import heapq
from . import pcg, terrain
LAYER = 200
D4 = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
PLINTH_LEVELS = {"flat": 0, "low": 1, "medium": 3, "high": 4}
HIDE_MAX = 2
KIND_BY_HEIGHT = {
    "high": {"hills": 2.2, "ruins": 1.6, "forest": 1.3, "lake": 0.25, "village": 0.6,
             "garden": 0.7},
    "mid": {"forest": 1.3, "garden": 1.2, "village": 1.1},
    "low": {"lake": 2.2, "village": 1.6, "garden": 1.3, "hills": 0.4, "ruins": 0.8},
}
def height_class(level, top):
    if top <= 0 or level <= 0:
        return "low"
    if level >= max(2, top - 1) or level == top:
        return "high"
    return "mid"
def kind_factor(kind, level, top):
    return KIND_BY_HEIGHT[height_class(level, top)].get(kind, 1.0)
def plinth_top(brief):
    want, avoid = _want_avoid(brief)
    if "terraces" in avoid or "terrain" in avoid:
        return 0
    vert = brief.get("verticality") or "medium"
    top = PLINTH_LEVELS.get(vert, 3)
    if "terraces" in want and top < 3:
        top = 3
    if brief.get("family") == "hide":
        top = min(top, HIDE_MAX)
    return top
def _want_avoid(brief):
    f = brief.get("features") or {}
    return set(f.get("want") or []), set(f.get("avoid") or [])
def plinths(sites, n, seed, top, centre=None, field=None):
    if top <= 0 or not sites:
        return {i: 0 for i in range(len(sites))}
    mid = (n - 1) / 2.0
    raw = {}
    for i, (si, sj) in enumerate(sites):
        r = min(1.0, max(abs(si - mid), abs(sj - mid)) / max(1.0, mid))
        if field is not None and (si, sj) in field:
            f = field[(si, sj)]
        else:
            f = terrain.fbm(si, sj, "%s/plinth" % seed, octaves=2, scale=0.035)
        raw[i] = 0.6 * r + 0.4 * f
    order = sorted((i for i in raw if i != centre), key=lambda i: (raw[i], i))
    out = {}
    if centre is not None:
        out[centre] = 0
    m = len(order)
    for k, i in enumerate(order):
        q = (k + 0.5) / max(1, m)
        out[i] = 0 if q < 0.2 else min(top, 1 + int((q - 0.2) / 0.8 * top))
    return out
def ground(owner, plinth, streets, keep=None, fixed=None):
    G = {}
    for c, d in owner.items():
        if c in streets:
            lo = plinth.get(d, 0)
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    m = (c[0] + a, c[1] + b)
                    if m in owner and m not in streets:
                        lo = min(lo, plinth.get(owner[m], 0))
            G[c] = lo
        else:
            G[c] = plinth.get(d, 0)
    for c, v in (fixed or {}).items():
        if c in G:
            G[c] = v
    settle(G, keep=set(keep or ()) | set(fixed or ()))
    return G
def settle(h, keep=(), up=False):
    keep = set(keep)
    todo = sorted(h)
    queued = set(todo)
    while todo:
        nxt = []
        for c in todo:
            queued.discard(c)
            if c in keep:
                continue
            for a, b in pcg.N4:
                m = (c[0] + a, c[1] + b)
                if m not in h:
                    continue
                if not up and h[c] - h[m] > 1:
                    h[c] = h[m] + 1
                elif up and h[m] - h[c] > 1:
                    h[c] = h[m] - 1
                else:
                    continue
                for a2, b2 in pcg.N4:
                    k = (c[0] + a2, c[1] + b2)
                    if k in h and k not in queued:
                        queued.add(k)
                        nxt.append(k)
        todo = sorted(set(nxt))
    return h
