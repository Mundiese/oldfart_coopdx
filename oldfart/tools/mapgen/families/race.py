from .. import kit, v1
from ..paths import common, road, shape
from ..paths.road import Track, marker, q
START_KIND = 1
def race_world(arena):
    start = next((m for m in arena.get("markers") or [] if m.get("kind") == START_KIND), None)
    if start is None:
        return None
    spawns = arena.get("spawns") or []
    yaw = spawns[0].get("yaw", start.get("yaw", 0)) if spawns else start.get("yaw", 0)
    return {"x": start["x"], "y": start.get("y", 0), "z": start["z"], "yaw": yaw}
def curves_on(track, brief):
    from ..brief import dna
    want, avoid = brief["features"]["want"], brief["features"]["avoid"]
    if "curves" in avoid or dna(brief, "complexity") < 0.3:
        return
    track.round = True
    track.banked = "curves" in want
FAMILY = "race"
DEFAULTS = {"symmetry": "none", "verticality": "low", "edge": "walled"}
MODES = ["shellrace"]
SHELL = 1920
LAP_S = {"tiny": 30, "small": 33, "medium": 38, "large": 42, "huge": 45}
ROW_OFFSETS = (-750, -450, -150, 150, 450, 750)
START_BACK = 3100
START_AHEAD = 3000
SHORTCUT_WORDS = ("jump", "jumps", "shortcut", "shortcut_ramp", "shortcut_jump", "void_gaps",
                  "jump_pads")
