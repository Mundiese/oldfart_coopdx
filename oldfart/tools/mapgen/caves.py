import heapq
import math
import random
from . import decor, kit
CELL = 400
LAYER = 200
LAYERS = 3
CHAMBER_LAYERS = 4
ROOF_MIN = 1
TRENCH = 2
LEN_MIN, LEN_MAX = 7, 24
MOUTHS_APART = 8
CHAMBER = 4
LIP = 20
TURN_COST = 0.35
WANDER = 1.2
WANDER_WAVE = 3.0
LAMP_EVERY = 4
GLOW = {"ice": "crystalblue", "water": "crystalblue", "lava": "crystalrose",
        "desert": "crystalrose", "temple": "crystalrose", "forest": "crystalamethyst",
        "garden": "crystalamethyst", "haunted": "crystalamethyst"}
GLOW_DEFAULT = "crystalamethyst"
TORCH_FOOT, TORCH_TOP, TORCH_CUP = 220, 360, 40
TORCH_OFF = 45
CRYSTALS = ((90, 340, 0, 0), (60, 240, 165, 30), (50, 170, -155, 40))
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
UNDERMINE = ("house", "prefab", "plaza", "spire", "landform", "skylight", "field")
MOUTHS_MAX = 80
EDGE = 3
WANT = 2
SKY_DROP = 5
def _hash01(*xs):
    h = 2166136261
    for x in xs:
        for ch in str(x):
            h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return h / 4294967296.0
def _noise(i, j, seed):
    x, z = i / WANDER_WAVE, j / WANDER_WAVE
    i0, j0 = int(math.floor(x)), int(math.floor(z))
    fx, fz = x - i0, z - j0
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    a = _hash01(seed, i0, j0)
    b = _hash01(seed, i0 + 1, j0)
    c = _hash01(seed, i0, j0 + 1)
    d = _hash01(seed, i0 + 1, j0 + 1)
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz
def block(pos):
    i, j = pos
    return ((i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1))
class Ground(object):
    def __init__(self, W, taken=()):
        self.W = W
        self.T = W.total()
        self.n = W.n
        self.taken = set(taken)
        bad = set(W.road) | set(W.river) | set(W.lake) | set(W.cuts) | set(W.roofs)
        bad |= set(W.ramps) | set(getattr(W, "shapes", {})) | set(getattr(W, "bridges", ()))
        bad |= set(c for c, v in W.solid.items() if v[2] in UNDERMINE)
        self.bad = bad
    def t(self, c):
        return self.T.get(c, -99)
    def inside(self, c):
        return EDGE <= c[0] < self.n - EDGE and EDGE <= c[1] < self.n - EDGE
    def high(self, c, f, layers=LAYERS):
        return (self.inside(c) and self.t(c) >= f + layers + ROOF_MIN and c not in self.bad
                and c not in self.taken)
    def wall(self, c, f):
        return self.inside(c) and self.t(c) >= f + LAYERS + ROOF_MIN and c not in self.taken
    def foot(self, c, f):
        return (self.inside(c) and self.t(c) in (f, f + 1) and c not in self.bad
                and c not in self.taken)
def _ring_ok(G, pos, f):
    i, j = pos
    for a in range(-1, 3):
        for b in range(-1, 3):
            c = (i + a, j + b)
            if 0 <= a <= 1 and 0 <= b <= 1:
                if not G.high(c, f):
                    return False
            elif not G.wall(c, f):
                return False
    return True
def mouths(G):
    out = []
    n = G.n
    for i in range(n):
        for j in range(n):
            for d in N4:
                side = (abs(d[1]), abs(d[0]))
                a = (i, j)
                b = (i + side[0], j + side[1])
                f = G.t(a)
                if f < 0 or G.t(b) != f or not (G.foot(a, f) and G.foot(b, f)):
                    continue
                trench = []
                pa, pb = a, b
                ok = False
                for k in range(TRENCH + 1):
                    pa = (pa[0] + d[0], pa[1] + d[1])
                    pb = (pb[0] + d[0], pb[1] + d[1])
                    ta, tb = G.t(pa), G.t(pb)
                    if G.high(pa, f) and G.high(pb, f):
                        ok = True
                        break
                    if not (f < ta < f + LAYERS + ROOF_MIN and f < tb < f + LAYERS + ROOF_MIN):
                        break
                    if pa in G.bad or pb in G.bad or pa in G.taken or pb in G.taken:
                        break
                    trench += [pa, pb]
                if not ok:
                    continue
                pos = (min(pa[0], pb[0]), min(pa[1], pb[1]))
                if d == (-1, 0):
                    pos = (pos[0] - 1, pos[1])
                elif d == (0, -1):
                    pos = (pos[0], pos[1] - 1)
                if not all(G.high(c, f) for c in block(pos)):
                    continue
                out.append({"f": f, "pos": pos, "dir": d, "trench": trench, "out": [a, b]})
    return out
