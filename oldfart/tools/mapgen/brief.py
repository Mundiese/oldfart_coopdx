import copy
import hashlib
import json
import re
VERSION = 1
FAMILIES = ("shooter", "objective", "knockoff", "race", "hide", "party", "course",
            "explore")
FAMILY_ALIASES = {
    "deathmatch": "shooter", "dm": "shooter", "ffa": "shooter", "a": "shooter",
    "capture": "objective", "ctf": "objective", "domination": "objective", "b": "objective",
    "sumo": "knockoff", "knock-off": "knockoff", "c": "knockoff",
    "racing": "race", "d": "race",
    "hide-and-seek": "hide", "hunt": "hide", "chase": "hide", "e": "hide",
    "platform": "party", "f": "party",
    "coop": "course", "co-op": "course", "obstacle": "course", "g": "course",
    "travel": "explore", "world": "explore", "roam": "explore", "h": "explore",
}
BUILT = ("shooter",)
SIZES = {"tiny": 0.6, "small": 0.8, "medium": 1.0, "large": 1.25, "huge": 1.5,
         "gigantic": 3.0}
PACES = {"slow": 1.25, "normal": 1.0, "fast": 0.8}
GIGANTIC_CANDIDATES = 6
SYMMETRIES = ("auto", "none", "mirror", "turn2", "turn4", "turn8")
SIDES = ("auto", "ffa", "2", "4")
VERTICALITIES = ("flat", "low", "medium", "high")
DENSITIES = ("sparse", "medium", "dense")
DIFFICULTIES = ("easy", "normal", "hard", "expert", "pro")
DIFFICULTY_ALIASES = {"casual": "easy", "kaizo": "pro", "hardcore": "pro", "profi": "pro"}
COURSE_LENGTHS = ("auto", "short", "medium", "long", "marathon")
COURSE_FOCUSES = ("mixed", "jumps", "climb", "balance", "moving")
COURSE_MOVES = ("longjump", "sideflip", "wallkick", "dive", "groundpound", "triple", "movers",
                "blj")
EDGES = ("auto", "walled", "rails", "void")
BOUNDARIES = ("auto", "visible", "invisible", "both")
THEMES = ("auto", "castle", "desert", "ice", "lava", "wood", "sky", "garden")
STYLES = ("auto", "plain", "built")
LEVELS = ("auto", "empty", "empty2")
LEVEL_NAMES = {"tiles": "empty", "the tiles": "empty", "void": "empty2", "the void": "empty2"}
FEATURES = ("bridge", "tower", "crown", "pit", "perches", "undercroft", "void_gaps",
            "jump_pads", "stairs", "ramps_only", "loops", "long_lines", "rails",
            "side_colours", "columns", "cover_walls", "plaza", "bridge_cross",
            "ramps", "second_floor", "tall_walls", "jumps", "shortcut", "shortcut_ramp",
            "shortcut_jump", "figure_eight", "water", "lava", "tunnel", "gate", "walls",
            "nooks", "arches", "pillars", "slopes", "moving_platforms", "trampolines",
            "lanes", "islands", "spiral", "jump", "point_to_point", "chicane",
            "buildings", "fences", "slabs", "diagonals", "corners", "curves", "terrain",
            "river", "roads",
            "corner_bases",
            "split_spawns",
            "water_levels",
            "mountains", "valley", "caves", "volcano",
            "terraces", "weirs", "landmarks", "lighthouse", "obelisk", "watchtower",
            "temple",
            "backdrop", "roofs", "gradients", "framing", "tops",
            "flanks", "routes", "comeback", "spawn_camping", "move_shortcuts",
            "mesa", "natural_arch", "waterfall", "dunes", "glacier", "rolling_hills",
            "detail", "coin_star",
            "windmill", "belltower", "keep", "ruin", "statue", "pyramid", "spirerock",
            "fountain", "shrine", "greattree", "marketsquare", "fortress", "domedhall",
            "well", "shipwreck", "courtyard",
            "rooms", "training_course",
            "slide", "floating_islands", "spiral_path", "lookout", "secret_alcove",
            "giant_mushrooms",
            "lanterns", "glowing_mushrooms", "crystals", "dark")
FUN_FEATURES = {
    "flanks": "a second way into the fight, out of sight of the main way and "
              "arriving from the side (flank unseen >= 0.6, angle >= 60); the shooter "
              "skeletons add a flank link (rewire.py)",
    "routes": "a choice of ways - three routes within 1.3x the fastest; the "
              "skeletons add shortcuts and close dead ends",
    "comeback": "the side losing ground has the shorter trip back to the fight "
                "(home ratio <= 0.7)",
    "spawn_camping": "one camper can cover every way out of a base; 'no spawn camping' "
                     "(avoided) asks for 2+ exits no camper sees and 3+ ways out",
    "move_shortcuts": "shortcuts only SM64's moves make (a double jump up a ledge, a "
                      "long jump over a gap, a wall-kick chimney): 2+ per symmetry unit",
}
FEATURE_ALIASES = {"ramp": "ramps", "wall_over_jump": "tall_walls",
                   "jump_pad": "jump_pads", "trampoline": "trampolines", "stair": "stairs",
                   "perch": "perches", "column": "columns", "pillar": "pillars",
                   "arch": "arches", "gap": "void_gaps", "gaps": "void_gaps",
                   "towers": "tower", "bridges": "bridge", "pits": "pit", "loop": "loops",
                   "nook": "nooks", "lane": "lanes", "island": "islands", "tunnels": "tunnel",
                   "gates": "gate", "wall": "walls", "rail": "rails", "railings": "rails",
                   "second_storey": "second_floor", "upper_floor": "second_floor",
                   "figure8": "figure_eight", "long_line": "long_lines",
                   "sightlines": "long_lines", "cover": "cover_walls",
                   "building": "buildings", "houses": "buildings", "house": "buildings",
                   "fence": "fences", "slab": "slabs", "diagonal": "diagonals",
                   "corner": "corners", "curve": "curves", "bends": "curves",
                   "hills": "terrain", "rivers": "river", "road": "roads",
                   "backdrops": "backdrop", "scenery": "backdrop", "roof": "roofs",
                   "gradient": "gradients", "frames": "framing", "top": "tops",
                   "room": "rooms", "corridors": "rooms", "corridor": "rooms",
                   "indoor": "rooms", "interior": "rooms", "killhouse": "training_course",
                   "training": "training_course"}
