from PySide6.QtCore import QEvent, QObject, QPointF, Qt
from PySide6.QtGui import QColor
from studio.ux import plane
from . import ACTIONS, action
action("plane.up", ["Alt+PgUp"], "Work plane up", "Work plane",
       "The grid you build on goes up one cell (PgUp does it too when nothing is "
       "selected; Ctrl+wheel in a view) - for building in mid-air")
action("plane.down", ["Alt+PgDown"], "Work plane down", "Work plane",
       "The grid you build on goes down one cell (PgDn with nothing selected)")
action("plane.up_floor", [], "Up a floor", "Work plane",
       "The work plane one floor (4 m) higher")
action("plane.down_floor", [], "Down a floor", "Work plane",
       "The work plane one floor (4 m) lower")
action("plane.to_selection", ["Alt+Home"], "Work plane to the selection's top", "Work plane",
       "Put the work plane on the top of what is selected: the next things go on it")
action("plane.ground", ["Alt+Shift+Home"], "Work plane back to the ground", "Work plane",
       "The work plane at 0, the ground")
action("plane.lock", ["Ctrl+Shift+Space"], "Stay on the work plane", "Work plane",
       "On: the cursor ignores what is in front and stays on the work plane (hold Space "
       "for the same while you place)")
class PlaneUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ctx = ux.ctx
        self.ctx.plane_only = False
        self.locked = False
        self.held = False
        m = ux.menu("B&uild").addMenu("Work plane")
        self.menu = m
        ux.add_action("plane.up", lambda: self.step(1), menu=m)
        ux.add_action("plane.down", lambda: self.step(-1), menu=m)
        ux.add_action("plane.up_floor", lambda: self.step(1, floor=True), menu=m)
        ux.add_action("plane.down_floor", lambda: self.step(-1, floor=True), menu=m)
        ux.add_action("plane.to_selection", self.to_selection, menu=m)
        ux.add_action("plane.ground", lambda: self.set_height(0), menu=m)
        self.lock_action = ux.add_action("plane.lock", self.toggle_lock, checkable=True, menu=m)
        ed = ux.ed
        original = ed.run_action
        def run_action(aid):
            if aid in ("edit.nudge_up", "edit.nudge_down") and not ed.session.refs():
                return self.step(1 if aid == "edit.nudge_up" else -1)
            return original(aid)
        ed.run_action = run_action
        for v in ux.studio.views.views():
            v.installEventFilter(self)
        self.ctx.painters.append(self._paint)
    def height(self):
        return int(self.ctx.settings["grid.height"])
    def set_height(self, h):
        h = int(max(plane.LO, min(plane.HI, h)))
        self.ctx.settings.set("grid.height", h)
        self.ux.hint(plane.label(h))
        v = self.ux.view()
        if v is not None:
            v.show_toast(plane.label(h), seconds=1.4)
        self._refresh_ghost()
        self.ctx.redraw()
        return h
    def step(self, direction, fine=False, floor=False):
        h = self.height()
        if floor:
            new = int(round(h / float(plane.FLOOR)) + direction) * plane.FLOOR
        else:
            new = plane.step(h, direction, fine)
        self.ux.sound("tick", up=direction > 0)
        return self.set_height(new)
    def to_selection(self):
        ed = self.ux.ed
        top = plane.top_of(ed.session.doc, ed.session.refs())
        if top is None:
            self.ux.hint("Select something first: the work plane goes onto its top")
            return None
        return self.set_height(int(round(top)))
    def toggle_lock(self, on=None):
        self.locked = (not self.locked) if on is None else bool(on)
        self._apply()
        self.ux.hint("Stay on the work plane: %s" % ("on - the cursor ignores what is in front"
                                                     if self.locked else "off"))
    def set_held(self, on):
        self.held = bool(on)
        self._apply()
    def _apply(self):
        self.ctx.plane_only = self.locked or self.held
        if self.lock_action.isChecked() != self.locked:
            self.lock_action.blockSignals(True)
            self.lock_action.setChecked(self.locked)
            self.lock_action.blockSignals(False)
        self.ctx.redraw()
    def _refresh_ghost(self):
        for v in self.ux.studio.views.views():
            if getattr(v, "_mouse", None) is not None:
                try:
                    v._hover_now()
                except Exception:
                    pass
    def eventFilter(self, obj, ev):
        t = ev.type()
        if t == QEvent.Wheel and ev.modifiers() & Qt.ControlModifier:
            from studio.ui.viewport import is_touchpad
            if not is_touchpad(ev):
                n = ev.angleDelta().y()
                if n:
                    self.step(1 if n > 0 else -1, fine=bool(ev.modifiers() & Qt.ShiftModifier))
                return True
        if t in (QEvent.KeyPress, QEvent.KeyRelease) and ev.key() == Qt.Key_Space \
                and not ev.isAutoRepeat() and not ev.modifiers() & (Qt.ControlModifier
                                                                    | Qt.AltModifier):
            if getattr(obj, "_fly", None) is None:
                self.set_held(t == QEvent.KeyPress)
                self._refresh_ghost()
                return True
        return False
    def _paint(self, view, p, w, h):
        hgt = self.height()
        if hgt == 0 and not self.ctx.plane_only:
            return
        t = self.ctx.tokens
        txt = plane.label(hgt) + ("  (held)" if self.ctx.plane_only else "")
        view._text(p, 12, 56, txt, QColor(t["accent"] if self.ctx.plane_only else t["text"]),
                   bold=self.ctx.plane_only)
def install(ux):
    return PlaneUI(ux)
__all__ = ["PlaneUI", "install", "QPointF"]
