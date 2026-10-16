from . import kit, movement
SWIM_DEPTH = 100
SURFACING_LAND = 450
EXIT_MARGIN = 150
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, tag)
def _inside(w, x, z):
    return w[0] - 1 <= x <= w[2] + 1 and w[1] - 1 <= z <= w[3] + 1
def _footprint(p):
    import math
    a = math.radians(p.get("yaw") or 0)
    ew = abs(p["w"] * math.cos(a)) + abs(p["d"] * math.sin(a))
    ed = abs(p["w"] * math.sin(a)) + abs(p["d"] * math.cos(a))
    return p["x"] - ew / 2.0, p["z"] - ed / 2.0, p["x"] + ew / 2.0, p["z"] + ed / 2.0
def floor_under(pieces, x, z, top):
    best = None
    for p in pieces:
        if p.get("kind") == "water" or p.get("tex") == "invisible" or p.get("pass"):
            continue
        x0, z0, x1, z1 = _footprint(p)
        if not (x0 <= x <= x1 and z0 <= z <= z1):
            continue
        t = p["y"] + p["h"]
        if t <= top + 1 and (best is None or t > best):
            best = t
    return best
SHEET_MAX = 60
def is_sheet(p):
    return p.get("kind") == "water" and p.get("h", 0) <= SHEET_MAX
def real_water(arena, floor=None):
    from . import decor
    pieces = arena.get("pieces") or []
    out = []
    def add(w):
        w = [int(round(v)) for v in w]
        if w not in out:
            out.append(w)
    for w in arena.get("water") or []:
        w = list(w)
        if len(w) < 6:
            w = w + [w[4] - 400]
        add(w)
    for w in decor.water_boxes(pieces):
        add(w)
    level_floor = floor if floor is not None else 0
    for p in pieces:
        if not is_sheet(p):
            continue
        x0, z0, x1, z1 = _footprint(p)
        cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        top = p["y"] + p["h"]
        if any(_inside(w, cx, cz) and w[5] - 1 <= top <= w[4] + 1 for w in out):
            continue
        bottom = floor_under(pieces, cx, cz, p["y"])
        if bottom is None:
            bottom = min(level_floor, top - 400)
        add([x0, z0, x1, z1, top, bottom])
    return out
WATER_MOST = 19
def fit_water(rows, ground, most=WATER_MOST, step=200):
    rows = [list(r) for r in rows]
    joins = 0
    def inside_any(x, z, group):
        return any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in group)
    def dry(box, group):
        x0, z0, x1, z1, top = box[0], box[1], box[2], box[3], box[4]
        x = x0 + step / 2.0
        while x < x1:
            z = z0 + step / 2.0
            while z < z1:
                if not inside_any(x, z, group):
                    g = ground(x, z)
                    if g is None or g < top:
                        return False
                z += step
            x += step
        return True
    members = [[r] for r in rows]
    while len(rows) > most:
        best = None
        for i in range(len(rows)):
            for j in range(i + 1, len(rows)):
                a, c = rows[i], rows[j]
                if a[4] != c[4]:
                    continue
                box = [min(a[0], c[0]), min(a[1], c[1]), max(a[2], c[2]), max(a[3], c[3]),
                       a[4], min(a[5], c[5])]
                grow = (box[2] - box[0]) * (box[3] - box[1]) - \
                    (a[2] - a[0]) * (a[3] - a[1]) - (c[2] - c[0]) * (c[3] - c[1])
                if best is not None and grow >= best[0]:
                    continue
                if dry(box, members[i] + members[j]):
                    best = (grow, i, j, box)
        if best is None:
            break
        _, i, j, box = best
        rows[i] = box
        members[i] = members[i] + members[j]
        del rows[j]
        del members[j]
        joins += 1
    return rows, joins
