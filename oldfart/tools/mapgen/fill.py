from . import kit
from .layout import grow, overlaps, rect_of
C = 200
STEP = 200
MODULES = {
    "crate":       ("crates", (1, 1), [(0, 1, 0, 1, 200, "crate")], "nsew", True),
    "crate_stack": ("crates", (2, 1), [(0, 2, 0, 1, 200, "crate"),
                                       (1, 2, 0, 1, 200, "crate", {"lift": 200})],
                    "nsew", True),
    "crate_pile":  ("crates", (2, 2), [(0, 2, 0, 1, 200, "crate"), (0, 1, 1, 2, 400, "crate")],
                    "nsew", True),
    "low_wall":    ("low_walls", (3, 1), [(0, 3, 0, 1, 250, "cover")], "ns", False),
    "wall":        ("low_walls", (4, 1), [(0, 4, 0, 1, 450, "cover")], "ns", False),
    "corner_wall": ("low_walls", (2, 2), [(0, 2, 0, 1, 450, "cover"), (0, 1, 1, 2, 450, "cover")],
                    "nsew", False),
    "column":      ("columns", (2, 2), [(0, 2, 0, 2, 700, "wall")], "nsew", False),
    "column_pair": ("columns", (5, 1), [(0, 1, 0, 1, 600, "wall"), (4, 5, 0, 1, 600, "wall")],
                    "ns", False),
    "bunker":      ("bunkers", (3, 3), [(0, 3, 0, 1, 450, "cover"), (0, 1, 1, 3, 450, "cover"),
                                        (2, 3, 1, 3, 450, "cover")], "s", False),
    "dais":        ("daises", (3, 3), [(0, 3, 0, 3, 200, "deck")], "nsew", True),
    "dais_high":   ("daises", (3, 4), [(0, 3, 0, 2, 400, "deck"), (0, 3, 2, 4, 200, "deck")],
                    "nsew", True),
}
KIT_MODULES = {
    "round_column": ("colonnades", (2, 2), [(0, 2, 0, 2, 700, "wall", {"kind": "pillar"})],
                     "nsew", False),
    "archway":      ("arches", (5, 1), [(0, 1, 0, 1, 500, "wall", {"kind": "pillar"}),
                                         (4, 5, 0, 1, 500, "wall", {"kind": "pillar"}),
                                         (0, 5, 0, 1, 200, "wall", {"kind": "arch", "lift": 500})],
                     "ns", False),
    "fence_run":    ("fences", (4, 1), [(0, 4, 0, 1, 160, "trim", {"kind": "rail"})], "ns", False),
    "stair_deck":   ("slabs", (3, 4), [(0, 3, 0, 2, 200, "deck"),
                                       (0, 3, 2, 4, 200, "ramp", {"kind": "stairs", "dir": "-z"})],
                     "nsew", True),
    "corner_deck":  ("corners", (4, 4), [(2, 4, 0, 2, 200, "deck"),
                                         (2, 4, 2, 4, 200, "ramp", {"kind": "stairs", "dir": "-z"}),
                                         (0, 2, 0, 2, 200, "ramp", {"kind": "stairs", "dir": "+x"}),
                                         (0, 2, 2, 4, 200, "ramp",
                                          {"kind": "outerstairs", "dir": "+x-z"})],
                     "nsew", True),
    "angled_block": ("diagonals", (6, 2), [(2, 4, 0, 2, 450, "cover"),
                                          (0, 2, 0, 2, 450, "cover", {"kind": "prism", "dir": "+x-z"}),
                                          (4, 6, 0, 2, 450, "cover", {"kind": "prism", "dir": "-x-z"})],
                     "s", False),
}
MODULES.update(KIT_MODULES)
MODULES.update({
    "rubble":   ("crates", (3, 2), [(0, 2, 0, 1, 200, "cover"), (1, 3, 1, 2, 200, "cover"),
                                    (2, 3, 0, 1, 400, "cover")], "nsew", True),
    "signpost": ("crates", (3, 1), [(0, 1, 0, 1, 600, "trim"),
                                    (1, 3, 0, 1, 200, "sign", {"lift": 400})], "ns", False),
})
PURPOSE = {
    "supply":   {"crate": 4.0, "crate_stack": 5.0, "crate_pile": 5.0, "*": 0.35},
    "choke":    {"rubble": 5.0, "low_wall": 2.5, "corner_wall": 2.5, "angled_block": 2.0,
                 "bunker": 2.0, "*": 0.4},
    "junction": {"signpost": 6.0, "column": 1.5, "round_column": 1.5, "*": 0.8},
    "route":    {"low_wall": 3.0, "crate_stack": 2.0, "corner_wall": 2.0, "rubble": 1.5,
                 "*": 0.3},
}
PURPOSE_ONLY = ("rubble", "signpost")
PURPOSE_MAX = {"signpost": 1}
def purpose_weight(name, purpose):
    table = PURPOSE.get(purpose)
    if table is None:
        return 0.0 if name in PURPOSE_ONLY else 1.0
    if name in table:
        return table[name]
    return 0.0 if name in PURPOSE_ONLY else table.get("*", 1.0)
