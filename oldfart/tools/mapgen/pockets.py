from . import decor, houses, interiors, kit
HALL_W = 2400
HALL_D = 2800
HALL_H = 1200
WALL = 200
LIP = 20
MAT = (20, 140)
FRONT_IN = 160
EXIT = (180, 340)
DOOR_HALF = 100
WARP_LIFT = 2
GROUND_GAP = 600
FLOOR_LEAST = -5400
SURFACE_ENTER, SURFACE_EXIT = 0x1B, 0x1C
FUNCTIONS = ("tavern", "chapel", "home")
def hall_pieces(st, floor_y, z1, function="tavern", theme=None, tag="pocket"):
    o = houses.Out(tag)
    zf = z1 + FRONT_IN
    zb = zf - HALL_D
    x0, x1 = -HALL_W // 2, HALL_W // 2
    y = floor_y
    wall, floor, trim = st.get("wall") or "stone1", st.get("planks") or st.get("floor") or \
        "darkplanks", st.get("trim") or "darkplanks"
    o.box(floor, x0 - WALL, x1 + WALL, y - LIP, y, zb - WALL, zf + WALL, "floor", "floor")
    o.box(wall, x0 - WALL, x1 + WALL, y, y + HALL_H, zb - WALL, zb, "walls", "wall")
    o.box(wall, x0 - WALL, x0, y, y + HALL_H, zb, zf, "walls", "wall")
    o.box(wall, x1, x1 + WALL, y, y + HALL_H, zb, zf, "walls", "wall")
    o.box(wall, x0 - WALL, -DOOR_HALF, y, y + HALL_H, zf, zf + WALL, "walls", "wall")
    o.box(wall, DOOR_HALF, x1 + WALL, y, y + HALL_H, zf, zf + WALL, "walls", "wall")
    o.box(wall, -DOOR_HALF, DOOR_HALF, y + 2 * houses.C, y + HALL_H, zf, zf + WALL, "walls",
          "lintel")
    door = st.get("door") or "doorplank"
    o.box(door, -DOOR_HALF, DOOR_HALF, y, y + 2 * houses.C, zf + WALL - LIP, zf + WALL, "door",
          "door")
    o.box(trim, x0 - WALL, x1 + WALL, y + HALL_H, y + HALL_H + WALL, zb - WALL, zf + WALL,
          "roof", "ceiling")
    base = st.get("base") or "stone1"
    o.box(base, -500, -300, y, y + 700, zb, zb + 300, "hearth", "hearth")
    o.box(base, 300, 500, y, y + 700, zb, zb + 300, "hearth", "hearth")
    o.box(base, -500, 500, y + 700, y + 800, zb, zb + 360, "hearth", "mantel")
    fire = decor.piece("campfire", 0, y, zb + 220, 0, theme=theme, tag="%s.hearth.fire" % tag)
    fire["context"] = "interior"
    o.pieces.append(fire)
    for lx in (x0 + 250, x1 - 250):
        lamp = decor.piece("lamp", lx, y, zf - 300, 0, theme=theme, tag="%s.interior.lamp" % tag)
        lamp["context"] = "interior"
        o.pieces.append(lamp)
    st2 = dict(st, rug=st.get("rug"))
    interiors.furnish(o, st2, (x0, x1, zb + 400, zf - 600), y, function, doors=("front",),
                      taken=[(-500, 500, zb, zb + 360)], theme=theme)
    inner = (x0, x1, y, y + HALL_H, zb, zf)
    room = (x0, x1, y - LIP, y + HALL_H, zb, zf + WALL)
    return o.pieces, inner, room
def turn_box(box, face, cx, cz):
    x0, x1, y0, y1, z0, z1 = box
    r = houses.turn_rect((x0, x1, z0, z1), face)
    return (r[0] + cx, r[1] + cx, y0, y1, r[2] + cz, r[3] + cz)
