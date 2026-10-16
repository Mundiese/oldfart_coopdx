#!/usr/bin/env python3
import importlib.util
import os
import re
import struct
import sys
import zlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
SOURCES = os.path.join(ROOT, "assets-incoming", "1003", "models")
HOST_BINS = os.path.join(SOURCES, "host-bins")
_spec = importlib.util.spec_from_file_location(
    "make_blocks", os.path.join(HERE, "make-blocks.py"))
blocks = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(blocks)
Refused = blocks.Refused
POINTER, FUNCTION, LUA_VAR = blocks.POINTER, blocks.FUNCTION, blocks.LUA_VAR
TEX_REF = blocks.TEX_REF
BALLOON_COLOURS = [
    ("red", None),
    ("white", (0xF2, 0xF2, 0xF2)),
    ("blue", (0x2F, 0x6F, 0xE8)),
    ("green", (0x3C, 0xC2, 0x4A)),
    ("yellow", (0xF5, 0xC7, 0x26)),
    ("orange", (0xFF, 0x6E, 0x0A)),
    ("purple", (0x8E, 0x3C, 0xD6)),
    ("pink", (0xFF, 0x7E, 0xC8)),
    ("cyan", (0x2E, 0xE0, 0xE6)),
    ("brown", (0x7A, 0x4A, 0x24)),
]
BALLOON_RED = (255, 7, 4)
HAMMER_HEAD_ENV = (40, 40, 44)
HAMMER_HEAD_AMBIENT = 0x7F
HAMMER_PIVOT_Y = 12
CCMUX = {"COMBINED": 0, "TEXEL0": 1, "TEXEL1": 2, "PRIMITIVE": 3, "SHADE": 4,
         "ENVIRONMENT": 5, "CENTER": 6, "SCALE": 6, "COMBINED_ALPHA": 7,
         "TEXEL0_ALPHA": 8, "TEXEL1_ALPHA": 9, "PRIMITIVE_ALPHA": 10,
         "SHADE_ALPHA": 11, "ENV_ALPHA": 12, "LOD_FRACTION": 13,
         "PRIM_LOD_FRAC": 14, "NOISE": 7, "K4": 7, "K5": 15, "1": 6, "0": 31}
ACMUX = {"COMBINED": 0, "TEXEL0": 1, "TEXEL1": 2, "PRIMITIVE": 3, "SHADE": 4,
         "ENVIRONMENT": 5, "LOD_FRACTION": 0, "PRIM_LOD_FRAC": 6, "1": 6,
         "0": 7}
CONST = {
    "G_IM_FMT_RGBA": 0, "G_IM_FMT_YUV": 1, "G_IM_FMT_CI": 2, "G_IM_FMT_IA": 3,
    "G_IM_FMT_I": 4, "G_IM_SIZ_4b": 0, "G_IM_SIZ_8b": 1, "G_IM_SIZ_16b": 2,
    "G_IM_SIZ_32b": 3, "G_IM_SIZ_8b_LOAD_BLOCK": 2, "G_IM_SIZ_16b_LOAD_BLOCK": 2,
    "G_TX_WRAP": 0, "G_TX_NOMIRROR": 0, "G_TX_MIRROR": 1, "G_TX_CLAMP": 2,
    "G_TX_NOMASK": 0, "G_TX_NOLOD": 0,
    "G_AD_PATTERN": 0x00, "G_AD_NOTPATTERN": 0x10, "G_AD_NOISE": 0x20,
    "G_AD_DISABLE": 0x30, "G_TT_NONE": 0, "G_TT_RGBA16": 0x8000,
    "G_TT_IA16": 0xC000, "G_AC_NONE": 0, "G_AC_THRESHOLD": 1, "G_AC_DITHER": 3,
    "G_LIGHTING": 0x00020000, "G_TEXTURE_GEN": 0x00040000,
    "G_SHADE": 0x00000004, "G_CULL_BACK": 0x00000400, "G_ZBUFFER": 0x00000001,
    "G_SHADING_SMOOTH": 0x00200000, "G_FOG": 0x00010000,
    "G_TEXTURE_GEN_LINEAR": 0x00080000, "G_CULL_FRONT": 0x00000200,
}
GEO_WORDS = {"GEO_NODE_START": 0x0B, "GEO_OPEN_NODE": 0x04,
             "GEO_CLOSE_NODE": 0x05, "GEO_END": 0x01}
