import math
from ..metrics import v1
from ..metrics.world import footprint
BG = (24, 24, 34)
INK = (235, 235, 240)
DIM = (170, 170, 185)
SPAWN = (80, 230, 120)
FIELD = (150, 255, 190)
GOLD = (255, 210, 60)
RED = (235, 80, 70)
BLUE = (80, 140, 255)
SIDES = ("top", "bottom", "front", "back", "left", "right")
def _pil():
    from PIL import Image, ImageDraw
    return Image, ImageDraw
def colour_of(tex, colours):
    if tex in colours:
        return colours[tex]
    h = sum(ord(c) * (i + 7) for i, c in enumerate(tex or "?"))
    return (90 + h % 100, 90 + (h // 7) % 100, 90 + (h // 49) % 100)
def shade(rgb, f):
    return tuple(max(0, min(255, int(c * f))) for c in rgb)
SLOPED = ("ramp", "stairs", "outer", "inner", "outerstairs", "innerstairs")
CORNER_KINDS = ("outer", "inner", "outerstairs", "innerstairs")
def _top(p, x, z):
    return v1.tool().top_at(p, x, z)
def outline_xz(p):
    x0, x1, z0, z1, up = footprint(p)
    if p["kind"] == "prism":
        ma = v1.tool()
        pts = []
        for (x, z) in ((x0, z0), (x1, z0), (x1, z1), (x0, z1)):
            ix = x + (1 if x == x0 else -1)
            iz = z + (1 if z == z0 else -1)
            if ma.covers(p, ix, iz):
                pts.append((x, z))
        return pts if len(pts) >= 3 else [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    if p["kind"] == "pillar":
        slopes = v1.tool().slopes
        h, c = slopes.PILLAR_HALF, slopes.PILLAR_CUT
        s, co = math.sin(math.radians(p["yaw"])), math.cos(math.radians(p["yaw"]))
        out = []
        for lx, lz in ((h, c), (c, h), (-c, h), (-h, c), (-h, -c), (-c, -h), (c, -h), (h, -c)):
            ax, az = lx / 200.0 * p["w"], lz / 200.0 * p["d"]
            out.append((p["x"] + ax * co + az * s, p["z"] - ax * s + az * co))
        return out
    if p["kind"] in ("curve", "bank", "arcwall"):
        ma = v1.tool()
        ratio = ma.ARC_KINDS[p["kind"]][0]
        outer, inner = ma.arc_points(ratio)
        ring = list(outer) + (list(reversed(inner)) if inner else [(ma.LO, ma.LO)])
        s, co = math.sin(math.radians(p["yaw"])), math.cos(math.radians(p["yaw"]))
        out = []
        for lx, lz in ring:
            ax, az = lx / 200.0 * p["w"], lz / 200.0 * p["d"]
            out.append((p["x"] + ax * co + az * s, p["z"] - ax * s + az * co))
        return out
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
def _rects(arena):
    out = []
    for p in arena["pieces"]:
        if p.get("tex") == "invisible":
            continue
        x0, x1, z0, z1, up = footprint(p)
        out.append((p, x0, x1, z0, z1, up))
    return out
def extents(arena):
    rs = [r for r in _rects(arena)
          if not str(r[0].get("tag", "")).startswith("dress.backdrop")] or _rects(arena)
    xs = [r[1] for r in rs] + [r[2] for r in rs]
    zs = [r[3] for r in rs] + [r[4] for r in rs]
    ys = [r[0]["y"] for r in rs] + [r[0]["y"] + r[0]["h"] for r in rs]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)
class Plan(object):
    def __init__(self, arena, size=900, margin=400):
        x0, x1, _, _, z0, z1 = extents(arena)
        cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        half = max(x1 - x0, z1 - z0) / 2.0 + margin
        self.lo_x, self.lo_z = cx - half, cz - half
        self.scale = size / (2.0 * half)
        self.size = size
    def px(self, x, z):
        return ((x - self.lo_x) * self.scale, (z - self.lo_z) * self.scale)
def top_down(arena, size=900, heat=None, heat_label=None, lines=None, exposure=None,
             title=None, legend=True):
    Image, ImageDraw = _pil()
    colours = v1.texture_colours()
    plan = Plan(arena, size)
    px = plan.px
    foot = 96 if legend else 0
    im = Image.new("RGB", (size, size + foot), BG)
    d = ImageDraw.Draw(im, "RGBA")
    rects = _rects(arena)
    tops = [r[0]["y"] + max(r[0]["h"], 0) for r in rects]
    t_lo, t_hi = min(tops), max(tops)
    order = sorted(range(len(rects)), key=lambda i: (tops[i], i))
    for i in order:
        p, x0, x1, z0, z1, up = rects[i]
        lift = (tops[i] - t_lo) / float(max(1, t_hi - t_lo))
        fill = shade(colour_of(p.get("tex"), colours), 0.5 + 0.5 * lift)
        d.polygon([px(x, z) for x, z in outline_xz(p)], fill=fill, outline=(10, 10, 10))
        if p["kind"] in CORNER_KINDS:
            ma = v1.tool()
            cs = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
            hs = [ma.top_at(p, x + (2 if x == x0 else -2), z + (2 if z == z0 else -2)) or 0 for x, z in cs]
            hi = cs[hs.index(max(hs))]
            lo = cs[hs.index(min(hs))]
            d.line([px(*lo), px(*hi)], fill=(255, 255, 255), width=2)
            hx, hz = px(*hi)
            d.ellipse([hx - 3, hz - 3, hx + 3, hz + 3], fill=(255, 255, 255))
        if p["kind"] in ("ramp", "stairs"):
            cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
            ex, ez = cx + up[0] * (x1 - x0) * 0.35, cz + up[1] * (z1 - z0) * 0.35
            sx, sz = cx - up[0] * (x1 - x0) * 0.35, cz - up[1] * (z1 - z0) * 0.35
            d.line([px(sx, sz), px(ex, ez)], fill=(255, 255, 255), width=2)
            hx, hz = px(ex, ez)
            d.ellipse([hx - 3, hz - 3, hx + 3, hz + 3], fill=(255, 255, 255))
            if p["kind"] == "stairs":
                for k in range(1, 10):
                    t = k / 10.0
                    if up[0]:
                        xx = x0 + (x1 - x0) * (t if up[0] > 0 else 1 - t)
                        d.line([px(xx, z0), px(xx, z1)], fill=(0, 0, 0, 90))
                    else:
                        zz = z0 + (z1 - z0) * (t if up[1] > 0 else 1 - t)
                        d.line([px(x0, zz), px(x1, zz)], fill=(0, 0, 0, 90))
    if heat:
        vmax = max(heat.values()) or 1
        cell = 100 * plan.scale
        for (gx, gz), v in heat.items():
            if v <= 0:
                continue
            t = min(1.0, v / float(vmax)) ** 0.5
            col = heat_colour(t)
            x, z = px(gx * 100, gz * 100)
            d.rectangle([x, z, x + cell, z + cell], fill=col + (int(60 + 150 * t),))
    for seg in lines or []:
        a, b = seg[0], seg[1]
        col = seg[2] if len(seg) > 2 else GOLD
        d.line([px(a[0], a[2]), px(b[0], b[2])], fill=col, width=2)
    survey = arena.get("survey", {}) or {}
    spawn_keys = set((s["x"], s["z"]) for s in arena.get("spawns", []))
    for p in survey.get("points", []) or []:
        if isinstance(p, dict) and (p["x"], p["z"]) not in spawn_keys:
            x, z = px(p["x"], p["z"])
            d.ellipse([x - 7, z - 7, x + 7, z + 7], outline=FIELD, width=2)
    for i, s in enumerate(arena.get("spawns", [])):
        x, z = px(s["x"], s["z"])
        fill = SPAWN
        if exposure and i < len(exposure):
            fill = heat_colour(min(1.0, exposure[i] / 0.3))
        d.ellipse([x - 6, z - 6, x + 6, z + 6], fill=fill, outline=(0, 0, 0))
        yaw = math.radians(s.get("yaw", 0))
        d.line([(x, z), (x + 11 * math.sin(yaw), z + 11 * math.cos(yaw))], fill=(0, 0, 0), width=2)
        d.text((x + 7, z - 7), str(i + 1), fill=(220, 255, 220))
    for key, col, label in (("ctfRed", RED, "red flag"), ("ctfBlue", BLUE, "blue flag"),
                            ("hill", GOLD, "hill")):
        p = survey.get(key)
        if isinstance(p, dict):
            x, z = px(p["x"], p["z"])
            d.polygon([(x, z - 10), (x + 9, z + 7), (x - 9, z + 7)], fill=col, outline=(0, 0, 0))
    for m in arena.get("markers", []) or []:
        if m.get("kind") == 16:
            x, z = px(m["x"], m["z"])
            d.rectangle([x - 4, z - 4, x + 4, z + 4], outline=GOLD, width=2)
            d.text((x + 6, z - 6), str(m.get("num", "")), fill=(255, 230, 140))
        elif m.get("kind") == 1:
            x, z = px(m["x"], m["z"])
            d.rectangle([x - 6, z - 6, x + 6, z + 6], fill=(255, 255, 255), outline=(0, 0, 0))
    for m in arena.get("marks", []) or []:
        if m.get("label", "").startswith("G") and m.get("kind") == 16:
            continue
        if "kind" in m:
            continue
        x, z = px(m["x"], m["z"])
        d.rectangle([x - 5, z - 5, x + 5, z + 5], outline=GOLD, width=2)
        d.text((x + 7, z - 7), m.get("label", ""), fill=(255, 230, 140))
    item_cols = {"enemies": (235, 80, 70), "hazards": (255, 140, 40), "movers": (90, 200, 255),
                 "items": (255, 225, 80), "scenery": (140, 225, 110)}
    if arena.get("objects"):
        from .. import gameplay as _gp
        for o in arena["objects"]:
            x, z = px(o["x"], o["z"])
            col = item_cols.get(_gp.category_of(o.get("key")), (220, 220, 220))
            d.rectangle([x - 3, z - 3, x + 3, z + 3], fill=col, outline=(0, 0, 0))
    for st in arena.get("stars", []) or []:
        x, z = px(st["x"], st["z"])
        pts = []
        for k in range(10):
            r = 11 if k % 2 == 0 else 5
            a = math.pi / 2 + k * math.pi / 5
            pts.append((x + r * math.cos(a), z - r * math.sin(a)))
        d.polygon(pts, fill=GOLD, outline=(0, 0, 0))
        d.text((x + 12, z - 8), "%d %s (%d)" % (st.get("id", 0), st["kind"], st["grade"]),
               fill=(255, 235, 150))
    d.text((size - 22, 8), "N", fill=INK)
    d.line([(size - 18, 22), (size - 18, 40)], fill=INK, width=2)
    d.polygon([(size - 18, 20), (size - 22, 28), (size - 14, 28)], fill=INK)
    if legend:
        y = size + 14
        d.line([(20, y), (20 + 1000 * plan.scale, y)], fill=INK, width=3)
        d.text((24, y + 6), "1000 units", fill=INK)
        name = title or "%s on %s" % (arena.get("key", "?"), arena.get("level", "?"))
        d.text((200, y - 6), "%s - %d pieces, %d spawns" % (name, len(rects), len(arena.get("spawns", []))),
               fill=INK)
        d.text((200, y + 10), "brighter = higher (%d .. %d); white arrows point up ramps; "
               "rings = field spawns; triangles = flags/hill" % (t_lo, t_hi), fill=DIM)
        if heat:
            d.text((200, y + 26), heat_label or "overlay: heat (blue low .. red high)", fill=DIM)
        for k in range(100):
            t = k / 99.0
            d.line([(size - 140 + k, y + 40), (size - 140 + k, y + 52)], fill=shade((200, 200, 210), 0.5 + 0.5 * t))
        d.text((size - 140, y + 56), "%d" % t_lo, fill=DIM)
        d.text((size - 50, y + 56), "%d" % t_hi, fill=DIM)
    return im
def heat_colour(t):
    stops = [(0.0, (40, 70, 220)), (0.35, (40, 200, 220)), (0.65, (250, 220, 60)), (1.0, (235, 50, 40))]
    for k in range(len(stops) - 1):
        a, ca = stops[k]
        b, cb = stops[k + 1]
        if t <= b:
            f = (t - a) / (b - a) if b > a else 0
            return tuple(int(ca[i] + (cb[i] - ca[i]) * f) for i in range(3))
    return stops[-1][1]
def _profile(p, x0, x1, z0, z1, up, side):
    y0, y1 = p["y"], p["y"] + p["h"]
    if side in ("top", "bottom"):
        return [(x if side == "top" else -x, z) for x, z in outline_xz(p)]
    if side == "front":
        u0, u1, along = x0, x1, up[0]
    elif side == "back":
        u0, u1, along = -x1, -x0, -up[0]
    elif side == "right":
        u0, u1, along = -z1, -z0, -up[1]
    else:
        u0, u1, along = z0, z1, up[1]
    if p["kind"] in ("box", "rail", "arch") or (p["kind"] in ("ramp", "stairs") and along == 0):
        return [(u0, y0), (u1, y0), (u1, y1), (u0, y1)]
    if p["kind"] not in ("ramp", "stairs"):
        n = 16
        pts = []
        for k in range(n + 1):
            f = k / float(n)
            best = None
            for j in range(n + 1):
                g = j / float(n)
                if side in ("front", "back"):
                    x = x0 + (x1 - x0) * (f if side == "front" else 1 - f)
                    z = z0 + (z1 - z0) * g
                else:
                    z = z0 + (z1 - z0) * (f if side == "left" else 1 - f)
                    x = x0 + (x1 - x0) * g
                x = min(max(x, x0 + 0.5), x1 - 0.5)
                z = min(max(z, z0 + 0.5), z1 - 0.5)
                t = _top(p, x, z)
                if t is not None and (best is None or t > best):
                    best = t
            pts.append((u0 + (u1 - u0) * f, best))
        tops = [(u, t) for u, t in pts if t is not None]
        if len(tops) < 2:
            return [(u0, y0), (u1, y0), (u1, y1), (u0, y1)]
        return [(tops[0][0], y0)] + tops + [(tops[-1][0], y0)]
    lo_u, hi_u = (u0, u1) if along > 0 else (u1, u0)
    if p["kind"] == "stairs":
        pts = [(lo_u, y0)]
        for k in range(10):
            ua = lo_u + (hi_u - lo_u) * k / 10.0
            ub = lo_u + (hi_u - lo_u) * (k + 1) / 10.0
            yy = y0 + (y1 - y0) * (k + 1) / 10.0
            pts += [(ua, yy), (ub, yy)]
        pts += [(hi_u, y0)]
        return pts
    return [(lo_u, y0), (hi_u, y1), (hi_u, y0)]
def _depth(p, x0, x1, z0, z1, side):
    y0, y1 = p["y"], p["y"] + p["h"]
    return {"top": (y1, y0), "bottom": (-y0, -y1), "front": (z1, z0), "back": (-z0, -z1),
            "right": (x1, x0), "left": (-x0, -x1)}[side]
def ortho(arena, side, size=900, scale=None):
    Image, ImageDraw = _pil()
    colours = v1.texture_colours()
    x0, x1, y0, y1, z0, z1 = extents(arena)
    rects = _rects(arena)
    if side in ("top", "bottom"):
        ur = (x0, x1) if side == "top" else (-x1, -x0)
        vr = (z0, z1)
    elif side in ("front", "back"):
        ur = (x0, x1) if side == "front" else (-x1, -x0)
        vr = (y0, y1)
    else:
        ur = (-z1, -z0) if side == "right" else (z0, z1)
        vr = (y0, y1)
    margin = 300
    span = max(ur[1] - ur[0], vr[1] - vr[0]) + 2 * margin
    if scale is None:
        scale = size / float(span)
    w = int((ur[1] - ur[0] + 2 * margin) * scale) + 1
    h = int((vr[1] - vr[0] + 2 * margin) * scale) + 1 + 22
    im = Image.new("RGB", (max(w, 120), h), BG)
    d = ImageDraw.Draw(im)
    flip_v = side not in ("top", "bottom")
    def to_px(u, v):
        X = (u - ur[0] + margin) * scale
        if flip_v:
            Y = (vr[1] - v + margin) * scale + 22
        else:
            Y = (v - vr[0] + margin) * scale + 22
        return (X, Y)
    ty = [r[0]["y"] + r[0]["h"] for r in rects]
    t_lo, t_hi = min(ty), max(ty)
    order = sorted(range(len(rects)), key=lambda i: (_depth(*rects[i][:5], side=side), i))
    deps = [_depth(*r[:5], side=side)[0] for r in rects]
    lo_d, hi_d = min(deps), max(deps)
    for i in order:
        p, a0, a1, b0, b1, up = rects[i]
        base = colour_of(p.get("tex"), colours)
        if side in ("top", "bottom"):
            ref = (p["y"] + p["h"]) if side == "top" else p["y"]
            lift = (ref - t_lo) / float(max(1, t_hi - t_lo))
            f = 0.5 + 0.5 * lift if side == "top" else 0.35 + 0.35 * lift
        else:
            dep = _depth(p, a0, a1, b0, b1, side)[0]
            f = 0.45 + 0.55 * (dep - lo_d) / float(max(1, hi_d - lo_d))
        pts = [to_px(u, v) for u, v in _profile(p, a0, a1, b0, b1, up, side)]
        d.polygon(pts, fill=shade(base, f), outline=(8, 8, 8))
    d.text((6, 4), "%s - %s" % (arena.get("key", "?"), side_caption(side)), fill=INK)
    return im
def side_caption(side):
    return {"top": "top (north up)", "bottom": "bottom (from below, north up)",
            "front": "front (from the south)", "back": "back (from the north)",
            "left": "left (from the west)", "right": "right (from the east)"}[side]
def six_sides(arena, size=600):
    x0, x1, y0, y1, z0, z1 = extents(arena)
    span = max(x1 - x0, z1 - z0, y1 - y0) + 600
    scale = size / float(span)
    return {side: ortho(arena, side, scale=scale) for side in SIDES}
def sheet(images, cols=3, pad=8, label=None):
    Image, ImageDraw = _pil()
    images = list(images)
    if not images:
        return Image.new("RGB", (10, 10), BG)
    cw = max(im.width for im in images)
    ch = max(im.height for im in images)
    rows = (len(images) + cols - 1) // cols
    top = 24 if label else 0
    out = Image.new("RGB", (cols * cw + (cols + 1) * pad, rows * ch + (rows + 1) * pad + top), BG)
    for k, im in enumerate(images):
        r, c = divmod(k, cols)
        out.paste(im, (pad + c * (cw + pad), top + pad + r * (ch + pad)))
    if label:
        ImageDraw.Draw(out).text((pad, 6), label, fill=INK)
    return out
def _faces(p, x0, x1, z0, z1, up):
    y0, y1 = p["y"], p["y"] + p["h"]
    if p["kind"] in ("prism", "pillar", "curve", "bank", "arcwall"):
        poly = outline_xz(p)
        out = [([(x, y1, z) for x, z in poly], 1.0)]
        cx = sum(x for x, _ in poly) / len(poly)
        cz = sum(z for _, z in poly) / len(poly)
        for k in range(len(poly)):
            (ax, az), (bx, bz) = poly[k], poly[(k + 1) % len(poly)]
            mx, mz = (ax + bx) / 2 - cx, (az + bz) / 2 - cz
            if mx + mz > 1e-6:
                light = 0.72 if mx >= mz else 0.55
                out.append(([(ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)], light))
        return out
    if p["kind"] in CORNER_KINDS:
        def t(x, z):
            v = _top(p, min(max(x, x0 + 1), x1 - 1), min(max(z, z0 + 1), z1 - 1))
            return y0 if v is None else v
        return [
            ([(x0, t(x0, z0), z0), (x1, t(x1, z0), z0), (x1, t(x1, z1), z1)], 0.92),
            ([(x0, t(x0, z0), z0), (x1, t(x1, z1), z1), (x0, t(x0, z1), z1)], 0.86),
            ([(x1, y0, z0), (x1, y0, z1), (x1, t(x1, z1), z1), (x1, t(x1, z0), z0)], 0.72),
            ([(x0, y0, z1), (x1, y0, z1), (x1, t(x1, z1), z1), (x0, t(x0, z1), z1)], 0.55),
        ]
    if p["kind"] not in ("ramp", "stairs"):
        return [
            ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], 1.0),
            ([(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], 0.72),
            ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], 0.55),
        ]
    def top(x, z):
        if up[0] > 0:
            t = (x - x0) / (x1 - x0)
        elif up[0] < 0:
            t = (x1 - x) / (x1 - x0)
        elif up[1] > 0:
            t = (z - z0) / (z1 - z0)
        else:
            t = (z1 - z) / (z1 - z0)
        return y0 + (y1 - y0) * t
    out = [([(x0, top(x0, z0), z0), (x1, top(x1, z0), z0), (x1, top(x1, z1), z1),
             (x0, top(x0, z1), z1)], 0.9)]
    out.append(([(x1, y0, z0), (x1, y0, z1), (x1, top(x1, z1), z1), (x1, top(x1, z0), z0)], 0.72))
    out.append(([(x0, y0, z1), (x1, y0, z1), (x1, top(x1, z1), z1), (x0, top(x0, z1), z1)], 0.55))
    return out
