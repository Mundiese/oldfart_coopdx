import time
from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (QButtonGroup, QCheckBox, QComboBox, QFrame, QGridLayout,
                               QHBoxLayout, QLabel, QLineEdit, QListWidget, QListWidgetItem,
                               QProgressBar, QPushButton, QScrollArea, QSizePolicy, QSlider,
                               QSpinBox, QToolButton, QTreeWidget, QTreeWidgetItem, QVBoxLayout,
                               QWidget)
from studio.toolbox import brushes, dress, issues as issmod, meters, overlays, snapshots
from studio.toolbox.symmetry import LABELS as SYM_LABELS, MODES as SYM_MODES, facing_note
TOOL_BUTTONS = (("select", "Select", "tools.select"), ("paint", "Paint", "tools.brush_paint"),
                ("raise", "Raise", "tools.brush_raise"), ("lower", "Lower", "tools.brush_lower"),
                ("scatter", "Scatter", "tools.brush_scatter"), ("fill", "Fill", "tools.brush_fill"),
                ("ruler", "Ruler", "tools.ruler"), ("path", "Path", "tools.path"),
                ("room", "Room", "tools.room"))
def _keys(aid):
    from studio.core import keymap
    keys = keymap.ACTIONS.get(aid, ([],))[0]
    return ("  (%s)" % ", ".join(keys)) if keys else ""
def header(text, tip=None):
    lab = QLabel(text)
    lab.setObjectName("dim")
    f = lab.font()
    f.setBold(True)
    lab.setFont(f)
    if tip:
        lab.setToolTip(tip)
    return lab
def caption(text):
    lab = QLabel(text)
    lab.setObjectName("caption")
    lab.setWordWrap(True)
    return lab
def scrolled(inner):
    area = QScrollArea()
    area.setWidgetResizable(True)
    area.setFrameShape(QFrame.NoFrame)
    area.setWidget(inner)
    return area
