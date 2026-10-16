from . import instances, meshes, vec
INF = float("inf")
class Hit:
    __slots__ = ("kind", "index", "point", "normal", "t")
    def __init__(self, kind=None, index=None, point=None, normal=None, t=INF):
        self.kind, self.index, self.point, self.normal, self.t = kind, index, point, normal, t
    def __bool__(self):
        return self.kind is not None
    def __repr__(self):
        return "Hit(%s %s t=%.1f at %s)" % (self.kind, self.index, self.t, self.point)
def ray_box(origin, d, lo, hi):
    t0, t1 = -INF, INF
    for k in range(3):
        if abs(d[k]) < 1e-12:
            if origin[k] < lo[k] or origin[k] > hi[k]:
                return None
            continue
        a = (lo[k] - origin[k]) / d[k]
        b = (hi[k] - origin[k]) / d[k]
        if a > b:
            a, b = b, a
        t0, t1 = max(t0, a), min(t1, b)
        if t0 > t1:
            return None
    if t1 < 0:
        return None
    return t0, t1
def ray_triangle(origin, d, a, b, c, both_sides=True):
    e1, e2 = vec.sub(b, a), vec.sub(c, a)
    p = vec.cross(d, e2)
    det = vec.dot(e1, p)
    if abs(det) < 1e-12 or (not both_sides and det < 0):
        return None
    inv = 1.0 / det
    s = vec.sub(origin, a)
    u = vec.dot(s, p) * inv
    if u < -1e-9 or u > 1 + 1e-9:
        return None
    q = vec.cross(s, e1)
    v = vec.dot(d, q) * inv
    if v < -1e-9 or u + v > 1 + 1e-9:
        return None
    t = vec.dot(e2, q) * inv
    return t if t >= 0 else None
def ray_plane(origin, d, point, normal):
    den = vec.dot(d, normal)
    if abs(den) < 1e-12:
        return None
    t = vec.dot(vec.sub(point, origin), normal) / den
    return t if t >= 0 else None
def ray_sphere(origin, d, centre, radius):
    oc = vec.sub(origin, centre)
    b = vec.dot(oc, d)
    c = vec.dot(oc, oc) - radius * radius
    disc = b * b - c
    if disc < 0:
        return None
    s = disc ** 0.5
    t = -b - s
    if t < 0:
        t = -b + s
    return t if t >= 0 else None
def pick_piece(scene, origin, d, skip=frozenset(), outlines=True):
    best = _pick_piece(scene, origin, d, skip, False)
    if not best and outlines:
        best = _pick_piece(scene, origin, d, skip, True)
    return best
def _pick_piece(scene, origin, d, skip, edge):
    candidates = []
    for i in range(len(scene.pieces)):
        if i in scene.hidden or i in skip:
            continue
        p = scene.shown_piece(i)
        if instances.outlined(p) != edge:
            continue
        lo, hi = meshes.world_bounds(p)
        span = ray_box(origin, d, lo, hi)
        if span is not None:
            candidates.append((max(0.0, span[0]), i, p))
    candidates.sort(key=lambda c: c[0])
    best = Hit()
    for t_enter, i, p in candidates:
        if t_enter > best.t:
            break
        for a, b, c in meshes.world_triangles(p):
            t = ray_triangle(origin, d, a, b, c)
            if t is not None and t < best.t:
                n = vec.norm(vec.cross(vec.sub(b, a), vec.sub(c, a)))
                if vec.dot(n, d) > 0:
                    n = vec.mul(n, -1.0)
                best = Hit("piece", i, vec.add(origin, vec.mul(d, t)), n, t)
    return best
MARKER_HEIGHT = 160.0
def pick_marker(scene, origin, d, radius=90.0):
    best = Hit()
    for i, m in enumerate(scene.markers):
        centre = (m.x, m.y + MARKER_HEIGHT / 2.0, m.z)
        t = ray_sphere(origin, d, centre, radius)
        if t is not None and t < best.t:
            best = Hit("marker", i, vec.add(origin, vec.mul(d, t)), (0.0, 1.0, 0.0), t)
    return best
def pick(scene, origin, d, marker_radius=90.0, plane=None, markers=True, outlines=True):
    best = pick_piece(scene, origin, d, outlines=False)
    if markers:
        m = pick_marker(scene, origin, d, marker_radius)
        if m and m.t <= best.t + marker_radius:
            best = m
    if not best and plane is not None:
        t = ray_plane(origin, d, plane[0], plane[1])
        if t is not None:
            best = Hit("plane", None, vec.add(origin, vec.mul(d, t)), plane[1], t)
    if not best and outlines:
        best = pick_piece(scene, origin, d)
    return best
def closest_on_line(origin, d, line_point, line_dir):
    w0 = vec.sub(line_point, origin)
    a = vec.dot(d, d)
    b = vec.dot(d, line_dir)
    c = vec.dot(line_dir, line_dir)
    dd = vec.dot(d, w0)
    e = vec.dot(line_dir, w0)
    den = a * c - b * b
    if abs(den) < 1e-9:
        return None
    return (b * dd - a * e) / den
def segment_distance_2d(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    if L < 1e-9:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
    qx, qy = ax + t * dx, ay + t * dy
    return ((px - qx) ** 2 + (py - qy) ** 2) ** 0.5
