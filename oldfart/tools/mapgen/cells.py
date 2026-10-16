import bisect
import collections
import heapq
from . import kit, v1
CELL = 200
LAYER = 50
def _longest():
    return v1.arenas_module().LONGEST_FACE
def rise_axis(rises):
    return rises[1], (1 if rises[0] == "+" else -1)
def piece_rect(piece):
    x0, x1, z0, z1, _ = v1.arenas_module().footprint(piece)
    return x0, x1, z0, z1
def wedge_descriptor(piece):
    m = v1.arenas_module()
    x0, x1, z0, z1, up = m.footprint(piece)
    if up[0] > 0:
        rises, lo, hi = "+x", x0, x1
    elif up[0] < 0:
        rises, lo, hi = "-x", x1, x0
    elif up[1] > 0:
        rises, lo, hi = "+z", z0, z1
    else:
        rises, lo, hi = "-z", z1, z0
    return (piece["kind"], kit.tex_key(piece), rises, _n(lo), _n(hi), _n(piece["y"]),
            _n(piece["y"] + piece["h"]))
def _n(v):
    r = round(v, 3)
    return int(r) if r == int(r) else r
class CellGrid:
    def __init__(self, xs, zs):
        self.xs = sorted(set(_n(x) for x in xs))
        self.zs = sorted(set(_n(z) for z in zs))
        self.boxes = {}
        self.wedges = {}
        self.atomic = []
    @classmethod
    def uniform(cls, x0, x1, z0, z1, cell=CELL):
        return cls(range(int(x0), int(x1) + 1, cell), range(int(z0), int(z1) + 1, cell))
    @classmethod
    def from_pieces(cls, pieces, extra_xs=(), extra_zs=()):
        xs, zs = list(extra_xs), list(extra_zs)
        for p in pieces:
            x0, x1, z0, z1 = piece_rect(p)
            xs += [x0, x1]
            zs += [z0, z1]
        grid = cls(xs, zs)
        for p in pieces:
            grid.add_piece(p)
        return grid
    def _range(self, lines, a, b):
        i0 = bisect.bisect_left(lines, _n(a))
        i1 = bisect.bisect_left(lines, _n(b))
        if i0 >= len(lines) or lines[i0] != _n(a) or i1 >= len(lines) or lines[i1] != _n(b):
            raise ValueError("%s..%s is not on the grid's lines" % (a, b))
        return range(i0, i1)
    def columns(self, x0, x1, z0, z1):
        for i in self._range(self.xs, x0, x1):
            for k in self._range(self.zs, z0, z1):
                yield i, k
    def refine(self, xs=(), zs=()):
        g = CellGrid(list(self.xs) + list(xs), list(self.zs) + list(zs))
        for src, dst in ((self.boxes, g.boxes), (self.wedges, g.wedges)):
            for c, content in src.items():
                for c2 in g.columns(*self.column_rect(c)):
                    dst[c2] = list(content)
        g.atomic = [dict(p) for p in self.atomic]
        return g
    def add_piece(self, p, tag=None):
        tag = p.get("tag", "") if tag is None else tag
        cells = kit.kind(p["kind"]).cells
        x0, x1, z0, z1 = piece_rect(p)
        if cells == "atomic":
            self.atomic.append(dict(p))
            return
        if cells == "box":
            span = (kit.tex_key(p), _n(p["y"]), _n(p["y"] + p["h"]), tag)
            for c in self.columns(x0, x1, z0, z1):
                self._add_box(c, span)
            return
        desc = wedge_descriptor(p)
        for c in self.columns(x0, x1, z0, z1):
            lst = self.wedges.setdefault(c, [])
            if all(d != desc for d, _ in lst):
                lst.append((desc, tag))
    def _add_box(self, c, span):
        tex, y0, y1, tag = span
        lst = self.boxes.setdefault(c, [])
        keep = []
        for s in lst:
            if s[0] == tex and s[1] < y1 and y0 < s[2]:
                y0, y1 = min(y0, s[1]), max(y1, s[2])
                tag = tag or s[3]
            else:
                keep.append(s)
        keep.append((tex, y0, y1, tag))
        keep.sort(key=lambda s: (s[1], s[2], str(s[0])))
        self.boxes[c] = keep
    def carve(self, x0, x1, z0, z1, y0=-10 ** 6, y1=10 ** 6):
        if not (_n(x0) in self.xs and _n(x1) in self.xs and _n(z0) in self.zs
                and _n(z1) in self.zs):
            g = self.refine([x0, x1], [z0, z1])
            self.__dict__.update(g.__dict__)
        for c in self.columns(x0, x1, z0, z1):
            out = []
            for tex, a, b, tag in self.boxes.get(c, []):
                if b <= y0 or a >= y1:
                    out.append((tex, a, b, tag))
                    continue
                if a < y0:
                    out.append((tex, a, y0, tag))
                if b > y1:
                    out.append((tex, y1, b, tag))
            if out:
                self.boxes[c] = out
            else:
                self.boxes.pop(c, None)
            ws = [w for w in self.wedges.get(c, []) if w[0][6] <= y0 or w[0][5] >= y1]
            if ws:
                self.wedges[c] = ws
            else:
                self.wedges.pop(c, None)
        self.atomic = [p for p in self.atomic if not _inside(piece_rect(p), (x0, x1, z0, z1))]
    def column_rect(self, c):
        i, k = c
        return self.xs[i], self.xs[i + 1], self.zs[k], self.zs[k + 1]
    def signature(self, xs=None, zs=None):
        g = self if xs is None else self.refine(xs, zs)
        out = []
        for c in sorted(set(g.boxes) | set(g.wedges)):
            rect = g.column_rect(c)
            spans = tuple(sorted(((t, a, b) for t, a, b, _ in g.boxes.get(c, [])), key=str))
            wedges = tuple(sorted((d for d, _ in g.wedges.get(c, [])), key=str))
            out.append((rect, spans, wedges))
        out.append(tuple(sorted((_atomic_key(p) for p in g.atomic), key=str)))
        return out
    def heights(self):
        hs = set()
        for spans in self.boxes.values():
            for _, a, b, _ in spans:
                hs.update((a, b))
        for ws in self.wedges.values():
            for d, _ in ws:
                hs.update((d[5], d[6]))
        return hs
    def off_quantum(self, cell=CELL, layer=LAYER):
        return {"x": [x for x in self.xs if x % cell], "z": [z for z in self.zs if z % cell],
                "y": sorted(h for h in self.heights() if h % layer)}
    def to_pieces(self, merge=True, disjoint=False):
        longest = _longest()
        m = v1.arenas_module()
        out = []
        by_key = {}
        tags = {}
        for c, spans in self.boxes.items():
            for tex, a, b, tag in spans:
                key = (tex, a, b)
                by_key.setdefault(key, set()).add(c)
                tags.setdefault((key, c), tag)
        for key in sorted(by_key, key=lambda k: (k[1], k[2], str(k[0]))):
            tex, y0, y1 = key
            for (i0, i1, k0, k1) in self._rectangles(by_key[key], merge, longest, disjoint):
                tag = tags[(key, (i0, k0))]
                for ya, yb in _split(y0, y1, longest):
                    out.append(kit.with_tex(m.box(None, self.xs[i0], self.xs[i1], ya, yb,
                                                  self.zs[k0], self.zs[k1], tag), tex))
        by_desc = {}
        wtags = {}
        for c, ws in self.wedges.items():
            for d, tag in ws:
                by_desc.setdefault(d, set()).add(c)
                wtags.setdefault(d, tag)
        for d in sorted(by_desc, key=lambda d: (d[5], d[6], d[0], str(d[1]), d[2], d[3], d[4])):
            out += self._wedge_pieces(d, by_desc[d], wtags[d], merge, longest, disjoint)
        out += [dict(p) for p in self.atomic]
        for p in out:
            p["x"], p["y"], p["z"] = _n(p["x"]), _n(p["y"]), _n(p["z"])
            p["w"], p["h"], p["d"] = _n(p["w"]), _n(p["h"]), _n(p["d"])
        return out
    def _rectangles(self, cols, merge, longest, disjoint=False):
        if not merge:
            return [(i, i + 1, k, k + 1) for i, k in sorted(cols, key=lambda c: (c[1], c[0]))]
        cols = set(cols)
        if disjoint:
            return self._exact_cover(cols, longest)
        cands = set()
        runs = self._runs(cols)
        for (i, k) in cols:
            cands.add(self._grow_runs(runs, i, k, True, longest))
            cands.add(self._grow_runs(runs, i, k, False, longest))
        cands = sorted(cands, key=lambda r: (r[2], r[0], r[3], r[1]))
        cover = {r: set((i, k) for i in range(r[0], r[1]) for k in range(r[2], r[3]))
                 for r in cands}
        left = set(cols)
        rects = []
        heap = [(-len(cover[r]), n, r) for n, r in enumerate(cands)]
        heapq.heapify(heap)
        while left:
            neg, n, r = heapq.heappop(heap)
            gain = len(cover[r] & left)
            if gain == -neg:
                rects.append(r)
                left -= cover[r]
            elif gain > 0:
                heapq.heappush(heap, (-gain, n, r))
        rects.sort(key=lambda r: (r[2], r[0], r[3], r[1]))
        return rects
    @staticmethod
    def _runs(cols):
        right, down = {}, {}
        for (i, k) in sorted(cols, reverse=True):
            right[(i, k)] = 1 + right.get((i + 1, k), 0)
            down[(i, k)] = 1 + down.get((i, k + 1), 0)
        return right, down
    def _grow_runs(self, runs, i0, k0, x_first, longest):
        right, down = runs
        xs, zs = self.xs, self.zs
        jx = min(len(xs) - 1, bisect.bisect_right(xs, xs[i0] + longest) - 1)
        jz = min(len(zs) - 1, bisect.bisect_right(zs, zs[k0] + longest) - 1)
        if x_first:
            i1 = i0 + 1 + min(right.get((i0 + 1, k0), 0), max(0, jx - i0 - 1))
            k1 = k0 + 1
            while k1 + 1 <= jz and right.get((i0, k1), 0) >= i1 - i0:
                k1 += 1
        else:
            k1 = k0 + 1 + min(down.get((i0, k0 + 1), 0), max(0, jz - k0 - 1))
            i1 = i0 + 1
            while i1 + 1 <= jx and down.get((i1, k0), 0) >= k1 - k0:
                i1 += 1
        return (i0, i1, k0, k1)
    def _grow(self, cols, i0, k0, x_first, longest):
        i1, k1 = i0 + 1, k0 + 1
        def grow_x(i1, k0, k1):
            while (i1 + 1 < len(self.xs) and self.xs[i1 + 1] - self.xs[i0] <= longest
                   and all((i1, k) in cols for k in range(k0, k1))):
                i1 += 1
            return i1
        def grow_z(k1, i0, i1):
            while (k1 + 1 < len(self.zs) and self.zs[k1 + 1] - self.zs[k0] <= longest
                   and all((i, k1) in cols for i in range(i0, i1))):
                k1 += 1
            return k1
        if x_first:
            i1 = grow_x(i1, k0, k1)
            k1 = grow_z(k1, i0, i1)
        else:
            k1 = grow_z(k1, i0, i1)
            i1 = grow_x(i1, k0, k1)
        return (i0, i1, k0, k1)
    def _exact_cover(self, cols, longest):
        left = set(cols)
        rects = []
        grown = {}
        inside = collections.defaultdict(set)
        heap = []
        def grow(i, k):
            for xf in (0, 1):
                r = self._grow(left, i, k, xf == 0, longest)
                key = (k, i, xf)
                grown[key] = r
                for ci in range(r[0], r[1]):
                    for ck in range(r[2], r[3]):
                        inside[(ci, ck)].add(key)
                heapq.heappush(heap, (-(r[1] - r[0]) * (r[3] - r[2]), key, r))
        for (i, k) in left:
            grow(i, k)
        while left:
            neg, key, r = heapq.heappop(heap)
            if grown.get(key) != r:
                continue
            best = r
            rects.append(best)
            gone = set((i, k) for i in range(best[0], best[1]) for k in range(best[2], best[3]))
            left -= gone
            again = set()
            for c in gone:
                again |= inside.pop(c, set())
            for key2 in again:
                grown.pop(key2, None)
            for (k2, i2) in set((k2, i2) for k2, i2, _ in again):
                if (i2, k2) in left:
                    grow(i2, k2)
        rects.sort(key=lambda r: (r[2], r[0], r[3], r[1]))
        return rects
    def _wedge_pieces(self, d, cols, tag, merge, longest, disjoint=False):
        kind, tex, rises, lo, hi, y0, y1 = d
        axis, sign = rise_axis(rises)
        maker = kit.kind(kind).make
        out = []
        for (i0, i1, k0, k1) in self._rectangles(cols, merge, longest, disjoint):
            x0, x1, z0, z1 = self.xs[i0], self.xs[i1], self.zs[k0], self.zs[k1]
            a, b = (x0, x1) if axis == "x" else (z0, z1)
            if sign < 0:
                a, b = b, a
            full = (_n(a) == lo and _n(b) == hi)
            if full:
                out.append(kit.with_tex(maker(None, x0, x1, y0, y1, z0, z1, rises, tag), tex))
                continue
            span = float(hi - lo)
            ya = _n(y0 + (y1 - y0) * (a - lo) / span)
            yb = _n(y0 + (y1 - y0) * (b - lo) / span)
            part_kind = "ramp" if kit.kind(kind).cells == "wedge" else kind
            out.append(kit.with_tex(kit.kind(part_kind).make(None, x0, x1, ya, yb, z0, z1, rises,
                                                             tag), tex))
            if ya > y0:
                out.append(kit.with_tex(kit.kind("box").make(None, x0, x1, y0, ya, z0, z1, None,
                                                             tag), tex))
        return out
