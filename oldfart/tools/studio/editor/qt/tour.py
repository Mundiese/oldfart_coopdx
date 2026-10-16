STEPS = (
    ("wish", "Welcome to Oldfart Studio. Make a map: click \"Your first map\" in the middle "
             "- or say what you want in the Wish panel (\"a snowy castle with towers\") and "
             "press Ctrl+Enter"),
    ("look", "Look around: drag with the middle mouse button to turn the view, or hold the "
             "right button and fly with W A S D"),
    ("place", "Add something: click a palette item, then click in a view to put it there "
              "(Esc lets go, Ctrl+Z takes it back)"),
    ("play", "Play it: F6 puts the map into the mod and starts Coop DX"),
)
SKIP = "Shift+F1 skips the tour"
WELCOME = "Welcome to Oldfart Studio."
SEEN = "tour_seen"
SHOW_S = 120.0
class Tour:
    def __init__(self, ed):
        self.ed = ed
        self.step = None
        self.steps = STEPS
        self._hooked = False
    def seen(self):
        state = getattr(self.ed.studio.settings, "state", None) or {}
        return bool(state.get(SEEN))
    def running(self):
        return self.step is not None
    def start(self, force=False):
        if self.step is not None or (self.seen() and not force):
            return False
        st = self.ed.studio.settings
        if st.state is None:
            st.state = {}
        st.state[SEEN] = True
        if not self._hooked:
            for v in self.ed.studio.views.views():
                v.cameraChanged.connect(self._camera)
            self._hooked = True
        has_map = bool(self.ed.session.doc.refs("piece"))
        self.steps = STEPS[1:] if has_map else STEPS
        self.step = 0
        self._show()
        return True
    def first_run(self):
        if self.seen() or self.ed.session.doc.refs("piece"):
            return False
        return self.start()
    def skip(self):
        if self.step is None:
            return False
        self.step = None
        self._toast("Tour skipped - Shift+F1 starts it again, F1 has every key", 6.0)
        return True
    def toggle(self):
        if self.running():
            return self.skip()
        return self.start(force=True)
    def text(self):
        if self.step is None:
            return ""
        words = self.steps[self.step][1]
        if self.step == 0 and not words.startswith(WELCOME):
            words = "%s %s" % (WELCOME, words)
        return "%d/%d  %s   (%s)" % (self.step + 1, len(self.steps), words, SKIP)
    def _toast(self, text, seconds):
        try:
            self.ed.studio.views.active.view.show_toast(text, seconds=seconds)
        except AttributeError:
            pass
        self.ed.hint(text)
    def _show(self):
        if self.step is None:
            return
        if self.step >= len(self.steps):
            self.step = None
            self._toast("That is the tour - F1 has every key, F3 finds any command", 8.0)
            return
        self._toast(self.text(), SHOW_S)
    def done(self, what):
        if self.step is None or self.steps[self.step][0] != what:
            return False
        self.step += 1
        self._show()
        return True
    def _camera(self, *_):
        self.done("look")
