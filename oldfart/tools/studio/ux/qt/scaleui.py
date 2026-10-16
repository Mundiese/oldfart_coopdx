from PySide6.QtCore import QEvent, QObject, QPointF, QSize, Qt
from . import action
action("view.large", ["Ctrl+Alt+="], "Large UI", "View",
       "Everything bigger: 150 % interface, a 16 px font, a bigger gizmo and palette tiles "
       "(again: back to how it was)")
action("view.fly_toggle", ["Ctrl+Alt+F"], "Fly (toggle)", "View",
       "Fly without holding a button: W A S D, Q / E down / up, the mouse looks around; "
       "press it again or Esc to stop")
LARGE = {"ui.scale": 150, "ui.font_size": 16, "gizmo.size": 144}
class ScaleUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.settings = ux.settings
        v = ux.menu("&View")
        self.large_action = ux.add_action("view.large", self.large, checkable=True, menu=v)
        self.large_action.setChecked(bool(self._before()))
        ux.add_action("view.fly_toggle", self.toggle_fly, menu=v)
        self.settings.listen(self._setting)
        self._icons()
        self.flying = None
        for view in ux.studio.views.views():
            view.installEventFilter(self)
    def _before(self):
        st = self.settings.state if isinstance(self.settings.state, dict) else {}
        return st.get("large_before")
    def _setting(self, key, _value):
        if key == "ui.scale":
            self._icons()
            hb = self.ux.parts.get("hotbarui")
            if hb is not None:
                hb.refresh()
    def _icons(self):
        tb = getattr(self.ux.window, "toolbar", None)
        if tb is not None:
            side = int(round(20 * self.settings["ui.scale"] / 100.0))
            tb.setIconSize(QSize(side, side))
    def large(self, on=None):
        st = self.settings.state
        if on is None:
            on = not bool(self._before())
        if on:
            if not self._before():
                st["large_before"] = {k: self.settings[k] for k in LARGE}
            for k, v in LARGE.items():
                self.settings.set(k, v)
        else:
            for k, v in (self._before() or {}).items():
                self.settings.set(k, v)
            st.pop("large_before", None)
        pal = getattr(self.ux.ed, "palette_panel", None)
        lvl = self.ux.parts.get("levelui")
        if pal is not None and hasattr(pal, "set_big"):
            pal.set_big(on or (lvl is not None and lvl.simple()))
        if self.large_action.isChecked() != on:
            self.large_action.blockSignals(True)
            self.large_action.setChecked(on)
            self.large_action.blockSignals(False)
        self.ux.hint("Large UI %s" % ("on - everything bigger" if on else "off"))
        return on
    def toggle_fly(self):
        view = self.ux.view()
        if view is None:
            return None
        if getattr(view, "_fly", None) is not None:
            view.end_fly()
            self.flying = None
            self.ux.hint("Fly off")
            return False
        view.start_fly(QPointF(view.width() / 2.0, view.height() / 2.0))
        self.flying = view
        self.ux.hint("Flying (no button needed): W A S D, Q / E down / up, the mouse looks - "
                     "Ctrl+Alt+F or Esc stops")
        return True
    def eventFilter(self, obj, ev):
        if self.flying is obj and ev.type() == QEvent.KeyPress and ev.key() == Qt.Key_Escape:
            obj.end_fly()
            self.flying = None
            return True
        return False
def install(ux):
    return ScaleUI(ux)
