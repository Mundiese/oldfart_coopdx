import math
from .. import kit, v1
from ..skeleton import Graph, Zone
from .objective import finish, palette, q, weighted
from .knockoff import shape_boxes
FAMILY = "party"
DEFAULTS = {"symmetry": "turn4", "sides": "ffa", "verticality": "flat",
            "density": "sparse", "edge": "void", "level": "empty2", "theme": "sky"}
MODES = ("bombsaway", "bumperballs", "blizzard", "bombxing", "booksquirm", "hotrope",
         "lavaleave", "spots", "blast", "deflect", "chompfever", "sleep", "glassbridge",
         "hexheat", "hexagone", "turf")
DEFAULT_MODES = ("bombsaway", "bumperballs", "blizzard", "bombxing", "booksquirm", "hotrope",
                 "lavaleave", "spots")
AREA_PER_PLAYER = 320000
FILL = {"square": 1.0, "octagon": 0.83, "round": 0.80, "cross": 0.74}
LAYER_GAP = 500
FLAT_PLATE_MODES = ("turf",)
ONE_FLOOR_MODES = ("turf", "glassbridge")
def across_for(players, shape, factor):
    area = players * AREA_PER_PLAYER * factor * factor
    return max(1200, q(math.sqrt(area / FILL[shape]), 200))
def platform_graph(safety, layers):
    g = Graph()
    dirs = ((0, 1), (1, 0), (0, -1), (-1, 0))
    for qd, (x, z) in enumerate(dirs):
        g.add(Zone("island_%d" % qd, "centre", qd, x, z))
    g.loop(["island_%d" % qd for qd in range(4)], "the island round")
    if safety:
        for qd, (x, z) in enumerate(dirs):
            g.add(Zone("safety_%d" % qd, "field", qd, 2 * x, 2 * z))
        g.loop(["safety_%d" % qd for qd in range(4)], "the safety tier round")
        for qd in range(4):
            g.loop(["island_%d" % qd, "safety_%d" % qd, "safety_%d" % ((qd + 1) % 4),
                    "island_%d" % ((qd + 1) % 4)], "fall and climb back (%d)" % qd)
    return g
def spawn_ring(island, a, level, notes):
    m = v1.arenas_module()
    def stands(x, z):
        return 0 in m.standable(island, x, z, level)
    grid = [(x, z) for x in range(-a + 150, a, 100) for z in range(-a + 150, a, 100)
            if stands(x, z)]
    cands = []
    for margin in (300, 200, 100, 0):
        cands = [(x, z) for x, z in grid
                 if all(stands(x + dx, z + dz) for dx, dz in
                        ((margin, 0), (-margin, 0), (0, margin), (0, -margin)))] \
            if margin else list(grid)
        if len(cands) >= 40:
            break
    if margin < 300:
        notes.append("spawns: the island is small for sixteen starts; they keep %d from the "
                     "edge" % margin)
    chosen = [(0, 0)]
    best = {c: math.hypot(*c) for c in cands}
    while len(chosen) < 16 and best:
        c = max(sorted(best), key=lambda k: best[k])
        chosen.append(c)
        del best[c]
        for k in best:
            best[k] = min(best[k], math.hypot(k[0] - c[0], k[1] - c[1]))
    gap = min(math.hypot(p[0] - r[0], p[1] - r[1]) for i, p in enumerate(chosen)
              for r in chosen[i + 1:])
    if gap < 300:
        notes.append("spawns: sixteen starts stand %d apart on this island" % gap)
    return [{"x": x, "y": 0, "z": z,
             "yaw": round(math.degrees(math.atan2(-x, -z))) % 360 if (x or z) else 0}
            for x, z in chosen]
def pattern_boxes(pattern, a, pal, m, y0=-100, y1=0):
    if pattern == "quarters":
        acc = pal["accents"]
        return [m.box(acc[0], -a, 0, y0, y1, -a, 0, "island"), m.box(acc[1], 0, a, y0, y1, -a, 0, "island"),
                m.box(acc[2], 0, a, y0, y1, 0, a, "island"), m.box(acc[3], -a, 0, y0, y1, 0, a, "island")]
    if pattern == "checker":
        n = 4
        step = 2 * a / float(n)
        out = []
        for i in range(n):
            for j in range(n):
                tex = pal["floor"] if (i + j) % 2 == 0 else pal["deck"]
                out.append(m.box(tex, -a + i * step, -a + (i + 1) * step, y0, y1,
                                 -a + j * step, -a + (j + 1) * step, "island"))
        return out
    if pattern == "bands":
        b = 400
        acc = pal["accents"][0]
        return [m.box(pal["floor"], -a + b, a - b, y0, y1, -a + b, a - b, "island"),
                m.box(acc, -a, a, y0, y1, -a, -a + b, "island"),
                m.box(acc, -a, a, y0, y1, a - b, a, "island"),
                m.box(acc, -a, -a + b, y0, y1, -a + b, a - b, "island"),
                m.box(acc, a - b, a, y0, y1, -a + b, a - b, "island")]
    return [m.box(pal["floor"], -a, a, y0, y1, -a, a, "island")]
