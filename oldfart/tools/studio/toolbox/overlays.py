import collections
import math
from mapgen.metrics import mario
from mapgen.metrics.world import World, Refused
G = mario.CELL
LIFT = 6.0
LEVELS = 6
GOOD = (0.30, 0.85, 0.45, 0.42)
BAD = (0.95, 0.28, 0.25, 0.55)
SEEN = (1.00, 0.84, 0.25, 0.40)
HIDDEN = (0.25, 0.45, 0.95, 0.22)
LINE = (1.00, 0.84, 0.25, 0.85)
RISK = (0.95, 0.28, 0.25, 0.95)
DEATH = (0.95, 0.20, 0.20, 0.95)
class Layer:
    def __init__(self, key, title):
        self.key = key
        self.title = title
        self.quads = []
        self.lines = []
        self.dots = []
        self.labels = []
        self.legend = []
        self.note = ""
        self.facts = {}
    def __len__(self):
        return len(self.quads) + len(self.lines) + len(self.dots) + len(self.labels)
    def quad(self, x0, x1, z0, z1, y, rgba):
        y = y + LIFT
        self.quads.append(([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], rgba))
    def line(self, a, b, rgba, width=2.0):
        self.lines.append((tuple(a), tuple(b), rgba, width))
    def dot(self, p, rgba, radius=6.0):
        self.dots.append((tuple(p), rgba, radius))
    def label(self, p, text, rgba=(1, 1, 1, 1)):
        self.labels.append((tuple(p), text, rgba))
def without_points(layer, points, near=1.0):
    if not points or not len(layer):
        return layer
    pts = [(float(x), float(z)) for x, z in points]
    def on(p):
        return any(abs(p[0] - x) <= near and abs(p[2] - z) <= near for x, z in pts)
    out = Layer(layer.key, layer.title)
    out.quads = list(layer.quads)
    out.lines = [ln for ln in layer.lines if not (on(ln[0]) or on(ln[1]))]
    out.dots = [d for d in layer.dots if not on(d[0])]
    out.labels = [lb for lb in layer.labels if not on(lb[0])]
    out.legend, out.note, out.facts = layer.legend, layer.note, layer.facts
    return out
def ramp(t):
    t = max(0.0, min(1.0, t))
    stops = [(0.0, (0.20, 0.35, 0.95)), (0.35, (0.15, 0.80, 0.90)),
             (0.7, (1.00, 0.85, 0.20)), (1.0, (0.95, 0.20, 0.15))]
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            f = (t - a) / (b - a)
            return tuple(ca[i] + (cb[i] - ca[i]) * f for i in range(3)) + (0.55,)
    return stops[-1][1] + (0.55,)
def _world(layout):
    arena = dict(layout)
    arena.setdefault("key", "generated")
    return World(arena)
def _strips(cells, layer, colour_of, size=G):
    rows = collections.defaultdict(list)
    for (gx, gz), (y, key) in cells.items():
        rows[gz].append((gx, y, key))
    runs = collections.defaultdict(list)
    for gz, row in rows.items():
        row.sort(key=lambda t: t[0])
        start = prev = None
        for gx, y, key in row + [(None, None, None)]:
            if start is not None and (gx is None or gx != prev[0] + 1 or y != prev[1]
                                      or key != prev[2]):
                runs[(start[0], prev[0] + 1, start[1], start[2])].append(gz)
                start = None
            if gx is None:
                break
            if start is None:
                start = (gx, y, key)
            prev = (gx, y, key)
    for (x0, x1, y, key), zs in sorted(runs.items(), key=lambda kv: (kv[0][0], kv[0][1],
                                                                    kv[0][2], str(kv[0][3]))):
        zs.sort()
        a = zs[0]
        for i in range(1, len(zs) + 1):
            if i == len(zs) or zs[i] != zs[i - 1] + 1:
                layer.quad(x0 * size, x1 * size, a * size, (zs[i - 1] + 1) * size, y,
                           colour_of(key))
                if i < len(zs):
                    a = zs[i]
def _empty(key, title, why):
    layer = Layer(key, title)
    layer.note = why
    return layer
