import hashlib
import heapq
import math
QUAD = 200
JOIN = 215
PIN_JOIN = 40
SLOPE = 0.46
WALKABLE_DEG = 28.0
WALL_NY = 0.01
CONFLICT_ROUNDS = 8
RELAX_ROUNDS = 40
RELAX_MARGIN = 1.0
MERGE = 4
QUADS = (100, 200)
SLOPE_TEX_GRADE = 0.30
LIP = 60
TOLERANCE = 10
SPLIT = 800
ANCHOR_MARGIN = 60
SMALL_FOOT = 260
SLAB_H = 60
SLAB_TAGS = ("path", "road", "street", "lane", "plaza", "way")
POINT_REACH = 300
STAND_GAP = 60
TEX_UNIT = 32 * 32 / 200.0
DETAIL_AMP = 26
DETAIL_WAVE = 1400
DETAIL_FREE = 500
WARP_AMP = 1.1
WARP_WAVE = 1800
STEEP_JOIN = 1400
STEEP_GRADE = 1.70
FLANK_ROCK_GRADE = 0.70
STEEP_TOL = 40
ERODE_DEPTH = 70
ERODE_FROM = 6
SURFACE_DEFAULT, SURFACE_BURNING, SURFACE_ICE = 0x0000, 0x0001, 0x002E
SURFACE_SLIPPERY = 0x0014
SLIDE_MAX_DEG = 68.0
def triangle_band(surface, tri):
    a, b, c = tri
    u = [b[k] - a[k] for k in range(3)]
    v = [c[k] - b[k] for k in range(3)]
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    ln = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2])
    if surface == 0x0015 or not ln:
        return None
    ny = n[1] / ln
    if abs(ny) <= WALL_NY:
        return "wall"
    if ny >= math.cos(math.radians(WALKABLE_DEG)):
        return "floor"
    if ny <= -0.999:
        return "ceiling"
    if surface == SURFACE_SLIPPERY and ny >= math.cos(math.radians(SLIDE_MAX_DEG)):
        return "slide"
    return None
TERRAIN_TAGS = ("terrace", "terrace.rock", "terrace.plate", "hills", "hills.rock", "slope",
                "hills.ramp", "ground", "volcano",
                "pond.podium", "cave.top", "cave.roof",
                "play.cannon.mound")
VOID_DEEP = -100000
CAVE_GAP = 250
WATER_TAGS = ("river.water", "lake.water")
WATER_GROW = 12
WATER_SHALLOW = 80
BASIN_TAGS = ("lake.terrace", "lake.bed", "lake.rim.shore", "lake.bank.shore")
SHORE_HELD = ("lake.rim.shore",)
BANK_SLIDE_TAGS = ("lake.bank.shore",)
TERRAIN_KINDS = ("box", "ramp", "inner", "outer")
RIVER_TAGS = ("river.water", "river.lava")
BANK_RISE = 40
def river_quads(L, pieces, ring=1):
    nx, nz = L.nx, L.nz
    out = set()
    for p in pieces:
        if str(p.get("tag") or "") not in RIVER_TAGS:
            continue
        for q in _quads_in(L, [_footprint(p)]):
            i, j = q % nx, q // nx
            for dj in range(-ring, ring + 1):
                for di in range(-ring, ring + 1):
                    if 0 <= i + di < nx and 0 <= j + dj < nz:
                        out.add(i + di + (j + dj) * nx)
    return out
def river_banks(L, pieces):
    nx, nz = L.nx, L.nz
    beds = {}
    for p in pieces:
        if str(p.get("tag") or "") not in RIVER_TAGS:
            continue
        top = p["y"] + p["h"]
        for q in _quads_in(L, [_footprint(p)]):
            beds[q] = max(beds.get(q, top), top)
    bank = {}
    raised = 0
    for q, top in sorted(beds.items()):
        i, j = q % nx, q // nx
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            r = a + b * nx
            if not (0 <= a < nx and 0 <= b < nz) or r in beds:
                continue
            if L.src[r] < 0 or L.hc[r] is None or L.fc[r] is None or min(L.hc[r]) < top:
                continue
            for c, (oi, oj) in enumerate(CORNER_OFF):
                vi, vj = a + oi, b + oj
                if not (i <= vi <= i + 1 and j <= vj <= j + 1):
                    continue
                h = min(L.hc[r][c], top + BANK_RISE)
                if L.fc[r][c] < h:
                    L.fc[r][c] = h
                    L.steep[r] = True
                    raised += 1
                bank[(vi, vj)] = max(bank.get((vi, vj), L.fc[r][c]), L.fc[r][c])
    sloped = 0
    for q in sorted(beds):
        if L.fc[q] is None:
            continue
        i, j = q % nx, q // nx
        new = list(L.fc[q])
        for c, (oi, oj) in enumerate(CORNER_OFF):
            h = bank.get((i + oi, j + oj))
            if h is not None:
                new[c] = max(new[c], min(h, L.fc[q][c] + QUAD))
        if new != L.fc[q]:
            L.fc[q] = new
            L.steep[q] = True
            sloped += 1
    return raised, sloped
def _quads_in(L, rects):
    out = set()
    for r in rects or ():
        x0, x1, z0, z1 = r
        i0 = max(0, int(math.ceil((x0 - L.ox) / float(QUAD) - 0.5)))
        i1 = min(L.nx - 1, int(math.floor((x1 - L.ox) / float(QUAD) - 0.5)))
        j0 = max(0, int(math.ceil((z0 - L.oz) / float(QUAD) - 0.5)))
        j1 = min(L.nz - 1, int(math.floor((z1 - L.oz) / float(QUAD) - 0.5)))
        for j in range(j0, j1 + 1):
            for i in range(i0, i1 + 1):
                out.add(i + j * L.nx)
    return sorted(out)
def wants(arena):
    t = arena.get("terrain")
    return isinstance(t, dict) and bool(t.get("mesh"))
def is_terrain(piece):
    tag = str(piece.get("tag") or "")
    if piece.get("decor") or piece.get("kind") not in TERRAIN_KINDS:
        return False
    if piece.get("tex") in (None, "invisible"):
        return False
    if float(piece.get("yaw", 0) or 0) % 90:
        return False
    return tag in TERRAIN_TAGS or tag in BASIN_TAGS
def is_sheet(piece):
    return piece.get("kind") == "water" and str(piece.get("tag") or "") in WATER_TAGS
def _hash01(seed, *xs):
    h = hashlib.blake2b(("%s:%s" % (seed, ":".join(str(x) for x in xs))).encode(),
                        digest_size=4).digest()
    return int.from_bytes(h, "big") / 4294967296.0
def noise(x, z, seed, wave):
    total, norm, amp, f = 0.0, 0.0, 1.0, 1.0 / wave
    for o in range(2):
        u, v = x * f, z * f
        i, j = int(math.floor(u)), int(math.floor(v))
        fu, fv = u - i, v - j
        fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
        s = "%s/%d" % (seed, o)
        a, b = _hash01(s, i, j), _hash01(s, i + 1, j)
        c, d = _hash01(s, i, j + 1), _hash01(s, i + 1, j + 1)
        val = (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv
        total += amp * (2 * val - 1)
        norm += amp
        amp *= 0.45
        f *= 2.1
    return total / norm
def _footprint(p):
    yaw = int(round(float(p.get("yaw", 0) or 0))) % 360
    w, d = p["w"], p["d"]
    if yaw in (90, 270):
        w, d = d, w
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def _arenas():
    import importlib.util
    import os
    import sys
    global _M
    if _M is None:
        tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if tools not in sys.path:
            sys.path.insert(0, tools)
        spec = importlib.util.spec_from_file_location(
            "heightfield_arenas", os.path.join(tools, "make-arenas.py"))
        _M = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_M)
    return _M
_M = None
def top_at(piece, x, z):
    if piece["kind"] == "box":
        return piece["y"] + piece["h"]
    p = dict(piece)
    p["yaw"] = int(round(float(p.get("yaw", 0) or 0))) % 360
    return _arenas().top_at(p, x, z)
def surface_of(piece):
    if piece is None:
        return SURFACE_DEFAULT
    if piece.get("kind") == "lava" or piece.get("tex") == "lava":
        return SURFACE_BURNING
    if piece.get("kind") == "ice":
        return SURFACE_ICE
    return SURFACE_DEFAULT
class Terrain(object):
    def __init__(self):
        self.consumed = set()
        self.faces = []
        self.collision = []
        self.occluders = []
        self.stats = {}
        self.grid = None
        self.tone = None
        self.far_faces = []
        self.water_faces = []
        self.horizon_faces = []
class Lattice(object):
    def __init__(self, ox, oz, nx, nz, floor):
        self.ox, self.oz, self.nx, self.nz = ox, oz, nx, nz
        self.floor = floor
        n = nx * nz
        self.src = [-1] * n
        self.hc = [None] * n
        self.col = [None] * n
        self.anchor = [False] * n
        self.soft = [False] * n
        self.steep = [False] * n
        self.cave = {}
        self.fc = [None] * n
        self.drawn = [False] * n
        self.eroded = 0
        self.vpin = {}
    def q(self, i, j):
        return i + j * self.nx
    def x(self, i):
        return self.ox + i * QUAD
    def z(self, j):
        return self.oz + j * QUAD
BACKDROP_MARGIN = 200
def raster(pieces, terrain_idx, floor, pad=0, align=None, cover=None):
    xs, zs = [], []
    if cover is not None:
        xs += [cover[0], cover[1]]
        zs += [cover[2], cover[3]]
    for k in terrain_idx:
        x0, x1, z0, z1 = _footprint(pieces[k])
        xs += [x0, x1]
        zs += [z0, z1]
    step = align or QUAD
    ox = int(math.floor(min(xs) / step)) * step - pad * QUAD
    oz = int(math.floor(min(zs) / step)) * step - pad * QUAD
    nx = int(math.ceil((max(xs) - ox) / step)) * step // QUAD + pad
    nz = int(math.ceil((max(zs) - oz) / step)) * step // QUAD + pad
    L = Lattice(ox, oz, nx, nz, floor)
    best = [None] * (nx * nz)
    cols = [None] * (nx * nz)
    for k in terrain_idx:
        p = pieces[k]
        x0, x1, z0, z1 = _footprint(p)
        i0 = max(0, int(math.ceil((x0 - ox) / QUAD - 0.5)))
        i1 = min(nx - 1, int(math.floor((x1 - ox) / QUAD - 0.5)))
        j0 = max(0, int(math.ceil((z0 - oz) / QUAD - 0.5)))
        j1 = min(nz - 1, int(math.floor((z1 - oz) / QUAD - 0.5)))
        for j in range(j0, j1 + 1):
            cz = oz + j * QUAD + QUAD / 2.0
            if not z0 < cz < z1:
                continue
            for i in range(i0, i1 + 1):
                cx = ox + i * QUAD + QUAD / 2.0
                if not x0 < cx < x1:
                    continue
                q = i + j * nx
                t = top_at(p, cx, cz)
                if t is None:
                    continue
                if best[q] is None or t > best[q][0] or (t == best[q][0] and k > best[q][1]):
                    best[q] = (t, k)
                if cols[q] is None:
                    cols[q] = []
                cols[q].append((p["y"], t, p["tex"], k))
    for q in range(nx * nz):
        i, j = q % nx, q // nx
        if best[q] is None:
            L.hc[q] = [floor, floor, floor, floor]
            L.col[q] = []
            continue
        t, k = best[q]
        p = pieces[k]
        L.src[q] = k
        if p["kind"] == "box":
            L.hc[q] = [int(round(t))] * 4
        else:
            xa, xb = L.x(i), L.x(i + 1)
            za, zb = L.z(j), L.z(j + 1)
            L.hc[q] = [int(round(top_at(p, x_, z_))) for x_, z_ in
                       ((xa, za), (xb, za), (xb, zb), (xa, zb))]
        L.col[q] = sorted(cols[q])
        segs = L.col[q]
        for a in range(len(segs) - 1):
            under = max(s[1] for s in segs[:a + 1])
            if segs[a + 1][0] - under >= CAVE_GAP and \
                    max(s[1] for s in segs[a + 1:]) >= t - 1:
                L.cave[q] = (int(round(under)), int(round(segs[a + 1][0])))
    return L
