from PySide6.QtCore import QMimeData, QSize, Qt, QTimer
from PySide6.QtGui import QDrag, QPainter
from PySide6.QtWidgets import (QComboBox, QHBoxLayout, QLabel, QLineEdit, QListView,
                               QListWidget, QListWidgetItem, QMenu, QTabWidget, QVBoxLayout,
                               QWidget)
from .. import palette as palmod
from . import widgets
MIME = "application/x-oldfart-palette"
TITLES = {"shapes": "Shapes", "textures": "Textures", "prefabs": "Prefabs", "decor": "Decor",
          "setpieces": "Set pieces", "forge": "Forge", "markers": "Markers"}
PEN = " Click: in the hand - each click in a view places one, Esc lets go."
TIPS = {
    "shapes": "Drag a shape into a view (or double-click: at the cursor). It wears the "
              "current texture." + PEN,
    "textures": "Click: the current texture. Double-click: paint the selection. Drag onto a "
                "piece: paint it. Ctrl+click: a brush - click pieces to paint them.",
    "prefabs": "Finished builds from prefabs/ - laid in the map's theme." + PEN,
    "decor": "Props: each ONE object (a lamp, a bench, a well...) with one simple solid or "
             "none - the same list the generator and the Forge's Decor shelf use." + PEN,
    "setpieces": "Whole set pieces - giant mushrooms, a waterfall grotto, a lookout tower... "
                 "Drag one onto the map: it is built where you drop it, fitted to the "
                 "ground there (or the status line says why it does not fit)." + PEN,
    "forge": "The mod's Forge objects - enemies, bosses, platforms, lifts, pickups... - on "
             "their Forge shelves. Their kind, facing and the modes that use them are in "
             "Properties." + PEN,
    "markers": "Spawn points, and anchors: where the wish wants what. The generator honours "
               "anchors you place." + PEN,
}
SHELF_ITEM = QSize(94, 90)
SHELF_ITEM_BIG = QSize(112, 116)
RECENT_EMPTY = "What you place shows up here - click it to place it again"
class Shelf(QListWidget):
    def __init__(self, panel):
        super().__init__()
        self.panel = panel
        self.setViewMode(QListView.IconMode)
        self.setIconSize(QSize(40, 40))
        self.setGridSize(QSize(96, 92))
        self.setResizeMode(QListView.Adjust)
        self.setMovement(QListView.Static)
        self.setWordWrap(True)
        self.setDragEnabled(True)
        self.setUniformItemSizes(True)
        self.setSelectionMode(QListWidget.SingleSelection)
        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.empty_text = ""
    def paintEvent(self, ev):
        super().paintEvent(ev)
        if self.count() or not self.empty_text:
            return
        p = QPainter(self.viewport())
        col = self.palette().color(self.foregroundRole())
        col.setAlpha(150)
        p.setPen(col)
        r = self.viewport().rect().adjusted(8, 0, -8, 0)
        p.drawText(r, int(Qt.AlignVCenter | Qt.AlignLeft | Qt.TextWordWrap), self.empty_text)
        p.end()
    def startDrag(self, actions):
        item = self.currentItem()
        if item is None:
            return
        mime = QMimeData()
        mime.setData(MIME, item.data(Qt.UserRole).encode("utf-8"))
        mime.setText(item.data(Qt.UserRole))
        drag = QDrag(self)
        drag.setMimeData(mime)
        drag.setPixmap(item.icon().pixmap(40, 40))
        drag.exec(Qt.CopyAction)
