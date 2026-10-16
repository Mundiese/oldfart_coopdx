import collections
import math
import re
from mapgen import movement
from mapgen.metrics import mario
from mapgen.metrics.world import World, Refused
def _chain_speed():
    text = str(movement._get(("speed_carry", "long_jump_chain_speed"), "about 1300 units/s"))
    nums = [int(n) for n in re.findall(r"\d{3,5}", text)]
    return float(min(nums)) if nums else 1300.0
LONG_JUMP = _chain_speed()
WALK = mario.WALK_HALF * mario.FPS
TIPTOE = mario.TIPTOE * mario.FPS
SPEEDS = ("run", "long_jump", "walk", "tiptoe")
WORDS = {"run": "run", "long_jump": "long jump", "walk": "walk", "tiptoe": "tiptoe"}
JUMP_S = 0.5
TURN_S = 0.3
NEAR = 300
RISE_WORDS = {0: "walked", 1: "a single jump", 2: "a double jump", 3: "a triple jump or backflip",
              4: "out of reach"}
GAP_WORDS = {0: "", 1: "a running jump", 2: "a long jump", 3: "an expert jump", 4: "too wide"}
def times(units, jumps=0, turns=0):
    if units <= 0:
        return {k: 0.0 for k in SPEEDS}
    extra = jumps * JUMP_S + turns * TURN_S
    return {"run": mario.distance_time_s(units) + extra,
            "long_jump": units / LONG_JUMP + extra,
            "walk": units / float(WALK) + extra,
            "tiptoe": units / float(TIPTOE) + extra}
class Segment:
    __slots__ = ("a", "b", "across", "rise", "length")
    def __init__(self, a, b):
        self.a, self.b = tuple(a), tuple(b)
        self.across = math.hypot(b[0] - a[0], b[2] - a[2])
        self.rise = b[1] - a[1]
        self.length = math.sqrt(self.across ** 2 + self.rise ** 2)
    def reach(self):
        out = []
        if self.rise > mario.STEP_UP:
            out.append(RISE_WORDS[mario.rise_class(self.rise)])
        elif self.rise < -mario.DROP_SAFE:
            out.append("a drop that hurts")
        return out
    def bands(self):
        out = []
        r = self.rise
        if r > 0:
            out.append(rise_band(r))
        elif r < -mario.DROP_SAFE:
            out.append("drop %d: over %d hurts (a ground pound from %d)"
                       % (-r, movement.FALL_HURTS, movement.FALL_HURTS - movement.GROUND_POUND_HOVER))
        if self.across > 0:
            out.append(gap_band(self.across))
        return out
def rise_band(rise):
    e, m, h = movement.DESIGN_RISES
    if rise <= movement.STEP_MAX:
        return "rise %d: walked (a box edge up to %d)" % (rise, movement.STEP_MAX)
    head = "rise %d" % rise
    if rise < 50:
        head += " - a wall, not a step (over %d)" % movement.STEP_MAX
    if rise <= e:
        return head + ": easy (<= %d)" % e
    if rise <= m:
        return head + ": medium (<= %d)" % m
    if rise <= h:
        return head + ": hard (<= %d)" % h
    if rise <= movement.REACH:
        return head + ": beyond the design - only a triple lands (%d) or a flip grabs (%d)" % (
            movement.RISES["max_land_flat"], movement.RISES["max_grab_flat"])
    return head + ": out of reach in one move (%d the most) - a wall-kick chimney %d-%d wide climbs it" % (
        movement.REACH, movement.CHIMNEY_MIN, movement.CHIMNEY_MAX)
def gap_band(span):
    e, m, h, x = movement.DESIGN_GAPS
    if span <= e:
        word = "easy (<= %d)" % e
    elif span <= m:
        word = "medium (<= %d, a running jump flies %d)" % (m, movement.RUNNING_JUMP)
    elif span <= h:
        word = "hard (<= %d, a long jump)" % h
    elif span <= x:
        word = "expert (<= %d, a long jump flies %d)" % (x, movement.LONG_JUMP)
    else:
        word = "beyond the design (over %d)" % x
    out = "gap %d: %s" % (span, word)
    if movement.chimney(span):
        out += "; between two walls a wall-kick chimney (%d-%d)" % (movement.CHIMNEY_MIN,
                                                                   movement.CHIMNEY_MAX)
    return out
