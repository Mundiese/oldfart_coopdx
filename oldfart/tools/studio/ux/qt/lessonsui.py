import random
import time
from PySide6.QtCore import QObject, QPointF, QRectF, Qt, QTimer
from PySide6.QtGui import QColor, QFont, QPen
from PySide6.QtWidgets import (QDialog, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
                               QPushButton, QVBoxLayout)
from studio.ux import lessons as L
from . import action
action("help.lessons", ["Alt+F1"], "Maker Lessons", "Help",
       "Eight hands-on challenges, two minutes each, in small maps: move, put down blocks, "
       "copy, paint, fair bases, rooms, make it pretty, play it - ticked by the Studio itself")
action("help.lesson_next", [], "Next lesson", "Help", "The next Maker Lesson")
class LessonsDialog(QDialog):
    def __init__(self, part):
        super().__init__(part.ux.window)
        self.part = part
        self.setWindowTitle("Maker Lessons")
        self.resize(520, 460)
        lay = QVBoxLayout(self)
        t = QLabel("Learn to build - by doing it")
        t.setObjectName("title")
        lay.addWidget(t)
        lay.addWidget(QLabel("Each lesson opens a small map. Do what it says; the Studio "
                             "ticks it and you win a sticker."))
        self.list = QListWidget()
        self.list.itemDoubleClicked.connect(lambda *_: self.start())
        lay.addWidget(self.list, 1)
        row = QHBoxLayout()
        go = QPushButton("Start the lesson")
        go.setObjectName("primary")
        go.clicked.connect(self.start)
        close = QPushButton("Close")
        close.clicked.connect(self.close)
        row.addStretch(1)
        row.addWidget(close)
        row.addWidget(go)
        lay.addLayout(row)
        self.fill()
    def fill(self):
        self.list.clear()
        done = self.part.done()
        first_open = None
        for k, l in enumerate(L.LESSONS):
            ok = l["id"] in done
            text = "%s %d. %s - %s%s" % ("✓" if ok else "  ", k + 1, l["title"], l["goal"],
                                         "    (sticker: %s)" % l["sticker"] if ok else "")
            it = QListWidgetItem(text)
            it.setData(Qt.UserRole, l["id"])
            it.setToolTip(l["how"])
            self.list.addItem(it)
            if not ok and first_open is None:
                first_open = k
        self.list.setCurrentRow(first_open or 0)
    def start(self):
        it = self.list.currentItem()
        if it is not None:
            self.close()
            self.part.start(it.data(Qt.UserRole))
class LessonsUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.ctx = ux.ctx
        self.lesson = None
        self.ok = False
        self.line = ""
        self.used = set()
        self.confetti = None
        h = ux.menu("&Help")
        ux.add_action("help.lessons", self.open, menu=h)
        ux.add_action("help.lesson_next", self.next_lesson, menu=h)
        for aid, a in ux.window.actions.items():
            a.triggered.connect(lambda *_, aid=aid: self.used.add(aid))
        self.timer = QTimer(self)
        self.timer.setInterval(600)
        self.timer.timeout.connect(self.check)
        self.ctx.painters.append(self._paint)
        self._add_card()
    def _add_card(self):
        lib = getattr(self.ux.studio, "library", None)
        cards = getattr(lib, "cards", None)
        if cards is None or not hasattr(cards, "grid"):
            return
        try:
            from studio.library.qt.wizard import big_button
        except ImportError:
            return
        b = big_button("Learn to build", "eight hands-on lessons, two minutes each",
                       checkable=False)
        b.setToolTip("Maker Lessons (Alt+F1): move, put down blocks, copy, paint, rooms...")
        b.clicked.connect(self.open)
        cards.buttons.append(b)
        n = len(cards.buttons) - 1
        cards.grid.addWidget(b, n // 2, n % 2)
        self.card = b
    def done(self):
        return set(self.ed.settings_get("lessons_done") or [])
    def stickers(self):
        d = self.done()
        return [l["sticker"] for l in L.LESSONS if l["id"] in d]
    def open(self):
        dlg = LessonsDialog(self)
        self.dialog = dlg
        dlg.show()
        return dlg
    def start(self, lesson_id):
        from studio.editor.document import Document
        lesson = L.get(lesson_id)
        if not self.ed._may_drop_edits():
            return None
        doc = Document({}, L.layout_of(lesson))
        doc.meta["notes"] = L.notes_of(lesson)
        self.ed.session._replace_doc(doc, origin="Lesson: %s" % lesson["title"])
        self.ed.after_change("Lesson: %s - %s" % (lesson["title"], lesson["goal"]))
        tools = self.ux.tools
        if tools is not None and not tools.state.notes_shown:
            tools.run("tools.notes_show")
        self.lesson = lesson
        self.ok = False
        self.used = set()
        self.line = ""
        self.timer.start()
        self.ux.sound("open")
        self.ctx.redraw()
        return lesson
    def next_lesson(self):
        ids = [l["id"] for l in L.LESSONS]
        if self.lesson is None:
            return self.start(ids[0])
        k = ids.index(self.lesson["id"])
        return self.start(ids[(k + 1) % len(ids)])
    def state(self):
        view = self.ux.view()
        return {"doc": self.ed.session.doc,
                "eye": tuple(view.camera.eye()) if view is not None else None,
                "used": set(self.used), "walked": 0.0}
    def check(self):
        if self.lesson is None or self.ok:
            return self.ok
        ok, line = L.check(self.lesson, self.state())
        self.line = line
        if ok:
            self.finish()
        self.ctx.redraw()
        return ok
    def finish(self):
        self.ok = True
        done = self.done() | {self.lesson["id"]}
        self.ed.settings_set("lessons_done", sorted(done))
        self.ux.sound("chime")
        self.ux.hint("Lesson done! Sticker: %s - Help > Next lesson (or Alt+F1) for the next one"
                     % self.lesson["sticker"])
        if not self.ux.settings["ui.reduce_motion"]:
            rng = random.Random(len(done))
            self.confetti = (time.monotonic(), [(rng.random(), rng.random() * 0.3,
                                                 rng.choice(("#0072B2", "#E69F00", "#D55E00",
                                                             "#56B4E9", "#009E73", "#F0E442")))
                                                for _ in range(60)])
            for k in range(1, 30):
                QTimer.singleShot(k * 35, self.ctx.redraw)
        self.timer.stop()
    def stop(self):
        self.lesson = None
        self.timer.stop()
        self.ctx.redraw()
    def _paint(self, view, p, w, h):
        if self.lesson is not None:
            tok = self.ctx.tokens
            k = [l["id"] for l in L.LESSONS].index(self.lesson["id"]) + 1
            head = "Lesson %d of %d: %s" % (k, len(L.LESSONS), self.lesson["goal"])
            if self.ok:
                head = "✓ Done! Sticker: %s" % self.lesson["sticker"]
            sub = self.lesson["how"] if not self.ok else "Help > Next lesson goes on"
            f = QFont(p.font())
            f.setPixelSize(16)
            f.setBold(True)
            p.setFont(f)
            fm = p.fontMetrics()
            small = QFont(f)
            small.setPixelSize(12)
            small.setBold(False)
            from PySide6.QtGui import QFontMetrics
            sw = QFontMetrics(small).horizontalAdvance(sub)
            bw = min(w - 24, max(fm.horizontalAdvance(head) + 40, sw + 40, 380))
            r = QRectF((w - bw) / 2.0, 8, bw, 62)
            bg = QColor(tok["raised"])
            bg.setAlpha(238)
            p.setPen(QPen(QColor(tok["ok"] if self.ok else tok["accent"]), 2))
            p.setBrush(bg)
            p.drawRoundedRect(r, 10, 10)
            p.setPen(QColor(tok["text"]))
            p.drawText(r.adjusted(14, 6, -14, -30), Qt.AlignLeft | Qt.AlignVCenter, head)
            f.setPixelSize(12)
            f.setBold(False)
            p.setFont(f)
            p.setPen(QColor(tok["text_dim"]))
            line = sub + (("  - " + self.line) if self.line and not self.ok else "")
            p.drawText(r.adjusted(14, 32, -14, -6), Qt.AlignLeft | Qt.AlignVCenter,
                       p.fontMetrics().elidedText(line, Qt.ElideRight, int(bw - 28)))
        if self.confetti is not None:
            t0, bits = self.confetti
            t = time.monotonic() - t0
            if t > 1.0:
                self.confetti = None
                return
            p.setPen(Qt.NoPen)
            for x, y0, col in bits:
                p.setBrush(QColor(col))
                yy = (y0 + t * 1.1) * h
                p.drawRect(QRectF(x * w, yy, 6, 9))
def install(ux):
    return LessonsUI(ux)
__all__ = ["LessonsUI", "install", "QPointF"]
