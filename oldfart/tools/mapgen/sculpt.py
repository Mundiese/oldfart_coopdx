import math
TEX_UNIT = 32 * 32 / 200.0
SHAPES = ("none", "cap", "under", "stem", "spot", "isle", "rock", "cloud", "sheet")
def _h(seed, *xs):
    v = int(seed) * 374761393
    for x in xs:
        v = (v ^ (int(x) * 668265263 + 0x5bd1e995)) & 0xffffffff
        v = (v * 2246822519 + 3266489917) & 0xffffffff
    v ^= v >> 15
    return (v & 0xffffff) / float(0x1000000)
def _wave(seed, phi, waves=((3, 0.10), (5, 0.06), (8, 0.03))):
    out = 0.0
    for k, (n, a) in enumerate(waves):
        out += a * math.sin(n * phi + 6.283 * _h(seed, k, n))
    return out
def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def _unit(v):
    n = math.sqrt(_dot(v, v))
    return (0.0, 1.0, 0.0) if n < 1e-9 else (v[0] / n, v[1] / n, v[2] / n)
_swatches = {}
SWATCH = 6
def swatch(slug, tone, picture):
    key = (slug, tuple(tone))
    if key in _swatches:
        return _swatches[key]
    got = None
    png = picture(slug) if picture else None
    if png:
        import io
        from PIL import Image
        im = Image.open(io.BytesIO(png)).convert("RGB")
        W, H = im.size
        px = im.load()
        best = None
        for y in range(0, H - SWATCH + 1):
            for x in range(0, W - SWATCH + 1):
                cs = [px[x + i, y + j] for i in range(SWATCH) for j in range(SWATCH)]
                m = [sum(c[k] for c in cs) / float(len(cs)) for k in range(3)]
                var = sum((c[k] - m[k]) ** 2 for c in cs for k in range(3)) / len(cs)
                off = sum((m[k] - tone[k]) ** 2 for k in range(3))
                score = off + 2.0 * var
                if best is None or score < best[0]:
                    best = (score, x, y)
        _, x, y = best
        got = (x + 1, y + 1, x + SWATCH - 1, y + SWATCH - 1)
    _swatches[key] = got
    return got
def swatch_colour(slug, tone, picture):
    win = swatch(slug, tone, picture)
    if win is None:
        return None
    import io
    from PIL import Image
    im = Image.open(io.BytesIO(picture(slug))).convert("RGB")
    cs = [im.getpixel((x, y)) for x in range(win[0], win[2]) for y in range(win[1], win[3])]
    return tuple(int(sum(c[k] for c in cs) / len(cs)) for k in range(3))
class Mesh(object):
    def __init__(self):
        self.tris = []
    def grid(self, P, tex_of, out_of, closed=True, uv=None):
        rows, cols = len(P), len(P[0])
        span = cols if closed else cols - 1
        fn = {}
        for i in range(rows - 1):
            for j in range(span):
                a, b = P[i][j], P[i][(j + 1) % cols]
                c, d = P[i + 1][(j + 1) % cols], P[i + 1][j]
                n = _cross(_sub(c, a), _sub(d, b))
                fn[(i, j)] = n
        flip = 0.0
        for (i, j), n in fn.items():
            p = P[i][j]
            flip += _dot(_unit(n), _sub(p, out_of(p)))
        sign = 1.0 if flip >= 0 else -1.0
        vn = {}
        for (i, j), n in fn.items():
            n = (n[0] * sign, n[1] * sign, n[2] * sign)
            for v in ((i, j), (i, (j + 1) % cols), (i + 1, (j + 1) % cols), (i + 1, j)):
                vn[v] = tuple(a + b for a, b in zip(vn.get(v, (0.0, 0.0, 0.0)), _unit(n)))
        for (i, j), n in fn.items():
            j1 = (j + 1) % cols
            quad = [(i, j), (i, j1), (i + 1, j1), (i + 1, j)]
            if sign < 0:
                quad = quad[::-1]
            pts = [(P[a][b], _unit(vn[(a, b)])) for a, b in quad]
            tex = tex_of(i, j)
            for tri in ((pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])):
                ab = _cross(_sub(tri[1][0], tri[0][0]), _sub(tri[2][0], tri[1][0]))
                if _dot(ab, ab) < 1e-6:
                    continue
                self.tris.append((tri, tex, uv))
        return self
    def fan(self, centre, ring, tex, normal_up=True, uv=None):
        n = len(ring)
        for j in range(n):
            a, b = ring[j], ring[(j + 1) % n]
            tri = (centre, a, b)
            fnrm = _cross(_sub(tri[1], tri[0]), _sub(tri[2], tri[1]))
            if (fnrm[1] > 0) != normal_up:
                tri = (centre, b, a)
                fnrm = (-fnrm[0], -fnrm[1], -fnrm[2])
            u = _unit(fnrm)
            self.tris.append((tuple((p, u) for p in tri), tex, uv))
        return self