class ToolsPanel(QWidget):
    def __init__(self, tools):
        super().__init__()
        self.tools = tools
        st = tools.state
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        inner = QWidget()
        lay = QVBoxLayout(inner)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(6)
        outer.addWidget(scrolled(inner))
        lay.addWidget(header("Tool", "What a left click or drag in a view does"))
        from studio.ui.reflow import ReflowGrid
        grid = ReflowGrid(max_cols=4, min_cols=2)
        self.group = QButtonGroup(self)
        self.group.setExclusive(True)
        self.buttons = {}
        from studio.toolbox.controller import ACTIONS
        for n, (mode, label, aid) in enumerate(TOOL_BUTTONS):
            b = QToolButton()
            b.setText(label)
            b.setCheckable(True)
            b.setToolButtonStyle(Qt.ToolButtonTextOnly)
            b.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            b.setToolTip(ACTIONS[aid][3] + _keys(aid))
            b.clicked.connect(lambda _=False, m=mode: tools.set_mode(m))
            self.group.addButton(b)
            grid.add(b)
            self.buttons[mode] = b
        self.buttons["select"].setChecked(True)
        lay.addWidget(grid)
        lay.addWidget(header("Brush", "Size and falloff of every brush; the rim of a soft "
                                      "brush acts less"))
        form = QGridLayout()
        self.size = QSlider(Qt.Horizontal)
        self.size.setRange(1, brushes.SIZE_MAX)
        self.size.setValue(st.brush.size)
        self.size.setToolTip("The brush's radius in cells (200 units)  (Alt+[ / Alt+])")
        self.size_label = QLabel()
        self.falloff = QSlider(Qt.Horizontal)
        self.falloff.setRange(0, 100)
        self.falloff.setValue(int(100 * st.brush.falloff))
        self.falloff.setToolTip("0: a hard edge; 100: fades from the middle to the rim")
        self.falloff_label = QLabel()
        self.strength = QSpinBox()
        self.strength.setRange(1, 20)
        self.strength.setValue(st.brush.strength)
        self.strength.setSuffix(" x 50")
        self.strength.setToolTip("Raise / lower: steps of 50 a dab at the brush's middle")
        self.spacing = QSpinBox()
        self.spacing.setRange(1, 12)
        self.spacing.setValue(st.brush.spacing)
        self.spacing.setSuffix(" cells")
        self.spacing.setToolTip("Scatter: the least distance between two things (Poisson disk)")
        self.height = QSpinBox()
        self.height.setRange(50, 2000)
        self.height.setSingleStep(50)
        self.height.setValue(st.brush.height)
        self.height.setToolTip("Fill: how thick a filled floor is (its top at the cursor)")
        self.whole = QCheckBox("Paint whole pieces")
        self.whole.setChecked(st.brush.whole_pieces)
        self.whole.setToolTip("On: a piece the brush touches is painted whole. Off: only the "
                              "cells under the brush (the piece is split into columns)")
        self.scatter_what = QComboBox()
        self.scatter_what.setToolTip("Scatter: the shape or prefab spread under the brush")
        rows = (("Size", self.size, self.size_label), ("Falloff", self.falloff, self.falloff_label),
                ("Strength", self.strength, None), ("Spacing", self.spacing, None),
                ("Fill height", self.height, None))
        for r, (name, w, extra) in enumerate(rows):
            lab = QLabel(name)
            lab.setToolTip(w.toolTip())
            form.addWidget(lab, r, 0)
            form.addWidget(w, r, 1)
            if extra is not None:
                form.addWidget(extra, r, 2)
        lay.addLayout(form)
        lay.addWidget(self.whole)
        row = QHBoxLayout()
        row.addWidget(QLabel("Scatter"))
        row.addWidget(self.scatter_what, 1)
        lay.addLayout(row)
        for w in (self.size, self.falloff):
            w.valueChanged.connect(self._brush_changed)
        for w in (self.strength, self.spacing, self.height):
            w.valueChanged.connect(self._brush_changed)
        self.whole.toggled.connect(self._brush_changed)
        self.scatter_what.currentIndexChanged.connect(self._scatter_changed)
        lay.addWidget(header("Symmetry", "Every edit repeats on the twins as you make it"))
        row = QHBoxLayout()
        self.sym = QComboBox()
        for m in SYM_MODES:
            self.sym.addItem(SYM_LABELS[m], m)
            if facing_note(m):
                self.sym.setItemData(self.sym.count() - 1, facing_note(m), Qt.ToolTipRole)
        self.sym.setToolTip("Mirror x / z / both, or radial 2-8 about the centre" +
                            _keys("tools.symmetry"))
        self.sym.currentIndexChanged.connect(
            lambda _: tools.state.set_symmetry(self.sym.currentData()))
        centre = QPushButton("Centre here")
        centre.setToolTip("The symmetry's centre on the selection's middle (nothing selected: "
                          "the map's middle)")
        centre.clicked.connect(lambda: tools.run("tools.symmetry_centre"))
        row.addWidget(self.sym, 1)
        row.addWidget(centre)
        lay.addLayout(row)
        self.sym_note = caption("")
        lay.addWidget(self.sym_note)
        self._build_section(lay, tools)
        lay.addWidget(header("Auto-dress", "The finishing touches the generator gives its own "
                                           "maps: rails, pillars, battlements, colours"))
        self.rules = {}
        rgrid = QGridLayout()
        for n, rule in enumerate(dress.RULES):
            c = QCheckBox(dress.LABELS[rule])
            c.setChecked(rule in st.dress_rules)
            c.setToolTip({"palette": "Pieces outside the theme's palette take their role's "
                                     "texture; floor and wall stand apart (0.18)",
                          "trims": "Rails along floor edges over a drop of 400+, a gap every "
                                   "few cells",
                          "pillars": "A pillar every few cells along walls over 1000 long",
                          "crenels": "Battlements on long walls (castle, lava, desert)",
                          "legs": "Columns under anything floating less than 800 over the "
                                  "floor",
                          "light": "The theme's light direction in the venue's look (one "
                                   "that gives tops, fronts and sides three values)",
                          "values": "The main wall steps within its material family when it "
                                    "reads too close to the floors (the family's minimum)",
                          "tops": "Grass, snow or sand on the top block under the sky "
                                  "(garden, ice, desert); none under a block"}.get(rule, "")
                         + ("\n(rule %s)" % dress.RULE_IDS[rule] if rule in dress.RULE_IDS
                            else ""))
            c.toggled.connect(self._rules_changed)
            self.rules[rule] = c
            rgrid.addWidget(c, n, 0)
        lay.addLayout(rgrid)
        b = QPushButton("Dress")
        b.setToolTip("Dress the selection, or the whole map with nothing selected" +
                     _keys("tools.dress"))
        b.clicked.connect(lambda: tools.run("tools.dress"))
        lay.addWidget(b)
        lay.addWidget(header("Region", "Box-select an area, then build only it again"))
        row = QVBoxLayout()
        b = QPushButton("Regenerate the area")
        b.setToolTip("The area the selection spans built again from the wish; the rest stays; "
                     "the seam must pass the safety gate" + _keys("tools.region"))
        b.clicked.connect(lambda: tools.run("tools.region"))
        f = QPushButton("Fill the area")
        f.setToolTip("A floor in every empty cell of the area the selection spans, its top at "
                     "the selection's top")
        f.clicked.connect(lambda: tools.run("tools.fill_region"))
        from studio.toolbox.controller import ACTIONS as TOOL_ACTIONS
        s = QPushButton("Auto-shape the steps")
        s.setToolTip(TOOL_ACTIONS["tools.autoshape"][3] + _keys("tools.autoshape"))
        s.clicked.connect(lambda: tools.run("tools.autoshape"))
        row.addWidget(b)
        row.addWidget(f)
        row.addWidget(s)
        lay.addLayout(row)
        lay.addWidget(header("Measure", "The ruler (D) and the walk path (J), in Mario seconds"))
        self.readout = caption("Ruler: D, then click points in a view. Walk path: J, then "
                               "two points.")
        lay.addWidget(self.readout)
        lay.addStretch(1)
        self._brush_changed()
        self.fill_scatter()
    def _build_section(self, lay, tools):
        from studio.toolbox import build
        st = tools.state
        ses = tools.ed.session
        lay.addWidget(header("Build", "Grow boxes, change shapes, paint gradients and patches, "
                                      "rooms - each one undo step, mirrored with symmetry"))
        from studio.ui.reflow import ReflowGrid
        grid = ReflowGrid(max_cols=3, min_cols=2)
        for n, (aid, text) in enumerate((("tools.push_face", "Push out"),
                                         ("tools.pull_face", "Pull in"),
                                         ("tools.variant_next", "Next shape"),
                                         ("tools.gradient", "Gradient"),
                                         ("tools.noise", "Noise"),
                                         ("tools.second_texture", "Take as 2nd"))):
            b = QPushButton(text)
            from studio.toolbox.controller import ACTIONS
            b.setToolTip(ACTIONS[aid][3] + _keys(aid))
            b.clicked.connect(lambda _=False, a=aid: tools.run(a))
            grid.add(b)
        lay.addWidget(grid)
        self.second = caption("")
        lay.addWidget(self.second)
        form = QGridLayout()
        self.grad_axis = QComboBox()
        for key, text in (("y", "by height"), ("x", "along x"), ("z", "along z")):
            self.grad_axis.addItem(text, key)
        self.grad_axis.setToolTip("Which way the gradient runs: the current texture at the "
                                  "low end, the second at the high end")
        self.grad_axis.currentIndexChanged.connect(
            lambda _: setattr(st, "gradient_axis", self.grad_axis.currentData()))
        self.noise_share = QSpinBox()
        self.noise_share.setRange(5, 95)
        self.noise_share.setSuffix(" %")
        self.noise_share.setValue(int(round(100 * st.noise_share)))
        self.noise_share.setToolTip("Noise: how much of the area the second texture covers")
        self.noise_share.valueChanged.connect(
            lambda v: setattr(st, "noise_share", v / 100.0))
        self.noise_patch = QSpinBox()
        self.noise_patch.setRange(200, 4000)
        self.noise_patch.setSingleStep(200)
        self.noise_patch.setSuffix(" units")
        self.noise_patch.setValue(st.noise_patch)
        self.noise_patch.setToolTip("Noise: how big the patches are")
        self.noise_patch.valueChanged.connect(lambda v: setattr(st, "noise_patch", v))
        self.room_h = QSpinBox()
        self.room_h.setRange(200, 2000)
        self.room_h.setSingleStep(50)
        self.room_h.setValue(st.room_height)
        self.room_h.setToolTip("Room: how high its walls are (a door is 400 high; over that "
                               "a lintel)")
        self.room_h.valueChanged.connect(lambda v: setattr(st, "room_height", v))
        for r, (name, w) in enumerate((("Gradient", self.grad_axis),
                                       ("Noise share", self.noise_share),
                                       ("Noise patches", self.noise_patch),
                                       ("Room walls", self.room_h))):
            lab = QLabel(name)
            lab.setToolTip(w.toolTip())
            form.addWidget(lab, r, 0)
            form.addWidget(w, r, 1)
        lay.addLayout(form)
        from studio.ui.reflow import ReflowGrid
        row = ReflowGrid(max_cols=4, min_cols=2, spacing=4)
        self.doors = {}
        for face, text in (("-z", "N door"), ("+z", "S door"), ("-x", "W door"),
                           ("+x", "E door")):
            c = QCheckBox(text)
            c.setChecked(face in st.room_doors)
            c.setToolTip("Room: a door gap in the middle of this wall")
            c.toggled.connect(self._doors_changed)
            self.doors[face] = c
            row.add(c)
        lay.addWidget(row)
        self.roof = QCheckBox("Room roof")
        self.roof.setToolTip("Room: a roof slab over it (in the current texture)")
        self.roof.toggled.connect(lambda on: setattr(st, "room_roof", on))
        lay.addWidget(self.roof)
        lay.addWidget(header("Laying prefabs", "How a prefab from the palette goes down"))
        self.merge = QCheckBox("Merge cubes into boxes")
        self.merge.setChecked(ses.prefab_opts.get("merge", True))
        self.merge.setToolTip("A Forge build's cubes of one texture become a few big boxes "
                              "(fewer pieces, tiled textures) - mapgen's own cell merge")
        self.merge.toggled.connect(lambda on: ses.prefab_opts.__setitem__("merge", on))
        lay.addWidget(self.merge)
        row = QHBoxLayout()
        self.mirror = QComboBox()
        for key, text in ((None, "not mirrored"), ("x", "mirrored left-right"),
                          ("z", "mirrored front-back")):
            self.mirror.addItem(text, key)
        self.mirror.setToolTip("Lay the prefab mirror-image (ramps climb the other way, "
                               "corners stay corners)")
        self.mirror.currentIndexChanged.connect(
            lambda _: ses.prefab_opts.__setitem__("mirror", self.mirror.currentData()))
        self.ruin = QSpinBox()
        self.ruin.setRange(0, 90)
        self.ruin.setSingleStep(10)
        self.ruin.setSuffix(" % ruined")
        self.ruin.setToolTip("Lay it as a ruin: this share of the pieces off its ground "
                             "layer crumbles away, the high ones first, nothing left floating; "
                             "each drop a new seed")
        self.ruin.valueChanged.connect(
            lambda v: ses.prefab_opts.__setitem__("ruin", v / 100.0))
        row.addWidget(self.mirror, 1)
        row.addWidget(self.ruin)
        lay.addLayout(row)
        lay.addWidget(header("Reach and notes", "Mario's reach on the ghost before placing; "
                                                "notes in the map"))
        legend = caption("  ".join('<span style="color:%s">&#9632;</span> %s' % (
            QColor.fromRgbF(*c[:3]).name(), w) for _, w, c in build.REACH_CLASSES))
        legend.setTextFormat(Qt.RichText)
        legend.setToolTip("The outline on a dragged piece or a paste: what getting onto its "
                          "top takes from the floor beside it (tools/mapgen/movement.py)" +
                          _keys("tools.reach_ghost"))
        lay.addWidget(legend)
        b = QPushButton("Note here...")
        b.setToolTip("A note at the mouse - saved with the map, never exported" +
                     _keys("tools.note"))
        b.clicked.connect(lambda: tools.run("tools.note"))
        lay.addWidget(b)
    def _doors_changed(self, *_):
        self.tools.state.room_doors = tuple(f for f, c in self.doors.items() if c.isChecked())
    def fill_scatter(self):
        pal = self.tools.ed.palette
        self.scatter_what.blockSignals(True)
        self.scatter_what.clear()
        for e in pal.section("shapes") + pal.section("prefabs"):
            self.scatter_what.addItem("%s (%s)" % (e.label, e.section[:-1]), e.id)
        self.scatter_what.blockSignals(False)
        i = self.scatter_what.findText("Pillar", Qt.MatchStartsWith)
        self.scatter_what.setCurrentIndex(max(0, i))
        self._scatter_changed()
    def _scatter_changed(self, *_):
        eid = self.scatter_what.currentData()
        if not eid:
            return
        try:
            e = self.tools.ed.palette.get(eid)
        except KeyError:
            return
        self.tools.state.scatter_make = (e.label, e.make)
    def _brush_changed(self, *_):
        b = self.tools.state.brush
        b.size = self.size.value()
        b.falloff = self.falloff.value() / 100.0
        b.strength = self.strength.value()
        b.spacing = self.spacing.value()
        b.height = self.height.value()
        b.whole_pieces = self.whole.isChecked()
        self.size_label.setText("%d" % b.size)
        self.falloff_label.setText("%d%%" % self.falloff.value())
        self.tools.ctx.redraw()
    def _rules_changed(self, *_):
        self.tools.state.dress_rules = [r for r, c in self.rules.items() if c.isChecked()]
    def show_mode(self, mode):
        b = self.buttons.get(mode)
        if b is not None and not b.isChecked():
            b.setChecked(True)
    def show_state(self):
        st = self.tools.state
        self.size.blockSignals(True)
        self.size.setValue(st.brush.size)
        self.size.blockSignals(False)
        self.size_label.setText("%d" % st.brush.size)
        i = self.sym.findData(st.symmetry.mode)
        if i >= 0 and i != self.sym.currentIndex():
            self.sym.blockSignals(True)
            self.sym.setCurrentIndex(i)
            self.sym.blockSignals(False)
        note = facing_note(st.symmetry.mode)
        self.sym_note.setText("" if not st.symmetry else "about (%d, %d), %d sectors%s" % (
            st.symmetry.centre[0], st.symmetry.centre[1], st.symmetry.order,
            (" - " + note) if note else ""))
        if st.result is not None:
            self.readout.setText("\n".join(st.result.lines()))
        ses = self.tools.ed.session
        def named(slug):
            try:
                return self.tools.ed.palette.get("textures:" + slug).label
            except (KeyError, AttributeError):
                return slug
        self.second.setText("Texture: %s, second texture: %s (Alt+I takes it)" % (
            named(ses.texture), named(ses.texture2)))
