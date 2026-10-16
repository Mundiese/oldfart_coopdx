import math
import re
from studio.editor import geometry as geo, ops
from studio.editor.commands import Change
NAME_RE = re.compile(r"(\w+) (\w+) at \((-?\d+), (-?\d+), (-?\d+)\)")
SPAWN_RE = re.compile(r"spawn (\d+)")
CELL_RE = re.compile(r"first at x (-?\d+) z (-?\d+) y (-?\d+)")
FIX_LABELS = {
    "delete_overlap": "Delete the smaller piece",
    "nudge_apart": "Nudge it off the other piece",
    "resolve_all": "Resolve every overlap (as the generator does)",
    "spawn_to_floor": "Move the spawn onto the nearest floor",
    "add_ramp": "Add a ramp out",
    "close_slot": "Close the slot (lower the piece onto the one below)",
    "repaint": "Paint it with the current texture",
    "refine": "Ask the engine",
    "dress": "Auto-dress the map",
    "edge_invisible": "Make the map edge an invisible wall",
    "star_renumber": "Number the stars 1 to n in their order",
    "star_to_lift": "Hang it 200 over the floor (a vanilla star's height)",
    "contract_repaint": "Paint it in its class's material (the theme contract)",
    "add_cheek": "Add the flight's cheek wall on the open side",
    "delete_piece": "Delete the piece",
    "drop_piece": "Drop it onto what is below it",
    "delete_wire": "Take the wire out",
    "critic": "Let the critic mend it (one undo step)",
}
SHORT = {
    "delete_overlap": "Delete one", "nudge_apart": "Nudge apart", "resolve_all": "Fix overlaps",
    "spawn_to_floor": "Onto the floor", "add_ramp": "Add a ramp", "close_slot": "Close it",
    "repaint": "Repaint", "refine": "Ask the engine", "dress": "Auto-dress",
    "edge_invisible": "Close the edge", "star_renumber": "Renumber", "star_to_lift": "Lift it",
    "contract_repaint": "Repaint", "add_cheek": "Add a wall", "delete_piece": "Delete it",
    "drop_piece": "Drop it", "delete_wire": "Take it out", "critic": "Fix it",
}
SHOW_ME = "Show me"
REFINE_TEXT = {
    ("sightline_max", False): "more cover", ("open_pairs_over_2400", False): "more cover",
    ("sightline_p95", False): "more cover", ("cover_within_300", True): "more cover",
    ("cover_within_300", False): "more open", ("openness", True): "more open",
    ("layers", True): "more verticality", ("high_ground_share", True): "more verticality",
    ("layers", False): "flatter", ("high_ground_share", False): "flatter",
    ("spawn_exposure_max", False): "new bases", ("spawn_exposure_mean", False): "new bases",
    ("spawn_kill_risk", False): "new bases", ("spawn_equity", False): "new bases",
    ("dead_ends", False): "new cover", ("chokes", False): "new cover",
    ("area_per_player", True): "bigger map", ("area_per_player", False): "smaller map",
    ("spawn_to_centre_s", True): "bigger map", ("spawn_to_centre_s", False): "smaller map",
    ("spawn_to_enemy_spawn_s", True): "bigger map",
    ("climb_routes_per_high_point", True): "new centre",
    ("exits_per_base", True): "new bases",
    ("lf1_viable_routes", True): "new cover", ("lf1_viable_routes", False): "more cover",
    ("lf3_flank_unseen", True): "more cover", ("lf4_flank_angle", True): "new cover",
    ("cb1_home_ratio", False): "new bases", ("cb2_unseen_exits", True): "new bases",
    ("vm1_per_unit", True): "more verticality", ("vm1_shortcuts", True): "more verticality",
    ("vm1_per_district", True): "more verticality", ("vm3_theme_share", True): "new cover",
    ("sl_real_choices", True): "more verticality",
    ("gp1_move_share", True): "more verticality", ("gp2_height_span", True): "more verticality",
    ("gp3_above_share", True): "more verticality", ("gp4_farthest_s", True): "bigger map",
    ("gp4_farthest_s", False): "smaller map", ("gp4_nearest_s", False): "smaller map",
}
class Issue:
    def __init__(self, level, source, text, refs=(), points=(), fixes=(), data=None):
        self.level = level
        self.source = source
        self.text = text
        self.refs = list(refs)
        self.points = list(points)
        self.fixes = list(fixes)
        self.data = data or {}
    def __repr__(self):
        return "<Issue %s %s: %s>" % (self.level, self.source, self.text[:60])
    def bounds(self, doc):
        boxes = [geo.aabb(doc.view_item(r)) for r in self.refs if r in doc]
        for p in self.points:
            boxes.append((p[0] - 300, p[0] + 300, p[1], p[1] + 300, p[2] - 300, p[2] + 300))
        return geo.union(boxes)
