import math
import time
from PySide6.QtCore import QEvent, QObject, QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QCursor, QFont, QPainter, QPen
from PySide6.QtWidgets import QInputDialog, QMenu, QWidget
from studio.ux import wheel as wmod
from . import action
action("wheel.open", ["Q"], "Quick wheel", "Tools",
       "Hold Q, flick toward what you want, let go (a quick tap leaves it open to click). "
       "Right-click a slice, a menu item or a palette item to put something on it")
R_OUT = 150
R_IN = 46
TAP_S = 0.22
class Radial(QWidget):
    def __init__(self, part):
        super().__init__(None, Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.part = part
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setMouseTracking(True)
        self.resize(2 * R_OUT + 40, 2 * R_OUT + 40)
        self.hot = None
    def centre(self):
        return QPointF(self.width() / 2.0, self.height() / 2.0)
    def slice_at(self, pos):
        c = self.centre()
        return self.part.wheel.slice_at(pos.x() - c.x(), pos.y() - c.y())
    def paintEvent(self, _ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        tok = self.part.ux.ctx.tokens
        c = self.centre()
        w = self.part.wheel
        n = wmod.SLICES
        f = QFont(self.font())
        f.setBold(True)
        f.setPixelSize(13)
        p.setFont(f)
        r = QRectF(c.x() - R_OUT, c.y() - R_OUT, 2 * R_OUT, 2 * R_OUT)
        for k in range(n):
            start = 90 - (k * 360.0 / n) + 180.0 / n
            col = QColor(tok["accent_soft"] if k == self.hot else tok["raised"])
            col.setAlpha(240)
            p.setPen(QPen(QColor(tok["accent"] if k == self.hot else tok["border"]), 1.5))
            p.setBrush(col)
            p.drawPie(r, int(start * 16), int(-360.0 / n * 16))
        for k in range(n):
            entry = w.entry(w.page, k)
            a = math.radians(k * 360.0 / n)
            mid = (R_OUT + R_IN) / 2.0 + 6
            at = QPointF(c.x() + math.sin(a) * mid, c.y() - math.cos(a) * mid)
            text = self.part.label(entry) if entry else "+"
            key = self.part.key_of(entry) if entry else "empty"
            p.setFont(f)
            p.setPen(QColor(tok["text"] if entry else tok["text_off"]))
            p.drawText(QRectF(at.x() - 60, at.y() - 18, 120, 22), Qt.AlignCenter, text)
            f2 = QFont(f)
            f2.setBold(False)
            f2.setPixelSize(10)
            p.setFont(f2)
            p.setPen(QColor(tok["text_dim"]))
            p.drawText(QRectF(at.x() - 60, at.y() + 2, 120, 16), Qt.AlignCenter, key)
        p.setFont(f)
        p.setPen(QPen(QColor(tok["border"]), 1.5))
        p.setBrush(QColor(tok["window"]))
        p.drawEllipse(c, R_IN, R_IN)
        p.setPen(QColor(tok["text_dim"]))
        pages = len(w.pages)
        p.drawText(QRectF(c.x() - R_IN, c.y() - 14, 2 * R_IN, 28), Qt.AlignCenter,
                   "page %d/%d" % (w.page + 1, pages) if pages > 1 else "Q")
        p.end()
    def mouseMoveEvent(self, ev):
        k = self.slice_at(ev.position())
        if k != self.hot:
            self.hot = k
            self.update()
    def mouseReleaseEvent(self, ev):
        k = self.slice_at(ev.position())
        if ev.button() == Qt.RightButton:
            if k is not None:
                self.part.slice_menu(k, ev.globalPosition().toPoint())
            return
        if k is None:
            self.part.close()
            return
        self.part.run_slice(k)
    def wheelEvent(self, ev):
        self.part.wheel.turn_page(-1 if ev.angleDelta().y() > 0 else 1)
        self.update()
    def keyPressEvent(self, ev):
        if ev.key() == Qt.Key_Escape:
            self.part.close()
class WheelUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.wheel = wmod.Wheel.from_state(ux.ed.settings_get("wheel"))
        self.radial = Radial(self)
        self.opened_at = None
        self.ran = None
        ux.add_action("wheel.open", self.open_held, menu=ux.menu("&Tools"))
        from studio.ui import appfilters
        appfilters.install(self)
        hooks = getattr(ux.ed, "palette_menu_hooks", None)
        if hooks is None:
            hooks = ux.ed.palette_menu_hooks = []
        hooks.append(lambda m, e: m.addAction("Add to quick wheel").triggered.connect(
            lambda: self.add("palette:" + e.id)))
    def label(self, entry):
        if entry is None:
            return ""
        if entry.startswith("palette:"):
            try:
                return self.ux.ed.palette.get(entry[8:]).label
            except KeyError:
                return entry[8:]
        if entry in wmod.WORDS:
            return wmod.WORDS[entry]
        a = self.ux.window.actions.get(entry)
        text = a.text().replace("&", "") if a is not None else entry
        return text if len(text) <= 18 else text[:17] + "…"
    def key_of(self, entry):
        a = self.ux.window.actions.get(entry or "")
        if a is None:
            return "click" if entry and entry.startswith("palette:") else ""
        keys = [k.toString() for k in a.shortcuts()]
        return keys[0] if keys else ""
    def add(self, entry):
        page, k = self.wheel.add(entry)
        self.save()
        self.ux.hint("%s is on the quick wheel (hold Q), page %d, slice %d"
                     % (self.label(entry), page + 1, k + 1))
        return page, k
    def save(self):
        self.ux.ed.settings_set("wheel", self.wheel.state())
    def run_entry(self, entry):
        if not entry:
            return None
        self.ran = entry
        if entry.startswith("palette:"):
            self.ux.ed.arm(entry[8:])
            return entry
        a = self.ux.window.actions.get(entry)
        if a is None:
            self.ux.hint("%s is not here (an extension is off)" % entry)
            return None
        a.trigger()
        return entry
    def open_held(self):
        return self.open(QCursor.pos(), held=True)
    def open(self, global_pos=None, held=False):
        pos = global_pos or QCursor.pos()
        r = self.radial
        r.move(pos.x() - r.width() // 2, pos.y() - r.height() // 2)
        r.hot = None
        r.show()
        r.raise_()
        self.opened_at = time.monotonic() if held else None
        self.ux.sound("open")
        return r
    def is_open(self):
        return self.radial.isVisible()
    def close(self):
        self.radial.hide()
        self.opened_at = None
    def run_slice(self, k):
        entry = self.wheel.entry(self.wheel.page, k)
        self.close()
        if entry is None:
            return self.slice_menu(k, QCursor.pos())
        return self.run_entry(entry)
    def release(self, local=None):
        if not self.is_open() or self.opened_at is None:
            return None
        held = time.monotonic() - self.opened_at
        r = self.radial
        k = r.slice_at(local if local is not None else r.mapFromGlobal(QCursor.pos()))
        if k is None:
            if held < TAP_S:
                self.opened_at = None
                return "open"
            self.close()
            return None
        return self.run_slice(k)
    def slice_menu(self, k, at):
        m = QMenu()
        page = self.wheel.page
        m.addAction("Put a command here…").triggered.connect(lambda: self.choose(page, k))
        if self.wheel.entry(page, k):
            m.addAction("Empty this slice").triggered.connect(
                lambda: (self.wheel.remove(page, k), self.save(), self.radial.update()))
        self._menu = m
        m.popup(at)
        return m
    def choose(self, page, k):
        acts = self.ux.window.actions
        names = sorted("%s  [%s]" % (a.text().replace("&", ""), aid) for aid, a in acts.items())
        got, ok = QInputDialog.getItem(self.ux.window, "Quick wheel", "Put on this slice:",
                                       names, 0, True)
        if ok and got and "[" in got:
            self.wheel.put(page, k, got.rsplit("[", 1)[1].rstrip("]"))
            self.save()
    def eventFilter(self, obj, ev):
        t = ev.type()
        if t == QEvent.KeyRelease and not ev.isAutoRepeat() and self.opened_at is not None:
            keys = [k.toString() for k in self.ux.window.actions["wheel.open"].shortcuts()]
            from PySide6.QtGui import QKeySequence
            if QKeySequence(ev.key()).toString() in keys:
                self.release()
                return True
        if t == QEvent.MouseButtonRelease and ev.button() == Qt.RightButton \
                and isinstance(obj, QMenu):
            a = obj.actionAt(ev.position().toPoint())
            aid = next((k for k, v in self.ux.window.actions.items() if v is a), None)
            if aid is not None and aid != "wheel.open":
                obj.close()
                self.add(aid)
                return True
        return False
def install(ux):
    return WheelUI(ux)
