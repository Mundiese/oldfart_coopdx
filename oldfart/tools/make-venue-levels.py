#!/usr/bin/env python3
import json
import os
import re
import struct
import sys
import zlib
HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
LEVELS = os.path.join(MOD, "levels")
MAGIC = b"DYNOSBIN"
VENUES = [
    ("skykeep", "of_sky_keep", "empty2"),
]
def generated_venues():
    folder = os.path.join(HERE, "venues-generated")
    out = []
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.endswith(".json"):
                with open(os.path.join(folder, name), encoding="utf-8") as handle:
                    arena = json.load(handle)
                ground = arena.get("ground") if arena["level"] == "empty" else None
                arena["_generated"] = True
                out.append((arena["key"], arena.get("script") or "of_" + arena["key"],
                            arena["level"], ground, water_boxes(arena), world_of(arena), arena))
    return out
_bake = None
def venuebake():
    global _bake
    if _bake is None:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "venuebake", os.path.join(os.path.dirname(os.path.abspath(__file__)), "venuebake.py"))
        _bake = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_bake)
    return _bake
def release_install():
    import importlib.util
    import sys
    if "of_luaregion" not in sys.modules:
        spec = importlib.util.spec_from_file_location(
            "of_luaregion", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "luaregion.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules["of_luaregion"] = module
    return sys.modules["of_luaregion"].is_release(MOD)
_levels = {}
def baked_level(arena, name):
    vb = venuebake()
    if not arena or not vb.wants_bake(arena):
        return None
    import json
    sig = (name, json.dumps(arena, sort_keys=True, default=str))
    if sig not in _levels:
        _levels.clear()
        _levels[sig] = vb.compile_level(arena, script=name)
    return _levels[sig]
def generated_level(key):
    for row in generated_venues():
        if row[0] == key:
            return baked_level(row[6], row[1])
    return None
WARP_LIFT = 100
START_LIFT = 80
WARP_BEHAVIOUR = b"PNTR\x13bhvSpinAirborneWarp"
def world_of(arena):
    w = arena.get("world")
    if not isinstance(w, dict) or "x" not in w or "z" not in w:
        return None
    return (int(round(w["x"])), int(round(w.get("y", 0))), int(round(w["z"])),
            int(round(w.get("yaw", 0))) % 360)
def generated_world(key):
    for row in generated_venues():
        if row[0] == key:
            return row[5] if len(row) > 5 else None
    return None
def _script_start(body):
    m = re.search(rb"level_[A-Za-z0-9_]+_entry", body)
    if m is None:
        raise SystemExit("no level script in this level")
    return m.end()
def entry_points(body):
    start = _script_start(body)
    out = []
    i = body.find(WARP_BEHAVIOUR, start)
    if i < 0 or body[i - 20:i - 18] != b"\x24\x18":
        raise SystemExit("no 0x0A warp object in this level's script")
    out.append(("warp", i - 20))
    i = body.find(b"\x2b\x0c", start)
    while i >= 0:
        out.append(("start", i))
        i = body.find(b"\x2b\x0c", i + 12)
    if len(out) < 2:
        raise SystemExit("no MARIO_POS in this level's script")
    return out
def entry_of(body):
    out = {"start": []}
    for kind, at in entry_points(body):
        if kind == "warp":
            x, y, z = struct.unpack("<hhh", body[at + 4:at + 10])
            out["warp"] = (x, y, z, struct.unpack("<h", body[at + 12:at + 14])[0])
        else:
            out["start"].append(struct.unpack("<hhhh", body[at + 4:at + 12]))
    return out
def entry_body(body, world):
    if not world:
        return body
    x, y, z, yaw = world
    b = bytearray(body)
    for kind, at in entry_points(body):
        if kind == "warp":
            b[at + 4:at + 10] = struct.pack("<hhh", x, y + WARP_LIFT, z)
            b[at + 12:at + 14] = struct.pack("<h", yaw)
        else:
            b[at + 4:at + 12] = struct.pack("<hhhh", yaw, x, y + START_LIFT, z)
    return bytes(b)
def entry_source(text, world):
    if not world:
        return text
    x, y, z, yaw = world
    text = re.sub(r"MARIO_POS\(0x01, -?\d+, -?\d+, -?\d+, -?\d+\)",
                  "MARIO_POS(0x01, %d, %d, %d, %d)" % (yaw, x, y + START_LIFT, z), text)
    return re.sub(r"OBJECT\(MODEL_NONE, -?\d+, -?\d+, -?\d+, 0, -?\d+, 0, \(0x0A << 16\), "
                  r"bhvSpinAirborneWarp\)",
                  "OBJECT(MODEL_NONE, %d, %d, %d, 0, %d, 0, (0x0A << 16), bhvSpinAirborneWarp)"
                  % (x, y + WARP_LIFT, z, yaw), text)
DATA_TYPE_COLLISION = 11
TERRAIN_LOAD_END = 0x42
TERRAIN_LOAD_ENVIRONMENT = 0x44
WATER_MAX = 20
TAB, NL = chr(9), chr(10)
def water_boxes(arena):
    boxes = arena.get("water") or None
    if not boxes:
        return None
    out = []
    for w in boxes[:WATER_MAX]:
        x0, z0, x1, z1, y = (int(round(v)) for v in w[:5])
        out.append((min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1), y))
    return tuple(out)