def shift_of(arena, floors, low=None):
    pieces = arena.get("pieces") or []
    if low is None:
        low = min([p["y"] for p in pieces] or [0]) - 400
    dy = low - GROUND_GAP - (HALL_H + WALL) - max(floors)
    dy = int(dy // 100 * 100)
    from . import v1
    m = v1.arenas_module()
    plane = (m.LEVELS.get(arena.get("level")) or {}).get("plane")
    least = FLOOR_LEAST if plane is None else max(FLOOR_LEAST, plane + 2048 + WALL + 10)
    if min(floors) + dy < least:
        return None
    return (0, dy, 0)
def _in_level(arena, pieces):
    from . import v1
    m = v1.arenas_module()
    level = m.LEVELS.get(arena.get("level")) or {}
    half = min(m.BOUND, level.get("half", m.BOUND))
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        if max(abs(x0), abs(x1), abs(z0), abs(z1)) > half:
            return False
    return True
def make(arena, houses_built, st_of, theme=None, most=2, low=None, shift=None):
    picks = []
    for b, at, face, s in houses_built:
        if b.get("enterable") or not b.get("door") or b.get("recipe") not in ("H1", "H3", "H5"):
            continue
        if any(abs(at[0] - p[1][0]) < HALL_W * 2 and abs(at[1] - p[1][1]) < HALL_W * 2
               for p in picks):
            continue
        picks.append((b, at, face, s))
        if len(picks) >= most:
            break
    if not picks:
        return 0
    if shift is None:
        shift = shift_of(arena, [at[2] + b["floor"] for b, at, _, _ in picks], low)
    if shift is None:
        return 0
    arena.setdefault("pockets", [])
    for n, (b, at, face, s) in enumerate(picks):
        cx, cz, y = at
        body = b.get("body")
        if body is None:
            continue
        z1 = body[3]
        floor_y = b["floor"]
        door_x = b["door"][0]
        st = st_of(s)
        function = FUNCTIONS[n % len(FUNCTIONS)]
        tag = "pocket.%d" % len(arena["pockets"])
        ps, inner, room = hall_pieces(st, floor_y, z1, function, theme, tag)
        ps = [dict(p, x=p["x"] + door_x) for p in ps]
        placed = houses.place({"pieces": ps}, cx, cz, y, face)
        for p in placed:
            p["x"] += shift[0]
            p["y"] += shift[1]
            p["z"] += shift[2]
        if not _in_level(arena, placed):
            continue
        arena["pieces"].extend(placed)
        def world(box, dy=0):
            x0, x1, y0, y1, z0, z1_ = turn_box((box[0] + door_x, box[1] + door_x) + tuple(box[2:]),
                                                face, cx, cz)
            return [x0 + shift[0], x1 + shift[0], y0 + y + dy, y1 + y + dy, z0 + shift[2],
                    z1_ + shift[2]]
        mat = (door_x - DOOR_HALF, door_x + DOOR_HALF, floor_y, floor_y, z1 + MAT[0], z1 + MAT[1])
        ext = (door_x - DOOR_HALF, door_x + DOOR_HALF, floor_y, floor_y, z1 + EXIT[0], z1 + EXIT[1])
        mx0, mx1, _, _, mz0, mz1 = turn_box((mat[0], mat[1], 0, 0, mat[4], mat[5]), face, cx, cz)
        ex0, ex1, _, _, ez0, ez1 = turn_box((ext[0], ext[1], 0, 0, ext[4], ext[5]), face, cx, cz)
        arena["pockets"].append({
            "door": [mx0, mz0, mx1, mz1, y + floor_y],
            "exit": [ex0 + shift[0], ez0 + shift[2], ex1 + shift[0], ez1 + shift[2],
                     y + floor_y + shift[1]],
            "box": world(room, shift[1]), "inner": world(inner, shift[1]),
            "shift": list(shift), "tag": tag, "function": function})
    return len(arena["pockets"])
HALL_LOT = (2000, 1600)
def hall_house(arena, x, z, y, theme=None, face="s", seed=1):
    import random
    from . import beauty
    theme = theme if theme not in (None, "auto") else "garden"
    r = random.Random(seed)
    pal, _ = beauty.palette(theme)
    st = houses.style_for(theme, pal, r)
    b = houses.build("H1", st, HALL_LOT, r, intent="climbable", enterable=False)
    if b is None or not b.get("door") or not b.get("body"):
        return None, "a house does not stand here"
    house = houses.place(b, x, z, y, face)
    old = [dict(pk) for pk in arena.get("pockets") or [] if isinstance(pk, dict)]
    probe = {"pieces": list(arena.get("pieces") or []) + house, "pockets": list(old)}
    had = len(probe["pieces"])
    shift = tuple(old[0]["shift"]) if old and old[0].get("shift") else None
    got = make(probe, [(b, (x, z, y), face, 0)], lambda s_: st, theme=theme, most=1,
               shift=shift)
    if not got or len(probe["pockets"]) <= len(old):
        return None, "no room for a hall under the world here"
    rec = probe["pockets"][-1]
    hall = probe["pieces"][had:]
    if shift is not None:
        top = max(p["y"] + p["h"] for p in hall)
        rest = [p for p in arena.get("pieces") or [] if not str(p.get("tag", "")).startswith("pocket")]
        if rest and top > min(p["y"] for p in rest) - GROUND_GAP // 2:
            return None, "this house stands too low over the map's other halls"
    return house + hall, rec
