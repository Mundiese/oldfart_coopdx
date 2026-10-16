import os
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtWidgets import (QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFileDialog,
                               QFormLayout, QFrame, QHBoxLayout, QLabel, QLineEdit, QListWidget,
                               QListWidgetItem, QMessageBox, QPlainTextEdit, QPushButton,
                               QScrollArea, QSpinBox, QStackedWidget, QVBoxLayout, QWidget)
from studio.ui.reflow import fit_to_screen
from .. import REPO, engine, geometry as geo, ops, selection as selmod
from mapgen import brief as briefmod
from . import widgets
EDGE_CHOICES = (("auto", "auto (both, invisible when the budget is tight)"),
                ("visible", "visible wall"), ("invisible", "invisible wall"),
                ("both", "both (low rim + invisible wall)"))
class HistoryPanel(QListWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self.setToolTip("Click a step to go back to it - nothing is lost until you change "
                        "something else (Ctrl+Z / Ctrl+Shift+Z)")
        self.itemClicked.connect(self._clicked)
        self.refresh()
    def refresh(self):
        self.blockSignals(True)
        self.clear()
        stack = self.ed.session.stack
        self.addItem(QListWidgetItem(getattr(self.ed.session, "origin", "Opened")))
        for label, done in stack.labels():
            item = QListWidgetItem(label)
            if not done:
                item.setForeground(Qt.gray)
            self.addItem(item)
        cur = len(stack.done)
        it = self.item(cur)
        if it is not None:
            f = QFont(it.font())
            f.setBold(True)
            it.setFont(f)
            self.setCurrentRow(cur)
        self.blockSignals(False)
    def _clicked(self, item):
        self.ed.session.stack.undo_to(self.row(item))
        self.ed.after_change("History")
class PropertiesPanel(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self._loading = False
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        self.title = QLabel("")
        self.title.setObjectName("title")
        lay.addWidget(self.title)
        self.pages = QStackedWidget()
        lay.addWidget(self.pages)
        self.map_page = self._map_page()
        self.piece_page = self._piece_page()
        self.point_page = self._point_page()
        self.anchor_page = self._anchor_page()
        self.star_page = self._star_page()
        self.object_page = self._object_page()
        for p in (self.map_page, self.piece_page, self.point_page, self.anchor_page,
                  self.star_page, self.object_page):
            self.pages.addWidget(p)
        self.pages.currentChanged.connect(self._page_sizes)
        self._page_sizes()
        lay.addWidget(widgets.Collapsible("Tool options", self._options(), open_=False))
        lay.addStretch(1)
        self.refresh()
    def _page_sizes(self, *_):
        from PySide6.QtWidgets import QSizePolicy
        cur = self.pages.currentWidget()
        for i in range(self.pages.count()):
            pg = self.pages.widget(i)
            pol = QSizePolicy.Preferred if pg is cur else QSizePolicy.Ignored
            pg.setSizePolicy(pol, pol)
        self.pages.updateGeometry()
    def _spin(self, lo, hi, step, cb, tip=""):
        s = QSpinBox()
        s.setRange(lo, hi)
        s.setSingleStep(step)
        s.setKeyboardTracking(False)
        s.valueChanged.connect(lambda *_: None if self._loading else cb())
        if hi - lo >= 10000:
            from PySide6.QtWidgets import QAbstractSpinBox
            s.setButtonSymbols(QAbstractSpinBox.NoButtons)
        if tip:
            s.setToolTip(tip)
        return s
    def _map_page(self):
        w = QWidget()
        f = QFormLayout(w)
        f.setRowWrapPolicy(QFormLayout.WrapLongRows)
        self.map_name = QLineEdit()
        self.map_name.setPlaceholderText("e.g. The Frost Keep")
        self.map_name.editingFinished.connect(self._set_name)
        f.addRow("Name", self.map_name)
        self.map_budget = self._spin(20, briefmod.BUDGET_MAX, 5, self._set_budget,
                                     "objects the venue may use (the engine's ceiling is 150)")
        f.addRow("Budget", self.map_budget)
        self.map_level = QComboBox()
        self.map_level.addItem("The Tiles (a floor)", "empty")
        self.map_level.addItem("The Void (a death edge)", "empty2")
        self.map_level.currentIndexChanged.connect(
            lambda *_: None if self._loading else self.ed.push(ops.set_rest(
                self.ed.session.doc, "level", self.map_level.currentData(), "Set the level")))
        f.addRow("Level", self.map_level)
        self.map_edge = QComboBox()
        for value, label in EDGE_CHOICES:
            self.map_edge.addItem(label, value)
        self.map_edge.setSizeAdjustPolicy(QComboBox.AdjustToMinimumContentsLengthWithIcon)
        self.map_edge.setMinimumContentsLength(16)
        self.map_edge.setToolTip("The wall round the map: drawn, invisible (collision only, "
                                 "nobody wall-kicks over it), or a low rim with an invisible "
                                 "wall over it. Auto picks both, invisible when the budget is tight.")
        self.map_edge.currentIndexChanged.connect(
            lambda *_: None if self._loading else self.ed.push(ops.set_boundary(
                self.ed.session.doc, self.map_edge.currentData())))
        f.addRow("Map edge", self.map_edge)
        self.map_coinstar = QCheckBox("100-coin star")
        self.map_coinstar.setToolTip("A star appears when a player holds 100 coins in this "
                                     "world, as in a main course. It needs 100 coins to reach "
                                     "and bonus stars in the world.")
        self.map_coinstar.toggled.connect(
            lambda on: None if self._loading else self.ed.push(ops.set_rest(
                self.ed.session.doc, "coinStar", True if on else None,
                "100-coin star on" if on else "100-coin star off")))
        f.addRow("", self.map_coinstar)
        from .skypicker import SkyPicker, rom_choice
        studio = getattr(self.ed, "studio", None)
        self.map_sky = SkyPicker(rom=rom_choice(getattr(studio, "settings", None)))
        self.map_sky.currentIndexChanged.connect(
            lambda *_: None if self._loading else self.ed.push(ops.set_sky(
                self.ed.session.doc, self.map_sky.value())))
        f.addRow("Sky", self.map_sky)
        self.sun_show = QCheckBox("Show the sun (drag it in the sky)")
        self.sun_show.setToolTip("A sun over the map: drag it and the light follows at once "
                                 "(the \"baked\" shading, View > Shading, shows it as the "
                                 "game will).")
        self.sun_show.toggled.connect(self._show_sun)
        f.addRow("Sun", self.sun_show)
        from studio.ui.reflow import ReflowGrid
        row = ReflowGrid(max_cols=5, min_cols=3, spacing=4)
        from mapgen import bake as bakemod
        self.sun_presets = {}
        for name in bakemod.PRESET_ORDER:
            b = QPushButton(name.capitalize())
            b.setToolTip("One click: a %s sun" % name if name != "night" else
                         "One click: a moonlit night")
            b.clicked.connect(lambda *_, n=name: self._sun_preset(n))
            row.add(b)
            self.sun_presets[name] = b
        self.sun_reset = QPushButton("As it was")
        self.sun_reset.setToolTip("Forget this sun: the map wears the light it had")
        self.sun_reset.clicked.connect(lambda *_: self._commit_sun(None))
        row.add(self.sun_reset)
        f.addRow("", row)
        more = QWidget()
        mf = QFormLayout(more)
        mf.setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        self.sun_az = self._spin(0, 359, 5, self._set_sun,
                                 "Degrees round from the north, clockwise: 90 east, 180 south, "
                                 "270 west")
        self.sun_az.setWrapping(True)
        self.sun_az.setSuffix(" round")
        self.sun_el = self._spin(5, 90, 5, self._set_sun, "Degrees over the horizon")
        self.sun_el.setSuffix(" up")
        row.addWidget(self.sun_az)
        row.addWidget(self.sun_el)
        mf.addRow("Where", row)
        row = QHBoxLayout()
        self.sun_strength = self._spin(0, 200, 5, self._set_sun, "How strong its light is")
        self.sun_strength.setSuffix(" %")
        self.sun_colour = QPushButton("Colour")
        self.sun_colour.setToolTip("The sun's colour")
        self.sun_colour.clicked.connect(self._pick_sun_colour)
        row.addWidget(self.sun_strength)
        row.addWidget(self.sun_colour)
        mf.addRow("Strength", row)
        self.sun_ambient = self._spin(0, 150, 5, self._set_sun,
                                      "The sky's light on the faces turned from the sun "
                                      "(100: the map's own)")
        self.sun_ambient.setSuffix(" %")
        mf.addRow("Sky light", self.sun_ambient)
        mf.addRow(widgets.caption("In game the sun lights what the venue bakes: its merged "
                                  "pieces (a map of more than 150 pieces), props and joined "
                                  "pillars. Single pieces, the level's floor and Forge blocks "
                                  "keep the game's own light, which turns with the camera."))
        self.sun_more = widgets.Collapsible("More", more, open_=False)
        f.addRow(self.sun_more)
        self.light_path = QPushButton("Light my path")
        self.light_path.setToolTip("Lamps along the map's streets, roads and paths, with a dark "
                                   "gap between their pools - one undo step")
        self.light_path.clicked.connect(
            lambda *_: self.ed.push(ops.light_my_path(self.ed.session.doc)))
        f.addRow("Lights", self.light_path)
        from .moodpanel import MoodSection
        self.mood_box = MoodSection(self.ed)
        f.addRow(widgets.header("Weather and mood", "What the air does while people play "
                                "here: one click for a whole mood"))
        f.addRow(self.mood_box)
        self.map_look = widgets.caption("")
        f.addRow("Look", self.map_look)
        self.map_stats = widgets.caption("")
        f.addRow(self.map_stats)
        return w
    def _piece_page(self):
        w = QWidget()
        f = QFormLayout(w)
        self.p_kind = QLabel("")
        f.addRow("Kind", self.p_kind)
        self.p_tex = QComboBox()
        for e in self.ed.palette.section("textures"):
            self.p_tex.addItem(QIcon(widgets.swatch_pixmap(e.key, 20)), e.label, e.key)
        self.p_tex.currentIndexChanged.connect(self._set_tex)
        f.addRow("Texture", self.p_tex)
        self.p_pos = [self._spin(-30000, 30000, 200, self._set_piece) for _ in range(3)]
        self.p_pos[1].setSingleStep(50)
        row = QHBoxLayout()
        for s in self.p_pos:
            row.addWidget(s)
        f.addRow("x / y / z", row)
        self.p_size = [self._spin(20, 6200, 200, self._set_piece) for _ in range(3)]
        self.p_size[1].setSingleStep(50)
        row = QHBoxLayout()
        for s in self.p_size:
            row.addWidget(s)
        f.addRow("w / h / d", row)
        self.p_yaw = QComboBox()
        for y in (0, 90, 180, 270):
            self.p_yaw.addItem("%d" % y, y)
        self.p_yaw.currentIndexChanged.connect(lambda *_: self._set_piece())
        f.addRow("Turn", self.p_yaw)
        row = QHBoxLayout()
        self.p_light = QComboBox()
        for key, label in ops.LIGHT_CHOICES:
            self.p_light.addItem(label, key)
        self.p_light.setToolTip("Makes this piece a light: it glows, lights what is round it "
                                "and (a fire, magic) flickers in the game. Lamps, torches, "
                                "crystals and campfires bring their light already.")
        self.p_light.currentIndexChanged.connect(lambda *_: self._set_light())
        self.p_bright = QComboBox()
        for key, label in ops.LIGHT_STOPS:
            self.p_bright.addItem(label, key)
        self.p_bright.setCurrentIndex(1)
        self.p_bright.setToolTip("How bright: dim, normal or bright")
        self.p_bright.currentIndexChanged.connect(lambda *_: self._set_light())
        row.addWidget(self.p_light)
        row.addWidget(self.p_bright)
        f.addRow("Light", row)
        self.p_light_more = QWidget()
        more = QHBoxLayout(self.p_light_more)
        more.setContentsMargins(0, 0, 0, 0)
        self.p_reach = self._spin(0, 4000, 100, self._set_light_detail,
                                  "How far its light reaches (0: its kind's own)")
        self.p_colour = QComboBox()
        for key, label in ops.LIGHT_COLOURS:
            self.p_colour.addItem(label, key)
        self.p_colour.setToolTip("The light's colour")
        self.p_colour.currentIndexChanged.connect(lambda *_: self._set_light_detail())
        more.addWidget(self.p_reach)
        more.addWidget(self.p_colour)
        self.p_light_more_label = QLabel("Reach / colour")
        f.addRow(self.p_light_more_label, self.p_light_more)
        self.p_note = widgets.caption("")
        f.addRow(self.p_note)
        return w
    def _point_page(self):
        w = QWidget()
        f = QFormLayout(w)
        self.s_pos = [self._spin(-30000, 30000, 200, self._set_point) for _ in range(3)]
        self.s_pos[1].setSingleStep(50)
        row = QHBoxLayout()
        for s in self.s_pos:
            row.addWidget(s)
        f.addRow("x / y / z", row)
        self.s_yaw = self._spin(0, 359, 45, self._set_point, "facing: 0 looks to -z (north)")
        self.s_yaw.setWrapping(True)
        f.addRow("Facing", self.s_yaw)
        f.addRow(widgets.caption("Spawns are dealt in this order, one side at a time. A spawn "
                                 "must stand on a piece with room above it (the gate checks)."))
        return w
    def _object_page(self):
        from .. import forgeobjects
        w = QWidget()
        f = QFormLayout(w)
        self.o_key = QComboBox()
        self.o_key.setEditable(True)
        self.o_key.setInsertPolicy(QComboBox.NoInsert)
        for fo in forgeobjects.roster():
            self.o_key.addItem("%s  (%s)" % (fo.name, fo.shelf), fo.key)
        for key, label in (("onoffswitch", "ON/OFF switch"), ("onoffred", "ON/OFF red block"),
                           ("onoffblue", "ON/OFF blue block")):
            self.o_key.addItem(label, key)
        if self.o_key.completer() is not None:
            self.o_key.completer().setFilterMode(Qt.MatchContains)
            self.o_key.completer().setCompletionMode(
                self.o_key.completer().CompletionMode.PopupCompletion)
        self.o_key.setToolTip("Which Forge object this is (type to search). One undo step.")
        self.o_key.activated.connect(lambda *_: self._set_object(key=True))
        f.addRow("Object", self.o_key)
        self.o_variant = QComboBox()
        self.o_variant.setToolTip("Its kind - what the Forge's wheel cycles (a seesaw's plank, "
                                  "a box's contents, a coin formation's shape)")
        self.o_variant.activated.connect(lambda *_: self._set_object(variant=True))
        f.addRow("Kind", self.o_variant)
        self.o_pos = [self._spin(-30000, 30000, 200, lambda: self._set_object(pos=True))
                      for _ in range(3)]
        self.o_pos[1].setSingleStep(50)
        row = QHBoxLayout()
        for s in self.o_pos:
            row.addWidget(s)
        f.addRow("x / y / z", row)
        self.o_yaw = self._spin(0, 359, 45, lambda: self._set_object(yaw=True),
                                "facing: 0 looks to -z (north)")
        self.o_yaw.setWrapping(True)
        f.addRow("Facing", self.o_yaw)
        self.o_air = QCheckBox("Floats where it is put")
        self.o_air.setToolTip("A platform or a pickup in the air on purpose (the export's "
                              "\"stands on nothing\" check leaves it)")
        self.o_air.toggled.connect(lambda *_: self._set_object(air=True))
        f.addRow("", self.o_air)
        self.o_modes = QLineEdit()
        self.o_modes.setPlaceholderText("free play only")
        self.o_modes.setToolTip("The game modes whose rounds use it, by key (shooter, ctf, "
                                "course...); empty = free play only (THE GAME MODE RULE)")
        self.o_modes.editingFinished.connect(lambda: self._set_object(modes=True))
        f.addRow("Used in", self.o_modes)
        self.o_pipe = QComboBox()
        self.o_pipe.setToolTip("Where the pipe leads: nowhere, a level, or another pipe in "
                               "this map (the two lead to each other)")
        self.o_pipe.activated.connect(lambda *_: self._set_pipe())
        f.addRow("Leads to", self.o_pipe)
        self.o_pipe_area = self._spin(1, 8, 1, lambda: self._set_pipe(), "the level's area")
        f.addRow("Area", self.o_pipe_area)
        self.o_note = widgets.caption("")
        f.addRow(self.o_note)
        return w
    def _object_refs(self):
        return [r for r in self.ed.session.refs() if r[0] == "object"]
    def _fill_object(self, refs):
        from .. import forgeobjects
        doc = self.ed.session.doc
        first = doc.get(refs[0])
        keys = sorted(set(doc.get(r).get("key") for r in refs))
        fo = forgeobjects.get(first.get("key"))
        name = fo.name if fo else first.get("key", "object")
        self.title.setText(name if len(refs) == 1 else "%d %s" % (
            len(refs), name if len(keys) == 1 else "objects"))
        i = self.o_key.findData(first.get("key"))
        if i < 0:
            self.o_key.addItem(first.get("key", "?"), first.get("key"))
            i = self.o_key.findData(first.get("key"))
        self.o_key.setCurrentIndex(i)
        self.o_key.setEnabled(len(keys) == 1)
        self.o_variant.clear()
        names = forgeobjects.variant_names(first.get("key")) if len(keys) == 1 else []
        for n, (_, label) in enumerate(names):
            self.o_variant.addItem(label, n + 1)
        self.o_variant.setEnabled(bool(names))
        if names:
            self.o_variant.setCurrentIndex(max(0, int(first.get("variant") or 1) - 1))
        one = len(refs) == 1
        for sp, k in zip(self.o_pos, ("x", "y", "z")):
            sp.setEnabled(one)
            sp.setValue(int(first.get(k, 0)))
        self.o_yaw.setValue(int(first.get("yaw", 0)) % 360)
        self.o_air.setChecked(bool(first.get("air")))
        self.o_modes.setText(", ".join(first.get("modes") or []))
        self._fill_pipe(refs, first)
        self.o_note.setText("" if one else "Kind, facing, floating and modes apply to all of "
                            "them; the place is per object (select one).")
        self.pages.setCurrentWidget(self.object_page)
    def _fill_pipe(self, refs, first):
        from .. import forgeobjects as fo
        pipe = first.get("key") == "warppipe" and len(refs) == 1
        self.o_pipe.setVisible(pipe)
        self.o_pipe_area.setVisible(pipe)
        lay = self.object_page.layout()
        for w in (self.o_pipe, self.o_pipe_area):
            label = lay.labelForField(w)
            if label is not None:
                label.setVisible(pipe)
        if not pipe:
            return
        doc = self.ed.session.doc
        dest = first.get("pipe") or {}
        self.o_pipe.clear()
        self.o_pipe.addItem("nowhere", ("none", 0))
        for tag, ref in sorted(fo.pipe_tags(doc).items()):
            if ref != refs[0]:
                o = doc.get(ref)
                self.o_pipe.addItem("the pipe at %d, %d, %d" % (o["x"], o["y"], o["z"]),
                                    ("pair", tag))
        for ref in doc.refs("object"):
            o = doc.get(ref)
            if ref != refs[0] and o.get("key") == "warppipe" and not (o.get("pipe") or {}).get(
                    "tag"):
                self.o_pipe.addItem("the pipe at %d, %d, %d" % (o["x"], o["y"], o["z"]),
                                    ("ref", ref))
        for level, name in fo.LEVELS:
            self.o_pipe.addItem(name, ("level", level))
        want = ("none", 0)
        if dest.get("kind") == fo.PIPE_PAIR:
            want = ("pair", dest.get("pair"))
        elif dest.get("kind") == fo.PIPE_LEVEL:
            want = ("level", dest.get("level"))
            if self.pipe_index(want) < 0:
                self.o_pipe.addItem("level %s" % dest.get("level"), want)
        self.o_pipe.setCurrentIndex(max(0, self.pipe_index(want)))
        self.o_pipe_area.setValue(int(dest.get("area") or 1))
        self.o_pipe_area.setEnabled(dest.get("kind") == fo.PIPE_LEVEL)
    def pipe_index(self, data):
        for n in range(self.o_pipe.count()):
            if tuple(self.o_pipe.itemData(n) or ()) == tuple(data):
                return n
        return -1
    def _set_pipe(self):
        from .. import forgeobjects as fo
        from ..commands import Change
        if self._loading:
            return
        refs = self._object_refs()
        if len(refs) != 1:
            return
        doc = self.ed.session.doc
        me = doc.get(refs[0])
        how, value = tuple(self.o_pipe.currentData() or ("none", 0))
        tag = (me.get("pipe") or {}).get("tag") or fo.free_tag(doc)
        steps = []
        if how == "level":
            mine = {"kind": fo.PIPE_LEVEL, "level": int(value),
                    "area": self.o_pipe_area.value(), "tag": tag, "pair": 0}
        elif how in ("pair", "ref"):
            if how == "ref":
                other_ref = value
                other_tag = tag + 1
                while other_tag in fo.pipe_tags(doc):
                    other_tag += 1
            else:
                other_ref, other_tag = fo.pipe_tags(doc)[value], value
            mine = {"kind": fo.PIPE_PAIR, "level": 0, "area": 1, "tag": tag,
                    "pair": other_tag}
            theirs = {"kind": fo.PIPE_PAIR, "level": 0, "area": 1, "tag": other_tag,
                      "pair": tag}
            steps += ops.set_fields(doc, [other_ref], pipe=theirs).steps
        else:
            mine = None
        steps += ops.set_fields(doc, refs, pipe=mine).steps
        self.ed.push(Change("Lead the pipe somewhere", steps, select=list(refs)))
    def _set_object(self, key=False, variant=False, pos=False, yaw=False, air=False,
                    modes=False):
        if self._loading:
            return
        refs = self._object_refs()
        if not refs:
            return
        doc = self.ed.session.doc
        fields, label = {}, "Set the object"
        if key:
            k = self.o_key.currentData()
            if not k:
                return
            fields, label = {"key": k, "variant": None}, "Make it a %s" % k
        elif variant:
            fields, label = {"variant": self.o_variant.currentData()}, "Set its kind"
        elif pos and len(refs) == 1:
            fields = {"x": self.o_pos[0].value(), "y": self.o_pos[1].value(),
                      "z": self.o_pos[2].value()}
            label = "Set the place"
        elif yaw:
            fields, label = {"yaw": self.o_yaw.value()}, "Set the facing"
        elif air:
            fields, label = {"air": True if self.o_air.isChecked() else None}, "Set floating"
        elif modes:
            ms = [m.strip().lower() for m in self.o_modes.text().replace(";", ",").split(",")
                  if m.strip()]
            fields, label = {"modes": ms or None}, "Set the modes"
        if not fields:
            return
        change = ops.set_fields(doc, refs, label=label, **fields)
        if change:
            self.ed.push(change)
    def _anchor_page(self):
        w = QWidget()
        f = QFormLayout(w)
        self.a_what = QComboBox()
        for what in briefmod.ANCHOR_WHATS:
            self.a_what.addItem(what.replace("_", " "), what)
        self.a_what.currentIndexChanged.connect(lambda *_: self._set_anchor())
        f.addRow("What", self.a_what)
        self.a_pos = [self._spin(-30000, 30000, 200, self._set_anchor) for _ in range(2)]
        row = QHBoxLayout()
        for s in self.a_pos:
            row.addWidget(s)
        f.addRow("x / z", row)
        self.a_hard = QCheckBox("Exactly here")
        self.a_hard.setToolTip("Exactly here; off: as near as the layout allows")
        self.a_hard.toggled.connect(lambda *_: self._set_anchor())
        f.addRow(self.a_hard)
        self.a_once = QCheckBox("Only one")
        self.a_once.setToolTip("Only one: not repeated by the symmetry")
        self.a_once.toggled.connect(lambda *_: self._set_anchor())
        f.addRow(self.a_once)
        f.addRow(widgets.caption("Anchors are part of the wish: the next Generate or Refine "
                                 "builds the map around them."))
        return w
    def _star_page(self):
        w = QWidget()
        f = QFormLayout(w)
        self.b_num = self._spin(1, ops.STAR_NUMBERS, 1, self._set_star_number,
                                "1 to 6, once each: a number another star has is swapped")
        f.addRow("Number", self.b_num)
        self.b_name = QLineEdit()
        self.b_name.setPlaceholderText("e.g. Atop the Windy Hill (English, shown as typed)")
        self.b_name.setMaxLength(40)
        self.b_name.editingFinished.connect(self._set_star_name)
        f.addRow("Name", self.b_name)
        self.b_pos = [self._spin(-30000, 30000, 200, self._set_star_pos) for _ in range(3)]
        self.b_pos[1].setSingleStep(50)
        row = QHBoxLayout()
        for sp in self.b_pos:
            row.addWidget(sp)
        f.addRow("x / y / z", row)
        self.b_kind = widgets.caption("")
        f.addRow(self.b_kind)
        f.addRow(widgets.caption("A star hangs 200 over its floor, like the game's own; the "
                                 "issue browser says when one is in a piece, too low, "
                                 "unreachable, or when numbers repeat."))
        return w
    def _set_star_number(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) == 1 and refs[0][0] == "star":
            self.ed.push(ops.set_star_number(self.ed.session.doc, refs[0], self.b_num.value()))
    def _set_star_name(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) == 1 and refs[0][0] == "star":
            self.ed.push(ops.set_star_name(self.ed.session.doc, refs[0], self.b_name.text()))
    def _set_star_pos(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) == 1 and refs[0][0] == "star":
            self.ed.push(ops.set_fields(self.ed.session.doc, refs, label="Move the star",
                                        x=self.b_pos[0].value(), y=self.b_pos[1].value(),
                                        z=self.b_pos[2].value()))
    def _options(self):
        w = QWidget()
        f = QFormLayout(w)
        s = self.ed.session
        self.o_count = QSpinBox()
        self.o_count.setRange(1, 20)
        self.o_count.setValue(s.stack_count)
        self.o_count.valueChanged.connect(lambda v: setattr(s, "stack_count", v))
        self.o_dir = QComboBox()
        for d in ops.DIRECTIONS:
            self.o_dir.addItem(d, d)
        self.o_dir.setCurrentIndex(self.o_dir.findData(s.stack_direction))
        self.o_dir.currentIndexChanged.connect(
            lambda *_: setattr(s, "stack_direction", self.o_dir.currentData()))
        self.o_gap = QSpinBox()
        self.o_gap.setRange(0, 20)
        self.o_gap.setSuffix(" cells")
        self.o_gap.valueChanged.connect(lambda v: setattr(s, "stack_gap", v))
        row = QHBoxLayout()
        row.addWidget(self.o_count)
        row.addWidget(self.o_dir)
        row.addWidget(self.o_gap)
        f.addRow("Stack (Ctrl+Shift+D)", row)
        row = QHBoxLayout()
        self.o_magic = {}
        for m in selmod.MATCHES:
            c = QCheckBox(m)
            c.setChecked(m in s.magic)
            c.toggled.connect(self._magic)
            self.o_magic[m] = c
            row.addWidget(c)
        f.addRow("Magic select matches", row)
        return w
    def _magic(self, *_):
        got = tuple(m for m, c in self.o_magic.items() if c.isChecked())
        self.ed.session.magic = got or ("texture",)
    def _sun_tool(self):
        return getattr(self.ed, "sun_tool", None)
    def _show_sun(self, on):
        tool = self._sun_tool()
        if tool is None:
            return
        tool.visible = bool(on)
        ctx = getattr(self.ed, "ctx", None)
        if ctx is not None:
            ctx.redraw()
    def _commit_sun(self, sun):
        doc = self.ed.session.doc
        self.ed.push(ops.set_sun(doc, sun))
    def _set_sun(self):
        tool = self._sun_tool()
        if tool is None:
            return
        sun = dict(tool.sun())
        sun["az"] = float(self.sun_az.value())
        sun["el"] = float(self.sun_el.value())
        sun["strength"] = self.sun_strength.value() / 100.0
        sun["ambient"] = self.sun_ambient.value() / 100.0
        self._commit_sun(sun)
    def _sun_preset(self, name):
        from mapgen import bake as bakemod
        self._commit_sun(dict(bakemod.PRESETS[name]))
        if not self.sun_show.isChecked():
            self.sun_show.setChecked(True)
    def _pick_sun_colour(self):
        from PySide6.QtGui import QColor
        from PySide6.QtWidgets import QColorDialog
        tool = self._sun_tool()
        if tool is None:
            return
        sun = dict(tool.sun())
        c = sun["colour"]
        got = QColorDialog.getColor(QColor.fromRgbF(c[0], c[1], c[2]), self, "The sun's colour")
        if got.isValid():
            sun["colour"] = [round(got.redF(), 3), round(got.greenF(), 3), round(got.blueF(), 3)]
            self._commit_sun(sun)
    def _fill_sun(self):
        tool = self._sun_tool()
        if tool is None:
            return
        sun = tool.sun()
        self.sun_show.setChecked(tool.visible)
        self.sun_az.setValue(int(round(sun["az"])) % 360)
        self.sun_el.setValue(int(round(sun["el"])))
        self.sun_strength.setValue(int(round(sun["strength"] * 100)))
        self.sun_ambient.setValue(int(round(sun.get("ambient", 1.0) * 100)))
        c = sun["colour"]
        self.sun_colour.setStyleSheet("background: rgb(%d, %d, %d)" % tuple(
            int(round(v * 255)) for v in c))
        self.sun_reset.setEnabled(tool.own())
    def refresh(self):
        s = self.ed.session
        doc = s.doc
        refs = s.refs()
        self._loading = True
        try:
            kinds = set(r[0] for r in refs)
            if not refs:
                self.title.setText(doc.rest.get("name") or "This map")
                self.map_name.setText(doc.rest.get("name") or "")
                self.map_budget.setValue(int(doc.rest.get("budget") or 120))
                self.map_level.setCurrentIndex(max(0, self.map_level.findData(
                    doc.rest.get("level"))))
                self.map_edge.setCurrentIndex(max(0, self.map_edge.findData(
                    doc.brief.get("boundary") or "auto")))
                self.map_coinstar.setChecked(doc.rest.get("coinStar") is True)
                look = doc.rest.get("look") or {}
                self.map_sky.set_value(doc.brief.get("sky") if doc.brief.get("sky") not in (
                    None, "auto") else "auto")
                self._fill_sun()
                self.mood_box.fill()
                self.map_look.setText("sky %s, music %s (wished: %s - the Music tab "
                                      "changes it)" % (look.get("sky", "-"),
                                                       look.get("music", "-"),
                                                       doc.brief.get("music") or "auto"))
                self.map_stats.setText(s.selection_line())
                self.pages.setCurrentWidget(self.map_page)
            elif kinds == {"piece"}:
                first = doc.get(refs[0])
                self.title.setText("%d piece%s" % (len(refs), "" if len(refs) == 1 else "s")
                                   if len(refs) > 1 else "%s piece" % first["kind"])
                self.p_kind.setText(", ".join(sorted(set(doc.get(r)["kind"] for r in refs))))
                i = self.p_tex.findData(first.get("tex"))
                self.p_tex.setCurrentIndex(max(0, i))
                one = len(refs) == 1
                for sp, k in zip(self.p_pos, ("x", "y", "z")):
                    sp.setEnabled(one)
                    sp.setValue(int(first.get(k, 0)))
                for sp, k in zip(self.p_size, ("w", "h", "d")):
                    sp.setEnabled(one)
                    sp.setValue(int(first.get(k, 200)))
                self.p_yaw.setEnabled(one)
                self.p_yaw.setCurrentIndex(max(0, self.p_yaw.findData(geo.yaw_of(first))))
                light = first.get("light") if isinstance(first.get("light"), dict) else {}
                self.p_light.setCurrentIndex(max(0, self.p_light.findData(light.get("preset") or "")))
                self.p_bright.setCurrentIndex(max(0, self.p_bright.findData(
                    light.get("bright") or "normal")))
                self.p_bright.setEnabled(bool(light))
                full = self.full_mode()
                self.p_light_more.setVisible(full)
                self.p_light_more_label.setVisible(full)
                self.p_light_more.setEnabled(bool(light))
                self.p_reach.setValue(int(light.get("radius") or 0))
                col = light.get("colour")
                key = ",".join(str(int(c)) for c in col) if isinstance(col, (list, tuple)) else ""
                at = self.p_colour.findData(key)
                if at < 0 and key:
                    self.p_colour.addItem(key, key)
                    at = self.p_colour.findData(key)
                self.p_colour.setCurrentIndex(max(0, at))
                self.p_note.setText("" if one else "The texture applies to all of them; place "
                                    "and size are per piece (select one).")
                self.pages.setCurrentWidget(self.piece_page)
            elif kinds == {"object"}:
                self._fill_object(refs)
            elif kinds <= {"spawn", "object", "spot"} and len(refs) == 1:
                p = doc.get(refs[0])
                self.title.setText(refs[0][0])
                if refs[0][0] == "spot":
                    name = p.get("_name") or "spot"
                    self.title.setText("World spawn - where everybody arrives"
                                       if name == "world" else "%s (a point the modes read)"
                                       % name)
                for sp, k in zip(self.s_pos, ("x", "y", "z")):
                    sp.setValue(int(p.get(k, 0)))
                self.s_yaw.setValue(int(p.get("yaw", 0)) % 360)
                self.pages.setCurrentWidget(self.point_page)
            elif kinds == {"star"} and len(refs) == 1:
                st = doc.get(refs[0])
                self.title.setText("Bonus star %s" % st.get("id", "?"))
                self.b_num.setValue(max(1, min(ops.STAR_NUMBERS, int(st.get("id") or 1))))
                self.b_name.setText(st.get("name") or "")
                for sp, k in zip(self.b_pos, ("x", "y", "z")):
                    sp.setValue(int(st.get(k, 0)))
                self.b_kind.setText("placed by hand" if st.get("kind") == "hand" else
                                    "generated: %s, grade %s" % (st.get("kind"), st.get("grade")))
                self.pages.setCurrentWidget(self.star_page)
            elif kinds == {"anchor"} and len(refs) == 1:
                a = doc.view_item(refs[0])
                self.title.setText("Anchor %s" % refs[0][1])
                self.a_what.setCurrentIndex(max(0, self.a_what.findData(a.get("what"))))
                x, z = geo.point_xz(a)
                self.a_pos[0].setValue(int(x))
                self.a_pos[1].setValue(int(z))
                self.a_hard.setChecked(bool(a.get("hard")))
                self.a_once.setChecked(bool(a.get("once")))
                self.pages.setCurrentWidget(self.anchor_page)
            else:
                self.title.setText("%d items" % len(refs))
                self.map_stats.setText(s.selection_line())
                self.pages.setCurrentWidget(self.map_page)
        finally:
            self._loading = False
    def _set_name(self):
        name = self.map_name.text().strip()
        doc = self.ed.session.doc
        if name and name != doc.rest.get("name"):
            self.ed.push(ops.set_rest(doc, "name", name, "Name the map"))
    def _set_budget(self):
        self.ed.push(ops.set_rest(self.ed.session.doc, "budget", self.map_budget.value(),
                                  "Set the budget"))
    def _set_tex(self, *_):
        if self._loading:
            return
        refs = [r for r in self.ed.session.refs() if r[0] == "piece"]
        if refs:
            self.ed.push(ops.retexture(self.ed.session.doc, refs, self.p_tex.currentData()))
    def full_mode(self):
        return True
    def _set_light_detail(self):
        if self._loading:
            return
        refs = [r for r in self.ed.session.refs() if r[0] == "piece"]
        if refs:
            self.ed.push(ops.set_light_detail(self.ed.session.doc, refs, self.p_reach.value(),
                                              self.p_colour.currentData()))
    def _set_light(self):
        if self._loading:
            return
        refs = [r for r in self.ed.session.refs() if r[0] == "piece"]
        if refs:
            self.ed.push(ops.set_light(self.ed.session.doc, refs, self.p_light.currentData(),
                                       self.p_bright.currentData()))
    def _set_piece(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) != 1 or refs[0][0] != "piece":
            return
        doc = self.ed.session.doc
        p = doc.get(refs[0])
        fields = {"w": self.p_size[0].value(), "h": self.p_size[1].value(),
                  "d": self.p_size[2].value(), "yaw": self.p_yaw.currentData()}
        change = ops.set_fields(doc, refs, label="Set size and turn", **fields)
        pos = (self.p_pos[0].value() - p["x"], self.p_pos[1].value() - p["y"],
               self.p_pos[2].value() - p["z"])
        if change:
            self.ed.push(change)
        elif any(pos):
            self.ed.push(ops.move(doc, refs, *pos, snap_on=False, label="Set the place"))
    def _set_point(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) != 1:
            return
        self.ed.push(ops.set_fields(self.ed.session.doc, refs, label="Set the spawn",
                                    x=self.s_pos[0].value(), y=self.s_pos[1].value(),
                                    z=self.s_pos[2].value(), yaw=self.s_yaw.value()))
    def _set_anchor(self):
        if self._loading:
            return
        refs = self.ed.session.refs()
        if len(refs) != 1 or refs[0][0] != "anchor":
            return
        doc = self.ed.session.doc
        a = dict(doc.get(refs[0]))
        a["what"] = self.a_what.currentData()
        a["where"] = {"x": self.a_pos[0].value(), "z": self.a_pos[1].value()}
        a["hard"] = self.a_hard.isChecked()
        a["once"] = self.a_once.isChecked()
        self.ed.push(ops.Change("Change the anchor", [("replace", refs[0], doc.get(refs[0]), a)],
                                select=refs) if a != doc.get(refs[0]) else ops.Change("Anchor"))
SHOW_FAULT = "Double-click: the pieces are selected in the view - move one or delete it"
class ExportDialog(QDialog):
    DEBOUNCE_MS = 300
    def __init__(self, ed, parent=None):
        super().__init__(parent)
        self.ed = ed
        self.check_runs = 0
        self.gate_runs = 0
        self._gate_at = None
        self._gate_faults = []
        self._idle = QTimer(self)
        self._idle.setSingleShot(True)
        self._idle.setInterval(self.DEBOUNCE_MS)
        self._idle.timeout.connect(self.check_later)
        from .worker import Jobs
        self._jobs = Jobs(self)
        self._box = None
        self._again = False
        self._export_after = False
        self.setWindowTitle("Export into the mod")
        fit_to_screen(self, 660, 820)
        doc = ed.session.doc
        outer = QVBoxLayout(self)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        body = QWidget()
        scroll.setWidget(body)
        self.body_scroll = scroll
        outer.addWidget(scroll, 1)
        lay = QVBoxLayout(body)
        lay.setContentsMargins(0, 0, 4, 0)
        form = QFormLayout()
        self.name = QLineEdit(doc.rest.get("name") if doc.rest.get("name") not in
                              (None, "Untitled map") else "")
        self.name.setPlaceholderText("e.g. The Frost Keep")
        self.key = QLineEdit()
        self.key.setPlaceholderText("from the name")
        self.blurb = QLineEdit(doc.rest.get("blurb") or "")
        self.blurb.setPlaceholderText("one line the map list shows (optional)")
        from .. import modfolder
        self.mod = QLineEdit(modfolder.choose(ed.settings_get("export.mod")))
        self.mod.setToolTip("The mod folder Export writes into - found where Coop DX keeps "
                            "its mods, remembered once you export")
        browse = QPushButton("Browse\u2026")
        browse.setToolTip("Choose the mod folder")
        browse.clicked.connect(self._browse)
        find = QPushButton("Find")
        find.setToolTip("Look where Coop DX keeps mods on this machine "
                        "(~/.local/share/sm64coopdx/mods, the Flatpak's) and pick one")
        find.clicked.connect(self._find)
        row = QHBoxLayout()
        row.addWidget(self.mod, 1)
        row.addWidget(find)
        row.addWidget(browse)
        form.addRow("Name", self.name)
        form.addRow("Key", self.key)
        form.addRow("Blurb", self.blurb)
        form.addRow("Mod folder", row)
        lay.addLayout(form)
        from . import modepicker
        from .. import gamemodes as gm
        lay.addWidget(widgets.header(
            "Game modes", "Which modes offer this map in their map picker. Ticked: offered. "
                          "A mark beside each says whether the map is ready for it."))
        self.modes = modepicker.ModePicker(readiness=True)
        self.modes.setToolTip("Example: tick Capture the Flag - its map picker offers this map "
                              "once it has a red and a blue flag")
        self._mode_context()
        self.modes.set_pick(gm.current(doc))
        self.modes.changed.connect(self._modes_changed)
        self.modes.fix.connect(self._mode_fix)
        lay.addWidget(self.modes, 2)
        self._doc = doc
        self._doc_idle = QTimer(self)
        self._doc_idle.setSingleShot(True)
        self._doc_idle.setInterval(120)
        self._doc_idle.timeout.connect(self._doc_settled)
        doc.listeners.append(self._doc_changed)
        self.checks = QListWidget()
        self.checks.setMaximumHeight(130)
        self.checks.setWordWrap(True)
        self.checks.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.checks.setTextElideMode(Qt.ElideNone)
        self.checks.itemActivated.connect(self._show_fault)
        self.checks.itemDoubleClicked.connect(self._show_fault)
        lay.addWidget(widgets.header("Before it goes in"))
        lay.addWidget(self.checks)
        self.banner = widgets.Banner()
        outer.insertWidget(0, self.banner)
        self.out = QPlainTextEdit()
        self.out.setReadOnly(True)
        self.out.setPlaceholderText("The play-it note appears here after the export.")
        self.out.setMaximumHeight(150)
        lay.addWidget(self.out, 1)
        buttons = QDialogButtonBox()
        self.go = buttons.addButton("Export", QDialogButtonBox.AcceptRole)
        self.go.setObjectName("primary")
        self.copy = buttons.addButton("Copy the note", QDialogButtonBox.ActionRole)
        self.remove = buttons.addButton("Remove a venue...", QDialogButtonBox.ActionRole)
        self.to = buttons.addButton("Export to...", QDialogButtonBox.ActionRole)
        self.to.setToolTip("A complete map folder anywhere else: brief, layout, report and "
                           "pictures (Shift+F5)")
        self.to.clicked.connect(lambda: self.ed.export_to())
        self.level = buttons.addButton("Export level...", QDialogButtonBox.ActionRole)
        self.level.setToolTip("For any sm64coopdx mod or modpack - no Oldfart's Mod Menu "
                              "needed; the level and everything in it (Ctrl+F5)")
        self.level.clicked.connect(lambda: self.ed.export_level())
        close = buttons.addButton(QDialogButtonBox.Close)
        self.go.clicked.connect(self.export)
        self.copy.clicked.connect(lambda: QGuiApplication.clipboard().setText(
            self.out.toPlainText()))
        self.remove.clicked.connect(self._remove)
        close.clicked.connect(self.reject)
        outer.addWidget(buttons)
        self.why = QLabel("")
        self.why.setObjectName("caption")
        self.why.setWordWrap(True)
        outer.insertWidget(outer.count() - 1, self.why)
        for w in (self.name, self.key, self.mod):
            w.textChanged.connect(self._typed)
        self._auto_find()
        self.check_later()
    def _mode_context(self):
        from .. import gamemodes as gm
        doc = self.ed.session.doc
        self.modes.set_context(doc.to_layout(models=False), gm.family_of(doc),
                               gm.players_of(doc), gm.brief_size(doc))
    def _modes_changed(self, pick):
        from .. import gamemodes as gm
        self.ed.push(gm.store(self.ed.session.doc, pick.how, pick.keys))
        self.check_later()
    def _mode_fix(self, key, issue):
        from .. import gamemodes as gm
        fix = issue.get("fix") or {}
        if fix.get("do") == "spot":
            self.ed.push(gm.spot_change(self.ed.session.doc, fix["name"]))
            self.ed.hint("Placed - move it where you like; Ctrl+Z takes it back")
        elif fix.get("do") == "place":
            if self.ed.arm(fix["entry"]):
                self.ed.hint("%s - click in a view to place it, Esc stops" % issue.text)
        self._doc_settled()
    def _doc_changed(self, *_):
        try:
            self._doc_idle.start()
        except RuntimeError:
            pass
    def _doc_settled(self):
        from .. import gamemodes as gm
        now = gm.current(self.ed.session.doc)
        if now != self.modes.pick():
            self.modes._pick = now
            self.modes._filling = True
            try:
                (self.modes.except_btn if now.how == gm.EXCEPT
                 else self.modes.only_btn).setChecked(True)
            finally:
                self.modes._filling = False
        self._mode_context()
        self.check_later()
    def done(self, result):
        try:
            self._doc.listeners.remove(self._doc_changed)
        except ValueError:
            pass
        super().done(result)
    def closeEvent(self, ev):
        try:
            self._doc.listeners.remove(self._doc_changed)
        except ValueError:
            pass
        super().closeEvent(ev)
    def _typed(self, *_):
        self.go.setEnabled(False)
        self._idle.start()
    def pending(self):
        return self._idle.isActive() or self._jobs.busy()
    def _stamps(self):
        from .. import modfolder
        doc = self.ed.session.doc
        mod = self.mod.text().strip()
        gate = (id(doc), doc.revision)
        size = None if modfolder.why_not(mod) else (id(doc), doc.revision, mod)
        return gate, size
    def _adopt(self):
        box = self._box
        if box is None:
            return
        gate, size = self._stamps()
        if box[0] == gate and gate != self._gate_at:
            self._gate_faults, self._gate_at = list(box[1]), gate
        if size is not None and box[2] == size and size != getattr(self, "_size_at", None):
            self._size_now, self._size_at = box[3], size
    def stale(self):
        self._adopt()
        gate, size = self._stamps()
        return gate != self._gate_at or (size is not None and size != getattr(
            self, "_size_at", None))
    def measuring(self):
        return self._jobs.busy()
    def check_later(self, *_):
        self._idle.stop()
        if not self.stale():
            return self.check()
        if self._jobs.busy():
            self._again = True
        else:
            self._measure()
        self.checks.clear()
        item = QListWidgetItem("Checking the map (the safety gate and the download size)...")
        item.setForeground(Qt.gray)
        self.checks.addItem(item)
        self.go.setEnabled(False)
        return None
    def _measure(self):
        gate, size = self._stamps()
        doc = self.ed.session.doc
        layout = doc.to_layout()
        mod = size[2] if size is not None else None
        self._again = False
        self.gate_runs += 1
        def job(_progress, _cancelled):
            from .. import childcall
            faults, got = childcall.call("studio.editor.engine:export_checks", layout, mod)
            self._box = (gate, faults, size, got)
            return True
        def done(_ok):
            try:
                if self._idle.isActive():
                    return
                if self._again or self.stale():
                    self._again = False
                    self.check_later()
                else:
                    problems = self.check()
                    if self._export_after:
                        self._export_after = False
                        if self.go.text().startswith("Checking"):
                            self.go.setText("Export")
                        if not problems:
                            self.export()
            except RuntimeError:
                pass
        def failed(reason):
            try:
                self.checks.clear()
                self.checks.addItem(QListWidgetItem("The check did not run: %s" % reason))
                self.go.setEnabled(False)
            except RuntimeError:
                pass
        self._jobs.run("Checking the export", job, done, failed)
    def _wait_measure(self):
        if self._jobs.busy():
            self._jobs.wait()
            self._adopt()
    def _gate(self):
        self._wait_measure()
        self._adopt()
        doc = self.ed.session.doc
        stamp = (id(doc), doc.revision)
        if stamp != self._gate_at:
            self.gate_runs += 1
            self._gate_faults = list(engine.gate(doc.to_layout()).faults)
            self._gate_at = stamp
        return self._gate_faults
    def the_key(self):
        return self.key.text().strip() or engine.key_for(self.name.text())
    def _size(self, mod):
        self._wait_measure()
        self._adopt()
        doc = self.ed.session.doc
        stamp = (id(doc), doc.revision, mod)
        if stamp != getattr(self, "_size_at", None):
            try:
                self._size_now = engine.export_size(doc.to_layout(), mod)
            except Exception:
                self._size_now = None
            self._size_at = stamp
        return self._size_now
    def check(self, *_):
        self._idle.stop()
        self.check_runs += 1
        self.checks.clear()
        from .. import modfolder
        mod = self.mod.text().strip()
        bad_mod = modfolder.why_not(mod)
        size = None if bad_mod else self._size(mod)
        from .. import gamemodes as gm
        doc = self.ed.session.doc
        problems = ([bad_mod] if bad_mod else []) + engine.check_export(
            None, self.name.text(), self.the_key(), self.mod.text(), gate_faults=self._gate(),
            size=size, modes=self.modes.offered(), mode_layout=doc.to_layout(models=False),
            players=gm.players_of(doc), map_size=gm.brief_size(doc))
        if size is not None:
            item = QListWidgetItem(engine.size_line(size))
            item.setForeground(self._tone("text_dim"))
            self.checks.addItem(item)
        for p in problems:
            item = QListWidgetItem(p)
            playable = " is not playable yet: " in p
            item.setForeground(self._tone("bad") if p.startswith(("safety", "the mod folder is"))
                               or playable or p == bad_mod else self._tone("warn"))
            if playable:
                item.setToolTip("Press the button next to the mode under Game modes, or untick "
                                "the mode")
            elif p.startswith("safety gate: ") and not p.startswith("safety gate: ..."):
                item.setToolTip(SHOW_FAULT)
            self.checks.addItem(item)
        if not problems:
            item = QListWidgetItem("Ready: the safety gate passes, the key %s is free%s." % (
                self.the_key(), " (it replaces the venue exported under it before)"
                if engine.replaces(self.the_key(), self.mod.text()) else ""))
            item.setForeground(self._tone("ok"))
            self.checks.addItem(item)
        self.go.setEnabled(not problems)
        self._say_why(problems, bad_mod)
        return problems
    def _tone(self, name):
        from PySide6.QtGui import QColor
        tokens = getattr(self.ed, "tokens", None) or {}
        fallback = {"bad": "#e5534b", "warn": "#d29922", "ok": "#3fb950",
                    "text_dim": "#8b949e"}[name]
        return QColor(tokens.get(name, fallback))
    def _say_why(self, problems, bad_mod=None):
        first = problems[0] if problems else ""
        self.why.setText(("Export is waiting: %s" % first) if first else "")
        self.why.setVisible(bool(first))
        self.go.setToolTip(("Not yet: %s" % first) if first else
                           "Put the map into the mod (the safety gate passed)")
        name_bad = bool(first) and (first == "give the map a name" or first.startswith("key "))
        mod_bad = bool(first) and (first == bad_mod)
        for field, bad in ((self.name, name_bad), (self.mod, mod_bad)):
            field.setProperty("bad", "true" if bad else "false")
            field.style().unpolish(field)
            field.style().polish(field)
    def _auto_find(self):
        from .. import modfolder
        if self.mod.text().strip() and not modfolder.why_not(self.mod.text().strip()):
            return False
        try:
            found = modfolder.candidates()
        except Exception:
            return False
        if len(found) == 1:
            self.mod.setText(found[0])
            return True
        return False
    def _show_fault(self, item):
        text = item.text() if item is not None else ""
        if not text.startswith("safety gate: "):
            return False
        self.ed.select_fault(text[len("safety gate: "):])
        n = len(self.ed.session.selection)
        self.ed.hint("%s selected: move one (drag it, or the arrow keys) or delete it "
                     "(Delete) - then this line goes" % ("%d pieces" % n if n != 1 else
                                                        "The piece") if n else
                     "These pieces are not found any more - check again")
        return bool(n)
    def _find(self):
        from PySide6.QtWidgets import QMenu
        from .. import modfolder
        found = modfolder.candidates()
        if not found:
            QMessageBox.information(self, "Find", "No copy of the mod was found where Coop DX "
                                    "keeps mods - choose the folder with ...")
            return
        m = QMenu(self)
        for path in found:
            m.addAction(path, lambda p=path: self.mod.setText(p))
        m.exec(self.mapToGlobal(self.rect().center()))
    def _browse(self):
        d = QFileDialog.getExistingDirectory(self, "The mod folder", self.mod.text())
        if d:
            self.mod.setText(d)
    def export(self):
        if self.stale() or self._jobs.busy() or self._idle.isActive():
            self._export_after = True
            self.go.setEnabled(False)
            self.go.setText("Checking\u2026")
            self.check_later()
            return None
        if self.check():
            return
        key = self.the_key()
        if engine.replaces(key, self.mod.text()) and QMessageBox.question(
                self, "Replace?", "%s was exported before. Replace it with this map?" % key) \
                != QMessageBox.Yes:
            return
        self.ed.settings_set("export.mod", self.mod.text())
        self.go.setEnabled(False)
        self.banner.clear()
        self.out.setPlainText("Writing the map into the mod and checking it\u2026")
        self._export_key = key
        self.ed.export(self.name.text().strip(), key, self.mod.text(), self.blurb.text().strip()
                       or None, self._done, self._failed, modes=self.modes.resolved())
    def written(self, res):
        out = list(res.get("touched", []))
        key = getattr(self, "_export_key", None)
        if key:
            lvl = os.path.join(self.mod.text(), "levels", "level_of_%s_entry.lvl" % key)
            if os.path.exists(lvl) and not any(os.path.abspath(p) == os.path.abspath(lvl)
                                               for p in out):
                out.append(lvl)
        return out
    def _done(self, res):
        files = self.written(res)
        self.out.setPlainText(res["handoff"] + "\n\nWritten:\n" + "\n".join(
            "  " + os.path.relpath(p, self.mod.text()) for p in files))
        self.go.setEnabled(True)
        self.go.setText("Export again")
        self.banner.ok("Exported \u201c%s\u201d into the mod" % self.name.text().strip(),
                       "%d files written - the play-it note below says how to play it."
                       % len(files), getattr(self.ed.studio, "ux", None)
                       if hasattr(self.ed, "studio") else None, opener=self._open_mod,
                       player=lambda: self.ed.launch_game(self.mod.text().strip()))
    def _failed(self, reason):
        self.out.setPlainText("Not exported: %s" % reason)
        self.go.setEnabled(True)
        self.banner.fail("Not exported", str(reason))
    def _open_mod(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices
        folder = self.mod.text().strip()
        if folder and os.path.isdir(folder):
            return QDesktopServices.openUrl(QUrl.fromLocalFile(folder))
        return False
    def _remove(self):
        folder = os.path.join(self.mod.text(), "tools", "venues-generated")
        keys = sorted(n[:-5] for n in os.listdir(folder) if n.endswith(".json")) \
            if os.path.isdir(folder) else []
        if not keys:
            QMessageBox.information(self, "Remove", "No exported venue in %s." % self.mod.text())
            return
        from PySide6.QtWidgets import QInputDialog
        key, ok = QInputDialog.getItem(self, "Remove a venue", "Take this venue out of the mod:",
                                       keys, 0, False)
        if ok and key:
            try:
                engine.unexport(key, self.mod.text())
            except engine.EngineError as exc:
                self.out.setPlainText("Not removed: %s" % exc)
                return
            self.out.setPlainText("%s is out of the mod again (its level, pictures and row)." % key)
            self.check_later()
class TextDialog(QDialog):
    def __init__(self, title, text, parent=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.resize(640, 520)
        lay = QVBoxLayout(self)
        box = QPlainTextEdit(text)
        box.setReadOnly(True)
        f = QFont("monospace")
        f.setStyleHint(QFont.Monospace)
        box.setFont(f)
        lay.addWidget(box)
        buttons = QDialogButtonBox(QDialogButtonBox.Close)
        buttons.rejected.connect(self.reject)
        lay.addWidget(buttons)
