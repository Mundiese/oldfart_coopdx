import hashlib
import importlib.util
import json
import os
import re
import shutil
import struct
import time
from . import bake, basins, decor, modpackthings, mood, movers, skies, v1
from . import luastrip, sharedcode, worldedge
from .render import gamefog
from .brief import KEY_RE
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
REPO = os.path.dirname(TOOLS)
RUNTIME = os.path.join(HERE, "standalone", "oldfart_maps.lua.txt")
RUNTIME_NAME = "oldfart_maps.lua"
README_NAME = "README-oldfart-maps.txt"
FORMAT = 2
STAR_BACKDROP = "actors/of_star_backdrop_geo.bin"
UI_SELECT = "sound/of_ui_select.ogg"
LOGIC_KINDS = {"lgtarget": "target", "lgbutton": "button", "lgzone": "zone"}
LOGS = {"log": ("E_MODEL_LLL_ROLLING_LOG", "lll_seg7_collision_pitoune"),
        "logwide": ("E_MODEL_TTM_ROLLING_LOG", "ttm_seg7_collision_pitoune_2")}
MOVER_HEIGHT = {"blk": 200, "slab": 100, "uslab": 100, "plate": 20, "uplate": 20}
SHADER_FLAGS = {"hue": ("SHADER_FLAG_HUE", 0.0), "saturation": ("SHADER_FLAG_SATURATION", 1.0),
                "brightness": ("SHADER_FLAG_BRIGHTNESS", 1.0),
                "contrast": ("SHADER_FLAG_CONTRAST", 1.0),
                "exposure": ("SHADER_FLAG_EXPOSURE", 1.0),
                "posterization": ("SHADER_FLAG_POSTERIZATION", 8.0),
                "scanlines": ("SHADER_FLAG_SCANLINES", 1.0),
                "dithering": ("SHADER_FLAG_DITHERING", 0.0)}
FOG_GREY = (150, 152, 160)
MOOD_ROW = {"weather": "snow", "hour": "sun", "darkness": "dark", "fog": "fog",
            "light": "shading", "colour": "tint"}
class PackError(ValueError):
    pass
_tools = {}
def tool(filename):
    if filename not in _tools:
        spec = importlib.util.spec_from_file_location(
            "modpack_" + re.sub(r"\W", "_", filename), os.path.join(TOOLS, filename))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _tools[filename] = module
    return _tools[filename]
def runtime_text():
    with open(RUNTIME, encoding="utf-8") as handle:
        text = sharedcode.splice(handle.read())
    return text.replace('local BUILD = "dev"', 'local BUILD = "%s"' % runtime_hash(text), 1)
def runtime_hash(text=None):
    import hashlib
    if text is None:
        with open(RUNTIME, encoding="utf-8") as handle:
            text = sharedcode.splice(handle.read())
    body = re.sub(r'^local (VERSION = \d+|BUILD = "[^"]*")$', "", text, flags=re.M)
    return hashlib.sha1(body.encode("utf-8")).hexdigest()[:12]
STAMP = os.path.join(os.path.dirname(RUNTIME), "runtime_stamp.json")
def stamp_now():
    return {"version": runtime_version(), "hash": runtime_hash()}
def write_stamp():
    import json
    with open(STAMP, "w", encoding="utf-8") as handle:
        json.dump(stamp_now(), handle, indent=1)
        handle.write("\n")
def runtime_version(text=None):
    m = re.search(r"^local VERSION = (\d+)", text if text is not None else runtime_text(), re.M)
    return int(m.group(1)) if m else 0
def key_for(name):
    key = "".join(ch for ch in (name or "").lower() if ch.isalnum())
    if key.startswith("the") and len(key) > 6:
        key = key[3:]
    if key and not key[0].isalpha():
        key = "m" + key
    return key[:24]
def script_of(key):
    return "ofmap_" + key
def level_name(key):
    return "level_%s_entry" % script_of(key)
def prepared_arena(layout, key, name):
    from .families.race import race_world
    arena = json.loads(json.dumps(layout))
    arena["key"], arena["name"] = key, name
    arena["script"] = script_of(key)
    arena["_generated"] = True
    arena.setdefault("level", "empty2")
    for p in arena.get("pieces") or []:
        p.pop("model", None)
    if isinstance(arena.get("look"), dict):
        arena["look"] = bake.fold_hour(bake.export_look(arena["look"]))
        from . import autolight
        dark_sky = autolight.night_sky(arena["look"].get("mood"),
                                       arena["look"].get("sky") or "BACKGROUND_OCEAN_SKY")
        if dark_sky:
            arena["look"] = dict(arena["look"], sky=dark_sky)
        tint = autolight.sky_tint(arena["look"].get("mood"),
                                  arena["look"].get("sky") or "BACKGROUND_OCEAN_SKY")
        if tint:
            arena["look"] = dict(arena["look"], **{autolight.SKY_TINT_FIELD: tint})
    start = race_world(arena)
    if start is not None:
        arena["world"] = start
    elif not arena.get("world"):
        from .worldspawn import ensure
        ensure(arena)
    return arena
def level_body(arena, script, bake_key):
    mvl = tool("make-venue-levels.py")
    vb = mvl.venuebake()
    base = arena.get("level") or "empty2"
    ground = arena.get("ground") if base == "empty" else None
    level = vb.compile_level(dict(arena, _generated=True), key=bake_key, script=script)
    body = mvl.ground_body(mvl.uv_body(mvl.soft64_body(mvl.base_body(base), base), base), ground)
    body = mvl.water_body(body, mvl.water_boxes(arena))
    body = mvl.entry_body(body, mvl.world_of(arena))
    new = mvl.rename_body(body, base, script)
    if mvl.rename_body(new, script, base) != body:
        raise PackError("the level does not rename cleanly to %s" % script)
    return vb.bake_body(new, level, script), level
