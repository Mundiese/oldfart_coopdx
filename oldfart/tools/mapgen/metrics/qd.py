import json
import math
import statistics
AXES = {
    "verticality": (0.0, 1.0),
    "openness": (0.0, 1.0),
    "path_redundancy": (0.0, 1.0),
    "engagement": (0.0, 1.0),
    "centre_dominance": (-1.0, 1.0),
    "size": (0.0, 1.0),
    "density": (0.0, 1.0),
    "pace": (0.0, 1.0),
    "route_choice": (0.0, 1.0),
    "move_richness": (0.0, 1.0),
}
DEFAULT_AXES = ("verticality", "openness")
def _clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))
def descriptors(result):
    m = result["metrics"]
    w = result.get("world")
    out = {}
    tops = []
    if w is not None:
        tops = [w.nodes[i][2] for i in w.columns.values()]
    if tops:
        lo = min(tops)
        sd = statistics.pstdev(tops) if len(tops) > 1 else 0.0
        high = sum(1 for h in tops if h >= lo + 300) / float(len(tops))
        out["verticality"] = round(_clamp(0.5 * sd / 400.0 + 0.5 * high), 4)
    else:
        out["verticality"] = round(_clamp((m.get("layers") or 1) / 4.0), 4)
    if m.get("openness") is not None:
        out["openness"] = round(_clamp(m["openness"]), 4)
    else:
        cover = m.get("cover_within_300")
        out["openness"] = round(_clamp(1.0 - (cover if cover is not None else 0.5)), 4)
    rooms = max(1, m.get("rooms") or 1)
    loops = m.get("loops") or 0
    lanes = m.get("lanes_between_bases")
    red = loops / float(rooms + loops)
    if lanes:
        red = 0.5 * red + 0.5 * min(1.0, lanes / 4.0)
    out["path_redundancy"] = round(_clamp(red), 4)
    p95 = m.get("sightline_p95")
    out["engagement"] = round(_clamp(p95 / 6000.0), 4) if p95 is not None else None
    plateaus = m.get("plateaus") or [0]
    if w is not None and result.get("extra", {}).get("centre") is not None:
        ch = w.nodes[result["extra"]["centre"]][2]
        span = max(plateaus) - min(plateaus)
        main = m.get("main_plane", 0)
        out["centre_dominance"] = round(_clamp((ch - main) / float(span), -1.0, 1.0), 4) if span else 0.0
    else:
        out["centre_dominance"] = 0.0
    fp = m.get("footprint") or [0, 0]
    out["size"] = round(_clamp(max(fp) / 16000.0), 4)
    cov = m.get("cover_within_300")
    out["density"] = round(_clamp(cov), 4) if cov is not None else None
    stc = m.get("spawn_to_centre_s")
    if stc:
        out["pace"] = round(_clamp(1.0 - (sum(stc) / 2.0 - 2.0) / 10.0), 4)
    else:
        out["pace"] = None
    lf1 = m.get("lf1_viable_routes")
    out["route_choice"] = round(_clamp((lf1 - 1) / 3.0), 4) if lf1 is not None else None
    vm1 = m.get("vm1_per_unit")
    out["move_richness"] = round(_clamp(vm1 / 4.0), 4) if vm1 is not None else None
    return out
def symmetry_of(arena, tol=1.0):
    by_pieces = _symmetry_of_pieces(arena, tol)
    if by_pieces == "turn4":
        return by_pieces
    by_solid = _symmetry_of_solid(arena)
    return by_solid if by_solid != "none" else by_pieces
