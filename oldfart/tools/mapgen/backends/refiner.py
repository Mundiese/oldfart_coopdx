import json
from . import BACKENDS, LABELS, BadReply, Config, Unavailable, scrub
from .. import brief as briefmod
from .. import refine as refmod
OPS = ("resize", "move", "swap", "remove", "nudge", "lock", "reseed", "retexture", "set",
       "want", "avoid", "trace", "few", "less", "more", "lots", "novelty")
WHATS = tuple(sorted(set(w for _, w in refmod.WHAT_WORDS)))
DIRS = tuple(refmod.DIRS) + ("c",)
REGIONS = tuple(refmod.REGIONS)
MODULES = tuple(sorted(set(m for _, m in refmod.RESEED_WORDS)))
SET_FIELDS = ("players", "size", "pace", "verticality", "density", "symmetry", "level",
              "family", "sides", "edge", "difficulty", "style", "sky", "music", "budget", "name")
AXES = ("openness", "verticality")
RULES = """You translate a request to CHANGE an existing generated map into the map
generator's refine operations. Answer with JSON only: {"why": "...", "ops": [...]}.
Each op is {"op": NAME, "args": [...]} with these forms:
  resize   [target "centre"|"map", factor]        "Mitte groesser" = ["centre", 1.25]; smaller 0.8
  move     [thing, direction, units]              "Turm weiter nach Norden" = ["tower", "n", 400]
  swap     [old thing, new thing]                 "Grube statt Krone" = ["crown", "pit"]
  remove   [thing]                                "Bruecke weg" = ["bridge"]
  nudge    [region, "openness"|"verticality", 1|-1]  "Mitte offener" = ["centre", "openness", 1];
                                                  "mehr Deckung im Norden" = ["n", "openness", -1]
  lock     [region]                               "Basen nicht aendern" = ["bases"]
  reseed   [module]                               "andere Mitte" = ["centre"]
  retexture ["theme", theme]                      "Wuestenoptik" = ["theme", "desert"]
  set      [field, value]                         "flacher" = ["verticality", "low"]
  want / avoid [feature]                          "mit Treppen" = want ["stairs"]; "ohne Wasser" = avoid ["water"]
  less / more  [feature]                          "weniger Wasser" = less ["water"] (less, not none)
  trace / few / lots [feature]                    "kaum Wasser" = trace, "ein paar Baeume" = few ["trees"], "viele Bruecken" = lots
  novelty  [mode "reject"|"novel", aspects...]    "die Formation hatten wir schon" = ["reject", "formation"]
Change only what was asked. Use only the words listed below. Never coordinates
of pieces, never a seed.
Tools (when offered): map_state() shows the current map's fields and its
anchors with ids, kinds and places - call it when the request points at
something on the map ("die Bruecke da", "the tower in the north"); preview(ops)
says whether your operations make a valid map before you answer; ask_user(ask,
options) asks the user ONE short question with 2-6 options when the request
cannot be read otherwise (two towers match "the tower") - then stop.
"""
def vocabulary():
    return ["things: " + ", ".join(WHATS), "directions: " + ", ".join(DIRS),
            "regions: " + ", ".join(REGIONS), "modules: " + ", ".join(MODULES),
            "fields: " + ", ".join(SET_FIELDS), "themes: " + ", ".join(briefmod.THEMES),
            "features: " + ", ".join(briefmod.FEATURES),
            "novelty aspects: " + ", ".join(briefmod.NOVELTY_ASPECTS)]
def system_prompt():
    return RULES + "\n" + "\n".join(vocabulary())
def schema():
    arg = {"anyOf": [{"type": "string"}, {"type": "number"}]}
    return {"type": "object", "properties": {
        "why": {"type": "string"},
        "ops": {"type": "array", "items": {"type": "object", "properties": {
            "op": {"type": "string", "enum": list(OPS)},
            "args": {"type": "array", "items": arg}},
            "required": ["op", "args"], "additionalProperties": False}}},
        "required": ["why", "ops"], "additionalProperties": False}
def user_prompt(text, offline_ops=None, base=None, problems=None):
    parts = ["REQUEST: %s" % text]
    if offline_ops:
        parts.append("The offline parser read: %s" % json.dumps(
            [list(op) for op in offline_ops], ensure_ascii=False, default=str))
    if base:
        shown = {k: v for k, v in base.items() if k in SET_FIELDS + ("theme", "features")}
        parts.append("The current map's brief: %s" % json.dumps(shown, ensure_ascii=False,
                                                                sort_keys=True))
    if problems:
        parts.append("Your previous operations did not validate:\n- " + "\n- ".join(problems)
                     + "\nReturn the corrected operations.")
    parts.append("Return the operations as JSON.")
    return "\n\n".join(parts)