LAYERS = {"LAYER_FORCE": 0, "LAYER_OPAQUE": 1, "LAYER_OPAQUE_DECAL": 2,
          "LAYER_OPAQUE_INTER": 3, "LAYER_ALPHA": 4, "LAYER_TRANSPARENT": 5,
          "LAYER_TRANSPARENT_DECAL": 6, "LAYER_TRANSPARENT_INTER": 7}
def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)
def split_args(body):
    out, depth, cur = [], 0, ""
    for ch in body:
        if ch == "(" or ch == "{":
            depth += 1
        elif ch == ")" or ch == "}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out
def macro_calls(body, where):
    calls = []
    i = 0
    while True:
        m = re.compile(r"\s*,?\s*([A-Za-z_]\w*)\s*\(").match(body, i)
        if m is None:
            if body[i:].strip(" \t\n,"):
                raise Refused("%s: cannot read %r" % (where, body[i:i + 40]))
            return calls
        depth, j = 1, m.end()
        while depth:
            if j >= len(body):
                raise Refused("%s: unbalanced brackets" % where)
            depth += {"(": 1, ")": -1}.get(body[j], 0)
            j += 1
        calls.append((m.group(1), split_args(body[m.end():j - 1])))
        i = j
def read_export(folder, prefix):
    text = ""
    for part in ("model.inc.c", "geo.inc.c"):
        path = os.path.join(folder, part)
        if not os.path.exists(path):
            raise Refused("%s: missing" % path)
        with open(path, encoding="utf-8") as handle:
            text += strip_comments(handle.read()) + "\n"
    arrays = {}
    for m in re.finditer(r"(?:const\s+)?(Lights1|u8|Vtx|Gfx|GeoLayout)\s+(\w+)"
                         r"\s*(\[\d*\])?\s*=\s*", text):
        kind, name = m.group(1), m.group(2)
        start = m.end()
        if text.startswith("gdSPDefLights1", start):
            end = text.index(";", start)
            call = macro_calls(text[start:end], name)[0]
            arrays[name] = ("lights", [int(a, 0) for a in call[1]])
            continue
        if text[start] != "{":
            raise Refused("%s: %s is not an array" % (folder, name))
        depth, j = 0, start
        while True:
            depth += {"{": 1, "}": -1}.get(text[j], 0)
            j += 1
            if depth == 0:
                break
        body = text[start + 1:j - 1]
        if name.endswith("_aligner"):
            continue
        if kind == "u8":
            arrays[name] = ("bytes", bytes(int(v, 0) for v in body.replace("\n", " ").split(",") if v.strip()))
        elif kind == "Vtx":
            rows = []
            for row in re.finditer(r"\{\{\s*\{([^}]*)\}\s*,\s*(\w+)\s*,\s*\{([^}]*)\}\s*,\s*\{([^}]*)\}\s*\}\}", body):
                pos = [int(v, 0) for v in row.group(1).split(",")]
                tc = [int(v, 0) for v in row.group(3).split(",")]
                col = [int(v, 0) for v in row.group(4).split(",")]
                rows.append(tuple(pos + [int(row.group(2), 0)] + tc + col))
            if m.group(3) and m.group(3) != "[]" and int(m.group(3)[1:-1]) != len(rows):
                raise Refused("%s: %s declares %s vertices, holds %d"
                              % (folder, name, m.group(3), len(rows)))
            arrays[name] = ("vtx", rows)
        elif kind == "Gfx":
            arrays[name] = ("gfx", macro_calls(body, name))
        else:
            arrays[name] = ("geo", macro_calls(body, name))
    roots = [n for n, (k, _) in arrays.items() if k == "geo"]
    if roots != [prefix + "geo"]:
        raise Refused("%s: geo roots %s, expected %sgeo" % (folder, roots, prefix))
    return arrays
