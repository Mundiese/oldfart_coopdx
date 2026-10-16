import os
import subprocess
import sys
from PySide6.QtCore import Qt, QTimer, QUrl
from PySide6.QtGui import QDesktopServices, QGuiApplication
from PySide6.QtWidgets import (QButtonGroup, QComboBox, QDialog, QDialogButtonBox,
                               QFileDialog, QFormLayout, QHBoxLayout, QLabel, QLineEdit,
                               QListWidget, QListWidgetItem, QPlainTextEdit, QPushButton,
                               QRadioButton, QVBoxLayout)
from .. import engine
from . import widgets
INTRO = ("Makes your map work in any sm64coopdx mod or modpack - no Oldfart's Mod Menu "
         "needed. Everything comes along: the level, every object (enemies, coins, pipes, "
         "springs...), moving platforms, buttons and targets, the ON/OFF switch, speedrun "
         "tracks, all its stars, the sky, the music and the weather. Only game modes stay "
         "with Oldfart's Mod Menu.")
CHOICES = (
    ("game", "Put it in my game",
     "Adds the map to your own Coop DX, into one mod called Oldfart Maps - every map you "
     "make is one tick in the game's Mods list", "Coop DX mods folder", "export.mods_folder"),
    ("mod", "Add to a mod",
     "Adds the map to a mod you choose - one in your mods folder, any folder, or a new mod "
     "with a name of its own", "Folder", "export.level_folder"),
    ("zip", "Zip to share",
     "Makes one .zip that is a complete mod: whoever gets it unpacks it into their mods folder",
     "Save the zip in", "export.zip_folder"),
)
NEW_MOD = "New mod..."
BROWSE = "Browse..."
def _pack():
    from mapgen import modpack
    return modpack
def _ingame():
    from mapgen import ingame
    return ingame
def problems(doc, name, key, folder, gate_faults=None, choice="mod"):
    out = list(_ingame().problems(doc.to_layout(models=False), choice, folder, key, name))
    far = any("too far out" in p for p in out)
    faults = [f for f in (gate_faults or []) if not (far and "leaves the level" in f)]
    for fault in faults[:3]:
        out.append("safety gate: %s" % fault)
    return out
