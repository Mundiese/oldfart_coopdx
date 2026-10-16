import math
GRID = 200
YGRID = 50
POINT_RADIUS = 60
POINT_TALL = 160
DIAGONAL_KINDS = ("outer", "inner", "outerstairs", "innerstairs", "prism", "curve", "bank",
                  "arcwall", "roundcorner", "uouter", "uinner", "wedgetipouter", "wedgetipinner")
QUARTER_UP = {0: (0, -1), 90: (-1, 0), 180: (0, 1), 270: (1, 0)}
def snap(value, step=GRID, origin=0.0, invert=False):
    if invert or not step:
        return value
    return origin + round((value - origin) / float(step)) * step
def snap_floor(value, step=GRID):
    return math.floor(value / float(step)) * step
def is_point(item):
    return "w" not in item
def is_anchor(item):
    return "what" in item and "x" not in item
def _anchor_at(anchor, x, z):
    out = dict(anchor)
    out.pop("_at", None)
    where = {"x": x, "z": z}
    for keep in ("radius",):
        if keep in (anchor.get("where") or {}):
            where[keep] = anchor["where"][keep]
    out["where"] = where
    out["hard"] = True
    return out
def point_xz(item):
    if "x" in item:
        return item.get("x", 0), item.get("z", 0)
    where = item.get("where") or {}
    if "x" in where and "z" in where:
        return where["x"], where["z"]
    at = item.get("_at") or (0, 0)
    return at[0], at[1]
def yaw_of(item):
    return int(round(item.get("yaw", 0))) % 360
def extent(piece):
    w, d = piece["w"], piece["d"]
    if yaw_of(piece) in (90, 270):
        w, d = d, w
    return w, d
def aabb(item):
    if is_point(item):
        x, z = point_xz(item)
        y = item.get("y", 0)
        r = POINT_RADIUS
        return (x - r, x + r, y, y + POINT_TALL, z - r, z + r)
    w, d = extent(item)
    return (item["x"] - w / 2.0, item["x"] + w / 2.0, item["y"], item["y"] + item["h"],
            item["z"] - d / 2.0, item["z"] + d / 2.0)
def union(boxes):
    boxes = list(boxes)
    if not boxes:
        return None
    return (min(b[0] for b in boxes), max(b[1] for b in boxes),
            min(b[2] for b in boxes), max(b[3] for b in boxes),
            min(b[4] for b in boxes), max(b[5] for b in boxes))
def touching(a, b, gap=0.5):
    return (a[0] <= b[1] + gap and b[0] <= a[1] + gap and
            a[2] <= b[3] + gap and b[2] <= a[3] + gap and
            a[4] <= b[5] + gap and b[4] <= a[5] + gap)
def overlap_volume(a, b):
    dx = min(a[1], b[1]) - max(a[0], b[0])
    dy = min(a[3], b[3]) - max(a[2], b[2])
    dz = min(a[5], b[5]) - max(a[4], b[4])
    if dx <= 0 or dy <= 0 or dz <= 0:
        return 0.0
    return dx * dy * dz
VIEWS = {
    "top": ("x", "z", "y"), "bottom": ("x", "z", "y"),
    "front": ("x", "y", "z"), "back": ("x", "y", "z"),
    "right": ("z", "y", "x"), "left": ("z", "y", "x"),
}
AXIS_SLOT = {"x": (0, 1), "y": (2, 3), "z": (4, 5)}
def projected(box, view):
    a, b, _ = VIEWS[view]
    ia, ib = AXIS_SLOT[a], AXIS_SLOT[b]
    return (box[ia[0]], box[ia[1]], box[ib[0]], box[ib[1]])
def depth_range(box, view):
    _, _, c = VIEWS[view]
    i = AXIS_SLOT[c]
    return box[i[0]], box[i[1]]
def rect_hits(rect, other, contain=False):
    a0, a1 = sorted(rect[:2])
    b0, b1 = sorted(rect[2:])
    if contain:
        return a0 <= other[0] and other[1] <= a1 and b0 <= other[2] and other[3] <= b1
    return other[0] < a1 and a0 < other[1] and other[2] < b1 and b0 < other[3]
def translated(item, dx=0, dy=0, dz=0):
    out = dict(item)
    if is_anchor(out):
        x, z = point_xz(out)
        return _anchor_at(out, x + dx, z + dz)
    out["x"] = out.get("x", 0) + dx
    out["z"] = out.get("z", 0) + dz
    if "y" in out or dy:
        out["y"] = out.get("y", 0) + dy
    return out