FLAT_OK = ("crate", "low_wall", "dais", "fence_run", "stair_deck")
FLAT_H = 200
def _turn_cells(x0, x1, z0, z1, w, d, t):
    for _ in range(t % 4):
        x0, x1, z0, z1 = d - z1, d - z0, x0, x1
        w, d = d, w
    return x0, x1, z0, z1, w, d
SIDE_TURN = {"n": "e", "e": "s", "s": "w", "w": "n"}
def _turn_sides(sides, t):
    for _ in range(t % 4):
        sides = "".join(SIDE_TURN[s] for s in sides)
    return sides
def turn_dir(direction, t):
    if not direction:
        return direction
    dx = (1 if "+x" in direction else -1 if "-x" in direction else 0)
    dz = (1 if "+z" in direction else -1 if "-z" in direction else 0)
    for _ in range(t % 4):
        dx, dz = -dz, dx
    return (("+x" if dx > 0 else "-x" if dx < 0 else "") +
            ("+z" if dz > 0 else "-z" if dz < 0 else ""))
def shapes(name, flat=0):
    knob, (w, d), parts, sides, walk = MODULES[name]
    out = []
    seen = set()
    for t in range(4):
        ps = []
        for part in parts:
            (x0, x1, z0, z1, h, role) = part[:6]
            shape = dict(part[6]) if len(part) > 6 else None
            if shape and shape.get("dir"):
                shape["dir"] = turn_dir(shape["dir"], t)
            a = _turn_cells(x0, x1, z0, z1, w, d, t)
            row = (a[0], a[1], a[2], a[3], min(h, flat) if flat else h, role)
            ps.append(row + ((tuple(sorted(shape.items())),) if shape else ()))
        ww, dd = (w, d) if t % 2 == 0 else (d, w)
        key = tuple(sorted(ps))
        if key in seen:
            continue
        seen.add(key)
        out.append((ps, ww, dd, _turn_sides(sides, t)))
    return out
