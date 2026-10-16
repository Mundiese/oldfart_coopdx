import math
INCREMENTS = (25, 50, 100, 200, 400, 800, 1000)
GRID = 200
VERTICAL = 50
TURN = 90
SUBDIVIDE_PX = 160.0
def snap(value, step, origin=0.0):
    if step <= 0:
        return value
    return origin + round((value - origin) / step) * step
def on_surface(grid_y, top):
    if abs(grid_y - top) <= 0.5:
        return float(grid_y)
    return float(round(top, 2))
def floor_to(value, step):
    return math.floor(value / step) * step
class Snap:
    def __init__(self, step=GRID, vertical=VERTICAL, enabled=True, angle=TURN):
        self.step = float(step)
        self.vertical = float(vertical)
        self.enabled = bool(enabled)
        self.angle = float(angle)
    def active(self, ctrl=False):
        return self.enabled != bool(ctrl)
    def value(self, v, axis=0, ctrl=False):
        if not self.active(ctrl):
            return v
        return snap(v, self.vertical if axis == 1 else self.step)
    def point(self, p, ctrl=False):
        return tuple(self.value(v, k, ctrl) for k, v in enumerate(p))
    def surface(self, p, ctrl=False):
        x, y, z = self.point(p, ctrl)
        return (x, on_surface(y, p[1]), z)
    def delta(self, d, ctrl=False):
        return self.point(d, ctrl)
    def degrees(self, deg, ctrl=False):
        if not self.active(ctrl):
            return deg
        return snap(deg, self.angle)
    def quarters(self, deg):
        return int(round(deg / 90.0)) % 4
    def cell(self, p, size=GRID):
        return (int(math.floor(p[0] / size)), int(math.floor(p[1] / self.vertical)),
                int(math.floor(p[2] / size)))
    def finer(self):
        smaller = [i for i in INCREMENTS if i < self.step]
        if smaller:
            self.step = float(smaller[-1])
        return self.step
    def coarser(self):
        larger = [i for i in INCREMENTS if i > self.step]
        if larger:
            self.step = float(larger[0])
        return self.step
def grid_levels(units_per_pixel, step=GRID, min_px=6.0):
    minor = float(step)
    while minor / max(units_per_pixel, 1e-9) < min_px:
        minor *= 5.0
    while minor / max(units_per_pixel, 1e-9) >= SUBDIVIDE_PX and minor > step / 16.0:
        minor /= 4.0
    return minor, minor * 5.0
