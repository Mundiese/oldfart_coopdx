import copy
import math
import random
from studio.editor import geometry as geo
from studio.editor.commands import Change
KINDS = ("paint", "raise", "lower", "scatter", "fill")
LABELS = {"paint": "Paint", "raise": "Raise", "lower": "Lower", "scatter": "Scatter",
          "fill": "Fill"}
HINTS = {
    "paint": "Paint the pieces under the brush with the current texture",
    "raise": "Raise the ground columns under the brush (steps of 50; the rim less)",
    "lower": "Lower the ground columns under the brush (never below a 50 slab)",
    "scatter": "Scatter the chosen shape or prefab under the brush, evenly spaced "
               "(evenly, never in clumps), never into another piece",
    "fill": "Fill the empty cells under the brush at the cursor's height (a floor)",
}
CELL = geo.GRID
STEP = geo.YGRID
RAISED = "brush.raise"
SIZE_MAX = 16
class Brush:
    def __init__(self, kind="paint", size=2, falloff=0.5, strength=1, spacing=3, seed=1,
                 height=200, whole_pieces=True):
        if kind not in KINDS:
            raise ValueError("brush %r: one of %s" % (kind, ", ".join(KINDS)))
        self.kind = kind
        self.size = max(1, min(SIZE_MAX, int(size)))
        self.falloff = max(0.0, min(1.0, float(falloff)))
        self.strength = max(1, int(strength))
        self.spacing = max(1, int(spacing))
        self.seed = int(seed)
        self.height = max(STEP, int(height))
        self.whole_pieces = whole_pieces
        self.dabs = 0
    def state(self):
        return {k: getattr(self, k) for k in ("kind", "size", "falloff", "strength", "spacing",
                                              "seed", "height", "whole_pieces")}
    @classmethod
    def from_state(cls, state):
        try:
            return cls(**{k: v for k, v in (state or {}).items() if k in (
                "kind", "size", "falloff", "strength", "spacing", "seed", "height",
                "whole_pieces")})
        except (TypeError, ValueError):
            return cls()
    def centre(self, cursor):
        x, z = cursor[0], cursor[2]
        return (math.floor(x / CELL) * CELL + CELL / 2.0, math.floor(z / CELL) * CELL + CELL / 2.0)
    def weight(self, d):
        r = self.size - 0.5
        if d > r + 1e-9:
            return 0.0
        core = r * (1.0 - self.falloff)
        if d <= core or r <= core:
            return 1.0
        return max(0.0, 1.0 - (d - core) / (r - core + 0.5))
    def cells(self, cursor, symmetry=None):
        centres = [self.centre(cursor)]
        if symmetry:
            for img in symmetry.images({"x": cursor[0], "y": cursor[1], "z": cursor[2]}):
                centres.append(self.centre((img["x"], img.get("y", 0), img["z"])))
        best = {}
        n = self.size
        for cx, cz in centres:
            for i in range(-n, n + 1):
                for k in range(-n, n + 1):
                    w = self.weight(math.hypot(i, k))
                    key = (cx + i * CELL, cz + k * CELL)
                    if w > best.get(key, 0.0):
                        best[key] = w
        return sorted((x, z, w) for (x, z), w in best.items())
    def _rng(self, cursor):
        cx, cz = self.centre(cursor)
        return random.Random("%d:%d:%d:%s" % (self.seed, int(cx), int(cz), self.kind))
    def stroke(self, doc, cursor, texture="stone1", make=None, stroke_id=None, symmetry=None):
        fn = {"paint": paint, "raise": raise_lower, "lower": raise_lower,
              "scatter": scatter, "fill": fill}[self.kind]
        change = fn(self, doc, cursor, texture=texture, make=make, symmetry=symmetry)
        if stroke_id is not None and change:
            change.merge = ("brush", self.kind, stroke_id)
        change.no_symmetry = True
        self.dabs += 1
        return change
