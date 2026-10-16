#!/usr/bin/env python3
import importlib.util
import math
import os
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
LUA = os.path.join(ROOT, "of_venues.lua")
PICTURES = os.path.join(ROOT, "docs", "arenas")
_spec = importlib.util.spec_from_file_location(
    "make_forgeslopes", os.path.join(HERE, "make-forgeslopes.py"))
slopes = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(slopes)
blocks = slopes.blocks
Refused = blocks.Refused
PREFIX = "of_ak_"
BEGIN = "-- BEGIN LAYOUTS (written by tools/make-arenas.py - edit the tool, not these lines)"
END = "-- END LAYOUTS"
SURFACE_DEFAULT = 0x0000
SURFACE_NOT_SLIPPERY = 0x0015
TEXEL_SPAN = 200
TEX_PX = 32
LONGEST_FACE = (1023 // TEX_PX) * TEXEL_SPAN
SETTILE_W0 = 0xF5101000
SETTILE_CLAMP = 0x00094250
SETTILE_WRAP = SETTILE_CLAMP & ~((2 << 8) | (2 << 18))
BOUND = 30000
MARIO_TALL = 160
STEP_UP = 50
JUMP_UP = 200
SURVEY_POINTS_MAX = 256 // 9
SAFE_DROP = 1100
GRID = 100
LEVELS = {
    "empty":  {"floor": 0, "half": 15000, "plane": -6000},
    "empty2": {"floor": None, "half": 17500, "plane": -6000},
}
def box(tex, x0, x1, y0, y1, z0, z1, tag=""):
    return {"kind": "box", "tex": tex, "x": (x0 + x1) / 2, "y": y0,
            "z": (z0 + z1) / 2, "w": x1 - x0, "h": y1 - y0, "d": z1 - z0,
            "yaw": 0, "tag": tag}
RISES = {"-z": 0, "-x": 90, "+z": 180, "+x": 270}
def ramp(tex, x0, x1, z0, z1, y0, y1, rises, tag=""):
    yaw = RISES[rises]
    along_x = rises in ("-x", "+x")
    w = (z1 - z0) if along_x else (x1 - x0)
    d = (x1 - x0) if along_x else (z1 - z0)
    return {"kind": "ramp", "tex": tex, "x": (x0 + x1) / 2, "y": y0,
            "z": (z0 + z1) / 2, "w": w, "h": y1 - y0, "d": d, "yaw": yaw,
            "tag": tag}
STAIR_STEPS = 10
STAIR_RISER_MAX = 28
def stairs(tex, x0, x1, z0, z1, y0, y1, rises, tag=""):
    piece = ramp(tex, x0, x1, z0, z1, y0, y1, rises, tag)
    piece["kind"] = "stairs"
    return piece
CORNERS = {"-x-z": 0, "-x+z": 90, "+x+z": 180, "+x-z": 270}
def ramp_corner(tex, x0, x1, z0, z1, y0, y1, high, inner=False, tag=""):
    yaw = CORNERS[high]
    sideways = yaw in (90, 270)
    w = (z1 - z0) if sideways else (x1 - x0)
    d = (x1 - x0) if sideways else (z1 - z0)
    return {"kind": "inner" if inner else "outer", "tex": tex, "x": (x0 + x1) / 2, "y": y0,
            "z": (z0 + z1) / 2, "w": w, "h": y1 - y0, "d": d, "yaw": yaw, "tag": tag}
def corner_stairs(tex, x0, x1, z0, z1, y0, y1, high, inner=False, tag=""):
    piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, high, inner, tag)
    piece["kind"] = "innerstairs" if inner else "outerstairs"
    return piece
def slab(tex, x0, x1, z0, z1, y0, thick=100, tag=""):
    if thick not in SLAB_HEIGHTS:
        raise Refused("a slab is one of %s high, not %s" % (SLAB_HEIGHTS, thick))
    piece = box(tex, x0, x1, y0, y0 + thick, z0, z1, tag)
    return piece
SLAB_HEIGHTS = (20, 40, 100)
def _along(kind, tex, x0, x1, z0, z1, y0, y1, tag):
    if (x1 - x0) >= (z1 - z0):
        return {"kind": kind, "tex": tex, "x": (x0 + x1) / 2, "y": y0, "z": (z0 + z1) / 2,
                "w": x1 - x0, "h": y1 - y0, "d": z1 - z0, "yaw": 0, "tag": tag}
    return {"kind": kind, "tex": tex, "x": (x0 + x1) / 2, "y": y0, "z": (z0 + z1) / 2,
            "w": z1 - z0, "h": y1 - y0, "d": x1 - x0, "yaw": 90, "tag": tag}
def rail(tex, x0, x1, z0, z1, y0, high=160, tag=""):
    return _along("rail", tex, x0, x1, z0, z1, y0, y0 + high, tag)
RAIL_POST_EVERY = 200
def pillar(tex, x, z, y0, y1, width=200, tag=""):
    return {"kind": "pillar", "tex": tex, "x": x, "y": y0, "z": z, "w": width,
            "h": y1 - y0, "d": width, "yaw": 0, "tag": tag}
def arch(tex, x0, x1, z0, z1, y0, y1, tag=""):
    return _along("arch", tex, x0, x1, z0, z1, y0, y1, tag)
def prism(tex, x0, x1, z0, z1, y0, y1, solid_corner, tag=""):
    piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, solid_corner, tag=tag)
    piece["kind"] = "prism"
    return piece
def turned(piece, quarters):
    out = dict(piece)
    for _ in range(quarters % 4):
        out["x"], out["z"] = out["z"], -out["x"]
        out["yaw"] = (out["yaw"] + 90) % 360
    return out
def turned_point(point, quarters):
    out = dict(point)
    for _ in range(quarters % 4):
        out["x"], out["z"] = out["z"], -out["x"]
        out["yaw"] = (out.get("yaw", 0) + 90) % 360
    return out
def mirrored_z(thing):
    out = dict(thing)
    out["z"] = -out["z"]
    out["yaw"] = (180 - out.get("yaw", 0)) % 360
    return out