def anchor(L, pieces, terrain_idx, points):
    skip = set(terrain_idx)
    nx, nz = L.nx, L.nz
    for k, p in enumerate(pieces):
        if k in skip or p.get("kind") == "water" or p.get("drape"):
            continue
        try:
            x0, x1, z0, z1 = _footprint(p)
        except (KeyError, TypeError):
            continue
        if float(p.get("yaw", 0) or 0) % 90:
            r = math.hypot(p["w"], p["d"]) / 2.0
            x0, x1, z0, z1 = p["x"] - r, p["x"] + r, p["z"] - r, p["z"] + r
        foot, head = p["y"], p["y"] + p["h"]
        slab = p.get("kind") == "box" and p["h"] <= SLAB_H and \
            str(p.get("tag", "")).split(".")[0] in SLAB_TAGS
        if max(x1 - x0, z1 - z0) <= SMALL_FOOT and not slab:
            q = _quad_at(L, p["x"], p["z"])
            if q is None:
                continue
            hc = L.hc[q]
            if not (foot <= max(hc) + STAND_GAP and head >= min(hc) - 10):
                continue
            for v in _vertices_under(L, x0, x1, z0, z1):
                _pin(L, v, _ground_at(L, q, v))
            continue
        i0 = max(0, int(math.floor((x0 - ANCHOR_MARGIN - L.ox) / QUAD)))
        i1 = min(nx - 1, int(math.floor((x1 + ANCHOR_MARGIN - L.ox) / QUAD)))
        j0 = max(0, int(math.floor((z0 - ANCHOR_MARGIN - L.oz) / QUAD)))
        j1 = min(nz - 1, int(math.floor((z1 + ANCHOR_MARGIN - L.oz) / QUAD)))
        for j in range(j0, j1 + 1):
            for i in range(i0, i1 + 1):
                q = i + j * nx
                hc = L.hc[q]
                lo, hi = min(hc), max(hc)
                if foot <= hi + STAND_GAP and head >= lo - 10:
                    L.anchor[q] = True
    for (x, y, z) in points:
        q = _quad_at(L, x, z)
        if q is None:
            continue
        if y > max(L.hc[q]) + POINT_REACH:
            continue
        i, j = q % nx, q // nx
        for c, (di, dj) in enumerate(CORNER_OFF):
            _pin(L, (i + di, j + dj), _ground_at(L, q, (i + di, j + dj)))
