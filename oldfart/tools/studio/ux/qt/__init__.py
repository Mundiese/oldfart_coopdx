from PySide6.QtCore import QObject
from studio.core import keymap
ACTIONS = {}
def action(aid, keys, label, group, tip):
    ACTIONS[aid] = (list(keys), label, group, tip)
class UX(QObject):
    def __init__(self, studio):
        super().__init__(studio.window)
        self.studio = studio
        self.window = studio.window
        self.ctx = studio.ctx
        self.ed = studio.editor
        self.tools = getattr(studio, "tools", None)
        self.settings = studio.settings
        self.parts = {}
        from . import (coachui, contextbarui, faceui, gamepadui, ghostui, hintsui, hotbarui,
                       houseui, lessonsui, levelui, magicui, planeui, playgroundui,
                       scaleui, shareui, soundui, wheelui)
        for mod in (soundui, planeui, ghostui, hotbarui, houseui, magicui,
                    contextbarui, wheelui, shareui, lessonsui, playgroundui, scaleui, gamepadui,
                    faceui, levelui, coachui, hintsui):
            part = mod.install(self)
            self.parts[mod.__name__.rsplit(".", 1)[-1]] = part
        self.window.apply_keys()
    def add_action(self, aid, handler, checkable=False, menu=None):
        keys, label, group, tip = ACTIONS[aid]
        keymap.register(aid, keys, label, group)
        a = self.window.add_action(aid, handler, label, checkable=checkable, keys=keys,
                                   group=group)
        a.setStatusTip(tip)
        if menu is not None:
            menu.addAction(a)
        return a
    def menu(self, title):
        mb = self.window.menuBar()
        for a in mb.actions():
            if a.text().replace("&", "") == title.replace("&", "") and a.menu() is not None:
                return a.menu()
        m = mb.addMenu(title)
        help_a = next((a for a in mb.actions() if a.text().replace("&", "") == "Help"), None)
        if help_a is not None:
            mb.insertMenu(help_a, m)
        return m
    def hint(self, text):
        if text:
            self.window.hint(text)
    def view(self):
        try:
            return self.studio.views.active.view
        except AttributeError:
            return None
    def sound(self, kind, **kw):
        part = self.parts.get("soundui")
        if part is not None:
            part.play(kind, **kw)
    def pop(self, refs):
        part = self.parts.get("soundui")
        if part is not None:
            part.pop(refs)
def install(studio):
    ux = UX(studio)
    studio.ux = ux
    return ux
