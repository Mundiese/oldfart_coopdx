import copy
import math
import os
import re
from studio.editor.commands import Change
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PIECES = {"target": "lgtarget", "button": "lgbutton", "zone": "lgzone"}
KIND_OF = {v: k for k, v in PIECES.items()}
EVENTS = ("pressed", "entered", "left", "hit", "alldown", "timer")
ACTIONS = ("raise", "start", "flip", "timer_start", "timer_stop", "message", "finish")
MAX_LINK = 31
MAX_WIRES = 24
MESSAGES = ("Go!", "The door is open", "Halfway there", "Well done", "Time is up")
ZONE_RADIUS = 300
EVENT_WORDS = {
    "pressed": "button %d is pressed", "entered": "somebody walks into zone %d",
    "left": "somebody walks out of zone %d", "hit": "a target of %d is hit",
    "alldown": "every target of %d is down", "timer": "the clock passes %d seconds",
}
ACTION_WORDS = {
    "raise": "raise targets %d", "start": "open door / start mover %d",
    "flip": "flip the ON/OFF switch", "timer_start": "start the clock",
    "timer_stop": "stop the clock", "message": "show a message", "finish": "finish the course",
}
NUMBERED = ("raise", "start")
RGBA = {"target": (1.0, 0.55, 0.25, 1.0), "button": (0.75, 0.45, 1.0, 1.0),
        "zone": (0.45, 0.85, 1.0, 1.0)}
WIRE_RGBA = {"raise": (1.0, 0.55, 0.25, 0.9), "start": (0.3, 0.9, 0.5, 0.9),
             "finish": (1.0, 0.9, 0.3, 0.9)}
OTHER_RGBA = (0.9, 0.9, 0.9, 0.8)
RECIPES = {
    "course": ("Training course",
               "a start button, three pop-up targets, a finish zone and the clock",
               [("button", 0, 0, 1), ("target", 600, -300, 1), ("target", 900, 250, 1),
                ("target", 1300, -150, 1), ("zone", 1700, 0, 1)],
               [("pressed", 1, "timer_start", 0), ("pressed", 1, "raise", 1),
                ("pressed", 1, "message", 0, "1"), ("entered", 1, "finish", 0)]),
    "door": ("Button opens a door",
             "a button that opens every door (a mover) wired to it",
             [("button", 0, 0, 1)],
             [("pressed", 1, "start", 1), ("pressed", 1, "message", 0, "2")]),
    "gallery": ("Shooting gallery",
                "five targets in a row that stand up again when all are down",
                [("button", 0, 0, 1), ("target", 800, -600, 1), ("target", 800, -300, 1),
                 ("target", 800, 0, 1), ("target", 800, 300, 1), ("target", 800, 600, 1)],
                [("pressed", 1, "raise", 1), ("alldown", 1, "raise", 1),
                 ("alldown", 1, "message", 0, "4")]),
}
class LogicError(ValueError):
    pass
def wire(on, src, act, dst=0, arg=None):
    if on not in EVENTS:
        raise LogicError("no event %r" % (on,))
    if act not in ACTIONS:
        raise LogicError("no action %r" % (act,))
    top = 3600 if on == "timer" else MAX_LINK
    src, dst = int(src), int(dst) if act in NUMBERED else 0
    if not 0 <= src <= top or not 0 <= dst <= MAX_LINK:
        raise LogicError("a number out of range")
    out = {"on": on, "src": src, "act": act, "dst": dst}
    if arg not in (None, ""):
        out["arg"] = re.sub(r"[;|]", " ", str(arg))[:40]
    return out
def message_text(arg):
    if arg is not None and str(arg).isdigit() and 1 <= int(arg) <= len(MESSAGES):
        return MESSAGES[int(arg) - 1]
    return str(arg) if arg else MESSAGES[0]
def wire_text(w):
    on = EVENT_WORDS[w["on"]] % w["src"]
    act = ACTION_WORDS[w["act"]] % w["dst"] if w["act"] in NUMBERED else ACTION_WORDS[w["act"]]
    if w["act"] == "message":
        act += ": " + message_text(w.get("arg"))
    return "When %s: %s" % (on, act)
def kind_of(item):
    return KIND_OF.get((item or {}).get("key"))
def wires_of(doc):
    return [dict(w) for w in (doc.rest.get("wires") or []) if isinstance(w, dict)]
def used_links(doc):
    used = set()
    for ref in doc.refs("object"):
        o = doc.get(ref)
        if kind_of(o):
            used.add(int(o.get("link") or 0))
    for ref in doc.refs("mover"):
        m = doc.get(ref)
        if m.get("trigger") == "wired":
            used.add(int(m.get("link") or 0))
    for w in wires_of(doc):
        used.add(w["src"])
        used.add(w["dst"])
    return used