def footprint(piece):
    yaw = piece["yaw"] % 360
    if yaw not in (0, 90, 180, 270):
        raise Refused("%s: only quarter turns are laid by this tool" % piece_name(piece))
    w, d = piece["w"], piece["d"]
    if yaw in (90, 270):
        w, d = d, w
    x0, x1 = piece["x"] - w / 2, piece["x"] + w / 2
    z0, z1 = piece["z"] - d / 2, piece["z"] + d / 2
    s, c = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
    up = (round(-s), round(-c))
    return x0, x1, z0, z1, up
def piece_name(piece):
    return "%s %s at (%d, %d, %d)" % (piece["kind"], piece["tex"], piece["x"],
                                      piece["y"], piece["z"])
def local_of(piece, x, z):
    s, c = math.sin(math.radians(piece["yaw"])), math.cos(math.radians(piece["yaw"]))
    dx, dz = x - piece["x"], z - piece["z"]
    lx = (dx * c - dz * s) / piece["w"] * 200.0
    lz = (dx * s + dz * c) / piece["d"] * 200.0
    return lx, lz
def covers(piece, x, z):
    if piece["kind"] == "prism":
        lx, lz = local_of(piece, x, z)
        return lx + lz <= 1e-6
    if piece["kind"] == "pillar":
        lx, lz = local_of(piece, x, z)
        h, c = slopes.PILLAR_HALF, slopes.PILLAR_CUT
        return abs(lx) <= h and abs(lz) <= h and abs(lx) + abs(lz) <= h + c
    return True
def top_at(piece, x, z):
    x0, x1, z0, z1, up = footprint(piece)
    if not covers(piece, x, z):
        return None
    if piece["kind"] in FLAT_TOPPED:
        return piece["y"] + piece["h"]
    if piece["kind"] in ("outer", "inner", "outerstairs", "innerstairs"):
        lx, lz = local_of(piece, x, z)
        fx = max(0.0, min(1.0, (100 - lx) / 200.0))
        fz = max(0.0, min(1.0, (100 - lz) / 200.0))
        f = min(fx, fz) if piece["kind"] in ("outer", "outerstairs") else max(fx, fz)
        if piece["kind"].endswith("stairs"):
            step = min(STAIR_STEPS, int(f * STAIR_STEPS) + 1)
            return piece["y"] + piece["h"] * step / STAIR_STEPS
        return piece["y"] + piece["h"] * f
    if up[0] != 0:
        t = (x - x0) / (x1 - x0) if up[0] > 0 else (x1 - x) / (x1 - x0)
    else:
        t = (z - z0) / (z1 - z0) if up[1] > 0 else (z1 - z) / (z1 - z0)
    t = max(0.0, min(1.0, t))
    if piece["kind"] == "stairs":
        step = min(STAIR_STEPS, int(t * STAIR_STEPS) + 1)
        return piece["y"] + piece["h"] * step / STAIR_STEPS
    return piece["y"] + piece["h"] * t
FLAT_TOPPED = ("box", "rail", "pillar", "arch", "prism")
def model_name(piece):
    def n(v):
        return str(int(round(v)))
    return "%s%s_%s_%s_%s_%s_geo" % (PREFIX, piece["tex"], piece["kind"],
                                     n(piece["w"]), n(piece["h"]), n(piece["d"]))
LO, HI, TOP = -100, 100, 200
CORNER = {
    "A": (LO, 0, LO), "B": (HI, 0, LO), "C": (HI, 0, HI), "D": (LO, 0, HI),
    "E": (LO, TOP, LO), "F": (HI, TOP, LO), "G": (LO, TOP, HI), "H": (HI, TOP, HI),
}
SOLIDS = {
    "box": [
        ("EGHF", (0, 1, 0)), ("ABCD", (0, -1, 0)),
        ("ABFE", (0, 0, -1)), ("DCHG", (0, 0, 1)),
        ("ADGE", (-1, 0, 0)), ("BCHF", (1, 0, 0)),
    ],
    "ramp": [
        ("DCFE", (0, 1, 1)), ("ABFE", (0, 0, -1)), ("ABCD", (0, -1, 0)),
        ("ADE", (-1, 0, 0)), ("BCF", (1, 0, 0)),
    ],
    "stairs": slopes.stair_faces(),
    "outer": [(c, n) for c, n in slopes.SHAPES[1][3]],
    "inner": [(c, n) for c, n in slopes.SHAPES[2][3]],
    "pillar": slopes.pillar_faces(),
    "arch": slopes.arch_faces(),
    "prism": slopes.prism_faces(),
    "rail": slopes.box_faces(LO, HI, 0, TOP, LO, HI),
    "outerstairs": slopes.corner_stair_faces(False),
    "innerstairs": slopes.corner_stair_faces(True),
}
FLOORS = {"stairs": slopes.stair_floor_faces(),
          "outerstairs": slopes.corner_stair_floor_faces(False),
          "innerstairs": slopes.corner_stair_floor_faces(True)}
SURFACES = {"box": SURFACE_DEFAULT, "ramp": SURFACE_NOT_SLIPPERY,
            "stairs": SURFACE_NOT_SLIPPERY, "outer": SURFACE_NOT_SLIPPERY,
            "inner": SURFACE_NOT_SLIPPERY, "pillar": SURFACE_DEFAULT,
            "arch": SURFACE_DEFAULT, "prism": SURFACE_DEFAULT, "rail": SURFACE_DEFAULT,
            "outerstairs": SURFACE_NOT_SLIPPERY, "innerstairs": SURFACE_NOT_SLIPPERY}
def rail_faces(piece):
    w, h = piece["w"], piece["h"]
    def ux(v):
        return int(round(v / w * 200.0))
    def uy(v):
        return int(round(v / h * 200.0))
    n = max(1, int(round(w / RAIL_POST_EVERY)))
    post = max(1, ux(RAIL_POST / 2.0))
    faces = slopes.box_faces(LO, HI, 0, uy(RAIL_FOOT), -60, 60)
    faces += slopes.box_faces(LO, HI, TOP - uy(RAIL_TOP), TOP, -70, 70)
    for i in range(n + 1):
        cx = LO + int(round(i * 200.0 / n))
        cx = max(LO + post, min(HI - post, cx))
        faces += slopes.box_faces(cx - post, cx + post, 0, TOP, -100, 100)
    return faces
