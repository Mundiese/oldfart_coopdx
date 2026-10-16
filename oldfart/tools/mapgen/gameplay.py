import math
from . import kit, modeknow, movement, v1
from .metrics import mario
STAR_COUNT = 6
STAR_LIFT = 200
SPAWN_CLEAR = 1500
FIRST_SPAWN_CLEAR = 2500
EDGE_BAND = 0.82
EDGE_MAX = 1
LIFT_RISE = 1200
FERRY_UP = 1200
FERRY_FAR = 1800
CANNON_REACH = 6000
KICK_RISE = 350
CHIMNEY_GAP = 400
LONGJUMP_GAP = int(movement.GAPS["hard"]) // 100 * 100
ITEM_CLEAR = 300
SPAWN_ITEM_CLEAR = 600
CLUTTER_MAX = 6
GP_WALK_SHARE = 0.3
GP_UP_DOWN = 300
GP_CURVE = 0.6
GP_NEAR_S = 4.0
GP_FAR_S = (12.0, 20.0)
STAR_KINDS = {
    "summit": (1, None, "climb the hill's ramps to its summit"),
    "corner": (1, None, "climb the corner tower's steps (a well-made corner)"),
    "lift": (1, "movers", "ride the lift up to the ledge (it starts when you stand on it)"),
    "ferry": (2, "movers", "ride the ferry to the floating island"),
    "sunken": (2, None, "dive to the bottom of the pool"),
    "cave": (2, None, "walk to the end of the dark cave"),
    "cannon": (2, "scenery", "climb into the cannon and shoot onto the floating island"),
    "guarded": (2, "enemies", "get past the guards on the plaza deck"),
    "wallrun": (3, "movers", "run up the triangular blocks on the wall"),
    "pillars": (3, None, "double-jump up the stepping pillars to the island"),
    "chimney": (3, None, "wall-kick up the chimney"),
    "longjump": (3, None, "long-jump from the deck to the floating island"),
}
SHELF_CATEGORY = {"Enemies": "enemies", "Bosses": "enemies", "Fliers and ghosts": "enemies",
                  "In the water": "enemies", "Fire and hazards": "hazards",
                  "Crushers and traps": "hazards", "Platforms": "movers", "Lifts": "movers",
                  "Clockwork": "movers", "Coins and pickups": "items",
                  "Things to carry": "items", "Switches and posts": "items",
                  "Friends and scenery": "scenery"}
PATTERNS = {
    "wallrun": ("movers", ("triblock",), "a triangular-block wall run up to a ledge"),
    "falling_bridge": ("hazards", ("donut",), "falling platforms across a pool"),
    "log_gauntlet": ("movers", ("mvlog",), "rolling logs on a path across a long road"),
    "pool_ferry": ("movers", ("mvslab",), "a platform ferrying over a pool, rim to rim"),
    "cannon_shortcut": ("scenery", ("cannon",), "a cannon as the shortcut to an island"),
    "guards": ("enemies", ("goomba", "koopa", "bobomb"), "enemies guarding a star route"),
    "lift": ("movers", ("mvslab",), "a lift on a path up to a higher ledge"),
    "island_ferry": ("movers", ("mvslab",), "a ferry to a floating island"),
    "pickups": ("items", ("coin", "1up"), "coins along the routes, a 1-up at a hard one"),
}
PATTERN_WORDS = {"moving_platforms": ("lift", "log_gauntlet", "pool_ferry"),
                 "jumps": ("wallrun",), "water": ("falling_bridge",)}
STAR_PATTERN = {"lift": "lift", "ferry": "island_ferry", "wallrun": "wallrun",
                "cannon": "cannon_shortcut", "guarded": "guards"}
MOVER_SUBS = {"lift": "lift", "log_gauntlet": "log_gauntlet", "gap_ferry": "pool_ferry",
              "island_ferry": "island_ferry"}
MOVER_PATTERNS = ("lift", "log_gauntlet", "pool_ferry", "island_ferry")
_shelves = {}
def forge_shelf(key):
    if not _shelves:
        import os
        import re
        path = os.path.join(v1.REPO, "of_forge.lua")
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            text = ""
        at = text.find("forge.CATEGORIES = {")
        body = text[at:] if at >= 0 else ""
        end = re.search(r"\n}\n", body)
        body = body[:end.start()] if end else body
        for m in re.finditer(r'name = "([^"]+)", keys = \{(.*?)\}', body, re.S):
            for k in re.findall(r'"([a-zA-Z0-9_]+)"', m.group(2)):
                _shelves[k] = m.group(1)
        _shelves.setdefault("", None)
    return _shelves.get(key)
def category_of(key):
    if str(key).startswith("mv"):
        return "movers"
    return SHELF_CATEGORY.get(forge_shelf(key))
def forge_off(brief):
    off = set(brief.get("forge_off") or []) if hasattr(brief, "get") else set()
    avoid = set(brief["features"]["avoid"])
    if "moving_platforms" in avoid:
        off.add("movers")
    if "all" in off:
        off |= set(modeknow.CATEGORIES)
    return off
def asked(brief):
    want = set(brief["features"]["want"])
    out = set()
    for word, pats in PATTERN_WORDS.items():
        if word in want:
            out |= set(pats)
    keys = set(o.get("key") for o in brief["objects"] or [])
    for name, (_, pkeys, _) in PATTERNS.items():
        if keys & set(pkeys):
            out.add(name)
    reqs = brief.get("requests") if hasattr(brief, "get") else None
    for q in reqs or []:
        if q.get("kind") == "mover":
            sub = q.get("sub")
            out |= {MOVER_SUBS[sub]} if sub in MOVER_SUBS else {"lift", "log_gauntlet"}
        elif q.get("kind") == "forge":
            out |= set(PATTERNS)
    return out
def stars_wanted(brief):
    reqs = brief.get("requests") if hasattr(brief, "get") else None
    for q in reqs or []:
        if q.get("kind") == "stars":
            return q.get("count") != 0
    return brief["family"] == "explore"
def order_and_name(stars, brief, arena):
    from . import starnames
    n = len(stars)
    slots = [None] * n
    rest = []
    for st in stars:
        h = st.get("hint")
        want = h.get("n") if isinstance(h, dict) else None
        if isinstance(want, int) and 1 <= want <= n and slots[want - 1] is None:
            slots[want - 1] = st
        else:
            rest.append(st)
    names = {h["n"]: h["name"] for h in star_hints(brief) if h.get("name")}
    for i in range(n):
        if slots[i] is None:
            slots[i] = rest.pop(0)
    for i, st in enumerate(slots):
        st["id"] = i + 1
        if names.get(i + 1):
            st["name"] = names[i + 1]
            st["asked"] = True
        if isinstance(st.get("hint"), dict) and st["hint"].get("kinds"):
            st["asked"] = True
    sites = arena.get("sites") or {}
    get = brief.get if hasattr(brief, "get") else (lambda k, d=None: d)
    starnames.name_stars(slots, sites.get("districts"), get("theme"),
                         seed="%s:%s" % (get("seed"), arena.get("key")),
                         taken=list(names.values()))
    return slots
def star_hints(brief):
    for q in (brief.get("requests") if hasattr(brief, "get") else None) or []:
        if q.get("kind") == "stars" and isinstance(q.get("stars"), list):
            return sorted((h for h in q["stars"] if isinstance(h, dict)),
                          key=lambda h: h.get("n", 0))
    return []
def h_why(kinds, arena, rules):
    out = []
    for k in kinds:
        cat = STAR_KINDS[k][1]
        ok, why = rules.allows(cat)
        if not ok:
            out.append("%s: %s" % (k, why or "%s are switched off" % cat))
        elif k == "cave":
            out.append("a cave needs a hills, ruins, forest or garden district with room")
        elif k == "sunken":
            out.append("no pool deep enough")
        elif k == "summit":
            out.append("no hill summit")
        elif k == "guarded" or k == "longjump":
            out.append("no plaza deck")
        else:
            out.append("%s: no clearing wide enough" % k)
    return "; ".join(out) or "no room"
STARS_BY_SIZE = {"tiny": 4, "small": 5, "medium": 6, "large": 6, "huge": 8, "gigantic": 10}
STAR_MOST = 10
def star_count(brief):
    for q in (brief.get("requests") if hasattr(brief, "get") else None) or []:
        if q.get("kind") == "stars" and isinstance(q.get("count"), int):
            return max(1, min(STAR_MOST, q["count"]))
    if brief.get("family") == "explore":
        from . import budget as budgetmod
        return STARS_BY_SIZE.get(budgetmod.tier_of(brief.get("size")), STAR_COUNT)
    return STAR_COUNT
class Rules:
    def __init__(self, brief, arena):
        self.off = forge_off(brief)
        self.named = list(brief["modes"] or [])
        self.modes = list(self.named or arena.get("onlyFor") or [])
        self.family = brief["family"]
        self.dropped = []
    def allows(self, category):
        if category is None:
            return True, "no Forge item"
        if category in self.off:
            return False, "the wish switched %s off" % category
        return modeknow.allows(self.modes, category, self.family)
    def make_room(self, category):
        if category in self.off or self.named:
            return False
        keep = [m for m in self.modes if modeknow.allows([m], category, self.family)[0]]
        if not keep or len(keep) == len(self.modes):
            return False
        for m in self.modes:
            if m not in keep:
                self.dropped.append((m, modeknow.allows([m], category, self.family)[1]))
        self.modes = keep
        return True
