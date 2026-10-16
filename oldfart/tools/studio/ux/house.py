import random
from studio.editor import geometry as geo
CELL = 400
STOREY = 400
TAG = "house.brush"
PANEL = 40
STEP = 20
SIDES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
def snap_cell(v):
    return int((v // CELL) * CELL)
def cell_at(point, normal=None, base_y=None):
    x, y, z = point
    nx, ny, nz = normal if normal is not None else (0.0, 1.0, 0.0)
    eps = 1.0
    if abs(nx) > 0.5:
        x += eps * (1 if nx > 0 else -1)
    if abs(nz) > 0.5:
        z += eps * (1 if nz > 0 else -1)
    if ny > 0.5:
        cy = y
    elif ny < -0.5:
        cy = y - STOREY
    else:
        cy = y if base_y is None else base_y
    return snap_cell(x), int(round(cy / float(geo.YGRID)) * geo.YGRID), snap_cell(z)
def cell_under(point, cells):
    x, y, z = point
    for (cx, cy, cz) in cells:
        if cx <= x <= cx + CELL and cz <= z <= cz + CELL and cy <= y <= cy + STOREY + 1:
            return (cx, cy, cz)
    return None
def _box(tex, x0, x1, y0, y1, z0, z1, part, kind="box", yaw=0):
    w, d = x1 - x0, z1 - z0
    if yaw in (90, 270):
        w, d = d, w
    return {"kind": kind, "tex": tex, "x": (x0 + x1) / 2.0, "y": y0, "z": (z0 + z1) / 2.0,
            "w": w, "h": y1 - y0, "d": d, "yaw": yaw, "tag": "%s.%s" % (TAG, part)}
def columns(cells):
    cols = {}
    for (x, y, z), tex in cells.items():
        cols.setdefault((x, z), []).append((y, tex))
    out = {}
    for key, ys in cols.items():
        ys.sort()
        runs = []
        for y, tex in ys:
            if runs and runs[-1][1] == y and runs[-1][2] == tex:
                runs[-1] = (runs[-1][0], y + STOREY, tex)
            else:
                runs.append((y, y + STOREY, tex))
        out[key] = runs
    return out
def masses(cells):
    cols = columns(cells)
    spans = []
    for (x, z), runs in cols.items():
        for y0, y1, tex in runs:
            spans.append([x, x + CELL, y0, y1, z, z + CELL, tex])
    spans.sort(key=lambda s: (s[4], s[2], s[3], s[6], s[0]))
    merged = []
    for s in spans:
        last = merged[-1] if merged else None
        if last and last[4] == s[4] and last[2] == s[2] and last[3] == s[3] and \
                last[6] == s[6] and last[1] == s[0]:
            last[1] = s[1]
        else:
            merged.append(list(s))
    return merged
def _open_sky(cells, x0, x1, y1, z):
    return all((x, y1, z) not in cells for x in range(int(x0), int(x1), CELL))
def courtyards(cells):
    ground = {}
    for (x, y, z) in cells:
        ground.setdefault(y, set()).add((x, z))
    out = []
    for y, have in ground.items():
        xs = sorted({x for x, _ in have})
        zs = sorted({z for _, z in have})
        if not xs or not zs:
            continue
        inner = set()
        for x in range(xs[0], xs[-1] + CELL, CELL):
            for z in range(zs[0], zs[-1] + CELL, CELL):
                if (x, z) in have:
                    continue
                w = any((xx, z) in have for xx in range(xs[0], x, CELL))
                e = any((xx, z) in have for xx in range(x + CELL, xs[-1] + CELL, CELL))
                n = any((x, zz) in have for zz in range(zs[0], z, CELL))
                s = any((x, zz) in have for zz in range(z + CELL, zs[-1] + CELL, CELL))
                if w and e and n and s:
                    inner.add((x, z))
        for (x, z) in sorted(inner):
            block = [(x, z), (x + CELL, z), (x, z + CELL), (x + CELL, z + CELL)]
            if all(b in inner for b in block):
                out.append((x, z, x + 2 * CELL, z + 2 * CELL, y))
                for b in block:
                    inner.discard(b)
    return out
def build(cells, theme="castle", seed=1):
    rng = random.Random(seed)
    pieces = []
    try:
        from mapgen import detailrules as rules
        ctx = rules.Ctx(theme, seed)
    except Exception:
        rules = ctx = None
    for x0, x1, y0, y1, z0, z1, tex in masses(cells):
        mass = _box(tex, x0, x1, y0, y1, z0, z1, "mass")
        pieces.append(mass)
        if rules is not None and _open_sky(cells, x0, x1, y1, z0):
            try:
                roof = rules.make_roof(dict(mass, tag=""), ctx)
                for r in roof:
                    r["tag"] = TAG + ".roof"
                pieces += roof
            except Exception:
                pass
    door_cells = _door_cells(cells)
    door_done = set()
    for (x, y, z), tex in sorted(cells.items()):
        for side, (dx, dz) in SIDES.items():
            if (x + dx * CELL, y, z + dz * CELL) in cells:
                continue
            ground = (x, y - STOREY, z) not in cells
            cx, cz = x + CELL / 2.0, z + CELL / 2.0
            fx = x + CELL if dx > 0 else x if dx < 0 else None
            fz = z + CELL if dz > 0 else z if dz < 0 else None
            if ground and (x, y, z) in door_cells and (x, z) not in door_done and \
                    _door_side(cells, x, y, z) == side:
                door_done.add((x, z))
                pieces += _door(tex, cx, cz, fx, fz, y, side)
            elif not ground and rng.random() < 0.5:
                pieces += _window(tex, cx, cz, fx, fz, y, side)
    for x0, z0, x1, z1, y in courtyards(cells):
        pieces.append(_box("grass", x0 + 100, x1 - 100, y, y + STEP, z0 + 100, z1 - 100,
                           "garden"))
        pieces.append(_box("stone1", (x0 + x1) / 2 - 200, (x0 + x1) / 2 + 200, y + STEP,
                           y + STEP + 200, (z0 + z1) / 2 - 200, (z0 + z1) / 2 + 200,
                           "fountain"))
    return [geo.cleaned(p) for p in pieces]
def _door_cells(cells):
    ground = {k: t for k, t in cells.items() if (k[0], k[1] - STOREY, k[2]) not in cells}
    seen, out = set(), set()
    for start in sorted(ground):
        if start in seen:
            continue
        group, todo = [], [start]
        seen.add(start)
        while todo:
            c = todo.pop()
            group.append(c)
            for dx, dz in SIDES.values():
                n = (c[0] + dx * CELL, c[1], c[2] + dz * CELL)
                if n in ground and n not in seen and ground[n] == ground[start]:
                    seen.add(n)
                    todo.append(n)
        best, score = None, None
        for c in sorted(group):
            side = _door_side(cells, *c)
            if side is None:
                continue
            dx, dz = SIDES[side]
            free = sum(1 for k in range(1, 4)
                       if (c[0] + dx * CELL * k, c[1], c[2] + dz * CELL * k) not in cells)
            key = (free, side == "+z", -abs(c[0]))
            if score is None or key > score:
                best, score = c, key
        if best is not None:
            out.add(best)
    return out
def _door_side(cells, x, y, z):
    best, score = None, -1
    for side in ("+z", "-z", "+x", "-x"):
        dx, dz = SIDES[side]
        if (x + dx * CELL, y, z + dz * CELL) in cells:
            continue
        free = sum(1 for k in range(1, 4)
                   if (x + dx * CELL * k, y, z + dz * CELL * k) not in cells)
        if free > score:
            best, score = side, free
    return best
def _panel(tex, cx, cz, fx, fz, y0, y1, w, kind, part):
    if fx is not None:
        sgn = 1 if fx > cx else -1
        return _box(tex, min(fx, fx + sgn * PANEL), max(fx, fx + sgn * PANEL), y0, y1,
                    cz - w / 2, cz + w / 2, part, kind=kind, yaw=0)
    sgn = 1 if fz > cz else -1
    return _box(tex, cx - w / 2, cx + w / 2, y0, y1, min(fz, fz + sgn * PANEL),
                max(fz, fz + sgn * PANEL), part, kind=kind, yaw=0)
def _door(tex, cx, cz, fx, fz, y, side):
    door = _panel(tex, cx, cz, fx, fz, y, y + 300, 200, "doorway", "door")
    out = [door]
    dx, dz = SIDES[side]
    if fx is not None:
        x0 = fx + (PANEL if dx > 0 else -PANEL - 200)
        out.append(_box("stone1", x0, x0 + 200, y, y + STEP, cz - 150, cz + 150, "step"))
    else:
        z0 = fz + (PANEL if dz > 0 else -PANEL - 200)
        out.append(_box("stone1", cx - 150, cx + 150, y, y + STEP, z0, z0 + 200, "step"))
    return out
def _window(tex, cx, cz, fx, fz, y, side):
    return [_panel(tex, cx, cz, fx, fz, y + 120, y + 300, 160, "window", "window")]
def is_house(piece):
    return str(piece.get("tag", "")).startswith(TAG)
def cells_of_boxes(boxes):
    cells = {}
    for b in boxes:
        x0, x1, y0, y1, z0, z1 = geo.aabb(b)
        for x in range(snap_cell(x0), int(x1), CELL):
            for z in range(snap_cell(z0), int(z1), CELL):
                y = int(y0)
                while y + STOREY <= y1 + 1:
                    cells[(x, y, z)] = b.get("tex", "brick1")
                    y += STOREY
    return cells
