import threading
from PySide6.QtCore import QObject, Qt, Signal
from PySide6.QtWidgets import (QCheckBox, QComboBox, QHBoxLayout, QLabel, QLineEdit,
                               QMessageBox, QPushButton, QSizePolicy, QVBoxLayout, QWidget)
from mapgen import backends
from mapgen.backends import ollama as ollamamod
from . import model
CHOICES = (("auto", "Best available"), ("offline", "Offline rules"), ("claude", "Claude API"),
           ("ollama", "Ollama"))
class _Bridge(QObject):
    status = Signal(object, object)
    models = Signal(object)
def _chip_style(label, colour):
    label.setStyleSheet("QLabel { background: %s; color: #0e1116; border-radius: 9px; "
                        "padding: 1px 8px; font-weight: 600; }" % colour)
class WishBackends(QObject):
    def __init__(self, studio):
        super().__init__(studio.window)
        self.studio = studio
        self.ed = studio.editor
        self.panel = self.ed.wish_panel
        self.settings = studio.settings
        self.tokens = studio.ctx.tokens
        self.book = model.Readings()
        self.status = None
        self.resolved = None
        self.auto_why = ""
        self.question = None
        self._bridge = _Bridge()
        self._bridge.status.connect(self._got_status)
        self._probe_n = 0
        self._build_row()
        self._hook()
        self.settings.listen(self._setting)
        self.refresh_status()
    def _build_row(self):
        p = self.panel
        box = QWidget()
        col = QVBoxLayout(box)
        col.setContentsMargins(0, 0, 0, 0)
        col.setSpacing(4)
        row = QHBoxLayout()
        row.setSpacing(6)
        row.addWidget(QLabel("Read by"))
        self.picker = QComboBox()
        for key, label in CHOICES:
            self.picker.addItem(label, key)
        self.picker.setToolTip("Who reads the free text. Best available: Claude when its key "
                               "is set and it answers, else a running Ollama model, else the "
                               "offline rules (always there). The map is always built by the "
                               "engine; Preferences > Wish backends has the key and the models.")
        self.picker.setCurrentIndex(max(0, self.picker.findData(model.backend_of(self.settings))))
        self.picker.currentIndexChanged.connect(self._picked)
        self.picker.setMinimumContentsLength(10)
        self.picker.setSizeAdjustPolicy(QComboBox.AdjustToMinimumContentsLengthWithIcon)
        row.addWidget(self.picker, 1)
        self.chip = QLabel("built in")
        self.chip.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)
        self.ask_btn = QPushButton("Ask")
        self.ask_btn.setToolTip("Let the chosen backend read the wish now and show what it "
                                "added to the offline reading (Generate asks by itself)")
        self.ask_btn.clicked.connect(lambda: self.ask())
        row.addWidget(self.ask_btn)
        col.addLayout(row)
        col.addWidget(self.chip, 0, Qt.AlignLeft)
        self.caption = QLabel("")
        self.caption.setObjectName("caption")
        self.caption.setWordWrap(True)
        self.caption.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.caption.setVisible(False)
        col.addWidget(self.caption)
        lay = p.reading.parentWidget().layout()
        lay.insertWidget(lay.indexOf(p.reading) + 1, box)
        self.row = box
    def _picked(self, *_):
        key = self.picker.currentData()
        if key != model.backend_of(self.settings):
            self.settings.set("wish.backend", key)
            try:
                self.settings.save()
            except OSError:
                pass
    def _setting(self, key, value):
        if key == "wish.backend":
            i = self.picker.findData(value)
            if i >= 0 and i != self.picker.currentIndex():
                self.picker.blockSignals(True)
                self.picker.setCurrentIndex(i)
                self.picker.blockSignals(False)
        if key.startswith("wish."):
            self.refresh_status()
            self._show_reading(self.current())
            self.panel.read_now()
    def config(self):
        return model.config(self.settings, self.resolved)
    def refresh_status(self, probe=False):
        self._probe_n += 1
        n = self._probe_n
        if model.backend_of(self.settings) == model.AUTO:
            self._show_chip("checking", "text_dim", "Looking for an AI backend that answers")
            self._auto(n)
            return
        self.resolved = None
        cfg = self.config()
        if cfg.backend == "offline":
            self._got_status(n, backends.status(cfg))
            return
        self._show_chip("checking", "text_dim", "Asking %s whether it can answer"
                        % model.LABELS[cfg.backend])
        def work():
            try:
                st = backends.status(cfg, probe=probe)
            except Exception as why:
                st = backends.Status(cfg.backend, False, "%s: error" % model.LABELS[cfg.backend],
                                     backends.scrub(why))
            self._bridge.status.emit(n, st)
        threading.Thread(target=work, daemon=True).start()
    def _auto(self, n):
        def work():
            statuses = {}
            for b in model.AUTO_ORDER:
                cfg = model.config(self.settings, b)
                try:
                    st = backends.status(cfg)
                    if b == "claude" and st.ok:
                        st = backends.status(cfg, probe=True)
                except Exception as why:
                    st = backends.Status(b, False, "%s: error" % model.LABELS[b],
                                         backends.scrub(why))
                statuses[b] = st
            self._bridge.status.emit(n, statuses)
        threading.Thread(target=work, daemon=True).start()
    def _got_status(self, n, st):
        if n != self._probe_n:
            return
        if isinstance(st, dict):
            before = self.resolved
            self.resolved, self.auto_why = model.pick_auto(st)
            self.status = st.get(self.resolved) or backends.status(self.config())
            self._show_chip(*model.auto_chip(self.resolved, self.auto_why))
            if before != self.resolved:
                self._show_reading(self.current())
                self.panel.read_now()
            return
        self.status = st
        text, tone, tip = model.chip(st)
        self._show_chip(text, tone, tip)
    def _show_chip(self, text, tone, tip):
        self.chip.setText(text)
        self.chip.setToolTip(tip)
        _chip_style(self.chip, self.tokens.get(tone, self.tokens["text_dim"]))
    def ask(self, then=None):
        text = self.panel.wish_text()
        cfg = self.config()
        if not text:
            self.ed.hint("Type a wish first")
            return False
        if cfg.backend == "offline":
            self._show_reading(None)
            if then:
                then()
            return True
        def job(progress, cancelled):
            progress(0, 0, "%s reads the wish" % model.LABELS[cfg.backend])
            return backends.read(text, cfg)
        def done(reading):
            self.book.put(reading, cfg)
            self._show_reading(reading)
            self.ed.hint(model.status_line(reading))
            if reading.fell_back:
                self.refresh_status()
            if then:
                then()
        return self.ed.jobs.run("Asking %s" % model.LABELS[cfg.backend], job, done)
    def _show_reading(self, reading):
        lines = model.reading_lines(reading) if reading is not None else []
        self.caption.setText("\n".join(lines))
        self.caption.setVisible(bool(lines))
    def current(self):
        return self.book.fresh(self.panel.wish_text(), self.config())
    def _hook(self):
        panel, ed = self.panel, self.ed
        orig_brief = panel.brief
        orig_generate = ed.generate
        def brief():
            r = self.current()
            if r is None or r.used == "offline":
                return orig_brief()
            doc = ed.session.doc.brief or {}
            base = {k: doc.get(k) for k in ("anchors", "objects", "name") if doc.get(k)}
            return model.brief_for(r, panel.values(), base or None)
        def generate():
            cfg = self.config()
            if model.needs_ask(panel.wish_text(), cfg, self.book) and not ed.jobs.busy() \
                    and self.read_first(cfg):
                return self.ask(then=orig_generate)
            return orig_generate()
        def explain():
            raw, _ = panel.brief()
            from studio.editor import engine
            ed.show_text("What the engine reads", model.explain_text(self.current(),
                                                                     engine.explain(raw)))
        def refine_reader(text, doc_brief, progress=None):
            cfg = self.config()
            if cfg.backend != "offline" and progress is not None:
                progress(0, 0, "%s reads the change" % model.LABELS[cfg.backend])
            return model.refine_ops(text, doc_brief, cfg)
        panel.brief = brief
        ed.generate = generate
        ed.refine_reader = refine_reader
        panel.explain = explain
        try:
            panel.explain_btn.clicked.disconnect()
        except (RuntimeError, TypeError):
            pass
        panel.explain_btn.clicked.connect(explain)
        panel.explain_btn.setToolTip("The brief in words - every assumed field marked - and "
                                     "where the anchors go; with Claude or Ollama, its own "
                                     "reading (why) and what it changed come first")
        panel.text.textChanged.connect(self._text_changed)
    def _text_changed(self):
        r = self.current()
        self._show_reading(r)
    def read_first(self, cfg):
        known = model.ask_first(self.settings)
        if known != "ask":
            return known
        if self.question is not None:
            yes, remember = self.question(cfg)
        else:
            box = QMessageBox(self.studio.window)
            box.setWindowTitle("Read the wish first?")
            box.setText("Let %s read the changed wish before Generate?" % model.LABELS[cfg.backend])
            box.setInformativeText("Yes: it reads the wish, then the engine builds its brief. "
                                   "No: the engine builds what the offline rules read.")
            box.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
            box.setDefaultButton(QMessageBox.Yes)
            remember_box = QCheckBox("Remember my choice")
            remember_box.setToolTip("Do not ask again - Preferences > Wish backends > Forget "
                                    "my choice asks again")
            box.setCheckBox(remember_box)
            yes = box.exec() == QMessageBox.Yes
            remember = remember_box.isChecked()
        model.answered(self.settings, yes, remember)
        if remember:
            try:
                self.settings.save()
            except OSError:
                pass
        return yes