def _rect(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw", 0))) % 180 == 90:
        w, d = d, w
    return (p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0)
def _overlap(a, b, margin=0):
    return (a[0] - margin < b[1] and b[0] - margin < a[1]
            and a[2] - margin < b[3] and b[2] - margin < a[3])
CLEARABLE = ("tree", "tree.crown")
class Space:
    def __init__(self, arena):
        self.rects = []
        self.tops = []
        self.trees = []
        from . import flora
        for g in flora.groups(arena["pieces"]):
            for p in g:
                self.trees.append((_rect(p), g))
        for p in arena["pieces"]:
            tag = str(p.get("tag", ""))
            if tag in ("ground", "terrace.plate"):
                continue
            if tag in CLEARABLE or flora.is_tree(p):
                continue
            self.rects.append(_rect(p))
            self.tops.append(p["y"] + p["h"])
        self.spawns = [(s["x"], s["z"]) for s in arena.get("spawns", [])]
        self.pieces = arena["pieces"]
        self.level = arena.get("level")
        from . import basins
        self.mound_tex = basins.mound_texture(arena)
        from . import heightfield
        self.ground = [p for p in arena["pieces"] if self.mound_tex and heightfield.is_terrain(p)]
        self.bounds = _play_bounds(arena)
        self.base = None
        self.mine = []
        self.cleared = []
    def free(self, rect, margin=200, above=None):
        if above is None:
            above = self.base
        if self.bounds is not None:
            b = self.bounds
            if rect[0] < b[0] or rect[1] > b[1] or rect[2] < b[2] or rect[3] > b[3]:
                return False
        for r, top in zip(self.rects, self.tops):
            if above is not None and top <= above + 1:
                continue
            if _overlap(rect, r, margin):
                return False
        return not any(_overlap(rect, r, margin) for r in self.mine)
    def holds(self, pieces):
        floor = (v1.arenas_module().LEVELS.get(self.level) or {}).get("floor")
        for p in pieces:
            if p.get("h", 0) <= 200 or (floor is not None and p["y"] <= floor + 12):
                continue
            a = _rect(p)
            held = False
            for q in self.pieces:
                if q.get("tex") == "invisible" or q.get("kind") == "water":
                    continue
                b = _rect(q)
                if b[1] <= a[0] or b[0] >= a[1] or b[3] <= a[2] or b[2] >= a[3]:
                    continue
                top = q["y"] + q["h"]
                if abs(top - p["y"]) <= 3 or q["y"] < p["y"] < top:
                    held = True
                    break
            if not held and not any(q is not p and abs(q["y"] + q["h"] - p["y"]) <= 3
                                    and _overlap(_rect(q), a) for q in pieces):
                return False
        return True
    def floor_under(self, rect, y, tol=30):
        for r, top in zip(self.rects, self.tops):
            if abs(top - y) <= tol and r[0] <= rect[0] and r[1] >= rect[1] \
                    and r[2] <= rect[2] and r[3] >= rect[3]:
                return True
        return False
    def take(self, rect, margin=100):
        rects = rect if isinstance(rect, list) else [rect]
        for one in rects:
            self.mine.append(one)
            for tr, g in self.trees:
                if _overlap(one, tr, margin):
                    for p in g:
                        if not any(p is q for q in self.cleared):
                            self.cleared.append(p)
    def standing(self, pieces):
        gone = set(id(p) for p in self.cleared)
        return [p for p in pieces if id(p) not in gone]
def _play_bounds(arena):
    rects = []
    for p in arena.get("pieces", []):
        tag = str(p.get("tag", ""))
        if tag.startswith(("edge", "dress.backdrop", "outland")) or p.get("decor"):
            continue
        rects.append(_rect(p))
    if not rects:
        return None
    x0, x1 = min(r[0] for r in rects), max(r[1] for r in rects)
    z0, z1 = min(r[2] for r in rects), max(r[3] for r in rects)
    try:
        half = v1.arenas_module().LEVELS[arena.get("level")]["half"]
    except (KeyError, TypeError):
        half = None
    if half:
        x0, x1, z0, z1 = max(x0, -half), min(x1, half), max(z0, -half), min(z1, half)
    return (x0, x1, z0, z1)
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    p = kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, tag)
    p["model"] = v1.arenas_module().model_name(p)
    return p
def _tex(arena, role, fallback):
    have = kit.textures()
    for t in role:
        if t in have:
            return t
    return fallback
def _square(x, z, half):
    return (x - half, x + half, z - half, z + half)
def build_corner(site, lift, space, tex):
    x, z = site["x"], site["z"]
    rect = _square(x, z, 600)
    if not space.free(rect, 100):
        return None
    st = 180
    pieces = [_box(tex, x - 200, x + 200, lift, lift + 3 * st, z - 200, z + 200,
                   "play.corner.keep")]
    pieces.append(_box(tex, x - 200, x + 200, lift, lift + st, z + 200, z + 600, "play.corner.step"))
    pieces.append(_box(tex, x + 200, x + 600, lift, lift + 2 * st, z - 200, z + 600,
                       "play.corner.step"))
    pieces.append(_box(tex, x - 600, x + 200, lift, lift + st, z - 600, z - 200, "play.corner.step"))
    return pieces, [], (x, lift + 3 * st, z), ["walk", "jump 180", "jump 180", "jump 180"], rect
def build_cave(site, lift, space, tex, r):
    x, z = site["x"], site["z"]
    along = r.choice(("x", "z"))
    if along == "x":
        rect = (x - 800, x + 800, z - 400, z + 400)
    else:
        rect = (x - 400, x + 400, z - 800, z + 800)
    if not space.free(rect, 200):
        return None
    top = lift + 500
    if along == "x":
        pieces = [_box(tex, x - 800, x + 800, lift, top, z - 400, z - 200, "play.cave.wall"),
                  _box(tex, x - 800, x + 800, lift, top, z + 200, z + 400, "play.cave.wall"),
                  _box(tex, x + 600, x + 800, lift, top, z - 200, z + 200, "play.cave.back"),
                  _box(tex, x - 800, x + 800, top, top + 200, z - 400, z + 400, "play.cave.roof")]
        star = (x + 450, lift, z)
    else:
        pieces = [_box(tex, x - 400, x - 200, lift, top, z - 800, z + 800, "play.cave.wall"),
                  _box(tex, x + 200, x + 400, lift, top, z - 800, z + 800, "play.cave.wall"),
                  _box(tex, x - 200, x + 200, lift, top, z + 600, z + 800, "play.cave.back"),
                  _box(tex, x - 400, x + 400, top, top + 200, z - 800, z + 800, "play.cave.roof")]
        star = (x, lift, z + 450)
    return pieces, [], star, ["walk", "walk 1400 in the dark"], rect
def build_chimney(site, lift, space, tex, height=1000):
    x, z = site["x"], site["z"]
    g = CHIMNEY_GAP // 2
    rect = (x - g - 200, x + g + 200, z - 600, z + 600)
    if not space.free(rect, 200):
        return None
    top = lift + height
    pieces = [_box(tex, x - g - 200, x - g, lift, top, z - 600, z + 600, "play.chimney.wall"),
              _box(tex, x + g, x + g + 200, lift, top, z - 600, z + 600, "play.chimney.wall"),
              _box(tex, x - g - 200, x + g + 200, top, top + 100, z + 200, z + 600,
                   "play.chimney.cap")]
    kicks = int(math.ceil(height / float(KICK_RISE)))
    return pieces, [], (x, top + 100, z + 400), ["walk"] + ["wall kick"] * kicks, rect
def build_pillars(site, lift, space, tex, r):
    x, z = site["x"], site["z"]
    dx, dz = r.choice(((1, 0), (0, 1), (-1, 0), (0, -1)))
    steps = 4
    far = 500 * steps + 300 + 400
    xs = sorted((x - 200 * abs(dz) - 200 * dx, x + dx * far + 400 * abs(dz)))
    zs = sorted((z - 200 * abs(dx) - 200 * dz, z + dz * far + 400 * abs(dx)))
    rect = (min(xs[0], x - 400), max(xs[1], x + 400), min(zs[0], z - 400), max(zs[1], z + 400))
    if not space.free(rect, 100):
        return None
    pieces, moves = [], ["walk"]
    for k in range(steps):
        cx, cz = x + dx * 500 * k, z + dz * 500 * k
        h = 250 * (k + 1)
        pieces.append(_box(tex, cx - 100, cx + 100, lift, lift + h, cz - 100, cz + 100,
                           "play.pillars.step"))
        moves.append("double jump 250, gap 300")
    ix, iz = x + dx * (500 * steps + 300), z + dz * (500 * steps + 300)
    top = lift + 250 * steps
    pieces.append(_box(tex, ix - 400, ix + 400, top - 100, top, iz - 400, iz + 400,
                       "play.pillars.island"))
    moves.append("jump 0, gap 300")
    return pieces, [], (ix, top, iz), moves, rect
def build_lift(site, lift, space, tex, on_floor=False):
    from . import movers
    x, z = site["x"], site["z"]
    rect = (x - 300, x + 900, z - 400, z + 400)
    if not space.free(rect, 200, above=lift if on_floor else None):
        return None
    top = lift + LIFT_RISE
    pieces = [_box(tex, x + 150, x + 750, top - 100, top, z - 300, z + 300, "play.lift.ledge"),
              _box(tex, x + 350, x + 550, lift, top - 100, z - 100, z + 100, "play.lift.post")]
    base = lift + (movers.SHAPES["slab"][1] if on_floor else 0)
    mv = movers.lift((x, base, z), (x, top, z), tex=_mover_tex(tex))
    mv["pattern"] = "lift"
    return pieces, [], (x + 450, top, z), ["walk", "ride lift %d" % LIFT_RISE, "step off"], \
        rect, [mv]
def build_ferry(site, lift, space, tex, r, on_floor=False):
    from . import movers
    x, z = site["x"], site["z"]
    dirs = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    r.shuffle(dirs)
    for dx, dz in dirs:
        ix, iz = x + dx * FERRY_FAR, z + dz * FERRY_FAR
        rect = (min(x, ix) - 450, max(x, ix) + 450, min(z, iz) - 450, max(z, iz) + 450)
        if space.free(rect, 100):
            break
    else:
        return None
    top = lift + FERRY_UP
    pieces = [_box(tex, ix - 400, ix + 400, top - 150, top, iz - 400, iz + 400,
                   "play.ferry.island")]
    dock = (ix - dx * 510, top, iz - dz * 510)
    base = lift + (movers.SHAPES["slab"][1] if on_floor else 0)
    mv = movers.island_ferry((x, base, z), dock, tex=_mover_tex(tex))
    mv["pattern"] = "island_ferry"
    return pieces, [], (ix, top, iz), ["walk", "ride ferry %d" % FERRY_FAR, "step off"], \
        rect, [mv]
def _mover_tex(tex):
    from . import movers
    for t in (tex, "woodenplank1", "stone1"):
        if movers.key_known(movers.platform_key("slab", t)):
            return t
    return "stone1"