def piece_refs_named(doc, text):
    out = []
    for m in NAME_RE.finditer(text):
        kind, tex, x, y, z = m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), \
            int(m.group(5))
        for ref in doc.refs("piece"):
            p = doc.get(ref)
            if (p["kind"], p["tex"]) == (kind, tex) and \
                    (int(p["x"]), int(p["y"]), int(p["z"])) == (x, y, z) and ref not in out:
                out.append(ref)
                break
    return out
def _spawn_ref(doc, text):
    m = SPAWN_RE.search(text)
    if not m:
        return None
    refs = doc.refs("spawn")
    i = int(m.group(1)) - 1
    return refs[i] if 0 <= i < len(refs) else None
def gate_issue(doc, fault):
    refs = piece_refs_named(doc, fault)
    fixes = []
    points = []
    data = {}
    if " overlaps " in fault:
        if len(refs) >= 2:
            fixes = ["nudge_apart", "delete_overlap", "resolve_all"]
        else:
            fixes = ["resolve_all"]
    elif "drawn twice, they flicker" in fault:
        fixes = ["resolve_all", "delete_overlap"] if len(refs) >= 2 else ["resolve_all"]
    elif "-high slot under" in fault and len(refs) >= 2:
        fixes = ["close_slot"]
    elif "one-way trip" in fault:
        m = CELL_RE.search(fault)
        if m:
            x, z, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
            points.append((x + 50, y, z + 50))
            data["cell"] = (x, z, y)
            fixes = ["add_ramp"]
    elif fault.startswith("spawn ") and ("stands on nothing" in fault or
                                         "cannot be walked" in fault):
        ref = _spawn_ref(doc, fault)
        if ref is not None:
            refs = [ref]
            fixes = ["spawn_to_floor"]
    elif "no block texture" in fault or "plain Brick" in fault:
        fixes = ["repaint"] if refs else []
    return Issue("fail", "gate", fault, refs, points, fixes, data)
def metric_issues(card):
    out = []
    for group in (card or {}).get("metrics") or []:
        for row in group.get("rows") or []:
            if row.get("status") not in ("fail", "warn"):
                continue
            value = row.get("value")
            low = _too_low(row)
            fixes = []
            text = REFINE_TEXT.get((row.get("metric"), low))
            if text:
                fixes = ["refine"]
            shown = value if not isinstance(value, float) else round(value, 3)
            fun = group.get("group") == "fun"
            looks = group.get("group") == "looks"
            msg = "%s: %s (want %s)" % (row.get("label", row.get("metric")), shown, row.get("band"))
            if (fun or looks) and row.get("note"):
                msg += " - " + row["note"]
            if looks:
                msg += ". Fix: " + row.get("fix", "")
                out.append(Issue(row["status"], "beauty", msg, fixes=["dress"],
                                 data={"metric": row.get("metric"), "group": "looks"}))
                continue
            where = ((card or {}).get("fun_where") or {}).get(row.get("metric")) or []
            out.append(Issue(row["status"], "fun" if fun else "metric", msg,
                             points=[tuple(p) for p in where[:6]],
                             fixes=fixes, data={"metric": row.get("metric"), "refine": text,
                                                "group": group.get("group")}))
    return out
def _too_low(row):
    v = row.get("value")
    vals = [x for x in (list(v) if isinstance(v, (list, tuple)) else [v]) if x is not None]
    if not vals:
        return None
    lo, hi = row.get("lo"), row.get("hi")
    if lo is not None and min(vals) < lo:
        return True
    if hi is not None and max(vals) > hi:
        return False
    return None
def collect_from_json(doc_json, result):
    from studio.editor.document import Document
    return collect(Document.from_json(doc_json), result)
def collect(doc, result):
    result = result or {}
    out = [gate_issue(doc, f) for f in result.get("gate") or []]
    card = result.get("card")
    if card:
        out += metric_issues(card)
        for note in card.get("notes") or []:
            if note.startswith("beauty"):
                out.append(Issue("warn", "beauty", note, fixes=["dress"]))
    from studio.toolbox import paths
    out += paths.issues(doc)
    from studio.toolbox import logic
    out += logic.issues(doc)
    from studio.toolbox import stars
    out += stars.issues(doc)
    out += escape_issues(doc)
    out += pocket_issues(doc)
    out += rules_issues(doc)
    from studio.editor import forgeobjects
    out += [Issue("warn", "gate", text, refs=[ref]) for ref, text in
            forgeobjects.pipe_issues(doc)]
    return out
