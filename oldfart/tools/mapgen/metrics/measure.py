import collections
import math
import statistics
import time
from . import beauty
from . import fun
from . import graph
from . import mario
from . import structure
from . import targets
from . import v1
from . import vis
from .world import world_of
SPAWN_KEYS_COURSE = (("start", "goal"), ("courseStart", "courseGoal"),
                     ("lineStart", "lineFinish"), ("floodStart", "floodGoal"))
def r1(v):
    return None if v is None else round(v, 1)
def r2(v):
    return None if v is None else round(v, 2)
def r3(v):
    return None if v is None else round(v, 3)
def family_for(arena, family=None):
    if family:
        return targets.family_of(family)
    if arena.get("family"):
        return targets.family_of(arena["family"])
    return v1.VENUE_FAMILY.get(arena.get("key"), "shooter")
def cover_within(world, cols=None, reach=3):
    if world._los_index is None:
        world._build_los()
    idx = world._los_index[0]
    dil = getattr(world, "_cover_dilated", None)
    if dil is None:
        tops = {}
        for k, plist in idx.items():
            t = max([p.y + p.h for p in plist if not p.sloped] or [None], key=lambda v: -1e18 if v is None else v)
            if t is not None:
                tops[k] = t
        rows = collections.defaultdict(lambda: -1e18)
        for (gx, gz), t in tops.items():
            for dx in range(-reach, reach + 1):
                k = (gx + dx, gz)
                if t > rows[k]:
                    rows[k] = t
        dil = collections.defaultdict(lambda: -1e18)
        for (gx, gz), t in rows.items():
            for dz in range(-reach, reach + 1):
                k = (gx, gz + dz)
                if t > dil[k]:
                    dil[k] = t
        world._cover_dilated = dil
    near = 0
    items = list(world.columns.items()) if cols is None else cols
    for (gx, gz), i in items:
        h = world.nodes[i][2]
        if dil.get((gx, gz), -1e18) - h < mario.COVER_TALL:
            continue
        ok = False
        for dx in range(-reach, reach + 1):
            for dz in range(-reach, reach + 1):
                for p in idx.get((gx + dx, gz + dz), ()):
                    if not p.sloped and p.y + p.h - h >= mario.COVER_TALL and p.y <= h + 10:
                        ok = True
                        break
                if ok:
                    break
            if ok:
                break
        near += ok
    return near / float(len(items)) if items else 0.0
def piece_at(world, x, z):
    if world._los_index is None:
        world._build_los()
    return world._los_index[0].get((int(math.floor(x / mario.CELL)), int(math.floor(z / mario.CELL))), ())
def spawn_cover(world, spot):
    y = spot.get("y", 0)
    yaw = math.radians(spot.get("yaw", 0))
    fx, fz = math.sin(yaw), math.cos(yaw)
    front = False
    for r in range(250, 501, 50):
        for a in range(-30, 31, 10):
            t = math.radians(a)
            dx = fx * math.cos(t) - fz * math.sin(t)
            dz = fx * math.sin(t) + fz * math.cos(t)
            x, z = spot["x"] + dx * r, spot["z"] + dz * r
            for p in piece_at(world, x, z):
                if p.contains_inclusive(x, z) and p.top(x, z) >= y + 399 and p.y <= y + 160:
                    front = True
                    break
            if front:
                break
        if front:
            break
    back = True
    for r in range(100, 501, 50):
        for a in range(-45, 46, 15):
            t = math.radians(a)
            dx = -(fx * math.cos(t) - fz * math.sin(t))
            dz = -(fx * math.sin(t) + fz * math.cos(t))
            x, z = spot["x"] + dx * r, spot["z"] + dz * r
            for p in piece_at(world, x, z):
                if p.contains(x, z) and p.top(x, z) > y + 300 and p.y < y + 160:
                    back = False
                    break
            if not back:
                break
        if not back:
            break
    return front, back
def cv(values):
    vals = [v for v in values if v is not None]
    if len(vals) < 2:
        return 0.0
    m = sum(vals) / float(len(vals))
    if m == 0:
        return 0.0
    return statistics.pstdev(vals) / m
class Measured(object):
    def __init__(self, world):
        self.world = world