def to_ops(reply):
    if not isinstance(reply, dict) or not isinstance(reply.get("ops"), list):
        raise BadReply("the reply is not {why, ops}")
    ops, problems = [], []
    feats = {"want": [], "avoid": []}
    amounts = {}
    for i, o in enumerate(reply["ops"]):
        if not isinstance(o, dict) or o.get("op") not in OPS or not isinstance(o.get("args"), list):
            problems.append("op %d: not {op: one of %s, args: [...]}" % (i + 1, ", ".join(OPS)))
            continue
        name, a = o["op"], o["args"]
        def need(n, *checks):
            if len(a) < n:
                problems.append("%s: needs %d args" % (name, n))
                return False
            for k, allowed in checks:
                if a[k] not in allowed:
                    problems.append("%s: %r is not one of %s" % (name, a[k], ", ".join(
                        str(x) for x in allowed)))
                    return False
            return True
        if name == "resize" and need(2, (0, ("centre", "map"))):
            try:
                f = float(a[1])
            except (TypeError, ValueError):
                problems.append("resize: factor %r is not a number" % (a[1],))
                continue
            if not 0.5 <= f <= 2.0:
                problems.append("resize: factor %r outside 0.5-2" % f)
                continue
            ops.append(("resize", a[0], f))
        elif name == "move" and need(2, (0, WHATS), (1, DIRS)):
            amount = refmod.STEP
            if len(a) > 2:
                try:
                    amount = int(a[2])
                except (TypeError, ValueError):
                    problems.append("move: units %r is not a number" % (a[2],))
                    continue
            ops.append(("move", a[0], a[1], amount))
        elif name == "swap" and need(2, (0, WHATS), (1, WHATS)):
            ops.append(("swap", a[0], a[1]))
        elif name == "remove" and need(1, (0, WHATS)):
            ops.append(("remove", a[0]))
        elif name == "nudge" and need(3, (0, REGIONS), (1, AXES), (2, (1, -1))):
            ops.append(("nudge", a[0], a[1], int(a[2])))
        elif name == "lock" and need(1, (0, REGIONS)):
            ops.append(("lock", a[0]))
        elif name == "reseed" and need(1, (0, MODULES)):
            ops.append(("reseed", a[0]))
        elif name == "retexture" and need(2, (0, ("theme",)), (1, briefmod.THEMES)):
            ops.append(("retexture", "theme", a[1]))
        elif name == "set" and need(2, (0, SET_FIELDS)):
            ops.append(("set", a[0], a[1]))
        elif name in ("want", "avoid") and need(1, (0, briefmod.FEATURES)):
            feats[name].append(a[0])
        elif name in briefmod.AMOUNTS and need(1, (0, briefmod.FEATURES + briefmod.AMOUNT_EXTRA)):
            amounts[a[0]] = name
        elif name == "novelty" and need(1, (0, ("reject", "novel"))):
            bad = [x for x in a[1:] if x not in briefmod.NOVELTY_ASPECTS]
            if bad:
                problems.append("novelty: %s not among %s" % (bad, briefmod.NOVELTY_ASPECTS))
                continue
            nov = {"mode": a[0]}
            if a[1:]:
                nov["avoid"] = list(a[1:])
            ops.append(("novelty", nov))
    if feats["want"] or feats["avoid"]:
        ops.append(("features", feats))
    if amounts:
        ops.append(("amounts", amounts))
    return ops, str(reply.get("why") or "").strip(), problems
def problems_of(brief, ops):
    try:
        refmod.apply(brief, ops)
        return []
    except briefmod.BriefError as why:
        return list(why.problems)
    except Exception as why:
        return ["the operations could not be applied: %s" % why]
class MapTools:
    def __init__(self, brief, layout=None):
        self.brief = brief
        self.layout = layout or {}
        self.calls = []
    def definitions(self):
        arg = {"anyOf": [{"type": "string"}, {"type": "number"}]}
        none = {"type": "object", "properties": {}, "required": [], "additionalProperties": False}
        return [
            {"name": "map_state", "strict": True, "input_schema": none,
             "description": "The current map: its brief fields and its anchors (id, kind, "
                            "compass place, height). Call it when the request refers to "
                            "something on the map."},
            {"name": "preview", "strict": True,
             "description": "Check refine operations before answering: 'ok' with what "
                            "changes, or the problems.",
             "input_schema": {"type": "object", "additionalProperties": False,
                              "required": ["ops"],
                              "properties": {"ops": {"type": "array", "items": {
                                  "type": "object", "additionalProperties": False,
                                  "required": ["op", "args"],
                                  "properties": {"op": {"type": "string", "enum": list(OPS)},
                                                 "args": {"type": "array", "items": arg}}}}}}},
            {"name": "ask_user", "strict": True,
             "description": "Ask the user one short question with 2-6 options, only when the "
                            "request cannot be read otherwise. Ends your turn.",
             "input_schema": {"type": "object", "additionalProperties": False,
                              "required": ["ask", "options"],
                              "properties": {"ask": {"type": "string"},
                                             "options": {"type": "array",
                                                         "items": {"type": "string"}}}}},
        ]
    def state(self):
        b = self.brief.to_dict() if hasattr(self.brief, "to_dict") else dict(self.brief or {})
        anchors = []
        for i, a in enumerate(b.get("anchors") or []):
            anchors.append({"id": a.get("id") or "a%d" % (i + 1), "kind": a.get("what"),
                            "where": a.get("where"), "count": a.get("count", 1),
                            "height": a.get("height")})
        for i, a in enumerate(self.layout.get("anchors") or []):
            anchors.append({"id": a.get("id") or "p%d" % (i + 1), "kind": a.get("what"),
                            "where": a.get("where") or a.get("cell"), "placed": True})
        fields = {k: v for k, v in b.items() if k in SET_FIELDS + ("theme", "features")}
        return {"fields": fields, "anchors": anchors}
    def run(self, name, args):
        from .claude import Asked
        self.calls.append(name)
        if name == "map_state":
            return json.dumps(self.state(), ensure_ascii=False, sort_keys=True, default=str)
        if name == "preview":
            ops, _, problems = to_ops({"ops": args.get("ops") or [], "why": ""})
            if not problems:
                problems = problems_of(self.brief, ops) if ops else ["no operation"]
            return "ok: %s" % json.dumps([list(o) for o in ops], default=str) \
                if not problems else "problems: " + "; ".join(problems)
        if name == "ask_user":
            raise Asked({"ask": str(args.get("ask") or "").strip(),
                         "options": [str(o) for o in (args.get("options") or [])][:6]})
        raise ValueError("no tool %s" % name)
