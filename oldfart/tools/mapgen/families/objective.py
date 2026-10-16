import math
from .. import anchors as anchormod, boundary, kit, v1
from ..skeleton import Graph, Zone, compass_of
FAMILY = "objective"
DEFAULTS = {"symmetry": "mirror", "sides": "2", "verticality": "medium",
            "density": "medium", "edge": "walled", "level": "empty", "theme": "desert"}
MODES = ("domination", "ctf", "oneflag", "koth")
TEAM_TEX = {"red": "carpet", "blue": "glassblock"}
LONGEST = 6200
WALL_TALL = 1200
POINT_RING = 500
def q(v, step=100):
    return int(round(v / float(step))) * step
def weighted(r, choices):
    total = sum(w for _, w in choices)
    x = r.random() * total
    for name, w in choices:
        x -= w
        if x < 0:
            return name
    return choices[-1][0]
def split_long(piece, longest=LONGEST):
    if piece["kind"] != "box":
        return [piece]
    out = [piece]
    turned = piece.get("yaw", 0) % 180 == 90
    for dim, axis in (("w", "z" if turned else "x"), ("d", "x" if turned else "z")):
        nxt = []
        for p in out:
            n = int(math.ceil(p[dim] / float(longest)))
            if n <= 1:
                nxt.append(p)
                continue
            lo = p[axis] - p[dim] / 2.0
            if lo % 100 == 0:
                cuts = [lo] + [round((lo + p[dim] * i / float(n)) / 100.0) * 100
                               for i in range(1, n)] + [lo + p[dim]]
            else:
                cuts = [lo] + [lo + round(p[dim] * i / float(n) / 100.0) * 100
                               for i in range(1, n)] + [lo + p[dim]]
            for a, b in zip(cuts, cuts[1:]):
                part = dict(p)
                part[dim] = b - a
                part[axis] = (a + b) / 2.0
                nxt.append(part)
        out = nxt
    return out
def palette(theme, override=None):
    try:
        from .. import beauty
        return beauty.palette(theme, override)
    except (ImportError, AttributeError):
        return kit.palette(theme, override)
def capped(piece):
    tex = piece.get("tex")
    if piece["kind"] != "box" or not kit.layered(tex) or piece["h"] <= kit.TRANSITION_MAX:
        return [piece]
    top = piece["y"] + piece["h"]
    base = dict(piece, h=piece["h"] - kit.TRANSITION_MAX,
                tex=kit.TRANSITION_BASE.get(tex, "stone2"))
    return [base, dict(piece, y=top - kit.TRANSITION_MAX, h=kit.TRANSITION_MAX)]
def standing(arena, spot):
    m = v1.arenas_module()
    hs = m.standable(arena["pieces"], spot["x"], spot["z"], arena["level"])
    return any(abs(h - spot["y"]) <= 1 for h in hs)
def finish(arena, lift):
    m = v1.arenas_module()
    out = []
    for p in arena["pieces"]:
        out += [c for part in split_long(p) for c in capped(part)]
    arena["pieces"] = out
    for p in arena["pieces"]:
        if lift:
            p["y"] += lift
        p["model"] = m.model_name(p)
    if lift:
        for s in arena["spawns"]:
            s["y"] += lift
        for key, val in arena["survey"].items():
            for s in (val if isinstance(val, list) else [val]):
                s["y"] += lift
    return arena
def rotate_all(arena, quarters):
    m = v1.arenas_module()
    if not quarters % 4:
        return
    arena["pieces"] = [m.turned(p, quarters) for p in arena["pieces"]]
    arena["spawns"] = [m.turned_point(s, quarters) for s in arena["spawns"]]
    for key, val in list(arena["survey"].items()):
        if isinstance(val, list):
            arena["survey"][key] = [m.turned_point(s, quarters) for s in val]
        else:
            arena["survey"][key] = m.turned_point(val, quarters)
def shift_all(arena, dx, dz):
    for p in arena["pieces"]:
        p["x"] += dx
        p["z"] += dz
    for s in arena["spawns"]:
        s["x"] += dx
        s["z"] += dz
    for val in arena["survey"].values():
        for s in (val if isinstance(val, list) else [val]):
            s["x"] += dx
            s["z"] += dz
def quarters_for(home, want):
    order = ("s", "e", "n", "w")
    return (order.index(want) - order.index(home)) % 4
def axis_compass(c):
    return {"n": "n", "s": "s", "e": "e", "w": "w", "ne": "n", "nw": "n",
            "se": "s", "sw": "s"}.get(c)
def flag_time(players):
    return 7.0 + 0.25 * players