class OverlaysPanel(QWidget):
    def __init__(self, tools):
        super().__init__()
        self.tools = tools
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(6)
        lay.addWidget(caption("Layers drawn over the views from what tools/mapgen measures; "
                              "the legend is in each view's corner."))
        from studio.toolbox.controller import ACTIONS, OVERLAY_ACTIONS
        self.checks = {}
        self.notes = {}
        for aid, key in OVERLAY_ACTIONS.items():
            c = QCheckBox(ACTIONS[aid][1].replace("Overlay: ", "").capitalize())
            c.setToolTip(ACTIONS[aid][3] + _keys(aid))
            c.toggled.connect(lambda on, k=key: tools.toggle_layer(k, on))
            note = caption("")
            lay.addWidget(c)
            lay.addWidget(note)
            self.checks[key] = c
            self.notes[key] = note
        row = QHBoxLayout()
        b = QPushButton("Measure again")
        b.setToolTip("Compute the shown layers again for the map as it is now - the bot "
                     "heatmap and deaths only measure again here; the others by themselves "
                     "a moment after an edit")
        b.clicked.connect(tools.refresh_layers)
        off = QPushButton("All off")
        off.setToolTip("Hide every overlay" + _keys("tools.overlay_clear"))
        off.clicked.connect(lambda: tools.run("tools.overlay_clear"))
        row.addWidget(b)
        row.addWidget(off)
        lay.addLayout(row)
        self.busy = QProgressBar()
        self.busy.setRange(0, 0)
        self.busy.setVisible(False)
        self.busy.setToolTip("Measuring on a worker thread")
        lay.addWidget(self.busy)
        lay.addStretch(1)
    def show_layer(self, key, layer):
        c = self.checks.get(key)
        if c is not None:
            c.blockSignals(True)
            c.setChecked(layer is not None)
            c.blockSignals(False)
        if key in self.notes:
            self.notes[key].setText(layer.note if layer is not None else "")
    def mark_stale(self, key):
        from studio.toolbox.overlays import STALE_NOTE
        if key in self.notes and self.checks[key].isChecked():
            self.notes[key].setText(STALE_NOTE)
