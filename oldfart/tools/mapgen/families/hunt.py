from .. import boundary, kit, movement, v1
from ..paths import common, shape
from ..paths.road import q, compile_pieces
FAMILY = "hide"
DEFAULTS = {"symmetry": "none", "verticality": "medium", "density": "dense",
            "edge": "walled"}
MODES = ["rabbitchase", "hideballoon", "copsandrobbers"]
CELL = 400
WALL = 1200
PERCH = 400
RAMP_CELLS = 2
RING_H, QUARTER_H, AVENUE_H = 0, 50, 100
ACROSS = {"tiny": 6400, "small": 8000, "medium": 9600, "large": 11200, "huge": 12800,
          "gigantic": 20000}
MAX_CELLS = {"gigantic": 50}
REGION_KINDS = ("blocks", "maze", "garden", "court")
HOUSE_SIZES = ((3, 3), (3, 4), (4, 3), (4, 4))
FORCE_PLAN = None
import os as _os
SPAWN_FIELD = _os.environ.get("MAPGEN_SPAWN_FIELD", "1") == "1"
def across_for(brief):
    size = brief["size"]
    if isinstance(size, dict):
        from ..brief import across_units
        a = across_units(size, ACROSS["medium"])
    else:
        a = ACROSS["gigantic" if size == "gigantic" else common.size_name(size)]
    a *= (0.75 + 0.25 * brief["players"] / 16.0)
    n = int(round(a / CELL / 2.0)) * 2
    return max(16, min(MAX_CELLS.get(size, 34) if isinstance(size, str) else 34, n))
class Ground:
    def __init__(self, n):
        self.n = n
        self.solid = {}
        self.ramp = {}
        self.perch = {}
        self.ramps = []
        self.region = {}
        self.base = {}
        self.houses = []
        self.hills = {}
        self.hill_ramps = {}
        self.wet = set()
        self.road_cells = set()
        self.prefabs = []
        self.prefabs_laid = set()
    def h(self, c):
        return self.base.get(c, RING_H) + 200 * self.hills.get(c, 0)
    def inside(self, c):
        return 0 <= c[0] < self.n and 0 <= c[1] < self.n
    def floor(self, c):
        return self.inside(c) and c not in self.solid and c not in self.perch
    def walk(self, c):
        return self.floor(c)
    def free(self, c):
        return self.floor(c) and c not in self.ramp
def _clear_of(g, cells, gap=1):
    for (i, j) in cells:
        for di in range(-gap, gap + 1):
            for dj in range(-gap, gap + 1):
                c = (i + di, j + dj)
                if c in cells:
                    continue
                if c in g.solid or c in g.perch or c in g.ramp:
                    return False
    return True
def region_border(g, box, r, tex, gates=2):
    x0, x1, z0, z1 = box
    sides = [[(i, z0) for i in range(x0, x1)], [(i, z1 - 1) for i in range(x0, x1)],
             [(x0, j) for j in range(z0, z1)], [(x1 - 1, j) for j in range(z0, z1)]]
    for side in sides:
        inner = side[2:-2]
        open_ = set(r.sample(inner, min(gates, len(inner)))) if inner else set()
        for c in side:
            if c not in open_ and g.free(c):
                g.solid[c] = (600, tex, "hedge")
    return (x0 + 1, x1 - 1, z0 + 1, z1 - 1)
def region_hills(g, box, r, brief, seed):
    from .. import terrain
    from ..brief import dna
    x0, x1, z0, z1 = box
    cells = [(i, j) for i in range(x0, x1) for j in range(z0, z1) if g.free((i, j))]
    if len(cells) < 16:
        return 0
    h = terrain.heightfield(cells, "%s/hills/%d/%d" % (seed, x0, z0), layers=3)
    want = brief["features"]["want"]
    wet = []
    if "river" in want or dna(brief, "nature") >= 0.8:
        wet = terrain.river(h)
        for c in wet:
            h[c] = 0
        terrain.smooth(h, keep=wet)
    road = []
    if "roads" in want or dna(brief, "nature") >= 0.6:
        a = min(cells, key=lambda c: (c[0] + c[1], c))
        b = max(cells, key=lambda c: (c[0] + c[1], c))
        road = terrain.road(h, a, b, wet)
    ramps = terrain.ramps_for(h, set(cells) - set(wet))
    for c, layer in h.items():
        if layer:
            g.hills[c] = layer
    for c, d in ramps.items():
        g.hill_ramps[c] = d
        g.ramp[c] = -1
    g.wet |= set(wet)
    for c in set(wet) | set(road):
        g.ramp.setdefault(c, -2)
    g.road_cells |= set(road)
    return len(cells)