def level_file(arena, key):
    body, level = level_body(arena, script_of(key), script_of(key))
    return tool("make-venue-levels.py").write_lvl(body), level
_kit = {}
def _kit_parts():
    if not _kit:
        m = tool("make-arenas.py")
        template_path, _ = m.blocks.read_manifest()
        with open(os.path.join(REPO, template_path), "rb") as handle:
            raw = m.blocks.unpack_bin(handle.read(), template_path)
        _kit["nodes"] = m.slopes.read_nodes(raw, template_path)
        _kit["textures"], _kit["layered"] = m.kit_textures()
    return _kit
def collision_bin(piece, name):
    m = tool("make-arenas.py")
    verts, tris = [], []
    for pts, _ in m.solid(piece["kind"], floor=True):
        real = [tuple(int(round(c)) for c in m.scaled(p, piece)) for p in pts]
        for tri in m.slopes.triangles(real):
            idx = []
            for p in m.slopes.sort_first(tri):
                if p not in verts:
                    verts.append(p)
                idx.append(verts.index(p))
            tris.append(tuple(idx))
    words = [m.slopes.COL_INIT, len(verts)]
    for p in verts:
        words += list(p)
    words += [m.SURFACES[piece["kind"]], len(tris)]
    for t in tris:
        words += list(t)
    words += [m.slopes.COL_TRI_STOP, m.slopes.COL_END]
    raw = name.encode("ascii")
    return (bytes([m.slopes.DATA_TYPE_COLLISION]) + bytes([len(raw)]) + raw
            + struct.pack("<I", len(words)) + struct.pack("<%dh" % len(words), *words))
def mover_block(key):
    shape = movers.shape_of(key)
    if shape in LOGS:
        return None
    rest = str(key)[2:]
    tex = rest[len(shape):] if rest.startswith(shape) else rest
    height = MOVER_HEIGHT.get(shape, 200)
    return shape, tex, {"kind": "box", "tex": tex, "x": 0, "y": 0, "z": 0, "w": 200,
                        "h": height, "d": 200, "yaw": 0}
def mover_files(key):
    _shape, tex, piece = mover_block(key)
    kit = _kit_parts()
    if tex not in kit["textures"]:
        raise PackError("a moving platform wears the block %r, which the kit does not have" % tex)
    m = tool("make-arenas.py")
    probe = m.build_geo(kit["nodes"], "ofmap_mv_probe_", kit["textures"][tex], piece,
                        kit["layered"].get(tex))
    stem = "ofmap_mv_" + hashlib.sha1(probe + repr(sorted(piece.items())).encode()).hexdigest()[:10]
    geo = m.build_geo(kit["nodes"], stem + "_", kit["textures"][tex], piece,
                      kit["layered"].get(tex))
    col = collision_bin(piece, stem + "_col")
    return stem + "_geo", stem + "_col", {"actors/%s_geo.bin" % stem: geo,
                                          "actors/%s_col.col" % stem: col}
_stops = {}
def modifier_stops(row):
    if row in _stops:
        return _stops[row]
    with open(os.path.join(REPO, "of_modifiers.lua"), encoding="utf-8") as handle:
        text = handle.read()
    at = text.find('key = "%s", id = ' % row)
    if at < 0:
        raise PackError("of_modifiers.lua has no Visuals row %r" % row)
    start = text.find("levels = {", at)
    depth, i = 0, start + len("levels = ")
    while True:
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                break
        elif ch == "-" and text[i:i + 2] == "--":
            i = text.find("\n", i)
            continue
        i += 1
    body = text[start:i]
    out = {}
    for line in body.split("\n"):
        line = line.split("--")[0]
        m = re.search(r'\{\s*name = "([^"]+)"(.*)\}', line)
        if not m:
            continue
        rest, stop = m.group(2), {}
        for k, a, b, c in re.findall(r"(\w+) = \{ (-?[\d.]+), (-?[\d.]+), (-?[\d.]+) \}", rest):
            stop[k] = [float(a) if "." in a else int(a), float(b) if "." in b else int(b),
                       float(c) if "." in c else int(c)]
        for k, v in re.findall(r"(\w+) = (-?[\d.]+)(?=[,\s}]|$)", rest):
            if k not in stop:
                stop[k] = float(v) if "." in v else int(v)
        for k, v in re.findall(r'(\w+) = "([^"]*)"', rest):
            stop[k] = v
        for k, v in re.findall(r"(\w+) = ([A-Z][A-Z0-9_]+)", rest):
            stop[k] = v
        for k, v in re.findall(r"(\w+) = (true|false)\b", rest):
            stop[k] = v == "true"
        out[m.group(1)] = stop
    _stops[row] = out
    return out
def stop_of(row, name):
    return modifier_stops(row).get(name) if isinstance(name, str) else None
MUSIC_ROOTS = []
def music_roots():
    out = []
    for r in list(MUSIC_ROOTS) + [REPO]:
        if r and os.path.isfile(os.path.join(r, "of_music.lua")) and \
                os.path.realpath(r) not in [os.path.realpath(x) for x in out]:
            out.append(r)
    return out
