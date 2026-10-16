import random
from . import contract, interiors, kit, roofs, soft64
C = 200
STOREY = 600
DOOR_H = 400
DOOR_W = 400
PLINTH_H = 200
PROUD = 100
FACADE_T = 20
TRIM_T = 40
WALL_T = 200
EAVE = 200
GABLE = 100
FLOOR_T = 20
FRONT = 600
REACH_SAFE = 700
CLIMB_MAX = 350
FLIGHT_RISE, FLIGHT_RUN = 200, 400
PARAPET_H = 160
WINDOW_W = 400
WINDOW_SILL, WINDOW_HEAD = 200, 400
FOOTPRINTS = ((4, 4), (5, 4), (4, 5), (6, 4), (4, 6), (6, 5), (5, 6), (6, 6), (7, 5), (5, 7),
              (7, 6), (6, 7), (8, 6), (6, 8), (8, 8))
INTENTS = ("climbable", "out_of_reach", "vantage")
FIVE = ("plinth", "walls", "roof", "door", "chimney")
WINDOW_WALLS = {
    "wincottage": ("plastercream", "plasterochre", "plastersage", "plasterpink"),
    "winshutter": ("plasterwhite", "brwhite", "adobewhite"),
    "winshop": ("plastercream", "plasterwhite"),
    "winstone": ("cutpanel", "cutsmooth", "sbwarm", "castlesand"),
    "winround": ("castlelight", "cutfluted", "sblight", "cutsmooth"),
    "winarched": ("brreddark", "brredworn", "brred", "brickscorched"),
}
DOOR_WALLS = {
    "doorplank": ("plastercream", "plasterwhite", "plasterochre", "sandstonecut"),
    "doorstudded": ("sblarge", "sbgrey", "castlegrey", "castlelight"),
    "doordouble": ("brredworn", "brred", "brreddark"),
    "doorarched": ("cutpanel", "cutsmooth", "sbwarm"),
}
FUNCTIONS = {
    "home": ((400, 200, 200),),
    "forge": ((400, 400, 200),),
    "shop": ((600, 200, 200),),
    "chapel": ((400, 200, 200),),
    "barn": ((200, 200, 200), (200, 400, 200)),
    "tavern": ((400, 200, 200), (400, 200, 200)),
}
def lum(key):
    try:
        _, entry = contract._lib_entry(key)
    except Exception:
        entry = None
    return (entry or {}).get("lum")
def _k(lib_key):
    k = soft64.to_kit(lib_key)
    return k if k and k in kit.textures() else None
def _lib_key(kit_key):
    if not kit_key:
        return None
    for s64, key in soft64.keymap().items():
        if key == kit_key:
            return s64
    return kit_key
def _ok(theme, cls, key, kind=None):
    return (key is not None and key in kit.textures() and contract.ok(theme, cls, key)
            and (kind is None or kit.comes_in(key, kind)))
def _darker(theme, cls, cands, than, by, kind=None):
    ok = []
    for c in cands:
        if c and c not in ok and _ok(theme, cls, c, kind):
            ok.append(c)
    if not ok:
        return None
    if than is None:
        return ok[0]
    for c in ok:
        v = lum(c)
        if v is not None and v <= than - by:
            return c
    return min(ok, key=lambda c: (lum(c) if lum(c) is not None else 1.0))
def _with_role(role):
    return [k for k, v in sorted(kit.textures().items()) if role in (v.get("roles") or ())]
def _roof_culture(culture, r):
    if culture == "roofsouth":
        return ("gable" if r.random() < 0.7 else "hip"), "low", False
    if culture == "roofeast":
        return "hip", "low", False
    if culture == "rooftropic":
        return "pyramid", "steep", False
    if culture == "roofmetal":
        return "gable", "low", r.random() < 0.5
    return "gable", ("steep" if r.random() < 0.6 else "low"), True
def style_for(theme, pal, r, settlement="S1"):
    b = soft64.buildings(theme) or soft64.buildings("village") or {}
    pal = pal or {}
    ws = b.get("wood_set") or {}
    window, window_alt, door = b.get("window"), b.get("window_alt"), b.get("door")
    win_walls = [_k(x) for x in WINDOW_WALLS.get(_lib_key(window), ())]
    door_walls = [_k(x) for x in DOOR_WALLS.get(_lib_key(door), ())]
    order = []
    for c in win_walls + [b.get("facade_wall")] + door_walls + \
            [pal.get("building"), pal.get("wall"), ws.get("planks"),
             contract.material(theme, "building_wall", pal, ("building", "wall"), kind="box")]:
        if c and c not in order and _ok(theme, "building_wall", c, "box"):
            order.append(c)
    cands = list(order)
    roof_vals = [lum(x) for x in list(b.get("roofs") or []) + [pal.get("roof")]
                 if x and lum(x) is not None]
    darkest = min(roof_vals) if roof_vals else None
    def roof_reads(c):
        v = lum(c)
        return v is None or darkest is None or v - darkest >= 0.15
    wall = next((c for c in order if roof_reads(c)), order[0] if order else None) \
        or pal.get("building") or pal.get("wall")
    if wall not in cands:
        cands = [wall] + cands
    fam = contract.family(wall)
    wl = lum(wall)
    same = []
    for m in [c for c in cands if c != wall] + contract.members(theme, "building_wall", "box"):
        if len(same) >= 3:
            break
        if contract.family(m) != fam or m in same or m == wall or not roof_reads(m):
            continue
        v = lum(m)
        if v is not None and wl is not None and abs(v - wl) <= 0.12:
            same.append(m)
    base_c = [pal.get("wall_base"), pal.get("keel")] + \
        contract.members(theme, "building_wall", "box")
    stone = [c for c in base_c if c and contract.family(c) in ("masonry", "brick", "rock")]
    base = _darker(theme, "building_wall", stone, wl, 0.12, "box") or \
        _darker(theme, "building_wall", base_c, wl, 0.12, "box") or wall
    if lum(base) is not None and wl is not None and lum(base) > wl - 0.05:
        base = _darker(theme, "building_wall", base_c, wl, 0.12, "box") or base
    chimney = b.get("small_brick") if _ok(theme, "building_wall", b.get("small_brick"), "box") \
        else base
    roofs = list(b.get("roofs") or []) + [pal.get("roof"), pal.get("roof_alt")]
    roof = _darker(theme, "roof", roofs, wl, 0.15, "ridge") or \
        contract.material(theme, "roof", pal, ("roof",), kind="ridge")
    roof_alt = next((x for x in roofs if x and x != roof and _ok(theme, "roof", x, "ridge")
                     and (lum(x) or 0) <= (wl or 1) - 0.1), roof)
    culture = next((t for t in (kit.textures().get(roof) or {}).get("roles", ())
                    if t.startswith("roof") and t != "roof"), "roofnorth")
    trims = [ws.get("beam"), _k("beamdark"), _k("beamoak"), pal.get("trim"), ws.get("stripped"),
             base]
    trim = next((t for t in trims if _ok(theme, "trim", t, "box") and lum(t) is not None
                 and wl is not None and abs(lum(t) - wl) >= 0.15), None) or \
        next((t for t in trims if _ok(theme, "trim", t, "box")), base)
    door_top = (door + "top") if door and (door + "top") in kit.textures() else door
    wdoor = ws.get("door") if ws.get("door") in kit.textures() else None
    wdoor_top = ws.get("door_top") if ws.get("door_top") in kit.textures() else wdoor
    upper = b.get("facade_wall") if _ok(theme, "building_wall", b.get("facade_wall"), "box") \
        else None
    shop = b.get("shop") if b.get("shop") in kit.textures() else None
    planks = ws.get("planks") if ws.get("planks") in kit.textures() else (pal.get("deck") or base)
    log_end = ws.get("log_end") if ws.get("log_end") in kit.textures() else planks
    log_side = ws.get("bark") if ws.get("bark") in kit.textures() and log_end != planks else None
    acc = [a for a in (pal.get("accents_built") or pal.get("accents") or [])
           if a in kit.textures() and contract.family(a) not in ("foliage", "fabric", "ground")]
    awning = contract.material(theme, "awning", pal, ("awning",), kind="ramp")
    rails = [k for k in _with_role("rail") if kit.comes_in(k, "box")]
    wood_wall = planks if _ok(theme, "building_wall", planks, "box") else wall
    form, pitch, gts = _roof_culture(culture, r)
    st = {
        "theme": theme, "settlement": settlement, "wall": wall, "wall_alt": same[:3],
        "family": fam, "base": base, "chimney": chimney, "trim": trim, "roof": roof,
        "roof_alt": roof_alt, "culture": culture, "roof_form": form, "pitch": pitch,
        "gable_to_street": gts, "overhang": EAVE, "window": window,
        "window_alt": window_alt or window, "door": door, "door_top": door_top,
        "wood_door": wdoor, "wood_door_top": wdoor_top, "shop": shop, "upper": upper,
        "floor": planks, "planks": planks, "wood_wall": wood_wall, "log_end": log_end, "log_side": log_side,
        "accent": acc[0] if acc else None, "awning": awning,
        "rail": rails[0] if rails else trim,
        "path": pal.get("path") or pal.get("road"),
        "rug": interiors.rug_tex(theme, pal, contract),
    }
    st["values"] = values_of(st)
    return st
