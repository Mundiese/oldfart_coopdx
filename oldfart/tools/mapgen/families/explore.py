import json
import math
from .. import boundary, kit, pcg, v1
from ..paths import common
from ..paths.road import compile_pieces
FAMILY = "explore"
DEFAULTS = {"symmetry": "none", "verticality": "medium", "density": "medium",
            "edge": "walled", "level": "empty", "theme": "garden"}
MODES = []
HIDE_MODES = ["rabbitchase", "hideballoon", "copsandrobbers"]
CELL = 400
ACROSS = {"tiny": 8000, "small": 10000, "medium": 14000, "large": 18000, "huge": 22000,
          "gigantic": 99999}
DISTRICT_CELLS = 180
KINDS = ("village", "hills", "forest", "ruins", "garden", "lake", "plaza")
WALL_H = 1200
WATER_DROP = 40
GAMEPLAY_ROOM = 24
TREE_H, CROWN = 600, 600
TREES_KEPT = 8
POOL_DEPTH = 190
POND_RAISE = 400
def across_for(brief, info):
    size = brief["size"]
    if isinstance(size, dict):
        from ..brief import across_units
        a = across_units(size, ACROSS["medium"])
    else:
        a = ACROSS.get(size, ACROSS["medium"])
    edge = 2 * (info["half"] - 600)
    a = min(a, edge)
    n = int(a // CELL // 2 * 2)
    return max(16, n)
def _weights(brief):
    from ..brief import dna
    c, n, a, e = (dna(brief, k) for k in ("complexity", "nature", "age", "exploration"))
    want, avoid = common.want_avoid(brief)
    w = {"village": 1 + 3 * c, "hills": 0.5 + 3 * n, "forest": 0.5 + 2.5 * n,
         "ruins": 0.3 + 3 * a, "garden": 0.5 + e, "lake": 0.3 + 1.5 * n, "plaza": 0.6}
    plain = dict(w)
    if "buildings" in want or brief.get("prefabs"):
        w["village"] *= 3
    if "terrain" in want:
        w["hills"] *= 3
    if want & {"mountains", "caves", "valley"}:
        w["hills"] *= 4
    if "water" in want:
        w["lake"] *= 4
    elif "river" in want:
        w["lake"] *= 1.5
    if brief.get("family") == "hide":
        for k, f in (("village", 2.5), ("ruins", 2.5), ("garden", 2.0), ("forest", 1.5),
                     ("hills", 0.3), ("lake", 0.3)):
            w[k] *= f
    am = brief.get("amounts") or {}
    for k, words in (("village", ("buildings",)), ("hills", ("terrain",)),
                     ("lake", ("water", "river")), ("forest", ("trees",))):
        how = [am.get(x) for x in words if am.get(x)]
        low = [AMOUNT_FACTOR[h] for h in how if AMOUNT_FACTOR.get(h, 1) < 1]
        high = [AMOUNT_FACTOR[h] for h in how if AMOUNT_FACTOR.get(h, 1) > 1]
        if low:
            w[k] = plain[k] * min(low)
        elif high:
            w[k] *= max(high)
        if any(x in avoid for x in words):
            w[k] = 0
    prof = theme_world(brief)
    for k, f in prof["kinds"].items():
        w[k] = w.get(k, 0) * f
    if "lava" in want:
        w["lake"] = max(w["lake"], 1.0) * 3
    return w
THEME_WORLDS = {
    "lava": {"kinds": {"forest": 0, "garden": 0, "village": 0.4, "ruins": 1.6, "hills": 1.6,
                       "lake": 1.5}, "trees": False, "liquid": "lava", "rock": "basaltrough"},
    "ice": {"kinds": {"forest": 0.5, "garden": 0.3, "lake": 1.3}, "trees": True,
            "liquid": "water", "rock": "frostedrock"},
    "desert": {"kinds": {"forest": 0.15, "garden": 0.3, "ruins": 1.5, "hills": 1.3},
               "trees": True, "liquid": "water", "rock": "sandblock"},
    "sky": {"kinds": {"forest": 0.6, "lake": 0.6, "plaza": 1.5}, "trees": True,
            "liquid": "water", "rock": "whitestonebrick"},
    "castle": {"kinds": {"village": 2.0, "ruins": 1.5, "forest": 0.4, "garden": 1.2},
               "trees": True, "liquid": "water", "rock": "greystone"},
    "wood": {"kinds": {"forest": 1.6, "village": 1.3}, "trees": True, "liquid": "water",
             "rock": "dirt"},
    "garden": {"kinds": {}, "trees": True, "liquid": "water", "rock": "mossyrock"},
}
def theme_world(brief):
    t = brief.get("theme") if brief.get("theme") not in (None, "auto") else "garden"
    return THEME_WORLDS.get(t, THEME_WORLDS["garden"])
EXPLORE_BUILDS = {"terrain", "mountains", "valley", "river", "caves", "water", "water_levels",
                  "lava", "volcano", "buildings", "trees", "roads", "tower", "walls", "plaza",
                  "fences", "slabs", "stairs", "ramps", "gate", "arches", "pillars", "columns",
                  "nooks", "loops", "lanes", "islands", "jumps", "tunnel", "moving_platforms",
                  "corners", "curves", "diagonals",
                  "terraces", "weirs", "landmarks", "lighthouse", "obelisk", "watchtower",
                  "temple", "bridge",
                  "mesa", "natural_arch", "waterfall", "dunes", "glacier", "rolling_hills",
                  "windmill", "belltower", "keep", "ruin", "statue", "pyramid", "spirerock",
                  "fountain", "shrine", "greattree", "marketsquare", "fortress", "domedhall",
                  "well", "shipwreck", "courtyard"}
LATE_FEATURES = ("lanterns", "glowing_mushrooms", "crystals", "dark")
AMOUNT_LESS = 0.5
AMOUNT_MORE = 2.5
AMOUNT_FACTOR = {"trace": 0.12, "few": 0.3, "less": AMOUNT_LESS, "more": AMOUNT_MORE,
                 "lots": 4.0}
TREE_SHARE = {"trace": 0.08, "few": 0.18, "less": 0.3, "more": 1.0, "lots": 1.0}
def tree_share(brief):
    how = (brief.get("amounts") or {}).get("trees")
    return TREE_SHARE.get(how, 1.0)
def _pick(r, w):
    total = sum(w.values())
    x = r.random() * total
    for k in sorted(w):
        x -= w[k]
        if x < 0:
            return k
    return sorted(w)[-1]
class World:
    def __init__(self, n):
        self.n = n
        self.solid = {}
        self.hills = {}
        self.ramps = {}
        self.road = set()
        self.lake = set()
        self.waters = []
        self.prefabs = []
        self.prefabs_laid = set()
        self.trees = []
        self.houses = []
        self.spires = []
        self.owner = {}
        self.streets = set()
        self.river = set()
        self.valley = []
        self.caves = []
        self.macro = {}
        self.top_tex = {}
        self.craters = []
        self.volcano = None
        self.base = {}
        self.plinth = {}
        self.river_level = {}
        self.weirs = []
        self.bridges = set()
        self.cuts = {}
        self.roofs = {}
        self.landmarks = []
        self.shapes = {}
        self.road_info = []
        self.lowered = set()
        self.preset = None
        self.bands = []
        self.clefts = {}
        self.sites = []
        self.biome = {}
        self.biome_tex = {}
        self.tree_kind = {}
        self.landforms = []
        self.rolling = set()
        self.meander = None
        self.rocks = []
        self.settlements = []
        self.footpath = {}
        self.basin = {}
        self.banded_hills = False
        self.peaks = []
        self.flank = set()
    def T(self, c):
        if c in self.cuts:
            return self.cuts[c]
        return self.base.get(c, 0) + self.hills.get(c, 0)
    def flat(self, cells):
        hs = set(self.T(c) for c in cells)
        return len(hs) <= 1
    def total(self):
        return {(i, j): self.T((i, j)) for i in range(self.n) for j in range(self.n)}
    def free(self, c):
        return (0 <= c[0] < self.n and 0 <= c[1] < self.n and c not in self.solid
                and c not in self.road and c not in self.streets and c not in self.lake
                and c not in self.ramps and c not in self.river and c not in self.cuts
                and c not in self.footpath and c not in self.flank)
def _line(a, b, first_x=True):
    (i0, j0), (i1, j1) = a, b
    out = []
    if first_x:
        for i in range(min(i0, i1), max(i0, i1) + 1):
            out.append((i, j0))
        for j in range(min(j0, j1), max(j0, j1) + 1):
            out.append((i1, j))
    else:
        for j in range(min(j0, j1), max(j0, j1) + 1):
            out.append((i0, j))
        for i in range(min(i0, i1), max(i0, i1) + 1):
            out.append((i, j1))
    return out
def _street_side(W, foot):
    i0 = min(c[0] for c in foot)
    i1 = max(c[0] for c in foot)
    j0 = min(c[1] for c in foot)
    j1 = max(c[1] for c in foot)
    best = None
    for face, cells in (("-x", [(i0 - k, j) for k in range(1, 6) for j in range(j0, j1 + 1)]),
                        ("+x", [(i1 + k, j) for k in range(1, 6) for j in range(j0, j1 + 1)]),
                        ("-z", [(i, j0 - k) for k in range(1, 6) for i in range(i0, i1 + 1)]),
                        ("+z", [(i, j1 + k) for k in range(1, 6) for i in range(i0, i1 + 1)])):
        for k, c in enumerate(cells):
            if c in W.streets or c in W.road:
                d = k // max(1, (len(cells) // 5))
                if best is None or d < best[0]:
                    best = (d, face)
                break
    return best[1] if best else "+z"
def district_prefabs(W, cells, r, keys):
    from .. import prefablib
    cs = set(cells)
    laid = []
    for key in keys:
        pf = prefablib.find(key)
        if pf is None:
            continue
        w, d = prefablib.size(pf, 0)
        ci, cj = -(-w // CELL), -(-d // CELL)
        for _ in range(60):
            c0 = cells[int(r.random() * len(cells))]
            foot = [(c0[0] + a, c0[1] + b) for a in range(max(ci, cj)) for b in range(max(ci, cj))]
            ring = [(c[0] + di, c[1] + dj) for c in foot for di in (-1, 0, 1) for dj in (-1, 0, 1)]
            if not all(c in cs and W.free(c) for c in foot) or not W.flat(foot):
                continue
            if any(x in W.solid for x in ring):
                continue
            turn = prefablib.door_turn(pf, _street_side(W, foot))
            for c in foot:
                W.solid[c] = (0, None, "prefab")
            W.prefabs.append({"key": pf["key"], "cell": c0, "turn": turn, "cells": foot})
            laid.append(pf["key"])
            break
    return laid
def district_village(W, cells, r, brief, tex, pal=None, site=None, district=None, villages=1):
    from .. import settlements
    placed = 0
    wished = [k for k in (brief.get("prefabs") or []) if k not in W.prefabs_laid]
    for key in district_prefabs(W, cells, r, wished):
        W.prefabs_laid.add(key)
        placed += 1
    if site is None:
        site = cells[len(cells) // 2]
    placed += settlements.plan_explore(W, cells, r, brief, pal or {}, site, district,
                                       settlements.allotment(brief, villages,
                                                             len(W.settlements)))
    return placed
def landmark_pal(W, pal, theme):
    from .. import soft64
    b = soft64.buildings(theme) or {}
    out = {"wall": pal.get("wall"), "trim": pal.get("trim") or pal.get("wall"),
           "road": pal.get("road") or pal.get("wall"),
           "deck": pal.get("deck") or pal.get("pad"), "roof": pal.get("roof"),
           "accent": (pal.get("accents_built") or [None])[0], "awning": pal.get("awning"),
           "door": b.get("door"), "door_top": (b.get("door") + "top")
           if b.get("door") and (b.get("door") + "top") in kit.textures() else b.get("door"),
           "path": pal.get("path") or pal.get("road"), "leaves": pal.get("foliage")}
    if theme_world({"theme": theme})["liquid"] == "lava":
        rock = theme_world({"theme": theme})["rock"]
        if rock in kit.textures():
            out["wall"] = rock
    return out
MOUNTAIN_LAYERS = 7
MESH_GROUND = True
GROUND_STEPS = ("slopes", "terrace_once", "terraces", "hills", "hills_all")
STRUCTURE_LINE = {"gigantic": 560}
STRUCTURE_ROOM = 80
def structure_line(brief):
    if not MESH_GROUND:
        return None
    size = brief.get("size")
    return STRUCTURE_LINE.get(size) if isinstance(size, str) else None
def line_thin(thin):
    return tuple(s_ for s_ in thin if s_ != "road")
def budget_count(pieces):
    if not MESH_GROUND:
        return len(pieces)
    from .. import heightfield
    return sum(1 for p in pieces if not heightfield.is_terrain(p))
MOUNTAIN_LAYERS_MESH = 10
HILL_LAYERS, HILL_LAYERS_MESH = 3, 3
MOUNTAIN_GRADE = 2.5
MOUNTAIN_TOP = {"tiny": 6, "small": 10, "medium": 15, "large": 22, "huge": 24,
                "gigantic": 24}
MOUNTAIN_AUTO = {"small": 1, "medium": 1, "large": 1, "huge": 2, "gigantic": 2}
MOUNTAIN_CELLS = 40
LEDGE = 1.5
LEDGE_WALL = 3
FLIGHT_MAX = 2
FLIGHT_TURN = 4.0
POCKET_MOST = 30
BROAD_SIZES = ("gigantic",)
BROAD_HILLS = 2
BROAD_GRADE = 0.45
BROAD_LAYERS = 8
BROAD_PLATEAUS = 4
BROAD_MOUNTAINS = 1
BROAD_VILLAGES = 3
def broad_relief(brief):
    return MESH_GROUND and brief.get("family") == "explore" and \
        brief.get("size") in BROAD_SIZES
def pockets(T, free, burning=(), most=POCKET_MOST):
    out = []
    seen = set()
    for c0 in sorted(free):
        if c0 in seen or c0 not in T or c0 in burning:
            continue
        h = T[c0]
        comp, todo = {c0}, [c0]
        seen.add(c0)
        rim = set()
        while todo:
            c = todo.pop()
            for a, b in pcg.N4:
                n = (c[0] + a, c[1] + b)
                if n in comp:
                    continue
                if n in free and n not in burning and T.get(n) == h:
                    comp.add(n)
                    seen.add(n)
                    todo.append(n)
                else:
                    rim.add(n)
        if len(comp) > most:
            continue
        ups = []
        trapped = True
        for n in rim:
            if n in burning or n not in T:
                continue
            if T[n] >= h + 2:
                ups.append(T[n])
            else:
                trapped = False
                break
        if trapped and ups:
            out.append((comp, min(ups)))
    return out
def design_mountain(free, seed, top, entry=None, grade=MOUNTAIN_GRADE, level=None):
    from .. import terrain
    fs = set(free)
    rim = [c for c in free if any((c[0] + a, c[1] + b) not in fs for a, b in pcg.N4)]
    if not rim or len(fs) < MOUNTAIN_CELLS:
        return None
    dist = terrain.chamfer(fs, rim)
    cone = {}
    for c in free:
        d = dist.get(c, 0.0)
        wear = 0.85 + 0.3 * terrain.fbm(c[0] * 0.3, c[1] * 0.3, "%s/cone" % seed)
        cone[c] = 0.0 if d <= 0 else 1.0 + (d - 1.0) * grade * wear
    middle = max(free, key=lambda c: (dist.get(c, 0), c))
    if entry is None:
        entry = middle
    def climb(start, spin):
        path, layer = [start], [0]
        seen = {start}
        back = next(((-a, -b) for a, b in pcg.N4 if (start[0] - a, start[1] - b) not in fs
                     and level is not None and level((start[0] - a, start[1] - b)) == 0),
                    None)
        run = 0
        while layer[-1] < top:
            cur = path[-1]
            din = (cur[0] - path[-2][0], cur[1] - path[-2][1]) if len(path) > 1 else back
            best = None
            recent = set(path[-2:])
            for a, b in pcg.N4:
                n = (cur[0] + a, cur[1] + b)
                want = layer[-1] + (1 if (a, b) == din else 0)
                if n not in fs or n in seen or cone[n] < want - LEDGE:
                    continue
                if any((n[0] + p, n[1] + q) in seen and (n[0] + p, n[1] + q) not in recent
                       for p, q in pcg.N8):
                    continue
                score = 0.6 * abs(cone[n] - want - 0.5)
                rx, rz = cur[0] - middle[0], cur[1] - middle[1]
                cross = rx * b - rz * a
                if cross * spin <= 0 and (rx or rz):
                    score += 1.2
                if (a, b) != din:
                    score += 1.5
                elif run >= FLIGHT_MAX:
                    score += FLIGHT_TURN
                if best is None or (score, n) < best:
                    best = (score, n, want)
            if best is None:
                break
            run = run + 1 if best[2] > layer[-1] else 0
            path.append(best[1])
            layer.append(best[2])
            seen.add(best[1])
        return path, layer
    feet = sorted(rim, key=lambda c: ((c[0] - entry[0]) ** 2 + (c[1] - entry[1]) ** 2, c))
    step_ = max(1, len(feet) // 12)
    path, layer = [], []
    for k, foot in enumerate(feet[::step_][:12]):
        for spin in (1, -1):
            got, lay = climb(foot, spin)
            if lay[-1] > (layer[-1] if layer else -1):
                path, layer = got, lay
    seen = set(path)
    K = layer[-1] if layer else 0
    if K < 4:
        return None
    h = {}
    for c in free:
        h[c] = min(K, int(round(cone[c])))
    summit = set(c for c in free if cone[c] >= K - 0.5 and c not in seen) | {path[-1]}
    for c in summit:
        h[c] = K
    for c, v in zip(path, layer):
        h[c] = v
    for c, v in zip(path, layer):
        for a, b in pcg.N8:
            n = (c[0] + a, c[1] + b)
            if n not in fs or n in seen:
                continue
            if h[n] > v + LEDGE_WALL:
                h[n] = v + LEDGE_WALL
                summit.discard(n)
            if (a, b) not in pcg.N4 or n in summit:
                continue
            if dist.get(n, 0) > dist.get(c, 0):
                h[n] = max(h[n], min(K, v + 2))
    for c, v in zip(path, layer):
        for a, b in pcg.N4:
            n = (c[0] + a, c[1] + b)
            if n in fs and n not in seen and n not in summit and \
                    dist.get(n, 0) < dist.get(c, 0):
                h[n] = v
    step = {(1, 0): "+x", (-1, 0): "-x", (0, 1): "+z", (0, -1): "-z"}
    ramps = {}
    for a, b, la, lb in zip(path, path[1:], layer, layer[1:]):
        if lb == la + 1:
            ramps[a] = step[(b[0] - a[0], b[1] - a[1])]
    flank = set(c for c in free if h[c] > 0 and c not in seen and c not in summit)
    return h, ramps, path, summit, flank
def choose_peaks(W, brief, sites, edges, mid, mountainous, avoid, notes):
    size_name = brief["size"] if isinstance(brief["size"], str) else "large"
    want = MOUNTAIN_AUTO.get(size_name, 0) + (1 if mountainous else 0)
    if broad_relief(brief):
        want = min(want, BROAD_MOUNTAINS)
    if not MESH_GROUND or brief["family"] != "explore" or not want or \
            avoid & {"mountains", "terrain"}:
        return set(), edges
    own = {}
    for c, d in W.owner.items():
        if c not in W.streets:
            own.setdefault(d, set()).add(c)
    wet = set(W.valley) | set(W.river)
    hi = W.macro or {}
    from .. import terrain
    room = {}
    for i, cs in own.items():
        rim = [c for c in cs if any((c[0] + a, c[1] + b) not in cs for a, b in pcg.N4)]
        room[i] = max(terrain.chamfer(cs, rim).values() or [0])
    cand = sorted((i for i in own if i != mid and len(own[i]) >= MOUNTAIN_CELLS + 30
                   and not (own[i] & wet)),
                  key=lambda i: (-round(room[i]), -hi.get(sites[i], 0), -len(own[i]), i))
    peaks = set()
    for i in cand:
        if len(peaks) >= want:
            break
        rest = [e for e in edges if i not in e and not (set(e) & peaks)]
        nodes = set(k for k in range(len(sites)) if k != i and k not in peaks)
        if nodes and _connected(nodes, rest):
            peaks.add(i)
    kept = [e for e in edges if not (set(e) & peaks)]
    for i in sorted(peaks):
        notes.append("mountains: district %d stands a mountain (no road across it: its path "
                     "climbs it)" % i)
    return peaks, kept
HOUSES_KEPT = 5
PEAK_LEAVES = 0.6
PEAK_LEAVES_VILLAGE = 0.9
VILLAGE_KEEP_SIZES = ("medium", "large", "huge", "gigantic")
PEAK_LEAVES_LANDMARK = 0.75
PEAK_REACH = {"small": 6.0, "medium": 10.5, "large": 11.0, "huge": 12.0, "gigantic": 13.0}
def grow_peaks(W, brief, sites, peaks, mid, n, notes):
    size_name = brief["size"] if isinstance(brief["size"], str) else "large"
    reach = PEAK_REACH.get(size_name)
    if not reach or not peaks:
        return
    wet = set(W.valley) | set(W.river) | set(W.lake)
    edge = set(c for c in W.streets if c[0] in (0, 1, n - 2, n - 1) or c[1] in (0, 1, n - 2, n - 1))
    want = common.want_avoid(brief)[0]
    villaged = bool(want & {"buildings", "village"}) or brief.get("preset") == "village"
    from .. import landmarks as _landmarks
    marked = bool(want & set(_landmarks.FEATURE_KIND))
    for i in sorted(peaks):
        lo, hi = reach + 2, n - reach - 3
        si = (min(hi, max(lo, sites[i][0])), min(hi, max(lo, sites[i][1])))
        took = 0
        own = {}
        for c, d in W.owner.items():
            if c not in W.streets:
                own[d] = own.get(d, 0) + 1
        lost = {}
        leaves = PEAK_LEAVES_VILLAGE if villaged and size_name in VILLAGE_KEEP_SIZES \
            else PEAK_LEAVES_LANDMARK if marked else PEAK_LEAVES
        near = sorted((c for c in W.owner
                       if math.hypot(c[0] - si[0], c[1] - si[1]) <= reach and
                       math.hypot(c[0] - sites[i][0], c[1] - sites[i][1]) <= 2 * reach),
                      key=lambda c: (math.hypot(c[0] - si[0], c[1] - si[1]), c))
        for c in near:
            d = W.owner[c]
            if d == i or d == mid or d in peaks or c in wet or c in edge:
                continue
            if any(c == sites[j] for j in range(len(sites))):
                continue
            if c not in W.streets and lost.get(d, 0) >= (1.0 - leaves) * own.get(d, 0):
                continue
            W.owner[c] = i
            took += 1
            if c not in W.streets:
                lost[d] = lost.get(d, 0) + 1
        inner = [c for c in W.streets if c not in edge and W.owner.get(c) == i
                 and all(W.owner.get((c[0] + a, c[1] + b)) == i for a, b in pcg.N8)]
        for c in inner:
            W.streets.discard(c)
        if took:
            notes.append("mountains: district %d took %d cells round its site for its mountain"
                         % (i, took))
def _connected(nodes, edges):
    nodes = set(nodes)
    if not nodes:
        return True
    adj = {}
    for a, b in edges:
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    start = min(nodes)
    seen, todo = {start}, [start]
    while todo:
        k = todo.pop()
        for m in adj.get(k, ()):
            if m in nodes and m not in seen:
                seen.add(m)
                todo.append(m)
    return seen == nodes
def district_hills(W, cells, r, seed, mountains=False, top=None, entry=None, broad=False):
    from .. import terrain
    free = [c for c in cells if W.free(c)]
    if len(free) < 16:
        return 0
    if MESH_GROUND and mountains and top:
        low = min(W.base.get(c, 0) for c in free)
        got = design_mountain(free, "%s/mountain/%d/%d" % (seed, free[0][0], free[0][1]), top,
                              entry, level=lambda c: W.T(c) - low if 0 <= c[0] < W.n
                              and 0 <= c[1] < W.n and c not in W.river else None)
        if got is not None:
            h, ramps, path, summit, flank = got
            for c, d in ramps.items():
                W.ramps[c] = d
            low = min(W.base.get(c, 0) for c in free)
            for c, v in h.items():
                v = low + v - W.base.get(c, 0)
                if v > 0:
                    W.hills[c] = v
            W.peaks.append({"path": path, "summit": summit, "flank": flank,
                            "cells": set(free)})
            W.flank |= flank
            return len(free)
    if MESH_GROUND and broad:
        fs = set(free)
        rim = [c for c in free if any((c[0] + di, c[1] + dj) not in fs for di, dj in pcg.N4)]
        dist = terrain.chamfer(fs, rim)
        wear = terrain.heightfield(free, "%s/explore-hills/%d/%d" % (seed, free[0][0],
                                                                      free[0][1]),
                                   layers=5, scale=0.05)
        h = {}
        for c in free:
            k_ = 0.75 + 0.5 * wear.get(c, 0) / 4.0
            h[c] = 0 if c in rim else min(BROAD_LAYERS, int(dist.get(c, 0) * BROAD_GRADE * k_))
        terrain.smooth(h, n8=True)
        for c, v in h.items():
            if v:
                W.hills[c] = v
        return len(free)
    if MESH_GROUND:
        layers = MOUNTAIN_LAYERS_MESH if mountains else HILL_LAYERS_MESH
    else:
        layers = MOUNTAIN_LAYERS if mountains else HILL_LAYERS
    h = terrain.heightfield(free, "%s/explore-hills/%d/%d" % (seed, free[0][0], free[0][1]),
                            layers=layers, scale=0.05 if mountains else 0.07)
    fs = set(free)
    if mountains:
        rim = [c for c in free if any((c[0] + di, c[1] + dj) not in fs for di, dj in pcg.N4)]
        if MESH_GROUND:
            dist = terrain.chamfer(fs, rim)
            for c in free:
                h[c] = min(layers - 1, int(dist.get(c, 0) * (1.0 + 0.5 * h[c]
                                                             / max(1, layers - 1))))
        else:
            dist = {c: 0 for c in rim}
            todo = list(rim)
            while todo:
                nxt = []
                for c in todo:
                    for di, dj in pcg.N4:
                        m = (c[0] + di, c[1] + dj)
                        if m in fs and m not in dist:
                            dist[m] = dist[c] + 1
                            nxt.append(m)
                todo = nxt
            for c in free:
                h[c] = min(layers - 1, int(dist.get(c, 0) * (1.0 + 0.5 * h[c]
                                                             / max(1, layers - 1))))
    for c in free:
        if any((c[0] + di, c[1] + dj) not in fs for di, dj in pcg.N4):
            h[c] = 0
    terrain.smooth(h, n8=MESH_GROUND and not mountains)
    ramps = terrain.climb_ramps(h, fs) if mountains else {}
    if MESH_GROUND and mountains:
        from .. import landscape
        landscape.band_hills(h, landscape.HILL_RISER, keep=landscape.climb_cells(ramps))
        W.banded_hills = True
    elif len(getattr(W, "bands", ()) or ()) > 1 and not MESH_GROUND:
        from .. import landscape
        landscape.band_hills(h, landscape.HILL_RISER, keep=landscape.climb_cells(ramps))
    for c, d in ramps.items():
        W.ramps[c] = d
    for c, v in h.items():
        if v:
            W.hills[c] = v
    return len(free)
def district_forest(W, cells, r, biome=None, site=None):
    from .. import flora, landscape
    free = [c for c in cells if W.free(c)]
    b = landscape.BIOMES.get(biome or "forest") or landscape.BIOMES["forest"]
    inner = b["inner"] or [("oak", 1)]
    edge = b["edge"] or inner
    clearing = set()
    hero = None
    if site is not None and len(free) >= 25:
        site = tuple(site)
        mid = min(free, key=lambda c: (abs(c[0] - site[0]) + abs(c[1] - site[1]), c))
        clearing = set((mid[0] + a, mid[1] + d) for a in (-1, 0, 1) for d in (-1, 0, 1))
        hero = mid
    got = flora.forest(free, r, inner, edge, limit=max(3, len(free) // 6), clearing=clearing)
    for c, sp in got:
        if W.free(c):
            W.solid[c] = (flora.height_of(sp), None, "tree")
            W.trees.append(c)
            W.tree_kind[c] = sp
    if hero is not None and W.free(hero):
        sp = "broadleaf" if biome not in ("taiga", "alpine") else "megapine"
        W.solid[hero] = (flora.height_of(sp), None, "tree")
        W.trees.append(hero)
        W.tree_kind[hero] = sp
    return len(got)
def district_ruins(W, cells, r, tex):
    inner = [c for c in cells if W.free(c)]
    walls = pcg.ca_caves(inner, r, fill=0.42, steps=3)
    n = 0
    for c in sorted(walls):
        if W.free(c):
            W.solid[c] = (r.choice((400, 600, 800)), tex, "ruin")
            n += 1
    return n
def district_garden(W, cells, r, tex):
    free = set(c for c in cells if W.free(c))
    if not free:
        return 0
    i0 = min(c[0] for c in free)
    n = 0
    for c in sorted(free):
        if (c[0] - i0) % 3 == 0 and r.random() < 0.85:
            W.solid[c] = (600, tex, "hedge")
            n += 1
    return n
def district_lake(W, cells, centre, smallest=2):
    cs = set(c for c in cells if W.free(c) or (c in W.road and c not in W.solid))
    near = sorted(cs, key=lambda c: (abs(c[0] - centre[0]) + abs(c[1] - centre[1]), c))
    for at in [centre] + [c for c in near[:40] if c != centre]:
        best = None
        for rx in range(6, smallest - 1, -1):
            for rz in range(6, smallest - 1, -1):
                box = [(at[0] + a, at[1] + b) for a in range(-rx, rx + 1)
                       for b in range(-rz, rz + 1)]
                if all(c in cs for c in box) and W.flat(box):
                    if best is None or len(box) > len(best[0]):
                        best = (box, rx, rz)
        if best is None:
            continue
        box, rx, rz = best
        W.lake |= set(box)
        W.road -= set(box)
        W.waters.append((at[0] - rx, at[1] - rz, at[0] + rx + 1, at[1] + rz + 1))
        return len(box)
    return 0
SPIRE_EDGE_ROOM = 600
def district_landmark(W, cells, centre, r, pal, kind):
    from .. import landmarks
    k = landmarks.foot(kind) // 2
    def foot(c):
        return [(c[0] + a, c[1] + b) for a in range(-k, k + 1) for b in range(-k, k + 1)]
    own = set(cells)
    def fits(c):
        f = foot(c)
        ring = [(x[0] + a, x[1] + b) for x in f for a, b in pcg.N4]
        return (all(x in own and x not in W.solid and x not in W.lake and x not in W.river
                    and x not in W.cuts and x not in W.roofs and x not in W.ramps
                    and x not in W.streets and x not in W.road
                    for x in f)
                and W.flat(f) and not any(x in W.solid for x in ring))
    order = sorted(own, key=lambda c: (abs(c[0] - centre[0]) + abs(c[1] - centre[1]), c))
    spot = next((c for c in order[:400] if fits(c)), None)
    if spot is None:
        return 0
    full = landmarks.derive_full(kind, r, pal)
    pieces = full["pieces"]
    turned = False
    if kind == "gate" and any((spot[0] + a, spot[1]) in W.road for a in (-2, 2)) \
            and not any((spot[0], spot[1] + b) in W.road for b in (-2, 2)):
        m = v1.arenas_module()
        pieces = [m.turned(p, 1) for p in pieces]
        turned = True
    entry = dict(full, cell=spot, pieces=pieces, foot=landmarks.foot(kind), cells=foot(spot))
    if turned:
        entry["faces_ok"] = True
    W.landmarks.append(entry)
    for c in foot(spot):
        W.solid[c] = (0, None, "landmark")
    return 1
def district_plaza(W, cells, centre, tex, grand=False):
    a = 600 if grand else 400
    k = 2
    def deck_at(c):
        return [(c[0] + di, c[1] + dj) for di in range(-k, k + 1) for dj in range(-k, k + 1)]
    def fits(c):
        flight = [(c[0], c[1] + dj) for dj in range(k + 1, k + 4)]
        return (W.flat(deck_at(c) + flight)
                and not any(x in W.solid or x in W.streets or x in W.lake for x in deck_at(c))
                and not any(x in W.solid or x in W.lake or x in W.river for x in flight))
    own = set(cells)
    if not fits(centre):
        alt = [c for c in sorted(own, key=lambda c: (abs(c[0] - centre[0]) + abs(c[1] - centre[1]), c))
               if all(x in own for x in deck_at(c)) and fits(c)]
        if not alt:
            return 0
        centre = alt[0]
    deck = deck_at(centre)
    for c in deck:
        W.road.discard(c)
    W.spires.append({"cell": centre, "a": a, "h": 2600 if grand else 1600, "tex": tex,
                     "grand": grand})
    for c in deck:
        W.solid.setdefault(c, (0, tex, "spire"))
    for dj in range(k + 1, k + 3):
        W.solid.setdefault((centre[0], centre[1] + dj), (0, tex, "spire"))
        W.road.discard((centre[0], centre[1] + dj))
    return 1
VOLCANO_R = 6
VOLCANO_LAYERS = 7
def district_volcano(W, cells, centre, rock, clear_streets=False):
    R = max(3, min(VOLCANO_R, W.n // 6))
    from .. import terrain
    own = set(cells)
    for c in list(W.road):
        if c in own and max(abs(c[0] - centre[0]), abs(c[1] - centre[1])) <= R:
            W.road.discard(c)
    if clear_streets:
        for c in list(W.streets):
            if c in own and max(abs(c[0] - centre[0]), abs(c[1] - centre[1])) <= R - 1:
                W.streets.discard(c)
    free = [c for c in cells if W.free(c)
            and max(abs(c[0] - centre[0]), abs(c[1] - centre[1])) <= R]
    if len(free) < 9:
        return 0
    fs = set(free)
    h = {}
    for c in free:
        d = max(abs(c[0] - centre[0]), abs(c[1] - centre[1]))
        h[c] = min(VOLCANO_LAYERS, R - d + 1)
    for c in free:
        if any((c[0] + a, c[1] + b) not in fs for a, b in pcg.N4):
            h[c] = min(h[c], 1)
    terrain.smooth(h)
    top = max(h.values())
    crater = [c for c in free if max(abs(c[0] - centre[0]), abs(c[1] - centre[1])) <= 1
              and h[c] == top]
    for c in crater:
        h[c] = top - 1
    cs_ = set(crater)
    for c in crater:
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                m = (c[0] + a, c[1] + b)
                if m in fs and m not in cs_:
                    h[m] = max(h[m], top)
    for c, d in terrain.climb_ramps(h, fs - set(crater)).items():
        W.ramps[c] = d
    for c, v in h.items():
        if v:
            W.hills[c] = v
            W.top_tex[c] = rock
    W.craters.append(crater)
    W.volcano = {"cell": centre, "top": top, "crater": crater}
    return len(free)
RIVER_SURFACE = 150
BANK = 1
def lay_river(W, n, seed):
    from .. import terrain
    if not W.macro:
        cells = [(i, j) for i in range(n) for j in range(n)]
        W.macro = terrain.macro(cells, "%s/explore-river" % seed)
    path = terrain.trunk(W.macro)
    if getattr(W, "meander", None) is not None:
        from .. import landscape
        path = landscape.meander(path, n, W.meander)
    W.valley = list(path)
    W.river = set(c for c in path if c not in W.road and 2 <= c[0] < n - 2 and 2 <= c[1] < n - 2)
    W.streets -= W.river
    return W.river
def lay_land(W, n, seed, sites, centre, top, river, weirs=False, preset=None, hide=False,
             broad=False):
    from .. import landform, terrain
    cells = [(i, j) for i in range(n) for j in range(n)]
    if top > 0 or river:
        W.macro = terrain.macro(cells, "%s/explore-river" % seed)
    field = {s: W.macro.get(s, 0.5) for s in sites} if W.macro else None
    W.plinth = landform.plinths(sites, n, seed, top, centre=centre, field=field)
    W.preset = preset
    if preset and top > 0:
        from .. import landscape
        cap = top if hide else None
        levels = landscape.band_levels(top if hide else top, preset)
        if cap is not None:
            levels = [v for v in levels if v <= cap] or [0, cap]
        W.bands = levels
        W.plinth = landscape.band_plinths(W.plinth, top, levels)
    W.plinth_shape = dict(W.plinth)
    if broad and top > 0:
        raised = sorted((d for d, v in W.plinth.items() if v > 0),
                        key=lambda d: (-(field or {}).get(sites[d], 0.5), d))
        for d in raised[BROAD_PLATEAUS:]:
            W.plinth[d] = 0
    G = landform.ground(W.owner, W.plinth, W.streets)
    if river:
        lay_river(W, n, seed)
        lv, weirs_ = landform.river_levels(W.valley, G)
        if weirs and not weirs_ and len(W.valley) >= 8:
            for c in W.valley[:len(W.valley) // 2]:
                lv[c] += 1
            weirs_ = [(W.valley[len(W.valley) // 2 - 1], W.valley[len(W.valley) // 2])]
        W.river_level = {c: lv[c] for c in W.valley}
        W.weirs = [(a, b) for a, b in weirs_ if a in W.river and b in W.river]
        G = landform.ground(W.owner, W.plinth, W.streets, fixed=W.river_level)
        landform.banks(set(W.valley), W.river_level, G)
    if preset and top > 0 and len(getattr(W, "bands", ())) > 1 and not broad:
        from .. import landscape
        keep = set(W.valley)
        for c in W.valley:
            for a, b in pcg.N4:
                keep.add((c[0] + a, c[1] + b))
        step = max(2, max(b - a for a, b in zip(W.bands, W.bands[1:])))
        G, W.clefts = landscape.cliff_ground(G, W.owner, W.streets, W.plinth, sites, step,
                                             keep=keep)
    from .. import stamps as stampmod
    if stampmod.ACTIVE:
        avoid = set(getattr(W, "valley", None) or ()) | \
            set(c for c, d in W.owner.items() if d == centre)
        W.stamps = stampmod.lay(G, seed, avoid=avoid,
                                keep=set((getattr(W, "river_level", None) or {}).keys()))
    W.base = G
    return G
ADAPTIVE_SIZES = ("huge", "gigantic")
GIANT_ACROSS = 24000
BACKDROP_SNOW = {"lava": None, "desert": None, "ice": "snowfresh"}
def terrain_spec(W, brief, info, n):
    from .. import heightfield, landscape as _ls
    have = kit.textures()
    theme = common.theme_of(brief)
    slope = {}
    for d_, b_ in sorted(W.biome.items()):
        top, sl = _ls.biome_top(b_, have), _ls.biome_slope(b_, have)
        if top and sl and top != sl:
            slope.setdefault(top, sl)
    rock = _ls.riser_tex(theme, 0, have) or theme_world(brief).get("rock") or "rockgrey"
    snow = BACKDROP_SNOW.get(theme, "snowfresh")
    snow = snow if snow in have else None
    back = {"half": n * CELL // 2 + 200, "rock": rock, "snow": snow}
    if info["floor"] is None:
        back["skirt"] = True
    if info["floor"] is not None and brief.get("boundary") != "visible":
        from .. import outland
        back["outline"] = outland.kind_for(theme)
        if back["outline"] == "mountains" and back["snow"] is None and \
                BACKDROP_SNOW.get(theme, "snowfresh"):
            back["snow"] = BACKDROP_SNOW.get(theme, "snowfresh")
    out = {"mesh": True, "floor": info["floor"], "seed": "%s" % brief["seed"],
           "slope_tex": slope, "rock": rock, "quad": heightfield.QUAD, "backdrop": back}
    if n * CELL > GIANT_ACROSS:
        out["tolerance"] = heightfield.LADDER[1]["tolerance"]
    if brief.get("size") in ADAPTIVE_SIZES:
        out["multires"] = "dual"
    if W.peaks:
        from .. import landform
        off = -n * CELL // 2
        gone = set(W.cuts) | set(W.roofs) | set(W.solid)
        def rects(cells):
            return [[off + i0 * CELL, off + i1 * CELL, off + j0 * CELL, off + j1 * CELL]
                    for (i0, j0, i1, j1) in landform.merge_rects(set(cells) - gone)]
        out["steep"] = rects(c for pk in W.peaks for c in set(pk["flank"]) | set(pk["summit"])
                             if W.hills.get(c) and c not in pk["path"])
        out["held"] = rects(c for pk in W.peaks for c in pk["path"])
    if W.craters:
        off = -n * CELL // 2
        from .. import landform
        pit = set()
        for crater in W.craters:
            for c in crater:
                for a in (-1, 0, 1):
                    for b in (-1, 0, 1):
                        pit.add((c[0] + a, c[1] + b))
        out["held"] = (out.get("held") or []) + [
            [off + i0 * CELL, off + i1 * CELL, off + j0 * CELL, off + j1 * CELL]
            for (i0, j0, i1, j1) in landform.merge_rects(pit - set(W.ramps))]
    rings = getattr(W, "pond_rings", None)
    if rings:
        off = -n * CELL // 2
        from .. import landform
        out["steep"] = (out.get("steep") or []) + [
            [off + i0 * CELL, off + i1 * CELL, off + j0 * CELL, off + j1 * CELL]
            for (i0, j0, i1, j1) in landform.merge_rects(set(rings))]
    return out
def lay_roads(W, sites, edges, n):
    from .. import landform
    G = W.base
    W.road_info = []
    for a, b in edges:
        path = landform.road_path(G, sites[a], sites[b], river=W.river,
                                  river_level=W.river_level)
        if not path:
            continue
        W.road_info.append(landform.road_stats(path, G, W.river, W.river_level))
        for c in path:
            if c in W.streets and c not in W.river:
                continue
            W.road.add(c)
            if c in W.river:
                W.bridges.add(c)
                continue
            for d in ((1, 0), (0, 1)):
                x = (c[0] + d[0], c[1] + d[1])
                if (0 <= x[0] < n and 0 <= x[1] < n and x not in W.streets
                        and x not in W.river and G.get(x) == G.get(c)):
                    W.road.add(x)
    return len(W.road_info)
def shape_valley(W):
    if not W.valley:
        return 0
    dist = {c: 0 for c in W.valley}
    todo = list(W.valley)
    while todo:
        nxt = []
        for c in todo:
            for a, b in pcg.N4:
                m = (c[0] + a, c[1] + b)
                if 0 <= m[0] < W.n and 0 <= m[1] < W.n and m not in dist:
                    dist[m] = dist[c] + 1
                    nxt.append(m)
        todo = nxt
    capped = 0
    from .. import landscape
    step = landscape.HILL_RISER if len(getattr(W, "bands", ()) or ()) > 1 and \
        not MESH_GROUND else 1
    peaks = set(c for pk in W.peaks for c in pk["cells"])
    for c in list(W.hills):
        if c in peaks:
            continue
        d = dist.get(c, 99)
        cap = max(BANK, (d // step) * step)
        if W.hills[c] > cap:
            W.hills[c] = cap
            capped += 1
    valid_ramps(W)
    return capped
def valid_ramps(W):
    step = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
    W.ramps = {c: d for c, d in W.ramps.items()
               if W.T((c[0] + step[d][0], c[1] + step[d][1])) == W.T(c) + 1}
def settle_hills(W):
    from .. import landform
    T = W.total()
    keep = set(c for c in T if not W.hills.get(c))
    keep |= set(c for pk in W.peaks for c in pk["cells"])
    if MESH_GROUND and (len(getattr(W, "bands", ()) or ()) > 1 or W.banded_hills):
        from .. import landscape
        keep |= landscape.climb_cells(W.ramps)
        landscape.settle_step(T, keep=keep, step=landscape.HILL_RISER if W.banded_hills else 1)
    elif len(getattr(W, "bands", ()) or ()) > 1:
        from .. import landscape
        keep |= landscape.climb_cells(W.ramps)
        landscape.settle_step(T, keep=keep, step=max(landscape.HILL_RISER, max(
            b - a for a, b in zip(W.bands, W.bands[1:]))))
    else:
        landform.settle(T, keep=keep)
    for c in list(W.hills):
        v = T[c] - W.base.get(c, 0)
        if v > 0:
            W.hills[c] = v
        else:
            del W.hills[c]
    valid_ramps(W)
def terrace_down(W):
    keep = set(W.valley)
    for c in W.valley:
        for a, b in pcg.N4:
            keep.add((c[0] + a, c[1] + b))
    for c in list(W.roofs) + list(W.cuts):
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                keep.add((c[0] + a, c[1] + b))
    cand = [c for c, v in W.base.items() if c not in keep]
    if not cand:
        return 0
    top = max(W.base[c] for c in cand)
    if top <= 1:
        return 0
    low = [c for c in cand if W.base[c] == top]
    W.lowered |= set(low)
    for c in low:
        W.base[c] = top - 1
    for i, v in list(W.plinth.items()):
        if v == top:
            W.plinth[i] = top - 1
    valid_ramps(W)
    return len(low)
def networks_strip():
    from .. import networks
    return networks.STRIP_H
def band_down(W, n=1):
    keep = set(W.valley) | set(W.roofs) | set(W.cuts)
    by = {}
    for c, d in W.owner.items():
        if c not in W.streets and W.plinth.get(d, 0) > 0:
            by.setdefault(d, []).append(c)
    if not by:
        return 0
    for d in sorted(by, key=lambda k: (len(by[k]), k))[:max(1, n)]:
        lower = [b for b in W.bands if b < W.plinth[d]]
        W.plinth[d] = lower[-1] if lower else 0
    from .. import landform, landscape
    G = landform.ground(W.owner, W.plinth, W.streets, fixed=W.river_level or None)
    if W.valley:
        landform.banks(set(W.valley), W.river_level, G)
    step = max(2, max(b - a for a, b in zip(W.bands, W.bands[1:])))
    kv = set(W.valley)
    for c in W.valley:
        for a, b in pcg.N4:
            kv.add((c[0] + a, c[1] + b))
    G, W.clefts = landscape.cliff_ground(G, W.owner, W.streets, W.plinth, W.sites, step,
                                         keep=kv)
    n = 0
    for c, v in G.items():
        if c in keep:
            continue
        if v < W.base.get(c, 0):
            W.lowered.add(c)
            n += 1
        W.base[c] = v
    valid_ramps(W)
    return n
LANDFORM_COUNT = {"tiny": 0, "small": 1, "medium": 1, "large": 1, "huge": 2, "gigantic": 3}
def lay_landforms(W, brief, kinds, by, r, notes, np_out):
    from .. import landrecipes as LR
    size = brief["size"] if isinstance(brief["size"], str) else "large"
    want = set((brief.get("features") or {}).get("want") or ())
    theme = common.theme_of(brief)
    n = LANDFORM_COUNT.get(size, 1)
    asked = [r_ for f, r_ in sorted(LR.FEATURE_OF.items()) if f in want]
    recipes = LR.pick(theme, want, max(n, len(asked)), r)
    natural = [d for d, k in sorted(kinds.items()) if k in ("hills", "garden", "ruins", "forest")]
    built = []
    for rec in recipes:
        if rec == "glacier":
            hills = [d for d in natural if kinds[d] == "hills"]
            cells = [c for d in hills for c in by.get(d, []) if W.hills.get(c, 0) >= 2
                     and c not in W.roofs]
            if not cells:
                continue
            top = max(W.T(c) for c in cells)
            reach = [c for c in cells if W.T(c) >= top - 2]
            for c in reach:
                W.biome_tex[c] = "ice" if "ice" in kit.textures() else W.biome_tex.get(c)
            W.landforms.append({"recipe": "glacier", "cells": sorted(reach)})
            built.append("glacier")
            continue
        if rec == "rolling":
            hills = [d for d in natural if kinds[d] == "hills"]
            if not hills:
                continue
            for d in hills[:2]:
                W.rolling |= set(by.get(d, []))
            W.landforms.append({"recipe": "rolling", "cells": sorted(W.rolling)})
            built.append("rolling hills")
            continue
        foot = LR.FOOT[rec]
        placed = False
        trees = set(W.trees)
        def open_(c):
            return W.free(c) or (c in trees and W.solid.get(c, (0, 0, ""))[2] == "tree")
        for d in sorted(natural, key=lambda d: (-len(by.get(d, [])), d)):
            cells = sorted(c for c in by.get(d, []) if open_(c))
            if len(cells) < foot[0] * foot[1] + 4:
                continue
            start = r.randint(0, max(0, len(cells) - 1))
            order = cells[start:] + cells[:start]
            def level(c, d=d):
                if not open_(c) or W.owner.get(c) != d or c in W.ramps or c in W.shapes:
                    return None
                return W.T(c)
            got = None
            for c0 in order:
                got = LR.site([c0], level, foot)
                if got is None:
                    continue
                c, (a, b), h = got
                ring = [(c[0] + i, c[1] + j) for i in range(-1, a + 1) for j in range(-1, b + 1)]
                if all(open_(m) and W.T(m) == h for m in ring):
                    break
                got = None
            if got is None:
                continue
            c, (a, b), h = got
            for i in range(a):
                for j in range(b):
                    m = (c[0] + i, c[1] + j)
                    if m in trees:
                        W.trees.remove(m)
                        W.tree_kind.pop(m, None)
                        trees.discard(m)
                    W.solid[m] = (1200, None, "landform")
            W.landforms.append({"recipe": rec, "cell": c, "foot": (a, b), "level": h,
                                "district": d})
            built.append(rec)
            placed = True
            break
        if not placed and rec in asked:
            np_out.append("%s: no natural district had a level site for it on this seed "
                          "(try a larger size)" % rec)
    if built:
        notes.append("landforms: %s" % ", ".join(built))
    return built
def lay_caves(W, owners, want=3):
    if owners is None:
        from .. import caves as worm
        if worm.lay(W, want=min(want, worm.WANT)):
            return len(W.caves)
    taken = set()
    T = W.total()
    held = set(c for pk in W.peaks for c in list(pk["path"]) + list(pk["summit"]))
    def foot(m, t0):
        return (0 <= m[0] < W.n and 0 <= m[1] < W.n and T.get(m) == t0
                and m not in W.solid and m not in W.river and m not in W.lake)
    for axis in (0, 1):
        d = (1, 0) if axis == 0 else (0, 1)
        side = (0, 1) if axis == 0 else (1, 0)
        for c in sorted(T):
            if len(W.caves) >= want:
                return len(W.caves)
            if owners is not None and W.owner.get(c) not in owners:
                continue
            before = (c[0] - d[0], c[1] - d[1])
            if before not in T:
                continue
            t0 = T[before]
            if T[c] <= t0 or not foot(before, t0):
                continue
            run = []
            m = c
            roofed_seen = False
            while m in T and T[m] > t0 and len(run) < 18 and not (
                    roofed_seen and T[m] <= t0 + 1):
                run.append(m)
                roofed_seen = roofed_seen or T[m] >= t0 + 3
                m = (m[0] + d[0], m[1] + d[1])
            out_ok = foot(m, t0) or (T.get(m) == t0 + 1 and foot(m, t0 + 1)
                                     and m not in W.roofs and m not in W.cuts)
            if not out_ok or len(run) < 4:
                continue
            if sum(1 for x in run if T[x] >= t0 + 3) < 2:
                continue
            if any(x in W.solid or x in taken or x in W.road or x in W.river or x in W.lake
                   or x in held for x in run):
                continue
            if any((x[0] + k * side[0], x[1] + k * side[1]) in taken
                   for x in run for k in (-1, 1)):
                continue
            roofed = [x for x in run if T[x] >= t0 + 3]
            for x in run:
                taken.add(x)
                W.ramps.pop(x, None)
                if T[x] < t0 + 3:
                    W.cuts[x] = t0
                else:
                    W.roofs[x] = set(range(t0 + 1, t0 + 1 + CAVE_H // 200))
            W.caves.append(roofed)
            W.cave_floor = getattr(W, "cave_floor", {})
            for x in roofed:
                W.cave_floor[x] = t0
    return len(W.caves)
CAVE_H = 400
PLATE_SIDES = (15, 8, 4, 2, 1)
PLATE_SIDES_FROM = 450
def level_y(level, lift):
    return lift if level <= 0 else 200 * level
RIVER_RUN = 15
DEEP_RIVER = 200
def deep_pools(W):
    weir_cells = set(a for a, b in W.weirs)
    return set(c for c in W.river if W.river_level.get(c, 0) <= 0 and c not in weir_cells)
def stand_deep(W, n, off, floor_tex, pieces, spots, objects, design, lift,
               deep=DEEP_RIVER):
    from .. import landform
    pools = deep_pools(W)
    if not pools:
        return 0
    def cells_of(p):
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
        if int(p.get("yaw", 0)) % 180 == 90:
            x0, x1, z0, z1 = (p["x"] - p["d"] / 2.0, p["x"] + p["d"] / 2.0,
                              p["z"] - p["w"] / 2.0, p["z"] + p["w"] / 2.0)
        i0, i1 = int(math.floor((x0 + 1 - off) / CELL)), int(math.floor((x1 - 1 - off) / CELL))
        j0, j1 = int(math.floor((z0 + 1 - off) / CELL)), int(math.floor((z1 - 1 - off) / CELL))
        return [(i, j) for i in range(i0, i1 + 1) for j in range(j0, j1 + 1)]
    def plate_cell(i, j):
        return 0 <= i < n and 0 <= j < n and (i, j) not in pools
    top = deep
    up = deep - lift
    keep = []
    for p in pieces:
        on_plate = all(plate_cell(i, j) for (i, j) in cells_of(p))
        if p["y"] <= 0 and not on_plate:
            p["h"] += up
        elif p["y"] < lift and on_plate:
            if p["y"] + p["h"] <= lift:
                continue
            p["h"] = p["y"] + p["h"] - lift
            p["y"] = top
        else:
            p["y"] += up
        keep.append(p)
    pieces[:] = keep
    for o in list(spots) + list(objects):
        c = (int(math.floor((o["x"] - off) / CELL)), int(math.floor((o["z"] - off) / CELL)))
        o["y"] = max(top, o["y"] + up) if plate_cell(*c) else o["y"] + up
    def lift_rows(v):
        if isinstance(v, dict):
            for k in ("y", "top", "bottom"):
                if isinstance(v.get(k), (int, float)) and not isinstance(v.get(k), bool):
                    v[k] += up
            for k, w in v.items():
                if k not in ("relief", "descriptors", "settlements", "readability"):
                    lift_rows(w)
        elif isinstance(v, list):
            for w in v:
                lift_rows(w)
    for k, v in design.items():
        if k != "lift":
            lift_rows(v)
    design["lift"] = top
    design["deep"] = deep
    def in_pools(x0, z0, x1, z1):
        return all((int(math.floor((x - off) / CELL)), int(math.floor((z - off) / CELL))) in pools
                   for x in (x0 + 1, x1 - 1) for z in (z0 + 1, z1 - 1))
    rows = []
    for w in getattr(W, "water_boxes", []):
        w = list(w)
        w[4] += up
        w[5] = 0 if in_pools(w[0], w[1], w[2], w[3]) and w[5] <= 0 else w[5] + up
        rows.append(w)
    W.water_boxes = rows
    for po in design.get("pools", []):
        if in_pools(po["x0"], po["z0"], po["x1"], po["z1"]) and po["bottom"] <= up:
            po["bottom"] = 0
    plate = set((i, j) for i in range(n) for j in range(n)) - pools
    made = 0
    for (i0, j0, i1, j1) in landform.merge_rects(plate):
        pieces.append(kit.kind("box").make(floor_tex, off + i0 * CELL, off + i1 * CELL, 0, top,
                             off + j0 * CELL, off + j1 * CELL, None, "terrace.plate"))
        made += 1
    return made
HERO_ROAD_MAX = 30
def hero_road(W, notes):
    from .. import landmarks, networks
    def top_of(lm):
        return 200 * W.T(lm["cell"]) + lm.get("height", 0)
    def foot_of(lm):
        if lm.get("cells"):
            return set(map(tuple, lm["cells"]))
        k = int(lm.get("foot") or landmarks.foot(lm["kind"])) // 2
        c = lm["cell"]
        return set((c[0] + a, c[1] + b) for a in range(-k, k + 1) for b in range(-k, k + 1))
    lms = [lm for lm in W.landmarks if lm.get("cell") is not None]
    if not lms:
        return None
    hero = max(lms, key=lambda lm: (top_of(lm), tuple(lm["cell"])))
    if W.spires and max(200 * W.T(sp["cell"]) + 400 + sp["h"] for sp in W.spires) > top_of(hero):
        return None
    foot = foot_of(hero)
    ring = sorted(set((c[0] + a, c[1] + b) for c in foot for a, b in pcg.N4) - foot)
    goal = set(W.road) | set(W.streets)
    district = W.owner.get(tuple(hero["cell"]))
    if any(c in goal for c in ring):
        return {"kind": hero["kind"], "cells": 0, "district": district}
    class Ctx(object):
        pass
    ctx = Ctx()
    ctx.W = W
    best = None
    for c in ring:
        if not (0 <= c[0] < W.n and 0 <= c[1] < W.n) or c in W.solid or c in W.lake \
                or c in W.river or c in W.cuts or c in W.roofs:
            continue
        way = networks.route(ctx, c, goal, set())
        if way is not None and (best is None or len(way) < len(best)):
            best = way
    if best is None or len(best) > HERO_ROAD_MAX:
        notes.append("hero road: no way from the %s to the roads within %d cells"
                     % (hero["kind"], HERO_ROAD_MAX))
        return None
    cells = [c for c in best if c not in goal]
    for c in cells:
        W.road.add(c)
        if c in W.river:
            W.bridges.add(c)
    notes.append("hero road: the %s joined to the roads (%d cells)" % (hero["kind"], len(cells)))
    return {"kind": hero["kind"], "cells": len(cells), "district": district}
def river_rects(cells):
    left = set(cells)
    out = []
    for c in sorted(left):
        if c not in left:
            continue
        w = 1
        while (c[0] + w, c[1]) in left and w < RIVER_RUN:
            w += 1
        d = 1
        while d < RIVER_RUN and all((c[0] + a, c[1] + d) in left for a in range(w)):
            d += 1
        for a in range(w):
            for b in range(d):
                left.discard((c[0] + a, c[1] + b))
        out.append((c[0], c[1], c[0] + w, c[1] + d))
    return out
POND_DEEP = 2800
POND_DEEP_ASKED = 2400
def raised_ponds(waters, levels=False):
    deep = [k for k, (i0, j0, i1, j1) in enumerate(waters) if (j1 - j0) * CELL >= POND_DEEP]
    out = set(k for k in deep if k % 2 == 1)
    if not levels or len(waters) < 2:
        return out
    if not out:
        fits = [k for k, (i0, j0, i1, j1) in enumerate(waters)
                if (j1 - j0) * CELL >= POND_DEEP_ASKED]
        if fits:
            out = {max(fits, key=lambda k: (waters[k][3] - waters[k][1], -k))}
    if len(out) == len(waters):
        out.discard(min(out))
    return out
LAKE_BASIN = 4.0
def basin_share(W, n, seed):
    from .. import terrain
    if not W.macro:
        cells = [(i, j) for i in range(n) for j in range(n)]
        W.macro = terrain.macro(cells, "%s/explore-river" % seed)
    deep = terrain.depressions(W.macro)
    size, wet = {}, {}
    for c, d in W.owner.items():
        size[d] = size.get(d, 0) + 1
        if c in deep:
            wet[d] = wet.get(d, 0) + 1
    return {d: wet.get(d, 0) / float(size[d]) for d in size}
def ensure_lakes(kinds, owner, mid, count, basin=None):
    have = sum(1 for k in kinds.values() if k == "lake")
    if have >= count:
        return []
    size = {}
    for c, d in owner.items():
        size[d] = size.get(d, 0) + 1
    basin = basin or {}
    order = sorted((i for i in kinds if i != mid and kinds[i] not in ("lake", "volcano")),
                   key=lambda i: (-round(basin.get(i, 0.0), 2), -size.get(i, 0), i))
    made = []
    for i in order[:count - have]:
        kinds[i] = "lake"
        made.append(i)
    return made
def design_sites(W, sites, kinds, n, off, lift):
    def X(i):
        return off + i * CELL + CELL // 2
    def Y(c):
        return level_y(W.T(c), lift)
    out = {"cell": CELL, "lift": lift, "half": n * CELL // 2, "districts": [],
           "summits": [], "decks": [], "pockets": [], "pools": [], "corners": [],
           "open": [], "roads": [], "trees": [], "landmarks": []}
    for i, c in enumerate(sites):
        out["districts"].append({"i": i, "kind": kinds.get(i), "x": X(c[0]), "z": X(c[1]),
                                 "plinth": W.plinth.get(i, 0), "y": Y(c)})
    by = {}
    for c in sorted(set(W.hills) | set(c for c in W.base if W.base[c] >= 2)):
        d = W.owner.get(c)
        if c in W.roofs or c in W.cuts or c in W.shapes or c in W.solid or c in W.lake \
                or c in W.river or c in W.road or c in W.streets:
            continue
        layer = W.T(c)
        if d is not None and layer > by.get(d, (0, None))[0]:
            by[d] = (layer, c)
    for d, (layer, c) in sorted(by.items()):
        out["summits"].append({"x": X(c[0]), "y": level_y(layer, lift), "z": X(c[1]),
                               "district": d, "layer": layer})
    out["peaks"] = []
    for pk in getattr(W, "peaks", None) or ():
        c = pk["path"][-1]
        out["peaks"].append({"x": X(c[0]), "z": X(c[1]), "y": level_y(W.base.get(c, 0), lift),
                             "top": level_y(W.T(c), lift) + 300, "a": 600})
    out["volcanoes"] = []
    if W.volcano:
        c = W.volcano["cell"]
        out["volcanoes"].append({"x": X(c[0]), "z": X(c[1]),
                                 "y": level_y(W.base.get(c, 0) + W.volcano["top"], lift)})
    for sp in W.spires:
        c = sp["cell"]
        out["decks"].append({"x": X(c[0]), "y": Y(c) + 400, "z": X(c[1]),
                             "top": Y(c) + 400 + sp["h"], "a": sp["a"],
                             "grand": bool(sp.get("grand")), "district": W.owner.get(c)})
    for lm in W.landmarks:
        c = lm["cell"]
        out["landmarks"].append({"kind": lm["kind"], "x": X(c[0]), "z": X(c[1]), "y": Y(c),
                                 "top": Y(c) + lm.get("height", 0),
                                 "district": W.owner.get(c)})
    for c in sorted(W.owner):
        if not W.free(c) or kinds.get(W.owner[c]) not in ("ruins", "garden"):
            continue
        walls = sum(1 for a, b in pcg.N4 if (c[0] + a, c[1] + b) in W.solid)
        if walls >= 3:
            out["pockets"].append({"x": X(c[0]), "y": Y(c), "z": X(c[1]), "walls": walls,
                                   "district": W.owner[c]})
    for w in getattr(W, "water_boxes", []):
        x0, z0, x1, z1, top, bottom = w
        mid = (int(((x0 + x1) // 2 - off) // CELL), int(((z0 + z1) // 2 - off) // CELL))
        out["pools"].append({"x0": x0, "z0": z0, "x1": x1, "z1": z1, "top": top, "bottom": bottom,
                             "x": (x0 + x1) // 2, "z": (z0 + z1) // 2,
                             "district": W.owner.get(mid)})
    def level_block(c, k=2):
        h = W.T(c)
        for a in range(-k, k + 1):
            for b in range(-k, k + 1):
                m = (c[0] + a, c[1] + b)
                if not (0 <= m[0] < n and 0 <= m[1] < n) or W.T(m) != h or m in W.shapes \
                        or m in W.solid or m in W.lake or m in W.river or m in W.roofs \
                        or m in W.cuts or m in W.bridges:
                    return False
        return True
    for ci, cj in ((2, 2), (n - 3, 2), (2, n - 3), (n - 3, n - 3)):
        near = sorted(((ci + a, cj + b) for a in range(-6, 7) for b in range(-6, 7)
                       if 2 <= ci + a < n - 2 and 2 <= cj + b < n - 2),
                      key=lambda m: (abs(m[0] - ci) + abs(m[1] - cj), m))
        c = next((m for m in near if level_block(m)), (ci, cj))
        out["corners"].append({"x": X(c[0]), "z": X(c[1]), "y": Y(c), "cell": [c[0], c[1]]})
    trees = set(W.trees)
    def flat_free(c, h):
        if W.T(c) != h or c in W.shapes or c in W.hills:
            return False
        if c in trees:
            return c not in W.road and c not in W.streets
        return W.free(c)
    for c in sorted(W.owner):
        h = W.T(c)
        if flat_free(c, h) and all(flat_free((c[0] + a, c[1] + b), h) for a, b in pcg.N4):
            ring = 1
            while ring < 4 and all(flat_free((c[0] + a, c[1] + b), h)
                                   for a in range(-ring - 1, ring + 2)
                                   for b in range(-ring - 1, ring + 2)):
                ring += 1
            out["open"].append({"x": X(c[0]), "z": X(c[1]), "district": W.owner[c],
                                "clear": ring, "y": Y(c)})
    runs = []
    for axis in (0, 1):
        seen = set()
        for c in sorted(W.road):
            if c in seen:
                continue
            k = 0
            def at(k):
                return (c[0] + (k if axis == 0 else 0), c[1] + (k if axis == 1 else 0))
            while at(k) in W.road and W.T(at(k)) == W.T(c) and at(k) not in W.shapes \
                    and at(k) not in W.bridges:
                seen.add(at(k))
                k += 1
            if k >= 6:
                end = at(k - 1)
                runs.append({"x0": X(c[0]), "z0": X(c[1]), "x1": X(end[0]), "z1": X(end[1]),
                             "cells": k, "axis": "x" if axis == 0 else "z", "y": Y(c) + 20})
    out["roads"] = sorted(runs, key=lambda r: (-r["cells"], r["x0"], r["z0"]))[:12]
    out["trees"] = [{"x": X(c[0]), "z": X(c[1]), "y": Y(c)} for c in W.trees[:60]]
    return out
def build(brief, streams, reference=False):
    notes = []
    r = streams("world")
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    level = brief["level"]
    info = common.level_info(level)
    lift = 10 if info["floor"] is not None else 0
    n = across_for(brief, info)
    half = n * CELL // 2
    off = -half
    W = World(n)
    cells = [(i, j) for i in range(n) for j in range(n)]
    k = max(4, int(n * n / DISTRICT_CELLS))
    radius = max(4.0, n / math.sqrt(k) * 0.8)
    inner = [c for c in cells if 2 <= c[0] < n - 2 and 2 <= c[1] < n - 2]
    sites = pcg.poisson_disk(inner, radius, streams("sites"), limit=k)
    W.sites = sites
    W.owner = pcg.voronoi(cells, sites)
    border, pairs = pcg.borders(W.owner)
    W.streets = set(border) | set(c for c in cells if c[0] in (0, 1, n - 2, n - 1)
                                  or c[1] in (0, 1, n - 2, n - 1))
    from .. import cyclic
    edges = pcg.delaunay_mst(sites, pairs, 0, streams("roads"))
    steps = max(1, len(sites) // 4) + (1 if "loops" in common.want_avoid(brief)[0] else 0)
    def road_len(e):
        a, b = sites[e[0]], sites[e[1]]
        return math.hypot(a[0] - b[0], a[1] - b[1])
    edges, rewrites = cyclic.rewrite(list(range(len(sites))), edges, sorted(pairs),
                                     streams("cycles"), steps, length=road_len)
    if rewrites:
        notes.append("road graph rewritten into %d loops: %s" % (
            cyclic.cycles(list(range(len(sites))), edges),
            ", ".join("%s %d-%d" % x for x in rewrites)))
    land_want = common.want_avoid(brief)[0]
    mid = min(range(len(sites)), key=lambda i: (abs(sites[i][0] - n / 2.0)
                                                + abs(sites[i][1] - n / 2.0), i))
    from .. import landform
    top = landform.plinth_top(brief)
    from .. import landscape
    preset, why_preset = landscape.preset_for(brief, streams("preset"))
    land_avoid = common.want_avoid(brief)[1]
    lava_world = theme_world(brief)["liquid"] == "lava" and brief.get("family") != "hide"
    big = brief["size"] in ("huge", "gigantic") if isinstance(brief["size"], str) else False
    lava_river = lava_world and big and not (land_avoid & {"river", "lava"})
    if "river" in land_want and brief["size"] not in ("tiny", "small"):
        import random as _random
        W.meander = _random.Random("%s/meander" % brief["seed"])
    lay_land(W, n, brief["seed"], sites, mid, top, bool(land_want & {"river", "valley", "weirs",
                                                       "bridge"}) or lava_river,
             "weirs" in land_want, preset=preset, hide=brief.get("family") == "hide",
             broad=broad_relief(brief))
    if lava_river and not (land_want & {"river", "valley"}):
        notes.append("lava: a lava river runs down the world (a lava world's own, no wish "
                     "asked)")
    if top and W.bands:
        notes.append("landscape: %s (%s) - bands %s layers, risers of %s, %d clefts"
                     % (preset, why_preset, "/".join(str(b) for b in W.bands),
                        "/".join(str(b - a) for a, b in zip(W.bands, W.bands[1:])),
                        len(set(W.clefts.values()))))
    mountainous = bool("mountains" in land_want or ("caves" in land_want and top < 3))
    peaks, edges = choose_peaks(W, brief, sites, edges, mid, mountainous, land_avoid, notes)
    grow_peaks(W, brief, sites, peaks, mid, n, notes)
    lay_roads(W, sites, edges, n)
    if top:
        notes.append("terraces: district plinths 0-%d layers (%s)" % (top, ", ".join(
            "%d" % W.plinth[i] for i in range(len(sites)))))
    weights = _weights(brief)
    kinds = {}
    counts = {}
    basin = basin_share(W, n, brief["seed"])
    W.basin = basin
    for i in range(len(sites)):
        if i == mid:
            kinds[i] = "plaza"
        else:
            w = {k: v * landform.kind_factor(k, W.plinth_shape.get(i, 0), top)
                 for k, v in weights.items()}
            if w.get("lake"):
                w["lake"] *= 1.0 + LAKE_BASIN * basin.get(i, 0.0)
            for kk, v in counts.items():
                if v >= max(2, len(sites) // 3):
                    w[kk] = 0
            kinds[i] = _pick(r, w) if sum(w.values()) > 0 else "garden"
        counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    for i in peaks:
        kinds[i] = "hills"
    volcano_at = None
    volcano_mid = False
    vol_anchor = next((a_ for a_ in brief["anchors"] if a_["what"] == "volcano"), None)
    lava_volcano = lava_world and "volcano" not in land_avoid and brief["size"] not in (
        "tiny", "small") and len(sites) >= 5
    if "volcano" in land_want or vol_anchor is not None or lava_volcano:
        comp = ((vol_anchor or {}).get("where") or {}).get("compass") or "c"
        if comp in ("c", "centre", "center"):
            volcano_at = mid
            volcano_mid = True
        else:
            def wx(i):
                return off + sites[i][0] * CELL + CELL // 2, off + sites[i][1] * CELL + CELL // 2
            scored = [(common.compass_score(*wx(i), {"compass": comp}), i)
                      for i in range(len(sites))]
            scored = [s for s in scored if s[0] is not None]
            volcano_at = max(scored)[1] if scored else mid
        kinds[volcano_at] = "volcano"
        counts = {}
        for i in kinds:
            counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    if mountainous and not (broad_relief(brief) and peaks):
        size = {}
        for c, d in W.owner.items():
            size[d] = size.get(d, 0) + 1
        hi = W.macro or {}
        order = sorted((i for i in kinds if i != mid and kinds[i] not in ("lake", "volcano")),
                       key=lambda i: (-hi.get(sites[i], 0), -size.get(i, 0), i))
        for i in order[:2]:
            if kinds[i] != "hills":
                kinds[i] = "hills"
                notes.append("mountains: district %d is a mountain" % i)
        counts = {}
        for i in kinds:
            counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    if theme_world(brief)["liquid"] == "lava" and (land_want & {"lava", "water"} or (
            lava_world and not (land_avoid & {"lava", "water"}))):
        for i in ensure_lakes(kinds, W.owner, volcano_at if volcano_at is not None else mid, 1,
                              W.basin):
            notes.append("lava: district %d is a lava lake" % i)
        counts = {}
        for i in kinds:
            counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    levels = "water_levels" in common.want_avoid(brief)[0]
    if levels:
        for i in ensure_lakes(kinds, W.owner, mid, 2, W.basin):
            notes.append("water at two heights: district %d is a lake (a second pool)" % i)
        counts = {}
        for i in kinds:
            counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    if broad_relief(brief):
        hi_ = W.macro or {}
        size_ = {}
        for c, d in W.owner.items():
            size_[d] = size_.get(d, 0) + 1
        hills_ = sorted((i for i in kinds if kinds[i] == "hills" and i not in peaks),
                        key=lambda i: (-size_.get(i, 0), -hi_.get(sites[i], 0), i))
        calmed = hills_[BROAD_HILLS:]
        for k_, i in enumerate(calmed):
            kinds[i] = "forest" if k_ % 2 == 0 else "garden"
        if calmed:
            notes.append("relief: a few large landforms - %d hill district(s) as woods and "
                         "meadows (%d broad hills, %d mountains)" % (
                             len(calmed), len(hills_) - len(calmed), len(peaks)))
        def central(i):
            return (abs(sites[i][0] - n / 2.0) + abs(sites[i][1] - n / 2.0), i)
        vill = sorted((i for i in kinds if kinds[i] == "village"), key=central)
        if not vill and weights.get("village", 0) > 0:
            open_ = sorted((i for i in kinds if kinds[i] in ("garden", "forest", "ruins")
                            and i not in peaks), key=central)
            if open_:
                kinds[open_[0]] = "village"
                vill = [open_[0]]
                notes.append("villages: district %d is one (none was drawn)" % open_[0])
        for k_, i in enumerate(vill[BROAD_VILLAGES:]):
            kinds[i] = "garden" if k_ % 2 == 0 else "forest"
        if len(vill) > BROAD_VILLAGES:
            notes.append("villages: %d full ones (%d districts as meadows and woods)" % (
                BROAD_VILLAGES, len(vill) - BROAD_VILLAGES))
        counts = {}
        for i in kinds:
            counts[kinds[i]] = counts.get(kinds[i], 0) + 1
    by = {}
    for c, d in W.owner.items():
        if c not in W.streets:
            by.setdefault(d, []).append(c)
    from .. import landscape as _lsb
    wet_cells = set(W.river) | set(W.valley) | set(
        c for c, d in W.owner.items() if kinds.get(d) == "lake")
    wet = {}
    for d, cs in by.items():
        near = sum(1 for c in cs if any((c[0] + a, c[1] + b) in wet_cells
                                       for a in range(-2, 3) for b in range(-2, 3)))
        wet[d] = min(1.0, near / max(1.0, len(cs) * 0.35))
    W.biome = _lsb.biomes(common.theme_of(brief), {d: W.plinth.get(d, 0) for d in kinds},
                          max(1, max(W.plinth.values() or [1])), wet, streams("biomes"),
                          kinds, W.preset)
    for d, k in kinds.items():
        if k == "volcano" and "volcanic" in _lsb.BIOMES:
            W.biome[d] = "volcanic"
    _have_b = kit.textures()
    _top_b = {d: _lsb.biome_top(b, _have_b) for d, b in W.biome.items()}
    for c, d in W.owner.items():
        if _top_b.get(d):
            W.biome_tex[c] = _top_b[d]
    notes.append("biomes: %s" % ", ".join("%s %d%%" % (b, round(100 * v)) for b, v in
                                          _lsb.biome_share(W.biome, W.owner).items()))
    accents = pal["accents"]
    from .. import contract
    ctheme = common.theme_of(brief)
    walls = contract.variants(ctheme, "building_wall", pal, ("building", "wall"), 4) \
        or [pal["wall"]]
    tex_of = {i: walls[i % len(walls)] for i in range(len(sites))}
    built = list(pal.get("accents_built") or accents)
    spire_of = {i: built[i % len(built)] for i in range(len(sites))}
    order = sorted(range(len(sites)), key=lambda i: (kinds[i] != "plaza", i))
    did = {}
    hedged = 0
    if brief["family"] == "hide":
        hedge_tex = pal.get("hedge") or pal["cover"]
        for i in sorted(by):
            cs = set(by[i])
            rim = sorted(c for c in cs if any((c[0] + a, c[1] + b) in W.streets
                                              for a, b in pcg.N4))
            for k, c in enumerate(rim):
                if k % 5 == 2 or c in W.road or not W.free(c):
                    continue
                W.solid[c] = (600, hedge_tex, "hedge")
                hedged += 1
    size_name = brief["size"] if isinstance(brief["size"], str) else "large"
    peak_top = MOUNTAIN_TOP.get(size_name, 13) if MESH_GROUND else None
    auto_peaks = set(i for i in peaks if kinds.get(i) == "hills")
    from .. import landmarks
    rl = streams("landmarks")
    theme = brief["theme"] if brief["theme"] not in (None, "auto") else "garden"
    wished_lm = [landmarks.FEATURE_KIND[f] for f in sorted(land_want)
                 if f in landmarks.FEATURE_KIND]
    lm_pal = landmark_pal(W, pal, ctheme)
    if theme_world(brief)["liquid"] == "lava":
        rock = theme_world(brief)["rock"]
        if rock in kit.textures():
            lm_pal["wall"] = rock
    for i in order:
        cs = sorted(by.get(i, []))
        if not cs:
            continue
        kind = kinds[i]
        rd = streams("district.%d" % i)
        if kind == "village":
            did[i] = district_village(W, cs, rd, brief, tex_of[i], pal, sites[i], i,
                                      counts.get("village", 1))
        elif kind == "hills":
            did[i] = district_hills(W, cs, rd, brief["seed"],
                                    mountains=mountainous or i in auto_peaks,
                                    top=peak_top, entry=(n // 2, n // 2),
                                    broad=broad_relief(brief) and i not in auto_peaks)
        elif kind == "forest":
            did[i] = district_forest(W, cs, rd, W.biome.get(i), sites[i])
        elif kind == "ruins":
            worn = "mossyrock" if "mossyrock" in kit.textures() else pal["wall"]
            did[i] = district_ruins(W, cs, rd, worn)
        elif kind == "garden":
            did[i] = district_garden(W, cs, rd, pal.get("hedge") or pal["cover"])
        elif kind == "lake":
            did[i] = district_lake(W, cs, sites[i],
                                   1 if theme_world(brief)["liquid"] == "lava" else 2)
        elif kind == "volcano":
            rock = theme_world(brief)["rock"]
            if rock not in kit.textures():
                rock = pal.get("keel") or pal["wall"]
            if volcano_mid:
                ring = [c for c in cells if max(abs(c[0] - n // 2), abs(c[1] - n // 2))
                        <= max(3, min(VOLCANO_R, n // 6))]
                did[i] = district_volcano(W, ring, (n // 2, n // 2), rock, clear_streets=True)
            else:
                did[i] = district_volcano(W, cs, sites[i], rock)
        elif i == mid:
            did[i] = district_plaza(W, cs, sites[i], spire_of[i], grand=True)
            if not did[i]:
                for j in sorted((k for k in by if k != i and kinds[k] not in
                                 ("lake", "volcano")),
                                key=lambda k: (abs(sites[k][0] - n / 2.0)
                                               + abs(sites[k][1] - n / 2.0), k)):
                    if district_plaza(W, sorted(by[j]), sites[j], spire_of[i], grand=True):
                        notes.append("the grand spire stands on district %d (the middle "
                                     "had no level place)" % j)
                        did[i] = 1
                        break
        else:
            kind_l = landmarks.pick(rl, theme, [x["kind"] for x in W.landmarks], wished_lm,
                                tier="secondary")
            did[i] = district_landmark(W, cs, sites[i], rl, lm_pal, kind_l) or \
                district_plaza(W, cs, sites[i], spire_of[i], grand=False)
    if W.valley and "valley" in land_want or (W.valley and mountainous):
        shape_valley(W)
    settle_hills(W)
    np_early = []
    lay_landforms(W, brief, kinds, by, streams("landforms"), notes, np_early)
    if "caves" in land_want:
        lay_caves(W, None)
    extra = {"large": 1, "huge": 2, "gigantic": 3}.get(brief["size"], 0) \
        if isinstance(brief["size"], str) else 1
    if "landmarks" in land_want:
        extra += 2
    if brief["family"] == "hide":
        extra = min(extra, 1)
    extra = max(extra, len([k for k in wished_lm
                            if k not in [x["kind"] for x in W.landmarks]]))
    high = [i for i in kinds if i != mid and kinds[i] in ("hills", "ruins", "forest",
                                                          "garden", "village")]
    from .. import viewshed
    seen_by = viewshed.counts(W.total(), viewshed.thin(W.road), {i: sites[i] for i in high},
                              eye=1, rise=6)
    high = sorted(high, key=lambda i: (-W.plinth.get(i, 0), -seen_by.get(i, 0), i))
    for i in high:
        if extra <= 0:
            break
        cs = sorted(by.get(i, []))
        kind_l = landmarks.pick(rl, theme, [x["kind"] for x in W.landmarks], wished_lm,
                                tier="secondary")
        if district_landmark(W, cs, sites[i], rl, lm_pal, kind_l):
            extra -= 1
    for kind_w in [k for k in wished_lm if k not in [x["kind"] for x in W.landmarks]]:
        for i in sorted((i for i in kinds if i != mid and kinds[i] != "volcano"),
                        key=lambda i: (kinds[i] != "lake", -W.plinth.get(i, 0), i)):
            if district_landmark(W, sorted(by.get(i, [])), sites[i], rl, lm_pal, kind_w):
                break
    from .. import settlements
    W.ladder = settlements.hierarchy(W, notes)
    W.hero_way = hero_road(W, notes)
    if W.landmarks:
        notes.append("landmarks: %s" % ", ".join(x["kind"] for x in W.landmarks))
    for s in W.settlements:
        notes.append("settlement: %s on district %d - anchor %s, %d houses (%s), prefabs %s"
                     % (s["name"], s["district"], s["anchor"], s["houses"],
                        ", ".join(s["recipes"]) or "none", ", ".join(s["prefabs"]) or "none"))
    if W.hills:
        notes.append("terrain: hills up to %d layers (%d high)" % (max(W.hills.values()),
                                                                   200 * max(W.hills.values())))
    if W.river:
        notes.append("river: %d cells from its source to the world's edge (%d bridges, "
                     "%d weirs)" % (len(W.river), len(W.bridges), len(W.weirs)))
    if W.caves:
        notes.append("caves: %d passages through the high ground (%s cells)"
                     % (len(W.caves), ", ".join(str(len(c)) for c in W.caves)))
    if W.road_info:
        climbs = sum(x[0] for x in W.road_info)
        turns = sum(x[1] for x in W.road_info)
        notes.append("roads: %d climbs, %d turns at landings, %d bridge cells"
                     % (climbs, turns, len(W.bridges)))
    notes.append("world %d across: %d districts (%s), %d roads" % (
        n * CELL, len(sites), ", ".join("%s %d" % (kk, v) for kk, v in sorted(counts.items())),
        len(edges)))
    gu4_ctx, gu4_pieces, gu4_objects, gu4 = None, [], [], None
    if "decor" not in common.want_avoid(brief)[1]:
        from .. import networks
        gu4_ctx = networks.Ctx(W, brief, sites, edges, kinds, mid, streams("paths"), pal, lift,
                               off, CELL, level_y, contract.theme_for(brief))
        gu4_pieces, gu4_objects, gu4 = networks.dress(gu4_ctx)
        notes.append(networks.describe(gu4))
        from .. import gameplay as gp
        shut = gp.forge_off(brief)
        gu4_objects = [dict({k: v for k, v in o.items() if k != "pattern"},
                            dressing=o.get("pattern"))
                       for o in gu4_objects if gp.category_of(o["key"]) not in shut]
    gu4_kept = [gu4_pieces]
    from .. import landform
    slope_budget = [max(16, min(110, int(0.2 * brief["budget"])))]
    stairs_kinds = set(i for i, k in kinds.items() if k in ("village", "plaza"))
    burning = (set(W.river) | set(W.lake)) if theme_world(brief)["liquid"] == "lava" else set()
    def shape_now():
        T = W.total()
        free = set(c for c in T if c not in W.solid and c not in W.lake and c not in W.river
                   and c not in W.cuts and c not in W.roofs and c not in W.bridges)
        pits = set(c for c in W.lowered if c in T and all(
            T.get((c[0] + a_, c[1] + b_), -1) > T[c] for a_, b_ in pcg.N4))
        landform.repair(T, free - (W.lowered - pits))
        for c in sorted(pits & free):
            up = min(T[(c[0] + a_, c[1] + b_)] for a_, b_ in pcg.N4)
            if T[c] < up:
                T[c] = up
        for comp, up in pockets(T, free, burning):
            for c in comp:
                T[c] = up
        for c in free:
            if T[c] != W.T(c):
                W.base[c] = W.base.get(c, 0) + (T[c] - W.T(c))
        forced = {c: ("ramp", d) for c, d in W.ramps.items() if c in free}
        stairs = set(c for c in free if W.owner.get(c) in stairs_kinds)
        W.shapes = landform.autoshape(T, free, route=set(W.road) | set(W.footpath)
                                      | (W.rolling & free),
                                      forced=forced,
                                      budget=slope_budget[0], stairs_cells=stairs,
                                      clear=free | set(W.road) - set(W.solid))
        return T
    def make_raw():
        box, ramp = kit.kind("box").make, kit.kind("ramp").make
        raw = []
        if info["floor"] is None:
            step = 6000
            x = -half
            while x < half:
                z = -half
                while z < half:
                    raw.append(box(pal["floor"], x, min(half, x + step), -200, 0, z,
                                   min(half, z + step), None, "ground"))
                    z += step
                x += step
        X = lambda i: off + i * CELL
        T = shape_now()
        def Y(c):
            return level_y(T.get(c, 0), lift)
        shaped = W.shapes
        for c in sorted(W.road):
            if c in shaped or c in W.bridges:
                continue
            raw.append(box(pal["road"], X(c[0]), X(c[0] + 1), Y(c), Y(c) + 20,
                           X(c[1]), X(c[1] + 1), None, "road"))
        floor_tex = pal["floor"]
        ground = []
        groups = {}
        from .. import landscape as _ls
        _have = kit.textures()
        _riser = {}
        def riser_of(k):
            if not W.bands or len(W.bands) < 2:
                return None
            if k not in _riser:
                _riser[k] = _ls.riser_tex(ctheme, k, _have)
            return _riser[k]
        banded = bool(W.bands and len(W.bands) > 1)
        columns = {}
        for k, cs in sorted(landform.plates(T, skip=W.roofs).items()):
            for c in cs:
                b = W.base.get(c, 0)
                if banded and c not in W.roofs and c not in W.top_tex and c not in W.cuts \
                        and k < T[c]:
                    columns.setdefault((T[c], "terrace" if T[c] <= b else "hills"),
                                       set()).add(c)
                    continue
                if c in W.roofs and k > min(W.roofs[c]):
                    tag = "cave.top" if k == T[c] else "cave.roof"
                elif c in W.top_tex:
                    tag = "volcano"
                else:
                    tag = "terrace" if k <= b else "hills"
                groups.setdefault((k, W.top_tex.get(c) or W.biome_tex.get(c, floor_tex), tag),
                                  set()).add(c)
        _riser_b = {}
        for d_, bname in W.biome.items():
            _riser_b[d_] = _ls.biome_riser(bname, _have)
        by_rock = {}
        for (b, what), cs in sorted(columns.items()):
            for c in cs:
                t = _riser_b.get(W.owner.get(c)) or riser_of(b - 1) or floor_tex
                by_rock.setdefault((b, what, t), set()).add(c)
        for (b, what, tex), cs in sorted(by_rock.items()):
            for (i0, j0, i1, j1) in landform.merge_rects(cs):
                ground.append(box(tex, X(i0), X(i1), 0 if lift else level_y(0, lift),
                                  level_y(b - 1, lift), X(j0), X(j1), None, what + ".rock"))
        _runtime = v1.arenas_module().block_slugs() \
            if hasattr(v1.arenas_module(), "block_slugs") else set()
        for (k, tex, tag), cs in sorted(groups.items()):
            rects = landform.merge_rects(cs)
            if PLATE_SIDES and budget >= PLATE_SIDES_FROM and tex not in _runtime:
                rects = landform.alphabet(rects, PLATE_SIDES)
            y0 = 0 if (k == 1 and lift) else level_y(k - 1, lift)
            for (i0, j0, i1, j1) in rects:
                ground.append(box(tex, X(i0), X(i1), y0, level_y(k, lift),
                                  X(j0), X(j1), None, tag))
        for crater in W.craters:
            for c in crater:
                t = Y(c)
                raw.append(box("lava", X(c[0]), X(c[0] + 1), t, t + 40, X(c[1]), X(c[1] + 1),
                               None, "volcano.lava"))
        _slope_b = {d_: _ls.biome_slope(b_, _have) for d_, b_ in W.biome.items()}
        peak_way = set(c for pk in W.peaks for c in pk["path"])
        def slope_tex(c):
            kind = shaped[c][0]
            if c in peak_way:
                return _slope_b.get(W.owner.get(c)) or pal.get("road") or floor_tex
            if c in W.road or c in W.ramps or "stairs" in kind:
                return pal.get("road") or W.top_tex.get(c, floor_tex)
            return W.top_tex.get(c) or _slope_b.get(W.owner.get(c)) or floor_tex
        for kind, facing, (i0, j0, i1, j1), lv_, tex in landform.ramp_runs(shaped, T,
                                                                            slope_tex):
            b0 = level_y(lv_, lift)
            c0 = (i0, j0)
            ground.append(kit.kind(kind).make(tex, X(i0), X(i1), b0, level_y(lv_ + 1, lift), X(j0), X(j1),
                                              facing, "hills.ramp" if c0 in W.ramps
                                              else "slope"))
        W.ground_pieces = ground
        surface = ([s for s, t in kit.textures().items() if "water" in t["roles"]]
                   or ["ice"])[0]
        liquid = theme_world(brief)["liquid"]
        rim_tex = pal["wall"]
        waters = []
        import random as _random
        from .. import basins
        raise_set = raised_ponds(W.waters, levels)
        W.pond_rings = set()
        def shore(p_):
            t_ = str(p_.get("tag", ""))
            if t_ in ("lake.rim", "lake.bank"):
                p_ = dict(p_, tag=t_ + ".shore")
            return p_
        def land_beside(i0, j0, i1, j1):
            from collections import Counter
            got = Counter()
            for a in range(i0 - 1, i1 + 1):
                for b in (j0 - 1, j1):
                    t_ = W.top_tex.get((a, b))
                    if t_:
                        got[t_] += 1
            for b in range(j0, j1):
                for a in (i0 - 1, i1):
                    t_ = W.top_tex.get((a, b))
                    if t_:
                        got[t_] += 1
            return got.most_common(1)[0][0] if got else None
        natural = MESH_GROUND
        for k, (i0, j0, i1, j1) in enumerate(W.waters):
            x0, x1, z0, z1 = X(i0), X(i1), X(j0), X(j1)
            raised = k in raise_set
            ground_y = Y((i0, j0))
            if raised:
                cx_ = (X(i0) + X(i1)) // 2
                foot = [a for a in range(i0, i1) if X(a) < cx_ + 200 and X(a + 1) > cx_ - 200]
                blocked = set(W.solid) | W.lake | W.river | set(W.ramps) | set(W.cuts) | W.flank
                if j1 >= W.n or any(Y((a, j1)) != ground_y or (a, j1) in blocked
                                    for a in foot):
                    raised = False
            base = ground_y
            if raised:
                base = ground_y + POND_RAISE
                cx = (x0 + x1) // 2
                if natural:
                    pod_tex = land_beside(i0, j0, i1, j1) or W.top_tex.get((i0, j0)) or floor_tex
                    pod_rock = _ls.riser_tex(ctheme, 0, _have) or rim_tex
                    raw.append(box(pod_rock, x0, x1, ground_y, base - 200, z0, z1 - 1200, None,
                                   "pond.podium"))
                    raw.append(box(pod_tex, x0, x1, base - 200, base, z0, z1 - 1200, None,
                                   "pond.podium"))
                else:
                    raw.append(box(rim_tex, x0, x1, ground_y, base, z0, z1 - 1200, None,
                                   "pond.podium"))
                raw.append(kit.kind("ramp").make(pal.get("road") or rim_tex, cx - 200, cx + 200,
                                                 ground_y, base, z1 - 1200, z1, "-z", "pond.ramp"))
                top_j = j1 - 1200 // CELL
                for a in range(i0 - 1, i1 + 1):
                    for b in range(j0 - 1, j1 + 1):
                        if not (i0 <= a < i1 and j0 <= b < top_j):
                            W.pond_rings.add((a, b))
                z1 = z1 - 1200
            fits = basins.basin_depths(min(x1 - x0, z1 - z0),
                                       basins.NATURAL_RIM if natural else basins.BASIN_RIM)
            if raised and (liquid == "lava" or not fits):
                for n_, q_ in enumerate(raw):
                    if q_.get("tag") == "pond.ramp" and q_.get("y") == ground_y and \
                            abs(q_["z"] - (z1 + 600)) < 1 and abs(q_["x"] - (x0 + x1) // 2) < 1:
                        raw[n_] = kit.kind("ramp").make(q_["tex"], q_["x"] - 200, q_["x"] + 200,
                                                        ground_y, base + POOL_DEPTH, z1, z1 + 1200,
                                                        "-z", "pond.ramp")
            if liquid != "lava" and fits:
                if info["floor"] is None and not raised and ground_y <= lift:
                    raw.append(box(pal["keel"], x0 + 100, x1 - 100, -200, 0, z0 + 100, z1 - 100,
                                   None, "lake.bed"))
                depth = _random.Random("%s/lake/%d" % (brief["seed"], k)).choice(fits)
                bank_tex = W.top_tex.get((i0, j0)) or W.biome_tex.get((i0, j0), floor_tex)
                floor_y = (info["floor"] or 0) if (not raised and ground_y <= lift) else base
                if natural:
                    land = land_beside(i0, j0, i1, j1) or bank_tex
                    bed_tex = _ls.biome_slope(W.biome.get(W.owner.get((i0, j0)), "meadow"),
                                              _have) or land
                    ps_, row = basins.lake_basin(x0, x1, z0, z1, base, depth, land, land,
                                                 bed_tex, surface, "lake", floor=floor_y,
                                                 rim=basins.NATURAL_RIM)
                    ps_, row = basins.natural_shore(ps_, row, land, "%s/%d" % (brief["seed"], k))
                else:
                    ps_, row = basins.lake_basin(x0, x1, z0, z1, base, depth, bank_tex, rim_tex,
                                                 rim_tex, surface, "lake", floor=floor_y)
                raw.extend(ps_)
                waters.append(row)
                continue
            top = base + POOL_DEPTH
            R = 200 if natural else 100
            for (a0, a1, b0, b1) in ((x0, x1, z0, z0 + R), (x0, x1, z1 - R, z1),
                                     (x0, x0 + R, z0 + R, z1 - R),
                                     (x1 - R, x1, z0 + R, z1 - R)):
                if natural:
                    bank_ = land_beside(i0, j0, i1, j1) or W.top_tex.get((i0, j0)) or floor_tex
                    raw.append(shore(box(bank_, a0, a1, base, top, b0, b1, None, "lake.rim")))
                else:
                    raw.append(box(rim_tex, a0, a1, base, top, b0, b1, None, "lake.rim"))
            if info["floor"] is None and not raised and ground_y <= lift:
                raw.append(box(pal["keel"], x0 + R, x1 - R, -200, 0, z0 + R, z1 - R,
                               None, "lake.bed"))
            wtop = top - WATER_DROP
            if liquid == "lava":
                raw.append(box("lava", x0 + R, x1 - R, base, wtop, z0 + R, z1 - R,
                               None, "lake.lava"))
                continue
            raw.append(kit.kind("water").make(surface, x0 + R, x1 - R, wtop - 20, wtop,
                                              z0 + R, z1 - R, None, "lake.water"))
            waters.append([x0 + R, z0 + R, x1 - R, z1 - R, wtop, base])
        weir_cells = set(a for a, b in W.weirs)
        by_level = {}
        for c in W.river:
            if c in weir_cells:
                continue
            by_level.setdefault(W.river_level.get(c, 0), set()).add(c)
        for lv_, cs in sorted(by_level.items()):
            for (i0, j0, i1, j1) in river_rects(cs):
                x0, x1, z0, z1 = X(i0), X(i1), X(j0), X(j1)
                floor_y = level_y(lv_, lift)
                bed = floor_y if (lv_ or info["floor"] is None) else info["floor"]
                wtop = floor_y + RIVER_SURFACE
                if liquid == "lava":
                    raw.append(box("lava", x0, x1, floor_y, wtop, z0, z1, None, "river.lava"))
                    continue
                raw.append(kit.kind("water").make(surface, x0, x1, wtop - 20, wtop, z0, z1, None,
                                                  "river.water"))
                waters.append([x0, z0, x1, z1, wtop, bed])
        stone = pal.get("trim") or rim_tex
        for (a, b) in W.weirs:
            up = level_y(W.river_level.get(a, 0), lift)
            raw.append(box(stone, X(a[0]), X(a[0] + 1), up, up + RIVER_SURFACE + 30,
                           X(a[1]), X(a[1] + 1), None, "weir"))
        deck_tex = "darkplanks" if "darkplanks" in kit.textures() else pal["road"]
        gu4_bridge, gu4_bridged = getattr(W, "gu4_bridges", ([], set()))
        for p in gu4_bridge:
            ground.append(dict(p))
        for c in sorted(W.bridges):
            if c in gu4_bridged:
                continue
            dy = level_y(W.river_level.get(c, 0) + 1, lift)
            raw.append(box(deck_tex, X(c[0]), X(c[0] + 1), dy - 30, dy, X(c[1]), X(c[1] + 1),
                           None, "bridge"))
        W.water_boxes = waters
        import random as _random
        from .. import flora
        tree_set = set(W.trees)
        _have_t = kit.textures()
        for c in W.trees:
            cx, cz = X(c[0]) + CELL // 2, X(c[1]) + CELL // 2
            g = Y(c)
            sp = W.tree_kind.get(c, "oak")
            room_c = flora.crown_room(c, lambda m, c=c: W.free(m) and m not in tree_set
                                      and T.get(m, 0) <= T.get(c, 0))
            rnd_c = _random.Random("%s/tree/%d/%d" % (brief["seed"], c[0], c[1]))
            ground += flora.build(sp, cx, cz, g, rnd_c, room=room_c, have=_have_t)
        from .. import settlements
        hp, sp_extra = settlements.world_pieces(W, X, Y, pal, ctheme)
        ground.extend(hp)
        ground.extend(sp_extra)
        from .. import prefablib
        theme = brief["theme"] if brief["theme"] != "auto" else "garden"
        for pf in W.prefabs:
            got = prefablib.find(pf["key"])
            if got is None:
                continue
            pp, _ = prefablib.lay(got, X(pf["cell"][0]), X(pf["cell"][1]), Y(pf["cell"]),
                                  pf["turn"], theme)
            raw += pp
        from .. import landrecipes as LR
        rf = streams("landform pieces")
        for lf in W.landforms:
            rec = lf["recipe"]
            if rec not in ("mesa", "arch", "waterfall", "dunes"):
                continue
            (ci, cj), (fa, fb) = lf["cell"], lf["foot"]
            g = Y((ci, cj))
            bname = W.biome.get(lf.get("district"), "meadow")
            rock = _ls.biome_riser(bname, _have) or pal["wall"]
            rock2 = _ls.riser_tex(ctheme, 4, _have) or rock
            if rec == "mesa":
                cap = "sandstonelayered" if "sandstonelayered" in _have else rock2
                raw += LR.mesa(X(ci), X(cj), fa, fb, g, rf, rock, rock2, cap)[0]
            elif rec == "arch":
                raw += LR.arch(X(ci), X(cj), fa >= 3, g, rf, rock, rock)[0]
            elif rec == "waterfall":
                ps_, pool = LR.waterfall(X(ci), X(cj), g, rf, rock, surface, rock)
                raw += ps_
                waters.append(pool)
            elif rec == "dunes":
                sand = _ls.biome_top(bname, _have) or "sand"
                raw += LR.dunes(X(ci), X(cj), fa, fb, g, rf, sand)
        for c in W.rocks:
            import random as _random
            bname = W.biome.get(W.owner.get(c), "meadow")
            rtex = _ls.biome_riser(bname, _have) or pal["wall"]
            raw += _ls.boulder(X(c[0]) + CELL // 2, X(c[1]) + CELL // 2, Y(c),
                               _random.Random("%s/rock/%d/%d" % (brief["seed"], c[0], c[1])), rtex)
        if getattr(W, "cave_info", None):
            from .. import caves as worm
            ground.extend(worm.pieces(W, X, lambda k: level_y(k, lift), worm.floor_tex(pal, _have),
                                      worm.rock_tex(W, pal, _ls, _have), ctheme, pal))
        for (i, j), (h, tex, kind) in sorted(W.solid.items()):
            if kind in ("house", "tree", "spire", "landmark", "landform", "rock") or not h:
                continue
            g = Y((i, j))
            raw.append(box(tex, X(i), X(i + 1), g, g + h, X(j), X(j + 1), None, kind))
        from ..kitpass import octagon_pieces
        for sp in W.spires:
            cx, cz = X(sp["cell"][0]) + CELL // 2, X(sp["cell"][1]) + CELL // 2
            a = sp["a"]
            g = Y(sp["cell"])
            deck = 400
            dh = 2 * CELL + CELL // 2
            raw.append(box(pal["pad"], cx - dh, cx + dh, g, g + deck,
                           cz - dh, cz + dh, None, "spire.deck"))
            ways = [((cx - 200, cx + 200, cz + dh, cz + dh + 800), "-z", (cx, cz + dh + 800)),
                    ((cx - 200, cx + 200, cz - dh - 800, cz - dh), "+z", (cx, cz - dh - 800)),
                    ((cx + dh, cx + dh + 800, cz - 200, cz + 200), "-x", (cx + dh + 800, cz)),
                    ((cx - dh - 800, cx - dh, cz - 200, cz + 200), "+x", (cx - dh - 800, cz))]
            (sx0, sx1, sz0, sz1), rises, _ = next(
                (w for w in ways if max(abs(w[2][0]), abs(w[2][1])) <= half - SPIRE_EDGE_ROOM),
                ways[0])
            raw.append(kit.kind("ramp").make(pal["road"], sx0, sx1, g, g + deck,
                                               sz0, sz1, rises, "spire.stairs"))
            for p in octagon_pieces(sp["tex"], a, g + deck, g + deck + sp["h"], "spire"):
                p = dict(p, x=p["x"] + cx, z=p["z"] + cz)
                ground.append(p)
        for lm in W.landmarks:
            c = lm["cell"]
            g, lx, lz = Y(c), X(c[0]) + CELL // 2, X(c[1]) + CELL // 2
            for p in lm["pieces"]:
                ground.append(dict(p, x=p["x"] + lx, y=p["y"] + g, z=p["z"] + lz))
        if gu4_ctx is not None:
            from .. import networks
            ways = networks.strips(gu4_ctx, shaped)
            ground.extend(ways)
            gu4_solid = [p for p in raw + ground if p is not None]
            from .. import decor as decormod
            def on_ground(p):
                c = (int((p["x"] - off) // CELL), int((p["z"] - off) // CELL))
                r = decormod.BY_KEY.get(p.get("decor"))
                if r is None:
                    if str(p.get("tag", "")) == "climb.vine" and p["y"] != Y(c):
                        return None
                    return dict(p)
                return dict(p, y=Y(c) + (r.get("base") or 0))
            props_now = [q for q in (on_ground(p) for p in gu4_kept[0]) if q is not None]
            ground.extend(networks.clear_of(props_now, ways, gu4_solid))
        rim_top = max([T.get(c, 0) for c in T if c[0] in (0, n - 1) or c[1] in (0, n - 1)]
                      or [0])
        e0, e1 = -half - 200, half + 200
        wall_h = (WALL_H if brief["edge"] != "rails" else 160) + 200 * rim_top
        rects = ((e0, e1, e0, -half), (e0, e1, half, e1), (e0, -half, -half, half),
                 (half, e1, -half, half))
        foot = lift - (200 if lift else 0) if info["floor"] is not None else -200
        if brief["edge"] == "rails":
            for (x0, x1, z0, z1) in rects:
                raw.append(box(pal["wall"], x0, x1, foot, lift + wall_h, z0, z1, None, "edge"))
        else:
            raw += boundary.walls(box, edge_mode[0], rects, foot, lift, lift + wall_h,
                                  pal["wall"], "edge",
                                  top=boundary.top_of([p for p in raw + ground if p is not None]))
        return [p for p in raw if p is not None]
    budget = brief["budget"]
    edge_mode = ["invisible"]
    compiled = {}
    def compile_world():
        raw = make_raw()
        key = json.dumps(raw, sort_keys=True, default=str)
        if key not in compiled:
            compiled.clear()
            compiled[key] = compile_pieces(raw)
        out = [dict(p) for p in compiled[key]]
        m = v1.arenas_module()
        for p in W.ground_pieces:
            p = dict(p)
            p["model"] = m.model_name(p)
            out.append(p)
        from .. import basins as _bs, heightfield as _hf
        land = _bs.mound_texture({"terrain": {"mesh": True}, "pieces": out}) or pal["floor"]
        for p in _bs.liquid_banks(out, info["floor"], land,
                                  sheets=[q for q in out if MESH_GROUND and _hf.is_sheet(q)]):
            p["model"] = m.model_name(p)
            out.append(p)
        return out
    def compile_with(mode):
        edge_mode[0] = mode
        return compile_world()
    edge_mode[0], pieces = boundary.choose(brief, compile_with, budget)
    if brief["edge"] != "rails":
        notes.append("edge: %s" % boundary.describe(edge_mode[0]))
    natural = set(i for i, k in kinds.items() if k in ("hills", "forest", "garden", "ruins"))
    def fill_trees(pieces, cap, why):
        room = cap - budget_count(pieces)
        if "trees" in common.want_avoid(brief)[1] or not theme_world(brief)["trees"]:
            return pieces
        if len(W.trees) < TREES_KEPT:
            room = max(room, 3 * (TREES_KEPT - len(W.trees)))
        if room <= 12:
            return pieces
        where = natural or set(kinds) - set(k for k, v in kinds.items()
                                            if v in ("lake", "volcano", "plaza"))
        open_ground = [c for c in cells if W.owner.get(c) in where and W.free(c)
                       and c not in W.hills]
        from .. import flora, landscape as _lsf
        by_b = {}
        for c in open_ground:
            by_b.setdefault(W.biome.get(W.owner.get(c), "meadow"), []).append(c)
        rt = streams("trees " + why)
        extra = []
        for bname, cs in sorted(by_b.items()):
            sparse = _lsf.BIOMES.get(bname, _lsf.BIOMES["meadow"])["sparse"]
            if not sparse:
                continue
            share = room * len(cs) / float(len(open_ground) or 1)
            limit = int(share / flora.mean_pieces(sparse) * tree_share(brief))
            extra += flora.groves(cs, rt, sparse, limit)
        laid = 0
        for c, sp in extra:
            if W.free(c):
                W.solid[c] = (flora.height_of(sp), None, "tree")
                W.trees.append(c)
                W.tree_kind[c] = sp
                laid += 1
        if laid:
            pieces = compile_world()
            notes.append("%d trees fill the budget's room%s, in groves" % (laid, why))
        return pieces
    pieces = fill_trees(pieces, int(0.92 * budget), "")
    def fill_rocks(pieces, cap):
        room = cap - budget_count(pieces)
        if room <= 8 or not natural:
            return pieces
        from .. import landscape as _lsr
        T_ = W.total()
        feet = [c for c in _lsr.cliff_feet(T_, sorted(T_))
                if W.owner.get(c) in natural and W.free(c) and c not in W.hills]
        want = min(len(feet), room // 3, {"tiny": 0, "small": 2, "medium": 3, "large": 5,
                                          "huge": 7, "gigantic": 9}.get(
                                              brief["size"] if isinstance(brief["size"], str)
                                              else "large", 4))
        if want <= 0:
            return pieces
        picked = pcg.poisson_disk(feet, 3.0, streams("rocks"), limit=want)
        for c in picked:
            if W.free(c):
                W.solid[c] = (400, None, "rock")
                W.rocks.append(c)
        if picked:
            pieces = compile_world()
            notes.append("rocks: %d boulders at cliff feet" % len(picked))
        return pieces
    pieces = fill_rocks(pieces, int(0.92 * budget))
    dropped = []
    hide_family = brief["family"] == "hide"
    thin = ("tree", "decor", "decor", "decor", "ruin", "hedge", "slopes", "landmark",
            "house_half", "terrace_once", "house", "terraces", "hills", "road")
    if "buildings" in land_want:
        thin = ("tree", "decor", "decor", "decor", "ruin", "hedge", "slopes", "landmark",
                "terraces", "house_half", "hills", "house", "road")
    if brief["family"] == "hide":
        thin = ("tree", "decor", "decor", "decor", "slopes", "hills", "terraces", "road",
                "ruin", "house", "hedge")
    elif len(W.bands or ()) > 1 and not (land_want & {"buildings", "roads", "village"}) \
            and brief.get("preset") != "village":
        thin = ("tree", "decor", "decor", "decor", "ruin", "hedge", "slopes", "landmark",
                "house_half", "house", "road", "hills", "terraces")
    thin = tuple(thin) + ("hills_all",)
    if MESH_GROUND:
        thin = tuple(s_ for s_ in thin if s_ not in GROUND_STEPS)
    target = budget - (0 if hide_family else (
        max(GAMEPLAY_ROOM, budget // 10) if budget >= 500 else GAMEPLAY_ROOM))
    target -= len(gu4_objects)
    line = structure_line(brief)
    if line is not None:
        target = min(target, line - STRUCTURE_ROOM - len(gu4_objects))
        thin = line_thin(thin)
    houses0 = len(W.houses)
    houses_kept = min(houses0, HOUSES_KEPT) if (land_want & {"buildings", "village"} or
                                                 brief.get("preset") == "village") else 0
    decor_step = [0]
    def _drop_house(hs):
        for c in hs["cells"]:
            W.solid.pop(c, None)
        k = hs.get("settlement")
        if k is None or any(h.get("settlement") == k for h in W.houses):
            return
        for lm in [x for x in W.landmarks if x.get("settlement") == k
                   and (x.get("anchor") or x.get("town_gate"))]:
            W.landmarks.remove(lm)
            for c, v in list(W.solid.items()):
                if v[2] == "landmark" and c in _foot_cells(lm):
                    del W.solid[c]
    def _foot_cells(lm):
        if lm.get("cells"):
            return set(lm["cells"]) | {lm["cell"]}
        c, k_ = lm["cell"], lm.get("foot", 3) // 2
        return set((c[0] + a, c[1] + b) for a in range(-k_, k_ + 1) for b in range(-k_, k_ + 1))
    def _kept(x):
        if not (x.get("anchor") or x.get("town_gate")):
            return False
        k = x.get("settlement")
        return k is None or any(h.get("settlement") == k for h in W.houses)
    for step in thin:
        rounds = 0
        what = "terraces" if step == "terrace_once" else step
        while budget_count(pieces) > target and rounds < (1 if step == "terrace_once" else 12):
            rounds += 1
            if what == "tree" and len(W.trees) <= TREES_KEPT:
                break
            if what == "tree" and W.trees:
                for c in W.trees[len(W.trees) // 2:]:
                    W.solid.pop(c, None)
                W.trees = W.trees[:len(W.trees) // 2]
            elif what == "decor" and gu4_ctx is not None and decor_step[0] < 3:
                from .. import networks
                gu4_kept[0], gone = networks.thin(gu4_kept[0], decor_step[0])
                decor_step[0] += 1
                if not gone:
                    break
            elif what in ("ruin", "hedge"):
                cs = [c for c, v in W.solid.items() if v[2] == what]
                if not cs:
                    break
                for c in sorted(cs)[::2]:
                    del W.solid[c]
            elif what == "house_half" and len(W.houses) > houses0 // 2:
                _drop_house(W.houses.pop())
            elif what == "house" and len(W.houses) > houses_kept:
                _drop_house(W.houses.pop())
            elif what in ("hills", "hills_all") and any(c not in W.top_tex and c not in W.roofs
                                                        for c in W.hills):
                top = max(v for c, v in W.hills.items() if c not in W.top_tex
                          and c not in W.roofs)
                down = 2 if len(W.bands or ()) > 1 else 1
                if top <= down and mountainous and what == "hills":
                    break
                for c in [c for c, v in W.hills.items() if v > top - down and c not in W.roofs
                          and c not in W.top_tex]:
                    if top > down:
                        W.hills[c] = top - down
                    else:
                        del W.hills[c]
                valid_ramps(W)
            elif what == "slopes" and slope_budget[0] > 8:
                slope_budget[0] //= 2
            elif what == "terraces" and W.bands and len(W.bands) > 1:
                if not band_down(W, 1 + max(0, budget_count(pieces) - target) // 150):
                    break
            elif what == "terraces" and W.base and max(W.base.values()) > 1:
                lowered = terrace_down(W)
                if not lowered:
                    break
            elif what == "landmark" and any(x["kind"] not in wished_lm and not _kept(x)
                                            for x in W.landmarks[1:]):
                i = max(k for k, x in enumerate(W.landmarks)
                        if k and x["kind"] not in wished_lm and not _kept(x))
                lm = W.landmarks.pop(i)
                c = lm["cell"]
                k_ = lm.get("foot", 3) // 2
                for a in range(-k_, k_ + 1):
                    for b in range(-k_, k_ + 1):
                        if W.solid.get((c[0] + a, c[1] + b), (0, 0, ""))[2] == "landmark":
                            del W.solid[(c[0] + a, c[1] + b)]
            elif what == "road" and W.road:
                W.road = set(sorted(W.road)[::2]) if len(W.road) > 40 else set()
            else:
                break
            dropped.append(what)
            pieces = compile_world()
            if not W.trees and what == "tree":
                break
    if dropped:
        notes.append("budget %d: thinned %s" % (budget, ", ".join(
            "%s x%d" % (w, dropped.count(w)) for w in sorted(set(dropped)))))
        pieces = fill_trees(pieces, min(int(0.92 * budget), target), " the thinning left")
    floor_of = getattr(W, "cave_floor", {})
    kept = [run for run in W.caves
            if all(W.T(x) >= floor_of.get(x, 0) + 1 + CAVE_H // 200 for x in run)]
    if len(kept) < len(W.caves):
        notes.append("caves: %d of %d lost their roof to the budget" % (
            len(W.caves) - len(kept), len(W.caves)))
        W.caves = kept
    pocket_lines = []
    for _ in range(3):
        pk = landform.pockets(pieces)
        if not pk:
            break
        filled = False
        for (x, y, z) in pk:
            c = (int((x - off) // CELL), int((z - off) // CELL))
            run = next((r for r in W.caves if c in r), None)
            if c in W.roofs:
                for x_ in (run or [c]):
                    W.roofs.pop(x_, None)
                if run:
                    W.caves.remove(run)
                filled = True
        if not filled:
            pocket_lines = ["pocket: a floor sealed inside a mass at (%d, %d, %d) - only a "
                            "clip reaches it" % p for p in pk]
            break
        pieces = compile_world()
        notes.append("pockets: %d sealed cave cell(s) filled solid" % len(pk))
    walk = sorted(c for c in (W.streets | W.road) if c not in W.solid and c not in W.lake)
    walk = pcg.largest_component(walk) or walk
    climbs = set((int((p["x"] - off) // CELL), int((p["z"] - off) // CELL))
                 for p in (gu4_kept[0] if gu4 is not None else [])
                 if str(p.get("tag", "")) == "climb.vine")
    plain = set(c for c in walk if c not in W.shapes and c not in W.bridges
                and c not in W.river and c not in climbs)
    first = min(sorted(plain) or walk,
                key=lambda c: (abs(c[0] - n // 2) + abs(c[1] - n // 2), c))
    picks = []
    for c in pcg.farthest_points(walk, 28, streams("spawns"), first=first):
        if c not in plain:
            near = sorted(plain, key=lambda m: (abs(m[0] - c[0]) + abs(m[1] - c[1]), m))
            near = [m for m in near[:12] if m not in picks]
            if not near:
                continue
            c = near[0]
        if c not in picks:
            picks.append(c)
    def spot(c):
        x = off + c[0] * CELL + CELL // 2
        z = off + c[1] * CELL + CELL // 2
        yaw = int(round(math.degrees(math.atan2(-x, -z)) / 90.0)) * 90 % 360
        t = W.T(c)
        paved = c in W.road or c in getattr(W, "paved", ())
        if t:
            y = level_y(t, lift) + (20 if paved else 0)
        else:
            y = (lift + 20) if paved else (0 if info["floor"] is not None else 0)
        return {"x": x, "y": y, "z": z, "yaw": yaw}
    spots = [spot(c) for c in picks]
    hide = brief["family"] == "hide"
    lines = []
    for a_ in brief["anchors"]:
        if a_["what"] == "volcano" and W.volcano:
            lines.append(("placed", a_["id"], "a volcano %d high with a lava crater on the "
                          "district at the anchor's place" % (200 * W.volcano["top"])))
        elif a_["what"] in ("tower", "landmark", "vantage") and W.spires:
            lines.append(("approximated", a_["id"], "a spire stands on the plaza district "
                          "nearest the middle"))
        else:
            lines.append(("not yet", a_["id"], "an explore world places %s by its districts"
                          % a_["what"]))
    missing = [k for k in (brief.get("prefabs") or []) if k not in W.prefabs_laid]
    np = list(pocket_lines) + np_early
    for k in wished_lm:
        if k not in [x["kind"] for x in W.landmarks]:
            np.append("%s: no district had a level place for it on this seed (try a larger "
                      "size)" % k)
    if "weirs" in land_want and W.river and not W.weirs:
        np.append("weirs: the river found no step down on this seed")
    if missing:
        np.append("prefabs %s: no village with room for them on this map (try a larger "
                  "size or a village wish)" % ", ".join(missing))
    if "water" in common.want_avoid(brief)[0] and not getattr(W, "water_boxes", None):
        np.append("water: no district drew a pool with room for its rim on this seed "
                  "(try another seed or a larger size)")
    if "river" in land_want and not W.river:
        np.append("river: no river line with room on this map (try a larger size)")
    if "valley" in land_want and not W.valley:
        np.append("valley: no valley line on this map")
    if mountainous and not any(v >= 4 for v in W.hills.values()):
        np.append("mountains: no mountain district stood higher than 600 on this seed "
                  "(try a larger size)")
    if ("volcano" in land_want or vol_anchor is not None) and not W.volcano:
        np.append("volcano: its district had no room for the cone on this seed (try a "
                  "larger size)")
    liquid = theme_world(brief)["liquid"]
    if liquid == "lava" and ("lava" in land_want or "water" in land_want):
        lakes = sum(1 for p in pieces if p.get("tag") in ("lake.lava", "river.lava"))
        crat = sum(1 for p in pieces if p.get("tag") == "volcano.lava")
        if not lakes:
            np.append("lava lake: no district had room for a lake on this seed (try a larger "
                      "size)%s" % ("; the lava is the crater's only" if crat else ""))
        notes.append("lava: %d lake and %d crater pieces - real lava (the burning floor "
                     "SM64's lava is: it hurts and bounces Mario off)" % (lakes, crat))
    from .. import setpieces as _sp
    asked_feats = [f for f in sorted(land_want) if f not in EXPLORE_BUILDS
                   and f not in _sp.KINDS and f not in LATE_FEATURES]
    for f in asked_feats:
        np.append("%s: not built in an explore world (no district builds it)" % f)
    if "caves" in land_want and not W.caves:
        np.append("caves: no mountain high and wide enough for a passage on this seed "
                  "(try another seed or a larger size)")
    if levels:
        tops = sorted(set(w[4] for w in getattr(W, "water_boxes", [])))
        if len(tops) < 2:
            np.append("water at two heights: only %d pool%s with room for a rim on this "
                      "seed (try a larger size)" % (len(tops), "" if len(tops) == 1 else "s"))
    design = design_sites(W, sites, kinds, n, off, lift)
    if getattr(W, "hero_way", None) is not None:
        design["hero_way"] = dict(W.hero_way)
    design["settlements"] = settlements.report(W)
    design["readability"] = settlements.readability(W)
    rel = landform.relief(W.total(), W.shapes, landforms=[pk["cells"] for pk in W.peaks])
    rel["weirs"] = len(W.weirs)
    rel["bridges"] = len(W.bridges)
    rel["road_climbs"] = sum(x[0] for x in W.road_info)
    rel["road_turns"] = sum(x[1] for x in W.road_info)
    rel["caves"] = len(W.caves)
    rel["houses"] = len(W.houses)
    rel["houses_on_streets"] = sum(1 for h in W.houses if h.get("street"))
    rel["loops"] = cyclic.cycles(list(range(len(sites))), edges)
    design["relief"] = rel
    design["descriptors"] = dict(
        landform.landform_descriptor(rel, len(W.river), len(W.weirs), len(W.caves), n * n),
        **landform.structure_descriptor(counts, [lm["kind"] for lm in W.landmarks],
                                        len(edges), max(0, len(edges) - len(sites) + 1),
                                        len(W.houses), len(sites)))
    notes.append("relief: %d%% raised, %d%% under 400, %d levels, %d plateaus, %d of %d "
                 "steps sloped" % (100 * rel["raised"], 100 * rel["under400"], rel["levels"],
                                   rel["plateaus"], rel["sloped"], rel["steps"]))
    extra_objects = []
    if gu4 is not None:
        from .. import decor as decormod
        kept_ids = set(id(p) for p in gu4_kept[0])
        gu4["props"] = sum(1 for p in pieces if p.get("decor"))
        gu4["thinned"] = len(gu4_pieces) - len(kept_ids)
        def pole_stands(o):
            if o.get("key") != "pole":
                return True
            c = (int((o["x"] - off) // CELL), int((o["z"] - off) // CELL))
            if c in (W.shapes or {}):
                return False
            return o["y"] - level_y(W.T(c), lift) in (0, networks_strip())
        extra_objects = [dict(o) for o in gu4_objects if pole_stands(o)]
    if DEEP_RIVER and info["floor"] is not None and liquid != "lava" and deep_pools(W):
        plate = len(landform.merge_rects(set((i, j) for i in range(n) for j in range(n))
                                         - deep_pools(W)))
        if len(pieces) + plate <= budget:
            made = stand_deep(W, n, off, pal["floor"], pieces, spots, extra_objects, design,
                              lift)
            sealed = [q for q in landform.pockets(pieces) if q[1] == DEEP_RIVER]
            if sealed:
                from .. import flora
                gone, trees = set(), 0
                for g in flora.groups(pieces):
                    if any(p["y"] == DEEP_RIVER and abs(p["x"] - x) <= p["w"] / 2 + 300
                           and abs(p["z"] - z) <= p["d"] / 2 + 300
                           for p in g for (x, _, z) in sealed):
                        gone.update(id(p) for p in g)
                        trees += 1
                pieces[:] = [p for p in pieces if id(p) not in gone]
                notes.append("deep river: %d tree(s) that sealed a floor on the plate went"
                             % trees)
            notes.append("deep river: the world stands %d higher on a %d-piece plate, the "
                         "low river %d deep" % (DEEP_RIVER - lift, made, DEEP_RIVER
                                                + RIVER_SURFACE))
        else:
            notes.append("deep river: no room in the budget for the plate (%d + %d > %d)"
                         % (len(pieces), plate, budget))
    from .. import decor as _decor
    for pk in W.peaks:
        c = pk["path"][-1]
        bx, bz = off + c[0] * CELL + CELL // 2, off + c[1] * CELL + CELL // 2
        beacon = _decor.piece("campfire", bx, level_y(W.T(c), lift), bz, 0,
                              theme=brief["theme"], tag="decor.beacon")
        beacon["glow"] = True
        beacon["context"] = "summit"
        pieces.append(beacon)
        notes.append("mountains: a beacon burns at the summit (%d, %d)" % (bx, bz))
    arena = {"key": brief["key"] or "generated", "level": level, "budget": budget,
             "sites": design,
             "pieces": pieces, "spawns": spots[:16], "survey": {"points": spots},
             "look": kit.look(brief["theme"] if brief["theme"] != "auto" else "garden",
                              brief["sky"], brief["music"]),
             "onlyFor": list(HIDE_MODES if hide else MODES),
             "water": [list(w) for w in getattr(W, "water_boxes", [])],
             "blurb": "a generated world to travel" if not hide else
             "a generated hiding world for sixteen",
             "note": "a world %d across in %d districts, %d spires" % (
                 n * CELL, len(sites), len(W.spires))}
    arena["terrain"] = terrain_spec(W, brief, info, n)
    if MESH_GROUND:
        from .. import heightfield
        arena["terrain"], how = heightfield.ladder(arena)
        notes.append("ground: one mesh, %s" % how)
    from .. import basins as _basins
    arena["water"] = _basins.real_water(arena, info.get("floor"))
    if len(arena["water"]) > _basins.WATER_MOST:
        from .. import heightfield
        floor0 = info["floor"] if info["floor"] is not None else -10 ** 6
        tops = {}
        for p in arena["pieces"]:
            if not heightfield.is_terrain(p):
                continue
            x0_, x1_, z0_, z1_ = heightfield._footprint(p)
            for gi in range(int(x0_ // 200), int(-(-x1_ // 200))):
                for gj in range(int(z0_ // 200), int(-(-z1_ // 200))):
                    t_ = p["y"] + p["h"]
                    if tops.get((gi, gj), floor0) < t_:
                        tops[(gi, gj)] = t_
        def ground_at(x, z):
            if abs(x) > half + CELL or abs(z) > half + CELL:
                return None
            return tops.get((int(x // 200), int(z // 200)), floor0)
        had = len(arena["water"])
        arena["water"], joins = _basins.fit_water(arena["water"], ground_at)
        notes.append("water: %d boxes joined into %d (the engine loads %d an area)"
                     % (had, len(arena["water"]), _basins.WATER_MOST))
        if len(arena["water"]) > _basins.WATER_MOST:
            left = len(arena["water"]) - _basins.WATER_MOST
            arena["water"] = sorted(arena["water"], key=lambda w: (
                -(w[2] - w[0]) * (w[3] - w[1]), w))[:_basins.WATER_MOST]
            np.append("water: %d small pools are drawn but not swum - a level loads %d "
                      "water boxes (try fewer weirs or a smaller size)"
                      % (left, _basins.WATER_MOST))
    if not hide and W.houses and getattr(W, "settlements", None):
        from .. import pockets as _pockets
        built = []
        for e in sorted((e for e in W.houses if "built" in e and "at" in e),
                        key=lambda e: (e["settlement"], e["at"][0], e["at"][1])):
            built.append((e["built"], e["at"], e["face"], e["settlement"]))
        got = _pockets.make(arena, built, lambda s: W.settlements[s]["style_full"],
                            theme=brief["theme"] if brief["theme"] != "auto" else "garden",
                            most=min(2, len(W.settlements)))
        if got:
            notes.append("halls: %d behind a door (a pocket under the world, its own room)" % got)
    if extra_objects:
        arena["objects"] = extra_objects
    if gu4 is not None:
        d = decormod.dressing_checks(arena, "hide" if hide else "explore")
        gu4["dressing"] = {k: list(v) for k, v in d.items()}
        arena["gu4"] = gu4
        bad = [k for k, v in sorted(d.items()) if not v[2]]
        notes.append("dressing D1-D8: %s" % ("all kept" if not bad else "missed " + ", ".join(
            "%s (%s)" % (k, d[k][0]) for k in bad)))
    params = common.compat_params(n * CELL, {
        "shape": "world", "lane": "streets", "corner": "%d spires" % len(W.spires),
        "cells": n, "districts": len(sites), "kinds": dict(counts), "roads": len(edges),
        "houses": len(W.houses), "trees": len(W.trees)})
    meta = {"params": params, "modules": {"districts": dict(counts), "spires": len(W.spires),
                                          "prefabs": [p["key"] for p in W.prefabs]},
            "not_possible": np,
            "anchors": lines, "notes": notes, "graph_faults": [], "centre": (0, 0),
            "bases": [], "module_pieces": {}, "field_spots": len(spots) - 16, "cover": 0,
            "graph": {"zones": ["district%d" % i for i in range(len(sites))],
                      "loops": ["streets"]}}
    from .. import landscape as _lsm
    meta["land"] = {"biome_shares": _lsm.biome_share(W.biome, W.owner) if W.biome else {},
                    "species": sorted(set(W.tree_kind.get(c, "oak") for c in W.trees)),
                    "landforms": [lf["recipe"] for lf in W.landforms],
                    "preset": W.preset, "bands": list(W.bands or [])}
    return arena, meta
