import math
from . import kit, v1
FAMILIES = ("party", "knockoff", "race")
GAP = 3000
LEVEL_MARGIN = 1500
PLANE_MARGIN = 2100
RISE = 1200
HERO_FAN = 55
THEMES = {
    "sky": {"top": "grasslushcube", "body": "rockbrown", "under": "rockgrey",
            "trees": ("oak", "broadleaf", "birch"), "fall": ("water", "watersurface")},
    "garden": {"top": "grasslushcube", "body": "rockbrown", "under": "dirtdark",
               "trees": ("oak", "broadleaf", "umbrella"), "fall": ("water", "watersurface")},
    "castle": {"top": "grasscliffcube", "body": "stone2", "under": "rockdark",
               "trees": ("oak", "pine"), "fall": ("water", "watersurface")},
    "wood": {"top": "grasslushcube", "body": "rockbrown", "under": "rockdark",
             "trees": ("pine", "oak", "megapine"), "fall": ("water", "watersurface")},
    "ice": {"top": "snowcliffcube", "body": "frostedrock", "under": "icepacked",
            "trees": ("pine",), "fall": ("box", "icedeep")},
    "desert": {"top": "sanddirtcube", "body": "sandstonelayered", "under": "sandstonered",
               "trees": ("palm", "cactus"), "fall": ("water", "watersurface"), "mesa": True},
    "lava": {"top": "basalttop", "body": "basaltrough", "under": "volcanicred",
             "trees": ("snag",), "fall": ("box", "lava")},
}
HERO_KINDS = {
    "sky": ("lighthouse", "belltower", "windmill", "tower", "spirerock"),
    "garden": ("windmill", "belltower", "temple", "greattree"),
    "castle": ("keep", "tower", "belltower"),
    "wood": ("windmill", "greattree", "tower"),
    "ice": ("lighthouse", "tower", "spirerock"),
    "desert": ("pyramid", "obelisk", "domedhall"),
    "lava": ("fortress", "obelisk", "tower"),
}
def wanted(brief):
    f = brief.get("features") or {}
    return "backdrop" not in (f.get("avoid") or ())
def applies(arena, brief):
    if brief.get("family") not in FAMILIES or not wanted(brief):
        return False
    m = v1.arenas_module()
    lv = m.LEVELS.get(arena.get("level")) or {}
    return lv.get("floor", 0) is None
def _theme(brief):
    t = brief.get("theme")
    return t if t in THEMES else "sky"
def _have(tex, fallback):
    have = kit.textures()
    return tex if tex in have else fallback
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(tex, int(x0), int(x1), int(y0), int(y1), int(z0), int(z1),
                                None, tag)
def _oct(tex, cx, cz, ax, az, y0, y1, tag):
    ax, az = max(100, _q(ax)), max(100, _q(az))
    p = kit.kind("pillar").make(tex, _q(cx) - ax, _q(cx) + ax, int(y0), int(y1),
                                _q(cz) - az, _q(cz) + az, None, tag)
    p["w"], p["d"] = 2 * ax, 2 * az
    return p
def _q(v, step=100):
    return int(round(v / float(step))) * step
