import math
from studio.editor import geometry as geo
YAW = 45.0
PITCH = 32.0
SHADE = {"top": 1.0, "x": 0.78, "z": 0.62}
def _basis(yaw=YAW, pitch=PITCH):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    def project(p):
        x, y, z = p
        rx = x * cy - z * sy
        rz = x * sy + z * cy
        sx = rx
        sy_ = -y * cp + rz * sp
        depth = rz * cp + y * sp
        return sx, sy_, depth
    view = (sy * cp, sp, cy * cp)
    return project, view
def _ridge_faces(b, xs, zs):
    x0, x1, y0, y1, z0, z1 = b
    if (x1 - x0) >= (z1 - z0):
        zm = (z0 + z1) / 2.0
        zf = (z0, z1)[zs]
        xf = (x0, x1)[xs]
        return {"top": [(x0, y1, zm), (x1, y1, zm), (x1, y0, zf), (x0, y0, zf)],
                "x": [(xf, y0, z0), (xf, y0, z1), (xf, y1, zm)]}
    xm = (x0 + x1) / 2.0
    xf = (x0, x1)[xs]
    zf = (z0, z1)[zs]
    return {"top": [(xm, y1, z0), (xm, y1, z1), (xf, y0, z1), (xf, y0, z0)],
            "z": [(x0, y0, zf), (x1, y0, zf), (xm, y1, zf)]}
def faces(pieces, width, height, margin=0.08, yaw=YAW, pitch=PITCH):
    project, _ = _basis(yaw, pitch)
    from studio.core.instances import outlined
    boxes = [(geo.aabb(p), p) for p in pieces if not geo.is_point(p) and not outlined(p)]
    if not boxes:
        return []
    raw = []
    cyaw = math.cos(math.radians(yaw))
    syaw = math.sin(math.radians(yaw))
    xs = 1 if syaw >= 0 else 0
    zs = 1 if cyaw >= 0 else 0
    for b, p in boxes:
        x0, x1, y0, y1, z0, z1 = b
        xf = (x0, x1)[xs]
        zf = (z0, z1)[zs]
        if p.get("kind") == "ridge":
            quads = _ridge_faces(b, xs, zs)
        else:
            quads = {
                "top": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
                "x": [(xf, y0, z0), (xf, y0, z1), (xf, y1, z1), (xf, y1, z0)],
                "z": [(x0, y0, zf), (x1, y0, zf), (x1, y1, zf), (x0, y1, zf)],
            }
        for name, q in quads.items():
            pts = [project(v) for v in q]
            depth = sum(d for _, _, d in pts) / len(pts) + (0.5 if name == "top" else 0.0)
            raw.append((depth, [(sx, sy) for sx, sy, _ in pts], SHADE[name[:3] if name[:3]
                                                                  in SHADE else name[0]], p))
    xs_ = [x for _, pts, _, _ in raw for x, _ in pts]
    ys_ = [y for _, pts, _, _ in raw for _, y in pts]
    w0, w1, h0, h1 = min(xs_), max(xs_), min(ys_), max(ys_)
    span = max(w1 - w0, 1e-6), max(h1 - h0, 1e-6)
    k = min(width * (1 - 2 * margin) / span[0], height * (1 - 2 * margin) / span[1])
    ox = (width - span[0] * k) / 2.0 - w0 * k
    oy = (height - span[1] * k) / 2.0 - h0 * k
    raw.sort(key=lambda r: r[0])
    return [([(x * k + ox, y * k + oy) for x, y in pts], shade, p) for _, pts, shade, p in raw]