def layer_links(a, tops, pal, m):
    out = []
    for li in range(1, len(tops)):
        lo, hi = tops[li], tops[li - 1]
        run = 2 * (hi - lo)
        unit = [m.ramp(pal["ramp"], a, a + run, -600, 0, lo, hi, "+x", "layer ramp"),
                m.box(pal["deck"], a + run, a + run + 600, hi - 100, hi, -600, 600, "layer landing"),
                m.box(pal["bridge"], a, a + run, hi - 100, hi, 0, 600, "layer bridge")]
        face = (li - 1) % 2
        for qd in (face, face + 2):
            out += [m.turned(p, qd) for p in unit]
    return out
def build(brief, streams, reference=False):
    from ..brief import SIZES
    m = v1.arenas_module()
    from ..kitpass import diagonals_on
    diag = diagonals_on(brief)
    notes, lines = [], []
    want = set(brief["features"]["want"])
    modes = set(brief["modes"])
    symmetry = brief["symmetry"]
    if symmetry not in ("turn4",):
        notes.append("symmetry %s: a party island is built turn4 (every start the same distance "
                     "from every edge)" % symmetry)
        symmetry = "turn4"
    size = brief["size"]
    factor = SIZES[size] if isinstance(size, str) else 1.0
    pal, pal_notes = palette(brief["theme"], brief["palette"])
    notes += pal_notes
    r = streams("frame")
    P = {}
    shapes = [("square", 3), ("octagon", 3), ("round", 2)]
    if brief["players"] >= 12:
        shapes.append(("cross", 1))
    P["shape"] = weighted(r, shapes)
    if modes & set(FLAT_PLATE_MODES):
        P["shape"] = "square"
        notes.append("mode turf: a square plate (the grid of tiles is drawn over one flat floor)")
    P["A"] = across_for(brief["players"], P["shape"], factor)
    if isinstance(size, dict) and "across" in size:
        P["A"] = q(float(size["across"]), 200)
    from .. import venuejudge
    ring_modes = [mm for mm in (modes or DEFAULT_MODES) if mm in venuejudge.RING_WIDEST]
    need = max([venuejudge.RING_WIDEST[mm] for mm in ring_modes] or [0]) + venuejudge.RING_MARGIN
    if ring_modes and P["A"] < need:
        P["A"] = -(-need // 200) * 200
        notes.append("the plate is %d across: the widest ring of %s and 400 to spare each side"
                     % (P["A"], "/".join(sorted(ring_modes))))
    if ring_modes and P["shape"] == "cross":
        P["shape"] = "octagon"
    a = P["A"] // 2
    P["pattern"] = weighted(r, [("plain", 2), ("quarters", 2), ("checker", 2), ("bands", 1)]) \
        if P["shape"] == "square" else "plain"
    if modes & set(FLAT_PLATE_MODES):
        P["pattern"] = "plain"
    vert = brief["verticality"]
    P["layers"] = 3 if (vert == "high" or modes & {"hexheat", "hexagone"}) else 1
    P["safety"] = vert in ("low", "medium") and P["layers"] == 1
    if modes & set(ONE_FLOOR_MODES):
        if P["layers"] > 1 or P["safety"]:
            notes.append("modes %s: one floor (no stacked floors, no safety tier)"
                         % "/".join(sorted(modes & set(ONE_FLOOR_MODES))))
        P["layers"], P["safety"] = 1, False
    edge = brief["edge"] if brief["edge"] != "auto" else "void"
    if "rails" in want:
        edge = "rails"
    P["edge"] = edge
    lift = 1200 if brief["level"] == "empty" else 0
    if lift:
        notes.append("level empty (The Tiles): the island stands 1200 up so a fall is a fall")
    pieces = []
    tops = [0] if P["layers"] == 1 else [0, -LAYER_GAP, -2 * LAYER_GAP]
    for li, top in enumerate(tops):
        if P["shape"] == "square":
            floor = pattern_boxes(P["pattern"] if li == 0 else "plain", a, pal, m, top - 100, top)
        else:
            floor = shape_boxes(P["shape"], a, top - 100, top,
                                pal["floor"] if li == 0 else pal["deck"], "island", m, diag)
        if li:
            for p in floor:
                p["tag"] = "layer%d" % (li + 1)
        pieces += floor
    if P["pattern"] in ("plain", "quarters", "bands") and not modes & set(FLAT_PLATE_MODES):
        from ..kitpass import octagon_pieces
        mh = max(400, q(a * (0.55 if P["pattern"] == "quarters" else 0.4), 100))
        tex = pal["floor"] if P["pattern"] == "quarters" else pal.get("deck")
        if tex and (P["pattern"] == "quarters" or tex != pal["floor"]):
            pieces += octagon_pieces(tex, mh, tops[0] - 100, tops[0], "island medallion")
            P["medallion"] = mh
    bottom = tops[-1] - 100
    if P["layers"] > 1:
        pieces += layer_links(a, tops, pal, m)
        symmetry = "turn2"
    if P["safety"]:
        s = a + 1000
        y = -400
        sh = P["shape"] if P["shape"] != "cross" else "square"
        pieces += shape_boxes(sh, s, y - 100, y, pal["deck"], "safety tier", m, diag)
        pieces += shape_boxes(P["shape"], a, y - 100, -100, pal["keel"], "island body", m, diag)
        ramp = m.ramp(pal["ramp"], -300, 300, a, a + 800, y, 0, "-z", "safety ramp")
        for qd in range(4):
            pieces.append(m.turned(ramp, qd))
        bottom = y - 100
    if P["edge"] in ("rails", "walled") and P["layers"] == 1:
        h = 160 if P["edge"] == "rails" else 400
        if P["shape"] == "square":
            side = [m.rail(pal["trim"], -a, a, a - 60, a, 0, h, "edge rail")] if h == 160 else \
                [m.box(pal["wall"], -a, a, 0, h, a - 100, a, "edge wall")]
            for qd in range(4):
                pieces += [m.turned(p, qd) for p in side]
        else:
            notes.append("edge %s: only a square island takes rails or walls in this kit (the "
                         "slanted faces have no railing piece)" % P["edge"])
    k1 = q(a * 0.6, 100)
    pieces.append(m.box(pal["keel"], -k1, k1, bottom - 500, bottom, -k1, k1, "keel"))
    island = [p for p in pieces if p.get("tag") == "island"]
    spawns = spawn_ring(island, a, "empty2", notes)
    for an in brief["anchors"]:
        what = an["what"]
        comp = an["where"].get("compass")
        if what in ("centre", "world_spawn", "plaza", "spawn", "spawns") and comp in (None, "c"):
            lines.append(("placed", an["id"], "%s: the island's middle" % what))
        elif what in ("spawn", "spawns"):
            lines.append(("approximated", an["id"], "spawns stay a ring round the middle (every "
                          "start the same distance from the edge)"))
        else:
            lines.append(("refused", an["id"], "%s: a party island carries nothing but its floor "
                          "(the round brings the hazards)" % what))
    centre = {"x": 0, "y": 0, "z": 0, "yaw": 0}
    arena = {"key": brief["key"] or "generated", "level": brief["level"],
             "budget": brief["budget"], "pieces": pieces, "spawns": spawns,
             "survey": {"musicalSpot": dict(centre), "ring": dict(centre),
                        "points": [dict(s) for s in spawns]},
             "marks": [{"x": 0, "z": 0, "label": "centre"}],
             "look": kit.look(brief["theme"], brief["sky"], brief["music"])}
    finish(arena, lift)
    asked = [mm for mm in brief["modes"] if mm in MODES]
    arena["onlyFor"] = asked or list(DEFAULT_MODES)
    arena["blurb"] = "a generated party island sized for %d players" % brief["players"]
    arena["note"] = ("a flat %s island %d across%s%s, nothing on it but its floor"
                     % (P["shape"] if P["shape"] != "cross" else "cross-shaped", P["A"],
                        " (%s floor)" % P["pattern"] if P["pattern"] != "plain" else "",
                        ", three stacked floors" if P["layers"] > 1 else
                        ", a safety tier below" if P["safety"] else ""))
    graph = platform_graph(P["safety"], P["layers"])
    params = dict(P, centre="island", lane=P["shape"], corner=P["pattern"], shield="-", I=a, G=0, B=0, Dh=0, Ph=0)
    meta = {"params": params, "units": 4, "symmetry": symmetry,
            "modules": {"island": P["shape"], "pattern": P["pattern"], "layers": P["layers"],
                        "safety": P["safety"], "edge": P["edge"]},
            "anchors": lines, "notes": notes, "graph_faults": graph.faults(),
            "graph": {"zones": sorted(graph.zones), "loops": graph.loops},
            "centre": (0, 0), "field_spots": 0, "cover": 0, "module_pieces": {},
            "bases": [[(s["x"], s["y"], s["z"]) for s in spawns]], "family": FAMILY}
    return arena, meta