def play_box(arena):
    from . import place
    pieces = [p for p in arena.get("pieces") or []
              if not str(p.get("tag", "")).startswith("dress.backdrop")]
    x0, x1, z0, z1 = place.bounds(dict(arena, pieces=pieces))
    tops = sorted(p["y"] + p["h"] for p in pieces if p.get("tex") != "invisible") or [0]
    return x0, x1, z0, z1, tops[len(tops) // 2], min(p["y"] for p in pieces)
def _edge_dist(box, a):
    x0, x1, z0, z1 = box[:4]
    hx, hz = (x1 - x0) / 2.0, (z1 - z0) / 2.0
    s, c = abs(math.sin(a)), abs(math.cos(a))
    return min(hx / s if s > 1e-6 else 1e9, hz / c if c > 1e-6 else 1e9)
def hero_angle(arena, box, r):
    cx, cz = (box[0] + box[1]) / 2.0, (box[2] + box[3]) / 2.0
    spawns = [s for s in arena.get("spawns") or [] if isinstance(s, dict)]
    best, best_n = None, -1
    turn = r.random() * 15.0
    for k in range(24):
        deg = turn + 15.0 * k
        a = math.radians(deg)
        reach = _edge_dist(box, a) + GAP + 1500
        hx, hz = cx + math.sin(a) * reach, cz + math.cos(a) * reach
        n = 0
        for s in spawns:
            if s.get("yaw") is not None:
                face = float(s["yaw"])
            else:
                face = math.degrees(math.atan2(cx - s["x"], cz - s["z"]))
            to = math.degrees(math.atan2(hx - s["x"], hz - s["z"]))
            if abs((to - face + 180.0) % 360.0 - 180.0) <= HERO_FAN:
                n += 1
        if n > best_n:
            best, best_n = a, n
    return best, best_n, len(spawns)
TOP_SHARE = 0.85
TIER_SHARES = ((0.0, 0.3), (0.3, 0.55), (0.55, 0.75))
BOX_K = TOP_SHARE / 0.6
def isle(cx, cz, top, w, d, r, th, tag="dress.backdrop isle", tiers=3, solid=False):
    from . import sculpt
    topt = _have(th["top"], th["body"])
    body = _have(th["body"], "rockgrey")
    under = _have(th["under"], body)
    hw, hd = max(200, _q(w / 2.0)), max(200, _q(d / 2.0))
    band = min(200, _q(min(hw, hd) * 0.2, 10))
    depth = _q(min(hw, hd) * (0.7 + 0.2 * tiers) * r.uniform(0.9, 1.1))
    spec = {"shape": "isle", "r": hw, "rz": hd, "depth": depth, "band": band,
            "seed": r.randrange(1, 1 << 15), "body": body, "under": under}
    if th.get("mesa"):
        spec["mesa"] = True
    k = TOP_SHARE / 0.6
    p = _oct(topt, cx, cz, hw * k, hd * k, top - band, top, tag + " top")
    p["sculpt"] = spec
    out = [p]
    if solid:
        y = top - band
        y0 = top - band * 1.4
        for fa, fb in TIER_SHARES:
            share = 0.95 * (1 - fb) ** 0.85 * 0.93 / 1.08 * 0.95
            lo = _q(y0 - depth * fb)
            if share * min(hw, hd) < 100 or lo >= y:
                break
            t = _oct(body, cx, cz, hw * share / 0.6, hd * share / 0.6, lo, y, tag + " body")
            t["sculpt"] = {"shape": "none"}
            out.append(t)
            y = lo
    return out, (p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0, p["z"] - p["d"] / 2.0,
                 p["z"] + p["d"] / 2.0)
def isle_drawn(pieces):
    from . import sculpt
    ext = [sculpt.extent(p) if p.get("sculpt") else
           (p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0, p["y"], p["y"] + p["h"],
            p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0) for p in pieces]
    return (min(e[0] for e in ext), max(e[1] for e in ext), min(e[2] for e in ext),
            max(e[3] for e in ext), min(e[4] for e in ext), max(e[5] for e in ext))
def trees_on(rect, top, r, th, n, avoid=(), avoid_rects=()):
    import random as _random
    from . import flora
    x0, x1, z0, z1 = rect
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    rx, rz = (x1 - x0) / 2.0 * 0.6 - 300, (z1 - z0) / 2.0 * 0.6 - 300
    out = []
    taken = list(avoid)
    if rx < 100 or rz < 100:
        return [], taken
    for k in range(n * 6):
        if len(out) >= n:
            break
        a = r.uniform(0, 2 * math.pi)
        f = math.sqrt(r.uniform(0.0, 1.0))
        x = _q(cx + math.cos(a) * rx * f)
        z = _q(cz + math.sin(a) * rz * f)
        if ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2 > 1.0:
            continue
        if any(abs(x - a_) < 700 and abs(z - b_) < 700 for a_, b_ in taken):
            continue
        sp = r.choice(th["trees"])
        rt = _random.Random("%d/%d/%s" % (x, z, sp))
        tree = flora.build(sp, x, z, top, rt, room=300, tag="dress.backdrop tree")
        if any(_clear(_rect(t), [a_], 0) is False for t in tree for a_ in avoid_rects):
            continue
        taken.append((x, z))
        out.append(tree)
    return [p for t in out for p in t], taken
def waterfall(rect, top, bottom, r, th, cx, cz, toward, spec=None):
    from . import sculpt
    kind, tex = th["fall"]
    tex = _have(tex, "watersurface")
    x0, x1, z0, z1 = rect
    dx, dz = toward[0] - cx, toward[1] - cz
    out = []
    make = kit.kind(kind).make
    w = 300
    tag = "dress.backdrop waterfall"
    cy = bottom + 200
    if abs(dx) >= abs(dz):
        sx = 1 if dx > 0 else -1
        edge = x1 if sx > 0 else x0
        if spec is not None:
            edge = _q(sculpt.isle_edge(spec, cx, cz, 0.0 if sx > 0 else math.pi)[0], 10)
        z = _q(cz + r.uniform(-0.15, 0.15) * (z1 - z0))
        a, b = sorted((cx, edge))
        foot = (edge + sx * 10, z)
        mist = cloud(foot[0], foot[1], cy, CLOUD_OUT, r, tag="dress.backdrop cloud mist",
                     d=CLOUD_ACROSS) if kind == "water" else None
        low = _foot_y(mist, bottom)
        out.append(make(tex, a, b, top, top + 10, z - w // 2, z + w // 2, None, tag + " stream"))
        f0, f1 = sorted((edge, edge + sx * 20))
        out.append(make(tex, f0, f1, low, top + 10, z - w // 2, z + w // 2, None,
                        tag + " fall"))
        out[-1]["sculpt"] = {"shape": "sheet", "out": [sx, 0], "seed": r.randrange(1, 999)}
    else:
        sz = 1 if dz > 0 else -1
        edge = z1 if sz > 0 else z0
        if spec is not None:
            edge = _q(sculpt.isle_edge(spec, cx, cz, 0.5 * math.pi if sz > 0 else 1.5 * math.pi)[1],
                      10)
        x = _q(cx + r.uniform(-0.15, 0.15) * (x1 - x0))
        a, b = sorted((cz, edge))
        foot = (x, edge + sz * 10)
        mist = cloud(foot[0], foot[1], cy, CLOUD_ACROSS, r, tag="dress.backdrop cloud mist",
                     d=CLOUD_OUT) if kind == "water" else None
        low = _foot_y(mist, bottom)
        out.append(make(tex, x - w // 2, x + w // 2, top, top + 10, a, b, None, tag + " stream"))
        f0, f1 = sorted((edge, edge + sz * 20))
        out.append(make(tex, x - w // 2, x + w // 2, low, top + 10, f0, f1, None,
                        tag + " fall"))
        out[-1]["sculpt"] = {"shape": "sheet", "out": [0, sz], "seed": r.randrange(1, 999)}
    if mist is not None:
        out.append(mist)
    return out
CLOUD_ACROSS = 1000
CLOUD_OUT = 760
CLOUD_H = 300
def _main_puff(c):
    w, h, d = c["w"] / 2.0, c["h"] / 2.0, c["d"] / 2.0
    return (c["x"], c["y"] + h - h * 0.1, c["z"], w * 0.62, h * 0.75, d * 0.7)
def _foot_y(mist, bottom):
    if mist is None:
        return bottom
    return int(math.ceil(_main_puff(mist)[1]))
def _puffs(c):
    from . import sculpt
    sp = c.get("sculpt") or {}
    seed = int(sp.get("seed", 1))
    w, h, d = c["w"] / 2.0, c["h"] / 2.0, c["d"] / 2.0
    cx, cy, cz = c["x"], c["y"] + h, c["z"]
    out = [_main_puff(c)]
    n = 4 + int(sculpt._h(seed, 1) * 3)
    for k in range(n):
        a = 2 * math.pi * (k + sculpt._h(seed, k, 2) * 0.6) / n
        rr = 0.45 + 0.2 * sculpt._h(seed, k, 3)
        s_ = 0.42 + 0.25 * sculpt._h(seed, k, 4)
        out.append((cx + math.cos(a) * w * rr, cy + h * (0.15 * sculpt._h(seed, k, 5) - 0.2),
                    cz + math.sin(a) * d * rr, w * s_, h * (s_ + 0.25), d * s_))
    return out
FALL_IN = 0.92
def fall_faults(pieces):
    from . import sculpt
    out = []
    clouds = [p for p in pieces if "cloud mist" in str(p.get("tag", ""))]
    for f in pieces:
        if "waterfall fall" not in str(f.get("tag", "")) or not clouds:
            continue
        c = min(clouds, key=lambda q: math.hypot(q["x"] - f["x"], q["z"] - f["z"]))
        if math.hypot(c["x"] - f["x"], c["z"] - f["z"]) > c["w"] + c["d"]:
            out.append((f, "no cloud at its foot"))
            continue
        puffs = _puffs(c)
        lowest = min(py - ay for (_, py, _, _, ay, _) in puffs)
        mid = puffs[0][1]
        verts = set(v for corners, _n, _t in sculpt.faces(f) for v in corners)
        for v in verts:
            if v[1] < lowest:
                out.append((f, "a vertex at %d under its cloud (lowest %d)" % (v[1], lowest)))
                break
            if v[1] > mid + 1:
                continue
            if not any(((v[0] - px) / ax) ** 2 + ((v[1] - py) / ay) ** 2 + ((v[2] - pz) / az) ** 2
                       <= FALL_IN for (px, py, pz, ax, ay, az) in puffs):
                out.append((f, "a vertex at (%d, %d, %d) outside its cloud" % v))
                break
    return out
CLOUD_TEX = ("snowfresh", "snowblock", "plasterwhite")
CLOUD_TONE = [244, 246, 250]
def cloud(x, z, y, w, r, tag="dress.backdrop cloud", d=None):
    have = kit.textures()
    tex = next((t for t in CLOUD_TEX if t in have), "plasterwhite")
    w = max(400, _q(w))
    if d is None:
        d = max(400, _q(w * r.uniform(0.55, 0.8)))
        h = max(200, _q(w * r.uniform(0.28, 0.36)))
    else:
        d = max(400, _q(d))
        h = CLOUD_H
    p = _box(tex, x - w // 2, x + w // 2, y - h // 2, y + h // 2, z - d // 2, z + d // 2, tag)
    p["sculpt"] = {"shape": "cloud", "seed": r.randrange(1, 1 << 15), "tone": CLOUD_TONE}
    return p
def landmark_pal(theme):
    from .families.objective import palette
    pal, _ = palette(theme, None)
    acc = (pal.get("accents_built") or pal.get("accents") or [None])[0]
    return {"wall": pal.get("wall"), "trim": pal.get("trim") or pal.get("wall"),
            "roof": pal.get("roof"), "deck": pal.get("deck"), "accent": acc,
            "rock": pal.get("keel"), "leaves": pal.get("foliage")}
def _rect(p):
    m = v1.arenas_module()
    x0, x1, z0, z1, _ = m.footprint(p)
    return x0, x1, z0, z1
def _clear(rect, taken, pad):
    x0, x1, z0, z1 = rect
    return not any(x0 - pad < b[1] and x1 + pad > b[0] and z0 - pad < b[3] and z1 + pad > b[2]
                   for b in taken)
def dress(arena, brief, r):
    if not applies(arena, brief):
        return [], []
    m = v1.arenas_module()
    lv = m.LEVELS.get(arena.get("level")) or {}
    half = lv.get("half", 17500) - LEVEL_MARGIN
    floor_min = lv.get("plane", -6000) + PLANE_MARGIN
    try:
        box = play_box(arena)
    except (ValueError, KeyError):
        return [], []
    x0, x1, z0, z1, floor, low = box
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    theme = _theme(brief)
    th = THEMES[theme]
    out, notes, taken = [], [], []
    play = [_rect(p) for p in arena.get("pieces") or []
            if not str(p.get("tag", "")).startswith("dress.backdrop")]
    def inside(rect):
        return all(abs(v) <= half for v in rect)
    def spots(a, size, extra=0.0):
        edge = _edge_dist(box, a)
        top = half * 1.5
        out_ = []
        d = edge + GAP + size / 2.0 + extra
        while d < top:
            out_.append(d)
            d += 400
        d = edge
        while d > size:
            out_.append(d)
            d -= 400
        for d in out_:
            yield _q(cx + math.sin(a) * d), _q(cz + math.cos(a) * d)
    def find(angles, w, d, extra, pad, depth):
        for a in angles:
            for px, pz in spots(a, max(w, d), extra):
                rect = (px - w // 2, px + w // 2, pz - d // 2, pz + d // 2)
                if inside(rect) and _clear(rect, play, GAP + 100) and _clear(rect, taken, pad):
                    return px, pz
        return None
    a0, seen, of = hero_angle(arena, box, r)
    kinds = [k for k in HERO_KINDS.get(theme, HERO_KINDS["sky"])]
    want = [k for k in ((brief.get("features") or {}).get("want") or ())
            if k in kinds]
    from . import landmarks
    kind = want[0] if want else r.choice(kinds)
    pal = landmark_pal(theme)
    lm, lh = landmarks.derive(kind, r, pal, tag="dress.backdrop.landmark")
    lrects = [_rect(p) for p in lm]
    lw = max(max(q[1] for q in lrects) - min(q[0] for q in lrects),
             max(q[3] for q in lrects) - min(q[2] for q in lrects))
    hero_w = max(2400, _q(lw + 1000, 200))
    hero_top = _q(floor + r.choice((-400, -200, 0, 200)))
    hero_top = max(hero_top, _q(floor + RISE - lh + 100))
    if hero_top - 4000 < floor_min:
        hero_top = _q(floor_min + 4000)
    at = find([a0 + math.radians(da) for da in (0, 10, -10, 20, -20, 30, -30)],
              _q(hero_w * BOX_K), _q(hero_w * BOX_K), 0, 0, 4000)
    if at is not None:
        ox, oz = at
        pieces, rect = isle(ox, oz, hero_top, hero_w, hero_w, r, th, tiers=4)
        lift = 0
        for p in lm:
            q = dict(p)
            q["x"] += ox
            q["z"] += oz
            q["y"] += hero_top + lift
            pieces.append(q)
        tr, _ = trees_on(rect, hero_top, r, th, 2)
        pieces += [t for t in tr if abs(t["x"] - ox) > lw / 2.0 + 400
                   or abs(t["z"] - oz) > lw / 2.0 + 400]
        out += pieces
        taken.append(rect)
        notes.append("a %s on a floating isle beyond the edge, seen from %d of %d spawns"
                     % (kind, seen, of))
    else:
        notes.append("no room beyond the edge for the far landmark's isle")
    n_mid = 4 if half - max(abs(x0), abs(x1), abs(z0), abs(z1)) > 9000 else 3
    fall_left = 1
    for i in range(n_mid):
        base = a0 + 2 * math.pi * (i + 1) / (n_mid + 1) + math.radians(r.uniform(-14, 14))
        w = _q(r.choice((1400, 1600, 1800, 2000)), 200)
        d = _q(w * r.uniform(0.8, 1.2), 200)
        top = _q(floor + r.choice((-1400, -1000, -600, 400, 800)))
        at = find([base + math.radians(da) for da in (0, 12, -12, 24, -24)], _q(w * BOX_K),
                  _q(d * BOX_K),
                  r.choice((0, 600, 1200)), 800, 2400)
        if at is None:
            notes.append("one isle found no room")
            continue
        px, pz = at
        pieces, rect = isle(px, pz, top, w, d, r, th, tiers=3)
        avoid = []
        if fall_left and th["fall"]:
            fall = waterfall(rect, top, max(floor_min + 300, top - 2400), r, th, px, pz, (cx, cz),
                             spec=pieces[0].get("sculpt"))
            pieces += fall
            avoid = [_rect(f) for f in fall]
            fall_left -= 1
        tr, _ = trees_on(rect, top, r, th, r.choice((1, 2, 3)), avoid_rects=avoid)
        pieces += tr
        out += pieces
        taken.append(rect)
    for i in range(r.choice((4, 5, 6))):
        a = r.uniform(0, 2 * math.pi)
        w = _q(r.choice((400, 500, 600, 700)))
        top = _q(floor + r.uniform(-1800, 1400))
        at = find([a, a + 0.4, a - 0.4], _q(w * BOX_K), _q(w * BOX_K), r.uniform(0, 2500), 500,
                  1200)
        if at is None:
            continue
        pieces, rect = isle(at[0], at[1], top, w, w, r, th, tag="dress.backdrop rock", tiers=2)
        out += pieces
        taken.append(rect)
    for i in range(r.choice((5, 6, 7, 8))):
        a = r.uniform(0, 2 * math.pi)
        w = _q(r.choice((1200, 1600, 2000, 2600)))
        y = _q(floor + r.choice((-3000, -2200, -1500, 600, 1400, 2400)))
        at = find([a, a + 0.5, a - 0.5], w, w, r.uniform(0, 5000), 300, 0)
        if at is None:
            continue
        c = cloud(at[0], at[1], y, w, r)
        out.append(c)
        taken.append(_rect(c))
    out = [p for p in out if p["y"] >= floor_min]
    for p in out:
        p["model"] = m.model_name(p)
    if out:
        notes.insert(0, "the diorama round the map: %d isles and rocks (%d pieces)"
                     % (len(taken), len(out)))
    return out, notes
