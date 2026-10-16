import math
from . import decor, flora, kit, place
CELL = 200
FAMILIES = ("explore", "hide")
NATURAL = ("grass", "snow", "sand", "dirt", "moss", "mud", "gravel", "clover", "dune")
ROADS = ("road", "street", "path", "footpath", "plaza", "bridge", "stair", "ramp", "deck", "lane",
         "crossing", "pad", "square", "paving", "quay", "dock")
POI = ("landmark", "house", "settlement", "village", "spire", "well", "fountain", "camp",
       "ruin", "prefab", "outpost", "temple", "shrine")
CLEAR_POINT = 300
CLEAR_ROAD = 100
VISTA_HALF = 350
TALL = ("bush", "boulder", "rock.small", "reeds", "fern")
FOOT_PAD = 60
BUCKET = 800
JITTER = 140
TOP_SHARE = 0.35
LAYERS = {
    "rocks": (0.15, 500, (1, 4), 260),
    "understorey": (0.30, 320, (2, 5), 300),
    "flowers": (0.35, 300, (2, 5), 240),
    "cover": (0.20, 220, (3, 7), 260),
}
ORDER = ("rocks", "understorey", "flowers", "cover")
def _salt(seed, name):
    s = 0
    for ch in "%s/%s" % (seed, name):
        s = (s * 131 + ord(ch)) & 0xFFFFFFFF
    return s
def _hash(x, z, salt):
    h = (int(x) * 73856093) ^ (int(z) * 19349663) ^ salt
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFF) / float(0xFFFFFF)
def _noise(x, z, salt, wave):
    gx, gz = x / float(wave), z / float(wave)
    i, j = int(math.floor(gx)), int(math.floor(gz))
    u, w = gx - i, gz - j
    u, w = u * u * (3 - 2 * u), w * w * (3 - 2 * w)
    a = _hash(i, j, salt)
    b = _hash(i + 1, j, salt)
    c = _hash(i + 1, j + 1, salt)
    d = _hash(i, j + 1, salt)
    return a * (1 - u) * (1 - w) + b * u * (1 - w) + c * u * w + d * (1 - u) * w
def smoothstep(a, b, v):
    t = max(0.0, min(1.0, (v - a) / float(b - a)))
    return t * t * (3 - 2 * t)
def _words(p):
    return str(p.get("tag", "") or "").replace(" ", ".").split(".")
def _natural(tex, ground=None):
    t = str(tex or "")
    return t == ground or any(w in t for w in NATURAL)