MOUND_DISTS = (2000, 2400, 1600, 2800, 3200, 3600, 4000)
WELL_DISTS = (2400, 1600, 2800, 3200)
MOUND_DIRS = ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1))
def _covers(p, x, z):
    r = _rect(p)
    return r[0] <= x <= r[1] and r[2] <= z <= r[3]
def build_cannon(site, lift, space, tex, r):
    x, z = site["x"], site["z"]
    dirs = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    first = r.choice(dirs)
    rect = _square(x, z, 500)
    if not space.free(rect, 100):
        return None
    from . import basins
    order = [first] + [d for d in dirs if d != first]
    mound_tex = getattr(space, "mound_tex", None)
    if mound_tex:
        for dist in MOUND_DISTS:
            for dx, dz in MOUND_DIRS:
                f = 0.7071 if dx and dz else 1.0
                cx = x + int(round(dx * dist * f / 100.0)) * 100
                cz = z + int(round(dz * dist * f / 100.0)) * 100
                dug = _dig(space, cx, cz, lift)
                if dug is None:
                    continue
                gone, rest = dug
                well, cy, rects = basins.cannon_well(cx, cz, lift, tex, tex, (1, 0),
                                                     mound=basins.DIG)
                if any(_overlap(q, (a, a, b, b), 150) for q in rects for a, b in space.spawns):
                    continue
                if not _cone_ok(space, x, z, cx, cy, cz):
                    continue
                for p in gone:
                    if not any(p is q for q in space.cleared):
                        space.cleared.append(p)
                return _cannon_result(x, z, cx, cz, cy, lift, tex, well + rest, rects, dist)
    tries = ([(d, dist, mound_tex) for dist in MOUND_DISTS for d in MOUND_DIRS] if mound_tex
             else []) + [(d, 2000, None) for d in order] + \
        [(d, dist, None) for dist in WELL_DISTS for d in order]
    for (dx, dz), dist, mound in tries:
        f = 0.7071 if dx and dz else 1.0
        cx = x + int(round(dx * dist * f / 100.0)) * 100
        cz = z + int(round(dz * dist * f / 100.0)) * 100
        if dx and dz:
            dx, dz = (dx, 0)
        well, cy, rects = basins.cannon_well(cx, cz, lift, tex, tex, (dx, dz), mound=mound)
        if (not mound or space.holds(well)) and all((space.free(q, 100, above=lift) if mound else
                space.free(q, 100) and (space.base is None or space.floor_under(q, lift)))
               and not any(_overlap(q, (a, a, b, b), 150) for a, b in space.spawns)
               for q in rects) and _cone_ok(space, x, z, cx, cy, cz):
            break
    else:
        return None
    return _cannon_result(x, z, cx, cz, cy, lift, tex, well, rects, dist)
def _cone_ok(space, x, z, cx, cy, cz):
    from . import cannons
    pieces = getattr(space, "pieces", None)
    if pieces is None:
        return True
    yaw = int(math.degrees(math.atan2(x - cx, z - cz))) % 360
    return cannons.cone_free(pieces, cx, cy, cz, yaw)
def _cannon_result(x, z, cx, cz, cy, lift, tex, well, rects, dist):
    rect = _square(x, z, 500)
    top = lift + 1400
    pieces = [_box(tex, x - 500, x + 500, top - 150, top, z - 500, z + 500, "play.cannon.island")]
    for p in well:
        p["model"] = v1.arenas_module().model_name(p)
    pieces += well
    objs = [{"key": "cannon", "what": "cannon", "x": int(cx), "y": int(cy), "z": int(cz),
             "yaw": int(math.degrees(math.atan2(x - cx, z - cz))) % 360, "modes": [],
             "pattern": "cannon_shortcut"}]
    return pieces, objs, (x, top, z), ["walk", "cannon %d" % dist], [rect] + rects
DIG_MARGIN = 200
def _dig(space, cx, cz, lift):
    from . import basins
    rim = lift + basins.WELL_DEPTH
    w = basins.WELL_HALF + basins.WELL_WALL
    hole = (cx - w, cx + w, cz - w, cz + w)
    m = w + DIG_MARGIN
    area = (cx - m, cx + m, cz - m, cz + m)
    if not space.free(area, 0, above=rim):
        return None
    near = [p for p in space.ground if _overlap(_rect(p), area, 0)]
    step = 100
    xs = range(int(area[0]) + 50, int(area[1]), step)
    zs = range(int(area[2]) + 50, int(area[3]), step)
    for px in xs:
        for pz in zs:
            tops = [p["y"] + p["h"] for p in near if _rect(p)[0] <= px <= _rect(p)[1]
                    and _rect(p)[2] <= pz <= _rect(p)[3]]
            if not tops or abs(max(tops) - rim) > 10:
                return None
    cut = [p for p in near if _overlap(_rect(p), hole, 0) and p["y"] + p["h"] > lift]
    if any(p.get("kind") != "box" for p in cut):
        return None
    rest = []
    for p in cut:
        rest += basins.cut_out(p, hole)
        if p["y"] < lift:
            x0, x1, z0, z1 = _rect(p)
            a0, a1, b0, b1 = max(x0, hole[0]), min(x1, hole[1]), max(z0, hole[2]), min(z1, hole[3])
            under = dict(p, x=(a0 + a1) / 2.0, z=(b0 + b1) / 2.0, w=a1 - a0, d=b1 - b0, yaw=0,
                         h=lift - p["y"])
            under.pop("model", None)
            rest.append(under)
    return cut, rest
def build_wallrun(site, lift, space, tex):
    x, z = site["x"], site["z"]
    rect = (x - 1000, x + 1000, z - 300, z + 300)
    if not space.free(rect, 200):
        return None
    top = lift + 1000
    pieces = [_box(tex, x - 1000, x + 1000, lift, top, z + 100, z + 300, "play.wallrun.wall"),
              _box(tex, x + 600, x + 1000, top - 100, top, z - 300, z + 100, "play.wallrun.ledge")]
    objs = []
    for k in range(4):
        objs.append({"key": "triblock", "what": "triblock", "x": int(x - 800 + 400 * k),
                     "y": int(lift), "z": int(z + 99), "yaw": 180,
                     "modes": [], "pattern": "wallrun"})
    return pieces, objs, (x + 800, top, z - 100), ["walk", "run up the triangular block"], rect
def _candidates(arena, rules, r):
    s = arena.get("sites") or {}
    lift = s.get("lift", 0)
    half = s.get("half") or 8000
    out = []
    def add(kind, site, district, extra=None):
        c = {"kind": kind, "x": site["x"], "z": site["z"], "y": site.get("y", lift),
             "district": district, "site": site, "grade": STAR_KINDS[kind][0]}
        c.update(extra or {})
        out.append(c)
    for su in s.get("summits", []):
        add("summit", su, su.get("district"))
    for po in s.get("pools", []):
        add("sunken", dict(po, y=po["bottom"]), po.get("district"))
    for co in s.get("corners", []):
        add("corner", co, None)
    for de in s.get("decks", []):
        add("guarded", de, de.get("district"))
        add("longjump", de, de.get("district"))
    opens = list(s.get("open", []))
    r.shuffle(opens)
    by_d = {}
    for o in opens:
        by_d.setdefault(o.get("district"), []).append(o)
    for d, cells in sorted(by_d.items(), key=lambda kv: str(kv[0])):
        dk = next((x["kind"] for x in s.get("districts", []) if x["i"] == d), None)
        for k, need in ROOM.items():
            if k == "cave" and dk not in ("hills", "ruins", "forest", "garden"):
                continue
            room = [c for c in cells if c.get("clear", 1) >= need]
            room += [c for c in cells if c.get("clear", 1) == need - 1][:6]
            for cell in room[:9]:
                add(k, cell, d, {"dkind": dk})
    keep = []
    for c in out:
        cat = STAR_KINDS[c["kind"]][1]
        ok, _ = rules.allows(cat)
        if ok:
            keep.append(c)
    return keep, half, lift
ROOM = {"cave": 2, "chimney": 2, "pillars": 3, "lift": 2, "cannon": 1, "wallrun": 3,
        "ferry": 2}
def _edge(c, half):
    return max(abs(c["x"]), abs(c["z"])) > EDGE_BAND * half
