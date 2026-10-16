import math
ENGINE_NEAR = 5.0
LEVEL_NEAR = 100.0
LEVEL_FAR = 32767.0
ENGINE_FAR_DD6 = 1000000.0
FRUSTUM_FAR = 30000.0
ENGINE_PLANES = {"near": ENGINE_NEAR, "far": ENGINE_FAR_DD6, "level_near": LEVEL_NEAR,
                 "level_far": FRUSTUM_FAR}
VANILLA_POSITION = (960, 1000)
HAZE_START = 8000
def _s16(v):
    v = int(v) & 0xFFFF
    return v - 0x10000 if v & 0x8000 else v
def _cdiv(a, b):
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q
def position_words(fmin, fmax):
    return (_s16(_cdiv(128000, fmax - fmin)), _s16(_cdiv((500 - fmin) * 256, fmax - fmin)))
def x_of(d, near=ENGINE_NEAR, far=LEVEL_FAR, level_near=LEVEL_NEAR, level_far=LEVEL_FAR):
    z = d * (near + far) / (far - near) - 2.0 * near * far / (far - near)
    z = (z - level_near) * (level_far - near) / (level_far - level_near) + (2.0 * near - level_near)
    return z / d
def x_horizon(near=ENGINE_NEAR, far=LEVEL_FAR, level_near=LEVEL_NEAR, level_far=LEVEL_FAR):
    return (near + far) / (far - near) * (level_far - near) / (level_far - level_near)
def factor(d, mul, off, intensity=1.0, **planes):
    if d <= 0:
        return 0.0
    f = x_of(d, **planes) * mul * intensity + off
    return max(0.0, min(255.0, f)) / 255.0
def factors(d, mul, off, intensity=1.0):
    import numpy as np
    d = np.maximum(np.asarray(d, np.float64), 1e-3)
    n, f, ln, lf = ENGINE_NEAR, ENGINE_FAR_DD6, LEVEL_NEAR, FRUSTUM_FAR
    z = d * (n + f) / (f - n) - 2.0 * n * f / (f - n)
    z = (z - ln) * (lf - n) / (lf - ln) + (2.0 * n - ln)
    return np.clip((z / d) * mul * intensity + off, 0.0, 255.0) / 255.0
def haze_words(start, end=None, intensity=1.0, **planes):
    x0 = x_of(float(start), **planes)
    x1 = x_horizon(**planes) if end is None else x_of(float(end), **planes)
    span = max(x1 - x0, 1e-6)
    mul = 255.0 / (span * intensity)
    off = -x0 * mul * intensity
    return _s16_round(mul), _s16_round(off)
def _s16_round(v):
    return max(-32768, min(32767, int(math.floor(v + 0.5))))
def depth_at(share, mul, off, intensity=1.0):
    lo, hi = 1.0, 1e7
    if factor(hi, mul, off, intensity) < share:
        return None
    if factor(lo, mul, off, intensity) >= share:
        return lo
    for _ in range(80):
        mid = math.sqrt(lo * hi)
        if factor(mid, mul, off, intensity) < share:
            lo = mid
        else:
            hi = mid
    return hi
_REPO = __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.dirname(
    __import__("os").path.dirname(__import__("os").path.abspath(__file__)))))
_lua = None
SKY_ORDER = ("BACKGROUND_OCEAN_SKY", "BACKGROUND_FLAMING_SKY", "BACKGROUND_UNDERWATER_CITY",
             "BACKGROUND_BELOW_CLOUDS", "BACKGROUND_SNOW_MOUNTAINS", "BACKGROUND_DESERT",
             "BACKGROUND_HAUNTED", "BACKGROUND_GREEN_SKY", "BACKGROUND_ABOVE_CLOUDS",
             "BACKGROUND_PURPLE_SKY")
def _modifiers_text():
    global _lua
    if _lua is None:
        import os
        with open(os.path.join(_REPO, "of_modifiers.lua"), encoding="utf-8") as handle:
            _lua = handle.read()
    return _lua
def sky_airs():
    import re
    text = _modifiers_text()
    at = text.index("local SKY_AIR = {")
    body = text[at:text.index("\n    }", at)]
    out = {}
    for k, r, g, b in re.findall(r"\[(\d+)\] = \{ (\d+), (\d+), (\d+) \}", body):
        if int(k) < len(SKY_ORDER):
            out[SKY_ORDER[int(k)]] = (int(r), int(g), int(b))
    return out
def sky_air(sky):
    return sky_airs().get(sky)
def paint_reach():
    import re
    text = _modifiers_text()
    m = re.search(r"modifiers\.PAINT_FAR, modifiers\.PAINT_NEAR, modifiers\.PAINT_WHOLE = "
                  r"(\d+), (\d+), (\d+)", text)
    t = re.search(r"^local FOG_THICKEST = ([\d.]+)", text, re.M)
    return int(m.group(1)), int(m.group(2)), int(m.group(3)), float(t.group(1))
def reach(stop, amount=None):
    far, near, whole, thickest = paint_reach()
    full = (stop.get("fogx", 118) / 100.0 - 1.0) / (thickest - 1.0)
    a = full if amount is None else amount
    a = max(0.0, min(1.0, a))
    haze = stop.get("haze")
    if isinstance(haze, (int, float)) and haze > 0:
        share = max(0.05, min(1.0, a / max(full, 0.01)))
        return haze / share, None
    start = far * (float(near) / far) ** a
    return start, start * whole
def stop_words(stop, **planes):
    start, end = reach(stop)
    return haze_words(start, end, stop.get("fogx", 118) / 100.0, **planes)
def linear(mul, off, intensity=1.0, near=ENGINE_NEAR, far=ENGINE_FAR_DD6, level_near=LEVEL_NEAR,
           level_far=FRUSTUM_FAR):
    m = (level_far - near) / (level_far - level_near)
    a = (near + far) / (far - near) * m
    b = (-2.0 * near * far / (far - near) - level_near) * m + (2.0 * near - level_near)
    return (a * mul * intensity + off, b * mul * intensity)
def look_fog(look):
    from .. import modpack
    got, _ = modpack.resolve_look({"look": look if isinstance(look, dict) else {}}, [])
    fog = got.get("fog")
    if not fog or len(fog) < 6:
        return None
    return (fog[4], fog[5], fog[0], tuple(c / 255.0 for c in fog[1:4]))
