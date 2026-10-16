import math
CONE_HALF = 30.0
CONE_H = 4000
CANNON_RISE = 340
REACH_TOL = 400
MOUND_REACH = 1300
OWN_TAGS = ("play.cannon.well", "play.cannon.mound")
DRESSING = ("scatter.", "tree", "flora.", "detail.", "decor.t3", "decor.node", "decor.odd",
            "decor.pointer")
ISLAND_TAGS = ("play.cannon.island", "setpiece.island")
AIM_TOL = 25.0
SHOT_REACH = 6000
GENERATED = ("cannon_shortcut", "setpiece.island")
def cannons(arena, generated=True):
    return [o for o in arena.get("objects") or []
            if str(o.get("key") or "").startswith("cannon")
            and (not generated or o.get("pattern") in GENERATED)]
def _rect(p):
    from . import v1
    try:
        x0, x1, z0, z1, _ = v1.arenas_module().footprint(p)
    except Exception:
        r = max(p["w"], p["d"]) / 2.0
        x0, x1, z0, z1 = p["x"] - r, p["x"] + r, p["z"] - r, p["z"] + r
    return x0, x1, z0, z1
def muzzle(o):
    return o.get("y", 0) + CANNON_RISE
def in_cone(o, p):
    if p.get("kind") == "water" or p.get("tex") == "invisible" and \
            str(p.get("tag", "")).startswith("edge"):
        return False
    m = muzzle(o)
    top = p["y"] + p["h"]
    if top <= m + 1 or p["y"] >= m + CONE_H:
        return False
    x0, x1, z0, z1 = _rect(p)
    dx = max(x0 - o["x"], 0, o["x"] - x1)
    dz = max(z0 - o["z"], 0, o["z"] - z1)
    d = math.hypot(dx, dz)
    up = min(top, m + CONE_H) - m
    return d <= up * math.tan(math.radians(CONE_HALF))
def _own(o, p):
    t = str(p.get("tag", ""))
    return t.startswith(OWN_TAGS) and math.hypot(p["x"] - o["x"], p["z"] - o["z"]) <= MOUND_REACH
def aimed_at(o, p):
    if not str(p.get("tag", "")).startswith(ISLAND_TAGS):
        return False
    d = math.hypot(p["x"] - o["x"], p["z"] - o["z"])
    if d > SHOT_REACH:
        return False
    if d < 1:
        return True
    want = math.degrees(math.atan2(p["x"] - o["x"], p["z"] - o["z"]))
    return abs((want - (o.get("yaw") or 0) + 180) % 360 - 180) <= AIM_TOL
def cone_blockers(arena, o, pieces=None):
    return [p for p in (arena["pieces"] if pieces is None else pieces)
            if not _own(o, p) and not aimed_at(o, p) and in_cone(o, p)]
def drop(arena, o):
    gone = [p for p in arena["pieces"] if _own(o, p) or aimed_at(o, p)]
    isles = [_rect(p) for p in gone if aimed_at(o, p)]
    ids = set(id(p) for p in gone)
    arena["pieces"] = [p for p in arena["pieces"] if id(p) not in ids]
    arena["objects"] = [q for q in arena.get("objects") or [] if q is not o]
    stars = [st for st in arena.get("stars") or []
             if any(r[0] - 100 <= st["x"] <= r[1] + 100 and r[2] - 100 <= st["z"] <= r[3] + 100
                    for r in isles)]
    if stars:
        sid = set(id(st) for st in stars)
        arena["stars"] = [st for st in arena["stars"] if id(st) not in sid]
    return gone, stars
def reachable(arena, o, graph=None):
    from . import v1
    m = v1.arenas_module()
    if not arena.get("spawns"):
        return True
    if graph is None:
        graph = m.walk_graph(arena)
    cells, edges = graph
    first = m.spawn_cell(arena["spawns"][0])
    if first not in cells:
        return True
    live = m.reach(edges, first)
    G = m.GRID
    cols = {}
    for (gx, gz, h) in live:
        cols.setdefault((gx, gz), []).append(h)
    def near(reach, y, tol):
        g0, n = (int(math.floor(o["x"] / G)), int(math.floor(o["z"] / G))), int(reach // G) + 1
        return any(abs(h - y) <= tol and math.hypot((g0[0] + i) * G + G / 2.0 - o["x"],
                                                     (g0[1] + j) * G + G / 2.0 - o["z"]) <= reach
                   for i in range(-n, n + 1) for j in range(-n, n + 1)
                   for h in cols.get((g0[0] + i, g0[1] + j), []))
    y = o.get("y", 0)
    if near(2 * G, y, REACH_TOL):
        return True
    mound = any(str(p.get("tag", "")) == "play.cannon.mound"
                and math.hypot(p["x"] - o["x"], p["z"] - o["z"]) <= MOUND_REACH
                for p in arena["pieces"])
    return mound and near(MOUND_REACH, y, REACH_TOL)
def faults(arena, graph=None):
    out = []
    for o in cannons(arena):
        bl = cone_blockers(arena, o)
        if bl:
            out.append("cannon at (%d, %d): %s over its firing cone" % (
                o["x"], o["z"], ", ".join(sorted(set(str(p.get("tag") or p.get("kind"))
                                                    for p in bl))[:3])))
        if not reachable(arena, o, graph):
            out.append("cannon at (%d, %d): no way a player walks to it" % (o["x"], o["z"]))
    return out
def clear_cones(arena):
    gone = set()
    left = {}
    for o in cannons(arena):
        bl = cone_blockers(arena, o)
        for p in bl:
            if str(p.get("tag", "")).startswith(DRESSING):
                gone.add(id(p))
        rest = [p for p in bl if id(p) not in gone]
        if rest:
            left[id(o)] = rest
    if gone:
        arena["pieces"] = [p for p in arena["pieces"] if id(p) not in gone]
    return left
def cone_free(pieces, x, y, z, yaw=0):
    o = {"x": x, "y": y, "z": z, "yaw": yaw}
    return not [p for p in pieces if not str(p.get("tag", "")).startswith(DRESSING)
                and not _own(o, p) and not aimed_at(o, p) and in_cone(o, p)]