def _behind(a, b):
    _, ax0, ax1, az0, az1, _ = a
    _, bx0, bx1, bz0, bz1, _ = b
    ay0, ay1 = a[0]["y"], a[0]["y"] + a[0]["h"]
    by0, by1 = b[0]["y"], b[0]["y"] + b[0]["h"]
    if ax1 <= bx0 + 1e-6:
        return True
    if bx1 <= ax0 + 1e-6:
        return False
    if az1 <= bz0 + 1e-6:
        return True
    if bz1 <= az0 + 1e-6:
        return False
    if ay1 <= by0 + 1e-6:
        return True
    if by1 <= ay0 + 1e-6:
        return False
    return (ax0 + az0 + ay0) < (bx0 + bz0 + by0)
def iso(arena, size=640):
    Image, ImageDraw = _pil()
    colours = v1.texture_colours()
    rects = _rects(arena)
    c30, s30 = math.cos(math.radians(30)), 0.5
    def proj(x, y, z):
        return ((x - z) * c30, (x + z) * s30 - y)
    xs, ys = [], []
    for p, x0, x1, z0, z1, up in rects:
        for x in (x0, x1):
            for z in (z0, z1):
                for y in (p["y"], p["y"] + p["h"]):
                    u, v = proj(x, y, z)
                    xs.append(u)
                    ys.append(v)
    lo_u, hi_u, lo_v, hi_v = min(xs), max(xs), min(ys), max(ys)
    sc = (size - 40) / float(max(hi_u - lo_u, hi_v - lo_v))
    W = int((hi_u - lo_u) * sc) + 40
    H = int((hi_v - lo_v) * sc) + 60
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    def px(x, y, z):
        u, v = proj(x, y, z)
        return ((u - lo_u) * sc + 20, (v - lo_v) * sc + 30)
    boxes = []
    for r in rects:
        p, x0, x1, z0, z1, up = r
        pts = [px(x, y, z) for x in (x0, x1) for z in (z0, z1) for y in (p["y"], p["y"] + p["h"])]
        boxes.append((min(q[0] for q in pts), max(q[0] for q in pts),
                      min(q[1] for q in pts), max(q[1] for q in pts)))
    n = len(rects)
    after = [[] for _ in range(n)]
    indeg = [0] * n
    for i in range(n):
        for j in range(i + 1, n):
            bi, bj = boxes[i], boxes[j]
            if bi[1] <= bj[0] or bj[1] <= bi[0] or bi[3] <= bj[2] or bj[3] <= bi[2]:
                continue
            if _behind(rects[i], rects[j]):
                after[i].append(j)
                indeg[j] += 1
            else:
                after[j].append(i)
                indeg[i] += 1
    import heapq
    key = [rects[i][1] + rects[i][3] + rects[i][0]["y"] for i in range(n)]
    ready = [(key[i], i) for i in range(n) if indeg[i] == 0]
    heapq.heapify(ready)
    order = []
    done = [False] * n
    while len(order) < n:
        if not ready:
            rest = min((key[i], i) for i in range(n) if not done[i])
            ready.append(rest)
            indeg[rest[1]] = 0
        _, i = heapq.heappop(ready)
        if done[i]:
            continue
        done[i] = True
        order.append(i)
        for j in after[i]:
            indeg[j] -= 1
            if indeg[j] == 0 and not done[j]:
                heapq.heappush(ready, (key[j], j))
    for i in order:
        p, x0, x1, z0, z1, up = rects[i]
        base = colour_of(p.get("tex"), colours)
        for pts, light in _faces(p, x0, x1, z0, z1, up):
            d.polygon([px(*q) for q in pts], fill=shade(base, light), outline=(10, 10, 12))
    for s in arena.get("spawns", []):
        x, y = px(s["x"], s.get("y", 0) + 40, s["z"])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=SPAWN, outline=(0, 0, 0))
    d.text((8, 6), "%s - 3D (from the south-east)" % arena.get("key", "?"), fill=INK)
    return im
