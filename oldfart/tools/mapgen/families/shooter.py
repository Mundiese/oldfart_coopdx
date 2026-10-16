from .. import cells, kit, v1
from ..skeleton import shooter_graph, solve_anchors
SKYKEEP = {"I": 2000, "G": 800, "B": 1200, "Dh": 600, "Cd": 600, "Ph": 400, "Pw": 600,
           "centre": "skykeep.crown", "lane": "bridge", "Lw": 600, "corner": "perch",
           "shield": "wide", "column": True, "breaker": True, "cover": 0, "stairs": False,
           "edge": "rails", "side_colours": True}
BANDSTAND = [
    {"kind": "box", "tex": "tile1", "x": 0, "y": 450, "z": 0, "w": 1400, "h": 100,
     "d": 1400, "yaw": 0, "tag": "bandstand"},
    {"kind": "box", "tex": "brickpyramid", "x": -600, "y": 0, "z": -600, "w": 200, "h": 450,
     "d": 200, "yaw": 0, "tag": "bandstand pillar"},
    {"kind": "box", "tex": "brickpyramid", "x": -600, "y": 0, "z": 600, "w": 200, "h": 450,
     "d": 200, "yaw": 0, "tag": "bandstand pillar"},
    {"kind": "box", "tex": "brickpyramid", "x": 600, "y": 0, "z": -600, "w": 200, "h": 450,
     "d": 200, "yaw": 0, "tag": "bandstand pillar"},
    {"kind": "box", "tex": "brickpyramid", "x": 600, "y": 0, "z": 600, "w": 200, "h": 450,
     "d": 200, "yaw": 0, "tag": "bandstand pillar"},
    {"kind": "ramp", "tex": "bricklightgrey", "x": 0, "y": 0, "z": 1200, "w": 600, "h": 550,
     "d": 1000, "yaw": 0, "tag": "bandstand ramp"},
    {"kind": "ramp", "tex": "bricklightgrey", "x": 0, "y": 0, "z": -1200, "w": 600, "h": 550,
     "d": 1000, "yaw": 180, "tag": "bandstand ramp"},
]
UNIT_ORDER4 = (0, 2, 1, 3)
KEEP_AXIS = 400
def q(v, step=200):
    return int(round(v / float(step))) * step
def family_across(players):
    return 8000 * (0.45 + 0.55 * players / 16.0)
MIN_ACROSS, MAX_ACROSS = 5600, 16000
class Unit:
    def __init__(self, index, units, symmetry):
        self.index = index
        self.units = units
        self.symmetry = symmetry
    def place(self, thing, point=False):
        m = v1.arenas_module()
        if self.units == 4:
            return (m.turned_point if point else m.turned)(thing, self.index)
        if self.index == 0:
            return dict(thing)
        if self.symmetry == "turn2":
            return (m.turned_point if point else m.turned)(thing, 2)
        return m.mirrored_z(thing)
def mirrored_x(thing):
    out = dict(thing)
    out["x"] = -out["x"]
    out["yaw"] = (360 - out.get("yaw", 0)) % 360
    return out
class Builder:
    def __init__(self, palette):
        self.pal = palette
        self.pieces = []
        self.reserved = []
        self.carves = []
        self.late = []
    def box(self, role, x0, x1, y0, y1, z0, z1, tag, tex=None):
        return kit.kind("box").make(tex or self.pal[role], x0, x1, y0, y1, z0, z1, None, tag)
    def ramp(self, role, x0, x1, y0, y1, z0, z1, rises, tag, kind="ramp", tex=None):
        return kit.kind(kind).make(tex or self.pal[role], x0, x1, y0, y1, z0, z1, rises, tag)
def rect_of(piece):
    return cells.piece_rect(piece)
def grow(rect, margin):
    return (rect[0] - margin, rect[1] + margin, rect[2] - margin, rect[3] + margin)
