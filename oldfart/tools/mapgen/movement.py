import json
import math
import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "..", "..", "docs", "learned", "movement", "movement.json")
SIM_PATH = os.path.join(HERE, "..", "..", "docs", "learned", "movement", "movement-sim.py")
FALLBACKS_USED = []
def _load():
    try:
        with open(PATH, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}
DATA = _load()
def _get(path, default=None):
    node = DATA
    for k in path:
        if not isinstance(node, dict) or k not in node:
            FALLBACKS_USED.append(".".join(path))
            return default
        node = node[k]
    if isinstance(node, dict) and "value" in node:
        node = node["value"]
    if node is None:
        FALLBACKS_USED.append(".".join(path))
        return default
    return node
def _num(path, default):
    v = _get(path, default)
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else default
def _sub(path, key, default):
    v = _get(path, {})
    if isinstance(v, dict) and isinstance(v.get(key), (int, float)):
        return v[key]
    FALLBACKS_USED.append(".".join(path) + "." + key)
    return default
FPS = 30
GRAVITY = float(_num(("air", "gravity"), 4))
TERMINAL = _num(("air", "terminal_fall"), -75)
def apex(v, g=GRAVITY):
    h = 0.0
    while v > 0:
        h += v
        v -= g
    return h
TALL = _num(("body", "height_standing"), 160)
TALL_CROUCH = _num(("body", "height_crouch_crawl"), 100)
STEP_MAX = int(_num(("clearances", "step_walked_up_max"), 24))
WALL_EDGE = STEP_MAX + 1
STAIR_RISER = int(_num(("design", "stairs_riser_max"), 20))
DROP_WALK = int(_num(("clearances", "drop_walked_off_without_leaving_ground"), 100))
CORRIDOR_MIN = int(_num(("clearances", "corridor_min_walk"), 100))
RUN = _num(("ground", "run_speed"), 32)
RUN_SLOW = _num(("ground", "run_speed_slow_surface"), 24)
GROUND_CAP = _num(("ground", "ground_speed_cap"), 48)
CRAWL = _num(("ground", "crawl_speed"), 3.2)
RUN_UP = _get(("ground", "run_up_to_full_speed"), {"frames": 40, "distance": 880})
LIP = int(_num(("ledge_grab", "lip_rule_land"), 25))
_GW = _get(("ledge_grab", "window_above_feet"), [100, 145])
GRAB_LO, GRAB_HI = (int(_GW[0]), int(_GW[1])) if isinstance(_GW, list) and len(_GW) == 2 else (100, 145)
GRABBING = tuple(_get(("ledge_grab", "actions_that_grab"),
                      ["single", "double", "side_flip", "wall_kick", "long_jump", "freefall",
                       "water_jump", "top_of_pole_jump"]))
FALL_HURTS = int(_num(("falls", "damage_threshold"), 1150))
FALL_HARD = int(_num(("falls", "hard_fall_threshold"), 3000))
DROP_SAFE = (FALL_HURTS - 1) // 100 * 100
_GP = _get(("jumps", "ground_pound"), {})
GROUND_POUND_HOVER = 110
if isinstance(_GP, dict):
    _m = re.search(r"up to (\d+) units", str(_GP.get("hover_rise", "")))
    if _m:
        GROUND_POUND_HOVER = int(_m.group(1))
GROUND_POUND_HURTS = "yes" in str(_GP.get("fall_damage", "yes")) if isinstance(_GP, dict) else True
def fall_hurts(drop, pound=False):
    if pound and GROUND_POUND_HURTS:
        drop += GROUND_POUND_HOVER
    return drop > FALL_HURTS
def _arc(name, key, default):
    v = _get(("measured", "arcs", name), {})
    if isinstance(v, dict) and isinstance(v.get(key), (int, float)):
        return v[key]
    FALLBACKS_USED.append("measured.arcs.%s.%s" % (name, key))
    return default
ARCS = {
    "single_standing": (_arc("single_standing", "apex", 242), _arc("single_standing", "distance", 298.7), True),
    "single_run": (_arc("single_run", "apex", 338), _arc("single_run", "distance", 838.2), True),
    "double_standing": (_arc("double_standing", "apex", 364), _arc("double_standing", "distance", 444.2), True),
    "double_run": (_arc("double_run", "apex", 480), _arc("double_run", "distance", 1013.0), True),
    "triple_run": (_arc("triple_run", "apex", 630), _arc("triple_run", "distance", 1173.5), False),
    "backflip": (_arc("backflip", "apex", 512), _arc("backflip", "distance", 479.2), False),
    "sideflip": (_arc("sideflip", "apex", 512), _arc("sideflip", "distance", 785.2), True),
    "wallkick": (_arc("wallkick_24", "apex", 512), _arc("wallkick_24", "distance", 1024.2), True),
    "longjump": (_arc("longjump_run", "apex", 240), _arc("longjump_run", "distance", 1546.9), True),
}
RUNNING_JUMP = int(round(ARCS["single_run"][1]))
LONG_JUMP = int(round(ARCS["longjump"][1]))
APEX_SINGLE = ARCS["single_run"][0]
APEX_DOUBLE = ARCS["double_run"][0]
APEX_TRIPLE = ARCS["triple_run"][0]
def land_reach(name):
    return ARCS[name][0] + LIP - 1
