import collections
import math
from . import graph
from . import mario
ROOM_STEP = mario.STEP_WALK
BASE_RADIUS = 12
def spawn_groups(spawns, link=1200):
    n = len(spawns)
    parent = list(range(n))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for i in range(n):
        for j in range(i + 1, n):
            if math.hypot(spawns[i]["x"] - spawns[j]["x"], spawns[i]["z"] - spawns[j]["z"]) < link:
                parent[find(i)] = find(j)
    groups = collections.OrderedDict()
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())
def rooms(world):
    nodes = world.nodes
    room_of = [-1] * len(nodes)
    out = []
    for s in range(len(nodes)):
        if not world.flat[s] or room_of[s] >= 0:
            continue
        rid = len(out)
        comp = [s]
        room_of[s] = rid
        stack = [s]
        while stack:
            u = stack.pop()
            hu = nodes[u][2]
            for v in world.adj2[u]:
                if room_of[v] < 0 and world.flat[v] and abs(nodes[v][2] - hu) <= ROOM_STEP:
                    room_of[v] = rid
                    comp.append(v)
                    stack.append(v)
        out.append(comp)
    return room_of, out
def has_block(world, comp, size=3):
    cols = set((world.nodes[i][0], world.nodes[i][1]) for i in comp)
    if len(cols) < size * size:
        return False
    for (x, z) in cols:
        ok = True
        for dx in range(size):
            for dz in range(size):
                if (x + dx, z + dz) not in cols:
                    ok = False
                    break
            if not ok:
                break
        if ok:
            return True
    return False
