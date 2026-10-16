import os
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor, QGuiApplication, QIcon
from PySide6.QtWidgets import (QAbstractItemView, QCheckBox, QComboBox, QDialog, QFileDialog,
                               QFormLayout, QFrame, QGridLayout, QHBoxLayout, QHeaderView,
                               QInputDialog, QLabel, QLineEdit, QListWidget, QListWidgetItem,
                               QMessageBox, QPlainTextEdit, QPushButton, QScrollArea,
                               QSplitter, QTableWidget, QTableWidgetItem, QTabWidget,
                               QToolButton, QVBoxLayout, QWidget)
from .. import kb, texman
from . import common
CHECK_NAMES = (("size", "Size"), ("opaque", "Opaque"), ("seams", "Seams"),
               ("duplicate", "New picture"), ("key", "Name free"))
def tile_colour(item):
    img = item.result.get("img") if item.result else None
    if img is None:
        return QColor("#8a8f98")
    r, g, b, _ = img.convert("RGBA").resize((1, 1)).getpixel((0, 0))
    return QColor(r, g, b)
def tile_png(item):
    img = item.result.get("img") if item.result else None
    return texman.kit().png_bytes(img) if img is not None else None
class ShapeGrid(QWidget):
    changed = Signal(object)
    def __init__(self, colour=None, parent=None):
        super().__init__(parent)
        self.chosen = set()
        self.colour = QColor(colour or "#b08a5a")
        self.buttons = {}
        self.family_buttons = {}
        grid = QGridLayout(self)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(4)
        grid.setVerticalSpacing(4)
        for row, (family, tags) in enumerate(texman.families()):
            fb = QToolButton()
            fb.setText(family)
            fb.setCheckable(True)
            fb.setMinimumWidth(92)
            fb.setToolTip("%s (%s): click to give this texture every shape of the family, "
                          "again to take them all away" % (family,
                                                            texman.FAMILY_GERMAN.get(family, "")))
            fb.clicked.connect(lambda on, f=family: self._family(f, on))
            grid.addWidget(fb, row, 0)
            self.family_buttons[family] = fb
            for col, tag in enumerate(tags):
                b = QToolButton()
                b.setCheckable(True)
                b.setToolButtonStyle(Qt.ToolButtonIconOnly)
                b.setFixedSize(46, 46)
                tw = texman.twin(tag)
                b.setToolTip("%s%s" % (texman.SHAPE_LABELS.get(tag, tag),
                                       " - and upside down" if tw else ""))
                if tag == "cube":
                    b.setChecked(True)
                    b.setEnabled(False)
                    b.setToolTip("Cube - every texture is a cube")
                b.clicked.connect(lambda on, t=tag: self._shape(t, on))
                grid.addWidget(b, row, col + 1)
                self.buttons[tag] = b
        width = max(len(tags) for _, tags in texman.families()) + 1
        grid.setColumnStretch(width, 1)
        self.setStyleSheet("QToolButton { background: transparent; border: 1px solid "
                           "transparent; border-radius: 6px; } QToolButton:hover { border-color: "
                           "#62666c; } QToolButton:checked { background: #2e3a55; border-color: "
                           "#5b8cff; }")
        self.paint_icons()
    def paint_icons(self):
        from PySide6.QtCore import QSize
        for tag, b in self.buttons.items():
            b.setIcon(QIcon(common.shape_pixmap(tag, self.colour, 40)))
            b.setIconSize(QSize(40, 40))
    def set_colour(self, colour):
        self.colour = QColor(colour)
        self.paint_icons()
    def set_chosen(self, chosen):
        self.chosen = set(chosen)
        for tag, b in self.buttons.items():
            if tag != "cube":
                b.setChecked(tag in self.chosen)
        for family, fb in self.family_buttons.items():
            state = texman.family_state(self.chosen, family)
            fb.setChecked(state == "all")
            fb.setProperty("some", state == "some")
            fb.setText(family + (" ~" if state == "some" else ""))
    def _family(self, family, on):
        self.set_chosen(texman.toggle_family(self.chosen, family, on))
        self.changed.emit(set(self.chosen))
    def _shape(self, tag, on):
        out = set(self.chosen)
        for t in (tag, texman.twin(tag)):
            if t:
                (out.add if on else out.discard)(t)
        self.set_chosen(out)
        self.changed.emit(set(self.chosen))
