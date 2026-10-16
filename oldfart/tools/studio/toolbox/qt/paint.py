from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QPen, QPolygonF
from studio.toolbox import overlays
def colour(rgba):
    c = QColor()
    c.setRgbF(*[max(0.0, min(1.0, float(v))) for v in rgba[:3]],
              max(0.0, min(1.0, float(rgba[3] if len(rgba) > 3 else 1.0))))
    return c
VISION = "safe"
def vision_mode(view=None):
    try:
        return view.ctx.settings["ui.colour_vision"]
    except Exception:
        return VISION
def paint_layer(p, view, layer, w, h):
    from studio.ux import vision
    cam = view.camera
    out = vision.decorate(overlays.project(layer, lambda q: cam.to_pixel(q, w, h)),
                          vision_mode(view))
    for pts, rgba, meaning in out["quads"]:
        poly = QPolygonF([QPointF(x, y) for x, y in pts])
        p.setPen(Qt.NoPen)
        p.setBrush(colour(rgba))
        p.drawPolygon(poly)
        if meaning == "bad":
            p.save()
            from PySide6.QtGui import QPainterPath
            path = QPainterPath()
            path.addPolygon(poly)
            p.setClipPath(path)
            dark = colour(rgba[:3] + (min(1.0, rgba[3] + 0.35),)).darker(170)
            p.setPen(QPen(dark, 1.4))
            for a, b in vision.hatch_lines(pts):
                p.drawLine(QPointF(*a), QPointF(*b))
            p.restore()
        elif meaning == "warn":
            pen = QPen(colour(rgba[:3] + (0.95,)), 1.4, Qt.DotLine)
            p.setPen(pen)
            p.setBrush(Qt.NoBrush)
            p.drawPolygon(poly)
    for a, b, rgba, width, meaning in out["lines"]:
        pen = QPen(colour(rgba))
        pen.setWidthF(width)
        pen.setCapStyle(Qt.RoundCap)
        if meaning == "warn":
            pen.setStyle(Qt.DashLine)
        elif meaning == "bad":
            pen.setStyle(Qt.DashDotLine)
        p.setPen(pen)
        p.drawLine(QPointF(*a), QPointF(*b))
    p.setPen(QPen(QColor(0, 0, 0, 160), 1.0))
    for q, rgba, r, meaning in out["dots"]:
        p.setPen(QPen(QColor(0, 0, 0, 160), 1.0))
        p.setBrush(colour(rgba))
        p.drawEllipse(QPointF(*q), r, r)
    paint_glyphs(p, out["glyphs"])
    for q, text, rgba in out["labels"]:
        p.setPen(QColor(0, 0, 0, 170))
        p.drawText(QPointF(q[0] + 7, q[1] - 5), text)
        p.setPen(colour(theme_remap(rgba, view)))
        p.drawText(QPointF(q[0] + 6, q[1] - 6), text)
def theme_remap(rgba, view=None):
    from studio.core import theme
    return theme.remap(rgba, vision_mode(view))
def paint_glyphs(p, glyphs):
    if not glyphs:
        return
    p.save()
    f = p.font()
    f.setBold(True)
    f.setPixelSize(13)
    p.setFont(f)
    fm = p.fontMetrics()
    for (x, y), g, rgba in glyphs:
        tw = fm.horizontalAdvance(g)
        at = QPointF(x - tw / 2.0, y + fm.ascent() / 2.0 - 1)
        p.setPen(QColor(0, 0, 0, 220))
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            p.drawText(at + QPointF(dx, dy), g)
        p.setPen(colour(rgba))
        p.drawText(at, g)
    p.restore()
def paint_legend(p, layers, tokens, w, h):
    rows = []
    for layer in layers:
        if not layer.legend and not layer.note:
            continue
        rows.append(("title", layer.title, None))
        for rgba, text in layer.legend:
            rows.append(("swatch", text, rgba))
        if layer.note:
            rows.append(("note", layer.note, None))
    if not rows:
        return
    fm = p.fontMetrics()
    line = fm.height() + 3
    width = min(w - 24, max(fm.horizontalAdvance(t) for _, t, _ in rows) + 34)
    height = line * len(rows) + 12
    x, y = 12, h - height - 34
    bg = QColor(tokens.get("raised", "#22262d"))
    bg.setAlpha(225)
    p.setPen(QPen(QColor(tokens.get("border", "#3a3f47")), 1))
    p.setBrush(bg)
    p.drawRoundedRect(QRectF(x, y, width, height), 6, 6)
    ty = y + 6 + fm.ascent()
    for kind, text, rgba in rows:
        tx = x + 10
        if kind == "swatch":
            from studio.core import theme
            meaning = theme.meaning_of(rgba)
            rgba = theme.remap(rgba, VISION)
            p.setPen(Qt.NoPen)
            c = colour(rgba)
            c.setAlphaF(max(0.75, c.alphaF()))
            p.setBrush(c)
            p.drawRoundedRect(QRectF(tx, ty - fm.ascent() + 2, 12, 12), 2, 2)
            if meaning != "neutral":
                p.setPen(QColor(0, 0, 0, 220) if meaning != "bad" else QColor(255, 255, 255))
                p.drawText(QRectF(tx, ty - fm.ascent() + 2, 12, 12), Qt.AlignCenter,
                           theme.GLYPH[meaning])
            tx += 18
        f = p.font()
        f.setBold(kind == "title")
        p.setFont(f)
        p.setPen(QColor(tokens.get("text_dim" if kind == "note" else "text", "#dddddd")))
        p.drawText(QPointF(tx, ty), fm.elidedText(text, Qt.ElideRight, int(width - (tx - x) - 8)))
        ty += line
    f = p.font()
    f.setBold(False)
    p.setFont(f)