def critic_issues(doc, res):
    if not res:
        return []
    from studio.editor import critic_live, criticfix
    out = []
    for row in res.get("rows") or []:
        if row.state == "ok" or row.key in criticfix.MODE_ROWS or not criticfix.has_fix(row.key):
            continue
        iss = critic_live.issue(res, row.key, doc)
        iss.fixes = ["critic"]
        iss.data.update(row=row.key, label=row.label)
        out.append(iss)
    return out
def button_for(issue):
    if issue.fixes:
        key = issue.fixes[0]
        return key, SHORT.get(key, "Fix it")
    return None, SHOW_ME
def _theme(doc):
    from mapgen import contract
    t = (doc.brief or {}).get("theme")
    return contract.theme_for({"theme": t, "family": (doc.brief or {}).get("family")})
def rules_issues(doc):
    from mapgen import contract, guards
    try:
        layout = doc.to_layout(models=False)
        theme = _theme(doc)
        con = contract.issues(layout, theme)
        fl = guards.flights(layout, guards.reach_set(layout))
        jn = guards.joins(layout)
        flo = guards.floating(layout)
    except Exception:
        return []
    out = []
    for i in con:
        out.append(Issue("fail" if i["refused"] else "warn", "gate", i["text"],
                         refs=piece_refs_named(doc, i["text"])[:1], fixes=["contract_repaint"],
                         data={"class": i["class"], "theme": theme}))
    fam = (doc.brief or {}).get("family")
    for f in fl:
        hard = f["rule"] in guards.hard_rules(f["piece"], fam)
        text = "Stair " + f["text"]
        out.append(Issue("fail" if hard else "warn", "gate", text,
                         refs=piece_refs_named(doc, f["text"])[:1],
                         fixes=["add_cheek"] if f["rule"] == "ST6" else [],
                         data={"side": f.get("side")}))
    for j in jn:
        out.append(Issue("warn", "gate", j["text"], refs=piece_refs_named(doc, j["text"])[:2]))
    m = _m()
    for grp in flo:
        text = "floating: %s rests on nothing (the support graph)" % m.piece_name(grp[0])
        out.append(Issue("warn", "gate", text, refs=piece_refs_named(doc, text)[:1],
                         fixes=["drop_piece", "delete_piece"]))
    return out
def _m():
    from mapgen import v1
    return v1.arenas_module()
def _contract_repaint(doc, issue):
    from mapgen import contract
    if not issue.refs:
        return Change("contract: nothing to repaint")
    p = doc.get(issue.refs[0])
    tex = contract.material(issue.data.get("theme") or "castle", issue.data.get("class"),
                            kind=p.get("kind")) or contract.material(
        issue.data.get("theme") or "castle", issue.data.get("class"))
    return ops.retexture(doc, issue.refs[:1], tex)
def _add_cheek(doc, issue):
    from mapgen import guards
    if not issue.refs:
        return Change("cheek: no flight")
    layout = doc.to_layout(models=False)
    p = dict(doc.get(issue.refs[0]))
    match = [q for q in layout["pieces"] if all(q.get(k) == p.get(k) for k in
                                                  ("kind", "x", "y", "z", "w", "h", "d"))]
    if not match:
        return Change("cheek: the flight is gone")
    add = guards.cheeks(layout, [{"rule": "ST6", "piece": match[0],
                                  "side": issue.data.get("side") or "left"}])
    if not add:
        return Change("cheek: no room beside the flight")
    return ops.insert(doc, [("piece", geo.cleaned(q)) for q in add], "add the flight's cheek")
def pocket_issues(doc):
    from mapgen import landform
    try:
        pts = landform.pockets(doc.to_layout(models=False).get("pieces") or [])
    except Exception:
        return []
    return [Issue("warn", "gate", "pocket: a floor sealed inside a mass at (%d, %d, %d) - only "
                  "a clip reaches it; fill it or open it" % p, points=[p]) for p in pts]
def escape_issues(doc):
    from mapgen import escape
    try:
        layout = doc.to_layout(models=False)
        esc, hid = escape.escape_faults(layout), escape.hiding_faults(layout)
    except Exception:
        return []
    out = []
    for text in esc:
        out.append(Issue("fail", "gate", text, refs=piece_refs_named(doc, text)[:1],
                         fixes=["edge_invisible"]))
    for text in hid:
        out.append(Issue("warn", "gate", text, refs=piece_refs_named(doc, text)[:1]))
    return out
