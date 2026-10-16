from . import decor, kit
LIP = 20
GAP = 10
RUG_MIN = 1000
FRONT_MIN = 1200
CLEAR = 300
FURNITURE = {
    "home": ("barrels", "bench"),
    "shop": ("crates", "barrels"),
    "tavern": ("barrels", "bench"),
    "chapel": ("bench", "bench"),
    "forge": ("barrels", "crates"),
    "barn": ("haybale", "haybale"),
}
def _size(key):
    r = decor.BY_KEY[key]
    c = r.get("collide")
    if c:
        return c
    x0, x1, y0, y1, z0, z1 = decor.visual_box(r)
    return (x1 - x0, y1 - y0, z1 - z0)
def _rect_of(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw", 0))) % 180 == 90:
        w, d = d, w
    return (p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0)
def _hits(r, others):
    return any(r[0] < o[1] and o[0] < r[1] and r[2] < o[3] and o[2] < r[3] for o in others)
def furnish(o, st, room, y, function="home", doors=("front",), taken=(), theme=None):
    x0, x1, z0, z1 = room
    w, d = x1 - x0, z1 - z0
    used = [tuple(t) for t in taken]
    xc, zc = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    lanes = []
    if "front" in doors:
        lanes.append((-CLEAR, CLEAR, zc, z1))
    if "back" in doors:
        lanes.append((-CLEAR, CLEAR, z0, zc))
    if "left" in doors:
        lanes.append((x0, xc, zc - CLEAR, zc + CLEAR))
    keys = FURNITURE.get(function, FURNITURE["home"])
    corners = ["back_right", "back_left"]
    if w >= FRONT_MIN and d >= FRONT_MIN:
        corners += ["front_left", "front_right"]
    want = 3 if w >= FRONT_MIN and d >= FRONT_MIN else 2
    laid = []
    k = 0
    for where in corners:
        if len(laid) >= want:
            break
        key = keys[k % len(keys)]
        sw, sh, sd = _size(key)
        if sh > 220:
            continue
        if where == "back_right":
            px, pz, yaw = x1 - sw / 2.0 - GAP, z0 + sd / 2.0 + GAP, 0
        elif where == "back_left":
            px, pz, yaw = x0 + sw / 2.0 + GAP, z0 + sd / 2.0 + GAP, 0
        elif where == "front_left":
            px, pz, yaw = x0 + sd / 2.0 + GAP, z1 - sw / 2.0 - GAP, 90
        else:
            px, pz, yaw = x1 - sd / 2.0 - GAP, z1 - sw / 2.0 - GAP, 90
        p = decor.piece(key, px, y, pz, yaw, theme=theme, tag="%s.interior.%s" % (o.tag, key))
        p["context"] = "interior"
        r = _rect_of(p)
        if r[0] < x0 or r[1] > x1 or r[2] < z0 or r[3] > z1:
            continue
        if _hits(r, used) or _hits(r, lanes):
            continue
        used.append(r)
        k += 1
        o.pieces.append(p)
        o.parts["interior"] = o.parts.get("interior", 0) + 1
        laid.append(p)
    rug = st.get("rug")
    if rug and w >= RUG_MIN and d >= RUG_MIN:
        rx0, rx1 = x0 + 200, x1 - 200
        rz0, rz1 = z0 + 200, z1 - 200
        for t in used:
            if t[3] <= zc:
                rz0 = max(rz0, t[3] + 100)
            if t[2] >= zc:
                rz1 = min(rz1, t[2] - 100)
        if rx1 - rx0 >= 400 and rz1 - rz0 >= 400:
            o.box(rug, int(rx0), int(rx1), y, y + LIP, int(rz0), int(rz1), "interior",
                  "floor.rug")
            laid.append(o.pieces[-1])
    return laid
def rug_tex(theme, pal, contract):
    for k in ((pal or {}).get("carpet"), (pal or {}).get("awning"), "carpet"):
        if k and k in kit.textures():
            return k
    return None