class ExportLevelDialog(QDialog):
    DEBOUNCE_MS = 300
    def __init__(self, ed, parent=None):
        super().__init__(parent)
        self.ed = ed
        self.check_runs = 0
        self.choice = None
        self.places = {}
        self._gate_at, self._gate_faults = None, []
        self._idle = QTimer(self)
        self._idle.setSingleShot(True)
        self._idle.setInterval(self.DEBOUNCE_MS)
        self._idle.timeout.connect(self.check)
        self.setWindowTitle("Export level")
        self.resize(640, 620)
        doc = ed.session.doc
        lay = QVBoxLayout(self)
        intro = QLabel(INTRO)
        intro.setWordWrap(True)
        lay.addWidget(intro)
        self.roads = QButtonGroup(self)
        roads = QHBoxLayout()
        for i, (ck, words, tip, _label, _setting) in enumerate(CHOICES):
            b = QRadioButton(words)
            b.setToolTip(tip)
            b.setObjectName("road_" + ck)
            self.roads.addButton(b, i)
            roads.addWidget(b)
        lay.addLayout(roads)
        form = QFormLayout()
        self.name = QLineEdit(doc.rest.get("name") if doc.rest.get("name") not in
                              (None, "Untitled map") else "")
        self.name.setPlaceholderText("e.g. The Frost Keep")
        self.name.setToolTip("What the map list shows, e.g. The Frost Keep")
        self.key = QLineEdit()
        self.key.setPlaceholderText("from the name")
        self.key.setToolTip("What players type to go there, e.g. frostkeep for /ofmap frostkeep "
                            "(small letters and digits)")
        self.mod_pick = QComboBox()
        self.mod_pick.setToolTip("The mod the map goes into: one of your mods, a new one, or any "
                                 "folder")
        self.mod_pick.activated.connect(self._picked_mod)
        self.mod_name = QLineEdit()
        self.mod_name.setPlaceholderText("e.g. My Maps")
        self.mod_name.setToolTip("The new mod's name, as Coop DX's Mods list shows it")
        self.mod_name.textChanged.connect(self._new_mod_named)
        self.folder = QLineEdit()
        self.folder.setToolTip("Where the map goes")
        choose = QPushButton("Choose...")
        choose.setToolTip("Pick the folder")
        choose.clicked.connect(self._browse)
        row = QHBoxLayout()
        row.addWidget(self.folder, 1)
        row.addWidget(choose)
        form.addRow("Map name", self.name)
        form.addRow("Short name", self.key)
        self.mod_label = QLabel("Mod")
        form.addRow(self.mod_label, self.mod_pick)
        self.mod_name_label = QLabel("New mod's name")
        form.addRow(self.mod_name_label, self.mod_name)
        self.place_label = QLabel("Folder")
        form.addRow(self.place_label, row)
        prow = QHBoxLayout()
        self.paint_thumb = QLabel()
        self.paint_thumb.setVisible(False)
        self.paint_words = QLabel()
        self.paint_words.setObjectName("hint")
        self.paint_btn = QPushButton("Choose\u2026")
        self.paint_btn.setToolTip("Six paintings of the map from different viewpoints - pick "
                                  "the one its painting frame shows")
        self.paint_btn.clicked.connect(self.choose_painting)
        prow.addWidget(self.paint_thumb)
        prow.addWidget(self.paint_words, 1)
        prow.addWidget(self.paint_btn)
        form.addRow("Painting", prow)
        self._say_painting()
        lay.addLayout(form)
        self.in_game_head = widgets.header("My maps in the game")
        lay.addWidget(self.in_game_head)
        mine = QHBoxLayout()
        self.in_game = QListWidget()
        self.in_game.setMaximumHeight(80)
        self.in_game.setToolTip("The maps you put in your game (all in the mod Oldfart Maps)")
        self.remove = QPushButton("Remove")
        self.remove.setToolTip("Takes the chosen map out of your game again")
        self.remove.clicked.connect(self.remove_chosen)
        mine.addWidget(self.in_game, 1)
        mine.addWidget(self.remove)
        lay.addLayout(mine)
        lay.addWidget(widgets.header("Before it goes"))
        self.checks = QListWidget()
        self.checks.setWordWrap(True)
        self.checks.setMaximumHeight(110)
        self.checks.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        lay.addWidget(self.checks)
        self.banner = widgets.Banner()
        lay.insertWidget(0, self.banner)
        self.out = QPlainTextEdit()
        self.out.setReadOnly(True)
        self.out.setPlaceholderText("What to do next appears here after the export.")
        lay.addWidget(self.out, 1)
        buttons = QDialogButtonBox()
        self.go = buttons.addButton("Export level", QDialogButtonBox.AcceptRole)
        self.go.setObjectName("primary")
        self.go.setToolTip("Write the map out (Ctrl+F5)")
        self.open = buttons.addButton("Open the folder", QDialogButtonBox.ActionRole)
        self.open.setEnabled(False)
        self.copy = buttons.addButton("Copy the note", QDialogButtonBox.ActionRole)
        self.inside = buttons.addButton("Move it inside", QDialogButtonBox.ActionRole)
        self.inside.setToolTip("Moves everything that is too far out just inside the edge of the "
                               "world (Ctrl+Z takes it back)")
        self.inside.setVisible(False)
        self.inside.clicked.connect(self.move_inside)
        close = buttons.addButton(QDialogButtonBox.Close)
        self.go.clicked.connect(self.export)
        self.open.clicked.connect(self._open_folder)
        self.copy.clicked.connect(lambda: QGuiApplication.clipboard().setText(
            self.out.toPlainText()))
        close.clicked.connect(self.reject)
        lay.addWidget(buttons)
        for w in (self.name, self.key, self.folder):
            w.textChanged.connect(self._typed)
        self.roads.idToggled.connect(self._road)
        self.set_choice("game")
    def mods_folder(self):
        return (self.places.get("game") or self.ed.settings_get("export.mods_folder", None)
                or _ingame().find_mods_folder() or "")
    def default_place(self, choice):
        home = os.path.expanduser("~")
        if choice == "game":
            return _ingame().find_mods_folder() or ""
        if choice == "zip":
            return home
        found = _ingame().mods_in(self.mods_folder())
        return found[0] if found else os.path.join(home, "oldfart-maps")
    def set_choice(self, choice):
        if self.choice is not None:
            self.places[self.choice] = self.folder.text()
        self.choice = choice
        i = [c[0] for c in CHOICES].index(choice)
        if not self.roads.button(i).isChecked():
            self.roads.blockSignals(True)
            self.roads.button(i).setChecked(True)
            self.roads.blockSignals(False)
        _k, _w, _t, label, setting = CHOICES[i]
        place = self.places.get(choice)
        if place is None:
            place = self.ed.settings_get(setting, None) or self.default_place(choice)
        self.place_label.setText(label)
        self.folder.blockSignals(True)
        self.folder.setText(place)
        self.folder.blockSignals(False)
        game, mod = choice == "game", choice == "mod"
        for w in (self.in_game_head, self.in_game, self.remove):
            w.setVisible(game)
        for w in (self.mod_label, self.mod_pick):
            w.setVisible(mod)
        if mod:
            self.fill_mods()
        self._show_new_name()
        self.go.setText({"game": "Put it in my game", "zip": "Make the zip"}.get(choice,
                                                                               "Export level"))
        self.refresh_in_game()
        self.check()
    def _road(self, i, on):
        if on:
            self.set_choice(CHOICES[i][0])
    def fill_mods(self):
        here = self.folder.text().strip()
        self.mod_pick.blockSignals(True)
        self.mod_pick.clear()
        for path in _ingame().mods_in(self.mods_folder()):
            self.mod_pick.addItem(os.path.basename(path), path)
        if here and self.mod_pick.findData(here) < 0 and here != self.mods_folder():
            self.mod_pick.addItem(here, here)
        self.mod_pick.addItem(NEW_MOD, NEW_MOD)
        self.mod_pick.addItem(BROWSE, BROWSE)
        at = self.mod_pick.findData(here)
        self.mod_pick.setCurrentIndex(at if at >= 0 else 0)
        self.mod_pick.blockSignals(False)
        self._picked_mod(self.mod_pick.currentIndex(), quiet=True)
        return self.mod_pick.count()
    def _picked_mod(self, index, quiet=False):
        data = self.mod_pick.itemData(index)
        if data == BROWSE:
            if quiet:
                return
            self._browse()
            self.fill_mods()
            return
        if data == NEW_MOD:
            self._new_mod_named()
        elif data:
            self.folder.setText(data)
        self._show_new_name()
    def new_mod_chosen(self):
        return self.choice == "mod" and self.mod_pick.currentData() == NEW_MOD
    def _show_new_name(self):
        on = self.new_mod_chosen()
        self.mod_name.setVisible(on)
        self.mod_name_label.setVisible(on)
    def _new_mod_named(self, *_):
        if not self.new_mod_chosen():
            return
        mods = self.mods_folder()
        if mods:
            self.folder.setText(os.path.join(
                mods, _ingame().mod_folder_name(self.mod_name.text() or "My maps")))
    def refresh_in_game(self):
        self.in_game.clear()
        mods = self.folder.text().strip() if self.choice == "game" else ""
        if mods and os.path.isdir(mods):
            for key, name in _ingame().maps_in_game(mods):
                item = QListWidgetItem("%s   (/ofmap %s)" % (name, key))
                item.setData(Qt.UserRole, key)
                self.in_game.addItem(item)
        self.remove.setEnabled(self.in_game.count() > 0)
        return self.in_game.count()
    def remove_chosen(self):
        item = self.in_game.currentItem()
        if item is None and self.in_game.count() == 1:
            item = self.in_game.item(0)
        if item is None:
            return False
        key = item.data(Qt.UserRole)
        gone = _ingame().remove_map(self.folder.text().strip(), key)
        self.out.setPlainText(("%s is out of your game." % item.text().split("   ")[0])
                              if gone else "That map was not in your game.")
        self.refresh_in_game()
        return gone
    def the_key(self):
        return self.key.text().strip() or engine.key_for(self.name.text())
    def _typed(self, *_):
        self.go.setEnabled(False)
        self._idle.start()
    def _gate(self):
        doc = self.ed.session.doc
        stamp = (id(doc), doc.revision)
        if stamp != self._gate_at:
            self._gate_faults = list(engine.gate(doc.to_layout()).faults)
            self._gate_at = stamp
        return self._gate_faults
    def check(self, *_):
        self._idle.stop()
        self.check_runs += 1
        self.checks.clear()
        found = problems(self.ed.session.doc, self.name.text(), self.the_key(),
                         self.folder.text().strip(), self._gate(), self.choice)
        if self.new_mod_chosen() and not self.mod_name.text().strip():
            found.append("Give the new mod a name")
        for p in found:
            item = QListWidgetItem(p)
            item.setForeground(Qt.red if p.startswith("safety") else Qt.yellow)
            self.checks.addItem(item)
        if not found:
            item = QListWidgetItem("Ready: players will type /ofmap %s to go there."
                                   % self.the_key())
            item.setForeground(Qt.green)
            self.checks.addItem(item)
        self.go.setEnabled(not found)
        from mapgen import worldedge
        self.inside.setVisible(bool(worldedge.far(self.ed.session.doc.to_layout(models=False))))
        return found
    def move_inside(self):
        from .. import criticfix
        doc = self.ed.session.doc
        pv = criticfix.preview(doc, "world_edge")
        if pv is None:
            self.check()
            return False
        self.ed.push(criticfix.change_for(doc, pv, "Move it inside the world"))
        self.ed.hint("Moved inside the world - Ctrl+Z takes it back")
        self.check()
        return True
    def _browse(self):
        title = {"game": "Where is Coop DX's mods folder?",
                 "zip": "Save the zip in..."}.get(self.choice, "Add the map to the mod in...")
        d = QFileDialog.getExistingDirectory(self, title, self.folder.text())
        if d:
            self.folder.setText(d)
            self.refresh_in_game()
        return d
    def _say_painting(self, preview=None):
        from mapgen import paintpick
        view = paintpick.chosen(self.ed.session.doc.rest)
        self.paint_words.setText((view.get("label") or "Your chosen view") if view else
                                 "The best view (chosen for you)")
        if preview is not None:
            from studio.library.qt.paintbuilder import to_pixmap
            self.paint_thumb.setPixmap(to_pixmap(preview.resize((64, 63))))
            self.paint_thumb.setVisible(True)
    def choose_painting(self):
        from studio.library.qt import paintpick as ppq
        dlg = ppq.open_picker(self.ed, self)
        def picked(_view):
            cand = dlg.selected()
            face = dlg.faces.get(cand.id) if cand is not None else None
            self._say_painting(face[2] if face else None)
        dlg.picked.connect(picked)
        return dlg
    def export(self):
        if self.choice == "game" and not self.folder.text().strip():
            self._browse()
        if self.check():
            return
        name, key, folder = self.name.text().strip(), self.the_key(), self.folder.text().strip()
        choice = self.choice
        self.ed.settings_set(CHOICES[[c[0] for c in CHOICES].index(choice)][4],
                             os.path.dirname(folder) if self.new_mod_chosen() else folder)
        if self.new_mod_chosen():
            folder = _ingame().new_mod(os.path.dirname(folder), self.mod_name.text().strip())
        layout = self.ed.session.doc.to_layout()
        self.go.setEnabled(False)
        self.banner.clear()
        self.out.setPlainText("Exporting - baking the level and packing everything in...")
        pack, ing = _pack(), _ingame()
        try:
            from studio.library import musiclib
            root = musiclib.target(self.ed)
        except Exception:
            root = None
        pack.MUSIC_ROOTS[:] = [root] if root else []
        def job(progress, cancelled):
            progress(0, 0, "baking the level and packing everything in")
            if choice == "game":
                return ing.put_in_game(layout, folder, key, name)
            if choice == "zip":
                return ing.make_zip(layout, os.path.join(folder, key + ".zip"), key, name)
            return pack.export(layout, folder, key, name)
        def done(res):
            if choice == "game":
                self.out.setPlainText(ing.done_note(res, name, key))
                self.refresh_in_game()
            elif choice == "zip":
                self.out.setPlainText(ing.zip_note(res, name, key))
            else:
                self.out.setPlainText(pack.handoff(res, name, key, folder))
            self.go.setEnabled(True)
            self.open.setEnabled(True)
            self.ed.hint("Exported %s - type /ofmap %s in the game" % (name, key))
            where = {"game": "It is in your game - start Coop DX and type /ofmap %s" % key,
                     "zip": "The zip is ready to share - Open folder shows it"}.get(
                choice, "It is in the mod - type /ofmap %s in the game" % key)
            self.banner.ok("Exported \u201c%s\u201d" % name, where,
                           getattr(getattr(self.ed, "studio", None), "ux", None),
                           opener=self._open_folder)
        def failed(reason):
            self.out.setPlainText("Not exported: %s" % reason)
            self.go.setEnabled(True)
            self.banner.fail("Not exported", str(reason))
        if not self.ed.jobs.run("Exporting %s" % name, job, done, failed):
            failed("the Studio is busy - try again in a moment")
    def _open_folder(self):
        folder = self.folder.text().strip()
        if self.choice == "game":
            folder = _ingame().shared_folder(folder)
        if not os.path.isdir(folder):
            return False
        if not QDesktopServices.openUrl(QUrl.fromLocalFile(folder)) and sys.platform.startswith("linux"):
            subprocess.Popen(["xdg-open", folder])
        return True
def run(ed):
    dlg = ExportLevelDialog(ed, ed.window)
    dlg.show()
    ed._export_level_dialog = dlg
    return dlg
