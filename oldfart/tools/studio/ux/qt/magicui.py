import math
import time
from PySide6.QtCore import QObject, QPointF, QRectF, Qt, QTimer
from PySide6.QtGui import QColor, QPen
from PySide6.QtWidgets import (QApplication, QHBoxLayout, QLabel, QPushButton, QSlider,
                               QVBoxLayout, QWidget)
from studio.core.gizmo import Delta
from studio.editor import geometry as geo, ops
from studio.editor.commands import Change
from studio.ux import magic
from . import action
action("edit.drop", ["End"], "Drop to the ground", "Edit",
       "Each selected thing goes down until it rests on what is below it (or the floor)")
action("edit.drop_group", ["Shift+End"], "Drop to the ground as one", "Edit",
       "The selection goes down as one block until its lowest part rests on something")
action("edit.scrub", ["Ctrl+Alt+Z"], "Scrub the history", "Edit",
       "The History's slider: drag back through every change and forward again, live; "
       "letting go keeps that version as one undo step (Undodog)")
action("file.start_over", [], "Start over", "File",
       "Clear the map - with an Undo that button right there, never a question")
FLOORISH = ("floor", "slab", "ice", "lava", "water")
GUIDE_PX = 6
class Scrubber(QWidget):
    def __init__(self, part):
        super().__init__()
        self.part = part
        lay = QHBoxLayout(self)
        lay.setContentsMargins(6, 4, 6, 2)
        self.label = QLabel("Time travel")
        self.label.setObjectName("dim")
        self.label.setToolTip("Drag the slider back through every change, and forward again")
        self.slider = QSlider(Qt.Horizontal)
        self.slider.setToolTip("Drag back through every change, and forward again - letting "
                               "go keeps that version (one undo step). Ctrl+Alt+Z")
        self.slider.sliderPressed.connect(part.scrub_begin)
        self.slider.valueChanged.connect(part.scrub_to)
        self.slider.sliderReleased.connect(part.scrub_end)
        lay.addWidget(self.label)
        lay.addWidget(self.slider, 1)
class MagicUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.ctx = ux.ctx
        self.stamps = 0
        self.guide_lines = []
        self.guide_label = None
        self.snap_adj = (0.0, 0.0, 0.0)
        self.rocket = None
        e = ux.menu("E&dit")
        ux.add_action("edit.drop", lambda: self.drop(False), menu=e)
        ux.add_action("edit.drop_group", lambda: self.drop(True), menu=e)
        ux.add_action("edit.scrub", self.focus_scrubber, menu=e)
        ux.add_action("file.start_over", self.start_over, menu=ux.menu("&File"))
        ed = self.ed
        self._armed_pick = ed._armed_pick
        ed._armed_pick = self.armed_pick
        run = ed.run_action
        def run_action(aid):
            if aid == "edit.paint" and not ed.session.refs() and not ed.armed:
                return ed.arm("textures:" + ed.session.texture)
            return run(aid)
        ed.run_action = run_action
        self._lay_row = ed.lay_row
        self._box_drag = ed._box_drag
        ed._box_drag = self.box_drag
        tools = ux.tools
        if tools is not None:
            self._click = tools.state.click
            tools.state.click = self.tool_click
        self.ctx.gizmoDragged.connect(self._gizmo_dragged)
        self._gizmo_handler = self.ctx.gizmo_handler
        self.ctx.gizmo_handler = self.gizmo_handler
        self.ctx.painters.append(self._paint)
        self._build_scrubber()
        self.chip = None
    def drop(self, as_group):
        s = self.ed.session
        if not s.refs():
            self.ux.hint("Select what to drop first")
            return None
        ch = magic.drop_to_ground(s.doc, s.refs(), as_group)
        if not ch:
            self.ux.hint("Already on the ground")
            return None
        self.ed.push(ch)
        self.ux.sound("place", y=0)
        return ch
    def armed_pick(self, hit, mods):
        ed = self.ed
        armed = ed.armed or ""
        if armed.startswith("textures:") and hit and hit.kind == "piece" and \
                (mods.get("shift") or mods.get("alt")):
            ref = ed.sync.ref_of_piece(hit.index)
            refs = (magic.wall_run if mods.get("alt") else magic.surface)(ed.session.doc, ref)
            tex = armed.split(":", 1)[1]
            ed.set_texture(tex)
            ch = ops.retexture(ed.session.doc, refs, tex)
            ch.label = "Paint %s (%d pieces)" % ("the wall run" if mods.get("alt")
                                                 else "the surface", len(refs))
            ed.push(ch)
            return True
        return self._armed_pick(hit, mods)
    def floor_item(self):
        armed = self.ed.armed or ""
        if ":" not in armed or armed.startswith("textures:"):
            return None
        try:
            e = self.ed.palette.get(armed)
        except KeyError:
            return None
        if e.section != "shapes":
            return None
        _, items = self.ed.armed_items()
        pieces = [i for k, i in items if "w" in i]
        if len(pieces) != 1:
            return None
        p = pieces[0]
        if e.key in FLOORISH or (p.get("kind") == "box" and p.get("h", 999) <= 100):
            return p
        return None
    def box_drag(self, view, start, now, phase):
        item = self.floor_item()
        shift = bool(QApplication.keyboardModifiers() & Qt.ShiftModifier)
        if item is None or shift or self.ed.armed in (None,):
            return self._box_drag(view, start, now, phase)
        a, b = view.pick_at(start), view.pick_at(now)
        if a.point is None or b.point is None:
            return None
        pa = tuple(self.ctx.snap.point(a.point))
        pb = tuple(self.ctx.snap.point(b.point))
        pieces = magic.floor_rect(pa, (pb[0], pa[1], pb[2]), item)
        if phase in ("begin", "drag"):
            self.ed.sync.show_ghost(pieces)
            return pieces
        self.ed.sync.clear_ghost()
        return self.lay_floor(pieces)
    def lay_floor(self, pieces):
        g = self.ux.parts.get("ghostui")
        if g is not None:
            v = g.judge(pieces)
            if v is not None and v.level == "bad":
                return g.refuse(v)
        ch = ops.insert(self.ed.session.doc, [("piece", p) for p in pieces],
                        "Lay a floor (%d piece%s)" % (len(pieces), "" if len(pieces) == 1
                                                      else "s"))
        self.ed.push(ch)
        self.ux.sound("row")
        self.ux.pop(ch.select or [])
        return ch
    def tool_click(self, point, mods=None):
        st = self.ux.tools.state
        mods = mods or {}
        if st.mode == "paste" and mods.get("alt") and self.ed.session.clipboard and point:
            return self.stamp(point)
        return self._click(point, mods)
    def stamp(self, point):
        s = self.ed.session
        ch = s.clipboard.paste_at(s.doc, point, s.paste_turns, s.snap_on)
        self.stamps += 1
        seed = hash((round(point[0]), round(point[2]), self.stamps)) & 0xFFFF
        ins = [(i, st) for i, st in enumerate(ch.steps) if st[0] == "insert"]
        varied = magic.stamp_vary([(st[1][0], st[3]) for _, st in ins], seed,
                                  [s.texture, s.texture2])
        for (i, st), (_, item) in zip(ins, varied):
            ch.steps[i] = (st[0], st[1], st[2], geo.cleaned(item))
        ch.label = "Stamp (a little different)"
        return s.push(ch)
    def _gizmo_dragged(self, delta, phase):
        sc = self.ctx.scene
        if phase in ("end", "cancel") or not sc.selection:
            self.guide_lines, self.guide_label = [], None
            self.snap_adj = (0.0, 0.0, 0.0)
            return
        if delta.quarters:
            return
        idx = sorted(sc.selection)
        boxes = [geo.aabb(sc.pieces[i]) for i in idx if i < len(sc.pieces)]
        b = geo.union(boxes)
        if b is None:
            return
        ox, oy, oz = delta.offset
        moving = (b[0] + ox, b[1] + ox, b[2] + oy, b[3] + oy, b[4] + oz, b[5] + oz)
        near = []
        cx, cz = (moving[0] + moving[1]) / 2, (moving[4] + moving[5]) / 2
        for i, p in enumerate(sc.pieces):
            if i in sc.selection:
                continue
            pb = geo.aabb(p)
            if abs((pb[0] + pb[1]) / 2 - cx) < 3000 and abs((pb[4] + pb[5]) / 2 - cz) < 3000:
                near.append(pb)
        view = self.ux.view()
        upp = view.camera.units_per_pixel(view.camera.target, max(1, view.height())) \
            if view is not None else 10.0
        got = magic.guides(moving, near[:400], tol=GUIDE_PX * upp)
        adj = [0.0, 0.0, 0.0]
        lines = []
        for axis, value, d, other in got:
            k = "xyz".index(axis)
            if axis != "y":
                adj[k] = d
            lines.append((axis, value, moving, other))
        self.snap_adj = tuple(adj)
        self.guide_lines = lines
        total = (ox + adj[0], oy + adj[1], oz + adj[2])
        self.guide_label = magic.move_label(*total)
        piv = sc.selection_pivot()
        from studio.core.scene import Preview
        sc.set_preview(Preview(sc.selection, total, 0, (piv[0], piv[2]) if piv else (0.0, 0.0)))
    def gizmo_handler(self, delta, ids):
        adj = self.snap_adj
        if any(adj) and not delta.quarters:
            delta = Delta(tuple(a + b for a, b in zip(delta.offset, adj)), 0, delta.degrees,
                          delta.handle)
        self.snap_adj = (0.0, 0.0, 0.0)
        self.guide_lines, self.guide_label = [], None
        return self._gizmo_handler(delta, ids)
    def _build_scrubber(self):
        docks = self.ux.studio.docks
        if "history" not in docks.keys():
            self.scrubber = None
            return
        dock = docks.get("history")
        panel = self.ed.history
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        self.scrubber = Scrubber(self)
        lay.addWidget(self.scrubber)
        lay.addWidget(panel, 1)
        dock.set_panel(box)
        self._scrub_from = None
        self._refresh_history = panel.refresh
        def refresh():
            self._refresh_history()
            self.scrub_range()
        panel.refresh = refresh
        self.scrub_range()
    def scrub_range(self):
        if self.scrubber is None or self._scrub_from is not None:
            return
        st = self.ed.session.stack
        sl = self.scrubber.slider
        sl.blockSignals(True)
        sl.setRange(0, len(st.done) + len(st.undone))
        sl.setValue(len(st.done))
        sl.blockSignals(False)
    def focus_scrubber(self):
        d = self.ux.studio.docks.get("history")
        d.show()
        d.raise_()
        self.scrubber.slider.setFocus()
        self.ux.hint("Scrub the history: drag the slider (or the arrow keys), let go to keep")
    def scrub_begin(self):
        st = self.ed.session.stack
        self._scrub_from = len(st.done)
    def scrub_to(self, n):
        st = self.ed.session.stack
        if self._scrub_from is None:
            self.scrub_begin()
            QTimer.singleShot(400, self, self.scrub_end_if_idle)
        st.undo_to(n)
        self.ux.sound("undo" if n < len(st.done) + 1 else "redo")
        self.ctx.redraw()
        self._scrub_t = time.monotonic()
    def scrub_end_if_idle(self):
        if self.scrubber.slider.isSliderDown():
            return
        if time.monotonic() - getattr(self, "_scrub_t", 0) < 0.35:
            QTimer.singleShot(400, self, self.scrub_end_if_idle)
            return
        self.scrub_end()
    def scrub_end(self):
        st = self.ed.session.stack
        start, self._scrub_from = self._scrub_from, None
        if start is None:
            return None
        n = len(st.done)
        if n == start:
            self.scrub_range()
            return None
        label = st.done[n - 1].label if n else self.ed.session.origin
        doc = self.ed.session.doc
        target = doc.state()
        st.undo_to(start)
        ch = Change("Back to: %s" % label, [("state", doc.state(), target)], select=[])
        self.ed.push(ch)
        self.scrub_range()
        return ch
    def start_over(self):
        from studio.editor.document import empty_layout
        doc = self.ed.session.doc
        if not doc.refs("piece") and not doc.refs("spawn"):
            self.ux.hint("The map is empty already")
            return None
        layout = empty_layout()
        layout["name"] = doc.rest.get("name") or layout["name"]
        ch = ops.replace_map(doc, dict(doc.brief), layout, "Start over")
        ch.hand = True
        self.ed.push(ch)
        self.ux.sound("fanfare")
        if not self.ux.settings["ui.reduce_motion"]:
            self.rocket = time.monotonic()
            for k in range(1, 26):
                QTimer.singleShot(k * 40, self.ctx.redraw)
        self.show_chip()
        return ch
    def show_chip(self):
        views = self.ux.studio.views
        if self.chip is None:
            self.chip = QPushButton("↶  Undo that", views)
            self.chip.setObjectName("primary")
            self.chip.setToolTip("Bring the map back (Ctrl+Z does it too)")
            self.chip.clicked.connect(self._undo_chip)
            self._chip_timer = QTimer(self)
            self._chip_timer.setSingleShot(True)
            self._chip_timer.timeout.connect(self.chip.hide)
        self.chip.adjustSize()
        self.chip.move((views.width() - self.chip.width()) // 2, 40)
        self.chip.show()
        self.chip.raise_()
        self._chip_timer.start(9000)
        return self.chip
    def _undo_chip(self):
        self.chip.hide()
        self.ed.run_action("edit.undo")
    def _paint(self, view, p, w, h):
        cam = view.camera
        if self.guide_lines:
            pen = QPen(QColor("#ffcc33"), 1.5, Qt.DashLine)
            p.setPen(pen)
            for axis, value, a, b in self.guide_lines:
                lo = [min(a[0], b[0]), min(a[2], b[2]), min(a[4], b[4])]
                hi = [max(a[1], b[1]), max(a[3], b[3]), max(a[5], b[5])]
                y = a[2]
                if axis == "x":
                    p0, p1 = (value, y, lo[2] - 200), (value, y, hi[2] + 200)
                elif axis == "z":
                    p0, p1 = (lo[0] - 200, y, value), (hi[0] + 200, y, value)
                else:
                    p0, p1 = (lo[0] - 200, value, a[4]), (hi[0] + 200, value, a[4])
                q0, q1 = cam.to_pixel(p0, w, h), cam.to_pixel(p1, w, h)
                if q0 is not None and q1 is not None:
                    p.drawLine(QPointF(q0[0], q0[1]), QPointF(q1[0], q1[1]))
        if self.guide_label and getattr(view, "_mouse", None) is not None:
            m = view._mouse
            view._text(p, m.x() + 18, m.y() + 34, self.guide_label, QColor("#ffcc33"), bold=True)
        if self.rocket is not None:
            t = time.monotonic() - self.rocket
            if t > 1.0:
                self.rocket = None
                return
            x = w * (0.2 + 0.6 * t)
            y = h * (0.85 - 0.8 * t * t)
            p.setPen(Qt.NoPen)
            p.setBrush(QColor("#ff8a3d"))
            p.drawEllipse(QPointF(x - 8, y + 26), 7, 12)
            p.setBrush(QColor("#e8edf2"))
            p.drawRoundedRect(QRectF(x - 9, y - 18, 18, 40), 8, 8)
            p.setBrush(QColor("#e8473b"))
            p.drawEllipse(QPointF(x, y - 14), 6, 6)
            view._text(p, x + 16, y, "Whoosh!", QColor("#ffffff"), bold=True)
def install(ux):
    return MagicUI(ux)
__all__ = ["MagicUI", "install", "math"]
