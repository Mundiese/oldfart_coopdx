import hashlib
import heapq
import math
LAYER = 200
OCTAVES = 4
def _hash(seed, ix, iz):
    h = hashlib.blake2b(("%s:%d:%d" % (seed, ix, iz)).encode(), digest_size=4).digest()
    return int.from_bytes(h, "big") / float(2 ** 32)
def _smooth(t):
    return t * t * (3 - 2 * t)
def value_noise(x, z, seed):
    ix, iz = int(math.floor(x)), int(math.floor(z))
    fx, fz = _smooth(x - ix), _smooth(z - iz)
    a, b = _hash(seed, ix, iz), _hash(seed, ix + 1, iz)
    c, d = _hash(seed, ix, iz + 1), _hash(seed, ix + 1, iz + 1)
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz
def fbm(x, z, seed, octaves=OCTAVES, scale=1.0):
    total, weight, norm = 0.0, 1.0, 0.0
    f = scale
    for o in range(octaves):
        total += weight * value_noise(x * f, z * f, "%s/%d" % (seed, o))
        norm += weight
        weight *= 0.5
        f *= 2.0
    return total / norm
def heightfield(cells, seed, layers=3, scale=0.18):
    cells = list(cells)
    raw = {c: fbm(c[0], c[1], seed, scale=scale) for c in cells}
    lo, hi = min(raw.values()), max(raw.values())
    span = (hi - lo) or 1.0
    h = {c: min(layers - 1, int((raw[c] - lo) / span * layers)) for c in cells}
    cs = set(cells)
    for _ in range(layers * 4):
        changed = False
        for c in cells:
            for n in _nb(c):
                if n in cs and h[c] - h[n] > 1:
                    h[c] = h[n] + 1
                    changed = True
        if not changed:
            break
    return h
def smooth(h, keep=(), n8=False):
    keep = set(keep)
    cs = set(h)
    nbs = _nb8 if n8 else _nb
    for _ in range(4 * (max(h.values()) + 1 if h else 1)):
        changed = False
        for c in sorted(h):
            if c in keep:
                continue
            for n in nbs(c):
                if n in cs and h[c] - h[n] > 1:
                    h[c] = h[n] + 1
                    changed = True
        if not changed:
            break
    return h
def _nb(c):
    return ((c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1))
def _nb8(c):
    return _nb(c) + ((c[0] + 1, c[1] + 1), (c[0] - 1, c[1] - 1), (c[0] + 1, c[1] - 1),
                     (c[0] - 1, c[1] + 1))
def chamfer(cells, sources):
    cells = set(cells)
    dist = {}
    pq = [(0.0, c) for c in sorted(sources) if c in cells]
    heapq.heapify(pq)
    for d, c in pq:
        dist[c] = 0.0
    while pq:
        d, c = heapq.heappop(pq)
        if d > dist.get(c, float("inf")):
            continue
        for k, n in enumerate(_nb8(c)):
            if n not in cells:
                continue
            nd = d + (1.0 if k < 4 else 1.41421356)
            if nd < dist.get(n, float("inf")):
                dist[n] = nd
                heapq.heappush(pq, (nd, n))
    return dist
def river(h, start=None):
    cs = set(h)
    xs = [c[0] for c in cs]
    zs = [c[1] for c in cs]
    edge = [c for c in cs if c[0] in (min(xs), max(xs)) or c[1] in (min(zs), max(zs))]
    if not edge:
        return []
    cur = start or max(edge, key=lambda c: (h[c], c))
    path, seen = [cur], {cur}
    while True:
        nbs = [n for n in _nb(cur) if n in cs and n not in seen]
        if not nbs:
            break
        nxt = min(nbs, key=lambda n: (h[n], -abs(n[0] - cur[0]) - abs(n[1] - cur[1]), n))
        if h[nxt] > h[cur] and len(path) > 2:
            break
        path.append(nxt)
        seen.add(nxt)
        cur = nxt
        if nxt in edge and len(path) > 3:
            break
    return path
