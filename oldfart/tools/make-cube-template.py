#!/usr/bin/env python3
import importlib.util
import os
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "of_cube_template.bin")
PREFIX = "of_cube_"
TILE = "cobblewarm"
TILE_SIZE = (32, 32)
AMBIENT = 0x50
DIFFUSE = 0xE6
LIGHT_DIR = (0x00, 0x6E, 0x3F)
W_PIPESYNC = 0xE7000000
W_TILESYNC = 0xE8000000
W_LOADSYNC = 0xE6000000
W_ENDDL = 0xDF000000
COMBINE = (0xFC127E24, 0xFFFFF9FC)
COMBINE_BACK = (0xFCFFFFFF, 0xFFFE793C)
SMOOTH_OFF = (0xD9DFFFFF, 0x00000000)
SMOOTH_ON = (0xD9FFFFFF, 0x00200000)
LOAD_TILE = (0xF5100000, 0x07000000)
TEXTURE_ON = (0xD7000002, 0xFFFFFFFF)
TEXTURE_OFF = (0xD7000000, 0xFFFFFFFF)
RENDER_TILE = (0xF5101000, 0x00094250)
TILE_SIZE_CMD = (0xF2000000, 0x0007C07C)
SETTIMG = 0xFD100000
LOADBLOCK = (0xF3000000, 0x073FF100)
LIGHT_MOVE = (0xDC08060A, 0xDC08090A)
DL_CALL, DL_BRANCH = 0xDE000000, 0xDE010000
CULL = 500
def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
def word(value):
    return ("word", value)
def pair(p):
    return [word(p[0]), word(p[1])]
def light_bytes():
    amb = bytes([AMBIENT] * 3)
    dif = bytes([DIFFUSE] * 3)
    return (amb + b"\0" + amb + b"\0" + dif + b"\0" + dif + b"\0"
            + bytes(c & 0xFF for c in LIGHT_DIR) + b"\0" + bytes(4))
def nodes():
    slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    host = _load("make_host_actors", "make-host-actors.py")
    faces = slopes.solid({"tag": "cube", "flip": False,
                          "faces": slopes.box_faces(slopes.LO, slopes.HI, 0, slopes.TOP,
                                                    slopes.LO, slopes.HI)})
    data, tris, count = b"", [], 0
    for pts, normal in faces:
        nb = slopes.normal_bytes(normal)
        base = count
        for p in pts:
            s, t = slopes.uv(p, normal)
            data += struct.pack("<3hHhh4B", p[0], p[1], p[2], 0, s, t, nb[0], nb[1], nb[2], 255)
            count += 1
        for k in range(1, len(pts) - 1):
            tris.append((base, base + k, base + k + 1))
    texture, light = PREFIX + "texture", PREFIX + "light"
    material, vertex = PREFIX + "material", PREFIX + "vertex0"
    shape, draw, geo = PREFIX + "shape", PREFIX + "draw", PREFIX + "geo"
    material_words = (pair((W_PIPESYNC, 0)) + pair(COMBINE) + pair(SMOOTH_OFF)
                      + pair(LOAD_TILE) + pair(TEXTURE_ON) + pair((W_TILESYNC, 0))
                      + pair(RENDER_TILE) + pair(TILE_SIZE_CMD) + pair((W_ENDDL, 0)))
    shape_words = [word(LIGHT_MOVE[0]), ("ptr", light, 1),
                   word(LIGHT_MOVE[1]), ("ptr", light, 2),
                   word(0x01000000 | (count << 12) | (count * 2)), ("ptr", vertex, 0)]
    for w0, w1 in slopes.tri_words(tris):
        shape_words += [word(w0), word(w1)]
    shape_words += (pair(TEXTURE_OFF) + pair((W_PIPESYNC, 0)) + pair(COMBINE_BACK)
                    + pair(SMOOTH_ON) + pair((W_ENDDL, 0)))
    draw_words = [word(DL_CALL), ("ptr", material, 0),
                  word(SETTIMG), ("ptr", texture, 0),
                  word(W_LOADSYNC), word(0),
                  word(LOADBLOCK[0]), word(LOADBLOCK[1]),
                  word(DL_BRANCH), ("ptr", shape, 0)]
    geo_words = [word((CULL << 16) | 0x20),
                 word(0x04),
                 word(0x0115), ("ptr", draw, 0),
                 word(0x05),
                 word(0x01)]
    def dl(name, words):
        return [4, name, [struct.pack("<I", len(words) // 2), ("words", words)]]
    return [
        dl(material, material_words),
        [2, texture, [("png", host.soft64_png(TILE, TILE_SIZE))]],
        [1, light, [light_bytes()]],
        [3, vertex, [struct.pack("<I", count), data]],
        dl(shape, shape_words),
        dl(draw, draw_words),
        [5, geo, [struct.pack("<I", len(geo_words)), ("words", geo_words)]],
    ], slopes
def inputs():
    import json
    host = _load("make_host_actors", "make-host-actors.py")
    with open(os.path.join(host.SOFT64_LIB, "library.json"), encoding="utf-8") as handle:
        tile = json.load(handle)[TILE]["file"]
    return [os.path.relpath(os.path.join(host.SOFT64_LIB, name), ROOT)
            for name in ("library.json", tile)]
def build():
    out, slopes = nodes()
    raw = slopes.write_nodes(out, lambda label: label)
    slopes.blocks.walk(raw, OUT)
    return slopes.blocks.pack_bin(raw)
def stale():
    if not os.path.exists(OUT):
        return "%s is missing" % os.path.relpath(OUT, ROOT)
    with open(OUT, "rb") as handle:
        if handle.read() != build():
            return "%s is stale; run tools/make-cube-template.py" % os.path.relpath(OUT, ROOT)
    return None
def main(argv):
    if "--check" in argv:
        why = stale()
        if why:
            print("make-cube-template: " + why)
            return 1
        print("make-cube-template: %s current" % os.path.relpath(OUT, ROOT))
        return 0
    data = build()
    with open(OUT, "wb") as handle:
        handle.write(data)
    print("make-cube-template: wrote %s (%d bytes)" % (os.path.relpath(OUT, ROOT), len(data)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
