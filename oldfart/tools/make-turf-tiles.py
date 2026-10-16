#!/usr/bin/env python3
import importlib.util
import os
import re
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
TEMPLATE = os.path.join(ACTORS, "of_flood_plane_geo.bin")
TEAMS = os.path.join(ROOT, "of_teams.lua")
TURF = os.path.join(ROOT, "of_gm_turf.lua")
_spec = importlib.util.spec_from_file_location(
    "make_blocks", os.path.join(HERE, "make-blocks.py"))
blocks = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(blocks)
Refused = blocks.Refused
POINTER, FUNCTION, LUA_VAR = blocks.POINTER, blocks.FUNCTION, blocks.LUA_VAR
UNIT = 100
ALPHA = 140
SIDES = ("red", "blue")
GEO_NODE_START, GEO_OPEN_NODE, GEO_CLOSE_NODE, GEO_END = 0x0B, 0x04, 0x05, 0x01
GEO_DISPLAY_LIST_XLU = 0x15 | (5 << 8)
G_VTX, G_TRI1, G_TRI2 = 0x01, 0x05, 0x06
G_DL, G_ENDDL, G_GEOMETRYMODE = 0xDE, 0xDF, 0xD9
G_RDPPIPESYNC, G_SETCOMBINE, G_SETENVCOLOR = 0xE7, 0xFC, 0xFB
G_CULL_BACK, G_LIGHTING = 0x00000400, 0x00020000
def combine(a0, b0, c0, d0, aa0, ab0, ac0, ad0, a1, b1, c1, d1, aa1, ab1, ac1, ad1):
    w0 = ((G_SETCOMBINE << 24) | ((a0 & 0xF) << 20) | ((c0 & 0x1F) << 15)
          | ((aa0 & 7) << 12) | ((ac0 & 7) << 9) | ((a1 & 0xF) << 5) | (c1 & 0x1F))
    w1 = (((b0 & 0xF) << 28) | ((b1 & 0xF) << 24) | ((aa1 & 7) << 21)
          | ((ac1 & 7) << 18) | ((d0 & 7) << 15) | ((ab0 & 7) << 12)
          | ((ad0 & 7) << 9) | ((d1 & 7) << 6) | ((ab1 & 7) << 3) | (ad1 & 7))
    return w0, w1
ZERO, AZERO, ENV, SHADE = 31, 7, 5, 4
CC_ENV = combine(ZERO, ZERO, ZERO, ENV, AZERO, AZERO, AZERO, ENV,
                 ZERO, ZERO, ZERO, ENV, AZERO, AZERO, AZERO, ENV)
CC_SHADE = combine(ZERO, ZERO, ZERO, SHADE, AZERO, AZERO, AZERO, SHADE,
                   ZERO, ZERO, ZERO, SHADE, AZERO, AZERO, AZERO, SHADE)
def geometry(clear, set_):
    return (G_GEOMETRYMODE << 24) | (~clear & 0xFFFFFF), set_
def read_nodes(raw, where):
    i = 0
    nodes = []
    def take(n):
        nonlocal i
        if i + n > len(raw):
            raise Refused("%s: runs off the end at %d" % (where, i))
        chunk = raw[i:i + n]
        i += n
        return chunk
    def name():
        return take(take(1)[0]).decode("ascii")
    def u32():
        return struct.unpack("<I", take(4))[0]
    def value(v):
        if v == POINTER:
            return ("ptr", name(), u32())
        if v == FUNCTION:
            return ("fn", struct.unpack("<i", take(4))[0])
        if v == LUA_VAR:
            return ("lua", name())
        return v
    while i < len(raw):
        kind = take(1)[0]
        label = name()
        if kind == 1:
            nodes.append((kind, label, take(24)))
        elif kind == 2:
            count = struct.unpack("<i", take(4))[0]
            if count == blocks.TEX_REF:
                nodes.append((kind, label, ("ref", name())))
            else:
                nodes.append((kind, label, take(max(count, 0))))
        elif kind == 3:
            nodes.append((kind, label, [struct.unpack("<3hHhh4B", take(16))
                                        for _ in range(u32())]))
        elif kind == 4:
            body = []
            for _ in range(u32()):
                w0 = u32()
                body.append((w0, value(u32())))
            nodes.append((kind, label, body))
        elif kind == 5:
            nodes.append((kind, label, [value(u32()) for _ in range(u32())]))
        else:
            raise Refused("%s: node type %d is not part of a flat plate"
                          % (where, kind))
    return nodes
