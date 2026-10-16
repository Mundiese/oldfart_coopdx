from PySide6.QtCore import QEvent, QObject, QTimer
from . import common, forgetrack, polish
ACTIONS = {
    "lib.commands": (["F3", "Ctrl+Shift+P"], "Search every command", "Library"),
    "lib.textures": (["Ctrl+Shift+T"], "Textures - import, shapes, download size", "Library"),
    "lib.prefabs": ([], "Prefab library", "Library"),
    "lib.save_prefab": (["Ctrl+G"], "Save the selection as a prefab", "Library"),
    "lib.prefab_draft": ([], "Prefab from a game save...", "Library"),
    "lib.forge_import": ([], "Forge build from a game save...", "Library"),
    "lib.forge_number": ([], "Number the race gates in driving order", "Library"),
    "lib.forge_export": ([], "Forge build back into the game save...", "Library"),
    "lib.music": (["Ctrl+Alt+M"], "Music", "Library"),
    "lib.paintings": ([], "Painting Builder...", "Library"),
    "lib.paintpick": ([], "Choose the map's painting...", "Library"),
    "lib.variety": (["Ctrl+Alt+V"], "Show the variety maps", "Library"),
    "lib.taste": ([], "A or B? - teach the generator your taste", "Library"),
    "lib.wizard": (["Ctrl+Alt+N"], "Your first map (wizard)\u2026", "Library"),
    "lib.trash": ([], "Recently removed...", "Library"),
}
class Library(QObject):
    def __init__(self, studio):
        super().__init__(studio.window)
        self.studio = studio
        self.ed = studio.editor
        self.window = studio.window
        self.tokens = studio.ctx.tokens
        self.thumbnailer = common.Thumbnailer(studio)
        self._textures = None
        self._variety = None
        self._wizard = None
        self._commands = None
        self._build_docks()
        self._build_actions()
        self._hook_variety()
        self._start_cards()
        QTimer.singleShot(0, lambda: polish.tooltips(self.window))
    def _build_docks(self):
        from .music import MusicPanel
        from .prefabs import PrefabPanel
        docks = self.studio.docks
        self.prefabs = PrefabPanel(self)
        self.music = MusicPanel(self)
        docks.add("left", "prefabs", "Prefabs", self.prefabs)
        from PySide6.QtWidgets import QFrame, QScrollArea
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(self.music)
        docks.add("bottom", "music", "Music", scroll)
        docks.get("palette").raise_()
        if docks.get("history") is not None:
            docks.get("history").raise_()
        if not (self.studio.settings.state or {}).get("docks"):
            from PySide6.QtCore import Qt
            QTimer.singleShot(0, lambda: self.window.resizeDocks(
                [docks.get("music")], [190], Qt.Vertical))
        self.ed.changed.connect(self._doc_changed)
    def _build_actions(self):
        from studio.core import keymap
        for aid, (keys, label, group) in ACTIONS.items():
            keymap.register(aid, keys, label, group)
        w = self.window
        mb = w.menuBar()
        menu = mb.addMenu("Li&brary")
        help_menu = next((a for a in mb.actions() if a.text().replace("&", "") == "Help"), None)
        if help_menu is not None:
            mb.insertMenu(help_menu, menu)
        handlers = {
            "lib.commands": self.command_palette, "lib.textures": self.texture_manager,
            "lib.prefabs": lambda: self._show_dock("prefabs"),
            "lib.save_prefab": lambda: self.prefabs.save_selection(),
            "lib.prefab_draft": lambda: self.prefabs.import_draft(),
            "lib.forge_import": lambda: forgetrack.import_build(self),
            "lib.forge_number": lambda: forgetrack.number_gates(self),
            "lib.forge_export": lambda: forgetrack.export_build(self),
            "lib.music": lambda: self._show_dock("music"),
            "lib.paintings": self.painting_builder,
            "lib.paintpick": self.paint_picker,
            "lib.variety": self.variety, "lib.wizard": self.first_map,
            "lib.taste": self.taste, "lib.trash": self.recently_removed,
        }
        for aid, (keys, label, group) in ACTIONS.items():
            a = w.add_action(aid, handlers[aid], label, keys=keys, group=group)
            menu.addAction(a)
            if aid in ("lib.commands", "lib.music", "lib.prefab_draft", "lib.forge_export"):
                menu.addSeparator()
        if help_menu is not None and help_menu.menu() is not None:
            help_menu.menu().addAction(w.actions["lib.wizard"])
            help_menu.menu().addAction(w.actions["lib.commands"])
        w.apply_keys()
    def recently_removed(self):
        from .trashview import TrashDialog
        dlg = TrashDialog(self)
        dlg.show()
        self._trash_dialog = dlg
        return dlg
    def _show_dock(self, key):
        d = self.studio.docks.get(key)
        if d is not None:
            d.show()
            d.raise_()
            from PySide6.QtCore import Qt
            from studio.ui.docks import ui_scale
            win = self.studio.window
            if win.dockWidgetArea(d) == Qt.BottomDockWidgetArea and not d.isFloating():
                want = int(max(260 * ui_scale(win), 0.38 * win.height()))
                if d.height() < want - 40:
                    win.resizeDocks([d], [want], Qt.Vertical)
    def texture_manager(self):
        from .textures import TextureManager
        if self._textures is None:
            self._textures = TextureManager(self)
        self._textures.show()
        self._textures.raise_()
        return self._textures
    def variety(self, maps=None):
        from .variety import VarietyWindow
        if self._variety is None:
            self._variety = VarietyWindow(self)
        self._variety.show()
        self._variety.raise_()
        if maps:
            self._variety.show_generated(maps)
        return self._variety
    def painting_builder(self):
        from .paintbuilder import open_builder
        return open_builder(self)
    def paint_picker(self):
        from .paintpick import open_picker
        return open_picker(self.ed)
    def taste(self):
        from .taste import TasteWindow
        if getattr(self, "_taste", None) is None:
            self._taste = TasteWindow(self)
        self._taste.show()
        self._taste.raise_()
        return self._taste
    def first_map(self):
        from .wizard import FirstMap
        self._seen()
        self._wizard = FirstMap(self)
        self._wizard.show()
        return self._wizard
    def command_palette(self):
        from .command import CommandPalette
        if self._commands is None:
            self._commands = CommandPalette(self)
        self._commands.open()
        return self._commands
    def _hook_variety(self):
        original = self.ed._varied
        def varied(maps):
            original(maps)
            self.variety(maps)
        self.ed._varied = varied
    def palette_changed(self):
        pal = self.ed.palette
        state = pal.state()
        pal.reload()
        pal.restore(state)
        self.ed.palette_panel.fill()
    def reload_textures(self):
        try:
            from studio.editor.qt import widgets
            widgets._swatches.clear()
            widgets._average.clear()
            widgets._shape_pixmaps.clear()
        except Exception:
            pass
        self.palette_changed()
        self.prefabs.fill()
    def _doc_changed(self):
        self.music.refresh_map()
        self._update_cards()
    def _start_cards(self):
        from .wizard import StartCards
        from .. import wizard as wizmod
        self.cards = StartCards(self, self.studio.views)
        self.studio.ctx.start_screen = self.cards.isVisible
        self.studio.views.installEventFilter(self)
        state = self.studio.settings.state
        att = wizmod.attention(state, bool(self.studio.settings.get("ui.reduce_motion")))
        self.cards.draw_attention(att)
        if att["hint"]:
            QTimer.singleShot(0, lambda: self.window.hint(att["hint"]))
        self._update_cards()
    def _seen(self):
        from .. import wizard as wizmod
        if wizmod.mark_seen(self.studio.settings.state):
            self.cards.calm()
            try:
                self.studio.settings.save()
            except OSError:
                pass
    def _update_cards(self):
        doc = self.ed.session.doc
        empty = not doc.refs("piece") and not doc.refs("spawn")
        self.cards.setVisible(empty)
        if empty:
            self.cards.fill_maps()
            self.cards.fill_hand()
            self.cards.place()
        else:
            self._seen()
        self.studio.ctx.redraw()
    def eventFilter(self, obj, ev):
        if obj is self.studio.views and ev.type() in (QEvent.Resize, QEvent.Show):
            if self.cards.isVisible():
                self.cards.place()
        return False
def install(studio):
    if getattr(studio, "editor", None) is None:
        from studio.editor.qt import install as install_editor
        install_editor(studio)
    lib = Library(studio)
    studio.library = lib
    return lib