def num(token, table=CONST):
    total = 0
    for part in token.split("|"):
        part = part.strip()
        if part in table:
            total |= table[part]
        else:
            try:
                total |= int(part, 0)
            except ValueError:
                raise Refused("unknown constant %s" % part)
    return total
def combine(args):
    if len(args) != 16:
        raise Refused("gsDPSetCombineLERP takes 16 arguments")
    c = [CCMUX[a] if i % 8 < 4 else ACMUX[a] for i, a in enumerate(args)]
    a0, b0, c0, d0, Aa0, Ab0, Ac0, Ad0, a1, b1, c1, d1, Aa1, Ab1, Ac1, Ad1 = c
    w0 = ((a0 & 15) << 20 | (c0 & 31) << 15 | (Aa0 & 7) << 12 | (Ac0 & 7) << 9
          | (a1 & 15) << 5 | (c1 & 31))
    w1 = ((b0 & 15) << 28 | (d0 & 7) << 15 | (Ab0 & 7) << 12 | (Ad0 & 7) << 9
          | (b1 & 15) << 24 | (Aa1 & 7) << 21 | (Ac1 & 7) << 18 | (d1 & 7) << 6
          | (Ab1 & 7) << 3 | (Ad1 & 7))
    return 0xFC000000 | w0, w1
def othermode(cmd, shift, length, value):
    return (cmd << 24) | ((32 - shift - length) << 8) | (length - 1), value
def pointer(token):
    m = re.fullmatch(r"(\w+)(?:\s*\+\s*(\d+))?", token.strip())
    if m is None:
        raise Refused("cannot read pointer %s" % token)
    return ("ptr", m.group(1), int(m.group(2) or 0))
def encode_gfx(name, args):
    if name == "gsSPSetLights1":
        light = args[0].strip()
        return [(0xDB020000, 0x18), (0xDC08060A, ("ptr", light, 1)),
                (0xDC08090A, ("ptr", light, 2))]
    if name == "gsDPPipeSync":
        return [(0xE7000000, 0)]
    if name == "gsSPEndDisplayList":
        return [(0xDF000000, 0)]
    if name == "gsDPSetCombineLERP":
        return [combine(args)]
    if name == "gsDPSetAlphaDither":
        return [othermode(0xE3, 4, 2, num(args[0]))]
    if name == "gsDPSetTextureLUT":
        return [othermode(0xE3, 14, 2, num(args[0]))]
    if name == "gsDPSetAlphaCompare":
        return [othermode(0xE2, 0, 2, num(args[0]))]
    if name == "gsSPTexture":
        s, t, level, tile, on = (num(a) for a in args)
        return [(0xD7000000 | (level & 7) << 11 | (tile & 7) << 8 | (on & 0x7F) << 1,
                 (s & 0xFFFF) << 16 | (t & 0xFFFF))]
    if name == "gsDPSetTextureImage":
        fmt, siz, width = num(args[0]), num(args[1]), num(args[2])
        return [(0xFD000000 | (fmt & 7) << 21 | (siz & 3) << 19 | ((width - 1) & 0xFFF),
                 pointer(args[3]))]
    if name == "gsDPSetTile":
        fmt, siz, line, tmem, tile, pal, cmt, maskt, shiftt, cms, masks, shifts = (num(a) for a in args)
        return [(0xF5000000 | (fmt & 7) << 21 | (siz & 3) << 19 | (line & 0x1FF) << 9 | (tmem & 0x1FF),
                 (tile & 7) << 24 | (pal & 15) << 20 | (cmt & 3) << 18 | (maskt & 15) << 14
                 | (shiftt & 15) << 10 | (cms & 3) << 8 | (masks & 15) << 4 | (shifts & 15))]
    if name == "gsDPLoadTLUTCmd":
        tile, count = num(args[0]), num(args[1])
        return [(0xF0000000, (tile & 7) << 24 | (count & 0x3FF) << 14)]
    if name == "gsDPLoadBlock":
        tile, uls, ult, lrs, dxt = (num(a) for a in args)
        return [(0xF3000000 | (uls & 0xFFF) << 12 | (ult & 0xFFF),
                 (tile & 7) << 24 | (min(lrs, 0x7FF) & 0xFFF) << 12 | (dxt & 0xFFF))]
    if name == "gsDPSetTileSize":
        tile, uls, ult, lrs, lrt = (num(a) for a in args)
        return [(0xF2000000 | (uls & 0xFFF) << 12 | (ult & 0xFFF),
                 (tile & 7) << 24 | (lrs & 0xFFF) << 12 | (lrt & 0xFFF))]
    if name == "gsSPVertex":
        ptr = pointer(args[0])
        n, v0 = num(args[1]), num(args[2])
        return [(0x01000000 | (n & 0xFF) << 12 | ((v0 + n) & 0x7F) << 1, ptr)]
    if name == "gsSP1Triangle":
        a, b, c, flag = (num(x) for x in args)
        if flag != 0:
            raise Refused("gsSP1Triangle with flag %d" % flag)
        return [(0x05000000 | (a * 2) << 16 | (b * 2) << 8 | (c * 2), 0)]
    if name == "gsSP2Triangles":
        a, b, c, f0, d, e, f, f1 = (num(x) for x in args)
        if f0 or f1:
            raise Refused("gsSP2Triangles with a flag")
        return [(0x06000000 | (a * 2) << 16 | (b * 2) << 8 | (c * 2),
                 (d * 2) << 16 | (e * 2) << 8 | (f * 2))]
    if name == "gsSPDisplayList":
        return [(0xDE000000, pointer(args[0]))]
    if name == "gsSPSetGeometryMode":
        return [(0xD9FFFFFF, num(args[0]))]
    if name == "gsSPClearGeometryMode":
        return [(0xD9000000 | (~num(args[0]) & 0xFFFFFF), 0)]
    if name == "gsDPSetEnvColor":
        r, g, b, a = (num(x) & 0xFF for x in args)
        return [(0xFB000000, r << 24 | g << 16 | b << 8 | a)]
    raise Refused("display list command %s is not one this tool knows" % name)
