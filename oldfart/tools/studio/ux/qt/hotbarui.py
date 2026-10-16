from PySide6.QtCore import QEvent, QObject, QPoint, QRectF, QSize, Qt
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QMenu, QWidget
from studio.ux import hotbar
from . import action
for _k in range(hotbar.SLOTS):
    action("hotbar.slot%d" % (_k + 1), [str(_k + 1), "Alt+%d" % (_k + 1)],
           "Hotbar slot %d" % (_k + 1), "Hotbar",
           "Take what hotbar slot %d holds into the hand (the last things you placed fill "
           "the bar; pinned ones stay)" % (_k + 1))
    action("hotbar.pin%d" % (_k + 1), ["Ctrl+Shift+%d" % (_k + 1)],
           "Pin to hotbar slot %d" % (_k + 1), "Hotbar",
           "Keep what is in the hand (or the last thing placed) in hotbar slot %d for good"
           % (_k + 1))
TILE = 54
GAP = 6
class HotbarWidget(QWidget):
    def __init__(self, part, parent):
        super().__init__(parent)
        self.part = part
        self.setMouseTracking(True)
        self.setAttribute(Qt.WA_NoSystemBackground)
        self.setToolTip("The hotbar: what you placed last, on the number keys. Right-click a "
                        "slot to pin what is in the hand there")
        self._hover = -1
    def tile(self):
        room = (self.parentWidget().width() - 16 - GAP) // hotbar.SLOTS - GAP \
            if self.parentWidget() is not None else TILE
        return int(max(30, min(TILE * self.part.scale(), room)))
    def sizeHint(self):
        t = self.tile()
        return QSize(hotbar.SLOTS * (t + GAP) + GAP, t + 2 * GAP)
    def slot_at(self, pos):
        t = self.tile()
        k = int((pos.x() - GAP) // (t + GAP))
        return k if 0 <= k < hotbar.SLOTS else -1
    def paintEvent(self, _ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        tok = self.part.ux.ctx.tokens
        t = self.tile()
        bg = QColor(tok["window"])
        bg.setAlpha(215)
        p.setPen(QPen(QColor(tok["border"]), 1))
        p.setBrush(bg)
        p.drawRoundedRect(QRectF(0.5, 0.5, self.width() - 1, self.height() - 1), 10, 10)
        bar = self.part.bar
        f = QFont(self.font())
        f.setPixelSize(max(9, int(t * 0.2)))
        f.setBold(True)
        p.setFont(f)
        for k in range(hotbar.SLOTS):
            r = QRectF(GAP + k * (t + GAP), GAP, t, t)
            eid = bar.slots[k]
            cur = (k == bar.current and eid and self.part.ux.ed.armed == eid)
            p.setPen(QPen(QColor(tok["accent"] if cur else tok["border"]), 2 if cur else 1))
            p.setBrush(QColor(tok["accent_soft"] if (cur or k == self._hover) else tok["raised"]))
            p.drawRoundedRect(r, 7, 7)
            icon = self.part.icon(eid)
            if icon is not None:
                p.drawPixmap(r.adjusted(7, 5, -7, -9).toRect(), icon.pixmap(QSize(t, t)))
            key = hotbar.key_for(k, self.part.emulated()).replace("Alt+", "⌥")
            p.setPen(QColor(0, 0, 0, 180))
            p.drawText(r.adjusted(5, 3, 0, 0), Qt.AlignLeft | Qt.AlignTop, key)
            p.setPen(QColor(tok["text"]))
            p.drawText(r.adjusted(4, 2, 0, 0), Qt.AlignLeft | Qt.AlignTop, key)
            if bar.pinned(k):
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(tok["accent"]))
                p.drawEllipse(r.topRight() + QPoint(-8, 8), 3.5, 3.5)
        p.end()
    def mouseMoveEvent(self, ev):
        k = self.slot_at(ev.position())
        if k != self._hover:
            self._hover = k
            eid = self.part.bar.get(k) if k >= 0 else None
            self.setToolTip(self.part.tip(k, eid))
            self.update()
    def leaveEvent(self, _ev):
        self._hover = -1
        self.update()
    def mousePressEvent(self, ev):
        k = self.slot_at(ev.position())
        if k < 0:
            return
        if ev.button() == Qt.RightButton:
            self.part.slot_menu(k, self.mapToGlobal(ev.position().toPoint()))
        else:
            self.part.take(k)
class HotbarUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.bar = hotbar.Hotbar()
        known = {e.id for e in self.ed.palette.entries}
        self.bar.restore(self.ed.settings_get("hotbar", {}), known)
        self.bar.fill(self.ed.palette.recent)
        self.icons = {}
        m = ux.menu("E&dit").addMenu("Hotbar")
        for k in range(hotbar.SLOTS):
            ux.add_action("hotbar.slot%d" % (k + 1), lambda k=k: self.take(k), menu=m)
        m.addSeparator()
        for k in range(hotbar.SLOTS):
            ux.add_action("hotbar.pin%d" % (k + 1), lambda k=k: self.pin_hand(k), menu=m)
        views = ux.studio.views
        self.widget = HotbarWidget(self, views)
        views.installEventFilter(self)
        for v in views.views():
            v.installEventFilter(self)
        self.ed.changed.connect(self.refresh)
        hooks = getattr(self.ed, "palette_menu_hooks", None)
        if hooks is None:
            hooks = self.ed.palette_menu_hooks = []
        hooks.append(self.palette_menu)
        ux.settings.listen(lambda key, _v: key in ("nav.emulate_numpad", "ui.scale_tiles")
                           and self.refresh())
        self.place()
        self.widget.show()
    def emulated(self):
        return bool(self.ux.settings["nav.emulate_numpad"])
    def scale(self):
        part = self.ux.parts.get("levelui")
        k = self.ux.settings["ui.scale"] / 100.0
        return k * (1.25 if part is not None and part.simple() else 1.0)
    def icon(self, eid):
        if not eid:
            return None
        if eid not in self.icons:
            try:
                from studio.editor.qt import widgets
                e = self.ed.palette.get(eid)
                self.icons[eid] = widgets.icon_for(e, self.ed.session.texture, self.ed.tokens)
            except Exception:
                self.icons[eid] = None
        return self.icons[eid]
    def tip(self, k, eid):
        if k < 0:
            return ""
        key = hotbar.key_for(k, self.emulated())
        if not eid:
            return "Slot %d (%s) is empty - what you place shows up here" % (k + 1, key)
        try:
            label = self.ed.palette.get(eid).label
        except KeyError:
            label = eid
        return "%s - %s takes it into the hand%s" % (
            label, key, " (pinned)" if self.bar.pinned(k) else "; Ctrl+Shift+%d pins it" % (k + 1))
    def refresh(self, *_):
        self.bar.fill(self.ed.palette.recent)
        self.place()
        self.widget.update()
    def save(self):
        self.ed.settings_set("hotbar", self.bar.state())
    def take(self, k):
        eid = self.bar.get(k)
        if not eid:
            self.ux.hint("Hotbar slot %d is empty - place something and it shows up there"
                         % (k + 1))
            return None
        self.bar.current = k
        try:
            e = self.ed.palette.get(eid)
        except KeyError:
            return None
        if e.section == "textures":
            self.ed.set_texture(e.key)
        else:
            self.ed.arm(eid)
        self.ux.sound("tick", up=True)
        self.widget.update()
        return eid
    def hand(self):
        armed = self.ed.armed
        if armed and ":" in armed:
            return armed
        return self.ed.palette.recent[0] if self.ed.palette.recent else None
    def pin_hand(self, k, eid=None):
        eid = eid or self.hand()
        if not eid:
            self.ux.hint("Take something into the hand first (a palette item), then pin it")
            return None
        self.bar.pin(k, eid)
        self.save()
        self.widget.update()
        try:
            label = self.ed.palette.get(eid).label
        except KeyError:
            label = eid
        self.ux.hint("%s pinned to hotbar slot %d" % (label, k + 1))
        return eid
    def unpin(self, k):
        self.bar.unpin(k)
        self.save()
        self.refresh()
    def palette_menu(self, menu, entry):
        sub = menu.addMenu("Pin to hotbar slot")
        for k in range(hotbar.SLOTS):
            sub.addAction("%d%s" % (k + 1, "  (pinned: %s)" % self.bar.pins[k]
                                    if k in self.bar.pins else "")).triggered.connect(
                lambda _=False, k=k: self.pin_hand(k, entry.id))
        return sub
    def slot_menu(self, k, at):
        m = QMenu(self.widget)
        hand = self.hand()
        if hand:
            try:
                label = self.ed.palette.get(hand).label
            except KeyError:
                label = hand
            m.addAction("Pin %s here" % label).triggered.connect(lambda: self.pin_hand(k, hand))
        if self.bar.pinned(k):
            m.addAction("Unpin").triggered.connect(lambda: self.unpin(k))
        if not m.actions():
            m.addAction("Empty - place something first").setEnabled(False)
        self._menu = m
        m.popup(at)
        return m
    def place(self):
        views = self.ux.studio.views
        w = self.widget
        size = w.sizeHint()
        w.resize(size)
        x = max(4, (views.width() - size.width()) // 2)
        y = max(0, views.height() - size.height() - 10)
        w.move(x, y)
        w.raise_()
    def eventFilter(self, obj, ev):
        t = ev.type()
        if obj is self.ux.studio.views and t in (QEvent.Resize, QEvent.Show):
            self.place()
        elif t == QEvent.Wheel and ev.modifiers() & Qt.AltModifier \
                and not ev.modifiers() & Qt.ControlModifier:
            d = ev.angleDelta().y() or ev.angleDelta().x()
            if d:
                k = self.bar.cycle(-1 if d > 0 else 1)
                if k is not None:
                    self.take(k)
            return True
        return False
def install(ux):
    return HotbarUI(ux)