def counts(issues):
    return {"fail": sum(1 for i in issues if i.level == "fail"),
            "warn": sum(1 for i in issues if i.level == "warn")}
def fix(doc, issue, key, texture="stone1"):
    if key not in issue.fixes:
        raise KeyError("no fix %r for this issue" % key)
    if key == "refine":
        return ("refine", issue.data.get("refine"))
    if key == "dress":
        return ("dress", None)
    if key == "critic":
        return ("critic", issue.data.get("row"))
    if key.startswith("star_"):
        from studio.toolbox import stars
        change = stars.fix(doc, issue, key)
        change.label = "Fix: %s" % change.label
        return change
    fn = {"delete_overlap": _delete_overlap, "nudge_apart": _nudge_apart,
          "resolve_all": _resolve_all, "spawn_to_floor": _spawn_to_floor,
          "add_ramp": _add_ramp, "close_slot": _close_slot,
          "contract_repaint": _contract_repaint, "add_cheek": _add_cheek,
          "delete_piece": lambda d, i: ops.delete(d, i.refs[:1]),
          "drop_piece": _drop_piece, "delete_wire": _delete_wire,
          "repaint": lambda d, i: ops.retexture(d, i.refs, texture),
          "edge_invisible": lambda d, i: ops.set_boundary(d, "invisible")}[key]
    change = fn(doc, issue)
    if change is not None and change:
        change.label = "Fix: %s" % change.label
        change.twins = True
    return change
def _drop_piece(doc, issue):
    from studio.ux import magic
    return magic.drop_to_ground(doc, issue.refs[:1])
def _delete_wire(doc, issue):
    from studio.toolbox import logic
    tool = logic.LogicTool(type("S", (), {"doc": doc})())
    return tool.delete_wire(int(issue.data["wire"]))
def _vol(p):
    b = geo.aabb(p)
    return (b[1] - b[0]) * (b[3] - b[2]) * (b[5] - b[4])
def _pair(doc, issue):
    a, b = issue.refs[0], issue.refs[1]
    pa, pb = doc.get(a), doc.get(b)
    return (a, pa, b, pb) if _vol(pa) >= _vol(pb) else (b, pb, a, pa)
def _delete_overlap(doc, issue):
    _, _, small, _ = _pair(doc, issue)
    ch = ops.delete(doc, [small])
    ch.label = "delete the smaller piece"
    return ch
def _clear(doc, piece, skip):
    box = geo.aabb(piece)
    for ref in doc.refs("piece"):
        if ref in skip:
            continue
        if geo.overlap_volume(box, geo.aabb(doc.get(ref))) > 1.0:
            return False
    return True
def _nudge_apart(doc, issue):
    big_ref, big, small_ref, small = _pair(doc, issue)
    A, B = geo.aabb(big), geo.aabb(small)
    moves = []
    for axis, lo, hi, step in ((0, 0, 1, geo.GRID), (2, 4, 5, geo.GRID), (1, 2, 3, geo.YGRID)):
        plus = A[hi] - B[lo]
        minus = A[lo] - B[hi]
        for d in (plus, minus):
            d = math.ceil(abs(d) / step) * step * (1 if d > 0 else -1)
            if d:
                v = [0, 0, 0]
                v[axis] = d
                moves.append((abs(d), v))
    for _, v in sorted(moves, key=lambda t: (t[0], t[1][1] < 0)):
        moved = geo.translated(small, v[0], v[1], v[2])
        if _clear(doc, moved, {small_ref}):
            ch = ops.move(doc, [small_ref], v[0], v[1], v[2], snap_on=False)
            ch.label = "nudge %s by (%d, %d, %d)" % (small["kind"], v[0], v[1], v[2])
            return ch
    return Change("nudge: no free place next to it")
def _resolve_all(doc, issue):
    from mapgen import solids
    from studio.toolbox.brushes import replace_pieces
    refs = doc.refs("piece")
    painted, _ = solids.resolve([dict(doc.get(r)) for r in refs])
    if [geo.cleaned(p) for p in painted] == [geo.cleaned(doc.get(r)) for r in refs]:
        return Change("resolve: nothing to change")
    return replace_pieces(doc, refs, [geo.cleaned(p) for p in painted],
                          "resolve every overlap (%d pieces)" % len(painted))
def _two_way(doc):
    from mapgen.metrics import graph
    from mapgen.metrics.world import World
    lay = doc.to_layout()
    lay.setdefault("key", "generated")
    w = World(lay)
    start = w.node_of(lay["spawns"][0]) if lay.get("spawns") else 0
    back = graph.bfs(w.radj, [start])
    return w, set(i for i, d in enumerate(back) if d >= 0)
