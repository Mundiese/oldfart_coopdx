from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QColor, QIcon, QPixmap
from PySide6.QtWidgets import (QHBoxLayout, QLineEdit, QMenu, QToolButton, QTreeWidget,
                               QTreeWidgetItem, QVBoxLayout, QWidget)
from .. import groups
from .widgets import caption
ROLE = Qt.UserRole
MAX_ROWS = 400
KIND_WORDS = {"piece": "Pieces", "spawn": "Spawns", "object": "Forge objects",
              "mover": "Movers", "star": "Stars", "spot": "Named spots", "anchor": "Anchors"}
EMPTY = ("No layers yet. Select things and press Ctrl+L to put them on a layer you can "
         "hide, lock and colour; Ctrl+Alt+G glues things into a group.")
def colour_icon(name):
    rgb = groups.COLOUR.get(name, (150, 150, 150))
    pm = QPixmap(12, 12)
    pm.fill(QColor(*rgb))
    return QIcon(pm)
class Tree(QTreeWidget):
    def __init__(self, panel):
        super().__init__()
        self.panel = panel
    def keyPressEvent(self, ev):
        k = ev.key()
        if k == Qt.Key_F2:
            self.panel.rename_current()
            return
        if k == Qt.Key_Delete and self.panel.current_group():
            self.panel.dissolve_group()
            return
        if k == Qt.Key_Delete and self.panel.current_layer():
            self.panel.delete_layer()
            return
        if k == Qt.Key_H and self.panel.current_layer():
            self.panel.toggle("hidden")
            return
        if k == Qt.Key_L and self.panel.current_layer():
            self.panel.toggle("locked")
            return
        if k in (Qt.Key_Return, Qt.Key_Enter):
            self.panel.select_row(self.currentItem())
            return
        super().keyPressEvent(ev)