def encode_geo(name, args):
    if name in GEO_WORDS:
        return [GEO_WORDS[name]]
    if name == "GEO_DISPLAY_LIST":
        return [0x15 | (LAYERS[args[0].strip()] << 8), pointer(args[1])]
    raise Refused("geo command %s is not one this tool knows" % name)
def lights_bytes(args):
    ar, ag, ab, r, g, b, x, y, z = args
    return (bytes([ar, ag, ab, 0, ar, ag, ab, 0, r, g, b, 0, r, g, b, 0])
            + struct.pack("<3b", *[((v + 128) & 255) - 128 for v in (x, y, z)]) + b"\0" * 5)
def ci8_png(indices, palette, width, height):
    rgba = bytearray()
    for idx in indices[:width * height]:
        col = palette[idx * 2] << 8 | palette[idx * 2 + 1]
        r, g, b, a = (col >> 11) & 31, (col >> 6) & 31, (col >> 1) & 31, col & 1
        rgba += bytes([r * 255 // 31, g * 255 // 31, b * 255 // 31, 255 * a])
    rows = b"".join(b"\0" + bytes(rgba[y * width * 4:(y + 1) * width * 4])
                    for y in range(height))
    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body
                + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF))
    return (blocks.PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))
def convert(arrays, root):
    nodes, done = [], set()
    textures = {}
    palettes = []
    def visit(name):
        if name in done:
            return
        if name not in arrays:
            raise Refused("%s is referenced and not defined" % name)
        done.add(name)
        kind, body = arrays[name]
        if kind == "lights":
            nodes.append((1, name, lights_bytes(body)))
        elif kind == "bytes":
            textures[name] = {"fmt": None, "siz": None, "w": None, "h": None}
            nodes.append((2, name, None))
        elif kind == "vtx":
            nodes.append((3, name, list(body)))
        elif kind == "gfx":
            words = []
            current = None
            for macro, args in body:
                for w0, w1 in encode_gfx(macro, args):
                    if isinstance(w1, tuple):
                        visit(w1[1])
                    words.append((w0, w1))
                if macro == "gsDPSetTextureImage":
                    current = pointer(args[3])[1]
                    textures[current]["fmt"] = num(args[0])
                    textures[current]["siz"] = num(args[1])
                elif macro == "gsDPSetTile" and current:
                    textures[current]["fmt"] = num(args[0])
                    textures[current]["siz"] = num(args[1])
                elif macro == "gsDPSetTileSize" and current:
                    textures[current]["w"] = (num(args[3]) >> 2) + 1
                    textures[current]["h"] = (num(args[4]) >> 2) + 1
                elif macro == "gsDPLoadTLUTCmd" and current:
                    palettes.append(current)
            nodes.append((4, name, words))
        elif kind == "geo":
            words = []
            for macro, args in body:
                for word in encode_geo(macro, args):
                    if isinstance(word, tuple):
                        visit(word[1])
                    words.append(word)
            nodes.append((5, name, words))
    visit(root)
    if len(set(palettes)) > 1:
        raise Refused("more than one palette; one CI texture is supported")
    palette = palettes[0] if palettes else None
    out = []
    for kind, name, body in nodes:
        if kind == 2:
            info = textures[name]
            if name == palette:
                body = b""
            else:
                if info["fmt"] != 2 or info["siz"] != 1 or palette is None:
                    raise Refused("%s: only CI8 with a palette is supported" % name)
                body = ci8_png(arrays[name][1], arrays[palette][1], info["w"], info["h"])
        out.append((kind, name, body))
    return out
