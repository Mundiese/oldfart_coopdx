from . import contract, kit, v1
TAG = "detail."
PROUD = 100
CAP_H = 100
PLINTH_H = 200
POST = 100
POLE = 40
PILASTER_W = 200
PILASTER_EVERY = 1400
STOREY_BAND = 1200
WINDOW_FACE = 800
WINDOW_H = 400
RIDGE_CAP = 200
RIDGE_T = 20
FINIAL_H = 400
LIP_LOW, LIP_HIGH = 20, 200
HEADROOM = 400
SLOT = 160
LANE_MIN = 400
KEYS_MAX = 40
SHARE = 0.30
KEEP = 0.92
RESERVE = 24
TOL = 2
HOSTS = ("house", "hut", "cottage", "home", "shop", "inn", "barn", "chapel", "prefab",
         "building", "hall", "tower", "spire", "landmark", "centre", "keep", "watchtower",
         "turret", "fort", "castle", "gate", "gatehouse", "temple", "bastion", "unit",
         "base0", "base1", "base", "base_blue", "base_red", "wall", "rampart", "outer",
         "obelisk", "lighthouse", "monument", "windmill", "block", "bunker")
NOT_HOSTS = ("terrace", "edge", "landform", "tree", "hedge", "maze", "breaker", "decor", "dress",
             "fill", "hills", "slope", "lake", "river", "water", "road", "path", "lane", "lanes",
             "avenue", "floor", "field", "plateau", "keel", "island", "ring", "plank", "mark",
             "pad", "chord", "ramp", "play", "beat", "start", "goal", "rest", "bridge", "climb",
             "boardwalk", "cloud", "backdrop", "boundary", "perch", "spawn", "star", "mover",
             "stair", "stairs", "flight", "deck", "catwalk", "yard", "tier2", "plaza",
             "facade", "stoop", "chimney", "woodpile", "roof", "trim", "door", "lintel", "sill",
             "platform", "gallery", "landing", "summit",
             "post", "stilt", "porch", "awning", "stall", "tent", "detail", "invisible")
IMPORTANT = ("landmark", "centre", "spire", "keep", "castle", "temple", "tower")
HOUSE_DONE = ("D1", "D3", "D5", "D30")
TIGHT = ("shooter", "objective", "knockoff", "party", "course", "race")
def _m():
    return v1.arenas_module()
def rect(p):
    x0, x1, z0, z1, _ = _m().footprint(p)
    return (x0, x1, z0, z1)
def _words(p):
    return str(p.get("tag", "")).lower().replace(".", " ").replace("_", " ").split()
def _root(p):
    t = str(p.get("tag", "")).lower()
    return t.split(".")[0].split(" ")[0]
def _detail(p):
    return str(p.get("tag", "")).startswith(TAG)
def box(tex, x0, x1, y0, y1, z0, z1, part):
    return kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, TAG + part)
def aabb(p):
    x0, x1, z0, z1 = rect(p)
    y0, y1 = p["y"], p["y"] + p["h"]
    k = p.get("kind")
    if k in ("doorway", "window"):
        if (x1 - x0) >= (z1 - z0):
            c, t = (z0 + z1) / 2.0, (z1 - z0) / 8.0
            return (x0, x1, y0, y1, c - t, c + t)
        c, t = (x0 + x1) / 2.0, (x1 - x0) / 8.0
        return (c - t, c + t, y0, y1, z0, z1)
    if k == "pole":
        cx, cz, t = (x0 + x1) / 2.0, (z0 + z1) / 2.0, (x1 - x0) / 10.0
        return (cx - t, cx + t, y0, y1, cz - t, cz + t)
    return (x0, x1, y0, y1, z0, z1)
def _meet(a, b, tol=TOL):
    return (min(a[1], b[1]) - max(a[0], b[0]) > tol and min(a[3], b[3]) - max(a[2], b[2]) > tol
            and min(a[5], b[5]) - max(a[4], b[4]) > tol)
def _plan_meet(a, b, tol=TOL):
    return min(a[1], b[1]) - max(a[0], b[0]) > tol and min(a[5], b[5]) - max(a[4], b[4]) > tol
def _gap(a, b):
    gx = max(a[0], b[0]) - min(a[1], b[1])
    gz = max(a[4], b[4]) - min(a[5], b[5])
    if gx > 0 and gz < 0:
        return gx
    if gz > 0 and gx < 0:
        return gz
    return None
def _y_overlap(a, b):
    return min(a[3], b[3]) - max(a[2], b[2])
class Site:
    def __init__(self, cls, parts, root, house=False):
        self.cls = cls
        self.parts = parts
        self.root = root
        self.house = house
        self.done = set()
        self.bands = []
        r = rect(parts[0])
        self.rect = r
        self.y0 = parts[0]["y"]
        self.y1 = parts[-1]["y"] + parts[-1]["h"]
        ws = set(w for q in parts for w in _words(q))
        self.backdrop = "backdrop" in ws
        from . import guards
        self.float_word = next((w for w in sorted(ws) if w.startswith(guards.FLOAT_OK)), None)
        self.important = 3 if root in IMPORTANT else 1 if self.backdrop else \
            2 if cls in ("building", "tower", "house", "roof") else 1
    @property
    def w(self):
        return self.rect[1] - self.rect[0]
    @property
    def d(self):
        return self.rect[3] - self.rect[2]
    def box(self, grow=0.0, y0=None, y1=None):
        r = self.rect
        return (r[0] - grow, r[1] + grow, self.y0 if y0 is None else y0,
                self.y1 if y1 is None else y1, r[2] - grow, r[3] + grow)
    def signature(self):
        return (self.cls, tuple(sorted((round(self.w), round(self.d)))), round(self.y1 - self.y0),
                round(self.y0))
def _hostable(p):
    ws = set(_words(p))
    if "backdrop" in ws and not ws & {"tiles", "invisible"}:
        return True
    if ws & set(NOT_HOSTS) and not (_root(p) == "house" and "wall" in ws):
        return False
    return _root(p) in HOSTS or _root(p).startswith(("base", "tower", "house"))
