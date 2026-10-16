from . import v1
ROLES = {
    "stone1": ("floor", "wall", "accent"), "stone2": ("floor", "wall", "keel"),
    "flagstone": ("floor",), "mossyrock": ("wall", "keel"), "greystone": ("wall",),
    "frostedrock": ("floor", "wall", "keel"),
    "brickdarkgrey": ("wall", "ramp"), "bricklightgrey": ("wall", "ramp"),
    "brickpyramid": ("accent", "wall"), "bricktwocolored": ("accent",),
    "redbrick": ("wall",), "whitestonebrick": ("wall",),
    "woodenplank1": ("floor", "bridge"), "woodenplank2": ("floor", "bridge", "accent"),
    "hatchedwood": ("floor", "bridge", "deck"), "darkplanks": ("floor", "wall"),
    "shipplanks": ("floor", "wall", "bridge"), "greenplanks": ("wall",), "crate": ("accent", "cover"),
    "diamondplate": ("floor", "deck"), "studdedsteel": ("wall",), "rivetedplate": ("trim",),
    "sand": ("floor",), "grass": ("floor",), "dirt": ("floor", "ramp"),
    "tile1": ("floor", "deck"), "tile2": ("floor",), "hexpaving": ("floor", "deck"),
    "whitemarble": ("wall", "floor"), "carpet": ("floor", "accent"), "lava": ("accent",),
    "ice": ("floor", "deck"), "glassblock": ("accent",), "hazardstripes": ("trim",),
}
THEMES = {
    "castle": {"floor": "tile2", "deck": "tile1", "wall": "brickdarkgrey", "ramp": "bricklightgrey",
               "bridge": "woodenplank1", "keel": "stone2", "cover": "brickdarkgrey",
               "trim": "rivetedplate",
               "accents": ["stone1", "brickpyramid", "carpet", "woodenplank2"]},
    "ice": {"floor": "snowblock", "deck": "ice", "wall": "whitestonebrick", "ramp": "stone1",
            "bridge": "hatchedwood", "keel": "frostedrock", "cover": "whitestonebrick",
            "trim": "glassblock",
            "accents": ["ice", "stone1", "glassblock", "whitemarble"]},
    "desert": {"floor": "sandblock", "deck": "hexpaving", "wall": "brickpyramid", "ramp": "bricklightgrey",
               "bridge": "woodenplank2", "keel": "flagstone", "cover": "brickpyramid",
               "trim": "bricktwocolored",
               "accents": ["stone1", "carpet", "bricktwocolored", "flagstone"]},
    "lava": {"floor": "flagstone", "deck": "tile1", "wall": "redbrick", "ramp": "brickdarkgrey",
             "bridge": "darkplanks", "keel": "lava", "cover": "redbrick", "trim": "hazardstripes",
             "accents": ["lava", "carpet", "brickpyramid", "greystone"]},
    "wood": {"floor": "woodenplank1", "deck": "hatchedwood", "wall": "darkplanks",
             "ramp": "woodenplank2", "bridge": "shipplanks", "keel": "greenplanks",
             "cover": "crate", "trim": "rivetedplate",
             "accents": ["carpet", "greenplanks", "hatchedwood", "shipplanks"]},
    "sky": {"floor": "whitemarble", "deck": "tile1", "wall": "whitestonebrick", "ramp": "stone1",
            "bridge": "hatchedwood", "keel": "stone2", "cover": "whitestonebrick",
            "trim": "glassblock",
            "accents": ["stone1", "brickpyramid", "carpet", "glassblock"]},
    "garden": {"floor": "grassblock", "deck": "hexpaving", "wall": "mossyrock", "ramp": "dirt",
               "bridge": "woodenplank1", "keel": "dirt", "cover": "greenplanks",
               "trim": "flagstone",
               "accents": ["grass", "flagstone", "carpet", "woodenplank2"]},
}
THEMES_BEFORE_SOFT64 = {t: dict(v) for t, v in THEMES.items()}
def _soft64_themes():
    try:
        from . import soft64
    except ImportError:
        return
    for theme in soft64.THEMES:
        pal = soft64.theme_palette(theme)
        if pal and all(pal.get(r) for r in ("floor", "deck", "wall", "ramp", "bridge", "keel",
                                             "cover", "trim")) and len(pal.get("accents") or ()) >= 4:
            THEMES[theme] = pal