def free_link(doc):
    used = used_links(doc)
    for n in range(1, MAX_LINK + 1):
        if n not in used:
            return n
    raise LogicError("every number from 1 to %d is taken" % MAX_LINK)
def _rest_change(doc, label, wires, steps=(), select=None):
    if len(wires) > MAX_WIRES:
        raise LogicError("a map holds %d wires at most" % MAX_WIRES)
    before = copy.deepcopy(doc.rest.get("wires"))
    return Change(label, list(steps) + [("rest", "wires", before, wires or None)], select=select)
def piece_row(kind, at, link, yaw=0):
    if kind not in PIECES:
        raise LogicError("no piece %r" % (kind,))
    return {"key": PIECES[kind], "x": int(round(at[0])), "y": int(round(at[1])),
            "z": int(round(at[2])), "yaw": yaw, "link": int(link)}
class LogicTool:
    def __init__(self, session):
        self.session = session
        self.source = None
    @property
    def doc(self):
        return self.session.doc
    def pieces(self):
        out = []
        for ref in self.doc.refs("object"):
            o = self.doc.get(ref)
            if kind_of(o):
                out.append((ref, o, kind_of(o)))
        return out
    def place(self, kind, at, link=None):
        link = free_link(self.doc) if link is None else int(link)
        ref = ("object", self.doc.new_id("object"))
        row = piece_row(kind, at, link)
        return Change("Place a %s" % kind, [("insert", ref, len(self.doc.refs("object")), row)],
                      select=[ref])
    def set_link(self, ref, link):
        o = self.doc.get(ref)
        if not kind_of(o):
            raise LogicError("not a logic piece")
        new = dict(o)
        new["link"] = max(1, min(MAX_LINK, int(link)))
        return Change("Number a %s" % kind_of(o), [("replace", ref, copy.deepcopy(o), new)],
                      select=[ref])
    def nearest(self, point, reach=500.0):
        best, far = None, reach * reach
        for ref in self.doc.refs("object") + self.doc.refs("mover"):
            o = self.doc.get(ref)
            if ref[0] == "object" and not kind_of(o):
                continue
            d = (o["x"] - point[0]) ** 2 + (o["z"] - point[2]) ** 2
            if d <= far:
                best, far = ref, d
        return best
    def choices(self, src_ref, dst_ref=None):
        src = self.doc.get(src_ref)
        kind = kind_of(src)
        if kind is None:
            raise LogicError("start a wire on a button, a zone or a target")
        n = int(src.get("link") or 1)
        events = {"button": ["pressed"], "zone": ["entered", "left"],
                  "target": ["alldown", "hit"]}[kind]
        dst = self.doc.get(dst_ref) if dst_ref is not None else None
        acts = []
        if dst_ref is not None and dst_ref[0] == "mover":
            m = int(dst.get("link") or 0) if dst.get("trigger") == "wired" else 0
            acts = [("start", m or free_link(self.doc))]
        elif dst is not None and kind_of(dst) == "target":
            acts = [("raise", int(dst.get("link") or 1))]
        elif dst is not None and kind_of(dst) in ("button", "zone"):
            acts = [("timer_start", 0), ("finish", 0), ("timer_stop", 0)]
        else:
            acts = [("timer_start", 0), ("finish", 0), ("timer_stop", 0), ("flip", 0),
                    ("message", 0)]
        out = []
        for on in events:
            for act, d in acts:
                w = wire(on, n, act, d, "1" if act == "message" else None)
                out.append((wire_text(w), w))
        return out
    def connect(self, src_ref, dst_ref=None, choice=0):
        options = self.choices(src_ref, dst_ref)
        if not 0 <= choice < len(options):
            raise LogicError("no such choice")
        w = options[choice][1]
        wires = wires_of(self.doc)
        if w in wires:
            raise LogicError("that wire is already there")
        steps = []
        if dst_ref is not None and dst_ref[0] == "mover":
            m = self.doc.get(dst_ref)
            new = dict(m)
            new["trigger"], new["link"] = "wired", w["dst"]
            if new != m:
                steps.append(("replace", dst_ref, copy.deepcopy(m), new))
        self.source = None
        return _rest_change(self.doc, "Wire: " + wire_text(w), wires + [w], steps)
    def add_wire(self, w):
        return _rest_change(self.doc, "Wire: " + wire_text(w), wires_of(self.doc) + [w])
    def delete_wire(self, i):
        wires = wires_of(self.doc)
        if not 0 <= i < len(wires):
            raise LogicError("no wire %d" % i)
        del wires[i]
        return _rest_change(self.doc, "Take a wire out", wires)
    def recipe(self, key, at, yaw=0):
        if key not in RECIPES:
            raise LogicError("no recipe %r" % (key,))
        _, _, pieces, wires = RECIPES[key]
        base = free_link(self.doc)
        s, c = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
        steps, refs = [], []
        index = len(self.doc.refs("object"))
        taken = set(i for _, i in self.doc.refs("object"))
        for kind, ahead, side, n in pieces:
            ref = ("object", self.doc.new_id("object"))
            while ref[1] in taken:
                ref = ("object", self.doc.new_id("object"))
            taken.add(ref[1])
            p = (at[0] + s * ahead + c * side, at[1], at[2] + c * ahead - s * side)
            steps.append(("insert", ref, index, piece_row(kind, p, n - 1 + base, yaw)))
            refs.append(ref)
            index += 1
        new = []
        for row in wires:
            on, src, act, dst = row[:4]
            new.append(wire(on, src if on == "timer" else src - 1 + base, act,
                            dst - 1 + base if act in NUMBERED else 0,
                            row[4] if len(row) > 4 else None))
        return _rest_change(self.doc, "Place: " + RECIPES[key][0], wires_of(self.doc) + new,
                            steps, select=refs)
    def spots_faced(self):
        out = []
        def add(x, y, z, yaw=0):
            p = (int(round(x)), int(round(y)), int(round(z)))
            if not any(abs(p[0] - q[0]) < 50 and abs(p[2] - q[2]) < 50 for q in out):
                out.append(p + (int(yaw or 0),))
        hooks = self.doc.rest.get("hooks")
        for spot in (hooks.get("targets") if isinstance(hooks, dict) else None) or []:
            if isinstance(spot, dict) and all(k in spot for k in "xyz"):
                add(spot["x"], spot["y"], spot["z"], spot.get("yaw"))
        for _ref, spot in self.doc.spots():
            if str(spot.get("_name", "")).lower().startswith("target"):
                add(spot["x"], spot["y"], spot["z"], spot.get("yaw"))
        for spot in self.doc.rest.get("targetSpots") or []:
            if isinstance(spot, dict):
                add(spot["x"], spot["y"], spot["z"], spot.get("yaw"))
            elif isinstance(spot, (list, tuple)) and len(spot) >= 3:
                add(*spot[:3])
        return out
    def target_spots(self):
        return [s[:3] for s in self.spots_faced()]
    def _targets_on_spots(self, group):
        have = [(o["x"], o["z"]) for _, o, k in self.pieces() if k == "target"]
        steps, refs = [], []
        index = len(self.doc.refs("object"))
        taken = set(i for _, i in self.doc.refs("object"))
        for (x, y, z, yaw) in self.spots_faced():
            if any(abs(x - hx) < 50 and abs(z - hz) < 50 for hx, hz in have):
                continue
            ref = ("object", self.doc.new_id("object"))
            while ref[1] in taken:
                ref = ("object", self.doc.new_id("object"))
            taken.add(ref[1])
            steps.append(("insert", ref, index, piece_row("target", (x, y, z), group, yaw)))
            refs.append(ref)
            index += 1
        return steps, refs
    def fill_target_spots(self, group=None):
        spots = self.target_spots()
        if not spots:
            raise LogicError("this map has no target spots")
        group = free_link(self.doc) if group is None else int(group)
        steps, refs = self._targets_on_spots(group)
        if not steps:
            raise LogicError("every target spot already has a target")
        wires = wires_of(self.doc)
        if not any(w["act"] == "raise" and w["dst"] == group for w in wires):
            wires += [wire("pressed", group, "timer_start", 0), wire("pressed", group, "raise", group),
                      wire("alldown", group, "finish", 0)]
        return _rest_change(self.doc, "Fill %d target spots" % len(steps), wires, steps,
                            select=refs)
    def start_spot(self):
        got = self.doc.spots("lineStart")
        if got:
            s = got[0][1]
            return (s["x"], s["y"], s["z"])
        spawns = self.doc.refs("spawn")
        if spawns:
            s = self.doc.get(spawns[0])
            return (s["x"], s["y"], s["z"])
        return None
    def can_make_course(self):
        if not self.spots_faced() or self.start_spot() is None:
            return False
        have = [(o["x"], o["z"]) for _, o, k in self.pieces() if k == "target"]
        return any(not any(abs(x - hx) < 50 and abs(z - hz) < 50 for hx, hz in have)
                   for x, _, z, _ in self.spots_faced())
    def make_course(self):
        if not self.spots_faced():
            raise LogicError("this map has no target spots - generate a Killhouse, or put "
                             "targets down by hand")
        at = self.start_spot()
        if at is None:
            raise LogicError("this map has no start - put a spawn down first")
        group = free_link(self.doc)
        steps, refs = self._targets_on_spots(group)
        if not steps:
            raise LogicError("every target spot already has a target")
        ref = ("object", self.doc.new_id("object"))
        taken = set(i for _, i in self.doc.refs("object")) | set(r[1] for r in refs)
        while ref[1] in taken:
            ref = ("object", self.doc.new_id("object"))
        steps.append(("insert", ref, len(self.doc.refs("object")) + len(refs),
                      piece_row("button", at, group)))
        wires = wires_of(self.doc) + [
            wire("pressed", group, "timer_start", 0), wire("pressed", group, "raise", group),
            wire("pressed", group, "message", 0, "1"), wire("alldown", group, "finish", 0)]
        return _rest_change(self.doc, "Make it a course: %d targets and a start button"
                            % (len(refs)), wires, steps, select=refs + [ref])
    def layer(self, doc=None):
        from studio.toolbox.overlays import Layer
        doc = doc or self.doc
        L = Layer("logic", "Logic")
        by = {"target": {}, "button": {}, "zone": {}}
        for ref in doc.refs("object"):
            o = doc.get(ref)
            k = kind_of(o)
            if not k:
                continue
            n = int(o.get("link") or 0)
            top = (o["x"], o["y"] + (240 if k == "target" else 40), o["z"])
            by[k].setdefault(n, []).append(top)
            L.dot(top, RGBA[k], 9.0 if ref == self.source else 6.0)
            L.label(top, "%s %d" % (k, n), RGBA[k])
            if k == "zone":
                pts = [(o["x"] + ZONE_RADIUS * math.cos(a * math.pi / 12), o["y"] + 10,
                        o["z"] + ZONE_RADIUS * math.sin(a * math.pi / 12)) for a in range(25)]
                for a, b in zip(pts, pts[1:]):
                    L.line(a, b, RGBA["zone"], 2.0)
        movers = {}
        for ref in doc.refs("mover"):
            m = doc.get(ref)
            if m.get("trigger") == "wired":
                movers.setdefault(int(m.get("link") or 0), []).append((m["x"], m["y"] + 100, m["z"]))
        src_kind = {"pressed": "button", "entered": "zone", "left": "zone", "hit": "target",
                    "alldown": "target"}
        stacked = {}
        for w in wires_of(doc):
            froms = by.get(src_kind.get(w["on"]), {}).get(w["src"], [])
            if w["act"] == "raise":
                tos = by["target"].get(w["dst"], [])
            elif w["act"] == "start":
                tos = movers.get(w["dst"], [])
            else:
                tos = []
            rgba = WIRE_RGBA.get(w["act"], OTHER_RGBA)
            for a in froms:
                for b in tos:
                    L.line(a, b, rgba, 2.5)
                if not tos:
                    n = stacked[a] = stacked.get(a, 0) + 1
                    L.label((a[0], a[1] + 40 + 110 * n, a[2]), wire_text(w), rgba)
        L.legend = [(RGBA["button"], "a button"), (RGBA["zone"], "a zone"),
                    (RGBA["target"], "a pop-up target"),
                    (WIRE_RGBA["raise"], "a wire that raises targets"),
                    (WIRE_RGBA["start"], "a wire that opens a door")]
        return L
