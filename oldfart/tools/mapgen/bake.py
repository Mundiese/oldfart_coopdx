import math
CELL = 200
OFF = 40
NEAR = 90
FAR = 230
OUT = 200
DIAG = 0.7071
AO_K = 0.6
SUN_K = 0.60
EXTENT = 800.0
AO_LEAST = 0.25
SHADOW_STEP = 120
SHADOW_STEPS = 24
SHADOW_LIGHT = 0.25
RELIT_KEEP = 0.9
SHADE_TINT = (0.94, 0.97, 1.05)
PALETTES = {
    "default": {"sun": (0.36, 0.86, 0.36), "sunc": (1.0, 0.93, 0.80),
                "sky": (0.50, 0.50, 0.52), "gnd": (0.36, 0.33, 0.30),
                "lo": (0.84, 0.86, 1.0), "hi": (1.0, 0.95, 0.84)},
    "garden": {"sun": (0.40, 0.84, 0.36), "sunc": (1.0, 0.93, 0.78),
               "sky": (0.47, 0.50, 0.50), "gnd": (0.34, 0.38, 0.30),
               "lo": (0.80, 0.92, 0.84), "hi": (1.0, 0.96, 0.82)},
    "ice": {"sun": (-0.30, 0.62, 0.72), "sunc": (1.16, 1.14, 1.12),
            "sky": (0.41, 0.43, 0.46), "gnd": (0.37, 0.38, 0.41),
            "lo": (0.90, 0.94, 1.0), "hi": (1.0, 0.98, 0.94)},
    "desert": {"sun": (0.50, 0.80, 0.30), "sunc": (1.0, 0.91, 0.72),
               "sky": (0.54, 0.52, 0.52), "gnd": (0.50, 0.41, 0.31),
               "lo": (0.96, 0.84, 0.74), "hi": (1.0, 0.94, 0.80)},
    "lava": {"sun": (0.20, 0.70, -0.68), "sunc": (1.0, 0.80, 0.60),
             "sky": (0.44, 0.37, 0.38), "gnd": (0.50, 0.30, 0.22),
             "lo": (0.72, 0.62, 0.68), "hi": (1.0, 0.84, 0.62)},
    "castle": {"sun": (0.42, 0.78, 0.46), "sunc": (1.0, 0.91, 0.80),
               "sky": (0.48, 0.47, 0.50), "gnd": (0.35, 0.32, 0.33),
               "lo": (0.84, 0.84, 1.0), "hi": (1.0, 0.94, 0.84)},
    "wood": {"sun": (0.46, 0.80, 0.38), "sunc": (1.0, 0.90, 0.72),
             "sky": (0.47, 0.50, 0.53), "gnd": (0.40, 0.34, 0.30),
             "lo": (0.82, 0.90, 0.80), "hi": (1.0, 0.93, 0.78)},
    "sky": {"sun": (0.30, 0.90, 0.30), "sunc": (1.0, 0.97, 0.90),
            "sky": (0.50, 0.53, 0.58), "gnd": (0.40, 0.42, 0.47),
            "lo": (0.86, 0.90, 1.0), "hi": (1.0, 0.97, 0.90)},
}
LEGACY_PALETTES = {
    "default": {"sunc": (1.0, 0.95, 0.85), "sky": (0.60, 0.65, 0.76), "gnd": (0.44, 0.40, 0.34)},
    "garden": {"sunc": (1.0, 0.94, 0.80), "sky": (0.58, 0.66, 0.74), "gnd": (0.42, 0.46, 0.32)},
    "ice": {"sunc": (0.86, 0.92, 1.0), "sky": (0.60, 0.70, 0.86), "gnd": (0.52, 0.56, 0.66)},
    "desert": {"sunc": (1.0, 0.92, 0.74), "sky": (0.70, 0.68, 0.66), "gnd": (0.62, 0.50, 0.36)},
    "lava": {"sunc": (1.0, 0.66, 0.44), "sky": (0.56, 0.42, 0.44), "gnd": (0.70, 0.36, 0.24)},
    "castle": {"sunc": (1.0, 0.90, 0.80), "sky": (0.58, 0.58, 0.72), "gnd": (0.42, 0.38, 0.40)},
    "wood": {"sunc": (1.0, 0.90, 0.72), "sky": (0.60, 0.64, 0.70), "gnd": (0.48, 0.40, 0.30)},
    "sky": {"sunc": (1.0, 0.98, 0.92), "sky": (0.66, 0.74, 0.86), "gnd": (0.56, 0.58, 0.66)},
}
PALETTE_KEYS = ("sun", "sunc", "sky", "gnd")
PAINT_KEYS = ("lo", "hi")
WHITE = (1.0, 1.0, 1.0)
PAINT_GAIN = (0.55, 0.61, 0.67, 0.73, 0.79, 0.85, 0.90, 0.95, 1.0, 1.025, 1.05, 1.075,
              1.10, 1.125, 1.15, 1.18)