MENU_VOLUME = 75
def _rows_of(root):
    with open(os.path.join(root, "of_music.lua"), encoding="utf-8") as handle:
        text = handle.read()
    text = tool("music.py").luaregion().restore(text, "of_music.lua")
    begin = text.find("-- music.py: rows begin")
    end = text.find("-- music.py: rows end", begin)
    out = {}
    if begin < 0 or end < 0:
        return out
    for m in re.finditer(r'\{\s*file\s*=\s*"([^"]+)"([^{}]*)\}', text[begin:end]):
        body = m.group(2)
        bank = re.search(r"bank\s*=\s*(\d+)", body)
        ext = re.search(r'ext\s*=\s*"(\w+)"', body)
        vol = re.search(r"volume\s*=\s*(\d+)", body)
        name = re.search(r'name\s*=\s*"((?:[^"\\]|\\.)*)"', body)
        lf = re.search(r"loopFrom\s*=\s*(\d+)", body)
        lt = re.search(r"loopTo\s*=\s*(\d+)", body)
        row = {"bank": int(bank.group(1)) if bank else None,
               "ext": ext.group(1) if ext else "m64",
               "volume": int(vol.group(1)) if vol else MENU_VOLUME,
               "name": name.group(1) if name else m.group(1), "root": root}
        if lf:
            row["loopFrom"] = int(lf.group(1))
            row["loopTo"] = int(lt.group(1)) if lt else 0
        out[m.group(1)] = row
    return out
def music_rows():
    out = {}
    for root in music_roots():
        for k, v in _rows_of(root).items():
            out.setdefault(k, v)
    return out
def music_file(key, row):
    for root in [row.get("root")] + music_roots():
        if root:
            src = os.path.join(root, "sound", "%s.%s" % (key, row["ext"]))
            if os.path.isfile(src):
                return src
    return os.path.join(REPO, "sound", "%s.%s" % (key, row["ext"]))
def resolve_look(arena, notes):
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    out, sounds = {}, {}
    if look.get("sky") in dict(skies.SKIES):
        out["sky"] = look["sky"]
    from . import autolight
    dark_sky = autolight.night_sky(look.get("mood"), out.get("sky") or "BACKGROUND_OCEAN_SKY")
    if dark_sky:
        out["sky"] = dark_sky
    tint = autolight.sky_tint(look.get("mood"), out.get("sky") or "BACKGROUND_OCEAN_SKY")
    if tint:
        out[autolight.SKY_TINT_FIELD] = tint
    music = look.get("music")
    if isinstance(music, str) and music.startswith("SEQ_"):
        out["music"] = music
    elif isinstance(music, str) and music:
        row = music_rows().get(music)
        if row is None:
            notes.append("the music %r is not in the mod's music list - the level's own plays"
                         % music)
        else:
            src = music_file(music, row)
            if not os.path.isfile(src):
                notes.append("the music file sound/%s.%s is missing - the level's own plays"
                             % (music, row["ext"]))
            else:
                sounds["sound/%s.%s" % (music, row["ext"])] = src
                out["musicFile"] = music
                if row["ext"] == "m64":
                    out["musicBank"], out["musicVolume"] = row["bank"] or 37, row["volume"]
                else:
                    out["musicStream"] = row["ext"]
                    out["musicVolume"] = row["volume"]
                    if row.get("loopFrom") is not None:
                        out["musicLoop"] = [row["loopFrom"], row.get("loopTo") or 0]
    tracks = []
    rows = None
    for key in look.get("playlist") or []:
        if not isinstance(key, str) or not key or key == out.get("musicFile") or \
                any(t["file"] == key for t in tracks):
            continue
        rows = rows if rows is not None else music_rows()
        row = rows.get(key)
        if row is None:
            notes.append("the music %r to take along is not in the mod's music list - left out"
                         % key)
            continue
        src = music_file(key, row)
        if not os.path.isfile(src):
            notes.append("the music file sound/%s.%s is missing - left out" % (key, row["ext"]))
            continue
        sounds["sound/%s.%s" % (key, row["ext"])] = src
        t = {"file": key, "name": row.get("name") or key}
        if row["ext"] == "m64":
            t["bank"], t["volume"] = row["bank"] or 37, row["volume"]
        else:
            t["stream"], t["volume"] = row["ext"], row["volume"]
            if row.get("loopFrom") is not None:
                t["loop"] = [row["loopFrom"], row.get("loopTo") or 0]
        tracks.append(t)
    if tracks:
        out["tracks"] = tracks
    wants = {}
    for pair in look.get("visuals") or []:
        if isinstance(pair, (list, tuple)) and len(pair) == 2 and pair[1] not in mood.OBJECT_RAINS:
            wants[pair[0]] = pair[1]
    m = mood.clean(look.get("mood"))
    for field, row in MOOD_ROW.items():
        if field in m:
            wants[row] = m[field]
    light = look.get("light")
    if isinstance(light, dict):
        light = light.get("dir")
    if isinstance(light, (list, tuple)) and len(light) == 3:
        out["dir"] = [round(float(c), 4) for c in light]
    hour = stop_of("sun", wants.get("sun"))
    if hour and "dir" in hour:
        out["dir"] = [float(c) for c in hour["dir"]]
    dark = stop_of("dark", wants.get("dark"))
    if dark is None and isinstance(look.get("dark"), int) and look["dark"] > 0:
        names = list(modifier_stops("dark"))
        if look["dark"] <= len(names):
            dark = modifier_stops("dark")[names[look["dark"] - 1]]
    if dark and "light" in dark:
        out["dark"] = list(dark["light"])
    elif dark and "grey" in dark:
        out["dark"] = [dark["grey"]] * 3
    fog = stop_of("fog", wants.get("fog"))
    if fog and "fogx" in fog:
        hue = fog.get("hue")
        if hue is None and fog.get("fromSky"):
            hue = gamefog.sky_air(out.get("sky"))
        out["fog"] = [round(fog["fogx"] / 100.0, 3)] + list(hue or FOG_GREY) + \
            list(gamefog.stop_words(fog, **gamefog.ENGINE_PLANES))
    shade = stop_of("shading", wants.get("shading"))
    if shade and "dir" in shade and "amb" in shade:
        out["shade"] = {"dir": list(shade["dir"]), "amb": list(shade["amb"])}
    tint = stop_of("tint", wants.get("tint"))
    if tint and "tint" in tint:
        out["tint"] = list(tint["tint"])
    weather = stop_of("snow", wants.get("snow"))
    if weather and wants.get("snow") not in mood.OBJECT_RAINS:
        if "envfx" in weather:
            out["envfx"] = weather["envfx"]
        if "rain" in weather:
            out["rain"] = weather["rain"]
    if m.get("vision") or m.get("dials"):
        dials = mood.look_dials(m)
        shader = []
        for name in mood.DIAL_NAMES + ["dithering"]:
            flag, rest = SHADER_FLAGS[name]
            if abs(float(dials.get(name, rest)) - rest) > 1e-6:
                shader.append([flag, round(float(dials[name]), 3), rest])
        if shader:
            out["shader"] = shader
    if bake.clean_sun(look.get("sun")) is not None:
        out["sun"] = [round(float(c), 4) for c in bake.sun_palette(look)["sun"]]
    for row, name in sorted(wants.items()):
        if not isinstance(name, str) or name in ("", "off", "none"):
            continue
        needs = FIXED_FIELDS.get(row)
        stop = stop_of(row, name) if needs is not None else None
        if needs is None or stop is None or not any(k in stop for k in needs):
            moving = stop is not None and any(k in stop for k in MOVING_FIELDS)
            notes.append("the Visuals stop %r (%s) %s - an exported map wears fixed stops only, "
                         "so it is left out" % (name, row, "changes while you play" if moving
                                                else "is the lobby's own"))
    return out, sounds
