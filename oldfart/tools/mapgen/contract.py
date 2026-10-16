import json
import os
from . import kit
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "contract.json")
_cache = {}
def data():
    if "data" not in _cache:
        with open(PATH, encoding="utf-8") as handle:
            _cache["data"] = json.load(handle)
    return _cache["data"]
_LIB_FAMILY = {
    "stonebrick": "masonry", "castle": "masonry", "cutstone": "masonry", "brick": "brick",
    "cobble": "paving", "roof": "roof", "metal": "metal", "crystal": "crystal",
    "fabric": "fabric", "transition": "ground", "wood": "wood", "woodset": "wood",
    "facade": "facade", "decor": "decor",
}
_KEY_FAMILY = {
    "adobe": "plaster", "adobewhite": "plaster", "adobeworn": "plaster",
    "adobebrick": "masonry", "sandstone": "masonry", "sandstonebrick": "masonry",
    "sandstonecarved": "masonry", "sandstonecut": "masonry", "sandstonelayered": "rock",
    "sandstonered": "rock", "terracotta": "paving", "terracottasmall": "paving",
    "tileglazedblue": "tile", "tileglazedgreen": "tile",
    "ash": "ground", "basaltbrick": "masonry", "basaltcolumns": "rock", "basaltrough": "rock",
    "basalttop": "ground", "brickscorched": "brick", "brickscorchedsmall": "brick",
    "lavaflow": "hazard", "magmacrust": "hazard", "obsidian": "rock",
    "obsidianbrick": "masonry", "volcanicred": "rock",
    "wdcrate": "decor", "wddeck": "wood",
    "brbasket": "paving", "brbasketyellow": "paving",
    "barnaclerock": "rock", "mosaicteal": "tile", "poolblue": "tile", "poolwhite": "tile",
    "quaystone": "paving", "seawall": "masonry", "wetalgae": "masonry", "wetstone": "masonry",
    "waterripple": "water",
    "clothblue": "fabric", "clothgreen": "fabric", "clothpurple": "fabric", "clothred": "fabric",
    "clothyellow": "fabric", "lanterncool": "glass", "lanternwarm": "glass",
    "brickenchanted": "masonry", "runestone": "masonry",
    "cuttile": "tile",
    "frostrock": "rock", "icebrick": "masonry", "snowbrick": "masonry", "icecracked": "ice",
    "icedeep": "ice", "icepacked": "ice", "icesmooth": "ice", "snowdirty": "ground",
    "snowfresh": "ground", "snowpacked": "ground", "snowridge": "ground",
    "glassclear": "glass", "stripesrw": "hazard", "stripesyb": "hazard", "checkerbw": "tile",
    "checkerrw": "tile", "glowamber": "signal", "glowblue": "signal", "glowgreen": "signal",
    "glowpink": "signal", "teamblue": "signal", "teamred": "signal", "target": "signal",
    "arrowtile": "signal",
    "plastercream": "plaster", "plasterochre": "plaster", "plasterpink": "plaster",
    "plastersage": "plaster", "plasterwhite": "plaster", "timberbrace": "timber",
    "timbercross": "timber", "timbergrid": "timber", "timberherring": "timber",
    "treadplate": "metal",
}
_FOLIAGE_WORDS = ("hedge", "leaves", "fern", "flower", "mushroom")
_ROCK_WORDS = ("rock", "cliff", "boulder")
_GROUND_KEYS = ("grass", "sand", "dirt", "gravel", "path", "moss", "mud", "snow")
def _lib_entry(block):
    if "lib" not in _cache:
        from . import soft64
        lib = soft64.library()
        back = {}
        for s64, key in soft64.keymap().items():
            back.setdefault(key, s64)
        layered = {}
        try:
            for stems, key in soft64._layered_rows().items():
                layered[key] = stems[0]
        except Exception:
            pass
        _cache["lib"] = (lib, back, layered)
    lib, back, layered = _cache["lib"]
    s64 = back.get(block)
    if s64 is not None and s64 in lib:
        return s64, lib[s64]
    top = layered.get(block)
    if top is not None and top in lib:
        return top, lib[top]
    if block in lib:
        return block, lib[block]
    return None, None