RAIL_FOOT, RAIL_TOP, RAIL_POST = 40, 30, 40
KINDS = {
    "box": {"make": "box / slab", "walk": "floor",
            "sizes": "any multiple of 200; slabs %s high" % (SLAB_HEIGHTS,)},
    "ramp": {"make": "ramp", "walk": "ramp", "sizes": "multiples of 200"},
    "stairs": {"make": "stairs", "walk": "stairs",
               "sizes": "rise at most %d, runs of 400/800/1200" % (STAIR_STEPS * STAIR_RISER_MAX)},
    "outer": {"make": "ramp_corner(inner=False)", "walk": "ramp",
              "sizes": "square footprints, as the ramps beside it"},
    "inner": {"make": "ramp_corner(inner=True)", "walk": "ramp",
              "sizes": "square footprints, as the ramps beside it"},
    "rail": {"make": "rail", "walk": "edge",
             "sizes": "lengths 400/800/1200/1600, 60 thick, 160 or 300 high"},
    "pillar": {"make": "pillar", "walk": "column",
               "sizes": "width 200 or 400, heights 400/600/900/1200"},
    "arch": {"make": "arch", "walk": "arch",
             "sizes": "openings 400/600/800 wide, 200 deep, 200-400 high"},
    "prism": {"make": "prism", "walk": "floor",
              "sizes": "square footprints of 200/400"},
    "outerstairs": {"make": "corner_stairs(inner=False)", "walk": "stairs",
                    "sizes": "square footprints, as the flights beside it"},
    "innerstairs": {"make": "corner_stairs(inner=True)", "walk": "stairs",
                    "sizes": "square footprints, as the flights beside it"},
}
for _kind, _row in KINDS.items():
    _row["mesh"] = "%s%s_col" % (PREFIX, _kind)
    _row["surface"] = SURFACES[_kind]
def kit_faults():
    faults = []
    for kind in KINDS:
        if KINDS[kind]["walk"] == "stairs":
            continue
        faces = solid(kind, floor=True)
        for yaw in (0, 90, 180, 270):
            piece = {"kind": kind, "tex": "stone1", "x": 1000, "y": 400, "z": -600,
                     "w": 400, "h": 300, "d": 600, "yaw": yaw}
            if kind == "pillar":
                piece["d"] = piece["w"]
            sn, cs = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
            tris = []
            for pts, n in faces:
                if n[1] <= 0:
                    continue
                world = []
                for p in pts:
                    lx, ly, lz = scaled(p, piece)
                    world.append((piece["x"] + lx * cs + lz * sn, piece["y"] + ly,
                                  piece["z"] - lx * sn + lz * cs))
                tris += slopes.triangles(world)
            x0, x1, z0, z1, _ = footprint(piece)
            for i in range(1, 12):
                for j in range(1, 12):
                    x, z = x0 + (x1 - x0) * i / 12.0, z0 + (z1 - z0) * j / 12.0
                    best = None
                    for a, b, c in tris:
                        h = floor_height(a, b, c, x, z)
                        if h is not None and (best is None or h > best):
                            best = h
                    want = top_at(piece, x, z)
                    if (best is None) != (want is None) or (
                            best is not None and abs(best - want) > 1.5):
                        faults.append("%s turned %d at (%d, %d): floor %s, top_at %s"
                                      % (kind, yaw, x, z, best, want))
                        break
                else:
                    continue
                break
    return faults
def floor_height(a, b, c, x, z):
    def side(p, q):
        return (q[0] - p[0]) * (z - p[2]) - (q[2] - p[2]) * (x - p[0])
    d1, d2, d3 = side(a, b), side(b, c), side(c, a)
    eps = 1e-6
    if not ((d1 >= -eps and d2 >= -eps and d3 >= -eps) or (d1 <= eps and d2 <= eps and d3 <= eps)):
        return None
    n = slopes.cross(slopes.sub(b, a), slopes.sub(c, a))
    if abs(n[1]) < 1e-9:
        return None
    return a[1] - (n[0] * (x - a[0]) + n[2] * (z - a[2])) / n[1]
def solid(kind, floor=False, piece=None):
    faces = []
    if kind == "rail" and not floor and piece is not None:
        faces = slopes.solid({"tag": kind, "flip": False, "faces": rail_faces(piece)})
        slopes.vet({"tag": kind}, faces)
        return faces
    if kind != "stairs" and not isinstance(SOLIDS[kind][0][0], str):
        faces = slopes.solid({"tag": kind, "flip": False,
                              "faces": FLOORS[kind] if floor and kind in FLOORS else SOLIDS[kind]})
        slopes.vet({"tag": kind}, faces)
        return faces
    if kind == "stairs":
        faces = slopes.solid({"tag": kind, "flip": False,
                              "faces": FLOORS[kind] if floor else SOLIDS[kind]})
        slopes.vet({"tag": kind}, faces)
        return faces
    for corners, normal in SOLIDS[kind]:
        pts = [CORNER[c] for c in corners]
        if slopes.dot(slopes.cross(slopes.sub(pts[1], pts[0]),
                                   slopes.sub(pts[2], pts[0])), normal) < 0:
            pts = list(reversed(pts))
        faces.append((pts, normal))
    slopes.vet({"tag": kind}, faces)
    return faces
def build_col(kind):
    faces = solid(kind, floor=True)
    verts, tris = [], []
    for pts, _ in faces:
        for tri in slopes.triangles(pts):
            idx = []
            for p in slopes.sort_first(tri):
                if p not in verts:
                    verts.append(p)
                idx.append(verts.index(p))
            tris.append(tuple(idx))
    words = [slopes.COL_INIT, len(verts)]
    for p in verts:
        words += list(p)
    words += [SURFACES[kind], len(tris)]
    for t in tris:
        words += list(t)
    words += [slopes.COL_TRI_STOP, slopes.COL_END]
    name = ("%s%s_col" % (PREFIX, kind)).encode("ascii")
    return (bytes([slopes.DATA_TYPE_COLLISION]) + bytes([len(name)]) + name
            + struct.pack("<I", len(words)) + struct.pack("<%dh" % len(words), *words))
def scaled(p, piece):
    return (p[0] / 200.0 * piece["w"], p[1] / 200.0 * piece["h"],
            p[2] / 200.0 * piece["d"])
