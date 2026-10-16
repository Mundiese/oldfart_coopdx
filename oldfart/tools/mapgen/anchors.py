import itertools
import math
from .rng import stream
G_COARSE, G_FINE = 11, 21
SOLID = {"tower", "pit", "crown", "plaza", "hill", "base", "landmark", "perch", "vantage",
         "pillar", "arch", "wall", "tunnel", "nook", "loop", "goal", "start_line", "flag",
         "point", "bridge"}
IMPLICIT = ("centre", "middle", "bases", "base", "corners", "edge", "ring", "ground")
COMPASS_VEC = {"n": (0, -1), "ne": (1, -1), "e": (1, 0), "se": (1, 1), "s": (0, 1),
               "sw": (-1, 1), "w": (-1, 0), "nw": (-1, -1), "c": (0, 0)}
COMPASS_NAMES = {"n": "north", "ne": "north-east", "e": "east", "se": "south-east",
                 "s": "south", "sw": "south-west", "w": "west", "nw": "north-west",
                 "c": "centre"}
FAMILY_ACROSS = {"shooter": 8000, "objective": 8000, "knockoff": 4500, "race": 30000,
                 "hide": 9000, "party": 2200, "course": 8000}
SIZE_FACTOR = {"tiny": 0.6, "small": 0.8, "medium": 1.0, "large": 1.25, "huge": 1.5,
               "gigantic": 3.0}
NODE_CAP = 60000
class Refused(ValueError):
    def __init__(self, names, why):
        self.names = list(names)
        self.why = list(why)
        ValueError.__init__(self, "refused: %s cannot all hold - %s (the smallest conflicting "
                            "set; drop or change one)" % (" + ".join(self.names),
                                                          "; ".join(self.why)))
def compass_of(u, v):
    if abs(u) < 0.2 and abs(v) < 0.2:
        return "c"
    best = None
    for name, (cu, cv) in COMPASS_VEC.items():
        if name == "c":
            continue
        n = math.hypot(cu, cv)
        d = (u * cu + v * cv) / n / math.hypot(u, v)
        if best is None or d > best[0]:
            best = (d, name)
    return best[1]
def family_across(family, players):
    try:
        import importlib
        mod = importlib.import_module("mapgen.families.%s" % family)
        fn = getattr(mod, "family_across", None)
        if fn is not None:
            return float(fn(players))
    except Exception:
        pass
    base = FAMILY_ACROSS.get(family, 8000)
    return base * (0.45 + 0.55 * players / 16.0) if family != "party" else \
        math.sqrt(max(2, players) * 300000)
def across_of(raw):
    fam = raw.get("family") or "shooter"
    try:
        from .brief import FAMILY_ALIASES
        fam = FAMILY_ALIASES.get(fam, fam)
    except Exception:
        pass
    players = raw.get("players") if isinstance(raw.get("players"), int) else 16
    base = family_across(fam, players)
    size = raw.get("size", "medium")
    if isinstance(size, str):
        return base * SIZE_FACTOR.get(size, 1.0)
    if isinstance(size, dict):
        if isinstance(size.get("across"), (int, float)):
            return float(size["across"])
        if isinstance(size.get("across_s"), (int, float)):
            return (float(size["across_s"]) - 0.6) * 960.0
    return base
class Frame:
    def __init__(self, G, half, symmetry, mirror_axis="z"):
        self.G = G
        self.c = (G - 1) // 2
        self.half = half
        self.symmetry = symmetry
        self.axis = mirror_axis
        self.slots = [(i, j) for j in range(G) for i in range(G)]
    def uv(self, slot):
        i, j = slot
        return ((i - self.c) / float(self.c), (j - self.c) / float(self.c))
    def world(self, slot):
        u, v = self.uv(slot)
        return (int(round(u * self.half * 0.9 / 200.0)) * 200,
                int(round(v * self.half * 0.9 / 200.0)) * 200)
    def slot_of_world(self, x, z):
        i = int(round(x / (self.half * 0.9) * self.c + self.c))
        j = int(round(z / (self.half * 0.9) * self.c + self.c))
        return (min(self.G - 1, max(0, i)), min(self.G - 1, max(0, j)))
    def dist_units(self, a, b):
        (ua, va), (ub, vb) = self.uv(a), self.uv(b)
        return math.hypot(ua - ub, va - vb) * self.half * 0.9
    def images(self, slot):
        i, j = slot
        c2 = 2 * self.c
        s = self.symmetry
        if s in ("turn4", "turn8"):
            out = [(i, j), (c2 - j, i), (c2 - i, c2 - j), (j, c2 - i)]
        elif s == "turn2":
            out = [(i, j), (c2 - i, c2 - j)]
        elif s == "mirror":
            out = [(i, j), (i, c2 - j)] if self.axis == "z" else [(i, j), (c2 - i, j)]
        else:
            out = [(i, j)]
        seen = []
        for o in out:
            if o not in seen:
                seen.append(o)
        return seen
    def orbit_sizes(self):
        if self.symmetry in ("turn4", "turn8"):
            return (4, 1)
        if self.symmetry in ("turn2", "mirror"):
            return (2, 1)
        return (1,)