def _env_words(boxes):
    words = [TERRAIN_LOAD_ENVIRONMENT, len(boxes)]
    for i, (x0, z0, x1, z1, y) in enumerate(boxes):
        words += [i, x0, z0, x1, z1, y]
    return words
ANCHOR = (30000, 30000, 30100, 30100, -11000)
ANCHORED = ("empty", "empty2", "the_studio", "the_plate", "desert_cage", "ice_donut",
            "the_stadium", "the_stadium2")
SURFACE_FORCE = (0x0004, 0x000E, 0x0024, 0x0025, 0x0027, 0x002C, 0x002D)
TERRAIN_LOAD_VERTICES = 0x40
TERRAIN_LOAD_CONTINUE = 0x41
def split_env(words):
    if not words or words[0] != TERRAIN_LOAD_VERTICES:
        raise SystemExit("collision does not open with TERRAIN_LOAD_VERTICES")
    i = 2 + 3 * words[1]
    while words[i] != TERRAIN_LOAD_CONTINUE:
        per = 4 if words[i] in SURFACE_FORCE else 3
        i += 2 + per * words[i + 1]
    i += 1
    head = list(words[:i])
    boxes = []
    while words[i] != TERRAIN_LOAD_END:
        if words[i] == TERRAIN_LOAD_ENVIRONMENT:
            n = words[i + 1]
            for k in range(n):
                _, x0, z0, x1, z1, y = words[i + 2 + 6 * k:i + 8 + 6 * k]
                boxes.append((x0, z0, x1, z1, y))
            i += 2 + 6 * n
        else:
            raise SystemExit("collision section %#x after the triangles is not read here"
                             % words[i])
    return head, boxes
def water_body(body, boxes):
    if not boxes:
        return body
    at = 0
    while True:
        at = body.find(bytes([DATA_TYPE_COLLISION]), at)
        if at < 0:
            raise SystemExit("the level body has no collision node")
        n = body[at + 1]
        name = body[at + 2:at + 2 + n]
        if b"collision" in name and all(32 < c < 127 for c in name):
            break
        at += 1
    start = at + 2 + n
    size = struct.unpack("<I", body[start:start + 4])[0]
    words = list(struct.unpack("<%dh" % size, body[start + 4:start + 4 + 2 * size]))
    if not words or words[-1] != TERRAIN_LOAD_END:
        raise SystemExit("the collision node does not end in TERRAIN_LOAD_END")
    head, have = split_env(words)
    every = list(have) + [tuple(b) for b in boxes if tuple(b) not in have]
    if len(every) > WATER_MAX:
        raise SystemExit("%d water boxes, the engine loads %d" % (len(every), WATER_MAX))
    words = head + _env_words(every) + [TERRAIN_LOAD_END]
    data = struct.pack("<I", len(words)) + struct.pack("<%dh" % len(words), *words)
    return body[:start] + data + body[start + 4 + 2 * size:]