class DropZone(QFrame):
    dropped = Signal(list)
    def __init__(self, text):
        super().__init__()
        self.setObjectName("card")
        self.setAcceptDrops(True)
        lay = QVBoxLayout(self)
        self.label = QLabel(text)
        self.label.setAlignment(Qt.AlignCenter)
        self.label.setWordWrap(True)
        lay.addWidget(self.label)
    def dragEnterEvent(self, ev):
        if ev.mimeData().hasUrls():
            ev.acceptProposedAction()
    def dropEvent(self, ev):
        paths = [u.toLocalFile() for u in ev.mimeData().urls() if u.isLocalFile()]
        if paths:
            self.dropped.emit(paths)
            ev.acceptProposedAction()
class ItemRow(QWidget):
    def __init__(self, panel, item):
        super().__init__()
        self.panel = panel
        self.item = item
        tok = panel.tok
        lay = QHBoxLayout(self)
        lay.setContentsMargins(6, 4, 6, 4)
        pic = QLabel()
        png = tile_png(item)
        if png:
            pic.setPixmap(common.tiled_pixmap(png, 56, 2))
        else:
            pic.setText("?")
        pic.setFixedSize(58, 58)
        pic.setToolTip("Four copies side by side: a seam shows where they meet")
        lay.addWidget(pic)
        col = QVBoxLayout()
        name = (item.result or {}).get("name") or os.path.basename(item.path)
        title = QLabel("<b>%s</b>  <span style='color:%s'>%s - %s</span>" % (
            name, tok["text_dim"], item.shelf, os.path.basename(item.path)))
        col.addWidget(title)
        chips = QHBoxLayout()
        levels = item.levels()
        said = {}
        for check, level, text in (item.result or {}).get("checks", []):
            said.setdefault(check, []).append(text)
        for check, label in CHECK_NAMES:
            if check in levels:
                chips.addWidget(common.chip(label, levels[check], tok,
                                            "\n".join(said.get(check, []))))
        if item.skip:
            chips.addWidget(common.chip("left out", "note", tok))
        chips.addStretch(1)
        col.addLayout(chips)
        if item.result and item.result.get("refusal") and not item.skip:
            why = QLabel(item.result["refusal"])
            why.setObjectName("caption")
            why.setWordWrap(True)
            col.addWidget(why)
        lay.addLayout(col, 1)
        fixes = QHBoxLayout()
        col.addLayout(fixes)
        for fix, label in item.fixes():
            b = QPushButton(label)
            b.setToolTip({"seamless": "Blend the edges with the middle so the tile runs on "
                                      "across the wrap (kit.make_seamless)",
                          "allow_seams": "Import it with its seams (a wall of it shows a grid)",
                          "rename": "A new name gives it a new key",
                          "skip": "Do not import this picture"}.get(fix, label))
            b.clicked.connect(lambda _=False, f=fix: panel.fix(item, f))
            fixes.addWidget(b)
        fixes.addStretch(1)
