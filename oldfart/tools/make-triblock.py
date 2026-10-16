#!/usr/bin/env python3
import importlib.util
import os
import re
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
SPAWNER = os.path.join(ROOT, "of_spawner.lua")
_spec = importlib.util.spec_from_file_location(
    "make_turf_tiles", os.path.join(HERE, "make-turf-tiles.py"))
turf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(turf)
blocks = turf.blocks
Refused = turf.Refused
POINTER = turf.POINTER
GEO = "of_triblock_geo"
COL = "of_triblock_col"
WIDE, DEEP, TALL = 200, 200, 200
HW = WIDE // 2
PINK = (255, 120, 190, 255)
SIDE = (230, 90, 165, 255)
BACK = (190, 70, 140, 255)
FACE = (12, 10, 12, 255)
GEO_DISPLAY_LIST_OPA = 0x15 | (1 << 8)
DATA_TYPE_COLLISION = 11
COL_INIT, COL_TRI_STOP, COL_END = 0x40, 0x41, 0x42
SURFACE_DEFAULT = 0x0000
def corners(a, b, c, d):
    table = {(-1, -1): a, (1, -1): b, (1, 1): c, (-1, 1): d}
    return lambda sx, sz: table[(sx, sz)]
def on_slope(u, t, lift=2):
    z = DEEP * (1 - t)
    y = TALL * t
    n = (DEEP * DEEP + TALL * TALL) ** 0.5
    return (int(round(u)), int(round(y + lift * DEEP / n)), int(round(z + lift * TALL / n)))
def feature(cx, ct, half_u, half_t):
    a = on_slope(cx - half_u, ct - half_t)
    b = on_slope(cx + half_u, ct - half_t)
    c = on_slope(cx + half_u, ct + half_t)
    d = on_slope(cx - half_u, ct + half_t)
    return corners(a, b, c, d)
FACES = [
    ("pink", corners((-HW, 0, DEEP), (HW, 0, DEEP), (HW, TALL, 0), (-HW, TALL, 0))),
    ("side", corners((-HW, 0, 0), (-HW, 0, DEEP), (-HW, TALL, 0), (-HW, TALL, 0))),
    ("side", corners((HW, 0, 0), (HW, 0, DEEP), (HW, TALL, 0), (HW, TALL, 0))),
    ("back", corners((-HW, 0, 0), (HW, 0, 0), (HW, TALL, 0), (-HW, TALL, 0))),
    ("back", corners((-HW, 0, 0), (HW, 0, 0), (HW, 0, DEEP), (-HW, 0, DEEP))),
    ("face", feature(0, 0.36, 14, 0.15)),
    ("face", corners(on_slope(-44, 0.50), on_slope(44, 0.50),
                     on_slope(0, 0.80), on_slope(0, 0.80))),
]
LIP = 24
SOLID = [(-HW, 0, 0), (HW, 0, 0), (HW, 0, DEEP), (-HW, 0, DEEP),
         (-HW, TALL, 0), (HW, TALL, 0), (-HW, TALL, -LIP), (HW, TALL, -LIP)]
SOLID_TRIS = [
    (3, 2, 5), (3, 5, 4),
    (0, 1, 2), (0, 2, 3),
    (0, 4, 5), (0, 5, 1),
    (0, 3, 4),
    (1, 5, 2),
    (4, 5, 7), (4, 7, 6),
]
def spawner_numbers():
    with open(SPAWNER, encoding="utf-8") as handle:
        text = handle.read()
    found = {}
    for name in ("TRIBLOCK_WIDE", "TRIBLOCK_DEEP", "TRIBLOCK_TALL"):
        match = re.search(r"^\s*spawner\.%s\s*=\s*(\d+)" % name, text, re.M)
        found[name] = int(match.group(1)) if match else None
    return found
def normal(p1, p2, p3):
    x1, y1, z1 = p1
    x2, y2, z2 = p2
    x3, y3, z3 = p3
    return ((y2 - y1) * (z3 - z2) - (z2 - z1) * (y3 - y2),
            (z2 - z1) * (x3 - x2) - (x2 - x1) * (z3 - z2),
            (x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2))
def wound_out(tri):
    centre = [sum(p[k] for p in SOLID) / len(SOLID) for k in range(3)]
    pts = [SOLID[i] for i in tri]
    mid = [sum(p[k] for p in pts) / 3 for k in range(3)]
    n = normal(*pts)
    out = sum(n[k] * (mid[k] - centre[k]) for k in range(3))
    if out < 0:
        return (tri[0], tri[2], tri[1])
    return tri
