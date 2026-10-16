import copy
import json
import os
import re
from .. import brief as briefmod
from .. import wish as wishmod
from . import schema
BACKENDS = ("offline", "claude", "ollama")
LABELS = {"offline": "Offline", "claude": "Claude", "ollama": "Ollama"}
CLAUDE_MODELS = ("claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-4-5-20251001")
CLAUDE_DEFAULT = CLAUDE_MODELS[0]
OLLAMA_URL = "http://localhost:11434"
TIMEOUT_S = 60.0
APP = "oldfart-studio"
class Unavailable(Exception):
    pass
class BadReply(Exception):
    pass
def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, APP)
def key_path():
    return os.path.join(config_dir(), "secrets.json")
def stored_key(path=None):
    try:
        with open(path or key_path(), encoding="utf-8") as f:
            k = (json.load(f) or {}).get("anthropic_api_key")
        return k if isinstance(k, str) and k.strip() else None
    except (OSError, ValueError, AttributeError):
        return None
def store_key(key, path=None):
    path = path or key_path()
    data = {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f) or {}
    except (OSError, ValueError):
        data = {}
    if key and key.strip():
        data["anthropic_api_key"] = key.strip()
    else:
        data.pop("anthropic_api_key", None)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
    return path
def api_key(path=None):
    env = os.environ.get("ANTHROPIC_API_KEY")
    if env and env.strip():
        return env.strip(), "env ANTHROPIC_API_KEY"
    k = stored_key(path)
    return (k, "the Studio's key file") if k else (None, None)
def mask(key):
    if not key:
        return "(none)"
    return "..." + key[-4:] if len(key) > 8 else "(set)"
def scrub(text, key=None):
    text = str(text)
    if key:
        text = text.replace(key, "[key]")
    return re.sub(r"sk-ant-[A-Za-z0-9_\-]{6,}", "[key]", text)
class Config:
    def __init__(self, backend="offline", claude_model=CLAUDE_DEFAULT, ollama_url=OLLAMA_URL,
                 ollama_model="", timeout=TIMEOUT_S, key_file=None):
        self.backend = backend if backend in BACKENDS else "offline"
        self.claude_model = claude_model if claude_model in CLAUDE_MODELS else CLAUDE_DEFAULT
        self.ollama_url = (ollama_url or OLLAMA_URL).rstrip("/")
        self.ollama_model = ollama_model or ""
        self.timeout = float(timeout or TIMEOUT_S)
        self.key_file = key_file
    def __repr__(self):
        return "Config(%s, claude=%s, ollama=%s %s)" % (
            self.backend, self.claude_model, self.ollama_url, self.ollama_model or "auto")
    @classmethod
    def from_settings(cls, get):
        def g(k, d):
            try:
                v = get(k)
            except (KeyError, TypeError):
                return d
            return d if v is None else v
        return cls(backend=g("wish.backend", "offline"),
                   claude_model=g("wish.claude_model", CLAUDE_DEFAULT),
                   ollama_url=g("wish.ollama_url", OLLAMA_URL),
                   ollama_model=g("wish.ollama_model", ""),
                   timeout=g("wish.timeout", TIMEOUT_S))
class Reading:
    def __init__(self, text, backend, used, raw, why="", model=None, offline=None,
                 notes=None, understood=None, assumed=None, not_understood=None,
                 attempts=0, usage=None, questions=None):
        self.text = text
        self.backend = backend
        self.used = used
        self.raw = raw
        self.why = why
        self.model = model
        self.offline = offline
        self.notes = list(notes or [])
        self.understood = list(understood or [])
        self.assumed = list(assumed or [])
        self.not_understood = list(not_understood or [])
        self.attempts = attempts
        self.usage = usage or {}
        self.questions = list(questions or [])
    @property
    def fell_back(self):
        return self.backend != "offline" and self.used == "offline"
    @property
    def fallback_reason(self):
        return (self.notes[-1] if self.notes else "no reason recorded") if self.fell_back else ""
    @property
    def heard_in(self):
        return getattr(self.offline, "heard_in", {}) or {}
    def lines(self):
        who = LABELS.get(self.used, self.used) + (" (%s)" % self.model if self.model else "")
        out = ["read by: %s" % who]
        if self.fell_back:
            out[0] += " - FALLBACK: %s was chosen but not used" % LABELS.get(
                self.backend, self.backend)
            out.append("fallback reason: %s" % self.fallback_reason)
        if self.why:
            out.append("why: %s" % self.why)
        out += ["note: %s" % n for n in self.notes if not (self.fell_back and
                                                            n == self.fallback_reason)]
        for q in self.questions:
            out.append("question: %s%s" % (q["ask"], " [%s]" % " / ".join(q["options"])
                                           if q.get("options") else ""))
        return out