class Ground(object):
    def __init__(self, arena):
        from . import heightfield, v1
        m = v1.arenas_module()
        self.m = m
        pieces = arena.get("pieces") or []
        play = [p for p in pieces if not str(p.get("tag", "")).startswith("dress.backdrop")]
        x0, x1, z0, z1 = place.bounds(dict(arena, pieces=play))
        self.i0, self.j0 = int(math.floor(x0 / CELL)), int(math.floor(z0 / CELL))
        self.nx = int(math.ceil(x1 / CELL)) - self.i0
        self.nz = int(math.ceil(z1 / CELL)) - self.j0
        lv = m.LEVELS.get(arena.get("level")) or {}
        floor = lv.get("floor")
        self.ground_tex = arena.get("ground") if floor is not None else None
        n = self.nx * self.nz
        self.h = [None] * n
        self.tex = [None] * n
        self.over = [False] * n
        self.water = [False] * n
        self.road = [False] * n
        self.poi = [False] * n
        self.tree = [False] * n
        self.sloped = [False] * n
        self.built = [False] * n
        if floor is not None:
            for k in range(n):
                self.h[k] = float(floor)
                self.tex[k] = self.ground_tex or "level"
        terrain = []
        others = []
        for p in play:
            if p.get("tex") == "invisible":
                continue
            if heightfield.is_terrain(p):
                terrain.append(p)
            else:
                others.append(p)
        for p in terrain:
            for k, cx, cz in self._cells(p):
                try:
                    t = m.top_at(p, cx, cz) if p.get("kind") != "box" else p["y"] + p["h"]
                except Exception:
                    t = p["y"] + p["h"]
                if t is None:
                    continue
                if self.h[k] is None or t > self.h[k]:
                    self.h[k] = float(t)
                    self.tex[k] = p.get("tex")
                    self.sloped[k] = p.get("kind") != "box"
        self.top = list(self.h)
        for p in others:
            if p.get("kind") == "water":
                continue
            t = p["y"] + p["h"]
            for k, _, _ in self._cells(p):
                if self.top[k] is None or t > self.top[k]:
                    self.top[k] = float(t)
        for p in others:
            words = set(_words(p))
            is_road = bool(words & set(ROADS))
            if p.get("kind") == "water" or str(p.get("tex", "")).startswith("water") \
                    or p.get("kind") == "lava":
                for k, _, _ in self._cells(p, grow=100):
                    self.water[k] = True
                continue
            tree = flora.is_tree(p)
            poi = bool(words & set(POI))
            hero = bool(p.get("decor")) and bool((decor.BY_KEY.get(p["decor"]) or {}).get("hero"))
            grow = CLEAR_ROAD if is_road else (250 if p.get("kind") in ("stairs", "ramp")
                                              else (450 if hero else 50))
            for k, cx, cz in self._cells(p, grow=grow):
                g = self.h[k]
                top = p["y"] + p["h"]
                if g is not None and top <= g + 5 and not is_road:
                    continue
                if g is not None and p["y"] > g + 400 and not tree:
                    continue
                self.over[k] = True
                if not tree:
                    self.built[k] = True
                if is_road:
                    self.road[k] = True
                if poi:
                    self.poi[k] = True
                if tree:
                    self.tree[k] = True
        self.ramps = []
        for p in play:
            if p.get("kind") in ("stairs", "ramp"):
                try:
                    self.ramps.append(m.footprint(p)[:4])
                except Exception:
                    pass
        self.boxes = {}
        for p in play:
            if p.get("kind") == "water":
                continue
            try:
                x0, x1, z0, z1, _ = m.footprint(p)
            except Exception:
                continue
            row = (x0, x1, z0, z1, p["y"], p["y"] + p["h"],
                   heightfield.is_terrain(p) or p.get("tex") == "invisible", flora.is_tree(p))
            for bi in range(int(math.floor(x0 / BUCKET)), int(math.floor(x1 / BUCKET)) + 1):
                for bj in range(int(math.floor(z0 / BUCKET)), int(math.floor(z1 / BUCKET)) + 1):
                    self.boxes.setdefault((bi, bj), []).append(row)
        from . import movers as moversmod
        for mv in arena.get("movers") or []:
            try:
                x0, x1, y0, y1, z0, z1 = moversmod.swept_box(mv)
            except Exception:
                continue
            row = (x0 - 50, x1 + 50, z0 - 50, z1 + 50, y0 - 50, y1 + 50, False, False)
            for bi in range(int(math.floor(row[0] / BUCKET)), int(math.floor(row[1] / BUCKET)) + 1):
                for bj in range(int(math.floor(row[2] / BUCKET)),
                                int(math.floor(row[3] / BUCKET)) + 1):
                    self.boxes.setdefault((bi, bj), []).append(row)
            fake = {"kind": "box", "x": (x0 + x1) / 2.0, "z": (z0 + z1) / 2.0, "y": y0,
                    "w": x1 - x0, "d": z1 - z0, "h": y1 - y0, "yaw": 0}
            for k, _, _ in self._cells(fake, grow=100):
                self.over[k] = self.built[k] = True
        self.points = []
        for key in ("spawns", "objects", "stars", "markers"):
            for o in arena.get(key) or []:
                if isinstance(o, dict) and "x" in o and "z" in o:
                    self.points.append((o["x"], o["z"]))
        surv = arena.get("survey") or {}
        for v in surv.values():
            for s in (v if isinstance(v, list) else [v]):
                if isinstance(s, dict) and "x" in s and "z" in s:
                    self.points.append((s["x"], s["z"]))
        w = arena.get("world")
        if isinstance(w, dict) and "x" in w:
            self.points.append((w["x"], w["z"]))
        self.d_water = self._distance(self.water)
        self.d_road = self._distance(self.road)
        self.d_poi = self._distance([a or b for a, b in zip(self.poi, self.road)])
        self.d_tree = self._distance(self.tree)
    def clear_box(self, x0, x1, z0, z1, y0, y1, pad=0, trees_ok=False):
        seen = set()
        for bi in range(int(math.floor((x0 - pad) / BUCKET)), int(math.floor((x1 + pad) / BUCKET)) + 1):
            for bj in range(int(math.floor((z0 - pad) / BUCKET)),
                            int(math.floor((z1 + pad) / BUCKET)) + 1):
                for row in self.boxes.get((bi, bj), ()):
                    if id(row) in seen:
                        continue
                    seen.add(id(row))
                    a0, a1, b0, b1, c0, c1, terr, tree = row
                    if tree and trees_ok:
                        continue
                    g = 0 if terr else pad
                    if a0 >= x1 + g or a1 <= x0 - g or b0 >= z1 + g or b1 <= z0 - g:
                        continue
                    if terr and c1 <= y0 + 5:
                        continue
                    if c0 >= y1 + (0 if terr else 400) or c1 <= y0 - 60:
                        continue
                    return False
        return True
    def k(self, i, j):
        if 0 <= i < self.nx and 0 <= j < self.nz:
            return i + j * self.nx
        return None
    def at(self, x, z):
        return self.k(int(math.floor(x / CELL)) - self.i0, int(math.floor(z / CELL)) - self.j0)
    def centre(self, k):
        i, j = k % self.nx, k // self.nx
        return (self.i0 + i + 0.5) * CELL, (self.j0 + j + 0.5) * CELL
    def _cells(self, p, grow=0):
        try:
            x0, x1, z0, z1, _ = self.m.footprint(p)
        except Exception:
            return
        x0, x1, z0, z1 = x0 - grow, x1 + grow, z0 - grow, z1 + grow
        i0 = max(0, int(math.floor(x0 / CELL)) - self.i0)
        i1 = min(self.nx, int(math.ceil(x1 / CELL)) - self.i0)
        j0 = max(0, int(math.floor(z0 / CELL)) - self.j0)
        j1 = min(self.nz, int(math.ceil(z1 / CELL)) - self.j0)
        for j in range(j0, j1):
            for i in range(i0, i1):
                cx, cz = (self.i0 + i + 0.5) * CELL, (self.j0 + j + 0.5) * CELL
                if x0 <= cx <= x1 and z0 <= cz <= z1:
                    yield i + j * self.nx, cx, cz
    def _distance(self, src):
        big = 1e9
        d = [0.0 if s else big for s in src]
        nx, nz = self.nx, self.nz
        a, b = float(CELL), CELL * 1.4142
        for j in range(nz):
            for i in range(nx):
                k = i + j * nx
                v = d[k]
                if i:
                    v = min(v, d[k - 1] + a)
                if j:
                    v = min(v, d[k - nx] + a)
                    if i:
                        v = min(v, d[k - nx - 1] + b)
                    if i < nx - 1:
                        v = min(v, d[k - nx + 1] + b)
                d[k] = v
        for j in range(nz - 1, -1, -1):
            for i in range(nx - 1, -1, -1):
                k = i + j * nx
                v = d[k]
                if i < nx - 1:
                    v = min(v, d[k + 1] + a)
                if j < nz - 1:
                    v = min(v, d[k + nx] + a)
                    if i < nx - 1:
                        v = min(v, d[k + nx + 1] + b)
                    if i:
                        v = min(v, d[k + nx - 1] + b)
                d[k] = v
        return d
    def slope(self, k):
        i, j = k % self.nx, k // self.nx
        h = self.h[k]
        rise, step = 0.0, 0.0
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            kk = self.k(i + di, j + dj)
            if kk is None or self.h[kk] is None:
                continue
            dh = self.h[kk] - h
            step = max(step, abs(dh))
            rise = max(rise, abs(dh) / (2.0 * CELL))
        return rise, step
    def free(self, k):
        return (k is not None and self.h[k] is not None and not self.over[k]
                and not self.water[k] and _natural(self.tex[k], self.ground_tex))
