import math
from . import kit, v1
WHAT = {"caves": "cave", "cave": "cave", "grotto": "cave", "water": "lake", "lake": "lake",
        "pond": "lake", "pool": "lake", "tower": "tower", "towers": "tower",
        "watchtower": "tower", "castle": "castle", "keep": "castle", "fortress": "castle",
        "house": "house", "houses": "house", "hut": "house", "buildings": "house",
        "temple": "house"}
OF = {"waterfall": "waterfall", "castle": "castle", "keep": "castle", "fortress": "castle",
      "tower": "tower", "towers": "tower", "watchtower": "tower", "lighthouse": "tower",
      "lake": "lake", "water": "lake", "pond": "lake", "river": "lake", "bridge": "bridge",
      "bridges": "bridge", "cave": "cave", "caves": "cave", "mountain": "mountain",
      "mountains": "mountain", "hill": "mountain", "terrain": "mountain", "house": "house",
      "houses": "house", "village": "house", "spire": "tower", "landmark": "castle"}
RELATIONS = ("behind", "in_front_of", "next_to", "on", "under", "inside", "near")
REL_ALIAS = {"on_top_of": "on", "above": "on", "below": "under", "beneath": "under",
             "beside": "next_to", "in_front": "in_front_of", "in": "inside", "near": "next_to",
             "opposite": "behind", "around": "next_to", "along": "next_to"}
LANDMARK_TAGS = {
    "waterfall": ("waterfall",),
    "lake": ("lake", "pond", "pool", "river", "water"),
    "bridge": ("bridge", "causeway"),
    "tower": ("tower", "spire", "lighthouse", "watchtower", "perch", "obelisk"),
    "cave": ("cave",),
    "mountain": ("summit", "hills", "terrace", "mountain", "volcano", "crown"),
    "house": ("house", "village", "cottage", "settlement", "outpost"),
    "castle": ("castle", "keep", "fort", "bastion", "castlewall"),
}
MAIN_BUILDING = ("castle", "keep", "fort", "landmark", "spire", "gate", "prefab", "tower",
                 "house", "outpost", "bastion")
NOT_LANDMARK = ("edge", "dress.backdrop", "boundary", "invisible", "decor", "tree",
                "path", "play.", "place.")
GAP = 300
FOOT = {"cave": (1200, 1200), "lake": (1600, 1600), "tower": (1200, 1300),
        "castle": (1700, 2000), "house": (1200, 1200)}
FOOT_SMALLER = {"lake": ((1200, 1200), (1000, 1000))}
CLEARS = ("scatter.", "tree", "flora.", "detail.")
def norm_what(w):
    return WHAT.get(str(w or "").lower())
def norm_of(o):
    return OF.get(str(o or "").lower())
def norm_rel(r):
    r = str(r or "").lower()
    r = REL_ALIAS.get(r, r)
    return r if r in RELATIONS else None
