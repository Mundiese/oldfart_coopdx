import os
import re
from . import REPO
from mapgen import kit as mkit, v1
SECTIONS = ("shapes", "textures", "prefabs", "decor", "setpieces", "forge", "markers")
class Entry:
    def __init__(self, section, key, label, hint="", make=None, tags=(), data=None):
        self.section = section
        self.key = key
        self.label = label
        self.hint = hint
        self._make = make
        self.tags = tuple(tags)
        self.data = data or {}
    @property
    def id(self):
        return "%s:%s" % (self.section, self.key)
    def make(self, tex="stone1", theme=None, opts=None):
        if not self._make:
            return []
        if opts is not None and self.section == "prefabs":
            return self._make(tex, theme, opts)
        return self._make(tex, theme)
    def __repr__(self):
        return "<Entry %s>" % self.id
def _arenas():
    return v1.arenas_module()
def _shape_rows():
    m = _arenas()
    return [
        ("block", "Block", "a cube, one cell (200)",
         lambda t: m.box(t, 0, 200, 0, 200, 0, 200)),
        ("floor", "Floor", "a 2 x 2 floor, 100 thick",
         lambda t: m.box(t, 0, 400, 0, 100, 0, 400)),
        ("slab", "Slab", "a one-cell slab, 40 thick (ledges, trims)",
         lambda t: m.slab(t, 0, 200, 0, 200, 0, 40)),
        ("wall", "Wall", "4 cells long, 2 high, one thick",
         lambda t: m.box(t, 0, 800, 0, 400, 0, 200)),
        ("ramp", "Ramp", "rises 200 over 400 (26.6 degrees)",
         lambda t: m.ramp(t, 0, 400, 0, 400, 0, 200, "-z")),
        ("stairs", "Stairs", "ten steps up 200 over 400",
         lambda t: m.stairs(t, 0, 400, 0, 400, 0, 200, "-z")),
        ("outer", "Ramp corner", "a hip: one corner up",
         lambda t: m.ramp_corner(t, 0, 400, 0, 400, 0, 200, "-x-z")),
        ("inner", "Ramp valley", "two sides up",
         lambda t: m.ramp_corner(t, 0, 400, 0, 400, 0, 200, "-x-z", inner=True)),
        ("outerstairs", "Corner stairs", "a flight round a corner",
         lambda t: m.corner_stairs(t, 0, 400, 0, 400, 0, 200, "-x-z")),
        ("innerstairs", "Inner corner stairs", "a flight round an inside corner",
         lambda t: m.corner_stairs(t, 0, 400, 0, 400, 0, 200, "-x-z", inner=True)),
        ("rail", "Railing", "4 cells long, jumped over (160 high)",
         lambda t: m.rail(t, 0, 800, 0, 60, 0)),
        ("pillar", "Pillar", "an octagonal column, 3 cells high",
         lambda t: m.pillar(t, 100, 100, 0, 600)),
        ("arch", "Arch", "lay it over a 3-cell gap",
         lambda t: m.arch(t, 0, 600, 0, 200, 0, 200)),
        ("prism", "Diagonal half", "a 45-degree wall in plan",
         lambda t: m.prism(t, 0, 400, 0, 400, 0, 400, "-x-z")),
        ("curve", "Round corner", "a road's round corner, 4 cells",
         lambda t: m.arc("curve", t, 0, 800, 0, 800, 0, 100, "-x-z")),
        ("bank", "Banked corner", "a berm round a corner, 5 cells",
         lambda t: m.arc("bank", t, 0, 1000, 0, 1000, 0, 200, "-x-z")),
        ("arcwall", "Curved wall", "a quarter-round wall, 5 cells",
         lambda t: m.arc("arcwall", t, 0, 1000, 0, 1000, 0, 400, "-x-z")),
        ("ridge", "Gable roof", "a ridge roof, 4 x 3 cells, 26.6 degrees",
         lambda t: m.roof("ridge", t, 0, 800, 0, 600, 0, 150, "x")),
        ("pyramid", "Hip roof", "a pyramid roof, 3 x 3 cells",
         lambda t: m.roof("pyramid", t, 0, 600, 0, 600, 0, 150)),
        ("roundcorner", "Round tower corner", "a quarter of a round tower, 2 cells",
         lambda t: m.round_corner(t, 0, 400, 0, 400, 0, 400, "-x-z")),
        ("ice", "Ice floor", "a slippery floor (the game's ice), 2 x 2",
         lambda t: dict(m.box(t, 0, 400, 0, 100, 0, 400), kind="ice")),
        ("lava", "Lava", "real lava: a burning floor (the game's), 2 x 2 - never stood on",
         lambda t: dict(m.box(t, 0, 400, 0, 100, 0, 400), kind="lava")),
        ("water", "Water surface", "drawn only - the venue's water box swims",
         lambda t: dict(m.box(t, 0, 800, 180, 200, 0, 800), kind="water")),
        ("uslope", "Corbel", "a slope upside down: a bracket under an eave, 1 cell",
         lambda t: m.upside("uslope", t, 0, 200, 0, 200, 0, 200, "-z")),
        ("uouter", "Corbel outer corner", "an upside-down slope corner, 1 cell",
         lambda t: m.upside("uouter", t, 0, 200, 0, 200, 0, 200, "-x-z")),
        ("uinner", "Corbel inner corner", "an upside-down inner corner, 1 cell",
         lambda t: m.upside("uinner", t, 0, 200, 0, 200, 0, 200, "-x-z")),
        ("wedgetip", "Wedge tip", "a gentle ramp's upper half on a foot, 1 cell",
         lambda t: m.wedge_tip("wedgetip", t, 0, 200, 0, 200, 0, 200, "-z")),
        ("wedgetipouter", "Wedge tip outer corner", "a hip skirt's corner, 1 cell",
         lambda t: m.wedge_tip("wedgetipouter", t, 0, 200, 0, 200, 0, 200, "-x-z")),
        ("wedgetipinner", "Wedge tip inner corner", "a valley skirt's corner, 1 cell",
         lambda t: m.wedge_tip("wedgetipinner", t, 0, 200, 0, 200, 0, 200, "-x-z")),
        ("pole", "Pole", "a post 40 across, 3 cells high",
         lambda t: m.pole(t, 100, 100, 0, 600)),
        ("doorway", "Doorway", "a wall cell with a door Mario walks through",
         lambda t: m.opening("doorway", t, 0, 200, 0, 200, 0, 200)),
        ("window", "Window", "a wall cell with a window",
         lambda t: m.opening("window", t, 0, 200, 0, 200, 0, 200)),
    ]
