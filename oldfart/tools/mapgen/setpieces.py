import math
from . import kit, scatter, surround, v1
KINDS = ("lookout", "spiral_path", "slide", "floating_islands", "secret_alcove",
         "giant_mushrooms")
DEFAULT_COUNT = {"tiny": 0, "small": 0, "medium": 0, "large": 1, "huge": 2, "gigantic": 2}
THEME_PICKS = {
    "garden": ("lookout", "floating_islands", "secret_alcove"),
    "wood": ("lookout", "secret_alcove", "slide"),
    "castle": ("lookout", "spiral_path", "secret_alcove"),
    "ice": ("slide", "lookout", "spiral_path"),
    "desert": ("spiral_path", "secret_alcove", "lookout"),
    "lava": ("spiral_path", "secret_alcove"),
    "sky": ("floating_islands", "lookout", "spiral_path"),
}
COST = {"lookout": 24, "spiral_path": 46, "slide": 40, "floating_islands": 40,
        "secret_alcove": 10, "waterfall": 8, "giant_mushrooms": 100}
WATER_ROWS = 19
RISE = 250
STRIP = 300
CLEAR = 300
SPAWN_CLEAR = 1500
SAMPLES = 40
REGION_GAP = 4000
HEADROOM = 900
NEAR = 3000
NEAR_SPOTS = 4
LOOSE = ("coin", "coins", "1up")
LOOSE_STEP = 600
def _ground(arena):
    G = scatter.Ground(arena)
    loose = set((o["x"], o["z"]) for o in arena.get("objects") or []
                if isinstance(o, dict) and o.get("key") in LOOSE and "x" in o)
    if loose:
        G.points = [pt for pt in G.points if pt not in loose]
    return G
def _q(v, step=100):
    return int(round(v / float(step))) * step
def wanted(brief):
    f = brief.get("features") or {}
    return [k for k in KINDS if k in (f.get("want") or ())], set(f.get("avoid") or ())