WATER_LINE = re.compile(r"\tCOL_WATER_BOX\((-?\d+), (-?\d+), (-?\d+), (-?\d+), (-?\d+), (-?\d+)\),\n")
def water_source(text, boxes):
    if not boxes:
        return text
    have = [tuple(int(v) for v in m.groups()[1:]) for m in WATER_LINE.finditer(text)]
    text = WATER_LINE.sub("", text)
    text = re.sub(r"\tCOL_WATER_BOX_INIT\(\d+\),\n", "", text)
    every = list(have) + [tuple(b) for b in boxes if tuple(b) not in have]
    lines = [TAB + "COL_WATER_BOX_INIT(%d)," % len(every)]
    for i, (x0, z0, x1, z1, y) in enumerate(every):
        lines.append(TAB + "COL_WATER_BOX(%d, %d, %d, %d, %d, %d)," % (i, x0, z0, x1, z1, y))
    at = text.rfind(TAB + "COL_END()")
    if at < 0:
        raise SystemExit("collision.inc.c has no COL_END()")
    return text[:at] + NL.join(lines) + NL + text[at:]
def base_body(base):
    body = read_lvl(os.path.join(LEVELS, "level_%s_entry.lvl" % base))
    return water_body(body, [ANCHOR]) if base in ANCHORED else body
def generated_water(key):
    for row in generated_venues():
        if row[0] == key:
            return row[4]
    return None
TILES_GROUNDS = {"grass": "grass", "ice": "ice", "sand": "sand", "stone": "flagstone",
                 "snow": "snowblock", "wood": "woodenplank1"}
TILES_TEXTURE = "empty_dl_Texture0322_RGB_ci8"
TILES_PALETTE = "empty_dl_Texture0322_RGB_pal_rgba16"
TILES_COLOURS = 23
MANIFEST = os.path.join(HERE, "blocks-manifest.txt")
ASSETS = MOD
def block_source(slug):
    import importlib.util
    spec = importlib.util.spec_from_file_location("make_blocks", os.path.join(HERE, "make-blocks.py"))
    mb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mb)
    _, rows = mb.read_manifest(MANIFEST)
    for row in rows:
        if row["slug"] == slug:
            return os.path.join(ASSETS, (row.get("layers") or [row["source"]])[0])
    raise SystemExit("no block %r in the manifest" % slug)
def ground_texture(ground):
    import io
    from PIL import Image
    im = Image.open(block_source(TILES_GROUNDS[ground])).convert("RGBA")
    if im.size != (32, 32):
        im = im.resize((32, 32), Image.NEAREST)
    q = im.convert("RGB").quantize(colors=TILES_COLOURS, method=Image.MEDIANCUT, dither=0)
    pal = q.getpalette()[:3 * TILES_COLOURS]
    pal += [0] * (3 * TILES_COLOURS - len(pal))
    idx = list(q.getdata())
    words, rgb = [], []
    for k in range(TILES_COLOURS):
        r, g, b = pal[3 * k:3 * k + 3]
        r5, g5, b5 = r >> 3, g >> 3, b >> 3
        words.append((r5 << 11) | (g5 << 6) | (b5 << 1) | 1)
        rgb.append(((r5 << 3) | (r5 >> 2), (g5 << 3) | (g5 >> 2), (b5 << 3) | (b5 >> 2), 255))
    out = Image.new("RGBA", (32, 32))
    out.putdata([rgb[i] for i in idx])
    buf = io.BytesIO()
    out.save(buf, format="PNG", optimize=False)
    return idx, b"".join(struct.pack(">H", w) for w in words), buf.getvalue()
ICE_GROUNDS = ("ice",)
SURFACE_DEFAULT, SURFACE_ICE = 0x0000, 0x002E
def ice_floor(body):
    at = 0
    while True:
        at = body.find(bytes([DATA_TYPE_COLLISION]), at)
        if at < 0:
            raise SystemExit("the level body has no collision node")
        n = body[at + 1]
        name = body[at + 2:at + 2 + n]
        if b"collision" in name and all(32 < c < 127 for c in name):
            break
        at += 1
    start = at + 2 + n
    size = struct.unpack("<I", body[start:start + 4])[0]
    words = list(struct.unpack("<%dh" % size, body[start + 4:start + 4 + 2 * size]))
    nverts = words[1]
    k = 2 + 3 * nverts
    groups = 0
    while k < len(words) and words[k] < 0x40:
        if groups == 1 and words[k] == SURFACE_DEFAULT:
            words[k] = SURFACE_ICE
            break
        k += 2 + 3 * words[k + 1]
        groups += 1
    else:
        raise SystemExit("The Tiles' collision has no floor group to ice")
    return body[:start + 4] + struct.pack("<%dh" % size, *words) + body[start + 4 + 2 * size:]