def unswum(arena):
    from . import decor
    rows = [list(w) + [None] * (6 - len(w)) for w in (arena.get("water") or [])]
    out = []
    for p in arena.get("pieces") or []:
        if is_sheet(p):
            x0, z0, x1, z1 = _footprint(p)
            cx, cz, top = (x0 + x1) / 2.0, (z0 + z1) / 2.0, p["y"] + p["h"]
            if not any(_inside(w, cx, cz) and abs(w[4] - top) <= 30 for w in rows):
                out.append("water drawn at (%d, %d, %d) with no water to swim in (%s)"
                           % (cx, top, cz, p.get("tag")))
        elif p.get("decor") in decor.WATER:
            for w in decor.water_boxes([p]):
                if not any(_inside(r, (w[0] + w[2]) / 2.0, (w[1] + w[3]) / 2.0)
                           and abs(r[4] - w[4]) <= 1 for r in rows):
                    out.append("the %s at (%d, %d) holds no water to swim in" % (p["decor"], p["x"], p["z"]))
    return out
BASIN_DEPTHS = (400, 600, 800)
BASIN_DROP = 40
BASIN_RIM = 100
BASIN_STEP = 200
def _run(depth):
    return 400 if depth <= 600 else 800
def basin_depths(width, rim=BASIN_RIM):
    out = []
    for d in BASIN_DEPTHS:
        steps = -(-(d + 10) // BASIN_STEP) - 1
        inner = width - 2 * _run(d) - 2 * rim - 2 * BASIN_STEP * steps
        if inner >= 200:
            out.append(d)
    return out
def lake_basin(x0, x1, z0, z1, base, depth, bank_tex, rim_tex, step_tex, surface, tag="lake",
               floor=None, rim=BASIN_RIM):
    out = []
    run = _run(depth)
    top = base + depth
    box = kit.kind("box").make
    ramp = kit.kind("ramp").make
    outer = kit.kind("outer").make
    ix0, ix1, iz0, iz1 = x0 + run, x1 - run, z0 + run, z1 - run
    out.append(ramp(bank_tex, ix0, ix1, base, top, z0, iz0, "+z", tag + ".bank"))
    out.append(ramp(bank_tex, ix0, ix1, base, top, iz1, z1, "-z", tag + ".bank"))
    out.append(ramp(bank_tex, x0, ix0, base, top, iz0, iz1, "+x", tag + ".bank"))
    out.append(ramp(bank_tex, ix1, x1, base, top, iz0, iz1, "-x", tag + ".bank"))
    for (a0, a1, b0, b1, high) in ((x0, ix0, z0, iz0, "+x+z"), (ix1, x1, z0, iz0, "-x+z"),
                                   (x0, ix0, iz1, z1, "+x-z"), (ix1, x1, iz1, z1, "-x-z")):
        out.append(outer(bank_tex, a0, a1, base, top, b0, b1, high, tag + ".bank"))
    r = rim
    for (a0, a1, b0, b1) in ((ix0, ix1, iz0, iz0 + r), (ix0, ix1, iz1 - r, iz1),
                             (ix0, ix0 + r, iz0 + r, iz1 - r), (ix1 - r, ix1, iz0 + r, iz1 - r)):
        out.append(box(rim_tex, a0, a1, base, top, b0, b1, None, tag + ".rim"))
    fl = base if floor is None else floor
    wx0, wx1, wz0, wz1 = ix0 + r, ix1 - r, iz0 + r, iz1 - r
    n = -(-(top - fl) // BASIN_STEP)
    a0, a1, b0, b1 = wx0, wx1, wz0, wz1
    s = BASIN_STEP
    for k in range(n - 1, 0, -1):
        h = fl + int(round(k * (top - fl) / float(n)))
        for (c0, c1, e0, e1) in ((a0, a1, b0, b0 + s), (a0, a1, b1 - s, b1),
                                 (a0, a0 + s, b0 + s, b1 - s), (a1 - s, a1, b0 + s, b1 - s)):
            out.append(box(step_tex, c0, c1, base, h, e0, e1, None, tag + ".terrace"))
        a0, a1, b0, b1 = a0 + s, a1 - s, b0 + s, b1 - s
    wtop = top - BASIN_DROP
    out.append(kit.kind("water").make(surface, wx0, wx1, wtop - 20, wtop, wz0, wz1, None,
                                      tag + ".water"))
    return out, [wx0, wz0, wx1, wz1, wtop, min(base, fl)]
def exits(water, pieces):
    x0, z0, x1, z1, top = water[:5]
    out = []
    for side, (x, z) in (("-z", ((x0 + x1) / 2.0, z0 - 50)), ("+z", ((x0 + x1) / 2.0, z1 + 50)),
                         ("-x", (x0 - 50, (z0 + z1) / 2.0)), ("+x", (x1 + 50, (z0 + z1) / 2.0))):
        h = floor_under(pieces, x, z, top + SURFACING_LAND)
        if h is not None and h - top <= SURFACING_LAND - EXIT_MARGIN and h >= top - 200:
            out.append(side)
    return out
def basin_exits(water, pieces, sides=1):
    x0, z0, x1, z1, top, bottom = water[:6]
    out = []
    if top - bottom <= SWIM_DEPTH:
        out.append("water at (%d, %d) only %d deep: waded, not swum" % (x0, z0, top - bottom))
    got = exits(water, pieces)
    if len(got) < sides:
        out.append("water at (%d, %d): a way out on %d side(s), %d wanted" % (x0, z0, len(got), sides))
    return out
CANNON_SINK = 340
WELL_DEPTH = 400
WELL_FLOOR = 60
WELL_HALF = 200
WELL_WALL = 200
WELL_RAMP = 800
MOUND_STEP = 400
MOUND_TAG = "play.cannon.mound"
DIG = "dig"
BANK_DEPTH = 200
BANK_LIP = 40
BANK_COLUMN = 200
BANK_TOL = 12
def _foot(p):
    w, d = p["w"], p["d"]
    if int(round(float(p.get("yaw", 0) or 0))) % 180 == 90:
        w, d = d, w
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def _liquid(p):
    return p.get("kind") in ("lava", "water") or p.get("tex") == "lava"
def liquid_banks(pieces, floor, land_tex, sheets=()):
    out = []
    liquids = [p for p in pieces if (_liquid(p))
               and id(p) not in set(id(q) for q in sheets)
               and min(p["w"], p["d"]) >= 200 and p["h"] < min(p["w"], p["d"])]
    feet = [(_foot(p), p) for p in pieces]
    every = feet
    for p in liquids:
        surf = p["y"] + p["h"]
        x0, x1, z0, z1 = _foot(p)
        m_ = BANK_DEPTH + 1
        feet = [(f, q) for f, q in every if f[0] < x1 + m_ and f[1] > x0 - m_
                and f[2] < z1 + m_ and f[3] > z0 - m_]
        for axis, side in (("z", -1), ("z", 1), ("x", -1), ("x", 1)):
            lo, hi = (x0, x1) if axis == "z" else (z0, z1)
            edge = (z0 if side < 0 else z1) if axis == "z" else (x0 if side < 0 else x1)
            run = []
            a = lo
            while a < hi - 1:
                b = min(hi, a + BANK_COLUMN)
                depth = BANK_DEPTH
                for (f0, f1, g0, g1), q in feet:
                    if q is p:
                        continue
                    along = (f0, f1) if axis == "z" else (g0, g1)
                    across = (g0, g1) if axis == "z" else (f0, f1)
                    if along[1] <= a or along[0] >= b:
                        continue
                    near = (edge - across[1]) if side < 0 else (across[0] - edge)
                    far = (edge - across[0]) if side < 0 else (across[1] - edge)
                    if far <= 0 or near >= depth:
                        continue
                    top = q["y"] + q["h"]
                    if q["y"] >= surf + BANK_LIP:
                        continue
                    liquid = _liquid(q)
                    if (liquid and abs(top - surf) <= BANK_TOL) or top >= surf - BANK_TOL:
                        depth = max(0.0, min(depth, near))
                if depth < 20:
                    a = b
                    continue
                c0, c1 = (edge - depth, edge) if side < 0 else (edge, edge + depth)
                fx = (a, b, c0, c1) if axis == "z" else (c0, c1, a, b)
                under = [q["y"] + q["h"] for (f0, f1, g0, g1), q in feet if q is not p
                         and f0 < fx[1] and f1 > fx[0] and g0 < fx[3] and g1 > fx[2]]
                ground = max(under + ([floor] if floor is not None else []), default=None)
                if ground is None or ground >= surf - BANK_TOL:
                    a = b
                    continue
                run.append((fx, int(ground)))
                a = b
            k = 0
            while k < len(run):
                fx, g = run[k]
                e = k + 1
                while e < len(run) and run[e][1] == g and (
                        (run[e][0][2:] == fx[2:]) if axis == "z" else (run[e][0][:2] == fx[:2])):
                    e += 1
                last = run[e - 1][0]
                rect = (fx[0], last[1], fx[2], fx[3]) if axis == "z" else (fx[0], fx[1], fx[2],
                                                                           last[3])
                out.append(_box(land_tex, rect[0], rect[1], g, surf + BANK_LIP, rect[2], rect[3],
                                str(p.get("tag", "liquid")).split(".")[0] + ".bank.lip"))
                k = e
    return out
def mound_texture(arena):
    if not (arena.get("terrain") or {}).get("mesh"):
        return None
    from . import heightfield, kit
    import collections
    have = kit.textures()
    c = collections.Counter(p.get("tex") for p in arena.get("pieces") or []
                            if p.get("kind") == "box" and heightfield.is_terrain(p)
                            and not (have.get(p.get("tex")) or {}).get("layered"))
    return c.most_common(1)[0][0] if c else None
def cut_out(p, hole):
    x0, x1, z0, z1 = _foot(p)
    h0, h1, k0, k1 = max(x0, hole[0]), min(x1, hole[1]), max(z0, hole[2]), min(z1, hole[3])
    if h0 >= h1 or k0 >= k1:
        return [p]
    parts = [(x0, x1, z0, k0), (x0, x1, k1, z1), (x0, h0, k0, k1), (h1, x1, k0, k1)]
    out = []
    for a0, a1, b0, b1 in parts:
        if a1 - a0 < 1 or b1 - b0 < 1:
            continue
        q = dict(p, x=(a0 + a1) / 2.0, z=(b0 + b1) / 2.0, w=a1 - a0, d=b1 - b0, yaw=0)
        q.pop("model", None)
        out.append(q)
    return out
def cannon_mound(cx, cz, g, land_tex):
    box = kit.kind("box").make
    w = WELL_HALF + WELL_WALL
    out = []
    for k, (r0, r1, h) in enumerate(((w, w + MOUND_STEP, WELL_DEPTH),
                                     (w + MOUND_STEP, w + 2 * MOUND_STEP, WELL_DEPTH // 2))):
        out += [box(land_tex, cx - r1, cx + r1, g, g + h, cz - r1, cz - r0, None, MOUND_TAG),
                box(land_tex, cx - r1, cx + r1, g, g + h, cz + r0, cz + r1, None, MOUND_TAG),
                box(land_tex, cx - r1, cx - r0, g, g + h, cz - r0, cz + r0, None, MOUND_TAG),
                box(land_tex, cx + r0, cx + r1, g, g + h, cz - r0, cz + r0, None, MOUND_TAG)]
    r = w + 2 * MOUND_STEP
    return out, (cx - r, cx + r, cz - r, cz + r)
def cannon_well(cx, cz, g, tex, ramp_tex, away, tag="play.cannon.well", mound=None):
    box = kit.kind("box").make
    h, w = WELL_HALF, WELL_HALF + WELL_WALL
    top = g + WELL_DEPTH
    out = [box(tex, cx - w, cx + w, g, top, cz - w, cz - h, None, tag),
           box(tex, cx - w, cx + w, g, top, cz + h, cz + w, None, tag),
           box(tex, cx - w, cx - h, g, top, cz - h, cz + h, None, tag),
           box(tex, cx + h, cx + w, g, top, cz - h, cz + h, None, tag),
           box(tex, cx - h, cx + h, g, g + WELL_FLOOR, cz - h, cz + h, None, tag + ".floor")]
    if mound == DIG:
        return out, g + WELL_FLOOR, [(cx - w, cx + w, cz - w, cz + w)]
    if mound:
        ground, rect = cannon_mound(cx, cz, g, mound)
        return out + ground, g + WELL_FLOOR, [rect]
    dx, dz = away
    rises = {(1, 0): "-x", (-1, 0): "+x", (0, 1): "-z", (0, -1): "+z"}[(dx, dz)]
    if dx:
        a0, a1 = sorted((cx + dx * w, cx + dx * (w + WELL_RAMP)))
        ramp = kit.kind("ramp").make(ramp_tex, a0, a1, g, top, cz - h, cz + h, rises, tag + ".ramp")
        rect = (a0, a1, cz - h, cz + h)
    else:
        b0, b1 = sorted((cz + dz * w, cz + dz * (w + WELL_RAMP)))
        ramp = kit.kind("ramp").make(ramp_tex, cx - h, cx + h, g, top, b0, b1, rises, tag + ".ramp")
        rect = (cx - h, cx + h, b0, b1)
    out.append(ramp)
    return out, g + WELL_FLOOR, [(cx - w, cx + w, cz - w, cz + w), rect]
NATURAL_RIM = 200
NATURAL_DROP = 100
COVE_UNDER = 10
COVE_SHARE = 0.35
def natural_shore(pieces, row, land_tex, seed, tag="lake"):
    import random
    rnd = random.Random("shore/%s" % seed)
    out = []
    wx0, wz0, wx1, wz1, wtop, bottom = row
    wtop2 = wtop - NATURAL_DROP + BASIN_DROP
    rims = []
    for p in pieces:
        t = str(p.get("tag", ""))
        if t == tag + ".bank":
            p = dict(p, tag=t + ".shore", tex=land_tex)
        elif t == tag + ".rim":
            rims.append(p)
            continue
        elif t == tag + ".water":
            p = dict(p, y=wtop2 - p["h"])
        out.append(p)
    if not rims:
        return out, [wx0, wz0, wx1, wz1, wtop2, bottom]
    base = min(p["y"] for p in rims)
    crest = max(p["y"] + p["h"] for p in rims)
    cove = wtop2 - COVE_UNDER
    r = NATURAL_RIM
    ix0, ix1, iz0, iz1 = wx0 - r, wx1 + r, wz0 - r, wz1 + r
    sides = [[(x, iz0) for x in range(ix0 + r, ix1 - r, r)],
             [(x, iz1 - r) for x in range(ix0 + r, ix1 - r, r)],
             [(ix0, z) for z in range(iz0 + r, iz1 - r, r)],
             [(ix1 - r, z) for z in range(iz0 + r, iz1 - r, r)]]
    low = set([(ix0, iz0), (ix1 - r, iz0), (ix0, iz1 - r), (ix1 - r, iz1 - r)])
    for side in sides:
        if len(side) >= 4 and rnd.random() < COVE_SHARE * 2:
            run = rnd.randint(1, 2)
            k = rnd.randint(1, len(side) - 1 - run)
            for t in side[k:k + run]:
                low.add(t)
    for side in sides:
        k = 0
        while k < len(side):
            h = cove if side[k] in low else crest
            e = k + 1
            while e < len(side) and (cove if side[e] in low else crest) == h:
                e += 1
            (a0, b0), (a1, b1) = side[k], side[e - 1]
            out.append(_box(land_tex, a0, a1 + r, base, h, b0, b1 + r, tag + ".rim.shore"))
            k = e
    for t in sorted(low - set(t for side in sides for t in side)):
        out.append(_box(land_tex, t[0], t[0] + r, base, cove, t[1], t[1] + r, tag + ".rim.shore"))
    return out, [wx0, wz0, wx1, wz1, wtop2, bottom]
SEAL_OUT = 120
SEAL_STEP = 100
SEAL_ROUNDS = 2
_RIMS_SEEN = []
_RIMS_KEEP = 4
RIMS_OF = ("pieces", "water", "terrain", "level", "texture_cap", "movers", "pockets", "key")
def _rims(arena):
    import hashlib
    import json
    key = hashlib.sha1(json.dumps([arena.get(k) for k in RIMS_OF], sort_keys=True,
                                  default=str).encode()).hexdigest()
    for k, v in _RIMS_SEEN:
        if k == key:
            return list(v)
    got = _rims_baked(arena)
    _RIMS_SEEN.insert(0, (key, list(got)))
    del _RIMS_SEEN[_RIMS_KEEP:]
    return got
def _rims_baked(arena):
    import os
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake
    a = dict(arena)
    a.setdefault("key", "rims")
    a["_generated"] = True
    lv = venuebake.compile_level(a, shade=False)
    info = venuebake.arenas_tool().LEVELS.get(arena.get("level") or "empty2") or {}
    return venuebake.liquid_rims(venuebake.prepared(a), lv.collision, lv.terrain, info.get("floor"))
def _sheet_of(pieces, x, z):
    best = None
    for p in pieces:
        if not (_liquid(p) or p.get("kind") == "water" or "water" in str(p.get("tag", ""))
                or "lava" in str(p.get("tex", ""))):
            continue
        x0, x1, z0, z1 = _foot(p)
        for side, d, inside in (("-x", x0 - x, z0 <= z <= z1), ("+x", x - x1, z0 <= z <= z1),
                                ("-z", z0 - z, x0 <= x <= x1), ("+z", z - z1, x0 <= x <= x1)):
            if inside and 0 <= d <= 40 and (best is None or d < best[0]):
                best = (d, p, side)
    return (best[1], best[2]) if best else (None, None)
def seal_rims(arena, tex=None):
    notes = []
    tex = tex or ((arena.get("terrain") or {}).get("rock") if isinstance(arena.get("terrain"), dict)
                  else None) or "stone1"
    for _ in range(SEAL_ROUNDS):
        try:
            open_ = _rims(arena)
        except Exception as why:
            return notes + ["rims not sealed: the bake did not run (%s)" % why.__class__.__name__]
        if not open_:
            return notes
        runs = {}
        for over, x, y, z in open_:
            p, side = _sheet_of(arena["pieces"], x, z)
            if p is None:
                continue
            runs.setdefault((id(p), side), (p, side, []))[2].append((x, z, y - over))
        added = 0
        for p, side, pts in runs.values():
            surf = p["y"] + p["h"]
            x0, x1, z0, z1 = _foot(p)
            low = min(g for _, _, g in pts) - 20
            low = int(low // 1)
            along = sorted((z if side in ("-x", "+x") else x) for x, z, _ in pts)
            a, b = along[0] - SEAL_STEP / 2.0, along[-1] + SEAL_STEP / 2.0
            if side == "-x":
                fx = (x0 - SEAL_OUT, x0, a, b)
            elif side == "+x":
                fx = (x1, x1 + SEAL_OUT, a, b)
            elif side == "-z":
                fx = (a, b, z0 - SEAL_OUT, z0)
            else:
                fx = (a, b, z1, z1 + SEAL_OUT)
            for q in arena["pieces"]:
                if q is p or _liquid(q) or q.get("pass") or q.get("tex") == "invisible":
                    continue
                qx0, qx1, qz0, qz1 = _foot(q)
                if qx1 <= fx[0] or qx0 >= fx[1] or qz1 <= fx[2] or qz0 >= fx[3]:
                    continue
                qt = q["y"] + q["h"]
                if qt <= low or q["y"] >= surf + BANK_LIP:
                    continue
                if qt <= surf - BANK_TOL:
                    low = qt
                else:
                    low = None
                    break
            if low is None or low >= surf:
                continue
            seal = {"kind": "box", "tex": tex, "x": int(round((fx[0] + fx[1]) / 2.0)),
                    "y": int(low), "z": int(round((fx[2] + fx[3]) / 2.0)),
                    "w": int(round(fx[1] - fx[0])), "h": int(round(surf + BANK_LIP - low)),
                    "d": int(round(fx[3] - fx[2])), "yaw": 0,
                    "tag": "%s.bank.seal" % (str(p.get("tag") or "liquid").split(" ")[0])}
            arena["pieces"].append(seal)
            added += 1
        if not added:
            return notes + ["%d rim points open, none beside a liquid piece" % len(open_)]
        notes.append("%d open rims sealed (%d points)" % (added, len(open_)))
    return notes
