import functools
import math
from . import movement
FPS = 30
RUN_SPEED = float(movement.RUN)
LJ_KEEP = 0.97
NUDGE = 20
HOVER = movement.GROUND_POUND_HOVER
TIERS = ("casual", "normal", "hard", "expert", "pro")
TIER_LABEL = {"casual": "Casual", "normal": "Normal", "hard": "Hard", "expert": "Expert",
              "pro": "Pro"}
DIFFICULTY_TIER = {"easy": "casual", "casual": "casual", "normal": "normal", "hard": "hard",
                   "expert": "expert", "pro": "pro", "kaizo": "pro"}
MOVE_LABEL = {
    "jump": "running jump", "standjump": "standing jump", "double": "double jump",
    "triple": "triple jump", "longjump": "long jump", "sideflip": "side flip",
    "backflip": "backflip", "wallkick": "wall kick", "kickup": "side flip into wall kick",
    "dive": "dive", "groundpound": "ground pound", "ride": "moving platform",
    "blj": "backward long jump",
}
SWITCHES = ("longjump", "sideflip", "wallkick", "dive", "groundpound", "triple", "movers",
            "blj")
SWITCH_MOVES = {"longjump": ("longjump",), "sideflip": ("sideflip", "kickup"),
                "wallkick": ("wallkick", "kickup"), "dive": ("dive",),
                "groundpound": ("groundpound",), "triple": ("triple",), "movers": ("ride",),
                "blj": ("blj",)}
class Tier(object):
    def __init__(self, name, rank, leeway, grab, depth_run, depth_long, lane, nets,
                 checkpoint_s, moves, chimney, mover_wait, fail):
        self.name = name
        self.rank = rank
        self.leeway = leeway
        self.grab = grab
        self.depth_run = depth_run
        self.depth_long = depth_long
        self.lane = lane
        self.nets = nets
        self.checkpoint_s = checkpoint_s
        self.moves = frozenset(moves)
        self.chimney = chimney
        self.mover_wait = mover_wait
        self.fail = fail
    @property
    def label(self):
        return TIER_LABEL[self.name]
TIER = {
    "casual": Tier("casual", 0, 6, False, 800, 1000, 1600, "all", 20,
                   ("jump", "standjump", "ride"), None, 30, 0.30),
    "normal": Tier("normal", 1, 4, True, 600, 800, 400, "all", 25,
                   ("jump", "standjump", "ride"), None, 20, 0.35),
    "hard": Tier("hard", 2, 3, True, 500, 600, 200, "not_peak", 30,
                 ("jump", "standjump", "ride", "longjump", "sideflip", "double", "wallkick"),
                 ("easy_late_kicks", (400, 500, 600)), 12, 0.40),
    "expert": Tier("expert", 3, 2, True, 400, 500, 200, "breather", 40,
                   ("jump", "standjump", "ride", "longjump", "sideflip", "double", "wallkick",
                    "dive", "triple", "groundpound"),
                   ("easy_late_kicks", (300, 400, 500, 600, 700, 800)), 6, 0.45),
    "pro": Tier("pro", 4, 1, True, 300, 400, 200, "none", 50,
                ("jump", "standjump", "ride", "longjump", "sideflip", "double", "wallkick",
                 "kickup", "dive", "triple", "groundpound"),
                ("skilled_late_kicks", (200, 300, 800, 900)), 0, 0.50),
}
def tier_of(brief_or_word):
    if isinstance(brief_or_word, str):
        word = brief_or_word
    else:
        try:
            word = brief_or_word["difficulty"]
        except (KeyError, TypeError):
            word = "normal"
    return TIER[DIFFICULTY_TIER.get(str(word).lower(), "normal")]
def allowed(tier, switches=None):
    moves = set(tier.moves)
    for name, on in (switches or {}).items():
        for mv in SWITCH_MOVES.get(name, ()):
            if on is False:
                moves.discard(mv)
            elif on is True and mv == "blj":
                moves.add(mv)
    return moves
@functools.lru_cache(maxsize=1)
def sim():
    return movement.sim_module()