def _step_cost(G, pos, d, prev, seed):
    c = 1.0 + WANDER * _noise(pos[0], pos[1], seed)
    if prev is not None and prev != d:
        c += TURN_COST
    return c
def _search(G, m, others, seed):
    f = m["f"]
    start = (m["pos"], m["dir"])
    if not _ring_ok_mouth(G, m):
        return None, None
    best = {start: 0.0}
    prev = {start: None}
    steps = {start: 0}
    heap = [(0.0, 0, start)]
    ends = {}
    for o in others:
        if o is not m and o["f"] == f:
            ends.setdefault(o["pos"], o)
    far = start
    found = None
    while heap:
        cost, _, state = heapq.heappop(heap)
        if cost > best.get(state, 1e18):
            continue
        pos, d = state
        k = steps[state]
        if pos in ends and k >= LEN_MIN and _apart(m, ends[pos]) >= MOUTHS_APART:
            found = (state, ends[pos])
            break
        if k > steps[far] or (k == steps[far] and cost < best[far]):
            far = state
        if k >= LEN_MAX:
            continue
        for nd in N4:
            if nd[0] == -d[0] and nd[1] == -d[1]:
                continue
            npos = (pos[0] + nd[0], pos[1] + nd[1])
            if not (_ring_ok(G, npos, f) or npos in ends):
                continue
            ns = (npos, nd)
            nc = cost + _step_cost(G, npos, nd, d, seed)
            if nc < best.get(ns, 1e18):
                best[ns] = nc
                prev[ns] = state
                steps[ns] = k + 1
                heapq.heappush(heap, (nc, id(ns) % 997, ns))
    end, exit_ = (found if found else (far, None))
    path = []
    s = end
    while s is not None:
        path.append(s[0])
        s = prev[s]
    path.reverse()
    return path, exit_
def _apart(m, o):
    (a, _), (b, _) = m["out"], o["out"]
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))
def _ring_ok_mouth(G, m):
    f = m["f"]
    i, j = m["pos"]
    d = m["dir"]
    for a in range(-1, 3):
        for b in range(-1, 3):
            c = (i + a, j + b)
            if 0 <= a <= 1 and 0 <= b <= 1:
                continue
            back = (a == -1 and d == (1, 0)) or (a == 2 and d == (-1, 0)) or \
                (b == -1 and d == (0, 1)) or (b == 2 and d == (0, -1))
            if back:
                continue
            if not G.wall(c, f):
                return False
    return True
def cells_of(path):
    out = []
    for pos in path:
        for c in block(pos):
            if c not in out:
                out.append(c)
    return out
def _turns(path):
    n = 0
    for a, b, c in zip(path, path[1:], path[2:]):
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]):
            n += 1
    return n
