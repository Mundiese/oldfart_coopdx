import random
def spots(particles, w, h, seed=7):
    if not particles or w <= 0 or h <= 0:
        return []
    kind, _colour, count, streak = particles
    n = max(4, int(count * (w * h) / (900.0 * 600.0)))
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        size = rnd.uniform(1.4, 3.2) if kind != "ring" else rnd.uniform(2.5, 5.5)
        dx = -streak * 0.25 if streak else 0.0
        dy = float(streak)
        out.append((x, y, dx, dy, size))
    return out
def paint(p, particles, w, h):
    from PySide6.QtCore import QPointF, Qt
    from PySide6.QtGui import QColor, QPen
    kind, colour, _count, _streak = particles
    c = QColor.fromRgbF(colour[0], colour[1], colour[2], 0.55)
    p.save()
    for x, y, dx, dy, size in spots(particles, w, h):
        if kind == "streak":
            pen = QPen(c)
            pen.setWidthF(1.1)
            p.setPen(pen)
            p.drawLine(QPointF(x, y), QPointF(x + dx, y + dy))
        elif kind == "ring":
            pen = QPen(c)
            pen.setWidthF(1.0)
            p.setPen(pen)
            p.setBrush(Qt.NoBrush)
            p.drawEllipse(QPointF(x, y), size, size)
        else:
            p.setPen(Qt.NoPen)
            p.setBrush(c)
            if dy:
                p.drawEllipse(QPointF(x, y), size, size * 1.6)
            else:
                p.drawEllipse(QPointF(x, y), size, size)
    p.restore()
