LEVELS = ("none", "few", "some", "heaps")
FACTORS = (0.15, 0.6, 1.0, 2.2)
BOOST = 40.0
KNOBS = {
    "islands":      ((20, 40, 30, 15), "structure", "islands"),
    "lanes":        ((20, 40, 30, 15), "structure", "lanes"),
    "rings":        ((25, 40, 25, 10), "structure", "rings"),
    "hubs":         ((25, 40, 25, 10), "structure", "spokes"),
    "hills":        ((25, 40, 25, 10), "structure", "terraces"),
    "walls":        ((25, 40, 25, 10), "structure", "ramparts"),
    "canyons":      ((25, 40, 25, 10), "structure", "canyons"),
    "keeps":        ((20, 40, 30, 15), "structure", "island keeps"),
    "bases":        ((20, 40, 30, 15), "structure", "twin bases"),
    "height":       ((15, 35, 35, 15), "height", "height"),
    "towers":       ((30, 40, 20, 10), "height", "towers"),
    "perches":      ((20, 40, 30, 10), "height", "perches"),
    "daises":       ((25, 40, 25, 10), "height", "raised daises"),
    "pits":         ((40, 35, 15, 10), "height", "sunken floors"),
    "ramps":        ((10, 35, 40, 15), "height", "ramps"),
    "stairs":       ((55, 25, 15, 5), "height", "stairs"),
    "bridges":      ((15, 35, 35, 15), "joins", "bridges"),
    "void_gaps":    ((30, 40, 20, 10), "joins", "gaps over the void"),
    "crossings":    ((20, 40, 30, 10), "joins", "cross links"),
    "width":        ((15, 40, 35, 10), "joins", "wide walkways"),
    "cover":        ((5, 35, 45, 15), "cover", "cover"),
    "crates":       ((30, 40, 20, 10), "cover", "crates"),
    "low_walls":    ((20, 40, 30, 10), "cover", "low walls"),
    "columns":      ((25, 40, 25, 10), "cover", "columns"),
    "bunkers":      ((35, 40, 20, 5), "cover", "bunkers"),
    "rails":        ((15, 35, 35, 15), "dress", "rails"),
    "trims":        ((20, 40, 30, 10), "dress", "trims"),
    "pillars":      ((25, 40, 25, 10), "dress", "wall pillars"),
    "crenels":      ((35, 40, 20, 5), "dress", "battlements"),
    "landmark":     ((10, 30, 40, 20), "dress", "a landmark"),
    "keels":        ((20, 40, 30, 10), "dress", "rock keels"),
    "side_colours": ((10, 20, 40, 30), "dress", "side colours"),
}
KIT_KNOBS = {
    "fences":       ((30, 35, 25, 10), "kit", "fences"),
    "arches":       ((35, 35, 20, 10), "kit", "arches"),
    "colonnades":   ((35, 35, 20, 10), "kit", "colonnades"),
    "diagonals":    ((40, 35, 20, 5), "kit", "diagonal corners"),
    "slabs":        ((30, 40, 20, 10), "kit", "slabs and steps"),
    "corners":      ((40, 35, 20, 5), "kit", "corner stairs"),
    "buildings":    ((45, 30, 20, 5), "kit", "buildings"),
}
ALL_KNOBS = dict(KNOBS, **KIT_KNOBS)
FEATURE_KNOBS = {
    "bridge": "bridges", "tower": "towers", "perches": "perches", "pit": "pits",
    "void_gaps": "void_gaps", "stairs": "stairs", "rails": "rails",
    "side_colours": "side_colours", "columns": "columns", "cover_walls": "low_walls",
    "loops": "crossings", "ramps_only": None,
    "fences": "fences", "arches": "arches", "pillars": "colonnades", "diagonals": "diagonals",
    "slabs": "slabs", "corners": "corners", "buildings": "buildings",
}
AMOUNT_LEVELS = {"trace": 1, "few": 1, "less": 1, "more": 3, "lots": 3}
AMOUNT_KNOBS = {"cover_walls": ("low_walls", "cover", "crates"), "tower": ("towers",),
                "bridge": ("bridges",), "ramps": ("ramps",), "pillars": ("colonnades",),
                "columns": ("columns",), "islands": ("islands",), "lanes": ("lanes",),
                "walls": ("walls",), "terrain": ("hills",)}
