import math
from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QIcon, QPainter, QPainterPath, QPen, QPixmap
SIZE = 20
def _single(p):
    p.drawRoundedRect(QRectF(3, 3, 14, 14), 2, 2)
def _quad(p):
    p.drawRoundedRect(QRectF(3, 3, 14, 14), 2, 2)
    p.drawLine(QPointF(10, 3), QPointF(10, 17))
    p.drawLine(QPointF(3, 10), QPointF(17, 10))
def _persp(p):
    path = QPainterPath(QPointF(4, 15))
    path.lineTo(16, 15)
    path.lineTo(13, 5)
    path.lineTo(7, 5)
    path.closeSubpath()
    p.drawPath(path)
    p.drawLine(QPointF(10, 5), QPointF(10, 15))
def _grid(p):
    for k in (4, 8, 12, 16):
        p.drawLine(QPointF(k, 3), QPointF(k, 17))
        p.drawLine(QPointF(3, k), QPointF(17, k))
def _edges(p):
    p.drawRect(QRectF(4, 7, 9, 9))
    p.drawLine(QPointF(4, 7), QPointF(7, 4))
    p.drawLine(QPointF(13, 7), QPointF(16, 4))
    p.drawLine(QPointF(13, 16), QPointF(16, 13))
    p.drawLine(QPointF(7, 4), QPointF(16, 4))
    p.drawLine(QPointF(16, 4), QPointF(16, 13))
def _markers(p):
    p.drawEllipse(QPointF(10, 7), 3.2, 3.2)
    path = QPainterPath(QPointF(10, 17))
    path.lineTo(6.5, 9.5)
    path.moveTo(10, 17)
    path.lineTo(13.5, 9.5)
    p.drawPath(path)
def _snap(p):
    path = QPainterPath(QPointF(5, 4))
    path.lineTo(5, 11)
    path.arcTo(QRectF(5, 6, 10, 10), 180, 180)
    path.lineTo(15, 4)
    p.drawPath(path)
    p.drawLine(QPointF(3.5, 7), QPointF(6.5, 7))
    p.drawLine(QPointF(13.5, 7), QPointF(16.5, 7))
def _select(p):
    path = QPainterPath(QPointF(5, 3))
    path.lineTo(15, 11)
    path.lineTo(10.5, 11.5)
    path.lineTo(13, 16.5)
    path.lineTo(11, 17.5)
    path.lineTo(8.5, 12.5)
    path.lineTo(5, 15.5)
    path.closeSubpath()
    p.drawPath(path)
def _move(p):
    p.drawLine(QPointF(10, 3), QPointF(10, 17))
    p.drawLine(QPointF(3, 10), QPointF(17, 10))
    for a in range(4):
        ang = a * math.pi / 2
        tip = QPointF(10 + math.cos(ang) * 7, 10 + math.sin(ang) * 7)
        l = QPointF(10 + math.cos(ang + 0.5) * 4.5, 10 + math.sin(ang + 0.5) * 4.5)
        r = QPointF(10 + math.cos(ang - 0.5) * 4.5, 10 + math.sin(ang - 0.5) * 4.5)
        p.drawLine(tip, l)
        p.drawLine(tip, r)
def _rotate(p):
    p.drawArc(QRectF(4, 4, 12, 12), 30 * 16, 280 * 16)
    p.drawLine(QPointF(15.2, 6.0), QPointF(15.6, 2.6))
    p.drawLine(QPointF(15.2, 6.0), QPointF(11.8, 5.8))
def _frame(p):
    for (x, y, dx, dy) in ((3, 3, 1, 1), (17, 3, -1, 1), (3, 17, 1, -1), (17, 17, -1, -1)):
        p.drawLine(QPointF(x, y), QPointF(x + 4 * dx, y))
        p.drawLine(QPointF(x, y), QPointF(x, y + 4 * dy))
    p.drawRect(QRectF(7.5, 7.5, 5, 5))
def _open(p):
    path = QPainterPath(QPointF(3, 15))
    path.lineTo(3, 5)
    path.lineTo(8, 5)
    path.lineTo(9.5, 7)
    path.lineTo(16, 7)
    path.lineTo(16, 9)
    p.drawPath(path)
    path = QPainterPath(QPointF(3, 15))
    path.lineTo(6, 9)
    path.lineTo(18, 9)
    path.lineTo(15, 15)
    path.closeSubpath()
    p.drawPath(path)
def _shading(p):
    p.drawEllipse(QPointF(10, 10), 7, 7)
    path = QPainterPath(QPointF(10, 3))
    path.arcTo(QRectF(3, 3, 14, 14), 90, -180)
    path.closeSubpath()
    p.fillPath(path, p.pen().color())
def _settings(p):
    p.drawEllipse(QPointF(10, 10), 3, 3)
    for a in range(8):
        ang = a * math.pi / 4
        p.drawLine(QPointF(10 + math.cos(ang) * 5.5, 10 + math.sin(ang) * 5.5),
                   QPointF(10 + math.cos(ang) * 7.5, 10 + math.sin(ang) * 7.5))
    p.drawEllipse(QPointF(10, 10), 5.5, 5.5)
DRAW = {"single": _single, "quad": _quad, "persp": _persp, "grid": _grid, "edges": _edges,
        "markers": _markers, "snap": _snap, "select": _select, "move": _move,
        "rotate": _rotate, "frame": _frame, "open": _open, "shading": _shading,
        "settings": _settings}
def pixmap(name, colour, scale=2.0):
    pm = QPixmap(int(SIZE * scale), int(SIZE * scale))
    pm.setDevicePixelRatio(scale)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    pen = QPen(QColor(colour))
    pen.setWidthF(1.6)
    pen.setCapStyle(Qt.RoundCap)
    pen.setJoinStyle(Qt.RoundJoin)
    p.setPen(pen)
    p.setBrush(Qt.NoBrush)
    DRAW[name](p)
    p.end()
    return pm
def icon(name, tokens):
    ic = QIcon()
    ic.addPixmap(pixmap(name, tokens["text_dim"]), QIcon.Normal, QIcon.Off)
    ic.addPixmap(pixmap(name, tokens["text"]), QIcon.Active, QIcon.Off)
    ic.addPixmap(pixmap(name, tokens["accent"]), QIcon.Normal, QIcon.On)
    ic.addPixmap(pixmap(name, tokens["accent"]), QIcon.Active, QIcon.On)
    ic.addPixmap(pixmap(name, tokens["text_off"]), QIcon.Disabled, QIcon.Off)
    return ic
def swatch(rgba, size=32):
    from PySide6.QtGui import QImage
    img = QImage(rgba, 32, 32, 32 * 4, QImage.Format_RGBA8888).copy()
    pm = QPixmap.fromImage(img).scaled(size, size, Qt.IgnoreAspectRatio, Qt.FastTransformation)
    return QIcon(pm)