def grab_reach(name):
    a, _, grabs = ARCS[name]
    return a + GRAB_HI if grabs else None
def reaches(rise, name, falling_grab=True):
    if rise <= land_reach(name):
        return "land"
    g = grab_reach(name)
    if falling_grab and g is not None and rise <= g:
        return "grab"
    return None
def _wall_reach():
    best = 0
    for row in (_get(("measured", "wall_reach"), {}) or {}).values():
        if isinstance(row, dict):
            for k in ("land", "grab"):
                if isinstance(row.get(k), (int, float)):
                    best = max(best, row[k])
    return int(best) if best else 656
def _kick():
    text = str(_get(("wall_kick", "chimney_summary", "climbs_to"), ""))
    nums = [int(n) for n in re.findall(r"\+\s*(\d+)", text)]
    return max(nums) if nums else 632
REACH = _wall_reach()
KICK_REACH = _kick()
KICK_LAND = 512
_m = re.search(r"\+\s*(\d+)\s*\(land\)", str(_get(("wall_kick", "chimney_summary", "climbs_to"), "")))
if _m:
    KICK_LAND = int(_m.group(1))
CHIMNEY_MIN = int(_num(("wall_kick", "chimney_summary", "narrowest"), 101))
CHIMNEY_MAX = int(_num(("wall_kick", "chimney_summary", "widest_easy_late_kicks"), 1050))
CHIMNEY_MAX_FIRSTIE = int(_num(("wall_kick", "chimney_summary", "widest_frame_perfect_from_long_jump_48"), 1500))
_CS = _get(("design", "corridor_stops_chimney"), {})
KICK_GAP = int(_CS.get("vanilla_frame_perfect", 1550)) if isinstance(_CS, dict) else 1550
KICK_GAP_HUMAN = int(_CS.get("vanilla_human", 1100)) if isinstance(_CS, dict) else 1100
def chimney(width, frame_perfect=False):
    hi = KICK_GAP if frame_perfect else CHIMNEY_MAX
    return CHIMNEY_MIN <= width <= hi
def _reach_table():
    t = _get(("design", "reach_by_distance"), {})
    rows = t.get("run_grab") if isinstance(t, dict) else None
    if not isinstance(rows, dict) or not rows:
        FALLBACKS_USED.append("design.reach_by_distance.run_grab")
        rows = {"700": 656, "800": 550, "900": 450, "1000": 350, "1200": 300, "1400": 200,
                "1600": 100, "1800": 0, "2750": -1000}
    return sorted((float(k), float(v)) for k, v in rows.items())
REACH_TABLE = _reach_table()
def reach_at(d):
    tab = REACH_TABLE
    if d <= tab[0][0]:
        return tab[0][1]
    for (d0, r0), (d1, r1) in zip(tab, tab[1:]):
        if d <= d1:
            return r0 + (r1 - r0) * (d - d0) / (d1 - d0)
    (d0, r0), (d1, r1) = tab[-2], tab[-1]
    return r1 + (r1 - r0) * (d - d1) / (d1 - d0)
JUMP_GAP = int(REACH_TABLE[0][0]) if REACH_TABLE[0][1] >= REACH else 400
GAPS = {k: _sub(("design", "gaps_flat"), k, v) for k, v in
        (("easy", 500), ("medium", 750), ("hard", 1200), ("expert_shortcut", 1450),
         ("impossible_over", 1850))}
GAPS_UP_200 = {k: _sub(("design", "gaps_up_200"), k, v) for k, v in
               (("easy", 400), ("medium", 650), ("hard", 1000))}
RISES = {k: _sub(("design", "rise_one_jump"), k, v) for k, v in
         (("easy", 200), ("medium", 330), ("hard", 480), ("max_land_flat", 653),
          ("max_grab_flat", 656))}
DEPTHS = {k: _sub(("design", "platform_depth"), k, v) for k, v in
          (("landing_running_jump", 400), ("landing_long_jump", 600), ("standing_spot", 200),
           ("min_ledge_grab_side", 110))}
WADE_MAX = int(_num(("design", "water_wade_max_depth"), 100))
HEADROOM_JUMP = int(_num(("clearances", "headroom_single_run_jump"), 498))
HEADROOM_TRIPLE = int(_num(("clearances", "headroom_triple"), 790))
DESIGN_GAPS = (GAPS["easy"], GAPS["medium"], GAPS["hard"], GAPS["expert_shortcut"])
DESIGN_RISES = (RISES["easy"], RISES["medium"], RISES["hard"])
DESIGN_DEPTHS = (DEPTHS["landing_running_jump"], DEPTHS["landing_long_jump"])
_B = _get(("design", "boundary_height_over_launch"), {})
BOUNDARY_SAFE = int(_B.get("safe", 700)) if isinstance(_B, dict) else 700
BOUNDARY_BOUNCE = int(_B.get("safe_with_partner_bounce", 1450)) if isinstance(_B, dict) else 1450
def _partner():
    for t in _get(("tricks",), []) or []:
        if isinstance(t, dict) and "partner" in str(t.get("name", "")):
            nums = [int(n) for n in re.findall(r"(\d+)\s+above", str(t.get("gain", "")))]
            if nums:
                return max(nums)
            nums = [int(n) for n in re.findall(r"-(\d+)", str(t.get("gain", "")))]
            if nums:
                return max(nums)
    FALLBACKS_USED.append("tricks.partner bounce")
    return 1400