def _covering(doc, x, z, kinds=None, editable=False):
    from studio.editor import groups
    frozen = groups.frozen_refs(doc) if editable else ()
    out = []
    for ref in doc.refs("piece"):
        if ref in frozen:
            continue
        p = doc.get(ref)
        if kinds and p["kind"] not in kinds:
            continue
        b = geo.aabb(p)
        if b[0] < x < b[1] and b[4] < z < b[5]:
            out.append((ref, p))
    return out
def replace_pieces(doc, old_refs, new_pieces, label):
    from studio.editor import ops
    steps = list(ops.delete(doc, old_refs).steps)
    if new_pieces:
        steps += ops.insert(doc, [("piece", p) for p in new_pieces], label, select=False).steps
    return Change(label, steps)
def _grid():
    from mapgen import cells
    return cells
def _top_box(doc, x, z, below=None):
    best = None
    for ref, p in _covering(doc, x, z, ("box",)):
        top = p["y"] + p["h"]
        if below is not None and top > below + 1e-6:
            continue
        if best is None or top > best[1]["y"] + best[1]["h"]:
            best = (ref, p)
    return best
def _ceiling(doc, x, z, top, skip):
    lo = None
    for ref, p in _covering(doc, x, z):
        if ref in skip:
            continue
        if p["y"] >= top - 1e-6 and (lo is None or p["y"] < lo):
            lo = p["y"]
    return lo
def paint(brush, doc, cursor, texture="stone1", make=None, symmetry=None):
    rng = brush._rng(cursor)
    cells = brush.cells(cursor, symmetry)
    if brush.whole_pieces:
        hit = {}
        for x, z, w in cells:
            for ref, p in _covering(doc, x, z, editable=True):
                hit[ref] = max(hit.get(ref, 0.0), w)
        from studio.editor import ops
        refs = [r for r in sorted(hit) if rng.random() < hit[r] and doc.get(r)["tex"] != texture]
        ch = ops.retexture(doc, refs, texture)
        ch.label = "Brush: paint %d piece%s %s" % (len(ch.steps), "" if len(ch.steps) == 1
                                                   else "s", texture)
        ch.select = None
        return ch
    chosen = [(x, z) for x, z, w in cells if rng.random() < w]
    return _cell_edit(doc, chosen, lambda spans, x, z: [
        (texture, a, b, tag) if i == len(spans) - 1 else (t, a, b, tag)
        for i, (t, a, b, tag) in enumerate(spans)], "Brush: paint cells %s" % texture)
def _cell_edit(doc, cells, edit, label):
    if not cells:
        return Change(label)
    cm = _grid()
    refs = set()
    for x, z in cells:
        for ref, p in _covering(doc, x, z, ("box",), editable=True):
            refs.add(ref)
    if not refs:
        return Change(label)
    pieces = [doc.get(r) for r in sorted(refs)]
    xs, zs = [], []
    for x, z in cells:
        xs += [x - CELL / 2.0, x + CELL / 2.0]
        zs += [z - CELL / 2.0, z + CELL / 2.0]
    grid = cm.CellGrid.from_pieces(pieces, extra_xs=xs, extra_zs=zs)
    changed = False
    for x, z in cells:
        for c in grid.columns(x - CELL / 2.0, x + CELL / 2.0, z - CELL / 2.0, z + CELL / 2.0):
            spans = grid.boxes.get(c)
            if not spans:
                continue
            spans = sorted(spans, key=lambda s: (s[2], s[1]))
            new = edit(spans, x, z)
            if new != spans:
                grid.boxes[c] = sorted(new, key=lambda s: (s[1], s[2], str(s[0])))
                changed = True
    if not changed:
        return Change(label)
    out = [geo.cleaned(p) for p in grid.to_pieces(merge=True, disjoint=True)]
    def key(p):
        return tuple(sorted((k, v) for k, v in geo.cleaned(p).items()
                            if k not in ("tag", "model")))
    pool = {}
    for p in out:
        pool.setdefault(key(p), []).append(p)
    kept = set()
    for r in sorted(refs):
        lst = pool.get(key(doc.get(r)))
        if lst:
            lst.pop()
            kept.add(r)
    out = [p for lst in pool.values() for p in lst]
    for p in out:
        if not p.get("tag"):
            p.pop("tag", None)
    return replace_pieces(doc, sorted(r for r in refs if r not in kept), out, label)
