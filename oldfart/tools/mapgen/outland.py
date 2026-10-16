import math
from . import heightfield as hf
OUT_QUAD = 400
BAND_QUADS = 8
SURFACE_SLIPPERY = hf.SURFACE_SLIPPERY
SLIDE_MAX_DEG = hf.SLIDE_MAX_DEG
MERGE_TOL = (16, 60)
BAND_BLOCKS = ((4, 300), (2, None))
REACH_UP = 300
ESCAPE_H = 2400
HORIZON_STEP = 3000
HORIZON_REACH = 29000
HORIZON_SINK = 400
HORIZON_PERIOD = 1920
SNOW_MAX_DEG = 52.0
SNOW_BAND = 0.6
MEADOW_LINE = 0.38
MEADOW_WANDER = 0.16
MEADOW_WAVE = 2600
MEADOW_MAX_DEG = 40.0
SHELF = 400
SEAM_GRADE = 2.0
KINDS = {
    "mountains": {"crest": (1500, 4200), "grade": (44, 64), "shoulder": (500, 2200),
                  "ridge": 0.32, "peaks": 0.95, "far": 5600, "snow": 1.15, "cones": 0,
                  "dune": False, "rock": "rockboulder"},
    "ice": {"crest": (1900, 4400), "grade": (48, 65), "shoulder": (500, 2400),
            "ridge": 0.36, "peaks": 1.0, "far": 6000, "snow": 0.0, "cones": 0, "dune": False,
            "rock": "frostedrock"},
    "dunes": {"crest": (900, 2000), "grade": (31, 38), "shoulder": (800, 2600),
              "ridge": 0.22, "peaks": 0.4, "far": 1800, "snow": None, "cones": 0,
              "dune": True, "rock": "sandstone"},
    "volcanic": {"crest": (1400, 3400), "grade": (42, 62), "shoulder": (500, 2400),
                 "ridge": 0.34, "peaks": 0.6, "far": 4000, "snow": None, "cones": 3,
                 "dune": False, "rock": "basaltrough"},
}
THEME_KIND = {"lava": "volcanic", "desert": "dunes", "ice": "ice"}
def kind_for(theme):
    return THEME_KIND.get(theme, "mountains")
def wants(spec):
    b = (spec or {}).get("backdrop")
    return isinstance(b, dict) and b.get("outline") in KINDS and spec.get("floor") is not None
def smoothstep(a, b, v):
    if b <= a:
        return 1.0 if v >= b else 0.0
    t = max(0.0, min(1.0, (v - a) / float(b - a)))
    return t * t * (3.0 - 2.0 * t)
def ridged(x, z, seed, wave):
    return 1.0 - abs(hf.noise(x, z, seed, wave))
