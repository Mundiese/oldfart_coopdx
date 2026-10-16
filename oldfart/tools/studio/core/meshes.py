import math
from . import kitbridge, vec
VERTEX_FLOATS = 8
SMOOTH_DEG = 30.0
_meshes = {}
def mesh_key(piece):
    kind = piece["kind"]
    if kind == "rail":
        return ("rail", int(round(piece["w"])), int(round(piece["h"])))
    return kind
def faces_of(key):
    a = kitbridge.arenas()
    if isinstance(key, tuple):
        kind, w, h = key
        return a.solid(kind, piece={"kind": kind, "w": w, "h": h, "d": 60})
    return a.solid(key)
class Mesh:
    __slots__ = ("key", "vertices", "edges", "triangles", "count")
    def __init__(self, key, vertices, edges, triangles):
        self.key = key
        self.vertices = vertices
        self.edges = edges
        self.triangles = triangles
        self.count = len(vertices) // VERTEX_FLOATS
def _unit_normal(n):
    return vec.norm(tuple(float(v) for v in n))
def build(key):
    if key in _meshes:
        return _meshes[key]
    a = kitbridge.arenas()
    sl = a.slopes
    kind = key[0] if isinstance(key, tuple) else key
    faces = faces_of(key)
    verts, tris = [], []
    for pts, normal in faces:
        layer = sl.layer_of(normal)
        ramp_face = 1.0 if (kind == "ramp" and normal[1] > 0 and abs(normal[2]) > 0) else 0.0
        for tri in sl.triangles(pts):
            tris.append(tuple(tuple(float(c) for c in p) for p in tri))
            for p in tri:
                verts += [float(p[0]), float(p[1]), float(p[2]),
                          float(normal[0]), float(normal[1]), float(normal[2]),
                          float(layer), ramp_face]
    mesh = Mesh(key, verts, _outline(faces), tris)
    _meshes[key] = mesh
    return mesh
def _outline(faces):
    owners = {}
    for index, (pts, normal) in enumerate(faces):
        n = _unit_normal(normal)
        for i in range(len(pts)):
            a, b = tuple(pts[i]), tuple(pts[(i + 1) % len(pts)])
            k = (a, b) if a <= b else (b, a)
            owners.setdefault(k, []).append(n)
    cos_smooth = math.cos(math.radians(SMOOTH_DEG))
    out = []
    for (a, b), normals in sorted(owners.items()):
        if len(normals) == 2 and vec.dot(normals[0], normals[1]) > cos_smooth:
            continue
        out += [float(a[0]), float(a[1]), float(a[2]), float(b[0]), float(b[1]), float(b[2])]
    return out
def scaled(p, piece):
    return (p[0] / 200.0 * piece["w"], p[1] / 200.0 * piece["h"], p[2] / 200.0 * piece["d"])
def to_world(p, piece):
    q = vec.yaw_turn(piece.get("yaw", 0), scaled(p, piece))
    return (q[0] + piece["x"], q[1] + piece["y"], q[2] + piece["z"])
def real_normal(n, piece):
    m = (n[0] / max(piece["w"], 1e-6), n[1] / max(piece["h"], 1e-6), n[2] / max(piece["d"], 1e-6))
    return vec.norm(vec.yaw_turn(piece.get("yaw", 0), m))
def world_triangles(piece):
    mesh = build(mesh_key(piece))
    return [tuple(to_world(p, piece) for p in tri) for tri in mesh.triangles]
def world_bounds(piece):
    x0, x1, z0, z1, _ = kitbridge.arenas().footprint(piece)
    return (x0, piece["y"], z0), (x1, piece["y"] + piece["h"], z1)
TILE = 200.0
def face_uv(p, normal, piece, ramp_face=False):
    q = scaled(p, piece)
    w, h, d = piece["w"], piece["h"], piece["d"]
    if abs(normal[0]) < 1e-9 and abs(normal[2]) < 1e-9:
        return (q[0] + w / 2.0) / TILE, (q[2] + d / 2.0) / TILE
    if ramp_face:
        slope_len = math.hypot(h, d)
        return (q[0] + w / 2.0) / TILE, (q[2] + d / 2.0) / d * slope_len / TILE
    u = (normal[2], 0.0, -normal[0])
    ul = math.sqrt(u[0] * u[0] + u[2] * u[2])
    s = (q[0] * u[0] + q[2] * u[2]) / ul + (w if abs(u[0]) > abs(u[2]) else d) / 2.0
    return s / TILE, (h - q[1]) / TILE
