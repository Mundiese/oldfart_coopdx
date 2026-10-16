#!/usr/bin/env python3
import argparse
import os
import sys
import numpy as np
from PIL import Image
MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(MOD_DIR, "assets-incoming", "1010", "paintings")
DUMP_DIR = os.path.join(MOD_DIR, "assets-incoming", "0923", "paintings")
SOURCES = {
    "b1": ("146.webp", 448.4, 20.9, 1104.1),
    "b2": ("147.webp", 448.9, 23.1, 1100.9),
    "b3": ("148.webp", 449.5, 23.1, 1100.9),
    "bbh": ("16.jpg", 469.9, 40.2, 599.1),
    "bitdw": ("29.png", 94.0, 0.0, 450.7),
    "bitfs": ("158.webp", 449.5, 23.1, 1100.9),
    "bits": ("24.png", 93.7, 0.9, 452.8),
    "bob": ("rig:bob_2.png", 280.0, 0.0, 720.0),
    "castle_basement": ("142.webp", 448.2, 20.7, 1104.3),
    "castle_courtyard": ("144.webp", 449.5, 23.1, 1100.9),
    "castle_lobby": ("140.webp", 448.2, 20.7, 1104.3),
    "castle_upstairs": ("141.webp", 118.8, 20.7, 1104.3),
    "ccm": ("rig:ccm_8.png", 280.0, 0.0, 720.0),
    "ccmslide": ("153.webp", 449.5, 22.7, 1101.8),
    "cotmc": ("157.webp", 448.2, 20.7, 1104.3),
    "ddd": ("149.webp", 448.2, 20.7, 1104.3),
    "desert_cage": ("render-level-face.py", 0.0, 0.0, 192.0),
    "grounds": ("139.webp", 448.2, 20.7, 1104.3),
    "hmc": ("rig:hmc_3.png", 280.0, 0.0, 720.0),
    "ice_donut": ("render-level-face.py", 0.0, 0.0, 192.0),
    "igloo": ("154.webp", 449.7, 22.1, 1102.8),
    "jrb": ("rig:jrb_1.png", 280.0, 0.0, 720.0),
    "lll": ("rig:lll_2.png", 280.0, 0.0, 720.0),
    "pss": ("20.png", 59.6, 51.4, 144.6),
    "pyramid": ("155.webp", 448.4, 20.9, 1104.1),
    "rr": ("17.jpg", 60.9, 0.0, 719.6),
    "sa": ("14.png", 0.0, 50.0, 169.8),
    "ship": ("151.webp", 448.2, 20.7, 1104.3),
    "sl": ("13.webp", 210.5, 5.3, 279.3),
    "skykeep": ("rig:sk_1.png", 280.0, 0.0, 720.0),
    "ssl": ("11.png", 40.2, 130.2, 299.6),
    "the_plate": ("render-level-face.py", 0.0, 0.0, 192.0),
    "thihuge": ("rig:thihuge_2.png", 280.0, 0.0, 720.0),
    "thitiny": ("rig:thitiny_7.png", 280.0, 0.0, 720.0),
    "ttc": ("145.webp", 697.6, 22.2, 1102.8),
    "ttm": ("rig:ttm_4.png", 280.0, 0.0, 720.0),
    "ttmslide": ("152.webp", 448.2, 20.7, 1104.3),
    "vc": ("23.webp", 149.8, 0.0, 725.6),
    "volcano": ("156.webp", 150.5, 23.8, 1100.2),
    "wc": ("22.webp", 150.2, 0.0, 724.1),
    "wdw": ("rig:wdw_2.png", 280.0, 0.0, 720.0),
    "wf": ("rig:wf_6.png", 280.0, 0.0, 720.0),
    "wigglercave": ("150.webp", 448.2, 20.7, 1104.3),
    "wmotr": ("19.png", 39.9, 27.8, 190.5),
}
RENDERED = {"desert_cage", "ice_donut", "the_plate"}
SOURCE_TRIM = {}
FRAMES = {
    "b1": "lll", "b2": "lll", "b3": "lll", "bbh": "lll", "bitdw": "lll",
    "bitfs": "lll", "bits": "lll", "pss": "lll", "volcano": "lll",
    "the_plate": "lll",
    "skykeep": "bob",
    "castle_basement": "bob", "castle_courtyard": "bob", "castle_lobby": "bob",
    "castle_upstairs": "bob", "desert_cage": "bob", "grounds": "bob",
    "pyramid": "bob", "wmotr": "bob", "ssl": "bob",
    "ccmslide": "ccm", "ice_donut": "ccm", "igloo": "ccm", "sa": "ccm",
    "wc": "ccm", "sl": "ccm",
    "cotmc": "jrb", "hmc": "jrb", "ship": "jrb",
    "ddd": "wdw",
    "bob": "bob", "ccm": "ccm", "jrb": "jrb", "lll": "lll", "ttm": "ttm",
    "wdw": "wdw", "wf": "wf",
    "rr": "wf", "thihuge": "wf", "thitiny": "wf", "ttmslide": "wf", "vc": "wf",
    "wigglercave": "wf", "ttc": "wf",
}
ENV_KEYS = {"bbh", "bitdw", "bitfs", "bits", "cotmc", "ddd", "hmc", "pss", "rr",
            "sa", "thihuge", "thitiny", "vc", "wc", "wmotr", "ssl", "sl", "ttc",
            "bob", "ccm", "jrb", "lll", "ttm", "wdw", "wf"}
