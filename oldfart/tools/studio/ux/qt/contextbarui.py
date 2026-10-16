from PySide6.QtCore import QObject, QTimer, Qt
from PySide6.QtWidgets import QFrame, QHBoxLayout, QMenu, QToolButton
from studio.editor import geometry as geo
from studio.ux import contextbar as cb
ICONS = {"gizmo.move": "✥", "edit.turn": "↻", "tools.variant_next": "◆",
         "edit.paint": "✎", "edit.duplicate": "❐", "edit.delete": "✕",
         "more": "…", "edit.group": "⧉", "edit.mirror_x": "⇆",
         "lib.save_prefab": "☆", "tools.push_face": "⬆", "tools.pull_face": "⬇",
         "build.hollow": "▢", "build.carve": "◌", "edit.drop": "⤓",
         "tools.paste_sticky": "❖", "plane.up": "↑",
         "plane.down": "↓", "select.none": "↩", "hotbar.slot1": "➕",
         "tools.room": "▣", "tools.brush_raise": "⛰", "tools.brush_paint": "✒",
         "house.brush": "⌂", "map.play": "★", "hand": "✋"}
class Bar(QFrame):
    def __init__(self, parent):
        super().__init__(parent)
        self.setObjectName("contextBar")
        self.lay = QHBoxLayout(self)
        self.lay.setContentsMargins(6, 4, 6, 4)
        self.lay.setSpacing(2)
        self.buttons = []
    def set_buttons(self, rows):
        for b in self.buttons:
            self.lay.removeWidget(b)
            b.hide()
            if b not in rows:
                b.deleteLater()
        self.buttons = []
        for b in rows:
            self.lay.addWidget(b)
            b.show()
            self.buttons.append(b)
        self.lay.activate()
        self.adjustSize()
class ContextBarUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.ctx = ux.ctx
        self.views = ux.studio.views
        self.bar = Bar(self.views)
        self.bar.hide()
        self.kind = None
        self.overflow = []
        self._armed = None
        self._moving = False
        self._idle = QTimer(self)
        self._idle.setSingleShot(True)
        self._idle.setInterval(350)
        self._idle.timeout.connect(self._settled)
        self._poll = QTimer(self)
        self._poll.setInterval(200)
        self._poll.timeout.connect(self._check_hand)
        self._poll.start()
        self.ed.session.selection.listeners.append(lambda *_: self.refresh())
        self.ed.changed.connect(self.refresh)
        for v in self.views.views():
            v.cameraChanged.connect(self._camera)
            if hasattr(v, "lmbDrag"):
                v.lmbDrag.connect(self._dragging)
        ux.settings.listen(lambda key, _v: key in ("ui.context_bar", "ui.level")
                           and self.refresh())
        self.refresh()
    def enabled(self):
        up = getattr(self.ctx, "start_screen", None)
        try:
            if up is not None and up():
                return False
        except RuntimeError:
            pass
        lvl = self.ux.parts.get("levelui")
        if lvl is not None and lvl.simple():
            return True
        try:
            return bool(self.ux.settings["ui.context_bar"])
        except KeyError:
            return True
    def rows(self):
        s = self.ed.session
        kind = cb.kind_of(s.doc, s.refs(), self.ed.armed)
        acts = self.ux.window.actions
        out = []
        for aid, word in cb.buttons(kind, set(acts)):
            b = QToolButton()
            b.setObjectName("contextButton")
            b.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
            if aid == "hand":
                word = self.hand_label()
            a = acts.get(aid)
            keys = [k.toString() for k in a.shortcuts()][:1] if a is not None else []
            b.setText("%s\n%s" % (ICONS.get(aid, ""), word))
            tip = word
            if a is not None:
                tip = "%s%s - %s" % (word, ("  (%s)" % keys[0]) if keys else "",
                                     a.statusTip() or a.text().replace("&", ""))
            elif aid == "more":
                tip = "More: the right-click menu"
            b.setToolTip(tip)
            b.setProperty("aid", aid)
            if aid == "more":
                b.clicked.connect(lambda _=False, b=b: self.more(b))
            elif a is not None:
                b.clicked.connect(lambda _=False, a=a: a.trigger())
            out.append(b)
        return kind, out
    def _signature(self):
        try:
            s = self.ed.session
            kind = cb.kind_of(s.doc, s.refs(), self.ed.armed)
            acts = self.ux.window.actions
            lvl = self.ux.parts.get("levelui")
            return (kind, tuple(cb.buttons(kind, set(acts))), self.ed.armed,
                    self.hand_label() if kind == "hand" else None,
                    getattr(lvl, "level", None), self.views.width())
        except Exception:
            return None
    def hand_label(self):
        armed = self.ed.armed
        try:
            return self.ed.palette.get(armed).label
        except (KeyError, TypeError):
            return {"eraser": "Eraser", "corridor": "Hallway"}.get(armed, "In the hand")
    def refresh(self, *_):
        if not self.enabled():
            self.bar.hide()
            return None
        sig = self._signature()
        if sig is not None and sig == getattr(self, "_built", None) and self.bar.buttons:
            kind = self.kind
        else:
            kind, rows = self.rows()
            self.kind = kind
            self.bar.set_buttons(rows)
            self.fit()
            self._built = sig
        self.place()
        if getattr(self, "too_narrow", False):
            self.bar.hide()
            return kind
        if not self._moving:
            self.bar.show()
            self.bar.raise_()
        return kind
    def fit(self):
        self.overflow = []
        self.too_narrow = False
        room = self.views.width() - 12
        if self.bar.sizeHint().width() <= room:
            return []
        buttons = list(self.bar.buttons)
        more = next((b for b in buttons if b.property("aid") == "more"), None)
        if more is None:
            more = QToolButton()
            more.setObjectName("contextButton")
            more.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
            more.setText("%s\n%s" % (ICONS["more"], "More"))
            more.setToolTip("More: the rest of these and the right-click menu")
            more.setProperty("aid", "more")
            more.clicked.connect(lambda _=False, b=more: self.more(b))
            buttons.append(more)
        keep = [b for b in buttons if b is not more]
        while keep and len(keep) > 2:
            self.bar.set_buttons(keep + [more])
            if self.bar.sizeHint().width() <= room:
                break
            self.overflow.insert(0, keep.pop().property("aid"))
        self.bar.set_buttons(keep + [more])
        for b in buttons:
            if b is not more and b not in keep:
                b.deleteLater()
        self.too_narrow = self.bar.sizeHint().width() > room
        return self.overflow
    def words(self):
        return [b.text().split("\n", 1)[-1] for b in self.bar.buttons]
    def place(self):
        v = self.ux.view()
        bw, bh = self.bar.sizeHint().width(), self.bar.sizeHint().height()
        W, H = self.views.width(), self.views.height()
        hb = self.ux.parts.get("hotbarui")
        bottom = H - (hb.widget.height() + 18 if hb is not None else 10)
        x, y = (W - bw) // 2, bottom - bh - 6
        rect = self.selection_rect(v)
        if rect is not None and self.kind not in ("nothing", "hand"):
            x0, y0, x1, y1 = rect
            x = int((x0 + x1) / 2 - bw / 2)
            y = int(y1 + 24)
            if y + bh > bottom:
                y = int(y0 - 24 - bh)
        x = max(6, min(W - bw - 6, x))
        y = max(30, min(H - bh - 6, y))
        self.bar.move(x, y)
    def selection_rect(self, v):
        if v is None:
            return None
        doc = self.ed.session.doc
        boxes = [geo.aabb(doc.view_item(r)) for r in self.ed.session.refs()]
        b = geo.union(boxes)
        if b is None:
            return None
        w, h = max(1, v.width()), max(1, v.height())
        pts = [v.camera.to_pixel((x, y, z), w, h) for x in b[:2] for y in b[2:4] for z in b[4:]]
        pts = [p for p in pts if p is not None]
        if not pts:
            return None
        off = v.mapTo(self.views, v.rect().topLeft())
        xs = [p[0] + off.x() for p in pts]
        ys = [p[1] + off.y() for p in pts]
        return min(xs), min(ys), max(xs), max(ys)
    def more(self, button):
        m = QMenu(button)
        thing = bool(self.ed.session.refs())
        acts = self.ux.window.actions
        for aid in getattr(self, "overflow", None) or []:
            if aid in acts:
                m.addAction(acts[aid])
        if getattr(self, "overflow", None):
            m.addSeparator()
        for aid in (self.ed.MENU_ON_THING if thing else self.ed.MENU_ON_NOTHING):
            if aid is None:
                m.addSeparator()
            elif aid in acts:
                m.addAction(acts[aid])
        self._menu = m
        m.popup(button.mapToGlobal(button.rect().bottomLeft()))
        return m
    def _camera(self, *_):
        if self.bar.isVisible():
            self.bar.hide()
        self._moving = True
        self._idle.start()
    def _dragging(self, _view, _a, _b, phase):
        self._moving = phase != "end"
        if self._moving:
            self.bar.hide()
        else:
            self._idle.start()
    def _settled(self):
        self._moving = False
        self.refresh()
    def _check_hand(self):
        if self.ed.armed != self._armed:
            self._armed = self.ed.armed
            self.refresh()
def install(ux):
    return ContextBarUI(ux)