def overlaps(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]
def draw_params(brief, streams, units, notes, reference=False):
    if reference:
        return dict(SKYKEEP)
    from ..brief import across_units, PACES
    want, avoid = set(brief["features"]["want"]), set(brief["features"]["avoid"])
    r = streams("frame")
    across = across_units(brief["size"], family_across(brief["players"]))
    if across < MIN_ACROSS:
        notes.append("size: %d across is below the %d a keep with sixteen spawns needs; "
                     "built at %d" % (across, MIN_ACROSS, MIN_ACROSS))
        across = MIN_ACROSS
    if across > MAX_ACROSS:
        notes.append("size: %d across clamped to %d" % (across, MAX_ACROSS))
        across = MAX_ACROSS
    half = across / 2.0
    if units == 2:
        half *= 1.15
    P = {}
    P["G"] = r.choice((600, 800, 800, 1000))
    Bmin = 1200 if units == 4 else 1600
    P["I"] = max(1600, q(half * r.choice((0.45, 0.5, 0.5, 0.55))))
    P["B"] = max(Bmin, q(half - P["I"] - P["G"]))
    if P["I"] + P["G"] + P["B"] > half + 300:
        P["I"] = max(1600, q(half - P["G"] - P["B"]))
    vert = brief["verticality"]
    P["Ph"] = {"flat": 0, "low": r.choice((250, 300)), "medium": 400, "high": 400}[vert]
    P["Dh"] = {"flat": 0, "low": 400, "medium": 600, "high": 600}[vert]
    P["stairs"] = "stairs" in want and "ramps_only" not in want
    if P["stairs"]:
        P["Ph"] = min(P["Ph"], 250)
    if P["Ph"] > P["G"] // 2:
        P["Ph"] = (P["G"] // 2) // 50 * 50
    if "perches" in avoid:
        P["Ph"] = 0
    P["Pw"] = 600
    room = P["I"] - P["Pw"] - KEEP_AXIS
    if P["Ph"] and 2 * P["Ph"] > room:
        P["Ph"] = max(0, room // 2 // 50 * 50)
        if P["Ph"] < 150:
            P["Ph"] = 0
        notes.append("perches %d high: a small island leaves their ramps no more room"
                     % P["Ph"])
    P["Cd"] = max(P["Dh"], r.choice((600, 600, 800))) if P["Dh"] else 600
    if P["Cd"] + 600 > 0.45 * P["I"] + 400:
        P["Cd"] = 600
    u = streams("centre")
    choices = []
    if vert == "flat":
        choices = [("plaza", 1)]
    else:
        if units == 4:
            choices += [("crown", 3)]
            if P["Dh"] == 600 and P["I"] >= 1800:
                choices += [("skykeep.crown", 2)]
        choices += [("crown_straight", 2 if units == 2 else 1)]
        if P["I"] >= 1800:
            choices += [("pit", 2)]
        if P["I"] >= 2000:
            choices += [("bandstand", 1)]
        if "void_gaps" not in avoid and P["I"] >= 1800:
            choices += [("bridge_cross", 1)]
        if vert == "high" and units == 4 and P["I"] >= 2200:
            choices += [("crown_high", 3)]
    for feat, mod in (("crown", "crown"), ("pit", "pit"), ("bridge_cross", "bridge_cross"),
                      ("plaza", "bandstand")):
        if feat in want and any(c[0] == mod for c in choices):
            choices = [(mod, 1)]
        if feat in avoid:
            choices = [c for c in choices if not c[0].startswith(mod.split(".")[0])] or choices
    if "crown" in avoid:
        choices = [c for c in choices if "crown" not in c[0]] or [("plaza", 1)]
    if units == 2:
        choices = [c for c in choices if c[0] not in ("crown", "skykeep.crown", "crown_high")] \
            or [("crown_straight", 1)]
    P["centre"] = weighted(u, choices)
    s = streams("unit")
    P["lane"] = weighted(s, [("bridge", 3), ("causeway", 1), ("twin", 1)])
    if "bridge" in want:
        P["lane"] = "bridge"
    if "bridge" in avoid or "void_gaps" in avoid:
        P["lane"] = "causeway"
    P["Lw"] = {"bridge": 600, "causeway": 1000, "twin": 400}[P["lane"]]
    P["corner"] = "pad" if P["Ph"] == 0 else ("tower" if vert == "high" or "tower" in want
                                                 else "perch")
    P["shield"] = weighted(s, [("wide", 2), ("twin", 1)])
    P["column"] = "columns" not in avoid and (s.random() < 0.8 or "columns" in want)
    P["breaker"] = s.random() < 0.7
    dens = {"sparse": 1, "medium": 2, "dense": 4}[brief["density"]]
    if "long_lines" in avoid or "cover_walls" in want:
        dens += 1
    cov = (brief.get("amounts") or {}).get("cover_walls")
    if cov and "cover_walls" not in avoid:
        dens = {"trace": 0, "few": 1, "less": max(1, dens - 1), "more": dens + 2,
                "lots": max(dens + 2, 5)}[cov]
    P["cover"] = dens
    P["edge"] = brief["edge"] if brief["edge"] != "auto" else "rails"
    if "rails" in want:
        P["edge"] = "rails"
    if "rails" in avoid and P["edge"] == "rails":
        P["edge"] = "void"
    P["side_colours"] = "side_colours" not in avoid
    return P
def weighted(r, choices):
    total = sum(w for _, w in choices)
    x = r.random() * total
    for name, w in choices:
        x -= w
        if x < 0:
            return name
    return choices[-1][0]
def bastion(b, P, accent, unit_spawns, uid):
    I, G, B = P["I"], P["G"], P["B"]
    z0, z1 = I + G, I + G + B
    tag = uid + ".bastion"
    back_h = 900 if P.get("back", "wall") == "wall" else 160
    out = [b.box(None, -I, I, -300, 0, z0, z1, tag, tex=accent),
           b.box("wall", -I, I, 0, back_h, z1 - 200, z1, uid + ".back wall")]
    if P["edge"] in ("rails", "walled"):
        h = 160 if P["edge"] == "rails" else 400
        out += [b.box("wall", -I, -I + 80, 0, h, z0, z1 - 200, uid + ".bastion rail"),
                b.box("wall", I - 80, I, 0, h, z0, z1 - 200, uid + ".bastion rail")]
    lw = P["Lw"] // 2 if P["lane"] != "twin" else 800
    if I - 600 > lw:
        out += [b.box("wall", -(I - 600), -lw, 0, 200, z0, z0 + 100, uid + ".front wall"),
                b.box("wall", lw, I - 600, 0, 200, z0, z0 + 100, uid + ".front wall")]
    if P["shield"] == "wide":
        out.append(b.box("wall", -500, 500, 0, 400, z0 + 300, z0 + 500, uid + ".shield"))
    else:
        out += [b.box("wall", -900, -500, 0, 400, z0 + 300, z0 + 500, uid + ".shield"),
                b.box("wall", 500, 900, 0, 400, z0 + 300, z0 + 500, uid + ".shield")]
    rows = [z1 - 450] if unit_spawns <= 4 else [z1 - 450, z1 - 850]
    xs = [q(-0.575 * I, 50), q(-0.175 * I, 50), q(0.175 * I, 50), q(0.575 * I, 50)]
    if P["I"] == 2000:
        xs = [-1150, -350, 350, 1150]
    spawns = []
    for z in rows:
        for x in xs:
            spawns.append({"x": x, "y": 0, "z": z, "yaw": 180})
    return out, spawns[:unit_spawns]
def lane(b, P, uid):
    I, G = P["I"], P["G"]
    tag = uid + ".lane"
    out = []
    rails = P["edge"] in ("rails", "walled")
    if P["lane"] == "bridge":
        out.append(b.box("bridge", -300, 300, -100, 0, I, I + G, uid + ".bridge"))
        if rails:
            out += [b.box("wall", -300, -220, 0, 120, I, I + G, uid + ".bridge rail"),
                    b.box("wall", 220, 300, 0, 120, I, I + G, uid + ".bridge rail")]
    elif P["lane"] == "causeway":
        out.append(b.box("floor", -500, 500, -200, 0, I, I + G, uid + ".causeway"))
        if rails:
            out += [b.box("wall", -500, -420, 0, 160, I, I + G, uid + ".causeway rail"),
                    b.box("wall", 420, 500, 0, 160, I, I + G, uid + ".causeway rail")]
    else:
        for sx in (-1, 1):
            x0, x1 = sorted((sx * 400, sx * 800))
            out.append(b.box("bridge", x0, x1, -100, 0, I, I + G, uid + ".twin bridge"))
    del tag
    return out
def corner(b, P, module, uid):
    I, Ph = P["I"], P["Ph"]
    kind = "stairs" if P["stairs"] else "ramp"
    if module == "pad" or Ph == 0:
        return [], [], []
    if module == "tower" and I - 1000 - 2 * Ph < KEEP_AXIS:
        module = "perch"
    Pw = 1000 if module == "tower" else P["Pw"]
    out = [b.box("wall", I - Pw, I, 0, Ph, I - Pw, I, uid + ".perch")]
    out.append(b.ramp("ramp", I - Pw - 2 * Ph, I - Pw, 0, Ph, I - 400, I, "+x",
                      uid + ".perch ramp", kind=kind))
    spots = [{"x": I - 300, "y": Ph, "z": I - 300, "yaw": 225}]
    keep = [(I - Pw - 2 * Ph - 200, I, I - Pw - 200, I)]
    if module == "tower":
        top = Ph + 250
        out.append(b.box("wall", I - 700, I - 300, Ph, top, I - 1000, I - 600, uid + ".tower"))
        out.append(b.ramp("ramp", I - 700, I - 300, Ph, top, I - 600, I - 100, "-z",
                          uid + ".tower ramp", kind=kind))
        spots = [{"x": I - 500, "y": top, "z": I - 800, "yaw": 225},
                 {"x": I - 150, "y": Ph, "z": I - 150, "yaw": 225}]
    return out, spots, keep
def flanks(b, P, uid):
    I, G, Ph = P["I"], P["G"], P["Ph"]
    kind = "stairs" if P["stairs"] else "ramp"
    out = []
    for x0, x1 in ((I - 600, I), (-I, -I + 600)):
        if Ph == 0:
            out.append(b.box("bridge", x0, x1, -100, 0, I, I + G, uid + ".flank bridge"))
        else:
            out.append(b.ramp("ramp", x0, x1, 0, Ph, I, I + G, "-z", uid + ".flank ramp",
                              kind=kind))
    return out
def field(b, P, uid):
    I = P["I"]
    out, keep, spots = [], [], []
    if P["column"]:
        c0 = q(0.45 * I, 100)
        rect = (c0, c0 + 400, c0, c0 + 400)
        out.append(b.box("wall", c0, c0 + 400, 0, 700, c0, c0 + 400, uid + ".column"))
        keep.append(rect)
    if P["breaker"]:
        out.append(b.box("wall", -400, 400, 0, 200, I - 600, I - 500, uid + ".breaker"))
        keep.append((-400, 400, I - 600, I - 500))
    spots.append({"x": 0, "y": 0, "z": I - 850, "yaw": 180})
    keep.append((-P["Lw"] // 2 - 300 if P["lane"] != "twin" else -1000,
                 P["Lw"] // 2 + 300 if P["lane"] != "twin" else 1000, I - 1000, I))
    keep.append((-200, 200, I - 1050, I - 650))
    return out, keep, spots
def centre(b, P, module, units, uid="centre"):
    m = v1.arenas_module()
    Dh, Cd = P["Dh"], P["Cd"]
    I = P["I"]
    out, spots, keep = [], [], []
    turns = 4 if units == 4 else 2
    def all_turns(pieces):
        return [m.turned(p, qq) for qq in range(4) for p in pieces]
    if module == "skykeep.crown":
        out = [dict(p, tag="centre." + p["tag"]) for p in cells.cut_module(
            "skykeep", tags=("crown deck", "crown pillar", "crown merlon", "crown ramp"))]
        for p in out:
            p.pop("model", None)
            p["tex"] = {"tile1": b.pal["deck"], "brickdarkgrey": b.pal["wall"],
                        "bricklightgrey": b.pal["ramp"]}.get(p["tex"], p["tex"])
        Dh, Cd = 600, 600
        keep.append((-1000, 1000, -1000, 1000))
        spots = [{"x": 300, "y": 600, "z": 300, "yaw": 225}]
    elif module in ("crown", "crown_high"):
        if module == "crown_high":
            Dh = Cd = 800
        out.append(b.box("deck", -Cd, Cd, Dh - 100, Dh, -Cd, Cd, uid + ".crown deck"))
        quarter = [b.box("wall", Cd - 200, Cd, 0, Dh - 100, Cd - 200, Cd, uid + ".crown pillar"),
                   b.box("wall", -200, 200, Dh, Dh + 200, Cd - 150, Cd, uid + ".crown merlon"),
                   b.ramp("ramp", -Cd, Cd, 0, Dh, Cd, Cd + 400, "-x", uid + ".crown ramp")]
        out += all_turns(quarter)
        keep.append((-Cd - 400, Cd + 400, -Cd - 400, Cd + 400))
        spots = [{"x": Cd // 2, "y": Dh, "z": Cd // 2, "yaw": 225}]
    elif module == "crown_straight":
        Dh = min(Dh, 400)
        out.append(b.box("deck", -Cd, Cd, Dh - 100, Dh, -Cd, Cd, uid + ".crown deck"))
        for sx in (-1, 1):
            for sz in (-1, 1):
                x0, z0 = (Cd - 200 if sx > 0 else -Cd), (Cd - 200 if sz > 0 else -Cd)
                out.append(b.box("wall", x0, x0 + 200, 0, Dh - 100, z0, z0 + 200,
                                 uid + ".crown pillar"))
        side = [b.ramp("ramp", -300, 300, 0, Dh, Cd, Cd + 2 * Dh, "-z", uid + ".crown ramp")]
        if turns == 4:
            out += all_turns(side)
        else:
            out += side + [m.mirrored_z(side[0])]
        keep.append((-Cd - 2 * Dh, Cd + 2 * Dh, -Cd - 2 * Dh, Cd + 2 * Dh))
        spots = [{"x": Cd // 2, "y": Dh, "z": Cd // 2, "yaw": 225}]
    elif module == "bandstand":
        cut = [dict(p) for p in BANDSTAND]
        seen = []
        for p in cut:
            p = dict(p, tag="centre." + p["tag"])
            p["tex"] = {"tile1": b.pal["deck"], "brickpyramid": b.pal["wall"],
                        "bricklightgrey": b.pal["ramp"]}.get(p["tex"], p["tex"])
            if p not in seen:
                seen.append(p)
        out = seen
        if turns == 4:
            out += [m.turned(p, 1) for p in out if p["kind"] == "ramp"]
        keep.append((-1900, 1900, -1900, 1900) if turns == 4 else (-900, 900, -1900, 1900))
        spots = [{"x": 300, "y": 550, "z": 300, "yaw": 225}]
    elif module == "pit":
        Pp = q(min(0.7 * I - 400, 1400))
        b.carves.append((-Pp, Pp, -400, 0, -Pp, Pp))
        out.append(b.box("wall", -200, 200, -400, -200, -200, 200, uid + ".pit block"))
        if turns == 4:
            out += all_turns([b.ramp("ramp", Pp - 800, Pp, -400, 0, Pp - 400, Pp, "+x",
                                     uid + ".pit ramp")])
        else:
            r = b.ramp("ramp", -300, 300, -400, 0, Pp - 800, Pp, "+z", uid + ".pit ramp")
            out += [r, m.mirrored_z(r)]
        keep.append((-Pp - 300, Pp + 300, -Pp - 300, Pp + 300))
        spots = []
    elif module == "bridge_cross":
        Pp = q(min(0.4 * I, 1200))
        b.carves.append((-Pp, Pp, -10 ** 5, 10 ** 5, -Pp, Pp))
        out.append(b.box("bridge", -300, 300, -100, 0, -Pp, Pp, uid + ".cross bridge"))
        out.append(b.box("bridge", -Pp, -300, -100, 0, -300, 300, uid + ".cross bridge"))
        out.append(b.box("bridge", 300, Pp, -100, 0, -300, 300, uid + ".cross bridge"))
        if P["edge"] in ("rails", "walled"):
            arm = [b.box("wall", -300, -220, 0, 120, 300, Pp, uid + ".cross rail"),
                   b.box("wall", 220, 300, 0, 120, 300, Pp, uid + ".cross rail")]
            out += all_turns(arm)
        keep.append((-Pp - 300, Pp + 300, -Pp - 300, Pp + 300))
        spots = []
    else:
        ring = [b.box("wall", -400, 400, 0, 200, 700, 900, uid + ".plaza wall")]
        out += all_turns(ring)
        keep.append((-1100, 1100, -1100, 1100))
        spots = [{"x": 0, "y": 0, "z": 0, "yaw": 0}]
    return out, spots, keep
FAMILY = "shooter"
def build(brief, streams, reference=False):
    from .. import dice as dicemod, skeletons
    if reference:
        return build_keep(brief, streams, reference=True)
    d = dicemod.roll(brief, streams("style"))
    if streams.force.get("boost"):
        k = streams.force["boost"]
        if k in d:
            d[k] = 3
            if k not in d.boosted:
                d.boosted.append(k)
    across = skeletons.across_of(brief, brief["players"])
    name = streams.force.get("skeleton")
    keep_only = [a for a in brief["anchors"] if a["what"] not in ("world_spawn",)
                 and not skeletons.ABOUT.get(a["what"])]
    if [a for a in brief["anchors"] if a["what"] != "world_spawn"]:
        solve_anchors(brief, shooter_graph(4, (2000, 2600)))
    if name:
        syms = skeletons.SKELETONS[name][0]
        units = skeletons.wanted_units(brief)
        sym = "mirror" if units == 2 and "mirror" in syms else syms[0]
        if units == 4 and "turn4" in syms:
            sym = "turn4"
        why = "skeleton %s (%s) pinned" % (name, sym)
    elif set(brief["features"]["want"]) & set(skeletons.ROOM_WANTS) and \
            skeletons.wanted_units(brief) != 4:
        name, sym, why = skeletons.choose(brief, d, streams("skeleton"), across)
    elif keep_only:
        name, sym = "keep", None
        why = "skeleton keep: the anchors %s are placed by the keep's zone solver" % ", ".join(
            a["id"] for a in keep_only)
    else:
        name, sym, why = skeletons.choose(brief, d, streams("skeleton"), across)
    if name == "keep":
        arena, meta = build_keep(brief, streams, dice=d, sym=sym)
        meta["notes"].insert(0, why)
        return spread(arena, meta)
    return spread(*build_skeleton(brief, streams, d, name, sym, across, why))
def spread(arena, meta):
    from .. import spawns as spawnmod
    leaders = max(1, len([b for b in meta.get("bases") or [] if b]))
    rep = spawnmod.spread_points(arena, leaders)
    if rep:
        if not isinstance(meta.get("spawn_report"), dict):
            meta["spawn_report"] = {}
        meta["spawn_report"]["spread"] = rep
        meta.setdefault("notes", []).append(
            "survey points spread for a free-for-all: %d, %s apart at the median (was %s)"
            % (rep["points"], rep["median_gap"], rep["median_gap_before"]))
    return arena, meta
def build_skeleton(brief, streams, d, name, sym, across, why):
    from .. import beauty, layout, skeletons
    from ..skeleton import compass_of
    pal, pal_notes = beauty.palette(brief["theme"], brief["palette"])
    if "side_colours" in brief["features"]["avoid"] or (d is not None and d["side_colours"] == 0):
        pal["accents"] = [pal["deck"]] * 4
    L = skeletons.build(name, sym, brief, streams, d, pal, across)
    L.notes.insert(0, why)
    L.notes += pal_notes
    if d is not None:
        L.notes.append("style: %s" % d.about())
    lines = []
    for a in brief["anchors"]:
        what, where = a["what"], a["where"]
        if what == "world_spawn":
            pts = []
            for b in L.bases:
                x0, x1, z0, z1 = b["rect"]
                pts += L.sym.points({"x": (x0 + x1) / 2.0, "y": 0, "z": (z0 + z1) / 2.0})
            want = where.get("compass")
            best = None
            if want and want != "c":
                from ..skeleton import COMPASS_VEC
                vx, vz = COMPASS_VEC[want]
                best = max(pts, key=lambda p: (p["x"] * vx + p["z"] * vz, -p["x"], -p["z"]))
            if best is None:
                L.world_spawn = None
                lines.append(("placed", a["id"], "world spawn at the centre (the origin)"))
            else:
                L.world_spawn = (best["x"], best["z"])
                lines.append(("placed" if compass_of(best["x"], best["z"]) == want else
                              "approximated", a["id"],
                              "world spawn on the base to the %s: the layout is moved so it "
                              "stands at the origin" % compass_of(best["x"], best["z"])))
        elif name in skeletons.ABOUT.get(what, ()):
            lines.append(("approximated", a["id"], "%s: the %s skeleton is built round it "
                          "(the exact spot is the anchor solver's)" % (what, name)))
        else:
            lines.append(("not yet", a["id"], "%s is not placed by the %s skeleton" % (what, name)))
    L.anchor_lines = lines
    if name == "rooms":
        from .. import rooms
        return rooms.finish(L, L.rooms_plan)
    from .. import rewire
    arena, meta = rewire.finish(L)
    return arena, meta
def build_keep(brief, streams, reference=False, dice=None, sym=None):
    notes = []
    symmetry = sym or brief["symmetry"]
    if symmetry == "turn8":
        notes.append("symmetry turn8: built as turn4 (eighth turns are not in the kit)")
        symmetry = "turn4"
    sides = brief["sides"]
    units = 2 if symmetry in ("mirror", "turn2") or sides == "2" else 4
    if units == 2 and symmetry not in ("mirror", "turn2"):
        symmetry = "mirror"
    asym = symmetry == "none"
    P = draw_params(brief, streams, units, notes, reference)
    P["skeleton"] = "keep"
    P["back"] = "wall" if reference else "rail"
    graph = shooter_graph(units, (P["I"], P["I"] + P["G"] + P["B"] // 2))
    gfaults = graph.faults()
    plan, lines = solve_anchors(brief, graph)
    if reference:
        pal, pal_notes = kit.palette(brief["theme"], brief["palette"])
    else:
        from .. import beauty
        pal, pal_notes = beauty.palette(brief["theme"], brief["palette"])
    notes += pal_notes
    b = Builder(pal)
    m = v1.arenas_module()
    cmod = P["centre"]
    if "centre" in plan["zones"] and plan["zones"]["centre"]["module"]:
        cmod = plan["zones"]["centre"]["module"]
        aid = plan["zones"]["centre"]["anchor"]
        if units == 2 and cmod in ("crown", "crown_high", "skykeep.crown"):
            _approximate(lines, aid, "two bases: a straight crown (a pinwheel is not "
                         "mirror-symmetric)")
            cmod = "crown_straight"
        if cmod == "crown_high" and P["I"] < 2200:
            notes.append("the island widened from %d to 2200 half to hold the tower in the "
                         "middle" % P["I"])
            P["I"] = 2200
            P["column"] = P["column"] and True
    P["centre"] = cmod
    I = P["I"]
    base = [b.box("floor", -I, I, -200, 0, -I, I, "island")]
    if brief["level"] == "empty2":
        k1, k2 = q(0.7 * I, 100), q(0.35 * I, 100)
        base += [b.box("keel", -k1, k1, -700, -200, -k1, k1, "keel"),
                 b.box("keel", -k2, k2, -1300, -700, -k2, k2, "keel")]
    cpieces, cspots, ckeep = centre(b, P, cmod, units)
    ckeep = [rect_of(p) for p in cpieces] + [(c[0], c[1], c[4], c[5]) for c in b.carves]
    zone_by_compass = {z.compass: z.id for z in graph.zones.values()}
    unit_pieces, spawns_by_unit, spots_by_unit, keeps = [], [], [], []
    accents = pal["accents"] if P["side_colours"] else [pal["floor"]] * 4
    modules = {"centre": cmod, "island": "island"}
    for u in range(units):
        unit = Unit(u, units, symmetry)
        uid = "unit%d" % u
        Pu = P
        if asym:
            Pu = dict(P)
            su = streams("unit.%d" % u)
            Pu["lane"] = weighted(su, [("bridge", 3), ("causeway", 1), ("twin", 1)])
            Pu["Lw"] = {"bridge": 600, "causeway": 1000, "twin": 400}[Pu["lane"]]
            Pu["shield"] = weighted(su, [("wide", 2), ("twin", 1)])
            Pu["column"] = su.random() < 0.8
        local = []
        acc = accents[[0, 1, 2, 3][u if units == 4 else (0 if u == 0 else 2)]]
        if reference:
            acc = ["stone1", "brickpyramid", "carpet", "woodenplank2"][u]
        bp, sp = bastion(b, Pu, acc, 16 // units, uid)
        local += bp
        local += lane(b, Pu, uid)
        local += flanks(b, Pu, uid)
        fp, fkeep, fspots = field(b, Pu, uid)
        clash = [p for p in fp if any(overlaps(grow(rect_of(p), 200), k) for k in ckeep)]
        fp = [p for p in fp if p not in clash]
        fkeep = [k for k in fkeep if not any(overlaps(k, rect_of(p)) and k == rect_of(p)
                                              for p in clash)]
        fspots = [sp for sp in fspots if not any(
            k[0] <= sp["x"] <= k[1] and k[2] <= sp["z"] <= k[3] for k in ckeep)]
        local += fp
        uspots = list(fspots)
        ukeep = list(fkeep)
        corner_sides = [1] if units == 4 else [1, -1]
        for sx in corner_sides:
            probe = unit.place({"x": sx * (I - 300), "y": 0, "z": I - 300, "yaw": 0}, point=True)
            from ..skeleton import compass_of
            zid = zone_by_compass.get(compass_of(probe["x"], probe["z"]))
            cm = P["corner"]
            entry = plan["zones"].get(zid)
            if entry and entry["module"] in ("tower", "perch") and P["Ph"] > 0:
                cm = entry["module"]
            if not entry and plan["asymmetric"] and cm == "tower" and "tower" not in \
                    brief["features"]["want"] and brief["verticality"] != "high":
                cm = "perch"
            copied = [e for e in plan["zones"].values()
                      if not e["once"] and e["module"] in ("tower", "perch")]
            if copied and not entry and P["Ph"] > 0:
                cm = copied[0]["module"]
            modules[zid] = cm
            cp, cs, ck = corner(b, Pu, cm, "%s.%s" % (uid, zid))
            if sx < 0:
                cp = [mirrored_x(p) for p in cp]
                cs = [mirrored_x(s) for s in cs]
                ck = [(-r[1], -r[0], r[2], r[3]) for r in ck]
            local += cp
            uspots += cs
            ukeep += ck
        if units == 2:
            local += [mirrored_x(p) for p in fp if p["tag"].endswith("column")]
            ukeep += [(-r[1], -r[0], r[2], r[3]) for r in fkeep[:1]] if Pu["column"] else []
        modules[uid] = {"base": "bastion", "lane": Pu["lane"], "shield": Pu["shield"]}
        unit_pieces += [unit.place(p) for p in local]
        spawns_by_unit.append([unit.place(s, point=True) for s in sp])
        spots_by_unit.append([unit.place(s, point=True) for s in uspots])
        for r in ukeep:
            dummy = kit.kind("box").make("tile1", r[0], r[1], 0, 1, r[2], r[3])
            keeps.append(rect_of(unit.place(dummy)))
    keeps += ckeep
    centre_spots = []
    for u in range(units):
        unit = Unit(u, units, symmetry)
        for s in cspots:
            centre_spots.append(unit.place(s, point=True))
    cover = [] if reference else fill(b, P, brief, streams, units, symmetry, keeps, asym)
    pieces = base + unit_pieces + cover
    module_pieces = {}
    for p in pieces + cpieces:
        mod = str(p.get("tag", "")).split(".")[0]
        module_pieces.setdefault(mod, []).append(
            tuple(sorted((k, str(v)) for k, v in p.items() if k != "tag")))
    module_pieces = {k: sorted(v) for k, v in module_pieces.items()}
    module_pieces.setdefault("centre", []).extend("carve %s" % (c,) for c in b.carves)
    cx, cz = _edges(cpieces)
    grid = cells.CellGrid.from_pieces(pieces, cx, cz)
    for (x0, x1, y0, y1, z0, z1) in b.carves:
        grid.carve(x0, x1, z0, z1, y0, y1)
    for p in cpieces:
        grid.add_piece(p)
    merged = grid.to_pieces()
    lift = 10 if brief["level"] == "empty" else 0
    order = []
    seq = UNIT_ORDER4 if units == 4 else (0, 1)
    per = 16 // units
    for k in range(per):
        for u in seq:
            order.append(spawns_by_unit[u][k])
    field_spots = []
    for u in seq:
        field_spots += spots_by_unit[u]
    field_spots += centre_spots
    if reference:
        field_spots = []
        for u in UNIT_ORDER4:
            field_spots += [spots_by_unit[u][1], spots_by_unit[u][0], centre_spots[u]]
    arena = {"key": brief["key"] or "generated", "level": brief["level"],
             "budget": brief["budget"], "pieces": merged, "spawns": order,
             "survey": {}, "look": kit.look(brief["theme"], brief["sky"], brief["music"],
                                             None if reference else streams("light"), "shooter")}
    if reference:
        arena["look"] = {k: arena["look"][k] for k in ("sky", "music")}
    if lift:
        for p in arena["pieces"]:
            p["y"] += lift
        for s in order + field_spots:
            s["y"] += lift
    centre_at = (0, 0)
    if plan["world_spawn"]:
        zid = plan["world_spawn"]["zone"]
        zone = graph.zones[zid]
        if zone.kind == "base":
            u = zone.unit
            pt = Unit(u, units, symmetry).place(
                {"x": 0, "y": 0, "z": I + P["G"] + P["B"] - 450, "yaw": 0}, point=True)
        elif zone.kind == "corner":
            pt = {"x": (zone.x / abs(zone.x)) * (I - 300), "z": (zone.z / abs(zone.z)) * (I - 300)}
        else:
            pt = {"x": 0, "z": 0}
        dx, dz = -int(pt["x"]), -int(pt["z"])
        for p in arena["pieces"]:
            p["x"] += dx
            p["z"] += dz
        for s in order + field_spots:
            s["x"] += dx
            s["z"] += dz
        centre_at = (dx, dz)
    ok_spots = []
    for s in field_spots:
        hs = m.standable(arena["pieces"], s["x"], s["z"], arena["level"])
        if any(abs(h - s["y"]) <= 1 for h in hs) and len(order) + len(ok_spots) < 28:
            ok_spots.append(s)
    arena["survey"] = {"points": order + ok_spots}
    for p in arena["pieces"]:
        p["model"] = m.model_name(p)
    meta = {"params": P, "units": units, "symmetry": symmetry, "modules": modules,
            "anchors": lines, "notes": notes, "graph_faults": gfaults,
            "graph": {"zones": sorted(graph.zones), "loops": graph.loops},
            "centre": centre_at, "field_spots": len(ok_spots), "cover": len(cover),
            "module_pieces": module_pieces, "skeleton": "keep",
            "style": dice.as_dict() if dice is not None else None,
            "bases": [[(sp["x"], sp["y"], sp["z"]) for sp in order[i::units]]
                      for i in range(units)]}
    if not reference:
        from .. import spawns as spawnmod
        chosen, rep = spawnmod.choose_field_world(arena, list(field_spots), units, symmetry)
        if chosen is not None:
            arena["survey"] = {"points": order + chosen}
            meta["field_spots"] = len(chosen)
            meta["spawn_report"] = {"field": rep}
    return arena, meta
def _approximate(lines, aid, why):
    for i, (how, a, note) in enumerate(lines):
        if a == aid and how == "placed":
            lines[i] = ("approximated", a, "%s; %s" % (note, why))
def _edges(pieces):
    xs, zs = [], []
    for p in pieces:
        r = rect_of(p)
        xs += [r[0], r[1]]
        zs += [r[2], r[3]]
    return xs, zs
def fill(b, P, brief, streams, units, symmetry, keeps, asym):
    I = P["I"]
    out = []
    count = P["cover"]
    r = streams("fill")
    shapes = [("breaker", 800, 200, 200, "wall"), ("breaker", 200, 800, 200, "wall"),
              ("wall", 600, 200, 400, "cover"), ("wall", 200, 600, 400, "cover"),
              ("crate", 200, 200, 200, "crate"), ("block", 400, 400, 600, "cover")]
    placed = []
    tries = 0
    while len(out) < count * (units if units == 4 else 4) and tries < 150:
        tries += 1
        name, w, d, h, role = r.choice(shapes)
        x0 = q(r.uniform(-I + 200, I - 200 - w))
        z0 = q(r.uniform(200, I - 200 - d))
        rect = (x0, x0 + w, z0, z0 + d)
        if units == 4 and not (abs(rect[0]) < rect[2] - 200 and abs(rect[1]) < rect[2] - 200):
            continue
        if units == 2 and rect[0] < 200:
            continue
        copies = []
        for u in range(units):
            unit = Unit(u, units, symmetry)
            dummy = kit.kind("box").make("tile1", rect[0], rect[1], 0, 1, rect[2], rect[3])
            copies.append(rect_of(unit.place(dummy)))
            if units == 2:
                copies.append(rect_of(unit.place(mirrored_x(dummy))))
        if any(overlaps(grow(c, 200), k) for c in copies for k in keeps):
            continue
        if any(overlaps(grow(c, 400), p) for c in copies for p in placed):
            continue
        if any(overlaps(grow(a, 300), c) for i, a in enumerate(copies) for c in copies[i + 1:]):
            continue
        placed += copies
        tex = b.pal["cover"] if role != "crate" else "crate"
        piece = kit.kind("box").make(tex, rect[0], rect[1], 0, h, rect[2], rect[3], None,
                                     "fill.%s" % name)
        group = []
        for u in range(units):
            unit = Unit(u, units, symmetry)
            group.append(unit.place(piece))
            if units == 2:
                group.append(unit.place(mirrored_x(piece)))
        out += group
    return out