VANILLA = ["bob", "ccm", "wf", "jrb", "lll", "wdw", "thi", "ttm"]
STYLE = {
    "sat_mean": 0.46,
    "sat_gain_max": 1.35,
    "dark_p5": 30.0,
    "light_p95": 238.0,
    "dark_p95": 135.0,
    "dark_lift": 0.85,
    "mid_floor": 70.0,
    "glow": 0.35,
    "glow_from": 170.0,
    "stretch": 0.6,
    "palette_pull": 0.22,
    "palette_size": 64,
    "detail": 32.0,
    "smooth_passes": 2,
    "smooth_radius": 6,
    "smooth_range": 16.0,
}
R = 8
MASTER_W = 66 * R
MASTER_H = 65 * R
OPEN_BOX = (int((5.5 + 0.5) * R), int((4.5 + 1.5) * R),
            int((59.5 + 0.5) * R), int((57.5 + 1.5) * R))
def _load_rgb(path):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.float32)
def vanilla_full(course):
    top = _load_rgb(os.path.join(DUMP_DIR, course + "_top.png"))
    bottom = _load_rgb(os.path.join(DUMP_DIR, course + "_bottom.png"))
    return np.vstack([top, bottom])
FRAME_DIR = os.path.join(MOD_DIR, "tools", "mapgen", "paintframes")
FRAME_BLANK = (128, 128, 128)
def frame_path(course):
    return os.path.join(FRAME_DIR, course + ".png")
def frame_full(course):
    return _load_rgb(frame_path(course))
def painted_over():
    idx = np.arange(63 * 64, dtype=np.int32).reshape(63, 64)
    padded = np.pad(idx, ((1, 1), (1, 1)), mode="edge")
    rgb = np.stack([padded & 255, (padded >> 8) & 255, np.zeros_like(padded)], axis=-1)
    big = np.asarray(Image.fromarray(rgb.astype(np.uint8)).resize(
        (MASTER_W, MASTER_H), Image.NEAREST), dtype=np.int32)
    src = big[..., 0] | (big[..., 1] << 8)
    x0, y0, x1, y1 = OPEN_BOX
    inside = np.zeros(src.shape, dtype=bool)
    inside[y0:y1, x0:x1] = True
    shown = set(np.unique(src[~inside]).tolist())
    keep_logical = np.array([[(r * 64 + c) in shown for c in range(64)] for r in range(63)])
    full = np.vstack([keep_logical[:32], keep_logical[31:32], keep_logical[32:]])
    return ~full
def write_frames():
    import json
    os.makedirs(FRAME_DIR, exist_ok=True)
    blank = painted_over()
    for course in VANILLA:
        full = vanilla_full(course).copy()
        full[blank] = FRAME_BLANK
        Image.fromarray(full.astype(np.uint8)).save(frame_path(course), optimize=True)
    pal = [[int(round(v)) for v in c] for c in vanilla_palette(measure=True)]
    with open(os.path.join(FRAME_DIR, "palette.json"), "w", encoding="utf-8") as handle:
        json.dump({"palette": pal, "from": "the eight vanilla pictures' interiors, median cut"},
                  handle, indent=0)
        handle.write("\n")