class PalettePanel(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self.palette = ed.palette
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(6)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search: stairs, ramp, lava, cottage, tower...")
        self.search.setClearButtonEnabled(True)
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(120)
        self._search_timer.timeout.connect(self.fill)
        self.search.textChanged.connect(self._searched)
        lay.addWidget(self.search)
        self.family = QComboBox()
        self.family.addItem("Every material family", "")
        for name, entries in self.palette.families():
            self.family.addItem("%s (%d)" % (name, len(entries)), name)
        self.family.setToolTip("Show the textures of one material family (Soft 64's "
                               "library); search words narrow it further.")
        self.family.currentIndexChanged.connect(self.fill)
        lay.addWidget(self.family)
        row = QHBoxLayout()
        self.tex_icon = QLabel()
        self.tex_label = QLabel()
        row.addWidget(widgets.header("Texture"))
        row.addWidget(self.tex_icon)
        row.addWidget(self.tex_label, 1)
        lay.addLayout(row)
        self.recent = Shelf(self)
        self.recent.setFlow(QListView.LeftToRight)
        self.recent.setWrapping(False)
        self.recent.setIconSize(QSize(28, 28))
        self.recent.setGridSize(QSize(40, 40))
        self.recent.setFixedHeight(48)
        self.recent.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.recent.setToolTip("Recently placed: click to take one into the hand, drag one "
                               "into a view")
        self.recent.empty_text = RECENT_EMPTY
        self.recent.itemClicked.connect(self._clicked)
        self.recent.itemActivated.connect(self._double)
        lay.addWidget(widgets.header("Recent"))
        lay.addWidget(self.recent)
        self.tabs = QTabWidget()
        self.tabs.setUsesScrollButtons(False)
        self.tabs.tabBar().setExpanding(True)
        self.shelves = {}
        for section in palmod.SECTIONS:
            shelf = Shelf(self)
            shelf.setToolTip(TIPS[section])
            shelf.itemClicked.connect(self._clicked)
            shelf.itemActivated.connect(self._double)
            shelf.customContextMenuRequested.connect(lambda pos, s=shelf: self._menu(s, pos))
            self.shelves[section] = shelf
            self.tabs.addTab(shelf, TITLES[section])
        lay.addWidget(self.tabs, 1)
        self.hint = widgets.caption(TIPS["shapes"])
        self.tabs.currentChanged.connect(
            lambda i: self.hint.setText(TIPS[palmod.SECTIONS[i]]))
        lay.addWidget(self.hint)
        self.show_texture(ed.session.texture)
        self.fill_recent()
    def set_big(self, on):
        was = getattr(self, "big", False)
        self.big = bool(on)
        for shelf in getattr(self, "shelves", {}).values():
            shelf.setIconSize(QSize(64, 64) if on else QSize(40, 40))
            shelf.setGridSize(QSize(114, 118) if on else QSize(96, 92))
        if not getattr(self, "_filled", False):
            self.fill()
            return
        if was == self.big:
            return
        hint = SHELF_ITEM_BIG if self.big else SHELF_ITEM
        for shelf in self.shelves.values():
            for i in range(shelf.count()):
                shelf.item(i).setSizeHint(hint)
    def show_texture(self, slug):
        self.tex_icon.setPixmap(widgets.swatch_pixmap(slug, 22))
        t = None
        try:
            t = self.palette.get("textures:" + slug)
        except KeyError:
            pass
        self.tex_label.setText(t.label if t else slug)
        if hasattr(self, "shelves"):
            if getattr(self, "_filled", False):
                self.fill(sections=("shapes",))
            else:
                self.fill()
    def fill_recent(self):
        self.recent.clear()
        for eid in self.palette.recent:
            try:
                e = self.palette.get(eid)
            except KeyError:
                continue
            item = QListWidgetItem(widgets.icon_for(e, self.ed.session.texture, self.ed.tokens),
                                   "")
            item.setData(Qt.UserRole, e.id)
            item.setToolTip("%s\n%s" % (e.label, e.hint))
            self.recent.addItem(item)
        return self.recent.count()
    def _searched(self, *_):
        if self.search.hasFocus():
            self._search_timer.start()
        else:
            self._search_timer.stop()
            self.fill()
    def fill(self, *_, sections=None):
        self._filled = True
        text = self.search.text()
        tokens = self.ed.tokens
        found = 0
        for section, shelf in self.shelves.items():
            if sections is not None and section not in sections:
                found += shelf.count()
                continue
            shelf.clear()
            family = self.family.currentData() if hasattr(self, "family") else ""
            for e in self.palette.in_family(self.palette.search(text, section), family):
                item = QListWidgetItem(widgets.icon_for(e, self.ed.session.texture, tokens),
                                       ("* " if e.id in self.palette.favourites else "") + e.label)
                item.setData(Qt.UserRole, e.id)
                item.setToolTip("%s\n%s" % (e.label, e.hint))
                item.setSizeHint(SHELF_ITEM_BIG if getattr(self, "big", False) else SHELF_ITEM)
                shelf.addItem(item)
                found += 1
            shelf.empty_text = ("Nothing called \u201c%s\u201d here - try stairs, ramp, "
                                "tower, or another tab" % text.strip()) if text.strip() else ""
            shelf.viewport().update()
            self.tabs.setTabText(palmod.SECTIONS.index(section), "%s %s" % (
                TITLES[section], ("(%d)" % shelf.count()) if text else ""))
        widgets.save_drawing_cache()
        return found
    def entry(self, item):
        return self.palette.get(item.data(Qt.UserRole))
    def _clicked(self, item):
        from PySide6.QtWidgets import QApplication
        e = self.entry(item)
        ctrl = bool(QApplication.keyboardModifiers() & Qt.ControlModifier)
        if e.section == "textures":
            self.ed.set_texture(e.key)
            if ctrl:
                self.ed.arm(e.id)
        else:
            self.ed.arm(e.id)
    def _double(self, item):
        e = self.entry(item)
        if e.section == "textures":
            self.ed.set_texture(e.key)
            self.ed.run_action("edit.paint")
        else:
            self.ed.drop(e.id)
    def _menu(self, shelf, pos):
        item = shelf.itemAt(pos)
        if item is None:
            return
        e = self.entry(item)
        m = QMenu(self)
        fav = m.addAction("Remove from favourites" if e.id in self.palette.favourites
                          else "Add to favourites")
        place = m.addAction("Place at the cursor") if e.section != "textures" else None
        paint = m.addAction("Paint the selection") if e.section == "textures" else None
        for hook in list(getattr(self.ed, "palette_menu_hooks", ())):
            hook(m, e)
        got = m.exec(shelf.mapToGlobal(pos))
        if got is fav:
            self.palette.toggle_favourite(e.id)
            self.ed.save_palette_state()
            self.fill()
        elif got is not None and got is place:
            self.ed.drop(e.id)
        elif got is not None and got is paint:
            self.ed.set_texture(e.key)
            self.ed.run_action("edit.paint")
