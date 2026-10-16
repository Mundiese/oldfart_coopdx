from studio.editor import engine
STEPS = ("mode", "size", "theme", "wish", "generate", "export")
TITLES = {
    "mode": "What kind of map?", "size": "How big?", "theme": "How should it look?",
    "wish": "Anything special?", "generate": "Build it", "export": "Into the game",
}
HELP = {
    "mode": "Pick what you will play on it. You can change everything later.",
    "size": "Players and size. Sixteen players is the lobby's most; size is measured in "
            "how long Mario runs across.",
    "theme": "A look: its blocks, sky and music. Or start from a preset.",
    "wish": "Say what you want in German or English - a bridge in the middle, the world "
            "spawn in the south, lots of height. Leave it empty for a surprise.",
    "generate": "The engine builds a few maps and keeps the best. Not this one? Press "
                "Generate again, or step back with < in the seed bar later.",
    "export": "Give it a name and put it into the mod. Then restart Coop DX and travel there.",
}
PRESETS = (
    ("arena", "Shooter arena", "16 players, towers and bridges, the Sky Keep's kind",
     {"family": "shooter", "players": 16, "size": "medium", "verticality": "high"}),
    ("ctf", "Capture the flag", "two bases face to face, mirrored",
     {"family": "objective", "players": 16, "sides": "2", "symmetry": "mirror"}),
    ("sumo", "Knock-off plate", "a small round plate over the void",
     {"family": "knockoff", "players": 8, "size": "small"}),
    ("race", "Race track", "a loop with banked corners",
     {"family": "race", "players": 16}),
    ("hide", "Hide and seek", "lots of corners and cover",
     {"family": "hide", "density": "dense"}),
    ("course", "Obstacle course", "jumps from start to finish",
     {"family": "course"}),
    ("course_kids", "Easy course for kids", "a short course with big landings and a net "
     "under every jump",
     {"family": "course", "difficulty": "easy", "course": {"length": "short"}}),
    ("course_pro", "Pro course", "wall-kick shafts, long jumps at the edge of their range, "
     "lava and the void - for SM64 pros", {"family": "course", "difficulty": "pro"}),
    ("rooms", "Rooms and corridors", "an indoor shooter: rooms, doors, windows, a hall "
     "in the middle, flank corridors",
     {"family": "shooter", "features": {"want": ["rooms"], "avoid": []}}),
    ("killhouse", "Killhouse", "a training course through rooms, 60 x 30 m, target spots "
     "along the route",
     {"family": "shooter", "features": {"want": ["training_course"], "avoid": []}}),
)
SIMPLE = ("family", "players", "size", "theme")
COURSE_SIMPLE = ("difficulty", "course_length")
def control(field):
    for c in engine.CONTROLS:
        if c[0] == field:
            return c
    raise KeyError(field)
def choices(field):
    _, _, kind, opts, _ = control(field)
    if kind in ("choice", "steps"):
        return list(opts)
    lo, hi = opts
    return [(n, str(n)) for n in (2, 4, 8, 12, 16) if lo <= n <= hi]
