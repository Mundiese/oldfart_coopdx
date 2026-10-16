import math
import time
from PySide6.QtCore import QEvent, QPointF, QRectF, Qt, QTimer, QVariantAnimation, Signal
from PySide6.QtGui import QColor, QFont, QInputDevice, QPainter, QPainterPath, QPen, QPolygonF
from PySide6.QtOpenGLWidgets import QOpenGLWidget
from ..core import camera as cam_mod
from ..core import picking, snap as snap_mod, vec
from ..core.scene import Preview
from . import renderer as rmod
DRAG_PX = 4
FLY_KEYS = {Qt.Key_W: (0, 0, 1), Qt.Key_S: (0, 0, -1), Qt.Key_A: (-1, 0, 0),
            Qt.Key_D: (1, 0, 0), Qt.Key_E: (0, 1, 0), Qt.Key_Q: (0, -1, 0),
            Qt.Key_Up: (0, 0, 1), Qt.Key_Down: (0, 0, -1), Qt.Key_Left: (-1, 0, 0),
            Qt.Key_Right: (1, 0, 0), Qt.Key_PageUp: (0, 1, 0), Qt.Key_PageDown: (0, -1, 0)}
FLY_LOOK = 0.25
FLY_TICK_MS = 16
NAV_BALL_R = 46
NAV_DOT_R = 9
def _mods(ev):
    m = ev.modifiers()
    return {"shift": bool(m & Qt.ShiftModifier), "ctrl": bool(m & Qt.ControlModifier),
            "alt": bool(m & Qt.AltModifier)}
