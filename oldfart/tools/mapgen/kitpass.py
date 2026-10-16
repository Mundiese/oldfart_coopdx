from . import kit, v1
from .layout import grow, open_map, overlaps, rect_of
STAIR_RISE_MAX = 280
FENCE_H = 160
FENCE_T = 60
COLUMN_W = 400
COLUMN_EVERY = 800
GATE_POST = 200
GATE_H = 500
ARCH_H = 200
RUG_T = 20
DAIS_RISE = 200
DAIS_RUN = 400
FENCE_TEX = {"castle": "darkplanks", "ice": "woodenplank2", "desert": "woodenplank1",
             "lava": "rivetedplate", "wood": "darkplanks", "sky": "whitemarble",
             "garden": "woodenplank1"}
def fence_tex(L):
    tex = kit.dress_tex(L.pal, "fence", FENCE_TEX.get(L.brief["theme"], "darkplanks"))
    if tex not in kit.textures():
        tex = L.pal.get("trim", L.pal["wall"])
    return tex
def diagonals_on(brief):
    from .brief import dna
    if "diagonals" in brief["features"]["avoid"]:
        return False
    return "diagonals" in brief["features"]["want"] or dna(brief, "complexity") >= 0.5
def octagon_pieces(tex, a, y0, y1, tag):
    b = int(round(a * 0.414 / 100.0)) * 100
    s = a - b
    mk_box, mk_prism = kit.kind("box").make, kit.kind("prism").make
    out = [mk_box(tex, -a, a, y0, y1, -b, b, None, tag),
           mk_box(tex, -b, b, y0, y1, -a, -b, None, tag),
           mk_box(tex, -b, b, y0, y1, b, a, None, tag)]
    for (x0, z0, solid) in ((b, b, "-x-z"), (-a, b, "+x-z"), (b, -a, "-x+z"), (-a, -a, "+x+z")):
        out.append(mk_prism(tex, x0, x0 + s, y0, y1, z0, z0 + s, solid, tag))
    return out
def unit_floor(L, f):
    if f.get("copy", True) or L.sym.units == 1:
        return True
    copies = L.sym.rects(f["rect"])
    if len(set(copies)) < L.sym.units:
        return False
    return tuple(f["rect"]) == min(copies)
def _level(L, knob):
    d = L.dice
    if d is None or knob not in d:
        return 0
    return d[knob]
def _budget_left(L):
    from .layout import compile_pieces
    budget = L.brief["budget"]
    try:
        now = (L.fixed_count + len(L.fill) + len(L.shields) + len(L.dress)) \
            if getattr(L, "fixed_count", None) else len(compile_pieces(L))
    except Exception:
        now = len(L.structure) + len(L.top) + len(L.fill) + len(L.shields) + len(L.dress)
    return int(0.92 * budget) - now
class Pass:
    def __init__(self, L):
        self.L = L
        self.left = _budget_left(L)
        self.rules = {}
        self.hard = list(getattr(L, "clear", []))
        for b in L.bases:
            self.hard += L.sym.rects(grow(b["rect"], 200))
        self.clear = self.hard + list(L.keeps)
        self.opens = list(L.edges_open)
    def add(self, pieces, rule, copy=True):
        out = []
        for p in pieces:
            out += self.L.sym.pieces(p) if copy else [p]
        if len(out) > self.left:
            return False
        self.L.dress.extend(out)
        self.left -= len(out)
        self.rules[rule] = self.rules.get(rule, 0) + len(out)
        return True
    def free(self, rect, margin=0):
        if any(overlaps(rect, c) for c in self.clear):
            return False
        r = grow(rect, margin)
        if any(overlaps(r, o) for o in self.opens):
            return False
        return True
    def flat_floor(self, rect, y):
        L = self.L
        hit = False
        for p in L.structure + L.top + L.fill + L.shields + L.dress:
            pr = rect_of(p)
            if not overlaps(pr, rect):
                continue
            top = p["y"] + p["h"]
            if p["kind"] not in ("box",) and top > y - 1:
                return False
            if top > y + 1:
                return False
            if abs(top - y) <= 1:
                hit = True
        return hit
