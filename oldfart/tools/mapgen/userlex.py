import json
import os
import re
import time
APP = "oldfart-studio"
_cache = {"path": None, "mtime": None, "data": None}
def path():
    env = os.environ.get("OLDFART_USER_LEXICON")
    if env == "off":
        return None
    if env:
        return env
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, APP, "lexicon-user.json")
def _fold(t):
    from .wish import fold
    return re.sub(r"\s+", " ", fold(t).replace("-", " ")).strip()
def _load():
    p = path()
    try:
        mt = os.path.getmtime(p)
    except (OSError, TypeError):
        return {"version": 1, "words": {}}
    if _cache["path"] == p and _cache["mtime"] == mt:
        return _cache["data"]
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict) or not isinstance(data.get("words"), dict):
            raise ValueError
    except (OSError, ValueError):
        data = {"version": 1, "words": {}}
    _cache.update(path=p, mtime=mt, data=data)
    return data
def _save(data):
    p = path()
    if p is None:
        raise TeachError("the taught-words store is switched off (OLDFART_USER_LEXICON=off)")
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    os.replace(tmp, p)
    _cache.update(path=None, mtime=None, data=None)
def words():
    return dict(_load()["words"])
class TeachError(ValueError):
    pass
def teach(word, meaning):
    from . import wish
    w = _fold(word)
    m = (meaning or "").strip()
    if not w or not m or len(w) > 60:
        raise TeachError("say a word and what it means")
    if _fold(m) == w:
        raise TeachError("'%s' cannot mean itself" % word)
    data = _load()
    old = data["words"].pop(w, None)
    _cache.update(data=data)
    try:
        r = wish.understand(m)
    finally:
        if old is not None:
            data["words"][w] = old
    if not r.understood:
        raise TeachError("'%s' says nothing the reader understands - say it with words it "
                         "knows (not understood: %s)" % (m, "; ".join(r.not_understood) or m))
    data = json.loads(json.dumps(_load()))
    data["words"][w] = {"means": m, "reads": list(r.understood),
                        "taught": time.strftime("%Y-%m-%d")}
    _save(data)
    return list(r.understood)
def forget(word):
    data = json.loads(json.dumps(_load()))
    gone = data["words"].pop(_fold(word), None)
    if gone is not None:
        _save(data)
    return gone is not None
def rewrite(low):
    ws = _load()["words"]
    if not ws:
        return low, []
    used = []
    for w in sorted(ws, key=len, reverse=True):
        rx = r"(?<![a-z0-9])%s(?:e|en|er|es|em|n|s)?(?![a-z0-9])" % r"[ -]".join(
            re.escape(p) for p in w.split(" "))
        if re.search(rx, low):
            meaning = re.sub(r"[,;.!?]+", " ", _fold(ws[w]["means"]))
            low = re.sub(rx, lambda m: " %s " % meaning, low)
            used.append((w, ws[w]["means"]))
    return re.sub(r"[ \t]+", " ", low).strip(), used
def parse_teach(text):
    t = (text or "").strip()
    m = re.match(r"^\s*[\"'„“‚‘](?P<w>[^\"'“”‘’]{1,60})[\"'“”‘’]\s*(?:bedeutet|heisst|heißt|"
                 r"meint|means|=)\s+(?P<m>.+?)\s*$", t, re.I)
    if not m:
        m = re.match(r"^\s*(?P<w>[^=]{1,60}?)\s*=\s*(?P<m>.+?)\s*$", t)
    if not m:
        return None
    return m.group("w").strip(), m.group("m").strip()
def export(out_path):
    from . import wish
    concepts = []
    for w, e in sorted(_load()["words"].items()):
        r = wish.understand(e["means"])
        raw = {k: v for k, v in r.raw.items() if k != "wish"}
        concepts.append({"id": "user." + re.sub(r"[^a-z0-9]+", "_", w), "source": "taught",
                         "means": e["means"], "set": raw, "say": "'%s' (taught): %s"
                         % (w, e["means"]), "forms": [w], "taught": e.get("taught")})
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"about": "Words taught in the Studio, as lexicon "
                            "concepts for review; merge the good ones into "
                            "tools/mapgen/lexicon.json", "concepts": concepts}, f,
                  ensure_ascii=False, indent=1)
    return len(concepts)