def _chamber(G, path, f, at_end):
    on_path = set(cells_of(path))
    order = [path[-1]] if at_end else \
        sorted(path[2:-2], key=lambda p: abs(path.index(p) - len(path) // 2))
    for pos in order:
        for oi in range(-(CHAMBER - 2), 1):
            for oj in range(-(CHAMBER - 2), 1):
                i0, j0 = pos[0] + oi, pos[1] + oj
                room = [(i0 + a, j0 + b) for a in range(CHAMBER) for b in range(CHAMBER)]
                ring = [(i0 + a, j0 + b) for a in range(-1, CHAMBER + 1)
                        for b in range(-1, CHAMBER + 1)
                        if not (0 <= a < CHAMBER and 0 <= b < CHAMBER)]
                if not all(G.high(c, f) for c in room):
                    continue
                if not all(G.wall(c, f) or c in on_path for c in ring):
                    continue
                tall = all(G.high(c, f, CHAMBER_LAYERS) for c in room) and \
                    all(G.wall(c, f) and G.t(c) >= f + CHAMBER_LAYERS + ROOF_MIN or
                        c in on_path for c in ring)
                return room, (CHAMBER_LAYERS if tall else LAYERS)
    return None, 0
def plan(W, want=2, seed="caves"):
    caves = []
    taken = set()
    for _ in range(want):
        G = Ground(W, taken)
        ms = mouths(G)
        tries = sorted(ms, key=lambda m: _hash01(seed, m["pos"], m["dir"]))[:MOUTHS_MAX]
        best = None
        for m in tries:
            path, exit_ = _search(G, m, ms, seed)
            if not path or len(path) < 3:
                continue
            through = exit_ is not None
            if not through and len(path) < LEN_MIN // 2 + 2:
                continue
            score = (1 if through else 0, min(len(path), LEN_MAX), _turns(path), -m["pos"][0],
                     -m["pos"][1])
            if best is None or score > best[0]:
                best = (score, m, path, exit_)
        if best is None:
            break
        _, m, path, exit_ = best
        f = m["f"]
        cells = cells_of(path)
        room, room_layers = _chamber(G, path, f, exit_ is None)
        layers = dict((c, LAYERS) for c in cells)
        if room:
            for c in room:
                if c not in layers:
                    cells.append(c)
                layers[c] = max(layers.get(c, 0), room_layers)
        sky = None
        if room:
            i0 = min(c[0] for c in room)
            j0 = min(c[1] for c in room)
            mid = (i0 + CHAMBER // 2 - 1, j0 + CHAMBER // 2 - 1)
            if mid not in G.bad and mid not in W.solid and G.t(mid) - f <= SKY_DROP:
                sky = mid
        mouths_ = [m] + ([exit_] if exit_ else [])
        trench = list(m["trench"]) + (list(exit_["trench"]) if exit_ else [])
        secret = None
        if exit_ is None:
            end = room or list(block(path[-1]))
            came = path[-2] if len(path) > 1 else path[-1]
            secret = max(sorted(end), key=lambda c: abs(c[0] - came[0]) + abs(c[1] - came[1]))
            if secret == sky:
                secret = None
        cave = {"f": f, "cells": cells, "layers": layers, "mouths": mouths_,
                "through": exit_ is not None, "chamber": room or [], "skylight": sky,
                "trench": trench, "secret": secret, "path": path}
        caves.append(cave)
        for c in cells + trench:
            for a in range(-2, 3):
                for b in range(-2, 3):
                    taken.add((c[0] + a, c[1] + b))
    return caves
def carve(W, cave):
    f = cave["f"]
    W.cave_floor = getattr(W, "cave_floor", {})
    for c in cave["trench"]:
        W.ramps.pop(c, None)
        W.cuts[c] = f
    for c in cave["cells"]:
        W.ramps.pop(c, None)
        n = cave["layers"][c]
        W.roofs[c] = set(range(f + 1, f + 1 + n))
        W.cave_floor[c] = f
        W.solid.setdefault(c, (0, None, "cave"))
    sky = cave.get("skylight")
    if sky is not None:
        W.roofs[sky] = set(range(f + 1, W.T(sky) + 1))
        W.solid[sky] = (0, None, "skylight")
    W.caves.append([c for c in cave["cells"] if c != sky])
    if not hasattr(W, "cave_info"):
        W.cave_info = []
    W.cave_info.append(cave)
def lay(W, want=2, seed="caves"):
    got = plan(W, want, seed)
    for cave in got:
        carve(W, cave)
    return len(got)
def _runs(cells):
    cs = set(cells)
    rows, seen = [], set()
    for c in sorted(cs, key=lambda c: (c[1], c[0])):
        if c in seen:
            continue
        i = c[0]
        while (i + 1, c[1]) in cs and (i + 1, c[1]) not in seen:
            i += 1
        for x in range(c[0], i + 1):
            seen.add((x, c[1]))
        rows.append([c[0], c[1], i, c[1]])
    merged = []
    for row in rows:
        for m in merged:
            if m[0] == row[0] and m[2] == row[2] and m[3] + 1 == row[1]:
                m[3] = row[1]
                break
        else:
            merged.append(row)
    return [tuple(m) for m in merged]
def pieces(W, X, LY, floor_tex, rock_tex, theme=None, pal=None):
    def Y(c):
        return LY(W.T(c))
    from . import landscape
    out = []
    for k, cave in enumerate(getattr(W, "cave_info", []) or []):
        f = cave["f"]
        if not all(c in W.roofs for c in cave["cells"]):
            continue
        y0 = LY(f)
        sky = cave.get("skylight")
        by_h = {}
        for c in cave["cells"]:
            by_h.setdefault(cave["layers"][c], []).append(c)
        for (i0, j0, i1, j1) in _runs(cave["cells"]):
            out.append(kit.kind("box").make(floor_tex, X(i0), X(i1 + 1), y0, y0 + LIP, X(j0),
                                            X(j1 + 1), None, "cave.floor"))
        for h, cs in sorted(by_h.items()):
            top = LY(f + h)
            for (i0, j0, i1, j1) in _runs([c for c in cs if c != sky]):
                out.append(kit.kind("box").make(rock_tex, X(i0), X(i1 + 1), top - LIP, top,
                                                X(j0), X(j1 + 1), None, "cave.ceiling"))
        cs = set(cave["cells"])
        dress = Dressing(out)
        rnd = random.Random("cave/%d/%d/%d" % (k, cave["path"][0][0], cave["path"][0][1]))
        glow = glow_tex(theme)
        spots = []
        for n_, pos in enumerate(cave["path"][2:-1:LAMP_EVERY]):
            for c in block(pos):
                for a, b in N4:
                    if (c[0] + a, c[1] + b) not in cs and (c[0] - a, c[1] - b) in cs:
                        spots.append((c, (a, b)))
                        break
                else:
                    continue
                break
        room = cave["chamber"]
        if room:
            i0 = min(c[0] for c in room)
            j0 = min(c[1] for c in room)
            i1 = max(c[0] for c in room)
            j1 = max(c[1] for c in room)
            corners = []
            for c, (a, b) in (((i0, j0), (-1, -1)), ((i1, j1), (1, 1)), ((i1, j0), (1, -1)),
                              ((i0, j1), (-1, 1))):
                if (c[0] + a, c[1]) not in cs:
                    corners.append((c, (a, 0)))
                elif (c[0], c[1] + b) not in cs:
                    corners.append((c, (0, b)))
            if cave.get("secret") in (corners[0][0], corners[1][0]):
                corners = corners[2:]
            spots += corners[:2]
        passage = len(spots) - (len(corners[:2]) if room else 0)
        if room:
            fire = sky
            if fire is None:
                fire = (min(c[0] for c in room) + CHAMBER // 2 - 1,
                        min(c[1] for c in room) + CHAMBER // 2 - 1)
            if fire != cave.get("secret"):
                x, z = X(fire[0]) + CELL / 2.0, X(fire[1]) + CELL / 2.0
                if sky is None:
                    x, z = x + CELL / 2.0, z + CELL / 2.0
                dress.add(decor.piece("campfire", x, y0 + LIP, z, 0, theme=theme, pal=pal,
                                       tag="cave.campfire"))
        if cave.get("secret") is not None:
            c = cave["secret"]
            x, z = X(c[0]) + CELL / 2.0, X(c[1]) + CELL / 2.0
            dress.add(decor.piece("crates", x, y0 + LIP, z, 0, theme=theme, pal=pal,
                                   tag="cave.stash"))
        seen = set()
        for n_, (c, (a, b)) in enumerate(spots):
            if c in seen or c == sky:
                continue
            seen.add(c)
            if n_ < passage and n_ % 2 == 0:
                lit = torch(X(c[0]) + CELL / 2.0 + a * (CELL / 2.0 - TORCH_OFF),
                            y0 + LIP, X(c[1]) + CELL / 2.0 + b * (CELL / 2.0 - TORCH_OFF), (a, b))
                if all(dress.fits(p) for p in lit):
                    for p in lit:
                        dress.add(p)
                continue
            x = X(c[0]) + CELL / 2.0 + a * (CELL / 2.0 - 110)
            z = X(c[1]) + CELL / 2.0 + b * (CELL / 2.0 - 110)
            held = []
            for p in crystals(x, y0 + LIP, z, rnd, glow, (a, b)):
                pc = (int((p["x"] - X(0)) // CELL), int((p["z"] - X(0)) // CELL))
                if pc in cs and any((pc[0] + u, pc[1] + v) not in cs
                                    for u, v in ((a, 0), (0, b)) if u or v):
                    held.append(p)
            if held and all(dress.fits(p) for p in held):
                for p in held:
                    dress.add(p)
        for m in cave["mouths"]:
            a, b = m["out"]
            d = m["dir"]
            side = (abs(d[1]), abs(d[0]))
            for c, s in ((a, -1), (b, 1)):
                flank = (c[0] + s * side[0], c[1] + s * side[1])
                if flank in W.road or flank in W.river or flank in W.lake or flank in W.solid:
                    continue
                if W.T(flank) != W.T(c):
                    continue
                cx = X(flank[0]) + CELL / 2.0 - s * side[0] * 80
                cz = X(flank[1]) + CELL / 2.0 - s * side[1] * 80
                rocks = [dict(p, tag="cave.mouth") for p in
                         landscape.boulder(cx, cz, Y(flank), rnd, rock_tex)]
                if all(dress.fits(p) for p in rocks):
                    for p in rocks:
                        dress.add(p)
    return out
class Dressing:
    def __init__(self, out):
        self.out = out
        self.laid = []
    def fits(self, p):
        from . import solids
        return not any(solids.overlap_depth(p, q)[1] for q in self.laid)
    def add(self, p):
        self.laid.append(p)
        self.out.append(p)
def glow_tex(theme):
    t = GLOW.get(theme, GLOW_DEFAULT)
    return t if t in kit.textures() else GLOW_DEFAULT
def torch(x, y, z, toward=(1, 0)):
    tx, tz = toward
    if tx and tz:
        tz = 0
    w, d = (40, 60) if tx else (60, 40)
    bracket = kit.kind("box").make("darkplanks", int(x - w / 2), int(x + w / 2), y + TORCH_FOOT,
                                   y + TORCH_TOP, int(z - d / 2), int(z + d / 2), None, "cave.torch")
    cx, cz = x - tx * 20, z - tz * 20
    cup = kit.kind("box").make("glowamber", int(cx - 35), int(cx + 35), y + TORCH_TOP,
                               y + TORCH_TOP + TORCH_CUP, int(cz - 35), int(cz + 35), None,
                               "cave.torch")
    cup["light"] = "torch"
    return [bracket, cup]
def crystals(x, y, z, rnd, tex, toward=(1, 0)):
    out = []
    flip = rnd.choice((1, -1))
    tx, tz = (1 if toward[0] > 0 else -1 if toward[0] < 0 else 0), \
        (1 if toward[1] > 0 else -1 if toward[1] < 0 else 0)
    if tx and tz:
        tz = 0
    ax, az = abs(tz), abs(tx)
    for a, h, along, inward in CRYSTALS:
        cx = x + flip * along * ax + inward * tx
        cz = z + flip * along * az + inward * tz
        out.append(kit.kind("pyramid").make(tex, int(cx - a), int(cx + a), y, y + h,
                                            int(cz - a), int(cz + a), "x", "cave.crystal"))
    return out
def floor_tex(pal, have=None):
    for k in ("path", "road", "floor"):
        t = (pal or {}).get(k)
        if t and (have is None or t in have):
            return t
    return "stone1"
def rock_tex(W, pal, landscape, have):
    info = getattr(W, "cave_info", None) or []
    if info:
        c = info[0]["cells"][0]
        bname = W.biome.get(W.owner.get(c), "meadow")
        t = landscape.biome_riser(bname, have)
        if t:
            return t
    return (pal or {}).get("wall") or "stone1"
def report(W):
    out = []
    for cave in getattr(W, "cave_info", []) or []:
        out.append({"cells": len(cave["cells"]), "through": cave["through"],
                    "mouths": len(cave["mouths"]), "chamber": bool(cave["chamber"]),
                    "skylight": cave["skylight"] is not None,
                    "secret": cave["secret"] is not None, "turns": _turns(cave["path"]),
                    "floor": cave["f"]})
    return out