def values_of(st):
    w = lum(st["wall"])
    def d(k):
        v = lum(st.get(k)) if st.get(k) else None
        return None if v is None or w is None else round(w - v, 3)
    t, dr = d("trim"), d("door")
    return {"wall": w, "roof_under_wall": d("roof"), "base_under_wall": d("base"),
            "trim_from_wall": None if t is None else abs(t),
            "door_from_wall": None if dr is None else abs(dr)}
RECORD_KEYS = ("settlement", "wall", "wall_alt", "family", "base", "roof", "roof_alt", "culture",
               "roof_form", "pitch", "gable_to_street", "overhang", "window", "window_alt",
               "door", "door_top", "shop", "upper", "trim", "chimney", "accent")
def record(st):
    return {k: st.get(k) for k in RECORD_KEYS}
class Body:
    def __init__(self, x0, x1, z0, z1, y, n):
        self.x0, self.x1, self.z0, self.z1, self.y, self.n = x0, x1, z0, z1, y, n
    @property
    def top(self):
        return self.y + self.n * STOREY
    @property
    def w(self):
        return self.x1 - self.x0
    @property
    def d(self):
        return self.z1 - self.z0
class Out:
    def __init__(self, tag):
        self.tag = tag
        self.pieces = []
        self.parts = {}
    def add(self, kind, tex, x0, x1, y0, y1, z0, z1, rises=None, part="walls", word=None):
        if x1 - x0 <= 0 or y1 - y0 <= 0 or z1 - z0 <= 0 or not tex:
            return None
        p = kit.kind(kind).make(tex, x0, x1, y0, y1, z0, z1, rises,
                                "%s.%s" % (self.tag, word or part))
        self.pieces.append(p)
        self.parts[part] = self.parts.get(part, 0) + 1
        return p
    def box(self, tex, x0, x1, y0, y1, z0, z1, part="walls", word=None):
        return self.add("box", tex, x0, x1, y0, y1, z0, z1, None, part, word)
def _snap(v, g=C):
    return int(round(v / float(g))) * g
def _fit(lot, side, back, front=FRONT, sizes=FOOTPRINTS, cap=None, low=None):
    best = None
    for w, d in sizes:
        if cap and (w > cap[0] or d > cap[1]):
            continue
        if low and (w < low[0] or d < low[1]):
            continue
        if w * C + 2 * side <= lot[0] and d * C + back + front <= lot[1]:
            if best is None or w * d > best[0] * best[1]:
                best = (w, d)
    return best
def _body(lot, wc, dc, n, front=FRONT, y=PLINTH_H, dx=0):
    bw, bd = wc * C, dc * C
    x0 = _snap(-bw / 2.0, 100) + dx
    z1 = lot[1] // 2 - front
    return Body(x0, x0 + bw, z1 - bd, z1, y, n)
def _mid(a, b):
    return _snap((a + b) / 2.0, 100)
def plinth(o, st, b, tex=None, extra=(0, 0, 0, 0)):
    o.box(tex or st["base"], b.x0 - PROUD - extra[0], b.x1 + PROUD + extra[1],
          b.y - PLINTH_H, b.y, b.z0 - PROUD - extra[2], b.z1 + PROUD + extra[3], part="plinth",
          word="plinth")
def band(o, tex, b, face, a0, a1, y0, y1, word="facade.window"):
    if a1 - a0 < C or not tex:
        return None
    if face == "front":
        return o.box(tex, a0, a1, y0, y1, b.z1, b.z1 + FACADE_T, "facade", word)
    if face == "back":
        return o.box(tex, a0, a1, y0, y1, b.z0 - FACADE_T, b.z0, "facade", word)
    if face == "left":
        return o.box(tex, b.x0 - FACADE_T, b.x0, y0, y1, a0, a1, "facade", word)
    return o.box(tex, b.x1, b.x1 + FACADE_T, y0, y1, a0, a1, "facade", word)
def _span(b, face, inset=C):
    if face in ("front", "back"):
        return b.x0 + inset, b.x1 - inset
    return b.z0 + inset, b.z1 - inset
def runs(lo, hi, cuts):
    out = [(lo, hi)]
    for c0, c1 in cuts:
        nxt = []
        for a, z in out:
            if c1 <= a or z <= c0:
                nxt.append((a, z))
                continue
            if c0 > a:
                nxt.append((a, c0))
            if c1 < z:
                nxt.append((c1, z))
        out = nxt
    clean = []
    for a, z in out:
        z = a + (z - a) // C * C
        if z - a >= C:
            clean.append((a, z))
    return clean
def windows(o, st, b, storey, faces, cuts=None, tex=None, alt=None):
    y0 = b.y + storey * STOREY + C
    for face in faces:
        lo, hi = _span(b, face)
        t = (alt if face == "back" and alt else tex) or st["window"]
        for a0, a1 in runs(lo, hi, (cuts or {}).get(face, [])):
            band(o, t, b, face, a0, a1, y0, y0 + C)
