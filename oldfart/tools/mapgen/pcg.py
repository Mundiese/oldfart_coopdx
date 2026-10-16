import heapq
import math
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))
def poisson_disk(cells, radius, r, k=24, limit=None):
    cells = set(cells)
    if not cells:
        return []
    order = sorted(cells)
    start = order[int(r.random() * len(order))]
    out, active = [start], [start]
    r2 = radius * radius
    def free(c):
        for p in out:
            if (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 < r2:
                return False
        return True
    while active and (limit is None or len(out) < limit):
        idx = int(r.random() * len(active))
        p = active[idx]
        placed = False
        for _ in range(k):
            a = r.random() * 2 * math.pi
            d = radius * (1 + r.random())
            c = (int(round(p[0] + d * math.cos(a))), int(round(p[1] + d * math.sin(a))))
            if c in cells and free(c):
                out.append(c)
                active.append(c)
                placed = True
                break
        if not placed:
            active.pop(idx)
    return out
def voronoi(cells, sites):
    owner = {}
    for c in cells:
        best, bi = None, -1
        for i, s in enumerate(sites):
            d = (s[0] - c[0]) ** 2 + (s[1] - c[1]) ** 2
            if best is None or d < best:
                best, bi = d, i
        owner[c] = bi
    return owner
def borders(owner):
    edge_cells, pairs = set(), set()
    for (i, j), d in owner.items():
        for di, dj in N4:
            o = owner.get((i + di, j + dj))
            if o is not None and o != d:
                edge_cells.add((i, j))
                pairs.add((min(d, o), max(d, o)))
    return edge_cells, pairs
def delaunay_mst(sites, pairs, extra, r):
    def length(e):
        a, b = sites[e[0]], sites[e[1]]
        return math.hypot(a[0] - b[0], a[1] - b[1])
    edges = sorted(pairs, key=lambda e: (length(e), e))
    parent = list(range(len(sites)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    tree, rest = [], []
    for e in edges:
        a, b = find(e[0]), find(e[1])
        if a != b:
            parent[a] = b
            tree.append(e)
        else:
            rest.append(e)
    rest.sort(key=lambda e: (length(e) * (0.8 + 0.4 * r.random()), e))
    return tree + rest[:extra]
def ca_caves(cells, r, fill=0.45, steps=4, birth=5, survive=4):
    cells = set(cells)
    wall = set(c for c in sorted(cells) if r.random() < fill)
    for _ in range(steps):
        nxt = set()
        for c in cells:
            n = sum(1 for di, dj in N8 if (c[0] + di, c[1] + dj) in wall)
            if (c in wall and n >= survive) or (c not in wall and n >= birth):
                nxt.add(c)
        wall = nxt
    return wall
def distance_field(cells, sources):
    cells = set(cells)
    dist = {}
    heap = [(0, s) for s in sorted(sources) if s in cells]
    for _, s in heap:
        dist[s] = 0
    heapq.heapify(heap)
    while heap:
        d, c = heapq.heappop(heap)
        if d > dist.get(c, 1e9):
            continue
        for di, dj in N4:
            n = (c[0] + di, c[1] + dj)
            if n in cells and d + 1 < dist.get(n, 1e9):
                dist[n] = d + 1
                heapq.heappush(heap, (d + 1, n))
    return dist
def largest_component(cells):
    left = set(cells)
    best = []
    for c in sorted(left):
        if c not in left:
            continue
        group, todo = [c], [c]
        left.discard(c)
        while todo:
            nxt = []
            for a in todo:
                for d in N4:
                    m = (a[0] + d[0], a[1] + d[1])
                    if m in left:
                        left.discard(m)
                        group.append(m)
                        nxt.append(m)
            todo = nxt
        if len(group) > len(best):
            best = group
    return sorted(best)
def farthest_points(cells, k, r, first=None, weight=None):
    cells = sorted(set(cells))
    if not cells:
        return []
    pick = [first if first in cells else cells[int(r.random() * len(cells))]]
    dist = distance_field(cells, pick)
    while len(pick) < k:
        best, bc = -1, None
        for c in cells:
            d = dist.get(c, 0) * (weight(c) if weight else 1.0)
            if d > best:
                best, bc = d, c
        if bc is None or best <= 0:
            break
        pick.append(bc)
        nd = distance_field(cells, [bc])
        for c in cells:
            if nd.get(c, 1e9) < dist.get(c, 1e9):
                dist[c] = nd[c]
    return pick
