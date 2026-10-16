import math
from . import v1
from .metrics import mario
PICKUPS = ("coin", "coins", "redcoin", "bluecoin", "1up", "heart", "star", "redcoins",
           "bluecoins", "1ups", "hearts")
REACH_SIDE = 200
DROP_UNDER = 150
REACH_UP = mario.JUMP_DOUBLE + mario.MARIO_TALL
MOVE_REACH = 1500
LIFT = 120
def _m():
    return v1.arenas_module()
def _graph(arena, graph=None):
    m = _m()
    try:
        cells, edges = graph if graph is not None else m.walk_graph(arena)
        first = m.spawn_cell(arena["spawns"][0])
    except Exception:
        return None, None
    if first not in cells:
        return None, None
    live = m.reach(edges, first)
    cols = {}
    for (gx, gz, h) in live:
        cols.setdefault((gx, gz), []).append(h)
    return live, cols
def is_pickup(o):
    k = str(o.get("key") or o.get("what") or "").lower()
    return k in PICKUPS
def _reaches(cols, x, y, z):
    m = _m()
    g = int(math.floor(x / m.GRID)), int(math.floor(z / m.GRID))
    r = int(math.ceil(REACH_SIDE / float(m.GRID)))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            for h in cols.get((g[0] + dx, g[1] + dz), ()):
                if -DROP_UNDER <= y - h <= REACH_UP:
                    return True
    return False
def faults(arena, graph=None):
    objs = [o for o in arena.get("objects") or [] if is_pickup(o)]
    if not objs or not arena.get("spawns"):
        return []
    live, cols = _graph(arena, graph)
    if cols is None:
        return []
    return [(o, "out of reach of every floor walked from spawn 1")
            for o in objs if not _reaches(cols, o["x"], o["y"], o["z"])]
def repair(arena, graph=None):
    bad = faults(arena, graph)
    if not bad:
        return []
    m = _m()
    live, cols = _graph(arena, graph)
    notes, drop = [], []
    for o, _ in bad:
        best = None
        g = int(math.floor(o["x"] / m.GRID)), int(math.floor(o["z"] / m.GRID))
        r = int(MOVE_REACH // m.GRID)
        for dx in range(-r, r + 1, 2):
            for dz in range(-r, r + 1, 2):
                for h in cols.get((g[0] + dx, g[1] + dz), ()):
                    d = math.hypot(dx, dz) * m.GRID + abs(h - o["y"]) * 0.5
                    if best is None or d < best[0]:
                        best = (d, g[0] + dx, g[1] + dz, h)
        if best is None:
            drop.append(o)
            notes.append("%s at %d,%d taken off (no reached floor near)" % (
                o.get("key"), o["x"], o["z"]))
            continue
        _, gx, gz, h = best
        o["x"], o["z"] = int((gx + 0.5) * m.GRID), int((gz + 0.5) * m.GRID)
        o["y"] = int(h + LIFT)
        if LIFT:
            o["air"] = True
        notes.append("%s moved onto a floor Mario reaches" % o.get("key"))
    if drop:
        arena["objects"] = [o for o in arena["objects"] if all(o is not d for d in drop)]
    return notes
def _spearman(xs, ys):
    def ranks(v):
        order = sorted(range(len(v)), key=lambda i: v[i])
        r = [0.0] * len(v)
        i = 0
        while i < len(order):
            j = i
            while j + 1 < len(order) and v[order[j + 1]] == v[order[i]]:
                j += 1
            for k in range(i, j + 1):
                r[order[k]] = (i + j) / 2.0
            i = j + 1
        return r
    if len(xs) < 3:
        return None
    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den = math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))
    return None if den == 0 else num / den
def curve(arena):
    stars = arena.get("stars") or []
    sp = (arena.get("spawns") or [None])[0]
    if sp is None or len(stars) < 3:
        return None, []
    rows = [(math.hypot(s["x"] - sp["x"], s["z"] - sp["z"]), int(s.get("grade") or 1),
             s.get("kind")) for s in stars]
    return _spearman([r[0] for r in rows], [r[1] for r in rows]), rows