CORNER_KINDS_Q = ("prism", "outer", "inner", "outerstairs", "innerstairs")
CORNER_VEC = {0: (-1, -1), 90: (-1, 1), 180: (1, 1), 270: (1, -1)}
_RECT_T = {
    "turn4": lambda r: (r[2], r[3], -r[1], -r[0]),
    "turn2": lambda r: (-r[1], -r[0], -r[3], -r[2]),
    "mirror_z": lambda r: (r[0], r[1], -r[3], -r[2]),
    "mirror_x": lambda r: (-r[1], -r[0], r[2], r[3]),
}
_VEC_T = {
    "turn4": lambda v: (v[1], -v[0]),
    "turn2": lambda v: (-v[0], -v[1]),
    "mirror_z": lambda v: (v[0], -v[1]),
    "mirror_x": lambda v: (-v[0], v[1]),
}
def _symmetry_of_solid(arena):
    from .. import cells, v1
    m = v1.arenas_module()
    plain, whole = [], []
    for p in arena["pieces"]:
        q = {k: v for k, v in p.items() if not k.startswith("tex_") and k != "model"}
        q["tex"] = "x"
        if p["kind"] in ("box", "ramp", "stairs"):
            plain.append(q)
        else:
            whole.append(q)
    def atom(p, t=None):
        x0, x1, z0, z1, up = m.footprint(p)
        r = (x0, x1, z0, z1)
        if p["kind"] in CORNER_KINDS_Q:
            v = CORNER_VEC.get(p["yaw"] % 360, (0, 0))
        elif p["kind"] in ("rail", "arch"):
            v = (1, 0) if (x1 - x0) >= (z1 - z0) else (0, 1)
        else:
            v = (0, 0)
        if t is not None:
            r = _RECT_T[t](r)
            v = _VEC_T[t](v)
        if p["kind"] in ("rail", "arch"):
            v = (abs(v[0]), abs(v[1]))
        return (p["kind"], tuple(round(c, 1) for c in r), round(p["y"], 1), round(p["h"], 1), v)
    def solid(ga, xs, zs):
        g = ga.refine(xs, zs)
        out = {}
        for c in set(g.boxes) | set(g.wedges):
            spans = [(a, b) for _, a, b, _ in g.boxes.get(c, [])]
            slopes_ = []
            x0, x1, z0, z1 = g.column_rect(c)
            for d, _ in g.wedges.get(c, []):
                kind, _, rises, lo, hi, y0, y1 = d
                u0, u1 = (x0, x1) if rises[1] == "x" else (z0, z1)
                ta = y0 + (y1 - y0) * (u0 - lo) / float(hi - lo)
                tb = y0 + (y1 - y0) * (u1 - lo) / float(hi - lo)
                spans.append((y0, min(ta, tb)))
                slopes_.append((kind, rises, round(ta, 1), round(tb, 1)))
            spans.sort()
            merged = []
            for a, b in spans:
                if merged and a <= merged[-1][1]:
                    merged[-1] = (merged[-1][0], max(merged[-1][1], b))
                else:
                    merged.append((a, b))
            out[g.column_rect(c)] = (tuple(merged), tuple(sorted(slopes_)))
        return out
    mir_x = m.mirrored_x
    try:
        ga = cells.CellGrid.from_pieces(plain) if plain else None
        atoms = sorted(atom(p) for p in whole)
        for name, fn in (("turn4", lambda p: m.turned(p, 1)), ("turn2", lambda p: m.turned(p, 2)),
                         ("mirror_z", m.mirrored_z), ("mirror_x", mir_x)):
            if sorted(atom(p, name) for p in whole) != atoms:
                continue
            if ga is None:
                return name
            gb = cells.CellGrid.from_pieces([fn(p) for p in plain])
            xs = sorted(set(ga.xs) | set(gb.xs))
            zs = sorted(set(ga.zs) | set(gb.zs))
            if solid(ga, xs, zs) == solid(gb, xs, zs):
                return name
    except (ValueError, KeyError):
        return "none"
    return "none"