def region_village(g, box, r, tex, brief, pal):
    from .. import houses, prefablib
    x0, x1, z0, z1 = box
    placed = []
    tries = 0
    for key in [k for k in (brief.get("prefabs") or []) if k not in g.prefabs_laid]:
        pf = prefablib.find(key)
        if pf is None:
            continue
        w, d = prefablib.size(pf, 0)
        n = max(-(-w // CELL), -(-d // CELL))
        for _ in range(40):
            i = r.randint(x0 + 1, max(x0 + 1, x1 - n - 1))
            j = r.randint(z0 + 1, max(z0 + 1, z1 - n - 1))
            cells = set((i + a, j + b) for a in range(n) for b in range(n))
            if not all(x0 <= c[0] < x1 and z0 <= c[1] < z1 and g.free(c) for c in cells):
                continue
            if not _clear_of(g, cells):
                continue
            for c in cells:
                g.solid[c] = (houses.STOREY, tex, "prefab")
            turn = prefablib.door_turn(pf, "+z" if j < (z0 + z1) // 2 else "-z")
            g.prefabs.append({"key": pf["key"], "cell": (i, j), "turn": turn,
                              "cells": sorted(cells)})
            g.prefabs_laid.add(pf["key"])
            break
    from .. import settlements
    del placed, tries
    return settlements.plan_quarter(g, box, r, brief, pal, tex)
def region_ruins(g, box, r, tex):
    from .. import pcg
    x0, x1, z0, z1 = box
    free = [(i, j) for i in range(x0, x1) for j in range(z0, z1) if g.free((i, j))]
    walls = pcg.ca_caves(free, r, fill=0.52, steps=2)
    n = 0
    for c in sorted(walls):
        if g.free(c):
            g.solid[c] = (r.choice((600, 800, 800, 1000)), tex, "ruin")
            n += 1
    return n
def region_blocks(g, box, r, tex, dense):
    x0, x1, z0, z1 = box
    placed = 0
    tries = 0
    want = {"sparse": 6, "medium": 10, "dense": 14}[dense] * (x1 - x0) * (z1 - z0) // 100
    while placed < want and tries < 400:
        tries += 1
        w, d = r.choice(((1, 2), (2, 1), (2, 2), (2, 3), (3, 2), (1, 3), (3, 1)))
        i = r.randint(x0, x1 - w)
        j = r.randint(z0, z1 - d)
        cells = set((i + a, j + b) for a in range(w) for b in range(d))
        if not all(g.inside(c) and g.free(c) for c in cells) or not _clear_of(g, cells):
            continue
        h = r.choice((600, 800, 800, 1000))
        for c in cells:
            g.solid[c] = (h, tex, "block")
        placed += 1
    return placed
def region_maze(g, box, r, tex):
    x0, x1, z0, z1 = box
    rooms = [(i, j) for i in range(x0, x1, 2) for j in range(z0, z1, 2)]
    rs = set(rooms)
    walls = set()
    for i in range(x0, x1):
        for j in range(z0, z1):
            if (i - x0) % 2 == 1 or (j - z0) % 2 == 1:
                walls.add((i, j))
    start = r.choice(rooms)
    seen, stack = {start}, [start]
    links = set()
    while stack:
        cur = stack[-1]
        nb = [(cur[0] + dx, cur[1] + dz) for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2))
              if (cur[0] + dx, cur[1] + dz) in rs and (cur[0] + dx, cur[1] + dz) not in seen]
        if not nb:
            stack.pop()
            continue
        nxt = r.choice(nb)
        mid = ((cur[0] + nxt[0]) // 2, (cur[1] + nxt[1]) // 2)
        walls.discard(mid)
        links.add(mid)
        seen.add(nxt)
        stack.append(nxt)
    for room in rooms:
        exits = [((room[0] + dx // 2), (room[1] + dz // 2)) for dx, dz in
                 ((2, 0), (-2, 0), (0, 2), (0, -2))]
        open_ = [m for m in exits if m not in walls and x0 <= m[0] < x1 and z0 <= m[1] < z1]
        edge_open = [m for m in exits if not (x0 <= m[0] < x1 and z0 <= m[1] < z1)]
        if len(open_) + len(edge_open) <= 1:
            shut = [m for m in exits if m in walls]
            if shut:
                walls.discard(r.choice(shut))
    for c in walls:
        if g.inside(c) and g.free(c):
            g.solid[c] = (800, tex, "maze")
def region_garden(g, box, r, tex):
    x0, x1, z0, z1 = box
    along_x = r.random() < 0.5
    rng_a = range(x0, x1) if along_x else range(z0, z1)
    rng_b = range(z0 + 1, z1, 2) if along_x else range(x0 + 1, x1, 2)
    for b in rng_b:
        row = list(rng_a)
        gaps = set(r.sample(row, min(len(row), r.choice((2, 2, 3)))))
        for a in row:
            if a in gaps:
                continue
            c = (a, b) if along_x else (b, a)
            if g.free(c):
                g.solid[c] = (600, tex, "hedge")
def region_court(g, box, r, tex, pal, pid):
    x0, x1, z0, z1 = box
    ci, cj = (x0 + x1) // 2 - 1, (z0 + z1) // 2 - 1
    perch = [(ci, cj), (ci + 1, cj), (ci, cj + 1), (ci + 1, cj + 1)]
    if not all(g.free(c) for c in perch):
        return False
    d = r.choice(shape.DIRS)
    ramps = []
    for dd in (d, (-d[0], -d[1])):
        k3 = range(RAMP_CELLS)
        if dd == (1, 0):
            cells, rises = [(ci + 2 + k, cj) for k in k3], "-x"
        elif dd == (-1, 0):
            cells, rises = [(ci - 1 - k, cj + 1) for k in k3], "+x"
        elif dd == (0, 1):
            cells, rises = [(ci, cj + 2 + k) for k in k3], "-z"
        else:
            cells, rises = [(ci + 1, cj - 1 - k) for k in k3], "+z"
        if not all(g.free(c) for c in cells):
            return False
        ramps.append((cells, rises))
    for c in perch:
        g.perch[c] = pid
    for cells, rises in ramps:
        for c in cells:
            g.ramp[c] = pid
        g.ramps.append((cells, rises, pid))
    cells = [c for cs, _ in ramps for c in cs]
    ring = []
    for i in range(ci - 2, ci + 4):
        for j in (cj - 2, cj + 3):
            ring.append((i, j))
    for j in range(cj - 1, cj + 3):
        for i in (ci - 2, ci + 3):
            ring.append((i, j))
    for k, c in enumerate(sorted(ring)):
        if k % 2 == 0 and g.free(c) and _clear_of(g, {c}) and all(
                abs(c[0] - rc[0]) + abs(c[1] - rc[1]) > 1 for rc in cells):
            g.solid[c] = (1000, tex, "pillar")
    return True
def lane_breakers(g, n, mid, every=3):
    placed = 0
    lanes = [((0, 1), "x"), ((n - 2, n - 1), "x"), ((0, 1), "z"), ((n - 2, n - 1), "z"),
             ((mid - 1, mid), "x"), ((mid - 1, mid), "z")]
    for (a, b), axis in lanes:
        side = 0
        for t in range(4, n - 4):
            if abs(t - mid) <= 1 or abs(t - (mid - 1)) <= 1 or t % every:
                continue
            row = (a, b)[side]
            c = (t, row) if axis == "x" else (row, t)
            other = (t, (a, b)[1 - side]) if axis == "x" else ((a, b)[1 - side], t)
            if g.free(c) and g.free(other):
                g.solid[c] = (800, g.breaker_tex, "breaker")
                placed += 1
            side = 1 - side
    return placed
def hide_mazes(g, maze_boxes):
    if not maze_boxes:
        return 0
    cells = set()
    for (x0, x1, z0, z1) in maze_boxes:
        for i in range(x0, x1):
            for j in range(z0, z1):
                cells.add((i, j))
    for c in [c for c, v in g.solid.items() if v[2] == "breaker"]:
        if not any(max(abs(c[0] - a), abs(c[1] - b)) <= 2 for a, b in cells):
            continue
        tops = []
        for a in range(-2, 3):
            for b in range(-2, 3):
                n = (c[0] + a, c[1] + b)
                if n in cells or n == c or not g.inside(n):
                    continue
                if g.floor(n):
                    tops.append(g.h(n))
                elif n in g.solid and g.solid[n][2] != "breaker":
                    tops.append(g.h(n) + g.solid[n][0])
                elif n in g.perch:
                    tops.append(g.h(n) + PERCH)
        need = (max(tops) if tops else g.h(c)) + movement.REACH + 1 - g.h(c)
        h0, tex, kind = g.solid[c]
        g.solid[c] = (max(h0, int(-(-need // 200) * 200)), tex, kind)
    tallest = 0
    for c in cells:
        if c not in g.solid:
            continue
        near = [g.h((c[0] + a, c[1] + b)) for a in range(-2, 3) for b in range(-2, 3)
                if g.floor((c[0] + a, c[1] + b))]
        need = (max(near) if near else g.h(c)) + movement.REACH + 1 - g.h(c)
        tallest = max(tallest, need)
    h = int(-(-tallest // 200) * 200)
    for c in cells:
        if c in g.solid and g.solid[c][2] not in ("house", "prefab"):
            _, tex, _k = g.solid[c]
            g.solid[c] = (max(h, g.solid[c][0]), tex, "maze")
    return h
def fix_dead_ends(g):
    changed = True
    filled = 0
    while changed:
        changed = False
        for i in range(g.n):
            for j in range(g.n):
                c = (i, j)
                if not g.free(c):
                    continue
                ways = sum(1 for nb in shape.neighbours(c) if g.floor(nb))
                if ways <= 1:
                    reg = g.region.get(c)
                    g.solid[c] = (600, g.region_tex.get(reg, "stone1"), "fill")
                    filled += 1
                    changed = True
    return filled
def solid_components(g):
    seen = set()
    out = []
    for c in sorted(g.solid):
        if c in seen:
            continue
        comp, todo = {c}, [c]
        seen.add(c)
        while todo:
            u = todo.pop()
            for v in shape.neighbours(u):
                if v in g.solid and v not in seen:
                    seen.add(v)
                    comp.add(v)
                    todo.append(v)
        out.append(comp)
    return out
def cut_windows(g, r, limit=4000):
    cut = 0
    for _ in range(60):
        long = [comp for comp in solid_components(g)
                if shape.perimeter(comp) * CELL > limit
                and not any(g.solid[c][2] in ("maze", "hedge", "house") for c in comp)]
        if not long:
            break
        comp = long[0]
        thin = [c for c in sorted(comp)
                if sum(1 for nb in shape.neighbours(c) if nb in comp) == 2 and
                ((c[0] - 1, c[1]) in comp) == ((c[0] + 1, c[1]) in comp)]
        if not thin:
            thin = sorted(comp)
        c = r.choice(thin)
        del g.solid[c]
        cut += 1
    return cut
def connected_floor(g):
    cells = [c for c in ((i, j) for i in range(g.n) for j in range(g.n))
             if g.floor(c) or c in g.ramp]
    if not cells:
        return False
    s = set(cells)
    seen, todo = {cells[0]}, [cells[0]]
    while todo:
        u = todo.pop()
        for v in shape.neighbours(u):
            if v in s and v not in seen:
                seen.add(v)
                todo.append(v)
    return len(seen) == len(s)
def spread(cells, k, r, first=None):
    cells = sorted(cells)
    if not cells:
        return []
    out = [first if first in cells else r.choice(cells)]
    d = {c: abs(c[0] - out[0][0]) + abs(c[1] - out[0][1]) for c in cells}
    while len(out) < min(k, len(cells)):
        c = max(cells, key=lambda x: (d[x], x))
        out.append(c)
        for x in cells:
            d[x] = min(d[x], abs(x[0] - c[0]) + abs(x[1] - c[1]))
    return out
def build(brief, streams, reference=False):
    if "rooms" in brief["features"]["want"]:
        from .. import rooms
        return rooms.build_family(brief, streams)
    if brief["size"] == "gigantic":
        from . import explore
        return getattr(explore.build, "__wrapped__", explore.build)(brief, streams, reference)
    notes = []
    r = streams("ground")
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    level = brief["level"]
    info = common.level_info(level)
    lift = 10 if info["floor"] is not None else 0
    n = across_for(brief)
    half_units = n * CELL // 2
    if half_units + 400 > info["half"]:
        n = int((info["half"] - 600) * 2 // CELL // 2 * 2)
        half_units = n * CELL // 2
        notes.append("size: clamped to %d across (the level's edge)" % (n * CELL))
    g = Ground(n)
    from .. import contract
    theme = common.theme_of(brief)
    g.breaker_tex = pal.get("hedge") or pal["cover"]
    mid = n // 2
    boxes = [(2, mid - 1, 2, mid - 1), (mid + 1, n - 2, 2, mid - 1),
             (2, mid - 1, mid + 1, n - 2), (mid + 1, n - 2, mid + 1, n - 2)]
    for i in range(n):
        for j in range(n):
            c = (i, j)
            if i in (0, 1, n - 2, n - 1) or j in (0, 1, n - 2, n - 1):
                g.base[c] = RING_H
            elif i in (mid - 1, mid) or j in (mid - 1, mid):
                g.base[c] = AVENUE_H
            else:
                g.base[c] = QUARTER_H
    from ..brief import dna as _dna
    breakers = lane_breakers(g, n, mid, every=5 if _dna(brief, "complexity") >= 0.6 else 3)
    want, avoid = common.want_avoid(brief)
    kinds = list(REGION_KINDS)
    r.shuffle(kinds)
    if "maze" in avoid:
        kinds = [k for k in kinds if k != "maze"] + ["blocks"]
    courts = 2 if "perches" not in avoid and "vantage" not in avoid else 0
    order = [k for k in kinds if k != "court"]
    from ..brief import dna
    villages = 0
    if "buildings" not in avoid:
        cx = dna(brief, "complexity")
        villages = 2 if ("buildings" in want or cx >= 0.75) else (1 if cx >= 0.6 else 0)
    hills = 0
    if "terrain" in want or "river" in want or dna(brief, "nature") >= 0.6:
        if "terrain" not in avoid:
            hills = 1
    if brief.get("prefabs") and "buildings" not in avoid:
        villages = max(villages, 1)
    if dna(brief, "age") >= 0.6 and "ruins" not in order:
        order = ["ruins"] + [k for k in order if k != "maze"]
    if villages >= 2:
        order = [k for k in order if k not in ("maze", "garden")] + ["blocks"]
    if hills:
        order = [k for k in order if k not in ("maze",)]
    plan = ["court"] * courts + ["village"] * villages + ["hills"] * hills + order
    plan = plan[:4]
    while len(plan) < 4:
        plan.append("blocks")
    r.shuffle(plan)
    if FORCE_PLAN:
        plan = list(FORCE_PLAN)
    accents = list(pal["accents"])
    g.region_tex = {}
    floors = [pal["floor"], pal["pad"], pal["accents"][3 % len(accents)], pal["road"]]
    built = list(pal.get("accents_built") or accents)
    hedges = contract.variants(theme, "hedge", pal, ("hedge",), 4)
    walls = contract.variants(theme, "building_wall", pal, ("building", "wall"), 4)
    g.hedge_tex, g.house_tex = {}, {}
    for qi, box in enumerate(boxes):
        for i in range(box[0], box[1]):
            for j in range(box[2], box[3]):
                g.region[(i, j)] = qi
        g.region_tex[qi] = built[qi % len(built)]
        g.hedge_tex[qi] = hedges[qi % len(hedges)] if hedges else g.breaker_tex
        g.house_tex[qi] = walls[qi % len(walls)] if walls else pal["wall"]
    g.region_tex[None] = pal["wall"]
    perches = 0
    regions = []
    for qi, (kind, box) in enumerate(zip(plan, boxes)):
        tex = g.region_tex[qi]
        htex = g.hedge_tex[qi]
        if kind in ("village", "hills"):
            box = (box[0] + 1, box[1] - 1, box[2] + 1, box[3] - 1)
        else:
            box = region_border(g, box, r, pal["wall"] if kind != "garden" else htex)
        if kind == "court":
            if region_court(g, box, r, tex, pal, perches):
                perches += 1
            else:
                kind = "blocks"
            region_blocks(g, box, r, tex, "sparse")
        elif kind == "hills":
            if not region_hills(g, box, r, brief, brief["seed"]):
                kind = "blocks"
                region_blocks(g, box, r, tex, "sparse")
        elif kind == "village":
            if not region_village(g, box, r, tex, brief, pal):
                kind = "blocks"
                region_blocks(g, box, r, tex, "sparse")
        elif kind == "maze":
            region_maze(g, box, r, htex)
        elif kind == "ruins":
            worn = "mossyrock" if "mossyrock" in kit.textures() else tex
            region_ruins(g, box, r, worn)
        elif kind == "garden":
            region_garden(g, box, r, htex)
        else:
            region_blocks(g, box, r, tex, brief["density"])
        regions.append(kind)
    windows = cut_windows(g, r)
    filled = fix_dead_ends(g)
    windows += cut_windows(g, r)
    filled += fix_dead_ends(g)
    maze_h = hide_mazes(g, [b for b, k in zip(boxes, regions) if k == "maze"])
    if maze_h:
        notes.append("maze walls %d tall: over a player's reach (%d, one move with a ledge "
                     "grab) from every floor beside them"
                     % (maze_h, movement.REACH))
    if not connected_floor(g):
        notes.append("the floor came apart; the fill was undone")
    off = -half_units
    def make_raw():
        box_k, ramp_k = kit.kind("box"), kit.kind("ramp")
        raw = []
        for qi, bx in enumerate(boxes):
            x0, x1 = off + bx[0] * CELL, off + bx[1] * CELL
            z0, z1 = off + bx[2] * CELL, off + bx[3] * CELL
            raw.append(box_k.make(floors[qi % len(floors)], x0, x1, lift + QUARTER_H - 200,
                                  lift + QUARTER_H, z0, z1, None, "floor.%d" % qi))
        for (x0, x1, z0, z1) in ((0, n, 0, 2), (0, n, n - 2, n), (0, 2, 2, n - 2),
                                 (n - 2, n, 2, n - 2)):
            raw.append(box_k.make(pal["road"], off + x0 * CELL, off + x1 * CELL, lift - 200,
                                  lift + RING_H, off + z0 * CELL, off + z1 * CELL, None, "lane"))
        for (x0, x1, z0, z1) in ((2, n - 2, mid - 1, mid + 1), (mid - 1, mid + 1, 2, mid - 1),
                                 (mid - 1, mid + 1, mid + 1, n - 2)):
            raw.append(box_k.make(pal["pad"], off + x0 * CELL, off + x1 * CELL, lift + AVENUE_H - 200,
                                  lift + AVENUE_H, off + z0 * CELL, off + z1 * CELL, None, "avenue"))
        from .. import prefablib
        qh = lift + QUARTER_H
        earth = pal.get("keel") or pal["wall"]
        top_tex = pal["floor"]
        for (i, j), layer in sorted(g.hills.items()):
            for k in range(1, layer + 1):
                raw.append(box_k.make(top_tex if k == layer else earth, off + i * CELL,
                                      off + (i + 1) * CELL, qh + 200 * (k - 1), qh + 200 * k,
                                      off + j * CELL, off + (j + 1) * CELL, None, "hills"))
        for (i, j), d in sorted(g.hill_ramps.items()):
            b0 = qh + 200 * g.hills.get((i, j), 0)
            raw.append(ramp_k.make(pal.get("ramp", pal["road"]), off + i * CELL, off + (i + 1) * CELL, b0,
                                   b0 + 200, off + j * CELL, off + (j + 1) * CELL, d,
                                   "hills.ramp"))
        bed = {"ice": "ice", "desert": "sand", "lava": "frostedrock"}.get(brief["theme"], "ice")
        for (i, j) in sorted(g.wet):
            t0 = qh + 200 * g.hills.get((i, j), 0)
            raw.append(box_k.make(bed, off + i * CELL, off + (i + 1) * CELL, t0, t0 + 20,
                                  off + j * CELL, off + (j + 1) * CELL, None, "hills.river"))
        for (i, j) in sorted(g.road_cells - g.wet - set(g.hill_ramps)):
            t0 = qh + 200 * g.hills.get((i, j), 0)
            raw.append(box_k.make(pal["road"], off + i * CELL, off + (i + 1) * CELL, t0, t0 + 20,
                                  off + j * CELL, off + (j + 1) * CELL, None, "hills.road"))
        for pf in g.prefabs:
            got = prefablib.find(pf["key"])
            if got is not None:
                i, j = pf["cell"]
                pp, _ = prefablib.lay(got, off + i * CELL, off + j * CELL, lift + g.h((i, j)),
                                      pf["turn"], brief["theme"] if brief["theme"] != "auto"
                                      else "garden")
                raw += pp
        for (i, j), (h, tex, kind) in sorted(g.solid.items()):
            if kind in ("house", "prefab"):
                continue
            b0 = lift + g.h((i, j))
            raw.append(box_k.make(tex, off + i * CELL, off + (i + 1) * CELL, b0, b0 + h,
                                  off + j * CELL, off + (j + 1) * CELL, None, kind))
        for (i, j), pid in sorted(g.perch.items()):
            b0 = lift + g.h((i, j))
            raw.append(box_k.make(pal["pad"], off + i * CELL, off + (i + 1) * CELL, b0,
                                  b0 + PERCH, off + j * CELL, off + (j + 1) * CELL, None, "perch"))
        for cells, rises, pid in g.ramps:
            xs = [c[0] for c in cells]
            zs = [c[1] for c in cells]
            b0 = lift + g.h(cells[0])
            raw.append(ramp_k.make(pal["road"], off + min(xs) * CELL, off + (max(xs) + 1) * CELL,
                                   b0, b0 + PERCH, off + min(zs) * CELL, off + (max(zs) + 1) * CELL,
                                   rises, "perch.ramp"))
        a, b = off - 200, off + n * CELL + 200
        rects = ((a, b, a, off), (a, b, off + n * CELL, b), (a, off, off, off + n * CELL),
                 (off + n * CELL, b, off, off + n * CELL))
        raw += boundary.walls(box_k.make, edge_mode[0], rects, lift - 200, lift + RING_H,
                              lift + WALL, pal["wall"], "wall", top=boundary.top_of(raw))
        return raw
    budget = brief["budget"]
    edge_mode = ["invisible"]
    def assemble():
        from .. import settlements
        m = v1.arenas_module()
        hs = settlements.quarter_pieces(g, lambda i: off + i * CELL,
                                        lambda c: lift + g.h(c))
        for p in hs:
            p["model"] = m.model_name(p)
        return compile_pieces(make_raw()) + hs
    def compile_with(mode):
        edge_mode[0] = mode
        return assemble()
    edge_mode[0], pieces = boundary.choose(brief, compile_with, budget)
    thinned = 0
    while len(pieces) > budget:
        comps = [c for c in solid_components(g)
                 if all(g.solid[x][2] in ("block", "pillar", "ruin") for x in c)]
        if not comps:
            break
        for comp in r.sample(comps, min(len(comps), max(1, (len(pieces) - budget) // 2))):
            for x in comp:
                del g.solid[x]
            thinned += 1
        pieces = assemble()
    dropped_houses = 0
    while len(pieces) > budget and g.houses:
        hs = g.houses.pop()
        for c in hs["cells"]:
            g.solid.pop(c, None)
        dropped_houses += 1
        pieces = assemble()
    if dropped_houses:
        notes.append("budget: %d houses left out" % dropped_houses)
    flattened = 0
    while len(pieces) > budget and (g.hills or g.road_cells):
        top = max(g.hills.values()) if g.hills else 0
        if top > 1:
            for c in [c for c, v in g.hills.items() if v == top]:
                g.hills[c] = top - 1
            g.hill_ramps = {c: d for c, d in g.hill_ramps.items()
                            if g.hills.get(c, 0) < top - 1}
        elif g.road_cells:
            g.road_cells = set()
        else:
            g.hills, g.hill_ramps = {}, {}
        flattened += 1
        pieces = assemble()
    if flattened:
        notes.append("budget: the hills flattened %d step(s)" % flattened)
    if thinned:
        notes.append("budget: %d loop blocks left out" % thinned)
    ground = [c for c in ((i, j) for i in range(n) for j in range(n)) if g.free(c)]
    if SPAWN_FIELD:
        from .. import pcg
        picks = pcg.farthest_points(ground, 28, r, first=(0, 0))
    else:
        picks = spread(ground, 28, r, first=(0, 0))
    m = v1.arenas_module()
    def spot(c):
        x = off + c[0] * CELL + CELL // 2
        z = off + c[1] * CELL + CELL // 2
        import math
        yaw = int(round(math.degrees(math.atan2(-x, -z)) / 90.0)) * 90 % 360
        return {"x": x, "y": lift + g.h(c), "z": z, "yaw": yaw}
    spots = [spot(c) for c in picks]
    spawns = spots[:16]
    points = list(spots)
    del m
    lines = []
    for a_ in brief["anchors"]:
        if a_["what"] in ("vantage", "tower", "perch") and perches:
            lines.append(("approximated", a_["id"], "a perch stands in a court region; its "
                          "quadrant is the dice's"))
        else:
            lines.append(("not yet", a_["id"], "a hide map places %s from milestone 3"
                          % a_["what"]))
    arena = {"key": brief["key"] or "generated", "level": level, "budget": budget,
             "pieces": pieces, "spawns": spawns, "survey": {"points": points},
             "look": kit.look(brief["theme"] if brief["theme"] != "auto" else "garden",
                              brief["sky"], brief["music"]),
             "onlyFor": list(MODES),
             "blurb": "a generated hiding ground for sixteen",
             "note": "a walled ground %d across in four quarters (%s), %d perches, lanes round "
                     "every block" % (n * CELL, ", ".join(regions), perches)}
    notes.append("edge: %s" % boundary.describe(edge_mode[0]))
    if len(pieces) > budget:
        notes.append("%d pieces against a budget of %d" % (len(pieces), budget))
    params = common.compat_params(n * CELL, {
        "shape": "walled ground", "lane": "lanes %d" % CELL, "corner": "%d perches" % perches,
        "cells": n, "regions": regions, "perches": perches, "windows": windows,
        "filled": filled, "solid_cells": len(g.solid), "houses": len(g.houses),
        "boundary": edge_mode[0]})
    missing = [k for k in (brief.get("prefabs") or []) if k not in g.prefabs_laid]
    meta = {"params": params, "modules": {"regions": regions, "perches": perches,
                                          "prefabs": [p["key"] for p in g.prefabs]},
            "not_possible": ["prefabs %s: no village quarter with room for them (try a "
                             "larger size)" % ", ".join(missing)] if missing else [],
            "anchors": lines, "notes": notes, "graph_faults": [], "centre": (0, 0),
            "bases": [], "module_pieces": {}, "field_spots": len(points) - 16, "cover": 0,
            "graph": {"zones": ["region%d" % i for i in range(4)], "loops": ["ring"]}}
    return arena, meta