def emit(nodes):
    out = bytearray()
    def name(text):
        data = text.encode("ascii")
        if len(data) > 255:
            raise Refused("name too long: %s" % text)
        out.extend(bytes([len(data)]) + data)
    def word(value):
        if isinstance(value, tuple):
            out.extend(struct.pack("<I", POINTER))
            name(value[1])
            out.extend(struct.pack("<I", value[2]))
        else:
            out.extend(struct.pack("<I", value & 0xFFFFFFFF))
    for kind, label, body in nodes:
        out.append(kind)
        name(label)
        if kind == 1:
            out.extend(body)
        elif kind == 2:
            out.extend(struct.pack("<i", len(body)) + body)
        elif kind == 3:
            out.extend(struct.pack("<I", len(body)))
            for v in body:
                out.extend(struct.pack("<3hHhh4B", *v))
        elif kind == 4:
            out.extend(struct.pack("<I", len(body)))
            for w0, w1 in body:
                word(w0)
                word(w1)
        elif kind == 5:
            out.extend(struct.pack("<I", len(body)))
            for w in body:
                word(w)
    return blocks.pack_bin(bytes(out))
def decode(data, where):
    raw = blocks.unpack_bin(data, where)
    i, nodes = 0, []
    def take(n):
        nonlocal i
        if i + n > len(raw):
            raise Refused("%s: runs off the end" % where)
        chunk = raw[i:i + n]
        i += n
        return chunk
    def name():
        return take(take(1)[0]).decode("ascii")
    def u32():
        return struct.unpack("<I", take(4))[0]
    def value():
        v = u32()
        if v == POINTER:
            return ("ptr", name(), u32())
        if v in (FUNCTION, LUA_VAR):
            raise Refused("%s: function or Lua reference in a host actor" % where)
        return v
    while i < len(raw):
        kind, label = take(1)[0], name()
        if kind == 1:
            nodes.append((1, label, take(24)))
        elif kind == 2:
            count = struct.unpack("<i", take(4))[0]
            if count == TEX_REF:
                raise Refused("%s: texture reference" % where)
            png = take(count)
            nodes.append((2, label, blocks.png_pixels(png, label) if png else b""))
        elif kind == 3:
            nodes.append((3, label, [struct.unpack("<3hHhh4B", take(16)) for _ in range(u32())]))
        elif kind == 4:
            nodes.append((4, label, [(value(), value()) for _ in range(u32())]))
        elif kind == 5:
            nodes.append((5, label, [value() for _ in range(u32())]))
        else:
            raise Refused("%s: node type %d" % (where, kind))
    return nodes