def real_normal(pts, piece):
    a, b, c = (scaled(p, piece) for p in pts[:3])
    n = slopes.cross(slopes.sub(b, a), slopes.sub(c, a))
    return n
def uv(p, normal, piece):
    q = scaled(p, piece)
    unit = TEX_PX * 32 / float(TEXEL_SPAN)
    if abs(normal[0]) < 1e-9 and abs(normal[2]) < 1e-9:
        s, t = q[0] + piece["w"] / 2, q[2] + piece["d"] / 2
    else:
        u = (normal[2], 0, -normal[0])
        length = math.sqrt(slopes.dot(u, u))
        s = slopes.dot(q, u) / length + (piece["w"] if abs(u[0]) > abs(u[2])
                                          else piece["d"]) / 2
        if piece["kind"] == "ramp" and normal[1] > 0 and abs(normal[2]) > 0:
            slope_len = math.hypot(piece["h"], piece["d"])
            s = q[0] + piece["w"] / 2
            t = (q[2] + piece["d"] / 2) / piece["d"] * slope_len
            return int(round(s * unit)), int(round(t * unit))
        t = piece["h"] - q[1]
    return int(round(s * unit)), int(round(t * unit))
def build_geo(template_nodes, prefix, png, piece, layers=None):
    faces = solid(piece["kind"], piece=piece)
    tri_dl = None
    for node in template_nodes:
        if node[0] == 4:
            words = node[2][1][1]
            if any(c[0] == "word" and i % 2 == 0 and (c[1] >> 24) == 0x01
                   for i, c in enumerate(words)):
                tri_dl = node
    if tri_dl is None:
        raise Refused("the standard block has no triangle list to replace")
    words = tri_dl[2][1][1]
    pairs = [(words[i], words[i + 1]) for i in range(0, len(words), 2)]
    first = next(i for i, (w0, _) in enumerate(pairs)
                 if w0[0] == "word" and (w0[1] >> 24) == 0x01)
    last = max(i for i, (w0, _) in enumerate(pairs)
               if w0[0] == "word" and (w0[1] >> 24) in (0x01, 0x05, 0x06))
    head, tail = pairs[:first], pairs[last + 1:]
    groups = [faces]
    if layers is not None:
        if piece["h"] > TEXEL_SPAN:
            raise Refused("%s: a transition texture on a piece taller than %d - its "
                          "side would repeat its fringe; lay the base under it"
                          % (piece_name(piece), TEXEL_SPAN))
        groups = [[f for f in faces if slopes.layer_of(f[1]) == k] for k in range(3)]
    chunks, loads = [], {}
    for k, group in enumerate(groups):
        if not group:
            continue
        if k > 0:
            loads[len(chunks)] = slopes.LAYER_LABELS[k]
        chunks.append([])
        for pts, normal in group:
            if chunks[-1] and sum(len(q) for q, _ in chunks[-1]) + len(pts) > slopes.CHUNK:
                chunks.append([])
            chunks[-1].append((pts, normal))
    commands = list(head)
    vertex_nodes = []
    for index, chunk in enumerate(chunks):
        if index in loads:
            commands += slopes.load_layer(loads[index])
        data, count, tris = b"", 0, []
        for pts, normal in chunk:
            n = real_normal(pts, piece)
            nb = slopes.normal_bytes(n)
            base = count
            real = [scaled(p, piece) for p in pts]
            for p, q in zip(pts, real):
                s, t = uv(p, normal, piece)
                if layers is not None and slopes.layer_of(normal) == 1:
                    unit = TEX_PX * 32 / float(TEXEL_SPAN)
                    t = int(round((slopes.side_top(real, n, q) - q[1]) * unit))
                if not (-32768 <= s <= 32767 and -32768 <= t <= 32767):
                    raise Refused("%s: a face is longer than %d units"
                                  % (piece_name(piece), LONGEST_FACE))
                data += struct.pack("<3hHhh4B", p[0], p[1], p[2], 0, s, t,
                                    nb[0], nb[1], nb[2], 255)
                count += 1
            for k in range(1, len(pts) - 1):
                tris.append((base, base + k, base + k + 1))
        if count > slopes.CHUNK:
            raise Refused("%s: one face has %d corners, more than one load"
                          % (piece_name(piece), count))
        label = "%svertex%d" % (slopes.TEMPLATE_PREFIX, index)
        vertex_nodes.append([3, label, [struct.pack("<I", count), data]])
        commands.append((("word", 0x01000000 | (count << 12) | (count * 2)),
                         ("ptr", label, 0)))
        for w0, w1 in slopes.tri_words(tris):
            commands.append((("word", w0), ("word", w1)))
    commands += tail
    flat = []
    for w0, w1 in commands:
        flat += [w0, w1]
    new_tri = [4, tri_dl[1], [struct.pack("<I", len(commands)), ("words", flat)]]
    out, placed, wrapped = [], False, 0
    for node in template_nodes:
        if node[0] == 3:
            if not placed:
                out += vertex_nodes
                placed = True
            continue
        if node is tri_dl:
            out.append(new_tri)
        elif node[0] == 2:
            out.append([2, node[1], [("png", png)]])
            if layers is not None:
                out.append([2, slopes.LAYER_LABELS[1], [("png", layers[0])]])
                out.append([2, slopes.LAYER_LABELS[2], [("png", layers[1])]])
        elif node[0] == 4:
            body = node[2]
            flat_words = list(body[1][1])
            for i in range(0, len(flat_words) - 1, 2):
                w0, w1 = flat_words[i], flat_words[i + 1]
                if (w0 == ("word", SETTILE_W0) and w1 == ("word", SETTILE_CLAMP)):
                    flat_words[i + 1] = ("word", SETTILE_WRAP)
                    wrapped += 1
            out.append([4, node[1], [body[0], ("words", flat_words)]])
        else:
            out.append(node)
    if wrapped != 1:
        raise Refused("the standard block's render tile is not the one this tool "
                      "knows how to make wrap (found %d)" % wrapped)
    template_prefix = slopes.TEMPLATE_PREFIX
    def rename(name):
        if name.startswith(template_prefix):
            return prefix + name[len(template_prefix):]
        return name
    return blocks.pack_bin(slopes.write_nodes(out, rename))