def _split(y0, y1, longest):
    out = []
    while y1 - y0 > longest:
        out.append((y0, y0 + longest))
        y0 += longest
    out.append((y0, y1))
    return out
def _inside(rect, region):
    return (rect[0] >= region[0] and rect[1] <= region[1] and rect[2] >= region[2]
            and rect[3] <= region[3])
def _atomic_key(p):
    return (p["kind"], kit.tex_key(p), _n(p["x"]), _n(p["y"]), _n(p["z"]), _n(p["w"]), _n(p["h"]),
            _n(p["d"]), _n(p["yaw"]))
def same_geometry(pieces_a, pieces_b):
    ga = CellGrid.from_pieces(pieces_a)
    gb = CellGrid.from_pieces(pieces_b)
    xs = sorted(set(ga.xs) | set(gb.xs))
    zs = sorted(set(ga.zs) | set(gb.zs))
    return ga.signature(xs, zs) == gb.signature(xs, zs)
def compile_pieces(pieces, budget=None):
    return CellGrid.from_pieces(pieces).to_pieces()
def venue_cells(key):
    return CellGrid.from_pieces(v1.venue(key)["pieces"])
def cut_module(key, tags=None, region=None, shift=(0, 0, 0)):
    out = []
    for p in v1.venue(key)["pieces"]:
        if tags is not None and p.get("tag") not in tags:
            continue
        if region is not None and not _inside(piece_rect(p), region):
            continue
        q = dict(p)
        q.pop("model", None)
        q["x"] += shift[0]
        q["y"] += shift[1]
        q["z"] += shift[2]
        out.append(q)
    return out
