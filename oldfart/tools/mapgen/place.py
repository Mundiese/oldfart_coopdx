import math
from . import v1
FEATURE_TAGS = {
    "bridge": ("bridge", "causeway", "twin", "lane"), "bridges": ("bridge", "causeway", "lane"),
    "tower": ("tower", "perch", "crown_high"), "towers": ("tower", "perch", "crown_high"),
    "perch": ("perch",), "perches": ("perch",), "crown": ("crown",), "pit": ("pit",),
    "base": ("bastion",), "bases": ("bastion",), "centre": ("centre",), "middle": ("centre",),
    "island": ("island",), "plaza": ("plaza", "bandstand"), "hill": ("crown", "bandstand"),
}
RAMP_KINDS = ("ramp", "stairs", "outer", "inner", "outerstairs", "innerstairs")
def _foot(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw", 0))) % 180 == 90:
        w, d = d, w
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def bounds(arena):
    fs = [_foot(p) for p in arena["pieces"]
          if not str(p.get("tag", "")).startswith("dress.backdrop")] or \
        [_foot(p) for p in arena["pieces"]]
    return (min(f[0] for f in fs), max(f[1] for f in fs), min(f[2] for f in fs),
            max(f[3] for f in fs))
_stand_cache = {}
def standing_points(arena, step=200, margin=200):
    m = v1.arenas_module()
    key = (id(arena["pieces"]), len(arena["pieces"]), step, margin,
           sum(p["x"] + 3 * p["z"] + 7 * p["y"] for p in arena["pieces"]))
    if key in _stand_cache:
        return _stand_cache[key]
    cells, edges = m.walk_graph(arena)
    grid = m.GRID
    if arena.get("spawns"):
        first = m.spawn_cell(arena["spawns"][0])
        if first in cells:
            live = m.reach(edges, first) & m.reach(edges, first, reverse=True)
        else:
            live = set(cells)
    else:
        live = set(cells)
    heights = {}
    for (gx, gz, h) in live:
        heights.setdefault((gx, gz), set()).add(h)
    k = max(1, int(step // grid))
    r = int(round(margin / grid))
    out = []
    pieces = arena["pieces"]
    tile = 1000.0
    buckets = {}
    for p in pieces:
        f = _foot(p)
        for tx in range(int(math.floor(f[0] / tile)), int(math.floor(f[1] / tile)) + 1):
            for tz in range(int(math.floor(f[2] / tile)), int(math.floor(f[3] / tile)) + 1):
                buckets.setdefault((tx, tz), []).append((p, f))
    for (gx, gz, h) in sorted(live):
        if gx % k or gz % k:
            continue
        if r and not all(h in heights.get((gx + dx, gz + dz), ()) for dx, dz in
                   ((r, 0), (-r, 0), (0, r), (0, -r))):
            continue
        x, z = gx * grid + grid / 2.0, gz * grid + grid / 2.0
        owner = None
        for p, (fx0, fx1, fz0, fz1) in buckets.get((int(math.floor(x / tile)),
                                                     int(math.floor(z / tile))), ()):
            if fx0 < x < fx1 and fz0 < z < fz1 and m.covers(p, x, z):
                t = m.top_at(p, x, z)
                if t is not None and abs(t - h) <= 1:
                    owner = p
                    break
        if owner is not None and any(w in str(owner.get("tag", "")) for w in
                                     ("rail", "merlon", "keel")):
            continue
        out.append((x, h, z, owner))
    _stand_cache.clear()
    _stand_cache[key] = out
    return out
def region_filter(where, arena, solved=None):
    x0, x1, z0, z1 = bounds(arena)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    half = max(x1 - x0, z1 - z0) / 2.0
    where = dict(where or {})
    def uv(x, z):
        return (x - cx) / half, (z - cz) / half
    def rad(x, z):
        u, v = uv(x, z)
        return max(abs(u), abs(v))
    def sector(x, z, ang, width):
        u, v = uv(x, z)
        if abs(u) < 1e-9 and abs(v) < 1e-9:
            return False
        a = math.degrees(math.atan2(u, -v)) % 360
        return abs((a - ang + 180) % 360 - 180) <= width
    comp = where.get("compass")
    feat = where.get("on") or where.get("along") or (
        where.get("of") if where.get("relation") in ("on", "along", "above") else None)
    if isinstance(feat, list):
        feat = feat[0] if feat else None
    if feat in ("ramps", "ramp", "stairs", "slopes"):
        return lambda x, z, p: p is not None and p["kind"] in RAMP_KINDS
    if feat in FEATURE_TAGS:
        tags = FEATURE_TAGS[feat]
        tagged = [p for p in arena["pieces"] if any(t in str(p.get("tag", "")) for t in tags)]
        if not tagged and feat in ("bridge", "bridges"):
            tagged = [p for p in arena["pieces"] if _is_bridge(p, arena["pieces"])]
        ids = set(id(p) for p in tagged)
        return lambda x, z, p: p is not None and id(p) in ids
    if where.get("relation") in ("next_to", "near", "around") and where.get("of"):
        of = where["of"] if isinstance(where["of"], str) else where["of"][0]
        pts = (solved or {}).get(of)
        if pts:
            return lambda x, z, p: any(300 <= math.hypot(x - a, z - b) <= 1400 for a, b in pts)
        if of in FEATURE_TAGS:
            tags = FEATURE_TAGS[of]
            near = [_foot(p) for p in arena["pieces"] if any(t in str(p.get("tag", ""))
                                                             for t in tags)]
            return lambda x, z, p: any(f[0] - 600 <= x <= f[1] + 600 and f[2] - 600 <= z <= f[3] + 600
                                       for f in near) and not (
                p is not None and any(t in str(p.get("tag", "")) for t in tags))
    if comp in ("corners", "corner"):
        return lambda x, z, p: rad(x, z) >= 0.5 and any(sector(x, z, a, 25)
                                                         for a in (45, 135, 225, 315))
    if comp in ("edge", "edges", "ring") or where.get("edge") or where.get("relation") == "edge":
        return lambda x, z, p: min(x - x0, x1 - x, z - z0, z1 - z) <= 800
    if comp == "c" or where.get("relation") == "middle" or where.get("region") == "centre":
        return lambda x, z, p: rad(x, z) <= 0.25
    angles = {"n": 0, "ne": 45, "e": 90, "se": 135, "s": 180, "sw": 225, "w": 270, "nw": 315}
    if comp in angles:
        return lambda x, z, p: rad(x, z) >= 0.4 and sector(x, z, angles[comp], 30)
    if "clock" in where:
        ang = (int(where["clock"]) % 12) * 30
        return lambda x, z, p: rad(x, z) >= 0.25 and sector(x, z, ang, 20)
    if "x" in where and "z" in where:
        tx, tz = float(where["x"]), float(where["z"])
        return lambda x, z, p: math.hypot(x - tx, z - tz) <= 400
    if where.get("region") in (None, "field", "anywhere") or where.get("anywhere"):
        return lambda x, z, p: True
    return None
def _is_bridge(p, pieces):
    if p["kind"] != "box":
        return False
    x0, x1, z0, z1 = _foot(p)
    w, d = x1 - x0, z1 - z0
    if min(w, d) > 1000 or max(w, d) < 3 * min(w, d):
        return False
    mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    for q in pieces:
        if q is p:
            continue
        a0, a1, b0, b1 = _foot(q)
        if a0 < mx < a1 and b0 < mz < b1 and q["y"] + q["h"] <= p["y"]:
            return False
    return True
def _margin(where):
    w = where or {}
    if w.get("on") or w.get("along") or w.get("relation") in ("on", "along", "above"):
        return 0
    return 200
def spread(points, n, start=None):
    if not points or n <= 0:
        return []
    pts = list(points)
    if start is None:
        first = min(pts, key=lambda p: (p[0], p[2]))
    else:
        first = min(pts, key=lambda p: (math.hypot(p[0] - start[0], p[2] - start[1]), p[0], p[2]))
    chosen = [first]
    best = {i: math.hypot(p[0] - first[0], p[2] - first[2]) for i, p in enumerate(pts)}
    while len(chosen) < min(n, len(pts)):
        i = max(best, key=lambda k: (best[k], -k))
        if best[i] <= 0:
            break
        q = pts[i]
        chosen.append(q)
        for k, p in enumerate(pts):
            d = math.hypot(p[0] - q[0], p[2] - q[2])
            if d < best[k]:
                best[k] = d
    return chosen
def _yaw_to(x, z, cx, cz):
    a = math.degrees(math.atan2(cx - x, cz - z)) % 360
    return int(round(a / 45.0) * 45) % 360
def respawn(arena, where, count=16, checks_run=None):
    pred = region_filter(where, arena)
    if pred is None:
        return "approximated", "no spawn region %r in the anchor language" % (where,)
    x0, x1, z0, z1 = bounds(arena)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    if _margin(where) and arena.get("spawns") and all(
            pred(s["x"], s["z"], None) for s in arena["spawns"]):
        return "placed", "the %d spawns already stand %s (the family's, kept)" % (
            len(arena["spawns"]), _say(where))
    cands = [(x, h, z) for (x, h, z, p) in standing_points(arena, margin=_margin(where)) if pred(x, z, p)]
    if len(cands) < count:
        return "approximated", "only %d standing points in %s for %d spawns" % (
            len(cands), _say(where), count)
    old = arena["spawns"]
    picked = spread(cands, count, start=(old[0]["x"], old[0]["z"]) if old else None)
    new = [{"x": int(x), "y": int(h), "z": int(z), "yaw": _yaw_to(x, z, cx, cz)}
           for (x, h, z) in picked]
    keep_spawns, keep_survey = arena["spawns"], dict(arena.get("survey") or {})
    pts = list(keep_survey.get("points") or [])
    field = [s for s in pts[len(old):] if all(math.hypot(s["x"] - n["x"], s["z"] - n["z"]) >= 300
                                               for n in new)]
    arena["spawns"] = new
    survey = dict(keep_survey)
    survey["points"] = new + field[:max(0, 28 - len(new))]
    arena["survey"] = survey
    if checks_run is not None:
        res = checks_run(arena)
        if not res.ok:
            arena["spawns"], arena["survey"] = keep_spawns, keep_survey
            return "approximated", "spawns %s fail the hard checks (%s); kept the family's" % (
                _say(where), "; ".join(res.faults[:2]))
    return "placed", "%d spawns re-picked %s, spread out, facing the middle" % (len(new),
                                                                                _say(where))
def _say(where):
    if "on" in where:
        return "on the %s" % where["on"]
    if where.get("relation") in ("on", "along") and where.get("of"):
        return "on the %s" % where["of"]
    if where.get("compass") in ("edge", "edges", "ring") or where.get("edge"):
        return "at the edge"
    if where.get("compass") == "corners":
        return "in the corners"
    if "compass" in where:
        return "in the %s" % where["compass"]
    return "where asked"
def blocks_for_trees(objects, theme=None, seed=0):
    import random
    from . import flora, landscape
    theme = theme if theme in landscape.THEME_BIOMES else "garden"
    sparse = []
    for b in landscape.THEME_BIOMES[theme]:
        sparse += [sp for sp, _ in (landscape.BIOMES.get(b) or {}).get("sparse") or ()
                   if sp not in ("bush",)]
    sparse = sparse or ["oak"]
    keep, pieces = [], []
    for k, o in enumerate(objects or ()):
        if o.get("key") != "tree":
            keep.append(o)
            continue
        rnd = random.Random("%s/wished tree/%d/%d/%d" % (seed, k, o["x"], o["z"]))
        sp = sparse[rnd.randrange(len(sparse))]
        cx, cz = int(round(o["x"] / 50.0) * 50), int(round(o["z"] / 50.0) * 50)
        pieces += flora.build(sp, cx, cz, int(o.get("y", 0)), rnd, room=200,
                              tag="tree.wished")
    return keep, pieces
def place_objects(arena, requests, solved=None, budget=None):
    if not requests:
        return [], []
    budget = budget if budget is not None else arena.get("budget", 120)
    room = budget - len(arena["pieces"]) - len(arena.get("markers", []))
    x0, x1, z0, z1 = bounds(arena)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    pass
    taken = [(s["x"], s["z"]) for s in arena.get("spawns", [])]
    placed, lines = [], []
    for i, req in enumerate(requests):
        rid = "object%d %s" % (i + 1, req["key"])
        n = int(req.get("count", 1))
        if room <= 0:
            lines.append(("refused", rid, "no room left in the object budget (%d)" % budget))
            continue
        if n > room:
            lines.append(("approximated", rid, "%d asked, %d fit the object budget of %d"
                          % (n, room, budget)))
            n = room
        where = req.get("where") or {}
        pred = region_filter(where, arena, solved)
        if pred is None:
            lines.append(("refused", rid, "no region %r in the anchor language" % (where,)))
            continue
        stand = standing_points(arena, margin=_margin(where))
        cands = [(x, h, z) for (x, h, z, p) in stand if pred(x, z, p)
                 and all(math.hypot(x - a, z - b) >= 300 for a, b in taken)]
        got = spread(cands, n, start=(cx, cz))
        for (x, h, z) in got:
            row = {"key": req["key"], "what": req["key"], "x": int(x), "y": int(h),
                   "z": int(z), "yaw": _yaw_to(x, z, cx, cz),
                   "modes": list(req.get("modes") or [])}
            if req["key"] == "coins":
                from . import kit
                row["formation"] = req.get("formation") or "ring"
                row["variant"] = kit.coin_variant(row["formation"])
            placed.append(row)
            taken.append((x, z))
        room -= len(got)
        if len(got) == n and n == int(req.get("count", 1)):
            lines.append(("placed", rid, "%d %s %s" % (n, req["key"], _say(where))))
        elif got:
            lines.append(("approximated", rid, "%d of %d %s %s (no more clear standing room)"
                          % (len(got), int(req.get("count", 1)), req["key"], _say(where))))
        else:
            lines.append(("refused", rid, "no clear standing point %s" % _say(where)))
    return placed, lines