ANCHORS = (
    ("world_spawn", "World spawn", "where everybody arrives; the map shifts onto it"),
    ("spawn", "Spawn area", "spawns here"),
    ("tower", "Tower", "a tall landmark"),
    ("bridge", "Bridge", "a bridge here"),
    ("plaza", "Plaza", "an open square"),
    ("pit", "Pit", "a sunken pit"),
    ("hill", "Hill", "a summit (King of the Hill)"),
    ("flag", "Flag stand", "a team's flag (CTF)"),
    ("point", "Capture point", "a point to hold (Domination)"),
    ("base", "Base", "a team's base"),
    ("landmark", "Landmark", "something everybody sees"),
    ("crown", "Crown", "a raised centre"),
    ("perch", "Perch", "a high spot to shoot from"),
    ("tunnel", "Tunnel", "a way under"),
    ("start_line", "Start line", "a race's start"),
    ("finish", "Finish", "a race's finish"),
    ("checkpoint", "Checkpoint", "a race gate"),
)
ONOFF_OBJECTS = (
    ("onoffswitch", "ON/OFF switch", "stand on it to flip every red and blue block"),
    ("onoffred", "ON/OFF red block", "one full block, solid while the switch reads ON"),
    ("onoffblue", "ON/OFF blue block", "one full block, solid while the switch reads OFF"),
)
def _object_maker(key, air=None):
    if air is None:
        air = key != "onoffswitch"
    return lambda tex=None, theme=None: [("object", dict(
        {"key": key, "x": 0, "y": 0, "z": 0, "yaw": 0}, **({"air": True} if air else {})))]
