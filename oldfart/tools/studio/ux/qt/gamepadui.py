import math
from PySide6.QtCore import QObject, QPointF, QTimer
from PySide6.QtWidgets import QDialog, QLabel, QTableWidget, QTableWidgetItem, QVBoxLayout
from studio.ux import gamepad as G
from . import action
action("app.controller", [], "Controller…", "Help",
       "The pad's buttons - the same as the Forge's in the game - and whether a pad is connected")
POLL_MS = 16
BUTTONS = ("a", "b", "x", "y", "back", "start", "leftstick", "rightstick", "leftshoulder",
           "rightshoulder", "dpup", "dpdown", "dpleft", "dpright")
class PygamePad:
    def __init__(self, mod):
        import pygame
        self.pygame = pygame
        pygame.init()
        mod.init()
        self.mod = mod
        self.pad = mod.Controller(0) if mod.get_count() else None
    def read(self):
        pg = self.pygame
        pg.event.pump()
        if self.pad is None:
            if self.mod.get_count():
                self.pad = self.mod.Controller(0)
            return None
        names = set()
        for b in BUTTONS:
            const = getattr(pg, "CONTROLLER_BUTTON_%s" % b.upper(), None)
            if const is not None and self.pad.get_button(const):
                names.add(b)
        ax = {}
        for name in ("leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright"):
            const = getattr(pg, "CONTROLLER_AXIS_%s" % name.upper(), None)
            ax[name] = (self.pad.get_axis(const) / 32767.0) if const is not None else 0.0
        if ax["triggerleft"] > 0.5:
            names.add("lefttrigger")
        if ax["triggerright"] > 0.5:
            names.add("righttrigger")
        return names, ax["leftx"], ax["lefty"], ax["rightx"], ax["righty"]
