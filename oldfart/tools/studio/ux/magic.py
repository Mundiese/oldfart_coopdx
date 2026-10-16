import math
import random
from studio.editor import geometry as geo
from studio.editor.commands import Change
TOUCH = 1.0
def _floor_of(doc):
    level = str(doc.rest.get("level") or "empty")
    return None if level == "empty2" else 0.0
def _support(doc, box, skip):
    best = None
    for r in doc.refs("piece"):
        if r in skip:
            continue
        b = geo.aabb(doc.get(r))
        if b[0] < box[1] and box[0] < b[1] and b[4] < box[5] and box[4] < b[5] and \
                b[3] <= box[2] + TOUCH:
            best = b[3] if best is None else max(best, b[3])
    floor = _floor_of(doc)
    if floor is not None and floor <= box[2] + TOUCH:
        best = floor if best is None else max(best, floor)
    return best
def drop_to_ground(doc, refs, as_group=False):
    refs = [r for r in refs if r in doc]
    skip = set(refs)
    items = {r: doc.view_item(r) for r in refs}
    if not refs:
        return Change("Drop to the ground")
    drops = {}
    if as_group:
        box = geo.union(geo.aabb(i) for i in items.values())
        top = _support(doc, box, skip)
        d = (box[2] - top) if top is not None else 0
        drops = {r: d for r in refs}
    else:
        for r, it in items.items():
            box = geo.aabb(it)
            top = _support(doc, box, skip)
            drops[r] = (box[2] - top) if top is not None else 0
    steps = []
    moved = 0
    for r in refs:
        d = drops[r]
        if d <= 0.5:
            continue
        before = doc.get(r)
        after = dict(before)
        after["y"] = before.get("y", 0) - d
        steps.append(("replace", r, before, after))
        moved += 1
    return Change("Drop %d thing%s to the ground" % (moved, "" if moved == 1 else "s"), steps,
                  select=list(refs))
def _touch(a, b):
    return geo.touching(a, b, gap=TOUCH)
def surface(doc, ref):
    seed = doc.get(ref)
    if seed is None:
        return []
    tex = seed.get("tex")
    top = geo.aabb(seed)[3]
    cand = {r: geo.aabb(doc.get(r)) for r in doc.refs("piece")
            if doc.get(r).get("tex") == tex and abs(geo.aabb(doc.get(r))[3] - top) <= TOUCH}
    out, todo, seen = [], [ref], {ref}
    while todo:
        r = todo.pop()
        out.append(r)
        for o, b in cand.items():
            if o not in seen and _touch(cand[r], b):
                seen.add(o)
                todo.append(o)
    return out
def wall_run(doc, ref):
    seed = doc.get(ref)
    if seed is None:
        return []
    sb = geo.aabb(seed)
    along_x = (sb[1] - sb[0]) >= (sb[5] - sb[4])
    tex = seed.get("tex")
    def inline(b):
        if along_x:
            return abs(b[4] - sb[4]) <= TOUCH and abs(b[5] - sb[5]) <= TOUCH
        return abs(b[0] - sb[0]) <= TOUCH and abs(b[1] - sb[1]) <= TOUCH
    cand = {r: geo.aabb(doc.get(r)) for r in doc.refs("piece")
            if doc.get(r).get("tex") == tex and inline(geo.aabb(doc.get(r)))
            and geo.aabb(doc.get(r))[2] < sb[3] and geo.aabb(doc.get(r))[3] > sb[2]}
    out, todo, seen = [], [ref], {ref}
    while todo:
        r = todo.pop()
        out.append(r)
        for o, b in cand.items():
            if o not in seen and _touch(cand[r], b):
                seen.add(o)
                todo.append(o)
    return out
def floor_rect(a, b, item, cell=geo.GRID):
    x0, x1 = sorted((geo.snap_floor(a[0], cell), geo.snap_floor(b[0], cell)))
    z0, z1 = sorted((geo.snap_floor(a[2], cell), geo.snap_floor(b[2], cell)))
    w0 = max(cell, item.get("w", cell))
    d0 = max(cell, item.get("d", cell))
    x1 += w0
    z1 += d0
    y = a[1]
    if item.get("kind") == "box":
        out = dict(item)
        out.update(x=(x0 + x1) / 2.0, z=(z0 + z1) / 2.0, y=y, w=x1 - x0, d=z1 - z0, yaw=0)
        return [geo.cleaned(out)]
    out = []
    x = x0
    while x + w0 <= x1 + 0.5:
        z = z0
        while z + d0 <= z1 + 0.5:
            p = dict(item)
            p.update(x=x + w0 / 2.0, z=z + d0 / 2.0, y=y)
            out.append(geo.cleaned(p))
            z += d0
        x += w0
    return out
def stamp_vary(items, seed, texs=None):
    from studio.toolbox import build
    rng = random.Random(seed)
    q = rng.randrange(4)
    pts = [i for _, i in items]
    c = geo.centre_of(pts)
    out = []
    for kind, it in items:
        it = dict(it)
        if "w" in it:
            fam = build.family_of(it.get("kind"))
            if fam:
                square = it.get("w") == it.get("d")
                ok = [k for k in fam if square or k not in build.SQUARE_ONLY]
                it["kind"] = rng.choice(ok)
            if texs:
                it["tex"] = rng.choice(list(texs))
        out.append((kind, geo.turned(it, q, c) if q else it))
    return out
def guides(box, boxes, tol=40.0):
    out = []
    keys = {0: (0, 1), 1: (2, 3), 2: (4, 5)}
    for other in boxes:
        for axis, (lo, hi) in keys.items():
            mine = (box[lo], box[hi], (box[lo] + box[hi]) / 2.0)
            theirs = (other[lo], other[hi], (other[lo] + other[hi]) / 2.0)
            for m in mine:
                for t in theirs:
                    d = t - m
                    if abs(d) <= tol:
                        out.append((abs(d), "xyz"[axis], t, d, other))
    out.sort(key=lambda g: g[0])
    seen, best = set(), []
    for _, axis, value, d, other in out:
        if axis in seen:
            continue
        seen.add(axis)
        best.append((axis, value, d, other))
    return best
def move_label(dx, dy, dz):
    from studio.toolbox import build, measure
    across = math.hypot(dx, dz)
    parts = []
    if across:
        cells = across / geo.GRID
        parts.append("%+d cell%s" % (round(cells) if dx + dz >= 0 else -round(cells),
                                     "" if round(cells) == 1 else "s"))
        parts.append("%d" % round(across))
        parts.append("%.1f s run" % measure.times(across)["run"])
    if dy:
        cls = build.reach_class(dy) if dy > 0 else None
        word = build.WORDS.get(cls, "") if cls else "down"
        parts.append("%s %d%s" % ("↑" if dy > 0 else "↓", abs(dy),
                                  (" - " + word) if dy > 0 else ""))
    return " · ".join(parts)
