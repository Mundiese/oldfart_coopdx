import os
from PySide6.QtCore import QTimer, QMimeData, QSize, Qt
from PySide6.QtGui import QColor, QDrag, QIcon
from PySide6.QtWidgets import (QComboBox, QDialog, QFileDialog, QFormLayout, QHBoxLayout,
                               QInputDialog, QLabel, QLineEdit, QListView, QListWidget,
                               QListWidgetItem, QMenu, QMessageBox, QPushButton, QTableWidget,
                               QTableWidgetItem, QVBoxLayout, QWidget)
from .. import prefablib
from . import common
MIME = "application/x-oldfart-palette"
THUMB = 112
class Grid(QListWidget):
    def __init__(self, panel):
        super().__init__()
        self.panel = panel
        self.setViewMode(QListView.IconMode)
        self.setIconSize(QSize(THUMB, THUMB))
        self.setGridSize(QSize(THUMB + 24, THUMB + 40))
        self.setResizeMode(QListView.Adjust)
        self.setMovement(QListView.Static)
        self.setWordWrap(True)
        self.setDragEnabled(True)
        self.setSelectionMode(QListWidget.SingleSelection)
        self.setContextMenuPolicy(Qt.CustomContextMenu)
    def startDrag(self, actions):
        item = self.currentItem()
        if item is None:
            return
        mime = QMimeData()
        entry = "prefabs:" + item.data(Qt.UserRole)
        mime.setData(MIME, entry.encode("utf-8"))
        mime.setText(entry)
        drag = QDrag(self)
        drag.setMimeData(mime)
        drag.setPixmap(item.icon().pixmap(64, 64))
        drag.exec(Qt.CopyAction)
    def keyPressEvent(self, ev):
        item = self.currentItem()
        if item is not None and ev.modifiers() == Qt.NoModifier:
            if ev.key() == Qt.Key_F2:
                self.panel.verb(item, "rename")
                return
            if ev.key() == Qt.Key_Delete:
                self.panel.verb(item, "delete")
                return
        super().keyPressEvent(ev)
