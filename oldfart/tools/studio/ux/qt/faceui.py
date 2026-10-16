import math
import time
from PySide6.QtCore import QPointF, QRectF, QSize, Qt, QTimer
from PySide6.QtGui import QColor, QFont, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import (QFrame, QHBoxLayout, QLabel, QPushButton, QSizePolicy,
                               QVBoxLayout, QWidget)
from studio.core import theme
from studio.ux import grade as gr
from . import action
action("critic.face", [], "The critic's grade", "Map",
       "The critic's face and grade: one thing to make the map better, Show me and Fix it")
SKIN = "#ffd34d"
SKIN_EDGE = "#c98f12"
INK = "#3a2a10"
JUMP_MS = 420
BLINK_EVERY_S = 5.5
def paint_face(p, rect, mood, thinking=False, blink=False, ink=INK, skin=SKIN):
    p.save()
    p.setRenderHint(QPainter.Antialiasing)
    w = min(rect.width(), rect.height())
    c = rect.center()
    r = w / 2.0 - 1
    p.setPen(QPen(QColor(SKIN_EDGE), max(1.0, w / 22.0)))
    p.setBrush(QColor(skin))
    p.drawEllipse(c, r, r)
    if mood > 0.5 and not thinking:
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(255, 120, 90, 90))
        p.drawEllipse(QPointF(c.x() - r * 0.55, c.y() + r * 0.22), r * 0.16, r * 0.11)
        p.drawEllipse(QPointF(c.x() + r * 0.55, c.y() + r * 0.22), r * 0.16, r * 0.11)
    p.setPen(Qt.NoPen)
    p.setBrush(QColor(ink))
    ey = c.y() - r * 0.22
    look = (r * 0.08, -r * 0.1) if thinking else (0.0, 0.0)
    for sx in (-1, 1):
        ex = c.x() + sx * r * 0.33 + look[0]
        if blink:
            p.setPen(QPen(QColor(ink), max(1.0, w / 16.0), Qt.SolidLine, Qt.RoundCap))
            p.drawLine(QPointF(ex - r * 0.1, ey), QPointF(ex + r * 0.1, ey))
            p.setPen(Qt.NoPen)
        else:
            p.drawEllipse(QPointF(ex, ey + look[1]), r * 0.1, r * 0.14)
    pen = QPen(QColor(ink), max(1.2, w / 13.0), Qt.SolidLine, Qt.RoundCap)
    p.setPen(pen)
    p.setBrush(Qt.NoBrush)
    my = c.y() + r * 0.38
    if thinking:
        p.drawLine(QPointF(c.x() - r * 0.18, my), QPointF(c.x() + r * 0.12, my - r * 0.04))
    else:
        bend = mood * r * 0.42
        path = QPainterPath(QPointF(c.x() - r * 0.42, my - bend * 0.35))
        path.quadTo(QPointF(c.x(), my + bend), QPointF(c.x() + r * 0.42, my - bend * 0.35))
        p.drawPath(path)
    p.restore()
