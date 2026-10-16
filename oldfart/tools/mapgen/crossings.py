import math
DECK = 30
RAIL_H = 300
RAIL_T = 60
PARAPET_H = 200
SWIM_CLEAR = 200
STONE_GAP = 400
STONE_GAP_DEEP = 600
JUMP_GAP_MAX = 500
DRY_DROP_RAILS = 600
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return {"kind": "box", "tex": tex, "x": (x0 + x1) / 2.0, "y": y0, "z": (z0 + z1) / 2.0,
            "w": x1 - x0, "h": y1 - y0, "d": z1 - z0, "yaw": 0, "tag": tag}
def _span_box(along, a0, a1, c, half, y0, y1, tex, tag):
    if along == "x":
        return _box(tex, a0, a1, y0, y1, c - half, c + half, tag)
    return _box(tex, c - half, c + half, y0, y1, a0, a1, tag)
def plank(along, a0, a1, c, width, y, tex, tag="bridge.plank"):
    return [_span_box(along, a0, a1, c, width / 2.0, y - DECK, y, tex, tag)]
def plank_rails(along, a0, a1, c, width, y, tex, rail_tex, posts=False, tag="bridge.rails",
                sides=(-1, 1)):
    out = plank(along, a0, a1, c, width, y, tex, tag + ".deck")
    for side in sides:
        cc = c + side * (width / 2.0 - RAIL_T / 2.0)
        out.append(_span_box(along, a0, a1, cc, RAIL_T / 2.0, y + RAIL_H - 40, y + RAIL_H,
                             rail_tex, tag + ".rail"))
        if posts:
            for a in (a0, a1 - RAIL_T):
                out.append(_span_box(along, a, a + RAIL_T, cc, RAIL_T / 2.0, y, y + RAIL_H,
                                     rail_tex, tag + ".post"))
    return out
def stone_arch(along, a0, a1, c, width, y, water, tex, trim_tex, arch_kind=None,
               tag="bridge.arch", sides=(-1, 1)):
    out = []
    span = a1 - a0
    floor = (water if water is not None else y - 600)
    deck_y = y
    half = width / 2.0
    out.append(_span_box(along, a0, a1, c, half, deck_y - 100, deck_y, tex, tag + ".deck"))
    for side in sides:
        cc = c + side * (half - 50)
        out.append(_span_box(along, a0, a1, cc, 50, deck_y, deck_y + PARAPET_H, trim_tex,
                             tag + ".parapet"))
    if arch_kind is not None and span >= 400 and span > width \
            and deck_y - 200 - floor >= 100:
        rise = min(span / 2.0, max(100, deck_y - 100 - floor))
        x0, x1 = (a0, a1) if along == "x" else (c - half, c + half)
        z0, z1 = (c - half, c + half) if along == "x" else (a0, a1)
        p = arch_kind(tex, x0, x1, deck_y - 100 - rise, deck_y - 100, z0, z1,
                      tag=tag + ".arch")
        if p is not None:
            out.append(p)
    return out, deck_y
def humpback(along, a0, a1, c, width, y, water, tex, rail_tex, ramp_kind,
             tag="bridge.humpback"):
    out = []
    span = a1 - a0
    rise = 200
    run = min(400, span / 3.0)
    top = y + rise
    half = width / 2.0
    lo_dir, hi_dir = ("+x", "-x") if along == "x" else ("+z", "-z")
    if ramp_kind is None:
        return plank_rails(along, a0, a1, c, width, y, tex, rail_tex)
    if along == "x":
        out.append(ramp_kind(tex, a0, a0 + run, y, top, c - half, c + half, lo_dir, tag + ".ramp"))
        out.append(ramp_kind(tex, a1 - run, a1, y, top, c - half, c + half, hi_dir, tag + ".ramp"))
    else:
        out.append(ramp_kind(tex, c - half, c + half, y, top, a0, a0 + run, lo_dir, tag + ".ramp"))
        out.append(ramp_kind(tex, c - half, c + half, y, top, a1 - run, a1, hi_dir, tag + ".ramp"))
    out.append(_span_box(along, a0 + run, a1 - run, c, half, top - DECK, top, tex, tag + ".top"))
    for side in (-1, 1):
        cc = c + side * (half - RAIL_T / 2.0)
        out.append(_span_box(along, a0 + run, a1 - run, cc, RAIL_T / 2.0, top + RAIL_H - 40,
                             top + RAIL_H, rail_tex, tag + ".rail"))
    return out
