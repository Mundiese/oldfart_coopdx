from PySide6.QtCore import QEvent, QObject, Qt, QTimer
from studio.editor.qt.worker import Jobs
from studio.toolbox import controller, issues as issmod, meters, overlays as ovmod, region
from studio.toolbox.controller import ACTIONS, BRUSH_ACTIONS, OVERLAY_ACTIONS, ToolState
from . import paint
METER_PAUSE_MS = 400
OVERLAY_PAUSE_MS = ovmod.IDLE_MS
def preview_score(pv):
    b, a = pv.get("before"), pv.get("after")
    if isinstance(b, (int, float)) and isinstance(a, (int, float)):
        return "critic %.0f → %.0f" % (b, a)
    return "the critic measures again"
class Tools(QObject):
    def __init__(self, studio):
        super().__init__(studio.window)
        self.studio = studio
        self.window = studio.window
        self.ctx = studio.ctx
        self.ed = studio.editor
        self.state = ToolState(self.ed.session)
        self.state.listeners.append(self._state_event)
        self.overlay_jobs = Jobs(self)
        self.wanted = []
        self.stale = set()
        self._build_docks()
        self._build_actions()
        self._hook_views()
        self._meter_timer = QTimer(self)
        self._meter_timer.setSingleShot(True)
        self._meter_timer.setInterval(METER_PAUSE_MS)
        self._meter_timer.timeout.connect(self.update_meters_later)
        self.meter_jobs = Jobs(self)
        self._meters_again = False
        self._overlay_timer = QTimer(self)
        self._overlay_timer.setSingleShot(True)
        self._overlay_timer.setInterval(OVERLAY_PAUSE_MS)
        self._overlay_timer.timeout.connect(self.refresh_after_edit)
        self._apply_settings()
        studio.settings.listen(lambda key, _v: key.startswith("tools.") and
                               self._apply_settings())
        self.ed.changed.connect(self._doc_changed)
        self.ed.session.listeners.append(self._session_event)
        self._hook_report()
        self.ed.palette.reload_listeners.append(lambda: self.panel.fill_scatter())
        self._load_symmetry(self.ed.session.doc)
        self._hook_build()
        self._meter_timer.start()
        self.snapshots.refresh()
    def _build_docks(self):
        from .panels import IssuesPanel, MetersBar, OverlaysPanel, SnapshotsPanel, ToolsPanel
        docks = self.studio.docks
        self.panel = ToolsPanel(self)
        self.overlays = OverlaysPanel(self)
        self.issues = IssuesPanel(self)
        self.snapshots = SnapshotsPanel(self)
        docks.add("left", "tools", "Tools", self.panel)
        docks.add("right", "issues", "Issues", self.issues)
        docks.add("right", "overlays", "Overlays", self.overlays)
        from PySide6.QtWidgets import QFrame, QScrollArea
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(self.snapshots)
        docks.add("bottom", "snapshots", "Snapshots", scroll)
        for key in ("palette", "wish", "history"):
            if docks.get(key) is not None:
                docks.get(key).raise_()
        self.meters = MetersBar(self)
        self.window.statusBar().addPermanentWidget(self.meters)
    def _build_actions(self):
        from studio.core import keymap
        controller.register(keymap)
        w = self.window
        mb = w.menuBar()
        menu = mb.addMenu("&Tools")
        lib = next((a for a in mb.actions() if a.text().replace("&", "") in ("Library", "Help")),
                   None)
        if lib is not None:
            mb.insertMenu(lib, menu)
        over = menu.addMenu("Overlays")
        build_menu = menu.addMenu("Build")
        last = None
        for aid, (keys, label, group, tip) in ACTIONS.items():
            a = w.add_action(aid, lambda a=aid: self.run(a), label, keys=keys, group=group)
            a.setCheckable(aid in ("tools.paste_sticky", "tools.reach_ghost", "tools.notes_show"))
            a.setStatusTip(tip)
            target = over if group == "Overlays" else build_menu if group == "Build" else menu
            if target is menu and last is not None and aid.split("_")[0] != last:
                menu.addSeparator()
            last = aid.split("_")[0]
            target.addAction(a)
        w.apply_keys()
        for aid, on in (("tools.paste_sticky", self.state.paste_sticky),
                        ("tools.reach_ghost", self.state.reach_on),
                        ("tools.notes_show", self.state.notes_shown)):
            w.actions[aid].setChecked(on)
    def _hook_views(self):
        self._editor_pick = self.ctx.pick_handler
        self.ctx.pick_handler = self._pick
        self.ctx.cursorMoved.connect(self._cursor)
        self.ctx.gizmoDragged.connect(self._gizmo_dragged)
        self.ctx.painters.append(self._paint)
        for v in self.studio.views.views():
            if hasattr(v, "lmbDrag"):
                try:
                    v.lmbDrag.disconnect(self.ed._box_drag)
                except (RuntimeError, TypeError):
                    pass
                v.lmbDrag.connect(self._drag)
            v.installEventFilter(self)
    def _point(self, p):
        if p is None:
            return None
        return tuple(self.ctx.snap.point(p)) if self.ctx.snap.enabled else tuple(p)
    def _pick(self, hit, mods, view):
        if self.state.active and hit is not None and hit.point is not None:
            pt = tuple(hit.point) if self.state.mode in ("raise", "lower", "paint", "scatter",
                                                         "fill") else self._point(hit.point)
            msg = self.state.click(pt, mods)
            if msg is not None:
                self._after(msg)
                return True
        return self._editor_pick(hit, mods, view)
    def _drag(self, view, start, now, phase):
        if self.state.mode == "room":
            hit = view.pick_at(now)
            pt = self._point(hit.point) if hit is not None and hit.point is not None else None
            msg = self.state.drag(pt, phase)
            if msg:
                self._after(msg)
            self.ctx.redraw()
            return
        if self.state.mode in controller.brushes.KINDS:
            hit = view.pick_at(now)
            if hit is not None and hit.point is not None:
                msg = self.state.drag(tuple(hit.point), phase)
                if msg:
                    self._after(msg)
            elif phase == "end":
                self.state.drag(None, "end")
            return
        if self.state.active:
            return
        self.ed._box_drag(view, start, now, phase)
    def _gizmo_dragged(self, delta, phase):
        if not self.state.symmetry:
            return
        sc = self.ctx.scene
        if phase in ("begin", "drag"):
            pv = sc.selection_pivot()
            ghosts = self.state.twin_preview(self.ed.session.refs(), tuple(delta.offset),
                                             delta.quarters, (pv[0], pv[2]) if pv else None)
            sc.set_ghosts(ghosts)
        elif self.state.diff is None:
            sc.set_ghosts([])
    def _cursor(self, info):
        p = info.get("point")
        if p is not None:
            self.state.move_cursor(self._point(p) if self.state.mode == "paste" else p)
            if self.state.mode == "paste":
                ghost = self.state.paste_ghost()
                self.ctx.scene.set_ghosts([g for g in ghost if "w" in g])
                line = self.state.preview_reach(ghost)
                if line:
                    self.hint(line)
            if self.state.active:
                self.ctx.redraw()
    def eventFilter(self, obj, ev):
        if ev.type() in (QEvent.ShortcutOverride, QEvent.KeyPress) and \
                ev.key() == Qt.Key_Escape and self.state.active:
            ev.accept()
            self.set_mode("select")
            return True
        return False
    def _paint(self, view, p, w, h):
        shown = list(self.state.layers.values())
        from studio.editor import groups
        hidden = groups.hidden_points(self.ed.session.doc) if (
            groups.layers(self.ed.session.doc)) else ()
        for layer in shown + self.state.guides():
            paint.paint_layer(p, view, ovmod.without_points(layer, hidden), w, h)
        if shown:
            paint.paint_legend(p, shown, self.ed.tokens, w, h)
    def hint(self, text):
        if text:
            self.window.hint(text)
    def _after(self, msg):
        self.ed.after_change(msg)
        self.panel.show_state()
        self.ctx.redraw()
    def set_mode(self, mode):
        was = self.state.mode
        self.hint(self.state.set_mode(mode))
        if was == "paste" and mode != "paste":
            self.ctx.scene.set_ghosts([])
        self.panel.show_mode(mode)
        self.ctx.redraw()
    def _hook_build(self):
        paste = self.window.actions.get("edit.paste")
        if paste is not None:
            paste.triggered.connect(lambda *_: self._paste_armed())
        original = getattr(self.ed, "_ghost", None)
        if original is not None:
            def ghost(entry_id):
                original(entry_id)
                line = self.state.preview_reach(self.ctx.scene.ghosts)
                if line:
                    self.hint(line)
            self.ed._ghost = ghost
        clear = getattr(self.ed.sync, "clear_ghost", None)
        if clear is not None:
            def cleared():
                clear()
                if self.state.mode != "paste":
                    self.state.reach = None
            self.ed.sync.clear_ghost = cleared
    def _paste_armed(self):
        msg = self.state.arm_paste()
        if msg:
            self.panel.show_mode(self.state.mode)
            self.hint(msg)
    def ask_note(self):
        from PySide6.QtWidgets import QInputDialog
        from studio.toolbox import build
        doc = self.ed.session.doc
        point = self.state.cursor or self.ed.session.cursor
        near = build.note_near(doc, point)
        text, ok = QInputDialog.getMultiLineText(
            self.window, "Map note", "A note here (saved with the map, never exported; "
            "empty removes it):", near["text"] if near else "")
        if not ok:
            return
        if near is not None and not text.strip():
            self.ed.push(build.remove_note(doc, near["id"]))
            return
        self._after(self.state.note_here(text, point))
    def run(self, aid):
        st = self.state
        if aid == "tools.select":
            return self.set_mode("select")
        if aid in BRUSH_ACTIONS:
            return self.set_mode(BRUSH_ACTIONS[aid])
        if aid in ("tools.ruler", "tools.path"):
            return self.set_mode(aid.split(".")[1])
        if aid == "tools.brush_bigger":
            self.hint(st.brush_size(1))
        elif aid == "tools.brush_smaller":
            self.hint(st.brush_size(-1))
        elif aid == "tools.symmetry":
            self.hint(st.next_symmetry())
        elif aid in ("tools.push_face", "tools.pull_face"):
            self._after(st.push_pull(aid == "tools.push_face"))
        elif aid in ("tools.variant_next", "tools.variant_prev"):
            self._after(st.variant(1 if aid == "tools.variant_next" else -1))
        elif aid == "tools.gradient":
            self._after(st.paint_gradient())
        elif aid == "tools.noise":
            self._after(st.paint_noise())
        elif aid == "tools.second_texture":
            self.hint(st.take_second_texture())
        elif aid == "tools.room":
            return self.set_mode("select" if st.mode == "room" else "room")
        elif aid == "tools.paste_sticky":
            st.paste_sticky = not st.paste_sticky
            self.window.actions[aid].setChecked(st.paste_sticky)
            self.hint("Paste stays armed: %s" % ("on - Esc stops" if st.paste_sticky else "off"))
        elif aid == "tools.reach_ghost":
            st.reach_on = not st.reach_on
            if not st.reach_on:
                st.reach = None
            self.window.actions[aid].setChecked(st.reach_on)
            self.hint("Mario's reach on the ghost: %s" % ("on" if st.reach_on else "off"))
        elif aid == "tools.note":
            self.ask_note()
        elif aid == "tools.notes_show":
            st.notes_shown = not st.notes_shown
            self.window.actions[aid].setChecked(st.notes_shown)
        elif aid == "tools.symmetry_centre":
            self.hint(st.centre_symmetry())
        elif aid == "tools.dress":
            self._after(st.dress())
        elif aid == "tools.fill_region":
            self._after(st.fill_region())
        elif aid == "tools.autoshape":
            self._after(st.autoshape())
        elif aid == "tools.region":
            return self.regenerate_region()
        elif aid == "tools.snapshot":
            self.snapshots.take()
        elif aid == "tools.compare":
            self.snapshots.compare()
        elif aid in ("tools.issue_next", "tools.issue_prev"):
            self.issues.step(1 if aid == "tools.issue_next" else -1)
        elif aid in OVERLAY_ACTIONS:
            key = OVERLAY_ACTIONS[aid]
            self.toggle_layer(key, key not in self.wanted)
        elif aid == "tools.overlay_clear":
            for key in list(self.wanted):
                self.toggle_layer(key, False)
        self.panel.show_state()
        self.ctx.redraw()
        return None
    def _state_event(self, event, payload):
        if event == "status":
            self.hint(payload)
        elif event == "diff":
            self._show_diff(payload)
        elif event == "guides":
            self._save_symmetry()
            self.ctx.redraw()
    def _session_event(self, event, payload):
        if event == "document":
            self.state.clear_compare()
            self._load_symmetry(payload)
            self.snapshots.refresh()
            self.issues.critic = None
            self.issues.show(None)
            self._edited()
    def _doc_changed(self):
        self._meter_timer.start()
        self._edited()
        if self.state.diff is not None:
            self.state.compare(self.state.compare_index)
    def _hook_report(self):
        rp = self.ed.report_panel
        original = rp.show_result
        def show_result(res):
            original(res)
            self.issues.show(res)
        rp.show_result = show_result
    def _load_symmetry(self, doc):
        from studio.toolbox.symmetry import Symmetry
        sym = Symmetry.from_state(doc.meta.get("symmetry"))
        self.state.symmetry = sym
        self.panel.show_state()
    def _save_symmetry(self):
        doc = self.ed.session.doc
        if self.state.symmetry:
            doc.meta["symmetry"] = self.state.symmetry.state()
        else:
            doc.meta.pop("symmetry", None)
        self.panel.show_state()
    def toggle_layer(self, key, on):
        if on:
            if key not in self.wanted:
                self.wanted.append(key)
            self._compute([key])
        else:
            if key in self.wanted:
                self.wanted.remove(key)
            self.stale.discard(key)
            self.state.hide_layer(key)
            self.overlays.show_layer(key, None)
        self.ctx.redraw()
    def _apply_settings(self):
        s = self.studio.settings
        try:
            self._overlay_timer.setInterval(int(s.get("tools.overlay_idle_ms")))
            self.state.snapshot_cap = int(s.get("tools.snapshot_cap"))
        except KeyError:
            pass
    def _edited(self):
        again, stale = ovmod.after_edit(self.wanted)
        for key in stale:
            if key not in self.stale:
                self.stale.add(key)
                self.overlays.mark_stale(key)
        if again:
            self._overlay_timer.start()
    def refresh_after_edit(self):
        again, _ = ovmod.after_edit(self.wanted)
        if again:
            self._compute(again)
    def refresh_layers(self):
        if self.wanted:
            self.stale.clear()
            self._compute(list(self.wanted))
    def _compute(self, keys):
        if self.overlay_jobs.busy():
            self._overlay_timer.start()
            return
        layout = self.ed.session.doc.to_layout()
        eye = self.state.eye()
        st = self.state
        def job(progress, cancelled):
            out = []
            for n, key in enumerate(keys):
                progress(n, len(keys), "measuring %s" % key)
                out.append((key, st.compute_layer(key, layout, eye)))
            return out
        def done(got):
            self.overlays.busy.setVisible(False)
            for key, layer in got:
                if key in self.wanted:
                    st.show_layer(layer)
                    self.overlays.show_layer(key, layer)
            self.ctx.redraw()
        def failed(reason):
            self.overlays.busy.setVisible(False)
            self.hint("Overlay: %s" % reason.splitlines()[0])
        self.overlays.busy.setVisible(True)
        self.overlay_jobs.run("Overlays", job, done, failed)
    def _show_diff(self, diff):
        sc = self.ctx.scene
        doc = self.ed.session.doc
        for name in ("snap_added", "snap_changed"):
            sc.clear_highlight(name)
        if diff is None:
            sc.set_ghosts([])
            return
        def ids(refs):
            return set(doc.index_of(r) for r in refs if r[0] == "piece" and r in doc)
        added, changed = ids(diff.added), ids(diff.moved + diff.changed)
        if added:
            sc.set_highlight("snap_added", added, (0.36, 0.78, 0.47))
        if changed:
            sc.set_highlight("snap_changed", changed, (0.96, 0.69, 0.25))
        sc.set_ghosts([p for p in diff.removed + diff.moved_from if "w" in p])
    def show_issue(self, iss):
        doc = self.ed.session.doc
        refs = [r for r in iss.refs if r in doc]
        if refs:
            self.ed.session.selection.set(refs)
        b = iss.bounds(doc)
        if b is None:
            self.hint(iss.text)
            return
        view = self.studio.views.active.view
        cam = view.camera.copy()
        cam.frame((b[0], b[2], b[4]), (b[1], b[3], b[5]),
                  view.width() / float(max(1, view.height())), margin=1.8)
        view.set_camera(cam, animate=True)
        self.hint(iss.text)
    def fix(self, iss, key):
        doc = self.ed.session.doc
        try:
            got = issmod.fix(doc, iss, key, texture=self.ed.session.texture)
        except Exception as exc:
            self.hint("The fix failed: %s" % exc)
            return
        if isinstance(got, tuple):
            what, text = got
            if what == "critic":
                return self._critic_fix(text, iss)
            if what == "refine":
                self.ed.wish_panel.refine_text.setText(text or "")
                self.ed.refine()
            elif what == "dress":
                self._after(self.state.dress([]))
            return
        if not got:
            self.hint(got.label)
            return
        self.ed.push(got)
        self.ed.measure(full=False, quiet=True)
    def _critic_fix(self, row, iss=None):
        from studio.editor import criticfix
        doc = self.ed.session.doc
        label = (iss.data.get("label") if iss is not None else None) or row
        try:
            pv = criticfix.preview(doc, row)
        except Exception as exc:
            self.hint("The fix failed: %s" % exc)
            return None
        if pv is None:
            self.hint("%s: nothing the critic can mend by itself right now - Show me, then "
                      "change it by hand" % label)
            return None
        change = criticfix.change_for(doc, pv)
        self.ed.push(change)
        touched = criticfix.refs(self.ed.session.doc, pv, after=True)
        if touched:
            self.ed.session.selection.set([r for r in touched if r in self.ed.session.doc])
        self.hint("Fixed: %s (%s) - Ctrl+Z takes it back"
                  % (pv.get("label") or label, preview_score(pv)))
        self.ed.measure(full=False, quiet=True)
        return pv
    def regenerate_region(self):
        doc = self.ed.session.doc
        refs = self.ed.session.refs()
        box = region.box_of(doc, refs)
        if box is None:
            self.hint("Box-select the area to build again first (drag in a view)")
            return
        if self.ed.jobs.busy():
            self.hint("The engine is still working - wait, or Cancel")
            return
        brief, layout = dict(doc.brief), doc.to_layout()
        def job(progress, cancelled):
            from studio.editor import engine
            if not brief:
                raise engine.EngineError("this map has no wish yet - generate it from a wish "
                                         "first (the region is built from the same wish)")
            return engine.regenerate_region(brief, layout, box, progress=progress,
                                            cancel=cancelled)
        def done(res):
            new, notes = res
            ch = region.change(self.ed.session.doc, new)
            self.ed.push(ch)
            self.hint("; ".join(notes))
            self.ed.measure(full=False, quiet=True)
        self.ed.jobs.run("Regenerating %d x %d cells" % ((box[1] - box[0]) // 200,
                                                        (box[3] - box[2]) // 200), job, done,
                         lambda reason: self.hint("Region: %s" % reason))
    def update_meters(self):
        doc = self.ed.session.doc
        try:
            rep = meters.report(doc.to_layout(), doc.brief)
        except Exception as exc:
            self.meters.setToolTip("meters: %s" % exc)
            return None
        self.meters.show_report(rep)
        self.last_meters = rep
        return rep
    def update_meters_later(self):
        if self.meter_jobs.busy():
            self._meters_again = True
            return False
        self._meters_again = False
        doc = self.ed.session.doc
        try:
            layout, brief = doc.to_layout(), dict(doc.brief or {})
        except Exception as exc:
            self.meters.setToolTip("meters: %s" % exc)
            return False
        def job(_progress, _cancelled):
            from studio.editor import childcall
            return childcall.call("studio.toolbox.meters:report", layout, brief)
        def done(rep):
            self.meters.show_report(rep)
            self.last_meters = rep
            if self._meters_again:
                self._meter_timer.start()
        def failed(reason):
            self.meters.setToolTip("meters: %s" % reason)
            if self._meters_again:
                self._meter_timer.start()
        return self.meter_jobs.run("Meters", job, done, failed)
def install(studio):
    tools = Tools(studio)
    studio.tools = tools
    try:
        from studio.library.qt import polish
        QTimer.singleShot(0, lambda: polish.tooltips(studio.window))
    except Exception:
        pass
    return tools
