import math
FPS = 30
LIMITS = {
    "max_points": 12,
    "min_speed": 30,
    "max_speed": 4200,
    "speed": 300,
    "rise": 50,
    "max_wait": 600,
    "wait": 10,
    "cap": 32,
}
MODES = ("loop", "pingpong", "oneway")
TRIGGERS = ("always", "ridden", "wired")
MAX_LINK = 31
STAND_SPEED = 1200
RUN = 960.0
SHAPES = {"blk": (100, 200), "slab": (100, 100), "plate": (100, 20),
          "log": (300, 150), "logwide": (450, 150)}
LOG_DIMS = {"log": (1024, 256), "logwide": (1105, 237)}
class Refused(ValueError):
    pass
def platform_key(shape="slab", tex="stone1"):
    if shape in ("log", "logwide"):
        return "mv" + shape
    return "mv" + ("blk" if shape in ("cube", "blk") else shape) + tex
def key_known(key):
    rest = str(key)[2:]
    if not str(key).startswith("mv"):
        return False
    if rest in ("log", "logwide"):
        return True
    from . import kit
    have = kit.textures()
    if rest.startswith("blk"):
        return rest[3:] in have
    for tex, row in have.items():
        if rest.endswith(tex) and rest[:-len(tex)] in (row.get("shapes") or ()):
            return True
    return False
def shape_of(key):
    rest = str(key)[2:]
    if rest in ("log", "logwide"):
        return rest
    for shape in sorted(SHAPES, key=len, reverse=True):
        if rest.startswith(shape):
            return shape
    return "blk"
def _clamp(v, lo, hi):
    return max(lo, min(hi, v))
def normalise(m):
    out = dict(m)
    out["mode"] = m.get("mode") if m.get("mode") in MODES else "pingpong"
    out["trigger"] = m.get("trigger") if m.get("trigger") in TRIGGERS else "always"
    out["phase"] = int(round(_clamp(m.get("phase", 0) or 0, 0, 30000)))
    if out["trigger"] == "wired":
        out["link"] = int(round(_clamp(m.get("link") or 1, 1, MAX_LINK)))
    else:
        out.pop("link", None)
    out["yaw"] = m.get("yaw", 0) or 0
    pts = []
    for p in (m.get("points") or [])[:LIMITS["max_points"]]:
        p = list(p) + [LIMITS["speed"], LIMITS["wait"]][len(p) - 3:] if len(p) < 5 else list(p)
        pts.append([int(round(_clamp(p[0], -32000, 32000))), int(round(_clamp(p[1], -32000, 32000))),
                    int(round(_clamp(p[2], -32000, 32000))),
                    int(round(_clamp(p[3], LIMITS["min_speed"], LIMITS["max_speed"]))),
                    int(round(_clamp(p[4], 0, LIMITS["max_wait"])))])
    if not pts:
        pts.append([0, 0, 0, LIMITS["speed"], LIMITS["wait"]])
    pts[0][0] = pts[0][1] = pts[0][2] = 0
    if len(pts) == 1:
        pts.append([0, 0, 600, pts[0][3], pts[0][4]])
    out["points"] = pts
    return out
def mover(key, at, points, mode="pingpong", trigger="always", speed=None, wait=None,
          yaw=0, phase=0, modes=None, link=None):
    x0, y0, z0 = at
    speed = LIMITS["speed"] if speed is None else speed
    wait = LIMITS["wait"] if wait is None else wait
    rel = []
    for p in points:
        s = p[3] if len(p) > 3 else speed
        w = p[4] if len(p) > 4 else wait
        rel.append([p[0] - x0, p[1] - y0, p[2] - z0, s, w])
    m = {"key": key, "x": x0, "y": y0, "z": z0, "yaw": yaw, "mode": mode,
         "trigger": trigger, "phase": phase, "points": rel}
    if modes:
        m["modes"] = list(modes)
    if link:
        m["link"] = link
    return normalise(m)
def gap_ferry(a, b, tex="stone1", shape="slab", speed=300, wait=15, modes=None):
    half, top = SHAPES[shape_of(platform_key(shape, tex))]
    dx, dz = b[0] - a[0], b[2] - a[2]
    length = math.hypot(dx, dz) or 1.0
    ux, uz = dx / length, dz / length
    dock = half + 10
    at = (a[0] + ux * dock, a[1] - top, a[2] + uz * dock)
    end = (b[0] - ux * dock, b[1] - top, b[2] - uz * dock)
    return mover(platform_key(shape, tex), at, [at, end],
                 mode="pingpong", speed=speed, wait=wait, modes=modes)