def perimeter(world, comp):
    cols = set((world.nodes[i][0], world.nodes[i][1]) for i in comp)
    n = 0
    for (x, z) in cols:
        if any((x + dx, z + dz) not in cols for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            n += 1
    return n
def exits(world, zone, target, min_size=2, diagonal=False):
    zone = set(zone)
    if target in zone:
        return []
    reach = graph.bfs(world.adj2, [target], blocked=zone)
    boundary = set()
    for u in zone:
        for v in world.adj2[u]:
            if v not in zone and reach[v] >= 0:
                boundary.add(v)
    if diagonal:
        nodes = world.nodes
        at = collections.defaultdict(list)
        for v in boundary:
            at[(nodes[v][0], nodes[v][1])].append(v)
        def near(u):
            x, z, h = nodes[u]
            out = list(world.adj2[u])
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for v in at.get((x + dx, z + dz), ()):
                        if v != u and abs(nodes[v][2] - h) <= mario.JUMP_SAFE:
                            out.append(v)
            return out
        comps = graph.components(sorted(boundary), near)
    else:
        comps = graph.components(sorted(boundary), lambda u: world.adj2[u])
    comps = [c for c in comps if len(c) >= min_size]
    comps.sort(key=lambda c: -len(c))
    return comps
def base_zone(world, spawn_nodes, radius=BASE_RADIUS):
    dist = {}
    q = collections.deque()
    for s in spawn_nodes:
        if s not in dist:
            dist[s] = 0
            q.append(s)
    while q:
        u = q.popleft()
        if dist[u] >= radius:
            continue
        for v in world.adj2[u]:
            if v not in dist:
                dist[v] = dist[u] + 1
                q.append(v)
    return set(dist)
def room_graph(world, room_of, room_list):
    n = len(world.nodes)
    group = list(room_of)
    ng = len(room_list)
    for s in range(n):
        if group[s] >= 0:
            continue
        gid = ng
        ng += 1
        group[s] = gid
        stack = [s]
        while stack:
            u = stack.pop()
            for v in world.adj2[u]:
                if group[v] < 0:
                    group[v] = gid
                    stack.append(v)
    adj = [set() for _ in range(ng)]
    for u in range(n):
        gu = group[u]
        for v in world.adj2[u]:
            gv = group[v]
            if gv != gu:
                adj[gu].add(gv)
                adj[gv].add(gu)
    return group, ng, adj
def cycle_stats(world, room_list, ng, gadj):
    adjl = [sorted(s) for s in gadj]
    art, comps = graph.biconnected(adjl)
    on_cycle = set()
    for comp in comps:
        if len(comp) >= 3:
            on_cycle |= comp
    total = sum(len(r) for r in room_list) or 1
    covered = sum(len(r) for rid, r in enumerate(room_list) if rid in on_cycle)
    e = sum(len(s) for s in gadj) // 2
    c = len(graph.components(range(ng), lambda u: adjl[u]))
    return covered / float(total), e - ng + c
def coarse_graph(world, k=2):
    nodes = world.nodes
    block = [((x // k), (z // k)) for (x, z, h) in nodes]
    cid = [-1] * len(nodes)
    members = []
    for s in range(len(nodes)):
        if cid[s] >= 0:
            continue
        c = len(members)
        cid[s] = c
        mem = [s]
        stack = [s]
        while stack:
            u = stack.pop()
            for v in world.adj2[u]:
                if cid[v] < 0 and block[v] == block[s]:
                    cid[v] = c
                    mem.append(v)
                    stack.append(v)
        members.append(mem)
    adj = [set() for _ in members]
    for u in range(len(nodes)):
        for v in world.adj2[u]:
            if cid[u] != cid[v]:
                adj[cid[u]].add(cid[v])
    return cid, members, [sorted(s) for s in adj]
def lanes_and_chokes(world, zone_a, zone_b, cap=24):
    cid, members, cadj = coarse_graph(world)
    src = set(cid[u] for u in zone_a)
    snk = set(cid[u] for u in zone_b)
    if src & snk or not src or not snk:
        return None, None, []
    flow, cut = graph.max_flow_vertex(cadj, src, snk, cap=cap)
    if not cut:
        return None, None, []
    nodes = world.nodes
    where = {}
    for c in cut:
        x, z, h = nodes[members[c][0]]
        where[c] = (x // 2, z // 2, h)
    def near(u):
        ux, uz, uh = where[u]
        return [v for v in cut if v != u and abs(where[v][0] - ux) <= 1
                and abs(where[v][1] - uz) <= 1 and abs(where[v][2] - uh) <= mario.JUMP_SAFE]
    comps = graph.components(sorted(cut), near)
    widths = sorted(len(c) * 200 for c in comps)
    lanes = len(comps)
    chokes = sum(1 for w in widths if w < 600)
    return lanes, chokes, widths
def jump_reach(world, important, max_saving_checks=6):
    nodes = world.nodes
    n = len(nodes)
    important = [i for i in important if i is not None]
    need = None
    slope = getattr(world, "slope", None) or [0.0] * n
    rc = mario.rise_class
    classes = [[rc(nodes[v][2] - nodes[u][2], max(slope[u], slope[v])) for v in world.adj[u]]
               for u in range(n)]
    for cls in (0, 1):
        adj = [[v for v, c in zip(world.adj[u], classes[u]) if c <= cls] for u in range(n)]
        if not important:
            need = 0
            break
        d = graph.bfs(adj, [important[0]])
        radj = [[] for _ in range(n)]
        for u, vs in enumerate(adj):
            for v in vs:
                radj[v].append(u)
        r = graph.bfs(radj, [important[0]])
        if all(d[i] >= 0 and r[i] >= 0 for i in important):
            need = cls
            break
    if need is None:
        need = 2
    jumps = sum(1 for u in range(n) for c in classes[u] if c > 0)
    edges = sum(len(vs) for vs in world.adj) or 1
    colh = collections.defaultdict(list)
    for i, (x, z, h) in enumerate(nodes):
        colh[(x, z)].append((h, i))
    links = []
    for i, (x, z, h) in enumerate(nodes):
        if not world.flat[i]:
            continue
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if any(h2 - h <= mario.JUMP_SAFE and h - h2 <= mario.DROP_SAFE
                   for h2, _ in colh.get((x + dx, z + dz), ())):
                continue
            for k in range(2, 15):
                land = [(h2, j) for h2, j in colh.get((x + dx * k, z + dz * k), ())
                        if h2 - h <= 100 and h - h2 <= mario.DROP_SAFE]
                if land:
                    h2, j = max(land)
                    gap = (k - 1) * mario.CELL
                    cls = mario.gap_class(gap, h - h2)
                    if cls <= 3:
                        links.append((gap, cls, i, j))
                    break
                if colh.get((x + dx * k, z + dz * k)):
                    break
    by_class = collections.Counter(c for _, c, _, _ in links)
    best_saving = 0.0
    seen_pairs = set()
    for gap, cls, i, j in sorted(links, key=lambda t: -t[0])[:max_saving_checks]:
        if (i, j) in seen_pairs:
            continue
        seen_pairs.add((i, j))
        d = graph.bfs(world.adj, [i])
        walk = d[j] if d[j] >= 0 else None
        if walk is None:
            saving = float("inf")
        else:
            saving = (walk * mario.CELL - gap) / float(mario.SPEED)
        best_saving = max(best_saving, saving)
    return {
        "jump_class_needed": need,
        "jump_edge_share": jumps / float(edges),
        "gap_links_running": by_class.get(1, 0),
        "gap_links_long": by_class.get(2, 0),
        "gap_links_expert": by_class.get(3, 0),
        "gap_best_saving_s": None if best_saving == float("inf") else round(best_saving, 2),
        "gap_reaches_new_floor": best_saving == float("inf"),
    }