def arenas():
    out = [sky_keep()]
    for arena in out:
        for piece in arena["pieces"]:
            piece["model"] = model_name(piece)
    return out
def sky_keep():
    WALL = "brickdarkgrey"
    pieces = [
        box("tile2", -2000, 2000, -200, 0, -2000, 2000, "island"),
        box("stone2", -1400, 1400, -700, -200, -1400, 1400, "keel"),
        box("stone2", -700, 700, -1300, -700, -700, 700, "keel"),
        box("tile1", -600, 600, 500, 600, -600, 600, "crown deck"),
    ]
    quarter = [
        box(WALL, 400, 600, 0, 500, 400, 600, "crown pillar"),
        box(WALL, -200, 200, 600, 800, 450, 600, "crown merlon"),
        ramp("bricklightgrey", -600, 600, 600, 1000, 0, 600, "-x", "crown ramp"),
        box(WALL, 900, 1300, 0, 700, 900, 1300, "column"),
        box(WALL, -400, 400, 0, 200, 1400, 1500, "breaker"),
        box(WALL, 1400, 2000, -200, 400, 1400, 2000, "perch"),
        ramp("bricklightgrey", 600, 1400, 1600, 2000, 0, 400, "+x", "perch ramp"),
        box("woodenplank1", -300, 300, -100, 0, 2000, 2800, "bridge"),
        box(WALL, -300, -220, 0, 120, 2000, 2800, "bridge rail"),
        box(WALL, 220, 300, 0, 120, 2000, 2800, "bridge rail"),
        ramp("bricklightgrey", 1400, 2000, 2000, 2800, 0, 400, "-z", "flank ramp"),
        ramp("bricklightgrey", -2000, -1400, 2000, 2800, 0, 400, "-z", "flank ramp"),
        box(WALL, -2000, 2000, -300, 0, 2800, 4000, "bastion"),
        box(WALL, -2000, 2000, 0, 900, 3800, 4000, "back wall"),
        box(WALL, -2000, -1920, 0, 160, 2800, 3800, "bastion rail"),
        box(WALL, 1920, 2000, 0, 160, 2800, 3800, "bastion rail"),
        box(WALL, -1400, -300, 0, 200, 2800, 2900, "front wall"),
        box(WALL, 300, 1400, 0, 200, 2800, 2900, "front wall"),
        box(WALL, -500, 500, 0, 400, 3100, 3300, "shield"),
    ]
    accents = ["stone1", "brickpyramid", "carpet", "woodenplank2"]
    for q in range(4):
        for piece in quarter:
            p = dict(piece)
            if p["tag"] == "bastion":
                p = box(accents[q], -2000, 2000, -300, 0, 2800, 4000, "bastion")
                p = dict(p)
            pieces.append(turned(p, q))
    spawns = []
    for q in range(4):
        for x in (-1150, -350, 350, 1150):
            spawns.append(turned_point({"x": x, "y": 0, "z": 3550, "yaw": 180}, q))
    order = []
    for k in range(4):
        for q in (0, 2, 1, 3):
            order.append(spawns[q * 4 + k])
    field = []
    for q in (0, 2, 1, 3):
        for spot in ({"x": 1700, "y": 400, "z": 1700, "yaw": 225},
                     {"x": 0, "y": 0, "z": 1150, "yaw": 180},
                     {"x": 300, "y": 600, "z": 300, "yaw": 225}):
            field.append(turned_point(spot, q))
    return {
        "key": "skykeep",
        "level": "empty2",
        "budget": 120,
        "pieces": pieces,
        "spawns": order,
        "survey": {"points": order + field},
        "look": {"sky": "BACKGROUND_PURPLE_SKY", "music": "SEQ_LEVEL_KOOPA_ROAD"},
    }
def octagon(tex, radius, y0, y1, tag):
    a = radius
    b = round(radius * 0.414 / 100) * 100
    c = round(radius * 0.707 / 100) * 100
    return [box(tex, -a, a, y0, y1, -b, b, tag),
            box(tex, -b, b, y0, y1, -a, a, tag),
            box(tex, -c, c, y0, y1, -c, c, tag)]
KIND = {"START": 1, "INFO": 3, "GATE": 16, "RESPAWN": 18, "BOX": 32,
        "COIN": 33, "BOOST": 64, "OUT": 80}
def marker(kind, num, a, b, x, y, z, label=""):
    return {"kind": KIND[kind], "num": num, "a": a, "b": b,
            "x": x, "y": y, "z": z, "yaw": 0, "label": label}
def road(tex, x0, x1, z0, z1, top, thick=200, tag="road", longest=6000):
    out = []
    along_x = (x1 - x0) >= (z1 - z0)
    lo, hi = (x0, x1) if along_x else (z0, z1)
    n = max(1, int(math.ceil((hi - lo) / float(longest))))
    step = (hi - lo) / float(n)
    for k in range(n):
        a, b = lo + step * k, lo + step * (k + 1)
        if along_x:
            out.append(box(tex, a, b, top - thick, top, z0, z1, tag))
        else:
            out.append(box(tex, x0, x1, top - thick, top, a, b, tag))
    return out
def check_markers(arena):
    faults = []
    markers = arena.get("markers", [])
    if not markers:
        return faults
    by = {}
    for m in markers:
        by.setdefault(m["kind"], []).append(m)
    if len(by.get(KIND["START"], [])) != 1:
        faults.append("not exactly one START")
    if len(by.get(KIND["INFO"], [])) != 1:
        faults.append("not exactly one INFO")
    gates = sorted(by.get(KIND["GATE"], []), key=lambda m: m["num"])
    if len(gates) < 8 or [g["num"] for g in gates] != list(range(len(gates))):
        faults.append("gates are not 0..N-1 with N at least 8")
    for m in markers:
        for field in ("num", "a", "b"):
            if not 0 <= m[field] <= 255:
                faults.append("a marker's %s is %s" % (field, m[field]))
    pieces = arena["pieces"]
    for m in gates + by.get(KIND["START"], []) + by.get(KIND["BOOST"], []):
        tops = [round(top_at(p, m["x"], m["z"])) for p in pieces
                if footprint(p)[0] <= m["x"] <= footprint(p)[1]
                and footprint(p)[2] <= m["z"] <= footprint(p)[3]
                and covers(p, m["x"], m["z"])]
        if not any(abs(t - m["y"]) <= 2 for t in tops):
            faults.append("%s at (%d, %d, %d) is not on the road (tops %s)"
                          % (m.get("label") or m["kind"], m["x"], m["y"], m["z"], tops))
    if by.get(KIND["START"]) and gates:
        s, g = by[KIND["START"]][0], gates[0]
        gap = math.hypot(s["x"] - g["x"], s["z"] - g["z"])
        if not 200 <= gap <= 400:
            faults.append("START is %d from gate 0, not 2-4 m" % gap)
    return faults