def door_solid(o, st, b, lo=None, up=None, hood=True, x=0):
    lo = lo or st.get("door")
    up = up or st.get("door_top") or lo
    x0, x1 = x - C // 2, x + C // 2
    o.box(lo, x0, x1, b.y, b.y + C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    o.box(up, x0, x1, b.y + C, b.y + 2 * C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    if hood:
        o.box(st["trim"], x0 - 100, x1 + 100, b.y + 2 * C, b.y + STOREY, b.z1,
              b.z1 + TRIM_T, "door", "trim")
    o.box(st["base"], x0 - 100, x1 + 100, b.y - PLINTH_H, b.y, b.z1 + PROUD, b.z1 + PROUD + C,
          "step", "stoop")
    return (x, b.z1 + PROUD + C + 100), (x0 - C, x1 + C)
def door_open(o, st, b, face="front", arched=False):
    g0, g1 = -DOOR_W // 2, DOOR_W // 2
    y = b.y
    zc = _mid(b.z0, b.z1)
    if face == "front":
        o.add("stairs", st["base"], g0, g1, y - PLINTH_H, y, b.z1 + PROUD,
              b.z1 + PROUD + FLIGHT_RUN, "-z", "step", "steps")
        pt = (0, b.z1 + PROUD + FLIGHT_RUN + 100)
        lintel = (g0, g1, b.z1 - WALL_T, b.z1)
        cut = (g0 - C, g1 + C)
    elif face == "back":
        o.add("stairs", st["base"], g0, g1, y - PLINTH_H, y, b.z0 - PROUD - FLIGHT_RUN,
              b.z0 - PROUD, "+z", "step", "steps")
        pt = (0, b.z0 - PROUD - FLIGHT_RUN - 100)
        lintel = (g0, g1, b.z0, b.z0 + WALL_T)
        cut = (g0 - C, g1 + C)
    else:
        o.add("stairs", st["base"], b.x0 - PROUD - FLIGHT_RUN, b.x0 - PROUD, y - PLINTH_H, y,
              zc + g0, zc + g1, "+x", "step", "steps")
        pt = (b.x0 - PROUD - FLIGHT_RUN - 100, zc)
        lintel = (b.x0, b.x0 + WALL_T, zc + g0, zc + g1)
        cut = (zc + g0 - C, zc + g1 + C)
    x0, x1, z0, z1 = lintel
    if arched and face != "left" and kit.comes_in(st["wall"], "arch"):
        o.add("arch", st["wall"], x0, x1, y + DOOR_H, y + STOREY, z0, z1, None, "door", "lintel")
    else:
        o.box(st["trim"], x0, x1, y + DOOR_H, y + STOREY, z0, z1, "door", "trim")
    return pt, cut
def open_walls(o, st, b, doors=("front",), tex=None, windows=()):
    tex = tex or st["wall"]
    y0, y1 = b.y, b.y + STOREY
    g0, g1 = -DOOR_W // 2, DOOR_W // 2
    for face, (zz0, zz1) in (("front", (b.z1 - WALL_T, b.z1)), ("back", (b.z0, b.z0 + WALL_T))):
        if face in doors:
            o.box(tex, b.x0, g0, y0, y1, zz0, zz1, "walls", "wall")
            o.box(tex, g1, b.x1, y0, y1, zz0, zz1, "walls", "wall")
        else:
            o.box(tex, b.x0, b.x1, y0, y1, zz0, zz1, "walls", "wall")
    zc = _mid(b.z0, b.z1)
    for face, (xx0, xx1) in (("left", (b.x0, b.x0 + WALL_T)), ("right", (b.x1 - WALL_T, b.x1))):
        if face in doors:
            o.box(tex, xx0, xx1, y0, y1, b.z0 + WALL_T, zc + g0, "walls", "wall")
            o.box(tex, xx0, xx1, y0, y1, zc + g1, b.z1 - WALL_T, "walls", "wall")
        elif face in windows and zc - WINDOW_W // 2 - C >= b.z0 + WALL_T:
            w0, w1 = zc - WINDOW_W // 2, zc + WINDOW_W // 2
            o.box(tex, xx0, xx1, y0, y1, b.z0 + WALL_T, w0, "walls", "wall")
            o.box(tex, xx0, xx1, y0, y1, w1, b.z1 - WALL_T, "walls", "wall")
            o.box(st["trim"], xx0, xx1, y0, y0 + WINDOW_SILL, w0, w1, "walls", "sill")
            o.box(tex, xx0, xx1, y0 + WINDOW_HEAD, y1, w0, w1, "walls", "lintel")
        else:
            o.box(tex, xx0, xx1, y0, y1, b.z0 + WALL_T, b.z1 - WALL_T, "walls", "wall")
def interior(o, st, b, function="home", side="left", doors=("front",)):
    fx0, fx1 = b.x0 + WALL_T, b.x1 - WALL_T
    fz0, fz1 = b.z0 + WALL_T, b.z1 - WALL_T
    o.box(st["floor"], fx0, fx1, b.y, b.y + FLOOR_T, fz0, fz1, "interior", "floor")
    y = b.y + FLOOR_T
    tex = st["base"] if function == "forge" else st["planks"]
    x = fx0 if side == "left" else fx1
    for w, h, d in FUNCTIONS.get(function, FUNCTIONS["home"]):
        z0 = fz0
        if z0 + w > fz1 - 2 * C:
            break
        if side == "left":
            if x + d > fx1 - 2 * C:
                break
            o.box(tex, x, x + d, y, y + h, z0, z0 + w, "interior", function)
            x += d + C
        else:
            if x - d < fx0 + 2 * C:
                break
            o.box(tex, x - d, x, y, y + h, z0, z0 + w, "interior", function)
            x -= d + C
    taken = []
    for p in o.pieces:
        if p["tag"].endswith(".interior.%s" % function) or p["tag"].endswith("." + function):
            if p["y"] == y:
                taken.append((p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0,
                              p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0))
    interiors.furnish(o, st, (fx0, fx1, fz0, fz1), y, function, doors, taken,
                      theme=st.get("theme"))
def roof(o, st, b, form=None, along=None, pitch=None, eave=EAVE, gable=GABLE, cut=None,
         tex=None, word="roof", board=True):
    form = form or st["roof_form"]
    pitch = pitch or st["pitch"]
    tex = tex or st["roof"]
    if form not in roofs.FORMS:
        form = "gable"
    if form == "gable":
        along = along or ("x" if b.w >= b.d else "z")
    elif form != "shed":
        along = None
    x0, x1, z0, z1 = roofs.outline(b.x0, b.x1, b.z0, b.z1, form, along, eave, gable, cut)
    trim = st.get("trim") if board and st.get("detail") != "lean" else None
    specs, top = roofs.pieces(form, tex, x0, x1, z0, z1, b.top, along=along, pitch=pitch,
                              trim=trim, finial=st.get("trim"))
    for sp in specs:
        part = "roof" if sp.word.startswith(("roof", "trim", "finial")) else "walls"
        w = word if sp.word == "roof" else sp.word
        o.add(sp[0], sp[1], sp[2], sp[3], sp[4], sp[5], sp[6], sp[7], sp[8], part, w)
    return top
def chimney(o, st, rect, end, y0, ridge_top, aside=False, y1=None, deep=PROUD):
    x0, x1, z0, z1 = rect
    y1 = ridge_top + C if y1 is None else y1
    zc, xc = _mid(z0, z1), _mid(x0, x1)
    if aside:
        xc, zc = x0 + C + C // 2, z0 + C + C // 2
    if end == "x1":
        o.box(st["chimney"], x1, x1 + deep, y0, y1, zc - C // 2, zc + C // 2, "chimney", "chimney")
    elif end == "x0":
        o.box(st["chimney"], x0 - deep, x0, y0, y1, zc - C // 2, zc + C // 2, "chimney", "chimney")
    elif end == "z0":
        o.box(st["chimney"], xc - C // 2, xc + C // 2, y0, y1, z0 - deep, z0, "chimney", "chimney")
    else:
        o.box(st["chimney"], xc - C // 2, xc + C // 2, y0, y1, z1, z1 + deep, "chimney", "chimney")
def parapets(o, st, x0, x1, z0, z1, y, gaps=()):
    t = 60
    tex = st["rail"] if kit.comes_in(st["rail"], "rail") else st["trim"]
    edges = {"front": (x0, x1), "back": (x0, x1), "left": (z0 + t, z1 - t),
             "right": (z0 + t, z1 - t)}
    for face, (lo, hi) in edges.items():
        cuts = [(a0, a1) for f, a0, a1 in gaps if f == face]
        segs = [(lo, hi)]
        for c0, c1 in cuts:
            nxt = []
            for a, z in segs:
                if c1 <= a or z <= c0:
                    nxt.append((a, z))
                    continue
                if c0 > a:
                    nxt.append((a, c0))
                if c1 < z:
                    nxt.append((c1, z))
            segs = nxt
        for a, z in segs:
            if z - a < C:
                continue
            if face == "front":
                o.add("rail", tex, a, z, y, y + PARAPET_H, z1 - t, z1, None, "roof", "parapet")
            elif face == "back":
                o.add("rail", tex, a, z, y, y + PARAPET_H, z0, z0 + t, None, "roof", "parapet")
            elif face == "left":
                o.add("rail", tex, x0, x0 + t, y, y + PARAPET_H, a, z, None, "roof", "parapet")
            else:
                o.add("rail", tex, x1 - t, x1, y, y + PARAPET_H, a, z, None, "roof", "parapet")
class Building(dict):
    pass
def _finish(o, recipe, b, intent, enterable, openings, door_pt, top, notes=(), **more):
    from . import v1
    m = v1.arenas_module()
    rects = [m.footprint(p) for p in o.pieces]
    out = Building(recipe=recipe, pieces=o.pieces, parts=dict(o.parts), intent=intent,
                   storeys=b.n if b else 0, eave=b.top if b else top, top=top,
                   floor=b.y if b else 0, enterable=enterable, openings=openings,
                   door=door_pt, notes=list(notes),
                   foot=(min(r[0] for r in rects), max(r[1] for r in rects),
                         min(r[2] for r in rects), max(r[3] for r in rects)),
                   body=(b.x0, b.x1, b.z0, b.z1) if b else None)
    out.update(more)
    return out
def _storeys(intent):
    return 2 if intent == "out_of_reach" else 1
def _wall_of(st, r):
    if st["wall_alt"] and r.random() < 0.4:
        return r.choice(st["wall_alt"])
    return st["wall"]
def _place(lot, fit, left, right, n, front=FRONT, y=PLINTH_H):
    lw, ld = lot
    bw, bd = fit[0] * C, fit[1] * C
    slack = lw - left - right - bw
    x0 = _snap(-lw / 2.0 + left + slack / 2.0, 100)
    z1 = ld // 2 - front
    return Body(x0, x0 + bw, z1 - bd, z1, y, n)
LOG_END = 20
def _woodpile(o, st, x0, x1, y0, y1, z0, z1, end):
    side = st.get("log_side") or st["log_end"]
    t = LOG_END
    if side == st["log_end"]:
        o.box(st["log_end"], x0, x1, y0, y1, z0, z1, "climb", "woodpile")
        return
    if end == "+z":
        o.box(side, x0, x1, y0, y1, z0, z1 - t, "climb", "woodpile")
        o.box(st["log_end"], x0, x1, y0, y1, z1 - t, z1, "climb", "woodpile.ends")
    elif end == "-z":
        o.box(side, x0, x1, y0, y1, z0 + t, z1, "climb", "woodpile")
        o.box(st["log_end"], x0, x1, y0, y1, z0, z0 + t, "climb", "woodpile.ends")
    elif end == "+x":
        o.box(side, x0, x1 - t, y0, y1, z0, z1, "climb", "woodpile")
        o.box(st["log_end"], x1 - t, x1, y0, y1, z0, z1, "climb", "woodpile.ends")
    else:
        o.box(side, x0 + t, x1, y0, y1, z0, z1, "climb", "woodpile")
        o.box(st["log_end"], x0, x0 + t, y0, y1, z0, z1, "climb", "woodpile.ends")
def _aid(o, st, xa0, za, eave, ground=0, xa1=None, base=PLINTH_H):
    xa1 = xa0 + C if xa1 is None else xa1
    top = (eave - ground - 300) // 50 * 50
    if top - base > CLIMB_MAX or eave - ground - top > CLIMB_MAX:
        return False
    _woodpile(o, st, xa0, xa1, ground, ground + top, za - C, za + C, "+x")
    return True
def _aid_side(o, st, b, zc, eave):
    pile = (eave - 300) // 50 * 50
    _woodpile(o, st, b.x1, b.x1 + EAVE + PROUD, b.y, pile, zc - C, zc + C, "+z")
def _aid_front(o, st, b):
    top = (b.top - 300) // 50 * 50
    if top - b.y > CLIMB_MAX or b.top - top > CLIMB_MAX:
        return False
    x1 = b.x1
    if x1 - C < C:
        return False
    _woodpile(o, st, x1 - C, x1, b.y, top, b.z1, b.z1 + EAVE + PROUD, "+x")
    return True
FACE_OF = {"x0": "left", "x1": "right", "z0": "back", "z1": "front"}
def cottage(st, lot, r, intent="climbable", enterable=False, openings=1, function="home",
            tag="house", variant="H1"):
    wing, jetty, chalet = variant == "H3", variant == "H4", variant == "H5"
    if jetty:
        intent = "out_of_reach"
    if intent == "vantage":
        intent = "climbable"
    climb = intent == "climbable"
    n = _storeys(intent)
    along = "z" if (st["gable_to_street"] or chalet or wing) else "x"
    form = "gable" if (climb or wing or jetty or chalet) else st["roof_form"]
    if form not in ("gable", "hip", "pyramid"):
        form = "gable"
    over = PROUD if jetty else 0
    second = ("back" if wing else "left") if (enterable and openings >= 2) else None
    if along == "x":
        chim = "x1" if second == "left" else "x0"
        left = C + over
        right = C + over
        back = C + over
    else:
        chim = "z0"
        left = C + over
        right = C + over
        back = C
    if wing:
        left = C
        right = 2 * C + C // 2
    if second == "left":
        left = max(left, 3 * C)
    if second == "back":
        back = FRONT
    low = (7, 7) if enterable else None
    cap = (8, 8) if enterable else (6, 6)
    fit = _fit(lot, (left + right) / 2.0, back, cap=cap, low=low)
    if fit is None and enterable:
        fit = _fit(lot, (left + right) / 2.0, back, cap=cap, low=(6, 6))
    if fit is None:
        return None
    b = _place(lot, fit, left, right, n)
    if form == "pyramid" and b.w != b.d:
        form = "hip"
    o = Out(tag)
    notes = []
    wall = st["wood_wall"] if chalet else _wall_of(st, r)
    stw = dict(st, wall=wall)
    plinth(o, stw, b, extra=(0, 2 * C if wing else 0, 0, 0))
    cuts = {}
    if enterable:
        doors = ("front", second) if second else ("front",)
        lit = [f for f in ("left", "right") if f not in doors and FACE_OF[chim] != f]
        open_walls(o, stw, b, doors=doors, windows=lit)
        for f in lit:
            cuts[f] = [(b.z0, b.z1)]
        door_pt, cut = door_open(o, stw, b, "front",
                                 arched=stw["family"] == "masonry" and r.random() < 0.5)
        cuts["front"] = [cut]
        if second:
            cuts[second] = [door_open(o, stw, b, second)[1]]
        interior(o, stw, b, function, side="right" if second == "left" else "left",
                 doors=("front", second) if second else ("front",))
        if n > 1:
            _upper(o, stw, Body(b.x0, b.x1, b.z0, b.z1, b.y + STOREY, n - 1), jetty)
    else:
        if jetty:
            o.box(wall, b.x0, b.x1, b.y, b.y + STOREY, b.z0, b.z1, "walls", "wall")
            _upper(o, stw, Body(b.x0, b.x1, b.z0, b.z1, b.y + STOREY, n - 1), True)
        else:
            o.box(wall, b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
        lo, up = (st.get("wood_door"), st.get("wood_door_top")) if chalet else (None, None)
        door_pt, cut = door_solid(o, stw, b, lo, up)
        cuts["front"] = [cut]
    faces = [f for f in ("front", "back", "left", "right") if f != FACE_OF[chim]]
    if wing and "right" in faces:
        faces.remove("right")
    if st.get("detail") == "lean":
        faces = [f for f in faces if f == "front"] or faces[:1]
    windows(o, stw, Body(b.x0, b.x1, b.z0, b.z1, b.y, 1), 0, faces, cuts,
            alt=st.get("window_alt"))
    if not jetty:
        for s in range(1, n):
            windows(o, stw, b, s, faces, alt=st.get("window_alt"))
    rb = Body(b.x0 - over, b.x1 + over, b.z0 - over, b.z1 + over, b.y, n)
    cut_faces = [chim] + (["x1"] if wing else [])
    pitch = "steep" if (jetty or chalet) else st["pitch"]
    ridge_top = roof(o, stw, rb, form=form, along=along, pitch=pitch,
                     gable=(300 if chalet else GABLE), cut=cut_faces)
    aside = second == "back" and chim == "z0"
    if jetty:
        chimney(o, stw, (rb.x0, rb.x1, rb.z0, rb.z1), chim, b.y + STOREY, ridge_top, aside)
        zs = chim in ("z0", "z1")
        chimney(o, stw, (rb.x0, rb.x1, b.z0, b.z1) if zs else (b.x0, b.x1, rb.z0, rb.z1), chim,
                b.y, 0, aside, y1=b.y + STOREY, deep=over + PROUD)
    else:
        chimney(o, stw, (b.x0, b.x1, b.z0, b.z1), chim, b.y, ridge_top, aside)
    if wing:
        _wing(o, stw, b)
    if climb:
        if not _aid_front(o, stw, b):
            notes.append("no woodpile fits")
    recipe = "H5" if chalet else "H4" if jetty else "H3" if wing else "H1"
    return _finish(o, recipe, b, intent, enterable, openings if enterable else 0, door_pt,
                   ridge_top, notes, function=function if enterable else None, along=along,
                   chimney=chim, form=form)
def _upper(o, st, up, jetty):
    if jetty and st.get("upper"):
        o.box(st["upper"], up.x0 - PROUD, up.x1 + PROUD, up.y, up.top, up.z0 - PROUD,
              up.z1 + PROUD, "walls", "jetty")
    elif jetty:
        o.box(st["wall"], up.x0 - PROUD, up.x1 + PROUD, up.y, up.top, up.z0 - PROUD,
              up.z1 + PROUD, "walls", "jetty")
    else:
        o.box(st["wall"], up.x0, up.x1, up.y, up.top, up.z0, up.z1, "walls", "wall")
def _wing(o, st, b):
    x0, x1 = b.x1, b.x1 + 2 * C
    z0 = b.z0
    z1 = b.z0 + max(2 * C, (b.d // 2) // C * C)
    y = b.y + STOREY
    o.box(st["wall"], x0, x1, b.y, y, z0, z1, "walls", "wing")
    span = (z1 + EAVE) - (z0 - EAVE)
    h = max(C, span // 4 // 50 * 50)
    o.add("ridge", st["roof_alt"] or st["roof"], x0, x1, y, y + h, z0 - EAVE, z1 + EAVE, "x",
          "roof", "roof")
def townhouses(st, lot, r, intent="out_of_reach", tag="house"):
    lw, ld = lot
    depth = min(6, (ld - C - FRONT) // C)
    if depth < 4:
        return None
    uw = 4 if lw >= 2 * 4 * C + 2 * C else 3
    count = min(4, (lw - 2 * C) // (uw * C))
    if count < 2:
        return None
    o = Out(tag)
    z1 = ld // 2 - FRONT
    z0 = z1 - depth * C
    xs0 = _snap(-(count * uw * C) / 2.0 - C / 2.0, 100)
    x = xs0
    colours = [st["wall"]] + list(st["wall_alt"])
    intent = "out_of_reach"
    base_n = 2
    flat = st["culture"] == "roofsouth" and r.random() < 0.35
    plinth(o, st, Body(xs0, xs0 + count * uw * C, z0, z1, PLINTH_H, base_n))
    tops, ns = [], []
    door_pt = None
    last = base_n
    for k in range(count):
        n = base_n + (1 if r.random() < 0.35 else 0)
        if abs(n - last) > 1:
            n = last
        last = n
        ns.append(n)
        u = Body(x, x + uw * C, z0, z1, PLINTH_H, n)
        o.box(colours[k % len(colours)], u.x0, u.x1, u.y, u.top, u.z0, u.z1, "walls", "wall")
        dx = u.x0 + C if k % 2 == 0 else u.x1 - 2 * C
        o.box(st["door"], dx, dx + C, u.y, u.y + C, u.z1, u.z1 + FACADE_T, "door", "facade.door")
        o.box(st["door_top"], dx, dx + C, u.y + C, u.y + 2 * C, u.z1, u.z1 + FACADE_T, "door",
              "facade.door")
        if st.get("shop") and uw >= 4:
            s0 = dx + 2 * C if k % 2 == 0 else dx - 2 * C
            band(o, st["shop"], u, "front", s0, s0 + C, u.y, u.y + C, word="facade.shop")
        for s in range(1, n):
            y0 = u.y + s * STOREY + C
            band(o, st["window"] if s % 2 else st["window_alt"], u, "front", u.x0 + C,
                 u.x1 - C, y0, y0 + C)
        if flat:
            parapets(o, st, u.x0, u.x1, u.z0, u.z1, u.top,
                     gaps=[("left", u.z0, u.z1), ("right", u.z0, u.z1)])
            tops.append(u.top + PARAPET_H)
        else:
            h = max(C, ((depth * C + 2 * EAVE) // 4) // 50 * 50)
            o.add("ridge", st["roof"], u.x0, u.x1, u.top, u.top + h, u.z0 - EAVE, u.z1 + EAVE,
                  "x", "roof", "roof")
            tops.append(u.top + h)
        if door_pt is None:
            door_pt = (dx + C // 2, z1 + PROUD + C + 100)
            o.box(st["base"], dx - C // 2, dx + C + C // 2, 0, PLINTH_H, z1 + PROUD,
                  z1 + PROUD + C, "step", "stoop")
        x += uw * C
    chimney(o, st, (xs0, x, z0, z1), "x1", PLINTH_H, max(tops))
    b = Body(xs0, x, z0, z1, PLINTH_H, min(ns))
    return _finish(o, "H2", b, intent, False, 0, door_pt, max(tops), units=count, each=ns,
                   flat=flat)
def cube_house(st, lot, r, intent="vantage", tag="house"):
    fit = _fit(lot, (C + 3 * C) / 2.0, C, low=(5, 8), cap=(7, 8))
    if fit is None:
        return None
    b = _place(lot, fit, C, 3 * C, 1)
    o = Out(tag)
    stw = dict(st, wall=_wall_of(st, r))
    o.box(st["base"], b.x0 - PROUD, b.x1, 0, PLINTH_H, b.z0 - PROUD, b.z1 + PROUD, "plinth",
          "plinth")
    o.box(stw["wall"], b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
    door_pt, cut = door_solid(o, stw, b, hood=False)
    if st.get("awning"):
        o.add("ramp", st["awning"], -C - 100, C + 100, b.y + 2 * C, b.y + 2 * C + 100, b.z1,
              b.z1 + 300, "-z", "door", "awning.roof")
    windows(o, stw, b, 0, ["front", "back", "left"], {"front": [cut]}, alt=st.get("window_alt"))
    run = 300
    nfl = b.top // FLIGHT_RISE
    xs0, xs1 = b.x1, b.x1 + 2 * C - 60
    half = nfl // 2
    o.box(st["base"], xs1, xs1 + 60, 0, half * FLIGHT_RISE, b.z1 - half * run, b.z1, "stair",
          "cheek")
    o.box(st["base"], xs1, xs1 + 60, 0, nfl * FLIGHT_RISE, b.z1 - nfl * run, b.z1 - half * run,
          "stair", "cheek")
    for k in range(nfl):
        fz1 = b.z1 - k * run
        fz0 = fz1 - run
        yk = k * FLIGHT_RISE
        if yk:
            o.box(st["base"], xs0, xs1, 0, yk, fz0, fz1, "stair", "stair")
        o.add("stairs", st["base"], xs0, xs1, yk, yk + FLIGHT_RISE, fz0, fz1, "-z", "stair",
              "stair")
    lz1 = b.z1 - nfl * run
    lz0 = max(b.z0, lz1 - 2 * C)
    o.box(st["base"], xs0, xs1 + 60, 0, b.top, lz0, lz1, "stair", "landing")
    parapets(o, stw, b.x0, b.x1, b.z0, b.z1, b.top, gaps=[("right", lz0, lz1)])
    o.box(st["chimney"], b.x0 + 60, b.x0 + 60 + C, b.top, b.top + 2 * C, b.z0 + 60,
          b.z0 + 60 + C,
          "chimney", "chimney")
    return _finish(o, "H6", b, "vantage", False, 0, door_pt, b.top + PARAPET_H, flat=True)
def dome_house(st, lot, r, intent="out_of_reach", tag="house"):
    n = 2 if intent != "climbable" else 1
    right = C if n > 1 else 2 * C
    fit = _fit(lot, (C + right) / 2.0, C, sizes=[s for s in FOOTPRINTS if s[0] == s[1]],
               cap=(6, 6))
    if fit is None:
        return None
    b = _place(lot, fit, C, right, n)
    o = Out(tag)
    stw = dict(st, wall=_wall_of(st, r))
    plinth(o, stw, b)
    o.box(stw["wall"], b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
    door_pt, cut = door_solid(o, stw, b)
    windows(o, stw, b, 0, ["front", "back", "left"] + ([] if n == 1 else ["right"]), {"front": [cut]},
            alt=st.get("window_alt"))
    for s in range(1, n):
        windows(o, stw, b, s, ["front", "back", "left", "right"], alt=st.get("window_alt"))
    y = b.top
    xc, zc = _mid(b.x0, b.x1), _mid(b.z0, b.z1)
    for w, h in ((b.w, 3 * C // 2), (_snap(b.w * 2 / 3.0, 100), C), (_snap(b.w / 3.0, 100), C)):
        if w < C:
            break
        o.add("pillar", st["roof"] if kit.comes_in(st["roof"], "pillar") else stw["wall"],
              xc - w // 2, xc + w // 2, y, y + h, zc - w // 2, zc + w // 2, None, "roof", "dome")
        y += h
    acc = st.get("accent") if st.get("accent") and kit.comes_in(st["accent"], "pillar") \
        else st["trim"]
    o.add("pillar", acc, xc - 50, xc + 50, y, y + C, zc - 50, zc + 50, None, "roof", "accent")
    if n == 1:
        _aid_side(o, stw, b, zc, b.top)
    return _finish(o, "H7", b, "climbable" if n == 1 else intent, False, 0, door_pt, y + C,
                   ["a dome has no stack"])
def stilt_hut(st, lot, r, intent="out_of_reach", tag="house"):
    lw, ld = lot
    if lw < 5 * C or ld < 2 * (4 * C + 2 * FLIGHT_RUN + C // 2 + 100) - 2 * (2 * FLIGHT_RUN + 100):
        return None
    o = Out(tag)
    dh = 4 * C // 2 * 2
    x0, x1 = -dh // 2, dh // 2
    z1 = ld // 2 - 2 * FLIGHT_RUN - 100
    z0 = z1 - dh
    deck_y = 2 * FLIGHT_RISE
    post = st["trim"] if kit.comes_in(st["trim"], "pillar") else st["base"]
    for px in (x0 + 50, x1 - 50):
        for pz in (z0 + 50, z1 - 50):
            o.add("pillar", post, px - 50, px + 50, 0, deck_y, pz - 50, pz + 50, None, "plinth",
                  "stilt")
    o.box(st["planks"], x0, x1, deck_y, deck_y + 40, z0, z1, "plinth", "deck")
    fy = deck_y + 40
    hb = Body(x0 + C, x1 - C, z0 + C, z1 - C, fy, 1)
    hut_top = fy + 4 * C
    o.box(st["wood_wall"], hb.x0, hb.x1, fy, hut_top, hb.z0, hb.z1, "walls", "wall")
    o.box(st.get("wood_door") or st["door"], -C // 2, C // 2, fy, fy + C, hb.z1, hb.z1 + FACADE_T,
          "door", "facade.door")
    o.box(st.get("wood_door_top") or st["door_top"], -C // 2, C // 2, fy + C, fy + 2 * C, hb.z1,
          hb.z1 + FACADE_T, "door", "facade.door")
    rtex = st["roof"]
    o.add("pyramid", rtex, x0 - C // 2, x1 + C // 2, hut_top, hut_top + 2 * C, z0 - C // 2,
          z1 + C // 2, "x", "roof", "roof")
    o.box(st["base"], -C, C, 0, FLIGHT_RISE, z1, z1 + FLIGHT_RUN, "step", "stair")
    o.add("stairs", st["base"], -C, C, FLIGHT_RISE, deck_y + 40, z1, z1 + FLIGHT_RUN, "-z",
          "step", "steps")
    for x0 in (-C - 60, C):
        o.box(st["base"], x0, x0 + 60, 0, deck_y + 40, z1, z1 + FLIGHT_RUN, "step", "cheek")
    o.add("stairs", st["base"], -C, C, 0, FLIGHT_RISE, z1 + FLIGHT_RUN, z1 + 2 * FLIGHT_RUN,
          "-z", "step", "steps")
    b = Body(hb.x0, hb.x1, hb.z0, hb.z1, fy, 1)
    b.n = 1
    out = _finish(o, "H8", b, "out_of_reach", False, 0, (0, z1 + 2 * FLIGHT_RUN + 100),
                  hut_top + 2 * C, ["stilts for a plinth, no stack (a hut)"])
    out["eave"] = hut_top
    out["launch"] = deck_y + 40
    return out
def japanese_house(st, lot, r, intent="climbable", tag="house"):
    fit = _fit(lot, 3 * C, 2 * C, cap=(6, 6), front=FRONT + C)
    if fit is None:
        return None
    b = _place(lot, fit, 2 * C, 4 * C, 1, front=FRONT + C)
    o = Out(tag)
    wall = st["wood_wall"]
    o.box(st["base"], b.x0 - C, b.x1 + C, 0, PLINTH_H, b.z0 - C, b.z1 + C, "plinth", "platform")
    o.box(wall, b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
    lo, up = st.get("wood_door") or st["door"], st.get("wood_door_top") or st["door_top"]
    o.box(lo, -C // 2, C // 2, b.y, b.y + C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    o.box(up, -C // 2, C // 2, b.y + C, b.y + 2 * C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    o.add("stairs", st["base"], -C, C, 0, PLINTH_H, b.z1 + C, b.z1 + C + FLIGHT_RUN, "-z", "step",
          "steps")
    post = st["trim"] if kit.comes_in(st["trim"], "pillar") else wall
    for px in (b.x0 - C + 50, b.x1 + C - 50):
        for pz in (b.z0 - C + 50, b.z1 + C - 50):
            o.add("pillar", post, px - 50, px + 50, b.y, b.top, pz - 50, pz + 50, None, "walls",
                  "post")
    eave = C + 100
    ridge_top = roof(o, st, b, form="hip", pitch="low", eave=eave)
    zc = _mid(b.z0, b.z1)
    _aid(o, st, b.x1 + C, zc, b.top, xa1=b.x1 + eave + C)
    return _finish(o, "H9", b, "climbable", False, 0, (0, b.z1 + C + FLIGHT_RUN + 100), ridge_top,
                   ["a veranda roof, no stack"])
def stall(st, lot, r, tag="stall"):
    o = Out(tag)
    o.box(st["planks"], -3 * C // 2, 3 * C // 2, 0, C, 0, C, "walls", "counter")
    post = st["trim"] if kit.comes_in(st["trim"], "pillar") else st["planks"]
    for px in (-3 * C // 2 + 50, 3 * C // 2 - 50):
        o.add("pillar", post, px - 50, px + 50, 0, 5 * C // 2, -C - 100, -C, None, "walls", "post")
    o.add("ramp", st["awning"] or st["roof"], -2 * C, 2 * C, 5 * C // 2, 3 * C, -C - 100, 2 * C,
          "-z", "roof", "awning.roof")
    b = Body(-3 * C // 2, 3 * C // 2, 0, C, 0, 1)
    return _finish(o, "H10", b, "climbable", False, 0, (0, 3 * C), 3 * C)
def barn(st, lot, r, intent="climbable", tag="barn"):
    fit = _fit(lot, (C + 2 * C) / 2.0, C, cap=(6, 8), low=(5, 6))
    if fit is None:
        return None
    b = _place(lot, fit, C, 2 * C, 1)
    o = Out(tag)
    wall = st["wood_wall"]
    stw = dict(st, wall=wall)
    plinth(o, stw, b)
    o.box(wall, b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
    lo = st.get("wood_door") or st["door"]
    up = st.get("wood_door_top") or st["door_top"]
    o.box(lo, -C, C, b.y, b.y + C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    o.box(up, -C, C, b.y + C, b.y + 2 * C, b.z1, b.z1 + FACADE_T, "door", "facade.door")
    o.box(st["trim"], -C - 100, C + 100, b.y + 2 * C, b.y + STOREY, b.z1, b.z1 + TRIM_T,
          "door", "trim")
    o.box(st["base"], -C - 100, C + 100, 0, PLINTH_H, b.z1 + PROUD, b.z1 + PROUD + C, "step",
          "stoop")
    top = b.top
    lower = 2 * C
    z0, z1 = b.z0, b.z1 + GABLE
    o.add("ramp", st["roof"], b.x0 - EAVE, b.x0 + C, top, top + lower, z0, z1, "+x", "roof", "roof")
    o.add("ramp", st["roof"], b.x1 - C, b.x1 + EAVE, top, top + lower, z0, z1, "-x", "roof", "roof")
    o.box(wall, b.x0 + C, b.x1 - C, top, top + lower, z0, z1, "roof", "attic")
    span = b.w - 2 * C
    h = max(C, span // 4 // 50 * 50)
    o.add("ridge", st["roof"], b.x0 + C, b.x1 - C, top + lower, top + lower + h, z0, z1, "z",
          "roof", "roof")
    acc = st.get("accent") or st["trim"]
    o.box(acc, -C // 2, C // 2, top + 50, top + 50 + C, z1, z1 + FACADE_T, "accent", "accent")
    _aid_side(o, st, b, _mid(b.z0, b.z1), top)
    return _finish(o, "H11", b, "climbable", False, 0, (0, b.z1 + PROUD + C + 100),
                   top + lower + h, ["a barn: no stack"])
def igloo(st, lot, r, tag="igloo"):
    o = Out(tag)
    tex = st["wall"]
    y = 0
    for w, h in ((4 * C, 3 * C // 2), (3 * C, C), (2 * C, C)):
        o.add("pillar", tex, -w // 2, w // 2, y, y + h, -w // 2, w // 2, None, "walls", "dome")
        y += h
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 100, sx * 160))
        o.box(tex, x0, x1, 0, 3 * C // 2, 2 * C - 40, 2 * C + 300, "walls", "tunnel")
    if kit.comes_in(tex, "arch"):
        o.add("arch", tex, -220, 220, 3 * C // 2, 5 * C // 2, 3 * C // 2, 2 * C + 300, None,
              "door", "arch")
    for p in o.pieces:
        p["z"] -= C
    b = Body(-2 * C, 2 * C, -3 * C, C, 0, 1)
    return _finish(o, "H12", b, "climbable", False, 0, (0, C + 400), y)
def perch(st, lot, r, tag="perch"):
    lw, ld = lot
    if ld < 2 * (2 * C + 2 * 250 + 100) or lw < 5 * C + C:
        return None
    o = Out(tag)
    post = st["trim"] if kit.comes_in(st["trim"], "pillar") else st["base"]
    o.add("pillar", post, -C // 2, C // 2, 0, 2 * C, -C // 2, C // 2, None, "plinth", "truss")
    deck = 2 * C + 40
    o.box(st["planks"], -2 * C, 2 * C, 2 * C, deck, -2 * C, 2 * C, "plinth", "deck")
    for px, pz in ((-3 * C // 2 + 50, -50), (3 * C // 2 - 50, -50)):
        o.add("pillar", post, px - 50, px + 50, deck, deck + 7 * C // 2, -C - 50 + pz,
              -C + 50 + pz, None, "walls", "post")
    for px in (-3 * C // 2 + 50, 3 * C // 2 - 50):
        o.add("pillar", post, px - 50, px + 50, deck, deck + 7 * C // 2, C - 50, C + 50, None,
              "walls", "post")
    top = deck + 7 * C // 2
    o.add("pyramid", st["roof"], -5 * C // 2, 5 * C // 2, top, top + 3 * C // 2, -5 * C // 2,
          5 * C // 2, "x", "roof", "roof")
    run = 250
    o.box(st["base"], -150, 150, 0, deck // 2, 2 * C, 2 * C + run, "step", "stair")
    o.add("stairs", st["base"], -150, 150, deck // 2, deck, 2 * C, 2 * C + run, "-z", "step",
          "steps")
    o.add("stairs", st["base"], -150, 150, 0, deck // 2, 2 * C + run, 2 * C + 2 * run, "-z",
          "step", "steps")
    for x0 in (-210, 150):
        o.box(st["base"], x0, x0 + 60, 0, deck, 2 * C, 2 * C + run, "step", "cheek")
    b = Body(-2 * C, 2 * C, -2 * C, 2 * C, deck, 1)
    out = _finish(o, "H13", b, "out_of_reach", False, 0, (0, 2 * C + 2 * run + 100),
                  top + 3 * C // 2, ["a perch: a deck for a plinth"])
    out["eave"] = top
    out["launch"] = deck
    return out
RECIPES = {
    "H1": ("cottage", (3, 4)),
    "H2": ("townhouses", (9, 5)),
    "H3": ("cottage", (6, 5)),
    "H4": ("cottage", (4, 5)),
    "H5": ("cottage", (4, 5)),
    "H6": ("cube_house", (5, 6)),
    "H7": ("dome_house", (4, 5)),
    "H8": ("stilt_hut", (4, 5)),
    "H9": ("japanese_house", (5, 5)),
    "H10": ("stall", (2, 2)),
    "H11": ("barn", (5, 6)),
    "H12": ("igloo", (3, 3)),
    "H13": ("perch", (3, 5)),
    "H14": ("tower", (5, 6)),
}
NAMES = {"H1": "cottage", "H2": "townhouse row", "H3": "L-house", "H4": "timber house",
         "H5": "chalet", "H6": "desert cube house", "H7": "dome house", "H8": "stilt hut",
         "H9": "Japanese house", "H10": "market stall", "H11": "barn", "H12": "igloo",
         "H13": "perch", "H14": "lookout tower"}
OPEN_LOT = (5, 6)
OPEN_LOT_TWO = (5, 6)
OPEN_LOTS = {"H3": ((7, 6), (7, 7)), "H4": ((6, 6), (6, 6))}
def lot_of(recipe, enterable=False, openings=1):
    if enterable:
        one, two = OPEN_LOTS.get(recipe, (OPEN_LOT, OPEN_LOT_TWO))
        return two if openings >= 2 else one
    return RECIPES[recipe][1]
FIVE_PART = ("H1", "H2", "H3", "H4", "H5")
def build(recipe, st, lot, r, intent="climbable", enterable=False, openings=1,
          function="home", tag="house"):
    if recipe in ("H1", "H3", "H4", "H5"):
        return cottage(st, lot, r, intent, enterable, openings, function, tag, recipe)
    if recipe == "H2":
        return townhouses(st, lot, r, intent, tag)
    if recipe == "H14":
        from . import towers
        return towers.tower(st, lot, r, intent, tag)
    if enterable and recipe not in ("H10", "H12", "H13"):
        return cottage(st, lot, r, intent, enterable, openings, function, tag, "H1")
    fn = {"H6": cube_house, "H7": dome_house, "H8": stilt_hut, "H9": japanese_house,
          "H11": barn}.get(recipe)
    if fn is not None:
        return fn(st, lot, r, intent, tag)
    fn = {"H10": stall, "H12": igloo, "H13": perch}[recipe]
    return fn(st, lot, r, tag)
QUARTERS = {"s": 0, "e": 1, "n": 2, "w": 3, "+z": 0, "+x": 1, "-z": 2, "-x": 3}
def place(building, cx, cz, y, face="s"):
    from . import v1
    m = v1.arenas_module()
    q = QUARTERS[face]
    out = []
    for p in building["pieces"]:
        t = m.turned(p, q)
        t["x"] += cx
        t["z"] += cz
        t["y"] += y
        out.append(t)
    return out
def turn_point(pt, face):
    x, z = pt
    for _ in range(QUARTERS[face]):
        x, z = z, -x
    return x, z
def turn_rect(rect, face):
    x0, x1, z0, z1 = rect
    pts = [turn_point((x0, z0), face), turn_point((x1, z1), face)]
    return (min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts),
            max(p[1] for p in pts))
def keys(pieces):
    return set("%s:%s:%d:%d:%d" % (p["kind"], kit.tex_key(p), round(p["w"]), round(p["h"]),
                                   round(p["d"])) for p in pieces)
def validate(b, st=None):
    from . import solids
    out = []
    ps = b["pieces"]
    for i, j, depth, faces in solids.overlaps(ps):
        out.append("3 overlap: %s and %s by %d" % (ps[i]["tag"], ps[j]["tag"], depth))
    for i, j, dist, normal, area in solids.face_pairs({"pieces": ps}):
        if i >= 0 and j >= 0:
            out.append("3 flicker: %s and %s (%d)" % (ps[i]["tag"], ps[j]["tag"], area))
    doors = [p for p in ps if p["tag"].endswith("facade.door")]
    if b["recipe"] not in ("H10", "H12", "H13") and not doors and not b.get("enterable"):
        out.append("1 no door")
    if doors and len(doors) % 2:
        out.append("1 a door of one cell (doors are two: the tile and its top)")
    if b.get("enterable"):
        if b["storeys"] < 1 or STOREY - FLOOR_T < 400:
            out.append("2 headroom under 400")
        if b.get("openings", 0) < 1:
            out.append("1 an enterable house without a doorway")
    out += roof_faults(b)
    if st is not None:
        th = st["theme"]
        for p in ps:
            cls = contract.object_class(p)
            if cls and contract.refused(cls, contract.family(p["tex"])):
                out.append("5 refused: %s wears %s" % (p["tag"], p["tex"]))
        v = st.get("values") or {}
        if v.get("roof_under_wall") is not None and v["roof_under_wall"] < 0.05:
            out.append("6 the roof is not darker than the wall (%.2f)" % v["roof_under_wall"])
        if v.get("base_under_wall") is not None and v["base_under_wall"] < 0.0:
            out.append("6 the plinth is lighter than the wall (%.2f)" % v["base_under_wall"])
        del th
    return out
def launch_tops(b):
    out = []
    for p in b["pieces"]:
        part = p["tag"].split(".")[-1]
        if part in ("plinth", "stoop", "steps", "stair", "landing", "deck", "platform",
                    "woodpile", "counter", "floor") or p["kind"] == "stairs":
            out.append(p["y"] + p["h"])
    return out
def roof_faults(b):
    tops = launch_tops(b)
    eave = b["eave"]
    hi = max(tops) if tops else 0
    if b["intent"] == "out_of_reach" and eave - hi < REACH_SAFE:
        return ["4 out of reach, but a launch top is %d under the eave (< %d)"
                % (eave - hi, REACH_SAFE)]
    if b["intent"] == "climbable" and b["recipe"] not in ("H10", "H12") and \
            eave - hi > CLIMB_MAX:
        return ["4 climbable, but the nearest launch top is %d under the eave (> %d)"
                % (eave - hi, CLIMB_MAX)]
    return []
def five_parts(b):
    have = b["parts"]
    return {k: bool(have.get(k)) or (k == "door" and bool(have.get("step")))
            for k in FIVE}
