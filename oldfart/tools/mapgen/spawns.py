import math
from . import kit, v1
from .layout import UNDER_EYE, open_map
ROW_BACK = 500
SPACING = 450
SHIELD_GAP = 300
SHIELD_H = 450
FIELD_MAX = 12
FIELD_GAP = 1000
BASE_GAP = 1200
EXPOSURE_GOOD = 0.15
EXPOSURE_OK = 0.22
SAMPLE = 300
ORBITS_MAX = 48
def _yaw_of(facing):
    dx, dz = facing
    return int(round(math.degrees(math.atan2(dx, dz)))) % 360
def _frame(base):
    x0, x1, z0, z1 = base["rect"]
    fx, fz = base["facing"]
    if fz != 0:
        back = z0 if fz > 0 else z1
        width = (x0, x1)
        depth = z1 - z0
        def at(a, d):
            return a, back + fz * d
    else:
        back = x0 if fx > 0 else x1
        width = (z0, z1)
        depth = x1 - x0
        def at(a, d):
            return back + fx * d, a
    return at, width, depth
def base_layout(base, n, flat=False, low=False):
    at, (w0, w1), depth = _frame(base)
    y = base["y"]
    yaw = _yaw_of(base["facing"])
    room = (w1 - w0) - 400
    rows = 1
    while rows < 3:
        per = int(math.ceil(n / float(rows)))
        if per <= 1 or room / float(per - 1) >= 300:
            break
        rows += 1
    per = int(math.ceil(n / float(rows)))
    spacing = SPACING if per <= 1 else min(SPACING, room / float(per - 1))
    spots, shields = [], []
    mid = (w0 + w1) / 2.0
    back = ROW_BACK if depth >= 1300 else max(300, depth - 800)
    for r in range(rows):
        d = back + r * 700
        span = (per - 1) * spacing
        off = spacing / 2.0 if (r % 2 == 1 and span + spacing / 2.0 <= room) else 0.0
        a_list = [mid - span / 2.0 + i * spacing + off for i in range(per)]
        for a in a_list:
            if len(spots) >= n:
                break
            x, z = at(a, d)
            spots.append({"x": int(round(x / 50.0)) * 50, "y": y, "z": int(round(z / 50.0)) * 50,
                          "yaw": yaw})
        h = (UNDER_EYE if low else 200) if flat else SHIELD_H
        for i in range(0, len(a_list), 2):
            pair = a_list[i:i + 2]
            a0, a1 = min(pair) - 150, max(pair) + 150
            dd0, dd1 = d + SHIELD_GAP, d + SHIELD_GAP + 200
            if dd1 > depth - 100 or (r + 1 < rows and dd1 > back + (r + 1) * 700 - 200):
                continue
            p0, p1 = at(a0, dd0), at(a1, dd1)
            rect = (min(p0[0], p1[0]), max(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[1], p1[1]))
            rect = tuple(int(round(v / 50.0)) * 50 for v in rect)
            shields.append((rect, y, y + h))
    return spots[:n], shields
def place_bases(L):
    sym = L.sym
    nb = len(L.bases) * sym.units
    if nb == 0:
        L.spawns = []
        L.base_points = []
        L.report["spawns"] = {"bases": 0}
        return
    players = 16
    per = int(math.ceil(players / float(nb)))
    flat = L.brief["verticality"] == "flat"
    groups = []
    for bi, base in enumerate(L.bases):
        spots, shields = base_layout(base, per, flat, open_map(L.brief))
        for (rect, y0, y1) in shields:
            p = kit.kind("box").make(L.pal.get("cover", L.pal["wall"]), rect[0], rect[1], y0, y1,
                                     rect[2], rect[3], None, "%s.shield" % base["id"])
            L.shields.extend(sym.pieces(p))
        L.keep(base["rect"])
        for u in range(sym.units):
            groups.append((u, bi, [sym.copy(s, u, point=True) for s in spots]))
    order_units = sym.order()
    seq = [(u, bi) for bi in range(len(L.bases)) for u in order_units]
    by = {(u, bi): g for u, bi, g in groups}
    out = []
    for k in range(per):
        for key in seq:
            g = by[key]
            if k < len(g) and len(out) < max(players, 16):
                out.append(g[k])
    L.spawns = out[:16]
    L.base_points = [[(s["x"], s["y"], s["z"]) for s in by[key]] for key in seq]
    L.report["spawns"] = {"bases": nb, "per_base": per, "shields": len(L.shields),
                          "rule": "cover %d tall %d-%d ahead, nothing tall 500 behind"
                          % (200 if flat else SHIELD_H, SHIELD_GAP, SHIELD_GAP + 200)}