def logical(full64):
    return np.vstack([full64[:32], full64[33:]])
def luminance(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
def saturation(a):
    mx = a.max(-1)
    mn = a.min(-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
def laplacian_energy(a):
    lum = luminance(a)
    lap = (4 * lum[1:-1, 1:-1] - lum[:-2, 1:-1] - lum[2:, 1:-1]
           - lum[1:-1, :-2] - lum[1:-1, 2:])
    return float(np.abs(lap).mean())
def bilateral(a, radius=2, sigma_s=1.6, sigma_r=22.0):
    h, w, _ = a.shape
    pad = np.pad(a, ((radius, radius), (radius, radius), (0, 0)), mode="edge")
    acc = np.zeros_like(a)
    wsum = np.zeros(a.shape[:2], dtype=np.float32)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            sh = pad[radius + dy:radius + dy + h, radius + dx:radius + dx + w]
            d2 = ((sh - a) ** 2).sum(-1)
            wgt = np.exp(-(dx * dx + dy * dy) / (2 * sigma_s ** 2)
                         - d2 / (2 * (sigma_r ** 2) * 3)).astype(np.float32)
            acc += sh * wgt[..., None]
            wsum += wgt
    return acc / wsum[..., None]
_PALETTE = None
def vanilla_palette(measure=False):
    global _PALETTE
    if measure:
        tiles = [vanilla_full(c)[5:59, 5:59] for c in VANILLA]
        strip = np.concatenate(tiles, axis=1).astype(np.uint8)
        q = Image.fromarray(strip).quantize(STYLE["palette_size"],
                                            method=Image.Quantize.MEDIANCUT)
        pal = np.asarray(q.getpalette()[:STYLE["palette_size"] * 3], dtype=np.float32)
        return pal.reshape(-1, 3)
    if _PALETTE is None:
        import json
        with open(os.path.join(FRAME_DIR, "palette.json"), encoding="utf-8") as handle:
            _PALETTE = np.asarray(json.load(handle)["palette"], dtype=np.float32)
    return _PALETTE
def palette_pull(a, amount):
    pal = vanilla_palette()
    flat = a.reshape(-1, 3)
    d = ((flat[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
    near = pal[d.argmin(1)].reshape(a.shape)
    return a + (near - a) * amount
def tone(a):
    lum = luminance(a)
    p5, p50, p95 = np.percentile(lum, [5, 50, 95])
    lo = p5 + (min(p5, STYLE["dark_p5"]) - p5) * STYLE["stretch"]
    want_hi = STYLE["light_p95"] if p95 > 150 else max(p95 * 1.08, STYLE["dark_p95"])
    lift = STYLE["stretch"] if p95 > 150 else STYLE["dark_lift"]
    hi = p95 + (max(p95, want_hi) - p95) * lift
    xs = [0.0, p5, p50, p95, 255.0]
    mid = lo + (p50 - p5) / max(p95 - p5, 1e-3) * (hi - lo)
    if mid < STYLE["mid_floor"]:
        mid = mid + (STYLE["mid_floor"] - mid) * STYLE["stretch"] * 0.6
    mid = float(np.clip(mid, lo + 1, hi - 1))
    ys = [0.0, lo, mid, hi, 255.0]
    new = np.interp(lum, xs, ys)
    ratio = (new + 1.0) / (lum + 1.0)
    return a * ratio[..., None]
def saturate(a):
    s = saturation(a / 255.0).mean()
    gain = float(np.clip(STYLE["sat_mean"] / max(s, 1e-3), 1.0, STYLE["sat_gain_max"]))
    lum = luminance(a)[..., None]
    return lum + (a - lum) * gain
def glow(a):
    from PIL import ImageFilter
    lum = luminance(a)
    w = np.clip((lum - STYLE["glow_from"]) / (255.0 - STYLE["glow_from"]), 0, 1)
    hl = (a * w[..., None]).astype(np.uint8)
    halo = np.asarray(Image.fromarray(hl).filter(ImageFilter.GaussianBlur(4)), dtype=np.float32)
    share = float((w > 0).mean())
    amount = STYLE["glow"] * float(np.clip(1.0 - share / 0.25, 0.0, 1.0))
    return a + halo * amount * (1.0 - a / 255.0)
def unsharp(a, amount, radius=1.2):
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    from PIL import ImageFilter
    blur = np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)
    return a + (a - blur) * amount
def stylise(src):
    work = src.resize((54 * 4, 53 * 4), Image.LANCZOS)
    a = np.asarray(work.convert("RGB"), dtype=np.float32)
    for _ in range(STYLE["smooth_passes"]):
        a = bilateral(a, radius=STYLE["smooth_radius"], sigma_s=STYLE["smooth_radius"] / 2.0,
                      sigma_r=STYLE["smooth_range"])
    a = tone(a)
    a = saturate(a)
    a = np.clip(a, 0, 255)
    a = glow(a)
    a = palette_pull(a, STYLE["palette_pull"])
    best = None
    for amount in (-0.6, -0.3, 0.0, 0.3, 0.6, 0.9, 1.2, 1.6):
        t = np.clip(unsharp(a, amount, radius=2.0), 0, 255)
        small = np.asarray(Image.fromarray(t.astype(np.uint8)).resize((54, 53), Image.BOX),
                           dtype=np.float32)
        err = abs(laplacian_energy(small) - STYLE["detail"])
        if best is None or err < best[0]:
            best = (err, t)
    return best[1]
def master(key):
    with Image.open(os.path.join(SRC_DIR, key + ".png")) as im:
        src = im.convert("RGB")
        if key in SOURCE_TRIM:
            src = src.crop(SOURCE_TRIM[key])
        return master_from(src, FRAMES[key])
def opening_crop(src):
    aspect = (54 / 64.0) / (53 / 62.0)
    sw, sh = src.size
    cw = sw * aspect
    return src.crop((round((sw - cw) / 2), 0, round((sw + cw) / 2), sh))
def master_from(src, frame_course, stylised=True):
    frame = logical(frame_full(frame_course))
    padded = np.pad(frame, ((1, 1), (1, 1), (0, 0)), mode="edge")
    m = np.asarray(Image.fromarray(padded.astype(np.uint8)).resize(
        (MASTER_W, MASTER_H), Image.NEAREST), dtype=np.float32).copy()
    x0, y0, x1, y1 = OPEN_BOX
    src = opening_crop(src.convert("RGB"))
    pic = stylise(src) if stylised else np.asarray(src, dtype=np.float32)
    pic_img = Image.fromarray(np.clip(pic, 0, 255).astype(np.uint8))
    m[y0:y1, x0:x1] = np.asarray(pic_img.resize((x1 - x0, y1 - y0), Image.BICUBIC),
                                 dtype=np.float32)
    return m
def halves_from(src, frame_course="bob", k=2, stylised=True):
    return cut_halves(master_from(src, frame_course, stylised), k)
def quantise_rgba16(a, keep=None, strength=0.8):
    h, w, _ = a.shape
    work = a.astype(np.float64) / 255.0 * 31.0
    out = np.zeros_like(work)
    if keep is None:
        keep = np.zeros((h, w), dtype=bool)
    for y in range(h):
        xs = range(w) if y % 2 == 0 else range(w - 1, -1, -1)
        step = 1 if y % 2 == 0 else -1
        for x in xs:
            old = work[y, x]
            new = np.clip(np.floor(old + 0.5), 0, 31)
            out[y, x] = new
            if keep[y, x]:
                continue
            err = (old - new) * strength
            for dx, dy, f in ((step, 0, 7 / 16), (-step, 1, 3 / 16), (0, 1, 5 / 16), (step, 1, 1 / 16)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and ny < h and not keep[ny, nx]:
                    work[ny, nx] += err * f
    q = out.astype(np.uint8)
    return (q << 3) | (q >> 2)
def _frame_mask(k):
    m = np.ones((MASTER_H, MASTER_W), dtype=np.uint8) * 255
    x0, y0, x1, y1 = OPEN_BOX
    m[y0:y1, x0:x1] = 0
    img = Image.fromarray(m)
    box = ((0.5 + 0.5) * R, (-0.5 + 1.5) * R, (64.5 + 0.5) * R, (62.5 + 1.5) * R)
    g = np.asarray(img.resize((64 * k, 63 * k), Image.BOX, box=box))
    return g == 255
def cut_halves(m, k):
    img = Image.fromarray(np.clip(m, 0, 255).astype(np.uint8))
    box = ((0.5 + 0.5) * R, (-0.5 + 1.5) * R, (64.5 + 0.5) * R, (62.5 + 1.5) * R)
    g = np.asarray(img.resize((64 * k, 63 * k), Image.BOX, box=box), dtype=np.float32)
    q = quantise_rgba16(g, keep=_frame_mask(k))
    return q[:32 * k].copy(), q[31 * k:63 * k].copy()
def env_swatch(m, k):
    x0, y0, x1, y1 = OPEN_BOX
    img = Image.fromarray(np.clip(m[y0:y1, x0:x1], 0, 255).astype(np.uint8))
    sw = np.asarray(img.resize((32 * k, 32 * k), Image.BOX), dtype=np.float32)
    return quantise_rgba16(sw)
def build(key, k):
    m = master(key)
    top, bottom = cut_halves(m, k)
    env = env_swatch(m, k) if key in ENV_KEYS else None
    return top, bottom, env
def vanilla_halves(course, k):
    def rgba16(a):
        q = np.floor(a.astype(np.float64) / 255.0 * 31.0 + 0.5).astype(np.uint8)
        return (q << 3) | (q >> 2)
    whole = logical(vanilla_full(course))
    img = Image.fromarray(whole.astype(np.uint8))
    g = rgba16(np.asarray(img.resize((64 * k, 63 * k), Image.BILINEAR)))
    with Image.open(os.path.join(DUMP_DIR, course + "_env.png")) as im:
        env = rgba16(np.asarray(im.convert("RGB").resize((32 * k, 32 * k), Image.BILINEAR)))
    return g[:32 * k].copy(), g[31 * k:63 * k].copy(), env
SHIP_SCALE = 2
SHIP_DIR = os.path.join(MOD_DIR, "assets-incoming", "1010", "faces")
NOT_SHIPPED = {"thi"}
def ship_keys():
    return sorted(SOURCES)
def ship_build(key):
    if key not in SOURCES:
        raise KeyError("%s has no source: every shipped face is painted" % key)
    return build(key, SHIP_SCALE)
def sample(tex, u, v, mode):
    h, w = tex.shape[:2]
    t = tex.astype(np.float32)
    def at(ix, iy):
        return t[np.clip(iy, 0, h - 1), np.clip(ix, 0, w - 1)]
    if mode == "nearest":
        return at(np.floor(u * w).astype(int), np.floor(v * h).astype(int))
    x = u * w - 0.5
    y = v * h - 0.5
    if mode == "bilinear":
        x0 = np.floor(x).astype(int)
        y0 = np.floor(y).astype(int)
        fx = (x - x0)[..., None]
        fy = (y - y0)[..., None]
        return (at(x0, y0) * (1 - fx) * (1 - fy) + at(x0 + 1, y0) * fx * (1 - fy)
                + at(x0, y0 + 1) * (1 - fx) * fy + at(x0 + 1, y0 + 1) * fx * fy)
    ox = x - np.floor(x)
    oy = y - np.floor(y)
    flip = (ox + oy) >= 1.0
    ox = np.where(flip, ox - 1, ox)
    oy = np.where(flip, oy - 1, oy)
    def tap(dx, dy):
        return at(np.floor(x - dx + 0.5).astype(int), np.floor(y - dy + 0.5).astype(int))
    c0 = tap(ox, oy)
    c1 = tap(ox - np.sign(ox), oy)
    c2 = tap(ox, oy - np.sign(oy))
    return c0 + np.abs(ox)[..., None] * (c1 - c0) + np.abs(oy)[..., None] * (c2 - c0)
def engine_uv(s, t, tile_w=64, tile_h=32):
    return (s + 0.5) / tile_w, (t + 0.5) / tile_h
def seam_limits(top, bottom, mode, columns=256):
    s = np.linspace(-1.0, 63.0, columns)
    t31 = np.full_like(s, 31.0)
    t0 = np.zeros_like(s)
    u, v = engine_uv(s, t31)
    from_top = sample(top, u, v, mode)
    u, v = engine_uv(s, t0)
    from_bottom = sample(bottom, u, v, mode)
    u, v = engine_uv(s, t31 - 1)
    top_prev = sample(top, u, v, mode)
    u, v = engine_uv(s, t0 + 1)
    bottom_next = sample(bottom, u, v, mode)
    return s, from_top, from_bottom, top_prev, bottom_next
def seam_report(top, bottom, mode="bilinear"):
    s, a, b, ap, bn = seam_limits(top, bottom, mode)
    inner = (s >= 6) & (s <= 57)
    d = np.abs(a - b)[inner].mean(-1)
    row = (np.abs(a - ap) + np.abs(bn - b))[inner].mean() / 2.0
    return float(d.mean()), float(row), int((d > 16.5).sum())
def seam_ok(top, bottom, mode="bilinear"):
    jump, row, bad = seam_report(top, bottom, mode)
    return (jump <= max(1.0, 0.25 * row) and bad <= 2), jump, row, bad
def _png(a):
    import io
    buf = io.BytesIO()
    Image.fromarray(a).save(buf, format="PNG", optimize=True)
    return buf.getvalue()
def ship(check):
    stale = []
    os.makedirs(SHIP_DIR, exist_ok=True)
    wanted = set()
    for key in ship_keys():
        top, bottom, env = ship_build(key)
        parts = [("top", top), ("bottom", bottom)]
        if env is not None:
            parts.append(("env", env))
        for half, a in parts:
            name = "%s_%s.png" % (key, half)
            wanted.add(name)
            path = os.path.join(SHIP_DIR, name)
            if check:
                same = False
                if os.path.isfile(path):
                    with Image.open(path) as im:
                        same = np.array_equal(np.asarray(im.convert("RGB")), a)
                if not same:
                    stale.append(name)
            else:
                with open(path, "wb") as handle:
                    handle.write(_png(a))
    for name in sorted(os.listdir(SHIP_DIR)):
        if name.endswith(".png") and name not in wanted:
            if check:
                stale.append(name + " (no key)")
            else:
                os.remove(os.path.join(SHIP_DIR, name))
    for name in stale:
        print("STALE: %s" % os.path.join(os.path.relpath(SHIP_DIR, MOD_DIR), name))
    if not check:
        print("wrote %d faces into %s" % (len(wanted), os.path.relpath(SHIP_DIR, MOD_DIR)))
    return 1 if stale else 0
def main():
    ap = argparse.ArgumentParser(description="Paints the castle-painting faces in the style of the game's own paintings.")
    ap.add_argument("--out")
    ap.add_argument("--scale", type=int, default=1)
    ap.add_argument("--keys")
    ap.add_argument("--seam", action="store_true")
    ap.add_argument("--ship", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--frames", action="store_true",
                    help="write tools/mapgen/paintframes/ (the frames and palette) from the dump")
    args = ap.parse_args()
    if args.frames:
        write_frames()
        print("wrote", FRAME_DIR)
        return 0
    if args.ship or args.check:
        return ship(args.check)
    keys = args.keys.split(",") if args.keys else sorted(SOURCES)
    k = args.scale
    if not args.out and not args.seam:
        ap.error("--out DIR, --seam, --ship or --check")
    if args.out and os.path.abspath(args.out).startswith(os.path.join(MOD_DIR, "textures")):
        ap.error("this tool never writes into textures/ - make-painting-textures.py packs them")
    failed = []
    for key in keys:
        top, bottom, env = build(key, k)
        if args.out:
            os.makedirs(args.out, exist_ok=True)
            Image.fromarray(top).save(os.path.join(args.out, key + "_top.png"), optimize=True)
            Image.fromarray(bottom).save(os.path.join(args.out, key + "_bottom.png"), optimize=True)
            if env is not None:
                Image.fromarray(env).save(os.path.join(args.out, key + "_env.png"), optimize=True)
        if args.seam:
            for mode in ("bilinear", "3point"):
                ok, jump, row, bad = seam_ok(top, bottom, mode)
                if not ok:
                    failed.append((key, mode))
                print("%-17s %-8s seam jump %5.2f (row step %5.2f, %d bad columns)  %s"
                      % (key, mode, jump, row, bad, "ok" if ok else "SEAM"))
    if failed:
        print("%d seam failures" % len(failed))
        return 1
    return 0
if __name__ == "__main__":
    sys.exit(main())
