import json
from .. import brief as briefmod
LLM_FIELDS = ("family", "modes", "players", "size", "pace", "symmetry", "sides",
              "verticality", "density", "difficulty", "edge", "theme", "style", "level",
              "ground", "features", "anchors", "objects", "dna", "dials", "visuals",
              "palette", "reference", "name", "budget", "preset", "prefabs",
              "variety", "novelty", "requests", "forge_off", "amounts")
def fields():
    return tuple(f for f in LLM_FIELDS if f in briefmod.FIELDS)
def _enum(values):
    return {"type": "string", "enum": [str(v) for v in values]}
def _modes():
    try:
        from .. import modes
        return sorted(modes.all())
    except Exception:
        return []
def _forge_keys():
    try:
        from .. import kit
        return sorted(kit.forge_keys())
    except Exception:
        return []
def _textures():
    try:
        from .. import kit
        t = kit.textures()
        return sorted(t) if isinstance(t, dict) else sorted(str(x) for x in t)
    except Exception:
        return []
def _roles():
    try:
        from .. import kit
        return sorted(set(r for v in kit.ROLES.values() for r in v))
    except Exception:
        return ["floor", "wall"]
def references():
    try:
        from .. import wish
        return [key for _, key in wish.REFERENCES]
    except Exception:
        return []
def presets():
    try:
        from .. import presets as pmod
        return [tuple(row) for row in pmod.table()]
    except Exception:
        return []
def prefabs():
    try:
        from .. import prefablib
        return [(row[0], row[1]) for row in prefablib.names()]
    except Exception:
        return []
def _where():
    return {
        "type": "object",
        "description": "Where it goes, in ONE of these forms: compass (n ne e se s sw w nw c, "
                       "or a region corners/edges/edge/ring/field), clock (1..12), relation + of "
                       "(another anchor id or feature), cell [column,row] of the 200 grid, "
                       "on (a feature such as bridge or ramps), edge, aligned.",
        "properties": {
            "compass": _enum(tuple(briefmod.COMPASS) + tuple(briefmod.REGION_WORDS)),
            "clock": {"type": "integer"},
            "relation": _enum(briefmod.RELATIONS),
            "of": {"anyOf": [{"type": "string"},
                             {"type": "array", "items": {"type": "string"}}]},
            "cell": {"type": "array", "items": {"type": "integer"}},
            "on": {"type": "string"},
            "edge": {"type": "string"},
            "aligned": {"type": "string"},
            "radius": _enum(briefmod.RADII),
        },
        "additionalProperties": False,
    }