def issues(doc):
    from studio.toolbox.issues import Issue
    tool = LogicTool(type("S", (), {"doc": doc})())
    have = {"button": set(), "zone": set(), "target": set()}
    for _, o, k in tool.pieces():
        have[k].add(int(o.get("link") or 0))
    movers = set(int(doc.get(r).get("link") or 0) for r in doc.refs("mover")
                 if doc.get(r).get("trigger") == "wired")
    src_kind = {"pressed": "button", "entered": "zone", "left": "zone", "hit": "target",
                "alldown": "target"}
    out = []
    for i, w in enumerate(wires_of(doc)):
        kw = dict(fixes=["delete_wire"], data={"wire": i})
        k = src_kind.get(w["on"])
        say = wire_text(w)
        if k and w["src"] not in have[k]:
            out.append(Issue("warn", "logic", "%s - there is no %s %d" % (say, k, w["src"]), **kw))
        if w["act"] == "raise" and w["dst"] not in have["target"]:
            out.append(Issue("warn", "logic", "%s - there are no targets %d" % (say, w["dst"]),
                             **kw))
        if w["act"] == "start" and w["dst"] not in movers:
            out.append(Issue("warn", "logic", "%s - no mover waits for wire %d" % (say, w["dst"]),
                             **kw))
    return out
