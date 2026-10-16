import math
from . import kit, values
from .layout import overlaps, rect_of
BACKDROP_GAP = 3000
BACKDROP_DROP = 600
FLOAT_ROCK = {"shape": "rock", "flat": False, "round": 2.2, "rough": 0.3}
ROOF_TOWER_MAX = 1200
REACH_UP = 800
REACH_NEAR = 1600
GATE_POST = 200
GATE_OPEN = 600
FRAME_CLEAR = 600
ROOFS = {"castle": "redbrick", "desert": "redbrick", "garden": "redbrick",
         "lava": "brickdarkgrey", "wood": "darkplanks", "ice": "stone2", "sky": "stone2"}
FAMILY_WANTS = {"party": ("backdrop",), "knockoff": ("backdrop",)}
def wanted(L, feature):
    f = L.brief.get("features") or {}
    if feature in (f.get("want") or ()):
        return True
    return feature in FAMILY_WANTS.get(getattr(L, "family", None), ()) \
        and feature not in (f.get("avoid") or ())
def avoided(L, feature):
    f = L.brief.get("features") or {}
    return feature in (f.get("avoid") or ())
def _gradient_of(tex, have):
    st = values.stats()
    if tex not in st:
        return None, None
    fam = [t for t in values.members(tex, have) if t not in values.NOT_WALL or t == tex]
    lt = st[tex][0]
    darker = [t for t in fam if 0.04 <= lt - st[t][0] <= 0.25]
    lighter = [t for t in fam if 0.04 <= st[t][0] - lt <= 0.25]
    d = max(darker, key=lambda t: st[t][0]) if darker else None
    li = min(lighter, key=lambda t: st[t][0]) if lighter else None
    return d, li
def gradient_walls(L, budget_left, notes):
    from .beauty import long_walls
    if avoided(L, "gradients"):
        return 0
    have = kit.textures()
    age = (kit.PALETTE_DNA.get("age") or 0) >= 0.6
    count = 6 if wanted(L, "gradients") else 3
    walls = sorted(long_walls(L.structure), key=lambda p: -max(p["w"], p["d"]))[:count]
    if getattr(L, "family", None) == "objective" and getattr(L, "sym", None) is not None:
        def same(a, b):
            return a["kind"] == b["kind"] and rect_of(a) == rect_of(b) and \
                a["y"] == b["y"] and a["h"] == b["h"] and a.get("tex") == b.get("tex")
        whole = []
        for p in walls:
            for c in L.sym.pieces(p):
                twin = next((q for q in L.structure if same(q, c)), None)
                if twin is not None and not any(twin is w for w in whole):
                    whole.append(twin)
        walls = whole
    added = 0
    for p in walls:
        where = L.structure
        if p["h"] < 600 or budget_left - added < 1:
            continue
        base = L.pal.get("wall_base")
        darker, lighter = _gradient_of(p["tex"], have)
        if age:
            worn = [t for t in kit.WORN if t in values.members(p["tex"], have)
                    and t != p["tex"]]
            if worn:
                darker = worn[0]
        base = base or darker
        if base is None or base == p["tex"]:
            continue
        cap = lighter if (p["h"] >= 800 and budget_left - added >= 2) else None
        i = where.index(p)
        y0, y1 = p["y"], p["y"] + p["h"]
        parts = [dict(p, h=200, tex=base, tag=str(p.get("tag", "")) + " base")]
        mid_top = y1 - (150 if cap else 0)
        parts.append(dict(p, y=y0 + 200, h=mid_top - y0 - 200))
        if cap:
            parts.append(dict(p, y=mid_top, h=150, tex=cap, tag=str(p.get("tag", "")) + " cap"))
        where[i:i + 1] = parts
        added += len(parts) - 1
    if added:
        notes.append("R13 gradient walls: %d mass(es) in base and cap courses (+%d pieces)"
                     % (len(walls), added))
    return added
def _free(L, piece, skip=()):
    r = rect_of(piece)
    y0, y1 = piece["y"], piece["y"] + piece["h"]
    for q in L.structure + L.top + L.fill + L.shields + L.dress:
        if q is piece or any(q is s_ for s_ in skip):
            continue
        if q["y"] < y1 and q["y"] + q["h"] > y0 and overlaps(r, rect_of(q)):
            return False
    return True