def brief_schema():
    feat = _enum(briefmod.FEATURES)
    forge = _forge_keys()
    obj_key = _enum(forge) if forge else {"type": "string"}
    textures = _textures()
    tex = _enum(textures) if textures else {"type": "string"}
    modes = _modes()
    props = {
        "why": {"type": "string",
                "description": "Your reading of the wish in 1-4 short sentences: what you took "
                               "from it and what you assumed. Same language as the wish."},
        "family": _enum(briefmod.FAMILIES),
        "modes": {"type": "array", "items": _enum(modes) if modes else {"type": "string"}},
        "players": {"type": "integer", "description": "2..16"},
        "size": {"anyOf": [
            _enum(tuple(briefmod.SIZES)),
            {"type": "object", "properties": {"across": {"type": "number"}},
             "required": ["across"], "additionalProperties": False},
            {"type": "object", "properties": {"across_s": {"type": "number"}},
             "required": ["across_s"], "additionalProperties": False},
            {"type": "object", "properties": {"w": {"type": "number"}, "d": {"type": "number"}},
             "required": ["w", "d"], "additionalProperties": False},
            {"type": "object", "properties": {"aspect": {"type": "number"},
                                              "tier": _enum(tuple(briefmod.SIZES))},
             "required": ["aspect"], "additionalProperties": False}]},
        "pace": _enum(tuple(briefmod.PACES)),
        "symmetry": _enum(briefmod.SYMMETRIES),
        "sides": _enum(briefmod.SIDES),
        "verticality": _enum(briefmod.VERTICALITIES),
        "density": _enum(briefmod.DENSITIES),
        "difficulty": _enum(briefmod.DIFFICULTIES),
        "edge": _enum(briefmod.EDGES),
        "theme": _enum(briefmod.THEMES),
        "style": _enum(briefmod.STYLES),
        "level": _enum(briefmod.LEVELS),
        "ground": _enum(briefmod.GROUNDS),
        "features": {"type": "object", "properties": {
            "want": {"type": "array", "items": feat},
            "avoid": {"type": "array", "items": feat}},
            "additionalProperties": False},
        "anchors": {"type": "array", "items": {
            "type": "object",
            "properties": {
                "id": {"type": "string"},
                "what": _enum(briefmod.ANCHOR_WHATS),
                "where": _where(),
                "count": {"type": "integer"},
                "height": {"type": "number"},
                "size": _enum(tuple(briefmod.SIZES)),
                "spacing": {"type": "number"},
                "once": {"type": "boolean"},
                "hard": {"type": "boolean"}},
            "required": ["what"], "additionalProperties": False}},
        "objects": {"type": "array", "items": {
            "type": "object",
            "properties": {
                "key": obj_key,
                "count": {"type": "integer"},
                "where": _where(),
                "modes": {"type": "array", "items": {"type": "string"}}},
            "required": ["key"], "additionalProperties": False}},
        "dna": {"type": "object", "properties": {k: {"type": "number"} for k in briefmod.DNA},
                "additionalProperties": False},
        "dials": {"type": "object",
                  "properties": {k: {"type": "number"}
                                 for k in ("openness", "verticality", "density")},
                  "additionalProperties": False},
        "visuals": {"type": "array",
                    "items": _enum(sorted(k for k in briefmod.VISUALS if k != "auto"))},
        "mood": _enum(list(briefmod.MOODS)),
        "palette": {"type": "object",
                    "properties": {r: {"type": "array", "items": tex} for r in _roles()},
                    "additionalProperties": False},
        "reference": _enum(references()) if references() else {"type": "string"},
        "name": {"type": "string"},
        "budget": {"type": "integer"},
    }
    pre = presets()
    props["preset"] = _enum([k for k, _, _ in pre]) if pre else {"type": "string"}
    pf = prefabs()
    props["prefabs"] = {"type": "array",
                        "items": _enum([k for k, _ in pf]) if pf else {"type": "string"}}
    props["variety"] = _enum(getattr(briefmod, "VARIETIES", ("auto", "low", "high")))
    props["novelty"] = {
        "type": "object",
        "description": "surprise = roll what the wish left open; novel = far from the maps "
                       "made before; reject = unlike the last maps in the named aspects",
        "properties": {
            "mode": _enum(getattr(briefmod, "NOVELTY_MODES", ("surprise", "novel", "reject"))),
            "avoid": {"type": "array", "items": _enum(getattr(
                briefmod, "NOVELTY_ASPECTS", ("formation", "theme", "size", "preset",
                                              "features")))}},
        "required": ["mode"], "additionalProperties": False}
    props["requests"] = {
        "type": "array",
        "description": "things asked for that no generator builds yet (kept, never dropped)",
        "items": {"type": "object", "properties": {
            "kind": _enum(getattr(briefmod, "REQUEST_KINDS", ("stars", "mover", "forge"))),
            "count": {"type": "integer"},
            "what": {"type": "string"}, "relation": {"type": "string"},
            "of": {"type": "string"}, "hidden": {"type": "boolean"},
            "sub": _enum(getattr(briefmod, "MOVER_SUBS", ("lift", "log_gauntlet", "gap_ferry",
                                                          "island_ferry"))),
            "stars": {"type": "array", "items": {"type": "object", "properties": {
                "n": {"type": "integer", "minimum": 1, "maximum": 6},
                "kinds": {"type": "array", "items": _enum(getattr(
                    briefmod, "STAR_HINT_KINDS", ("summit", "cave")))},
                "name": {"type": "string"}},
                "required": ["n"], "additionalProperties": False}}},
            "required": ["kind"], "additionalProperties": False}}
    props["forge_off"] = {"type": "array", "items": _enum(getattr(
        briefmod, "FORGE_OFF", ("enemies", "hazards", "movers", "items", "scenery", "all")))}
    props["amounts"] = {
        "type": "object",
        "description": "how much of a feature, graded: 'kaum Wasser' = {water: trace}, "
                       "'wenig / ein paar' = few, 'weniger Wasser' = less, 'mehr Baeume' = "
                       "more, 'viele / jede Menge' = lots; 'kein Wasser' is features.avoid "
                       "instead",
        "properties": {f: _enum(getattr(briefmod, "AMOUNTS", ("less", "more")))
                       for f in tuple(briefmod.FEATURES) + tuple(getattr(briefmod, "AMOUNT_EXTRA", ()))},
        "additionalProperties": False}
    props = {k: v for k, v in props.items() if k == "why" or k in fields()}
    return {"type": "object", "properties": props, "required": ["why"],
            "additionalProperties": False}
