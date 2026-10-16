import os
import random
import time
from PySide6.QtCore import QObject, QRect, QSize, Qt, QTimer, Signal
from PySide6.QtWidgets import QFileDialog, QMessageBox, QRubberBand
from ... import APP_NAME
from .. import actions as actmod, engine, ops, selection as selmod
from ..autosave import AutoSaver
from ..palette import Palette
from ..scenesync import SceneSync
from ..seeds import SeedBook
from ..session import Session
from .worker import Jobs
MIME = "application/x-oldfart-palette"
ERASER = "eraser"
CORRIDOR = "corridor"
INSERT = "insert"
def click_wav():
    import math
    import struct
    import tempfile
    import wave
    path = os.path.join(tempfile.gettempdir(), "oldfart-studio-click.wav")
    if not os.path.exists(path):
        rate = 22050
        n = int(rate * 0.025)
        frames = b"".join(struct.pack("<h", int(12000 * math.sin(2 * math.pi * 1800 * i / rate)
                                                 * (1 - i / n) ** 3)) for i in range(n))
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(frames)
    return path
MEASURE_PAUSE_MS = 1200
AUTOSAVE_MS = 15000
def why_line(reason):
    lines = [ln.strip() for ln in str(reason or "").splitlines() if ln.strip()]
    if not lines:
        return ""
    if any(ln.startswith("Traceback") for ln in lines):
        return lines[-1]
    return lines[0]