def _candidates(L):
    out = [dict(s) for s in L.spots]
    for f in L.floors:
        if f["zone"] == "base":
            continue
        x0, x1, z0, z1 = f["rect"]
        if x1 - x0 < 600 or z1 - z0 < 600:
            continue
        step = 600
        x = x0 + 300
        while x <= x1 - 300:
            z = z0 + 300
            while z <= z1 - 300:
                out.append({"x": int(x), "y": f["y"], "z": int(z), "yaw": 0, "why": f["zone"]})
                z += step
            x += step
    seen, uniq = set(), []
    for s in out:
        k = (int(s["x"]) // 100, int(s["z"]) // 100, int(s["y"]))
        if k not in seen:
            seen.add(k)
            uniq.append(s)
    return uniq
def _face_centre(s, cx, cz):
    dx, dz = cx - s["x"], cz - s["z"]
    if abs(dx) < 1 and abs(dz) < 1:
        return 0
    return int(round(math.degrees(math.atan2(dx, dz)) / 45.0)) * 45 % 360
def choose_field(L, arena, shift):
    dx, lift, dz = shift
    orbits = []
    for s in _candidates(L):
        pts = []
        for c in L.sym.points(s):
            pts.append({"x": int(c["x"] + dx), "y": int(c["y"] + lift), "z": int(c["z"] + dz),
                        "yaw": 0, "why": s.get("why", "")})
        orbits.append(pts)
    chosen, rep = pick(arena, orbits, centre=(dx, dz), notes=L.notes)
    L.report.setdefault("spawns", {})["field"] = rep
    return chosen
def choose_field_world(arena, spots, units, symmetry):
    from .layout import Sym
    kind = symmetry if symmetry in ("turn4", "turn2", "mirror") else "none"
    sym = Sym(kind)
    seen, orbits = set(), []
    for s in spots:
        pts = []
        for c in sym.points(s):
            pts.append({"x": int(c["x"]), "y": int(c["y"]), "z": int(c["z"]), "yaw": 0,
                        "why": s.get("why", "")})
        key = tuple(sorted((p["x"], p["y"], p["z"]) for p in pts))
        if key in seen:
            continue
        seen.add(key)
        orbits.append(pts)
    chosen, rep = pick(arena, orbits)
    return chosen, rep
SPREAD_GAP = 1000
SPREAD_WANT = 16
def _nearest(p, pts):
    return min([math.hypot(p["x"] - q["x"], p["z"] - q["z"]) for q in pts] or [1e9])
def spread_points(arena, leaders, extra=()):
    m = v1.arenas_module()
    pts = [p for p in (arena.get("survey") or {}).get("points") or [] if isinstance(p, dict)]
    if len(pts) <= leaders:
        return None
    before = _median_gap(pts)
    chosen = [dict(p) for p in pts[:leaders]]
    seen = set((p["x"], p["y"], p["z"]) for p in chosen)
    pool = []
    for p in list(pts[leaders:]) + list(extra):
        k = (p["x"], p["y"], p["z"])
        if k not in seen:
            seen.add(k)
            pool.append({"x": p["x"], "y": p["y"], "z": p["z"], "yaw": p.get("yaw", 0)})
    cap = m.SURVEY_POINTS_MAX
    while pool and len(chosen) < cap:
        best = max(range(len(pool)), key=lambda i: (_nearest(pool[i], chosen), -i))
        d = _nearest(pool[best], chosen)
        if len(chosen) >= SPREAD_WANT and d < SPREAD_GAP:
            break
        chosen.append(pool.pop(best))
    arena["survey"]["points"] = chosen
    return {"points": len(chosen), "median_gap_before": before,
            "median_gap": _median_gap(chosen),
            "rule": "%d leaders kept, then farthest first; past %d only %d apart"
                    % (leaders, SPREAD_WANT, SPREAD_GAP)}
def _median_gap(pts):
    if len(pts) < 2:
        return None
    near = sorted(_nearest(a, [b for b in pts if b is not a]) for a in pts)
    return int(near[len(near) // 2])
def more_field(arena, orbits, centre=(0, 0)):
    m = v1.arenas_module()
    chosen, _ = pick(arena, orbits, centre=centre, budget=m.SURVEY_POINTS_MAX)
    return chosen
def pick(arena, orbits, centre=(0, 0), notes=None, budget=None):
    m = v1.arenas_module()
    if budget is None:
        budget = min(FIELD_MAX, m.SURVEY_POINTS_MAX - len(arena["spawns"]))
    if budget <= 0:
        return [], {"chosen": 0, "candidates": 0}
    base_pts = [(s["x"], s["z"]) for s in arena["spawns"]]
    ok = []
    for pts in orbits:
        for p in pts:
            p["yaw"] = _face_centre(p, centre[0], centre[1])
        if any(math.hypot(p["x"] - a, p["z"] - b) < BASE_GAP for p in pts for a, b in base_pts):
            continue
        if any(math.hypot(a["x"] - b["x"], a["z"] - b["z"]) < FIELD_GAP
               for i, a in enumerate(pts) for b in pts[i + 1:]):
            continue
        ok.append(pts)
    if not ok:
        return [], {"chosen": 0, "candidates": 0}
    if len(ok) > ORBITS_MAX:
        step = len(ok) / float(ORBITS_MAX)
        ok = [ok[int(i * step)] for i in range(ORBITS_MAX)]
    world = sample = None
    try:
        from .metrics.world import world_of
        from .metrics import vis
        world = world_of(arena)
        sample, _ = vis.sample_points(world, k=SAMPLE)
    except Exception as why:
        if notes is not None:
            notes.append("field spawns by order (no exposure: %s)" % why.__class__.__name__)
    def stands(p):
        hs = m.standable(arena["pieces"], p["x"], p["z"], arena["level"])
        return any(abs(h - p["y"]) <= 1 for h in hs)
    scored = []
    for i, pts in enumerate(ok):
        if not stands(pts[0]):
            continue
        ex = vis.exposure(world, pts[0], sample) if world is not None else 0.5 + 0.001 * i
        scored.append((round(ex, 4), i, pts))
    scored.sort(key=lambda t: (t[0], t[1]))
    chosen, used = [], []
    for limit in (EXPOSURE_GOOD, EXPOSURE_OK):
        for ex, i, pts in scored:
            if ex > limit or len(chosen) + len(pts) > budget or i in [u[1] for u in used]:
                continue
            if any(math.hypot(p["x"] - c["x"], p["z"] - c["z"]) < FIELD_GAP
                   for p in pts for c in chosen):
                continue
            if not all(stands(p) for p in pts[1:]):
                continue
            chosen += [{"x": p["x"], "y": p["y"], "z": p["z"], "yaw": p["yaw"]} for p in pts]
            used.append((ex, i, pts[0].get("why", "")))
    rep = {"chosen": len(chosen), "candidates": len(ok),
           "exposure_max": max([u[0] for u in used] or [0]),
           "where": sorted(set(u[2] for u in used if u[2])),
           "rule": "<= %d, least exposed orbits first (<= %.2f, then <= %.2f), %d apart, %d "
                   "from base spawns" % (FIELD_MAX, EXPOSURE_GOOD, EXPOSURE_OK, FIELD_GAP,
                                         BASE_GAP)}
    return chosen, rep