def ground_body(body, ground):
    if not ground:
        return body
    if ground in ICE_GROUNDS:
        body = ice_floor(body)
    name = TILES_TEXTURE.encode()
    at = body.find(bytes([len(name)]) + name)
    if at < 0:
        raise SystemExit("The Tiles' body has no %s texture node" % TILES_TEXTURE)
    start = at + 1 + len(name)
    size = struct.unpack("<I", body[start:start + 4])[0]
    if body[start + 4:start + 12] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("%s is not a PNG node" % TILES_TEXTURE)
    png = ground_texture(ground)[2]
    return body[:start] + struct.pack("<I", len(png)) + png + body[start + 4 + size:]
def ground_source(text, ground):
    if not ground:
        return text
    idx, pal, _ = ground_texture(ground)
    def array(name, values):
        lines = []
        for k in range(0, len(values), 8):
            lines.append("\t" + " ".join("0x%02x," % v for v in values[k:k + 8]) + " ")
        body = "\n".join(lines)
        return "u8 %s[] = {\n%s\n};" % (name, body)
    for name, values in ((TILES_TEXTURE, idx), (TILES_PALETTE, list(pal))):
        m = re.search(r"u8 %s\[\] = \{.*?\n\};" % re.escape(name), text, re.S)
        if not m:
            raise SystemExit("levels/empty/model.inc.c has no %s array" % name)
        text = text[:m.start()] + array(name, values) + text[m.end():]
    return text
SOFT64_LIB = os.path.join(MOD, "assets-incoming", "1006", "textures")
LEVEL_SOFT64 = {
    "empty": {"empty_dl_Texture0322_RGB": "cuttile"},
    "desert_cage": {"desert_cage_dl_Texture0250_RGB": "sandstonebrick"},
    "ice_donut": {"ice_donut_dl_Texture0443_RGB": "icepacked"},
    "the_plate": {"the_plate_dl_Texture0057_RGB": "checkerbw",
                  "the_plate_dl_Texture0118_RGB": "brred"},
    "the_stadium": {"the_stadium_dl_Texture0195_RGB": "grassmeadow",
                    "the_stadium_dl_Tile0247_RGB": "sbgrey"},
    "the_stadium2": {"the_stadium2_dl_Texture0141_RGB": "sandbeach",
                     "the_stadium2_dl_Tile0247_RGB": "sbgrey"},
}
UV_TILE_TEXELS = 32
LEVEL_UV = {
    "the_plate": {"the_plate_dl_Ground_mesh_layer_1_vtx_0": (400, 256)},
}
def planar_uv(x, z, tile, offset):
    scale = UV_TILE_TEXELS * 32 / tile
    return int(round(offset + x * scale)), int(round(offset + z * scale))
def _vtx_node(body, name):
    raw = name.encode()
    at = body.find(bytes([len(raw)]) + raw)
    if at < 0:
        raise SystemExit("the level body has no %s vertex node" % name)
    start = at + 1 + len(raw)
    count = struct.unpack("<I", body[start:start + 4])[0]
    return start + 4, count
def uv_body(body, base):
    for name, (tile, offset) in sorted(LEVEL_UV.get(base, {}).items()):
        first, count = _vtx_node(body, name)
        out = bytearray(body)
        for k in range(count):
            at = first + 16 * k
            x, _, z = struct.unpack("<hhh", body[at:at + 6])
            out[at + 8:at + 12] = struct.pack("<hh", *planar_uv(x, z, tile, offset))
        body = bytes(out)
    return body
VTX_LINE = re.compile(r"(\{\{ \{(-?\d+), (-?\d+), (-?\d+)\}, (-?\d+), \{)(-?\d+), (-?\d+)(\})")
def _vtx_array(text, name):
    return re.search(r"Vtx %s\[\d+\] = \{.*?\n\};" % re.escape(name), text, re.S)
def uv_source(text, base):
    for name, (tile, offset) in sorted(LEVEL_UV.get(base, {}).items()):
        m = _vtx_array(text, name)
        if not m:
            raise SystemExit("%s has no %s array" % (base, name))
        def lay(v):
            u, w = planar_uv(int(v.group(2)), int(v.group(4)), tile, offset)
            return "%s%d, %d%s" % (v.group(1), u, w, v.group(8))
        text = text[:m.start()] + VTX_LINE.sub(lay, m.group(0)) + text[m.end():]
    return text
