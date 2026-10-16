import json
import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "vocab.json")
_data = None
SKIP_VALUES = {"auto"}
def data():
    global _data
    if _data is None:
        with open(PATH, encoding="utf-8") as fh:
            _data = json.load(fh)
    return _data
def rows():
    out = list(data()["rows"])
    have = set(r["value"] for r in out if r["param"] == "mode")
    try:
        from . import modes
        for key, name in sorted(modes.all().items()):
            if key not in have:
                out.append({"param": "mode", "value": key, "en": [name], "de": [name],
                            "proper": True})
    except Exception:
        pass
    return out
def params():
    from . import brief, modes, presets, skies
    out = {
        "family": list(brief.FAMILIES), "theme": list(brief.THEMES),
        "size": list(brief.SIZES), "verticality": list(brief.VERTICALITIES),
        "density": list(brief.DENSITIES), "pace": list(brief.PACES),
        "difficulty": list(brief.DIFFICULTIES), "symmetry": list(brief.SYMMETRIES),
        "sides": list(brief.SIDES), "edge": list(brief.EDGES),
        "boundary": list(brief.BOUNDARIES), "level": list(brief.LEVELS),
        "ground": list(brief.GROUNDS), "variety": list(brief.VARIETIES),
        "sky": skies.names(), "visuals": list(brief.VISUALS),
        "preset": [p["key"] for p in presets.all_presets()],
        "feature": list(brief.FEATURES), "forge_off": list(brief.FORGE_OFF),
        "novelty": [m for m in brief.NOVELTY_MODES if m != "reject"],
        "mode": sorted(modes.all()),
    }
    return {k: [v for v in vs if v not in SKIP_VALUES] for k, vs in out.items()}
def setting(param, value):
    if param == "mode":
        return {"modes": [value]}
    if param == "feature":
        return {"want": [value]}
    if param in ("visuals", "forge_off"):
        return {param: [value]}
    if param == "novelty":
        return {"novelty": {"mode": value}}
    return {param: value}
def row_of(param, value):
    for r in rows():
        if r["param"] == param and r["value"] == value:
            return r
    return None
def missing():
    out = []
    for p, values in sorted(params().items()):
        for v in values:
            r = row_of(p, v)
            for lang in ("en", "de"):
                if r is None or not [f for f in r.get(lang) or [] if f.strip()]:
                    out.append((p, v, lang))
    return out
def template(param, lang):
    t = data()["templates"].get(param) or ["{}", "{}"]
    return t[0] if lang == "en" else t[1]
def surface(form):
    return form.lstrip("~").split("(")[0].strip()
def holds(param, value, raw):
    if param == "mode":
        return value in (raw.get("modes") or [])
    if param == "feature":
        return value in ((raw.get("features") or {}).get("want") or [])
    if param in ("visuals", "forge_off"):
        return value in (raw.get(param) or [])
    if param == "novelty":
        return (raw.get("novelty") or {}).get("mode") == value
    got = raw.get(param)
    return str(got) == str(value)
def misread(lang=None):
    from . import wish
    out = []
    for r in rows():
        for lg in ("en", "de"):
            if lang and lg != lang:
                continue
            for form in r.get(lg) or []:
                text = template(r["param"], lg).format(surface(form))
                try:
                    raw = wish.understand(text).raw
                except Exception as why:
                    out.append((r["param"], r["value"], lg, form, "raised %s" % why))
                    continue
                if not holds(r["param"], r["value"], raw):
                    out.append((r["param"], r["value"], lg, form, "read as %s" % json.dumps(
                        {k: v for k, v in raw.items() if k not in ("wish", "seed")},
                        sort_keys=True)[:160]))
    return out
DE_WORDS = re.compile(r"\b(und|mit|ohne|eine?n?|der|die|das|den|dem|viele|wenig|nicht|kein\w*|"
                      r"auf|im|am|in der|gross|klein|sehr|bitte|ich|mach|baue?|welt|karte|"
                      r"mehr|weniger)\b|[äöüß]|ae|oe|ue")