PATCH_KEYS = ("reading", "set", "remove", "questions")
def schema():
    field = _enum(fields())
    return {
        "type": "object", "additionalProperties": False,
        "required": list(PATCH_KEYS),
        "properties": {
            "reading": {"type": "string"},
            "set": {"type": "array", "items": {
                "type": "object", "additionalProperties": False,
                "required": ["field", "value"],
                "properties": {"field": field, "value": {"type": "string"}}}},
            "remove": {"type": "array", "items": field},
            "questions": {"type": "array", "items": {
                "type": "object", "additionalProperties": False,
                "required": ["ask", "options"],
                "properties": {"ask": {"type": "string"},
                               "options": {"type": "array", "items": {"type": "string"}}}}},
        }}
def schema_limits(sch):
    opt = uni = 0
    stack = [sch]
    while stack:
        s = stack.pop()
        if isinstance(s, list):
            stack.extend(s)
            continue
        if not isinstance(s, dict):
            continue
        props = s.get("properties")
        if isinstance(props, dict):
            req = set(s.get("required") or [])
            for k, v in props.items():
                if k not in req:
                    opt += 1
                if isinstance(v, dict) and ("anyOf" in v or isinstance(v.get("type"), list)):
                    uni += 1
        stack.extend(v for v in s.values() if isinstance(v, (dict, list)))
    return opt, uni
def _value(text):
    if not isinstance(text, str):
        return text, None
    t = text.strip()
    try:
        return json.loads(t), None
    except ValueError:
        if t and not t[0] in "[{\"" and "\n" not in t:
            return t, None
        return None, "not JSON: %s" % t[:60]
def apply_patch(reply, draft, text):
    from . import BadReply
    if not isinstance(reply, dict) or not all(k in reply for k in ("reading", "set")):
        raise BadReply("the reply is not a patch {reading, set, remove, questions}")
    raw = {k: v for k, v in (draft or {}).items() if k != "wish"}
    raw = json.loads(json.dumps(raw))
    ok = set(fields())
    problems = []
    for f in reply.get("remove") or []:
        if f not in ok:
            problems.append("remove: %r is not a brief field" % (f,))
            continue
        raw.pop(f, None)
    for i, item in enumerate(reply.get("set") or []):
        if not isinstance(item, dict) or item.get("field") not in ok:
            problems.append("set %d: %r is not a brief field" % (
                i + 1, item.get("field") if isinstance(item, dict) else item))
            continue
        v, bad = _value(item.get("value"))
        if bad:
            problems.append("set %s: %s" % (item["field"], bad))
            continue
        if v in (None, "", [], {}):
            raw.pop(item["field"], None)
            continue
        if item["field"] == "features" and isinstance(v, dict):
            v = {s: list(v.get(s) or []) for s in ("want", "avoid")}
            if not v["want"] and not v["avoid"]:
                raw.pop("features", None)
                continue
        raw[item["field"]] = v
    questions = []
    for q in reply.get("questions") or []:
        if isinstance(q, dict) and str(q.get("ask") or "").strip():
            questions.append({"ask": str(q["ask"]).strip(),
                              "options": [str(o) for o in (q.get("options") or [])][:6]})
    raw["wish"] = text
    return raw, str(reply.get("reading") or "").strip(), questions, problems
def to_patch(brief, reading=""):
    brief = dict(brief)
    reading = reading or brief.pop("why", "")
    brief.pop("why", None)
    return {"reading": reading,
            "set": [{"field": k, "value": json.dumps(v, ensure_ascii=False)}
                    for k, v in brief.items() if k in fields()],
            "remove": [], "questions": []}