def engine_first(tri):
    pts = [SOLID[i] for i in tri]
    n = normal(*pts)
    if n[1] > 0:
        want = max(p[1] for p in pts)
    elif n[1] < 0:
        want = min(p[1] for p in pts)
    else:
        return tri
    while SOLID[tri[0]][1] != want:
        tri = (tri[1], tri[2], tri[0])
    return tri
def build_geo():
    quad, load_w0, faces = turf.read_template()
    prefix = "of_triblock_"
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
    no_cull = turf.geometry(turf.G_CULL_BACK | turf.G_LIGHTING, 0)
    kinds = (("pink", PINK), ("side", SIDE), ("back", BACK), ("face", FACE))
    for kind, (r, g, b, a) in kinds:
        dl(prefix + kind, [(turf.G_RDPPIPESYNC << 24, 0), turf.CC_ENV, no_cull,
                           (turf.G_SETENVCOLOR << 24, (r << 24) | (g << 16) | (b << 8) | a),
                           (turf.G_ENDDL << 24, 0)])
    face_dls = []
    for index, (kind, place) in enumerate(FACES):
        vtx = "%svtx%d" % (prefix, index)
        tri = "%stri%d" % (prefix, index)
        header(3, vtx)
        u32(len(quad))
        for x, _, z, _, _, _, _, _, _, _ in quad:
            px, py, pz = place(1 if x > 0 else -1, 1 if z > 0 else -1)
            pieces.append(struct.pack("<3hHhh4B", px, py, pz, 0, 0, 0, 0, 127, 0, 255))
        dl(tri, [(load_w0, vtx)] + [(w0, w1) for w0, w1 in faces]
           + [(turf.G_ENDDL << 24, 0)])
        face_dls.append((kind, tri))
    revert, main = prefix + "revert", prefix + "dl"
    dl(revert, [(turf.G_RDPPIPESYNC << 24, 0),
                turf.geometry(0, turf.G_CULL_BACK | turf.G_LIGHTING),
                turf.CC_SHADE, (turf.G_SETENVCOLOR << 24, 0xFFFFFFFF),
                (turf.G_ENDDL << 24, 0)])
    commands = []
    for kind, _ in kinds:
        commands.append((turf.G_DL << 24, prefix + kind))
        for k, tri in face_dls:
            if k == kind:
                commands.append((turf.G_DL << 24, tri))
    commands.append((turf.G_DL << 24, revert))
    commands.append((turf.G_ENDDL << 24, 0))
    dl(main, commands)
    header(5, GEO)
    u32(6)
    u32(turf.GEO_NODE_START)
    u32(turf.GEO_OPEN_NODE)
    u32(GEO_DISPLAY_LIST_OPA)
    ptr(main)
    u32(turf.GEO_CLOSE_NODE)
    u32(turf.GEO_END)
    return blocks.pack_bin(blocks.emit(pieces))
def build_col():
    words = [COL_INIT, len(SOLID)]
    for x, y, z in SOLID:
        words += [x, y, z]
    words += [SURFACE_DEFAULT, len(SOLID_TRIS)]
    for tri in SOLID_TRIS:
        words += list(engine_first(wound_out(tri)))
    words += [COL_TRI_STOP, COL_END]
    name = COL.encode("ascii")
    raw = (bytes([DATA_TYPE_COLLISION]) + bytes([len(name)]) + name
           + struct.pack("<I", len(words)) + struct.pack("<%dh" % len(words), *words))
    return raw
def write(path, data, check, label):
    have = open(path, "rb").read() if os.path.exists(path) else None
    if check:
        if have != data:
            print("make-triblock: actors/%s is out of date" % label)
            return False
        return True
    if have != data:
        with open(path, "wb") as handle:
            handle.write(data)
    print("make-triblock: %s %d bytes; %s" % (label, len(data),
                                              "written" if have != data else "unchanged"))
    return True
def main(argv):
    check = "--check" in argv
    try:
        geo = build_geo()
        col = build_col()
        numbers = spawner_numbers()
        want = {"TRIBLOCK_WIDE": WIDE, "TRIBLOCK_DEEP": DEEP, "TRIBLOCK_TALL": TALL}
        for name, value in want.items():
            if numbers.get(name) != value:
                raise Refused("of_spawner.lua's %s is %s, the block is %s"
                              % (name, numbers.get(name), value))
    except Refused as why:
        print("make-triblock: %s" % why)
        return 1
    ok = write(os.path.join(ACTORS, GEO + ".bin"), geo, check, GEO + ".bin")
    ok = write(os.path.join(ACTORS, COL + ".col"), col, check, COL + ".col") and ok
    if check:
        if not ok:
            print("run tools/make-triblock.py to rebuild them")
            return 1
        print("make-triblock: the block is current")
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
