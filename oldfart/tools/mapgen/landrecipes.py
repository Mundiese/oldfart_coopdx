from . import kit
CELL = 400
RECIPES = ("mesa", "arch", "waterfall", "dunes", "glacier", "rolling")
FEATURE_OF = {"mesa": "mesa", "natural_arch": "arch", "waterfall": "waterfall", "dunes": "dunes",
              "glacier": "glacier", "rolling_hills": "rolling"}
THEME_RECIPES = {
    "garden": ("arch", "waterfall"), "wood": ("waterfall", "arch"), "castle": ("arch", "waterfall"),
    "sky": ("arch", "waterfall"), "desert": ("mesa", "dunes", "arch"), "ice": ("glacier", "arch"),
    "lava": ("mesa", "arch"),
}
FOOT = {"mesa": (2, 2), "arch": (3, 1), "waterfall": (2, 3), "dunes": (3, 3)}
PIECES = {"mesa": 4, "arch": 3, "waterfall": 5, "dunes": 5, "glacier": 0, "rolling": 0}
def _box(t, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(t, int(x0), int(x1), int(y0), int(y1), int(z0), int(z1), None, tag)
def mesa(x0, z0, w, d, g, rnd, rock_lo, rock_hi, cap):
    x1, z1 = x0 + w * CELL, z0 + d * CELL
    lo = rnd.choice((400, 600))
    hi = rnd.choice((400, 600))
    out = [_box(rock_lo, x0, x1, g, g + lo, z0, z1, "landform.mesa"),
           _box(rock_hi, x0 + 100, x1 - 100, g + lo, g + lo + hi, z0 + 100, z1 - 100,
                "landform.mesa")]
    top = g + lo + hi
    out.append(_box(cap, x0, x1, top, top + 200, z0, z1, "landform.mesa.cap"))
    return out, top + 200
def arch(x0, z0, along_x, g, rnd, rock, lintel):
    h = rnd.choice((600, 800))
    t = rnd.choice((200, 400))
    if along_x:
        legs = ((x0, x0 + CELL), (x0 + 2 * CELL, x0 + 3 * CELL))
        out = [_box(rock, a, b, g, g + h, z0, z0 + CELL, "landform.arch") for a, b in legs]
        out.append(_box(lintel, x0, x0 + 3 * CELL, g + h, g + h + t, z0, z0 + CELL,
                        "landform.arch.lintel"))
    else:
        legs = ((z0, z0 + CELL), (z0 + 2 * CELL, z0 + 3 * CELL))
        out = [_box(rock, x0, x0 + CELL, g, g + h, a, b, "landform.arch") for a, b in legs]
        out.append(_box(lintel, x0, x0 + CELL, g + h, g + h + t, z0, z0 + 3 * CELL,
                        "landform.arch.lintel"))
    return out, g + h + t
def waterfall(x0, z0, g, rnd, rock, water, rim):
    h = rnd.choice((800, 1000, 1200))
    x1 = x0 + 2 * CELL
    face = z0 + CELL
    out = [_box(rock, x0, x1, g, g + h, z0, face, "landform.waterfall.cliff")]
    wtop = g + POOL_SURFACE
    fx0 = x0 + CELL // 2
    out.append(kit.kind("water").make(water, fx0, fx0 + CELL, wtop, g + h - 100, face,
                                      face + FALL_THICK, None, "landform.waterfall.fall"))
    pz1 = z0 + 3 * CELL
    for (a0, a1, b0, b1) in ((x0, x0 + 100, face, pz1), (x1 - 100, x1, face, pz1),
                             (x0 + 100, x1 - 100, pz1 - 100, pz1)):
        out.append(_box(rim, a0, a1, g, wtop + POOL_DROP, b0, b1, "landform.waterfall.rim"))
    sheet = kit.kind("water").make(water, x0 + 100, x1 - 100, wtop - 20, wtop, face,
                                   pz1 - 100, None, "landform.waterfall.pool")
    out.append(sheet)
    out.append(_box(rim, x0 + 100, x1 - 100, g, g + POOL_FLOOR, face, pz1 - 100,
                    "landform.waterfall.floor"))
    return out, [x0 + 100, face, x1 - 100, pz1 - 100, wtop, g]
POOL_SURFACE = 210
POOL_DROP = 40
POOL_FLOOR = 60
FALL_THICK = 20
def dunes(x0, z0, w, d, g, rnd, sand):
    out = []
    along_x = rnd.random() < 0.5
    rows = []
    span = d if along_x else w
    k = 0
    while k + 1 <= span:
        rows.append(k)
        k += 2
    for r in rows:
        length = rnd.choice((2, 3))
        width = 1
        run = w if along_x else d
        start = rnd.randint(0, max(0, run - length))
        h = 100 if width == 1 else 200
        if along_x:
            a0, a1 = x0 + start * CELL, x0 + (start + length) * CELL
            b0, b1 = z0 + r * CELL, z0 + (r + width) * CELL
            out.append(kit.kind("ridge").make(sand, a0, a1, g, g + h, b0, b1, "x", "landform.dunes"))
        else:
            a0, a1 = x0 + r * CELL, x0 + (r + width) * CELL
            b0, b1 = z0 + start * CELL, z0 + (start + length) * CELL
            out.append(kit.kind("ridge").make(sand, a0, a1, g, g + h, b0, b1, "z", "landform.dunes"))
    return out
def pick(theme, want, n, rnd):
    out = [r for f, r in sorted(FEATURE_OF.items()) if f in want]
    pool = [r for r in THEME_RECIPES.get(theme, THEME_RECIPES["garden"]) if r not in out]
    while len(out) < n and pool:
        out.append(pool.pop(0))
    return out
def site(cells, free, foot):
    w, d = foot
    for c in cells:
        for (a, b) in ((w, d), (d, w)):
            hs = set()
            ok = True
            for i in range(a):
                for j in range(b):
                    h = free((c[0] + i, c[1] + j))
                    if h is None:
                        ok = False
                        break
                    hs.add(h)
                if not ok:
                    break
            if ok and len(hs) == 1:
                return c, (a, b), hs.pop()
    return None
