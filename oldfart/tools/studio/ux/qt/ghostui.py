from PySide6.QtCore import QObject, QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QPen
from studio.core import theme
from studio.editor import geometry as geo
from studio.ux import ghost, plane
class GhostUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ctx = ux.ctx
        self.scene = ux.ctx.scene
        self.verdict = None
        self.override = None
        self.cache = ghost.BoxCache()
        self.scene.ghost_tint = None
        self.scene.listen(self._scene_event)
        self.ctx.painters.append(self._paint)
        ed = ux.ed
        self._place = ed.place_armed
        ed.place_armed = self.place_armed
        self._drop = ed.drop
        ed.drop = self.drop
        tools = ux.tools
        if tools is not None:
            self._tools_pick = tools._pick
            tools._pick = self.tools_pick
            if self.ctx.pick_handler == self._tools_pick:
                self.ctx.pick_handler = self.tools_pick
    def judge(self, items):
        doc = self.ux.ed.session.doc
        items = [i for i in items if isinstance(i, dict)]
        if not items:
            return None
        reach = None
        pieces = [i for i in items if not geo.is_point(i)]
        if pieces:
            try:
                from studio.toolbox import build
                reach = build.ghost_reach(doc, pieces)
            except Exception:
                reach = None
        return ghost.verdict(doc, items, reach, self.cache)
    def _scene_event(self, event, _payload):
        if event != "ghosts":
            return
        ghosts = self.scene.ghosts
        judge = self.override or self.judge
        self.verdict = judge(ghosts) if ghosts else None
        if self.verdict is None:
            self.scene.ghost_tint = None
        else:
            mode = self.ctx.settings["ui.colour_vision"]
            self.scene.ghost_tint = theme.rgbf(theme.semantic(mode)[self.verdict.meaning])
    def refuse(self, v):
        self.ux.sound("bonk")
        self.ux.hint("Not placed: " + v.reason)
        view = self.ux.view()
        if view is not None:
            view.show_toast(v.reason, bad=True, seconds=2.5)
            self.shake = 3
        return None
    def items_at_cursor(self, entry_id=None):
        ed = self.ux.ed
        try:
            e, items = ed.armed_items(entry_id)
        except Exception:
            return None, []
        if e.section == "textures":
            return e, []
        got = geo.placed_at([i for _, i in items], ed.session.cursor, ed.session.snap_on,
                            anchor=e.data.get("anchor"))
        return e, got
    def place_armed(self, cursor=None):
        ed = self.ux.ed
        if cursor is not None:
            was = ed.session.cursor
            ed.session.cursor = tuple(cursor)
            _, items = self.items_at_cursor()
            ed.session.cursor = was
        else:
            _, items = self.items_at_cursor()
        v = self.judge(items) if items else None
        if v is not None and v.level == "bad":
            return self.refuse(v)
        msg = self._place(cursor)
        if msg:
            self.ux.pop(ed.session.refs())
        return msg
    def drop(self, entry_id):
        _, items = self.items_at_cursor(entry_id)
        v = self.judge(items) if items else None
        if v is not None and v.level == "bad":
            return self.refuse(v)
        out = self._drop(entry_id)
        self.ux.sound("place", y=(items[0].get("y", 0) if items else 0))
        self.ux.pop(self.ux.ed.session.refs())
        return out
    def tools_pick(self, hit, mods, view):
        st = self.ux.tools.state
        if st.mode == "paste" and self.verdict is not None and self.verdict.level == "bad":
            self.refuse(self.verdict)
            return True
        return self._tools_pick(hit, mods, view)
    shake = 0
    def _paint(self, view, p, w, h):
        v = self.verdict
        ghosts = self.scene.ghosts
        if not ghosts:
            return
        cam = view.camera
        mode = self.ctx.settings["ui.colour_vision"]
        col = QColor(theme.semantic(mode)[v.meaning if v is not None else "good"])
        line = plane.drop_line(ghosts, self.ux.ed.session.doc)
        if line is not None:
            a, b = cam.to_pixel(line[0], w, h), cam.to_pixel(line[1], w, h)
            if a is not None and b is not None:
                pen = QPen(col, 2.0, Qt.DashLine)
                p.setPen(pen)
                p.drawLine(QPointF(a[0], a[1]), QPointF(b[0], b[1]))
                p.setBrush(col)
                p.drawEllipse(QPointF(b[0], b[1]), 4, 4)
                drop = line[0][1] - line[1][1]
                view._text(p, b[0] + 8, b[1] - 4, "%.1f m up" % plane.metres(drop), col)
        if v is None or v.level == "ok" or getattr(view, "_mouse", None) is None:
            return
        if v.level == "bad":
            box = geo.union(geo.aabb(g) for g in ghosts if not geo.is_point(g))
            if box is not None:
                corners = [cam.to_pixel((x, y, z), w, h) for x in box[:2] for y in box[2:4]
                           for z in box[4:]]
                corners = [c for c in corners if c is not None]
                if corners:
                    r = QRectF(min(c[0] for c in corners), min(c[1] for c in corners), 0, 0)
                    r.setRight(max(c[0] for c in corners))
                    r.setBottom(max(c[1] for c in corners))
                    p.save()
                    p.setClipRect(r)
                    hatch = QColor(col)
                    hatch.setAlpha(150)
                    p.setPen(QPen(hatch, 2.0))
                    step = 9
                    x = r.left() - r.height()
                    while x < r.right():
                        p.drawLine(QPointF(x, r.bottom()), QPointF(x + r.height(), r.top()))
                        x += step
                    p.restore()
        text = "%s  %s" % (theme.GLYPH[v.meaning], v.reason)
        fm = p.fontMetrics()
        bw = min(w - 12, fm.horizontalAdvance(text) + 20)
        jiggle = (3 if self.shake % 2 else -3) if self.shake else 0
        if self.shake:
            self.shake -= 1
        x = min(view._mouse.x() + 18 + jiggle, w - bw - 6)
        y = min(view._mouse.y() - 34, h - 30)
        y = max(4, y)
        bg = QColor(self.ctx.tokens["raised"])
        bg.setAlpha(240)
        p.setPen(QPen(col, 2.0))
        p.setBrush(bg)
        p.drawRoundedRect(QRectF(x, y, bw, 26), 7, 7)
        p.setPen(QColor(self.ctx.tokens["text"]))
        p.drawText(QRectF(x + 10, y, bw - 14, 26), Qt.AlignVCenter | Qt.AlignLeft,
                   fm.elidedText(text, Qt.ElideRight, int(bw - 16)))
def install(ux):
    return GhostUI(ux)