def lift(bottom, top_point, tex="stone1", shape="slab", ridden=True, speed=240, wait=20,
         stops=(), modes=None):
    h = SHAPES[shape_of(platform_key(shape, tex))][1]
    at = (bottom[0], bottom[1] - h, bottom[2])
    pts = [at] + [(s[0], s[1] - h, s[2]) for s in stops] + [(top_point[0], top_point[1] - h,
                                                             top_point[2])]
    return mover(platform_key(shape, tex), at, pts, mode="oneway",
                 trigger="ridden" if ridden else "always", speed=speed, wait=wait, modes=modes)
def log_gauntlet(start, end, count=3, wide=False, speed=420, wait=5, modes=None):
    key = platform_key("logwide" if wide else "log")
    dx, dz = end[0] - start[0], end[2] - start[2]
    length = math.hypot(dx, dz) or 1.0
    ux, uz = -dz / length, dx / length
    gap = 2 * LOG_DIMS[shape_of(key)][0] + 60
    out = []
    probe = mover(key, start, [start, end], speed=speed, wait=wait)
    period = timeline(probe)["period"]
    for i in range(count):
        off = (i - (count - 1) / 2.0) * gap
        a = (start[0] + ux * off, start[1], start[2] + uz * off)
        b = (end[0] + ux * off, end[1], end[2] + uz * off)
        yaw = int(round(math.degrees(math.atan2(dx, dz)))) % 360
        out.append(mover(key, a, [a, b], mode="pingpong", speed=speed, wait=wait, yaw=yaw,
                         phase=(period * i) // max(1, count), modes=modes))
    return out
def extent(m):
    shape = shape_of(m["key"])
    if shape in LOG_DIMS:
        half_len, rad = LOG_DIMS[shape]
        yaw = math.radians(m.get("yaw", 0) or 0)
        c, s = abs(math.cos(yaw)), abs(math.sin(yaw))
        return (half_len * c + rad * s, half_len * s + rad * c, 2 * rad)
    half, height = SHAPES[shape]
    return (half, half, height)
def swept_box(m):
    m = normalise(m)
    hx, hz, h = extent(m)
    xs = [m["x"] + p[0] for p in m["points"]]
    ys = [m["y"] + p[1] for p in m["points"]]
    zs = [m["z"] + p[2] for p in m["points"]]
    return (min(xs) - hx, max(xs) + hx, min(ys), max(ys) + h, min(zs) - hz, max(zs) + hz)
def log_lane(start, end, wide=False, speed=420, wait=10, phase=0, modes=None):
    key = platform_key("logwide" if wide else "log")
    dx, dz = end[0] - start[0], end[2] - start[2]
    yaw = int(round(math.degrees(math.atan2(dx, dz)))) % 360
    return mover(key, start, [start, end], mode="pingpong", speed=speed, wait=wait, yaw=yaw,
                 phase=phase, modes=modes)
def island_ferry(shore, island, tex="woodenplank1", shape="slab", speed=360, wait=30,
                 ridden=False, via=(), modes=None):
    h = SHAPES[shape_of(platform_key(shape, tex))][1]
    at = (shore[0], shore[1] - h, shore[2])
    pts = [at] + [(v[0], v[1] - h, v[2]) for v in via] + [(island[0], island[1] - h, island[2])]
    return mover(platform_key(shape, tex), at, pts,
                 mode="oneway" if ridden else "pingpong",
                 trigger="ridden" if ridden else "always", speed=speed, wait=wait, modes=modes)
def _leg_frames(a, b, speed):
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    per = max(1.0, speed / float(FPS))
    frames = int(math.ceil(length / per))
    frames = max(frames, int(math.ceil(abs(dy) / float(LIMITS["rise"]))))
    return max(1, frames), length
def timeline(m):
    m = normalise(m)
    pts = m["points"]
    n = len(pts)
    legs = []
    def wait(i):
        legs.append({"wait": True, "a": i, "frames": pts[i][4] * 3})
    def move(i, j, speed):
        frames, length = _leg_frames(pts[i], pts[j], speed)
        legs.append({"wait": False, "a": i, "b": j, "frames": frames, "len": length})
    if m["mode"] == "loop":
        for i in range(n):
            wait(i)
            move(i, (i + 1) % n, pts[i][3])
    elif m["mode"] == "oneway":
        for i in range(n - 1):
            wait(i)
            move(i, i + 1, pts[i][3])
        wait(n - 1)
        for i in range(n - 1, 0, -1):
            move(i, i - 1, pts[i - 1][3])
    else:
        for i in range(n - 1):
            wait(i)
            move(i, i + 1, pts[i][3])
        wait(n - 1)
        for i in range(n - 1, 0, -1):
            move(i, i - 1, pts[i - 1][3])
            if i - 1 > 0:
                wait(i - 1)
    at = 0
    for leg in legs:
        leg["start"] = at
        at += leg["frames"]
    return {"legs": legs, "period": max(1, at),
            "first_wait": legs[0]["frames"] if legs and legs[0]["wait"] else 0, "mover": m}
def position(m, t):
    tl = timeline(m)
    pts = tl["mover"]["points"]
    t %= tl["period"]
    for k, leg in enumerate(tl["legs"]):
        if t < leg["start"] + leg["frames"] or k == len(tl["legs"]) - 1:
            f = (t - leg["start"]) / float(leg["frames"]) if leg["frames"] else 1.0
            f = _clamp(f, 0.0, 1.0)
            if leg["wait"]:
                p = pts[leg["a"]]
                return (p[0], p[1], p[2])
            a, b = pts[leg["a"]], pts[leg["b"]]
            return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))
    return tuple(pts[0][:3])