class PrefabPanel(QWidget):
    def __init__(self, lib):
        super().__init__()
        self.lib = lib
        self.ed = lib.ed
        self.thumbs = lib.thumbnailer
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(6)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search prefabs: house, tower, bridge, castle...")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(lambda *_: self.fill(refresh=False))
        lay.addWidget(self.search)
        self.grid = Grid(self)
        self.grid.setToolTip("Drag a prefab into a view, or double-click: it is laid at the "
                             "cursor in the map's theme. Right-click: rename, tags, delete.")
        self.grid.itemActivated.connect(self._place)
        self.grid.currentItemChanged.connect(self._show)
        self.grid.customContextMenuRequested.connect(self._menu)
        self.empty = common.empty_state("No prefabs yet", "Select a build in the map and press "
                                        "Save selection, or import one saved in the game.")
        lay.addWidget(self.empty)
        lay.addWidget(self.grid, 1)
        self.info = QLabel()
        self.info.setObjectName("caption")
        self.info.setWordWrap(True)
        lay.addWidget(self.info)
        row = QHBoxLayout()
        save = QPushButton("Save selection")
        save.setObjectName("primary")
        save.setToolTip("Keep the selected pieces as a prefab (Ctrl+G): its roles follow "
                        "a map's theme, its connectors join other prefabs")
        save.clicked.connect(self.save_selection)
        draft = QPushButton("From the game...")
        draft.setToolTip("A structure saved in the Forge (Save the marked box as a prefab): "
                         "read it out of the mod's save file")
        draft.clicked.connect(self.import_draft)
        row.addWidget(save, 1)
        row.addWidget(draft)
        lay.addLayout(row)
        self.items = []
        self.fill()
    def picture(self, key):
        path = os.path.join(prefablib.prefabs().LIBRARY, key + ".prefab")
        theme = self.ed.session.doc.brief.get("theme")
        cache_key = ("prefab", key, common.mtime(path), theme)
        try:
            pieces = prefablib.thumb_pieces(key, None if theme in (None, "auto") else theme)
        except Exception:
            pieces = []
        if not pieces:
            pm = common.shape_pixmap("cube", QColor("#8a8f98"), THUMB)
        else:
            pm = self.thumbs.picture(cache_key, pieces)
        return QIcon(pm.scaled(THUMB, THUMB, Qt.KeepAspectRatio, Qt.SmoothTransformation))
    def fill(self, *_, refresh=True):
        if refresh or not getattr(self, "_read", False):
            self._read = True
            try:
                self.items = prefablib.entries()
            except Exception as why:
                self.items = []
                self.info.setText("The library could not be read: %s" % why)
        shown = prefablib.search(self.items, self.search.text())
        self.grid.clear()
        self._todo = []
        for e in shown:
            w, h, d = e["size"]
            item = QListWidgetItem(self.placeholder(), e["name"])
            self._todo.append((item, e["key"]))
            item.setData(Qt.UserRole, e["key"])
            item.setToolTip("%s\n%d x %d cells, %d high, %d pieces\ntags: %s\nconnectors: %s%s" % (
                e["name"], w, d, h, e["pieces"], ", ".join(e["tags"]) or "-",
                ", ".join("%s %s" % (c["kind"], c["face"]) for c in e["connectors"]) or "none",
                "\n%d cells only in the game's Forge (no arena kind yet)" % e["forge_only"]
                if e["forge_only"] else ""))
            self.grid.addItem(item)
        self.grid.setVisible(bool(self.items))
        self.empty.setVisible(not self.items)
        if self._todo:
            QTimer.singleShot(0, self, self._draw_some)
    def placeholder(self):
        pm = getattr(self, "_placeholder", None)
        if pm is None:
            pm = common.shape_pixmap("cube", QColor("#5a5f68"), THUMB)
            self._placeholder = pm
        return QIcon(pm)
    def _draw_some(self, most=2):
        todo = getattr(self, "_todo", [])
        done = 0
        while todo and done < most:
            item, key = todo.pop(0)
            try:
                item.setIcon(self.picture(key))
            except RuntimeError:
                pass
            done += 1
        if todo:
            QTimer.singleShot(0, self, self._draw_some)
        return done
    def draw_all(self):
        while getattr(self, "_todo", []):
            self._draw_some(most=100)
    def changed(self):
        self.fill()
        self.lib.palette_changed()
    def current(self):
        item = self.grid.currentItem()
        if item is None:
            return None
        key = item.data(Qt.UserRole)
        return next((e for e in self.items if e["key"] == key), None)
    def _show(self, *_):
        e = self.current()
        if e is None:
            self.info.setText("")
            return
        w, h, d = e["size"]
        self.info.setText("<b>%s</b> - %d x %d cells, %d high, %d pieces; roles: %s" % (
            e["name"], w, d, h, e["pieces"], ", ".join(
                "%s=%s" % kv for kv in sorted(e["roles"].items())) or "none"))
    def _place(self, item):
        self.ed.drop("prefabs:" + item.data(Qt.UserRole))
    def _menu(self, pos):
        item = self.grid.itemAt(pos)
        if item is None:
            return
        m = QMenu(self)
        place = m.addAction("Place at the cursor  (double-click, Enter)")
        rename = m.addAction("Rename...  (F2)")
        tags = m.addAction("Tags...")
        m.addSeparator()
        delete = m.addAction("Delete...  (Delete)")
        got = m.exec(self.grid.mapToGlobal(pos))
        self.verb(item, {place: "place", rename: "rename", tags: "tags",
                         delete: "delete"}.get(got))
    def verb(self, item, what):
        if what is None or item is None:
            return
        key = item.data(Qt.UserRole)
        e = self.current() if self.current() and self.current()["key"] == key else next(
            (x for x in self.items if x["key"] == key), None)
        if e is None:
            return
        if what == "place":
            self._place(item)
        elif what == "rename":
            name, ok = QInputDialog.getText(self, "Rename", "Name:", text=e["name"])
            if ok and name.strip():
                self._do(lambda: prefablib.edit(key, name=name.strip()), "Renamed %s" % key)
        elif what == "tags":
            text, ok = QInputDialog.getText(self, "Tags", "Tags, comma separated (theme, kind, "
                                            "size):", text=", ".join(e["tags"]))
            if ok:
                self._do(lambda: prefablib.edit(key, tags=[t.strip() for t in text.split(",")
                                                             if t.strip()]), "Tagged %s" % key)
        elif what == "delete":
            if QMessageBox.question(self, "Delete", "Take %s out of the library and the Forge's "
                                    "Prefabs shelf?" % e["name"]) == QMessageBox.Yes:
                self._do(lambda: prefablib.delete(key), "Deleted %s" % key)
    def _do(self, fn, msg):
        pf = prefablib.prefabs()
        try:
            said = fn()
        except pf.Refused as why:
            QMessageBox.warning(self, "Refused", str(why))
            return
        self.changed()
        self.ed.hint("%s - %s" % (msg, said or ""))
    def save_selection(self):
        s = self.ed.session
        pieces = [s.doc.get(r) for r in s.refs() if r[0] == "piece"]
        if not pieces:
            self.ed.hint("Select the pieces of a build first (box select, or magic select "
                         "with Alt+click)")
            return
        cells, skipped = prefablib.from_pieces(pieces)
        if not cells:
            QMessageBox.information(self, "Not on the Forge's grid", "None of the %d pieces sits "
                                    "on the Forge's 200 grid in a shape the Forge has:\n\n%s" % (
                                        len(pieces), "\n".join(w for _, w in skipped[:6])))
            return
        dlg = SavePrefab(self, cells, skipped, len(pieces))
        if dlg.exec() == QDialog.Accepted:
            self.changed()
    def import_draft(self):
        start = (prefablib.save_locations() or [os.path.expanduser("~")])[0]
        path, _ = QFileDialog.getOpenFileName(self, "The mod's save file (Coop DX keeps it in "
                                              "its sav folder)", start,
                                              "Mod storage (*.sav);;All files (*)")
        if not path:
            return
        pf = prefablib.prefabs()
        try:
            cells = prefablib.read_draft(path)
        except (pf.Refused, OSError, ValueError) as why:
            QMessageBox.warning(self, "No draft", str(why))
            return
        name, ok = QInputDialog.getText(self, "From the game", "%d blocks. Its name:" % len(cells))
        if not ok or not name.strip():
            return
        slugs = prefablib.textures_in(cells)
        roles = {}
        if slugs:
            wall, ok = QInputDialog.getItem(
                self, "Theme-aware?", "Which texture is its wall (it then follows a map's "
                "theme)?", ["(none - keep the textures)"] + slugs, 0, False)
            if ok and not wall.startswith("("):
                roles["wall"] = wall
        code, said = prefablib.import_save(path, name.strip(), roles)
        if code:
            QMessageBox.warning(self, "Refused", said)
            return
        self.changed()
        self.ed.hint(said.splitlines()[0] if said else "Imported")
