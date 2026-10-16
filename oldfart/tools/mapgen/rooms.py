import math
from . import houses
from .layout import grow
C = 200
WALL_H = 2 * houses.STOREY
UPPER = houses.STOREY
UPPER_WALL = UPPER + WALL_H
LINTEL = houses.STOREY
SILL, HEADER = 200, 500
GALLERY = 4
FLIGHT = 2
FLIGHTS = UPPER // 200
STAIR_W = 2
LID = 100
INVISIBLE = "invisible"
STYLES = ("arena", "hide", "course")
DEFAULTS = {
    "arena":  dict(mn=6, mx=12, cw=4, corr=0.45, door=3, windows=0.55, extra=0.2),
    "hide":   dict(mn=6, mx=12, cw=4, corr=0.4, door=2, windows=0.2, extra=0.25),
    "course": dict(mn=5, mx=7, cw=4, corr=0.0, door=2, windows=0.7, extra=0.0),
}
KILLHOUSE = (6000, 3000)
class Leaf(dict):
    @property
    def cells(self):
        return self["cells"]
    def area(self):
        u0, u1, v0, v1 = self["cells"]
        return (u1 - u0) * (v1 - v0)
    def centre(self):
        u0, u1, v0, v1 = self["cells"]
        return (u0 + u1) / 2.0, (v0 + v1) / 2.0
def _leaf(lid, cells, kind="room"):
    return Leaf(id=lid, cells=tuple(cells), kind=kind, wall_h=WALL_H, galleries=[])
def bsp(rect, r, P, out, depth=0):
    u0, u1, v0, v1 = rect
    su, sv = u1 - u0, v1 - v0
    mn, mx, cw = P["mn"], P["mx"], P["cw"]
    can = {"u": su >= 2 * mn + 1, "v": sv >= 2 * mn + 1}
    big = su > mx or sv > mx
    if not (can["u"] or can["v"]) or (not big and r.random() < 0.3):
        out.append(_leaf("r%d" % len(out), rect))
        return
    if can["u"] and can["v"]:
        axis = "u" if (su > sv * 1.15 or (sv <= su * 1.15 and r.random() < 0.5)) else "v"
    else:
        axis = "u" if can["u"] else "v"
    lo, hi = (u0, u1) if axis == "u" else (v0, v1)
    corridor = (P["corr"] > 0 and depth <= 1 and hi - lo >= 2 * mn + 2 + cw
                and r.random() < P["corr"])
    def cut(a, b):
        return (a, b, v0, v1) if axis == "u" else (u0, u1, a, b)
    if corridor:
        a, b = lo + mn, hi - mn - 2 - cw
        s = _mid_pick(r, a, b)
        bsp(cut(lo, s), r, P, out, depth + 1)
        out.append(_leaf("r%d" % len(out), cut(s + 1, s + 1 + cw), "corridor"))
        bsp(cut(s + 2 + cw, hi), r, P, out, depth + 1)
    else:
        a, b = lo + mn, hi - mn - 1
        s = _mid_pick(r, a, b)
        bsp(cut(lo, s), r, P, out, depth + 1)
        bsp(cut(s + 1, hi), r, P, out, depth + 1)
def _mid_pick(r, a, b):
    if b <= a:
        return a
    m = (a + b) / 2.0
    half = (b - a) / 2.0
    return int(round(m + (r.random() * 2 - 1) * half * 0.8))
def neighbours(leaves, need=3):
    out = {}
    for i, A in enumerate(leaves):
        a = A.cells
        for B in leaves[i + 1:]:
            b = B.cells
            for (x, y) in ((a, b), (b, a)):
                if x[1] + 1 == y[0]:
                    lo, hi = max(x[2], y[2]), min(x[3], y[3])
                    if hi - lo >= need:
                        out[_pair(A["id"], B["id"])] = ("u", x[1], lo, hi)
                if x[3] + 1 == y[2]:
                    lo, hi = max(x[0], y[0]), min(x[1], y[1])
                    if hi - lo >= need:
                        out[_pair(A["id"], B["id"])] = ("v", x[3], lo, hi)
    return out
def _pair(a, b):
    return (a, b) if a < b else (b, a)
def bridges(nodes, edges):
    adj = {n: [] for n in nodes}
    for a, b in edges:
        adj[a].append(b)
        adj[b].append(a)
    index, low, out = {}, {}, []
    counter = [0]
    def visit(v, parent):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        for w in sorted(adj[v]):
            if w not in index:
                visit(w, v)
                low[v] = min(low[v], low[w])
                if low[w] > index[v]:
                    out.append(_pair(v, w))
            elif w != parent:
                low[v] = min(low[v], index[w])
    for n in sorted(nodes):
        if n not in index:
            visit(n, None)
    return out
def connected(nodes, edges):
    adj = {n: set() for n in nodes}
    for a, b in edges:
        adj[a].add(b)
        adj[b].add(a)
    seen, todo = set(), [sorted(nodes)[0]] if nodes else []
    while todo:
        n = todo.pop()
        if n in seen:
            continue
        seen.add(n)
        todo += sorted(adj[n] - seen)
    return seen == set(nodes)