def _lines(title, items, per=12):
    items = [str(i) for i in items]
    out = ["%s:" % title]
    for i in range(0, len(items), per):
        out.append("  " + ", ".join(items[i:i + per]))
    return out
EXAMPLES = (
    ("eine kleine schnelle Shooter-Map, viel Vertikalitaet",
     {"why": "Kleine, schnelle Shooter-Map mit viel Hoehe: Familie shooter, Groesse small, "
             "Tempo fast, Vertikalitaet high.",
      "family": "shooter", "size": "small", "pace": "fast", "verticality": "high"}),
    ("16 Spieler CTF, Eis-Thema, eine Bruecke in der Mitte, World Spawn im Sueden",
     {"why": "CTF for 16 on ice; a bridge anchored in the centre; the world spawn hard in "
             "the south.",
      "family": "objective", "modes": ["ctf"], "players": 16, "sides": "2", "theme": "ice",
      "anchors": [{"what": "bridge", "where": {"compass": "c"}},
                  {"what": "world_spawn", "where": {"compass": "s"}}]}),
    ("a tower in the middle, 4 bases in the corners",
     {"why": "A shooter (no mode named) with a tower anchored in the centre and four bases, "
             "one per corner.",
      "anchors": [{"what": "tower", "where": {"compass": "c"}},
                  {"what": "base", "count": 4, "where": {"compass": "corners"}}]}),
    ("no stairs, only ramps",
     {"why": "Stairs avoided; height changes by ramps only.",
      "features": {"want": ["ramps_only"], "avoid": ["stairs"]}}),
    ("ein paar Goombas auf der Bruecke",
     {"why": "Forge objects only because the wish names them: three goombas on the bridge "
             "('ein paar' read as 3); the bridge itself is wanted.",
      "features": {"want": ["bridge"]},
      "objects": [{"key": "goomba", "count": 3, "where": {"on": "bridge"}}]}),
    ("riesige hide and seek map mit komplexen bauten und stimmiger texturauswahl",
     {"why": "Hide and seek, huge; complex buildings = World DNA complexity high; a coherent "
             "texture choice = coherence high.",
      "family": "hide", "size": "huge", "features": {"want": ["buildings"]},
      "dna": {"complexity": 0.85, "coherence": 0.85}}),
    ("nicht zu flach, eher bergig, keine Gegner bis auf zwei Thwomps",
     {"why": "'nicht zu flach, eher bergig' = high; enemies stay on, the only ones named are "
             "two thwomps.",
      "verticality": "high", "objects": [{"key": "thwomp", "count": 2}]}),
    ("eine ruhige Seenlandschaft zum Wandern, alles ausser Lava",
     {"why": "A landscape to walk through, no game named: explore (assumed). Lakes = water; "
             "'alles ausser Lava' refuses lava.",
      "family": "explore", "features": {"want": ["water", "terrain"], "avoid": ["lava"]},
      "preset": "lakeland"}),
)
RULES = """\
You translate a map wish (German or English) for the Studio of a Super Mario 64
Coop DX mod into a BRIEF. You are the creative director only: you never place
pieces or give coordinates beyond the anchor language; the deterministic
generator plans, builds, checks and scores the map from the brief.

You answer with a PATCH on the offline rule parser's draft (shown with the wish):
  {"reading": "...", "set": [{"field": F, "value": V}], "remove": [F], "questions": []}
- "reading" first: 1-4 short sentences in the wish's language saying what you
  read and what you assumed (shown to the user). Write it before the fields.
- "set": each field you add or correct. V is the field's value as JSON text,
  for example "\"ice\"", "16", "{\"want\": [\"river\"], \"avoid\": [\"lava\"]}".
  A set REPLACES the draft's value: for features, anchors and objects give the
  whole list. Put content fields (features, anchors, objects, theme, size)
  before family.
- "remove": draft fields that are wrong (they fall back to the family default).
- "questions": [] almost always. Ask (with 2-6 short options) only when no
  family can be read or inferred, or the wish contradicts itself.
- Keep what the draft got right: an empty set and remove is a valid answer.

Rules:
- Fill only what the wish says or clearly implies. A field you leave out takes
  the family's default - that is good; do not restate defaults.
- Use only the words listed below (enums). Never invent fields or values.
- Features: "want" for things asked for, "avoid" for things refused ("ohne",
  "keine", "no", "without"). Never both. A negation has a scope: "nicht zu
  flach, eher bergig" is high; "keine Gegner bis auf Thwomps" keeps thwomps;
  "alles ausser Lava" refuses lava.
- Anchors place named things: tower, bridge, spawns, world spawn, flags, hills...
  with compass directions (n ne e se s sw w nw, c = centre), regions (corners,
  edges, ring, field), clock hours, or a relation to another anchor/feature.
  "4 bases in the corners" = one anchor {what: base, count: 4, where: {compass: corners}}.
- Forge objects (enemies, items, gadgets) ONLY when the wish names them.
- Mode names choose the family: CTF/domination/KotH -> objective, sumo -> knockoff,
  races -> race, hide and seek -> hide, deathmatch -> shooter. Put the mode in "modes".
  A landscape or nature wish with no game named is explore, never a silent shooter.
- Places and Super Mario 64 courses (a region, "Hazy Maze Cave") become concrete
  features, theme, preset and DNA; say so in "reading".
- Size is a tier name, or {"across": units} when the wish gives units; {"w": units, "d": units}
  for width by depth (a metre is 100 units), {"aspect": w/d, "tier": name} for "long and narrow"
  (2.5) or "wide" (1.6)
  (Mario runs ~960 units a second), or {"across_s": seconds} for a walk time.
- World DNA and dials are 0..1 numbers.
"""
def system_prompt():
    fam = briefmod.FAMILY_DEFAULTS
    out = [RULES, "Vocabulary (the brief's own values):", ""]
    out += _lines("families", briefmod.FAMILIES)
    out.append("family defaults:")
    for f in briefmod.FAMILIES:
        out.append("  %s: %s" % (f, ", ".join("%s=%s" % kv for kv in sorted(fam[f].items()))))
    out += _lines("family words (aliases)", sorted(briefmod.FAMILY_ALIASES))
    out += _lines("size tiers (factor on the footprint)",
                  ["%s %.2f" % kv for kv in briefmod.SIZES.items()])
    out += _lines("paces", briefmod.PACES)
    out += _lines("symmetries", briefmod.SYMMETRIES)
    out += _lines("sides", briefmod.SIDES)
    out += _lines("verticality", briefmod.VERTICALITIES)
    out += _lines("density (cover)", briefmod.DENSITIES)
    out += _lines("difficulty", briefmod.DIFFICULTIES)
    out += _lines("edges", briefmod.EDGES)
    out += _lines("themes", briefmod.THEMES)
    out += _lines("styles", briefmod.STYLES)
    out += _lines("levels (empty = The Tiles, a floor; empty2 = The Void)", briefmod.LEVELS)
    out += _lines("grounds of The Tiles", briefmod.GROUNDS)
    out += _lines("features (tick boxes)", briefmod.FEATURES)
    out += _lines("feature synonyms", ["%s=%s" % kv for kv in sorted(
        briefmod.FEATURE_ALIASES.items())], per=8)
    out += _lines("anchor kinds", briefmod.ANCHOR_WHATS)
    out += _lines("compass", tuple(briefmod.COMPASS) + tuple(briefmod.REGION_WORDS))
    out += _lines("relations", briefmod.RELATIONS)
    out += _lines("World DNA (0..1)", ["%s (default %.1f)" % (k, briefmod.DNA_DEFAULTS[k])
                                        for k in briefmod.DNA])
    out += _lines("visual modifiers", ["%s = %s" % (k, v[1]) for k, v in
                                       sorted(briefmod.VISUALS.items()) if k != "auto"], per=6)
    out += _lines("game modes of the mod (keys)", _modes())
    out += _lines("Forge objects (keys)", _forge_keys())
    out += _lines("textures (for palette roles %s)" % ", ".join(_roles()), _textures())
    out += _lines("reference venues", references())
    if "preset" in fields():
        out.append("World DNA presets (field preset; the wish's own words win):")
        out += ["  %s = %s%s" % (k, n, " - %s" % a if a else "") for k, n, a in presets()]
    if "prefabs" in fields():
        out += _lines("prefabs (field prefabs, by key; only when the wish names a build)",
                      ["%s (%s)" % kv for kv in prefabs()], per=6)
    out.append("budget: 20..%d objects" % briefmod.BUDGET_MAX)
    if "variety" in fields():
        out += _lines("material variety (field variety: low = fewer distinct pictures to "
                      "download, high = more)", getattr(briefmod, "VARIETIES", ()))
    if "novelty" in fields():
        out.append("novelty: {mode: surprise|novel|reject, avoid: [formation|theme|size|preset|"
                   "features]} - 'ueberrasch mich' = surprise, 'mal was anderes' = novel, "
                   "'die Formation hatten wir schon' = reject + avoid formation")
    if "forge_off" in fields():
        out.append("forge_off: Forge objects switched off by category (enemies, hazards, movers, "
                   "items, scenery, all) - 'ohne Gegner', 'nur Bloecke'")
    if "amounts" in fields():
        out.append("amounts: {feature: trace|few|less|more|lots} - 'kaum Wasser' = trace, "
                   "'wenig Wasser' / 'a few trees' = few, 'weniger Wasser' = less water (not "
                   "none), 'mehr Baeume' = more, 'viele Baeume' / 'lots of water' = lots; "
                   "'kein/ohne Wasser' = features.avoid")
    if "requests" in fields():
        out.append("requests: [{kind: stars|mover|forge, count?}] for what no generator builds "
                   "yet (bonus stars, movers on a path) - keep them, never drop them")
        out.append("  a stars request may list single stars: stars: [{n: 1..6, kinds?: [summit|"
                   "corner|lift|ferry|sunken|cave|cannon|guarded|wallrun|pillars|chimney|"
                   "longjump], name?}] - 'Stern 1 auf dem Berg \"Scale the Mountain\", Stern 2 "
                   "am Ende einer Hoehle' = [{n: 1, kinds: [summit], name: \"Scale the "
                   "Mountain\"}, {n: 2, kinds: [cave]}]; a floating island is [ferry, cannon, "
                   "pillars, longjump]; a quoted name is kept exactly as written")
    out += _lexicon_lines()
    out += ["", "Examples (wish -> patch on an empty draft):"]
    out += _example_lines(EXAMPLES)
    return "\n".join(out) + "\n"