def place_stars(arena, brief, rules, r, space, notes):
    cands, half, lift = _candidates(arena, rules, r)
    spawns = [(sp["x"], sp["z"]) for sp in arena.get("spawns", [])]
    first = spawns[0] if spawns else (0, 0)
    cands = [c for c in cands
             if math.hypot(c["x"] - first[0], c["z"] - first[1]) >= FIRST_SPAWN_CLEAR]
    def near_spawn(x, z, clear):
        return any(math.hypot(x - a, z - b) < clear for a, b in spawns)
    tex_wall = _tex(arena, ("mossyrock", "greystone", "stone1"), "stone1")
    tex_stone = _tex(arena, ("whitestonebrick", "bricklightgrey", "stone2"), "stone1")
    tex_wood = _tex(arena, ("darkplanks", "woodenplank1"), "stone1")
    chosen, built, dropped = [], [], []
    spreads = [(max(1600, half * 0.32), EDGE_MAX, SPAWN_CLEAR),
               (max(1600, half * 0.2), EDGE_MAX, SPAWN_CLEAR),
               (1600, EDGE_MAX + 1, int(SPAWN_CLEAR * 0.7))]
    spread_min, edge_max, clear = spreads.pop(0)
    want = star_count(brief)
    wished = asked(brief)
    for h in star_hints(brief):
        kinds = h.get("kinds")
        if not kinds:
            continue
        pool = [c for c in cands if c["kind"] in kinds and not near_spawn(c["x"], c["z"], clear)]
        pool.sort(key=lambda c: (min([math.hypot(c["x"] - x["x"], c["z"] - x["z"])
                                      for x in chosen] or [half]) < 1600,
                                 -c.get("y", 0) if c["kind"] == "summit" else 0, r.random()))
        done = False
        for c in pool[:12]:
            got = _build_star(c, lift, space, r, tex_wall, tex_stone, tex_wood, arena)
            if got is None:
                continue
            pieces, objs, (sx, sy, sz), route, rect, mvs = got
            if near_spawn(sx, sz, clear) or \
                    math.hypot(sx - first[0], sz - first[1]) < FIRST_SPAWN_CLEAR:
                continue
            cands.remove(c)
            space.take(rect)
            c = dict(c, hint=h)
            chosen.append(c)
            built.append((c, pieces, objs, (sx, sy, sz), route, mvs))
            done = True
            break
        if not done:
            have = sorted(set(c["kind"] for c in cands))
            notes.append(("refused", "star %d" % h["n"], "no place of this world takes a %s "
                          "star (%s); %s" % (" or ".join(kinds), h_why(kinds, arena, rules),
                                             "it is placed as another kind" if have else
                                             "it is left out")))
    sy = (arena.get("spawns") or [{}])[0].get("y", lift)
    def gp_bonus(c):
        return gp_score(c, chosen, first, sy, want)
    walk_cap = [True]
    while len(chosen) < want and cands:
        def score(c):
            kinds = [x["kind"] for x in chosen]
            if kinds.count(c["kind"]) >= 2:
                return None
            if near_spawn(c["x"], c["z"], clear):
                return None
            if c["kind"] == "corner" and "corner" in kinds:
                return None
            if walk_cap[0] and c["kind"] in WALK_KINDS and \
                    sum(1 for x in chosen if x["kind"] in WALK_KINDS) >= \
                    max(1, int(GP_WALK_SHARE * want)):
                return None
            if _edge(c, half) and sum(1 for x in chosen if _edge(x, half)) >= edge_max:
                return None
            dmin = min([math.hypot(c["x"] - x["x"], c["z"] - x["z"]) for x in chosen] or [half])
            if dmin < spread_min:
                return None
            v = 0.0
            v += 3.0 if c["kind"] not in kinds else -1.0
            v += 2.0 if c["district"] is None or c["district"] not in [x["district"] for x in chosen] else -1.5
            v += 1.5 * min(1.0, dmin / half)
            grades = [x["grade"] for x in chosen]
            if c["grade"] == 1 and 1 not in grades:
                v += 1.5
            if c["grade"] >= 3 and sum(1 for g in grades if g >= 3) < 2:
                v += 1.5
            if c["grade"] >= 3 and sum(1 for g in grades if g >= 3) >= 3:
                v -= 2.0
            if STAR_PATTERN.get(c["kind"]) in wished and c["kind"] not in kinds:
                v += 6.0
            v += gp_bonus(c)
            if c["kind"] in PURE_WALK and len(chosen) >= want - 2 and \
                    not any(x["kind"] in PURE_WALK for x in chosen):
                v += 4.0
            return v + r.random() * 0.5
        scored = [(score(c), i, c) for i, c in enumerate(cands)]
        scored = [t for t in scored if t[0] is not None]
        if not scored:
            if spreads:
                spread_min, edge_max, clear = spreads.pop(0)
                cands = list(dropped) + cands
                dropped[:] = []
                continue
            if walk_cap[0]:
                walk_cap[0] = False
                continue
            break
        scored.sort(key=lambda t: (-t[0], t[1]))
        c = scored[0][2]
        cands.remove(c)
        got = _build_star(c, lift, space, r, tex_wall, tex_stone, tex_wood, arena)
        if got is None:
            continue
        pieces, objs, (sx, sy, sz), route, rect, mvs = got
        if near_spawn(sx, sz, clear) or \
                math.hypot(sx - first[0], sz - first[1]) < FIRST_SPAWN_CLEAR:
            dropped.append(c)
            continue
        space.take(rect)
        chosen.append(c)
        built.append((c, pieces, objs, (sx, sy, sz), route, mvs))
    return built
