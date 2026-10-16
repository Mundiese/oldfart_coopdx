import math
from .. import coursemoves as cm
from .. import kit, movement
from .. import movers as movermod
from ..paths.road import axis_rises
W = 1600
LIP = 400
SAFE_DROP = 600
CLASSIC = {
    "casual": (500, 400, 200),
    "normal": (700, 500, 330),
    "hard": (1200, 1000, 480),
    "expert": (1450, 1300, 600),
    "pro": (None, None, None),
}
STONE = {"casual": 400, "normal": 400, "hard": 300, "expert": 300, "pro": 200}
BEAM = {"casual": (400, 400), "normal": (400, 300), "hard": (300, 300), "expert": (300, 200),
        "pro": (200, 200)}
MOVER_SPEED = {"casual": 240, "normal": 300, "hard": 360, "expert": 420, "pro": 480}
MOVERS_MAX = 24
def land_for(gap, long_move=False):
    depth = movement.DEPTHS["landing_long_jump"] if long_move or gap > movement.GAPS["medium"] \
        else movement.DEPTHS["landing_running_jump"]
    return max(800, gap + depth)
class Plan:
    def __init__(self, f, name, cls=1):
        self.f = f
        self.name = name
        self.cls = cls
        self.items = []
        self.length = 0
        self.h_out = f.h
        self.exit_c = 0
        self.jumps = 0
        self.safe = False
        self.over = "floor"
        self.moves = []
        self.movers = []
        self.objects = []
        self.wires = []
        self.walk = 0.0
        self.skips = []
    def box(self, tex, a0, a1, c0, c1, y0, y1, tag=""):
        self.items.append(("box", tex, a0, a1, c0, c1, y0, y1, None, tag))
    def ramp(self, tex, a0, a1, c0, c1, y0, y1, rises, tag=""):
        self.items.append(("ramp", tex, a0, a1, c0, c1, y0, y1, rises, tag))
    def lava(self, a0, a1, c0, c1, y0, y1, tag="lava"):
        self.items.append(("lava", "lava", a0, a1, c0, c1, y0, y1, None, tag))
    def pieces(self, prefix):
        out = []
        f = self.f
        for kind, tex, a0, a1, c0, c1, y0, y1, rises, tag in self.items:
            x0, x1, z0, z1 = f.rect(a0, a1, c0, c1)
            t = "%s.%s" % (prefix, tag or self.name)
            if kind == "box":
                out.append(kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, t))
            elif kind == "lava":
                out.append(kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, t))
            else:
                from ..paths import shape
                axis = {"+a": (f.d, True), "-a": (f.d, False),
                        "+c": (shape.right(f.d), True), "-c": (shape.right(f.d), False)}[rises]
                out.append(kit.kind("stairs" if kind == "stairs" else "ramp").make(
                    tex, x0, x1, y0, y1, z0, z1, axis_rises(*axis), t))
        return out
    def rects(self):
        out = []
        for kind, _, a0, a1, c0, c1, y0, y1, _, tag in self.items:
            k = "net" if (tag.startswith("safety") or kind == "lava") else "path"
            out.append((self.f.rect(a0, a1, c0, c1), k, y0, y1))
        for spec in self.movers:
            a0, a1, c0, c1 = spec["rect"]
            ys = [pt[2] for pt in spec["points"]]
            out.append((self.f.rect(a0, a1, c0, c1), "mover", min(ys) - 1300, max(ys) + 200))
        return out
    def move(self, kind, move, a, c=0.0, h=None, **kw):
        rec = {"kind": kind, "move": move, "a": a, "c": c,
               "h": self.f.h if h is None else h, "over": kw.pop("over", self.over)}
        rec.update(kw)
        self.moves.append(rec)
        if kind in ("gap", "climb", "kickup", "pound", "hop", "blj"):
            self.jumps += 1
        return rec
    def world_moves(self):
        out = []
        for m in self.moves:
            r = dict(m)
            x, z = self.f.point(m["a"], m.get("c", 0))
            r["x"], r["y"], r["z"] = round(x), round(m["h"]), round(z)
            if "to_a" in m:
                x2, z2 = self.f.point(m["to_a"], m.get("to_c", m.get("c", 0)))
                r["x2"], r["z2"], r["y2"] = round(x2), round(z2), round(m.get("to_h", m["h"]))
            for k in ("a", "c", "to_a", "to_c", "to_h"):
                r.pop(k, None)
            out.append(r)
        return out
    def world_movers(self, modes):
        out = []
        for spec in self.movers:
            pts = [(self.f.point(a, c)[0], y, self.f.point(a, c)[1]) for a, c, y in spec["points"]]
            m = spec["make"](pts, modes)
            out.append(m)
        return out
    def world_objects(self):
        out = []
        for o in self.objects:
            r = dict(o)
            x, z = self.f.point(o["a"], o.get("c", 0))
            r["x"], r["z"] = int(round(x)), int(round(z))
            r.pop("a", None)
            r.pop("c", None)
            out.append(r)
        return out