class FaceWidget(QWidget):
    def __init__(self, part):
        super().__init__()
        self.part = part
        self.setObjectName("criticFace")
        self.setCursor(Qt.PointingHandCursor)
        self.setFocusPolicy(Qt.TabFocus)
        self.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
        self.g = gr.grade(None)
        self.thinking = False
        self.blink = False
        self.jump_at = None
        self.droop_at = None
        self.hover = False
        self.setAttribute(Qt.WA_Hover)
    def scale(self):
        try:
            return self.part.ux.settings["ui.scale"] / 100.0
        except Exception:
            return 1.0
    def show_words(self):
        lvl = self.part.ux.parts.get("levelui")
        return lvl is not None and lvl.simple()
    def sizeHint(self):
        s = self.scale()
        h = int(round(34 * s))
        w = h + int(round(34 * s))
        if self.show_words():
            f = self._word_font()
            from PySide6.QtGui import QFontMetrics
            w += QFontMetrics(f).horizontalAdvance(self.g.words) + int(14 * s)
        return QSize(w + int(8 * s), h)
    def _word_font(self):
        f = QFont(self.font())
        f.setPixelSize(max(10, int(round(13 * self.scale()))))
        f.setWeight(QFont.DemiBold)
        return f
    def set_grade(self, g, thinking=False):
        old = self.g
        self.g = g
        self.thinking = thinking
        motion = not self.part.ux.settings["ui.reduce_motion"]
        how = gr.change(old, g)
        if how == "up" and motion:
            self.jump_at = time.time()
            self.part.anim.start()
        elif how == "down" and motion:
            self.droop_at = time.time()
            self.part.anim.start()
        self.updateGeometry()
        self.update()
        return how
    def event(self, ev):
        from PySide6.QtCore import QEvent
        if ev.type() in (QEvent.HoverEnter, QEvent.HoverLeave):
            self.hover = ev.type() == QEvent.HoverEnter
            self.update()
        return super().event(ev)
    def mousePressEvent(self, ev):
        if ev.button() == Qt.LeftButton:
            self.part.open_card()
            ev.accept()
            return
        super().mousePressEvent(ev)
    def keyPressEvent(self, ev):
        if ev.key() in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
            self.part.open_card()
            return
        super().keyPressEvent(ev)
    def offset(self):
        now = time.time()
        s = self.scale()
        if self.jump_at is not None:
            t = (now - self.jump_at) * 1000.0 / JUMP_MS
            if t < 1.0:
                return -math.sin(t * math.pi) * 7 * s
            self.jump_at = None
        if self.droop_at is not None:
            t = (now - self.droop_at) * 1000.0 / JUMP_MS
            if t < 1.0:
                return math.sin(t * math.pi) * 3 * s
            self.droop_at = None
        return 0.0
    def paintEvent(self, _ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        t = self.part.ux.ctx.tokens or {}
        s = self.scale()
        h = self.height()
        if self.hover or self.hasFocus():
            p.setPen(QPen(QColor(t.get("accent", "#5b8cff")), 1))
            p.setBrush(QColor(t.get("hover", "#2a2e35")))
            p.drawRoundedRect(QRectF(0.5, 0.5, self.width() - 1, h - 1), h / 2.0, h / 2.0)
        dy = self.offset()
        side = h - 6 * s
        face = QRectF(4 * s, 3 * s + dy, side, side)
        paint_face(p, face, self.g.mood, thinking=self.thinking, blink=self.blink)
        bx = face.right() + 4 * s
        badge = QRectF(bx, 4 * s, h - 8 * s, h - 8 * s)
        paint_badge(p, badge, self.g, self.part.ux.settings, t)
        if self.thinking:
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(t.get("text_dim", "#aab")))
            phase = int(time.time() * 3) % 3
            for i in range(3):
                r = (2.2 if i == phase else 1.5) * s
                p.drawEllipse(QPointF(face.right() - 2 * s + i * 4.5 * s, face.top() + 2 * s), r, r)
        if self.show_words():
            p.setFont(self._word_font())
            p.setPen(QColor(t.get("text", "#e6e6e6")))
            p.drawText(QRectF(badge.right() + 8 * s, 0, self.width(), h),
                       Qt.AlignVCenter | Qt.AlignLeft, self.g.words)
        p.end()
class Card(QFrame):
    def __init__(self, part):
        super().__init__(part.window, Qt.Popup)
        self.part = part
        self.setObjectName("faceCard")
        self.setAttribute(Qt.WA_DeleteOnClose, False)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 14, 16, 14)
        lay.setSpacing(8)
        top = QHBoxLayout()
        self.face = _BigFace(part)
        top.addWidget(self.face)
        words = QVBoxLayout()
        self.title = QLabel("")
        self.title.setObjectName("faceTitle")
        self.score = QLabel("")
        self.score.setObjectName("caption")
        words.addWidget(self.title)
        words.addWidget(self.score)
        words.addStretch(1)
        top.addLayout(words, 1)
        lay.addLayout(top)
        self.tip_head = QLabel("One thing to make it better:")
        self.tip_head.setObjectName("dim")
        lay.addWidget(self.tip_head)
        self.tip = QLabel("")
        self.tip.setWordWrap(True)
        self.tip.setObjectName("faceTip")
        self.tip.setMinimumWidth(300)
        lay.addWidget(self.tip)
        row = QHBoxLayout()
        self.show_btn = QPushButton("Show me")
        self.show_btn.setToolTip("Look at where the critic saw it")
        self.show_btn.clicked.connect(lambda: (self.hide(), part.show_me()))
        self.fix_btn = QPushButton("Fix it")
        self.fix_btn.setObjectName("primary")
        self.fix_btn.setToolTip("The critic mends it itself - one undo step (Ctrl+Z takes it "
                                "back)")
        self.fix_btn.clicked.connect(lambda: (self.hide(), part.fix()))
        self.all_btn = QPushButton("All the notes")
        self.all_btn.setToolTip("The report card: every row, its score and its fix")
        self.all_btn.clicked.connect(lambda: (self.hide(), part.all_notes()))
        for b in (self.show_btn, self.fix_btn, self.all_btn):
            row.addWidget(b)
        lay.addLayout(row)
    def fill(self, g):
        self.face.g = g
        self.face.update()
        self.title.setText(g.words)
        if g.letter == "-":
            self.score.setText("The critic reads the map while you build")
        else:
            self.score.setText("Score %d  ·  a pass is %d" % (int(g.score), int(g.line)))
        self.tip_head.setVisible(bool(g.row) or g.letter == "-")
        self.tip.setText(g.tip)
        self.show_btn.setVisible(bool(g.row))
        self.fix_btn.setVisible(bool(g.row) and g.fixable)
        self.adjustSize()