def river_levels(path, G):
    lv = {}
    cur = None
    for c in path:
        g = G.get(c, 0)
        cur = g if cur is None else min(cur, g)
        lv[c] = cur
    for k in range(len(path) - 1, 0, -1):
        a, b = path[k - 1], path[k]
        if lv[a] - lv[b] > 1:
            lv[a] = lv[b] + 1
    for k in range(1, len(path)):
        if lv[path[k]] > lv[path[k - 1]]:
            lv[path[k]] = lv[path[k - 1]]
    weirs = [(path[k - 1], path[k]) for k in range(1, len(path))
             if lv[path[k]] < lv[path[k - 1]]]
    return lv, weirs
def banks(river, lv, G, blocked=()):
    blocked = set(blocked)
    fixed = set(river)
    for c in sorted(river):
        for a, b in pcg.N4:
            m = (c[0] + a, c[1] + b)
            if m in river or m not in G or m in blocked:
                continue
            G[m] = max(G[m], lv[c] + 1)
            fixed.add(m)
    settle(G, keep=fixed, up=True)
    settle(G, keep=fixed)
    return G
CLIMB = 4
CLIMB_AGAIN = 6
BRIDGE = 10
TURN = 0.5
def road_path(G, a, b, river=(), river_level=None, blocked=()):
    river = set(river)
    blocked = set(blocked)
    rl = river_level or {}
    def H(c):
        if c in river:
            return rl.get(c, G.get(c, 0)) + 1
        return G[c]
    start = (a, None, False)
    openq = [(0, 0, a, None, False)]
    best = {start: 0}
    came = {start: None}
    goal = None
    tick = 0
    while openq:
        _, cost, cur, head, climbed = heapq.heappop(openq)
        if best.get((cur, head, climbed), 1e18) < cost:
            continue
        if cur == b:
            goal = (cur, head, climbed)
            break
        for d, (di, dj) in sorted(D4.items()):
            n = (cur[0] + di, cur[1] + dj)
            if n not in G or (n in blocked and n != b):
                continue
            dh = H(n) - H(cur)
            if abs(dh) > 1:
                continue
            step = 1.0 + (BRIDGE if n in river else 0) + (TURN if head and d != head else 0)
            climb = dh != 0
            if climb:
                step += CLIMB + (CLIMB_AGAIN if climbed and head == d else 0)
            nc = cost + step
            key = (n, d, climb)
            if nc < best.get(key, 1e18):
                best[key] = nc
                came[key] = (cur, head, climbed)
                tick += 1
                heapq.heappush(openq, (nc + abs(n[0] - b[0]) + abs(n[1] - b[1]), nc, n, d, climb))
    if goal is None:
        return []
    out = []
    k = goal
    while k is not None:
        out.append(k[0])
        k = came[k]
    return list(reversed(out))
def road_stats(path, G, river=(), river_level=None):
    river = set(river)
    rl = river_level or {}
    def H(c):
        return rl.get(c, G.get(c, 0)) + 1 if c in river else G.get(c, 0)
    climbs = 0
    turns = 0
    last_climb_dir = None
    for k in range(1, len(path)):
        a, b = path[k - 1], path[k]
        d = (b[0] - a[0], b[1] - a[1])
        if H(b) != H(a):
            climbs += 1
            if last_climb_dir is not None and d != last_climb_dir:
                turns += 1
            last_climb_dir = d
    return climbs, turns, sum(1 for c in path if c in river)
_ORTH = (("+x", (1, 0)), ("-x", (-1, 0)), ("+z", (0, 1)), ("-z", (0, -1)))
_DIAG = (((1, 1), "+x+z"), ((1, -1), "+x-z"), ((-1, 1), "-x+z"), ((-1, -1), "-x-z"))
def corner_name(sx, sz):
    return "%sx%sz" % ("+" if sx > 0 else "-", "+" if sz > 0 else "-")