PAINT_STEPS = len(PAINT_GAIN)
PAINT_MID = 8
def palette(theme):
    p = PALETTES.get(theme) or PALETTES["default"]
    return {k: [float(c) for c in v] for k, v in p.items()}
def occluder(row):
    kind, model = row[0], str(row[1])
    if kind == "decor" or model == "none" or "invisible" in model or "water" in model:
        return None
    x, y, z, w, h, d = (float(v) for v in row[2:8])
    yaw = float(row[8]) if len(row) > 8 else 0.0
    q = yaw % 180.0
    if q == 90.0:
        w, d = d, w
    elif q != 0.0:
        w = d = max(w, d)
    return (x - w / 2.0, x + w / 2.0, y, y + h, z - d / 2.0, z + d / 2.0)
class Grid(object):
    def __init__(self, rows):
        self.boxes = []
        self.cells = {}
        self.top = None
        for row in rows:
            b = occluder(row)
            if b is None or b[1] <= b[0] or b[3] <= b[2] or b[5] <= b[4]:
                continue
            self.boxes.append(b)
            if self.top is None or b[3] > self.top:
                self.top = b[3]
            k = len(self.boxes) - 1
            for i in range(int(math.floor(b[0] / CELL)), int(math.floor((b[1] - 0.001) / CELL)) + 1):
                for j in range(int(math.floor(b[4] / CELL)),
                               int(math.floor((b[5] - 0.001) / CELL)) + 1):
                    self.cells.setdefault(i * 65536 + j, []).append(k)
    def solid(self, x, y, z):
        lst = self.cells.get(int(math.floor(x / CELL)) * 65536 + int(math.floor(z / CELL)))
        if not lst:
            return False
        for k in lst:
            b = self.boxes[k]
            if b[0] <= x < b[1] and b[2] <= y < b[3] and b[4] <= z < b[5]:
                return True
        return False
def occlusion(grid, x, y, z, nx, ny, nz):
    if abs(ny) > 0.9:
        t1 = (1.0, 0.0, 0.0)
        t2 = (0.0, 0.0, 1.0)
    else:
        t1 = (0.0, 1.0, 0.0)
        ln = math.sqrt(nz * nz + nx * nx)
        t2 = (-nz / ln, 0.0, nx / ln)
    bx, by, bz = x + nx * OFF, y + ny * OFF, z + nz * OFF
    hit = 0.0
    for s in (1.0, -1.0):
        for t in (t1, t2):
            if grid.solid(bx + t[0] * s * NEAR, by + t[1] * s * NEAR, bz + t[2] * s * NEAR):
                hit += 1.0
    for a in (DIAG, -DIAG):
        for b in (DIAG, -DIAG):
            dx = (t1[0] * a + t2[0] * b) * FAR
            dy = (t1[1] * a + t2[1] * b) * FAR
            dz = (t1[2] * a + t2[2] * b) * FAR
            if grid.solid(bx + dx, by + dy, bz + dz):
                hit += 0.5
    if grid.solid(bx + nx * OUT, by + ny * OUT, bz + nz * OUT):
        hit += 1.0
    return hit / 7.0