def _sector(u, v, angle_deg, width=24.0):
    if abs(u) < 1e-9 and abs(v) < 1e-9:
        return False
    a = math.degrees(math.atan2(u, -v)) % 360
    d = abs((a - angle_deg + 180) % 360 - 180)
    return d <= width
COMPASS_ANGLE = {"n": 0, "ne": 45, "e": 90, "se": 135, "s": 180, "sw": 225, "w": 270, "nw": 315}
RADIUS = {"near": (0.2, 0.6), "far": (0.55, 1.01), "edge": (0.7, 1.01), None: (0.35, 1.01)}
def position(where, frame, notes):
    r_lo, r_hi = RADIUS.get(where.get("radius"), RADIUS[None])
    def rad(u, v):
        return max(abs(u), abs(v))
    if "cell" in where:
        ci, cj = where["cell"]
        x = -frame.half + 200 * ci + 100
        z = -frame.half + 200 * cj + 100
        target = frame.slot_of_world(x, z)
        return (lambda s: s == target), frame.uv(target), "cell %d,%d (%d, %d)" % (ci, cj, x, z)
    if "x" in where and "z" in where:
        target = frame.slot_of_world(float(where["x"]), float(where["z"]))
        return (lambda s: s == target), frame.uv(target), "x %d z %d" % (where["x"], where["z"])
    comp = where.get("compass")
    if comp in ("corners", "corner"):
        return (lambda s: rad(*frame.uv(s)) >= 0.5 and any(
            _sector(*frame.uv(s), a, 22.5) for a in (45, 135, 225, 315))), None, "the corners"
    if comp in ("edges", "edge", "ring") or where.get("edge") or where.get("relation") == "edge":
        return (lambda s: rad(*frame.uv(s)) >= 0.7), None, "the edge"
    if comp == "c" or where.get("relation") == "middle":
        return (lambda s: rad(*frame.uv(s)) <= 0.21), (0.0, 0.0), "the centre"
    if comp in COMPASS_ANGLE:
        ang = COMPASS_ANGLE[comp]
        lo = max(r_lo, 0.45) if where.get("radius") is None else r_lo
        cu, cv = COMPASS_VEC[comp]
        n = math.hypot(cu, cv)
        ideal_r = 0.75 if where.get("radius") != "near" else 0.4
        return (lambda s: lo <= rad(*frame.uv(s)) < r_hi and _sector(*frame.uv(s), ang, 30)), \
            (cu / n * ideal_r * (1.41 if comp in ("ne", "se", "sw", "nw") else 1),
             cv / n * ideal_r * (1.41 if comp in ("ne", "se", "sw", "nw") else 1)), \
            COMPASS_NAMES[comp]
    if "clock" in where:
        h = int(where["clock"]) % 12
        ang = h * 30
        rr = {"near": 0.35, "far": 0.75}.get(where.get("radius"), 0.6)
        ideal = (math.sin(math.radians(ang)) * rr, -math.cos(math.radians(ang)) * rr)
        return (lambda s: rad(*frame.uv(s)) >= 0.25 and _sector(*frame.uv(s), ang, 18)), \
            ideal, "%d o'clock" % (h or 12)
    if where.get("aligned"):
        ax = where["aligned"]
        long_z = True
        if ax in ("x", "short_axis", "east_west"):
            long_z = False
        return (lambda s: (frame.uv(s)[0] == 0) if long_z else (frame.uv(s)[1] == 0)), \
            (0.0, 0.0), "in a row along the %s axis" % ("north-south" if long_z else "east-west")
    return (lambda s: True), None, "anywhere"