def find(nodes, kind, label):
    for i, (k, n, _) in enumerate(nodes):
        if k == kind and n == label:
            return i
    raise Refused("no node %s" % label)
def env_word(rgb, alpha=255):
    r, g, b = rgb
    return (0xFB000000, r << 24 | g << 16 | b << 8 | alpha)
def black_head(nodes):
    nodes = list(nodes)
    li = find(nodes, 1, "of_hammer_f3dlite_material_003_lights")
    light = bytearray(nodes[li][2])
    light[0:3] = light[4:7] = bytes([HAMMER_HEAD_AMBIENT] * 3)
    nodes[li] = (1, nodes[li][1], bytes(light))
    mi = find(nodes, 4, "mat_of_hammer_f3dlite_material_003")
    words = list(nodes[mi][2])
    cc = combine(["ENVIRONMENT", "0", "SHADE", "0", "0", "0", "0", "ENVIRONMENT"] * 2)
    at = [j for j, (w0, _) in enumerate(words) if w0 >> 24 == 0xFC]
    if len(at) != 1:
        raise Refused("the hammer head's material has %d combiners" % len(at))
    words[at[0]] = cc
    words.insert(len(words) - 1, env_word(HAMMER_HEAD_ENV))
    nodes[mi] = (4, nodes[mi][1], words)
    return nodes
def translate_words(x, y, z, layer=1):
    return [0x11 | (layer & 0xFF) << 8 | (x & 0xFFFF) << 16, (y & 0xFFFF) | (z & 0xFFFF) << 16]
def pivot_hammer(nodes):
    nodes = list(nodes)
    gi = find(nodes, 5, "of_hammer_geo")
    words = list(nodes[gi][2])
    start, open_ = GEO_WORDS["GEO_NODE_START"], GEO_WORDS["GEO_OPEN_NODE"]
    close, end = GEO_WORDS["GEO_CLOSE_NODE"], GEO_WORDS["GEO_END"]
    if len(words) != 6 or words[:2] != [start, open_] or words[4:] != [close, end]:
        raise Refused("the hammer's geo is not one display list under the root")
    nodes[gi] = (5, nodes[gi][1], words[:2] + translate_words(0, -HAMMER_PIVOT_Y, 0)
                 + [open_] + words[2:4] + [close] + words[4:])
    return nodes
def recolour(nodes, rgb, old_prefix, new_prefix):
    out = []
    hits = 0
    def rename(text):
        return new_prefix + text[len(old_prefix):] if text.startswith(old_prefix) else text
    for kind, label, body in nodes:
        label = rename(label.replace("mat_" + old_prefix, "mat_" + new_prefix)
                       .replace("mat_revert_" + old_prefix, "mat_revert_" + new_prefix))
        if kind in (4, 5):
            new = []
            for item in body:
                pair = item if kind == 4 else (item,)
                fixed = []
                for w in pair:
                    if isinstance(w, tuple):
                        target = w[1]
                        target = target.replace("mat_revert_" + old_prefix, "mat_revert_" + new_prefix)
                        target = target.replace("mat_" + old_prefix, "mat_" + new_prefix)
                        w = ("ptr", rename(target), w[2])
                    fixed.append(w)
                new.append(tuple(fixed) if kind == 4 else fixed[0])
            body = new
            if kind == 4 and rgb is not None and label.startswith("mat_") and "revert" not in label:
                for j, (w0, w1) in enumerate(body):
                    if w0 == 0xFB000000 and w1 >> 8 == (BALLOON_RED[0] << 16 | BALLOON_RED[1] << 8 | BALLOON_RED[2]):
                        body[j] = env_word(rgb, w1 & 255)
                        hits += 1
        out.append((kind, label, body))
    if rgb is not None and hits != 1:
        raise Refused("the balloon's material has %d red env colours, not one" % hits)
    return out
