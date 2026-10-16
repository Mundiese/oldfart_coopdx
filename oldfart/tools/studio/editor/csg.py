import copy
from . import geometry as geo
from .commands import Change, refusal
AXES = ("x", "y", "z")
KEEPS = ("both", "low", "high")
def _box_like(p):
    try:
        from mapgen import kit
        return kit.kind(p.get("kind")).cells == "box"
    except Exception:
        return p.get("kind") in ("box", "ice", "lava")
def budget_left(doc):
    budget = int(doc.rest.get("budget") or 120)
    return budget - len(doc.refs("piece")), budget
def over_budget(doc, extra, what):
    left, budget = budget_left(doc)
    if extra > max(0, left):
        return ("%s needs %d more piece%s but the budget has %d left (%d of %d used) - delete "
                "some or raise the budget in Properties" % (
                    what, extra, "" if extra == 1 else "s", max(0, left),
                    len(doc.refs("piece")), budget))
    return None
def _from_box(src, x0, x1, y0, y1, z0, z1):
    out = dict(src)
    out.update({"x": (x0 + x1) / 2.0, "y": y0, "z": (z0 + z1) / 2.0, "w": x1 - x0,
                "h": y1 - y0, "d": z1 - z0, "yaw": 0})
    out.pop("model", None)
    return geo.cleaned(out)
def _swap_steps(doc, removed, added, label, select=True):
    from . import groups, ops
    steps = []
    for index, ref in sorted(((doc.index_of(r), r) for r in removed), key=lambda t: -t[0]):
        steps.append(("remove", ref, index, copy.deepcopy(doc.get(ref))))
    steps += groups.prune_steps(doc, removed)
    ins = ops.insert(doc, [("piece", p) for p in added], label)
    return Change(label, steps + ins.steps, select=ins.select if select else [])
def plane_default(doc, refs, axis):
    items = [doc.get(r) for r in refs if r[0] == "piece" and r in doc]
    if not items:
        return 0
    b = geo.union(geo.aabb(p) for p in items)
    lo, hi = {"x": (b[0], b[1]), "y": (b[2], b[3]), "z": (b[4], b[5])}[axis]
    return geo.snap((lo + hi) / 2.0, geo.YGRID if axis == "y" else geo.GRID)
def clip(doc, refs, axis="x", at=None, keep="both"):
    if axis not in AXES:
        raise ValueError("clip across x, y or z")
    if keep not in KEEPS:
        raise ValueError("keep both, low or high")
    if at is None:
        at = plane_default(doc, refs, axis)
    at = geo.snap(at, geo.YGRID if axis == "y" else geo.GRID)
    i = AXES.index(axis)
    removed, added, skipped = [], [], 0
    for r in refs:
        p = doc.get(r)
        if r[0] != "piece" or p is None:
            continue
        if not _box_like(p):
            skipped += 1
            continue
        b = list(geo.aabb(p))
        lo, hi = b[2 * i], b[2 * i + 1]
        if not lo < at < hi:
            if (keep == "low" and lo >= at) or (keep == "high" and hi <= at):
                removed.append(r)
            continue
        removed.append(r)
        if keep in ("both", "low"):
            bl = list(b)
            bl[2 * i + 1] = at
            added.append(_from_box(p, *bl))
        if keep in ("both", "high"):
            bh = list(b)
            bh[2 * i] = at
            added.append(_from_box(p, *bh))
    if not removed:
        why = "the plane %s = %d crosses none of the selected boxes" % (axis, at)
        if skipped:
            why += " (%d slope%s or shape%s skipped: only boxes are clipped)" % (
                skipped, "" if skipped == 1 else "s", "" if skipped == 1 else "s")
        return refusal("Clip: " + why)
    why_not = over_budget(doc, len(added) - len(removed), "The clip")
    if why_not:
        return refusal(why_not)
    label = "Clip %d box%s at %s = %d (%s)" % (len(removed), "" if len(removed) == 1 else "es",
                                               axis, at, {"both": "kept both halves",
                                                          "low": "kept the low side",
                                                          "high": "kept the high side"}[keep])
    return _swap_steps(doc, removed, added, label)