def raise_lower(brush, doc, cursor, texture="stone1", make=None, symmetry=None):
    sign = 1 if brush.kind == "raise" else -1
    surface = geo.snap(cursor[1], STEP) + STEP / 2.0
    amounts = {}
    for x, z, w in brush.cells(cursor, symmetry):
        n = int(round(brush.strength * w))
        if n > 0:
            amounts[(x, z)] = n * STEP * sign
    skip = set()
    for (x, z) in amounts:
        for ref, p in _covering(doc, x, z, ("box",), editable=True):
            skip.add(ref)
    def edit(spans, x, z):
        under = [i for i, s in enumerate(spans) if s[2] <= surface]
        if not under:
            return spans
        at = under[-1]
        tex, a, b, tag = spans[at]
        d = amounts[(x, z)]
        if d > 0:
            roofs = [s[1] for s in spans[at + 1:] if s[1] >= b]
            other = _ceiling(doc, x, z, b, skip)
            if other is not None:
                roofs.append(other)
            nb = min([b + d] + roofs)
            if nb == b:
                return spans
            if tag == RAISED:
                return spans[:at] + [(tex, a, nb, tag)] + spans[at + 1:]
            return spans[:at + 1] + [(tex, b, nb, RAISED)] + spans[at + 1:]
        out = list(spans)
        left = -d
        while left > 0 and at >= 0:
            tex, a, b, tag = out[at]
            if tag == RAISED and b - left <= a:
                left -= b - a
                del out[at]
                at -= 1
                if at < 0 or out[at][2] != a:
                    break
                continue
            nb = max(a + STEP, b - left)
            out[at] = (tex, a, nb, tag)
            break
        return out
    verb = "raise" if sign > 0 else "lower"
    return _cell_edit(doc, list(amounts), edit, "Brush: %s %d column%s" % (
        verb, len(amounts), "" if len(amounts) == 1 else "s"))