SOFT64_LIB = os.path.join(ROOT, "assets-incoming", "1006", "textures")
HAMMER_TEXTURE = ("of_hammer_Texture0115_RGB_ci8", "beamoak")
BALL_TEXTURE = ("of_ball_Texture0326_RGB_ci8", "treadplate")
def soft64_png(key, size):
    import io
    import json
    from PIL import Image
    with open(os.path.join(SOFT64_LIB, "library.json"), encoding="utf-8") as handle:
        path = os.path.join(SOFT64_LIB, json.load(handle)[key]["file"])
    im = Image.open(path).convert("RGBA")
    if im.size != size:
        im = im.resize(size, Image.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return buf.getvalue()
def png_size(png):
    return struct.unpack(">II", png[16:24])
def soft64_nodes(nodes, label, key):
    nodes = list(nodes)
    ti = find(nodes, 2, label)
    nodes[ti] = (2, label, soft64_png(key, png_size(nodes[ti][2])))
    return nodes
def soft64_bin(data, label, key, where):
    raw = blocks.unpack_bin(data, where)
    name = label.encode("ascii")
    at = raw.find(bytes([2, len(name)]) + name)
    if at < 0:
        raise Refused("%s: no texture node %s" % (where, label))
    start = at + 2 + len(name)
    count = struct.unpack("<i", raw[start:start + 4])[0]
    old = raw[start + 4:start + 4 + count]
    png = soft64_png(key, png_size(old))
    return blocks.pack_bin(raw[:start] + struct.pack("<i", len(png)) + png + raw[start + 4 + count:])
def plain(name):
    arrays = read_export(os.path.join(SOURCES, name), name + "_")
    return convert(arrays, name + "_geo")
def builds():
    out = [("of_hammer_geo", soft64_nodes(pivot_hammer(black_head(plain("of_hammer"))),
                                          *HAMMER_TEXTURE))]
    balloon = plain("of_balloon")
    for colour, rgb in BALLOON_COLOURS:
        if rgb is None:
            out.append(("of_balloon_geo", balloon))
        else:
            out.append(("of_balloon_%s_geo" % colour,
                        recolour(balloon, rgb, "of_balloon_", "of_balloon_%s_" % colour)))
    return out
def comparable(nodes):
    out = []
    for kind, label, body in nodes:
        if kind == 2 and body:
            body = blocks.png_pixels(body, label) if isinstance(body, bytes) else body
        out.append((kind, label, body))
    return out
def prove_against_host():
    for name in ("of_hammer", "of_balloon"):
        path = os.path.join(HOST_BINS, name + "_geo.bin")
        with open(path, "rb") as handle:
            host = decode(handle.read(), path)
        ours = comparable(plain(name))
        if [(k, n) for k, n, _ in host] != [(k, n) for k, n, _ in ours]:
            raise Refused("%s: node order differs from the reference bin:\n  reference %s\n  ours %s"
                          % (name, [n for _, n, _ in host], [n for _, n, _ in ours]))
        for (k, n, a), (_, _, b) in zip(host, ours):
            if a != b:
                raise Refused("%s: node %s differs from the reference bin" % (name, n))
    return True
def main(argv):
    check = "--check" in argv
    try:
        prove_against_host()
        out = [(stem, emit(nodes)) for stem, nodes in builds()]
        ball = os.path.join(ACTORS, "of_ball_geo.bin")
        with open(ball, "rb") as handle:
            out.append(("of_ball_geo", soft64_bin(handle.read(), *BALL_TEXTURE, where=ball)))
        for stem, data in out:
            decode(data, stem)
    except Refused as why:
        print("make-host-actors: %s" % why)
        return 1
    stale = []
    for stem, data in out:
        path = os.path.join(ACTORS, stem + ".bin")
        have = open(path, "rb").read() if os.path.exists(path) else None
        if have != data:
            stale.append(stem)
            if not check:
                with open(path, "wb") as handle:
                    handle.write(data)
    if check:
        if stale:
            print("make-host-actors: out of date: %s" % ", ".join(stale))
            print("run tools/make-host-actors.py to rebuild them")
            return 1
        print("make-host-actors: %d actors current; the plain conversion equals the reference bins"
              % len(out))
        return 0
    print("make-host-actors: %d actors, %d written; the plain conversion equals the reference bins"
          % (len(out), len(stale)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
