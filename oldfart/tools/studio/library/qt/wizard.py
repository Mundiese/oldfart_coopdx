from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QCheckBox, QDialog, QFrame, QGridLayout, QHBoxLayout, QLabel, QLayout,
                               QLineEdit,
                               QPlainTextEdit, QProgressBar, QPushButton, QScrollArea,
                               QStackedWidget, QVBoxLayout, QWidget)
from .. import wizard as wizmod
PULSE_MS = 900
PULSE_BEATS = 24
FAMILY_HELP = {
    "shooter": "everybody against everybody, towers and cover",
    "objective": "capture the flag, hold the points",
    "knockoff": "push each other off a plate",
    "race": "a track with a start and a finish",
    "hide": "corners, cover and hiding places",
    "party": "a plate for party games",
    "course": "jumps and obstacles to the finish",
    "explore": "a big world to roam, with landmarks and bonus stars",
}
PAD_V, PAD_H, BORDER, SLACK = 10, 14, 2, 6
class BigChoice(QPushButton):
    def _need(self):
        from PySide6.QtCore import QSize
        from PySide6.QtGui import QFont, QFontMetrics
        f = QFont(self.font())
        f.setWeight(QFont.DemiBold)
        fm = QFontMetrics(f)
        lines = self.text().split("\n")
        w = max(fm.horizontalAdvance(line) for line in lines)
        h = fm.lineSpacing() * len(lines)
        return QSize(w + 2 * (PAD_H + BORDER) + SLACK, h + 2 * (PAD_V + BORDER) + SLACK)
    def minimumSizeHint(self):
        need = self._need()
        need.setWidth(max(need.width(), 170))
        need.setHeight(max(need.height(), 60))
        return need
    def sizeHint(self):
        return self.minimumSizeHint()
    def event(self, e):
        from PySide6.QtCore import QEvent
        done = super().event(e)
        if e.type() in (QEvent.Polish, QEvent.FontChange, QEvent.StyleChange):
            self.setMinimumSize(self.minimumSizeHint())
        return done
CARD_LINE = 34
def big_button(title, text, checkable=True):
    import textwrap
    shown = "\n".join(textwrap.wrap(text, CARD_LINE)) if text else ""
    b = BigChoice("%s\n%s" % (title, shown) if text else title)
    b.setCheckable(checkable)
    b.setAutoDefault(False)
    b.setToolTip("%s: %s" % (title, text) if text else title)
    b.setObjectName("bigChoice")
    return b
