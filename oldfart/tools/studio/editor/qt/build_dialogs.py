from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFormLayout,
                               QGridLayout, QLabel, QPushButton, QSpinBox, QVBoxLayout,
                               QWidget)
from .. import csg, geometry as geo, rooms
from .widgets import Collapsible, caption
DIRECTION_WORDS = (("+z", "front (+z)"), ("-z", "back (-z)"), ("+x", "right (+x)"),
                   ("-x", "left (-x)"))
DOOR_LAYOUT = (("+z", 0, 0), ("-z", 0, 1), ("-x", 0, 2), ("+x", 0, 3))
def _spin(lo, hi, value, step=1, suffix="", tip=""):
    s = QSpinBox()
    s.setRange(lo, hi)
    s.setSingleStep(step)
    s.setValue(int(value))
    if suffix:
        s.setSuffix(suffix)
    if tip:
        s.setToolTip(tip)
    return s
def _combo(pairs, value, tip=""):
    c = QComboBox()
    for key, words in pairs:
        c.addItem(words, key)
    i = c.findData(value)
    c.setCurrentIndex(max(0, i))
    if tip:
        c.setToolTip(tip)
    return c
def inserted(change):
    return [s[3] for s in change.steps if s[0] == "insert"]
class BuildDialog(QDialog):
    title = ""
    intro = ""
    def __init__(self, ed):
        super().__init__(ed.window)
        self.ed = ed
        self.session = ed.session
        self.setWindowTitle(self.title)
        self.setModal(False)
        self.setMinimumWidth(420)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(14, 12, 14, 12)
        lay.setSpacing(8)
        if self.intro:
            lay.addWidget(caption(self.intro))
        self.basic = QFormLayout()
        lay.addLayout(self.basic)
        body = QWidget()
        self.more = QFormLayout(body)
        self.more.setContentsMargins(0, 0, 0, 0)
        self.more_box = Collapsible("More options", body)
        self.basic.setVerticalSpacing(8)
        self.more.setVerticalSpacing(8)
        self.more_box.button.toggled.connect(
            lambda *_: QTimer.singleShot(0, self, lambda: self.resize(self.width(),
                                                                self.sizeHint().height())))
        lay.addWidget(self.more_box)
        self.note = QLabel("")
        self.note.setWordWrap(True)
        self.note.setObjectName("caption")
        lay.addWidget(self.note)
        self.buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        self.buttons.button(QDialogButtonBox.Ok).setText("Build it")
        self.buttons.button(QDialogButtonBox.Ok).setObjectName("primary")
        self.buttons.button(QDialogButtonBox.Ok).setToolTip("Enter: build it - Ctrl+Z takes it "
                                                            "back")
        self.buttons.accepted.connect(self.accept)
        self.buttons.rejected.connect(self.reject)
        lay.addWidget(self.buttons)
        self.fields = []
        self.build_form()
        if self.more.rowCount() == 0:
            self.more_box.hide()
        for w in self.fields:
            sig = getattr(w, "valueChanged", None) or getattr(w, "currentIndexChanged", None) \
                or getattr(w, "toggled", None)
            sig.connect(lambda *_: self.preview())
        self.finished.connect(lambda *_: self.ed.sync.clear_ghost())
        self.preview()
    def add(self, form, label, widget):
        form.addRow(label, widget)
        self.fields.append(widget)
        return widget
    def build_form(self):
        raise NotImplementedError
    def values(self):
        raise NotImplementedError
    def change(self, values):
        raise NotImplementedError
    def run(self, values):
        return self.ed.session.push_built(self.change(values))
    def preview(self):
        try:
            ch = self.change(self.values())
        except (ValueError, KeyError) as why:
            self.note.setText(str(why))
            self.ed.sync.clear_ghost()
            return None
        left, budget = csg.budget_left(self.session.doc)
        if ch.refused or not ch:
            self.note.setText(ch.label)
            self.note.setStyleSheet("color: #e0a040")
            self.buttons.button(QDialogButtonBox.Ok).setEnabled(False)
            self.ed.sync.clear_ghost()
            return ch
        n = len(inserted(ch))
        gone = len([s for s in ch.steps if s[0] == "remove"])
        self.note.setStyleSheet("")
        self.note.setText("%s - %d piece%s, %d left in the budget of %d" % (
            ch.label, n - gone, "" if n - gone == 1 else "s", left - (n - gone), budget))
        self.buttons.button(QDialogButtonBox.Ok).setEnabled(True)
        self.ed.sync.show_ghost(inserted(ch))
        return ch
    def accept(self):
        values = self.values()
        self.ed.sync.clear_ghost()
        msg = self.run(values)
        super().accept()
        self.ed.after_change(msg)