RETIRED_TEMPLATE = "of_flood_" + "plate_geo.bin"
FLOOD = os.path.join(ROOT, "of_gm_flood.lua")
def flood_uv_vtx():
    with open(FLOOD, encoding="utf-8") as handle:
        match = re.search(r'local PLATE_UV_VTX = "([^"]+)"', handle.read())
    if match is None:
        raise Refused("of_gm_flood.lua: no PLATE_UV_VTX")
    return match.group(1)
def read_template():
    where = os.path.relpath(TEMPLATE, ROOT)
    with open(TEMPLATE, "rb") as handle:
        nodes = read_nodes(blocks.unpack_bin(handle.read(), where), where)
    verts = [n for n in nodes if n[0] == 3]
    geos = [n for n in nodes if n[0] == 5]
    if len(verts) != 1 or len(verts[0][2]) != 4:
        raise Refused("%s: not one quad" % where)
    quad = verts[0][2]
    if any(v[1] != 0 for v in quad):
        raise Refused("%s: the quad is not flat (y = %s)"
                      % (where, [v[1] for v in quad]))
    if len(geos) != 1:
        raise Refused("%s: %d geo layouts, a plate has one" % (where, len(geos)))
    if os.path.exists(os.path.join(ACTORS, RETIRED_TEMPLATE)):
        raise Refused("actors/%s is back; the flood actor is %s"
                      % (RETIRED_TEMPLATE, os.path.basename(TEMPLATE)))
    want_geo = os.path.splitext(os.path.basename(TEMPLATE))[0]
    if geos[0][1] != want_geo:
        raise Refused("%s: the geo root is named %r, not %r"
                      % (where, geos[0][1], want_geo))
    want_vtx = flood_uv_vtx()
    if verts[0][1] != want_vtx:
        raise Refused("%s: the vertex buffer is named %r, of_gm_flood.lua's"
                      " PLATE_UV_VTX asks for %r" % (where, verts[0][1], want_vtx))
    geo = geos[0][2]
    shape = [GEO_NODE_START, GEO_OPEN_NODE, GEO_DISPLAY_LIST_XLU, "ptr",
             GEO_CLOSE_NODE, GEO_END]
    got = [w[0] if isinstance(w, tuple) else w for w in geo]
    if got != shape:
        raise Refused("%s: the geo layout is not one layer-5 display list: %s"
                      % (where, geo))
    tris = [n for n in nodes if n[0] == 4 and any(
        isinstance(w1, tuple) and w1[0] == "ptr" and w1[1] == verts[0][1]
        for _, w1 in n[2])]
    if len(tris) != 1:
        raise Refused("%s: no single display list draws the quad" % where)
    load = [(w0, w1) for w0, w1 in tris[0][2] if w0 >> 24 == G_VTX]
    faces = [(w0, w1) for w0, w1 in tris[0][2] if w0 >> 24 in (G_TRI1, G_TRI2)]
    if len(load) != 1 or not faces:
        raise Refused("%s: the quad's display list is not one load and its"
                      " triangles" % where)
    return quad, load[0][0], faces
def team_colours():
    with open(TEAMS, encoding="utf-8") as handle:
        text = handle.read()
    out = {}
    for side in SIDES:
        match = re.search(r'\{\s*key\s*=\s*"%s".*?r\s*=\s*(\d+),\s*g\s*=\s*(\d+),'
                          r'\s*b\s*=\s*(\d+)' % side, text)
        if match is None:
            raise Refused("of_teams.lua: no %s row with r, g, b" % side)
        out[side] = tuple(int(x) for x in match.groups())
    return out