class Var:
    def __init__(self, aid, what, k, orbit, solid, height=None):
        self.aid = aid
        self.what = what
        self.k = k
        self.orbit = orbit
        self.solid = solid
        self.height = height
        self.domain = []
        self.ideal = None
        self.exact = None
        self.pin = None
    @property
    def name(self):
        return "%s#%d" % (self.aid, self.k)
def _decompose(n, sizes, fixed_ok):
    big = sizes[0]
    if big == 1:
        return [1] * n
    for nbig in range(n // big, -1, -1):
        rest = n - nbig * big
        if rest == 0 or (fixed_ok and rest <= fixed_ok):
            return [big] * nbig + [1] * rest
    return None
class Problem:
    def __init__(self, raw, G=G_COARSE, drop=(), mirror_axis="z"):
        self.raw = raw
        self.drop = set(drop)
        family = raw.get("family") or "shooter"
        self.across = across_of({k: v for k, v in raw.items() if not (
            k == "size" and "size" in self.drop) and not (k == "players" and "players" in
                                                          self.drop)})
        self.symmetry_asked = raw.get("symmetry") not in (None, "auto")
        sym = raw.get("symmetry") or "auto"
        if "symmetry" in self.drop:
            sym = "none"
        elif sym == "auto":
            sym = self._default_symmetry(raw, family)
        self.frame = Frame(G, self.across / 2.0, sym, mirror_axis)
        self.notes = []
        self.vars = []
        self.by_anchor = {}
        self.anchors = {}
        self.relations = []
        self.spacing = {}
        self.unsolvable = []
        self.groups = {}
        self.post = []
        self.locks = [] if "locks" in self.drop else list(raw.get("locks") or [])
        self._lock_applies = False
        self.pairs = {}
        self._build()
    @staticmethod
    def _default_symmetry(raw, family):
        from .brief import FAMILY_DEFAULTS
        if raw.get("sides") in ("2", 2) and family == "shooter":
            return "mirror"
        return FAMILY_DEFAULTS.get(family, {}).get("symmetry", "turn4")
    def _locked(self, slot):
        u, v = self.frame.uv(slot)
        x, z = u * self.frame.half, v * self.frame.half
        for lock in self.locks:
            if not isinstance(lock, dict) or not self._lock_applies:
                continue
            if "rows" in lock:
                r0, r1 = lock["rows"]
                row = int((z + self.frame.half) // 200)
                if r0 <= row <= r1:
                    return True
            if "rect" in lock:
                x0, x1, z0, z1 = lock["rect"]
                if x0 <= x <= x1 and z0 <= z <= z1:
                    return True
            if "compass" in lock:
                pred, _, _ = position({"compass": lock["compass"]}, self.frame, [])
                if pred(slot):
                    return True
        return False
    def _build(self):
        frame = self.frame
        anchors = [a for a in (self.raw.get("anchors") or []) if isinstance(a, dict)]
        for n, a in enumerate(anchors):
            aid = a.get("id") or "%s%d" % (a.get("what", "anchor"), n + 1)
            if aid in self.drop:
                continue
            what = str(a.get("what", "")).lower()
            self._lock_applies = bool(a.get("added"))
            where = a.get("where") or {"anywhere": True}
            if isinstance(where, str):
                where = {"compass": where}
            where = _norm_where(where)
            self.anchors[aid] = dict(a, id=aid, where=where)
            label = _describe(a, where)
            self.groups[aid] = label
            if "on" in where or (where.get("relation") == "on" and isinstance(where.get("of"),
                                                                                str)
                                 and where["of"] in ("ramps", "ramp", "stairs", "bridges",
                                                     "bridge", "towers", "perches")
                                 and not any(x.get("id") == where["of"] for x in anchors)) \
                    or (what == "spawns" and a.get("count") is None):
                self.post.append(aid)
                continue
            count = a.get("count")
            once = bool(a.get("once"))
            sizes = frame.orbit_sizes()
            if count is None:
                orbits = ["single" if once else None]
            else:
                if not isinstance(count, int) or count < 1:
                    self.unsolvable.append((aid, "%s: count %r" % (aid, count)))
                    continue
                if once or frame.symmetry == "none":
                    orbits = ["single"] * count
                else:
                    fixed = 1 if frame.symmetry in ("turn4", "turn8", "turn2") else count
                    orbits = _decompose(count, sizes, fixed)
                    if orbits is None:
                        if self.symmetry_asked:
                            self.unsolvable.append(
                                ("symmetry", "%d %s cannot be laid out %s (orbits of %s)"
                                 % (count, what, frame.symmetry, "/".join(map(str, sizes)))))
                            self.unsolvable.append((aid, "%d of %s" % (count, what)))
                            orbits = []
                        else:
                            self.notes.append("%s: %d %s do not divide into %s - laid out "
                                              "without symmetry" % (aid, count, what,
                                                                    frame.symmetry))
                            orbits = ["single"] * count
            pred, ideal, plabel = position(where, frame, self.notes)
            vs = []
            for k, orb in enumerate(orbits):
                v = Var(aid, what, k, orb, what in SOLID, a.get("height"))
                v.ideal = ideal
                if "cell" in where:
                    v.exact = (-frame.half + 200 * where["cell"][0] + 100,
                               -frame.half + 200 * where["cell"][1] + 100)
                elif "x" in where and "z" in where:
                    v.exact = (float(where["x"]), float(where["z"]))
                if isinstance(a.get("pin"), list) and len(a["pin"]) == 2 and k == 0:
                    v.pin = frame.slot_of_world(float(a["pin"][0]), float(a["pin"][1]))
                dom = []
                for s in frame.slots:
                    if not pred(s):
                        continue
                    if self._locked(s):
                        continue
                    imgs = frame.images(s)
                    if isinstance(orb, int) and len(imgs) != orb:
                        continue
                    dom.append(s)
                if orb == "single" and frame.symmetry != "none" and once \
                        and what not in ("world_spawn",):
                    fixed = [s for s in dom if len(frame.images(s)) == 1]
                    partner = None
                    if not fixed and self.symmetry_asked and \
                            frame.symmetry in ("turn2", "mirror"):
                        partner = self._partner(aid, what, anchors, dom)
                    if fixed and self.symmetry_asked:
                        dom = fixed
                    elif partner is not None:
                        other_id, other_pred = partner
                        dom = [s for s in dom if any(other_pred(i) for i in frame.images(s)[1:])]
                        self.pairs[aid] = other_id
                    elif self.symmetry_asked and not fixed:
                        self.unsolvable.append(("symmetry", "a single %s at %s breaks the %s "
                                                "symmetry the brief asks for"
                                                % (what, plabel, frame.symmetry)))
                        self.unsolvable.append((aid, "one %s at %s" % (what, plabel)))
                        dom = []
                    elif not fixed:
                        self.notes.append("%s: a single %s at %s makes the map asymmetric"
                                          % (aid, what, plabel))
                v.domain = dom
                vs.append(v)
            if orbits and not any(v.domain for v in vs) and \
                    not any(g == aid for g, _ in self.unsolvable):
                self.unsolvable.append((aid, "no place on the map is %s%s" % (
                    plabel, " outside the locked regions" if self.locks else "")))
            self.vars += vs
            self.by_anchor[aid] = vs
            if isinstance(a.get("spacing"), (int, float)):
                self.spacing[aid] = float(a["spacing"])
            rel = where.get("relation")
            if rel and rel not in ("middle", "edge"):
                ofs = where.get("of")
                ofs = ofs if isinstance(ofs, list) else [ofs]
                for v in vs:
                    self.relations.append((v, rel, [o for o in ofs if o is not None], a))
        players = self.raw.get("players") if isinstance(self.raw.get("players"), int) else 16
        for aid, a in self.anchors.items():
            if a.get("what") == "spawns" and isinstance(a.get("count"), int) \
                    and "players" not in self.drop:
                total = sum(x.get("count", 0) for x in self.anchors.values()
                            if x.get("what") == "spawns" and isinstance(x.get("count"), int))
                if total > 28:
                    self.unsolvable.append(("players", "%d spawns asked; the wire carries 28 "
                                            "survey points" % total))
                    self.unsolvable.append((aid, "%d spawns" % a["count"]))
        self.groups.setdefault("size", "%d across" % self.across)
        self.groups.setdefault("symmetry", self.frame.symmetry)
        self.groups.setdefault("players", "%s players" % players)
        if self.locks:
            self.groups.setdefault("locks", "%d locked region(s)" % len(self.locks))
    def _partner(self, aid, what, anchors, dom):
        f = self.frame
        for n, b in enumerate(anchors):
            bid = b.get("id") or "%s%d" % (b.get("what", "anchor"), n + 1)
            if bid == aid or bid in self.drop or not b.get("once") \
                    or str(b.get("what", "")).lower() != what:
                continue
            if self.pairs.get(bid, aid) != aid or bid in self.pairs.values():
                continue
            where = b.get("where") or {"anywhere": True}
            if isinstance(where, str):
                where = {"compass": where}
            where = _norm_where(where)
            if set(where) - {"compass", "radius"}:
                continue
            pred, _, _ = position(where, f, [])
            if any(not pred(s) and any(pred(i) for i in f.images(s)[1:]) for s in dom):
                return bid, pred
        return None
    def footprint(self, var, slot):
        if var.orbit in (1, "single"):
            return [slot]
        return self.frame.images(slot)
    def implicit_points(self, name):
        f = self.frame
        c = f.c
        if name in ("centre", "middle", "ground"):
            return [(c, c)]
        if name in ("bases", "base"):
            far = f.G - 1 - max(1, f.G // 10)
            near = f.G - 1 - far
            if f.symmetry in ("mirror", "turn2"):
                return [(c, far), (c, near)] if f.axis == "z" else [(far, c), (near, c)]
            return [(c, far), (far, c), (c, near), (near, c)]
        if name in ("corners",):
            e = f.G - 2
            return [(1, 1), (e, 1), (e, e), (1, e)]
        return None
    def consistent(self, var, slot, assign):
        fp = self.footprint(var, slot)
        f = self.frame
        for other, oslot in assign.items():
            if other is var:
                continue
            ofp = self.footprint(other, oslot)
            if var.solid and other.solid and set(fp) & set(ofp) and not self._stacked(var, other):
                return False
            if self.pairs.get(var.aid) == other.aid or self.pairs.get(other.aid) == var.aid:
                if oslot not in f.images(slot)[1:]:
                    return False
            if var.aid == other.aid:
                if set(fp) & set(ofp):
                    return False
                sp = self.spacing.get(var.aid)
                if sp:
                    for a in fp:
                        for b in ofp:
                            if f.dist_units(a, b) < sp - 1e-6:
                                return False
        sp = self.spacing.get(var.aid)
        if sp and len(fp) > 1:
            for a, b in itertools.combinations(fp, 2):
                if f.dist_units(a, b) < sp - 1e-6:
                    return False
        for rv, rel, ofs, a in self.relations:
            if rv is var:
                if not self._relation_ok(slot, rel, ofs, assign, partial=True):
                    return False
            else:
                pass
        return True
    def _stacked(self, a, b):
        for rv, rel, ofs, anc in self.relations:
            if rel in ("above", "on") and ((rv is a and b.aid in ofs) or (rv is b and a.aid in ofs)):
                return True
        return False
    def _targets(self, name, assign):
        if name in self.by_anchor:
            pts = []
            for v in self.by_anchor[name]:
                if v in assign:
                    pts += self.footprint(v, assign[v])
                else:
                    return None
            return pts
        kind = [v for v in self.vars if v.what == name or v.what + "s" == name]
        if kind:
            pts = []
            for v in kind:
                if v not in assign:
                    return None
                pts += self.footprint(v, assign[v])
            return pts
        pts = self.implicit_points(name)
        return pts if pts is not None else "unknown"
    def _relation_ok(self, slot, rel, ofs, assign, partial):
        f = self.frame
        pts_all = []
        for o in ofs:
            pts = self._targets(o, assign)
            if pts == "unknown":
                continue
            if pts is None:
                return True if partial else False
            pts_all.append(pts)
        if not pts_all:
            return True
        u, v = f.uv(slot)
        def cheb(a, b):
            return max(abs(a[0] - b[0]), abs(a[1] - b[1]))
        if rel == "between":
            if len(pts_all) == 1:
                pairs = list(itertools.combinations(pts_all[0], 2))
            else:
                pairs = [(a, b) for a in pts_all[0] for b in pts_all[1]]
            for a, b in pairs:
                (ua, va), (ub, vb) = f.uv(a), f.uv(b)
                dx, dz = ub - ua, vb - va
                L2 = dx * dx + dz * dz
                if L2 == 0:
                    continue
                t = ((u - ua) * dx + (v - va) * dz) / L2
                if not 0.2 <= t <= 0.8:
                    continue
                px, pz = ua + t * dx, va + t * dz
                if math.hypot(u - px, v - pz) <= 1.6 / f.c + 1e-9:
                    return True
            return False
        targets = [p for pts in pts_all for p in pts]
        if rel in ("next_to", "near"):
            lim = 2 if rel == "next_to" else max(2, f.G // 4)
            return any(1 <= cheb(slot, p) <= lim for p in targets) or (
                rel == "near" and slot in targets)
        if rel == "around":
            return any(1 <= cheb(slot, p) <= 3 for p in targets)
        if rel in ("above", "on", "along"):
            return any(cheb(slot, p) <= (0 if rel != "along" else 1) for p in targets)
        if rel in ("facing", "opposite"):
            c2 = 2 * f.c
            return any(cheb(slot, (c2 - p[0], c2 - p[1])) <= 1 for p in targets)
        if rel in ("in_front_of", "behind"):
            for p in targets:
                pu, pv = f.uv(p)
                n = math.hypot(pu, pv) or 1.0
                step = 1.0 / f.c
                sign = -1 if rel == "in_front_of" else 1
                want = (pu + sign * pu / n * 2 * step, pv + sign * pv / n * 2 * step)
                if math.hypot(u - want[0], v - want[1]) <= 1.5 * step:
                    return True
            return False
        if rel == "far":
            return all(cheb(slot, p) >= f.G // 2 for p in targets)
        return True
    def order_values(self, var, rnd, assign=None):
        f = self.frame
        sibs = [s for o, s in (assign or {}).items() if o.aid == var.aid]
        def key(s):
            u, v = f.uv(s)
            d = 0.0 if var.ideal is None else math.hypot(u - var.ideal[0], v - var.ideal[1])
            spread = -min((f.dist_units(s, o) for o in sibs), default=0.0)
            pinned = 0 if var.pin is None or s == var.pin else 1
            return (pinned, round(spread, -2), round(d, 3), rnd.get(s, 0))
        return sorted(var.domain, key=key)
    def solve(self, seed=0):
        if self.unsolvable:
            return None
        f = self.frame
        r = stream(seed, "anchors")
        rnd = {s: r.random() for s in f.slots}
        assign = {}
        domains = {v: list(v.domain) for v in self.vars}
        nodes = [0]
        def forward(var, slot):
            pruned = {}
            for other in self.vars:
                if other in assign or other is var:
                    continue
                keep = [s for s in domains[other] if self.consistent(other, s, assign)]
                if not keep:
                    return None
                if len(keep) != len(domains[other]):
                    pruned[other] = domains[other]
                    domains[other] = keep
            return pruned
        def unassigned_relation_ok():
            for rv, rel, ofs, a in self.relations:
                if rv in assign and not self._relation_ok(assign[rv], rel, ofs, assign,
                                                          partial=True):
                    return False
            return True
        def bt():
            nodes[0] += 1
            if nodes[0] > NODE_CAP:
                raise _Cap()
            free = [v for v in self.vars if v not in assign]
            if not free:
                for rv, rel, ofs, a in self.relations:
                    if not self._relation_ok(assign[rv], rel, ofs, assign, partial=False):
                        return False
                return True
            var = min(free, key=lambda v: (len(domains[v]), self.vars.index(v)))
            for s in self.order_values(var, rnd, assign):
                if s not in domains[var]:
                    continue
                if not self.consistent(var, s, assign):
                    continue
                assign[var] = s
                if unassigned_relation_ok():
                    pruned = forward(var, s)
                    if pruned is not None:
                        if bt():
                            return True
                        for o, d in pruned.items():
                            domains[o] = d
                del assign[var]
            return False
        try:
            ok = bt()
        except _Cap:
            ok = None
        self.nodes = nodes[0]
        if ok:
            return dict(assign)
        return None if ok is False else "cap"
class _Cap(Exception):
    pass
def _norm_where(where):
    w = dict(where)
    if "compass" in w and isinstance(w["compass"], str):
        c = w["compass"].strip().lower().replace("_", "-")
        alias = {"north": "n", "south": "s", "east": "e", "west": "w", "northeast": "ne",
                 "north-east": "ne", "northwest": "nw", "north-west": "nw",
                 "southeast": "se", "south-east": "se", "southwest": "sw",
                 "south-west": "sw", "centre": "c", "center": "c", "middle": "c", "mid": "c"}
        w["compass"] = alias.get(c, c)
    if isinstance(w.get("relation"), str):
        w["relation"] = w["relation"].strip().lower().replace(" ", "_").replace("-", "_")
        w["relation"] = {"next": "next_to", "beside": "next_to", "on_top_of": "on",
                         "in_front": "in_front_of"}.get(w["relation"], w["relation"])
    return w
def _describe(a, where):
    what = a.get("what", "?")
    n = a.get("count")
    head = ("%d %s" % (n, what)) if n else what
    if "relation" in where:
        of = where.get("of")
        of = " and ".join(of) if isinstance(of, list) else of
        pos = "%s %s" % (where["relation"].replace("_", " "), of or "")
    elif "compass" in where:
        pos = "at " + COMPASS_NAMES.get(where["compass"], where["compass"])
    elif "clock" in where:
        pos = "at %s o'clock" % where["clock"]
    elif "cell" in where:
        pos = "at cell %s" % (where["cell"],)
    elif "x" in where:
        pos = "at x %s z %s" % (where.get("x"), where.get("z"))
    elif "edge" in where:
        pos = "at the edge"
    elif "on" in where:
        pos = "on the %s" % where["on"]
    else:
        pos = ""
    if a.get("spacing"):
        pos += " %d apart" % a["spacing"]
    return (head + " " + pos).strip()
class Solution:
    def __init__(self, problem, assign):
        self.problem = problem
        self.assign = assign
        self.frame = problem.frame
        self.notes = list(problem.notes)
    def placements(self):
        out = {}
        f = self.frame
        for v in self.problem.vars:
            s = self.assign[v]
            x, z = f.world(s)
            u, vv = f.uv(s)
            world = [list(f.world(i)) for i in self.problem.footprint(v, s)]
            if v.exact is not None:
                x, z = int(v.exact[0]), int(v.exact[1])
                u, vv = v.exact[0] / f.half, v.exact[1] / f.half
                world = [[x, z]]
            out.setdefault(v.aid, []).append({
                "slot": list(s), "x": x, "z": z, "compass": compass_of(u, vv),
                "images": [list(i) for i in self.problem.footprint(v, s)],
                "world": world})
        return out
    def lines(self):
        out = []
        pl = self.placements()
        for aid, a in self.problem.anchors.items():
            if aid in self.problem.post:
                out.append(("placed", aid, "%s: solved on the built map (spawn picker)"
                            % self.problem.groups[aid]))
                continue
            got = pl.get(aid, [])
            if not got:
                continue
            spots = ", ".join("%s (%d, %d)" % (COMPASS_NAMES[g["compass"]], g["x"], g["z"])
                              for g in got[:6])
            copies = sum(len(g["images"]) for g in got)
            more = "" if copies == len(got) else "; %d with the symmetry copies" % copies
            out.append(("placed", aid, "%s -> %s%s" % (self.problem.groups[aid], spots, more)))
        return out
    def brief_edits(self):
        pl = self.placements()
        out = []
        for a in self.problem.raw.get("anchors") or []:
            if not isinstance(a, dict):
                continue
            aid = a.get("id")
            got = pl.get(aid)
            if aid not in self.problem.anchors or got is None:
                out.append(a)
                continue
            where = self.problem.anchors[aid]["where"]
            simple = set(where) <= {"compass", "radius"} and where.get("compass") in COMPASS_VEC
            for k, g in enumerate(got):
                n = dict(a)
                n.pop("count", None)
                n.pop("spacing", None)
                if len(got) > 1:
                    n["id"] = "%s.%d" % (aid, k + 1)
                    n["once"] = len(g["images"]) == 1 or bool(a.get("once"))
                if not simple:
                    n["asked"] = where
                    n["where"] = {"compass": g["compass"]}
                n["solved"] = {"x": g["x"], "z": g["z"], "points": g["world"]}
                out.append(n)
        return out
def problem_ok(raw, drop=(), G=G_COARSE, seed=0):
    p = Problem(raw, G=G, drop=drop)
    res = p.solve(seed)
    if res is None and p.symmetry_asked is False and p.frame.symmetry == "mirror":
        p2 = Problem(raw, G=G, drop=drop, mirror_axis="x")
        r2 = p2.solve(seed)
        if isinstance(r2, dict):
            return p2, r2
    return p, res
def solve(raw, seed=None):
    seed = raw.get("seed", 0) if seed is None else seed
    seed = seed if isinstance(seed, int) else 0
    p, res = problem_ok(raw, seed=seed)
    if isinstance(res, dict):
        return Solution(p, res)
    if p.spacing or res == "cap":
        p2, res2 = problem_ok(raw, G=G_FINE, seed=seed)
        if isinstance(res2, dict):
            return Solution(p2, res2)
    names, why = conflict_set(raw, p, seed)
    raise Refused(names, why)
def conflict_set(raw, p, seed):
    groups = list(p.anchors) + ["size", "symmetry", "players"] + (["locks"] if p.locks else [])
    keep = list(groups)
    for g in list(groups):
        trial = [x for x in keep if x != g]
        drop = [x for x in groups if x not in trial]
        pp, res = problem_ok(raw, drop=drop, G=G_FINE if p.spacing else G_COARSE, seed=seed)
        if not isinstance(res, dict):
            keep = trial
    if not keep:
        keep = [g for g, _ in p.unsolvable[:2]] or groups[:1]
    why = []
    early = dict(p.unsolvable)
    for g in keep:
        if g in early:
            why.append(early[g])
        else:
            why.append("%s: %s" % (g, p.groups.get(g, g)))
    return keep, why
def _tops(arena):
    out = []
    for p in arena.get("pieces", []):
        w, d = p["w"], p["d"]
        if int(round(p.get("yaw", 0))) % 180 == 90:
            w, d = d, w
        out.append((p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0,
                    p["y"] + p["h"], p["kind"]))
    return out
def map_frame(arena):
    tops = _tops(arena)
    if not tops:
        return 0, 0, 1
    x0 = min(t[0] for t in tops)
    x1 = max(t[1] for t in tops)
    z0 = min(t[2] for t in tops)
    z1 = max(t[3] for t in tops)
    return (x0 + x1) / 2.0, (z0 + z1) / 2.0, max(x1 - x0, z1 - z0) / 2.0
def verify(arena, solution, origin_shift=(0, 0)):
    out = []
    tops = _tops(arena)
    cx, cz, half = map_frame(arena)
    if not tops:
        return out
    area = {}
    for t in tops:
        area[t[4]] = area.get(t[4], 0) + (t[1] - t[0]) * (t[3] - t[2])
    floor = max(area, key=lambda h: (area[h], -h))
    scale = half / max(1.0, solution.frame.half)
    NEED = {"tower": 600, "vantage": 400, "landmark": 400, "crown": 300, "hill": 200,
            "perch": 200}
    for aid, got in solution.placements().items():
        a = solution.problem.anchors[aid]
        what = a.get("what")
        tol = a.get("tolerance", 400) + 0.25 * half
        pts = [(cx + x * scale, cz + z * scale) for g in got for (x, z) in g["world"]]
        if what in ("tower", "perch", "vantage", "crown", "hill", "landmark"):
            need = a.get("height") or NEED[what]
            worst = 0
            for (x, z) in pts:
                best = min((math.hypot(max(t[0] - x, 0, x - t[1]), max(t[2] - z, 0, z - t[3]))
                            for t in tops if t[4] - floor >= need - 1), default=None)
                worst = max(worst, best if best is not None else 1e9)
            if worst <= tol:
                out.append(("placed", aid, "%s stands within %d of each solved point"
                            % (what, worst)))
            else:
                out.append(("approximated", aid, "no %s %d high within %d of a solved point "
                            "(nearest %s)" % (what, need, tol,
                                              "none" if worst >= 1e9 else int(worst))))
        elif what in ("spawn", "spawns"):
            sp = arena.get("spawns", [])
            near = [s for s in sp if any(math.hypot(s["x"] - x, s["z"] - z) <= tol
                                         for x, z in pts)]
            if near:
                out.append(("placed", aid, "%d of the spawns stand at the solved points"
                            % len(near)))
            else:
                out.append(("approximated", aid, "no spawn within %d of the solved points"
                            % tol))
        elif what == "world_spawn":
            out.append(("placed", aid, "the map is moved so the world spawn is the origin"))
        else:
            out.append(("unverified", aid, "%s: the family's own report says how it was built"
                        % what))
    return out