def surfaces_at(pieces, x, z, level):
    tops, bottoms = [], []
    for piece in pieces:
        x0, x1, z0, z1, _ = footprint(piece)
        if x0 <= x <= x1 and z0 <= z <= z1 and covers(piece, x, z):
            tops.append((top_at(piece, x, z), piece))
            bottoms.append(piece["y"])
    floor = LEVELS[level]["floor"]
    if floor is not None and abs(x) <= LEVELS[level]["half"] and abs(z) <= LEVELS[level]["half"]:
        tops.append((floor, None))
    return tops, bottoms
def standable(pieces, x, z, level):
    out = []
    for height, piece in surfaces_at(pieces, x, z, level)[0]:
        clear = True
        for other in pieces:
            if other is piece:
                continue
            x0, x1, z0, z1, _ = footprint(other)
            if not (x0 < x < x1 and z0 < z < z1) or not covers(other, x, z):
                continue
            below, above = other["y"], top_at(other, x, z)
            if below < height + MARIO_TALL and above > height + 1:
                clear = False
                break
        if clear:
            out.append(round(height))
    return sorted(set(out))
def check_layout(arena):
    faults = []
    level = LEVELS[arena["level"]]
    pieces = arena["pieces"]
    for piece in pieces:
        x0, x1, z0, z1, _ = footprint(piece)
        if max(abs(x0), abs(x1), abs(z0), abs(z1)) > min(BOUND, level["half"]):
            faults.append("%s leaves the level" % piece_name(piece))
        if piece["y"] < level["plane"] + 2048:
            faults.append("%s sits within the death barrier's reach" % piece_name(piece))
        for dim in ("w", "h", "d"):
            if piece[dim] <= 0 or piece[dim] > LONGEST_FACE:
                faults.append("%s: %s %s is out of the kit's range"
                              % (piece_name(piece), dim, piece[dim]))
        if piece["kind"] in ("stairs", "outerstairs", "innerstairs") \
                and piece["h"] / STAIR_STEPS > STAIR_RISER_MAX:
            faults.append("%s: risers of %d are a wall to a walking Mario (most %d)"
                          % (piece_name(piece), piece["h"] / STAIR_STEPS, STAIR_RISER_MAX))
    objects = len(pieces) + len(arena.get("markers", []))
    if objects > arena["budget"]:
        faults.append("%d objects against a budget of %d" % (objects, arena["budget"]))
    faults += check_markers(arena)
    for i, spot in enumerate(arena["spawns"]):
        heights = standable(pieces, spot["x"], spot["z"], arena["level"])
        if not any(abs(h - spot["y"]) <= 1 for h in heights):
            faults.append("spawn %d at (%d, %d, %d) stands on nothing clear"
                          % (i + 1, spot["x"], spot["y"], spot["z"]))
    for i, piece in enumerate(pieces):
        x0, x1, z0, z1, _ = footprint(piece)
        for px, pz in (((x0 + x1) / 2, (z0 + z1) / 2), (x0 + 50, z0 + 50), (x1 - 50, z1 - 50),
                       (x0 + 50, z1 - 50), (x1 - 50, z0 + 50)):
            top = top_at(piece, px, pz)
            if top is None:
                continue
            for j, other in enumerate(pieces):
                if j == i:
                    continue
                ox0, ox1, oz0, oz1, _ = footprint(other)
                if ox0 < px < ox1 and oz0 < pz < oz1 and covers(other, px, pz):
                    gap = other["y"] - top
                    if 1 < gap < MARIO_TALL:
                        faults.append("a %d-high slot under %s over %s"
                                      % (gap, piece_name(other), piece_name(piece)))
    for key, spots in sorted(arena.get("survey", {}).items()):
        if not isinstance(spots, list):
            continue
        if key == "points" and len(spots) > SURVEY_POINTS_MAX:
            faults.append("%d survey points, the wire carries %d"
                          % (len(spots), SURVEY_POINTS_MAX))
        for i, spot in enumerate(spots):
            if not isinstance(spot, dict) or "x" not in spot:
                continue
            heights = standable(pieces, spot["x"], spot["z"], arena["level"])
            if not any(abs(h - spot["y"]) <= 1 for h in heights):
                faults.append("survey %s %d at (%d, %d, %d) stands on nothing clear"
                              % (key, i + 1, spot["x"], spot["y"], spot["z"]))
    if len(arena["spawns"]) < 16:
        faults.append("%d spawns for sixteen players" % len(arena["spawns"]))
    if not faults:
        faults += check_walks(arena)
    return faults
def walk_graph(arena):
    pieces = arena["pieces"]
    xs = []
    for piece in pieces:
        x0, x1, z0, z1, _ = footprint(piece)
        xs.append((x0, x1, z0, z1))
    lo_x = min(a for a, _, _, _ in xs)
    hi_x = max(b for _, b, _, _ in xs)
    lo_z = min(c for _, _, c, _ in xs)
    hi_z = max(d for _, _, _, d in xs)
    cells = {}
    gx = int(math.floor(lo_x / GRID))
    while gx * GRID <= hi_x:
        gz = int(math.floor(lo_z / GRID))
        while gz * GRID <= hi_z:
            x, z = gx * GRID + GRID / 2, gz * GRID + GRID / 2
            for h in standable(pieces, x, z, arena["level"]):
                cells[(gx, gz, h)] = True
            gz += 1
        gx += 1
    by_column = {}
    for (gx, gz, h) in cells:
        by_column.setdefault((gx, gz), []).append(h)
    edges = {}
    for (gx, gz, h) in cells:
        out = []
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for h2 in by_column.get((gx + dx, gz + dz), []):
                rise = h2 - h
                if rise <= JUMP_UP and -rise <= SAFE_DROP:
                    out.append((gx + dx, gz + dz, h2))
        edges[(gx, gz, h)] = out
    return cells, edges
