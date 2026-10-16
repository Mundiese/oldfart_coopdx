from studio.editor import geometry as geo
CELL = 400
LAYER = 200
TOL = 15
def _pieces(doc):
    return [(r, doc.get(r)) for r in doc.refs("piece")]
def _area(pieces, box):
    if box is not None:
        x0, x1, z0, z1 = box
    else:
        bs = [geo.aabb(p) for _, p in pieces]
        if not bs:
            return None
        x0, x1 = min(b[0] for b in bs), max(b[1] for b in bs)
        z0, z1 = min(b[4] for b in bs), max(b[5] for b in bs)
    i0, i1 = int(x0 // CELL), int(-(-x1 // CELL))
    j0, j1 = int(z0 // CELL), int(-(-z1 // CELL))
    return i0, i1, j0, j1
def heights(doc, box=None):
    pieces = _pieces(doc)
    area = _area(pieces, box)
    if area is None:
        return {}, set(), {}
    i0, i1, j0, j1 = area
    T, free, info = {}, set(), {}
    boxes = [(p, geo.aabb(p)) for _, p in pieces]
    for i in range(i0, i1):
        for j in range(j0, j1):
            x0, x1, z0, z1 = i * CELL, (i + 1) * CELL, j * CELL, (j + 1) * CELL
            cx, cz = x0 + CELL / 2.0, z0 + CELL / 2.0
            over = [(p, b) for p, b in boxes if b[0] < cx < b[1] and b[4] < cz < b[5]]
            if not over:
                T[(i, j)] = 0
                info[(i, j)] = (0, None)
                free.add((i, j))
                continue
            p, b = max(over, key=lambda t: t[1][3])
            top = b[3]
            layer = int(round(top / float(LAYER)))
            T[(i, j)] = layer
            info[(i, j)] = (top, p.get("tex"))
            whole = b[0] <= x0 + 1 and b[1] >= x1 - 1 and b[4] <= z0 + 1 and b[5] >= z1 - 1
            if p["kind"] == "box" and whole and abs(top - layer * LAYER) <= TOL:
                free.add((i, j))
    return T, free, info
def shapes_for(doc, box=None, budget=60):
    from mapgen import landform
    T, free, info = heights(doc, box)
    if not T:
        return [], {}
    shapes = landform.autoshape(T, free, budget=budget)
    return shapes, (T, info)
def autoshape(doc, box=None, budget=60, texture="stone1"):
    from mapgen import kit, landform
    from .brushes import replace_pieces
    shapes, got = shapes_for(doc, box, budget)
    if not shapes:
        return replace_pieces(doc, [], [], "Auto-shape: no step to shape"), 0
    T, info = got
    def tex_of(c):
        return info.get(c, (0, None))[1] or texture
    out = []
    for kind, facing, (i0, j0, i1, j1), lv, tex in landform.ramp_runs(shapes, T, tex_of):
        y0 = info[(i0, j0)][0]
        y1 = max(y0 + 1, (lv + 1) * LAYER if lv >= 0 else y0 + LAYER)
        p = kit.kind(kind).make(tex, i0 * CELL, i1 * CELL, y0, y1, j0 * CELL, j1 * CELL,
                                facing, "slope")
        out.append(geo.cleaned(p) if hasattr(geo, "cleaned") else p)
    label = "Auto-shape: %d slope%s" % (len(out), "" if len(out) == 1 else "s")
    return replace_pieces(doc, [], out, label), len(out)