def top_speed(m):
    tl = timeline(m)
    pts = tl["mover"]["points"]
    top, side = 0.0, 0.0
    for leg in tl["legs"]:
        if leg["wait"]:
            continue
        a, b = pts[leg["a"]], pts[leg["b"]]
        top = max(top, leg["len"] / leg["frames"] * FPS)
        side = max(side, math.hypot(b[0] - a[0], b[2] - a[2]) / leg["frames"] * FPS)
    return top, side
def _arrivals(tl):
    at = {}
    for leg in tl["legs"]:
        if leg["wait"]:
            at.setdefault(leg["a"], []).append((leg["start"], leg["start"] + leg["frames"]))
        else:
            end = leg["start"] + leg["frames"]
            at.setdefault(leg["b"], []).append((end, end))
    return at
def ride_s(m, i, j):
    tl = timeline(m)
    period = tl["period"]
    stands = _arrivals(tl)
    leave = [b for (_, b) in stands.get(i, [])]
    arrive = [a for (a, _) in stands.get(j, [])]
    if not leave or not arrive:
        return float("inf")
    best = None
    for lv in leave:
        for ar in arrive:
            d = (ar - lv) % period
            if d == 0:
                d = period
            best = d if best is None else min(best, d)
    return best / float(FPS)
def wait_s(m, i):
    tl = timeline(m)
    if tl["mover"]["trigger"] in ("ridden", "wired"):
        return 0.0 if i == 0 else tl["period"] / float(FPS) / 2.0
    period = tl["period"]
    stands = sorted(_arrivals(tl).get(i, []))
    if not stands:
        return float("inf")
    away = []
    for k, (a, b) in enumerate(stands):
        nxt = stands[(k + 1) % len(stands)][0]
        gap = (nxt - b) % period
        away.append(gap)
    return sum(g * g / 2.0 for g in away) / float(period) / FPS
def mario_seconds(m, i, j):
    if i == j:
        return 0.0
    return wait_s(m, i) + ride_s(m, i, j)
def stops(m):
    top = SHAPES[shape_of(m["key"])][1]
    return [(m["x"] + p[0], m["y"] + p[1] + top, m["z"] + p[2]) for p in m["points"]]
def timed_edges(arena):
    out = []
    for k, m in enumerate(arena.get("movers") or []):
        m = normalise(m)
        st = stops(m)
        for i in range(len(st)):
            for j in range(len(st)):
                if i != j:
                    r, w = ride_s(m, i, j), wait_s(m, i)
                    out.append({"mover": k, "from": i, "to": j, "board": st[i], "alight": st[j],
                                "ride_s": round(r, 2), "wait_s": round(w, 2),
                                "s": round(r + w, 2)})
    return out
def route_s(arena, a, b):
    return routes_s(arena, a, [b])[0]
