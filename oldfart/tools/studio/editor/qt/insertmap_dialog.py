import os
from PySide6.QtCore import Qt
from PySide6.QtWidgets import (QButtonGroup, QCheckBox, QComboBox, QDialog, QFileDialog,
                               QGridLayout, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
                               QPushButton, QRadioButton, QSpinBox, QVBoxLayout)
from .. import insertmap
INTRO = ("Bring another map into this one - all of it, or just a part. It follows the mouse "
         "until you click where it goes. Ctrl+Z takes it out again.")
class InsertMapDialog(QDialog):
    def __init__(self, ed):
        super().__init__(ed.window)
        self.ed = ed
        self.src = None
        self.source = ""
        self.ins = None
        self.setWindowTitle("Insert map")
        self.resize(520, 600)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 14, 16, 14)
        intro = QLabel(INTRO)
        intro.setWordWrap(True)
        intro.setObjectName("caption")
        lay.addWidget(intro)
        lay.addWidget(QLabel("<b>1. Which map?</b>"))
        row = QHBoxLayout()
        self.pick_btn = QPushButton("Choose a map file...")
        self.pick_btn.setToolTip("An .ofmap you saved, or a map folder (brief.json + "
                                 "layout.json)")
        self.pick_btn.clicked.connect(self.choose_file)
        row.addWidget(self.pick_btn)
        self.templates = QComboBox()
        self.templates.setToolTip("Or one of the maps that come with the Studio")
        self.templates.addItem("...or a ready map", None)
        try:
            from studio.library import wizard
            for source, name, what in wizard.templates():
                self.templates.addItem("%s (%s)" % (name, what), source)
        except Exception:
            pass
        self.templates.currentIndexChanged.connect(self._template)
        row.addWidget(self.templates, 1)
        lay.addLayout(row)
        self.which = QLabel("No map chosen yet")
        self.which.setObjectName("dim")
        self.which.setWordWrap(True)
        lay.addWidget(self.which)
        lay.addWidget(QLabel("<b>2. Which part?</b>"))
        self.part = QButtonGroup(self)
        self.part_btns = {}
        for key, label, tip in (
                ("whole", "The whole map", "Every block, logic piece and mover of it"),
                ("region", "A box of it", "Everything whose middle is inside the box below"),
                ("layers", "Some of its layers", "Tick the layers below"),
                ("groups", "Some of its groups", "Tick the groups below")):
            b = QRadioButton(label)
            b.setToolTip(tip)
            self.part.addButton(b)
            self.part_btns[key] = b
            b.toggled.connect(lambda on, k=key: on and self._part(k))
            lay.addWidget(b)
        box = QGridLayout()
        self.box = {}
        self.box_labels = []
        for i, (key, label) in enumerate((("x0", "From x"), ("x1", "to x"), ("z0", "From z"),
                                          ("z1", "to z"))):
            sp = QSpinBox()
            sp.setRange(-60000, 60000)
            sp.setSingleStep(200)
            sp.setSuffix(" u")
            sp.setToolTip("In units: 100 is about one Mario step; the Studio's grid is 200")
            sp.valueChanged.connect(self.refresh)
            self.box[key] = sp
            lab = QLabel(label)
            self.box_labels.append(lab)
            box.addWidget(lab, i // 2, (i % 2) * 2)
            box.addWidget(sp, i // 2, (i % 2) * 2 + 1)
        lay.addLayout(box)
        self.list = QListWidget()
        self.list.setToolTip("Tick what to bring")
        self.list.itemChanged.connect(self.refresh)
        lay.addWidget(self.list, 1)
        lay.addWidget(QLabel("<b>3. What comes along?</b>"))
        self.logic = QCheckBox("Its targets, buttons, zones and wires (numbered so they do not "
                               "clash with this map's)")
        self.logic.setChecked(True)
        self.logic.toggled.connect(self.refresh)
        lay.addWidget(self.logic)
        self.look = QCheckBox("Its sun and mood (the light and the weather)")
        self.look.toggled.connect(self.refresh)
        lay.addWidget(self.look)
        self.spawns = QCheckBox("Its spawns")
        self.spawns.setToolTip("Off: this map keeps its own spawns")
        self.spawns.toggled.connect(self.refresh)
        lay.addWidget(self.spawns)
        self.said = QLabel("")
        self.said.setWordWrap(True)
        lay.addWidget(self.said)
        row = QHBoxLayout()
        close = QPushButton("Cancel")
        close.setAutoDefault(False)
        close.clicked.connect(self.reject)
        row.addWidget(close)
        row.addStretch(1)
        self.go = QPushButton("Put it in the hand")
        self.go.setObjectName("primary")
        self.go.setDefault(True)
        self.go.setToolTip("Then click in a view where it goes (T turns it, Esc stops)")
        self.go.clicked.connect(self.place)
        row.addWidget(self.go)
        lay.addLayout(row)
        self.part_btns["whole"].setChecked(True)
    def choose_file(self):
        start = os.path.dirname(self.ed.session.doc.meta.get("path") or "") or os.getcwd()
        path, _ = QFileDialog.getOpenFileName(self, "Insert which map?", start,
                                              "Maps (*.ofmap layout.json);;All files (*)")
        if path:
            if os.path.basename(path) == "layout.json":
                path = os.path.dirname(path)
            self.set_source(path)
    def _template(self, i):
        source = self.templates.itemData(i)
        if source:
            self.set_source(source)
    def set_source(self, source):
        try:
            self.src = insertmap.load(source)
        except insertmap.InsertError as why:
            self.src = None
            self.which.setText("Not read: %s" % why)
            self.refresh()
            return False
        self.source = source
        name = insertmap.name_of(self.src, source)
        what = insertmap.parts(self.src)
        self.which.setText("%s - %d things, %d layer%s, %d group%s" % (
            name, what["count"], len(what["layers"]), "" if len(what["layers"]) == 1 else "s",
            len(what["groups"]), "" if len(what["groups"]) == 1 else "s"))
        from .. import geometry as geo
        items = [self.src.get(r) for k in insertmap.KINDS for r in self.src.refs(k)]
        b = geo.grid_box(items) if items else None
        if b is not None:
            for key, v in (("x0", b[0]), ("x1", b[1]), ("z0", b[4]), ("z1", b[5])):
                self.box[key].blockSignals(True)
                self.box[key].setValue(int(v))
                self.box[key].blockSignals(False)
        self.part_btns["layers"].setEnabled(bool(what["layers"]))
        self.part_btns["groups"].setEnabled(bool(what["groups"]))
        self._part(self.current_part())
        return True
    def current_part(self):
        for k, b in self.part_btns.items():
            if b.isChecked():
                return k
        return "whole"
    def _part(self, key):
        for sp in self.box.values():
            sp.setVisible(key == "region")
        for lab in self.box_labels:
            lab.setVisible(key == "region")
        self.list.blockSignals(True)
        self.list.clear()
        if self.src is not None and key in ("layers", "groups"):
            what = insertmap.parts(self.src)[key]
            for gid, name, n in what:
                it = QListWidgetItem("%s (%d)" % (name, n))
                it.setData(Qt.UserRole, gid)
                it.setFlags(it.flags() | Qt.ItemIsUserCheckable)
                it.setCheckState(Qt.Unchecked)
                self.list.addItem(it)
        self.list.blockSignals(False)
        self.list.setVisible(key in ("layers", "groups"))
        self.refresh()
    def ticked(self):
        return [self.list.item(i).data(Qt.UserRole) for i in range(self.list.count())
                if self.list.item(i).checkState() == Qt.Checked]
    def build(self):
        if self.src is None:
            return None, "Choose a map first"
        part = self.current_part()
        kw = {"part": part, "logic": self.logic.isChecked(), "look": self.look.isChecked(),
              "spawns": self.spawns.isChecked(), "source": self.source}
        if part == "region":
            kw["region"] = (self.box["x0"].value(), self.box["x1"].value(),
                            self.box["z0"].value(), self.box["z1"].value())
        elif part == "layers":
            kw["layers"] = self.ticked()
            if not kw["layers"]:
                return None, "Tick a layer to bring"
        elif part == "groups":
            kw["groups_"] = self.ticked()
            if not kw["groups_"]:
                return None, "Tick a group to bring"
        try:
            return insertmap.Insert(self.src, **kw), ""
        except insertmap.InsertError as why:
            return None, str(why)[:1].upper() + str(why)[1:]
    def refresh(self, *_):
        self.ins, why = self.build()
        if self.ins is None:
            self.said.setText(why)
            self.go.setEnabled(False)
            return
        c = self.ins.counts()
        parts = []
        for k, word in (("piece", "block"), ("object", "logic piece or object"),
                        ("mover", "mover"), ("spawn", "spawn")):
            if c.get(k):
                parts.append("%d %s%s" % (c[k], word, "" if c[k] == 1 else "s"))
        if self.ins.wires:
            parts.append("%d wire%s" % (len(self.ins.wires),
                                        "" if len(self.ins.wires) == 1 else "s"))
        ok, line = self.ins.budget_line(self.ed.session.doc)
        self.said.setText("Brings %s.\nBudget: %s" % (", ".join(parts), line))
        self.said.setStyleSheet("" if ok else "color: #ef5350;")
        self.go.setEnabled(True)
    def place(self):
        if self.ins is None:
            return False
        ok = self.ed.arm_insert(self.ins)
        if ok:
            self.accept()
        return ok
