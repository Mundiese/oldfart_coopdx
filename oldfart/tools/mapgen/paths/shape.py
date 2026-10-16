DIRS = ((1, 0), (0, 1), (-1, 0), (0, -1))
def left(d):
    return (d[1], -d[0])
def right(d):
    return (-d[1], d[0])
def cell_right(v, d):
    vx, vz = v
    return {(1, 0): (vx, vz), (-1, 0): (vx - 1, vz - 1),
            (0, 1): (vx - 1, vz), (0, -1): (vx, vz - 1)}[d]
def cell_left(v, d):
    vx, vz = v
    return {(1, 0): (vx, vz - 1), (-1, 0): (vx - 1, vz),
            (0, 1): (vx, vz), (0, -1): (vx - 1, vz - 1)}[d]
def neighbours(c):
    i, j = c
    return [(i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)]
def connected(cells):
    cells = set(cells)
    if not cells:
        return False
    start = next(iter(cells))
    seen, todo = {start}, [start]
    while todo:
        c = todo.pop()
        for n in neighbours(c):
            if n in cells and n not in seen:
                seen.add(n)
                todo.append(n)
    return len(seen) == len(cells)
def bbox(cells):
    xs = [c[0] for c in cells]
    zs = [c[1] for c in cells]
    return min(xs), max(xs), min(zs), max(zs)
def has_hole(cells):
    cells = set(cells)
    x0, x1, z0, z1 = bbox(cells)
    x0, x1, z0, z1 = x0 - 1, x1 + 1, z0 - 1, z1 + 1
    start = (x0, z0)
    seen, todo = {start}, [start]
    while todo:
        c = todo.pop()
        for n in neighbours(c):
            if x0 <= n[0] <= x1 and z0 <= n[1] <= z1 and n not in cells and n not in seen:
                seen.add(n)
                todo.append(n)
    empty = (x1 - x0 + 1) * (z1 - z0 + 1) - len(cells)
    return len(seen) != empty
def pinches(cells):
    cells = set(cells)
    out = []
    x0, x1, z0, z1 = bbox(cells)
    for i in range(x0, x1 + 2):
        for j in range(z0, z1 + 2):
            a = (i - 1, j - 1) in cells
            b = (i, j - 1) in cells
            c = (i - 1, j) in cells
            d = (i, j) in cells
            if (a and d and not b and not c) or (b and c and not a and not d):
                out.append((i, j))
    return out
def valid(cells):
    return bool(cells) and connected(cells) and not has_hole(cells) and not pinches(cells)
def boundary_cycle(cells):
    cells = set(cells)
    nxt = {}
    for (i, j) in cells:
        if (i, j - 1) not in cells:
            nxt[(i + 1, j)] = (i, j)
        if (i, j + 1) not in cells:
            nxt[(i, j + 1)] = (i + 1, j + 1)
        if (i - 1, j) not in cells:
            nxt[(i, j)] = (i, j + 1)
        if (i + 1, j) not in cells:
            nxt[(i + 1, j + 1)] = (i + 1, j)
    start = min(nxt)
    out = [start]
    v = nxt[start]
    while v != start:
        out.append(v)
        v = nxt[v]
        if len(out) > len(nxt) + 1:
            raise ValueError("the boundary is not one simple cycle")
    if len(out) != len(nxt):
        raise ValueError("the boundary has more than one cycle")
    return out
def rotate_to(cycle, vertex, heading=None):
    n = len(cycle)
    for k in range(n):
        if cycle[k] == vertex:
            nb = cycle[(k + 1) % n]
            d = (nb[0] - vertex[0], nb[1] - vertex[1])
            if heading is None or d == heading:
                return cycle[k:] + cycle[:k]
    raise ValueError("vertex %r not on the cycle" % (vertex,))
def runs(points, closed=True):
    n = len(points)
    heads = []
    for k in range(n if closed else n - 1):
        a, b = points[k], points[(k + 1) % n]
        heads.append((b[0] - a[0], b[1] - a[1]))
    out = []
    if not heads:
        return out
    if closed:
        k0 = 0
        for k in range(len(heads)):
            if heads[k] != heads[k - 1]:
                k0 = k
                break
        order = list(range(k0, len(heads))) + list(range(0, k0))
    else:
        order = list(range(len(heads)))
    cur = None
    for k in order:
        if cur and heads[k] == cur[2]:
            cur[1] += 1
        else:
            if cur:
                out.append(tuple(cur))
            cur = [k, 1, heads[k]]
    if cur:
        out.append(tuple(cur))
    return out
def corners_of(points, closed=True):
    n = len(points)
    out = []
    for k in range(n):
        if not closed and (k == 0 or k == n - 1):
            continue
        a, b, c = points[k - 1], points[k], points[(k + 1) % n]
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]):
            out.append(k)
    return out
def rect_cells(i0, j0, w, h):
    return {(i, j) for i in range(i0, i0 + w) for j in range(j0, j0 + h)}