def shadowed(grid, x, y, z, nx, ny, nz, sx, sy, sz):
    if grid.top is None:
        return False
    bx, by, bz = x + nx * OFF, y + ny * OFF, z + nz * OFF
    for k in range(1, SHADOW_STEPS + 1):
        t = k * SHADOW_STEP
        py = by + sy * t
        if py >= grid.top:
            return False
        if grid.solid(bx + sx * t, py, bz + sz * t):
            return True
    return False
def _unit(v):
    ln = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if ln == 0:
        return (0.0, 1.0, 0.0)
    return (v[0] / ln, v[1] / ln, v[2] / ln)
def paint_mul(pal, paint):
    g = PAINT_GAIN[paint]
    if paint < PAINT_MID:
        w = (PAINT_MID - paint) / float(PAINT_MID)
        tint = pal.get("lo") or WHITE
    else:
        w = (paint - PAINT_MID) / float(PAINT_STEPS - 1 - PAINT_MID)
        tint = pal.get("hi") or WHITE
    return [g * (1.0 + (tint[c] - 1.0) * w) for c in range(3)]
def paint_step(gain):
    if gain <= 0:
        return 0
    lg = math.log(gain)
    best, at = None, PAINT_MID
    for i, g in enumerate(PAINT_GAIN):
        d = abs(lg - math.log(g))
        if best is None or d < best - 1e-12:
            best, at = d, i
    return at
def shade(pal, sun, n, ao, lit, paint=PAINT_MID):
    nx, ny, nz = n
    ndl = nx * sun[0] + ny * sun[1] + nz * sun[2]
    if ndl < 0:
        ndl = 0.0
    ndl = ndl * lit
    hemi = 0.5 + 0.5 * ny
    mul = paint_mul(pal, paint)
    out = []
    for c in range(3):
        amb = (pal["sky"][c] * hemi + pal["gnd"][c] * (1.0 - hemi)) * SHADE_TINT[c]
        v = amb * ao + pal["sunc"][c] * ndl * SUN_K * (0.55 + 0.45 * ao)
        v = v * mul[c]
        if v > 1.0:
            v = 1.0
        out.append(int(math.floor(v * 255.0 + 0.5)))
    return tuple(out)
def parts(grid, pal, x, y, z, nx, ny, nz, extent=None):
    nx, ny, nz = _unit((nx, ny, nz))
    k = AO_K
    big = 1.0
    if extent is not None and extent > EXTENT:
        big = max(AO_LEAST, EXTENT / extent)
        k = AO_K * big
    sx, sy, sz = _unit(pal["sun"])
    lit = 1.0
    if nx * sx + ny * sy + nz * sz > 0 and shadowed(grid, x, y, z, nx, ny, nz, sx, sy, sz):
        lit = 1.0 - (1.0 - SHADOW_LIGHT) * big
    ao = 1.0 - k * occlusion(grid, x, y, z, nx, ny, nz)
    return (nx, ny, nz), ao, lit
def colour(grid, pal, x, y, z, nx, ny, nz, extent=None):
    n, ao, lit = parts(grid, pal, x, y, z, nx, ny, nz, extent)
    return shade(pal, _unit(pal["sun"]), n, ao, lit)
def own_hour(pal, dir_):
    own = pal.get("hour") if isinstance(pal, dict) else None
    return own is not None and dir_ is not None and \
        all(abs(float(own[i]) - float(dir_[i])) < 1e-3 for i in range(3))
def relit(pal, dir_, n, ao, lit, paint=PAINT_MID):
    b = _unit(pal["sun"])
    if own_hour(pal, dir_):
        return shade(pal, b, _unit(n), ao, lit, paint)
    base = pal.get("sun0") or pal["sun"]
    s = _unit([base[i] + dir_[i] for i in range(3)])
    keep = s[0] * b[0] + s[1] * b[1] + s[2] * b[2] >= RELIT_KEEP
    return shade(pal, s, _unit(n), ao, lit if keep else 1.0, paint)