def reachability(layout):
    try:
        w = _world(layout)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("reach", "Reachability", "cannot measure: %s" % why)
    reached = set(w.nodes)
    cells = {}
    for (gx, gz, h) in w.all_cells:
        ok = (gx, gz, h) in reached
        have = cells.get((gx, gz))
        if have is None or h > have[0] or (h == have[0] and ok):
            cells[(gx, gz)] = (h, ok)
    layer = Layer("reach", "Reachability")
    _strips(cells, layer, lambda ok: GOOD if ok else BAD)
    n_bad = sum(1 for _, ok in cells.values() if not ok)
    layer.legend = [(GOOD, "reached from spawn 1"), (BAD, "can stand, never gets there")]
    layer.facts = {"columns": len(cells), "unreached": n_bad}
    layer.note = ("every floor is reached" if not n_bad else
                  "%d cells Mario could stand on but never gets to - wall and pillar tops "
                  "often are; a floor meant for play must not be" % n_bad)
    for i, s in enumerate(layout.get("spawns") or []):
        layer.dot((s["x"], s.get("y", 0) + 20, s["z"]), (1, 1, 1, 0.9), 4)
    return layer
def sightlines(layout, eye=None, points=180, reach=None):
    from mapgen.metrics import vis
    try:
        w = _world(layout)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("sight", "Sightlines", "cannot measure: %s" % why)
    reach = reach or mario.SIGHT_FIGHT * 3
    layer = Layer("sight", "Sightlines")
    if eye is not None:
        e = (eye[0], eye[1] + mario.EYE, eye[2])
        cells = {}
        seen = 0
        for (gx, gz), i in w.columns.items():
            h = w.nodes[i][2]
            p = ((gx + .5) * G, h + mario.EYE, (gz + .5) * G)
            if math.hypot(p[0] - e[0], p[2] - e[2]) > reach:
                continue
            ok = not w.blocked(e, p)
            seen += ok
            cells[(gx, gz)] = (h, ok)
        _strips(cells, layer, lambda ok: SEEN if ok else HIDDEN)
        layer.dot(e, (1, 1, 1, 1), 7)
        layer.legend = [(SEEN, "seen from the eye (Mario's eye height, %d)" % mario.EYE),
                        (HIDDEN, "hidden from it")]
        layer.facts = {"seen": seen, "cells": len(cells)}
        layer.note = "%d of %d floor cells within %d see this point" % (seen, len(cells), reach)
        return layer
    sample, _ = vis.sample_points(w, k=points, seed=1)
    res = vis.sightlines(w, sample, depth=40)
    longest = res.get("sightline_max_at")
    pairs = sorted(res.get("_visible_pairs", []), key=lambda t: -t[2])
    shown = 0
    for i, j, d in pairs:
        if d <= mario.SIGHT_FIGHT or shown >= 60:
            break
        layer.line(sample[i], sample[j], (1.0, 0.84, 0.25, 0.35 + 0.5 * min(1.0, d / 6000.0)),
                   1.5)
        shown += 1
    if longest:
        layer.line(longest[0], longest[1], BAD, 3.0)
        layer.label(longest[1], "%d" % res["sightline_max"], BAD)
    layer.legend = [(LINE, "an open line over %d (a fight's range)" % mario.SIGHT_FIGHT),
                    (BAD, "the longest open line")]
    layer.facts = {"sightline_max": res["sightline_max"],
                   "openness": round(res["openness"], 3),
                   "open_pairs_over_2400": round(res["open_pairs_over_2400"], 3)}
    layer.note = ("longest open line %d; %.0f%% of sampled pairs see each other"
                  % (res["sightline_max"], 100 * res["openness"]))
    return layer