class ImportTab(QWidget):
    def __init__(self, mgr):
        super().__init__()
        self.mgr = mgr
        self.tok = mgr.tok
        self.inbox = texman.Inbox()
        self.costs = None
        outer = QVBoxLayout(self)
        outer.setContentsMargins(10, 10, 10, 10)
        outer.setSpacing(8)
        top = QHBoxLayout()
        self.zone = DropZone("<b>Drop pictures or a folder here</b><br>"
                             "PNG, square: 32x32 is taken as it is, bigger is scaled down. "
                             "Sub-folders named after a shelf (Stone, Wood...) put their "
                             "pictures there.")
        self.zone.dropped.connect(self.add)
        self.zone.setMinimumHeight(64)
        self.zone.setMaximumHeight(96)
        top.addWidget(self.zone, 1)
        col = QVBoxLayout()
        pick = QPushButton("Choose a folder...")
        pick.setObjectName("primary")
        pick.setToolTip("Every PNG in it (and in its shelf-named sub-folders)")
        pick.clicked.connect(self.choose_folder)
        files = QPushButton("Add pictures...")
        files.clicked.connect(self.choose_files)
        self.shelf = QComboBox()
        self.shelf.addItems(texman.shelves())
        self.shelf.setCurrentText("Blocks")
        self.shelf.setToolTip("The shelf new pictures go on (a shelf-named sub-folder wins)")
        clear = QPushButton("Clear")
        clear.clicked.connect(self.clear)
        col.addWidget(pick)
        col.addWidget(files)
        srow = QHBoxLayout()
        srow.addWidget(QLabel("Shelf:"))
        srow.addWidget(self.shelf, 1)
        col.addLayout(srow)
        col.addWidget(clear)
        top.addLayout(col)
        outer.addLayout(top)
        split = QSplitter(Qt.Horizontal)
        self.list = QListWidget()
        self.list.setSelectionMode(QAbstractItemView.SingleSelection)
        self.list.currentRowChanged.connect(self.show_item)
        self.empty = common.empty_state("No pictures yet",
                                        "Drop a folder of textures above - every check shows "
                                        "here before anything is written.")
        left = QWidget()
        ll = QVBoxLayout(left)
        ll.setContentsMargins(0, 0, 0, 0)
        ll.addWidget(self.empty)
        ll.addWidget(self.list)
        split.addWidget(left)
        right = QScrollArea()
        right.setWidgetResizable(True)
        right.setFrameShape(QFrame.NoFrame)
        body = QWidget()
        right.setWidget(body)
        rl = QVBoxLayout(body)
        rl.setContentsMargins(8, 0, 0, 0)
        self.big = QLabel()
        self.big.setFixedSize(198, 198)
        self.big.setToolTip("Nine copies: what a wall of it looks like")
        head = QHBoxLayout()
        head.addWidget(self.big)
        form = QFormLayout()
        self.name = QLineEdit()
        self.name.setPlaceholderText("from the file name")
        self.name.setToolTip("The name the Forge's menu draws; its letters are the key")
        self.name.editingFinished.connect(self._renamed)
        self.item_shelf = QComboBox()
        self.item_shelf.addItems(texman.shelves())
        self.item_shelf.activated.connect(self._reshelved)
        form.addRow("Name", self.name)
        form.addRow("Shelf", self.item_shelf)
        self.roles = {}
        roles_w = QWidget()
        rg = QGridLayout(roles_w)
        rg.setContentsMargins(0, 0, 0, 0)
        for i, (role, help_) in enumerate(texman.ROLE_HELP.items()):
            cb = QCheckBox(role)
            cb.setToolTip("The map generator may use it for %s" % help_)
            cb.toggled.connect(self._roles)
            rg.addWidget(cb, i // 2, i % 2)
            self.roles[role] = cb
        form.addRow("Roles", roles_w)
        self.item_cost = QLabel()
        form.addRow("Costs", self.item_cost)
        head.addLayout(form, 1)
        rl.addLayout(head)
        shapes_said = QLabel("<b>Which shapes this texture comes in</b> - the Forge's wheel "
                             "(Blocks, Ramps, Wedges, Stairs, Walls, Fences, Columns, Openings)")
        shapes_said.setWordWrap(True)
        rl.addWidget(shapes_said)
        self.grid = ShapeGrid()
        self.grid.changed.connect(self._shapes)
        rl.addWidget(self.grid)
        row = QHBoxLayout()
        all_ = QPushButton("These shapes for every picture")
        all_.setToolTip("Give every picture in the list the shapes chosen here")
        all_.clicked.connect(self._shapes_for_all)
        default = QPushButton("The shelf's defaults")
        default.setToolTip("What the tool picks for this shelf when nobody chooses")
        default.clicked.connect(self._default_shapes)
        row.addWidget(all_)
        row.addWidget(default)
        row.addStretch(1)
        rl.addLayout(row)
        rl.addStretch(1)
        self.detail = body
        split.addWidget(right)
        split.setChildrenCollapsible(False)
        split.setStretchFactor(0, 1)
        split.setStretchFactor(1, 2)
        split.setSizes([360, 780])
        outer.addWidget(split, 1)
        bottom = QHBoxLayout()
        self.meter = QLabel()
        self.meter.setToolTip("Every picture is downloaded by every player who joins")
        bottom.addWidget(self.meter, 1)
        self.go = QPushButton("Import")
        self.go.setObjectName("primary")
        self.go.setToolTip("Write the tiles and the manifest rows, build the blocks and shapes, "
                           "run both checks")
        self.go.clicked.connect(self.run)
        bottom.addWidget(self.go)
        outer.addLayout(bottom)
        self.said = QLabel()
        self.said.setWordWrap(True)
        self.said.setObjectName("caption")
        self.said.setTextInteractionFlags(Qt.TextSelectableByMouse)
        outer.addWidget(self.said)
        self.refresh()
    def choose_folder(self):
        d = QFileDialog.getExistingDirectory(self, "A folder of textures",
                                             self.mgr.remember("dir", os.path.expanduser("~")))
        if d:
            self.mgr.remember("dir", os.path.dirname(d), True)
            self.add([d])
    def choose_files(self):
        paths, _ = QFileDialog.getOpenFileNames(self, "Pictures", self.mgr.remember(
            "dir", os.path.expanduser("~")), "PNG pictures (*.png)")
        if paths:
            self.mgr.remember("dir", os.path.dirname(paths[0]), True)
            self.add(paths)
    def add(self, paths):
        self.inbox.faults = []
        self.inbox.add(paths, self.shelf.currentText())
        if self.inbox.faults:
            self.said.setText("Not read: " + "; ".join(self.inbox.faults))
        self.refresh()
        if self.list.count() and self.list.currentRow() < 0:
            self.list.setCurrentRow(0)
    def clear(self):
        self.inbox = texman.Inbox()
        self.refresh()
    def fix(self, item, fix):
        value = None
        if fix == "rename":
            value, ok = QInputDialog.getText(self, "Another name", "The block's name:",
                                             text=(item.result or {}).get("name") or "")
            if not ok or not value.strip():
                return
            value = value.strip()
        self.inbox.fix(item, fix, value)
        self.refresh()
    def refresh(self):
        row = self.list.currentRow()
        self.list.clear()
        for item in self.inbox.items:
            li = QListWidgetItem()
            w = ItemRow(self, item)
            li.setSizeHint(w.sizeHint())
            self.list.addItem(li)
            self.list.setItemWidget(li, w)
        has = bool(self.inbox.items)
        self.list.setVisible(has)
        self.empty.setVisible(not has)
        self.detail.setEnabled(has)
        if has:
            self.list.setCurrentRow(max(0, min(row, self.list.count() - 1)))
        self.update_meter()
    def current(self):
        r = self.list.currentRow()
        return self.inbox.items[r] if 0 <= r < len(self.inbox.items) else None
    def show_item(self, *_):
        item = self.current()
        if item is None:
            return
        png = tile_png(item)
        if png:
            self.big.setPixmap(common.tiled_pixmap(png, 198, 3))
        else:
            self.big.clear()
            self.big.setText("no picture")
        self.name.setText((item.result or {}).get("name") or "")
        self.item_shelf.setCurrentText(item.shelf)
        for role, cb in self.roles.items():
            cb.blockSignals(True)
            cb.setChecked(role in item.roles)
            cb.blockSignals(False)
        self.grid.set_colour(tile_colour(item))
        self.grid.set_chosen(item.chosen())
        self._item_cost(item)
    def _item_cost(self, item):
        self.costs = self.costs or texman.shape_costs()
        n = len([t for t in item.chosen() if t != "cube"])
        self.item_cost.setText("%s per joiner: the cube and %d shape pictures" % (
            kb(texman.estimate(item.chosen(), self.costs)), n))
    def update_meter(self):
        self.costs = self.costs or texman.shape_costs()
        ready, refused = self.inbox.ready(), self.inbox.refused()
        total = texman.meter()["total"]
        add = self.inbox.estimate(self.costs)
        self.meter.setText("<b>%d ready</b>, %d refused - this import adds about <b>%s</b> to "
                           "every joiner's download (blocks and shapes now %s, then %s)" % (
                               len(ready), len(refused), kb(add), kb(total), kb(total + add)))
        self.go.setEnabled(bool(ready))
    def _renamed(self):
        item = self.current()
        text = self.name.text().strip()
        if item is None or not text or text == (item.result or {}).get("name"):
            return
        self.inbox.fix(item, "rename", text)
        self.refresh()
    def _reshelved(self, *_):
        item = self.current()
        if item is not None and item.shelf != self.item_shelf.currentText():
            had_default = item.shapes is None
            self.inbox.fix(item, "shelf", self.item_shelf.currentText())
            if had_default:
                item.shapes = None
            self.refresh()
    def _roles(self, *_):
        item = self.current()
        if item is not None:
            item.roles = [r for r, cb in self.roles.items() if cb.isChecked()]
    def _shapes(self, chosen):
        item = self.current()
        if item is not None:
            item.shapes = set(chosen)
            self._item_cost(item)
            self.update_meter()
    def _shapes_for_all(self):
        chosen = set(self.grid.chosen)
        for item in self.inbox.items:
            item.shapes = set(chosen)
        self.update_meter()
        self.mgr.hint("Every picture comes in the same %d shapes" % len(chosen))
    def _default_shapes(self):
        item = self.current()
        if item is not None:
            item.shapes = None
            self.grid.set_chosen(item.chosen())
            self._item_cost(item)
            self.update_meter()
    def run(self):
        refused = self.inbox.refused()
        if refused and QMessageBox.question(
                self, "Import?", "%d picture(s) are refused and stay out. Import the %d ready "
                "one(s)?" % (len(refused), len(self.inbox.ready()))) != QMessageBox.Yes:
            return
        inbox = self.inbox
        self.go.setEnabled(False)
        self.said.setText("Importing: writing the tiles and rows, building blocks and shapes, "
                          "checking both...")
        def job(progress, cancelled):
            progress(0, 0, "make-blocks, make-forgeslopes and their checks")
            return texman.import_now(inbox)
        def done(res):
            added, said = res
            self.said.setText(said + "\n\n" + texman.AFTER)
            self.inbox = texman.Inbox()
            self.costs = None
            self.refresh()
            self.mgr.after_change("Imported - the palette has the new blocks")
        def failed(reason):
            self.said.setText("Not imported: %s" % reason)
            self.update_meter()
        self.mgr.run_job("Importing textures", job, done, failed)
class BlocksTab(QWidget):
    COLS = ("", "Name", "Key", "Shelf", "Shapes", "Download", "Used by")
    def __init__(self, mgr):
        super().__init__()
        self.mgr = mgr
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        self.filter = QLineEdit()
        self.filter.setPlaceholderText("Search: name, key, shelf...")
        self.filter.setClearButtonEnabled(True)
        self.filter.textChanged.connect(self.fill)
        lay.addWidget(self.filter)
        self.table = QTableWidget(0, len(self.COLS))
        self.table.setHorizontalHeaderLabels(self.COLS)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.verticalHeader().setVisible(False)
        self.table.horizontalHeader().setSectionResizeMode(6, QHeaderView.Stretch)
        self.table.setSortingEnabled(True)
        self.table.activated.connect(lambda *_: self.apply())
        self.table.setContextMenuPolicy(Qt.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self._menu)
        from studio.ui import keyguard
        keyguard.list_keys(self.table, {Qt.Key_F2: self.rename, Qt.Key_Delete: self.remove})
        lay.addWidget(self.table, 1)
        row = QHBoxLayout()
        for label, tip, fn in (
                ("Rename...", "A new name - its key follows, and prefabs, the game's Forge "
                 "saves and your maps are re-coded so nothing breaks", self.rename),
                ("Shapes...", "Which shapes this texture comes in", self.shapes),
                ("Remove...", "Take it out: its keys are retired, saved bars load another block "
                 "or nothing", self.remove),
                ("Rebuild", "Run make-blocks and make-forgeslopes and their checks", self.rebuild)):
            b = QPushButton(label)
            b.setToolTip(tip)
            b.clicked.connect(fn)
            row.addWidget(b)
        row.addStretch(1)
        copy = QPushButton("Copy the rebuild line")
        copy.setToolTip(texman.REBUILD)
        copy.clicked.connect(lambda: QGuiApplication.clipboard().setText(texman.REBUILD))
        row.addWidget(copy)
        lay.addLayout(row)
        self.said = QLabel()
        self.said.setObjectName("caption")
        self.said.setWordWrap(True)
        self.said.setTextInteractionFlags(Qt.TextSelectableByMouse)
        lay.addWidget(self.said)
        self.rows = []
    def fill(self, *_):
        from studio.editor.palette import _fold
        if not self.rows:
            self.rows = texman.blocks()
        words = [_fold(w) for w in self.filter.text().split()]
        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)
        for r in self.rows:
            hay = _fold(" ".join([r["name"], r["key"], r["shelf"], r.get("family", ""),
                                  r.get("soft64", "")]))
            if not all(w in hay for w in words):
                continue
            n = self.table.rowCount()
            self.table.insertRow(n)
            sw = QTableWidgetItem()
            try:
                from studio.editor.qt.widgets import swatch_pixmap
                sw.setIcon(QIcon(swatch_pixmap(r["key"], 28)))
            except Exception:
                pass
            vals = [sw, QTableWidgetItem(r["name"]), QTableWidgetItem(r["key"]),
                    QTableWidgetItem(r["shelf"] + (" (%s)" % r["family"]
                                                   if r.get("family") and r["family"] != r["shelf"]
                                                   else ""))]
            shapes = QTableWidgetItem()
            shapes.setData(Qt.DisplayRole, len([t for t in r["shapes"] if not t.startswith("u")]))
            size = QTableWidgetItem()
            size.setData(Qt.DisplayRole, round(r["bytes"] / 1024.0, 1))
            size.setToolTip("%s in %d pictures" % (kb(r["bytes"]), r["pictures"]))
            used = QTableWidgetItem("; ".join(r["used_by"]) or "-")
            used.setToolTip("\n".join(r["used_by"]) or "nothing names it: it can go freely")
            for col, it in enumerate(vals + [shapes, size, used]):
                it.setData(Qt.UserRole, r["key"])
                self.table.setItem(n, col, it)
        self.table.setSortingEnabled(True)
        self.table.resizeColumnsToContents()
    def reload(self):
        self.rows = texman.blocks()
        self.fill()
    def apply(self):
        r = self.selected()
        if r is None:
            return None
        ed = self.mgr.lib.ed
        ed.set_texture(r["key"])
        if any(ref[0] == "piece" for ref in ed.session.refs()):
            ed.run_action("edit.paint")
        self.said.setText("%s is the current texture" % r["name"])
        return r["key"]
    def _menu(self, pos):
        from PySide6.QtWidgets import QMenu
        if self.table.itemAt(pos) is None:
            return
        m = QMenu(self)
        acts = [(m.addAction("Use and paint the selection  (double-click, Enter)"), self.apply),
                (m.addAction("Shapes..."), self.shapes),
                (m.addAction("Rename...  (F2)"), self.rename),
                (m.addAction("Remove...  (Delete)"), self.remove)]
        got = m.exec(self.table.viewport().mapToGlobal(pos))
        for a, fn in acts:
            if got is a:
                fn()
    def selected(self):
        items = self.table.selectedItems()
        if not items:
            self.said.setText("Pick a block in the list first")
            return None
        key = items[0].data(Qt.UserRole)
        return next((r for r in self.rows if r["key"] == key), None)
    def _kit(self, label, fn, after=None):
        def job(progress, cancelled):
            progress(0, 0, label)
            return fn()
        def done(res):
            code, text = res if isinstance(res, tuple) else (0, str(res))
            self.said.setText(("" if code == 0 else "Refused: ") + text)
            if code == 0:
                self.mgr.after_change(label)
                if after is not None:
                    after()
        self.mgr.run_job(label, job, done, lambda why: self.said.setText("Refused: %s" % why))
    def rename(self):
        r = self.selected()
        if r is None:
            return
        name, ok = QInputDialog.getText(self, "Rename", "The new name for %s:" % r["name"],
                                        text=r["name"])
        if not ok or not name.strip() or name.strip() == r["name"]:
            return
        self.rename_to(r, name.strip())
    def studio_maps(self):
        st = self.mgr.lib.studio
        paths = list(getattr(st.settings, "recent", []) or [])
        here = self.mgr.lib.ed.session.doc.meta.get("path")
        if here:
            paths.insert(0, here)
        out = []
        for p in paths:
            if p and p.endswith(".ofmap") and os.path.isfile(p) and p not in out:
                out.append(p)
        return out
    def rename_to(self, r, name, ask=True):
        also = self.studio_maps()
        plan = texman.rename_plan(r["key"], name, also)
        new_key, warning = texman.rename_choice(plan)
        self.last_warning = warning
        if warning and ask:
            if QMessageBox.warning(self, "The key stays", warning,
                                   QMessageBox.Ok | QMessageBox.Cancel) != QMessageBox.Ok:
                return None
        after = self._recode_open_map if new_key else None
        self._kit("Rename %s" % r["key"], lambda: texman.rename(
            r["key"], name, new_key, also), after=after)
        return plan
    def _recode_open_map(self):
        from studio.editor import document
        ed = self.mgr.lib.ed
        change = texman.recode_change(ed.session.doc, document.old_keys())
        if change is not None:
            ed.session.push(change)
    def shapes(self):
        r = self.selected()
        if r is None:
            return
        dlg = QDialog(self)
        dlg.setWindowTitle("Shapes of %s" % r["name"])
        lay = QVBoxLayout(dlg)
        colour = QColor("#8a8f98")
        try:
            from studio.editor.qt.widgets import average_colour
            colour = average_colour(r["key"])
        except Exception:
            pass
        grid = ShapeGrid(colour)
        grid.set_chosen(r["shapes"])
        if r["layered"]:
            lay.addWidget(QLabel("A transition block comes only in the ground shapes."))
        lay.addWidget(grid)
        cost = QLabel()
        lay.addWidget(cost)
        costs = texman.shape_costs()
        grid.changed.connect(lambda c: cost.setText("%s per joiner (now %s)" % (
            kb(texman.estimate(c, costs)), kb(r["bytes"]))))
        grid.changed.emit(set(r["shapes"]))
        row = QHBoxLayout()
        ok = QPushButton("Build these shapes")
        ok.setObjectName("primary")
        ok.clicked.connect(dlg.accept)
        no = QPushButton("Cancel")
        no.clicked.connect(dlg.reject)
        row.addStretch(1)
        row.addWidget(no)
        row.addWidget(ok)
        lay.addLayout(row)
        if dlg.exec() == QDialog.Accepted:
            chosen = set(grid.chosen)
            self._kit("Shapes of %s" % r["key"], lambda: texman.set_shapes(
                r["key"], chosen, r["shelf"]))
    def remove(self):
        r = self.selected()
        if r is None:
            return
        others = ["(nothing - a saved bar's slot loads empty)"] + [
            "%s (%s)" % (o["name"], o["key"]) for o in self.rows if o["key"] != r["key"]]
        into, ok = QInputDialog.getItem(
            self, "Remove %s" % r["name"], "Its keys are retired. Saved bars that hold it load:"
            + ("\n\nNamed by: %s - removing it anyway makes those red in their own checks."
               % "; ".join(r["used_by"]) if r["used_by"] else ""), others, 0, False)
        if not ok:
            return
        into_key = None if into.startswith("(") else into.rsplit("(", 1)[1].rstrip(")")
        force = bool(r["used_by"])
        if force and QMessageBox.warning(
                self, "Remove a used block?", "%s is used by %s. Remove it anyway?" % (
                    r["name"], "; ".join(r["used_by"])),
                QMessageBox.Yes | QMessageBox.No) != QMessageBox.Yes:
            return
        def remove():
            from .. import trash
            k = texman.kit()
            trash.keep("texture", "Block %s" % r["name"], [k.blocks.MANIFEST, k.RETIRED])
            return texman.remove(r["key"], into_key, force)
        self._kit("Remove %s" % r["key"], remove)
    def rebuild(self):
        def fn():
            ok, text = texman.rebuild()
            return (0 if ok else 1), text
        self._kit("Rebuild the blocks", fn)
