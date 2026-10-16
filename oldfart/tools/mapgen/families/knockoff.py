import math
from .. import kit, v1
from ..skeleton import Graph, Zone
from .objective import finish, palette, q, weighted
FAMILY = "knockoff"
DEFAULTS = {"symmetry": "turn4", "sides": "ffa", "verticality": "low",
            "density": "sparse", "edge": "void", "level": "empty2", "theme": "lava"}
MODES = ("sumo", "smash", "bumperballs", "chompfever", "deflect", "laststanding",
         "hotpotato", "logroll")
TIER_DROP = 300
RING_TEX = {"lava": "sand", "desert": "sand", "castle": "tile2", "ice": "ice",
            "sky": "whitemarble", "wood": "woodenplank1", "garden": "grass"}
def ring_radius(players, factor, r):
    if players >= 12:
        lo, hi = 1200, 1500
    elif players >= 6:
        lo, hi = 900, 1200
    else:
        lo, hi = 800, 900
    return max(800, min(1800, q(r.uniform(lo, hi) * factor, 100)))
def shape_boxes(shape, a, y0, y1, tex, tag, m, diagonal=False):
    if shape == "octagon" and diagonal:
        from ..kitpass import octagon_pieces
        return octagon_pieces(tex, a, y0, y1, tag)
    if shape == "square":
        return [m.box(tex, -a, a, y0, y1, -a, a, tag)]
    if shape == "cross":
        b = q(a * 0.55, 100)
        return [m.box(tex, -a, a, y0, y1, -b, b, tag), m.box(tex, -b, b, y0, y1, -a, a, tag),
                m.box(tex, -q(a * 0.8), q(a * 0.8), y0, y1, -q(a * 0.8), q(a * 0.8), tag)]
    if shape == "round":
        c1 = q(a * math.cos(math.radians(22.5)) * 0.42, 100)
        out = [m.box(tex, -a, a, y0, y1, -q(a * 0.38), q(a * 0.38), tag),
               m.box(tex, -q(a * 0.38), q(a * 0.38), y0, y1, -a, a, tag),
               m.box(tex, -q(a * 0.83), q(a * 0.83), y0, y1, -q(a * 0.62), q(a * 0.62), tag),
               m.box(tex, -q(a * 0.62), q(a * 0.62), y0, y1, -q(a * 0.83), q(a * 0.83), tag)]
        del c1
        return out
    b = q(a * 0.414, 100)
    c = q(a * 0.707, 100)
    return [m.box(tex, -a, a, y0, y1, -b, b, tag), m.box(tex, -b, b, y0, y1, -a, a, tag),
            m.box(tex, -c, c, y0, y1, -c, c, tag)]
def ring_graph(tiers, platforms):
    g = Graph()
    dirs = ((0, 1), (1, 0), (0, -1), (-1, 0))
    for t in range(1, tiers + 1):
        for qd, (x, z) in enumerate(dirs):
            g.add(Zone("tier%d_%d" % (t, qd), "centre" if t == 1 else "field", qd,
                       x * t, z * t))
        g.loop(["tier%d_%d" % (t, qd) for qd in range(4)],
               "the ring round" if t == 1 else "tier %d round" % t)
    for t in range(2, tiers + 1):
        for qd in range(4):
            a, b = "tier%d_%d" % (t, qd), "tier%d_%d" % (t, (qd + 1) % 4)
            g.loop(["tier%d_%d" % (t - 1, qd), a, b, "tier%d_%d" % (t - 1, (qd + 1) % 4)],
                   "ramps up from tier %d (%d)" % (t, qd))
    for qd in range(platforms):
        g.add(Zone("platform%d" % qd, "corner", qd, 0, 0))
        g.loop(["tier1_%d" % qd, "platform%d" % qd, "tier1_%d" % ((qd + 1) % 4)],
               "jump up, drop off")
    return g