def _uv(p, n, mode, win):
    if win is not None:
        fx = 0.5 + 0.35 * math.sin(p[0] * 0.013 + p[2] * 0.007)
        fy = 0.5 + 0.35 * math.sin(p[2] * 0.011 - p[1] * 0.009)
        return ((win[0] + (win[2] - win[0]) * fx) * 32.0, (win[1] + (win[3] - win[1]) * fy) * 32.0)
    if isinstance(mode, tuple) and mode[0] == "side":
        u = p[2] if abs(n[0]) >= abs(n[2]) else p[0]
        return u * TEX_UNIT, (mode[4] - p[1]) * TEX_UNIT
    if abs(n[1]) >= 0.7:
        return p[0] * TEX_UNIT, p[2] * TEX_UNIT
    if abs(n[0]) >= abs(n[2]):
        return p[2] * TEX_UNIT, -p[1] * TEX_UNIT
    return p[0] * TEX_UNIT, -p[1] * TEX_UNIT
def _layer(n, layered):
    if not layered:
        return 0
    return 0 if n[1] > 0.5 else (2 if n[1] < -0.5 else 1)
def _cap(piece, sp, tex, M):
    cx, cz = piece["x"], piece["z"]
    R = float(sp["r"])
    rim = float(sp.get("rim", piece["y"]))
    top = float(sp.get("top", piece["y"] + piece["h"]))
    H = max(40.0, top - rim)
    lip = float(sp.get("lip", min(120.0, H * 0.4)))
    segs = int(sp.get("segs", 16))
    prof = []
    for deg in (0, 16, 30, 43, 55, 66, 76, 84, 90):
        th = math.radians(deg)
        prof.append((R * math.sin(th), rim + H * math.cos(th) ** 0.55))
    prof += [(R * 1.0, rim - lip * 0.45), (R * 0.97, rim - lip * 0.85), (R * 0.9, rim - lip)]
    P = []
    for r, y in prof:
        row = []
        for j in range(segs):
            phi = 2 * math.pi * j / segs
            row.append((cx + r * math.cos(phi), y, cz + r * math.sin(phi)))
        P.append(row)
    M.grid(P, lambda i, j: tex, lambda p: (cx, rim - lip * 0.5, cz))
def _under(piece, sp, tex, tex2, M):
    cx, cz = piece["x"], piece["z"]
    R = float(sp["r"])
    rs = float(sp.get("stem", R * 0.3))
    y0 = float(sp.get("at", piece["y"]))
    rise = float(sp.get("rise", piece["h"]))
    segs = int(sp.get("segs", 24))
    P = []
    for f in (0.0, 0.35, 0.7, 1.0):
        r = R + (rs - R) * f
        y = y0 + rise * (f ** 0.7)
        P.append([(cx + r * math.cos(2 * math.pi * j / segs), y,
                   cz + r * math.sin(2 * math.pi * j / segs)) for j in range(segs)])
    M.grid(P, lambda i, j: tex2 if (tex2 and j % 2) else tex,
           lambda p: (cx, y0 + rise + 2000, cz))
def _stem(piece, sp, tex, M):
    cx, cz = piece["x"], piece["z"]
    rs = float(sp["r"])
    flare = float(sp.get("flare", 1.3))
    y0, y1 = piece["y"], float(sp.get("top", piece["y"] + piece["h"]))
    segs = int(sp.get("segs", 12))
    P = []
    for f, k in ((0.0, flare), (0.06, 1.0 + (flare - 1) * 0.45), (0.2, 1.0),
                 (0.5, 1.07), (0.8, 0.98), (1.0, 0.86)):
        y = y0 + (y1 - y0) * f
        r = rs * k
        P.append([(cx + r * math.cos(2 * math.pi * j / segs), y,
                   cz + r * math.sin(2 * math.pi * j / segs)) for j in range(segs)])
    M.grid(P, lambda i, j: tex, lambda p: (cx, p[1], cz))