class GamepadUI(QObject):
    def __init__(self, ux, backend=None):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.mapper = G.Mapper()
        self.done = []
        self._point = None
        self._snapped = None
        ux.add_action("app.controller", self.dialog, menu=ux.menu("&Help"))
        name, mod = backend if backend is not None else G.backend()
        self.status = mod if name is None else "%s - looking for a pad" % name
        self.device = None
        if name == "pygame":
            try:
                self.device = PygamePad(mod)
                self.status = "pygame - %s" % ("a pad is connected" if self.device.pad
                                               else "no pad connected yet")
            except Exception as why:
                self.status = "pygame failed: %s" % why
        self.timer = QTimer(self)
        self.timer.setInterval(POLL_MS)
        self.timer.timeout.connect(self.poll)
        self.stopped = False
        self.settings = ux.settings
        self.settings.listen(self._setting)
        from PySide6.QtWidgets import QApplication
        app = QApplication.instance()
        if app is not None:
            app.aboutToQuit.connect(self.stop)
        self._setting("ui.controller", self.settings["ui.controller"])
    def enabled(self):
        return bool(self.settings["ui.controller"]) and not self.stopped
    def _setting(self, key, value):
        if key != "ui.controller" or self.stopped:
            return
        if value and self.device is not None:
            self.timer.start()
        else:
            self.timer.stop()
    def stop(self):
        self.stopped = True
        self.timer.stop()
        dev, self.device = self.device, None
        try:
            if dev is not None:
                if getattr(dev, "pad", None) is not None and hasattr(dev.pad, "quit"):
                    dev.pad.quit()
                dev.mod.quit()
                dev.pygame.quit()
        except Exception:
            pass
        return True
    def window_has_focus(self):
        from PySide6.QtWidgets import QAbstractSpinBox, QApplication, QLineEdit, QPlainTextEdit, \
            QTextEdit
        win = self.ux.window
        if win is None or not win.isVisible() or not win.isActiveWindow():
            return False
        fw = QApplication.focusWidget()
        return not isinstance(fw, (QLineEdit, QTextEdit, QPlainTextEdit, QAbstractSpinBox))
    def poll(self):
        if not self.enabled() or self.device is None:
            self.timer.stop()
            return None
        if not self.window_has_focus():
            return None
        try:
            got = self.device.read()
        except Exception as why:
            self.status = "the pad stopped: %s" % why
            self.timer.stop()
            return None
        if got is None:
            return None
        names, lx, ly, rx, ry = got
        return self.feed_raw(names, lx, ly, rx, ry)
    def feed_raw(self, names, lx=0.0, ly=0.0, rx=0.0, ry=0.0):
        if self.stopped:
            return []
        cmds = self.mapper.feed(G.Pad(G.roles_of(names), lx, ly, rx, ry))
        for c in cmds:
            self.run(c)
        return cmds
    def run(self, cmd):
        self.done.append(cmd)
        del self.done[:-40]
        kind = cmd[0]
        acts = self.ux.window.actions
        ed = self.ed
        if kind == "action":
            aid = cmd[1]
            if aid == "pad.place":
                if ed.armed:
                    return ed.place_armed()
                hb = self.ux.parts.get("hotbarui")
                return hb.take(hb.bar.current) if hb is not None else None
            if aid == "pad.delete":
                if ed.session.refs():
                    return ed.run_action("edit.delete")
                return None
            if aid in ("pad.hotbar_back", "pad.hotbar_on"):
                hb = self.ux.parts.get("hotbarui")
                if hb is not None:
                    k = hb.bar.cycle(-1 if aid.endswith("back") else 1)
                    return hb.take(k) if k is not None else None
                return None
            a = acts.get(aid)
            if a is not None:
                a.trigger()
            return aid
        if kind == "cursor":
            return self.move_cursor(cmd[1], cmd[2])
        if kind == "orbit":
            v = self.ux.view()
            if v is not None:
                v.camera.orbit(-cmd[1], cmd[2])
                v.update()
            return None
        if kind == "wheel":
            wh = self.ux.parts.get("wheelui")
            if wh is None:
                return None
            if cmd[1] == "open":
                return wh.open()
            r = wh.radial
            local = r.centre() + QPointF(cmd[2], cmd[3])
            if cmd[1] == "point":
                r.hot = r.slice_at(local)
                r.update()
                return r.hot
            wh.opened_at = (wh.opened_at or 0) - 1.0
            return wh.release(local)
        return None
    def move_cursor(self, dx, dy):
        v = self.ux.view()
        s = self.ed.session
        if v is None:
            return None
        right, _, forward = v.camera.basis()
        fx, fz = forward[0], forward[2]
        n = math.hypot(fx, fz) or 1.0
        last = getattr(self, "_point", None)
        if last is None or self._snapped != tuple(s.cursor):
            last = tuple(s.cursor)
        x, y, z = last
        x += right[0] * dx - fx / n * dy
        z += right[2] * dx - fz / n * dy
        y = float(self.ux.settings["grid.height"])
        self._point = (x, y, z)
        s.cursor = (x, y, z)
        self.ux.ctx.cursorMoved.emit({"view": v, "kind": "plane", "index": None,
                                      "point": (x, y, z),
                                      "snapped": tuple(self.ux.ctx.snap.point((x, y, z))),
                                      "cell": self.ux.ctx.snap.cell((x, y, z))})
        self._snapped = tuple(s.cursor)
        return self._point
    def dialog(self):
        d = QDialog(self.ux.window)
        d.setWindowTitle("Controller")
        lay = QVBoxLayout(d)
        from studio.editor.qt.widgets import Banner
        state = Banner()
        if self.settings["ui.controller"] and "connected" in str(self.status).lower():
            state.ok("Building with a controller is on", "Pad: %s" % self.status)
        else:
            state.fail("Building with a controller is %s" % ("on" if self.settings[
                "ui.controller"] else "off"), "Pad: %s. %s" % (self.status, "" if self.settings[
                    "ui.controller"] else "Preferences > Tools > Build with a controller "
                    "turns it on."))
        lay.addWidget(state)
        lay.addWidget(QLabel("The same buttons as the Forge in the game."))
        t = QTableWidget(len(G.TABLE), 2)
        t.setHorizontalHeaderLabels(["Button", "Does"])
        t.verticalHeader().setVisible(False)
        t.horizontalHeader().setStretchLastSection(True)
        t.setEditTriggers(QTableWidget.NoEditTriggers)
        for r, (b, does) in enumerate(G.TABLE):
            t.setItem(r, 0, QTableWidgetItem(b))
            t.setItem(r, 1, QTableWidgetItem(does))
        t.resizeColumnsToContents()
        t.horizontalHeader().setStretchLastSection(True)
        lay.addWidget(t)
        d.resize(520, 440)
        self._dialog = d
        d.show()
        return d
def install(ux):
    return GamepadUI(ux)