def _foot(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw", 0))) % 180 == 90:
        w, d = d, w
    return (p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0)
def _clusters(pieces, gap=400):
    groups = []
    for p in pieces:
        f = _foot(p)
        hit = [g for g in groups if g["box"][0] - gap < f[1] and f[0] < g["box"][1] + gap
               and g["box"][2] - gap < f[3] and f[2] < g["box"][3] + gap]
        box = list(f)
        members = [p]
        for g in hit:
            groups.remove(g)
            members += g["pieces"]
            box = [min(box[0], g["box"][0]), max(box[1], g["box"][1]),
                   min(box[2], g["box"][2]), max(box[3], g["box"][3])]
        groups.append({"pieces": members, "box": box})
    for g in groups:
        g["top"] = max(p["y"] + p["h"] for p in g["pieces"])
        g["base"] = min(p["y"] for p in g["pieces"])
    return groups
def _tagged(arena, words):
    out = []
    for p in arena["pieces"]:
        tag = str(p.get("tag", "")).lower()
        if any(tag.startswith(n) or ("." + n) in tag for n in NOT_LANDMARK):
            if not any(w in tag for w in ("waterfall", "cave", "lake")):
                continue
        if p.get("tex") == "invisible":
            continue
        if any(w in tag for w in words) or ("water" in words and p.get("kind") == "water"):
            out.append(p)
    return out
def locate(arena, of):
    of = norm_of(of) or of
    words = LANDMARK_TAGS.get(of)
    main = False
    found = _tagged(arena, words) if words else []
    if not found and of == "castle":
        found = _tagged(arena, MAIN_BUILDING)
        main = True
    if not found:
        return None
    groups = _clusters(found)
    tall = of in ("castle", "tower", "mountain", "house")
    g = max(groups, key=lambda g: ((g["top"] if tall else 0) + len(g["pieces"]) * 10,
                                   -abs(g["box"][0]) - abs(g["box"][2])))
    b = g["box"]
    return {"box": b, "top": g["top"], "base": g["base"], "main": main,
            "centre": ((b[0] + b[1]) / 2.0, (b[2] + b[3]) / 2.0), "pieces": g["pieces"]}
def viewer(arena):
    w = arena.get("world") or (arena.get("survey") or {}).get("world")
    if isinstance(w, dict) and "x" in w:
        return (w["x"], w["z"])
    if arena.get("spawns"):
        s = arena["spawns"][0]
        return (s["x"], s["z"])
    return (0.0, 0.0)
def ideal(land, rel, size, view):
    b = land["box"]
    cx, cz = land["centre"]
    rx, rz = (b[1] - b[0]) / 2.0, (b[3] - b[2]) / 2.0
    dx, dz = cx - view[0], cz - view[1]
    n = math.hypot(dx, dz) or 1.0
    dx, dz = dx / n, dz / n
    reach = max(rx, rz) + GAP + max(size) / 2.0
    def along(x, z):
        return (x - cx) * dx + (z - cz) * dz
    def across(x, z):
        return -(x - cx) * dz + (z - cz) * dx
    if rel == "behind":
        return (cx + dx * reach, cz + dz * reach, (-dx, -dz),
                lambda x, z: along(x, z) > 0.3 * reach)
    if rel == "in_front_of":
        return (cx - dx * reach, cz - dz * reach, (dx, dz),
                lambda x, z: along(x, z) < -0.3 * reach)
    if rel == "next_to":
        return (cx - dz * reach, cz + dx * reach, (dz, -dx),
                lambda x, z: abs(across(x, z)) > 0.3 * reach
                and abs(along(x, z)) < reach)
    if rel in ("on", "inside", "under"):
        return (cx, cz, (-dx, -dz), lambda x, z: b[0] <= x <= b[1] and b[2] <= z <= b[3])
    return (cx + dx * reach, cz + dz * reach, (-dx, -dz), lambda x, z: True)
def _clear(arena, rect, y, height, cleared=None):
    g = (rect[0] - 100, rect[1] + 100, rect[2] - 100, rect[3] + 100)
    for p in arena["pieces"]:
        if p.get("tex") == "invisible" and str(p.get("tag", "")).startswith("edge"):
            f = _foot(p)
            if f[0] < g[1] and g[0] < f[1] and f[2] < g[3] and g[2] < f[3]:
                return False
            continue
        f = _foot(p)
        if f[0] < g[1] and g[0] < f[1] and f[2] < g[3] and g[2] < f[3]:
            if p["y"] + p["h"] > y + 10 and p["y"] < y + height:
                if cleared is not None and str(p.get("tag", "")).startswith(CLEARS):
                    cleared.append(p)
                    continue
                return False
    return True
def spot(arena, land, rel, what, size=None, cleared_out=None):
    from . import place
    size = size or FOOT[what]
    m = v1.arenas_module()
    view = viewer(arena)
    ix, iz, face, ok = ideal(land, rel, size, view)
    pts = place.standing_points(arena)
    flat = {}
    for x, y, z, _ in pts:
        flat.setdefault((int(round(x)), int(round(z))), set()).add(int(round(y)))
    height = {"cave": 1000, "lake": 300, "tower": 3200, "castle": 3200, "house": 2400}[what]
    hw, hd = size[0] / 2.0, size[1] / 2.0
    cands = []
    for x, y, z, _ in pts:
        if not ok(x, z):
            continue
        if rel == "on" and y < land["base"] + 150:
            continue
        if rel == "under" and y > land["base"] - 200:
            continue
        if rel == "inside" and y > land["base"] + 60:
            continue
        key = (-y if rel == "on" else 0, math.hypot(x - ix, z - iz))
        cands.append(key + (x, y, z))
    cands.sort()
    for _, _, x, y, z in cands[:600]:
        rect = (x - hw, x + hw, z - hd, z + hd)
        corners = [(x + sx * (hw - 100), z + sz * (hd - 100)) for sx in (-1, 1) for sz in (-1, 1)]
        if not all(any(abs(fy - y) <= 10 for fy in _near(flat, cx, cz))
                   or any(abs(fy - y) <= 10 for fy in m.standable(arena["pieces"], cx, cz,
                                                                   arena.get("level")))
                   for cx, cz in corners):
            continue
        cleared = []
        if not _clear(arena, rect, y, height, cleared):
            continue
        if cleared_out is not None:
            cleared_out.extend(cleared)
        return (x, y, z, face)
    return None
def _near(flat, x, z):
    for k in ((int(round(x)), int(round(z))),
              (int(round(x / 200.0) * 200 + 100), int(round(z / 200.0) * 200 + 100))):
        if k in flat:
            return flat[k]
    best = None
    for (fx, fz), ys in flat.items():
        d = abs(fx - x) + abs(fz - z)
        if d <= 200 and (best is None or d < best[0]):
            best = (d, ys)
    return best[1] if best else ()
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    p = kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, tag)
    p["model"] = v1.arenas_module().model_name(p)
    return p