def _dome_point(dome, th, phi, lift=0.0):
    cx, cz, R, rim, top = dome
    H = top - rim
    c = max(0.0, math.cos(th))
    p = (cx + R * math.sin(th) * math.cos(phi), rim + H * c ** 0.55,
         cz + R * math.sin(th) * math.sin(phi))
    e = 1e-3
    def at(t, f):
        cc = max(0.0, math.cos(t))
        return (cx + R * math.sin(t) * math.cos(f), rim + H * cc ** 0.55,
                cz + R * math.sin(t) * math.sin(f))
    a = _sub(at(th + e, phi), at(max(0.0, th - e), phi))
    b = _sub(at(th, phi + e), at(th, phi - e)) if th > 1e-3 else (0.0, 0.0, 1.0)
    n = _unit(_cross(b, a))
    if n[1] < 0 and th < 1.4:
        n = (-n[0], -n[1], -n[2])
    if th <= 1e-3:
        n = (0.0, 1.0, 0.0)
    return (p[0] + n[0] * lift, p[1] + n[1] * lift, p[2] + n[2] * lift), n
def _spot(piece, sp, tex, M):
    for dot in sp.get("dots") or [list(sp["at"]) + [sp.get("size", 12)]]:
        _dot_on(sp, dot, tex, M)
def _dot_on(sp, dot, tex, M):
    dome = [float(v) for v in sp["dome"]]
    th0, ph0 = (math.radians(float(v)) for v in dot[:2])
    s = math.radians(float(dot[2]))
    lift = 3.0 + dome[2] * 0.004
    centre, cn = _dome_point(dome, th0, ph0, lift)
    ring = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        th = th0 + s * math.cos(a)
        ph = ph0 + s * math.sin(a) / max(0.25, math.sin(th0))
        ring.append(_dome_point(dome, th, ph, lift))
    for k in range(8):
        a, b = ring[k], ring[(k + 1) % 8]
        tri = [(centre, cn), a, b]
        fn = _cross(_sub(tri[1][0], tri[0][0]), _sub(tri[2][0], tri[1][0]))
        if _dot(fn, cn) < 0:
            tri = [tri[0], tri[2], tri[1]]
        M.tris.append((tuple(tri), tex, None))
def isle_outline(sp, segs=None):
    R = float(sp["r"])
    Rz = float(sp.get("rz", R))
    seed = int(sp.get("seed", 1))
    segs = segs or int(sp.get("segs", 24 if sp.get("square") else
                                   (20 if max(R, Rz) > 900 else 14)))
    out = []
    for j in range(segs):
        a = 2 * math.pi * j / segs
        out.append((a, R * _rim_k(sp, a), Rz * _rim_k(sp, a)))
    return out
def _rim_k(sp, a):
    k = 1.0 + max(-0.07, _wave(int(sp.get("seed", 1)), a) * (0.4 if sp.get("square") else 1.0))
    n = sp.get("square")
    if n:
        c, s = abs(math.cos(a)), abs(math.sin(a))
        k *= (c ** n + s ** n) ** (-1.0 / n)
    return k
def isle_edge(sp, cx, cz, angle):
    R = float(sp["r"])
    Rz = float(sp.get("rz", R))
    k = _rim_k(sp, angle)
    return cx + R * k * math.cos(angle), cz + Rz * k * math.sin(angle)