GERMAN = {
    "block": "Block Wuerfel", "floor": "Boden", "slab": "Platte Stufe", "wall": "Wand Mauer",
    "ramp": "Rampe Schraege", "stairs": "Treppe Stufen", "outer": "Ecke Rampenecke",
    "inner": "Kehle Rampenecke", "outerstairs": "Ecktreppe Treppe", "innerstairs":
    "Ecktreppe Treppe", "rail": "Gelaender Zaun", "pillar": "Saeule", "arch": "Bogen Tor",
    "prism": "Diagonale Schraege Wand", "curve": "Kurve rund", "bank": "Steilkurve Kurve",
    "arcwall": "runde Wand Kurve", "ridge": "Satteldach Dach", "pyramid": "Walmdach Dach Pyramide",
    "roundcorner": "Rundturm Ecke rund", "ice": "Eis glatt", "lava": "Lava brennt",
    "water": "Wasser", "uslope": "Konsole Schraege umgedreht",
    "uouter": "Konsole Ecke umgedreht", "uinner": "Konsole Kehle umgedreht",
    "wedgetip": "Keilspitze flache Rampe", "wedgetipouter": "Keilspitze Ecke",
    "wedgetipinner": "Keilspitze Kehle", "pole": "Pfahl Pfosten Stange",
    "doorway": "Tuer Tuerrahmen", "window": "Fenster",
    "spawn": "Spawn Startpunkt", "world_spawn": "Weltspawn Start",
    "tower": "Turm", "bridge": "Bruecke", "plaza": "Platz", "pit": "Grube Loch",
    "hill": "Huegel", "flag": "Flagge Fahne", "point": "Punkt Eroberung", "base": "Basis",
    "landmark": "Wahrzeichen", "crown": "Krone", "perch": "Aussichtspunkt Hochsitz",
    "tunnel": "Tunnel", "start_line": "Start", "finish": "Ziel", "checkpoint": "Checkpoint Tor",
}
COMMON_FAMILIES = ("blocks", "ramps", "stairs")
def forge_families():
    try:
        from mapgen import prefablib
        return [(name, tuple(tags)) for name, tags in prefablib.tool().slopes().FAMILIES]
    except Exception:
        return []
def family_order():
    try:
        from mapgen import soft64 as s64
        return list(s64._TITLES.values())
    except Exception:
        return []
_SWATCH = {"rows": None, "rgba": {}}
def forget_swatches():
    _SWATCH["rows"] = None
    _SWATCH["rgba"].clear()
def swatch_path(slug):
    if _SWATCH["rows"] is None:
        _, rows = _arenas().blocks.read_manifest()
        _SWATCH["rows"] = {r["slug"]: r for r in rows}
    row = _SWATCH["rows"][slug]
    source = (row.get("layers") or [row["source"]])[0]
    return source if os.path.isabs(source) else os.path.join(REPO, source)
def swatch_rgba(slug):
    if slug in _SWATCH["rgba"]:
        return _SWATCH["rgba"][slug]
    t = mkit.textures().get(slug)
    if t is None:
        raise KeyError("no texture %r" % slug)
    blocks = _arenas().blocks
    path = swatch_path(slug)
    w, h, px = blocks.png_pixels(blocks.read_texture(path), path)
    data = bytearray()
    for line in px:
        for p in line:
            data.extend(p if len(p) == 4 else (p[0], p[1], p[2], 255))
    _SWATCH["rgba"][slug] = (w, h, bytes(data))
    return _SWATCH["rgba"][slug]