def _clean(v):
    if isinstance(v, float) and abs(v - round(v)) < 1e-6:
        return int(round(v))
    return v
def cleaned(item):
    out = dict(item)
    for k in ("x", "y", "z", "w", "h", "d", "yaw"):
        if k in out and isinstance(out[k], (int, float)):
            out[k] = _clean(out[k])
    if isinstance(out.get("where"), dict):
        w = dict(out["where"])
        for k in ("x", "z"):
            if k in w:
                w[k] = _clean(w[k])
        out["where"] = w
    return out
def turned(item, quarters, pivot=(0.0, 0.0)):
    q = quarters % 4
    out = dict(item)
    if is_anchor(out):
        x, z = point_xz(out)
        x, z = x - pivot[0], z - pivot[1]
        for _ in range(q):
            x, z = z, -x
        return cleaned(_anchor_at(out, x + pivot[0], z + pivot[1]))
    x, z = out.get("x", 0) - pivot[0], out.get("z", 0) - pivot[1]
    for _ in range(q):
        x, z = z, -x
    out["x"], out["z"] = x + pivot[0], z + pivot[1]
    if "yaw" in out or not is_point(out):
        out["yaw"] = (yaw_of(out) + 90 * q) % 360
    return cleaned(out)
def _corner_world(yaw):
    r = math.radians(yaw)
    c, s = math.cos(r), math.sin(r)
    return (round(-c - s), round(s - c))
def mirrored(item, axis, pivot=0.0):
    out = dict(item)
    if is_anchor(out):
        x, z = point_xz(out)
        if axis == "x":
            x = 2 * pivot - x
        else:
            z = 2 * pivot - z
        return cleaned(_anchor_at(out, x, z))
    out[axis] = 2 * pivot - out.get(axis, 0)
    yaw = yaw_of(out)
    if not is_point(out) and out.get("kind") in DIAGONAL_KINDS:
        cx, cz = _corner_world(yaw)
        want = (-cx, cz) if axis == "x" else (cx, -cz)
        for y in (0, 90, 180, 270):
            if _corner_world(y) == want:
                out["yaw"] = y
                break
    elif "yaw" in out or not is_point(out):
        out["yaw"] = ((180 - yaw) if axis == "z" else (-yaw)) % 360
    return cleaned(out)
def grid_box(items):
    pieces = [i for i in items if not is_point(i)]
    if pieces:
        return union(aabb(i) for i in pieces)
    pts = []
    for i in items:
        x, z = point_xz(i)
        y = i.get("y", 0)
        pts.append((x, x, y, y, z, z))
    return union(pts)
def grid_phase(value, step=GRID):
    return value - snap_floor(value, step)
def resnap_after(items_before, items_after, step=GRID):
    b0 = grid_box(items_before)
    b1 = grid_box(items_after)
    if b0 is None or b1 is None:
        return 0, 0
    dx = grid_phase(b0[0], step) - grid_phase(b1[0], step)
    dz = grid_phase(b0[4], step) - grid_phase(b1[4], step)
    if dx > step / 2.0:
        dx -= step
    if dx < -step / 2.0:
        dx += step
    if dz > step / 2.0:
        dz -= step
    if dz < -step / 2.0:
        dz += step
    return dx, dz
def centre_of(items):
    b = grid_box(items)
    if b is None:
        return (0.0, 0.0)
    return ((b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0)
def placed_at(items, cursor, snap_on=True, step=GRID, ystep=YGRID, floor_y=None, anchor=None):
    b = grid_box(items)
    if b is None:
        return []
    w, d = b[1] - b[0], b[5] - b[4]
    cx, cy, cz = cursor
    if floor_y is not None:
        cy = floor_y
    ax, ay, az = anchor if anchor is not None else (b[0], b[2], b[4])
    wx = cx - w / 2.0 + (ax - b[0])
    wz = cz - d / 2.0 + (az - b[4])
    wy = cy + (ay - b[2])
    if snap_on:
        wx, wz, wy = snap(wx, step), snap(wz, step), snap_up(wy, ystep)
    return [cleaned(translated(i, wx - ax, wy - ay, wz - az)) for i in items]
def snap_up(value, step=YGRID):
    got = snap(value, step)
    if abs(got - value) <= 0.5:
        return got
    return float(round(value, 2))
def mario_seconds(units):
    return units / 960.0 + 0.6 if units > 0 else 0.0
