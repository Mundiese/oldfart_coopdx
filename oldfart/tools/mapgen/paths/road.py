import math
from .. import cells, kit, v1
from . import shape
LAYER = 50
def q(v, step=200):
    return int(round(v / float(step))) * step
def qdown(v, step=LAYER):
    return int(math.floor(v / float(step))) * step
def yaw_of(d):
    return {(1, 0): 90, (0, 1): 0, (-1, 0): 270, (0, -1): 180}[d]
def axis_rises(d, up):
    sign = (d[0] or d[1]) * (1 if up else -1)
    return ("+" if sign > 0 else "-") + ("x" if d[0] else "z")
class Node:
    def __init__(self, k, v, pos, din, dout):
        self.k = k
        self.v = v
        self.x, self.z = pos
        self.din = din
        self.dout = dout
        self.corner = din != dout
        self.crossing = False
        self.h = 0
        self.tags = set()
    def __repr__(self):
        return "Node(%d %s %s h%d%s)" % (self.k, self.v, "corner" if self.corner else "straight",
                                         self.h, " " + ",".join(sorted(self.tags)) if self.tags else "")
class Track:
    def __init__(self, points, C, W, closed=True, ratio=1 / 3.0, origin=None):
        self.C = C
        self.W = W
        self.closed = closed
        self.ratio = ratio
        n = len(points)
        if origin is None:
            xs = [p[0] for p in points]
            zs = [p[1] for p in points]
            origin = (-q(C * (min(xs) + max(xs)) / 2.0), -q(C * (min(zs) + max(zs)) / 2.0))
        self.origin = origin
        self.nodes = []
        for k, p in enumerate(points):
            if closed or 0 < k < n - 1:
                a, b = points[k - 1], points[(k + 1) % n]
                din = (p[0] - a[0], p[1] - a[1])
                dout = (b[0] - p[0], b[1] - p[1])
            elif k == 0:
                b = points[1]
                dout = (b[0] - p[0], b[1] - p[1])
                din = dout
            else:
                a = points[k - 1]
                din = (p[0] - a[0], p[1] - a[1])
                dout = din
            pos = (origin[0] + p[0] * C, origin[1] + p[1] * C)
            self.nodes.append(Node(k, p, pos, din, dout))
        seen = {}
        for nd in self.nodes:
            seen.setdefault(nd.v, []).append(nd)
        for v, nds in seen.items():
            if len(nds) > 1:
                for nd in nds:
                    nd.crossing = True
                    nd.corner = False
        self.cut = {}
        self.chords = []
        self.extra = []
        self.keep_clear = []
    def segs(self):
        n = len(self.nodes)
        return [(k, (k + 1) % n) for k in range(n if self.closed else n - 1)]
    def occ(self, nd):
        if nd.corner:
            return self.W // 2
        if not self.closed and nd.k in (0, len(self.nodes) - 1):
            return self.W // 2
        return 0
    def free(self, a, b):
        na, nb = self.nodes[a], self.nodes[b]
        s = max(self.occ(na), self.cut.get(a, 0))
        e = self.C - max(self.occ(nb), self.cut.get(b, 0))
        return s, e
    def maxrise(self, a, b, ratio=None):
        s, e = self.free(a, b)
        return qdown((e - s) * (ratio or self.ratio))
    def length(self):
        return self.C * len(self.segs())
    def point(self, k, t):
        nd = self.nodes[k]
        return nd.x + nd.dout[0] * t, nd.z + nd.dout[1] * t
    def height_at(self, k, t):
        a = self.nodes[k]
        b = self.nodes[(k + 1) % len(self.nodes)]
        if a.h == b.h:
            return a.h
        s, e = self.free(k, (k + 1) % len(self.nodes))
        if t <= s:
            return a.h
        if t >= e:
            return b.h
        return None
    def relax(self, wish, locked_low=(), ratio=None):
        h = list(wish)
        segs = self.segs()
        mr = {(a, b): self.maxrise(a, b, ratio) for a, b in segs}
        for _ in range(4 * len(h) + 4):
            changed = False
            for a, b in segs:
                m = mr[(a, b)]
                if h[b] < h[a] - m:
                    h[b] = h[a] - m
                    changed = True
                if h[a] < h[b] - m:
                    h[a] = h[b] - m
                    changed = True
            if not changed:
                break
        for k in locked_low:
            if h[k] > wish[k]:
                return False
        for nd, v in zip(self.nodes, h):
            nd.h = int(v)
        return True
    def road_rect(self, k, s, e, half=None):
        half = self.W // 2 if half is None else half
        nd = self.nodes[k]
        d = nd.dout
        ax, az = nd.x + d[0] * s, nd.z + d[1] * s
        bx, bz = nd.x + d[0] * e, nd.z + d[1] * e
        if d[0]:
            return (min(ax, bx), max(ax, bx), az - half, az + half)
        return (ax - half, ax + half, min(az, bz), max(az, bz))
    def pieces(self, pal, thick=200, walls=True, wall_high=600, plateau_tex=None):
        box, ramp = kit.kind("box"), kit.kind("ramp")
        out = []
        W = self.W
        n = len(self.nodes)
        for a, b in self.segs():
            na, nb = self.nodes[a], self.nodes[b]
            s, e = self.free(a, b)
            if e - s <= 0:
                continue
            x0, x1, z0, z1 = self.road_rect(a, s, e)
            chord = [c for c in self.chords if c[0] == a]
            if na.h == nb.h:
                tex = pal["road"]
                if plateau_tex and na.h > 0 and na.h == nb.h and ("plateau" in na.tags
                                                                  and "plateau" in nb.tags):
                    tex = plateau_tex
                out.append(box.make(tex, x0, x1, na.h - thick, na.h, z0, z1, None,
                                    "road.%d" % a))
            else:
                up = nb.h > na.h
                lo, hi = min(na.h, nb.h), max(na.h, nb.h)
                out.append(ramp.make(pal["road"], x0, x1, lo, hi, z0, z1,
                                     axis_rises(na.dout, up), "ramp.%d" % a))
        for nd in self.nodes:
            if nd.corner or (not self.closed and nd.k in (0, n - 1)):
                x0, x1, z0, z1 = nd.x - W // 2, nd.x + W // 2, nd.z - W // 2, nd.z + W // 2
                inner = self.inner_corner(nd) if nd.corner and self.round else None
                if inner is not None:
                    out += self.round_corner(nd, inner, pal, thick, walls, wall_high)
                    continue
                out.append(box.make(pal["pad"], x0, x1, nd.h - thick, nd.h, z0, z1, None,
                                    "pad.%d" % nd.k))
                if walls and nd.corner:
                    out += self.corner_walls(nd, pal, thick, wall_high)
        return out + list(self.extra)
    round = False
    banked = False
    def inner_corner(self, nd):
        sides = self.open_sides(nd)
        if len(sides) != 2:
            return None
        sx = sum(d[0] for d in sides)
        sz = sum(d[1] for d in sides)
        if not sx or not sz:
            return None
        return ("+x" if sx > 0 else "-x") + ("+z" if sz > 0 else "-z")
    def round_corner(self, nd, inner, pal, thick, walls, high):
        W = self.W
        cx = nd.x + (W // 2 if inner[0] == "+" else -W // 2)
        cz = nd.z + (W // 2 if inner[2] == "+" else -W // 2)
        def square(R):
            x0, x1 = (cx - R, cx) if inner[0] == "+" else (cx, cx + R)
            z0, z1 = (cz - R, cz) if inner[2] == "+" else (cz, cz + R)
            return x0, x1, z0, z1
        out = []
        x0, x1, z0, z1 = square(W)
        out.append(kit.kind("curve").make(pal["pad"], x0, x1, nd.h - thick, nd.h, z0, z1,
                                          inner, "pad.%d" % nd.k))
        R = W
        if self.banked:
            Rb = int(round(W / 0.6))
            x0, x1, z0, z1 = square(Rb)
            out.append(kit.kind("bank").make(pal["road"], x0, x1, nd.h - thick, nd.h + thick,
                                             z0, z1, inner, "bank.%d" % nd.k))
            R = Rb
        if walls:
            Rw = int(round(R / 0.9))
            x0, x1, z0, z1 = square(Rw)
            top = nd.h + high + (thick if self.banked else 0)
            out.append(kit.kind("arcwall").make(pal["wall"], x0, x1, nd.h - thick, top,
                                                z0, z1, inner, "wall.%d" % nd.k))
        return out
    def open_sides(self, nd):
        sides = {(-nd.din[0], -nd.din[1]), nd.dout}
        for c in self.chords:
            if c[0] == nd.k:
                sides.add(nd.din)
            if c[1] == nd.k:
                sides.add((-nd.dout[0], -nd.dout[1]))
        return sides
    def corner_walls(self, nd, pal, thick=200, high=600):
        box = kit.kind("box")
        W, T = self.W, 200
        out = []
        for d in shape.DIRS:
            if d in self.open_sides(nd):
                continue
            if d[0]:
                x0 = nd.x + d[0] * W // 2 + (0 if d[0] > 0 else -T)
                rect = (x0, x0 + T, nd.z - W // 2 - T, nd.z + W // 2 + T)
            else:
                z0 = nd.z + d[1] * W // 2 + (0 if d[1] > 0 else -T)
                rect = (nd.x - W // 2 - T, nd.x + W // 2 + T, z0, z0 + T)
            out.append(box.make(pal["wall"], rect[0], rect[1], nd.h - thick, nd.h + high,
                                rect[2], rect[3], None, "wall.%d" % nd.k))
        return out
    def spots(self, step=200, skip=()):
        out = []
        s0 = 0
        for a, b in self.segs():
            if a in skip:
                s0 += self.C
                continue
            t = 0
            while t < self.C:
                x, z = self.point(a, t)
                out.append({"s": s0 + t, "x": x, "z": z, "h": self.height_at(a, t),
                            "d": self.nodes[a].dout, "k": a, "t": t})
                t += step
            s0 += self.C
        return out
def compile_pieces(pieces):
    from .. import solids
    grid = cells.CellGrid.from_pieces(pieces)
    merged, _ = solids.resolve(grid.to_pieces())
    m = v1.arenas_module()
    for p in merged:
        p["model"] = m.model_name(p)
    return merged
def rects_overlap(a, b, margin=0):
    return (a[0] - margin < b[1] and b[0] - margin < a[1]
            and a[2] - margin < b[3] and b[2] - margin < a[3])
def piece_rect(p):
    return cells.piece_rect(p)
def top_at(pieces, x, z):
    m = v1.arenas_module()
    tops = []
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        if x0 <= x <= x1 and z0 <= z <= z1 and m.covers(p, x, z):
            t = m.top_at(p, x, z)
            if t is not None:
                tops.append(t)
    return tops
def marker(kind, num, a, b, x, y, z, label=""):
    return v1.arenas_module().marker(kind, num, int(a), int(b), int(round(x)), int(round(y)),
                                     int(round(z)), label)