def vista_lines(arena):
    from . import critic
    starts = []
    w = arena.get("world")
    if isinstance(w, dict) and "x" in w:
        starts.append((w["x"], w["z"]))
    sp = [s for s in arena.get("spawns") or [] if isinstance(s, dict)]
    starts += [(s["x"], s["z"]) for s in sp[:1]]
    targets = {}
    for p in arena.get("pieces") or []:
        root = critic.landmark_root(p)
        if root is None or str(p.get("tag", "")).startswith("dress.backdrop"):
            continue
        t = targets.setdefault(root, [0.0, 0.0, 0])
        t[0] += p["x"]
        t[1] += p["z"]
        t[2] += 1
    ends = [(a / n, b / n) for a, b, n in targets.values() if n]
    return [(s, e) for s in starts for e in ends]
def _seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))
TEX_LINE = 62
def texture_keys(pieces):
    import os
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake
    out = set()
    for p in decor.drawn(pieces):
        t = p.get("tex")
        if not t or t == "invisible":
            continue
        for layer in ((0, 1) if kit.layered(t) else (0,)):
            out.add((t, layer))
            if venuebake.coarse(t, layer):
                out.add((t, layer, "hi"))
    return out
def materials(arena, theme):
    have = kit.textures()
    worn = {}
    for p in arena.get("pieces") or []:
        t = p.get("tex")
        if t:
            worn[t] = worn.get(t, 0) + 1
        for v in (p.get("mats") or {}).values():
            if v:
                worn[v] = worn.get(v, 0) + 1
    count = [len(texture_keys(arena.get("pieces") or []))]
    def pick(choices, allow_new=True):
        for c in choices:
            if c in worn and c in have:
                return c
        if allow_new:
            for c in choices:
                if c in have:
                    cost = len(texture_keys([{"kind": "box", "tex": c, "x": 0, "y": 0, "z": 0,
                                              "w": 200, "h": 200, "d": 200, "yaw": 0}]))
                    if count[0] + cost > TEX_LINE:
                        continue
                    count[0] += cost
                    worn[c] = 1
                    return c
        return None
    cold = theme == "ice"
    dry = theme in ("desert", "lava")
    out = {}
    out["leaves"] = pick(("leaves", "leavesdark", "hedge", "fern") if not dry else
                         ("leaves", "hedge"), allow_new=not dry)
    out["fern"] = pick(("fern", "ferndark", "leavesdark", out["leaves"] or "leaves"),
                       allow_new=not (cold or dry))
    ground = arena.get("ground")
    ground = {"grass": "grass", "snow": "snowblock", "sand": "sand"}.get(ground, ground)
    meadow = max((t for t in worn if "grass" in t and not kit.layered(t)),
                 key=lambda t: (worn[t], t), default="grass")
    out["grass"] = pick(("grasslush", "grassclover", ground or "grass", meadow, "grass",
                         "grassflowers")
                        if not dry else ("grassdry", "grassteal"), allow_new=not cold)
    out["rock"] = pick(("rockboulder", "rockgrey", "rockbrown", "mossyrock", "rockdark",
                        "frostedrock", "sandstone", "basaltrough", "stone2"))
    flowers = [t for t in ("flowersyellow", "flowersred", "flowerswhite", "flowerspink",
                           "flowersblue", "flowerspurple", "flowersorange") if t in worn]
    if not flowers and not (cold or dry):
        f = pick(("flowersyellow", "flowerswhite", "flowersred"))
        flowers = [f] if f else []
    if cold or dry:
        flowers = []
    out["flowers"] = flowers
    out["reeds"] = pick(("grassdry", "grassteal", "bamboolog", out["grass"] or "grass"),
                        allow_new=False)
    out["mushroom"] = pick(("mushroomsred", "mushroomsbrown"), allow_new=not (cold or dry))
    out["stalk"] = pick(("cutlight", "whitemarble", "plastercream"), allow_new=False)
    return out