class Choices(QWidget):
    def __init__(self, options, on_pick, cols=3):
        super().__init__()
        self.buttons = {}
        grid = QGridLayout(self)
        grid.setSpacing(8)
        grid.setSizeConstraint(QLayout.SetMinimumSize)
        for i, (value, title, text) in enumerate(options):
            b = big_button(title, text)
            b.clicked.connect(lambda checked=False, v=value: self.toggle(v, checked, on_pick))
            grid.addWidget(b, i // cols, i % cols)
            self.buttons[value] = b
    def value(self):
        for v, b in self.buttons.items():
            if b.isChecked():
                return v
        return None
    def toggle(self, value, checked, on_pick=None):
        self.pick(value if checked else None, on_pick)
    def pick(self, value, on_pick=None):
        for v, b in self.buttons.items():
            b.setChecked(value is not None and v == value)
        if on_pick:
            on_pick(value)
def _demote(button):
    button.setObjectName("")
    button.style().unpolish(button)
    button.style().polish(button)
class FirstMap(QDialog):
    def __init__(self, lib):
        super().__init__(lib.window)
        self.lib = lib
        self.ed = lib.ed
        self.w = wizmod.Wizard()
        self.setWindowTitle("Your first map")
        self.resize(820, 640)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(20, 16, 20, 16)
        self.steps = QLabel()
        self.steps.setObjectName("dim")
        self.steps.setTextFormat(Qt.RichText)
        self.steps.setTextInteractionFlags(Qt.LinksAccessibleByMouse | Qt.LinksAccessibleByKeyboard)
        self.steps.linkActivated.connect(self.go_to)
        self.seen = 0
        lay.addWidget(self.steps)
        self.title = QLabel()
        self.title.setObjectName("title")
        lay.addWidget(self.title)
        self.help = QLabel()
        self.help.setWordWrap(True)
        self.help.setObjectName("caption")
        lay.addWidget(self.help)
        self.pages = QStackedWidget()
        lay.addWidget(self.pages, 1)
        self.summary = QLabel()
        self.summary.setObjectName("caption")
        self.summary.setWordWrap(True)
        lay.addWidget(self.summary)
        row = QHBoxLayout()
        self.back_btn = QPushButton("\u2190 Back")
        self.back_btn.setToolTip("The step before (Alt+Left)")
        self.back_btn.setShortcut("Alt+Left")
        self.back_btn.clicked.connect(self.back)
        self.next_btn = QPushButton("Next")
        self.next_btn.setObjectName("primary")
        self.next_btn.clicked.connect(self.next)
        close = QPushButton("Close")
        close.setAutoDefault(False)
        self.back_btn.setAutoDefault(False)
        close.clicked.connect(self.reject)
        self.quick_btn = QPushButton("Build it now \u25b6")
        self.quick_btn.setToolTip("Skip the other questions (all on auto) and build the map now")
        self.quick_btn.setAutoDefault(False)
        self.quick_btn.clicked.connect(self.build_now)
        row.addWidget(close)
        row.addStretch(1)
        row.addWidget(self.back_btn)
        row.addWidget(self.quick_btn)
        row.addWidget(self.next_btn)
        lay.addLayout(row)
        self.mod = ""
        self.exported = None
        self.keep_picks = False
        from studio.editor.qt.worker import Jobs
        self._checks = Jobs(self)
        self._build()
        self.show_step()
        self.fit_size()
        self.paused_tour = self._pause_tour()
        self.ed.jobs.ended.connect(self._ended)
        self.ed.jobs.started.connect(self._started)
        self.ed.jobs.progress.connect(self._progress)
        self.finished.connect(self._closed)
        QTimer.singleShot(0, self, self._first_focus)
    def _build(self):
        page = QWidget()
        pl = QVBoxLayout(page)
        pl.setSizeConstraint(QLayout.SetMinimumSize)
        fam = [(v, label.split(" (")[0], FAMILY_HELP.get(v, ""))
               for v, label in wizmod.choices("family")]
        self.family = Choices(fam, self._family_picked, cols=2)
        pl.addWidget(self.family)
        from studio.editor.qt.modepicker import ModePicker
        self.modes_title = QLabel("<b>Which game modes?</b> Ticked modes offer the map in "
                                  "their map picker - the kind's own are ticked already")
        self.modes_title.setWordWrap(True)
        pl.addWidget(self.modes_title)
        self.modes = ModePicker(compact=True)
        self.modes.setToolTip("Example: an objective map for Capture the Flag only - untick "
                              "the others")
        self.modes.changed.connect(lambda *_: self._set("modes", self.modes.value()))
        pl.addWidget(self.modes)
        self.modes_title.hide()
        self.modes.hide()
        pl.addWidget(QLabel("<b>Or start from a preset</b>"))
        presets = [(k, label, hint) for k, label, hint, _ in wizmod.PRESETS]
        self.presets = Choices(presets, self._preset, cols=2)
        pl.addWidget(self.presets)
        pl.addStretch(1)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(page)
        self.mode_scroll = scroll
        self.pages.addWidget(scroll)
        page = QWidget()
        pl = QVBoxLayout(page)
        pl.addWidget(QLabel("<b>Players</b>"))
        self.players = Choices([(n, "%d players" % n, "") for n, _ in
                                wizmod.choices("players")], lambda v: self._set("players", v),
                               cols=5)
        pl.addWidget(self.players)
        pl.addWidget(QLabel("<b>Size</b> - Mario's run across"))
        sizes = {"tiny": "a few seconds", "small": "quick rounds", "medium": "the Sky Keep's",
                 "large": "room to roam", "huge": "a long way"}
        self.size = Choices([(v, label, sizes.get(v, "")) for v, label in
                             wizmod.choices("size")], lambda v: self._set("size", v), cols=5)
        pl.addWidget(self.size)
        self.course_box = QWidget()
        cl = QVBoxLayout(self.course_box)
        cl.setContentsMargins(0, 0, 0, 0)
        cl.addWidget(QLabel("<b>How hard?</b> From Casual (for kids) to Pro (for SM64 pros)"))
        hard = {"easy": "big landings, a net under every jump",
                "normal": "running jumps, beams, ferries",
                "hard": "long jumps, side flips, wall kicks",
                "expert": "dives, wall-kick shafts, lava",
                "pro": "frame-tight jumps over the void"}
        self.difficulty = Choices([(v, label, hard.get(v, "")) for v, label in
                                   wizmod.choices("difficulty")],
                                  lambda v: self._set("difficulty", v), cols=5)
        cl.addWidget(self.difficulty)
        cl.addWidget(QLabel("<b>How long?</b> A good run, start to finish"))
        self.course_length = Choices([(v, label.split(" (")[0], label.split(" (")[1][:-1])
                                      for v, label in wizmod.choices("course_length")],
                                     lambda v: self._set("course_length", v), cols=4)
        cl.addWidget(self.course_length)
        self.course_box.setVisible(False)
        pl.addWidget(self.course_box)
        pl.addStretch(1)
        self.pages.addWidget(page)
        page = QWidget()
        pl = QVBoxLayout(page)
        self.theme = Choices([(v, label if v != "auto" else "Surprise me",
                               "" if v != "auto" else "the kind's own look")
                              for v, label in wizmod.choices("theme")],
                             lambda v: self._set("theme", None if v == "auto" else v), cols=4)
        pl.addWidget(self.theme)
        from studio.editor.qt.skypicker import SkyPicker, rom_choice
        pl.addWidget(QLabel("<b>Sky</b> - the theme's own, or any of the game's"))
        self.sky = SkyPicker(rom=rom_choice(self.lib.studio.settings))
        self.sky.currentIndexChanged.connect(
            lambda *_: self._set("sky", None if self.sky.value() == "auto" else self.sky.value()))
        pl.addWidget(self.sky)
        pl.addStretch(1)
        self.pages.addWidget(page)
        page = QWidget()
        pl = QVBoxLayout(page)
        self.wish = QPlainTextEdit()
        self.wish.setPlaceholderText("e.g. \"a bridge in the middle, world spawn in the south, "
                                     "lots of height\" - or \"a tower in the north-west\"")
        self.wish.textChanged.connect(self._wish)
        pl.addWidget(self.wish)
        self.reading = QLabel()
        self.reading.setWordWrap(True)
        self.reading.setObjectName("caption")
        pl.addWidget(self.reading)
        self.conflict = QFrame()
        self.conflict.setObjectName("card")
        cl = QVBoxLayout(self.conflict)
        self.conflict_said = QLabel("")
        self.conflict_said.setWordWrap(True)
        cl.addWidget(self.conflict_said)
        crow = QHBoxLayout()
        self.use_wish_btn = QPushButton("Use what the wish says")
        self.use_wish_btn.setAutoDefault(False)
        self.use_wish_btn.clicked.connect(self.use_wish)
        self.keep_btn = QPushButton("Keep my picks")
        self.keep_btn.setAutoDefault(False)
        self.keep_btn.clicked.connect(self.keep_choices)
        crow.addWidget(self.use_wish_btn)
        crow.addWidget(self.keep_btn)
        crow.addStretch(1)
        cl.addLayout(crow)
        self.conflict.setVisible(False)
        pl.addWidget(self.conflict)
        pl.addStretch(1)
        self.pages.addWidget(page)
        page = QWidget()
        pl = QVBoxLayout(page)
        self.gen_btn = QPushButton("Generate my map")
        self.gen_btn.setObjectName("primary")
        self.gen_btn.setMinimumHeight(48)
        self.gen_btn.clicked.connect(self.generate)
        pl.addWidget(self.gen_btn)
        prow = QHBoxLayout()
        self.gen_bar = QProgressBar()
        self.gen_bar.setTextVisible(True)
        self.gen_bar.setVisible(False)
        self.gen_cancel = QPushButton("Cancel")
        self.gen_cancel.setAutoDefault(False)
        self.gen_cancel.setVisible(False)
        self.gen_cancel.clicked.connect(self.ed.jobs.cancel)
        prow.addWidget(self.gen_bar, 1)
        prow.addWidget(self.gen_cancel)
        pl.addLayout(prow)
        self.gen_said = QLabel("Press the button: the engine builds a few maps and keeps the "
                               "best. It takes a little while.")
        self.gen_said.setWordWrap(True)
        pl.addWidget(self.gen_said)
        self.thumb = QLabel()
        self.thumb.setAlignment(Qt.AlignCenter)
        self.thumb.setMinimumHeight(0)
        self.thumb.setToolTip("Your map from above - the views behind this window show it in 3D")
        self.thumb.setVisible(False)
        pl.addWidget(self.thumb, 1)
        self.course = QCheckBox("Make it playable: a pop-up target on every target spot, a "
                                "start button, and the clock")
        self.course.setToolTip("Press the button in the start room: the clock runs, every "
                               "target stands up, and the last one down finishes the run. "
                               "Change it later in the Logic panel.")
        self.course.setChecked(True)
        self.course.toggled.connect(lambda on: setattr(self.w, "course", on))
        pl.addWidget(self.course)
        pl.addStretch(1)
        self.pages.addWidget(page)
        page = QWidget()
        pl = QVBoxLayout(page)
        from studio.editor.qt import widgets as ewidgets
        self.banner = ewidgets.Banner()
        pl.addWidget(self.banner)
        pl.addWidget(QLabel("<b>Its name</b>"))
        self.name = QLineEdit()
        self.name.setPlaceholderText("e.g. The Frost Keep")
        pl.addWidget(self.name)
        mrow = QHBoxLayout()
        self.mod_said = QLabel("")
        self.mod_said.setObjectName("caption")
        self.mod_said.setWordWrap(True)
        mrow.addWidget(self.mod_said, 1)
        self.mod_btn = QPushButton("Choose the mod folder\u2026")
        self.mod_btn.setAutoDefault(False)
        self.mod_btn.clicked.connect(self.choose_mod)
        mrow.addWidget(self.mod_btn)
        pl.addLayout(mrow)
        self.exp_btn = QPushButton("Put it into the game")
        self.exp_btn.setObjectName("primary")
        self.exp_btn.setMinimumHeight(48)
        self.exp_btn.setToolTip("Checks the map, writes it into the mod and says how to play "
                                "it")
        self.exp_btn.clicked.connect(self.export)
        pl.addWidget(self.exp_btn)
        self.exp_bar = QProgressBar()
        self.exp_bar.setRange(0, 0)
        self.exp_bar.setVisible(False)
        pl.addWidget(self.exp_bar)
        self.exp_said = QLabel("")
        self.exp_said.setWordWrap(True)
        self.exp_said.setObjectName("caption")
        pl.addWidget(self.exp_said)
        self.note = QLabel("After that: close Coop DX if it runs, start it with the mod, host, "
                           "then Travel > Arenas > your map. Change anything later with the "
                           "tools - Ctrl+Z always goes back.")
        self.note.setWordWrap(True)
        self.note.setObjectName("caption")
        pl.addWidget(self.note)
        more = QLabel('<a href="more">More export options\u2026</a> (game modes, the key, '
                      'other mods)')
        more.setObjectName("caption")
        more.setTextInteractionFlags(Qt.LinksAccessibleByMouse | Qt.LinksAccessibleByKeyboard)
        more.linkActivated.connect(lambda *_: self.expert_export())
        pl.addWidget(more)
        pl.addStretch(1)
        self.pages.addWidget(page)
    def _family_picked(self, value):
        from studio.editor import gamemodes as gm
        self._set("family", value)
        self.course_box.setVisible(value == "course")
        self.modes_title.setVisible(value is not None)
        self.modes.setVisible(value is not None)
        if value is None:
            self._set("modes", None)
            return
        self.modes.set_context({}, value)
        self.modes.set_pick(gm.Pick(gm.ONLY, gm.defaults({}, value), False))
        self._set("modes", None)
        QTimer.singleShot(0, self, lambda: self.mode_scroll.ensureWidgetVisible(self.modes, 0, 40))
    def _set(self, field, value):
        self.w.set(field, value)
        self.show_step()
    def _preset(self, key):
        if key is None:
            for field in self.w.drop_preset():
                group = getattr(self, field, None)
                if isinstance(group, Choices):
                    group.pick(None)
            if "family" not in self.w.values:
                self._family_picked(None)
            self.show_step()
            return
        fields = self.w.use_preset(key)
        self.family.pick(fields["family"], self._family_picked)
        if "players" in fields:
            self.players.pick(fields["players"])
        if "size" in fields:
            self.size.pick(fields["size"])
        if "difficulty" in fields:
            self.difficulty.pick(fields["difficulty"])
        if (fields.get("course") or {}).get("length"):
            self.course_length.pick(fields["course"]["length"])
        self.show_step()
    CONFLICT_FIELDS = ("family", "players", "size", "theme")
    def conflicts(self):
        if not self.w.wish.strip() or self.keep_picks:
            return []
        from studio.editor import engine
        try:
            reading = engine.read_wish(self.w.wish)
        except Exception:
            return []
        out = []
        for f in self.CONFLICT_FIELDS:
            said, picked = reading.raw.get(f), self.w.values.get(f)
            if said not in (None, "", "auto") and picked is not None and said != picked:
                out.append((f, said, picked))
        return out
    def _said(self, field, value):
        if field == "players":
            return "%s players" % value
        label = dict(wizmod.choices(field)).get(value, value)
        return str(label).split(" (")[0]
    def _wish(self):
        self.w.wish = self.wish.toPlainText()
        if not self.w.wish.strip():
            self.keep_picks = False
        try:
            from studio.editor import engine
            if self.w.wish.strip():
                raw, reading = self.w.brief()
                lines = engine.say_reading(reading, final=raw)
            else:
                lines = []
        except Exception as why:
            lines = ["(%s)" % why]
        self.reading.setText("\n".join(lines))
        got = self.conflicts()
        if got:
            wish = ", ".join(self._said(f, a) for f, a, _ in got)
            mine = ", ".join(self._said(f, b) for f, _, b in got)
            self.conflict_said.setText("<b>Your wish says %s</b> - you picked %s. Which one?"
                                       % (wish, mine))
            self.use_wish_btn.setText("Use the wish: %s" % wish)
            self.keep_btn.setText("Keep %s" % mine)
        self.conflict.setVisible(bool(got))
        self.summary.setText(self.w.summary())
    def use_wish(self):
        for f, said, _ in self.conflicts():
            self.w.values[f] = said
            group = getattr(self, f if f != "family" else "family", None)
            if isinstance(group, Choices) and said in group.buttons:
                group.pick(said)
        if "family" in self.w.values:
            self.modes.set_context({}, self.w.values["family"])
            self.w.values.pop("modes", None)
        self._wish()
        self.show_step()
    def keep_choices(self):
        from studio.editor import gamemodes as gm
        self.keep_picks = True
        fam = self.w.values.get("family")
        if fam and "modes" not in self.w.values:
            self.w.values["modes"] = [str(k) for k in gm.defaults({}, fam)]
        self._wish()
        self.show_step()
    def fit_size(self, screen=None):
        need_w = max(980, self.mode_scroll.widget().minimumSizeHint().width() + 80)
        try:
            from PySide6.QtGui import QGuiApplication
            scr = screen or (self.parentWidget().screen() if self.parentWidget() is not None
                             else QGuiApplication.primaryScreen())
            geo = scr.availableGeometry()
            w = min(need_w, int(geo.width() * 0.92))
            h = min(max(640, int(geo.height() * 0.75)), int(geo.height() * 0.88))
        except Exception:
            w, h = need_w, 720
        self.resize(w, h)
        return w, h
    def go_to(self, step):
        if step in wizmod.STEPS and wizmod.STEPS.index(step) <= self.seen:
            self.w.step = wizmod.STEPS.index(step)
            self.show_step()
        return self.w.current
    def show_step(self):
        step = self.w.current
        i = wizmod.STEPS.index(step)
        self.seen = max(self.seen, i)
        self.pages.setCurrentIndex(i)
        words = []
        for k, s in enumerate(wizmod.STEPS):
            if s == step:
                words.append("<b>%s</b>" % s.capitalize())
            elif k <= self.seen:
                words.append('<a href="%s">%s</a>' % (s, s.capitalize()))
            else:
                words.append(s.capitalize())
        self.steps.setText("  &gt;  ".join(words))
        self.title.setText(wizmod.TITLES[step])
        self.help.setText(wizmod.HELP[step])
        self.back_btn.setVisible(i > 0)
        self.back_btn.setEnabled(i > 0)
        made = bool(self.ed.session.doc.refs("piece")) and self.generated
        if step == "generate":
            self.next_btn.setText("Put it into the game \u25b6")
            self.next_btn.setEnabled(made and not self.ed.jobs.busy())
        else:
            self.next_btn.setText("Next")
            self.next_btn.setEnabled(self.w.can_next())
        self.next_btn.setVisible(step != "export")
        self.quick_btn.setVisible(step in ("mode", "size", "theme", "wish")
                                  and "family" in self.w.values)
        self.course.setVisible(self.w.offers_course())
        said = self.w.summary()
        self.summary.setText(said if said != "nothing chosen yet" else "")
        self.summary.setVisible(said != "nothing chosen yet")
        if step == "export":
            self._export_page()
    def next(self):
        leaving = self.w.current
        self.w.next()
        self.show_step()
        if leaving == "generate" and self.w.current == "export":
            self.export(auto=True)
    def build_now(self):
        self.w.step = wizmod.STEPS.index("generate")
        self.show_step()
        self.generate()
    def back(self):
        self.w.back()
        self.show_step()
    def fill_wish_panel(self):
        raw, _ = self.w.brief()
        panel = self.ed.wish_panel
        panel.text.setPlainText(self.w.wish.strip())
        shown = dict(self.w.values)
        if self.w.wish.strip():
            shown["wish"] = self.w.wish.strip()
        panel.load_brief(shown)
        return raw
    generated = False
    _ours = False
    def generate(self):
        self.fill_wish_panel()
        self.gen_btn.setEnabled(False)
        self.gen_said.setText("Building... the engine tries several maps and keeps the best.")
        self._ours = True
        self.ed.run_action("map.generate")
        if not self.ed.jobs.busy():
            self._ours = False
            self.gen_btn.setEnabled(True)
        self.show_step()
    def _started(self, label):
        if not self._ours:
            return
        try:
            self.gen_bar.setRange(0, 0)
            self.gen_bar.setFormat(label)
            self.gen_bar.setVisible(True)
            self.gen_cancel.setVisible(True)
            self.gen_cancel.setEnabled(True)
        except RuntimeError:
            pass
    def _progress(self, a, b, text):
        if not self._ours:
            return
        try:
            self.gen_bar.setRange(0, max(0, b))
            self.gen_bar.setValue(max(0, a))
            self.gen_bar.setFormat(text or "%p%")
        except RuntimeError:
            pass
    def _ended(self, reason):
        try:
            QTimer.singleShot(0, self, lambda: self._engine_done(reason))
        except RuntimeError:
            pass
    def _engine_done(self, reason=""):
        ours, self._ours = self._ours, False
        self.gen_bar.setVisible(False)
        self.gen_cancel.setVisible(False)
        if self.w.current != "generate" or not (ours or reason):
            return
        self.gen_btn.setEnabled(True)
        doc = self.ed.session.doc
        n = len(doc.refs("piece"))
        if n and not reason:
            self.generated = True
            self.gen_btn.setText("Generate another one")
            _demote(self.gen_btn)
            made = self.make_course()
            self.gen_said.setText("Done: %d pieces.%s Not this one? Generate another. Happy? "
                                  "Put it into the game." % (n, made))
            self._show_thumb()
            self.show_step()
            self.next_btn.setFocus()
        elif reason == "Cancelled":
            self.gen_said.setText("Stopped. Press the button to build again.")
        elif reason:
            from studio.editor.qt import why_line
            self.gen_said.setText("No map: %s. Change a choice and try again." %
                                  why_line(reason).rstrip("."))
        else:
            self.gen_said.setText("No map yet - see the status bar for why, change a choice "
                                  "and try again.")
    def make_course(self):
        if not self.w.makes_course():
            return ""
        from studio.toolbox import logic
        tool = logic.LogicTool(self.ed.session)
        if not tool.can_make_course():
            return ""
        try:
            change = tool.make_course()
        except logic.LogicError:
            return ""
        change.hand = False
        self.ed.push(change)
        panel = getattr(getattr(self.lib.studio, "logic", None), "panel", None)
        if panel is not None:
            panel.refresh()
        n = sum(1 for step in change.steps if step[0] == "insert") - 1
        return (" %d pop-up targets and a start button are in: press the button in the start "
                "room to run the course." % n)
    def _show_thumb(self):
        layout = self.ed.session.doc.to_layout()
        side = max(160, min(320, self.pages.height() - 160))
        def job(_progress, _cancelled):
            from mapgen.render import views
            im = views.top_down(layout, size=side).convert("RGBA")
            return im.width, im.height, im.tobytes("raw", "RGBA")
        def done(got):
            from PySide6.QtGui import QImage, QPixmap
            try:
                w, h, data = got
                img = QImage(data, w, h, 4 * w, QImage.Format_RGBA8888).copy()
                self.thumb.setPixmap(QPixmap.fromImage(img))
                self.thumb.setVisible(True)
            except RuntimeError:
                pass
        if not self._checks.busy():
            self._checks.run("Picture", job, done, lambda _why: None)
    def suggested_name(self):
        theme = self.w.values.get("theme")
        fam = self.w.values.get("family") or self.ed.session.doc.brief.get("family")
        kinds = dict(wizmod.choices("family"))
        looks = dict(wizmod.choices("theme"))
        words = []
        if theme and theme in looks:
            words.append(looks[theme].split(" (")[0])
        if fam and fam in kinds:
            words.append(kinds[fam].split(" (")[0])
        base = " ".join(words) if words else "My first"
        return ("%s map" % base).replace("  ", " ").strip().title()
    def _export_page(self):
        from studio.editor import modfolder
        doc = self.ed.session.doc
        if not self.name.text().strip():
            have = doc.rest.get("name")
            self.name.setText(have if have and have != "Untitled map" else self.suggested_name())
        if not self.mod or modfolder.why_not(self.mod):
            self.mod = modfolder.choose(self.ed.settings_get("export.mod")) or ""
        bad = modfolder.why_not(self.mod)
        self.mod_said.setText("Into the mod at %s" % self.mod if not bad else
                              "The mod folder was not found on this machine - choose it once, "
                              "the Studio remembers it.")
        self.mod_btn.setText("Change\u2026" if not bad else "Choose the mod folder\u2026")
        self.exp_btn.setEnabled(not bad and not self._busy_export())
    def _busy_export(self):
        return self._checks.busy() or (self.ed.jobs.busy() and self.ed.jobs.label.startswith(
            "Exporting"))
    def choose_mod(self):
        from PySide6.QtWidgets import QFileDialog
        d = QFileDialog.getExistingDirectory(self, "The mod folder", self.mod or "")
        if d:
            self.mod = d
            self._export_page()
        return d
    def expert_export(self):
        dlg = self.ed.export_dialog()
        if self.name.text().strip():
            dlg.name.setText(self.name.text().strip())
        if self.mod:
            dlg.mod.setText(self.mod)
        return dlg
    def _unique_key(self, name):
        from studio.editor import engine
        key = engine.key_for(name)
        n = 2
        while engine.replaces(key, self.mod) and (self.exported or {}).get("key") != key:
            key = engine.key_for("%s %d" % (name, n))
            n += 1
        return key
    def export(self, auto=False):
        from studio.editor import gamemodes as gm, modfolder
        self._export_page()
        name = self.name.text().strip() or self.suggested_name()
        if modfolder.why_not(self.mod):
            if not auto:
                self.choose_mod()
                if modfolder.why_not(self.mod):
                    return False
            else:
                return False
        if self._busy_export():
            return False
        doc = self.ed.session.doc
        layout = doc.to_layout()
        mod = self.mod
        key = self._unique_key(name)
        self.banner.clear()
        self.exp_btn.setEnabled(False)
        self.exp_bar.setVisible(True)
        self.exp_said.setText("Checking the map...")
        def job(_progress, _cancelled):
            from studio.editor import childcall
            return childcall.call("studio.editor.engine:export_checks", layout, mod)
        def checked(got):
            from studio.editor import engine
            try:
                faults, size = got
                pick = gm.current(doc)
                lay = doc.to_layout(models=False)
                fam = gm.family_of(doc)
                modes = gm.resolve(pick, lay, fam)
                problems = engine.check_export(
                    None, name, key, mod, gate_faults=faults, size=size, modes=modes[0],
                    mode_layout=lay, players=gm.players_of(doc), map_size=gm.brief_size(doc))
                playable = [p for p in problems if " is not playable yet: " in p]
                hard = [p for p in problems if p not in playable]
                if hard:
                    self._export_failed(hard[0], more=len(hard) - 1)
                    return
                if playable:
                    ready = [k for k in modes[0] if not any(
                        p.startswith("%s is not playable" % gm.name_of(k)) for p in playable)]
                    modes = (ready or modes[0], modes[1])
                self.exp_said.setText("Writing it into the mod...")
                self.ed.export(name, key, mod, None, lambda res: self._exported(res, name, key),
                               self._export_failed, modes=modes)
            except RuntimeError:
                pass
        self._checks.run("Checking the export", job, checked, self._export_failed)
        return True
    def _exported(self, res, name, key):
        try:
            self.exp_bar.setVisible(False)
            self.exported = {"name": name, "key": key, "mod": self.mod, "res": res}
            self.ed.settings_set("export.mod", self.mod)
            self.exp_said.setText(res.get("handoff", "").split("\n")[0])
            ux = getattr(self.lib.studio, "ux", None)
            self.banner.ok("\u201c%s\u201d is in the game" % name,
                           "Start Coop DX with the mod, host, then Travel > Arenas.",
                           ux, opener=self._open_mod, player=self.play_now)
            self.exp_btn.setText("Put it in again")
            self.exp_btn.setEnabled(True)
            _demote(self.exp_btn)
        except RuntimeError:
            pass
    def _export_failed(self, reason, more=0):
        try:
            from studio.editor.qt import why_line
            self.exp_bar.setVisible(False)
            self.exp_btn.setEnabled(True)
            line = why_line(str(reason)) if why_line else str(reason)
            self.banner.fail("Not in the game yet", line + (" (and %d more - see More export "
                                                           "options)" % more if more else ""))
            self.exp_said.setText("")
        except RuntimeError:
            pass
    def play_now(self):
        return self.ed.launch_game(self.mod)
    def _open_mod(self):
        import os
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices
        if self.mod and os.path.isdir(self.mod):
            return QDesktopServices.openUrl(QUrl.fromLocalFile(self.mod))
        return False
    def _pause_tour(self):
        coach = getattr(getattr(self.lib.studio, "ux", None), "parts", {}).get("coachui")
        if coach is not None and getattr(coach, "active", False):
            coach.pause()
            return coach
        return None
    def _closed(self, *_):
        try:
            self.ed.jobs.ended.disconnect(self._ended)
            self.ed.jobs.started.disconnect(self._started)
            self.ed.jobs.progress.disconnect(self._progress)
        except (RuntimeError, TypeError):
            pass
        if self.paused_tour is not None:
            self.paused_tour.unpause()
            self.paused_tour = None
    def _first_focus(self):
        try:
            b = next(iter(self.family.buttons.values()), None)
            (b or self.next_btn).setFocus()
        except RuntimeError:
            pass
VENUE_CARD = "From a template"
def built_in_venues():
    from mapgen import v1
    from studio.core import loader
    return [(k, "The " + loader.venue_name(k)) for k in v1.venue_keys()]
def venue_card_text():
    names = [name for _, name in built_in_venues()]
    rest = len([t for t in wizmod.templates()
                if not t[0].startswith(("venue:", "playground:"))])
    what = names[0] if len(names) == 1 else "a venue"
    what += ", the Playground"
    if rest:
        what += ", %d more" % rest
    return "%s - a new map" % what
class StartCards(QFrame):
    def __init__(self, lib, parent):
        super().__init__(parent)
        self.lib = lib
        self.setObjectName("card")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(18, 16, 18, 16)
        t = QLabel("Oldfart Studio - start a map")
        t.setObjectName("title")
        lay.addWidget(t)
        sub = QLabel("An empty map. Pick a way in - everything can be changed later.")
        sub.setObjectName("caption")
        lay.addWidget(sub)
        grid = self.grid = QGridLayout()
        grid.setSpacing(8)
        cards = (
            ("Your first map", "a few friendly steps", lib.first_map),
            ("From a wish", "say what you want; Ctrl+Enter builds it", self._wish),
            (VENUE_CARD, venue_card_text(), self._venue),
            ("Open a map...", "a .ofmap or a generator folder", lambda: lib.ed.open_dialog()),
        )
        self.buttons = []
        for i, (title, text, fn) in enumerate(cards):
            b = big_button(title, text, checkable=False)
            b.clicked.connect(fn)
            grid.addWidget(b, i // 2, i % 2)
            self.buttons.append(b)
        self.first_button = self.buttons[0]
        self.hint = QLabel("")
        self.hint.setObjectName("caption")
        self.hint.setWordWrap(True)
        self.hint.hide()
        lay.addWidget(self.hint)
        lay.addLayout(grid)
        self.hand_title = QLabel("Or build it by hand")
        self.hand_title.setObjectName("caption")
        self.hand = QLabel("")
        self.hand.setObjectName("caption")
        self.hand.setWordWrap(True)
        lay.addWidget(self.hand_title)
        lay.addWidget(self.hand)
        self.fill_hand()
        from PySide6.QtWidgets import QListWidget
        self.maps = QListWidget()
        self.maps.setToolTip("Maps opened before: double-click or Enter opens one, Delete "
                             "takes it off this list (the file stays)")
        self.maps.setMaximumHeight(130)
        self.maps.itemActivated.connect(self.open_item)
        from studio.ui import keyguard
        keyguard.list_keys(self.maps, {Qt.Key_Delete: self.forget_current})
        self.maps_title = QLabel("Recent maps")
        self.maps_title.setObjectName("caption")
        lay.addWidget(self.maps_title)
        lay.addWidget(self.maps)
        self.fill_maps()
        self._pulse = QTimer(self)
        self._pulse.setInterval(PULSE_MS)
        self._pulse.timeout.connect(self._beat)
        self._beats = 0
        self.adjustSize()
    def fill_hand(self):
        lines = list(getattr(self.lib.studio.ctx, "empty_lines", None) or ())[1:]
        if not any("F3" in ln for ln in lines):
            lines.append("F3  find any command")
        lines.append("Ctrl+Shift+T  import your own textures")
        self.hand.setText("\n".join(lines))
        return lines
    def fill_maps(self):
        import os
        from PySide6.QtWidgets import QListWidgetItem
        self.maps.clear()
        recent = list(getattr(self.lib.studio.settings, "recent", None) or [])
        for path in recent:
            if not os.path.exists(path):
                continue
            name = os.path.basename(os.path.normpath(path))
            item = QListWidgetItem("%s   %s" % (name, os.path.dirname(path)))
            item.setData(Qt.UserRole, path)
            item.setToolTip(path)
            self.maps.addItem(item)
        has = self.maps.count() > 0
        self.maps.setVisible(has)
        self.maps_title.setVisible(has)
        return self.maps.count()
    def open_item(self, item):
        path = item.data(Qt.UserRole) if item is not None else None
        if path:
            self.lib.ed.open_source(path)
        return path
    def forget_current(self):
        item = self.maps.currentItem()
        if item is None:
            return None
        path = item.data(Qt.UserRole)
        s = self.lib.studio.settings
        s.recent = [p for p in s.recent if p != path]
        self.fill_maps()
        return path
    def draw_attention(self, att):
        b = self.first_button
        b.setProperty("attention", "true" if att["highlight"] else "false")
        b.setProperty("pulse", "off")
        self.hint.setText(att["hint"])
        self.hint.setVisible(bool(att["hint"]))
        self._beats = 0
        if att["pulse"]:
            self._pulse.start()
        else:
            self._pulse.stop()
        self._restyle()
        self.adjustSize()
    def calm(self):
        self.draw_attention({"open": False, "highlight": False, "pulse": False, "hint": ""})
    def pulsing(self):
        return self._pulse.isActive()
    def _beat(self):
        self._beats += 1
        b = self.first_button
        b.setProperty("pulse", "on" if b.property("pulse") != "on" else "off")
        if self._beats >= PULSE_BEATS:
            self._pulse.stop()
            b.setProperty("pulse", "off")
        self._restyle()
    def _restyle(self):
        b = self.first_button
        b.style().unpolish(b)
        b.style().polish(b)
        b.update()
    def _wish(self):
        d = self.lib.studio.docks.get("wish")
        if d is not None:
            d.show()
            d.raise_()
        self.lib.ed.wish_panel.text.setFocus()
    def _venue(self):
        from PySide6.QtWidgets import QMenu
        got = wizmod.templates()
        if len(got) == 1:
            return self.open_template(got[0][0], got[0][1])
        m = QMenu(self)
        m.setToolTipsVisible(True)
        venue = True
        for source, name, what in got:
            if venue and not source.startswith(("venue:", "playground:")):
                m.addSeparator()
                venue = False
            a = m.addAction("%s - %s" % (name, what))
            a.setData(source)
            a.triggered.connect(lambda _=False, src=source, n=name: self.open_template(src, n))
        self.template_menu = m
        b = self.buttons[2] if len(self.buttons) > 2 else self
        m.popup(b.mapToGlobal(b.rect().bottomLeft()))
        return m
    def open_template(self, source, name):
        ed = self.lib.ed
        if not ed.open_source(source, recent=False):
            return False
        ed.hint("%s is open as a copy - change it, then Ctrl+S saves it under a new name"
                % name)
        return True
    def fit(self, width, height):
        cols = 2
        for b in self.buttons:
            self.grid.removeWidget(b)
        two = 2 * max(b.minimumSizeHint().width() for b in self.buttons) + 8 + 40
        if two > width:
            cols = 1
        for i, b in enumerate(self.buttons):
            self.grid.addWidget(b, i // cols, i % cols)
        for w in (self.hand_title, self.hand):
            w.setVisible(True)
        self.maps.setVisible(self.maps.count() > 0)
        self.maps_title.setVisible(self.maps.count() > 0)
        self.setMaximumWidth(max(240, width))
        self.adjustSize()
        for drop in ((self.maps, self.maps_title), (self.hand, self.hand_title)):
            if self.sizeHint().height() <= height:
                break
            for w in drop:
                w.setVisible(False)
            self.adjustSize()
        self.columns = cols
        return cols
    def _bars(self):
        p = self.parentWidget()
        return [w for w in p.children() if isinstance(w, QWidget) and w is not self
                and not w.isWindow() and type(w).__name__ in ("HotbarWidget", "Bar")] \
            if p is not None else []
    def place(self):
        p = self.parentWidget()
        if p is None:
            return
        top = 30
        bars = [w for w in self._bars() if w.isVisible() or w in getattr(self, "_hid", ())]
        floor = min([w.y() for w in bars], default=p.height()) if bars else p.height()
        self.fit(p.width() - 16, floor - top - 8)
        if self.height() > floor - top - 4 and bars:
            self._hid = [w for w in bars if w.isVisible()] + list(getattr(self, "_hid", ()))
            for w in self._hid:
                w.hide()
            floor = p.height()
            self.fit(p.width() - 16, floor - top - 8)
        room = floor - self.height()
        self.move(max(0, (p.width() - self.width()) // 2),
                  max(min(top, room), room // 2, 0))
        self.raise_()
    def hideEvent(self, ev):
        for w in getattr(self, "_hid", ()):
            try:
                w.show()
            except RuntimeError:
                pass
        self._hid = []
        super().hideEvent(ev)