def _spawn_to_floor(doc, issue):
    ref = issue.refs[0]
    spot = doc.get(ref)
    w, good = _two_way(doc)
    if not good:
        return Change("spawn: no floor reached both ways")
    taken = set((s["x"], s["z"]) for r, s in doc.items["spawn"] if r != ref[1])
    def score(i):
        x, y, z = w.node_xyz(i)
        return (math.hypot(x - spot["x"], z - spot["z"]) + abs(y - spot.get("y", 0)), i)
    for i in sorted(good, key=score):
        if not w.flat[i]:
            continue
        x, y, z = w.node_xyz(i)
        gx, gz = geo.snap(x - 100, geo.GRID) + 100, geo.snap(z - 100, geo.GRID) + 100
        if (gx, gz) in taken:
            continue
        new = dict(spot, x=int(gx), y=int(y), z=int(gz))
        ch = Change("move spawn %s onto the floor at (%d, %d, %d)" % (ref[1], gx, y, gz),
                    [("replace", ref, dict(spot), new)], select=[ref])
        return ch
    return Change("spawn: no free floor")
QUARTER_UP = geo.QUARTER_UP
def _add_ramp(doc, issue):
    w, good = _two_way(doc)
    x, z, y = issue.data["cell"]
    start = w.index.get((x // 100, z // 100, y))
    trapped = set()
    if start is None:
        start = w.node_of({"x": x + 50, "y": y, "z": z + 50})
    todo = [start]
    while todo:
        u = todo.pop()
        if u in trapped or u in good:
            continue
        trapped.add(u)
        todo += w.adj2[u]
    heights = {}
    for i in good:
        gx, gz, h = w.nodes[i]
        heights.setdefault((gx, gz), []).append(h)
    cands = []
    for u in trapped:
        gx, gz, h = w.nodes[u]
        for yaw, (ux, uz) in QUARTER_UP.items():
            for h2 in heights.get((gx + ux, gz + uz), ()):
                rise = h2 - h
                if 200 < rise <= 1200:
                    cands.append((rise, gx, gz, h, h2, yaw, ux, uz))
    cands.sort()
    for rise, gx, gz, h, h2, yaw, ux, uz in cands[:60]:
        length = max(400, int(math.ceil(2 * rise / 200.0)) * 200)
        if ux:
            edge = geo.snap((gx + (1 if ux > 0 else 0)) * 100, geo.GRID)
            x0, x1 = (edge - length, edge) if ux > 0 else (edge, edge + length)
            cz = geo.snap(gz * 100 + 50, geo.GRID)
            z0, z1 = cz - 200, cz + 200
        else:
            edge = geo.snap((gz + (1 if uz > 0 else 0)) * 100, geo.GRID)
            z0, z1 = (edge - length, edge) if uz > 0 else (edge, edge + length)
            cx = geo.snap(gx * 100 + 50, geo.GRID)
            x0, x1 = cx - 200, cx + 200
        w_, d_ = (x1 - x0, z1 - z0)
        if yaw in (90, 270):
            w_, d_ = d_, w_
        ramp = {"kind": "ramp", "tex": _tex_near(doc, gx * 100 + 50, gz * 100 + 50),
                "x": (x0 + x1) // 2, "y": h, "z": (z0 + z1) // 2, "w": w_, "h": rise, "d": d_,
                "yaw": yaw, "tag": "fix.ramp"}
        if _clear(doc, ramp, set()):
            ch = ops.insert(doc, [("piece", geo.cleaned(ramp))], "add a ramp up %d" % rise)
            return ch
    return Change("ramp: no room for one in the pit")
def _tex_near(doc, x, z):
    best = None
    for ref in doc.refs("piece"):
        p = doc.get(ref)
        b = geo.aabb(p)
        if b[0] <= x <= b[1] and b[4] <= z <= b[5]:
            if best is None or p["y"] + p["h"] > best["y"] + best["h"]:
                best = p
    return best["tex"] if best else "stone1"
def _close_slot(doc, issue):
    upper, lower = issue.refs[0], issue.refs[1]
    pu, pl = doc.get(upper), doc.get(lower)
    gap = pu["y"] - (pl["y"] + pl["h"])
    if gap <= 0:
        return Change("slot: already closed")
    ch = ops.move(doc, [upper], 0, -gap, 0, snap_on=False)
    ch.label = "close the %d slot" % gap
    return ch