MOVING_FIELDS = ("hours", "closes", "still", "team", "drains", "alarm", "shoulder")
FIXED_FIELDS = {"sun": ("dir",), "dark": ("light", "grey"), "fog": ("fogx",),
                "shading": ("dir", "amb"), "tint": ("tint",), "snow": ("envfx", "rain")}
def lua_value(v, indent=""):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return ("%d" % v) if v == int(v) and abs(v) < 1e15 else repr(round(v, 4))
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if isinstance(v, (list, tuple)):
        inner = [lua_value(x, indent + "    ") for x in v]
        if all(not isinstance(x, (list, tuple, dict)) for x in v):
            return "{ " + ", ".join(inner) + " }" if inner else "{}"
        return "{\n" + "".join(indent + "    " + s + ",\n" for s in inner) + indent + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        parts = []
        for k in sorted(v):
            parts.append(indent + "    %s = %s,\n" % (k, lua_value(v[k], indent + "    ")))
        return "{\n" + "".join(parts) + indent + "}"
    raise PackError("no Lua for %r" % (v,))
def _num(v):
    v = float(v)
    return int(v) if v == int(v) else round(v, 2)
DARK_SHADING = "moonlight"
def rig_hour(arena, lights):
    if not lights.get("night"):
        return None
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    words = []
    m = look.get("mood")
    if isinstance(m, dict):
        words += [str(v) for v in m.values()]
    elif m:
        words.append(str(m))
    words.append(str(look.get("darkness") or ""))
    text = " ".join(words).lower()
    if any(w in text for w in ("dusk", "sunset", "evening", "twilight")):
        return "dusk"
    return "night"
def fog_head(name):
    import re
    return re.match(r"^of_.+_(static|water)_dl$", name or "") is not None
def sky_tints():
    import re
    with open(os.path.join(REPO, "of_venues.lua"), encoding="utf-8") as handle:
        text = handle.read()
    at = text.index("venues.SKY_TINTS = {")
    body = text[at:text.index("\n}", at)]
    return {k: (int(r), int(g), int(b))
            for k, r, g, b in re.findall(r"(\w+) = \{ (\d+), (\d+), (\d+) \}", body)}
def sky_tint_worn(look, hour):
    if not isinstance(look, dict):
        return None
    t = look.get("skyTint")
    if isinstance(t, (list, tuple)) and t and isinstance(t[0], (int, float)):
        return [t[0], t[1] if len(t) > 1 else t[0], t[2] if len(t) > 2 else t[0]]
    words = [str(hour or ""), str(look.get("darkness") or "")]
    m = look.get("mood")
    if isinstance(m, dict):
        words += [str(v) for v in m.values()]
    elif m is not None:
        words.append(str(m))
    text = " ".join(words).lower()
    tints = sky_tints()
    if "purple" in text:
        pick = tints["purple"]
    elif any(w in text for w in ("dusk", "sunset", "evening", "twilight")):
        pick = tints["dusk"]
    elif any(w in text for w in ("night", "pitch", "cold blue")):
        pick = tints["night"]
    else:
        return None
    return list(pick)
def worn_sky_tint(arena):
    look, _ = resolve_look(arena, [])
    vb = tool("make-venue-levels.py").venuebake()
    return sky_tint_worn(look, rig_hour(arena, {"night": vb.evening(vb.prepared(arena))}))