def _floor(p, tex, a0, a1, h, c0=-W // 2, c1=W // 2, tag=""):
    p.box(tex, a0, a1, c0, c1, h - 200, h, tag)
class Ctx:
    def __init__(self, tier, pal, r, moves, ground=None, lava_ok=True, movers_left=MOVERS_MAX,
                 modes=(), forge_off=(), link_next=2):
        self.tier = tier
        self.pal = pal
        self.r = r
        self.moves = set(moves)
        self.ground = ground
        self.lava_ok = lava_ok
        self.movers_left = movers_left
        self.modes = list(modes)
        self.forge_off = set(forge_off)
        self.link_next = link_next
        self.need = tier.leeway
        self.net_side = 1
        self.nets = True
        self.lava = False
        self.role = "build"
    @property
    def grab(self):
        return self.tier.grab
    def depth(self, move):
        return self.tier.depth_long if move in ("longjump", "dive") else self.tier.depth_run
    def cap(self, rise):
        flat, up, _ = CLASSIC[self.tier.name]
        if flat is None:
            return None
        if rise > 0:
            return up
        if rise < 0:
            return flat + 300
        return flat
    def rise_cap(self):
        return CLASSIC[self.tier.name][2]
    def gap(self, move, rise, depth, runup, need=None, most=None):
        need = self.need if need is None else need
        g = cm.design_gap(move, int(rise), int(depth), int(runup), need, self.grab)
        if g is None:
            return None
        cap = self.cap(rise)
        if cap is not None:
            g = min(g, cap)
        if most is not None:
            g = min(g, most)
        g = g // 50 * 50
        while g >= 150 and cm.leeway(move, g, int(rise), int(depth), int(runup),
                                     self.grab) < need:
            g -= 50
        return g if g >= 150 else None
    def common_gap(self, specs, most=None):
        gs = []
        for s in specs:
            need = s[4] if len(s) > 4 else None
            g = self.gap(s[0], s[1], s[2], s[3], need=need, most=most)
            if g is None:
                return None
            gs.append(g)
        g = min(gs)
        while g >= 150:
            if all(cm.leeway(s[0], g, int(s[1]), int(s[2]), int(s[3]), self.grab) >=
                   (s[4] if len(s) > 4 and s[4] is not None else self.need) for s in specs):
                return g
            g -= 50
        return None
    def has(self, move):
        return move in self.moves
    def mover_tex(self):
        for tex in list(self.pal.get("accents") or []) + ["stone1"]:
            if movermod.key_known(movermod.platform_key("slab", tex)):
                return tex
        return "stone1"
def net(p, ctx, a_end, low=None):
    h = p.f.h
    hs = (h if low is None else low) - SAFE_DROP
    pal = ctx.pal
    ground = ctx.ground
    if ground is not None and hs - 200 <= ground + 200:
        p.safe = "floor"
        p.over = "floor"
        return None
    from ..paths.road import q
    run = q(2 * (h - hs))
    if getattr(ctx, "net_side", 1) >= 0:
        c0, c1 = -W // 2, W // 2 + run + 400
        p.ramp(pal["road"], 0, LIP, W // 2, W // 2 + run, hs, h, "-c", "safety.ramp")
    else:
        c0, c1 = -W // 2 - run - 400, W // 2
        p.ramp(pal["road"], 0, LIP, -W // 2 - run, -W // 2, hs, h, "+c", "safety.ramp")
    p.box(pal["keel"], 0, a_end, c0, c1, hs - 200, hs, "safety")
    p.safe = True
    p.over = "net"
    return hs, c0, c1
def under(p, ctx, a0, a_end, low=None):
    if ctx.nets:
        from . import course as _course
        return _course._safety(p, ctx, a_end, low)
    h = p.f.h if low is None else low
    if ctx.ground is not None and h - SAFE_DROP - 200 <= ctx.ground + 200:
        p.over = "floor"
        return None
    if ctx.lava and ctx.lava_ok and a_end - a0 >= 200:
        p.lava(a0, a_end, -W // 2, W // 2, h - SAFE_DROP - 200, h - SAFE_DROP)
        p.over = "lava"
    else:
        p.over = "void"
    return None
def _landing(p, tex, a0, a1, h2, net, c0=-W // 2, c1=W // 2):
    if net is None:
        _floor(p, tex, a0, a1, h2, c0, c1, tag="landing")
    else:
        hs, n0, n1 = net
        p.box(tex, a0, a1, n0, n1, hs - 200, h2, "landing")
def _land_len(ctx, gap, move, net):
    if net is not None:
        return land_for(gap, move in ("longjump", "dive"))
    return max(ctx.depth(move), 400)
def beat_gap(f, ctx, tex, name, move="jump", rise=0, lip=LIP, cls=None, need=None):
    if not ctx.has(move) and move != "jump":
        return None
    depth = ctx.depth(move)
    g = ctx.gap(move, rise, depth, lip, need)
    if g is None or g < 200:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, lip, h, tag="lip")
    h2 = h + rise
    net = under(p, ctx, lip, lip + g, low=min(h, h2) if rise < 0 else None)
    land = _land_len(ctx, g, move, net)
    _landing(p, tex, lip + g, lip + g + land, h2, net)
    p.move("gap", move, lip, gap=g, rise=rise, depth=depth, runup=lip, to_a=lip + g, to_h=h2,
           need=ctx.need if need is None else need)
    p.length = lip + g + land
    p.walk = lip + land
    p.h_out = h2
    return p
def beat_stones(f, ctx, tex, name, steps=3, wobble=0, rise=0, size=None, tall=False):
    s = size or STONE[ctx.tier.name]
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    rises = []
    for k in range(steps):
        rises.append(rise * (k + 1) + ((wobble if k % 2 == 0 else -wobble) if wobble else 0))
    ups = [rises[0]] + [rises[k] - rises[k - 1] for k in range(1, steps)]
    ups.append(rise * steps - rises[-1])
    depth_end = ctx.tier.depth_run
    specs = [("jump", ups[0], s, LIP)] + [("jump", u, s, s) for u in ups[1:-1]] + \
        [("jump", ups[-1], depth_end, s)]
    g = ctx.common_gap(specs, most=800)
    if g is None or g < 200:
        return None
    lanes = ((-600 - s // 2, -600 + s // 2), (-s // 2, s // 2), (600 - s // 2, 600 + s // 2))
    a = LIP
    end = LIP + steps * (g + s) + g
    net = under(p, ctx, LIP, end, low=min(0, min(rises)) + h if min(rises) < 0 else None)
    hh_prev = h
    for k in range(steps):
        hh = h + rises[k]
        bottom = hh - ((300 if p.over == "lava" else 900) if tall and net is None else 200)
        for c0, c1 in lanes:
            p.box(tex, a + g, a + g + s, c0, c1, bottom, hh, "post" if tall else "stone")
        p.move("gap", "jump", a, gap=g, rise=hh - hh_prev, depth=s, runup=LIP if k == 0 else s,
               to_a=a + g, to_h=hh, h=hh_prev, need=ctx.need)
        hh_prev = hh
        a += g + s
    h2 = h + rise * steps
    land = _land_len(ctx, g, "jump", net)
    _landing(p, tex, a + g, a + g + land, h2, net)
    p.move("gap", "jump", a, gap=g, rise=h2 - hh_prev, depth=depth_end, runup=s, to_a=a + g,
           to_h=h2, h=hh_prev, need=ctx.need)
    p.length = a + g + land
    p.walk = LIP + land + steps * s
    p.h_out = h2
    return p
def beat_beams(f, ctx, tex, name, length=1600, width=None, gap_after=False):
    width = width or BEAM[ctx.tier.name][0]
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    for c in (-600, 0, 600):
        p.box(tex, LIP, LIP + length, c - width // 2, c + width // 2, h - 200, h, "beam")
    g = 0
    if gap_after:
        g = ctx.gap("jump", 0, ctx.tier.depth_run, min(length, 900))
        if g is None or g < 200:
            g = 0
    a = LIP + length + g
    net = under(p, ctx, LIP, a)
    land = _land_len(ctx, g or 400, "jump", net)
    _landing(p, tex, a, a + land, h, net)
    p.move("beam", "walk", LIP, width=width, length=length, to_a=LIP + length)
    if g:
        p.move("gap", "jump", LIP + length, gap=g, rise=0, depth=ctx.tier.depth_run,
               runup=min(length, 900), to_a=a, need=ctx.need)
    p.length = a + land
    p.walk = LIP + length + land
    return p
def beat_pound(f, ctx, tex, name):
    if not ctx.has("groundpound"):
        return None
    drop = 500
    need = ctx.need + 1
    best = None
    for g in range(150, 700, 50):
        if cm.pound_window(g, drop, 200) >= need:
            best = g
    if best is None:
        return None
    g = best
    out = ctx.gap("jump", 0, ctx.tier.depth_run, 200)
    if out is None or out < 200:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    a_post = LIP + g
    h_post = h - drop
    end = a_post + 200 + out
    net = under(p, ctx, LIP, end, low=h_post)
    for c in (-600, 0, 600):
        p.box(tex, a_post, a_post + 200, c - 100, c + 100,
              h_post - (300 if p.over == "lava" else 900), h_post, "post")
    land = _land_len(ctx, out, "jump", net)
    _landing(p, tex, end, end + land, h_post, net)
    p.move("pound", "groundpound", LIP, gap=g, drop=drop, post=200, to_a=a_post + 100,
           to_h=h_post, need=need - 1)
    p.move("gap", "jump", a_post + 200, gap=out, rise=0, depth=ctx.tier.depth_run, runup=200,
           to_a=end, h=h_post, need=ctx.need)
    p.length = end + land
    p.walk = LIP + land + 200
    p.h_out = h_post
    return p
CLIMB_RUNWAY = {"jump": 800, "standjump": 400, "double": 1400, "sideflip": 400, "triple": 2200}
def best_rise(ctx, move, runway, lo=150, hi=1000, need=None):
    need = ctx.need if need is None else need
    cap = ctx.rise_cap()
    if move in ("sideflip", "triple") and cap is not None:
        cap = max(cap, {"sideflip": 535, "triple": 600}[move] if ctx.tier.rank >= 2 else cap)
    r = min(hi, 700 if cap is None else cap) // 50 * 50
    while r >= lo:
        if cm.climb_leeway(move, r, runway, ctx.grab, most=need) >= need:
            return r
        r -= 50
    return None
def beat_ledge(f, ctx, tex, name, move="jump", rise=None):
    if move != "jump" and not ctx.has(move):
        return None
    runway = CLIMB_RUNWAY.get(move, 800)
    if rise is None:
        rise = best_rise(ctx, move, runway)
    if rise is None or cm.climb_leeway(move, rise, runway, ctx.grab, most=ctx.need) < ctx.need:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, runway, h, tag="lip")
    p.box(tex, runway, runway + 800, -W // 2, W // 2, h - 200, h + rise, "ledge")
    p.move("climb", move, runway, rise=rise, runway=runway, to_a=runway, to_h=h + rise,
           need=ctx.need)
    p.length = runway + 800
    p.walk = runway + 800
    p.h_out = h + rise
    return p
def beat_block_stairs(f, ctx, tex, name, steps=3):
    s = 400
    g = ctx.common_gap([("jump", 200, s, s), ("jump", 200, s, LIP),
                        ("jump", 200, ctx.tier.depth_run, s)], most=600)
    if not g or g < 200:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    a = LIP
    for k in range(steps):
        hh = h + 200 * (k + 1)
        p.box(tex, a + g, a + g + s, -W // 2, W // 2, hh - 200, hh, "block")
        p.move("gap", "jump", a, gap=g, rise=200, depth=s, runup=LIP if k == 0 else s,
               to_a=a + g, to_h=hh, h=hh - 200, need=ctx.need)
        a += g + s
    h2 = h + 200 * (steps + 1)
    net = under(p, ctx, LIP, a + g)
    land = _land_len(ctx, g, "jump", net)
    _landing(p, tex, a + g, a + g + land, h2, net)
    p.move("gap", "jump", a, gap=g, rise=200, depth=ctx.tier.depth_run, runup=s, to_a=a + g,
           to_h=h2, h=h2 - 200, need=ctx.need)
    p.length = a + g + land
    p.walk = LIP + land + steps * s
    p.h_out = h2
    return p
SHAFT_L = 800
def _shaft(f, ctx, tex, name, width, top, tall, kind_rec):
    p = Plan(f, name)
    h = f.h
    wall = ctx.pal.get("wall") or tex
    half = width // 2
    _floor(p, tex, 0, LIP, h, tag="lip")
    p.box(tex, LIP, LIP + SHAFT_L, -half, half, h - 200, h, "shaft.floor")
    p.box(wall, LIP, LIP + SHAFT_L, half, half + 400, h - 200, h + tall, "shaft.wall")
    p.box(tex, LIP, LIP + SHAFT_L, -half - 1200, -half, h - 200, h + top, "shaft.exit")
    p.over = "floor"
    rec = dict(kind_rec)
    kind = rec.pop("kind")
    move = rec.pop("move")
    p.move(kind, move, LIP + SHAFT_L // 2, c=0, to_a=LIP + SHAFT_L // 2, to_c=-half - 600,
           to_h=h + top, over="floor", **rec)
    p.length = LIP + SHAFT_L
    p.walk = LIP + SHAFT_L // 2
    p.h_out = h + top
    p.exit_c = -half - 600
    return p
def beat_shaft(f, ctx, tex, name, height, width=None):
    if not ctx.has("wallkick") or ctx.tier.chimney is None:
        return None
    policy, widths = ctx.tier.chimney
    width = width or ctx.r.choice(widths)
    if cm.chimney_climb(width, policy) is None:
        return None
    return _shaft(f, ctx, tex, name, width, height, height + 1000,
                  {"kind": "shaft", "move": "wallkick", "width": width, "height": height,
                   "policy": policy, "need": 0})
def beat_kickup(f, ctx, tex, name):
    if not ctx.has("kickup"):
        return None
    width = ctx.r.choice((400, 500, 600))
    best = None
    for ledge in range(700, 1150, 50):
        if cm.kickup_leeway(width, ledge) >= ctx.need:
            best = ledge
    if best is None:
        return None
    return _shaft(f, ctx, tex, name, width, best, best + 1200,
                  {"kind": "kickup", "move": "kickup", "width": width, "ledge": best,
                   "first": "sideflip", "need": ctx.need})
def _slab(ctx):
    return ctx.mover_tex()
def beat_ferry(f, ctx, tex, name, span=None):
    if not ctx.has("ride") or ctx.movers_left < 1 or "movers" in ctx.forge_off:
        return None
    span = span or ctx.r.choice((1600, 2000, 2400))
    speed = MOVER_SPEED[ctx.tier.name]
    wait = max(ctx.tier.mover_wait, 15)
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    net = under(p, ctx, LIP, LIP + span)
    land = _land_len(ctx, 600, "jump", net)
    _landing(p, tex, LIP + span, LIP + span + land, h, net)
    mt = _slab(ctx)
    modes = ctx.modes
    def make(pts, modes, mt=mt, speed=speed, wait=wait):
        (ax, ay, az), (bx, by, bz) = pts
        return movermod.gap_ferry((ax, ay, az), (bx, by, bz), tex=mt, shape="slab", speed=speed,
                                  wait=wait, modes=modes)
    p.movers.append({"make": make, "points": [(LIP, 0, h), (LIP + span, 0, h)],
                     "rect": (LIP, LIP + span, -110, 110)})
    probe = make([(0, h, 0), (span, h, 0)], modes)
    p.move("ride", "ride", LIP, to_a=LIP + span, what="ferry",
           window=wait * 3, ride_s=round(movermod.ride_s(probe, 0, 1), 2),
           wait_s=round(movermod.wait_s(probe, 0), 2))
    p.length = LIP + span + land
    p.walk = LIP + land
    return p
def beat_lift(f, ctx, tex, name, rise=None):
    if not ctx.has("ride") or ctx.movers_left < 1 or "movers" in ctx.forge_off:
        return None
    rise = rise or ctx.r.choice((800, 1000, 1200))
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    net = under(p, ctx, LIP, LIP + 220)
    p.box(tex, LIP + 220, LIP + 1020, -W // 2, W // 2, h - 200, h + rise, "ledge")
    mt = _slab(ctx)
    def make(pts, modes, mt=mt):
        (ax, ay, az), (bx, by, bz) = pts
        return movermod.lift((ax, ay, az), (bx, by, bz), tex=mt, shape="slab", ridden=True,
                             speed=300, wait=15, modes=modes)
    p.movers.append({"make": make, "points": [(LIP + 110, 0, h), (LIP + 110, 0, h + rise)],
                     "rect": (LIP + 10, LIP + 210, -100, 100)})
    probe = make([(0, h, 0), (0, h + rise, 0)], ctx.modes)
    p.move("ride", "ride", LIP, to_a=LIP + 220, to_h=h + rise, what="lift", window=90,
           ride_s=round(movermod.ride_s(probe, 0, 1), 2), wait_s=0.0)
    p.length = LIP + 1020
    p.walk = LIP + 800
    p.h_out = h + rise
    return p
def beat_door(f, ctx, tex, name):
    if not ctx.has("ride") or ctx.movers_left < 1 or {"movers", "all"} & ctx.forge_off:
        return None
    hop = ctx.common_gap([("jump", 0, 200, LIP), ("jump", 0, ctx.tier.depth_run, 200)],
                         most=200)
    if not hop:
        return None
    link = ctx.link_next
    if link > 31:
        return None
    ctx.link_next += 1
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    span = 2 * hop + 200
    net = under(p, ctx, LIP, LIP + span)
    land = _land_len(ctx, hop, "jump", net)
    _landing(p, tex, LIP + span, LIP + span + land, h, net)
    mt = _slab(ctx)
    mid = LIP + hop + 100
    def make(pts, modes, mt=mt, link=link):
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts
        key = movermod.platform_key("slab", mt)
        top = movermod.SHAPES["slab"][1]
        at = (ax, ay - top, az)
        return movermod.mover(key, at, [at + (600, 0), (bx, by - top, bz, 60, 0),
                                        (cx, cy - top, cz, 600, 600)], mode="pingpong",
                              trigger="wired", modes=modes, link=link)
    p.movers.append({"make": make, "points": [(mid, -1500, h), (mid, -20, h), (mid, 0, h)],
                     "rect": (mid - 100, mid + 100, -1600, 100)})
    p.objects.append({"key": "lgbutton", "a": LIP // 2, "c": -500, "y": h, "link": link,
                      "yaw": 0, "modes": list(ctx.modes), "what": "bridge button"})
    p.wires.append({"on": "pressed", "src": link, "act": "start", "dst": link})
    p.move("ride", "ride", LIP // 2, c=-500, what="button bridge", window=600 * 3,
           ride_s=2.5, wait_s=0.0)
    p.move("gap", "jump", LIP, gap=hop, rise=0, depth=200, runup=LIP, to_a=LIP + hop,
           need=ctx.need)
    p.move("gap", "jump", LIP + hop + 200, gap=hop, rise=0, depth=ctx.tier.depth_run, runup=200,
           to_a=LIP + span, need=ctx.need)
    p.length = LIP + span + land
    p.walk = LIP + land
    return p
def positions(m):
    tl = movermod.timeline(m)
    return [movermod.position(m, t) for t in range(tl["period"])]
def _pingpong_probe(key, a_pts, speed, wait, phase=0):
    return movermod.mover(key, a_pts[0], a_pts, mode="pingpong", speed=speed, wait=wait,
                          phase=phase)
def beat_hop(f, ctx, tex, name):
    if not ctx.has("ride") or ctx.tier.rank < 2 or ctx.movers_left < 1 or \
            "movers" in ctx.forge_off:
        return None
    speed = MOVER_SPEED[ctx.tier.name]
    wait = ctx.tier.mover_wait
    span = 1800
    mt = _slab(ctx)
    key = movermod.platform_key("slab", mt)
    top = movermod.SHAPES["slab"][1]
    for d in (200, 150):
        near = d
        a_c = LIP + near + 100
        b_c = LIP + span - near - 100
        probe = movermod.mover(key, (a_c, -top, 0), [(a_c, -top, 0), (b_c, -top, 0)],
                               mode="pingpong", speed=speed, wait=wait)
        offs = positions(probe)
        period = len(offs)
        board = tuple((near + o[0], near + o[0] + 200, 0.0) for o in offs)
        w_on = cm.moving_window("jump", LIP, board, period, grab=False)
        alight = tuple((span - (near + 200 + o[0]), span - (near + 200 + o[0]) +
                        ctx.tier.depth_run, 0.0) for o in offs)
        w_off = cm.moving_window("jump", 150, alight, period, takeoff_len=200, fixed=True)
        if w_on >= ctx.need + 1 and w_off >= ctx.need + 1:
            break
    else:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    net = under(p, ctx, LIP, LIP + span)
    land = _land_len(ctx, 600, "jump", net)
    _landing(p, tex, LIP + span, LIP + span + land, h, net)
    def make(pts, modes, key=key, speed=speed, wait=wait):
        (ax, ay, az), (bx, by, bz) = pts
        at = (ax, ay - top, az)
        return movermod.mover(key, at, [at, (bx, by - top, bz)], mode="pingpong", speed=speed,
                              wait=wait, modes=modes)
    p.movers.append({"make": make, "points": [(a_c, 0, h), (b_c, 0, h)],
                     "rect": (a_c - 100, b_c + 100, -100, 100)})
    p.move("hop", "jump", LIP, gap=near, rise=0, to_a=LIP + near, window=w_on, period=period,
           wait_s=round(period / 2.0 / 30.0, 2), need=ctx.need)
    p.move("ride", "ride", LIP + near + 100, to_a=LIP + span - near - 100, what="platform",
           window=99, ride_s=round(abs(b_c - a_c) / float(speed), 2), wait_s=0.0)
    p.move("hop", "jump", LIP + span - near, gap=near, rise=0, to_a=LIP + span, window=w_off,
           period=period, wait_s=0.0, need=ctx.need)
    p.length = LIP + span + land
    p.walk = LIP + land
    return p
def beat_sinkers(f, ctx, tex, name, count=2):
    if ctx.nets:
        return None
    if not ctx.has("ride") or ctx.tier.rank < 2 or ctx.movers_left < count or \
            "movers" in ctx.forge_off:
        return None
    mt = _slab(ctx)
    key = movermod.platform_key("slab", mt)
    top = movermod.SHAPES["slab"][1]
    wait_top = {"hard": 40, "expert": 30, "pro": 20}.get(ctx.tier.name, 40)
    speed = 400
    step = 12
    g = ctx.gap("jump", 0, 200, 150, need=ctx.need + 1, most=200)
    if not g:
        return None
    def path(x, y, z):
        return [(x, y, z, 60, wait_top), (x, y - 20, z, speed, 0), (x, y - 1200, z, speed, 10)]
    probe = movermod.mover(key, (0, -top, 0), path(0, -top, 0), mode="pingpong", phase=0)
    ys = [o[1] for o in positions(probe)]
    period = len(ys)
    def tops(k):
        return tuple(ys[(t - step * k) % period] for t in range(period))
    windows = []
    windows.append(cm.moving_window("jump", LIP, tuple((g, g + 200, y) for y in tops(0)),
                                    period))
    for k in range(count - 1):
        windows.append(cm.moving_window("jump", 150, tuple((g, g + 200, y) for y in tops(k + 1)),
                                        period, take=tops(k), takeoff_len=200))
    windows.append(cm.moving_window("jump", 150, tuple((g, g + ctx.tier.depth_run, 0.0)
                                                       for _ in range(period)),
                                    period, take=tops(count - 1), takeoff_len=200))
    if min(windows) < ctx.need + 1:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, LIP, h, tag="lip")
    end = LIP + count * (g + 200) + g
    lava, ctx.lava = ctx.lava, False
    net = under(p, ctx, LIP, end)
    ctx.lava = lava
    land = _land_len(ctx, g, "jump", net)
    _landing(p, tex, end, end + land, h, net)
    a = LIP
    for k in range(count):
        c_a = a + g + 100
        def make(pts, modes, key=key, k=k):
            (ax, ay, az) = pts[0]
            at = (ax, ay - top, az)
            return movermod.mover(key, at, path(ax, ay - top, az), mode="pingpong",
                                  phase=(period - step * k) % period, modes=modes)
        p.movers.append({"make": make, "points": [(c_a, 0, h)],
                         "rect": (c_a - 100, c_a + 100, -100, 100)})
        p.move("hop", "jump", a, gap=g, rise=0, to_a=a + g, window=windows[k], period=period,
               wait_s=round(period / 4.0 / 30.0, 2) if k == 0 else 0.0, need=ctx.need)
        a += g + 200
    p.move("hop", "jump", a, gap=g, rise=0, to_a=a + g, window=windows[-1], period=period,
           wait_s=0.0, need=ctx.need)
    p.length = end + land
    p.walk = LIP + land
    return p
def beat_tower(f, ctx, tex, name, rise=3000, pad=2000):
    if not ctx.has("ride") or ctx.movers_left < 1 or {"movers", "all"} & ctx.forge_off:
        return None
    p = Plan(f, name, 1)
    h = f.h
    top = h + rise
    half = pad // 2
    p.box(ctx.pal["floor"], 220, 220 + pad, -half, half, top - 200, top, "rest")
    mt = _slab(ctx)
    def make(pts, modes, mt=mt):
        (ax, ay, az), (bx, by, bz) = pts
        return movermod.lift((ax, ay, az), (bx, by, bz), tex=mt, shape="slab", ridden=True,
                             speed=300, wait=15, modes=modes)
    p.movers.append({"make": make, "points": [(110, 0, h), (110, 0, top)],
                     "rect": (10, 210, -100, 100)})
    probe = make([(0, h, 0), (0, top, 0)], ctx.modes)
    p.move("ride", "ride", 0, to_a=220, to_h=top, what="lift", window=90,
           ride_s=round(movermod.ride_s(probe, 0, 1), 2), wait_s=0.0)
    p.over = "floor"
    p.length = 220 + half
    p.walk = 220 + half
    p.h_out = top
    p.pad_centre = 220 + half
    return p
def beat_ascend(f, ctx, tex, name, rise=3000):
    if ctx.has("ride") and ctx.movers_left >= 1 and not ({"movers", "all"} & ctx.forge_off):
        p = beat_lift(f, ctx, tex, name, rise=rise)
        if p is not None:
            p.cls = 1
            return p
    p = Plan(f, name, 1)
    h = f.h
    run = rise * 3 // 2 // 200 * 200
    _floor(p, tex, 0, LIP, h, tag="lip")
    p.ramp(ctx.pal["road"], LIP, LIP + run, -W // 2, W // 2, h, h + rise, "+a", "ascend")
    _floor(p, tex, LIP + run, LIP + run + 800, h + rise, tag="landing")
    p.over = "floor"
    p.length = LIP + run + 800
    p.walk = p.length * 1.2
    p.h_out = h + rise
    return p
def beat_slide(f, ctx, tex, name, drop=600):
    p = Plan(f, name, 0)
    h = f.h
    run = drop * 3
    _floor(p, tex, 0, LIP, h, tag="lip")
    p.ramp(ctx.pal["road"], LIP, LIP + run, -W // 2, W // 2, h - drop, h, "-a", "slide")
    _floor(p, tex, LIP + run, LIP + run + 800, h - drop, tag="landing")
    p.over = "floor"
    p.length = LIP + run + 800
    p.walk = p.length
    p.h_out = h - drop
    return p
def beat_fork(f, ctx, tex, name):
    if not ctx.has("longjump"):
        return None
    s, n = 300, 2
    lip = LIP + 400
    lj = cm.design_gap("longjump", 0, ctx.tier.depth_long, lip, ctx.need, ctx.grab)
    if lj is None:
        return None
    most = (lj - n * s) // (n + 1) // 50 * 50
    g = ctx.common_gap([("jump", 0, s, s, ctx.need + 1), ("jump", 0, s, lip, ctx.need + 1),
                        ("jump", 0, ctx.tier.depth_run, s, ctx.need + 1)], most=most)
    if not g or g < 200:
        return None
    span = n * (g + s) + g
    if cm.leeway("longjump", span, 0, ctx.tier.depth_long, lip, ctx.grab) < ctx.need:
        return None
    p = Plan(f, name)
    h = f.h
    _floor(p, tex, 0, lip, h, tag="lip")
    net = under(p, ctx, lip, lip + span)
    a = lip
    for k in range(n):
        for c in (-600, 600):
            p.box(tex, a + g, a + g + s, c - s // 2, c + s // 2, h - 200, h, "stone")
        p.move("gap", "jump", a, c=-600, gap=g, rise=0, depth=s, runup=lip if k == 0 else s,
               to_a=a + g, need=ctx.need + 1)
        a += g + s
    p.move("gap", "jump", a, c=-600, gap=g, rise=0, depth=ctx.tier.depth_run, runup=s,
           to_a=a + g, need=ctx.need + 1)
    land = max(_land_len(ctx, span, "longjump", net), ctx.tier.depth_long)
    _landing(p, tex, lip + span, lip + span + land, h, net)
    p.skips.append({"kind": "gap", "move": "longjump", "gap": span, "rise": 0,
                    "depth": ctx.tier.depth_long, "runup": lip, "a": lip, "c": 0, "h": h,
                    "to_a": lip + span, "over": p.over, "need": ctx.need, "skip": True})
    p.length = lip + span + land
    p.walk = lip + land + n * s
    return p
def beat_blj(f, ctx, tex, name):
    if not ctx.has("blj"):
        return None
    s = 400
    g = ctx.common_gap([("jump", 0, s, s, ctx.need + 1), ("jump", 0, s, LIP + 600, ctx.need + 1),
                        ("jump", 0, ctx.tier.depth_run, s, ctx.need + 1)], most=700)
    if not g:
        return None
    steps = max(3, int(math.ceil((3000 - g) / float(g + s))))
    span = steps * (g + s) + g
    if not cm.blj_leap(span, -200):
        return None
    p = Plan(f, name)
    h = f.h
    lip = LIP + 600
    _floor(p, tex, 0, lip, h, tag="lip")
    p.items.append(("stairs", ctx.pal.get("road") or tex, lip - 600, lip, -200, 200, h,
                    h + 200, "+a", "blj.stairs"))
    net = under(p, ctx, lip, lip + span)
    a = lip
    for k in range(steps):
        for c in (-600, 600):
            p.box(tex, a + g, a + g + s, c - s // 2, c + s // 2, h - 200, h, "stone")
        p.move("gap", "jump", a, c=-600, gap=g, rise=0, depth=s, runup=lip - 600 if k == 0
               else s, to_a=a + g, need=ctx.need + 1)
        a += g + s
    p.move("gap", "jump", a, c=-600, gap=g, rise=0, depth=ctx.tier.depth_run, runup=s,
           to_a=a + g, need=ctx.need + 1)
    land = _land_len(ctx, g, "jump", net)
    _landing(p, tex, lip + span, lip + span + land, h, net)
    p.skips.append({"kind": "blj", "move": "blj", "gap": span, "rise": -200, "a": lip, "c": 0,
                    "h": h + 200, "to_a": lip + span, "over": p.over, "need": 0,
                    "skip": True})
    p.length = lip + span + land
    p.walk = lip + land + steps * s
    return p