class SizeTab(QWidget):
    def __init__(self, mgr):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        self.total = QLabel()
        lay.addWidget(self.total)
        split = QSplitter(Qt.Horizontal)
        self.by_tex = QTableWidget(0, 3)
        self.by_tex.setHorizontalHeaderLabels(("Texture", "Pictures", "KB"))
        self.by_shape = QTableWidget(0, 3)
        self.by_shape.setHorizontalHeaderLabels(("Shape", "Textures", "KB"))
        for t in (self.by_tex, self.by_shape):
            t.verticalHeader().setVisible(False)
            t.setEditTriggers(QAbstractItemView.NoEditTriggers)
            t.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
            split.addWidget(t)
        lay.addWidget(split, 1)
        note = QLabel("Fewer shapes per texture is the lever: a picture is about 2-3 KB, and "
                      "every player who joins downloads every one.")
        note.setObjectName("caption")
        note.setWordWrap(True)
        lay.addWidget(note)
    def fill(self):
        m = texman.meter()
        sizes = texman.kit().actor_sizes()
        self.total.setText("<b>Blocks and shapes: %s</b> - added to every joiner's download "
                           "(%d textures)" % (kb(m["total"]), len(m["by_texture"])))
        for table, rows in ((self.by_tex, sorted(m["by_texture"].items(), key=lambda kv: -kv[1])),
                            (self.by_shape, sorted(m["by_shape"].items(),
                                                   key=lambda kv: -kv[1][1]))):
            table.setSortingEnabled(False)
            table.setRowCount(0)
            for name, val in rows:
                n = table.rowCount()
                table.insertRow(n)
                if table is self.by_tex:
                    count, size = len(sizes.get(name, {})), val
                    label = name
                else:
                    count, size = val
                    base = name[1:] if name.startswith("u") and name[1:] in \
                        texman.SHAPE_LABELS else name
                    label = texman.SHAPE_LABELS.get(base, name) + (
                        " (upside down)" if base != name else "")
                a = QTableWidgetItem(label)
                b = QTableWidgetItem()
                b.setData(Qt.DisplayRole, count)
                c = QTableWidgetItem()
                c.setData(Qt.DisplayRole, round(size / 1024.0, 1))
                for col, it in enumerate((a, b, c)):
                    table.setItem(n, col, it)
            table.setSortingEnabled(True)
