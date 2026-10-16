from .layout import Layout, Sym, grow, q
SKELETONS = {
    "keep":        (("turn4", "mirror", "turn2"), "keeps", False, 5600),
    "three_lane":  (("mirror",), "lanes", True, 4400),
    "ring":        (("turn4",), "rings", True, 7200),
    "hub":         (("turn4",), "hubs", True, 5600),
    "twin":        (("mirror",), "bases", False, 5600),
    "terraces":    (("turn4",), "hills", False, 7200),
    "archipelago": (("turn4", "mirror"), "islands", True, 5600),
    "courtyard":   (("turn4",), "walls", False, 5600),
    "canyon":      (("mirror",), "canyons", False, 5600),
    "knoll":       (("turn4",), "hills", False, 7200),
    "ridge":       (("mirror",), "hills", False, 6400),
    "mesa":        (("mirror",), "hills", False, 6400),
    "rooms":       (("mirror",), "walls", True, 5600),
}
ROOM_WANTS = ("rooms", "training_course")
ABOUT = {"bridge": ("canyon", "archipelago", "hub", "ring"), "tower": ("courtyard", "terraces"),
         "hill": ("terraces", "knoll", "ridge", "mesa"), "pit": ("terraces", "ring"),
         "crown": ("keep",),
         "wall": ("courtyard",), "arch": ("courtyard",), "loop": ("ring",),
         "plaza": ("hub", "twin")}
SIZE_ACROSS = {"tiny": 4000, "small": 4800, "medium": 8000, "large": 10000, "huge": 12000,
               "gigantic": 16000}
def across_of(brief, players=16):
    size = brief["size"]
    if isinstance(size, dict) and size.get("across"):
        return int(size["across"])
    if isinstance(size, str) and size in SIZE_ACROSS:
        base = SIZE_ACROSS[size]
        return int(base * (0.55 + 0.45 * min(players, 16) / 16.0))
    try:
        from .brief import across_units
        return int(across_units(size, 8000))
    except Exception:
        return 8000
def _aspect(size):
    if "w" in size and "d" in size:
        return max(0.01, float(size["w"])) / max(0.01, float(size["d"]))
    return float(size.get("aspect") or 1.0)
def wanted_units(brief):
    defaulted = set(getattr(brief, "defaulted", ()) or ())
    sym = "auto" if "symmetry" in defaulted else brief["symmetry"]
    sides = "auto" if "sides" in defaulted else brief["sides"]
    if sym in ("mirror", "turn2") or sides == "2":
        return 2
    if sym in ("turn4", "turn8"):
        return 4
    return None
def choose(brief, dice, r, across):
    units = wanted_units(brief)
    flat = brief["verticality"] == "flat"
    want = set(brief["features"]["want"])
    if want & set(ROOM_WANTS) and units != 4:
        return "rooms", "mirror", "skeleton rooms: %s wished" % " and ".join(
            sorted(want & set(ROOM_WANTS)))
    size = brief["size"]
    long_ = isinstance(size, dict) and ("w" in size or "aspect" in size) and \
        max(_aspect(size), 1.0 / _aspect(size)) >= 1.5
    anchors = [a["what"] for a in brief["anchors"]]
    weights = []
    for name, (syms, knob, flat_ok, min_across) in sorted(SKELETONS.items()):
        if flat and not flat_ok:
            continue
        if across < min_across:
            continue
        if units == 4 and "turn4" not in syms:
            continue
        if units == 2 and not any(s in ("mirror", "turn2") for s in syms):
            continue
        w = dice.factor(knob) if dice is not None else 1.0
        for a in anchors + sorted(want):
            if name in ABOUT.get(a, ()):
                w *= 6.0
        if name == "keep":
            w *= 0.8
        if name == "rooms":
            if set(ROOM_WANTS) & set(brief["features"]["avoid"]):
                continue
            w *= 1.5 if long_ else 0.35
        weights.append((name, w))
    if not weights:
        weights = [("keep", 1.0)]
    answers = {n: sum(1 for a in anchors if n in ABOUT.get(a, ())) for n, _ in weights}
    most = max(answers.values())
    if most:
        weights = [(n, w) for n, w in weights if answers[n] == most]
    total = sum(w for _, w in weights)
    x = r.random() * total
    pick = weights[-1][0]
    for name, w in weights:
        x -= w
        if x < 0:
            pick = name
            break
    syms = SKELETONS[pick][0]
    if units == 2:
        sym = "mirror" if "mirror" in syms else "turn2"
    elif units == 4:
        sym = "turn4"
    else:
        sym = syms[0] if len(syms) == 1 else r.choice(syms)
    why = "skeleton %s (%s) from %s" % (pick, sym, ", ".join(
        "%s %.2g" % (n, w) for n, w in sorted(weights, key=lambda t: -t[1])[:4]))
    return pick, sym, why
def heights(brief, dice, r):
    vert = brief["verticality"]
    if vert == "flat":
        return 0, 0
    h = dice["height"] if dice is not None else 2
    if vert == "low":
        return r.choice((200, 300)), 400
    if vert == "high":
        return r.choice((400, 600, 600)), 1200 + 200 * h
    return r.choice((300, 400, 400, 600)) if h >= 1 else 300, 600 + 100 * h
def lane_width(dice, r):
    w = dice["width"] if dice is not None else 2
    return (600, 800, 1000, 1200)[w] if r.random() < 0.8 else r.choice((600, 800, 1000))
def base_size(units, across):
    per = 16 // (units if units else 4)
    width = max(1800, (per - 1) * 450 + 600)
    depth = 1400 if across >= 6000 else 1200
    return q(width), depth
def common_params(L, name, across, r):
    brief, dice = L.brief, L.dice
    step, high = heights(brief, dice, r)
    stairs = (dice is not None and dice["stairs"] >= 2 and "ramps_only" not in
              brief["features"]["want"] and "stairs" not in brief["features"]["avoid"]
              and r.random() < 0.5) or "stairs" in brief["features"]["want"]
    P = {"skeleton": name, "across": across, "step": step, "high": high, "stairs": stairs,
         "Lw": lane_width(dice, r),
         "centre": "-", "lane": "-", "corner": "-", "shield": "spawn shields",
         "I": 0, "G": 0, "B": 0, "Dh": 0, "Ph": 0}
    return P
CENTRE_SIZES = {"tiny": 0.6, "small": 0.8, "medium": 1.0, "large": 1.3, "huge": 1.6,
                "gigantic": 2.0}
def centre_scale(L):
    for a in L.brief["anchors"]:
        where = a.get("where") or {}
        if a.get("what") == "centre" or (where.get("compass") == "c" and a.get("size")):
            return CENTRE_SIZES.get(a.get("size") or "medium", 1.0)
    return 1.0
def ramp_kind(L, rise):
    return bool(L.params.get("stairs")) and rise <= 250
def ramp(L, x0, x1, y0, y1, z0, z1, rises, tag, copy=True, role="ramp"):
    return L.ramp(role, x0, x1, y0, y1, z0, z1, rises, tag, copy=copy,
                  stairs=ramp_kind(L, y1 - y0))
def bridge(L, rect, y, tag, copy=True, role="bridge", zone="lane"):
    x0, x1, z0, z1 = rect
    out = L.box(role, x0, x1, y - 100, y, z0, z1, tag, copy=copy)
    L.floor(rect, y, zone, fill=min(x1 - x0, z1 - z0) >= 1200, copy=copy)
    return out
