import json
import os
_HERE = os.path.dirname(os.path.abspath(__file__))
_TOOLS = os.path.dirname(_HERE)
_ROOT = os.path.dirname(_TOOLS)
PALETTES = os.path.join(_ROOT, "assets-incoming", "1006", "textures", "palettes.json")
MAP = os.path.join(_TOOLS, "soft64-map.json")
THEMES = ("ice", "desert", "lava", "wood", "sky", "garden")
_cache = {}
def palettes():
    if "pal" not in _cache:
        try:
            with open(PALETTES, encoding="utf-8") as handle:
                _cache["pal"] = json.load(handle)
        except OSError:
            _cache["pal"] = {}
    return _cache["pal"]
def keymap():
    if "map" not in _cache:
        try:
            with open(MAP, encoding="utf-8") as handle:
                _cache["map"] = json.load(handle).get("map", {})
        except OSError:
            _cache["map"] = {}
    return _cache["map"]
def to_kit(key):
    return keymap().get(key)
def _layered_rows():
    if "layered" not in _cache:
        from . import v1
        _, rows = v1.arenas_module().blocks.read_manifest()
        out = {}
        for row in rows:
            if row.get("layers"):
                stems = tuple(os.path.splitext(os.path.basename(p))[0] for p in row["layers"])
                out[stems] = row["slug"]
        _cache["layered"] = out
    return _cache["layered"]
def cap_block(cap):
    if not isinstance(cap, dict):
        return None
    return _layered_rows().get((cap.get("top"), cap.get("side"), cap.get("bottom")))
def theme_palette(theme):
    from . import values
    pal = palettes()
    row = (pal.get("themes") or {}).get(theme)
    if not row:
        return None
    raw = values.palette_from_soft64(pal, theme)
    layered_floor = str((row.get("kit_roles") or {}).get("floor", "")).endswith("+layered")
    out = {}
    for role, value in raw.items():
        if role == "floor" and layered_floor and cap_block(row.get("cap")):
            out[role] = cap_block(row.get("cap"))
        elif isinstance(value, list):
            out[role] = [to_kit(v) for v in value if to_kit(v)]
        elif to_kit(value):
            out[role] = to_kit(value)
    return out
def buildings(theme):
    row = ((palettes().get("themes") or {}).get(theme) or {}).get("buildings")
    if not row:
        return None
    out = {"wood": row.get("wood")}
    for role, value in row.items():
        if role == "wood":
            continue
        if isinstance(value, list):
            out[role] = [to_kit(v) for v in value if to_kit(v)]
        elif isinstance(value, dict):
            out[role] = {k: to_kit(v) for k, v in value.items() if to_kit(v)}
        elif to_kit(value):
            out[role] = to_kit(value)
    return out
def materials():
    from . import values
    out = {}
    for name, keys in values.materials_from_soft64(palettes()).items():
        kit_keys = tuple(to_kit(k) for k in keys if to_kit(k))
        if kit_keys:
            out[name] = kit_keys
    return out
def caps():
    from . import tops
    out = {}
    for theme, cap in tops.caps_from_soft64(palettes()).items():
        block = cap_block(cap)
        if block:
            out[theme] = block
    return out
def transition_bases():
    out = {}
    for stems, block in _layered_rows().items():
        base = to_kit(stems[2])
        if base:
            out[block] = base
    return out
_TITLES = {"stonebrick": "Stone bricks", "cutstone": "Cut stone and marble",
           "cobble": "Cobble, flagstone, paving", "castle": "Castle masonry", "brick": "Brick",
           "wood": "Wood", "roof": "Roof", "nature": "Nature", "snowice": "Snow and ice",
           "desert": "Desert", "volcanic": "Lava and volcanic", "waterside": "Water-side",
           "metal": "Metal", "crystal": "Crystal and magic", "fabric": "Fabric and decor",
           "special": "Special blocks", "transition": "Transition tops",
           "woodset": "Wood sets", "facade": "Facades", "decor": "Decor surfaces"}
def library():
    if "lib" not in _cache:
        try:
            with open(os.path.join(os.path.dirname(PALETTES), "library.json"),
                      encoding="utf-8") as handle:
                _cache["lib"] = json.load(handle)
        except OSError:
            _cache["lib"] = {}
    return _cache["lib"]
def family_of(block):
    back = {}
    for s64, key in keymap().items():
        back.setdefault(key, s64)
    s64 = back.get(block)
    if s64 is None:
        return None
    lib = library()
    entry = lib.get(s64)
    if entry is None:
        for stems, key in _layered_rows().items():
            if key == block and stems[0] in lib:
                entry = lib[stems[0]]
                break
    if entry is None:
        return None
    return _TITLES.get(entry["family"], entry["family"]), entry.get("variant", ""), s64