def uv_problems():
    import io
    from PIL import Image
    bad = []
    for base, nodes in sorted(LEVEL_UV.items()):
        body = read_lvl(os.path.join(LEVELS, "level_%s_entry.lvl" % base))
        text = _slurp(os.path.join(LEVELS, base, "model.inc.c")).decode("utf-8")
        for name, (tile, offset) in sorted(nodes.items()):
            first, count = _vtx_node(body, name)
            for k in range(count):
                at = first + 16 * k
                x, _, z, _, tu, tv = struct.unpack("<hhhhhh", body[at:at + 12])
                if (tu, tv) != planar_uv(x, z, tile, offset):
                    bad.append("%s .lvl %s[%d]: UV %d, %d at %d, %d" % (base, name, k, tu, tv, x, z))
                    break
            m = _vtx_array(text, name)
            if m is None:
                bad.append("%s model.inc.c has no %s" % (base, name))
                continue
            for v in VTX_LINE.finditer(m.group(0)):
                want = planar_uv(int(v.group(2)), int(v.group(4)), tile, offset)
                if (int(v.group(6)), int(v.group(7))) != want:
                    bad.append("%s model.inc.c %s: UV %s, %s at %s, %s"
                               % (base, name, v.group(6), v.group(7), v.group(2), v.group(4)))
                    break
        for tex, _, colours, key in _level_textures(base):
            raw = tex.encode()
            at = body.find(bytes([len(raw)]) + raw) + 1 + len(raw)
            size = struct.unpack("<I", body[at:at + 4])[0]
            have = Image.open(io.BytesIO(body[at + 4:at + 4 + size])).convert("RGBA")
            want = Image.open(io.BytesIO(soft64_texture(key, colours)[2])).convert("RGBA")
            if have.tobytes() != want.tobytes():
                bad.append("%s %s does not wear %s" % (base, tex, key))
    return bad
def soft64_file(key):
    with open(os.path.join(SOFT64_LIB, "library.json"), encoding="utf-8") as handle:
        return os.path.join(SOFT64_LIB, json.load(handle)[key]["file"])
def _rgb5(r, g, b):
    r5, g5, b5 = r >> 3, g >> 3, b >> 3
    word = (r5 << 11) | (g5 << 6) | (b5 << 1) | 1
    return word, ((r5 << 3) | (r5 >> 2), (g5 << 3) | (g5 >> 2), (b5 << 3) | (b5 >> 2), 255)
def soft64_texture(key, colours):
    import io
    from PIL import Image
    im = Image.open(soft64_file(key)).convert("RGB")
    if colours:
        q = im.quantize(colors=colours, method=Image.MEDIANCUT, dither=0)
        pal = q.getpalette()[:3 * colours]
        pal += [0] * (3 * colours - len(pal))
        idx = list(q.tobytes())
        words, rgb = [], []
        for k in range(colours):
            w, c = _rgb5(*pal[3 * k:3 * k + 3])
            words.append(w)
            rgb.append(c)
        pixels = [rgb[i] for i in idx]
    else:
        idx, words, pixels = None, [], []
        raw = im.tobytes()
        for k in range(0, len(raw), 3):
            w, c = _rgb5(raw[k], raw[k + 1], raw[k + 2])
            words.append(w)
            pixels.append(c)
    out = Image.new("RGBA", im.size)
    out.putdata(pixels)
    buf = io.BytesIO()
    out.save(buf, format="PNG", optimize=False)
    return idx, b"".join(struct.pack(">H", w) for w in words), buf.getvalue()
def _tlut_counts(text):
    out = {}
    image = None
    for line in text.split("\n"):
        m = re.search(r"gsDPSetTextureImage\([^,]+, [^,]+, \d+, (\w+)\)", line)
        if m:
            image = m.group(1)
        m = re.search(r"gsDPLoadTLUTCmd\(\d+, (\d+)\)", line)
        if m and image:
            out[image] = int(m.group(1)) + 1
    return out
def _level_textures(base):
    swaps = LEVEL_SOFT64.get(base)
    if not swaps:
        return []
    text = _slurp(os.path.join(LEVELS, base, "model.inc.c")).decode("utf-8")
    counts = _tlut_counts(text)
    out = []
    for stem, key in sorted(swaps.items()):
        if stem + "_ci8" in text:
            pal = stem + "_pal_rgba16"
            if pal not in counts:
                raise SystemExit("%s: no TLUT load for %s" % (base, pal))
            out.append((stem + "_ci8", pal, counts[pal], key))
        elif stem + "_rgba16" in text:
            out.append((stem + "_rgba16", None, 0, key))
        else:
            raise SystemExit("%s: no texture %s" % (base, stem))
    return out
