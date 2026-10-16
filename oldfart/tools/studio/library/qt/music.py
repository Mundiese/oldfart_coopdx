import os
from PySide6.QtCore import Qt, QTimer, QUrl
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (QAbstractItemView, QCheckBox, QComboBox, QDialog, QFileDialog,
                               QFormLayout, QFrame, QHBoxLayout, QHeaderView, QInputDialog, QLabel,
                               QLineEdit, QMessageBox, QPushButton, QSizePolicy, QSpinBox,
                               QSplitter,
                               QTableWidget, QTableWidgetItem, QTreeWidget, QTreeWidgetItem,
                               QVBoxLayout, QWidget)
from .. import kb, musiclib
COLS = ("Title", "Artist", "Kind", "KB")
FOLD_STATE = "music_folds"
IMPORT_INTO = "music_import_category"
FOLDER = Qt.UserRole + 2
TITLE = Qt.UserRole + 3
MAP_MARK = "\u266a "
ALONG_MARK = "\u21a7 "
AUTO = "auto"
def elide(text, n=46):
    return text if len(text) <= n else text[:n - 1] + "\u2026"
class MapPicker(QFrame):
    def __init__(self, panel):
        super().__init__(panel, Qt.Popup)
        self.panel = panel
        self.setFrameShape(QFrame.StyledPanel)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search: title, game, artist...")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self.fill)
        self.search.returnPressed.connect(self.pick_first)
        lay.addWidget(self.search)
        self.tree = QTreeWidget()
        self.tree.setHeaderHidden(True)
        self.tree.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.tree.setExpandsOnDoubleClick(False)
        self.tree.itemClicked.connect(self.clicked)
        self.tree.itemActivated.connect(self.clicked)
        lay.addWidget(self.tree, 1)
        self.resize(440, 380)
        self.fill()
    def tracks(self):
        out = []
        def walk(item):
            for i in range(item.childCount()):
                child = item.child(i)
                if child.data(0, Qt.UserRole):
                    out.append(child)
                walk(child)
        walk(self.tree.invisibleRootItem())
        return out
    def fill(self, *_):
        text = self.search.text().strip()
        asked = self.panel.map_key()
        self.tree.clear()
        auto = QTreeWidgetItem([("%s" % MAP_MARK if asked == AUTO else "") +
                                "auto - the theme's music"])
        auto.setData(0, Qt.UserRole, AUTO)
        if not text or any(w in auto.text(0).lower() for w in text.lower().split()):
            self.tree.addTopLevelItem(auto)
        current = auto if asked == AUTO and auto.treeWidget() is not None else None
        shown = musiclib.search(self.panel.rows, text)
        def node(parent, n):
            count = musiclib.count_rows(n)
            item = QTreeWidgetItem(["%s  (%d)" % (n["label"], count)])
            f = item.font(0)
            f.setBold(parent is None)
            item.setFont(0, f)
            (self.tree.addTopLevelItem(item) if parent is None else parent.addChild(item))
            found = None
            for r in n["rows"]:
                it = QTreeWidgetItem([("%s" % MAP_MARK if r["id"] == asked else "")
                                      + (r.get("label") or r["title"])])
                it.setData(0, Qt.UserRole, r["id"])
                it.setToolTip(0, "%s\n%s" % (r.get("label") or r["title"], r.get("about") or ""))
                item.addChild(it)
                if r["id"] == asked:
                    found = it
            for k in n["children"]:
                found = node(item, k) or found
            item.setExpanded(bool(text) or found is not None)
            return found
        for n in musiclib.tree(shown, getattr(self.panel, "folders", None), keep_empty=False):
            if musiclib.count_rows(n):
                current = node(None, n) or current
        if current is not None:
            f = current.font(0)
            f.setBold(True)
            current.setFont(0, f)
            self.tree.setCurrentItem(current)
            self.tree.scrollToItem(current)
    def clicked(self, item, *_):
        key = item.data(0, Qt.UserRole)
        if not key:
            item.setExpanded(not item.isExpanded())
            return
        self.close()
        self.panel.use_for_map(key)
    def pick_first(self):
        found = self.tracks()
        if found:
            self.clicked(found[0])
class Tree(QTreeWidget):
    def __init__(self, panel):
        super().__init__()
        self.panel = panel
        self.setColumnCount(len(COLS))
        self.setHeaderLabels(COLS)
        self.setSelectionMode(QAbstractItemView.SingleSelection)
        self.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.setDragEnabled(True)
        self.setAcceptDrops(True)
        self.viewport().setAcceptDrops(True)
        self.setDragDropMode(QAbstractItemView.InternalMove)
        self.setDropIndicatorShown(True)
        self.header().setSectionResizeMode(0, QHeaderView.Stretch)
        self.itemExpanded.connect(lambda it: panel.folded(it, True))
        self.itemCollapsed.connect(lambda it: panel.folded(it, False))
        self.itemActivated.connect(lambda it, _c=0: panel.play_item(it))
        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.customContextMenuRequested.connect(panel.menu_at)
    def keyPressEvent(self, ev):
        if ev.key() == Qt.Key_Space and ev.modifiers() == Qt.NoModifier:
            self.panel.stop()
            return
        if ev.key() == Qt.Key_Delete and ev.modifiers() == Qt.NoModifier:
            self.panel.remove_row()
            return
        super().keyPressEvent(ev)
    def dropEvent(self, ev):
        if ev.source() is not self:
            return super().dropEvent(ev)
        target = self.itemAt(ev.position().toPoint())
        ev.setDropAction(Qt.IgnoreAction)
        ev.accept()
        self.drop_on(target)
    def drop_on(self, target):
        if target is not None and not target.data(0, Qt.UserRole) and target.data(0, FOLDER):
            self.panel.dropped_into(target.data(0, FOLDER))
            return
        self.panel.dropped_on(target.data(0, Qt.UserRole) if target is not None else None)
    def folder_items(self):
        out = []
        def walk(item):
            for i in range(item.childCount()):
                child = item.child(i)
                if child.data(0, FOLDER):
                    out.append(child)
                walk(child)
        walk(self.invisibleRootItem())
        return out
    def tracks(self):
        out = []
        def walk(item):
            for i in range(item.childCount()):
                child = item.child(i)
                if child.data(0, Qt.UserRole):
                    out.append(child)
                walk(child)
        walk(self.invisibleRootItem())
        return out
    def rowCount(self):
        return len(self.tracks())
    def selectRow(self, n):
        items = self.tracks()
        if 0 <= n < len(items):
            self.setCurrentItem(items[n])