def surface_at(L, x, z):
    q = _quad_at(L, x, z)
    if q is None or L.fc[q] is None or not L.drawn[q] and L.src[q] < 0:
        return None
    u = (x - L.x(q % L.nx)) / float(QUAD)
    w = (z - L.z(q // L.nx)) / float(QUAD)
    u, w = max(0.0, min(1.0, u)), max(0.0, min(1.0, w))
    h = L.fc[q]
    return h[0] * (1 - u) * (1 - w) + h[1] * u * (1 - w) + h[2] * u * w + h[3] * (1 - u) * w
def drape(L, pieces):
    n = 0
    for p in pieces:
        if not p.get("drape"):
            continue
        hw, hd = p["w"] / 2.0, p["d"] / 2.0
        hs = [surface_at(L, p["x"] + dx, p["z"] + dz)
              for dx, dz in ((0, 0), (-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))]
        hs = [h for h in hs if h is not None]
        if not hs:
            continue
        y = int(round(min(hs)))
        if y != p["y"]:
            p["y"] = y
            n += 1
    return n
def _quad_at(L, x, z):
    i = int(math.floor((x - L.ox) / QUAD))
    j = int(math.floor((z - L.oz) / QUAD))
    if 0 <= i < L.nx and 0 <= j < L.nz:
        return i + j * L.nx
    return None
def _vertices_under(L, x0, x1, z0, z1):
    out = []
    vi0 = int(math.ceil((x0 - L.ox) / QUAD))
    vi1 = int(math.floor((x1 - L.ox) / QUAD))
    vj0 = int(math.ceil((z0 - L.oz) / QUAD))
    vj1 = int(math.floor((z1 - L.oz) / QUAD))
    for vj in range(max(0, vj0), min(L.nz, vj1) + 1):
        for vi in range(max(0, vi0), min(L.nx, vi1) + 1):
            out.append((vi, vj))
    if not out:
        vi = int(round(((x0 + x1) / 2.0 - L.ox) / QUAD))
        vj = int(round(((z0 + z1) / 2.0 - L.oz) / QUAD))
        if 0 <= vi <= L.nx and 0 <= vj <= L.nz:
            out.append((vi, vj))
    return out
def _ground_at(L, q, v):
    i, j = q % L.nx, q // L.nx
    hc = L.hc[q]
    u = max(0.0, min(1.0, float(v[0] - i)))
    w = max(0.0, min(1.0, float(v[1] - j)))
    return int(round(hc[0] * (1 - u) * (1 - w) + hc[1] * u * (1 - w) + hc[2] * u * w
                     + hc[3] * (1 - u) * w))
def _pin(L, v, h):
    old = L.vpin.get(v)
    if old is None or h > old:
        L.vpin[v] = h
ROUND = (((-1, -1), 2), ((0, -1), 3), ((0, 0), 0), ((-1, 0), 1))
CORNER_OFF = ((0, 0), (1, 0), (1, 1), (0, 1))
def surface_nodes(L, broken=frozenset()):
    nx, nz = L.nx, L.nz
    node = {}
    pins, up0, dn0, rings = [], [], [], []
    for vj in range(nz + 1):
        for vi in range(nx + 1):
            ring = []
            for (di, dj), c in ROUND:
                i, j = vi + di, vj + dj
                if 0 <= i < nx and 0 <= j < nz:
                    ring.append((i + j * nx, c))
                else:
                    ring.append(None)
            parent = list(range(4))
            def find(a):
                while parent[a] != a:
                    parent[a] = parent[parent[a]]
                    a = parent[a]
                return a
            for a in range(4):
                b = (a + 1) % 4
                ra, rb = ring[a], ring[b]
                if ra is None or rb is None:
                    continue
                if not (L.soft[ra[0]] and L.soft[rb[0]]):
                    continue
                if (min(ra[0], rb[0]), max(ra[0], rb[0])) in broken:
                    continue
                d = abs(L.hc[ra[0]][ra[1]] - L.hc[rb[0]][rb[1]])
                if d <= JOIN or (d <= STEEP_JOIN and L.steep[ra[0]] and L.steep[rb[0]]):
                    parent[find(a)] = find(b)
            groups = {}
            for a in range(4):
                if ring[a] is not None and L.soft[ring[a][0]]:
                    groups.setdefault(find(a), []).append(a)
            for members in groups.values():
                nid = len(pins)
                hs = [L.hc[ring[a][0]][ring[a][1]] for a in members]
                up0.append(max(hs))
                dn0.append(min(hs))
                pin = None
                for a in members:
                    for b in ((a + 1) % 4, (a + 3) % 4):
                        rb = ring[b]
                        if rb is None or L.soft[rb[0]]:
                            continue
                        h = L.hc[rb[0]][rb[1]]
                        if abs(h - L.hc[ring[a][0]][ring[a][1]]) <= PIN_JOIN and (
                                pin is None or h > pin):
                            pin = h
                vp = L.vpin.get((vi, vj))
                if vp is not None and any(abs(vp - L.hc[ring[a][0]][ring[a][1]]) <= PIN_JOIN
                                          for a in members):
                    pin = vp if pin is None else max(pin, vp)
                if pin is None and any(L.steep[ring[a][0]] for a in members):
                    best = None
                    for a in members:
                        for b in range(4):
                            rb = ring[b]
                            if rb is None or L.soft[rb[0]] or not L.anchor[rb[0]]:
                                continue
                            h = L.hc[rb[0]][rb[1]]
                            d = abs(h - L.hc[ring[a][0]][ring[a][1]])
                            if d <= STEEP_JOIN and (best is None or d < best[0]):
                                best = (d, h)
                    if best is not None:
                        pin = best[1]
                pins.append(pin)
                rings.append([ring[a] for a in members])
                for a in members:
                    node[ring[a]] = nid
    return node, len(pins), pins, up0, dn0, rings
def _edges(L, node, count, flags=None):
    adj = [[] for _ in range(count)]
    if flags is not None:
        flags[:] = [[] for _ in range(count)]
    d = QUAD * math.sqrt(2.0)
    for q in range(L.nx * L.nz):
        if not L.soft[q]:
            continue
        n = [node[(q, c)] for c in range(4)]
        s = L.steep[q]
        for a, b, w in ((0, 1, QUAD), (1, 2, QUAD), (2, 3, QUAD), (3, 0, QUAD),
                        (0, 2, d), (1, 3, d)):
            if n[a] != n[b]:
                adj[n[a]].append((n[b], w))
                adj[n[b]].append((n[a], w))
                if flags is not None:
                    flags[n[a]].append(s)
                    flags[n[b]].append(s)
    return adj
def _envelope(adj, start, k, upper, flags=None, ks=None):
    INF = float("inf")
    n = len(adj)
    if upper:
        val = [(-INF if s is None else s) for s in start]
        pq = [(-v, i) for i, v in enumerate(val) if v != -INF]
    else:
        val = [(INF if s is None else s) for s in start]
        pq = [(v, i) for i, v in enumerate(val) if v != INF]
    heapq.heapify(pq)
    while pq:
        key, i = heapq.heappop(pq)
        v = -key if upper else key
        if v != val[i]:
            continue
        for e, (j, w) in enumerate(adj[i]):
            kk = ks if (flags is not None and flags[i][e]) else k
            c = v - kk * w if upper else v + kk * w
            if (upper and c > val[j]) or (not upper and c < val[j]):
                val[j] = c
                heapq.heappush(pq, (-c if upper else c, j))
    return val
def _tri_ok(a, b, c, deg=None):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx_ = uy * vz - uz * vy
    ny_ = uz * vx - ux * vz
    nz_ = ux * vy - uy * vx
    ln = math.sqrt(nx_ * nx_ + ny_ * ny_ + nz_ * nz_)
    if ln == 0:
        return True
    ny = abs(ny_) / ln
    return ny >= math.cos(math.radians(WALKABLE_DEG if deg is None else deg)) or ny <= WALL_NY
def quad_points(L, q, hc):
    i, j = q % L.nx, q // L.nx
    return [(L.x(i + di), hc[c], L.z(j + dj)) for c, (di, dj) in enumerate(CORNER_OFF)]
def split_of(pts):
    def steep(a, b, c):
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx_ = uy * vz - uz * vy
        ny_ = uz * vx - ux * vz
        nz_ = ux * vy - uy * vx
        ln = math.sqrt(nx_ * nx_ + ny_ * ny_ + nz_ * nz_) or 1.0
        return 1.0 - abs(ny_) / ln
    p0, p1, p2, p3 = pts
    s0 = max(steep(p0, p1, p2), steep(p0, p2, p3))
    s1 = max(steep(p1, p2, p3), steep(p1, p3, p0))
    return 0 if s0 <= s1 + 1e-9 else 1
def quad_tris(pts, diag):
    p0, p1, p2, p3 = pts
    if diag == 0:
        return [(p0, p3, p2), (p0, p2, p1)]
    return [(p1, p0, p3), (p1, p3, p2)]
def legal_quad(pts, deg=None):
    return quad_grade([p[1] for p in pts])[1] <= math.tan(math.radians(
        WALKABLE_DEG if deg is None else deg))
def smooth(L, seed, detail=True, erosion=True):
    broken = set()
    INF = float("inf")
    for _ in range(CONFLICT_ROUNDS):
        node, count, pins, up0, dn0, rings = surface_nodes(L, broken)
        flags = []
        adj = _edges(L, node, count, flags)
        lo = _envelope(adj, pins, SLOPE, True, flags, STEEP_GRADE)
        hi = _envelope(adj, pins, SLOPE, False, flags, STEEP_GRADE)
        more = set()
        hot = set()
        for n in range(count):
            if lo[n] > hi[n] + 1 and lo[n] != -INF and hi[n] != INF:
                hot.add(n)
                hot.update(m for m, _ in adj[n])
        for n in sorted(hot):
            if True:
                members = rings[n]
                for a in range(len(members)):
                    for b in range(a + 1, len(members)):
                        qa, ca = members[a]
                        qb, cb = members[b]
                        if abs(L.hc[qa][ca] - L.hc[qb][cb]) > PIN_JOIN and not (
                                L.steep[qa] and L.steep[qb]):
                            more.add((min(qa, qb), max(qa, qb)))
        if not more - broken:
            break
        broken |= more
    k2 = 2.0 * SLOPE
    U = _envelope(adj, up0, k2, True, flags, STEEP_GRADE)
    D = _envelope(adj, dn0, k2, False, flags, STEEP_GRADE)
    F = []
    for n in range(count):
        f = (U[n] + D[n]) / 2.0
        if pins[n] is not None:
            f = pins[n]
        else:
            if lo[n] > hi[n]:
                f = (lo[n] + hi[n]) / 2.0
            elif f < lo[n]:
                f = lo[n]
            elif f > hi[n]:
                f = hi[n]
        F.append(f)
    if detail and DETAIL_AMP:
        free = _free_distance(adj, pins)
        pos = _node_pos(L, node, count)
        for n in range(count):
            if pins[n] is not None:
                continue
            fade = min(1.0, free[n] / float(DETAIL_FREE))
            if fade <= 0:
                continue
            grade = _node_grade(adj, F, n)
            room = max(0.0, 1.0 - grade / SLOPE)
            x, z = pos[n]
            F[n] += DETAIL_AMP * fade * room * noise(x, z, seed + "/detail", DETAIL_WAVE)
    if erosion and ERODE_DEPTH:
        L.eroded = erode(adj, F, pins, lo, L.floor)
    relaxed = relax(L, node, F, pins, adj, lo, hi)
    for q in range(L.nx * L.nz):
        if L.soft[q]:
            L.fc[q] = [int(round(F[node[(q, c)]])) for c in range(4)]
        else:
            L.fc[q] = list(L.hc[q])
    return relaxed, len(broken)
def erode(adj, F, pins, lo, floor=-10 ** 6):
    n = len(F)
    if not n:
        return 0
    INF = float("inf")
    edge = [k for k in range(n) if pins[k] is not None or len(adj[k]) < 6]
    filled = [INF] * n
    pq = []
    for k in edge:
        filled[k] = F[k]
        pq.append((F[k], k))
    heapq.heapify(pq)
    order = []
    while pq:
        h, k = heapq.heappop(pq)
        if h > filled[k]:
            continue
        order.append(k)
        for m, _ in adj[k]:
            if filled[m] == INF:
                filled[m] = max(F[m], h + 1e-3)
                heapq.heappush(pq, (filled[m], m))
    rec = [-1] * n
    for k in range(n):
        best, bh = -1, filled[k]
        for m, w in adj[k]:
            if filled[m] < bh:
                best, bh = m, filled[m]
        rec[k] = best
    acc = [1.0] * n
    for k in sorted(range(n), key=lambda k: -filled[k]):
        if rec[k] >= 0:
            acc[rec[k]] += acc[k]
    top = max(acc)
    if top <= ERODE_FROM:
        return 0
    span = math.log(top) - math.log(ERODE_FROM)
    cut = 0
    for k in range(n):
        if pins[k] is not None or acc[k] <= ERODE_FROM or rec[k] < 0:
            continue
        w = next((w_ for m, w_ in adj[k] if m == rec[k]), QUAD)
        grade = (F[k] - F[rec[k]]) / float(w)
        steep = min(1.0, grade / (0.6 * SLOPE))
        if steep <= 0.05:
            continue
        depth = ERODE_DEPTH * steep * min(1.0, (math.log(acc[k]) - math.log(ERODE_FROM)) / span)
        F[k] = max(lo[k], F[k] - depth, floor)
        cut += 1
    return cut
def relax(L, node, F, pins, adj, lo, hi, rounds=RELAX_ROUNDS):
    limit = math.tan(math.radians(WALKABLE_DEG - RELAX_MARGIN))
    of_node = {}
    for (q, c), n in node.items():
        of_node.setdefault(n, []).append(q)
    todo = [q for q in range(L.nx * L.nz) if L.soft[q] and not L.steep[q]]
    moved = 0
    for _ in range(rounds):
        bad = set()
        for q in todo:
            ns = [node[(q, c)] for c in range(4)]
            if quad_grade([F[n] for n in ns])[1] > limit:
                for n in ns:
                    if pins[n] is None:
                        bad.add(n)
        if not bad:
            break
        new = {}
        for n in bad:
            if adj[n]:
                mean = sum(F[m] for m, _ in adj[n]) / float(len(adj[n]))
                v = 0.5 * F[n] + 0.5 * mean
                if lo[n] <= hi[n]:
                    v = min(hi[n], max(lo[n], v))
                new[n] = v
        for n, v in new.items():
            F[n] = v
        moved += len(new)
        todo = sorted(set(q for n in new for q in of_node.get(n, ())))
    return moved
def quad_grade(h):
    h0, h1, h2, h3 = h
    a = math.hypot(h2 - h3, h3 - h0)
    b = math.hypot(h1 - h0, h2 - h1)
    c = math.hypot(h1 - h0, h3 - h0)
    d = math.hypot(h2 - h3, h2 - h1)
    s0, s1 = max(a, b), max(c, d)
    if s0 <= s1 + 1e-9:
        return 0, s0 / QUAD
    return 1, s1 / QUAD
def _free_distance(adj, pins):
    src = [0.0 if p is not None else None for p in pins]
    if all(s is None for s in src):
        return [float(DETAIL_FREE)] * len(adj)
    return _envelope(adj, src, 1.0, False)
def _node_pos(L, node, count):
    pos = [None] * count
    for (q, c), n in node.items():
        if pos[n] is None:
            i, j = q % L.nx, q // L.nx
            di, dj = CORNER_OFF[c]
            pos[n] = (L.x(i + di), L.z(j + dj))
    return pos
def _node_grade(adj, F, n):
    g = 0.0
    for m, w in adj[n]:
        g = max(g, abs(F[m] - F[n]) / w)
    return g
def legalise(L):
    back = 0
    walk = math.tan(math.radians(WALKABLE_DEG))
    for q in range(L.nx * L.nz):
        if not L.soft[q]:
            continue
        hc = L.fc[q]
        slide = math.tan(math.radians(SLIDE_MAX_DEG))
        limit = slide if L.steep[q] else walk
        if quad_grade(hc)[1] <= limit:
            continue
        if not L.steep[q] and quad_grade(hc)[1] <= slide and _beside_steep(L, q):
            L.steep[q] = True
            continue
        mean = sum(hc) / 4.0
        lo, hi = 0.0, 1.0
        for _ in range(12):
            t = (lo + hi) / 2.0
            if quad_grade([mean + t * (v - mean) for v in hc])[1] <= limit * 0.98:
                lo = t
            else:
                hi = t
        new = [int(round(mean + lo * (v - mean))) for v in hc]
        if quad_grade(new)[1] > limit:
            new = [int(round(mean))] * 4
        if L.src[q] < 0:
            i, j = q % L.nx, q // L.nx
            pins = {c: L.vpin[(i + di, j + dj)] for c, (di, dj) in enumerate(CORNER_OFF)
                    if (i + di, j + dj) in L.vpin}
            if pins:
                kept = [pins.get(c, v) for c, v in enumerate(new)]
                if quad_grade(kept)[1] > limit:
                    h0 = int(round(sum(pins.values()) / float(len(pins))))
                    kept = [pins.get(c, h0) for c in range(4)]
                new = kept
        L.fc[q] = new
        L.soft[q] = False
        back += 1
    return back
def _beside_steep(L, q):
    i, j = q % L.nx, q // L.nx
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            a, b = i + di, j + dj
            if (di or dj) and 0 <= a < L.nx and 0 <= b < L.nz and L.steep[a + b * L.nx]:
                return True
    return False
def warp(L, seed):
    if not WARP_AMP:
        return 0
    nx, nz = L.nx, L.nz
    hc = [list(h) for h in L.hc]
    src = list(L.src)
    col = list(L.col)
    moved = 0
    held = set()
    for (vi, vj) in L.vpin:
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if 0 <= i < nx and 0 <= j < nz:
                held.add(i + j * nx)
    still = getattr(L, "still", None) or set()
    for q in range(nx * nz):
        if not L.soft[q] or q in held or q in still:
            continue
        i, j = q % nx, q // nx
        cx, cz = L.x(i) + QUAD / 2.0, L.z(j) + QUAD / 2.0
        dx = WARP_AMP * QUAD * noise(cx, cz, seed + "/wx", WARP_WAVE)
        dz = WARP_AMP * QUAD * noise(cx, cz, seed + "/wz", WARP_WAVE)
        si = int(math.floor((cx + dx - L.ox) / QUAD))
        sj = int(math.floor((cz + dz - L.oz) / QUAD))
        if not (0 <= si < nx and 0 <= sj < nz):
            continue
        s = si + sj * nx
        if s == q or not L.soft[s] or s in still:
            continue
        a, b = L.hc[s], L.hc[q]
        if a == b:
            continue
        if max(a) != min(a) or max(b) != min(b):
            continue
        hc[q] = list(a)
        src[q] = L.src[s]
        col[q] = L.col[s]
        moved += 1
    L.hc = hc
    L.src = src
    L.col = col
    return moved
def _unit(v):
    ln = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if ln == 0:
        return (0.0, 1.0, 0.0)
    return (v[0] / ln, v[1] / ln, v[2] / ln)
def _normal(pts):
    a, b, c = pts[0], pts[1], pts[2]
    u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    v = (c[0] - b[0], c[1] - b[1], c[2] - b[2])
    return _unit((u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]))
def _extent(pts):
    most = 0.0
    for a in range(len(pts)):
        for b in range(a + 1, len(pts)):
            most = max(most, math.sqrt(sum((pts[a][k] - pts[b][k]) ** 2 for k in range(3))))
    return most
def _area2(a, b, c):
    u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    return (u[1] * v[2] - u[2] * v[1]) ** 2 + (u[2] * v[0] - u[0] * v[2]) ** 2 + \
        (u[0] * v[1] - u[1] * v[0]) ** 2
class Emitter(object):
    def __init__(self, out, layered):
        self.out = out
        self.layered = layered
    def tex_key(self, slug, normal):
        if slug in self.layered:
            return (slug, 0 if normal[1] > 0 else (2 if normal[1] < 0 else 1))
        return (slug, 0)
    def top(self, pts, slug, surface, split=False, uv=None):
        n = _normal(pts)
        if n[1] < 0:
            pts = list(reversed(pts))
            n = _normal(pts)
        if uv is None:
            corners = [(p[0], p[1], p[2], p[0] * TEX_UNIT, p[2] * TEX_UNIT) for p in pts]
        else:
            corners = [(p[0], p[1], p[2]) + tuple(uv(p, n)) for p in pts]
        self.out.faces.append((corners, n, self.tex_key(slug, n), _extent(pts), split,
                               uv is not None))
        if surface is not None:
            self._stand(surface, pts)
    def _stand(self, surface, pts):
        for k in range(1, len(pts) - 1):
            tri = (tuple(pts[0]), tuple(pts[k]), tuple(pts[k + 1]))
            if _area2(*tri) > 0:
                self.out.collision.append((surface, tri))
    def wall(self, pts, slug, n, surface=SURFACE_DEFAULT, draw=True, uv=None):
        m = _normal(pts)
        if m[0] * n[0] + m[2] * n[2] < 0:
            pts = list(reversed(pts))
        if not draw:
            self._stand(surface, pts)
            return
        top_y = max(p[1] for p in pts)
        u = (n[2], 0.0, -n[0])
        nn = (float(n[0]), 0.0, float(n[2]))
        corners = []
        for p in pts:
            if uv is not None:
                corners.append((p[0], p[1], p[2]) + tuple(uv(p, nn)))
                continue
            s = (p[0] * u[0] + p[2] * u[2]) * TEX_UNIT
            corners.append((p[0], p[1], p[2], s, (top_y - p[1]) * TEX_UNIT))
        self.out.faces.append((corners, nn, self.tex_key(slug, (0, 0, 0)), _extent(pts), False,
                               uv is not None))
        if surface is not None:
            self._stand(surface, pts)
def materials(L, E, pieces):
    slope_tex = getattr(E, "slope_tex", None) or {}
    steep = steep_quads(L) if slope_tex else None
    flank = getattr(E, "flank_rock", None)
    cliff = cliff_quads(L, pieces)
    def mat(q):
        k = L.src[q]
        p = pieces[k] if k >= 0 else None
        tex = p["tex"] if p else E.floor_tex
        if L.steep[q] and flank and tri_grade(L, q) >= FLANK_ROCK_GRADE:
            return (flank, surface_of(p))
        if q in cliff:
            rock = cliff[q] or flank or E.rock
            if rock:
                return (rock, surface_of(p))
        if tex in slope_tex and steep[q]:
            tex = slope_tex[tex]
        return (tex, surface_of(p))
    return mat
CLIFF_GRADE = 0.84
CLIFF_NEAR = 0.58
CLIFF_FILL = 5
CLIFF_KEEP = ("snow", "sand", "ice", "dune", "lava", "ash")
CLIFF_TRI_DEG = 35.0
def tri_grade(L, q):
    pts = quad_points(L, q, L.fc[q])
    best = 0.0
    for a, b, c in quad_tris(pts, split_of(pts)):
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx_ = uy * vz - uz * vy
        ny_ = uz * vx - ux * vz
        nz_ = ux * vy - uy * vx
        if ny_ == 0:
            continue
        best = max(best, math.hypot(nx_, nz_) / abs(ny_))
    return best
def _column_rock(L, q, pieces):
    col = L.col[q] or []
    top = L.src[q]
    tex = pieces[top]["tex"] if top >= 0 else None
    for y0, y1, t, k in sorted(col, key=lambda s: -s[1]):
        if k != top and t != tex and t not in (None, "invisible"):
            return t
    return None
def cliff_quads(L, pieces):
    nx, nz = L.nx, L.nz
    grade = {}
    for q in range(nx * nz):
        if not L.drawn[q] or not L.soft[q] or L.steep[q] or L.anchor[q]:
            continue
        k = L.src[q]
        tex = str(pieces[k]["tex"]) if k >= 0 else ""
        if any(w in tex for w in CLIFF_KEEP):
            continue
        grade[q] = tri_grade(L, q)
    out = set(q for q, g in grade.items() if g >= CLIFF_GRADE)
    for q, g in grade.items():
        if q in out or g < CLIFF_NEAR:
            continue
        i, j = q % nx, q // nx
        near = 0
        for dj in (-1, 0, 1):
            for di in (-1, 0, 1):
                a, b = i + di, j + dj
                if (di or dj) and 0 <= a < nx and 0 <= b < nz and \
                        (a + b * nx in out or L.steep[a + b * nx]):
                    near += 1
        if near >= CLIFF_FILL:
            out.add(q)
    return dict((q, _column_rock(L, q, pieces)) for q in out)
CORNERS = (((-1, 0), (0, 1), 0, 0), ((-1, 0), (0, -1), 1, 0), ((1, 0), (0, -1), 0, 1),
           ((1, 0), (0, 1), 1, 1))
def material_corners(L, mat):
    nx, nz = L.nx, L.nz
    out = {}
    for q in range(nx * nz):
        if not L.drawn[q] or L.anchor[q]:
            continue
        i, j = q % nx, q // nx
        m = mat(q)
        def at(di, dj):
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < nz and L.drawn[a + b * nx]:
                return mat(a + b * nx)
            return None
        for s1, s2, diag, half in CORNERS:
            other = at(*s1)
            if other is None or other == m or at(*s2) != other:
                continue
            o1 = (-s1[0], -s1[1])
            o2 = (-s2[0], -s2[1])
            if at(*o1) == other or at(*o2) == other:
                continue
            pts = quad_points(L, q, L.fc[q])
            tris = quad_tris(pts, diag)
            ok = all(_tri_ok(*t) or (L.steep[q] and _tri_ok(*t, deg=SLIDE_MAX_DEG))
                     for t in tris)
            if not ok:
                continue
            if not _tri_ok(*tris[half], deg=CLIFF_TRI_DEG):
                continue
            out[q] = (diag, (other, m) if half == 0 else (m, other))
            break
    return out
FAR_STEP = 3200
class _Sink(object):
    def __init__(self):
        self.faces, self.collision = [], []
def far_ground(L, E, pieces, mat=None):
    from .outland import planar_uv
    sink = _Sink()
    F = Emitter(sink, E.layered)
    F.floor_tex, F.rock = E.floor_tex, E.rock
    mat = mat or materials(L, E, pieces)
    step = max(1, FAR_STEP // QUAD)
    nx, nz = L.nx, L.nz
    xs = list(range(0, nx, step)) + [nx]
    zs = list(range(0, nz, step)) + [nz]
    def h_at(vi, vj):
        best = None
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if 0 <= i < nx and 0 <= j < nz and L.drawn[i + j * nx]:
                h = L.fc[i + j * nx][c]
                best = h if best is None else max(best, h)
        return L.floor if best is None else best
    H = dict(((vi, vj), h_at(vi, vj)) for vi in xs for vj in zs)
    for a in range(len(xs) - 1):
        for b in range(len(zs) - 1):
            count = {}
            for j in range(zs[b], zs[b + 1]):
                for i in range(xs[a], xs[a + 1]):
                    q = i + j * nx
                    if L.drawn[q]:
                        m = mat(q)[0]
                        count[m] = count.get(m, 0) + 1
            if not count:
                continue
            tex = max(sorted(count), key=lambda t: count[t])
            corners = [(xs[a], zs[b]), (xs[a + 1], zs[b]), (xs[a + 1], zs[b + 1]),
                       (xs[a], zs[b + 1])]
            pts = [(L.x(vi), H[(vi, vj)], L.z(vj)) for vi, vj in corners]
            for tri in quad_tris(pts, split_of(pts)):
                if _area2(*tri) > 0:
                    F.top(list(tri), tex, None, uv=lambda p, n: planar_uv(p, n, 640.0))
    return sink.faces
def emit_tops(L, E, pieces, tolerance=TOLERANCE):
    nx, nz = L.nx, L.nz
    done = [False] * (nx * nz)
    frozen = {}
    cnt = 0
    mat = materials(L, E, pieces)
    if getattr(L, "fine_mat", None) is not None:
        fine_mat, comp_mat = L.fine_mat, mat
        def mat(q, _f=fine_mat, _c=comp_mat):
            got = _f[q]
            return got if got is not None else _c(q)
    flats = {}
    blocks = getattr(L, "block", None)
    if blocks is not None and L.blocks:
        own = {}
        bc = getattr(L, "block_corner", None)
        for i0, j0, sz in L.blocks:
            qs = [i + j * nx for j in range(j0, j0 + sz) for i in range(i0, i0 + sz)]
            fm = getattr(L, "fine_mat", None)
            ms = [(fm[q] if fm is not None and fm[q] is not None else mat(q)) for q in qs]
            m_ = max(sorted(set(ms)), key=ms.count)
            if bc and (i0, j0) in bc and not set(bc[(i0, j0)][1]) <= set(ms):
                del bc[(i0, j0)]
            for q in qs:
                own[q] = m_
        base_mat = mat
        def mat(q, _own=own, _base=base_mat):
            got = _own.get(q)
            return got if got is not None else _base(q)
    corner = material_corners(L, mat)
    def vert(q, c):
        i, j = q % nx, q // nx
        di, dj = CORNER_OFF[c]
        return (i + di, j + dj)
    def held(vi, vj, hv, i0, i1, j0, j1):
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if not (0 <= i < nx and 0 <= j < nz) or (i0 <= i < i1 and j0 <= j < j1):
                continue
            qq = i + j * nx
            if L.anchor[qq] and L.fc[qq][c] == hv:
                return True
        return False
    def fit(i0, i1, j0, j1, m):
        h = {}
        exact = set()
        sm = L.steep[i0 + j0 * nx]
        for j in range(j0, j1):
            for i in range(i0, i1):
                q = i + j * nx
                if done[q] or not L.drawn[q] or mat(q) != m or L.steep[q] != sm or q in corner:
                    return None
                for c in range(4):
                    v = vert(q, c)
                    hv = L.fc[q][c]
                    if h.setdefault(v, hv) != hv:
                        return None
                    if L.anchor[q]:
                        exact.add(v)
        A = h[(i0, j0)]
        B = h[(i1, j0)]
        C = h[(i1, j1)]
        D = h[(i0, j1)]
        pts = [(L.x(i0), A, L.z(j0)), (L.x(i1), B, L.z(j0)),
               (L.x(i1), C, L.z(j1)), (L.x(i0), D, L.z(j1))]
        diag = split_of(pts)
        deg = SLIDE_MAX_DEG if sm else None
        if not all(_tri_ok(a, b, c, deg) for a, b, c in quad_tris(pts, diag)):
            return None
        wi, wj = float(i1 - i0), float(j1 - j0)
        moved = {}
        for (vi, vj), hv in h.items():
            u, v = (vi - i0) / wi, (vj - j0) / wj
            want = _interp(A, B, C, D, u, v, diag)
            lim = 0.5 if (vi, vj) in frozen or (vi, vj) in exact or (vi, vj) in L.vpin or (
                (vi in (i0, i1) or vj in (j0, j1)) and held(vi, vj, hv, i0, i1, j0, j1)) \
                else (STEEP_TOL if sm else tolerance) + 0.5
            if abs(want - hv) > lim:
                return None
            if int(round(want)) != hv and (vi in (i0, i1) or vj in (j0, j1)):
                moved[(vi, vj)] = (hv, int(round(want)))
        seen = set()
        for (vi, vj), (old, new) in moved.items():
            for (di, dj), c in ROUND:
                i, j = vi + di, vj + dj
                if not (0 <= i < nx and 0 <= j < nz) or (i0 <= i < i1 and j0 <= j < j1):
                    continue
                qq = i + j * nx
                if qq in seen or done[qq] or not L.drawn[qq]:
                    continue
                seen.add(qq)
                hc = list(L.fc[qq])
                for k in range(4):
                    w = vert(qq, k)
                    if w in moved and hc[k] == moved[w][0]:
                        hc[k] = moved[w][1]
                if not legal_quad(quad_points(L, qq, hc),
                                  SLIDE_MAX_DEG if L.steep[qq] else None):
                    return None
        return (A, B, C, D), diag
    for i0, j0, sz in (getattr(L, "blocks", None) or []) if (
            blocks is not None and getattr(L, "blocks_first", True)) else []:
        q = i0 + j0 * nx
        if done[q]:
            continue
        got = fit(i0, i0 + sz, j0, j0 + sz, mat(q))
        if got is not None:
            cnt += _emit_block(L, E, i0, i0 + sz, j0, j0 + sz, got, mat(q), done, frozen,
                               flats)
    dualb = list(blocks) if blocks is not None and not getattr(L, "blocks_first", True) \
        else None
    origins = set((i0, j0) for i0, j0, sz in (getattr(L, "blocks", None) or []))
    bcorner = getattr(L, "block_corner", None) or {}
    if dualb is not None:
        corner = dict((q, v) for q, v in corner.items() if dualb[q] != 2)
    for least in (MERGE * MERGE // 4, 8, 2, 1):
        for j in range(nz):
            for i in range(nx):
                q = i + j * nx
                if done[q] or not L.drawn[q]:
                    continue
                m = mat(q)
                most, grid = MERGE, SPLIT
                if blocks is not None and blocks[q] > MERGE:
                    most, grid = blocks[q], blocks[q] * QUAD
                gx = int(math.floor(L.x(i) / grid))
                gz = int(math.floor(L.z(j) / grid))
                step = 1
                if dualb is not None and dualb[q] == 2:
                    if (i, j) not in origins:
                        continue
                    step = 2
                    qs_ = [i + j * nx, i + 1 + j * nx, i + 1 + (j + 1) * nx, i + (j + 1) * nx]
                    if any(done[q_] for q_ in qs_):
                        for q_ in qs_:
                            dualb[q_] = 1
                        step = 1
                    elif (i, j) in bcorner:
                        cdiag, cmats = bcorner[(i, j)]
                        hc = [L.fc[qs_[0]][0], L.fc[qs_[1]][1], L.fc[qs_[2]][2],
                              L.fc[qs_[3]][3]]
                        pts = [(L.x(i), hc[0], L.z(j)), (L.x(i + 2), hc[1], L.z(j)),
                               (L.x(i + 2), hc[2], L.z(j + 2)), (L.x(i), hc[3], L.z(j + 2))]
                        for tri, mt in zip(quad_tris(pts, cdiag), cmats):
                            sf = mt[1]
                            if not _tri_ok(*tri) and _tri_ok(*tri, deg=SLIDE_MAX_DEG):
                                sf = SURFACE_SLIPPERY
                            E.top(list(tri), mt[0], sf)
                            cnt += 1
                        _snap(L, i, i + 2, j, j + 2, tuple(hc), cdiag, done, frozen)
                        continue
                best = fit(i, i + step, j, j + step, m)
                if best is None and step == 2:
                    if least > 1:
                        continue
                    for jj in (j, j + 1):
                        for ii in (i, i + 1):
                            dualb[ii + jj * nx] = 1
                    best = fit(i, i + 1, j, j + 1, m)
                    step = 1
                if best is None:
                    if least > 1:
                        continue
                    pts = quad_points(L, q, L.fc[q])
                    diag, mats = corner.get(q, (split_of(pts), (m, m)))
                    if not all(_tri_ok(*t) for t in quad_tris(pts, diag)):
                        diag = split_of(pts)
                    if len(set(L.fc[q])) == 1 and mats[0][1] == mats[1][1] == m[1]:
                        for tri, mt in zip(quad_tris(pts, diag), mats):
                            E.top(list(tri), mt[0], None)
                            cnt += 1
                        flats[q] = (L.fc[q][0], m[1])
                        done[q] = True
                        for c in range(4):
                            frozen[vert(q, c)] = L.fc[q][c]
                        continue
                    for tri, mt in zip(quad_tris(pts, diag), mats):
                        if mt != m and not _tri_ok(*tri, deg=CLIFF_TRI_DEG):
                            mt = m
                        s = mt[1]
                        if not _tri_ok(*tri) and (L.steep[q] or L.soft[q] or (
                                L.src[q] >= 0 and str(pieces[L.src[q]].get("tag") or "")
                                in BANK_SLIDE_TAGS)) and _tri_ok(*tri, deg=SLIDE_MAX_DEG):
                            s = SURFACE_SLIPPERY
                        E.top(list(tri), mt[0], s)
                        cnt += 1
                    done[q] = True
                    for c in range(4):
                        frozen[vert(q, c)] = L.fc[q][c]
                    continue
                i1, j1 = i + step, j + step
                def into_blocks(a0, a1, b0, b1):
                    return step == 1 and dualb is not None and any(
                        dualb[a + b * nx] == 2 for b in range(b0, b1) for a in range(a0, a1))
                while i1 + step <= nx and i1 - i < most and \
                        int(math.floor(L.x(i1) / grid)) == gx:
                    if into_blocks(i1, i1 + step, j, j1):
                        break
                    got = fit(i, i1 + step, j, j1, m)
                    if got is None:
                        break
                    best, i1 = got, i1 + step
                while j1 + step <= nz and j1 - j < most and \
                        int(math.floor(L.z(j1) / grid)) == gz:
                    if into_blocks(i, i1, j1, j1 + step):
                        break
                    got = fit(i, i1, j, j1 + step, m)
                    if got is None:
                        break
                    best, j1 = got, j1 + step
                if (i1 - i) * (j1 - j) < least:
                    continue
                cnt += _emit_block(L, E, i, i1, j, j1, best, m, done, frozen, flats)
    _flat_collision(L, E, flats)
    return cnt
FLAT_MOST = 16
def _flat_collision(L, E, flats):
    nx = L.nx
    taken = set()
    for q in sorted(flats):
        if q in taken:
            continue
        key = flats[q]
        i0, j0 = q % nx, q // nx
        i1 = i0 + 1
        while i1 < nx and i1 - i0 < FLAT_MOST and flats.get(i1 + j0 * nx) == key \
                and (i1 + j0 * nx) not in taken:
            i1 += 1
        j1 = j0 + 1
        while j1 < L.nz and j1 - j0 < FLAT_MOST and all(
                flats.get(i + j1 * nx) == key and (i + j1 * nx) not in taken
                for i in range(i0, i1)):
            j1 += 1
        for j in range(j0, j1):
            for i in range(i0, i1):
                taken.add(i + j * nx)
        y, surface = key
        pts = [(L.x(i0), y, L.z(j0)), (L.x(i0), y, L.z(j1)), (L.x(i1), y, L.z(j1)),
               (L.x(i1), y, L.z(j0))]
        if _normal(pts)[1] < 0:
            pts = list(reversed(pts))
        if surface is not None:
            E._stand(surface, pts)
OPEN_STEPS = ((8, 14), (4, 10), (2, 6))
OPEN_WATER = ("lake", "pond", "river", "pool", "basin", "water", "shore", "fountain", "well")
def open_distance(L, pieces, most=16):
    nx, nz = L.nx, L.nz
    n = nx * nz
    dist = [most] * n
    front = []
    pinned = set()
    for (vi, vj) in L.vpin:
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if 0 <= i < nx and 0 <= j < nz:
                pinned.add(i + j * nx)
    for q in range(n):
        k = L.src[q]
        tag = str(pieces[k].get("tag", "")) if k >= 0 else ""
        if L.anchor[q] or q in L.cave or q in pinned or any(w in tag for w in OPEN_WATER):
            dist[q] = 0
            front.append(q)
    d = 0
    while front and d < most:
        d += 1
        nxt = []
        for q in front:
            i, j = q % nx, q // nx
            for dj in (-1, 0, 1):
                for di in (-1, 0, 1):
                    a, b = i + di, j + dj
                    if 0 <= a < nx and 0 <= b < nz and dist[a + b * nx] > d:
                        dist[a + b * nx] = d
                        nxt.append(a + b * nx)
        front = nxt
    return dist
def coarsen(L, pieces):
    nx, nz = L.nx, L.nz
    dist = open_distance(L, pieces)
    L.block = [1] * (nx * nz)
    L.blocks = []
    count = 0
    def height(vi, vj):
        if (vi, vj) in L.vpin:
            return None
        h = None
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if not (0 <= i < nx and 0 <= j < nz):
                continue
            q = i + j * nx
            if not L.drawn[q]:
                return None
            v = L.fc[q][c]
            if h is None:
                h = v
            elif v != h:
                return None
        return h
    def put(vi, vj, h):
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if 0 <= i < nx and 0 <= j < nz:
                L.fc[i + j * nx][c] = h
    for s, far in OPEN_STEPS:
        i_first = (-int(math.floor(L.ox / float(QUAD)))) % s
        j_first = (-int(math.floor(L.oz / float(QUAD)))) % s
        for j0 in range(j_first, nz - s + 1, s):
            for i0 in range(i_first, nx - s + 1, s):
                qs = [i + j * nx for j in range(j0, j0 + s) for i in range(i0, i0 + s)]
                if any(L.block[q] > 1 or dist[q] < far or L.anchor[q] for q in qs):
                    continue
                if len(set(L.steep[q] for q in qs)) > 1:
                    continue
                corners = {(i0, j0): L.fc[i0 + j0 * nx][0],
                           (i0 + s, j0): L.fc[i0 + s - 1 + j0 * nx][1],
                           (i0 + s, j0 + s): L.fc[i0 + s - 1 + (j0 + s - 1) * nx][2],
                           (i0, j0 + s): L.fc[i0 + (j0 + s - 1) * nx][3]}
                hs = {}
                for vj in range(j0, j0 + s + 1):
                    for vi in range(i0, i0 + s + 1):
                        if (vi, vj) in corners:
                            continue
                        h = height(vi, vj)
                        if h is None:
                            break
                        hs[(vi, vj)] = h
                    else:
                        continue
                    break
                if len(hs) != (s + 1) * (s + 1) - 4:
                    continue
                A, B = corners[(i0, j0)], corners[(i0 + s, j0)]
                C, D = corners[(i0 + s, j0 + s)], corners[(i0, j0 + s)]
                for (vi, vj) in hs:
                    u, v = (vi - i0) / float(s), (vj - j0) / float(s)
                    h = (A * (1 - u) * (1 - v) + B * u * (1 - v) + C * u * v
                         + D * (1 - u) * v)
                    put(vi, vj, int(round(h)))
                for q in qs:
                    L.block[q] = s
                L.blocks.append((i0, j0, s))
                count += 1
    return count
def _emit_block(L, E, i, i1, j, j1, got, m, done, frozen, flats=None):
    (A, B, C, D), diag = got
    _snap(L, i, i1, j, j1, (A, B, C, D), diag, done, frozen)
    pts = [(L.x(i), A, L.z(j)), (L.x(i), D, L.z(j1)),
           (L.x(i1), C, L.z(j1)), (L.x(i1), B, L.z(j))]
    if flats is not None and A == B == C == D:
        E.top(pts, m[0], None)
        for jj in range(j, j1):
            for ii in range(i, i1):
                flats[ii + jj * L.nx] = (A, m[1])
        return 2
    if A + C == B + D and (not L.steep[i + j * L.nx] or _tri_ok(*pts[:3])):
        E.top(pts, m[0], m[1])
    else:
        p0, p3, p2, p1 = pts
        for tri in quad_tris([p0, p1, p2, p3], diag):
            s = m[1]
            if not _tri_ok(*tri) and _tri_ok(*tri, deg=SLIDE_MAX_DEG):
                s = SURFACE_SLIPPERY
            E.top(list(tri), m[0], s)
    return 2
def steep_quads(L, rounds=2):
    nx, nz = L.nx, L.nz
    out = [L.soft[q] and not L.steep[q] and quad_grade(L.fc[q])[1] >= SLOPE_TEX_GRADE
           for q in range(nx * nz)]
    for _ in range(rounds):
        new = list(out)
        for q in range(nx * nz):
            if not L.soft[q]:
                continue
            i, j = q % nx, q // nx
            yes = tot = 0
            for dj in (-1, 0, 1):
                for di in (-1, 0, 1):
                    a, b = i + di, j + dj
                    if 0 <= a < nx and 0 <= b < nz and L.soft[a + b * nx]:
                        tot += 1
                        yes += out[a + b * nx]
            new[q] = 2 * yes > tot
        out = new
    return out
def _interp(A, B, C, D, u, v, diag):
    if diag == 0:
        if u >= v:
            return A + (B - A) * u + (C - B) * v
        return A + (C - D) * u + (D - A) * v
    if u + v <= 1:
        return A + (B - A) * u + (D - A) * v
    return C + (D - C) * (1 - u) + (B - C) * (1 - v)
def _snap(L, i0, i1, j0, j1, corners, diag, done, frozen):
    nx, nz = L.nx, L.nz
    A, B, C, D = corners
    wi, wj = float(i1 - i0), float(j1 - j0)
    for vj in range(j0, j1 + 1):
        for vi in range(i0, i1 + 1):
            new = int(round(_interp(A, B, C, D, (vi - i0) / wi, (vj - j0) / wj, diag)))
            inside = []
            outside = []
            for (di, dj), c in ROUND:
                i, j = vi + di, vj + dj
                if not (0 <= i < nx and 0 <= j < nz):
                    continue
                q = i + j * nx
                if i0 <= i < i1 and j0 <= j < j1:
                    inside.append((q, c))
                else:
                    outside.append((q, c))
            old = L.fc[inside[0][0]][inside[0][1]]
            for q, c in inside:
                L.fc[q][c] = new
                done[q] = True
            for q, c in outside:
                if not done[q] and not L.anchor[q] and L.fc[q][c] == old:
                    L.fc[q][c] = new
            frozen[(vi, vj)] = new
def _strata(col, lo, hi, fallback, rock=None, layered=()):
    out = []
    for (y0, y1, slug, _) in col:
        a, b = max(lo, y0), min(hi, y1)
        if b > a:
            out.append([a, b, slug])
    if not out:
        out = [[lo, hi, fallback]]
    out.sort()
    out[0][0] = lo
    out[-1][1] = hi
    for k in range(1, len(out)):
        out[k][0] = out[k - 1][1]
    out = [s for s in out if s[1] > s[0]]
    top = out[-1]
    under = out[-2][2] if len(out) > 1 else rock
    if under and top[2] not in layered and top[2] != under and top[1] - top[0] > LIP + 20:
        cut = top[1] - LIP
        if len(out) > 1:
            out[-2][1] = cut
        else:
            out.insert(0, [top[0], cut, under])
        out[-1][0] = cut
    return [tuple(s) for s in out if s[1] > s[0]]
def emit_walls(L, E, pieces, outside=None):
    nx, nz = L.nx, L.nz
    floor = L.floor
    def fc_or_floor(i, j, c):
        if 0 <= i < nx and 0 <= j < nz:
            q = i + j * nx
            return L.fc[q][c] if (L.drawn[q] or L.src[q] >= 0) else floor
        if outside is not None:
            di, dj = CORNER_OFF[c]
            got = outside.get((i + di, j + dj))
            if got is not None:
                return got
        return floor
    def column(i, j):
        if 0 <= i < nx and 0 <= j < nz:
            q = i + j * nx
            k = L.src[q]
            tex = pieces[k]["tex"] if k >= 0 else E.floor_tex
            return L.col[q], tex
        return [], E.floor_tex
    lines = {}
    for axis in (0, 1):
        for j in range(nz + (1 if axis else 0)):
            for i in range(nx + (0 if axis else 1)):
                if axis == 0:
                    a, b = (i - 1, j), (i, j)
                    ha = (fc_or_floor(i - 1, j, 1), fc_or_floor(i - 1, j, 2))
                    hb = (fc_or_floor(i, j, 0), fc_or_floor(i, j, 3))
                    t0, t1 = j, j + 1
                    na = (-1.0, 0.0, 0.0)
                else:
                    a, b = (i, j - 1), (i, j)
                    ha = (fc_or_floor(i, j - 1, 3), fc_or_floor(i, j - 1, 2))
                    hb = (fc_or_floor(i, j, 0), fc_or_floor(i, j, 1))
                    t0, t1 = i, i + 1
                    na = (0.0, 0.0, -1.0)
                if ha == hb:
                    continue
                if not any(0 <= c[0] < nx and 0 <= c[1] < nz for c in (a, b)):
                    continue
                nb = (-na[0], 0.0, -na[2])
                at = i if axis == 0 else j
                d0, d1 = ha[0] - hb[0], ha[1] - hb[1]
                if d0 >= 0 and d1 >= 0:
                    segs = [(t0, t1, ha, hb, a, nb)]
                elif d0 <= 0 and d1 <= 0:
                    segs = [(t0, t1, hb, ha, b, na)]
                else:
                    f = d0 / float(d0 - d1)
                    tm = t0 + f
                    hm = ha[0] + (ha[1] - ha[0]) * f
                    if d0 > 0:
                        segs = [(t0, tm, (ha[0], hm), (hb[0], hm), a, nb),
                                (tm, t1, (hm, hb[1]), (hm, ha[1]), b, na)]
                    else:
                        segs = [(t0, tm, (hb[0], hm), (ha[0], hm), b, na),
                                (tm, t1, (hm, ha[1]), (hm, hb[1]), a, nb)]
                for s0, s1, top, foot, upper, n in segs:
                    cq = upper[0] + upper[1] * nx if (0 <= upper[0] < nx
                                                      and 0 <= upper[1] < nz) else None
                    if cq in L.cave and max(foot) <= L.cave[cq][1]:
                        ceil = L.cave[cq][1]
                        if min(top) <= ceil:
                            continue
                        foot = (max(foot[0], ceil), max(foot[1], ceil))
                    col, tex = column(*upper)
                    if min(foot) < VOID_DEEP:
                        bottom = min([c_[0] for c_ in col] or [0])
                        foot = (max(foot[0], bottom), max(foot[1], bottom))
                        if top[0] <= foot[0] and top[1] <= foot[1]:
                            continue
                    out_ = not (0 <= upper[0] < nx and 0 <= upper[1] < nz)
                    sig = (tex, tuple((c[0], c[1], c[2]) for c in col), out_)
                    lines.setdefault((axis, at, n), []).append((s0, s1, top, foot, sig, col, tex))
    walls = 0
    for (axis, at, n), segs in sorted(lines.items()):
        segs.sort(key=lambda s: s[0])
        run = None
        for seg in segs:
            if run is not None and _continues(run, seg):
                run = _extend(run, seg)
                continue
            if run is not None:
                _wall_run(L, E, axis, at, run, n)
                walls += 1
            run = seg
        if run is not None:
            _wall_run(L, E, axis, at, run, n)
            walls += 1
    return walls
def _continues(run, seg):
    s0, s1, top, foot, sig = run[:5]
    t0, t1, top2, foot2, sig2 = seg[:5]
    if t0 != s1 or sig != sig2 or top2[0] != top[1] or foot2[0] != foot[1]:
        return False
    if int(math.floor(s0 * QUAD / SPLIT)) != int(math.floor((t1 * QUAD - 1e-6) / SPLIT)):
        return False
    if (t1 - t0) <= 0 or (s1 - s0) <= 0:
        return False
    k_top = (top[1] - top[0]) / float(s1 - s0)
    k_foot = (foot[1] - foot[0]) / float(s1 - s0)
    return abs((top2[1] - top2[0]) / float(t1 - t0) - k_top) < 1e-6 and \
        abs((foot2[1] - foot2[0]) / float(t1 - t0) - k_foot) < 1e-6
def _extend(run, seg):
    return (run[0], seg[1], (run[2][0], seg[2][1]), (run[3][0], seg[3][1])) + tuple(run[4:])
def _wall_run(L, E, axis, at, run, n):
    s0, s1, top, foot, sig, col, tex = run
    def at_point(t):
        if axis == 0:
            return (L.ox + at * QUAD, L.oz + t * QUAD)
        return (L.ox + t * QUAD, L.oz + at * QUAD)
    _wall_poly(E, at_point(s0), at_point(s1), top, foot, col, tex, n, own_uv=sig[2])
def _planar(p, n):
    from .outland import planar_uv
    return planar_uv(p, n, 640.0)
def _wall_poly(E, s0, s1, top, foot, col, tex, n, own_uv=False):
    lo = min(foot)
    hi = max(top)
    if hi - lo < 1:
        return
    def poly_of(b0, b1, t0, t1):
        poly = []
        for (x, z), y in (((s0[0], s0[1]), b0), ((s1[0], s1[1]), b1),
                          ((s1[0], s1[1]), t1), ((s0[0], s0[1]), t0)):
            pt = (int(round(x)), int(round(y)), int(round(z)))
            if not poly or poly[-1] != pt:
                poly.append(pt)
        if len(poly) > 1 and poly[0] == poly[-1]:
            poly.pop()
        return poly if len(poly) >= 3 else None
    whole = poly_of(foot[0], foot[1], top[0], top[1])
    if whole is None:
        return
    E.wall(whole, None, n, draw=False)
    corners = [(s0[0], foot[0], s0[1]), (s1[0], foot[1], s1[1]),
               (s1[0], top[1], s1[1]), (s0[0], top[0], s0[1])]
    for (y0, y1, slug) in _strata(col, lo, hi, tex, E.rock, E.layered):
        poly = _band(corners, y0, y1)
        if poly is not None:
            E.wall(poly, slug, n, surface=None, uv=_planar if own_uv else None)
def _band(poly, y0, y1):
    def clip(pts, keep, cut):
        out = []
        m = len(pts)
        for k in range(m):
            p, q = pts[k], pts[(k + 1) % m]
            kp, kq = keep(p), keep(q)
            if kp:
                out.append(p)
            if kp != kq:
                u = (cut - p[1]) / float(q[1] - p[1])
                out.append((p[0] + u * (q[0] - p[0]), cut, p[2] + u * (q[2] - p[2])))
        return out
    pts = clip(list(poly), lambda p: p[1] >= y0, y0)
    if pts:
        pts = clip(pts, lambda p: p[1] <= y1, y1)
    out = []
    for p in pts:
        pt = (int(round(p[0])), int(round(p[1])), int(round(p[2])))
        if not out or out[-1] != pt:
            out.append(pt)
    while len(out) > 1 and out[0] == out[-1]:
        out.pop()
    if len(out) < 3:
        return None
    a = out[0]
    for k in range(1, len(out) - 1):
        b, c = out[k], out[k + 1]
        cx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
        cy = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2])
        cz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if cx or cy or cz:
            return out
    return None
def passages(L, E, pieces):
    nx, nz = L.nx, L.nz
    before = len(E.out.faces)
    for q, (floor, ceil) in sorted(L.cave.items()):
        i, j = q % nx, q // nx
        x0, x1, z0, z1 = L.x(i), L.x(i + 1), L.z(j), L.z(j + 1)
        segs = L.col[q]
        under = [s for s in segs if s[1] <= floor + 1]
        over = [s for s in segs if s[0] >= ceil - 1]
        ftex = max(under, key=lambda s: s[1])[2] if under else E.floor_tex
        rtex = min(over, key=lambda s: s[0])[2] if over else (E.rock or ftex)
        E.top([(x0, floor, z0), (x1, floor, z0), (x1, floor, z1), (x0, floor, z1)], ftex,
              SURFACE_DEFAULT)
        pts = [(x0, ceil, z0), (x1, ceil, z0), (x1, ceil, z1), (x0, ceil, z1)]
        corners = [(p[0], p[1], p[2], p[0] * TEX_UNIT, p[2] * TEX_UNIT) for p in pts]
        E.out.faces.append((corners, (0.0, -1.0, 0.0), E.tex_key(rtex, (0, -1, 0)),
                            _extent(pts), False, False))
        E._stand(SURFACE_DEFAULT, pts)
        for di, dj, n in ((-1, 0, (1.0, 0.0, 0.0)), (1, 0, (-1.0, 0.0, 0.0)),
                          (0, -1, (0.0, 0.0, 1.0)), (0, 1, (0.0, 0.0, -1.0))):
            a, b = i + di, j + dj
            r = a + b * nx if (0 <= a < nx and 0 <= b < nz) else None
            if r in L.cave:
                continue
            side = min(L.fc[r]) if r is not None and (L.drawn[r] or L.src[r] >= 0) else L.floor
            top = min(ceil, side)
            if top <= floor + 1:
                continue
            if di:
                xs = x0 if di < 0 else x1
                pts = [(xs, floor, z0), (xs, floor, z1), (xs, top, z1), (xs, top, z0)]
            else:
                zs = z0 if dj < 0 else z1
                pts = [(x0, floor, zs), (x1, floor, zs), (x1, top, zs), (x0, top, zs)]
            E.wall(pts, rtex, n)
    return len(E.out.faces) - before
WATER_HOLD = 10
HOLD_RING = 2
HOLD_LIP = 10
HOLD_REACH = 4
def _held_round(L, own, top, wet):
    nx, nz = L.nx, L.nz
    seen = set(own)
    front = list(own)
    most = HOLD_REACH * len(own) + 50
    while front:
        nxt = []
        for q in front:
            i, j = q % nx, q // nx
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if not (0 <= a < nx and 0 <= b < nz):
                    return False
                r = a + b * nx
                if r in seen or (r in wet and r not in own):
                    continue
                if not L.drawn[r] or min(L.fc[r]) >= top - WATER_HOLD:
                    continue
                seen.add(r)
                if len(seen) > most:
                    return False
                nxt.append(r)
        front = nxt
    return True
def hold_water(L, pieces):
    nx, nz = L.nx, L.nz
    raised = 0
    wet = set()
    for p in pieces:
        if is_sheet(p):
            x0, x1, z0, z1 = _footprint(p)
            wet.update(_quads_in(L, [(x0, x1, z0, z1)]))
    for k, p in enumerate(pieces):
        if not is_sheet(p):
            continue
        top = p["y"] + p["h"]
        x0, x1, z0, z1 = _footprint(p)
        own = set(_quads_in(L, [(x0, x1, z0, z1)]))
        if not own:
            continue
        if _held_round(L, own, top, wet):
            continue
        ring = set(own)
        for _ in range(HOLD_RING):
            nxt = set()
            for q in ring:
                i, j = q % nx, q // nx
                for b in (-1, 0, 1):
                    for a in (-1, 0, 1):
                        if 0 <= i + a < nx and 0 <= j + b < nz:
                            nxt.add(i + a + (j + b) * nx)
            ring |= nxt
        verts = set()
        for q in ring:
            i, j = q % nx, q // nx
            for c, (di, dj) in enumerate(CORNER_OFF):
                vi, vj = i + di, j + dj
                for (ei, ej), cc in ROUND:
                    a, b = vi + ei, vj + ej
                    if 0 <= a < nx and 0 <= b < nz and (a + b * nx) not in ring:
                        verts.add((vi, vj))
                        break
        want = top + HOLD_LIP
        for (vi, vj) in verts:
            refs = []
            for (ei, ej), cc in ROUND:
                a, b = vi + ei, vj + ej
                if 0 <= a < nx and 0 <= b < nz and L.drawn[a + b * nx]:
                    refs.append((a + b * nx, cc))
            if not refs or all(L.fc[q][c] >= top - WATER_HOLD for q, c in refs):
                continue
            if any(not L.soft[q] or q in wet for q, c in refs) or (vi, vj) in L.vpin:
                continue
            low = min(L.fc[q][c] for q, c in refs)
            for q, c in refs:
                if L.fc[q][c] == low or L.fc[q][c] < want:
                    L.fc[q][c] = max(L.fc[q][c], want)
            raised += 1
    return raised
def _banked(L, level, r):
    nx, nz = L.nx, L.nz
    top = level[r]
    i, j = r % nx, r // nx
    for c, (di, dj) in enumerate(CORNER_OFF):
        vi, vj = i + di, j + dj
        for (ei, ej), cc in ROUND:
            a, b = vi + ei, vj + ej
            if not (0 <= a < nx and 0 <= b < nz):
                return False
            n = a + b * nx
            if n == r or n in level:
                continue
            if L.fc[n][cc] < top - WATER_HOLD:
                return False
    return True
def waters(L, pieces, sheets):
    nx, nz = L.nx, L.nz
    level = {}
    tex = {}
    flows = set()
    for k in sheets:
        p = pieces[k]
        x0, x1, z0, z1 = _footprint(p)
        top = p["y"] + p["h"]
        for q in _quads_in(L, [(x0, x1, z0, z1)]):
            if q not in level or top > level[q]:
                level[q], tex[q] = top, p["tex"]
                if str(p.get("tag", "")).startswith("river"):
                    flows.add(q)
                else:
                    flows.discard(q)
    edge = dict(level)
    for ring in range(WATER_GROW):
        grown = {}
        for q, top in edge.items():
            i, j = q % nx, q // nx
            for dj in (-1, 0, 1):
                for di in (-1, 0, 1):
                    a, b = i + di, j + dj
                    r = a + b * nx
                    if not (0 <= a < nx and 0 <= b < nz) or r in level:
                        continue
                    if min(L.fc[r]) >= top or (r in grown and top <= grown[r][0]):
                        continue
                    if ring and min(L.fc[r]) < top - WATER_SHALLOW:
                        continue
                    grown[r] = (top, tex[q], q in flows)
        if not grown:
            break
        for r, (top, t, _f) in grown.items():
            level[r], tex[r] = top, t
        edge = dict((r, g[0]) for r, g in grown.items() if g[2] and max(L.fc[r]) < g[0]
                    and min(L.fc[r]) >= g[0] - WATER_SHALLOW)
        flows |= set(edge)
    first = set()
    for k in sheets:
        p = pieces[k]
        x0, x1, z0, z1 = _footprint(p)
        first.update(_quads_in(L, [(x0, x1, z0, z1)]))
    grown_ = set(level) - first
    changed = True
    while changed:
        changed = False
        for r in sorted(grown_):
            if not _banked(L, level, r):
                del level[r]
                grown_.discard(r)
                changed = True
    out = []
    def face(pts, n, t):
        corners = [(p[0], p[1], p[2], p[0] * TEX_UNIT, p[2] * TEX_UNIT) for p in pts]
        out.append((corners, n, (t, 0), _extent(pts)))
    for j in range(nz):
        i = 0
        while i < nx:
            q = i + j * nx
            if q not in level:
                i += 1
                continue
            i1 = i + 1
            while i1 < nx and level.get(i1 + j * nx) == level[q] and \
                    tex.get(i1 + j * nx) == tex[q] and i1 - i < 30:
                i1 += 1
            y = level[q]
            x0, x1, z0, z1 = L.x(i), L.x(i1), L.z(j), L.z(j + 1)
            face([(x0, y, z0), (x0, y, z1), (x1, y, z1), (x1, y, z0)], (0.0, 1.0, 0.0), tex[q])
            face([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], (0.0, -1.0, 0.0), tex[q])
            i = i1
    for q, top in sorted(level.items()):
        i, j = q % nx, q // nx
        for di, dj in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            a, b = i + di, j + dj
            r = a + b * nx
            if not (0 <= a < nx and 0 <= b < nz) or r not in level or level[r] >= top - 20:
                continue
            low = level[r]
            if di:
                xs = L.x(i + 1) if di > 0 else L.x(i)
                pts = [(xs, low, L.z(j)), (xs, low, L.z(j + 1)), (xs, top, L.z(j + 1)),
                       (xs, top, L.z(j))]
            else:
                zs = L.z(j + 1) if dj > 0 else L.z(j)
                pts = [(L.x(i), low, zs), (L.x(i + 1), low, zs), (L.x(i + 1), top, zs),
                       (L.x(i), top, zs)]
            n = (float(di), 0.0, float(dj))
            corners = [(p[0], p[1], p[2], (p[0] + p[2]) * TEX_UNIT, -p[1] * TEX_UNIT)
                       for p in pts]
            out.append((corners, n, (tex[q], 0), _extent(pts)))
            out.append((list(reversed(corners)), (-n[0], 0.0, -n[2]), (tex[q], 0), _extent(pts)))
    return out
def occluders(L):
    rows = []
    nx, nz = L.nx, L.nz
    base = L.floor - 400
    for j in range(nz):
        i = 0
        while i < nx:
            q = i + j * nx
            if not (L.drawn[q] or L.src[q] >= 0):
                i += 1
                continue
            top = min(L.fc[q])
            i1 = i + 1
            while i1 < nx and (L.drawn[i1 + j * nx] or L.src[i1 + j * nx] >= 0) \
                    and min(L.fc[i1 + j * nx]) == top:
                i1 += 1
            if top > base:
                x0, x1 = L.x(i), L.x(i1)
                z0, z1 = L.z(j), L.z(j + 1)
                rows.append(("box", "terrain", (x0 + x1) / 2.0, base, (z0 + z1) / 2.0,
                             x1 - x0, top - base, z1 - z0, 0))
            i = i1
    return rows
BACKDROP_STEP = 1400
BACKDROP_REACH = 29000
BACKDROP_GAP = 1800
SKIRT_UNDER = 20
def backdrop(E, half, seed, rock, snow=None, floor=0, height=None, ground=None, skirt=False):
    inner = half + BACKDROP_GAP
    outer = min(BACKDROP_REACH, max(inner + 7000, half * 2.4))
    if outer - inner < 4000:
        return 0
    lowest = floor - 300
    if skirt:
        lowest = floor - SKIRT_UNDER
    height = height or max(3000, min(8000, half * 0.5))
    step = BACKDROP_STEP
    n = int(math.ceil(outer / step))
    def h_at(x, z):
        d = max(abs(x), abs(z))
        t = (d - inner) / float(outer - inner)
        if t <= 0:
            return lowest
        ridge = 1.0 - abs(noise(x, z, seed + "/ridge", 6000))
        ridge2 = 1.0 - abs(noise(x * 1.7, z * 1.7, seed + "/ridge2", 3000))
        mass = 0.5 + 0.5 * noise(x, z, seed + "/mass", 14000)
        rise = min(1.0, t * 1.8) ** 1.4
        shape = (0.55 * ridge * ridge + 0.25 * ridge2 * ridge2 + 0.2) * (0.35 + 0.65 * mass)
        return floor - 300 + height * rise * shape
    pts = {}
    for j in range(-n, n + 1):
        for i in range(-n, n + 1):
            x = max(-outer, min(outer, i * step))
            z = max(-outer, min(outer, j * step))
            jx = 0.3 * step * noise(x, z, seed + "/jx", 2100)
            jz = 0.3 * step * noise(x, z, seed + "/jz", 2100)
            if max(abs(x), abs(z)) <= inner or max(abs(x), abs(z)) >= outer:
                jx = jz = 0.0
            x, z = x + jx, z + jz
            pts[(i, j)] = (int(round(x)), int(round(h_at(x, z))), int(round(z)))
    tris = 0
    for j in range(-n, n):
        for i in range(-n, n):
            corners = [pts[(i, j)], pts[(i, j + 1)], pts[(i + 1, j + 1)], pts[(i + 1, j)]]
            if max(max(abs(c[0]), abs(c[2])) for c in corners) <= (half if skirt else inner):
                continue
            if not skirt and all(c[1] <= floor - 300 for c in corners):
                continue
            for tri in ((corners[0], corners[1], corners[2]), (corners[0], corners[2], corners[3])):
                if not skirt and all(c[1] <= floor - 300 for c in tri):
                    continue
                top = max(c[1] for c in tri)
                mean = sum(c[1] for c in tri) / 3.0
                nrm = _normal(list(tri))
                if snow and top > floor + 0.62 * height and nrm[1] > 0.55:
                    slug = snow
                elif ground and mean < floor + 0.16 * height and nrm[1] > 0.8:
                    slug = ground
                else:
                    slug = rock
                E.top(list(tri), slug, None, split=False)
                tris += 1
    return tris
def points_of(arena):
    out = []
    for s in arena.get("spawns") or []:
        out.append((s["x"], s.get("y", 0), s["z"]))
    for s in (arena.get("survey") or {}).get("points") or []:
        out.append((s["x"], s.get("y", 0), s["z"]))
    for key in ("stars", "objects", "movers", "markers"):
        for o in arena.get(key) or []:
            if isinstance(o, dict) and "x" in o and "z" in o:
                out.append((o["x"], o.get("y", 0), o["z"]))
    return out
GROUND_SHARE = {"collision_triangles": 0.6, "draw_triangles": 0.35}
LADDER = ({}, {"tolerance": 20}, {"tolerance": 30, "warp": False},
          {"tolerance": 45, "warp": False})
def ladder(arena):
    from . import budget
    import os
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake
    textures, layered = venuebake.kit_textures()
    base = dict(arena.get("terrain") or {})
    lines = dict((k, budget.BAKED_METERS[k][0] * f) for k, f in GROUND_SHARE.items())
    t = None
    for k, step in enumerate(LADDER):
        spec = dict(base, **step)
        t = build(dict(arena, terrain=spec), layered=layered, known=textures)
        if t is None:
            return spec, "no ground pieces"
        drawn = t.stats["top_triangles"] + 2 * t.stats["wall_faces"]
        if t.stats["ground_collision"] <= lines["collision_triangles"] and \
                drawn <= lines["draw_triangles"]:
            break
    how = "%d collision and ~%d drawn triangles%s" % (
        t.stats["ground_collision"], t.stats["top_triangles"] + 2 * t.stats["wall_faces"],
        "" if not k else " (simplified %d step%s: %s)" % (
            k, "" if k == 1 else "s", ", ".join("%s %s" % kv for kv in sorted(LADDER[k].items()))))
    return spec, how
def build(arena, layered=(), detail=True, known=None):
    global QUAD, MERGE
    spec = arena.get("terrain") or {}
    quad = spec.get("quad", QUAD)
    if quad not in QUADS:
        raise ValueError("terrain quad %r is not one of %s" % (quad, QUADS))
    was = QUAD, MERGE
    QUAD, MERGE = quad, SPLIT // quad
    try:
        return _build(arena, spec, layered, detail, known)
    finally:
        QUAD, MERGE = was
def _shape(arena, spec, detail, idx, floor, seed, outlined):
    from . import outland
    pieces = arena["pieces"]
    cover = None
    if outlined and (spec.get("backdrop") or {}).get("half"):
        w = spec["backdrop"]["half"] - BACKDROP_MARGIN
        cover = (-w, w, -w, w)
    L = raster(pieces, idx, floor if floor is not None else -10 ** 6,
               align=outland.OUT_QUAD if outlined else None, cover=cover)
    void_ok = floor is not None
    anchor(L, pieces, idx, points_of(arena))
    for q in _quads_in(L, spec.get("held")):
        L.anchor[q] = True
    for q in L.cave:
        L.anchor[q] = True
    for q in range(L.nx * L.nz):
        k = L.src[q]
        if k >= 0 and str(pieces[k].get("tag", "")) in SHORE_HELD:
            L.anchor[q] = True
    for q in range(L.nx * L.nz):
        L.soft[q] = (not L.anchor[q]) and (L.src[q] >= 0 or void_ok)
    for q in _quads_in(L, spec.get("steep")):
        L.steep[q] = L.soft[q]
    L.still = river_quads(L, pieces)
    warped = warp(L, seed) if spec.get("warp", True) else 0
    relaxed, broken = smooth(L, seed, detail=detail and spec.get("detail", False),
                             erosion=spec.get("erosion", True))
    back = legalise(L)
    river_banks(L, pieces)
    draped = drape(L, pieces)
    for q in range(L.nx * L.nz):
        if L.src[q] >= 0:
            L.drawn[q] = True
        elif void_ok:
            L.drawn[q] = max(L.fc[q]) > floor
    return L, (warped, relaxed, broken, back, draped)
MULTI_FAR = 1
MULTI_SPAWN = 2000
MULTI_ERR = 60
MULTI_SIZES = (8, 4, 2)
DUAL_SPAWN = 1600
DUAL_STITCH = 160
DUAL_KEEP_ANCHORS = True
DUAL_WATER = ("lake", "pond", "river", "pool", "basin", "water", "shore", "fountain", "well")
DUAL_WAY_KINDS = ("ramp", "inner", "outer")
DUAL_WAY_TAGS = ("slope", "hills.ramp", "path", "road", "lane", "street", "plaza", "way")
def _coarse(arena, spec, detail, idx, floor, seed, outlined, E):
    global QUAD, MERGE
    was = QUAD, MERGE
    QUAD, MERGE = 400, SPLIT // 400
    try:
        L4, _ = _shape(arena, spec, detail, idx, floor, seed, outlined)
        mat = materials(L4, E, arena["pieces"])
        mats = [mat(q) if L4.drawn[q] else None for q in range(L4.nx * L4.nz)]
        corners = material_corners(L4, mat)
    finally:
        QUAD, MERGE = was
    return L4, mats, corners
def dual(L, L4, mats4, corners4, pieces, spawns):
    nx, nz = L.nx, L.nz
    n = nx * nz
    fine = [False] * n
    for q in range(n):
        k = L.src[q]
        tag = str(pieces[k].get("tag", "")) if k >= 0 else ""
        if q in L.cave or any(w in tag for w in DUAL_WATER) or not L.drawn[q] or \
                (DUAL_KEEP_ANCHORS and L.anchor[q]):
            fine[q] = True
            continue
        cx, cz = L.x(q % nx) + QUAD / 2.0, L.z(q // nx) + QUAD / 2.0
        if any(math.hypot(cx - sx, cz - sz) < DUAL_SPAWN for sx, sz in spawns):
            fine[q] = True
    for q in range(n):
        k = L.src[q]
        if k >= 0 and (pieces[k].get("kind") in DUAL_WAY_KINDS or
                       str(pieces[k].get("tag", "")).startswith(DUAL_WAY_TAGS)):
            fine[q] = True
    grow = [q for q in range(n) if fine[q] and L.drawn[q] and (q in L.cave or (
        L.src[q] >= 0 and (any(w in str(pieces[L.src[q]].get("tag", "")) for w in DUAL_WATER)
                           or pieces[L.src[q]].get("kind") in DUAL_WAY_KINDS
                           or str(pieces[L.src[q]].get("tag", "")).startswith(DUAL_WAY_TAGS))))]
    for q in grow:
        i, j = q % nx, q // nx
        for b in (-1, 0, 1):
            for a in (-1, 0, 1):
                if 0 <= i + a < nx and 0 <= j + b < nz:
                    fine[i + a + (j + b) * nx] = True
    parent = [None] * n
    for q in range(n):
        if fine[q]:
            continue
        x, z = L.x(q % nx), L.z(q // nx)
        i4, j4 = (x - L4.ox) // 400, (z - L4.oz) // 400
        if not (0 <= i4 < L4.nx and 0 <= j4 < L4.nz) or not L4.drawn[i4 + j4 * L4.nx]:
            fine[q] = True
            continue
        q4 = i4 + j4 * L4.nx
        A, B, C, D = L4.fc[q4]
        x0, z0 = L4.ox + i4 * 400, L4.oz + j4 * 400
        diag = corners4[q4][0] if q4 in corners4 else split_of(
            [(x0, A, z0), (x0 + 400, B, z0), (x0 + 400, C, z0 + 400), (x0, D, z0 + 400)])
        hc = []
        for c, (di, dj) in enumerate(CORNER_OFF):
            u = (x + di * QUAD - x0) / 400.0
            v = (z + dj * QUAD - z0) / 400.0
            hc.append(int(round(_interp(A, B, C, D, u, v, diag))))
        L.fc[q] = hc
        parent[q] = q4
    for vj in range(nz + 1):
        for vi in range(nx + 1):
            refs = []
            for (di, dj), c in ROUND:
                i, j = vi + di, vj + dj
                if 0 <= i < nx and 0 <= j < nz and L.drawn[i + j * nx]:
                    refs.append((i + j * nx, c))
            kinds = set(fine[q] for q, c in refs)
            if len(kinds) < 2:
                continue
            hc = set(L.fc[q][c] for q, c in refs if not fine[q])
            hf = set(L.fc[q][c] for q, c in refs if fine[q])
            if len(hc) == 1 and len(hf) == 1 and not any(L.anchor[q] for q, c in refs):
                a, b = hc.pop(), hf.pop()
                if a != b and abs(a - b) <= DUAL_STITCH and (vi, vj) not in L.vpin:
                    for q, c in refs:
                        if fine[q]:
                            L.fc[q][c] = a
    L.block = [1] * n
    L.blocks = []
    L.block_mat = {}
    L.block_corner = {}
    L.blocks_first = False
    taken = 0
    for j0 in range(nz - 1):
        for i0 in range(nx - 1):
            qs = [i0 + j0 * nx, i0 + 1 + j0 * nx, i0 + 1 + (j0 + 1) * nx, i0 + (j0 + 1) * nx]
            if parent[qs[0]] is None or any(parent[q] != parent[qs[0]] or L.block[q] > 1
                                            for q in qs):
                continue
            for q in qs:
                L.block[q] = 2
            L.blocks.append((i0, j0, 2))
            L.block_mat[(i0, j0)] = mats4[parent[qs[0]]]
            if parent[qs[0]] in corners4:
                L.block_corner[(i0, j0)] = corners4[parent[qs[0]]]
            taken += 1
    return taken
def multires(L, pieces, spawns):
    nx, nz = L.nx, L.nz
    dist = open_distance(L, pieces)
    L.block = [1] * (nx * nz)
    L.blocks = []
    taken = 0
    def put(vi, vj, h, inside, old):
        for (di, dj), c in ROUND:
            i, j = vi + di, vj + dj
            if not (0 <= i < nx and 0 <= j < nz):
                continue
            q = i + j * nx
            if q in inside or (L.drawn[q] and L.fc[q][c] == old):
                L.fc[q][c] = h
    for s in MULTI_SIZES:
        span = s * QUAD
        far = MULTI_FAR + (s // 2 - 1)
        for j0 in range(0, nz - s + 1):
            z0 = L.z(j0)
            if z0 % span:
                continue
            for i0 in range(0, nx - s + 1):
                x0 = L.x(i0)
                if x0 % span:
                    continue
                qs = [i + j * nx for j in range(j0, j0 + s) for i in range(i0, i0 + s)]
                if any(not L.drawn[q] or L.anchor[q] or dist[q] < far or L.block[q] > 1
                       for q in qs):
                    continue
                if len(set(L.steep[q] for q in qs)) > 1:
                    continue
                cx, cz = x0 + span / 2.0, z0 + span / 2.0
                if any(math.hypot(cx - sx, cz - sz) < MULTI_SPAWN + span / 2.0
                       for sx, sz in spawns):
                    continue
                A = L.fc[i0 + j0 * nx][0]
                B = L.fc[i0 + s - 1 + j0 * nx][1]
                C = L.fc[i0 + s - 1 + (j0 + s - 1) * nx][2]
                D = L.fc[i0 + (j0 + s - 1) * nx][3]
                pts = [(x0, A, z0), (x0 + span, B, z0), (x0 + span, C, z0 + span),
                       (x0, D, z0 + span)]
                diag = split_of(pts)
                if not all(_tri_ok(*t) for t in quad_tris(pts, diag)):
                    continue
                own = {}
                for q in qs:
                    qi, qj = q % nx, q // nx
                    for c, (di, dj) in enumerate(CORNER_OFF):
                        own.setdefault((qi + di, qj + dj), []).append((q, c))
                corners = {(i0, j0), (i0 + s, j0), (i0 + s, j0 + s), (i0, j0 + s)}
                new, ok = {}, True
                for (vi, vj), refs in own.items():
                    if (vi, vj) in corners:
                        continue
                    hs = set(L.fc[q][c] for q, c in refs)
                    if len(hs) > 1 or (vi, vj) in L.vpin:
                        ok = False
                        break
                    h = int(round(_interp(A, B, C, D, (vi - i0) / float(s), (vj - j0) / float(s),
                                          diag)))
                    if abs(hs.pop() - h) > MULTI_ERR:
                        ok = False
                        break
                    new[(vi, vj)] = h
                if not ok:
                    continue
                if any(len(set(L.fc[i + j * nx][c] for (di, dj), c in ROUND
                               for i, j in [(vi + di, vj + dj)]
                               if 0 <= i < nx and 0 <= j < nz and L.drawn[i + j * nx])) > 1
                       for (vi, vj) in new):
                    continue
                inside = set(qs)
                for (vi, vj), h in new.items():
                    q, c = own[(vi, vj)][0]
                    put(vi, vj, h, inside, L.fc[q][c])
                for q in qs:
                    L.block[q] = s
                L.blocks.append((i0, j0, s))
                taken += 1
    return taken
def _build(arena, spec, layered, detail, known):
    pieces = arena["pieces"]
    idx = [k for k, p in enumerate(pieces) if is_terrain(p)]
    out = Terrain()
    if not idx:
        return None
    floor = spec.get("floor", 0)
    seed = str(spec.get("seed", arena.get("key", "terrain")))
    from . import outland
    outlined = outland.wants(spec)
    void_ok = floor is not None
    L, (warped, relaxed, broken, back, draped) = _shape(arena, spec, detail, idx, floor, seed,
                                                        outlined)
    E = Emitter(out, set(layered))
    E.rock = spec.get("rock")
    ground = arena.get("ground")
    E.floor_tex = spec.get("floor_tex") or (ground if known and ground in known else None) \
        or pieces[idx[0]]["tex"]
    used = set(p.get("tex") for p in pieces) | {E.floor_tex}
    E.slope_tex = dict((a, b) for a, b in (spec.get("slope_tex") or {}).items() if b in used)
    own = outland.KINDS[spec["backdrop"]["outline"]].get("rock") if outlined else None
    E.flank_rock = own if (own and known and own in known) else (
        E.rock if E.rock in used else None)
    coarsened = coarsen(L, pieces) if spec.get("adaptive") else 0
    if spec.get("multires") and QUAD == 200:
        spawns = [(s_["x"], s_["z"]) for s_ in arena.get("spawns") or [] if isinstance(s_, dict)]
        if spec.get("multires") == "dual":
            fmat = materials(L, E, pieces)
            L.fine_mat = [fmat(q) if L.drawn[q] else None for q in range(L.nx * L.nz)]
            L4, mats4, corners4 = _coarse(arena, spec, detail, idx, floor, seed, outlined, E)
            coarsened = dual(L, L4, mats4, corners4, pieces, spawns)
        else:
            coarsened = multires(L, pieces, spawns)
        draped = drape(L, pieces)
    held_water = hold_water(L, pieces)
    top_tris = emit_tops(L, E, pieces, spec.get("tolerance", TOLERANCE))
    passages(L, E, pieces)
    faces_before = len(out.faces)
    seam = outland.seam_heights(L) if outlined else None
    emit_walls(L, E, pieces, outside=seam)
    wall_faces = len(out.faces) - faces_before
    bd = 0
    b = spec.get("backdrop")
    ring = {}
    replaced = set()
    out.far_faces = far_ground(L, E, pieces)
    if outlined:
        rocks = {}
        for k in idx:
            p = pieces[k]
            if str(p.get("tag")).endswith(".rock"):
                rocks[p["tex"]] = rocks.get(p["tex"], 0) + 1
        b = dict(b)
        own = outland.KINDS[b["outline"]].get("rock")
        if known and own in known:
            b["rock"] = own
        elif b.get("rock") not in used:
            b["rock"] = max(sorted(rocks), key=lambda t: rocks[t]) if rocks else (
                E.rock if E.rock in used else E.floor_tex)
        if b.get("snow") not in used and not (known and b.get("snow") in known):
            b["snow"] = None
        if b.get("ground") not in used:
            b["ground"] = E.floor_tex
        replaced = outland.replaced(pieces)
        ground_collision = len(out.collision)
        top_y = max([p["y"] + p["h"] for k, p in enumerate(pieces)
                     if k not in replaced and p.get("tex") != "invisible"] or [0])
        ring = outland.build(L, E, dict(spec, backdrop=b), seed, top_y)
        bd = ring.get("horizon_triangles", 0)
        out.tone = lambda x, y, z, n, _s=seed: outland.tone(_s, x, y, z, n)
    elif isinstance(b, dict) and b.get("half"):
        ground = b.get("ground") or E.floor_tex
        rocks, snows = {}, {}
        for k in idx:
            p = pieces[k]
            if str(p.get("tag")).endswith(".rock"):
                rocks[p["tex"]] = rocks.get(p["tex"], 0) + 1
            if "snow" in p["tex"] and p["tex"] not in layered:
                snows[p["tex"]] = snows.get(p["tex"], 0) + 1
        rock = b.get("rock") if b.get("rock") in used else (
            max(sorted(rocks), key=lambda t: rocks[t]) if rocks else
            (E.rock if E.rock in used else None))
        snow = b.get("snow") if b.get("snow") in used else (
            max(sorted(snows), key=lambda t: snows[t]) if snows else None)
        bd = backdrop(E, b["half"], seed, rock or E.floor_tex, snow, floor or 0,
                      b.get("height"), ground, skirt=bool(b.get("skirt")))
    sheets = [k for k, p in enumerate(pieces) if is_sheet(p)]
    out.water_faces = waters(L, pieces, sheets)
    out.consumed = set(idx) | replaced | set(sheets)
    out.occluders = occluders(L)
    out.grid = L
    soft = sum(1 for q in range(L.nx * L.nz) if L.soft[q])
    out.stats = {"quads": L.nx * L.nz, "soft": soft, "anchored": sum(L.anchor),
                 "pinned": len(L.vpin), "put_back": back, "relaxed": relaxed,
                 "broken": broken, "eroded": L.eroded, "warped": warped,
                 "top_triangles": top_tris, "wall_faces": wall_faces,
                 "backdrop_triangles": bd, "collision_triangles": len(out.collision),
                 "draped": draped,
                 "consumed": len(idx)}
    out.stats["coarsened"] = coarsened
    out.stats["held_water"] = held_water
    out.stats["ground_collision"] = len(out.collision)
    if ring:
        out.stats["outline"] = ring
        out.stats["replaced"] = len(replaced)
        out.stats["ground_collision"] = ground_collision
    return out