PARTNER_BOUNCE = _partner()
def _row_name(text):
    return re.split(r"\s*\(", str(text).strip())[0].strip().strip(".")
def _unbounded():
    out = {}
    for item in _get(("mod_changes", "unbounded"), []) or []:
        head, _, rest = str(item).partition(":")
        for name in rest.split(","):
            name = _row_name(name)
            if name:
                out[name] = head.strip()
    bounded = _get(("mod_changes", "bounded"), {}) or {}
    for key, row in bounded.items() if isinstance(bounded, dict) else ():
        if isinstance(row, dict) and "unbounded" in str(row.get("note", "")):
            for name in key.split(".", 1)[-1].split("/"):
                out[_row_name(name)] = key.split(".")[0]
    return out
UNBOUNDED = _unbounded()
def _bounded():
    out = {}
    rows = _get(("mod_changes", "bounded"), {}) or {}
    for key, row in rows.items() if isinstance(rows, dict) else ():
        if not isinstance(row, dict):
            continue
        group, _, name = key.partition(".")
        name = _row_name(name)
        best = None
        for field in ("apex", "apex_per_kick"):
            nums = [v for v in row.get(field) or [] if isinstance(v, (int, float))]
            if nums:
                best = max(nums)
        if isinstance(row.get("per_jump_apex"), (int, float)):
            counts = [c for c in row.get("count") or [1] if isinstance(c, (int, float)) and c < 99]
            best = row["per_jump_apex"] * max(counts or [1])
        if isinstance(row.get("fall_scale"), list):
            scales = sorted(v for v in row["fall_scale"] if isinstance(v, (int, float)) and v > 0)
            if len(scales) >= 2:
                best = APEX_TRIPLE / scales[1]
        m = re.search(r"apex (\d+)", str(row.get("note", "")))
        if m:
            best = int(m.group(1))
            if group == "powerups" and name == "triple":
                name = "wingtriple"
        if best is not None:
            out[name] = best
    return out
BOUNDED = _bounded()
class Rules(object):
    def __init__(self, interactions=True, rows=()):
        self.interactions = bool(interactions)
        self.rows = tuple(str(r) for r in rows or ())
    @classmethod
    def of(cls, arena_or_brief):
        mv = (arena_or_brief or {}).get("movement") if isinstance(arena_or_brief, dict) else None
        if not isinstance(mv, dict):
            return cls()
        return cls(mv.get("interactions", True), mv.get("rows") or ())
    @property
    def flight(self):
        return any(_row_name(r) in UNBOUNDED for r in self.rows)
    @property
    def extra_rise(self):
        best = REACH
        for r in self.rows:
            r = _row_name(r)
            if r in BOUNDED:
                best = max(best, BOUNDED[r] + GRAB_HI)
        return best - REACH
    def reach(self):
        if self.flight:
            return float("inf")
        r = REACH + self.extra_rise
        if self.interactions:
            r = max(r, PARTNER_BOUNCE)
        return r
    def boundary(self):
        if self.flight:
            return float("inf")
        need = BOUNDARY_BOUNCE if self.interactions else BOUNDARY_SAFE
        return max(need, self.reach() - REACH + BOUNDARY_SAFE)
VANILLA = Rules(interactions=False)
def table():
    return {
        "STEP_MAX": STEP_MAX, "WALL_EDGE": WALL_EDGE, "STAIR_RISER": STAIR_RISER,
        "LIP": LIP, "GRAB": (GRAB_LO, GRAB_HI), "RUN": RUN, "TALL": TALL,
        "RUNNING_JUMP": RUNNING_JUMP, "LONG_JUMP": LONG_JUMP,
        "APEX": (APEX_SINGLE, APEX_DOUBLE, APEX_TRIPLE), "REACH": REACH,
        "KICK_REACH": KICK_REACH, "CHIMNEY": (CHIMNEY_MIN, CHIMNEY_MAX), "KICK_GAP": KICK_GAP,
        "DROP_SAFE": DROP_SAFE, "FALL_HURTS": FALL_HURTS, "GROUND_POUND_HOVER": GROUND_POUND_HOVER,
        "GAPS": DESIGN_GAPS, "RISES": DESIGN_RISES, "DEPTHS": DESIGN_DEPTHS, "WADE_MAX": WADE_MAX,
        "PARTNER_BOUNCE": PARTNER_BOUNCE, "BOUNDARY_SAFE": BOUNDARY_SAFE,
        "BOUNDARY_BOUNCE": BOUNDARY_BOUNCE,
    }
def sim_module():
    import importlib.util
    spec = importlib.util.spec_from_file_location("movement_sim", SIM_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