def draw_params(brief, streams, notes, anchors):
    from ..brief import SIZES, PACES
    want, avoid = set(brief["features"]["want"]), set(brief["features"]["avoid"])
    r = streams("frame")
    P = {}
    size = brief["size"]
    factor = SIZES[size] if isinstance(size, str) else 1.0
    pace = PACES[brief["pace"]]
    P["T"] = round(flag_time(brief["players"]) * factor * pace + r.uniform(-0.6, 0.6), 2)
    modes = set(brief["modes"])
    P["points_only"] = bool(modes) and not (modes & {"ctf", "oneflag"})
    if P["points_only"]:
        P["T"] = round(6.5 * factor * pace, 2)
    if isinstance(size, dict):
        if "across_s" in size:
            P["T"] = float(size["across_s"])
        elif "across" in size:
            P["T"] = (float(size["across"]) - 1400) / 960.0 + 0.6
    if P["T"] > 20.0:
        notes.append("flag to flag %.1f s held to 20 s: a run longer than that is no game "
                     "(GEN2 size tiers; the corner forts grow instead)" % P["T"])
        P["T"] = 20.0
    W = 3000 * (0.75 + 0.25 * brief["players"] / 16.0) * factor
    W = q(W * r.choice((0.88, 0.94, 1.0, 1.06, 1.12)), 100)
    P["W"] = max(2400, min(4200, W))
    from .. import modeknow
    P["point_gap"] = modeknow.spawn_needs("domination").get("point_gap_min", 0) \
        if "domination" in modes else 0
    if P["point_gap"]:
        P["W"] = max(P["W"], min(4200, P["point_gap"] + 700))
    vert = brief["verticality"]
    th_medium = r.choice((400, 400, 600))
    P["Th"] = {"flat": 0, "low": 200, "high": 600,
               "medium": 400 if P["points_only"] else th_medium}[vert]
    u = streams("centre")
    P["Hh"] = {"flat": 0, "low": 400, "medium": u.choice((400, 500, 500, 600)),
               "high": 600}[vert]
    if P["points_only"] and vert == "medium":
        P["Hh"] = 400
    hill = anchors.get("hill")
    if hill is not None and isinstance(hill.get("height"), (int, float)) and vert != "flat":
        h = int(hill["height"])
        P["Hh"] = max(400, min(600, q(h, 50)))
        if h != P["Hh"]:
            notes.append("hill height %d: built at %d (a hill stands 400-600 up so its points "
                         "count as the main storey, of_gm_domination STOREY 700)" % (h, P["Hh"]))
    P["deck"] = u.choice((1400, 1400, 1600)) if P["Hh"] else 1400
    foot = P["deck"] // 2 + 2 * P["Hh"] if P["Hh"] else 0
    if foot and P["W"] - 700 < foot + 200:
        P["W"] = min(4200, q(foot + 200 + 700, 100))
    P["hill_ramp"] = u.choice((600, 800))
    P["hill_style"] = u.choice(("cross", "side"))
    P["hill_kind"] = "stairs" if ("stairs" in want and P["Hh"] <= 280) else "ramp"
    s = streams("lanes")
    P["high_side"] = s.choice((-1, 1))
    P["Gw"] = s.choice((600, 800, 800))
    P["road_h"] = weighted(s, [(600, 3), (400, 1), (800, 1)])
    P["Xw"] = max(900, min(q(P["W"] / 2.7, 100), P["W"] - P["Gw"] - 800, P["W"] - 1300))
    P["mid"] = weighted(s, [("bend", 2), ("s_bend", 2), ("pillars", 1)])
    P["low"] = weighted(s, [("walls", 3), ("crates", 1)])
    P["lane_shift"] = s.choice((0, 0, 200))
    if P["Th"] == 0:
        P["high"] = "low_walk"
    else:
        P["high"] = "gallery"
    dens = {"sparse": 5, "medium": 9, "dense": 13}[brief["density"]]
    if "cover_walls" in want or "long_lines" in avoid:
        dens += 3
    P["cover"] = dens
    edge = brief["edge"]
    if edge == "auto":
        edge = "walled"
    if brief["level"] == "empty" and edge != "walled":
        notes.append("edge %s: The Tiles' floor runs on past the fort, so it is walled" % edge)
        edge = "walled"
    if "rails" in want and brief["level"] == "empty2":
        edge = "rails"
    P["edge"] = edge
    islands = brief["level"] == "empty2" and ("void_gaps" in want or "bridge" in want
                                               or anchors.get("bridge") is not None)
    if "void_gaps" in avoid or "bridge" in avoid:
        islands = False
    P["islands"] = islands
    P["side_colours"] = "side_colours" not in avoid
    return P
def layout_z(P, notes):
    Hh, Th = P["Hh"], P["Th"]
    D = P["deck"] // 2
    Z = {}
    Z["foot"] = D + 2 * Hh if Hh else 0
    Z["zfoot"] = (D + P["hill_ramp"] if P["hill_style"] == "side" else Z["foot"]) if Hh else 0
    Z["m"] = max(1400, Z["zfoot"] + 500)
    Z["gap"] = 600 if P["islands"] else 0
    Z["l0"] = Z["m"] + Z["gap"]
    lane_min = max(1200, 2 * Th + 600) if P["points_only"] else max(1600, 2 * Th + 1200)
    want_f = ((P["T"] - 0.6) * 960.0 - 600) / 2.0
    Z["f"] = q(max(want_f, Z["l0"] + lane_min + 1000), 100)
    if Z["f"] > want_f + 150 and not P["points_only"]:
        notes.append("flag to flag: planned %.1f s, the hill and the lanes need %.1f s"
                     % (P["T"], (2 * Z["f"] + 600) / 960.0 + 0.6))
    Z["t0"] = Z["f"] - 1000
    Z["s"] = Z["t0"] + 600
    Z["t1"] = Z["f"] + 500
    Z["end"] = Z["t1"] + 200
    return Z
class Kit:
    def __init__(self, pal, team, P):
        self.pal = pal
        self.team = team
        self.P = P
        self.m = v1.arenas_module()
    def box(self, role, x0, x1, y0, y1, z0, z1, tag, tex=None):
        return self.m.box(tex or self.pal[role], x0, x1, y0, y1, z0, z1, tag)
    def ramp(self, role, x0, x1, z0, z1, y0, y1, rises, tag, kind="ramp"):
        p = self.m.ramp(self.pal[role], x0, x1, z0, z1, y0, y1, rises, tag)
        if kind == "stairs":
            p["kind"] = "stairs"
        return p