def _offline_why(r):
    bits = []
    if r.understood:
        bits.append("understood " + "; ".join(r.understood))
    if r.assumed:
        bits.append("assumed " + "; ".join(r.assumed))
    if r.not_understood:
        bits.append("not understood " + "; ".join(r.not_understood))
    return ". ".join(bits) or "nothing in the text set a field - the family's defaults stand"
def offline(text, base=None):
    r = wishmod.understand(text, base=base)
    return Reading(text, "offline", "offline", copy.deepcopy(r.raw), _offline_why(r),
                   offline=r, understood=r.understood, assumed=r.assumed,
                   not_understood=r.not_understood,
                   questions=list(getattr(r, "questions", []) or []))
def problems_of(raw, forge_keys=None):
    try:
        briefmod.Brief.from_dict(copy.deepcopy(raw), forge_keys)
        return []
    except briefmod.BriefError as why:
        return list(why.problems)
    except Exception as why:
        return ["the brief could not be read: %s" % why]
def clean(reply, text):
    if not isinstance(reply, dict):
        raise BadReply("the reply is not a JSON object")
    reply = copy.deepcopy(reply)
    why = reply.pop("why", "") or ""
    raw = {}
    for k, v in reply.items():
        if v in (None, "", [], {}):
            continue
        if k == "features" and isinstance(v, dict):
            v = {s: list(v.get(s) or []) for s in ("want", "avoid")}
            if not v["want"] and not v["avoid"]:
                continue
        raw[k] = v
    raw["wish"] = text
    return raw, str(why).strip()
def _forge_keys():
    try:
        from .. import kit
        return kit.forge_keys()
    except Exception:
        return None
def negation_guard(raw, offline_raw):
    off = set(((offline_raw or {}).get("features") or {}).get("avoid") or [])
    feats = raw.get("features")
    if not off or not isinstance(feats, dict):
        return []
    want = list(feats.get("want") or [])
    back = [f for f in want if f in off]
    if not back:
        return []
    feats["want"] = [f for f in want if f not in off]
    feats["avoid"] = sorted(set(feats.get("avoid") or []) | set(back))
    return ["kept %s avoided: the wish refuses it, the model's patch wanted it"
            % ", ".join(back)]
def read(text, config=None, base=None, client=None, transport=None):
    config = config or Config()
    off = offline(text, base)
    if config.backend == "offline" or not (text or "").strip():
        return off
    from . import claude as claudemod, ollama as ollamamod
    name = LABELS[config.backend]
    forge = _forge_keys()
    try:
        if config.backend == "claude":
            session = claudemod.Session(config, client=client)
        else:
            session = ollamamod.Session(config, transport=transport)
    except Unavailable as why:
        off.backend = config.backend
        off.notes.append("%s is not available (%s) - the offline reading is used"
                         % (name, scrub(why)))
        return off
    problems = None
    raw = why_text = None
    guard_notes = []
    questions = []
    attempts = 0
    try:
        for attempts in (1, 2):
            try:
                reply = session.ask(text, off.raw, base, problems)
                raw, why_text, questions, problems = schema.apply_patch(reply, off.raw, text)
            except BadReply as bad:
                problems = ["the reply was not a patch: %s" % bad]
                raw = None
                continue
            if problems:
                raw = None
                continue
            guard_notes = negation_guard(raw, off.raw)
            problems = problems_of(raw, forge)
            if not problems:
                break
            raw = None
    except Unavailable as why:
        off.backend = config.backend
        off.notes.append("%s did not answer (%s) - the offline reading is used"
                         % (name, scrub(why)))
        off.attempts = attempts
        return off
    if raw is None:
        off.backend = config.backend
        off.attempts = attempts
        off.notes.append("%s's brief did not validate after one repair (%s) - the offline "
                         "reading is used" % (name, "; ".join(problems or [])[:300]))
        return off
    notes = ["%s's first brief did not validate; repaired on the second try" % name] \
        if attempts > 1 else []
    notes += list(getattr(session, "notes", []) or []) + guard_notes
    return Reading(text, config.backend, config.backend, raw, why_text,
                   model=session.model, offline=off.offline, notes=notes,
                   understood=off.understood, assumed=off.assumed,
                   not_understood=[], attempts=attempts, usage=session.usage,
                   questions=questions)
class Status:
    def __init__(self, backend, ok, label, detail):
        self.backend = backend
        self.ok = ok
        self.label = label
        self.detail = detail
    def __repr__(self):
        return "Status(%s, %s, %r)" % (self.backend, "ok" if self.ok else "off", self.label)
def status(config, probe=False, client=None, transport=None):
    b = config.backend
    if b == "offline":
        return Status(b, True, "Offline", "the rule parser - always there, no network")
    if b == "claude":
        from . import claude as claudemod
        return claudemod.status(config, probe=probe, client=client)
    from . import ollama as ollamamod
    return ollamamod.status(config, transport=transport)
