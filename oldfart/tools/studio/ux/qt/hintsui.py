from PySide6.QtCore import QObject, QTimer, Qt
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout
from studio.ux import hints as H
STATE_KEY = "hints"
SHOW_S = 22
NUDGES = ("edit.nudge_left", "edit.nudge_right", "edit.nudge_back", "edit.nudge_front",
          "edit.nudge_up", "edit.nudge_down")
DUPS = ("edit.duplicate", "edit.dup_left", "edit.dup_right", "edit.dup_back", "edit.dup_front",
        "edit.dup_up")
KNOWN_BY_ACTION = {"gizmo.move": "gizmo", "edit.drop": "drop", "edit.drop_group": "drop",
                   "tools.symmetry": "symmetry", "edit.stack": "stack", "edit.scrub": "scrub"}
class Chip(QFrame):
    def __init__(self, part, parent):
        super().__init__(parent)
        self.part = part
        self.setObjectName("tipChip")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(14, 8, 10, 8)
        lay.setSpacing(4)
        top = QHBoxLayout()
        top.setSpacing(6)
        self.glyph = QLabel("✦")
        self.glyph.setObjectName("tipGlyph")
        self.head = QLabel("A faster way")
        self.head.setObjectName("tipHead")
        top.addWidget(self.glyph)
        top.addWidget(self.head)
        top.addStretch(1)
        lay.addLayout(top)
        self.text = QLabel("")
        self.text.setObjectName("tipText")
        self.text.setWordWrap(True)
        lay.addWidget(self.text)
        row = QHBoxLayout()
        row.addStretch(1)
        self.off = QPushButton("No more tips")
        self.off.setObjectName("coachLink")
        self.off.setToolTip("Turn the faster-way tips off (Preferences > Look turns them on "
                            "again)")
        self.off.clicked.connect(part.turn_off)
        self.got = QPushButton("Got it")
        self.got.setObjectName("tipButton")
        self.got.setToolTip("Thanks - this tip will not come again")
        self.got.clicked.connect(part.dismiss)
        row.addWidget(self.off)
        row.addWidget(self.got)
        lay.addLayout(row)
class HintsUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.window = ux.window
        st = self._store().get(STATE_KEY) or {}
        self.watch = H.Watcher(known=st.get("known") or (), shown=st.get("shown") or ())
        self.views = ux.studio.views
        self.chip = Chip(self, self.views)
        self.chip.hide()
        self.tip = None
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self.dismiss)
        self._seen_change = None
        self._in_menu = None
        self._laying = 0
        acts = self.window.actions
        for aid in NUDGES:
            self._on(aid, lambda: self.feed("nudge", selection=self._selection()))
        for aid in DUPS:
            self._on(aid, lambda: self.feed("duplicate"))
        for aid in ("edit.mirror_x", "edit.mirror_z"):
            self._on(aid, lambda: self.feed("mirror"))
        self._on("edit.undo", lambda: self.feed("undo"))
        self._on("edit.paint", lambda: self.feed("paint", count=len(self.ed.session.refs())))
        for aid, kind in KNOWN_BY_ACTION.items():
            self._on(aid, lambda k=kind: self.feed(k))
        for aid, a in acts.items():
            a.triggered.connect(lambda *_, aid=aid: self._triggered(aid))
        for a in self.window.menuBar().actions():
            if a.menu() is not None:
                a.menu().triggered.connect(self._menu_chosen)
        self.ed.changed.connect(self._changed)
        real = self.ed.lay_row
        def lay_row(start, end):
            self._laying += 1
            try:
                return real(start, end)
            finally:
                self._laying -= 1
                self.feed("row")
        self.ed.lay_row = lay_row
        self.views.installEventFilter(self)
    def _store(self):
        st = self.ux.settings
        if not isinstance(st.state, dict):
            st.state = {}
        return st.state
    def _save(self):
        self._store()[STATE_KEY] = self.watch.state()
    def enabled(self):
        try:
            return bool(self.ux.settings["ui.hints"])
        except KeyError:
            return True
    def _on(self, aid, fn):
        a = self.window.actions.get(aid)
        if a is not None:
            a.triggered.connect(lambda *_: fn())
    def _selection(self):
        return frozenset(self.ed.session.refs())
    def feed(self, kind, **data):
        tip = self.watch.event(kind, **data)
        self._save()
        if tip is None:
            return None
        if not self.enabled():
            self.watch.shown.discard(tip.id)
            self.watch.said -= 1
            self._save()
            return None
        return self.show(tip)
    def _triggered(self, aid):
        self._in_menu = aid
        QTimer.singleShot(0, self, lambda: self._settle(aid))
    def _settle(self, aid):
        if self._in_menu == aid:
            self.watch.event("key", aid=aid)
            self._in_menu = None
    def _menu_chosen(self, action):
        aid = next((k for k, v in self.window.actions.items() if v is action), None)
        if aid is None:
            return None
        self._in_menu = None
        keys = [k.toString() for k in action.shortcuts()]
        if not keys:
            return None
        return self.feed("menu", aid=aid, label=action.text().replace("&", ""), key=keys[0])
    def _changed(self):
        stack = self.ed.session.stack
        last = stack.done[-1] if stack.done else None
        if last is None or last is self._seen_change:
            return
        self._seen_change = last
        label = last.label or ""
        if label.startswith(("Paint the surface", "Paint the wall run")):
            self.feed("fill")
        elif label.startswith("Lay a floor"):
            self.feed("row")
        elif label.startswith("Place ") and not self._laying:
            at = None
            for step in last.steps:
                if step[0] == "insert" and isinstance(step[3], dict) and "x" in step[3]:
                    at = (step[3].get("x", 0), step[3].get("y", 0), step[3].get("z", 0))
                    break
            self.feed("place", what=label[6:], at=at)
    def show(self, tip):
        self.tip = tip
        self.chip.text.setText(tip.text)
        self.place()
        self.chip.show()
        self.chip.raise_()
        self.timer.start(SHOW_S * 1000)
        return tip
    def place(self):
        w = max(240, min(520, self.views.width() - 24))
        self.chip.setFixedWidth(w)
        self.chip.layout().activate()
        h = self.chip.layout().heightForWidth(w) if self.chip.layout().hasHeightForWidth() \
            else self.chip.sizeHint().height()
        self.chip.setFixedHeight(max(h, self.chip.minimumSizeHint().height()))
        self.chip.move(max(8, (self.views.width() - self.chip.width()) // 2), 36)
    def dismiss(self):
        self.timer.stop()
        self.chip.hide()
        self.tip = None
    def turn_off(self):
        self.ux.settings.set("ui.hints", False)
        self.dismiss()
        self.ux.hint("Faster-way tips are off - Preferences > Look turns them on again")
    def eventFilter(self, obj, ev):
        from PySide6.QtCore import QEvent
        try:
            if ev.type() == QEvent.Resize and obj is self.views and self.chip.isVisible():
                self.place()
        except RuntimeError:
            pass
        return False
def install(ux):
    return HintsUI(ux)
