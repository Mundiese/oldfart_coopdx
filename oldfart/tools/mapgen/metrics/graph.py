import collections
BFS_NUMPY_FROM = 20000
_CSR = []
def _csr(adj):
    import numpy as np
    edges = sum(map(len, adj))
    for ref, out in _CSR:
        if ref is adj and len(out[0]) == len(adj) + 1 and int(out[0][-1]) == edges:
            return out
    lens = np.fromiter((len(a) for a in adj), dtype=np.int64, count=len(adj))
    indptr = np.zeros(len(adj) + 1, dtype=np.int64)
    np.cumsum(lens, out=indptr[1:])
    indices = np.fromiter((v for a in adj for v in a), dtype=np.int64, count=int(indptr[-1]))
    out = (indptr, indices)
    _CSR.insert(0, (adj, out))
    del _CSR[4:]
    return out
def _bfs_numpy(adj, sources, blocked):
    import numpy as np
    indptr, indices = _csr(adj)
    n = len(adj)
    dist = np.full(n, -1, dtype=np.int64)
    if blocked:
        dist[np.fromiter((b for b in blocked if 0 <= b < n), dtype=np.int64)] = -2
    src = sorted(set(s for s in sources if s is not None and dist[s] == -1))
    if not src:
        dist[dist == -2] = -1
        return dist.tolist()
    front = np.asarray(src, dtype=np.int64)
    dist[front] = 0
    owner = np.empty(n, dtype=np.int64)
    level = 0
    while front.size:
        level += 1
        starts = indptr[front]
        lens = indptr[front + 1] - starts
        total = int(lens.sum())
        if not total:
            break
        offs = np.repeat(starts - (np.cumsum(lens) - lens), lens) + np.arange(total)
        nxt = indices[offs]
        nxt = nxt[dist[nxt] == -1]
        if not nxt.size:
            break
        pos = np.arange(nxt.size)
        owner[nxt] = pos
        nxt = nxt[owner[nxt] == pos]
        dist[nxt] = level
        front = nxt
    if blocked:
        dist[dist == -2] = -1
    return dist.tolist()
def bfs(adj, sources, blocked=None):
    if len(adj) >= BFS_NUMPY_FROM:
        try:
            return _bfs_numpy(adj, sources, blocked)
        except ImportError:
            pass
    dist = [-1] * len(adj)
    q = collections.deque()
    for s in sources:
        if s is not None and dist[s] < 0 and not (blocked and s in blocked):
            dist[s] = 0
            q.append(s)
    while q:
        u = q.popleft()
        du = dist[u] + 1
        for v in adj[u]:
            if dist[v] < 0 and not (blocked and v in blocked):
                dist[v] = du
                q.append(v)
    return dist
def components(nodes, neighbours):
    inside = set(nodes)
    seen = set()
    out = []
    for s in nodes:
        if s in seen:
            continue
        comp = [s]
        seen.add(s)
        stack = [s]
        while stack:
            u = stack.pop()
            for v in neighbours(u):
                if v in inside and v not in seen:
                    seen.add(v)
                    comp.append(v)
                    stack.append(v)
        out.append(comp)
    return out
def biconnected(adj):
    n = len(adj)
    disc = [-1] * n
    low = [0] * n
    art = set()
    comps = []
    t = 0
    for root in range(n):
        if disc[root] >= 0:
            continue
        disc[root] = low[root] = t
        t += 1
        children = 0
        stack = [(root, -1, iter(range(len(adj[root]))))]
        estack = []
        while stack:
            u, pe, it = stack[-1]
            advanced = False
            for k in it:
                v = adj[u][k]
                if (u, k) == pe:
                    continue
                if disc[v] < 0:
                    disc[v] = low[v] = t
                    t += 1
                    estack.append((u, v))
                    back = adj[v].index(u) if u in adj[v] else -1
                    stack.append((v, (v, back), iter(range(len(adj[v])))))
                    if u == root:
                        children += 1
                    advanced = True
                    break
                elif disc[v] < disc[u]:
                    low[u] = min(low[u], disc[v])
                    estack.append((u, v))
            if advanced:
                continue
            stack.pop()
            if stack:
                p = stack[-1][0]
                low[p] = min(low[p], low[u])
                if low[u] >= disc[p]:
                    if p != root:
                        art.add(p)
                    comp = set()
                    while estack:
                        a, b = estack.pop()
                        comp.add(a)
                        comp.add(b)
                        if (a, b) == (p, u):
                            break
                    comps.append(comp)
        if children > 1:
            art.add(root)
    return art, comps
def max_flow_vertex(adj, sources, sinks, cap=64):
    n = len(adj)
    S, T = 2 * n, 2 * n + 1
    src, snk = set(sources), set(sinks)
    res = collections.defaultdict(dict)
    def add(a, b, c):
        res[a][b] = res[a].get(b, 0) + c
        res[b].setdefault(a, 0)
    big = 1 << 30
    for u in range(n):
        add(2 * u, 2 * u + 1, big if (u in src or u in snk) else 1)
        for v in adj[u]:
            add(2 * u + 1, 2 * v, big)
    for s in src:
        add(S, 2 * s, big)
    for t in snk:
        add(2 * t + 1, T, big)
    flow = 0
    while flow < cap:
        parent = {S: None}
        q = collections.deque([S])
        while q and T not in parent:
            a = q.popleft()
            for b, c in res[a].items():
                if c > 0 and b not in parent:
                    parent[b] = a
                    q.append(b)
        if T not in parent:
            break
        b = T
        while parent[b] is not None:
            a = parent[b]
            res[a][b] -= 1
            res[b][a] += 1
            b = a
        flow += 1
    if flow >= cap:
        return flow, set()
    seen = {S}
    q = collections.deque([S])
    while q:
        a = q.popleft()
        for b, c in res[a].items():
            if c > 0 and b not in seen:
                seen.add(b)
                q.append(b)
    cut = set(u for u in range(n) if (2 * u) in seen and (2 * u + 1) not in seen)
    return flow, cut
