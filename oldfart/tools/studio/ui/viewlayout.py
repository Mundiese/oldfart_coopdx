from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (QFrame, QHBoxLayout, QLabel, QMenu, QSizePolicy, QSplitter,
                               QToolButton,
                               QVBoxLayout, QWidget)
from ..core import camera as cam_mod
from .viewport import Viewport
SIDES = ("user", "top", "bottom", "front", "back", "left", "right")
class Pane(QWidget):
    def __init__(self, ctx, side, parent=None):
        super().__init__(parent)
        self.ctx = ctx
        self.view = Viewport(ctx, side)
        self.header = QFrame()
        self.header.setObjectName("paneHeader")
        self.header.setMinimumHeight(26)
        self.header.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Fixed)
        hl = QHBoxLayout(self.header)
        hl.setContentsMargins(6, 0, 6, 0)
        hl.setSpacing(4)
        self.menu_button = QToolButton()
        self.menu_button.setPopupMode(QToolButton.InstantPopup)
        self.menu_button.setToolButtonStyle(Qt.ToolButtonTextOnly)
        menu = QMenu(self.menu_button)
        for side_name in SIDES:
            label = cam_mod.LABELS[side_name]
            act = menu.addAction(label if side_name != "user" else "3D view")
            act.triggered.connect(lambda _=False, s=side_name: self.set_side(s))
        menu.addSeparator()
        menu.addAction("Perspective / orthographic\tNum 5").triggered.connect(
            lambda: self.view.numpad("5"))
        menu.addAction("Frame all\tHome").triggered.connect(self.view.frame_all)
        menu.addAction("Frame selected\tNum .").triggered.connect(self.view.frame_selected)
        self.menu_button.setMenu(menu)
        hl.addWidget(self.menu_button)
        hl.addStretch(1)
        self.info = QLabel("")
        self.info.setObjectName("caption")
        hl.addWidget(self.info)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        lay.addWidget(self.header)
        lay.addWidget(self.view, 1)
        self.view.cameraChanged.connect(lambda *_: self._label())
        self._label()
    def set_side(self, side):
        if side == "user":
            cam = self.view.camera.copy()
            cam.side = "user"
            cam.yaw, cam.pitch = 35.0, 30.0
            cam.set_ortho(False)
            self.view.set_camera(cam, animate=True)
        else:
            self.view.view_side(side)
    def _label(self):
        self.menu_button.setText(self.view.camera.label() + "  ▾")
    def set_active(self, on):
        self.view.active = on
        self.header.setProperty("active", "true" if on else "false")
        self.header.style().unpolish(self.header)
        self.header.style().polish(self.header)
        self.view.update()
class ViewLayout(QWidget):
    activeChanged = Signal(object)
    def __init__(self, ctx, parent=None):
        super().__init__(parent)
        self.ctx = ctx
        sides = [s.strip() for s in ctx.settings["view.quad"].split(",")]
        sides = [s if s in SIDES else "user" for s in sides][:4]
        while len(sides) < 4:
            sides.append(("top", "user", "front", "right")[len(sides)])
        self.panes = [Pane(ctx, s) for s in sides]
        self.main = next((p for p in self.panes if p.view.camera.side == "user"), self.panes[1])
        self.active = self.main
        self.top = QSplitter(Qt.Horizontal)
        self.bottom = QSplitter(Qt.Horizontal)
        self.rows = QSplitter(Qt.Vertical)
        for sp in (self.top, self.bottom, self.rows):
            sp.setHandleWidth(2)
            sp.setChildrenCollapsible(False)
        self.top.addWidget(self.panes[0])
        self.top.addWidget(self.panes[1])
        self.bottom.addWidget(self.panes[2])
        self.bottom.addWidget(self.panes[3])
        self.rows.addWidget(self.top)
        self.rows.addWidget(self.bottom)
        self.top.splitterMoved.connect(lambda *_: self.bottom.setSizes(self.top.sizes()))
        self.bottom.splitterMoved.connect(lambda *_: self.top.setSizes(self.bottom.sizes()))
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.addWidget(self.rows)
        self._linking = False
        for p in self.panes:
            p.view.activated.connect(self._activate)
            p.view.cameraChanged.connect(self._link)
        self.mode = None
        self.maximised = None
        self.set_mode(ctx.settings["view.layout"])
        self._activate(self.main.view)
    def views(self):
        return [p.view for p in self.panes]
    def visible_views(self):
        return [p.view for p in self.panes if p.isVisible()]
    def pane_of(self, view):
        return next(p for p in self.panes if p.view is view)
    def set_mode(self, mode):
        self.mode = mode
        self.maximised = None
        for p in self.panes:
            p.setVisible(mode == "quad" or p is self.main)
        self.top.setVisible(mode == "quad" or self.main in (self.panes[0], self.panes[1]))
        self.bottom.setVisible(mode == "quad" or self.main in (self.panes[2], self.panes[3]))
        for p in self.panes:
            p.header.setVisible(True)
        if mode == "quad":
            self._even()
        self._activate(self.main.view if mode == "single" else self.active.view)
    def toggle_quad(self):
        self.set_mode("single" if self.mode == "quad" else "quad")
        return self.mode
    def toggle_maximise(self):
        if self.mode != "quad":
            return
        if self.maximised is not None:
            self.maximised = None
            for p in self.panes:
                p.setVisible(True)
            self.top.setVisible(True)
            self.bottom.setVisible(True)
            return
        self.maximised = self.active
        for p in self.panes:
            p.setVisible(p is self.active)
        self.top.setVisible(self.active in (self.panes[0], self.panes[1]))
        self.bottom.setVisible(self.active in (self.panes[2], self.panes[3]))
    def _even(self):
        w, h = max(2, self.width()), max(2, self.height())
        self.top.setSizes([w // 2, w // 2])
        self.bottom.setSizes([w // 2, w // 2])
        self.rows.setSizes([h // 2, h // 2])
    def _activate(self, view):
        pane = self.pane_of(view)
        if pane is not self.active or not view.active:
            self.active.set_active(False)
            self.active = pane
            pane.set_active(True)
            self.activeChanged.emit(view)
    def _link(self, view):
        if self._linking or not self.ctx.settings["view.link_ortho"]:
            return
        cam = view.camera
        if not cam.ortho or cam.side == "user":
            return
        self._linking = True
        try:
            for other in self.views():
                if other is view:
                    continue
                oc = other.camera
                if oc.ortho and oc.side != "user":
                    oc.target = cam.target
                    oc.ortho_size = cam.ortho_size
                    other.update()
        finally:
            self._linking = False
    def frame_all(self, animate=True):
        self._linking = True
        try:
            for v in self.views():
                v.frame_all(animate=False)
        finally:
            self._linking = False
        linked = [v for v in self.views() if v.camera.ortho and v.camera.side != "user"]
        if self.ctx.settings["view.link_ortho"] and len(linked) > 1:
            size = max(v.camera.ortho_size for v in linked)
            for v in linked:
                v.camera.ortho_size = size
                v.update()
    def state(self):
        return {"mode": self.mode, "cameras": [p.view.camera.state() for p in self.panes]}
    def restore(self, state):
        try:
            for p, s in zip(self.panes, state.get("cameras", [])):
                p.view.camera = cam_mod.Camera.from_state(s)
                p._label()
        except (KeyError, TypeError, ValueError):
            pass