def render_all(arena, outdir, result=None, prefix=None):
    import os
    os.makedirs(outdir, exist_ok=True)
    key = prefix or arena.get("key", "map")
    out = {}
    def save(name, im):
        path = os.path.join(outdir, "%s-%s.png" % (key, name))
        im.save(path, optimize=True)
        out[name] = path
    save("plan", top_down(arena))
    sides = six_sides(arena)
    for side in SIDES:
        save("side-" + side, sides[side])
    save("sides", sheet([sides[s] for s in SIDES], cols=3, label="%s - the six sides" % key))
    save("iso", iso(arena))
    if result is not None:
        ex = result.get("extra", {})
        lines = []
        at = ex.get("sightline_max_at")
        if at:
            lines.append((at[0], at[1], GOLD))
        spawns = arena.get("spawns", [])
        for i, j, dist in ex.get("spawn_kill_pairs", []):
            a, b = spawns[i], spawns[j]
            lines.append(((a["x"], 0, a["z"]), (b["x"], 0, b["z"]), RED))
        if lines or ex.get("spawn_exposure"):
            save("sight", top_down(arena, lines=lines, exposure=ex.get("spawn_exposure"),
                                   heat_label="gold: longest open line; red: spawn-kill pairs; "
                                              "spawn colour = exposure (blue safe .. red 30%+)"))
        sim = ex.get("sim")
        if sim:
            save("heat", top_down(arena, heat=sim["heat"], heat_label="bots: where they stood"))
            save("deaths", top_down(arena, heat=sim["deaths"], heat_label="bots: where they died"))
    return out
