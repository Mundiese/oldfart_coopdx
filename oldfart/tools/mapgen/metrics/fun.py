import collections
import heapq
import math
from .. import movement
from . import graph
from . import mario
from . import structure
from . import vis
G = mario.CELL
RATIO = 1.3
BUFFER = 300
EXEMPT = 600
ROUTES_CAP = 5
FLANK_TAIL = 1500
HOLD_SPOTS = 3
HOLD_RANGE = 2400
ARRIVAL = 600
CB_FRONTS = (0.25, 0.75)
CB2_RANGE = 2400
CAMP_AWAY = 800
SHORTCUT_S = 1.0
SPLIT_SAVE_S = 1.5
SPLIT_SAVE_SHARE = 0.15
PARITY = 0.10
SKILL = 0.10
FAIL = {1: 0.02, 2: 0.08, 3: 0.20, 4: 0.35}
EXPERT = 0.25
REPLAY_CAP_S = 10.0
JUMP_S = 0.5
KICK_S = 0.5
GOAL_TOUCH = 300
GOAL_ABOVE = 300
GP_UP_DOWN = 300
BFS_CAP = 16
MOVE_STRIDE = 2
def _xz(w, i):
    gx, gz, _ = w.nodes[i]
    return ((gx + .5) * G, (gz + .5) * G)
def _path(adj, sources, target, blocked=None):
    parent = {}
    q = collections.deque()
    for s in sources:
        if s is not None and s not in parent and not (blocked and s in blocked):
            parent[s] = None
            q.append(s)
    while q:
        u = q.popleft()
        if u == target:
            break
        for v in adj[u]:
            if v not in parent and not (blocked and v in blocked):
                parent[v] = u
                q.append(v)
    if target not in parent:
        return None
    out = []
    u = target
    while u is not None:
        out.append(u)
        u = parent[u]
    out.reverse()
    return out
def _columns(w):
    col = getattr(w, "_fun_cols", None)
    if col is None:
        col = collections.defaultdict(list)
        for i, (gx, gz, h) in enumerate(w.nodes):
            col[(gx, gz)].append(i)
        w._fun_cols = col
    return col
def viable_routes(w, sources, target, ratio=RATIO, buffer=BUFFER, cap=ROUTES_CAP):
    sources = [s for s in sources if s is not None]
    if not sources or target is None:
        return []
    col = _columns(w)
    ends = [_xz(w, s) for s in sources] + [_xz(w, target)]
    r = int(math.ceil(buffer / float(G)))
    disk = [(dx, dz) for dx in range(-r, r + 1) for dz in range(-r, r + 1)
            if dx * dx + dz * dz <= r * r]
    def exempt(i):
        x, z = _xz(w, i)
        return any(math.hypot(x - a, z - b) <= EXEMPT for a, b in ends)
    blocked = set()
    routes = []
    best = None
    while len(routes) < cap:
        p = _path(w.adj, sources, target, blocked)
        if p is None:
            break
        if best is None:
            best = len(p)
        elif len(p) - 1 > ratio * (best - 1):
            break
        routes.append(p)
        for u in p:
            gx, gz, h = w.nodes[u]
            for dx, dz in disk:
                for v in col.get((gx + dx, gz + dz), ()):
                    if abs(w.nodes[v][2] - h) <= buffer and not exempt(v):
                        blocked.add(v)
        if not any(not exempt(u) for u in p):
            break
    return routes
TARGET_AWAY = 1500
def _targets(w, arena, centre, sources=()):
    out = [centre]
    home = [_xz(w, s) for s in sources if s is not None]
    for key, val in (arena.get("survey") or {}).items():
        if key == "points":
            continue
        for spot in (val if isinstance(val, list) else [val]):
            if isinstance(spot, dict) and "x" in spot and len(out) < 4:
                if any(math.hypot(spot["x"] - a, spot["z"] - b) < TARGET_AWAY for a, b in home):
                    continue
                n = w.node_of(spot)
                if n not in out:
                    out.append(n)
    return out