def _layer_density(G, k, layer, salt, theme):
    if not G.free(k):
        return 0.0
    tex = str(G.tex[k] or "")
    rise, step = G.slope(k)
    flat = 1.0 - smoothstep(0.25, 0.55, rise)
    if step > 150:
        flat = 0.0 if layer != "rocks" else flat
    moist = math.exp(-G.d_water[k] / 2400.0)
    near_tree = math.exp(-max(0.0, G.d_tree[k] - 250) / 700.0)
    imp = max(math.exp(-G.d_road[k] / 1500.0), math.exp(-G.d_poi[k] / 2000.0))
    x, z = G.centre(k)
    patch = _noise(x, z, salt + 11, 2200)
    snow, sand = "snow" in tex, ("sand" in tex or "dune" in tex)
    if layer == "rocks":
        foot = 1.0 if 200 < step < 1200 else 0.0
        up = smoothstep(0.15, 0.6, rise)
        return max(foot * 0.8, up * 0.6, 0.12 * patch) * (1.0 if not sand else 0.7)
    if layer == "understorey":
        if snow or sand:
            return 0.0
        return flat * (0.15 + 0.85 * near_tree) * (0.5 + 0.5 * moist) * (0.4 + 0.6 * patch)
    if layer == "flowers":
        if snow or sand or "grass" not in tex and "clover" not in tex and tex != G.ground_tex:
            return 0.0
        meadow = 1.0 - 0.7 * near_tree
        return flat * meadow * (0.25 + 0.75 * imp) * smoothstep(0.45, 0.75, patch)
    if layer == "cover":
        if snow:
            return 0.0
        return flat * imp * (0.6 + 0.4 * moist) * (0.5 + 0.5 * patch)
    return 0.0
