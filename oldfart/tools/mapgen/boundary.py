from . import v1
INVISIBLE = "invisible"
RIM_H = 200
ESCAPE_H = 2400
TIGHT = 0.9
MODES = ("visible", "invisible", "both")
def no_walls(brief):
    return "walls" in ((brief.get("features") or {}).get("avoid") or ())
def resolve(brief, pieces_without_edge=None, budget=None):
    mode = brief.get("boundary") or "auto"
    if mode in MODES:
        return mode
    if no_walls(brief):
        return "invisible"
    if pieces_without_edge is not None and budget:
        if pieces_without_edge + 8 > TIGHT * budget:
            return "invisible"
    return "both"
def choose(brief, compile_with, budget):
    mode = brief.get("boundary") or "auto"
    if mode in MODES:
        return mode, compile_with(mode)
    if no_walls(brief):
        return "invisible", compile_with("invisible")
    both = compile_with("both")
    if len(both) <= TIGHT * budget:
        return "both", both
    return "invisible", compile_with("invisible")
def is_invisible(piece):
    return piece.get("tex") == INVISIBLE
def top_of(pieces):
    tops = [p["y"] + p["h"] for p in pieces if not is_invisible(p)]
    return max(tops) if tops else 0
RUN_MAX = 6000
def snap_seams(pieces, step=100):
    edge = [p for p in pieces if str(p.get("tag", "")).startswith("edge")
            and p.get("kind") == "box" and not float(p.get("yaw", 0) or 0) % 180]
    moved = 0
    for axis, size, other, osize in (("x", "w", "z", "d"), ("z", "d", "x", "w")):
        ends = {}
        for p in edge:
            ends.setdefault((p[axis] + p[size] / 2.0, p[other] - p[osize] / 2.0,
                             p[other] + p[osize] / 2.0, p["y"]), []).append(p)
        for p in edge:
            seam = p[axis] - p[size] / 2.0
            if not seam % step:
                continue
            for q in ends.get((seam, p[other] - p[osize] / 2.0, p[other] + p[osize] / 2.0,
                               p["y"]), ()):
                new = (seam // step) * step
                a0 = q[axis] - q[size] / 2.0
                b1 = p[axis] + p[size] / 2.0
                if new <= a0 or new >= b1:
                    continue
                q[axis], q[size] = (a0 + new) / 2.0, new - a0
                p[axis], p[size] = (new + b1) / 2.0, b1 - new
                for r in (p, q):
                    if "model" in r:
                        r["model"] = v1.arenas_module().model_name(r)
                moved += 1
                break
    return moved
def _chunks(a0, a1):
    n = max(1, int(-(-(a1 - a0) // RUN_MAX)))
    step = (a1 - a0) / float(n)
    edges = [int(round((a0 + k * step) / 200.0) * 200) if 0 < k < n else (a0 if k == 0 else a1)
             for k in range(n + 1)]
    return [(edges[k], edges[k + 1]) for k in range(n) if edges[k + 1] > edges[k]]
def walls(make_box, mode, rects, y0, floor_y, wall_top, tex, tag, top=None):
    out = []
    high = max(wall_top, (top if top is not None else wall_top)) + ESCAPE_H
    high = int(-(-high // 200) * 200)
    split = []
    for (x0, x1, z0, z1) in rects:
        for a0, a1 in _chunks(x0, x1):
            for b0, b1 in _chunks(z0, z1):
                split.append((a0, a1, b0, b1))
    rects = split
    for (x0, x1, z0, z1) in rects:
        if mode == "visible":
            out.append(make_box(tex, x0, x1, y0, wall_top, z0, z1, None, tag))
        elif mode == "invisible":
            for c0, c1 in _chunks(y0, high):
                out.append(make_box(INVISIBLE, x0, x1, c0, c1, z0, z1, None, tag + ".invisible"))
        else:
            rim = floor_y + RIM_H
            out.append(make_box(tex, x0, x1, y0, rim, z0, z1, None, tag + ".rim"))
            for c0, c1 in _chunks(rim, high):
                out.append(make_box(INVISIBLE, x0, x1, c0, c1, z0, z1, None, tag + ".invisible"))
    return out
def rejoin(pieces):
    m = v1.arenas_module()
    edge = [i for i, p in enumerate(pieces) if p.get("kind") == "box" and not p.get("yaw")
            and str(p.get("tag", "")).startswith("edge")]
    if len(edge) < 2:
        return pieces
    gone, new = set(), []
    for axis in ("z", "x"):
        groups = {}
        for i in edge:
            if i in gone:
                continue
            p = pieces[i]
            x0, x1, z0, z1, _ = m.footprint(p)
            if axis == "z":
                key, span = (x0, x1), (z0, z1)
            else:
                key, span = (z0, z1), (x0, x1)
            groups.setdefault((str(p.get("tag")), p.get("tex"), p["y"], p["h"], key),
                              []).append((span, i))
        for (tag, tex, y, h, key), runs in sorted(groups.items(), key=str):
            if len(runs) < 2:
                continue
            runs.sort()
            merged = []
            for (a0, a1), i in runs:
                if merged and a0 <= merged[-1][1]:
                    merged[-1][1] = max(merged[-1][1], a1)
                    merged[-1][2].append(i)
                else:
                    merged.append([a0, a1, [i]])
            for a0, a1, idx in merged:
                if len(idx) < 2:
                    continue
                cuts = _chunks(a0, a1)
                spans = sorted(m.footprint(pieces[i])[2:4] if axis == "z"
                               else m.footprint(pieces[i])[0:2] for i in idx)
                if [tuple(s) for s in spans] == [tuple(c) for c in cuts]:
                    continue
                gone.update(idx)
                src = pieces[idx[0]]
                for b0, b1 in cuts:
                    if axis == "z":
                        q = m.box(tex, key[0], key[1], y, y + h, b0, b1, tag)
                    else:
                        q = m.box(tex, b0, b1, y, y + h, key[0], key[1], tag)
                    for k, v in src.items():
                        if k not in q and k not in ("x", "y", "z", "w", "h", "d", "model"):
                            q[k] = v
                    q["model"] = m.model_name(q)
                    new.append(q)
    if not gone:
        return pieces
    return [p for i, p in enumerate(pieces) if i not in gone] + new
def describe(mode):
    return {"visible": "a visible wall round the map",
            "invisible": "an invisible wall round the map (collision only, %d over the "
                         "highest piece)" % ESCAPE_H,
            "both": "a low rim and an invisible wall over it (%d over the highest piece)"
                    % ESCAPE_H}[mode]
def no_model():
    return getattr(v1.arenas_module(), "NO_MODEL", "none")
def edge_pieces(pieces):
    m = v1.arenas_module()
    rects = []
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        rects.append((x0, x1, z0, z1))
    if not rects:
        return []
    X0 = min(r[0] for r in rects)
    X1 = max(r[1] for r in rects)
    Z0 = min(r[2] for r in rects)
    Z1 = max(r[3] for r in rects)
    span = max(X1 - X0, Z1 - Z0)
    out = []
    for i, (p, (x0, x1, z0, z1)) in enumerate(zip(pieces, rects)):
        if p.get("kind") != "box":
            continue
        w, d = x1 - x0, z1 - z0
        on_x = (x0 <= X0 + 1 or x1 >= X1 - 1) and w <= 400 and d >= 0.45 * span
        on_z = (z0 <= Z0 + 1 or z1 >= Z1 - 1) and d <= 400 and w >= 0.45 * span
        tall = p["h"] >= 400 or is_invisible(p) or str(p.get("tag", "")).endswith(".rim")
        if (on_x or on_z) and tall:
            out.append(i)
    return out
def restyle(pieces, mode, wall_h=1200):
    m = v1.arenas_module()
    idx = set(edge_pieces(pieces))
    if not idx:
        return list(pieces), 0
    edge = [pieces[i] for i in sorted(idx)]
    rest = [p for i, p in enumerate(pieces) if i not in idx]
    seen, rects = set(), []
    for p in edge:
        x0, x1, z0, z1, _ = m.footprint(p)
        key = (round(x0), round(x1), round(z0), round(z1))
        if key not in seen:
            seen.add(key)
            rects.append(key)
    foot = min(p["y"] for p in edge)
    visible = [p for p in edge if not is_invisible(p)]
    tex = visible[0]["tex"] if visible else "stone1"
    tag = str(edge[0].get("tag") or "edge").split(".")[0] or "edge"
    floor_y = foot + 200
    top = max([p["y"] + p["h"] for p in visible if p["h"] > RIM_H + 200] or [floor_y + wall_h])
    def make(tex_, x0, x1, y0, y1, z0, z1, _r, tag_):
        return m.box(tex_, x0, x1, y0, y1, z0, z1, tag_)
    new = walls(make, mode, rects, foot, floor_y, top, tex, tag, top=top_of(rest))
    return rest + new, len(rects)
