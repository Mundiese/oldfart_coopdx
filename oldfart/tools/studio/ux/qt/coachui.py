import math
import time
from PySide6.QtCore import QEvent, QObject, QPoint, QRect, QRectF, Qt, QTimer
from PySide6.QtGui import QColor, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget
from studio.ux import tour as T
STATE_KEY = "coach"
SEEN = "tour_seen"
PULSE_MS = 40
RING_PAD = 6
BUBBLE_W = 360
ACTION_EVENTS = {"tools.variant_next": "variant", "tools.variant_prev": "variant",
                 "edit.paint": "paint", "tools.brush_paint": "paint", "lib.commands": "find", "critic.face": "grade",
                 "map.play": "play"}
class Spotlight(QWidget):
    def __init__(self, coach, parent):
        super().__init__(parent)
        self.coach = coach
        self.setAttribute(Qt.WA_TransparentForMouseEvents)
        self.setAttribute(Qt.WA_NoSystemBackground)
        self.rect_ = None
        self.started = time.time()
    def paintEvent(self, _ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        t = self.coach.ux.ctx.tokens or {}
        whole = QPainterPath()
        whole.addRect(QRectF(self.rect()))
        r = self.rect_
        if r is not None:
            hole = QPainterPath()
            hole.addRoundedRect(QRectF(r.adjusted(-RING_PAD, -RING_PAD, RING_PAD, RING_PAD)),
                                10, 10)
            whole = whole.subtracted(hole)
        p.fillPath(whole, QColor(8, 10, 14, 70))
        if r is not None:
            accent = QColor(t.get("accent", "#5b8cff"))
            calm = self.coach.ux.settings["ui.reduce_motion"]
            phase = 0.0 if calm else (math.sin((time.time() - self.started) * 4.0) + 1) / 2.0
            grow = 0 if calm else int(round(phase * 5))
            glow = QColor(accent)
            glow.setAlpha(int(70 + 80 * (1 - phase)))
            p.setPen(QPen(glow, 8))
            p.setBrush(Qt.NoBrush)
            pad = RING_PAD + grow
            p.drawRoundedRect(QRectF(r.adjusted(-pad, -pad, pad, pad)), 12, 12)
            p.setPen(QPen(accent, 3))
            p.drawRoundedRect(QRectF(r.adjusted(-RING_PAD, -RING_PAD, RING_PAD, RING_PAD)),
                              10, 10)
        p.end()
class Bubble(QFrame):
    def __init__(self, coach, parent):
        super().__init__(parent)
        self.coach = coach
        self.setObjectName("coachBubble")
        self.setFixedWidth(BUBBLE_W)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 12, 16, 12)
        lay.setSpacing(6)
        top = QHBoxLayout()
        self.count = QLabel("")
        self.count.setObjectName("coachCount")
        top.addWidget(self.count)
        top.addStretch(1)
        self.dots = QLabel("")
        self.dots.setObjectName("coachDots")
        top.addWidget(self.dots)
        lay.addLayout(top)
        self.title = QLabel("")
        self.title.setObjectName("coachTitle")
        self.title.setWordWrap(True)
        lay.addWidget(self.title)
        self.body = QLabel("")
        self.body.setObjectName("coachBody")
        self.body.setWordWrap(True)
        lay.addWidget(self.body)
        self.did = QLabel("")
        self.did.setObjectName("coachDid")
        self.did.hide()
        lay.addWidget(self.did)
        row = QHBoxLayout()
        row.setSpacing(6)
        self.back_btn = QPushButton("‹ Back")
        self.back_btn.setToolTip("The step before")
        self.back_btn.clicked.connect(coach.back)
        self.end_btn = QPushButton("End tour")
        self.end_btn.setObjectName("coachLink")
        self.end_btn.setToolTip("Stop here - Help > Tour (Shift+F1) picks it up again")
        self.end_btn.clicked.connect(lambda: coach.end())
        self.next_btn = QPushButton("Next ›")
        self.next_btn.setObjectName("primary")
        self.next_btn.setToolTip("Skip this step (or just do it - the tour sees it)")
        self.next_btn.clicked.connect(coach.next)
        row.addWidget(self.end_btn)
        row.addStretch(1)
        row.addWidget(self.back_btn)
        row.addWidget(self.next_btn)
        lay.addLayout(row)
    def fill_step(self, state, step, simple):
        n, k = len(state.steps), state.at
        self.count.setText("Step %d of %d" % (k + 1, n))
        self.dots.setText("".join("●" if i <= k else "○" for i in range(n)))
        self.title.setText(step.heading(simple))
        self.body.setText(step.words(simple) or step.full)
        already = step.id in state.done
        self.did.setText("✓ You did that already - Next goes on")
        self.did.setVisible(already)
        self.back_btn.setVisible(k > 0)
        self.back_btn.setText("‹ Back")
        self.end_btn.setText("End tour")
        self.next_btn.setText("Finish ✓" if k == n - 1 else "Next ›")
        self.adjustSize()
    def fill_resume(self, state, simple):
        step = state.step()
        self.count.setText("The tour")
        self.dots.setText("")
        self.title.setText("Pick up the tour?")
        self.body.setText("You stopped at step %d of %d: %s." % (
            state.at + 1, len(state.steps), step.heading(simple) if step else ""))
        self.did.hide()
        self.back_btn.setVisible(True)
        self.back_btn.setText("From the start")
        self.end_btn.setText("Not now")
        self.next_btn.setText("Continue ›")
        self.adjustSize()