def prefs_extra(dialog, form):
    s = dialog.s
    bridge = _Bridge(dialog)
    where = QLabel(model.key_where())
    where.setObjectName("caption")
    where.setWordWrap(True)
    key = QLineEdit()
    key.setEchoMode(QLineEdit.Password)
    key.setPlaceholderText("paste an API key (sk-ant-...)")
    key.setToolTip("Kept in your config folder, readable only by you; never in settings.json, "
                   "never in a log. ANTHROPIC_API_KEY wins over it.")
    save = QPushButton("Save key")
    remove = QPushButton("Remove key")
    save.setToolTip("Store the key for the Claude backend")
    remove.setToolTip("Delete the stored key")
    row = QHBoxLayout()
    row.addWidget(key, 1)
    row.addWidget(save)
    row.addWidget(remove)
    def store(value):
        try:
            backends.store_key(value)
            where.setText(model.key_where())
        except OSError as why:
            where.setText("Could not write the key file: %s" % why)
        key.clear()
    save.clicked.connect(lambda: store(key.text()))
    remove.clicked.connect(lambda: store(""))
    form.addRow("Claude API key", row)
    form.addRow("", where)
    from mapgen.backends import claude as claudemod, sdkenv
    sdk = QPushButton("Install Claude support")
    sdk.setToolTip("Make a small Python environment in your data folder and install the "
                   "pinned Claude SDK there (its file checked against vendor.lock)")
    sdk_said = QLabel("" if claudemod.sdk_installed() else
                      "Claude support is not installed. The button sets it up; by hand: "
                      + sdkenv.manual_command())
    sdk_said.setObjectName("caption")
    sdk_said.setWordWrap(True)
    sdk_said.setTextInteractionFlags(Qt.TextSelectableByMouse)
    def install_sdk():
        sdk.setEnabled(False)
        sdk_said.setText("Installing Claude support ... (a minute, needs the network once)")
        def work():
            res = sdkenv.install()
            bridge.status.emit("sdk", backends.Status("claude", res.ok, "sdk", res.message))
        threading.Thread(target=work, daemon=True).start()
    def sdk_done(name, st):
        if name != "sdk":
            return
        sdk_said.setText(st.detail if st.ok else "Not installed: " + st.detail)
        sdk.setEnabled(not claudemod.sdk_installed())
        sdk.setVisible(not claudemod.sdk_installed())
    bridge.status.connect(sdk_done)
    sdk.clicked.connect(install_sdk)
    sdk.setVisible(not claudemod.sdk_installed())
    dialog._install_sdk = install_sdk
    dialog._sdk_widgets = (sdk, sdk_said)
    form.addRow(sdk, sdk_said)
    test = QPushButton("Test the backend")
    test.setToolTip("Ask the chosen backend whether it answers (Claude: one small request to "
                    "the API; Ollama: its local port)")
    result = QLabel("")
    result.setObjectName("caption")
    result.setWordWrap(True)
    def run_test():
        cfg = model.config(s)
        result.setText("Testing %s ..." % model.LABELS[cfg.backend])
        def work():
            try:
                st = backends.status(cfg, probe=True)
                bridge.status.emit(None, st)
            except Exception as why:
                bridge.status.emit(None, backends.Status(cfg.backend, False, "error",
                                                         backends.scrub(why)))
        threading.Thread(target=work, daemon=True).start()
    bridge.status.connect(lambda _n, st: _n != "sdk" and result.setText(
        "%s - %s" % (st.label, st.detail)))
    test.clicked.connect(run_test)
    form.addRow(test, result)
    pick = QComboBox()
    pick.setToolTip("The models Ollama has installed (ollama list); choosing one sets "
                    "'Ollama model' above")
    refresh = QPushButton("Installed models")
    refresh.setToolTip("Ask Ollama which models are installed")
    mrow = QHBoxLayout()
    mrow.addWidget(pick, 1)
    mrow.addWidget(refresh)
    def list_models():
        cfg = model.config(s)
        def work():
            try:
                bridge.models.emit(ollamamod.models(cfg))
            except (backends.Unavailable, backends.BadReply) as why:
                bridge.models.emit(str(why))
        threading.Thread(target=work, daemon=True).start()
    def got_models(names):
        pick.blockSignals(True)
        pick.clear()
        if isinstance(names, str):
            pick.addItem(names, "")
        else:
            pick.addItem("(the first installed)", "")
            for n in names:
                pick.addItem(n, n)
            i = pick.findData(s.get("wish.ollama_model"))
            pick.setCurrentIndex(max(0, i))
        pick.blockSignals(False)
    def chosen(_i):
        if pick.currentData() is not None:
            s.set("wish.ollama_model", pick.currentData())
            ed = dialog.editors.get("wish.ollama_model")
            if ed is not None and hasattr(ed, "setText"):
                ed.setText(pick.currentData())
    bridge.models.connect(got_models)
    refresh.clicked.connect(list_models)
    pick.currentIndexChanged.connect(chosen)
    form.addRow("Ollama models", mrow)
    forget = QPushButton("Forget my choice")
    forget.setToolTip("Generate asks again whether the AI reads a changed wish first")
    forget_said = QLabel("")
    forget_said.setObjectName("caption")
    def do_forget():
        model.forget(s)
        ed = dialog.editors.get(model.ASK_KEY)
        if ed is not None and hasattr(ed, "findData"):
            ed.setCurrentIndex(max(0, ed.findData("ask")))
        forget_said.setText("Generate will ask again")
    forget.clicked.connect(do_forget)
    form.addRow(forget, forget_said)
    dialog._wish_bridge = bridge
def install(studio):
    from studio.ui import prefs
    extras = prefs.PAGE_EXTRAS.setdefault("Wish backends", [])
    if prefs_extra not in extras:
        extras.append(prefs_extra)
    wb = WishBackends(studio)
    studio.wish_backends = wb
    return wb