def run(L):
    P = Pass(L)
    want = L.brief["features"]["want"]
    reserve = min(max(P.left, 0), sum(len(SHOWCASE[f][1]) * L.sym.units
                                      for f in SHOWCASE if f in want))
    P.left -= reserve
    stairs(L, P)
    fences(L, P)
    landmark_kit(L, P)
    colonnades(L, P)
    gates(L, P)
    rugs(L, P)
    P.left += reserve
    missing = ensure_wanted(L, P)
    L.report["kit"] = {"rules": dict(P.rules), "left": P.left, "not_placed": missing,
                       "knobs": {k: _level(L, k) for k in
                                 ("stairs", "fences", "arches", "colonnades", "diagonals",
                                  "slabs", "corners", "buildings")}}
    return P.rules
SHOWCASE = {
    "arches": (("arch",), [(0, 200, 0, 200, 0, 500, "pillar", None),
                           (800, 1000, 0, 200, 0, 500, "pillar", None),
                           (0, 1000, 0, 200, 500, 700, "arch", None)], (1000, 200)),
    "pillars": (("pillar",), [(0, 400, 0, 400, 0, 700, "pillar", None),
                              (800, 1200, 0, 400, 0, 700, "pillar", None)], (1200, 400)),
    "fences": (("rail",), [(0, 800, 170, 230, 0, 160, "rail", None)], (800, 400)),
    "diagonals": (("prism",), [(0, 400, 0, 400, 0, 400, "prism", "+x-z"),
                               (400, 800, 0, 400, 0, 400, "box", None),
                               (800, 1200, 0, 400, 0, 400, "prism", "-x-z")], (1200, 400)),
    "stairs": (("stairs", "outerstairs", "innerstairs"),
               [(0, 600, 0, 400, 0, 200, "box", None),
                (0, 600, 400, 800, 0, 200, "stairs", "-z")], (600, 800)),
    "corners": (("outerstairs", "innerstairs", "outer", "inner"),
                [(400, 800, 0, 400, 0, 200, "box", None),
                 (400, 800, 400, 800, 0, 200, "stairs", "-z"),
                 (0, 400, 0, 400, 0, 200, "stairs", "+x"),
                 (0, 400, 400, 800, 0, 200, "outerstairs", "+x-z")], (800, 800)),
    "slabs": (("box",), [(0, 800, 0, 800, 0, 40, "box", None)], (800, 800)),
}
SHOWCASE_SMALL = {
    "arches": ([(0, 200, 0, 200, 0, 400, "pillar", None),
                (400, 600, 0, 200, 0, 400, "pillar", None),
                (0, 600, 0, 200, 400, 600, "arch", None)], 600, 200),
    "pillars": ([(0, 400, 0, 400, 0, 600, "pillar", None)], 400, 400),
}
def ensure_wanted(L, P):
    want = L.brief["features"]["want"]
    have = set(p["kind"] for p in L.structure + L.top + L.fill + L.dress + L.shields)
    missing = []
    for feat in sorted(SHOWCASE):
        if feat not in want:
            continue
        kinds, parts, (w, d) = SHOWCASE[feat]
        if feat != "slabs" and have & set(kinds):
            continue
        if feat == "slabs" and any(p["kind"] == "box" and p["h"] in (20, 40)
                                   for p in L.dress + L.fill):
            continue
        if not _showcase(L, P, feat, parts, w, d) and not (
                feat in SHOWCASE_SMALL and _showcase(L, P, feat, *SHOWCASE_SMALL[feat])):
            missing.append(feat)
    return missing
def _copies_apart(L, r, floor):
    copies = L.sym.rects(r)
    if len(set(copies)) < L.sym.units:
        return False
    for i, a in enumerate(copies):
        if not (floor[0] <= a[0] and a[1] <= floor[1] and floor[2] <= a[2] and a[3] <= floor[3]):
            return False
        if any(overlaps(grow(a, 200), b) for b in copies[i + 1:]):
            return False
    return True