def road(h, a, b, wet=()):
    wet = set(wet)
    cs = set(h)
    openq = [(0, a)]
    came, cost = {a: None}, {a: 0}
    while openq:
        _, cur = heapq.heappop(openq)
        if cur == b:
            break
        for n in _nb(cur):
            if n not in cs:
                continue
            step = 1 + 5 * abs(h[n] - h[cur]) + (100 if n in wet else 0)
            nc = cost[cur] + step
            if n not in cost or nc < cost[n]:
                cost[n] = nc
                came[n] = cur
                heapq.heappush(openq, (nc + abs(n[0] - b[0]) + abs(n[1] - b[1]), n))
    if b not in came:
        return []
    out, cur = [], b
    while cur is not None:
        out.append(cur)
        cur = came[cur]
    return list(reversed(out))
def ramps_for(h, free):
    out = {}
    for c in sorted(h):
        if c not in free:
            continue
        for n, d in zip(_nb(c), ("+x", "-x", "+z", "-z")):
            if n in h and h[n] == h[c] + 1:
                out[c] = d
                break
    return out
def macro(cells, seed):
    f = {}
    for (i, j) in cells:
        wx = i + 6 * (fbm(i, j, seed + "wx", octaves=2, scale=0.04) - 0.5)
        wz = j + 6 * (fbm(i, j, seed + "wz", octaves=2, scale=0.04) - 0.5)
        cont = fbm(wx, wz, seed + "c", octaves=2, scale=0.025)
        r = fbm(wx, wz, seed + "r", octaves=3, scale=0.05)
        ridge = 1 - abs(2 * r - 1)
        f[(i, j)] = 0.55 * cont + 0.45 * ridge * ridge * cont * 1.6
    lo, hi = min(f.values()), max(f.values())
    return {c: (v - lo) / ((hi - lo) or 1.0) for c, v in f.items()}
def _edge(f):
    return [c for c in f if any(n not in f for n in _nb(c))]
def priority_flood(f):
    out = dict(f)
    seen = set()
    pq = []
    for c in _edge(f):
        heapq.heappush(pq, (f[c], c))
        seen.add(c)
    while pq:
        h, c = heapq.heappop(pq)
        for n in _nb(c):
            if n in f and n not in seen:
                seen.add(n)
                out[n] = max(f[n], h + 1e-6)
                heapq.heappush(pq, (out[n], n))
    return out
def depressions(f, least=0.004):
    filled = priority_flood(f)
    return {c: filled[c] - f[c] for c in f if filled[c] - f[c] >= least}
def flow_acc(f):
    rec = {}
    for c, v in f.items():
        best = None
        for n in _nb(c):
            if n in f and f[n] < v and (best is None or f[n] < f[best]):
                best = n
        rec[c] = best
    acc = {c: 1 for c in f}
    for c in sorted(f, key=lambda c: (-f[c], c)):
        if rec[c] is not None:
            acc[rec[c]] += acc[c]
    return rec, acc
def trunk(f, min_flow=6):
    filled = priority_flood(f)
    rec, acc = flow_acc(filled)
    edge = set(_edge(f))
    mouth = max(sorted(edge), key=lambda c: acc[c])
    up = {}
    for c, r in sorted(rec.items()):
        if r is not None:
            up.setdefault(r, []).append(c)
    path, cur = [mouth], mouth
    while cur in up:
        cur = max(up[cur], key=lambda c: (acc[c], c))
        if acc[cur] < min_flow:
            break
        path.append(cur)
    return list(reversed(path))
def climb_ramps(h, free):
    if not h:
        return {}
    top = max(sorted(h), key=lambda c: (h[c], c))
    out = {}
    cur = top
    seen = {cur}
    while h.get(cur, 0) > 0:
        lower = [n for n in _nb(cur) if n in h and n not in seen and h[n] == h[cur] - 1]
        if not lower:
            lower = [n for n in _nb(cur) if n in h and n not in seen and h[n] < h[cur]]
        if not lower:
            break
        n = min(lower, key=lambda c: (h[c], c))
        if n in free:
            for m, d in zip(_nb(n), ("+x", "-x", "+z", "-z")):
                if m == cur:
                    out[n] = d
        seen.add(n)
        cur = n
    return out
