FAMILIES = ("shooter", "objective", "knockoff", "race", "hide", "party", "course", "explore")
FAMILY_ALIASES = {
    "a": "shooter", "deathmatch": "shooter", "arena": "shooter", "shooter": "shooter",
    "b": "objective", "t": "objective", "capture": "objective", "ctf": "objective",
    "objective": "objective", "domination": "objective", "koth": "objective",
    "c": "knockoff", "p": "knockoff", "sumo": "knockoff", "knockoff": "knockoff",
    "d": "race", "r": "race", "race": "race",
    "e": "hide", "h": "hide", "hide": "hide", "chase": "hide",
    "explore": "explore", "travel": "explore", "world": "explore",
    "f": "party", "party": "party",
    "g": "course", "course": "course", "obstacle": "course", "coop": "course",
}
GROUPS = ("flow", "time", "sight", "spawn safety", "height", "fairness", "objective",
          "race", "fun", "cost", "beauty")
def family_of(name):
    if not name:
        return "shooter"
    key = str(name).strip().lower()
    if key not in FAMILY_ALIASES:
        raise KeyError("unknown family %r" % name)
    return FAMILY_ALIASES[key]
class Band(object):
    def __init__(self, lo=None, hi=None, weight=1.0, group="flow", soft=None, note="",
                 tier="cheap", label=None, warn_only=None):
        self.warn_only = (tier == "sim") if warn_only is None else bool(warn_only)
        self.lo, self.hi = lo, hi
        self.weight = weight
        self.group = group
        self.soft = soft
        self.note = note
        self.tier = tier
        self.label = label
    def width(self):
        if self.soft is not None:
            return float(self.soft)
        if self.lo is not None and self.hi is not None and self.hi > self.lo:
            return float(self.hi - self.lo)
        bound = self.hi if self.hi is not None else self.lo
        return max(abs(bound) * 0.5, 1.0)
    def closeness(self, value):
        if value is None:
            return None
        if isinstance(value, (list, tuple)):
            vals = [v for v in value if isinstance(v, (int, float))]
            if not vals:
                return None
            return min(self.closeness(v) for v in vals)
        if isinstance(value, bool):
            value = 1.0 if value else 0.0
        out = 0.0
        if self.lo is not None and value < self.lo:
            out = self.lo - value
        elif self.hi is not None and value > self.hi:
            out = value - self.hi
        if out <= 0:
            return 1.0
        return max(0.0, 1.0 - out / self.width())
    def text(self):
        if self.lo is not None and self.hi is not None:
            return "%s-%s" % (fmt(self.lo), fmt(self.hi)) if self.lo != self.hi else "= %s" % fmt(self.lo)
        if self.lo is not None:
            return ">= %s" % fmt(self.lo)
        if self.hi is not None:
            return "<= %s" % fmt(self.hi)
        return "-"
    def as_dict(self):
        return {"lo": self.lo, "hi": self.hi, "weight": self.weight, "group": self.group,
                "tier": self.tier, "text": self.text(), "note": self.note,
                "warn_only": self.warn_only}
def fmt(v):
    if isinstance(v, float):
        if abs(v) < 1:
            return ("%.2f" % v).rstrip("0").rstrip(".")
        return ("%.1f" % v).rstrip("0").rstrip(".")
    return str(v)
def status(closeness, warn_only=False):
    if closeness is None:
        return "n/a"
    if closeness >= 1.0:
        return "pass"
    if closeness >= 0.5 or warn_only:
        return "warn"
    return "fail"