def fog_fields(level, vb=None):
    vb = vb or tool("make-venue-levels.py").venuebake()
    version = int(getattr(vb, "LIGHTFOG_CONTRACT", 1) or 1)
    if version < 2:
        return {}
    names = [n[1] for n in getattr(level, "nodes", None) or []
             if isinstance(n, (list, tuple)) and len(n) >= 2 and isinstance(n[1], str)]
    heads = [n for n in names if fog_head(n)]
    boards = [n for n in names if "_bake_bb_" in n]
    return {"lightfog": version, "fogHeads": heads, "fogBillboards": boards}
def map_table(arena, key, name, blurb, made, notes):
    files = {}
    data = {"format": FORMAT, "runtime": runtime_version(), "made": int(made),
            "key": key, "name": name, "blurb": blurb or "", "script": level_name(key)}
    lights = tool("make-venue-levels.py").venuebake().light_fields(arena)
    data["lightfog"] = lights.get("lightfog")
    if lights["lights"]:
        data["lights"] = [[_num(c) for c in row] for row in lights["lights"]]
    if lights["night"]:
        data["night"] = True
    if lights["rooms"]:
        data["rooms"] = list(lights["rooms"])
    if lights["shift"]:
        data["pocketShift"] = list(lights["shift"])
    if lights.get("flames"):
        data["flames"] = [[_num(c) for c in row] for row in lights["flames"]]
    vb = tool("make-venue-levels.py").venuebake()
    if getattr(vb, "SCROLL_ROWS", False):
        if lights.get("scroll"):
            data["scroll"] = [list(r) for r in lights["scroll"]]
        if lights.get("lava"):
            data["lava"] = [list(r) for r in lights["lava"]]
    w = arena.get("world")
    if isinstance(w, dict):
        data["world"] = [_num(w.get("x", 0)), _num(w.get("y", 0)), _num(w.get("z", 0)),
                         _num(w.get("yaw", 0))]
    sp = [q for q in arena.get("spawns") or [] if isinstance(q, dict)][:16]
    if sp:
        data["spawns"] = [[_num(q.get("x", 0)), _num(q.get("y", 0)), _num(q.get("z", 0)),
                           _num(q.get("yaw", 0))] for q in sp]
    from .families.race import race_world
    if race_world(arena) is not None:
        data["race"] = True
    look, sounds = resolve_look(arena, notes)
    if lights.get("darkBaked"):
        dark = look.pop("dark", None)
        if dark and look.get("fog"):
            look["fogDark"] = [int(c) for c in dark]
    hour = rig_hour(arena, lights)
    if hour:
        data["hour"] = hour
    data["look"] = look
    if isinstance(arena.get("course"), int) and arena["course"] >= 16:
        data["course"] = int(arena["course"])
    stars = sorted(arena.get("stars") or [], key=lambda s: s.get("id") or 99)
    if stars:
        data["stars"] = [[_num(s["x"]), _num(s["y"]), _num(s["z"]), str(s.get("name") or "")]
                         for s in stars]
    if arena.get("coinStar"):
        data["coinStar"] = True
    rows = []
    for raw in arena.get("movers") or []:
        mv = movers.normalise(raw)
        row = {"x": _num(mv["x"]), "y": _num(mv["y"]), "z": _num(mv["z"]),
               "yaw": _num(mv.get("yaw", 0)), "mode": mv["mode"], "trigger": mv["trigger"],
               "phase": int(mv["phase"]), "points": mv["points"], "key": mv["key"]}
        if mv.get("link"):
            row["link"] = int(mv["link"])
        shape = movers.shape_of(mv["key"])
        if shape in LOGS:
            row["model"], row["col"] = LOGS[shape]
            row["log"] = True
        else:
            row["model"], row["col"], more = mover_files(mv["key"])
            files.update(more)
        rows.append(row)
    if rows:
        data["movers"] = rows
    try:
        things, pieces, tracks, actors, counts = modpackthings.things(arena, notes)
    except modpackthings.ThingError as why:
        raise PackError(str(why))
    if things:
        data["things"] = things
    if pieces:
        data["pieces"] = pieces
    if tracks:
        data["tracks"] = tracks
    reds = sum(1 for t in things if t.get("bhv") == "id_bhvRedCoin")
    if reds:
        data["redCoins"] = reds
    if data.get("stars") or data.get("coinStar") or reds:
        actors = actors + [STAR_BACKDROP]
    if tracks:
        actors = actors + [UI_SELECT]
    for rel in actors:
        with open(os.path.join(REPO, rel), "rb") as handle:
            files[rel] = handle.read()
    if counts.get("mode") or arena.get("markers"):
        notes.append("the Shell Racer track is a game mode's and stays with Oldfart's Mod Menu "
                     "- everything else comes along")
    wires = []
    for w in arena.get("wires") or []:
        row = [w.get("on"), int(w.get("src", 0)), w.get("act"), int(w.get("dst", 0))]
        if w.get("arg") not in (None, ""):
            row.append(str(w["arg"]))
        wires.append(row)
    if wires:
        data["wires"] = wires
    m = tool("make-arenas.py")
    water = basins.real_water(arena, m.LEVELS.get(arena.get("level"), {}).get("floor"))
    water = list(water or []) + tool("make-venue-levels.py").venuebake().sheet_rows(arena, water)
    if water:
        rows = []
        for wbox in water:
            wbox = list(wbox) + [None] * (6 - len(wbox))
            if wbox[5] is None:
                wbox[5] = wbox[4] - 400
            rows.append([_num(c) for c in wbox[:6]])
        data["water"] = rows
    return data, files, sounds