def speed_after(run):
    if run <= 0:
        return 0.0
    v, d = 8.0, 0.0
    while d < run:
        v = min(RUN_SPEED, v + 1.1 - v / 43.0)
        d += v
    return v
def _act(move):
    S = sim()
    return {"jump": S.JUMP, "standjump": S.JUMP, "double": S.DOUBLE, "triple": S.TRIPLE,
            "longjump": S.LONGJUMP, "sideflip": S.SIDEFLIP, "backflip": S.BACKFLIP,
            "dive": S.JUMP, "ride": S.JUMP, "groundpound": S.JUMP, "blj": S.LONGJUMP}[move]
STANDING = ("standjump", "sideflip", "backflip")
def launch_speed(move, runup):
    if move in STANDING:
        return 0.0
    v = speed_after(runup)
    if move == "longjump":
        v *= LJ_KEEP
    if move == "triple":
        v = max(v, 21.0)
    return v
def _world(gap, rise, depth, takeoff_top=0.0):
    S = sim()
    boxes = [S.Box(-100000.0, 0.0, S.VOID, takeoff_top),
             S.Box(gap, gap + depth, S.VOID, rise),
             S.Box(-200000.0, 200000.0, S.VOID - 100, S.VOID)]
    return S.World(boxes)
def _fly(move, fv, x0, gap, rise, depth, stick, grab, dive_at=None, max_frames=240):
    S = sim()
    w = _world(gap, rise, depth)
    m = S.Mario(w, x0, 0.0, 1.0, fv)
    m.floor_h = 0.0
    m.set_action(_act(move))
    for f in range(max_frames):
        if dive_at is not None and f == dive_at and m.act in (S.JUMP, S.DOUBLE):
            m.set_action(S.DIVE)
        r = m.frame(True, False, stick)
        if r is not None:
            break
    if m.result == "ledge":
        return grab and move != "dive" and abs(m.y - rise) < 1.0 and m.x >= gap - 1
    return m.result == "landed" and abs(m.y - rise) < 1.0 and gap <= m.x <= gap + depth
STICKS = (1.0, 0.6, 0.3, 0.0, -0.5, -1.0)
def _lands(move, fv, x0, gap, rise, depth, grab, dive_at=None):
    return any(_fly(move, fv, x0, gap, rise, depth, s, grab, dive_at) for s in STICKS)
@functools.lru_cache(maxsize=20000)
def leeway(move, gap, rise=0, depth=600, runup=400, grab=True, dive_at=5, most=12):
    fv = launch_speed(move, runup)
    step = fv if fv > 0 else NUDGE
    da = dive_at if move == "dive" else None
    best = -1
    for k in range(most + 1):
        x0 = -(step * (k + 1)) if fv > 0 else -(1.0 + step * k)
        if not _lands(move, fv, x0, float(gap), float(rise), float(depth), grab, da):
            break
        best = k
    return best
def feasible(move, gap, rise=0, depth=600, runup=400, grab=True):
    return leeway(move, gap, rise, depth, runup, grab) >= 0
@functools.lru_cache(maxsize=4096)
def design_gap(move, rise, depth, runup, need, grab, lo=100, hi=3200, grid=50):
    top = min(hi, REACH_MAX.get(move, hi) + max(0, -rise))
    g = top // 100 * 100
    while g >= lo and leeway(move, g, rise, depth, runup, grab, most=need) < need:
        g -= 100
    if g < lo:
        return None
    best = g
    g += grid
    while g <= top and leeway(move, g, rise, depth, runup, grab, most=need) >= need:
        best = g
        g += grid
    return best
REACH_MAX = {"jump": 1100, "standjump": 700, "double": 1300, "triple": 1300, "longjump": 2000,
             "dive": 1400, "sideflip": 1100, "backflip": 700, "ride": 1100,
             "groundpound": 700}
def _climb_world(rise, at):
    S = sim()
    return S.World([S.Box(-100000.0, at, S.VOID, 0.0), S.Box(at, at + 100000.0, S.VOID, rise),
                     S.Box(-200000.0, 200000.0, S.VOID - 100, S.VOID)])