B = Band
E = "expensive"
S = "sim"
_FIGHT = {
    "sim_kill_entropy": B(0.9, None, 2, "fairness", soft=0.2, tier=S),
    "sim_spawn_kill_share": B(None, 0.10, 2, "spawn safety", soft=0.1, tier=S),
    "sim_unused_floor": B(None, 0.30, 1, "flow", soft=0.2, tier=S),
    "sim_kill_hotspot_share": B(None, 0.15, 1, "fairness", soft=0.1, tier=S),
    "sim_kill_spread": B(0.7, None, 1, "flow", soft=0.3, tier=S),
    "dead_ends": B(0, 0, 3, "flow", soft=2),
    "cycle_cover": B(0.9, None, 3, "flow", soft=0.3),
    "jump_class_needed": B(None, 1, 2, "height", soft=1),
}
_RHYTHM = {
    "sim_rh_fight_share": B(0.28, 0.38, 2, "flow", soft=0.1, tier=S,
                            note="fights in episodes, not a carpet"),
    "sim_rh_calm_p50_s": B(2.6, 3.6, 1, "flow", soft=1.0, tier=S, note="calm gaps, median"),
    "sim_rh_calm_p90_s": B(6.5, 9.5, 1, "flow", soft=2.0, tier=S, note="calm gaps, p90"),
    "sim_rh_calm_over_20_share": B(None, 0.10, 1, "flow", soft=0.1, tier=S,
                                   note="calm over 20 s"),
    "sim_rh_unseen_p90_s": B(None, 25, 1, "flow", soft=10, tier=S, note="no dead stretches"),
    "sim_rh_fight_hotspot": B(None, 0.55, 1, "fairness", soft=0.2, tier=S,
                              note="peaks spread in space"),
    "sim_rh_fight_places": B(2, None, 1, "flow", soft=2, tier=S,
                             note="the loop repeats in different places"),
    "sim_rh_ambush_share": B(0.2, 0.4, 1, "sight", soft=0.15, tier=S,
                             note="ambush corners, not an ambush map"),
}
F = "fun"
def _fun(**rows):
    return rows
_LF = _fun(
    lf1_viable_routes=B(2, 4, 2, F, soft=1,
                        note="a choice of ways: routes within 1.3x the fastest (more than 4 is a guess map)"),
    lf3_flank_unseen=B(0.6, None, 1, F, soft=0.4, tier=E,
                       note="a flank is out of sight of the spots that hold the main way"),
    lf4_flank_angle=B(60, None, 1, F, soft=40, tier=E,
                      note="a flank arrives from the side, not down the main way"),
)
_CB = _fun(
    cb1_home_ratio=B(None, 0.7, 2, F, soft=0.3,
                     note="the side losing ground has the shorter trip to the fight"),
    cb2_unseen_exits=B(2, None, 2, F, soft=2, tier=E,
                       note="no pen: one camper never covers every way out of a base"),
)
_VM_UNIT = _fun(vm1_per_unit=B(2, None, 1, F, soft=2,
                               note="SM64's moves pay: shortcuts per symmetry unit"))
_THEME = _fun(vm3_theme_share=B(0.5, None, 1, F, soft=0.3,
                                note="one movement theme carries the shortcuts"))
_SL = _fun(sl_real_choices=B(1, None, 1, F, soft=1,
                             note="a risky short way and a safe long way, neither dominating"))
