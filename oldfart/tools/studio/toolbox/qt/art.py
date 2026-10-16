from PySide6.QtCore import QSize, Qt, QTimer
from PySide6.QtGui import QBrush, QColor, QPainter, QPixmap
from PySide6.QtWidgets import (QCheckBox, QComboBox, QGridLayout, QHBoxLayout, QLabel,
                               QListWidget, QListWidgetItem, QPushButton, QScrollArea,
                               QVBoxLayout, QWidget)
from studio.toolbox import artmodels, verbs
BAND_PAUSE_MS = 250
def _caption(text):
    lab = QLabel(text)
    lab.setWordWrap(True)
    lab.setObjectName("caption")
    return lab
class VerbsPanel(QWidget):
    def __init__(self, art):
        super().__init__()
        self.art = art
        self.ed = art.ed
        self.current = verbs.ORDER[0]
        lay = QVBoxLayout(self)
        lay.addWidget(_caption("Detail the selection (nothing selected: every piece a verb "
                               "fits). The bands are the result's guards before you apply - "
                               "green fine, amber a warning, red a guard broken."))
        grid = QGridLayout()
        self.buttons = {}
        for k, rid in enumerate(verbs.ORDER):
            b = QPushButton(verbs.label(rid))
            b.setToolTip(verbs.about(rid))
            b.setCheckable(True)
            b.clicked.connect(lambda _=False, r=rid: self.pick(r))
            b.installEventFilter(self)
            grid.addWidget(b, k // 2, k % 2)
            self.buttons[rid] = b
        lay.addLayout(grid)
        self.bands = QListWidget()
        self.bands.setMinimumHeight(150)
        lay.addWidget(self.bands, 1)
        row = QHBoxLayout()
        self.apply_btn = QPushButton("Apply")
        self.apply_btn.setObjectName("primary")
        self.apply_btn.setToolTip("Lay the verb's pieces on the selection (one undo step)")
        self.apply_btn.clicked.connect(self.apply)
        row.addStretch(1)
        row.addWidget(self.apply_btn)
        lay.addLayout(row)
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(BAND_PAUSE_MS)
        self._timer.timeout.connect(lambda: self.measure())
        self.buttons[self.current].setChecked(True)
    def eventFilter(self, obj, ev):
        from PySide6.QtCore import QEvent
        if ev.type() == QEvent.Enter:
            for rid, b in self.buttons.items():
                if b is obj and rid != self.current:
                    self.show_bands(verbs.preview(self.ed.session.doc, self.ed.session.refs(),
                                                  rid), rid)
        elif ev.type() == QEvent.Leave:
            self._timer.start()
        return False
    def pick(self, rid):
        self.current = rid
        for r, b in self.buttons.items():
            b.setChecked(r == rid)
        self.measure(force=True)
    def schedule(self):
        self._timer.start()
    def showEvent(self, ev):
        super().showEvent(ev)
        if getattr(self, "_stale", False):
            self._timer.start()
    def measure(self, force=False):
        if not force and not self.isVisible():
            self._stale = True
            return
        self._stale = False
        try:
            got = verbs.preview(self.ed.session.doc, self.ed.session.refs(), self.current)
        except Exception as why:
            self.bands.clear()
            self.bands.addItem("cannot measure: %s" % why)
            return
        self.show_bands(got, self.current)
    def show_bands(self, bands, rid):
        self.bands.clear()
        head = QListWidgetItem("%s - %s" % (verbs.label(rid), verbs.about(rid)))
        self.bands.addItem(head)
        for b in bands:
            item = QListWidgetItem("%s: %s  (%s)" % (b["name"], b["value"], b["text"]))
            item.setForeground(QBrush(QColor(*verbs.STATE_COLOURS[b["state"]])))
            item.setToolTip(b["text"])
            self.bands.addItem(item)
    def apply(self):
        ch, bands, lines = verbs.apply_verb(self.ed.session.doc, self.ed.session.refs(),
                                            self.current)
        if ch:
            self.ed.push(ch)
        self.show_bands(bands, self.current)
        self.ed.hint("; ".join(lines[:3]))
class PatternsPanel(QWidget):
    def __init__(self, art):
        super().__init__()
        from mapgen import hostpatterns
        self.art = art
        self.ed = art.ed
        self.store = hostpatterns.Store.load()
        lay = QVBoxLayout(self)
        lay.addWidget(_caption("Select two pieces that meet, then say Never or Like. The "
                               "pattern is what they are and how they meet, not where: every "
                               "map from now obeys it (a Never piece that yields is taken "
                               "out, else the map is refused; a Like counts for the map)."))
        self.widen = {}
        for key, text in artmodels.WIDEN:
            c = QCheckBox("any " + text)
            c.setToolTip("Leave %s out of the pattern" % text)
            lay.addWidget(c)
            self.widen[key] = c
        row = QHBoxLayout()
        self.never = QPushButton("Never like this")
        self.never.setToolTip("Every later map: never these two meeting like this")
        self.never.clicked.connect(lambda: self.keep("never"))
        self.like = QPushButton("Like this")
        self.like.setToolTip("Every later map: more of these two meeting like this counts")
        self.like.clicked.connect(lambda: self.keep("like"))
        row.addWidget(self.never)
        row.addWidget(self.like)
        lay.addLayout(row)
        self.list = QListWidget()
        lay.addWidget(self.list, 1)
        row = QHBoxLayout()
        rm = QPushButton("Forget")
        rm.setToolTip("Forget the pattern picked in the list")
        rm.clicked.connect(self.forget)
        check = QPushButton("Check this map")
        check.setToolTip("Select the pieces of this map that match a kept pattern")
        check.clicked.connect(self.check)
        row.addWidget(rm)
        row.addStretch(1)
        row.addWidget(check)
        lay.addLayout(row)
        self.refresh()
    def refresh(self):
        self.list.clear()
        for line in artmodels.pattern_rows(self.store):
            self.list.addItem(line)
    def keep(self, kind):
        widen = [k for k, c in self.widen.items() if c.isChecked()]
        pat, why = artmodels.pattern_of(self.ed.session.doc, self.ed.session.refs(), kind, widen)
        if pat is None:
            self.ed.hint(why)
            return
        self.ed.hint(artmodels.keep_pattern(self.store, pat))
        self.refresh()
    def forget(self):
        i = self.list.currentRow()
        if self.store.remove(i):
            try:
                self.store.save()
            except OSError:
                pass
            self.refresh()
    def check(self):
        found = artmodels.check_doc(self.ed.session.doc, self.store)
        doc = self.ed.session.doc
        refs = [r for r in doc.refs("piece") if any(doc.get(r) is a or doc.get(r) is b
                                                     for _, a, b in found)]
        if refs:
            self.ed.session.selection.set(refs)
        self.ed.hint("%d match(es)%s" % (len(found), (": " + found[0][0]) if found else ""))
class GalleryPanel(QWidget):
    def __init__(self, art):
        super().__init__()
        self.art = art
        self.ed = art.ed
        lay = QVBoxLayout(self)
        lay.addWidget(_caption("The gallery: fixed wishes and seeds, the hand venues and one "
                               "pair per finding, each with its accepted card. Use a pair's "
                               "wish, or A/B two of its maps to teach the score your taste."))
        self.list = QListWidget()
        lay.addWidget(self.list, 1)
        row = QHBoxLayout()
        self.use = QPushButton("Use the wish")
        self.use.setToolTip("Put the pair's brief in the wish panel (Generate builds it)")
        self.use.clicked.connect(self.use_pair)
        self.ab = QPushButton("A/B")
        self.ab.setObjectName("primary")
        self.ab.setToolTip("Two maps of the pair's wish side by side: which is better?")
        self.ab.clicked.connect(self.a_b)
        row.addWidget(self.use)
        row.addStretch(1)
        row.addWidget(self.ab)
        lay.addLayout(row)
        self.rows = []
        self.refresh()
    def refresh(self):
        self.list.clear()
        try:
            self.rows = artmodels.gallery_rows()
        except Exception as why:
            self.list.addItem("the gallery is not here: %s" % why)
            self.rows = []
            return
        for r in self.rows:
            item = QListWidgetItem("%s  %s" % (r["id"], r["line"]))
            if r["hard"]:
                item.setForeground(QBrush(QColor(*verbs.STATE_COLOURS["bad"])))
            self.list.addItem(item)
    def _row(self):
        i = self.list.currentRow()
        return self.rows[i] if 0 <= i < len(self.rows) else None
    def use_pair(self):
        r = self._row()
        if r is None:
            return
        brief = artmodels.gallery_brief(r)
        if brief is None:
            self.ed.hint("%s is a hand venue: File > Venues opens it" % r["id"])
            return
        try:
            self.ed.wish_panel.load_brief(brief)
        except Exception:
            self.ed.hint("brief: %s" % brief)
            return
        self.ed.hint("%s's wish is in the wish panel - Generate builds it" % r["id"])
    def a_b(self):
        r = self._row()
        if r is None:
            self.ed.hint("Pick a gallery pair first")
            return
        brief = artmodels.gallery_brief(r)
        if brief is None:
            self.ed.hint("A hand venue has one map - pick a wish pair")
            return
        from studio.library.qt.taste import TasteWindow
        lib = getattr(self.art.studio, "library", None)
        if lib is None:
            self.ed.hint("The library is not installed")
            return
        win = TasteWindow(lib)
        win.brief_override = brief
        win.next_pair = lambda w=win, b=brief: _next_pair_for(w, b)
        win.show()
        win.next_pair()
def _next_pair_for(win, raw):
    from studio.editor import engine
    if win.ed.jobs.busy():
        win.ed.hint("The engine is still working - wait, or Cancel")
        return
    seed = win.session.next_seed(int(raw.get("seed") or 1))
    def job(progress, cancelled):
        return engine.taste_pair(raw, seed=seed, progress=progress, cancel=cancelled)
    win.next.setEnabled(False)
    win.status.setText("Building two maps of the gallery wish (seed %d)..." % seed)
    win.ed.jobs.run("A/B - two maps", job, win.show_pair, win._failed)
class ContractPanel(QWidget):
    def __init__(self, art):
        super().__init__()
        from mapgen import contract
        self.art = art
        self.ed = art.ed
        lay = QVBoxLayout(self)
        lay.addWidget(_caption("What each part of a build may be made of, per theme. Tick a "
                               "family on or off: every later map follows (contract.json). "
                               "Foliage and fabric never go on a built part."))
        self.theme = QComboBox()
        for t in contract.themes():
            self.theme.addItem(t)
        self.theme.currentTextChanged.connect(lambda _t: self.refresh())
        lay.addWidget(self.theme)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        lay.addWidget(self.scroll, 1)
        self.boxes = {}
        self._built = False
    def showEvent(self, ev):
        if not self._built:
            self.refresh()
        super().showEvent(ev)
    def refresh(self):
        self._built = True
        theme = self.theme.currentText()
        body = QWidget()
        grid = QVBoxLayout(body)
        self.boxes = {}
        for row in artmodels.board(theme):
            grid.addWidget(QLabel("<b>%s</b>" % row["cls"].replace("_", " ")))
            tiles = QHBoxLayout()
            for slug in row["tiles"]:
                f = artmodels.tile_file(slug)
                lab = QLabel()
                lab.setToolTip(slug)
                if f:
                    pm = QPixmap(f)
                    if not pm.isNull():
                        lab.setPixmap(pm.scaled(QSize(28, 28), Qt.KeepAspectRatio))
                tiles.addWidget(lab)
            tiles.addStretch(1)
            grid.addLayout(tiles)
            fams = QGridLayout()
            for k, (fam, on, refused) in enumerate(row["families"]):
                c = QCheckBox(fam)
                c.setChecked(on)
                c.setEnabled(not refused)
                c.setToolTip("never on a built part" if refused else
                             "%s may wear %s" % (row["cls"].replace("_", " "), fam))
                c.toggled.connect(lambda _on, cls=row["cls"]: self.changed(cls))
                fams.addWidget(c, k // 4, k % 4)
                self.boxes.setdefault(row["cls"], []).append((fam, c))
            grid.addLayout(fams)
        grid.addStretch(1)
        self.scroll.setWidget(body)
    def changed(self, cls):
        fams = [f for f, c in self.boxes.get(cls, []) if c.isChecked()]
        kept, notes = artmodels.set_board(self.theme.currentText(), cls, fams)
        self.ed.hint("%s in %s: %s%s" % (cls.replace("_", " "), self.theme.currentText(),
                                          ", ".join(kept) or "nothing",
                                          ("  (" + "; ".join(notes) + ")") if notes else ""))
class StampGrid(QWidget):
    CELL = 26
    def __init__(self, panel):
        super().__init__()
        self.panel = panel
        n = artmodels.GRID
        self.setFixedSize(n * self.CELL + 1, n * self.CELL + 1)
        self.setToolTip("Left click: a layer up; right click: a layer down")
    def paintEvent(self, _ev):
        p = QPainter(self)
        s = self.panel.stamp()
        n = artmodels.GRID
        for i in range(n):
            for j in range(n):
                v = (s or {"cells": {}})["cells"].get((i, j), 0)
                g = 40 + min(215, v * 26)
                p.fillRect(i * self.CELL, j * self.CELL, self.CELL - 1, self.CELL - 1,
                           QColor(g // 2, g, g // 3))
                if v:
                    p.setPen(QColor(255, 255, 255))
                    p.drawText(i * self.CELL + 8, j * self.CELL + 17, str(v))
        p.end()
    def mousePressEvent(self, ev):
        s = self.panel.stamp()
        if s is None:
            return
        pos = ev.position()
        cell = (int(pos.x() // self.CELL), int(pos.y() // self.CELL))
        artmodels.stamp_click(s, cell, "left" if ev.button() == Qt.LeftButton else "right")
        self.panel.save()
        self.update()
class StampsPanel(QWidget):
    def __init__(self, art):
        super().__init__()
        from mapgen import stamps
        self.art = art
        self.ed = art.ed
        self.store = stamps.Store.load()
        lay = QVBoxLayout(self)
        lay.addWidget(_caption("Paint a piece of land (a cell is 400 across, a layer 200 up) "
                               "or capture it from the selection. Worlds generated from now lay "
                               "each stamp in use once - turned, mirrored, a layer higher or "
                               "lower, its rim worn."))
        self.list = QListWidget()
        self.list.currentRowChanged.connect(lambda _i: self.show())
        lay.addWidget(self.list)
        row = QHBoxLayout()
        for text, tip, fn in (("New", "A new empty stamp", self.new),
                              ("Capture", "A stamp from the selection's land", self.capture),
                              ("Delete", "Delete the stamp", self.delete)):
            b = QPushButton(text)
            b.setToolTip(tip)
            b.clicked.connect(fn)
            row.addWidget(b)
        lay.addLayout(row)
        self.use = QCheckBox("Lay this stamp in generated worlds")
        self.use.setToolTip("Used stamps are laid once in every explore world")
        self.use.toggled.connect(self.toggle_use)
        lay.addWidget(self.use)
        self.grid = StampGrid(self)
        lay.addWidget(self.grid)
        lay.addStretch(1)
        self.refresh()
    def stamp(self):
        i = self.list.currentRow()
        return self.store.items[i] if 0 <= i < len(self.store.items) else None
    def refresh(self):
        i = self.list.currentRow()
        self.list.clear()
        for s in self.store.items:
            self.list.addItem("%s  (%d cells%s)" % (s["name"], len(s["cells"]),
                                                    "" if s.get("use", True) else ", unused"))
        if self.store.items:
            self.list.setCurrentRow(max(0, min(i, len(self.store.items) - 1)))
        self.show()
    def show(self):
        s = self.stamp()
        self.use.blockSignals(True)
        self.use.setChecked(bool(s and s.get("use", True)))
        self.use.setEnabled(s is not None)
        self.use.blockSignals(False)
        self.grid.update()
    def save(self):
        try:
            self.store.save()
        except OSError as why:
            self.ed.hint("not saved: %s" % why)
    def new(self):
        artmodels.stamp_new(self.store, None)
        self.save()
        self.refresh()
        self.list.setCurrentRow(len(self.store.items) - 1)
    def capture(self):
        s, why = artmodels.stamp_capture(self.store, self.ed.session.doc, self.ed.session.refs())
        if s is None:
            self.ed.hint(why)
            return
        self.save()
        self.refresh()
        self.list.setCurrentRow(len(self.store.items) - 1)
    def delete(self):
        i = self.list.currentRow()
        if 0 <= i < len(self.store.items):
            del self.store.items[i]
            self.save()
            self.refresh()
    def toggle_use(self, on):
        s = self.stamp()
        if s is not None:
            s["use"] = bool(on)
            self.save()
            self.refresh()
class Art:
    def __init__(self, studio):
        self.studio = studio
        self.window = studio.window
        self.ed = studio.editor
        docks = studio.docks
        self.verbs = VerbsPanel(self)
        self.patterns = PatternsPanel(self)
        self.gallery = GalleryPanel(self)
        self.contract = ContractPanel(self)
        self.stamps = StampsPanel(self)
        docks.add("right", "verbs", "Verbs", self.verbs)
        docks.add("right", "patterns", "Never / Like", self.patterns)
        docks.add("bottom", "gallery", "Gallery", self.gallery)
        docks.add("left", "contract", "Contract", self.contract)
        docks.add("left", "stamps", "Stamps", self.stamps)
        studio.ctx.selectionChanged.connect(lambda *_: self.verbs.schedule())
        self.ed.changed.connect(self.verbs.schedule)
def install(studio):
    studio.art = Art(studio)
    return studio.art