DATA_TAIL = r'''
-- This map's music, readied here because a track is found in the mod that
-- ships it (this one), whichever copy of the runtime plays it.
local look = map.look or {}
if type(look.musicFile) == "string" then
    if look.musicStream ~= nil then
        if type(audio_stream_load) == "function" then
            look.stream = audio_stream_load(look.musicFile .. "." .. look.musicStream)
            if look.stream ~= nil and type(look.musicLoop) == "table"
                and type(audio_stream_set_loop_points) == "function" then
                audio_stream_set_loop_points(look.stream, look.musicLoop[1], look.musicLoop[2] or 0)
            end
        end
    elseif type(smlua_audio_utils_allocate_sequence) == "function"
        and type(smlua_audio_utils_replace_sequence) == "function"
        and type(mod_file_exists) == "function"
        and mod_file_exists("sound/" .. look.musicFile .. ".m64") then
        local seq = smlua_audio_utils_allocate_sequence()
        local floor = type(SEQ_COUNT) == "number" and SEQ_COUNT or 0
        if type(seq) == "number" and seq > floor and seq < 128 then
            smlua_audio_utils_replace_sequence(seq, look.musicBank or 37, look.musicVolume or 75,
                look.musicFile)
            look.musicSeq = seq
        end
    end
end

-- The tracks it takes along, readied the same way.
for _, t in ipairs(type(look.tracks) == "table" and look.tracks or {}) do
    if type(t) == "table" and type(t.file) == "string" then
        if t.stream ~= nil then
            if type(audio_stream_load) == "function" then
                t.handle = audio_stream_load(t.file .. "." .. t.stream)
                if t.handle ~= nil and type(t.loop) == "table"
                    and type(audio_stream_set_loop_points) == "function" then
                    audio_stream_set_loop_points(t.handle, t.loop[1], t.loop[2] or 0)
                end
            end
        elseif type(smlua_audio_utils_allocate_sequence) == "function"
            and type(smlua_audio_utils_replace_sequence) == "function"
            and type(mod_file_exists) == "function"
            and mod_file_exists("sound/" .. t.file .. ".m64") then
            local seq = smlua_audio_utils_allocate_sequence()
            local floor = type(SEQ_COUNT) == "number" and SEQ_COUNT or 0
            if type(seq) == "number" and seq > floor and seq < 128 then
                smlua_audio_utils_replace_sequence(seq, t.bank or 37, t.volume or 75, t.file)
                t.seq = seq
            end
        end
    end
end

-- Its progress (stars, best coins) kept in this mod's own storage, so it
-- stays with the map whichever copy of the runtime leads the lobby: read
-- here at load, written by this file's own update when the runtime asks.
map.saved, map.saveQueue = {}, {}
local slug = string.lower(tostring(map.key or "")):gsub("[^%w]", "")
if type(mod_storage_load) == "function" then
    for _, k in ipairs({ "bonus_" .. slug, "coins_" .. slug }) do
        local v = mod_storage_load(k)
        if v ~= nil and v ~= "" then map.saved[k] = v end
    end
end
-- A recording that did not load (a joiner whose files were still arriving)
-- is tried again from here, this mod's own context, a few times.
local tries, wait = 0, 0
if type(hook_event) == "function" and HOOK_UPDATE ~= nil then
    hook_event(HOOK_UPDATE, function()
        if next(map.saveQueue) ~= nil and type(mod_storage_save) == "function" then
            for k, v in pairs(map.saveQueue) do mod_storage_save(k, v) end
            map.saveQueue = {}
        end
        if look.musicStream ~= nil and look.stream == nil and type(look.musicFile) == "string"
            and tries < 10 and type(audio_stream_load) == "function" then
            wait = wait + 1
            if wait >= 60 then
                wait, tries = 0, tries + 1
                look.stream = audio_stream_load(look.musicFile .. "." .. look.musicStream)
                if look.stream ~= nil and type(look.musicLoop) == "table"
                    and type(audio_stream_set_loop_points) == "function" then
                    audio_stream_set_loop_points(look.stream, look.musicLoop[1], look.musicLoop[2] or 0)
                end
            end
        end
    end)
end

-- Into the shared list every copy of oldfart_maps.lua reads.
local hub = rawget(_G, "OldfartMapsHub")
if hub == nil then
    hub = {}
    _G.OldfartMapsHub = hub
end
hub.maps = hub.maps or {}
hub.maps[#hub.maps + 1] = map
'''
def data_file(data, venue=None):
    head = ("-- %s - a map made with Oldfart Studio.\n"
            "-- Needs oldfart_maps.lua (any copy, in any mod of the lobby). Made by the\n"
            "-- Studio's Export level: change the map there and export it again rather\n"
            "-- than editing this file.\n\n" % data["name"])
    text = head + "local map = " + lua_value(data) + "\n"
    if venue:
        text += ("\n-- The same map as Oldfart's Mod Menu lays its own worlds (its venue row,\n"
                 "-- written by its own tools/make-arenas.py): when the full mod is in the\n"
                 "-- lobby it adopts this and plays the map exactly as its own.\n"
                 "map.venue = " + venue + "\n")
    return text + DATA_TAIL