_soft64_themes()
LOOKS = {
    "castle": ("BACKGROUND_PURPLE_SKY", "SEQ_LEVEL_KOOPA_ROAD"),
    "ice": ("BACKGROUND_SNOW_MOUNTAINS", "SEQ_LEVEL_SNOW"),
    "desert": ("BACKGROUND_DESERT", "SEQ_LEVEL_HOT"),
    "lava": ("BACKGROUND_FLAMING_SKY", "SEQ_LEVEL_BOSS_KOOPA_FINAL"),
    "wood": ("BACKGROUND_OCEAN_SKY", "SEQ_LEVEL_WATER"),
    "sky": ("BACKGROUND_ABOVE_CLOUDS", "SEQ_LEVEL_SLIDE"),
    "garden": ("BACKGROUND_OCEAN_SKY", "SEQ_LEVEL_GRASS"),
}
SUN_STOPS = {
    "early, from the east": (0.9, 0.35, 0.1), "overhead": (0, 1, 0),
    "late, from the west": (-0.9, 0.35, -0.1), "from underneath": (0, -1, 0),
    "from the north": (0.1, 0.4, 0.9), "low and behind": (0, 0.15, -1.0),
    "from the south": (-0.1, 0.4, -0.9), "flat on from the east": (1.0, 0.05, 0),
    "flat on from the west": (-1.0, 0.05, 0),
}
FLOOR_LIGHT_MIN = 0.35
SUN_STOPS["none"] = (0, 0, 0)
L3_STOPS = ("none", "from the north")
LIGHTS = {
    "castle": ((("none", 2), ("from the north", 1)), 0),
    "ice": ((("none", 1), ("from the north", 1)), 0),
    "desert": ((("none", 2), ("from the north", 1)), 0),
    "lava": ((("none", 2), ("from the north", 1)), 0),
    "wood": ((("from the north", 2), ("none", 1)), 0),
    "sky": ((("none", 1), ("from the north", 1)), 0),
    "garden": ((("none", 2), ("from the north", 1)), 0),
}
FAMILY_LIGHT = {"shooter": "from the north"}
def light(theme, r=None, family=None):
    stops, dark = LIGHTS.get(theme, LIGHTS["castle"])
    name = stops[0][0]
    if family in FAMILY_LIGHT:
        name = FAMILY_LIGHT[family]
    elif r is not None:
        total = sum(w for _, w in stops)
        x = r.random() * total
        for n, w in stops:
            x -= w
            if x < 0:
                name = n
                break
    return {"name": name, "dir": list(SUN_STOPS[name])}, dark
FORBIDDEN = ("brick",)
FACES = ("top", "side", "bottom")
def tex_key(piece):
    extra = tuple((f, piece["tex_" + f]) for f in FACES if piece.get("tex_" + f))
    return piece["tex"] if not extra else (piece["tex"], extra)
def with_tex(piece, key):
    if isinstance(key, tuple):
        piece["tex"] = key[0]
        for f, t in key[1]:
            piece["tex_" + f] = t
    else:
        piece["tex"] = key
    return piece
def textures_of(piece):
    return [piece["tex"]] + [piece["tex_" + f] for f in FACES if piece.get("tex_" + f)]
def cap_top_layers(pieces, cap):
    if not layered(cap):
        return pieces
    out = []
    for p in pieces:
        if p["kind"] != "box":
            out.append(p)
            continue
        top = p["y"] + p["h"]
        covered = any(q is not p and q["y"] == top and abs(q["x"] - p["x"]) * 2 < p["w"] + q["w"]
                      and abs(q["z"] - p["z"]) * 2 < p["d"] + q["d"] for q in pieces)
        if covered:
            out.append(p)
        elif p["h"] <= TRANSITION_MAX:
            out.append(dict(p, tex=cap))
        else:
            out.append(dict(p, h=p["h"] - TRANSITION_MAX,
                            tex=TRANSITION_BASE.get(cap, p["tex"])))
            out.append(dict(p, y=top - TRANSITION_MAX, h=TRANSITION_MAX, tex=cap))
    return out
class Kind:
    def __init__(self, name, cells, make, walk=None, sizes=None, mesh=None):
        self.name = name
        self.cells = cells
        self.make = make
        self.walk = walk
        self.sizes = sizes
        self.mesh = mesh
    def __repr__(self):
        return "Kind(%s, %s, %s)" % (self.name, self.cells, self.walk)
