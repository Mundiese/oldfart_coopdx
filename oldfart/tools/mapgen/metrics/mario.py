from .. import movement
RUN = movement.RUN
FPS = movement.FPS
SPEED = RUN * FPS
STARTUP = 18
SHELL_SPEED = int(movement._num(("swim", "shell_speed"), 64)) * FPS
RAMP_SLOPE = 0.5
STEP_WALK = movement.STAIR_RISER
STEP_UP = movement.STEP_MAX
WALL_EDGE = movement.WALL_EDGE
JUMP_SAFE = movement.RISES["easy"]
JUMP_DOUBLE = movement.RISES["medium"]
JUMP_TRIPLE = movement.RISES["hard"]
GAP_SAFE = movement.GAPS["easy"]
GAP_RUN = movement.GAPS["medium"]
GAP_LONG = movement.GAPS["hard"]
GAP_EXPERT = movement.GAPS["expert_shortcut"]
GAP_IMPOSSIBLE = movement.GAPS["impossible_over"]
DROP_SAFE = movement.DROP_SAFE
HEADROOM = movement.HEADROOM_JUMP
CAMERA_ROOF = movement.HEADROOM_TRIPLE
LANE_MIN = 400
SPAWN_WALL = 500
SIGHT_FIGHT = 2400
EYE = 120
COVER_TALL = 100
CELL = 100
MARIO_TALL = movement.TALL
def path_time_s(cells):
    return (cells * CELL / RUN + STARTUP) / FPS
def distance_time_s(units, speed=SPEED):
    return units / float(speed) + STARTUP / float(FPS)
def rise_class(rise, slope=0.0):
    if rise <= STEP_UP or (slope > 0 and rise <= slope + STEP_UP):
        return 0
    if rise <= JUMP_SAFE:
        return 1
    if rise <= JUMP_DOUBLE:
        return 2
    if rise <= JUMP_TRIPLE:
        return 3
    return 4
def _drop_bonus(drop):
    env = movement._get(("measured", "gap_envelope", "moves", "single_run", "with_ledge_grab"), {})
    if not isinstance(env, dict) or drop <= 0:
        return 0.0
    pts = sorted((-float(k), v) for k, v in env.items()
                 if isinstance(v, (int, float)) and float(k) <= 0)
    if not pts:
        return 0.0
    base = pts[0][1]
    best = 0.0
    for d, v in pts:
        if d <= drop:
            best = v - base
    return best
def gap_class(gap, drop=0):
    if gap <= 0:
        return 0
    g = gap - _drop_bonus(drop)
    if g <= GAP_RUN:
        return 1
    if g <= GAP_LONG:
        return 2
    if g <= GAP_EXPERT:
        return 3
    return 4
WALK_HALF = RUN / 2.0
TIPTOE = 8