class Wizard:
    def __init__(self):
        self.step = 0
        self.values = {}
        self.wish = ""
        self.preset = None
        self.name = ""
        self.course = True
    @property
    def current(self):
        return STEPS[self.step]
    def set(self, field, value):
        if field == "modes":
            if value is None:
                self.values.pop("modes", None)
            else:
                self.values["modes"] = [str(k) for k in value]
            return
        allowed = [v for v, _ in choices(field)]
        if value is None:
            self.values.pop(field, None)
            return
        if field == "players":
            lo, hi = control("players")[3]
            if not (isinstance(value, int) and lo <= value <= hi):
                raise ValueError("players %r is not %d-%d" % (value, lo, hi))
        elif value is not None and value not in allowed:
            raise ValueError("%s %r is not one of %s" % (field, value, allowed))
        if value is None:
            self.values.pop(field, None)
        else:
            self.values[field] = value
    def use_preset(self, key):
        for k, _, _, fields in PRESETS:
            if k == key:
                self.preset = key
                for f, v in fields.items():
                    self.values[f] = v
                return fields
        raise KeyError(key)
    def drop_preset(self):
        dropped = []
        for k, _, _, fields in PRESETS:
            if k == self.preset:
                for f, v in fields.items():
                    if self.values.get(f) == v:
                        self.values.pop(f)
                        dropped.append(f)
        self.preset = None
        return dropped
    def next(self):
        self.step = min(len(STEPS) - 1, self.step + 1)
        return self.current
    def back(self):
        self.step = max(0, self.step - 1)
        return self.current
    def can_next(self):
        if self.current == "mode":
            return "family" in self.values
        return self.current != "export"
    def offers_course(self):
        want = ((self.values.get("features") or {}).get("want") or [])
        return self.preset == "killhouse" or "training_course" in want
    def makes_course(self):
        return self.course and self.offers_course()
    def brief(self):
        return engine.brief_from(dict(self.values), self.wish.strip() or None)
    def summary(self):
        fields = SIMPLE + (COURSE_SIMPLE if self.values.get("family") == "course" else ())
        labels = {f: dict(choices(f)) for f in fields}
        values = dict(self.values)
        if (values.get("course") or {}).get("length") and "course_length" not in values:
            values["course_length"] = values["course"]["length"]
        parts = []
        for f in fields:
            if f in values:
                v = values[f]
                said = labels[f].get(v, v) if not isinstance(v, (dict, list)) else v
                parts.append("%s: %s" % (control(f)[1], said))
        if "modes" in self.values:
            from studio.editor import gamemodes
            parts.append("modes: %s" % (", ".join(gamemodes.name_of(k)
                                                   for k in self.values["modes"]) or "none"))
        if self.wish.strip():
            parts.append("wish: %s" % self.wish.strip())
        return "; ".join(parts) or "nothing chosen yet"
SEEN_KEY = "wizard_seen"
FIRST_HINT = ("New here? \"Your first map\" walks you through it in a few steps - "
              "or start any other way below.")
def first_start(state):
    return not (state or {}).get(SEEN_KEY)
def attention(state, reduce_motion=False):
    first = first_start(state)
    return {"open": False, "highlight": first, "pulse": first and not reduce_motion,
            "hint": FIRST_HINT if first else ""}
def mark_seen(state):
    if state is None or state.get(SEEN_KEY):
        return False
    state[SEEN_KEY] = True
    return True
FAMILY_WORDS = {"shooter": "shooter arena", "race": "race track", "hide": "hide and seek",
                "course": "obstacle course", "party": "party game", "knockoff": "knock-off",
                "objective": "capture the flag", "sumo": "knock-off"}
def templates(examples=None):
    import json
    import os
    out = []
    from studio.ux import playground
    out.append((playground.SOURCE, playground.NAME, playground.WHAT))
    try:
        from mapgen import v1
        from studio.core import loader
        for k in v1.venue_keys():
            out.append(("venue:" + k, "The " + loader.venue_name(k), "the venue in the mod"))
    except Exception:
        pass
    if examples is None:
        here = os.path.dirname(os.path.abspath(__file__))
        examples = os.path.join(os.path.dirname(os.path.dirname(here)), "mapgen", "examples")
    try:
        names = sorted(os.listdir(examples))
    except OSError:
        names = []
    for d in names:
        folder = os.path.join(examples, d)
        if not os.path.isfile(os.path.join(folder, "layout.json")):
            continue
        try:
            with open(os.path.join(folder, "brief.json"), encoding="utf-8") as h:
                brief = json.load(h)
        except (OSError, ValueError):
            brief = {}
        name = brief.get("name") or d.replace("-", " ").title()
        modes = brief.get("modes") or []
        fam = (modes[0] if modes else None) or brief.get("family") or ""
        out.append((folder, name, FAMILY_WORDS.get(fam, fam or "a map")))
    return out