WALK_KINDS = ("summit", "corner", "cave", "guarded")
PURE_WALK = ("summit", "corner", "cave")
def gp_score(c, chosen, first, sy, want):
    near_run = GP_NEAR_S * mario.SPEED
    far_lo, far_hi = GP_FAR_S[0] * mario.SPEED, GP_FAR_S[1] * mario.SPEED
    v = 0.0
    ys = [x["y"] for x in chosen]
    walkers = sum(1 for x in chosen if x["kind"] in WALK_KINDS)
    dist = math.hypot(c["x"] - first[0], c["z"] - first[1])
    if c["kind"] in WALK_KINDS:
        if walkers >= max(1, int(GP_WALK_SHARE * want)):
            v -= 2.0
        elif walkers == 0 and dist <= near_run:
            v += 1.0
    if ys:
        span = max(ys) - min(ys)
        grown = max(ys + [c["y"]]) - min(ys + [c["y"]])
        v += 1.0 * min(1.0, (grown - span) / 1000.0)
    up = sum(1 for y in ys if y >= sy + GP_UP_DOWN)
    down = sum(1 for y in ys if y <= sy - GP_UP_DOWN)
    if c["y"] >= sy + GP_UP_DOWN and up < max(1, want // 4):
        v += 0.75
    if c["y"] <= sy - GP_UP_DOWN and down < max(1, want // 4):
        v += 0.75
    dists = [math.hypot(x["x"] - first[0], x["z"] - first[1]) for x in chosen]
    if dist <= near_run and not any(d <= near_run for d in dists):
        v += 0.75
    if far_lo <= dist <= far_hi and not any(far_lo <= d for d in dists):
        v += 0.75
    g = int(c.get("grade") or 1)
    agree = sum(1 for x, d in zip(chosen, dists)
                if (g - int(x.get("grade") or 1)) * (dist - d) > 0)
    clash = sum(1 for x, d in zip(chosen, dists)
                if (g - int(x.get("grade") or 1)) * (dist - d) < 0)
    if chosen:
        v += GP_CURVE * (agree - clash) / float(len(chosen))
    return v
def _build_star(c, lift, space, r, tex_wall, tex_stone, tex_wood, arena):
    base = lift
    if c["kind"] not in ("summit", "sunken", "guarded", "longjump"):
        base = max(lift, c.get("y", lift) or lift)
    space.base = base if base > lift else None
    try:
        got = _build_star5(c, base, space, r, tex_wall, tex_stone, tex_wood, arena)
    finally:
        space.base = None
    if got is None or len(got) == 6:
        return got
    return tuple(got) + ([],)
def _build_star5(c, lift, space, r, tex_wall, tex_stone, tex_wood, arena):
    site, kind = c["site"], c["kind"]
    if kind == "summit":
        rect = _square(site["x"], site["z"], 150)
        return [], [], (site["x"], site["y"], site["z"]), ["walk", "ramps"], rect
    if kind == "sunken":
        rect = (site["x0"], site["x1"], site["z0"], site["z1"])
        return [], [], (site["x"], site["bottom"], site["z"]), ["walk", "jump 190", "swim down"], rect
    if kind == "guarded":
        x, z, y = site["x"], site["z"], site["y"]
        objs = []
        for k, key in enumerate(("goomba", "koopa", "goomba")):
            a = math.radians(120 * k + 30)
            objs.append({"key": key, "what": key, "x": int(x + 700 * math.sin(a)), "y": int(y),
                         "z": int(z + 700 * math.cos(a)), "yaw": 0, "modes": [],
                         "pattern": "guards"})
        star = (x + site.get("a", 400) + 300, y, z)
        return [], objs, star, ["walk", "stairs", "past the guards"], _square(x, z, 200)
    if kind == "longjump":
        x, z, y = site["x"], site["z"], site["y"]
        deck_half = 1000
        ix, iz = x, z - deck_half - LONGJUMP_GAP - 400
        rect = _square(ix, iz, 450)
        if not space.free(rect, 100):
            return None
        top = y - 100
        if top - lift <= mario.JUMP_DOUBLE + 100:
            top = lift + mario.JUMP_DOUBLE + 150
            if top > y:
                return None
        p = [_box(tex_stone, ix - 400, ix + 400, top - 150, top, iz - 400, iz + 400,
                  "play.longjump.island")]
        return p, [], (ix, top, iz), ["walk", "stairs", "long jump %d" % LONGJUMP_GAP], rect
    if kind == "corner":
        return build_corner(site, lift, space, tex_stone)
    if kind == "cave":
        return build_cave(site, lift, space, tex_wall, r)
    if kind == "chimney":
        return build_chimney(site, lift, space, tex_stone)
    if kind == "pillars":
        return build_pillars(site, lift, space, tex_wood, r)
    on_floor = not (arena.get("sites") or {}).get("lift") or \
        lift > (arena.get("sites") or {}).get("lift", 0)
    if kind == "lift":
        return build_lift(site, lift, space, tex_stone, on_floor=on_floor)
    if kind == "ferry":
        return build_ferry(site, lift, space, tex_wood, r, on_floor=on_floor)
    if kind == "cannon":
        return build_cannon(site, lift, space, tex_stone, r)
    if kind == "wallrun":
        return build_wallrun(site, lift, space, tex_stone)
    return None
def move_ok(move):
    words = move.replace(",", " ").split()
    if not words or words[0] in ("walk", "ramps", "stairs", "step", "past", "swim"):
        return True, 1 if words[:1] != ["swim"] else 2
    if move.startswith("dive") or move.startswith("swim"):
        return True, 2
    num = [int(w) for w in words if w.isdigit()]
    if move.startswith("jump"):
        rise = num[0] if num else 0
        gap = num[1] if len(num) > 1 else 0
        rc = mario.rise_class(rise)
        gc = mario.gap_class(gap)
        return rc <= 3 and gc <= 1, max(1, rc, gc)
    if move.startswith("double jump"):
        rise = num[0] if num else 0
        gap = num[1] if len(num) > 1 else 0
        return rise <= mario.JUMP_DOUBLE and gap <= mario.GAP_SAFE, 2
    if move.startswith("long jump"):
        gap = num[0] if num else 0
        return gap <= mario.GAP_LONG, 3
    if move.startswith("wall kick"):
        return True, 3
    if move.startswith("ride"):
        return True, 2 if "ferry" in move else 1
    if move.startswith("lift"):
        return (num[0] if num else 0) <= LIFT_RISE, 1
    if move.startswith("cannon"):
        return (num[0] if num else 0) <= CANNON_REACH, 2
    if "off a block" in move:
        return True, 2
    if move.startswith("run up the triangular block"):
        return True, 3
    return False, 4
def grade_of(route, kind):
    g = STAR_KINDS[kind][0]
    ok = True
    for m in route:
        good, mg = move_ok(m)
        ok = ok and good
        g = max(g, mg)
    kicks = sum(1 for m in route if m.startswith("wall kick"))
    if kicks >= 4:
        g = 4
    return min(4, g), ok
def _floor_at(pieces, arena, x, z, want):
    m = v1.arenas_module()
    hs = m.standable(pieces, x, z, arena["level"])
    near = [h for h in hs if abs(h - want) <= 60]
    return min(near, key=lambda h: abs(h - want)) if near else None
def _room(arena, extra):
    used = len(arena["pieces"]) + len(arena.get("markers", [])) + len(arena.get("objects", []))
    return arena.get("budget", 0) - used - extra
def _clear(objs, x, z, spawns):
    if any(math.hypot(x - a, z - b) < SPAWN_ITEM_CLEAR for a, b in spawns):
        return False
    if any(math.hypot(x - o["x"], z - o["z"]) < ITEM_CLEAR for o in objs):
        return False
    sq = (int(x // 1000), int(z // 1000))
    return sum(1 for o in objs if (int(o["x"] // 1000), int(o["z"] // 1000)) == sq) < CLUTTER_MAX
LOG_RUNUP = 600
LOG_TRAVEL_MIN = 1600
LOG_LANES = 2
def pattern_log_gauntlet(arena, objs, spawns, movers_now=()):
    from . import movers
    roads = sorted((arena.get("sites") or {}).get("roads", []), key=lambda r: -r["cells"])
    taken = [movers.swept_box(m) for m in movers_now]
    out = []
    for rd in roads:
        if len(out) >= LOG_LANES:
            break
        if rd["cells"] < 8:
            continue
        cell = (arena.get("sites") or {}).get("cell", 400)
        if rd["axis"] == "x":
            zc = rd["z0"] + cell / 2.0
            a = (rd["x0"] + LOG_RUNUP, rd["y"], zc)
            b = (rd["x1"] + cell - LOG_RUNUP, rd["y"], zc)
        else:
            xc = rd["x0"] + cell / 2.0
            a = (xc, rd["y"], rd["z0"] + LOG_RUNUP)
            b = (xc, rd["y"], rd["z1"] + cell - LOG_RUNUP)
        if abs(b[0] - a[0]) + abs(b[2] - a[2]) < LOG_TRAVEL_MIN:
            continue
        m = dict(movers.log_lane(a, b, phase=0), pattern="log_gauntlet")
        box = movers.swept_box(m)
        if any(_boxes_meet(box, t) for t in taken):
            continue
        if not _lane_clear(arena, box) or not _clear_box(objs, box, spawns):
            continue
        out.append(m)
        taken.append(box)
    if out:
        return out, "%d log-roll lane%s on the longest straight roads (a run-up and a landing " \
            "at each end, one log each)" % (len(out), "" if len(out) == 1 else "s")
    for a, b in log_floors(arena):
        if len(out) >= LOG_LANES:
            break
        m = dict(movers.log_lane(a, b), pattern="log_gauntlet")
        box = movers.swept_box(m)
        if not any(_boxes_meet(box, t) for t in taken) and _lane_clear(arena, box) \
                and _clear_box(objs, box, spawns):
            out.append(m)
            taken.append(box)
    if out:
        return out, "%d log-roll lane%s across the widest clear floors (a run-up and a " \
            "landing at each end, one log each)" % (len(out), "" if len(out) == 1 else "s")
    return [], None
def log_floors(arena):
    from . import movers
    width = 2 * movers.LOG_DIMS["log"][0] + 40
    need = LOG_TRAVEL_MIN + 2 * LOG_RUNUP
    tops = []
    for p in arena["pieces"]:
        if p.get("kind") != "box" or str(p.get("tag", "")).startswith("play."):
            continue
        x0, x1, z0, z1 = _rect(p)
        if max(x1 - x0, z1 - z0) >= need and min(x1 - x0, z1 - z0) >= width:
            tops.append(((x1 - x0) * (z1 - z0), p, (x0, x1, z0, z1)))
    tops.sort(key=lambda t: -t[0])
    out = []
    for _, p, (x0, x1, z0, z1) in tops:
        y = p["y"] + p["h"]
        mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        if z1 - z0 >= need and x1 - x0 >= width:
            out.append(((mx, y, z0 + LOG_RUNUP), (mx, y, z1 - LOG_RUNUP)))
        if x1 - x0 >= need and z1 - z0 >= width:
            out.append(((x0 + LOG_RUNUP, y, mz), (x1 - LOG_RUNUP, y, mz)))
    return out
def _boxes_meet(a, b, pad=0):
    return (a[0] < b[1] + pad and b[0] < a[1] + pad and a[2] < b[3] and b[2] < a[3]
            and a[4] < b[5] + pad and b[4] < a[5] + pad)
def _lane_clear(arena, box):
    from . import v1
    m = v1.arenas_module()
    for p in arena["pieces"]:
        if p.get("kind") == "water":
            continue
        x0, x1, z0, z1, _ = m.footprint(p)
        if x0 < box[1] and box[0] < x1 and z0 < box[5] and box[4] < z1 \
                and p["y"] < box[3] and p["y"] + p["h"] > box[2] + 2:
            return False
    return True
def _clear_box(objs, box, spawns):
    pts = [(o["x"], o["z"]) for o in objs] + [(s[0], s[1]) for s in spawns or []]
    for x, z in pts:
        if box[0] - 200 <= x <= box[1] + 200 and box[4] - 200 <= z <= box[5] + 200:
            return False
    return True
def flat_lane(arena, need):
    best = None
    for p in arena["pieces"]:
        if p["kind"] != "box" or str(p.get("tag", "")).startswith("play."):
            continue
        x0, x1, z0, z1 = _rect(p)
        lng, sht = max(x1 - x0, z1 - z0), min(x1 - x0, z1 - z0)
        if lng >= need and sht >= 700 and (best is None or lng > best[0]):
            best = (lng, p, (x0, x1, z0, z1))
    if best is None:
        return None
    _, p, (x0, x1, z0, z1) = best
    y = p["y"] + p["h"]
    mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    if x1 - x0 >= z1 - z0:
        h = (z1 - z0) / 2.0 - 160
        return (mx, y, mz - h), (mx, y, mz + h)
    h = (x1 - x0) / 2.0 - 160
    return (mx - h, y, mz), (mx + h, y, mz)
def pattern_pool_ferry(arena, objs, spawns):
    from . import movers
    for po in (arena.get("sites") or {}).get("pools", []):
        if po["x1"] - po["x0"] < 1400:
            continue
        rim = po["top"]
        a = (po["x0"], rim, po["z"])
        b = (po["x1"], rim, po["z"])
        m = movers.gap_ferry(a, b, tex="woodenplank1")
        return [dict(m, pattern="pool_ferry")], "a platform ferrying over the pool, rim to rim"
    gap = floor_gap(arena)
    if gap is not None:
        m = movers.gap_ferry(gap[0], gap[1], tex="stone1")
        return [dict(m, pattern="pool_ferry")], "a platform ferrying over a %d gap" % gap[2]
    return [], None
def floor_gap(arena, lo=600, hi=1800):
    from . import place
    try:
        pts = place.standing_points(arena, step=200, margin=0)
    except Exception:
        return None
    by = {}
    for (x, h, z, _) in pts:
        by[(int(x), int(z))] = h
    m = v1.arenas_module()
    stand = m.StandIndex(arena["pieces"], arena["level"]).at
    for (x, h, z, _) in pts[::3]:
        for dx, dz in ((1, 0), (0, 1)):
            for d in range(lo, hi + 1, 200):
                bx, bz = x + dx * d, z + dz * d
                if by.get((int(bx), int(bz))) != h:
                    continue
                mid = [(x + dx * t, z + dz * t) for t in range(200, d, 200)]
                if mid and all(not stand(mx, mz) or max(stand(mx, mz)) < h - 600
                               for mx, mz in mid):
                    return (x - dx * 0, h, z), (bx, h, bz), d
    return None
def pattern_lift(arena, objs, spawns, space=None):
    from . import movers, place
    try:
        pts = place.standing_points(arena, step=200, margin=0)
    except Exception:
        return [], None, [], []
    at = {}
    for (x, h, z, _) in pts:
        at.setdefault((int(x), int(z)), []).append(h)
    highs = sorted(pts, key=lambda t: -t[1])[:60]
    offsets = [(dx, dz) for dx in (-400, -200, 0, 200, 400) for dz in (-400, -200, 0, 200, 400)
               if 200 <= math.hypot(dx, dz) <= 400]
    tries = 0
    for (hx, hh, hz, _) in highs:
        for dx, dz in offsets:
            lx, lz = int(hx + dx), int(hz + dz)
            lows = [h for h in at.get((lx, lz), []) if hh - h >= 300]
            if not lows or tries >= 25:
                continue
            tries += 1
            low = max(lows)
            m = movers.lift((lx, low, lz), (lx, hh, lz), tex="stone1")
            trial = dict(arena, movers=[m])
            if not [i for i in movers.issues(trial) if i["kind"] in ("crosses", "stranded")]:
                return [dict(m, pattern="lift")], "a lift up %d to the high floor" % (hh - low), \
                    [], []
    if space is None:
        return [], None, [], []
    count = {}
    for (_, h, _, _) in pts:
        count[h] = count.get(h, 0) + 1
    main = max(count, key=lambda h: (count[h], -abs(h)))
    tex = _tex(arena, ("whitestonebrick", "bricklightgrey", "stone2"), "stone1")
    for (x, h, z, _) in sorted(pts, key=lambda t: (abs(t[0]) + abs(t[2]), t[0], t[2])):
        if h != main or any(math.hypot(x - a, z - b) < SPAWN_ITEM_CLEAR for a, b in spawns):
            continue
        got = build_lift({"x": x, "z": z}, h, space, tex, on_floor=True)
        if got is None:
            continue
        pieces, _, (sx, sy, sz), _, rect, mvs = got
        trial = dict(arena, pieces=space.standing(arena["pieces"]) + pieces, movers=mvs)
        if [i for i in movers.issues(trial) if i["kind"] in ("crosses", "stranded")]:
            continue
        space.take(rect)
        prize = {"key": "1up", "what": "1up", "x": int(sx), "y": int(sy), "z": int(sz), "yaw": 0,
                 "modes": [], "pattern": "lift", "air": True}
        return mvs, "a lift up %d to an upper floor with a 1-up" % LIFT_RISE, pieces, [prize]
    return [], None, [], []
def pattern_falling_bridge(arena, objs, spawns):
    for po in (arena.get("sites") or {}).get("pools", []):
        span = po["x1"] - po["x0"]
        if span < 1200:
            continue
        out = []
        k = 1
        while po["x0"] + 300 * k < po["x1"] - 150:
            x = po["x0"] + 300 * k
            out.append({"key": "donut", "what": "donut", "x": int(x), "y": int(po["top"] + 10),
                        "z": int(po["z"]), "yaw": 0, "modes": [], "pattern": "falling_bridge",
                        "air": True})
            k += 1
        if out:
            return out[:8], "falling platforms across the pool, rim to rim"
    return [], None
def pattern_pickups(arena, objs, spawns, stars):
    out = []
    roads = (arena.get("sites") or {}).get("roads", [])
    for rd in roads[:3]:
        for k in range(5):
            t = 0.2 + 0.15 * k
            x = rd["x0"] + (rd["x1"] - rd["x0"]) * t
            z = rd["z0"] + (rd["z1"] - rd["z0"]) * t
            if _clear(objs + out, x, z, spawns):
                out.append({"key": "coin", "what": "coin", "x": int(x), "y": int(rd["y"]),
                            "z": int(z), "yaw": 0, "modes": [], "pattern": "pickups"})
    for st in stars:
        if st["grade"] >= 3 and st.get("launch"):
            x, y, z = st["launch"]
            if _clear(objs + out, x, z, spawns):
                out.append({"key": "1up", "what": "1up", "x": int(x), "y": int(y), "z": int(z),
                            "yaw": 0, "modes": [], "pattern": "pickups"})
                break
    return out, ("coins along %d roads, a 1-up at the hardest climb" % min(3, len(roads))
                 if out else None)
COIN_STAR_TIERS = ("medium", "large", "huge", "gigantic")
COIN_STAR_STARS = 4
COIN_TARGET = 120
COINS_IN = {"coin": 1, "coins": 5}
COIN_LINE_EVERY = 700
COINS_BY_FORMATION = {"line": 5, "column": 5, "ring": 8, "arch": 5, "arrow": 8}
def coins_of(objs):
    return sum(COINS_BY_FORMATION.get(o.get("formation"), COINS_IN.get(o.get("key"), 0))
               if o.get("key") == "coins" else COINS_IN.get(o.get("key"), 0) for o in objs)
def coin_star_wanted(brief, stars):
    from . import budget as budgetmod
    f = brief.get("features") or {}
    if "coin_star" in (f.get("avoid") or ()):
        return False, "the wish says no 100-coin star"
    if "coin_star" in (f.get("want") or ()):
        return True, "the wish asks for a 100-coin star"
    if brief.get("family") != "explore":
        return False, None
    if budgetmod.tier_of(brief.get("size")) not in COIN_STAR_TIERS:
        return False, None
    if len(stars) < COIN_STAR_STARS:
        return False, None
    return True, "a main-course world (%s, %d bonus stars)" % (
        budgetmod.tier_of(brief.get("size")), len(stars))
def coin_star(arena, brief, objs, stars, spawns, space, new_pieces, top, rules):
    on, why = coin_star_wanted(brief, stars)
    if not on:
        arena.pop("coinStar", None)
        return None if why is None else {"on": False, "coins": coins_of(objs), "added": 0,
                                         "why": why}
    ok, no = rules.allows("items")
    if not ok:
        arena.pop("coinStar", None)
        return {"on": False, "coins": coins_of(objs), "added": 0,
                "why": "no 100-coin star: %s" % no}
    have = coins_of(objs)
    used = (len(arena.get("pieces") or []) + len(new_pieces) + len(objs)
            + len(arena.get("markers") or []) + len(arena.get("movers") or []))
    room = max(0, int(top) - used)
    added = []
    roads = (arena.get("sites") or {}).get("roads", [])
    floor = space.standing(arena["pieces"]) + new_pieces
    for rd in roads:
        if have >= COIN_TARGET or len(added) >= room:
            break
        length = math.hypot(rd["x1"] - rd["x0"], rd["z1"] - rd["z0"])
        n = int(length // COIN_LINE_EVERY)
        for k in range(1, n + 1):
            if have >= COIN_TARGET or len(added) >= room:
                break
            t = k / float(n + 1)
            x = rd["x0"] + (rd["x1"] - rd["x0"]) * t
            z = rd["z0"] + (rd["z1"] - rd["z0"]) * t
            if not _clear(objs + added, x, z, spawns):
                continue
            h = _floor_at(floor, arena, x, z, rd["y"])
            if h is None:
                continue
            along = math.degrees(math.atan2(rd["x1"] - rd["x0"], rd["z1"] - rd["z0"]))
            added.append({"key": "coins", "what": "a line of coins", "x": int(x), "y": int(h),
                          "z": int(z), "yaw": int(round(along)) % 360, "modes": [],
                          "pattern": "coin_star", "formation": "line",
                          "variant": kit.coin_variant("line")})
            have += COINS_IN["coins"]
    if have < COIN_TARGET:
        arena.pop("coinStar", None)
        return {"on": False, "coins": have - COINS_IN["coins"] * len(added), "added": 0,
                "why": "no 100-coin star: the world holds %d coins and the budget (%d left) "
                       "cannot hold the %d more it needs" % (
                           have - COINS_IN["coins"] * len(added), room,
                           COIN_TARGET - (have - COINS_IN["coins"] * len(added)))}
    objs.extend(added)
    arena["coinStar"] = True
    return {"on": True, "coins": have, "added": len(added),
            "why": "%s: %d coins (%d coin lines added)" % (why, have, len(added))}
REDS = 8
RED_TIERS = ("medium", "large", "huge", "gigantic")
RED_APART = 1500
RED_HOVER = 260
RED_SPAWN_CLEAR = 1500
TRAIL_NEAR, TRAIL_FAR = 700, 1500
COINS_WANT = {"tiny": 60, "small": 60}
def _places(arena):
    s = arena.get("sites") or {}
    out = []
    for key in ("summits", "decks", "districts", "open", "corners"):
        for d in s.get(key) or ():
            if isinstance(d, dict) and "x" in d and "z" in d:
                out.append((d["x"], d["z"], d.get("y", d.get("top", 0))))
    for pl in s.get("pools") or ():
        if isinstance(pl, dict) and "x0" in pl:
            out.append((pl["x0"] - 300, pl["z0"] - 300, pl.get("top", 0)))
            out.append((pl["x1"] + 300, pl["z1"] + 300, pl.get("top", 0)))
    for rd in s.get("roads") or ():
        out.append(((rd["x0"] + rd["x1"]) / 2.0, (rd["z0"] + rd["z1"]) / 2.0, rd.get("y", 0)))
    return out
def _stand_any(pieces, arena, x, z, want):
    m = v1.arenas_module()
    hs = m.standable(pieces, x, z, arena["level"])
    if not hs:
        return None
    return min(hs, key=lambda h: abs(h - want))
def rewards(arena, brief, objs, stars, spawns, space, new_pieces, rules):
    from . import budget as budgetmod
    ok, no = rules.allows("items")
    if not ok:
        return [("skipped", "rewards", "no coins: %s" % no)]
    out = []
    floor = space.standing(arena["pieces"]) + new_pieces
    half = (arena.get("sites") or {}).get("half") or 99999
    first = spawns[0] if spawns else (0, 0)
    trailed = 0
    for st in stars:
        base = st.get("launch") or (st["x"], st["y"] - STAR_LIFT, st["z"])
        dx, dz = first[0] - base[0], first[1] - base[2]
        L = math.hypot(dx, dz) or 1.0
        ux, uz = dx / L, dz / L
        placed = False
        for d in (TRAIL_NEAR, 900, 1100, 1300, TRAIL_FAR):
            for side in (0, 300, -300):
                x = base[0] + ux * d - uz * side
                z = base[2] + uz * d + ux * side
                if max(abs(x), abs(z)) > half - 200 or not _clear(objs, x, z, spawns):
                    continue
                h = _stand_any(floor, arena, x, z, base[1])
                if h is None:
                    continue
                yaw = int(round(math.degrees(math.atan2(-ux, -uz)))) % 360
                objs.append({"key": "coins", "what": "a line of coins", "x": int(x), "y": int(h),
                             "z": int(z), "yaw": yaw, "modes": [], "pattern": "trail",
                             "formation": "line", "variant": kit.coin_variant("line")})
                placed = True
                break
            if placed:
                break
        trailed += placed
    out.append(("placed", "coin trails", "a line of coins leads to %d of %d stars"
                % (trailed, len(stars))))
    if budgetmod.tier_of(brief.get("size")) in RED_TIERS:
        reds = []
        places = sorted(_places(arena), key=lambda p: (p[0], p[1]))
        while len(reds) < REDS and places:
            best, bd = None, -1.0
            for p in places:
                if math.hypot(p[0] - first[0], p[1] - first[1]) < RED_SPAWN_CLEAR:
                    continue
                d = min([math.hypot(p[0] - r_[0], p[1] - r_[1]) for r_ in reds] or [99999.0])
                if d > bd:
                    best, bd = p, d
            if best is None or (reds and bd < RED_APART):
                break
            places.remove(best)
            if not _clear(objs, best[0], best[1], spawns):
                continue
            h = _stand_any(floor, arena, best[0], best[1], best[2])
            if h is None:
                continue
            reds.append((best[0], best[1], h))
        if len(reds) == REDS:
            for x, z, h in reds:
                objs.append({"key": "redcoin", "what": "a red coin", "x": int(x),
                             "y": int(h + RED_HOVER), "z": int(z), "yaw": 0, "modes": [],
                             "pattern": "redcoins", "air": True})
            out.append(("placed", "red coins", "eight red coins over the world's places; "
                        "their star stands where the last is taken"))
        else:
            out.append(("approximated", "red coins", "only %d places for red coins far enough "
                        "apart - none laid" % len(reds)))
    return out
def coins_to(arena, brief, objs, spawns, space, new_pieces, rules):
    from . import budget as budgetmod
    tier = budgetmod.tier_of(brief.get("size"))
    want = COINS_WANT.get(tier, COIN_TARGET)
    if not rules.allows("items")[0] or coins_of(objs) >= want:
        return None
    floor = space.standing(arena["pieces"]) + new_pieces
    half = (arena.get("sites") or {}).get("half") or 99999
    added = 0
    for x0, z0, y0 in _places(arena):
        for ox, oz in ((0, 0), (500, 0), (-500, 0), (0, 500), (0, -500)):
            if coins_of(objs) >= want:
                break
            x, z = x0 + ox, z0 + oz
            if max(abs(x), abs(z)) > half - 200 or not _clear(objs, x, z, spawns):
                continue
            h = _stand_any(floor, arena, x, z, y0)
            if h is None:
                continue
            ring = (added % 3 == 2)
            objs.append({"key": "coins", "what": "a ring of coins" if ring else "a line of coins",
                         "x": int(x), "y": int(h), "z": int(z), "yaw": (added * 47) % 360,
                         "modes": [], "pattern": "coins", "formation": "ring" if ring else "line",
                         "variant": kit.coin_variant("ring" if ring else "line")})
            added += 1
    return ("placed" if coins_of(objs) >= want else "approximated", "coins",
            "%d coin formations at the world's places: %d coins (want %d)"
            % (added, coins_of(objs), want))
def run(arena, brief, streams, meta=None):
    r = streams("gameplay")
    rules = Rules(brief, arena)
    space = Space(arena)
    lines, skipped = [], []
    want_patterns = asked(brief)
    explore = brief["family"] == "explore" and arena.get("sites")
    objs = list(arena.get("objects") or [])
    spawns = [(s["x"], s["z"]) for s in arena.get("spawns", [])]
    new_pieces, stars, patterns, new_movers = [], [], [], []
    from . import budget as budgetmod
    top = budgetmod.ceiling(brief["family"], rules.modes)
    if stars_wanted(brief) and explore:
        built = place_stars(arena, brief, rules, r, space, lines)
        for i, (c, pieces, sobjs, (sx, sy, sz), route, smovers) in enumerate(built):
            g, ok = grade_of(route, c["kind"])
            if not ok:
                skipped.append("star %s: a move outside the movement model (%s)" % (
                    c["kind"], ", ".join(route)))
                continue
            placed_objs = []
            for o in sobjs:
                if o.get("air"):
                    placed_objs.append(o)
                    continue
                h = _floor_at(space.standing(arena["pieces"]) + new_pieces + pieces, arena,
                              o["x"], o["z"], o["y"])
                if h is None:
                    break
                placed_objs.append(dict(o, y=int(h)))
            if len(placed_objs) < len(sobjs):
                skipped.append("star %s: its %s has no floor to stand on" % (
                    c["kind"], sobjs[len(placed_objs)]["key"]))
                continue
            if smovers:
                from . import movers as movermod
                trial = dict(arena, pieces=space.standing(arena["pieces"]) + new_pieces + pieces,
                             movers=list(new_movers) + list(smovers))
                bad = [i for i in movermod.issues(trial)
                       if i["kind"] in ("crosses", "stranded", "key", "fast")]
                if bad:
                    skipped.append("star %s: its mover - %s" % (c["kind"], bad[0]["text"]))
                    continue
            new_pieces += pieces
            for mv in smovers:
                new_movers.append(mv)
                if mv.get("pattern") and mv["pattern"] not in patterns:
                    patterns.append(mv["pattern"])
            for o in placed_objs:
                objs.append(o)
                if o.get("pattern") and o["pattern"] not in patterns:
                    patterns.append(o["pattern"])
            launch = None
            if pieces and c["kind"] in ("pillars", "chimney", "wallrun", "cannon", "lift",
                                         "ferry"):
                launch = (c["x"], c["y"], c["z"])
            stars.append({"id": len(stars) + 1, "kind": c["kind"], "x": int(sx),
                          "y": int(sy + STAR_LIFT), "z": int(sz), "grade": g, "route": route,
                          "district": c["district"], "why": STAR_KINDS[c["kind"]][2],
                          "launch": launch, "hint": c.get("hint")})
        stars = order_and_name(stars, brief, arena)
        if len(stars) < star_count(brief):
            lines.append(("approximated", "stars", "%d of %d bonus stars found a designed place "
                          "on this world" % (len(stars), star_count(brief))))
        else:
            lines.append(("placed", "stars", "%d bonus stars: %s" % (
                len(stars), ", ".join("%s (%d)" % (s["kind"], s["grade"]) for s in stars))))
        for s in stars:
            lines.append(("placed", "star %d" % s["id"], "\"%s\" - %s, grade %d%s" % (
                s["name"], s["kind"], s["grade"], " (as the wish asked)" if s.get("asked")
                else "")))
    elif stars_wanted(brief):
        lines.append(("not yet", "stars", "bonus stars are designed into explore worlds; "
                      "this family has no districts to tie them to"))
    cands = []
    if explore:
        cands = ["log_gauntlet", "pool_ferry", "falling_bridge", "pickups"]
    cands += sorted(p for p in want_patterns if p not in cands and p in
                    ("log_gauntlet", "falling_bridge", "pickups", "pool_ferry", "lift"))
    if explore and "lift" in cands and "lift" in patterns:
        cands.remove("lift")
    for name in cands:
        cat = PATTERNS[name][0]
        ok, why = rules.allows(cat)
        if not ok and name in want_patterns and rules.make_room(cat):
            ok = True
        if not ok:
            skipped.append("%s: %s" % (name, why))
            continue
        if name in ("log_gauntlet", "pool_ferry", "lift"):
            extra_pieces, extra_objs = [], []
            if name == "lift":
                got, say, extra_pieces, extra_objs = pattern_lift(arena, objs, spawns, space)
            else:
                if name == "log_gauntlet":
                    got, say = pattern_log_gauntlet(arena, objs, spawns,
                                                    list(arena.get("movers") or [])
                                                    + list(new_movers))
                else:
                    got, say = pattern_pool_ferry(arena, objs, spawns)
            if got:
                from . import movers as movermod
                trial = dict(arena, pieces=space.standing(arena["pieces"]) + new_pieces
                             + extra_pieces, movers=list(new_movers) + got)
                bad = set(i["mover"] for i in movermod.issues(trial)
                          if i["kind"] in ("crosses", "stranded", "key"))
                got = [m for k, m in enumerate(got) if len(new_movers) + k not in bad]
            if not got:
                if name in want_patterns:
                    lines.append(("approximated", "pattern " + name,
                                  "no clear place for %s on this map" % PATTERNS[name][2]))
                continue
            new_movers += got
            if extra_pieces:
                new_pieces += extra_pieces
                objs += extra_objs
            patterns.append(name)
            lines.append(("placed", "pattern " + name, say))
            continue
        if name == "falling_bridge":
            if "pool_ferry" in patterns and len((arena.get("sites") or {}).get("pools", [])) < 2:
                continue
            got, say = pattern_falling_bridge(arena, objs, spawns)
        else:
            got, say = pattern_pickups(arena, objs, spawns, stars)
        if not got:
            if name in want_patterns:
                lines.append(("approximated", "pattern " + name, "no place for %s on this map"
                              % PATTERNS[name][2]))
            continue
        fixed = []
        for o in got:
            if o.get("air"):
                fixed.append(o)
                continue
            h = _floor_at(space.standing(arena["pieces"]) + new_pieces, arena,
                          o["x"], o["z"], o["y"])
            if h is not None:
                fixed.append(dict(o, y=int(h)))
        got = fixed
        if not got:
            continue
        objs += got
        patterns.append(name)
        lines.append(("placed", "pattern " + name, say))
    for name in sorted(want_patterns - set(patterns)):
        if name in ("wallrun", "cannon_shortcut", "guards", "island_ferry") and not explore:
            lines.append(("not yet", "pattern " + name, "%s is built with a star route in an "
                          "explore world" % PATTERNS[name][2]))
    needs = modeknow.spawn_needs_for(rules.modes, brief["family"])
    if needs.get("spawn_gap_ideal") and brief["family"] == "shooter":
        from .fit import spawn_gap
        gap = spawn_gap(arena)
        if gap is not None and gap < needs["spawn_gap_ideal"]:
            lines.append(("noted", "spawns", "spawn points %d apart at the median (SPAWNS' "
                          "ideal for a free-for-all is %d, with cover between)"
                          % (gap, needs["spawn_gap_ideal"])))
    for s in skipped:
        lines.append(("skipped", "gameplay", s))
    if rules.dropped:
        arena["onlyFor"] = list(rules.modes)
        for m, why in rules.dropped:
            lines.append(("approximated", "modes", "not offered to %s any more: the wish asked "
                          "for what it bans (%s)" % (m, why)))
    if not explore and brief.get("family") in SHORTCUT_WANT:
        sc_pieces, say = move_shortcuts(arena, brief, space, new_pieces,
                                        _tex(arena, ("stone2", "greystone", "stone1"), "stone1"))
        new_pieces += sc_pieces
        if sc_pieces:
            patterns.append("shortcuts")
        if say:
            lines.append(say)
    if explore:
        for line in rewards(arena, brief, objs, stars, spawns, space, new_pieces, rules):
            lines.append(line)
        line = coins_to(arena, brief, objs, spawns, space, new_pieces, rules)
        if line:
            lines.append(line)
    cs = coin_star(arena, brief, objs, stars, spawns, space, new_pieces, top, rules)
    if cs is not None:
        if meta is not None:
            meta["coin_star"] = cs
        lines.append(("placed" if cs["on"] else "approximated", "100-coin star", cs["why"]))
    added_objs = len(objs) - len(arena.get("objects") or [])
    have_movers = list(arena.get("movers") or [])
    need = (len(arena["pieces"]) + len(arena.get("markers", [])) + len(new_pieces) + len(objs)
            + len(have_movers) + len(new_movers))
    if need > arena.get("budget", 0):
        if need <= top:
            arena["budget"] = need
        else:
            drop = need - top
            keep = []
            for o in reversed(objs):
                if drop > 0 and o.get("pattern") in ("pickups", "log_gauntlet", "falling_bridge",
                                                     "coins", "trail"):
                    drop -= 1
                    continue
                keep.append(o)
            objs = list(reversed(keep))
            arena["budget"] = top
            lines.append(("approximated", "gameplay", "items held to the measured ceiling %d"
                          % top))
    if space.cleared:
        gone = set(id(p) for p in space.cleared)
        arena["pieces"] = [p for p in arena["pieces"] if id(p) not in gone]
        lines.append(("placed", "clearings", "%d tree pieces cleared for the star routes"
                      % len(gone)))
    for p in new_pieces:
        arena["pieces"].append(p)
    if objs:
        arena["objects"] = objs
    if new_movers:
        from . import movers as movermod
        arena["movers"] = (have_movers + new_movers)[:movermod.LIMITS["cap"]]
    cats = {}
    for o in list(objs) + list(new_movers):
        c = category_of(o["key"]) or "other"
        cats[c] = cats.get(c, 0) + 1
    grades = [s["grade"] for s in stars]
    arena["stars"] = [dict((k, v) for k, v in s.items() if k not in ("launch", "hint"))
                      for s in stars]
    answered = []
    if stars:
        answered.append("stars")
    if new_movers:
        answered.append("mover")
    if patterns:
        answered.append("forge")
    arena["gameplay"] = {
        "answered": answered,
        "stars": [s["kind"] for s in stars], "grades": grades,
        "patterns": sorted(set(patterns)), "items": added_objs, "categories": cats,
        "skipped": skipped, "pieces": len(new_pieces),
        "movers": len(new_movers),
        "descriptor": {"star_kinds": len(set(s["kind"] for s in stars)),
                       "challenge": round(sum(grades) / (4.0 * len(grades)), 3) if grades else 0.0,
                       "items": round(min(1.0, added_objs / 60.0), 3)}}
    return lines
def route_seconds(arena):
    from . import movers
    if not arena.get("spawns"):
        return {}
    sp = arena["spawns"][0]
    stars = arena.get("stars") or []
    secs = movers.routes_s(arena, (sp["x"], sp["y"], sp["z"]),
                           [(st["x"], st["y"] - STAR_LIFT, st["z"]) for st in stars])
    return {st["id"]: t for st, t in zip(stars, secs)}
def check_stars(arena, graph=None):
    stars = arena.get("stars") or []
    if not stars:
        return []
    m = v1.arenas_module()
    if graph is None:
        graph = m.walk_graph(arena)
    cells, edges = graph
    if not arena.get("spawns"):
        return ["no spawns to reach the stars from"]
    first = m.spawn_cell(arena["spawns"][0])
    if first not in cells:
        return []
    live = m.reach(edges, first)
    cols = {}
    for (gx, gz, h) in live:
        cols.setdefault((gx, gz), []).append(h)
    faults = []
    for s in stars:
        if s["kind"] not in ("summit", "corner", "cave", "guarded", "lift", "ferry"):
            continue
        g = (int(math.floor(s["x"] / m.GRID)), int(math.floor(s["z"] / m.GRID)))
        foot = s["y"] - STAR_LIFT
        near = [h for dx in (-1, 0, 1) for dz in (-1, 0, 1)
                for h in cols.get((g[0] + dx, g[1] + dz), [])]
        if not any(abs(h - foot) <= 60 for h in near):
            faults.append("bonus star %d (%s) at (%d, %d, %d) cannot be walked to from spawn 1"
                          % (s["id"], s["kind"], s["x"], s["y"], s["z"]))
    return faults
MOVE_REACH = 1200
def move_unreached(arena, graph=None):
    stars = arena.get("stars") or []
    bad = check_stars(arena, graph)
    if not bad:
        return []
    m = v1.arenas_module()
    if graph is None:
        graph = m.walk_graph(arena)
    cells, edges = graph
    first = m.spawn_cell(arena["spawns"][0])
    if first not in cells:
        return []
    live = m.reach(edges, first)
    ids = set(int(f.split()[2]) for f in bad)
    notes = []
    for s in stars:
        if s["id"] not in ids or s["kind"] not in ("summit", "corner"):
            continue
        best = None
        for (gx, gz, h) in live:
            x, z = (gx + 0.5) * m.GRID, (gz + 0.5) * m.GRID
            d = math.hypot(x - s["x"], z - s["z"])
            if d > MOVE_REACH:
                continue
            key = (h, -d)
            if best is None or key > best[0]:
                best = (key, x, z, h)
        if best is None:
            continue
        _, x, z, h = best
        notes.append("bonus star %d (%s) moved %d to the top its climb reaches (%d)"
                     % (s["id"], s["kind"], math.hypot(x - s["x"], z - s["z"]), h))
        s["x"], s["z"], s["y"] = int(x), int(z), int(h + STAR_LIFT)
    return notes
SHORTCUT_WANT = {"shooter": ("unit", 2), "objective": ("unit", 2), "hide": ("map", 4)}
SHORTCUT_TRIES = 120
STEP_W = 400
def _copies(rect, sym):
    from .metrics import qd
    out = [rect]
    if sym == "turn4":
        r = rect
        for _ in range(3):
            r = qd._RECT_T["turn4"](r)
            out.append(r)
    elif sym in qd._RECT_T:
        out.append(qd._RECT_T[sym](rect))
    return out
def move_shortcuts(arena, brief, space, new_pieces, tex):
    want_kind = SHORTCUT_WANT.get(brief.get("family"))
    if not want_kind:
        return [], None
    from .metrics import fun, graph, qd
    from .metrics.world import World, Refused
    trial = dict(arena, pieces=space.standing(arena["pieces"]) + new_pieces)
    trial.setdefault("key", "generated")
    try:
        w = World(trial)
    except (Refused, KeyError, ValueError, IndexError):
        return [], None
    sym = qd.symmetry_of(trial)
    units = {"turn4": 4, "turn2": 2, "mirror_x": 2, "mirror_z": 2}.get(sym, 1)
    kind, per = want_kind
    wished = "move_shortcuts" in ((brief.get("features") or {}).get("want") or ())
    per = per + (1 if wished else 0)
    need = per * (units if kind == "unit" else 1)
    have = len(fun.shortcuts(w))
    if have >= need:
        return [], None
    nodes = w.nodes
    col = fun._columns(w)
    lo, hi = mario.JUMP_SAFE, mario.JUMP_TRIPLE
    cands = []
    seen = set()
    for u, (gx, gz, h) in enumerate(nodes):
        if not w.flat[u]:
            continue
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for v in col.get((gx + dx, gz + dz), ()):
                top = nodes[v][2]
                rise = top - h
                step_rise = min(hi, max(lo + 100, rise - lo))
                if not (step_rise < rise and rise - step_rise <= lo):
                    continue
                step = h + step_rise
                key = (gx // 4, gz // 4, dx, dz)
                if key in seen:
                    continue
                seen.add(key)
                cands.append((u, v, dx, dz, h, step))
    out, made = [], 0
    why = {"walk": 0, "room": 0, "faces": 0}
    rnd_order = sorted(cands, key=lambda c: (-(nodes[c[1]][2] - c[4]), c[0]))
    for u, v, dx, dz, h, step in rnd_order[:SHORTCUT_TRIES * (2 if wished else 1)]:
        if made * len(_copies((0, 1, 0, 1), sym)) + have >= need:
            break
        d = graph.bfs(w.radj, [v])[u]
        jump = fun.JUMP_S + 0.6 + mario.STARTUP / float(mario.FPS)
        if 0 <= d and mario.path_time_s(d) - jump < fun.SHORTCUT_S:
            why["walk"] += 1
            continue
        gx, gz, _ = nodes[u]
        cx, cz = (gx + .5) * mario.CELL, (gz + .5) * mario.CELL
        if dx:
            face = (gx + (1 if dx > 0 else 0)) * mario.CELL
            x0, x1 = (face - STEP_W, face) if dx > 0 else (face, face + STEP_W)
            z0 = int(round((cz - STEP_W / 2) / 100.0)) * 100
            rect = (x0, x1, z0, z0 + STEP_W)
        else:
            face = (gz + (1 if dz > 0 else 0)) * mario.CELL
            z0, z1 = (face - STEP_W, face) if dz > 0 else (face, face + STEP_W)
            x0 = int(round((cx - STEP_W / 2) / 100.0)) * 100
            rect = (x0, x0 + STEP_W, z0, z1)
        copies = _copies(rect, sym)
        if not all(space.free(r, margin=0, above=h) for r in copies):
            why["room"] += 1
            continue
        pieces = [_box(tex, r[0], r[1], h, step, r[2], r[3], "play.shortcut") for r in copies]
        check = dict(trial, pieces=trial["pieces"] + out + pieces)
        from . import solids
        if solids.faults(check, limit=5):
            why["faces"] += 1
            continue
        for r in copies:
            space.take(r, margin=0)
        out += pieces
        made += 1
    if not out:
        return [], ("approximated", "shortcuts", "the brief wants %d move-gated shortcuts, the map has "
                    "%d and no step fits beside its high ground (%d places: %d walked as "
                    "quick, %d without room, %d against another face)"
                    % (need, have, len(cands), why["walk"], why["room"], why["faces"]))
    after = dict(trial, pieces=trial["pieces"] + out)
    try:
        gained = len(fun.shortcuts(World(after))) - have
    except (Refused, KeyError, ValueError, IndexError):
        gained = 0
    if gained <= 0:
        for r in [_rect(p) for p in out]:
            if r in space.mine:
                space.mine.remove(r)
        return [], ("approximated", "shortcuts", "the brief wants %d move-gated shortcuts; the steps "
                    "tried opened none" % need)
    return out, ("placed", "shortcuts", "%d step block%s beside the high ground: a double or "
                 "triple jump up, a shortcut the walk takes longer for (%d -> %d)" % (
                     len(out), "" if len(out) == 1 else "s", have, have + gained))