def recognise(pieces):
    from . import boundary
    edge = set(id(pieces[i]) for i in boundary.edge_pieces(pieces))
    cols = {}
    for i, p in enumerate(pieces):
        if p.get("kind") != "box" or p.get("decor") or p.get("tex") == "invisible" \
                or id(p) in edge:
            continue
        r = tuple(int(round(v)) for v in rect(p))
        cols.setdefault(r, []).append(p)
    sites = []
    for r, ps in cols.items():
        ps.sort(key=lambda q: q["y"])
        runs, run = [], [ps[0]]
        for q in ps[1:]:
            prev = run[-1]
            if abs(q["y"] - (prev["y"] + prev["h"])) <= 1:
                run.append(q)
            else:
                runs.append(run)
                run = [q]
        runs.append(run)
        for run in runs:
            if not all(_hostable(q) for q in run):
                continue
            h = run[-1]["y"] + run[-1]["h"] - run[0]["y"]
            w, d = r[1] - r[0], r[3] - r[2]
            lo, hi = min(w, d), max(w, d)
            if h < 400 or lo < 200:
                continue
            root = _root(run[0])
            house = root == "house" and any("wall" in _words(q) for q in run)
            if house:
                cls = "house"
            elif hi >= 3 * lo and lo <= 400:
                cls = "wall"
            elif lo < 400:
                continue
            elif hi <= 800 and h >= 2 * hi:
                cls = "tower"
            else:
                cls = "building"
            sites.append(Site(cls, run, root, house))
    for p in pieces:
        if p.get("kind") in ("ridge", "pyramid") and _root(p) not in ("bridge", "awning",
                                                                       "stall", "tent", "detail"):
            sites.append(Site("roof", [p], _root(p), _root(p) == "house"))
    sites.sort(key=lambda s: (s.rect, s.y0, s.cls))
    return sites
