import math
from . import geometry as geo
from .commands import Change, refusal
from .csg import over_budget
SIDES = ("-z", "+z", "-x", "+x")
SIDE_WORDS = {"-z": "back (-z)", "+z": "front (+z)", "-x": "left (-x)", "+x": "right (+x)"}
WALL = geo.GRID
FLOOR = 50
STAIR_RISE = 250
LANDING = 2 * geo.GRID
CLIMB_YAW = {"-z": 0, "-x": 90, "+z": 180, "+x": 270}
DIRS = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return geo.cleaned({"kind": "box", "tex": tex, "x": (x0 + x1) / 2.0, "y": y0,
                        "z": (z0 + z1) / 2.0, "w": x1 - x0, "h": y1 - y0, "d": z1 - z0, "yaw": 0,
                        "tag": tag})
def on_level_floor(doc, piece):
    if piece.get("h", 0) > FLOOR:
        return False
    try:
        from mapgen import solids
        return bool(solids._on_level_plane({"level": doc.rest.get("level")}, piece))
    except Exception:
        return False
def level_floor_free(doc, pieces):
    return [p for p in pieces if not on_level_floor(doc, p)]
def _finish(doc, pieces, label, what):
    from . import ops
    pieces = level_floor_free(doc, pieces)
    if not pieces:
        return refusal(label), label
    why_not = over_budget(doc, len(pieces), what)
    if why_not:
        return refusal(why_not), why_not
    return ops.insert(doc, [("piece", p) for p in pieces], label), label
def room_at(doc, centre, w=6, d=6, h=600, doors=("+z",), ceiling=False, wall_tex="stone1",
            floor_tex=None):
    from studio.toolbox import build
    w, d = max(3, int(w)), max(3, int(d))
    cx, cy, cz = centre
    x0 = geo.snap(cx - w * geo.GRID / 2.0, geo.GRID)
    z0 = geo.snap(cz - d * geo.GRID / 2.0, geo.GRID)
    pieces, note = build.room(x0, x0 + w * geo.GRID, z0, z0 + d * geo.GRID, cy, wall_tex,
                              floor_tex=floor_tex, height=h, doors=tuple(doors), roof=ceiling,
                              roof_tex=wall_tex)
    if not pieces:
        return refusal(note), note
    return _finish(doc, pieces, note, "The room")
def _cell(v):
    return int(math.floor(v / float(geo.GRID)))
SHAPES = (("xz", "L: along x, then z"), ("zx", "L: along z, then x"),
          ("straight", "Straight"), ("path", "Through the points you click"))
SHAPE_KEYS = tuple(k for k, _ in SHAPES)
END_KINDS = ("open", "door")
def _sign(v):
    return (v > 0) - (v < 0)
def path_vertices(points, shape="xz"):
    if shape not in SHAPE_KEYS:
        raise ValueError("a corridor runs %s" % ", ".join(SHAPE_KEYS))
    cells = [(_cell(p[0]), _cell(p[1])) for p in points]
    out = []
    for p in cells:
        if not out or out[-1] != p:
            out.append(p)
    if len(out) == 1:
        return out
    if shape != "path":
        out = [out[0], out[-1]]
    (ax, az), (bx, bz) = out[0], out[-1]
    if shape == "straight":
        if abs(bx - ax) >= abs(bz - az):
            return [(ax, az), (bx, az)]
        return [(ax, az), (ax, bz)]
    if shape in ("xz", "zx"):
        corner = (bx, az) if shape == "xz" else (ax, bz)
        return _clean([(ax, az), corner, (bx, bz)])
    verts = [out[0]]
    along = None
    for q in out[1:]:
        p = verts[-1]
        dx, dz = q[0] - p[0], q[1] - p[1]
        if dx and dz:
            first = along if along else ("x" if abs(dx) >= abs(dz) else "z")
            corner = (q[0], p[1]) if first == "x" else (p[0], q[1])
            verts.append(corner)
            along = "z" if first == "x" else "x"
        else:
            along = "x" if dx else "z"
        verts.append(q)
    return _clean(verts)
def _clean(verts):
    out = []
    for v in verts:
        if out and out[-1] == v:
            continue
        if len(out) >= 2:
            a, b = out[-2], out[-1]
            if (a[0] == b[0] == v[0]) or (a[1] == b[1] == v[1]):
                if _sign(b[0] - a[0]) == _sign(v[0] - b[0]) and \
                        _sign(b[1] - a[1]) == _sign(v[1] - b[1]):
                    out[-1] = v
                    continue
        out.append(v)
    return out
def _dir(p, q):
    return (_sign(q[0] - p[0]), _sign(q[1] - p[1]))
def corridor_cells(a, b, width=2, via=(), shape="xz", doors=()):
    floor, walls, _, _ = corridor_parts([a] + list(via) + [b], width, shape, doors)
    return floor, walls
