import math
WORLD = 32767
BOUND = 30000
LEVEL_HALF = {"empty": 15000, "empty2": 17500}
MARGIN = 1200
class Far:
    __slots__ = ("list", "index", "item", "x", "y", "z")
    def __init__(self, lst, index, item, x, y, z):
        self.list, self.index, self.item = lst, index, item
        self.x, self.y, self.z = x, y, z
    def __repr__(self):
        return "<Far %s[%d] %s>" % (self.list, self.index, describe(self))
def _num(v, default=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default
def edge(layout):
    half = LEVEL_HALF.get((layout or {}).get("level") or "empty2", LEVEL_HALF["empty2"])
    return min(BOUND, half)
def _half_extents(p):
    w, d = _num(p.get("w"), 0) / 2.0, _num(p.get("d"), 0) / 2.0
    a = math.radians(_num(p.get("yaw"), 0) % 360)
    c, s = abs(math.cos(a)), abs(math.sin(a))
    return w * c + d * s, w * s + d * c
def piece_over(p, lim):
    hx, hz = _half_extents(p)
    x, z = _num(p.get("x")), _num(p.get("z"))
    ox = max(0.0, abs(x) + hx - lim)
    oz = max(0.0, abs(z) + hz - lim)
    return math.copysign(ox, x) if ox else 0.0, math.copysign(oz, z) if oz else 0.0
def piece_out(p, lim):
    ox, oz = piece_over(p, lim)
    y, h = _num(p.get("y")), _num(p.get("h"), 0)
    return bool(ox or oz) or not (-WORLD < y - MARGIN and y + h + MARGIN < WORLD)
def point_out(x, y, z, lim):
    return abs(_num(x)) > lim or abs(_num(z)) > lim or abs(_num(y)) >= WORLD - MARGIN
def _mover_points(mv):
    x, y, z = _num(mv.get("x")), _num(mv.get("y")), _num(mv.get("z"))
    out = [(x, y, z)]
    for p in mv.get("points") or []:
        if isinstance(p, (list, tuple)) and len(p) >= 3:
            out.append((x + _num(p[0]), y + _num(p[1]), z + _num(p[2])))
    return out
def far(layout):
    layout = layout or {}
    lim = edge(layout)
    out = []
    for i, p in enumerate(layout.get("pieces") or []):
        if isinstance(p, dict) and piece_out(p, lim):
            out.append(Far("pieces", i, p, _num(p.get("x")), _num(p.get("y")), _num(p.get("z"))))
    for name in ("objects", "stars", "spawns"):
        for i, o in enumerate(layout.get(name) or []):
            if isinstance(o, dict) and point_out(o.get("x"), o.get("y"), o.get("z"), lim):
                out.append(Far(name, i, o, _num(o.get("x")), _num(o.get("y")), _num(o.get("z"))))
    for i, mv in enumerate(layout.get("movers") or []):
        if not isinstance(mv, dict):
            continue
        for (x, y, z) in _mover_points(mv):
            if point_out(x, y, z, lim):
                out.append(Far("movers", i, mv, x, y, z))
                break
    w = layout.get("world")
    if isinstance(w, dict) and point_out(w.get("x"), w.get("y"), w.get("z"), lim):
        out.append(Far("world", 0, w, _num(w.get("x")), _num(w.get("y")), _num(w.get("z"))))
    return out
WHAT = {"stars": "star", "spawns": "spawn point", "movers": "moving platform",
        "world": "world spawn"}
def _thousands(v):
    return "{:,}".format(int(round(v)))
def describe(item):
    if item.list == "pieces":
        p = item.item
        if p.get("decor"):
            what = "the %s" % p["decor"]
        else:
            what = "the %s %s" % (p.get("tex") or "", p.get("kind") or "piece")
            what = what.replace("the  ", "the ")
    elif item.list == "objects":
        what = "the %s" % (item.item.get("key") or "object")
    elif item.list == "stars":
        what = "star %d" % (item.index + 1)
    else:
        what = "the %s" % WHAT.get(item.list, item.list)
        if item.list in ("spawns", "movers"):
            what += " %d" % (item.index + 1)
    return "%s at x %s, y %s, z %s" % (what, _thousands(item.x), _thousands(item.y),
                                      _thousands(item.z))
def message(items, layout=None):
    if not items:
        return None
    first = describe(items[0])
    more = "" if len(items) == 1 else " (and %d more thing%s)" % (
        len(items) - 1, "" if len(items) == 2 else "s")
    lim = edge(layout) if layout is not None else None
    reach = ("the map ends %s from the middle" % _thousands(lim)) if lim else \
        "the map cannot reach that far from the middle"
    return ("%s%s is too far out: %s, and past it there is nothing to stand on. Press "
            "\"Move it inside\" (or the report card's Fix it) to bring it in, then export "
            "again." % (first[0].upper() + first[1:], more, reach))
def _round_in(v):
    return int(v / 10) * 10
def move_inside(layout):
    notes = []
    lim = edge(layout) - 10
    for item in far(layout):
        before = describe(item)
        if item.list == "pieces":
            p = item.item
            ox, oz = piece_over(p, lim)
            if ox:
                p["x"] = _round_in(_num(p.get("x")) - ox)
            if oz:
                p["z"] = _round_in(_num(p.get("z")) - oz)
            y, h = _num(p.get("y")), _num(p.get("h"), 0)
            p["y"] = _round_in(max(-WORLD + MARGIN + 10, min(WORLD - MARGIN - h - 10, y)))
        elif item.list == "movers":
            mv = item.item
            pts = _mover_points(mv)
            for axis, k in ((0, "x"), (2, "z")):
                hi = max(p[axis] for p in pts)
                lo = min(p[axis] for p in pts)
                shift = 0.0
                if hi > lim:
                    shift = lim - hi
                elif lo < -lim:
                    shift = -lim - lo
                if shift:
                    mv[k] = _round_in(_num(mv.get(k)) + shift)
        else:
            o = item.item
            for k in ("x", "z"):
                o[k] = _round_in(max(-lim, min(lim, _num(o.get(k)))))
        notes.append("moved %s inside the map" % before)
    return notes
