import json
import os
import time
MAX_ENTRIES = 200
REJECT_FOR = 5
WEIGHTS = {"formation": 3.0, "theme": 1.0, "preset": 1.0, "size": 1.0, "symmetry": 0.5,
           "about": 1.0, "features": 1.0, "descriptors": 1.5}
SIZE_ORDER = ("tiny", "small", "medium", "large", "huge", "gigantic")
def user_path():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "oldfart-studio", "mapgen-history.json")
_test_file = []
def under_test():
    import sys
    if "unittest" not in sys.modules:
        return False
    main = getattr(sys.modules.get("__main__"), "__file__", "") or ""
    main = main.replace("\\", "/")
    return (main.endswith("unittest/__main__.py") or "/tests/" in main
            or os.path.basename(main).startswith("test_") or main.endswith("selftest.py"))
def path():
    p = os.environ.get("MAPGEN_HISTORY")
    if p:
        return p
    if under_test():
        if not _test_file:
            import atexit
            import tempfile
            fd, name = tempfile.mkstemp(prefix="mapgen-history-test-", suffix=".json")
            os.close(fd)
            os.remove(name)
            _test_file.append(name)
            atexit.register(lambda: os.path.exists(name) and os.remove(name))
        return _test_file[0]
    return user_path()
def load(p=None):
    p = p or path()
    try:
        with open(p, encoding="utf-8") as handle:
            h = json.load(handle)
        if isinstance(h, dict):
            h.setdefault("entries", [])
            h.setdefault("rejects", [])
            h.setdefault("count", len(h["entries"]))
            return h
    except (OSError, ValueError):
        pass
    return {"entries": [], "rejects": [], "count": 0}
def save(h, p=None):
    p = p or path()
    d = os.path.dirname(p)
    if d:
        os.makedirs(d, exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(h, handle, indent=1, sort_keys=True)
    os.replace(tmp, p)
def forget(p=None):
    p = p or path()
    try:
        os.remove(p)
        return True
    except OSError:
        return False
def entry_of(arena, brief, summary=None, descriptors=None):
    summary = summary or {}
    size = brief["size"] if isinstance(brief["size"], str) else "medium"
    return {"family": brief["family"],
            "formation": str(summary.get("skeleton") or summary.get("shape") or "-"),
            "symmetry": str((arena.get("report") or {}).get("symmetry_solved")
                            or brief["symmetry"]),
            "theme": brief["theme"], "preset": brief["preset"], "size": size,
            "about": summary.get("about") or "",
            "features": sorted(brief["features"]["want"]),
            "descriptors": {k: round(float(v), 3) for k, v in (descriptors or {}).items()
                            if isinstance(v, (int, float))},
            "seed": brief["seed"], "time": int(time.time())}
def record(arena, brief, summary=None, descriptors=None, p=None):
    h = load(p)
    e = entry_of(arena, brief, summary, descriptors)
    h["entries"] = (h["entries"] + [e])[-MAX_ENTRIES:]
    h["count"] = h.get("count", 0) + 1
    fam_count = sum(1 for x in h["entries"] if x["family"] == e["family"])
    for rj in h["rejects"]:
        if rj["family"] == e["family"]:
            rj["left"] = max(0, rj.get("left", REJECT_FOR) - 1)
    h["rejects"] = [rj for rj in h["rejects"] if rj.get("left", 0) > 0]
    e["n"] = fam_count
    save(h, p)
    return e
def reject(aspects, p=None, family=None):
    h = load(p)
    last = [e for e in h["entries"] if family is None or e["family"] == family]
    if not last:
        return []
    e = last[-1]
    out = []
    for a in aspects:
        vals = e.get(a)
        for v in (vals if isinstance(vals, list) else [vals]):
            if v in (None, "", "-", "auto"):
                continue
            h["rejects"].append({"family": e["family"], "aspect": a, "value": v,
                                 "left": REJECT_FOR})
            out.append((a, v))
    save(h, p)
    return out
def banned(family, aspect, p=None):
    return sorted(set(rj["value"] for rj in load(p)["rejects"]
                      if rj["family"] == family and rj["aspect"] == aspect
                      and rj.get("left", 0) > 0))
def recent(family=None, n=10, p=None):
    es = [e for e in load(p)["entries"] if family is None or e["family"] == family]
    return es[-n:]
def counts(aspect, family=None, p=None):
    out = {}
    for e in recent(family, 50, p):
        v = e.get(aspect)
        for x in (v if isinstance(v, list) else [v]):
            out[x] = out.get(x, 0) + 1
    return out
def _cat(a, b):
    return 0.0 if a == b else 1.0
def distance(a, b):
    parts = []
    parts.append((WEIGHTS["formation"], _cat(a.get("formation"), b.get("formation"))))
    parts.append((WEIGHTS["theme"], _cat(a.get("theme"), b.get("theme"))))
    parts.append((WEIGHTS["preset"], _cat(a.get("preset"), b.get("preset"))))
    sa, sb = a.get("size"), b.get("size")
    if sa in SIZE_ORDER and sb in SIZE_ORDER:
        parts.append((WEIGHTS["size"], abs(SIZE_ORDER.index(sa) - SIZE_ORDER.index(sb)) / 2.0
                      if sa != sb else 0.0))
    parts.append((WEIGHTS["symmetry"], _cat(a.get("symmetry"), b.get("symmetry"))))
    parts.append((WEIGHTS["about"], _cat(a.get("about"), b.get("about"))))
    fa, fb = set(a.get("features") or []), set(b.get("features") or [])
    if fa or fb:
        parts.append((WEIGHTS["features"], 1.0 - len(fa & fb) / float(len(fa | fb))))
    da, db = a.get("descriptors") or {}, b.get("descriptors") or {}
    shared = sorted(set(da) & set(db))
    if shared:
        parts.append((WEIGHTS["descriptors"],
                      min(1.0, sum(abs(da[k] - db[k]) for k in shared) / len(shared) * 2)))
    total = sum(w for w, _ in parts)
    return round(sum(w * min(1.0, v) for w, v in parts) / total, 3) if total else 1.0
def novelty(entry, p=None, n=10, entries=None):
    es = entries if entries is not None else recent(entry["family"], n, p)
    if not es:
        return 1.0, None
    best = min(es, key=lambda e: distance(entry, e))
    return distance(entry, best), best