def _isle(piece, sp, tex, texb, texu, M):
    cx, cz = piece["x"], piece["z"]
    top = piece["y"] + piece["h"]
    R = float(sp["r"])
    depth = float(sp.get("depth", R * 1.4))
    seed = int(sp.get("seed", 1))
    band = float(sp.get("band", min(220.0, R * 0.18)))
    out = isle_outline(sp)
    segs = len(out)
    def ring(f, y, wob=0.0, i=0, dx=0.0, dz=0.0):
        pts = []
        for j, (a, rx, rz) in enumerate(out):
            w = 1 + wob * (_h(seed, i, j) - 0.5)
            pts.append((cx + dx + f * rx * w * math.cos(a), y, cz + dz + f * rz * w * math.sin(a)))
        return pts
    inner = ring(0.8, top)
    M.fan((cx, top, cz), inner, tex, True)
    rim = [inner, ring(0.93, top - band * 0.1), ring(0.99, top - band * 0.3),
           ring(1.02, top - band * 0.58)]
    M.grid(rim, lambda i, j: tex, lambda p: (cx, top - band * 3, cz))
    soil = [rim[-1], ring(1.01, top - band, 0.04, 1), ring(0.95, top - band * 1.4, 0.06, 2)]
    side = (tex[0], 1 if tex[1] is not None else 0, tex[2], tex[3])
    M.grid(soil, lambda i, j: side, lambda p: (cx, p[1], cz),
           uv=("side", cx, cz, R, top - band * 0.58))
    wx = (_h(seed, 7) - 0.5) * R * 0.45
    wz = (_h(seed, 8) - 0.5) * R * 0.45
    y = top - band * 1.4
    body = [soil[-1]]
    if sp.get("mesa"):
        fr = (0.08, 0.18, 0.3, 0.42, 0.56, 0.7, 0.84, 0.94, 1.0)
        shape = lambda f: 0.95 * (1.0 if f < 0.42 else max(0.0, 1 - (f - 0.42) / 0.58) ** 0.7)
    else:
        fr = (0.1, 0.22, 0.35, 0.5, 0.64, 0.77, 0.88, 0.96, 1.0)
        shape = lambda f: 0.95 * (1 - f) ** 0.7
    for i, f in enumerate(fr):
        rr = shape(f)
        if i % 2 == 0 and f < 0.9:
            rr *= 1.05
        body.append(ring(max(0.01, rr), y - depth * f, 0.1, 10 + i, wx * f * f, wz * f * f))
    tip = body[-1]
    tcx = sum(p[0] for p in tip) / len(tip)
    tcz = sum(p[2] for p in tip) / len(tip)
    body[-1] = [(tcx, y - depth - 60, tcz)] * segs
    def stratum(i, j):
        f = fr[min(i, len(fr) - 1)]
        if f > 0.6:
            return texu
        return texb if (i % 3) != 2 else texu
    M.grid(body, stratum, lambda p: (cx, p[1], cz))
def _blob(piece, sp, tex, M, puffs=None):
    seed = int(sp.get("seed", 1))
    e = float(sp.get("round", 2.6))
    lon, lat = int(sp.get("segs", 12)), int(sp.get("rings", 7))
    items = puffs or [(piece["x"], piece["y"] + piece["h"] / 2.0, piece["z"],
                       piece["w"] / 2.0, piece["h"] / 2.0, piece["d"] / 2.0)]
    flat = sp.get("flat", True)
    table = sp.get("table", False)
    rough = sp.get("rough")
    for n, (cx, cy, cz, ax, ay, az) in enumerate(items):
        P = []
        for i in range(lat + 1):
            v = -math.pi / 2 + math.pi * i / lat
            row = []
            for j in range(lon):
                u = 2 * math.pi * j / lon
                cu, su, cv, sv = math.cos(u), math.sin(u), math.cos(v), math.sin(v)
                f = lambda c: math.copysign(abs(c) ** (2.0 / e), c)
                jit = 1.0 + 0.12 * (_h(seed, n, i, j) - 0.5) if 0 < i < lat else 1.0
                x = ax * f(cv) * f(cu) * jit
                z = az * f(cv) * f(su) * jit
                y = ay * f(sv) * (1.0 + 0.06 * (_h(seed, n, j, i) - 0.5))
                if rough:
                    k = 1.0 - rough * _h(seed, n, i, j, 7)
                    x, z = x * k, z * k
                    y = y * (1.0 - rough * _h(seed, n, j, i, 9))
                    if i in (0, lat):
                        x += ax * rough * 0.4 * (_h(seed, n, j, 13) - 0.5)
                        z += az * rough * 0.4 * (_h(seed, n, j, 17) - 0.5)
                if table and sv > 0:
                    y = ay * min(1.0, f(sv) * 1.3)
                if flat and y < -ay * 0.7:
                    y = -ay * 0.7 - (y + ay * 0.7) * 0.25
                row.append((cx + x, cy + y, cz + z))
            P.append(row)
        P = P[::-1]
        M.grid(P, lambda i, j: tex, lambda p, c=(cx, cy, cz): c)
def _cloud(piece, sp, tex, M):
    seed = int(sp.get("seed", 1))
    w, h, d = piece["w"] / 2.0, piece["h"] / 2.0, piece["d"] / 2.0
    cx, cy, cz = piece["x"], piece["y"] + h, piece["z"]
    puffs = [(cx, cy - h * 0.1, cz, w * 0.62, h * 0.75, d * 0.7)]
    n = 4 + int(_h(seed, 1) * 3)
    for k in range(n):
        a = 2 * math.pi * (k + _h(seed, k, 2) * 0.6) / n
        r = 0.45 + 0.2 * _h(seed, k, 3)
        s = 0.42 + 0.25 * _h(seed, k, 4)
        puffs.append((cx + math.cos(a) * w * r, cy + h * (0.15 * _h(seed, k, 5) - 0.2),
                      cz + math.sin(a) * d * r, w * s, h * (s + 0.25), d * s))
    _blob(piece, dict(sp, round=2.0, segs=10, rings=5, flat=False), tex, M, puffs)