def _example_lines(examples):
    out = []
    for text, reply in examples:
        out.append("WISH: %s" % text)
        out.append("PATCH: %s" % json.dumps(to_patch(reply), ensure_ascii=False))
    return out
def _lexicon_lines():
    try:
        from .. import lexicon
        lines = lexicon.summary(per=5)
    except Exception:
        return []
    return ["", "Lexicon (concept {what it sets}: words that mean it; the offline parser "
                "knows %d forms):" % lexicon.count()] + lines
SLIM_CONCEPTS = 30
def _grams(w):
    w = " %s " % w
    return {w[i:i + 3] for i in range(len(w) - 2)}
def _near(word, form):
    if word == form:
        return 1.0
    if len(word) >= 5 and len(form) >= 5 and (word.startswith(form[:5]) or
                                              form.startswith(word[:5])):
        return 0.8
    a, b = _grams(word), _grams(form)
    return float(len(a & b)) / len(a | b) if a and b else 0.0
def nearest_concepts(text, n=SLIM_CONCEPTS):
    import re
    try:
        from .. import lexicon
    except Exception:
        return []
    low = lexicon._fold(text or "")
    words = [w for w in re.findall(r"[a-z0-9']+", low) if len(w) >= 3]
    phrases = " %s " % " ".join(words)
    scored = []
    for c in lexicon.concepts():
        best = 0.0
        for f in c.get("forms", []):
            for ff, _ in lexicon.expand(f):
                if " " in ff:
                    if " %s " % ff in phrases:
                        best = 1.0
                    continue
                for w in words:
                    best = max(best, _near(w, ff))
            if best >= 1.0:
                break
        if best >= 0.5:
            scored.append((-best, c["id"], c))
    scored.sort(key=lambda t: (t[0], t[1]))
    return [c for _, _, c in scored[:n]]