def venue_table(arena, key, face=None):
    m = tool("make-arenas.py")
    a = json.loads(json.dumps(arena))
    a["key"] = script_of(key)
    m.connect([p for p in a["pieces"] if float(p.get("yaw", 0) or 0) % 90 == 0])
    for p in a["pieces"]:
        p["model"] = m.model_name(p)
    a["solids"] = m.solids_faults(a)
    a.setdefault("budget", 0)
    a.setdefault("survey", {})
    if not a.get("spawns"):
        w = a.get("world") if isinstance(a.get("world"), dict) else {}
        a["spawns"] = [{"x": w.get("x", 0), "y": w.get("y", 0), "z": w.get("z", 0),
                        "yaw": w.get("yaw", 0)}]
    look = a.get("look") if isinstance(a.get("look"), dict) else {}
    look.setdefault("sky", "")
    look.setdefault("music", "")
    a["look"] = look
    reds = sum(1 for o in a.get("objects") or [] if o.get("key") == "redcoin")
    text = m.lua_table([a])
    lines = text.split("\n")
    head = "    %s = {" % a["key"]
    i = lines.index(head)
    j = lines.index("    },", i)
    body = ["{"] + [ln[4:] for ln in lines[i + 1:j]] + ["}"]
    if reds:
        body.insert(1, "    redStar = true,")
    if face:
        body.insert(1, '    face = { top = "%s", bottom = "%s" },' % (face["top"], face["bottom"]))
    return "\n".join(body)
MAIN_LUA = '''-- name: %(name)s
-- description: A map made with Oldfart Studio.\\n\\nType /ofmap in the chat to see the maps and travel to one.
'''
def readme(name, key, notes, own_main):
    lines = [
        "OLDFART MAPS - %s" % name,
        "=" * (15 + len(name)),
        "",
        "This folder has a map made with Oldfart Studio. It works in any",
        "sm64coopdx mod or modpack. You do not need Oldfart's Mod Menu.",
        "",
        "HOW TO USE IT",
        "",
        "1. Copy everything in this folder into your mod's folder (the folder",
        "   in sm64coopdx's mods folder that has a main.lua in it). Keep the",
        "   levels, actors and sound folders as they are - merge them with the",
        "   ones your mod already has.",
        ("   This folder also works as a mod on its own: it has its own main.lua."
         if own_main else
         "   Your mod's own main.lua was left alone."),
        "2. Start the game and turn the mod on.",
        "3. In the chat, type /ofmap to see the maps, and /ofmap 1 to go to the",
        "   first one.",
        "",
        "CHAT COMMANDS",
        "",
        "  /ofmap              the list of maps",
        "  /ofmap 1            go to map 1 (or type its name: /ofmap %s)" % key,
        "  /ofmap 1 all        the host takes everybody there",
        "  /ofmap home         back to the start of the game",
        "  /ofmap lock         the host only: now only the host can travel",
        "  /ofmap unlock       the host only: everybody can travel again",
        "  /ofmap music        the songs you can put on (the game's and the maps')",
        "  /ofmap music 3      the host only: song 3 for everybody, in every level",
        "  /ofmap music off    the host only: each level's own music again",
        "  /ofmap music me 3   song 3 just for you (/ofmap music me off: stop)",
        "",
        "Anybody can visit a map until the host types /ofmap lock.",
        "",
        "MORE THAN ONE MAP",
        "",
        "Export as many maps as you like into the same folder, or into",
        "different mods. Every map brings a copy of oldfart_maps.lua; that is",
        "fine. The newest copy does the work and the others wait quietly.",
        "If two maps have the same short name (%s), the newer one is used." % key,
        "",
        "WHAT THE MAP BRINGS",
        "",
        "Everything in it: its level, sky, music, weather and light, every",
        "object (enemies, coins and coin rings, red coins, pipes, springs,",
        "boxes, lifts...), moving platforms, buttons and targets, the ON/OFF",
        "switch and its blocks, sound spots, triangular blocks, balls to",
        "ride, speedrun tracks (walk into the start ring - the clock runs",
        "until the flag), and all its stars: its bonus stars with a star",
        "picker before you travel there, the 100-coin star and the red coins'",
        "star.",
        "Stars are the room's: the host's computer remembers them.",
        "",
        "WHAT STAYS BEHIND",
        "",
        "Only game modes - those are part of Oldfart's Mod Menu. A Shell",
        "Racer track in the map is a game mode's, so it is not shown.",
        "",
        "WITH OLDFART'S MOD MENU",
        "",
        "If Oldfart's Mod Menu is on too, it plays the map as one of its own",
        "worlds - the same map, the same things - and /ofmap still takes you",
        "there. Its own Music page plays the music then.",
        "",
        "THE FILES",
        "",
        "  oldfart_maps.lua          the map runtime (the same in every export)",
        "  oldfart_map_%s.lua%s the map itself" % (key, " " * max(1, 13 - len(key))),
        "  levels/level_ofmap_%s_entry.lvl   the level" % key,
        "  actors/ofmap_mv_*         moving platforms (only if the map has any)",
        "  actors/of_*               the star picker's wall, triangular blocks,",
        "                            balls (only what the map uses)",
        "  sound/                    the map's music (only if it brings its own)",
    ]
    if own_main:
        lines.append("  main.lua                  makes this folder a mod of its own")
    if notes:
        lines += ["", "NOTES FROM THE EXPORT", ""] + ["  - " + n for n in notes]
    return "\n".join(lines) + "\n"
def problems(layout, folder, key, name):
    out = []
    if not (name or "").strip():
        out.append("Give the map a name")
    if not KEY_RE.match(key or ""):
        out.append("The short name must be 3-24 small letters or digits, starting with a letter")
    if not (layout or {}).get("pieces"):
        out.append("The map is empty - put some pieces in it first")
    else:
        far = worldedge.far(layout)
        if far:
            out.append(worldedge.message(far, layout))
    if not (folder or "").strip():
        out.append("Choose the folder to export into")
    elif os.path.isfile(os.path.join(folder, "of_venues.lua")):
        out.append("That is Oldfart's Mod Menu's own folder - use Export into the mod for it, "
                   "or choose another folder")
    elif os.path.exists(folder) and not os.path.isdir(folder):
        out.append("That is a file, not a folder")
    return out