SKY_RAYS = 12
SKY_STEP = 150
SKY_REACH = 1800
SKY_AO_LEAST = 0.55
_SKY_DIRS = None
def _sky_dirs():
    global _SKY_DIRS
    if _SKY_DIRS is None:
        out = []
        for i in range(SKY_RAYS):
            if i < 8:
                az, el = i * 45.0, 30.0
            else:
                az, el = (i - 8) * 90.0 + 45.0, 65.0
            a, e = math.radians(az), math.radians(el)
            out.append((math.cos(e) * math.sin(a), math.sin(e), -math.cos(e) * math.cos(a)))
        _SKY_DIRS = tuple(out)
    return _SKY_DIRS
def sky_open(grid, x, y, z, nx, ny, nz):
    if grid.top is None:
        return 1.0
    bx, by, bz = x + nx * OFF, y + ny * OFF, z + nz * OFF
    free = total = 0
    for dx, dy, dz in _sky_dirs():
        if dx * nx + dy * ny + dz * nz <= 0.05:
            continue
        total += 1
        hit = False
        t = SKY_STEP
        while t <= SKY_REACH:
            py = by + dy * t
            if py >= grid.top:
                break
            if grid.solid(bx + dx * t, py, bz + dz * t):
                hit = True
                break
            t += SKY_STEP
        if not hit:
            free += 1
    if total == 0:
        return 0.5
    return free / float(total)
def sky_ao(ao, sky):
    return max(1.0 - AO_K, ao * (SKY_AO_LEAST + (1.0 - SKY_AO_LEAST) * sky))
def _hash01(i, j, seed):
    h = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFF) / 65535.0
def value_noise(x, z, wave, seed=0):
    fx, fz = x / float(wave), z / float(wave)
    i, j = int(math.floor(fx)), int(math.floor(fz))
    tx, tz = fx - i, fz - j
    tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
    a, b = _hash01(i, j, seed), _hash01(i + 1, j, seed)
    c, d = _hash01(i, j + 1, seed), _hash01(i + 1, j + 1, seed)
    top = a + (b - a) * tx
    bot = c + (d - c) * tx
    return (top + (bot - top) * tz) * 2.0 - 1.0
def macro(x, z):
    return (value_noise(x, z, 2400.0, 1) * 0.72 + value_noise(x, z, 900.0, 2) * 0.28)
def smoothstep(a, b, v):
    if b <= a:
        return 1.0 if v >= b else 0.0
    t = (v - a) / (b - a)
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return t * t * (3.0 - 2.0 * t)
ROLE_GAIN = {
    "ground": (1.0, 0.95, 0.88),
    "masonry": (1.03, 0.95, 0.88),
    "wood": (1.0, 0.95, 0.88),
    "roof": (1.0, 0.97, 0.88),
    "detail": (1.0, 0.97, 0.90),
}
HEIGHT_LO, HEIGHT_HI = 0.90, 1.06
HEIGHT_SPAN = (800.0, 2400.0)
FOOT_LO, FOOT_RISE = 0.80, 300.0
FOOT_PROBE = 600
MACRO_K = (0.11, 0.03)
CROWN_LO, CROWN_HI = 0.97, 1.17
class Painter(object):
    def __init__(self, grid, tops, hero=None):
        self.grid = grid
        ts = sorted(tops) or [0.0]
        self.y_lo = ts[int(0.10 * (len(ts) - 1))]
        span = ts[int(0.95 * (len(ts) - 1))] - self.y_lo
        self.y_hi = self.y_lo + min(HEIGHT_SPAN[1], max(HEIGHT_SPAN[0], span))
        self.hero = hero
    def ground_below(self, x, y, z, n):
        bx, bz = x + n[0] * OFF, z + n[2] * OFF
        d = 10.0
        while d <= FOOT_PROBE:
            if self.grid.solid(bx, y - d, bz):
                return d
            d += 50.0
        return None
    def gain(self, x, y, z, n, role="ground", hero=False):
        nx, ny, nz = n
        top, side, under = ROLE_GAIN.get(role, ROLE_GAIN["detail"])
        if ny > 0.5:
            g = top
        elif ny < -0.5:
            g = under
        else:
            g = side
        g *= HEIGHT_LO + (HEIGHT_HI - HEIGHT_LO) * smoothstep(self.y_lo, self.y_hi, y)
        if ny <= 0.5:
            d = self.ground_below(x, y, z, n)
            if d is not None:
                g *= FOOT_LO + (1.0 - FOOT_LO) * smoothstep(0.0, FOOT_RISE, d)
        k = MACRO_K[0] if role == "ground" else MACRO_K[1]
        g *= 1.0 + k * macro(x, z)
        if hero and self.hero is not None:
            base, crown = self.hero[0], self.hero[1]
            g *= CROWN_LO + (CROWN_HI - CROWN_LO) * smoothstep(base, crown, y)
        return g
    def step(self, x, y, z, n, role="ground", hero=False):
        return paint_step(self.gain(x, y, z, n, role, hero))
