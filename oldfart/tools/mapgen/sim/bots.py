import collections
import math
import random
from ..metrics import graph
from ..metrics import mario
from ..metrics import structure
from ..metrics import vis
from ..metrics.world import world_of
HZ = 4
RANGE = 2400
RESPAWN_TICKS = 8
SPAWN_KILL_S = 3.0
HP = 4
BIN = 800
FOV = 90.0
HEAR = 400
REACT = 3
LOSE = 4
RETREAT_HP = 1
RETREAT = 16
HEAL = 20
EPISODE_GAP = HZ
AMBUSH = 800
PLACE = 1600
class Table(object):
    def __init__(self, world, points=120, goals=16, seed=7):
        self.world = world
        w = world
        sample, owners = vis.sample_points(w, k=points, seed=seed)
        self.sample = sample
        self.owners = owners
        k = len(sample)
        vis_rows = [[False] * k for _ in range(k)]
        dist = [[0.0] * k for _ in range(k)]
        for i in range(k):
            vis_rows[i][i] = True
            for j in range(i + 1, k):
                a, b = sample[i], sample[j]
                d = math.hypot(a[0] - b[0], a[2] - b[2])
                dist[i][j] = dist[j][i] = d
                if d <= RANGE and not w.blocked(a, b):
                    vis_rows[i][j] = vis_rows[j][i] = True
        self.vis = vis_rows
        n = len(w.nodes)
        near = [-1] * n
        q = collections.deque()
        for si, node in enumerate(owners):
            if near[node] < 0:
                near[node] = si
                q.append(node)
        while q:
            u = q.popleft()
            for v in w.adj2[u]:
                if near[v] < 0:
                    near[v] = near[u]
                    q.append(v)
        for u in range(n):
            if near[u] < 0:
                near[u] = 0
        self.near = near
        step = max(1, len(owners) // goals)
        self.goals = owners[::step][:goals]
        self.to_goal = [graph.bfs(w.radj, [g]) for g in self.goals]
def _entropy(counts, base):
    total = float(sum(counts))
    if total <= 0 or base <= 1:
        return 1.0
    h = 0.0
    for c in counts:
        if c > 0:
            p = c / total
            h -= p * math.log(p)
    return h / math.log(base)
def run_once(arena, table, seed, seconds=120, players=16, teams=None, aware=True):
    w = table.world
    rnd = random.Random(seed)
    nodes = w.nodes
    survey_pts = [p for p in (arena.get("survey", {}) or {}).get("points", []) if isinstance(p, dict)]
    spawn_spots = survey_pts if len(survey_pts) >= players else list(arena.get("spawns", []))
    spawn_nodes = [w.node_of(s) for s in spawn_spots]
    team_spawns = None
    if teams:
        team_spawns = [[w.node_of(arena["spawns"][i]) for i in g] for g in teams]
    team = [(i % len(teams)) if teams else i for i in range(players)]
    cos_fov = math.cos(math.radians(FOV / 2.0))
    def xz(u):
        gx, gz, _ = nodes[u]
        return ((gx + .5) * 100, (gz + .5) * 100)
    def pick_spawn(i, alive_pos):
        cand = team_spawns[team[i]] if team_spawns else spawn_nodes
        enemies = [alive_pos[j] for j in range(players) if alive_pos[j] is not None and team[j] != team[i]]
        if not enemies:
            return cand[rnd.randrange(len(cand))]
        scored = []
        for c in cand:
            cx, cz = xz(c)
            d = min(math.hypot(cx - xz(e)[0], cz - xz(e)[1]) for e in enemies)
            scored.append((-d, c))
        scored.sort()
        half = scored[:max(1, len(scored) // 2)]
        return half[rnd.randrange(len(half))][1]
    pos = [None] * players
    for i in range(players):
        pos[i] = spawn_nodes[i % len(spawn_nodes)] if not team_spawns else \
            team_spawns[team[i]][(i // len(teams)) % len(team_spawns[team[i]])]
    def face_to(i, x, z):
        ax, az = xz(pos[i])
        dx, dz = x - ax, z - az
        n = math.hypot(dx, dz)
        if n > 1e-6:
            face[i] = (dx / n, dz / n)
    hp = [HP] * players
    goal = [rnd.randrange(len(table.goals)) for _ in range(players)]
    born = [0] * players
    dead_until = [-1] * players
    carry = [0.0] * players
    kills = [0] * players
    deaths = [0] * players
    spawn_kills = 0
    heat = collections.Counter()
    death_at = collections.Counter()
    fight_at = collections.Counter()
    engage = []
    lives = []
    face = []
    for i in range(players):
        a = rnd.random() * 2 * math.pi
        face.append((math.cos(a), math.sin(a)))
    seen = [dict() for _ in range(players)]
    lost = [LOSE] * players
    target_at = [None] * players
    retreat_until = [-1] * players
    last_hit = [-10 ** 6] * players
    met = [set() for _ in range(players)]
    first_sights = []
    log = [[] for _ in range(players)]
    ticks = seconds * HZ
    per_tick = mario.SPEED / float(HZ) / mario.CELL
    for tick in range(ticks):
        for i in range(players):
            if pos[i] is None and tick >= dead_until[i]:
                pos[i] = pick_spawn(i, pos)
                hp[i] = HP
                born[i] = tick
                goal[i] = rnd.randrange(len(table.goals))
                seen[i] = {}
                lost[i] = LOSE
                retreat_until[i] = -1
                met[i] = set()
        shooting = [False] * players
        sees = [False] * players
        hits = []
        for i in range(players):
            if pos[i] is None:
                continue
            si = table.near[pos[i]]
            ax, az = xz(pos[i])
            best, bd = None, None
            now = {}
            for j in range(players):
                if j == i or pos[j] is None or team[j] == team[i]:
                    continue
                sj = table.near[pos[j]]
                if not table.vis[si][sj]:
                    continue
                bx, bz = xz(pos[j])
                d = math.hypot(ax - bx, az - bz)
                if d > RANGE:
                    continue
                if aware and d > HEAR:
                    if (face[i][0] * (bx - ax) + face[i][1] * (bz - az)) / d < cos_fov:
                        continue
                now[j] = seen[i].get(j, 0) + 1
                if j not in met[i]:
                    met[i].add(j)
                    first_sights.append(d)
                if aware and now[j] < REACT:
                    continue
                if bd is None or d < bd:
                    best, bd = j, d
            seen[i] = now
            sees[i] = bool(now)
            if aware and tick < retreat_until[i]:
                best = None
            if best is not None:
                shooting[i] = True
                lost[i] = 0
                target_at[i] = xz(pos[best])
                if aware:
                    face_to(i, *target_at[i])
                p_hit = max(0.03, 0.2 * (1.0 - bd / 3000.0))
                if rnd.random() < p_hit:
                    hits.append((i, best, bd))
            else:
                lost[i] += 1
        hit_now = set(j for _, j, _ in hits)
        for i in range(players):
            if pos[i] is None:
                log[i].append(-1)
            elif shooting[i] or i in hit_now:
                log[i].append(2)
                fight_at[nodes[pos[i]][:2]] += 1
            else:
                log[i].append(1 if sees[i] else 0)
        for i, j, d in hits:
            if pos[j] is None or pos[i] is None:
                continue
            hp[j] -= 1
            last_hit[j] = tick
            if aware:
                face_to(j, *xz(pos[i]))
            if hp[j] <= 0:
                kills[i] += 1
                deaths[j] += 1
                engage.append(d)
                col = nodes[pos[j]][:2]
                death_at[col] += 1
                life = (tick - born[j]) / float(HZ)
                lives.append(life)
                if life <= SPAWN_KILL_S:
                    spawn_kills += 1
                pos[j] = None
                dead_until[j] = tick + RESPAWN_TICKS
            elif aware and hp[j] <= RETREAT_HP and retreat_until[j] < tick:
                bx, bz = xz(pos[i])
                goal[j] = max(range(len(table.goals)),
                              key=lambda g: math.hypot(xz(table.goals[g])[0] - bx,
                                                       xz(table.goals[g])[1] - bz))
                retreat_until[j] = tick + RETREAT
        if aware:
            for i in range(players):
                since = tick - last_hit[i]
                if pos[i] is not None and hp[i] < HP and since >= HEAL and since % HEAL == 0:
                    hp[i] += 1
        for i in range(players):
            if pos[i] is None:
                continue
            carry[i] += per_tick * (0.5 if shooting[i] else 1.0)
            field = table.to_goal[goal[i]]
            moved = None
            while carry[i] >= 1.0:
                carry[i] -= 1.0
                u = pos[i]
                if field[u] == 0 or field[u] < 0:
                    goal[i] = rnd.randrange(len(table.goals))
                    field = table.to_goal[goal[i]]
                    continue
                opts = [v for v in w.adj[u] if 0 <= field[v] < field[u]]
                if opts:
                    pos[i] = opts[rnd.randrange(len(opts))]
                    moved = u
                else:
                    goal[i] = rnd.randrange(len(table.goals))
                    field = table.to_goal[goal[i]]
            if aware and not shooting[i] and moved is not None:
                if lost[i] < LOSE and target_at[i] is not None and tick >= retreat_until[i]:
                    face_to(i, *target_at[i])
                else:
                    ux, uz = xz(moved)
                    vx, vz = xz(pos[i])
                    n = math.hypot(vx - ux, vz - uz)
                    if n > 1e-6:
                        face[i] = ((vx - ux) / n, (vz - uz) / n)
            heat[nodes[pos[i]][:2]] += 1
    return {"kills": kills, "deaths": deaths, "spawn_kills": spawn_kills,
            "heat": heat, "death_at": death_at, "engage": engage, "lives": lives,
            "seconds": seconds, "log": log, "fight_at": fight_at,
            "first_sights": first_sights}
def _quantile(values, p):
    if not values:
        return None
    v = sorted(values)
    return v[int(p * (len(v) - 1))]
def rhythm(log):
    calm = []
    fight = alive = 0
    in_ep = have_ep = False
    gap = 0
    blind = longest_blind = 0
    first = None
    for t, x in enumerate(log):
        if x < 0:
            in_ep = have_ep = False
            gap = blind = 0
            continue
        alive += 1
        if x >= 1:
            if first is None:
                first = t / float(HZ)
            blind = 0
        else:
            blind += 1
            longest_blind = max(longest_blind, blind)
        if x == 2:
            fight += 1
            if not in_ep:
                if have_ep and gap >= EPISODE_GAP:
                    calm.append(gap / float(HZ))
                in_ep = have_ep = True
            gap = 0
        else:
            gap += 1
            if in_ep and gap >= EPISODE_GAP:
                in_ep = False
    return fight, alive, calm, longest_blind / float(HZ), first
def simulate(arena, runs=2, seconds=120, players=16, seed=1, world=None, table=None, aware=True):
    w = world or world_of(arena)
    table = table or Table(w)
    groups = structure.spawn_groups(arena.get("spawns", []))
    teams = groups if len(groups) == 2 else None
    heat = collections.Counter()
    death_at = collections.Counter()
    ent, spawn_share, kpm, eng, life = [], [], [], [], []
    shares, calms, blinds, firsts, sights = [], [], [], [], []
    fight_at = collections.Counter()
    total_deaths = 0
    for k in range(runs):
        r = run_once(arena, table, seed + k, seconds=seconds, players=players, teams=teams,
                     aware=aware)
        heat.update(r["heat"])
        death_at.update(r["death_at"])
        fight_at.update(r["fight_at"])
        sights += r["first_sights"]
        for log in r["log"]:
            f, al, calm, blind, first = rhythm(log)
            if al:
                shares.append(f / float(al))
            calms += calm
            blinds.append(blind)
            if first is not None:
                firsts.append(first)
        d = sum(r["deaths"])
        total_deaths += d
        if teams:
            tk = [sum(r["kills"][i] for i in range(players) if i % 2 == t) for t in range(2)]
            ent.append(_entropy(tk, 2))
        else:
            ent.append(_entropy(r["kills"], players))
        spawn_share.append(r["spawn_kills"] / float(d) if d else 0.0)
        kpm.append(d / (seconds / 60.0))
        if r["engage"]:
            e = sorted(r["engage"])
            eng.append(e[len(e) // 2])
        if r["lives"]:
            life.append(sum(r["lives"]) / len(r["lives"]))
    bins = collections.Counter()
    floor_bins = set()
    for (gx, gz) in w.columns:
        floor_bins.add((gx * 100 // BIN, gz * 100 // BIN))
    for (gx, gz), c in death_at.items():
        bins[(gx * 100 // BIN, gz * 100 // BIN)] += c
    spread = _entropy(list(bins.values()), max(2, len(floor_bins)))
    hotspot = max(bins.values()) / float(sum(bins.values())) if bins else 0.0
    unused = sum(1 for c in w.columns if heat.get(c, 0) == 0) / float(len(w.columns) or 1)
    def mean(v):
        return round(sum(v) / len(v), 3) if v else None
    fbins = collections.Counter()
    for (gx, gz), c in fight_at.items():
        fbins[(gx * 100 // BIN, gz * 100 // BIN)] += c
    ftotal = float(sum(fbins.values()))
    top = sorted(fbins.values(), reverse=True)
    busiest = max(1, int(round(0.15 * len(floor_bins))))
    rh_hot = round(sum(top[:busiest]) / ftotal, 3) if ftotal else None
    regions = collections.Counter()
    for (gx, gz), c in fight_at.items():
        regions[(gx * 100 // PLACE, gz * 100 // PLACE)] += c
    rh_places = sum(1 for c in regions.values() if c / ftotal >= 0.10) if ftotal else 0
    def q(v, p):
        x = _quantile(v, p)
        return None if x is None else round(x, 2)
    metrics = {
        "kill_entropy": mean(ent),
        "kill_spread": round(spread, 3),
        "kill_hotspot_share": round(hotspot, 3),
        "spawn_kill_share": mean(spawn_share),
        "kills_per_min": mean(kpm),
        "engagement_distance": mean(eng),
        "mean_life_s": mean(life),
        "unused_floor": round(unused, 3),
        "runs": runs,
        "mode": "teams" if teams else "ffa",
        "aware": aware,
        "rh_fight_share": mean(shares),
        "rh_calm_p50_s": q(calms, 0.5),
        "rh_calm_p90_s": q(calms, 0.9),
        "rh_calm_over_20_share": (round(sum(1 for c in calms if c > 20) / float(len(calms)), 3)
                                  if calms else None),
        "rh_unseen_p90_s": q(blinds, 0.9),
        "rh_first_contact_s": q(firsts, 0.5),
        "rh_fight_hotspot": rh_hot,
        "rh_fight_places": rh_places,
        "rh_ambush_share": (round(sum(1 for d in sights if d < AMBUSH) / float(len(sights)), 3)
                            if sights else None),
    }
    return {"metrics": metrics, "heat": heat, "deaths": death_at, "fights": fight_at}