ANCHOR_WHATS = ("tower", "bridge", "crown", "pit", "perch", "base", "ramp", "stairs",
                "wall", "pillar", "arch", "tunnel", "plaza", "flag", "point", "hill",
                "spawn", "spawns", "world_spawn", "start_line", "goal", "loop", "nook",
                "vantage", "item_point", "landmark", "centre", "platform", "ring", "gate",
                "shortcut", "jump", "island", "lane", "checkpoint", "finish",
                "volcano")
ANCHOR_ALIASES = {"worldspawn": "world_spawn", "entry": "world_spawn", "spawnpoint": "spawn",
                  "column": "pillar", "center": "centre", "middle": "centre",
                  "towers": "tower", "bridges": "bridge", "bases": "base", "points": "point",
                  "flags": "flag", "platforms": "platform", "ramps": "ramp", "pits": "pit",
                  "perches": "perch", "start": "start_line", "finish_line": "finish"}
COMPASS = {"n": (0, -1), "ne": (1, -1), "e": (1, 0), "se": (1, 1), "s": (0, 1),
           "sw": (-1, 1), "w": (-1, 0), "nw": (-1, -1), "c": (0, 0)}
COMPASS_ALIASES = {"north": "n", "south": "s", "east": "e", "west": "w",
                   "northeast": "ne", "north-east": "ne", "northwest": "nw", "north-west": "nw",
                   "southeast": "se", "south-east": "se", "southwest": "sw", "south-west": "sw",
                   "centre": "c", "center": "c", "middle": "c", "mid": "c"}
RELATIONS = ("between", "above", "around", "next_to", "facing", "opposite", "in_front_of",
             "behind", "near", "far", "on", "along", "edge", "middle")
RELATION_ALIASES = {"next": "next_to", "beside": "next_to", "next_to_the": "next_to",
                    "on_top_of": "on", "in_front": "in_front_of", "under": "below"}
REGION_WORDS = ("corners", "edges", "edge", "ring", "field")
DIALS = ("openness", "verticality", "density", "size")
VARIETIES = ("auto", "low", "high")
AMOUNTS = ("trace", "few", "less", "more", "lots")
AMOUNT_EXTRA = ("trees",)
NOVELTY_MODES = ("surprise", "novel", "reject")
NOVELTY_ASPECTS = ("formation", "theme", "size", "preset", "features")
REQUEST_KINDS = ("stars", "mover", "forge", "place", "lanes")
STAR_HINT_KINDS = ("summit", "corner", "lift", "ferry", "sunken", "cave", "cannon",
                   "guarded", "wallrun", "pillars", "chimney", "longjump")
STAR_NAME_MAX = 40
def star_hint_problems(q):
    out = []
    if q.get("kind") != "stars":
        return ["requests: only a stars request lists stars"]
    hints = q.get("stars")
    if not isinstance(hints, list) or not all(isinstance(h, dict) for h in hints):
        return ["requests: stars is a list of {n, kinds?, name?}"]
    seen = set()
    for h in hints:
        n = h.get("n")
        if not isinstance(n, int) or isinstance(n, bool) or not 1 <= n <= 6 or n in seen:
            out.append("requests: star number %r is not 1..6 (once each)" % (n,))
        seen.add(n)
        if any(k not in ("n", "kinds", "name") for k in h):
            out.append("requests: a star says only n, kinds and name")
        ks = h.get("kinds")
        if ks is not None and (not isinstance(ks, list) or not ks
                               or any(k not in STAR_HINT_KINDS for k in ks)):
            out.append("requests: star kinds %r are not of %s" % (ks, ", ".join(STAR_HINT_KINDS)))
        nm = h.get("name")
        if nm is not None and (not isinstance(nm, str) or not nm.strip()
                               or len(nm) > STAR_NAME_MAX):
            out.append("requests: star name %r is not 1..%d letters" % (nm, STAR_NAME_MAX))
    return out
MOVER_SUBS = ("lift", "log_gauntlet", "gap_ferry", "island_ferry")
FORGE_OFF = ("enemies", "hazards", "movers", "items", "scenery", "all")
RADII = ("near", "far", "edge")
DNA = ("complexity", "coherence", "age", "nature", "exploration")
DNA_DEFAULTS = {"complexity": 0.5, "coherence": 0.5, "age": 0.2, "nature": 0.2,
                "exploration": 0.5}
FAMILY_DNA = {"hide": {"exploration": 0.7},
              "course": {"nature": 0.1}, "race": {"nature": 0.3},
              "knockoff": {"complexity": 0.3}, "party": {"complexity": 0.3},
              "explore": {"exploration": 0.9, "nature": 0.6, "complexity": 0.6}}
def dna(brief, key):
    got = (brief.get("dna") or {}).get(key)
    if got is not None:
        return float(got)
    return FAMILY_DNA.get(brief.get("family"), {}).get(key, DNA_DEFAULTS[key])