def _symmetry_of_pieces(arena, tol=1.0):
    from .world import footprint
    rects = []
    for p in arena["pieces"]:
        x0, x1, z0, z1, up = footprint(p)
        rects.append((p["kind"], x0, x1, z0, z1, p["y"], p["h"], up))
    def canon(r):
        k, x0, x1, z0, z1, y, h, up = r
        if k in ("box", "pillar"):
            up = (0, 0)
        elif k in ("rail", "arch"):
            up = (abs(up[0]), abs(up[1]))
        return (k, round(x0 / tol), round(x1 / tol), round(z0 / tol), round(z1 / tol),
                round(y / tol), round(h / tol), up)
    base = sorted(canon(r) for r in rects)
    def turned(r):
        k, x0, x1, z0, z1, y, h, up = r
        return (k, z0, z1, -x1, -x0, y, h, (up[1], -up[0]))
    def mir_x(r):
        k, x0, x1, z0, z1, y, h, up = r
        return (k, -x1, -x0, z0, z1, y, h, (-up[0], up[1]))
    def mir_z(r):
        k, x0, x1, z0, z1, y, h, up = r
        return (k, x0, x1, -z1, -z0, y, h, (up[0], -up[1]))
    t1 = [turned(r) for r in rects]
    if sorted(canon(r) for r in t1) == base:
        return "turn4"
    if sorted(canon(turned(r)) for r in t1) == base:
        return "turn2"
    if sorted(canon(mir_z(r)) for r in rects) == base:
        return "mirror_z"
    if sorted(canon(mir_x(r)) for r in rects) == base:
        return "mirror_x"
    return "none"
def bin_of(value, axis, bins, ranges=None):
    lo, hi = (ranges or AXES).get(axis, (0.0, 1.0))
    if value is None:
        return None
    t = (value - lo) / float(hi - lo) if hi > lo else 0.0
    return max(0, min(bins - 1, int(t * bins)))
def distance(a, b, axes):
    s = 0.0
    for ax in axes:
        lo, hi = AXES.get(ax, (0.0, 1.0))
        va, vb = a.get(ax), b.get(ax)
        if va is None or vb is None:
            continue
        s += ((va - vb) / float(hi - lo)) ** 2
    return math.sqrt(s)
class Entry(object):
    __slots__ = ("genome", "fitness", "desc", "valid", "infeasibility", "order", "meta")
    def __init__(self, genome, fitness, desc, valid=True, infeasibility=0.0, order=0, meta=None):
        self.genome = genome
        self.fitness = fitness
        self.desc = dict(desc)
        self.valid = valid
        self.infeasibility = infeasibility
        self.order = order
        self.meta = meta or {}
    def as_dict(self):
        return {"genome": self.genome, "fitness": self.fitness, "desc": self.desc,
                "valid": self.valid, "infeasibility": self.infeasibility,
                "order": self.order, "meta": self.meta}
