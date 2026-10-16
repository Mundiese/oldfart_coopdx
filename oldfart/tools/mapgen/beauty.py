from . import kit
from .layout import UNDER_EYE, grow, open_map, overlaps, rect_of
RAIL_H = 120
SMALL_MAX = 8
RAIL_T = 80
CONTRAST_MIN = 0.18
WALL_ALTS = ("brickdarkgrey", "redbrick", "greystone", "darkplanks", "mossyrock",
             "whitestonebrick", "bricklightgrey", "stone2")
def luminance(rgb):
    r, g, b = [c / 255.0 for c in rgb]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
def palette(theme, override=None):
    from . import values
    pal, notes = kit.palette(theme, override)
    need = values.minimum(kit.PALETTE_FAMILY.get("family"))
    try:
        cols = kit.colours()
    except Exception:
        return pal, notes
    have = kit.textures()
    def lum(t):
        return luminance(cols[t]) if t in cols else None
    lf = lum(pal["floor"])
    lw = lum(pal["wall"])
    if lf is not None and lw is not None and abs(lf - lw) < need and not override \
            and not pal.get("wall_base") and not kit.PALETTE_FAMILY.get("family"):
        best = None
        for t in WALL_ALTS:
            if t in have and lum(t) is not None:
                d = abs(lf - lum(t))
                if d >= need and (best is None or abs(lum(t) - lw) < best[2]):
                    best = (d, t, abs(lum(t) - lw))
        if best:
            notes.append("beauty R2: wall %s -> %s (contrast %.2f -> %.2f against the floor)"
                         % (pal["wall"], best[1], abs(lf - lw), best[0]))
            if pal["cover"] == pal["wall"]:
                pal["cover"] = best[1]
            pal["wall"] = best[1]
    return pal, notes
def _built_accent(pal, i, fallback):
    acc = pal.get("accents_built") or pal.get("accents") or []
    return acc[i % len(acc)] if acc else pal[fallback]
class Heights:
    def __init__(self, pieces):
        self.items = [(rect_of(p), p) for p in pieces]
    def tops(self, x, z):
        out = []
        for r, p in self.items:
            if r[0] < x < r[1] and r[2] < z < r[3]:
                out.append(p["y"] + p["h"])
        return out
def _cap(L, frac=0.25):
    from .layout import compile_pieces
    budget = L.brief["budget"]
    try:
        now = (L.fixed_count + len(L.fill) + len(L.shields)) if getattr(L, "fixed_count", None) \
            else len(compile_pieces(L))
    except Exception:
        now = len(L.structure) + len(L.top) + len(L.fill) + len(L.shields)
    return max(0, min(int(frac * now) + 4, int(0.85 * budget) - now)), now