class Editor(QObject):
    changed = Signal()
    def __init__(self, studio, autosave_folder=None):
        super().__init__(studio.window)
        self.studio = studio
        self.window = studio.window
        self.ctx = studio.ctx
        self.tokens = self.ctx.tokens
        self.palette = Palette()
        self.palette.restore(self.settings_get("palette", {}))
        self.palette.reload_listeners.append(self._textures_reloaded)
        self.session = Session(autosaver=AutoSaver(autosave_folder))
        self.seeds = SeedBook(self.session.doc.meta.get("seeds"))
        self.session.listeners.append(self._session_event)
        self.sync = SceneSync(self.session.doc, self.ctx.scene, self.session.selection,
                              self.session.stack)
        self.session.selection.listeners.append(lambda refs: self._selection_changed())
        self.jobs = Jobs(self)
        self.measure_jobs = Jobs(self)
        self.report_text = ""
        self.last_card = None
        self._measured_rev = None
        self._seeds_written = None
        self._build_panels()
        self._build_actions()
        self._hook_views()
        self._measure_timer = QTimer(self)
        self._measure_timer.setSingleShot(True)
        self._measure_timer.setInterval(MEASURE_PAUSE_MS)
        self._measure_timer.timeout.connect(lambda: self.measure(full=False, quiet=True))
        self._autosave = QTimer(self)
        self._autosave.setInterval(AUTOSAVE_MS)
        self._autosave.timeout.connect(self._autosave_tick)
        self._autosave.start()
        self.window.open = self.open_source
        self.window.editor_open_dialog = self.open_dialog
        self.after_change("Ready")
        QTimer.singleShot(0, lambda: None if getattr(self.studio, "startup_owned", False)
                          else self.offer_recovery_once())
        if not os.environ.get("STUDIO_NO_RECOVERY") and not os.environ.get("STUDIO_NO_TOUR"):
            QTimer.singleShot(800, self.tour.first_run)
    @property
    def tour(self):
        if getattr(self, "_tour", None) is None:
            from .tour import Tour
            self._tour = Tour(self)
        return self._tour
    def _textures_reloaded(self):
        reg = getattr(self.ctx, "registry", None)
        if reg is not None and hasattr(reg, "reload"):
            reg.reload()
            self.ctx.redraw()
    def settings_get(self, key, default=None):
        st = getattr(self.studio.settings, "state", None)
        if not isinstance(st, dict):
            return default
        return (st.get("editor") or {}).get(key, default)
    def settings_set(self, key, value):
        st = getattr(self.studio.settings, "state", None)
        if isinstance(st, dict):
            st.setdefault("editor", {})[key] = value
    def save_palette_state(self):
        self.settings_set("palette", self.palette.state())
    def _build_panels(self):
        from .palette_panel import PalettePanel
        from .panels import HistoryPanel, PropertiesPanel
        from .report_panel import ReportPanel
        from .wish_panel import WishPanel
        docks = self.studio.docks
        self.palette_panel = PalettePanel(self)
        self.wish_panel = WishPanel(self)
        self.report_panel = ReportPanel(self)
        self.properties = PropertiesPanel(self)
        self.history = HistoryPanel(self)
        docks.add("left", "palette", "Palette", self.palette_panel)
        docks.add("right", "wish", "Wish", self.wish_panel)
        docks.add("right", "report", "Report card", self.report_panel)
        docks.add("right", "properties", "Properties", self.properties)
        docks.add("bottom", "history", "History", self.history)
        from .critic_meter import CriticMeter
        from .outliner import OutlinerPanel
        self.outliner = OutlinerPanel(self)
        docks.add("right", "outliner", "Outliner", self.outliner)
        self.critic = CriticMeter(self)
        self.window.statusBar().addPermanentWidget(self.critic)
        docks.get("wish").raise_()
        if not (self.studio.settings.state or {}).get("docks"):
            w = self.window
            w.resizeDocks([docks.get("history")], [120], Qt.Vertical)
        self.jobs.started.connect(lambda label: self.hint("%s..." % label))
        self.jobs.ended.connect(self._job_ended)
        self.measure_jobs.started.connect(lambda *_: self.report_panel.busy(True))
        self.measure_jobs.ended.connect(lambda *_: self.report_panel.busy(False))
    def _build_actions(self):
        from studio.core import keymap
        actmod.register(keymap)
        w = self.window
        mb = w.menuBar()
        edit = mb.addMenu("E&dit")
        build = mb.addMenu("Ma&p")
        rooms_menu = mb.addMenu("B&uild")
        layers_menu = mb.addMenu("La&yers")
        help_menu = next((a.menu() for a in mb.actions() if a.text().replace("&", "") == "Help"),
                         None)
        menus = {"File": None, "Edit": edit, "Select": None, "Map": build, "Build": rooms_menu,
                 "Layers": layers_menu, "Help": help_menu}
        file_menu = next((a.menu() for a in mb.actions() if a.text().replace("&", "") == "File"),
                         None)
        select_menu = next((a.menu() for a in mb.actions()
                            if a.text().replace("&", "") == "Select"), None)
        menus["File"], menus["Select"] = file_menu, select_menu
        if select_menu is not None:
            mb.insertMenu(select_menu.menuAction(), edit)
        view_menu = next((a for a in mb.actions() if a.text().replace("&", "") == "View"), None)
        if view_menu is not None:
            mb.insertMenu(view_menu, build)
            mb.insertMenu(view_menu, rooms_menu)
            mb.insertMenu(view_menu, layers_menu)
        last_group = {}
        for aid, (keys, label, group) in actmod.ACTIONS.items():
            a = w.add_action(aid, lambda a=aid: self.run_action(a), label, keys=keys,
                             group=group)
            menu = menus.get(group)
            if menu is None:
                continue
            if last_group.get(id(menu)) is None and group in ("File", "Select"):
                menu.addSeparator()
            last_group[id(menu)] = group
            if aid in ("build.clip", "edit.group", "layer.lock", "map.critic_worst"):
                menu.addSeparator()
            menu.addAction(a)
        if "select.ignore_groups" in w.actions:
            w.actions["select.ignore_groups"].setCheckable(True)
        for aid, tip in actmod.TIPS.items():
            a = w.actions.get(aid)
            if a is not None:
                a.setStatusTip(tip)
        w.apply_keys()
        self.ctx.empty_lines = self.session.empty_hint(
            {aid: [s.toString() for s in w.actions[aid].shortcuts()]
             for aid in ("map.generate", "build.room", "build.corridor", "build.stairs")
             if aid in w.actions})
        if "select.none" in w.actions:
            w.actions["select.none"].triggered.connect(lambda *_: self.disarm(quiet=True))
    def _hook_views(self):
        self.ctx.pick_handler = self._pick
        self.ctx.gizmo_handler = self._gizmo
        from ..sun import SunTool
        self.sun_tool = SunTool(self)
        self.ctx.sun_tool = self.sun_tool
        self.ctx.cursorMoved.connect(self._cursor)
        self._bands = {}
        for v in self.studio.views.views():
            self._hook_view(v)
    def _hook_view(self, v):
        if getattr(v, "_editor_hooked", False):
            return
        v._editor_hooked = True
        v.setAcceptDrops(True)
        v.installEventFilter(self)
        if hasattr(v, "lmbDrag"):
            v.lmbDrag.connect(self._box_drag)
        if hasattr(v, "contextMenu"):
            v.contextMenu.connect(self._context_menu)
        if hasattr(v, "middleClicked"):
            v.middleClicked.connect(self._middle_pick)
    def _pick(self, hit, mods, view):
        if self.armed:
            return self._armed_pick(hit, mods)
        if mods.get("alt") and hit and hit.kind == "piece":
            ref = self.sync.ref_of_piece(hit.index)
            mode = "add" if mods.get("shift") else "remove" if mods.get("ctrl") else "replace"
            self.session.magic_click(ref, mode)
            return True
        from studio.ui.context import default_pick
        return default_pick(hit, mods, view)
    def _gizmo(self, delta, ids):
        sc = self.ctx.scene
        pivot = sc.selection_pivot()
        pivot = (pivot[0], pivot[2]) if pivot else None
        change = self.sync.commit_transform(sorted(ids), delta.offset, delta.quarters, pivot,
                                            snap_on=self.ctx.snap.enabled)
        self.after_change(change.label if change else "")
        return True
    def _cursor(self, info):
        p = info.get("snapped") or info.get("point")
        if p is not None:
            self.session.cursor = tuple(p)
            if self.armed == CORRIDOR:
                self.corridor_ghost()
            elif self.armed == INSERT:
                self.insert_ghost()
            elif self.armed and self.armed != ERASER:
                self._ghost(self.armed)
    armed = None
    arm_quarters = 0
    def arm(self, entry_id):
        self.corridor_points = []
        if entry_id == INSERT:
            ins = getattr(self, "inserting", None)
            if ins is None:
                return False
            label, what = ins.name, (
                "click in a view to put it down, T turns it, Esc or a right click stops - "
                "%s" % ins.budget_line(self.session.doc)[1])
        elif entry_id == CORRIDOR:
            label, what = "Corridor", (
                "click where it goes, point by point (the corners turn by themselves); "
                "Enter or Shift+click builds it, Backspace takes a point back, Esc stops")
        elif entry_id != ERASER:
            try:
                e = self.palette.get(entry_id)
            except KeyError:
                return False
            label = e.label
            what = "click in a view to place it (Shift+click: the last one), drag for a row, " \
                   "T turns it, Esc or a right click stops"
            if e.section == "textures":
                what = "click pieces to paint them, Esc or a right click stops"
        else:
            label, what = "Eraser", "click or drag over things to delete them, Esc stops"
        self.armed = entry_id
        self.arm_quarters = 0
        for v in self.studio.views.views():
            v.setCursor(Qt.CrossCursor)
        try:
            self.studio.views.active.view.setFocus(Qt.OtherFocusReason)
        except AttributeError:
            pass
        self.hint("%s in the hand: %s" % (label, what))
        return True
    def disarm(self, quiet=False):
        if self.armed is None:
            return
        self.armed = None
        self.arm_quarters = 0
        self.corridor_points = []
        self.inserting = None
        self.sync.clear_ghost()
        for v in self.studio.views.views():
            v.unsetCursor()
        if not quiet:
            self.hint("Nothing in the hand")
    def armed_items(self, entry_id=None):
        from .. import geometry as geo
        e = self.palette.get(entry_id or self.armed)
        items = e.make(self.session.texture, self.session.doc.brief.get("theme"),
                       self.session.prefab_opts if e.section == "prefabs" else None)
        q = self.arm_quarters % 4
        if q and items:
            c = geo.centre_of([i for _, i in items])
            items = [(k, geo.turned(i, q, (c[0], c[2]) if len(c) > 2 else c))
                     for k, i in items]
        return e, items
    def place_armed(self, cursor=None):
        e, items = self.armed_items()
        if not items:
            return None
        self.palette.used(e.id)
        self.save_palette_state()
        msg = self.session.drop(e, cursor=cursor, items=items)
        self.after_change(msg)
        self.click_sound()
        return msg
    def erase(self, refs):
        from .. import groups
        doc = self.session.doc
        keep = groups.editable(doc, refs)
        if not keep:
            if refs:
                self.hint("Locked or hidden: the eraser leaves it alone - unlock the layer "
                          "in the Outliner or press Alt+L")
            return None
        self.push(ops.delete(doc, keep))
        self.click_sound()
        return keep
    inserting = None
    def insert_map_dialog(self):
        from .insertmap_dialog import InsertMapDialog
        dlg = InsertMapDialog(self)
        self._insert_dialog = dlg
        dlg.show()
        return dlg
    def arm_insert(self, ins):
        self.disarm(quiet=True)
        self.inserting = ins
        if not self.arm(INSERT):
            self.inserting = None
            return False
        self.insert_ghost()
        return True
    def insert_ghost(self):
        ins = self.inserting
        if ins is None:
            self.sync.clear_ghost()
            return None
        self.sync.show_ghost(ins.ghost(self.session.cursor, self.arm_quarters,
                                       self.session.snap_on))
        return True
    def insert_place(self, cursor=None):
        from ..insertmap import InsertError
        ins = self.inserting
        if ins is None:
            return None
        try:
            change = ins.change(self.session.doc, cursor or self.session.cursor,
                                self.arm_quarters, self.session.snap_on)
        except InsertError as why:
            self.hint(str(why))
            return None
        self.sync.clear_ghost()
        self.push(change)
        self.disarm(quiet=True)
        self.hint("%s is in, on the layer \"From %s\" - Ctrl+Z takes it out"
                  % (ins.name, ins.name))
        return change
    corridor_points = []
    def corridor_change(self, points=None):
        from .. import rooms
        s = self.session
        pts = list(points if points is not None else self.corridor_points)
        if not pts:
            return None, ""
        if len(pts) == 1:
            pts.append(tuple(s.cursor))
        c = s.corridor
        y = pts[0][1]
        return rooms.corridor(s.doc, (pts[0][0], y, pts[0][2]), (pts[-1][0], y, pts[-1][2]),
                              c["width"], c["h"], c["ceiling"], s.texture, s.texture2,
                              via=[(p[0], y, p[2]) for p in pts[1:-1]], shape="path",
                              doors=tuple(c.get("doors") or ()))
    def corridor_ghost(self):
        if not self.corridor_points:
            self.sync.clear_ghost()
            return None
        pts = self.corridor_points + [tuple(self.session.cursor)]
        ch, note = self.corridor_change(pts)
        if ch is None or not ch:
            self.sync.clear_ghost()
            return note
        self.sync.show_ghost([st[3] for st in ch.steps if st[0] == "insert"])
        return note
    def corridor_click(self, point, finish=False):
        pts = self.corridor_points
        if point is not None and (not pts or tuple(point) != pts[-1]):
            pts.append(tuple(point))
        if finish:
            return self.corridor_finish()
        if len(pts) == 1:
            self.hint("Corridor: A is set - click the next point (Enter builds, Esc stops)")
        else:
            ch, note = self.corridor_change()
            self.hint("Corridor: %d points - %s. Enter builds it, Backspace takes the last "
                      "point back" % (len(pts), note))
        self.corridor_ghost()
        return None
    def corridor_back(self):
        if self.corridor_points:
            self.corridor_points.pop()
            self.hint("Corridor: %d point%s" % (len(self.corridor_points),
                                                "" if len(self.corridor_points) == 1 else "s"))
            self.corridor_ghost()
    def corridor_finish(self):
        pts = list(self.corridor_points)
        if len(pts) < 2:
            self.hint("A corridor needs two points or more - click where it goes")
            return None
        self.sync.clear_ghost()
        msg = self.session.corridor_path(pts)
        self.disarm(quiet=True)
        self.after_change(msg)
        return msg
    def _armed_pick(self, hit, mods):
        if self.armed == INSERT:
            if hit is not None and hit.point is not None:
                self.session.cursor = tuple(self.ctx.snap.point(hit.point))
            self.insert_place()
            return True
        if self.armed == CORRIDOR:
            p = None
            if hit is not None and hit.point is not None:
                p = tuple(self.ctx.snap.point(hit.point))
                self.session.cursor = p
            self.corridor_click(p, finish=bool(mods.get("shift")))
            return True
        if self.armed == ERASER:
            ref = self._ref_of_hit(hit)
            if ref is not None:
                self.erase([ref])
            return True
        e = self.palette.get(self.armed)
        if e.section == "textures":
            if hit and hit.kind == "piece":
                self.set_texture(e.key)
                self.push(ops.retexture(self.session.doc, [self.sync.ref_of_piece(hit.index)],
                                        e.key))
                self.click_sound()
            return True
        if hit is not None and hit.point is not None and not self._edge_hit(hit):
            self.session.cursor = tuple(self.ctx.snap.surface(hit.point))
        self.place_armed()
        if mods.get("shift"):
            self.disarm()
        return True
    def _edge_hit(self, hit):
        from studio.core import instances
        try:
            return hit.kind == "piece" and instances.outlined(self.ctx.scene.shown_piece(hit.index))
        except (IndexError, AttributeError, TypeError):
            return False
    def _ref_of_hit(self, hit):
        if not hit:
            return None
        if hit.kind == "piece":
            return self.sync.ref_of_piece(hit.index)
        if hit.kind == "marker":
            return self.sync.ref_of_marker(hit.index)
        return None
    def lay_row(self, start, end):
        from .. import geometry as geo
        e, items = self.armed_items()
        box = geo.grid_box([i for _, i in items])
        step_x = max(geo.GRID, (box[1] - box[0]) if box else geo.GRID)
        step_z = max(geo.GRID, (box[5] - box[4]) if box else geo.GRID)
        dx, dz = end[0] - start[0], end[2] - start[2]
        along_x = abs(dx) >= abs(dz)
        step = step_x if along_x else step_z
        n = int(abs(dx if along_x else dz) // step) + 1
        sign = 1 if (dx if along_x else dz) >= 0 else -1
        for i in range(n):
            off = sign * i * step
            at = (start[0] + (off if along_x else 0), start[1], start[2] + (0 if along_x else off))
            self.place_armed(at)
        self.hint("Laid %d x %s" % (n, e.label))
        return n
    def click_sound(self):
        if not self.settings_get_global("ui.place_sound", True):
            return
        try:
            if getattr(self, "_click", None) is None:
                from PySide6.QtCore import QUrl
                from PySide6.QtMultimedia import QSoundEffect
                self._click = QSoundEffect(self)
                self._click.setSource(QUrl.fromLocalFile(click_wav()))
                self._click.setVolume(0.35)
            self._click.play()
        except Exception:
            self._click = False
    def settings_get_global(self, key, default=None):
        try:
            return self.studio.settings[key]
        except Exception:
            return default
    MENU_ON_THING = ("gizmo.move", "edit.turn", "edit.mirror_x", None, "edit.duplicate",
                     "edit.copy", "edit.cut", "edit.delete", None, "edit.paint",
                     "edit.eyedropper", "select.linked", "select.similar", None,
                     "lib.save_prefab", "view.frame_selected")
    MENU_ON_NOTHING = ("edit.paste", "tools.note", None, "select.all", "view.frame_all")
    def context_actions(self, hit):
        thing = bool(hit) and hit.kind in ("piece", "marker")
        if thing:
            sc = self.ctx.scene
            chosen = (hit.index in sc.selection) if hit.kind == "piece" else \
                (hit.index in sc.marker_selection)
            if not chosen:
                from studio.ui.context import default_pick
                default_pick(hit, {}, self.studio.views.views()[0])
        acts = self.window.actions
        out = []
        for aid in (self.MENU_ON_THING if thing else self.MENU_ON_NOTHING):
            if aid is None:
                if out and out[-1] is not None:
                    out.append(None)
            elif aid in acts:
                out.append(acts[aid])
        while out and out[-1] is None:
            out.pop()
        return out
    def place_here_entries(self, n=5):
        out = []
        for eid in self.palette.recent[:n]:
            try:
                out.append(self.palette.get(eid))
            except KeyError:
                pass
        return out
    def _context_menu(self, view, hit, global_pos):
        from PySide6.QtWidgets import QMenu
        if self.armed:
            self.disarm()
            return None
        if hit is not None and hit.point is not None and not self._edge_hit(hit):
            self.session.cursor = tuple(self.ctx.snap.surface(hit.point))
        m = QMenu(view)
        for a in self.context_actions(hit):
            if a is None:
                m.addSeparator()
            else:
                m.addAction(a)
        recent = self.place_here_entries()
        if recent:
            m.addSeparator()
            sub = m.addMenu("Place here")
            for e in recent:
                act = sub.addAction(e.label)
                act.triggered.connect(lambda _=False, eid=e.id: self.drop(eid))
        self._last_menu = m
        m.popup(global_pos)
        return m
    def _middle_pick(self, view, hit):
        if not hit:
            return None
        if hit.kind == "piece":
            ref = self.sync.ref_of_piece(hit.index)
            p = self.session.doc.get(ref) or {}
            tex = p.get("tex")
            if tex:
                self.set_texture(tex)
                self.hint("Picked %s: new pieces wear %s (P paints the selection)"
                          % (p.get("kind", "piece"), tex))
            return tex
        return None
    _body = None
    def _body_drag(self, view, start, now, phase):
        from studio.core.scene import Preview
        sc = self.ctx.scene
        if phase == "begin":
            self._body = None
            if self.armed:
                return False
            hit = view.pick_at(start, plane=False)
            if not (hit and hit.kind == "piece" and hit.index in sc.selection):
                return False
            self._body = {"y": hit.point[1], "from": hit.point, "delta": (0.0, 0.0, 0.0)}
            return True
        if self._body is None:
            return False
        o, d = view.ray_at(now)
        if abs(d[1]) > 1e-6:
            t = (self._body["y"] - o[1]) / d[1]
            if t > 0:
                p = (o[0] + d[0] * t, o[2] + d[2] * t)
                dx, dz = p[0] - self._body["from"][0], p[1] - self._body["from"][2]
                if self.ctx.snap.enabled:
                    step = self.ctx.snap.step
                    dx, dz = round(dx / step) * step, round(dz / step) * step
                self._body["delta"] = (dx, 0.0, dz)
        piv = sc.selection_pivot()
        if phase == "drag":
            sc.set_preview(Preview(sc.selection, self._body["delta"], 0,
                                   (piv[0], piv[2]) if piv else (0.0, 0.0)))
            return True
        delta, self._body = self._body["delta"], None
        sc.set_preview(None)
        if any(delta):
            change = self.sync.commit_transform(None, delta, 0, None,
                                                snap_on=self.ctx.snap.enabled)
            self.after_change(change.label if change else "")
        return True
    def _box_drag(self, view, start, now, phase):
        if self._body_drag(view, start, now, phase):
            return
        band = self._bands.get(id(view))
        rect = QRect(start.toPoint(), now.toPoint()).normalized()
        if phase in ("begin", "drag"):
            if band is None:
                band = QRubberBand(QRubberBand.Rectangle, view)
                self._bands[id(view)] = band
            band.setGeometry(rect)
            band.show()
            return
        if band is not None:
            band.hide()
        if self.armed in (CORRIDOR, INSERT):
            return
        if self.armed and self.armed != ERASER:
            a, b = view.pick_at(start), view.pick_at(now)
            if a.point is not None and b.point is not None:
                if self.palette.get(self.armed).section != "textures":
                    self.lay_row(tuple(self.ctx.snap.point(a.point)),
                                 tuple(self.ctx.snap.point(b.point)))
            return
        w, h = max(1, view.width()), max(1, view.height())
        cam = view.camera
        def project(p):
            return cam.to_pixel(p, w, h)
        from PySide6.QtWidgets import QApplication
        mods = QApplication.keyboardModifiers()
        mode = "add" if mods & Qt.ShiftModifier else "remove" if mods & Qt.ControlModifier \
            else "replace"
        got = selmod.screen_box_select(self.session.doc, project,
                                       (rect.left(), rect.right(), rect.top(), rect.bottom()))
        if self.armed == ERASER:
            if got:
                self.erase(list(got))
            return
        self.session.selection.combine(got, mode)
        self.hint("%d selected by the box" % len(self.session.selection))
    def drop_files(self, paths):
        from .. import dropfiles
        what, got, words = dropfiles.classify(paths)
        if what is None:
            self.hint("Not taken: %s" % words)
            return None
        lib = getattr(self.studio, "library", None)
        if what == "map":
            if not self._may_drop_edits():
                return None
            self.open_source(got[0])
        elif what == "gltf":
            from studio.exchange import docio
            try:
                change, lines = docio.import_change(self.session.doc, got[0])
            except (OSError, ValueError, KeyError) as why:
                self.hint("glTF not read: %s" % why)
                return None
            self.push(change)
            self.show_text("Back from Blender", "\n".join(lines))
        elif lib is None:
            self.hint("The library is not installed - %s needs it" % words.lower())
            return None
        elif what == "textures":
            mgr = lib.texture_manager()
            mgr.tabs.setCurrentWidget(mgr.importer)
            mgr.importer.add(got)
        elif what == "music":
            lib.music.import_paths(got)
        self.hint(words)
        return what
    def eventFilter(self, obj, ev):
        t = ev.type()
        if t == ev.Type.KeyPress and self.armed == CORRIDOR:
            if ev.key() in (Qt.Key_Return, Qt.Key_Enter):
                self.corridor_finish()
                return True
            if ev.key() == Qt.Key_Backspace:
                self.corridor_back()
                return True
        if t in (ev.Type.DragEnter, ev.Type.DragMove) and ev.mimeData().hasUrls() \
                and not ev.mimeData().hasFormat(MIME):
            from .. import dropfiles
            paths = [u.toLocalFile() for u in ev.mimeData().urls() if u.isLocalFile()]
            what, _, words = dropfiles.classify(paths)
            if what is not None:
                ev.acceptProposedAction()
                self.hint(words + " - let go to do it")
            else:
                ev.ignore()
            return True
        if t == ev.Type.Drop and ev.mimeData().hasUrls() and not ev.mimeData().hasFormat(MIME):
            paths = [u.toLocalFile() for u in ev.mimeData().urls() if u.isLocalFile()]
            if self.drop_files(paths):
                ev.acceptProposedAction()
            return True
        if t in (ev.Type.DragEnter, ev.Type.DragMove):
            if ev.mimeData().hasFormat(MIME):
                ev.acceptProposedAction()
                if t == ev.Type.DragMove and hasattr(obj, "pick_at"):
                    hit = obj.pick_at(ev.position(), outlines=False)
                    if hit.point is not None:
                        self.session.cursor = tuple(self.ctx.snap.surface(hit.point))
                        self._ghost(bytes(ev.mimeData().data(MIME)).decode())
                return True
        elif t == ev.Type.DragLeave:
            self.sync.clear_ghost()
        elif t == ev.Type.Drop and ev.mimeData().hasFormat(MIME):
            entry_id = bytes(ev.mimeData().data(MIME)).decode()
            hit = obj.pick_at(ev.position(), outlines=False) if hasattr(obj, "pick_at") \
                else None
            self.sync.clear_ghost()
            if hit is not None and hit.point is not None:
                self.session.cursor = tuple(self.ctx.snap.surface(hit.point))
            if entry_id.startswith("textures:") and hit is not None and hit.kind == "piece":
                ref = self.sync.ref_of_piece(hit.index)
                self.set_texture(entry_id.split(":", 1)[1])
                self.push(ops.retexture(self.session.doc, [ref], self.session.texture))
            else:
                self.drop(entry_id)
            ev.acceptProposedAction()
            return True
        return False
    def _ghost(self, entry_id):
        try:
            e = self.palette.get(entry_id)
        except KeyError:
            return
        if e.section == "textures":
            return
        from .. import geometry as geo
        items = [i for _, i in self.armed_items(entry_id)[1]]
        self.sync.show_ghost(geo.placed_at(items, self.session.cursor, self.session.snap_on,
                                           anchor=e.data.get("anchor")))
    def hint(self, text):
        if text:
            self.window.hint(text)
    NEEDS = ("select", "nothing", "pick a", "first")
    def toast(self, msg):
        if not msg:
            return None
        text = msg
        if msg.startswith("Delete") and "item" in msg:
            text = msg + " - Ctrl+Z brings them back"
        bad = any(w in msg.lower() for w in self.NEEDS) and not msg.startswith(("Place", "Set"))
        try:
            view = self.studio.views.active.view
        except AttributeError:
            return None
        view.show_toast(text, bad=bad)
        return text
    def push(self, change):
        msg = self.session.push(change)
        self.after_change(msg)
    def run_action(self, aid):
        handlers = {"file.save": self.save, "file.save_as": lambda: self.save(as_=True),
                    "file.open_map": self.open_dialog, "map.generate": self.generate,
                    "map.refine": self.refine, "map.variety": self.variety,
                    "map.measure": lambda: self.measure(full=False),
                    "map.export": self.export_only, "map.play": self.play_dialog,
                    "map.reskin": self.reskin_dialog,
                    "map.export_to": self.export_to, "map.export_level": self.export_level, "map.seed_back": lambda: self.seed_step(-1),
                    "map.seed_forward": lambda: self.seed_step(1),
                    "map.seed_lock": self.seed_lock,
                    "map.critic_worst": lambda: self.critic.show_worst(),
                    "file.insert_map": self.insert_map_dialog,
                    "help.tour": lambda: self.tour.toggle()}
        if aid in handlers:
            return handlers[aid]()
        from .build_dialogs import DIALOGS, open_dialog
        if aid in DIALOGS:
            return open_dialog(self, aid)
        if aid == "edit.eraser":
            if self.armed == ERASER:
                return self.disarm()
            return self.arm(ERASER)
        if aid == "build.corridor_path":
            return self.arm(CORRIDOR)
        if self.armed and self.armed not in (ERASER, CORRIDOR) and \
                aid in ("edit.turn", "edit.turn_back"):
            self.arm_quarters += 1 if aid == "edit.turn" else -1
            if self.armed == INSERT:
                self.insert_ghost()
            else:
                self._ghost(self.armed)
            self.hint("Turned: %d degrees" % (self.arm_quarters % 4 * 90))
            return None
        if aid == "file.new" and not self._may_drop_edits():
            return None
        msg = self.session.do(aid)
        self.after_change(msg)
        return msg
    def drop(self, entry_id):
        try:
            e = self.palette.get(entry_id)
        except KeyError:
            return
        self.palette.used(entry_id)
        self.save_palette_state()
        msg = self.session.drop(e)
        self.after_change(msg)
    def set_texture(self, slug):
        self.session.texture = slug
        self.palette_panel.show_texture(slug)
        self.hint("Texture: %s - new pieces wear it, P paints the selection" % slug)
    def select_fault(self, text):
        ids = self.sync.show_issues([text])
        refs = [self.sync.ref_of_piece(i) for i in sorted(ids)]
        if refs:
            self.session.selection.set(refs)
    def after_change(self, msg=""):
        self.hint(msg or "")
        if msg and msg.startswith(("Place", "Room", "Corridor", "Stairs")) and \
                self.tour.done("place"):
            pass
        else:
            self.toast(msg)
        if self.palette.recent != getattr(self, "_recent_shown", None):
            self._recent_shown = list(self.palette.recent)
            self.palette_panel.fill_recent()
        self.window.setWindowTitle("%s - %s" % (self.session.title(), APP_NAME))
        self.history.refresh()
        self.properties.refresh()
        self.changed.emit()
        if self.session.doc.revision != self._measured_rev:
            self._measure_timer.start()
    def _selection_changed(self):
        self.properties.refresh()
        self.hint(self.session.selection_line())
    def _session_event(self, event, payload):
        if event == "document":
            self.sync.attach(payload, self.session.stack)
            if payload.meta.get("seeds") is not self._seeds_written:
                self.seeds.restore(payload.meta.get("seeds") or {})
                self._seeds_written = payload.meta.get("seeds")
                if not self.seeds.entries and isinstance(payload.brief.get("seed"), int):
                    self.seeds.record(payload.brief["seed"], "Opened")
            self._seedbar_refresh()
            self.report_text = ""
            self.last_card = None
            self.report_panel.show_result(None)
            self.wish_panel.load_brief(payload.brief)
            self.after_change()
            try:
                self.studio.views.frame_all(animate=False)
            except Exception:
                pass
        elif event == "texture":
            self.palette_panel.show_texture(payload)
    def _may_drop_edits(self):
        if self.session.stack.is_clean():
            return True
        got = QMessageBox.question(self.window, "Unsaved changes",
                                   "This map has changes that are not saved. Save them first?",
                                   QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel)
        if got == QMessageBox.Save:
            return bool(self.save())
        return got == QMessageBox.Discard
    def open_source(self, source, frame=True, recent=True):
        if not self._may_drop_edits():
            return False
        if source == "playground:":
            from studio.ux import playground
            doc = playground.document(keys=lambda aid: [
                k.toString() for k in (self.window.actions[aid].shortcuts()
                                       if aid in self.window.actions else [])])
            self.session._replace_doc(doc, origin="Playground")
            msg = ("The Playground: try what the notes say - nothing can go wrong, Ctrl+Z takes "
                   "anything back")
            tools = getattr(self.studio, "tools", None)
            if tools is not None and not tools.state.notes_shown:
                tools.run("tools.notes_show")
        elif source.startswith("venue:"):
            from mapgen import v1
            from ..document import Document
            try:
                try:
                    layout = v1.venue(source.split(":", 1)[1])
                except KeyError:
                    from studio.core import loader as _loader
                    layout = _loader.venue_layout(source.split(":", 1)[1])
            except Exception as why:
                return self._open_failed(source, "there is no venue %r in the mod (%s)"
                                         % (source[6:], why))
            self.session._replace_doc(Document({}, layout))
            from studio.core import loader
            try:
                shown = "The " + loader.venue_name(source[6:])
            except Exception:
                shown = source[6:]
            self.session.doc.rest.setdefault("name", "%s (copy)" % shown)
            msg = ("Opened %s as a copy - Save keeps it under a new name; export it under a "
                   "new name" % shown)
        else:
            msg = self.session.open(source)
            if getattr(self.session, "open_failed", None):
                return self._open_failed(source, self.session.open_failed)
            report = os.path.join(source if os.path.isdir(source) else os.path.dirname(source),
                                  "report.md")
            if os.path.exists(report):
                with open(report, encoding="utf-8") as h:
                    self.report_text = h.read()
            try:
                if recent:
                    self.studio.settings.add_recent(source)
            except Exception:
                pass
        self.after_change(msg)
        return True
    def _open_failed(self, source, reason):
        name = os.path.basename(str(source).rstrip("/")) or str(source)
        self.hint("Could not open %s - %s" % (name, reason))
        if getattr(self.studio, "starting", False):
            return False
        try:
            from PySide6.QtWidgets import QMessageBox
            box = QMessageBox(QMessageBox.Warning, "Could not open %s" % name,
                              "Could not open %s." % name, QMessageBox.Ok, self.window)
            tips = ["Try File > Recent for another map"]
            folder = getattr(getattr(self.session, "autosaver", None), "folder", None)
            if folder:
                tips.append("or an autosaved copy in %s" % folder)
            box.setInformativeText("%s.\n\n%s." % (reason, ", ".join(tips)))
            box.setObjectName("openFailed")
            box.open()
            self._open_box = box
        except Exception:
            pass
        return False
    def open_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self.window, "Open a map", self.settings_get("dir", os.getcwd()),
            "Maps (*.ofmap layout.json brief.json *.json);;All files (*)")
        if path:
            self.settings_set("dir", os.path.dirname(path))
            self.open_source(path)
    def save(self, as_=False):
        path = None if as_ else self.session.doc.meta.get("path")
        if not path:
            name = self.session.doc.rest.get("name") or "map"
            path, _ = QFileDialog.getSaveFileName(
                self.window, "Save the map", os.path.join(
                    self.settings_get("dir", os.getcwd()), engine.key_for(name) + ".ofmap"),
                "%s maps (*.ofmap)" % APP_NAME)
            if not path:
                return None
            self.settings_set("dir", os.path.dirname(path))
        got = self.session.save(path)
        self.after_change("Saved %s" % got)
        return got
    def _autosave_tick(self):
        try:
            got = self.session.autosave_tick()
        except OSError as exc:
            self.hint("Autosave failed: %s" % exc)
            return
        if got:
            self.hint("Autosaved (%s)" % time.strftime("%H:%M"))
    RECOVER_TITLE = "Bring back your changes?"
    RECOVER_TEXT = ("Your last session closed unexpectedly. Bring back the unsaved changes?")
    RECOVER_YES = "Yes, bring them back"
    RECOVER_NO = "No, keep the saved map"
    def offer_recovery_once(self, ask=None):
        if getattr(self, "_recovery_asked", False):
            return None
        self._recovery_asked = True
        return self._offer_recovery(ask)
    def _offer_recovery(self, ask=None):
        saver = self.session.autosaver
        if not saver or (ask is None and os.environ.get("STUDIO_NO_RECOVERY")):
            return None
        try:
            found = saver.recoverable()
        except OSError:
            found = []
        if not found:
            return None
        path, at, name = found[0]
        detail = "%s, saved by itself at %s." % (
            name or "An untitled map", time.strftime("%H:%M on %d %b", time.localtime(at)))
        if ask is not None:
            yes = ask(self.RECOVER_TEXT, detail)
        else:
            box = QMessageBox(self.window)
            box.setWindowTitle(self.RECOVER_TITLE)
            box.setIcon(QMessageBox.Question)
            box.setText(self.RECOVER_TEXT)
            box.setInformativeText(detail)
            yes_button = box.addButton(self.RECOVER_YES, QMessageBox.YesRole)
            no_button = box.addButton(self.RECOVER_NO, QMessageBox.NoRole)
            box.setDefaultButton(yes_button)
            box.setEscapeButton(no_button)
            box.exec()
            yes = box.clickedButton() is yes_button
        if not yes:
            saver.put_aside(path)
            self.after_change("Kept the saved map - the autosave is put aside")
            return "no"
        try:
            doc = saver.recover(path)
        except Exception as why:
            saver.put_aside(path)
            self.after_change("The autosave could not be read (%s) - kept the saved map"
                              % why_line(why))
            return "broken"
        self.session._replace_doc(doc, origin="Recovered")
        self.session.stack.clean_at = None
        self.after_change("Brought back your unsaved changes - save to keep them")
        return "yes"
    def _engine_busy(self):
        if self.jobs.busy():
            self.hint("The engine is still working - wait, or Cancel")
            return True
        return False
    def generate(self):
        if self._engine_busy():
            return
        if self.session.stack.hand_edits() and QMessageBox.question(
                self.window, "Generate a new map?",
                "Your %d hand edit(s) are replaced by the new map (Undo brings them back).%s"
                % (self.session.stack.hand_edits(), self._locked_note())) != QMessageBox.Yes:
            return
        raw, reading = self.wish_panel.brief()
        wish = self.wish_panel.wish_text() or None
        seed = self.seeds.next_seed(random.Random(), raw.get("seed"))
        def job(progress, cancelled):
            return engine.generate(raw, seed=seed, progress=progress, cancel=cancelled,
                                   reading=reading, wish=wish)
        self.jobs.run("Generating (seed %d)" % seed, job, self._generated)
    def _locked_note(self):
        from .. import groups
        n = len(groups.locked_refs(self.session.doc))
        return (" The locked layers stay (%d thing%s): the new map is made around them."
                % (n, "" if n == 1 else "s")) if n else ""
    def _job_ended(self, reason):
        if reason:
            self.hint("%s stopped: %s" % (self.jobs.label or "The job", why_line(reason)))
    def _generated(self, gen, record=True):
        if gen.brief.get("wish") is None and self.wish_panel.wish_text():
            gen.brief["wish"] = self.wish_panel.wish_text()
        self.report_text = gen.report_text
        if record and gen.brief.get("seed") is not None:
            self.seeds.record(gen.brief["seed"], "Generate", gen)
        msg = self.session.apply_generated(gen)
        self._keep_seeds()
        said = ["[%s] %s: %s" % tuple(line) for line in gen.lines]
        said.append("seed %s - Generate rolls another, Lock keeps it, < > step through the "
                    "maps before" % gen.brief.get("seed"))
        self.wish_panel.show_said(said)
        self.after_change(msg)
        try:
            self.studio.views.frame_all(animate=True)
        except Exception:
            pass
        if not self.tour.done("wish"):
            self.tour.start()
    def _keep_seeds(self):
        state = self.seeds.state()
        self.session.doc.meta["seeds"] = state
        self._seeds_written = state
        self._seedbar_refresh()
    def _seedbar_refresh(self):
        bar = getattr(getattr(self, "wish_panel", None), "seedbar", None)
        if bar is not None:
            bar.refresh()
    def seed_lock(self):
        self.seeds.lock(not self.seeds.locked)
        self._keep_seeds()
        self.hint("Seed %s - Generate keeps it" % self.seeds.current_seed() if self.seeds.locked
                  else "Seed unlocked - Generate rolls a new one")
    def seed_step(self, step):
        if self._engine_busy():
            return
        entry = self.seeds.back() if step < 0 else self.seeds.forward()
        if entry is None:
            self.hint("No map %s in the seed history" % ("before" if step < 0 else "after"))
            return
        kept = self.seeds.result()
        if kept is not None:
            self._generated(kept, record=False)
            return
        raw, reading = self.wish_panel.brief()
        seed = entry["seed"]
        def job(progress, cancelled):
            return engine.generate(raw, seed=seed, progress=progress, cancel=cancelled,
                                   reading=reading, wish=self.wish_panel.wish_text() or None)
        def done(gen):
            self.seeds.keep(gen)
            self._generated(gen, record=False)
        self.jobs.run("Building seed %d again" % seed, job, done)
    def export_level(self):
        from . import modpack_dialog
        return modpack_dialog.run(self)
    def export_to(self):
        from . import exportto
        return exportto.run(self)
    def refine(self):
        if self._engine_busy():
            return
        text = self.wish_panel.refine_text.text().strip()
        if not text:
            self.hint("Say what to change: \"bigger centre\", \"move the spawn north\"...")
            return
        doc = self.session.doc
        if not (doc.rest.get("generator") or {}).get("seed") and not doc.brief:
            self.hint("Refine changes a generated map - generate one first")
            return
        if self.session.stack.hand_edits() and QMessageBox.question(
                self.window, "Refine?", "Refine rebuilds the map from its wish: your %d hand "
                "edit(s) are replaced (Undo brings them back). Anchors you placed are kept.%s"
                % (self.session.stack.hand_edits(), self._locked_note())) != QMessageBox.Yes:
            return
        brief, layout = dict(doc.brief), doc.to_layout()
        reader = getattr(self, "refine_reader", None)
        def job(progress, cancelled):
            ops, lines = None, []
            if reader is not None:
                ops, lines = reader(text, brief, progress)
            gen = engine.refine(brief, layout, text, progress=progress, cancel=cancelled,
                                ops=ops)
            gen.lines = list(lines) + list(gen.lines or [])
            return gen
        self.jobs.run("Refining: %s" % text, job, self._refined)
    def _refined(self, gen):
        self.report_text = gen.report_text
        msg = self.session.apply_generated(gen)
        self.wish_panel.show_said(gen.lines)
        self.after_change(msg)
    def variety(self):
        if self._engine_busy():
            return
        raw, _ = self.wish_panel.brief()
        count = self.wish_panel.count.value()
        def job(progress, cancelled):
            return engine.variety(raw, count=count, children=max(24, 10 * count),
                                  progress=progress, cancel=cancelled)
        self.jobs.run("Searching for %d different maps" % count, job, self._varied)
    def _varied(self, maps):
        self.wish_panel.show_variety(maps)
        self.hint("%d maps - double-click one to use it" % len(maps))
    def apply_generated(self, gen):
        self.report_text = gen.report_text
        self.after_change(self.session.apply_generated(gen))
    def measure(self, full=False, quiet=False):
        if self.measure_jobs.busy():
            if not quiet:
                self.hint("Measuring already")
            self._measure_timer.start()
            return
        doc = self.session.doc
        layout, brief, rev = doc.to_layout(), dict(doc.brief), doc.revision
        def job(progress, cancelled):
            from .. import childcall
            return childcall.call("studio.editor.engine:card", layout, brief,
                                  tier="full" if full else "cheap", sim=full)
        def done(res):
            self._measured_rev = rev
            self.last_card = res
            self.report_panel.show_result(res)
            self.sync.show_issues(res["gate"])
        self.measure_jobs.run("Measuring", job, done,
                              lambda reason: self.report_panel.note.setText(reason))
    def export_dialog(self):
        from .panels import ExportDialog
        dlg = ExportDialog(self, self.window)
        dlg.show()
        self._export_dialog = dlg
        return dlg
    _play_next = False
    def reskin_dialog(self, theme=None):
        from .. import reskin
        if theme is None:
            from PySide6.QtWidgets import QInputDialog
            names = reskin.themes()
            now = self.session.doc.brief.get("theme") or "castle"
            theme, ok = QInputDialog.getItem(self.window, "Re-skin", "The map in the theme:",
                                             names, max(0, names.index(now)
                                                        if now in names else 0), False)
            if not ok:
                return None
        change = reskin.reskin(self.session.doc, theme)
        self.push(change)
        return change
    def export_only(self):
        self._play_next = False
        return self.export_dialog()
    def play_dialog(self):
        self.tour.done("play")
        self._play_next = True
        dlg = self.export_dialog()
        dlg.setWindowTitle("Export and play")
        return dlg
    def launch_game(self, mod=None):
        from .. import play
        game = play.find_game(self.settings_get_global("play.game_path", "") or None)
        if game is None:
            self.hint("Coop DX was not found - set its program in Preferences > Tools")
            return None
        argv = play.command(game, mod)
        if not play.start(argv):
            self.hint("Coop DX did not start: %s" % " ".join(argv))
            return None
        self.hint("Coop DX starts hosting - the venue is on the Arenas page (close the game "
                  "before the next export: a venue's level is read when the mod loads)")
        return argv
    def export(self, name, key, mod, blurb, on_done, on_fail, modes=None):
        doc = self.session.doc
        layout, brief = doc.to_layout(), dict(doc.brief)
        layout["name"] = name
        if modes is not None:
            layout["onlyFor"] = list(modes[0])
            if modes[1]:
                layout["notFor"] = list(modes[1])
            else:
                layout.pop("notFor", None)
        def job(progress, cancelled):
            progress(0, 0, "Writing the map into the mod and checking it")
            return engine.export(layout, brief, name, key, mod, blurb)
        def done(res):
            if doc.rest.get("name") != name:
                self.push(ops.set_rest(doc, "name", name, "Name the map"))
            self.hint("Exported %s into the mod - see the play-it note" % name)
            on_done(res)
            if self._play_next:
                self._play_next = False
                self.launch_game(mod)
        if not self.jobs.run("Exporting %s" % name, job, done, on_fail):
            on_fail("the engine is busy - try again in a moment")
    def show_text(self, title, text):
        from .panels import TextDialog
        dlg = TextDialog(title, text, self.window)
        dlg.show()
        self._text_dialog = dlg
        return dlg
def install(studio, autosave_folder=None):
    editor = Editor(studio, autosave_folder)
    studio.editor = editor
    settings = getattr(studio, "settings", None)
    def follow(*_):
        try:
            engine.HISTORY = bool(settings.get("wish.history"))
        except Exception:
            engine.HISTORY = True
        try:
            engine.TASTE = bool(settings.get("taste.use"))
        except Exception:
            engine.TASTE = True
    if settings is not None:
        follow()
        if hasattr(settings, "listen"):
            settings.listen(follow)
    return editor
__all__ = ["Editor", "install", "QSize"]
