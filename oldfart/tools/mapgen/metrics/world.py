import collections
import math
from . import mario
from . import v1
G = mario.CELL
COARSE = 400
RISES_UP = {0: (0, -1), 90: (-1, 0), 180: (0, 1), 270: (1, 0)}
class Refused(ValueError):
    pass
def footprint(piece):
    yaw = piece.get("yaw", 0) % 360
    if yaw not in RISES_UP:
        raise Refused("only quarter turns are measured (yaw %s)" % piece.get("yaw"))
    w, d = piece["w"], piece["d"]
    if yaw in (90, 270):
        w, d = d, w
    x0, x1 = piece["x"] - w / 2, piece["x"] + w / 2
    z0, z1 = piece["z"] - d / 2, piece["z"] + d / 2
    s, c = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
    return x0, x1, z0, z1, (round(-s), round(-c))
FAST = ("box", "ramp", "stairs")
def kinds():
    return getattr(v1.tool(), "KINDS", {"box": {"walk": "floor"}, "ramp": {"walk": "ramp"},
                                         "stairs": {"walk": "stairs"}})
class Piece(object):
    __slots__ = ("i", "src", "kind", "x0", "x1", "z0", "z1", "up", "y", "h", "top_max",
                 "tex", "tag", "walk", "partial", "slope")
    def __init__(self, i, src):
        self.i = i
        self.src = src
        self.kind = src["kind"]
        self.x0, self.x1, self.z0, self.z1, self.up = footprint(src)
        self.y = src["y"]
        self.h = src["h"]
        self.top_max = self.y + max(self.h, 0)
        self.tex = src.get("tex", "")
        self.tag = src.get("tag", "")
        reg = kinds()
        if self.kind not in reg:
            raise Refused("unknown piece kind %r (v1 knows %s)" % (self.kind, ", ".join(sorted(reg))))
        self.walk = reg[self.kind].get("walk", "floor")
        self.partial = self.kind in ("prism", "pillar", "curve", "bank", "arcwall", "water",
                                    "roundcorner", "pole", "doorway", "window")
        self.slope = 0.0
        if self.walk in ("ramp", "stairs") and self.h > 0:
            if self.up[0] != 0:
                span = self.x1 - self.x0
            elif self.up[1] != 0:
                span = self.z1 - self.z0
            else:
                span = min(self.x1 - self.x0, self.z1 - self.z0)
            self.slope = self.h * G / max(span, 1.0)
    def top(self, x, z):
        if self.kind in ("box", "ice", "lava"):
            return self.y + self.h
        if self.kind not in FAST:
            return v1.tool().top_at(self.src, x, z)
        up = self.up
        if up[0] != 0:
            span = self.x1 - self.x0
            t = (x - self.x0) / span if up[0] > 0 else (self.x1 - x) / span
        else:
            span = self.z1 - self.z0
            t = (z - self.z0) / span if up[1] > 0 else (self.z1 - z) / span
        t = max(0.0, min(1.0, t))
        if self.kind == "stairs":
            steps = 10
            step = min(steps, int(t * steps) + 1)
            return self.y + self.h * step / steps
        return self.y + self.h * t
    def covers(self, x, z):
        return not self.partial or v1.tool().covers(self.src, x, z)
    def contains(self, x, z):
        return self.x0 < x < self.x1 and self.z0 < z < self.z1 and self.covers(x, z)
    def contains_inclusive(self, x, z):
        return self.x0 <= x <= self.x1 and self.z0 <= z <= self.z1 and self.covers(x, z)
    @property
    def sloped(self):
        return self.walk in ("ramp", "stairs")