def stepped_keels(L, add):
    if L.solid:
        return 0
    have = kit.textures()
    n = 0
    for k in [p for p in L.dress if p.get("tag") == "dress.keel"]:
        x0, x1, z0, z1 = rect_of(k)
        if x1 - x0 < 1200 or z1 - z0 < 1200:
            continue
        darker, _ = _gradient_of(k["tex"], have)
        tex = darker or k["tex"]
        p = kit.kind("box").make(tex, int(x0 + 400), int(x1 - 400), k["y"] - 400, k["y"],
                                 int(z0 + 400), int(z1 - 400), None, "dress.keel2")
        if not _free(L, p):
            continue
        if add(p, "TECH stepped keels", copy=False):
            n += 1
    return n
def _play_rect(L):
    pieces = L.structure + L.top + L.fill + L.shields + L.dress
    if not pieces:
        return None
    rs = [rect_of(p) for p in pieces]
    return (min(r[0] for r in rs), max(r[1] for r in rs), min(r[2] for r in rs),
            max(r[3] for r in rs), min(p["y"] for p in pieces),
            max(p["y"] + p["h"] for p in pieces))
def backdrop(L, add, r):
    if L.solid:
        return 0, ("The Tiles: the level floor runs everywhere, a backdrop would be walked to "
                   "(it stands there only behind an invisible edge)")
    if avoided(L, "backdrop"):
        return 0, None
    from . import surround
    if getattr(L, "family", None) in surround.FAMILIES:
        return 0, None
    box = _play_rect(L)
    if box is None:
        return 0, None
    x0, x1, z0, z1, ylo, yhi = box
    floors = [f["y"] for f in L.floors] or [0]
    low = min(floors)
    n = r.choice((2, 3, 4)) + (2 if wanted(L, "backdrop") else 0)
    ma = __import__("mapgen.v1", fromlist=["v1"]).arenas_module()
    half = ma.LEVELS.get(L.brief["level"], {}).get("half", 17500) - 1500
    plane = ma.LEVELS.get(L.brief["level"], {}).get("plane", -6000)
    have = kit.textures()
    st = values.stats()
    keel = L.pal.get("keel") or L.pal.get("wall")
    fam = values.members(keel, have) if keel in have else []
    lighter = [t for t in fam if t in st and keel in st and st[t][0] > st[keel][0] + 0.08
               and t not in ("lava", "glassblock", "ice")]
    tex = lighter[-1] if lighter else ("frostedrock" if "frostedrock" in have else keel)
    cx = cz = 0.0
    rad = math.ceil(max(abs(x0), abs(x1), abs(z0), abs(z1)) / 1000.0) * 1000.0 + BACKDROP_GAP
    units = max(1, getattr(L.sym, "units", 1))
    per = max(1, int(round(n / float(units))))
    turn = r.random() * 360.0
    placed = 0
    for i in range(per):
        w = r.choice((1600, 2000, 2400))
        h = r.choice((800, 1200))
        top = low - BACKDROP_DROP - r.choice((0, 400, 800))
        for k in range(12):
            a = math.radians(turn + 360.0 * i / (per * units) + 30.0 * k)
            px = int(round((cx + math.sin(a) * (rad + w / 2)) / 200.0)) * 200
            pz = int(round((cz + math.cos(a) * (rad + w / 2)) / 200.0)) * 200
            if abs(px) + w / 2 > half or abs(pz) + w / 2 > half or top - h < plane + 1000:
                continue
            p = kit.kind("box").make(tex, px - w // 2, px + w // 2, top - h, top,
                                     pz - w // 2, pz + w // 2, None, "dress.backdrop")
            copies = L.sym.pieces(p)
            if not all(_free(L, c) for c in copies):
                continue
            rs = [rect_of(c) for c in copies]
            if any(overlaps(grow_rect(a_, 400), b_) for j, a_ in enumerate(rs) for b_ in rs[j + 1:]):
                continue
            if any(abs(c["x"]) + w / 2 > half or abs(c["z"]) + w / 2 > half for c in copies):
                continue
            if add(p, "C3 backdrop"):
                placed += len(copies)
            break
    return placed, None
def void_rocks(pieces, level):
    ma = __import__("mapgen.v1", fromlist=["v1"]).arenas_module()
    if ma.LEVELS.get(level, {}).get("floor", 0) is not None:
        return 0
    n = 0
    for p in pieces:
        if p.get("tag") == "dress.backdrop" and not p.get("sculpt"):
            p["sculpt"] = dict(FLOAT_ROCK, seed=1 + (abs(int(p["x"])) * 7
                                                     + abs(int(p["z"])) * 13) % 32749)
            n += 1
    return n
TILES_GAP = 3000
TILES_MARGIN = 500
def tiles_edge(pieces):
    from . import boundary
    m = __import__("mapgen.v1", fromlist=["v1"]).arenas_module()
    rs = [m.footprint(p)[:4] for p in pieces
          if p.get("kind") == "box" and boundary.is_invisible(p)]
    rs = [r for r in rs if min(r[1] - r[0], r[3] - r[2]) <= 400]
    if not rs:
        return None
    box = (min(r[0] for r in rs), max(r[1] for r in rs), min(r[2] for r in rs),
           max(r[3] for r in rs))
    def covered(spans, lo, hi):
        at = lo
        for a, b in sorted(spans):
            if a > at + 1:
                return False
            at = max(at, b)
        return at >= hi - 1
    x_sides = [[(r[2], r[3]) for r in rs if abs(r[k] - box[k]) < 1 and r[1] - r[0] <= 400]
               for k in (0, 1)]
    z_sides = [[(r[0], r[1]) for r in rs if abs(r[k] - box[k]) < 1 and r[3] - r[2] <= 400]
               for k in (2, 3)]
    ok = all(covered(sp + [(box[2], box[2] + 400), (box[3] - 400, box[3])], box[2], box[3])
             for sp in x_sides) and \
        all(covered(sp + [(box[0], box[0] + 400), (box[1] - 400, box[1])], box[0], box[1])
            for sp in z_sides)
    return box if ok and all(x_sides) and all(z_sides) else None
def _tiles_tex(pieces):
    have = kit.textures()
    st = values.stats()
    count = {}
    for p in pieces:
        t = p.get("tex")
        if t and t != "invisible" and p["h"] >= 400:
            count[t] = count.get(t, 0) + p["w"] * p["d"]
    walls = sorted(count, key=lambda t: (-count[t], t))
    for wall in walls[:3]:
        fam = values.members(wall, have) if wall in have else []
        lighter = [t for t in fam if t in st and wall in st and st[t][0] > st[wall][0] + 0.08
                   and t not in ("lava", "glassblock", "ice")]
        if lighter:
            return lighter[-1]
    return "frostedrock" if "frostedrock" in have else (walls[0] if walls else "stone1")
def tiles_backdrop(arena, brief, r):
    f = brief.get("features") or {}
    if "backdrop" in (f.get("avoid") or ()):
        return [], None
    if arena.get("level") != "empty":
        return [], None
    pieces = arena.get("pieces") or []
    if any(str(p.get("tag", "")).startswith("dress.backdrop") for p in pieces):
        return [], None
    box = tiles_edge(pieces)
    if box is None:
        return [], ("The Tiles: the level floor runs everywhere and no invisible edge keeps "
                    "players in, so a backdrop would be walked to")
    m = __import__("mapgen.v1", fromlist=["v1"]).arenas_module()
    lvl = m.LEVELS.get("empty", {})
    half = lvl.get("half", 15000) - TILES_MARGIN
    floor = lvl.get("floor", 0)
    wish = "backdrop" in (f.get("want") or ())
    used = (len(pieces) + len(arena.get("markers") or []) + len(arena.get("objects") or [])
            + len(arena.get("movers") or []))
    budget = int(arena.get("budget") or 0)
    if "budget" in (getattr(brief, "defaulted", ()) or ()):
        from . import budget as budgetmod
        budget = max(budget, budgetmod.ceiling(brief["family"], brief.get("modes") or
                                                arena.get("onlyFor") or ()))
    room = budget - used
    n = 8 if wish else 4
    if room < 4:
        return [], "the budget has no room for it (%d left)" % max(0, room)
    if room < n:
        n = 4
    w = r.choice((1600, 2000, 2400))
    h = r.choice((1200, 1600, 2000))
    tex = _tiles_tex(pieces)
    x0, x1, z0, z1 = box
    out = []
    spots = [(sx, sz) for sx in (-1, 1) for sz in (-1, 1)]
    if n == 8:
        spots += [(-1, 0), (1, 0), (0, -1), (0, 1)]
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    for sx, sz in spots:
        px = cx if sx == 0 else (x1 + TILES_GAP + w / 2.0 if sx > 0 else x0 - TILES_GAP - w / 2.0)
        pz = cz if sz == 0 else (z1 + TILES_GAP + w / 2.0 if sz > 0 else z0 - TILES_GAP - w / 2.0)
        px = int(round(px / 200.0)) * 200
        pz = int(round(pz / 200.0)) * 200
        if abs(px) + w / 2.0 > half or abs(pz) + w / 2.0 > half:
            return [], ("the map reaches within %d of The Tiles' edge: no room beyond its wall"
                        % (TILES_GAP + w))
        out.append(kit.kind("box").make(tex, px - w // 2, px + w // 2, floor, floor + h,
                                        pz - w // 2, pz + w // 2, None, "dress.backdrop tiles"))
    return out, None
def grow_rect(r, by):
    return (r[0] - by, r[1] + by, r[2] - by, r[3] + by)
def _unreached(pieces, p):
    x0, x1, z0, z1 = rect_of(p)
    top = p["y"] + p["h"]
    for q in pieces:
        if q is p:
            continue
        a0, a1, b0, b1 = rect_of(q)
        dx = max(0, a0 - x1, x0 - a1)
        dz = max(0, b0 - z1, z0 - b1)
        if math.hypot(dx, dz) <= REACH_NEAR and top - (q["y"] + q["h"]) <= REACH_UP \
                and (q["y"] + q["h"]) <= top + 1:
            if not str(q.get("tag", "")).startswith("centre.landmark"):
                return False
    return True
def roofs(L, add, theme):
    if avoided(L, "roofs"):
        return 0
    from .brief import dna
    if not wanted(L, "roofs") and "complexity" in (L.brief.get("dna") or {}) \
            and dna(L.brief, "complexity") < 0.3:
        return 0
    tex = ROOFS.get(theme, "redbrick")
    if tex not in kit.textures():
        tex = L.pal.get("ramp") or L.pal.get("wall")
    everything = L.structure + L.top + L.fill + L.shields + L.dress
    cands = [p for p in L.dress if p.get("tag") == "centre.landmark cap"]
    towers = [p for p in L.structure + L.top if p["kind"] == "box"
              and max(p["w"], p["d"]) <= ROOF_TOWER_MAX and p["w"] == p["d"]
              and p["h"] >= 600 and _unreached(everything, p)]
    limit = 4 if wanted(L, "roofs") else 2
    cands += sorted(towers, key=lambda p: -(p["y"] + p["h"]))[:limit]
    n = 0
    for p in cands:
        x0, x1, z0, z1 = rect_of(p)
        w = int(x1 - x0)
        if w != int(z1 - z0) or w > ROOF_TOWER_MAX:
            continue
        top = p["y"] + p["h"]
        live = L.structure + L.top + L.fill + L.shields + L.dress
        if any(q is not p and q["y"] >= top - 1 and q["y"] < top + w
               and overlaps((x0, x1, z0, z1), rect_of(q)) for q in live):
            continue
        on_landmark = str(p.get("tag", "")).startswith("centre.")
        roof = kit.kind("pyramid").make(tex, int(x0), int(x1), top, top + max(200, w * 3 // 4),
                                        int(z0), int(z1), None,
                                        "centre.landmark roof" if on_landmark else "dress.roof")
        copy = not on_landmark
        if not _free(L, roof) or not all(_free(L, c) for c in (L.sym.pieces(roof) if copy
                                                                 else [])):
            continue
        if add(roof, "C4 roofs", copy=copy):
            n += 1
    return n
def _origins(L):
    if L.bases:
        b = L.bases[0]
        x0, x1, z0, z1 = b["rect"]
        return [((x0 + x1) / 2.0, (z0 + z1) / 2.0, b["y"], max(x1 - x0, z1 - z0) / 2.0, True)]
    spawns = [s for s in (getattr(L, "arena_spawns", None) or L.spawns or [])
              if isinstance(s, dict)]
    if len(spawns) < 2:
        return []
    a, b = max(((s, t) for s in spawns for t in spawns),
               key=lambda st: math.hypot(st[0]["x"] - st[1]["x"], st[0]["z"] - st[1]["z"]))
    groups = ([], [])
    for s in spawns:
        da = math.hypot(s["x"] - a["x"], s["z"] - a["z"])
        db = math.hypot(s["x"] - b["x"], s["z"] - b["z"])
        groups[0 if da <= db else 1].append(s)
    out = []
    copy = getattr(L.sym, "units", 1) > 1
    for g in groups[:1] if copy else groups:
        s = min(g, key=lambda q: (math.hypot(q["x"], q["z"]), q["x"], q["z"]))
        out.append((s["x"], s["z"], s["y"], 200.0, copy))
    return out
def framing(L, add):
    if avoided(L, "arches") or avoided(L, "gate") or avoided(L, "framing"):
        return 0
    if L.family != "objective" and not wanted(L, "framing"):
        return 0
    n = 0
    world = L.structure + L.top + L.fill + L.shields + L.dress
    spots = [(s["x"], s["z"]) for s in (getattr(L, "arena_spawns", None) or L.spawns or [])
             if isinstance(s, dict)]
    for bx, bz, y, rad, copy in _origins(L):
        dx, dz = -bx, -bz
        d = math.hypot(dx, dz)
        if d < 1:
            continue
        dx, dz = dx / d, dz / d
        parts = None
        for out in range(int(rad + FRAME_CLEAR + 200), int(rad + 2600), 200):
            parts = _gate(L, bx + dx * out, bz + dz * out, y, abs(dz) >= abs(dx), spots, world)
            if parts:
                break
        if not parts:
            continue
        if add(parts, "C8 framing", copy=copy):
            n += len(parts)
    return n
def _gate(L, x, z, y, along_x, spots, world):
    gx, gz = int(round(x / 100.0)) * 100, int(round(z / 100.0)) * 100
    half = GATE_OPEN // 2 + GATE_POST
    span = (gx - half, gx + half, gz - 100, gz + 100) if along_x else \
        (gx - 100, gx + 100, gz - half, gz + half)
    corners = [(cx, cz) for cx in (span[0], span[1]) for cz in (span[2], span[3])]
    heights = sorted({f["y"] for f in L.floors if y - 450 <= f["y"] <= y + 20}, reverse=True)
    fy = None
    for h in heights:
        level = [f for f in L.floors if f["y"] == h]
        if all(any(f["rect"][0] <= cx <= f["rect"][1] and f["rect"][2] <= cz <= f["rect"][3]
                   for f in level) for cx, cz in corners):
            fy = h
            break
    if fy is None:
        return None
    if any(span[0] - 300 <= sx <= span[1] + 300 and span[2] - 300 <= sz <= span[3] + 300
           for sx, sz in spots):
        return None
    if any(overlaps(span, k) for k in L.keeps):
        return None
    tall = 800 if L.family in ("shooter", "objective") else 400
    tex = L.pal.get("trim") or L.pal.get("wall")
    if along_x:
        posts = [(span[0], span[0] + GATE_POST, span[2], span[3]),
                 (span[1] - GATE_POST, span[1], span[2], span[3])]
    else:
        posts = [(span[0], span[1], span[2], span[2] + GATE_POST),
                 (span[0], span[1], span[3] - GATE_POST, span[3])]
    parts = [kit.kind("pillar").make(tex, a, c, fy, fy + tall, e, f, None, "dress.gate post")
             for a, c, e, f in posts]
    parts.append(kit.kind("arch").make(tex, span[0], span[1], fy + tall, fy + tall + 200,
                                       span[2], span[3], None, "dress.gate arch"))
    if any(overlaps(rect_of(p), rect_of(q)) and q["y"] < p["y"] + p["h"]
           and q["y"] + q["h"] > p["y"] for p in parts for q in world):
        return None
    return parts
def dress(L, add, notes):
    r = L.streams("scenery")
    theme = L.brief["theme"]
    done = {}
    done["TECH stepped keels"] = stepped_keels(L, add)
    placed, why = backdrop(L, add, r)
    done["C3 backdrop"] = placed
    if why:
        notes.append("C3 backdrop: not built - %s" % why)
    done["C4 roofs"] = roofs(L, add, theme)
    done["C8 framing"] = framing(L, add)
    return {k: v for k, v in done.items() if v}