def road_width(players):
    w = 1400 + 50 * max(0, players - 8)
    return max(1600, int(-(-w // 400) * 400))
def draw_params(brief, r, notes):
    want, avoid = common.want_avoid(brief)
    P = {}
    P["W"] = road_width(brief["players"])
    P["C"] = r.choice([c for c in (3200, 3600, 3600, 4000) if c - P["W"] >= 1200] or [P["W"] + 1200])
    lap = LAP_S[common.size_name(brief["size"])]
    lap += {"slow": 2, "normal": 0, "fast": -2}.get(brief["pace"], 0)
    P["lap_s"] = max(30, min(45, lap))
    P["vert"] = brief["verticality"]
    P["fig8"] = ("figure_eight" in want) or ("figure_eight" not in avoid and P["vert"] in
                                              ("medium", "high") and r.random() < 0.3)
    if "bridge" in want and not P["fig8"]:
        P["bridge"] = True
    else:
        P["bridge"] = "bridge" not in avoid and not P["fig8"] and r.random() < 0.5
    wants_short = any(w in want for w in SHORTCUT_WORDS)
    avoids_short = any(w in avoid for w in SHORTCUT_WORDS)
    P["shortcut"] = wants_short or (not avoids_short and r.random() < 0.75)
    if P["fig8"] and not wants_short:
        P["shortcut"] = P["shortcut"] and r.random() < 0.5
    P["chicane"] = "chicane" not in avoid
    P["gap"] = {"easy": 1000, "normal": 1200, "hard": 1200}.get(brief["difficulty"], 1200)
    if P["vert"] == "flat":
        P["H"] = 0
    elif P["vert"] == "low":
        P["H"] = r.choice((400, 600))
    elif P["vert"] == "medium":
        P["H"] = r.choice((600, 800))
    else:
        P["H"] = r.choice((1100, 1300, 1500))
    if P["bridge"]:
        P["H"] = max(P["H"], 600)
    P["ratio"] = 0.5 if P["vert"] == "high" else 1 / 3.0
    return P
def _start_run(track, cyc, avoid_nodes, start_where=None):
    best = None
    n = len(cyc)
    need = START_BACK + START_AHEAD + track.W // 2
    for k0, cnt, d in shape.runs(cyc):
        if cnt * track.C < need:
            continue
        ids = [(k0 + t) % n for t in range(cnt + 1)]
        if any(i in avoid_nodes for i in ids):
            continue
        nd = track.nodes[k0]
        mid = (nd.x + d[0] * cnt * track.C / 2.0, nd.z + d[1] * cnt * track.C / 2.0)
        score = cnt
        if start_where is not None:
            s = common.compass_score(mid[0], mid[1], start_where)
            if s is not None:
                score = s
        if best is None or score > best[0]:
            best = (score, k0, cnt)
    return None if best is None else (best[1], best[2])
def try_shape(brief, P, r, span_x, span_z):
    target = P["lap_s"] * SHELL / float(P["C"])
    lo, hi = int(target * 0.9), int(target * 1.1) + 1
    lo = max(lo, int(30 * SHELL / P["C"]))
    hi = min(hi, int(45 * SHELL / P["C"]))
    if P["fig8"]:
        f = shape.figure_eight(r, max(3, span_x // 2), max(3, span_z // 2), tries=10,
                               target=target)
        if not f:
            return "no figure eight"
        pts, a, b = f
        if not lo <= len(pts) <= hi:
            return "lap length"
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        if max(xs) - min(xs) > span_x or max(zs) - min(zs) > span_z:
            return "too big"
        return pts, None, (a, b)
    cells = shape.rect_union(r, span_x, span_z, pieces=r.randint(1, 3),
                             target=target - (2 if P["shortcut"] else 0),
                             min_side=4 if P["shortcut"] else 2)
    mouth = None
    if P["shortcut"]:
        cells, mouth = shape.add_bump(cells, r)
        if mouth is None:
            return "no room for the shortcut"
    per = shape.perimeter(cells)
    if not lo <= per <= hi:
        return "lap length"
    x0, x1, z0, z1 = shape.bbox(cells)
    if x1 - x0 + 1 > span_x or z1 - z0 + 1 > span_z:
        return "too big"
    pts = shape.boundary_cycle(cells)
    if len(shape.corners_of(pts)) < 6:
        return "fewer than six corners"
    long_runs = [cnt for _, cnt, _ in shape.runs(pts) if cnt * P["C"] >= 6000]
    if len(long_runs) < 2:
        return "fewer than two overtaking straights"
    return pts, mouth, None
FOOT_MODES = ("line", "flood", "downhill")
FOOT_S = {"tiny": 40, "small": 50, "medium": 60, "large": 75, "huge": 90}
def wants_point_to_point(brief):
    want, _ = common.want_avoid(brief)
    return "point_to_point" in want or any(m in FOOT_MODES for m in brief["modes"])
def build(brief, streams, reference=False):
    if "line" in brief["modes"] and "flood" not in brief["modes"]:
        return build_rlgl(brief, streams)
    if wants_point_to_point(brief):
        return build_point_to_point(brief, streams)
    notes = []
    lines = []
    r = streams("track")
    P = draw_params(brief, r, notes)
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    level = brief["level"]
    info = common.level_info(level)
    base = 0 if info["floor"] is None else 400
    half = min(info["half"], v1.arenas_module().BOUND)
    span = int(2 * (half - P["W"] // 2 - 900) // P["C"])
    anchors = {a["what"]: a for a in brief["anchors"]}
    start_where = None
    for key in ("start_line", "world_spawn", "spawns", "spawn"):
        if key in anchors:
            start_where = anchors[key]["where"]
            break
    track = None
    why = {}
    for attempt in range(900):
        if attempt and attempt % 300 == 0:
            P = draw_params(brief, r, [])
            span = int(2 * (half - P["W"] // 2 - 900) // P["C"])
        got = try_shape(brief, P, r, span, span)
        if isinstance(got, str):
            why[got] = why.get(got, 0) + 1
            continue
        pts, mouth, lobes = got
        t = Track(pts, P["C"], P["W"], closed=True, ratio=P["ratio"])
        curves_on(t, brief)
        n = len(t.nodes)
        bump_nodes = set()
        chord = None
        if mouth:
            ka = next(i for i, nd in enumerate(t.nodes) if nd.v == mouth[0])
            kb = next(i for i, nd in enumerate(t.nodes) if nd.v == mouth[1])
            k = ka
            while True:
                bump_nodes.add(k)
                if k == kb:
                    break
                k = (k + 1) % n
            chord = (ka, kb)
        cross = [i for i, nd in enumerate(t.nodes) if nd.crossing]
        near_cross = set()
        for c in cross:
            for dk in (-1, 0, 1):
                near_cross.add((c + dk) % n)
        st = _start_run(t, pts, bump_nodes | near_cross, start_where)
        if st is None:
            why["no start straight"] = why.get("no start straight", 0) + 1
            continue
        k0, cnt = st
        reach = (START_BACK + START_AHEAD + P["W"]) // P["C"] + 1
        start_nodes = set((k0 + i) % n for i in range(-1, min(cnt, reach) + 1))
        if not elevate(t, P, r, base, start_nodes, bump_nodes, cross, lines, anchors):
            why["no room for the climb"] = why.get("no room for the climb", 0) + 1
            continue
        P["chicanes"], unresolved = place_chicanes(t, pts, mouth, pal, P, r, bump_nodes,
                                                   start_nodes)
        if unresolved:
            why["a straight over 12000 without a chicane"] = why.get(
                "a straight over 12000 without a chicane", 0) + 1
            continue
        track = (t, pts, mouth, chord, bump_nodes, cross, k0, cnt, lobes)
        notes.append("track found on attempt %d" % (attempt + 1))
        break
    if track is None:
        raise RuntimeError("race: no track shape fits the wish (lap %d s, %d x %d cells of %d): %s"
                           % (P["lap_s"], span, span, P["C"], ", ".join(
                               "%s %d" % kv for kv in sorted(why.items(), key=lambda kv: -kv[1]))))
    t, pts, mouth, chord, bump_nodes, cross, k0, cnt, lobes = track
    n = len(t.nodes)
    d0 = t.nodes[k0].dout
    W, C = t.W, t.C
    coins = []
    if chord:
        ka, kb = chord
        h = t.nodes[ka].h
        span_len = abs(t.nodes[kb].x - t.nodes[ka].x) + abs(t.nodes[kb].z - t.nodes[ka].z)
        L = span_len - W
        la = q(0.4 * L)
        g = P["gap"]
        d = t.nodes[ka].din
        nd = t.nodes[ka]
        def rect(s, e, half=W // 2):
            ax, az = nd.x + d[0] * s, nd.z + d[1] * s
            bx, bz = nd.x + d[0] * e, nd.z + d[1] * e
            if d[0]:
                return (min(ax, bx), max(ax, bx), az - half, az + half)
            return (ax - half, ax + half, min(az, bz), max(az, bz))
        box, rmp = kit.kind("box"), kit.kind("ramp")
        a0, a1 = W // 2, W // 2 + la
        r1 = rect(a0, a1)
        t.extra.append(box.make(pal["road"], r1[0], r1[1], h - 200, h, r1[2], r1[3], None,
                                "chord.road"))
        rk = rect(a1 - 800, a1, half=max(400, W // 2 - 400))
        t.extra.append(rmp.make(pal["pad"], rk[0], rk[1], h, h + 200, rk[2], rk[3],
                                road.axis_rises(d, True), "chord.kicker"))
        b0, b1 = a1 + g, span_len - W // 2
        r2 = rect(b0, b1)
        t.extra.append(box.make(pal["road"], r2[0], r2[1], h - 200, h, r2[2], r2[3], None,
                                "chord.landing"))
        t.chords.append((ka, kb, g))
        mid = a1 + g / 2.0
        for i in range(6):
            off = mid + (i - 2.5) * 200
            coins.append(marker("COIN", 1, 0, 0, nd.x + d[0] * off, h + 300, nd.z + d[1] * off))
        P["shortcut_saves_s"] = round(2 * C / float(SHELL), 1)
        P["chord"] = {"from": ka, "to": kb, "gap": g, "kicker_at": a1 - 800}
    extra_markers = []
    if base > 0:
        extra_markers.append(marker("OUT", 0, 255, 2, 0, 0, 0, "out zone"))
        added = 0
        rects = [road.piece_rect(p) for p in t.pieces(pal)]
        for k in range(n):
            if added >= 2:
                break
            a, b = t.nodes[k], t.nodes[(k + 1) % n]
            if a.h != base or b.h != base or k in bump_nodes or a.crossing or b.crossing:
                continue
            if (k - k0) % n <= cnt:
                continue
            d = a.dout
            o = shape.left(d)
            mid = C // 2
            ramp_r = _oriented_rect(a, d, o, mid - 400, mid + 400, W // 2, W // 2 + 1200)
            if any(road.rects_overlap(rc, ramp_r, 200) for rc in rects
                   if not _touches_strip(rc, a, d, o, C, W)):
                continue
            t.extra.append(kit.kind("ramp").make(pal["pad"], ramp_r[0], ramp_r[1], 0, base,
                                                 ramp_r[2], ramp_r[3],
                                                 road.axis_rises((-o[0], -o[1]), True),
                                                 "walkback.%d" % k))
            rects.append(ramp_r)
            added += 1
        if added == 0:
            notes.append("no room for a walk-back ramp from the floor")
    pieces = road.compile_pieces(t.pieces(pal, plateau_tex=pal["bridge"] if P["bridge"] else None))
    start_corner = t.nodes[k0]
    g0_off = START_BACK
    g0 = (start_corner.x + d0[0] * g0_off, start_corner.z + d0[1] * g0_off)
    h0 = start_corner.h
    gw = W // 100 + 3
    gates = [(g0[0], h0, g0[1], 2, "zero", road.yaw_of(d0))]
    skipped = set(k for k in bump_nodes if chord and k != chord[1])
    cross_xz = [(nd.x, nd.z) for nd in t.nodes if nd.crossing]
    order = [(k0 + i) % n for i in range(n)]
    after_skip = set()
    jumped = False
    for k in order:
        a_, b_ = t.nodes[k], t.nodes[(k + 1) % n]
        x, z = t.point(k, C / 2.0)
        if k in skipped or a_.crossing or b_.crossing or any(
                abs(x - cx) + abs(z - cz) < W + C // 2 for cx, cz in cross_xz):
            jumped = True
            continue
        if abs(x - g0[0]) + abs(z - g0[1]) <= 1500:
            continue
        h = t.height_at(k, C / 2.0)
        if h is None:
            mid = (a_.h + b_.h) / 2.0
            hs = road.top_at(pieces, x, z)
            h = int(round(min(hs, key=lambda v: abs(v - mid)))) if hs else int(mid)
        if jumped:
            after_skip.add((q(x), q(z)))
            jumped = False
        gates.append((q(x), h, q(z), GATE_OWN_YAW, "straight", road.yaw_of(a_.dout)))
    gates = thin_gates(gates, len(gates) - 30)
    lap_est = t.length() / float(SHELL)
    par = int(round(lap_est * 1.2))
    markers = [marker("START", 0, W // 100 - 2, 4, g0[0] - d0[0] * 300, h0, g0[1] - d0[1] * 300,
                      "start"),
               marker("INFO", 3, min(255, par), 0, 0, 0, 0, "info")]
    markers += extra_markers
    lap_len = t.length()
    s_g0 = _s_of(t, k0, g0_off)
    skip_k = set(k for k in bump_nodes if chord and k != chord[1])
    spots = [s for s in t.spots(step=200, skip=skip_k) if s["h"] is not None]
    corners_xy = [(nd.x, nd.z) for nd in t.nodes if nd.corner or nd.crossing or "chicane" in nd.tags]
    def clear_of_corners(s, need):
        return all(abs(s["x"] - x) + abs(s["z"] - z) >= need for x, z in corners_xy)
    kicker_s = None
    if chord:
        kicker_s = _s_of(t, chord[0], 0)
    rows_wanted = 4 if lap_len >= 70000 else 3
    row_spots = []
    for s in spots:
        rel = (s["s"] - s_g0) % lap_len
        if rel < 10000 or rel > lap_len - 3000:
            continue
        if not clear_of_corners(s, W // 2 + 600):
            continue
        if kicker_s is not None and 0 <= (kicker_s - s["s"]) % lap_len <= 3500:
            continue
        if any(abs(s["x"] - nd.x) + abs(s["z"] - nd.z) < 2500 for nd in t.nodes if nd.crossing):
            continue
        row_spots.append((rel, s))
    rows = []
    if row_spots:
        usable = lap_len - 13000
        for i in range(rows_wanted):
            target = 10000 + usable * (i + 0.5) / rows_wanted
            best = min(row_spots, key=lambda rs: abs(rs[0] - target))
            if all(abs(best[0] - x[0]) > 4000 for x in rows):
                rows.append(best)
    box_markers = []
    for row_no, (_, s) in enumerate(sorted(rows, key=lambda x: x[0]), 1):
        o = shape.left(s["d"])
        for j, off in enumerate(ROW_OFFSETS):
            box_markers.append(marker("BOX", row_no, 0, 1 if j in (0, 5) else 0,
                                      s["x"] + o[0] * off, s["h"] + 100, s["z"] + o[1] * off))
    boost_markers = []
    for nd in sorted(t.nodes, key=lambda x: (_s_of(t, x.k, 0) - s_g0) % lap_len):
        if len(boost_markers) >= 2:
            break
        if not nd.corner or nd.k in bump_nodes:
            continue
        k = nd.k
        ahead = 0
        kk = k
        while True:
            a, b = t.nodes[kk], t.nodes[(kk + 1) % n]
            if a.h != b.h or b.corner and ahead >= 1 or (kk + 1) % n in bump_nodes:
                break
            ahead += 1
            kk = (kk + 1) % n
            if b.corner:
                break
        if ahead < 2:
            continue
        x, z = t.point(k, W // 2 + 600)
        rel = (_s_of(t, k, W // 2 + 600) - s_g0) % lap_len
        if rel < 3000 or any(abs(rel - b0) < 15000 for b0 in [m["s"] for m in boost_markers]):
            continue
        mk = marker("BOOST", 0, 6, 4, x, nd.h, z, "boost")
        mk["s"] = rel
        boost_markers.append(mk)
    for mk in boost_markers:
        mk.pop("s", None)
    if not coins:
        for nd in t.nodes:
            if nd.corner and nd.k not in bump_nodes and nd.k not in set(
                    (k0 + i) % n for i in range(0, cnt + 1)):
                a, b = nd, t.nodes[(nd.k + 1) % n]
                if a.h != b.h:
                    continue
                turn_left = shape.left(nd.din) == nd.dout
                o = shape.left(nd.dout) if turn_left else shape.right(nd.dout)
                lat = W // 2 - 300
                for i in range(6):
                    x, z = t.point(nd.k, W // 2 + 200 + 200 * i)
                    coins.append(marker("COIN", 1, 0, 0, x + o[0] * lat, nd.h + 50, z + o[1] * lat))
                break
    markers += box_markers + boost_markers + coins
    budget = brief["budget"]
    if "budget" in brief.defaulted and len(pieces) + len(markers) + len(gates) > budget:
        from .. import budget as budgetmod
        budget = min(budgetmod.ceiling("race", brief["modes"]),
                     len(pieces) + len(markers) + len(gates))
        notes.append("budget raised to %d for the track's markers (the brief named none)" % budget)
    kinds = v1.arenas_module().KIND
    markers, bnotes = common.fit_budget(pieces, markers, budget - len(gates), [
        ("coins", lambda m: m["kind"] == kinds["COIN"]),
        ("boost pads", lambda m: m["kind"] == kinds["BOOST"]),
        ("item boxes of a fourth row", lambda m: m["kind"] == kinds["BOX"] and m["num"] >= 4),
    ])
    notes += bnotes
    over = len(pieces) + len(markers) + len(gates) - budget
    if over > 0:
        before = len(gates)
        gates = thin_gates(gates, min(over, len(gates) - GATES_KEPT))
        if len(gates) < before:
            notes.append("budget: %d gates instead of %d" % (len(gates), before))
    gate_markers = [marker("GATE", i, gw, g[3], g[0], g[1], g[2], "G%02d" % i)
                    for i, g in enumerate(gates)]
    for mk, g in zip(gate_markers, gates):
        mk["yaw"] = g[5]
    markers = markers[:2 + len(extra_markers)] + gate_markers + markers[2 + len(extra_markers):]
    spawns = []
    cols = [(-3 * W) // 8, -W // 8, W // 8, (3 * W) // 8]
    o = shape.left(d0)
    sx, sz = g0[0] - d0[0] * 300, g0[1] - d0[1] * 300
    for row in range(4):
        for c in cols:
            back = 400 * (row + 1)
            spawns.append({"x": sx - d0[0] * back + o[0] * c, "y": h0,
                           "z": sz - d0[1] * back + o[1] * c, "yaw": road.yaw_of(d0)})
    for a in brief["anchors"]:
        if a["what"] in ("start_line", "world_spawn", "spawns", "spawn"):
            if start_where is a["where"]:
                lines.append(("placed", a["id"], "the start straight is the run nearest %s"
                              % _where_text(a["where"])))
        elif a["what"] in ("bridge",) and P["bridge"]:
            lines.append(("approximated", a["id"], "the raised plateau is a timber bridge; "
                          "its place is where the climb fits"))
        elif not any(x[1] == a["id"] for x in lines):
            lines.append(("not yet", a["id"], "a race track places %s from milestone 3"
                          % a["what"]))
    fx0, fx1, fz0, fz1 = common.footprint(pieces)
    shape_name = "figure eight" if lobes else "loop"
    elev = sorted(set(nd.h for nd in t.nodes))
    blurb = "a generated %s for sixteen shells" % ("figure of eight" if lobes else "race loop")
    feats = []
    if lobes:
        feats.append("an overpass over the crossing")
    if P["bridge"] and elev[-1] > base:
        feats.append("a timber bridge")
    elif elev[-1] > base:
        feats.append("a climb to %d" % (elev[-1] - base))
    if chord:
        feats.append("a gap to jump or drive round")
    if P["chicanes"]:
        feats.append("a chicane")
    note = "a %d m lap with %d corners: %s" % (round(lap_len / 100.0), len(
        [nd for nd in t.nodes if nd.corner]), ", ".join(feats) or "flat and fast")
    arena = {"key": brief["key"] or "generated", "level": level, "budget": budget,
             "pieces": pieces, "markers": markers, "spawns": spawns, "survey": {},
             "look": kit.look(
                 brief["theme"] if brief["theme"] != "auto" else "sky", brief["sky"],
                 brief["music"]),
             "onlyFor": list(MODES), "blurb": blurb, "note": note}
    arena["marks"] = [m for m in markers if m["kind"] in (kinds["START"], kinds["GATE"])]
    arena["track"] = road_line(t, k0, d0, g0, h0, chord, bump_nodes, gates)
    for g, plan in zip(gates, arena["track"]["gates"]):
        if (g[0], g[2]) in after_skip:
            plan["after_skip"] = True
    arena["world"] = race_world(arena)
    modules = {"track": shape_name, "start": "straight %d" % k0,
               "elevation": ("overpass" if lobes else ("bridge" if P["bridge"] else "climb"))
               if elev[-1] > base else "flat",
               "shortcut": "bump jump" if chord else None, "chicanes": P["chicanes"],
               "item_rows": len(rows), "boosts": len(boost_markers)}
    params = common.compat_params(fx1 - fx0, {
        "shape": shape_name, "lane": "road %d" % W, "corner": "pads %d" % len(
            [nd for nd in t.nodes if nd.corner]),
        "W": W, "C": C, "lap_target_s": P["lap_s"], "lap_length": lap_len,
        "lap_estimate_s": round(lap_len / float(SHELL), 1), "H": P["H"], "base": base,
        "heights": elev, "shortcut": bool(chord), "chicanes": P["chicanes"],
        "gates": len(gates), "shortcut_saves_s": P.get("shortcut_saves_s"),
        "nodes": n, "cells": [list(v) for v in pts], "origin": list(t.origin)})
    meta = {"params": params, "modules": modules, "anchors": lines, "notes": notes,
            "graph_faults": [], "centre": (0, 0), "bases": [],
            "module_pieces": {}, "field_spots": 0, "cover": 0,
            "graph": {"zones": ["track"], "loops": [shape_name]}}
    return arena, meta
GATES_KEPT = 10
GATE_OWN_YAW = 2
def road_line(t, k0, d0, g0, h0, chord, bump_nodes, gates):
    n = len(t.nodes)
    W = t.W
    def at(nd):
        if not hasattr(nd, "chicane"):
            return [[int(nd.x), int(nd.h), int(nd.z)]]
        d = nd.dout
        cx, cz = nd.chicane
        return [[int(nd.x - d[0] * 0.65 * W), int(nd.h), int(nd.z - d[1] * 0.65 * W)],
                [int(cx - d[0] * 0.2 * W), int(nd.h), int(cz - d[1] * 0.2 * W)],
                [int(cx + d[0] * 0.2 * W), int(nd.h), int(cz + d[1] * 0.2 * W)],
                [int(nd.x + d[0] * 0.65 * W), int(nd.h), int(nd.z + d[1] * 0.65 * W)]]
    start = [int(g0[0] - d0[0] * 300), int(h0), int(g0[1] - d0[1] * 300)]
    order = [(k0 + 1 + i) % n for i in range(n)]
    loop = [start] + [p for k in order for p in at(t.nodes[k])]
    out = {"loop": loop, "width": W, "shortcuts": [],
           "gates": [{"x": g[0], "y": g[1], "z": g[2], "yaw": g[5]} for g in gates]}
    if chord:
        ka, kb = chord
        inside = set(k for k in bump_nodes if k not in (ka, kb))
        out["shortcuts"].append([start] + [p for k in order if k not in inside
                                           for p in at(t.nodes[k])])
    return out
RLGL_W = 3600
RLGL_LONG = {"tiny": 9000, "small": 10000, "medium": 11500, "large": 13000, "huge": 14000}
RLGL_START = 1600
RLGL_FINISH = 1600
RLGL_SINK = 200
RLGL_TOP = 800
def build_rlgl(brief, streams):
    from ..paths.road import compile_pieces
    notes = []
    r = streams("track")
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    level = "empty2"
    if common.level_info(brief["level"])["floor"] is not None:
        notes.append("level: Red Light, Green Light's course is built over The Void (on The "
                     "Tiles the floor would be a way round)")
    box, ramp, pillar = kit.kind("box"), kit.kind("ramp"), kit.kind("pillar")
    road, pad, wall, floor = pal["road"], pal["pad"], pal["wall"], pal.get("floor") or pal["pad"]
    L = RLGL_LONG.get(common.size_name(brief["size"]), 11500)
    W = RLGL_W
    hw = W // 2
    pieces = []
    z = 0
    y = RLGL_TOP
    pieces.append(box.make(pad, -hw, hw, -200, y, z, z + RLGL_START, None, "rlgl.start"))
    z += RLGL_START
    sections = []
    body = L - RLGL_START - RLGL_FINISH
    plan = [("slide", 0.22), ("platforms", 0.30), ("roll", 0.18), ("climb2", 0.18), ("flat", 0.12)]
    for name, share in plan:
        d = int(round(body * share / 200.0)) * 200
        if name == "slide":
            drop = RLGL_TOP
            pieces.append(ramp.make(road, -hw, hw, y - drop, y, z, z + d - 400, "-z",
                                    "rlgl.slide"))
            y -= drop
            pieces.append(box.make(road, -hw, hw, y - 200, y, z + d - 400, z + d, None,
                                   "rlgl.slide.landing"))
        elif name in ("climb", "climb2"):
            rise = 600 if name == "climb" else 400
            pieces.append(ramp.make(road, -hw, hw, y, y + rise, z, z + d - 400, "+z",
                                    "rlgl.%s" % name))
            y += rise
            pieces.append(box.make(road, -hw, hw, y - 200, y, z + d - 400, z + d, None,
                                   "rlgl.%s.landing" % name))
        elif name == "platforms":
            pieces.append(box.make(floor, -hw, hw, y - RLGL_SINK - 200, y - RLGL_SINK, z,
                                   z + d - 800, None, "rlgl.platforms.floor"))
            row_z = z + 400
            k = 0
            while row_z + 300 <= z + d - 900:
                off = 0 if k % 2 == 0 else 450
                xs = range(-hw + 450 + off, hw - 300, 900)
                for x in xs:
                    pieces.append(pillar.make(road, x - 300, x + 300, y - RLGL_SINK - 200, y,
                                              row_z - 300, row_z + 300, None, "rlgl.platform"))
                row_z += 1000
                k += 1
            pieces.append(ramp.make(road, -hw, hw, y - RLGL_SINK, y, z + d - 800, z + d - 400,
                                    "+z", "rlgl.platforms.out"))
            pieces.append(box.make(road, -hw, hw, y - 200, y, z + d - 400, z + d, None,
                                   "rlgl.platforms.landing"))
        elif name == "roll":
            half = (d - 800) // 2
            pieces.append(ramp.make(road, -hw, hw, y - 200, y, z, z + half, "-z", "rlgl.roll.down"))
            pieces.append(box.make(road, -hw, hw, y - 400, y - 200, z + half, z + half + 400, None,
                                   "rlgl.roll.dip"))
            pieces.append(ramp.make(road, -hw, hw, y - 200, y, z + half + 400, z + d - 400, "+z",
                                    "rlgl.roll.up"))
            pieces.append(box.make(road, -hw, hw, y - 200, y, z + d - 400, z + d, None,
                                   "rlgl.roll.landing"))
        else:
            pieces.append(box.make(road, -hw, hw, y - 200, y, z, z + d, None, "rlgl.%s" % name))
        sections.append((name, z, z + d))
        z += d
    pieces.append(box.make(pad, -hw, hw, y - 200, y, z, z + RLGL_FINISH, None, "rlgl.finish"))
    finish_z = z + RLGL_FINISH // 2
    z += RLGL_FINISH
    for sx in (-1, 1):
        x0, x1 = (hw, hw + 100) if sx > 0 else (-hw - 100, -hw)
        pieces.append(box.make(wall, x0, x1, -400, RLGL_TOP + 100, 0, z, None, "rlgl.lip"))
    pieces = compile_pieces(pieces)
    spawns = []
    for row in range(2):
        for col in range(8):
            x = -hw + 250 + col * ((W - 500) // 7)
            spawns.append({"x": int(x), "y": RLGL_TOP, "z": RLGL_START // 2 - 300 + 500 * row,
                           "yaw": 0})
    start = {"x": 0, "y": RLGL_TOP, "z": RLGL_START - 100, "yaw": 0}
    finish = {"x": 0, "y": y, "z": finish_z, "yaw": 180}
    survey = {"lineStart": start, "lineFinish": finish}
    loop = [[0, RLGL_TOP, RLGL_START // 2], [0, RLGL_TOP, RLGL_START]]
    yy = RLGL_TOP
    for name, z0, z1 in sections:
        loop.append([0, yy, z0])
        if name == "slide":
            yy -= RLGL_TOP
        elif name == "climb2":
            yy += 400
        loop.append([0, yy, z1])
    loop.append([0, y, finish_z])
    arena = {"key": brief["key"] or "generated", "level": level, "budget": brief["budget"],
             "pieces": pieces, "spawns": spawns, "survey": survey,
             "look": kit.look(brief["theme"] if brief["theme"] != "auto" else "sky",
                              brief["sky"], brief["music"]),
             "onlyFor": ["line"], "track": {"loop": loop, "width": W},
             "blurb": "a generated Red Light, Green Light course climbing to its caller",
             "note": "a %d m course %d wide: a climb, round platforms over a shallow floor, a "
                     "rolling stretch, a last climb to the caller's dais (%+d)"
                     % (L // 100, W, y)}
    lines = [("not yet", x["id"], "a Red Light, Green Light course places %s from milestone 3"
              % x["what"]) for x in brief["anchors"]]
    fx0, fx1, fz0, fz1 = common.footprint(pieces)
    params = common.compat_params(max(fx1 - fx0, fz1 - fz0), {
        "shape": "rlgl course", "lane": "field %d" % W, "corner": "none", "W": W,
        "run_length": L, "run_estimate_s": round(L / 960.0 + 2.0, 1), "rise": y})
    meta = {"params": params, "modules": {"track": "rlgl course"}, "anchors": lines,
            "notes": notes, "graph_faults": [], "centre": (0, 0), "bases": [],
            "module_pieces": {}, "field_spots": 0, "cover": 0,
            "graph": {"zones": ["course"], "loops": []}}
    del r
    return arena, meta
def build_point_to_point(brief, streams):
    notes = []
    r = streams("track")
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    level = brief["level"]
    if common.level_info(level)["floor"] is not None:
        notes.append("level: a foot race is built over The Void (on The Tiles the floor "
                     "would be a shortcut to the finish)")
        level = "empty2"
    info = common.level_info(level)
    base = 0
    W, C = 1600, 3200
    secs = FOOT_S[common.size_name(brief["size"])]
    cells = max(6, int(round((secs - 2) * 960 / float(C))))
    half = min(info["half"], v1.arenas_module().BOUND)
    span = int(2 * (half - 2000) // C)
    pts = None
    for _ in range(6):
        pts = shape.open_walk(r, cells, span, min_run=2, max_run=4)
        if pts:
            break
        cells -= 2
    if not pts:
        raise RuntimeError("race: no point-to-point route fits (%d cells in %d)" % (cells, span))
    t = Track(pts, C, W, closed=False, ratio=1 / 3.0)
    curves_on(t, brief)
    n = len(t.nodes)
    H = {"flat": 0, "low": 400, "medium": 1200, "high": 2400}[brief["verticality"]]
    down = "downhill" in brief["modes"]
    wish = []
    steps = max(1, (n - 1) // 3)
    for k in range(n):
        frac = min(1.0, (k // 3) / float(steps))
        wish.append(base + int(H * ((1 - frac) if down else frac) / 50) * 50)
    ok = t.relax(wish)
    if not ok:
        notes.append("the climb was spread further than wished")
    pieces = road.compile_pieces(t.pieces(pal))
    a, b = t.nodes[0], t.nodes[-1]
    d0 = a.dout
    o = shape.left(d0)
    spawns = []
    for row in range(4):
        for col in range(4):
            back = -450 + 300 * row
            c = -600 + 400 * col
            spawns.append({"x": a.x - d0[0] * back + o[0] * c, "y": a.h,
                           "z": a.z - d0[1] * back + o[1] * c, "yaw": road.yaw_of(d0)})
    start = {"x": a.x, "y": a.h, "z": a.z, "yaw": road.yaw_of(d0)}
    finish = {"x": b.x, "y": b.h, "z": b.z, "yaw": road.yaw_of(b.din)}
    survey = {"lineStart": start, "lineFinish": finish}
    modes = ["line"]
    if finish["y"] >= start["y"] + 400:
        survey["floodStart"], survey["floodGoal"] = dict(start), dict(finish)
        modes.append("flood")
    length = (n - 1) * C
    arena = {"key": brief["key"] or "generated", "level": level,
             "budget": brief["budget"], "pieces": pieces, "spawns": spawns, "survey": survey,
             "look": kit.look(brief["theme"] if brief["theme"] != "auto" else "sky",
                              brief["sky"], brief["music"]),
             "onlyFor": modes, "blurb": "a generated foot race from a start line to a finish",
             "note": "a %d m run with %d corners, %+d from start to finish"
                     % (round(length / 100.0), len([x for x in t.nodes if x.corner]),
                        finish["y"] - start["y"])}
    lines = [("not yet", x["id"], "a foot race places %s from milestone 3" % x["what"])
             for x in brief["anchors"]]
    fx0, fx1, fz0, fz1 = common.footprint(pieces)
    params = common.compat_params(max(fx1 - fx0, fz1 - fz0), {
        "shape": "point to point", "lane": "road %d" % W, "corner": "pads %d" % len(
            [x for x in t.nodes if x.corner]),
        "W": W, "C": C, "run_length": length, "run_estimate_s": round(length / 960.0 + 0.6, 1),
        "rise": finish["y"] - start["y"], "cells": [list(v) for v in pts],
        "origin": list(t.origin)})
    meta = {"params": params, "modules": {"track": "point to point", "down": down},
            "anchors": lines, "notes": notes, "graph_faults": [], "centre": (0, 0),
            "bases": [], "module_pieces": {}, "field_spots": 0, "cover": 0,
            "graph": {"zones": ["route"], "loops": []}}
    return arena, meta
def thin_gates(gates, drop):
    if drop <= 0:
        return gates
    out = list(gates)
    for kind in ("mid", "straight"):
        idx = [i for i, g in enumerate(out) if g[4] == kind]
        if not idx:
            continue
        take = min(drop, len(idx))
        step = len(idx) / float(take)
        gone = set(idx[int(k * step)] for k in range(take))
        out = [g for i, g in enumerate(out) if i not in gone]
        drop -= len(gone)
        if drop <= 0:
            break
    return out
def _where_text(where):
    if "compass" in where:
        return where["compass"]
    if "clock" in where:
        return "%d o'clock" % where["clock"]
    return str(where)
def _s_of(t, k, off):
    return k * t.C + off
def _oriented_rect(nd, d, o, a0, a1, c0, c1):
    xs = [nd.x + d[0] * a + o[0] * c for a in (a0, a1) for c in (c0, c1)]
    zs = [nd.z + d[1] * a + o[1] * c for a in (a0, a1) for c in (c0, c1)]
    return (min(xs), max(xs), min(zs), max(zs))
def _grow(r, m):
    return (r[0] - m, r[1] + m, r[2] - m, r[3] + m)
def _inside(a, b):
    return b[0] <= a[0] and a[1] <= b[1] and b[2] <= a[2] and a[3] <= b[3]
def _touches_strip(rc, nd, d, o, C, W):
    strip = _oriented_rect(nd, d, o, -W, C + W, -W // 2, W // 2)
    return _inside(rc, _grow(strip, 1))
def lines_of(pts, mouth):
    n = len(pts)
    rs = shape.runs(pts)
    out = [[(k0 + i) % n for i in range(cnt + 1)] for k0, cnt, _ in rs]
    if mouth:
        a = next((L for L in out if pts[L[-1]] == mouth[0]), None)
        b = next((L for L in out if pts[L[0]] == mouth[1]), None)
        if a and b and a is not b:
            da = (pts[a[1]][0] - pts[a[0]][0], pts[a[1]][1] - pts[a[0]][1])
            db = (pts[b[1]][0] - pts[b[0]][0], pts[b[1]][1] - pts[b[0]][1])
            if da == db:
                out = [L for L in out if L is not a and L is not b] + [a + b]
    return out
def line_cells(t, line):
    a, b = t.nodes[line[0]], t.nodes[line[-1]]
    return (abs(a.x - b.x) + abs(a.z - b.z)) // t.C
def place_chicanes(t, pts, mouth, pal, P, r, bump_nodes, start_nodes):
    W, C = t.W, t.C
    limit = 12000 // C
    count = 0
    unresolved = []
    rects = None
    plain = lines_of(pts, None)
    joined = [L for L in lines_of(pts, mouth) if L not in plain] if mouth else []
    for line in plain + joined:
        soft = line in joined
        cells_long = line_cells(t, line)
        need = cells_long > limit
        if not need and not (P["chicane"] and cells_long >= 3 and r.random() < 0.35):
            continue
        if not P["chicane"]:
            if need and not soft:
                unresolved.append(line)
            continue
        if rects is None:
            rects = [road.piece_rect(p) for p in t.pieces(pal, walls=True)]
        d = t.nodes[line[0]].dout
        o = shape.right(d)
        shift = q(0.6 * W)
        along = q(0.7 * W)
        inner = line[1:-1]
        inner.sort(key=lambda k: abs(line.index(k) - len(line) / 2.0))
        placed = False
        for m in inner:
            nd = t.nodes[m]
            if nd.corner or nd.crossing or m in bump_nodes or m in start_nodes:
                continue
            if any(t.nodes[(m + dk) % len(t.nodes)].crossing for dk in (-1, 1)):
                continue
            first, last = t.nodes[line[0]], t.nodes[line[-1]]
            da = (abs(nd.x - first.x) + abs(nd.z - first.z)) // C
            db = (abs(nd.x - last.x) + abs(nd.z - last.z)) // C
            if need and max(da, db) > limit:
                continue
            n = len(t.nodes)
            prev, nxt = (m - 1) % n, (m + 1) % n
            if not (t.nodes[prev].h == nd.h == t.nodes[nxt].h):
                continue
            pad = _oriented_rect(nd, d, o, -along, along, shift - W // 2, shift + W // 2)
            wall = _oriented_rect(nd, d, o, -along - 200, along + 200, shift + W // 2,
                                  shift + W // 2 + 200)
            strip = _grow(_oriented_rect(nd, d, o, -C - W, C + W, -W // 2, W // 2), 1)
            clash = any((road.rects_overlap(rc, pad, 100) or road.rects_overlap(rc, wall, 100))
                        and not _inside(rc, strip) for rc in rects)
            if clash:
                continue
            box = kit.kind("box")
            t.cut[m] = W // 2
            t.extra.append(box.make(pal["pad"], pad[0], pad[1], nd.h - 200, nd.h, pad[2], pad[3],
                                    None, "chicane.%d" % m))
            t.extra.append(box.make(pal["wall"], wall[0], wall[1], nd.h - 200, nd.h + 600,
                                    wall[2], wall[3], None, "chicane.wall.%d" % m))
            rects += [pad, wall]
            nd.tags.add("chicane")
            nd.chicane = (nd.x + o[0] * shift, nd.z + o[1] * shift)
            count += 1
            placed = True
            break
        if need and not placed and not soft:
            unresolved.append(line)
    return count, unresolved
def elevate(t, P, r, base, start_nodes, bump_nodes, cross, lines, anchors):
    n = len(t.nodes)
    locked = set(start_nodes) | set(bump_nodes)
    if cross:
        c1, c2 = sorted(cross)[:2]
        lowpass = set((c1 + dk) % n for dk in (-1, 0, 1))
        hipass = set((c2 + dk) % n for dk in (-1, 0, 1))
        if lowpass & locked and hipass & locked:
            return False
        if hipass & locked:
            lowpass, hipass = hipass, lowpass
        H = max(P["H"], 1200)
        P["H"] = H
        for ratio in (P["ratio"], 0.5):
            wish = [base] * n
            for k in hipass:
                wish[k] = base + H
            if t.relax(wish, locked_low=sorted(locked | lowpass), ratio=ratio):
                for k in hipass:
                    t.nodes[k].tags.add("overpass")
                return True
        return False
    if P["H"] <= 0:
        for nd in t.nodes:
            nd.h = base
        return True
    want_where = anchors.get("bridge", {}).get("where")
    windows = []
    for s in range(n):
        for ln in range(2, max(3, n // 4) + 1):
            ks = [(s + i) % n for i in range(ln)]
            if any(k in locked for k in ks):
                continue
            windows.append(ks)
    if not windows:
        return False
    if want_where is not None:
        def wscore(ks):
            xs = sum(t.nodes[k].x for k in ks) / float(len(ks))
            zs = sum(t.nodes[k].z for k in ks) / float(len(ks))
            return common.compass_score(xs, zs, want_where) or 0
        windows.sort(key=wscore, reverse=True)
        windows = windows[:max(4, len(windows) // 6)]
    r.shuffle(windows)
    for ks in windows[:30]:
        wish = [base] * n
        for k in ks:
            wish[k] = base + P["H"]
        if t.relax(wish, locked_low=sorted(locked)):
            for k in ks:
                t.nodes[k].tags.add("plateau")
            return True
    return False
