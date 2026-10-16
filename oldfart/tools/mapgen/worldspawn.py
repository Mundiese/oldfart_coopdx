import math
from .metrics import mario
from .metrics.world import world_of
HEAD = 250
DISC = 200
MIN_ORIGIN = 600
NEAR = 1500
SIGHT = 12000
def _headroom(w, x, z, y):
    best = 1e9
    for p in w.pieces:
        if p.x0 < x < p.x1 and p.z0 < z < p.z1 and p.covers(x, z):
            if p.y > y - 1 and p.y - y < best:
                best = p.y - y
    return best
def _inside(w, x, z, y):
    for p in w.pieces:
        if p.x0 < x < p.x1 and p.z0 < z < p.z1 and p.covers(x, z):
            t = p.top(x, z)
            if t is not None and p.y + 1 < y < t - 1:
                return p
    return None
def problems(arena, spot):
    w = world_of(arena)
    x, y, z = spot["x"], spot["y"], spot["z"]
    out = []
    if abs(x) < 1 and abs(z) < 1:
        out.append("at the origin")
    if _inside(w, x, z, y) is not None:
        out.append("inside a piece")
    tops = [round(p.top(x, z)) for p in w.pieces
            if p.x0 <= x <= p.x1 and p.z0 <= z <= p.z1 and p.covers(x, z)
            and p.top(x, z) is not None and not p.sloped]
    level = w.level["floor"]
    if level is not None and abs(x) <= w.level["half"] and abs(z) <= w.level["half"]:
        tops.append(level)
    if not any(abs(t - y) <= 2 for t in tops):
        out.append("no floor top at y=%s there" % y)
    if _headroom(w, x, z, y) < HEAD:
        out.append("under %d of headroom" % HEAD)
    return out
def origin_ok(arena):
    w = world_of(arena)
    for p in w.pieces:
        if p.x0 <= 0 <= p.x1 and p.z0 <= 0 <= p.z1 and p.covers(0, 0) and not p.sloped:
            t = p.top(0, 0)
            if t is not None and 0 <= t <= 80 and not problems(arena, {"x": 0, "y": round(t), "z": 0}):
                return True
    return False
def choose(arena):
    spawns = arena.get("spawns") or []
    if not spawns or not arena.get("pieces"):
        return None
    if origin_ok(arena):
        return None
    w = world_of(arena)
    first = spawns[0]
    fx, fz = first["x"], first["z"]
    r = math.hypot(fx, fz) or 1.0
    bx, bz = fx / r, fz / r
    ideal = (fx + 400 * bx, fz + 400 * bz)
    foes = [s for s in spawns[1:] if s["x"] * fx + s["z"] * fz < 0]
    cells = set(w.nodes)
    best = None
    ring = [(dx * 100, dz * 100) for dx in range(-2, 3) for dz in range(-2, 3)
            if math.hypot(dx, dz) * 100 <= DISC + 1]
    for i, (gx, gz, h) in enumerate(w.nodes):
        if not w.flat[i]:
            continue
        x, z = (gx + .5) * 100, (gz + .5) * 100
        if math.hypot(x, z) < MIN_ORIGIN or math.hypot(x - fx, z - fz) > NEAR:
            continue
        if any((int(math.floor((x + dx) / 100)), int(math.floor((z + dz) / 100)), h) not in cells
               for dx, dz in ring):
            continue
        spot = {"x": int(x), "y": int(h), "z": int(z), "yaw": first.get("yaw", 0)}
        if problems(arena, spot):
            continue
        seen = sum(1 for s in foes
                   if not w.blocked((s["x"], s.get("y", 0) + mario.EYE, s["z"]),
                                     (x, h + mario.EYE, z)))
        d = math.hypot(x - ideal[0], z - ideal[1])
        if any(math.hypot(s["x"] - x, s["z"] - z) < 150 for s in spawns):
            d += 600
        key = (seen, d)
        if best is None or key < best[0]:
            best = (key, spot)
    return best[1] if best else None
def ensure(arena):
    if not arena.get("world"):
        try:
            safe = choose(arena)
        except ValueError:
            safe = None
        if safe is not None:
            arena["world"] = safe
    return arena.get("world")