def family(slug):
    if not slug or slug == "invisible":
        return None
    memo = _cache.setdefault("family", {})
    if slug in memo:
        return memo[slug]
    key, entry = _lib_entry(slug)
    out = None
    if entry is not None:
        if key in _KEY_FAMILY:
            out = _KEY_FAMILY[key]
        elif entry.get("family") == "nature":
            v = (entry.get("variant", "") + " " + key).lower()
            if key.startswith(_GROUND_KEYS):
                out = "ground"
            elif any(w in v for w in _FOLIAGE_WORDS):
                out = "foliage"
            elif any(w in v for w in _ROCK_WORDS):
                out = "rock"
            else:
                out = "ground"
        elif entry.get("family") in ("wood", "woodset") and "door" in key:
            out = "facade"
        else:
            out = _LIB_FAMILY.get(entry.get("family"))
        if out is None:
            out = {"desert": "masonry", "volcanic": "rock", "waterside": "masonry",
                   "snowice": "ice", "special": "signal"}.get(entry.get("family"))
    if out is None:
        roles = (kit.textures().get(slug) or {}).get("roles") or ()
        out = "masonry" if "wall" in roles else "paving" if "floor" in roles else None
    memo[slug] = out
    return out
_PART_RULES = (
    (("awning", "tent", "stall", "canopy", "banner", "flag", "market"), "awning"),
    (("hedge", "maze"), "hedge"),
    (("crown", "bush", "shrub", "flowerbed", "flowers"), "foliage"),
    (("bridge",), "bridge"),
    (("stair", "stairs", "flight", "steps"), "stair"),
)
_HOUSE = ("house", "cottage", "hut", "home", "shop", "inn", "barn", "chapel")
_HOUSE_PARTS = {"wall": "building_wall", "lintel": "building_wall", "sill": "building_wall",
                "door": "building_wall", "frame": "building_wall", "chimney": "building_wall",
                "plinth": "building_wall", "parapet": "trim", "roof": "roof",
                "eave": "roof", "ridge": "roof", "porch": "building_wall",
                "facade": "facade", "trim": "trim", "floor": None, "deck": None,
                "platform": None, "woodpile": "cover", "home": "cover", "forge": "cover",
                "shop": "cover", "chapel": "cover", "barn": "cover", "tavern": "cover",
                "counter": "cover", "post": "structure", "stilt": "structure",
                "truss": "structure", "dome": "building_wall"}
_STRUCTURE = ("tower", "spire", "landmark", "watchtower", "obelisk", "temple", "lighthouse",
              "pillar", "column", "keep", "gate", "gatehouse", "arch", "arcade", "bastion",
              "monument", "statue", "shrine", "post", "pier", "colonnade", "turret",
              "fort", "castle", "windmill", "well", "lamp")
_FORT = ("wall", "rampart", "crenel", "crenels", "battlement", "edge", "rim", "curtain")
_COVER = ("fill", "crate", "cover", "shield", "block", "blocks", "bunker", "bend", "barrel",
          "barricade", "sandbag")
_PATH = ("road", "lane", "avenue", "street", "path", "plaza", "pavement", "track", "kerb")
_TRIM = ("rail", "railing", "fence", "band", "cap", "trim", "parapet", "cornice", "weir",
         "sill", "plinth", "lintel")
_WALKED = {"deck", "floor", "gallery", "platform", "landing", "plate", "terrace", "pad",
           "top", "summit", "walk"}
_PITCHED = ("ridge", "pyramid", "ramp", "prism", "roundcorner", "outer", "inner")
def _prefab_class(piece, words):
    kind = piece.get("kind")
    stall = any(w.startswith(("stall", "market", "tent", "awning", "canopy")) for w in words)
    if kind in _PITCHED:
        return "awning" if stall else "roof"
    if kind in ("box", "ice") and piece.get("h", 0) >= 300 and not stall:
        return "building_wall"
    return None
def _words(tag):
    out = []
    for part in str(tag or "").lower().replace("_", " ").replace("-", " ").split("."):
        out += [w for w in part.split() if w]
    return out