_GP = _fun(
    gp1_move_share=B(0.7, None, 2, F, soft=0.4,
                     note="a goal costs a move (SM64: 87 % of 68 stars) [M]"),
    gp1_walkable_near_start=B(1, None, 1, F, soft=1,
                              note="one goal walked to near the start (onboarding)"),
    gp2_height_span=B(0.6, None, 1, F, soft=0.4,
                      note="the goals span the world's height (SM64: a course's height) [M]"),
    gp3_above_share=B(0.25, None, 1, F, soft=0.25,
                      note="goals pull up the mountain (SM64: 40 % above) [M]"),
    gp3_below_share=B(0.25, None, 1, F, soft=0.25,
                      note="goals pull down into the pit (SM64: 38 % below) [M]"),
    gp4_nearest_s=B(None, 4, 1, F, soft=4, note="the nearest goal is seconds away (SM64 p10 2.9 s) [M]"),
    gp4_farthest_s=B(12, 20, 1, F, soft=8, note="the farthest is a trip (SM64 p90 15.2 s) [M]"),
)
_SEEK = _fun(
    sim_hs9_found_share=B(0.9, None, 1, F, soft=0.3, tier=S,
                          note="a full seeker sweep finds the hiding places"),
    sim_hs9_find_frac=B(0.35, 0.65, 1, F, soft=0.3, tier=S,
                        note="places are found through the round, not at once"),
    sim_hs9_survive_share=B(0.1, 0.4, 1, F, soft=0.2, tier=S,
                            note="two seekers leave 10-40 % of the hiders after 3 minutes"),
)
TARGETS = {
    "shooter": dict(_FIGHT, **dict(_RHYTHM, **dict(_LF, **dict(_CB, **dict(_VM_UNIT, **{
        "spawn_to_centre_s": B(4, 7, 2, "time"),
        "spawn_to_enemy_spawn_s": B(3.5, None, 3, "time", soft=1.5),
        "meet_time_s": B(2, 5, 1, "time"),
        "time_to_contact_s": B(2, 5, 2, "time", tier=E),
        "open_pairs_over_2400": B(None, 0.08, 3, "sight", soft=0.08, tier=E),
        "sightline_p95": B(None, 3500, 1, "sight", soft=1500, tier=E),
        "sightline_max": B(None, 7000, 1, "sight", soft=3000, tier=E),
        "cover_within_300": B(0.6, 0.8, 2, "sight"),
        "spawn_exposure_mean": B(None, 0.15, 3, "spawn safety", soft=0.1, tier=E),
        "spawn_exposure_max": B(None, 0.20, 2, "spawn safety", soft=0.1, tier=E),
        "spawn_kill_risk": B(None, 0, 2, "spawn safety", soft=4, tier=E),
        "field_spawn_exposure_max": B(None, 0.20, 2, "spawn safety", soft=0.15, tier=E),
        "spawn_front_cover": B(0.5, None, 1, "spawn safety", soft=0.5),
        "spawn_back_clear": B(0.5, None, 1, "spawn safety", soft=0.5),
        "layers": B(2, 3, 2, "height", soft=1),
        "high_ground_share": B(0.15, 0.35, 1, "height"),
        "climb_routes_per_high_point": B(2, None, 2, "height", soft=1),
        "exits_per_base": B(3, None, 3, "flow", soft=2),
        "lanes_between_bases": B(2, 3, 2, "flow", soft=1),
        "chokes": B(None, 4, 1, "flow", soft=3),
        "landmark_visible_from_spawns": B(0.5, None, 1, "sight", soft=0.5,
                                          note="a landmark the spawns can see (the Sky Keep: half)"),
        "area_per_player": B(1.8e6, 3.0e6, 1, "cost"),
        "spawn_equity": B(None, 0.15, 2, "fairness", soft=0.15),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.6, None, 1, "beauty", soft=0.4),
    }))))),
    "objective": dict(_FIGHT, **dict(_LF, **dict(_CB, **dict(_VM_UNIT, **{
        "lf1_viable_routes": B(3, 4, 2, F, soft=1,
                               note="three ways onto every objective (more than 4 is a guess map)"),
        "sim_rh_fight_share": B(0.18, 0.35, 1, "flow", soft=0.1, tier=S,
                                note="fights in episodes, calmer than a shooter"),
        "sim_rh_unseen_p90_s": B(None, 40, 1, "flow", soft=15, tier=S, note="no dead stretches"),
        "flag_to_flag_s": B(9, 14, 3, "objective"),
        "own_spawn_to_own_flag_s": B(None, 3, 2, "objective", soft=2),
        "enemy_spawn_to_flag_s": B(9, None, 2, "objective", soft=4),
        "side_time_gap": B(None, 0.05, 3, "fairness", soft=0.1),
        "point_to_point_s": B(3, 6, 1, "objective"),
        "base_to_nearest_point_s": B(2, 4, 1, "objective", soft=2),
        "base_to_centre_s": B(5, 8, 1, "objective"),
        "hill_approaches": B(4, None, 2, "objective", soft=2),
        "lanes_between_bases": B(3, 3, 2, "flow", soft=1),
        "exits_per_base": B(3, None, 3, "flow", soft=2),
        "open_pairs_over_2400": B(None, 0.10, 3, "sight", soft=0.1, tier=E),
        "spawn_exposure_mean": B(None, 0.20, 3, "spawn safety", soft=0.1, tier=E),
        "spawn_kill_risk": B(None, 0, 2, "spawn safety", soft=4, tier=E),
        "cover_within_300": B(0.6, None, 2, "sight", soft=0.3),
        "landmark_visible_from_spawns": B(0.5, None, 1, "sight", soft=0.5,
                                          note="a landmark the spawns can see (the Sky Keep: half)"),
        "layers": B(2, 3, 1, "height", soft=1),
        "spawn_equity": B(None, 0.15, 1, "fairness", soft=0.15),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.6, None, 1, "beauty", soft=0.4),
    })))),
    "knockoff": {
        "ring_radius": B(1100, 1600, 3, "objective", soft=500),
        "spawn_to_centre_s": B(None, 4, 2, "time", soft=2),
        "tiers": B(1, 3, 1, "height", soft=1),
        "ways_up_per_tier": B(2, None, 2, "flow", soft=2),
        "ring_cover": B(None, 0.0, 2, "sight", soft=0.2, label="cover on the ring"),
        "jump_class_needed": B(None, 1, 1, "height", soft=1),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.5, None, 1, "beauty", soft=0.4),
    },
    "race": {
        "lap_s": B(30, 45, 3, "race"),
        "gates_per_lap": B(15, 30, 1, "race", soft=8),
        "longest_straight": B(None, 12000, 1, "race", soft=6000),
        "elevation_range": B(400, None, 1, "height", soft=400),
        "road_width_min": B(1400, None, 2, "race", soft=600),
        "markers_ok": B(1, 1, 3, "race", soft=1, label="markers pass v1's check"),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.5, None, 1, "beauty", soft=0.4),
    },
    "hide": dict(_FIGHT, **dict(_SEEK, **dict(_THEME, **dict(_SL, **{
        "lf1_viable_routes": B(2, None, 1, F, soft=1,
                               note="a chase has more than one way round"),
        "vm1_shortcuts": B(4, None, 1, F, soft=3,
                           note="moves pay: a wall-kick roof, a long-jump cut (>= 4 a map)"),
        "hiding_share": B(0.15, None, 3, "sight", soft=0.15, tier=E),
        "vantage_points": B(2, None, 2, "height", soft=2),
        "area_per_player": B(3.0e6, 6.0e6, 1, "cost"),
        "cover_within_300": B(0.7, None, 2, "sight", soft=0.3),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.6, None, 1, "beauty", soft=0.4),
    })))),
    "party": {
        "area_per_player": B(0.25e6, 0.4e6, 3, "cost"),
        "spawn_spacing_min": B(300, None, 2, "spawn safety", soft=200),
        "floor_height_range": B(None, 50, 2, "height", soft=200),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.5, None, 1, "beauty", soft=0.4),
    },
    "explore": dict(_GP, **dict(_THEME, **dict(_SL, **{
        "vm1_per_district": B(1, None, 1, F, soft=1,
                              note="a move-gated shortcut in every district"),
        "districts": B(4, None, 2, "flow", soft=3),
        "district_kinds": B(4, None, 2, "beauty", soft=2),
        "landmarks": B(1, None, 2, "sight", soft=1),
        "landmark_seen": B(0.6, None, 2, "sight", soft=0.4),
        "cycle_cover": B(0.7, None, 3, "flow", soft=0.4),
        "dead_ends": B(0, 0, 2, "flow", soft=4),
        "stars": B(5, None, 2, "objective", soft=3),
        "star_districts": B(0.8, None, 2, "objective", soft=0.4),
        "star_spread": B(0.2, None, 2, "objective", soft=0.15),
        "star_kinds": B(4, None, 2, "objective", soft=2),
        "star_challenge_mix": B(1.0, None, 2, "objective", soft=0.5),
        "height_bands": B(3, None, 2, "height", soft=2),
        "vantage_points": B(2, None, 1, "height", soft=2),
        "jump_class_needed": B(None, 1, 1, "height", soft=1),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.5, None, 1, "beauty", soft=0.4),
    }))),
    "course": dict(_THEME, **dict(_SL, **{
        "course_s": B(45, 120, 3, "time"),
        "rest_interval_s": B(8, 15, 2, "time"),
        "jump_class_needed": B(None, 3, 2, "height", soft=1),
        "pieces_share": B(None, 1.0, 1, "cost", soft=0.25, label="pieces / budget"),
        "beauty": B(0.5, None, 1, "beauty", soft=0.4),
    })),
}
LABELS = {
    "spawn_to_centre_s": "spawn to centre (s, min-max)",
    "spawn_to_enemy_spawn_s": "nearest enemy base (s)",
    "meet_time_s": "first meeting on foot (s)",
    "time_to_contact_s": "time to first sight contact (s)",
    "open_pairs_over_2400": "floor pairs open past 2400",
    "sightline_p95": "open lines, 95th percentile",
    "sightline_max": "longest open line",
    "cover_within_300": "floor with cover within 300",
    "spawn_exposure_mean": "spawn exposure, mean",
    "spawn_exposure_max": "spawn exposure, worst spawn",
    "spawn_kill_risk": "spawns at spawn-kill risk",
    "field_spawn_exposure_max": "field spawn exposure, worst",
    "spawn_front_cover": "spawns with cover in front",
    "spawn_back_clear": "spawns with a clear back (camera)",
    "layers": "height layers",
    "high_ground_share": "high ground share",
    "climb_routes_per_high_point": "ways up each high point (min)",
    "exits_per_base": "exits per base (min)",
    "lanes_between_bases": "lanes between bases",
    "chokes": "chokes (cuts under 600 wide)",
    "landmark_visible_from_spawns": "spawns that see the landmark",
    "area_per_player": "floor per player (units^2)",
    "spawn_equity": "spawn equity (spread / mean)",
    "dead_ends": "dead ends",
    "cycle_cover": "floor on a loop",
    "jump_class_needed": "jump class the walk needs",
    "flag_to_flag_s": "flag to flag (s)",
    "own_spawn_to_own_flag_s": "own spawn to own flag (s)",
    "enemy_spawn_to_flag_s": "enemy spawn to flag (s)",
    "side_time_gap": "side time gap",
    "point_to_point_s": "point to point (s, min-max)",
    "base_to_nearest_point_s": "base to nearest point (s)",
    "base_to_centre_s": "base to centre (s)",
    "hill_approaches": "ways onto the hill",
    "ring_radius": "ring radius",
    "tiers": "tiers",
    "ways_up_per_tier": "ways up per tier (min)",
    "ring_cover": "cover on the ring",
    "lap_s": "lap on a shell (s)",
    "gates_per_lap": "gates per lap",
    "longest_straight": "longest gate-to-gate straight",
    "elevation_range": "elevation range of the gates",
    "road_width_min": "narrowest road",
    "markers_ok": "race markers valid",
    "hiding_share": "hiding cells share",
    "districts": "districts",
    "district_kinds": "kinds of district",
    "landmarks": "landmarks (spires)",
    "landmark_seen": "districts that see a landmark",
    "reached_share": "floor the walk reaches",
    "stars": "bonus stars",
    "star_districts": "stars in different districts",
    "star_spread": "closest two stars / half the world",
    "star_kinds": "kinds of star route",
    "star_challenge_mix": "challenge mix (one easy, two or three tricky)",
    "height_bands": "height bands to look from",
    "vantage_points": "vantage points",
    "spawn_spacing_min": "closest two spawns",
    "floor_height_range": "play floor height range",
    "course_s": "course time (s)",
    "rest_interval_s": "between rests (s, max)",
    "pieces_share": "pieces / budget",
    "sim_kill_entropy": "bots: kill balance (entropy)",
    "sim_spawn_kill_share": "bots: deaths within 3 s of spawning",
    "sim_unused_floor": "bots: floor never visited",
    "sim_kill_hotspot_share": "bots: kills in the busiest 800 square",
    "sim_kill_spread": "bots: kill-position spread",
    "sim_rh_fight_share": "bots: time in a fight",
    "sim_rh_calm_p50_s": "bots: calm gap, median s",
    "sim_rh_calm_p90_s": "bots: calm gap, 90th percentile s",
    "sim_rh_calm_over_20_share": "bots: calm gaps over 20 s",
    "sim_rh_unseen_p90_s": "bots: longest stretch with no enemy seen",
    "sim_rh_fight_hotspot": "bots: fights in the busiest 15% of floor",
    "sim_rh_fight_places": "bots: places holding 10% of the fights",
    "sim_rh_ambush_share": "bots: first sightings under 800",
    "beauty": "beauty score",
    "lf1_viable_routes": "ways within 1.3x the fastest",
    "lf3_flank_unseen": "flank unseen from the hold spots",
    "lf4_flank_angle": "flank's angle off the main way",
    "cb1_home_ratio": "home trip / away trip at a 25 % front",
    "cb2_unseen_exits": "base exits one camper cannot see",
    "vm1_shortcuts": "move-gated shortcuts",
    "vm1_per_unit": "move-gated shortcuts per symmetry unit",
    "vm1_per_district": "move-gated shortcuts per district",
    "vm3_theme_share": "shortcuts sharing one move",
    "sl_real_choices": "risky/safe splits that are real choices",
    "gp1_move_share": "goals that cost a move",
    "gp1_walkable_near_start": "a goal walked to near the start",
    "gp2_height_span": "goals' height span / the world's",
    "gp3_above_share": "goals 300 above the spawn",
    "gp3_below_share": "goals 300 below the spawn",
    "gp4_nearest_s": "nearest goal, straight run",
    "gp4_farthest_s": "farthest goal, straight run",
    "sim_hs9_found_share": "seekers: hiding places found",
    "sim_hs9_find_frac": "seekers: median find, share of the round",
    "sim_hs9_survive_share": "seekers: hiders left after 3 min",
}
REFERENCE = {
    "shooter": "skykeep",
    "objective": None,
    "knockoff": None,
    "race": None,
    "hide": "skykeep",
    "party": None,
    "course": None,
    "explore": None,
}
SIZE_SCALE = {"tiny": 0.7, "small": 0.85, "medium": 1.0, "large": 1.2, "huge": 1.45,
              "gigantic": 1.9}