def terrace(k, P, Z, team, uid):
    W, Th = P["W"], P["Th"]
    out, keep = [], []
    rug = TEAM_TEX[team] if P["side_colours"] else k.pal["deck"]
    top = Th
    if Th:
        out.append(k.box("wall", -W, W, 0, Th, Z["t0"], Z["t1"], uid + ".terrace"))
    out.append(k.box(None, -W, W, top, top + 20, Z["t0"] + 300, Z["t1"], uid + ".rug", tex=rug))
    pad = k.box(None, -300, 300, top, top + 40, Z["f"] - 300, Z["f"] + 300,
                uid + ".flag pad", tex=k.pal["trim"])
    out.append(pad)
    flag = {"x": 0, "y": top + 40, "z": Z["f"], "yaw": 180}
    step = (2 * W - 800) / 7.0
    xs = [q((i - 3.5) * step, 25) for i in range(8)]
    spawns = [{"x": x, "y": top + 20, "z": Z["s"], "yaw": 180} for x in xs]
    for c in (-3, -1, 1, 3):
        cx = c * step
        half = (step + 300) / 2.0
        out.append(k.box("wall", q(cx - half, 50), q(cx + half, 50), top, top + 400,
                         Z["s"] - 500, Z["s"] - 300, uid + ".shield"))
    if Th:
        kind = "stairs" if P["hill_kind"] == "stairs" and Th <= 280 else "ramp"
        out.append(k.ramp("ramp", -400, 400, Z["t0"] - 2 * Th, Z["t0"], 0, Th, "+z",
                          uid + ".centre ramp", kind=kind))
        lx = low_lane_x(P)
        out.append(k.ramp("ramp", lx - 400, lx + 400, Z["t0"] - 2 * Th, Z["t0"], 0, Th, "+z",
                          uid + ".low ramp", kind=kind))
        keep += [(-500, 500, Z["t0"] - 2 * Th - 300, Z["t0"]),
                 (lx - 500, lx + 500, Z["t0"] - 2 * Th - 300, Z["t0"])]
    return out, spawns, flag, keep
def low_lane_x(P):
    s = -P["high_side"]
    a, b = P["Xw"] + 200, P["W"]
    return s * q((a + b) / 2.0, 100)