def slim_prompt(text, draft=None):
    out = [RULES, "Vocabulary (the brief's own values):"]
    out += _lines("families", briefmod.FAMILIES, per=20)
    out += _lines("size tiers", tuple(briefmod.SIZES), per=20)
    out += _lines("paces", briefmod.PACES) + _lines("symmetries", briefmod.SYMMETRIES)
    out += _lines("sides", briefmod.SIDES) + _lines("verticality", briefmod.VERTICALITIES)
    out += _lines("density (cover)", briefmod.DENSITIES)
    out += _lines("difficulty", briefmod.DIFFICULTIES) + _lines("themes", briefmod.THEMES)
    out += _lines("features (tick boxes)", briefmod.FEATURES, per=20)
    out += _lines("anchor kinds", briefmod.ANCHOR_WHATS, per=20)
    out += _lines("compass", tuple(briefmod.COMPASS) + tuple(briefmod.REGION_WORDS), per=20)
    out += _lines("relations", briefmod.RELATIONS, per=20)
    out += _lines("World DNA (0..1)", briefmod.DNA, per=20)
    out += _lines("game modes (keys)", _modes(), per=30)
    near = nearest_concepts(text)
    import re
    words = re.findall(r"[a-z0-9]+", (text or "").lower())
    keys = [k for k in _forge_keys()
            if any(k in json.dumps(c.get("expect") or c.get("set") or {}) for c in near)
            or any(_near(w, k) >= 0.5 for w in words if len(w) >= 3)]
    out.append("Forge objects: keys as in objects[].key%s" % (
        " - near this wish: " + ", ".join(keys) if keys else ""))
    if "preset" in fields():
        out += _lines("World DNA presets", [k for k, _, _ in presets()], per=20)
    if "forge_off" in fields():
        out.append("forge_off: [enemies|hazards|movers|items|scenery|all] - 'ohne Gegner'")
    if "amounts" in fields():
        out.append("amounts: {feature: trace|few|less|more|lots} - 'weniger Wasser' = "
                   "less, not none; 'kaum' trace, 'viele' lots")
    if near:
        out += ["", "Words of this wish the offline lexicon knows (concept {what it sets}: "
                    "forms):"]
        for c in near:
            what = json.dumps(c.get("expect") or c.get("set") or {}, sort_keys=True,
                              ensure_ascii=False)
            forms = []
            for f in c.get("forms", [])[:5]:
                from .. import lexicon
                forms.append(lexicon.expand(f)[0][0])
            out.append("  %s %s: %s" % (c["id"], what, ", ".join(forms)))
    out += ["", "Examples (wish -> patch on an empty draft):"]
    out += _example_lines(EXAMPLES[1:2] + EXAMPLES[4:5] + EXAMPLES[-2:])
    return "\n".join(out) + "\n"