class Fill:
    def __init__(self, L):
        self.L = L
        self.sym = L.sym
        self.flat = L.brief["verticality"] == "flat"
        self.cap = (100 if L.brief["density"] == "sparse" else FLAT_H) if self.flat else 0
        self.solids = [(rect_of(p), p["y"], p["y"] + p["h"]) for p in L.structure + L.top]
        self.keeps = list(L.keeps)
        self.placed = []
        self.pieces = []
        self.groups = []
        self.log = []
        self.purposes = {}
    def floor_cells(self):
        out = []
        for fi, f in enumerate(self.L.floors):
            if f["zone"] in ("base", "lane"):
                continue
            x0, x1, z0, z1 = f["rect"]
            x = x0
            while x < x1:
                z = z0
                while z < z1:
                    out.append((fi, x + C / 2, z + C / 2, f["y"]))
                    z += C
                x += C
        return out
    def covered(self, cell, extra=()):
        _, x, z, y = cell
        box = (x - 300, x + 300, z - 300, z + 300)
        for (r, y0, y1) in self.solids:
            if y1 >= y + 100 and y0 <= y + 10 and overlaps(r, box):
                return True
        for (r, y0, y1) in extra:
            if y1 >= y + 100 and y0 <= y + 10 and overlaps(r, box):
                return True
        return False
    def fits(self, f, parts, w, d, sides, cx, cz, solids, keeps):
        y = f["y"]
        x0 = cx
        z0 = cz
        foot = (x0, x0 + w * C, z0, z0 + d * C)
        fr = f["rect"]
        if not (foot[0] >= fr[0] and foot[1] <= fr[1] and foot[2] >= fr[2]
                and foot[3] <= fr[3]):
            return None
        gaps = (foot[0] - fr[0], fr[1] - foot[1], foot[2] - fr[2], fr[3] - foot[3])
        if any(0 < gp < 2 * C for gp in gaps):
            return None
        if max(gaps[0], gaps[1]) < 2 * C or max(gaps[2], gaps[3]) < 2 * C:
            return None
        g = grow(foot, C)
        if any(overlaps(g, k) for k in keeps):
            return None
        for (r, y0, y1) in solids:
            if overlaps(g, r) and y1 > y + 10 and y0 < y + 900:
                return None
        for side in sides:
            if side == "n":
                st = (foot[0], foot[1], foot[2] - 2 * C, foot[2])
            elif side == "s":
                st = (foot[0], foot[1], foot[3], foot[3] + 2 * C)
            elif side == "w":
                st = (foot[0] - 2 * C, foot[0], foot[2], foot[3])
            else:
                st = (foot[1], foot[1] + 2 * C, foot[2], foot[3])
            for (r, y0, y1) in solids:
                if overlaps(st, r) and y1 > y + 10 and y0 < y + 900:
                    return None
        copies = self.sym.rects(foot)
        for i, a in enumerate(copies):
            for b in copies[i + 1:]:
                if overlaps(grow(a, 300), b):
                    return None
        support = getattr(self.L, "support", None)
        if support is not None:
            for c in copies[1:]:
                if not any(fy == y and c[0] >= r[0] and c[1] <= r[1] and c[2] >= r[2]
                           and c[3] <= r[3] for (r, fy) in support):
                    return None
                g2 = grow(c, C)
                if any(overlaps(g2, k) for k in self.keeps):
                    return None
                for (r, y0, y1) in self.solids:
                    if overlaps(g2, r) and y1 > y + 10 and y0 < y + 900:
                        return None
        rects, kinds = [], []
        for part in parts:
            (a0, a1, b0, b1, h, role) = part[:6]
            shape = dict(part[6]) if len(part) > 6 else None
            lift = shape.get("lift", 0) if shape else 0
            rects.append(((x0 + a0 * C, x0 + a1 * C, z0 + b0 * C, z0 + b1 * C), y + lift,
                          y + lift + h, role))
            kinds.append(shape)
        return foot, rects, kinds
    def options(self, budget_left):
        L = self.L
        d = L.dice
        r = L.streams("fill.options")
        opts = []
        names = [n for n in sorted(MODULES) if not self.flat or n in FLAT_OK]
        for n in names:
            knob = MODULES[n][0]
            weight = d.factor(knob) if d is not None else 1.0
            if n == "crate":
                weight *= 0.4
            if weight <= 0:
                continue
            n_parts = len(MODULES[n][2]) * self.sym.units
            if n_parts > budget_left:
                continue
            for parts, w, dd, sides in shapes(n, self.cap):
                for fi, f in enumerate(L.floors):
                    if not f["fill"] or f["zone"] in ("base", "lane"):
                        continue
                    pw = purpose_weight(n, f.get("purpose"))
                    if pw <= 0:
                        continue
                    x0, x1, z0, z1 = f["rect"]
                    area = grow(f["rect"], 1200)
                    solids = [t for t in self.solids if overlaps(t[0], area)]
                    keeps = [k for k in self.keeps if overlaps(k, area)]
                    n_cells = (x1 - x0) * (z1 - z0) / float(C * C)
                    step = C if n_cells <= 300 else (2 * C if n_cells <= 1200 else 3 * C)
                    cx = x0
                    while cx + w * C <= x1:
                        cz = z0
                        while cz + dd * C <= z1:
                            fit = self.fits(f, parts, w, dd, sides, cx, cz, solids, keeps)
                            if fit:
                                opts.append({"name": n, "floor": fi, "foot": fit[0],
                                             "rects": fit[1], "shapes": fit[2],
                                             "weight": weight * pw,
                                             "jitter": r.random(), "sides": sides})
                            cz += step
                        cx += step
        return opts
    def still_fits(self, o):
        g = grow(o["foot"], 2 * C)
        return not any(overlaps(g, p) for p in self.placed)
    def place(self, o):
        L = self.L
        group = []
        for (rect, y0, y1, role), shape in zip(o["rects"], o.get("shapes") or
                                               [None] * len(o["rects"])):
            tex = "crate" if role == "crate" and "crate" in kit.textures() else \
                L.pal.get(role if role != "crate" else "cover", L.pal["wall"])
            if role == "sign":
                tex = next((t for t in ("signboard", "signpainted") if t in kit.textures()),
                           L.pal.get("trim") or L.pal["wall"])
            if role == "trim" and "trim" not in L.pal:
                tex = L.pal.get("deck") or L.pal["wall"]
            kind = (shape.get("kind") or "box") if shape else "box"
            if kind == "rail":
                from .kitpass import fence_tex
                tex = fence_tex(L)
                if rect[1] - rect[0] >= rect[3] - rect[2]:
                    m = (rect[2] + rect[3]) // 2
                    rect = (rect[0], rect[1], m - 30, m + 30)
                else:
                    m = (rect[0] + rect[1]) // 2
                    rect = (m - 30, m + 30, rect[2], rect[3])
            p = kit.kind(kind).make(tex, rect[0], rect[1], y0, y1, rect[2], rect[3],
                                    shape.get("dir") if shape else None,
                                    "fill.%s" % o["name"])
            group += self.sym.pieces(p)
        self.placed += self.sym.rects(o["foot"])
        self.pieces += group
        self.groups.append(group)
        for p in group:
            self.solids.append((rect_of(p), p["y"], p["y"] + p["h"]))
        tall = max(y1 - y0 for (_, y0, y1, _) in o["rects"])
        f = L.floors[o["floor"]]
        fx0, fx1, fz0, fz1 = o["foot"]
        if tall >= 400:
            cx, cz = (fx0 + fx1) / 2.0, (fz0 + fz1) / 2.0
            if abs(cx) > abs(cz):
                sx = fx1 + 200 if cx > 0 else fx0 - 200
                sp = (sx, cz)
            else:
                sz = fz1 + 200 if cz > 0 else fz0 - 200
                sp = (cx, sz)
            fr = f["rect"]
            if fr[0] + 200 <= sp[0] <= fr[1] - 200 and fr[2] + 200 <= sp[1] <= fr[3] - 200:
                L.spot(int(sp[0] // 50 * 50), f["y"], int(sp[1] // 50 * 50), 0,
                       "lee of %s" % o["name"])
        if o["name"] in MODULES and MODULES[o["name"]][4]:
            top = max(y1 for (_, _, y1, _) in o["rects"])
            if top - f["y"] <= 200:
                cx, cz = (fx0 + fx1) / 2.0, (fz0 + fz1) / 2.0
                L.spot(int(cx // 50 * 50), top, int(cz // 50 * 50), 0,
                       "on %s" % o["name"])
def edge_cover(F, L, room):
    placed = 0
    if room <= 0:
        return 0
    hard = list(getattr(L, "clear", []))
    for bs in L.bases:
        hard += L.sym.rects(grow(bs["rect"], 400))
    for fi, f in enumerate(L.floors):
        if f["zone"] not in ("lane", "field") or not f.get("copy", True):
            continue
        x0, x1, z0, z1 = f["rect"]
        w, d = x1 - x0, z1 - z0
        if not (600 <= min(w, d) <= 1400 and max(w, d) >= 1600):
            continue
        along_x = w >= d
        y = f["y"]
        side = 0
        t = (x0 if along_x else z0) + 400
        end = (x1 if along_x else z1) - 800
        while t <= end:
            if (placed + 1) * F.sym.units > room:
                return placed
            for flip in (side, 1 - side):
                if along_x:
                    r = (int(t), int(t) + 2 * C, int(z0 if flip == 0 else z1 - C),
                         int(z0 + C if flip == 0 else z1))
                else:
                    r = (int(x0 if flip == 0 else x1 - C), int(x0 + C if flip == 0 else x1),
                         int(t), int(t) + 2 * C)
                g = grow(r, C)
                if any(overlaps(grow(r, 2 * C), o) for o in L.edges_open):
                    continue
                if any(overlaps(r, h) for h in hard):
                    continue
                if any(overlaps(g, rr) and y1 > y + 10 and y0 < y + 900
                       for (rr, y0, y1) in F.solids):
                    continue
                copies = F.sym.rects(r)
                if any(overlaps(grow(a, 300), b) for i, a in enumerate(copies)
                       for b in copies[i + 1:]):
                    continue
                if any(overlaps(grow(c, C), p) for c in copies for p in F.placed):
                    continue
                F.place({"name": "lane_wall", "floor": fi, "foot": r,
                         "rects": [(r, y, y + (F.cap if F.flat else 250), "cover")],
                         "shapes": [None]})
                placed += 1
                side = 1 - flip
                break
            t += 800
    return placed
def target_cover(L):
    dials = L.brief.get("dials") or {}
    if "openness" in dials:
        return round(0.82 - 0.52 * float(dials["openness"]), 3)
    if "density" in dials:
        return round(0.35 + 0.47 * float(dials["density"]), 3)
    dens = L.brief["density"]
    t = {"sparse": 0.5, "medium": 0.68, "dense": 0.76}[dens]
    if L.dice is not None:
        t += (-0.06, -0.02, 0.0, 0.04)[L.dice["cover"]]
    return max(0.3, min(0.8, t))
def run(L, max_backtracks=12):
    from .layout import compile_pieces
    F = Fill(L)
    budget = L.brief["budget"]
    try:
        n_struct = L.fixed_count if getattr(L, "fixed_count", None) else len(compile_pieces(L))
    except Exception:
        n_struct = len(L.structure) + len(L.top)
    reserve = 2 * max(1, len(L.bases)) * L.sym.units + int(0.15 * budget)
    budget_left = max(0, int(0.95 * budget) - n_struct - reserve)
    cells_all = F.floor_cells()
    target = target_cover(L)
    if not cells_all or budget_left <= 0:
        L.report["fill"] = {"modules": 0, "target": target, "reached": None,
                            "why": "no fillable floor" if not cells_all else "piece budget"}
        return
    from . import outposts
    budget_left -= outposts.run(F, L, budget_left // 2)
    opts = F.options(budget_left)
    for i, o in enumerate(opts):
        o["i"] = i
    r = L.streams("fill")
    banned = set()
    backtracks = 0
    n_cells = float(len(cells_all))
    covered = [F.covered(c) for c in cells_all]
    by_floor = {}
    for ci, c in enumerate(cells_all):
        by_floor.setdefault(c[0], []).append(ci)
    def near(ci, rects):
        _, x, z, y = cells_all[ci]
        box = (x - 300, x + 300, z - 300, z + 300)
        return any(y1 >= y + 100 and y0 <= y + 10 and overlaps(rr, box)
                   for (rr, y0, y1, _) in rects)
    at = {}
    for ci, c in enumerate(cells_all):
        at.setdefault((int(c[1] // C), int(c[2] // C)), []).append(ci)
    def reach(rects):
        out = set()
        for (rr, y0, y1, _) in rects:
            i0, i1 = int((rr[0] - 300) // C) - 1, int((rr[1] + 300) // C) + 1
            k0, k1 = int((rr[2] - 300) // C) - 1, int((rr[3] + 300) // C) + 1
            for i in range(i0, i1 + 1):
                for k in range(k0, k1 + 1):
                    for ci in at.get((i, k), ()):
                        if near(ci, [(rr, y0, y1, None)]):
                            out.add(ci)
        return out
    def cover_of(o):
        if "cells" not in o:
            o["cells"] = reach(o["rects"])
        return o["cells"]
    def floor_cov(fi):
        cs = by_floor[fi]
        return sum(1 for ci in cs if covered[ci]) / float(len(cs))
    start = sum(covered) / n_cells
    cov = start
    per_floor_count = {}
    steps = 0
    stop = "target reached"
    while cov < target and steps < 80:
        steps += 1
        room = budget_left - len(F.pieces)
        live = [o for o in opts if o["i"] not in banned and o["floor"] in by_floor
                and len(o["rects"]) * F.sym.units <= room and F.still_fits(o)
                and per_floor_count.get((o["floor"], o["name"]), 0)
                < PURPOSE_MAX.get(o["name"], 10 ** 6)]
        if not live:
            stop = "no option left" if room > 0 else "piece budget"
            break
        per_floor = {}
        for o in live:
            per_floor.setdefault(o["floor"], []).append(o)
        fcov = {fi: floor_cov(fi) for fi in per_floor}
        fi = min(per_floor, key=lambda k: (fcov[k] >= target, fcov[k], len(per_floor[k]), k))
        cands = per_floor[fi]
        scored = []
        for o in cands:
            gain = sum(1 for ci in cover_of(o) if not covered[ci] and cells_all[ci][0] == fi)
            if gain <= 0:
                continue
            scored.append((o["weight"] * (gain + 0.5) * (0.6 + 0.8 * o["jitter"]), o))
        if not scored:
            banned.update(o["i"] for o in cands)
            continue
        total = sum(sc for sc, _ in scored)
        x = r.random() * total
        pick = scored[-1][1]
        for sc, o in scored:
            x -= sc
            if x < 0:
                pick = o
                break
        snapshot = (len(F.pieces), len(F.groups), len(F.placed), len(F.solids), len(L.spots))
        F.place(pick)
        dead = False
        for fj, opts_j in per_floor.items():
            if fj == fi or fcov[fj] >= 0.3:
                continue
            if not any(F.still_fits(o) for o in opts_j):
                dead = True
                break
        if dead and backtracks < max_backtracks:
            backtracks += 1
            del F.pieces[snapshot[0]:]
            del F.groups[snapshot[1]:]
            del F.placed[snapshot[2]:]
            del F.solids[snapshot[3]:]
            del L.spots[snapshot[4]:]
            banned.add(pick["i"])
            continue
        F.log.append(pick["name"])
        per_floor_count[(pick["floor"], pick["name"])] = \
            per_floor_count.get((pick["floor"], pick["name"]), 0) + 1
        purp = L.floors[pick["floor"]].get("purpose")
        if purp:
            F.purposes.setdefault(purp, {})
            F.purposes[purp][pick["name"]] = F.purposes[purp].get(pick["name"], 0) + 1
        for ci in cover_of(pick):
            covered[ci] = True
        cov = sum(covered) / n_cells
    edge = edge_cover(F, L, budget_left - len(F.pieces)) if target >= 0.6 else 0
    L.fill = F.pieces
    L.fill_groups = F.groups
    counts = {}
    for n in F.log:
        counts[n] = counts.get(n, 0) + 1
    L.report["fill"] = {"modules": len(F.log), "kinds": counts, "pieces": len(F.pieces),
                        "target": round(target, 2), "before": round(start, 3),
                        "reached": round(cov, 3), "options": len(opts),
                        "backtracks": backtracks, "budget_left": budget_left,
                        "lane_walls": edge, "purposes": F.purposes,
                        "stop": stop if cov < target else "target reached", "steps": steps}