def shell(p, thick=200, roof=True, floor=True):
    x0, x1, y0, y1, z0, z1 = geo.aabb(p)
    t = geo.snap(thick, geo.GRID) or geo.GRID
    ty = min(t, geo.snap(max(geo.YGRID, (y1 - y0) / 4.0), geo.YGRID))
    if x1 - x0 < 3 * t or z1 - z0 < 3 * t or y1 - y0 < (2 if roof else 1) * ty + geo.YGRID:
        return []
    out = []
    iy0 = y0 + (ty if floor else 0)
    iy1 = y1 - (ty if roof else 0)
    if floor:
        out.append(_from_box(p, x0, x1, y0, y0 + ty, z0, z1))
    if roof:
        out.append(_from_box(p, x0, x1, y1 - ty, y1, z0, z1))
    out.append(_from_box(p, x0, x1, iy0, iy1, z0, z0 + t))
    out.append(_from_box(p, x0, x1, iy0, iy1, z1 - t, z1))
    out.append(_from_box(p, x0, x0 + t, iy0, iy1, z0 + t, z1 - t))
    out.append(_from_box(p, x1 - t, x1, iy0, iy1, z0 + t, z1 - t))
    return out
def hollow(doc, refs, thick=200, roof=True):
    removed, added, small = [], [], 0
    for r in refs:
        p = doc.get(r)
        if r[0] != "piece" or p is None or not _box_like(p):
            continue
        got = shell(p, thick, roof)
        if not got:
            small += 1
            continue
        removed.append(r)
        added += got
    if not removed:
        return refusal("Hollow: select a box at least %d x %d cells across (walls %d thick)" % (
            3 * max(1, int(thick // geo.GRID)), 3 * max(1, int(thick // geo.GRID)), thick)
            if small else "Hollow: select a box first")
    why_not = over_budget(doc, len(added) - len(removed), "Hollowing")
    if why_not:
        return refusal(why_not)
    label = "Hollow %d box%s (walls %d thick%s)" % (len(removed), "" if len(removed) == 1
                                                    else "es", thick, "" if roof else ", open top")
    return _swap_steps(doc, removed, added, label)
def carve(doc, refs):
    from mapgen import cells
    cutters = [r for r in refs if r[0] == "piece" and r in doc and _box_like(doc.get(r))]
    if not cutters:
        return refusal("Carve: select the box to cut with first")
    boxes = [geo.aabb(doc.get(r)) for r in cutters]
    targets = []
    from . import groups
    frozen = groups.frozen_refs(doc)
    for r in doc.refs("piece"):
        if r in cutters or r in frozen:
            continue
        b = geo.aabb(doc.get(r))
        if any(geo.overlap_volume(b, c) > 0 for c in boxes):
            targets.append(r)
    if not targets:
        return refusal("Carve: the selected box overlaps nothing to cut")
    pieces = [dict(doc.get(r)) for r in targets]
    xs, zs = [], []
    for c in boxes:
        xs += [c[0], c[1]]
        zs += [c[4], c[5]]
    grid = cells.CellGrid.from_pieces(pieces, xs, zs)
    for c in boxes:
        grid.carve(c[0], c[1], c[4], c[5], c[2], c[3])
    after = [geo.cleaned(p) for p in grid.to_pieces()]
    why_not = over_budget(doc, len(after) - len(targets) - len(cutters), "The carve")
    if why_not:
        return refusal(why_not)
    label = "Carve %d box%s out of %d piece%s" % (len(cutters), "" if len(cutters) == 1 else "es",
                                                  len(targets), "" if len(targets) == 1 else "s")
    return _swap_steps(doc, targets + cutters, after, label)