class Viewport(QOpenGLWidget):
    cameraChanged = Signal(object)
    activated = Signal(object)
    lmbDrag = Signal(object, object, object, str)
    frameTimed = Signal(float)
    contextMenu = Signal(object, object, object)
    middleClicked = Signal(object, object)
    def __init__(self, ctx, side="user", parent=None):
        super().__init__(parent)
        self.ctx = ctx
        s = ctx.settings
        self.camera = cam_mod.Camera(fov=s["nav.fov"])
        if side != "user":
            self.camera.set_side(side)
        self.renderer = None
        self.gl_error = None
        self._nav = None
        self._press = None
        self._lmb_dragging = False
        self._gizmo = None
        self._sun = None
        self._gizmo_hover = None
        self._nav_hover = None
        self._was_persp = True
        self._mouse = None
        self._hover_pending = False
        self._anim = None
        self._last_delta = None
        self._fly = None
        self._fly_timer = QTimer(self)
        self._fly_timer.setInterval(FLY_TICK_MS)
        self._fly_timer.timeout.connect(self._fly_tick)
        from ..core import bakeview as _bakeview
        self._flame_timer = QTimer(self)
        self._flame_timer.setInterval(int(1000 / _bakeview.FLAME_FPS))
        self._flame_timer.timeout.connect(self._flame_tick)
        self._nav_start = None
        self.frame_ms = 0.0
        self.active = False
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setMinimumSize(120, 90)
        ctx.views.append(self)
        self.destroyed.connect(lambda *_: ctx.views.remove(self) if self in ctx.views else None)
    def initializeGL(self):
        try:
            self.renderer = rmod.Renderer(self.ctx.cache, self.ctx.registry)
            self.renderer.init(self.ctx.settings["view.filter"])
        except Exception as exc:
            self.renderer = None
            self.gl_error = "OpenGL 3.3 is not available here: %s" % exc
            self.ctx.status.emit(self.gl_error)
    def resizeGL(self, w, h):
        pass
    def options(self):
        s, t = self.ctx.settings, self.ctx.tokens
        sc = self.ctx.scene
        b = sc.bounds()
        meta = rmod.with_sun(sc.meta, self.ctx.sun_preview)
        shown = getattr(self.ctx, "mood_shown", True)
        if shown:
            meta = rmod.with_mood(meta)
        bg = rmod.theme.rgbf(t["viewport"])
        mood = rmod.mood_of(meta, bg, shown)
        self._mood = mood
        if mood["fog"] > 0 or mood["multiply"] != (1.0, 1.0, 1.0):
            bg = tuple(min(1.0, (b + (fc - b) * mood["fog"] * 0.7) * mm)
                       for b, fc, mm in zip(bg, mood["fog_colour"], mood["multiply"]))
        hov = sc.hover if isinstance(sc.hover, int) else -2.0
        upp = self.camera.units_per_pixel(self.camera.target, max(1, self.height()))
        minor, major = snap_mod.grid_levels(upp, self.ctx.snap.step)
        return {
            "background": bg,
            "mood": rmod.mood_uniforms(mood),
            "accent": rmod.theme.rgbf(t["accent"]),
            "shading": s["view.shading"], "edges": s["view.edges"], "grid": s["view.grid"],
            "markers": s["view.markers"], "fog": s["view.fog"],
            "light": rmod.light_of(meta, s["view.light_from_venue"]),
            "game_light": rmod.game_light_of(meta),
            "bake": rmod.bake_of(meta),
            "hover": float(hov),
            "height": (b[0][1], b[1][1]) if b else (0.0, 1000.0),
            "radius": sc.radius(),
            "grid_plane": rmod.grid_plane(self.camera, s["grid.height"]),
            "grid_spacing": (minor, major),
            "grid_colour": (0.62, 0.65, 0.70),
            "axis_colours": rmod.axis_colours(t),
            "ghost_tint": getattr(sc, "ghost_tint", None),
            "baked_mesh": None if sc.preview is not None else getattr(self.ctx, "baked_mesh",
                                                                      None),
        }
    def paintGL(self):
        t = time.perf_counter()
        if self.renderer is not None and self.renderer.ready:
            try:
                self.renderer.draw(self.camera, self._fb_w(), self._fb_h(), self.options())
            except Exception as exc:
                self.renderer = None
                self.gl_error = "drawing failed: %s" % exc
                self.ctx.status.emit(self.gl_error)
        self.frame_ms = (time.perf_counter() - t) * 1000.0
        self.flames_watch()
        self._overlay()
        self.frameTimed.emit(self.frame_ms)
    def flames_burning(self):
        if self.ctx.settings["view.shading"] != "baked" or self.ctx.scene.preview is not None:
            return False
        m = getattr(self.ctx, "baked_mesh", None)
        return m is not None and bool(getattr(m, "flames", None))
    def flames_watch(self):
        if self.flames_burning() and not self._flame_timer.isActive():
            self._flame_timer.start()
    def _flame_tick(self):
        if self.flames_burning() and self.isVisible():
            self.update()
        else:
            self._flame_timer.stop()
    def _fb_w(self):
        return int(self.width() * self.devicePixelRatioF())
    def _fb_h(self):
        return int(self.height() * self.devicePixelRatioF())
    def set_camera(self, cam, animate=False):
        if self._anim is not None:
            self._anim.stop()
            self._anim = None
        s = self.ctx.settings
        ms = s["nav.smooth_ms"]
        if animate and s["nav.smooth_views"] and not s["ui.reduce_motion"] and ms > 0:
            start = self.camera.copy()
            anim = QVariantAnimation(self)
            anim.setStartValue(0.0)
            anim.setEndValue(1.0)
            anim.setDuration(ms)
            def step(v, start=start, end=cam):
                self.camera = cam_mod.blend(start, end, vec.ease(float(v)))
                self.update()
                self.cameraChanged.emit(self)
            def done(end=cam):
                self.camera = end.copy()
                self._anim = None
                self.update()
                self.cameraChanged.emit(self)
            anim.valueChanged.connect(step)
            anim.finished.connect(done)
            self._anim = anim
            anim.start()
            return
        self.camera = cam.copy()
        self.update()
        self.cameraChanged.emit(self)
    def view_side(self, side):
        cam = self.camera.copy()
        if not cam.ortho:
            self._was_persp = True
        cam.set_side(side, ortho=True if self.ctx.settings["nav.auto_perspective"] else None)
        self.set_camera(cam, animate=True)
    def numpad(self, key):
        if key == ".":
            return self.frame_selected()
        cam = self.camera.copy()
        if cam.side == "user" and not cam.ortho:
            self._was_persp = True
        elif key == "5":
            self._was_persp = cam.ortho
        cam_mod.apply_numpad(cam, key, self.ctx.settings["nav.numpad_step"],
                             self.ctx.settings["nav.auto_perspective"], self._was_persp)
        self.set_camera(cam, animate=key not in ("+", "-"))
    def frame_all(self, animate=True):
        b = self.ctx.scene.bounds()
        if b is None:
            return
        cam = self.camera.copy()
        cam.frame(b[0], b[1], self.width() / float(max(1, self.height())), margin=1.05)
        self.set_camera(cam, animate)
    def frame_selected(self):
        sc = self.ctx.scene
        if not sc.selection and not sc.marker_selection:
            return self.frame_all()
        b = sc.bounds(sc.selection) if sc.selection else None
        for i in sc.marker_selection:
            m = sc.markers[i]
            lo, hi = (m.x - 200, m.y, m.z - 200), (m.x + 200, m.y + 200, m.z + 200)
            b = (lo, hi) if b is None else (tuple(map(min, b[0], lo)), tuple(map(max, b[1], hi)))
        cam = self.camera.copy()
        cam.frame(b[0], b[1], self.width() / float(max(1, self.height())), margin=1.6)
        self.set_camera(cam, animate=True)
    def ray_at(self, pos):
        return self.camera.ray(pos.x(), pos.y(), max(1, self.width()), max(1, self.height()),
                               self.ctx.scene.radius())
    def pick_at(self, pos, plane=True, outlines=True):
        o, d = self.ray_at(pos)
        gp = rmod.grid_plane(self.camera, self.ctx.settings["grid.height"]) if plane else None
        if gp and getattr(self.ctx, "plane_only", False):
            t = picking.ray_plane(o, d, gp[0], gp[1])
            if t is not None:
                return picking.Hit("plane", None, vec.add(o, vec.mul(d, t)), gp[1], t)
        upp = self.camera.units_per_pixel(self.camera.target, max(1, self.height()))
        return picking.pick(self.ctx.scene, o, d, marker_radius=max(90.0, 10 * upp),
                            plane=(gp[0], gp[1]) if gp else None,
                            markers=self.ctx.settings["view.markers"], outlines=outlines)
    def _hover_now(self):
        self._hover_pending = False
        if self._mouse is None or self._nav or self._gizmo or self._sun:
            return
        hit = self.pick_at(self._mouse)
        sc = self.ctx.scene
        if hit.kind == "piece":
            sc.set_hover(hit.index)
        elif hit.kind == "marker":
            sc.set_hover(("marker", hit.index))
        else:
            sc.set_hover(None)
        info = {"view": self, "kind": hit.kind, "index": hit.index, "point": hit.point}
        if hit.point is not None:
            info["snapped"] = self.ctx.snap.point(hit.point)
            info["cell"] = self.ctx.snap.cell(hit.point)
        self.ctx.cursorMoved.emit(info)
        g = self.ctx.gizmo()
        self._gizmo_hover = (g.hit(self._mouse.x(), self._mouse.y(), self.camera, self.width(),
                                   self.height()) if g else None)
        side = self._nav_ball_hit(self._mouse)
        self._nav_hover = side if side != "ball" else None
        self.update()
    def _is_nav(self, ev):
        if ev.buttons() & Qt.MiddleButton or ev.button() == Qt.MiddleButton:
            return True
        return (self.ctx.settings["nav.emulate_3button"] and (ev.modifiers() & Qt.AltModifier)
                and (ev.button() == Qt.LeftButton or ev.buttons() & Qt.LeftButton))
    def mousePressEvent(self, ev):
        self.activated.emit(self)
        pos = ev.position()
        if self._is_nav(ev):
            m = _mods(ev)
            if m["ctrl"] and m["shift"]:
                mode = "dolly"
            elif m["ctrl"]:
                mode = "zoom"
            elif m["shift"]:
                mode = "pan"
            else:
                mode = "orbit"
            self._start_nav(mode, pos)
            return
        if ev.button() == Qt.RightButton:
            self._press = (pos, "right", _mods(ev), None)
            return
        if ev.button() == Qt.LeftButton:
            side = self._nav_ball_hit(pos)
            if side == "ball":
                self._start_nav("orbit", pos)
                return
            if side is not None:
                self._press = (pos, "navball", _mods(ev), side)
                return
            sun = self.ctx.sun_gizmo()
            if sun is not None and sun.hit(pos.x(), pos.y(), self.camera, self.width(),
                                           self.height()):
                self._sun = sun
                self.setCursor(Qt.ClosedHandCursor)
                return
            g = self.ctx.gizmo()
            if g is not None:
                name = g.hit(pos.x(), pos.y(), self.camera, self.width(), self.height())
                if name and g.begin(name, *self.ray_at(pos)):
                    self._gizmo = g
                    self.ctx.gizmoDragged.emit(gizmo_math_delta(), "begin")
                    return
            self._press = (pos, "left", _mods(ev), None)
            self._lmb_dragging = False
    def _start_nav(self, mode, pos):
        if self._anim is not None:
            self._anim.stop()
            self._anim = None
        if mode == "orbit" and self.ctx.settings["nav.orbit_around_selection"]:
            piv = self.ctx.scene.selection_pivot()
            if piv is not None:
                eye = self.camera.eye()
                self.camera.target = piv
                d = vec.sub(eye, piv)
                self.camera.distance = max(50.0, vec.length(d))
                dn = vec.norm(d)
                self.camera.pitch = math.degrees(math.asin(max(-1.0, min(1.0, dn[1]))))
                self.camera.yaw = math.degrees(math.atan2(dn[0], dn[2])) % 360.0
        self._nav = (mode, pos)
        self._nav_start = pos
        self.setCursor(Qt.ClosedHandCursor if mode != "zoom" else Qt.SizeVerCursor)
    def mouseMoveEvent(self, ev):
        pos = ev.position()
        self._mouse = pos
        if self._fly is not None:
            last = self._fly["pos"]
            self._fly["pos"] = pos
            self.camera.fly_look((pos.x() - last.x()) * FLY_LOOK, (pos.y() - last.y()) * FLY_LOOK)
            self.update()
            self.cameraChanged.emit(self)
            return
        if self._nav is not None:
            mode, last = self._nav
            dx, dy = pos.x() - last.x(), pos.y() - last.y()
            self._nav = (mode, pos)
            self._navigate(mode, dx, dy)
            return
        if self._sun is not None:
            self.ctx.set_sun_preview(self._sun.drag(*self.ray_at(pos)))
            return
        if self._gizmo is not None:
            delta = self._gizmo.drag(*self.ray_at(pos), snap=self.ctx.snap,
                                     ctrl=bool(ev.modifiers() & Qt.ControlModifier))
            sc = self.ctx.scene
            piv = self._gizmo.centre
            sc.set_preview(Preview(sc.selection, delta.offset, delta.quarters, (piv[0], piv[2])))
            self.ctx.gizmoDragged.emit(delta, "drag")
            self._last_delta = delta
            return
        if self._press is not None:
            start, kind, mods, extra = self._press
            if kind == "navball":
                if (pos - start).manhattanLength() > DRAG_PX:
                    self._press = None
                    self._start_nav("orbit", pos)
                return
            if kind == "right":
                if (pos - start).manhattanLength() > DRAG_PX:
                    self._press = None
                    how = self.ctx.settings["nav.right_drag"]
                    if how == "fly" and not self.camera.ortho:
                        self.start_fly(pos)
                    elif how != "off":
                        self._start_nav("pan", pos)
                return
            if kind == "left":
                if not self._lmb_dragging and (pos - start).manhattanLength() > DRAG_PX:
                    self._lmb_dragging = True
                    self.lmbDrag.emit(self, start, pos, "begin")
                elif self._lmb_dragging:
                    self.lmbDrag.emit(self, start, pos, "drag")
                return
        if not self._hover_pending:
            self._hover_pending = True
            QTimer.singleShot(0, self, self._hover_now)
    def _navigate(self, mode, dx, dy):
        s = self.ctx.settings
        cam = self.camera
        if mode == "orbit":
            k = s["nav.orbit_speed"]
            sign = -1.0 if s["nav.invert_orbit_y"] else 1.0
            was_side = cam.side != "user"
            cam.orbit(-dx * k, dy * k * sign)
            if was_side and cam.ortho and s["nav.auto_perspective"] and self._was_persp:
                cam.set_ortho(False)
        elif mode == "pan":
            cam.pan_pixels(dx, dy, max(1, self.height()))
        elif mode == "zoom":
            cam.zoom(-dy / 40.0, s["nav.zoom_factor"])
        elif mode == "dolly":
            cam.dolly(-dy * cam.units_per_pixel(cam.target, max(1, self.height())) * 4.0)
        self.update()
        self.cameraChanged.emit(self)
    def mouseReleaseEvent(self, ev):
        pos = ev.position()
        if self._fly is not None and ev.button() == Qt.RightButton:
            self.end_fly()
            return
        if self._nav is not None and not (ev.buttons() & (Qt.MiddleButton | Qt.LeftButton
                                                         | Qt.RightButton)):
            mode, start = self._nav[0], self._nav_start
            self._nav = None
            self.unsetCursor()
            if (ev.button() == Qt.MiddleButton and mode == "orbit" and start is not None
                    and (pos - start).manhattanLength() <= DRAG_PX):
                self.middleClicked.emit(self, self.pick_at(pos, plane=False))
            return
        if self._sun is not None:
            self._finish_sun(cancel=False)
            return
        if self._gizmo is not None:
            self._finish_gizmo(cancel=False)
            return
        if self._press is not None:
            start, kind, mods, extra = self._press
            self._press = None
            if kind == "navball":
                self.view_side(extra)
                return
            if kind == "right":
                self.contextMenu.emit(self, self.pick_at(pos, plane=True),
                                      self.mapToGlobal(pos.toPoint()))
                return
            if kind == "left":
                if self._lmb_dragging:
                    self._lmb_dragging = False
                    self.lmbDrag.emit(self, start, pos, "end")
                    return
                hit = self.pick_at(pos, plane=False)
                self.ctx.picked.emit(hit, mods, self)
                if self.ctx.pick_handler is not None:
                    self.ctx.pick_handler(hit, mods, self)
    def _finish_sun(self, cancel):
        g, self._sun = self._sun, None
        self.unsetCursor()
        tool = self.ctx.sun_tool
        if not cancel and g is not None and tool is not None:
            tool.commit(dict(g.sun))
        self.ctx.set_sun_preview(None)
    def _finish_gizmo(self, cancel):
        g, self._gizmo = self._gizmo, None
        delta = getattr(self, "_last_delta", None) or gizmo_math_delta()
        self._last_delta = None
        g.end()
        self.unsetCursor()
        sc = self.ctx.scene
        applied = False
        if not cancel and not delta.is_zero() and self.ctx.gizmo_handler is not None:
            applied = bool(self.ctx.gizmo_handler(delta, sc.selection))
        sc.set_preview(None)
        self.ctx.gizmoDragged.emit(delta, "cancel" if cancel else "end")
        if not cancel and not applied and not delta.is_zero():
            self.ctx.status.emit("Read only: the move is shown, not applied (the editor applies it).")
    def wheelEvent(self, ev):
        s = self.ctx.settings
        if self._fly is not None:
            notches = ev.angleDelta().y() / 120.0
            if notches:
                self._fly["speed"] = max(50.0, min(50000.0, self._fly["speed"]
                                                   * (1.2 ** notches)))
                self.ctx.status.emit("Fly speed %d units a second" % self._fly["speed"])
            return
        if (s["nav.trackpad_pans"] and is_touchpad(ev)
                and not (ev.modifiers() & Qt.ControlModifier)):
            d = ev.pixelDelta()
            if d.isNull():
                d = ev.angleDelta() / 8
            self.camera.pan_pixels(d.x(), d.y(), max(1, self.height()))
            self.update()
            self.cameraChanged.emit(self)
            return
        steps = ev.angleDelta().y() / 120.0
        if not steps:
            return
        if s["nav.invert_zoom"]:
            steps = -steps
        anchor = None
        if s["nav.zoom_to_mouse"]:
            hit = self.pick_at(ev.position())
            anchor = hit.point if hit else None
        self.camera.zoom(steps, s["nav.zoom_factor"], anchor=anchor)
        self.update()
        self.cameraChanged.emit(self)
    def cancel_drag(self):
        if self._sun is not None:
            self._finish_sun(cancel=True)
            return True
        if self._gizmo is not None:
            self._finish_gizmo(cancel=True)
            return True
        return False
    def event(self, ev):
        if ev.type() == QEvent.ShortcutOverride and self._fly is not None \
                and ev.key() in FLY_KEYS:
            ev.accept()
            return True
        return super().event(ev)
    def keyPressEvent(self, ev):
        if self._fly is not None and ev.key() in FLY_KEYS:
            if not ev.isAutoRepeat():
                self._fly["keys"].add(ev.key())
            return
        if ev.key() == Qt.Key_Escape and self._sun is not None:
            self._finish_sun(cancel=True)
            return
        if ev.key() == Qt.Key_Escape and self._gizmo is not None:
            self._finish_gizmo(cancel=True)
            return
        super().keyPressEvent(ev)
    def keyReleaseEvent(self, ev):
        if self._fly is not None and ev.key() in FLY_KEYS:
            if not ev.isAutoRepeat():
                self._fly["keys"].discard(ev.key())
            return
        super().keyReleaseEvent(ev)
    def mouseDoubleClickEvent(self, ev):
        if ev.button() == Qt.LeftButton:
            hit = self.pick_at(ev.position(), plane=False)
            if hit:
                self._press = None
                self.frame_selected()
                return
        self.mousePressEvent(ev)
    def start_fly(self, pos):
        if self._anim is not None:
            self._anim.stop()
            self._anim = None
        self._fly = {"keys": set(), "speed": float(self.ctx.settings["nav.fly_speed"]),
                     "t": time.monotonic(), "pos": pos}
        self.setFocus()
        self.setCursor(Qt.BlankCursor)
        self._fly_timer.start()
        self.ctx.status.emit("Flying: W A S D, Q/E down/up, Shift faster, the wheel sets "
                             "the speed - let go of the right button to stop")
    def end_fly(self):
        if self._fly is None:
            return
        self._fly = None
        self._fly_timer.stop()
        self.unsetCursor()
    def fly_step(self, dt, keys=None, mods=None):
        if self._fly is None:
            return 0.0
        keys = self._fly["keys"] if keys is None else keys
        if not keys:
            return 0.0
        from PySide6.QtWidgets import QApplication
        mods = QApplication.keyboardModifiers() if mods is None else mods
        speed = self._fly["speed"] * (3.0 if mods & Qt.ShiftModifier else 1.0) \
            * (0.25 if mods & Qt.ControlModifier else 1.0)
        r = u = f = 0.0
        for k in keys:
            dr, du, df = FLY_KEYS.get(k, (0, 0, 0))
            r, u, f = r + dr, u + du, f + df
        n = math.sqrt(r * r + u * u + f * f) or 1.0
        step = speed * dt / n
        self.camera.fly_move(r * step, u * step, f * step)
        self.update()
        self.cameraChanged.emit(self)
        return step * n
    def _fly_tick(self):
        if self._fly is None:
            self._fly_timer.stop()
            return
        now = time.monotonic()
        dt = min(0.1, now - self._fly["t"])
        self._fly["t"] = now
        self.fly_step(dt)
    def enterEvent(self, ev):
        self.activated.emit(self)
        super().enterEvent(ev)
    def leaveEvent(self, ev):
        self._mouse = None
        self._nav_hover = None
        if isinstance(self.ctx.scene.hover, int) or self.ctx.scene.hover:
            self.ctx.scene.set_hover(None)
        self.update()
        super().leaveEvent(ev)
    def _nav_centre(self):
        return QPointF(self.width() - NAV_BALL_R - 14, NAV_BALL_R + 14)
    def _nav_dots(self):
        right, up, forward = self.camera.basis()
        c = self._nav_centre()
        r = NAV_BALL_R - NAV_DOT_R
        out = []
        for axis, label, pos_side, neg_side in (((1, 0, 0), "X", "right", "left"),
                                                ((0, 1, 0), "Y", "top", "bottom"),
                                                ((0, 0, 1), "Z", "front", "back")):
            for sign, side in ((1, pos_side), (-1, neg_side)):
                a = vec.mul(axis, sign)
                p = QPointF(c.x() + vec.dot(a, right) * r, c.y() - vec.dot(a, up) * r)
                out.append((side, label, sign > 0, p, vec.dot(a, forward)))
        out.sort(key=lambda d: -d[4])
        return out
    def _nav_ball_hit(self, pos):
        if not self.ctx.settings["view.axes"]:
            return None
        best = None
        for side, _, _, p, depth in reversed(self._nav_dots()):
            if (pos - p).manhattanLength() <= NAV_DOT_R * 1.5:
                best = side
                break
        if best is None and (pos - self._nav_centre()).manhattanLength() <= NAV_BALL_R:
            return "ball"
        return best
    def _overlay(self):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        t = self.ctx.tokens
        w, h = self.width(), self.height()
        font = QFont(self.font())
        font.setPointSizeF(max(8.0, font.pointSizeF()))
        p.setFont(font)
        label = self.camera.label()
        upp = self.camera.units_per_pixel(self.camera.target, max(1, h))
        minor, _ = snap_mod.grid_levels(upp, self.ctx.snap.step)
        self._text(p, 12, 20, label, QColor(t["text"]), bold=True)
        self._text(p, 12, 38, "grid %d" % minor, QColor(t["text_dim"]))
        if self.gl_error:
            self._text(p, 12, 62, self.gl_error, QColor(t["bad"]))
        sc = self.ctx.scene
        mood = getattr(self, "_mood", None)
        if mood is not None and mood.get("particles") and sc.pieces:
            from . import weatherfx
            weatherfx.paint(p, mood["particles"], w, h)
        if not sc.pieces and not sc.markers and not self._start_screen_up():
            self._empty_state(p, w, h, t)
        if self.ctx.settings["view.axes"]:
            self._nav_ball(p, t)
        g = self.ctx.gizmo() if self._gizmo is None else self._gizmo
        if g is not None:
            self._draw_gizmo(p, g, t)
        sun = self._sun or self.ctx.sun_gizmo()
        if sun is not None:
            self._draw_sun(p, sun, t)
        for fn in list(getattr(self.ctx, "painters", ())):
            try:
                p.save()
                fn(self, p, w, h)
            except Exception as exc:
                self.ctx.status.emit("overlay failed: %s" % exc)
            finally:
                p.restore()
        self._hover_chip(p, t, w, h)
        self._toast_chip(p, t, w, h)
        if self.ctx.settings["view.show_fps"]:
            txt = rmod.fps_text(self.frame_ms)
            if self.renderer is not None:
                st = self.renderer.stats
                txt += "   %d draws  %dk tris" % (st.get("draws", 0), st.get("triangles", 0) // 1000)
            self._text(p, w - p.fontMetrics().horizontalAdvance(txt) - 12, h - 12, txt,
                       QColor(t["text_dim"]))
        if self.active and len([v for v in self.ctx.views if v.isVisible()]) > 1:
            pen = QPen(QColor(t["accent"]))
            pen.setWidthF(1.5)
            p.setPen(pen)
            p.setBrush(Qt.NoBrush)
            p.drawRect(QRectF(0.75, 0.75, w - 1.5, h - 1.5))
        p.end()
    def _draw_sun(self, p, sun, t):
        from ..core import sungizmo
        w, h = self.width(), self.height()
        at = sun.screen(self.camera, w, h)
        base = self.camera.to_pixel(sun.centre, w, h)
        if at is None:
            return
        col = sun.sun["colour"]
        disc = QColor.fromRgbF(min(1.0, 0.55 + 0.45 * col[0]), min(1.0, 0.45 + 0.45 * col[1]),
                               min(1.0, 0.15 + 0.4 * col[2]))
        x, y = at
        if base is not None:
            pen = QPen(QColor(255, 214, 90, 150), 1.5, Qt.DashLine)
            p.setPen(pen)
            p.drawLine(QPointF(x, y), QPointF(base[0], base[1]))
        live = self._sun is not None
        r = sungizmo.HIT_PX * (0.8 if live else 0.65)
        p.setPen(QPen(disc, 2.0))
        for k in range(8):
            a = k * math.pi / 4.0
            p.drawLine(QPointF(x + math.cos(a) * (r + 3), y + math.sin(a) * (r + 3)),
                       QPointF(x + math.cos(a) * (r + 8), y + math.sin(a) * (r + 8)))
        p.setPen(QPen(QColor(90, 60, 10), 1.5))
        p.setBrush(disc)
        p.drawEllipse(QPointF(x, y), r, r)
        p.setBrush(Qt.NoBrush)
        if live:
            self._text(p, x + r + 12, y + 4, sungizmo.label(sun.sun), QColor(t["text"]), bold=True)
    def _text(self, p, x, y, s, colour, bold=False):
        f = p.font()
        f.setBold(bold)
        p.setFont(f)
        p.setPen(QColor(0, 0, 0, 150))
        p.drawText(QPointF(x + 1, y + 1), s)
        p.setPen(colour)
        p.drawText(QPointF(x, y), s)
        f.setBold(False)
        p.setFont(f)
    def _start_screen_up(self):
        up = getattr(self.ctx, "start_screen", None)
        try:
            return bool(up and up())
        except RuntimeError:
            return False
    def _empty_state(self, p, w, h, t):
        lines = list(getattr(self.ctx, "empty_lines", None) or ()) or [
            "Nothing open", "Ctrl+O opens a generated map (a mapgen --out folder or layout.json)",
            "File > Venues opens the Sky Keep or a venue you exported"]
        y = h / 2 - 20
        for i, s in enumerate(lines):
            fm = p.fontMetrics()
            self._text(p, (w - fm.horizontalAdvance(s)) / 2, y, s,
                       QColor(t["text"] if i == 0 else t["text_dim"]), bold=(i == 0))
            y += 22
    def _nav_ball(self, p, t):
        c = self._nav_centre()
        hover_bg = self._nav_hover is not None or (
            self._mouse is not None and (self._mouse - c).manhattanLength() < NAV_BALL_R)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(255, 255, 255, 22 if hover_bg else 0))
        p.drawEllipse(c, NAV_BALL_R, NAV_BALL_R)
        cols = {"X": QColor(t["axis_x"]), "Y": QColor(t["axis_y"]), "Z": QColor(t["axis_z"])}
        for side, label, positive, pt, depth in self._nav_dots():
            col = QColor(cols[label])
            if positive:
                pen = QPen(col)
                pen.setWidthF(2.0)
                p.setPen(pen)
                p.drawLine(c, pt)
            hot = side == self._nav_hover
            p.setPen(Qt.NoPen)
            if positive:
                p.setBrush(col.lighter(130) if hot else col)
            else:
                faded = QColor(col)
                faded.setAlpha(110 if not hot else 200)
                p.setBrush(faded)
            p.drawEllipse(pt, NAV_DOT_R if positive else NAV_DOT_R - 2, NAV_DOT_R if positive else NAV_DOT_R - 2)
            if positive:
                p.setPen(QColor("#101215"))
                f = p.font()
                f.setBold(True)
                f.setPointSizeF(max(7.0, f.pointSizeF() - 1))
                p.setFont(f)
                p.drawText(QRectF(pt.x() - NAV_DOT_R, pt.y() - NAV_DOT_R, 2 * NAV_DOT_R, 2 * NAV_DOT_R),
                           Qt.AlignCenter, label)
                f.setBold(False)
                f.setPointSizeF(f.pointSizeF() + 1)
                p.setFont(f)
    def _draw_gizmo(self, p, g, t):
        w, h = self.width(), self.height()
        active = g.active or self._gizmo_hover
        for hd in g.handles(self.camera, w, h):
            pts = [self.camera.to_pixel(q, w, h) for q in hd.points]
            if any(q is None for q in pts):
                continue
            col = QColor.fromRgbF(*hd.colour)
            if active == hd.name:
                col = col.lighter(140)
            elif active:
                col.setAlphaF(0.55)
            if hd.kind == "axis":
                a, b = QPointF(pts[0][0], pts[0][1]), QPointF(pts[1][0], pts[1][1])
                pen = QPen(col)
                pen.setWidthF(2.5)
                pen.setCapStyle(Qt.RoundCap)
                p.setPen(pen)
                p.drawLine(a, b)
                d = b - a
                L = math.hypot(d.x(), d.y()) or 1.0
                ux, uy = d.x() / L, d.y() / L
                head = QPolygonF([b + QPointF(ux * 12, uy * 12), b + QPointF(-uy * 6, ux * 6),
                                  b + QPointF(uy * 6, -ux * 6)])
                p.setPen(Qt.NoPen)
                p.setBrush(col)
                p.drawPolygon(head)
                tip = b + QPointF(ux * 22, uy * 22)
                self._text(p, tip.x() - 4, tip.y() + 5, hd.name.upper()[-1:], col, bold=True)
            elif hd.kind == "plane":
                poly = QPolygonF([QPointF(q[0], q[1]) for q in pts])
                fill = QColor(col)
                fill.setAlphaF(0.35 if active != hd.name else 0.6)
                p.setPen(QPen(col, 1.2))
                p.setBrush(fill)
                p.drawPolygon(poly)
            else:
                path = QPainterPath(QPointF(pts[0][0], pts[0][1]))
                for q in pts[1:]:
                    path.lineTo(q[0], q[1])
                pen = QPen(col)
                pen.setWidthF(3.0 if active == hd.name else 2.2)
                p.setPen(pen)
                p.setBrush(Qt.NoBrush)
                p.drawPath(path)
        c = self.camera.to_pixel(g.centre, w, h)
        if c is not None:
            p.setPen(QPen(QColor(255, 255, 255, 220), 1.5))
            p.setBrush(QColor(t["accent"]))
            p.drawEllipse(QPointF(c[0], c[1]), 4.5, 4.5)
        if g.active and getattr(self, "_last_delta", None) is not None:
            d = self._last_delta
            txt = ("turn %d x 90" % d.quarters if g.mode == "rotate"
                   else "move %+d  %+d  %+d" % tuple(int(v) for v in d.offset))
            if c is not None:
                self._text(p, c[0] + 14, c[1] - 14, txt, QColor(t["text"]), bold=True)
    TOAST_S = 2.5
    _toast = None
    def show_toast(self, text, bad=False, seconds=None):
        if not text:
            return
        self._toast = (text, time.monotonic() + (seconds or self.TOAST_S), bad)
        QTimer.singleShot(int((seconds or self.TOAST_S) * 1000) + 50, self.update)
        self.update()
    def toast_text(self):
        if self._toast is None or time.monotonic() > self._toast[1]:
            return None
        return self._toast[0]
    def _toast_chip(self, p, t, w, h):
        txt = self.toast_text()
        if txt is None:
            return
        fm = p.fontMetrics()
        bw = min(w - 24, fm.horizontalAdvance(txt) + 24)
        x, y = (w - bw) / 2.0, h - 54
        bg = QColor(t["bad"] if self._toast[2] else t["raised"])
        bg.setAlpha(240)
        p.setPen(QPen(QColor(t["accent"] if not self._toast[2] else t["bad"]), 1.5))
        p.setBrush(bg)
        p.drawRoundedRect(QRectF(x, y, bw, 28), 8, 8)
        p.setPen(QColor(t["text"]))
        p.drawText(QRectF(x + 8, y, bw - 16, 28), Qt.AlignCenter,
                   fm.elidedText(txt, Qt.ElideRight, int(bw - 16)))
    def _hover_chip(self, p, t, w, h):
        sc = self.ctx.scene
        hov = sc.hover
        if hov is None or self._mouse is None or self._nav or self._gizmo:
            return
        if isinstance(hov, int) and 0 <= hov < len(sc.pieces):
            pc = sc.pieces[hov]
            name = self.ctx.registry.names.get(pc.get("tex"), pc.get("tex"))
            txt = "%s  %s  %dx%dx%d  at %d, %d, %d" % (
                pc["kind"], name, pc["w"], pc["h"], pc["d"], pc["x"], pc["y"], pc["z"])
        elif isinstance(hov, tuple) and hov[1] < len(sc.markers):
            m = sc.markers[hov[1]]
            txt = "%s %s  at %d, %d, %d  facing %d" % (m.kind, m.label, m.x, m.y, m.z, m.yaw)
        else:
            return
        fm = p.fontMetrics()
        bw = fm.horizontalAdvance(txt) + 16
        x = min(self._mouse.x() + 16, w - bw - 6)
        y = min(self._mouse.y() + 18, h - 30)
        p.setPen(QPen(QColor(t["border"]), 1))
        bg = QColor(t["raised"])
        bg.setAlpha(235)
        p.setBrush(bg)
        p.drawRoundedRect(QRectF(x, y, bw, 22), 5, 5)
        p.setPen(QColor(t["text"]))
        p.drawText(QRectF(x, y, bw, 22), Qt.AlignCenter, txt)
def is_touchpad(ev):
    try:
        dev = ev.pointingDevice()
        return dev is not None and dev.type() == QInputDevice.DeviceType.TouchPad
    except AttributeError:
        return False
def gizmo_math_delta():
    from ..core.gizmo import Delta
    return Delta()