class MusicPanel(QWidget):
    def __init__(self, lib):
        super().__init__()
        self.lib = lib
        self.ed = lib.ed
        self.reg = None
        self.rows = []
        self.list_key = "vanilla"
        self.rom = None
        self._player = None
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(6)
        row = QHBoxLayout()
        map_row = row
        row.addWidget(QLabel("<b>\u266a This map plays</b>"))
        from studio.ui.reflow import ElideButton
        self.map_pick = ElideButton()
        self.map_pick.setToolTip("The open map's music: what its brief asks for and what the "
                                 "venue plays - the game's own or any imported track. Click "
                                 "for a searchable list; or right-click a track below: Use as "
                                 "this map's music. One undo step.")
        self.map_pick.clicked.connect(self.open_map_picker)
        self.picker = None
        row.addWidget(self.map_pick, 1)
        from studio.ui.reflow import ElideLabel
        self.map_said = ElideLabel()
        self.map_said.setObjectName("caption")
        row.addWidget(self.map_said, 1)
        lay.addLayout(row)
        from PySide6.QtWidgets import QToolButton
        self.ffmpeg = QLabel()
        self.ffmpeg.setWordWrap(True)
        self.ffmpeg.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.audio = QLabel()
        self.audio.setObjectName("caption")
        self.audio.setWordWrap(True)
        self.audio.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.rom_line = QLabel()
        self.rom_line.setObjectName("caption")
        self.rom_line.setWordWrap(True)
        self.rom_line.setTextInteractionFlags(Qt.TextSelectableByMouse)
        for w in (self.ffmpeg, self.audio, self.rom_line):
            w.setVisible(False)
            lay.addWidget(w)
        self.chips = {}
        for key, tip, fix in (
                ("sound", "Can sound play here? Click to look again (after installing the "
                          "full pyside6 or plugging in a speaker).", self.check_audio),
                ("rom", "Your own Super Mario 64 ROM gives the game's real instruments. "
                        "Click to choose it - it is only read, never copied.", self.choose_rom),
                ("ffmpeg", "ffmpeg turns any recording into the game's .ogg.", self._say_ffmpeg)):
            chip = QToolButton()
            chip.setObjectName("musicChip")
            chip.setAutoRaise(True)
            chip.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
            chip.setCursor(Qt.PointingHandCursor)
            chip.setProperty("tip", tip)
            chip.clicked.connect(lambda _=False, fix=fix: (fix(), self._chips()))
            map_row.addWidget(chip)
            self.chips[key] = chip
        self.check_audio()
        from studio.editor.qt.wish_chips import FlowLayout
        row_w = QWidget()
        row = FlowLayout(row_w, spacing=6)
        self.search = QLineEdit()
        self.search.setMinimumWidth(200)
        self.search.setPlaceholderText("Search: title, game, artist...")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self.fill)
        row.addWidget(self.search)
        imp = QPushButton("Import...")
        imp.setObjectName("primary")
        imp.setToolTip("Music files (%s, or m64 sequences) or a folder of them - a "
                       "recording becomes an .ogg at the quality you pick"
                       % musiclib.music().IMPORT_WORDS)
        imp.clicked.connect(self.import_files)
        folder = QPushButton("Folder...")
        folder.clicked.connect(self.import_folder)
        self.sort = QComboBox()
        self.sort.addItem("Sort by...", None)
        for key in musiclib.SORTS:
            self.sort.addItem(key, key)
        self.sort.setToolTip("Sort the list by a key (dragging a row makes the order your own)")
        self.sort.activated.connect(self._sort)
        from PySide6.QtWidgets import QMenu, QToolButton
        self.cats = QToolButton()
        self.cats.setText("Categories")
        self.cats.setPopupMode(QToolButton.InstantPopup)
        self.cats.setToolTip("Make, rename and delete the categories the menu shows and the "
                             "folders in them. Drag a track onto one to file it there, or "
                             "right-click it: Move to...")
        menu = QMenu(self.cats)
        menu.addAction("New category...", lambda: self.new_category(None))
        menu.addAction("New folder in the selected category...", self.new_folder_here)
        menu.addAction("Rename the selected category...", self.rename_here)
        menu.addAction("Delete the selected category...", self.delete_here)
        self.cats.setMenu(menu)
        row.addWidget(imp)
        row.addWidget(folder)
        row.addWidget(self.cats)
        row.addWidget(self.sort)
        lay.addWidget(row_w)
        self.setAcceptDrops(True)
        split = QSplitter(Qt.Horizontal)
        self.table = Tree(self)
        self.table.itemSelectionChanged.connect(self.show_row)
        split.addWidget(self.table)
        side = QWidget()
        form = QFormLayout(side)
        self.f_title = QLineEdit()
        self.f_game = QLineEdit()
        self.f_artist = QLineEdit()
        self.f_about = QLineEdit()
        self.f_about.setPlaceholderText("free text, may stay empty")
        self.f_about.setToolTip("The line under the menu: anything about the song. The row "
                                "itself already says the title and who made it.")
        self.f_row = QLabel()
        self.f_row.setObjectName("caption")
        self.f_row.setWordWrap(True)
        for w in (self.f_title, self.f_game, self.f_artist):
            w.textChanged.connect(self._row_preview)
        self.f_category = QComboBox()
        self.f_volume = QSpinBox()
        self.f_volume.setRange(0, 127)
        self.f_volume.setToolTip("0-127; the mod's default when untouched")
        self.f_info = QLabel()
        self.f_info.setObjectName("caption")
        self.f_info.setWordWrap(True)
        for label, w in (("Title", self.f_title), ("Game", self.f_game),
                         ("Artist", self.f_artist), ("Description", self.f_about),
                         ("In the menu", self.f_row), ("Category", self.f_category),
                         ("Volume", self.f_volume)):
            form.addRow(label, w)
        form.addRow(self.f_info)
        from studio.ui.reflow import ReflowGrid
        buttons = ReflowGrid(max_cols=4, min_cols=2, spacing=4)
        save = QPushButton("Save changes")
        save.setToolTip("Write the title, game, artist, description, category and volume "
                        "into the registry")
        save.clicked.connect(self.save_row)
        self.save = save
        self.play = QPushButton("Play")
        self.play.setToolTip("Preview the track here - a recording as it is, a .m64 sequence "
                             "with the game's own instruments from your ROM (a sketch with "
                             "plain tones when there is none)")
        self.play.clicked.connect(self.toggle_play)
        remove = QPushButton("Remove...")
        remove.setToolTip("Out of the mod; its id is retired so a saved pick of it plays "
                          "another track or the level's own music")
        remove.clicked.connect(self.remove_row)
        self.remove = remove
        buttons.add(save)
        buttons.add(self.play)
        self.use = QPushButton("Use for this map")
        self.use.setToolTip("Make this track the open map's music (one undo step); the list "
                            "marks it with \u266a")
        self.use.clicked.connect(self.use_current)
        buttons.add(self.use)
        buttons.add(remove)
        form.addRow(buttons)
        self.play_note = QLabel()
        self.play_note.setObjectName("caption")
        self.play_note.setWordWrap(True)
        form.addRow(self.play_note)
        from PySide6.QtWidgets import QFrame, QScrollArea
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(side)
        split.addWidget(scroll)
        split.setSizes([640, 320])
        self.table.setMinimumHeight(60)
        lay.addWidget(split, 1)
        self.meter = QLabel()
        self.meter.setObjectName("caption")
        self.meter.setWordWrap(True)
        lay.addWidget(self.meter)
        self.reload()
    def rom_choice(self):
        try:
            return (self.lib.studio.settings.state or {}).get("music_rom")
        except AttributeError:
            return None
    def find_rom(self):
        self.rom, line = musiclib.rom_status(self.rom_choice())
        self.rom_line.setText(line)
        self.rom_line.setStyleSheet("color: %s" % self.lib.tokens["ok" if self.rom else "warn"])
        self._chips()
        return self.rom
    def choose_rom(self):
        path, _ = QFileDialog.getOpenFileName(self, "Your Super Mario 64 ROM",
                                              os.path.expanduser("~"),
                                              "N64 ROM (*.z64 *.n64 *.v64);;All files (*)")
        if path:
            self.set_rom(path)
    def set_rom(self, path):
        try:
            settings = self.lib.studio.settings
            if settings.state is None:
                settings.state = {}
            settings.state["music_rom"] = path
        except AttributeError:
            pass
        self.reload()
    def show_list(self, key, select=None):
        self.list_key = key
        self.reload(select)
        for i in range(self.table.topLevelItemCount()):
            top = self.table.topLevelItem(i)
            fold = top.data(0, Qt.UserRole + 1)
            if fold == key or (key not in ("vanilla",) and fold != "vanilla" and (
                    key in ("mod", "imported") or top.data(0, FOLDER) == key)):
                top.setExpanded(True)
                self.table.scrollToItem(top)
        if select is not None:
            for it in self.table.tracks():
                if it.data(0, Qt.UserRole) == select:
                    parent = it.parent()
                    while parent is not None:
                        parent.setExpanded(True)
                        parent = parent.parent()
                    self.table.scrollToItem(it)
    def folds(self):
        try:
            state = self.lib.studio.settings.state
        except AttributeError:
            return {}
        return (state or {}).get(FOLD_STATE) or {}
    def folded(self, item, open_):
        key = item.data(0, Qt.UserRole + 1)
        if not key or self._filling:
            return
        try:
            settings = self.lib.studio.settings
            if settings.state is None:
                settings.state = {}
            settings.state.setdefault(FOLD_STATE, {})[key] = bool(open_)
        except AttributeError:
            pass
    _filling = False
    def _row_preview(self, *_):
        label = musiclib.music().row_label({"name": self.f_title.text().strip(),
                                            "artist": self.f_artist.text().strip(),
                                            "game": self.f_game.text().strip()})
        self.f_row.setText(label + ("  (scrolls in the menu)" if musiclib.scrolls(label)
                                    else ""))
    def reload(self, select=None):
        self.find_rom()
        try:
            first = not getattr(self, "_cleaned", False)
            self._cleaned = True
            self.reg = musiclib.load(musiclib.target(self.ed), clean=first)
        except Exception as why:
            self.reg = None
            self.meter.setText("The music registry could not be read: %s" % why)
            return
        self.rows = musiclib.vanilla_rows(self.rom) + musiclib.rows(self.reg)
        self.folders = musiclib.folder_tree(self.reg)
        cats = musiclib.categories(self.reg)
        self.f_category.clear()
        for key, label in cats:
            self.f_category.addItem(label, key)
        have, said = musiclib.ffmpeg_status()
        self.ffmpeg.setText(said)
        self.ffmpeg.setStyleSheet("color: %s" % self.lib.tokens["ok" if have else "warn"])
        self._ffmpeg_ok = bool(have)
        self._chips()
        self.measure_download()
        self.fill(select=select)
        self.refresh_map()
    def measure_download(self, wait=False):
        import concurrent.futures
        if getattr(self, "_meter_pool", None) is None:
            self._meter_pool = concurrent.futures.ThreadPoolExecutor(max_workers=1)
            self._meter_timer = QTimer(self)
            self._meter_timer.setInterval(100)
            self._meter_timer.timeout.connect(self._meter_ready)
        self.meter.setText("Measuring the mod's download...")
        self._meter_job = (self._meter_pool.submit(musiclib.meter, self.reg), self.reg)
        self._meter_timer.start()
        if wait:
            self._meter_job[0].result()
            self._meter_ready()
    def _meter_ready(self):
        future, reg = self._meter_job
        if not future.done():
            return
        self._meter_timer.stop()
        if reg is not self.reg:
            return
        try:
            m = future.result()
        except Exception as why:
            self.meter.setText("The download could not be measured: %s" % why)
            return
        vanilla = sum(1 for r in self.rows if r.get("vanilla") is not None)
        self.meter.setText("%d vanilla tracks%s, in nobody's download; %d of the mod's, "
                           "order: %s - music %s of the mod's %s release download (budget "
                           "%s)\nthe mod folder %s: %s"
                           % (vanilla, "" if self.rom else " (no ROM: listed, not playable)",
                              len(self.rows) - vanilla, self.reg.order,
                              kb(m["music_bytes"]), kb(m["shipped_bytes"]),
                              kb(m["budget_bytes"]), self.reg.root,
                              m.get("wall_line", "")))
    def fill(self, *_, select=None):
        searching = bool(self.search.text().strip())
        shown = musiclib.search(self.rows, self.search.text())
        folds = self.folds()
        self._filling = True
        self.table.clear()
        chosen = []
        dim = QColor(self.lib.tokens.get("muted", "#888888")) if hasattr(
            self.lib, "tokens") else QColor("#888888")
        def track(parent, r):
            mod = r.get("vanilla") is None
            kind = r["kind"] + (" bank %d" % r["bank"] if r["bank"] else "")
            if mod and not r.get("imported"):
                kind += ", ships"
            it = QTreeWidgetItem([r["title"], r["artist"], kind,
                                  "%.0f" % (r["bytes"] / 1024.0)])
            it.setData(0, Qt.UserRole, r["id"])
            it.setData(0, TITLE, r["title"])
            it.setToolTip(0, "%s\n%s%s" % (r.get("label") or r["title"], r["about"],
                                           "" if not mod or r.get("imported") else
                                           "\n(ships with the mod)"))
            it.setFlags(it.flags() & ~Qt.ItemIsDropEnabled if not mod else it.flags())
            parent.addChild(it)
            if r["id"] == select:
                chosen.append(it)
        def node(parent, n, depth):
            count = musiclib.count_rows(n)
            item = QTreeWidgetItem(["%s  (%d)" % (n["label"], count)])
            item.setData(0, Qt.UserRole + 1, n["fold"])
            if n.get("folder"):
                item.setData(0, FOLDER, n["folder"])
                item.setToolTip(0, "%s - %s. Drop a track here to file it; right-click to "
                                "rename or delete%s." % (
                                    n["label"], "a category: a heading of its own in the "
                                    "game's Music page" if depth == 0 else "a folder inside it",
                                    "" if depth else ", or to make a folder inside"))
                item.setFlags(item.flags() & ~Qt.ItemIsDragEnabled | Qt.ItemIsDropEnabled)
            else:
                item.setFlags(item.flags() & ~Qt.ItemIsDragEnabled & ~Qt.ItemIsDropEnabled)
            if depth == 0:
                f = item.font(0)
                f.setBold(True)
                item.setFont(0, f)
            if count == 0:
                item.setForeground(0, dim)
            if parent is None:
                self.table.addTopLevelItem(item)
            else:
                parent.addChild(item)
            for r in n["rows"]:
                track(item, r)
            for k in n["children"]:
                node(item, k, depth + 1)
            item.setExpanded(searching or folds.get(n["fold"], True))
        for n in musiclib.tree(shown, getattr(self, "folders", None), keep_empty=not searching):
            if searching and musiclib.count_rows(n) == 0:
                continue
            node(None, n, 0)
        chosen = chosen[0] if chosen else None
        self._filling = False
        if chosen is not None:
            self.table.setCurrentItem(chosen)
        if self._playing_id is not None:
            self._now_playing(self._playing_id, getattr(self, "_playing_title", ""))
        self.mark_map()
        self.table.resizeColumnToContents(1)
    def select_id(self, ident):
        for it in self.table.tracks():
            if it.data(0, Qt.UserRole) == ident:
                self.table.setCurrentItem(it)
                return True
        return False
    def count(self, category=None):
        return sum(1 for it in self.table.tracks()
                   if category is None or musiclib.category_of(next(
                       r for r in self.rows if r["id"] == it.data(0, Qt.UserRole))) == category)
    def current(self):
        items = self.table.selectedItems()
        if not items:
            return None
        ident = items[0].data(0, Qt.UserRole)
        return next((r for r in self.rows if r["id"] == ident), None)
    def show_row(self):
        r = self.current()
        if r is None:
            return
        self.f_title.setText(r["title"])
        self.f_game.setText(r["game"])
        self.f_artist.setText(r["artist"])
        self.f_about.setText(r.get("about") or "")
        self._row_preview()
        self.f_category.setCurrentIndex(max(0, self.f_category.findData(r["category"])))
        self.f_volume.setValue(r["volume"] if r["volume"] is not None else 127)
        self.f_info.setText("id %s - %s, %s%s%s" % (
            r["id"], r["kind"], kb(r["bytes"]), (", bank %d" % r["bank"]) if r["bank"] else "",
            (", loops %s-%s" % r["loop"]) if r["loop"] else ""))
        vanilla = r.get("vanilla") is not None
        sequence = vanilla or r["path"].lower().endswith(".m64")
        self.use.setEnabled(r["id"] != self.map_key())
        self.save.setEnabled(not vanilla)
        self.remove.setEnabled(not vanilla)
        self.play.setEnabled(r["playable"] or (sequence and not vanilla))
        if vanilla and self.rom is None:
            self.play_note.setText("The vanilla music is in your own ROM, and none was found. "
                                   + self.rom_line.text())
        elif sequence and self.rom is not None:
            self.play_note.setText("A .m64 is a sequence: Play runs it with the game's own "
                                   "instruments from your ROM (sound bank %s)." % (
                                       ", ".join(str(b) for b in r.get("banks") or [r["bank"]])))
        elif sequence:
            self.play_note.setText("A .m64 is a sequence: Play sings a sketch of it - its notes, "
                                   "rhythm and tempo with plain tones, because no ROM was found "
                                   "for its instruments (sound bank %d). %s"
                                   % (r["bank"] or 0, self.rom_line.text()))
        else:
            self.play_note.setText("")
    def _guard(self, fn, ok_msg, select=None):
        m = musiclib.music()
        try:
            fn()
        except m.MusicError as why:
            QMessageBox.warning(self, "Not changed", str(why))
            self.reload(select)
            return False
        self.reload(select)
        self.lib.ed.hint(ok_msg)
        return True
    def save_row(self):
        r = self.current()
        if r is None or r.get("vanilla") is not None:
            return
        vol = self.f_volume.value()
        self._guard(lambda: musiclib.edit(
            self.reg, r["id"], title=self.f_title.text().strip(), game=self.f_game.text().strip(),
            artist=self.f_artist.text().strip() or None,
            about=self.f_about.text().strip(),
            category=self.f_category.currentData(),
            volume=None if (r["volume"] is None and vol == 127) else vol),
            "Saved %s" % r["id"], r["id"])
    def remove_row(self):
        r = self.current()
        if r is None or r.get("vanilla") is not None:
            return
        others = ["(the level's own music)"] + [x["id"] for x in self.rows if x["id"] != r["id"]
                                                 and x.get("vanilla") is None]
        to, ok = QInputDialog.getItem(self, "Remove %s" % r["title"],
                                      "Its id is retired. A saved pick of it plays:", others, 0,
                                      False)
        if not ok:
            return
        self.stop()
        from .. import trash
        def remove():
            trash.keep("music", "Track %s" % r["title"], [self.reg.path] + (
                [r["path"]] if r.get("path") else []))
            return musiclib.remove(self.reg, r["id"], None if to.startswith("(") else to)
        self._guard(remove, "Removed %s (retired) - Library > Recently removed brings it "
                    "back" % r["id"])
    def dropped_on(self, target):
        r = self.current()
        if r is None or r.get("vanilla") is not None:
            self.lib.ed.hint("The vanilla music keeps the game's order")
            return
        if self.search.text().strip():
            self.lib.ed.hint("Clear the search to drag tracks into order")
            return
        ids = [x["id"] for x in self.rows if x.get("vanilla") is None]
        if target not in ids or target == r["id"]:
            return
        there = next(x for x in self.rows if x["id"] == target)
        def move():
            if there["category"] != r["category"]:
                musiclib.move_to_category(self.reg, [r["id"]], there["category"])
            musiclib.move(self.reg, r["id"], before=target)
        self._guard(move, "Moved %s - the order is your own now" % r["id"], r["id"])
    def dropped_into(self, key):
        r = self.current()
        if r is None or r.get("vanilla") is not None:
            self.lib.ed.hint("The vanilla music is the game's own and is not filed")
            return
        self.move_to(r, key)
    def folder_name(self, key):
        return dict(musiclib.categories(self.reg)).get(key) or next(
            (c["label"] for c in self.folders if c["key"] == key), key)
    def move_to(self, r, key):
        if r["category"] == key:
            return
        self._guard(lambda: musiclib.move_to_category(self.reg, [r["id"]], key),
                    "Moved %s to %s" % (r["title"], self.folder_name(key)), r["id"])
    def selected_folder(self):
        it = self.table.currentItem()
        while it is not None and not it.data(0, FOLDER):
            it = it.parent()
        if it is None:
            return None, False
        return it.data(0, FOLDER), it.parent() is None
    def ask_name(self, title, said, text=""):
        name, ok = QInputDialog.getText(self, title, said, QLineEdit.Normal, text)
        return name.strip() if ok and name.strip() else None
    def new_category(self, name=None):
        name = name or self.ask_name("New category", "Its name - a heading of its own in the "
                                     "game's Music page (e.g. My music, Chill, Boss fights):")
        if not name:
            return None
        made = []
        ok = self._guard(lambda: made.append(musiclib.add_category(self.reg, name)),
                         "Made the category %s" % name)
        return made[0] if ok and made else None
    def new_folder(self, under, name=None):
        name = name or self.ask_name("New folder in %s" % self.folder_name(under),
                                     "Its name (a sub-heading under %s):"
                                     % self.folder_name(under))
        if not name:
            return None
        made = []
        ok = self._guard(lambda: made.append(musiclib.add_category(self.reg, name, under)),
                         "Made the folder %s" % name)
        return made[0] if ok and made else None
    def new_folder_here(self):
        key, top = self.selected_folder()
        if key is None or not top:
            it = self.table.currentItem()
            while it is not None and it.parent() is not None:
                it = it.parent()
            key = it.data(0, FOLDER) if it is not None else None
        if key is None:
            self.lib.ed.hint("Select a category first (or make one with New category...)")
            return None
        return self.new_folder(key)
    def rename_folder(self, key, name=None):
        if key == "games":
            self.lib.ed.hint("'From other games' is the game's own heading and keeps its name")
            return False
        old = self.folder_name(key).split(" / ")[-1]
        name = name or self.ask_name("Rename %s" % old, "Its new name (the tracks in it "
                                     "stay):", old)
        if not name or name == old:
            return False
        return self._guard(lambda: musiclib.rename_category(self.reg, key, name),
                           "Renamed %s to %s" % (old, name))
    def rename_here(self):
        key, _ = self.selected_folder()
        if key is not None:
            self.rename_folder(key)
    def delete_folder(self, key, move_to=None, ask=True):
        if key in ("games", "other"):
            self.lib.ed.hint("'%s' stays: %s" % (
                self.folder_name(key), "it is the game's own heading" if key == "games"
                else "a track filed nowhere else lands there"))
            return False
        name = self.folder_name(key)
        held = musiclib.folder_tracks(self.reg, key)
        if held and move_to is None:
            if not ask:
                return False
            inside = {key} | {f["key"] for c in self.folders if c["key"] == key
                              for f in c["folders"]}
            others = [(k, l) for k, l in musiclib.categories(self.reg) if k not in inside]
            pick, ok = QInputDialog.getItem(
                self, "Delete %s" % name, "%s holds %d track(s). Move them to:" % (
                    name, len(held)), [l for _, l in others], 0, False)
            if not ok:
                return False
            move_to = dict((l, k) for k, l in others)[pick]
        elif ask and QMessageBox.question(self, "Delete %s" % name,
                                          "Delete the empty %s?" % name) != QMessageBox.Yes:
            return False
        from .. import trash
        def go():
            trash.keep("music", "Category %s" % name, [self.reg.path])
            musiclib.delete_category(self.reg, key, move_to)
        return self._guard(go, "Deleted %s%s - Library > Recently removed brings it back"
                           % (name, (" (its tracks moved to %s)" % self.folder_name(move_to))
                                    if held else ""))
    def delete_here(self):
        key, _ = self.selected_folder()
        if key is not None:
            self.delete_folder(key)
    def folder_menu(self, item, pos):
        from PySide6.QtWidgets import QMenu
        key = item.data(0, FOLDER) if item is not None else None
        m = QMenu(self)
        new_cat = m.addAction("New category...")
        new_sub = rename = delete = None
        if key is not None:
            top = item.parent() is None
            if top:
                new_sub = m.addAction("New folder in %s..." % self.folder_name(key))
            m.addSeparator()
            rename = m.addAction("Rename...")
            rename.setEnabled(key != "games")
            delete = m.addAction("Delete...")
            delete.setEnabled(key not in ("games", "other"))
        got = m.exec(self.table.viewport().mapToGlobal(pos))
        if got is new_cat:
            self.new_category()
        elif got is not None and got is new_sub:
            self.new_folder(key)
        elif got is not None and got is rename:
            self.rename_folder(key)
        elif got is not None and got is delete:
            self.delete_folder(key)
    def _sort(self, *_):
        key = self.sort.currentData()
        self.sort.setCurrentIndex(0)
        if key:
            sel = self.current()
            self._guard(lambda: musiclib.sort(self.reg, key), "Sorted by %s" % key,
                        sel["id"] if sel else None)
    def dragEnterEvent(self, ev):
        if ev.mimeData().hasUrls():
            ev.acceptProposedAction()
    def dropEvent(self, ev):
        paths = [u.toLocalFile() for u in ev.mimeData().urls() if u.isLocalFile()]
        if paths:
            self.import_paths(paths)
    def import_files(self):
        paths, _ = QFileDialog.getOpenFileNames(
            self, "Music to import", os.path.expanduser("~"),
            musiclib.file_filter())
        if paths:
            self.import_paths(paths)
    def import_folder(self):
        d = QFileDialog.getExistingDirectory(self, "A folder of music", os.path.expanduser("~"))
        if d:
            self.import_paths([d])
    def import_paths(self, paths):
        files = musiclib.importable(paths)
        if not files:
            QMessageBox.information(self, "Import", "No music files there (%s, or m64 "
                                    "sequences)." % musiclib.music().IMPORT_WORDS)
            return
        blocked = musiclib.needs_ffmpeg(paths) if not musiclib.ffmpeg_status()[0] else []
        if blocked:
            QMessageBox.warning(self, "ffmpeg is missing", "%s\n\n%s" % (
                musiclib.ffmpeg_status()[1], "Needs it: " + ", ".join(
                    os.path.basename(p) for p in blocked[:8])))
            return
        self.review = ImportReview(self, musiclib.plan_tracks(paths), self.reg)
        if self.review.exec() != ImportReview.Accepted:
            return
        self.import_reviewed(self.review)
    def import_reviewed(self, review):
        tracks = review.tracks
        fields = {"folder_artist": review.artist.text().strip(),
                  "folder_game": review.game.text().strip()}
        if any(t.path.lower().endswith(".m64") for t in tracks):
            fields["bank"] = review.bank.value()
        fields.update(review.choice())
        into = review.category() if hasattr(review, "category") else None
        if into:
            fields["category"] = into
            try:
                settings = self.lib.studio.settings
                if settings.state is None:
                    settings.state = {}
                settings.state[IMPORT_INTO] = into
            except AttributeError:
                pass
        reg = self.reg
        def job(progress, cancelled):
            progress(0, 0, "converting and checking %d file(s)" % len(tracks))
            return musiclib.import_tracks(reg, tracks, **fields)
        def done(res):
            ids, notes = res
            self.show_list(into or "imported", ids[0] if ids else None)
            self.lib.ed.hint("Imported %s%s" % (", ".join(ids) or "nothing",
                                                ("; " + "; ".join(notes)) if notes else ""))
            refused = [n for n in notes if not n.startswith("taken as it is")]
            if refused:
                QMessageBox.information(self, "Imported %d of %d" % (len(ids), len(tracks)),
                                        "Not imported:\n\n" + "\n\n".join(refused))
        def failed(why):
            QMessageBox.warning(self, "Not imported", why)
            self.reload()
        if not self.lib.ed.jobs.run("Importing music", job, done, failed):
            failed("Oldfart Studio is busy - try again in a moment")
    def play_item(self, item):
        ident = item.data(0, Qt.UserRole) if item is not None else None
        if not ident:
            return False
        if self.table.currentItem() is not item:
            self.table.setCurrentItem(item)
        self.toggle_play()
        return True
    def menu_at(self, pos):
        item = self.table.itemAt(pos)
        if item is None or not item.data(0, Qt.UserRole):
            if item is None or item.data(0, FOLDER):
                self.folder_menu(item, pos)
            return
        self.table.setCurrentItem(item)
        r = self.current()
        if r is None:
            return
        from PySide6.QtWidgets import QMenu
        m = QMenu(self)
        playing = self._playing and self._playing_id == r["id"]
        play = m.addAction("Stop" if playing else "Play  (double-click, Enter)")
        use = m.addAction("Use as this map's music")
        use.setEnabled(r["id"] != self.map_key())
        along = m.addAction("Take along with this map (export for other mods)")
        along.setCheckable(True)
        along.setChecked(r["id"] in musiclib.map_playlist(self.ed.session.doc))
        along.setEnabled(r.get("vanilla") is None)
        edit = m.addAction("Edit the title")
        vanilla = r.get("vanilla") is not None
        edit.setEnabled(not vanilla)
        into = m.addMenu("Move to")
        into.setEnabled(not vanilla)
        targets = {}
        for key, label in musiclib.categories(self.reg) if not vanilla else []:
            a = into.addAction(label)
            a.setEnabled(key != r.get("category"))
            targets[a] = key
        m.addSeparator()
        remove = m.addAction("Remove...  (Delete)")
        remove.setEnabled(not vanilla)
        got = m.exec(self.table.viewport().mapToGlobal(pos))
        if got is along:
            self.take_along(r["id"])
        elif got is play:
            self.toggle_play()
        elif got is use:
            self.use_for_map(r["id"])
        elif got is edit:
            self.f_title.setFocus()
            self.f_title.selectAll()
        elif got in targets:
            self.move_to(r, targets[got])
        elif got is remove:
            self.remove_row()
    def toggle_play(self):
        r = self.current()
        if self._player is not None and self._playing:
            if r is None or r["id"] == self._playing_id:
                self.stop()
                return
            self.stop()
        if r is None:
            return
        sequence = r.get("vanilla") is not None or r["path"].lower().endswith(".m64")
        if not r["playable"] and not sequence:
            return
        if r.get("vanilla") is not None and self.rom is None:
            self.play_note.setText("The vanilla music is in your own ROM, and none was found. "
                                   + self.rom_line.text())
            return
        ok, line, _ = musiclib.audio_status()
        if not ok:
            self.play_note.setText(line)
            self.audio.setText(line)
            return
        classes, why = musiclib.player()
        if classes is None:
            self.play_note.setText(why)
            return
        if sequence:
            return self._play_sketch(r, classes)
        self._start(classes, r["path"], "Playing %s" % r["title"], r)
    _playing = False
    _playing_id = None
    def check_audio(self):
        ok, line, devices = musiclib.audio_status()
        self.audio.setText(line if ok else "<b>No sound here.</b> " + line)
        self.audio.setToolTip("\n".join(devices) if devices else line)
        self._audio_ok = bool(ok)
        self._chips()
        return ok
    _audio_ok = None
    _ffmpeg_ok = None
    def _say_ffmpeg(self):
        self.lib.ed.hint(self.ffmpeg.text())
    def _chips(self):
        chips = getattr(self, "chips", None)
        if not chips:
            return None
        import re as _re
        plain = lambda w: _re.sub(r"<[^>]+>", "", w.text())
        state = {"sound": (self._audio_ok, "Sound", plain(self.audio)),
                 "rom": (self.rom is not None if hasattr(self, "rom") else None, "ROM",
                         plain(self.rom_line)),
                 "ffmpeg": (self._ffmpeg_ok, "ffmpeg", plain(self.ffmpeg))}
        for key, (ok, name, said) in state.items():
            chip = chips[key]
            mark = "\u2713" if ok else ("!" if ok is not None else "\u2026")
            chip.setText("%s %s" % (mark, name))
            chip.setProperty("ok", "true" if ok else "false")
            chip.style().unpolish(chip)
            chip.style().polish(chip)
            chip.setToolTip("%s\n\n%s" % (said or name, chip.property("tip")))
        return state
    def _play_sketch(self, r, classes):
        import tempfile
        folder = os.path.join(tempfile.gettempdir(), "oldfart-studio-sketches")
        os.makedirs(folder, exist_ok=True)
        out = os.path.join(folder, "%s.wav" % r["id"])
        rom = self.rom
        self.play_note.setText(("Rendering %s with your ROM's instruments..." if rom else
                                "Sketching %s...") % r["title"])
        def job(progress, cancelled):
            return musiclib.preview(r, out, rom=rom, seconds=60)
        def done(res):
            path, said, mode, why = res
            if mode == "real":
                note = "%s with the game's own instruments (sound bank %s): %s." % (
                    r["title"], ", ".join(str(b) for b in r.get("banks") or [r["bank"]]), said)
            else:
                note = "A sketch of %s: %s. Plain tones - %s." % (
                    r["title"], said, why if why and why != "no ROM" else
                    "the instruments are in your ROM, and none was found")
            self._start(classes, path, note, r)
        def failed(why):
            self.play_note.setText("This sequence could not be played: %s" %
                                   why.splitlines()[0])
        if not self.lib.ed.jobs.run("Rendering a sequence", job, done, failed):
            failed("Oldfart Studio is busy - try again in a moment")
    def _start(self, classes, path, note, r=None):
        Player, Output = classes
        if self._player is None:
            self._player = Player(self)
            self._output = Output(self)
            self._player.setAudioOutput(self._output)
            try:
                self._player.playbackStateChanged.connect(self._state_changed)
            except AttributeError:
                pass
        self._player.setSource(QUrl.fromLocalFile(path))
        self._player.play()
        self._now_playing(r["id"] if r else None, r["title"] if r else "")
        self.play_note.setText(note)
    def _now_playing(self, ident, title=""):
        self._playing = ident is not None
        self._playing_id = ident
        self._playing_title = title
        self.play.setText("Stop" if self._playing else "Play")
        for it in self.table.tracks():
            f = it.font(0)
            f.setBold(ident is not None and it.data(0, Qt.UserRole) == ident)
            it.setFont(0, f)
    def _state_changed(self, state):
        stopped = getattr(type(self._player), "PlaybackState", None)
        stopped = getattr(stopped, "StoppedState", 0) if stopped is not None else 0
        if state == stopped and self._playing:
            title = getattr(self, "_playing_title", "")
            self._now_playing(None)
            if title:
                self.play_note.setText("Finished: %s" % title)
    def stop(self):
        playing = self._playing
        self._now_playing(None)
        if self._player is not None and playing:
            self._player.stop()
    def map_key(self):
        try:
            return musiclib.map_music(self.ed.session.doc)[0] or AUTO
        except AttributeError:
            return AUTO
    def track_name(self, key):
        if key in (None, "", AUTO):
            return "auto - the theme's music"
        r = next((x for x in self.rows if x["id"] == key), None)
        return (r.get("label") or r["title"]) if r else key
    def refresh_map(self):
        doc = self.ed.session.doc
        asked, plays = musiclib.map_music(doc)
        self.map_pick.setText("%s  \u25be" % elide(self.track_name(asked or AUTO)))
        self.map_said.setText("now: %s" % (self.track_name(plays) if plays
                                           else "the level's own"))
        self.mark_map()
        if hasattr(self, "use"):
            r = self.current()
            self.use.setEnabled(r is not None and r["id"] != asked)
    def mark_map(self):
        key = self.map_key() if hasattr(self, "map_pick") else None
        try:
            along = set(musiclib.map_playlist(self.ed.session.doc))
        except AttributeError:
            along = set()
        for it in self.table.tracks():
            title = it.data(0, TITLE) or it.text(0)
            tid = it.data(0, Qt.UserRole)
            mine = tid == key
            text = (MAP_MARK + title) if mine else title
            if tid in along:
                text = ALONG_MARK + text
            it.setText(0, text)
            tip = it.toolTip(0).replace("\nThis map's music", "").replace(
                "\nTaken along with this map", "")
            it.setToolTip(0, tip + ("\nThis map's music" if mine else "")
                          + ("\nTaken along with this map" if tid in along else ""))
    def open_map_picker(self):
        from PySide6.QtCore import QPoint
        self.picker = MapPicker(self)
        self.picker.move(self.map_pick.mapToGlobal(QPoint(0, self.map_pick.height())))
        self.picker.show()
        self.picker.search.setFocus()
        return self.picker
    def use_for_map(self, key):
        change = musiclib.set_map_music(self.ed.session.doc, key)
        if change:
            self.ed.push(change)
        self.refresh_map()
        self.lib.ed.hint("This map plays %s" % self.track_name(key))
    def use_current(self):
        r = self.current()
        if r is not None:
            self.use_for_map(r["id"])
    def take_along(self, key):
        change, on = musiclib.toggle_take_along(self.ed.session.doc, key)
        if change:
            self.ed.push(change)
        self.refresh_map()
        n = len(musiclib.map_playlist(self.ed.session.doc))
        self.lib.ed.hint("%s %s - %d track%s go along with this map's export" % (
            "Taking along" if on else "Not taking along", self.track_name(key), n,
            "" if n == 1 else "s"))
        return on
