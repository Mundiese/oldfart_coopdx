from PySide6.QtCore import Qt
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtWidgets import (QDialog, QHBoxLayout, QLabel, QMessageBox, QPushButton,
                               QVBoxLayout)
from .. import tastepair
from . import common
PIC = 360
class TasteWindow(QDialog):
    def __init__(self, lib):
        super().__init__(lib.window)
        from studio.editor import engine
        self.lib = lib
        self.ed = lib.ed
        self.session = tastepair.Session(engine.taste_store())
        self.thumbs = common.Thumbnailer(lib.studio, size=PIC)
        self.setWindowTitle("A or B? - teach the generator your taste")
        self.resize(2 * PIC + 80, PIC + 260)
        lay = QVBoxLayout(self)
        intro = QLabel("<b>%s</b>  <a href='how'>How it works</a>" % tastepair.LINE)
        intro.setWordWrap(True)
        intro.setToolTip(tastepair.HELP)
        intro.linkActivated.connect(lambda *_: QMessageBox.information(
            self, "How it works", tastepair.HELP))
        lay.addWidget(intro)
        row = QHBoxLayout()
        self.pics = {}
        from PySide6.QtWidgets import QFrame
        for side in ("a", "b"):
            frame = QFrame()
            frame.setObjectName("card")
            col = QVBoxLayout(frame)
            title = QLabel("<b>%s</b>" % side.upper())
            title.setAlignment(Qt.AlignCenter)
            pic = QLabel("Building\u2026")
            pic.setObjectName("caption")
            pic.setMinimumSize(PIC, PIC)
            pic.setAlignment(Qt.AlignCenter)
            col.addWidget(title)
            col.addWidget(pic, 1)
            row.addWidget(frame)
            self.pics[side] = pic
        lay.addLayout(row, 1)
        self.quality = QLabel()
        self.quality.setObjectName("caption")
        lay.addWidget(self.quality)
        buttons = QHBoxLayout()
        self.buttons = {}
        for pick in ("a", "skip", "both_bad", "b"):
            b = QPushButton("%s (%s)" % (tastepair.LABELS[pick],
                                         " / ".join(tastepair.KEYS[pick])))
            b.clicked.connect(lambda _=False, p=pick: self.choose(p))
            buttons.addWidget(b)
            self.buttons[pick] = b
            for key in tastepair.KEYS[pick]:
                QShortcut(QKeySequence(key), self, activated=lambda p=pick: self.choose(p))
        lay.addLayout(buttons)
        self.status = QLabel()
        self.status.setWordWrap(True)
        lay.addWidget(self.status)
        row = QHBoxLayout()
        self.next = QPushButton("Next pair")
        self.next.setObjectName("primary")
        self.next.setToolTip("Build two candidates of the wish panel's wish (the next seed)")
        self.next.clicked.connect(self.next_pair)
        self.reset = QPushButton("Forget my choices for this kind\u2026")
        self.reset.setObjectName("quiet")
        self.reset.setAutoDefault(False)
        self.reset.setToolTip("Forget the choices you made for this kind of map (asks first)")
        self.reset.clicked.connect(self.reset_family)
        row.addWidget(self.reset)
        row.addStretch(1)
        row.addWidget(self.next)
        lay.addLayout(row)
        self._enable(False)
        self.refresh()
        from PySide6.QtCore import QTimer
        QTimer.singleShot(0, self, lambda: self.next_pair() if self.session.pair is None
                          and self.isVisible() else None)
    def _enable(self, on):
        for b in self.buttons.values():
            b.setEnabled(on)
    def next_pair(self):
        from studio.editor import engine
        if self.ed.jobs.busy():
            self.ed.hint("The engine is still working - wait, or Cancel")
            return
        raw, _ = self.ed.wish_panel.brief()
        seed = self.session.next_seed(int(raw.get("seed") or 1))
        def job(progress, cancelled):
            return engine.taste_pair(raw, seed=seed, progress=progress, cancel=cancelled)
        self.next.setEnabled(False)
        self.status.setText("Building two maps of the wish (seed %d)..." % seed)
        self.ed.jobs.run("A or B? - two maps", job, self.show_pair, self._failed)
    def _failed(self, why):
        self.next.setEnabled(True)
        self.status.setText("No pair: %s" % why)
    def show_pair(self, pair):
        self.next.setEnabled(True)
        self.session.show(pair)
        for side in ("a", "b"):
            pieces = (getattr(pair, side)["layout"] or {}).get("pieces", [])
            pm = self.thumbs.picture(("taste", side, pair.seed), pieces)
            self.pics[side].setPixmap(pm.scaled(PIC, PIC, Qt.KeepAspectRatio,
                                                Qt.SmoothTransformation))
        self.quality.setText(self.session.quality_line() + "  (hidden from the choice: judge "
                             "the maps, not the numbers)")
        self.quality.setVisible(False)
        self._enable(True)
        self.refresh()
    def choose(self, pick):
        if self.session.pair is None:
            return
        self.quality.setVisible(True)
        self.session.choose(pick)
        self._enable(False)
        self.refresh()
        self.ed.hint("Kept: %s. Next pair builds the next seed." % tastepair.LABELS[pick])
    def reset_family(self):
        fam = self.session.family()
        if fam is None:
            return
        if QMessageBox.question(self, "Reset", "Forget every choice you made for %s maps?"
                                % fam) != QMessageBox.Yes:
            return
        self.session.store.reset(fam)
        try:
            self.session.store.save()
        except OSError:
            pass
        self.refresh()
    def refresh(self):
        self.status.setText("\n".join(self.session.lines()))