def object_class(piece):
    if piece.get("decor"):
        return None
    tag = piece.get("tag", "")
    words = _words(tag)
    if not words:
        return "stair" if piece.get("kind") == "stairs" else None
    ws = set(words)
    if words == ["breaker"]:
        return "hedge"
    if "accent" in ws:
        return None
    if piece.get("kind") in ("box", "ice") and piece.get("h", 0) <= 300 \
            and min(piece.get("w", 0), piece.get("d", 0)) >= 800 and words[0] not in _HOUSE:
        return None
    if words[0] == "prefab" and len(words) > 1:
        return _prefab_class(piece, words)
    joined = " ".join(words)
    if any(b in joined for b in ("low wall", "side wall", "bend")):
        return "cover"
    for keys, cls in _PART_RULES:
        if ws & set(keys):
            if cls == "stair" and words[0] in _HOUSE and piece.get("kind") == "box":
                return "building_wall"
            return cls
    if words[0] in _HOUSE:
        for w in words[1:]:
            if w in _HOUSE_PARTS:
                cls = _HOUSE_PARTS[w]
                if cls == "roof" and piece.get("kind") in ("box", "ice"):
                    return None
                return cls
        return "building_wall"
    if ws & _WALKED and words[0] not in _HOUSE:
        return None
    if words[0] == "tree":
        return "foliage" if len(words) > 1 and words[1] in ("crown", "bush", "drape") else None
    if "roof" in ws:
        return None if piece.get("kind") in ("box", "ice") else "roof"
    if ws & set(_STRUCTURE):
        if ws & set(("band", "cap", "trim", "cornice")):
            return "structure"
        return "structure"
    if words[0] == "dress":
        rest = set(words[1:])
        if rest & {"pillar", "pillars", "column", "keel"}:
            return "structure"
        if rest & {"rail", "rails", "parapet", "crenel", "crenels"}:
            return "trim"
        return None
    if ws & set(_COVER):
        return "cover"
    if ws & set(_PATH):
        return "path"
    if ws & set(_TRIM):
        return "trim"
    if ws & set(_FORT):
        return "fort_wall"
    if piece.get("kind") == "stairs":
        return "stair"
    return None
def themes():
    from . import soft64
    names = list((soft64.palettes().get("themes") or {}).keys())
    for t in kit.THEMES:
        if t not in names:
            names.append(t)
    return names
def classes():
    return list(data()["classes"].keys())