class ImportReview(QDialog):
    REVIEW_COLS = ("File", "Title", "Artist", "Game", "Length", "Size", "Description",
                   "In the menu", "Read from")
    LENGTH, SIZE, ABOUT, MENU, SOURCE = 4, 5, 6, 7, 8
    EDITABLE = {1: "title", 2: "artist", 3: "game", 6: "about"}
    def __init__(self, panel, tracks, reg=None):
        super().__init__(panel)
        self.setWindowTitle("Import music")
        self.tracks = tracks
        self.reg = reg if reg is not None else musiclib.load(
            musiclib.target(getattr(panel, "ed", None)))
        try:
            self.release = musiclib.music().wall_bytes(self.reg.root)
        except Exception:
            self.release = 0
        self._filling = True
        lay = QVBoxLayout(self)
        intro = QLabel("Each track as its file describes it. Change anything in the list - "
                       "an empty artist or game takes the folder's.")
        intro.setWordWrap(True)
        intro.setObjectName("caption")
        lay.addWidget(intro)
        self.table = QTableWidget(len(tracks), len(self.REVIEW_COLS))
        self.table.setHorizontalHeaderLabels(self.REVIEW_COLS)
        self.table.verticalHeader().setVisible(False)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
        def fixed(text, tip=""):
            it = QTableWidgetItem(text)
            it.setFlags(it.flags() & ~Qt.ItemIsEditable)
            if tip:
                it.setToolTip(tip)
            return it
        for n, t in enumerate(tracks):
            length = ("%d:%02d" % divmod(int(round(t.seconds)), 60)) if t.seconds else ""
            for col, it in enumerate((
                    fixed(os.path.basename(t.path), t.path), QTableWidgetItem(t.title),
                    QTableWidgetItem(t.artist), QTableWidgetItem(t.game),
                    fixed(length), fixed(""), QTableWidgetItem(t.about), fixed(""),
                    fixed(t.source, "mutagen / ffprobe / tags: the file's own tags; file "
                          "name: read off its name"))):
                self.table.setItem(n, col, it)
        self.table.item(0, self.ABOUT) and self.table.item(0, self.ABOUT).setToolTip(
            "Free text under the menu row; written from the file (length, BPM, genre, year, "
            "album) - change it, or empty it")
        self.table.resizeColumnsToContents()
        self.table.setColumnWidth(0, min(self.table.columnWidth(0), 200))
        self.table.itemChanged.connect(self._edited)
        lay.addWidget(self.table, 1)
        form = QFormLayout()
        self.artist = QLineEdit(musiclib.folder_artist([t.path for t in tracks], tracks))
        self.artist.setPlaceholderText("who made the tracks that name nobody")
        self.artist.setToolTip("Used for every track whose artist is empty")
        self.artist.textChanged.connect(self._check)
        self.game = QLineEdit()
        self.game.setPlaceholderText("optional")
        self.game.setToolTip("Used for every track whose game is empty")
        self.game.textChanged.connect(self._check)
        form.addRow("Folder artist", self.artist)
        form.addRow("Folder game", self.game)
        self.panel = panel
        self.into = QComboBox()
        self.into.setToolTip("The category the tracks go into - a heading in the game's "
                             "Music page. Change it later by dragging a track, or Move to...")
        self.fill_into(self.remembered_into())
        self.into.activated.connect(self._into_picked)
        form.addRow("Goes into", self.into)
        self.bank = QSpinBox()
        self.bank.setRange(1, 63)
        self.bank.setValue(37)
        self.bank.setToolTip("A .m64 sequence needs its sound bank (never guessed)")
        if any(t.path.lower().endswith(".m64") for t in tracks):
            form.addRow("Sound bank (.m64)", self.bank)
        size = QHBoxLayout()
        self.quality = QComboBox()
        for key, label in musiclib.qualities():
            self.quality.addItem(label, key)
        self.quality.setToolTip("How small a recording is made: Ogg Vorbis at an average "
                                "bitrate. Needs ffmpeg.")
        self.mono = QCheckBox("Mono")
        self.mono.setToolTip("One channel instead of two: the same size sounds better, or "
                             "pick a lower quality for half the size")
        self.keep_mp3 = QCheckBox("Keep an mp3 as it is when that is smaller")
        self.keep_mp3.setChecked(True)
        self.keep_mp3.setToolTip("An .mp3 smaller than the .ogg it would become goes in "
                                 "unchanged (not made equally loud)")
        have, said = musiclib.ffmpeg_status()
        for w in (self.quality, self.mono, self.keep_mp3):
            w.setEnabled(have)
            if not have:
                w.setToolTip(said)
        self.quality.currentIndexChanged.connect(self._check)
        self.mono.toggled.connect(self._check)
        self.keep_mp3.toggled.connect(self._check)
        size.addWidget(self.quality, 1)
        size.addWidget(self.mono)
        size.addWidget(self.keep_mp3)
        form.addRow("Quality", size)
        lay.addLayout(form)
        self.sizes = QLabel()
        self.sizes.setWordWrap(True)
        self.sizes.setTextInteractionFlags(Qt.TextSelectableByMouse)
        lay.addWidget(self.sizes)
        self.said = QLabel()
        self.said.setWordWrap(True)
        self.said.setObjectName("caption")
        lay.addWidget(self.said)
        row = QHBoxLayout()
        row.addStretch(1)
        no = QPushButton("Cancel")
        no.setToolTip("Import nothing")
        no.clicked.connect(self.reject)
        self.go = QPushButton("Import %d" % len(tracks))
        self.go.setObjectName("primary")
        self.go.setToolTip("Every track with the fields shown")
        self.go.clicked.connect(self.accept)
        row.addWidget(no)
        row.addWidget(self.go)
        lay.addLayout(row)
        self.resize(1040, 480)
        self._filling = False
        self._check()
    NEW_CATEGORY = "__new__"
    def remembered_into(self):
        try:
            key = (self.panel.lib.studio.settings.state or {}).get(IMPORT_INTO)
        except AttributeError:
            key = None
        if key in dict(musiclib.categories(self.reg)):
            return key
        return musiclib.default_category(self.reg)
    def fill_into(self, key):
        self.into.clear()
        for k, label in musiclib.categories(self.reg):
            self.into.addItem(label, k)
        self.into.addItem("New category...", self.NEW_CATEGORY)
        self.into.setCurrentIndex(max(0, self.into.findData(key)))
    def _into_picked(self, *_):
        if self.into.currentData() != self.NEW_CATEGORY:
            return
        name, ok = QInputDialog.getText(self, "New category", "Its name - a heading of its "
                                        "own in the game's Music page:")
        key = None
        if ok and name.strip():
            try:
                key = musiclib.add_category(self.reg, name.strip())
            except musiclib.music().MusicError as why:
                QMessageBox.warning(self, "Not made", str(why))
        self.fill_into(key or self.remembered_into())
    def category(self):
        key = self.into.currentData()
        return None if key == self.NEW_CATEGORY else key
    def choice(self):
        return {"quality": self.quality.currentData(),
                "channels": 1 if self.mono.isChecked() else 2,
                "mp3_as_is": "smaller" if self.keep_mp3.isChecked() else "never"}
    def _edited(self, item):
        if self._filling:
            return
        t = self.tracks[item.row()]
        field = self.EDITABLE.get(item.column())
        if field:
            setattr(t, field, item.text())
            self._check()
    def _check(self, *_):
        if self._filling:
            return
        readable = [t for t in self.tracks if not getattr(t, "problem", None)]
        bad = [t for t in self.tracks if getattr(t, "problem", None)]
        lacking = musiclib.missing_credit(readable, self.artist.text())
        c = self.choice()
        plan = musiclib.plan(self.reg, readable, c["quality"], c["channels"],
                             c["mp3_as_is"], release_bytes=self.release)
        m = musiclib.music()
        self._filling = True
        warn = QColor(self.palette().color(self.foregroundRole()))
        planned = dict(zip([id(t) for t in readable], plan["tracks"]))
        for n, t in enumerate(self.tracks):
            p = planned.get(id(t))
            if p is None:
                size = self.table.item(n, self.SIZE)
                size.setText("cannot be read")
                size.setToolTip(t.problem)
                size.setForeground(QColor("#d04040"))
                self.table.item(n, 0).setToolTip(t.problem)
                continue
            label = t.label(self.artist.text(), self.game.text())
            wide = musiclib.row_width(label)
            row = self.table.item(n, self.MENU)
            row.setText(label + ("  - scrolls" if wide > m.ROW_WIDTH else ""))
            for col in (1, 2):
                self.table.item(n, col).setToolTip(self.table.item(n, col).text())
            row.setToolTip("%s\n%dpx in the menu's %dpx row%s" % (
                label, wide, m.ROW_WIDTH, " - it scrolls under the cursor, never cut"
                if wide > m.ROW_WIDTH else ""))
            size = self.table.item(n, self.SIZE)
            size.setText(("?" if p["bytes"] is None else ("~" if p["way"] == "converted"
                                                         else "") + m.mb(p["bytes"]))
                         + ("" if p["fits"] else "  past 35 MB"))
            size.setToolTip("%s .%s" % (p["way"], p["ext"]))
            size.setForeground(QColor("#d04040") if not p["fits"] else warn)
        self._filling = False
        self.table.resizeColumnToContents(self.MENU)
        self.table.resizeColumnToContents(self.SIZE)
        self.plan = plan
        self.sizes.setText("The mod folder: %s now, %s after this import (%s)%s"
                           % (m.wall_line(plan["release_now"]),
                              m.wall_line(plan["release_after"]),
                              "the wall: %s" % m.mb(plan["wall"]),
                                      ("<br><b>Left out, past the 35 MB wall (the mod would "
                                       "vanish from the list):</b> " + ", ".join(plan["over"]))
                                      if plan["over"] else ""))
        fits = len(readable) - len(plan["over"])
        self.go.setText("Import %d" % fits)
        self.go.setEnabled(bool(readable) and not lacking and fits > 0)
        said = [] if not lacking else ["No artist yet for %s - every track names who made "
                                       "it: fill the folder artist or the row." % ", ".join(
                                           os.path.basename(t.path) for t in lacking[:4])]
        if bad:
            said.append("Left out, cannot be read:\n" + "\n".join(t.problem for t in bad))
        self.said.setText("\n".join(said))
