from . import cells, kit, v1
OVERLAP_TOLERANCE = 2
SAMPLE = 25
TEXTURE_SPAN = 200
MIN_PART = 40
FULL_RECT = ("rail", "arch", "outer", "inner", "outerstairs", "innerstairs")
def _m():
    return v1.arenas_module()
def column(p, x, z):
    t = _m().top_at(p, x, z)
    if t is None:
        return None
    return (p["y"], t)
def same_solid(a, b):
    if a["kind"] != "box" or b["kind"] != "box" or kit.tex_key(a) != kit.tex_key(b):
        return False
    if a["y"] != b["y"] or a["h"] != b["h"]:
        return False
    ra, rb = cells.piece_rect(a), cells.piece_rect(b)
    return all((ra[k] - rb[k]) % TEXTURE_SPAN == 0 for k in range(4))
ARC_KINDS = ("curve", "bank", "arcwall")
def arc_centre(p):
    m = _m()
    x0, x1, z0, z1, _ = m.footprint(p)
    corner = {0: (x0, z0), 90: (x0, z1), 180: (x1, z1), 270: (x1, z0)}
    return corner[p["yaw"] % 360]
def concentric(a, b):
    return (a["kind"] in ARC_KINDS and b["kind"] in ARC_KINDS
            and arc_centre(a) == arc_centre(b))