LEVEL_TOKEN = {"fail": "bad", "warn": "warn"}
LEVEL_GLYPH = {"fail": "✕", "warn": "!"}
LEVEL_TIP = {"fail": "The export waits for this one", "warn": "Worth a look"}
class IssuesPanel(QWidget):
    def __init__(self, tools):
        super().__init__()
        self.tools = tools
        self._items = []
        self._pending = None
        self.result = None
        self.critic = None
        self.buttons = []
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(6)
        self.summary = QLabel("Not measured yet")
        self.summary.setWordWrap(True)
        self.summary.setToolTip("The safety gate's faults first (they stop an export), then "
                                "the metrics outside their bands, the critic's notes and the "
                                "beauty notes")
        lay.addWidget(self.summary)
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["", "Issue", ""])
        self.tree.setHeaderHidden(True)
        self.tree.setRootIsDecorated(False)
        self.tree.setColumnWidth(0, 26)
        self.tree.setWordWrap(True)
        self.tree.setTextElideMode(Qt.ElideNone)
        self.tree.setUniformRowHeights(False)
        hv = self.tree.header()
        from PySide6.QtWidgets import QHeaderView
        hv.setStretchLastSection(False)
        hv.setSectionResizeMode(0, QHeaderView.Fixed)
        hv.setSectionResizeMode(1, QHeaderView.Stretch)
        hv.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        hv.sectionResized.connect(lambda i, *_: i == 1 and self._fit_rows())
        self.tree.setToolTip("Each row's button fixes it (one undo step) or shows you where it "
                             "is. Double-click: show me")
        self.tree.currentItemChanged.connect(lambda *_: self._chosen())
        self.tree.itemActivated.connect(lambda *_: self.show_me())
        lay.addWidget(self.tree, 1)
        row = QHBoxLayout()
        self.show_btn = QPushButton("Show me")
        self.show_btn.setToolTip("Frame the camera on it and select what it names  (F7 next, "
                                 "Shift+F7 previous)")
        self.show_btn.clicked.connect(self.show_me)
        row.addWidget(self.show_btn)
        m = QPushButton("Measure")
        m.setToolTip("Measure the map now (F4)")
        m.clicked.connect(lambda: tools.ed.measure(full=False))
        full = QPushButton("Full")
        full.setToolTip("Sightlines, spawn exposure and the bot run too (a few seconds)")
        full.clicked.connect(lambda: tools.ed.measure(full=True))
        row.addWidget(m)
        row.addWidget(full)
        lay.addLayout(row)
        lay.addWidget(header("Fixes", "One click; one undo step; the card measures again"))
        self.fix_row = QVBoxLayout()
        lay.addLayout(self.fix_row)
        self.fix_note = caption("Choose an issue to see what can fix it.")
        lay.addWidget(self.fix_note)
        meter = getattr(tools.ed, "critic", None)
        if meter is not None and hasattr(meter, "judged"):
            meter.judged.connect(self.show_critic)
    def show_critic(self, res):
        self.critic = res
        self.show(self.result)
    @property
    def items(self):
        if self._pending is not None:
            result = self._pending[0]
            self._fill(result, self._collected(result))
        return self._items
    @items.setter
    def items(self, value):
        self._items = value
    def _stamp(self, result):
        doc = self.tools.ed.session.doc
        return (id(doc), doc.revision, id(result))
    def _collected(self, result):
        stamp = self._stamp(result)
        base = getattr(self, "_base", None)
        if base is not None and base[0] == stamp:
            return base[1]
        rows = issmod.collect(self.tools.ed.session.doc, result) if result else []
        self._base = (stamp, rows)
        return rows
    def showEvent(self, ev):
        super().showEvent(ev)
        if self._pending is not None:
            self._start()
    def show(self, result):
        self.result = result
        self._pending = (result,)
        base = getattr(self, "_base", None)
        if base is not None and base[0] == self._stamp(result) or not result:
            self._fill(result, base[1] if result else [])
        elif self.isVisible():
            self._start()
    def _start(self):
        if self._pending is None:
            return
        jobs = getattr(self, "_jobs", None)
        if jobs is None:
            from studio.editor.qt.worker import Jobs
            jobs = self._jobs = Jobs(self)
        if jobs.busy():
            self._again = True
            return
        self._again = False
        result = self._pending[0]
        stamp = self._stamp(result)
        doc_json = self.tools.ed.session.doc.to_json()
        self.summary.setText("Looking for issues...")
        def job(_progress, _cancelled):
            from studio.editor import childcall
            return childcall.call("studio.toolbox.issues:collect_from_json", doc_json, result)
        def done(rows):
            try:
                if stamp == self._stamp(result) and self._pending is not None \
                        and self._pending[0] is result:
                    self._base = (stamp, rows)
                    self._fill(result, rows)
                if self._again or self._pending is not None:
                    self._again = False
                    if self.isVisible():
                        self._start()
            except RuntimeError:
                pass
        def failed(reason):
            try:
                self.summary.setText("The issues could not be collected: %s" % reason)
            except RuntimeError:
                pass
        jobs.run("Issues", job, done, failed)
    def _apply(self, result):
        self._fill(result, self._collected(result))
    def _fill(self, result, base):
        self._pending = None
        doc = self.tools.ed.session.doc
        was = self.current()
        was = was.text if was is not None else None
        self._items = list(base)
        try:
            self._items += issmod.critic_issues(doc, self.critic)
        except Exception:
            pass
        self.tree.blockSignals(True)
        self.tree.clear()
        self.buttons = []
        t = self.tools.ed.tokens
        for n, iss in enumerate(self.items):
            it = QTreeWidgetItem([LEVEL_GLYPH.get(iss.level, "·"), iss.text, ""])
            it.setForeground(0, QColor(t.get(LEVEL_TOKEN.get(iss.level, "text"), "#ddd")))
            it.setTextAlignment(0, Qt.AlignHCenter | Qt.AlignTop)
            f = it.font(0)
            f.setBold(True)
            it.setFont(0, f)
            it.setToolTip(0, LEVEL_TIP.get(iss.level, ""))
            it.setToolTip(1, iss.text + ("\nFixes: %s" % ", ".join(
                self._label(iss, f) for f in iss.fixes) if iss.fixes else ""))
            it.setData(0, Qt.UserRole, n)
            self.tree.addTopLevelItem(it)
            self.tree.setItemWidget(it, 2, self._row_button(iss))
            if iss.text == was:
                self.tree.setCurrentItem(it)
        self.tree.blockSignals(False)
        self._fit_rows()
        gate = sum(1 for i in self.items if i.source == "gate")
        bands = sum(1 for i in self.items if i.source == "metric")
        notes = sum(1 for i in self.items if i.source not in ("gate", "metric"))
        if result is None and not self.items:
            self.summary.setText("Not measured yet")
        elif not self.items:
            self.summary.setText("No issues - the gate passes and every band is met")
        else:
            if gate:
                self.summary.setText("%d stop the export, %d bands missed, %d notes"
                                     % (gate, bands, notes))
            else:
                self.summary.setText("The export is ready - %d bands missed, %d notes"
                                     % (bands, notes))
        self._chosen()
    def _fit_rows(self):
        from PySide6.QtCore import QRect, QSize
        col = self.tree.columnWidth(1)
        if col <= 20:
            return
        fm = self.tree.fontMetrics()
        for i in range(self.tree.topLevelItemCount()):
            it = self.tree.topLevelItem(i)
            r = fm.boundingRect(QRect(0, 0, col - 12, 100000), int(Qt.TextWordWrap),
                                it.text(1))
            b = self.tree.itemWidget(it, 2)
            h = max(r.height() + 12, (b.sizeHint().height() + 4) if b is not None else 0)
            if it.sizeHint(1).height() != h:
                it.setSizeHint(1, QSize(col, h))
    def _label(self, iss, key):
        if key == "refine":
            return "Ask the engine: \"%s\"" % iss.data.get("refine")
        return issmod.FIX_LABELS.get(key, key)
    def _row_button(self, iss):
        key, words = issmod.button_for(iss)
        b = QToolButton()
        b.setText(words)
        b.setObjectName("issueFix" if key else "issueShow")
        b.setCursor(Qt.PointingHandCursor)
        if key is None:
            b.setToolTip("No one-click fix: this frames it and selects what it names - then "
                         "change it by hand")
            b.clicked.connect(lambda _=False, i=iss: self._show(i))
        else:
            b.setToolTip("%s - one undo step" % self._label(iss, key))
            b.clicked.connect(lambda _=False, i=iss, k=key: self.tools.fix(i, k))
            if len(iss.fixes) > 1:
                from PySide6.QtWidgets import QMenu
                menu = QMenu(b)
                for k in iss.fixes:
                    menu.addAction(self._label(iss, k)).triggered.connect(
                        lambda _=False, i=iss, k=k: self.tools.fix(i, k))
                menu.addSeparator()
                menu.addAction("Show me").triggered.connect(lambda _=False, i=iss: self._show(i))
                b.setMenu(menu)
                b.setPopupMode(QToolButton.MenuButtonPopup)
        self.buttons.append((iss, key, b))
        return b
    def _show(self, iss):
        for i in range(self.tree.topLevelItemCount()):
            it = self.tree.topLevelItem(i)
            n = it.data(0, Qt.UserRole)
            if n is not None and n < len(self.items) and self.items[n] is iss:
                self.tree.setCurrentItem(it)
        self.tools.show_issue(iss)
    def current(self):
        it = self.tree.currentItem()
        if it is None:
            return None
        n = it.data(0, Qt.UserRole)
        return self.items[n] if n is not None and n < len(self.items) else None
    def step(self, d):
        self.items
        n = self.tree.topLevelItemCount()
        if not n:
            return
        it = self.tree.currentItem()
        i = self.tree.indexOfTopLevelItem(it) if it is not None else -1
        self.tree.setCurrentItem(self.tree.topLevelItem((i + d) % n))
        self.show_me()
    def _chosen(self):
        while self.fix_row.count():
            w = self.fix_row.takeAt(0).widget()
            if w is not None:
                w.deleteLater()
        iss = self.current()
        self.show_btn.setEnabled(iss is not None)
        if iss is None:
            self.fix_note.setText("Choose an issue to see what can fix it.")
            return
        if not iss.fixes:
            self.fix_note.setText("No one-click fix: show me, then change it by hand.")
            return
        self.fix_note.setText("")
        for key in iss.fixes:
            label = self._label(iss, key)
            b = QPushButton(label)
            b.setToolTip({"refine": "Refine with these words (only what they ask changes; "
                                    "hand edits are replaced - Undo brings them back)",
                          "dress": "Run the auto-dress on the whole map",
                          "critic": "The critic's own mend, the report card's Fix it - one "
                                    "undo step",
                          "resolve_all": "Every overlap painted the way the generator does "
                                         "(solids.resolve)"}.get(key, label))
            b.clicked.connect(lambda _=False, k=key, i=iss: self.tools.fix(i, k))
            self.fix_row.addWidget(b)
    def show_me(self):
        iss = self.current()
        if iss is not None:
            self.tools.show_issue(iss)
