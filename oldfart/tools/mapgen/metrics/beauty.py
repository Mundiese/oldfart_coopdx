import collections
import math
from . import v1
SIZES = (200, 400, 600, 800, 1200, 1600, 2400)
def luminance(rgb):
    r, g, b = [c / 255.0 for c in rgb]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
def role(p):
    w = p.x1 - p.x0
    d = p.z1 - p.z0
    if p.sloped:
        return "floor"
    if p.kind == "rail":
        return "trim"
    if p.kind == "pillar":
        return "accent"
    if p.h >= 400 and min(w, d) <= max(600, 0.5 * max(w, d)):
        return "wall"
    if p.h <= 250 and min(w, d) <= 200:
        return "trim"
    if p.h <= 300 or min(w, d) >= 2 * p.h:
        return "floor"
    return "mass"
def accent_textures(pieces):
    by_tag = collections.defaultdict(set)
    for p in pieces:
        by_tag[(p.tag, p.kind, round(p.x1 - p.x0), round(p.z1 - p.z0), round(p.h))].add(p.tex)
    out = set()
    for key, texes in by_tag.items():
        if len(texes) >= 2:
            out |= set(sorted(texes)[1:])
    return out
def score(world, groups=None):
    pieces = world.pieces
    colours = v1.texture_colours()
    roles = [role(p) for p in pieces]
    rules = {}
    notes = []
    accents = accent_textures(pieces)
    palette = set(p.tex for p in pieces) - accents
    n = len(palette)
    rules["R1 palette"] = 1.0 if n <= 5 else max(0.0, 1.0 - (n - 5) / 5.0)
    if n > 5:
        notes.append("%d textures besides team accents (a theme keeps to 5)" % n)
    def mean_lum(kind):
        num = den = 0.0
        for p, r in zip(pieces, roles):
            if r != kind or p.tex not in colours:
                continue
            a = (p.x1 - p.x0) * (p.z1 - p.z0) if kind == "floor" else max(p.x1 - p.x0, p.z1 - p.z0) * p.h
            num += luminance(colours[p.tex]) * a
            den += a
        return num / den if den else None
    lf, lw = mean_lum("floor"), mean_lum("wall")
    if lf is None or lw is None:
        rules["R2 contrast"] = None
    else:
        diff = abs(lf - lw)
        rules["R2 contrast"] = min(1.0, diff / 0.18)
        if diff < 0.18:
            notes.append("floor and wall differ by %.2f in brightness (want 0.18)" % diff)
    edge = railed = 0
    colh = collections.defaultdict(list)
    for (x, z, h) in world.nodes:
        colh[(x, z)].append(h)
    trims = [p for p, r in zip(pieces, roles) if r in ("trim", "wall", "mass")]
    trim_cols = set()
    for p in trims:
        for gx in range(int(math.floor(p.x0 / 100)), int(math.ceil(p.x1 / 100))):
            for gz in range(int(math.floor(p.z0 / 100)), int(math.ceil(p.z1 / 100))):
                trim_cols.add((gx, gz))
    for (x, z), i in world.columns.items():
        h = world.nodes[i][2]
        if (x, z) in trim_cols:
            continue
        open_sides = []
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = colh.get((x + dx, z + dz))
            if nb and any(h - h2 < 1100 for h2 in nb):
                continue
            open_sides.append((x + dx, z + dz) in trim_cols)
        if open_sides:
            edge += 1
            railed += all(open_sides)
    rules["R3 edges"] = railed / float(edge) if edge else 1.0
    walls = [p for p, r in zip(pieces, roles) if r == "wall"]
    ok = 0
    for p in walls:
        length = max(p.x1 - p.x0, p.z1 - p.z0)
        if length <= 800:
            ok += 1
            continue
        touching = 0
        for q in pieces:
            if q is p:
                continue
            if q.x0 <= p.x1 + 1 and q.x1 >= p.x0 - 1 and q.z0 <= p.z1 + 1 and q.z1 >= p.z0 - 1 \
                    and q.top_max > p.y + 100:
                touching += 1
        if touching >= length / 1000.0:
            ok += 1
    rules["R4 walls"] = ok / float(len(walls)) if walls else 1.0
    dims = 0
    good = 0
    for p in pieces:
        for v in (p.x1 - p.x0, p.z1 - p.z0):
            dims += 1
            if any(abs(v - s) < 1 for s in SIZES) or (v >= 200 and abs(v / 200.0 - round(v / 200.0)) < 1e-6):
                good += 1
    rules["R5 sizes"] = good / float(dims) if dims else 1.0
    base = min(q.y for q in pieces)
    tops = sorted(((p.top_max - base, p.i, p) for p in pieces if not p.sloped), key=lambda t: (t[0], t[1]))
    r6 = 0.0
    if tops:
        tall, lm = tops[-1][0], tops[-1][2]
        rest = [t for t, _, q in tops if q is not lm]
        typical = sorted(rest)[len(rest) // 2] if rest else 1
        ratio = tall / float(max(typical, 1))
        height_ok = min(1.0, max(ratio / 3.0, tall / 2000.0))
        x0, x1, z0, z1 = world.bounds()
        half = max(x1 - x0, z1 - z0) / 2.0
        cx, cz = (lm.x0 + lm.x1) / 2.0, (lm.z0 + lm.z1) / 2.0
        mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        off = min(math.hypot(cx - mx, cz - mz), abs(cx - mx), abs(cz - mz))
        placed = 1.0 if off <= 0.15 * half else max(0.0, 1.0 - (off - 0.15 * half) / half)
        r6 = 0.5 * height_ok + 0.5 * placed
    rules["R6 landmark"] = r6
    col_top = {}
    for p in pieces:
        for gx in range(int(math.floor(p.x0 / 200)), int(math.ceil(p.x1 / 200))):
            for gz in range(int(math.floor(p.z0 / 200)), int(math.ceil(p.z1 / 200))):
                col_top[(gx, gz)] = max(col_top.get((gx, gz), -1e9), p.top_max)
    if col_top:
        vals = sorted(col_top.values())
        lo, hi = vals[0], vals[-1]
        span = max(hi - lo, 1)
        bands = collections.Counter(min(2, int(3 * (v - lo) / (span + 1e-9))) for v in vals)
        levels = sum(1 for k in range(3) if bands.get(k, 0) > 0.03 * len(vals))
        mid = bands.get(1, 0) / float(len(vals))
        lev_ok = min(1.0, levels / 3.0)
        mid_ok = 1.0 if 0.2 <= mid <= 0.4 else max(0.0, 1.0 - min(abs(mid - 0.2), abs(mid - 0.4)) / 0.2)
        rules["R7 skyline"] = 0.6 * lev_ok + 0.4 * mid_ok
    else:
        rules["R7 skyline"] = None
    if groups and len(groups) >= 2 and world.spawns:
        sets = []
        for g in groups:
            xs = [world.spawns[i]["x"] for i in g]
            zs = [world.spawns[i]["z"] for i in g]
            cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
            near = set(p.tex for p in pieces
                       if p.x0 - 400 <= cx <= p.x1 + 400 and p.z0 - 400 <= cz <= p.z1 + 400)
            sets.append(near)
        distinct = 0
        for i, s in enumerate(sets):
            others = set().union(*[t for j, t in enumerate(sets) if j != i]) if len(sets) > 1 else set()
            if s - others:
                distinct += 1
        rules["R8 team colours"] = distinct / float(len(sets))
    else:
        rules["R8 team colours"] = None
    if world.level["floor"] is not None:
        floating = 0
        for p in pieces:
            if p.y <= world.level["floor"] + 50:
                continue
            gap = p.y - world.level["floor"]
            below = max([q.top_max for q in pieces if q is not p and q.top_max <= p.y + 1
                         and q.x0 < p.x1 and q.x1 > p.x0 and q.z0 < p.z1 and q.z1 > p.z0] or
                        [world.level["floor"]])
            if p.y - below > 800 and gap > 800:
                floating += 1
        rules["R10 grounded"] = 1.0 - floating / float(len(pieces))
    else:
        rules["R10 grounded"] = None
    if world.spawns:
        clear = 0
        for s in world.spawns:
            busy = False
            for p in pieces:
                if p.x0 - 300 < s["x"] < p.x1 + 300 and p.z0 - 300 < s["z"] < p.z1 + 300:
                    sy = s.get("y", 0)
                    if p.y >= sy - 1 and sy + 50 < p.top_max <= sy + 300:
                        busy = True
                        break
            clear += not busy
        rules["R11 breathing room"] = clear / float(len(world.spawns))
    else:
        rules["R11 breathing room"] = None
    budget = world.arena.get("budget") or 150
    objects = len(pieces) + len(world.arena.get("markers", []))
    share = objects / float(budget)
    rules["R12 restraint"] = 1.0 if share <= 0.85 else max(0.0, 1.0 - (share - 0.85) / 0.3)
    weights = {"R1 palette": 1, "R2 contrast": 2, "R3 edges": 1, "R4 walls": 1,
               "R5 sizes": 1, "R6 landmark": 2, "R7 skyline": 1, "R8 team colours": 1,
               "R10 grounded": 1, "R11 breathing room": 1, "R12 restraint": 1}
    num = den = 0.0
    for k, v in rules.items():
        if v is None:
            continue
        num += weights[k] * v
        den += weights[k]
    total = num / den if den else None
    return total, {k: (None if v is None else round(v, 3)) for k, v in rules.items()}, notes