def order_by_curve(arena):
    stars = arena.get("stars") or []
    sp = (arena.get("spawns") or [None])[0]
    if sp is None or len(stars) < 2 or any(s.get("asked") or s.get("hint") for s in stars):
        return []
    key = [(int(s.get("grade") or 1), math.hypot(s["x"] - sp["x"], s["z"] - sp["z"]), i)
           for i, s in enumerate(stars)]
    order = [i for _, _, i in sorted(key)]
    if order == list(range(len(stars))):
        return []
    ids = sorted(s.get("id") for s in stars)
    new = [stars[i] for i in order]
    for s, n in zip(new, ids):
        s["id"] = n
    arena["stars"] = new
    return ["stars numbered easiest and nearest first (the difficulty curve)"]
PIT_MOST = 400
PIT_HEAD = 200
def fill_pits(arena, graph, tex):
    import collections
    m = v1.arenas_module()
    cells, edges = graph
    if not arena.get("spawns"):
        return []
    first = m.spawn_cell(arena["spawns"][0])
    if first not in cells:
        return []
    fw = m.reach(edges, first)
    bk = m.reach(edges, first, reverse=True)
    trapped = set(c for c in fw if c not in bk)
    if not trapped:
        return []
    G = m.GRID
    floor = (m.LEVELS.get(arena.get("level")) or {}).get("floor")
    if floor is None:
        floor = (arena.get("terrain") or {}).get("floor", 0)
    cols = collections.defaultdict(list)
    for c in cells:
        cols[(c[0], c[1])].append(c[2])
    out = []
    seen = set()
    for c0 in sorted(trapped):
        if c0 in seen:
            continue
        comp, todo = [], [c0]
        seen.add(c0)
        while todo:
            c = todo.pop()
            comp.append(c)
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + di, c[1] + dj, c[2])
                if n in trapped and n not in seen:
                    seen.add(n)
                    todo.append(n)
        base = comp[0][2]
        if len(comp) > PIT_MOST or any(c[2] != base for c in comp):
            continue
        rim = []
        cset = set((c[0], c[1]) for c in comp)
        for c in comp:
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (c[0] + di, c[1] + dj)
                if k in cset:
                    continue
                rim += [h for h in cols.get(k, []) if (k[0], k[1], h) in bk and h > base]
        if not rim:
            continue
        top = min(rim)
        x0, x1 = min(i for i, _ in cset) * G, (max(i for i, _ in cset) + 1) * G
        z0, z1 = min(j for _, j in cset) * G, (max(j for _, j in cset) + 1) * G
        crowded = False
        for p in arena["pieces"]:
            if p.get("kind") == "water" or p["y"] >= top + PIT_HEAD or p["y"] + p["h"] <= base + 10:
                continue
            try:
                f0, f1, g0, g1, _ = m.footprint(p)
            except Exception:
                continue
            if f1 <= x0 or f0 >= x1 or g1 <= z0 or g0 >= z1:
                continue
            if any(f0 < (i + 1) * G and i * G < f1 and g0 < (j + 1) * G and j * G < g1
                   for (i, j) in cset):
                crowded = True
                break
        if crowded:
            continue
        rows = collections.defaultdict(list)
        for (i, j) in sorted(cset):
            rows[j].append(i)
        runs = []
        for j in sorted(rows):
            xs = sorted(rows[j])
            a = xs[0]
            for k_, x in enumerate(xs):
                if k_ + 1 == len(xs) or xs[k_ + 1] != x + 1:
                    runs.append((a, x + 1, j))
                    if k_ + 1 < len(xs):
                        a = xs[k_ + 1]
        merged = {}
        for (a, b, j) in runs:
            if (a, b, j - 1) in merged:
                merged[(a, b, j)] = merged.pop((a, b, j - 1))
            else:
                merged[(a, b, j)] = j
        from . import kit
        box = kit.kind("box").make
        for (a, b, j), j0 in merged.items():
            out.append(box(tex, a * G, b * G, base, top, j0 * G, (j + 1) * G, None, "terrace"))
    return out