def lanes(k, P, Z, r, uid):
    W, Th, Xw, Gw = P["W"], P["Th"], P["Xw"], P["Gw"]
    hs = P["high_side"]
    out, keep, spots = [], [], []
    l0, t0 = Z["l0"], Z["t0"]
    for side in (-1, 1):
        x0, x1 = sorted((side * Xw, side * (Xw + 200)))
        gz = q(l0 + (t0 - l0) * (0.45 if side == hs else 0.6), 100)
        if side == -hs and Th:
            gz = min(gz, t0 - 2 * Th - 700)
        gz = max(gz, l0 + 400)
        out.append(k.box("wall", x0, x1, 0, P["road_h"], l0, gz - 300, uid + ".road wall"))
        end = t0 - 2 * Th - 400 if Th else t0 - 400
        if gz + 300 + 400 <= end:
            out.append(k.box("wall", x0, x1, 0, P["road_h"], gz + 300, end, uid + ".road wall"))
        keep.append((x0 - 400, x1 + 400, gz - 400, gz + 400))
    if P["high"] == "gallery":
        gx0, gx1 = sorted((hs * (W - Gw), hs * W))
        g0 = l0 + 2 * Th
        out.append(k.box("wall", gx0, gx1, 0, Th, g0, t0, uid + ".gallery"))
        out.append(k.ramp("ramp", gx0, gx1, l0, g0, 0, Th, "+z", uid + ".gallery ramp"))
        px0, px1 = (gx0, gx0 + 100) if hs > 0 else (gx1 - 100, gx1)
        if t0 - 400 - (g0 + 300) >= 800:
            out.append(k.box("wall", px0, px1, Th, Th + 200, g0 + 300, t0 - 400,
                             uid + ".gallery parapet"))
        spots.append({"x": hs * (W - Gw // 2), "y": Th, "z": q((g0 + t0) / 2.0), "yaw": 180})
        keep.append((min(gx0, gx1) - 300, max(gx0, gx1) + 300, l0 - 300, t0))
    zb = q((l0 + t0 - 2 * Th) / 2.0 + P["lane_shift"], 100)
    if P["mid"] == "bend":
        out.append(k.box("cover", -500, 500, 0, 400, zb - 150, zb + 150, uid + ".bend"))
    elif P["mid"] == "s_bend":
        d = min(500, max(300, (t0 - 2 * Th - l0 - 600) // 4))
        out.append(k.box("cover", -Xw, 300, 0, 400, zb - d - 100, zb - d + 100, uid + ".bend"))
        out.append(k.box("cover", -300, Xw, 0, 400, zb + d - 100, zb + d + 100, uid + ".bend"))
    else:
        for x in (-500, 300):
            out.append(k.box("wall", x, x + 200, 0, 600, zb - 100, zb + 100, uid + ".lane pillar"))
        out.append(k.box("cover", -300, 300, 0, 200, zb + 300, zb + 500, uid + ".breaker"))
    ls = -hs
    a, b = Xw + 200, W
    span = t0 - 2 * Th - 400 - (l0 + 300) if Th else t0 - 400 - (l0 + 300)
    n = max(1, min(3, int(span // 700)))
    for i in range(n):
        z = q(l0 + 300 + (i + 0.5) * span / n, 100)
        if any(k0[2] <= z <= k0[3] and k0[0] < ls * (a + b) / 2 < k0[1] for k0 in keep):
            z += 300
        length = q((b - a) * 0.55, 100)
        if P["low"] == "walls":
            x0, x1 = (a, a + length) if i % 2 == 0 else (b - length, b)
            h = 400 if i % 2 == 0 else 200
            x0, x1 = sorted((ls * x0, ls * x1))
            out.append(k.box("cover", x0, x1, 0, h, z - 100, z + 100, uid + ".low wall"))
        else:
            c = (a + b) / 2.0 + (-1 if i % 2 else 1) * (b - a) * 0.2
            x0, x1 = sorted((ls * (c - 200), ls * (c + 200)))
            out.append(k.box(None, x0, x1, 0, 400, z - 200, z + 200, uid + ".crate",
                             tex="crate"))
    spots.append({"x": ls * q((a + b) / 2.0, 100), "y": 0, "z": q(l0 + 150, 100), "yaw": 180})
    if P["high"] == "low_walk":
        x0, x1 = sorted((hs * (W - 900), hs * (W - 700)))
        out.append(k.box("cover", x0, x1, 0, 400, l0 + 400, t0 - 400, uid + ".side wall"))
    del r
    return out, keep, spots
def hill(k, P, uid="centre"):
    Hh, D = P["Hh"], P["deck"] // 2
    out = []
    if not Hh:
        out.append(k.box(None, -D, D, 0, 20, -D, D, uid + ".hill pad", tex=k.pal["deck"]))
        return out, {"x": 0, "y": 20, "z": 0, "yaw": 0}
    out.append(k.box("deck", -D, D, Hh - 100, Hh, -D, D, uid + ".hill deck"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            x0 = D - 200 if sx > 0 else -D
            z0 = D - 200 if sz > 0 else -D
            out.append(k.box("wall", x0, x0 + 200, 0, Hh - 100, z0, z0 + 200, uid + ".hill pillar"))
    w = P["hill_ramp"] // 2
    kind = P["hill_kind"]
    if P.get("hill_style") == "side":
        Rw = P["hill_ramp"]
        first = k.ramp("ramp", D - 2 * Hh, D, D, D + Rw, 0, Hh, "+x", uid + ".hill ramp", kind)
        out.append(first)
        if P.get("sym") == "turn2":
            out.append(k.m.turned(first, 2))
        else:
            out.append(k.ramp("ramp", D - 2 * Hh, D, -D - Rw, -D, 0, Hh, "+x",
                              uid + ".hill ramp", kind))
    else:
        out.append(k.ramp("ramp", -w, w, D, D + 2 * Hh, 0, Hh, "-z", uid + ".hill ramp", kind))
        out.append(k.ramp("ramp", -w, w, -D - 2 * Hh, -D, 0, Hh, "+z", uid + ".hill ramp", kind))
    out.append(k.ramp("ramp", D, D + 2 * Hh, -w, w, 0, Hh, "-x", uid + ".hill ramp", kind))
    out.append(k.ramp("ramp", -D - 2 * Hh, -D, -w, w, 0, Hh, "+x", uid + ".hill ramp", kind))
    return out, {"x": 0, "y": Hh, "z": 0, "yaw": 0}
FILL_SHAPES = [("breaker", 1200, 200, 200, "cover"), ("breaker", 200, 1200, 200, "cover"),
               ("breaker", 800, 200, 200, "cover"), ("wall", 800, 200, 400, "cover"),
               ("wall", 200, 800, 400, "cover"), ("crate", 400, 400, 400, "crate"),
               ("crate", 200, 200, 200, "crate")]
def apply_dice(P, brief, streams):
    try:
        from .. import dice
    except ImportError:
        return None
    D = dice.roll(brief, streams("style"))
    P["cover"] = max(3, int(round(P["cover"] * (0.6, 0.8, 1.0, 1.4)[D["cover"]]
                                  * (1.4 if "cover" in D.boosted else 1.0))))
    if D["crates"] > D["low_walls"]:
        P["low"] = "crates"
    elif D["low_walls"] > D["crates"]:
        P["low"] = "walls"
    if D["columns"] == 3:
        P["mid"] = "pillars"
    P["crates"] = D["crates"]
    if (brief["level"] == "empty2" and "void_gaps" not in brief["features"]["avoid"]
            and (D["islands"] == 3 or D["void_gaps"] == 3)):
        P["islands"] = True
    P["crenels"] = D["crenels"] >= 2 and P["edge"] == "walled"
    return D
def battlements(k, P, Z):
    if not P.get("crenels"):
        return []
    out = []
    W, E = P["W"], Z["end"]
    for sz in (-1, 1):
        z0, z1 = sorted((sz * Z["t1"], sz * E))
        x = -W
        while x + 400 <= W:
            out.append(k.box("wall", x, x + 400, WALL_TALL, WALL_TALL + 200, z0, z1, "merlon"))
            x += 800
    return out
def cover_fill(k, P, Z, r, keeps, solids, uid="fill"):
    W = P["W"]
    placed, out = [], []
    tries = 0
    zmax = Z["t0"] - 2 * P["Th"] - 300
    zmin = 300
    while len(out) < P["cover"] and tries < 1500:
        tries += 1
        shapes = FILL_SHAPES
        if P.get("crates") == 0:
            shapes = [s for s in FILL_SHAPES if s[0] != "crate"]
        elif P.get("crates", 1) >= 2:
            shapes = FILL_SHAPES + [s for s in FILL_SHAPES if s[0] == "crate"] * 2
        name, w, d, h, role = r.choice(shapes)
        x0 = q(r.uniform(-W + 500, W - 500 - w), 100)
        z0 = q(r.uniform(zmin, zmax - d), 100)
        rect = (x0, x0 + w, z0, z0 + d)
        if rect[2] < zmin or rect[3] > zmax:
            continue
        if any(overlaps(grow(rect, 200), kp) for kp in keeps):
            continue
        if any(overlaps(grow(rect, 450), s) for s in solids + placed):
            continue
        placed.append(rect)
        tex = "crate" if role == "crate" else k.pal["cover"]
        out.append(k.box(None, rect[0], rect[1], 0, h, rect[2], rect[3], "%s.%s" % (uid, name),
                         tex=tex))
    return out
def rects_of(pieces):
    m = v1.arenas_module()
    return [tuple(m.footprint(p)[:4]) for p in pieces]
def grow(rect, m):
    return (rect[0] - m, rect[1] + m, rect[2] - m, rect[3] + m)
def overlaps(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]
def ring_rect(spot, radius=POINT_RING):
    return (spot["x"] - radius, spot["x"] + radius, spot["z"] - radius, spot["z"] + radius)
def fort_graph(Z):
    g = Graph()
    g.add(Zone("hill", "centre", None, 0, 0))
    g.add(Zone("plaza_a", "field", None, -2000, 0))
    g.add(Zone("plaza_c", "field", None, 2000, 0))
    for team, sz in (("blue", 1), ("red", -1)):
        g.add(Zone("base_" + team, "base", team, 0, sz * Z["f"]))
        mid = (Z["l0"] + Z["t0"]) / 2.0 * sz
        g.add(Zone("high_" + team, "lane", team, -2000, mid))
        g.add(Zone("mid_" + team, "lane", team, 0, mid))
        g.add(Zone("low_" + team, "lane", team, 2000, mid))
    g.loop(["plaza_a", "hill", "plaza_c"], "round the hill")
    for team in ("blue", "red"):
        b = "base_" + team
        g.loop([b, "high_" + team, "plaza_a", "hill", "mid_" + team], "%s high-mid loop" % team)
        g.loop([b, "mid_" + team, "hill", "plaza_c", "low_" + team], "%s mid-low loop" % team)
        g.loop(["high_" + team, "mid_" + team, "low_" + team], "%s connectors" % team)
    g.loop(["base_blue", "high_blue", "plaza_a", "high_red", "base_red", "low_red", "plaza_c",
            "low_blue"], "base to base")
    return g
def team_of(a):
    for key in ("team", "side", "id"):
        v = str(a.get(key, "")).lower()
        if "red" in v:
            return "red"
        if "blue" in v:
            return "blue"
    return None
def read_anchors(brief, lines):
    out = {"base": {}, "hill": None, "bridge": None, "points": None, "world_spawn": None,
           "pending": []}
    for a in brief["anchors"]:
        what, where = a["what"], a["where"]
        comp = where.get("compass")
        if what in ("base", "spawns", "spawn", "flag"):
            team = team_of(a)
            ax = axis_compass(comp) if comp else None
            if ax is None:
                lines.append(("approximated", a["id"], "%s: a base stands at one end of the fort; "
                              "no compass given, the default ends kept" % what))
                continue
            out["pending"].append((a, team, ax))
        elif what in ("hill", "centre", "crown", "plaza"):
            out["hill"] = a
            if comp not in (None, "c"):
                lines.append(("approximated", a["id"], "the hill stays in the middle: both teams "
                              "must reach it in the same time (side time gap <= 5%)"))
            else:
                lines.append(("placed", a["id"], "hill in the middle of the plaza"))
        elif what == "point":
            out["points"] = a
            n = a.get("count", 3)
            note = "Domination's three points: A and C on the mirror axis, B on the hill"
            if n != 3:
                lines.append(("approximated", a["id"], "%d points asked; %s" % (n, note)))
            else:
                lines.append(("placed", a["id"], note))
        elif what == "bridge":
            out["bridge"] = a
            if brief["level"] != "empty2":
                lines.append(("approximated", a["id"], "bridges need The Void under them "
                              "(level empty2); the Tiles fort keeps its floor"))
            else:
                lines.append(("placed", a["id"], "the halves are islands; every route crosses "
                              "the gap on a railed bridge (one per route, both sides)"))
        elif what == "world_spawn":
            out["world_spawn"] = a
        else:
            lines.append(("refused", a["id"], "%s is not part of the objective fort yet" % what))
    return out
def solve_orientation(pending, lines):
    turn, swap, fixed = 0, False, None
    named = set(t for _, t, _ in pending if t)
    free = [t for t in ("red", "blue") if t not in named]
    teams = []
    for a, team, ax in pending:
        if team is None and free:
            team = free.pop(0)
        teams.append(team)
    pending = [(a, t, ax) for (a, _, ax), t in zip(pending, teams)]
    for a, team, ax in pending:
        team = team or "red"
        options = []
        for t in range(4):
            for sw in (False, True):
                home = {"red": "n", "blue": "s"}[team]
                if sw:
                    home = {"n": "s", "s": "n"}[home]
                options.append(((t, sw), quarters_for(home, ax) == t))
        good = [o for o, ok in options if ok]
        if fixed is None:
            fixed = set(good)
        else:
            fixed &= set(good)
        if not fixed:
            raise OrientationConflict([x[0]["id"] for x in pending])
    if fixed:
        turn, swap = sorted(fixed)[0]
    for a, team, ax in pending:
        exact = a["where"].get("compass") == ax
        how = "placed" if exact else "approximated"
        note = "%s base at the %s end" % (team or "red", ax)
        if team is None:
            note += " (no team named: red)"
        if not exact:
            note += ", the nearest end to %s" % a["where"]["compass"]
        lines.append((how, a["id"], note))
    return turn, swap
class OrientationConflict(anchormod.Refused):
    def __init__(self, ids):
        self.ids = ids
        self.names = list(ids)
        self.why = ["the two teams' bases stand at the two ends of one line"]
        ValueError.__init__(self, "refused: anchors %s want the bases at ends that cannot both "
                            "be (the smallest conflicting set; name one team's base, or put "
                            "them at opposite ends)" % " and ".join(ids))
def build(brief, streams, reference=False):
    notes, lines = [], []
    m = v1.arenas_module()
    if not reference:
        from . import fortvariety
        if fortvariety.wanted(brief, streams("fort.choose")):
            try:
                arena, meta = fortvariety.build(brief, streams)
                arena["onlyFor"] = only_for(brief)
                meta["polished"] = True
                said = brief.get("symmetry")
                if said not in (None, "auto", meta.get("symmetry")) and \
                        "symmetry" not in (getattr(brief, "defaulted", None) or ()):
                    meta.setdefault("notes", []).append(
                        "symmetry %s: not built - the corner fort (corner bases or four "
                        "sides) is built %s" % (said, meta.get("symmetry")))
                return arena, meta
            except ValueError as why:
                notes.append("corner fort not built (%s): the line fort instead" % why)
    anchors = read_anchors(brief, lines)
    turn, swap = solve_orientation(anchors["pending"], lines)
    symmetry = brief["symmetry"]
    if symmetry in ("turn4", "turn8"):
        notes.append("symmetry %s: a two-team fort is built mirror-symmetric" % symmetry)
        symmetry = "mirror"
    if brief["sides"] == "4":
        notes.append("sides 4: the fort is for two teams (three or four bases come later)")
    P = draw_params(brief, streams, notes, anchors)
    style = apply_dice(P, brief, streams)
    Z = layout_z(P, notes)
    graph = fort_graph(Z)
    pal, pal_notes = palette(brief["theme"], brief["palette"])
    notes += pal_notes
    k = Kit(pal, None, P)
    def half(team, Ph, r_lanes, r_fill):
        uid = "base_" + team
        tp, spawns, flag, tkeep = terrace(k, Ph, Z, team, uid)
        lp, lkeep, lspots = lanes(k, Ph, Z, r_lanes, "lanes_" + team)
        return tp + lp, spawns, flag, tkeep + lkeep, lspots
    blue_pieces, blue_spawns, blue_flag, keeps, spots = half("blue", P, streams("lanes.blue"), None)
    P["sym"] = symmetry
    cp, hill_spot = hill(k, P)
    D = P["deck"] // 2
    Px = q(min(P["W"] - 700, Z["foot"] + POINT_RING + 100 if P["Hh"] else 1800), 100)
    if P["Hh"] == 0:
        Px = q(min(P["W"] - 700, max(1600, D + 900)), 100)
    if P.get("point_gap"):
        Px = q(min(P["W"] - 700, max(Px, P["point_gap"] + 100)), 100)
    pa = {"x": P["high_side"] * Px, "y": 0, "z": 0, "yaw": 0}
    pc = {"x": -P["high_side"] * Px, "y": 0, "z": 0, "yaw": 0}
    w, F = P["hill_ramp"] // 2 + 100, D + 2 * P["Hh"] + 400
    zkeep = (-w, w, -F, F)
    if P["hill_style"] == "side":
        Fz = D + P["hill_ramp"] + 300
        zkeep = (-D - 300, D + 300, -Fz, Fz)
    centre_keep = [(-D - 200, D + 200, -D - 200, D + 200), zkeep, (-F, F, -w, w),
                   grow(ring_rect(pa), -100), grow(ring_rect(pc), -100)]
    def fill_for(pieces, keep, r):
        if reference:
            return []
        solids = [rr for p, rr in zip(pieces, rects_of(pieces))
                  if not str(p.get("tag", "")).endswith((".rug", ".flag pad"))]
        gap = [(-P["W"], P["W"], Z["m"] - 300, Z["l0"] + 300)] if P["islands"] else []
        return cover_fill(k, P, Z, r, centre_keep + keep + gap, solids + rects_of(cp))
    fill = fill_for(blue_pieces, keeps, streams("fill"))
    blue_pieces += fill
    if symmetry == "none":
        Pr = dict(P)
        rr = streams("half.red")
        Pr["high_side"] = rr.choice((-1, 1))
        Pr["mid"] = weighted(rr, [("bend", 2), ("s_bend", 2), ("pillars", 1)])
        Pr["low"] = weighted(rr, [("walls", 3), ("crates", 1)])
        Pr["lane_shift"] = rr.choice((0, 200, 400))
        rp, red_spawns, red_flag, rkeeps, rspots = half("red", Pr, rr, None)
        rp += fill_for(rp, rkeeps, streams("fill.red"))
        red_pieces = [m.mirrored_z(p) for p in rp]
        red_spawns = [m.mirrored_z(s) for s in red_spawns]
        red_flag = m.mirrored_z(red_flag)
        rspots = [m.mirrored_z(s) for s in rspots]
    else:
        tr = (lambda t: m.turned(t, 2)) if symmetry == "turn2" else m.mirrored_z
        trp = (lambda t: m.turned_point(t, 2)) if symmetry == "turn2" else m.mirrored_z
        red_pieces = []
        for p in blue_pieces:
            red = tr(p)
            if str(red.get("tag", "")).endswith(".rug") and P["side_colours"]:
                red = dict(red, tex=TEAM_TEX["red"])
            red["tag"] = str(red.get("tag", "")).replace("_blue", "_red")
            red_pieces.append(red)
        red_spawns = [trp(s) for s in blue_spawns]
        red_flag = trp(blue_flag)
        rspots = [trp(s) for s in spots]
    edge_mode = boundary.resolve(brief)
    yard, edges = yard_and_edges(k, P, Z, brief, edge_mode)
    edges += battlements(k, P, Z) if edge_mode == "visible" else []
    pieces = yard + blue_pieces + red_pieces + cp + edges
    if P["edge"] == "walled" and (brief.get("boundary") or "auto") == "auto":
        mode2 = boundary.resolve(brief, len(pieces) - 2 * len(edges), brief["budget"])
        if mode2 != edge_mode:
            edge_mode = mode2
            yard, edges = yard_and_edges(k, P, Z, brief, edge_mode)
            edges += battlements(k, P, Z) if edge_mode == "visible" else []
            pieces = yard + blue_pieces + red_pieces + cp + edges
    order = []
    for i in range(8):
        order += [red_spawns[i], blue_spawns[i]]
    survey = {"points": [pa, hill_spot, pc], "hill": dict(hill_spot),
              "ctfRed": red_flag, "ctfBlue": blue_flag}
    if swap:
        survey["ctfRed"], survey["ctfBlue"] = survey["ctfBlue"], survey["ctfRed"]
        order = [order[i + 1] if i % 2 == 0 else order[i - 1] for i in range(16)]
        for p in pieces:
            if str(p.get("tag", "")).endswith(".rug") and P["side_colours"]:
                p["tex"] = TEAM_TEX["blue"] if p["tex"] == TEAM_TEX["red"] else TEAM_TEX["red"]
            t = str(p.get("tag", ""))
            if "_blue" in t or "_red" in t:
                p["tag"] = t.replace("_blue", "\0").replace("_red", "_blue").replace("\0", "_red")
    arena = {"key": brief["key"] or "generated", "level": brief["level"],
             "budget": brief["budget"], "pieces": pieces, "spawns": order, "survey": survey,
             "look": kit.look(brief["theme"], brief["sky"], brief["music"])}
    rotate_all(arena, turn)
    centre_at = (0, 0)
    ws = anchors["world_spawn"]
    if ws is not None:
        team = team_of(ws)
        comp = ws["where"].get("compass")
        if team is None and comp not in (None, "c"):
            vec = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}.get(axis_compass(comp))
            if vec:
                rs, bs = survey["ctfRed"], survey["ctfBlue"]
                team = "red" if rs["x"] * vec[0] + rs["z"] * vec[1] > \
                    bs["x"] * vec[0] + bs["z"] * vec[1] else "blue"
        if team in ("red", "blue"):
            f = survey["ctfRed" if team == "red" else "ctfBlue"]
            dx, dz = -int(f["x"]), -int(f["z"])
            lines.append(("placed", ws["id"], "world spawn on the %s flag: the fort is moved so it "
                          "stands at the origin" % team))
        else:
            dx = dz = 0
            lines.append(("placed", ws["id"], "world spawn in the middle (the hill)"))
        shift_all(arena, dx, dz)
        centre_at = (dx, dz)
    arena["marks"] = [dict(survey["points"][0], label="A"), dict(survey["points"][1], label="B hill"),
                      dict(survey["points"][2], label="C"), dict(survey["ctfRed"], label="red flag"),
                      dict(survey["ctfBlue"], label="blue flag")]
    finish(arena, 10 if brief["level"] == "empty" else 0)
    arena["onlyFor"] = only_for(brief)
    length = int(round(abs(arena["survey"]["ctfRed"]["x"] - arena["survey"]["ctfBlue"]["x"])
                       + abs(arena["survey"]["ctfRed"]["z"] - arena["survey"]["ctfBlue"]["z"])))
    arena["blurb"] = "a generated two-team fort: three roads, a hill, two flags"
    arena["note"] = ("a %s fort, flags %d apart: terraced bases with eight spawns behind shields, "
                     "a %s high road, a %s middle road, a low road, the hill in the middle%s"
                     % ("walled" if P["edge"] == "walled" else "railed" if P["edge"] == "rails"
                        else "open", length, "gallery" if P["high"] == "gallery" else "flat",
                        P["mid"].replace("_", "-"),
                        ", the halves on islands joined by bridges" if P["islands"] else ""))
    for key in ("hill", "ctfRed", "ctfBlue"):
        if not standing(arena, arena["survey"][key]):
            notes.append("survey %s does not stand on a floor" % key)
    modules = {"centre": "hill" if P["Hh"] else "hill pad", "base_blue": "terrace",
               "base_red": "terrace", "lanes": {"high": P["high"], "mid": P["mid"],
                                                "low": P["low"]},
               "islands": P["islands"], "symmetry": symmetry,
               "style": style.about() if style is not None else None}
    params = dict(P, Z=Z, centre=modules["centre"], lane="%s/%s/%s" % (P["high"], P["mid"], P["low"]),
                  corner="-", shield="shields", I=P["W"], G=0, B=0, Dh=P["Hh"], Ph=P["Th"], turn=turn, swap=swap)
    module_pieces = {}
    for p in arena["pieces"]:
        mod = str(p.get("tag", "")).split(".")[0]
        module_pieces.setdefault(mod, []).append(
            tuple(sorted((kk, str(v)) for kk, v in p.items() if kk != "tag")))
    meta = {"params": params, "units": 2, "symmetry": symmetry, "modules": modules,
            "anchors": lines, "notes": notes, "graph_faults": graph.faults(),
            "graph": {"zones": sorted(graph.zones), "loops": graph.loops},
            "centre": centre_at, "field_spots": 0, "cover": len(fill),
            "module_pieces": {k2: sorted(v) for k2, v in module_pieces.items()},
            "bases": [[(s["x"], s["y"], s["z"]) for s in arena["spawns"][i::2]] for i in range(2)],
            "family": FAMILY}
    return arena, meta
def yard_and_edges(k, P, Z, brief, edge_mode="visible"):
    W, E = P["W"], Z["end"]
    yard, edges = [], []
    floor = k.pal["floor"]
    if P["islands"]:
        for sz in (-1, 1):
            z0, z1 = sorted((sz * Z["l0"], sz * E))
            yard.append(k.box(None, -W, W, -200, 0, z0, z1, "yard", tex=floor))
        yard.append(k.box(None, -W, W, -200, 0, -Z["m"], Z["m"], "yard", tex=floor))
        xs = [q(P["high_side"] * (P["W"] - P["Gw"] // 2), 100), 0, low_lane_x(P)]
        for sz in (-1, 1):
            g0, g1 = sorted((sz * Z["m"], sz * Z["l0"]))
            for x in xs:
                x0, x1 = x - 300, x + 300
                x0, x1 = max(x0, -W), min(x1, W)
                yard.append(k.box("bridge", x0, x1, -100, 0, g0, g1, "bridge"))
                edges.append(k.m.rail(k.pal["trim"], x0, x0 + 60, g0, g1, 0, 120, "bridge rail"))
                edges.append(k.m.rail(k.pal["trim"], x1 - 60, x1, g0, g1, 0, 120, "bridge rail"))
            for lip in (Z["m"], Z["l0"]):
                zz = sz * lip
                if lip == Z["m"]:
                    za, zb = (zz - 60, zz) if sz > 0 else (zz, zz + 60)
                else:
                    za, zb = (zz, zz + 60) if sz > 0 else (zz - 60, zz)
                cuts = sorted([(x - 300, x + 300) for x in xs])
                x = -W
                for c0, c1 in cuts + [(W, W)]:
                    if c0 - x >= 400:
                        edges.append(k.m.rail(k.pal["trim"], x, c0, za, zb, 0, 160, "gap rail"))
                    x = c1
        for sz in (-1, 1):
            z0, z1 = sorted((sz * (Z["l0"] + 400), sz * (E - 400)))
            yard.append(k.box("keel", -W + 400, W - 400, -700, -200, z0, z1, "keel"))
        yard.append(k.box("keel", -Z["m"] + 400, Z["m"] - 400, -700, -200,
                          -Z["m"] + 400, Z["m"] - 400, "keel"))
    else:
        for sz in (-1, 1):
            z0, z1 = sorted((0, sz * E))
            yard.append(k.box(None, -W, W, -200, 0, z0, z1, "yard", tex=floor))
        if brief["level"] == "empty2":
            yard.append(k.box("keel", -W + 600, W - 600, -800, -200, -E + 600, E - 600, "keel"))
    if P["islands"]:
        regions = [(Z["l0"], E), (-E, -Z["l0"]), (0, Z["m"]), (-Z["m"], 0)]
    else:
        regions = [(0, E), (-E, 0)]
    if P["edge"] == "walled":
        rects = []
        for z0, z1 in regions:
            rects.append((-W - 200, -W, z0, z1))
            rects.append((W, W + 200, z0, z1))
        for sz in (-1, 1):
            zz0, zz1 = sorted((sz * Z["t1"], sz * E))
            rects.append((-W, W, zz0, zz1))
        def make(tex, x0, x1, y0, y1, z0, z1, _r, tag):
            return k.m.box(tex, x0, x1, y0, y1, z0, z1, tag)
        edges += boundary.walls(make, edge_mode, rects, 0, 0, WALL_TALL, k.pal["wall"],
                                "outer wall", top=WALL_TALL + 400)
    elif P["edge"] == "rails":
        for z0, z1 in regions:
            for x0 in (-W, W - 60):
                edges.append(k.m.rail(k.pal["trim"], x0, x0 + 60, z0, z1, 0, 160, "outer rail"))
        for sz in (-1, 1):
            zz0, zz1 = sorted((sz * (E - 60), sz * E))
            edges.append(k.m.rail(k.pal["trim"], -W, W, zz0, zz1, 0, 160, "outer rail"))
    return yard, edges
def only_for(brief):
    asked = [mm for mm in brief["modes"] if mm in MODES]
    return asked or list(MODES)
