import math
from studio.core import theme
GLYPH_MIN_PX = 16
def _span(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return max(xs) - min(xs), max(ys) - min(ys)
def decorate(projected, mode="safe"):
    out = {"quads": [], "lines": [], "dots": [], "labels": list(projected.get("labels", [])),
           "glyphs": []}
    for pts, rgba in projected.get("quads", []):
        meaning = theme.meaning_of(rgba)
        col = theme.remap(rgba, mode)
        out["quads"].append((pts, col, meaning))
        w, h = _span(pts)
        if meaning != "neutral" and min(w, h) >= GLYPH_MIN_PX:
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            out["glyphs"].append(((cx, cy), theme.GLYPH[meaning], (1.0, 1.0, 1.0, 1.0)))
    for a, b, rgba, width in projected.get("lines", []):
        meaning = theme.meaning_of(rgba)
        out["lines"].append((a, b, theme.remap(rgba, mode), width, meaning))
    for q, rgba, r in projected.get("dots", []):
        meaning = theme.meaning_of(rgba)
        col = theme.remap(rgba, mode)
        out["dots"].append((q, col, r, meaning))
        if meaning != "neutral":
            out["glyphs"].append((q, theme.GLYPH[meaning], (1.0, 1.0, 1.0, 1.0)))
    return out
def legend_rows(layer_legend, mode="safe"):
    out = []
    for rgba, text in layer_legend:
        meaning = theme.meaning_of(rgba)
        out.append((theme.remap(rgba, mode), theme.GLYPH[meaning] if meaning != "neutral"
                    else "", text))
    return out
def hatch_lines(pts, step=7.0):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    out = []
    n = int(math.ceil(((x1 - x0) + (y1 - y0)) / step))
    for k in range(n + 1):
        c = x0 + k * step
        out.append(((c, y0), (c - (y1 - y0), y1)))
    return out