def _sheet(piece, sp, tex, M):
    seed = int(sp.get("seed", 1))
    ox, oz = sp.get("out") or ([0, 1] if piece["w"] >= piece["d"] else [1, 0])
    span = piece["w"] if abs(oz) > abs(ox) else piece["d"]
    y0, y1 = piece["y"], piece["y"] + piece["h"]
    bow = float(sp.get("bow", min(90.0, (y1 - y0) * 0.05)))
    cols, rows = 5, 8
    P = []
    for i in range(rows + 1):
        f = i / float(rows)
        y = y1 - (y1 - y0) * f
        out = bow * math.sqrt(f)
        spread = 1 + 0.15 * f
        row = []
        for j in range(cols + 1):
            u = (j / float(cols) - 0.5) * span * spread
            rip = 12 * math.sin(j * 1.7 + f * 6 + _h(seed, j) * 6)
            o = out + rip
            if abs(oz) > abs(ox):
                row.append((piece["x"] + u, y, piece["z"] + oz * o))
            else:
                row.append((piece["x"] + ox * o, y, piece["z"] + u))
        P.append(row)
    M.grid(P, lambda i, j: tex, lambda p: (p[0] - ox * 1000, p[1], p[2] - oz * 1000),
           closed=False)
def faces(piece, picture=None, layered=()):
    sp = piece.get("sculpt") or {}
    shape = sp.get("shape")
    if shape == "none" or shape not in SHAPES:
        return []
    slug = piece["tex"]
    def key(s, tone=None, layer=None):
        return (s, layer if s in layered else None, tone, None)
    tex = key(slug, sp.get("tone"))
    M = Mesh()
    if shape == "cap":
        _cap(piece, sp, tex, M)
    elif shape == "under":
        _under(piece, sp, tex, key(slug, sp.get("tone2")) if sp.get("tone2") else None, M)
    elif shape == "stem":
        _stem(piece, sp, tex, M)
    elif shape == "spot":
        _spot(piece, sp, tex, M)
    elif shape == "isle":
        _isle(piece, sp, key(slug, sp.get("tone"), 0), key(sp.get("body") or slug),
              key(sp.get("under") or sp.get("body") or slug), M)
    elif shape == "rock":
        _blob(piece, sp, tex, M)
    elif shape == "cloud":
        _cloud(piece, sp, tex, M)
    elif shape == "sheet":
        _sheet(piece, sp, tex, M)
    out = []
    for tri, (s, layer, tone, _), mode in M.tris:
        a, b, c = (p for p, _ in tri)
        fn = _unit(_cross(_sub(b, a), _sub(c, b)))
        lay = layer if layer is not None else _layer(fn, s in layered)
        win = swatch(s, tone, picture) if tone else None
        corners = []
        for p, n in tri:
            st = _uv(p, fn, mode, win)
            corners.append((p[0], p[1], p[2], st[0], st[1], n[0], n[1], n[2]))
        out.append((corners, fn, (s, lay)))
    return out
def extent(piece):
    sp = piece.get("sculpt") or {}
    x0, x1 = piece["x"] - piece["w"] / 2.0, piece["x"] + piece["w"] / 2.0
    z0, z1 = piece["z"] - piece["d"] / 2.0, piece["z"] + piece["d"] / 2.0
    y0, y1 = piece["y"], piece["y"] + piece["h"]
    if sp.get("shape") == "isle":
        r = float(sp["r"]) * 1.2
        y0 -= float(sp.get("depth", r)) + 400
        x0, x1, z0, z1 = min(x0, piece["x"] - r), max(x1, piece["x"] + r), \
            min(z0, piece["z"] - r), max(z1, piece["z"] + r)
    elif sp.get("shape") in ("cap", "under"):
        r = float(sp["r"]) * 1.05
        y0 -= float(sp.get("lip", 150))
        y1 = max(y1, float(sp.get("top", y1)))
        x0, x1, z0, z1 = min(x0, piece["x"] - r), max(x1, piece["x"] + r), \
            min(z0, piece["z"] - r), max(z1, piece["z"] + r)
    return x0, x1, y0, y1, z0, z1