def build(brief, streams, reference=False):
    from ..brief import SIZES
    m = v1.arenas_module()
    from ..kitpass import diagonals_on
    diag = diagonals_on(brief)
    notes, lines = [], []
    want, avoid = set(brief["features"]["want"]), set(brief["features"]["avoid"])
    modes = set(brief["modes"])
    symmetry = brief["symmetry"]
    if symmetry not in ("turn4",):
        if symmetry == "turn8":
            notes.append("symmetry turn8: the ring is eight-sided, its ramps four (quarter "
                         "turns only in the kit)")
        elif symmetry != "auto":
            notes.append("symmetry %s: a knock-off ring is built turn4 (every start the same "
                         "distance from every edge)" % symmetry)
        symmetry = "turn4"
    size = brief["size"]
    factor = SIZES[size] if isinstance(size, str) else 1.0
    pal, pal_notes = palette(brief["theme"], brief["palette"])
    notes += pal_notes
    r = streams("frame")
    P = {}
    P["R"] = ring_radius(brief["players"], factor, r)
    if isinstance(size, dict) and "across" in size:
        P["R"] = max(800, min(1800, q(float(size["across"]) / 2 / 2.2, 100)))
    vert = brief["verticality"]
    P["tiers"] = {"flat": 1, "low": weighted(r, [(2, 3), (3, 2)]), "medium": 3, "high": 3}[vert]
    if modes & {"bumperballs"}:
        P["tiers"] = min(P["tiers"], 2)
    P["band2"] = r.choice((700, 800, 900, 1000))
    wish = str(brief.get("wish") or "").lower()
    P["rim"] = "crumbly" if (modes & {"bumperballs"} or any(
        w in wish for w in ("crumb", "bröck", "brock", "broken", "ragged"))) else "solid"
    if modes & {"bumperballs"}:
        P["R"] = min(P["R"], 1400)
        P["band2"] = min(P["band2"], 800)
    P["shape"] = weighted(r, [("octagon", 4), ("round", 3), ("square", 1), ("cross", 1)])
    if "round" in wish:
        P["shape"] = "round"
    from .. import venuejudge
    ring_modes = [mm for mm in (["sumo"] + sorted(modes)) if mm in venuejudge.RING_WIDEST
                  and mm != "bumperballs"]
    need = (max([venuejudge.RING_WIDEST[mm] for mm in ring_modes] or [0])
            + venuejudge.RING_MARGIN) // 2
    if P["R"] < need and not (isinstance(size, dict) and "across" in size) \
            and "bumperballs" not in modes:
        P["R"] = min(2600, -(-need // 100) * 100)
        notes.append("the ring is %d across: the widest ring of %s and 400 to spare"
                     % (2 * P["R"], "/".join(ring_modes)))
    if ring_modes and P["shape"] == "cross":
        P["shape"] = "octagon"
    P["shape2"] = weighted(r, [("octagon", 3), ("round", 2), ("square", 1)])
    if P["shape"] == "square":
        P["shape2"] = "square"
    P["ramp_w"] = r.choice((600, 600, 800))
    P["ramp_off"] = weighted(r, [(0, 3), (1, 2)])
    P["outer"] = weighted(r, [("slabs", 3), ("band", 1)])
    P["platforms"] = 4 if (modes & {"smash"} or "perches" in want) else 0
    if "perches" in avoid:
        P["platforms"] = 0
    P["Ph"] = r.choice((300, 350, 400))
    P["marks"] = "sumo" in modes or not modes
    R, B2 = P["R"], P["band2"]
    R2 = R + B2
    R3 = R2 + 1000 if P["tiers"] >= 3 else R2
    if R3 > 3500:
        P["tiers"] = 2
        R3 = R2
        notes.append("tier 3 left out: the floor would pass 7000 across")
    P["R2"], P["R3"] = R2, R3
    lift = 1200 if brief["level"] == "empty" else 0
    if lift:
        notes.append("level empty (The Tiles): the ring stands 1200 up so a fall is a fall")
    ring_tex = RING_TEX.get(brief["theme"], pal["floor"])
    if brief["palette"] and brief["palette"].get("floor"):
        ring_tex = pal["floor"]
    if kit.layered(ring_tex):
        ring_tex = kit.TRANSITION_BASE.get(ring_tex, "sand")
    tier_tex = pal["deck"] if pal["deck"] != ring_tex else pal["floor"]
    pieces = []
    if P["rim"] == "crumbly":
        P["shape"], P["ramp_off"] = "square", 0
        core = R - 400
        pieces += shape_boxes("square", core, -TIER_DROP, 0, ring_tex, "ring", m)
        mid = (-P["ramp_w"] // 2 - 200, P["ramp_w"] // 2 + 200)
        cuts = [(-core, mid[0] - 200), mid, (mid[1] + 200, core)]
        for qd in range(4):
            for i, (a0, a1) in enumerate(cuts):
                if a1 - a0 < 200:
                    continue
                depth = 400 if i == 1 else 300
                slab = m.box(ring_tex, a0, a1, -TIER_DROP, 0, core, core + depth, "ring rim")
                pieces.append(m.turned(slab, qd))
    else:
        pieces += shape_boxes(P["shape"], R, -TIER_DROP, 0, ring_tex, "ring", m, diag)
    if P["tiers"] >= 2:
        pieces += shape_boxes(P["shape2"], R2, -2 * TIER_DROP - 200, -TIER_DROP, tier_tex,
                              "tier2", m, diag)
    rw = P["ramp_w"]
    off = 0 if not P["ramp_off"] else q(R * 0.35, 100)
    quarter = []
    if P["tiers"] >= 2:
        quarter.append(m.ramp(pal["ramp"], off - rw // 2, off + rw // 2, R, R + 2 * TIER_DROP,
                              -TIER_DROP, 0, "-z", "ring ramp"))
    if P["tiers"] >= 3:
        y3 = -2 * TIER_DROP
        if P["outer"] == "band":
            quarter.append(None)
        else:
            fs = q(R2 * 0.5, 100)
            quarter.append(m.box(pal["keel"], -fs, fs, y3 - 200, y3, R2, R3, "outer slab"))
            c0, c1 = q(R2 * 0.72, 100), R3 - 200
            quarter.append(m.box(pal["keel"], c0, c1, y3 - 200, y3, c0, c1, "outer slab"))
            pz0, pz1 = q((R2 + R3) / 2.0 - 100, 100), q((R2 + R3) / 2.0 + 100, 100)
            if fs < c0:
                quarter.append(m.box(pal["bridge"], fs, c0, y3 - 100, y3, pz0, pz1, "plank"))
        quarter.append(m.ramp(pal["ramp"], -off - rw // 2, -off + rw // 2, R2, R2 + 2 * TIER_DROP,
                              y3, -TIER_DROP, "-z", "outer ramp"))
    quarter = [p for p in quarter if p is not None]
    for qd in range(4):
        for p in quarter:
            pieces.append(m.turned(p, qd))
    if P["tiers"] >= 3 and P["outer"] == "band":
        pieces[:0] = shape_boxes(P["shape2"], R3, -2 * TIER_DROP - 200, -2 * TIER_DROP,
                                 pal["keel"], "outer band", m, diag)
    elif P["tiers"] >= 3:
        extra = []
        for p in pieces:
            if p.get("tag") == "plank":
                mirrored = dict(p)
                mirrored["x"], mirrored["z"] = p["z"], p["x"]
                mirrored["w"], mirrored["d"] = p["d"], p["w"]
                extra.append(mirrored)
        pieces += extra
    low = -2 * TIER_DROP - 200 if P["tiers"] >= 2 else -TIER_DROP
    k1 = q(min(R2, R) * 0.6 if P["tiers"] >= 2 else R * 0.6, 100)
    pieces.append(m.box(pal["keel"], -k1, k1, low - 500, low, -k1, k1, "keel"))
    if P["marks"]:
        for x0 in (-q(R * 0.3, 100) - 200, q(R * 0.3, 100)):
            pieces.append(m.box(pal["accents"][2] if len(pal["accents"]) > 2 else "carpet",
                                x0, x0 + 200, -100, 0, -100, 100, "mark"))
    plat = []
    if P["platforms"]:
        pr = q(R * 0.55, 100)
        for qd in range(4):
            p = m.box(pal["deck"], -300, 300, P["Ph"] - 100, P["Ph"], pr - 300, pr + 300,
                      "platform")
            plat.append(m.turned(p, qd))
        pieces += plat
    if "rails" in want:
        e = P["R3"]
        y = -2 * TIER_DROP if P["tiers"] >= 3 else (-TIER_DROP if P["tiers"] == 2 else 0)
        edge = [m.rail(pal["trim"], -e + 400, e - 400, e - 60, e, y, 160, "edge rail")]
        for qd in range(4):
            pieces += [m.turned(p, qd) for p in edge]
        lines.append(("approximated", "rails", "rails on the outermost edge only"))
    spawns = [{"x": 0, "y": 0, "z": 0, "yaw": 0}]
    rr = max(600, q(R * 0.62, 50))
    level = brief["level"] if brief["level"] == "empty2" else "empty2"
    for i in range(15):
        a = 2 * math.pi * i / 15.0
        for r_try in range(rr, 299, -25):
            x, z = q(r_try * math.sin(a), 25), q(r_try * math.cos(a), 25)
            if 0 in m.standable([p for p in pieces if p["tag"] == "ring"], x, z, level):
                break
        yaw = round(math.degrees(math.atan2(-x, -z))) % 360
        spawns.append({"x": x, "y": 0, "z": z, "yaw": yaw})
    for a in brief["anchors"]:
        what = a["what"]
        comp = a["where"].get("compass")
        if what in ("centre", "world_spawn", "pit", "plaza") and comp in (None, "c"):
            lines.append(("placed", a["id"], "%s: the ring's middle, at the origin" % what))
        elif what in ("world_spawn",):
            lines.append(("approximated", a["id"], "the world spawn stays on the ring's middle: "
                          "Sumo pins its ring where the host lands"))
        elif what in ("spawn", "spawns"):
            lines.append(("approximated", a["id"], "spawns stay round the ring (every start the "
                          "same distance from the edge)"))
        elif what in ("perch", "tower", "vantage") and P["platforms"]:
            lines.append(("placed", a["id"], "%s: the four platforms over the ring" % what))
        else:
            lines.append(("refused", a["id"], "%s: nothing stands on a knock-off ring (no walls, "
                          "no pillars - PARTY 1)" % what))
    arena = {"key": brief["key"] or "generated", "level": brief["level"],
             "budget": brief["budget"], "pieces": pieces, "spawns": spawns,
             "survey": {"ring": {"x": 0, "y": 0, "z": 0, "yaw": 0},
                        "points": [dict(s) for s in spawns]},
             "marks": [{"x": 0, "z": 0, "label": "ring centre"}],
             "look": kit.look(brief["theme"], brief["sky"], brief["music"])}
    finish(arena, lift)
    asked = [mm for mm in brief["modes"] if mm in MODES]
    only = ["sumo"] + (["smash"] if P["platforms"] else [])
    arena["onlyFor"] = sorted(set(only + asked), key=lambda x: MODES.index(x))
    arena["blurb"] = "a generated knock-off ring over the void"
    arena["note"] = ("%s %s ring %d across%s%s%s, nothing to brace against"
                     % ("an" if P["shape"] == "octagon" else "a", P["shape"], 2 * P["R"],
                        ", a crumbly rim" if P["rim"] == "crumbly" else "",
                        {1: "", 2: ", a tier below with ramps back up",
                         3: ", two tiers below with ramps back up"}[P["tiers"]],
                        ", four platforms over it" if P["platforms"] else ""))
    graph = ring_graph(P["tiers"], 4 if P["platforms"] else 0)
    params = dict(P, centre="ring", lane=P["shape"], corner=P["outer"], shield="-", I=P["R3"], G=0, B=0, Dh=0)
    meta = {"params": params, "units": 4, "symmetry": symmetry,
            "modules": {"ring": P["shape"], "tier2": P["shape2"] if P["tiers"] >= 2 else None,
                        "tier3": P["outer"] if P["tiers"] >= 3 else None,
                        "platforms": P["platforms"]},
            "anchors": lines, "notes": notes, "graph_faults": graph.faults(),
            "graph": {"zones": sorted(graph.zones), "loops": graph.loops},
            "centre": (0, 0), "field_spots": 0, "cover": 0,
            "module_pieces": {}, "bases": [[(s["x"], s["y"], s["z"]) for s in spawns]],
            "family": FAMILY}
    return arena, meta