def corridor_parts(points, width=2, shape="xz", doors=()):
    width = max(1, int(width))
    verts = path_vertices(points, shape)
    lo, hi = -((width - 1) // 2), width // 2
    floor = set()
    def band(c, d):
        if d[0]:
            return [(c[0], c[1] + k) for k in range(lo, hi + 1)]
        return [(c[0] + k, c[1]) for k in range(lo, hi + 1)]
    for p, q in zip(verts, verts[1:]):
        d = _dir(p, q)
        c = p
        while True:
            floor.update(band(c, d))
            if c == q:
                break
            c = (c[0] + d[0], c[1] + d[1])
    for v in verts[1:-1]:
        for i in range(lo, hi + 1):
            for k in range(lo, hi + 1):
                floor.add((v[0] + i, v[1] + k))
    if len(verts) == 1:
        floor.update(band(verts[0], (1, 0)))
    first = _dir(verts[0], verts[1]) if len(verts) > 1 else (1, 0)
    last = _dir(verts[-2], verts[-1]) if len(verts) > 1 else (1, 0)
    ends = {"a": (verts[0], (-first[0], -first[1])), "b": (verts[-1], last)}
    open_ends, end_walls, door_cells = set(), set(), set()
    for name, (c, d) in ends.items():
        out = (c[0] + d[0], c[1] + d[1])
        row = band(out, d)
        if name in doors:
            if d[0]:
                ext = [(out[0], out[1] + k) for k in range(lo - 1, hi + 2)]
            else:
                ext = [(out[0] + k, out[1]) for k in range(lo - 1, hi + 2)]
            end_walls.update(ext)
            door_cells.add(out)
        else:
            open_ends.update(row)
    end_walls -= floor
    door_cells -= floor
    end_walls -= door_cells
    taken = floor | open_ends | end_walls | door_cells
    walls = set()
    for (x, z) in floor:
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = (x + dx, z + dz)
                if c not in taken:
                    walls.add(c)
    def beside_floor(c):
        return any((c[0] + dx, c[1] + dz) in floor for dx, dz in ((1, 0), (-1, 0), (0, 1),
                                                                    (0, -1)))
    def by_an_end(c):
        return any((c[0] + dx, c[1] + dz) in open_ends for dx in (-1, 0, 1) for dz in (-1, 0, 1))
    walls = set(c for c in walls if beside_floor(c) or not by_an_end(c))
    return floor, walls, end_walls, door_cells
def rectangles(cells):
    left = set(cells)
    out = []
    for c in sorted(cells, key=lambda c: (c[1], c[0])):
        if c not in left:
            continue
        i0, k0 = c
        i1 = i0 + 1
        while (i1, k0) in left:
            i1 += 1
        k1 = k0 + 1
        while all((i, k1) in left for i in range(i0, i1)):
            k1 += 1
        for i in range(i0, i1):
            for k in range(k0, k1):
                left.discard((i, k))
        out.append((i0, i1, k0, k1))
    return out
DOOR_H = 400
def corridor_pieces(a, b, width=2, h=500, y=None, ceiling=False, wall_tex="stone1",
                    floor_tex=None, walls=True, blocked=None, via=(), shape="xz", doors=()):
    y = geo.snap(a[1] if y is None else y, geo.YGRID)
    h = max(4 * geo.YGRID, geo.snap(h, geo.YGRID))
    pts = [(a[0], a[2])] + [(p[0], p[-1]) for p in via] + [(b[0], b[2])]
    floor, wall_cells, end_walls, door_cells = corridor_parts(pts, width, shape, doors)
    n = len(floor)
    if not walls:
        end_walls, door_cells = set(), set()
    if blocked is not None:
        floor = set(c for c in floor if not blocked(c[0], c[1], y - FLOOR, y))
        wall_cells = set(c for c in wall_cells if not blocked(c[0], c[1], y - FLOOR, y + h))
        end_walls = set(c for c in end_walls if not blocked(c[0], c[1], y - FLOOR, y + h))
        door_cells = set(c for c in door_cells if not blocked(c[0], c[1], y - FLOOR, y + h))
    g = geo.GRID
    out = []
    for i0, i1, k0, k1 in rectangles(floor | door_cells):
        out.append(_box(floor_tex or wall_tex, i0 * g, i1 * g, y - FLOOR, y, k0 * g, k1 * g,
                        "corridor"))
    if walls:
        for i0, i1, k0, k1 in rectangles(wall_cells | end_walls):
            out.append(_box(wall_tex, i0 * g, i1 * g, y - FLOOR, y + h, k0 * g, k1 * g,
                            "corridor"))
        if h > DOOR_H:
            for i0, i1, k0, k1 in rectangles(door_cells):
                out.append(_box(wall_tex, i0 * g, i1 * g, y + DOOR_H, y + h, k0 * g, k1 * g,
                                "corridor.door"))
    if ceiling:
        roof = floor | ((wall_cells | end_walls | door_cells) if walls else set())
        if blocked is not None:
            roof = set(c for c in roof if not blocked(c[0], c[1], y + h, y + h + FLOOR))
        for i0, i1, k0, k1 in rectangles(roof):
            out.append(_box(wall_tex, i0 * g, i1 * g, y + h, y + h + FLOOR, k0 * g, k1 * g,
                            "corridor"))
    return out, n
def blocked_by(doc):
    boxes = [geo.aabb(p) for p in doc.pieces()]
    g = geo.GRID
    def blocked(i, k, y0, y1):
        cell = (i * g, (i + 1) * g, y0, y1, k * g, (k + 1) * g)
        return any(geo.overlap_volume(cell, b) > 0 for b in boxes)
    return blocked
def corridor(doc, a, b, width=2, h=500, ceiling=False, wall_tex="stone1", floor_tex=None,
             walls=True, via=(), shape="xz", doors=()):
    pieces, cells = corridor_pieces(a, b, width, h, None, ceiling, wall_tex, floor_tex, walls,
                                    blocked=blocked_by(doc), via=via, shape=shape, doors=doors)
    verts = path_vertices([(a[0], a[2])] + [(p[0], p[-1]) for p in via] + [(b[0], b[2])],
                          shape)
    turns = max(0, len(verts) - 2)
    from studio.toolbox import build
    note = "Corridor %d cells long, %d wide, %s high%s%s%s" % (
        cells // max(1, int(width)), int(width), build.metres(h),
        "" if not turns else ", one turn" if turns == 1 else ", %d turns" % turns,
        ", roofed" if ceiling else "",
        "" if not doors else ", a door at %s" % " and ".join(
            {"a": "A", "b": "B"}[d] for d in ("a", "b") if d in doors))
    if shape == "straight" and verts[-1] != (_cell(b[0]), _cell(b[2])):
        note += " (B is off the line: it ends level with B)"
    if abs((b[1] or 0) - (a[1] or 0)) >= geo.YGRID:
        note += " (B is %d higher: Stairs between floors climbs it)" % ((b[1] or 0) - (a[1] or 0))
    return _finish(doc, pieces, note, "The corridor")
def rises(total):
    total = int(geo.snap(abs(total), geo.YGRID))
    if total <= 0:
        return []
    n = int(math.ceil(total / float(STAIR_RISE)))
    steps = total // geo.YGRID
    base, extra = divmod(steps, n)
    return [(base + (1 if i < extra else 0)) * geo.YGRID for i in range(n)]
def run_for(rise):
    for run in (400, 800, 1200):
        if run >= 2 * rise:
            return run
    return 1200
def stairs_pieces(start, y1, direction="+z", width=2, tex="stone1", support=True):
    if direction not in DIRS:
        raise ValueError("stairs climb +x, -x, +z or -z")
    x, y0, z = start
    y0 = geo.snap(y0, geo.YGRID)
    y1 = geo.snap(y1, geo.YGRID)
    width = max(1, int(width)) * geo.GRID
    up = y1 >= y0
    flights = rises(y1 - y0)
    if not flights:
        return [], "Stairs: the two floors are at the same height"
    dx, dz = DIRS[direction]
    along = geo.snap(x if dx else z, geo.GRID)
    across = geo.snap((z if dx else x) - width / 2.0, geo.GRID)
    sign = dx or dz
    out = []
    y = y0
    seq = flights if up else list(reversed(flights))
    yaw = CLIMB_YAW[direction] if up else CLIMB_YAW[{"+x": "-x", "-x": "+x", "+z": "-z",
                                                    "-z": "+z"}[direction]]
    if not up:
        y = y1 + sum(flights)
    pos = along
    base = min(y0, y1)
    for n, r in enumerate(seq):
        run = run_for(r)
        a0, a1 = sorted((pos, pos + sign * run))
        bot = y if up else y - r
        flight = _rect(direction, a0, a1, across, across + width, bot, r, tex)
        flight["kind"] = "stairs"
        flight["yaw"] = yaw
        if yaw in (90, 270):
            flight["w"], flight["d"] = flight["d"], flight["w"]
        out.append(flight)
        if support and bot > base:
            out.append(_rect(direction, a0, a1, across, across + width, base, bot - base, tex,
                             "stairs.support"))
        pos += sign * run
        y = bot + r if up else bot
        if n < len(seq) - 1:
            l0, l1 = sorted((pos, pos + sign * LANDING))
            top = y
            out.append(_rect(direction, l0, l1, across, across + width, base, top - base, tex,
                             "stairs.landing"))
            pos += sign * LANDING
    note = "Stairs %+d in %d flight%s towards %s, %d cells wide, %d cells long" % (
        y1 - y0, len(flights), "" if len(flights) == 1 else "s", direction, width // geo.GRID,
        abs(pos - along) // geo.GRID)
    return [geo.cleaned(p) for p in out if p["h"] > 0], note
def _rect(direction, a0, a1, c0, c1, y, h, tex, tag="stairs"):
    if direction in ("+x", "-x"):
        x0, x1, z0, z1 = a0, a1, c0, c1
    else:
        x0, x1, z0, z1 = c0, c1, a0, a1
    return _box(tex, x0, x1, y, y + h, z0, z1, tag)
def stairs(doc, start, y1, direction="+z", width=2, tex="stone1"):
    pieces, note = stairs_pieces(start, y1, direction, width, tex)
    if not pieces:
        return refusal(note), note
    return _finish(doc, pieces, note, "The stairs")