def tokens_estimate(text):
    return int(len(text or "") / 2.6) + 1
def _unread(text, base):
    try:
        from .. import wish
        r = wish.understand(text, base=base)
        return list(r.not_understood), list(r.assumed)
    except Exception:
        return [], []
def user_prompt(text, offline_raw=None, base=None, problems=None):
    parts = ["WISH: %s" % text]
    if offline_raw:
        shown = {k: v for k, v in offline_raw.items() if k != "wish"}
        parts.append("The offline rule parser's draft (patch it): %s"
                     % json.dumps(shown, ensure_ascii=False, sort_keys=True))
        unread, assumed = _unread(text, base)
        if unread:
            parts.append("Words the offline parser could not read: %s" % "; ".join(unread))
        if assumed:
            parts.append("What it assumed (check these): %s" % "; ".join(assumed))
    if base:
        shown = {k: v for k, v in base.items() if k in fields()}
        parts.append("The current map's brief (change only what the wish asks): %s"
                     % json.dumps(shown, ensure_ascii=False, sort_keys=True))
    if problems:
        parts.append("Your previous patch did not validate:\n- " + "\n- ".join(problems)
                     + "\nReturn the corrected patch.")
    parts.append("Return the patch as JSON: reading, set, remove, questions.")
    return "\n\n".join(parts)