class Shape(object):
    def __init__(self, kind, seed, hole, seam, base, scale=1.0):
        self.k = KINDS[kind]
        self.kind = kind
        self.seed = seed
        self.x0, self.x1, self.z0, self.z1 = hole
        self.seam = seam
        self.base = base
        self.scale = scale
        self.cones = []
        if self.k["cones"]:
            half = max(self.x1 - self.x0, self.z1 - self.z0) / 2.0
            for c in range(self.k["cones"]):
                a = 2 * math.pi * (c + 0.35 * hf._hash01(seed, "cone", c)) / self.k["cones"]
                r = half + 9000 + 4000 * hf._hash01(seed, "coner", c)
                self.cones.append((math.sin(a) * r, math.cos(a) * r,
                                   5200 + 2400 * hf._hash01(seed, "coneh", c),
                                   4200 + 1800 * hf._hash01(seed, "conew", c)))
    def dist(self, x, z):
        dx = max(self.x0 - x, 0.0, x - self.x1)
        dz = max(self.z0 - z, 0.0, z - self.z1)
        return math.hypot(dx, dz)
    def foot(self, x, z):
        lo, hi = self.k["shoulder"]
        t = max(0.0, min(1.0, 0.5 + 0.85 * hf.noise(x, z, self.seed + "/foot", 6400)))
        f = lo + (hi - lo) * t ** 1.5
        spur = ridged(x, z, self.seed + "/fspur", 3800) ** 4
        return max(lo, f - 1300.0 * spur)
    def foot_height(self, x, z):
        return self.shoulder(x, z, self.foot(x, z))
    def crest(self, x, z):
        lo, hi = self.k["crest"]
        t = 0.5 + 0.5 * hf.noise(x, z, self.seed + "/crest", 9000)
        return (lo + (hi - lo) * t ** 1.3) * self.scale
    def grade(self, x, z):
        lo, hi = self.k["grade"]
        t = 0.5 + 0.5 * hf.noise(x, z, self.seed + "/grade", 4200)
        return math.tan(math.radians(lo + (hi - lo) * t))
    def shoulder(self, x, z, d):
        s = self.seam(x, z)
        smooth = self.seam_mean(x, z)
        h = s + (smooth - s) * smoothstep(SHELF, SHELF + 1000.0, d)
        roll = 30.0 * hf.noise(x, z, self.seed + "/roll", 5600)
        return h + roll * smoothstep(300.0, 1200.0, d)
    def seam_mean(self, x, z, reach=2600, n=6):
        px = max(self.x0, min(self.x1, x))
        pz = max(self.z0, min(self.z1, z))
        along_x = pz in (self.z0, self.z1) and self.x0 < px < self.x1
        total = 0.0
        for k in range(-n, n + 1):
            off = reach * k / float(n)
            if along_x:
                total += self.seam(max(self.x0, min(self.x1, px + off)), pz)
            else:
                total += self.seam(px, max(self.z0, min(self.z1, pz + off)))
        return total / (2 * n + 1)
    def height(self, x, z):
        d = self.dist(x, z)
        f = self.foot(x, z)
        sh = self.shoulder(x, z, min(d, f))
        if d <= f:
            return sh
        u = d - f
        c = self.crest(x, z)
        g = self.grade(x, z)
        k = self.k
        if k["dune"]:
            rise = c * (1.0 - math.exp(-g * u / c))
            swell = ridged(x * 0.8 + z * 0.3, z * 0.8 - x * 0.3, self.seed + "/dune", 2600)
            rise *= 0.75 + 0.35 * swell ** 2
        else:
            rise = c * (1.0 - math.exp(-g * u / c))
            spur = ridged(x, z, self.seed + "/spur", 2600)
            rise += k["ridge"] * c * (spur ** 2 - 0.45) * smoothstep(0.0, 900.0, u)
        reach = c / g
        peak = ridged(x, z, self.seed + "/peak", 5200) ** 2.2
        rise += k["peaks"] * c * peak * smoothstep(0.7 * reach, 2.6 * reach + 2500.0, u)
        far = k["far"] * self.scale * (0.55 + 0.45 * hf.noise(x, z, self.seed + "/farm", 11000))
        far *= ridged(x * 0.7, z * 0.7, self.seed + "/farr", 7000) ** 1.6
        rise += far * smoothstep(5000.0, 13000.0, d)
        for cx, cz, ch, cw in self.cones:
            r = math.hypot(x - cx, z - cz)
            if r < cw:
                t = 1.0 - r / cw
                cone = ch * (t ** 1.25)
                crater = 0.18 * cw
                if r < crater:
                    cone = ch * ((1.0 - crater / cw) ** 1.25) - 260.0 * (1.0 - r / crater)
                rise = max(rise, cone)
        return sh + max(0.0, rise)
    def zone(self, x, z):
        d = self.dist(x, z)
        return "shoulder" if d <= self.foot(x, z) else "flank"
def planar_uv(point, normal, period):
    unit = 1024.0 / period
    x, y, z = point
    ax, ay, az = abs(normal[0]), abs(normal[1]), abs(normal[2])
    if ay >= ax and ay >= az:
        return x * unit, z * unit
    if ax >= az:
        return (-z if normal[0] > 0 else z) * unit, -y * unit
    return (x if normal[2] > 0 else -x) * unit, -y * unit
def tone(seed, x, y, z, normal):
    if abs(normal[1]) > 0.86:
        return 1.0 + 0.05 * hf.noise(x, z, seed + "/tint", 1700)
    band = math.sin((y + 160.0 * hf.noise(x, z, seed + "/strata", 2300)) / 160.0)
    gully = ridged(x, z, seed + "/spur", 2600)
    return (1.0 + 0.045 * band) * (0.9 + 0.12 * gully)