class Site(object):
    def __init__(self, arena, brief):
        self.arena = arena
        self.brief = brief
        self.G = _ground(arena)
        self.m = v1.arenas_module()
        self.taken = []
        self.placed = []
        self.laid = []
        self.cannons = []
        self.pad_gone, self.pad_new = [], []
        G = self.G
        roads = [k for k in range(G.nx * G.nz) if G.road[k]]
        step = max(1, len(roads) // SAMPLES)
        self.eyes = []
        for k in roads[::step][:SAMPLES]:
            x, z = G.centre(k)
            self.eyes.append((x, (G.top[k] or 0) + 160, z))
        for s in (arena.get("spawns") or [])[:4]:
            if isinstance(s, dict):
                self.eyes.append((s["x"], s.get("y", 0) + 160, s["z"]))
        self.spawns = [(s["x"], s["z"]) for s in arena.get("spawns") or [] if isinstance(s, dict)]
    def sees(self, eye, x, y, z):
        G = self.G
        dx, dy, dz = x - eye[0], y - eye[1], z - eye[2]
        n = max(1, int(math.hypot(dx, dz) / 200.0))
        for i in range(1, n):
            t = i / float(n)
            k = G.at(eye[0] + dx * t, eye[2] + dz * t)
            if k is None:
                continue
            top = G.top[k]
            if top is not None and top > eye[1] + dy * t:
                return False
        return True
    def seen_by(self, x, y, z):
        return sum(1 for e in self.eyes if self.sees(e, x, y, z))
    def open(self, k):
        G = self.G
        return (G.h[k] is not None and not G.built[k] and not G.water[k]
                and (scatter._natural(G.tex[k], G.ground_tex)
                     or (getattr(self, "near", None) is not None and G.tex[k] == "level")))
    def level(self, rect, g, pad=100):
        G = self.G
        x0, x1, z0, z1 = rect
        x = x0 + 50
        while x < x1:
            z = z0 + 50
            while z < z1:
                k = G.at(x, z)
                if k is None or not self.open(k) or G.sloped[k] or abs(G.h[k] - g) > 5:
                    return False
                z += 150
            x += 150
        if not G.clear_box(x0, x1, z0, z1, g, g + 1200, pad, trees_ok=True):
            return False
        if any(not (x1 + pad <= a or x0 - pad >= b or z1 + pad <= c or z0 - pad >= d)
               for a, b, c, d in self.taken):
            return False
        return not any(x0 - 400 <= px <= x1 + 400 and z0 - 400 <= pz <= z1 + 400
                       for px, pz in G.points)
    def flat(self, cx, cz, half, pad=CLEAR):
        G = self.G
        k0 = G.at(cx, cz)
        if k0 is None or not self.open(k0):
            return None
        g = G.h[k0]
        x = cx - half
        while x <= cx + half:
            z = cz - half
            while z <= cz + half:
                k = G.at(x, z)
                if k is None or not self.open(k) or G.sloped[k] or abs(G.h[k] - g) > 5:
                    return None
                z += 200
            x += 200
        if not G.clear_box(cx - half, cx + half, cz - half, cz + half, g, g + 3000, pad,
                           trees_ok=True):
            return None
        for u in range(-half - pad // 2, half + pad // 2 + 1, 200):
            for x, z in ((cx + u, cz - half - pad // 2), (cx + u, cz + half + pad // 2),
                         (cx - half - pad // 2, cz + u), (cx + half + pad // 2, cz + u)):
                k = G.at(x, z)
                if k is None or G.h[k] is None or G.water[k] or abs(G.h[k] - g) > 5:
                    return None
        if any(not (cx + half + pad <= a or cx - half - pad >= b or cz + half + pad <= c
                    or cz - half - pad >= d) for a, b, c, d in self.taken):
            return None
        if any(math.hypot(cx - sx, cz - sz) < SPAWN_CLEAR for sx, sz in self.spawns):
            return None
        if any(math.hypot(cx - px, cz - pz) < half + 400 for px, pz in G.points):
            return None
        return g
    def pad(self, half, spawn_clear=None):
        from . import heightfield
        G = self.G
        half = int(math.ceil(half / 200.0)) * 200
        x0 = (G.i0 + 0.5) * scatter.CELL
        z0 = (G.j0 + 0.5) * scatter.CELL
        pieces = self.arena.get("pieces") or []
        reach = SPAWN_CLEAR + half if spawn_clear is None else max(spawn_clear, half + CLEAR)
        best = None
        for j in range(0, G.nz * scatter.CELL, 400):
            for i in range(0, G.nx * scatter.CELL, 400):
                cx = int(round((x0 + i) / 200.0)) * 200
                cz = int(round((z0 + j) / 200.0)) * 200
                if not self.within(cx, cz):
                    continue
                if any(math.hypot(cx - sx, cz - sz) < reach for sx, sz in self.spawns):
                    continue
                if any(math.hypot(cx - px, cz - pz) < half + 400 for px, pz in G.points):
                    continue
                if any(not (cx + half + CLEAR <= a or cx - half - CLEAR >= b or
                            cz + half + CLEAR <= c or cz - half - CLEAR >= d)
                       for a, b, c, d in self.taken):
                    continue
                hs, ok = [], True
                x = cx - half + 100
                while ok and x < cx + half:
                    z = cz - half + 100
                    while z < cz + half:
                        k = G.at(x, z)
                        if k is None or G.h[k] is None or G.built[k] or G.water[k] or \
                                G.road[k] or not scatter._natural(G.tex[k], G.ground_tex):
                            ok = False
                            break
                        hs.append(G.h[k])
                        z += 200
                    x += 200
                if not ok or not hs or max(hs) - min(hs) > PAD_RANGE:
                    continue
                rect = (cx - half, cx + half, cz - half, cz + half)
                under = [q for q in pieces if _meets(q, rect)]
                if any(heightfield.is_terrain(q) and (q.get("kind") != "box" or
                                                      float(q.get("yaw", 0) or 0) % 90)
                       and not _within(q, rect) for q in under):
                    continue
                if any(not heightfield.is_terrain(q) and not _flora(q) for q in under):
                    continue
                score = (max(hs) - min(hs), -self.seen_by(cx, max(hs) + 600, cz))
                if best is None or score < best[0]:
                    best = (score, cx, cz, sorted(hs)[len(hs) // 2])
        if best is None:
            return None
        _, cx, cz, mid = best
        g = int(round(mid / 100.0)) * 100
        rect = (cx - half, cx + half, cz - half, cz + half)
        gone, new = [], []
        tops = {}
        foot = None
        rock = None
        for q in pieces:
            if not (heightfield.is_terrain(q) and _meets(q, rect)):
                continue
            gone.append(q)
            if q.get("kind") == "box":
                new += _cut_round(q, rect)
            foot = q["y"] if foot is None else min(foot, q["y"])
            if str(q.get("tag", "")).endswith(".rock"):
                rock = rock or q["tex"]
            tops[q["tex"]] = tops.get(q["tex"], 0) + (q["y"] + q["h"] >= g - 200)
        ground = max(sorted(tops), key=lambda t: tops[t]) if tops else None
        if ground is None:
            return None
        rock = rock or ground
        foot = min(foot if foot is not None else 0, g - 200)
        if g - 200 > foot:
            new.append(_box(rock, rect[0], rect[1], foot, g - 200, rect[2], rect[3], "terrace.rock"))
        new.append(_box(ground, rect[0], rect[1], g - 200, g, rect[2], rect[3], "terrace"))
        m = v1.arenas_module()
        for q in new:
            q["model"] = m.model_name(q)
        self.pad_gone += gone
        self.pad_new += new
        ids = set(id(q) for q in gone)
        self.arena = dict(self.arena, pieces=[q for q in pieces if id(q) not in ids] + new)
        self.G = _ground(self.arena)
        return cx, cz, g
    def apart(self, x, z):
        return all(math.hypot(x - (a + b) / 2.0, z - (e + f) / 2.0) >= REGION_GAP
                   for a, b, e, f in self.placed)
    def candidates(self, half, step=400):
        G = self.G
        x0 = (G.i0 + 0.5) * scatter.CELL
        z0 = (G.j0 + 0.5) * scatter.CELL
        out = []
        near = getattr(self, "near", None)
        for j in range(0, G.nz * scatter.CELL, step):
            for i in range(0, G.nx * scatter.CELL, step):
                cx, cz = _q(x0 + i), _q(z0 + j)
                if near and not self.within(cx, cz):
                    continue
                g = self.flat(cx, cz, half)
                if g is not None:
                    out.append((cx, cz, g))
        if near:
            out.sort(key=lambda c: math.hypot(c[0] - near[0], c[1] - near[1]))
            return out[:NEAR_SPOTS]
        apart = [c for c in out if self.apart(c[0], c[1])]
        return apart or out
    def within(self, x, z):
        near = getattr(self, "near", None)
        return near is None or math.hypot(x - near[0], z - near[1]) <= NEAR
PAD_RANGE = 800
def _rect_of(q):
    hw, hd = q["w"] / 2.0, q["d"] / 2.0
    if int(round(float(q.get("yaw", 0) or 0))) % 180 == 90:
        hw, hd = hd, hw
    return q["x"] - hw, q["x"] + hw, q["z"] - hd, q["z"] + hd
def _meets(q, rect):
    a, b, c, d = _rect_of(q)
    return a < rect[1] and b > rect[0] and c < rect[3] and d > rect[2]
def _within(q, rect):
    a, b, c, d = _rect_of(q)
    return a >= rect[0] and b <= rect[1] and c >= rect[2] and d <= rect[3]
def _flora(q):
    from . import flora
    tag = str(q.get("tag", ""))
    return flora.is_tree(q) or tag.startswith(("scatter.", "detail.", "tree"))
def _cut_round(q, rect):
    a, b, c, d = _rect_of(q)
    x0, x1, z0, z1 = rect
    out = []
    y0, y1 = q["y"], q["y"] + q["h"]
    parts = [(a, min(b, x0), c, d), (max(a, x1), b, c, d),
             (max(a, x0), min(b, x1), c, min(d, z0)), (max(a, x0), min(b, x1), max(c, z1), d)]
    for pa, pb, pc, pd in parts:
        if pb - pa >= 1 and pd - pc >= 1:
            out.append(_box(q["tex"], pa, pb, y0, y1, pc, pd, q.get("tag")))
    return out
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(tex, int(x0), int(x1), int(y0), int(y1), int(z0), int(z1),
                                None, tag)
def _pal(arena, brief):
    from .families.objective import palette
    theme = brief.get("theme") if brief.get("theme") not in (None, "auto") else "garden"
    pal, _ = palette(theme, None)
    have = kit.textures()
    worn = set(p.get("tex") for p in arena.get("pieces") or [])
    def first(*names):
        for n in names:
            if n and n in worn and n in have:
                return n
        for n in names:
            if n and n in have:
                return n
        return "greystone"
    return {
        "wall": first(pal.get("wall"), "greystone"),
        "trim": first(pal.get("trim"), pal.get("wall")),
        "roof": first(pal.get("roof"), "rfslate"),
        "path": first(pal.get("path"), "pathgravel", "cobble"),
        "rock": first("mossyrock", "rockgrey", "rockbrown", pal.get("keel")),
        "deck": first(pal.get("deck"), "woodenplank1"),
        "accent": first((pal.get("accents_built") or [None])[0], "bannerred"),
        "ice": first("ice", "icepacked"),
        "wood": first("woodenplank1", "darkplanks", "wdoak", "hatchedwood", pal.get("bridge")),
        "cap": first(surround.THEMES.get(theme, surround.THEMES["garden"])["top"], "grass"),
        "theme": theme,
    }
def winding(cx, cz, g, core, tiers, flights_tex, core_tex, tag, ramps=False):
    out = []
    a = core
    y = g
    stair = "ramp" if ramps else "stairs"
    make = kit.kind(stair).make
    for t in range(tiers):
        A = a + STRIP
        R = RISE
        legs = [((-a, a, -A, -a), "+x"), ((a, A, -a, a), "+z"), ((-a, a, a, A), "-x"),
                ((-A, -a, -a, a), "-z")]
        corners = [(a, A, -A, -a), (a, A, a, A), (-A, -a, a, A)]
        for i, ((x0, x1, z0, z1), rises) in enumerate(legs):
            lo = y + i * R
            if lo > y:
                out.append(_box(core_tex, cx + x0, cx + x1, y, lo, cz + z0, cz + z1,
                                tag + " plinth"))
            out.append(make(flights_tex, cx + x0, cx + x1, lo, lo + R, cz + z0, cz + z1,
                            rises, tag + " path"))
            if i < 3:
                c0, c1, d0, d1 = corners[i]
                out.append(_box(core_tex, cx + c0, cx + c1, y, lo + R, cz + d0, cz + d1,
                                tag + " landing"))
        top = y + 4 * R
        out.append(_box(core_tex, cx - a, cx + a, y, top, cz - a, cz + a, tag + " core"))
        y = top
        a -= STRIP
        if a < 300:
            break
    return out, y, a + STRIP
def lookout(S, pal, r):
    def site(half):
        best = None
        for cx, cz, g in S.candidates(half, step=200):
            seen = S.seen_by(cx, g + 1500, cz)
            score = seen + 0.002 * g
            if best is None or score > best[0]:
                best = (score, cx, cz, g, seen)
        return best
    core, tiers = 700, 2
    best = site(core + STRIP)
    if best is None:
        core, tiers = 400, 1
        best = site(core + STRIP)
    for c, t in ((700, 2), (400, 1)):
        if best is not None:
            break
        got = S.pad(c + STRIP, spawn_clear=SPAWN_CLEAR)
        if got is not None:
            core, tiers = c, t
            best = (0, got[0], got[1], got[2], S.seen_by(got[0], got[2] + 1500, got[1]))
    if best is None:
        return None, "no level ground for a lookout tower"
    half = core + STRIP
    _, cx, cz, g, seen = best
    tag = "setpiece.lookout"
    out, top, a = winding(cx, cz, g, core, tiers, pal["path"], pal["wall"], tag)
    T = 60
    for x0, x1, z0, z1 in ((-a, a, a - T, a), (a - T, a, -a, a - T), (-a + 300, a - T, -a, -a + T),
                           (-a, -a + T, -a + 300, a - T)):
        out.append(kit.kind("rail").make(pal["trim"], cx + x0, cx + x1, top, top + 160, cz + z0,
                                         cz + z1, None, tag + " rail"))
    post = 120
    for sx in (-1, 1):
        for sz in (-1, 1):
            px, pz = cx + sx * (a - 150), cz + sz * (a - 150)
            out.append(kit.kind("pillar").make(pal["trim"], px - post // 2, px + post // 2, top,
                                               top + 800, pz - post // 2, pz + post // 2, None,
                                               tag + " post"))
    out.append(kit.kind("pyramid").make(pal["roof"], cx - a - 100, cx + a + 100, top + 800,
                                        top + 1200, cz - a - 100, cz + a + 100, "x",
                                        tag + " roof"))
    out.append(kit.kind("pillar").make(pal["accent"], cx - 50, cx + 50, top + 1200, top + 1400,
                                       cz - 50, cz + 50, None, tag + " accent"))
    S.taken.append((cx - half, cx + half, cz - half, cz + half))
    return out, "a lookout tower %d high at (%d, %d), stairs round it; seen from %d of %d paths" % (
        top - g, cx, cz, seen, len(S.eyes))
def spiral_path(S, pal, r):
    core, tiers = 600, 2
    half = core + STRIP
    best = None
    for cx, cz, g in S.candidates(half, step=200):
        seen = S.seen_by(cx, g + 3000, cz)
        if best is None or seen > best[0]:
            best = (seen, cx, cz, g)
    if best is None:
        return None, "no level ground 1800 across for a spiral summit"
    seen, cx, cz, g = best
    tag = "setpiece.spiral"
    rock = _natural_rock(S, pal)
    out, top, a = winding(cx, cz, g, core, tiers, pal["path"], rock, tag, ramps=True)
    for k, p in enumerate(out):
        if p.get("kind") == "box" and p.get("tex") == rock:
            p["sculpt"] = {"shape": "rock", "seed": (cx * 7 + cz * 3 + k * 101) & 0x7fff,
                           "round": 5.0 if " core" in p["tag"] else 3.6, "flat": False,
                           "table": True}
            p["sculpt"].update(rock_detail(p))
    out.append(kit.kind("pillar").make(pal["trim"], cx - 40, cx + 40, top, top + 1000, cz - 40,
                                       cz + 40, None, tag + " pole"))
    out.append(_box(pal["accent"], cx + 40, cx + 400, top + 700, top + 950, cz - 10, cz + 10,
                    tag + " flag"))
    S.taken.append((cx - half, cx + half, cz - half, cz + half))
    return out, "a spiral path round a rock summit %d high at (%d, %d); seen from %d of %d paths" % (
        top - g, cx, cz, seen, len(S.eyes))
def slide(S, pal, r):
    G = S.G
    seg, drop, width = 800, 400, 400
    dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    best = None
    tops = sorted(((G.h[k], k) for k in range(G.nx * G.nz)
                   if S.open(k) and not G.sloped[k] and S.within(*G.centre(k))),
                  reverse=True)[:60]
    def ground_under(d0, d1, w0, w1):
        hs = []
        for f in (0.05, 0.35, 0.65, 0.95):
            for w in (w0, (w0 + w1) / 2.0, w1):
                d = d0 + (d1 - d0) * f
                kk = G.at(sx + dx * d - dz * w, sz + dz * d + dx * w)
                hs.append(None if kk is None else G.h[kk])
        return hs
    for gs, k in tops:
        sx, sz = G.centre(k)
        sx, sz = _q(sx, 200), _q(sz, 200)
        for dx, dz in dirs:
            e = None
            for off in range(100, 1300, 100):
                kk = G.at(sx + dx * off, sz + dz * off)
                if kk is None or G.h[kk] is None:
                    break
                if G.h[kk] < gs - 200:
                    e = off - 100
                    break
                if G.h[kk] > gs + 5 or not S.open(kk):
                    break
            if e is None:
                continue
            for n in range(8, 2, -1):
                yend = gs - n * drop
                ok = True
                for i in range(n + 2):
                    for f in (0.15, 0.5, 0.85):
                        d = e + (i + f) * seg
                        for w in (-width / 2 - 100, 0, width / 2 + 100):
                            x = sx + dx * d - dz * w
                            z = sz + dz * d + dx * w
                            kk = G.at(x, z)
                            if kk is None or G.h[kk] is None or G.built[kk] or G.water[kk]:
                                ok = False
                                break
                            foot = gs - (min(i, n - 1) + 1) * drop
                            if G.h[kk] > foot:
                                ok = False
                                break
                        if not ok:
                            break
                    if not ok:
                        break
                if not ok:
                    continue
                ex, ez = sx + dx * (e + (n + 2) * seg + 200), sz + dz * (e + (n + 2) * seg + 200)
                ke = G.at(ex, ez)
                if ke is None or G.h[ke] is None or not 0 <= yend - G.h[ke] <= 200 \
                        or not S.open(ke):
                    continue
                if any(math.hypot(sx + dx * d - px, sz + dz * d - pz) < 500
                       for d in range(0, e + (n + 2) * seg, 400) for px, pz in G.points):
                    continue
                score = n * 10 + 50 * S.apart(sx, sz) + S.seen_by(
                    sx + dx * (e + n * seg / 2), gs - n * drop / 2, sz + dz * (e + n * seg / 2))
                if best is None or score > best[0]:
                    best = (score, sx, sz, gs, dx, dz, n, yend, e)
                break
    if best is None:
        return None, "no hill high and long enough for a slide"
    _, sx, sz, gs, dx, dz, n, yend, e = best
    tag = "setpiece.slide"
    out = []
    rect_all = []
    def rect(d0, d1, w0, w1):
        xs = [sx + dx * d - dz * w for d in (d0, d1) for w in (w0, w1)]
        zs = [sz + dz * d + dx * w for d in (d0, d1) for w in (w0, w1)]
        return min(xs), max(xs), min(zs), max(zs)
    rises = {(1, 0): "-x", (-1, 0): "+x", (0, 1): "-z", (0, -1): "+z"}[(dx, dz)]
    for i in range(n):
        d0, d1 = e + i * seg, e + (i + 1) * seg
        y_hi = gs - i * drop
        y_lo = y_hi - drop
        x0, x1, z0, z1 = rect(d0, d1, -width / 2, width / 2)
        ground = max(h for h in ground_under(d0, d1, -width / 2 - 100, width / 2 + 100)
                     if h is not None)
        if y_lo > ground:
            out.append(_box(pal["wall"], x0, x1, ground, y_lo, z0, z1, tag + " stilt"))
        ramp = kit.kind("ramp").make(pal["ice"], int(x0), int(x1), int(y_lo), int(y_hi), int(z0),
                                     int(z1), rises, tag + " chute")
        ramp["slide"] = True
        out.append(ramp)
        for side in (-1, 1):
            w0, w1 = sorted((side * width / 2, side * (width / 2 + 100)))
            wx0, wx1, wz0, wz1 = rect(d0, d1, w0, w1)
            if y_lo + 150 > ground:
                out.append(_box(pal["wood"], wx0, wx1, ground, y_lo + 150, wz0, wz1,
                                tag + " bank"))
            out.append(kit.kind("ramp").make(pal["wood"], int(wx0), int(wx1), int(y_lo + 150),
                                             int(y_hi + 150), int(wz0), int(wz1), rises,
                                             tag + " bank"))
        rect_all.append(rect(d0, d1, -width / 2 - 100, width / 2 + 100))
    d0, d1 = e + n * seg, e + (n + 2) * seg
    x0, x1, z0, z1 = rect(d0, d1, -width / 2, width / 2)
    base = max(h for h in ground_under(d0, d1, -width / 2, width / 2) if h is not None)
    if base < yend:
        out.append(_box(pal["path"], x0, x1, base, yend, z0, z1, tag + " runout"))
    rect_all.append((x0, x1, z0, z1))
    fx, fz = sx + dx * e - dz * (width / 2 + 300), sz + dz * e + dx * (width / 2 + 300)
    out.append(kit.kind("pillar").make(pal["trim"], fx - 40, fx + 40, gs, gs + 900, fz - 40,
                                       fz + 40, None, tag + " pole"))
    out.append(_box(pal["accent"], fx + 40, fx + 360, gs + 600, gs + 850, fz - 10, fz + 10,
                    tag + " flag"))
    for rc in rect_all:
        S.taken.append(rc)
    return out, "a slide %d long from (%d, %d) down %d, on ice" % (
        (n + 2) * seg, sx + dx * e, sz + dz * e, gs - yend)
def floating_islands(S, pal, r):
    from . import basins
    import random as _random
    G = S.G
    th = dict(surround.THEMES.get(pal["theme"], surround.THEMES["garden"]))
    tag = "setpiece.island"
    def airy(pieces):
        x0, x1, lo, hi, z0, z1 = surround.isle_drawn(pieces)
        return G.clear_box(x0, x1, z0, z1, lo - HEADROOM, hi + 400, 100, trees_ok=False)
    mound_tex = basins.mound_texture(S.arena)
    from . import cannons
    def cannon_at(cx, cz):
        for dist in (2000, 1600, 2400, 2800, 3200):
            for dx, dz in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1)):
                f = 0.7071 if dx and dz else 1.0
                px, pz = _q(cx + dx * dist * f), _q(cz + dz * dist * f)
                if dx and dz:
                    dx, dz = (dx, 0) if abs(px - cx) >= abs(pz - cz) else (0, dz)
                k = G.at(px, pz)
                if k is None or G.h[k] is None:
                    continue
                fg = G.h[k]
                for mound in ([mound_tex, None] if mound_tex else [None]):
                    well, wy, rects = basins.cannon_well(px, pz, fg, pal["wall"], pal["path"],
                                                         (dx, dz), mound=mound)
                    yaw = int(math.degrees(math.atan2(cx - px, cz - pz))) % 360
                    if all(S.level(rc, fg) for rc in rects) and \
                            cannons.cone_free(S.arena["pieces"] + S.laid, px, wy, pz, yaw):
                        return px, pz, fg, well, wy, rects
        return None
    sites = []
    for k in range(0, G.nx * G.nz, 3):
        if G.h[k] is None or G.water[k] or (k // G.nx) % 3:
            continue
        cx, cz = G.centre(k)
        cx, cz = _q(cx), _q(cz)
        if not S.within(cx, cz):
            continue
        if any(math.hypot(cx - sx, cz - sz) < SPAWN_CLEAR for sx, sz in S.spawns):
            continue
        g = max(G.top[kk] for kk in (G.at(cx + dx, cz + dz) for dx in (-700, 0, 700)
                                     for dz in (-700, 0, 700)) if kk is not None
                and G.top[kk] is not None)
        sites.append((S.seen_by(cx, g + 2600, cz), cx, cz, g))
    sites.sort(key=lambda s: (S.apart(s[1], s[2]), s), reverse=True)
    pick = None
    for seen, cx, cz, g in sites[:80]:
        for top in (_q(g + 2600), _q(g + 3000)):
            rr = _random.Random("%d/%d/%d" % (cx, cz, top))
            pieces, rect = surround.isle(cx, cz, top, 1400, 1400, rr, th, tag=tag, tiers=3,
                                         solid=True)
            if airy(pieces):
                break
            pieces = None
        if pieces is None:
            continue
        can = cannon_at(cx, cz)
        if can is not None:
            pick = (seen, cx, cz, g, top, pieces, rect, can)
            break
        if pick is None:
            pick = (seen, cx, cz, g, top, pieces, rect, None)
    if pick is None:
        return None, "no open sky over level ground for islands in the sky"
    seen, cx, cz, g, top, pieces, rect, can = pick
    if can is None:
        return None, "islands in the sky: no cannon fits a well near one (no island without a way up)"
    out, objs = list(pieces), []
    aim = None
    if can is not None:
        px, pz, fg, well, wy, rects = can
        out += well
        objs.append({"key": "cannon", "what": "cannon", "x": int(px), "y": int(wy), "z": int(pz),
                     "yaw": int(math.degrees(math.atan2(cx - px, cz - pz))) % 360,
                     "modes": [], "pattern": "setpiece.island"})
        aim = (px, pz)
        for rc in rects:
            S.taken.append(tuple(rc))
    for i in range(5):
        a = 2 * math.pi * i / 5.0
        objs.append({"key": "coin", "what": "coin", "x": int(cx + 350 * math.sin(a)),
                     "y": int(top), "z": int(cz + 350 * math.cos(a)), "yaw": 0,
                     "modes": [], "pattern": "setpiece.island"})
    half_ = (S.arena.get("sites") or {}).get("half") or 0
    for k in range(r.choice((1, 2))):
        a = r.uniform(0, 2 * math.pi)
        ox, oz = _q(cx + math.sin(a) * 2600), _q(cz + math.cos(a) * 2600)
        if not half_ or max(abs(ox), abs(oz)) < half_ + 600:
            continue
        small, srect = surround.isle(ox, oz, _q(top + r.choice((-200, 300, 700))), 700, 700, r,
                                     th, tag=tag, tiers=2)
        if not airy(small):
            continue
        out += small
        S.taken.append(srect)
    S.taken.append(rect)
    return (out, objs), "islands in the sky over (%d, %d), %d up%s" % (
        cx, cz, top - g, ", a cannon aimed at the big one" if aim else " (no cannon fit)")
def secret_alcove(S, pal, r):
    G = S.G
    best = None
    for cx, cz, g in S.candidates(500, step=400):
        k = G.at(cx, cz)
        near = G.d_road[k] if k is not None else 1e9
        if not 400 <= near <= 1600 and getattr(S, "near", None) is None:
            continue
        seen = S.seen_by(cx, g + 100, cz)
        score = -seen + 0.0005 * near
        if best is None or score > best[0]:
            best = (score, cx, cz, g, seen)
    if best is None:
        return None, "no quiet ground beside a path for a secret alcove"
    _, cx, cz, g, seen = best
    k = G.at(cx, cz)
    face = (0, 1)
    worst = None
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        kk = G.at(cx + dx * 800, cz + dz * 800)
        d = G.d_road[kk] if kk is not None else 1e9
        if worst is None or d > worst[0]:
            worst = (d, (dx, dz))
    face = worst[1]
    tag = "setpiece.alcove"
    rock = _natural_rock(S, pal)
    h = 600
    out = []
    fx, fz = face
    def along(u0, u1, v0, v1, y0, y1, what, tex=rock):
        if fx:
            a0, a1 = sorted((cx + fx * u0, cx + fx * u1))
            out.append(_box(tex, a0, a1, y0, y1, cz + v0, cz + v1, tag + " " + what))
        else:
            b0, b1 = sorted((cz + fz * u0, cz + fz * u1))
            out.append(_box(tex, cx + v0, cx + v1, y0, y1, b0, b1, tag + " " + what))
    along(-500, 100, -500, 500, g, g + h, "back")
    along(100, 500, -500, -200, g, g + h, "side")
    along(100, 500, 200, 500, g, g + h, "side")
    along(100, 500, -200, 200, g + 400, g + h, "roof")
    along(-500, 500, -500, 500, g + h, g + h + 200, "cap", pal["cap"])
    seed = (cx * 13 + cz * 7) & 0x7fff
    for k, p in enumerate(out):
        if p["tag"].endswith(" cap"):
            p["sculpt"] = {"shape": "isle", "r": 540, "rz": 540, "depth": 120, "band": 160,
                           "seed": seed, "body": rock, "under": rock, "square": 4,
                           "segs": ISLE_SEGS}
        else:
            p["sculpt"] = {"shape": "rock", "seed": seed + k * 31, "flat": False,
                           "round": 3.2 if p["tag"].endswith(" back") else 4.0}
            p["sculpt"].update(rock_detail(p))
    prize = (cx + fx * 300, cz + fz * 300)
    objs = [{"key": "1up", "what": "1up", "x": int(prize[0]), "y": int(g),
             "z": int(prize[1]), "yaw": 0, "modes": [], "pattern": "setpiece.alcove"}]
    S.taken.append((cx - 500, cx + 500, cz - 500, cz + 500))
    return (out, objs), "a secret alcove at (%d, %d), its mouth away from the paths (seen from %d)" % (
        cx, cz, seen)
ROCK_FACET = 100
ISLE_SEGS = 16
def rock_detail(p):
    return {"segs": max(8, min(14, int(round(max(p["w"], p["d"]) / float(ROCK_FACET))))),
            "rings": max(5, min(8, int(round(p["h"] / (1.2 * ROCK_FACET)))))}
def _crag(tex, x0, x1, y0, y1, z0, z1, tag, seed, rnd=4.5, table=False):
    p = _box(tex, x0, x1, y0, y1, z0, z1, tag)
    p["sculpt"] = dict({"shape": "rock", "seed": seed, "round": rnd, "flat": False},
                       **rock_detail(p))
    if table:
        p["sculpt"]["table"] = True
    return p
def _natural_rock(S, pal):
    have = kit.textures()
    worn = set(p.get("tex") for p in S.arena.get("pieces") or [])
    rocks = [t for t in ("rockboulder", "rockgrey", "rockbrown", pal["rock"]) if t in have]
    return next((t for t in rocks if t in worn), rocks[0] if rocks else pal["rock"])
GROTTO_W = 2000
GROTTO_MOUTH = 400
def waterfall(S, pal, r):
    from . import landrecipes as LR
    best = None
    for cx, cz, g in S.candidates(1250, step=400):
        seen = S.seen_by(cx, g + 600, cz + 900)
        if best is None or seen > best[0]:
            best = (seen, cx, cz, g)
    if best is None:
        got = S.pad(1250, spawn_clear=SPAWN_CLEAR)
        if got is not None:
            cx, cz, g = got
            best = (S.seen_by(cx, g + 600, cz + 900), cx, cz, g)
    if best is None:
        return None, "no level ground for a waterfall"
    seen, cx, cz, g = best
    tag = "setpiece.grotto"
    rock = _natural_rock(S, pal)
    W, M = GROTTO_W, GROTTO_MOUTH
    x0, z0 = _q(cx - W // 2), _q(cz - 900)
    H = r.choice((1800, 2000, 2200))
    face = z0 + 900
    wtop = g + LR.POOL_SURFACE
    ledge = wtop + LR.POOL_DROP
    m0, m1 = x0 + (W - M) // 2, x0 + (W + M) // 2
    seed = (int(cx) * 31 + int(cz) * 17) & 0x7fff
    mid = _q(H * r.uniform(0.5, 0.6))
    out = [
        _crag(rock, x0, m0, g, g + mid, z0, face, "landform.waterfall.cliff", seed + 1),
        _crag(rock, x0 + 200, m0, g + mid, g + H, z0, face, "landform.waterfall.cliff", seed + 11),
        _crag(rock, m1, x0 + W, g, g + mid, z0, face, "landform.waterfall.cliff", seed + 2),
        _crag(rock, m1, x0 + W - 200, g + mid, g + H, z0, face, "landform.waterfall.cliff",
              seed + 12),
        _crag(rock, m0, m1, g, g + H, z0, z0 + 300, "landform.waterfall.cliff", seed + 3),
        _box(rock, m0, m1, g, ledge, z0 + 300, face, tag + " floor"),
        _crag(rock, m0, m1, ledge + 500, g + H, z0 + 300, face, tag + " roof", seed + 4, 6),
    ]
    cap = _box(pal["cap"], x0, x0 + W, g + H, g + H + 200, z0, face, tag + " cap")
    cap["sculpt"] = {"shape": "isle", "r": W // 2 + 60, "rz": 520, "depth": 160, "band": 160,
                     "seed": seed, "body": rock, "under": rock, "square": 5, "segs": ISLE_SEGS}
    out.append(cap)
    for sx, x in ((-1, x0), (1, x0 + W)):
        bw = r.choice((500, 600))
        a0, a1 = sorted((x, x + sx * bw))
        out.append(_crag(rock, a0, a1, g, g + _q(H * r.uniform(0.35, 0.5)), z0 + 100,
                         face - 100, "landform.waterfall.cliff", seed + 5 + sx, 3.5))
    fall = kit.kind("water").make("watersurface", m0 - 40, m1 + 40, wtop, g + H - 60,
                                  face, face + LR.FALL_THICK, None, "landform.waterfall.fall")
    fall["sculpt"] = {"shape": "sheet", "out": [0, 1], "seed": seed, "bow": 70}
    out.append(fall)
    pz1 = face + 1000
    for (a0, a1, b0, b1) in ((x0, x0 + 200, face, pz1), (x0 + W - 200, x0 + W, face, pz1),
                             (x0 + 200, x0 + W - 200, pz1 - 200, pz1)):
        along_x = a1 - a0 > b1 - b0
        lo, hi = (a0, a1) if along_x else (b0, b1)
        cuts = [lo]
        while hi - cuts[-1] > 500:
            cuts.append(cuts[-1] + r.choice((300, 400, 500)))
        cuts.append(hi)
        for k, (c0, c1) in enumerate(zip(cuts, cuts[1:])):
            top_k = wtop + LR.POOL_DROP + r.choice((0, 20, 40, 60))
            box = (c0, c1, b0, b1) if along_x else (a0, a1, c0, c1)
            out.append(_crag(rock, box[0], box[1], g, top_k, box[2], box[3],
                             "landform.waterfall.rim", seed + c0 + k, 2.4))
    out.append(kit.kind("water").make("watersurface", x0 + 200, x0 + W - 200, wtop - 20, wtop,
                                      face + LR.FALL_THICK, pz1 - 200, None,
                                      "landform.waterfall.pool"))
    out.append(_box(rock, x0 + 200, x0 + W - 200, g, g + LR.POOL_FLOOR, face, pz1 - 200,
                    "landform.waterfall.floor"))
    have = kit.textures()
    foam_tex = next((t for t in ("snowfresh", "plasterwhite") if t in have), None)
    if foam_tex:
        mx = (m0 + m1) // 2
        for k, (fx, fw, dy, dz) in enumerate(((mx, M + 200, 0, 60), (mx - M // 2 - 260, 280, -4, 90),
                                              (mx + M // 2 + 260, 260, -2, 120))):
            f = kit.kind("water").make(foam_tex, fx - fw // 2, fx + fw // 2, wtop - 10 + dy,
                                       wtop + 60 + dy, face + dz, face + dz + _q(fw * 0.6, 10),
                                       None, tag + " foam")
            f["sculpt"] = {"shape": "cloud", "seed": seed + 40 + k, "tone": [240, 242, 246]}
            out.append(f)
    water = S.arena.setdefault("water", [])
    if len(water) < WATER_ROWS:
        water.append([x0 + 200, face, x0 + W - 200, pz1 - 200, wtop, g])
    objs = [{"key": "1up", "what": "1up", "x": int((m0 + m1) // 2), "y": int(ledge),
             "z": int(z0 + 450), "yaw": 0, "modes": [], "pattern": "setpiece.grotto"}]
    S.taken.append((x0 - 600, x0 + W + 600, z0, pz1))
    return (out, objs), "a waterfall with a grotto behind it at (%d, %d); seen from %d of %d " \
        "paths" % ((m0 + m1) // 2, face, seen, len(S.eyes))
BUILDERS = {"lookout": lookout, "spiral_path": spiral_path, "slide": slide,
            "floating_islands": floating_islands, "secret_alcove": secret_alcove,
            "waterfall": waterfall}
MUSHROOM_LOOKS = {"red": ("teamred", [208, 48, 44]), "blue": ("teamblue", [40, 92, 212]),
                  "brown": ("beamacacia", [158, 92, 58])}
MUSHROOM_CAPS = {"garden": "red", "sky": "red", "castle": "red", "wood": "brown",
                 "lava": "brown", "desert": "brown", "ice": "blue"}
MUSHROOM_CREAM = "plasterwhite"
STEM_TONE, SPOT_TONE = [222, 208, 180], [232, 228, 220]
GILL_TONES = ([214, 196, 166], [184, 162, 132])
MUSHROOM_RISE = 200
PILLAR_FILL = 0.6
CAP_STEPS = ((1.0, 0.6), (0.78, 0.78), (0.45, 0.94))
CAP_DOME = 200
CAP_DOME_LEAST = 170
def _mushroom(cx, cz, g, top, w, look, tag, r, spots=5, dome_most=None):
    out = []
    R = w // 2
    o = lambda rad: rad / PILLAR_FILL
    cap_tex, cap_tone = MUSHROOM_LOOKS.get(look, MUSHROOM_LOOKS["red"])
    H = max(CAP_DOME_LEAST, _q(R * 0.42, 10))
    if dome_most:
        H = min(H, dome_most)
    rim = top - int(round(H * CAP_STEPS[-1][1]))
    lip = max(60, min(90, _q(R * 0.14, 10)))
    if rim - lip < g:
        rim = g + lip
        H = max(60, int((top - rim) / CAP_STEPS[-1][1]))
    dome_top = rim + H
    stem_r = 0
    foot = g
    if rim - lip - 60 > g + 100:
        stem_r = max(100, _q(R * r.uniform(0.26, 0.32), 10))
        if tag.endswith(".tall"):
            stem_r = max(140, _q(R * r.uniform(0.3, 0.36), 10))
        foot = rim - lip // 2
        out.append(dict(surround._oct(MUSHROOM_CREAM, cx, cz, o(stem_r), o(stem_r), g, foot,
                                      tag + ".stem"),
                        sculpt={"shape": "stem", "r": stem_r, "flare": 1.35,
                                "tone": STEM_TONE, "top": rim + H // 3}))
    dome = [cx, cz, R, rim, dome_top]
    turn = r.uniform(0, 360)
    ring = spots - 1 if spots >= 5 else spots
    dots = []
    for i in range(spots):
        if i == ring:
            dots.append([0.0, 0.0, 17])
        else:
            dots.append([50 + 8 * ((i * 7) % 3 - 1),
                         round(turn + 360.0 * i / ring + r.uniform(-12, 12), 1),
                         r.choice((14, 16, 18))])
    y = foot
    for k, (share, up) in enumerate(CAP_STEPS):
        y1 = max(y + 20, rim + int(round(H * up)))
        if k == 1:
            p = surround._oct(MUSHROOM_CREAM, cx, cz, o(R * share), o(R * share), y, y1,
                              tag + ".cap.spot")
            p["sculpt"] = {"shape": "spot", "dome": dome, "dots": dots, "tone": SPOT_TONE}
        elif k == 2:
            p = surround._oct(MUSHROOM_CREAM, cx, cz, o(R * share), o(R * share), y, y1,
                              tag + ".cap.under")
            p["sculpt"] = {"shape": "none"} if not stem_r else {
                "shape": "under", "r": int(R * 0.9), "stem": int(stem_r * 0.86),
                "rise": lip, "at": rim - lip, "x": cx, "z": cz, "tone": GILL_TONES[0],
                "tone2": GILL_TONES[1]}
        else:
            p = surround._oct(cap_tex, cx, cz, o(R * share), o(R * share), y, y1, tag + ".cap")
            p["sculpt"] = {"shape": "cap", "r": R, "top": dome_top, "lip": lip,
                           "tone": cap_tone, "rim": rim}
        out.append(p)
        y = y1
    return out, top
def _mushroom_chain(cx, cz, g, n, r, box=1600):
    def fits(x, z, half, caps):
        if abs(x - cx) + half > box or abs(z - cz) + half > box:
            return False
        return not any(math.hypot(x - qx, z - qz) < qh + half + 150
                       for qx, qz, qh, _ in caps[:-1])
    best = []
    for attempt in range(12):
        a = r.uniform(0, 2 * math.pi)
        sense = r.choice((1, -1))
        x, z = _q(cx + 900 * math.sin(a)), _q(cz + 900 * math.cos(a))
        caps = [(x, z, 300, g + MUSHROOM_RISE)]
        head = a + sense * math.pi / 2
        for i in range(1, n):
            top = g + MUSHROOM_RISE * (i + 1)
            sizes = (1500, 1200, 1000) if i == n - 1 else (min(1000, 600 + 100 * i),)
            done = False
            for w in sizes:
                for turn in (35, 60, 15, 0, 90, -25):
                    b = head + sense * math.radians(turn)
                    px, pz, ph, _ = caps[-1]
                    d = ph + w // 2
                    nx_, nz_ = _q(px + math.sin(b) * d), _q(pz + math.cos(b) * d)
                    if math.hypot(nx_ - px, nz_ - pz) > d + 50:
                        continue
                    if fits(nx_, nz_, w // 2, caps):
                        caps.append((nx_, nz_, w // 2, top))
                        head = b
                        done = True
                        break
                if done:
                    break
            if not done:
                break
        if len(caps) > len(best):
            best = caps
        if len(best) == n:
            break
    return best
def giant_mushrooms(S, pal, r):
    look = MUSHROOM_CAPS.get(pal["theme"], "red")
    best = None
    for site in (1600, 1200):
        if best is not None:
            break
        for cx, cz, g in S.candidates(site, step=400):
            seen = S.seen_by(cx, g + 1200, cz)
            if best is None or seen > best[0]:
                best = (seen, cx, cz, g, site)
    if best is None:
        got = S.pad(1600)
        if got is not None:
            cx, cz, g = got
            best = (S.seen_by(cx, g + 1200, cz), cx, cz, g, 1600)
    if best is None:
        return None, "no level ground 2400 across for giant mushrooms"
    seen, cx, cz, g, site = best
    tag = "setpiece.mushroom"
    n = r.choice((5, 6, 7))
    caps = _mushroom_chain(cx, cz, g, n, r, box=site)
    if len(caps) < 4:
        return None, "the mushrooms found no way up on the ground there"
    out = []
    for i, (x, z, h, top) in enumerate(caps):
        ps, _ = _mushroom(x, z, g, top, 2 * h, look, tag, r, spots=5 if h >= 450 else 3,
                          dome_most=CAP_DOME)
        out += ps
    chain = list(caps)
    want, tries = r.choice((2, 3)), 0
    b0 = r.uniform(0, 2 * math.pi)
    while want and tries < 24:
        b = b0 + 2.4 * tries
        reach = (1450, 1650, 1250)[tries % 3] * site / 1600.0
        tries += 1
        x, z = _q(cx + math.sin(b) * reach), _q(cz + math.cos(b) * reach)
        w = _q(r.choice((900, 1100, 1300)) if tries < 8 else 800, 100)
        if any(math.hypot(x - qx, z - qz) < qh + w // 2 + 200 for qx, qz, qh, _ in caps):
            continue
        if max(abs(x - cx), abs(z - cz)) > site + CLEAR // 2:
            continue
        want -= 1
        top = g + _q(max(1000, min(2000, w * r.uniform(1.3, 1.7))))
        ps, _ = _mushroom(x, z, g, top, w, look, tag + ".tall", r, spots=5)
        out += ps
        caps.append((x, z, w // 2, top))
    lx, lz, lh, ltop = chain[-1]
    objs = []
    for i in range(4):
        b = 2 * math.pi * i / 4.0 + math.pi / 4
        objs.append({"key": "coin", "what": "coin", "x": int(lx + lh * 0.2 * math.sin(b)),
                     "y": int(ltop), "z": int(lz + lh * 0.2 * math.cos(b)), "yaw": 0,
                     "modes": [], "pattern": "setpiece.mushroom"})
    fx, fz, fh, _ = caps[0]
    tx, tz = fx + (fx - cx) / max(1.0, math.hypot(fx - cx, fz - cz)) * (fh + 300), \
        fz + (fz - cz) / max(1.0, math.hypot(fx - cx, fz - cz)) * (fh + 300)
    if abs(tx - cx) < 1500 and abs(tz - cz) < 1500:
        objs.append({"key": "trampoline", "what": "trampoline", "x": int(tx), "y": int(g),
                     "z": int(tz), "yaw": 0, "modes": [], "pattern": "setpiece.mushroom"})
    S.taken.append((min(p["x"] - p["w"] / 2 for p in out), max(p["x"] + p["w"] / 2 for p in out),
                    min(p["z"] - p["d"] / 2 for p in out), max(p["z"] + p["d"] / 2 for p in out)))
    return (out, objs), "giant mushrooms at (%d, %d): %d caps climbing %d, the forest round " \
        "them; seen from %d of %d paths" % (cx, cz, len(chain), ltop - g, seen, len(S.eyes))
BUILDERS["giant_mushrooms"] = giant_mushrooms
STUDIO = (
    ("giant_mushrooms", "Giant mushrooms",
     "Mario's mushroom platforms climbing in a spiral, a mushroom forest round them"),
    ("waterfall", "Waterfall grotto",
     "a rock cliff with a waterfall, a cave behind the water and a pool"),
    ("lookout", "Lookout tower", "a tower with stairs winding up to a roofed deck"),
    ("spiral_path", "Spiral summit", "a rocky summit with a path spiralling to its flag"),
    ("secret_alcove", "Secret hideout", "a rock outcrop with a hidden hollow and a 1-up"),
    ("slide", "Ice slide", "an ice chute from a hill top down to the ground"),
    ("floating_islands", "Islands in the sky", "floating islands with coins, a cannon to reach them"),
)
def build_at(arena, kind, x, z, theme=None, seed=1):
    import random as _random
    brief = {"family": "explore", "theme": theme if theme not in (None, "auto") else "garden",
             "size": "large", "features": {"want": [kind], "avoid": []}}
    arena = dict(arena)
    arena["pieces"] = list(arena.get("pieces") or [])
    had = list(arena.get("water") or [])
    arena["water"] = list(had)
    S = Site(arena, brief)
    S.near = (x, z)
    got, why = BUILDERS[kind](S, _pal(arena, brief), _random.Random(seed))
    if got is None:
        return None, None, None, why
    objs = []
    if isinstance(got, tuple):
        got, objs = got
    m = v1.arenas_module()
    for p in got:
        p["model"] = m.model_name(p)
    return got, objs, arena["water"][len(had):], why
def preview(kind, theme="garden"):
    m = v1.arenas_module()
    ground = []
    for x0 in range(-6000, 6000, 4000):
        for z0 in range(-6000, 6000, 4000):
            ground.append(_box("grass", x0, x0 + 4000, -400, 0, z0, z0 + 4000, "ground"))
    for k in range(6):
        a = 500 * k
        ground.append(_box("grass", 1000 + a, 6000, 400 * k, 400 * (k + 1), -2500 + a // 2,
                           2500 - a // 2, "hills"))
    arena = {"level": "empty2", "pieces": ground, "objects": [], "survey": {},
             "spawns": [{"x": -5000, "y": 0, "z": -5000, "yaw": 0}]}
    for p in ground:
        p["model"] = m.model_name(p)
    at = (3000, 0) if kind == "slide" else (-2500, 0)
    got, _, _, _ = build_at(arena, kind, at[0], at[1], theme)
    return got or []
def fit_textures(world, got):
    from . import values
    before = scatter.texture_keys(world)
    if len(scatter.texture_keys(world + got)) <= max(scatter.TEX_LINE, len(before)):
        return True
    worn = set(p.get("tex") for p in world)
    for p in got:
        t = p.get("tex")
        if t in worn or t in (None, "invisible") or p.get("kind") == "water":
            continue
        subs = [s for s in values.members(t, worn) if s != t
                and kit.layered(s) == kit.layered(t)]
        if subs:
            p["tex"] = subs[len(subs) // 2]
    return len(scatter.texture_keys(world + got)) <= max(scatter.TEX_LINE, len(before))
def move_pickups(arena, S, pieces):
    m = v1.arenas_module()
    rects = []
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        rects.append((x0 - 200, x1 + 200, z0 - 200, z1 + 200))
    def inside(x, z):
        return any(a <= x <= b and c <= z <= d for a, b, c, d in rects)
    G = S.G
    half = (arena.get("sites") or {}).get("half") or 99999
    moved = lost = 0
    keep = []
    for o in arena.get("objects") or []:
        if not (isinstance(o, dict) and o.get("key") in LOOSE and "x" in o
                and inside(o["x"], o["z"])):
            keep.append(o)
            continue
        hit = [r for r in rects if r[0] <= o["x"] <= r[1] and r[2] <= o["z"] <= r[3]]
        a, b, c, d = (min(r[0] for r in hit), max(r[1] for r in hit),
                      min(r[2] for r in hit), max(r[3] for r in hit))
        cx, cz = (a + b) / 2.0, (c + d) / 2.0
        dx, dz = o["x"] - cx, o["z"] - cz
        first = ((1 if dx >= 0 else -1, 0) if abs(dx) / max(1.0, b - a)
                 >= abs(dz) / max(1.0, d - c) else (0, 1 if dz >= 0 else -1))
        ways = [first] + [w for w in ((1, 0), (-1, 0), (0, 1), (0, -1)) if w != first]
        put = None
        for ux, uz in ways:
            x = (b + LOOSE_STEP if ux > 0 else a - LOOSE_STEP) if ux else o["x"]
            z = (d + LOOSE_STEP if uz > 0 else c - LOOSE_STEP) if uz else o["z"]
            k = G.at(x, z)
            if max(abs(x), abs(z)) > half - 200 or k is None or G.h[k] is None \
                    or G.water[k] or G.built[k] or G.sloped[k] or inside(x, z):
                continue
            if G.top[k] is not None and G.top[k] > G.h[k] + 5:
                continue
            put = (x, G.h[k], z)
            break
        if put is None:
            lost += 1
            continue
        o["x"], o["z"] = int(put[0]), int(put[2])
        o["y"] = int(put[1])
        moved += 1
        keep.append(o)
    if lost:
        arena["objects"] = keep
    return moved, lost
def run(arena, brief, room, rnd, wished_room=None):
    if brief.get("family") not in scatter.FAMILIES:
        return [], [], [], []
    want, avoid = wanted(brief)
    from . import budget as budgetmod
    tier = budgetmod.tier_of(brief.get("size") or "medium")
    theme = brief.get("theme") if brief.get("theme") not in (None, "auto") else "garden"
    extra = [k for k in THEME_PICKS.get(theme, THEME_PICKS["garden"])
             if k not in want and k not in avoid]
    todo = list(want) + extra[:max(0, DEFAULT_COUNT.get(tier, 0) - len(want))]
    f = brief.get("features") or {}
    asked = "waterfall" in (f.get("want") or ()) or any(
        q.get("kind") == "place" and q.get("of") == "waterfall"
        for q in brief.get("requests") or ())
    grotto = any(q.get("kind") == "place" and q.get("of") == "waterfall"
                 and str(q.get("what")) in ("cave", "caves", "grotto")
                 and q.get("relation") in ("behind", "inside", "under")
                 for q in brief.get("requests") or ())
    if asked and "waterfall" not in avoid and (grotto or not any(
            "waterfall" in str(p.get("tag", "")) for p in arena.get("pieces") or ())):
        todo.insert(0, "waterfall")
    if not todo:
        return [], [], [], []
    S = Site(arena, brief)
    pal = _pal(arena, brief)
    pieces, objs, notes = [], [], []
    pads_gone = []
    for kind in todo:
        lim = wished_room if wished_room is not None and kind in want else room
        if COST[kind] > lim - len(pieces):
            notes.append("set piece %s: no room left in the budget" % kind.replace("_", " "))
            continue
        waters = len(arena.get("water") or [])
        before = S.arena, S.G
        def unpad():
            if S.pad_new:
                S.arena, S.G = before
                S.pad_gone, S.pad_new = [], []
        got, why = BUILDERS[kind](S, pal, rnd)
        if got is None:
            unpad()
            notes.append("set piece %s: not built - %s" % (kind.replace("_", " "), why))
            continue
        more = []
        if isinstance(got, tuple):
            got, more = got
        if not fit_textures(arena["pieces"] + pieces, got):
            unpad()
            notes.append("set piece %s: not built - its blocks would take the level past %d "
                         "pictures" % (kind.replace("_", " "), scatter.TEX_LINE))
            if arena.get("water") is not None:
                del arena["water"][waters:]
            continue
        from . import cannons
        blocks = [o for o in S.cannons
                  if not cannons.cone_free(got, o["x"], o["y"], o["z"], o.get("yaw") or 0)]
        if blocks:
            unpad()
            notes.append("set piece %s: not built - it would stand in a cannon's firing cone"
                         % kind.replace("_", " "))
            if arena.get("water") is not None:
                del arena["water"][waters:]
            continue
        m = v1.arenas_module()
        for p in got:
            p["model"] = m.model_name(p)
        if S.pad_new:
            got = list(S.pad_new) + got
            pads_gone.extend(S.pad_gone)
            S.pad_gone, S.pad_new = [], []
            notes.append("set piece %s: its site levelled (a pad %d pieces)"
                         % (kind.replace("_", " "), len(got)))
        objs += more
        S.cannons += [o for o in more if o.get("what") == "cannon"]
        S.laid += got
        pieces += got
        S.placed.append((min(p["x"] for p in got), max(p["x"] for p in got),
                         min(p["z"] for p in got), max(p["z"] for p in got)))
        notes.append("set piece: %s" % why)
    if pieces:
        moved, lost = move_pickups(arena, S, pieces)
        if moved or lost:
            notes.append("set pieces: %d pickups moved off their sites%s"
                         % (moved, ", %d with no ground beside them left out" % lost
                            if lost else ""))
    gone = []
    if pieces:
        m = v1.arenas_module()
        rects = []
        for p in pieces:
            x0, x1, z0, z1, _ = m.footprint(p)
            rects.append((x0 - 150, x1 + 150, z0 - 150, z1 + 150))
        from . import flora
        for tree in flora.groups(arena.get("pieces") or []):
            if any(not (x1 <= a or x0 >= b or z1 <= c or z0 >= d)
                   for p in tree for (x0, x1, z0, z1, _) in [m.footprint(p)]
                   for (a, b, c, d) in rects):
                gone += tree
        if gone:
            notes.append("set pieces: %d tree pieces cleared from their sites" % len(gone))
    return pieces, objs, notes, gone + pads_gone