def overlap_depth(a, b, ra=None, rb=None):
    ra = ra or cells.piece_rect(a)
    rb = rb or cells.piece_rect(b)
    x0, x1 = max(ra[0], rb[0]), min(ra[1], rb[1])
    z0, z1 = max(ra[2], rb[2]), min(ra[3], rb[3])
    if x1 - x0 <= OVERLAP_TOLERANCE or z1 - z0 <= OVERLAP_TOLERANCE:
        return 0, 0
    if a["y"] >= b["y"] + b["h"] or b["y"] >= a["y"] + a["h"]:
        return 0, 0
    if a["kind"] == "box" and b["kind"] == "box":
        d = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
        return (d, 1) if d > OVERLAP_TOLERANCE else (0, 0)
    nx = max(1, int((x1 - x0) // SAMPLE))
    nz = max(1, int((z1 - z0) // SAMPLE))
    deep, hits = 0, 0
    for ix in range(nx):
        x = x0 + (ix + 0.5) * (x1 - x0) / nx
        for iz in range(nz):
            z = z0 + (iz + 0.5) * (z1 - z0) / nz
            ca, cb = column(a, x, z), column(b, x, z)
            if ca is None or cb is None:
                continue
            d = min(ca[1], cb[1]) - max(ca[0], cb[0])
            if d > OVERLAP_TOLERANCE:
                hits += 1
                deep = max(deep, d)
    return deep, hits
def _coincide(a, b, ra, rb):
    out = []
    if a["y"] + a["h"] == b["y"] + b["h"]:
        out.append("tops")
    if a["y"] == b["y"]:
        out.append("bottoms")
    for i, name in ((0, "-x"), (1, "+x"), (2, "-z"), (3, "+z")):
        if ra[i] == rb[i]:
            out.append(name + " sides")
    return out
def overlaps(pieces, allow_same=False):
    rects = [cells.piece_rect(p) for p in pieces]
    order = sorted((i for i in range(len(pieces))
                    if not (pieces[i].get("decor") and pieces[i].get("pass"))),
                   key=lambda i: rects[i][0])
    out = []
    for n, i in enumerate(order):
        ri = rects[i]
        for j in order[n + 1:]:
            rj = rects[j]
            if rj[0] >= ri[1] - OVERLAP_TOLERANCE:
                break
            if rj[2] >= ri[3] - OVERLAP_TOLERANCE or ri[2] >= rj[3] - OVERLAP_TOLERANCE:
                continue
            a, b = pieces[i], pieces[j]
            if (allow_same and same_solid(a, b)) or concentric(a, b):
                continue
            depth, hits = overlap_depth(a, b, ri, rj)
            if hits:
                lo, hi = min(i, j), max(i, j)
                out.append((lo, hi, depth, _coincide(a, b, ri, rj)))
    out.sort()
    return out
def _on_level_plane(arena, p):
    lvl = _m().LEVELS.get(arena.get("level"), {})
    floor = lvl.get("floor")
    if floor is None:
        return False
    half = lvl.get("half", 0)
    r = cells.piece_rect(p)
    return (p["y"] + p["h"] == floor and r[0] < half and r[1] > -half and r[2] < half
            and r[3] > -half)
def level_plane_faults(arena):
    m = _m()
    lvl = m.LEVELS.get(arena.get("level"), {})
    floor = lvl.get("floor")
    if floor is None:
        return []
    half = lvl.get("half", 0)
    out = []
    for p in arena["pieces"]:
        r = cells.piece_rect(p)
        if (p["y"] + p["h"] == floor and r[0] < half and r[1] > -half and r[2] < half
                and r[3] > -half):
            out.append("%s: its top lies in the level's own floor plane (y %d) - the two "
                       "faces flicker (z-fighting)" % (m.piece_name(p), floor))
    return out
NEAR_GAP = 4
LEVEL_GAP = 10
FACE_AREA_MIN = 1.0
_UNIT_FACES = {}
def _unit_faces(p):
    m = _m()
    if p["kind"] == "rail":
        return m.solid("rail", piece=p)
    if p["kind"] not in _UNIT_FACES:
        _UNIT_FACES[p["kind"]] = m.solid(p["kind"], piece=p)
    return _UNIT_FACES[p["kind"]]
_WORLD_FACES = {}
def world_faces(p):
    key = (p["kind"], p["x"], p["y"], p["z"], p["w"], p["h"], p["d"], p["yaw"])
    got = _WORLD_FACES.get(key)
    if got is None:
        if len(_WORLD_FACES) > 50000:
            _WORLD_FACES.clear()
        got = _WORLD_FACES[key] = _world_faces(p)
    return got
def _world_faces(p):
    import math
    m = _m()
    S = m.slopes
    s, c = math.sin(math.radians(p["yaw"])), math.cos(math.radians(p["yaw"]))
    out = []
    for pts, _ in _unit_faces(p):
        w = []
        for q in pts:
            lx, ly, lz = m.scaled(q, p)
            w.append((p["x"] + lx * c + lz * s, p["y"] + ly, p["z"] - lx * s + lz * c))
        n = S.cross(S.sub(w[1], w[0]), S.sub(w[2], w[0]))
        length = math.sqrt(S.dot(n, n))
        if length < 1e-9:
            continue
        out.append((S.triangles(w), tuple(v / length for v in n)))
    return out
def _area2(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1]
               - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
def _clip_area(P, Q):
    if _area2(P) < 0:
        P = P[::-1]
    if _area2(Q) < 0:
        Q = Q[::-1]
    out = list(P)
    for i in range(len(Q)):
        a, b = Q[i], Q[(i + 1) % len(Q)]
        inp, out = out, []
        if not inp:
            break
        def inside(p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= -1e-9
        def cut(p, q):
            dx, dy = b[0] - a[0], b[1] - a[1]
            den = (q[0] - p[0]) * dy - (q[1] - p[1]) * dx
            if abs(den) < 1e-12:
                return q
            t = ((a[0] - p[0]) * dy - (a[1] - p[1]) * dx) / den
            return (p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1]))
        for j in range(len(inp)):
            cur, prev = inp[j], inp[j - 1]
            if inside(cur):
                if not inside(prev):
                    out.append(cut(prev, cur))
                out.append(cur)
            elif inside(prev):
                out.append(cut(prev, cur))
    return abs(_area2(out)) / 2.0 if len(out) >= 3 else 0.0
def _shared(ta, tb, normal):
    ax = max(range(3), key=lambda k: abs(normal[k]))
    keep = [k for k in range(3) if k != ax]
    area = 0.0
    for t1 in ta:
        P = [(q[keep[0]], q[keep[1]]) for q in t1]
        for t2 in tb:
            area += _clip_area(P, [(q[keep[0]], q[keep[1]]) for q in t2])
    return area
def _flat_rect(tris, normal):
    if max(abs(v) for v in normal) < 1.0 - 1e-9:
        return None
    ax = max(range(3), key=lambda k: abs(normal[k]))
    keep = [k for k in range(3) if k != ax]
    us = set(q[keep[0]] for t in tris for q in t)
    vs = set(q[keep[1]] for t in tris for q in t)
    if len(us) != 2 or len(vs) != 2:
        return None
    u0, u1 = min(us), max(us)
    v0, v1 = min(vs), max(vs)
    area = 0.0
    for t in tris:
        (a0, a1), (b0, b1), (c0, c1) = [(q[keep[0]], q[keep[1]]) for q in t]
        area += abs((b0 - a0) * (c1 - a1) - (c0 - a0) * (b1 - a1)) / 2.0
    if abs(area - (u1 - u0) * (v1 - v0)) > 1e-6 * max(1.0, area):
        return None
    return (u0, u1, v0, v1)
def _bbox(tris):
    out = []
    for t in range(3):
        vals = [q[t] for tri in tris for q in tri]
        out += [min(vals), max(vals)]
    return out
def _boxes_meet(a, b, pad):
    return all(a[2 * t] - pad[t] < b[2 * t + 1] and b[2 * t] < a[2 * t + 1] + pad[t]
               for t in range(3))
def face_pairs(arena, gap=None):
    m = _m()
    gap = NEAR_GAP if gap is None else gap
    faces = []
    ps = arena["pieces"]
    for i, p in enumerate(ps):
        if p.get("tex") == "invisible":
            continue
        if p.get("decor"):
            continue
        try:
            for tris, n in world_faces(p):
                faces.append((i, tris, n))
        except Exception:
            continue
    lvl = m.LEVELS.get(arena.get("level"), {})
    if lvl.get("floor") is not None:
        h, f = lvl["half"], lvl["floor"]
        sq = [(-h, f, -h), (-h, f, h), (h, f, h), (h, f, -h)]
        faces.append((-1, m.slopes.triangles(sq), (0.0, 1.0, 0.0)))
    planes = {}
    for k, (i, tris, n) in enumerate(faces):
        key = tuple(int(round(v * 1000)) for v in n)
        d = sum(n[t] * tris[0][0][t] for t in range(3))
        planes.setdefault(key, []).append((d, k))
    widest = max(gap, LEVEL_GAP - 0.5)
    found = {}
    for key, rows in planes.items():
        rows.sort()
        boxes = {k: _bbox(faces[k][1]) for _, k in rows}
        rects = {k: _flat_rect(faces[k][1], faces[k][2]) for _, k in rows}
        for x, (da, a) in enumerate(rows):
            i, ta, na = faces[a]
            for db, b in rows[x + 1:]:
                if db - da > widest + 1e-6:
                    break
                j, tb, _ = faces[b]
                if i == j or (i >= 0 and j >= 0 and concentric(ps[i], ps[j])):
                    continue
                lim = LEVEL_GAP - 0.5 if -1 in (i, j) else gap
                if db - da > lim + 1e-6:
                    continue
                pad = [abs(na[t]) * lim + 1e-6 for t in range(3)]
                if not _boxes_meet(boxes[a], boxes[b], pad):
                    continue
                ra, rb = rects[a], rects[b]
                if ra is not None and rb is not None:
                    area = (max(0.0, min(ra[1], rb[1]) - max(ra[0], rb[0]))
                            * max(0.0, min(ra[3], rb[3]) - max(ra[2], rb[2])))
                else:
                    area = _shared(ta, tb, na)
                if area > FACE_AREA_MIN:
                    k2 = (min(i, j), max(i, j), round(abs(db - da), 2),
                          tuple(round(v, 3) + 0.0 for v in na))
                    found[k2] = found.get(k2, 0) + area
    return sorted((k[0], k[1], k[2], k[3], int(round(v))) for k, v in found.items())
def _face_name(normal):
    n = tuple(int(round(v)) for v in normal)
    return {(0, 1, 0): "tops", (0, -1, 0): "bottoms", (1, 0, 0): "+x sides",
            (-1, 0, 0): "-x sides", (0, 0, 1): "+z sides", (0, 0, -1): "-z sides"}.get(
        n, "sloped faces")
def face_faults(arena, pairs=None):
    m = _m()
    ps = arena["pieces"]
    out = []
    for i, j, dist, normal, area in (face_pairs(arena) if pairs is None else pairs):
        if i < 0:
            out.append("%s: its %s lie %s over the level's own floor - the two faces "
                       "flicker (z-fighting; keep them %d or more apart)"
                       % (m.piece_name(ps[j]), _face_name(normal),
                          "exactly" if not dist else "only %g" % dist, LEVEL_GAP))
            continue
        same = kit.tex_key(ps[i]) == kit.tex_key(ps[j])
        out.append("%s and %s: %s %s over %d square units%s - drawn twice, they "
                   "flicker (z-fighting)"
                   % (m.piece_name(ps[i]), m.piece_name(ps[j]),
                      "coplanar" if not dist else "%g apart," % dist, _face_name(normal),
                      area, " (one texture twice)" if same else ""))
    return out
def faults(arena, limit=12):
    m = _m()
    out = level_plane_faults(arena)
    ps = arena["pieces"]
    named = set()
    for i, j, depth, faces in overlaps(ps):
        what = ("; coplanar %s flicker (z-fighting)" % ", ".join(faces)) if faces else ""
        out.append("%s overlaps %s by %d%s - solids must never share space"
                   % (m.piece_name(ps[i]), m.piece_name(ps[j]), depth, what))
        named.add((i, j))
    on_plane = set(j for j, p in enumerate(ps) if _on_level_plane(arena, p))
    rest = [fp for fp in face_pairs(arena) if (fp[0], fp[1]) not in named
            and not (fp[0] < 0 and fp[1] in on_plane)]
    out += face_faults(arena, rest)
    if len(out) > limit:
        out = out[:limit] + ["... and %d more overlaps" % (len(out) - limit)]
    return out
def _wedge_line(desc):
    kind, tex, rises, lo, hi, y0, y1 = desc
    axis, _ = cells.rise_axis(rises)
    return axis, lo, hi, y0, y1
def _top(desc, u):
    axis, lo, hi, y0, y1 = _wedge_line(desc)
    return y0 + (y1 - y0) * (u - lo) / float(hi - lo)
def _u_at(desc, y):
    axis, lo, hi, y0, y1 = _wedge_line(desc)
    return lo + (hi - lo) * (y - y0) / float(y1 - y0)
def _span_of(grid, c, axis):
    x0, x1, z0, z1 = grid.column_rect(c)
    return (x0, x1) if axis == "x" else (z0, z1)
def _range(grid, c, desc):
    axis = _wedge_line(desc)[0]
    a, b = _span_of(grid, c, axis)
    ta, tb = _top(desc, a), _top(desc, b)
    return desc[5], min(ta, tb), max(ta, tb)
def _inside_open(v, a, b):
    return a + 0.5 < v < b - 0.5
class Painter:
    def __init__(self, pieces):
        xs, zs = [], []
        for p in pieces:
            r = cells.piece_rect(p)
            xs += [r[0], r[1]]
            zs += [r[2], r[3]]
        self.grid = cells.CellGrid(xs, zs)
        self.atomic = []
        self.notes = []
    def _cut(self, axis, u):
        u = int(round(u))
        g = self.grid
        lines = g.xs if axis == "x" else g.zs
        if cells._n(u) in lines:
            return False
        if axis == "x":
            ng = g.refine([u], [])
        else:
            ng = g.refine([], [u])
        self.grid.__dict__.update(ng.__dict__)
        return True
    def _cuts_box_wedge(self, c, a, b, desc):
        foot, tlo, thi = _range(self.grid, c, desc)
        axis = _wedge_line(desc)[0]
        out = []
        lo, hi = _span_of(self.grid, c, axis)
        for v in (a, b):
            if tlo < v < thi:
                u = _u_at(desc, v)
                if _inside_open(u, min(lo, hi), max(lo, hi)):
                    out.append((axis, u))
        return out
    def _cuts_wedge_wedge(self, c, d1, d2):
        ax1, ax2 = _wedge_line(d1)[0], _wedge_line(d2)[0]
        if ax1 != ax2:
            return None
        lo, hi = _span_of(self.grid, c, ax1)
        out = []
        a1, b1 = _top(d1, lo), _top(d1, hi)
        a2, b2 = _top(d2, lo), _top(d2, hi)
        da, db = a1 - a2, b1 - b2
        if (da > 0.5 and db < -0.5) or (da < -0.5 and db > 0.5):
            out.append((ax1, lo + (hi - lo) * da / (da - db)))
        for d, other in ((d1, d2), (d2, d1)):
            foot = other[5]
            ta, tb = _top(d, lo), _top(d, hi)
            if min(ta, tb) < foot < max(ta, tb):
                u = _u_at(d, foot)
                if _inside_open(u, lo, hi):
                    out.append((ax1, u))
        return out
    def lay(self, p):
        kind = kit.kind(p["kind"]).cells
        if kind == "atomic":
            self.atomic.append(dict(p))
            return
        for _ in range(8):
            if not self._lay_once(p, kind):
                return
        self.notes.append("%s: could not be cut clean against its neighbours"
                          % _m().piece_name(p))
        self._lay_once(p, kind, force=True)
    def _lay_once(self, p, kind, force=False):
        g = self.grid
        x0, x1, z0, z1 = cells.piece_rect(p)
        tag = p.get("tag", "")
        if kind == "box":
            span = (kit.tex_key(p), cells._n(p["y"]), cells._n(p["y"] + p["h"]), tag)
            if not force:
                cuts = []
                for c in g.columns(x0, x1, z0, z1):
                    for desc, _ in g.wedges.get(c, []):
                        cuts += self._cuts_box_wedge(c, span[1], span[2], desc)
                if cuts:
                    for axis, u in cuts:
                        self._cut(axis, u)
                    return True
            for c in list(g.columns(x0, x1, z0, z1)):
                self._box_into(c, span)
            return False
        desc = cells.wedge_descriptor(p)
        if not force:
            cuts = []
            for c in g.columns(x0, x1, z0, z1):
                for (_, a, b, _) in g.boxes.get(c, []):
                    cuts += self._cuts_box_wedge(c, a, b, desc)
                for d2, _ in g.wedges.get(c, []):
                    if d2 != desc:
                        more = self._cuts_wedge_wedge(c, desc, d2)
                        cuts += more or []
            if cuts:
                for axis, u in cuts:
                    self._cut(axis, u)
                return True
        for c in list(g.columns(x0, x1, z0, z1)):
            self._wedge_into(c, desc, tag)
        return False
    def _box_into(self, c, span):
        g = self.grid
        tex, a, b, tag = span
        out = []
        for s in g.boxes.get(c, []):
            if s[2] <= a or s[1] >= b:
                out.append(s)
                continue
            if s[0] == tex:
                a, b = min(a, s[1]), max(b, s[2])
                tag = tag or s[3]
                continue
            if s[1] < a:
                out.append((s[0], s[1], a, s[3]))
            if s[2] > b:
                out.append((s[0], b, s[2], s[3]))
        ws = []
        for desc, wtag in g.wedges.get(c, []):
            foot, tlo, thi = _range(g, c, desc)
            if b <= foot or a >= thi - 0.5:
                ws.append((desc, wtag))
            elif a <= foot and b >= thi - 0.5:
                pass
            elif b <= tlo + 0.5:
                if a < foot:
                    out.append((tex, a, foot, tag))
                tex = None
                ws.append((desc, wtag))
            else:
                if foot < a:
                    out.append((desc[1], foot, a, wtag))
        if tex is not None:
            out.append((tex, a, b, tag))
        out.sort(key=lambda s: (s[1], s[2], str(s[0])))
        if out:
            g.boxes[c] = out
        else:
            g.boxes.pop(c, None)
        if ws:
            g.wedges[c] = ws
        else:
            g.wedges.pop(c, None)
    def _wedge_into(self, c, desc, tag):
        g = self.grid
        foot, tlo, thi = _range(g, c, desc)
        keep_wedge = True
        out = []
        for s in g.boxes.get(c, []):
            tex, a, b, stag = s
            if b <= foot or a >= thi - 0.5:
                out.append(s)
            elif a <= foot and b >= thi - 0.5:
                keep_wedge = False
                out.append(s)
            elif b <= tlo + 0.5:
                if a < foot:
                    out.append((tex, a, foot, stag))
            else:
                if foot < a:
                    out.append((desc[1], foot, a, tag))
                out.append(s)
                keep_wedge = False
        ws = []
        for d2, t2 in g.wedges.get(c, []):
            if d2 == desc:
                continue
            f2, lo2, hi2 = _range(g, c, d2)
            if _wedge_line(d2)[0] != _wedge_line(desc)[0]:
                ws.append((d2, t2))
                continue
            a_lo, a_hi = _span_of(g, c, _wedge_line(desc)[0])
            mid = (a_lo + a_hi) / 2.0
            new_above = _top(desc, mid) >= _top(d2, mid)
            hi_d, lo_d = (desc, d2) if new_above else (d2, desc)
            fh, fl = hi_d[5], lo_d[5]
            lo_top_min = _range(g, c, lo_d)[1]
            lo_top_max = _range(g, c, lo_d)[2]
            if lo_top_max <= fh + 0.5:
                ws.append((d2, t2))
                continue
            if fh > fl and lo_top_min >= fh - 0.5:
                out.append((lo_d[1], fl, fh, t2 if lo_d is d2 else tag))
            if new_above:
                continue
            keep_wedge = False
            ws.append((d2, t2))
        if keep_wedge:
            ws.append((desc, tag))
        out.sort(key=lambda s: (s[1], s[2], str(s[0])))
        if out:
            g.boxes[c] = out
        else:
            g.boxes.pop(c, None)
        if ws:
            g.wedges[c] = ws
        else:
            g.wedges.pop(c, None)
    def _place_atomics(self):
        m = _m()
        kept = []
        for p in self.atomic:
            x0, x1, z0, z1 = cells.piece_rect(p)
            refined = self.grid.refine([x0, x1], [z0, z1])
            self.grid.__dict__.update(refined.__dict__)
            g = self.grid
            foot, top = p["y"], p["y"] + p["h"]
            under, over, bad = [], [], False
            for c in g.columns(x0, x1, z0, z1):
                for (_, a, b, _) in g.boxes.get(c, []):
                    if b - OVERLAP_TOLERANCE <= foot or a + OVERLAP_TOLERANCE >= top:
                        if foot < b <= foot + OVERLAP_TOLERANCE:
                            under.append(b)
                        elif top - OVERLAP_TOLERANCE <= a < top:
                            over.append(a)
                        continue
                    if p["kind"] in FULL_RECT:
                        continue
                    if b <= (foot + top) / 2.0:
                        under.append(b)
                    elif a >= (foot + top) / 2.0:
                        over.append(a)
                    else:
                        bad = True
                for desc, _ in g.wedges.get(c, []):
                    f, lo, hi = _range(g, c, desc)
                    if hi - OVERLAP_TOLERANCE > foot and f + OVERLAP_TOLERANCE < top:
                        bad = True
            if not bad:
                for q in kept:
                    if overlap_depth(p, q)[1]:
                        bad = True
                        break
            if bad:
                self.notes.append("dropped %s: it shared space with a slope or another "
                                  "whole piece" % m.piece_name(p))
                continue
            if p["kind"] in FULL_RECT:
                g.carve(x0, x1, z0, z1, foot, top)
            else:
                nfoot = max(under) if under else foot
                ntop = min(over) if over else top
                if ntop - nfoot < MIN_PART:
                    self.notes.append("dropped %s: nothing left of it between the floor "
                                      "and what is above" % m.piece_name(p))
                    continue
                if (nfoot, ntop) != (foot, top):
                    p = dict(p, y=cells._n(nfoot), h=cells._n(ntop - nfoot))
            kept.append(p)
        return kept
    def pieces(self):
        atomics = self._place_atomics()
        out = self.grid.to_pieces() + atomics
        if overlaps(out):
            out = self.grid.to_pieces(disjoint=True) + atomics
        return out
def resolve(pieces):
    if any(p.get("decor") for p in pieces):
        rest = [p for p in pieces if not p.get("decor")]
        out, notes = resolve(rest)
        if out is rest:
            return pieces, notes
        return out + [p for p in pieces if p.get("decor")], notes
    found = overlaps(pieces)
    flat = [(i, j) for i, j, _, _, _ in face_pairs({"pieces": pieces}) if i >= 0]
    if not found and not flat:
        return pieces, []
    involved = set(i for i, _, _, _ in found) | set(j for _, j, _, _ in found)
    involved |= set(i for i, _ in flat) | set(j for _, j in flat)
    m = _m()
    for _ in range(6):
        order = sorted(involved, key=lambda i: priority(pieces[i], i))
        group = [pieces[i] for i in order]
        painter = Painter(group)
        for p in group:
            painter.lay(p)
        painted = painter.pieces()
        for p in painted:
            p.pop("model", None)
            p["model"] = m.model_name(p)
        rest = [i for i in range(len(pieces)) if i not in involved]
        out = [pieces[i] for i in rest] + painted
        more = set()
        for i, j, _, _ in overlaps(out):
            for k in (i, j):
                if k < len(rest):
                    more.add(rest[k])
        if not more:
            break
        involved |= more
    return out, painter.notes
def priority(p, index):
    x0, x1, z0, z1 = cells.piece_rect(p)
    return (p["y"] + p["h"], -(x1 - x0) * (z1 - z0), str(kit.tex_key(p)), index)
