MOVER_SHAPES = (("slab", "a slab"), ("plate", "a thin plate"), ("cube", "a cube"),
                ("slope", "a slope"), ("stairs", "stairs"), ("pillar", "a pillar"),
                ("wall", "a wall"), ("arch", "an arch"), ("prism", "a prism"),
                ("pole", "a pole"))
def install(studio):
    from PySide6.QtCore import QTimer
    from PySide6.QtWidgets import (QCheckBox, QComboBox, QHBoxLayout, QLabel, QListWidget,
                                   QPushButton, QSpinBox, QVBoxLayout, QWidget)
    from mapgen import movers as M
    from studio.toolbox import paths
    from studio.toolbox.qt import paint
    from studio.core import gizmo as gizmo_math
    ed = studio.editor
    ctx = studio.ctx
    tool = paths.PathTool(ed.session)
    state = {"drawing": False, "playing": False, "t": 0.0}
    def push(change, msg=None):
        if change:
            ed.push(change)
        panel.refresh()
        ctx.redraw()
        if msg:
            ed.hint(msg)
    def guarded(fn):
        def run(*a):
            try:
                return fn(*a)
            except paths.PathError as why:
                ed.hint(str(why))
        return run
    class PathsPanel(QWidget):
        def __init__(self):
            super().__init__()
            lay = QVBoxLayout(self)
            lay.setContentsMargins(10, 10, 10, 10)
            row = QHBoxLayout()
            for label, kind, tip in (("Platform", "platform", "a slab on a path"),
                                     ("Log", "log", "a rolling log, Lethal Lava Land's"),
                                     ("Wide log", "logwide", "the long rolling log")):
                b = QPushButton(label)
                b.setToolTip("Place %s at the cursor" % tip)
                b.clicked.connect(lambda _=False, k=kind: place(k))
                row.addWidget(b)
            lay.addLayout(row)
            srow = QHBoxLayout()
            self.shape = QComboBox()
            for key, label in MOVER_SHAPES:
                self.shape.addItem(label, key)
            self.shape.setToolTip("The shape a new platform is: the mod moves any block shape "
                                  "its texture comes in (a texture without the shape falls "
                                  "back to stone)")
            srow.addWidget(QLabel("Platform shape"))
            srow.addWidget(self.shape, 1)
            lay.addLayout(srow)
            self.movers = QListWidget()
            self.movers.setToolTip("The map's movers; choose one to edit its path")
            self.movers.currentRowChanged.connect(self.chosen)
            lay.addWidget(self.movers, 1)
            self.draw = QCheckBox("Draw: a click adds a point")
            self.draw.setToolTip("While on, a left click in any view adds a point after the "
                                 "chosen one (the grid snap applies)")
            self.draw.toggled.connect(lambda on: state.update(drawing=on))
            lay.addWidget(self.draw)
            self.points = QListWidget()
            self.points.setToolTip("The path's points; the chosen one wears the gizmo (G)")
            self.points.currentRowChanged.connect(self.point_chosen)
            lay.addWidget(self.points, 1)
            prow = QHBoxLayout()
            self.speed = QSpinBox()
            self.speed.setRange(M.LIMITS["min_speed"], M.LIMITS["max_speed"])
            self.speed.setSingleStep(30)
            self.speed.setSuffix(" /s")
            self.speed.setToolTip("Speed of the leg leaving this point (Mario runs 960)")
            self.speed.editingFinished.connect(guarded(
                lambda: push(tool.set_point(speed=self.speed.value()))))
            self.wait = QSpinBox()
            self.wait.setRange(0, M.LIMITS["max_wait"])
            self.wait.setSuffix(" tenths")
            self.wait.setToolTip("How long it stands at this point")
            self.wait.editingFinished.connect(guarded(
                lambda: push(tool.set_point(wait=self.wait.value()))))
            prow.addWidget(QLabel("Speed"))
            prow.addWidget(self.speed)
            prow.addWidget(QLabel("Wait"))
            prow.addWidget(self.wait)
            lay.addLayout(prow)
            mrow = QHBoxLayout()
            self.mode = QComboBox()
            for word in M.MODES:
                self.mode.addItem({"loop": "Loop", "pingpong": "There and back",
                                   "oneway": "Up, then straight home"}[word], word)
            self.mode.activated.connect(guarded(
                lambda _i: push(tool.set(mode=self.mode.currentData()))))
            self.ridden = QCheckBox("Only when ridden")
            self.ridden.setToolTip("Rests at its first point until somebody stands on it; goes "
                                   "round while ridden and finishes its path when left")
            self.ridden.clicked.connect(guarded(
                lambda on: push(tool.set(trigger="ridden" if on else "always"))))
            self.phase = QSpinBox()
            self.phase.setRange(0, 30000)
            self.phase.setSuffix(" frames")
            self.phase.setToolTip("How far ahead it runs (a gauntlet out of step)")
            self.phase.editingFinished.connect(guarded(
                lambda: push(tool.set(phase=self.phase.value()))))
            mrow.addWidget(self.mode)
            mrow.addWidget(self.ridden)
            lay.addLayout(mrow)
            lay.addWidget(self.phase)
            brow = QHBoxLayout()
            for label, fn, tip in (
                    ("Point here", guarded(lambda: push(tool.add_point(cursor()))),
                     "Add a point at the cursor"),
                    ("Move here", guarded(lambda: push(tool.move_point(tool.point, cursor()))),
                     "Move the chosen point to the cursor"),
                    ("Delete", guarded(lambda: push(tool.delete_point())),
                     "Delete the chosen point")):
                b = QPushButton(label)
                b.setToolTip(tip)
                b.clicked.connect(fn)
                brow.addWidget(b)
            lay.addLayout(brow)
            self.play = QPushButton("Play")
            self.play.setCheckable(True)
            self.play.setToolTip("Run every mover on its path in the views, as the mod does")
            self.play.toggled.connect(play)
            lay.addWidget(self.play)
            self._filling = False
        def refresh(self):
            self._filling = True
            try:
                doc = ed.session.doc
                refs = doc.refs("mover")
                self.movers.clear()
                for ref in refs:
                    m = doc.get(ref)
                    self.movers.addItem("%s  %s, %d points" % (m["key"], m["mode"],
                                                                len(m["points"])))
                if tool.ref in refs:
                    self.movers.setCurrentRow(refs.index(tool.ref))
                m = tool.mover()
                self.points.clear()
                for i, p in enumerate(paths.world_points(m) if m else []):
                    self.points.addItem("%d  (%d, %d, %d)" % (i + 1, p[0], p[1], p[2]))
                if m:
                    self.points.setCurrentRow(tool.point)
                    pt = m["points"][tool.point]
                    self.speed.setValue(pt[3])
                    self.wait.setValue(pt[4])
                    self.mode.setCurrentIndex(list(M.MODES).index(m["mode"]))
                    self.ridden.setChecked(m["trigger"] == "ridden")
                    self.phase.setValue(m.get("phase", 0))
            finally:
                self._filling = False
        def chosen(self, row):
            if self._filling:
                return
            refs = ed.session.doc.refs("mover")
            if 0 <= row < len(refs):
                tool.begin(refs[row])
                self.refresh()
                ctx.redraw()
        def point_chosen(self, row):
            if self._filling or tool.mover() is None or row < 0:
                return
            tool.point = row
            self.refresh()
            ctx.redraw()
    def cursor():
        p = ed.session.cursor
        if p is None:
            raise paths.PathError("aim at the map first")
        return tuple(p)
    def place(kind):
        try:
            tex = getattr(ed.session, "texture", None) or "stone1"
            at = cursor()
            shape = panel.shape.currentData() if kind == "platform" else None
            try:
                change = tool.place(at, kind, tex, shape=shape)
            except paths.PathError:
                change = tool.place(at, kind, "stone1", shape=shape)
            push(change, "A mover is in hand - draw its path (a click adds a point)")
        except paths.PathError as why:
            ed.hint(str(why))
    timer = QTimer(studio.window)
    timer.setInterval(33)
    def tick():
        state["t"] += 1.0 / 30.0
        ctx.redraw()
    timer.timeout.connect(tick)
    def play(on):
        state["playing"] = on
        state["t"] = 0.0
        (timer.start if on else timer.stop)()
        ctx.redraw()
    previous_pick = ctx.pick_handler
    def pick(hit, mods, view):
        if state["drawing"] and tool.mover() is not None and hit is not None \
                and hit.point is not None:
            p = ctx.snap.point(hit.point) if ctx.snap.enabled else hit.point
            guarded(lambda: push(tool.add_point(tuple(p))))()
            return True
        return previous_pick(hit, mods, view)
    ctx.pick_handler = pick
    own_gizmo = ctx.gizmo
    previous_gizmo_handler = ctx.gizmo_handler
    def gizmo():
        if tool.mover() is not None and not ctx.scene.selection and ctx.gizmo_mode == "move":
            return gizmo_math.Gizmo("move", tool.gizmo_pivot(), ctx.settings["gizmo.size"])
        return own_gizmo()
    ctx.gizmo = gizmo
    def gizmo_handler(delta, ids):
        if tool.mover() is not None and not ids:
            guarded(lambda: push(tool.nudge_point(tool.point, tuple(delta.offset))))()
            return True
        return previous_gizmo_handler(delta, ids) if previous_gizmo_handler else False
    ctx.gizmo_handler = gizmo_handler
    def painter(view, p, w, h):
        layer = tool.layer(ed.session.doc, t=state["t"] if state["playing"] else None)
        if len(layer):
            paint.paint_layer(p, view, layer, w, h)
    ctx.painters.append(painter)
    panel = PathsPanel()
    studio.docks.add("right", "paths", "Paths", panel)
    ed.changed.connect(panel.refresh)
    panel.refresh()
    studio.paths = tool
    return tool
