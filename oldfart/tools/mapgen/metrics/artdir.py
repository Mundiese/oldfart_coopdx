import math
G1_GAP = 400
G1_MASS = 400
G1_SINK = 8
G1_FAMILIES_FLOAT = ("course",)
G1_MEANT = ("play.", "course", "keel", "sky.",
            "setpiece.island")
T2_BAND = (0.30, 0.80)
T3_MAX = 16
P1_MEAN = 0.45
P1_ACCENT_SAT = 0.55
P1_ACCENT_SHARE = 0.10
B2_MIN = 0.20
B3_MIN = 0.05
B4_BAND = (0.35, 0.50)
BAKE_SAMPLES = 360
B1_Q05 = (0.05, 0.35)
B1_MED = (0.25, 0.65)
B1_Q95 = 0.75
B1_FLAT_IQR = 0.15
C1_CALM = 0.50
C1_EDGE = 0.16
C1_CELL = 16
C1_CELL_EDGES = 0.15
C2_DECILE = 0.60
C3_TEMP = 0.03
C3_LIGHT = 0.05
T4_PEAK = 0.78
X1_MONO = 0.70
X1_TEXTURES = 2
ADVISORY = ("shadow_colour", "depth_colour")
ADVISORY_FLOOR = 0.6
EXPLAIN = {
    "grounding": "Big blocks should stand on something. A block hanging in the air with "
                 "nothing under it looks like a mistake (unless it is a sky island).",
    "ground_calm": "Most of the ground should wear one calm texture, so the eye can rest "
                   "and the buildings stand out.",
    "texture_count": "Too many different textures in one map make it look messy. "
                     "Up to 16 is plenty.",
    "saturation": "Big surfaces should have soft colours. Save the bright colours for "
                  "small special things.",
    "light_height": "High things should be a bit brighter than low things, like in "
                    "Mario 64's own levels.",
    "shadow_colour": "Shadows look nicer when they are a little blue and the sunny side "
                     "is a little warm.",
    "away_side": "The side turned away from the sun should be darker, but not black.",
    "value_curve": "A good picture has some dark parts, lots of middle and some bright "
                   "parts.",
    "calm": "At least half of the picture should be calm, with not too many lines and "
            "bits.",
    "focal": "Your eye should go to the landmark first: it should stand out the most.",
    "depth_colour": "Things far away should look lighter and a bit bluer, like real air.",
    "tiling": "You should not see the same texture pattern repeat in a grid on the "
              "ground.",
    "liminal": "A map with no landmark, the same texture everywhere and flat light feels "
               "empty and strange, like a lost dream. Normal maps should not.",
}
LABELS = {"grounding": "Nothing floats by mistake", "ground_calm": "Calm ground",
          "texture_count": "Not too many textures", "saturation": "Soft colours on big surfaces",
          "light_height": "High things brighter", "shadow_colour": "Blue shadows, warm sun",
          "away_side": "Shady side not too dark", "value_curve": "Dark, middle and bright",
          "calm": "Calm picture", "focal": "The landmark stands out",
          "depth_colour": "Far things lighter and bluer", "tiling": "No repeating grid",
          "liminal": "Not empty and samey"}
FIXES = {"grounding": "Put a rock or a column under the floating blocks",
         "ground_calm": "Paint most of the ground in one calm texture",
         "texture_count": "Use fewer different textures - repaint the rare ones",
         "saturation": "Use softer colours on the big walls and floors",
         "light_height": "The baked light should brighten high places (a bake setting)",
         "shadow_colour": "Pick a sun with warmer light, or a bluer sky",
         "away_side": "Turn the sun so more of the map is lit, or use a brighter sky",
         "value_curve": "Mix dark, middle and light textures",
         "calm": "Clear some clutter from the open floors",
         "focal": "Make the landmark taller or brighter than everything else",
         "depth_colour": "Add a backdrop far away, or haze in the distance",
         "tiling": "Use a calmer ground texture, or break it with paths and patches",
         "liminal": "Add a landmark, mix two or three textures, and use light and dark"}
LIMINAL_OK_THEMES = ("haunted", "spooky", "ghost", "dream")
LIMINAL_OK_SKIES = ("BACKGROUND_HAUNTED",)
def advise(rows):
    for k in ADVISORY:
        r = rows.get(k)
        if r is not None and r["score"] < ADVISORY_FLOOR:
            r["score"] = ADVISORY_FLOOR
            r["advisory"] = True
    return rows