def _climbs(move, fv, d, rise, grab):
    S = sim()
    for stick in (1.0, 0.5, 0.0):
        m = S.Mario(_climb_world(rise, d), 0.0, 0.0, 1.0, fv)
        m.floor_h = 0.0
        m.set_action(_act(move))
        for _ in range(240):
            if m.frame(True, False, stick) is not None:
                break
        if m.result == "ledge" and grab and move not in ("triple", "backflip", "dive"):
            if abs(m.y - rise) < 1 and m.x >= d - 1:
                return True
        if m.result == "landed" and abs(m.y - rise) < 1:
            return True
    return False
@functools.lru_cache(maxsize=4096)
def climb_leeway(move, rise, runway=800, grab=True, most=12):
    best = -1
    run = 0
    fv0 = launch_speed(move, runway)
    step = max(fv0, NUDGE)
    d = 0.0
    while d <= runway:
        fv = launch_speed(move, max(0.0, runway - d))
        ok = _climbs(move, fv, d, float(rise), grab)
        run = run + 1 if ok else 0
        best = max(best, run - 1)
        if best >= most:
            break
        d += step
    return best
def chimney_row(width, policy):
    rows = movement._get(("measured", "chimney", policy, "by_width"), {}) or {}
    row = rows.get(str(int(width)))
    return row if isinstance(row, dict) and row.get("climbs") else None
POLICY = {
    "easy_late_kicks": (24.0, 5),
    "skilled_late_kicks": (24.0, 3),
}
@functools.lru_cache(maxsize=256)
def chimney_climb(width, policy):
    row = chimney_row(width, policy)
    if row is None:
        return None
    fv0, gap = POLICY[policy]
    r = sim().chimney(float(width), fv0, int(row["late"]), press_gap=gap,
                      stick=float(row["stick"]), hold=int(row["hold"]))
    if not r.get("climbs") or not r.get("gain"):
        return None
    return float(r["gain"]), float(r.get("frames_per_kick") or row["frames_per_kick"])
def kicks_for(height, width, policy):
    c = chimney_climb(width, policy)
    if c is None:
        return None
    gain = c[0]
    return max(1, int(math.ceil(max(0.0, height - movement.KICK_LAND) / gain)) + 1)
def _kickup(first, width, ledge, x0, late, stick_after):
    S = sim()
    w = S.World([S.Box(-100000.0, 0.0, S.VOID, ledge),
                 S.Box(0.0, width, S.VOID, 0.0),
                 S.Box(width, width + 100000.0, S.VOID, ledge + 3000.0),
                 S.Box(-200000.0, 200000.0, S.VOID - 100, S.VOID)])
    fv = 0.0 if first == "sideflip" else speed_after(max(0.0, width - x0 - 50))
    m = S.Mario(w, x0, 0.0, 1.0, fv)
    m.floor_h = 0.0
    m.set_action(_act(first))
    hit = None
    kicked = False
    for f in range(240):
        kick = False
        if not kicked:
            if m.act == S.AIRHITWALL:
                hit = f
                kick = late == 0
            elif m.act in (S.SOFTBONK, S.BACKKB) and hit is not None:
                kick = late > 0 and f - hit == late and m.wkt > 0
        if kick:
            kicked = True
        r = m.frame(True, kick, stick_after if kicked else 1.0, kick_now=kick)
        if r is not None:
            break
    if m.result == "ledge":
        return kicked and abs(m.y - ledge) < 1
    return kicked and m.result == "landed" and abs(m.y - ledge) < 1
@functools.lru_cache(maxsize=512)
def kickup_leeway(width, ledge, first="sideflip"):
    best = -1
    for x0 in range(60, int(width) - 60, NUDGE):
        good = 0
        for late in (1, 2, 3, 4):
            if any(_kickup(first, float(width), float(ledge), float(x0), late, s)
                   for s in (1.0, 0.0)):
                good += 1
        best = max(best, good - 1)
        if best >= 3:
            break
    return best