def set_allowed(theme, cls, families, where=None):
    d = data()
    if cls not in d["classes"]:
        raise ValueError("no object class %r" % cls)
    known = set(d["families"])
    fams = [f for f in families if f in known]
    notes = ["%s is not a material family" % f for f in families if f not in known]
    if cls in d["built"]:
        dropped = [f for f in fams if f in d["refused_on_built"]]
        fams = [f for f in fams if f not in d["refused_on_built"]]
        notes += ["%s never goes on a built %s (kept out)" % (f, cls.replace("_", " "))
                  for f in dropped]
    rules = d.setdefault("themes", {}).setdefault(theme, {})
    rules[cls] = {"only": sorted(set(fams), key=list(d["families"]).index)}
    where = where or PATH
    with open(where, "w", encoding="utf-8") as fh:
        json.dump(d, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    _cache.pop("data", None)
    return rules[cls]["only"], notes
def allowed(theme, cls):
    d = data()
    base = list(d["base"].get(cls) or [])
    rule = ((d.get("themes") or {}).get(theme) or {}).get(cls) or {}
    if "only" in rule:
        base = list(rule["only"])
    for f in rule.get("add") or ():
        if f not in base:
            base.append(f)
    for role in _PALETTE_ROLES.get(cls, ()):
        f = family(_palette_pick(theme, role))
        if f and f not in base and not refused(cls, f) and f not in ("foliage", "fabric",
                                                                      "hazard", "signal"):
            base.append(f)
    if cls in d["built"]:
        base = [f for f in base if f not in d["refused_on_built"]]
    return base
_PALETTE_ROLES = {"building_wall": ("wall", "wall_alt"), "fort_wall": ("wall", "wall_base"),
                  "structure": ("wall", "wall_base", "wall_cap", "trim"), "trim": ("trim",),
                  "cover": ("cover",), "roof": ("roof", "roof_alt"), "path": ("path",),
                  "bridge": ("bridge",), "stair": ("path", "ramp")}
def _palette_pick(theme, role):
    memo = _cache.setdefault("pick", {})
    if (theme, role) not in memo:
        from . import soft64
        row = _soft64_row(theme)
        v = row.get(role) or (row.get("kit_roles") or {}).get(role)
        out = soft64.to_kit(v) if isinstance(v, str) else None
        if out is None and theme in kit.THEMES_BEFORE_SOFT64:
            out = kit.THEMES_BEFORE_SOFT64[theme].get(role)
        memo[(theme, role)] = out
    return memo[(theme, role)]
def refused(cls, fam):
    d = data()
    if cls in d["built"] and fam in d["refused_on_built"]:
        return True
    if cls == "roof" and fam in ("paving", "ground", "foliage", "fabric", "hazard"):
        return True
    return False
_CLASS_ROLES = {
    "building_wall": ("wall",), "roof": ("roof",), "trim": ("trim", "wall"),
    "structure": ("wall", "trim"), "fort_wall": ("wall",), "bridge": ("floor", "wall"),
    "hedge": ("nature", "wall"), "foliage": ("nature", "accent"), "cover": ("wall", "accent"),
    "path": ("path", "floor"), "stair": ("floor", "path", "wall"), "awning": ("accent", "roof"),
}
def members(theme, cls, kind=None):
    key = (theme, cls, kind)
    memo = _cache.setdefault("members", {})
    if key in memo:
        return memo[key]
    fams = allowed(theme, cls)
    have = kit.textures()
    roles = _CLASS_ROLES.get(cls, ())
    own, rest = [], []
    for slug in have:
        if have[slug].get("layered") or slug in kit.FORBIDDEN or slug == "invisible":
            continue
        f = family(slug)
        if f not in fams:
            continue
        if kind and not kit.comes_in(slug, kind):
            continue
        _, entry = _lib_entry(slug)
        lroles = set((entry or {}).get("roles") or have[slug].get("roles") or ())
        if roles and not (lroles & set(roles)) and f not in ("plaster", "timber"):
            continue
        (own if theme in ((entry or {}).get("themes") or ()) else rest).append(slug)
    order = {f: i for i, f in enumerate(fams)}
    def rank(s):
        plant = 0 if ("hedge" in s or "leaves" in s) else 1
        return (order.get(family(s), 99), plant, s)
    own.sort(key=rank)
    rest.sort(key=rank)
    memo[key] = own + rest
    return memo[key]
def ok(theme, cls, slug):
    return cls is None or slug in (None, "invisible") or family(slug) in allowed(theme, cls)
def material(theme, cls, pal=None, prefer=(), index=0, kind=None):
    for p in prefer or ():
        tex = pal.get(p) if pal is not None and p in pal else p
        if isinstance(tex, str) and tex in kit.textures() and not kit.layered(tex) \
                and family(tex) in allowed(theme, cls) and (not kind or kit.comes_in(tex, kind)):
            return tex
    ms = members(theme, cls, kind) or members(theme, cls)
    if not ms:
        return None
    return ms[index % len(ms)]
def variants(theme, cls, pal=None, prefer=(), n=4, kind=None):
    first = material(theme, cls, pal, prefer, 0, kind)
    out = [first] if first else []
    ms = members(theme, cls, kind)
    fam = family(first) if first else None
    same = [m for m in ms if family(m) == fam and m not in out]
    other = [m for m in ms if family(m) != fam and m not in out]
    for m in same + other:
        if len(out) >= n:
            break
        out.append(m)
    while out and len(out) < n:
        out.append(out[len(out) % max(1, len(out))])
    return out
GREEN_THEMES = ("garden", "forest", "village")
BUILT_ROLES = ("wall", "ramp", "deck", "bridge", "keel", "cover", "trim", "wall_base",
               "wall_cap", "roof", "building", "stair", "path")
ROLE_CLASS = {"wall": "fort_wall", "building": "building_wall", "roof": "roof", "trim": "trim",
              "cover": "cover", "path": "path", "stair": "stair", "awning": "awning",
              "foliage": "foliage", "hedge": "hedge", "bridge": "bridge",
              "wall_base": "structure", "wall_cap": "structure", "keel": "structure"}
def _soft64_row(theme):
    from . import soft64
    return ((soft64.palettes().get("themes") or {}).get(theme) or {})
def split_roles(theme, pal):
    from . import soft64
    notes = []
    row = _soft64_row(theme)
    def s64(name):
        v = row.get(name)
        return soft64.to_kit(v) if isinstance(v, str) else None
    def fam(t):
        return family(t) if isinstance(t, str) else None
    plants = [t for t in [pal.get("foliage"), pal.get("cover"), pal.get("trim")]
              + list(pal.get("accents") or []) + [s64("cover"), s64("trim")]
              if isinstance(t, str) and fam(t) == "foliage" and not kit.layered(t)]
    hedge_like = [t for t in plants if "hedge" in t]
    if not pal.get("foliage"):
        if hedge_like or plants:
            pal["foliage"] = (hedge_like or plants)[0]
        elif theme in GREEN_THEMES:
            pal["foliage"] = material(theme, "foliage", None, ("hedge", "leaves")) or None
    if not pal.get("foliage"):
        pal.pop("foliage", None)
    for role in BUILT_ROLES:
        tex = pal.get(role)
        if not isinstance(tex, str):
            continue
        cls = ROLE_CLASS.get(role)
        if fam(tex) in ("foliage", "fabric") or (cls and cls in data()["built"]
                                                 and refused(cls, fam(tex))):
            alt = {"cover": ("wall_base", "wall_cap", "wall"),
                   "trim": ("wall_cap", "wall_base", "wall")}.get(role, ())
            new = material(theme, cls or "structure", pal,
                           tuple(r for r in alt if r != role) + (s64(role) or "",))
            if new and new != tex:
                pal[role] = new
    if not pal.get("building"):
        pal["building"] = material(theme, "building_wall", pal,
                                   ("wall", s64("wall") or "", s64("wall_alt") or ""))
    if not pal.get("roof"):
        pal["roof"] = material(theme, "roof", pal, (s64("roof") or "", s64("roof_alt") or ""),
                               kind="ridge")
    if not pal.get("path"):
        pal["path"] = material(theme, "path", pal, (s64("path") or "", "ramp", "deck"))
    if not pal.get("stair"):
        pal["stair"] = material(theme, "stair", pal, ("ramp", "path", "deck"), kind="stairs")
    if not pal.get("awning"):
        fabric = [t for t in list(pal.get("accents") or []) if fam(t) == "fabric"]
        pal["awning"] = material(theme, "awning", pal, tuple(fabric) + (s64("roof_alt") or "",))
    pal["hedge"] = pal.get("hedge") or pal.get("foliage") or pal.get("cover") or material(
        theme, "hedge", pal, ("wall",))
    acc = [t for t in pal.get("accents") or [] if fam(t) not in ("foliage", "fabric", "ground")
           and ok(theme, "structure", t)]
    for role in ("wall_cap", "wall_base", "wall", "keel", "bridge"):
        t = pal.get(role)
        if len(acc) < 4 and isinstance(t, str) and t not in acc and not kit.layered(t) \
                and ok(theme, "structure", t):
            acc.append(t)
    if len(acc) < 2:
        acc += [t for t in variants(theme, "structure", pal, ("wall_cap", "trim", "wall"), 4)
                if t not in acc]
    pal["accents_built"] = acc[:4]
    for role in ("building", "roof", "path", "stair", "awning", "hedge"):
        if pal.get(role) is None:
            pal.pop(role, None)
    return notes
def issues(arena, theme=None):
    theme = theme or arena_theme(arena)
    out = []
    from . import v1
    m = v1.arenas_module()
    for p in arena.get("pieces") or []:
        cls = object_class(p)
        if cls is None:
            continue
        for tex in kit.textures_of(p):
            f = family(tex)
            if f is None:
                continue
            hard = refused(cls, f)
            if hard or f not in allowed(theme, cls):
                out.append({"piece": p, "class": cls, "family": f, "refused": hard,
                            "text": "contract: %s is a %s in %s (%s), which %s may not wear%s"
                            % (m.piece_name(p), cls.replace("_", " "), tex, f, theme,
                               " - foliage and fabric never on a built structure"
                               if hard and f in ("foliage", "fabric") else "")})
                break
    return out
def faults(arena, theme=None):
    return [i["text"] for i in issues(arena, theme) if i["refused"]]
def repair(pieces, theme, pal=None):
    n = 0
    for p in pieces:
        cls = object_class(p)
        if cls is None:
            continue
        tex = kit.tex_key(p)
        f = family(tex)
        if f is None or not refused(cls, f):
            continue
        new = material(theme, cls, pal, ("building" if cls == "building_wall" else
                                         ROLE_CLASS.get(cls, cls),), kind=p.get("kind"))
        new = new or material(theme, cls, pal)
        if new:
            p["tex"] = new
            p.pop("model", None)
            n += 1
    return n
PATH_FAMILIES = ("race", "course", "hide", "hunt", "chase", "explore")
def theme_for(brief):
    t = brief.get("theme")
    if t in kit.THEMES:
        return t
    if brief.get("family") in PATH_FAMILIES:
        return "sky"
    return "castle"
def arena_theme(arena):
    gen = arena.get("generator") or {}
    t = arena.get("theme") or (arena.get("report") or {}).get("theme") or gen.get("theme")
    return t if t and t != "auto" else "garden"
def boards(out_dir, only=None, cell=40, per_row=14):
    from PIL import Image, ImageDraw
    from . import soft64
    os.makedirs(out_dir, exist_ok=True)
    root = os.path.dirname(soft64.PALETTES)
    written = []
    lab = 190
    pics = {}
    def pic(slug):
        if slug in pics:
            return pics[slug]
        key, entry = _lib_entry(slug)
        im = None
        if entry and entry.get("file"):
            try:
                im = Image.open(os.path.join(root, entry["file"])).convert("RGB").resize(
                    (cell, cell), Image.NEAREST)
            except OSError:
                im = None
        pics[slug] = im
        return im
    for theme in themes():
        if only and theme not in only:
            continue
        pal, _ = kit.palette(theme) if theme in kit.THEMES else _soft64_pal(theme)
        rows = []
        for cls in classes():
            ms = members(theme, cls)
            pick = material(theme, cls, pal, (_role_of(cls),))
            rows.append((cls, allowed(theme, cls), _sampled(ms, pick, per_row), len(ms), pick))
        h = 34 + len(rows) * (cell + 22)
        w = lab + per_row * (cell + 4) + 60
        img = Image.new("RGB", (w, h), (32, 32, 36))
        d = ImageDraw.Draw(img)
        d.text((8, 8), "theme %s - the material contract (a draft): each class and "
                       "the tiles it may wear" % theme, fill=(240, 240, 240))
        y = 34
        for cls, fams, ms, total, pick in rows:
            d.text((8, y + 2), cls.replace("_", " "), fill=(255, 220, 120))
            d.text((8, y + 16), ", ".join(fams)[:30], fill=(170, 170, 170))
            if len(", ".join(fams)) > 30:
                d.text((8, y + 28), ", ".join(fams)[30:60], fill=(170, 170, 170))
            x = lab
            for s in ms:
                im = pic(s)
                if im is not None:
                    img.paste(im, (x, y))
                else:
                    d.rectangle((x, y, x + cell, y + cell), outline=(120, 120, 120))
                if s == pick:
                    d.rectangle((x - 2, y - 2, x + cell + 1, y + cell + 1), outline=(255, 255, 0),
                                width=2)
                d.text((x, y + cell + 2), s[:7], fill=(200, 200, 200))
                x += cell + 4
            if total > len(ms):
                d.text((x + 2, y + cell // 2 - 5), "+%d" % (total - len(ms)), fill=(200, 200, 200))
            y += cell + 22
        path = os.path.join(out_dir, "contract-%s.webp" % theme)
        img.save(path, quality=72)
        written.append(path)
    return written
def _sampled(ms, pick, n):
    by = {}
    for m in ms:
        by.setdefault(family(m), []).append(m)
    out = [pick] if pick else []
    k = 0
    while len(out) < n and any(k < len(v) for v in by.values()):
        for f in list(by):
            if k < len(by[f]) and by[f][k] not in out and len(out) < n:
                out.append(by[f][k])
        k += 1
    return out
def _role_of(cls):
    return {"building_wall": "building", "fort_wall": "wall", "structure": "wall_cap"}.get(cls, cls)
def _soft64_pal(theme):
    from . import soft64
    pal = soft64.theme_palette(theme) or {}
    pal.setdefault("accents", [])
    pal = {k: v for k, v in pal.items() if v}
    notes = split_roles(theme, pal)
    return pal, notes
def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(prog="python3 tools/mapgen contract")
    ap.add_argument("--boards", default=None, help="draw one picture board per theme here")
    ap.add_argument("--theme", action="append", help="only these themes")
    a = ap.parse_args(argv)
    for theme in themes():
        if a.theme and theme not in a.theme:
            continue
        print(theme)
        for cls in classes():
            print("  %-14s %s" % (cls, ", ".join(allowed(theme, cls))))
    if a.boards:
        for path in boards(a.boards, only=a.theme):
            print("wrote", path)
    return 0