SIZE_SCALED = {
    "spawn_to_centre_s": 1, "meet_time_s": 1, "time_to_contact_s": 1,
    "sightline_p95": 1, "sightline_max": 1, "area_per_player": 2,
    "flag_to_flag_s": 1, "enemy_spawn_to_flag_s": 1, "base_to_centre_s": 1,
    "point_to_point_s": 1, "base_to_nearest_point_s": 1,
    "ring_radius": 1, "longest_straight": 1, "lap_s": 1,
    "spawn_spacing_min": 1,
}
FAMILY_SIZE_SCALE = {
    "objective": {"tiny": 1.0, "small": 1.0, "gigantic": 1.75},
    "knockoff": {"tiny": 0.6, "small": 0.77, "large": 1.26, "huge": 1.42, "gigantic": 1.42},
    "race": {"tiny": 0.8, "small": 0.9, "large": 1.06, "huge": 1.14, "gigantic": 1.14},
    "party": {"tiny": 0.63, "small": 0.82, "large": 1.27, "huge": 1.55, "gigantic": 3.0},
    "hide": {"large": 1.17, "huge": 1.33, "gigantic": 3.4},
}
def size_factor(family, size):
    tier = size_tier(size)
    if not tier:
        return 1.0
    fam = family_of(family)
    return FAMILY_SIZE_SCALE.get(fam, {}).get(tier, SIZE_SCALE.get(tier, 1.0))
