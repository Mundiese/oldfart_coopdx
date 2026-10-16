import math
from . import v1
CELL = 200
FEATURE_R = 800
PATCH = 1600
PATCH_ONE = 0.9
PROP_WINDOW = 800
PINCH = 150
PINCH_MIN = 40
EYE = 160
WEIGHTS = {"emptiness": 1.0, "mud": 1.0, "overlaps": 1.5, "floating": 1.5, "monotony": 1.0,
           "composition": 1.0,
           "hero_seen": 1.0, "vista": 0.6, "weenies": 0.8, "mode_fit": 1.5,
           "spawn_fairness": 1.0, "sightline": 0.8, "chokes": 0.6, "lanes": 0.8,
           "contact": 0.8, "integration": 0.8, "connectivity": 0.5, "objective_found": 0.8,
           "height_paid": 0.6, "contrast": 0.8, "value_bands": 0.6, "silhouette": 0.8,
           "palette": 0.6,
           "grounding": 1.0, "ground_calm": 0.4, "texture_count": 0.4, "saturation": 0.4,
           "light_height": 0.3, "shadow_colour": 0.2, "away_side": 0.3,
           "value_curve": 0.6, "calm": 0.5, "focal": 0.6, "depth_colour": 0.3, "tiling": 0.4,
           "liminal": 0.8}
LOW_ROWS = ("emptiness", "mud", "overlaps", "floating", "monotony", "composition", "reach",
            "mode_fit", "spawn_fairness", "grounding", "surroundings", "world_edge")
GROUP = {"lit_share": "looks", "pool_contrast": "looks", "light_leaks": "looks",
         "glow_on_structure": "looks", "emitter_without_light": "looks", "live_budget": "looks",
         "spawn_fairness": "play", "sightline": "play", "chokes": "play", "lanes": "play",
         "contact": "play", "integration": "play", "connectivity": "play",
         "objective_found": "play", "height_paid": "play", "mode_fit": "play", "reach": "play",
         "play": "play",
         "composition": "looks", "hero_seen": "looks", "vista": "looks", "weenies": "looks",
         "contrast": "looks", "value_bands": "looks", "silhouette": "looks", "palette": "looks",
         "monotony": "looks", "surroundings": "looks", "ground_calm": "looks", "texture_count": "looks",
         "saturation": "looks", "light_height": "looks", "shadow_colour": "looks",
         "away_side": "looks", "value_curve": "looks", "calm": "looks", "focal": "looks",
         "depth_colour": "looks", "tiling": "looks", "liminal": "looks"}
LABELS = {"emptiness": "Empty ground", "mud": "Prop clutter", "overlaps": "Overlaps",
          "floating": "Floating objects", "monotony": "Texture variety",
          "composition": "Composition", "reach": "Pickups in reach",
          "hero_seen": "Landmark seen from the spawns", "vista": "A framed view on arrival",
          "weenies": "Something tall in every part", "mode_fit": "Has what its modes need",
          "spawn_fairness": "Fair spawns", "sightline": "Longest sightline",
          "chokes": "Chokes per lane", "lanes": "Lanes between the bases",
          "contact": "Time to first contact", "integration": "The middle is central",
          "connectivity": "The middle opens out", "objective_found": "Objective easy to find",
          "height_paid": "High ground has a cost", "contrast": "Floor and wall contrast",
          "value_bands": "Light, middle and dark", "silhouette": "Mario stands out",
          "palette": "Colour shares (60-30-10)", "play": "How it plays",
          "surroundings": "Something to look at around the map",
          "world_edge": "Inside the world"}
from .metrics.artdir import LABELS as _ART_LABELS, EXPLAIN as _ART_EXPLAIN
LABELS.update(_ART_LABELS)
EXPLAIN = {
    "emptiness": "Big bare places with nothing to do or look at get boring. Every part "
                 "of the map should have something: a hill, a wall, a thing to pick up.",
    "mud": "Too many props squeezed into one corner look like a mess.",
    "overlaps": "Two blocks inside each other, or a thin gap nobody fits in, look like a "
                "mistake.",
    "floating": "Things like coins or cannons should stand on the floor, not hang in the "
                "air.",
    "monotony": "If one texture covers almost everything, the map looks plain. Mix in a "
                "second one.",
    "composition": "A good map has high and low places, and something to look at in each "
                   "part.",
    "reach": "Every coin and star should be possible to reach.",
    "hero_seen": "From where you start you should see the big landmark, so you know where "
                 "to go.",
    "vista": "When you arrive, a long view framed by buildings or trees feels exciting.",
    "weenies": "Something tall in every part of the map pulls you to walk there.",
    "mode_fit": "Each game mode needs certain things (flags, a hill, spawn points). This "
                "checks the map has them.",
    "spawn_fairness": "Every team should start in an equally safe place.",
    "sightline": "Very long open lines let one player shoot across the whole map. Walls "
                 "should break them.",
    "chokes": "Narrow doors between the bases make fights stuck. A few are fine, too many "
              "are not.",
    "lanes": "The bases should be joined by the number of paths the mode likes.",
    "contact": "The teams should meet after a good few seconds, not at once and not "
               "never.",
    "integration": "The middle of the map should be where the paths meet.",
    "connectivity": "There should be many ways into the middle and out of each base.",
    "objective_found": "The thing to capture should be easy to find from the start.",
    "height_paid": "High places are strong, so reaching them should take some effort.",
    "contrast": "The floor and the walls should look different, so you can see where to "
                "walk.",
    "value_bands": "A nice picture has light, middle and dark parts.",
    "silhouette": "Mario should stand out against what is behind him.",
    "palette": "One main colour, a second colour and a little bit of a special colour "
               "look best (60-30-10).",
    "play": "How well the map plays, measured by running through it.",
    "surroundings": "A party island or a race track floats in the sky. Big rocks and "
                    "islands all around, and something tall far away, make it a "
                    "picture instead of an empty sky.",
    "world_edge": "The game cannot go further than 32,000 from the middle of the map. "
                  "A piece out there is lost in the game and the level cannot be "
                  "exported. Fix it moves it just inside.",
}
EXPLAIN.update(_ART_EXPLAIN)
PASS = {"explore": 62, "hide": 60, "default": 58}
WORST_SHARE = 0.4
FAMILY_WEIGHTS = {"race": {"emptiness": 0.3, "monotony": 0.6, "vista": 0.4, "weenies": 0.5,
                           "surroundings": 0.8},
                  "knockoff": {"emptiness": 0.2, "monotony": 0.4, "composition": 0.4,
                               "hero_seen": 0.4, "vista": 0.3, "weenies": 0.3,
                               "surroundings": 0.8},
                  "party": {"emptiness": 0.3, "composition": 0.4, "hero_seen": 0.3,
                            "vista": 0.2, "weenies": 0.3, "surroundings": 0.8},
                  "hide": {"vista": 0.4}}
SKIP_TEX = ("invisible",)
LEVEL_COLOUR = (150, 146, 136)
GROUND_TEX = {"grass": "grass", "ice": "ice", "sand": "sand", "stone": "flagstone",
              "snow": "snowblock", "wood": "woodenplank1"}
NATURAL_TEX = ("grass", "sand", "snowblock")
def _m():
    return v1.arenas_module()
def _solid(p):
    return p.get("tex") not in SKIP_TEX and p.get("kind") != "water"
def _is_prop(p):
    t = str(p.get("tag", ""))
    return bool(p.get("decor")) or t.startswith(("decor", "dress", "stall"))
def _root(p):
    t = str(p.get("tag", "")) or p.get("kind", "")
    parts = t.split(".")
    return ".".join(parts[:2]) if parts[0] in ("landmark", "prefab", "play") else parts[0]
class HeightGrid(object):
    def __init__(self, arena):
        m = _m()
        self.top = {}
        self.tex = {}
        self.water = set()
        from . import place
        try:
            bx0, bx1, bz0, bz1 = place.bounds(arena)
        except (ValueError, KeyError):
            bx0 = bx1 = bz0 = bz1 = 0
        half = (arena.get("sites") or {}).get("half") if isinstance(arena.get("sites"),
                                                                    dict) else None
        if half:
            bx0, bx1, bz0, bz1 = max(bx0, -half), min(bx1, half), max(bz0, -half), min(bz1, half)
        self.bounds = (int(math.floor(bx0 / CELL)), int(math.ceil(bx1 / CELL)),
                       int(math.floor(bz0 / CELL)), int(math.ceil(bz1 / CELL)))
        floor = (m.LEVELS.get(arena.get("level")) or {}).get("floor")
        self.ground = GROUND_TEX.get(arena.get("ground"))
        if floor is not None:
            for i in range(self.bounds[0], self.bounds[1]):
                for j in range(self.bounds[2], self.bounds[3]):
                    self.top[(i, j)] = float(floor)
                    self.tex[(i, j)] = self.ground or "level"
        for p in arena.get("pieces") or []:
            if p.get("tex") in SKIP_TEX or str(p.get("tag", "")).startswith("dress.backdrop"):
                continue
            try:
                x0, x1, z0, z1, _ = m.footprint(p)
            except Exception:
                continue
            for i in range(max(self.bounds[0], int(math.floor(x0 / CELL))),
                           min(self.bounds[1], int(math.ceil(x1 / CELL)))):
                for j in range(max(self.bounds[2], int(math.floor(z0 / CELL))),
                               min(self.bounds[3], int(math.ceil(z1 / CELL)))):
                    cx, cz = (i + 0.5) * CELL, (j + 0.5) * CELL
                    if not (x0 <= cx <= x1 and z0 <= cz <= z1):
                        continue
                    if p.get("kind") == "box":
                        t = p["y"] + p["h"]
                    else:
                        try:
                            t = m.top_at(p, cx, cz)
                        except Exception:
                            t = p["y"] + p["h"]
                        if t is None:
                            continue
                    if t > self.top.get((i, j), -1e9):
                        self.top[(i, j)] = t
                        self.tex[(i, j)] = p.get("tex")
                        if p.get("kind") == "water" or str(p.get("tex", "")).startswith("water"):
                            self.water.add((i, j))
                        else:
                            self.water.discard((i, j))
    def at(self, x, z):
        return self.top.get((int(math.floor(x / CELL)), int(math.floor(z / CELL))))
def _clamp(v):
    return max(0.0, min(1.0, v))
