import math
from . import v1
WIDE = DEEP = TALL = 200
WALL_MIN = 400
FLUSH = 12
BEHIND = 20
SNAP_REACH = 1200
KEY = "triblock"
def _m():
    return v1.arenas_module()
def facing(yaw):
    a = math.radians(float(yaw or 0))
    return math.sin(a), math.cos(a)
def _solid(p):
    return p.get("kind") != "water" and p.get("tex") != "invisible" and not (
        p.get("decor") and p.get("pass"))
class _World(object):
    def __init__(self, arena):
        from .guards import Index
        self.arena = arena
        self.pieces = [p for p in arena.get("pieces") or [] if _solid(p)]
        self.ix = Index(self.pieces)
        self.m = _m()
    def inside(self, x, y, z):
        for i in self.ix.near(x, z):
            p = self.pieces[i]
            r = self.ix.rects[i]
            if not (r[0] < x < r[1] and r[2] < z < r[3]):
                continue
            if not self.m.covers(p, x, z):
                continue
            top = self.m.top_at(p, x, z)
            if top is not None and p["y"] <= y < top:
                return True
        return False
    def floors(self, x, z):
        near = [self.pieces[i] for i in self.ix.near(x, z)]
        return self.m.standable(near, x, z, self.arena.get("level", "tiles"))
def why_not(world, x, y, z, yaw):
    fx, fz = facing(yaw)
    lx, lz = fz, -fx
    for a, b in ((DEEP / 2.0, 0), (DEEP - 20, WIDE / 2.0 - 20), (DEEP - 20, -WIDE / 2.0 + 20)):
        px, pz = x + fx * a + lx * b, z + fz * a + lz * b
        if not any(abs(h - y) <= FLUSH for h in world.floors(px, pz)):
            return "not flush on the floor"
    for b in (-WIDE / 2.0 + 20, 0, WIDE / 2.0 - 20):
        px, pz = x - fx * BEHIND + lx * b, z - fz * BEHIND + lz * b
        for up in (50, TALL - 20, WALL_MIN - 20):
            if not world.inside(px, y + up, pz):
                in_front = world.inside(x + fx * (DEEP + BEHIND) + lx * b, y + 50,
                                        z + fz * (DEEP + BEHIND) + lz * b)
                return ("the wrong way round (the wall is at its low side)" if in_front
                        else "no wall behind its high side")
    if world.inside(x + fx * DEEP / 2.0, y + TALL / 2.0, z + fz * DEEP / 2.0):
        return "inside a solid"
    return None
def faults(arena):
    blocks = [o for o in arena.get("objects") or [] if (o.get("key") or o.get("what")) == KEY]
    if not blocks:
        return []
    world = _World(arena)
    out = []
    for o in blocks:
        why = why_not(world, o["x"], o["y"], o["z"], o.get("yaw", 0))
        if why:
            out.append((o, why))
    return out
def wall_feet(arena, world=None, step=200):
    world = world or _World(arena)
    m = world.m
    out = []
    seen = set()
    for p in world.pieces:
        if p.get("kind") != "box" or float(p.get("h", 0)) < WALL_MIN:
            continue
        x0, x1, z0, z1, _ = m.footprint(p)
        top = p["y"] + p["h"]
        sides = (((x1, 1, 0), (z0, z1)), ((x0, -1, 0), (z0, z1)),
                 ((z1, 0, 1), (x0, x1)), ((z0, 0, -1), (x0, x1)))
        for (edge, nx, nz), (lo, hi) in sides:
            yaw = int(round(math.degrees(math.atan2(nx, nz)))) % 360
            a = lo + WIDE / 2.0
            while a <= hi - WIDE / 2.0 + 1e-6:
                if nx:
                    x, z = edge + nx * 1.0, a
                else:
                    x, z = a, edge + nz * 1.0
                front = (x + nx * DEEP / 2.0, z + nz * DEEP / 2.0)
                for h in sorted(world.floors(*front)):
                    if h > top - WALL_MIN or h < p["y"] - FLUSH:
                        continue
                    key = (round(x), round(h), round(z), yaw)
                    if key in seen:
                        continue
                    seen.add(key)
                    if why_not(world, x, h, z, yaw) is None:
                        out.append((x, h, z, yaw))
                a += step
    return out
def snap(arena, obj, feet=None, taken=()):
    feet = wall_feet(arena) if feet is None else feet
    best, bd = None, None
    for f in feet:
        if any(math.hypot(f[0] - t[0], f[2] - t[2]) < WIDE for t in taken):
            continue
        d = math.hypot(f[0] - obj["x"], f[2] - obj["z"]) + abs(f[1] - obj["y"]) * 0.5
        if d <= SNAP_REACH and (bd is None or d < bd):
            best, bd = f, d
    return best
def enforce(arena):
    bad = faults(arena)
    if not bad:
        return []
    feet = wall_feet(arena)
    taken = [(o["x"], o["y"], o["z"]) for o in arena.get("objects") or []
             if (o.get("key") or o.get("what")) == KEY and all(o is not b for b, _ in bad)]
    notes, drop = [], []
    for o, why in bad:
        f = snap(arena, o, feet, taken)
        if f is None:
            drop.append(o)
            notes.append("triangular block at %d,%d taken off (%s, no wall foot near)"
                         % (o["x"], o["z"], why))
            continue
        o["x"], o["y"], o["z"], o["yaw"] = int(round(f[0])), int(round(f[1])), \
            int(round(f[2])), int(f[3])
        o.pop("air", None)
        taken.append((o["x"], o["y"], o["z"]))
        notes.append("triangular block moved to a wall foot (%s)" % why)
    if drop:
        arena["objects"] = [o for o in arena.get("objects") or [] if all(o is not d for d in drop)]
    return notes