class SnapshotsPanel(QWidget):
    def __init__(self, tools):
        super().__init__()
        self.tools = tools
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(6)
        row = QHBoxLayout()
        self.name = QLineEdit()
        self.name.setPlaceholderText("Name this version (e.g. before the bridge)")
        self.name.setToolTip("The snapshot's name; empty: Version N")
        self.name.returnPressed.connect(self.take)
        take = QPushButton("Take snapshot")
        take.setToolTip("Keep this version inside the map file" + _keys("tools.snapshot"))
        take.clicked.connect(self.take)
        row.addWidget(self.name, 1)
        row.addWidget(take)
        lay.addLayout(row)
        self.list = QListWidget()
        self.list.setToolTip("The timeline, oldest first. Double-click: compare with now")
        self.list.itemActivated.connect(lambda *_: self.compare())
        lay.addWidget(self.list, 1)
        row = QHBoxLayout()
        for label, tip, fn in (
                ("Compare", "Show what changed since it: added green, changed amber, moved "
                            "and removed as ghosts" + _keys("tools.compare"), self.compare),
                ("Restore", "Put the map back as it was then (one undo step)", self.restore),
                ("Rename", "Give the chosen snapshot the name in the box", self.rename),
                ("Remove", "Take the chosen snapshot out of the timeline", self.remove),
                ("Clear", "Hide the compare colours", self.clear)):
            b = QPushButton(label)
            b.setToolTip(tip)
            b.clicked.connect(fn)
            row.addWidget(b)
        lay.addLayout(row)
        self.summary = caption("")
        lay.addWidget(self.summary)
    def refresh(self):
        doc = self.tools.ed.session.doc
        self.list.clear()
        now = time.time()
        for e in snapshots.entries(doc):
            QListWidgetItem(snapshots.label(e, now), self.list)
        if self.list.count():
            self.list.setCurrentRow(self.list.count() - 1)
    def index(self):
        r = self.list.currentRow()
        return r if r >= 0 else None
    def take(self):
        self.tools.hint(self.tools.state.snapshot(self.name.text().strip() or None))
        self.name.clear()
        self.refresh()
    def compare(self):
        i = self.index()
        if i is None:
            self.tools.hint("Take a snapshot first, then compare with it")
            return
        self.summary.setText(self.tools.state.compare(i))
    def restore(self):
        i = self.index()
        if i is not None:
            self.tools.state.clear_compare()
            self.tools.hint(self.tools.state.restore(i))
            self.tools.ed.after_change()
            self.refresh()
    def rename(self):
        i = self.index()
        name = self.name.text().strip()
        if i is not None and name:
            snapshots.rename(self.tools.ed.session.doc, i, name)
            self.name.clear()
            self.refresh()
    def remove(self):
        i = self.index()
        if i is not None:
            snapshots.remove(self.tools.ed.session.doc, i)
            self.tools.state.clear_compare()
            self.refresh()
    def clear(self):
        self.tools.state.clear_compare()
        self.summary.setText("")
