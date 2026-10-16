from . import kit, movement, solids, v1
CUT_MAX = 0.25
APPROACH = 100
CLEAR = 400
DROP_RAILED = 300
JOIN_CELL = 200
SAMPLE = 50
WEDGES = ("ramp", "stairs")
EXEMPT_WORDS = ("jump", "kicker", "launch", "ski", "slide", "chute", "spring", "boost",
                "track", "kerb", "bank", "roof")
FLOAT_OK = ("backdrop", "water", "bridge", "cloud", "sky", "ceiling", "cave", "keel",
            "lantern", "lamp", "sign", "banner", "flag", "star", "island", "ring",
            "platform", "mover", "orbit")
def _m():
    return v1.arenas_module()
def _words(p):
    return set(str(p.get("tag", "")).lower().replace(".", " ").replace("_", " ").split())
class Index:
    def __init__(self, pieces, cell=400):
        self.cell = cell
        self.pieces = pieces
        self.rects = []
        self.grid = {}
        m = _m()
        for i, p in enumerate(pieces):
            x0, x1, z0, z1, _ = m.footprint(p)
            self.rects.append((x0, x1, z0, z1))
            for gx in range(int(x0 // cell), int(x1 // cell) + 1):
                for gz in range(int(z0 // cell), int(z1 // cell) + 1):
                    self.grid.setdefault((gx, gz), []).append(i)
    def near(self, x0, x1=None, z0=None, z1=None):
        if z0 is None:
            x, z = x0, x1
            x0 = x1 = x
            z0 = z1 = z
        out = set()
        c = self.cell
        for gx in range(int(x0 // c), int(x1 // c) + 1):
            for gz in range(int(z0 // c), int(z1 // c) + 1):
                out.update(self.grid.get((gx, gz), ()))
        return sorted(out)
def _solid(p):
    return p.get("kind") != "water"
def _probe(ix, level, x, z, h):
    m = _m()
    near = [ix.pieces[i] for i in ix.near(x, z) if _solid(ix.pieces[i])]
    hs = m.standable(near, x, z, level)
    stand = any(h - 30 <= s <= h + movement.STEP_MAX for s in hs)
    block = None
    for p in near:
        r = m.footprint(p)
        if not (r[0] < x < r[1] and r[2] < z < r[3]) or not m.covers(p, x, z):
            continue
        top = m.top_at(p, x, z)
        if top is None:
            continue
        if p["y"] < h + CLEAR and top > h + movement.STEP_MAX + 1:
            block = p
            break
    return stand, block
def _continues(ix, x, z, rises):
    m = _m()
    from .cells import wedge_descriptor
    for i in ix.near(x, z):
        p = ix.pieces[i]
        if p.get("kind") not in WEDGES:
            continue
        r = m.footprint(p)
        if r[0] - 1 <= x <= r[1] + 1 and r[2] - 1 <= z <= r[3] + 1 \
                and wedge_descriptor(p)[2] == rises:
            return True
    return False
def _side_exit(ix, level, axis, sign, edge, l0, l1, h, end):
    inward = -sign if end == "top" else sign
    along = edge + inward * APPROACH
    for lat in (l0 - APPROACH, l1 + APPROACH):
        x, z = _pt(axis, along, lat)
        stand, block = _probe(ix, level, x, z, h)
        if stand and block is None:
            return True
    return False
WORLD_FAMILIES = ("hide", "explore", "chase", "hunt")
def hard_rules(p, family):
    if p.get("kind") == "stairs" or family in WORLD_FAMILIES:
        return ("ST1", "ST2", "ST6")
    return ("ST1", "ST2")
def is_flight(p):
    if p.get("kind") not in WEDGES:
        return False
    ws = _words(p)
    if any(w.startswith(EXEMPT_WORDS) for w in ws):
        return False
    from . import contract
    return contract.family(kit.tex_key(p)) != "roof"
def _frame(p):
    from .cells import wedge_descriptor
    m = _m()
    x0, x1, z0, z1, _ = m.footprint(p)
    _, _, rises, lo, hi, y0, y1 = wedge_descriptor(p)
    axis = rises[1]
    sign = 1 if rises[0] == "+" else -1
    lat = (z0, z1) if axis == "x" else (x0, x1)
    return axis, sign, lo, hi, lat[0], lat[1], y0, y1, rises
def _pt(axis, along, lat):
    return (along, lat) if axis == "x" else (lat, along)
def reach_set(arena, graph=None):
    m = _m()
    try:
        cells, edges = graph if graph is not None else m.walk_graph(arena)
        first = m.spawn_cell(arena["spawns"][0])
    except Exception:
        return None
    if first not in cells:
        return None
    return m.reach(edges, first)
def _on_graph(reach, x, z, h):
    if reach is None:
        return True
    gx, gz = int(x // 100), int(z // 100)
    for (cx, cz, ch) in ((gx, gz, None), (gx + 1, gz, None), (gx - 1, gz, None),
                         (gx, gz + 1, None), (gx, gz - 1, None)):
        for dh in range(-30, 31):
            if (cx, cz, int(round(h)) + dh) in reach:
                return True
    return False
def flights(arena, reach=None, pieces=None):
    m = _m()
    pieces = arena["pieces"] if pieces is None else pieces
    level = arena["level"]
    ix = Index(pieces)
    floor = m.LEVELS[level]["floor"]
    out = []
    for p in pieces:
        if not is_flight(p):
            continue
        axis, sign, lo, hi, l0, l1, y0, y1, rises = _frame(p)
        if l1 - l0 < 100 or y1 - y0 < 50:
            continue
        lats = [l0 + (l1 - l0) * f for f in (0.25, 0.5, 0.75)]
        name = m.piece_name(p)
        perch = "perch" in _words(p)
        for end, edge, h, rule in (("foot", lo, y0, "ST1"), ("top", hi, y1, "ST2")):
            out_dir = -sign if end == "foot" else sign
            along = edge + out_dir * APPROACH
            bad, blocker, off = 0, None, 0
            for lat in lats:
                x, z = _pt(axis, along, lat)
                if _continues(ix, x, z, rises):
                    continue
                stand, block = _probe(ix, level, x, z, h)
                if block is not None and blocker is None:
                    blocker = block
                if not stand or block is not None:
                    bad += 1
                elif not _on_graph(reach, x, z, h) and not perch:
                    off += 1
            if bad and blocker is None and \
                    _side_exit(ix, level, axis, sign, edge, l0, l1, h, end):
                bad, blocker = 0, None
            if bad >= 2 or (blocker is not None and bad >= 1):
                what = ("starts at" if end == "foot" else "ends against") if blocker is not None \
                    else ("starts on nothing" if end == "foot" else "ends on nothing")
                out.append({"piece": p, "rule": rule, "blocker": blocker, "end": end,
                            "text": "%s: the %s %s %s%s - a flight needs a clear %s"
                            % (rule, p["kind"], name, what,
                               (" " + m.piece_name(blocker)) if blocker is not None else "",
                               "approach" if end == "foot" else "landing")})
            elif off >= 2:
                out.append({"piece": p, "rule": "ST3", "blocker": None, "end": end,
                            "text": "ST3: the %s %s - its %s is not on the walk graph"
                            % (p["kind"], name, "approach" if end == "foot" else "landing")})
        for side, lat in (("left", l0 - 40), ("right", l1 + 40)):
            opened = 0
            for t in (0.25, 0.5, 0.75):
                along = lo + (hi - lo) * t
                s = y0 + (y1 - y0) * t
                x, z = _pt(axis, along, lat)
                near = [pieces[i] for i in ix.near(x, z) if _solid(pieces[i])]
                walled = False
                best = floor if floor is not None else -10 ** 6
                for q in near:
                    r = m.footprint(q)
                    if not (r[0] < x < r[1] and r[2] < z < r[3]) or not m.covers(q, x, z):
                        continue
                    top = m.top_at(q, x, z)
                    if top is None:
                        continue
                    if top >= s + movement.STEP_MAX and q["y"] < s + 100:
                        walled = True
                        break
                    if top <= s + movement.STEP_MAX:
                        best = max(best, top)
                if not walled and s - best > DROP_RAILED:
                    opened += 1
            if opened >= 2:
                out.append({"piece": p, "rule": "ST6", "blocker": None, "side": side,
                            "lat": lat, "text": "ST6: the %s %s has an open drop over %d on its "
                            "%s side - a flight needs a cheek or a rail"
                            % (p["kind"], name, DROP_RAILED, side)})
    return out
def cheek(p, side):
    axis, sign, lo, hi, l0, l1, y0, y1, rises = _frame(p)
    a0, a1 = min(lo, hi), max(lo, hi)
    c0, c1 = (l0 - 100, l0) if side == "left" else (l1, l1 + 100)
    tag = str(p.get("tag") or "stair") + ".cheek"
    if "stair" not in tag:
        tag = "stair." + tag
    if axis == "x":
        return tag, (a0, a1, c0, c1)
    return tag, (c0, c1, a0, a1)
def cheeks(arena, issues, pieces=None, max_drop=1150):
    m = _m()
    pieces = arena["pieces"] if pieces is None else pieces
    ix = Index(pieces)
    floor = m.LEVELS[arena["level"]]["floor"]
    added = []
    for it in issues:
        if it["rule"] != "ST6":
            continue
        p = it["piece"]
        tag, (x0, x1, z0, z1) = cheek(p, it["side"])
        axis, sign, lo, hi, l0, l1, y0, y1, rises = _frame(p)
        base = floor if floor is not None else None
        clear = True
        for i in ix.near(x0, x1, z0, z1):
            q = pieces[i]
            if q is p or not _solid(q):
                continue
            r = ix.rects[i]
            if r[1] <= x0 or r[0] >= x1 or r[3] <= z0 or r[2] >= z1:
                continue
            top = q["y"] + q["h"]
            if top <= y1 and q["y"] < y1:
                base = top if base is None else max(base, top)
            if q["y"] < y1 and top > (base if base is not None else y0):
                if top > y1 or q.get("kind") not in ("box", "ice"):
                    clear = False
                    break
        if not clear or base is None or y1 - base < 50 or y1 - base > max_drop:
            continue
        piece = kit.kind("box").make(kit.tex_key(p), x0, x1, base, y1, z0, z1, None, tag)
        added.append(piece)
    return added
def functional(p):
    if p.get("kind") in WEDGES:
        return True
    ws = _words(p)
    return bool(ws & {"door", "bridge", "doorway", "gate"}) and p.get("kind") != "box" \
        or bool(ws & {"bridge"})
def _same(a, b):
    return all(a.get(k) == b.get(k) for k in ("kind", "x", "y", "z", "w", "h", "d", "yaw")) \
        and kit.tex_key(a) == kit.tex_key(b)
def function_cuts(before, after):
    m = _m()
    kept = {}
    for q in after:
        kept.setdefault((q.get("kind"), kit.tex_key(q)), []).append(q)
    ix = Index(after)
    out = []
    for p in before:
        if not functional(p):
            continue
        same = kept.get((p.get("kind"), kit.tex_key(p)), [])
        if any(_same(p, q) for q in same):
            continue
        x0, x1, z0, z1, _ = m.footprint(p)
        n = ok = 0
        sx = max(SAMPLE, (x1 - x0) / 8.0)
        sz = max(SAMPLE, (z1 - z0) / 8.0)
        x = x0 + sx / 2
        while x < x1:
            z = z0 + sz / 2
            while z < z1:
                t = m.top_at(p, x, z) if m.covers(p, x, z) else None
                if t is not None:
                    n += 1
                    for i in ix.near(x, z):
                        q = after[i]
                        if q.get("kind") != p.get("kind") or kit.tex_key(q) != kit.tex_key(p):
                            continue
                        r = ix.rects[i]
                        if not (r[0] <= x <= r[1] and r[2] <= z <= r[3]) or not m.covers(q, x, z):
                            continue
                        tq = m.top_at(q, x, z)
                        if tq is not None and abs(tq - t) <= 3:
                            ok += 1
                            break
                z += sz
            x += sx
        if n == 0:
            continue
        cut = 1.0 - ok / float(n)
        if cut > 0.01:
            out.append((p, round(cut, 3)))
    return out
def cut_faults(cuts):
    m = _m()
    return ["cut: solids.resolve took %d%% of the %s %s - a stair, ramp, door or bridge "
            "is never cut short silently (more than %d%% is a fault)"
            % (int(round(c * 100)), p.get("kind"), m.piece_name(p), int(CUT_MAX * 100))
            for p, c in cuts if c > CUT_MAX]
MEET = ("wall", "hedge", "maze", "pillar", "column", "post", "fence", "rail", "house",
        "cottage", "tower", "gate", "rampart", "crenel", "parapet", "edge", "rim")
def _meets(p):
    if p.get("kind") in ("pillar", "rail"):
        return True
    ws = _words(p)
    return any(w in ws or any(x.startswith(w) for x in ws) for w in MEET)
def joins(arena, pieces=None):
    import copy
    m = _m()
    pieces = copy.deepcopy(arena["pieces"] if pieces is None else pieces)
    try:
        m.connect(pieces)
    except Exception:
        pass
    cand = [i for i, p in enumerate(pieces) if _meets(p) and p.get("tex") != "invisible"
            and p.get("kind") != "water"]
    ix = Index(pieces)
    out = []
    seen = set()
    for i in cand:
        p = pieces[i]
        a = ix.rects[i]
        for j in ix.near(a[0] - JOIN_CELL, a[1] + JOIN_CELL, a[2] - JOIN_CELL, a[3] + JOIN_CELL):
            if j == i or (j, i) in seen or j not in cand:
                continue
            q = pieces[j]
            b = ix.rects[j]
            yo = min(p["y"] + p["h"], q["y"] + q["h"]) - max(p["y"], q["y"])
            if yo < 100:
                continue
            gx = max(a[0], b[0]) - min(a[1], b[1])
            gz = max(a[2], b[2]) - min(a[3], b[3])
            gap = None
            if gx > 0 and gz < -50:
                gap = gx
            elif gz > 0 and gx < -50:
                gap = gz
            elif gx <= 0 and gz <= 0 and "pillar" in (p.get("kind"), q.get("kind")) \
                    and (gx == 0 or gz == 0) and max(gx, gz) == 0 and min(gx, gz) < -50:
                pil, other = (p, q) if p.get("kind") == "pillar" else (q, p)
                if other.get("kind") in ("box", "ice") and not pil.get("join") \
                        and (gx == 0 or gz == 0):
                    gap = 40
            if gap is not None and 0 < gap < JOIN_CELL:
                seen.add((i, j))
                out.append({"a": p, "b": q, "gap": gap,
                            "text": "join: a %d gap between %s and %s - pieces that should "
                            "meet leave a slit under a cell" % (gap, m.piece_name(p),
                                                                 m.piece_name(q))})
    return out
def joinable(p):
    return (p.get("kind") == "pillar" and int(p["w"]) == 200 and int(p["d"]) == 200
            and int(p["h"]) % 200 == 0 and int(p["h"]) > 200 and p["x"] % 200 == 0
            and p["z"] % 200 == 0 and int(p.get("yaw", 0)) % 90 == 0)
def join_pillars(arena, pieces=None):
    pieces = arena["pieces"] if pieces is None else pieces
    want = set()
    for j in joins(arena, pieces):
        for p in (j["a"], j["b"]):
            if joinable(p) and j["gap"] == 40:
                want.add(_key(p))
    if not want:
        return pieces, 0
    out, n = [], 0
    for p in pieces:
        if _key(p) not in want:
            out.append(p)
            continue
        n += 1
        for k in range(int(p["h"]) // 200):
            q = dict(p, y=p["y"] + 200 * k, h=200, yaw=0)
            q.pop("model", None)
            out.append(q)
    return out, n
def _key(p):
    return tuple(p.get(k) for k in ("kind", "x", "y", "z", "w", "h", "d")) + (str(p.get("tex")),)
def _detail(p):
    t = str(p.get("tag", ""))
    return t.startswith(("dress.", "detail.")) or t.endswith(".cheek")
def floating(arena, pieces=None):
    m = _m()
    pieces = arena["pieces"] if pieces is None else pieces
    floor = m.LEVELS[arena["level"]]["floor"]
    ix = Index(pieces)
    n = len(pieces)
    use = [i for i, p in enumerate(pieces) if p.get("tex") != "invisible"]
    parent = list(range(n))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for i in use:
        p = pieces[i]
        a = ix.rects[i]
        for j in ix.near(a[0] - 3, a[1] + 3, a[2] - 3, a[3] + 3):
            if j <= i or pieces[j].get("tex") == "invisible":
                continue
            q = pieces[j]
            b = ix.rects[j]
            if b[0] > a[1] + 3 or b[1] < a[0] - 3 or b[2] > a[3] + 3 or b[3] < a[2] - 3:
                continue
            pt, qt = p["y"] + p["h"], q["y"] + q["h"]
            if q["y"] > pt + 3 or p["y"] > qt + 3:
                continue
            touch_x = min(a[1], b[1]) - max(a[0], b[0])
            touch_z = min(a[3], b[3]) - max(a[2], b[2])
            if touch_x < 0 and touch_z < 0:
                continue
            ri, rj = find(i), find(j)
            if ri != rj:
                parent[ri] = rj
    groups = {}
    for i in use:
        groups.setdefault(find(i), []).append(i)
    out = []
    for g, members in groups.items():
        ps = [pieces[i] for i in members]
        if floor is not None:
            if any(p["y"] <= floor + 12 for p in ps):
                continue
        elif not all(_detail(p) for p in ps):
            continue
        if all(any(w.startswith(FLOAT_OK) for w in _words(p)) or p.get("kind") == "water"
               for p in ps):
            continue
        out.append(ps)
    return out
HANGS = ("coin", "redcoin", "bluecoin", "1up", "star", "pickup", "ring", "balloon", "flag", "donut",
         "triblock")
def floating_objects(arena):
    m = _m()
    pieces = arena.get("pieces") or []
    ix = Index(pieces)
    out = []
    for o in arena.get("objects") or []:
        key = str(o.get("key") or o.get("what") or "")
        if key.startswith(HANGS) or o.get("pattern") == "pickups":
            continue
        near = [pieces[i] for i in ix.near(o["x"], o["z"]) if _solid(pieces[i])]
        hs = m.standable(near, o["x"], o["z"], arena["level"])
        if not any(abs(h - o["y"]) <= 30 for h in hs):
            out.append(o)
    return out
def unsupported(arena, pieces=None):
    m = _m()
    pieces = arena["pieces"] if pieces is None else pieces
    floor = m.LEVELS[arena["level"]]["floor"]
    ix = Index(pieces)
    out = []
    loose = set(id(q) for g in floating(arena, pieces) for q in g)
    for i, p in enumerate(pieces):
        if p.get("h", 0) <= 200 or p.get("tex") == "invisible" or not _solid(p):
            continue
        if id(p) in loose:
            continue
        if any(w.startswith(FLOAT_OK) for w in _words(p)):
            continue
        tag = str(p.get("tag", ""))
        if floor is None and not tag.startswith("play."):
            continue
        if floor is not None and p["y"] <= floor + 12:
            continue
        a = ix.rects[i]
        held = False
        for j in ix.near(a[0], a[1], a[2], a[3]):
            if j == i:
                continue
            q = pieces[j]
            b = ix.rects[j]
            if b[1] <= a[0] or b[0] >= a[1] or b[3] <= a[2] or b[2] >= a[3]:
                continue
            qt = q["y"] + q["h"]
            if abs(qt - p["y"]) <= 3 or (q["y"] < p["y"] < qt):
                held = True
                break
            if abs(q["y"] - (p["y"] + p["h"])) <= 3 and q.get("h", 0) >= 100:
                held = True
                break
        if not held:
            out.append(p)
    return out
def mover_faults(arena):
    from . import movers
    mv = arena.get("movers") or []
    if not mv:
        return []
    m = _m()
    boxes = [movers.swept_box(x) for x in mv]
    out = []
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            a, b = boxes[i], boxes[j]
            if a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3] \
                    and a[4] < b[5] and b[4] < a[5]:
                out.append((i, "movers: mover %d (%s) and mover %d (%s) sweep through each other"
                            % (i + 1, mv[i].get("key"), j + 1, mv[j].get("key"))))
    pieces = arena.get("pieces") or []
    ix = Index(pieces)
    for i, box in enumerate(boxes):
        for k in ix.near(box[0], box[1], box[4], box[5]):
            p = pieces[k]
            if not _solid(p) or p.get("tex") == "invisible":
                continue
            r = ix.rects[k]
            if r[0] < box[1] - 1 and box[0] + 1 < r[1] and r[2] < box[5] - 1 and box[4] + 1 < r[3] \
                    and p["y"] < box[3] - 1 and p["y"] + p["h"] > box[2] + 2:
                out.append((i, "movers: mover %d (%s) sweeps through %s"
                            % (i + 1, mv[i].get("key"), m.piece_name(p))))
                break
    return out
BLOB_SIDE = 400
BLOB_TALL = 300
BLOB_DEPTH = 100
SEAT = 200
def _root(p):
    return str(p.get("tag", "") or "").split(".")[0]
def _large(p):
    if p.get("tex") == "invisible" or not _solid(p):
        return False
    r = _m().footprint(p)
    return min(r[1] - r[0], r[3] - r[2]) >= BLOB_SIDE and p.get("h", 0) >= BLOB_TALL
def interpenetrations(pieces):
    big = [p for p in pieces if _large(p)]
    ix = Index(big)
    out = []
    for i, p in enumerate(big):
        a = ix.rects[i]
        for j in ix.near(a[0], a[1], a[2], a[3]):
            if j <= i:
                continue
            q = big[j]
            b = ix.rects[j]
            dx = min(a[1], b[1]) - max(a[0], b[0])
            dz = min(a[3], b[3]) - max(a[2], b[2])
            dy = min(p["y"] + p["h"], q["y"] + q["h"]) - max(p["y"], q["y"])
            if dx <= BLOB_DEPTH or dz <= BLOB_DEPTH or dy <= SEAT:
                continue
            if kit.tex_key(p) == kit.tex_key(q):
                continue
            if _root(p) and _root(p) == _root(q):
                continue
            if solids.concentric(p, q):
                continue
            out.append((p, q, (dx, dy, dz)))
    return out
def interpenetration_faults(pieces):
    m = _m()
    return ["overlap: %s and %s are pushed into one another (%d x %d x %d shared) - large "
            "pieces meet flush or seated, never as a blob" % (
                m.piece_name(p), m.piece_name(q), d[0], d[1], d[2])
            for p, q, d in interpenetrations(pieces)]
LAVA_DESIGNED = ("lava", "lake", "river", "volcano", "crater", "flow", "hazard", "moat")
LAVA_REACH = 250
def _lava_under(ix, pieces, x, y, z):
    for i in ix.near(x, z):
        p = pieces[i]
        if p.get("kind") not in kit.HAZARD_KINDS:
            continue
        r = ix.rects[i]
        if r[0] <= x <= r[1] and r[2] <= z <= r[3]:
            top = p["y"] + p["h"]
            if top - 10 <= y <= top + LAVA_REACH:
                return p
    return None
def lava_faults(arena):
    pieces = arena.get("pieces") or []
    if not any(p.get("kind") in kit.HAZARD_KINDS for p in pieces):
        return [], []
    m = _m()
    ix = Index(pieces)
    hard = []
    for k, sp in enumerate(arena.get("spawns") or []):
        p = _lava_under(ix, pieces, sp["x"], sp.get("y", 0), sp["z"])
        if p is not None:
            hard.append("lava: spawn %d stands on %s (lava burns)" % (k + 1, m.piece_name(p)))
    for st in arena.get("stars") or []:
        p = _lava_under(ix, pieces, st["x"], st.get("y", 0), st["z"])
        if p is not None:
            hard.append("lava: star %s waits over %s (lava burns)" % (st.get("id"),
                                                                     m.piece_name(p)))
    for o in arena.get("objects") or []:
        key = str(o.get("key") or o.get("what") or "")
        if key.startswith(HANGS) or o.get("pattern") == "pickups":
            continue
        p = _lava_under(ix, pieces, o["x"], o.get("y", 0), o["z"])
        if p is not None:
            hard.append("lava: the object %s stands on %s (lava burns)" % (key, m.piece_name(p)))
    soft = ["lava: %s is lava as decoration (no lake, river, crater or flow) - it burns"
            % m.piece_name(p) for p in pieces
            if p.get("kind") in kit.HAZARD_KINDS and not (_words(p) & set(LAVA_DESIGNED))]
    return hard, soft
def floating_faults(arena, pieces=None):
    m = _m()
    return ["floating: %s%s rests on nothing (the support graph: no piece below, beside or "
            "above it stands)" % (m.piece_name(g[0]), " and %d more" % (len(g) - 1)
                                  if len(g) > 1 else "")
            for g in floating(arena, pieces)]
def pockets(arena, pieces=None):
    from . import landform
    pieces = arena["pieces"] if pieces is None else pieces
    try:
        got = landform.pockets([p for p in pieces if p.get("kind") != "water"])
    except Exception:
        return []
    halls = [pk.get("box") for pk in arena.get("pockets") or () if isinstance(pk, dict)
             and len(pk.get("box") or ()) == 6]
    return [pt for pt in got if not any(b[0] - 1 <= pt[0] <= b[1] + 1 and b[2] - 1 <= pt[1] <= b[3] + 1
                                        and b[4] - 1 <= pt[2] <= b[5] + 1 for b in halls)]
LIP_LOW, LIP_HIGH = 20, 200
LANE_MIN = 400
def lips(pieces, detail):
    m = _m()
    ix = Index(pieces)
    out = []
    for d in detail:
        r = m.footprint(d)
        cx, cz = (r[0] + r[1]) / 2.0, (r[2] + r[3]) / 2.0
        under = None
        for i in ix.near(r[0], r[1], r[2], r[3]):
            q = pieces[i]
            if q is d:
                continue
            if abs(q["y"] + q["h"] - d["y"]) <= 2:
                rr = ix.rects[i]
                if rr[0] <= cx <= rr[1] and rr[2] <= cz <= rr[3]:
                    under = q
                    break
        rise = d["h"]
        if under is not None and _covers_top(d, _m().footprint(under)[:4]):
            under = None
        if under is not None and LIP_LOW < rise < LIP_HIGH:
            out.append({"piece": d, "rise": rise,
                        "text": "G1 lip: %s is a %d step on a walked floor (a lip is <= %d or "
                        ">= %d)" % (m.piece_name(d), rise, LIP_LOW, LIP_HIGH)})
    return out
def _covers_top(d, r):
    if r is None:
        return False
    a = _m().footprint(d)
    return a[0] <= r[0] + 1 and a[1] >= r[1] - 1 and a[2] <= r[2] + 1 and a[3] >= r[3] - 1
def chimneys(pieces, detail):
    m = _m()
    ix = Index(pieces)
    lo, hi = movement.CHIMNEY_MIN, movement.CHIMNEY_MAX
    out = []
    for d in detail:
        if d.get("h", 0) < 300:
            continue
        a = m.footprint(d)
        for i in ix.near(a[0] - hi, a[1] + hi, a[2] - hi, a[3] + hi):
            q = pieces[i]
            if q is d or q.get("h", 0) < 300 or q.get("kind") == "water":
                continue
            b = ix.rects[i]
            yo = min(d["y"] + d["h"], q["y"] + q["h"]) - max(d["y"], q["y"])
            if yo < 300:
                continue
            gx = max(a[0], b[0]) - min(a[1], b[1])
            gz = max(a[2], b[2]) - min(a[3], b[3])
            gap = gx if (gx > 0 and gz < -100) else gz if (gz > 0 and gx < -100) else None
            if gap is not None and lo <= gap <= hi:
                out.append({"piece": d, "other": q, "gap": gap,
                            "text": "G4 chimney: %s and %s face each other %d apart (a wall-kick "
                            "ladder, %d-%d)" % (m.piece_name(d), m.piece_name(q), gap, lo, hi)})
                break
    return out
def narrows(pieces, detail, lane_min=LANE_MIN):
    m = _m()
    ix = Index(pieces)
    out = []
    for d in detail:
        a = m.footprint(d)
        for i in ix.near(a[0] - lane_min, a[1] + lane_min, a[2] - lane_min, a[3] + lane_min):
            q = pieces[i]
            if q is d or q.get("kind") == "water" or q.get("tex") == "invisible":
                continue
            b = ix.rects[i]
            yo = min(d["y"] + d["h"], q["y"] + q["h"]) - max(d["y"], q["y"])
            if yo < movement.TALL:
                continue
            gx = max(a[0], b[0]) - min(a[1], b[1])
            gz = max(a[2], b[2]) - min(a[3], b[3])
            gap = gx if (gx > 0 and gz < 0) else gz if (gz > 0 and gx < 0) else None
            if gap is not None and movement.CORRIDOR_MIN <= gap < lane_min:
                out.append({"piece": d, "other": q, "gap": gap,
                            "text": "G7 lane: %s leaves %d to %s (a lane is never narrowed under "
                            "%d)" % (m.piece_name(d), gap, m.piece_name(q), lane_min)})
                break
    return out
def detail_of(pieces):
    return [p for p in pieces if str(p.get("tag", "")).startswith(("dress.", "detail."))
            or str(p.get("tag", "")).endswith(".cheek")]
def movement_issues(arena, detail=None):
    pieces = arena["pieces"]
    detail = detail_of(pieces) if detail is None else detail
    if not detail:
        return []
    return lips(pieces, detail) + chimneys(pieces, detail) + narrows(pieces, detail)
def prop_solid_faults(arena):
    from . import decor
    out, seen = [], set()
    for p in arena.get("pieces") or []:
        key = p.get("decor")
        if not key or key in seen or key not in decor.BY_KEY:
            continue
        seen.add(key)
        bad = decor.unsolid_parts(decor.BY_KEY[key])
        if bad:
            out.append("prop %s: Mario walks through %s" % (key, "; ".join(
                "part %d (%s)" % (i, why) for i, why in bad)))
    return out
def gate(arena, theme=None, graph=None, cuts=None, family=None, raw=None):
    from . import contract
    faults, warns = [], []
    counts = {}
    iss = contract.issues(arena, theme)
    hard = [i["text"] for i in iss if i["refused"]]
    counts["contract_refused"] = len(hard)
    counts["contract_warn"] = len(iss) - len(hard)
    faults += hard
    warns += [i["text"] for i in iss if not i["refused"]][:20]
    cf = cut_faults(cuts or [])
    counts["cuts"] = len(cf)
    faults += cf
    reach = reach_set(arena, graph)
    family = family or arena.get("family")
    fl = flights(arena, reach)
    hard_fl = [f for f in fl if f["rule"] in hard_rules(f["piece"], family)]
    soft_fl = [f for f in fl if f not in hard_fl]
    counts["stairs"] = len(hard_fl)
    counts["stairs_soft"] = len(soft_fl)
    faults += [f["text"] for f in hard_fl]
    warns += [f["text"] for f in soft_fl][:20]
    fg = floating_faults(arena)
    fo = floating_objects(arena)
    fu = unsupported(arena)
    m = _m()
    fg += ["floating: the object %s at (%d, %d, %d) stands on nothing"
           % (o.get("key"), o["x"], o["y"], o["z"]) for o in fo]
    fg += ["floating: %s stands on nothing (nothing under its foot holds it up)"
           % m.piece_name(p) for p in fu]
    counts["floating"] = len(fg)
    faults += fg
    mvf = mover_faults(arena)
    counts["movers"] = len(mvf)
    faults += [t for _, t in mvf]
    of = interpenetration_faults(arena["pieces"] if raw is None else raw)
    counts["overlaps"] = len(of)
    faults += of
    lh, ls = lava_faults(arena)
    counts["lava"] = len(lh)
    counts["lava_decor"] = len(ls)
    faults += lh
    warns += ls[:10]
    ps_ = prop_solid_faults(arena)
    counts["prop_solids"] = len(ps_)
    faults += ps_
    pk = pockets(arena)
    counts["pockets"] = len(pk)
    faults += ["pocket: a floor sealed inside a mass at (%d, %d, %d) - only a clip reaches it"
               % p for p in pk]
    jn = joins(arena)
    counts["joins"] = len(jn)
    warns += [j["text"] for j in jn[:20]]
    mv = movement_issues(arena)
    counts["movement"] = len(mv)
    warns += [x["text"] for x in mv[:20]]
    return {"faults": faults, "warns": warns, "counts": counts, "flights": fl}
