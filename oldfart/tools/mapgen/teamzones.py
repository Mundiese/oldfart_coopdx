import math
import random
import zlib
from .modeknow import SPAWN_NEEDS as _NEEDS
FLANK_MIN = _NEEDS["team"]["flank_min"]
OWN_SIDE = 1.4
SAFE_S = 3.5
EXPOSURE_MAX = 0.22
FAIR_S = 1.0
FAIR_EXPOSURE = 0.08
DICE_CHANCE = 1.0 / 6
LUA_NOTE = ("flank zones flankRed/flankBlue are in the survey; Capture the Flag, One Flag "
            "CTF and team Deathmatch / Rocket Arena open each side half and half across "
            "home and flank and bring a death back to the safer zone (modes.FLANK_ZONES)")
def wanted(brief):
    feats = brief["features"]
    if "split_spawns" in feats["avoid"]:
        return None
    if brief["sides"] != "2" and brief["family"] != "objective":
        return None
    if "split_spawns" in feats["want"]:
        return "want"
    r = random.Random(zlib.crc32(("teamzones:%d" % brief["seed"]).encode()))
    return "dice" if r.random() < DICE_CHANCE else None
def _homes(arena):
    s = arena.get("survey") or {}
    red, blue = s.get("ctfRed"), s.get("ctfBlue")
    if isinstance(red, dict) and isinstance(blue, dict):
        return red, blue
    sp = arena.get("spawns") or []
    if len(sp) < 2:
        return None, None
    xs = [p["x"] for p in sp]
    zs = [p["z"] for p in sp]
    axis = "z" if (max(zs) - min(zs)) >= (max(xs) - min(xs)) else "x"
    lo = [p for p in sp if p[axis] < 0] or sp[:len(sp) // 2]
    hi = [p for p in sp if p[axis] >= 0] or sp[len(sp) // 2:]
    def mean(ps):
        p = min(ps, key=lambda q: abs(q["x"] - sum(x["x"] for x in ps) / len(ps))
                + abs(q["z"] - sum(x["z"] for x in ps) / len(ps)))
        return dict(p)
    return mean(lo), mean(hi)
def apply(arena, brief):
    how = wanted(brief)
    if how is None:
        return None
    from .metrics import graph, mario, vis
    from .metrics.world import world_of
    red, blue = _homes(arena)
    if red is None:
        return _note(arena, how, "two spawn zones per team: no two team homes on "
                     "this map")
    try:
        w = world_of(arena)
    except Exception as why:
        return _note(arena, how, "two spawn zones per team: %s" % why)
    rn, bn = w.node_of(red), w.node_of(blue)
    dr = graph.bfs(w.adj, [rn])
    db = graph.bfs(w.adj, [bn])
    cell = mario.CELL
    home_gap = dr[bn] * cell if dr[bn] > 0 else 0
    sample, _ = vis.sample_points(w, k=300)
    sym = (arena.get("report") or {}).get("symmetry_solved") or brief["symmetry"]
    def t(steps):
        return mario.distance_time_s(steps * cell) if steps >= 0 else None
    def choose(d_own, d_enemy):
        cands = []
        for i, (a, e) in enumerate(zip(d_own, d_enemy)):
            if a < 0 or e < 0 or e < OWN_SIDE * a:
                continue
            if a * cell < max(FLANK_MIN, home_gap / 3.0):
                continue
            if t(e) < SAFE_S:
                continue
            cands.append((a, i))
        cands.sort(key=lambda c: -c[0])
        for a, i in cands[:40]:
            x, y, z = w.node_xyz(i)
            spot = {"x": int(x), "y": int(y), "z": int(z)}
            if vis.exposure(w, spot, sample) <= EXPOSURE_MAX:
                return i, spot
        return None, None
    ri, rspot = choose(dr, db)
    if ri is None:
        return _note(arena, how, "two spawn zones per team: no flank spot is %.1f s "
                     "from the enemy and covered enough on this map" % SAFE_S)
    bspot = bi = None
    mirror = {"mirror": (rspot["x"], -rspot["z"]), "turn2": (-rspot["x"], -rspot["z"])}.get(sym)
    if sym == "mirror" and abs(red["x"] - blue["x"]) > abs(red["z"] - blue["z"]):
        mirror = (-rspot["x"], rspot["z"])
    if mirror is not None:
        cand = w.node_of({"x": mirror[0], "y": rspot["y"], "z": mirror[1]})
        x, y, z = w.node_xyz(cand)
        if math.hypot(x - mirror[0], z - mirror[1]) <= 200 and db[cand] >= 0 and \
                db[cand] < dr[cand]:
            bi, bspot = cand, {"x": int(x), "y": int(y), "z": int(z)}
    if bi is None:
        bi, bspot = choose(db, dr)
    if bi is None:
        return _note(arena, how, "two spawn zones per team: the blue side has no "
                     "flank spot as safe as the red one")
    zones = {}
    twin = mirror is not None and (bspot["x"], bspot["z"]) == mirror
    for side, i, spot, own, enemy, home in (("Red", ri, rspot, dr, db, red),
                                            ("Blue", bi, bspot, db, dr, blue)):
        pts = [spot]
        if side == "Blue" and twin and len(zones["Red"]["points"]) > 1:
            q = zones["Red"]["points"][1]
            mq = (-q["x"], q["z"]) if mirror == (-rspot["x"], rspot["z"]) else \
                (q["x"], -q["z"]) if mirror == (rspot["x"], -rspot["z"]) else (-q["x"], -q["z"])
            k = w.node_of({"x": mq[0], "y": q["y"], "z": mq[1]})
            x, y, z = w.node_xyz(k)
            if (int(x), int(z)) == (int(mq[0]), int(mq[1])) and abs(y - spot["y"]) <= 1 \
                    and own[k] >= 0 and enemy[k] >= OWN_SIDE * own[k]:
                pts.append({"x": int(x), "y": int(y), "z": int(z)})
        for k in range(len(w.nodes)) if len(pts) < 2 else ():
            x, y, z = w.node_xyz(k)
            if 350 <= math.hypot(x - spot["x"], z - spot["z"]) <= 600 and \
                    abs(y - spot["y"]) <= 1 and own[k] >= 0 and enemy[k] >= OWN_SIDE * own[k]:
                pts.append({"x": int(x), "y": int(y), "z": int(z)})
                break
        if len(pts) < 2:
            return _note(arena, how, "two spawn zones per team: no room for two spawns at the "
                         "%s flank" % side.lower())
        yaw = int(round(math.degrees(math.atan2(-spot["x"], -spot["z"])))) % 360
        for p in pts:
            p["yaw"] = yaw
        zones[side] = {"points": pts, "enemy_s": round(t(enemy[i]), 2),
                       "home_s": round(t(own[i]), 2),
                       "exposure": round(vis.exposure(w, spot, sample), 3)}
    gap_t = abs(zones["Red"]["enemy_s"] - zones["Blue"]["enemy_s"])
    gap_e = abs(zones["Red"]["exposure"] - zones["Blue"]["exposure"])
    if gap_t > FAIR_S or gap_e > FAIR_EXPOSURE:
        return _note(arena, how, "two spawn zones per team: the fairest pair differs "
                     "by %.1f s to the enemy and %.2f exposure (limits %.1f s, %.2f)"
                     % (gap_t, gap_e, FAIR_S, FAIR_EXPOSURE))
    survey = arena.setdefault("survey", {})
    survey["flankRed"] = zones["Red"]["points"]
    survey["flankBlue"] = zones["Blue"]["points"]
    rep = arena.setdefault("report", {})
    rep["team_zones"] = {"how": how, "red": {k: v for k, v in zones["Red"].items()
                                             if k != "points"},
                         "blue": {k: v for k, v in zones["Blue"].items() if k != "points"},
                         "fair": {"enemy_s_gap": round(gap_t, 2),
                                  "exposure_gap": round(gap_e, 3)}}
    note = ("two spawn zones per team (%s): flanks %.1f / %.1f s from the enemy, exposure "
            "%.2f / %.2f" % ("asked" if how == "want" else "on the dice",
                             zones["Red"]["enemy_s"], zones["Blue"]["enemy_s"],
                             zones["Red"]["exposure"], zones["Blue"]["exposure"]))
    rep.setdefault("notes", []).append(note)
    rep.setdefault("notes", []).append(LUA_NOTE)
    return "placed", note
def _note(arena, how, text):
    if how == "want":
        arena.setdefault("report", {}).setdefault("not_possible", []).append(text)
    return "not possible", text