class Palette:
    def __init__(self):
        self.entries = []
        self.favourites = []
        self.recent = []
        self.recent_max = 12
        self.reload_listeners = []
        self.reload()
    def reload(self):
        mkit._textures = None
        forget_swatches()
        out = []
        m = _arenas()
        kinds = set(m.KINDS)
        for key, label, hint, build in _shape_rows():
            probe = build("stone1")
            if probe["kind"] not in kinds:
                continue
            out.append(Entry("shapes", key, label, hint, _shape_maker(build),
                             tags=(probe["kind"], m.KINDS[probe["kind"]]["walk"],
                                   GERMAN.get(key, "")),
                             data={"kind": probe["kind"]}))
        try:
            from mapgen import soft64 as s64
        except Exception:
            s64 = None
        fams = forge_families()
        for slug, t in mkit.textures().items():
            fam = s64.family_of(slug) if s64 is not None else None
            family, variant, tile = fam if fam else ("", "", "")
            shapes = sorted(t.get("shapes") or ())
            words = tuple(name.lower() for name, tags in fams
                          if set(tags) & set(shapes) and name.lower() not in COMMON_FAMILIES)
            out.append(Entry("textures", slug, t["name"], "%s%s - %s - %s" % (
                t["shelf"], (" (%s)" % family) if family and family != t["shelf"] else "",
                ", ".join(r for r in t["roles"] if r != "any") or "anything",
                ("%d Forge shapes" % (len(shapes) + 1)) if shapes else "a cube only"),
                tags=(t["shelf"],) + tuple(t["roles"]) + tuple(x for x in (family, variant, tile) if x)
                + words,
                data={"shelf": t["shelf"], "roles": list(t["roles"]),
                      "layered": t.get("layered", False), "family": family,
                      "variant": variant, "soft64": tile, "shapes": shapes,
                      "shape_families": list(words)}))
        try:
            import prefabs as prefabmod
            library = prefabmod.load_all()
        except Exception as why:
            library = {}
            self.prefab_error = str(why)
        else:
            self.prefab_error = None
        for key, pf in sorted(library.items()):
            fx0, fx1, fz0, fz1, top = prefabmod.footprint(pf)
            out.append(Entry("prefabs", key, pf.get("name", key),
                             "%d x %d cells, %d high, %d pieces" % (
                                 fx1 - fx0 + 1, fz1 - fz0 + 1, top + 1, len(pf["pieces"])),
                             _prefab_maker(prefabmod, pf), tags=pf.get("tags", []),
                             data={"roles": pf.get("roles", {}),
                                   "anchor": (-prefabmod.CELL // 2, 0, -prefabmod.CELL // 2)}))
        try:
            from mapgen import decor as decormod
        except Exception:
            decormod = None
        for r in (decormod.RECIPES if decormod is not None else ()):
            c = r.get("collide")
            out.append(Entry("decor", r["key"], r["name"], "one object - %s" % (
                "solid %d x %d x %d" % tuple(c) if c else "no solid (walked through)"),
                _decor_maker(decormod, r["key"]),
                tags=("decor", "prop", "deko") + tuple(r.get("context") or ()),
                data={"recipe": r["rid"], "solid": list(c) if c else None,
                      "hero": bool(r.get("hero"))}))
        try:
            from mapgen import setpieces as spmod
        except Exception:
            spmod = None
        for key, label, hint in (spmod.STUDIO if spmod is not None else ()):
            out.append(Entry("setpieces", key, label,
                             "%s - built where you drop it, on the ground there" % hint,
                             _setpiece_maker(key),
                             tags=("set piece", "setpiece", "landmark", key.replace("_", " "),
                                   SETPIECE_GERMAN.get(key, "")),
                             data={"setpiece": key, "preview": _setpiece_preview(key)}))
        out.append(Entry("setpieces", "hall_house", "Hall house",
                         "a small house whose door leads into a big hall (a tavern, a chapel, "
                         "a home) - bigger inside than out",
                         _setpiece_maker("hall_house"),
                         tags=("set piece", "house", "hall", "inside", "interior", "room",
                               "Haus Halle innen Zimmer Taverne"),
                         data={"setpiece": "hall_house", "preview": _hall_preview}))
        try:
            from . import forgeobjects
            forge = forgeobjects.roster()
        except Exception:
            forge = []
        for f in forge:
            hint = "%s - Forge object%s" % (f.shelf or "Forge", (
                ", %d kinds (Properties)" % len(f.variants)) if f.variants else "")
            out.append(Entry("forge", f.key, f.name, hint, _object_maker(f.key, f.floats),
                             tags=("forge", "objekt", f.key, f.shelf) + tuple(
                                 n for _, n in f.variants),
                             data={"shelf": f.shelf, "variants": len(f.variants),
                                   "floats": f.floats}))
        out.append(Entry("markers", "world", "World spawn",
                         "where everybody arrives in the venue (one; placing it again moves it)",
                         lambda tex, theme: [("spot", {"_name": "world", "x": 0, "y": 0,
                                                       "z": 0, "yaw": 0})],
                         tags=("world", "spawn", "entry", "arrive", "Weltspawn Start Eingang")))
        from mapgen import modeready
        for name, (label, hint) in modeready.SPOTS.items():
            out.append(Entry("markers", "spot." + name, label,
                             "%s (one; placing it again moves it)" % hint,
                             _spot_maker(name),
                             tags=("mode", "survey", "point", name, label.lower())))
        out.append(Entry("markers", "spawn", "Spawn point", "where a player starts (facing -z)",
                         lambda tex, theme: [("spawn", {"x": 0, "y": 0, "z": 0, "yaw": 0})],
                         tags=("spawn", GERMAN["spawn"])))
        out.append(Entry("markers", "star", "Bonus star",
                         "a star to collect (number 1-6 and name in Properties)",
                         lambda tex, theme: [("star", {"id": 0, "kind": "hand", "x": 0, "y": 0,
                                                       "z": 0, "grade": 1, "name": ""})],
                         tags=("star", "bonus", "Bonusstern Stern")))
        for key, label, hint in ONOFF_OBJECTS:
            out.append(Entry("markers", "onoff." + key, label, hint, _object_maker(key),
                             tags=("onoff", "on/off", "switch", "block", "smw", "Schalter")))
        for what, label, hint in ANCHORS:
            out.append(Entry("markers", "anchor." + what, label, hint, _anchor_maker(what),
                             tags=("anchor", what, GERMAN.get(what, ""))))
        self.entries = out
        for fn in list(getattr(self, "reload_listeners", ())):
            fn()
        return out
    def section(self, name):
        return [e for e in self.entries if e.section == name]
    def families(self):
        order = family_order()
        groups = {}
        for e in self.section("textures"):
            groups.setdefault(e.data.get("family") or e.data.get("shelf") or "", []).append(e)
        known = [f for f in order if f in groups]
        rest = sorted(f for f in groups if f not in order)
        return [(f, groups[f]) for f in known + rest]
    def in_family(self, entries, family):
        if not family:
            return list(entries)
        return [e for e in entries if e.section != "textures"
                or (e.data.get("family") or e.data.get("shelf")) == family]
    def get(self, entry_id):
        for e in self.entries:
            if e.id == entry_id:
                return e
        raise KeyError(entry_id)
    def search(self, text, section=None):
        words = [_fold(w) for w in re.split(r"\s+", text or "") if w]
        hits = []
        for e in self.entries:
            if section and e.section != section:
                continue
            hay = _fold(" ".join([e.label, e.key, e.hint] + list(e.tags)))
            if all(w in hay for w in words):
                hits.append(e)
        rank = {eid: n for n, eid in enumerate(self.favourites)}
        recent = {eid: n for n, eid in enumerate(self.recent)}
        return sorted(hits, key=lambda e: (0 if e.id in rank else 1 if e.id in recent else 2,
                                           rank.get(e.id, recent.get(e.id, 0))))
    def used(self, entry_id):
        if entry_id in self.recent:
            self.recent.remove(entry_id)
        self.recent.insert(0, entry_id)
        del self.recent[self.recent_max:]
    def toggle_favourite(self, entry_id):
        if entry_id in self.favourites:
            self.favourites.remove(entry_id)
        else:
            self.favourites.append(entry_id)
    def state(self):
        return {"favourites": list(self.favourites), "recent": list(self.recent)}
    def restore(self, state):
        have = set(e.id for e in self.entries)
        self.favourites = [x for x in (state or {}).get("favourites", []) if x in have]
        self.recent = [x for x in (state or {}).get("recent", []) if x in have]
def _fold(s):
    s = s.lower()
    for a, b in (("ä", "a"), ("ö", "o"), ("ü", "u"), ("ae", "a"), ("oe", "o"), ("ue", "u"),
                 ("ß", "ss"), ("_", " ")):
        s = s.replace(a, b)
    return s
def _shape_maker(build):
    def make(tex, theme):
        p = build(tex)
        if not p.get("tag"):
            p.pop("tag", None)
        return [("piece", p)]
    return make
def _decor_maker(decormod, key):
    def make(tex, theme):
        p = decormod.piece(key, 0, 0, 0, 0, theme=None if theme in (None, "auto") else theme)
        p["context"] = "studio"
        return [("piece", p)]
    return make
PREFAB_OPTS = {"merge": True, "mirror": None, "ruin": 0.0, "seed": 1}
def _prefab_maker(prefabmod, pf):
    def make(tex, theme, opts=None):
        pieces, skipped = prefabmod.arena_pieces(pf, (0, 0, 0), 0,
                                                  None if theme in (None, "auto") else theme)
        tagged = []
        for p in pieces:
            p = dict(p)
            p["tag"] = "prefab.%s" % pf.get("key", "")
            tagged.append(p)
        from studio.library import prefablib
        return [("piece", p) for p in prefablib.laid(
            tagged, opts if opts is not None else PREFAB_OPTS)]
    return make
SETPIECE_GERMAN = {
    "giant_mushrooms": "Riesenpilze Pilzwald Pilze", "waterfall": "Wasserfall Grotte Hoehle",
    "lookout": "Aussichtsturm Turm", "spiral_path": "Wendelweg Gipfel Berg",
    "secret_alcove": "Versteck Geheimversteck", "slide": "Rutsche Eisrutsche",
    "floating_islands": "schwebende Inseln Himmelsinseln",
}
def _setpiece_maker(key):
    def make(tex, theme):
        return [("setpiece", {"kind": key, "theme": theme, "x": 0, "y": 0, "z": 0})]
    return make
_previews = {}
def _setpiece_preview(key):
    def preview():
        if key not in _previews:
            from mapgen import setpieces
            _previews[key] = setpieces.preview(key)
        return _previews[key]
    return preview
def _hall_preview():
    if "hall_house" not in _previews:
        from mapgen import pockets
        got, _ = pockets.hall_house({"pieces": []}, 0, 0, 0)
        _previews["hall_house"] = [p for p in got or []
                                   if not str(p.get("tag", "")).startswith("pocket")]
    return _previews["hall_house"]
def _spot_maker(name):
    def make(tex, theme):
        return [("spot", {"_name": name, "x": 0, "y": 0, "z": 0, "yaw": 0})]
    return make
def _anchor_maker(what):
    def make(tex, theme):
        return [("anchor", {"what": what, "where": {"x": 0, "z": 0}, "hard": True})]
    return make
def theme_texture(theme, role):
    pal = mkit.THEMES.get(theme or "castle") or mkit.THEMES["castle"]
    tex = pal.get(role)
    return tex if isinstance(tex, str) else pal["floor"]