def current(b):
    if not isinstance(b, dict) or any(not isinstance(b.get(k), (list, tuple)) or len(b[k]) != 3
                                      for k in ("sky", "gnd")):
        return b
    for theme, old in LEGACY_PALETTES.items():
        k = float(b["sky"][0]) / old["sky"][0]
        if all(abs(float(b[key][c]) - old[key][c] * k) <= 0.002
               for key in ("sky", "gnd") for c in range(3)):
            new = PALETTES[theme]
            out = dict(b)
            out["sky"] = [round(c * k, 4) for c in new["sky"]]
            out["gnd"] = [round(c * k, 4) for c in new["gnd"]]
            for key in PAINT_KEYS:
                out.setdefault(key, list(new[key]))
            sunc = b.get("sunc")
            if isinstance(sunc, (list, tuple)) and len(sunc) == 3 \
                    and all(abs(float(sunc[c]) - old["sunc"][c]) <= 0.002 for c in range(3)):
                out["sunc"] = list(new["sunc"])
            return out
    return b
def look_palette(look, theme=None):
    if isinstance(look, dict) and "bake" in look:
        b = look["bake"]
        if b is False:
            return None
        if isinstance(b, dict):
            b = current(b)
            base = palette(theme)
            for k in PALETTE_KEYS + PAINT_KEYS:
                if isinstance(b.get(k), (list, tuple)) and len(b[k]) == 3:
                    base[k] = [float(c) for c in b[k]]
            return base
    return palette(theme)
def lua_table(pal):
    def three(v):
        return "{ %s }" % ", ".join(("%.3f" % c).rstrip("0").rstrip(".") or "0" for c in v)
    keys = PALETTE_KEYS + tuple(k for k in PAINT_KEYS if k in pal)
    return "{ %s }" % ", ".join("%s = %s" % (k, three(pal[k])) for k in keys)
def rows_of(arena):
    from . import v1
    m = v1.arenas_module()
    out = []
    for p in arena.get("pieces", []):
        kind = "decor" if p.get("decor") and p.get("pass") else p["kind"]
        try:
            model = m.row_model(p)
        except Exception:
            model = p.get("model") or "none"
        if p.get("tex") == "invisible":
            model = "none"
        if p.get("water") or p.get("tex", "").startswith("water"):
            model = "water"
        out.append((kind, model, p["x"], p["y"], p["z"], p["w"], p["h"], p["d"],
                    p.get("yaw", 0) or 0))
    return out
SUN_EL_MIN = 5.0
SUN_STRENGTH_MAX = 2.0
SUN_AMBIENT_MAX = 1.5
PRESETS = {
    "morning": {"az": 100.0, "el": 18.0, "colour": [1.0, 0.85, 0.65], "strength": 0.95,
                "ambient": 0.9},
    "noon": {"az": 160.0, "el": 75.0, "colour": [1.0, 0.98, 0.92], "strength": 1.1,
             "ambient": 1.0},
    "sunset": {"az": 260.0, "el": 8.0, "colour": [1.0, 0.6, 0.35], "strength": 1.0,
               "ambient": 0.8},
    "night": {"az": 300.0, "el": 40.0, "colour": [0.55, 0.65, 1.0], "strength": 0.5,
              "ambient": 0.6},
}
PRESET_ORDER = ("morning", "noon", "sunset", "night")
def sun_dir(az, el):
    a, e = math.radians(float(az)), math.radians(float(el))
    return (math.cos(e) * math.sin(a), math.sin(e), -math.cos(e) * math.cos(a))