def _clamp(v):
    return max(0.0, min(1.0, v))
def _band(v, lo, hi, soft):
    if lo is not None and v < lo:
        return _clamp(1.0 - (lo - v) / soft)
    if hi is not None and v > hi:
        return _clamp(1.0 - (v - hi) / soft)
    return 1.0
def _m():
    from .. import v1
    return v1.arenas_module()
def theme_of(arena):
    t = arena.get("theme")
    if not t:
        t = ((arena.get("report") or {}).get("beauty") or {}).get("theme")
    if not t:
        t = ((arena.get("generator") or {}).get("brief") or {}).get("theme") \
            if isinstance(arena.get("generator"), dict) else None
    return t if isinstance(t, str) else None
def _skip(p):
    return p.get("tex") in ("invisible", None) or p.get("kind") == "water" or \
        str(p.get("tex", "")).startswith("water")
def _is_prop(p):
    t = str(p.get("tag", ""))
    return bool(p.get("decor")) or t.startswith(("decor", "dress.lamp", "stall"))
def _box(p, m):
    try:
        x0, x1, z0, z1, _ = m.footprint(p)
    except Exception:
        w, d = float(p.get("w", 0)), float(p.get("d", 0))
        x0, x1, z0, z1 = p["x"] - w / 2, p["x"] + w / 2, p["z"] - d / 2, p["z"] + d / 2
    return x0, x1, z0, z1