def rect_union(r, span_x, span_z, pieces=3, target=None, min_side=2):
    if target:
        half = max(4, int(round(target * r.uniform(0.55, 0.85) / 2.0)))
        w = r.randint(max(min_side, half // 3), max(min_side, min(span_x, half - 2)))
        h = max(2, min(span_z, half - w))
        if r.random() < 0.5 and w <= span_z and h <= span_x:
            w, h = h, w
    else:
        w = r.randint(max(3, span_x // 2), span_x)
        h = r.randint(2, max(2, span_z - 1))
    cells = rect_cells(0, 0, w, h)
    for _ in range(pieces):
        x0, x1, z0, z1 = bbox(cells)
        if r.random() < 0.6:
            big = 2 if target else max(1, span_x // 2)
            aw, ah = r.randint(1, big), r.randint(1, 2 if target else max(1, span_z // 2))
            ai = r.randint(x0 - aw, x1 + 1)
            aj = r.randint(z0 - ah, z1 + 1)
            new = cells | rect_cells(ai, aj, aw, ah)
        else:
            aw, ah = r.randint(1, max(1, (x1 - x0) // 2)), r.randint(1, max(1, (z1 - z0) // 2))
            side = r.choice("nswe")
            if side == "n":
                ai, aj = r.randint(x0 + 1, max(x0 + 1, x1 - aw)), z0
            elif side == "s":
                ai, aj = r.randint(x0 + 1, max(x0 + 1, x1 - aw)), z1 - ah + 1
            elif side == "w":
                ai, aj = x0, r.randint(z0 + 1, max(z0 + 1, z1 - ah))
            else:
                ai, aj = x1 - aw + 1, r.randint(z0 + 1, max(z0 + 1, z1 - ah))
            new = cells - rect_cells(ai, aj, aw, ah)
        bx = bbox(new) if new else None
        if bx and bx[1] - bx[0] + 1 <= span_x and bx[3] - bx[2] + 1 <= span_z and valid(new):
            cells = new
    return cells
def perimeter(cells):
    return sum(1 for c in cells for n in neighbours(c) if n not in cells)
def add_bump(cells, r, width=2, margin=1, avoid=()):
    cyc = boundary_cycle(cells)
    options = []
    for k0, n, d in runs(cyc):
        if n < width + 2 * margin:
            continue
        for s in range(margin, n - width - margin + 1):
            a = cyc[(k0 + s) % len(cyc)]
            b = cyc[(k0 + s + width) % len(cyc)]
            bump = set()
            for t in range(width):
                bump.add(cell_right((a[0] + d[0] * t, a[1] + d[1] * t), d))
            if any(c in cells for c in bump) or any(c in avoid for c in bump):
                continue
            new = cells | bump
            if valid(new):
                options.append((new, (a, b)))
    if not options:
        return cells, None
    return r.choice(options)
def quadrant_shape(r, span_x, span_z, sx, sz, target=None):
    base = rect_union(r, span_x, span_z, pieces=r.randint(0, 2), target=target)
    x0, x1, z0, z1 = bbox(base)
    out = set()
    for (i, j) in base:
        ni = (i - x0) if sx > 0 else -(i - x0) - 1
        nj = (j - z0) if sz > 0 else -(j - z0) - 1
        out.add((ni, nj))
    corner = (0 if sx > 0 else -1, 0 if sz > 0 else -1)
    if corner not in out:
        return None
    return out
def figure_eight(r, span_x, span_z, tries=40, target=None):
    for _ in range(tries):
        ta = None
        if target:
            ta = max(6, int(round(target * r.uniform(0.4, 0.6))))
        a = quadrant_shape(r, span_x, span_z, +1, -1, ta)
        b = quadrant_shape(r, span_x, span_z, -1, +1, target - ta if target else None)
        if not a or not b or not valid(a) or not valid(b):
            continue
        ca = rotate_to(boundary_cycle(a), (0, 0), (1, 0))
        cb = boundary_cycle(b)
        cb = list(reversed(cb))
        cb = rotate_to(cb, (0, 0), (0, 1))
        if (ca[0][0] - ca[-1][0], ca[0][1] - ca[-1][1]) != (0, 1):
            continue
        if (cb[0][0] - cb[-1][0], cb[0][1] - cb[-1][1]) != (1, 0):
            continue
        return ca + cb, a, b
    return None
def open_walk(r, target_cells, span, min_run=1, max_run=4, tries=200):
    for _ in range(tries):
        pts = [(0, 0)]
        used = {(0, 0)}
        heading = r.choice(DIRS)
        ok = True
        while len(pts) - 1 < target_cells:
            n = r.randint(min_run, max_run)
            turn = r.choice((left, right))
            if len(pts) > 1:
                heading = turn(heading)
            for _ in range(n):
                p = pts[-1]
                q = (p[0] + heading[0], p[1] + heading[1])
                near = [(q[0] + a, q[1] + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]
                older = set(pts[:-2])
                if q in used or any(v in older for v in near):
                    ok = False
                    break
                pts.append(q)
                used.add(q)
                if len(pts) - 1 >= target_cells:
                    break
            if not ok:
                break
            xs = [p[0] for p in pts]
            zs = [p[1] for p in pts]
            if max(xs) - min(xs) > span or max(zs) - min(zs) > span:
                ok = False
                break
        if ok and len(pts) - 1 >= target_cells:
            return pts
    return None
