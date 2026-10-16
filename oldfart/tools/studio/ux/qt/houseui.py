from PySide6.QtCore import QEvent, QObject, Qt
from studio.editor import geometry as geo
from studio.editor.commands import Change
from studio.ux import ghost, house
from . import action
action("house.brush", ["B"], "House brush", "Build",
       "Click to add a house cell, on a top to build up, on a side to grow it; Shift+click "
       "takes one away, Alt+click takes a colour. Roofs, doors, windows and gardens come by "
       "themselves - Esc stops")
action("house.dress", [], "Dress this as houses", "Build",
       "The selected boxes become houses: roofs, doors, windows (the house brush's pass)")
class HouseUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.ctx = ux.ctx
        self.active = False
        self.target = None
        b = ux.menu("B&uild")
        self.action = ux.add_action("house.brush", self.toggle, menu=b)
        ux.add_action("house.dress", self.dress_selection, menu=b)
        self._pick = self.ctx.pick_handler
        self.ctx.pick_handler = self.pick
        self.ctx.cursorMoved.connect(self._cursor)
        for v in ux.studio.views.views():
            v.installEventFilter(self)
    def cells(self, doc=None):
        doc = doc or self.ed.session.doc
        out = {}
        for row in doc.meta.get("houses") or []:
            try:
                x, y, z, tex = row
                out[(int(x), int(y), int(z))] = str(tex)
            except (TypeError, ValueError):
                continue
        return out
    def theme(self):
        return self.ed.session.doc.brief.get("theme") or "castle"
    def change(self, cells, label, also=()):
        from studio.editor import ops
        doc = self.ed.session.doc
        old = [r for r in doc.refs("piece") if house.is_house(doc.get(r))] + list(also)
        new = house.build(cells, self.theme(), seed=len(cells))
        before = doc.meta.get("houses")
        after = [[x, y, z, t] for (x, y, z), t in sorted(cells.items())]
        steps = list(ops.delete(doc, old).steps) if old else []
        ins = ops.insert(doc, [("piece", p) for p in new], label, select=False)
        steps += ins.steps
        steps.append(("meta", "houses", before, after))
        return Change(label, steps, select=[]), new, old
    def judge(self, cells, cell=None):
        doc = self.ed.session.doc
        new = house.build(cells, self.theme(), seed=len(cells))
        old = [r for r in doc.refs("piece") if house.is_house(doc.get(r))]
        have = len(doc.refs("piece")) - len(old)
        budget = ghost.budget_of(doc)
        if have + len(new) > budget:
            return ghost.Verdict("bad", "Over the budget (%d + %d houses' pieces > %d)"
                                 % (have, len(new), budget))
        probe = [p for p in new if cell is None or self._in_cell(p, cell)] or new
        others = [r for r in doc.refs("piece") if not house.is_house(doc.get(r))]
        for p in probe:
            a = geo.aabb(p)
            for r in others:
                if geo.overlap_volume(a, geo.aabb(doc.get(r))) > 0:
                    return ghost.Verdict("bad", "That cell is inside something - click on its "
                                         "top or beside it", [r])
        if have + len(new) >= ghost.WARN_SHARE * budget:
            return ghost.Verdict("warn", "Houses use %d pieces of the budget" % len(new))
        return ghost.Verdict("ok", "")
    @staticmethod
    def _in_cell(p, cell):
        x, y, z = cell
        b = geo.aabb(p)
        return b[0] < x + house.CELL and b[1] > x and b[4] < z + house.CELL and b[5] > z and \
            b[2] < y + house.STOREY and b[3] > y
    def toggle(self, on=None):
        self.active = (not self.active) if on is None else bool(on)
        if self.active:
            self.ed.disarm(quiet=True)
            self.ux.hint("House brush: click to add a house cell, on a top to build up, Shift+"
                         "click takes one away, Alt+click a colour - Esc stops")
        else:
            self.target = None
            self.ed.sync.clear_ghost()
            g = self.ux.parts.get("ghostui")
            if g is not None:
                g.override = None
            self.ux.hint("House brush off")
        self.ctx.redraw()
        return self.active
    def aim(self, hit):
        cells = self.cells()
        if hit is None or hit.point is None:
            return None
        x, y, z = hit.point
        n = hit.normal or (0.0, 1.0, 0.0)
        inside = (x - n[0] * 2, y - n[1] * 2, z - n[2] * 2)
        under = house.cell_under(inside, cells)
        from PySide6.QtWidgets import QApplication
        mods = QApplication.keyboardModifiers()
        if mods & Qt.ShiftModifier:
            return ("remove", under) if under else None
        base = under[1] if under else None
        return "add", house.cell_at(hit.point, n, base_y=base)
    def add(self, cell, tex=None):
        cells = self.cells()
        if cell in cells:
            return None
        cells[cell] = tex or self.ed.session.texture
        v = self.judge(cells, cell)
        if v.level == "bad":
            g = self.ux.parts.get("ghostui")
            if g is not None:
                return g.refuse(v)
            return None
        ch, new, _ = self.change(cells, "House brush: a cell (%d)" % len(cells))
        self.ed.push(ch)
        self.ux.sound("place", y=cell[1], what="prefabs")
        doc = self.ed.session.doc
        fresh = [r for r in doc.refs("piece") if house.is_house(doc.get(r))
                 and self._in_cell(doc.get(r), cell)]
        self.ux.pop(fresh)
        return ch
    def remove(self, cell):
        cells = self.cells()
        if cell not in cells:
            return None
        del cells[cell]
        ch, _, _ = self.change(cells, "House brush: one cell away (%d)" % len(cells))
        self.ed.push(ch)
        self.ux.sound("delete")
        return ch
    def pick(self, hit, mods, view):
        if not self.active:
            return self._pick(hit, mods, view)
        if mods.get("alt") and hit and hit.kind == "piece":
            tex = self.ctx.scene.pieces[hit.index].get("tex")
            if tex:
                self.ed.set_texture(tex)
            return True
        got = self.aim(hit)
        if got is None:
            return True
        what, cell = got
        if what == "remove":
            self.remove(cell)
        else:
            self.add(cell)
        self._cursor({"point": hit.point})
        return True
    def _cursor(self, info):
        if not self.active:
            return
        view = info.get("view")
        hit = None
        if view is not None and getattr(view, "_mouse", None) is not None:
            hit = view.pick_at(view._mouse)
        got = self.aim(hit) if hit is not None else None
        self.target = got
        g = self.ux.parts.get("ghostui")
        if not got or got[0] != "add":
            self.ed.sync.clear_ghost()
            return
        cell = got[1]
        x, y, z = cell
        box = {"kind": "box", "tex": self.ed.session.texture, "x": x + house.CELL / 2.0,
               "y": y, "z": z + house.CELL / 2.0, "w": house.CELL, "h": house.STOREY,
               "d": house.CELL, "yaw": 0}
        cells = dict(self.cells())
        cells[cell] = self.ed.session.texture
        if g is not None:
            g.override = lambda _items, cells=cells, cell=cell: self.judge(cells, cell)
        self.ed.sync.show_ghost([box])
    def dress_selection(self):
        doc = self.ed.session.doc
        refs = [r for r in self.ed.session.refs() if r[0] == "piece"]
        boxes = [doc.get(r) for r in refs if doc.get(r).get("kind") == "box"
                 and not house.is_house(doc.get(r))]
        if not boxes:
            self.ux.hint("Select boxes first: they become houses")
            return None
        cells = self.cells()
        cells.update(house.cells_of_boxes(boxes))
        ch, new, old = self.change(cells, "Dress as houses",
                                   also=[r for r in refs if doc.get(r) in boxes])
        self.ed.push(ch)
        return ch
    def eventFilter(self, obj, ev):
        if self.active and ev.type() in (QEvent.ShortcutOverride, QEvent.KeyPress) and \
                ev.key() == Qt.Key_Escape:
            ev.accept()
            if ev.type() == QEvent.KeyPress:
                self.toggle(False)
            return True
        return False
def install(ux):
    return HouseUI(ux)