class Band(object):
    def __init__(self, ox, oz, nx, nz, depth=BAND_QUADS):
        self.ox, self.oz, self.nx, self.nz, self.k = ox, oz, nx, nz, depth
        self.h = {}
    def x(self, i):
        return self.ox + i * OUT_QUAD
    def z(self, j):
        return self.oz + j * OUT_QUAD
    def in_hole(self, i, j):
        return 0 <= i < self.nx and 0 <= j < self.nz
    def quads(self):
        k = self.k
        for j in range(-k, self.nz + k):
            for i in range(-k, self.nx + k):
                if not self.in_hole(i, j):
                    yield i, j
    def on_seam(self, i, j):
        return 0 <= i <= self.nx and 0 <= j <= self.nz and (i in (0, self.nx) or j in (0, self.nz))
    def seam_quad(self, i, j):
        return any(self.in_hole(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
def seam_heights(L):
    out = {}
    nx, nz = L.nx, L.nz
    for vj in range(nz + 1):
        for vi in range(nx + 1):
            if vi not in (0, nx) and vj not in (0, nz):
                continue
            best = None
            for (di, dj), c in hf.ROUND:
                i, j = vi + di, vj + dj
                if 0 <= i < nx and 0 <= j < nz:
                    q = i + j * nx
                    h = L.fc[q][c] if (L.drawn[q] or L.src[q] >= 0) else L.floor
                    best = h if best is None else max(best, h)
            out[(vi, vj)] = best
    loop = [(vi, 0) for vi in range(nx)] + [(nx, vj) for vj in range(nz)] + \
        [(vi, nz) for vi in range(nx, 0, -1)] + [(0, vj) for vj in range(nz, 0, -1)]
    k = SEAM_GRADE * hf.QUAD
    for _ in range(2):
        for seq in (loop, loop[::-1]):
            prev = seq[-1]
            for v in seq:
                out[v] = min(out[v], out[prev] + k)
                prev = v
    return out
def seam_function(L, seam):
    q = float(hf.QUAD)
    x0, z0 = L.ox, L.oz
    x1, z1 = L.ox + L.nx * hf.QUAD, L.oz + L.nz * hf.QUAD
    def at(x, z):
        px = max(x0, min(x1, x))
        pz = max(z0, min(z1, z))
        if pz in (z0, z1) or not (x0 < px < x1):
            vj = 0 if abs(pz - z0) <= abs(pz - z1) else L.nz
            u = (px - x0) / q
            a = int(math.floor(u))
            a = max(0, min(L.nx - 1, a))
            t = u - a
            return seam[(a, vj)] * (1 - t) + seam[(a + 1, vj)] * t
        vi = 0 if abs(px - x0) <= abs(px - x1) else L.nx
        u = (pz - z0) / q
        a = max(0, min(L.nz - 1, int(math.floor(u))))
        t = u - a
        return seam[(vi, a)] * (1 - t) + seam[(vi, a + 1)] * t
    return at
def _tri_slope(a, b, c):
    n = hf._normal([a, b, c])
    return math.degrees(math.acos(max(-1.0, min(1.0, abs(n[1])))))
def surface_of(a, b, c):
    return hf.SURFACE_DEFAULT if _tri_slope(a, b, c) <= hf.WALKABLE_DEG else SURFACE_SLIPPERY
def _limit(B, keep, k):
    import heapq
    pq = [(h, v) for v, h in B.h.items()]
    heapq.heapify(pq)
    while pq:
        h, v = heapq.heappop(pq)
        if h > B.h[v]:
            continue
        i, j = v
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                if not (di or dj):
                    continue
                w = (i + di, j + dj)
                if w not in B.h or w in keep:
                    continue
                c = h + k * OUT_QUAD * math.hypot(di, dj)
                if c < B.h[w]:
                    B.h[w] = c
                    heapq.heappush(pq, (c, w))
def build(L, E, spec, seed, top_y):
    b = spec["backdrop"]
    kind = b["outline"]
    ratio = OUT_QUAD // hf.QUAD
    if L.ox % OUT_QUAD or L.oz % OUT_QUAD or L.nx % ratio or L.nz % ratio:
        raise ValueError("the terrain lattice is not on the band's %d grid" % OUT_QUAD)
    seam = seam_heights(L)
    at = seam_function(L, seam)
    hole = (L.ox, L.ox + L.nx * hf.QUAD, L.oz, L.oz + L.nz * hf.QUAD)
    edge = [v for v in seam.values() if v is not None]
    base = sorted(edge)[len(edge) // 2] if edge else (L.floor or 0)
    half = max(hole[1] - hole[0], hole[3] - hole[2]) / 2.0
    scale = max(0.75, min(1.35, half / 9000.0))
    S = Shape(kind, seed, hole, at, base, scale)
    B = Band(L.ox, L.oz, L.nx // ratio, L.nz // ratio)
    keep = set()
    for j in range(-B.k, B.nz + B.k + 1):
        for i in range(-B.k, B.nx + B.k + 1):
            if 0 < i < B.nx and 0 < j < B.nz:
                continue
            if B.on_seam(i, j):
                B.h[(i, j)] = float(seam[(i * ratio, j * ratio)])
                keep.add((i, j))
            else:
                B.h[(i, j)] = S.height(B.x(i), B.z(j))
    _limit(B, keep, math.tan(math.radians(SLIDE_MAX_DEG - 0.5)) / math.sqrt(2.0))
    for v in B.h:
        B.h[v] = int(round(B.h[v]))
    stats = {"band_quads": 0, "band_merged": 0, "band_triangles": 0, "slide_triangles": 0,
             "steepest": 0.0}
    ground = b.get("ground") or E.floor_tex
    rock = b.get("rock") or E.rock or ground
    snow = b.get("snow")
    crest_hi = KINDS[kind]["crest"][1] * scale
    snow_y = None if KINDS[kind]["snow"] is None or not snow else \
        base + KINDS[kind]["snow"] * crest_hi
    if snow_y is not None and KINDS[kind]["snow"] > 0:
        top_band = max(B.h.values())
        horizon_snow = snow_y
        snow_y = min(snow_y, base + SNOW_BAND * (top_band - base))
    else:
        horizon_snow = snow_y
    period = float(b.get("period") or 640)
    meadow = kind == "mountains"
    def material(tri, line=None):
        slope = _tri_slope(*tri)
        top = max(p[1] for p in tri)
        line = snow_y if line is None else line
        if line is not None and top >= line and slope <= SNOW_MAX_DEG:
            return snow
        if slope <= hf.WALKABLE_DEG and kind != "ice":
            return ground
        if meadow and slope <= MEADOW_MAX_DEG:
            mx = sum(p[0] for p in tri) / 3.0
            mz = sum(p[2] for p in tri) / 3.0
            line = base + crest_hi * (MEADOW_LINE + MEADOW_WANDER * hf.noise(
                mx, mz, seed + "/meadow", MEADOW_WAVE))
            if top <= line:
                return ground
        if kind == "dunes":
            return ground if slope <= 45 else rock
        return rock
    def emit(tri, stand=True, mat=None):
        tri = [tuple(int(round(c)) for c in p) for p in tri]
        if hf._area2(*tri) <= 0:
            return
        slope = _tri_slope(*tri)
        stats["steepest"] = max(stats["steepest"], round(slope, 1))
        surface = surface_of(*tri)
        if surface == SURFACE_SLIPPERY:
            stats["slide_triangles"] += 1
        E.top(list(tri), mat or material(tri), surface if stand else None,
              uv=lambda p, n: planar_uv(p, n, period))
        stats["band_triangles"] += 1
    lo_i, hi_i, lo_j, hi_j = -B.k, B.nx + B.k, -B.k, B.nz + B.k
    foot_h = {}
    def high(v, over):
        if v not in foot_h:
            foot_h[v] = S.foot_height(B.x(v[0]), B.z(v[1]))
        return B.h[v] > foot_h[v] + over
    taken = {}
    blocks = []
    for size, over in BAND_BLOCKS:
        for j in range(lo_j, hi_j - size + 1, size):
            for i in range(lo_i, hi_i - size + 1, size):
                qs = [(i + a, j + c) for a in range(size) for c in range(size)]
                if any(q in taken or B.in_hole(*q) or B.seam_quad(*q) for q in qs):
                    continue
                vs = [(i + a, j + c) for a in range(size + 1) for c in range(size + 1)]
                corners = [(i, j), (i + size, j), (i + size, j + size), (i, j + size)]
                hs = [B.h[c] for c in corners]
                pts = [(B.x(c[0]), h, B.z(c[1])) for c, h in zip(corners, hs)]
                diag = hf.split_of(pts)
                up = all(high(v, REACH_UP if over is None else over) for v in vs)
                want = {}
                tol = MERGE_TOL[1] if up or not all(
                    S.zone(B.x(v[0]), B.z(v[1])) == "shoulder" for v in corners) else MERGE_TOL[0]
                ok = True
                for (vi, vj) in vs:
                    w = hf._interp(hs[0], hs[1], hs[2], hs[3], (vi - i) / float(size),
                                   (vj - j) / float(size), diag)
                    if not up and abs(w - B.h[(vi, vj)]) > tol:
                        ok = False
                        break
                    want[(vi, vj)] = int(round(w))
                if not ok:
                    continue
                for v, w in want.items():
                    B.h[v] = w
                for q in qs:
                    taken[q] = len(blocks)
                blocks.append((i, j, size, diag, up))
                stats["band_merged"] += 1
    def P(i, j):
        return (B.x(i), B.h[(i, j)], B.z(j))
    def quad_material(pts, diag):
        tris = hf.quad_tris(pts, diag)
        worst = max(tris, key=lambda t: _tri_slope(*t))
        return material(worst)
    up2 = set((i, j) for i, j, size, diag, up in blocks if up and size == 2)
    coarse = set()
    for j in range(lo_j, hi_j - 3, 4):
        for i in range(lo_i, hi_i - 3, 4):
            subs = [(i, j), (i + 2, j), (i, j + 2), (i + 2, j + 2)]
            if all(s in up2 for s in subs):
                coarse.update(subs)
                pts = [P(i, j), P(i + 4, j), P(i + 4, j + 4), P(i, j + 4)]
                for tri in hf.quad_tris(pts, hf.split_of(pts)):
                    tri = [tuple(int(round(c)) for c in p) for p in tri]
                    if hf._area2(*tri) > 0:
                        E._stand(surface_of(*tri), tri)
    for i, j, size, diag, up in blocks:
        pts = [P(i, j), P(i + size, j), P(i + size, j + size), P(i, j + size)]
        m = quad_material(pts, diag)
        for tri in hf.quad_tris(pts, diag):
            emit(tri, (i, j) not in coarse, m)
    for (i, j) in B.quads():
        if (i, j) in taken:
            continue
        stats["band_quads"] += 1
        pts = [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]
        if B.seam_quad(i, j):
            emit_seam(L, B, i, j, pts, ratio, seam, emit)
            continue
        diag = hf.split_of(pts)
        m = quad_material(pts, diag)
        for tri in hf.quad_tris(pts, diag):
            emit(tri, True, m)
    ring = []
    for i in range(lo_i, hi_i):
        ring.append(((i, lo_j), (i + 1, lo_j), (0.0, 0.0, 1.0)))
        ring.append(((i + 1, hi_j), (i, hi_j), (0.0, 0.0, -1.0)))
    for j in range(lo_j, hi_j):
        ring.append(((hi_i, j), (hi_i, j + 1), (-1.0, 0.0, 0.0)))
        ring.append(((lo_i, j + 1), (lo_i, j), (1.0, 0.0, 0.0)))
    tallest = max(B.h.values())
    wall_top = int(max(top_y, tallest) + ESCAPE_H)
    for a, c, n in ring:
        pa, pc = P(*a), P(*c)
        E.wall([(pa[0], min(pa[1], pc[1]) - 10, pa[2]), (pc[0], min(pa[1], pc[1]) - 10, pc[2]),
                (pc[0], wall_top, pc[2]), (pa[0], wall_top, pa[2])], None, n,
               surface=hf.SURFACE_DEFAULT, draw=False)
    stats["outline"] = kind
    stats["wall_top"] = wall_top
    stats["far_triangles"] = far_band(E, B, material)
    stats["horizon_triangles"] = horizon(E, S, B, seed, ground, rock, snow, horizon_snow, material,
                                         base + 0.45 * KINDS[kind]["crest"][0] * scale)
    stats["crest_lowest"] = int(min(B.h[(i, j)] for (i, j) in B.h
                                    if i in (lo_i, hi_i) or j in (lo_j, hi_j)))
    return stats
SIDES = ((0, -1), (1, 0), (0, 1), (-1, 0))
FAR_BAND = 8
def far_band(E, B, material):
    k = B.k
    def axis(n):
        return sorted(set(list(range(-k, 0, FAR_BAND)) + list(range(0, n, FAR_BAND)) + [n]
                          + list(range(n, n + k, FAR_BAND)) + [n + k]))
    xs, zs = axis(B.nx), axis(B.nz)
    sink_faces = []
    keep = E.out.faces
    E.out.faces = sink_faces
    try:
        for a in range(len(xs) - 1):
            for b in range(len(zs) - 1):
                i0, i1, j0, j1 = xs[a], xs[a + 1], zs[b], zs[b + 1]
                if 0 <= i0 and i1 <= B.nx and 0 <= j0 and j1 <= B.nz:
                    continue
                pts = [(B.x(i0), B.h[(i0, j0)], B.z(j0)), (B.x(i1), B.h[(i1, j0)], B.z(j0)),
                       (B.x(i1), B.h[(i1, j1)], B.z(j1)), (B.x(i0), B.h[(i0, j1)], B.z(j1))]
                for tri in hf.quad_tris(pts, hf.split_of(pts)):
                    if hf._area2(*tri) > 0:
                        E.top(list(tri), material(tri), None,
                              uv=lambda p, n: planar_uv(p, n, HORIZON_PERIOD))
    finally:
        E.out.faces = keep
    E.out.far_faces.extend(sink_faces)
    return len(sink_faces)
def emit_seam(L, B, i, j, pts, ratio, seam, emit):
    corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
    ring = []
    far = None
    for k in range(4):
        a, c = corners[k], corners[(k + 1) % 4]
        if far is None and not B.on_seam(*a):
            far = len(ring)
        ring.append(pts[k])
        if not B.in_hole(i + SIDES[k][0], j + SIDES[k][1]):
            continue
        for s in range(1, ratio):
            t = s / float(ratio)
            vi = int(round((a[0] + (c[0] - a[0]) * t) * ratio))
            vj = int(round((a[1] + (c[1] - a[1]) * t) * ratio))
            ring.append((L.ox + vi * hf.QUAD, seam[(vi, vj)], L.oz + vj * hf.QUAD))
    ring = ring[far:] + ring[:far]
    for k in range(1, len(ring) - 1):
        emit((ring[0], ring[k], ring[k + 1]))
def horizon(E, S, B, seed, ground, rock, snow, snow_y, material, meadow_y):
    x0, x1 = B.x(-B.k), B.x(B.nx + B.k)
    z0, z1 = B.z(-B.k), B.z(B.nz + B.k)
    reach = HORIZON_REACH
    step = HORIZON_STEP
    n = int(math.ceil(reach / float(step)))
    pts = {}
    def inside(x, z, m=0):
        return x0 + m < x < x1 - m and z0 + m < z < z1 - m
    for j in range(-n, n + 1):
        for i in range(-n, n + 1):
            x = max(-reach, min(reach, i * step))
            z = max(-reach, min(reach, j * step))
            if max(abs(x), abs(z)) < reach:
                x += 0.32 * step * hf.noise(x, z, seed + "/jx", 2100)
                z += 0.32 * step * hf.noise(x, z, seed + "/jz", 2100)
            h = S.height(x, z)
            if inside(x, z):
                h -= HORIZON_SINK
            pts[(i, j)] = (int(round(x)), int(round(h)), int(round(z)))
    tris = 0
    keep = E.out.faces
    E.out.faces = E.out.horizon_faces
    for j in range(-n, n):
        for i in range(-n, n):
            corners = [pts[(i, j)], pts[(i + 1, j)], pts[(i + 1, j + 1)], pts[(i, j + 1)]]
            if all(inside(c[0], c[2], 1) for c in corners):
                continue
            for tri in hf.quad_tris(corners, hf.split_of(corners)):
                if all(inside(c[0], c[2], 1) for c in tri):
                    continue
                m = material(tri, snow_y)
                if m == ground and min(c[1] for c in tri) > meadow_y:
                    m = rock
                E.top(list(tri), m, None,
                      uv=lambda p, nrm: planar_uv(p, nrm, HORIZON_PERIOD))
                tris += 1
    E.out.faces = keep
    return tris
def replaced(pieces):
    out = set()
    for k, p in enumerate(pieces):
        tag = str(p.get("tag") or "")
        if tag == "edge" or tag.startswith("edge.") or tag.startswith("dress.backdrop"):
            out.add(k)
    return out
