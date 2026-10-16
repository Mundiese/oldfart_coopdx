from PySide6.QtCore import QSize, Qt, QTimer
from PySide6.QtGui import QIcon, QImage, QPixmap
from PySide6.QtWidgets import (QCheckBox, QComboBox, QFormLayout, QGridLayout, QHBoxLayout,
                               QLabel, QLineEdit, QListWidget, QListWidgetItem, QPlainTextEdit,
                               QProgressBar, QPushButton, QScrollArea, QSlider, QSpinBox,
                               QVBoxLayout, QWidget)
from .. import engine
from . import widgets
AUTO = "auto"
EXAMPLE = ("e.g. \"16 players CTF, ice theme, lots of height, a bridge in the middle, "
           "world spawn in the south\" - or \"a small fast shooter map, a tower in the north-west\"")
REFINE_EXAMPLE = "bigger centre | move the spawn north | a pit instead of the crown | " \
                 "keep the bases | ice floor"
class WishPanel(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self._loading = False
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        body = QWidget()
        scroll.setWidget(body)
        outer.addWidget(scroll)
        lay = QVBoxLayout(body)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(8)
        lay.addWidget(widgets.header("Your wish", "German or English; what it understood is "
                                     "shown below before anything is built"))
        self.text = QPlainTextEdit()
        self.text.setPlaceholderText(EXAMPLE)
        self.text.setFixedHeight(84)
        self.text.textChanged.connect(self._text_changed)
        lay.addWidget(self.text)
        self.reading = widgets.caption("")
        from .wish_chips import ChipsBox, WishChips
        self.chips = WishChips(self.text.setPlainText, self._set_control, self.read_now)
        holder = QWidget()
        hl = QVBoxLayout(holder)
        hl.setContentsMargins(0, 0, 0, 0)
        hl.setSpacing(4)
        hl.addWidget(self.reading)
        hl.addWidget(self.chips)
        self.chips_box = ChipsBox(self.chips, holder)
        lay.addWidget(self.chips_box)
        self.export_taught_btn = QPushButton("Export taught words ...")
        self.export_taught_btn.setToolTip("write the words you taught as lexicon entries, "
                                          "for a merge into the shipped lexicon")
        self.export_taught_btn.clicked.connect(lambda: self.chips.export_taught())
        lay.addWidget(self.export_taught_btn, 0, Qt.AlignLeft)
        self.taught_shown()
        self._read_timer = QTimer(self)
        self._read_timer.setSingleShot(True)
        self._read_timer.setInterval(350)
        self._read_timer.timeout.connect(self.read_now)
        self.controls = {}
        grid = QGridLayout()
        grid.setHorizontalSpacing(8)
        grid.setVerticalSpacing(6)
        simple = [c for c in engine.CONTROLS if c[4]]
        more = [c for c in engine.CONTROLS if not c[4]]
        for n, c in enumerate(simple):
            grid.addWidget(QLabel(c[1]), n // 2 * 2, n % 2)
            grid.addWidget(self._control(c), n // 2 * 2 + 1, n % 2)
        lay.addLayout(grid)
        more_w = QWidget()
        form = QFormLayout(more_w)
        form.setContentsMargins(0, 0, 0, 0)
        for c in more:
            form.addRow(c[1], self._control(c))
        from .modepicker import ModePicker
        form.addRow(widgets.header("Game modes", "which modes offer the map; untouched: the "
                                   "map kind's own (or the ones your wish names)"))
        self.modes = ModePicker(compact=True)
        self.modes.setToolTip("Example: on an objective map, untick Domination - the map is "
                              "offered to the other objective modes only")
        self.modes.changed.connect(lambda *_: self._changed())
        form.addRow(self.modes)
        kind, fam = self.controls.get("family", (None, None))
        if fam is not None:
            fam.currentIndexChanged.connect(lambda *_: self._family_changed())
        form.addRow(widgets.header("Features", "ticked = wanted, half = avoided, empty = "
                                   "don't care"))
        self.features = QListWidget()
        self.features.setFixedHeight(150)
        for f in engine.FEATURES:
            item = QListWidgetItem(f.replace("_", " "))
            item.setData(Qt.UserRole, f)
            if f in engine.FEATURE_HELP:
                item.setToolTip(engine.FEATURE_HELP[f])
            item.setFlags(item.flags() | Qt.ItemIsUserCheckable | Qt.ItemIsUserTristate)
            item.setCheckState(Qt.Unchecked)
            self.features.addItem(item)
        self.features.itemChanged.connect(lambda *_: self._changed())
        form.addRow(self.features)
        form.addRow(widgets.header("World DNA", "0..1 dials that steer every layer at once; "
                                   "unticked = the family's default"))
        self.dna = {}
        for key in engine.DNA:
            row = QHBoxLayout()
            on = QCheckBox()
            slider = QSlider(Qt.Horizontal)
            slider.setRange(0, 100)
            slider.setEnabled(False)
            on.toggled.connect(slider.setEnabled)
            on.toggled.connect(lambda *_: self._changed())
            slider.valueChanged.connect(lambda *_: self._changed())
            row.addWidget(on)
            row.addWidget(slider, 1)
            holder = QWidget()
            holder.setLayout(row)
            form.addRow(key, holder)
            self.dna[key] = (on, slider)
        form.addRow(widgets.header("Looks", "visual modifiers the venue wears (none by default)"))
        self.visuals = QListWidget()
        self.visuals.setFixedHeight(110)
        for v in engine.VISUALS:
            item = QListWidgetItem(v.replace("_", " "))
            item.setData(Qt.UserRole, v)
            item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
            item.setCheckState(Qt.Unchecked)
            self.visuals.addItem(item)
        self.visuals.itemChanged.connect(lambda *_: self._changed())
        form.addRow(self.visuals)
        lay.addWidget(widgets.Collapsible("More - the whole brief", more_w))
        row = QHBoxLayout()
        self.generate_btn = QPushButton("Generate")
        self.generate_btn.setObjectName("primary")
        self.generate_btn.setToolTip("Build the best map for this wish (Ctrl+Return). The "
                                     "current map stays one undo away.")
        self.generate_btn.clicked.connect(lambda: self.ed.run_action("map.generate"))
        self.variety_btn = QPushButton("Variety")
        self.variety_btn.setToolTip("Different good maps for the same wish (Ctrl+Alt+Return)")
        self.variety_btn.clicked.connect(lambda: self.ed.run_action("map.variety"))
        self.count = QSpinBox()
        self.count.setRange(2, 12)
        self.count.setValue(6)
        self.count.setToolTip("How many different maps")
        self.explain_btn = QPushButton("Explain")
        self.explain_btn.setToolTip("The brief in words - every assumed field marked - and "
                                    "where the anchors go, before anything is built")
        self.explain_btn.clicked.connect(self.explain)
        lay.addWidget(self.generate_btn)
        ways = QWidget()
        wl = QVBoxLayout(ways)
        wl.setContentsMargins(0, 0, 0, 0)
        row.addWidget(self.variety_btn)
        row.addWidget(self.count)
        row.addWidget(self.explain_btn)
        row.addStretch(1)
        wl.addLayout(row)
        from .seedbar import SeedBar
        self.seedbar = SeedBar(ed)
        wl.addWidget(self.seedbar)
        wl.addWidget(widgets.header("Change only what you ask",
                                    "refine: the rest of the map stays as it is"))
        row = QHBoxLayout()
        self.refine_text = QLineEdit()
        self.refine_text.setPlaceholderText(REFINE_EXAMPLE)
        self.refine_text.returnPressed.connect(lambda: self.ed.run_action("map.refine"))
        self.refine_btn = QPushButton("Refine")
        self.refine_btn.clicked.connect(lambda: self.ed.run_action("map.refine"))
        row.addWidget(self.refine_text, 1)
        row.addWidget(self.refine_btn)
        wl.addLayout(row)
        self.more_ways = widgets.Collapsible("More: variety, seed, refine",
                                             ways)
        lay.addWidget(self.more_ways)
        row = QHBoxLayout()
        self.bar = QProgressBar()
        self.bar.setTextVisible(True)
        self.bar.setVisible(False)
        self.cancel_btn = QPushButton("Cancel")
        self.cancel_btn.setVisible(False)
        self.cancel_btn.clicked.connect(self.ed.jobs.cancel)
        row.addWidget(self.bar, 1)
        row.addWidget(self.cancel_btn)
        lay.addLayout(row)
        self.said = widgets.caption("")
        lay.addWidget(self.said)
        self.results = QListWidget()
        self.results.setViewMode(QListWidget.IconMode)
        self.results.setIconSize(QSize(120, 120))
        self.results.setGridSize(QSize(136, 156))
        self.results.setResizeMode(QListWidget.Adjust)
        self.results.setMovement(QListWidget.Static)
        self.results.setVisible(False)
        self.results.setToolTip("Double-click a map to use it (one undo step back)")
        self.results.itemActivated.connect(self._use_variety)
        lay.addWidget(self.results)
        lay.addStretch(1)
        ed.jobs.started.connect(self._busy)
        ed.jobs.progress.connect(self._progress)
        ed.jobs.ended.connect(self._idle)
        self.load_brief(ed.session.doc.brief)
    def _control(self, c):
        field, label, kind, choices, _ = c
        if kind == "steps":
            from .stepslider import StepSlider
            w = StepSlider(choices)
            w.currentIndexChanged.connect(lambda *_: self._changed())
            w.setToolTip("%s - leftmost: auto (the family's default or what the wish says)"
                         % label)
            self.controls[field] = ("choice", w)
            return w
        if kind == "choice":
            w = QComboBox()
            w.addItem("auto", None)
            for value, text in choices:
                if value == "auto":
                    continue
                w.addItem(text, value)
            w.currentIndexChanged.connect(lambda *_: self._changed())
        else:
            lo, hi = choices
            w = QSpinBox()
            w.setRange(lo - 1, hi)
            w.setSpecialValueText("auto")
            w.setValue(lo - 1)
            w.valueChanged.connect(lambda *_: self._changed())
        w.setToolTip("%s - auto: the family's default (or what the wish says)" % label)
        self.controls[field] = (kind, w)
        return w
    def values(self):
        out = {}
        for field, (kind, w) in self.controls.items():
            if kind == "choice":
                out[field] = w.currentData()
            else:
                out[field] = None if w.value() == w.minimum() else w.value()
        want, avoid = [], []
        for i in range(self.features.count()):
            item = self.features.item(i)
            if item.checkState() == Qt.Checked:
                want.append(item.data(Qt.UserRole))
            elif item.checkState() == Qt.PartiallyChecked:
                avoid.append(item.data(Qt.UserRole))
        out["want"], out["avoid"] = want, avoid
        out["dna"] = {k: s.value() / 100.0 for k, (on, s) in self.dna.items() if on.isChecked()}
        out["visuals"] = [self.visuals.item(i).data(Qt.UserRole) for i in range(self.visuals.count())
                          if self.visuals.item(i).checkState() == Qt.Checked]
        out["modes"] = self.modes.value()
        return out
    def _family(self):
        kind, w = self.controls.get("family", (None, None))
        fam = w.currentData() if w is not None else None
        if fam:
            return fam
        from .. import gamemodes as gm
        return gm.family_of(self.ed.session.doc)
    def _family_changed(self):
        from .. import gamemodes as gm
        fam = self._family()
        self.modes.set_context({}, fam)
        if not self.modes.pick().explicit:
            self.modes.set_pick(gm.Pick(gm.ONLY, gm.defaults({}, fam), False))
    def load_brief(self, brief):
        self._loading = True
        try:
            vals = engine.control_values(brief or {})
            wish = (brief or {}).get("wish") or ""
            if wish and not wish.startswith("refine:"):
                said = engine.read_wish(wish).raw
                for k in list(vals):
                    if k in said:
                        vals[k] = None
                feats = said.get("features") or {}
                vals["want"] = [f for f in vals["want"] if f not in (feats.get("want") or [])]
                vals["avoid"] = [f for f in vals["avoid"] if f not in (feats.get("avoid") or [])]
                for k in ("dna", "visuals"):
                    if k in said:
                        vals[k] = {} if k == "dna" else []
            for field, (kind, w) in self.controls.items():
                v = None if field in ("seed", "candidates") else vals.get(field)
                if kind == "choice":
                    i = w.findData(v) if v is not None else 0
                    w.setCurrentIndex(max(0, i))
                else:
                    w.setValue(w.minimum() if v is None else int(v))
            for i in range(self.features.count()):
                item = self.features.item(i)
                f = item.data(Qt.UserRole)
                item.setCheckState(Qt.Checked if f in vals["want"] else
                                   Qt.PartiallyChecked if f in vals["avoid"] else Qt.Unchecked)
            for k, (on, s) in self.dna.items():
                on.setChecked(k in vals["dna"])
                s.setValue(int(round(100 * vals["dna"].get(k, 0.5))))
            for i in range(self.visuals.count()):
                item = self.visuals.item(i)
                item.setCheckState(Qt.Checked if item.data(Qt.UserRole) in vals["visuals"]
                                   else Qt.Unchecked)
            self._load_modes(brief or {})
            wish = (brief or {}).get("wish")
            if wish and wish != self.text.toPlainText() and not wish.startswith("refine:"):
                self.text.setPlainText(wish)
        finally:
            self._loading = False
    def _load_modes(self, brief):
        from .. import gamemodes as gm
        fam = self._family()
        self.modes.set_context({}, fam)
        modes = list(brief.get("modes") or [])
        said = []
        wish = brief.get("wish") or ""
        if wish and not wish.startswith("refine:"):
            said = list(engine.read_wish(wish).raw.get("modes") or [])
        if modes and "modes" not in (brief.get("defaulted") or []) and modes != said:
            self.modes.set_pick(gm.Pick(gm.ONLY, modes, True))
        else:
            self.modes.set_pick(gm.Pick(gm.ONLY, gm.defaults({}, fam), False))
    def _changed(self):
        if not self._loading:
            self.read_now()
    def _text_changed(self):
        if not self._loading:
            self._read_timer.start()
    def wish_text(self):
        return self.text.toPlainText().strip()
    def brief(self):
        doc = self.ed.session.doc.brief or {}
        base = {k: doc.get(k) for k in ("anchors", "objects", "name") if doc.get(k)}
        return engine.brief_from(self.values(), self.wish_text(), base=base or None)
    def taught_shown(self):
        try:
            from mapgen import userlex
            n = len(userlex.words())
        except Exception:
            n = 0
        self.export_taught_btn.setVisible(n > 0)
        return n
    def read_now(self):
        self.taught_shown()
        try:
            raw, reading = self.brief()
        except Exception as exc:
            self.reading.setText("Could not read the wish: %s" % exc)
            return
        lines = engine.say_reading(reading, raw) if reading is not None else []
        if not lines:
            lines = ["Type a wish, or set the controls - then Generate."]
        self.reading.setText("\n".join(lines))
        self.chips.show_reading(reading, self.wish_text())
        self.chips_box.fit()
    def _set_control(self, field, value):
        kind, w = self.controls.get(field, (None, None))
        if kind == "choice":
            i = w.findData(value)
            if i >= 0:
                w.setCurrentIndex(i)
        self.read_now()
    def explain(self):
        raw, _ = self.brief()
        self.ed.show_text("What the engine reads", engine.explain(raw))
    def _busy(self, label):
        for b in (self.generate_btn, self.variety_btn, self.refine_btn):
            b.setEnabled(False)
        self.bar.setVisible(True)
        self.bar.setRange(0, 0)
        self.bar.setFormat(label)
        self.cancel_btn.setVisible(True)
    def _progress(self, a, b, text):
        if b > 0:
            self.bar.setRange(0, b)
            self.bar.setValue(a)
        self.bar.setFormat(text)
    def _idle(self, reason):
        for b in (self.generate_btn, self.variety_btn, self.refine_btn):
            b.setEnabled(True)
        self.bar.setVisible(False)
        self.cancel_btn.setVisible(False)
        if reason:
            self.said.setText(reason)
    def show_said(self, lines):
        self.said.setText("\n".join(lines[-12:]))
    def show_variety(self, maps):
        self.results.clear()
        self._variety = maps
        for n, g in enumerate(maps):
            item = QListWidgetItem(QIcon(_thumbnail(g.layout)), "%d  quality %.2f" % (
                n + 1, getattr(g, "quality", 0) or 0))
            item.setData(Qt.UserRole, n)
            item.setToolTip("\n".join(g.lines))
            self.results.addItem(item)
        self.results.setVisible(bool(maps))
    def _use_variety(self, item):
        g = self._variety[item.data(Qt.UserRole)]
        self.ed.apply_generated(g)
def _thumbnail(layout, size=120):
    try:
        from mapgen.render import views
        im = views.top_down(layout, size=size).convert("RGBA")
        data = im.tobytes("raw", "RGBA")
        img = QImage(data, im.width, im.height, 4 * im.width, QImage.Format_RGBA8888).copy()
        return QPixmap.fromImage(img)
    except Exception:
        pm = QPixmap(size, size)
        pm.fill(Qt.darkGray)
        return pm