GROUNDS = ("auto", "tiles", "grass", "ice", "sand", "stone", "snow", "wood")
VISUALS = {
    "warm_sun": ("shading", "a warm sun"), "sunset": ("shading", "a sunset"),
    "moonlight": ("shading", "moonlight"), "firelight": ("shading", "firelight"),
    "hard_shadows": ("shading", "hard shadows"),
    "snow": ("snow", "snow"), "blizzard": ("snow", "a blizzard"),
    "petals": ("snow", "flower petals on the ground"), "rain": ("snow", "rain"),
    "thunderstorm": ("snow", "a thunderstorm"),
    "sepia": ("tint", "sepia"), "rust": ("tint", "rust"), "verdigris": ("tint", "verdigris"),
    "ice_tint": ("tint", "ice"), "gold": ("tint", "gold"),
    "haze": ("fog", "hazy"), "fog": ("fog", "thick"), "thick_fog": ("fog", "pea soup"),
    "red_haze": ("fog", "a red haze"), "dust": ("fog", "sulphur"),
    "blue_distance": ("fog", "a blue distance"), "smoke": ("fog", "smoke"),
    "clear_air": ("fog", None),
    "sky_haze": ("fog", "the sky's haze"),
    "auto": (None, None),
}
from . import mood as _mood
MOODS = ("auto",) + tuple(_mood.PRESET_KEYS)
FIELDS = ("brief", "name", "key", "family", "modes", "players", "size", "pace", "symmetry",
          "sides", "verticality", "density", "difficulty", "edge", "theme", "palette",
          "style", "sky", "music", "level", "features", "anchors", "objects", "budget",
          "seed", "candidates", "locks", "reseed", "reference", "wish", "dials",
          "dna", "ground", "visuals", "prefabs", "preset",
          "variety", "novelty", "requests", "forge_off",
          "amounts",
          "boundary",
          "mood",
          "course")
LATE_FIELDS = {"dials": {}, "dna": {}, "ground": "auto", "visuals": [], "prefabs": [],
               "preset": None, "variety": "auto", "novelty": {}, "requests": [],
               "forge_off": [], "amounts": {}, "boundary": "auto", "mood": "auto",
               "course": {}}
FAMILY_DEFAULTS = {
    "shooter":   {"symmetry": "turn4", "sides": "ffa", "verticality": "medium",
                  "density": "medium", "edge": "rails", "level": "empty2", "theme": "castle"},
    "objective": {"symmetry": "mirror", "sides": "2", "verticality": "medium",
                  "density": "medium", "edge": "walled", "level": "empty", "theme": "desert"},
    "knockoff":  {"symmetry": "turn4", "sides": "ffa", "verticality": "low",
                  "density": "sparse", "edge": "void", "level": "empty2", "theme": "lava"},
    "race":      {"symmetry": "none", "sides": "ffa", "verticality": "low",
                  "density": "sparse", "edge": "walled", "level": "empty2", "theme": "sky"},
    "hide":      {"symmetry": "none", "sides": "ffa", "verticality": "medium",
                  "density": "dense", "edge": "walled", "level": "empty", "theme": "garden"},
    "party":     {"symmetry": "turn4", "sides": "ffa", "verticality": "flat",
                  "density": "sparse", "edge": "void", "level": "empty2", "theme": "sky"},
    "course":    {"symmetry": "none", "sides": "ffa", "verticality": "high",
                  "density": "sparse", "edge": "rails", "level": "empty2", "theme": "sky"},
    "explore":   {"symmetry": "none", "sides": "ffa", "verticality": "medium",
                  "density": "medium", "edge": "walled", "level": "empty", "theme": "garden"},
}
COMMON_DEFAULTS = {"players": 16, "size": "medium", "pace": "normal", "difficulty": "normal",
                   "style": "auto", "sky": "auto", "music": "auto", "palette": None,
                   "modes": [], "features": {"want": [], "avoid": []}, "anchors": [],
                   "objects": [], "budget": 120, "candidates": 6, "locks": [], "reseed": {},
                   "reference": None, "name": None, "key": None, "wish": None,
                   "dials": {}, "dna": {}, "ground": "auto", "visuals": [],
                   "prefabs": [], "preset": None,
                   "variety": "auto", "novelty": {}, "requests": [], "forge_off": [],
                   "amounts": {}, "boundary": "auto", "mood": "auto", "course": {}}
from . import modeready as _modeready
FAMILY_MODES = {fam: _modeready.venue_keys(fam)
                for fam in ("shooter", "objective", "knockoff", "race", "hide", "party",
                            "course", "explore")}
from . import budget as _budget
BUDGET_MAX = _budget.budget_max(baked=True)
BUDGET_MAX_UNBAKED = _budget.budget_max()
SEED_MAX = 2 ** 31 - 1
KEY_RE = re.compile(r"^[a-z][a-z0-9]{2,23}$")
class BriefError(ValueError):
    def __init__(self, problems):
        self.problems = list(problems)
        ValueError.__init__(self, "the brief is not valid:\n  " + "\n  ".join(self.problems))
def _choice(problems, field, value, allowed):
    if value not in allowed:
        problems.append("%s: %r is not one of %s" % (field, value, ", ".join(map(str, allowed))))
        return False
    return True
def _norm_word(value):
    return value.strip().lower().replace(" ", "_") if isinstance(value, str) else value
def size_factor(size):
    if isinstance(size, str):
        return SIZES[size]
    return None
def across_units(size, family_across):
    if isinstance(size, str):
        return family_across * SIZES[size]
    if "w" in size and "d" in size:
        return float(max(size["w"], size["d"]))
    if "across" in size:
        return float(size["across"])
    if "aspect" in size:
        return max(footprint_units(size, family_across))
    return (float(size["across_s"]) - 0.6) * 960.0
ASPECT_RANGE = (0.25, 4.0)
def footprint_units(size, family_across):
    if isinstance(size, dict):
        if "w" in size and "d" in size:
            return float(size["w"]), float(size["d"])
        a = size.get("aspect")
        if isinstance(a, (int, float)) and a > 0:
            if "across" in size:
                A = float(size["across"])
                return (A, A / a) if a >= 1 else (A * a, A)
            A = family_across * SIZES.get(size.get("tier") or "medium", 1.0)
            k = a ** 0.5
            return A * k, A / k
    A = across_units(size, family_across)
    return A, A
