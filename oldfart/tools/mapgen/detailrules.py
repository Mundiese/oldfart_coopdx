import random
from . import kit, roofs
TAG = "detail."
LIP = 20
LEDGE = 200
TRIM_H = LIP
POST = 100
FRAME = 40
LID = 200
ROCK = 200
DETAIL_SHARE = 0.25
class Ctx:
    def __init__(self, theme="castle", seed=1, pal=None):
        self.theme = theme
        self.rng = random.Random("detail:%s:%s" % (theme, seed))
        self._pal = pal
    def pal(self):
        if self._pal is None:
            try:
                from . import beauty, contract
                pal, _ = beauty.palette(self.theme if self.theme in kit.THEMES else "castle")
                pal = dict(pal)
                contract.split_roles(self.theme, pal)
            except Exception:
                pal = {}
            self._pal = pal
        return self._pal
    def tex(self, role, piece):
        t = self.pal().get(role)
        if isinstance(t, str):
            return t
        return kit.tex_key(piece) if hasattr(kit, "tex_key") else piece.get("tex")
def box(tex, x0, x1, y0, y1, z0, z1, rule):
    return kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, TAG + rule)
def rect(piece):
    w, d = piece.get("w", 0), piece.get("d", 0)
    if int(round(piece.get("yaw", 0))) % 180 == 90:
        w, d = d, w
    return (piece["x"] - w / 2.0, piece["x"] + w / 2.0, piece["z"] - d / 2.0,
            piece["z"] + d / 2.0)
def _words(piece):
    return str(piece.get("tag", "")).lower().replace(".", " ").replace("_", " ").split()
def _is_mass(p):
    return p.get("kind") in ("box", "ice") and p.get("h", 0) >= 200
def _is_opening(p):
    ws = set(_words(p))
    return p.get("kind") == "arch" or bool(ws & {"door", "doorway", "window", "gate", "arch"})
def _is_roof(p):
    return p.get("kind") in ("ridge", "pyramid") or "roof" in _words(p)
def _is_room(p):
    return p.get("kind") in ("box", "ice") and p.get("h", 0) >= 200 and \
        min(p.get("w", 0), p.get("d", 0)) >= 400
def _detail(p):
    return str(p.get("tag", "")).startswith((TAG, "dress."))
def make_trim(p, ctx):
    x0, x1, z0, z1 = rect(p)
    top = p["y"] + p["h"]
    return [box(ctx.tex("trim", p), x0 - LIP, x1 + LIP, top, top + TRIM_H, z0 - LIP, z1 + LIP,
                "trim")]
