import collections
import math
from . import structure
BLOCK_TARGET = 240
ROOM_CELLS = 9
BASE_SHARE = 0.9
def _diamond(k):
    if k <= 3:
        return 1.0
    return 2.0 * (k * (math.log((k + 2) / 3.0, 2) - 1) + 1) / ((k - 1) * (k - 2))
def integrations(adj):
    n = len(adj)
    nb = [set(vs) for vs in adj]
    for u, vs in enumerate(adj):
        for v in vs:
            nb[v].add(u)
    nb = [list(s) for s in nb]
    out = []
    for i in range(n):
        dist = {i: 0}
        q = collections.deque([i])
        total = 0
        while q:
            u = q.popleft()
            du = dist[u] + 1
            for v in nb[u]:
                if v not in dist:
                    dist[v] = du
                    total += du
                    q.append(v)
        k = len(dist)
        if k < 3:
            out.append(None)
            continue
        md = total / float(k - 1)
        ra = 2.0 * (md - 1.0) / (k - 2)
        rra = ra / _diamond(k)
        out.append(1.0 / rra if rra > 1e-9 else float(k))
    return out
def blocks(world):
    n = max(1, len(world.columns))
    k = max(2, int(math.ceil(math.sqrt(n / float(BLOCK_TARGET)))))
    cid, members, cadj = structure.coarse_graph(world, k)
    return cid, cadj
def flow(world, groups, spawn_nodes, centre=None):
    centre = world.centre_node() if centre is None else centre
    out = {}
    cid, cadj = blocks(world)
    ints = integrations(cadj)
    ic = ints[cid[centre]] if ints else None
    vals = [v for v in ints if v is not None]
    if ic is not None and len(vals) >= 4:
        above = sum(1 for v in vals if v > ic + 1e-9)
        share = 1.0 - above / float(len(vals))
        s_rank = _clamp((share - 0.5) / 0.4)
        notes = ["the middle is more integrated than %d %% of the map" % round(share * 100)]
        score = s_rank
        if groups and len(groups) >= 2:
            ratios = []
            for grp in groups:
                bi = [ints[cid[spawn_nodes[i]]] for i in grp if i < len(spawn_nodes)]
                bi = [v for v in bi if v is not None]
                if bi:
                    ratios.append(sum(bi) / len(bi) / ic)
            if ratios:
                worst = max(ratios)
                s_base = _clamp(1.0 - (worst - BASE_SHARE) / 0.3)
                score = 0.6 * s_rank + 0.4 * s_base
                notes.append("the most central base at %d %% of the middle's" % round(worst * 100))
        out["integration"] = {"value": round(share, 3), "score": round(score, 3),
                              "note": "; ".join(notes)}
    room_of, room_list = structure.rooms(world)
    group, ng, adj = structure.room_graph(world, room_of, room_list)
    size = collections.Counter(group)
    gc = group[centre]
    rooms = [g for g, c in size.items() if c >= ROOM_CELLS and g != gc]
    if rooms:
        degs = sorted(len(adj[g]) for g in rooms)
        dc = len(adj[gc])
        med = degs[len(degs) // 2]
        s_mid = 1.0 if dc >= med else dc / float(max(med, 1))
        notes = ["the middle opens onto %d spaces (a room's median: %d)" % (dc, med)]
        s = s_mid
        if groups and len(groups) >= 2:
            bdeg = []
            for grp in groups:
                gs = set(group[spawn_nodes[i]] for i in grp if i < len(spawn_nodes))
                if gs:
                    bdeg.append(max(len(adj[g]) if g != gc else 99 for g in gs))
            if bdeg:
                dead = sum(1 for d in bdeg if d < 2)
                s = 0.6 * s_mid + 0.4 * (1.0 - dead / float(len(bdeg)))
                if dead:
                    notes.append("%d of %d bases with a single way out" % (dead, len(bdeg)))
        out["connectivity"] = {"value": dc, "score": round(s, 3), "note": "; ".join(notes)}
    return out
def _clamp(v):
    return max(0.0, min(1.0, v))
