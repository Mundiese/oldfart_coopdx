from PySide6.QtCore import Qt
from PySide6.QtWidgets import (QFrame, QLabel, QLineEdit, QListWidget, QListWidgetItem,
                               QVBoxLayout)
from .. import commandpal
ROWS = 8
SECTION_WORDS = {"shapes": "shape", "prefabs": "prefab", "decor": "prop", "forge": "Forge object",
                 "markers": "marker"}
class CommandPalette(QFrame):
    def __init__(self, lib):
        super().__init__(lib.window, Qt.Popup | Qt.FramelessWindowHint)
        self.lib = lib
        self.model = commandpal.Palette()
        self.model.restore(lib.ed.settings_get("commands", {}))
        self.setObjectName("card")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(6)
        self.box = QLineEdit()
        self.box.setPlaceholderText("Search every command: stairs, export, undo, "
                                    "quad, music, prefab...")
        self.box.textChanged.connect(self.fill)
        self.box.installEventFilter(self)
        lay.addWidget(self.box)
        self.list = QListWidget()
        self.list.itemActivated.connect(self.run_item)
        self.list.itemClicked.connect(self.run_item)
        lay.addWidget(self.list)
        self.foot = QLabel("Enter runs  -  Up/Down choose  -  Esc closes")
        self.foot.setObjectName("caption")
        lay.addWidget(self.foot)
    def collect(self):
        m = self.model
        m.items.clear()
        w = self.lib.window
        from studio.core import keymap
        level = getattr(getattr(self.lib.studio, "ux", None), "parts", {}).get("levelui")
        from studio.ux import level as lvmod
        for aid, action in w.actions.items():
            label = action.text().replace("&", "") or aid
            group = keymap.ACTIONS.get(aid, ([], label, ""))[2]
            keys = [s.toString() for s in action.shortcuts()]
            full = level.full_name(aid).replace("&", "") if level is not None else label
            if level is not None and level.simple() and level.menu_of(aid):
                label += "  (Full mode)"
            m.add(aid, label, group, keys, action.toolTip(),
                  run=(lambda a=action: a.trigger()) if action.isEnabled() else None,
                  words=lvmod.search_words(aid, full))
        ed = self.lib.ed
        for e in ed.palette.entries:
            hint = e.hint
            if e.section == "textures":
                run = (lambda k=e.key: ed.set_texture(k))
                label = "Texture: %s" % e.label
            else:
                run = (lambda i=e.id: ed.arm(i) if hasattr(ed, "arm") else ed.drop(i))
                label = "Place %s: %s" % (SECTION_WORDS.get(e.section, e.section), e.label)
            m.add("palette:%s" % e.id, label, e.section.capitalize(), [], hint, run,
                  words=" ".join(e.tags))
        for dock in self.lib.studio.docks.keys():
            d = self.lib.studio.docks.get(dock)
            title = d.windowTitle() if d is not None else dock
            m.add("panel:" + dock, "Show the %s panel" % title, "Panels", [],
                  run=(lambda d=d: (d.show(), d.raise_())) if d is not None else None,
                  words="panel %s" % title)
        return m
    def open(self):
        self.collect()
        w = self.lib.window
        width = min(640, max(420, int(w.width() * 0.5)))
        self.resize(width, 60 + 34 * ROWS)
        top = w.mapToGlobal(w.rect().topLeft())
        self.move(top.x() + (w.width() - width) // 2, top.y() + int(w.height() * 0.15))
        self.box.clear()
        self.fill()
        self.show()
        self.box.setFocus()
    def fill(self, *_):
        self.list.clear()
        for item in self.model.search(self.box.text()):
            keys = ("   " + ", ".join(item.keys[:2])) if item.keys else ""
            li = QListWidgetItem("%s%s" % (item.label, keys))
            li.setData(Qt.UserRole, item.id)
            li.setToolTip("%s - %s" % (item.group, item.hint) if item.hint else item.group)
            if item.run is None:
                li.setFlags(li.flags() & ~Qt.ItemIsEnabled)
            self.list.addItem(li)
        if self.list.count():
            self.list.setCurrentRow(0)
        self.foot.setText("%d found  -  Enter runs  -  Esc closes" % self.list.count())
    def run_item(self, li=None):
        li = li or self.list.currentItem()
        if li is None:
            return False
        item = self.model.items.get(li.data(Qt.UserRole))
        if item is None or item.run is None:
            return False
        self.model.used(item.id)
        self.lib.ed.settings_set("commands", self.model.state())
        self.hide()
        item.run()
        self.lib.ed.hint("%s" % item.label)
        return True
    def eventFilter(self, obj, ev):
        if obj is self.box and ev.type() == ev.Type.KeyPress:
            k = ev.key()
            if k in (Qt.Key_Down, Qt.Key_Up):
                r = self.list.currentRow() + (1 if k == Qt.Key_Down else -1)
                self.list.setCurrentRow(max(0, min(self.list.count() - 1, r)))
                return True
            if k in (Qt.Key_Return, Qt.Key_Enter):
                self.run_item()
                return True
            if k == Qt.Key_Escape:
                self.hide()
                return True
        return False