def sun_angles(v):
    x, y, z = _unit(v)
    el = math.degrees(math.asin(max(-1.0, min(1.0, y))))
    az = math.degrees(math.atan2(x, -z)) % 360.0 if abs(x) + abs(z) > 1e-9 else 0.0
    return az, el
def clean_sun(sun):
    if not isinstance(sun, dict):
        return None
    try:
        az = float(sun.get("az", 0.0)) % 360.0
        el = min(90.0, max(SUN_EL_MIN, float(sun.get("el", 45.0))))
        col = [min(1.0, max(0.0, float(c))) for c in (sun.get("colour") or (1.0, 1.0, 1.0))]
        k = min(SUN_STRENGTH_MAX, max(0.0, float(sun.get("strength", 1.0))))
        amb = min(SUN_AMBIENT_MAX, max(0.0, float(sun.get("ambient", 1.0))))
    except (TypeError, ValueError):
        return None
    if len(col) != 3:
        return None
    return {"az": round(az, 2), "el": round(el, 2), "colour": [round(c, 3) for c in col],
            "strength": round(k, 3), "ambient": round(amb, 3)}
def sun_of(look, theme=None):
    own = clean_sun(look.get("sun")) if isinstance(look, dict) else None
    if own is not None:
        return own
    pal = look_palette(look, theme) or palette(theme)
    az, el = sun_angles(pal["sun"])
    k = max(pal["sunc"]) or 1.0
    return {"az": round(az, 2), "el": round(el, 2),
            "colour": [round(c / k, 3) for c in pal["sunc"]], "strength": round(k, 3),
            "ambient": 1.0}
def sun_palette(look, theme=None):
    pal = look_palette(look, theme) or palette(theme)
    own = clean_sun(look.get("sun")) if isinstance(look, dict) else None
    if own is None:
        return pal
    pal = dict(pal)
    pal["sun"] = [round(c, 4) for c in sun_dir(own["az"], own["el"])]
    pal["sunc"] = [round(c * own["strength"], 4) for c in own["colour"]]
    if own["ambient"] != 1.0:
        pal["sky"] = [round(c * own["ambient"], 4) for c in pal["sky"]]
        pal["gnd"] = [round(c * own["ambient"], 4) for c in pal["gnd"]]
    return pal
def fold_hour(look):
    if not isinstance(look, dict) or look.get("hourBaked") is not None:
        return look
    b = look.get("bake")
    if not isinstance(b, dict) or not isinstance(b.get("sun"), (list, tuple)) or len(b["sun"]) != 3:
        return look
    mood = look.get("mood") if isinstance(look.get("mood"), dict) else {}
    name = mood.get("hour")
    for pair in look.get("visuals") or []:
        if name is None and isinstance(pair, (list, tuple)) and len(pair) == 2 and pair[0] == "sun":
            name = pair[1]
    if not isinstance(name, str):
        return look
    from . import modpack
    stop = modpack.stop_of("sun", name) or {}
    d = stop.get("dir")
    if not isinstance(d, (list, tuple)) or len(d) != 3 or not any(float(c) for c in d):
        return look
    out = dict(look)
    nb = dict(b)
    nb["sun0"] = [float(c) for c in b["sun"]]
    nb["sun"] = [round(float(b["sun"][i]) + float(d[i]), 4) for i in range(3)]
    out["bake"] = nb
    out["hourBaked"] = [float(c) for c in d]
    return out
def export_look(look, theme=None):
    if not isinstance(look, dict) or clean_sun(look.get("sun")) is None:
        return look
    if look.get("bake") is False:
        return look
    out = dict(look)
    out["bake"] = {k: list(v) for k, v in sun_palette(look, theme).items()}
    return out