PAINTING = True
def plan(layout, key, name, blurb=None, made=None, folder=None):
    notes = []
    arena = prepared_arena(layout, key, name)
    far = worldedge.far(arena)
    if far:
        raise PackError(worldedge.message(far, arena))
    if arena.get("stars") and not isinstance(arena.get("course"), int):
        import zlib
        arena["course"] = 16 + zlib.crc32(key.encode("utf-8")) % 84
    lvl, level = level_file(arena, key)
    for i in level.runtime:
        p = arena["pieces"][i]
        raise PackError("the %s at x %s, z %s is a piece the level cannot hold (%s) - take it "
                        "out of the map and export again"
                        % (p.get("decor") or p.get("kind") or "piece", _num(p.get("x", 0)),
                           _num(p.get("z", 0)), "a prop the kit does not know"
                           if p.get("decor") else "a kind the kit does not know"))
    data, files, sounds = map_table(arena, key, name, blurb, made or time.time(), notes)
    data.update(fog_fields(level))
    files = dict(files)
    face = None
    if PAINTING:
        from . import painting
        pfiles, face = painting.export_files(arena, key)
        if face:
            files.update(pfiles)
            data["painting"] = face
        else:
            notes.append("no painting: the map could not be drawn for one")
        from . import romobjects
        if face and romobjects.wanted(arena) and romobjects.root() is None:
            notes.append(romobjects.MISSING)
    files["levels/%s.lvl" % level_name(key)] = lvl
    files["oldfart_map_%s.lua" % key] = luastrip.strip(
        data_file(data, venue_table(arena, key, face))).encode("utf-8")
    text = luastrip.strip(runtime_text())
    keep = folder is not None and _have_newer_runtime(folder, runtime_version(text))
    if not keep:
        files[RUNTIME_NAME] = text.encode("utf-8")
    own_main = folder is None or not os.path.isfile(os.path.join(folder, "main.lua"))
    if own_main:
        files["main.lua"] = luastrip.strip(MAIN_LUA % {"name": name.replace("\n", " ")},
                                           keep_header=True).encode("utf-8")
    files[README_NAME] = readme(name, key, notes, own_main).encode("utf-8")
    stats = {"pieces": len(level.static), "stars": len(data.get("stars") or []),
             "movers": len(data.get("movers") or []), "logic": len(data.get("pieces") or []),
             "things": len(data.get("things") or []), "tracks": len(data.get("tracks") or []),
             "level_bytes": len(lvl), "runtime_kept": keep}
    return files, sounds, notes, stats
def _have_newer_runtime(folder, mine):
    path = os.path.join(folder, RUNTIME_NAME)
    if not os.path.isfile(path):
        return False
    with open(path, encoding="utf-8", errors="replace") as handle:
        return runtime_version(handle.read()) > mine
def wall(folder, files, sounds):
    rs = tool("release_size.py")
    now = rs.engine_bytes(folder) if os.path.isdir(folder) else 0
    add = sum(len(b) for b in files.values()) + sum(os.path.getsize(s) for s in sounds.values())
    if now + add < rs.MAX_MOD_SIZE:
        return None
    return ("that folder would grow to about %.1f MB - past Coop DX's 35 MB limit, where a mod "
            "is greyed out. Choose another folder, or make room in this one"
            % ((now + add) / 1048576.0))
def export(layout, folder, key, name, blurb=None, made=None):
    bad = problems(layout, folder, key, name)
    if bad:
        raise PackError(bad[0])
    files, sounds, notes, stats = plan(layout, key, name, blurb, made, folder)
    too_big = wall(folder, files, sounds)
    if too_big:
        raise PackError(too_big)
    os.makedirs(folder, exist_ok=True)
    written = []
    for rel, data in sorted(files.items()):
        path = os.path.join(folder, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".part"
        with open(tmp, "wb") as handle:
            handle.write(data)
        os.replace(tmp, path)
        written.append(path)
    for rel, src in sorted(sounds.items()):
        path = os.path.join(folder, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        shutil.copyfile(src, path)
        written.append(path)
    return {"files": written, "notes": notes, "stats": stats,
            "readme": os.path.join(folder, README_NAME)}
def handoff(res, name, key, folder):
    st = res["stats"]
    extras = []
    if st["stars"]:
        extras.append("%d bonus star%s" % (st["stars"], "" if st["stars"] == 1 else "s"))
    if st["movers"]:
        extras.append("%d moving platform%s" % (st["movers"], "" if st["movers"] == 1 else "s"))
    if st["logic"]:
        extras.append("%d button/zone/target piece%s" % (st["logic"], "" if st["logic"] == 1 else "s"))
    if st.get("things"):
        extras.append("%d object%s" % (st["things"], "" if st["things"] == 1 else "s"))
    if st.get("tracks"):
        extras.append("%d speedrun track%s" % (st["tracks"], "" if st["tracks"] == 1 else "s"))
    lines = ["%s is ready in %s." % (name, folder),
             "",
             "Copy that folder's files into any sm64coopdx mod (or use the folder as a mod "
             "of its own), start the game, and type /ofmap in the chat - then /ofmap %s." % key]
    if extras:
        lines += ["", "It brings " + ", ".join(extras) + "."]
    if res["notes"]:
        lines += ["", "Good to know:"] + ["  - " + n for n in res["notes"]]
    lines += ["", "Everything is explained in %s in that folder." % README_NAME]
    return "\n".join(lines)