def turf_unit():
    with open(TURF, encoding="utf-8") as handle:
        match = re.search(r"^local FILL_UNIT = (\d+)", handle.read(), re.M)
    return int(match.group(1)) if match else None
def geo_name(side):
    return "of_turf_%s_geo" % side
def build_one(side, colour, quad, load_w0, faces):
    prefix = "of_turf_%s_" % side
    half = UNIT // 2
    pieces = []
    def header(kind, label):
        pieces.append(bytes([kind]))
        pieces.append(("name", label))
    def u32(v):
        pieces.append(struct.pack("<I", v))
    def ptr(label):
        u32(POINTER)
        pieces.append(("name", label))
        u32(0)
    def dl(label, commands):
        header(4, label)
        u32(len(commands))
        for w0, w1 in commands:
            u32(w0)
            if isinstance(w1, str):
                ptr(w1)
            else:
                u32(w1)
    vtx, mat, tri = prefix + "vtx", prefix + "mat", prefix + "tri"
    revert, main = prefix + "revert", prefix + "dl"
    r, g, b = colour
    no_cull = geometry(G_CULL_BACK | G_LIGHTING, 0)
    dl(mat, [(G_RDPPIPESYNC << 24, 0), CC_ENV, no_cull,
             (G_SETENVCOLOR << 24, (r << 24) | (g << 16) | (b << 8) | ALPHA),
             (G_ENDDL << 24, 0)])
    header(3, vtx)
    u32(len(quad))
    for x, _, z, _, _, _, _, _, _, _ in quad:
        sx = half if x > 0 else -half
        sz = half if z > 0 else -half
        pieces.append(struct.pack("<3hHhh4B", sx, 0, sz, 0, 0, 0, 0, 127, 0, 255))
    dl(tri, [(load_w0, vtx)] + [(w0, w1) for w0, w1 in faces]
       + [(G_ENDDL << 24, 0)])
    dl(revert, [(G_RDPPIPESYNC << 24, 0), geometry(0, G_CULL_BACK | G_LIGHTING),
                CC_SHADE, (G_SETENVCOLOR << 24, 0xFFFFFFFF),
                (G_ENDDL << 24, 0)])
    dl(main, [(G_DL << 24, mat), (G_DL << 24, tri), (G_DL << 24, revert),
              (G_ENDDL << 24, 0)])
    header(5, geo_name(side))
    u32(6)
    u32(GEO_NODE_START)
    u32(GEO_OPEN_NODE)
    u32(GEO_DISPLAY_LIST_XLU)
    ptr(main)
    u32(GEO_CLOSE_NODE)
    u32(GEO_END)
    return blocks.pack_bin(blocks.emit(pieces))
def build():
    quad, load_w0, faces = read_template()
    colours = team_colours()
    return {geo_name(side) + ".bin": build_one(side, colours[side], quad,
                                                load_w0, faces)
            for side in SIDES}
def main(argv):
    check = "--check" in argv
    try:
        files = build()
        unit = turf_unit()
        if unit != UNIT:
            raise Refused("of_gm_turf.lua's FILL_UNIT is %s, the model is %d"
                          % (unit, UNIT))
    except Refused as why:
        print("make-turf-tiles: %s" % why)
        return 1
    differ = []
    for name, data in sorted(files.items()):
        path = os.path.join(ACTORS, name)
        have = open(path, "rb").read() if os.path.exists(path) else None
        if have != data:
            differ.append(name)
    if check:
        if differ:
            print("make-turf-tiles: %d actor(s) out of date, first %s"
                  % (len(differ), differ[0]))
            print("run tools/make-turf-tiles.py to rebuild them")
            return 1
        print("make-turf-tiles: %d tiles, all current" % len(files))
        return 0
    for name in differ:
        with open(os.path.join(ACTORS, name), "wb") as handle:
            handle.write(files[name])
    print("make-turf-tiles: %d tiles, %d bytes; %d written"
          % (len(files), sum(len(d) for d in files.values()), len(differ)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