def _rect_size(s, problems):
    out = {}
    if "w" in s or "d" in s:
        for k in ("w", "d"):
            v = s.get(k)
            if not isinstance(v, (int, float)) or isinstance(v, bool):
                problems.append("size.%s: give both w and d in units (1500..30000)" % k)
                return s
            if not 1500 <= v <= 30000:
                problems.append("size.%s: %r is not 1500..30000 units" % (k, v))
                return s
        w, d = int(s["w"]), int(s["d"])
        return {"w": w, "d": d, "across": max(w, d)}
    a = s.get("aspect")
    if not isinstance(a, (int, float)) or isinstance(a, bool) or \
            not ASPECT_RANGE[0] <= a <= ASPECT_RANGE[1]:
        problems.append("size.aspect: %r is not %g..%g (width over depth)"
                        % ((a,) + ASPECT_RANGE))
        return s
    if "across" in s:
        A = s["across"]
        if not isinstance(A, (int, float)) or not 1500 <= A <= 30000:
            problems.append("size.across: %r is not 1500..30000 units" % (A,))
            return s
        w, d = footprint_units({"across": A, "aspect": a}, A)
        w, d = int(round(w / 100.0)) * 100, int(round(d / 100.0)) * 100
        if min(w, d) < 1500:
            problems.append("size: %r across at aspect %g leaves a side of %d (1500 the least)"
                            % (A, a, min(w, d)))
            return s
        return {"w": w, "d": d, "across": max(w, d), "aspect": a}
    tier = _norm_word(s.get("tier") or "medium")
    if tier not in SIZES:
        problems.append("size.tier: %r is not one of %s" % (tier, ", ".join(SIZES)))
        return s
    out = {"aspect": a, "tier": tier}
    return out
def normalise_anchor(raw, i, problems):
    where = "anchors[%d]" % i
    if not isinstance(raw, dict):
        problems.append("%s: an anchor is an object {what, where, ...}, not %r" % (where, raw))
        return None
    a = dict(raw)
    what = _norm_word(a.get("what"))
    what = ANCHOR_ALIASES.get(what, what)
    if not _choice(problems, where + ".what", what, ANCHOR_WHATS):
        return None
    a["what"] = what
    pos = a.get("where", {"compass": "c"})
    if isinstance(pos, str):
        pos = {"compass": pos}
    if not isinstance(pos, dict):
        problems.append("%s.where: %r is not a position" % (where, pos))
        return None
    pos = dict(pos)
    if "compass" in pos:
        c = _norm_word(pos["compass"]).replace("_", "-")
        c = COMPASS_ALIASES.get(c, c)
        if c in REGION_WORDS:
            pos["compass"] = c
        elif _choice(problems, where + ".where.compass", c, tuple(COMPASS) + REGION_WORDS):
            pos["compass"] = c
    elif "clock" in pos:
        try:
            hour = int(pos["clock"])
        except (TypeError, ValueError):
            hour = -1
        if not 1 <= hour <= 12:
            problems.append("%s.where.clock: %r is not an hour 1..12" % (where, pos["clock"]))
        pos["clock"] = hour
    elif "x" in pos or "z" in pos:
        for k in ("x", "z"):
            if not isinstance(pos.get(k), (int, float)):
                problems.append("%s.where.%s: an exact position needs numbers x and z" % (where, k))
    elif "relation" in pos:
        rel = _norm_word(pos["relation"]).replace("-", "_")
        rel = RELATION_ALIASES.get(rel, rel)
        if _choice(problems, where + ".where.relation", rel, RELATIONS):
            pos["relation"] = rel
        of = pos.get("of")
        if of is not None and not (isinstance(of, str) or (
                isinstance(of, list) and all(isinstance(o, str) for o in of))):
            problems.append("%s.where.of: an anchor id or feature name, or a list of them"
                            % where)
    elif "on" in pos:
        pos["on"] = _norm_word(pos["on"])
    elif "cell" in pos:
        c = pos["cell"]
        if not (isinstance(c, list) and len(c) == 2 and all(isinstance(v, int) and v >= 0
                                                             for v in c)):
            problems.append("%s.where.cell: [column, row] of the 200 grid from the north-west "
                            "corner" % where)
    elif "edge" in pos or "aligned" in pos or "anywhere" in pos or "region" in pos:
        pass
    else:
        problems.append("%s.where: give compass, clock, x/z, cell, edge, aligned, relation "
                        "or on" % where)
    if "radius" in pos:
        _choice(problems, where + ".where.radius", pos["radius"], RADII)
    a["where"] = pos
    if "spacing" in a and (not isinstance(a["spacing"], (int, float)) or a["spacing"] < 0):
        problems.append("%s.spacing: %r is not a distance in units" % (where, a["spacing"]))
    a.setdefault("id", "%s%d" % (what, i + 1))
    a.setdefault("hard", what in ("world_spawn",) or "compass" in pos or "x" in pos
                 or "cell" in pos)
    a.setdefault("once", False)
    a.setdefault("tolerance", 400)
    if "count" in a and (not isinstance(a["count"], int) or not 1 <= a["count"] <= 28):
        problems.append("%s.count: %r is not 1..28" % (where, a["count"]))
    if "height" in a and not isinstance(a["height"], (int, float)):
        problems.append("%s.height: %r is not a number" % (where, a["height"]))
    if "size" in a and a["size"] not in SIZES:
        problems.append("%s.size: %r is not one of %s" % (where, a["size"], ", ".join(SIZES)))
    return a
OBJECT_ALIASES = {"coins": "coin", "goombas": "goomba", "itembox": "exclam",
                  "itemboxes": "exclam", "item_box": "exclam", "item_boxes": "exclam",
                  "boxes": "box", "crate": "box", "crates": "box", "bobombs": "bobomb",
                  "bob-omb": "bobomb", "trampolines": "trampoline", "springs": "trampoline",
                  "spring": "trampoline", "hearts": "heart", "1ups": "1up", "lift": "elevator",
                  "lifts": "elevator", "koopas": "koopa", "thwomps": "thwomp",
                  "whomps": "whomp", "chomp": "chainchomp", "bluecoins": "bluecoin",
                  "redcoins": "redcoin", "shells": "shell", "piranhas": "piranha",
                  "amps": "amp", "boos": "boo", "trees": "tree", "cannons": "cannon"}