def _showcase(L, P, feat, parts, w, d):
    floors = sorted((f for f in L.floors if f["zone"] in ("field", "centre", "lane", "perch")),
                    key=lambda f: -((f["rect"][1] - f["rect"][0]) * (f["rect"][3] - f["rect"][2])))
    flat_map = L.brief["verticality"] == "flat"
    for f in floors:
        x0, x1, z0, z1 = f["rect"]
        y = f["y"]
        for turn in (False, True):
            ww, dd = (d, w) if turn else (w, d)
            if x1 - x0 < ww + 400 or z1 - z0 < dd + 400:
                continue
            for ox in range(int(x0) + 200, int(x1) - ww - 199, 200):
                for oz in range(int(z0) + 200, int(z1) - dd - 199, 200):
                    r = (ox, ox + ww, oz, oz + dd)
                    if not P.free(r, 200) or not P.flat_floor(r, y):
                        continue
                    if not unit_floor(L, f) and not _copies_apart(L, r, f["rect"]):
                        continue
                    pieces = []
                    for (a0, a1, b0, b1, y0, y1, kind, dir_) in parts:
                        if flat_map and y1 > 200:
                            y1 = 200
                        if turn:
                            a0, a1, b0, b1 = b0, b1, a0, a1
                            dir_ = {"-z": "-x", "+z": "+x", "+x": "+z", "-x": "-z",
                                    "+x-z": "-x+z", "-x-z": "-x-z", "+x+z": "+x+z",
                                    "-x+z": "+x-z"}.get(dir_, dir_)
                        rect = (ox + a0, ox + a1, oz + b0, oz + b1)
                        if y0 >= y1:
                            continue
                        pieces.append(kit.kind(kind).make(
                            kit.dress_tex(L.pal, "column", L.pal["wall"]) if kind == "pillar"
                            and feat != "slabs" else
                            kit.dress_tex(L.pal, "arch", L.pal["wall"]) if kind == "arch"
                            and feat != "slabs" else
                            L.pal["wall"] if kind in ("prism", "box")
                            and feat != "slabs" else
                            (fence_tex(L) if kind == "rail"
                             else (L.pal.get("accents") or [L.pal["deck"]])[0]
                             if feat == "slabs" else L.pal.get("ramp", L.pal["wall"])),
                            rect[0], rect[1], y + y0, y + y1, rect[2], rect[3], dir_,
                            "dress.%s" % feat))
                    for p in pieces:
                        if p["kind"] == "rail" and p["tex"] not in kit.textures():
                            p["tex"] = L.pal["trim"]
                    if P.add(pieces, "kit wish: %s" % feat):
                        P.clear.append(grow(r, 200))
                        return True
    return False
def stairs(L, P):
    want = "stairs" in L.brief["features"]["want"]
    avoid = "stairs" in L.brief["features"]["avoid"] or \
        "ramps_only" in L.brief["features"]["want"]
    if avoid or not (want or _level(L, "stairs") >= 2 or
                     (_level(L, "corners") >= 2 and _level(L, "slabs") >= 1)):
        return
    n = 0
    for group in (L.structure, L.top):
        out = []
        for p in group:
            if p["kind"] == "ramp" and p["h"] >= 100 and p["d"] >= 2 * p["h"]:
                flights = split_flights(p)
                if flights and len(flights) - 1 <= P.left:
                    out += flights
                    n += 1
                    P.left -= len(flights) - 1
                    continue
            out.append(p)
        group[:] = out
    if n:
        P.rules["K1 stairs"] = n
def split_flights(ramp):
    n = 1
    while ramp["h"] / float(n) > STAIR_RISE_MAX:
        n += 1
    if n == 1:
        return [dict(ramp, kind="stairs")]
    if ramp["h"] % (50 * n) or ramp["d"] % (100 * n):
        return None
    m = v1.arenas_module()
    x0, x1, z0, z1, up = m.footprint(ramp)
    rise, run = ramp["h"] // n, ramp["d"] // n
    out = []
    for k in range(n):
        y0 = ramp["y"] + k * rise
        if up[0] > 0:
            r = (x0 + k * run, x0 + (k + 1) * run, z0, z1, "+x")
        elif up[0] < 0:
            r = (x1 - (k + 1) * run, x1 - k * run, z0, z1, "-x")
        elif up[1] > 0:
            r = (x0, x1, z0 + k * run, z0 + (k + 1) * run, "+z")
        else:
            r = (x0, x1, z1 - (k + 1) * run, z1 - k * run, "-z")
        out.append(kit.with_tex(kit.kind("stairs").make(None, r[0], r[1], y0, y0 + rise, r[2],
                                                        r[3], r[4], ramp.get("tag", "")),
                                kit.tex_key(ramp)))
        if k:
            out.append(kit.with_tex(kit.kind("box").make(None, r[0], r[1], ramp["y"], y0, r[2],
                                                         r[3], None, ramp.get("tag", "")),
                                    kit.tex_key(ramp)))
    return out