class CoachTour(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.window = ux.window
        self.state = T.State.load(self._store().get(STATE_KEY))
        self.active = False
        self.resuming = False
        self.spot = Spotlight(self, self.window)
        self.spot.hide()
        self.bubble = Bubble(self, self.window)
        self.bubble.hide()
        self.timer = QTimer(self)
        self.timer.setInterval(PULSE_MS)
        self.timer.timeout.connect(self._follow)
        self.window.installEventFilter(self)
        self._hooked = False
        self.paused = False
        self._modal_paused = False
        from PySide6.QtGui import QGuiApplication
        app = QGuiApplication.instance()
        if app is not None:
            app.focusWindowChanged.connect(self._focus_moved)
        for aid, what in ACTION_EVENTS.items():
            a = self.window.actions.get(aid)
            if a is not None:
                a.triggered.connect(lambda *_, w=what: self.done(w))
        face = ux.parts.get("faceui")
        if face is not None:
            real = face.open_card
            def opened():
                card = real()
                self.done("grade")
                return card
            face.open_card = opened
    def _store(self):
        st = self.ux.settings
        if not isinstance(st.state, dict):
            st.state = {}
        return st.state
    def _save(self):
        if self.state is not None:
            self._store()[STATE_KEY] = self.state.dump()
    def seen(self):
        return bool(self._store().get(SEEN))
    @property
    def step(self):
        return self.state.at if (self.active and self.state is not None) else None
    @step.setter
    def step(self, value):
        if value is None:
            self._hide()
    def running(self):
        return self.active
    def simple(self):
        lvl = self.ux.parts.get("levelui")
        return lvl is not None and lvl.simple()
    def who(self):
        lvl = self.ux.parts.get("levelui")
        said = getattr(lvl, "who", None)
        if said in T.WHO and (said == "pro") != self.simple():
            return said
        return "kid" if self.simple() else "pro"
    def start(self, force=False, who=None):
        if self.active and not force:
            return False
        if self.seen() and not force:
            return False
        if not force and self.guide_open():
            return False
        self._store()[SEEN] = True
        self.resuming = False
        has_map = bool(self.ed.session.doc.refs("piece"))
        self.state = T.start(who or self.who(), has_map)
        self._save()
        self._show()
        return True
    def begin(self, who):
        return self.start(force=True, who=who)
    def first_run(self):
        lvl = self.ux.parts.get("levelui")
        card = getattr(lvl, "card", None) if lvl is not None else None
        if (card is not None and card.isVisible()) or getattr(lvl, "first_pending", False):
            return False
        if self.state is not None and self.state.resumable() and not self.state.ended:
            return self.offer_resume()
        if self.seen():
            return False
        if not self.ed.session.doc.refs("piece"):
            return False
        return self.start()
    def resume(self):
        if self.state is None or not self.state.resumable():
            return self.start(force=True)
        self.state.ended = False
        self.resuming = False
        self._save()
        self._show()
        return True
    def offer_resume(self):
        if self.state is None or not self.state.resumable():
            return False
        self.resuming = True
        self.active = False
        self.spot.rect_ = None
        self.bubble.fill_resume(self.state, self.simple())
        self._place_bubble(None)
        self.spot.hide()
        self.bubble.show()
        self.bubble.raise_()
        return True
    def skip(self):
        return self.end()
    def pause(self):
        if not self.active:
            return False
        self.paused = True
        self._hide()
        return True
    def guide_open(self):
        from PySide6.QtWidgets import QApplication
        if QApplication.activeModalWidget() is not None:
            return True
        return any(w.isVisible() and type(w).__name__ == "FirstMap"
                   for w in QApplication.topLevelWidgets())
    def _focus_moved(self, *_):
        from PySide6.QtWidgets import QApplication
        try:
            modal = QApplication.activeModalWidget()
            if modal is not None and self.active:
                self._modal_paused = self.pause()
            elif modal is None and self._modal_paused:
                self._modal_paused = False
                self.unpause()
        except RuntimeError:
            pass
    def unpause(self):
        if not getattr(self, "paused", False):
            return False
        self.paused = False
        if self.state is not None and not self.state.ended:
            self._show()
            return True
        return False
    def end(self, quiet=False):
        if self.resuming:
            self.resuming = False
            self.bubble.hide()
            if self.state is not None:
                self.state.ended = True
                self._save()
            return True
        if not self.active:
            return False
        if self.state is not None:
            self.state.ended = True
            self._save()
        self._hide()
        if not quiet:
            self.ux.hint("Tour stopped - Help > Tour (Shift+F1) picks it up where you left it")
        return True
    def toggle(self):
        if self.active or self.resuming:
            if self.resuming:
                return self.resume()
            return self.end()
        if self.state is not None and self.state.resumable():
            return self.resume()
        return self.start(force=True)
    def text(self):
        st = self.state.step() if (self.active and self.state) else None
        if st is None:
            return ""
        return "%d/%d  %s - %s" % (self.state.at + 1, len(self.state.steps),
                                   st.heading(self.simple()), st.words(self.simple()))
    def done(self, what):
        if self.state is None or not self.active:
            if self.state is not None:
                self.state.event(what)
            return False
        st = self.state.event(what)
        if st is None:
            self._save()
            return False
        self.ux.sound("chime")
        self.next()
        return True
    def next(self):
        if self.resuming:
            return self.resume()
        if self.state is None:
            return None
        nxt = self.state.advance()
        self._save()
        if nxt is None:
            self._hide()
            self.ux.sound("fanfare")
            self.ux.hint("That is the tour - F3 finds any command, Help > Maker Lessons "
                         "has more to try")
            view = self.ux.view()
            if view is not None:
                view.show_toast("That is the tour! F3 finds any command - have fun", seconds=6)
            return None
        self._show()
        return nxt
    def back(self):
        if self.resuming:
            return self.start(force=True, who=self.state.who if self.state else None)
        if self.state is None:
            return None
        st = self.state.back()
        self._save()
        self._show()
        return st
    def _hook_views(self):
        if self._hooked:
            return
        for v in self.ux.studio.views.views():
            v.cameraChanged.connect(lambda *_: self.done("look"))
        self._hooked = True
    def _show(self):
        st = self.state.step() if self.state else None
        if st is None:
            self._hide()
            return
        self._hook_views()
        self.active = True
        self._raise_for(st)
        self.bubble.fill_step(self.state, st, self.simple())
        self.spot.setGeometry(self.window.rect())
        self.spot.started = time.time()
        self.spot.show()
        self.spot.raise_()
        self.bubble.show()
        self.bubble.raise_()
        self._follow()
        self.timer.start()
    def _hide(self):
        self.active = False
        self.timer.stop()
        self.spot.hide()
        self.bubble.hide()
    def _raise_for(self, st):
        docks = self.ux.studio.docks
        key = {"wish": "wish", "palette": "palette"}.get(st.target)
        if key and key in docks.keys():
            d = docks.get(key)
            d.show()
            d.raise_()
    def target_rect(self, target=None):
        st = self.state.step() if self.state else None
        target = target or (st.target if st else None)
        w = self._target_widget(target)
        if isinstance(w, QRect):
            return w
        if w is None or not w.isVisible():
            return None
        top = w.mapTo(self.window, QPoint(0, 0))
        return QRect(top, w.size())
    def _target_widget(self, target):
        ed = self.ed
        if target == "wish":
            return getattr(ed.wish_panel, "text", None)
        if target == "palette":
            return getattr(ed.palette_panel, "tabs", None)
        if target == "view":
            return self.ux.view()
        if target == "face":
            face = self.ux.parts.get("faceui")
            return face.widget if face is not None else None
        if target == "play":
            aid = "map.play"
            lvl = self.ux.parts.get("levelui")
            if lvl is not None and lvl.simple():
                for a, wa, b in lvl.simple_buttons:
                    if a == aid and b.isVisible():
                        return b
            if target == "play":
                return self._menu_rect("Map")
            return self.ux.view()
        return None
    def _menu_rect(self, title):
        mb = self.window.menuBar()
        for a in mb.actions():
            if a.text().replace("&", "") == title and a.isVisible():
                r = mb.actionGeometry(a)
                return QRect(mb.mapTo(self.window, r.topLeft()), r.size())
        lvl = self.ux.parts.get("levelui")
        more = getattr(lvl, "more", None)
        if more is not None and more.menuAction().isVisible():
            r = mb.actionGeometry(more.menuAction())
            return QRect(mb.mapTo(self.window, r.topLeft()), r.size())
        return None
    def _follow(self):
        if not self.active:
            return
        r = self.target_rect()
        self.spot.setGeometry(self.window.rect())
        self.spot.rect_ = r
        self.spot.update()
        self._place_bubble(r)
    def _place_bubble(self, r):
        b = self.bubble
        b.adjustSize()
        W, H = self.window.width(), self.window.height()
        bw, bh = b.width(), b.height()
        gap = 18
        if r is None:
            views = self.ux.studio.views
            c = views.mapTo(self.window, views.rect().center())
            x, y = c.x() - bw // 2, c.y() - bh // 2
        elif r.width() * r.height() > W * H * 0.18 and r.height() > H * 0.4:
            x, y = r.center().x() - bw // 2, r.top() + 24
        elif r.bottom() + gap + bh < H - 8:
            x, y = r.center().x() - bw // 2, r.bottom() + gap
        elif r.top() - gap - bh > 8:
            x, y = r.center().x() - bw // 2, r.top() - gap - bh
        elif r.right() + gap + bw < W - 8:
            x, y = r.right() + gap, r.center().y() - bh // 2
        else:
            x, y = r.left() - gap - bw, r.center().y() - bh // 2
        x = max(8, min(x, W - bw - 8))
        y = max(8, min(y, H - bh - 8))
        b.move(x, y)
    def eventFilter(self, obj, ev):
        try:
            if ev.type() == QEvent.Resize and obj is self.window and (self.active
                                                                      or self.resuming):
                QTimer.singleShot(0, self, self._follow if self.active else
                                  (lambda: self._place_bubble(None)))
        except RuntimeError:
            pass
        return False
def install(ux):
    coach = CoachTour(ux)
    ux.ed._tour = coach
    return coach