def rope(along, a0, a1, c, width, y, tex, rope_tex, post_tex, tag="bridge.rope"):
    span = a1 - a0
    n = max(3, min(5, int(span // 400) or 3))
    if n % 2 == 0:
        n += 1
    seg = span / float(n)
    out = []
    mid = n // 2
    for k in range(n):
        drop = 50 * min(k, n - 1 - k)
        out.append(_span_box(along, a0 + k * seg, a0 + (k + 1) * seg, c, width / 2.0,
                             y - drop - DECK, y - drop, tex, tag + ".deck"))
    sag = 50 * mid
    for side in (-1, 1):
        cc = c + side * (width / 2.0 - 20)
        out.append(_span_box(along, a0, a1, cc, 20, y + 240 - sag // 2, y + 280 - sag // 2,
                             rope_tex, tag + ".rope"))
        for a in (a0 - 80, a1):
            out.append(_span_box(along, a, a + 80, cc, 40, y - 200, y + 400, post_tex,
                                 tag + ".post"))
    return out
def log(along, a0, a1, c, y, tex, tag="bridge.log"):
    return [_span_box(along, a0, a1, c, 100, y - 200, y, tex, tag)]
def covered(along, a0, a1, c, width, y, tex, rail_tex, roof_tex, roof_kind,
            tag="bridge.covered", sides=(-1, 1)):
    out = plank_rails(along, a0, a1, c, width, y, tex, rail_tex, posts=True, tag=tag,
                      sides=sides)
    half = width / 2.0
    for side in (-1, 1):
        cc = c + side * (half - 40)
        for a in (a0, a1 - 80):
            out.append(_span_box(along, a, a + 80, cc, 40, y, y + 900, rail_tex, tag + ".post"))
    if roof_kind is not None:
        x0, x1 = (a0 - 100, a1 + 100) if along == "x" else (c - half - 100, c + half + 100)
        z0, z1 = (c - half - 100, c + half + 100) if along == "x" else (a0 - 100, a1 + 100)
        p = roof_kind(roof_tex, x0, x1, y + 900, y + 1300, z0, z1, along, tag + ".roof")
        if p is not None:
            out.append(p)
    return out
def stepping_stones(along, a0, a1, c, y_ground, water, deep, stone_key="steppingstone",
                    r=None, tag="bridge.stones"):
    from . import decor
    span = a1 - a0
    step = STONE_GAP if not deep else 500
    n = max(1, int(math.ceil(span / float(step))) - 1)
    stones = []
    top = (water + 30) if water is not None else y_ground
    for k in range(n):
        a = a0 + (k + 1) * span / float(n + 1)
        off = 0
        if deep and n >= 3 and k >= n // 2:
            off = 100 if (r is None or r.random() < 0.5) else -100
        x, z = (a, c + off) if along == "x" else (c + off, a)
        p = decor.piece(stone_key, x, top - 40, z, 0, tag=tag)
        stones.append(p)
    return stones
def boardwalk(cells, cell, level, tex, post_tex, off, tag="boardwalk"):
    out = []
    if not cells:
        return out
    run = [cells[0]]
    def flush(run):
        i0 = min(c[0] for c in run)
        i1 = max(c[0] for c in run)
        j0 = min(c[1] for c in run)
        j1 = max(c[1] for c in run)
        y = level(run[0])
        x0, x1 = off + i0 * cell, off + (i1 + 1) * cell
        z0, z1 = off + j0 * cell, off + (j1 + 1) * cell
        if i0 == i1:
            x0, x1 = x0 + cell / 4.0, x1 - cell / 4.0
        else:
            z0, z1 = z0 + cell / 4.0, z1 - cell / 4.0
        out.append(_box(tex, x0, x1, y - DECK, y, z0, z1, tag + ".deck"))
    for c in cells[1:]:
        prev = run[-1]
        same = len(run) < 2 or (run[0][0] == c[0] == prev[0]) or (run[0][1] == c[1] == prev[1])
        if abs(c[0] - prev[0]) + abs(c[1] - prev[1]) == 1 and same:
            run.append(c)
        else:
            flush(run)
            run = [c]
    flush(run)
    return out
def pole(x, y, z, height=None, tag="climb.pole"):
    o = {"key": "pole", "what": "climbing pole", "x": x, "y": y, "z": z, "yaw": 0,
         "pattern": tag}
    if height:
        o["height"] = height
    return o
def vine(x, y, z, yaw, height, tex, tag="climb.vine"):
    a = math.radians(yaw)
    w, d = 160, 20
    return {"kind": "box", "tex": tex, "x": x, "y": y, "z": z, "w": w, "h": height, "d": d,
            "yaw": yaw, "tag": tag}
LAND_STEP = 50
def ends_land(along, a0, a1, c, y, under, reach=100, width=None):
    pts = ((a0 - reach, c), (a1 + reach, c)) if along == "x" else ((c, a0 - reach), (c, a1 + reach))
    got = [under(x, z) for x, z in pts]
    def ok(g):
        return g is not None and abs(g - y) <= LAND_STEP
    if all(ok(g) for g in got):
        return True, got
    if width is None:
        return False, got
    h = width / 2.0 + reach
    for m in sorted(set((a0 + width / 2.0, a1 - width / 2.0))):
        side = ((m, c - h), (m, c + h)) if along == "x" else ((c - h, m), (c + h, m))
        got += [under(x, z) for x, z in side]
    return sum(1 for g in got if ok(g)) >= 2 and any(ok(g) for g in got[:2]), got
def seat_posts(pieces, under):
    out, dropped = [], []
    decks = [p for p in pieces if not str(p.get("tag", "")).endswith(".post")]
    for p in pieces:
        if not str(p.get("tag", "")).endswith(".post"):
            out.append(p)
            continue
        on_deck = any(abs(d["y"] + d["h"] - p["y"]) <= 3
                      and abs(d["x"] - p["x"]) <= (d["w"] + p["w"]) / 2.0
                      and abs(d["z"] - p["z"]) <= (d["d"] + p["d"]) / 2.0 for d in decks)
        if on_deck:
            out.append(p)
            continue
        g = under(p["x"], p["z"])
        top = p["y"] + p["h"]
        if g is None or g >= top - 100:
            dropped.append(p)
            continue
        if g < p["y"]:
            p = dict(p, y=g, h=top - g)
        out.append(p)
    return out, dropped
ROAD_TYPES = ("arch", "covered", "rails")
MAIN_TYPES = ("arch", "covered")
FOOT_TYPES = ("plank", "rope", "stones", "log")
class Chooser:
    def __init__(self, r, theme=None):
        self.r = r
        self.main = "covered" if theme in ("village", "forest", "wood") and r.random() < 0.5 \
            else "arch"
        self.foot = None
    def for_class(self, cls, span, deep, dry=False):
        if cls == "main":
            return self.main if span <= 1600 else "rails"
        if cls == "road":
            return "rails"
        if self.foot is None:
            self.foot = "stones" if not dry and self.r.random() < 0.4 else \
                ("rope" if self.r.random() < 0.5 else "plank")
        kind = self.foot
        if kind == "stones" and (span > 2400 or dry):
            kind = "rope" if span >= 1200 else "plank"
        if kind == "rope" and span < 800:
            kind = "plank"
        return kind
def feet_faults(arena):
    from . import v1
    m = v1.arenas_module()
    side_parts = (".rail", ".parapet", ".rope", ".post", ".roof")
    pieces = [p for p in arena["pieces"] if p.get("kind") != "water"
              and p.get("tex") != "invisible" and not str(p.get("tag", "")).endswith(side_parts)]
    def top_under(x, z, lo, hi, skip):
        best = None
        for q in pieces:
            if q is skip:
                continue
            x0, x1, z0, z1, _ = m.footprint(q)
            if not (x0 <= x <= x1 and z0 <= z <= z1) or not m.covers(q, x, z):
                continue
            t = m.top_at(q, x, z)
            if t is not None and lo <= t <= hi and (best is None or t > best):
                best = t
        return best
    n = 0
    for p in arena["pieces"]:
        tag = str(p.get("tag", ""))
        if not tag.startswith("bridge"):
            continue
        if tag.endswith(".post"):
            if top_under(p["x"], p["z"], p["y"] - 3, p["y"] + p["h"] - 100, p) is None:
                n += 1
        elif tag.endswith((".deck", ".plank", ".foot")) and p.get("kind") == "box":
            x0, x1, z0, z1, _ = m.footprint(p)
            y = p["y"] + p["h"]
            cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
            along_x = (x1 - x0) >= (z1 - z0)
            ends = ((x0 - 50, cz), (x1 + 50, cz)) if along_x else ((cx, z0 - 50), (cx, z1 + 50))
            sides = ((cx, z0 - 50), (cx, z1 + 50)) if along_x else ((x0 - 50, cz), (x1 + 50, cz))
            got = [top_under(x, z, y - LAND_STEP, y + LAND_STEP, p) is not None
                   for x, z in ends + sides]
            if sum(got) < 2:
                n += 1
    for o in arena.get("objects") or []:
        if o.get("key") != "pole":
            continue
        tol = 60 if o.get("air") else 30
        if top_under(o["x"], o["z"], o["y"] - tol, o["y"] + tol, None) is None:
            n += 1
    return n
