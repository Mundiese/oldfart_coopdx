import math
from . import vec
HIT_PX = 16.0
RADIUS_MIN = 1500.0
RADIUS_K = 0.6
def place(bounds):
    if bounds is None:
        return (0.0, 0.0, 0.0), RADIUS_MIN
    lo, hi = bounds
    centre = ((lo[0] + hi[0]) / 2.0, float(lo[1]), (lo[2] + hi[2]) / 2.0)
    across = math.hypot(hi[0] - lo[0], hi[2] - lo[2])
    return centre, max(RADIUS_MIN, across * RADIUS_K)
class SunGizmo:
    def __init__(self, centre, radius, sun):
        from mapgen import bake
        self.centre = tuple(float(c) for c in centre)
        self.radius = float(radius)
        self.sun = bake.clean_sun(sun) or bake.sun_of({})
    def direction(self):
        from mapgen import bake
        return bake.sun_dir(self.sun["az"], self.sun["el"])
    def position(self):
        return vec.add(self.centre, vec.mul(self.direction(), self.radius))
    def screen(self, cam, width, height):
        q = cam.to_pixel(self.position(), width, height)
        return None if q is None else (q[0], q[1])
    def hit(self, px, py, cam, width, height):
        at = self.screen(cam, width, height)
        return at is not None and math.hypot(px - at[0], py - at[1]) <= HIT_PX
    def point_on_dome(self, origin, d):
        oc = vec.sub(origin, self.centre)
        b = vec.dot(oc, d)
        c = vec.dot(oc, oc) - self.radius * self.radius
        disc = b * b - c
        if disc >= 0.0:
            now = self.position()
            best = None
            for t in (-b - math.sqrt(disc), -b + math.sqrt(disc)):
                if t < 0.0:
                    continue
                p = vec.add(origin, vec.mul(d, t))
                gap = vec.length(vec.sub(p, now))
                if best is None or gap < best[0]:
                    best = (gap, p)
            if best is not None:
                return best[1]
        t = max(0.0, -b)
        near = vec.add(origin, vec.mul(d, t))
        off = vec.sub(near, self.centre)
        if vec.length(off) < 1e-6:
            return self.position()
        return vec.add(self.centre, vec.mul(vec.norm(off), self.radius))
    def drag(self, origin, d):
        from mapgen import bake
        p = self.point_on_dome(origin, d)
        az, el = bake.sun_angles(vec.sub(p, self.centre))
        sun = dict(self.sun, az=az, el=el)
        self.sun = bake.clean_sun(sun)
        return dict(self.sun)
def compass(az):
    names = ("the north", "the north-east", "the east", "the south-east", "the south",
             "the south-west", "the west", "the north-west")
    return names[int(((float(az) % 360.0) + 22.5) // 45.0) % 8]
def label(sun):
    return "Sun from %s, %d degrees round, %d up" % (compass(sun["az"]), int(round(sun["az"])),
                                                     int(round(sun["el"])))
