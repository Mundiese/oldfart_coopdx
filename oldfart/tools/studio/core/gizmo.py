import math
from . import picking, vec
AXES = {"x": (1.0, 0.0, 0.0), "y": (0.0, 1.0, 0.0), "z": (0.0, 0.0, 1.0)}
COLOURS = {"x": (0.93, 0.32, 0.37), "y": (0.55, 0.82, 0.27), "z": (0.30, 0.56, 0.96),
           "xz": (0.30, 0.56, 0.96), "xy": (0.55, 0.82, 0.27), "zy": (0.93, 0.32, 0.37),
           "ry": (0.55, 0.82, 0.27)}
PLANES = {"xz": ("x", "z", "y"), "xy": ("x", "y", "z"), "zy": ("z", "y", "x")}
SIZE_PX = 96.0
PLANE_AT = 0.28
PLANE_TO = 0.52
HIT_PX = 9.0
RING_SEGMENTS = 64
HIDE_DOT = 0.96
class Handle:
    __slots__ = ("name", "kind", "points", "colour")
    def __init__(self, name, kind, points, colour):
        self.name, self.kind, self.points, self.colour = name, kind, points, colour
class Delta:
    __slots__ = ("offset", "quarters", "degrees", "handle")
    def __init__(self, offset=(0.0, 0.0, 0.0), quarters=0, degrees=0.0, handle=None):
        self.offset, self.quarters, self.degrees, self.handle = offset, quarters, degrees, handle
    def is_zero(self):
        return self.quarters == 0 and all(abs(v) < 1e-9 for v in self.offset)
    def __repr__(self):
        return "Delta(%s, %d quarters)" % (self.offset, self.quarters)
class Gizmo:
    def __init__(self, mode="move", centre=(0.0, 0.0, 0.0), size_px=SIZE_PX):
        self.mode = mode
        self.centre = tuple(centre)
        self.size_px = size_px
        self.active = None
        self._start = None
    def scale(self, cam, height):
        return self.size_px * cam.units_per_pixel(self.centre, height)
    def handles(self, cam, width, height):
        L = self.scale(cam, height)
        _, _, forward = cam.basis()
        c = self.centre
        out = []
        if self.mode == "move":
            for name, axis in AXES.items():
                if abs(vec.dot(axis, forward)) > HIDE_DOT:
                    continue
                out.append(Handle(name, "axis", [c, vec.add(c, vec.mul(axis, L))], COLOURS[name]))
            for name, (a, b, n) in PLANES.items():
                if abs(vec.dot(AXES[n], forward)) < 1.0 - HIDE_DOT:
                    continue
                ua, ub = vec.mul(AXES[a], L), vec.mul(AXES[b], L)
                quad = [vec.add(c, vec.add(vec.mul(ua, s), vec.mul(ub, t)))
                        for s, t in ((PLANE_AT, PLANE_AT), (PLANE_TO, PLANE_AT),
                                     (PLANE_TO, PLANE_TO), (PLANE_AT, PLANE_TO))]
                out.append(Handle(name, "plane", quad, COLOURS[name]))
        else:
            ring = []
            for i in range(RING_SEGMENTS + 1):
                a = 2.0 * math.pi * i / RING_SEGMENTS
                ring.append((c[0] + math.cos(a) * L, c[1], c[2] + math.sin(a) * L))
            out.append(Handle("ry", "ring", ring, COLOURS["ry"]))
        return out
    def hit(self, px, py, cam, width, height):
        best, best_d = None, HIT_PX
        for h in self.handles(cam, width, height):
            pts = [cam.to_pixel(p, width, height) for p in h.points]
            if any(p is None for p in pts):
                continue
            pts2 = [(p[0], p[1]) for p in pts]
            if h.kind == "plane":
                if _inside(pts2, (px, py)) and best is None:
                    best, best_d = h.name, HIT_PX - 0.01
                continue
            for a, b in zip(pts2, pts2[1:]):
                d = picking.segment_distance_2d((px, py), a, b)
                if d < best_d:
                    best, best_d = h.name, d
        return best
    def begin(self, name, origin, d):
        self.active = name
        self._start = self._measure(name, origin, d)
        return self._start is not None
    def _plane_of(self, name):
        if name in PLANES:
            return AXES[PLANES[name][2]]
        return AXES["y"]
    def _measure(self, name, origin, d):
        c = self.centre
        if name in AXES:
            return picking.closest_on_line(origin, d, c, AXES[name])
        normal = self._plane_of(name)
        t = picking.ray_plane(origin, d, c, normal)
        if t is None:
            t = picking.ray_plane(origin, d, c, vec.mul(normal, -1.0))
        if t is None:
            return None
        hit = vec.add(origin, vec.mul(d, t))
        if name == "ry":
            return math.degrees(math.atan2(hit[2] - c[2], hit[0] - c[0]))
        return hit
    def drag(self, origin, d, snap=None, ctrl=False):
        name = self.active
        if name is None or self._start is None:
            return Delta()
        now = self._measure(name, origin, d)
        if now is None:
            return Delta(handle=name)
        if name in AXES:
            s = now - self._start
            off = vec.mul(AXES[name], s)
        elif name == "ry":
            deg = -((now - self._start + 180.0) % 360.0 - 180.0)
            snapped = snap.degrees(deg, ctrl) if snap is not None else deg
            quarters = int(round(snapped / 90.0)) % 4 if (snap is None or snap.active(ctrl)) else 0
            return Delta(quarters=quarters, degrees=snapped, handle=name)
        else:
            off = vec.sub(now, self._start)
            a, b, n = PLANES[name]
            off = tuple(0.0 if k == "xyz".index(n) else off[k] for k in range(3))
        if snap is not None:
            off = snap.delta(off, ctrl)
        return Delta(offset=tuple(off), handle=name)
    def end(self):
        self.active = None
        self._start = None
def _inside(poly, p):
    x, y = p
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xc = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if xc > x:
                inside = not inside
    return inside