class World(object):
    def __init__(self, arena):
        self.arena = arena
        ma = v1.tool()
        self.level_name = arena.get("level", "empty2")
        self.level = ma.LEVELS[self.level_name]
        self.pieces = [Piece(i, p) for i, p in enumerate(arena["pieces"])]
        if not self.pieces:
            raise Refused("an arena without pieces")
        self.spawns = list(arena.get("spawns", []))
        self._build_walk()
        self._build_columns()
        self._los_index = None
    def _standable(self, cand, x, z):
        tops = [(p.top(x, z), p) for p in cand if p.covers(x, z)]
        floor = self.level["floor"]
        half = self.level["half"]
        if floor is not None and abs(x) <= half and abs(z) <= half:
            tops.append((floor, None))
        out = {}
        slope = {}
        tall = mario.MARIO_TALL
        for height, piece in tops:
            if piece is not None and piece.walk == "hazard":
                continue
            clear = True
            for other in cand:
                if other is piece or not other.contains(x, z):
                    continue
                if other.y < height + tall and other.top(x, z) > height + 1:
                    clear = False
                    break
            if clear:
                h = round(height)
                flat = piece is None or not piece.sloped
                out[h] = out.get(h, False) or flat
                if piece is not None and piece.slope:
                    slope[h] = max(slope.get(h, 0.0), piece.slope)
        self._last_slope = slope
        return sorted(out.items())
    def _build_walk(self):
        buckets = collections.defaultdict(list)
        for p in self.pieces:
            for gx in range(int(math.ceil((p.x0 - G / 2) / G)), int(math.floor((p.x1 - G / 2) / G)) + 1):
                for gz in range(int(math.ceil((p.z0 - G / 2) / G)), int(math.floor((p.z1 - G / 2) / G)) + 1):
                    buckets[(gx, gz)].append(p)
        self.buckets = buckets
        src = self.arena.get("pieces") or []
        play = [p for p in self.pieces
                if not str(src[p.i].get("tag", "")).startswith("dress.backdrop")] or self.pieces
        lo_x = min(p.x0 for p in play)
        hi_x = max(p.x1 for p in play)
        lo_z = min(p.z0 for p in play)
        hi_z = max(p.z1 for p in play)
        has_floor = self.level["floor"] is not None
        cells = []
        flat = {}
        slopes = {}
        gx = int(math.floor(lo_x / G))
        while gx * G <= hi_x:
            gz = int(math.floor(lo_z / G))
            while gz * G <= hi_z:
                cand = buckets.get((gx, gz))
                if cand or has_floor:
                    for h, f in self._standable(cand or [], gx * G + G / 2, gz * G + G / 2):
                        cells.append((gx, gz, h))
                        flat[(gx, gz, h)] = f
                        if h in self._last_slope:
                            slopes[(gx, gz, h)] = self._last_slope[h]
                gz += 1
            gx += 1
        by_column = collections.defaultdict(list)
        for c in cells:
            by_column[(c[0], c[1])].append(c[2])
        jump, drop = v1.tool().JUMP_UP, v1.tool().SAFE_DROP
        edges = {}
        for (gx, gz, h) in cells:
            out = []
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                for h2 in by_column.get((gx + dx, gz + dz), ()):
                    rise = h2 - h
                    if rise <= jump and -rise <= drop:
                        out.append((gx + dx, gz + dz, h2))
            edges[(gx, gz, h)] = out
        mover_edges = getattr(v1.tool(), "mover_edges", None)
        self.mover_edges = mover_edges(self.arena, cells) if mover_edges else {}
        for a, outs in self.mover_edges.items():
            edges.setdefault(a, []).extend(outs)
        self.all_cells = cells
        self.all_edges = edges
        start = self.spawn_cell(self.spawns[0]) if self.spawns else (cells[0] if cells else None)
        if start not in edges:
            start = self.nearest_cell_of(start, cells) if cells else None
        keep = set()
        if start is not None:
            keep.add(start)
            todo = [start]
            while todo:
                u = todo.pop()
                for v in edges[u]:
                    if v not in keep:
                        keep.add(v)
                        todo.append(v)
        self.nodes = [c for c in cells if c in keep]
        self.index = {c: i for i, c in enumerate(self.nodes)}
        idx = self.index
        self.adj = [[idx[v] for v in edges[c] if v in idx] for c in self.nodes]
        radj = [[] for _ in self.nodes]
        for u, vs in enumerate(self.adj):
            for v in vs:
                radj[v].append(u)
        self.radj = radj
        aset = [set(vs) for vs in self.adj]
        self.adj2 = [[v for v in vs if u in aset[v]] for u, vs in enumerate(self.adj)]
        self.flat = [flat[c] for c in self.nodes]
        self.slope = [slopes.get(c, 0.0) for c in self.nodes]
        self.unreached = len(cells) - len(self.nodes)
    def _build_columns(self):
        col = {}
        for i, (gx, gz, h) in enumerate(self.nodes):
            k = (gx, gz)
            if k not in col or self.nodes[col[k]][2] < h:
                col[k] = i
        self.columns = col
    @staticmethod
    def spawn_cell(spot):
        return (int(math.floor(spot["x"] / G)), int(math.floor(spot["z"] / G)),
                int(round(spot.get("y", 0))))
    @staticmethod
    def nearest_cell_of(cell, cells):
        gx, gz, h = cell
        return min(cells, key=lambda c: (abs(c[0] - gx) + abs(c[1] - gz), abs(c[2] - h)))
    def node_of(self, spot):
        c = self.spawn_cell(spot)
        if c in self.index:
            return self.index[c]
        best, bd = None, None
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                for h in self._col_heights(c[0] + dx, c[1] + dz):
                    d = (abs(dx) + abs(dz)) * 100 + abs(h - c[2])
                    if bd is None or d < bd:
                        best, bd = self.index[(c[0] + dx, c[1] + dz, h)], d
        if best is not None:
            return best
        return self.index[self.nearest_cell_of(c, self.nodes)]
    def _col_heights(self, gx, gz):
        if not hasattr(self, "_colh"):
            colh = collections.defaultdict(list)
            for (x, z, h) in self.nodes:
                colh[(x, z)].append(h)
            self._colh = colh
        return self._colh.get((gx, gz), ())
    def centre_node(self):
        best = min(self.nodes, key=lambda c: (abs(c[0] + .5) + abs(c[1] + .5), -c[2]))
        return self.index[best]
    def node_xyz(self, i):
        gx, gz, h = self.nodes[i]
        return ((gx + .5) * G, h, (gz + .5) * G)
    def bounds(self):
        ps = [p for p in self.pieces if not str(p.tag or "").startswith("dress.backdrop")] \
            or self.pieces
        return (min(p.x0 for p in ps), max(p.x1 for p in ps),
                min(p.z0 for p in ps), max(p.z1 for p in ps))
    def _build_los(self):
        idx = collections.defaultdict(list)
        coarse_max = {}
        coarse_min = {}
        for p in self.pieces:
            for gx in range(int(math.floor(p.x0 / G)), int(math.ceil(p.x1 / G))):
                for gz in range(int(math.floor(p.z0 / G)), int(math.ceil(p.z1 / G))):
                    idx[(gx, gz)].append(p)
            for cx in range(int(math.floor(p.x0 / COARSE)), int(math.ceil(p.x1 / COARSE))):
                for cz in range(int(math.floor(p.z0 / COARSE)), int(math.ceil(p.z1 / COARSE))):
                    k = (cx, cz)
                    coarse_max[k] = max(coarse_max.get(k, -1e18), p.top_max)
                    coarse_min[k] = min(coarse_min.get(k, 1e18), p.y)
        self._los_index = (idx, coarse_max, coarse_min)
    def blocked(self, a, b):
        if self._los_index is None:
            self._build_los()
        idx, cmax, cmin = self._los_index
        ax, ay, az = a
        bx, by, bz = b
        dx, dy, dz = bx - ax, by - ay, bz - az
        n = int(max(abs(dx), abs(dz)) / 50) + 1
        i = 1
        CH = 8
        floor = math.floor
        while i < n:
            j = min(n - 1, i + CH - 1)
            t0, t1 = i / n, j / n
            x0, x1 = ax + dx * t0, ax + dx * t1
            z0, z1 = az + dz * t0, az + dz * t1
            y0, y1 = ay + dy * t0, ay + dy * t1
            ylo, yhi = min(y0, y1), max(y0, y1)
            hi, lo = -1e18, 1e18
            for cx in range(int(floor(min(x0, x1) / COARSE)), int(floor(max(x0, x1) / COARSE)) + 1):
                for cz in range(int(floor(min(z0, z1) / COARSE)), int(floor(max(z0, z1) / COARSE)) + 1):
                    k = (cx, cz)
                    if k in cmax:
                        if cmax[k] > hi:
                            hi = cmax[k]
                        if cmin[k] < lo:
                            lo = cmin[k]
            if ylo >= hi - 1 or yhi <= lo:
                i = j + 1
                continue
            for s in range(i, j + 1):
                t = s / n
                x, y, z = ax + dx * t, ay + dy * t, az + dz * t
                for p in idx.get((int(floor(x / G)), int(floor(z / G))), ()):
                    if p.x0 < x < p.x1 and p.z0 < z < p.z1 and p.covers(x, z):
                        t = p.top(x, z)
                        if t is not None and p.y < y < t - 1:
                            return True
            i = j + 1
        return False
    def visible(self, a, b):
        return not self.blocked(a, b)
_CACHE = {}
def world_of(arena):
    key = id(arena)
    hit = _CACHE.get(key)
    if hit is not None and hit.arena is arena:
        return hit
    w = World(arena)
    if len(_CACHE) > 32:
        _CACHE.clear()
    _CACHE[key] = w
    return w
