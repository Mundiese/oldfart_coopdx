import os
import time
from PySide6.QtCore import QByteArray, Qt, QTimer
from PySide6.QtGui import QAction, QActionGroup, QKeySequence
from PySide6.QtWidgets import (QComboBox, QDialog, QFileDialog, QHeaderView, QLabel, QMainWindow,
                               QMessageBox, QSizePolicy, QTableWidget, QTableWidgetItem, QToolButton,
                               QVBoxLayout, QWidget)
from .. import APP_NAME, VERSION
from ..core import keymap, loader, snap as snap_mod
from . import icons
from .docks import DockSlots
from .panels import SceneInfoPanel
from .prefs import Preferences
from .viewlayout import ViewLayout
NUMPAD_OF = {"view.front": "1", "view.back": "ctrl+1", "view.right": "3", "view.left": "ctrl+3",
             "view.top": "7", "view.bottom": "ctrl+7", "view.toggle_ortho": "5",
             "view.opposite": "9", "view.orbit_up": "8", "view.orbit_down": "2",
             "view.orbit_left": "4", "view.orbit_right": "6", "view.zoom_in": "+",
             "view.zoom_out": "-", "view.frame_selected": "."}
SHADINGS = ("textured", "flat", "height", "game light", "baked")
HOURS = (("as made", "As made"), ("day", "Day"), ("dusk", "Dusk"), ("night", "Night"))
class HourSlider(QWidget):
    def __init__(self, settings, parent=None):
        from PySide6.QtWidgets import QHBoxLayout, QSlider
        super().__init__(parent)
        self.settings = settings
        lay = QHBoxLayout(self)
        lay.setContentsMargins(4, 0, 4, 0)
        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(0, len(HOURS) - 1)
        self.slider.setPageStep(1)
        self.slider.setTickPosition(QSlider.TicksBelow)
        self.slider.setFixedWidth(72)
        self.label = QLabel()
        lay.addWidget(self.slider)
        lay.addWidget(self.label)
        self.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Preferred)
        self.setToolTip("Preview the map at day, dusk or night (baked shading)")
        keys = [k for k, _ in HOURS]
        now = settings["view.hour"]
        self.slider.setValue(keys.index(now) if now in keys else 0)
        self.label.setText(HOURS[self.slider.value()][1])
        self.slider.setToolTip("Preview hour: %s" % HOURS[self.slider.value()][1])
        self.slider.valueChanged.connect(self._moved)
    def compact(self, on):
        self.label.setVisible(not on)
    def _moved(self, i):
        self.label.setText(HOURS[i][1])
        self.slider.setToolTip("Preview hour: %s" % HOURS[i][1])
        self.settings.set("view.hour", HOURS[i][0])
        if HOURS[i][0] != "as made" and self.settings["view.shading"] != "baked":
            self.settings.set("view.shading", "baked")
    def hour(self):
        return HOURS[self.slider.value()][0]
def grid_words(units):
    if units < 100:
        return "%d cm" % units
    m = units / 100.0
    return ("%d m" % m) if m == int(m) else ("%.1f m" % m)
class HintLabel(QLabel):
    def minimumSizeHint(self):
        from PySide6.QtCore import QSize
        return QSize(40, super().minimumSizeHint().height())
    def sizeHint(self):
        return self.minimumSizeHint()
    def setText(self, text):
        super().setText(text)
        self.setToolTip(text if text else "")
    def paintEvent(self, _ev):
        from PySide6.QtGui import QPainter
        p = QPainter(self)
        r = self.contentsRect()
        p.setPen(self.palette().color(self.foregroundRole()))
        p.drawText(r, int(Qt.AlignLeft | Qt.AlignVCenter),
                   self.fontMetrics().elidedText(self.text(), Qt.ElideRight, r.width()))
        p.end()