class RoomDialog(BuildDialog):
    title = "Room by size"
    intro = ("A room at the mouse: walls, a floor and doors on the sides you tick. "
             "Walls wear the current texture, the floor the second one.")
    def build_form(self):
        r = self.session.room
        self.w = self.add(self.basic, "Width", _spin(3, 40, r["w"], suffix=" cells",
                                                      tip="Across x, walls included - a cell "
                                                          "is 2 m"))
        self.d = self.add(self.basic, "Depth", _spin(3, 40, r["d"], suffix=" cells",
                                                      tip="Across z, walls included - a cell "
                                                          "is 2 m"))
        doors = QWidget()
        grid = QGridLayout(doors)
        grid.setContentsMargins(0, 2, 0, 2)
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(0)
        self.doors = {}
        for side, row, col in DOOR_LAYOUT:
            cb = QCheckBox(rooms.SIDE_WORDS[side].split()[0])
            cb.setChecked(side in r["doors"])
            cb.setToolTip("A door in the middle of the %s wall" % rooms.SIDE_WORDS[side])
            grid.addWidget(cb, row, col)
            self.doors[side] = cb
            self.fields.append(cb)
        self.basic.addRow("Doors", doors)
        self.h = self.add(self.more, "Height", _spin(200, 3000, r["h"], 50, suffix=" cm",
                                                     tip="Wall height in cm (Mario is 160 "
                                                         "tall)"))
        self.ceiling = self.add(self.more, "Ceiling", QCheckBox("a roof slab over it"))
        self.ceiling.setChecked(r["ceiling"])
    def values(self):
        return {"w": self.w.value(), "d": self.d.value(), "h": self.h.value(),
                "doors": [s for s, cb in self.doors.items() if cb.isChecked()],
                "ceiling": self.ceiling.isChecked()}
    def change(self, v):
        s = self.session
        return rooms.room_at(s.doc, s.cursor, v["w"], v["d"], v["h"], v["doors"], v["ceiling"],
                             s.texture, s.texture2)[0]
    def run(self, v):
        return self.session.build_room(**v)
class CorridorDialog(BuildDialog):
    title = "Corridor from A to B"
    intro = ("A corridor between the two things you selected (or the points below), walls on "
             "both sides. Pick how it runs; tick a door to close an end with a doorway.")
    def build_form(self):
        c = self.session.corridor
        a, b = self.session.corridor_ends()
        self.shape = self.add(self.basic, "Runs", _combo(
            [kv for kv in rooms.SHAPES if kv[0] != "path"],
            c.get("shape") if c.get("shape") != "path" else "xz",
            tip="Straight from A, or one turn: along x first or along z first"))
        self.width = self.add(self.basic, "Width", _spin(1, 8, c["width"], suffix=" cells",
                                                         tip="Floor cells across"))
        ends = QWidget()
        row = QGridLayout(ends)
        row.setContentsMargins(0, 2, 0, 2)
        row.setHorizontalSpacing(14)
        self.doors = {}
        for col, (end, words) in enumerate((("a", "at A"), ("b", "at B"))):
            cb = QCheckBox(words)
            cb.setChecked(end in (c.get("doors") or ()))
            cb.setToolTip("Close the %s end with a wall that has a door in it (unticked: the "
                          "end stays open)" % end.upper())
            row.addWidget(cb, 0, col)
            self.doors[end] = cb
            self.fields.append(cb)
        self.basic.addRow("Doors", ends)
        path = QPushButton("Click the path in a view instead...")
        path.setToolTip("Ctrl+Alt+Shift+C - click where the corridor goes, point by point; a "
                        "ghost shows it as you click, Enter builds it")
        path.clicked.connect(self.click_path)
        self.basic.addRow("", path)
        self.ax = self.add(self.more, "A x", _spin(-60000, 60000, a[0], 200))
        self.az = self.add(self.more, "A z", _spin(-60000, 60000, a[2], 200))
        self.ay = self.add(self.more, "Floor height", _spin(-20000, 20000, a[1], 50))
        self.bx = self.add(self.more, "B x", _spin(-60000, 60000, b[0], 200))
        self.bz = self.add(self.more, "B z", _spin(-60000, 60000, b[2], 200))
        self.h = self.add(self.more, "Height", _spin(200, 3000, c["h"], 50))
        self.ceiling = self.add(self.more, "Ceiling", QCheckBox("roofed"))
        self.ceiling.setChecked(c["ceiling"])
        self.b_y = b[1]
    def values(self):
        return {"a": (self.ax.value(), self.ay.value(), self.az.value()),
                "b": (self.bx.value(), self.b_y, self.bz.value()),
                "width": self.width.value(), "h": self.h.value(),
                "ceiling": self.ceiling.isChecked(), "shape": self.shape.currentData(),
                "doors": [e for e, cb in self.doors.items() if cb.isChecked()]}
    def change(self, v):
        s = self.session
        return rooms.corridor(s.doc, v["a"], v["b"], v["width"], v["h"], v["ceiling"],
                              s.texture, s.texture2, shape=v["shape"],
                              doors=tuple(v["doors"]))[0]
    def click_path(self):
        v = self.values()
        for k in ("width", "h", "ceiling", "doors"):
            self.session.corridor[k] = v[k]
        self.ed.sync.clear_ghost()
        self.reject()
        self.ed.run_action("build.corridor_path")
    def run(self, v):
        v = dict(v)
        return self.session.build_corridor(v.pop("a"), v.pop("b"), **v)