def gap_base(L, Bw, Bd, z_in, gap=600, y=0, links=3, w=400, tex_i=0):
    zb = z_in + gap
    L.slab((-Bw // 2, Bw // 2, zb, zb + Bd), y, "floor", "base0.floor",
           tex=L.pal["accents"][tex_i], zone="base", fill=False)
    L.base("base0", (-Bw // 2, Bw // 2, zb, zb + Bd), y, (0, -1))
    if links == 3:
        xs = (-Bw // 2 + w // 2, 0, Bw // 2 - w // 2)
    else:
        xs = (-Bw // 2 + w // 2, Bw // 2 - w // 2)
    for xc in xs:
        rect = (xc - w // 2, xc + w // 2, z_in, zb)
        bridge(L, rect, y, "base link")
        L.keep(grow(rect, 100))
        L.opening((rect[0], rect[1], z_in - 100, zb + 100))
    return zb
def loops(L, units, spec):
    from .skeleton import Zone
    for u in range(units):
        n = (u + 1) % units
        pv = (u - 1) % units
        for ids, label in spec:
            real = [i.format(u=u, n=n, p=pv) for i in ids]
            for z in real:
                if z not in L.graph.zones:
                    kind = z.rstrip("0123456789").split("_")[0]
                    L.graph.add(Zone(z, kind, u, 0, 0))
            if len(set(real)) >= 3:
                L.graph.loop(real, label.format(u=u))
def build_three_lane(L, P, r):
    A = P["across"]
    H = q(A / 2.0)
    Wx = q(A * 0.42)
    step = P["step"]
    lw = q(max(800, min(1400, P["Lw"] + 200)))
    sw = 600
    mw = q(max(1200, min(2000, lw * r.choice((1.0, 1.5, 2.0)))))
    side_x = Wx - lw // 2
    inner = side_x - lw // 2
    Bw = min(base_size(2, A)[0], 2 * (inner - 400))
    Bw = q(max(1800, Bw))
    two_rows = Bw < 8 * 450 - 450 + 600
    Bd = 1900 if two_rows else (1400 if A >= 6000 else 1200)
    zf = H - Bd
    hi = step if step and r.random() < 0.85 else 0
    lo = -min(step, 400) if step and r.random() < 0.5 and not L.solid and A >= 6000 else 0
    left_y, right_y = (hi, lo) if r.random() < 0.5 else (lo, hi)
    P.update({"centre": "plaza", "lane": "three lanes", "corner": "-",
              "I": Wx, "G": zf, "B": Bd, "Dh": 0, "Ph": hi})
    L.slab((-Bw // 2, Bw // 2, zf, H), 0, "floor", "base0.floor",
           tex=L.pal["accents"][0], zone="base", fill=False)
    L.base("base0", (-Bw // 2, Bw // 2, zf, H), 0, (0, -1))
    L.slab((-mw // 2, mw // 2, 0, zf), 0, "floor", "mid lane", zone="field")
    L.opening((-mw // 2, mw // 2, zf - 100, zf + 100))
    L.keep((-mw // 2, mw // 2, zf - 400, zf))
    z_end = zf + sw + 200
    jog = lw if (r.random() < 0.5 and inner - lw > mw // 2 + 600) else 0
    for name, sx, y in (("left", -1, left_y), ("right", 1, right_y)):
        x0, x1 = sorted((sx * (inner), sx * (inner + lw)))
        lx0, lx1 = sorted((sx * Bw // 2, sx * inner))
        bridge(L, (lx0, lx1, zf, zf + sw), 0, "%s link" % name)
        L.keep((lx0 - 200, lx1 + 200, zf - 200, zf + sw + 200))
        L.opening((lx0 - 100, lx1 + 100, zf, zf + sw))
        if y != 0:
            room = (zf - 200 - 200) // 2
            y = (1 if y > 0 else -1) * min(abs(y), room // 50 * 50)
            if abs(y) < 100:
                y = 0
        if y == 0:
            z_main = z_end
        else:
            run = 2 * abs(y)
            zr = zf - 200
            L.slab((x0, x1, zr, z_end), 0, "floor", "%s lane foot" % name, zone="field",
                   fill=False)
            if y > 0:
                ramp(L, x0, x1, 0, y, zr - run, zr, "-z", "%s lane ramp" % name)
            else:
                ramp(L, x0, x1, y, 0, zr - run, zr, "+z", "%s lane ramp" % name)
            L.keep((x0 - 200, x1 + 200, zr - run - 400, zr + 200))
            z_main = zr - run
            L.opening((x0, x1, z_main - 100, z_main + 100))
            L.opening((x0, x1, zr - 100, zr + 100))
        if jog:
            zj = q(z_main / 2)
            L.slab((x0, x1, zj, z_main), y, "floor", "%s lane" % name, zone="field")
            jx0, jx1 = x0 - sx * jog, x1 - sx * jog
            L.slab((jx0, jx1, 0, zj + lw), y, "floor", "%s lane" % name, zone="field")
            L.keep((min(x0, jx0), max(x1, jx1), zj - 200, zj + 200))
        else:
            L.slab((x0, x1, 0, z_main), y, "floor", "%s lane" % name, zone="field")
        if y > 0:
            L.spot(sx * side_x, y, q(z_main * 0.6), 0, "high lane")
    cs = centre_scale(L)
    cw = q(max(mw // 2 + 400, A * 0.12 * cs))
    cd = q(min(max(800, A * 0.1 * cs), zf - 800))
    L.slab((-cw, cw, 0, cd), 0, "deck", "centre.plaza", zone="centre")
    cross_w = 600
    for zc0, label in ((0, "centre"), (q(zf * r.choice((0.45, 0.55))), "mid")):
        if label == "mid" and L.dice is not None and L.dice["crossings"] == 0:
            continue
        z0, z1 = (zc0, zc0 + cross_w) if label == "centre" else (zc0 - cross_w // 2,
                                                                   zc0 + cross_w // 2)
        if label == "mid" and z0 < cd + 400:
            continue
        if label == "mid" and jog:
            zj_all = [q((zf - 200 - 2 * abs(yy)) / 2) if yy else q(z_end / 2) for yy in
                      (left_y, right_y)]
            if any(z0 - lw - 400 < zj < z1 + 400 for zj in zj_all):
                continue
        for sx, y in ((-1, left_y), (1, right_y)):
            xa = cw if label == "centre" else mw // 2
            xb = inner - (jog if jog else 0)
            if label == "mid" and jog and z1 > q((zf - 200 - 2 * abs(y)) / 2):
                xb = inner
            a, b = (xa, xb) if sx > 0 else (-xb, -xa)
            if b - a < 200:
                continue
            run = 2 * abs(y)
            if y and b - a < run + 200:
                continue
            if y == 0:
                bridge(L, (a, b, z0, z1), 0, "%s cross link" % label)
            elif sx > 0:
                bridge(L, (a, b - run, z0, z1), 0, "%s cross link" % label)
                if y > 0:
                    ramp(L, b - run, b, 0, y, z0, z1, "+x", "%s cross ramp" % label)
                else:
                    ramp(L, b - run, b, y, 0, z0, z1, "-x", "%s cross ramp" % label)
            else:
                bridge(L, (a + run, b, z0, z1), 0, "%s cross link" % label)
                if y > 0:
                    ramp(L, a, a + run, 0, y, z0, z1, "-x", "%s cross ramp" % label)
                else:
                    ramp(L, a, a + run, y, 0, z0, z1, "+x", "%s cross ramp" % label)
            L.keep((a - 100, b + 100, z0 - 100, z1 + 100))
            L.opening((a - 200, b + 200, z0, z1))
    loops(L, 2, [(["base{u}", "laneL{u}", "centre", "laneM{u}"], "left loop {u}"),
                 (["base{u}", "laneR{u}", "centre", "laneM{u}"], "right loop {u}"),
                 (["laneL{u}", "laneM{u}", "laneR{u}", "laneR{n}", "laneM{n}", "laneL{n}"],
                  "the lanes {u}")])
    L.landmark = {"x": 0, "z": 0, "y": 0, "around": 200, "max_w": 800}
    if L.landmark:
        L.keep((-400, 400, -400, 400), copy=False)
    L.modules.update({"centre": "plaza", "lanes": "%s/0/%s" % (left_y, right_y),
                      "jog": bool(jog)})
def build_ring(L, P, r):
    A = P["across"]
    Bw, Bd = base_size(4, A)
    R = q(A / 2.0 - 0.75 * Bd - 400)
    wr = q(max(800, min(1400, A * 0.13)))
    step = P["step"]
    C = q(max(600, min(R * r.choice((0.3, 0.35, 0.4)) * centre_scale(L), R - wr - 600)))
    Dh = step if step and r.random() < 0.7 else 0
    Ph = step if step else 0
    sw = q(max(400, min(800, P["Lw"])))
    P.update({"centre": "island" + (" raised" if Dh else ""), "lane": "ring + spokes",
              "corner": "raised corner" if Ph else "-", "I": C, "G": R - wr - C, "B": Bd,
              "Dh": Dh, "Ph": Ph})
    cz0 = R - wr
    corner = (R - wr, R, R - wr, R)
    L.slab((-R + wr, R - wr, cz0, R), 0, "floor", "ring", zone="field")
    if Ph:
        L.slab(corner, Ph, "deck", "ring corner", zone="perch", fill=False)
        run = 2 * Ph
        ramp(L, R - wr - run, R - wr, 0, Ph, cz0, R, "+x", "ring corner ramp")
        L.keep((R - wr - run - 200, R - wr, cz0, R))
        ramp(L, R - wr, R, 0, Ph, R - wr - run, R - wr, "+z", "ring corner ramp")
        L.spot(R - wr // 2, Ph, R - wr // 2, 0, "ring corner")
    else:
        L.slab(corner, 0, "floor", "ring corner", zone="field")
    gap_base(L, max(Bw, 2400), Bd, R)
    span = cz0 - C
    if Dh and span >= 2 * Dh + 400:
        bridge(L, (-sw // 2, sw // 2, C + 2 * Dh, cz0), 0, "spoke")
        ramp(L, -sw // 2, sw // 2, 0, Dh, C, C + 2 * Dh, "-z", "spoke ramp")
        cy = Dh
    else:
        bridge(L, (-sw // 2, sw // 2, C, cz0), 0, "spoke")
        cy = 0
        Dh = 0
        P["Dh"] = 0
    L.keep((-sw // 2 - 200, sw // 2 + 200, C - 200, cz0 + 200))
    L.opening((-sw // 2, sw // 2, cz0 - 100, cz0 + 100))
    L.opening((-sw // 2, sw // 2, C - 100, C + 100))
    L.slab((-C, C, -C, C), cy, "deck", "centre island", zone="centre", copy=False)
    L.spot(C // 2, cy, C // 2, 0, "centre")
    L.landmark = {"x": 0, "z": 0, "y": cy, "around": 200, "max_w": max(400, C - 400)}
    if L.landmark:
        L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 4, [(["base{u}", "ring{u}", "corner{u}", "ring{n}", "base{n}"], "ring {u}"),
                 (["ring{u}", "spoke{u}", "centre", "spoke{n}", "ring{n}", "corner{u}"],
                  "spokes {u}")])
    L.modules.update({"centre": "island", "corner": "raised" if Ph else "flat",
                      "spoke": "ramp" if Dh else "bridge"})
def build_hub(L, P, r):
    A = P["across"]
    Bw, Bd = base_size(4, A)
    half = A / 2.0
    Rb = q(half - Bd)
    Hc = q(max(800, min(half * r.choice((0.18, 0.22, 0.26)) * centre_scale(L), Rb - 1600)))
    Rm = q((Hc + Rb) / 2.0)
    n = q(max(400, min(1000, (Rb - Hc) * 0.25)))
    sw = q(max(400, min(800, P["Lw"])))
    step = P["step"]
    Dh = step if step and r.random() < 0.6 else 0
    Ph = step if step and r.random() < 0.8 else 0
    if Dh and (Rm - n) - Hc < 2 * Dh:
        Dh = 0
    P.update({"centre": "hub" + (" raised" if Dh else ""), "lane": "spokes + web",
              "corner": "raised island" if Ph else "island", "I": Hc, "G": Rb - Hc, "B": Bd,
              "Dh": Dh, "Ph": Ph})
    L.slab((-Hc, Hc, -Hc, Hc), Dh, "deck", "hub", zone="centre", copy=False)
    L.spot(Hc // 2, Dh, Hc // 2, 0, "hub")
    L.slab((-n, n, Rm - n, Rm + n), 0, "floor", "spoke node", zone="field")
    a, b = Hc, Rm - n
    if Dh and b - a >= 2 * Dh:
        if b - a > 2 * Dh:
            bridge(L, (-sw // 2, sw // 2, a + 2 * Dh, b), 0, "inner spoke")
        ramp(L, -sw // 2, sw // 2, 0, Dh, a, a + 2 * Dh, "-z", "hub ramp")
    else:
        bridge(L, (-sw // 2, sw // 2, a, b), 0, "inner spoke")
        if Dh:
            Dh = 0
            P["Dh"] = 0
    L.keep((-sw // 2 - 200, sw // 2 + 200, a - 200, b + 200))
    bridge(L, (-sw // 2, sw // 2, Rm + n, Rb), 0, "outer spoke")
    L.keep((-sw // 2 - 200, sw // 2 + 200, Rm + n - 200, Rb + 200))
    ci = (Rm - n, Rm + n, Rm - n, Rm + n)
    L.slab(ci, Ph, "deck" if Ph else "floor", "web island", zone="perch" if Ph else "field")
    L.spot(Rm, Ph, Rm, 0, "web island")
    for (rect, rises) in (((n, Rm - n, Rm - sw // 2, Rm + sw // 2), "+x"),
                          ((Rm - sw // 2, Rm + sw // 2, n, Rm - n), "+z")):
        x0, x1, z0, z1 = rect
        length = (x1 - x0) if rises == "+x" else (z1 - z0)
        if Ph and length >= 2 * Ph + 200:
            run = 2 * Ph
            if rises == "+x":
                bridge(L, (x0, x1 - run, z0, z1), 0, "web link")
                ramp(L, x1 - run, x1, 0, Ph, z0, z1, "+x", "web ramp")
            else:
                bridge(L, (x0, x1, z0, z1 - run), 0, "web link")
                ramp(L, x0, x1, 0, Ph, z1 - run, z1, "+z", "web ramp")
        elif Ph:
            continue
        else:
            bridge(L, rect, 0, "web link")
        L.keep(grow(rect, 100))
    L.slab((-Bw // 2, Bw // 2, Rb, Rb + Bd), 0, "floor", "base0.floor", tex=L.pal["accents"][0],
           zone="base", fill=False)
    L.base("base0", (-Bw // 2, Bw // 2, Rb, Rb + Bd), 0, (0, -1))
    fz0, fz1 = Rb, Rb + sw
    if Rm + n <= Rb - 200 and Rm - sw // 2 > Bw // 2 + 200:
        for sx in (1, -1):
            a0, a1 = sorted((sx * Bw // 2, sx * (Rm + sw // 2)))
            bridge(L, (a0, a1, fz0, fz1), 0, "flank link")
            L.keep((a0 - 100, a1 + 100, fz0 - 200, fz1 + 200))
            za, zb = Rm + n, fz0
            run = 2 * Ph
            x0, x1 = sorted((sx * (Rm - sw // 2), sx * (Rm + sw // 2)))
            if Ph and zb - za >= run + 200:
                bridge(L, (x0, x1, za + run, zb), 0, "flank link")
                ramp(L, x0, x1, 0, Ph, za, za + run, "-z", "flank ramp")
            elif not Ph and zb > za:
                bridge(L, (x0, x1, za, zb), 0, "flank link")
            L.keep((x0 - 200, x1 + 200, za - 200, zb))
            L.opening((x0, x1, za - 100, za + 100))
            L.opening((a0, a1, fz0 - 100, fz1 + 100))
    L.opening((-Bw // 2, Bw // 2, Rb - 100, Rb + 100))
    L.landmark = {"x": 0, "z": 0, "y": Dh, "around": 200, "max_w": max(400, Hc - 400)}
    if L.landmark:
        L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 4, [(["hub", "node{u}", "web{u}", "node{n}"], "web {u}"),
                 (["base{u}", "node{u}", "web{u}"], "east flank {u}"),
                 (["base{u}", "node{u}", "web{p}"], "west flank {u}")])
    L.modules.update({"centre": "hub", "web": "raised" if Ph else "flat"})
def build_twin(L, P, r):
    A = P["across"]
    H = q(A / 2.0)
    Wx = q(A * 0.4)
    step = max(300, P["step"])
    Yb = step
    Bd = 1400 if A >= 6000 else 1200
    cw = 600
    zf = H - Bd
    run = 2 * Yb
    Dh = step if r.random() < 0.6 else 0
    P.update({"centre": "bunker" if not Dh else "raised platform", "lane": "ramps + catwalks",
              "corner": "catwalk", "I": Wx, "G": zf, "B": Bd, "Dh": Dh, "Ph": Yb})
    L.slab((-Wx, Wx, zf, H), Yb, "floor", "base0.plateau", tex=L.pal["accents"][0], zone="base",
           fill=False, thick=Yb + 200)
    Bw = min(2 * Wx - 2 * cw - 400, base_size(2, A)[0])
    L.base("base0", (-Bw // 2, Bw // 2, zf, H), Yb, (0, -1))
    L.slab((-Wx + cw, Wx - cw, 0, zf), 0, "floor", "field", zone="field")
    rx = q(Bw // 2) - 300
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (rx - 300), sx * (rx + 300)))
        ramp(L, x0, x1, 0, Yb, zf - run, zf, "+z", "plateau ramp")
        L.keep((x0 - 200, x1 + 200, zf - run - 400, zf))
        L.opening((x0, x1, zf - 100, zf + 100))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (Wx - cw), sx * Wx))
        L.slab((x0, x1, 0, zf), Yb, "wall", "catwalk", zone="perch", fill=False,
               thick=Yb + 200)
        ix0, ix1 = (x1, x1 + 600) if sx < 0 else (x0 - 600, x0)
        rz = q(zf * 0.15)
        if rz + run <= zf - run - 400:
            ramp(L, ix0, ix1, 0, Yb, rz, rz + run, "+z", "catwalk ramp")
            L.keep((ix0 - 200, ix1 + 200, rz - 400, rz + run + 400))
            edge = x1 if sx < 0 else x0
            L.opening((edge - 100, edge + 100, rz - 100, rz + run + 100))
        L.spot(sx * (Wx - cw // 2), Yb, q(zf * 0.6), 0, "catwalk")
    cx, cz = q(max(800, A * 0.1)), q(max(600, A * 0.08))
    if Dh:
        L.slab((-cx, cx, 0, cz), Dh, "deck", "centre platform", zone="centre", fill=False,
               thick=Dh + 200)
        for sx in (-1, 1):
            x0, x1 = sorted((sx * cx, sx * (cx + 2 * Dh)))
            ramp(L, x0, x1, 0, Dh, 0, min(cz, 600), "-x" if sx > 0 else "+x", "centre ramp")
            L.keep((x0 - 200, x1 + 200, 0, min(cz, 600) + 200))
        L.spot(0, Dh, cz // 2, 0, "centre platform")
        L.landmark = {"x": 0, "z": 0, "y": Dh, "around": Yb, "max_w": max(400, cx - 400)}
    else:
        L.box("wall", -cx, -cx + 200, 0, 450, 200, cz + 200, "centre bunker")
        L.box("wall", cx - 200, cx, 0, 450, 200, cz + 200, "centre bunker")
        L.keep((-cx - 200, cx + 200, 0, cz + 400))
        L.landmark = {"x": 0, "z": 0, "y": 0, "around": 450, "max_w": 600}
    if L.landmark:
        L.keep((-500, 500, -500, 500), copy=False)
    loops(L, 2, [(["base{u}", "rampL{u}", "field", "rampR{u}"], "front {u}"),
                 (["base{u}", "catwalkL", "base{n}", "catwalkR"], "flanks {u}"),
                 (["field", "catwalkL", "base{u}", "rampL{u}"], "left {u}")])
    L.modules.update({"centre": P["centre"], "plateau": Yb})
def build_terraces(L, P, r):
    A = P["across"]
    Bw, Bd = base_size(4, A)
    R0 = q(A / 2.0 - 0.75 * Bd - 300)
    n = 3 if A < 7000 else r.choice((3, 4))
    dy = max(200, min(400, P["step"] or 300))
    if dy > 250:
        dy = 300 if dy < 400 else 400
    bowl = r.random() < (0.35 if L.dice is None or L.dice["pits"] < 2 else 0.7)
    named = set(a["what"] for a in L.brief["anchors"])
    if "koth" in (L.brief.get("modes") or []):
        named.add("hill")
    if "hill" in named and "pit" not in named:
        bowl = False
    elif "pit" in named and "hill" not in named:
        bowl = True
    sgn = -1 if bowl else 1
    w_min = 2 * dy + 400
    while n > 2 and (n + 1) * w_min > R0:
        n -= 1
    while (n + 1) * (2 * dy + 400) > R0 and dy > 200:
        dy -= 100
    w_min = 2 * dy + 400
    base_w = q(R0 / float(n + 1))
    widths = []
    for k in range(n):
        w = base_w + r.choice((-200, 0, 0, 200))
        widths.append(max(w_min, w))
    while R0 - sum(widths) < w_min and max(widths) > w_min:
        i = widths.index(max(widths))
        widths[i] -= 200
    radii = [R0]
    for w in widths:
        radii.append(max(600, radii[-1] - w))
    P.update({"centre": "bowl" if bowl else "summit", "lane": "terraces",
              "corner": "-", "I": radii[-1], "G": R0 - radii[-1], "B": Bd,
              "Dh": sgn * dy * n, "Ph": dy})
    bottom = -200 if not bowl else -200 - dy * n
    for k in range(n + 1):
        Ro = radii[k]
        Ri = radii[k + 1] if k < n else 0
        y = sgn * dy * k
        tag = "terrace %d" % k if k < n else "summit"
        if k < n:
            L.box("floor" if k % 2 == 0 else "deck", -Ro, Ro, bottom, y, Ri, Ro, tag)
            L.floor((-Ro + (Ro - Ri), Ro - (Ro - Ri), Ri, Ro), y, "field")
        else:
            L.box("deck", -Ro, Ro, bottom, y, -Ro, Ro, tag, copy=False)
            L.floor((-Ro, Ro, -Ro, Ro), y, "centre", copy=False)
    for k in range(n):
        Ri = radii[k + 1]
        y0, y1 = sgn * dy * k, sgn * dy * (k + 1)
        lo, hi = min(y0, y1), max(y0, y1)
        run = 2 * dy
        w = 600
        xs = (0,) if k % 2 == 1 or q(Ri * 0.6) + w // 2 > Ri - run - 200 \
            else (-q(Ri * 0.6), q(Ri * 0.6))
        for xc in xs:
            x0, x1 = xc - w // 2, xc + w // 2
            if not bowl:
                ramp(L, x0, x1, lo, hi, Ri, Ri + run, "-z", "terrace ramp %d" % k)
                L.keep((x0 - 200, x1 + 200, Ri - 200, Ri + run + 400))
            else:
                ramp(L, x0, x1, lo, hi, Ri - run, Ri, "+z", "terrace ramp %d" % k)
                L.keep((x0 - 200, x1 + 200, Ri - run - 400, Ri + 200))
            L.opening((x0, x1, Ri - 100, Ri + 100))
        L.spot(q(Ri * 0.8), sgn * dy * (k + 1), Ri - 300, 0, "terrace %d" % (k + 1))
    gap_base(L, max(Bw, 2400), Bd, R0, gap=400)
    top = sgn * dy * n
    L.landmark = {"x": 0, "z": 0, "y": top, "around": dy, "max_w": max(400, radii[-1] - 400)}
    if L.landmark:
        L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 4, [(["base{u}", "tier0_{u}", "tier0_{n}", "base{n}"], "rim {u}"),
                 (["tier0_{u}", "tier1_{u}", "tier1_{n}", "tier0_{n}"], "step {u}"),
                 (["tier1_{u}", "summit", "tier1_{n}"], "summit {u}")])
    L.modules.update({"centre": P["centre"], "tiers": n, "step": dy})
def _orbit(pt, sym):
    i, j = pt
    if sym == "turn4":
        return sorted({(i, j), (j, -i), (-i, -j), (-j, i)})
    return sorted({(i, j), (i, -j)})
def _two_edge_connected(nodes, edges):
    adj = {v: [] for v in nodes}
    for k, (a, b) in enumerate(edges):
        adj[a].append((b, k))
        adj[b].append((a, k))
    start = nodes[0]
    index, low = {}, {}
    counter = [0]
    bridges = []
    def visit(v, pe):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        for w, k in adj[v]:
            if k == pe:
                continue
            if w not in index:
                visit(w, k)
                low[v] = min(low[v], low[w])
                if low[w] > index[v]:
                    bridges.append(k)
            else:
                low[v] = min(low[v], index[w])
    visit(start, None)
    return len(index) == len(nodes) and not bridges
def build_archipelago(L, P, r, sym_kind):
    A = P["across"]
    step = P["step"]
    N = 2
    Bw, Bd = base_size(4 if sym_kind == "turn4" else 2, A)
    S = q((A / 2.0 - Bd / 2.0) / N)
    sizes = (400, 600) if S < 1400 else (400, 600, 600)
    hs = [0] if not step else [0, 0, step, min(2 * step, P["high"])]
    nodes = [(i, j) for i in range(-N, N + 1) for j in range(-N, N + 1)]
    base_pts = [(0, N), (0, -N)] + ([(N, 0), (-N, 0)] if sym_kind == "turn4" else [])
    dropped = {(N, N), (N, -N), (-N, N), (-N, -N)}
    nodes = [p for p in nodes if p not in dropped]
    half, height = {}, {}
    for p in nodes:
        orb = _orbit(p, sym_kind)
        rep = orb[0]
        if rep in half:
            half[p], height[p] = half[rep], height[rep]
            continue
        rr = r
        half[p] = rr.choice(sizes)
        height[p] = 0 if (p in base_pts or rep == (0, 0)) else rr.choice(hs)
        half[rep], height[rep] = half[p], height[p]
    for p in base_pts:
        half[p] = None
    cap = S - Bw // 2 - 400
    for p in nodes:
        if half[p] is None:
            continue
        if any(abs(p[0] - b[0]) + abs(p[1] - b[1]) == 1 and (p[0] - b[0] if b[1] else p[1] - b[1])
               for b in base_pts):
            half[p] = min(half[p], max(200, q(cap)))
            if half[p] < 400:
                height[p] = 0
    edges = []
    for (i, j) in nodes:
        for (di, dj) in ((1, 0), (0, 1)):
            b = (i + di, j + dj)
            if b in nodes:
                edges.append(((i, j), b))
    def okey(e):
        out = []
        for (a, b) in ((e[0], e[1]),):
            for k in range(4 if sym_kind == "turn4" else 2):
                if sym_kind == "turn4":
                    ta, tb = a, b
                    for _ in range(k):
                        ta, tb = (ta[1], -ta[0]), (tb[1], -tb[0])
                else:
                    ta, tb = (a, b) if k == 0 else ((a[0], -a[1]), (b[0], -b[1]))
                out.append(tuple(sorted((ta, tb))))
        return min(out)
    orbits = {}
    for e in edges:
        orbits.setdefault(okey(e), []).append(e)
    keep_edges = list(edges)
    drop_share = 0.25 if L.dice is None else (0.4, 0.3, 0.2, 0.1)[L.dice["crossings"]]
    for key in sorted(orbits):
        if r.random() < drop_share:
            trial = [e for e in keep_edges if e not in orbits[key]]
            if _two_edge_connected(nodes, trial):
                keep_edges = trial
    def centre_of(p):
        return p[0] * S, p[1] * S
    def rect_of_node(p):
        cx, cz = centre_of(p)
        if p in base_pts:
            if p[1] != 0:
                return (cx - Bw // 2, cx + Bw // 2, cz - Bd // 2, cz + Bd // 2)
            return (cx - Bd // 2, cx + Bd // 2, cz - Bw // 2, cz + Bw // 2)
        h = half[p]
        return (cx - h, cx + h, cz - h, cz + h)
    for p in nodes:
        if p in base_pts:
            continue
        while half[p] > 100 and any(_overlap(grow(rect_of_node(p), 200), rect_of_node(b))
                                    for b in base_pts):
            half[p] -= 100
    rects = {p: rect_of_node(p) for p in nodes}
    for p in nodes:
        for o in nodes:
            if p < o and _overlap(grow(rects[p], 200), rects[o]):
                keep_edges = [e for e in keep_edges if e != (p, o) and e != (o, p)]
    if not _two_edge_connected(nodes, keep_edges):
        keep_edges = edges[:]
    sw = q(max(400, min(800, P["Lw"])))
    for p in nodes:
        rc = rects[p]
        y = height[p]
        if p in base_pts:
            _fx, _fz = (-p[0] / float(N), -p[1] / float(N))
            tag = "base%d.floor" % base_pts.index(p)
            L.slab(rc, 0, "floor", tag, tex=L.pal["accents"][base_pts.index(p) % 4], zone="base",
                   fill=False, copy=False)
        else:
            L.slab(rc, y, "deck" if y else "floor", "island %d %d" % p,
                   zone="perch" if y else ("centre" if p == (0, 0) else "field"), copy=False)
            L.spot(int((rc[0] + rc[1]) / 2), y, int((rc[2] + rc[3]) / 2), 0, "island")
    rc = rects[(0, N)]
    L.bases.append({"id": "base0", "rect": rc, "y": 0, "facing": (0, -1), "tex": None})
    L.keep(rc)
    for (a, b) in keep_edges:
        ra, rb = rects[a], rects[b]
        ya, yb = height[a], height[b]
        horiz = a[1] == b[1]
        if horiz:
            lo_p, hi_p = (a, b) if ra[1] <= rb[0] else (b, a)
            x0, x1 = rects[lo_p][1], rects[hi_p][0]
            cz = (centre_of(a)[1])
            z0, z1 = cz - sw // 2, cz + sw // 2
            _link(L, (x0, x1, z0, z1), height[lo_p], height[hi_p], "x")
        else:
            lo_p, hi_p = (a, b) if ra[3] <= rb[2] else (b, a)
            z0, z1 = rects[lo_p][3], rects[hi_p][2]
            cx = centre_of(a)[0]
            x0, x1 = cx - sw // 2, cx + sw // 2
            _link(L, (x0, x1, z0, z1), height[lo_p], height[hi_p], "z")
        del ya, yb
    P.update({"centre": "island", "lane": "bridges", "corner": "islands", "I": S,
              "G": S, "B": Bd, "Dh": height[(0, 0)], "Ph": max(height.values() or [0])})
    L.landmark = {"x": 0, "z": 0, "y": height[(0, 0)], "around": 200,
                  "max_w": max(400, 2 * half[(0, 0)] - 400)}
    if L.landmark:
        L.keep((-300, 300, -300, 300), copy=False)
    from .skeleton import Zone
    for p in nodes:
        zid = "n%+d%+d" % p
        L.graph.add(Zone(zid, "base" if p in base_pts else "field", None, p[0] * S, p[1] * S))
    for (a, b) in keep_edges:
        L.graph.edges.add(tuple(sorted(("n%+d%+d" % a, "n%+d%+d" % b))))
    L.graph.loops.append(("lattice: %d islands, %d bridges, 2-edge-connected" % (
        len(nodes), len(keep_edges)), []))
    _settle_steeps(L)
    L.modules.update({"islands": len(nodes), "bridges": len(keep_edges), "spacing": S})
def _overlap(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]
def _steep(L, made, over):
    if over:
        L.__dict__.setdefault("_steeps", []).append([made[0], over])
def _steep_rect(p, over):
    yaw = p["yaw"] % 360
    w, d = (p["d"], p["w"]) if yaw in (90, 270) else (p["w"], p["d"])
    return (p["x"] - w / 2, p["x"] + w / 2, p["z"] - d / 2, p["z"] + d / 2)
def _settle_steeps(L):
    steeps = L.__dict__.get("_steeps") or []
    if not steeps:
        return
    from . import v1
    up = v1.arenas_module().QUARTER_UP
    item_cut = {id(p): 0 for p, _ in steeps}
    others = [q for q in L.structure if q.get("kind") in ("ramp", "stairs")
              and all(q is not p for p, _ in steeps)]
    def hits(r):
        for sp in L.spots:
            for sx in (1, -1):
                for sz in (1, -1):
                    if (r[0] - 100 < sx * sp["x"] < r[1] + 100
                            and r[2] - 100 < sz * sp["z"] < r[3] + 100):
                        return True
        for q in others:
            if _rects_overlap(r, _steep_rect(q, 0)):
                return True
        return False
    while True:
        pulled = set()
        for i, it in enumerate(steeps):
            if it[1] - item_cut[id(it[0])] <= 0:
                continue
            ext = _extension(it[0], it[1], item_cut[id(it[0])], up)
            if hits(ext):
                pulled.add(i)
            for j in range(i + 1, len(steeps)):
                jt = steeps[j]
                if jt[1] - item_cut[id(jt[0])] > 0 and _rects_overlap(
                        ext, _extension(jt[0], jt[1], item_cut[id(jt[0])], up)):
                    pulled.update((i, j))
        if not pulled:
            break
        for i in pulled:
            item_cut[id(steeps[i][0])] += 100
    for p, over in steeps:
        cut = item_cut[id(p)]
        if cut:
            ux, uz = up[p["yaw"] % 360]
            p["d"] -= cut
            p["x"] += ux * cut / 2.0
            p["z"] += uz * cut / 2.0
def _extension(p, over, cut, up):
    x0, x1, z0, z1 = _steep_rect(p, 0)
    ux, uz = up[p["yaw"] % 360]
    if ux > 0:
        return (x0 + cut, x0 + over, z0, z1)
    if ux < 0:
        return (x1 - over, x1 - cut, z0, z1)
    if uz > 0:
        return (x0, x1, z0 + cut, z0 + over)
    return (x0, x1, z1 - over, z1 - cut)
def _rects_overlap(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]
STEEP_OVER = 400
def _link(L, rect, ylo_side, yhi_side, axis):
    x0, x1, z0, z1 = rect
    length = (x1 - x0) if axis == "x" else (z1 - z0)
    if length <= 0:
        return
    a, b = ylo_side, yhi_side
    if a == b:
        bridge(L, rect, a, "bridge", copy=False)
    else:
        lo, hi = min(a, b), max(a, b)
        run = 2 * (hi - lo)
        over = 0
        if run > length:
            run = length
            over = min(max(0, (hi - lo) - length), STEEP_OVER)
        flat = length - run
        if axis == "x":
            if a < b:
                if flat:
                    bridge(L, (x0, x0 + flat, z0, z1), lo, "bridge", copy=False)
                _steep(L, ramp(L, x0 + flat - over, x1, lo, hi, z0, z1, "+x", "bridge ramp", copy=False), over)
            else:
                _steep(L, ramp(L, x0, x0 + run + over, lo, hi, z0, z1, "-x", "bridge ramp", copy=False), over)
                if flat:
                    bridge(L, (x0 + run, x1, z0, z1), lo, "bridge", copy=False)
        else:
            if a < b:
                if flat:
                    bridge(L, (x0, x1, z0, z0 + flat), lo, "bridge", copy=False)
                _steep(L, ramp(L, x0, x1, lo, hi, z0 + flat - over, z1, "+z", "bridge ramp", copy=False), over)
            else:
                _steep(L, ramp(L, x0, x1, lo, hi, z0, z0 + run + over, "-z", "bridge ramp", copy=False), over)
                if flat:
                    bridge(L, (x0, x1, z0 + run, z1), lo, "bridge", copy=False)
    L.keep((x0 - 100, x1 + 100, z0 - 100, z1 + 100), copy=False)
    if axis == "x":
        L.opening((x0 - 200, x0 + 200, z0, z1), copy=False)
        L.opening((x1 - 200, x1 + 200, z0, z1), copy=False)
    else:
        L.opening((x0, x1, z0 - 200, z0 + 200), copy=False)
        L.opening((x0, x1, z1 - 200, z1 + 200), copy=False)
def build_courtyard(L, P, r):
    A = P["across"]
    Bw, Bd = base_size(4, A)
    Bw = max(Bw, 2000)
    tw = 600
    Hw = 600 if (P["step"] or 0) >= 400 else 400
    run = 2 * Hw
    R = q(A / 2.0 - Bd - tw)
    gw = q(max(800, min(1200, A * 0.12)))
    Ck = q(max(600, min(R * r.choice((0.25, 0.3)) * centre_scale(L), R - 1200)))
    Dh = 400 if Hw >= 600 else 300
    foot = 0 if L.solid else -200
    P.update({"centre": "keep", "lane": "gates + ramparts", "corner": "rampart",
              "I": R, "G": tw, "B": Bd, "Dh": Dh, "Ph": Hw})
    L.slab((-R, R, -R, R), 0, "floor", "courtyard", zone="field", copy=False)
    for (x0, x1) in ((-R - tw, -gw // 2), (gw // 2, R)):
        L.box("wall", x0, x1, foot, Hw, R, R + tw, "rampart")
        L.floor((x0, x1, R, R + tw), Hw, "perch", fill=False)
    L.box("bridge", -gw // 2, gw // 2, Hw - 100, Hw, R, R + tw, "gate deck")
    L.floor((-gw // 2, gw // 2, R, R + tw), Hw, "lane", fill=False)
    L.slab((-gw // 2, gw // 2, R, R + tw), 0, "floor", "gate", zone="lane", fill=False)
    L.keep((-gw // 2 - 200, gw // 2 + 200, R - 600, R + tw + 200))
    L.opening((-gw // 2, gw // 2, R - 100, R + tw + 100))
    if R - run > Ck + 600 and R - run > gw // 2 + 400:
        ramp(L, R - 500, R, 0, Hw, R - run, R, "+z", "rampart ramp")
        L.keep((R - 700, R, R - run - 400, R))
        L.opening((R - 600, R, R - 100, R + 100))
    zb = R + tw
    L.slab((-Bw // 2, Bw // 2, zb, zb + Bd), 0, "floor", "base0.floor", tex=L.pal["accents"][0],
           zone="base", fill=False)
    L.base("base0", (-Bw // 2, Bw // 2, zb, zb + Bd), 0, (0, -1))
    ox0 = Bw // 2
    if ox0 + run <= R + tw:
        for sx in (-1, 1):
            a, b = sorted((sx * ox0, sx * (ox0 + run)))
            ramp(L, a, b, 0, Hw, zb, zb + 500, "+x" if sx > 0 else "-x", "outer ramp")
            L.keep((a - 200, b + 200, zb, zb + 700))
            L.opening((a, b, R, zb + 600))
    tower_h = Hw + 200
    L.box("wall", R, R + tw, foot, tower_h, R, R + tw, "corner tower")
    L.floor((R, R + tw, R, R + tw), tower_h, "perch", fill=False)
    L.spot(R + tw // 2, tower_h, R + tw // 2, 0, "corner tower")
    L.box("wall", -Ck, Ck, foot, Dh, -Ck, Ck, "keep", copy=False)
    L.floor((-Ck, Ck, -Ck, Ck), Dh, "centre", fill=False, copy=False)
    kr = 2 * Dh
    ramp(L, -300, 300, 0, Dh, Ck, Ck + kr, "-z", "keep ramp")
    L.keep((-500, 500, Ck - 200, Ck + kr + 400))
    L.keep((-Ck - 200, Ck + 200, -Ck - 200, Ck + 200), copy=False)
    L.landmark = {"x": 0, "z": 0, "y": Dh, "around": Hw, "max_w": max(400, Ck - 200)}
    loops(L, 4, [(["base{u}", "gate{u}", "court{u}", "wallE{u}"], "gate and inner ramp {u}"),
                 (["base{u}", "wallW{u}", "gatedeck{u}", "wallE{u}"], "outer ramps {u}"),
                 (["wallE{u}", "tower{u}", "wallW{n}", "gatedeck{n}", "wallE{n}", "court{n}",
                   "court{u}"], "wall walk {u}"),
                 (["court{u}", "keepramp{u}", "keep", "keepramp{n}", "court{n}"], "keep {u}")])
    L.modules.update({"centre": "keep", "wall": Hw, "gate": gw})
def build_canyon(L, P, r):
    A = P["across"]
    H = q(A / 2.0)
    Wx = q(A * 0.4)
    Yr = max(400, P["step"] or 400)
    if P["high"] >= 1000 and r.random() < 0.5:
        Yr = 600
    cw = q(max(1200, min(2000, A * 0.2)))
    Bw, Bd = base_size(2, A)
    Bw = q(min(2 * Wx - 800, max(Bw, cw + 1200)))
    two_rows = Bw < 8 * 450 - 450 + 600
    if two_rows:
        Bd = 1900
    gap = max(600, 2 * Yr)
    zc = H - Bd - gap
    segs = 2 if zc < 3000 else 3
    bounds = [0] + [q(zc * (k + 1) / float(segs)) for k in range(segs)]
    jog = q(min(cw * 0.45, max(0, Wx - cw // 2 - 1000)))
    offsets = [(r.choice((-jog, jog)) if k % 2 == 0 else 0) for k in range(segs - 1)] + [0]
    P.update({"centre": "canyon crossing", "lane": "canyon + rims", "corner": "rim",
              "I": Wx, "G": zc, "B": Bd, "Dh": 0, "Ph": Yr})
    foot = 0 if L.solid else -200
    for k in range(segs):
        z0, z1 = bounds[k], bounds[k + 1]
        xc = offsets[k]
        a, b = xc - cw // 2, xc + cw // 2
        L.slab((a, b, z0, z1), 0, "floor", "canyon floor", zone="field")
        L.box("wall", -Wx, a, foot, Yr, z0, z1, "rim")
        L.floor((-Wx, a, z0, z1), Yr, "perch")
        L.box("wall", b, Wx, foot, Yr, z0, z1, "rim")
        L.floor((b, Wx, z0, z1), Yr, "perch")
    zb = zc + gap
    L.slab((-Bw // 2, Bw // 2, zb, zb + Bd), Yr, "floor", "base0.floor",
           tex=L.pal["accents"][0], zone="base", fill=False, thick=300)
    L.base("base0", (-Bw // 2, Bw // 2, zb, zb + Bd), Yr, (0, -1))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (Bw // 2 - 500), sx * (Bw // 2 - 100)))
        bridge(L, (x0, x1, zc, zb), Yr, "rim bridge")
        L.keep((x0 - 100, x1 + 100, zc - 400, zb + 100))
        L.opening((x0 - 100, x1 + 100, zc - 100, zb + 100))
    ramp(L, -300, 300, 0, Yr, zc, zb, "+z", "canyon ramp")
    L.keep((-500, 500, zc - 400, zb + 100))
    L.opening((-400, 400, zc - 100, zb + 100))
    run = 2 * Yr
    xc = offsets[0]
    zr0 = bounds[1] - 200 - run
    if zr0 > 600:
        for sx in (-1, 1):
            edge = xc + sx * (cw // 2)
            x0, x1 = sorted((edge, edge - sx * 500))
            ramp(L, x0, x1, 0, Yr, zr0, zr0 + run, "-z", "rim ramp")
            L.keep((x0 - 200, x1 + 200, zr0 - 400, zr0 + run + 200))
            L.opening((min(x0, x1) - 100, max(x0, x1) + 100, zr0 - 200, zr0 + 200))
    if segs > 2:
        xk = offsets[1]
        zr1 = bounds[2] - 200 - run
        if zr1 > bounds[1] + 400:
            for sx in (-1, 1):
                edge = xk + sx * (cw // 2)
                x0, x1 = sorted((edge, edge - sx * 500))
                ramp(L, x0, x1, 0, Yr, zr1, zr1 + run, "-z", "rim ramp")
                L.keep((x0 - 200, x1 + 200, zr1 - 400, zr1 + run + 200))
    a, b = offsets[0] - cw // 2, offsets[0] + cw // 2
    L.box("bridge", a, b, Yr - 100, Yr, 0, 600, "canyon bridge")
    L.floor((a, b, 0, 600), Yr, "lane", fill=False)
    L.opening((a - 200, b + 200, 0, 600))
    L.keep((a - 100, b + 100, 0, 800))
    L.spot(-Wx + 400, Yr, q(zc * 0.5), 0, "rim")
    L.landmark = {"x": -Wx + 400, "z": 0, "y": Yr, "around": Yr, "max_w": 600}
    L.keep((-Wx, -Wx + 800, -400, 400), copy=False)
    loops(L, 2, [(["base{u}", "canyon{u}", "rimL{u}"], "left climb {u}"),
                 (["base{u}", "canyon{u}", "rimR{u}"], "right climb {u}"),
                 (["canyon{u}", "rimL{u}", "bridge", "rimR{u}"], "crossing {u}"),
                 (["canyon{u}", "canyon{n}", "rimL{n}", "rimL{u}"], "the long way {u}")])
    L.modules.update({"centre": "crossing", "segments": segs, "rim": Yr, "jog": jog})
def _corner(L, x0, x1, y0, y1, z0, z1, high, tag, role="ramp", copy=True):
    from . import kit
    p = kit.kind("outer").make(L.pal[role], x0, x1, y0, y1, z0, z1, high, tag)
    return L._add(p, copy, L.structure)
def build_knoll(L, P, r):
    A = P["across"]
    Bw, Bd = base_size(4, A)
    H = q(A / 2.0 - 0.75 * Bd - 300)
    Hh = 600 if (P["step"] or 300) >= 400 and r.random() < 0.6 else 400
    run = 2 * Hh
    rr = q(max(600, min(1200, H * r.choice((0.16, 0.2, 0.24)))))
    if rr + run > H - 1400:
        rr = max(600, q(H - 1400 - run))
    if rr + run > H - 1000:
        Hh, run = 400, 800
        rr = max(400, q(min(rr, H - 1000 - run)))
    R = rr + run
    P.update({"centre": "knoll", "lane": "slopes", "corner": "hips", "I": rr, "G": H - R,
              "B": Bd, "Dh": Hh, "Ph": 0})
    L.box("floor", -R, H, -200, 0, R, H, "field")
    L.floor((-R, H, R, H), 0, "field")
    L.box("floor", -R, R, -200, 0, -R, R, "knoll ground", copy=False)
    L.box("deck", -rr, rr, 0, Hh, -rr, rr, "knoll summit", copy=False)
    L.floor((-rr, rr, -rr, rr), Hh, "centre", fill=False, copy=False)
    ramp(L, -rr, rr, 0, Hh, rr, R, "-z", "knoll slope")
    _corner(L, rr, R, 0, Hh, rr, R, "-x-z", "knoll hip")
    L.keep((-R - 200, R + 200, rr - 200, R + 200))
    L.opening((-rr, rr, rr - 100, rr + 100))
    if rr >= 800:
        L.box("cover", -200, 200, Hh, Hh + 400, rr - 400, rr - 200, "knoll cover")
    L.spot(q(H * 0.62), 0, q(H * 0.62), 0, "field corner")
    L.spot(0, Hh, q(rr * 0.5), 0, "summit")
    gap_base(L, max(Bw, 2400), Bd, H, gap=400)
    L.landmark = {"x": 0, "z": 0, "y": Hh, "around": Hh, "max_w": max(400, rr - 400)}
    L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 4, [(["base{u}", "field{u}", "field{n}", "base{n}"], "rim {u}"),
                 (["field{u}", "slope{u}", "slope{n}", "field{n}"], "round {u}"),
                 (["slope{u}", "summit", "slope{n}"], "summit {u}")])
    L.modules.update({"centre": "knoll", "hill": Hh, "summit": rr})
def build_ridge(L, P, r):
    A = P["across"]
    H = q(A / 2.0)
    Wx = q(A * 0.42)
    Bw, Bd = base_size(2, A)
    Bw = q(min(Bw, 2 * Wx - 1200))
    zf = H - Bd - 400
    Hh = 600 if (P["step"] or 300) >= 400 and r.random() < 0.5 else 400
    run = 2 * Hh
    w = r.choice((400, 600))
    L1 = q(Wx * r.choice((0.4, 0.5)))
    if Wx - (L1 + run) < 1400:
        L1 = max(800, q(Wx - run - 1400))
    if w + run > zf - 1400:
        Hh, run, w = 400, 800, 400
    a = q(max(400, min(800, L1 // 3)))
    P.update({"centre": "ridge", "lane": "flanks round the ridge", "corner": "-",
              "I": Wx, "G": zf, "B": Bd, "Dh": Hh + 200, "Ph": Hh})
    L.slab((-Wx, Wx, 0, zf), 0, "floor", "field", zone="field")
    L.box("deck", -L1, L1, 0, Hh, -w, w, "ridge spine", copy=False)
    L.floor((-L1, L1, -w, w), Hh, "centre", fill=False, copy=False)
    L.box("deck", -a, a, Hh, Hh + 200, -w, w, "ridge knob", tex=L.pal["accents"][-1],
          copy=False)
    L.floor((-a, a, -w, w), Hh + 200, "centre", fill=False, copy=False)
    ramp(L, -L1, L1, 0, Hh, w, w + run, "-z", "ridge face")
    ramp(L, L1, L1 + run, 0, Hh, 0, w, "-x", "ridge end")
    ramp(L, -L1 - run, -L1, 0, Hh, 0, w, "+x", "ridge end")
    for sz in (1, -1):
        z0, z1 = sorted((sz * w, sz * (w + run)))
        _corner(L, L1, L1 + run, 0, Hh, z0, z1, "-x-z" if sz > 0 else "-x+z", "ridge hip",
                copy=False)
        _corner(L, -L1 - run, -L1, 0, Hh, z0, z1, "+x-z" if sz > 0 else "+x+z", "ridge hip",
                copy=False)
    L.keep((-L1 - run - 200, L1 + run + 200, w - 200, w + run + 200))
    L.keep((-L1 - run - 200, L1 + run + 200, -w - run - 200, -w + 200), copy=False)
    L.opening((-L1, L1, w - 100, w + 100))
    fx = q((L1 + run + Wx) / 2.0)
    for sx in (-1, 1):
        L.box("cover", sx * fx - 300, sx * fx + 300, 0, 450, 600, 800, "flank cover")
        L.spot(sx * fx, 0, q(zf * 0.5), 0, "flank")
    L.spot(0, Hh, w + 200, 0, "ridge")
    L.base("base0", (-Bw // 2, Bw // 2, zf + 400, zf + 400 + Bd), 0, (0, -1))
    L.slab((-Bw // 2, Bw // 2, zf + 400, zf + 400 + Bd), 0, "floor", "base0.floor",
           tex=L.pal["accents"][0], zone="base", fill=False)
    for xc in (-Bw // 2 + 300, 0, Bw // 2 - 300):
        bridge(L, (xc - 200, xc + 200, zf, zf + 400), 0, "base link")
        L.keep((xc - 300, xc + 300, zf - 100, zf + 500))
        L.opening((xc - 200, xc + 200, zf - 100, zf + 500))
    L.landmark = {"x": 0, "z": 0, "y": Hh + 200, "around": 200, "max_w": max(400, a - 200)}
    L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 2, [(["base{u}", "field{u}", "flankL", "field{n}", "flankR"], "round {u}"),
                 (["field{u}", "face{u}", "spine", "face{n}", "field{n}", "flankL"],
                  "over {u}"),
                 (["base{u}", "flankL", "field{u}"], "left {u}")])
    L.modules.update({"centre": "ridge", "hill": Hh + 200, "spine": 2 * L1})
def build_mesa(L, P, r):
    A = P["across"]
    H = q(A / 2.0)
    Wx = q(A * 0.42)
    Bw, Bd = base_size(2, A)
    Bw = q(min(Bw, 2 * Wx - 1200))
    zf = H - Bd - 400
    Hh = r.choice((600, 800)) if (P["step"] or 300) >= 400 else 600
    run = 2 * Hh
    a = q(max(800, min(1600, Wx * 0.28)))
    if Wx - (a + run) < 1200:
        a = max(600, q(Wx - run - 1200))
    b = q(max(800, min(1400, zf * 0.3)))
    rw = q(min(b, 600))
    P.update({"centre": "mesa", "lane": "flank ramps", "corner": "-", "I": a, "G": zf,
              "B": Bd, "Dh": Hh, "Ph": Hh})
    L.slab((-Wx, Wx, 0, zf), 0, "floor", "field", zone="field")
    L.box("deck", -a, a, 0, Hh, -b, b, "mesa", copy=False)
    L.floor((-a, a, -b, b), Hh, "centre", fill=False, copy=False)
    ramp(L, a, a + run, 0, Hh, 0, rw, "-x", "mesa ramp")
    ramp(L, -a - run, -a, 0, Hh, 0, rw, "+x", "mesa ramp")
    L.keep((a - 200, a + run + 200, -rw - 200, rw + 200), copy=False)
    L.keep((-a - run - 200, -a + 200, -rw - 200, rw + 200), copy=False)
    L.opening((a - 100, a + 100, -rw, rw), copy=False)
    L.opening((-a - 100, -a + 100, -rw, rw), copy=False)
    L.box("cover", -q(a / 2.0), q(a / 2.0), Hh, Hh + 400, b - 400, b - 200, "mesa cover")
    L.box("cover", -400, 400, 0, 450, b + 600, b + 800, "field cover")
    for sx in (-1, 1):
        L.spot(sx * q((a + run + Wx) / 2.0), 0, q(zf * 0.4), 0, "flank")
    L.spot(0, Hh, 0, 0, "mesa top")
    L.base("base0", (-Bw // 2, Bw // 2, zf + 400, zf + 400 + Bd), 0, (0, -1))
    L.slab((-Bw // 2, Bw // 2, zf + 400, zf + 400 + Bd), 0, "floor", "base0.floor",
           tex=L.pal["accents"][0], zone="base", fill=False)
    for xc in (-Bw // 2 + 300, 0, Bw // 2 - 300):
        bridge(L, (xc - 200, xc + 200, zf, zf + 400), 0, "base link")
        L.keep((xc - 300, xc + 300, zf - 100, zf + 500))
        L.opening((xc - 200, xc + 200, zf - 100, zf + 500))
    L.landmark = {"x": 0, "z": 0, "y": Hh, "around": Hh, "max_w": max(400, a - 400)}
    L.keep((-400, 400, -400, 400), copy=False)
    loops(L, 2, [(["base{u}", "field{u}", "flankL", "field{n}", "flankR"], "round {u}"),
                 (["flankL", "rampL", "top", "rampR", "flankR", "field{u}"], "up {u}"),
                 (["base{u}", "flankL", "field{u}"], "left {u}")])
    L.modules.update({"centre": "mesa", "hill": Hh})
BUILDERS = {"three_lane": build_three_lane, "ring": build_ring, "hub": build_hub,
            "twin": build_twin, "terraces": build_terraces, "courtyard": build_courtyard,
            "canyon": build_canyon, "knoll": build_knoll, "ridge": build_ridge,
            "mesa": build_mesa}
def build(name, sym_kind, brief, streams, dice, pal, across, family="shooter"):
    if name == "rooms":
        from . import rooms
        L = Layout(brief, streams, dice, Sym("none"), pal, family)
        r = streams("skeleton." + name)
        L.params = common_params(L, name, across, r)
        rooms.build_skeleton(L, L.params, r)
        rooms.budget_for(L, brief)
        L.modules["skeleton"] = name
        return L
    L = Layout(brief, streams, dice, Sym(sym_kind), pal, family)
    r = streams("skeleton." + name)
    L.params = common_params(L, name, across, r)
    if name == "archipelago":
        build_archipelago(L, L.params, r, sym_kind)
    else:
        BUILDERS[name](L, L.params, r)
    L.modules["skeleton"] = name
    return L
