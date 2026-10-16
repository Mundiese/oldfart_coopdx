import array
import math
from . import vec
MARKER_FLOATS = 8
COLOURS = {
    "spawn": (0.25, 0.76, 0.85),
    "survey": (0.78, 0.57, 0.92),
    "race": (0.96, 0.69, 0.25),
    "object": (0.88, 0.88, 0.88),
    "anchor": (0.36, 0.78, 0.47),
    "star": (1.0, 0.84, 0.18),
}
_meshes = {}
def _quad(a, b, c, d):
    return [(a, b, c), (a, c, d)]
def _prism(radius, y0, y1, sides=8, rot=math.pi / 8):
    ring = [(math.cos(rot + 2 * math.pi * i / sides) * radius,
             math.sin(rot + 2 * math.pi * i / sides) * radius) for i in range(sides)]
    tris = []
    for i in range(sides):
        (ax, az), (bx, bz) = ring[i], ring[(i + 1) % sides]
        tris += _quad((ax, y0, az), (ax, y1, az), (bx, y1, bz), (bx, y0, bz))
        tris.append(((0, y1, 0), (bx, y1, bz), (ax, y1, az)))
        tris.append(((0, y0, 0), (ax, y0, az), (bx, y0, bz)))
    return tris
def _octahedron(r, y):
    pts = [(r, y, 0), (0, y, r), (-r, y, 0), (0, y, -r)]
    top, bottom = (0, y + r, 0), (0, y - r, 0)
    tris = []
    for i in range(4):
        a, b = pts[i], pts[(i + 1) % 4]
        tris.append((top, b, a))
        tris.append((bottom, a, b))
    return tris
def _box(x0, x1, y0, y1, z0, z1):
    A, B, C, D = (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)
    E, F, G, H = (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)
    return (_quad(E, H, G, F) + _quad(A, B, C, D) + _quad(A, E, F, B) + _quad(D, C, G, H)
            + _quad(A, D, H, E) + _quad(B, F, G, C))
def _star(r_out, r_in, half):
    ring = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        ring.append((math.cos(a) * r, math.sin(a) * r))
    tris = []
    for i in range(10):
        (ax, ay), (bx, by) = ring[i], ring[(i + 1) % 10]
        tris.append(((0, 0, half), (ax, ay, half), (bx, by, half)))
        tris.append(((0, 0, -half), (bx, by, -half), (ax, ay, -half)))
        tris += _quad((ax, ay, -half), (ax, ay, half), (bx, by, half), (bx, by, -half))
    return tris
def shape(kind):
    if kind == "spawn":
        tris = _prism(45, 0, 150)
        tris += _box(-18, 18, 90, 125, 30, 95)
        return tris
    if kind == "survey":
        return _octahedron(55, 80) + _prism(8, 0, 30, sides=6)
    if kind == "race":
        return _prism(10, 0, 220, sides=6) + _box(0, 6, 150, 215, 8, 110)
    if kind == "anchor":
        return _octahedron(70, 100)
    if kind == "star":
        return _star(64, 26, 18)
    return _box(-60, 60, 0, 120, -60, 60)
def build(kind):
    if kind in _meshes:
        return _meshes[kind]
    out = array.array("f")
    for a, b, c in shape(kind):
        n = vec.norm(vec.cross(vec.sub(b, a), vec.sub(c, a)))
        centre = vec.mul(vec.add(vec.add(a, b), c), 1.0 / 3.0)
        axis = (0.0, centre[1], 0.0)
        if vec.dot(n, vec.sub(centre, axis)) < 0 and abs(n[1]) < 0.99:
            a, b, c = a, c, b
            n = vec.mul(n, -1.0)
        for p in (a, b, c):
            out.extend((p[0], p[1], p[2], n[0], n[1], n[2]))
    _meshes[kind] = out
    return out
def instances(scene, state_of=None):
    out = {}
    sel = getattr(scene, "marker_selection", frozenset())
    for i, m in enumerate(scene.markers):
        kind = m.kind if m.kind in COLOURS else "object"
        rows = out.setdefault(kind, array.array("f"))
        state = 1.0 if i in sel else 0.0
        if state_of is not None:
            state = float(state_of(i, m))
        r, g, b = COLOURS[kind]
        rows.extend((m.x, m.y, m.z, math.radians(m.yaw), r, g, b, state))
    return out