def reach(edges, start, reverse=False):
    if reverse:
        back = {}
        for a, outs in edges.items():
            for b in outs:
                back.setdefault(b, []).append(a)
        edges = back
    seen, todo = {start}, [start]
    while todo:
        node = todo.pop()
        for nxt in edges.get(node, []):
            if nxt not in seen:
                seen.add(nxt)
                todo.append(nxt)
    return seen
def spawn_cell(spot):
    return (int(math.floor(spot["x"] / GRID)), int(math.floor(spot["z"] / GRID)),
            int(round(spot["y"])))
def check_walks(arena):
    faults = []
    cells, edges = walk_graph(arena)
    first = spawn_cell(arena["spawns"][0])
    if first not in cells:
        return ["the first spawn is not on the walk grid"]
    forward = reach(edges, first)
    backward = reach(edges, first, reverse=True)
    for i, spot in enumerate(arena["spawns"]):
        c = spawn_cell(spot)
        if c not in forward or c not in backward:
            faults.append("spawn %d cannot be walked to and from spawn 1" % (i + 1))
    trapped = [c for c in forward if c not in backward]
    if trapped:
        c = sorted(trapped)[0]
        faults.append("%d floor cells are a one-way trip (first at x %d z %d y %d)"
                      % (len(trapped), c[0] * GRID, c[1] * GRID, c[2]))
    arena["_walk"] = {"cells": len(cells), "reached": len(forward)}
    return faults