def size_tier(size):
    if size is None:
        return None
    try:
        from .. import budget
        return budget.tier_of(size)
    except Exception:
        return size if size in SIZE_SCALE else None
def scaled(band, power, factor):
    k = factor ** power
    if k == 1.0:
        return band
    return Band(None if band.lo is None else _round(band.lo * k),
                None if band.hi is None else _round(band.hi * k), band.weight, band.group,
                None if band.soft is None else _round(band.soft * k), band.note, band.tier,
                band.label, band.warn_only)
def _round(v):
    return round(v, 2) if abs(v) < 100 else round(v)
def bands(family, size=None):
    base = TARGETS[family_of(family)]
    factor = size_factor(family, size)
    if factor == 1.0:
        return base
    return {name: (scaled(b, SIZE_SCALED[name], factor) if name in SIZE_SCALED else b)
            for name, b in base.items()}
def score(metrics, family, size=None):
    rows = {}
    num = den = 0.0
    for name, band in bands(family, size).items():
        value = metrics.get(name)
        c = band.closeness(value)
        rows[name] = {"value": value, "band": band.text(), "lo": band.lo, "hi": band.hi, "closeness": c,
                      "status": status(c, band.warn_only), "weight": band.weight, "group": band.group,
                      "tier": band.tier, "label": band.label or LABELS.get(name, name),
                      "warn_only": band.warn_only, "note": band.note}
        if c is not None and not band.warn_only:
            num += band.weight * c
            den += band.weight
    quality = num / den if den else None
    return rows, quality