class MetersBar(QWidget):
    def __init__(self, tools):
        super().__init__()
        self.tools = tools
        lay = QHBoxLayout(self)
        lay.setContentsMargins(4, 0, 4, 0)
        lay.setSpacing(8)
        self.bars = {}
        self.compact = False
        self._has = {}
        for key, label in (("pieces", "Pieces"), ("ceiling", "Game limit"),
                           ("download", "Download")):
            box = QWidget()
            bl = QHBoxLayout(box)
            bl.setContentsMargins(0, 0, 0, 0)
            bl.setSpacing(4)
            lab = QLabel(label)
            lab.setObjectName("dim")
            bar = QProgressBar()
            bar.setRange(0, 1000)
            bar.setTextVisible(False)
            bar.setFixedSize(54, 8)
            val = QLabel("-")
            bl.addWidget(lab)
            bl.addWidget(bar)
            bl.addWidget(val)
            lay.addWidget(box)
            self.bars[key] = (box, bar, val)
        self.setToolTip("The meters (tools/mapgen's numbers)")
    def show_report(self, rep):
        rows = {r.key: r for r in rep["rows"]}
        t = self.tools.ed.tokens
        tip = ["%s - %s" % (r.text(), r.tip) for r in rep["rows"]]
        tip.append("")
        tip.append("Numbers from %s" % rep["source"])
        for key, (box, bar, val) in self.bars.items():
            r = rows.get(key)
            self._has[key] = r is not None
            if r is None:
                box.setVisible(False)
                continue
            box.setVisible(not (self.compact and key != "pieces"))
            bar.setValue(int(1000 * min(1.0, r.share)))
            colour = t.get({"ok": "ok", "warn": "warn", "fail": "bad"}[r.level], "#888")
            bar.setStyleSheet("QProgressBar { background: %s; border: none; border-radius: 3px; }"
                              "QProgressBar::chunk { background: %s; border-radius: 3px; }"
                              % (t.get("raised", "#2a2e35"), colour))
            val.setText(("%s/%s%s" % (meters._n(r.value), meters._n(r.limit), r.unit))
                        if r.limit else meters._n(r.value) + r.unit)
            box.setToolTip("%s\n%s" % (r.text(), r.tip))
        self.setToolTip("\n".join(tip))
    def set_compact(self, on):
        self.compact = bool(on)
        for key, (box, _bar, _val) in self.bars.items():
            if key != "pieces":
                box.setVisible(self._has.get(key, False) and not self.compact)
__all__ = ["ToolsPanel", "OverlaysPanel", "IssuesPanel", "SnapshotsPanel", "MetersBar",
           "overlays"]