class SavePrefab(QDialog):
    def __init__(self, panel, cells, skipped, total):
        super().__init__(panel)
        self.panel = panel
        self.cells = prefablib.anchored(cells)
        self.setWindowTitle("Save the selection as a prefab")
        self.resize(560, 560)
        lay = QVBoxLayout(self)
        note = QLabel("%d of %d pieces are Forge cells%s." % (
            len(cells), total, (" - %d are not on the Forge's grid and stay out: %s" % (
                len(skipped), "; ".join(sorted(set(w for _, w in skipped))[:3])))
            if skipped else ""))
        note.setWordWrap(True)
        lay.addWidget(note)
        form = QFormLayout()
        self.name = QLineEdit()
        self.name.setPlaceholderText("e.g. My house")
        self.tags = QLineEdit()
        self.tags.setPlaceholderText("house, village, castle...")
        form.addRow("Name", self.name)
        form.addRow("Tags", self.tags)
        lay.addLayout(form)
        lay.addWidget(QLabel("<b>Roles</b> - a texture that plays a role follows the map's "
                             "theme (wall, roof, floor, path, trim...)"))
        self.roles = {}
        roles_form = QFormLayout()
        pf = prefablib.prefabs()
        names = ["(keep)"] + sorted(pf.ROLE_TO_THEME) + ["accent"]
        for slug in prefablib.textures_in(self.cells):
            box = QComboBox()
            box.addItems(names)
            box.currentIndexChanged.connect(self.check)
            roles_form.addRow(slug, box)
            self.roles[slug] = box
        lay.addLayout(roles_form)
        lay.addWidget(QLabel("<b>Connectors</b> - where it joins another prefab (a door, a "
                             "path, a wall, a bridge)"))
        self.conn = QTableWidget(0, 3)
        self.conn.setHorizontalHeaderLabels(("Cell", "Faces", "Kind"))
        self.conn.verticalHeader().setVisible(False)
        lay.addWidget(self.conn, 1)
        row = QHBoxLayout()
        add = QPushButton("Add a connector")
        add.clicked.connect(self.add_connector)
        rm = QPushButton("Remove")
        rm.clicked.connect(lambda: self.conn.removeRow(self.conn.currentRow()))
        row.addWidget(add)
        row.addWidget(rm)
        row.addStretch(1)
        lay.addLayout(row)
        self.faults = QLabel()
        self.faults.setWordWrap(True)
        lay.addWidget(self.faults)
        row = QHBoxLayout()
        row.addStretch(1)
        cancel = QPushButton("Cancel")
        cancel.clicked.connect(self.reject)
        self.ok = QPushButton("Save")
        self.ok.setObjectName("primary")
        self.ok.clicked.connect(self.save)
        row.addWidget(cancel)
        row.addWidget(self.ok)
        lay.addLayout(row)
        self.name.textChanged.connect(self.check)
        self.check()
    def add_connector(self):
        slots = prefablib.connector_slots(self.cells)
        labels = ["%d, %d, %d facing %s" % (at + (face,)) for at, face in slots]
        got, ok = QInputDialog.getItem(self, "Connector", "Where:", labels, 0, False)
        if not ok:
            return
        at, face = slots[labels.index(got)]
        kind, ok = QInputDialog.getItem(self, "Connector", "Kind:",
                                        list(prefablib.prefabs().KINDS), 0, False)
        if not ok:
            return
        n = self.conn.rowCount()
        self.conn.insertRow(n)
        for col, val in enumerate(("%d, %d, %d" % at, face, kind)):
            it = QTableWidgetItem(val)
            it.setData(Qt.UserRole, (at, face, kind))
            self.conn.setItem(n, col, it)
        self.check()
    def prefab(self):
        roles = {}
        for slug, box in self.roles.items():
            if box.currentIndex() > 0:
                roles[box.currentText()] = slug
        conns = [self.conn.item(r, 0).data(Qt.UserRole) for r in range(self.conn.rowCount())]
        return prefablib.make(self.cells, self.name.text().strip(),
                              [t.strip() for t in self.tags.text().split(",") if t.strip()],
                              roles, conns)
    def check(self, *_):
        if not self.name.text().strip():
            self.faults.setText("Give it a name.")
            self.ok.setEnabled(False)
            return
        faults = prefablib.faults(self.prefab())
        key = prefablib.prefabs().key_for(self.name.text())
        if os.path.exists(os.path.join(prefablib.prefabs().LIBRARY, key + ".prefab")):
            faults.append("a prefab %s exists - pick another name" % key)
        self.faults.setText("<span style='color:%s'>%s</span>" % (
            "#ef5350" if faults else "#5cc879",
            "<br>".join(faults[:6]) if faults else "Ready: prefabs.py's checks pass."))
        self.ok.setEnabled(not faults)
    def save(self):
        pf = prefablib.prefabs()
        try:
            key, said = prefablib.save(self.prefab())
        except pf.Refused as why:
            self.faults.setText(str(why))
            return
        self.panel.ed.hint("Saved the prefab %s - %s" % (key, said))
        self.accept()
