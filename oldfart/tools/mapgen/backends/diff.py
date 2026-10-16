import copy
import json
from .. import api
from ..brief import BriefError
SKIP = ("wish", "seed", "candidates", "defaulted", "brief")
def normal(raw):
    try:
        b, _ = api.lenient(copy.deepcopy(raw or {}))
        out = api.raw_of(b)
    except (BriefError, Exception):
        out = copy.deepcopy(raw or {})
    for k in SKIP:
        out.pop(k, None)
    for k in [k for k, v in out.items() if v in (None, [], {}, "")]:
        out.pop(k)
    f = out.get("features")
    if isinstance(f, dict) and not (f.get("want") or f.get("avoid")):
        out.pop("features")
    return out
def where_text(w):
    if not isinstance(w, dict):
        return str(w)
    for k in ("compass", "clock", "on", "edge", "aligned", "region"):
        if k in w:
            return "%s %s" % ("at" if k == "compass" else k, w[k])
    if "relation" in w:
        of = w.get("of")
        return "%s %s" % (w["relation"], ", ".join(of) if isinstance(of, list) else of or "")
    if "cell" in w:
        return "cell %s" % (w["cell"],)
    if "x" in w or "z" in w:
        return "x %s z %s" % (w.get("x"), w.get("z"))
    return json.dumps(w, sort_keys=True)
def anchor_text(a):
    if not isinstance(a, dict):
        return str(a)
    n = a.get("count")
    s = "%s%s %s" % ("%d x " % n if isinstance(n, int) and n > 1 else "", a.get("what"),
                     where_text(a.get("where")))
    for k in ("height", "size", "spacing"):
        if k in a:
            s += " %s %s" % (k, a[k])
    return s
def object_text(o):
    if not isinstance(o, dict):
        return str(o)
    return "%d x %s %s" % (o.get("count", 1), o.get("key"), where_text(o.get("where")))
def _value(field, v):
    if field == "anchors":
        return sorted(anchor_text(a) for a in v or [])
    if field == "objects":
        return sorted(object_text(o) for o in v or [])
    return v
def diff(offline_raw, other_raw):
    a, b = normal(offline_raw), normal(other_raw)
    rows = []
    for field in sorted(set(a) | set(b)):
        if field == "features":
            fa, fb = a.get(field) or {}, b.get(field) or {}
            for side in ("want", "avoid"):
                sa, sb = set(fa.get(side) or []), set(fb.get(side) or [])
                for x in sorted(sb - sa):
                    rows.append(("features.%s" % side, None, x, "added"))
                for x in sorted(sa - sb):
                    rows.append(("features.%s" % side, x, None, "removed"))
            continue
        va, vb = _value(field, a.get(field)), _value(field, b.get(field))
        if field in ("anchors", "objects", "modes", "visuals"):
            la, lb = list(va or []), list(vb or [])
            for x in [x for x in lb if x not in la]:
                rows.append((field, None, x, "added"))
            for x in [x for x in la if x not in lb]:
                rows.append((field, x, None, "removed"))
            continue
        if va == vb:
            continue
        kind = "added" if field not in a else "removed" if field not in b else "changed"
        rows.append((field, va, vb, kind))
    return rows
def _show(v):
    return v if isinstance(v, str) else json.dumps(v, ensure_ascii=False, sort_keys=True)
def text(rows, who="the AI"):
    if not rows:
        return "%s read the same brief as the offline parser" % who
    mark = {"added": "+", "removed": "-", "changed": "~"}
    out = []
    for field, old, new, kind in rows:
        if kind == "added":
            out.append("+ %s: %s" % (field, _show(new)))
        elif kind == "removed":
            out.append("- %s: %s" % (field, _show(old)))
        else:
            out.append("%s %s: %s -> %s" % (mark[kind], field, _show(old), _show(new)))
    return "\n".join(out)
