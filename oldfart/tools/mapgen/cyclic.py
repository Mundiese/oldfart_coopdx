RULES = ("close", "shortcut", "gambit", "flank")
def _adj(nodes, edges):
    adj = {n: set() for n in nodes}
    for a, b in edges:
        adj[a].add(b)
        adj[b].add(a)
    return adj
def _dist(adj, a):
    d = {a: 0}
    todo = [a]
    while todo:
        nxt = []
        for x in todo:
            for y in sorted(adj[x]):
                if y not in d:
                    d[y] = d[x] + 1
                    nxt.append(y)
        todo = nxt
    return d
def cycles(nodes, edges):
    adj = _adj(nodes, edges)
    seen = set()
    parts = 0
    for n in sorted(nodes):
        if n in seen:
            continue
        parts += 1
        seen |= set(_dist(adj, n))
    return len(set(tuple(sorted(e)) for e in edges)) - len(nodes) + parts
def candidates(rule, nodes, edges, allowed, length=None):
    adj = _adj(nodes, edges)
    have = set(tuple(sorted(e)) for e in edges)
    ok = [tuple(sorted(e)) for e in allowed if tuple(sorted(e)) not in have]
    L = length or (lambda e: 0)
    out = []
    if rule == "close":
        ends = set(n for n in nodes if len(adj[n]) == 1)
        out = [e for e in ok if e[0] in ends or e[1] in ends]
    elif rule == "shortcut":
        for e in ok:
            d = _dist(adj, e[0]).get(e[1], 99)
            if d >= 3:
                out.append(e)
    elif rule == "gambit":
        for e in ok:
            if adj[e[0]] & adj[e[1]]:
                out.append(e)
    elif rule == "flank":
        for e in ok:
            d = _dist(adj, e[0]).get(e[1], 99)
            if d == 2 and len(adj[e[0]] & adj[e[1]]) == 1:
                out.append(e)
    return sorted(set(out), key=lambda e: (L(e), e))
def rewrite(nodes, edges, allowed, r, steps, length=None, rules=RULES):
    edges = [tuple(e) for e in edges]
    log = []
    for _ in range(steps):
        order = list(rules)
        r.shuffle(order)
        done = False
        for rule in order:
            cs = candidates(rule, nodes, edges, allowed, length)
            if not cs:
                continue
            e = cs[int(r.random() * min(3, len(cs)))]
            edges.append(e)
            log.append((rule, e[0], e[1]))
            done = True
            break
        if not done:
            break
    return edges, log
