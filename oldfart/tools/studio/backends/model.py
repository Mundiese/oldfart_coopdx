import copy
from . import TOOLS
from mapgen import backends
from mapgen.backends import diff as diffmod
LABELS = backends.LABELS
def config(settings, resolved=None):
    def get(key):
        v = settings.get(key)
        if key == "wish.backend" and v == AUTO:
            return resolved or "offline"
        return v
    return backends.Config.from_settings(get)
def backend_of(settings):
    try:
        return settings.get("wish.backend")
    except KeyError:
        return "offline"
AUTO = "auto"
AUTO_ORDER = ("claude", "ollama")
def pick_auto(statuses):
    for b in AUTO_ORDER:
        st = statuses.get(b)
        if st is not None and st.ok:
            return b, "auto: %s is set up and answers, so it reads your wish (%s)" % (
                LABELS[b], st.detail)
    why = "; ".join("%s - %s" % (statuses[b].label, statuses[b].detail)
                    for b in AUTO_ORDER if b in statuses)
    return "offline", "auto: no AI backend answers, so the offline rules read your wish" + \
        (" (%s)" % why if why else "")
def auto_chip(backend, sentence):
    if backend == "offline":
        return "auto: offline", "info", sentence
    return "auto: %s" % LABELS[backend], "ok", sentence
ASK_KEY = "wish.ask_first"
def ask_first(settings):
    try:
        v = settings.get(ASK_KEY)
    except KeyError:
        return "ask"
    return {"always": True, "never": False}.get(v, "ask")
def answered(settings, read_first, remember):
    if remember:
        settings.set(ASK_KEY, "always" if read_first else "never")
    return read_first
def forget(settings):
    settings.set(ASK_KEY, "ask")
def chip(status):
    if status.backend == "offline":
        return "built in", "info", "The offline rules read your wish - no network needed. " + \
            status.detail
    tone = "ok" if status.ok else "warn"
    state = status.label.split(": ", 1)[1] if ": " in status.label else "ready"
    tip = "%s - %s" % (status.label, status.detail)
    if not status.ok:
        tip += "\nUntil then the offline rules read your wish."
    return state, tone, tip
def key_where(key_file=None):
    key, where = backends.api_key(key_file)
    if not key:
        return "No key set. Set ANTHROPIC_API_KEY, or paste it here (kept in %s, readable " \
               "only by you)." % backends.key_path()
    return "Key %s from %s." % (backends.mask(key), where)
class Readings:
    def __init__(self):
        self._by = {}
        self.last = None
    @staticmethod
    def _key(text, cfg):
        model = cfg.claude_model if cfg.backend == "claude" else cfg.ollama_model
        return ((text or "").strip(), cfg.backend, model)
    def put(self, reading, cfg):
        self._by[self._key(reading.text, cfg)] = reading
        self.last = reading
    def fresh(self, text, cfg):
        return self._by.get(self._key(text, cfg))
    def clear(self):
        self._by.clear()
        self.last = None
def needs_ask(text, cfg, book):
    return cfg.backend != "offline" and bool((text or "").strip()) and \
        book.fresh(text, cfg) is None
def brief_for(reading, controls, base=None):
    from studio.editor import engine
    raw = copy.deepcopy(reading.raw)
    for k, v in (base or {}).items():
        if k in ("anchors", "objects") and v:
            read = list(raw.get(k) or [])
            raw[k] = read + [b for b in v if not any(
                engine._same_placed(a, b) for a in read)]
        elif k == "name" and v and not raw.get("name"):
            raw["name"] = v
    out, _ = engine.brief_from(controls, None, base=raw)
    if reading.text:
        out["wish"] = reading.text
    return out, reading
def diff_lines(reading):
    if reading is None or reading.used == "offline" or reading.offline is None:
        return []
    rows = diffmod.diff(reading.offline.raw, reading.raw)
    return diffmod.text(rows).splitlines() if rows else []
def reading_lines(reading):
    if reading is None:
        return []
    out = reading.lines()
    d = diff_lines(reading)
    if d:
        out.append("what %s added to the offline reading:" % LABELS[reading.used])
        out += ["  " + line for line in d]
    return out
def explain_text(reading, engine_text):
    if reading is None:
        return engine_text
    head = ["How the wish was read", "  " + "\n  ".join(reading.lines())]
    d = diff_lines(reading)
    if d:
        head.append("What %s changed against the offline parser" % LABELS[reading.used])
        head.append("  " + "\n  ".join(d))
    elif reading.used == "offline" and reading.backend != "offline":
        head.append("(the offline reading stands - see the note above)")
    return "\n".join(head) + "\n\n" + engine_text
def status_line(reading):
    if reading is None:
        return ""
    if reading.fell_back:
        return reading.notes[-1] if reading.notes else "the offline reading is used"
    n = len(diff_lines(reading))
    who = LABELS.get(reading.used, reading.used)
    return "%s read the wish%s" % (who, " - %d change(s) against the offline reading" % n
                                   if n else " the same way as the offline rules")
def refine_ops(text, brief, cfg, client=None, transport=None):
    from mapgen import api
    from mapgen.backends import refiner
    from mapgen.brief import Brief
    if cfg is None or cfg.backend == "offline" or not (text or "").strip():
        return None, []
    r = refiner.read(text, Brief.from_dict(api.raw_of(dict(brief))), cfg, client=client,
                     transport=transport)
    if r.used == "offline":
        return None, r.lines()
    return r.ops, r.lines()