def make_roof(p, ctx):
    x0, x1, z0, z1 = rect(p)
    w, d = x1 - x0, z1 - z0
    over = LEDGE if min(w, d) >= 800 else 0
    top = p["y"] + p["h"]
    h = max(200, min(400, int(min(w, d) / 2 // 100 * 100)))
    along = "x" if w >= d else "z"
    out, _ = roofs.build("gable", ctx.tex("roof", p), x0 - over, x1 + over, z0 - over,
                         z1 + over, top, tag=TAG.rstrip("."), along=along, trim=None, height=h)
    return out
def make_frame(p, ctx):
    x0, x1, z0, z1 = rect(p)
    top = p["y"] + p["h"]
    tex = ctx.tex("trim", p)
    if x1 - x0 >= z1 - z0:
        return [box(tex, x0 - FRAME, x0, p["y"], top, z0, z1, "frame"),
                box(tex, x1, x1 + FRAME, p["y"], top, z0, z1, "frame"),
                box(tex, x0 - FRAME, x1 + FRAME, top, top + LIP, z0, z1, "frame")]
    return [box(tex, x0, x1, p["y"], top, z0 - FRAME, z0, "frame"),
            box(tex, x0, x1, p["y"], top, z1, z1 + FRAME, "frame"),
            box(tex, x0, x1, top, top + LIP, z0 - FRAME, z1 + FRAME, "frame")]
def make_plinth(p, ctx):
    x0, x1, z0, z1 = rect(p)
    h = min(LEDGE, p["h"])
    return [box(ctx.tex("cover", p), x0 - LIP, x1 + LIP, p["y"], p["y"] + h, z0 - LIP, z1 + LIP,
                "plinth")]
def make_posts(p, ctx):
    x0, x1, z0, z1 = rect(p)
    top = p["y"] + p["h"]
    tex = ctx.tex("trim", p)
    out = []
    for x in (x0, x1):
        for z in (z0, z1):
            out.append(kit.kind("pillar").make(tex, x - POST / 2, x + POST / 2, p["y"], top,
                                               z - POST / 2, z + POST / 2, None, TAG + "posts"))
    return out
def make_ridge(p, ctx):
    x0, x1, z0, z1 = rect(p)
    top = p["y"] + p["h"]
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    tex = ctx.tex("trim", p)
    along_x = (x1 - x0) >= (z1 - z0)
    if along_x:
        return [box(tex, x0, x1, top - TRIM_H / 2, top + TRIM_H / 2, cz - TRIM_H / 2,
                    cz + TRIM_H / 2, "ridge")]
    return [box(tex, cx - TRIM_H / 2, cx + TRIM_H / 2, top - TRIM_H / 2, top + TRIM_H / 2, z0, z1,
                "ridge")]
def make_lid(p, ctx):
    x0, x1, z0, z1 = rect(p)
    top = p["y"] + p["h"]
    return [box(ctx.tex("cover", p), x0 - LID, x1 + LID, top, top + TRIM_H, z0 - LID, z1 + LID,
                "lid")]
def make_step(p, ctx):
    x0, x1, z0, z1 = rect(p)
    tex = ctx.tex("path", p)
    y = p["y"]
    if x1 - x0 >= z1 - z0:
        return [box(tex, x0, x1, y, y + LIP, z0 - 200, z0, "step"),
                box(tex, x0, x1, y, y + LIP, z1, z1 + 200, "step")]
    return [box(tex, x0 - 200, x0, y, y + LIP, z0, z1, "step"),
            box(tex, x1, x1 + 200, y, y + LIP, z0, z1, "step")]
def make_rocks(p, ctx):
    x0, x1, z0, z1 = rect(p)
    y = p["y"]
    tex = ctx.tex("cover", p)
    sides = [("+x", x1, None), ("-x", x0, None), ("+z", None, z1), ("-z", None, z0)]
    ctx.rng.shuffle(sides)
    out = []
    for name, x, z in sides[:ctx.rng.choice((2, 3, 4))]:
        if x is not None:
            cz = ctx.rng.uniform(z0 + ROCK / 2, max(z0 + ROCK / 2, z1 - ROCK / 2))
            lo, hi = (x, x + ROCK) if name == "+x" else (x - ROCK, x)
            rises = "-x" if name == "+x" else "+x"
            out.append(kit.kind("ramp").make(tex, lo, hi, y, y + ROCK, cz - ROCK / 2,
                                             cz + ROCK / 2, rises, TAG + "rocks"))
        else:
            cx = ctx.rng.uniform(x0 + ROCK / 2, max(x0 + ROCK / 2, x1 - ROCK / 2))
            lo, hi = (z, z + ROCK) if name == "+z" else (z - ROCK, z)
            rises = "-z" if name == "+z" else "+z"
            out.append(kit.kind("ramp").make(tex, cx - ROCK / 2, cx + ROCK / 2, y, y + ROCK, lo,
                                             hi, rises, TAG + "rocks"))
    return out
class Rule:
    __slots__ = ("id", "verb", "about", "applies", "make", "delegate", "tier")
    def __init__(self, id, verb, about, applies, make=None, delegate=None, tier="A"):
        self.id, self.verb, self.about = id, verb, about
        self.applies, self.make, self.delegate, self.tier = applies, make, delegate, tier
RULES = {r.id: r for r in (
    Rule("roof", "Roof this", "a ridge roof in the theme's roof texture, overhanging 200 on a "
         "big house", _is_room, make_roof),
    Rule("trim", "Trim this", "a cap band on the top edge, out 20", _is_mass, make_trim),
    Rule("plinth", "Plinth", "a base band at the foot, 200 high (a ledge), out 20", _is_mass,
         make_plinth),
    Rule("posts", "Corner posts", "a post on each corner, the piece's height", _is_mass,
         make_posts),
    Rule("frame", "Frame openings", "posts and a lintel round a door, window or arch",
         _is_opening, make_frame),
    Rule("step", "Step to the door", "a 20 threshold before and behind an opening, 200 deep",
         _is_opening, make_step),
    Rule("ridge", "Ridge line", "a ridge along a roof's top", _is_roof, make_ridge, tier="B"),
    Rule("lid", "Overhang lid", "a cliff-top lid out 200 on every side",
         lambda p: _is_mass(p) and p.get("h", 0) >= 400, make_lid, tier="B"),
    Rule("rocks", "Rocks at the foot", "two to four wedges of rock leaning on a tall mass",
         lambda p: _is_mass(p) and p.get("h", 0) >= 400, make_rocks, tier="B"),
    Rule("soften", "Soften steps", "ramps and corners on the ground's one-layer steps "
         "(auto-shape)", lambda p: p.get("kind") in ("box", "ice"), delegate="autoshape",
         tier="B"),
    Rule("rails", "Rail the edges", "rails along floor edges over a drop of 400+ (dress R3)",
         lambda p: p.get("kind") == "box", delegate="dress:trims", tier="B"),
    Rule("legs", "Columns under", "columns under a mass floating a little (dress R10)",
         lambda p: p.get("kind") == "box", delegate="dress:legs", tier="B"),
)}
ORDER = list(RULES)
def apply(rule_id, pieces, ctx):
    rule = RULES[rule_id]
    if rule.make is None:
        return []
    out = []
    for p in pieces:
        if rule.applies(p):
            out += rule.make(p, ctx)
    return out
def _overlap(a, b):
    return max(0.0, min(a[1], b[1]) - max(a[0], b[0])) * \
        max(0.0, min(a[3], b[3]) - max(a[2], b[2])) * \
        max(0.0, min(a[5], b[5]) - max(a[4], b[4]))
def _aabb(p):
    x0, x1, z0, z1 = rect(p)
    return (x0, x1, p["y"], p["y"] + p["h"], z0, z1)
def bands(pieces, new, theme="castle"):
    from . import guards
    every = list(pieces) + list(new)
    out = []
    def band(name, value, limit, bad_over, text):
        state = "ok" if value <= limit else ("bad" if bad_over else "warn")
        out.append({"name": name, "value": value, "limit": limit, "state": state, "text": text})
    li = guards.lips(every, new) if new else []
    band("G1 lips", len(li), 0, True, li[0]["text"] if li else
         "every lip on a walked floor is <= 20 or >= 200")
    ch = guards.chimneys(every, new) if new else []
    band("G4 chimneys", len(ch), 0, True, ch[0]["text"] if ch else
         "no new wall-kick ladder (parallel faces 101-1050 apart)")
    na = [n for n in (guards.narrows(every, new) if new else [])
          if not any(n["other"] is q for q in new)]
    band("G7 lanes", len(na), 0, True, na[0]["text"] if na else
         "no lane narrowed under 400")
    try:
        from . import contract
        iss = contract.issues({"pieces": list(new)}, theme)
    except Exception:
        iss = []
    hard = [i for i in iss if i["refused"]]
    band("Contract", len(hard), 0, True, hard[0]["text"] if hard else
         ("%d warn(s): %s" % (len(iss), iss[0]["text"]) if iss else
          "every new piece wears its class's material"))
    shared = 0
    boxes = [_aabb(p) for p in pieces]
    for q in new:
        b = _aabb(q)
        if any(_overlap(b, a) > 1 for a in boxes):
            shared += 1
    band("Shared space", shared, len(new), False,
         "%d new piece(s) share space with the old (painted like the generator's)" % shared)
    detail = sum(1 for p in every if _detail(p))
    share = detail / float(max(1, len(every)))
    out.append({"name": "Detail share", "value": round(share, 2), "limit": DETAIL_SHARE,
                "state": "ok" if share <= DETAIL_SHARE else "warn",
                "text": "%d of %d pieces are detail (R12: a quarter at most)" % (detail,
                                                                                 len(every))})
    return out
def worst(bands_):
    states = [b["state"] for b in bands_]
    return "bad" if "bad" in states else "warn" if "warn" in states else "ok"