def fences(L, P):
    if "fences" in L.brief["features"]["avoid"]:
        return
    if not ("fences" in L.brief["features"]["want"] or _level(L, "fences") >= 1):
        return
    if open_map(L.brief) and "fences" not in L.brief["features"]["want"]:
        P.rules["K2 fences: open map, rails kept"] = 0
        return
    tex = fence_tex(L)
    out, n = [], 0
    for p in L.dress:
        if p.get("tag") != "dress.rail":
            out.append(p)
            continue
        x0, x1, z0, z1 = rect_of(p)
        long_x = (x1 - x0) >= (z1 - z0)
        if long_x:
            mid = (z0 + z1) / 2.0
            r = (x0, x1, mid - FENCE_T / 2.0, mid + FENCE_T / 2.0)
        else:
            mid = (x0 + x1) / 2.0
            r = (mid - FENCE_T / 2.0, mid + FENCE_T / 2.0, z0, z1)
        f = kit.kind("rail").make(tex, int(r[0]), int(r[1]), p["y"], p["y"] + FENCE_H,
                                  int(r[2]), int(r[3]), None, "dress.fence")
        out.append(f)
        n += 1
    if n:
        L.dress[:] = out
        P.rules["K2 fences"] = n
def colonnades(L, P):
    if L.brief["verticality"] == "flat":
        return
    lvl = _level(L, "colonnades")
    if "pillars" in L.brief["features"]["want"]:
        lvl = max(lvl, 2)
    if lvl == 0 or "pillars" in L.brief["features"]["avoid"]:
        return
    arches = _level(L, "arches") >= 1 or "arches" in L.brief["features"]["want"]
    if "arches" in L.brief["features"]["avoid"]:
        arches = False
    tex = kit.dress_tex(L.pal, "column", L.pal.get("trim") or L.pal["wall"])
    arch_tex = kit.dress_tex(L.pal, "arch", L.pal["wall"])
    floors = sorted((f for f in L.floors if f["zone"] in ("centre", "field")
                     and unit_floor(L, f)),
                    key=lambda f: -((f["rect"][1] - f["rect"][0]) * (f["rect"][3] - f["rect"][2])))
    rows = {1: 1, 2: 2, 3: 3}[lvl]
    h = L.streams("kit").choice((600, 800))
    done = 0
    for f in floors:
        if done >= rows:
            break
        x0, x1, z0, z1 = f["rect"]
        if x1 - x0 < 2000 or z1 - z0 < 2000:
            continue
        y = f["y"]
        best = []
        for side in ("n", "s", "w", "e"):
            if side in ("n", "s"):
                zc = z0 + 200 if side == "n" else z1 - 200
                a0, a1 = x0 + 400, x1 - 400
                cells = [(t, zc) for t in range(int(a0), int(a1) + 1, COLUMN_EVERY)]
            else:
                xc = x0 + 200 if side == "w" else x1 - 200
                a0, a1 = z0 + 400, z1 - 400
                cells = [(xc, t) for t in range(int(a0), int(a1) + 1, COLUMN_EVERY)]
            ok = []
            for (cx, cz) in cells:
                r = (cx - COLUMN_W // 2, cx + COLUMN_W // 2, cz - COLUMN_W // 2, cz + COLUMN_W // 2)
                ok.append((cx, cz) if P.free(r, 200) and P.flat_floor(r, y) else None)
            runs, cur = [], []
            for c in ok + [None]:
                if c is None:
                    if len(cur) >= 2:
                        runs.append(cur)
                    cur = []
                else:
                    cur.append(c)
            if sum(len(x) for x in runs) > sum(len(x) for x in best):
                best = runs
        if best:
            pieces = []
            for run_ in best:
                pieces += [kit.kind("pillar").make(tex, cx - COLUMN_W // 2, cx + COLUMN_W // 2, y,
                                                   y + h, cz - COLUMN_W // 2, cz + COLUMN_W // 2,
                                                   None, "dress.column")
                           for cx, cz in run_]
                if arches:
                    for (ax, az), (bx, bz) in zip(run_, run_[1:]):
                        if ax == bx:
                            r = (ax - 100, ax + 100, min(az, bz), max(az, bz))
                        else:
                            r = (min(ax, bx), max(ax, bx), az - 100, az + 100)
                        pieces.append(kit.kind("arch").make(arch_tex, r[0], r[1], y + h,
                                                            y + h + ARCH_H, r[2], r[3], None,
                                                            "dress.arcade"))
            if P.add(pieces, "K4 arcades" if arches else "K3 colonnades"):
                done += 1
                for run_ in best:
                    for cx, cz in run_:
                        P.clear.append((cx - 300, cx + 300, cz - 300, cz + 300))
def gates(L, P):
    if L.brief["verticality"] == "flat":
        return
    if _level(L, "arches") < 2 and "arches" not in L.brief["features"]["want"]:
        return
    if "arches" in L.brief["features"]["avoid"]:
        return
    tex = L.pal["wall"]
    n = 0
    done = []
    for o in L.edges_open:
        if n >= (2 if _level(L, "arches") >= 3 else 1):
            break
        if o in done:
            continue
        done += L.sym.rects(o)
        x0, x1, z0, z1 = o
        across_x = (x1 - x0) >= (z1 - z0)
        width = (x1 - x0) if across_x else (z1 - z0)
        if not 400 <= width <= 1400:
            continue
        mid_x, mid_z = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        tops = [p["y"] + p["h"] for p in L.structure + L.top if p["kind"] == "box"
                and overlaps(rect_of(p), (mid_x - 10, mid_x + 10, mid_z - 10, mid_z + 10))]
        if not tops:
            continue
        y = max(tops)
        if across_x:
            posts = [(x0 - GATE_POST, x0, mid_z - 100, mid_z + 100),
                     (x1, x1 + GATE_POST, mid_z - 100, mid_z + 100)]
            arch_r = (x0 - GATE_POST, x1 + GATE_POST, mid_z - 100, mid_z + 100)
        else:
            posts = [(mid_x - 100, mid_x + 100, z0 - GATE_POST, z0),
                     (mid_x - 100, mid_x + 100, z1, z1 + GATE_POST)]
            arch_r = (mid_x - 100, mid_x + 100, z0 - GATE_POST, z1 + GATE_POST)
        posts = [tuple(int(v) for v in r) for r in posts]
        if not all(P.flat_floor(r, y) for r in posts):
            continue
        if any(overlaps(r, c) for r in posts for c in P.hard):
            continue
        pieces = [kit.kind("box").make(tex, r[0], r[1], y, y + GATE_H, r[2], r[3], None,
                                       "dress.gate post") for r in posts]
        arch_r = tuple(int(v) for v in arch_r)
        pieces.append(kit.kind("arch").make(tex, arch_r[0], arch_r[1], y + GATE_H,
                                            y + GATE_H + ARCH_H, arch_r[2], arch_r[3], None,
                                            "dress.gate"))
        if P.add(pieces, "K4 gates"):
            n += 1
def rugs(L, P):
    lvl = _level(L, "slabs")
    if "slabs" in L.brief["features"]["want"]:
        lvl = max(lvl, 2)
    if lvl == 0 or "slabs" in L.brief["features"]["avoid"]:
        return
    acc = [t for t in L.pal.get("accents", []) if t not in (L.pal["floor"], L.pal.get("deck"))]
    if not acc:
        return
    for f in L.floors:
        if f["zone"] != "centre":
            continue
        x0, x1, z0, z1 = f["rect"]
        if x1 - x0 < 1600 or z1 - z0 < 1600:
            continue
        inset = 400
        r = (x0 + inset, x1 - inset, z0 + inset, z1 - inset)
        if not P.free(r) or not P.flat_floor(r, f["y"]):
            continue
        rug = kit.kind("box").make(acc[0], r[0], r[1], f["y"], f["y"] + RUG_T, r[2], r[3],
                                   None, "dress.rug")
        if P.add([rug], "K5 slabs", copy=f.get("copy", True)):
            break
def landmark_kit(L, P):
    body = [p for p in L.dress if p.get("tag") == "centre.landmark"]
    if not body:
        return
    body = body[0]
    lm = L.landmark or {}
    x0, x1, z0, z1 = rect_of(body)
    w = x1 - x0
    y = body["y"]
    rebuilt = []
    dais = (_level(L, "corners") >= 1 or "corners" in L.brief["features"]["want"]) and \
        "corners" not in L.brief["features"]["avoid"]
    del lm
    lift = DAIS_RISE if dais else 0
    if dais:
        R = DAIS_RUN
        strips = ((x0 - R, x1 + R, z0 - R, z0), (x0 - R, x1 + R, z1, z1 + R),
                  (x0 - R, x0, z0, z1), (x1, x1 + R, z0, z1))
        if not all(P.flat_floor(s, y) for s in strips):
            dais, lift = False, 0
    if dais:
        tex = L.pal.get("deck") or L.pal["floor"]
        st = kit.dress_tex(L.pal, "stair", L.pal.get("ramp") or tex)
        rebuilt.append(kit.kind("box").make(tex, x0, x1, y, y + DAIS_RISE, z0, z1, None,
                                            "centre.dais"))
        R = DAIS_RUN
        rebuilt += [
            kit.kind("stairs").make(st, x0, x1, y, y + DAIS_RISE, z0 - R, z0, "+z", "centre.dais"),
            kit.kind("stairs").make(st, x0, x1, y, y + DAIS_RISE, z1, z1 + R, "-z", "centre.dais"),
            kit.kind("stairs").make(st, x0 - R, x0, y, y + DAIS_RISE, z0, z1, "+x", "centre.dais"),
            kit.kind("stairs").make(st, x1, x1 + R, y, y + DAIS_RISE, z0, z1, "-x", "centre.dais"),
        ]
        for cx0, cz0, high in ((x0 - R, z0 - R, "+x+z"), (x1, z0 - R, "-x+z"),
                               (x0 - R, z1, "+x-z"), (x1, z1, "-x-z")):
            rebuilt.append(kit.kind("outerstairs").make(st, cx0, cx0 + R, y, y + DAIS_RISE,
                                                        cz0, cz0 + R, high, "centre.dais"))
    octagon = (_level(L, "diagonals") >= 1 or "diagonals" in L.brief["features"]["want"]) and \
        "diagonals" not in L.brief["features"]["avoid"] and w >= 400
    top = body["y"] + body["h"] + lift
    by = y + lift
    tex = body["tex"]
    if octagon:
        c = 200 if w >= 600 else 100
        if c:
            rebuilt.append(kit.kind("box").make(tex, x0 + c, x1 - c, by, top, z0, z1, None,
                                                "centre.landmark"))
            rebuilt.append(kit.kind("box").make(tex, x0, x0 + c, by, top, z0 + c, z1 - c, None,
                                                "centre.landmark"))
            rebuilt.append(kit.kind("box").make(tex, x1 - c, x1, by, top, z0 + c, z1 - c, None,
                                                "centre.landmark"))
            for px, pz, solid in ((x0, z0, "+x+z"), (x1 - c, z0, "-x+z"),
                                  (x0, z1 - c, "+x-z"), (x1 - c, z1 - c, "-x-z")):
                rebuilt.append(kit.kind("prism").make(tex, px, px + c, by, top, pz, pz + c,
                                                      solid, "centre.landmark"))
        else:
            octagon = False
    if not octagon:
        rebuilt.append(dict(body, y=by))
    if not dais and not octagon:
        return
    extra = len(rebuilt) - 1
    if extra > P.left:
        return
    out = []
    for p in L.dress:
        if p is body:
            out += rebuilt
        elif p.get("tag") in ("centre.landmark cap", "centre.landmark roof"):
            out.append(dict(p, y=p["y"] + lift))
        else:
            out.append(p)
    L.dress[:] = out
    P.left -= extra
    if dais:
        P.rules["K7 corner stairs (dais)"] = 9
    if octagon:
        P.rules["K6 diagonals (octagon)"] = 4
