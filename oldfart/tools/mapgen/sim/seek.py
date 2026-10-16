import collections
import math
import random
from ..metrics import graph
from ..metrics import mario
from ..metrics.world import world_of
from . import bots
SEEKERS = 2
HIDERS = 16
ROUND_S = 180
HZ = bots.HZ
SPOT_SEEN = 0.05
SPREAD = 400
NEAR = 400
FOV = 180.0
RANGE = 2400
LOOK = 1.0
def _spots(table):
    k = len(table.sample)
    seen = [sum(1 for j in range(k) if j != i and table.vis[i][j]) for i in range(k)]
    order = sorted(range(k), key=lambda i: seen[i])
    spots = [i for i in order if seen[i] <= SPOT_SEEN * k]
    if len(spots) < HIDERS:
        spots = order[:max(HIDERS, len(spots))]
    return spots, seen
def sweep(arena, world=None, table=None, seekers=SEEKERS, seconds=ROUND_S, seed=1):
    w = world or world_of(arena)
    table = table or bots.Table(w)
    rnd = random.Random(seed)
    sample = table.sample
    spots, seen = _spots(table)
    spot_set = set(spots)
    hide = []
    for i in spots:
        p = sample[i]
        if all(math.hypot(p[0] - sample[j][0], p[2] - sample[j][2]) >= SPREAD for j in hide):
            hide.append(i)
        if len(hide) >= HIDERS:
            break
    spawns = arena.get("spawns") or []
    start = w.node_of(spawns[0]) if spawns else 0
    owners = table.owners
    found = {}
    looked = collections.Counter()
    per_tick = mario.SPEED / float(HZ) / mario.CELL
    cos_fov = math.cos(math.radians(FOV / 2.0))
    def look(node, tick, face):
        x, y, z = w.node_xyz(node)
        eye = (x, y + mario.EYE, z)
        for j in spots:
            if j in found:
                continue
            p = sample[j]
            d = math.hypot(p[0] - x, p[2] - z)
            if d <= NEAR:
                hit = True
            elif d > RANGE:
                continue
            else:
                if face is not None and ((p[0] - x) * face[0] + (p[2] - z) * face[1]) / d < cos_fov:
                    continue
                hit = not w.blocked(eye, p)
            if hit:
                found[j] = tick / float(HZ)
                looked[w.nodes[node][:2]] += 1
    pos = [start] * seekers
    paths = [[] for _ in range(seekers)]
    carry = [0.0] * seekers
    claimed = [None] * seekers
    visited = set()
    def near_enough(t, j):
        a, b = sample[t], sample[j]
        return math.hypot(a[0] - b[0], a[2] - b[2]) <= RANGE
    ticks = int(seconds * HZ)
    face = [None] * seekers
    pause = [0] * seekers
    for tick in range(ticks):
        for s in range(seekers):
            look(pos[s], tick, face[s])
        if len(found) == len(spots):
            break
        for s in range(seekers):
            if tick < pause[s]:
                continue
            if not paths[s]:
                dist = graph.bfs(w.adj, [pos[s]])
                best, score = None, -1.0
                others = set(claimed[o] for o in range(seekers) if o != s)
                for t, node in enumerate(owners):
                    if dist[node] <= 0 or t in visited or t in others:
                        continue
                    gain = sum(1 for j in spots if j not in found and table.vis[t][j]
                               and near_enough(t, j))
                    if gain <= 0:
                        continue
                    sc = gain / (dist[node] * mario.CELL / float(mario.SPEED) + 2.0)
                    sc *= 1.0 + 0.01 * rnd.random()
                    if sc > score:
                        best, score = t, sc
                if best is None:
                    left = [j for j in spots if j not in found and dist[owners[j]] > 0
                            and j not in visited]
                    if not left:
                        continue
                    best = min(left, key=lambda j: dist[owners[j]])
                claimed[s] = best
                visited.add(best)
                goal = owners[best]
                parent = {pos[s]: None}
                q = collections.deque([pos[s]])
                while q:
                    u = q.popleft()
                    if u == goal:
                        break
                    for v in w.adj[u]:
                        if v not in parent:
                            parent[v] = u
                            q.append(v)
                path = []
                u = goal if goal in parent else None
                while u is not None and u != pos[s]:
                    path.append(u)
                    u = parent[u]
                paths[s] = path[::-1]
            carry[s] += per_tick
            moved = pos[s]
            while carry[s] >= 1.0 and paths[s]:
                carry[s] -= 1.0
                pos[s] = paths[s].pop(0)
            if pos[s] != moved:
                ax, _, az = w.node_xyz(moved)
                bx, _, bz = w.node_xyz(pos[s])
                n = math.hypot(bx - ax, bz - az)
                if n > 1e-6:
                    face[s] = ((bx - ax) / n, (bz - az) / n)
            if not paths[s]:
                carry[s] = 0.0
                pause[s] = tick + int(LOOK * HZ)
    times = sorted(found.values())
    hidden = [j for j in hide if j not in found]
    metrics = {
        "hs9_spots": len(spots),
        "hs9_found_share": round(len(found) / float(len(spots)), 3) if spots else None,
        "hs9_find_frac": (round(times[len(times) // 2] / float(seconds), 3) if times else None),
        "hs9_survive_share": round(len(hidden) / float(len(hide)), 3) if hide else None,
        "hs9_seekers": seekers,
    }
    return {"metrics": metrics, "found": found, "looked": looked, "hiders": hide,
            "spots": [sample[j] for j in spots], "spot_set": spot_set}