def looped(nodes, cand, r, extra, closets=0, keep_dead=(), twin=None):
    pairs = sorted(cand)
    r.shuffle(pairs)
    parent = {n: n for n in nodes}
    twin = twin or (lambda p: p)
    def find(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n
    chosen = []
    rest = list(pairs)
    def take(p):
        for q in (p, twin(p)):
            if q in rest:
                rest.remove(q)
                chosen.append(q)
                ra, rb = find(q[0]), find(q[1])
                if ra != rb:
                    parent[ra] = rb
    for p in pairs:
        if p in rest and find(p[0]) != find(p[1]):
            take(p)
    def degree(n):
        return sum(1 for p in chosen if n in p)
    dead_ok = set(keep_dead)
    if closets:
        ones = sorted((n for n in nodes if degree(n) == 1), key=lambda n: nodes[n])
        dead_ok |= set(ones[:closets])
    for n in sorted(nodes, key=lambda k: (nodes[k], k)):
        if degree(n) >= 2 or n in dead_ok:
            continue
        for p in rest:
            if n in p:
                take(p)
                break
    for _ in range(len(nodes)):
        cut = [b for b in bridges(list(nodes), chosen) if not (set(b) & dead_ok)]
        if not cut:
            break
        added = False
        for a, b in cut:
            side = _side(list(nodes), [p for p in chosen if p != (a, b)], a)
            for p in rest:
                if (p[0] in side) != (p[1] in side) and not (set(p) & dead_ok):
                    take(p)
                    added = True
                    break
            if added:
                break
        if not added:
            break
    for p in list(rest):
        if p in rest and r.random() < extra and not (set(p) & dead_ok):
            take(p)
    return sorted(set(chosen)), rest
def _side(nodes, edges, start):
    adj = {n: set() for n in nodes}
    for a, b in edges:
        adj[a].add(b)
        adj[b].add(a)
    seen, todo = set(), [start]
    while todo:
        n = todo.pop()
        if n not in seen:
            seen.add(n)
            todo += list(adj[n] - seen)
    return seen
def grid_of(W, D):
    long_, short = max(W, D), min(W, D)
    nu = max(20, int(round(long_ / (2.0 * C))) * 2)
    nv = max(14, int(round(short / float(C))))
    return nu, nv, W < D
def plan(W, D, style, r, bases=2, upper=None, opts=None):
    if style not in STYLES:
        raise ValueError("no rooms style %r" % style)
    P = dict(DEFAULTS[style])
    P.update(opts or {})
    nu, nv, swap = grid_of(W, D)
    out = {"W": nu * C if not swap else nv * C, "D": nv * C if not swap else nu * C,
           "nu": nu, "nv": nv, "swap": swap, "style": style, "route": [], "hooks": [],
           "bases": [], "start": None, "notes": []}
    if style == "arena":
        leaves, doors, windows, edges = _arena(nu, nv, r, P, bases, upper, out)
    elif style == "hide":
        leaves, doors, windows, edges = _hide(nu, nv, r, P, upper, out)
    else:
        leaves, doors, windows, edges = _course(nu, nv, r, P, out)
    out.update(leaves=leaves, doors=doors, windows=windows, edges=edges)
    return out
def _upper(leaves, r, upper, P, want=1):
    if upper is False:
        return []
    need_v = GALLERY + FLIGHT * FLIGHTS + 4
    fits = [L for L in leaves if L["kind"] in ("room", "hall")
            and L.cells[1] - L.cells[0] >= 2 * STAIR_W + 4 and L.cells[3] - L.cells[2] >= need_v]
    if not fits or (upper is None and r.random() < 0.35):
        return []
    fits.sort(key=lambda L: (-L.area(), L["id"]))
    got = []
    for L in fits[:want]:
        sides = ["v0"]
        if L.cells[3] - L.cells[2] >= 2 * (GALLERY + FLIGHT * FLIGHTS) + 4 and r.random() < 0.5:
            sides.append("v1")
        L["galleries"] = sides
        L["wall_h"] = UPPER_WALL
        got.append(L["id"])
    return got
def _blocked(L):
    u0, u1, v0, v1 = L.cells
    out = {"u0": [], "u1": [], "v0": [], "v1": []}
    reach = GALLERY + FLIGHT * FLIGHTS + 1
    for side in L["galleries"]:
        if side == "v0":
            out["v0"].append((u0, u1))
            out["u0"].append((v0, v0 + reach))
            out["u1"].append((v0, v0 + reach))
        else:
            out["v1"].append((u0, u1))
            out["u0"].append((v1 - reach, v1))
            out["u1"].append((v1 - reach, v1))
    return out
def _door(leaves_by, a, b, wall, width, r, centre=False):
    axis, line, lo, hi = wall
    free = [(lo + 1, hi - 1)]
    for lid in (a, b):
        L = leaves_by[lid]
        bl = _blocked(L)
        if axis == "u":
            side = "u1" if L.cells[1] == line else "u0"
        else:
            side = "v1" if L.cells[3] == line else "v0"
        for c0, c1 in bl[side]:
            nxt = []
            for f0, f1 in free:
                if c1 <= f0 or f1 <= c0:
                    nxt.append((f0, f1))
                    continue
                if c0 > f0:
                    nxt.append((f0, c0))
                if c1 < f1:
                    nxt.append((c1, f1))
            free = nxt
    for w in (width, 2):
        spans = [(f0, f1) for f0, f1 in free if f1 - f0 >= w]
        if spans:
            f0, f1 = max(spans, key=lambda s: (s[1] - s[0], -s[0]))
            if centre:
                s = (f0 + f1 - w) // 2
            else:
                s = f0 + int(r.random() * (f1 - f0 - w + 1))
            if axis == "u":
                return (line, line + 1, s, s + w)
            return (s, s + w, line, line + 1)
    return None
def doorable(by, cand, width):
    import random as _random
    probe = _random.Random(0)
    return {p: w for p, w in cand.items() if _door(by, p[0], p[1], w, width, probe) is not None}
def _window(wall, r):
    axis, line, lo, hi = wall
    if hi - lo < 4:
        return None
    w = 2 if hi - lo < 6 else 3
    s = lo + 1 + int(r.random() * (hi - lo - 2 - w + 1))
    if axis == "u":
        return (line, line + 1, s, s + w)
    return (s, s + w, line, line + 1)
def _mirror_cells(c, nu):
    return (nu - c[1], nu - c[0], c[2], c[3])
def _arena(nu, nv, r, P, n_bases, upper, out):
    cu = nu // 2
    h = max(3, min(6, int(round(nu * 0.1))))
    if upper is not False and 2 * h < 2 * STAIR_W + 4 and nu >= 40:
        h = 4
    want_up = None
    fw = P["cw"]
    flanks = nv - 2 >= 2 * (fw + 1) + 10
    for attempt in range(16):
        if flanks:
            hall = _leaf("hall", (cu - h, cu + h, 2 + fw, nv - 2 - fw), "hall")
            side = [_leaf("flank0", (cu - h, cu + h, 1, 1 + fw), "corridor"),
                    _leaf("flank1", (cu - h, cu + h, nv - 1 - fw, nv - 1), "corridor")]
        else:
            hall = _leaf("hall", (cu - h, cu + h, 1, nv - 1), "hall")
            side = []
        half = []
        bsp((cu + h + 1, nu - 1, 1, nv - 1), r, P, half)
        for L in half:
            L["id"] = "a" + L["id"][1:]
        if want_up is None:
            want_up = _upper([hall], r, upper, P) and list(hall["galleries"])
        own = set(L["id"] for L in [hall] + side)
        def mid(x):
            if x in own:
                return x
            return x[:-1] if x.endswith("m") else x + "m"
        def twin(p):
            return _pair(mid(p[0]), mid(p[1]))
        mirror = []
        for L in half:
            M = Leaf(L)
            M["id"] = L["id"] + "m"
            M["cells"] = _mirror_cells(L.cells, nu)
            mirror.append(M)
        leaves = [hall] + side + half + mirror
        by = {L["id"]: L for L in leaves}
        for gal in ([want_up, want_up[:1], []] if want_up else [[]]):
            hall["galleries"] = list(gal)
            hall["wall_h"] = UPPER_WALL if gal else WALL_H
            cand = doorable(by, neighbours(leaves, need=4), P["door"])
            ids = list(by)
            three = sum(1 for L in half if L["kind"] == "room"
                        and sum(1 for p in cand if L["id"] in p) >= 3)
            if connected(ids, list(cand)) and not bridges(ids, list(cand)) and \
                    _no_cut(ids, list(cand)) and \
                    (three >= (2 if n_bases >= 4 else 1) or attempt >= 12):
                break
        else:
            continue
        break
    nodes = {L["id"]: L.area() for L in leaves}
    walls = {n: sum(1 for p in cand if n in p) for n in nodes}
    far = sorted((L for L in half if L["kind"] == "room"),
                 key=lambda L: (walls[L["id"]] < 3, -L.cells[1], -L.area(), L["id"]))
    spawn = [far[0]["id"]] if far else []
    if n_bases >= 4 and len(far) > 1:
        c0 = far[0].centre()[1]
        other = max(far[1:], key=lambda L: (walls[L["id"]] >= 3,
                                             abs(L.centre()[1] - c0) - 0.2 * (nu - L.cells[1]),
                                             L["id"]))
        spawn.append(other["id"])
    spawn = spawn + [mid(s) for s in spawn]
    for s in spawn:
        by[s]["kind"] = "spawn"
    edges, rest = looped(nodes, cand, r, P["extra"], twin=twin)
    for s in spawn:
        for p in list(rest):
            if p in rest and s in p and sum(1 for e in edges if s in e) < 3:
                for q in (p, twin(p)):
                    if q in rest:
                        edges.append(q)
                        rest.remove(q)
    doors, windows = [], []
    done = set()
    for p in sorted(set(edges)):
        if p in done:
            continue
        q = twin(p)
        done |= {p, q}
        d = _door(by, p[0], p[1], cand[p], P["door"], r, centre=bool(own & set(p)))
        if d is None:
            continue
        doors.append({"a": p[0], "b": p[1], "cells": d})
        c = _mirror_cells(d, nu)
        if c != d:
            doors.append({"a": q[0], "b": q[1], "cells": c})
    done = set()
    for p in sorted(rest):
        if p in done:
            continue
        q = twin(p)
        done |= {p, q}
        if r.random() < P["windows"]:
            w = _window(cand[p], r)
            if w is not None and not any(_touch(w, d["cells"]) for d in doors):
                windows.append({"a": p[0], "b": p[1], "cells": w})
                c = _mirror_cells(w, nu)
                if c != w:
                    windows.append({"a": q[0], "b": q[1], "cells": c})
    all_edges = sorted(set(_pair(d["a"], d["b"]) for d in doors))
    out["bases"] = spawn
    out["notes"].append("arena: a hall %d deep across the middle%s, %d rooms a side, %d doors, "
                        "%d windows%s" % (2 * h * C, " with flank corridors past it" if side
                                          else "", len(half), len(doors), len(windows),
                                          ", an upper floor in the hall" if hall["galleries"]
                                          else ""))
    return leaves, doors, windows, all_edges
def _no_cut(nodes, edges):
    from .skeleton import Graph, Zone
    g = Graph()
    for n in nodes:
        g.add(Zone(n, "field", 0, 0, 0))
    for e in edges:
        g.edges.add(e)
    cut, unreached = g.articulation_points()
    return not cut and not unreached
def _touch(a, b):
    return a[0] <= b[1] and b[0] <= a[1] and a[2] <= b[3] and b[2] <= a[3]
def _hide(nu, nv, r, P, upper, out):
    leaves = []
    bsp((1, nu - 1, 1, nv - 1), r, P, leaves)
    _upper(leaves, r, upper, P)
    by = {L["id"]: L for L in leaves}
    cand = doorable(by, neighbours(leaves, need=4), P["door"])
    nodes = {L["id"]: L.area() for L in leaves}
    closets = 2 if len(leaves) >= 8 else 1
    edges, rest = looped(nodes, cand, r, P["extra"], closets=closets)
    doors, windows = [], []
    for a, b in edges:
        d = _door(by, a, b, cand[(a, b)], P["door"], r)
        if d is not None:
            doors.append({"a": a, "b": b, "cells": d})
    for p in rest:
        if r.random() < P["windows"]:
            w = _window(cand[p], r)
            if w is not None:
                windows.append({"a": p[0], "b": p[1], "cells": w})
    deg = {n: sum(1 for d in doors if n in (d["a"], d["b"])) for n in nodes}
    for n, k in deg.items():
        if k == 1 and by[n]["kind"] == "room":
            by[n]["kind"] = "closet"
    rooms = [L for L in leaves if L["kind"] in ("room", "closet")]
    pick = [max(rooms, key=lambda L: (L.cells[0] + L.cells[2], L["id"]))] if rooms else []
    while len(pick) < min(4, len(rooms)):
        nxt = max((L for L in rooms if L not in pick),
                  key=lambda L: (min(_dist(L, p) for p in pick), L["id"]))
        pick.append(nxt)
    out["bases"] = [L["id"] for L in pick]
    out["notes"].append("hide: %d rooms by BSP, %d doors, %d dead-end closets kept for hiding"
                        % (len(leaves), len(doors), sum(1 for L in leaves
                                                        if L["kind"] == "closet")))
    return leaves, doors, windows, sorted(set(_pair(d["a"], d["b"]) for d in doors))
def _dist(A, B):
    a, b = A.centre(), B.centre()
    return math.hypot(a[0] - b[0], a[1] - b[1])
def _row_cuts(nv, rows, P, r, first=None):
    cuts, v = [], 1
    for k in range(rows - 1):
        share = (nv - 2 - (rows - 1)) / float(rows)
        s = int(round(1 + (k + 1) * share + k)) + r.choice((-1, 0, 0, 1))
        if k == 0 and first:
            s = max(s, 1 + first)
        s = max(v + P["mn"] - 1, min(s, nv - 1 - (rows - 1 - k) * (P["mn"] + 1)))
        cuts.append((v, s))
        v = s + 1
    cuts.append((v, nv - 1))
    return cuts
COURSE_ROOMS = 8
START_MIN = 6
def _course(nu, nv, r, P, out):
    inner_v = nv - 2
    rows = max(1, min(3, (inner_v + 1) // (P["mn"] + 1)))
    if rows == 1 and inner_v >= 2 * P["mn"] + 1:
        rows = 2
    start_w = max(START_MIN, min(10, int(round(nu * 0.2))))
    u = 2 + start_w
    cols = []
    while nu - 1 - u >= P["mn"]:
        left = nu - 1 - u
        w = P["mn"] + int(r.random() * (min(P["mx"], left) - P["mn"] + 1))
        if left - w - 1 < P["mn"]:
            w = left
        cols.append((u, u + w))
        u += w + 1
    corner = (rows >= 2 and len(cols) * rows < COURSE_ROOMS
              and (inner_v - (rows - 1)) - START_MIN >= (rows - 1) * (P["mn"] + 1) - 1)
    leaves = []
    grid = {}
    if corner:
        cols = [(1, 1 + start_w)] + cols
    else:
        leaves.append(_leaf("start", (1, 1 + start_w, 1, nv - 1), "start"))
    for ci, (a, b) in enumerate(cols):
        cuts = _row_cuts(nv, rows, P, r, first=START_MIN if corner and ci == 0 else None)
        for ri, (v0, v1) in enumerate(cuts):
            if corner and ci == 0 and ri == 0:
                L = _leaf("start", (a, b, v0, v1), "start")
                leaves.insert(0, L)
                continue
            L = _leaf("k%d_%d" % (ci, ri), (a, b, v0, v1))
            leaves.append(L)
            grid[(ci, ri)] = L["id"]
    order = []
    for ri in range(rows):
        cs = range(len(cols)) if ri % 2 == 0 else range(len(cols) - 1, -1, -1)
        order += [grid[(ci, ri)] for ci in cs if (ci, ri) in grid]
    route = ["start"] + order
    by = {L["id"]: L for L in leaves}
    cand = neighbours(leaves, need=4)
    doors = []
    for a, b in zip(route, route[1:]):
        p = _pair(a, b)
        if p not in cand:
            continue
        d = _door(by, p[0], p[1], cand[p], P["door"], r)
        if d is not None:
            doors.append({"a": a, "b": b, "cells": d})
    back = _pair(route[-1], "start")
    if rows % 2 == 0 and back in cand:
        d = _door(by, back[0], back[1], cand[back], P["door"], r)
        if d is not None:
            doors.append({"a": route[-1], "b": "start", "cells": d, "exit": True})
    on_route = set(_pair(d["a"], d["b"]) for d in doors)
    windows = []
    for p in sorted(cand):
        if p in on_route or r.random() >= P["windows"]:
            continue
        w = _window(cand[p], r)
        if w is not None:
            windows.append({"a": p[0], "b": p[1], "cells": w})
    out["route"] = route
    out["start"] = "start"
    out["bases"] = ["start"]
    out["hooks"] = _hooks(by, route, doors)
    out["notes"].append("course: a Killhouse route through %d rooms (%d x %d%s), %d target "
                        "spots along it%s" % (len(order), len(cols), rows,
                                              ", the start in the corner" if corner else "",
                                              len(out["hooks"]),
                                              ", the last door back into the start"
                                              if any(d.get("exit") for d in doors) else ""))
    return leaves, doors, windows, sorted(on_route)
def _hooks(by, route, doors):
    out = []
    for k, rid in enumerate(route[1:], 1):
        L = by[rid]
        u0, u1, v0, v1 = L.cells
        came = next((d for d in doors if d["b"] == rid and d["a"] == route[k - 1]), None)
        if came is None:
            continue
        dc = ((came["cells"][0] + came["cells"][1]) / 2.0, (came["cells"][2] + came["cells"][3]) / 2.0)
        corners = [(u0 + 1.5, v0 + 1.5), (u1 - 1.5, v0 + 1.5), (u0 + 1.5, v1 - 1.5),
                   (u1 - 1.5, v1 - 1.5)]
        exits = [((d["cells"][0] + d["cells"][1]) / 2.0, (d["cells"][2] + d["cells"][3]) / 2.0)
                 for d in doors if rid in (d["a"], d["b"]) and d is not came]
        corners = [c for c in corners if all(math.hypot(c[0] - e[0], c[1] - e[1]) >= 3
                                             for e in exits)] or corners
        corners.sort(key=lambda c: (-math.hypot(c[0] - dc[0], c[1] - dc[1]), c))
        for c in corners[:2]:
            out.append({"room": rid, "order": k, "cell": c, "from": dc})
    return out
def cell_map(pl):
    nu, nv = pl["nu"], pl["nv"]
    owner = {}
    for L in pl["leaves"]:
        u0, u1, v0, v1 = L.cells
        for u in range(u0, u1):
            for v in range(v0, v1):
                owner[(u, v)] = L["id"]
    by = {L["id"]: L for L in pl["leaves"]}
    cells = {}
    for u in range(nu):
        for v in range(nv):
            if (u, v) in owner:
                cells[(u, v)] = ("floor", 0, owner[(u, v)])
                continue
            hs = [by[owner[n]]["wall_h"] for n in _around(u, v) if n in owner]
            cells[(u, v)] = ("wall", max(hs) if hs else WALL_H, None)
    for d in pl["doors"]:
        u0, u1, v0, v1 = d["cells"]
        for u in range(u0, u1):
            for v in range(v0, v1):
                cells[(u, v)] = ("door", cells[(u, v)][1], None)
    for w in pl["windows"]:
        u0, u1, v0, v1 = w["cells"]
        for u in range(u0, u1):
            for v in range(v0, v1):
                if cells[(u, v)][0] == "wall":
                    cells[(u, v)] = ("window", cells[(u, v)][1], None)
    for L in pl["leaves"]:
        u0, u1, v0, v1 = L.cells
        for side in L["galleries"]:
            vs = range(v0, v0 + GALLERY) if side == "v0" else range(v1 - GALLERY, v1)
            for u in range(u0, u1):
                for v in vs:
                    cells[(u, v)] = ("deck", UPPER, L["id"])
    return cells
def _around(u, v):
    return [(u + du, v + dv) for du in (-1, 0, 1) for dv in (-1, 0, 1) if du or dv]
def merge(cells, keyf):
    left = {c: keyf(k) for c, k in cells.items()}
    left = {c: k for c, k in left.items() if k is not None}
    out = []
    for c in sorted(left):
        if c not in left:
            continue
        k = left[c]
        u0, v0 = c
        v1 = v0 + 1
        while left.get((u0, v1)) == k:
            v1 += 1
        u1 = u0 + 1
        while all(left.get((u1, v)) == k for v in range(v0, v1)):
            u1 += 1
        for u in range(u0, u1):
            for v in range(v0, v1):
                del left[(u, v)]
        out.append((k, (u0, u1, v0, v1)))
    return out
class Frame:
    def __init__(self, pl):
        self.swap = pl["swap"]
        self.W, self.D = pl["W"], pl["D"]
    def rect(self, c):
        u0, u1, v0, v1 = c
        if not self.swap:
            return (-self.W // 2 + u0 * C, -self.W // 2 + u1 * C,
                    -self.D // 2 + v0 * C, -self.D // 2 + v1 * C)
        return (-self.W // 2 + v0 * C, -self.W // 2 + v1 * C,
                -self.D // 2 + u0 * C, -self.D // 2 + u1 * C)
    def point(self, u, v):
        x0, _, z0, _ = self.rect((u, u, v, v))
        return x0, z0
    def dir(self, axis, sign):
        world = ("x" if axis == "u" else "z") if not self.swap else ("z" if axis == "u" else "x")
        return ("+" if sign > 0 else "-") + world
    def vec(self, axis, sign):
        d = self.dir(axis, sign)
        s = 1 if d[0] == "+" else -1
        return (s, 0) if d[1] == "x" else (0, s)
def textures(L, r):
    try:
        st = houses.style_for(L.brief["theme"], L.pal, r)
    except Exception:
        st = {}
    pal = L.pal
    return {"wall": st.get("wall") or pal["wall"], "outer": st.get("base") or pal["wall"],
            "trim": st.get("trim") or pal.get("deck") or pal["wall"],
            "room": st.get("floor") or pal["floor"], "corridor": pal.get("deck") or pal["floor"],
            "hall": pal["floor"], "deck": pal.get("deck") or pal["floor"],
            "spawn": (pal.get("accents") or [pal["floor"]])[0]}
def lay(L, pl, r):
    from .skeleton import Zone
    F = Frame(pl)
    T = textures(L, r)
    nu, nv = pl["nu"], pl["nv"]
    by = {Lf["id"]: Lf for Lf in pl["leaves"]}
    cells = cell_map(pl)
    outer = set()
    for u in range(nu):
        outer |= {(u, 0), (u, nv - 1)}
    for v in range(nv):
        outer |= {(0, v), (nu - 1, v)}
    stair_cells = {}
    for Lf in pl["leaves"]:
        for fl in flights(Lf):
            for u in range(fl["cells"][0], fl["cells"][1]):
                for v in range(fl["cells"][2], fl["cells"][3]):
                    stair_cells[(u, v)] = fl
    def key(k, c):
        kind, h, owner = k
        if kind == "floor":
            tex = T.get(by[owner]["kind"], T["room"]) if owner else T["room"]
            if by[owner]["kind"] in ("spawn", "start"):
                tex = T["spawn"]
            return ("floor", 0, tex)
        if kind == "wall":
            return ("wall", h, T["outer"] if c in outer else T["wall"])
        if kind == "door":
            return ("door", h, T["outer"] if c in outer else T["wall"])
        if kind == "window":
            return ("window", h, T["outer"] if c in outer else T["wall"])
        if kind == "deck":
            return ("deck", h, T["deck"])
        return None
    keyed = {c: key(k, c) for c, k in cells.items()}
    n = 0
    for (kind, h, tex), c in merge(keyed, lambda k: k):
        x0, x1, z0, z1 = F.rect(c)
        if kind == "floor":
            L.box("floor", x0, x1, -200, 0, z0, z1, "rooms.floor", tex=tex, copy=False)
        elif kind == "wall":
            L.box("wall", x0, x1, -200, h, z0, z1, "rooms.wall", tex=tex, copy=False)
        elif kind == "door":
            L.box("floor", x0, x1, -200, 0, z0, z1, "rooms.door", tex=T["trim"], copy=False)
            L.box("wall", x0, x1, LINTEL, LINTEL + C, z0, z1, "rooms.lintel", tex=T["trim"],
                  copy=False)
            L.box("wall", x0, x1, LINTEL + C, h, z0, z1, "rooms.wall", tex=tex, copy=False)
        elif kind == "window":
            L.box("wall", x0, x1, -200, SILL, z0, z1, "rooms.sill", tex=T["trim"], copy=False)
            L.box("wall", x0, x1, HEADER, HEADER + C, z0, z1, "rooms.lintel", tex=T["trim"],
                  copy=False)
            L.box("wall", x0, x1, HEADER + C, h, z0, z1, "rooms.wall", tex=tex, copy=False)
        elif kind == "deck":
            L.box("deck", x0, x1, -200, h, z0, z1, "rooms.gallery", tex=tex, copy=False)
        n += 1
    n += lid(L, pl, F, cells)
    for fl in flights_all(pl):
        x0, x1, z0, z1 = F.rect(fl["cells"])
        y0 = fl["level"] * 200
        if y0:
            L.box("deck", x0, x1, 0, y0, z0, z1, "rooms.flight foot", tex=T["deck"], copy=False)
        L.ramp("ramp", x0, x1, y0, y0 + 200, z0, z1, F.dir("v", fl["toward"]), "rooms.flight",
               tex=T["deck"], copy=False, stairs=True)
    for Lf in pl["leaves"]:
        rect = F.rect(_open_cells(Lf))
        kind = Lf["kind"]
        zone = {"spawn": "base", "start": "base"}.get(kind, "field")
        L.floor(rect, 0, zone, fill=kind not in ("spawn", "start"), copy=False)
        L.floors[-1]["purpose"] = purpose(pl, Lf)
        L.floors[-1]["room"] = Lf["id"]
        for side in Lf["galleries"]:
            u0, u1, v0, v1 = Lf.cells
            g = (u0, u1, v0, v0 + GALLERY) if side == "v0" else (u0, u1, v1 - GALLERY, v1)
            L.floor(F.rect(g), UPPER, "perch", fill=False, copy=False)
            cu, cv = (g[0] + g[1]) / 2.0, (g[2] + g[3]) / 2.0
            x, z = F.point(cu, cv)
            L.spot(int(x), UPPER, int(z), 0, "upper floor")
            for fl in flights(Lf):
                L.keep(grow(F.rect(fl["cells"]), 200), copy=False)
            L.keep(grow(F.rect(g), 200), copy=False)
    for d in pl["doors"]:
        rect = F.rect(d["cells"])
        L.keep(grow(rect, 400), copy=False)
        L.opening(grow(rect, 200), copy=False)
    for w in pl["windows"]:
        L.keep(grow(F.rect(w["cells"]), 200), copy=False)
    for Lf in pl["leaves"]:
        cu, cv = Lf.centre()
        x, z = F.point(cu, cv)
        kind = {"spawn": "base", "start": "base", "hall": "centre"}.get(Lf["kind"], "field")
        L.graph.add(Zone(Lf["id"], kind, 0, x, z))
    for a, b in pl["edges"]:
        L.graph.edges.add(_pair(a, b))
    for i, cyc in enumerate(cycles([Lf["id"] for Lf in pl["leaves"]], pl["edges"])):
        L.graph.loops.append(("rooms loop %d" % i, cyc))
    return n
def lid_cells(pl, cells=None):
    cells = cells if cells is not None else cell_map(pl)
    by = {Lf["id"]: Lf for Lf in pl["leaves"]}
    out = {}
    for c, (kind, h, owner) in cells.items():
        if kind in ("floor", "deck") and owner in by:
            out[c] = by[owner]["wall_h"]
        else:
            out[c] = h
    return out
def lid(L, pl, F, cells=None):
    n = 0
    for h, c in merge(lid_cells(pl, cells), lambda k: k):
        x0, x1, z0, z1 = F.rect(c)
        L.box("wall", x0, x1, h, h + LID, z0, z1, "rooms.lid", tex=INVISIBLE, copy=False)
        n += 1
    return n
def kickable_tops(pieces):
    from . import movement
    walls = [(i, p) for i, p in enumerate(pieces)
             if p.get("kind") == "box" and p.get("tex") != INVISIBLE
             and p["y"] + p["h"] > movement.REACH and p["h"] >= 300]
    solid = [p for p in pieces if p.get("kind") != "water"]
    def rect(p):
        return (p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0,
                p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0)
    rects = [rect(p) for p in solid]
    def inside(x, z, r):
        return r[0] <= x <= r[1] and r[2] <= z <= r[3]
    def headroom(a, top):
        xs = [a[0] + 1, (a[0] + a[1]) / 2.0, a[1] - 1]
        zs = [a[2] + 1, (a[2] + a[3]) / 2.0, a[3] - 1]
        for x in xs:
            for z in zs:
                if not any(inside(x, z, r) and top - 1 <= q["y"] < top + movement.TALL
                           for q, r in zip(solid, rects)):
                    return True
        return False
    def open_gap(g, top):
        for q, r in zip(solid, rects):
            if r[0] < g[1] and g[0] < r[1] and r[2] < g[3] and g[2] < r[3] \
                    and movement.TALL <= q["y"] < top:
                return False
        return True
    out = []
    for i, p in walls:
        a = rect(p)
        top = p["y"] + p["h"]
        if not headroom(a, top):
            continue
        for j, q in walls:
            if j == i:
                continue
            b = rect(q)
            gx = max(a[0], b[0]) - min(a[1], b[1])
            gz = max(a[2], b[2]) - min(a[3], b[3])
            if gx > 0 and gz < -100:
                g = (min(a[1], b[1]), max(a[0], b[0]), max(a[2], b[2]), min(a[3], b[3]))
                gap = gx
            elif gz > 0 and gx < -100:
                g = (max(a[0], b[0]), min(a[1], b[1]), min(a[3], b[3]), max(a[2], b[2]))
                gap = gz
            else:
                continue
            if movement.chimney(gap, frame_perfect=True) and open_gap(g, top):
                out.append((i, top))
                break
    return out
def _open_cells(Lf):
    u0, u1, v0, v1 = Lf.cells
    if "v0" in Lf["galleries"]:
        v0 += GALLERY + FLIGHT * FLIGHTS
    if "v1" in Lf["galleries"]:
        v1 -= GALLERY + FLIGHT * FLIGHTS
    return (u0, u1, v0, v1)
def flights(Lf):
    out = []
    u0, u1, v0, v1 = Lf.cells
    for side in Lf["galleries"]:
        for us in ((u0, u0 + STAIR_W), (u1 - STAIR_W, u1)):
            for k in range(FLIGHTS):
                if side == "v0":
                    top = v0 + GALLERY
                    c = (us[0], us[1], top + (FLIGHTS - 1 - k) * FLIGHT,
                         top + (FLIGHTS - k) * FLIGHT)
                    out.append({"cells": c, "level": k, "toward": -1})
                else:
                    top = v1 - GALLERY
                    c = (us[0], us[1], top - (FLIGHTS - k) * FLIGHT,
                         top - (FLIGHTS - 1 - k) * FLIGHT)
                    out.append({"cells": c, "level": k, "toward": 1})
    return out
def flights_all(pl):
    return [f for Lf in pl["leaves"] for f in flights(Lf)]
def cycles(nodes, edges):
    adj = {n: [] for n in nodes}
    for a, b in edges:
        adj[a].append(b)
        adj[b].append(a)
    parent, depth, order = {}, {}, []
    for root in sorted(nodes):
        if root in parent:
            continue
        parent[root], depth[root] = None, 0
        q = [root]
        while q:
            n = q.pop(0)
            order.append(n)
            for m in sorted(adj[n]):
                if m not in parent:
                    parent[m], depth[m] = n, depth[n] + 1
                    q.append(m)
    tree = set(_pair(n, p) for n, p in parent.items() if p is not None)
    out = []
    for a, b in sorted(set(_pair(*e) for e in edges)):
        if (a, b) in tree:
            continue
        pa, pb = [a], [b]
        x, y = a, b
        while x != y:
            if depth[x] >= depth[y]:
                x = parent[x]
                pa.append(x)
            else:
                y = parent[y]
                pb.append(y)
        cyc = pa + list(reversed(pb[:-1]))
        if len(cyc) >= 3:
            out.append(cyc)
    return out
def purpose(pl, Lf):
    rid = Lf["id"]
    if Lf["kind"] in ("spawn", "start"):
        return "spawn"
    if pl["style"] == "course":
        return "route"
    deg = sum(1 for d in pl["doors"] if rid in (d["a"], d["b"]))
    near_spawn = any(rid in (d["a"], d["b"]) and ({d["a"], d["b"]} & set(pl["bases"]))
                     for d in pl["doors"])
    u0, u1, v0, v1 = Lf.cells
    if Lf["kind"] == "corridor" or (deg == 2 and min(u1 - u0, v1 - v0) <= 7):
        return "choke"
    if near_spawn:
        return "supply"
    if deg >= 3:
        return "junction"
    return "room"
def footprint(brief, across):
    from . import brief as briefmod
    size = brief["size"]
    if isinstance(size, dict) and ("w" in size or "aspect" in size):
        w, d = briefmod.footprint_units(size, across)
        return int(w), int(d)
    if style_of(brief) == "course":
        if "size" in (getattr(brief, "defaulted", ()) or ()):
            return KILLHOUSE
        k = across / 8000.0
        return int(KILLHOUSE[0] * max(0.7, k)), int(KILLHOUSE[1] * max(0.7, k))
    return int(across), int(across)
def style_of(brief):
    if brief["family"] == "course" or "training_course" in brief["features"]["want"]:
        return "course"
    if brief["family"] == "hide":
        return "hide"
    return "arena"
def upper_of(brief):
    feats = brief["features"]
    if "second_floor" in feats["want"]:
        return True
    if "second_floor" in feats["avoid"] or brief["verticality"] == "flat":
        return False
    return None
def build_skeleton(L, P, r):
    brief = L.brief
    W, D = footprint(brief, P["across"])
    style = style_of(brief)
    sides = brief["sides"]
    n_bases = 2 if sides == "2" or style != "arena" else (4 if brief["players"] > 8 else 2)
    pl = plan(W, D, style, r, bases=n_bases, upper=upper_of(brief))
    lay(L, pl, r)
    F = Frame(pl)
    if style == "arena":
        cu = pl["nu"] / 2.0
        per = int(math.ceil(16.0 / max(1, len(pl["bases"]))))
        for bid in pl["bases"]:
            Lf = next(x for x in pl["leaves"] if x["id"] == bid)
            sign = -1 if Lf.centre()[0] > cu else 1
            vs = -1 if Lf.centre()[1] > pl["nv"] / 2.0 else 1
            rect = F.rect(Lf.cells)
            facing = next((f for f in (F.vec("u", sign), F.vec("v", vs), F.vec("v", -vs))
                           if _rows_fit(rect, f, per, brief)), F.vec("u", sign))
            L.base(bid, rect, 0, facing)
    else:
        own_spawns(L, pl, F)
    up = UPPER if _has_upper(pl) else 0
    P.update({"centre": "hall" if style == "arena" else style, "lane": "corridors",
              "corner": "-", "I": 0, "G": 0, "B": 0, "Dh": up, "Ph": up, "rooms": style,
              "footprint": [pl["W"], pl["D"]]})
    L.rooms_plan = pl
    L.landmark = None
    L.modules.update({"rooms": style, "leaves": len(pl["leaves"]), "doors": len(pl["doors"]),
                      "windows": len(pl["windows"]), "upper": _has_upper(pl),
                      "route": list(pl["route"])})
    L.notes += pl["notes"]
    return pl
def _rows_fit(rect, facing, per, brief):
    from . import spawns
    from .layout import open_map
    spots, shields = spawns.base_layout({"rect": rect, "y": 0, "facing": facing}, per,
                                        brief["verticality"] == "flat", open_map(brief))
    x0, x1, z0, z1 = rect
    inside = all(x0 + 100 <= s["x"] <= x1 - 100 and z0 + 100 <= s["z"] <= z1 - 100
                 for s in spots)
    return inside and all(r[0] >= x0 and r[1] <= x1 and r[2] >= z0 and r[3] <= z1
                          for r, _, _ in shields)
def _has_upper(pl):
    return any(Lf["galleries"] for Lf in pl["leaves"])
def own_spawns(L, pl, F):
    pts = []
    by = {Lf["id"]: Lf for Lf in pl["leaves"]}
    per = 16 if pl["style"] == "course" else int(math.ceil(16.0 / max(1, len(pl["bases"]))))
    side = int(math.ceil(math.sqrt(per)))
    for bid in pl["bases"]:
        Lf = by[bid]
        x0, x1, z0, z1 = F.rect(_open_cells(Lf))
        cx, cz = (x0 + x1) // 2, (z0 + z1) // 2
        door = next((d for d in pl["doors"] if bid in (d["a"], d["b"])), None)
        yaw = 0
        if door is not None:
            dx0, dx1, dz0, dz1 = F.rect(door["cells"])
            yaw = int(round(math.degrees(math.atan2((dx0 + dx1) / 2.0 - cx,
                                                    (dz0 + dz1) / 2.0 - cz)) / 45.0)) * 45 % 360
        gap = 300 if pl["style"] == "course" else 400
        half = (side - 1) * gap / 2.0
        for i in range(per):
            a, b = i % side, i // side
            pts.append({"x": int(cx - half + a * gap) // 50 * 50, "y": 0,
                        "z": int(cz - half + b * gap) // 50 * 50, "yaw": yaw})
        span = int(half) + 300
        L.keep((cx - span, cx + span, cz - span, cz + span), copy=False)
    L.own_spawns = pts[:16]
    return pts
def hooks_world(pl, lift=0):
    F = Frame(pl)
    out = []
    for h in pl["hooks"]:
        x, z = F.point(*h["cell"])
        fx, fz = F.point(*h["from"])
        yaw = int(round(math.degrees(math.atan2(fx - x, fz - z)) / 45.0)) * 45 % 360
        out.append({"x": int(x), "y": lift, "z": int(z), "yaw": yaw, "room": h["room"],
                    "order": h["order"], "kind": "target"})
    return out
def finish(L, pl):
    from . import layout
    arena, meta = layout.finish(L)
    lift = 10 if L.brief["level"] == "empty" else 0
    if getattr(L, "own_spawns", None):
        mine = [dict(s, y=s["y"] + lift) for s in L.own_spawns]
        arena["spawns"] = mine
        field = [p for p in (arena["survey"].get("points") or [])
                 if all(math.hypot(p["x"] - s["x"], p["z"] - s["z"]) >= 1000 for s in mine)]
        arena["survey"]["points"] = mine + field[:12]
    if pl["style"] == "course":
        F = Frame(pl)
        by = {Lf["id"]: Lf for Lf in pl["leaves"]}
        hooks = hooks_world(pl, lift)
        arena["hooks"] = {"targets": hooks}
        meta["hooks"] = {"targets": hooks}
        last = pl["route"][-1]
        sx, sz = F.point(*by["start"].centre())
        fx, fz = F.point(*by[last].centre())
        arena["survey"]["lineStart"] = {"x": int(sx), "y": lift, "z": int(sz), "yaw": 0}
        arena["survey"]["lineFinish"] = {"x": int(fx), "y": lift, "z": int(fz), "yaw": 0}
        meta.setdefault("notes", []).append(
            "course: the route %s, the finish in %s; %d target hooks"
            % (" > ".join(pl["route"]), last, len(hooks)))
    meta["rooms"] = {"style": pl["style"], "footprint": [pl["W"], pl["D"]],
                     "leaves": len(pl["leaves"]), "doors": len(pl["doors"]),
                     "windows": len(pl["windows"]), "route": pl["route"],
                     "upper": _has_upper(pl)}
    return arena, meta
def build_family(brief, streams):
    from . import beauty, dice as dicemod, skeletons
    from .layout import Layout, Sym
    d = dicemod.roll(brief, streams("style"))
    pal, pal_notes = beauty.palette(brief["theme"], brief["palette"])
    L = Layout(brief, streams, d, Sym("none"), pal, brief["family"])
    r = streams("skeleton.rooms")
    across = skeletons.across_of(brief, brief["players"])
    L.params = skeletons.common_params(L, "rooms", across, r)
    pl = build_skeleton(L, L.params, r)
    L.notes += pal_notes
    L.anchor_lines = [("not yet", a["id"], "%s is not placed by the rooms skeleton" % a["what"])
                      for a in brief["anchors"]]
    budget_for(L, brief)
    arena, meta = finish(L, pl)
    arena["family"] = brief["family"]
    if pl["style"] == "course":
        arena["onlyFor"] = ["line"]
    meta["params"].setdefault("shape", "rooms")
    return arena, meta
def budget_for(L, brief):
    from . import budget as budgetmod
    from .layout import compile_pieces
    if "budget" not in (getattr(brief, "defaulted", ()) or ()):
        return
    need = len(compile_pieces(L))
    want = int(need * 1.6) + 40
    top = budgetmod.ceiling(brief["family"], brief["modes"])
    if want > brief["budget"]:
        brief.data["budget"] = min(top, want)
        L.notes.append("budget %d for the rooms (their %d structure pieces and room for "
                       "cover; the brief named none)" % (brief["budget"], need))