def normalise_object(raw, i, problems, forge_keys=None):
    where = "objects[%d]" % i
    if isinstance(raw, dict) and not isinstance(raw.get("key"), str) \
            and isinstance(raw.get("what"), str):
        raw = dict(raw, key=raw["what"])
    if not isinstance(raw, dict) or not isinstance(raw.get("key"), str):
        problems.append("%s: an object request is {key, count?, where?}" % where)
        return None
    o = dict(raw)
    k = o["key"].strip().lower().replace(" ", "_")
    o["key"] = OBJECT_ALIASES.get(k, k)
    o.pop("what", None)
    if forge_keys is not None and o["key"] not in forge_keys:
        problems.append("%s.key: %r is not a Forge object key" % (where, o["key"]))
    o.setdefault("count", 1)
    if not isinstance(o["count"], int) or not 1 <= o["count"] <= BUDGET_MAX:
        problems.append("%s.count: %r is not 1..%d" % (where, o["count"], BUDGET_MAX))
    w = o.setdefault("where", {"region": "field"})
    if isinstance(w, str):
        o["where"] = {"compass": w}
    elif not isinstance(w, dict):
        problems.append("%s.where: a position in the anchor language" % where)
    modes = o.setdefault("modes", [])
    if not isinstance(modes, list) or not all(isinstance(m, str) for m in modes):
        problems.append("%s.modes: a list of mode keys whose rounds use them" % where)
    o.setdefault("in_rounds", bool(modes))
    return o
def _mode_keys():
    try:
        from . import modes
        return set(modes.all())
    except Exception:
        return set()
def mode_key(m):
    k = str(m).strip().lower()
    flat = re.sub(r"[^a-z0-9]+", "", k)
    try:
        from . import modes
        table = modes.all()
    except Exception:
        table = {}
    if k in table:
        return k
    for key, name in table.items():
        if re.sub(r"[^a-z0-9]+", "", name.lower()) == flat:
            return key
    return MODE_ALIASES.get(flat, flat)
MODE_ALIASES = {"deathmatch": "shooter", "dm": "shooter", "ffa": "shooter",
                "capturetheflag": "ctf", "kingofthehill": "koth", "hideandseek": "hideseek",
                "versteckspiel": "hideseek", "verstecken": "hideseek", "propjagd": "prophunt",
                "shellracer": "shellrace", "rennen": "shellrace", "oneflag": "oneflag",
                "killconfirmed": "bounty", "lastonestanding": "laststanding",
                "oddball": "crown", "lasttile": "hexagone",
                "redlightgreenlight": "line", "musicalspots": "spots", "simonsays": "simon"}
def dial_name(field, value):
    v = max(0.0, min(1.0, float(value)))
    if field == "verticality":
        return ("flat", "low", "medium", "high", "high")[min(4, int(v * 5))]
    if field == "openness":
        return ("dense", "dense", "medium", "sparse", "sparse")[min(4, int(v * 5))]
    if field == "density":
        return ("sparse", "sparse", "medium", "dense", "dense")[min(4, int(v * 5))]
    return None
def apply_dials(raw, problems):
    dials = dict(raw.get("dials") or {}) if isinstance(raw.get("dials"), dict) else {}
    if "dials" in raw and not isinstance(raw.get("dials"), dict):
        problems.append("dials: {openness|verticality|density: 0..1}")
    for field in ("openness", "verticality", "density"):
        v = raw.get(field)
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            if not 0 <= v <= 1:
                problems.append("%s: %r is not 0..1" % (field, v))
                raw.pop(field)
                continue
            dials[field] = float(v)
            raw.pop(field)
    for field, v in list(dials.items()):
        if field not in ("openness", "verticality", "density") or not isinstance(
                v, (int, float)) or not 0 <= v <= 1:
            problems.append("dials.%s: %r is not a 0..1 dial (openness, verticality, density)"
                            % (field, v))
            dials.pop(field)
            continue
        target = "density" if field == "openness" else field
        if target not in raw or field == target:
            raw[target] = dial_name(field, v)
    if dials:
        raw["dials"] = dials
def _course_options(data, problems):
    raw = data.get("course")
    if raw in (None, {}):
        data["course"] = {}
        return
    if not isinstance(raw, dict):
        problems.append("course: {length, moves, checkpoints, sections, focus}")
        data["course"] = {}
        return
    out = {}
    for k in raw:
        if k not in ("length", "moves", "checkpoints", "sections", "focus"):
            problems.append("course.%s: not an option (length, moves, checkpoints, sections, "
                            "focus)" % k)
    if raw.get("length") not in (None, "auto"):
        v = _norm_word(raw["length"])
        if _choice(problems, "course.length", v, COURSE_LENGTHS):
            out["length"] = v
    if raw.get("focus") not in (None, "mixed"):
        v = _norm_word(raw["focus"])
        if _choice(problems, "course.focus", v, COURSE_FOCUSES):
            out["focus"] = v
    for k, lo, hi in (("checkpoints", 10, 120), ("sections", 1, 30)):
        v = raw.get(k)
        if v is None or v == "auto":
            continue
        if not isinstance(v, int) or isinstance(v, bool) or not lo <= v <= hi:
            problems.append("course.%s: %r is not a whole number %d..%d" % (k, v, lo, hi))
        else:
            out[k] = v
    mv = raw.get("moves")
    if mv:
        if not isinstance(mv, dict) or any(m not in COURSE_MOVES or not isinstance(on, bool)
                                           for m, on in mv.items()):
            problems.append("course.moves: {move: true | false} for %s" % ", ".join(COURSE_MOVES))
        else:
            out["moves"] = dict(sorted(mv.items()))
    data["course"] = out