LANDMARK_CHEAP = ("shooter", "objective")
def measure(arena, family=None, tier="cheap", players=None, sim=False, sim_runs=2,
            hiding=None, size=None, course_s=None):
    fam = family_for(arena, family)
    T = collections.OrderedDict()
    t0 = time.perf_counter()
    w = world_of(arena)
    T["walk_graph"] = time.perf_counter() - t0
    t = time.perf_counter()
    m = collections.OrderedDict()
    notes = []
    extra = {}
    nodes = w.nodes
    n = len(nodes)
    spawns = arena.get("spawns", [])
    survey = arena.get("survey", {}) or {}
    players = players or arena.get("players") or 16
    m["cells"] = n
    m["columns"] = len(w.columns)
    m["unreached_cells"] = w.unreached
    m["pieces"] = len(arena["pieces"])
    objects = len(arena["pieces"]) + len(arena.get("markers", []))
    budget = arena.get("budget") or 150
    m["objects"] = objects
    m["pieces_share"] = r3(objects / float(budget))
    m["area_per_player"] = round(len(w.columns) * mario.CELL * mario.CELL / float(players))
    m["distinct_sizes"] = len(set((p["kind"], p.get("tex"), round(p["w"]), round(p["h"]), round(p["d"]))
                                  for p in arena["pieces"]))
    x0, x1, z0, z1 = w.bounds()
    m["footprint"] = [round(x1 - x0), round(z1 - z0)]
    hist = collections.Counter(round(h / 100.0) * 100 for (_, _, h) in nodes)
    m["height_histogram"] = sorted(h for h, c in hist.items() if c >= 0.03 * n)
    room_of, room_list = structure.rooms(w)
    big = [rid for rid, r in enumerate(room_list) if structure.has_block(w, r)]
    flat_hist = collections.Counter()
    for rid in big:
        for i in room_list[rid]:
            flat_hist[round(nodes[i][2] / 100.0) * 100] += 1
    plateaus = sorted(h for h, c in flat_hist.items() if c >= 0.03 * n)
    m["plateaus"] = plateaus
    m["layers"] = len(plateaus)
    main = flat_hist.most_common(1)[0][0] if flat_hist else 0
    m["main_plane"] = main
    tops = [nodes[i][2] for i in w.columns.values()]
    m["high_ground_share"] = r3(sum(1 for h in tops if h >= main + 300) / float(len(tops))) if tops else 0.0
    m["floor_height_range"] = (max(plateaus) - min(plateaus)) if plateaus else 0
    T["height"] = time.perf_counter() - t
    t = time.perf_counter()
    centre = w.centre_node()
    extra["centre"] = centre
    spawn_nodes = [w.node_of(s) for s in spawns]
    to_centre = graph.bfs(w.radj, [centre])
    tc = [mario.path_time_s(to_centre[s]) for s in spawn_nodes if to_centre[s] >= 0]
    m["spawn_to_centre_s"] = [r1(min(tc)), r1(max(tc))] if tc else None
    if spawn_nodes:
        d0 = graph.bfs(w.adj, [spawn_nodes[0]])
        others = [mario.path_time_s(d0[s]) for s in spawn_nodes[1:] if d0[s] >= 0]
        m["spawn1_to_others_s"] = [r1(min(others)), r1(max(others))] if others else None
    groups = structure.spawn_groups(spawns)
    extra["groups"] = groups
    m["bases"] = len(groups)
    fields = [graph.bfs(w.adj, [spawn_nodes[i] for i in g]) for g in groups]
    extra["fields"] = fields
    pairs = []
    enemy = []
    meet = None
    if len(groups) >= 2:
        for a in range(len(groups)):
            best_b, best_t = None, None
            for b in range(len(groups)):
                if a == b:
                    continue
                ts = [fields[a][spawn_nodes[j]] for j in groups[b] if fields[a][spawn_nodes[j]] >= 0]
                if ts and (best_t is None or min(ts) < best_t):
                    best_b, best_t = b, min(ts)
            if best_b is not None:
                enemy.append(mario.path_time_s(best_t))
                pair = tuple(sorted((a, best_b)))
                if pair not in pairs:
                    pairs.append(pair)
        for a, b in pairs:
            fa, fb = fields[a], fields[b]
            for i in range(n):
                if fa[i] >= 0 and fb[i] >= 0:
                    v = max(fa[i], fb[i])
                    if meet is None or v < meet:
                        meet = v
        m["spawn_to_enemy_spawn_s"] = r1(min(enemy)) if enemy else None
        m["meet_time_s"] = r1(mario.path_time_s(meet)) if meet is not None else None
    else:
        m["spawn_to_enemy_spawn_s"] = None
        m["meet_time_s"] = None
    extra["pairs"] = pairs
    m["spawn_equity"] = r3(cv(tc))
    T["times"] = time.perf_counter() - t
    t = time.perf_counter()
    zones = [structure.base_zone(w, [spawn_nodes[i] for i in g]) for g in groups]
    base_exits = []
    for z in zones:
        ex = structure.exits(w, z, centre, diagonal=True)
        base_exits.append(len(ex))
    extra["base_exits"] = base_exits
    m["exits_per_base"] = min(base_exits) if base_exits and len(groups) >= 2 else None
    if pairs:
        a, b = pairs[0]
        lanes, chokes, widths = structure.lanes_and_chokes(w, zones[a], zones[b])
        m["lanes_between_bases"] = lanes
        m["chokes"] = chokes
        extra["cut_widths"] = widths
    else:
        m["lanes_between_bases"] = None
        m["chokes"] = None
    special = set(spawn_nodes) | {centre}
    for key, val in survey.items():
        for spot in (val if isinstance(val, list) else [val]):
            if isinstance(spot, dict) and "x" in spot and key != "points":
                special.add(w.node_of(spot))
    for spot in goal_spots(arena):
        special.add(w.node_of(spot))
    dead = []
    room_exits = {}
    alt_target = spawn_nodes[0] if spawn_nodes else 0
    for rid in big:
        comp = room_list[rid]
        cs = set(comp)
        if cs & special and centre in cs:
            continue
        target = centre if centre not in cs else alt_target
        if target in cs:
            continue
        ex = structure.exits(w, cs, target)
        room_exits[rid] = ex
        if cs & special:
            continue
        if len(ex) == 0 or (len(ex) == 1 and len(ex[0]) < 0.5 * structure.perimeter(w, comp)):
            dead.append(rid)
    m["dead_ends"] = len(dead)
    extra["dead_end_rooms"] = [room_list[r][0] for r in dead]
    group, ng, gadj = structure.room_graph(w, room_of, room_list)
    cover, loops = structure.cycle_stats(w, room_list, ng, gadj)
    m["cycle_cover"] = r3(cover)
    m["loops"] = loops
    m["rooms"] = len(big)
    high = [rid for rid in big if nodes[room_list[rid][0]][2] >= main + 300]
    climbs = [len(room_exits[rid]) for rid in high if rid in room_exits]
    m["climb_routes_per_high_point"] = min(climbs) if climbs else None
    m["vantage_points"] = len(high)
    T["structure"] = time.perf_counter() - t
    t = time.perf_counter()
    m["cover_within_300"] = r2(cover_within(w))
    fc = bc = 0
    for s in spawns:
        f, b = spawn_cover(w, s)
        fc += f
        bc += b
    m["spawn_front_cover"] = r2(fc / float(len(spawns))) if spawns else None
    m["spawn_back_clear"] = r2(bc / float(len(spawns))) if spawns else None
    if fam in LANDMARK_CHEAP and spawns:
        share, lm = vis.landmark_visible(w, spawns)
        m["landmark_visible_from_spawns"] = r2(share) if share is not None else None
        if lm is not None:
            extra["landmark"] = lm.i
    T["cover"] = time.perf_counter() - t
    t = time.perf_counter()
    important = list(spawn_nodes) + [centre]
    m.update(structure.jump_reach(w, important))
    T["jump_reach"] = time.perf_counter() - t
    t = time.perf_counter()
    fun.cheap(w, arena, fam, m, extra, spawn_nodes, groups, fields, centre)
    T["fun"] = time.perf_counter() - t
    t = time.perf_counter()
    objective_metrics(w, arena, fam, m, extra, spawn_nodes, groups, fields, centre,
                      room_of, room_list, big, room_exits, notes, course_s=course_s)
    T["objectives"] = time.perf_counter() - t
    if fam == "explore":
        t = time.perf_counter()
        explore_metrics(w, arena, m, extra)
        T["explore"] = time.perf_counter() - t
    t = time.perf_counter()
    total, rules, bnotes = beauty.score(w, groups)
    m["beauty"] = r3(total)
    extra["beauty_rules"] = rules
    notes += ["beauty: " + s for s in bnotes]
    T["beauty"] = time.perf_counter() - t
    T["cheap_total"] = time.perf_counter() - t0
    if tier in ("full", "expensive"):
        expensive(w, arena, fam, m, extra, spawn_nodes, groups, fields, pairs, survey, T,
                  hiding=hiding)
        t = time.perf_counter()
        fun.full(w, arena, fam, m, extra, spawn_nodes, groups, centre)
        T["fun_full"] = time.perf_counter() - t
    if sim:
        t = time.perf_counter()
        from ..sim import bots
        res = bots.simulate(arena, runs=sim_runs, world=w)
        for k, v in res["metrics"].items():
            m["sim_" + k] = v
        extra["sim"] = res
        if fam == "hide":
            from ..sim import seek
            sw = seek.sweep(arena, world=w)
            for k, v in sw["metrics"].items():
                m["sim_" + k] = v
            extra["seek"] = sw
        T["sim"] = time.perf_counter() - t
    T["total"] = time.perf_counter() - t0
    return {"key": arena.get("key", "?"), "family": fam, "size": size,
            "tier": tier + ("+sim" if sim else ""),
            "metrics": m, "timings": {k: round(v, 4) for k, v in T.items()},
            "notes": notes, "extra": extra, "world": w}