class OutlinerPanel(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self._loading = False
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(6)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Find a thing, a layer, a group...")
        self.search.setClearButtonEnabled(True)
        self.search.setToolTip("Only the rows with these words")
        self.search.textChanged.connect(lambda *_: self.refresh())
        lay.addWidget(self.search)
        self.empty = caption(EMPTY)
        lay.addWidget(self.empty)
        self.tree = Tree(self)
        self.tree.setColumnCount(3)
        self.tree.setHeaderLabels(["Name", "Shown", "Locked"])
        self.tree.setToolTip("Click selects, double-click frames, F2 renames, H hides, L locks, "
                             "Delete deletes a layer or a group (its things stay)")
        self.tree.setEditTriggers(QTreeWidget.NoEditTriggers)
        self.tree.itemClicked.connect(lambda it, col: self.select_row(it) if col == 0 else None)
        self.tree.itemDoubleClicked.connect(self._frame)
        self.tree.itemChanged.connect(self._changed)
        self.tree.header().setStretchLastSection(False)
        self.tree.setColumnWidth(1, 64)
        self.tree.setColumnWidth(2, 64)
        self.tree.header().setSectionResizeMode(0, self.tree.header().ResizeMode.Stretch)
        lay.addWidget(self.tree, 1)
        from studio.ui.reflow import ReflowGrid
        row = ReflowGrid(max_cols=6, min_cols=3, spacing=4)
        self.buttons = {}
        for key, text, tip, fn in (
                ("new", "New layer", "Ctrl+L - a new layer holding the selection",
                 lambda: self.ed.run_action("layer.new")),
                ("move", "Move here", "Put the selection on the layer chosen in the tree",
                 self.move_here),
                ("isolate", "Isolate", "Shift+H - only the chosen layer is shown; again: all",
                 self.isolate),
                ("colour", "Colour", "The chosen layer's colour tag", self.colour_menu),
                ("group", "Group", "Ctrl+Alt+G - glue the selection into one group",
                 lambda: self.ed.run_action("edit.group")),
                ("ungroup", "Ungroup", "Ctrl+Alt+U - take the selected groups apart",
                 lambda: self.ed.run_action("edit.ungroup"))):
            b = QToolButton()
            b.setText(text)
            b.setToolTip(tip)
            b.setAutoRaise(True)
            b.clicked.connect(fn)
            row.add(b)
            self.buttons[key] = b
        lay.addWidget(row)
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(120)
        self._timer.timeout.connect(self.refresh)
        ed.changed.connect(self._timer.start)
        self.refresh()
    def refresh(self):
        doc = self.ed.session.doc
        out = groups.outline(doc)
        words = self.search.text().strip().lower()
        open_ = self._open_keys()
        current = self.tree.currentItem().data(0, ROLE) if self.tree.currentItem() else None
        self._loading = True
        self.tree.clear()
        self.empty.setVisible(not out["layers"] and not out["groups"] and not words)
        def match(text):
            return not words or words in text.lower()
        def add_items(parent, refs):
            shown = 0
            for r in refs:
                text = groups.describe(doc, r)
                if not match(text) and not match(parent.text(0)):
                    continue
                if shown >= MAX_ROWS:
                    QTreeWidgetItem(parent, ["... %d more - type to find them" % (
                        len(refs) - shown)])
                    break
                it = QTreeWidgetItem(parent, [text])
                it.setData(0, ROLE, ("item", r))
                shown += 1
            return shown
        top = QTreeWidgetItem(self.tree, ["Layers (%d)" % len(out["layers"])])
        top.setData(0, ROLE, ("root", "layers"))
        for l in out["layers"]:
            it = QTreeWidgetItem(top, ["%s (%d)%s" % (l["name"], len(l["members"]),
                                                      "  - isolated" if l["isolated"] else "")])
            it.setData(0, ROLE, ("layer", l["id"]))
            it.setIcon(0, colour_icon(l["colour"]))
            it.setFlags(it.flags() | Qt.ItemIsUserCheckable)
            it.setCheckState(1, Qt.Unchecked if l["hidden"] else Qt.Checked)
            it.setCheckState(2, Qt.Checked if l["locked"] else Qt.Unchecked)
            it.setToolTip(1, "Shown in the views (H)")
            it.setToolTip(2, "Locked: seen but not picked or changed - and kept when you "
                          "Generate or Refine (L)")
            add_items(it, l["members"])
        gtop = QTreeWidgetItem(self.tree, ["Groups (%d)" % len(out["groups"])])
        gtop.setData(0, ROLE, ("root", "groups"))
        focus = self.ed.session.focus()
        def add_group(parent, g):
            inner = len(g["groups"])
            text = "%s (%d%s)" % (g["name"], len(g["all"]),
                                  ", %d group%s inside" % (inner, "" if inner == 1 else "s")
                                  if inner else "")
            if g["id"] == focus:
                text += "  - entered"
            it = QTreeWidgetItem(parent, [text])
            it.setData(0, ROLE, ("group", g["id"]))
            for c in g["groups"]:
                add_group(it, c)
            add_items(it, g["members"])
        for g in out["groups"]:
            add_group(gtop, g)
        loose = QTreeWidgetItem(self.tree, ["Not on a layer"])
        loose.setData(0, ROLE, ("root", "loose"))
        for kind, refs in sorted(out["loose"].items()):
            it = QTreeWidgetItem(loose, ["%s (%d)" % (KIND_WORDS.get(kind, kind), len(refs))])
            it.setData(0, ROLE, ("kind", kind))
            add_items(it, refs)
        for i in range(self.tree.topLevelItemCount()):
            self.tree.topLevelItem(i).setExpanded(True)
        self._restore_open(open_, current, bool(words))
        self._loading = False
        has_layer = bool(out["layers"])
        for key in ("move", "isolate", "colour"):
            self.buttons[key].setEnabled(has_layer)
    def _walk(self):
        stack = [self.tree.topLevelItem(i) for i in range(self.tree.topLevelItemCount())]
        while stack:
            it = stack.pop()
            yield it
            stack += [it.child(i) for i in range(it.childCount())]
    def _open_keys(self):
        return set(it.data(0, ROLE) for it in self._walk() if it.isExpanded() and it.data(0, ROLE))
    def _restore_open(self, keys, current, all_open):
        for it in self._walk():
            key = it.data(0, ROLE)
            if all_open or (key in keys and key[0] != "root"):
                it.setExpanded(True)
            if current is not None and key == current:
                self.tree.setCurrentItem(it)
    def row_refs(self, item):
        if item is None:
            return []
        key = item.data(0, ROLE)
        doc = self.ed.session.doc
        if not key:
            return []
        if key[0] == "item":
            return [key[1]]
        if key[0] == "layer":
            lay = groups.get_layer(doc, key[1])
            return groups.members(doc, lay) if lay else []
        if key[0] == "group":
            g = groups.get_group(doc, key[1])
            return groups.all_members(doc, g) if g else []
        if key[0] == "kind":
            return doc.refs(key[1])
        return []
    def select_row(self, item):
        refs = self.row_refs(item)
        if not refs:
            return
        s = self.ed.session
        key = item.data(0, ROLE)
        doc = s.doc
        if key[0] == "group":
            g = groups.get_group(doc, key[1])
            up = groups.parent_of(doc, g)
            s.group_focus = up["id"] if up else None
        elif key[0] == "item":
            g = groups.group_of(doc, key[1])
            s.group_focus = g["id"] if g is not None else s.group_focus
        sel = s.selection
        sel.set(refs)
        got = len(sel.refs)
        if got < len(refs):
            self.ed.hint("%d of %d selected - the rest are hidden or locked" % (got, len(refs)))
        else:
            self.ed.hint(self.ed.session.selection_line())
    def _frame(self, item, *_):
        self.select_row(item)
        try:
            self.ed.studio.window.actions["view.frame_selected"].trigger()
        except (KeyError, AttributeError):
            pass
    def current_layer(self):
        it = self.tree.currentItem()
        while it is not None:
            key = it.data(0, ROLE)
            if key and key[0] == "layer":
                return key[1]
            it = it.parent()
        return None
    def current_group(self):
        it = self.tree.currentItem()
        key = it.data(0, ROLE) if it is not None else None
        return key[1] if key and key[0] == "group" else None
    def _push(self, change):
        self.ed.push(change)
    def _changed(self, item, col):
        if self._loading or col not in (1, 2):
            return
        key = item.data(0, ROLE)
        if not key or key[0] != "layer":
            return
        if col == 1:
            self._push(groups.set_layer(self.ed.session.doc, key[1],
                                        hidden=item.checkState(1) != Qt.Checked))
        else:
            self._push(groups.set_layer(self.ed.session.doc, key[1],
                                        locked=item.checkState(2) == Qt.Checked))
    def toggle(self, field):
        lid = self.current_layer()
        lay = groups.get_layer(self.ed.session.doc, lid) if lid else None
        if lay is None:
            return
        self._push(groups.set_layer(self.ed.session.doc, lid, **{field: not lay.get(field)}))
    def move_here(self):
        lid = self.current_layer()
        if lid is None:
            self.ed.hint("Choose a layer in the tree first")
            return
        self._push(groups.assign(self.ed.session.doc, lid, self.ed.session.refs()))
    def isolate(self):
        lid = self.current_layer()
        if lid is None:
            self.ed.hint("Choose a layer in the tree first")
            return
        self._push(groups.isolate(self.ed.session.doc, lid))
    def colour_menu(self):
        lid = self.current_layer()
        if lid is None:
            self.ed.hint("Choose a layer in the tree first")
            return None
        menu = QMenu(self)
        for name, _ in groups.COLOURS:
            a = menu.addAction(colour_icon(name), name)
            a.triggered.connect(lambda _=False, n=name: self.set_colour(lid, n))
        self._menu = menu
        menu.popup(self.buttons["colour"].mapToGlobal(self.buttons["colour"].rect().bottomLeft()))
        return menu
    def set_colour(self, lid, name):
        self._push(groups.set_layer(self.ed.session.doc, lid, colour=name))
    def dissolve_group(self):
        gid = self.current_group()
        doc = self.ed.session.doc
        g = groups.get_group(doc, gid) if gid else None
        if g is None:
            return
        refs = groups.all_members(doc, g)
        up = groups.parent_of(doc, g)
        self._push(groups.ungroup(doc, refs[:1], focus=up["id"] if up else None))
    def delete_layer(self):
        lid = self.current_layer()
        if lid is not None:
            self._push(groups.delete_layer(self.ed.session.doc, lid))
    def rename_current(self, name=None):
        lid, gid = self.current_layer(), self.current_group()
        doc = self.ed.session.doc
        if lid is None and gid is None:
            return
        old = (groups.get_layer(doc, lid) if gid is None else groups.get_group(doc, gid))["name"]
        if name is None:
            from PySide6.QtWidgets import QInputDialog
            name, ok = QInputDialog.getText(self, "Rename", "New name:", text=old)
            if not ok:
                return
        if gid is not None:
            self._push(groups.rename_group(doc, gid, name))
        else:
            self._push(groups.set_layer(doc, lid, name=name))