def _late_language(data, problems, notes):
    v = data["variety"]
    v = _norm_word(v) if isinstance(v, str) else v
    if _choice(problems, "variety", v, VARIETIES):
        data["variety"] = v
    nov = data["novelty"]
    if not isinstance(nov, dict):
        problems.append("novelty: {mode: %s, avoid: [%s]}" % (
            "|".join(NOVELTY_MODES), "|".join(NOVELTY_ASPECTS)))
        data["novelty"] = {}
    elif nov:
        if nov.get("mode") not in NOVELTY_MODES:
            problems.append("novelty.mode: %r is not one of %s" % (
                nov.get("mode"), ", ".join(NOVELTY_MODES)))
        av = nov.get("avoid", [])
        if not isinstance(av, list) or any(a not in NOVELTY_ASPECTS for a in av):
            problems.append("novelty.avoid: a list of %s" % ", ".join(NOVELTY_ASPECTS))
        data["novelty"] = {k: copy.deepcopy(nov[k]) for k in ("mode", "avoid") if k in nov}
    reqs = data["requests"]
    if not isinstance(reqs, list) or not all(isinstance(q, dict) for q in reqs):
        problems.append("requests: a list of {kind: %s, count?}" % "|".join(REQUEST_KINDS))
        data["requests"] = []
    else:
        for q in reqs:
            if q.get("sub") is not None and (q.get("kind") != "mover"
                                             or q["sub"] not in MOVER_SUBS):
                problems.append("requests: sub %r is not one of %s" % (
                    q.get("sub"), ", ".join(MOVER_SUBS)))
            if q.get("kind") not in REQUEST_KINDS:
                problems.append("requests: kind %r is not one of %s" % (
                    q.get("kind"), ", ".join(REQUEST_KINDS)))
            c = q.get("count")
            low = 0 if q.get("kind") == "stars" else 1
            if c is not None and (not isinstance(c, int) or isinstance(c, bool) or c < low):
                problems.append("requests: count %r is not a whole number >= %d" % (c, low))
            if q.get("stars") is not None:
                problems += star_hint_problems(q)
        for q in reqs:
            if q.get("kind") == "lanes":
                notes.append("requested: %s lanes (counted against the built map)"
                             % q.get("count"))
                continue
            if q.get("kind") == "place":
                notes.append("requested: %s%s %s the %s (kept as asked)" % (
                    "hidden " if q.get("hidden") else "", q.get("what"),
                    str(q.get("relation")).replace("_", " "), q.get("of")))
                continue
            notes.append("requested: %s%s (the gameplay pass builds it where the map "
                         "and its modes allow)" % (
                q.get("kind"), " x%d" % q["count"] if q.get("count") else
                " off" if q.get("count") == 0 else ""))
    am = data["amounts"]
    if not isinstance(am, dict) or any(k not in FEATURES + AMOUNT_EXTRA or v not in AMOUNTS
                                       for k, v in am.items()):
        problems.append("amounts: {feature: %s}" % "|".join(AMOUNTS))
        data["amounts"] = {}
    else:
        data["amounts"] = dict(sorted(am.items()))
        for k, v in sorted(am.items()):
            notes.append("%s %s" % (v, k.replace("_", " ")))
    off = data["forge_off"]
    if not isinstance(off, list) or any(x not in FORGE_OFF for x in off):
        problems.append("forge_off: a list of %s" % ", ".join(FORGE_OFF))
        data["forge_off"] = []
    elif off and data.get("objects"):
        keep = []
        for o in data["objects"]:
            cat = forge_category(o.get("key"))
            if "all" in off or cat in off:
                notes.append("object %s left out: %s are off" % (o.get("key"), cat or "objects"))
            else:
                keep.append(o)
        data["objects"] = keep
SHELF_CATEGORY = {"Enemies": "enemies", "Bosses": "enemies", "Fliers and ghosts": "enemies",
                  "In the water": "enemies", "Fire and hazards": "hazards",
                  "Crushers and traps": "hazards", "Platforms": "movers", "Lifts": "movers",
                  "Clockwork": "movers", "Coins and pickups": "items",
                  "Things to carry": "items", "Switches and posts": "items",
                  "Friends and scenery": "scenery"}
def forge_category(key):
    try:
        from . import kit
        shelf = kit.forge_shelves().get(key)
    except Exception:
        shelf = None
    return SHELF_CATEGORY.get(shelf)
def stable_seed(data):
    text = json.dumps({k: v for k, v in data.items() if k not in ("seed", "candidates", "mood")
                       and not (k in LATE_FIELDS and v == LATE_FIELDS[k])},
                      sort_keys=True)
    return int.from_bytes(hashlib.blake2b(text.encode(), digest_size=4).digest(), "big") % 1000000
