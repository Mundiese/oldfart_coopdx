import time
from dataclasses import dataclass
GAP = 120.0
PER_SESSION = 4
ROW = 4
NUDGES = 3
PAINTS = 5
STACKS = 4
UNDOS = 6
MENU_USES = 3
WINDOW_S = 90.0
TEXTS = {
    "row": "Drag while placing: one drag lays a whole row (a floor piece in the hand lays "
           "one big floor)",
    "move": "G then drag moves it anywhere - End drops it onto what is below",
    "fill": "Paint pen: P with nothing selected, then Shift+click paints a whole surface "
            "at once",
    "symmetry": "Shift+S turns on symmetry: everything you build happens on both sides",
    "stack": "Ctrl+Shift+D stacks a row of copies in one go",
    "scrub": "Ctrl+Alt+Z scrubs the history: drag back to any moment, let go to keep it",
}
KEY_TEXT = "%s has a key: %s"
KNOWS = {"row": ("row",), "gizmo": ("move",), "drop": ("move",), "fill": ("fill",),
         "symmetry": ("symmetry",), "stack": ("stack",), "scrub": ("scrub",)}
@dataclass
class Tip:
    id: str
    text: str
class Watcher:
    def __init__(self, known=(), shown=(), clock=time.time, gap=GAP, per_session=PER_SESSION):
        self.known = set(known)
        self.shown = set(shown)
        self.clock = clock
        self.gap = gap
        self.per_session = per_session
        self.said = 0
        self.last_said = None
        self.places = []
        self.nudges = []
        self.paints = []
        self.dups = []
        self.undos = []
        self.menu = {}
        self.last = None
    def event(self, kind, **data):
        if kind == "key":
            self.known.add("key:%s" % data.get("aid"))
            return None
        now = self.clock()
        if kind == "menu":
            return self._menu(now, data.get("aid"), data.get("label"), data.get("key"))
        tip = None
        for t in KNOWS.get(kind, ()):
            self.known.add(t)
        if kind == "place":
            tip = self._place(now, data.get("what"), data.get("at"))
        elif kind == "nudge":
            tip = self._nudge(now, data.get("selection"))
        elif kind == "paint":
            tip = self._paint(now, int(data.get("count") or 0))
        elif kind == "duplicate":
            tip = self._dup(now)
        elif kind == "mirror":
            if self.last == "duplicate" or (self.dups and now - self.dups[-1] < WINDOW_S):
                tip = self._say("symmetry", now)
        elif kind == "undo":
            tip = self._undo(now)
        if kind != "undo":
            self.undos = []
        if kind != "duplicate" and kind != "mirror":
            self.dups = [] if kind not in ("nudge", "place") else self.dups
        self.last = kind
        return tip
    def _recent(self, rows, now):
        return [r for r in rows if now - (r[0] if isinstance(r, tuple) else r) <= WINDOW_S]
    def _place(self, now, what, at):
        if at is None:
            return None
        self.places = self._recent(self.places, now) + [(now, what, tuple(at))]
        same = []
        for row in reversed(self.places):
            if row[1] != what:
                break
            same.append(row[2])
        if len(same) >= ROW and _in_a_line(same[:ROW]):
            self.places = []
            return self._say("row", now)
        return None
    def _nudge(self, now, selection):
        self.nudges = [n for n in self._recent(self.nudges, now) if n[1] == selection]
        self.nudges.append((now, selection))
        if len(self.nudges) >= NUDGES:
            self.nudges = []
            return self._say("move", now)
        return None
    def _paint(self, now, count):
        if count != 1:
            self.paints = []
            return None
        self.paints = self._recent(self.paints, now) + [now]
        if len(self.paints) >= PAINTS:
            self.paints = []
            return self._say("fill", now)
        return None
    def _dup(self, now):
        self.dups = self._recent(self.dups, now) + [now]
        if len(self.dups) >= STACKS:
            self.dups = []
            return self._say("stack", now)
        return None
    def _undo(self, now):
        self.undos = [t for t in self.undos if now - t <= 15.0] + [now]
        if len(self.undos) >= UNDOS:
            self.undos = []
            return self._say("scrub", now)
        return None
    def _menu(self, now, aid, label, key):
        if not aid or not key:
            return None
        self.menu[aid] = self.menu.get(aid, 0) + 1
        if self.menu[aid] >= MENU_USES:
            self.menu[aid] = 0
            return self._say("key:%s" % aid, now, KEY_TEXT % (label or aid, key))
        return None
    def may_say(self, tid, now=None):
        now = self.clock() if now is None else now
        if tid in self.known or tid in self.shown:
            return False
        if self.said >= self.per_session:
            return False
        if self.last_said is not None and now - self.last_said < self.gap:
            return False
        return True
    def _say(self, tid, now, text=None):
        if not self.may_say(tid, now):
            return None
        self.shown.add(tid)
        self.said += 1
        self.last_said = now
        return Tip(tid, text or TEXTS[tid])
    def state(self):
        return {"known": sorted(self.known), "shown": sorted(self.shown)}
def _in_a_line(points):
    ys = set(round(p[1]) for p in points)
    if len(ys) != 1:
        return False
    xs = set(round(p[0]) for p in points)
    zs = set(round(p[2]) for p in points)
    return (len(xs) == 1 and len(zs) == len(points)) or (len(zs) == 1
                                                         and len(xs) == len(points))