def _put_png(body, name, png):
    raw = name.encode()
    at = body.find(bytes([len(raw)]) + raw)
    if at < 0:
        raise SystemExit("the level body has no %s texture node" % name)
    start = at + 1 + len(raw)
    size = struct.unpack("<I", body[start:start + 4])[0]
    if body[start + 4:start + 12] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("%s is not a PNG node" % name)
    return body[:start] + struct.pack("<I", len(png)) + png + body[start + 4 + size:]
def soft64_body(body, base):
    for name, _, colours, key in _level_textures(base):
        body = _put_png(body, name, soft64_texture(key, colours)[2])
    return body
def _array(text, name, values, where):
    m = re.search(r"u8 %s\[\] = \{.*?\n\};" % re.escape(name), text, re.S)
    if not m:
        raise SystemExit("%s has no %s array" % (where, name))
    have = len(re.findall(r"0x[0-9a-fA-F]{2}", m.group(0)))
    values = list(values)
    if len(values) > have:
        raise SystemExit("%s: %s holds %d bytes, not %d" % (where, name, have, len(values)))
    values += [0] * (have - len(values))
    lines = []
    for k in range(0, len(values), 8):
        lines.append("\t" + " ".join("0x%02x," % v for v in values[k:k + 8]) + " ")
    return text[:m.start()] + "u8 %s[] = {\n%s\n};" % (name, "\n".join(lines)) + text[m.end():]
def soft64_source(text, base):
    for name, pal, colours, key in _level_textures(base):
        idx, words, _ = soft64_texture(key, colours)
        if pal:
            text = _array(text, name, idx, base)
            text = _array(text, pal, words, base)
        else:
            text = _array(text, name, words, base)
    return text
def base_pattern(base):
    return re.compile(re.escape(base) + (r"(?!2)" if base == "empty" else ""))
def rename_text(text, base, name):
    return base_pattern(base).sub(name, text)
def _slurp(path):
    with open(path, "rb") as handle:
        return handle.read()
def read_lvl(path):
    raw = _slurp(path)
    if raw[:8] != MAGIC:
        raise SystemExit("%s is not a compressed DynOS binary" % path)
    length = struct.unpack("<Q", raw[8:16])[0]
    body = zlib.decompress(raw[16:])
    if len(body) != length:
        raise SystemExit("%s: header says %d, body is %d" % (path, length, len(body)))
    return body
def write_lvl(body):
    return MAGIC + struct.pack("<Q", len(body)) + zlib.compress(body, 9)
IDENT = re.compile(rb"[A-Za-z0-9_]")
def names_in(body, base):
    found = []
    token = base.encode()
    pattern = re.compile(re.escape(token) + (rb"(?!2)" if base == "empty" else b""))
    for m in pattern.finditer(body):
        longest = m.end()
        while longest < len(body) and IDENT.match(body[longest:longest + 1]):
            longest += 1
        start = None
        for end in range(longest, m.end() - 1, -1):
            s = m.start()
            while s >= 1:
                if body[s - 1] == end - s:
                    start = s
                    break
                if not IDENT.match(body[s - 1:s]):
                    break
                s -= 1
            if start is not None:
                break
        if start is None:
            raise SystemExit("a %r at %d is not inside a length-prefixed name" % (base, m.start()))
        if found and found[-1][1] > start:
            continue
        found.append((start, end))
    return found
def rename_body(body, base, name):
    out = bytearray()
    at = 0
    for start, end in names_in(body, base):
        old = body[start:end].decode()
        new = rename_text(old, base, name)
        if len(new) > 254:
            raise SystemExit("%s is too long for a DynOS name" % new)
        out += body[at:start - 1]
        out.append(len(new))
        out += new.encode()
        at = end
    out += body[at:]
    return bytes(out)
def folder_files(base):
    root = os.path.join(LEVELS, base)
    for folder, _, files in os.walk(root):
        for f in sorted(files):
            path = os.path.join(folder, f)
            yield os.path.relpath(path, root)