class Brief:
    def __init__(self, data, defaulted, notes=None):
        self.data = data
        self.defaulted = defaulted
        self.notes = notes or []
    def __getitem__(self, key):
        return self.data[key]
    def get(self, key, default=None):
        return self.data.get(key, default)
    def to_dict(self):
        out = {"brief": VERSION}
        for k in FIELDS[1:]:
            out[k] = copy.deepcopy(self.data[k])
        out["defaulted"] = list(self.defaulted)
        return out
    def to_json(self):
        return json.dumps(self.to_dict(), indent=2, sort_keys=False) + "\n"
    def with_changes(self, **changes):
        raw = {k: v for k, v in self.data.items() if k not in self.defaulted}
        raw.update(changes)
        return Brief.from_dict(raw)
    @classmethod
    def from_json(cls, text, forge_keys=None):
        try:
            raw = json.loads(text)
        except ValueError as why:
            raise BriefError(["not JSON: %s" % why])
        return cls.from_dict(raw, forge_keys)
    @classmethod
    def from_dict(cls, raw, forge_keys=None):
        if not isinstance(raw, dict):
            raise BriefError(["a brief is a JSON object"])
        problems = []
        raw = {k: v for k, v in raw.items() if v is not None or k in ("palette",)}
        listed_defaults = set(raw.pop("defaulted", []) or [])
        version = raw.pop("brief", VERSION)
        if version != VERSION:
            problems.append("brief: version %r, this engine reads version %d" % (version, VERSION))
        apply_dials(raw, problems)
        unknown = sorted(set(raw) - set(FIELDS))
        for k in unknown:
            problems.append("%s: not a brief field (fields: %s)" % (k, ", ".join(FIELDS[1:])))
        for k in listed_defaults:
            raw.pop(k, None)
        preset_notes = []
        if raw.get("preset") is not None:
            from . import presets
            if presets.get(raw["preset"]) is None:
                problems.append("preset: %r is not a preset (%s)" % (
                    raw["preset"], ", ".join(n for _, n, _ in presets.table())))
                raw.pop("preset")
            else:
                raw, preset_notes = presets.apply(raw)
        data, defaulted = {}, []
        family = _norm_word(raw.get("family", "shooter"))
        family = FAMILY_ALIASES.get(family, family)
        if "family" not in raw:
            defaulted.append("family")
        if not _choice(problems, "family", family, FAMILIES):
            family = "shooter"
        data["family"] = family
        defaults = dict(COMMON_DEFAULTS)
        defaults.update(FAMILY_DEFAULTS[family])
        if raw.get("sides") in ("2", 2) and "symmetry" not in raw and family == "shooter":
            defaults["symmetry"] = "mirror"
        for k in FIELDS[1:]:
            if k == "family":
                continue
            if k in raw:
                data[k] = copy.deepcopy(raw[k])
            else:
                data[k] = copy.deepcopy(defaults.get(k))
                defaulted.append(k)
        if isinstance(data.get("difficulty"), str):
            data["difficulty"] = DIFFICULTY_ALIASES.get(_norm_word(data["difficulty"]),
                                                        data["difficulty"])
        for k, allowed in (("pace", tuple(PACES)), ("symmetry", SYMMETRIES),
                           ("verticality", VERTICALITIES), ("density", DENSITIES),
                           ("difficulty", DIFFICULTIES), ("edge", EDGES), ("theme", THEMES),
                           ("style", STYLES), ("boundary", BOUNDARIES), ("mood", MOODS)):
            data[k] = _norm_word(data[k])
            _choice(problems, k, data[k], allowed)
        data["sides"] = str(data["sides"]).lower()
        _choice(problems, "sides", data["sides"], SIDES)
        lvl = _norm_word(data["level"])
        lvl = LEVEL_NAMES.get(str(lvl).replace("_", " "), lvl)
        data["level"] = lvl
        _choice(problems, "level", lvl, LEVELS)
        if data["level"] == "auto":
            data["level"] = FAMILY_DEFAULTS[family]["level"]
        if data["theme"] == "auto":
            data["theme"] = FAMILY_DEFAULTS[family]["theme"]
        if data["symmetry"] == "auto":
            data["symmetry"] = FAMILY_DEFAULTS[family]["symmetry"]
        p = data["players"]
        if not isinstance(p, int) or isinstance(p, bool) or not 2 <= p <= 16:
            problems.append("players: %r is not a whole number 2..16" % (p,))
        s = data["size"]
        if isinstance(s, str):
            s = _norm_word(s)
            data["size"] = s
            _choice(problems, "size", s, tuple(SIZES))
        elif isinstance(s, dict) and any(k in s for k in ("w", "d", "aspect")):
            data["size"] = _rect_size(s, problems)
        elif isinstance(s, dict):
            if "across" in s and isinstance(s["across"], (int, float)):
                if not 1500 <= s["across"] <= 30000:
                    problems.append("size.across: %r is not 1500..30000 units" % s["across"])
            elif "across_s" in s and isinstance(s["across_s"], (int, float)):
                if not 2 <= s["across_s"] <= 32:
                    problems.append("size.across_s: %r is not 2..32 seconds" % s["across_s"])
            else:
                problems.append("size: give a name (%s), {\"across\": units}, "
                                "{\"across_s\": seconds}, {\"w\": units, \"d\": units} or "
                                "{\"aspect\": w/d}" % ", ".join(SIZES))
        else:
            problems.append("size: %r is not a size" % (s,))
        if "size" in defaulted and isinstance(data["modes"], list) and data["modes"]:
            from . import modeknow as _mk
            order = ("tiny", "small", "medium", "large", "huge", "gigantic")
            want = [t for t in (_mk.ideal_size(m, data.get("players") or 16, data["size"])
                                for m in data["modes"]) if t]
            if want:
                tier = max(want, key=order.index)
                if tier != data["size"]:
                    data["size"] = tier
                    preset_notes.append("size %s: what %s asks for at %s players "
                                        "(tools/mode-profiles.json)"
                                        % (tier, ", ".join(data["modes"]),
                                           data.get("players") or 16))
        b = data["budget"]
        if "budget" in defaulted:
            b = data["budget"] = max(120, _budget.tier_budget(
                data["size"], family,
                data["modes"] if isinstance(data["modes"], list) else (), baked=True))
        top = _budget.ceiling(family, data["modes"] if isinstance(data["modes"], list) else (),
                              baked=True)
        if not isinstance(b, int) or isinstance(b, bool) or not 20 <= b <= BUDGET_MAX:
            problems.append("budget: %r is not 20..%d objects" % (b, BUDGET_MAX))
        elif b > top:
            preset_notes.append("budget %d held to %d: the most a baked %s map may hold "
                                "(tools/mapgen/budget.py)" % (b, top, family))
            data["budget"] = b = top
        if "candidates" in defaulted and data["size"] == "gigantic":
            data["candidates"] = GIGANTIC_CANDIDATES
        c = data["candidates"]
        if not isinstance(c, int) or not 1 <= c <= 1000:
            problems.append("candidates: %r is not 1..1000" % (c,))
        if not isinstance(data["modes"], list) or not all(
                isinstance(m, str) for m in data["modes"]):
            problems.append("modes: a list of mode keys such as \"shooter\", \"oitc\"")
        else:
            data["modes"] = [mode_key(m) for m in data["modes"]]
            known = _mode_keys()
            for m in data["modes"]:
                if not re.match(r"^[a-z0-9]+$", m) or (known and m not in known):
                    problems.append("modes: %r is not a mode of the mod (%s)"
                                    % (m, ", ".join(sorted(known)[:8]) + ", ..."))
        f = data["features"]
        if isinstance(f, list):
            f = {"want": f, "avoid": []}
        if not isinstance(f, dict):
            problems.append("features: {\"want\": [...], \"avoid\": [...]}")
            f = {"want": [], "avoid": []}
        f = {"want": [FEATURE_ALIASES.get(_norm_word(x), _norm_word(x))
                      for x in f.get("want", [])],
             "avoid": [FEATURE_ALIASES.get(_norm_word(x), _norm_word(x))
                       for x in f.get("avoid", [])]}
        f = {"want": sorted(set(f["want"]), key=f["want"].index),
             "avoid": sorted(set(f["avoid"]), key=f["avoid"].index)}
        for side in ("want", "avoid"):
            for name in f[side]:
                _choice(problems, "features.%s" % side, name, FEATURES)
        both = sorted(set(f["want"]) & set(f["avoid"]))
        if both:
            problems.append("features: %s both wanted and avoided" % ", ".join(both))
        data["features"] = f
        pal = data["palette"]
        if pal is not None:
            if not isinstance(pal, dict) or not all(
                    isinstance(v, list) and all(isinstance(t, str) for t in v)
                    for v in pal.values()):
                problems.append("palette: {\"floor\": [texture, ...], \"wall\": [...], ...}")
        if not isinstance(data["anchors"], list):
            problems.append("anchors: a list")
            data["anchors"] = []
        anchors = []
        for i, a in enumerate(data["anchors"]):
            n = normalise_anchor(a, i, problems)
            if n is not None:
                anchors.append(n)
        ids = [a["id"] for a in anchors]
        for dup in sorted(set(i for i in ids if ids.count(i) > 1)):
            problems.append("anchors: the id %r is used twice" % dup)
        data["anchors"] = anchors
        if not isinstance(data["objects"], list):
            problems.append("objects: a list")
            data["objects"] = []
        data["objects"] = [o for o in (normalise_object(o, i, problems, forge_keys)
                                       for i, o in enumerate(data["objects"])) if o]
        if sum(o["count"] for o in data["objects"]) > data["budget"] if isinstance(
                data["budget"], int) else False:
            problems.append("objects: more objects asked for than the budget holds")
        if not isinstance(data["locks"], list):
            problems.append("locks: a list of module ids")
        if not isinstance(data["reseed"], dict) or not all(
                isinstance(v, int) for v in data["reseed"].values()):
            problems.append("reseed: {module id: generation number}")
        mus = data["music"]
        if mus not in (None, "auto"):
            from . import kit
            key = kit.music_key(mus) if isinstance(mus, str) else None
            if key is None:
                problems.append("music: %r is no sequence of the music page (a SEQ_ name, an "
                                "imported track's file or name; recordings cannot stand in "
                                "for a level's own music)" % (mus,))
            else:
                data["music"] = key
        dna_v = data["dna"]
        if not isinstance(dna_v, dict):
            problems.append("dna: {%s: 0..1}" % "|".join(DNA))
            data["dna"] = {}
        else:
            for k, v in sorted(dna_v.items()):
                if k not in DNA:
                    problems.append("dna.%s: not a World DNA value (%s)" % (k, ", ".join(DNA)))
                elif not isinstance(v, (int, float)) or isinstance(v, bool) or not 0 <= v <= 1:
                    problems.append("dna.%s: %r is not 0..1" % (k, v))
            data["dna"] = {k: float(v) for k, v in dna_v.items() if k in DNA
                           and isinstance(v, (int, float)) and not isinstance(v, bool)}
        g = _norm_word(data["ground"]) if isinstance(data["ground"], str) else data["ground"]
        data["ground"] = g
        if _choice(problems, "ground", g, GROUNDS) and g not in ("auto", "tiles") \
                and data["level"] != "empty":
            problems.append("ground: %r is a ground of The Tiles - the level is %s"
                            % (g, data["level"]))
        vis = data["visuals"]
        if not isinstance(vis, list) or not all(isinstance(v, str) for v in vis):
            problems.append("visuals: a list of visual modifier keys (%s)"
                            % ", ".join(sorted(VISUALS)))
            data["visuals"] = []
        else:
            data["visuals"] = [_norm_word(v) for v in vis]
            rows = {}
            for v in data["visuals"]:
                if _choice(problems, "visuals", v, tuple(sorted(VISUALS))) and VISUALS[v][0]:
                    row = VISUALS[v][0]
                    if row in rows:
                        problems.append("visuals: %s and %s are two stops of one row (%s) - "
                                        "pick one" % (rows[row], v, row))
                    rows[row] = v
        pf = data["prefabs"]
        if not isinstance(pf, list) or not all(isinstance(v, str) for v in pf):
            problems.append("prefabs: a list of prefab names (tools/prefabs.py list)")
            data["prefabs"] = []
        elif pf:
            from . import prefablib
            keys = []
            for v in pf:
                got = prefablib.find(v)
                if got is None:
                    problems.append("prefabs: no prefab named %r (the library: %s)" % (
                        v, ", ".join(n for _, n, _ in prefablib.names()) or "empty"))
                elif got["key"] not in keys:
                    keys.append(got["key"])
            data["prefabs"] = keys
        if "budget" in defaulted and isinstance(data["dna"], dict) and \
                (dna(data, "complexity") >= 0.6 or dna(data, "nature") >= 0.6):
            data["budget"] = max(150, data["budget"])
        _late_language(data, problems, preset_notes)
        _course_options(data, problems)
        key = data["key"]
        if key is not None and (not isinstance(key, str) or not KEY_RE.match(key)):
            problems.append("key: %r must be 3-24 lower-case letters/digits, starting with "
                            "a letter" % (key,))
        if data["name"] is not None and (not isinstance(data["name"], str)
                                         or not 1 <= len(data["name"]) <= 40):
            problems.append("name: 1..40 characters")
        if problems:
            raise BriefError(problems)
        if data["seed"] is None:
            data["seed"] = stable_seed(data)
        if not isinstance(data["seed"], int) or not 0 <= data["seed"] <= SEED_MAX:
            raise BriefError(["seed: %r is not 0..%d" % (data["seed"], SEED_MAX)])
        return cls(data, defaulted, preset_notes)