def classify(T, c):
    h = T.get(c)
    if h is None:
        return None, None
    up = [d for d, (a, b) in _ORTH if T.get((c[0] + a, c[1] + b), h) == h + 1]
    if any(T.get((c[0] + a, c[1] + b), h) > h + 1 for _, (a, b) in _ORTH):
        return None, None
    diag = [name for (a, b), name in _DIAG if T.get((c[0] + a, c[1] + b), h) == h + 1]
    if len(up) >= 3:
        return "raise", None
    if len(up) == 2:
        a, b = up
        if {a, b} in ({"+x", "-x"}, {"+z", "-z"}):
            return "raise", None
        sx = 1 if "+x" in up else -1
        sz = 1 if "+z" in up else -1
        return "inner", corner_name(sx, sz)
    if len(up) == 1:
        return "ramp", up[0]
    if len(diag) == 1:
        return "outer", diag[0]
    if len(diag) == 2 and diag[0][:2] != diag[1][:2] and diag[0][2:] != diag[1][2:]:
        return "raise", None
    return None, None
def repair(T, free, passes=2):
    raised = []
    for _ in range(passes):
        did = False
        for c in sorted(free):
            if c in T and classify(T, c)[0] == "raise" and all(
                    T.get((c[0] + a, c[1] + b), T[c]) >= T[c] for a, b in pcg.N4):
                T[c] += 1
                raised.append(c)
                did = True
        if not did:
            break
    return raised
def _sides_slope(shapes, c, kind, high):
    sx = 1 if high[0] == "+" else -1
    sz = 1 if high[2] == "+" else -1
    zdir = "+z" if sz > 0 else "-z"
    xdir = "+x" if sx > 0 else "-x"
    if kind == "outer":
        a = shapes.get((c[0] + sx, c[1]))
        b = shapes.get((c[0], c[1] + sz))
        return bool(a and a[0] == "ramp" and a[1] == zdir and b and b[0] == "ramp"
                    and b[1] == xdir)
    a = shapes.get((c[0] - sx, c[1]))
    b = shapes.get((c[0], c[1] - sz))
    return bool(a and a[0] == "ramp" and a[1] == zdir and b and b[0] == "ramp" and b[1] == xdir)
_DIR = dict(_ORTH)
def flight_clear(T, c, facing, clear):
    a, b = _DIR[facing]
    foot, top = (c[0] - a, c[1] - b), (c[0] + a, c[1] + b)
    return foot in clear and top in clear and T.get(foot) == T[c] and T.get(top) == T[c] + 1
def autoshape(T, free, route=(), forced=None, budget=60, stairs_cells=(), clear=None):
    free = set(free)
    shapes = dict(forced or {})
    route = set(route)
    stairs_cells = set(stairs_cells)
    cand = {}
    for c in sorted(free):
        if c in shapes:
            continue
        k, f = classify(T, c)
        if k not in ("ramp", "inner", "outer"):
            continue
        if clear is not None and k == "ramp" and c not in route \
                and not flight_clear(T, c, f, clear):
            continue
        cand[c] = (k, f)
    cost = [0]
    def runs(cells):
        out = []
        seen = set()
        for c in sorted(cells):
            if c in seen:
                continue
            k, f = cand[c]
            ax = (0, 1) if f in ("+x", "-x") else (1, 0)
            run = [c]
            seen.add(c)
            for sgn in (1, -1):
                m = (c[0] + sgn * ax[0], c[1] + sgn * ax[1])
                while m in cells and m not in seen and cand[m] == (k, f) and T[m] == T[c]:
                    run.append(m)
                    seen.add(m)
                    m = (m[0] + sgn * ax[0], m[1] + sgn * ax[1])
            out.append(sorted(run))
        return out
    every = runs(set(c for c in cand if cand[c][0] == "ramp"))
    for run in every:
        if not any(c in route for c in run):
            continue
        for c in run:
            shapes[c] = cand[c]
        cost[0] += 1 + (len(run) - 1) // 15
    on_route = set(shapes)
    nice = [run for run in every if run[0] not in shapes and not any(c in stairs_cells
                                                                     for c in run)]
    for run in sorted(nice, key=lambda r: (-len(r), r[0])):
        if len(run) < 2 and cost[0] >= budget // 2:
            continue
        if cost[0] + 1 > budget:
            break
        for c in run:
            shapes[c] = cand[c]
        cost[0] += 1 + (len(run) - 1) // 15
    for c in sorted(cand):
        k, f = cand[c]
        if c in shapes or k == "ramp" or c in stairs_cells:
            continue
        if cost[0] >= budget:
            break
        if _sides_slope(shapes, c, k, f):
            shapes[c] = (k, f)
            cost[0] += 1
    out = {}
    for c, (k, f) in shapes.items():
        if c in stairs_cells and c in on_route:
            k = {"ramp": "stairs", "inner": "innerstairs", "outer": "outerstairs"}.get(k, k)
        out[c] = (k, f)
    return out