EN_WORDS = re.compile(r"\b(and|with|without|a|an|the|many|lots|few|not|no|on|in the|big|small|"
                      r"very|please|make|build|world|map|more|less)\b")
def language(text):
    low = (text or "").lower()
    de = len(DE_WORDS.findall(low))
    en = len(EN_WORDS.findall(low))
    return "de" if de > en else "en"
_rx = []
EXCEPT_AFTER = re.compile(r"\s*,?\s*(ausser|ausgenommen|bis auf|abgesehen von|except|but for|"
                          r"apart from|other than|besides)\b")
ARTICLES = {"a", "an", "the", "ein", "eine", "einen", "einem", "einer", "eines", "der", "die",
            "das", "den", "dem", "des"}
def _patterns():
    if _rx:
        return _rx
    from .wish import fold
    out = []
    for r in rows():
        for lg in ("en", "de"):
            for form in r.get(lg) or []:
                text = fold(surface(form)).replace("-", " ")
                words = text.split()
                while len(words) > 1 and words[0] in ARTICLES:
                    words = words[1:]
                if len(words) == 1 and (words[0] in _number_words() or words[0].isdigit()):
                    words = text.split()
                if not words:
                    continue
                last = words[-1]
                if lg == "de" and not form.startswith("~") and len(last) > 5:
                    for end in ("ern", "en", "er", "e", "n"):
                        if last.endswith(end) and len(last) - len(end) >= 4:
                            last = last[:-len(end)]
                            break
                    words = words[:-1] + [last]
                    tail = r"(?:e|en|n|er|ern|es|s)?"
                elif form.startswith("~"):
                    tail = r"(?:e|er|es|en|em)?"
                else:
                    tail = r"(?:s|es)?"
                parts = []
                for k, w in enumerate(words):
                    if lg == "de" and k < len(words) - 1 and len(w) > 4:
                        for end in ("es", "er", "en", "em", "e"):
                            if w.endswith(end) and len(w) - len(end) >= 3:
                                w = w[:-len(end)]
                                break
                        parts.append(re.escape(w) + r"(?:e|er|es|en|em)?")
                    else:
                        parts.append(re.escape(w))
                body = r"[\s\-]+".join(parts)
                out.append((re.compile(r"(?<![a-z0-9])%s%s(?![a-z0-9])" % (body, tail)), r,
                            form, words))
    out.sort(key=lambda t: -len(" ".join(t[3])))
    _rx.extend(out)
    return _rx
def _number_words():
    from .wish import NUMBERS
    return set(NUMBERS)
def apply(r, text):
    from .wish import _negated, _take_negation, fold
    low = fold(text)
    raw = r.raw
    taken = []
    consumed = list(r.consumed)
    for rx, row, form, words in _patterns():
        for m in rx.finditer(low):
            if any(a <= m.start() < b and (pp == row["param"] or row["param"] != "mode")
                   for a, b, pp in taken):
                continue
            if row["param"] not in ("feature", "mode") and any(
                    a <= m.start() and m.end() <= b and b - a > m.end() - m.start()
                    for a, b in consumed):
                continue
            taken.append((m.start(), m.end(), row["param"]))
            p, v = row["param"], row["value"]
            neg = _negated(low, m.start())
            r.take(m)
            if neg:
                _take_negation(r, low, m.start())
            if p == "feature":
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                feats.setdefault("want", [])
                feats.setdefault("avoid", [])
                side = "avoid" if neg else "want"
                if v not in feats["want"] and v not in feats["avoid"]:
                    feats[side].append(v)
                    r.said("%s %s" % (side, v))
            elif neg:
                continue
            elif p == "forge_off" and EXCEPT_AFTER.match(low[m.end():]):
                continue
            elif p == "mode":
                from . import modes
                lst = raw.setdefault("modes", [])
                if v not in lst:
                    lst.append(v)
                    r.said("mode %s" % v)
                fam = modes.family_of(v)
                if fam:
                    raw.setdefault("family", fam)
            elif p in ("visuals", "forge_off"):
                lst = raw.setdefault(p, [])
                if v not in lst:
                    lst.append(v)
                    r.said("%s %s" % (p, v))
            elif p == "novelty":
                nov = dict(raw.get("novelty") or {})
                nov.setdefault("mode", v)
                raw["novelty"] = nov
            else:
                if p not in raw or (len(words) > 1 and str(raw[p]) != str(v)):
                    raw[p] = v
                    r.said("%s %s" % (p, v))
            words_here = set(low[m.start():m.end()].split())
            r.not_understood = [w for w in r.not_understood
                                if not set(fold(str(w)).split()) <= words_here]
            for k, val in (row.get("also") or {}).items():
                if isinstance(val, dict):
                    d = raw.setdefault(k, {})
                    for kk, vv in val.items():
                        d.setdefault(kk, vv)
                else:
                    raw.setdefault(k, val)
    return r