def paint_badge(p, rect, g, settings, tokens):
    vis = theme.semantic(settings["ui.colour_vision"]
                         if "ui.colour_vision" in settings.values else "safe")
    colour = QColor(vis.get(g.meaning, "#666a70") if g.meaning != "none"
                    else (tokens or {}).get("raised", "#2a2e35"))
    p.save()
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(Qt.NoPen)
    p.setBrush(colour)
    rad = rect.height() * 0.28
    p.drawRoundedRect(rect, rad, rad)
    f = QFont(p.font())
    f.setPixelSize(max(9, int(rect.height() * 0.66)))
    f.setWeight(QFont.Black)
    p.setFont(f)
    p.setPen(QColor("#0e1116" if theme.luminance(colour.name()) > 0.55 else "#ffffff"))
    p.drawText(rect, Qt.AlignCenter, g.letter if g.letter != "-" else "–")
    p.restore()
class _BigFace(QWidget):
    def __init__(self, part):
        super().__init__()
        self.part = part
        self.g = gr.grade(None)
        self.setFixedSize(84, 76)
    def paintEvent(self, _ev):
        p = QPainter(self)
        paint_face(p, QRectF(2, 2, 68, 68), self.g.mood)
        paint_badge(p, QRectF(52, 44, 30, 30), self.g, self.part.ux.settings,
                    self.part.ux.ctx.tokens)
        p.end()
class FaceUI:
    def __init__(self, ux):
        self.ux = ux
        self.ed = ux.ed
        self.window = ux.window
        self.meter = getattr(ux.ed, "critic", None)
        self.widget = FaceWidget(self)
        self.card = None
        self.last = None
        self.anim = QTimer(self.widget)
        self.anim.setInterval(30)
        self.anim.timeout.connect(self._tick)
        self.blinker = QTimer(self.widget)
        self.blinker.setInterval(int(BLINK_EVERY_S * 1000))
        self.blinker.timeout.connect(self._blink)
        self.blinker.start()
        tb = self.window.toolbar
        gear = self.window.actions.get("app.preferences")
        self.action = tb.insertWidget(gear, self.widget) if gear is not None \
            else tb.addWidget(self.widget)
        ux.add_action("critic.face", self.open_card)
        if self.meter is not None:
            self.meter.judged.connect(self.judged)
            self.ed.changed.connect(self.thinking)
            self.judged(self.meter.result)
        self._tip()
    def grade(self):
        return self.widget.g
    def thinking(self):
        if self.ed.session.doc.refs("piece"):
            self.widget.thinking = True
            self.anim.start()
            self.widget.update()
    def judged(self, res):
        g = gr.grade(res)
        how = self.widget.set_grade(g, thinking=False)
        if how == "up":
            self.ux.sound("coin")
        self.last = res
        self._tip()
        if self.card is not None and self.card.isVisible():
            self.card.fill(g)
        return how
    def _tip(self):
        g = self.widget.g
        if g.letter == "-":
            text = "The critic: %s" % g.tip
        else:
            text = "The critic says %s - %s\n%s%s" % (
                g.letter, g.words, ("Next: " + g.tip) if g.row else g.tip,
                "\nClick: Show me / Fix it" if g.row else "")
        self.widget.setToolTip(text)
    def _tick(self):
        w = self.widget
        if w.thinking and self.meter is not None:
            doc = self.ed.session.doc
            settled = (self.meter.revision == (id(doc), doc.revision)
                       and not self.meter.jobs.busy() and not self.meter.timer.isActive())
            if settled or not doc.refs("piece"):
                w.thinking = False
        busy = w.thinking or w.jump_at or w.droop_at
        self.widget.update()
        if not busy:
            self.anim.stop()
    def _blink(self):
        if self.ux.settings["ui.reduce_motion"] or self.widget.thinking:
            return
        self.widget.blink = True
        self.widget.update()
        def back():
            self.widget.blink = False
            self.widget.update()
        QTimer.singleShot(140, self.widget, back)
    def open_card(self):
        if self.card is None:
            self.card = Card(self)
        self.card.fill(self.widget.g)
        w = self.widget
        pos = w.mapToGlobal(w.rect().bottomRight())
        self.card.adjustSize()
        x = pos.x() - self.card.width()
        self.card.move(max(0, x), pos.y() + 6)
        self.card.show()
        return self.card
    def show_me(self):
        g = self.widget.g
        if self.meter is not None and g.row:
            return self.meter.show_row(g.row)
        return None
    def fix(self):
        g = self.widget.g
        tools = getattr(self.ux.studio, "tools", None)
        if not g.row or tools is None:
            return None
        return tools._critic_fix(g.row)
    def all_notes(self):
        docks = self.ux.studio.docks
        if "report" in docks.keys():
            d = docks.get("report")
            d.show()
            d.raise_()
            return d
        return None
def install(ux):
    return FaceUI(ux)
