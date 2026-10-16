from . import action
action("file.playground", [], "Open the Playground", "File",
       "A ready island to try things on: a note at each spot says what to press - nothing "
       "can go wrong, Ctrl+Z takes anything back")
class PlaygroundUI:
    def __init__(self, ux):
        self.ux = ux
        self.ed = ux.ed
        self.card = None
        ux.add_action("file.playground", self.open, menu=ux.menu("&File"))
        self._add_card()
    def open(self):
        from studio.ux import playground
        ok = self.ed.open_source(playground.SOURCE, recent=False)
        if ok:
            try:
                self.ux.studio.views.frame_all(animate=False)
            except Exception:
                pass
        return ok
    def _add_card(self):
        lib = getattr(self.ux.studio, "library", None)
        cards = getattr(lib, "cards", None)
        if cards is None or not hasattr(cards, "grid"):
            return
        try:
            from studio.library.qt.wizard import big_button
        except ImportError:
            return
        from studio.ux import playground
        b = big_button("Playground", playground.WHAT, checkable=False)
        b.setToolTip("A small island with a house, a tower, stairs and a note at each spot "
                     "saying what to try")
        b.clicked.connect(self.open)
        cards.buttons.append(b)
        n = len(cards.buttons) - 1
        cards.grid.addWidget(b, n // 2, n % 2)
        self.card = b
def install(ux):
    return PlaygroundUI(ux)