def steps(T, cells=None):
    out = []
    for c in sorted(cells if cells is not None else T):
        h = T.get(c)
        if h is None:
            continue
        for d, (a, b) in _ORTH:
            if T.get((c[0] + a, c[1] + b), h) == h + 1:
                out.append((c, d))
    return out
def merge_rects(cells, longest=15):
    key = (frozenset(cells), longest)
    if key in _MERGED:
        return list(_MERGED[key])
    if len(_MERGED) > 256:
        _MERGED.clear()
    left = set(cells)
    out = []
    while len(left) >= 6:
        best = _largest(left, longest)
        if best is None or (best[2] - best[0]) * (best[3] - best[1]) < 3:
            break
        i0, j0, i1, j1 = best
        for a in range(i0, i1):
            for b in range(j0, j1):
                left.discard((a, b))
        out.append(best)
    out += _scan_rects(left, longest)
    scan = _scan_rects(cells, longest)
    if len(scan) < len(out):
        out = scan
    _MERGED[key] = tuple(out)
    return out
_MERGED = {}
SIDES = (15, 12, 8, 6, 4, 3, 2, 1)
def alphabet(rects, sides=SIDES):
    def cut(n):
        out = []
        while n > 0:
            s = next(x for x in sides if x <= n)
            out.append(s)
            n -= s
        return out
    out = []
    for (i0, j0, i1, j1) in rects:
        i = i0
        for a in cut(i1 - i0):
            j = j0
            for b in cut(j1 - j0):
                out.append((i, j, i + a, j + b))
                j += b
            i += a
    return out
def _largest(cells, longest):
    if not cells:
        return None
    i_lo = min(c[0] for c in cells)
    i_hi = max(c[0] for c in cells)
    j_lo = min(c[1] for c in cells)
    j_hi = max(c[1] for c in cells)
    height = {i: 0 for i in range(i_lo, i_hi + 1)}
    best, best_a = None, 0
    for j in range(j_lo, j_hi + 1):
        for i in range(i_lo, i_hi + 1):
            height[i] = min(longest, height[i] + 1) if (i, j) in cells else 0
        for i in range(i_lo, i_hi + 1):
            h = height[i]
            if not h:
                continue
            k = i
            mh = h
            while k <= i_hi and height[k] and k - i < longest:
                mh = min(mh, height[k])
                a = mh * (k - i + 1)
                if a > best_a:
                    best_a = a
                    best = (i, j - mh + 1, k + 1, j + 1)
                k += 1
    return best
def _scan_rects(cells, longest=15):
    left = set(cells)
    out = []
    for c in sorted(left, key=lambda c: (c[1], c[0])):
        if c not in left:
            continue
        w = 1
        while w < longest and (c[0] + w, c[1]) in left:
            w += 1
        d = 1
        while d < longest and all((c[0] + a, c[1] + d) in left for a in range(w)):
            d += 1
        for a in range(w):
            for b in range(d):
                left.discard((c[0] + a, c[1] + b))
        out.append((c[0], c[1], c[0] + w, c[1] + d))
    return out