@functools.lru_cache(maxsize=1024)
def pound_window(gap, drop, post=200, runup=0, move="standjump"):
    S = sim()
    best = 0
    fv = launch_speed(move, runup)
    for stick in (0.0, 1.0):
        w = S.World([S.Box(-100000.0, 0.0, S.VOID, 0.0),
                     S.Box(-200000.0, 200000.0, S.VOID - 100, S.VOID)])
        m = S.Mario(w, -1.0, 0.0, 1.0, fv)
        m.floor_h = 0.0
        m.set_action(_act(move))
        frames = 0
        for _ in range(200):
            if m.frame(True, False, stick) is not None:
                break
            over = gap + 10 <= m.x <= gap + post - 10
            high = m.y > -drop + 50
            if over and high and not movement.fall_hurts(m.y + drop, pound=True):
                frames += 1
        best = max(best, frames)
    return best
@functools.lru_cache(maxsize=64)
def blj_leap(gap, rise=0, speed=-120.0):
    S = sim()
    w = _world(gap, rise, 4000.0)
    m = S.Mario(w, -1.0, 0.0, -1.0, speed)
    m.floor_h = 0.0
    m.set_action(S.LONGJUMP)
    for _ in range(240):
        if m.frame(True, False, 0.0) is not None:
            break
    return m.result == "landed" and abs(m.y - rise) < 1.0
@functools.lru_cache(maxsize=512)
def moving_window(move, runup, land, period, take=None, grab=False, takeoff_len=None,
                  fixed=False):
    S = sim()
    fv = launch_speed(move, runup)
    st = fv if fv > 0 else 1.0
    back = -float(takeoff_len or 100000.0)
    period = int(period)
    count = 0
    for t0 in range(period):
        top0 = float(take[t0 % period]) if take else 0.0
        landed = False
        for stick in (1.0, 0.0, -0.5):
            x0, x1, top = land[t0 % period]
            low = min(top0, top) - 300.0
            w = S.World([S.Box(back, 0.0, S.VOID, top0), S.Box(x0, x1, S.VOID, top),
                         S.Box(-200000.0, 200000.0, S.VOID - 100, S.VOID)])
            m = S.Mario(w, -st, top0, 1.0, fv)
            m.floor_h = top0
            m.set_action(_act(move))
            for f in range(1, 120):
                if not fixed:
                    x0, x1, top = land[(t0 + f) % period]
                    b = w.boxes[1]
                    b.x0, b.x1, b.top = float(x0), float(x1), float(top)
                    low = min(low, top - 300.0)
                if take:
                    w.boxes[0].top = float(take[(t0 + f) % period])
                r = m.frame(True, False, stick)
                if r is not None or m.y < low:
                    break
            if m.result == "ledge" and grab and m.x >= x0 - 1 and abs(m.y - top) < 30:
                landed = True
            elif m.result == "landed" and x0 - 1 <= m.x <= x1 + 1 and abs(m.y - top) < 30:
                landed = True
            if landed:
                break
        if landed:
            count += 1
    return count
def airtime(move, fv=None):
    name = {"jump": "single_run", "standjump": "single_standing", "double": "double_run",
            "triple": "triple_run", "longjump": "longjump_run", "sideflip": "sideflip",
            "backflip": "backflip", "dive": "single_run_dive", "ride": "single_run",
            "groundpound": "single_standing", "kickup": "sideflip",
            "blj": "longjump_run"}.get(move, "single_run")
    v = movement._get(("measured", "arcs", name, "frames"), 30)
    return int(v) if isinstance(v, (int, float)) else 30
SETUP_S = {"longjump": 0.25, "sideflip": 0.4, "backflip": 0.3, "dive": 0.1, "kickup": 0.6,
           "groundpound": 0.3, "double": 0.3, "triple": 0.6, "standjump": 0.2,
           "blj": 3.0}
MOVE_RISK = {"jump": 1.0, "standjump": 0.8, "double": 1.1, "triple": 1.3, "longjump": 1.3,
             "sideflip": 1.2, "backflip": 1.2, "wallkick": 1.4, "kickup": 1.6, "dive": 1.4,
             "groundpound": 1.5, "ride": 1.1, "blj": 2.5}
def fail_chance(tier, move, leeway_frames):
    p = tier.fail * MOVE_RISK.get(move, 1.0) * (0.5 ** max(0, leeway_frames))
    return max(0.002, min(0.85, p))