def first_size(screen=None):
    try:
        from PySide6.QtGui import QGuiApplication
        scr = screen or QGuiApplication.primaryScreen()
        geo = scr.availableGeometry() if scr is not None else None
    except Exception:
        geo = None
    if geo is None or geo.width() <= 0:
        return 1440, 900
    w = max(min(1100, geo.width()), int(geo.width() * 0.9))
    h = max(min(700, geo.height()), int(geo.height() * 0.9))
    return min(w, geo.width()), min(h, geo.height())
class StudioWindow(QMainWindow):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        self.settings = ctx.settings
        self.actions = {}
        self.setWindowTitle(APP_NAME)
        self.resize(*first_size())
        self.views = ViewLayout(ctx)
        self.setCentralWidget(self.views)
        from .bakepreview import BakePreview
        self.bake_preview = BakePreview(ctx)
        self.setDockNestingEnabled(True)
        self.setCorner(Qt.BottomLeftCorner, Qt.LeftDockWidgetArea)
        self.setCorner(Qt.BottomRightCorner, Qt.RightDockWidgetArea)
        self.setCorner(Qt.TopLeftCorner, Qt.LeftDockWidgetArea)
        self.setCorner(Qt.TopRightCorner, Qt.RightDockWidgetArea)
        self._build_actions()
        self._build_menus()
        self._build_toolbar()
        self._build_status()
        self.docks = DockSlots(self, self.panels_menu)
        self.info_panel = SceneInfoPanel(ctx)
        self.docks.add("right", "scene", "Scene", self.info_panel)
        self.apply_keys()
        from . import keyguard
        keyguard.install()
        ctx.status.connect(self.hint)
        ctx.cursorMoved.connect(self._cursor)
        ctx.selectionChanged.connect(lambda *_: self._selection_label())
        ctx.markerSelectionChanged.connect(lambda *_: self._selection_label())
        ctx.piecesChanged.connect(lambda *_: self._count_label())
        ctx.gizmoModeChanged.connect(self._gizmo_mode_changed)
        self.settings.listen(self._setting)
        for v in self.views.views():
            v.frameTimed.connect(self._frame_time)
        self._restore()
        self.hint("Middle-drag orbits, Shift+middle pans, the wheel zooms; numpad 1/3/7 for the sides.")
    def add_action(self, action_id, handler, label=None, checkable=False, icon=None, keys=None,
                   group="Editor"):
        if action_id not in keymap.ACTIONS:
            keymap.register(action_id, keys or [], label or action_id, group)
        a = QAction(label or keymap.ACTIONS[action_id][1], self)
        a.setCheckable(checkable)
        if icon:
            a.setIcon(icons.icon(icon, self.ctx.tokens))
        a.setShortcutContext(Qt.WindowShortcut)
        if checkable:
            a.toggled.connect(handler)
        else:
            a.triggered.connect(lambda _=False: handler())
        self.addAction(a)
        self.actions[action_id] = a
        return a
    def apply_keys(self):
        table = self.settings.keys
        emulated = table.table(self.settings["nav.emulate_numpad"])
        extra = {}
        for key, action in emulated.items():
            extra.setdefault(action, []).append(key)
        for action_id, a in self.actions.items():
            keys = table.keys(action_id) if action_id in keymap.ACTIONS else []
            keys = [k for k in keys if emulated.get(keymap.normalise(k)) == action_id]
            for k in extra.get(action_id, []):
                if k not in [keymap.normalise(x) for x in keys]:
                    keys.append(k)
            a.setShortcuts([QKeySequence(k) for k in keys if k])
            tip = a.text().replace("&", "")
            if keys:
                tip += "  (%s)" % ", ".join(keys[:2])
            if a.statusTip():
                tip += " - " + a.statusTip()
            a.setToolTip(tip)
    def _baked_then(self, key, value):
        self.settings.set(key, value)
        if self.settings["view.shading"] != "baked":
            self.settings.set("view.shading", "baked")
    def _build_actions(self):
        av = self.active_view
        for action_id, key in NUMPAD_OF.items():
            self.add_action(action_id, lambda k=key: av().numpad(k))
        self.add_action("view.frame_all", lambda: av().frame_all(), icon="frame")
        self.add_action("view.quad", self._toggle_quad, checkable=True, icon="quad")
        self.add_action("view.maximize", self.views.toggle_maximise)
        self.add_action("view.pie", self._view_pie)
        self.add_action("view.shading_cycle", self._cycle_shading, icon="shading")
        self.add_action("view.edges", lambda on: self.settings.set("view.edges", on),
                        checkable=True, icon="edges")
        self.add_action("view.grid", lambda on: self.settings.set("view.grid", on),
                        checkable=True, icon="grid")
        self.add_action("view.markers", lambda on: self.settings.set("view.markers", on),
                        checkable=True, icon="markers")
        self.add_action("snap.toggle", lambda on: self.settings.set("grid.snap", on),
                        checkable=True, icon="snap")
        self.add_action("snap.finer", lambda: self._step(-1))
        self.add_action("snap.coarser", lambda: self._step(1))
        grp = QActionGroup(self)
        for mode, ic in (("none", "select"), ("move", "move"), ("rotate", "rotate")):
            a = self.add_action("gizmo." + mode, lambda m=mode: self.ctx.set_gizmo_mode(m),
                                checkable=False, icon=ic)
            a.setCheckable(True)
            grp.addAction(a)
        self.actions["gizmo.none"].setChecked(True)
        sc = self.ctx.scene
        self.add_action("select.all", lambda: sc.set_selection(range(len(sc.pieces))))
        self.add_action("select.none", self._escape)
        self.add_action("select.invert",
                        lambda: sc.set_selection(set(range(len(sc.pieces))) - sc.selection))
        self.add_action("file.open", self.open_dialog, icon="open")
        self.add_action("file.screenshot", self.screenshot_dialog)
        self.add_action("app.preferences", self.preferences, icon="settings")
        self.add_action("app.shortcuts", self.shortcuts)
        from .workspaces import WORKSPACES, Workspaces
        self.workspaces = Workspaces(self)
        for name, (label, key, _) in WORKSPACES.items():
            self.add_action("view.workspace_" + name, lambda n=name: self.workspaces.switch(n),
                            "Workspace: %s" % label, keys=[key], group="View")
        self.add_action("view.reset_layout", lambda: self.workspaces.reset(),
                        "Reset layout", keys=["Ctrl+Shift+0"], group="View")
        s = self.settings
        for aid, key in (("view.edges", "view.edges"), ("view.grid", "view.grid"),
                         ("view.markers", "view.markers"), ("snap.toggle", "grid.snap")):
            self.actions[aid].setChecked(s[key])
        self.actions["view.quad"].setChecked(s["view.layout"] == "quad")
    def _build_menus(self):
        mb = self.menuBar()
        f = mb.addMenu("&File")
        f.addAction(self.actions["file.open"])
        f.addAction("Open folder...").triggered.connect(self.open_folder_dialog)
        self.venues_menu = f.addMenu("Venues")
        for src, key in loader.sources():
            self.venues_menu.addAction(key).triggered.connect(lambda _=False, s=src: self.open(s))
        self.recent_menu = f.addMenu("Recent")
        self.recent_menu.aboutToShow.connect(self._fill_recent)
        f.addAction("Reload").triggered.connect(self.reload)
        f.addSeparator()
        f.addAction(self.actions["file.screenshot"])
        f.addSeparator()
        f.addAction(self.actions["app.preferences"])
        f.addSeparator()
        f.addAction("Quit").triggered.connect(self.close)
        e = mb.addMenu("&Select")
        for aid in ("select.all", "select.none", "select.invert"):
            e.addAction(self.actions[aid])
        v = mb.addMenu("&View")
        for aid in ("view.quad", "view.maximize"):
            v.addAction(self.actions[aid])
        v.addSeparator()
        sides = v.addMenu("Sides")
        for aid in ("view.front", "view.back", "view.right", "view.left", "view.top",
                    "view.bottom", "view.toggle_ortho", "view.opposite"):
            sides.addAction(self.actions[aid])
        orbit = v.addMenu("Orbit and zoom")
        for aid in ("view.orbit_up", "view.orbit_down", "view.orbit_left", "view.orbit_right",
                    "view.zoom_in", "view.zoom_out"):
            orbit.addAction(self.actions[aid])
        v.addAction(self.actions["view.frame_all"])
        v.addAction(self.actions["view.frame_selected"])
        v.addSeparator()
        shading = v.addMenu("Shading")
        self.shading_group = QActionGroup(self)
        for name in SHADINGS:
            a = shading.addAction(name.title())
            a.setCheckable(True)
            a.setChecked(self.settings["view.shading"] == name)
            a.triggered.connect(lambda _=False, n=name: self.settings.set("view.shading", n))
            self.shading_group.addAction(a)
        shading.addAction(self.actions["view.shading_cycle"])
        for aid in ("view.edges", "view.grid", "view.markers"):
            v.addAction(self.actions[aid])
        v.addSeparator()
        fps = v.addAction("Frame time")
        fps.setCheckable(True)
        fps.setChecked(self.settings["view.show_fps"])
        fps.toggled.connect(lambda on: self.settings.set("view.show_fps", on))
        ws = v.addMenu("Workspace")
        for aid in [a for a in self.actions if a.startswith("view.workspace_")]:
            ws.addAction(self.actions[aid])
        ws.addSeparator()
        ws.addAction(self.actions["view.reset_layout"])
        self.panels_menu = v.addMenu("Panels")
        g = mb.addMenu("Gi&zmo")
        for aid in ("gizmo.none", "gizmo.move", "gizmo.rotate"):
            g.addAction(self.actions[aid])
        g.addSeparator()
        for aid in ("snap.toggle", "snap.finer", "snap.coarser"):
            g.addAction(self.actions[aid])
        h = mb.addMenu("&Help")
        h.addAction(self.actions["app.shortcuts"])
        h.addAction("About %s" % APP_NAME).triggered.connect(self.about)
    def _build_toolbar(self):
        tb = self.addToolBar("View")
        tb.setObjectName("toolbar_view")
        tb.setMovable(False)
        tb.setFloatable(False)
        tb.addAction(self.actions["file.open"])
        tb.addSeparator()
        for aid in ("gizmo.none", "gizmo.move", "gizmo.rotate"):
            tb.addAction(self.actions[aid])
        tb.addSeparator()
        tb.addAction(self.actions["snap.toggle"])
        self.step_box = QComboBox()
        for inc in snap_mod.INCREMENTS:
            self.step_box.addItem(grid_words(inc), inc)
        self.step_box.setCurrentIndex(self.step_box.findData(int(self.settings["grid.step"])))
        self.step_box.setToolTip("Grid step: how far a move or a new piece snaps ([ finer, "
                                 "] coarser)")
        self.step_box.currentIndexChanged.connect(
            lambda i: self.settings.set("grid.step", self.step_box.itemData(i)))
        tb.addWidget(self.step_box)
        tb.addSeparator()
        tb.addAction(self.actions["view.quad"])
        tb.addAction(self.actions["view.frame_all"])
        tb.addSeparator()
        for aid in ("view.edges", "view.grid", "view.markers"):
            tb.addAction(self.actions[aid])
        self.shading_box = QComboBox()
        for name in SHADINGS:
            self.shading_box.addItem(name.title(), name)
        self.shading_box.setCurrentIndex(SHADINGS.index(self.settings["view.shading"]))
        self.shading_box.setToolTip("Shading (Z cycles)")
        self.shading_box.currentIndexChanged.connect(
            lambda i: self.settings.set("view.shading", SHADINGS[i]))
        tb.addWidget(self.shading_box)
        self.hour_box = HourSlider(self.settings)
        tb.addWidget(self.hour_box)
        self.lightmap_button = QToolButton()
        self.lightmap_button.setText("Light map")
        self.lightmap_button.setObjectName("toggleText")
        self.lightmap_button.setCheckable(True)
        self.lightmap_button.setChecked(bool(self.settings["view.lightmap"]))
        self.lightmap_button.setToolTip("Baked shading: too dark is blue, too bright is red")
        self.lightmap_button.toggled.connect(
            lambda on: self._baked_then("view.lightmap", bool(on)))
        tb.addWidget(self.lightmap_button)
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        tb.addWidget(spacer)
        tb.addAction(self.actions["app.preferences"])
        self.toolbar = tb
        for btn in tb.findChildren(QToolButton):
            btn.setAutoRaise(True)
        from .headerfit import HeaderFit
        self.header_fit = HeaderFit(tb)
        self.header_fit.add_step("hour words", self.hour_box.compact, order=10)
    def _build_status(self):
        sb = self.statusBar()
        self.hint_label = HintLabel("")
        self.cursor_label = QLabel("")
        self.sel_label = QLabel("")
        self.count_label = QLabel("")
        self.fps_label = QLabel("")
        sb.addWidget(self.hint_label, 1)
        for w in (self.cursor_label, self.sel_label, self.count_label, self.fps_label):
            sb.addPermanentWidget(w)
        self._fps_timer = time.perf_counter()
    def active_view(self):
        return self.views.active.view
    def hint(self, text):
        self.hint_label.setText(text)
    def _cursor(self, info):
        if info.get("point") is None:
            self.cursor_label.setText("")
            return
        x, y, z = info["point"]
        cx, cy, cz = info["cell"]
        what = ""
        if info["kind"] == "piece":
            what = "  piece #%d" % info["index"]
        elif info["kind"] == "marker":
            what = "  %s" % self.ctx.scene.markers[info["index"]].kind
        self.cursor_label.setText("x %d  y %d  z %d   cell %d, %d, %d%s" % (x, y, z, cx, cy, cz, what))
    def _selection_label(self):
        sc = self.ctx.scene
        n, m = len(sc.selection), len(sc.marker_selection)
        parts = []
        if n:
            parts.append("%d piece%s" % (n, "" if n == 1 else "s"))
        if m:
            parts.append("%d marker%s" % (m, "" if m == 1 else "s"))
        self.sel_label.setText(("selected " + ", ".join(parts)) if parts else "")
    def _count_label(self):
        sc = self.ctx.scene
        budget = sc.meta.get("budget")
        self.count_label.setText("%d pieces%s" % (len(sc.pieces), " / %d" % budget if budget else ""))
    def _frame_time(self, ms):
        if not self.settings["view.show_fps"]:
            if self.fps_label.text():
                self.fps_label.setText("")
            return
        now = time.perf_counter()
        if now - self._fps_timer > 0.25:
            self._fps_timer = now
            self.fps_label.setText("frame %.1f ms" % ms)
    def _gizmo_mode_changed(self, mode):
        self.actions["gizmo." + mode].setChecked(True)
        if mode != "none" and not self.ctx.scene.selection:
            self.hint("The %s gizmo shows on a selection: click a piece." % mode)
    def _escape(self):
        if any(v.cancel_drag() for v in self.views.views()):
            return
        self.ctx.scene.set_selection(())
        self.ctx.scene.set_marker_selection(())
    def _toggle_quad(self, on):
        mode = "quad" if on else "single"
        if self.views.mode != mode:
            self.views.set_mode(mode)
        if self.settings["view.layout"] != mode:
            self.settings.set("view.layout", mode)
    def _cycle_shading(self):
        cur = SHADINGS.index(self.settings["view.shading"])
        self.settings.set("view.shading", SHADINGS[(cur + 1) % len(SHADINGS)])
    def _step(self, direction):
        snap = self.ctx.snap
        value = snap.coarser() if direction > 0 else snap.finer()
        self.settings.set("grid.step", int(value))
        self.hint("Grid step %d" % value)
    def _view_pie(self):
        from PySide6.QtGui import QCursor
        from PySide6.QtWidgets import QMenu
        m = QMenu(self)
        for aid in ("view.top", "view.front", "view.right", "view.bottom", "view.back", "view.left",
                    "view.toggle_ortho", "view.frame_all", "view.frame_selected"):
            m.addAction(self.actions[aid])
        m.exec(QCursor.pos())
    def _setting(self, key, value):
        if key == "view.shading":
            self.shading_box.blockSignals(True)
            self.shading_box.setCurrentIndex(SHADINGS.index(value))
            self.shading_box.blockSignals(False)
            for a in self.shading_group.actions():
                a.setChecked(a.text().lower() == value)
        elif key == "grid.step":
            self.step_box.blockSignals(True)
            self.step_box.setCurrentIndex(self.step_box.findData(int(value)))
            self.step_box.blockSignals(False)
        elif key == "view.filter":
            for v in self.views.views():
                if v.renderer is not None:
                    v.makeCurrent()
                    v.renderer.set_filter(value)
                    v.doneCurrent()
        elif key == "nav.fov":
            for v in self.views.views():
                v.camera.fov = float(value)
        elif key == "nav.emulate_numpad":
            self.apply_keys()
        elif key == "view.layout":
            if self.views.mode != value:
                self.views.set_mode(value)
            if self.actions["view.quad"].isChecked() != (value == "quad"):
                self.actions["view.quad"].blockSignals(True)
                self.actions["view.quad"].setChecked(value == "quad")
                self.actions["view.quad"].blockSignals(False)
        elif key in ("ui.accent", "ui.background", "ui.font", "ui.font_size", "ui.colour_vision",
                     "ui.scale"):
            from .app import apply_look
            apply_look(self.ctx, defer=True)
        mapping = {"view.edges": "view.edges", "view.grid": "view.grid",
                   "view.markers": "view.markers", "grid.snap": "snap.toggle"}
        if key in mapping:
            a = self.actions[mapping[key]]
            if a.isChecked() != value:
                a.blockSignals(True)
                a.setChecked(value)
                a.blockSignals(False)
        self.ctx.redraw()
    def open(self, source, frame=True):
        try:
            got = loader.load(source)
        except loader.LoadError as exc:
            QMessageBox.warning(self, "Cannot open", str(exc))
            return False
        sc = self.ctx.scene
        sc.set_pieces(got.pieces, meta=got.meta)
        sc.set_markers(got.markers)
        if not source.startswith("venue:"):
            self.settings.add_recent(source)
        self.current = source
        name = got.meta.get("name") or got.meta.get("key") or os.path.basename(source.rstrip("/"))
        self.setWindowTitle("%s - %s" % (name, APP_NAME))
        self._count_label()
        if frame:
            self.views.frame_all(animate=False)
        problems = got.meta.get("problems") or []
        self.hint("Opened %s: %d pieces, %d markers%s" % (
            name, len(got.pieces), len(got.markers),
            ("; %d skipped (see the Scene panel)" % len(problems)) if problems else ""))
        return True
    def reload(self):
        if getattr(self, "current", None):
            cams = [v.camera.copy() for v in self.views.views()]
            if self.open(self.current, frame=False):
                for v, c in zip(self.views.views(), cams):
                    v.camera = c
                    v.update()
    def open_dialog(self):
        path, _ = QFileDialog.getOpenFileName(self, "Open a map", self._start_dir(),
                                              "Layouts (*.json);;All files (*)")
        if path:
            self.open(path)
    def open_folder_dialog(self):
        path = QFileDialog.getExistingDirectory(self, "Open a mapgen --out folder", self._start_dir())
        if path:
            self.open(path)
    def _start_dir(self):
        if self.settings.recent:
            return os.path.dirname(self.settings.recent[0])
        return os.getcwd()
    def _fill_recent(self):
        self.recent_menu.clear()
        for path in self.settings.recent:
            self.recent_menu.addAction(path).triggered.connect(lambda _=False, p=path: self.open(p))
        if not self.settings.recent:
            self.recent_menu.addAction("Nothing yet").setEnabled(False)
    def screenshot_dialog(self):
        path, _ = QFileDialog.getSaveFileName(self, "Save the view as a picture",
                                              os.path.join(self._start_dir(), "view.png"),
                                              "PNG (*.png)")
        if path:
            self.active_view().grabFramebuffer().save(path)
            self.hint("Saved %s" % path)
    def preferences(self):
        Preferences(self.settings, self, on_keys=self.apply_keys).exec()
        self.settings.save()
    def mouse_rows(self):
        s = self.settings
        rows = [("Navigation", "Orbit", "Middle drag" + (", Alt + left drag"
                                                         if s["nav.emulate_3button"] else "")),
                ("Navigation", "Pan", "Shift + middle drag"),
                ("Navigation", "Zoom", "Wheel, Ctrl + middle drag"),
                ("Navigation", "Dolly", "Ctrl + Shift + middle drag")]
        how = s["nav.right_drag"]
        if how == "fly":
            rows.append(("Navigation", "Fly", "Hold right + W A S D, Q/E down/up, Shift faster, "
                         "wheel = speed"))
        elif how == "pan":
            rows.append(("Navigation", "Pan", "Right drag"))
        if s["nav.trackpad_pans"]:
            rows.append(("Navigation", "Pan (trackpad)", "Two fingers; Ctrl + two fingers zooms"))
        rows += [("Navigation", "Frame a piece", "Double-click it"),
                 ("Navigation", "Snap to a side", "Click an axis ball (top right)"),
                 ("Select", "Pick / add / remove", "Click / Shift+click / Ctrl+click"),
                 ("Select", "Box select", "Left drag on empty space"),
                 ("Select", "Menu of the verbs", "Right click (no drag)"),
                 ("Place", "The pen: in the hand", "Click a palette item, then click, click"),
                 ("Place", "A row", "Drag with an item in the hand"),
                 ("Place", "The last one", "Shift + click"),
                 ("Place", "Take a piece's texture", "Middle click (no drag)"),
                 ("Gizmo", "Snap off while dragging", "hold Ctrl"),
                 ("Gizmo", "Cancel a drag", "Escape")]
        return rows
    def shortcut_rows(self):
        rows = sorted(keymap.ACTIONS.items(), key=lambda kv: (kv[1][2], kv[1][1]))
        return self.mouse_rows() + [(group, label, ", ".join(self.settings.keys.keys(action)))
                                    for action, (_, label, group) in rows]
    def shortcuts(self):
        from PySide6.QtWidgets import QHBoxLayout, QLineEdit, QPushButton
        d = QDialog(self)
        d.setWindowTitle("Shortcuts")
        from .reflow import fit_to_screen
        fit_to_screen(d, 820, 680)
        lay = QVBoxLayout(d)
        search = QLineEdit()
        search.setPlaceholderText("Find: an action or a key (paste, Ctrl+V, fly...)")
        search.setClearButtonEnabled(True)
        lay.addWidget(search)
        rows = self.shortcut_rows()
        table = QTableWidget(len(rows), 3)
        table.setHorizontalHeaderLabels(["Group", "Action", "Keys"])
        table.verticalHeader().setVisible(False)
        table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        table.setEditTriggers(QTableWidget.NoEditTriggers)
        table.setWordWrap(True)
        last = None
        for r, row in enumerate(rows):
            for c, v in enumerate(row):
                shown = "" if c == 0 and v == last else v
                it = QTableWidgetItem(shown)
                if c == 0 and shown:
                    f = it.font()
                    f.setBold(True)
                    it.setFont(f)
                table.setItem(r, c, it)
            last = row[0]
        table.resizeColumnsToContents()
        table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        table.resizeRowsToContents()
        def find(text):
            words = text.lower().split()
            for r, row in enumerate(rows):
                hay = " ".join(row).lower()
                table.setRowHidden(r, bool(words) and not all(w in hay for w in words))
        search.textChanged.connect(find)
        lay.addWidget(table)
        buttons = QHBoxLayout()
        save = QPushButton("Save as PDF...")
        save.setToolTip("The cheat sheet on paper: every key, two columns")
        save.clicked.connect(lambda: self.save_cheat_sheet(rows, d))
        buttons.addStretch(1)
        buttons.addWidget(save)
        lay.addLayout(buttons)
        d._find, d._table, d._search = find, table, search
        self._shortcuts_dialog = d
        d.show()
        return d
    def cheat_sheet_html(self, rows=None):
        rows = rows or self.shortcut_rows()
        out = ["<h2>Oldfart Studio - shortcuts</h2><table cellspacing=0 cellpadding=2>"]
        group = None
        for g, a, k in rows:
            if g != group:
                out.append("<tr><td colspan=2><b>%s</b></td></tr>" % g)
                group = g
            out.append("<tr><td>%s</td><td><tt>%s</tt></td></tr>" % (a, k or "-"))
        out.append("</table>")
        return "".join(out)
    def save_cheat_sheet(self, rows=None, parent=None, path=None):
        if path is None:
            path, _ = QFileDialog.getSaveFileName(parent or self, "Save the cheat sheet",
                                                  os.path.join(self._start_dir(),
                                                               "studio-shortcuts.pdf"),
                                                  "PDF (*.pdf)")
        if not path:
            return None
        from PySide6.QtGui import QPageSize, QPdfWriter, QTextDocument
        writer = QPdfWriter(path)
        writer.setPageSize(QPageSize(QPageSize.A4))
        doc = QTextDocument()
        doc.setHtml(self.cheat_sheet_html(rows))
        doc.print_(writer)
        self.hint("Saved %s" % path)
        return path
    def about(self):
        QMessageBox.about(self, "About %s" % APP_NAME,
                          "%s %s - the map builder of Oldfart's Mod Menu: a wish in, a "
                          "checked map out, edited in 3D and played in Coop DX.\n\nRenderer: %s"
                          % (APP_NAME, VERSION, self._gl_info()))
    def _gl_info(self):
        v = self.active_view()
        if v.renderer is not None and v.renderer.ready:
            return "%(version)s on %(renderer)s" % v.renderer.gl_info
        return v.gl_error or "not started"
    def _restore(self):
        st = self.settings.state
        try:
            if st.get("geometry"):
                self.restoreGeometry(QByteArray.fromBase64(st["geometry"].encode()))
            if st.get("views"):
                self.views.restore(st["views"])
            if st.get("docks"):
                QTimer.singleShot(0, self, self._restore_docks)
        except (TypeError, ValueError, AttributeError):
            pass
    def _restore_docks(self):
        st = self.settings.state if isinstance(self.settings.state, dict) else {}
        kept = st.get("docks")
        if not isinstance(kept, str) or not kept:
            return False
        try:
            return bool(self.restoreState(QByteArray.fromBase64(kept.encode())))
        except (TypeError, ValueError):
            return False
    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        from .docks import ui_scale
        narrow = ev.size().width() < 1400 * ui_scale(self)
        for w in self.statusBar().findChildren(QWidget):
            fn = getattr(w, "set_compact", None)
            if callable(fn) and getattr(w, "compact", None) != narrow:
                fn(narrow)
    def showEvent(self, ev):
        super().showEvent(ev)
        ws = getattr(self, "workspaces", None)
        if ws is not None and getattr(ws, "sizes_pending", False):
            QTimer.singleShot(0, self, ws.settle)
            QTimer.singleShot(120, self, ws.apply_sizes)
    def closeEvent(self, ev):
        state = dict(self.settings.state or {})
        state.update({
            "geometry": bytes(self.saveGeometry().toBase64()).decode(),
            "docks": bytes(self.saveState().toBase64()).decode(),
            "views": self.views.state(),
        })
        self.settings.state = state
        try:
            self.settings.save()
        except OSError as exc:
            print("studio: settings not saved: %s" % exc)
        super().closeEvent(ev)
        if ev.isAccepted() and not getattr(self, "keep_running", False):
            from PySide6.QtWidgets import QApplication
            app = QApplication.instance()
            if app is not None:
                QTimer.singleShot(0, app.quit)
