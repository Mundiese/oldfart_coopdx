from .. import coursecheck, coursemoves as cm, kit, movement, v1
from ..paths import common, shape
from ..paths.road import yaw_of
from . import course_beats as B
FAMILY = "course"
DEFAULTS = {"symmetry": "none", "verticality": "high", "edge": "rails"}
RUN = 960.0
JUMP_S = 0.5
W = B.W
LIP = B.LIP
SAFE_DROP = B.SAFE_DROP
REST = 2000
START = 2800
GOAL = 2400
CLEAR = -(-(movement.LONG_JUMP + 1) // 200) * 200
REST_EVERY = 13.0
REST_STEP = 50
LOG_RUN_W = 2400
LOG_RUN_L = 3200
LOG_RUNS = 2
def _grid(v):
    return int(v) // 100 * 100
GAP_EASY, GAP_MEDIUM, GAP_HARD, GAP_EXPERT = (_grid(g) for g in movement.DESIGN_GAPS)
GAP_UP_EASY = _grid(movement.GAPS_UP_200["easy"])
RISE_EASY, RISE_MEDIUM, RISE_HARD = movement.DESIGN_RISES
DEPTH_RUN, DEPTH_LONG = movement.DESIGN_DEPTHS
COURSE_S = {"tiny": 45, "small": 55, "medium": 70, "large": 90, "huge": 110}
MAX_CLASS = {"easy": 2, "normal": 3, "hard": 3, "expert": 4, "pro": 5}
land_for = B.land_for
CONCEPTS = {
    "gaps": [("gap", {"gap": GAP_EASY}, 1), ("gap", {"gap": GAP_UP_EASY, "up": RISE_EASY}, 1),
             ("gap", {"gap": GAP_MEDIUM, "drop": 400}, 1), ("gap", {"gap": GAP_HARD}, 3)],
    "climb": [("ledge", {"rise": RISE_EASY}, 1), ("stairs", {"steps": 3}, 2),
              ("ledge", {"rise": RISE_MEDIUM}, 2), ("ledge", {"rise": RISE_HARD}, 3)],
}
LENGTHS = {"short": (30, 20, 45), "medium": (90, 60, 120), "long": (240, 180, 300),
           "marathon": (450, 360, 600)}
LENGTH_NAMES = ("auto",) + tuple(LENGTHS)
FOCUSES = ("mixed", "jumps", "climb", "balance", "moving")
FOCUS_CONCEPTS = {"jumps": ("gaps", "stones", "pillars"), "climb": ("climb", "kicks"),
                  "balance": ("beams", "stones", "pillars"), "moving": ("movers", "gaps")}
SECTION_S = 22.0
STEP_NAMES = ("teach", "develop", "twist", "conclude")
STEP_EXTRA = (2, 1, 1, 0)
ROLE_EXTRA = {"warmup": 2, "build": 1, "peak": 0, "breather": 3, "finale": 0}
ROLE_POOL = {
    "warmup": ("gaps", "stones", "beams", "climb"),
    "build": ("gaps", "stones", "climb", "beams", "pillars", "movers", "kicks"),
    "peak": ("kicks", "pillars", "gaps", "movers", "climb"),
    "breather": ("movers", "beams", "slide"),
}
def options(brief):
    raw = {}
    try:
        raw = brief["course"] or {}
    except (KeyError, TypeError):
        raw = {}
    moves = dict(raw.get("moves") or {})
    return {"length": raw.get("length") or "auto", "moves": moves,
            "checkpoints": raw.get("checkpoints"), "sections": raw.get("sections"),
            "focus": raw.get("focus") or "mixed"}
def curve(n):
    if n <= 1:
        return ["finale"]
    if n == 2:
        return ["warmup", "finale"]
    if n == 3:
        return ["warmup", "peak", "finale"]
    mid = []
    cycle = ("build", "peak", "breather")
    for k in range(n - 2):
        mid.append(cycle[k % 3])
    if mid[-1] == "breather" and n > 4:
        mid[-1] = "build"
    return ["warmup"] + mid + ["finale"]
class Frame:
    def __init__(self, x, z, d, h):
        self.x, self.z, self.d, self.h = x, z, d, h
    @property
    def o(self):
        return shape.right(self.d)
    def rect(self, a0, a1, c0, c1):
        xs = [self.x + self.d[0] * a + self.o[0] * c for a in (a0, a1) for c in (c0, c1)]
        zs = [self.z + self.d[1] * a + self.o[1] * c for a in (a0, a1) for c in (c0, c1)]
        return (min(xs), max(xs), min(zs), max(zs))
    def point(self, a, c=0):
        return (self.x + self.d[0] * a + self.o[0] * c, self.z + self.d[1] * a + self.o[1] * c)
Plan = B.Plan
def _safety(p, ctx, a_end, low=None):
    return B.net(p, ctx, a_end, low)
class Course:
    def __init__(self, half, half_z=None):
        self.half = half
        self.hx = half
        self.hz = half if half_z is None else half_z
        self.rects = []
        self.pieces = []
        self.log = []
        self.owner = 0
        self.route = []
        self.skips = []
        self.movers = []
        self.objects = []
        self.wires = []
        self.checkpoints = []
        self.sections = []
        self.start = (0, 0)
        self.now = None
        self.role = "build"
        self.turn_ahead = TURN_AHEAD
        self.rest = REST
        self.goal = GOAL
        self.max_layers = MAX_LAYERS
    def fits(self, rects, ahead=1):
        me = self.owner + ahead
        for item in rects:
            r, kind, y0, y1 = _item(item)
            if max(abs(r[0]), abs(r[1])) > self.hx or max(abs(r[2]), abs(r[3])) > self.hz:
                return False
            for rr, own, okind, oy0, oy1, t in self.rects:
                diff = me - own
                if diff <= 0 or (diff == 1 and "mover" not in (kind, okind)):
                    continue
                if y0 is not None and oy0 is not None and \
                        (y0 >= oy1 + LAYER_CLEAR or oy0 >= y1 + LAYER_CLEAR):
                    continue
                if self.now is None or t is None:
                    far = diff >= 4
                else:
                    far = diff >= 3 and self.now - t >= SKIP_S
                margin = CLEAR if (far and kind == "path" and okind == "path") else \
                    (0 if diff == 1 else 200)
                if r[0] < rr[1] + margin and rr[0] < r[1] + margin and \
                        r[2] < rr[3] + margin and rr[2] < r[3] + margin:
                    return False
        return True
    def add(self, rects, pieces):
        self.owner += 1
        for item in rects:
            r, kind, y0, y1 = _item(item)
            self.rects.append((r, self.owner, kind, y0, y1, self.now))
        self.pieces += pieces
LAYER_CLEAR = 1800
SKIP_S = 6.0
LAYER = 3000
MAX_LAYERS = 6
SPAN = 1200
def _item(item):
    if not isinstance(item[0], tuple):
        return item, "path", None, None
    if len(item) == 4:
        return item[0], item[1], item[2], item[3]
    return item[0], item[1], None, None
def _at(rect, h, kind="path"):
    return (rect, kind, h - SPAN, h + SPAN)
def _touching(a, b):
    return a[0] <= b[1] and b[0] <= a[1] and a[2] <= b[3] and b[2] <= a[3]
def target_seconds(brief, opts):
    if opts["length"] in LENGTHS:
        return LENGTHS[opts["length"]]
    t = COURSE_S[common.size_name(brief["size"]) if isinstance(brief["size"], str)
                 else "medium"]
    t *= {"slow": 1.15, "normal": 1.0, "fast": 0.85}.get(brief["pace"], 1.0)
    t = max(45, min(120, t))
    return t, 40, 130
def bounded(brief, info):
    s = brief["size"]
    return isinstance(s, dict) and "w" in s and "d" in s
MIN_SIDE = 12000
def bounds(brief, info):
    half = min(info["half"], v1.arenas_module().BOUND) - 600
    s = brief["size"]
    if isinstance(s, dict) and "w" in s and "d" in s:
        return (min(half, max(MIN_SIDE, s["w"]) / 2.0),
                min(half, max(MIN_SIDE, s["d"]) / 2.0))
    return half, half
def beat_class(p):
    c = 1
    for m in p.moves:
        k, mv = m["kind"], m.get("move")
        if k == "gap":
            if mv in ("jump", "standjump"):
                v = 1 if m["gap"] <= GAP_EASY and m.get("rise", 0) <= RISE_EASY else 2
            else:
                v = {"longjump": 3, "dive": 4}.get(mv, 3)
        elif k == "climb":
            v = {"jump": 1 if m["rise"] <= RISE_EASY else 2, "double": 3, "sideflip": 3,
                 "triple": 4}.get(mv, 2)
        elif k in ("shaft", "pound"):
            v = 4
        elif k in ("kickup", "blj"):
            v = 5
        elif k == "hop":
            v = 3
        elif k == "beam":
            v = 1 if m.get("width", 400) >= 400 else 2
        else:
            v = 1
        c = max(c, v)
    return c
def plan_seconds(p, tier):
    s = p.walk / RUN
    for m in p.moves:
        s += coursecheck.judge(m, tier)["seconds"]
    return s
def pick_concept(role, ctx, used, focus, r, budget_ok):
    pool = list(ROLE_POOL.get(role, ROLE_POOL["build"]))
    avail = []
    for k in pool:
        if k == "kicks" and not (ctx.has("wallkick") and ctx.tier.chimney):
            continue
        if k == "pillars" and ctx.tier.rank < 2:
            continue
        if k == "movers" and (not ctx.has("ride") or ctx.movers_left < 4 or not budget_ok
                              or "movers" in ctx.forge_off):
            continue
        avail.append(k)
    if focus in FOCUS_CONCEPTS:
        narrowed = [k for k in avail if k in FOCUS_CONCEPTS[focus] or k == "slide"]
        if role != "breather":
            narrowed = [k for k in narrowed if k != "slide"]
        avail = narrowed or [k for k in FOCUS_CONCEPTS[focus]
                             if k in ("gaps", "stones", "climb", "beams")] or avail
    if not avail:
        avail = ["gaps"]
    fresh = [k for k in avail if k not in used]
    last = used[-1] if used else None
    choices = [k for k in (fresh or avail) if k != last] or avail
    if role in ("peak",) and ctx.tier.rank >= 2:
        sig = [k for k in ("kicks", "pillars", "movers") if k in choices]
        if sig and r.random() < 0.75:
            return r.choice(sig)
    return r.choice(choices)
def jitter(maker, kw, r):
    if maker is B.beat_stones:
        kw["steps"] = max(3, kw.get("steps", 3) + r.choice((-1, 0, 0, 1)))
    elif maker is B.beat_beams:
        kw["length"] = kw.get("length", 1600) + r.choice((-400, 0, 0, 400))
    elif maker is B.beat_block_stairs:
        kw["steps"] = max(2, kw.get("steps", 3) + r.choice((-1, 0, 1)))
    return kw
def concept_beat(name, step, f, ctx, tex, label, r, c=None):
    if c is not None:
        first = None
        for side in (1, -1):
            ctx.net_side = side
            p = concept_beat(name, step, f, ctx, tex, label, r)
            if p is None:
                return None
            if placeable(c, p):
                return p
            first = first or p
            if not p.safe:
                break
        ctx.net_side = 1
        return first
    t = ctx.tier
    tries = []
    if name == "gaps":
        tries = [
            [(B.beat_gap, {"move": "jump"})],
            [(B.beat_gap, {"move": "jump", "rise": RISE_EASY})],
            [(B.beat_gap, {"move": "longjump", "rise": -400, "lip": 800}),
             (B.beat_gap, {"move": "jump", "rise": -400})],
            [(B.beat_gap, {"move": "longjump", "lip": 800}),
             (B.beat_gap, {"move": "dive", "rise": -200, "lip": 800}),
             (B.beat_gap, {"move": "jump"})],
        ][step]
        if step == 3 and ctx.has("dive") and r.random() < 0.4:
            tries = [(B.beat_gap, {"move": "dive", "rise": -200, "lip": 800})] + tries
    elif name == "stones":
        s = B.STONE[t.name]
        tries = [
            [(B.beat_stones, {"steps": 3, "size": max(s, 300)})],
            [(B.beat_stones, {"steps": 4, "wobble": 100})],
            [(B.beat_stones, {"steps": 3, "rise": 100})],
            [(B.beat_stones, {"steps": 5, "wobble": 100, "size": s,
                              "tall": t.rank >= 2})],
        ][step]
    elif name == "climb":
        last = [(B.beat_kickup, {})] if ctx.has("kickup") else []
        last += [(B.beat_ledge, {"move": "triple"}), (B.beat_ledge, {"move": "sideflip"}),
                 (B.beat_ledge, {"move": "double"}), (B.beat_ledge, {"move": "jump"})]
        tries = [
            [(B.beat_ledge, {"move": "jump"})],
            [(B.beat_block_stairs, {"steps": 3}), (B.beat_ledge, {"move": "jump"})],
            [(B.beat_ledge, {"move": "double"}), (B.beat_ledge, {"move": "sideflip"}),
             (B.beat_ledge, {"move": "jump"})],
            last,
        ][step]
    elif name == "beams":
        w0, w1 = B.BEAM[t.name]
        tries = [
            [(B.beat_beams, {"length": 1600, "width": w0})],
            [(B.beat_beams, {"length": 2000, "width": w1})],
            [(B.beat_beams, {"length": 1600, "width": w1, "gap_after": True})],
            [(B.beat_beams, {"length": 2400, "width": w1})],
        ][step]
    elif name == "pillars":
        tries = [
            [(B.beat_stones, {"steps": 3, "size": 400, "tall": True})],
            [(B.beat_stones, {"steps": 4, "size": 300, "wobble": 100, "tall": True})],
            [(B.beat_pound, {}), (B.beat_stones, {"steps": 3, "size": 200, "tall": True})],
            [(B.beat_stones, {"steps": 4, "size": 200, "rise": 100, "tall": True})],
        ][step]
    elif name == "kicks":
        hi = {"hard": (700, 1000), "expert": (1000, 1400), "pro": (1400, 2000)}.get(
            t.name, (700, 1000))
        tries = [
            [(B.beat_shaft, {"height": hi[0]})],
            [(B.beat_shaft, {"height": (hi[0] + hi[1]) // 2 // 100 * 100})],
            [(B.beat_kickup, {}), (B.beat_shaft, {"height": hi[0]})],
            [(B.beat_shaft, {"height": hi[1]})],
        ][step]
        tries += [(B.beat_ledge, {"move": "jump"})]
    elif name == "movers":
        if t.rank >= 2:
            tries = [
                [(B.beat_ferry, {})],
                [(B.beat_door, {}), (B.beat_lift, {})],
                [(B.beat_hop, {}), (B.beat_ferry, {})],
                [(B.beat_sinkers, {}), (B.beat_hop, {}), (B.beat_ferry, {})],
            ][step]
        else:
            tries = [
                [(B.beat_ferry, {})],
                [(B.beat_lift, {}), (B.beat_ferry, {})],
                [(B.beat_door, {}), (B.beat_ferry, {})],
                [(B.beat_ferry, {"span": 2400})],
            ][step]
        tries += [(B.beat_gap, {"move": "jump"})]
    elif name == "slide":
        tries = [[(B.beat_slide, {})], [(B.beat_beams, {"length": 1600, "width": 400})],
                 [(B.beat_ferry, {}), (B.beat_gap, {"move": "jump"})],
                 [(B.beat_beams, {"length": 2000, "width": 400})]][step]
    elif name == "fork":
        tries = [(B.beat_fork, {}), (B.beat_gap, {"move": "jump"})]
    elif name == "blj":
        tries = [(B.beat_blj, {}), (B.beat_gap, {"move": "jump"})]
    tries = [(mk, jitter(mk, dict(kw), r)) for mk, kw in tries]
    for maker, kw in tries + [(B.beat_gap, {"move": "jump"}),
                              (B.beat_gap, {"move": "jump", "need": 12})]:
        p = maker(f, ctx, tex, label, **kw)
        if p is not None:
            p.cls = beat_class(p)
            return p
    return None
def lay(brief, r, pal, notes):
    want, avoid = common.want_avoid(brief)
    tier = cm.tier_of(brief)
    opts = options(brief)
    target, least, most = target_seconds(brief, opts)
    info = common.level_info(brief["level"])
    base = 0 if info["floor"] is None else 400
    hx, hz = bounds(brief, info)
    if bounded(brief, info) and min(brief["size"]["w"], brief["size"]["d"]) < MIN_SIDE:
        notes.append("an obstacle course needs at least %d x %d (%d x %d m): the footprint "
                     "was widened to %d x %d" % (MIN_SIDE, MIN_SIDE, MIN_SIDE // 100,
                                                 MIN_SIDE // 100, 2 * hx, 2 * hz))
    from .. import budget as budgetmod
    top = budgetmod.ceiling("course", brief["modes"])
    budget = min(top, max(150, brief["budget"])) if "budget" in brief.defaulted \
        else brief["budget"]
    if opts["length"] in ("long", "marathon") and "budget" in brief.defaulted:
        budget = top
    pal = dict(pal)
    pal["_ground"] = info["floor"]
    moves = cm.allowed(tier, opts["moves"])
    forge_off = set(brief["forge_off"] or [])
    if forge_off & {"movers", "all"}:
        moves.discard("ride")
    if "lava" in avoid:
        lava_ok = False
    else:
        lava_ok = True
    ctx = B.Ctx(tier, pal, r, moves, ground=info["floor"], lava_ok=lava_ok,
                modes=("line", "flood"), forge_off=forge_off)
    c = Course(hx, hz)
    dirs = list(shape.DIRS)
    if abs(hx - hz) > 1:
        dirs = [d for d in dirs if (d[0] != 0) == (hx > hz)]
    d = r.choice(dirs)
    sp = START // 2
    sx = sz = 0
    if bounded(brief, info):
        o = shape.right(d)
        along = hx if d[0] else hz
        across = hz if d[0] else hx
        back = max(0, along - sp - 100)
        left = max(0, across - sp - 100)
        sx = int(-d[0] * back - o[0] * left)
        sz = int(-d[1] * back - o[1] * left)
    c.start = (sx, sz)
    c.now = 0.0
    c.turn_ahead = min(TURN_AHEAD, max(2500, int(min(hx, hz) * 2 // 3)))
    if min(hx, hz) < 6000:
        c.goal = 1600
        c.max_layers = 12
    start = kit.kind("box").make(pal["floor"], sx - sp, sx + sp, base - 200, base, sz - sp,
                                 sz + sp, None, "start")
    c.add([((sx - sp, sx + sp, sz - sp, sz + sp), "path", base - 200, base)], [start])
    f = Frame(sx + d[0] * sp, sz + d[1] * sp, d, base)
    clock = "all" not in forge_off
    if clock:
        bx, bz = sx + d[0] * (sp - 300) + shape.right(d)[0] * 900, sz + d[1] * (sp - 300) + \
            shape.right(d)[1] * 900
        c.objects.append({"key": "lgbutton", "x": int(bx), "y": base, "z": int(bz), "yaw": 0,
                          "link": 1, "what": "start the clock"})
        c.wires.append({"on": "pressed", "src": 1, "act": "timer_start", "dst": 0})
    seconds = START / 2 / RUN
    since_rest = 0.0
    since_cp = 0.0
    cp_every = float(opts["checkpoints"] or tier.checkpoint_s)
    from .. import gameplay
    logs_left = LOG_RUNS if "log_gauntlet" in gameplay.asked(brief) else 0
    used = []
    def log_run(f):
        nonlocal logs_left, seconds, since_rest
        if logs_left <= 0 or len(c.pieces) + 4 > budget:
            return None
        plan = beat_log_run(f, pal, None)
        if not placeable(c, plan):
            return None
        c.add(plan.rects(), plan.pieces("logs%d" % (LOG_RUNS - logs_left + 1)))
        c.log.append((plan.name, plan.cls, round(plan_seconds(plan, tier), 1), plan.safe))
        logs_left -= 1
        seconds += plan_seconds(plan, tier)
        since_rest += plan_seconds(plan, tier)
        return Frame(*f.point(plan.length), d=f.d, h=plan.h_out)
    f = log_run(f) or f
    ascents = [0]
    def ascend(f):
        nonlocal seconds, since_rest, since_cp
        c.now = seconds
        if ascents[0] >= c.max_layers or len(c.pieces) + 6 > budget:
            return None
        ctx.movers_left = B.MOVERS_MAX - len(c.movers)
        plan = B.beat_tower(f, ctx, accents[0], "ascend", rise=LAYER, pad=c.rest)
        if plan is not None and c.fits(plan.rects()):
            top = plan.h_out
            cx, cz = f.point(plan.pad_centre)
            rp = c.rest // 2
            best = None
            keep = (len(c.rects), len(c.pieces), c.owner)
            c.add(plan.rects(), plan.pieces("beat%d" % c.owner))
            for d2 in shape.DIRS:
                nf = Frame(cx + d2[0] * rp, cz + d2[1] * rp, d2, top)
                run = 0
                while run < 20000 and c.fits([_at(nf.rect(0, run + 2000, -W // 2, W // 2),
                                                  top)], 1):
                    run += 2000
                if run >= 2000 and (best is None or run > best[0]):
                    best = (run, nf)
            if best is None:
                del c.rects[keep[0]:]
                del c.pieces[keep[1]:]
                c.owner = keep[2]
            else:
                ps = plan_seconds(plan, tier)
                _record(c, plan, seconds, since_cp, ps)
                c.log.append((plan.name, plan.cls, round(ps, 1), plan.safe))
                seconds += ps
                since_rest = 0.0
                since_cp += ps
                ascents[0] += 1
                nf = best[1]
                nf.pad = True
                return nf
        for fa in (f,):
            plan = B.beat_ascend(fa, ctx, accents[0], "ascend", rise=LAYER)
            if plan is None or not placeable(c, plan):
                continue
            ps = plan_seconds(plan, tier)
            c.add(plan.rects(), plan.pieces("beat%d" % c.owner))
            _record(c, plan, seconds, since_cp, ps)
            c.log.append((plan.name, plan.cls, round(ps, 1), plan.safe))
            seconds += ps
            since_rest = 0.0
            since_cp += ps
            ascents[0] += 1
            return Frame(*fa.point(plan.length, plan.exit_c), d=fa.d, h=plan.h_out)
        return None
    accents = list(pal["accents"])
    def rest_at(f, **kw):
        nonlocal seconds, since_rest, since_cp
        c.now = seconds
        f2 = _rest_turn(c, f, pal, r, **kw)
        if f2 is None:
            return None
        seconds += c.rest / RUN
        since_cp += c.rest / RUN
        since_rest = 0.0
        if since_cp >= cp_every:
            _checkpoint(c, f2, pal, seconds)
            since_cp = 0.0
        return f2
    n = opts["sections"] or max(2, int(round(target / SECTION_S)))
    roles = curve(int(n))
    per_section = max(8.0, (target - seconds) / float(len(roles)))
    stop = False
    fork_done = False
    blj_done = "blj" not in moves
    section_i = 0
    while section_i < len(roles) and not stop:
        role = roles[section_i]
        section_i += 1
        if role == "finale" and seconds < target - per_section * 1.2 and \
                len(roles) < 40 and not opts["sections"]:
            k = len(roles)
            roles.insert(section_i - 1, ("build", "peak", "breather")[k % 3])
            role = roles[section_i - 1]
        elif role != "finale" and section_i > 1 and not opts["sections"] and \
                seconds + 1.5 * per_section >= target:
            del roles[section_i - 1:]
            roles.append("finale")
            role = "finale"
        ctx.role = role
        c.role = role
        ctx.nets = {"all": True, "not_peak": role not in ("peak", "finale"),
                    "breather": role in ("warmup", "breather"),
                    "none": False}[tier.nets]
        ctx.lava = (not ctx.nets) and lava_ok and (
            brief["theme"] == "lava" or (role in ("peak", "finale") and r.random() < 0.6))
        budget_ok = len(c.pieces) + 20 < budget
        if role == "finale":
            pool = [k for k in used if k != "slide"] or ["gaps"]
            concept = "finale"
            beats = []
            for k in range(4):
                cname = pool[(len(pool) - 1 - k) % len(pool)]
                beats.append((cname, 3 if k % 2 == 0 else 2))
        else:
            concept = pick_concept(role, ctx, used, opts["focus"], r, budget_ok)
            if role == "warmup" and section_i == 1:
                if "stairs" in want or (brief["verticality"] == "high" and r.random() < 0.6):
                    if concept != "climb" and r.random() < 0.7:
                        concept = "climb"
            beats = [(concept, k) for k in range(4)]
            if role == "breather":
                beats = [(concept, k) for k in range(2)] + [(concept, 3)]
            if role == "peak" and not fork_done and tier.rank >= 3 and "longjump" in moves:
                beats[2] = ("fork", 0)
                fork_done = True
            elif role == "build" and not blj_done:
                beats[1] = ("blj", 0)
                blj_done = True
        used.append(concept)
        c.sections.append((role, concept))
        tex = accents[(len(used) - 1) % len(accents)]
        section_s = 0.0
        bi = 0
        while bi < len(beats):
            cname, step = beats[bi]
            bi += 1
            c.now = seconds
            ctx.need = min(12, tier.leeway + ROLE_EXTRA.get(role, 0) + r.choice((0, 0, 1)) +
                           (STEP_EXTRA[step] if role != "finale" else 0))
            label = "%s.%s" % (cname if concept != "finale" else "finale." + cname,
                               STEP_NAMES[step])
            ctx.movers_left = B.MOVERS_MAX - len(c.movers)
            plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
            if plan is None:
                continue
            ps = plan_seconds(plan, tier)
            if since_rest > 4 and since_rest + ps > REST_EVERY and len(c.pieces) + 6 < budget:
                short = straight_room(c, f) < plan.length + c.turn_ahead
                f2 = _rest_turn(c, f, pal, r, turn=short or r.random() < 0.3, goal_after=True,
                                force_turn=short)
                if f2 is not None:
                    seconds += c.rest / RUN
                    since_cp += c.rest / RUN
                    since_rest = 0.0
                    f = f2
                    if since_cp >= cp_every:
                        _checkpoint(c, f, pal, seconds)
                        since_cp = 0.0
                    plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
                    if plan is None:
                        continue
            if since_rest > 0 and straight_room(c, f) < plan.length + c.turn_ahead and \
                    len(c.pieces) + 6 < budget:
                f2 = _rest_turn(c, f, pal, r, goal_after=True, force_turn=True)
                if f2 is not None:
                    seconds += c.rest / RUN
                    since_cp += c.rest / RUN
                    since_rest = 0.0
                    f = f2
                    if since_cp >= cp_every:
                        _checkpoint(c, f, pal, seconds)
                        since_cp = 0.0
                    plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
                    if plan is None:
                        continue
            if not placeable(c, plan):
                f2 = rest_at(f, goal_after=True) if len(c.pieces) + 6 < budget else None
                if f2 is not None:
                    f = f2
                    plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
                if plan is None or not placeable(c, plan):
                    f3 = ascend(f)
                    if f3 is not None:
                        f = f3
                        plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
                        if plan is None or not placeable(c, plan):
                            f2 = rest_at(f, goal_after=True, force_turn=True)
                            if f2 is not None:
                                f = f2
                                plan = concept_beat(cname, step, f, ctx, tex, label, r, c)
                if plan is None or not placeable(c, plan):
                    stop = "%s (and the goal after it) does not fit, turned or a layer up" \
                        % label
                    break
            if len(c.pieces) + len(plan.items) + len(plan.movers) + 2 > budget:
                stop = "the budget"
                break
            ps = plan_seconds(plan, tier)
            c.add(plan.rects(), plan.pieces("beat%d" % c.owner))
            _record(c, plan, seconds, since_cp, ps)
            c.log.append((plan.name, plan.cls, round(ps, 1), plan.safe))
            seconds += ps
            since_rest += ps
            since_cp += ps
            section_s += ps
            f = Frame(*f.point(plan.length, plan.exit_c), d=f.d, h=plan.h_out)
            if bi == len(beats) and section_s < per_section * 0.7 and len(beats) < 8 and \
                    role != "finale" and seconds < target:
                beats.append((beats[-1][0] if beats[-1][0] not in ("fork", "blj")
                              else concept, min(3, 1 + (len(beats) % 3))))
        if stop:
            break
        c.now = seconds
        last = section_i >= len(roles)
        if not last and len(c.pieces) + 6 < budget:
            f2 = _rest_turn(c, f, pal, r, goal_after=True)
            if f2 is None:
                f2 = ascend(f)
            if f2 is None:
                stop = "no rest pad fits after section %d" % section_i
                break
            seconds += c.rest / RUN
            since_rest = 0.0
            since_cp += c.rest / RUN
            f = f2
            if since_cp >= cp_every * 0.75 or role == "peak":
                _checkpoint(c, f, pal, seconds)
                since_cp = 0.0
            f = log_run(f) or f
    if stop:
        notes.append("the course ends early: %s" % stop)
    gp = c.goal // 2
    rect = f.rect(0, c.goal, -gp, gp)
    goal = kit.kind("box").make(pal["floor"], rect[0], rect[1], f.h - 200, f.h, rect[2], rect[3],
                                None, "goal")
    c.add([(rect, "path", f.h - 200, f.h + 900)], [goal])
    if "arches" not in brief["features"]["avoid"]:
        gate_tex = pal["wall"]
        r0 = f.rect(c.goal - 200, c.goal, -gp, -gp + 200)
        r1 = f.rect(c.goal - 200, c.goal, gp - 200, gp)
        ra = f.rect(c.goal - 200, c.goal, -gp, gp)
        c.pieces.append(kit.kind("pillar").make(gate_tex, r0[0], r0[1], f.h, f.h + 700, r0[2],
                                                r0[3], None, "goal.gate post"))
        c.pieces.append(kit.kind("pillar").make(gate_tex, r1[0], r1[1], f.h, f.h + 700, r1[2],
                                                r1[3], None, "goal.gate post"))
        c.pieces.append(kit.kind("arch").make(gate_tex, ra[0], ra[1], f.h + 700, f.h + 900,
                                              ra[2], ra[3], None, "goal.gate"))
    gx, gz = f.point(gp)
    if clock:
        zx, zz = f.point(gp, -600)
        c.objects.append({"key": "lgzone", "x": int(zx), "y": f.h, "z": int(zz), "yaw": 0,
                          "link": 1, "what": "the finish"})
        c.wires.append({"on": "entered", "src": 1, "act": "finish", "dst": 0})
    seconds += gp / RUN
    c.target = (target, least, most)
    c.tier = tier
    c.opts = opts
    c.moves_allowed = sorted(moves)
    return c, {"x": gx, "y": f.h, "z": gz, "yaw": yaw_of(f.d)}, seconds, used, target, base, d
def _record(c, plan, seconds, since_cp, ps):
    moves = plan.world_moves()
    n = max(1, len(moves))
    for k, m in enumerate(moves):
        frac = (k + 0.5) / n
        m["beat"] = plan.name
        m["role"] = c.role
        m["beat_s"] = round(ps * frac, 2)
        m["since_cp"] = round(since_cp + ps * frac, 2)
        m["at_s"] = round(seconds + ps * frac, 2)
        c.route.append(m)
    for s in plan.skips:
        sp = Plan(plan.f, plan.name)
        sp.moves = [dict(s)]
        w = sp.world_moves()[0]
        w["beat"] = plan.name
        c.skips.append(w)
    c.movers += plan.world_movers(["line", "flood"])
    c.objects += plan.world_objects()
    c.wires += plan.wires
def _checkpoint(c, f, pal, seconds):
    if not getattr(f, "pad", False):
        return
    x, z = f.point(-c.rest // 2)
    y = f.h
    c.checkpoints.append((int(x), int(y), int(z), round(seconds, 1)))
    c.objects.append({"key": "coin", "x": int(x), "y": int(y), "z": int(z), "yaw": 0,
                      "what": "checkpoint"})
    if c.log and c.log[-1][0] == "rest":
        c.log[-1] = ("rest", 0, c.log[-1][2], "checkpoint")
def beat_log_run(f, pal, tex, cls=1, name="logs.run"):
    p = Plan(f, name, cls)
    B._floor(p, pal["pad"], 0, LOG_RUN_L, f.h, -LOG_RUN_W // 2, LOG_RUN_W // 2, tag="logrun")
    p.length = LOG_RUN_L
    p.walk = LOG_RUN_L
    p.jumps = 1
    return p
def placeable(c, plan):
    if not c.fits(plan.rects()):
        return False
    nf = Frame(*plan.f.point(plan.length, plan.exit_c), d=plan.f.d, h=plan.h_out)
    return c.fits([_at(nf.rect(0, c.goal, -c.goal // 2, c.goal // 2), nf.h)], 2)
def _overlap(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]
TURN_AHEAD = 6000
def straight_room(c, f, most=20000):
    run = 0
    while run < most and c.fits([_at(f.rect(0, run + 500, -W // 2, W // 2), f.h)],
                                1):
        run += 500
    return run
def _rest_turn(c, f, pal, r, turn=True, goal_after=False, force_turn=False):
    rp = c.rest // 2
    rect = f.rect(0, c.rest, -rp, rp)
    if not c.fits([(rect, "path", f.h - 200, f.h + REST_STEP)]):
        return None
    centre = f.point(rp)
    options_ = [f.d]
    if turn:
        def room(d):
            nf = Frame(centre[0] + d[0] * rp, centre[1] + d[1] * rp, d, f.h)
            run = 0
            while run < 20000 and c.fits([_at(nf.rect(0, run + 2000, -W // 2,
                                                      W // 2), f.h)], 2):
                run += 2000
            return run
        dirs = [f.d, shape.left(f.d), shape.right(f.d)]
        r.shuffle(dirs)
        rooms = {d: room(d) for d in dirs}
        dirs.sort(key=lambda d: -rooms[d])
        if rooms[f.d] >= 8000 and r.random() < 0.35:
            dirs.remove(f.d)
            dirs.insert(0, f.d)
        options_ = [d for d in dirs if rooms[d] >= 2000] or dirs
        if rooms[f.d] < c.turn_ahead + 2000:
            force_turn = True
        if force_turn:
            sides = [d for d in options_ if d != f.d and rooms[d] >= 4000]
            if sides:
                options_ = sides + [d for d in options_ if d not in sides]
    for d in options_:
        nf = Frame(centre[0] + d[0] * rp, centre[1] + d[1] * rp, d, f.h + REST_STEP)
        probe = nf.rect(0, 5000, -W // 2, W // 2)
        if d != f.d and not c.fits([_at(probe, nf.h)], 2):
            continue
        if goal_after and not c.fits([_at(nf.rect(0, c.goal, -c.goal // 2, c.goal // 2), nf.h)], 2):
            continue
        pad = kit.kind("box").make(pal["floor"], rect[0], rect[1], f.h + REST_STEP - 200, f.h + REST_STEP,
                                   rect[2], rect[3], None, "rest")
        c.add([(rect, "path", f.h - 200, f.h + REST_STEP)], [pad])
        c.log.append(("rest", 0, round(c.rest / RUN, 1), False))
        nf.pad = True
        return nf
    return None
def course_kit(pieces, brief):
    used = {}
    for p in pieces:
        if str(p.get("tag", "")).startswith("goal.gate"):
            used[p["kind"]] = used.get(p["kind"], 0) + 1
    return used
def report(c, seconds):
    tier = c.tier
    walk_s = 0.0
    beats = [x for x in c.log if x[0] != "rest"]
    moves_s = sum(coursecheck.judge(m, tier)["seconds"] for m in c.route)
    walk_s = max(0.0, seconds - moves_s)
    rep = coursecheck.walk(c.route, tier, walk_s)
    for s in c.skips:
        r = coursecheck.judge(s, tier)
        s["leeway"] = r["leeway"]
        s["label"] = r["label"]
    target, least, most = c.target
    rep.update({
        "length": c.opts["length"], "target_s": target, "band_s": [least, most],
        "checkpoints": [list(x) for x in c.checkpoints], "sections": [list(x) for x in c.sections],
        "skips": [{"label": s.get("label"), "leeway": s.get("leeway"), "x": s.get("x"),
                   "z": s.get("z"), "x2": s.get("x2"), "z2": s.get("z2")} for s in c.skips],
        "blj": ("a BLJ skip" if any(s.get("kind") == "blj" for s in c.skips)
                else "avoided: no stairs on the route"),
        "moves_allowed": c.moves_allowed, "beats": len(beats),
        "movers": len(c.movers), "route": c.route,
    })
    return rep
def build(brief, streams, reference=False):
    if set(brief["features"]["want"]) & {"rooms", "training_course"}:
        from .. import rooms
        return rooms.build_family(brief, streams)
    notes = []
    r = streams("course")
    pal, pal_notes = common.palette(brief)
    notes += pal_notes
    best = None
    for attempt in range(6):
        tried = []
        c, goal, seconds, used, target, base, d0 = lay(brief, r, pal, tried)
        least, most = c.target[1], c.target[2]
        inside = least <= seconds <= most
        score = (0 if inside else 1, abs(seconds - target))
        if best is None or score < best[0]:
            best = (score, c, goal, seconds, used, target, base, d0, tried)
        if inside and abs(seconds - target) <= 0.15 * target:
            break
    _, c, goal, seconds, used, target, base, d0, tried = best
    notes += tried
    least = c.target[1]
    if seconds < least:
        notes.append("the course came out at %.0f s - no more room on the level" % seconds)
    from ..paths.road import compile_pieces
    pieces = compile_pieces(c.pieces)
    kit_used = course_kit(pieces, brief)
    d = d0
    o = shape.right(d)
    sx, sz = c.start
    spawns = []
    for row in range(4):
        for col in range(4):
            a = 600 - 400 * row
            cc = -600 + 400 * col
            spawns.append({"x": sx + d[0] * a + o[0] * cc, "y": base,
                           "z": sz + d[1] * a + o[1] * cc, "yaw": yaw_of(d)})
    start = {"x": sx + d[0] * 900, "y": base, "z": sz + d[1] * 900, "yaw": yaw_of(d)}
    survey = {"lineStart": dict(start), "lineFinish": dict(goal)}
    modes = ["line"]
    if goal["y"] >= base + 400:
        survey["floodStart"] = dict(start)
        survey["floodGoal"] = dict(goal)
        modes.append("flood")
    for m in c.movers:
        m["modes"] = list(modes)
    for o_ in c.objects:
        if o_.get("modes"):
            o_["modes"] = list(modes)
    budget = brief["budget"]
    total = len(pieces) + len(c.objects) + len(c.movers)
    if "budget" in brief.defaulted and total > budget:
        from .. import budget as budgetmod
        budget = min(budgetmod.ceiling("course", brief["modes"]), total)
        notes.append("budget raised to %d for the course (the brief named none)" % budget)
    if total > budget:
        notes.append("%d objects against a budget of %d" % (total, budget))
    beats = [x for x in c.log if x[0] != "rest"]
    classes = [x[1] for x in beats]
    rep = report(c, seconds)
    tier = c.tier
    arena = {"key": brief["key"] or "generated", "level": brief["level"], "budget": budget,
             "pieces": pieces, "spawns": spawns, "survey": survey,
             "look": kit.look(brief["theme"] if brief["theme"] != "auto" else "sky",
                              brief["sky"], brief["music"]),
             "onlyFor": modes,
             "blurb": "a generated obstacle course for sixteen",
             "note": "a %s course, %d s for a good run (%d s the first time), %d beats in %d "
                     "sections (%s), %d checkpoints, %d up from start to goal; %s"
                     % (tier.label, round(seconds), round(rep["expected_s"]), len(beats),
                        len(c.sections), ", ".join(used), len(c.checkpoints),
                        goal["y"] - base, rep["text"])}
    if c.objects:
        arena["objects"] = [{k: v for k, v in o_.items() if k != "what"} for o_ in c.objects]
    if c.movers:
        arena["movers"] = c.movers
    if c.wires:
        arena["wires"] = c.wires
    lines = []
    for a in brief["anchors"]:
        if a["what"] in ("start_line", "world_spawn", "spawns", "spawn"):
            lines.append(("placed", a["id"], "the start pad (%d, %d)" % c.start))
        else:
            lines.append(("not yet", a["id"], "an obstacle course places %s from milestone 3"
                          % a["what"]))
    fx0, fx1, fz0, fz1 = common.footprint(pieces)
    params = common.compat_params(max(fx1 - fx0, fz1 - fz0), {
        "shape": "course", "lane": "width %d" % W, "corner": "%d rests" % sum(
            1 for x in c.log if x[0] == "rest"),
        "course_estimate_s": round(seconds, 1), "course_target_s": target,
        "concepts": used, "beats": [list(x) for x in c.log], "max_class": max(classes or [0]),
        "safety_floors": sum(1 for x in beats if x[3] is True), "base": base,
        "rise": goal["y"] - base, "tier": tier.name, "course": rep})
    meta = {"params": params, "modules": {"course": used, "beats": len(beats), "kit": kit_used,
                                          "rests": sum(1 for x in c.log if x[0] == "rest"),
                                          "tier": tier.name},
            "anchors": lines, "notes": notes, "graph_faults": [], "centre": (0, 0),
            "bases": [], "module_pieces": {}, "field_spots": 0, "cover": 0,
            "graph": {"zones": ["course"], "loops": []}}
    return arena, meta
