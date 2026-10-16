import math
DEFAULT_BINDS = {"a": "A", "x": "B", "leftshoulder": "L", "rightshoulder": "R",
                 "righttrigger": "R", "lefttrigger": "Z", "start": "START", "back": "SELECT",
                 "dpup": "DUP", "dpdown": "DDOWN", "dpleft": "DLEFT", "dpright": "DRIGHT",
                 "leftstick": "L3", "rightstick": "R3", "y": "Y", "b": "BPAD"}
DEAD = 0.22
WHEEL_HOLD = 12
REPEAT = 8
CURSOR_SPEED = 40.0
ORBIT_SPEED = 4.0
class Pad:
    __slots__ = ("buttons", "lx", "ly", "rx", "ry")
    def __init__(self, buttons=(), lx=0.0, ly=0.0, rx=0.0, ry=0.0):
        self.buttons = set(buttons)
        self.lx, self.ly, self.rx, self.ry = lx, ly, rx, ry
def roles_of(raw_buttons, binds=None):
    binds = binds or DEFAULT_BINDS
    return {binds[b] for b in raw_buttons if b in binds}
def _dz(v):
    return 0.0 if abs(v) < DEAD else v
class Mapper:
    def __init__(self):
        self.prev = set()
        self.both = 0
        self.wheel = False
        self.repeat = {}
    def _pressed(self, now, role):
        return role in now and role not in self.prev
    def _step(self, key, active):
        if not active:
            self.repeat.pop(key, None)
            return False
        n = self.repeat.get(key, -1) + 1
        self.repeat[key] = n
        return n % REPEAT == 0
    def feed(self, pad):
        now = set(pad.buttons)
        out = []
        lx, ly, rx, ry = _dz(pad.lx), _dz(pad.ly), _dz(pad.rx), _dz(pad.ry)
        L, R = "L" in now, "R" in now
        if L and R and not ({"B", "Z"} & now):
            self.both += 1
            if self.both == WHEEL_HOLD:
                self.wheel = True
                out.append(("wheel", "open", 0.0, 0.0))
            elif self.wheel and (lx or ly):
                out.append(("wheel", "point", lx * 100, ly * 100))
        else:
            chose = self.wheel
            if chose:
                out.append(("wheel", "choose", lx * 100, ly * 100))
            self.wheel = False
            self.both = 0
            if chose:
                self.prev = now
                return out
        if self._pressed(now, "B"):
            if L and R:
                out.append(("action", "edit.redo"))
            elif L:
                out.append(("action", "edit.undo"))
            elif R:
                out.append(("action", "pad.delete"))
            else:
                out.append(("action", "pad.place"))
        if self._pressed(now, "Z"):
            if L and not R:
                out.append(("action", "pad.hotbar_back"))
            elif R and not L:
                out.append(("action", "pad.hotbar_on"))
        for role, aid in (("SELECT", "lib.commands"),
                          ("DLEFT", "edit.nudge_left"), ("DRIGHT", "edit.nudge_right"),
                          ("DUP", "tools.variant_next"), ("DDOWN", "tools.variant_prev"),
                          ("R3", "view.frame_selected"), ("L3", "view.frame_all"),
                          ("Y", "wheel.open")):
            if self._pressed(now, role):
                out.append(("action", aid))
        if not self.wheel:
            if L and not R:
                if self._step("plane", abs(ly) > 0.5):
                    out.append(("action", "plane.up" if ly < 0 else "plane.down"))
            elif lx or ly:
                out.append(("cursor", lx * CURSOR_SPEED, ly * CURSOR_SPEED))
            if R and not L:
                if self._step("turn", abs(rx) > 0.5):
                    out.append(("action", "edit.turn" if rx > 0 else "edit.turn_back"))
            elif (rx or ry) and not L:
                out.append(("orbit", rx * ORBIT_SPEED, ry * ORBIT_SPEED))
        self.prev = now
        return out
def stick_angle(dx, dy):
    return math.degrees(math.atan2(dx, -dy)) % 360.0
def backend():
    try:
        import pygame
        from pygame._sdl2 import controller
        return "pygame", controller
    except Exception:
        pass
    try:
        import sdl2
        return "pysdl2", sdl2
    except Exception:
        pass
    return None, ("To build with a game controller, the Studio needs pygame: "
                  "pip install pygame")
TABLE = [("B", "lay what is in the hand"), ("R + B", "take out"),
         ("L + B / L + R + B", "undo / redo"), ("L + Z / R + Z", "hotbar back / on"),
         ("left stick", "move the cursor"), ("L + left stick", "work plane down / up"),
         ("right stick", "orbit the view"), ("R + right stick", "turn"),
         ("hold L + R", "the quick wheel (left stick points, let go)"),
         ("Back", "find any command"),
         ("D-pad", "nudge; up / down change the shape")]