def ramp_runs(shapes, T, tex_of, longest=15):
    out = []
    seen = set()
    for c in sorted(shapes, key=lambda c: (c[1], c[0])):
        if c in seen:
            continue
        kind, f = shapes[c]
        key = (kind, f, T.get(c, 0), tex_of(c))
        seen.add(c)
        if kind not in ("ramp", "stairs"):
            out.append((kind, f, (c[0], c[1], c[0] + 1, c[1] + 1), key[2], key[3]))
            continue
        ax = (0, 1) if f in ("+x", "-x") else (1, 0)
        run = 1
        m = (c[0] + ax[0], c[1] + ax[1])
        while (run < longest and m in shapes and m not in seen
               and (shapes[m][0], shapes[m][1], T.get(m, 0), tex_of(m)) == key):
            seen.add(m)
            run += 1
            m = (m[0] + ax[0], m[1] + ax[1])
        i1 = c[0] + (run if ax[0] else 1)
        j1 = c[1] + (run if ax[1] else 1)
        out.append((kind, f, (c[0], c[1], i1, j1), key[2], key[3]))
    return out
def plates(T, skip=None):
    skip = skip or {}
    top = max(T.values()) if T else 0
    out = {}
    for k in range(1, top + 1):
        out[k] = set(c for c, v in T.items() if v >= k and k not in skip.get(c, ()))
    return out
def relief(T, shapes=None, cells=None, landforms=()):
    cells = sorted(cells if cells is not None else T)
    n = len(cells) or 1
    raised = sum(1 for c in cells if T.get(c, 0) >= 1)
    under = sum(1 for c in cells if T.get(c, 0) < 2)
    levels = sorted(set(T.get(c, 0) for c in cells))
    seen = set()
    plateaus = 0
    cs = set(cells)
    whole = set()
    for f in landforms or ():
        whole |= set(f)
    seen |= whole
    plateaus += sum(1 for f in landforms or () if f)
    for c in cells:
        if c in seen or T.get(c, 0) < 1:
            continue
        comp = [c]
        seen.add(c)
        todo = [c]
        while todo:
            x = todo.pop()
            for a, b in pcg.N4:
                m = (x[0] + a, x[1] + b)
                if m in cs and m not in seen and T.get(m, 0) == T[c]:
                    seen.add(m)
                    comp.append(m)
                    todo.append(m)
        if len(comp) >= 4:
            plateaus += 1
    st = steps(T, cells)
    shapes = shapes or {}
    sloped = sum(1 for c, d in st if c in shapes)
    return {"raised": round(raised / float(n), 3), "under400": round(under / float(n), 3),
            "levels": len(levels), "plateaus": plateaus, "top": max(levels) if levels else 0,
            "steps": len(st), "sloped": sloped,
            "sloped_share": round(sloped / float(len(st)), 3) if st else 0.0}