def routes_s(arena, a, goals):
    import heapq
    from .metrics import world as worldmod
    w = worldmod.World(arena)
    grid = 100
    cols = {}
    for k, c in enumerate(w.all_cells):
        cols.setdefault((c[0], c[1]), []).append((k, c))
    def cell_of(p):
        best, bd = None, None
        gx, gz = int(math.floor(p[0] / grid)), int(math.floor(p[2] / grid))
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                for k, c in cols.get((gx + dx, gz + dz), ()):
                    d = abs(c[2] - p[1]) + abs(c[0] - gx) * grid + abs(c[1] - gz) * grid
                    if bd is None or (d, k) < bd:
                        best, bd = c, (d, k)
        return best
    start = cell_of(a)
    targets = [cell_of(b) for b in goals]
    if start is None:
        return [None] * len(goals)
    step = grid / RUN
    ride = {}
    from . import v1
    tool = v1.arenas_module()
    for k, m in enumerate(arena.get("movers") or []):
        one = dict(arena, movers=[m])
        mm = normalise(m)
        n = len(mm["points"])
        cost = sum(mario_seconds(mm, i, j) for i in range(n) for j in range(n) if i != j) \
            / float(max(1, n * (n - 1)))
        for u, outs in tool.mover_edges(one, w.all_cells).items():
            for v in outs:
                key = (u, v)
                ride[key] = min(ride.get(key, cost), cost)
    edges = w.all_edges
    want = set(t for t in targets if t is not None)
    dist = {start: 0.0}
    done = {}
    heap = [(0.0, start)]
    while heap and want:
        d, u = heapq.heappop(heap)
        if d > dist.get(u, float("inf")):
            continue
        if u in want:
            done[u] = d
            want.discard(u)
        for v in edges.get(u, ()):
            c = ride.get((u, v), step)
            nd = d + c
            if nd < dist.get(v, float("inf")):
                dist[v] = nd
                heapq.heappush(heap, (nd, v))
    return [round(done[t] + 0.6, 2) if t is not None and t in done else None for t in targets]
def _foot(p):
    from . import v1
    return v1.arenas_module().footprint(p)
_SOLID_TILE = 1000
def _solid_index(pieces):
    out = {}
    for n, p in enumerate(pieces):
        if p.get("kind") in ("water",):
            continue
        x0, x1, z0, z1, _ = _foot(p)
        for tx in range(int(math.floor(x0 / _SOLID_TILE)), int(math.floor(x1 / _SOLID_TILE)) + 1):
            for tz in range(int(math.floor(z0 / _SOLID_TILE)),
                            int(math.floor(z1 / _SOLID_TILE)) + 1):
                out.setdefault((tx, tz), []).append((n, p, (x0, x1, z0, z1)))
    return out
def _solid_at_indexed(index, x, y0, y1, z, half):
    best = None
    seen = set()
    for tx in range(int(math.floor((x - half) / _SOLID_TILE)),
                    int(math.floor((x + half) / _SOLID_TILE)) + 1):
        for tz in range(int(math.floor((z - half) / _SOLID_TILE)),
                        int(math.floor((z + half) / _SOLID_TILE)) + 1):
            for n, p, (x0, x1, z0, z1) in index.get((tx, tz), ()):
                if n in seen or (best is not None and n >= best[0]):
                    continue
                seen.add(n)
                if x + half <= x0 + 1 or x - half >= x1 - 1 or z + half <= z0 + 1 \
                        or z - half >= z1 - 1:
                    continue
                if y1 <= p["y"] + 1 or y0 >= p["y"] + p["h"] - 1:
                    continue
                best = (n, p)
    return None if best is None else best[1]
def _solid_at(pieces, x, y0, y1, z, half):
    for p in pieces:
        if p.get("kind") in ("water",):
            continue
        x0, x1, z0, z1, _ = _foot(p)
        if x + half <= x0 + 1 or x - half >= x1 - 1 or z + half <= z0 + 1 or z - half >= z1 - 1:
            continue
        if y1 <= p["y"] + 1 or y0 >= p["y"] + p["h"] - 1:
            continue
        return p
    return None