def _kind_for(G, k, layer, salt, mats):
    x, z = G.centre(k)
    tex = str(G.tex[k] or "")
    r = _hash(x, z, salt + 7)
    if layer == "rocks":
        rise, step = G.slope(k)
        return ("boulder" if (step > 300 or r < 0.35) else "rock.small"), mats["rock"]
    if layer == "understorey":
        if G.d_tree[k] < 900 and mats.get("fern") and r < 0.45:
            return "fern", mats["fern"]
        return "bush", mats["leaves"]
    if layer == "flowers":
        fl = mats["flowers"]
        if not fl:
            return None, None
        c = int(_noise(x, z, salt + 23, 3000) * len(fl) * 0.999)
        return "flowers.patch", fl[c]
    if layer == "cover":
        if G.d_water[k] < 500 and mats.get("reeds"):
            return "reeds", mats["reeds"]
        if G.d_tree[k] < 500 and mats.get("mushroom") and r < 0.18:
            return "mushrooms", mats["mushroom"]
        if "sand" in tex and not mats.get("grass"):
            return None, None
        return "tuft", mats["grass"]
    return None, None
def run(arena, brief, room, seed=None):
    f = brief.get("features") or {}
    avoid = set(f.get("avoid") or ())
    if brief.get("family") not in FAMILIES or avoid & {"decor", "scatter", "vegetation"} \
            or room < 12:
        return [], {"placed": 0, "why": "not asked or no room"}
    theme = brief.get("theme") if brief.get("theme") not in (None, "auto") else "garden"
    seed = brief.get("seed") if seed is None else seed
    G = Ground(arena)
    mats = materials(arena, theme)
    lines = vista_lines(arena)
    taken = {}
    mine = []
    out = []
    counts = {}
    amount = (brief.get("amounts") or {}).get("decor") or (brief.get("amounts") or {}).get(
        "trees")
    scale = {"trace": 0.3, "few": 0.5, "less": 0.7, "more": 1.3, "lots": 1.6}.get(amount, 1.0)
    room = int(room * min(1.0, scale))
    for layer in ORDER:
        share, spacing, (clo, chi), sigma = LAYERS[layer]
        cap = int(room * share)
        salt = _salt(seed, layer)
        if cap <= 0:
            continue
        dens = {}
        cand = []
        for k in range(G.nx * G.nz):
            d = _layer_density(G, k, layer, salt, theme)
            if d <= 0.05:
                continue
            dens[k] = d
            x, z = G.centre(k)
            cand.append((_hash(x, z, salt) / d, k))
        cand.sort()
        placed = 0
        rad_cells = max(1, int(round(spacing / float(CELL))))
        def fits(k):
            i, j = k % G.nx, k // G.nx
            for dj in range(-rad_cells, rad_cells + 1):
                for di in range(-rad_cells, rad_cells + 1):
                    kk = G.k(i + di, j + dj)
                    if kk is not None and kk in taken:
                        if di * di + dj * dj <= rad_cells * rad_cells:
                            return False
            return True
        def clear(x, z, tall):
            if any(math.hypot(x - px, z - pz) < CLEAR_POINT * (2 if tall else 1)
                   for px, pz in G.points):
                return False
            if tall and any(_seg_dist(x, z, a, b) < VISTA_HALF for a, b in lines):
                return False
            return True
        def lay(k, x, z):
            nonlocal placed
            kind, tex = _kind_for(G, k, layer, salt, mats)
            if not kind or not tex:
                return False
            tall = kind in TALL
            rise, step = G.slope(k)
            if step > 150 and layer != "rocks":
                return False
            x += (_hash(x, z, salt + 29) - 0.5) * JITTER
            z += (_hash(z, x, salt + 31) - 0.5) * JITTER
            x, z = int(round(x / 10.0)) * 10, int(round(z / 10.0)) * 10
            if not clear(x, z, tall):
                return False
            yaw = 90 * (int(_hash(x, z, salt + 3) * 4) % 4)
            p = decor.piece(kind, x, int(round(G.h[k])), z, yaw, mats={"a": tex},
                            tag="scatter.%s.%s" % (layer, kind))
            if kind == "mushrooms" and mats.get("stalk"):
                p["mats"]["b"] = mats["stalk"]
            if max(p["w"], p["d"]) > 260:
                return False
            ow, od = (p["d"], p["w"]) if int(p.get("yaw", 0)) % 180 == 90 else (p["w"], p["d"])
            for pad in (0, FOOT_PAD):
                hw, hd = ow / 2.0 + pad, od / 2.0 + pad
                for dx in (-hw, 0, hw):
                    for dz in (-hd, 0, hd):
                        kk = G.at(p["x"] + dx, p["z"] + dz)
                        if kk is None or G.over[kk] or G.water[kk]:
                            return False
                        if not pad and (not G.free(kk) or abs(G.h[kk] - G.h[k]) > 5
                                        or G.sloped[kk]):
                            return False
            m_ = G.m
            fx0, fx1, fz0, fz1, _ = m_.footprint(p)
            if not G.clear_box(fx0, fx1, fz0, fz1, p["y"], p["y"] + p["h"], FOOT_PAD):
                return False
            if any(not (fx1 <= q0 or fx0 >= q1 or fz1 <= r0 or fz0 >= r1)
                   for q0, q1, r0, r1 in mine):
                return False
            if not p.get("pass") and any(
                    fx0 < b + 200 and fx1 > a - 200 and fz0 < d + 200 and fz1 > c - 200
                    for a, b, c, d in G.ramps):
                return False
            mine.append((fx0, fx1, fz0, fz1))
            p["drape"] = True
            p["scatter"] = True
            p["context"] = layer
            out.append(p)
            taken[k] = layer
            placed += 1
            counts[kind] = counts.get(kind, 0) + 1
            return True
        for _, k in cand:
            if placed >= cap:
                break
            if k in taken or not fits(k):
                continue
            px, pz = G.centre(k)
            if dens[k] < 0.3 or _hash(px, pz, salt + 1) > dens[k]:
                continue
            if not lay(k, px, pz):
                continue
            n = clo + int(_hash(px, pz, salt + 5) * (chi - clo + 1))
            for c in range(n * 3):
                if placed >= cap or n <= 0:
                    break
                a = _hash(px + c, pz, salt + 13) * 2 * math.pi
                rr = sigma * math.sqrt(-2.0 * math.log(max(1e-6, _hash(px, pz + c, salt + 17))))
                x, z = px + math.sin(a) * rr, pz + math.cos(a) * rr
                kk = G.at(x, z)
                if kk is None or kk in taken or kk not in dens:
                    continue
                if _hash(x, z, salt + 19) > dens[kk] * 1.6 or not fits(kk):
                    continue
                if lay(kk, *G.centre(kk)):
                    n -= 1
    capped = None
    if out:
        top = max(sorted(counts), key=lambda k_: counts[k_])
        rest = len(out) - counts[top]
        keep = int(TOP_SHARE * rest / (1.0 - TOP_SHARE)) if rest else counts[top]
        if counts[top] > keep and rest:
            mine_ = sorted((p for p in out if p.get("tag") == "scatter." + top or
                            p.get("decor") == top or p.get("kind_") == top),
                           key=lambda p: _hash(p["x"], p["z"], salt + 29))
            gone = set(id(p) for p in mine_[keep:])
            if gone:
                out = [p for p in out if id(p) not in gone]
                capped = (top, counts[top], counts[top] - len(gone))
                counts[top] -= len(gone)
    rep = {"placed": len(out), "kinds": counts, "room": room,
           "vistas": len(lines)}
    if capped:
        rep["capped"] = capped
    return out, rep