def _turn(pts_rect, face, x, z):
    x0, x1, z0, z1 = pts_rect
    fx, fz = face
    if abs(fx) >= abs(fz):
        q = 1 if fx > 0 else 3
    else:
        q = 2 if fz > 0 else 0
    corners = [(x0, z0), (x1, z1)]
    out = []
    for cx, cz in corners:
        for _ in range(q):
            cx, cz = -cz, cx
        out.append((cx, cz))
    return (x + min(p[0] for p in out), x + max(p[0] for p in out),
            z + min(p[1] for p in out), z + max(p[1] for p in out))
def build_cave(x, y, z, face, tex, hidden=False):
    parts = [(-600, -400, -600, 600, "place.cave.wall"), (400, 600, -600, 600, "place.cave.wall"),
             (-400, 400, 400, 600, "place.cave.back")]
    out = []
    for x0, x1, z0, z1, tag in parts:
        r = _turn((x0, x1, z0, z1), face, x, z)
        out.append(_box(tex, r[0], r[1], y, y + 600, r[2], r[3], tag))
    out.append(_box(tex, x - 600, x + 600, y + 600, y + 800, z - 600, z + 600, "place.cave.roof"))
    return out
def build_lake(x, y, z, face, tex, hidden=False, size=(1600, 1600)):
    a, b = size[0] // 2, size[1] // 2
    out = [_box(tex, x - a, x + a, y, y + 100, z - b, z - b + 200, "place.lake.rim"),
           _box(tex, x - a, x + a, y, y + 100, z + b - 200, z + b, "place.lake.rim"),
           _box(tex, x - a, x - a + 200, y, y + 100, z - b + 200, z + b - 200, "place.lake.rim"),
           _box(tex, x + a - 200, x + a, y, y + 100, z - b + 200, z + b - 200, "place.lake.rim")]
    w = kit.kind("water").make("watersurface", x - a + 200, x + a - 200, y, y + 80,
                               z - b + 200, z + b - 200, None, "place.lake.water")
    w["model"] = v1.arenas_module().model_name(w)
    out.append(w)
    return out
def _house_style(theme):
    import random
    from . import beauty, houses
    pal, _ = beauty.palette(theme)
    return houses, houses.style_for(theme, pal, random.Random(7), "shooter")
def _face_name(face):
    fx, fz = face
    if abs(fx) >= abs(fz):
        return "e" if fx > 0 else "w"
    return "s" if fz > 0 else "n"
def build_tower(x, y, z, face, tex, hidden=False, theme="castle"):
    import random
    from . import outposts
    houses, st = _house_style(theme)
    b = outposts.watchtower(st, random.Random(7), "place.tower")
    return houses.place(b, x, z, y, _face_name(face))
def build_castle(x, y, z, face, tex, hidden=False, theme="castle"):
    import random
    from . import outposts
    houses, st = _house_style(theme)
    b = outposts.make("bunker", st, random.Random(7), "place.castle")
    if b is None:
        b = outposts.watchtower(st, random.Random(7), "place.castle")
    return houses.place(b, x, z, y, _face_name(face))
def build_house(x, y, z, face, tex, hidden=False, theme="castle"):
    import random
    from . import outposts
    houses, st = _house_style(theme)
    b = outposts.make("shed", st, random.Random(7), "place.house", small=True)
    return houses.place(b, x, z, y, _face_name(face))