def issues(arena):
    out = []
    movers = arena.get("movers") or []
    pieces = arena.get("pieces") or []
    if len(movers) > LIMITS["cap"]:
        out.append({"kind": "cap", "mover": None, "at": None,
                    "text": "%d movers - an area holds %d" % (len(movers), LIMITS["cap"])})
    index = _solid_index(pieces) if movers else {}
    for k, raw in enumerate(movers):
        m = normalise(raw)
        name = "mover %d (%s)" % (k + 1, m["key"])
        if not key_known(m["key"]):
            out.append({"kind": "key", "mover": k, "at": (m["x"], m["y"], m["z"]),
                        "text": "%s: the mod has no such block on a path" % name})
        half, height = SHAPES[shape_of(m["key"])]
        pts = m["points"]
        tl = timeline(m)
        hit = None
        for leg in tl["legs"]:
            if leg["wait"] or hit:
                continue
            a, b = pts[leg["a"]], pts[leg["b"]]
            n = max(1, int(leg["len"] // 50))
            for s in range(n + 1):
                f = s / float(n)
                x = m["x"] + a[0] + (b[0] - a[0]) * f
                y = m["y"] + a[1] + (b[1] - a[1]) * f
                z = m["z"] + a[2] + (b[2] - a[2]) * f
                p = _solid_at_indexed(index, x, y + 1, y + height - 1, z, half - 1)
                if p is not None:
                    hit = (p, (round(x), round(y), round(z)))
                    break
        if hit:
            out.append({"kind": "crosses", "mover": k, "at": hit[1],
                        "text": "%s runs through %s" % (name, hit[0].get("tag") or hit[0]["kind"])})
        top, side = top_speed(m)
        if side > STAND_SPEED:
            out.append({"kind": "fast", "mover": k, "at": (m["x"], m["y"], m["z"]),
                        "text": "%s rides at %d a second - too fast to stand on (%d)"
                                % (name, side, STAND_SPEED)})
        for leg in tl["legs"]:
            if leg["wait"]:
                continue
            a, b = pts[leg["a"]], pts[leg["b"]]
            if abs(b[1] - a[1]) / float(leg["frames"]) >= LIMITS["rise"] - 0.01 and \
                    leg["len"] / leg["frames"] * FPS < pts[leg["a"]][3] - 1:
                out.append({"kind": "climb", "mover": k, "at": (m["x"] + a[0], m["y"] + a[1],
                                                                 m["z"] + a[2]),
                            "text": "%s: leg %d->%d climbs faster than a rider can stay on; "
                                    "the mod slows it to %d a frame"
                                    % (name, leg["a"] + 1, leg["b"] + 1, LIMITS["rise"])})
                break
    if movers and pieces and arena.get("level"):
        from . import v1
        tool = v1.arenas_module()
        try:
            cells = tool.walk_cells(arena["pieces"], arena["level"])
        except Exception:
            cells = None
        if cells is not None:
            for k, raw in enumerate(movers):
                m = normalise(raw)
                one = dict(arena, movers=[m])
                linked = tool.mover_edges(one, cells)
                if not linked:
                    out.append({"kind": "stranded", "mover": k, "at": (m["x"], m["y"], m["z"]),
                                "text": "mover %d (%s): no floor to get on or off at its stops"
                                        % (k + 1, m["key"])})
    return out
def budget(arena):
    movers = arena.get("movers") or []
    return {"movers": len(movers), "objects": len(movers), "cap": LIMITS["cap"],
            "per_frame_meshes": len(movers)}
def descriptors(arena):
    movers = [normalise(m) for m in arena.get("movers") or []]
    logs = sum(1 for m in movers if shape_of(m["key"]) in ("log", "logwide"))
    lifts = sum(1 for m in movers if m["trigger"] == "ridden"
                or any(abs(p[1]) >= 400 for p in m["points"]))
    path = sum(timeline(m)["period"] for m in movers) / float(FPS) if movers else 0.0
    return {"movers": len(movers), "logs": logs, "lifts": lifts,
            "platforms": len(movers) - logs,
            "ride_seconds": round(path, 1),
            "mover_share": round(min(1.0, len(movers) / float(LIMITS["cap"])), 3)}
def to_studio(m):
    m = normalise(m)
    return {"key": m["key"], "mode": m["mode"], "trigger": m["trigger"], "phase": m["phase"],
            "yaw": m["yaw"], "modes": list(m.get("modes") or []), "link": m.get("link"),
            "points": [[m["x"] + p[0], m["y"] + p[1], m["z"] + p[2], p[3], p[4]]
                       for p in m["points"]]}
def from_studio(obj):
    pts = obj.get("points") or []
    if not pts:
        raise Refused("a path needs points")
    at = tuple(pts[0][:3])
    return mover(obj.get("key", platform_key()), at, pts, mode=obj.get("mode", "pingpong"),
                 trigger=obj.get("trigger", "always"), yaw=obj.get("yaw", 0),
                 phase=obj.get("phase", 0), modes=obj.get("modes") or None,
                 link=obj.get("link"))