KINDS = {}
def register_kind(name, cells, make, walk=None, sizes=None, mesh=None):
    if cells not in ("box", "wedge", "atomic"):
        raise ValueError("cells must be box, wedge or atomic")
    KINDS[name] = Kind(name, cells, make, walk, sizes, mesh)
    return KINDS[name]
CELLS_OF = {"box": "box", "ramp": "wedge", "stairs": "wedge"}
def _builtin_kinds():
    m = v1.arenas_module()
    def make_box(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        return m.box(tex, x0, x1, y0, y1, z0, z1, tag)
    def make_ramp(tex, x0, x1, y0, y1, z0, z1, rises="-z", tag=""):
        return m.ramp(tex, x0, x1, z0, z1, y0, y1, rises, tag)
    def make_stairs(tex, x0, x1, y0, y1, z0, z1, rises="-z", tag=""):
        return m.stairs(tex, x0, x1, z0, z1, y0, y1, rises, tag)
    def make_corner(inner, stairs):
        def make(tex, x0, x1, y0, y1, z0, z1, high="-x-z", tag=""):
            fn = m.corner_stairs if stairs else m.ramp_corner
            return fn(tex, x0, x1, z0, z1, y0, y1, high, inner, tag)
        return make
    def make_rail(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        return m.rail(tex, x0, x1, z0, z1, y0, y1 - y0, tag)
    def make_pillar(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        return m.pillar(tex, (x0 + x1) / 2, (z0 + z1) / 2, y0, y1, x1 - x0, tag)
    def make_arch(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        return m.arch(tex, x0, x1, z0, z1, y0, y1, tag)
    def make_prism(tex, x0, x1, y0, y1, z0, z1, solid="-x-z", tag=""):
        return m.prism(tex, x0, x1, z0, z1, y0, y1, solid, tag)
    def make_arc(kind):
        def make(tex, x0, x1, y0, y1, z0, z1, centre="-x-z", tag=""):
            return m.arc(kind, tex, x0, x1, z0, z1, y0, y1, centre, tag)
        return make
    def make_water(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        p = m.box(tex, x0, x1, y0, y1, z0, z1, tag)
        p["kind"] = "water"
        return p
    def make_ice(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        p = m.box(tex, x0, x1, y0, y1, z0, z1, tag)
        p["kind"] = "ice"
        return p
    def make_lava(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        p = m.box(tex, x0, x1, y0, y1, z0, z1, tag)
        p["kind"] = "lava"
        return p
    def make_roof(kind):
        def make(tex, x0, x1, y0, y1, z0, z1, along="x", tag=""):
            return m.roof(kind, tex, x0, x1, z0, z1, y0, y1, along or "x", tag)
        return make
    def make_round(tex, x0, x1, y0, y1, z0, z1, centre="-x-z", tag=""):
        return m.round_corner(tex, x0, x1, z0, z1, y0, y1, centre, tag)
    def make_upside(kind):
        def make(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
            toward = rises or ("-z" if kind in ("uslope", "wedgetip") else "-x-z")
            fn = m.upside if kind.startswith("u") else m.wedge_tip
            return fn(kind, tex, x0, x1, z0, z1, y0, y1, toward, tag)
        return make
    def make_pole(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
        return m.pole(tex, (x0 + x1) / 2, (z0 + z1) / 2, y0, y1, x1 - x0, tag)
    def make_opening(kind):
        def make(tex, x0, x1, y0, y1, z0, z1, rises=None, tag=""):
            return m.opening(kind, tex, x0, x1, z0, z1, y0, y1, tag)
        return make
    makers = {"ridge": make_roof("ridge"), "pyramid": make_roof("pyramid"),
              "roundcorner": make_round, "ice": make_ice, "lava": make_lava, "water": make_water, "curve": make_arc("curve"), "bank": make_arc("bank"),
              "arcwall": make_arc("arcwall"),
              "box": make_box, "ramp": make_ramp, "stairs": make_stairs,
              "outer": make_corner(False, False), "inner": make_corner(True, False),
              "outerstairs": make_corner(False, True), "innerstairs": make_corner(True, True),
              "rail": make_rail, "pillar": make_pillar, "arch": make_arch,
              "prism": make_prism,
              "pole": make_pole, "doorway": make_opening("doorway"),
              "window": make_opening("window")}
    for _k in ("uslope", "uouter", "uinner", "wedgetip", "wedgetipouter", "wedgetipinner"):
        makers[_k] = make_upside(_k)
    registry = getattr(m, "KINDS", None)
    names = list(registry) if registry else sorted(getattr(m, "SOLIDS", {}))
    for name in names:
        row = registry.get(name, {}) if registry else {}
        make = makers.get(name)
        if make is None:
            def make(tex, x0, x1, y0, y1, z0, z1, rises="-z", tag="", _k=name):
                p = m.ramp(tex, x0, x1, z0, z1, y0, y1, rises, tag)
                p["kind"] = _k
                return p
        register_kind(name, CELLS_OF.get(name, "atomic"), make, row.get("walk"),
                      row.get("sizes"), row.get("mesh"))
ICE_TEXTURES = ("ice",)
def slippery(pieces):
    n = 0
    if "ice" not in kinds():
        return 0
    m = v1.arenas_module()
    for p in pieces:
        if p.get("kind") == "box" and p.get("tex") in ICE_TEXTURES:
            p["kind"] = "ice"
            if "model" in p:
                p["model"] = m.model_name(p)
            n += 1
    return n
LAVA_TEXTURES = ("lava", "lavaflow")
HAZARD_KINDS = ("lava",)
def burning(pieces):
    n = 0
    if "lava" not in kinds():
        return 0
    m = v1.arenas_module()
    for p in pieces:
        if p.get("kind") == "box" and p.get("tex") in LAVA_TEXTURES:
            p["kind"] = "lava"
            if "model" in p:
                p["model"] = m.model_name(p)
            n += 1
    return n
def surfaces(pieces):
    return slippery(pieces), burning(pieces)
def kinds():
    if not KINDS:
        _builtin_kinds()
    return KINDS
def kind(name):
    k = kinds().get(name)
    if k is None:
        raise KeyError("no piece kind %r (kinds: %s)" % (name, ", ".join(sorted(kinds()))))
    return k
_textures = None
WAS = {}
def textures():
    global _textures
    if _textures is None:
        blocks = v1.arenas_module().blocks
        _, rows = blocks.read_manifest()
        out = {}
        for row in rows:
            if row["slug"] in FORBIDDEN:
                continue
            layered = bool(row.get("layers"))
            own = tuple(row.get("roles") or ())
            roles = ("cap",) if layered else (own or ROLES.get(row["slug"], ("any",)))
            out[row["slug"]] = {"name": row["name"], "shelf": row["shelf"],
                                "source": row["source"], "layered": layered,
                                "roles": roles, "roles_from": "manifest" if own and not layered
                                else "table", "shapes": _shape_set(row)}
            for old in row.get("was") or ():
                WAS[old] = row["slug"]
                if not layered and not own and row["slug"] not in ROLES and old in ROLES:
                    out[row["slug"]]["roles"] = ROLES[old]
        _split_roles(out)
        _textures = out
    return _textures
FOLIAGE_KEYS = ("hedge", "leaves", "fern", "flowers", "mushrooms")
FABRIC_KEYS = ("banner", "canvas", "carpet", "rug", "quilt", "wool", "cloth")
def _split_roles(out):
    for slug, t in out.items():
        if t.get("layered"):
            continue
        roles = list(t["roles"])
        plant = slug.startswith(FOLIAGE_KEYS) or slug.startswith("leaves")
        cloth = slug.startswith(FABRIC_KEYS)
        if not (plant or cloth):
            continue
        roles = [r for r in roles if r != "wall"]
        if plant and "foliage" not in roles:
            roles.append("foliage")
        t["roles"] = tuple(roles) or ("accent",)
def _shape_set(row):
    try:
        from . import prefablib
        return frozenset(prefablib.tool().slopes().shape_set(row))
    except Exception:
        return frozenset()
KIND_SHAPE = {"ridge": "ridge", "pyramid": "pyramid", "roundcorner": "roundcorner",
              "rail": "fence", "pillar": "pillar", "arch": "arch", "prism": "prism",
              "stairs": "stairs", "outer": "outer", "inner": "inner", "ramp": "slope",
              "uslope": "uslope", "uouter": "uouter", "uinner": "uinner",
              "wedgetip": "wedgetip", "wedgetipouter": "wedgetipouter",
              "wedgetipinner": "wedgetipinner", "pole": "pole", "doorway": "doorway",
              "window": "window"}
def comes_in(slug, kind):
    shape = KIND_SHAPE.get(kind)
    t = textures().get(slug)
    if t is None:
        return False
    return shape is None or shape in (t.get("shapes") or ())
DRESS_ROLES = {
    "fence": ("rail", ("bridge", "trim", "cover", "deck", "wall")),
    "column": ("pillar", ("wall_cap", "trim", "wall", "wall_base")),
    "arch": ("arch", ("wall", "wall_cap", "trim")),
    "stair": ("stairs", ("ramp", "deck", "floor", "wall")),
}
def dress_tex(pal, role, fallback=None):
    if isinstance(pal.get(role), str) and pal[role] in textures():
        return pal[role]
    kind, prefs = DRESS_ROLES[role]
    have = textures()
    for want in prefs:
        tex = pal.get(want)
        if isinstance(tex, str) and tex in have and not layered(tex) and comes_in(tex, kind):
            return tex
    return fallback
def for_kind(kind, choices, role=None):
    for c in choices:
        if c and comes_in(c, kind):
            return c
    if role:
        for c in with_role(role):
            if comes_in(c, kind):
                return c
    return choices[0] if choices else None
def with_role(role):
    return [s for s, t in textures().items()
            if role in t["roles"] or ("any" in t["roles"] and not t.get("layered"))]
TRANSITION_MAX = 200
TRANSITION_BASE = {"grassblock": "dirt", "snowblock": "frostedrock", "sandblock": "sand"}
try:
    from . import soft64 as _soft64
    TRANSITION_BASE.update(_soft64.transition_bases())
except Exception:
    pass
def layered(slug):
    return bool(textures().get(slug, {}).get("layered"))
def palette(theme, override=None):
    base = dict(THEMES.get(theme) or THEMES["castle"])
    have = textures()
    base = {r: ([WAS.get(t, t) if isinstance(t, str) else t for t in v] if isinstance(v, list)
                else WAS.get(v, v) if isinstance(v, str) else v) for r, v in base.items()}
    notes = []
    for role, choices in sorted((override or {}).items()):
        choices = [WAS.get(t, t) for t in choices]
        ok = [t for t in choices if t in have]
        if not ok:
            notes.append("palette %s: none of %s is a Forge texture" % (role, ", ".join(choices)))
            continue
        if role in ("accent", "accents"):
            base["accents"] = (ok * 4)[:4]
        else:
            base[role] = ok[0]
    for role, tex in list(base.items()):
        if role == "accents":
            base[role] = [t if t in have else (with_role("accent") or list(have))[0] for t in tex]
        elif tex not in have:
            fallback = (with_role(role) or list(have))[0]
            notes.append("theme %s: %s is not in the manifest, used %s" % (theme, tex, fallback))
            base[role] = fallback
    if not override or not any(r in override for r in ("accent", "accents")):
        notes += _dna_palette(base, theme)
    if PALETTE_FAMILY.get("family") and (
            not override or not any(r in override for r in ("floor", "wall", "trim"))):
        from . import values
        notes += values.bands(base, theme, PALETTE_FAMILY.get("family"))
    from . import contract
    notes += contract.split_roles(theme if theme in THEMES else "castle", base)
    return base, notes
PALETTE_DNA = {}
PALETTE_FAMILY = {}
WORN = ("mossyrock", "greystone", "stone2", "frostedrock", "flagstone")
NOT_ACCENT = ("lava", "hazardstripes", "grassblock", "snowblock", "sandblock", "brick", "crate",
              "glassblock",
              "tile1")
NOT_NATURAL = ("tile1", "tile2", "rivetedplate", "diamondplate", "studdedsteel", "carpet",
               "whitemarble", "brickpyramid", "bricktwocolored", "redbrick")
def _dna_palette(pal, theme):
    coh = PALETTE_DNA.get("coherence")
    age = PALETTE_DNA.get("age")
    notes = []
    if coh is None and age is None:
        return notes
    try:
        cols = colours()
    except Exception:
        return notes
    used = set(v for k, v in pal.items() if k != "accents")
    def dist(a, b):
        return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
    pool = [t for t in sorted(cols) if t not in NOT_ACCENT and t not in FORBIDDEN]
    if theme == "garden" or (PALETTE_DNA.get("nature") or 0) >= 0.6:
        pool = [t for t in pool if t not in NOT_NATURAL]
    if coh is not None and coh >= 0.7:
        refs = [cols[pal[r]] for r in ("floor", "wall", "deck") if pal.get(r) in cols]
        if refs:
            mean = tuple(sum(c[i] for c in refs) / len(refs) for i in range(3))
            near = sorted((t for t in pool if t not in used), key=lambda t: dist(cols[t], mean))
            if len(near) >= 4:
                pal["accents"] = near[:4]
                notes.append("dna coherence %.2f: accents %s (nearest the floor and walls)"
                             % (coh, ", ".join(pal["accents"])))
    elif coh is not None and coh <= 0.3:
        def sat(t):
            c = cols[t]
            return max(c) - min(c)
        bright = sorted(pool, key=lambda t: (-sat(t), t))
        pal["accents"] = bright[:4]
        notes.append("dna coherence %.2f: accents %s (the most colourful)"
                     % (coh, ", ".join(pal["accents"])))
    if age is not None and age >= 0.6 and pal.get("wall") in cols:
        worn = [t for t in WORN if t in cols and t != pal.get("floor")]
        if worn:
            w = min(worn, key=lambda t: dist(cols[t], cols[pal["wall"]]))
            notes.append("dna age %.2f: walls %s -> %s" % (age, pal["wall"], w))
            if pal.get("cover") == pal["wall"]:
                pal["cover"] = w
            pal["wall"] = w
    return notes
def look(theme, sky="auto", music="auto", r=None, family=None):
    s, m = LOOKS.get(theme, LOOKS["castle"])
    out = {"sky": s if sky in (None, "auto") else sky,
           "music": m if music in (None, "auto") else music}
    lt, dark = light(theme, r, family)
    out["light"] = lt
    if dark:
        out["dark"] = dark
    from . import bake
    out["bake"] = bake.palette(theme)
    return out
_colours = None
def colours():
    global _colours
    if _colours is None:
        m = v1.arenas_module()
        out = {}
        for slug, t in textures().items():
            png = m.blocks.read_texture(_repo_path(t["source"]))
            out[slug] = m.average_colour(png)
        _colours = out
    return _colours
def _repo_path(rel):
    import os
    return os.path.join(v1.REPO, rel)
THEME_VISUALS = {
    "castle": ["sunset"], "ice": ["moonlight", "snow"], "desert": ["warm_sun", "sepia"],
    "lava": ["sunset"], "wood": ["warm_sun"], "sky": [],
    "garden": ["warm_sun", "petals"],
}
BIOME_FOG = {"garden": "sky_haze", "castle": "sky_haze", "wood": "sky_haze",
             "ice": "sky_haze", "desert": "sky_haze", "lava": "sky_haze"}
BIOME_FOG_FAMILIES = ("explore",)
def venue_visuals(names, theme, family=None):
    from .brief import VISUALS
    out, rows = [], set()
    names = list(names)
    if family in BIOME_FOG_FAMILIES and BIOME_FOG.get(theme):
        names.append(BIOME_FOG[theme])
    for name in names:
        expand = THEME_VISUALS.get(theme, []) if name == "auto" else [name]
        for n in expand:
            row, stop = VISUALS.get(n, (None, None))
            if row and row not in rows:
                rows.add(row)
                if stop:
                    out.append([row, stop])
    return out
_tracks = None
_music_mod = None
def _music_tool():
    global _music_mod
    if _music_mod is None:
        import importlib.util
        import os
        spec = importlib.util.spec_from_file_location("mapgen_kit_music",
                                                      _repo_path(os.path.join("tools", "music.py")))
        _music_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_music_mod)
    return _music_mod
def music_tracks():
    global _tracks
    if _tracks is not None:
        return _tracks
    import re
    with open(_repo_path("of_music.lua"), encoding="utf-8") as handle:
        text = handle.read()
    out = []
    for m in re.finditer(r'\{\s*seq\s*=\s*(SEQ_\w+)\s*,\s*name\s*=\s*"([^"]+)"', text):
        out.append({"key": m.group(1), "name": m.group(2), "label": m.group(2),
                    "stream": False})
    text = _music_tool().luaregion().restore(text, "of_music.lua")
    begin = re.search(r"-- music\.py: rows begin[^\n]*\n", text)
    end = text.find("-- music.py: rows end", begin.end()) if begin else -1
    if begin and end > 0:
        text = text[begin.end():end]
    for m in re.finditer(r'\{\s*file\s*=\s*"([^"]+)"([^{}]*)\}', text):
        body = m.group(2)
        name = re.search(r'name\s*=\s*"([^"]+)"', body)
        ext = re.search(r'ext\s*=\s*"([^"]+)"', body)
        title = name.group(1) if name else m.group(1)
        mt = _music_tool()
        fields = mt.parse_row_literal(m.group(0) + ",")
        out.append({"key": m.group(1), "name": title, "artist": mt.row_artist(fields),
                    "label": mt.row_label(fields), "imported": True,
                    "stream": bool(ext and ext.group(1) != "m64")})
    for t in out:
        names = [t["name"]]
        short = re.sub(r"^[A-Z0-9][A-Za-z0-9-]*\d[A-Za-z0-9-]*\s+(-\s+)?", "", t["name"])
        if short != t["name"]:
            names.append(short)
        words = re.sub(r"\s+-\s+", " ", t["name"]).split()
        for k in range(1, len(words) - 1):
            tail = " ".join(words[k:])
            if tail not in names:
                names.append(tail)
        t["names"] = names
    _tracks = out
    return out
def music_key(value):
    if value in (None, "auto"):
        return value
    for t in music_tracks():
        if value == t["key"] or str(value).lower() in (t["name"].lower(),
                                                       t["label"].lower()):
            return t["key"]
    return None
def levels():
    return v1.arenas_module().LEVELS
_SHELVES = {}
def forge_shelves():
    import os
    import re
    if _SHELVES:
        return dict(_SHELVES)
    path = os.path.join(v1.REPO, "of_forge.lua")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    start = text.find("forge.CATEGORIES = {")
    if start < 0:
        return {}
    body = text[start:]
    end = re.search(r"\n}\n", body)
    body = body[:end.start()] if end else body
    shelf = None
    for line in body.splitlines():
        line = line.split("--", 1)[0]
        m = re.search(r'name = "([^"]+)"', line)
        if m:
            shelf = m.group(1)
            line = line[m.end():]
        for k in re.findall(r'"([a-z0-9_]+)"', line):
            if shelf:
                _SHELVES.setdefault(k, shelf)
    return dict(_SHELVES)
def forge_keys():
    import os
    import re
    path = os.path.join(v1.REPO, "of_forge.lua")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    start = text.find("forge.CATEGORIES = {")
    if start < 0:
        return None
    body = text[start:]
    end = re.search(r"\n}\n", body)
    body = body[:end.start()] if end else body
    keys = []
    for line in body.splitlines():
        line = line.split("--", 1)[0]
        keys += re.findall(r'"([a-z0-9_]+)"', line)
    names = set(re.findall(r'name = "([^"]+)"', body))
    return sorted(set(k for k in keys if k not in names))
COIN_FORMATION_NAMES = {"line": "a line", "column": "a column", "ring": "a ring",
                        "arch": "an arch", "arrow": "an arrow"}
_COIN_VARIANTS = []
def coin_variants():
    import os
    import re
    if _COIN_VARIANTS:
        return list(_COIN_VARIANTS)
    path = os.path.join(v1.REPO, "of_spawner.lua")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as handle:
        code = "\n".join(line.split("--", 1)[0] for line in handle.read().splitlines())
    m = re.search(r'\{\s*key\s*=\s*"coins"\s*,', code)
    if not m:
        return []
    body = code[m.end():]
    nxt = re.search(r'\{\s*key\s*=\s*"', body)
    body = body[:nxt.start()] if nxt else body
    for v in re.finditer(r'\{\s*name\s*=\s*"([^"]*)"\s*,\s*value\s*=\s*(0x[0-9A-Fa-f]+|\d+)',
                         body):
        _COIN_VARIANTS.append((v.group(1), int(v.group(2), 0)))
    return list(_COIN_VARIANTS)
def coin_floats(second):
    return bool(second & 0x10) or (second & 7) in (1, 3)
def coin_variant(formation, air=False):
    want = COIN_FORMATION_NAMES[formation]
    for i, (name, second) in enumerate(coin_variants()):
        if name == want:
            if air and not coin_floats(second):
                raise ValueError("coin formation %r would drop its coins in the air" % formation)
            return i + 1
    raise ValueError("no coin formation %r in of_spawner's coins row" % formation)
