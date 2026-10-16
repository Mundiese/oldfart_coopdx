import copy
from . import anchors as anchormod
from . import checks, solids
from .brief import Brief
MODULES = ("fill", "centre", "unit", "houses", "ground", "lanes", "kit", "track", "course")
class Refused(ValueError):
    pass
def inside(piece, box):
    x0, x1, z0, z1 = box
    return x0 <= piece["x"] < x1 and z0 <= piece["z"] < z1
def _markers(arena, built, box):
    for get, put in ((lambda a: a.get("spawns"), "spawns"),
                     (lambda a: (a.get("survey") or {}).get("points"), "survey")):
        old, new = get(arena), get(built)
        if not isinstance(old, list) or not isinstance(new, list):
            continue
        o_in = [i for i, p in enumerate(old) if isinstance(p, dict) and inside(p, box)]
        n_in = [p for p in new if isinstance(p, dict) and inside(p, box)]
        if not o_in or len(o_in) != len(n_in):
            continue
        out = list(old)
        for i, p in zip(o_in, n_in):
            out[i] = copy.deepcopy(p)
        if put == "spawns":
            arena["spawns"] = out
        else:
            arena["survey"] = dict(arena.get("survey") or {}, points=out)
def _same(a, b):
    import json
    def key(p):
        return json.dumps({k: v for k, v in p.items() if k != "model"}, sort_keys=True)
    return sorted(map(key, a)) == sorted(map(key, b))
def regenerate(brief, layout, box, tries=8, use_metrics=False, progress=None, forge_keys=None):
    from . import api
    from . import refine as refmod
    try:
        b = Brief.from_dict(api.raw_of(brief), forge_keys)
    except Exception as why:
        raise Refused("the map's wish is not a valid brief (%s) - generate the map from a wish "
                      "first" % why)
    index = ((layout or {}).get("generator") or {}).get("candidate", 0)
    old = [dict(p) for p in layout.get("pieces", [])]
    keep = [p for p in old if not inside(p, box)]
    gone = len(old) - len(keep)
    reasons = []
    best = None
    for k in range(1, tries + 1):
        if progress is not None:
            progress(k - 1, tries, "region: try %d of %d" % (k, tries))
        rs = dict(b["reseed"])
        for m in MODULES:
            rs[m] = rs.get(m, 0) + 97 * k
        trial = b.with_changes(reseed=rs)
        try:
            cand, _, _ = refmod._build(trial, index, use_metrics)
        except anchormod.Refused as why:
            raise Refused(str(why))
        if not cand.ok:
            reasons.append("try %d: the rebuilt map failed its own checks" % k)
            continue
        fresh = [dict(p) for p in cand.arena["pieces"] if inside(p, box)]
        if _same(fresh, [p for p in old if inside(p, box)]):
            reasons.append("try %d: the same pieces came back" % k)
            continue
        painted, _ = solids.resolve(keep + fresh)
        arena = copy.deepcopy(layout)
        arena["pieces"] = painted
        _markers(arena, cand.arena, box)
        arena.setdefault("key", "generated")
        res = checks.run(arena)
        if not res.ok:
            reasons.append("try %d: %s" % (k, res.faults[0]))
            continue
        quality = (cand.quality if use_metrics else 0) or 0
        if best is None or quality > best[0]:
            best = (quality, arena, k, len(fresh))
        if not use_metrics:
            break
    if best is None:
        if reasons and all("same pieces" in r for r in reasons):
            raise Refused("the family builds this part the same way on every roll (%d tries) - "
                          "change the wish, or edit it by hand" % tries)
        raise Refused("no try of %d gave a region that fits: %s" % (tries, "; ".join(reasons[:3])))
    _, arena, k, n = best
    notes = ["region rebuilt (try %d): %d pieces out, %d in, %d kept outside"
             % (k, gone, n, len(keep))]
    arena.pop("key", None) if "key" not in layout else None
    return arena, notes
