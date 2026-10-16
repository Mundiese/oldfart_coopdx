from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import (QComboBox, QDialog, QHBoxLayout, QLabel, QListView, QListWidget,
                               QListWidgetItem, QPushButton, QSpinBox, QVBoxLayout)
from .. import varietygrid
from . import common
PIC = 200
class VarietyWindow(QDialog):
    def __init__(self, lib):
        super().__init__(lib.window)
        self.lib = lib
        self.ed = lib.ed
        self.grid = varietygrid.Grid()
        self.setWindowTitle("Variety - different good maps for one wish")
        self.resize(1000, 720)
        lay = QVBoxLayout(self)
        row = QHBoxLayout()
        self.go = QPushButton("Find maps")
        self.go.setObjectName("primary")
        self.go.setToolTip("Search for different good maps for the wish panel's wish "
                           "(quality-diversity: open to twisty, flat to vertical)")
        self.go.clicked.connect(self.search)
        self.count = QSpinBox()
        self.count.setRange(2, 16)
        self.count.setValue(9)
        self.count.setToolTip("How many maps")
        self.sort = QComboBox()
        for key, label in varietygrid.SORTS:
            self.sort.addItem(label, key)
        self.sort.setToolTip("Order the grid")
        self.sort.activated.connect(lambda *_: self.fill())
        self.view = QComboBox()
        self.view.addItem("3D", "3d")
        self.view.addItem("Top", "top")
        self.view.setToolTip("3D through Oldfart Studio's renderer, or the generator's top-down plan")
        self.view.activated.connect(lambda *_: self.fill())
        row.addWidget(self.go)
        row.addWidget(self.count)
        row.addStretch(1)
        row.addWidget(QLabel("Order"))
        row.addWidget(self.sort)
        row.addWidget(QLabel("Show"))
        row.addWidget(self.view)
        lay.addLayout(row)
        self.list = QListWidget()
        self.list.setViewMode(QListView.IconMode)
        self.list.setIconSize(QSize(PIC, PIC))
        self.list.setGridSize(QSize(PIC + 20, PIC + 58))
        self.list.setResizeMode(QListView.Adjust)
        self.list.setMovement(QListView.Static)
        self.list.setWordWrap(True)
        self.list.itemActivated.connect(lambda *_: self.open_current())
        self.list.currentItemChanged.connect(self._show)
        self.empty = common.empty_state(
            "No maps yet", "Write a wish in the Wish panel (or leave the controls on auto) "
            "and press Find maps. Each map comes with its report card.")
        lay.addWidget(self.empty)
        lay.addWidget(self.list, 1)
        self.info = QLabel()
        self.info.setObjectName("caption")
        self.info.setWordWrap(True)
        lay.addWidget(self.info)
        row = QHBoxLayout()
        self.pin = QPushButton("Keep in front")
        self.pin.setToolTip("Pin this map to the front of the grid while you compare")
        self.pin.clicked.connect(self._pin)
        self.refine = QPushButton("Refine from this")
        self.refine.setToolTip("Open it and put the cursor in the refine box: say what to "
                               "change, only that changes")
        self.refine.clicked.connect(self.refine_current)
        self.open = QPushButton("Open")
        self.open.setObjectName("primary")
        self.open.setToolTip("Use this map (one undo step back to what you had)")
        self.open.clicked.connect(self.open_current)
        row.addWidget(self.pin)
        row.addStretch(1)
        row.addWidget(self.refine)
        row.addWidget(self.open)
        lay.addLayout(row)
        self.fill()
    def search(self):
        from studio.editor import engine
        if self.ed.jobs.busy():
            self.ed.hint("The engine is still working - wait, or Cancel")
            return
        raw, _ = self.ed.wish_panel.brief()
        count = self.count.value()
        def job(progress, cancelled):
            maps = engine.variety(raw, count=count, children=max(24, 10 * count),
                                  progress=progress, cancel=cancelled)
            cells = []
            for i, m in enumerate(maps):
                progress(i, len(maps), "report card %d of %d" % (i + 1, len(maps)))
                cells.append(varietygrid.Cell.of(m, i).score(engine.card(m.layout, m.brief)))
            return cells
        self.go.setEnabled(False)
        self.info.setText("Searching for %d different maps..." % count)
        self.ed.jobs.run("Searching for %d different maps" % count, job, self.show_cells,
                         self._failed)
    def _failed(self, why):
        self.go.setEnabled(True)
        self.info.setText("No maps: %s" % why)
    def show_cells(self, cells):
        self.go.setEnabled(True)
        self.grid = varietygrid.Grid(cells)
        self.fill()
        spread = self.grid.spread()
        self.info.setText("%d maps. %s" % (len(cells), "; ".join(
            "%s %.2f-%.2f" % (k.replace("_", " "), a, b) for k, (a, b) in spread.items())))
        if self.list.count():
            self.list.setCurrentRow(0)
    def show_generated(self, maps):
        from studio.editor import engine
        cells = [varietygrid.Cell.of(m, i) for i, m in enumerate(maps)]
        def job(progress, cancelled):
            for i, c in enumerate(cells):
                progress(i, len(cells), "report card %d of %d" % (i + 1, len(cells)))
                c.score(engine.card(c.gen.layout, c.gen.brief))
            return cells
        self.show_cells(cells)
        self.lib.ed.measure_jobs.run("Scoring the maps", job, self.show_cells)
    def picture(self, cell):
        if self.view.currentData() == "top":
            from studio.editor.qt.wish_panel import _thumbnail
            return _thumbnail(cell.gen.layout, PIC)
        pieces = (cell.gen.layout or {}).get("pieces", [])
        return self.lib.thumbnailer.picture(("variety", id(cell.gen)), pieces)
    def fill(self):
        self.grid.sort(self.sort.currentData() or "quality")
        self.list.clear()
        for c in self.grid.cells:
            pm = self.picture(c).scaled(PIC, PIC, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            item = QListWidgetItem(QIcon(pm), ("* " if c.pinned else "") + c.summary())
            item.setData(Qt.UserRole, id(c))
            item.setToolTip(c.details())
            self.list.addItem(item)
        has = bool(self.grid.cells)
        self.list.setVisible(has)
        self.empty.setVisible(not has)
        for b in (self.open, self.refine, self.pin):
            b.setEnabled(has)
    def current(self):
        item = self.list.currentItem()
        if item is None:
            return None
        return next((c for c in self.grid.cells if id(c) == item.data(Qt.UserRole)), None)
    def _show(self, *_):
        c = self.current()
        if c is not None:
            self.info.setText(c.details().replace("\n", "  |  "))
    def _pin(self):
        c = self.current()
        if c is not None:
            c.pinned = not c.pinned
            self.fill()
    def open_current(self):
        c = self.current()
        if c is None:
            return None
        if c.gen.brief.get("seed") is not None:
            self.ed.seeds.record(c.gen.brief["seed"], "Variety", c.gen)
        self.ed.apply_generated(c.gen)
        self.ed._keep_seeds()
        self.ed.hint("Opened map %d of the variety - Ctrl+Z goes back" % (c.index + 1))
        return c
    def refine_current(self):
        if self.open_current() is None:
            return
        self.ed.studio.docks.get("wish").raise_()
        self.ed.wish_panel.refine_text.setFocus()
        self.ed.hint("Say what to change - \"bigger centre\", \"move the spawn north\" - "
                     "and press Refine")