def exposure(layout, points=160):
    from mapgen.metrics import structure, vis
    try:
        w = _world(layout)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("exposure", "Spawn safety", "cannot measure: %s" % why)
    spawns = list(layout.get("spawns") or [])
    layer = Layer("exposure", "Spawn safety")
    if not spawns:
        layer.note = "the map has no spawns yet"
        return layer
    sample, _ = vis.sample_points(w, k=points, seed=1)
    groups = structure.spawn_groups(spawns)
    survey = [p for p in ((layout.get("survey") or {}).get("points") or []) if isinstance(p, dict)]
    risky, pairs = vis.spawn_kill_risk(w, spawns, groups, survey)
    worst = 0.0
    shares = []
    for i, s in enumerate(spawns):
        share = vis.exposure(w, s, sample)
        shares.append(share)
        worst = max(worst, share)
        p = (s["x"], s.get("y", 0) + 30, s["z"])
        layer.dot(p, ramp(min(1.0, share / 0.5)), 9 if i in risky else 7)
        layer.label((s["x"], s.get("y", 0) + 260, s["z"]), "%d%%" % round(100 * share),
                    RISK if i in risky else (1, 1, 1, 0.95))
    for i, j, d in pairs:
        a, b = spawns[i], spawns[j]
        layer.line((a["x"], a.get("y", 0) + mario.EYE, a["z"]),
                   (b["x"], b.get("y", 0) + mario.EYE, b["z"]), RISK, 2.5)
    layer.legend = [(ramp(0.0), "seen by few (safe)"), (ramp(1.0), "seen by half the map or more"),
                    (RISK, "another base sees it within 1500 (spawn kill)")]
    layer.facts = {"spawns": len(spawns), "risky": len(risky), "worst": round(worst, 3),
                   "mean": round(sum(shares) / len(shares), 3)}
    layer.note = ("%d spawn%s at risk; the most exposed is seen by %d%% of the map"
                  % (len(risky), "" if len(risky) == 1 else "s", round(100 * worst)))
    return layer
