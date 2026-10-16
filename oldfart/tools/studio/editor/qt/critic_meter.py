from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QMenu, QToolButton, QWidget
from .. import critic_live
from .worker import Jobs
PAUSE_MS = 900
BARS = ("emptiness", "mud", "overlaps", "floating", "monotony", "composition", "grounding",
        "liminal", "mode_fit")
COLOURS = {"ok": "#5cbe6e", "warn": "#e6aa3c", "bad": "#dc4646", "none": "#666a70"}
class CriticMeter(QWidget):
    judged = Signal(object)
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        self.result = None
        self.revision = None
        self.runs = 0
        self.jobs = Jobs(self)
        lay = QHBoxLayout(self)
        lay.setContentsMargins(4, 0, 4, 0)
        lay.setSpacing(3)
        self.button = QToolButton()
        self.button.setAutoRaise(True)
        self.button.setText("Critic -")
        self.button.setToolTip("The critic's score while you edit - click for its rows "
                               "(Alt+C: the weakest)")
        self.button.clicked.connect(self.open_menu)
        lay.addWidget(self.button)
        self.bars = {}
        for key in BARS:
            bar = QLabel()
            bar.setFixedSize(7, 12)
            bar.setStyleSheet("background: %s; border-radius: 2px;" % COLOURS["none"])
            lay.addWidget(bar)
            self.bars[key] = bar
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.setInterval(PAUSE_MS)
        self.timer.timeout.connect(self.measure)
        ed.changed.connect(self.schedule)
        self.schedule()
    def schedule(self):
        self.timer.start()
    def measure(self):
        doc = self.ed.session.doc
        if self.jobs.busy():
            self.timer.start()
            return False
        rev = (id(doc), doc.revision)
        if rev == self.revision:
            return False
        layout, brief = doc.to_layout(), dict(doc.brief)
        self.runs += 1
        def job(progress, cancelled):
            from .. import childcall
            return childcall.call("studio.editor.critic_live:judge", layout, brief)
        def done(res):
            now = self.ed.session.doc
            if (id(now), now.revision) != rev:
                self.timer.start()
                return
            self.show_result(res, rev)
        def failed(reason):
            self.button.setText("Critic ?")
            self.button.setToolTip("The critic could not read this map: %s" % (
                reason.splitlines()[0] if reason else "?"))
        self.jobs.run("Critic", job, done, failed)
        return True
    def show_result(self, res, rev=None):
        self.result = res
        self.revision = rev
        self.judged.emit(res)
        if res is None:
            self.button.setText("Critic -")
            for bar in self.bars.values():
                bar.setStyleSheet("background: %s; border-radius: 2px;" % COLOURS["none"])
                bar.setToolTip("Nothing to judge yet")
            return
        self.button.setText("Critic %.0f" % res["score"])
        colour = COLOURS["ok"] if res["pass"] else COLOURS["warn"]
        self.button.setStyleSheet("QToolButton { color: %s; font-weight: 600; }" % colour)
        self.button.setToolTip(critic_live.summary(res) + "\nClick for every row (Alt+C: the "
                                                          "weakest)")
        for key, bar in self.bars.items():
            r = critic_live.row(res, key)
            state = r.state if r else "none"
            bar.setStyleSheet("background: %s; border-radius: 2px;" % COLOURS[state])
            bar.setToolTip(r.text() if r else "")
    def rows(self):
        return list((self.result or {}).get("rows") or [])
    def open_menu(self):
        menu = QMenu(self)
        if not self.result:
            menu.addAction("Nothing to judge yet - place some pieces").setEnabled(False)
        for r in sorted(self.rows(), key=lambda r: r.score):
            a = menu.addAction("%s  %s" % ({"ok": "ok ", "warn": "!  ", "bad": "!! "}[r.state],
                                           r.text()[:90]))
            a.triggered.connect(lambda _=False, k=r.key: self.show_row(k))
        self._menu = menu
        menu.popup(self.mapToGlobal(self.rect().topLeft()))
        return menu
    def show_row(self, key):
        iss = critic_live.issue(self.result, key, self.ed.session.doc)
        if iss is None:
            return None
        tools = getattr(self.ed.studio, "tools", None)
        if tools is not None and iss.points:
            tools.show_issue(iss)
        else:
            self.ed.hint(iss.text)
        return iss
    def show_worst(self):
        if not self.result:
            self.ed.hint(critic_live.summary(None) if self.revision else
                         "The critic is still reading the map - a moment")
            self.measure()
            return None
        return self.show_row(self.result["worst"])
__all__ = ["CriticMeter", "Qt"]