PARAM_NAMES = {
    "family": ("map kind", "Kartenart"), "theme": ("theme", "Thema"), "size": ("size", "Groesse"),
    "verticality": ("height", "Hoehe"), "density": ("cover", "Deckung"),
    "pace": ("pace", "Tempo"), "difficulty": ("difficulty", "Schwierigkeit"),
    "symmetry": ("symmetry", "Symmetrie"), "sides": ("teams", "Teams"),
    "edge": ("edge", "Rand"), "boundary": ("map edge", "Kartenrand"), "level": ("level", "Level"),
    "ground": ("ground", "Boden"), "variety": ("variety", "Vielfalt"), "sky": ("sky", "Himmel"),
    "visuals": ("mood", "Stimmung"), "preset": ("preset", "Vorlage"),
    "forge_off": ("off", "aus"), "novelty": ("novelty", "Neuheit"),
    "modes": ("for", "fuer"),
}
SUMMARY_WORDS = {"en": ("Understood", "with", "without", "nothing yet"),
                 "de": ("Verstanden", "mit", "ohne", "noch nichts")}
PARTLY = {"en": "Partly understood", "de": "Teilweise verstanden"}
STARS_WORDS = {"en": ("bonus stars", "mood"), "de": ("Bonussterne", "Stimmung")}
def summary(raw, lang="en", partly=False):
    lang = "de" if lang == "de" else "en"
    head, with_, without, nothing = SUMMARY_WORDS[lang]
    if partly:
        head = PARTLY[lang]
    i = 0 if lang == "en" else 1
    parts = []
    for p in ("family", "preset", "theme", "size", "verticality", "density", "pace",
              "difficulty", "symmetry", "sides", "edge", "boundary", "level", "ground",
              "variety", "sky"):
        if p in raw and raw[p] not in (None, "auto"):
            parts.append("%s %s" % (PARAM_NAMES[p][i], label(p, raw[p], lang)))
    for p in ("visuals", "forge_off"):
        vals = raw.get(p) or []
        if vals:
            parts.append("%s %s" % (PARAM_NAMES[p][i], ", ".join(label(p, v, lang) for v in vals)))
    feats = raw.get("features") or {}
    if feats.get("want"):
        parts.append("%s %s" % (with_, ", ".join(label("feature", v, lang)
                                                 for v in feats["want"])))
    if feats.get("avoid"):
        parts.append("%s %s" % (without, ", ".join(label("feature", v, lang)
                                                   for v in feats["avoid"])))
    stars = next((q.get("count") for q in raw.get("requests") or ()
                  if isinstance(q, dict) and q.get("kind") == "stars" and q.get("count")), None)
    if stars:
        parts.append("%d %s" % (stars, STARS_WORDS[lang][0]))
    objs = [o for o in raw.get("objects") or () if isinstance(o, dict) and o.get("key")]
    if objs:
        parts.append(", ".join("%s x%d" % (o["key"], o.get("count") or 1) for o in objs))
    return "%s: %s" % (head, "; ".join(parts) if parts else nothing)
def label(param, value, lang="en"):
    r = row_of(param, value)
    if r and r.get(lang):
        words = surface(r[lang][0]).split()
        while len(words) > 1 and words[0] in ARTICLES:
            words = words[1:]
        return " ".join(words)
    return str(value)