class RefineReading:
    def __init__(self, text, backend, used, ops, why="", model=None, offline_ops=None,
                 notes=None, attempts=0, usage=None):
        self.text, self.backend, self.used = text, backend, used
        self.ops = ops
        self.why = why
        self.model = model
        self.offline_ops = offline_ops or []
        self.notes = list(notes or [])
        self.attempts = attempts
        self.usage = usage or {}
        self.questions = []
    @property
    def fell_back(self):
        return self.backend != "offline" and self.used == "offline"
    def lines(self):
        who = LABELS.get(self.used, self.used) + (" (%s)" % self.model if self.model else "")
        out = ["refine read by: %s" % who]
        if self.fell_back:
            out[0] += " - FALLBACK: %s was chosen but not used" % LABELS.get(
                self.backend, self.backend)
        if self.why:
            out.append("why: %s" % self.why)
        out += ["question: %s%s" % (q["ask"], " [%s]" % " / ".join(q["options"])
                                    if q.get("options") else "") for q in self.questions]
        return out + ["note: %s" % n for n in self.notes]
def read(text, brief, config=None, client=None, transport=None, layout=None):
    config = config or Config()
    off_ops = refmod.parse_ops(text or "", brief)[0]
    off = RefineReading(text, "offline", "offline", off_ops, "the offline refine parser",
                        offline_ops=off_ops)
    if config.backend not in BACKENDS or config.backend == "offline" or not (text or "").strip():
        return off
    from . import claude as claudemod, ollama as ollamamod
    name = LABELS[config.backend]
    prompts = {"system": system_prompt, "schema": schema, "user": user_prompt}
    try:
        if config.backend == "claude":
            tools = MapTools(brief, layout)
            session = claudemod.Session(config, client=client, prompts=prompts, tools=tools)
        else:
            session = ollamamod.Session(config, transport=transport, prompts=prompts)
    except Unavailable as why:
        off.backend = config.backend
        off.notes.append("%s is not available (%s) - the offline refine is used"
                         % (name, scrub(why)))
        return off
    base = brief.to_dict() if hasattr(brief, "to_dict") else dict(brief or {})
    problems, ops, why_text, attempts = None, None, "", 0
    try:
        for attempts in (1, 2):
            try:
                reply = session.ask(text, off_ops, base, problems)
                ops, why_text, problems = to_ops(reply)
            except BadReply as bad:
                problems, ops = ["the reply was not refine operations: %s" % bad], None
                continue
            if not ops and not problems:
                problems = ["no operation - say what changes"]
            if not problems:
                problems = problems_of(brief, ops)
            if not problems:
                break
            ops = None
    except claudemod.Asked as q:
        r = RefineReading(text, config.backend, config.backend, [], "",
                          model=session.model, offline_ops=off_ops,
                          notes=["%s asks before changing anything" % name],
                          attempts=attempts, usage=session.usage)
        r.questions = [q.question]
        return r
    except Unavailable as why:
        off.backend = config.backend
        off.attempts = attempts
        off.notes.append("%s did not answer (%s) - the offline refine is used"
                         % (name, scrub(why)))
        return off
    if ops is None:
        off.backend = config.backend
        off.attempts = attempts
        off.notes.append("%s's operations did not validate after one repair (%s) - the "
                         "offline refine is used" % (name, "; ".join(problems or [])[:300]))
        return off
    notes = ["%s's first operations did not validate; repaired on the second try" % name] \
        if attempts > 1 else []
    return RefineReading(text, config.backend, config.backend, ops, why_text,
                         model=session.model, offline_ops=off_ops, notes=notes,
                         attempts=attempts, usage=session.usage)