def goal_spots(arena):
    out = [s for s in arena.get("stars") or [] if isinstance(s, dict) and "x" in s]
    for o in arena.get("objects") or []:
        if isinstance(o, dict) and o.get("pattern") and o.get("key") == "1up" and "x" in o:
            out.append(o)
    return out
LANDMARK_EYE = 160
HEIGHT_BAND = 400
HEIGHT_BAND_MIN = 36
LANDMARK_LOOKS = 5
def _sees_landmark(w, sites, spot, decks):
    node = w.node_of({"x": spot["x"], "y": sites.get("lift", 0), "z": spot["z"]})
    eye = (spot["x"], w.node_xyz(node)[1] + LANDMARK_EYE, spot["z"])
    for dk in decks:
        top = dk.get("top", dk.get("y", 0) + 1600)
        if math.hypot(dk["x"] - spot["x"], dk["z"] - spot["z"]) < 600:
            return True
        a = dk.get("a", 400) + 1
        hi = top - (top - dk.get("y", 0)) // 3
        dx, dz = spot["x"] - dk["x"], spot["z"] - dk["z"]
        d = math.hypot(dx, dz) or 1.0
        for t in ((dk["x"], top + 1, dk["z"]),
                  (dk["x"] + dx / d * a, hi, dk["z"] + dz / d * a)):
            if not w.blocked(eye, t):
                return True
    return False