class Dice(dict):
    def __init__(self, values, boosted=(), forced=()):
        dict.__init__(self, values)
        self.boosted = list(boosted)
        self.forced = dict(forced)
    def level(self, knob):
        return LEVELS[self[knob]]
    def factor(self, knob):
        f = FACTORS[self[knob]]
        if knob in self.boosted:
            f *= BOOST
        return f
    def chance(self, knob, base=0.5):
        return min(1.0, base * (0.0, 0.5, 1.0, 1.6)[self[knob]] * (2 if knob in self.boosted else 1))
    def count(self, knob, some):
        n = int(round(some * (0.0, 0.5, 1.0, 2.0)[self[knob]]))
        if knob in self.boosted:
            n = int(round(n * 1.6)) + 1
        return n
    def as_dict(self):
        return {"rolled": {k: LEVELS[v] for k, v in sorted(self.items())},
                "boosted": list(self.boosted), "forced": dict(sorted(self.forced.items())),
                "about": self.about()}
    def about(self):
        heaps = [k for k in sorted(self) if self[k] == 3 and k not in self.boosted]
        boosted = list(self.boosted)
        nones = [k for k in sorted(self) if self[k] == 0 and ALL_KNOBS[k][1] in ("cover", "height")
                 and k not in self.forced]
        words = []
        if boosted:
            words.append("about %s (boosted)" % " and ".join(ALL_KNOBS[k][2] for k in boosted))
        if heaps:
            words.append("heaps of %s" % ", ".join(ALL_KNOBS[k][2] for k in heaps[:4]))
        if nones:
            words.append("no %s" % ", ".join(ALL_KNOBS[k][2] for k in nones[:3]))
        return "; ".join(words) if words else "a balanced mix"
def _weighted(r, weights):
    total = float(sum(weights))
    x = r.random() * total
    for i, w in enumerate(weights):
        x -= w
        if x < 0:
            return i
    return len(weights) - 1
def roll(brief, r, absurdity=0.2):
    vals = {}
    for k in sorted(KNOBS):
        vals[k] = _weighted(r, KNOBS[k][0])
    boosted = []
    x = r.random()
    pick1, pick2 = r.choice(sorted(KNOBS)), r.choice(sorted(KNOBS))
    if x < absurdity:
        boosted.append(pick1)
        if x < absurdity * 0.25 and pick2 != pick1:
            boosted.append(pick2)
    for k in boosted:
        vals[k] = 3
    from .brief import dna as dna_of
    complexity = dna_of(brief, "complexity")
    forced = {}
    for k in sorted(KIT_KNOBS):
        vals[k] = _weighted(r, KIT_KNOBS[k][0])
        if complexity >= 0.75 and vals[k] < 2:
            vals[k] = 2
            forced[k] = "some (complex structures)"
        elif complexity >= 0.5 and vals[k] < 1:
            vals[k] = 1
        elif complexity <= 0.2 and vals[k] > 0:
            vals[k] = 0
            forced[k] = "none (simple structures)"
    want = set(brief["features"]["want"])
    avoid = set(brief["features"]["avoid"])
    for feat, knob in sorted(FEATURE_KNOBS.items()):
        if knob is None:
            continue
        if feat in want and vals[knob] < 2:
            vals[knob] = 2
            forced[knob] = "some (wanted)"
        if feat in avoid:
            vals[knob] = 0
            forced[knob] = "none (avoided)"
            if knob in boosted:
                boosted.remove(knob)
    for feat, grade in sorted((brief.get("amounts") or {}).items()):
        for knob in AMOUNT_KNOBS.get(feat, (FEATURE_KNOBS.get(feat),)):
            if knob is None or feat in avoid:
                continue
            vals[knob] = AMOUNT_LEVELS[grade]
            forced[knob] = "%s (%s, asked)" % (LEVELS[vals[knob]], grade)
            if knob in boosted and vals[knob] < 3:
                boosted.remove(knob)
    if "ramps_only" in want:
        vals["stairs"] = 0
        forced["stairs"] = "none (ramps only)"
    vert = brief["verticality"]
    if vert == "flat":
        for k in ("height", "towers", "perches", "daises", "pits", "hills", "walls", "canyons"):
            vals[k] = 0
            forced[k] = "none (flat)"
            if k in boosted:
                boosted.remove(k)
    elif vert == "high":
        vals["height"] = max(vals["height"], 2)
        forced["height"] = "%s (high)" % LEVELS[vals["height"]]
    elif vert == "low":
        vals["height"] = min(vals["height"], 1)
        forced["height"] = "%s (low)" % LEVELS[vals["height"]]
    dens = brief["density"]
    if dens == "sparse":
        vals["cover"] = min(vals["cover"], 1)
        forced["cover"] = "%s (sparse)" % LEVELS[vals["cover"]]
    elif dens == "dense":
        vals["cover"] = max(vals["cover"], 2)
        forced["cover"] = "%s (dense)" % LEVELS[vals["cover"]]
    if brief["edge"] == "void":
        vals["rails"] = 0
        forced["rails"] = "none (void edges)"
        if "rails" in boosted:
            boosted.remove("rails")
    return Dice(vals, boosted, forced)
def neutral():
    vals = {k: 2 for k in KNOBS}
    vals.update({k: 0 for k in KIT_KNOBS})
    return Dice(vals)