class TextureManager(QDialog):
    def __init__(self, lib):
        super().__init__(lib.window)
        self.lib = lib
        self.tok = lib.tokens
        self.setWindowTitle("Textures - import, shapes, download size")
        from studio.ui.reflow import fit_to_screen
        fit_to_screen(self, 1180, 760)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        self.tabs = QTabWidget()
        self.importer = ImportTab(self)
        self.blocks = BlocksTab(self)
        self.size = SizeTab(self)
        self.tabs.addTab(self.importer, "Import")
        self.tabs.addTab(self.blocks, "Your blocks")
        self.tabs.addTab(self.size, "Download size")
        self.tabs.currentChanged.connect(self._tab)
        lay.addWidget(self.tabs)
        self.log = QPlainTextEdit()
        self.log.setVisible(False)
    def _tab(self, i):
        if self.tabs.widget(i) is self.blocks and not self.blocks.rows:
            self.blocks.fill()
        elif self.tabs.widget(i) is self.size:
            self.size.fill()
    def remember(self, key, default=None, set_=False):
        if set_:
            self.lib.ed.settings_set("textures." + key, default)
            return default
        return self.lib.ed.settings_get("textures." + key, default)
    def hint(self, text):
        self.lib.ed.hint(text)
    def run_job(self, label, job, done, failed):
        if not self.lib.ed.jobs.run(label, job, done, failed):
            failed("Oldfart Studio is busy with another job - try again in a moment")
    def after_change(self, msg):
        self.lib.reload_textures()
        self.blocks.reload()
        if self.tabs.currentWidget() is self.size:
            self.size.fill()
        self.hint(msg)
