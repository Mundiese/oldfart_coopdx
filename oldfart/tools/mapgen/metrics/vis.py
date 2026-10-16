import math
import random
from . import mario
EYE = mario.EYE
def sample_points(world, k=500, seed=1):
    pts = []
    owner = []
    for (gx, gz), i in world.columns.items():
        h = world.nodes[i][2]
        pts.append(((gx + .5) * mario.CELL, h + EYE, (gz + .5) * mario.CELL))
        owner.append(i)
    rnd = random.Random(seed)
    order = list(range(len(pts)))
    pick = rnd.sample(order, min(k, len(pts)))
    return [pts[i] for i in pick], [owner[i] for i in pick]
def sightlines(world, sample, depth=40):
    longest, at = 0.0, None
    tot = vis_long = vis_n = 0
    lengths = []
    visible_pairs = []
    for i, a in enumerate(sample):
        for jj, b in enumerate(sample[i + 1:i + depth], start=i + 1):
            d = math.hypot(a[0] - b[0], a[2] - b[2])
            tot += 1
            if not world.blocked(a, b):
                vis_n += 1
                lengths.append(d)
                visible_pairs.append((i, jj, d))
                if d > longest:
                    longest, at = d, (a, b)
                if d > mario.SIGHT_FIGHT:
                    vis_long += 1
    lengths.sort()
    p95 = lengths[int(0.95 * (len(lengths) - 1))] if lengths else 0.0
    return {
        "sightline_max": round(longest),
        "sightline_max_at": at,
        "open_pairs_over_2400": vis_long / float(tot) if tot else 0.0,
        "sightline_p95": round(p95),
        "openness": vis_n / float(tot) if tot else 0.0,
        "_visible_pairs": visible_pairs,
    }
def eye_of(spot):
    return (spot["x"], spot.get("y", 0) + EYE, spot["z"])
def exposure(world, spot, sample, near=300):
    e = eye_of(spot)
    seen = sum(1 for p in sample
               if math.hypot(p[0] - e[0], p[2] - e[2]) > near and not world.blocked(p, e))
    return seen / float(len(sample)) if sample else 0.0
def spawn_kill_risk(world, spawns, groups, survey_points, reach=1500):
    group_of = {}
    for g, members in enumerate(groups):
        for i in members:
            group_of[i] = g
    risky = set()
    pairs = []
    for i, a in enumerate(spawns):
        for j in range(i + 1, len(spawns)):
            b = spawns[j]
            if group_of.get(i) == group_of.get(j):
                continue
            d = math.hypot(a["x"] - b["x"], a["z"] - b["z"])
            if d < reach and not world.blocked(eye_of(a), eye_of(b)):
                risky.add(i)
                risky.add(j)
                pairs.append((i, j, round(d)))
    if len(groups) <= 1:
        spawn_keys = set((s["x"], s["z"]) for s in spawns)
        others = [p for p in survey_points if (p["x"], p["z"]) not in spawn_keys]
        for i, a in enumerate(spawns):
            n = 0
            for p in others:
                d = math.hypot(a["x"] - p["x"], a["z"] - p["z"])
                if 1 < d < reach and not world.blocked(eye_of(a), eye_of(p)):
                    n += 1
            if n >= 3:
                risky.add(i)
    return sorted(risky), pairs
def contact_time(world, sample, owners, fields, pairs_of_groups, visible_pairs, reach=2400):
    best = None
    for (i, j, d) in visible_pairs:
        if d > reach:
            continue
        a, b = owners[i], owners[j]
        for ga, gb in pairs_of_groups:
            ta, tb = fields[ga][a], fields[gb][b]
            if ta >= 0 and tb >= 0:
                t = max(ta, tb)
                if best is None or t < best:
                    best = t
            ta, tb = fields[ga][b], fields[gb][a]
            if ta >= 0 and tb >= 0:
                t = max(ta, tb)
                if best is None or t < best:
                    best = t
    return None if best is None else mario.path_time_s(best)
def landmark(world):
    x0, x1, z0, z1 = world.bounds()
    mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    rx, rz = 0.3 * (x1 - x0) / 2.0, 0.3 * (z1 - z0) / 2.0
    best = central = None
    for p in world.pieces:
        if p.sloped:
            continue
        key = (p.top_max, p.h, -p.i)
        if best is None or key > (best.top_max, best.h, -best.i):
            best = p
        cx, cz = (p.x0 + p.x1) / 2.0, (p.z0 + p.z1) / 2.0
        if abs(cx - mx) <= rx and abs(cz - mz) <= rz:
            if central is None or key > (central.top_max, central.h, -central.i):
                central = p
    return central or best
def landmark_group(world, lm):
    arena = getattr(world, "arena", None) or {}
    pieces = arena.get("pieces") or []
    if not (0 <= lm.i < len(pieces)):
        return [lm]
    head = str(pieces[lm.i].get("tag") or "").split(" ")[0]
    out = [lm]
    if not head:
        return out
    for p in world.pieces:
        if p.i != lm.i and str(pieces[p.i].get("tag") or "").split(" ")[0] == head \
                and abs(pieces[p.i]["x"] - pieces[lm.i]["x"]) <= 1500 \
                and abs(pieces[p.i]["z"] - pieces[lm.i]["z"]) <= 1500:
            out.append(p)
    return out
def landmark_visible(world, spots):
    lm = landmark(world)
    if lm is None or not spots:
        return None, None
    group = landmark_group(world, lm)
    x0 = min(p.x0 for p in group)
    x1 = max(p.x1 for p in group)
    z0 = min(p.z0 for p in group)
    z1 = max(p.z1 for p in group)
    y0 = min(p.y for p in group)
    top = max(p.top_max for p in group)
    hi = top - (top - y0) / 6.0
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    targets = [(cx, top + 60.0, cz), (x0 - 1, hi, cz), (x1 + 1, hi, cz), (cx, hi, z0 - 1),
               (cx, hi, z1 + 1)]
    seen = 0
    for s in spots:
        e = eye_of(s)
        if any(not world.blocked(e, t) for t in targets):
            seen += 1
    return seen / float(len(spots)), lm
def hiding_share(world, sample, watchers=40):
    watch = sample[:watchers]
    hidden = 0
    for p in sample[watchers:]:
        if all(world.blocked(p, w) for w in watch if w is not p):
            hidden += 1
    n = len(sample) - len(watch)
    return hidden / float(n) if n > 0 else 0.0, hidden