def move_edges(w):
    cache = getattr(w, "_fun_moves", None)
    if cache is not None:
        return cache
    nodes = w.nodes
    col = _columns(w)
    tops = {}
    for (gx, gz, h) in w.all_cells:
        k = (gx, gz)
        if h > tops.get(k, -1e18):
            tops[k] = h
    out = []
    seen_chimney = set()
    for u, (gx, gz, h) in enumerate(nodes):
        if not w.flat[u]:
            continue
        strided = not (gx % MOVE_STRIDE or gz % MOVE_STRIDE)
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = col.get((gx + dx, gz + dz), ())
            for v in nxt:
                rise = nodes[v][2] - h
                if mario.JUMP_SAFE < rise <= mario.JUMP_TRIPLE and v not in w.adj[u]:
                    verb = "double jump" if rise <= mario.JUMP_DOUBLE else "triple jump"
                    out.append((u, v, verb, mario.rise_class(rise), JUMP_S + 0.6, (gx + dx, gz + dz)))
            if not strided:
                continue
            if any(nodes[v][2] - h <= mario.JUMP_SAFE and h - nodes[v][2] <= mario.DROP_SAFE
                   for v in nxt):
                continue
            for k in range(2, int(mario.GAP_EXPERT // G) + 2):
                land = [v for v in col.get((gx + dx * k, gz + dz * k), ())
                        if nodes[v][2] - h <= 100 and h - nodes[v][2] <= mario.DROP_SAFE]
                if land:
                    v = max(land, key=lambda j: nodes[j][2])
                    gap = (k - 1) * G
                    cls = mario.gap_class(gap, h - nodes[v][2])
                    if 2 <= cls <= 3:
                        out.append((u, v, "long jump", cls, gap / float(movement.LONG_JUMP) + JUMP_S,
                                    (gx + dx * k, gz + dz * k)))
                    break
                if (gx + dx * k, gz + dz * k) in tops and \
                        tops[(gx + dx * k, gz + dz * k)] > h + mario.JUMP_SAFE:
                    break
        for ax in (((1, 0), (0, 1)) if strided else ()):
            walls = []
            for sgn in (1, -1):
                for k in range(1, int(movement.CHIMNEY_MAX // G) + 2):
                    c = (gx + ax[0] * k * sgn, gz + ax[1] * k * sgn)
                    t = tops.get(c)
                    if t is not None and t > h + mario.JUMP_TRIPLE:
                        walls.append((k, c, t))
                        break
                    if t is not None and t > h + mario.STEP_UP:
                        break
            if len(walls) < 2:
                continue
            width = (walls[0][0] + walls[1][0] - 1) * G
            if not movement.chimney(width):
                continue
            k_lo, c_lo, t_lo = min(walls, key=lambda wl: wl[2])
            key = (c_lo, t_lo)
            if key in seen_chimney:
                continue
            seen_chimney.add(key)
            v = w.index.get((c_lo[0], c_lo[1], t_lo))
            kicks = max(1, int(math.ceil((t_lo - h) / 330.0)))
            out.append((u, v, "wall kick", 3, kicks * KICK_S + 0.6, c_lo))
    w._fun_moves = out
    return out
def _region(c, size=4):
    return (c[0] // size, c[1] // size)
def shortcuts(w, important=None, cap=BFS_CAP):
    edges = move_edges(w)
    groups = collections.OrderedDict()
    for e in edges:
        u, v, verb, cls, t, at = e
        key = (_region(w.nodes[u][:2]), verb, _region(at))
        if key not in groups:
            groups[key] = e
    out = []
    dist_cache = {}
    for key, (u, v, verb, cls, t, at) in groups.items():
        if v is None:
            out.append((verb, float("inf"), u, v, at))
            continue
        if u not in dist_cache:
            if len(dist_cache) >= cap:
                continue
            dist_cache[u] = graph.bfs(w.adj, [u])
        d = dist_cache[u][v]
        if d < 0:
            out.append((verb, float("inf"), u, v, at))
            continue
        saving = mario.path_time_s(d) - (t + mario.STARTUP / float(mario.FPS))
        if saving >= SHORTCUT_S:
            out.append((verb, saving, u, v, at))
    return out
def _dijkstra(w, source, extra):
    step = G / float(mario.SPEED)
    more = collections.defaultdict(list)
    for u, v, cls, t in extra:
        more[u].append((v, cls, t))
    best = {source: 0.0}
    parent = {source: None}
    via = {source: 0}
    heap = [(0.0, source)]
    while heap:
        d, u = heapq.heappop(heap)
        if d > best.get(u, 1e18):
            continue
        for v in w.adj[u]:
            nd = d + step
            if nd < best.get(v, 1e18):
                best[v], parent[v], via[v] = nd, u, 0
                heapq.heappush(heap, (nd, v))
        for v, cls, t in more.get(u, ()):
            nd = d + t
            if nd < best.get(v, 1e18):
                best[v], parent[v], via[v] = nd, u, cls
                heapq.heappush(heap, (nd, v))
    return best, parent, via
def expected(t, beats, expert=False):
    k = EXPERT if expert else 1.0
    return t + sum(FAIL.get(c, 0.35) * k * min(REPLAY_CAP_S, max(1.0, at)) for c, at in beats)
def splits(w, pairs):
    extra = [(u, v, cls, t) for u, v, verb, cls, t, at in move_edges(w) if v is not None]
    rows = []
    done = {}
    for s, g in pairs:
        if s is None or g is None or s == g:
            continue
        if s not in done:
            if len(done) >= BFS_CAP:
                continue
            walk = graph.bfs(w.adj, [s])
            done[s] = (walk, _dijkstra(w, s, extra))
        walk, (best, parent, via) = done[s]
        if walk[g] < 0 or g not in best:
            continue
        safe = (walk[g] * G) / float(mario.SPEED)
        risky = best[g]
        beats = []
        u = g
        while parent.get(u) is not None:
            if via[u] >= 2:
                beats.append((via[u], best[parent[u]]))
            u = parent[u]
        if not beats or risky >= safe:
            continue
        sl2 = safe - risky >= SPLIT_SAVE_S and (safe - risky) >= SPLIT_SAVE_SHARE * safe
        sl3 = max(c for c, _ in beats) >= 2
        e_risky, e_safe = expected(risky, beats), safe
        sl4 = abs(e_risky - e_safe) <= PARITY * e_safe
        sl5 = expected(risky, beats, expert=True) <= (1 - SKILL) * safe
        rows.append({"safe_s": round(safe, 2), "risky_s": round(risky, 2), "beats": len(beats),
                     "sl2": sl2, "sl3": sl3, "sl4": sl4, "sl5": sl5,
                     "real": sl2 and sl3 and sl4 and sl5, "goal": g})
    return rows
def _walk_adj(w):
    movers = set()
    for a, outs in (getattr(w, "mover_edges", None) or {}).items():
        for b in outs:
            if a in w.index and b in w.index:
                movers.add((w.index[a], w.index[b]))
    if not movers:
        return w.adj
    return [[v for v in vs if (u, v) not in movers] for u, vs in enumerate(w.adj)]
def goals_metrics(w, goals, spawn, m):
    goals = [g for g in goals if isinstance(g, dict) and "x" in g]
    if not goals or spawn is None:
        return
    adj = _walk_adj(w)
    s = w.node_of(spawn)
    reach = graph.bfs(adj, [s])
    col = _columns(w)
    walked = []
    for g in goals:
        gx, gz = int(math.floor(g["x"] / G)), int(math.floor(g["z"] / G))
        r = int(GOAL_TOUCH // G)
        ok = False
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                for v in col.get((gx + dx, gz + dz), ()):
                    h = w.nodes[v][2]
                    if reach[v] >= 0 and 0 <= g.get("y", 0) - h <= GOAL_ABOVE:
                        ok = True
                        break
                if ok:
                    break
            if ok:
                break
        walked.append(ok)
    m["gp1_move_share"] = round(1.0 - sum(walked) / float(len(goals)), 3)
    sy = spawn.get("y", 0)
    d = [math.hypot(g["x"] - spawn["x"], g["z"] - spawn["z"]) for g in goals]
    near = min(range(len(goals)), key=lambda i: d[i])
    m["gp1_walkable_goals"] = sum(walked)
    m["gp1_walkable_near_start"] = 1 if any(walked[i] and mario.distance_time_s(d[i]) <= 8.0
                                            for i in range(len(goals))) else 0
    hs = [w.nodes[i][2] for i in range(len(w.nodes))]
    floor_span = (max(hs) - min(hs)) if hs else 0
    ys = [g.get("y", 0) for g in goals]
    m["gp2_height_span"] = round((max(ys) - min(ys)) / float(floor_span), 3) if floor_span > 0 else None
    above = sum(1 for y in ys if y - sy >= GP_UP_DOWN + 200)
    below = sum(1 for y in ys if y - sy <= 200 - GP_UP_DOWN)
    m["gp3_above_share"] = round(above / float(len(goals)), 3)
    has_low = any(h <= sy - GP_UP_DOWN for h in hs)
    m["gp3_below_share"] = round(below / float(len(goals)), 3) if has_low else None
    ts = [mario.distance_time_s(x) - mario.STARTUP / float(mario.FPS) for x in d]
    m["gp4_nearest_s"] = round(ts[near], 1)
    m["gp4_farthest_s"] = round(max(ts), 1)
def symmetry_units(arena):
    from . import qd
    sym = qd.symmetry_of(arena)
    if sym == "none":
        sym = (arena.get("brief") or {}).get("symmetry") or arena.get("symmetry") or ""
    return {"turn4": 4, "turn3": 3, "mirror": 2, "mirror_x": 2, "mirror_z": 2, "turn2": 2,
            "mirror2": 4, "mirror4": 4}.get(str(sym), 1)
def cheap(w, arena, fam, m, extra, spawn_nodes, groups, fields, centre):
    lf1 = []
    routes_of = {}
    if groups and spawn_nodes:
        for gi, g in enumerate(groups[:4]):
            src = [spawn_nodes[i] for i in g]
            for t in _targets(w, arena, centre, src):
                rs = viable_routes(w, src, t)
                if rs:
                    lf1.append(len(rs))
                    routes_of[(gi, t)] = rs
    m["lf1_viable_routes"] = min(lf1) if lf1 else None
    extra["fun_routes"] = routes_of
    m["cb1_home_ratio"] = None
    if len(groups) == 2 and len(fields) == 2:
        cen = []
        for g in groups:
            xs = [w.node_xyz(spawn_nodes[i]) for i in g]
            cen.append(tuple(sum(p[k] for p in xs) / len(xs) for k in range(3)))
        ratios = []
        for f, home in zip(CB_FRONTS, (0, 1)):
            p = tuple(cen[0][k] + f * (cen[1][k] - cen[0][k]) for k in range(3))
            front = w.node_of({"x": p[0], "y": p[1], "z": p[2]})
            th, ta = fields[home][front], fields[1 - home][front]
            if th >= 0 and ta >= 0:
                ratios.append(mario.path_time_s(th) / mario.path_time_s(ta))
        m["cb1_home_ratio"] = round(max(ratios), 3) if ratios else None
    sc = shortcuts(w)
    extra["fun_shortcuts"] = sc
    m["vm1_shortcuts"] = len(sc)
    m["vm1_per_unit"] = round(len(sc) / float(symmetry_units(arena)), 2)
    districts = [d for d in ((arena.get("sites") or {}).get("districts") or []) if isinstance(d, dict)]
    m["vm1_per_district"] = round(len(sc) / float(len(districts)), 2) if districts else None
    verbs = collections.Counter(v for v, _, _, _, _ in sc)
    if len(sc) >= 2:
        verb, n = verbs.most_common(1)[0]
        m["vm3_theme_share"] = round(n / float(len(sc)), 2)
        m["vm3_theme"] = verb
    else:
        m["vm3_theme_share"] = None
        m["vm3_theme"] = None
    goals = [w.node_of(s) for s in (arena.get("stars") or []) if isinstance(s, dict) and "x" in s]
    pairs = []
    start = spawn_nodes[0] if spawn_nodes else None
    for gnode in goals:
        pairs.append((start, gnode))
    survey = arena.get("survey") or {}
    for a, b in (("start", "goal"), ("courseStart", "courseGoal"), ("lineStart", "lineFinish")):
        if isinstance(survey.get(a), dict) and isinstance(survey.get(b), dict):
            pairs.append((w.node_of(survey[a]), w.node_of(survey[b])))
    if not pairs and start is not None:
        pairs.append((start, centre))
    rows = splits(w, pairs)
    extra["fun_splits"] = rows
    m["sl_splits"] = len(rows)
    m["sl_real_choices"] = sum(1 for r in rows if r["real"])
    m["sl_choice_share"] = round(m["sl_real_choices"] / float(len(rows)), 2) if rows else None
    stars = [s for s in arena.get("stars") or [] if isinstance(s, dict) and "x" in s]
    spawns = arena.get("spawns") or []
    if stars and spawns:
        goals_metrics(w, stars, spawns[0], m)
def _approach(w, route):
    tx, tz = _xz(w, route[-1])
    for i in range(len(route) - 1, -1, -1):
        x, z = _xz(w, route[i])
        if math.hypot(x - tx, z - tz) > EXEMPT:
            return i
    return 0
def _tail(w, route, length=FLANK_TAIL, every=2):
    pts = []
    n = int(length // G)
    end = _approach(w, route) + 1
    for i in route[max(0, end - n):end][::every]:
        x, y, z = w.node_xyz(i)
        pts.append((x, y + mario.EYE, z))
    return pts
def _arrival(w, route):
    if len(route) < 2:
        return None
    end = _approach(w, route)
    a = w.node_xyz(route[max(0, end - int(ARRIVAL // G))])
    b = w.node_xyz(route[end])
    dx, dz = b[0] - a[0], b[2] - a[2]
    d = math.hypot(dx, dz)
    return (dx / d, dz / d) if d > 1e-6 else None
def full(w, arena, fam, m, extra, spawn_nodes, groups, centre, sample=None):
    routes_of = extra.get("fun_routes") or {}
    if sample is None:
        sample, _ = vis.sample_points(w, k=300, seed=3)
    m["lf3_flank_unseen"] = None
    m["lf4_flank_angle"] = None
    rs = None
    for (gi, t), r in sorted(routes_of.items(), key=lambda kv: (kv[0][0], kv[0][1] != centre)):
        if t == centre:
            rs = r
            break
    if rs and len(rs) >= 2:
        main = rs[0]
        tgt = w.node_xyz(centre)
        main_tail = _tail(w, main)
        cand = [p for p in sample if math.hypot(p[0] - tgt[0], p[2] - tgt[2]) <= HOLD_RANGE]
        scored = []
        for p in cand:
            seen = sum(1 for q in main_tail if not w.blocked(p, q))
            scored.append((seen, p))
        scored.sort(key=lambda t: -t[0])
        holds = [p for _, p in scored[:HOLD_SPOTS]]
        extra["fun_hold_spots"] = holds
        if holds:
            best_share, best_route = 0.0, None
            for r in rs[1:]:
                tail = _tail(w, r)
                if not tail:
                    continue
                shares = [sum(1 for q in tail if w.blocked(h, q)) / float(len(tail)) for h in holds]
                worst = min(shares)
                if worst > best_share or best_route is None:
                    best_share, best_route = worst, r
            m["lf3_flank_unseen"] = round(best_share, 2)
            a, b = _arrival(w, main), _arrival(w, best_route) if best_route else None
            if a and b:
                dot = max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1]))
                m["lf4_flank_angle"] = round(math.degrees(math.acos(dot)))
            extra["fun_flank"] = best_route
    m["cb2_unseen_exits"] = None
    if len(groups) == 2 and spawn_nodes:
        worst = None
        pens = []
        for g in groups:
            zone = structure.base_zone(w, [spawn_nodes[i] for i in g])
            exits = structure.exits(w, zone, centre, diagonal=True)
            if not exits:
                continue
            reps = []
            for ex in exits:
                pick = ex[:: max(1, len(ex) // 3)][:3]
                reps.append([(lambda p: (p[0], p[1] + mario.EYE, p[2]))(w.node_xyz(i)) for i in pick])
            cx = sum(w.node_xyz(spawn_nodes[i])[0] for i in g) / len(g)
            cz = sum(w.node_xyz(spawn_nodes[i])[2] for i in g) / len(g)
            zone_xz = [_xz(w, i) for i in zone][::3]
            enemy = [p for p in sample
                     if math.hypot(p[0] - cx, p[2] - cz) <= CB2_RANGE
                     and min(math.hypot(p[0] - a, p[2] - b) for a, b in zone_xz) >= CAMP_AWAY]
            base_worst = len(exits)
            at = None
            for e in enemy:
                unseen = sum(1 for rp in reps if all(w.blocked(e, q) for q in rp))
                if unseen < base_worst:
                    base_worst, at = unseen, e
            pens.append((base_worst, at))
            worst = base_worst if worst is None else min(worst, base_worst)
        m["cb2_unseen_exits"] = worst
        extra["fun_pens"] = pens
def where(extra, w):
    if w is None:
        return {}
    out = {}
    def at(i):
        x, y, z = w.node_xyz(i)
        return [round(x), round(y), round(z)]
    centre = extra.get("centre")
    if centre is not None:
        out["lf1_viable_routes"] = [at(centre)]
        out["vm1_per_unit"] = out["vm1_shortcuts"] = [at(centre)]
    holds = extra.get("fun_hold_spots") or []
    if holds:
        out["lf3_flank_unseen"] = [[round(v) for v in h] for h in holds]
    flank = extra.get("fun_flank")
    if flank:
        out["lf4_flank_angle"] = [at(flank[_approach(w, flank)])]
    pens = [p for _, p in extra.get("fun_pens") or [] if p is not None]
    if pens:
        out["cb2_unseen_exits"] = [[round(v) for v in p] for p in pens]
    goals = [r["goal"] for r in extra.get("fun_splits") or [] if not r.get("real")]
    if goals:
        out["sl_real_choices"] = [at(g) for g in goals[:6]]
    return out