def average_colour(png_bytes):
    import io
    from PIL import Image
    im = Image.open(io.BytesIO(png_bytes)).convert("RGB")
    px = [im.getpixel((x, y)) for y in range(im.height) for x in range(im.width)]
    return tuple(sum(c[k] for c in px) // len(px) for k in range(3))
def draw(arena, colours, path):
    from PIL import Image, ImageDraw
    pieces = arena["pieces"]
    rects = [footprint(p) for p in pieces]
    lo = min(min(r[0], r[2]) for r in rects) - 400
    hi = max(max(r[1], r[3]) for r in rects) + 400
    size = 900
    scale = size / (hi - lo)
    def px(x, z):
        return ((x - lo) * scale, (z - lo) * scale)
    im = Image.new("RGB", (size, size + 70), (24, 24, 34))
    d = ImageDraw.Draw(im)
    tops = [max(p["y"] + p["h"], p["y"]) for p in pieces]
    t_lo, t_hi = min(tops), max(tops)
    order = sorted(range(len(pieces)), key=lambda i: (tops[i], i))
    for i in order:
        p = pieces[i]
        x0, x1, z0, z1, up = footprint(p)
        base = colours.get(p["tex"], (128, 128, 128))
        lift = (tops[i] - t_lo) / max(1, t_hi - t_lo)
        shade = 0.55 + 0.45 * lift
        fill = tuple(int(c * shade) for c in base)
        d.rectangle([px(x0, z0), px(x1, z1)], fill=fill, outline=(10, 10, 10))
        if p["kind"] in ("ramp", "stairs"):
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            ex, ez = cx + up[0] * (x1 - x0) * 0.35, cz + up[1] * (z1 - z0) * 0.35
            sx, sz = cx - up[0] * (x1 - x0) * 0.35, cz - up[1] * (z1 - z0) * 0.35
            d.line([px(sx, sz), px(ex, ez)], fill=(255, 255, 255), width=2)
            hx, hz = px(ex, ez)
            d.ellipse([hx - 3, hz - 3, hx + 3, hz + 3], fill=(255, 255, 255))
    for i, s in enumerate(arena["spawns"]):
        x, z = px(s["x"], s["z"])
        d.ellipse([x - 6, z - 6, x + 6, z + 6], fill=(80, 230, 120), outline=(0, 0, 0))
        d.text((x + 7, z - 7), str(i + 1), fill=(220, 255, 220))
    for m in arena.get("marks", []):
        x, z = px(m["x"], m["z"])
        d.rectangle([x - 5, z - 5, x + 5, z + 5], outline=(255, 210, 60), width=2)
        d.text((x + 7, z - 7), m.get("label", ""), fill=(255, 230, 140))
    y = size + 12
    d.line([(20, y), (20 + 1000 * scale, y)], fill=(255, 255, 255), width=3)
    d.text((24, y + 6), "1000 units", fill=(255, 255, 255))
    d.text((220, y - 4), "%s on %s - %d pieces, %d spawns (green), arrows point up ramps"
           % (arena["key"], arena["level"], len(pieces), len(arena["spawns"])),
           fill=(255, 255, 255))
    d.text((220, y + 14), "brighter = higher (%d .. %d)" % (t_lo, t_hi), fill=(200, 200, 200))
    im.save(path, optimize=True)
def num(v):
    v = round(v, 3)
    if v == int(v):
        return str(int(v))
    return repr(v)
def lua_table(all_arenas):
    lines = [BEGIN, "venues.LAYOUTS = {"]
    for arena in all_arenas:
        lines.append("    %s = {" % arena["key"])
        lines.append('        level = "%s", budget = %d,' % (arena["level"], arena["budget"]))
        look = arena["look"]
        lines.append('        look = { sky = "%s", music = "%s" },' % (look["sky"], look["music"]))
        lines.append("        -- kind, model, x, y, z, width, height, depth, yaw (degrees)")
        lines.append("        pieces = {")
        for p in arena["pieces"]:
            lines.append('            { "%s", "%s", %s, %s, %s, %s, %s, %s, %s },'
                         % (p["kind"], p["model"], num(p["x"]), num(p["y"]), num(p["z"]),
                            num(p["w"]), num(p["h"]), num(p["d"]), num(p["yaw"])))
        lines.append("        },")
        lines.append("        -- x, y, z, yaw (degrees)")
        lines.append("        spawns = {")
        for s in arena["spawns"]:
            lines.append("            { %s, %s, %s, %s }," % (num(s["x"]), num(s["y"]),
                                                            num(s["z"]), num(s["yaw"])))
        lines.append("        },")
        if arena.get("markers"):
            lines.append("        -- the race's track markers: kind, number, a, b, x, y, z, yaw")
            lines.append("        markers = {")
            for m in arena["markers"]:
                lines.append("            { %d, %d, %d, %d, %s, %s, %s, %s },"
                             % (m["kind"], m["num"], m["a"], m["b"], num(m["x"]),
                                num(m["y"]), num(m["z"]), num(m["yaw"])))
            lines.append("        },")
        lines.append("        survey = {")
        for key in sorted(arena.get("survey", {})):
            spots = arena["survey"][key]
            single = isinstance(spots, dict)
            if single:
                spots = [spots]
            body = ", ".join("{ %s, %s, %s, %s }" % (num(s["x"]), num(s["y"]), num(s["z"]),
                                                      num(s.get("yaw", 0))) for s in spots)
            lines.append("            %s = { single = %s, %s }," % (key, "true" if single else "false", body))
        lines.append("        },")
        lines.append("    },")
    lines.append("}")
    lines.append(END)
    return "\n".join(lines)
def lua_meshes():
    import re
    with open(LUA, encoding="utf-8") as handle:
        text = handle.read()
    at = text.find("venues.MESH = {")
    body = text[at:text.find("}", at)]
    return dict(re.findall(r'(\w+) = "(\w+)"', body))
def splice(text, table):
    a = text.find(BEGIN)
    b = text.find(END)
    if a < 0 or b < 0 or b < a:
        raise Refused("of_venues.lua has no LAYOUTS markers")
    return text[:a] + table + text[b + len(END):]
def build():
    template_path, rows = blocks.read_manifest()
    with open(os.path.join(ROOT, template_path), "rb") as handle:
        raw = blocks.unpack_bin(handle.read(), template_path)
    nodes = slopes.read_nodes(raw, template_path)
    textures, layered = {}, {}
    for row in rows:
        textures[row["slug"]] = blocks.read_texture(os.path.join(ROOT, row["source"]))
        if row.get("layers"):
            layered[row["slug"]] = slopes.row_textures(row)[1]
    all_arenas = arenas()
    faults = kit_faults()
    meshes = lua_meshes()
    for kind in SOLIDS:
        if meshes.get(kind) != "%s%s_col" % (PREFIX, kind):
            faults.append("of_venues.lua's venues.MESH has no %s = \"%s%s_col\""
                          % (kind, PREFIX, kind))
    for arena in all_arenas:
        for fault in check_layout(arena):
            faults.append("%s: %s" % (arena["key"], fault))
        for piece in arena["pieces"]:
            if piece["tex"] not in textures:
                faults.append("%s: no block texture %r" % (arena["key"], piece["tex"]))
            if piece["tex"] == "brick":
                faults.append("%s: the plain Brick block is not used in an arena"
                              % arena["key"])
    if faults:
        raise Refused("; ".join(faults))
    files = {}
    for kind in SOLIDS:
        files["%s%s_col.col" % (PREFIX, kind)] = build_col(kind)
    for arena in all_arenas:
        for piece in arena["pieces"]:
            name = piece["model"] + ".bin"
            if name not in files:
                files[name] = build_geo(nodes, piece["model"][:-3],
                                        textures[piece["tex"]], piece,
                                        layered.get(piece["tex"]))
    for kind in KINDS:
        sample = {"kind": kind, "tex": "stone1", "x": 0, "y": 0, "z": 0, "w": 800,
                  "h": 160, "d": 200, "yaw": 0}
        build_geo(nodes, PREFIX + "probe", textures["stone1"], sample)
        for slug, layers in sorted(layered.items()):
            build_geo(nodes, PREFIX + "probe", textures[slug], dict(sample, tex=slug), layers)
    colours = {slug: average_colour(png) for slug, png in textures.items()}
    return all_arenas, files, colours
def main(argv):
    check = "--check" in argv
    try:
        all_arenas, files, colours = build()
        table = lua_table(all_arenas)
        with open(LUA, encoding="utf-8") as handle:
            text = handle.read()
        new_text = splice(text, table)
    except Refused as why:
        print("make-arenas: %s" % why)
        return 1
    stale = sorted(name for name in os.listdir(ACTORS)
                   if name.startswith(PREFIX) and name not in files)
    differ = []
    for name, data in sorted(files.items()):
        path = os.path.join(ACTORS, name)
        have = open(path, "rb").read() if os.path.exists(path) else None
        if have != data:
            differ.append(name)
    lua_stale = new_text != text
    pictures = [arena["key"] + ".png" for arena in all_arenas]
    missing_pictures = [p for p in pictures
                        if not os.path.exists(os.path.join(PICTURES, p))]
    if check:
        faults = []
        if differ:
            faults.append("%d file(s) out of date, first %s" % (len(differ), differ[0]))
        if stale:
            faults.append("%d file(s) no layout uses, first %s" % (len(stale), stale[0]))
        if lua_stale:
            faults.append("of_venues.lua's layout tables are out of date")
        if missing_pictures:
            faults.append("no picture %s" % missing_pictures[0])
        if faults:
            print("make-arenas: " + "; ".join(faults))
            print("run tools/make-arenas.py to rebuild them")
            return 1
        for arena in all_arenas:
            print("make-arenas: %s - %d pieces (budget %d), %d spawns, %d floor cells all "
                  "walkable to and from spawn 1"
                  % (arena["key"], len(arena["pieces"]), arena["budget"],
                     len(arena["spawns"]), arena["_walk"]["reached"]))
        return 0
    for name in differ:
        with open(os.path.join(ACTORS, name), "wb") as handle:
            handle.write(files[name])
    for name in stale:
        os.remove(os.path.join(ACTORS, name))
    if lua_stale:
        with open(LUA, "w", encoding="utf-8") as handle:
            handle.write(new_text)
    os.makedirs(PICTURES, exist_ok=True)
    for arena in all_arenas:
        draw(arena, colours, os.path.join(PICTURES, arena["key"] + ".png"))
    size = sum(len(data) for data in files.values())
    for arena in all_arenas:
        print("make-arenas: %s - %d pieces, %d spawns, %d floor cells reached"
              % (arena["key"], len(arena["pieces"]), len(arena["spawns"]),
                 arena["_walk"]["reached"]))
    print("make-arenas: %d files, %d bytes; %d written, %d removed"
          % (len(files), size, len(differ), len(stale)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