def explore_metrics(w, arena, m, extra):
    sites = arena.get("sites") or {}
    districts = [d for d in sites.get("districts") or [] if isinstance(d, dict)]
    if districts:
        m["districts"] = len(districts)
        m["district_kinds"] = len(set(d.get("kind") for d in districts if d.get("kind")))
    decks = [d for d in sites.get("decks") or [] if isinstance(d, dict)]
    m["landmarks"] = len(decks) + len(sites.get("volcanoes") or [])
    decks = decks + [d for d in sites.get("peaks") or [] if isinstance(d, dict)]
    if districts and decks:
        spots = {}
        for o in sites.get("open") or []:
            if isinstance(o, dict) and o.get("district") is not None:
                spots.setdefault(o["district"], []).append(o)
        seen = 0
        for d in districts:
            mine = sorted(spots.get(d.get("i"), []), key=lambda o: -o.get("clear", 0))
            eyes = [d] + mine[:LANDMARK_LOOKS - 1]
            if any(_sees_landmark(w, sites, e, decks) for e in eyes):
                seen += 1
        m["landmark_seen"] = r2(seen / float(len(districts)))
    total = m.get("cells", 0) + (m.get("unreached_cells") or 0)
    m["reached_share"] = r3(m.get("cells", 0) / float(total)) if total else None
    tops = [w.nodes[i][2] for i in w.columns.values()]
    if tops:
        bands = collections.Counter(int(h // HEIGHT_BAND) for h in tops)
        m["height_bands"] = sum(1 for c in bands.values() if c >= HEIGHT_BAND_MIN)
    stars = [s for s in arena.get("stars") or [] if isinstance(s, dict) and "x" in s]
    if stars:
        half = float(sites.get("half") or max(1.0, max(abs(v) for v in w.bounds())))
        m["stars"] = len(stars)
        ds = set(s.get("district") for s in stars if s.get("district") is not None)
        m["star_districts"] = r2(len(ds) / float(min(len(stars), max(1, len(districts)))))
        if len(stars) >= 2:
            dmin = min(math.hypot(a["x"] - b["x"], a["z"] - b["z"])
                       for i, a in enumerate(stars) for b in stars[i + 1:])
            m["star_spread"] = r2(dmin / half)
        m["star_kinds"] = len(set(s.get("kind") for s in stars))
        grades = [s.get("grade") or 0 for s in stars]
        easy = sum(1 for g in grades if g == 1)
        hard = sum(1 for g in grades if g >= 3)
        mix = 0.5 * min(easy, 1) + 0.25 * min(hard, 2) - (0.25 if hard > 3 else 0.0)
        m["star_challenge_mix"] = r2(max(0.0, mix))
        extra["star_grades"] = grades
def expensive(w, arena, fam, m, extra, spawn_nodes, groups, fields, pairs, survey, T,
              hiding=None):
    t = time.perf_counter()
    sample, owners = vis.sample_points(w)
    sl = vis.sightlines(w, sample)
    extra["sample"] = sample
    extra["sightline_max_at"] = sl["sightline_max_at"]
    m["sightline_max"] = sl["sightline_max"]
    m["sightline_p95"] = sl["sightline_p95"]
    m["open_pairs_over_2400"] = r3(sl["open_pairs_over_2400"])
    m["openness"] = r3(sl["openness"])
    T["sightlines"] = time.perf_counter() - t
    t = time.perf_counter()
    spawns = arena.get("spawns", [])
    ex = [vis.exposure(w, s, sample) for s in spawns[:16]]
    extra["spawn_exposure"] = ex
    if ex:
        m["spawn_exposure"] = [r2(min(ex)), r2(sum(ex) / len(ex)), r2(max(ex))]
        m["spawn_exposure_mean"] = r2(sum(ex) / len(ex))
        m["spawn_exposure_max"] = r2(max(ex))
    keys = set((s["x"], s["z"]) for s in spawns)
    pts = [p for p in survey.get("points", []) if isinstance(p, dict)]
    field = [p for p in pts if (p["x"], p["z"]) not in keys]
    fex = [vis.exposure(w, p, sample) for p in field]
    extra["field_exposure"] = fex
    m["field_spawn_exposure_max"] = r2(max(fex)) if (fex and fam == "shooter") else None
    risky, risk_pairs = vis.spawn_kill_risk(w, spawns, groups, pts)
    m["spawn_kill_risk"] = len(risky)
    extra["spawn_kill_pairs"] = risk_pairs
    T["exposure"] = time.perf_counter() - t
    t = time.perf_counter()
    if pairs:
        m["time_to_contact_s"] = r1(vis.contact_time(w, sample, owners, fields, pairs,
                                                    sl["_visible_pairs"]))
    else:
        m["time_to_contact_s"] = None
    share, lm = vis.landmark_visible(w, spawns)
    m["landmark_visible_from_spawns"] = r2(share)
    if lm is not None:
        extra["landmark"] = lm.i
    if ex:
        m["spawn_equity"] = r3(max(m.get("spawn_equity") or 0.0, cv(ex)))
    if hiding or (hiding is None and fam == "hide"):
        hs, hn = vis.hiding_share(w, sample)
        m["hiding_share"] = r3(hs)
        m["hiding_cells_sampled"] = hn
    T["contact_landmark"] = time.perf_counter() - t
def objective_metrics(w, arena, fam, m, extra, spawn_nodes, groups, fields, centre,
                      room_of, room_list, big, room_exits, notes, course_s=None):
    survey = arena.get("survey", {}) or {}
    nodes = w.nodes
    red, blue = survey.get("ctfRed"), survey.get("ctfBlue")
    if isinstance(red, dict) and isinstance(blue, dict):
        a, b = w.node_of(red), w.node_of(blue)
        d1 = graph.bfs(w.adj, [a])[b]
        d2 = graph.bfs(w.adj, [b])[a]
        if d1 >= 0 and d2 >= 0:
            m["flag_to_flag_s"] = r1(mario.path_time_s(max(d1, d2)))
        own, foe = [], []
        for flag in (a, b):
            ts = [(f[flag], g) for g, f in enumerate(fields) if f[flag] >= 0]
            ts.sort()
            if len(ts) >= 2:
                own.append(mario.path_time_s(ts[0][0]))
                foe.append(mario.path_time_s(ts[1][0]))
        if own:
            m["own_spawn_to_own_flag_s"] = r1(max(own))
            m["enemy_spawn_to_flag_s"] = r1(min(foe))
    pts = []
    if fam == "objective":
        pts = [p for p in survey.get("points", []) if isinstance(p, dict)]
    hill = survey.get("hill")
    obj_nodes = [w.node_of(p) for p in pts]
    if isinstance(hill, dict):
        hn = w.node_of(hill)
        if hn not in obj_nodes:
            obj_nodes.append(hn)
        rid = room_of[hn]
        if rid >= 0:
            target = spawn_nodes[0] if spawn_nodes else centre
            ex = structure.exits(w, set(room_list[rid]), target)
            m["hill_approaches"] = len(ex)
    if obj_nodes and len(fields) >= 2:
        gaps = []
        for o in obj_nodes:
            ts = sorted(f[o] for f in fields if f[o] >= 0)
            if len(ts) >= 2:
                ta, tb = mario.path_time_s(ts[0]), mario.path_time_s(ts[1])
                gaps.append(abs(ta - tb) / ((ta + tb) / 2.0))
        m["side_time_gap"] = r3(max(gaps)) if gaps else None
        near = []
        for f in fields:
            ts = [f[o] for o in obj_nodes if f[o] >= 0]
            if ts:
                near.append(mario.path_time_s(min(ts)))
        m["base_to_nearest_point_s"] = r1(max(near)) if near else None
        tc = [mario.path_time_s(f[centre]) for f in fields if f[centre] >= 0]
        m["base_to_centre_s"] = r1(max(tc)) if tc else None
    if len(obj_nodes) >= 2:
        pp = []
        for i, o in enumerate(obj_nodes):
            d = graph.bfs(w.adj, [o])
            for o2 in obj_nodes[i + 1:]:
                if d[o2] >= 0:
                    pp.append(mario.path_time_s(d[o2]))
        if pp:
            m["point_to_point_s"] = [r1(min(pp)), r1(max(pp))]
    if fam in ("knockoff", "party"):
        rid = room_of[centre]
        if rid >= 0:
            ring = room_list[rid]
            cx, _, cz = w.node_xyz(centre)
            cols = set((nodes[i][0], nodes[i][1]) for i in ring)
            edge = [math.hypot((x + .5) * 100 - cx, (z + .5) * 100 - cz) for (x, z) in cols
                    if any((x + dx, z + dz) not in cols for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
            edge.sort()
            m["ring_radius"] = round(edge[len(edge) // 2]) if edge else None
            ring_cols = [((nodes[i][0], nodes[i][1]), i) for i in ring
                         if w.columns.get((nodes[i][0], nodes[i][1])) == i]
            m["ring_cover"] = r2(cover_within(w, ring_cols))
            ways = []
            for r2id in big:
                if r2id == rid:
                    continue
                if nodes[room_list[r2id][0]][2] >= nodes[centre][2]:
                    continue
                ex = room_exits.get(r2id)
                if ex is None:
                    ex = structure.exits(w, set(room_list[r2id]), centre)
                ways.append(len(ex))
            m["ways_up_per_tier"] = min(ways) if ways else None
        m["tiers"] = m["layers"]
    if fam == "party" and arena.get("spawns"):
        sp = arena["spawns"]
        dmin = min(math.hypot(a["x"] - b["x"], a["z"] - b["z"])
                   for i, a in enumerate(sp) for b in sp[i + 1:]) if len(sp) > 1 else None
        m["spawn_spacing_min"] = round(dmin) if dmin is not None else None
    if arena.get("markers"):
        race_metrics(w, arena, m, extra, notes)
    for ks, kg in SPAWN_KEYS_COURSE:
        if isinstance(survey.get(ks), dict) and isinstance(survey.get(kg), dict):
            course_metrics(w, survey[ks], survey[kg], room_of, room_list, m,
                           known=course_s if course_s is not None else validator_clean_s(arena))
            if m.get("course_s_from") == "validator":
                notes.append("course time from the course validator's good run (the jump "
                             "path does not take this course's moves)")
            break
def race_metrics(w, arena, m, extra, notes):
    ma = v1.tool()
    gates = sorted([g for g in arena["markers"] if g["kind"] == ma.KIND["GATE"]],
                   key=lambda g: g["num"])
    if not gates:
        return
    faults = ma.check_markers(arena)
    m["markers_ok"] = 0 if faults else 1
    if faults:
        notes.append("markers: " + "; ".join(faults[:3]))
    m["gates_per_lap"] = len(gates)
    gn = [w.node_of(g) for g in gates]
    total = 0
    missing = 0
    for k in range(len(gn)):
        a, b = gn[k], gn[(k + 1) % len(gn)]
        d = graph.bfs(w.adj, [a])[b]
        if d < 0:
            missing += 1
            d = int(math.hypot(gates[k]["x"] - gates[(k + 1) % len(gn)]["x"],
                               gates[k]["z"] - gates[(k + 1) % len(gn)]["z"]) / 100)
        total += d
    lap = total * mario.CELL
    m["lap_length"] = lap
    m["lap_s"] = r1(lap / float(mario.SHELL_SPEED))
    m["lap_on_foot_s"] = r1(lap / float(mario.SPEED))
    if missing:
        notes.append("%d gate legs are not walkable (a jump or the shell's speed is needed)" % missing)
    legs = []
    for k in range(len(gates)):
        a, b = gates[k], gates[(k + 1) % len(gates)]
        legs.append((b["x"] - a["x"], b["z"] - a["z"]))
    best = run = 0.0
    prev = None
    corners = 0
    for v in legs + legs[:1]:
        L = math.hypot(*v)
        if prev is not None and L > 0 and math.hypot(*prev) > 0:
            cosang = (v[0] * prev[0] + v[1] * prev[1]) / (L * math.hypot(*prev))
            if cosang > math.cos(math.radians(15)):
                run += L
            else:
                if run >= 6000 and cosang < math.cos(math.radians(60)):
                    corners += 1
                run = L
        else:
            run = L
        best = max(best, run)
        prev = v
    m["longest_straight"] = round(best)
    m["hard_corners"] = corners
    ys = [g["y"] for g in gates]
    m["elevation_range"] = max(ys) - min(ys)
    widths = []
    for k, g in enumerate(gates):
        a, b = gates[k - 1], gates[(k + 1) % len(gates)]
        vx, vz = b["x"] - a["x"], b["z"] - a["z"]
        L = math.hypot(vx, vz)
        if L == 0:
            continue
        px, pz = -vz / L, vx / L
        span = 0
        for sign in (1, -1):
            r = 0
            while r < 6000:
                x, z = g["x"] + sign * px * (r + 50), g["z"] + sign * pz * (r + 50)
                if not any(p.contains_inclusive(x, z) and abs(p.top(x, z) - g["y"]) <= 120
                           for p in piece_at(w, x, z)):
                    break
                r += 50
            span += r
        widths.append(span)
    m["road_width_min"] = round(min(widths)) if widths else None
def _walked_to(w, spot):
    gx, gz, h = w.spawn_cell(spot)
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            for hh in w._col_heights(gx + dx, gz + dz):
                if abs(hh - h) <= 50:
                    return True
    return False
def validator_clean_s(arena):
    gen = arena.get("generator") if isinstance(arena, dict) else None
    rep = ((gen or {}).get("params") or {}).get("course") if isinstance(gen, dict) else None
    v = rep.get("clean_s") if isinstance(rep, dict) else None
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None
def course_metrics(w, start, goal, room_of, room_list, m, known=None):
    a, b = w.node_of(start), w.node_of(goal)
    parent = {a: None}
    q = collections.deque([a])
    if not _walked_to(w, goal):
        q.clear()
    while q:
        u = q.popleft()
        if u == b:
            break
        for v in w.adj[u]:
            if v not in parent:
                parent[v] = u
                q.append(v)
    if b not in parent:
        jp = course_jump_path(w, start, goal)
        if jp is None:
            m["course_s"] = r1(known) if known is not None else None
            if known is not None:
                m["course_s_from"] = "validator"
            return
        cells_long, path, jumps, rests = jp
        m["course_s"] = r1(mario.path_time_s(cells_long))
        m["course_jumps"] = jumps
        m["rests"] = len(rests)
        if len(rests) >= 2:
            gaps = [mario.path_time_s(rests[i + 1] - rests[i]) for i in range(len(rests) - 1)]
            m["rest_interval_s"] = [r1(min(gaps)), r1(max(gaps))]
        else:
            m["rest_interval_s"] = None
        return
    path = []
    u = b
    while u is not None:
        path.append(u)
        u = parent[u]
    path.reverse()
    m["course_s"] = r1(mario.path_time_s(len(path) - 1))
    rest_rooms = set(rid for rid, r in enumerate(room_list) if structure.has_block(w, r, 12))
    entries = []
    inside = False
    for k, u in enumerate(path):
        now = room_of[u] in rest_rooms
        if now and not inside:
            entries.append(k)
        inside = now
    if len(entries) >= 2:
        gaps = [mario.path_time_s(entries[i + 1] - entries[i]) for i in range(len(entries) - 1)]
        m["rest_interval_s"] = [r1(min(gaps)), r1(max(gaps))]
    else:
        m["rest_interval_s"] = None
    m["rests"] = len(entries)
def course_jump_path(w, start, goal):
    import heapq
    cells = w.all_cells
    edges = w.all_edges
    cols = collections.defaultdict(list)
    for c in cells:
        cols[(c[0], c[1])].append(c[2])
    def near(spot):
        c = w.spawn_cell(spot)
        best, bd = None, None
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                for h in cols.get((c[0] + dx, c[1] + dz), ()):
                    d = (abs(dx) + abs(dz)) * 100 + abs(h - c[2])
                    if bd is None or d < bd:
                        best, bd = (c[0] + dx, c[1] + dz, h), d
        return best
    a, b = near(start), near(goal)
    if a is None or b is None:
        return None
    reach = mario.JUMP_TRIPLE
    def solid_at(gx, gz, h):
        x, z = gx * mario.CELL + mario.CELL / 2.0, gz * mario.CELL + mario.CELL / 2.0
        for p in w.buckets.get((gx, gz), ()):
            if p.contains(x, z) and p.y < h + mario.MARIO_TALL and p.top(x, z) > h + 1:
                return True
        return False
    def nbrs(c):
        gx, gz, h = c
        for v in edges.get(c, ()):
            yield v, 1, False
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            here = cols.get((gx + dx, gz + dz), ())
            for h2 in here:
                if mario.JUMP_SAFE < h2 - h <= reach:
                    yield (gx + dx, gz + dz, h2), 1, True
            for k in range(1, mario.GAP_LONG // mario.CELL + 2):
                col = cols.get((gx + dx * k, gz + dz * k), ())
                near = [h2 for h2 in col if h - reach <= h2 <= h + reach]
                if not near:
                    if solid_at(gx + dx * k, gz + dz * k, h):
                        break
                    continue
                if k > 1:
                    gap = (k - 1) * mario.CELL
                    up = mario.JUMP_SAFE if gap <= mario.GAP_SAFE else 0
                    land = [h2 for h2 in near if h2 - h <= up]
                    if land:
                        yield (gx + dx * k, gz + dz * k, max(land)), k, True
                break
    dist = {a: 0}
    prev = {a: None}
    heap = [(0, a)]
    while heap:
        d, u = heapq.heappop(heap)
        if u == b:
            break
        if d > dist[u]:
            continue
        for v, cost, jump in nbrs(u):
            nd = d + cost
            if v not in dist or nd < dist[v]:
                dist[v] = nd
                prev[v] = (u, jump)
                heapq.heappush(heap, (nd, v))
    if b not in dist:
        return None
    path, jumps = [], 0
    u = b
    while u is not None:
        path.append(u)
        p = prev[u]
        if p and p[1]:
            jumps += 1
        u = p[0] if p else None
    path.reverse()
    region_of = {}
    rest_region = {}
    def region(c):
        if c in region_of:
            return region_of[c]
        comp, todo = {c}, [c]
        while todo and len(comp) < 4000:
            gx, gz, h = todo.pop()
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v = (gx + dx, gz + dz, h)
                if v not in comp and h in cols.get((v[0], v[1]), ()):
                    comp.add(v)
                    todo.append(v)
        rid = len(rest_region)
        for v in comp:
            region_of[v] = rid
        xy = set((v[0], v[1]) for v in comp)
        rest_region[rid] = any(all((x + i, z + j) in xy for i in range(12) for j in range(12))
                               for (x, z) in xy)
        return rid
    rests = []
    dist_at = 0
    inside = False
    for k, c in enumerate(path):
        if k:
            dist_at += abs(c[0] - path[k - 1][0]) + abs(c[1] - path[k - 1][1])
        now = rest_region[region(c)]
        if now and not inside:
            rests.append(dist_at)
        inside = now
    return dist[b], path, jumps, rests
def quality(result):
    return targets.score(result["metrics"], result["family"], result.get("size"))