def dress(L):
    d = L.dice
    r = L.streams("beauty")
    cap, before = _cap(L)
    used = 0
    rules = {}
    pal = L.pal
    sym = L.sym
    clear = list(getattr(L, "clear", []))
    for b in L.bases:
        clear += sym.rects(grow(b["rect"], 400))
    def add(piece, rule, copy=True):
        nonlocal used
        group = piece if isinstance(piece, list) else [piece]
        copies = [c for p in group for c in (sym.pieces(p) if copy else [p])]
        if used + len(copies) > cap:
            return False
        if rule in ("R4 pillars", "R7 crenels") and \
                rules.get("R4 pillars", 0) + rules.get("R7 crenels", 0) + len(copies) > SMALL_MAX:
            return False
        L.dress.extend(copies)
        used += len(copies)
        rules[rule] = rules.get(rule, 0) + len(copies)
        return True
    def level(knob):
        return d[knob] if d is not None else 2
    if L.landmark:
        lm = L.landmark
        rc = L.streams("centre")
        x, z, y = lm["x"], lm["z"], lm["y"]
        flat = L.brief["verticality"] == "flat"
        if flat or level("landmark") == 0:
            w = min(rc.choice((400, 600)), lm.get("max_w", 800))
            h = (UNDER_EYE if open_map(L.brief) else 200) if flat else rc.choice((300, 450))
            body = kit.kind("box").make(_built_accent(pal, 0, "wall"),
                                        x - w // 2, x + w // 2, y, y + h, z - w // 2, z + w // 2,
                                        None, "centre.plinth")
            pieces = [body]
            rule = "R6 plinth"
        else:
            w = rc.choice((400, 400, 600)) if level("landmark") < 3 else rc.choice((600, 800))
            w = min(w, lm.get("max_w", 800))
            around = lm.get("around", 600)
            tall = max(2000 - y if y < 1400 else 600, 3 * around) + rc.choice((0, 200, 400))
            tall = min(tall, 2800)
            over = rc.choice((100, 200))
            body = kit.kind("box").make(pal["wall"], x - w // 2, x + w // 2, y, y + tall,
                                        z - w // 2, z + w // 2, None, "centre.landmark")
            cap_p = kit.kind("box").make(_built_accent(pal, 0, "trim"),
                                         x - w // 2 - over, x + w // 2 + over, y + tall,
                                         y + tall + 150, z - w // 2 - over, z + w // 2 + over,
                                         None, "centre.landmark cap")
            pieces = [body, cap_p]
            rule = "R6 landmark"
        if used + len(pieces) <= cap + 2:
            L.dress += pieces
            used += len(pieces)
            rules[rule] = len(pieces)
    if level("rails") > 0 and not L.solid:
        H = Heights(L.structure + L.top + L.fill + L.shields)
        gap_every = {1: 3, 2: 5, 3: 9}[level("rails")]
        opens = list(L.edges_open)
        zones = ("base", "perch", "centre", "lane", "field") if level("rails") >= 2 \
            else ("base", "perch", "lane")
        for f in L.floors:
            if f["zone"] not in zones:
                continue
            for run in _edge_runs(f, H, opens, clear):
                (ax, az, bx, bz, side) = run
                for (s0, s1) in _split(run, gap_every):
                    rect = _rail_rect(side, s0, s1, f["rect"])
                    p = kit.kind("box").make(pal["trim"], rect[0], rect[1], f["y"],
                                             f["y"] + RAIL_H, rect[2], rect[3], None,
                                             "dress.rail")
                    if not add(p, "R3 rails"):
                        break
    if L.solid and getattr(L, "parapets", True):
        H = Heights(L.structure + L.top + L.fill + L.shields + L.dress)
        n_par = 0
        for f in L.floors:
            if f["y"] <= 200:
                continue
            for run in _edge_runs(f, H, list(L.edges_open), [], drop=200):
                (ax, az, bx, bz, side) = run
                for (s0, s1) in _split(run, 10 ** 6):
                    rect = _rail_rect(side, s0, s1, f["rect"])
                    p = kit.kind("box").make(pal["trim"], rect[0], rect[1], f["y"],
                                             f["y"] + 300, rect[2], rect[3], None,
                                             "dress.parapet")
                    copies = sym.pieces(p)
                    L.dress.extend(copies)
                    n_par += len(copies)
        if n_par:
            rules["parapets (The Tiles)"] = n_par
            used += n_par
    if not L.solid and level("keels") > 0:
        big = sorted((f for f in L.floors if f["zone"] in ("field", "centre", "base")),
                     key=lambda f: -((f["rect"][1] - f["rect"][0]) * (f["rect"][3] - f["rect"][2])))
        n = {1: 1, 2: 2, 3: 3}[level("keels")]
        for f in big[:n]:
            x0, x1, z0, z1 = f["rect"]
            if x1 - x0 < 1600 or z1 - z0 < 1600:
                continue
            bottom = f.get("bottom", f["y"] - 200)
            k1 = (x0 + 400, x1 - 400, z0 + 400, z1 - 400)
            k1 = tuple(int(v // 200 * 200) for v in k1)
            p = kit.kind("box").make(pal["keel"], k1[0], k1[1], bottom - 500, bottom,
                                     k1[2], k1[3], None, "dress.keel")
            if any(overlaps(rect_of(p), rect_of(o)) and o["y"] + o["h"] <= bottom and
                   o["y"] + o["h"] > bottom - 900 for o in L.structure):
                continue
            add(p, "R10 keels")
    walls = long_walls(L.structure + L.top)
    if walls and level("pillars") > 0:
        every = r.choice((600, 800, 1000))
        for p in walls[:6]:
            for piece in wall_pillars(p, every, _built_accent(pal, 1, "wall")):
                if not add(piece, "R4 pillars"):
                    break
    crenel_theme = L.brief["theme"] in ("castle", "lava", "desert")
    if walls and level("crenels") > (1 if crenel_theme else 2):
        for p in walls[:3]:
            for piece in wall_crenels(p, pal["wall"]):
                if not add(piece, "R7 crenels"):
                    break
    L.report["beauty"] = {"rules": rules, "dress_pieces": used, "cap": cap,
                          "theme": L.brief["theme"],
                          "palette": {k: v for k, v in pal.items() if k != "accents"},
                          "accents": list(pal.get("accents", []))}
SCENERY_ROOM = 8
def scenery(L):
    from . import scenery as scenerymod
    sym = L.sym
    rules = {}
    notes = []
    now = len(L.structure) + len(L.top) + len(L.fill) + len(L.shields) + len(L.dress)
    if getattr(L, "fixed_count", None):
        now = L.fixed_count + len(L.fill) + len(L.shields) + len(L.dress)
    asked = sum(int(o.get("count", 1) or 1) for o in (L.brief.get("objects") or [])
                if isinstance(o, dict))
    cap = max(0, min(SCENERY_ROOM, int(0.85 * L.brief["budget"]) - now - asked))
    used = 0
    def add(piece, rule, copy=True):
        nonlocal used
        group = piece if isinstance(piece, list) else [piece]
        copies = [c for p in group for c in (sym.pieces(p) if copy else [p])]
        if used + len(copies) > cap:
            return False
        L.dress.extend(copies)
        used += len(copies)
        rules[rule] = rules.get(rule, 0) + len(copies)
        return True
    reserve = 0
    if (L.family == "objective" or scenerymod.wanted(L, "framing")) and not (
            scenerymod.avoided(L, "framing") or scenerymod.avoided(L, "gate")
            or scenerymod.avoided(L, "arches")):
        probe = {"kind": "pillar", "x": 0, "y": 0, "z": 0, "w": 200, "h": 200, "d": 200,
                 "yaw": 0, "tex": L.pal.get("trim") or L.pal.get("wall")}
        reserve = min(cap, 3 * len(sym.pieces(probe)))
    split = scenerymod.gradient_walls(L, max(0, cap - used - reserve), notes)
    if split:
        used += split
        rules["R13 gradient walls"] = split
    scenerymod.dress(L, add, notes)
    rep = L.report.setdefault("beauty", {"rules": {}})
    rep.setdefault("rules", {}).update(rules)
    rep["scenery"] = {"pieces": used, "cap": cap, "notes": notes}
    rep["scenery_notes"] = notes
    return rules
def long_walls(pieces):
    return [p for p in pieces
            if p["kind"] == "box" and p["h"] >= 400 and min(p["w"], p["d"]) <= 400
            and max(p["w"], p["d"]) >= 1000]
def wall_pillars(p, every, tex):
    x0, x1, z0, z1 = rect_of(p)
    along_x = (x1 - x0) >= (z1 - z0)
    a0, a1 = (x0, x1) if along_x else (z0, z1)
    t = a0 + every // 2
    while t + 100 <= a1 - 100:
        if along_x:
            rect = (t - 100, t + 100, z0, z1)
        else:
            rect = (x0, x1, t - 100, t + 100)
        rect = tuple(int(v) for v in rect)
        yield kit.kind("box").make(tex, rect[0], rect[1], p["y"], p["y"] + p["h"] + 100,
                                   rect[2], rect[3], None, "dress.pillar")
        t += every
def wall_crenels(p, tex):
    x0, x1, z0, z1 = rect_of(p)
    along_x = (x1 - x0) >= (z1 - z0)
    a0, a1 = (x0, x1) if along_x else (z0, z1)
    t = a0
    k = 0
    while t + 200 <= a1:
        if k % 2 == 0:
            rect = (t, t + 200, z0, z1) if along_x else (x0, x1, t, t + 200)
            yield kit.kind("box").make(tex, rect[0], rect[1], p["y"] + p["h"],
                                       p["y"] + p["h"] + 150, rect[2], rect[3], None,
                                       "dress.crenel")
        t += 200
        k += 1
def _edge_runs(f, H, opens, clear, drop=400):
    x0, x1, z0, z1 = f["rect"]
    y = f["y"]
    out = []
    sides = (("n", [(x, z0) for x in range(int(x0), int(x1), 200)], (0, -1)),
             ("s", [(x, z1) for x in range(int(x0), int(x1), 200)], (0, 1)),
             ("w", [(x0, z) for z in range(int(z0), int(z1), 200)], (-1, 0)),
             ("e", [(x1, z) for z in range(int(z0), int(z1), 200)], (1, 0)))
    for side, starts, (ox, oz) in sides:
        run = []
        for (a, b) in starts:
            if side in ("n", "s"):
                mx, mz = a + 100, b
            else:
                mx, mz = a, b + 100
            px, pz = mx + ox * 100, mz + oz * 100
            ix, iz = mx - ox * 100, mz - oz * 100
            outside = [t for t in H.tops(px, pz) if t >= y - drop]
            inside = [t for t in H.tops(ix, iz) if abs(t - y) <= 1]
            cell = (min(mx, ix) - 100 if side in ("n", "s") else min(mx, ix),
                    max(mx, ix) + 100 if side in ("n", "s") else max(mx, ix),
                    min(mz, iz) if side in ("n", "s") else min(mz, iz) - 100,
                    max(mz, iz) if side in ("n", "s") else max(mz, iz) + 100)
            blocked = any(overlaps(grow(cell, 50), o) for o in opens) or \
                any(overlaps(cell, c) for c in clear)
            tall_in = [t for t in H.tops(ix, iz) if t > y + 1]
            if not outside and inside and not blocked and not tall_in:
                run.append((mx, mz))
            else:
                if len(run) >= 3:
                    out.append((run[0][0], run[0][1], run[-1][0], run[-1][1], side))
                run = []
        if len(run) >= 3:
            out.append((run[0][0], run[0][1], run[-1][0], run[-1][1], side))
    return out
def _split(run, every):
    ax, az, bx, bz, side = run
    if side in ("n", "s"):
        a0, a1 = ax - 100, bx + 100
    else:
        a0, a1 = az - 100, bz + 100
    out = []
    t = a0
    while t < a1:
        e = min(a1, t + every * 200)
        if e - t >= 400:
            out.append((t, e))
        t = e + 200
    return out
def _rail_rect(side, s0, s1, rect):
    x0, x1, z0, z1 = rect
    if side == "n":
        return (s0, s1, z0, z0 + RAIL_T)
    if side == "s":
        return (s0, s1, z1 - RAIL_T, z1)
    if side == "w":
        return (x0, x0 + RAIL_T, s0, s1)
    return (x1 - RAIL_T, x1, s0, s1)