class Pass:
    def __init__(self, arena, brief, meta, theme, family, cap, grammar):
        self.arena = arena
        self.pieces = arena["pieces"]
        self.brief = brief
        self.meta = meta
        self.theme = theme
        self.family = family
        self.cap = cap
        self.grammar = grammar
        self.added = []
        self.by_rule = {}
        self.skipped = {}
        self.keys = set()
        self.pending = []
        self.level_floor = _m().LEVELS.get(arena.get("level"), {}).get("floor")
        self._pal = None
    def pal(self):
        if self._pal is None:
            try:
                from . import beauty
                pal, _ = beauty.palette(self.theme if self.theme in kit.THEMES else "castle")
                pal = dict(pal)
                contract.split_roles(self.theme, pal)
            except Exception:
                pal = {}
            self._pal = pal
        return self._pal
    def tex(self, cls, prefer, host=None, kind=None):
        t = None
        try:
            t = contract.material(self.theme, cls, self.pal(), prefer=prefer, kind=kind)
        except Exception:
            t = None
        if t is None and host is not None:
            t = kit.tex_key(host)
        return t or self.pal().get("wall") or "stone1"
    def skip(self, rule, why):
        k = "%s: %s" % (rule, why)
        self.skipped[k] = self.skipped.get(k, 0) + 1
    def near(self, b, pad=0.0, exclude=()):
        ex = set(id(q) for q in exclude)
        out = []
        for q in list(self.pieces) + list(self.pending):
            if id(q) in ex or q.get("tex") == "invisible":
                continue
            a = aabb(q)
            if a[0] - pad < b[1] and b[0] - pad < a[1] and a[4] - pad < b[5] and b[4] - pad < a[5]:
                out.append(q)
        return out
    def floor_at(self, x, z, y):
        if self.level_floor is not None and abs(self.level_floor - y) <= 12:
            return True
        for q in self.near((x, x, y - 1, y + 1, z, z), pad=1):
            if q.get("kind") == "water":
                continue
            t = _m().top_at(q, x, z) if _m().covers(q, x, z) else None
            if t is not None and abs(t - y) <= 3:
                return True
        return False
    def check(self, rule, new, host_parts, host_box=None):
        hosts = list(host_parts) + list(new)
        self.blame = None
        for q in new:
            b = aabb(q)
            for o in self.near(b, pad=SLOT + 2, exclude=hosts):
                self.blame = o
                a = aabb(o)
                if _meet(a, b):
                    return "it would share space with %s" % o.get("tag", o.get("kind"))
                if _plan_meet(a, b):
                    gap_up = a[2] - b[3]
                    gap_dn = b[2] - a[3]
                    for gp in (gap_up, gap_dn):
                        if TOL < gp < SLOT:
                            return "it would leave a %d slot (a crawl space)" % gp
                    if q.get("_overhang") and TOL < gap_dn < HEADROOM:
                        return "G5: an overhang %d over a floor (>= %d)" % (gap_dn, HEADROOM)
            if LIP_LOW < q["h"] < LIP_HIGH and not q.get("_course"):
                cx, cz = (b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0
                for o in self.near((cx, cx, q["y"] - 1, q["y"] + 1, cz, cz), pad=1, exclude=new):
                    self.blame = o
                    if abs(o["y"] + o["h"] - q["y"]) <= 2:
                        return "G1: a %d step on a walked floor" % q["h"]
            if q["h"] >= 300 and q.get("kind") != "pole":
                from . import movement
                lo, hi = movement.CHIMNEY_MIN, movement.CHIMNEY_MAX
                for o in self.near(b, pad=hi, exclude=hosts):
                    self.blame = o
                    if o.get("kind") == "water" or o.get("h", 0) < 300:
                        continue
                    a = aabb(o)
                    if _y_overlap(a, b) < 300:
                        continue
                    g = _gap(a, b)
                    if g is None or not (lo <= g <= hi):
                        continue
                    hg = _gap(a, host_box) if host_box is not None else None
                    if hg is None or not (lo <= hg <= hi):
                        return "G4: a new wall-kick gap of %d" % g
            from . import movement
            for o in self.near(b, pad=LANE_MIN, exclude=hosts):
                self.blame = o
                if o.get("kind") == "water":
                    continue
                a = aabb(o)
                if _y_overlap(a, b) < movement.TALL:
                    continue
                g = _gap(a, b)
                if g is None or not (movement.CORRIDOR_MIN <= g < LANE_MIN):
                    continue
                hg = _gap(a, host_box) if host_box is not None else None
                if hg is None or hg >= LANE_MIN:
                    return "G7: a lane left %d wide" % g
        return None
    def keys_ok(self, new):
        ks = set(self.keys)
        for q in new:
            ks.add((q["kind"], kit.tex_key(q), int(q["w"]), int(q["h"]), int(q["d"])))
        return len(ks) <= KEYS_MAX
    def apply(self, entry, s, new, mods, how, hosts):
        for p, ch in mods:
            prev = dict((k, p[k]) for k in ch)
            prev["detail_was"] = p.get("detail_was")
            if "detail_was" not in p:
                p["detail_was"] = [p["y"], p["h"], p["x"], p["z"], p["w"], p["d"]]
            p.update(ch)
            p.pop("model", None)
            p["model"] = _m().model_name(p)
            entry["mods"].append((p, prev, how))
        if how == "swap":
            gone = [h for h in hosts if any(h is q for q in s.parts)]
            ids = set(id(h) for h in gone)
            self.pieces[:] = [q for q in self.pieces if id(q) not in ids]
            entry["removed"] += gone
        if how == "grow":
            return
        for q in new:
            for k in ("_overhang", "_course"):
                q.pop(k, None)
            q["model"] = _m().model_name(q)
            self.pieces.append(q)
            self.added.append(q)
            entry["added"].append(q)
            self.keys.add((q["kind"], kit.tex_key(q), int(q["w"]), int(q["h"]), int(q["d"])))
    def undo(self, entry):
        ids = set(id(q) for q in entry["added"])
        self.pieces[:] = [q for q in self.pieces if id(q) not in ids]
        self.added = [q for q in self.added if id(q) not in ids]
        for p, prev, _ in reversed(entry["mods"]):
            was = prev.pop("detail_was", None)
            p.update(prev)
            if was is None:
                p.pop("detail_was", None)
            else:
                p["detail_was"] = was
            p.pop("model", None)
            p["model"] = _m().model_name(p)
        self.pieces.extend(entry["removed"])
class Rule:
    __slots__ = ("id", "name", "tier", "gain", "cost", "classes", "make", "kinds", "source")
    def __init__(self, id, name, tier, gain, cost, classes, make=None, kinds=(), source=None):
        self.id, self.name, self.tier, self.gain, self.cost = id, name, tier, gain, cost
        self.classes, self.make, self.kinds, self.source = classes, make, kinds, source
def _top_part(s):
    return s.parts[-1]
def _bottom_part(s):
    return s.parts[0]
def _course_word(p, word):
    return word in _words(p)
def make_cap(P, s, flush=False):
    top = _top_part(s)
    r = s.rect
    if min(s.w, s.d) >= 800 and not s.backdrop and not _roofed(P, s):
        return "its top is a floor"
    tex = P.tex("trim", ("wall_cap", "trim"), top)
    y1 = s.y1
    if flush or (y1 - CAP_H) - s.y0 < HEADROOM:
        if _course_word(top, "cap") or top["h"] < CAP_H + 200 or tex == kit.tex_key(top):
            return None
        band = box(tex, r[0], r[1], y1 - CAP_H, y1, r[2], r[3], "cap.course")
        band["_course"] = True
        return [band], [(top, {"h": top["h"] - CAP_H})], "flush"
    if _course_word(top, "cap") and top["h"] <= 200:
        mods = [(top, {"w": top["w"] + 2 * PROUD, "d": top["d"] + 2 * PROUD})]
        trial = dict(top, **mods[0][1])
        trial["_course"] = True
        trial["_overhang"] = True
        return [trial], mods, "grow"
    if top["h"] < CAP_H + 200:
        return None
    band = box(tex, r[0] - PROUD, r[1] + PROUD, y1 - CAP_H, y1, r[2] - PROUD, r[3] + PROUD, "cap")
    band["_course"] = True
    band["_overhang"] = True
    return [band], [(top, {"h": top["h"] - CAP_H})], "band"
def _roofed(P, s):
    r = s.rect
    for q in P.pieces:
        if q.get("kind") in ("ridge", "pyramid", "prism") and abs(q["y"] - s.y1) <= 2:
            qr = rect(q)
            if qr[0] < r[1] and r[0] < qr[1] and qr[2] < r[3] and r[2] < qr[3]:
                return True
    return False
def make_plinth(P, s, flush=False):
    bot = _bottom_part(s)
    r = s.rect
    if flush or P.family in TIGHT:
        tex = P.tex("trim", ("wall_base", "keel", "cover"), bot)
        if _course_word(bot, "base") or bot["h"] < PLINTH_H + 200 or tex == kit.tex_key(bot):
            return None
        pl = box(tex, r[0], r[1], s.y0, s.y0 + PLINTH_H, r[2], r[3], "plinth.course")
        pl["_course"] = True
        return [pl], [(bot, {"y": bot["y"] + PLINTH_H, "h": bot["h"] - PLINTH_H})], "flush"
    pts = [((r[0] + r[1]) / 2.0, r[2] - PROUD / 2.0), ((r[0] + r[1]) / 2.0, r[3] + PROUD / 2.0),
           (r[0] - PROUD / 2.0, (r[2] + r[3]) / 2.0), (r[1] + PROUD / 2.0, (r[2] + r[3]) / 2.0),
           (r[0] - PROUD / 2.0, r[2] - PROUD / 2.0), (r[1] + PROUD / 2.0, r[3] + PROUD / 2.0),
           (r[0] - PROUD / 2.0, r[3] + PROUD / 2.0), (r[1] + PROUD / 2.0, r[2] - PROUD / 2.0)]
    if not all(P.floor_at(x, z, s.y0) for x, z in pts):
        return "the ground round it is not level"
    tex = P.tex("trim", ("wall_base", "keel", "cover"), bot)
    if _course_word(bot, "base") and bot["h"] == PLINTH_H:
        ch = {"w": bot["w"] + 2 * PROUD, "d": bot["d"] + 2 * PROUD}
        trial = dict(bot, **ch)
        trial["_course"] = True
        return [trial], [(bot, ch)], "grow"
    if bot["h"] < PLINTH_H + 200:
        return None
    pl = box(tex, r[0] - PROUD, r[1] + PROUD, s.y0, s.y0 + PLINTH_H, r[2] - PROUD, r[3] + PROUD,
             "plinth")
    pl["_course"] = True
    return [pl], [(bot, {"y": bot["y"] + PLINTH_H, "h": bot["h"] - PLINTH_H})], "band"
def make_string(P, s):
    lo = s.y0 + (PLINTH_H if "D3" in s.done else 0)
    hi = s.y1 - (CAP_H if "D2" in s.done else 0)
    at = lo + int(round((hi - lo) * 2 / 3.0 / 100.0)) * 100
    if at - lo < 400 or hi - at - CAP_H < 400:
        return None
    part = next((q for q in s.parts if q["y"] + 1 < at and at + CAP_H < q["y"] + q["h"] - 1), None)
    if part is None:
        return None
    r = s.rect
    tex = P.tex("trim", ("trim", "wall_cap"), part)
    band = box(tex, r[0] - PROUD, r[1] + PROUD, at, at + CAP_H, r[2] - PROUD, r[3] + PROUD,
               "band")
    band["_course"] = True
    band["_overhang"] = True
    upper = dict(part, y=at + CAP_H, h=part["y"] + part["h"] - at - CAP_H)
    upper.pop("detail_was", None)
    upper["detail_part"] = True
    upper["_course"] = True
    return [band, upper], [(part, {"h": at - part["y"]})], "split"
def _posts_span(s):
    lo, hi = s.y0, s.y1
    spans = [(lo, hi)]
    for b0, b1 in sorted(s.bands):
        nxt = []
        for a0, a1 in spans:
            if b1 <= a0 or b0 >= a1:
                nxt.append((a0, a1))
                continue
            if b0 > a0:
                nxt.append((a0, b0))
            if b1 < a1:
                nxt.append((b1, a1))
        spans = nxt
    return [(a0, a1) for a0, a1 in spans if a1 - a0 >= 300]
def make_posts(P, s, flush=False):
    r = s.rect
    host = s.parts[0]
    kind = "pole" if flush else None
    tex = P.tex("structure", ("trim", "wall_alt", "wall_cap"), host, kind=kind)
    side = POLE if flush else POST
    out = []
    for a0, a1 in _posts_span(s):
        for x0, z0 in ((r[0] - side, r[2] - side), (r[1], r[2] - side), (r[0] - side, r[3]),
                       (r[1], r[3])):
            foot = _foot(P, (x0, x0 + side, a0, a1, z0, z0 + side), s.parts)
            if a1 - foot < 300:
                continue
            if not P.floor_at(x0 + side / 2.0, z0 + side / 2.0, foot):
                continue
            head = _head(P, (x0, x0 + side, foot, a1, z0, z0 + side), s.parts)
            if flush:
                cx, cz = x0 + side / 2.0, z0 + side / 2.0
                p = kit.kind("pole").make(tex, cx - 100, cx + 100, foot, head, cz - 100, cz + 100,
                                          None, TAG + "post")
            else:
                p = box(tex, x0, x0 + side, foot, head, z0, z0 + side, "post")
            out.append(p)
    return (out, [], "flush" if flush else "posts") if out else None
def _head(P, b, hosts):
    head = b[3]
    for o in P.near((b[0], b[1], b[3], b[3] + SLOT, b[4], b[5]), exclude=hosts):
        a = aabb(o)
        if _plan_meet(a, b) and b[3] < a[2] < b[3] + SLOT:
            head = max(head, a[2]) if head == b[3] else min(head, a[2])
    return head
def _foot(P, b, hosts):
    foot = b[2]
    for o in P.near(b, exclude=hosts):
        a = aabb(o)
        if not _plan_meet(a, b) or o.get("kind") == "water":
            continue
        if b[2] - TOL < a[3] < b[3]:
            foot = max(foot, a[3])
    return foot
def make_pilasters(P, s):
    r = s.rect
    along_x = s.w >= s.d
    length = s.w if along_x else s.d
    n = int(length // PILASTER_EVERY)
    if n < 1:
        return None
    host = s.parts[0]
    tex = P.tex("structure", ("trim", "wall_alt"), host)
    a0 = (r[0] if along_x else r[2]) + (length - (n - 1) * PILASTER_EVERY) / 2.0
    out = []
    for a0_, a1_ in _posts_span(s):
        for k in range(n):
            c = a0 + k * PILASTER_EVERY
            c = round(c / 100.0) * 100
            for side in (-1, 1):
                if along_x:
                    z = (r[2] - PROUD) if side < 0 else r[3]
                    b = (c - PILASTER_W / 2, c + PILASTER_W / 2, a0_, a1_, z, z + PROUD)
                else:
                    x = (r[0] - PROUD) if side < 0 else r[1]
                    b = (x, x + PROUD, a0_, a1_, c - PILASTER_W / 2, c + PILASTER_W / 2)
                foot = _foot(P, b, s.parts)
                if b[3] - foot < 300:
                    continue
                out.append(box(tex, b[0], b[1], foot, b[3], b[4], b[5], "pilaster"))
    return (out, [], "pilasters") if out else None
BUILT_FAMILIES = ("masonry", "brick", "wood", "plaster", "timber", "metal", "facade", "tile",
                  "glass")
def _built_tex(p):
    try:
        return contract.family(kit.tex_key(p)) in BUILT_FAMILIES
    except Exception:
        return False
def make_windows(P, s):
    r = s.rect
    host = s.parts[0]
    if not _built_tex(host):
        return "it is rock or ground, not a built wall"
    y = s.y1 - (CAP_H if "D2" in s.done else 0) - 200 - WINDOW_H
    if y < s.y0 + (PLINTH_H if ("D3" in s.done or s.house) else 0) + 100:
        return None
    for b0, b1 in s.bands:
        if b0 < y + WINDOW_H and y < b1:
            return None
    tex = P.tex("trim", ("trim", "wall_alt", "wall_cap"), host, kind="window")
    out = []
    for face in ("-z", "+z", "-x", "+x"):
        lo_, hi_ = (r[0], r[1]) if face in ("-z", "+z") else (r[2], r[3])
        length = hi_ - lo_
        if length < WINDOW_FACE:
            continue
        n = int((length - 400) // 800) + 1
        start = lo_ + (length - (n - 1) * 800) / 2.0
        for k in range(n):
            c = round((start + k * 800) / 100.0) * 100
            if face == "-z":
                p = kit.kind("window").make(tex, c - 100, c + 100, y, y + WINDOW_H, r[2] - 125,
                                            r[2] + 75, None, TAG + "window")
            elif face == "+z":
                p = kit.kind("window").make(tex, c - 100, c + 100, y, y + WINDOW_H, r[3] - 75,
                                            r[3] + 125, None, TAG + "window")
            elif face == "-x":
                p = kit.kind("window").make(tex, r[0] - 125, r[0] + 75, y, y + WINDOW_H, c - 100,
                                            c + 100, None, TAG + "window")
            else:
                p = kit.kind("window").make(tex, r[1] - 75, r[1] + 125, y, y + WINDOW_H, c - 100,
                                            c + 100, None, TAG + "window")
            if face in ("-x", "+x"):
                p["yaw"] = 90
            out.append(p)
    return (out, [], "windows") if out else None
def _roof_host(P, s):
    p = s.parts[0]
    rr = rect(p)
    for q in P.pieces:
        if q is p or q.get("kind") != "box":
            continue
        if abs(q["y"] + q["h"] - p["y"]) > 2:
            continue
        qr = rect(q)
        if qr[0] - 1 <= rr[0] and rr[1] <= qr[1] + 1 and qr[2] - 1 <= rr[2] and rr[3] <= qr[3] + 1:
            return q
    return None
def make_overhang(P, s):
    p = s.parts[0]
    q = _roof_host(P, s)
    if q is None:
        return "no walls under it"
    rr, qr = rect(p), rect(q)
    if any(abs(a - b) > 1 for a, b in zip(rr, qr)):
        return "it overhangs already"
    over = 200 if min(s.w, s.d) >= 1200 else PROUD
    ch = {"w": p["w"] + 2 * over, "d": p["d"] + 2 * over}
    trial = dict(p, **ch)
    trial["_overhang"] = True
    return [trial], [(p, ch)], "grow", [q]
def make_ridge_cap(P, s):
    p = s.parts[0]
    if p.get("kind") != "ridge":
        return None
    r = rect(p)
    top = p["y"] + p["h"]
    tex = P.tex("trim", ("trim", "wall_cap"), p)
    along_x = int(round(p.get("yaw", 0))) % 180 == 0
    cx, cz = (r[0] + r[1]) / 2.0, (r[2] + r[3]) / 2.0
    if along_x:
        q = box(tex, r[0], r[1], top, top + RIDGE_T, cz - RIDGE_CAP / 2, cz + RIDGE_CAP / 2,
                "ridge.cap")
    else:
        q = box(tex, cx - RIDGE_CAP / 2, cx + RIDGE_CAP / 2, top, top + RIDGE_T, r[2], r[3],
                "ridge.cap")
    return [q], [], "cap"
def make_tower_cap(P, s):
    top = s.y1
    r = s.rect
    if _carries(P, r, top):
        return "something stands on its top"
    for q in P.pieces:
        if abs(q["y"] - top) <= 2:
            qr = rect(q)
            if qr[0] < r[1] and r[0] < qr[1] and qr[2] < r[3] and r[2] < qr[3]:
                return "its top carries something"
    g = PROUD if "D2" in s.done else 0
    h = max(200, int(min(s.w, s.d) / 2 // 100 * 100))
    roof = P.tex("roof", ("roof",), s.parts[-1], kind="pyramid")
    pyr = kit.kind("pyramid").make(roof, r[0] - g, r[1] + g, top, top + h, r[2] - g, r[3] + g,
                                   None, TAG + "roof.cap")
    cx, cz = (r[0] + r[1]) / 2.0, (r[2] + r[3]) / 2.0
    finial = kit.kind("pole").make(P.tex("structure", ("trim",), s.parts[-1], kind="pole"),
                                   cx - 100, cx + 100, top + h, top + h + FINIAL_H, cz - 100,
                                   cz + 100, None, TAG + "finial.post")
    return [pyr, finial], [], "cap"
def _carries(P, r, top):
    a = P.arena
    things = list(a.get("spawns") or []) + list(a.get("markers") or []) \
        + list(a.get("objects") or []) + list(a.get("stars") or [])
    for t in things:
        if not isinstance(t, dict) or "x" not in t or "z" not in t:
            continue
        if r[0] - 1 <= t["x"] <= r[1] + 1 and r[2] - 1 <= t["z"] <= r[3] + 1 \
                and t.get("y", top) >= top - 50:
            return True
    return False
def make_corbels(P, s):
    if "D2" not in s.done:
        return None
    r = s.rect
    if min(s.w, s.d) < 400:
        return None
    y1 = s.y1 - CAP_H
    host = s.parts[-1]
    tex = P.tex("trim", ("wall_cap", "trim"), host, kind="uslope")
    out = []
    cx, cz = (r[0] + r[1]) / 2.0, (r[2] + r[3]) / 2.0
    for face in ("-z", "+z", "-x", "+x"):
        if face == "-z":
            c = kit.kind("uslope").make(tex, cx - 100, cx + 100, y1 - 200, y1, r[2] - 200, r[2],
                                        "+z", TAG + "corbel")
        elif face == "+z":
            c = kit.kind("uslope").make(tex, cx - 100, cx + 100, y1 - 200, y1, r[3], r[3] + 200,
                                        "-z", TAG + "corbel")
        elif face == "-x":
            c = kit.kind("uslope").make(tex, r[0] - 200, r[0], y1 - 200, y1, cz - 100, cz + 100,
                                        "+x", TAG + "corbel")
        else:
            c = kit.kind("uslope").make(tex, r[1], r[1] + 200, y1 - 200, y1, cz - 100, cz + 100,
                                        "-x", TAG + "corbel")
        out.append(c)
    return out, [], "corbels"
def make_skirt(P, s):
    p = s.parts[0]
    r = rect(p)
    y = p["y"]
    if (r[1] - r[0]) % 200 or (r[3] - r[2]) % 200:
        return None
    tex = P.tex("roof", ("roof",), p, kind="wedgetip")
    out = []
    pyramid = p.get("kind") == "pyramid"
    for q in P.pieces:
        if q.get("kind") == "outer" and abs(q["y"] - y) <= 2:
            qr = rect(q)
            if qr[0] <= r[1] + 1 and r[0] <= qr[1] + 1 and qr[2] <= r[3] + 1 and r[2] <= qr[3] + 1:
                return None
    along_x = int(round(p.get("yaw", 0))) % 180 == 0
    W = 200
    sides = []
    if pyramid or along_x:
        sides += [("-z", r[0], r[1], r[2] - W, r[2], "+z"), ("+z", r[0], r[1], r[3], r[3] + W, "-z")]
    if pyramid or not along_x:
        sides += [("-x", r[0] - W, r[0], r[2], r[3], "+x"), ("+x", r[1], r[1] + W, r[2], r[3], "-x")]
    for _, x0, x1, z0, z1, rises in sides:
        out.append(kit.kind("wedgetip").make(tex, x0, x1, y - 200, y, z0, z1, rises,
                                             TAG + "roof.skirt"))
    if pyramid:
        for x0, z0, hi in ((r[0] - W, r[2] - W, "+x+z"), (r[1], r[2] - W, "-x+z"),
                           (r[0] - W, r[3], "+x-z"), (r[1], r[3], "-x-z")):
            out.append(kit.kind("wedgetipouter").make(tex, x0, x0 + W, y - 200, y, z0, z0 + W, hi,
                                                      TAG + "roof.skirt"))
    for q in out:
        q["_overhang"] = True
    return out, [], "skirt"
def make_round(P, s):
    if len(s.parts) != 1 or s.w != s.d or s.w not in (400, 800):
        return None
    if _carries(P, s.rect, s.y1):
        return "something stands on its top"
    p = s.parts[0]
    r = s.rect
    q = s.w / 2.0
    cx, cz = r[0] + q, r[2] + q
    tex = kit.tex_key(p)
    out = []
    for x0, z0, centre in ((r[0], r[2], "+x+z"), (cx, r[2], "-x+z"), (r[0], cz, "+x-z"),
                           (cx, cz, "-x-z")):
        c = kit.kind("roundcorner").make(tex, x0, x0 + q, s.y0, s.y1, z0, z0 + q, centre,
                                         str(p.get("tag", "")) + ".round")
        c["detail_part"] = True
        out.append(c)
    keep = dict(p)
    keep.pop("model", None)
    out[0]["detail_swap"] = keep
    return out, [], "swap", [p]
def make_chimney(P, s):
    p = s.parts[0]
    if p.get("kind") != "ridge":
        return None
    r = rect(p)
    top = p["y"] + p["h"]
    along_x = int(round(p.get("yaw", 0))) % 180 == 0
    if (r[1] - r[0] if along_x else r[3] - r[2]) < 800:
        return None
    if along_x:
        b = (r[0] - 200, r[0], 0, 0, (r[2] + r[3]) / 2.0 - 100, (r[2] + r[3]) / 2.0 + 100)
    else:
        b = ((r[0] + r[1]) / 2.0 - 100, (r[0] + r[1]) / 2.0 + 100, 0, 0, r[2] - 200, r[2])
    b = tuple(round(v / 100.0) * 100 for v in b)
    foot = None
    for o in P.near((b[0], b[1], -1e6, p["y"], b[4], b[5])):
        a_ = aabb(o)
        if o.get("kind") == "water" or not _plan_meet(a_, b):
            continue
        if a_[3] <= p["y"] + TOL:
            foot = a_[3] if foot is None else max(foot, a_[3])
    if foot is None or not P.floor_at((b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0, foot):
        return "no ground under its gable end"
    tex = P.tex("building_wall", ("wall_base", "wall"), p)
    q = box(tex, b[0], b[1], foot, top + 200, b[4], b[5], "chimney")
    return [q], [], "chimney"
RULES = [
    Rule("D1", "roof overhang", "A", 5, 0.5, ("roof",), make_overhang),
    Rule("D2", "cap line", "A", 5, 1, ("building", "tower", "wall", "house"), make_cap),
    Rule("D3", "plinth", "A", 4, 1, ("building", "tower", "wall"), make_plinth),
    Rule("D8", "string course", "B", 3, 2, ("building", "tower"), make_string),
    Rule("D4", "corner posts", "A", 4, 4, ("building", "tower", "house"), make_posts),
    Rule("D6", "ridge cap", "A", 3, 1, ("roof",), make_ridge_cap),
    Rule("D12", "tower cap", "B", 4, 2, ("tower",), make_tower_cap, kinds=("pyramid", "pole")),
    Rule("D7", "pilasters", "B", 3, 2, ("wall",), make_pilasters),
    Rule("D9", "windows", "B", 3, 4, ("building",), make_windows, kinds=("window",)),
    Rule("D11", "corbels", "B", 2, 4, ("tower",), make_corbels, kinds=("uslope",)),
    Rule("D10", "bell-cast eaves", "B", 2, 4, ("roof",), make_skirt,
         kinds=("wedgetip", "wedgetipouter")),
    Rule("D16", "round tower", "C", 6, 1, ("tower",), make_round, kinds=("roundcorner",)),
    Rule("D30", "chimney", "E", 2, 1, ("roof",), make_chimney),
    Rule("D5", "door frame and stoop", "A", 4, 2, ("opening",), None, source="houses.py"),
]
RULE = {r.id: r for r in RULES}
VERBS = {"D1": "roof", "D2": "trim", "D3": "plinth", "D4": "posts", "D5": "frame", "D6": "ridge"}
ABSORBED = [
    ("R3 rails", "beauty.dress", ("dress.rail",)),
    ("R4 pillars (D7 on long walls)", "beauty.dress", ("dress.pillar",)),
    ("R6 plinth / landmark", "beauty.dress", ("dress.plinth", "dress.landmark")),
    ("R7 crenels (D15)", "beauty.dress", ("dress.crenel",)),
    ("R10 keels", "beauty.dress", ("dress.keel",)),
    ("parapets", "beauty.dress", ("dress.parapet",)),
    ("K1 stairs", "kitpass", ("dress.stairs",)),
    ("K2 fences", "kitpass", ("dress.fence",)),
    ("K3/K4 colonnades, arcades, gates (D19)", "kitpass",
     ("dress.column", "dress.arcade", "dress.gate")),
    ("K5 slabs (D21)", "kitpass", ("dress.rug", "dress.slabs")),
    ("K6/K7 landmark octagon and dais (D17)", "kitpass", ("dress.prism", "dress.dais")),
    ("C1 roofs (D12)", "scenery", ("dress.roof",)),
    ("C3 backdrop", "scenery", ("dress.backdrop",)),
    ("R13 gradient walls (D23)", "scenery", (" base", " cap")),
]
KIND_RULES = {
    "box": "D2-D8 (caps, plinths, posts, pilasters, courses)",
    "ramp": "K1 / families (flights, slopes)", "stairs": "K1 stairs",
    "outer": "K7 dais corners / landform auto-shape", "inner": "landform auto-shape (valleys)",
    "outerstairs": "K7 corner stairs (dais)", "innerstairs": "K7 corner stairs (inner dais)",
    "rail": "R3 rails, K2 fences", "pillar": "R4 pillars, K3 colonnades",
    "arch": "K4 arcades and gates (D19)", "prism": "K6 octagon (D17 chamfer)",
    "curve": "race (round corners)", "bank": "race (banked corners)",
    "arcwall": "race (curved walls)", "ridge": "D1/D6 and the houses' roofs",
    "pyramid": "D12 tower cap, C1 roofs", "roundcorner": "D16 round tower",
    "ice": "the ice worlds' floors", "lava": "the lava worlds' lakes",
    "water": "lakes and rivers", "uslope": "D11 corbels",
    "uouter": "D11 corbels (corner)", "uinner": "D11 corbels (inner corner)",
    "wedgetip": "D10 bell-cast eaves", "wedgetipouter": "D10 bell-cast eaves (hip corner)",
    "wedgetipinner": "D10 bell-cast eaves (valley)", "pole": "D12 finial",
    "doorway": "D5 door frame", "window": "D9 windows",
}
FLUSHABLE = ("D2", "D3", "D4")
ROUND_THEMES = ("castle", "fantasy", "fairy", "ruins", "desert", "garden")
OFF_FAMILIES = ("race",)
def _defaulted(brief):
    return "budget" in (getattr(brief, "defaulted", None) or ())
def allowance(brief, arena):
    return int(brief.get("budget") or arena.get("budget") or 120)
def family_ceiling(brief, arena):
    from . import budget as budgetmod
    try:
        return int(budgetmod.ceiling(brief.get("family"), brief.get("modes")
                                     or arena.get("onlyFor") or ()))
    except Exception:
        return None
def used_of(arena):
    return (len(arena.get("pieces") or []) + len(arena.get("markers") or [])
            + len(arena.get("objects") or []) + len(arena.get("movers") or []))
def wanted(brief):
    f = brief.get("features") or {}
    return "detail" not in (f.get("avoid") or ()) and brief.get("style") != "plain"
def _ok_for_family(rule, site, family):
    if site.backdrop:
        if not any("tiles" in _words(q) for q in site.parts):
            return False
        return rule.id not in ("D3",)
    if family in TIGHT and rule.id in ("D3", "D9", "D7", "D11"):
        return False
    if family == "hide" and rule.id in ("D3",):
        return False
    if site.house and rule.id in HOUSE_DONE:
        return False
    if site.root == "house" and site.cls == "roof" and rule.id in ("D10", "D30"):
        return False
    return True
def run(arena, brief, meta=None, theme=None):
    meta = meta if meta is not None else {}
    family = brief.get("family")
    theme = theme or brief.get("theme") or "castle"
    pieces = arena["pieces"]
    before = len(pieces)
    allow = allowance(brief, arena)
    used = used_of(arena)
    dressed = sum(absorbed_counts(pieces).values())
    cap = int(max(0, min(SHARE * allow - dressed, KEEP * allow - used - RESERVE)))
    report = {"allowance": allow, "ceiling": family_ceiling(brief, arena), "used_before": used, "dress_before": dressed, "cap": cap,
              "pieces": 0, "by_rule": {}, "skipped": {}}
    if not wanted(brief):
        report["off"] = "the wish says plain (avoid: detail)"
        return report
    if family in OFF_FAMILIES:
        report["off"] = "a %s map's pieces are its play" % family
        return report
    grammar = any(str(p.get("tag", "")).startswith("house.") for p in pieces)
    houses = sum(1 for p in pieces if str(p.get("tag", "")).startswith("house."))
    P = Pass(arena, brief, meta, theme, family, cap, grammar)
    sites = recognise(pieces)
    report["sites"] = {}
    for s in sites:
        report["sites"][s.cls] = report["sites"].get(s.cls, 0) + 1
    esc0 = _escapes(arena)
    cands = []
    for k, rule in enumerate(RULES):
        if rule.make is None:
            continue
        if rule.id == "D16" and theme not in ROUND_THEMES:
            continue
        for s in sites:
            if s.cls not in rule.classes or not _ok_for_family(rule, s, family):
                continue
            score = rule.gain * s.important / float(rule.cost)
            cands.append((-score, k, s.signature(), id(s), rule, s))
    cands.sort(key=lambda c: (c[0], c[1], c[2]))
    groups = []
    for c in cands:
        key = (c[0], c[1], c[2])
        if groups and groups[-1][0] == key:
            groups[-1][1].append(c)
        else:
            groups.append((key, [c]))
    spent = 0
    log = []
    swapped = set()
    for _, members in groups:
        rule = members[0][4]
        built = _build_group(P, rule, members, swapped)
        P.pending = []
        if not built:
            continue
        cost = sum(_cost(new, how) for _, new, _, how, _ in built)
        if spent + cost > cap:
            P.skip(rule.id, "budget")
            continue
        flat = [q for _, new, _, _, _ in built for q in new]
        if not P.keys_ok(flat):
            P.skip(rule.id, "keys")
            continue
        entry = {"rule": rule.id, "added": [], "mods": [], "removed": [], "cost": cost}
        for s, new, mods, how, hosts in built:
            for q in new:
                if not _detail(q):
                    continue
                if s.backdrop:
                    q["tag"] = "dress.backdrop." + q["tag"]
                    q["detail_part"] = True
                elif s.float_word and s.float_word not in _words(q):
                    q["tag"] = "%s.%s" % (q["tag"], s.float_word)
            P.apply(entry, s, new, mods, how, hosts)
            _after(s, rule.id, new, how)
            if how == "swap":
                swapped.add(id(s))
        log.append(entry)
        spent += cost
    taken = 0
    while log and _escapes(arena) > esc0:
        P.undo(log.pop())
        taken += 1
    if taken:
        report["g2_taken_back"] = taken
    P.by_rule = {}
    for e in log:
        P.by_rule[e["rule"]] = P.by_rule.get(e["rule"], 0) + len(e["added"])
        grown = sum(1 for _, _, how in e["mods"] if how == "grow")
        if grown:
            P.by_rule[e["rule"] + " (grown)"] = P.by_rule.get(e["rule"] + " (grown)", 0) + grown
    n = len(P.added)
    after = len(arena["pieces"])
    if _defaulted(brief) and arena.get("budget") is not None:
        arena["budget"] = max(arena["budget"], min(allow, used_of(arena)))
    report.update({
        "pieces": n, "pieces_net": after - before, "by_rule": dict(sorted(P.by_rule.items())),
        "skipped": dict(sorted(P.skipped.items())), "keys": len(P.keys),
        "share": round(n / float(max(1, after)), 3),
        "share_of_allowance": round(n / float(max(1, allow)), 3),
        "houses": {"pieces": houses, "share": round(houses / float(max(1, after)), 3)},
        "absorbed": absorbed_counts(arena["pieces"]),
    })
    return report
def _build_group(P, rule, members, swapped):
    flushable = rule.id in FLUSHABLE
    for flush in ((False, True) if flushable else (False,)):
        built, pending, retry = [], [], False
        P.pending = pending
        for _, _, _, _, _, s in members:
            if id(s) in swapped:
                continue
            got = rule.make(P, s, flush=True) if flush else rule.make(P, s)
            if isinstance(got, tuple) and flushable and not flush and got[2] != "flush":
                hosts0 = list(s.parts) + list(got[3] if len(got) > 3 else [])
                if P.check(rule.id, got[0], hosts0, s.box()):
                    if any(q is P.blame for q in pending):
                        retry = True
                        break
                    alt = rule.make(P, s, flush=True)
                    if isinstance(alt, tuple):
                        got = alt
            if got is None:
                P.skip(rule.id, "no pattern")
                continue
            if isinstance(got, str):
                P.skip(rule.id, got)
                continue
            new, mods, how = got[0], got[1], got[2]
            hosts = list(s.parts) + list(got[3] if len(got) > 3 else [])
            host_box = s.box() if s.cls != "roof" else None
            why = P.check(rule.id, new, hosts, host_box)
            if not why and how not in ("grow", "swap"):
                trials = [dict(p, _course=True, **ch) for p, ch in mods]
                why = P.check(rule.id, trials, hosts, host_box) if trials else None
            if why:
                P.skip(rule.id, why)
                twin = next((k for k, b in enumerate(built)
                             if any(q is P.blame for q in b[1])), None)
                if twin is not None:
                    gone = built.pop(twin)
                    ids = set(id(q) for q in gone[1])
                    pending[:] = [q for q in pending if id(q) not in ids]
                    P.skip(rule.id, "its symmetric twin could not be laid")
                continue
            pending += new
            built.append((s, new, mods, how, hosts))
        P.pending = []
        if not retry:
            return built
    return []
def _cost(new, how):
    if how in ("grow",):
        return 0
    if how == "swap":
        return len(new) - 1
    return len(new)
def _after(s, rid, new, how):
    s.done.add(rid)
    if how == "flush":
        return
    if rid == "D2":
        s.bands.append((s.y1 - CAP_H, s.y1))
    elif rid == "D3":
        s.bands.append((s.y0, s.y0 + PLINTH_H))
    elif rid == "D8":
        b = new[0]
        s.bands.append((b["y"], b["y"] + b["h"]))
        s.parts.append(new[1])
        s.parts.sort(key=lambda q: q["y"])
def _escapes(arena):
    try:
        from . import escape
        return len(escape.escape_faults(arena))
    except Exception:
        return 0
def absorbed_counts(pieces):
    out = {}
    for name, source, tags in ABSORBED:
        n = 0
        for p in pieces:
            t = str(p.get("tag", ""))
            if any(t.startswith(x) if x.startswith("dress.") else t.endswith(x) for x in tags):
                n += 1
        if n:
            out[name] = n
    return out
def implicated(faults, pieces):
    m = _m()
    names = set(m.piece_name(p) for p in pieces
                if _detail(p) or p.get("detail_part") or "detail_was" in p)
    for f in faults:
        if "objects against a budget" in f or any(n in f for n in names):
            return True
    return False
def strip(pieces):
    out = []
    for p in pieces:
        if "detail_swap" in p:
            q = dict(p["detail_swap"])
            q["model"] = _m().model_name(q)
            out.append(q)
            continue
        if _detail(p) or p.get("detail_part"):
            continue
        if "detail_was" in p:
            y, h, x, z, w, d = p["detail_was"]
            p = dict(p, y=y, h=h, x=x, z=z, w=w, d=d)
            p.pop("detail_was", None)
            p.pop("model", None)
            p["model"] = _m().model_name(p)
        out.append(p)
    return out
def guard_faults(arena):
    from . import guards, solids
    pieces = arena["pieces"]
    det = [p for p in pieces if _detail(p) or p.get("detail_part")]
    if not det:
        return 0
    ids = set(id(p) for p in det)
    n = len(guards.lips(pieces, det))
    for i, j, _, _ in solids.overlaps(pieces):
        if id(pieces[i]) in ids or id(pieces[j]) in ids:
            n += 1
    for d in det:
        b = aabb(d)
        for o in pieces:
            if o is d or o.get("kind") == "water" or o.get("tex") == "invisible":
                continue
            a = aabb(o)
            if not _plan_meet(a, b):
                continue
            for gp in (a[2] - b[3], b[2] - a[3]):
                if TOL < gp < SLOT:
                    n += 1
    for g in guards.floating(arena):
        n += sum(1 for p in g if id(p) in ids)
    n += sum(1 for p in guards.unsupported(arena) if id(p) in ids)
    return n