BUILDERS = {"cave": build_cave, "lake": build_lake, "tower": build_tower,
            "castle": build_castle, "house": build_house}
def _tex_of(land, arena):
    from collections import Counter
    pool = [p for p in land["pieces"] if p.get("kind") != "water" and p.get("tex") != "invisible"]
    if not pool:
        pool = [p for p in arena["pieces"] if p.get("kind") == "box"
                and p.get("tex") not in ("invisible",)]
    c = Counter(p["tex"] for p in pool if p.get("tex"))
    return c.most_common(1)[0][0] if c else "stone1"
def said(q):
    return "%s%s %s the %s" % ("a hidden " if q.get("hidden") else "a ", norm_what(q.get("what"))
                               or q.get("what"), str(q.get("relation")).replace("_", " "),
                               norm_of(q.get("of")) or q.get("of"))
def answer(arena, q, theme="castle", budget=None):
    what, rel, of = norm_what(q.get("what")), norm_rel(q.get("relation")), q.get("of")
    if what not in BUILDERS:
        return False, "%s: no builder places a %s next to something yet" % (said(q), q.get("what"))
    if rel is None:
        return False, "%s: the place word is not one this pass knows" % said(q)
    if what == "cave" and norm_of(of) == "waterfall" and rel in ("behind", "inside", "under") \
            and any(str(p.get("tag", "")).startswith("setpiece.grotto")
                    for p in arena.get("pieces") or ()):
        return True, "placed: %s - the grotto behind the falling water" % said(q)
    land = locate(arena, of)
    if land is None:
        return False, "%s: this map has no %s to place it by" % (said(q), norm_of(of) or of)
    cleared = []
    at = spot(arena, land, rel, what, cleared_out=cleared)
    if at is None and rel in ("under", "inside"):
        at = spot(arena, land, "behind" if rel == "inside" else "next_to", what,
                  cleared_out=cleared)
    size = FOOT[what]
    for smaller in FOOT_SMALLER.get(what, ()):
        if at is not None:
            break
        size = smaller
        at = spot(arena, land, rel, what, size=smaller, cleared_out=cleared)
    if at is None:
        return False, "%s: no flat, free ground on that side of the %s" % (said(q), norm_of(of))
    x, y, z, face = at
    x, z = int(round(x / 50.0) * 50), int(round(z / 50.0) * 50)
    tex = _tex_of(land, arena)
    fn = BUILDERS[what]
    kw = {"hidden": bool(q.get("hidden"))}
    if what in ("tower", "castle", "house"):
        kw["theme"] = theme
    if size != FOOT[what]:
        kw["size"] = size
    try:
        new = fn(x, int(round(y)), z, face, tex, **kw)
    except Exception as why:
        return False, "%s: could not be built (%s)" % (said(q), why)
    if not new:
        return False, "%s: could not be built here" % said(q)
    used = (len(arena["pieces"]) + len(arena.get("markers", [])) + len(arena.get("objects") or [])
            + len(arena.get("movers") or []))
    if budget is not None and used + len(new) > budget:
        return False, "%s: the map's piece budget has no room for its %d pieces" % (
            said(q), len(new))
    before, had = list(arena["pieces"]), arena.get("budget")
    gone = set(id(p) for p in cleared)
    arena["pieces"] = [p for p in before if id(p) not in gone] + new
    arena["budget"] = max(had or 0, used + len(new))
    faults = v1.arenas_module().check_layout(arena)
    if faults:
        arena["pieces"], arena["budget"] = before, had
        return False, "%s: the safety check refused it here (%s)" % (said(q), faults[0])
    where = "the %s%s" % (norm_of(of), " (the map's main building)" if land["main"] else "")
    return True, "placed: %s - at (%d, %d), by %s" % (said(q), x, z, where)
def apply(arena, brief):
    reqs = brief["requests"] if hasattr(brief, "__getitem__") else []
    theme = brief["theme"] if brief["theme"] not in (None, "auto") else "castle"
    from . import budget as budgetmod
    if "budget" in (getattr(brief, "defaulted", ()) or ()):
        top = budgetmod.ceiling(brief["family"], brief["modes"] or arena.get("onlyFor") or ())
    else:
        top = brief["budget"]
    done, lines = [], []
    for i, q in enumerate(reqs or []):
        if q.get("kind") != "place":
            continue
        ok, line = answer(arena, q, theme, budget=max(top, arena.get("budget") or 0))
        lines.append(line)
        if ok:
            done.append(i)
    return done, lines