CELL = 400
class Columns(object):
    def __init__(self, arena, m=None):
        self.m = m or _m()
        self.pieces = [p for p in arena.get("pieces") or [] if not _skip(p)]
        self.boxes = [_box(p, self.m) for p in self.pieces]
        self.cells = {}
        for k, (x0, x1, z0, z1) in enumerate(self.boxes):
            for i in range(int(math.floor(x0 / CELL)), int(math.floor((x1 - 1e-3) / CELL)) + 1):
                for j in range(int(math.floor(z0 / CELL)), int(math.floor((z1 - 1e-3) / CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
        lvl = self.m.LEVELS.get(arena.get("level")) or {}
        self.floor = lvl.get("floor")
    def resting(self, k):
        x0, x1, z0, z1 = self.boxes[k]
        y = self.pieces[k]["y"]
        seen = set()
        for i in range(int(math.floor(x0 / CELL)), int(math.floor((x1 - 1e-3) / CELL)) + 1):
            for j in range(int(math.floor(z0 / CELL)), int(math.floor((z1 - 1e-3) / CELL)) + 1):
                for o in self.cells.get((i, j), ()):
                    if o == k or o in seen:
                        continue
                    seen.add(o)
                    a0, a1, b0, b1 = self.boxes[o]
                    if a1 <= x0 or a0 >= x1 or b1 <= z0 or b0 >= z1:
                        continue
                    q = self.pieces[o]
                    top = q["y"] + q["h"]
                    if y - G1_GAP < top <= y + 1 and q["y"] < y:
                        return True
        return False
    def below(self, x, z, y, skip):
        best = self.floor
        for k in self.cells.get((int(math.floor(x / CELL)), int(math.floor(z / CELL))), ()):
            if k == skip:
                continue
            x0, x1, z0, z1 = self.boxes[k]
            if not (x0 <= x <= x1 and z0 <= z <= z1):
                continue
            p = self.pieces[k]
            top = p["y"] + p["h"]
            if p["kind"] != "box":
                try:
                    t = self.m.top_at(p, x, z)
                    top = t if t is not None else top
                except Exception:
                    pass
            if p["y"] <= y + 1 and top <= y + 1 and (best is None or top > best):
                best = top
        return best
def floaters(arena, family=None, cols=None):
    if family in G1_FAMILIES_FLOAT or theme_of(arena) == "sky":
        return []
    cols = cols or Columns(arena)
    out = []
    for k, p in enumerate(cols.pieces):
        if _is_prop(p) or p.get("kind") in ("ramp", "stairs") or p.get("mover") \
                or str(p.get("tag", "")).startswith(G1_MEANT):
            continue
        x0, x1, z0, z1 = cols.boxes[k]
        if x1 - x0 < G1_MASS or z1 - z0 < G1_MASS:
            continue
        y = p["y"]
        if cols.floor is not None and y - cols.floor < G1_GAP:
            continue
        if cols.resting(k):
            continue
        ix, iz = min(50.0, (x1 - x0) / 4), min(50.0, (z1 - z0) / 4)
        mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        pts = [(mx, mz)] + [(x, z) for x in (x0 + ix, mx, x1 - ix) for z in (z0 + iz, mz, z1 - iz)
                            if (x, z) != (mx, mz)]
        gaps = []
        for x, z in pts:
            b = cols.below(x, z, y, k)
            gaps.append(None if b is None else y - b)
        known = [g for g in gaps if g is not None]
        if len(known) * 2 < len(pts) or min(known) < G1_GAP:
            continue
        out.append((p, min(known)))
    return out
def grounding(arena, family=None, cols=None):
    fl = floaters(arena, family, cols)
    n = len(fl)
    if not n:
        return {"value": 0, "score": 1.0, "note": "every big block stands on something"}
    names = "; ".join("%s %d over the floor" % (p.get("tag") or p.get("kind"), g)
                      for p, g in fl[:3])
    return {"value": n, "score": round(_clamp(1.0 - n / G1_SINK), 3),
            "note": "%d big block%s hang%s in the air over the map: %s" % (
                n, "" if n == 1 else "s", "s" if n == 1 else "", names),
            "where": [(round(p["x"]), round(p["z"])) for p, _ in fl[:20]]}
_tex_colour = {}
def tex_colour(slug):
    if slug in _tex_colour:
        return _tex_colour[slug]
    out = None
    try:
        import io
        import numpy as np
        from PIL import Image
        from .. import kit
        t = kit.textures().get(slug)
        if t is not None:
            png = _m().blocks.read_texture(kit._repo_path(t["source"]))
            a = np.asarray(Image.open(io.BytesIO(png)).convert("RGB"), np.float64) / 255.0
            rgb = a.reshape(-1, 3).mean(axis=0)
            mx, mn = a.max(axis=2), a.min(axis=2)
            sat = float(np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0).mean())
            out = (tuple(float(c) for c in rgb), sat)
    except Exception:
        out = None
    _tex_colour[slug] = out
    return out
def surface(p):
    w, h, d = float(p.get("w", 0)), float(p.get("h", 0)), float(p.get("d", 0))
    return w * d + 2.0 * (w + d) * h
def ground_calm(grid):
    cells = [c for c in grid.top if c not in grid.water]
    if not cells:
        return {"value": None, "score": 1.0, "note": "no ground"}
    count = {}
    for c in cells:
        t = grid.tex.get(c)
        count[t] = count.get(t, 0) + 1
    tex, n = max(count.items(), key=lambda kv: kv[1])
    share = n / float(len(cells))
    lo, hi = T2_BAND
    sc = _band(share, lo, hi, 0.35)
    return {"value": round(share, 3), "score": round(sc, 3),
            "note": "%s covers %d %% of the ground (calm: %d-%d %%)" % (
                tex, round(share * 100), lo * 100, hi * 100)}
def texture_count(arena):
    texs = set(p.get("tex") for p in arena.get("pieces") or [] if not _skip(p))
    n = len(texs)
    return {"value": n, "score": round(_band(n, None, T3_MAX, 12.0), 3),
            "note": "%d textures (up to %d is plenty)" % (n, T3_MAX)}
def saturation(arena):
    area = {}
    for p in arena.get("pieces") or []:
        if _skip(p) or str(p.get("tag", "")).startswith("dress.backdrop"):
            continue
        area[p["tex"]] = area.get(p["tex"], 0.0) + surface(p)
    total = 0.0
    sat = 0.0
    accent = 0.0
    for t, a in area.items():
        c = tex_colour(t)
        if c is None:
            continue
        total += a
        sat += a * c[1]
        if c[1] >= P1_ACCENT_SAT:
            accent += a
    if total <= 0:
        return {"value": None, "score": 1.0, "note": "no textures to read"}
    mean, share = sat / total, accent / total
    sc = min(_band(mean, None, P1_MEAN, 0.3), _band(share, None, P1_ACCENT_SHARE, 0.4))
    return {"value": [round(mean, 3), round(share, 3)], "score": round(sc, 3),
            "note": "colour strength %d %% on average (soft: up to %d %%), bright colours on "
                    "%d %% (up to %d %%)" % (round(mean * 100), P1_MEAN * 100,
                                             round(share * 100), P1_ACCENT_SHARE * 100)}
def value_spread(arena):
    try:
        from .. import values
        st = values.stats()
    except Exception:
        return None
    xs = []
    for p in arena.get("pieces") or []:
        if _skip(p) or p.get("tex") not in st:
            continue
        xs.append((st[p["tex"]][0], surface(p)))
    if not xs:
        return None
    xs.sort()
    total = sum(a for _, a in xs)
    def q(f):
        acc = 0.0
        for v, a in xs:
            acc += a
            if acc >= f * total:
                return v
        return xs[-1][0]
    return q(0.75) - q(0.25)
def _samples(arena, limit=BAKE_SAMPLES):
    ps = [p for p in arena.get("pieces") or [] if not _skip(p) and not _is_prop(p)
          and not str(p.get("tag", "")).startswith("dress.backdrop")]
    ps.sort(key=lambda p: -surface(p))
    out = []
    for p in ps:
        x, y, z = float(p["x"]), float(p["y"]), float(p["z"])
        w, h, d = float(p["w"]), float(p["h"]), float(p["d"])
        r = math.radians(p.get("yaw") or 0)
        c, s = math.cos(r), math.sin(r)
        out.append((x, y + h, z, 0.0, 1.0, 0.0))
        if h >= 100:
            for lx, lz, nx, nz in ((w / 2, 0, 1, 0), (-w / 2, 0, -1, 0), (0, d / 2, 0, 1),
                                   (0, -d / 2, 0, -1)):
                wx, wz = x + lx * c + lz * s, z - lx * s + lz * c
                wnx, wnz = nx * c + nz * s, -nx * s + nz * c
                for fy in (0.15, 0.85):
                    out.append((wx, y + h * fy, wz, wnx, 0.0, wnz))
        if len(out) >= limit:
            break
    return out[:limit]
def _corr(a, b):
    n = len(a)
    if n < 3:
        return None
    ma, mb = sum(a) / n, sum(b) / n
    va = sum((x - ma) ** 2 for x in a)
    vb = sum((y - mb) ** 2 for y in b)
    if va <= 1e-9 or vb <= 1e-9:
        return 0.0
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / math.sqrt(va * vb)
def bake_rows(arena):
    from .. import bake
    look = arena.get("look") if isinstance(arena.get("look"), dict) else None
    if look is not None and look.get("bake") is False:
        return {}
    pal = bake.sun_palette(look, theme_of(arena))
    grid = bake.Grid(bake.rows_of(arena))
    sun = bake._unit(pal["sun"])
    ys, ls, shaded, lit, away, tops = [], [], [], [], [], []
    for x, y, z, nx, ny, nz in _samples(arena):
        n, ao, lt = bake.parts(grid, pal, x, y, z, nx, ny, nz)
        r, g, b = bake.shade(pal, sun, n, ao, lt)
        lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        ys.append(y)
        ls.append(lum)
        ndl = n[0] * sun[0] + n[1] * sun[1] + n[2] * sun[2]
        warm = (b - r) / 255.0
        if ndl <= 0.05 or lt < 1.0:
            shaded.append(warm)
        else:
            lit.append(warm)
        if ny > 0.9 and ndl > 0.05 and lt >= 1.0:
            tops.append(lum)
        elif ny < 0.1 and ndl <= 0.0:
            away.append(lum)
    rows = {}
    c = _corr(ys, ls)
    if c is not None:
        rows["light_height"] = {"value": round(c, 3), "score": round(_band(c, B2_MIN, None, 0.4), 3),
                                "note": "height and light go together %+.2f (want %+.2f or more)"
                                        % (c, B2_MIN)}
    if shaded and lit:
        d = sum(shaded) / len(shaded) - sum(lit) / len(lit)
        rows["shadow_colour"] = {"value": round(d, 3),
                                 "score": round(_band(d, B3_MIN, None, 0.12), 3),
                                 "note": "shadows %s than the sunny side by %.2f (want %.2f)" % (
                                     "bluer" if d >= 0 else "warmer", abs(d), B3_MIN)}
    if away and tops:
        away.sort()
        tops.sort()
        ratio = away[len(away) // 2] / max(1e-3, tops[len(tops) // 2])
        lo, hi = B4_BAND
        rows["away_side"] = {"value": round(ratio, 3), "score": round(_band(ratio, lo, hi, 0.3), 3),
                             "note": "the shady side is %d %% of a sunny top (want %d-%d %%)" % (
                                 round(ratio * 100), lo * 100, hi * 100)}
    return rows
def cheap(arena, grid, family=None):
    rows = {"grounding": grounding(arena, family), "ground_calm": ground_calm(grid),
            "texture_count": texture_count(arena), "saturation": saturation(arena)}
    try:
        rows.update(bake_rows(arena))
    except Exception:
        pass
    return advise(rows)
def _np():
    import numpy as np
    return np
def value_curve(frames):
    np = _np()
    x = np.concatenate([f.lum[~f.sky] for f in frames]) if frames else np.array([])
    if x.size < 100:
        return None
    q05, q25, q50, q75, q95 = (float(v) for v in np.quantile(x, (0.05, 0.25, 0.5, 0.75, 0.95)))
    met = sum((B1_Q05[0] <= q05 <= B1_Q05[1], B1_MED[0] <= q50 <= B1_MED[1], q95 >= B1_Q95))
    return {"value": [round(q05, 2), round(q50, 2), round(q95, 2)],
            "score": {3: 1.0, 2: 0.6}.get(met, 0.2), "iqr": round(q75 - q25, 3),
            "note": "dark %.2f, middle %.2f, bright %.2f (want %.2f-%.2f, %.2f-%.2f, %.2f+)" % (
                q05, q50, q95, B1_Q05[0], B1_Q05[1], B1_MED[0], B1_MED[1], B1_Q95)}
def calm(frames):
    np = _np()
    shares = []
    for f in frames:
        lum = f.lum
        g = np.maximum(np.abs(np.diff(lum, axis=1))[:-1, :], np.abs(np.diff(lum, axis=0))[:, :-1])
        e = (g > C1_EDGE) & ~f.sky[:-1, :-1]
        h, w = e.shape
        h, w = h - h % C1_CELL, w - w % C1_CELL
        if h <= 0 or w <= 0:
            continue
        cells = e[:h, :w].reshape(h // C1_CELL, C1_CELL, w // C1_CELL, C1_CELL).mean(axis=(1, 3))
        drawn = (~f.sky[:h, :w]).reshape(h // C1_CELL, C1_CELL, w // C1_CELL,
                                         C1_CELL).mean(axis=(1, 3)) > 0.5
        if drawn.sum() < 4:
            continue
        shares.append(float((cells[drawn] < C1_CELL_EDGES).mean()))
    if not shares:
        return None
    v = float(np.median(shares))
    return {"value": round(v, 3), "score": round(_band(v, C1_CALM, None, 0.35), 3),
            "note": "%d %% of the picture is calm (want %d %% or more)" % (
                round(v * 100), C1_CALM * 100)}
def focal(frame, group):
    np = _np()
    if frame is None or not group:
        return None
    from PIL import Image
    w = 231
    h = max(1, int(round(frame.h * w / float(frame.w))))
    lum = np.asarray(Image.fromarray((np.clip(frame.lum, 0, 1) * 255).astype(np.uint8), "L")
                     .resize((w, h), Image.BILINEAR), np.float32) / 255.0
    ids = np.asarray(Image.fromarray(frame.ids.astype(np.int32)).resize((w, h), Image.NEAREST))
    mine = np.isin(ids, list(group))
    if mine.sum() < 6:
        return {"value": 0.0, "score": 0.3, "note": "the landmark is too small to see in the "
                                                    "far view"}
    rows, cols = np.nonzero(mine)
    r0, r1 = rows.min(), rows.max() + 1
    c0, c1 = cols.min(), cols.max() + 1
    pad = max(3, (r1 - r0) // 2)
    ring = np.zeros_like(mine)
    ring[max(0, r0 - pad):r1 + pad, max(0, c0 - pad):c1 + pad] = True
    ring &= ~mine
    if ring.sum() < 6:
        return None
    own = abs(float(lum[mine].mean()) - float(lum[ring].mean()))
    k = 8
    hh, ww = h - h % k, w - w % k
    blocks = lum[:hh, :ww].reshape(hh // k, k, ww // k, k)
    local = (blocks.max(axis=(1, 3)) - blocks.min(axis=(1, 3))).ravel() / 2.0
    pct = float((local < own).mean()) if local.size else 0.0
    return {"value": round(pct, 3), "score": round(_band(pct, C2_DECILE, None, 0.5), 3),
            "note": "the landmark stands out more than %d %% of the picture (want %d %%)" % (
                round(pct * 100), C2_DECILE * 100)}
def depth_colour(frames):
    np = _np()
    near_t, far_t, near_l, far_l = [], [], [], []
    for f in frames:
        m = ~f.sky & ~f.up
        near = m & (f.depth < 1200)
        far = m & (f.depth > 5000)
        if near.sum() < 30 or far.sum() < 30:
            continue
        t = f.rgb[..., 2] - f.rgb[..., 0]
        near_t.append(float(t[near].mean()))
        far_t.append(float(t[far].mean()))
        near_l.append(float(f.lum[near].mean()))
        far_l.append(float(f.lum[far].mean()))
    if not near_t:
        return None
    dt = float(np.mean(far_t) - np.mean(near_t))
    dl = float(np.mean(far_l) - np.mean(near_l))
    sc = min(_band(dt, C3_TEMP, None, 0.15), _band(dl, C3_LIGHT, None, 0.25))
    return {"value": [round(dt, 3), round(dl, 3)], "score": round(sc, 3),
            "note": "far things %s by %.2f and %s by %.2f (want bluer %.2f, lighter %.2f)" % (
                "bluer" if dt >= 0 else "warmer", abs(dt), "lighter" if dl >= 0 else "darker",
                abs(dl), C3_TEMP, C3_LIGHT)}
def tiling(frames):
    np = _np()
    peaks = []
    for f in frames:
        r0 = int(f.h * 0.7)
        lum = f.lum[r0:]
        up = f.up[r0:]
        for row, m in zip(lum[::4], up[::4]):
            if m.mean() < 0.9:
                continue
            x = row - row.mean()
            v = float((x * x).sum())
            if v < 1e-4 * x.size:
                continue
            ac = np.correlate(x, x, "full")[x.size - 1:] / v
            lo, hi = 6, min(x.size // 3, 120)
            if hi <= lo:
                continue
            peaks.append(float(ac[lo:hi].max()))
    if not peaks:
        return None
    v = float(np.median(peaks))
    return {"value": round(v, 3), "score": round(_band(v, None, T4_PEAK, 0.4), 3),
            "note": "the ground pattern repeats %d %% strongly (want under %d %%)" % (
                round(v * 100), T4_PEAK * 100)}
def render(audit, arena=None):
    frames = audit.get("frames") or {}
    far, spawn = frames.get("far") or [], frames.get("spawn") or []
    both = far + spawn
    rows = {}
    for key, fn in (("value_curve", lambda: value_curve(both)), ("calm", lambda: calm(spawn)),
                    ("depth_colour", lambda: depth_colour(spawn)),
                    ("tiling", lambda: tiling(spawn))):
        try:
            r = fn()
        except Exception:
            r = None
        if r is not None:
            rows[key] = r
    try:
        from . import looks
        li = audit.get("landmark")
        arena = arena if arena is not None else audit.get("_arena")
        group = looks.landmark_group(arena, li) if (arena is not None and li is not None) \
            else ([li] if li is not None else [])
        r = focal(far[0] if far else None, group)
        if r is not None:
            rows["focal"] = r
    except Exception:
        pass
    return advise(rows)
def liminal(arena, rows, looks_checks=None):
    theme = theme_of(arena) or ""
    sky = ((arena.get("look") or {}).get("sky") if isinstance(arena.get("look"), dict)
           else None)
    if any(w in theme for w in LIMINAL_OK_THEMES) or sky in LIMINAL_OK_SKIES:
        return None
    signs = []
    a5 = (looks_checks or {}).get("A5")
    hero = rows.get("hero_seen")
    if a5 is not None:
        lost = a5.get("status") == "fail" or a5.get("value") is None
    else:
        lost = hero is None or hero["score"] < 0.5
    if lost:
        signs.append("no landmark to steer by")
    tl = rows.get("tiling")
    mono = rows.get("monotony")
    tc = rows.get("texture_count")
    same = (tl is not None and tl["score"] < 0.5) or (
        mono is not None and isinstance(mono.get("value"), (int, float))
        and mono["value"] >= X1_MONO) or (tc is not None and isinstance(tc.get("value"), int)
                                          and tc["value"] <= X1_TEXTURES)
    if same:
        signs.append("the same texture everywhere")
    vc = rows.get("value_curve")
    spread = vc.get("iqr") if vc else value_spread(arena)
    if spread is not None and spread < B1_FLAT_IQR:
        signs.append("flat, even light")
    n = len(signs)
    score = {3: 0.1, 2: 0.6}.get(n, 1.0)
    note = ("feels empty and samey: " + ", ".join(signs)) if n == 3 else \
        ("drifting toward empty and samey: " + ", ".join(signs)) if n == 2 else \
        "has things to steer by, texture and light variety"
    return {"value": n, "score": score, "note": note, "signs": signs}