def emptiness(grid, arena):
    r = int(FEATURE_R // CELL)
    cells = [c for c in grid.top if c not in grid.water]
    if not cells:
        return 0.0, 1.0, "no ground"
    feature = set()
    for (i, j), t in grid.top.items():
        for a, b in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            u = grid.top.get((i + a, j + b))
            if u is not None and abs(u - t) >= 100:
                feature.add((i, j))
                break
    for o in arena.get("objects") or []:
        feature.add((int(math.floor(o["x"] / CELL)), int(math.floor(o["z"] / CELL))))
    dist = dict((c, 0) for c in feature)
    front = sorted(feature)
    for d in range(1, r + 1):
        nxt = []
        for (i, j) in front:
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    c = (i + a, j + b)
                    if c not in dist and c in grid.top:
                        dist[c] = d
                        nxt.append(c)
        front = nxt
    empty = sum(1 for c in cells if c not in dist)
    share = empty / float(len(cells))
    return share, _clamp(1.0 - max(0.0, share - 0.10) / 0.30), "%d%% empty ground" % round(
        share * 100)
def mud(arena):
    pts = [(p["x"], p["z"]) for p in arena.get("pieces") or [] if _is_prop(p)
           and not str(p.get("tag", "")).startswith("dress.backdrop")]
    pts += [(o["x"], o["z"]) for o in arena.get("objects") or []
            if not str(o.get("key", "")).startswith(("coin", "redcoin", "bluecoin"))]
    half = PROP_WINDOW // 2
    cell = {}
    for x, z in pts:
        k = (int(x // half), int(z // half))
        cell[k] = cell.get(k, 0) + 1
    peak = 0
    for (i, j) in cell:
        for a in (0, -1):
            for b in (0, -1):
                n = sum(cell.get((i + a + u, j + b + v), 0) for u in (0, 1) for v in (0, 1))
                peak = max(peak, n)
    return peak, _clamp(1.0 - max(0, peak - 8) / 12.0), "densest %d m square: %d props" % (
        PROP_WINDOW // 100, peak)
def overlaps(arena):
    from .guards import Index
    m = _m()
    pieces = [p for p in arena.get("pieces") or [] if _solid(p)]
    ix = Index(pieces)
    out = []
    seen = set()
    for i, p in enumerate(pieces):
        a = ix.rects[i]
        rp = _root(p)
        for j in ix.near(a[0], a[1], a[2], a[3]):
            if j <= i:
                continue
            q = pieces[j]
            rq = _root(q)
            if rp == rq:
                continue
            b = ix.rects[j]
            ox = min(a[1], b[1]) - max(a[0], b[0])
            oz = min(a[3], b[3]) - max(a[2], b[2])
            if ox <= 20 or oz <= 20:
                continue
            pt, qt = p["y"] + p["h"], q["y"] + q["h"]
            oy = min(pt, qt) - max(p["y"], q["y"])
            kinds = (p.get("kind"), q.get("kind"))
            big = (ox >= 100 and oz >= 100)
            if oy > 40 and big and "box" in kinds and not _terrain(p) and not _terrain(q):
                if _built(p) and _built(q) and (rp, rq) not in seen:
                    seen.add((rp, rq))
                    out.append((p, q, "inside each other"))
                continue
            for lo, hi in ((p, q), (q, p)):
                gap = hi["y"] - (lo["y"] + lo["h"])
                if PINCH_MIN <= gap < PINCH and big and _built(hi) and not _is_prop(hi) \
                        and not _is_prop(lo) and (rp, rq, "pinch") not in seen:
                    seen.add((rp, rq, "pinch"))
                    out.append((hi, lo, "hangs %d over a top" % gap))
    return out
def _terrain(p):
    t = str(p.get("tag", ""))
    return t.startswith(("terrace", "hills", "edge", "road", "lake", "river", "slope", "ground",
                         "path", "plaza", "rock", "landform", "street"))
def _built(p):
    return not _terrain(p) and not str(p.get("tag", "")).startswith(("tree", "detail"))
def floating(arena):
    from . import guards, triblock
    out = [(o, "stands on nothing") for o in guards.floating_objects(arena)]
    out += triblock.faults(arena)
    return out
def monotony(grid, arena):
    area = {}
    for c, t in grid.tex.items():
        if t:
            area[t] = area.get(t, 0) + 1.0
    for p in arena.get("pieces") or []:
        if not _solid(p):
            continue
        side = 2.0 * (float(p["w"]) + float(p["d"])) * float(p["h"]) / (CELL * CELL)
        area[p.get("tex")] = area.get(p.get("tex"), 0) + side * 0.5
    total = sum(area.values())
    if not total:
        return 1.0, 0.0, "nothing drawn"
    top = max(area.values())
    share = top / total
    probs = [v / total for v in area.values()]
    ent = -sum(q * math.log(q) for q in probs if q > 0)
    name = max(area, key=area.get)
    win = {}
    for (i, j), t in grid.tex.items():
        if t in NATURAL_TEX and t == grid.ground:
            continue
        k = (i * CELL // PATCH, j * CELL // PATCH)
        d = win.setdefault(k, {})
        d[t] = d.get(t, 0) + 1
    full = [w for w in win.values() if sum(w.values()) >= (PATCH // CELL) ** 2 // 2]
    flat = sum(1 for w in full if max(w.values()) >= PATCH_ONE * sum(w.values()))
    patchy = flat / float(len(full)) if full else 0.0
    glob = _clamp(1.0 - max(0.0, share - 0.6) / 0.3) * _clamp(ent / 0.9)
    local = _clamp(1.0 - max(0.0, patchy - 0.2) / 0.5)
    return share, glob * local, "%s covers %d%% (%d textures); %d%% of the %d m squares one " \
        "texture" % (name, round(share * 100), len(area), round(patchy * 100), PATCH // 100)
def landmark_root(p):
    t = str(p.get("tag", "")).split(" ")[0]
    if t.startswith("landmark.echo"):
        return None
    if t.startswith(("landmark", "spire")):
        return ".".join(t.split(".")[:2])
    parts = t.split(".")
    if "landmark" in parts:
        return ".".join(parts[:parts.index("landmark") + 1])
    return None
def hero(arena):
    best = None
    pieces = arena.get("pieces") or []
    for p in pieces:
        root = landmark_root(p)
        if root is None:
            continue
        top = p["y"] + p["h"]
        if best is None or top > best[2]:
            best = (p["x"], p["z"], top, root)
    if best is None:
        return None
    m = _m()
    rect, base = None, best[2]
    for p in pieces:
        if landmark_root(p) != best[3] or math.hypot(p["x"] - best[0], p["z"] - best[1]) > 2000:
            continue
        try:
            x0, x1, z0, z1, _ = m.footprint(p)
        except Exception:
            x0 = x1 = p["x"]
            z0 = z1 = p["z"]
        rect = (x0, x1, z0, z1) if rect is None else (min(rect[0], x0), max(rect[1], x1),
                                                      min(rect[2], z0), max(rect[3], z1))
        base = min(base, p["y"])
    return best + (rect, base)
def arrival(arena):
    w = arena.get("world")
    if isinstance(w, dict) and "x" in w:
        return w
    sp = arena.get("spawns") or []
    return sp[0] if sp else None
def sees(grid, a, b, step=100.0, skip=None):
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    n = max(1, int(math.hypot(dx, dz) / step))
    for k in range(1, n):
        t = k / float(n)
        x, y, z = a[0] + dx * t, a[1] + dy * t, a[2] + dz * t
        if skip is not None and skip[0] - 60 <= x <= skip[1] + 60 \
                and skip[2] - 60 <= z <= skip[3] + 60:
            continue
        h = grid.at(x, z)
        if h is not None and h > y:
            return False
    return True
def hero_view(grid, arena, h=None, at=None):
    h = h or hero(arena)
    at = at or arrival(arena)
    if h is None or at is None:
        return None, "no hero landmark" if h is None else "no spawn"
    eye = (at["x"], at["y"] + EYE, at["z"])
    rect = h[4] if len(h) > 4 and h[4] else (h[0], h[0], h[1], h[1])
    base = h[5] if len(h) > 5 else 0
    near = (min(max(eye[0], rect[0]), rect[1]), min(max(eye[2], rect[2]), rect[3]))
    for frac in (0.9, 0.75, 0.6, 0.5):
        y = base + (h[2] - base) * frac
        for px, pz in (near, (h[0], h[1])):
            if sees(grid, eye, (px, y, pz), skip=rect):
                return True, "%s seen from the spawn" % h[3]
    return False, "%s hidden from the spawn" % h[3]
def composition(grid, arena):
    notes = []
    parts = []
    seen, why = hero_view(grid, arena)
    if seen is not None:
        parts.append(1.0 if seen else 0.0)
        notes.append(why)
    tops = list(grid.top.values())
    if tops:
        lo, hi = min(tops), max(tops)
        relief = hi - lo
        parts.append(_clamp(relief / 1600.0))
        notes.append("relief %d" % relief)
    if grid.top:
        xs = [c[0] for c in grid.top]
        zs = [c[1] for c in grid.top]
        mx, mz = (min(xs) + max(xs)) / 2.0, (min(zs) + max(zs)) / 2.0
        floor = sorted(tops)[len(tops) // 2]
        quads = set()
        for (i, j), t in grid.top.items():
            if t >= floor + 600:
                quads.add((i >= mx, j >= mz))
        parts.append(len(quads) / 4.0)
        notes.append("focal points in %d of 4 quarters" % len(quads))
    score = sum(parts) / len(parts) if parts else 0.5
    return score, score, "; ".join(notes)
VISTA_LONG = 2400
VISTA_FRAME = 0.5
VISTA_FAN = 60
WEENIE_RISE = 600
STAND_IN = 500
STAND_IN_SIDE = 1500
NOT_A_HERO = {"road", "ramp", "stair", "stairs", "path", "floor", "ground", "wall", "bridge",
              "lane", "lanes", "fill", "cover", "invisible"}
COVER_STEP = 600
def _hero_any(arena, grid):
    h = hero(arena)
    if h is not None:
        return h, True
    tops = sorted(grid.top.values())
    if not tops:
        return None, False
    med = tops[len(tops) // 2]
    best = None
    m = _m()
    for p in arena.get("pieces") or []:
        if not _solid(p) or _terrain(p) or str(p.get("tag", "")).startswith("dress.backdrop"):
            continue
        words = set(str(p.get("tag", "")).split(" ")[0].replace("_", ".").split("."))
        if words & NOT_A_HERO:
            continue
        top = p["y"] + p["h"]
        side = max(float(p.get("w", 0)), float(p.get("d", 0)))
        if top < med + STAND_IN or side > STAND_IN_SIDE or p["h"] < 0.8 * side \
                or (best is not None and top <= best["y"] + best["h"]):
            continue
        best = p
    if best is None:
        return None, False
    try:
        x0, x1, z0, z1, _ = m.footprint(best)
    except Exception:
        x0 = x1 = best["x"]
        z0 = z1 = best["z"]
    tag = str(best.get("tag") or best.get("kind")).split(" ")[0]
    return (best["x"], best["z"], best["y"] + best["h"], tag, (x0, x1, z0, z1), best["y"]), False
def _spawn_sample(arena, n=16):
    sp = [s for s in arena.get("spawns") or [] if "x" in s]
    if len(sp) <= n:
        return sp
    step = len(sp) / float(n)
    return [sp[int(k * step)] for k in range(n)]
def stepped(s, d=COVER_STEP):
    r = math.radians(float(s.get("yaw", 0) or 0))
    return dict(s, x=s["x"] + math.sin(r) * d, z=s["z"] + math.cos(r) * d)
def hero_seen(grid, arena, family=None, h=None):
    if h is None:
        h, tagged = _hero_any(arena, grid)
    else:
        tagged = True
    sp = _spawn_sample(arena)
    if h is None:
        return None, 0.3, "no landmark: nothing in view to steer by", None
    if not sp:
        return None, 0.5, "no spawns", h
    fight = family in FIGHT
    seen = sum(1 for s in sp if hero_view(grid, arena, h, s)[0]
               or (fight and hero_view(grid, arena, h, stepped(s))[0]))
    share = seen / float(len(sp))
    name = h[3] if tagged else "%s (the tallest thing - no landmark)" % h[3]
    return share, _clamp(share / 0.75), "%s seen from %d of %d spawns%s" % (
        name, seen, len(sp), " (a step out)" if fight else ""), h
def _ray(grid, x, z, y, dx, dz, limit, past=0.0):
    d = 100.0
    while d < limit:
        h = grid.at(x + dx * d, z + dz * d)
        if h is None:
            return d, False
        if h > y and d >= past:
            return d, True
        d += 100.0
    return limit, False
def vista(grid, arena, family=None):
    if not grid.top:
        return None, 0.5, "nothing drawn"
    xs = [c[0] for c in grid.top]
    zs = [c[1] for c in grid.top]
    span = max(max(xs) - min(xs), max(zs) - min(zs)) * CELL
    long_ = min(VISTA_LONG, span / 3.0) if span else VISTA_LONG
    limit = min(span, 12000)
    sp = arena.get("spawns") or []
    starts = []
    w = arena.get("world")
    if isinstance(w, dict) and "x" in w:
        starts.append(w)
    from .metrics import structure
    for g in structure.spawn_groups(sp)[:4] if sp else []:
        starts.append(sp[g[0]])
    if not starts:
        return None, 0.5, "no spawns"
    scores = []
    framed_n = 0
    for s in starts[:4]:
        y = s.get("y", 0) + EYE
        yaw = float(s.get("yaw", 0) or 0)
        fan = {}
        far = {}
        past = COVER_STEP if family in FIGHT else 0.0
        for a in range(-VISTA_FAN, VISTA_FAN + 1, 5):
            r = math.radians(yaw + a)
            fan[a] = _ray(grid, s["x"], s["z"], y, math.sin(r), math.cos(r), limit)
            far[a] = _ray(grid, s["x"], s["z"], y, math.sin(r), math.cos(r), limit, past) \
                if past else fan[a]
        best = 0.3
        for a, (d, _) in far.items():
            if d < long_:
                continue
            best = max(best, 0.6)
            left = any(fan[b][1] and fan[b][0] <= VISTA_FRAME * d
                       for b in range(a - 40, a - 5, 5) if b in fan)
            right = any(fan[b][1] and fan[b][0] <= VISTA_FRAME * d
                        for b in range(a + 10, a + 45, 5) if b in fan)
            if left and right:
                best = 1.0
                break
        framed_n += best == 1.0
        scores.append(best)
    score = sum(scores) / len(scores)
    return round(score, 3), score, "a framed long view from %d of %d arrivals" % (
        framed_n, len(scores))
def _areas(grid):
    xs = [c[0] for c in grid.top]
    zs = [c[1] for c in grid.top]
    i0, i1, j0, j1 = min(xs), max(xs) + 1, min(zs), max(zs) + 1
    n = 3 if max(i1 - i0, j1 - j0) * CELL > 12000 else 2
    return n, i0, i1, j0, j1
def weenies(grid, arena):
    if not grid.top:
        return None, 0.5, "nothing drawn"
    n, i0, i1, j0, j1 = _areas(grid)
    tops = sorted(grid.top.values())
    floor = tops[len(tops) // 2]
    cells = {}
    tall = set()
    for (i, j), t in grid.top.items():
        k = (min(n - 1, (i - i0) * n // max(1, i1 - i0)), min(n - 1, (j - j0) * n // max(1, j1 - j0)))
        cells[k] = cells.get(k, 0) + 1
        if t >= floor + WEENIE_RISE:
            tall.add(k)
    areas = [k for k, c in cells.items() if c >= 0.1 * len(grid.top) / (n * n)]
    if not areas:
        return None, 0.5, "no ground"
    have = sum(1 for k in areas if k in tall)
    share = have / float(len(areas))
    return round(share, 3), share, "something tall to walk toward in %d of %d parts" % (
        have, len(areas))
PLATE_FAMILIES = ("party", "knockoff", "race")
AROUND_SECTORS = 8
AROUND_WANT = 4
AROUND_MASS = 800
AROUND_RISE = 400
AROUND_SHARE = 0.6
def surroundings(arena):
    from . import place
    pieces = arena.get("pieces") or []
    core = [p for p in pieces if "landmark" not in str(p.get("tag", "")).split(" ")[0]]
    try:
        x0, x1, z0, z1 = place.bounds(dict(arena, pieces=core or pieces))
    except (ValueError, KeyError):
        return None, 0.5, "nothing drawn"
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    play = [p for p in core if not str(p.get("tag", "")).startswith("dress.backdrop")
            and _solid(p)]
    tops = sorted(p["y"] + p["h"] for p in play) or [0]
    floor = tops[len(tops) // 2]
    sectors = set()
    rises = 0
    for p in pieces:
        if not _solid(p):
            continue
        tag = str(p.get("tag", ""))
        outside = p["x"] < x0 - 200 or p["x"] > x1 + 200 or p["z"] < z0 - 200 or p["z"] > z1 + 200
        if not (tag.startswith("dress.backdrop") or (outside and (
                tag.startswith("landmark") or "landmark" in tag.split(" ")[0]))):
            continue
        if max(float(p["w"]), float(p["d"]), float(p["h"])) < AROUND_MASS:
            continue
        a = math.atan2(p["x"] - cx, p["z"] - cz) % (2 * math.pi)
        sectors.add(int(a / (2 * math.pi) * AROUND_SECTORS) % AROUND_SECTORS)
        if p["y"] + p["h"] >= floor + AROUND_RISE:
            rises += 1
    n = len(sectors)
    score = AROUND_SHARE * min(1.0, n / float(AROUND_WANT)) + (1.0 - AROUND_SHARE) * (
        1.0 if rises else 0.0)
    if not n:
        note = "nothing around the map to look at - an empty sky all round"
    else:
        note = "something to look at in %d of %d directions round the map; %s" % (
            n, AROUND_SECTORS, "%d rise%s over the horizon" % (rises, "" if rises == 1 else "s")
            if rises else "nothing rises over the horizon (a landmark beyond the edge would)")
    return n, score, note
def first_look(grid, arena, family):
    rows = {}
    v, s, n, _ = hero_seen(grid, arena, family)
    rows["hero_seen"] = {"value": None if v is None else round(v, 3), "score": round(s, 3),
                         "note": n}
    v, s, n = vista(grid, arena, family)
    rows["vista"] = {"value": v, "score": round(s, 3), "note": n}
    v, s, n = weenies(grid, arena)
    rows["weenies"] = {"value": v, "score": round(s, 3), "note": n}
    return rows
START_KEYS = ("start", "courseStart", "lineStart", "floodStart")
GOAL_KEYS = ("goal", "courseGoal", "lineFinish", "floodGoal")
def _need_met(arena, need, n, measured):
    sv = arena.get("survey") or {}
    def count(key):
        v = sv.get(key)
        return len(v) if isinstance(v, list) else (1 if v else 0)
    if need == "spawns":
        have = len(arena.get("spawns") or [])
        return have >= n, "%d spawns (needs %d)" % (have, n)
    if need == "flags":
        have = count("ctfRed") + count("ctfBlue")
        return have >= n, "%d flags (needs %d)" % (have, n)
    if need in ("points", "field_spots"):
        have = count("points")
        return have >= n, "%d points (needs %d)" % (have, n)
    if need in ("hill", "ring"):
        return count(need) >= n, "%s %s" % ("a" if count(need) else "no", need)
    if need in ("start", "goal"):
        keys = START_KEYS if need == "start" else GOAL_KEYS
        ok = any(sv.get(k) for k in keys) or bool(arena.get("markers"))
        return ok, "%s %s" % ("a" if ok else "no", need)
    if need == "bonus_stars":
        have = len(arena.get("stars") or [])
        return have >= n, "%d bonus stars (needs %d)" % (have, n)
    m = (measured or {}).get("metrics") or {}
    if need == "rests" and m.get("rests") is not None:
        return m["rests"] >= n, "%d rests (needs %d)" % (m["rests"], n)
    if need == "hiding_cells" and m.get("hiding_share") is not None:
        cells = m.get("cells") or 0
        have = int(m["hiding_share"] * cells)
        return have >= n, "about %d hiding cells (needs %d)" % (have, n)
    return None, ""
def map_modes(arena, family, modes=None):
    from . import modes as modesmod
    return list(modes or ()) or list(arena.get("onlyFor") or ()) \
        or list(modesmod.FAMILY.get(family, ()))
def mode_fit(arena, family, modes=None, measured=None):
    from . import modeknow, brief as briefmod
    keys = map_modes(arena, family, modes)
    if not keys:
        return None, 1.0, "no mode to fit", []
    cats = {}
    for o in arena.get("objects") or []:
        c = briefmod.forge_category(o.get("key"))
        if c:
            cats.setdefault(c, o.get("key"))
    met = 0
    misses = []
    for k in keys:
        try:
            kn = modeknow.knowledge(k)
        except Exception:
            met += 1
            continue
        bad = []
        for need, n in sorted((kn.get("needs") or {}).items()):
            ok, why = _need_met(arena, need, n, measured)
            if ok is False:
                bad.append(why)
        for cat, why in sorted((kn.get("bans") or {}).items()):
            if cat in cats:
                bad.append("a %s (%s) it bans" % (cats[cat], cat))
        if bad:
            misses.append("%s: %s" % (k, ", ".join(bad)))
        else:
            met += 1
    share = met / float(len(keys))
    note = "carries what %d of %d modes need" % (met, len(keys))
    if misses:
        note += " - " + "; ".join(misses[:3])
    return round(share, 3), share, note, misses
FIGHT = ("shooter", "objective")
SIGHT_BAND = {"objective": (9000, 3000), "hide": (6000, 3000)}
CONTACT_BAND = {"objective": (3.0, 9.0)}
LANES_WANT = {"shooter": (2, 3), "objective": (3, 3)}
FAIR_OK = 0.08
FAIR_BAD = 0.25
FIND_S = 6.0
PAID_GROUND = 12
PAID_SAMPLE = 80
PAID_PERCHES = 8
def _band_score(b, value):
    c = b.closeness(value)
    return 0.5 if c is None else c
def play_rows(arena, family, measured, size=None):
    from .metrics import targets, syntax, mario
    m = measured.get("metrics") or {}
    ex = measured.get("extra") or {}
    w = measured.get("world")
    rows = {}
    bands = {}
    try:
        bands = targets.bands(family, size)
    except KeyError:
        pass
    groups = ex.get("groups") or []
    if family in FIGHT and ex.get("spawn_exposure"):
        e = ex["spawn_exposure"]
        spread = max(e) - min(e)
        side = 0.0
        if len(groups) >= 2:
            means = [sum(e[i] for i in g) / len(g) for g in groups if g]
            side = max(means) - min(means)
        v = max(side, spread / 2.0)
        rows["spawn_fairness"] = {
            "value": round(v, 3), "score": round(_clamp(1 - (v - FAIR_OK) / (FAIR_BAD - FAIR_OK)), 3),
            "note": "spawns seen by %d-%d %% of the map (sides %d %% apart)" % (
                round(min(e) * 100), round(max(e) * 100), round(side * 100))}
    sl = m.get("sightline_max")
    if sl is not None and (family == "shooter" or family in SIGHT_BAND):
        b = bands.get("sightline_max")
        if b is None:
            hi, soft = SIGHT_BAND[family]
            b = targets.Band(None, hi * targets.size_factor(family, size), soft=soft)
        rows["sightline"] = {"value": sl, "score": round(_band_score(b, sl), 3),
                             "note": "the longest open line %d m (at most %d m)" % (
                                 round(sl / 100), round(b.hi / 100))}
    lanes, chokes = m.get("lanes_between_bases"), m.get("chokes")
    if family in FIGHT and lanes:
        per = (chokes or 0) / float(lanes)
        rows["chokes"] = {"value": round(per, 2), "score": round(_clamp(1.5 - per), 3),
                          "note": "%d chokes on %d lanes" % (chokes or 0, lanes)}
        lo, hi = LANES_WANT[family]
        s = 1.0 if lo <= lanes <= hi else _clamp(1.0 - min(abs(lanes - lo), abs(lanes - hi)) / 2.0)
        rows["lanes"] = {"value": lanes, "score": round(s, 3),
                         "note": "%d lanes between the bases (wants %s)" % (
                             lanes, lo if lo == hi else "%d-%d" % (lo, hi))}
    tc = m.get("time_to_contact_s")
    if tc is not None and family in FIGHT:
        b = bands.get("time_to_contact_s")
        if b is None:
            lo, hi = CONTACT_BAND[family]
            k = targets.size_factor(family, size)
            b = targets.Band(lo * k, hi * k)
        rows["contact"] = {"value": tc, "score": round(_band_score(b, tc), 3),
                           "note": "first sight of the other side after %.1f s (wants %s s)" % (
                               tc, b.text() if hasattr(b, "text") else "")}
    if w is not None and family in FIGHT + ("hide",):
        spawns = arena.get("spawns") or []
        sn = [w.node_of(s) for s in spawns]
        g = groups if 2 <= len(groups) <= 4 else []
        try:
            rows.update(syntax.flow(w, g, sn, ex.get("centre")))
        except Exception:
            pass
        if family in FIGHT:
            r = objective_found(arena, family, w, sn, mario)
            if r:
                rows["objective_found"] = r
        r = height_paid(w, m, ex, sn)
        if r:
            rows["height_paid"] = r
    return rows
def _objective_spots(arena, family):
    sv = arena.get("survey") or {}
    out = []
    keys = ("ctfRed", "ctfBlue", "hill", "points") if family == "objective" else ()
    for k in keys:
        v = sv.get(k)
        for s in (v if isinstance(v, list) else [v]):
            if isinstance(s, dict) and "x" in s:
                out.append(s)
    return out
def objective_found(arena, family, w, sn, mario):
    from .metrics import graph
    spots = _objective_spots(arena, family)
    if family == "shooter" or not spots:
        c = w.node_xyz(w.centre_node())
        spots = [{"x": c[0], "y": c[1], "z": c[2]}]
    spawns = _spawn_sample(arena)
    if not spawns:
        return None
    nodes = [w.node_of(s) for s in spots]
    dist = graph.bfs(w.adj, nodes)
    ok = 0
    for s in spawns:
        eye = (s["x"], s.get("y", 0) + mario.EYE, s["z"])
        seen = any(not w.blocked(eye, (o["x"], o.get("y", 0) + 300, o["z"])) for o in spots)
        d = dist[w.node_of(s)]
        near = d >= 0 and mario.path_time_s(d) <= FIND_S
        ok += seen or near
    share = ok / float(len(spawns))
    what = "the middle" if family == "shooter" else "an objective"
    return {"value": round(share, 3), "score": round(_clamp(share / 0.8), 3),
            "note": "%s in sight or a short run from %d of %d spawns" % (what, ok, len(spawns))}
def height_paid(w, m, ex, sn):
    from .metrics import structure, vis
    main = m.get("main_plane")
    if main is None:
        return None
    room_of, room_list = structure.rooms(w)
    high = [r for r in room_list if w.nodes[r[0]][2] >= main + 300 and structure.has_block(w, r)]
    if not high:
        return None
    sample = ex.get("sample") or []
    if not sample:
        return None
    home = set()
    for g in ex.get("groups") or []:
        if 2 <= len(ex.get("groups") or []) <= 4:
            home |= structure.base_zone(w, [sn[i] for i in g], radius=8)
    ground = []
    for (gx, gz), i in list(w.columns.items())[::max(1, len(w.columns) // PAID_GROUND)]:
        if abs(w.nodes[i][2] - main) <= 50:
            x, y, z = w.node_xyz(i)
            ground.append(vis.exposure(w, {"x": x, "y": y, "z": z}, sample[:PAID_SAMPLE]))
    floor = sorted(ground)[len(ground) // 2] if ground else 0.0
    paid = 0
    for r in high[:PAID_PERCHES]:
        mid = r[len(r) // 2]
        x, y, z = w.node_xyz(mid)
        exp = vis.exposure(w, {"x": x, "y": y, "z": z}, sample[:PAID_SAMPLE])
        if not (set(r) & home) and exp >= 0.8 * floor:
            paid += 1
    n = min(len(high), PAID_PERCHES)
    share = paid / float(n)
    return {"value": round(share, 3), "score": round(_clamp(share / 0.75), 3),
            "note": "%d of %d perches cost something (away from the spawns, in plain sight)"
                    % (paid, n)}
LOOK_CHECKS = {"contrast": "A1", "value_bands": "A2", "silhouette": "A3"}
STATUS_SCORE = {"pass": 1.0, "warn": 0.6, "fail": 0.2}
def looks_rows(audit, arena=None):
    rows = {}
    art = audit.get("artdir")
    if art is None and audit.get("frames"):
        try:
            from .metrics import artdir
            art = artdir.render(audit, arena)
        except Exception:
            art = None
    for k, r in (art or {}).items():
        rows[k] = dict(r)
    checks = audit.get("checks") or {}
    for name, k in LOOK_CHECKS.items():
        r = checks.get(k)
        if not r:
            continue
        rows[name] = {"value": r.get("value") if not isinstance(r.get("value"), float)
                      else round(r["value"], 3),
                      "score": STATUS_SCORE.get(r.get("status"), 0.5), "note": r.get("why", "")}
    shares = sorted((audit.get("shares") or {}).values(), reverse=True)
    if shares:
        dom = shares[0]
        sec = shares[1] if len(shares) > 1 else 0.0
        rest = max(0.0, 1.0 - dom - sec)
        off = abs(dom - 0.6) + abs(sec - 0.3) + abs(rest - 0.1)
        rows["palette"] = {"value": [round(dom, 2), round(sec, 2), round(rest, 2)],
                           "score": round(_clamp(1.0 - max(0.0, off - 0.1) / 0.6), 3),
                           "note": "colours %d / %d / %d %% on screen (the rule: 60 / 30 / 10)"
                                   % (round(dom * 100), round(sec * 100), round(rest * 100))}
    return rows
def judge(arena, family=None, measured=None, looks=None, modes=None, size=None, carry=None):
    family = family or arena.get("family") or "default"
    grid = HeightGrid(arena)
    rows = {}
    v, s, n = emptiness(grid, arena)
    rows["emptiness"] = {"value": round(v, 3), "score": round(s, 3), "note": n}
    v, s, n = mud(arena)
    rows["mud"] = {"value": v, "score": round(s, 3), "note": n}
    ov = overlaps(arena)
    rows["overlaps"] = {"value": len(ov), "score": round(_clamp(1.0 - len(ov) / 6.0), 3),
                        "note": "; ".join("%s / %s %s" % (a.get("tag") or a.get("kind"),
                                                          b.get("tag") or b.get("kind"), w)
                                          for a, b, w in ov[:4]) or "none",
                        "where": [(round(a["x"]), round(a["z"])) for a, _, _ in ov[:20]]}
    fl = floating(arena)
    rows["floating"] = {"value": len(fl), "score": round(_clamp(1.0 - len(fl) / 3.0), 3),
                        "note": "; ".join("%s %s" % (o.get("key"), w) for o, w in fl[:4])
                        or "none", "where": [(o["x"], o["z"]) for o, _ in fl[:20]]}
    v, s, n = monotony(grid, arena)
    rows["monotony"] = {"value": round(v, 3), "score": round(s, 3), "note": n}
    v, s, n = composition(grid, arena)
    rows["composition"] = {"value": round(v, 3), "score": round(s, 3), "note": n}
    rows.update(first_look(grid, arena, family))
    edge = world_edge(arena)
    if edge is not None:
        rows["world_edge"] = edge
    if family in PLATE_FAMILIES:
        v, sc, n = surroundings(arena)
        rows["surroundings"] = {"value": v, "score": round(sc, 3), "note": n}
    try:
        from .metrics import artdir
        rows.update(artdir.cheap(arena, grid, family))
    except Exception:
        pass
    try:
        from . import autolight
        rows.update(autolight.critic_rows(arena))
    except Exception:
        pass
    v, sc, n, misses = mode_fit(arena, family, modes, measured)
    if v is not None:
        rows["mode_fit"] = {"value": v, "score": round(sc, 3), "note": n, "misses": misses}
    if measured:
        try:
            rows.update(play_rows(arena, family, measured, size))
        except Exception as why:
            rows["play"] = {"value": None, "score": 0.5,
                            "note": "not measured (%s)" % why.__class__.__name__}
    if looks:
        rows.update(looks_rows(looks, arena))
    carried = False
    for k, r in ((carry or {}).get("rows") or {}).items():
        if k not in rows and k in CARRY_ROWS:
            rows[k] = r
            carried = True
    warnings = []
    try:
        from .metrics import artdir
        x1 = artdir.liminal(arena, rows, (looks or {}).get("checks"))
        if x1 is not None:
            rows["liminal"] = x1
            if x1["value"] >= 3:
                warnings.append(LIMINAL_WARNING)
    except Exception:
        pass
    pl = arena.get("playable")
    weights = dict((k, w) for k, w in WEIGHTS.items() if k in rows)
    weights.update((k, w) for k, w in FAMILY_WEIGHTS.get(family, {}).items() if k in rows)
    if isinstance(pl, dict):
        n = int(pl.get("unreached") or 0)
        rho = pl.get("curve")
        sc = _clamp(1.0 - n / 4.0) * (1.0 if rho is None or rho >= 0 else 0.8)
        rows["reach"] = {"value": n, "score": round(sc, 3),
                         "note": "%d pickups out of reach; difficulty curve %s" % (
                             n, "-" if rho is None else "%+.2f" % rho)}
        weights["reach"] = 1.0
    for k in rows:
        weights.setdefault(k, 0.5)
    total = sum(weights.values())
    mean = sum(weights[k] * rows[k]["score"] for k in weights) / total
    low = min([rows[k]["score"] for k in weights if weights[k] >= 0.5 and k in LOW_ROWS]
              or [mean])
    score = 100.0 * ((1.0 - WORST_SHARE) * mean + WORST_SHARE * low)
    line = PASS.get(family, PASS["default"])
    groups = {}
    for g in ("build", "play", "looks"):
        ks = [k for k in rows if GROUP.get(k, "build") == g and weights.get(k)]
        if ks:
            groups[g] = round(sum(weights[k] * rows[k]["score"] for k in ks)
                              / sum(weights[k] for k in ks), 4)
    return {"score": round(score, 1), "pass": score >= line, "line": line, "rows": rows,
            "worst": min(rows, key=lambda k: rows[k]["score"] / max(weights.get(k, 0), 0.1)),
            "groups": groups, "weights": weights,
            "tier": "full" if measured or (carried and carry.get("tier") == "full") else "cheap",
            "looks": bool(looks) or bool(carried and carry.get("looks")), "warnings": warnings}
def world_edge(arena):
    from . import worldedge
    items = worldedge.far(arena)
    if not items:
        return None
    return {"value": len(items), "score": 0.0,
            "note": "%d thing%s too far out - %s" % (len(items), "" if len(items) == 1 else "s",
                                                    worldedge.describe(items[0])),
            "where": [(round(i.x), round(i.z)) for i in items[:20]]}
LIMINAL_WARNING = ("This map feels empty and samey, with nothing to remember it by: no "
                   "landmark to steer by, the same texture everywhere, flat light. Add a "
                   "landmark, mix textures, and use light and dark.")
FIXES = {"emptiness": "Add cover, a rise or something to pick up in the bare stretches",
         "mud": "Spread the props out - fewer in the busiest corner",
         "overlaps": "Pull apart the pieces that sit inside each other",
         "floating": "Set the floating objects down on the floor",
         "monotony": "Use a second floor or wall texture in the plain areas",
         "composition": "Give each part of the map something tall to look at",
         "reach": "Move the pickups nobody can reach",
         "hero_seen": "Raise the landmark or clear what hides it from the spawns",
         "vista": "Frame a long view from the spawn between two buildings or trees",
         "weenies": "Put something tall (a tower, a column) in the empty parts",
         "mode_fit": "Add what the modes need (flags, points, a hill) or take out what they ban",
         "spawn_fairness": "Give the more exposed spawns cover, or move them back",
         "sightline": "Break the longest open line with a wall or a building",
         "chokes": "Widen the narrow passages between the bases",
         "lanes": "Open or close a route so the bases have the lanes the mode wants",
         "contact": "Move the bases nearer or farther so the sides meet in time",
         "integration": "Make the middle a crossroads the routes pass through",
         "connectivity": "Open more ways into the middle and out of each base",
         "objective_found": "Put the objective in sight of the spawns, or nearer them",
         "height_paid": "Make high ground cost something: farther from the spawns, in plain sight",
         "contrast": "Pick a wall texture that stands apart from the floor",
         "value_bands": "Mix light, middle and dark surfaces",
         "silhouette": "Calmer, lighter walls where players fight",
         "palette": "One main colour, one second, a small accent (60-30-10)",
         "world_edge": "Move it inside: nothing can be further than 32,000 from the middle",
         "surroundings": "Put big rocks or islands all round the map and a landmark far "
                         "beyond the edge"}
from .metrics.artdir import FIXES as _ART_FIXES
FIXES.update(_ART_FIXES)
REPAIRS = ("hero_seen", "weenies", "floating", "overlaps",
           "grounding", "mud", "monotony", "texture_count", "composition", "liminal",
           "world_edge")
def fix(arena, row):
    if row == "hero_seen":
        return add_landmark(arena) or raise_hero(arena, arena.get("family"))
    if row == "weenies":
        return grow_weenies(arena)
    if row == "overlaps":
        return close_pinches(arena)
    if row == "floating":
        return repair(arena)
    if row == "grounding":
        return prop_up(arena)
    if row == "mud":
        return thin_props(arena)
    if row == "monotony":
        return vary_texture(arena)
    if row == "texture_count":
        return fewer_textures(arena)
    if row == "composition":
        return raise_hero(arena, arena.get("family")) + grow_weenies(arena)
    if row == "world_edge":
        from . import worldedge
        return worldedge.move_inside(arena)
    if row == "liminal":
        return (add_landmark(arena) + raise_hero(arena, arena.get("family"))
                + grow_weenies(arena) + vary_texture(arena))
    return []
POST = 200
POST_INSET = 100
def _boxes_clash(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3] and \
        a[4] < b[5] and b[4] < a[5]
def _aabb(p):
    m = _m()
    try:
        x0, x1, z0, z1, _ = m.footprint(p)
    except Exception:
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
    return (x0, x1, z0, z1, p["y"], p["y"] + p["h"])
def _keel_tex(arena):
    from . import kit
    from .metrics import artdir
    pal = kit.THEMES.get(artdir.theme_of(arena) or "castle") or kit.THEMES["castle"]
    tex = pal.get("keel") or pal.get("wall") or "stone2"
    return tex if tex in kit.textures() else "stone2"
def prop_up(arena):
    from . import kit
    from .metrics import artdir
    cols = artdir.Columns(arena)
    fl = artdir.floaters(arena, arena.get("family"), cols)
    if not fl:
        return []
    tex = _keel_tex(arena)
    solids = [_aabb(p) for p in arena.get("pieces") or [] if _solid(p)]
    added = []
    for p, _gap in fl:
        x0, x1, z0, z1, y0, _ = _aabb(p)
        k = cols.pieces.index(p)
        posts = []
        for cx, cz in ((x0 + POST_INSET, z0 + POST_INSET), (x1 - POST_INSET, z0 + POST_INSET),
                       (x0 + POST_INSET, z1 - POST_INSET), (x1 - POST_INSET, z1 - POST_INSET)):
            px0, px1 = cx, cx + POST if cx < (x0 + x1) / 2 else cx
            if cx >= (x0 + x1) / 2:
                px0, px1 = cx - POST, cx
            pz0, pz1 = (cz, cz + POST) if cz < (z0 + z1) / 2 else (cz - POST, cz)
            mx, mz = (px0 + px1) / 2.0, (pz0 + pz1) / 2.0
            base = cols.below(mx, mz, y0, k)
            if base is None or y0 - base < 50:
                continue
            box = (px0 + 1, px1 - 1, pz0 + 1, pz1 - 1, base + 1, y0 - 1)
            if any(_boxes_clash(box, b) for b in solids):
                continue
            posts.append(kit.kind("box").make(tex, int(px0), int(px1), int(round(base)),
                                              int(round(y0)), int(pz0), int(pz1), None,
                                              "keel.post u7"))
        if len(posts) < 2:
            continue
        for q in posts:
            solids.append(_aabb(q))
        arena["pieces"].extend(posts)
        added.append((p.get("tag") or p.get("kind"), len(posts)))
    if not added:
        return []
    return ["%d floating block%s put on posts (%s)" % (
        len(added), "" if len(added) == 1 else "s",
        ", ".join("%s: %d posts" % (str(t).split(" ")[0], n) for t, n in added[:4]))]
TOWER_SIDE = 600
TOWER_RISE = 1600
TOWER_CLEAR = 600
def _tower_tex(arena):
    from . import kit, values
    from .metrics import artdir
    have = kit.textures()
    st = values.stats()
    used = {}
    for p in arena.get("pieces") or []:
        if _solid(p):
            used[p["tex"]] = used.get(p["tex"], 0.0) + artdir.surface(p)
    base = max(used, key=used.get) if used else None
    lum = st.get(base, (0.5, 0))[0]
    pal = kit.THEMES.get(artdir.theme_of(arena) or "castle") or kit.THEMES["castle"]
    picks = list(pal.get("accents") or []) + ["whitemarble", "stone1", "bricklightgrey",
                                              "redbrick"]
    for t in picks:
        if t in have and t in st and abs(st[t][0] - lum) >= 0.15 and t not in ("lava",
                                                                               "glassblock"):
            return t
    return "whitemarble" if "whitemarble" in have else (base or "stone1")
def add_landmark(arena):
    from . import kit
    if hero(arena) is not None:
        return []
    grid = HeightGrid(arena)
    if not grid.top:
        return []
    xs = [c[0] for c in grid.top]
    zs = [c[1] for c in grid.top]
    cx = (min(xs) + max(xs) + 1) * CELL / 2.0
    cz = (min(zs) + max(zs) + 1) * CELL / 2.0
    solids = [_aabb(p) for p in arena.get("pieces") or [] if _solid(p)]
    keep = [(s["x"], s["z"]) for s in arena.get("spawns") or [] if "x" in s]
    keep += [(o["x"], o["z"]) for o in arena.get("objects") or [] if "x" in o]
    half = TOWER_SIDE / 2.0
    spots = sorted(set((i, j) for i, j in grid.top),
                   key=lambda c: (math.hypot((c[0] + 0.5) * CELL - cx, (c[1] + 0.5) * CELL - cz),
                                  c))
    for i, j in spots[:2000]:
        x, z = (i + 0.5) * CELL, (j + 0.5) * CELL
        if (i, j) in grid.water:
            continue
        tops = [grid.at(x + dx, z + dz) for dx in (-half + 1, half - 1)
                for dz in (-half + 1, half - 1)]
        if any(t is None for t in tops) or max(tops) - min(tops) > 10:
            continue
        if any(math.hypot(x - a, z - b) < TOWER_CLEAR for a, b in keep):
            continue
        y = max(tops)
        bx = (x - half, x + half, z - half, z + half, y + 1, y + TOWER_RISE)
        if any(_boxes_clash(bx, b) for b in solids):
            continue
        tex = _tower_tex(arena)
        arena["pieces"].append(kit.kind("box").make(
            tex, int(x - half), int(x + half), int(round(y)), int(round(y + TOWER_RISE)),
            int(z - half), int(z + half), None, "landmark.tower u7"))
        return ["a %s tower %d tall put near the middle, something to steer by" % (
            tex, TOWER_RISE)]
    return []
def thin_props(arena):
    pieces = arena.get("pieces") or []
    props = [p for p in pieces if _is_prop(p)]
    if not props:
        return []
    half = PROP_WINDOW // 2
    cell = {}
    for p in props:
        cell.setdefault((int(p["x"] // half), int(p["z"] // half)), []).append(p)
    best, where = [], None
    for (i, j) in cell:
        for a in (0, -1):
            for b in (0, -1):
                inside = [p for u in (0, 1) for v in (0, 1)
                          for p in cell.get((i + a + u, j + b + v), ())]
                if len(inside) > len(best):
                    best, where = inside, (i + a, j + b)
    objs = sum(1 for o in arena.get("objects") or []
               if where is not None and (int(o["x"] // half) - where[0]) in (0, 1)
               and (int(o["z"] // half) - where[1]) in (0, 1)
               and not str(o.get("key", "")).startswith(("coin", "redcoin", "bluecoin")))
    over = len(best) + objs - 8
    if over <= 0:
        return []
    drop = sorted(best, key=lambda p: float(p["w"]) * float(p["h"]) * float(p["d"]))[:over]
    ids = set(id(p) for p in drop)
    arena["pieces"] = [p for p in pieces if id(p) not in ids]
    return ["%d prop%s taken out of the busiest corner" % (len(drop), "" if len(drop) == 1
                                                             else "s")]
def _second(tex):
    from . import kit, values
    have = kit.textures()
    st = values.stats()
    if tex not in have or tex not in st:
        return None
    best = None
    for t in values.members(tex, have):
        if t == tex or t not in st or t in ("lava", "glassblock", "ice"):
            continue
        d = abs(st[t][0] - st[tex][0])
        if 0.05 <= d <= 0.25 and (best is None or d < best[0]):
            best = (d, t)
    return best[1] if best else None
def vary_texture(arena):
    grid = HeightGrid(arena)
    share, _, _ = monotony(grid, arena)
    area = {}
    for p in arena.get("pieces") or []:
        if _solid(p) and p.get("tex") not in NATURAL_TEX:
            area[p["tex"]] = area.get(p["tex"], 0.0) + float(p["w"]) * float(p["d"]) + \
                2.0 * (float(p["w"]) + float(p["d"])) * float(p["h"])
    if not area:
        return []
    tex = max(area, key=area.get)
    other = _second(tex)
    if other is None:
        return []
    tall = sorted([p for p in arena["pieces"] if p.get("tex") == tex and p["h"] >= 400
                   and not _is_prop(p)], key=lambda p: (p["x"], p["z"], p["y"]))
    if len(tall) < 2:
        return []
    n = 0
    for p in tall[1::2]:
        p["tex"] = other
        n += 1
    return ["%d of the %s walls repainted %s for variety" % (n, tex, other)]
def fewer_textures(arena, keep=None):
    from . import values
    from .metrics import artdir
    keep = keep or artdir.T3_MAX
    st = values.stats()
    area = {}
    for p in arena.get("pieces") or []:
        if _solid(p):
            area[p["tex"]] = area.get(p["tex"], 0.0) + artdir.surface(p)
    if len(area) <= keep:
        return []
    order = sorted(area, key=lambda t: area[t])
    gone = order[:len(area) - keep]
    stay = [t for t in order if t not in gone]
    swap = {}
    for t in gone:
        lum = st.get(t, (0.5, 0))[0]
        swap[t] = min(stay, key=lambda u: (abs(st.get(u, (0.5, 0))[0] - lum), -area[u]))
    for p in arena["pieces"]:
        if p.get("tex") in swap:
            p["tex"] = swap[p["tex"]]
    return ["%d rare texture%s repainted (%s)" % (
        len(swap), "" if len(swap) == 1 else "s",
        ", ".join("%s -> %s" % kv for kv in list(swap.items())[:3]))]
CARRY_ROWS = ("spawn_fairness", "sightline", "chokes", "lanes", "contact", "integration",
              "connectivity", "objective_found", "height_paid", "contrast", "value_bands",
              "silhouette", "palette", "play",
              "value_curve", "calm", "focal", "depth_colour", "tiling")
def rejudge(arena, family=None, modes=None):
    prev = arena.get("critic") or {}
    return judge(arena, family, modes=modes, carry=prev if prev.get("verdict") else None)
def summary(res):
    out = "critic %.0f/100 (%s, line %d; weakest: %s - %s)" % (
        res["score"], "pass" if res["pass"] else "below the line", res["line"], res["worst"],
        res["rows"][res["worst"]]["note"])
    if res.get("warnings"):
        out += "; warning: empty and samey (no landmark, one texture, flat light)"
    return out
def repair(arena):
    from . import guards, triblock
    notes = list(triblock.enforce(arena))
    notes += face_the_hero(arena)
    notes += close_pinches(arena)
    notes += first_look_repairs(arena)
    notes += first_view(arena)
    m = _m()
    for o in guards.floating_objects(arena):
        hs = [h for h in m.standable(arena.get("pieces") or [], o["x"], o["z"], arena["level"])
              if h <= o["y"] + 30]
        if hs:
            o["y"] = int(round(max(hs)))
            notes.append("%s set down onto the floor under it" % o.get("key"))
    return notes
HERO_STEP = 300
HERO_GROW_MAX = 1500
WEENIE_GROW_MAX = 1200
WEENIE_TAGS = ("landmark", "spire", "dress.column", "dress.pillar",
               "decor.watchpost", "fill.column", "pillar", "column", "obelisk", "tower")
SLENDER = 800
GROW_KINDS = ("box", "pillar", "prism", "cylinder", "pyramid")
def _growable(p, arena, pieces=None):
    if p.get("kind") not in GROW_KINDS or p.get("tex") in SKIP_TEX:
        return False
    m = _m()
    try:
        x0, x1, z0, z1, _ = m.footprint(p)
    except Exception:
        return False
    top = p["y"] + p["h"]
    for key in ("spawns", "objects", "stars"):
        for o in arena.get(key) or []:
            if isinstance(o, dict) and "x" in o and x0 - 100 <= o["x"] <= x1 + 100 \
                    and z0 - 100 <= o["z"] <= z1 + 100 and o.get("y", 0) >= top - 200:
                return False
    for q in pieces if pieces is not None else arena.get("pieces") or []:
        if q is p or not _solid(q):
            continue
        try:
            a0, a1, b0, b1, _ = m.footprint(q)
        except Exception:
            continue
        near = a0 <= x1 + 300 and a1 >= x0 - 300 and b0 <= z1 + 300 and b1 >= z0 - 300
        if not near:
            continue
        over = a0 < x1 and a1 > x0 and b0 < z1 and b1 > z0
        qt = q["y"] + q["h"]
        if over and q["y"] >= top - 1:
            return False
        if not over and top - 600 <= qt <= top + 50 and _root(q) != _root(p):
            return False
    return True
def _grow(p, dh):
    p["h"] += dh
    if p.get("model"):
        p["model"] = _m().model_name(p)
def raise_hero(arena, family=None, grid=None):
    h = hero(arena)
    if h is None:
        return []
    grid = grid or HeightGrid(arena)
    share = hero_seen(grid, arena, family, h)[0]
    if share is None or share >= 0.75:
        return []
    top = None
    for p in arena.get("pieces") or []:
        if landmark_root(p) == h[3] and abs(p["y"] + p["h"] - h[2]) < 1 \
                and math.hypot(p["x"] - h[0], p["z"] - h[1]) < 1:
            top = p
            break
    if top is None or not _growable(top, arena):
        return []
    grown = 0
    longest = _m().LONGEST_FACE
    while grown < HERO_GROW_MAX and top["h"] + HERO_STEP <= longest:
        _grow(top, HERO_STEP)
        grown += HERO_STEP
        h2 = hero(arena)
        s2 = hero_seen(grid, arena, family, h2)[0]
        if s2 is not None and s2 >= 0.75:
            break
    after = hero_seen(grid, arena, family, hero(arena))[0] or 0.0
    if after <= share:
        _grow(top, -grown)
        return []
    return ["the %s raised %d so %d %% of the spawns see it (was %d %%)" % (
        h[3], grown, round(after * 100), round(share * 100))]
def grow_weenies(arena, grid=None):
    grid = grid or HeightGrid(arena)
    if not grid.top:
        return []
    n, i0, i1, j0, j1 = _areas(grid)
    tops = sorted(grid.top.values())
    floor = tops[len(tops) // 2]
    want = floor + WEENIE_RISE + 100
    tall = set()
    cells = {}
    def area(i, j):
        return (min(n - 1, (i - i0) * n // max(1, i1 - i0)),
                min(n - 1, (j - j0) * n // max(1, j1 - j0)))
    for (i, j), t in grid.top.items():
        k = area(i, j)
        cells[k] = cells.get(k, 0) + 1
        if t >= floor + WEENIE_RISE:
            tall.add(k)
    lacking = set(k for k, c in cells.items() if c >= 0.1 * len(grid.top) / (n * n)
                  and k not in tall)
    if not lacking:
        return []
    pieces = arena.get("pieces") or []
    best = {}
    for p in pieces:
        t = str(p.get("tag", "")).split(" ")[0]
        if not t.startswith(WEENIE_TAGS) and not any(w in t.split(".") for w in WEENIE_TAGS):
            continue
        if max(float(p.get("w", 0)), float(p.get("d", 0))) > SLENDER:
            continue
        k = area(int(math.floor(p["x"] / CELL)), int(math.floor(p["z"] / CELL)))
        if k not in lacking:
            continue
        top = p["y"] + p["h"]
        if want - top > WEENIE_GROW_MAX or top >= want:
            continue
        if k not in best or top > best[k]["y"] + best[k]["h"]:
            if _growable(p, arena, pieces):
                best[k] = p
    out = []
    for k, p in sorted(best.items()):
        dh = int(math.ceil((want - (p["y"] + p["h"])) / 50.0)) * 50
        _grow(p, dh)
        out.append(p.get("tag") or p.get("kind"))
    if not out:
        return []
    return ["%d part%s of the map given something tall to walk toward (%s grown)" % (
        len(out), "" if len(out) == 1 else "s", ", ".join(str(t).split(" ")[0] for t in out[:4]))]
def first_look_repairs(arena, family=None):
    family = family or arena.get("family")
    grid = HeightGrid(arena)
    notes = raise_hero(arena, family, grid)
    notes += grow_weenies(arena, HeightGrid(arena) if notes else grid)
    return notes
def close_pinches(arena):
    from .guards import Index
    m = _m()
    pieces = [p for p in arena.get("pieces") or [] if _solid(p)]
    ix = Index(pieces)
    pos = {id(p): k for k, p in enumerate(pieces)}
    n = 0
    seen = set()
    for hi, lo, why in overlaps(arena):
        if not why.startswith("hangs") or hi.get("kind") != "box" or _is_prop(hi) \
                or id(hi) in seen or id(hi) not in pos:
            continue
        seen.add(id(hi))
        a = ix.rects[pos[id(hi)]]
        under = None
        for k in ix.near(a[0], a[1], a[2], a[3]):
            q = pieces[k]
            if q is hi:
                continue
            b = ix.rects[k]
            if min(a[1], b[1]) - max(a[0], b[0]) <= 0 or min(a[3], b[3]) - max(a[2], b[2]) <= 0:
                continue
            top = q["y"] + q["h"]
            if top <= hi["y"] + 1e-6 and (under is None or top > under):
                under = top
        if under is None:
            continue
        gap = hi["y"] - under
        if PINCH_MIN <= gap < PINCH:
            hi["y"] -= gap
            hi["h"] += gap
            if hi.get("model"):
                hi["model"] = m.model_name(hi)
            n += 1
    return ["%d hanging parts grown down onto what they hung over" % n] if n else []
HERO_FAMILIES = ("explore",)
def face_the_hero(arena, grid=None):
    if (arena.get("family") or "") not in HERO_FAMILIES:
        return []
    h = hero(arena)
    if h is None:
        return []
    grid = grid or HeightGrid(arena)
    out = []
    sp = arena.get("spawns") or []
    if sp and not hero_view(grid, arena, h, sp[0])[0] and not arena.get("world"):
        from .gameplay import FIRST_SPAWN_CLEAR
        stars = arena.get("stars") or []
        for k in range(1, len(sp)):
            s = sp[k]
            if any(math.hypot(st["x"] - s["x"], st["z"] - s["z"]) < FIRST_SPAWN_CLEAR
                   for st in stars):
                continue
            if hero_view(grid, arena, h, s)[0]:
                sp[0], sp[k] = sp[k], sp[0]
                out.append("spawn %d sees the %s: it is the arrival now" % (k + 1, h[3]))
                break
    turned = 0
    for s in arena.get("spawns") or []:
        seen, _ = hero_view(grid, arena, h, s)
        if not seen:
            continue
        yaw = int(round(math.degrees(math.atan2(h[0] - s["x"], h[1] - s["z"])))) % 360
        if yaw != s.get("yaw"):
            s["yaw"] = yaw
            turned += 1
    return out + (["%d spawns turned to face the %s" % (turned, h[3])] if turned else [])
def thumbnail(arena, path, size=320, theme=None):
    from PIL import Image
    from . import bake, kit
    grid = HeightGrid(arena)
    if not grid.top:
        Image.new("RGB", (size, size), (24, 24, 34)).save(path)
        return path
    cols = kit.colours()
    pal = bake.look_palette(arena.get("look") or {}, theme or (arena.get("look") or {}).get(
        "theme"))
    occ = bake.Grid(bake.rows_of(arena))
    xs = [c[0] for c in grid.top]
    zs = [c[1] for c in grid.top]
    i0, i1, j0, j1 = min(xs), max(xs), min(zs), max(zs)
    n = max(i1 - i0 + 1, j1 - j0 + 1)
    img = Image.new("RGB", (n, n), (24, 24, 34))
    px = img.load()
    for (i, j), t in grid.top.items():
        base = cols.get(grid.tex.get((i, j)), LEVEL_COLOUR)
        x, z = (i + 0.5) * CELL, (j + 0.5) * CELL
        sh = bake.colour(occ, pal, x, t, z, 0, 1, 0)
        sx, sz = pal["sun"][0], pal["sun"][2]
        nb = grid.top.get((i + (1 if sx > 0 else -1), j + (1 if sz > 0 else -1)))
        k = 1.0
        if nb is not None:
            k = max(0.55, min(1.15, 1.0 + (t - nb) / 1200.0))
        px[i - i0, j - j0] = tuple(int(max(0, min(255, base[c] * sh[c] / 255.0 * k)))
                                   for c in range(3))
    img = img.resize((size, size), Image.NEAREST)
    img.save(path)
    return path
EXPLORE_TIERS = ((8400, "tiny"), (10400, "small"), (14400, "medium"), (18400, "large"),
                 (22400, "huge"))
BAND_STEP = 400
BAND_CELLS = 36
BAND_SHARE = 0.04
BANDS_WANT = {"tiny": 3, "small": 4, "medium": 6, "large": 8, "huge": 10, "gigantic": 11}
DESIGN_BANDS = (3, 6)
RELIEF_WANT = {"tiny": 1200, "small": 2000, "medium": 3000, "large": 4293, "huge": 4293,
               "gigantic": 4293}
COINS_WANT = {"tiny": 60, "small": 60, "medium": 100, "large": 100, "huge": 100, "gigantic": 100}
REDS = 8
REDS_FROM = ("medium", "large", "huge", "gigantic")
STARS_WANT = {"tiny": 4, "small": 5, "medium": 7, "large": 8, "huge": 9, "gigantic": 10}
COVER_R = 1500
COVER_WANT = 0.85
TRAIL_R = 1500
TRAIL_WANT = 0.7
GATED_WANT = 0.7
SPAN_WANT = 2500
SPAN_SHARE = 0.6
HIGH_SHARE = 0.25
NEAR_S, FAR_S = 8.0, 20.0
HURT_SHARE = 0.02
SCATTER_TOP = 0.35
SCATTER_KINDS = 5
HERO_NEAR, HERO_FAR = 2000, 9000
SAFE_R = 1500
LAKITU_BACK, LAKITU_UP = 1000, 460
CAM_CLEAR = 800
CAM_HALF_ANGLE = 20
EDGE_BAND = 400
UNDER_GROUND = 60
FOOT_TOL = 400
MOUND_REACH = 1300
PILLARS_SPAN = 2800
SPAWN_HEAD = 160
def _spawn_buried(pieces, s, m):
    x, y, z = s["x"], s["y"], s["z"]
    worst = None
    for p in pieces:
        if p.get("tex") in SKIP_TEX or _is_liquid(p):
            continue
        if abs(p["x"] - x) > (p["w"] + p["d"]) or abs(p["z"] - z) > (p["w"] + p["d"]):
            continue
        try:
            x0, x1, z0, z1, _ = m.footprint(p)
            if not (x0 <= x <= x1 and z0 <= z <= z1):
                continue
            t = m.top_at(p, x, z)
        except Exception:
            continue
        if t is None or p["y"] >= y + SPAWN_HEAD or t <= y + UNDER_GROUND:
            continue
        worst = t if worst is None else max(worst, t)
    return worst
LIQUID_FLOAT = 150
ENEMIES = ("goomba", "koopa", "bobomb", "chainchomp", "thwomp", "flame", "fire", "piranha",
           "bully", "amp")
MOVE_KINDS = ("cannon", "chimney", "wallrun", "sunken", "pillars", "longjump", "gap")
WALK_STAR_KINDS = ("summit", "corner", "guarded")
PROMISE_TAGS = ("isle", "island", "lookout", "floating")
SOFT_WEIGHTS = {"coins": 1.2, "red_coins": 0.8, "coin_star": 0.6, "reward_cover": 1.0,
                "coin_trails": 0.8, "stars": 1.0, "move_gated": 0.6, "relief": 1.2,
                "height_bands": 1.0, "design_bands": 0.6, "star_span": 0.8, "pacing": 0.8,
                "falls": 0.6, "scatter": 0.6, "hero": 1.0}
SHOWCASE = 80
CALIBRATION = {
    "BoB": (4293, 11, 87), "WF": (3328, 8, 100), "JRB": (4996, 4, 101), "CCM": (8189, 20, 136),
    "BBH": (5904, 9, 52), "HMC": (7201, 18, 92), "LLL": (725, 2, 103), "SSL": (1162, 5, 83),
    "DDD": (1023, 3, 106), "SL": (3635, 11, 58), "WDW": (4096, 9, 135), "TTM": (6941, 18, 111),
    "THI": (6949, 19, 81), "TTC": (11402, 12, 126), "RR": (11049, 17, 124)}
def explore_tier(arena):
    half = (arena.get("sites") or {}).get("half")
    if not half:
        return "medium"
    across = 2 * half
    for top, name in EXPLORE_TIERS:
        if across <= top:
            return name
    return "gigantic"
def _soft(value, want, more=True):
    if value is None:
        return 0.5
    if more:
        return _clamp(value / float(want)) if want else 1.0
    return 1.0 if value <= want else _clamp(1.0 - (value - want) / float(max(want, 1e-6)))
def band_counts(heights):
    from collections import Counter
    hb = Counter(int(math.floor(h / float(BAND_STEP))) for h in heights)
    n = max(1, len(heights))
    return (sum(1 for v in hb.values() if v >= BAND_CELLS),
            sum(1 for v in hb.values() if v >= BAND_SHARE * n))
def soft_lines(tier, relief=None, bands=None, coins=None, reds=None, stars=None):
    out = {}
    if relief is not None:
        out["relief"] = _soft(relief, RELIEF_WANT[tier])
    if bands is not None:
        out["height_bands"] = _soft(bands, BANDS_WANT[tier])
    if coins is not None:
        out["coins"] = _soft(coins, COINS_WANT[tier])
    if reds is not None and tier in REDS_FROM:
        out["red_coins"] = 1.0 if reds == REDS else _clamp(reds / float(REDS)) * 0.8
    if stars is not None:
        out["stars"] = _soft(stars, STARS_WANT[tier])
    return out
def _liquid_open(arena):
    try:
        import os
        import sys
        tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if tools not in sys.path:
            sys.path.insert(0, tools)
        from . import basins
        return len(basins._rims(arena))
    except Exception:
        return None
def _is_liquid(p):
    return p.get("kind") == "water" or "lava" in str(p.get("tex", "")) \
        or str(p.get("tag", "")).startswith(("lake.water", "river.water", "water", "lava"))
def _cam_blockers(arena, spawn):
    m = _m()
    yaw = math.radians(spawn.get("yaw", 0) or 0)
    fx, fz = math.sin(yaw), math.cos(yaw)
    eye = (spawn["x"] - fx * LAKITU_BACK, spawn["y"] + LAKITU_UP, spawn["z"] - fz * LAKITU_BACK)
    look = (spawn["x"], spawn["y"] + 100, spawn["z"])
    boxes = []
    for p in arena.get("pieces") or []:
        if str(p.get("tex")) in SKIP_TEX or _is_liquid(p):
            continue
        try:
            x0, x1, z0, z1, _ = m.footprint(p)
        except Exception:
            r = max(p.get("w", 0), p.get("d", 0)) / 2.0
            x0, x1, z0, z1 = p["x"] - r, p["x"] + r, p["z"] - r, p["z"] + r
        if x1 < eye[0] - CAM_CLEAR - 50 or x0 > eye[0] + CAM_CLEAR + 50 \
                or z1 < eye[2] - CAM_CLEAR - 50 or z0 > eye[2] + CAM_CLEAR + 50:
            continue
        boxes.append((x0, x1, z0, z1, p["y"], p["y"] + p["h"], p))
    hit = []
    for a in range(-CAM_HALF_ANGLE, CAM_HALF_ANGLE + 1, 5):
        ang = math.atan2(fx, fz) + math.radians(a)
        dx, dz = math.sin(ang), math.cos(ang)
        drop = (eye[1] - look[1]) / float(LAKITU_BACK)
        for d in range(60, CAM_CLEAR + 1, 40):
            x, y, z = eye[0] + dx * d, eye[1] - drop * d, eye[2] + dz * d
            for b in boxes:
                if b[0] <= x <= b[1] and b[2] <= z <= b[3] and b[4] <= y <= b[5]:
                    if b[6] not in hit:
                        hit.append(b[6])
                    break
    return hit
def _edge_open(arena, grid):
    m = _m()
    info = m.LEVELS.get(arena.get("level") or "empty2") or {}
    if info.get("floor") is not None:
        return []
    half = (arena.get("sites") or {}).get("half")
    if not half:
        return []
    terrain = arena.get("terrain") if isinstance(arena.get("terrain"), dict) else {}
    back = terrain.get("backdrop") if isinstance(terrain.get("backdrop"), dict) else {}
    if terrain.get("mesh") and back.get("half"):
        if back.get("skirt") or back.get("outline"):
            return []
        return [(int(half + EDGE_BAND // 2), 0)]
    beyond = [p for p in arena.get("pieces") or []
              if max(abs(p["x"]), abs(p["z"])) > half + EDGE_BAND
              and not any(w in str(p.get("tag", "")) for w in PROMISE_TAGS + ("setpiece",))]
    if not beyond:
        return []
    out = []
    r = half + EDGE_BAND / 2.0
    k = int(2 * half // 400)
    for i in range(k + 1):
        t = -half + i * 400.0
        for x, z in ((t, -r), (t, r), (-r, t), (r, t)):
            if grid.at(x, z) is None:
                out.append((int(x), int(z)))
    return out
def explore_fun(arena, graph=None, bake=True):
    from collections import Counter
    from . import gameplay, playable
    m = _m()
    G = m.GRID
    tier = explore_tier(arena)
    pieces = arena.get("pieces") or []
    objs = arena.get("objects") or []
    stars = arena.get("stars") or []
    spawns = arena.get("spawns") or []
    hard, soft = {}, {}
    if not spawns:
        return {"hard": {"spawn": {"value": 0, "ok": False, "note": "no spawn"}}, "soft": {},
                "score": 0.0, "pass_hard": False, "fails": ["spawn"], "showcase": False,
                "tier": tier}
    if graph is None:
        graph = m.walk_graph(arena)
    cells, edges = graph
    first = m.spawn_cell(spawns[0])
    live = m.reach(edges, first) if first in cells else set()
    live = set(c for c in live if c[0] > -1000000)
    floor_cells = set((gx, gz) for (gx, gz, h) in live)
    grid = HeightGrid(arena)
    liquids = [p for p in pieces if _is_liquid(p)]
    dry = dict(arena)
    dry["pieces"] = [q for q in pieces if not _is_liquid(q)]
    g2 = HeightGrid(dry)
    afloat = []
    for p in liquids:
        under = g2.at(p["x"], p["z"])
        if under is not None and p["y"] - under > LIQUID_FLOAT:
            afloat.append("%s at (%d, %d, %d) %d over its ground" % (
                p.get("tag") or p.get("tex"), p["x"], p["y"], p["z"], p["y"] - under))
    wet = []
    rects = [(w[0], w[1], w[2], w[3], w[4]) for w in arena.get("water") or [] if len(w) >= 5]
    for p in liquids:
        try:
            x0, x1, z0, z1, _ = m.footprint(p)
        except Exception:
            continue
        rects.append((x0, z0, x1, z1, p["y"] + p["h"]))
    for p in pieces:
        t = str(p.get("tag", ""))
        if not (p.get("light") or "lamp" in t or "torch" in t or "lantern" in t):
            continue
        for x0, z0, x1, z1, top in rects:
            if x0 + 20 < p["x"] < x1 - 20 and z0 + 20 < p["z"] < z1 - 20 and p["y"] < top - 20:
                wet.append("%s at (%d, %d)" % (t or p.get("kind"), p["x"], p["z"]))
                break
    rims = _liquid_open(arena) if (bake and (liquids or arena.get("water"))) else None
    if rims is not None:
        afloat = []
    from . import surround
    falls = ["waterfall %s" % why for _f, why in surround.fall_faults(pieces)]
    n_bad = len(afloat) + len(wet) + (rims or 0) + len(falls)
    hard["liquids"] = {"value": n_bad, "ok": n_bad == 0,
                       "note": "; ".join(([("%d rim points open (bake)" % rims)] if rims else [])
                                         + afloat[:2] + ["lamp in liquid: " + w for w in wet[:2]]
                                         + falls[:2])
                       or ("every liquid in its basin" + ("" if rims is not None else
                                                          " (the bake's rim check not run)"))}
    ring = _edge_open(arena, grid)
    hard["world_edge"] = {"value": len(ring), "ok": not ring,
                          "note": ("%d points of the ring round the play square open to the "
                                   "void, first at %s" % (len(ring), ring[0])) if ring
                          else "the ground runs on to the backdrop"}
    inside = []
    for i, s in enumerate(spawns):
        t = _spawn_buried(pieces, s, m)
        if t is not None:
            inside.append("spawn %d %d under its ground" % (i + 1, t - s["y"]))
    s0 = spawns[0]
    near_bad = [o.get("key") for o in objs if str(o.get("key")) in ENEMIES
                and math.hypot(o["x"] - s0["x"], o["z"] - s0["z"]) < SAFE_R]
    lava = [p for p in pieces if "lava" in str(p.get("tex", ""))]
    for p in lava:
        if math.hypot(p["x"] - s0["x"], p["z"] - s0["z"]) - max(p["w"], p["d"]) / 2.0 < SAFE_R:
            near_bad.append("lava")
            break
    hard["spawn"] = {"value": len(inside) + len(near_bad), "ok": not inside and not near_bad,
                     "note": "; ".join(inside[:3] + ["%s within %d of spawn 1" % (k, SAFE_R)
                                                     for k in near_bad[:3]]) or "spawns clear"}
    reach_bad = list(gameplay.check_stars(arena, graph))
    cols = {}
    for (gx, gz, h) in live:
        cols.setdefault((gx, gz), []).append(h)
    def on_graph(x, y, z, tol=80):
        g = (int(math.floor(x / G)), int(math.floor(z / G)))
        return any(abs(h - y) <= tol for dx in (-2, -1, 0, 1, 2) for dz in (-2, -1, 0, 1, 2)
                   for h in cols.get((g[0] + dx, g[1] + dz), []))
    for s in stars:
        if s.get("kind") in MOVE_KINDS:
            at = s.get("launch")
            if at and not on_graph(at[0], at[1], at[2]):
                reach_bad.append("star %d (%s): its launch (%d, %d, %d) is not walked to" % (
                    s["id"], s["kind"], at[0], at[1], at[2]))
    for o, why in playable.faults(arena, graph):
        reach_bad.append("%s at (%d, %d, %d) %s" % (o.get("key"), o["x"], o["y"], o["z"], why))
    hard["reach"] = {"value": len(reach_bad), "ok": not reach_bad,
                     "note": "; ".join(reach_bad[:3]) or "every star and pickup reached"}
    half = (arena.get("sites") or {}).get("half") or 0
    promised = []
    def walked_near(x, y, z, reach, tol=FOOT_TOL):
        g0, n = (int(math.floor(x / G)), int(math.floor(z / G))), int(reach // G) + 1
        return any(abs(h_ - y) <= tol and math.hypot((g0[0] + dx) * G + G / 2.0 - x,
                                                      (g0[1] + dz) * G + G / 2.0 - z) <= reach
                   for dx in range(-n, n + 1) for dz in range(-n, n + 1)
                   for h_ in cols.get((g0[0] + dx, g0[1] + dz), []))
    mounds = [p for p in pieces if p.get("tag") == "play.cannon.mound"]
    cannons = [o for o in objs if str(o.get("key", "")).startswith("cannon")
               and (on_graph(o["x"], o.get("y", 0), o["z"], tol=400)
                    or (any(abs(q["x"] - o["x"]) <= MOUND_REACH and abs(q["z"] - o["z"]) <= MOUND_REACH
                            for q in mounds)
                        and walked_near(o["x"], o.get("y", 0), o["z"], MOUND_REACH)))]
    steps = [p for p in pieces if p.get("tag") == "play.pillars.step"]
    def climbed_to(p):
        if p.get("tag") != "play.pillars.island":
            return False
        top = p["y"] + p["h"]
        star = [s for s in stars if s.get("kind") == "pillars" and abs(s["x"] - p["x"]) <= p["w"] / 2
                and abs(s["z"] - p["z"]) <= p["d"] / 2 and abs(s["y"] - top) <= 400]
        if not star or not gameplay.grade_of(star[0].get("route") or ["walk"], "pillars")[1]:
            return False
        mine = [q for q in steps if math.hypot(q["x"] - p["x"], q["z"] - p["z"]) <= PILLARS_SPAN]
        if not mine:
            return False
        first = min(mine, key=lambda q: q["h"])
        return walked_near(first["x"], first["y"], first["z"], 300)
    def shot_at(p):
        for o in cannons:
            d = math.hypot(p["x"] - o["x"], p["z"] - o["z"])
            if d > gameplay.CANNON_REACH:
                continue
            want = math.degrees(math.atan2(p["x"] - o["x"], p["z"] - o["z"]))
            if abs((want - (o.get("yaw") or 0) + 180) % 360 - 180) <= 25:
                return True
        return False
    for p in pieces:
        t = str(p.get("tag", ""))
        if not any(w in t for w in PROMISE_TAGS) or "scenery" in t or "backdrop" in t:
            continue
        if shot_at(p) or climbed_to(p) or "roof" in t or \
                p.get("kind") in ("pyramid", "roof", "prism", "ridge"):
            continue
        if half and max(abs(p["x"]), abs(p["z"])) > half:
            continue
        if p["w"] < 400 or p["d"] < 400:
            continue
        top = p["y"] + p["h"]
        try:
            fx0, fx1, fz0, fz1, _ = m.footprint(p)
        except Exception:
            fx0, fx1, fz0, fz1 = p["x"] - 100, p["x"] + 100, p["z"] - 100, p["z"] + 100
        if not any(abs(h_ - top) <= 120
                   for gx in range(int(fx0 // G), int(fx1 // G) + 1)
                   for gz in range(int(fz0 // G), int(fz1 // G) + 1)
                   for h_ in cols.get((gx, gz), [])):
            promised.append("%s at (%d, %d, %d)" % (t, p["x"], top, p["z"]))
    hard["promise"] = {"value": len(promised), "ok": not promised,
                       "note": ("not reached: " + "; ".join(promised[:3])) if promised
                       else "every platform that looks playable is reached"}
    blockers = _cam_blockers(arena, s0)
    hard["spawn_camera"] = {"value": len(blockers), "ok": not blockers,
                            "note": ("%s within %d of spawn 1's camera" % (
                                ", ".join(str(b.get("tag") or b.get("kind")) for b in blockers[:3]),
                                CAM_CLEAR)) if blockers else "the first view is clear"}
    coins = gameplay.coins_of(objs)
    reds = sum(1 for o in objs if o.get("key") == "redcoin")
    soft["coins"] = {"value": coins, "want": ">= %d" % COINS_WANT[tier]}
    if tier in REDS_FROM:
        soft["red_coins"] = {"value": reds, "want": "8"}
        soft["coin_star"] = {"value": bool(arena.get("coinStar")), "want": "a 100-coin star",
                             "score": 1.0 if arena.get("coinStar") else 0.0}
    attract = [(o["x"], o["z"]) for o in objs if o.get("key") in (
        "coins", "coin", "1up", "redcoin", "bluecoin", "box", "itembox")]
    attract += [(s["x"], s["z"]) for s in stars]
    attract += [(p["x"], p["z"]) for p in pieces if str(p.get("tag", "")).split(".")[0] in
                ("landmark", "decor", "prefab", "play", "house", "plaza", "setpiece", "spire")]
    r = int(COVER_R // G)
    acell = {}
    for x, z in attract:
        acell.setdefault((int(x // G) // r, int(z // G) // r), []).append((int(x // G), int(z // G)))
    near = 0
    for (gx, gz) in floor_cells:
        bx, bz = gx // r, gz // r
        found = False
        for ddx in (-1, 0, 1):
            for ddz in (-1, 0, 1):
                for ax, az in acell.get((bx + ddx, bz + ddz), ()):
                    if (ax - gx) ** 2 + (az - gz) ** 2 <= r * r:
                        found = True
                        break
                if found:
                    break
            if found:
                break
        near += found
    cover = near / float(max(1, len(floor_cells)))
    soft["reward_cover"] = {"value": round(cover, 3), "want": ">= %.2f" % COVER_WANT,
                            "score": _soft(cover, COVER_WANT)}
    coin_at = [(o["x"], o["z"]) for o in objs if o.get("key") in ("coins", "coin", "redcoin")]
    trailed = sum(1 for s in stars if any(math.hypot(x - s["x"], z - s["z"]) <= TRAIL_R
                                          for x, z in coin_at))
    tshare = trailed / float(len(stars)) if stars else 0.0
    soft["coin_trails"] = {"value": round(tshare, 2), "want": ">= %.1f" % TRAIL_WANT,
                           "score": _soft(tshare, TRAIL_WANT)}
    n_stars = len(stars) + (1 if arena.get("coinStar") else 0) + (1 if reds >= REDS else 0)
    soft["stars"] = {"value": n_stars, "want": ">= %d" % STARS_WANT[tier]}
    gated = (1.0 - sum(1 for s in stars if s.get("kind") in WALK_STAR_KINDS) / float(len(stars))) \
        if stars else 0.0
    soft["move_gated"] = {"value": round(gated, 2), "want": ">= %.1f" % GATED_WANT,
                          "score": _soft(gated, GATED_WANT)}
    heights = [h for (_, _, h) in live]
    if heights:
        hs = sorted(heights)
        lo, hi = hs[int(0.01 * (len(hs) - 1))], hs[int(0.99 * (len(hs) - 1))]
        relief = hi - lo
    else:
        relief = 0
    bands, design = band_counts(heights)
    soft["relief"] = {"value": round(relief), "want": ">= %d (walk floor p1-p99)" % RELIEF_WANT[tier]}
    soft["height_bands"] = {"value": bands, "want": ">= %d (400 u bands of >= 36 cells; "
                                                     "courses' median 11)" % BANDS_WANT[tier]}
    soft["design_bands"] = {"value": design, "want": "%d-%d (400 u, 4 %% of the floor)" % DESIGN_BANDS,
                            "score": 1.0 if DESIGN_BANDS[0] <= design <= DESIGN_BANDS[1]
                            else _clamp(design / float(DESIGN_BANDS[0])) if design < DESIGN_BANDS[0]
                            else 0.8}
    if stars:
        sy = s0["y"]
        sh = [s["y"] - sy for s in stars]
        span = max(sh) - min(sh)
        high = sum(1 for h in sh if h >= 1000) / float(len(sh))
        sc = min(_soft(span, SPAN_WANT), _soft(span, SPAN_SHARE * max(relief, 1)),
                 _soft(high, HIGH_SHARE))
        soft["star_span"] = {"value": round(span), "want": ">= %d, >= %.1f x relief, >= %d %% "
                                                         "1000 up" % (SPAN_WANT, SPAN_SHARE,
                                                                     100 * HIGH_SHARE),
                             "high": round(high, 2), "score": round(sc, 3)}
        try:
            rs = gameplay.route_seconds(arena)
            ts = sorted(v for v in rs.values() if v is not None)
        except Exception:
            ts = []
        if ts:
            far = FAR_S if tier not in ("tiny", "small") else 12.0
            sc = 0.5 * (1.0 if ts[0] <= NEAR_S else _clamp(NEAR_S / ts[0])) \
                + 0.5 * _soft(ts[-1], far)
            soft["pacing"] = {"value": [round(ts[0], 1), round(ts[-1], 1)],
                              "want": "nearest <= %d s, farthest >= %d s" % (NEAR_S, far),
                              "score": round(sc, 3)}
    colsall = {}
    for (gx, gz, h) in cells:
        colsall.setdefault((gx, gz), []).append(h)
    from . import movement
    hurt = 0
    for (gx, gz, h) in live:
        worst = 0
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            below = [q for q in colsall.get((gx + dx, gz + dz), []) if q <= h + 24]
            if below:
                worst = max(worst, h - max(below))
        if worst > movement.FALL_HURTS:
            hurt += 1
    hshare = hurt / float(max(1, len(live)))
    soft["falls"] = {"value": round(hshare, 3), "want": "<= %.2f" % HURT_SHARE,
                     "score": _soft(hshare, HURT_SHARE, more=False)}
    sc = Counter(str(p.get("tag", "")) for p in pieces if str(p.get("tag", "")).startswith("scatter"))
    tot = sum(sc.values())
    top1 = sc.most_common(1)[0][1] / float(tot) if tot else 0.0
    soft["scatter"] = {"value": round(top1, 2), "kinds": len(sc),
                       "want": "top kind <= %.2f, >= %d kinds" % (SCATTER_TOP, SCATTER_KINDS),
                       "score": 1.0 if not tot else round(
                           0.6 * _soft(top1, SCATTER_TOP, more=False)
                           + 0.4 * _soft(len(sc), SCATTER_KINDS), 3)}
    h = hero(arena)
    if h is None:
        soft["hero"] = {"value": None, "want": "a landmark seen from spawn 1, %d-%d away"
                        % (HERO_NEAR, HERO_FAR), "score": 0.0}
    else:
        d = math.hypot(h[0] - s0["x"], h[1] - s0["z"])
        seen = bool(hero_view(grid, arena, h, s0)[0])
        dist_ok = HERO_NEAR <= d <= HERO_FAR
        soft["hero"] = {"value": round(d), "seen": seen,
                        "want": "seen from spawn 1, %d-%d away" % (HERO_NEAR, HERO_FAR),
                        "score": (0.5 if seen else 0.0) + (0.5 if dist_ok else
                                                           0.25 * _clamp(1 - abs(d - 5500) / 9000.0))}
    lines = soft_lines(tier, relief=relief, bands=bands, coins=coins,
                       reds=reds if tier in REDS_FROM else None, stars=n_stars)
    for k, v in lines.items():
        soft[k]["score"] = round(v, 3)
    for k, v in soft.items():
        v.setdefault("score", 0.5)
        v["score"] = round(v["score"], 3)
    w = dict((k, SOFT_WEIGHTS.get(k, 0.5)) for k in soft)
    score = 100.0 * sum(w[k] * soft[k]["score"] for k in soft) / max(1e-6, sum(w.values()))
    fails = [k for k, v in hard.items() if not v["ok"]]
    return {"hard": hard, "soft": soft, "score": round(score, 1), "pass_hard": not fails,
            "fails": fails, "showcase": not fails and score >= SHOWCASE, "tier": tier,
            "weak": sorted((k for k in soft if soft[k]["score"] < 0.8),
                           key=lambda k: soft[k]["score"])}
def explore_rows(fun):
    rows = {}
    for k, v in fun["soft"].items():
        rows["xf_" + k] = {"value": v.get("value"), "score": v["score"],
                           "note": "%s (want %s)" % (v.get("value"), v.get("want"))}
    rows["xf_hard"] = {"value": len(fun["fails"]), "score": 1.0 if fun["pass_hard"] else 0.0,
                       "note": "; ".join("%s: %s" % (k, fun["hard"][k]["note"]) for k in fun["fails"])
                       or "every hard line holds"}
    return rows
VIEW_TURNS = (0, 15, -15, 30, -30, 45, -45, 60, -60, 90, -90, 180)
def _spawn_safe(arena, s):
    objs = arena.get("objects") or []
    if any(str(o.get("key")) in ENEMIES and math.hypot(o["x"] - s["x"], o["z"] - s["z"]) < SAFE_R
           for o in objs):
        return False
    for p in arena.get("pieces") or []:
        if "lava" in str(p.get("tex", "")) and \
                math.hypot(p["x"] - s["x"], p["z"] - s["z"]) - max(p["w"], p["d"]) / 2.0 < SAFE_R:
            return False
    return True
def first_view(arena):
    sp = arena.get("spawns") or []
    if not sp or (arena.get("family") or "") not in HERO_FAMILIES or arena.get("world"):
        return []
    h = hero(arena)
    grid = None
    def clear_turn(s):
        base = s.get("yaw", 0) or 0
        if h is not None:
            base = math.degrees(math.atan2(h[0] - s["x"], h[1] - s["z"]))
        for t in VIEW_TURNS:
            yaw = int(round(base + t)) % 360
            if not _cam_blockers(arena, dict(s, yaw=yaw)):
                return yaw
        return None
    s0 = sp[0]
    def hero_range(s):
        return h is None or HERO_NEAR <= math.hypot(h[0] - s["x"], h[1] - s["z"]) <= HERO_FAR
    if _spawn_safe(arena, s0) and not _cam_blockers(arena, s0) and hero_range(s0):
        return []
    if _spawn_safe(arena, s0) and hero_range(s0):
        yaw = clear_turn(s0)
        if yaw is not None:
            s0["yaw"] = yaw
            return ["spawn 1 turned to %d: its camera's first view is clear" % yaw]
    from .gameplay import FIRST_SPAWN_CLEAR
    stars = arena.get("stars") or []
    order = sorted(range(1, len(sp)), key=lambda k: (not hero_range(sp[k]), k))
    s0_ok = _spawn_safe(arena, s0) and not _cam_blockers(arena, s0)
    for k in order:
        s = sp[k]
        if s0_ok and not hero_range(s):
            continue
        if not _spawn_safe(arena, s) or any(
                math.hypot(st["x"] - s["x"], st["z"] - s["z"]) < FIRST_SPAWN_CLEAR for st in stars):
            continue
        yaw = clear_turn(s)
        if yaw is None:
            continue
        s["yaw"] = yaw
        sp[0], sp[k] = sp[k], sp[0]
        return ["spawn %d is the arrival now: safe, and its camera's first view is clear" % (k + 1)]
    del grid
    if _spawn_safe(arena, s0) and not _cam_blockers(arena, s0):
        if h is not None:
            want = math.degrees(math.atan2(h[0] - s0["x"], h[1] - s0["z"]))
            off = abs((want - (s0.get("yaw", 0) or 0) + 180) % 360 - 180)
            yaw = clear_turn(s0) if off > 60 else None
            if yaw is not None:
                s0["yaw"] = yaw
                return ["spawn 1 turned to %d: toward the landmark, into the world" % yaw]
        return []
    return ["spawn 1's first view: no spawn has a clear camera and safe ground"]
