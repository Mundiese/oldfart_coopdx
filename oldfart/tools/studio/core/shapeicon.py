import math
from . import meshes
YAW = math.radians(60)
PITCH = math.radians(30)
LIGHT = (0.35, 0.85, 0.25)
SHADE_MIN = 0.38
CREASE_DEG = 30.0
class Drawing:
    __slots__ = ("polys", "creases")
    def __init__(self, polys, creases):
        self.polys = polys
        self.creases = creases
def _norm(v):
    n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / n, v[1] / n, v[2] / n)
def _view(p):
    cy, sy, cp, sp = math.cos(YAW), math.sin(YAW), math.cos(PITCH), math.sin(PITCH)
    x, y, z = p
    rx, rz = x * cy - z * sy, x * sy + z * cy
    ry, rz2 = y * cp - rz * sp, y * sp + rz * cp
    return rx, ry, rz2
def _facing(n):
    nx, ny, nz = _norm(n)
    cy, sy, cp, sp = math.cos(YAW), math.sin(YAW), math.cos(PITCH), math.sin(PITCH)
    rnz = nx * sy + nz * cy
    return ny * sp + rnz * cp
def drawing(faces, creases=True):
    L = _norm(LIGHT)
    shown = []
    for pts, n in faces:
        if len(pts) < 3 or _facing(n) <= 1e-6:
            continue
        cam = [_view(p) for p in pts]
        nn = _norm(n)
        lit = max(0.0, nn[0] * L[0] + nn[1] * L[1] + nn[2] * L[2])
        depth = sum(c[2] for c in cam) / len(cam)
        shown.append((depth, cam, SHADE_MIN + (1.0 - SHADE_MIN) * lit, pts, nn))
    if not shown:
        return Drawing([], [])
    shown.sort(key=lambda s: s[0])
    xs = [c[0] for s in shown for c in s[1]]
    ys = [c[1] for s in shown for c in s[1]]
    span = max(max(xs) - min(xs), max(ys) - min(ys), 1e-6) * 1.08
    cx, cy = (max(xs) + min(xs)) / 2.0, (max(ys) + min(ys)) / 2.0
    def to2(c):
        return (0.5 + (c[0] - cx) / span, 0.5 - (c[1] - cy) / span)
    polys = [([to2(c) for c in cam], light) for _, cam, light, _, _ in shown]
    owners = {}
    for _, cam, _, pts, nn in shown:
        for i in range(len(pts)):
            a, b = tuple(pts[i]), tuple(pts[(i + 1) % len(pts)])
            if a == b:
                continue
            k = (a, b) if a <= b else (b, a)
            owners.setdefault(k, []).append(nn)
    cos_c = math.cos(math.radians(CREASE_DEG))
    lines = []
    for (a, b), normals in (owners.items() if creases else ()):
        if len(normals) == 2:
            d = sum(x * y for x, y in zip(normals[0], normals[1]))
            if d > cos_c:
                continue
        lines.append((to2(_view(a)), to2(_view(b))))
    return Drawing(polys, lines)
def piece_faces(pieces):
    out = []
    for piece in pieces:
        if "w" not in piece or "kind" not in piece:
            continue
        key = meshes.mesh_key(piece)
        for pts, n in meshes.faces_of(key):
            world = [meshes.to_world(p, piece) for p in pts]
            out.append((world, meshes.real_normal(n, piece)))
    return out