class Measure:
    def __init__(self, points, kind="ruler"):
        self.kind = kind
        self.points = [tuple(p) for p in points]
        self.segments = [Segment(a, b) for a, b in zip(self.points, self.points[1:])]
        self.jumps = 0
        self.turns = 0
        self.ok = True
        self.why = ""
    @property
    def across(self):
        return sum(s.across for s in self.segments)
    @property
    def rise(self):
        return (self.points[-1][1] - self.points[0][1]) if self.points else 0.0
    def times(self):
        return times(self.across, self.jumps, self.turns)
    def lines(self):
        if not self.ok:
            return [self.why]
        t = self.times()
        out = ["%d units across, %+d up" % (round(self.across), round(self.rise)),
               "   ".join("%s %.1f s" % (WORDS[k], t[k]) for k in SPEEDS)]
        if self.kind == "path":
            out.append("%d jump%s, %d sharp turn%s on the way" % (
                self.jumps, "" if self.jumps == 1 else "s", self.turns,
                "" if self.turns == 1 else "s"))
        else:
            reach = sorted(set(w for s in self.segments for w in s.reach()))
            gap = mario.gap_class(self.across, max(0.0, -self.rise))
            if gap and len(self.segments) == 1 and GAP_WORDS[gap]:
                reach.append("as a gap: " + GAP_WORDS[gap])
            if reach:
                out.append("; ".join(reach))
            if len(self.segments) == 1:
                out += self.segments[0].bands()
        return out
def ruler(points):
    return Measure(points, "ruler")
def path(layout, a, b, world=None):
    try:
        w = world or World(layout)
    except Refused as why:
        m = Measure([a, b], "path")
        m.ok, m.why = False, "no walk graph: %s" % why
        return m
    except (KeyError, ValueError, IndexError) as why:
        m = Measure([a, b], "path")
        m.ok, m.why = False, "no walk graph: %s" % why
        return m
    if not w.nodes:
        m = Measure([a, b], "path")
        m.ok, m.why = False, "nothing is reachable from spawn 1"
        return m
    s = w.node_of({"x": a[0], "y": a[1], "z": a[2]})
    t = w.node_of({"x": b[0], "y": b[1], "z": b[2]})
    for end, node, name in ((a, s, "start"), (b, t, "end")):
        x, y, z = w.node_xyz(node)
        off = math.hypot(x - end[0], z - end[2])
        if off > NEAR or abs(y - end[1]) > mario.JUMP_SAFE + NEAR:
            m = Measure([a, b], "path")
            m.ok = False
            m.why = ("no way there: the %s is not on ground Mario reaches from the spawns "
                     "(the nearest is %d units away)" % (name, round(math.hypot(off, y - end[1]))))
            return m
    parent = {s: None}
    q = collections.deque([s])
    while q:
        u = q.popleft()
        if u == t:
            break
        for v in w.adj[u]:
            if v not in parent:
                parent[v] = u
                q.append(v)
    if t not in parent:
        m = Measure([a, b], "path")
        m.ok, m.why = False, "Mario cannot get there from here (no way on the walk graph)"
        return m
    nodes = []
    u = t
    while u is not None:
        nodes.append(u)
        u = parent[u]
    nodes.reverse()
    pts = [w.node_xyz(n) for n in nodes]
    m = Measure(_corners(pts), "path")
    m.cells = len(nodes) - 1
    m.nodes = nodes
    m.jumps = sum(1 for p, q2 in zip(pts, pts[1:]) if q2[1] - p[1] > mario.STEP_UP)
    m.turns = _sharp_turns(pts)
    return m
def _corners(pts):
    if len(pts) < 3:
        return pts
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = out[-1], pts[i], pts[i + 1]
        d1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        d2 = (c[0] - b[0], c[1] - b[1], c[2] - b[2])
        if _unit(d1) != _unit(d2):
            out.append(b)
    out.append(pts[-1])
    return out
def _unit(d):
    return tuple(0 if v == 0 else (1 if v > 0 else -1) for v in d)
def _sharp_turns(pts):
    n = 0
    for a, b, c in zip(pts, pts[1:], pts[2:]):
        d1 = (b[0] - a[0], b[2] - a[2])
        d2 = (c[0] - b[0], c[2] - b[2])
        if d1[0] * d2[0] + d1[1] * d2[1] < 0:
            n += 1
    return n