class MapElites(object):
    def __init__(self, axes=DEFAULT_AXES, bins=5, capacity=1, ranges=None):
        self.axes = tuple(axes)
        self.bins = bins
        self.capacity = capacity
        self.ranges = dict(AXES)
        if ranges:
            self.ranges.update(ranges)
        self.cells = {}
        self._all = []
        self._order = 0
    def cell_of(self, desc):
        idx = []
        for ax in self.axes:
            b = bin_of(desc.get(ax), ax, self.bins, self.ranges)
            if b is None:
                return None
            idx.append(b)
        return tuple(idx)
    def add(self, genome, fitness, desc, valid=True, infeasibility=0.0, meta=None):
        e = Entry(genome, fitness, desc, valid, infeasibility, self._order, meta)
        self._order += 1
        self._all.append(e)
        return self._place(e)
    def _place(self, e):
        cell = self.cell_of(e.desc)
        if cell is None:
            return None, False
        slot = self.cells.setdefault(cell, {"valid": [], "invalid": []})
        pop = slot["valid" if e.valid else "invalid"]
        pop.append(e)
        if e.valid:
            pop.sort(key=lambda x: (-x.fitness, x.order))
        else:
            pop.sort(key=lambda x: (x.infeasibility, -x.fitness, x.order))
        accepted = e in pop[:self.capacity]
        del pop[self.capacity:]
        return cell, accepted
    def set_axes(self, axes, bins=None):
        self.axes = tuple(axes)
        if bins:
            self.bins = bins
        self.cells = {}
        for e in self._all:
            self._place(e)
    def elites(self, valid=True):
        out = []
        for cell in sorted(self.cells):
            pop = self.cells[cell]["valid" if valid else "invalid"]
            if pop:
                out.append((cell, pop[0]))
        return out
    def elite(self, cell, valid=True):
        slot = self.cells.get(tuple(cell))
        if not slot:
            return None
        pop = slot["valid" if valid else "invalid"]
        return pop[0] if pop else None
    def coverage(self):
        return len(self.elites(True)) / float(self.bins ** len(self.axes))
    def qd_score(self):
        return sum(e.fitness for _, e in self.elites(True))
    def best(self):
        el = self.elites(True)
        if not el:
            return None
        return min((e for _, e in el), key=lambda e: (-e.fitness, e.order))
    def empty_cells(self):
        out = []
        def walk(prefix):
            if len(prefix) == len(self.axes):
                cell = tuple(prefix)
                if not self.elite(cell):
                    out.append(cell)
                return
            for b in range(self.bins):
                walk(prefix + [b])
        walk([])
        return out
    def sample_parent(self, rng, invalid_share=0.2):
        valid = [e for _, e in self.elites(True)]
        invalid = [e for _, e in self.elites(False)]
        if invalid and (not valid or rng.random() < invalid_share):
            return invalid[rng.randrange(len(invalid))]
        if valid:
            return valid[rng.randrange(len(valid))]
        return None
    def grid(self, valid=True):
        if len(self.axes) != 2:
            raise ValueError("grid() needs two axes")
        rows = []
        for j in range(self.bins):
            row = []
            for i in range(self.bins):
                e = self.elite((i, j), valid)
                row.append(None if e is None else e.fitness)
            rows.append(row)
        return rows
    def to_dict(self):
        return {"axes": list(self.axes), "bins": self.bins, "capacity": self.capacity,
                "entries": [e.as_dict() for e in self._all]}
    @classmethod
    def from_dict(cls, data):
        a = cls(data["axes"], data["bins"], data.get("capacity", 1))
        for d in data["entries"]:
            a.add(d["genome"], d["fitness"], d["desc"], d["valid"], d["infeasibility"], d.get("meta"))
        return a
    def dumps(self):
        return json.dumps(self.to_dict(), sort_keys=True)
def pick_diverse(entries, k=5, floor=0.8, axes=DEFAULT_AXES, avoid=(), echo=0.05):
    def fit(e):
        return e.fitness if isinstance(e, Entry) else e["fitness"]
    def desc(e):
        return e.desc if isinstance(e, Entry) else e["desc"]
    pool = [e for e in entries if fit(e) is not None]
    if not pool:
        return []
    pool = sorted(enumerate(pool), key=lambda t: (-fit(t[1]), t[0]))
    best = pool[0][1]
    picked = [best]
    cand = [e for _, e in pool[1:] if fit(e) >= floor * fit(best)]
    cand = [e for e in cand if all(distance(desc(e), a, axes) > echo for a in avoid)]
    while cand and len(picked) < k + 1:
        scored = []
        for n, e in enumerate(cand):
            d = min(distance(desc(e), desc(p), axes) for p in picked)
            scored.append((d, fit(e), -n, e))
        scored.sort(key=lambda t: (t[0], t[1], t[2]), reverse=True)
        d, _, _, e = scored[0]
        if d <= echo:
            break
        picked.append(e)
        cand.remove(e)
    return picked
def novelty(desc, others, axes=DEFAULT_AXES):
    if not others:
        return None
    return min(distance(desc, o, axes) for o in others)