def planned():
    out = {}
    for base in ANCHORED:
        path = os.path.join(LEVELS, "level_%s_entry.lvl" % base)
        if not os.path.isfile(path):
            continue
        out[path] = write_lvl(uv_body(soft64_body(base_body(base), base), base))
        model = os.path.join(LEVELS, base, "model.inc.c")
        if (LEVEL_SOFT64.get(base) or LEVEL_UV.get(base)) and os.path.isfile(model):
            text = soft64_source(_slurp(model).decode("utf-8"), base)
            out[model] = uv_source(text, base).encode("utf-8")
        src = os.path.join(LEVELS, base, "area_1", "collision.inc.c")
        if os.path.isfile(src):
            out[src] = water_source(_slurp(src).decode("utf-8"), [ANCHOR]).encode("utf-8")
    for row in VENUES + generated_venues():
        _, name, base = row[:3]
        ground = row[3] if len(row) > 3 else None
        water = row[4] if len(row) > 4 else None
        world = row[5] if len(row) > 5 else None
        level = baked_level(row[6], name) if len(row) > 6 else None
        texts = {}
        for rel in folder_files(base):
            text = _slurp(os.path.join(LEVELS, base, rel)).decode("utf-8")
            if rel == "script.c":
                text = entry_source(text, world)
            if rel == "model.inc.c":
                text = uv_source(soft64_source(text, base), base)
            if ground and rel == "model.inc.c":
                text = ground_source(text, ground)
            if ground in ICE_GROUNDS and rel.replace(os.sep, "/") == "area_1/collision.inc.c":
                text = text.replace(TAB + "COL_TRI_INIT(SURFACE_DEFAULT,",
                                    TAB + "COL_TRI_INIT(SURFACE_ICE,", 1)
            if rel.replace(os.sep, "/") == "area_1/collision.inc.c":
                if base in ANCHORED:
                    text = water_source(text, [ANCHOR])
                if water:
                    text = water_source(text, water)
            texts[rename_text(rel, base, name).replace(os.sep, "/")] = rename_text(text, base, name)
        if level is not None:
            texts = venuebake().source_files(texts, level, name, bare=release_install())
            for rel, data in level.files.items():
                out[os.path.join(LEVELS, name, rel)] = data
        for rel, text in texts.items():
            out[os.path.join(LEVELS, name, rel)] = text.encode("utf-8")
        body = ground_body(uv_body(soft64_body(base_body(base), base), base), ground)
        body = water_body(body, water)
        body = entry_body(body, world)
        new = rename_body(body, base, name)
        if rename_body(new, name, base) != body:
            raise SystemExit("%s does not round-trip back to %s" % (name, base))
        if base_pattern(base).search(new.decode("latin-1")):
            raise SystemExit("%s still carries a %s name" % (name, base))
        if level is not None:
            new = venuebake().bake_body(new, level, name)
        out[os.path.join(LEVELS, "level_%s_entry.lvl" % name)] = write_lvl(new)
    return out
def same_lvl(path, data):
    try:
        return read_lvl(path) == zlib.decompress(data[16:])
    except (OSError, SystemExit, zlib.error):
        return False
def leftovers(plan):
    out = []
    for row in generated_venues():
        folder = os.path.join(LEVELS, row[1])
        if not os.path.isdir(folder):
            continue
        for path in (os.path.join(folder, rel) for rel in folder_files(row[1])):
            if path not in plan:
                out.append(path)
    return out
def main(argv):
    check = "--check" in argv
    stale = []
    plan = planned()
    for path in leftovers(plan):
        stale.append(os.path.relpath(path, MOD))
        if not check:
            os.remove(path)
    for path, data in sorted(plan.items()):
        if path.endswith(".lvl"):
            current = os.path.isfile(path) and same_lvl(path, data)
        else:
            current = os.path.isfile(path) and _slurp(path) == data
        if current:
            continue
        stale.append(os.path.relpath(path, MOD))
        if not check:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(data)
    if check:
        laid = uv_problems()
        for line in laid:
            print("make-venue-levels: " + line)
        if laid:
            return 1
        if stale:
            print("make-venue-levels: stale - run tools/make-venue-levels.py:")
            for path in stale:
                print("  " + path)
            return 1
        print("make-venue-levels: %d venue level(s) current, each its own script"
              % len(VENUES + generated_venues()))
        return 0
    print("make-venue-levels: wrote %d file(s)" % len(stale))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
