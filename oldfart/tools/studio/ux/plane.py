from studio.editor import geometry as geo
STEP = geo.GRID
FINE = geo.YGRID
FLOOR = 400
UNITS_PER_M = 100.0
LO, HI = -20000, 20000
def step(height, direction, fine=False):
    s = FINE if fine else STEP
    h = geo.snap(height, s) + direction * s
    return int(max(LO, min(HI, h)))
def metres(height):
    return height / UNITS_PER_M
def floors(height):
    return height / float(FLOOR)
def label(height):
    m = metres(height)
    f = floors(height)
    mtxt = ("%d m" % round(m)) if abs(m - round(m)) < 0.05 else ("%.1f m" % m)
    if abs(f) < 1e-6:
        where = "on the ground"
    else:
        n = abs(f)
        ftxt = ("%d" % round(n)) if abs(n - round(n)) < 0.05 else ("%.1f" % n)
        where = "%s floor%s %s" % (ftxt, "" if ftxt == "1" else "s", "up" if f > 0 else "down")
    return "Work plane %s - %s" % (mtxt, where)
def top_of(doc, refs):
    tops = []
    for r in refs:
        item = doc.get(r) if r in doc else None
        if item is None:
            continue
        if geo.is_point(item):
            tops.append(item.get("y", 0))
        else:
            tops.append(geo.aabb(item)[3])
    return max(tops) if tops else None
def ground_under(doc, x, z, below, skip=()):
    best = None
    skip = set(skip)
    for r in doc.refs("piece"):
        if r in skip:
            continue
        b = geo.aabb(doc.get(r))
        if b[0] <= x <= b[1] and b[4] <= z <= b[5] and b[3] <= below + 0.5:
            best = b[3] if best is None else max(best, b[3])
    return 0.0 if best is None else best
def drop_line(items, doc):
    pieces = [i for i in items if not geo.is_point(i)]
    if not pieces:
        return None
    b = geo.union(geo.aabb(i) for i in pieces)
    x, z = (b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0
    ground = ground_under(doc, x, z, b[2])
    if b[2] - ground < 1.0:
        return None
    return (x, b[2], z), (x, ground, z)
