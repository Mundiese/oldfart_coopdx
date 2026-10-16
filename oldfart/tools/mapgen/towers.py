from . import houses, kit, roofs
C = houses.C
TOWER = 8
WALL_T = houses.WALL_T
SEG = 2 * C
RISE = houses.FLIGHT_RISE
SLAB = 200
HEAD = 400
POST = 120
POST_H = 600
PARAPET = houses.PARAPET_H
FLIGHT_KIND = "ramp"
SLIT, SLIT_H, SILL = 240, 300, 160
def ring(x0, x1, z0, z1):
    a, b = x0 + SEG, x1 - SEG
    c, d = z0 + SEG, z1 - SEG
    corner = {"fr": (b, x1, d, z1), "br": (b, x1, z0, c), "bl": (x0, a, z0, c),
              "fl": (x0, a, d, z1)}
    side = {"r": ((b, x1, c, d), "-z"), "b": ((a, b, z0, c), "-x"), "l": ((x0, a, c, d), "+z"),
            "f": ((a, b, d, z1), "+x")}
    order = [("fr", "r"), ("br", "b"), ("bl", "l"), ("fl", "f")]
    while True:
        for cn, sd in order:
            yield ("landing", corner[cn], None)
            yield ("flight",) + side[sd]
def tower(st, lot, r, intent="out_of_reach", tag="tower", storeys=None):
    lw, ld = lot
    S = TOWER * C
    front = houses.PROUD + houses.FLIGHT_RUN + 100
    if S + 2 * houses.PROUD > lw or S + front + houses.PROUD > ld:
        return None
    n = storeys or (3 if r.random() < 0.5 else 2)
    o = houses.Out(tag)
    z1 = ld // 2 - front
    b = houses.Body(-S // 2, S // 2, z1 - S, z1, houses.PLINTH_H, n)
    stone = st["base"]
    wall = st["wall"] if st.get("family") in ("masonry", "brick", "rock") else stone
    houses.plinth(o, st, b)
    y0 = b.y
    top = y0 + houses.FLOOR_T + n * houses.STOREY
    g0, g1 = -houses.DOOR_W // 2, houses.DOOR_W // 2
    o.box(wall, b.x0, g0, y0, top, b.z1 - WALL_T, b.z1, "walls", "wall")
    o.box(wall, g1, b.x1, y0, top, b.z1 - WALL_T, b.z1, "walls", "wall")
    o.box(st["trim"], g0, g1, y0 + houses.DOOR_H, y0 + houses.STOREY, b.z1 - WALL_T, b.z1,
          "door", "trim")
    o.box(wall, g0, g1, y0 + houses.STOREY, top, b.z1 - WALL_T, b.z1, "walls", "wall")
    o.box(wall, b.x0, b.x1, y0, top, b.z0, b.z0 + WALL_T, "walls", "wall")
    o.add("stairs", stone, g0, g1, 0, y0, b.z1 + houses.PROUD,
          b.z1 + houses.PROUD + houses.FLIGHT_RUN, "-z", "step", "steps")
    door_pt = (0, b.z1 + houses.PROUD + houses.FLIGHT_RUN + 100)
    ix0, ix1, iz0, iz1 = b.x0 + WALL_T, b.x1 - WALL_T, b.z0 + WALL_T, b.z1 - WALL_T
    o.box(st["floor"], ix0, ix1, y0, y0 + houses.FLOOR_T, iz0, iz1, "interior", "floor")
    fy = y0 + houses.FLOOR_T
    nx0, nz0 = ix0 + SEG, iz0 + SEG
    o.box(stone, nx0, nx0 + SEG, fy, top, nz0, nz0 + SEG, "stair", "newel")
    h = 0
    goal = top - fy
    climb = []
    side_flights = {}
    seq = ring(ix0, ix1, iz0, iz1)
    for kind, rect, rises in seq:
        x0, x1, z0, z1 = rect
        if kind == "landing":
            if h > 0:
                lo = fy + h - SLAB if h - SLAB >= HEAD else fy
                o.box(stone, x0, x1, lo, fy + h, z0, z1, "stair", "landing")
            climb.append((rect, h))
            if h >= goal:
                break
            continue
        if 0 < h < HEAD:
            o.box(stone, x0, x1, fy, fy + h, z0, z1, "stair", "landing")
        o.add(FLIGHT_KIND, stone, x0, x1, fy + h, fy + h + RISE, z0, z1, rises, "stair", "stair")
        if x0 == ix0 or x1 == ix1:
            side_flights.setdefault(x0 == ix0, []).append(h)
        h += RISE
        climb.append((rect, h))
    zm = (b.z0 + b.z1) // 2
    w0, w1 = zm - SLIT // 2, zm + SLIT // 2
    for left, (xa, xb) in ((True, (b.x0, b.x0 + WALL_T)), (False, (b.x1 - WALL_T, b.x1))):
        o.box(wall, xa, xb, y0, top, b.z0 + WALL_T, w0, "walls", "wall")
        o.box(wall, xa, xb, y0, top, w1, b.z1 - WALL_T, "walls", "wall")
        yy = y0
        for hb in sorted(side_flights.get(left, []))[:1]:
            sill = fy + hb + RISE + SILL
            if sill + SLIT_H > top - 100:
                break
            o.box(wall, xa, xb, yy, sill, w0, w1, "walls", "wall")
            yy = sill + SLIT_H
        o.box(wall, xa, xb, yy, top, w0, w1, "walls", "lintel")
    well = [rect for rect, hh in climb if hh > goal - 3 * RISE - 1]
    cells = []
    for i in range((ix1 - ix0) // SEG):
        for j in range((iz1 - iz0) // SEG):
            c = (ix0 + i * SEG, ix0 + (i + 1) * SEG, iz0 + j * SEG, iz0 + (j + 1) * SEG)
            if (c[0], c[2]) == (nx0, nz0):
                continue
            if not any(c[0] < w[1] and w[0] < c[1] and c[2] < w[3] and w[2] < c[3]
                       for w in well):
                cells.append(c)
    for x0, x1, z0, z1 in _merge(cells):
        o.box(stone, x0, x1, top - SLAB, top, z0, z1, "interior", "deck")
    rail = st["rail"] if kit.comes_in(st["rail"], "rail") else st["trim"]
    t = 60
    for x0, x1, z0, z1 in ((b.x0, b.x1, b.z1 - t, b.z1), (b.x0, b.x1, b.z0, b.z0 + t),
                           (b.x0, b.x0 + t, b.z0 + t, b.z1 - t),
                           (b.x1 - t, b.x1, b.z0 + t, b.z1 - t)):
        o.add("rail", rail, x0 + (POST if x1 - x0 > t else 0), x1 - (POST if x1 - x0 > t else 0),
              top, top + PARAPET, z0 + (POST if z1 - z0 > t else 0),
              z1 - (POST if z1 - z0 > t else 0), None, "roof", "parapet")
    post = st["trim"] if kit.comes_in(st["trim"], "pillar") else stone
    for px in (b.x0, b.x1 - POST):
        for pz in (b.z0, b.z1 - POST):
            o.add("pillar", post, px, px + POST, top, top + POST_H, pz, pz + POST, None, "roof",
                  "post")
    specs, cap_top = roofs.pieces("cap", st["roof"], b.x0 - houses.EAVE, b.x1 + houses.EAVE,
                                  b.z0 - houses.EAVE, b.z1 + houses.EAVE, top + POST_H,
                                  trim=None, finial=post, height=S // 2 + houses.EAVE)
    for sp in specs:
        o.add(sp[0], sp[1], sp[2], sp[3], sp[4], sp[5], sp[6], sp[7], sp[8], "roof",
              "roof" if sp.word == "roof" else sp.word)
    for s in range(n):
        houses.windows(o, st, b, s, ("back",))
    out = houses._finish(o, "H14", b, "vantage", True, 1, door_pt, cap_top,
                         ["a tower: no stack; its stair climbs inside"], function="lookout",
                         lookout=top, stair=len(climb))
    out["eave"] = top + POST_H
    return out
def _merge(rects):
    rs = sorted(rects, key=lambda r: (r[2], r[0]))
    rows = []
    for r in rs:
        if rows and rows[-1][2] == r[2] and rows[-1][3] == r[3] and rows[-1][1] == r[0]:
            rows[-1] = (rows[-1][0], r[1], r[2], r[3])
        else:
            rows.append(r)
    out = []
    for r in sorted(rows, key=lambda r: (r[0], r[1], r[2])):
        if out and out[-1][0] == r[0] and out[-1][1] == r[1] and out[-1][3] == r[2]:
            out[-1] = (r[0], r[1], out[-1][2], r[3])
        else:
            out.append(r)
    return out