class StairsDialog(BuildDialog):
    title = "Stairs between floors"
    intro = ("Flights of stairs from the mouse up to the next floor, a landing between "
             "flights, solid underneath.")
    def build_form(self):
        st = self.session.stairs
        self.rise = self.add(self.basic, "Up by", _spin(-3000, 3000, st["rise"], 50,
                                                        tip="How much higher the next floor is "
                                                            "(minus: down)"))
        self.dir = self.add(self.basic, "Towards", _combo(DIRECTION_WORDS, st["direction"]))
        self.width = self.add(self.more, "Width", _spin(1, 8, st["width"], suffix=" cells"))
    def values(self):
        return {"rise": self.rise.value(), "direction": self.dir.currentData(),
                "width": self.width.value()}
    def change(self, v):
        s = self.session
        start = tuple(s.cursor)
        return rooms.stairs(s.doc, start, start[1] + v["rise"], v["direction"], v["width"],
                            s.texture)[0]
    def run(self, v):
        return self.session.build_stairs(**v)
class ClipDialog(BuildDialog):
    title = "Clip boxes by a plane"
    intro = "Cut the selected boxes in two along a line. Keep both halves, or only one side."
    def build_form(self):
        c = self.session.clip
        self.axis = self.add(self.basic, "Across", _combo(
            (("x", "x (left / right)"), ("z", "z (front / back)"), ("y", "y (a height)")),
            c["axis"]))
        self.keep = self.add(self.basic, "Keep", _combo(
            (("both", "both halves"), ("low", "the low side"), ("high", "the high side")),
            c["keep"]))
        refs = self.session.refs()
        self.at = self.add(self.more, "At", _spin(-60000, 60000, csg.plane_default(
            self.session.doc, refs, c["axis"]), 50, tip="Where the line is (the middle of the "
                                                         "selection to start with)"))
        self.axis.currentIndexChanged.connect(self._axis_changed)
    def _axis_changed(self, *_):
        self.at.blockSignals(True)
        self.at.setValue(int(csg.plane_default(self.session.doc, self.session.refs(),
                                               self.axis.currentData())))
        self.at.blockSignals(False)
        self.preview()
    def values(self):
        return {"axis": self.axis.currentData(), "at": self.at.value(),
                "keep": self.keep.currentData()}
    def change(self, v):
        return csg.clip(self.session.doc, self.session.refs(), v["axis"], v["at"], v["keep"])
    def run(self, v):
        self.session.clip.update(v)
        return self.session.do("build.clip")
DIALOGS = {"build.room": RoomDialog, "build.corridor": CorridorDialog,
           "build.stairs": StairsDialog, "build.clip": ClipDialog}
def open_dialog(ed, aid):
    if aid == "build.clip" and not [r for r in ed.session.refs() if r[0] == "piece"]:
        msg = ed.session.need_selection()
        ed.after_change(msg)
        return None
    dlg = DIALOGS[aid](ed)
    dlg.show()
    dlg.raise_()
    dlg.activateWindow()
    ed._build_dialog = dlg
    return dlg
__all__ = ["DIALOGS", "open_dialog", "geo", "Qt"]