def relief_of_pieces(pieces, half, cell=400, base=0):
    ground_tags = ("terrace", "hills", "road", "bridge", "weir", "volcano", "cave", "lake.rim", "lake.bank",
                   "pond", "slope")
    tops = {}
    for p in pieces:
        tag = str(p.get("tag", ""))
        if not tag.startswith(ground_tags) or p.get("kind") == "water":
            continue
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
        if p.get("yaw") in (90, 270) and p["kind"] != "box":
            x0, x1 = p["x"] - p["d"] / 2.0, p["x"] + p["d"] / 2.0
            z0, z1 = p["z"] - p["w"] / 2.0, p["z"] + p["w"] / 2.0
        top = p["y"] + p["h"]
        for i in range(int((x0 + half) // cell), int((x1 + half - 1) // cell) + 1):
            for j in range(int((z0 + half) // cell), int((z1 + half - 1) // cell) + 1):
                if tops.get((i, j), -1e9) < top:
                    tops[(i, j)] = top
    n = max(1, int(2 * half // cell))
    total = n * n
    raised = sum(1 for v in tops.values() if v - base >= 200)
    under = total - sum(1 for v in tops.values() if v - base >= 400)
    return {"raised": round(raised / float(total), 3),
            "under400": round(under / float(total), 3)}
POCKET_GRID = 200
MARIO_H = 160
POCKET_MAX = 400
SOLID_KINDS = ("box", "ice")
def _columns(pieces, grid):
    cols = {}
    for p in pieces:
        if p.get("kind") not in SOLID_KINDS or p.get("tex") == "invisible":
            continue
        w, d = (p["d"], p["w"]) if p.get("yaw", 0) in (90, 270) else (p["w"], p["d"])
        x0, x1 = p["x"] - w / 2.0, p["x"] + w / 2.0
        z0, z1 = p["z"] - d / 2.0, p["z"] + d / 2.0
        for gx in range(int(x0 // grid), int(-(-x1 // grid))):
            cx = gx * grid + grid / 2.0
            if not x0 < cx < x1:
                continue
            for gz in range(int(z0 // grid), int(-(-z1 // grid))):
                cz = gz * grid + grid / 2.0
                if z0 < cz < z1:
                    cols.setdefault((gx, gz), []).append((p["y"], p["y"] + p["h"]))
    for k, iv in cols.items():
        iv.sort()
        merged = [list(iv[0])]
        for a, b in iv[1:]:
            if a <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        cols[k] = [tuple(m) for m in merged]
    return cols
def _blocks(iv, y0, y1):
    return any(a < y1 - 1 and y0 + 1 < b for a, b in iv)
def _covers(iv, y0, y1):
    return any(a <= y0 + 1 and b >= y1 - 1 for a, b in iv)
def pockets(pieces, grid=POCKET_GRID):
    cols = _columns(pieces, grid)
    seen = set()
    out = []
    for (gx, gz), iv in sorted(cols.items()):
        for k in range(len(iv) - 1):
            floor, roof = iv[k][1], iv[k + 1][0]
            if roof - floor < MARIO_H or ((gx, gz), floor) in seen:
                continue
            band = (floor, floor + MARIO_H)
            comp = [(gx, gz)]
            todo = [(gx, gz)]
            done = {(gx, gz)}
            sealed = True
            while todo and sealed:
                c = todo.pop()
                civ = cols.get(c, [])
                if not any(a >= band[1] - 1 for a, b in civ):
                    sealed = False
                    break
                for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    m = (c[0] + a, c[1] + b)
                    if m in done:
                        continue
                    miv = cols.get(m, [])
                    if _covers(miv, band[0], band[1]):
                        continue
                    if _blocks(miv, band[0], band[1]):
                        continue
                    done.add(m)
                    comp.append(m)
                    todo.append(m)
                    if len(comp) > POCKET_MAX:
                        sealed = False
                        break
            for c in comp:
                seen.add((c, floor))
            if sealed:
                out.append((gx * grid + grid / 2.0, floor, gz * grid + grid / 2.0))
    return out
def landform_descriptor(rel, river_cells=0, weirs=0, caves=0, cells=1):
    return {"relief": rel.get("raised", 0.0),
            "rugged": round(min(1.0, (rel.get("levels", 1) - 1) / 5.0), 3),
            "plateaus": round(min(1.0, rel.get("plateaus", 0) / 12.0), 3),
            "water": round(min(1.0, 8.0 * river_cells / float(max(1, cells))), 3),
            "weirs": min(3, weirs) / 3.0,
            "caves": min(4, caves) / 4.0}
def structure_descriptor(kinds, landmarks=(), roads=0, loops=0, houses=0, districts=1):
    import math
    total = float(sum(kinds.values()) or 1)
    ent = -sum((v / total) * math.log(v / total) for v in kinds.values() if v)
    return {"mix": round(ent / math.log(7), 3),
            "landmarks": round(min(1.0, len(set(landmarks)) / 4.0), 3),
            "loops": round(min(1.0, loops / 4.0), 3),
            "built": round(min(1.0, houses / float(max(1, 2 * districts))), 3)}