ROOM_SHARE = 0.3
ROOM_MAX = 480
ROOM_KEEP = 0.04
PROP_TRIS = 22
SCATTER_TRIS = {"tiny": 1500, "small": 2500, "medium": 3500, "large": 5000, "huge": 6000,
                "gigantic": 6000}
def line_of(arena, brief):
    budget = int(arena.get("budget") or brief.get("budget") or 0)
    if "budget" in (getattr(brief, "defaulted", None) or ()):
        from . import budget as budgetmod
        modes = brief.get("modes") or arena.get("onlyFor") or ()
        budget = max(budget, budgetmod.ceiling(brief.get("family"), modes))
    return budget
def room_of(arena, brief):
    budget = line_of(arena, brief)
    used = (len(arena.get("pieces") or []) + len(arena.get("markers") or [])
            + len(arena.get("objects") or []) + len(arena.get("movers") or []))
    left = budget - used - int(ROOM_KEEP * budget)
    from . import budget as budgetmod
    tier = budgetmod.tier_of(brief.get("size") or "medium")
    tris = SCATTER_TRIS.get(tier, SCATTER_TRIS["medium"]) // PROP_TRIS
    return max(0, min(left, int(ROOM_SHARE * budget), ROOM_MAX, tris))
def say(rep):
    kinds = rep.get("kinds") or {}
    words = ", ".join("%d %s" % (n, k) for k, n in sorted(kinds.items(), key=lambda kv: -kv[1]))
    return "scatter: %d props on the ground (%s), %d vista lines kept clear" % (
        rep.get("placed", 0), words or "-", rep.get("vistas", 0))