def _poisson(cells, radius, rng, limit=None):
    try:
        from mapgen import pcg
        return pcg.poisson_disk(cells, radius, rng, limit=limit)
    except (ImportError, AttributeError):
        pass
    cells = set(cells)
    if not cells:
        return []
    order = sorted(cells)
    start = order[int(rng.random() * len(order))]
    out, active = [start], [start]
    r2 = radius * radius
    while active and (limit is None or len(out) < limit):
        idx = int(rng.random() * len(active))
        p = active[idx]
        for _ in range(24):
            a = rng.random() * 2 * math.pi
            d = radius * (1 + rng.random())
            c = (int(round(p[0] + d * math.cos(a))), int(round(p[1] + d * math.sin(a))))
            if c in cells and all((q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 >= r2 for q in out):
                out.append(c)
                active.append(c)
                break
        else:
            active.pop(idx)
    return out
def ground_at(doc, x, z, level_floor=0):
    from studio.core import instances, kitbridge
    m = kitbridge.arenas()
    best = None
    for ref, p in _covering(doc, x, z):
        if instances.outlined(p):
            continue
        try:
            t = m.top_at(p, x, z)
        except Exception:
            t = p["y"] + p["h"]
        if t is not None and (best is None or t > best):
            best = t
    if best is None:
        return level_floor
    return best
def scatter(brush, doc, cursor, texture="stone1", make=None, symmetry=None):
    if make is None:
        return Change("Brush: scatter (choose a shape or a prefab first)")
    rng = brush._rng(cursor)
    cx, cz = brush.centre(cursor)
    weights = {}
    for x, z, w in brush.cells(cursor):
        weights[(int(round((x - cx) / CELL)), int(round((z - cz) / CELL)))] = w
    points = _poisson(set(weights), brush.spacing, rng)
    floor = 0 if doc.rest.get("level", "empty") != "empty2" else None
    have = [geo.aabb(p) for p in doc.pieces()]
    out = []
    from studio.editor import ops
    for (i, k) in sorted(points):
        if rng.random() >= weights[(i, k)]:
            continue
        x, z = cx + i * CELL, cz + k * CELL
        y = ground_at(doc, x, z, floor)
        if y is None:
            continue
        items = make(texture, doc.brief.get("theme"))
        if not items:
            continue
        placed = geo.placed_at([it for _, it in items], (x, y, z), True)
        group = [placed]
        if symmetry:
            twins = [symmetry.images(p) for p in placed]
            group += [[t[n] for t in twins] for n in range(min(len(t) for t in twins))] \
                if twins and all(twins) else []
        for copy_ in group:
            cb = [geo.aabb(p) for p in copy_ if not geo.is_point(p)]
            if any(geo.overlap_volume(a, b) > 1.0 for a in cb for b in have):
                continue
            have += cb
            out += [(kind, p) for (kind, _), p in zip(items, copy_)]
    ch = ops.insert(doc, out, "Brush: scatter %d" % len(out), select=False)
    return ch
def fill(brush, doc, cursor, texture="stone1", make=None, symmetry=None):
    y_top = geo.snap(cursor[1], STEP)
    y0 = y_top - brush.height
    empty = []
    for x, z, w in brush.cells(cursor, symmetry):
        busy = False
        for ref, p in _covering(doc, x, z):
            if p["y"] < y_top - 1e-6 and p["y"] + p["h"] > y0 + 1e-6:
                busy = True
                break
        if not busy:
            empty.append((x, z))
    return fill_cells(doc, empty, y0, y_top, texture, "Brush: fill %d cell%s" % (
        len(empty), "" if len(empty) == 1 else "s"))
def fill_cells(doc, cells, y0, y1, texture, label):
    if not cells or y1 <= y0:
        return Change(label)
    cm = _grid()
    xs, zs = [], []
    for x, z in cells:
        xs += [x - CELL / 2.0, x + CELL / 2.0]
        zs += [z - CELL / 2.0, z + CELL / 2.0]
    grid = cm.CellGrid(xs, zs)
    for x, z in cells:
        for c in grid.columns(x - CELL / 2.0, x + CELL / 2.0, z - CELL / 2.0, z + CELL / 2.0):
            grid.boxes[c] = [(texture, y0, y1, "fill")]
    pieces = [geo.cleaned(p) for p in grid.to_pieces(merge=True, disjoint=True)]
    from studio.editor import ops
    return ops.insert(doc, [("piece", p) for p in pieces], label, select=False)
def fill_region(doc, box, texture="stone1", height=200):
    x0, x1, z0, z1, y_top = box
    b = Brush("fill", size=1, height=height)
    y_top = geo.snap(y_top, STEP)
    y0 = y_top - b.height
    cells = []
    x = math.floor(x0 / CELL) * CELL + CELL / 2.0
    while x < x1:
        z = math.floor(z0 / CELL) * CELL + CELL / 2.0
        while z < z1:
            if not any(p["y"] < y_top - 1e-6 and p["y"] + p["h"] > y0 + 1e-6
                       for _, p in _covering(doc, x, z)):
                cells.append((x, z))
            z += CELL
        x += CELL
    return fill_cells(doc, cells, y0, y_top, texture, "Fill the region (%d cells)" % len(cells))
__all__ = ["Brush", "KINDS", "paint", "raise_lower", "scatter", "fill", "fill_region",
           "replace_pieces", "ground_at", "copy"]
