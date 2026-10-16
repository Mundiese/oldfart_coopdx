from PySide6.QtCore import QObject, Qt
from PySide6.QtWidgets import QToolButton
HEADER = (("edit.undo", "↶ Undo", "Take back the last thing (Ctrl+Z)"),
          ("edit.redo", "↷ Redo", "Do it again (Ctrl+Shift+Z)"),
          ("plane.up_floor", "↑ Floor", "Build one floor higher (the work plane goes up 4 m)"),
          ("plane.down_floor", "↓ Floor", "Build one floor lower"),
          ("map.play", "★ Play", "Play it in the game: put it in the game and start "
                                 "Coop DX (F6)"))
UNIFIED = "ui_unified_1013"
class LevelUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.window = ux.window
        self.level = "full"
        self.who = None
        self.card = None
        self.first_pending = False
        self.simple_buttons = []
        self._build_header()
        self._migrate()
    def _build_header(self):
        tb = self.window.toolbar
        first = tb.actions()[0] if tb.actions() else None
        acts = self.window.actions
        for aid, text, tip in HEADER:
            a = acts.get(aid)
            b = QToolButton()
            b.setText(text)
            b.setToolTip(tip)
            b.setAccessibleName(text.split(" ", 1)[-1])
            b.setObjectName("bigHeader")
            b.setToolButtonStyle(Qt.ToolButtonTextOnly)
            b.setFocusPolicy(Qt.NoFocus)
            if a is not None:
                b.clicked.connect(lambda _=False, a=a: a.trigger())
            else:
                b.clicked.connect(lambda _=False, aid=aid: self._run(aid))
            wa = tb.insertWidget(first, b)
            wa.setVisible(aid in acts)
            self.simple_buttons.append((aid, wa, b))
        if first is not None:
            tb.insertSeparator(first)
        fit = getattr(self.window, "header_fit", None)
        if fit is not None:
            fit.add_step("header words", lambda on: self.compact(on, keep=("map.play",)), order=20)
            fit.add_step("play words", lambda on: self.compact(on, only=("map.play",)), order=40)
    def compact(self, on, keep=(), only=None):
        for (aid, text, _tip), (_aid, _wa, b) in zip(HEADER, self.simple_buttons):
            if aid in keep or (only is not None and aid not in only):
                continue
            b.setText(text.split(" ", 1)[0] if on else text)
    def _run(self, aid):
        a = self.window.actions.get(aid)
        if a is not None:
            a.trigger()
    def _migrate(self):
        settings = self.ux.settings
        state = settings.state if isinstance(settings.state, dict) else None
        if state is None or state.get(UNIFIED):
            return False
        state[UNIFIED] = True
        before = state.pop("large_before", None)
        if isinstance(before, dict):
            for k, v in before.items():
                try:
                    settings.set(k, v)
                except Exception:
                    pass
        state.pop("layout_full", None)
        pal = getattr(self.ux.ed, "palette_panel", None)
        if pal is not None and hasattr(pal, "set_big"):
            pal.set_big(False)
        return True
    def simple(self):
        return False
    def toggle(self):
        return self.level
    def apply(self, level="full", save=True, first=False):
        return self.level
    def full_name(self, aid):
        a = self.window.actions.get(aid)
        return a.text() if a is not None else aid
    def menu_of(self, aid):
        return None
def install(ux):
    return LevelUI(ux)