def heatmap(layout, runs=1, seconds=60, players=16, what="heat"):
    from mapgen.sim import bots
    try:
        w = _world(layout)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("heat", "Heatmap", "cannot measure: %s" % why)
    if not layout.get("spawns"):
        return _empty("heat", "Heatmap", "the map has no spawns yet")
    arena = dict(layout)
    arena.setdefault("key", "generated")
    res = bots.simulate(arena, runs=runs, seconds=seconds, players=players, world=w)
    counts = res["heat"] if what == "heat" else res["deaths"]
    layer = Layer("heat" if what == "heat" else "deaths",
                  "Heatmap" if what == "heat" else "Deaths")
    bins = collections.Counter()
    tops = {}
    for (gx, gz), c in counts.items():
        i = w.columns.get((gx, gz))
        if i is None:
            continue
        b = (gx // 2, gz // 2)
        bins[b] += c
        tops[b] = max(tops.get(b, -1e9), w.nodes[i][2])
    top = max(bins.values()) if bins else 0
    cells = {}
    for b, c in bins.items():
        level = min(LEVELS - 1, int(LEVELS * c / float(top))) if top else 0
        cells[b] = (tops[b], level)
    _strips(cells, layer, lambda level: ramp((level + 0.5) / LEVELS), size=2 * G)
    m = res["metrics"]
    layer.legend = [(ramp(0.05), "rarely"), (ramp(0.5), "often"), (ramp(0.95), "the busiest")]
    layer.facts = dict(m)
    layer.note = ("%d bots, %d s x %d: %.1f kills a minute, %.0f%% spawn kills, %.0f%% of the "
                  "floor unused" % (players, seconds, runs, m.get("kills_per_min") or 0,
                                    100 * (m.get("spawn_kill_share") or 0),
                                    100 * (m.get("unused_floor") or 0)))
    return layer
STAR = (1.00, 0.86, 0.15, 0.95)
WATER = (0.25, 0.55, 1.00, 0.35)
ITEM_COLOURS = {"enemies": (0.95, 0.30, 0.25, 0.95), "hazards": (1.00, 0.55, 0.15, 0.95),
                "movers": (0.35, 0.80, 1.00, 0.95), "items": (1.00, 0.90, 0.30, 0.95),
                "scenery": (0.55, 0.90, 0.45, 0.95), "other": (0.85, 0.85, 0.85, 0.95)}
def gameplay(layout):
    from mapgen import gameplay as gp
    layer = Layer("gameplay", "Stars, water, items")
    for w in layout.get("water") or []:
        x0, z0, x1, z1, top = w[:5]
        layer.quad(x0, x1, z0, z1, top - LIFT, WATER)
        layer.label(((x0 + x1) / 2.0, top + 60, (z0 + z1) / 2.0), "water %d" % top, WATER)
    for st in layout.get("stars") or []:
        p = (st["x"], st["y"], st["z"])
        layer.dot(p, STAR, 9)
        layer.label((st["x"], st["y"] + 140, st["z"]),
                    "star %d: %s%s, grade %d" % (
                        st.get("id", 0), ("\"%s\" - " % st["name"]) if st.get("name") else "",
                        st["kind"], st["grade"]), STAR)
    cats = collections.Counter()
    for o in layout.get("objects") or []:
        cat = gp.category_of(o.get("key")) or "other"
        cats[cat] += 1
        layer.dot((o["x"], o["y"] + 40, o["z"]), ITEM_COLOURS.get(cat, ITEM_COLOURS["other"]), 5)
    layer.legend = [(STAR, "bonus star (kind, grade 1 easy .. 4 tricky)"),
                    (WATER, "water (its surface)")] + [
        (ITEM_COLOURS[c], "%s x%d" % (c, n)) for c, n in sorted(cats.items())]
    g = layout.get("gameplay") or {}
    layer.facts = {"stars": len(layout.get("stars") or []), "water": len(layout.get("water") or []),
                   "items": sum(cats.values()), "patterns": list(g.get("patterns") or [])}
    layer.note = ("%d stars, %d water bodies, %d Forge items%s" % (
        layer.facts["stars"], layer.facts["water"], layer.facts["items"],
        (" (" + ", ".join(layer.facts["patterns"]) + ")") if layer.facts["patterns"] else ""))
    return layer
ROUTE_COLOURS = [(0.30, 0.85, 0.45, 0.95), (0.35, 0.75, 1.00, 0.95), (0.85, 0.55, 1.00, 0.95),
                 (1.00, 0.70, 0.30, 0.95), (0.95, 0.95, 0.95, 0.95)]
MOVE = (1.00, 0.45, 0.85, 0.95)
EXIT = (0.30, 0.85, 0.45, 0.95)
def _fun_of(layout, full=False):
    from mapgen.metrics import fun, graph, structure
    w = _world(layout)
    spawns = list(layout.get("spawns") or [])
    sn = [w.node_of(s) for s in spawns]
    groups = structure.spawn_groups(spawns) if spawns else []
    fields = [graph.bfs(w.adj, [sn[i] for i in g]) for g in groups]
    centre = w.centre_node()
    m, extra = {}, {}
    arena = dict(layout)
    arena.setdefault("key", "generated")
    fun.cheap(w, arena, None, m, extra, sn, groups, fields, centre)
    if full:
        fun.full(w, arena, None, m, extra, sn, groups, centre)
    extra["centre"] = centre
    return w, m, extra
def _pt(w, i, lift=40):
    x, y, z = w.node_xyz(i)
    return (x, y + lift, z)
def routes(layout):
    try:
        w, m, extra = _fun_of(layout)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("routes", "Routes and shortcuts", "cannot measure: %s" % why)
    layer = Layer("routes", "Routes and shortcuts")
    centre = extra["centre"]
    shown = None
    for (gi, t), rs in sorted((extra.get("fun_routes") or {}).items(),
                              key=lambda kv: (kv[0][0], kv[0][1] != centre)):
        shown = rs
        break
    for k, r in enumerate(shown or []):
        col = ROUTE_COLOURS[k % len(ROUTE_COLOURS)]
        pts = [_pt(w, i) for i in r[::2]] + [_pt(w, r[-1])]
        for a, b in zip(pts, pts[1:]):
            layer.line(a, b, col, 3.0 if k == 0 else 2.0)
        layer.label(pts[len(pts) // 2], "route %d" % (k + 1), col)
    for verb, saving, u, v, at in extra.get("fun_shortcuts") or []:
        a = _pt(w, u, 60)
        if v is not None:
            b = _pt(w, v, 60)
        else:
            b = ((at[0] + .5) * G, a[1] + 300, (at[1] + .5) * G)
        layer.line(a, b, MOVE, 2.0)
        layer.dot(b, MOVE, 4)
        layer.label(b, verb if saving == float("inf") else "%s -%.1f s" % (verb, saving), MOVE)
    n = m.get("lf1_viable_routes")
    layer.legend = [(ROUTE_COLOURS[0], "the fastest route to the centre"),
                    (ROUTE_COLOURS[1], "another route within 1.3x of it"),
                    (MOVE, "a shortcut an SM64 move opens")]
    layer.facts = {"viable_routes": n, "shortcuts": m.get("vm1_shortcuts"),
                   "theme": m.get("vm3_theme"), "theme_share": m.get("vm3_theme_share")}
    layer.note = ("%s viable route%s from the first base (2-4 is a choice); %d move-gated "
                  "shortcut%s%s" % ("no" if not n else n, "" if n == 1 else "s",
                                    m.get("vm1_shortcuts") or 0,
                                    "" if m.get("vm1_shortcuts") == 1 else "s",
                                    (", mostly %s" % m["vm3_theme"]) if m.get("vm3_theme") else ""))
    return layer
def flanks(layout):
    try:
        w, m, extra = _fun_of(layout, full=True)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("flanks", "Flank sightlines", "cannot measure: %s" % why)
    from mapgen.metrics import fun
    layer = Layer("flanks", "Flank sightlines")
    holds = extra.get("fun_hold_spots") or []
    flank = extra.get("fun_flank")
    for h in holds:
        layer.dot(h, (1, 1, 1, 0.95), 8)
        layer.label((h[0], h[1] + 200, h[2]), "hold spot", (1, 1, 1, 0.95))
    if flank:
        pts = [_pt(w, i) for i in flank[::2]]
        for a, b in zip(pts, pts[1:]):
            layer.line(a, b, ROUTE_COLOURS[1], 2.5)
        for q in fun._tail(w, flank):
            for h in holds:
                if not w.blocked(h, q):
                    layer.line(h, q, RISK, 1.0)
    share, angle = m.get("lf3_flank_unseen"), m.get("lf4_flank_angle")
    layer.legend = [((1, 1, 1, 0.95), "a hold spot: sees most of the main route"),
                    (ROUTE_COLOURS[1], "the flank route"),
                    (RISK, "a hold spot sees the flank here")]
    layer.facts = {"flank_unseen": share, "flank_angle": angle}
    layer.note = ("no second route to flank by" if share is None else
                  "the flank's approach is %d%% unseen (60%% wanted) and arrives %d degrees off "
                  "the main way (60 wanted)" % (round(100 * share), angle or 0))
    return layer
def pens(layout):
    try:
        w, m, extra = _fun_of(layout, full=True)
    except (Refused, KeyError, ValueError, IndexError) as why:
        return _empty("pens", "Spawn pens", "cannot measure: %s" % why)
    from mapgen.metrics import graph, structure
    layer = Layer("pens", "Spawn pens")
    spawns = list(layout.get("spawns") or [])
    groups = structure.spawn_groups(spawns) if spawns else []
    if len(groups) != 2:
        layer.note = "a pen is a two-team question; this map has %d bases" % len(groups)
        return layer
    sn = [w.node_of(s) for s in spawns]
    centre = extra["centre"]
    for (worst, at), g in zip(extra.get("fun_pens") or [], groups):
        zone = structure.base_zone(w, [sn[i] for i in g])
        exits = structure.exits(w, zone, centre, diagonal=True)
        for ex in exits:
            mid = _pt(w, ex[len(ex) // 2], 30)
            layer.dot(mid, EXIT, 7)
            if at is not None and not w.blocked(at, (mid[0], mid[1] + 90, mid[2])):
                layer.line(at, (mid[0], mid[1] + 90, mid[2]), RISK, 2.0)
        if at is not None:
            layer.dot(at, RISK, 9)
            layer.label((at[0], at[1] + 200, at[2]), "%d way%s out unseen" % (
                worst, "" if worst == 1 else "s"), RISK if worst < 2 else EXIT)
    worst = m.get("cb2_unseen_exits")
    layer.legend = [(EXIT, "a way out of a base"), (RISK, "the camper spot that sees most of them")]
    layer.facts = {"unseen_exits": worst}
    layer.note = ("a pen: one camper spot leaves only %d way%s out unseen (2 wanted)" % (
        worst, "" if worst == 1 else "s") if worst is not None and worst < 2 else
        "no pen: every base keeps two ways out no single camper sees")
    return layer
CHEAP = ("reach", "sight", "exposure", "gameplay", "routes", "flanks", "pens")
ON_CLICK = ("heat", "deaths")
IDLE_MS = 600
STALE_NOTE = "measured before your last edit - press Measure again"
def after_edit(wanted):
    return ([k for k in wanted if k not in ON_CLICK], [k for k in wanted if k in ON_CLICK])
LAYERS = (("reach", "Reachability", reachability), ("sight", "Sightlines", sightlines),
          ("exposure", "Spawn safety", exposure), ("heat", "Heatmap (bots)", heatmap),
          ("deaths", "Deaths (bots)", lambda layout: heatmap(layout, what="deaths")),
          ("gameplay", "Stars, water, items", gameplay),
          ("routes", "Routes and shortcuts", routes), ("flanks", "Flank sightlines", flanks),
          ("pens", "Spawn pens", pens))
def guide_axes(symmetry, y=0.0, radius=4000.0):
    layer = Layer("symmetry", "Symmetry")
    col = (0.35, 0.80, 1.00, 0.9)
    for (a, b) in symmetry.axes(radius):
        layer.line((a[0], y, a[1]), (b[0], y, b[1]), col, 2.0)
    if symmetry:
        layer.dot((symmetry.centre[0], y, symmetry.centre[1]), col, 6)
        layer.label((symmetry.centre[0], y + 120, symmetry.centre[1]),
                    symmetry.mode.replace("_", " "), col)
    layer.legend = [(col, "symmetry: edits repeat across these lines")] if symmetry else []
    return layer
def guide_measure(m):
    from . import measure
    layer = Layer("measure", "Measure")
    col = (1.0, 1.0, 1.0, 0.95) if m.ok else BAD
    pts = m.points
    for a, b in zip(pts, pts[1:]):
        layer.line(a, b, col, 2.5)
    for p in pts:
        layer.dot(p, col, 4)
    if pts and m.ok:
        t = m.times()
        layer.label(pts[-1], "  ".join("%s %.1f s" % (measure.WORDS[k], t[k])
                                       for k in measure.SPEEDS), col)
    elif pts:
        layer.label(pts[-1], m.why, BAD)
    return layer
def guide_box(box, title="Region", rgba=(0.35, 0.80, 1.0, 0.9)):
    layer = Layer("region", title)
    x0, x1, y0, y1, z0, z1 = box
    c = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    for i in range(8):
        for j in range(i + 1, 8):
            if sum(1 for a, b in zip(c[i], c[j]) if a != b) == 1:
                layer.line(c[i], c[j], rgba, 2.0)
    return layer
def project(layer, to_pixel):
    out = {"quads": [], "lines": [], "dots": [], "labels": []}
    cache = {}
    def px(p):
        if p not in cache:
            q = to_pixel(p)
            cache[p] = None if q is None else (q[0], q[1])
        return cache[p]
    for pts, rgba in layer.quads:
        q = [px(p) for p in pts]
        if all(v is not None for v in q):
            out["quads"].append((q, rgba))
    for a, b, rgba, w in layer.lines:
        pa, pb = px(a), px(b)
        if pa is not None and pb is not None:
            out["lines"].append((pa, pb, rgba, w))
    for p, rgba, r in layer.dots:
        q = px(p)
        if q is not None:
            out["dots"].append((q, rgba, r))
    for p, text, rgba in layer.labels:
        q = px(p)
        if q is not None:
            out["labels"].append((q, text, rgba))
    return out
