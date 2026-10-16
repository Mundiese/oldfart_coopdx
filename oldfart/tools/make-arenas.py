#!/usr/bin/env python3
import collections
import importlib.util
import json
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
SURFACE_ICE = 0x002E
SURFACE_BURNING = 0x0001
TEXEL_SPAN = 200
TEX_PX = 32
LONGEST_FACE = (1023 // TEX_PX) * TEXEL_SPAN
SETTILE_W0 = 0xF5101000
SETTILE_CLAMP = 0x00094250
SETTILE_WRAP = SETTILE_CLAMP & ~((2 << 8) | (2 << 18))
PICTURES_AT_SIZE = True
BOUND = 30000
def _movement(path, default):
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs",
                               "learned", "movement", "movement.json"), encoding="utf-8") as fh:
            node = json.load(fh)
        for k in path:
            if isinstance(node, dict) and "value" in node and k not in node:
                node = node["value"]
            node = node[k]
        if isinstance(node, dict) and "value" in node:
            node = node["value"]
        return node if isinstance(node, (int, float)) and not isinstance(node, bool) else default
    except (OSError, ValueError, KeyError, TypeError):
        return default
MARIO_TALL = _movement(("body", "height_standing"), 160)
STEP_UP = _movement(("clearances", "step_walked_up_max"), 24)
JUMP_UP = _movement(("design", "rise_one_jump", "easy"), 200)
SURVEY_POINTS_MAX = 256 // 9
SAFE_DROP = (_movement(("falls", "damage_threshold"), 1150) - 1) // 100 * 100
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
ARC_SEGMENTS = 8
ARC_KINDS = {"curve": (0.0, False), "bank": (0.6, True), "arcwall": (0.9, False)}
BANK_IN = 0.5
def arc(kind, tex, x0, x1, z0, z1, y0, y1, centre, tag=""):
    piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, centre, tag=tag)
    piece["kind"] = kind
    return piece
def arc_points(ratio):
    def pt(rad, i):
        a = (math.pi / 2) * i / ARC_SEGMENTS
        return (int(round(LO + rad * math.cos(a))), int(round(LO + rad * math.sin(a))))
    outer = [pt(200, i) for i in range(ARC_SEGMENTS + 1)]
    inner = [pt(200 * ratio, i) for i in range(ARC_SEGMENTS + 1)] if ratio > 0 else None
    return outer, inner
def arc_faces(kind):
    ratio, banked = ARC_KINDS[kind]
    outer, inner = arc_points(ratio)
    yo = TOP
    yi = int(TOP * BANK_IN) if banked else TOP
    faces = []
    for i in range(ARC_SEGMENTS):
        (ax, az), (bx, bz) = outer[i], outer[i + 1]
        m = (math.pi / 2) * (i + 0.5) / ARC_SEGMENTS
        radial = (math.cos(m), 0, math.sin(m))
        faces.append(([(ax, 0, az), (bx, 0, bz), (bx, yo, bz), (ax, yo, az)], radial))
        if inner is None:
            faces.append(([(LO, TOP, LO), (ax, TOP, az), (bx, TOP, bz)], (0, 1, 0)))
            faces.append(([(LO, 0, LO), (ax, 0, az), (bx, 0, bz)], (0, -1, 0)))
        else:
            (cx_, cz_), (dx, dz) = inner[i], inner[i + 1]
            faces.append(([(cx_, yi, cz_), (ax, yo, az), (bx, yo, bz)], (0, 1, 0)))
            faces.append(([(cx_, yi, cz_), (bx, yo, bz), (dx, yi, dz)], (0, 1, 0)))
            faces.append(([(cx_, 0, cz_), (ax, 0, az), (bx, 0, bz), (dx, 0, dz)], (0, -1, 0)))
            faces.append(([(cx_, 0, cz_), (dx, 0, dz), (dx, yi, dz), (cx_, yi, cz_)],
                          (-radial[0], 0, -radial[2])))
    if inner is None:
        faces.append(([(LO, 0, LO), (outer[0][0], 0, LO), (outer[0][0], yo, LO), (LO, yo, LO)],
                      (0, 0, -1)))
        faces.append(([(LO, 0, LO), (LO, 0, outer[-1][1]), (LO, yo, outer[-1][1]), (LO, yo, LO)],
                      (-1, 0, 0)))
    else:
        faces.append(([(inner[0][0], 0, LO), (outer[0][0], 0, LO), (outer[0][0], yo, LO),
                       (inner[0][0], yi, LO)], (0, 0, -1)))
        faces.append(([(LO, 0, inner[-1][1]), (LO, 0, outer[-1][1]), (LO, yo, outer[-1][1]),
                       (LO, yi, inner[-1][1])], (-1, 0, 0)))
    out = []
    for pts, hint in faces:
        n = [0.0, 0.0, 0.0]
        for k in range(len(pts)):
            (x1, y1, z1), (x2, y2, z2) = pts[k], pts[(k + 1) % len(pts)]
            n[0] += (y1 - y2) * (z1 + z2)
            n[1] += (z1 - z2) * (x1 + x2)
            n[2] += (x1 - x2) * (y1 + y2)
        length = math.sqrt(sum(v * v for v in n))
        n = [v / length for v in n]
        if sum(a_ * b_ for a_, b_ in zip(n, hint)) < 0:
            n = [-v for v in n]
        out.append((pts, tuple(n)))
    return out
_ARC_TOPS = {}
def arc_top_unit(kind, lx, lz):
    if kind not in _ARC_TOPS:
        tris = []
        for pts, n in arc_faces(kind):
            if n[1] > 0:
                tris += slopes.triangles(pts)
        _ARC_TOPS[kind] = tris
    best = None
    for a, b, c in _ARC_TOPS[kind]:
        h = floor_height(a, b, c, lx, lz)
        if h is not None and (best is None or h > best):
            best = h
    return best
MESH_TOP_KINDS = ("ridge", "pyramid", "roundcorner")
def ridge_faces():
    return [
        ([(LO, 0, HI), (HI, 0, HI), (HI, TOP, 0), (LO, TOP, 0)], (0, 1, 2)),
        ([(LO, TOP, 0), (HI, TOP, 0), (HI, 0, LO), (LO, 0, LO)], (0, 1, -2)),
        ([(LO, 0, LO), (LO, 0, HI), (LO, TOP, 0)], (-1, 0, 0)),
        ([(HI, 0, LO), (HI, 0, HI), (HI, TOP, 0)], (1, 0, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0)),
    ]
def pyramid_faces():
    top = (0, TOP, 0)
    return [
        ([(LO, 0, HI), (HI, 0, HI), top], (0, 1, 2)),
        ([(HI, 0, HI), (HI, 0, LO), top], (2, 1, 0)),
        ([(HI, 0, LO), (LO, 0, LO), top], (0, 1, -2)),
        ([(LO, 0, LO), (LO, 0, HI), top], (-2, 1, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0)),
    ]
def exact_normals(faces):
    out = []
    for pts, hint in faces:
        n = [0.0, 0.0, 0.0]
        for k in range(len(pts)):
            (x1, y1, z1), (x2, y2, z2) = pts[k], pts[(k + 1) % len(pts)]
            n[0] += (y1 - y2) * (z1 + z2)
            n[1] += (z1 - z2) * (x1 + x2)
            n[2] += (x1 - x2) * (y1 + y2)
        length = math.sqrt(sum(v * v for v in n))
        n = [v / length for v in n]
        if sum(a_ * b_ for a_, b_ in zip(n, hint)) < 0:
            n = [-v for v in n]
        out.append((pts, tuple(n)))
    return out
def roof(kind, tex, x0, x1, z0, z1, y0, y1, along="x", tag=""):
    piece = box(tex, x0, x1, y0, y1, z0, z1, tag)
    piece["kind"] = kind
    if kind == "ridge" and along == "z":
        piece["yaw"] = 90
        piece["w"], piece["d"] = z1 - z0, x1 - x0
    return piece
def round_corner(tex, x0, x1, z0, z1, y0, y1, centre, tag=""):
    piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, centre, tag=tag)
    piece["kind"] = "roundcorner"
    return piece
U_KINDS = ("uslope", "uouter", "uinner")
WEDGE_TIP_KINDS = ("wedgetip", "wedgetipouter", "wedgetipinner")
OPENING_KINDS = ("doorway", "window")
def upside(kind, tex, x0, x1, z0, z1, y0, y1, toward, tag=""):
    if kind == "uslope":
        piece = ramp(tex, x0, x1, z0, z1, y0, y1, toward, tag)
    else:
        piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, toward, tag=tag)
    piece["kind"] = kind
    return piece
def wedge_tip(kind, tex, x0, x1, z0, z1, y0, y1, toward, tag=""):
    if kind == "wedgetip":
        piece = ramp(tex, x0, x1, z0, z1, y0, y1, toward, tag)
    else:
        piece = ramp_corner(tex, x0, x1, z0, z1, y0, y1, toward, tag=tag)
    piece["kind"] = kind
    return piece
def pole(tex, x, z, y0, y1, width=200, tag=""):
    return {"kind": "pole", "tex": tex, "x": x, "y": y0, "z": z, "w": width,
            "h": y1 - y0, "d": width, "yaw": 0, "tag": tag}
def opening(kind, tex, x0, x1, z0, z1, y0, y1, tag=""):
    return _along(kind, tex, x0, x1, z0, z1, y0, y1, tag)
_MESH_TOPS = {}
def mesh_top_unit(kind, lx, lz):
    if kind not in _MESH_TOPS:
        tris = []
        for pts, n in SOLIDS[kind]:
            if n[1] > 0:
                tris += slopes.triangles([CORNER[c] if isinstance(c, str) else c for c in pts])
        _MESH_TOPS[kind] = tris
    best = None
    for a, b, c in _MESH_TOPS[kind]:
        h = floor_height(a, b, c, lx, lz)
        if h is not None and (best is None or h > best):
            best = h
    return best
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
    return x0, x1, z0, z1, QUARTER_UP[yaw]
QUARTER_UP = {0: (0, -1), 90: (-1, 0), 180: (0, 1), 270: (1, 0)}
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
    if piece["kind"] in ARC_KINDS:
        lx, lz = local_of(piece, x, z)
        return arc_top_unit(piece["kind"], lx, lz) is not None
    if piece["kind"] in VISUAL_KINDS:
        return False
    if piece["kind"] == "roundcorner":
        lx, lz = local_of(piece, x, z)
        return mesh_top_unit(piece["kind"], lx, lz) is not None
    if piece["kind"] == "pole":
        lx, lz = local_of(piece, x, z)
        return abs(lx) <= slopes.POLE_HALF + 1e-6 and abs(lz) <= slopes.POLE_HALF + 1e-6
    if piece["kind"] in OPENING_KINDS:
        lx, lz = local_of(piece, x, z)
        return abs(lz) <= slopes.WALL_THICK / 2.0 + 1e-6
    return True
def top_at(piece, x, z):
    x0, x1, z0, z1, up = footprint(piece)
    if not covers(piece, x, z):
        return None
    if piece["kind"] in ARC_KINDS:
        lx, lz = local_of(piece, x, z)
        t = arc_top_unit(piece["kind"], lx, lz)
        return None if t is None else piece["y"] + piece["h"] * t / 200.0
    if piece["kind"] in MESH_TOP_KINDS:
        lx, lz = local_of(piece, x, z)
        t = mesh_top_unit(piece["kind"], max(LO, min(HI, lx)), max(LO, min(HI, lz)))
        return None if t is None else piece["y"] + piece["h"] * t / 200.0
    if piece["kind"] in FLAT_TOPPED:
        return piece["y"] + piece["h"]
    if piece["kind"] in ("outer", "inner", "outerstairs", "innerstairs", "wedgetipouter",
                         "wedgetipinner"):
        lx, lz = local_of(piece, x, z)
        fx = max(0.0, min(1.0, (100 - lx) / 200.0))
        fz = max(0.0, min(1.0, (100 - lz) / 200.0))
        f = min(fx, fz) if piece["kind"] in ("outer", "outerstairs", "wedgetipouter") \
            else max(fx, fz)
        if piece["kind"] in WEDGE_TIP_KINDS:
            return piece["y"] + piece["h"] * (0.5 + 0.5 * f)
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
    if piece["kind"] == "wedgetip":
        return piece["y"] + piece["h"] * (0.5 + 0.5 * t)
    return piece["y"] + piece["h"] * t
FLAT_TOPPED = ("box", "rail", "pillar", "arch", "prism", "ice", "lava", "uslope", "uouter",
               "uinner", "pole", "doorway", "window")
HAZARD_KINDS = ("lava",)
INVISIBLE = "invisible"
NO_MODEL = "none"
RUNTIME_SHAPES = {"box": 0, "ice": 0, "lava": 0, "ramp": 1, "outer": 2, "inner": 3, "stairs": 7,
                  "pillar": 14, "arch": 15, "prism": 16, "outerstairs": 17,
                  "innerstairs": 18,
                  "uslope": 4, "uouter": 5, "uinner": 6, "wedgetip": 22, "wedgetipouter": 25,
                  "wedgetipinner": 26, "pole": 32, "doorway": 34, "window": 35}
RUNTIME_FLATS = {100: 8, 20: 19}
RUNTIME_BOX_HALF_UP, RUNTIME_BOX_HALF = 46, 47
RUNTIME_MAX = (32, 16, 32)
_BLOCK_SLUGS = None
def block_slugs():
    global _BLOCK_SLUGS
    if _BLOCK_SLUGS is None:
        _BLOCK_SLUGS = set(row["slug"] for row in blocks.read_manifest()[1])
    return _BLOCK_SLUGS
def _decor():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import decor
    return decor
def runtime_token(piece):
    if piece.get("decor"):
        return _decor().token(piece)
    tex, kind = piece.get("tex"), piece.get("kind")
    join = piece.get("join")
    if join is not None and tex in block_slugs():
        return "@j:%s:%s:%s" % (tex, join["arms"], join.get("other") or "-")
    if tex == INVISIBLE or tex not in block_slugs() or kind not in RUNTIME_SHAPES:
        return None
    if any(k in piece for k in ("tex_top", "tex_side", "tex_bottom")):
        return None
    w, h, d = (int(round(piece[k])) for k in ("w", "h", "d"))
    if w <= 0 or h <= 0 or d <= 0:
        return None
    half = TEXEL_SPAN // 2
    if RUNTIME_SHAPES[kind] == 0 and h not in RUNTIME_FLATS and (
            w % TEXEL_SPAN or d % TEXEL_SPAN or h % TEXEL_SPAN) \
            and not (w % half or d % half or h % half):
        if w % TEXEL_SPAN == 0 and d % TEXEL_SPAN == 0:
            byte, sizes = RUNTIME_BOX_HALF_UP, (w // TEXEL_SPAN, h // half, d // TEXEL_SPAN)
        else:
            byte, sizes = RUNTIME_BOX_HALF, (w // half, h // half, d // half)
        if sizes[0] > RUNTIME_MAX[0] or sizes[1] > RUNTIME_MAX[1] or sizes[2] > RUNTIME_MAX[2]:
            return None
        return "@%d:%s:%d:%d:%d" % ((byte, tex) + sizes)
    if w % TEXEL_SPAN or d % TEXEL_SPAN:
        return None
    byte = RUNTIME_SHAPES[kind]
    if h % TEXEL_SPAN:
        if byte != 0 or h not in RUNTIME_FLATS:
            return None
        byte, cells_up = RUNTIME_FLATS[h], 1
    else:
        cells_up = h // TEXEL_SPAN
    across, deep = w // TEXEL_SPAN, d // TEXEL_SPAN
    if across > RUNTIME_MAX[0] or cells_up > RUNTIME_MAX[1] or deep > RUNTIME_MAX[2]:
        return None
    return "@%d:%s:%d:%d:%d" % (byte, tex, across, cells_up, deep)
def row_model(piece):
    return runtime_token(piece) or piece["model"]
JOIN_GAP = 100
JOIN_SIDES = ((1, 0), (0, 1), (-1, 0), (0, -1))
def _box_of(piece):
    x0, x1, z0, z1, _ = footprint(piece)
    return x0, x1, piece["y"], piece["y"] + piece["h"], z0, z1
def connect(pieces):
    joined, grown = 0, 0
    boxes = [(p, _box_of(p)) for p in pieces if p.get("kind") in ("box", "ice", "lava")]
    for p in pieces:
        if p.get("kind") != "pillar" or p.get("tex") not in block_slugs():
            continue
        if (int(p["w"]), int(p["h"]), int(p["d"])) != (200, 200, 200) or p["x"] % 200 \
                or p["z"] % 200 or int(p.get("yaw", 0)) % 360:
            continue
        arms, other = [], None
        for dx, dz in JOIN_SIDES:
            px, pz, py = p["x"] + dx * 101, p["z"] + dz * 101, p["y"] + 100
            hit = None
            for q, (x0, x1, y0, y1, z0, z1) in boxes:
                if x0 < px < x1 and z0 < pz < z1 and y0 < py < y1:
                    hit = q
                    break
            arms.append("1" if hit is not None else "0")
            if hit is not None and other is None:
                other = hit["tex"]
        if "1" in arms:
            p["join"] = {"arms": "".join(arms), "other": other if other != p["tex"] else None}
            joined += 1
    solids = [(q, _box_of(q)) for q in pieces
              if q.get("kind") in ("box", "ice", "lava", "pillar", "rail")
              and q.get("tex") != INVISIBLE]
    for p in pieces:
        if p.get("kind") != "rail":
            continue
        along_x = int(p.get("yaw", 0)) % 180 == 0
        x0, x1, y0, y1, z0, z1 = _box_of(p)
        for end in (-1, 1):
            best = None
            for q, (a0, a1, b0, b1, c0, c1) in solids:
                if q is p or b1 <= y0 or b0 >= y1:
                    continue
                if along_x:
                    if c1 <= z0 or c0 >= z1:
                        continue
                    gap = (a0 - x1) if end > 0 else (x0 - a1)
                else:
                    if a1 <= x0 or a0 >= x1:
                        continue
                    gap = (c0 - z1) if end > 0 else (z0 - c1)
                if 0 < gap < JOIN_GAP and (best is None or gap < best):
                    best = gap
            if best is not None:
                p["w"] += best
                if along_x:
                    p["x"] += end * best / 2.0
                    x0, x1 = (x0, x1 + best) if end > 0 else (x0 - best, x1)
                else:
                    p["z"] += end * best / 2.0
                    z0, z1 = (z0, z1 + best) if end > 0 else (z0 - best, z1)
                grown += 1
    return joined, grown
def model_name(piece):
    if piece.get("tex") == INVISIBLE:
        return NO_MODEL
    def n(v):
        return str(int(round(v)))
    return "%s%s_%s_%s_%s_%s_geo" % (PREFIX, piece["tex"], piece["kind"],
                                     n(piece["w"]), n(piece["h"]), n(piece["d"]))
LO, HI, TOP = -100, 100, 200
CORNER = {
    "A": (LO, 0, LO), "B": (HI, 0, LO), "C": (HI, 0, HI), "D": (LO, 0, HI),
    "E": (LO, TOP, LO), "F": (HI, TOP, LO), "G": (LO, TOP, HI), "H": (HI, TOP, HI),
}
def _flipped(faces):
    out = []
    for corners, normal in faces:
        pts = [CORNER[c] if isinstance(c, str) else c for c in corners]
        out.append(([(x, TOP - y, z) for x, y, z in pts], (normal[0], -normal[1], normal[2])))
    return out
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
    "curve": arc_faces("curve"),
    "bank": arc_faces("bank"),
    "arcwall": arc_faces("arcwall"),
    "water": slopes.box_faces(LO, HI, 0, TOP, LO, HI),
    "ridge": exact_normals(ridge_faces()),
    "pyramid": exact_normals(pyramid_faces()),
    "roundcorner": slopes.round_corner_faces(),
    "ice": slopes.box_faces(LO, HI, 0, TOP, LO, HI),
    "lava": slopes.box_faces(LO, HI, 0, TOP, LO, HI),
    "uslope": _flipped(slopes.SHAPES[0][3]),
    "uouter": _flipped(slopes.SHAPES[1][3]),
    "uinner": _flipped(slopes.SHAPES[2][3]),
    "wedgetip": slopes.wedge_faces(True),
    "wedgetipouter": slopes.wedge_corner_faces(False, True),
    "wedgetipinner": slopes.wedge_corner_faces(True, True),
    "pole": slopes.box_faces(-slopes.POLE_HALF, slopes.POLE_HALF, 0, TOP, -slopes.POLE_HALF,
                             slopes.POLE_HALF),
    "doorway": slopes.union_faces(slopes.doorway_boxes()),
    "window": slopes.union_faces(slopes.window_boxes()),
}
VISUAL_KINDS = ("water",)
FLOORS = {"stairs": slopes.stair_floor_faces(),
          "outerstairs": slopes.corner_stair_floor_faces(False),
          "innerstairs": slopes.corner_stair_floor_faces(True)}
SURFACES = {"box": SURFACE_DEFAULT, "ramp": SURFACE_NOT_SLIPPERY,
            "stairs": SURFACE_NOT_SLIPPERY, "outer": SURFACE_NOT_SLIPPERY,
            "inner": SURFACE_NOT_SLIPPERY, "pillar": SURFACE_DEFAULT,
            "arch": SURFACE_DEFAULT, "prism": SURFACE_DEFAULT, "rail": SURFACE_DEFAULT,
            "outerstairs": SURFACE_NOT_SLIPPERY, "innerstairs": SURFACE_NOT_SLIPPERY,
            "curve": SURFACE_DEFAULT, "bank": SURFACE_NOT_SLIPPERY, "arcwall": SURFACE_DEFAULT,
            "water": SURFACE_DEFAULT, "ice": SURFACE_ICE, "lava": SURFACE_BURNING, "ridge": SURFACE_NOT_SLIPPERY,
            "pyramid": SURFACE_NOT_SLIPPERY, "roundcorner": SURFACE_DEFAULT,
            "uslope": SURFACE_DEFAULT, "uouter": SURFACE_DEFAULT, "uinner": SURFACE_DEFAULT,
            "wedgetip": SURFACE_NOT_SLIPPERY, "wedgetipouter": SURFACE_NOT_SLIPPERY,
            "wedgetipinner": SURFACE_NOT_SLIPPERY, "pole": SURFACE_DEFAULT,
            "doorway": SURFACE_DEFAULT, "window": SURFACE_DEFAULT}
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
    "curve": {"make": "arc(\"curve\")", "walk": "floor",
              "sizes": "square footprints of a road width (600/800/1000/1200)"},
    "bank": {"make": "arc(\"bank\")", "walk": "ramp",
             "sizes": "square, the road width / 0.6 across"},
    "arcwall": {"make": "arc(\"arcwall\")", "walk": "edge",
                "sizes": "square, the road width / 0.9 across"},
    "ridge": {"make": "roof(\"ridge\")", "walk": "ramp",
              "sizes": "a house's footprint, a quarter of its depth high (26.6 degrees)"},
    "pyramid": {"make": "roof(\"pyramid\")", "walk": "ramp",
                "sizes": "square, a quarter of its width high"},
    "roundcorner": {"make": "round_corner", "walk": "column",
                    "sizes": "square quarters of a tower, 400/600/800"},
    "ice": {"make": "ice", "walk": "floor",
            "sizes": "any multiple of 200, as the box (a slippery floor)"},
    "lava": {"make": "lava", "walk": "hazard",
             "sizes": "any multiple of 200, as the box (a burning floor: never stood on)"},
    "water": {"make": "water", "walk": "water",
              "sizes": "a lake's or a river's rectangle, 20 thick (a drawn surface)"},
    "uslope": {"make": "upside(\"uslope\")", "walk": "floor",
               "sizes": "whole cells: a corbel under an eave, 200 x 200 x 200"},
    "uouter": {"make": "upside(\"uouter\")", "walk": "floor",
               "sizes": "whole cells, square: an eave bracket's outer corner"},
    "uinner": {"make": "upside(\"uinner\")", "walk": "floor",
               "sizes": "whole cells, square: an eave bracket's inner corner"},
    "wedgetip": {"make": "wedge_tip(\"wedgetip\")", "walk": "ramp",
                 "sizes": "whole cells: a low roof's skirt (half of it foot)"},
    "wedgetipouter": {"make": "wedge_tip(\"wedgetipouter\")", "walk": "ramp",
                      "sizes": "whole cells, square: a hip skirt's corner"},
    "wedgetipinner": {"make": "wedge_tip(\"wedgetipinner\")", "walk": "ramp",
                      "sizes": "whole cells, square: a valley skirt's corner"},
    "pole": {"make": "pole", "walk": "column",
             "sizes": "one cell across (a 40 post), heights in cells"},
    "doorway": {"make": "opening(\"doorway\")", "walk": "edge",
                "sizes": "one cell (a 140 x 180 door), or whole cells scaled"},
    "window": {"make": "opening(\"window\")", "walk": "edge",
               "sizes": "one cell (a 100 x 80 window), or whole cells scaled"},
}
for _kind, _row in KINDS.items():
    _row["mesh"] = "%s%s_col" % (PREFIX, _kind)
    _row["surface"] = SURFACES[_kind]
def kit_faults():
    faults = []
    by_byte = {v["byte"]: v["tag"] for v in slopes.variants()}
    for kind, byte in sorted(RUNTIME_SHAPES.items()):
        if byte == 0:
            continue
        want = {"ramp": "slope"}.get(kind, kind)
        if by_byte.get(byte) != want:
            faults.append("%s is drawn at run time as byte %d, the Forge's %s"
                          % (kind, byte, by_byte.get(byte)))
    for kind in KINDS:
        if KINDS[kind]["walk"] == "stairs" or kind in VISUAL_KINDS:
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
def face_corners(piece, pts, normal, layered=False):
    real = [scaled(p, piece) for p in pts]
    n = real_normal(pts, piece)
    out = []
    for p, q in zip(pts, real):
        s, t = uv(p, normal, piece)
        if layered and slopes.layer_of(normal) == 1:
            unit = TEX_PX * 32 / float(TEXEL_SPAN)
            t = int(round((slopes.side_top(real, n, q) - q[1]) * unit))
        out.append((q, s, t))
    return out
def kit_textures():
    _, rows = blocks.read_manifest()
    textures, layered = {}, {}
    for row in rows:
        textures[row["slug"]] = blocks.read_texture(os.path.join(ROOT, row["source"]))
        if row.get("layers"):
            layered[row["slug"]] = slopes.row_textures(row)[1]
    for row in rows:
        for old in row.get("was") or ():
            textures.setdefault(old, textures[row["slug"]])
            if row["slug"] in layered:
                layered.setdefault(old, layered[row["slug"]])
    return textures, layered
def build_geo(template_nodes, prefix, png, piece, layers=None):
    faces = solid(piece["kind"], piece=piece)
    if piece["kind"] == "water":
        faces = [f for f in faces if f[1][1] != 0]
    tri_dl = None
    for node in template_nodes:
        if node[0] == 4:
            words = node[2][1][1]
            if any(c[0] == "word" and i % 2 == 0 and (c[1] >> 24) == 0x01
                   for i, c in enumerate(words)):
                tri_dl = node
    if tri_dl is None:
        raise Refused("the cube template has no triangle list to replace")
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
            for p, (q, s, t) in zip(pts, face_corners(piece, pts, normal, layers is not None)):
                if not (-32768 <= s <= 32767 and -32768 <= t <= 32767):
                    raise Refused("%s: a face is longer than %d units"
                                  % (piece_name(piece), LONGEST_FACE))
                at = tuple(int(round(c)) for c in q) if PICTURES_AT_SIZE else p
                if any(not -32768 <= c <= 32767 for c in at):
                    raise Refused("%s: a corner lies outside a picture's s16 range"
                                  % piece_name(piece))
                data += struct.pack("<3hHhh4B", at[0], at[1], at[2], 0, s, t,
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
        raise Refused("the cube template's render tile is not the one this tool "
                      "knows how to make wrap (found %d)" % wrapped)
    if piece["kind"] == "water":
        out = slopes.water_look(out)
    template_prefix = slopes.TEMPLATE_PREFIX
    def rename(name):
        if name.startswith(template_prefix):
            return prefix + name[len(template_prefix):]
        return name
    return blocks.pack_bin(slopes.write_nodes(out, rename))
GENERATED = os.path.join(HERE, "venues-generated")
def generated_arenas():
    out = []
    if not os.path.isdir(GENERATED):
        return out
    for name in sorted(os.listdir(GENERATED)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(GENERATED, name), encoding="utf-8") as handle:
            arena = json.load(handle)
        if "%s.json" % arena.get("key") != name:
            raise Refused("%s: its key is %r" % (name, arena.get("key")))
        arena["_file"] = os.path.join(GENERATED, name)
        out.append(arena)
    course_numbers(out)
    return out
FIRST_BONUS_COURSE = 16
def course_numbers(generated):
    used = set()
    for arena in generated:
        course = arena.get("course")
        if isinstance(course, int) and course >= FIRST_BONUS_COURSE:
            if course in used:
                raise Refused("%s: course %d is another world's too"
                              % (arena.get("key"), course))
            used.add(course)
    for arena in generated:
        if not arena.get("stars") or isinstance(arena.get("course"), int):
            continue
        n = FIRST_BONUS_COURSE
        while n in used:
            n += 1
        used.add(n)
        arena["course"] = n
        arena["_course_new"] = True
def store_course_numbers(all_arenas):
    written = []
    for arena in all_arenas:
        if not arena.get("_course_new") or not arena.get("_file"):
            continue
        with open(arena["_file"], encoding="utf-8") as handle:
            data = json.load(handle)
        data["course"] = arena["course"]
        with open(arena["_file"], "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=1, sort_keys=True)
            handle.write("\n")
        written.append(arena["key"])
    return written
def arenas():
    out = [sky_keep()]
    out += generated_arenas()
    for arena in out:
        connect(arena["pieces"])
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
        box(WALL, 1400, 2000, 0, 400, 1400, 2000, "perch"),
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
        if piece is not None and piece.get("kind") in HAZARD_KINDS:
            continue
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
def _gap_filled(pieces, i, j, px, pz, lo, hi):
    for k, p in enumerate(pieces):
        if k in (i, j):
            continue
        x0, x1, z0, z1, _ = footprint(p)
        if not (x0 < px < x1 and z0 < pz < z1) or not covers(p, px, pz):
            continue
        t = top_at(p, px, pz)
        if t is not None and p["y"] <= lo + 1 and t >= hi - 1:
            return True
    return False
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
    standing = len(pieces)
    if venuebake().wants_bake(arena):
        standing = len(venuebake().split_rows(arena)[1])
    objects = standing + len(arena.get("markers", [])) + len(arena.get("objects", [])) \
        + len(arena.get("movers") or [])
    faults += check_movers(arena)
    faults += check_wires(arena)
    stand = StandIndex(pieces, arena["level"]).at
    for i, thing in enumerate(arena.get("objects", [])):
        if not str(thing.get("key", "")).replace("_", "").isalnum():
            faults.append("object %d: %r is not a Forge key" % (i + 1, thing.get("key")))
        if thing.get("air"):
            continue
        heights = stand(thing["x"], thing["z"])
        if not any(abs(h - thing["y"]) <= 1 for h in heights):
            faults.append("object %d (%s) at (%d, %d, %d) stands on nothing clear"
                          % (i + 1, thing.get("key"), thing["x"], thing["y"], thing["z"]))
    if objects > arena["budget"]:
        faults.append("%d objects against a budget of %d" % (objects, arena["budget"]))
    faults += check_markers(arena)
    for i, spot in enumerate(arena["spawns"]):
        heights = stand(spot["x"], spot["z"])
        if not any(abs(h - spot["y"]) <= 1 for h in heights):
            faults.append("spawn %d at (%d, %d, %d) stands on nothing clear"
                          % (i + 1, spot["x"], spot["y"], spot["z"]))
    feet = [footprint(p) for p in pieces]
    tiles = {}
    for j, (ox0, ox1, oz0, oz1, _) in enumerate(feet):
        for tx in range(int(math.floor(ox0 / 1000)), int(math.floor(ox1 / 1000)) + 1):
            for tz in range(int(math.floor(oz0 / 1000)), int(math.floor(oz1 / 1000)) + 1):
                tiles.setdefault((tx, tz), []).append(j)
    for i, piece in enumerate(pieces):
        x0, x1, z0, z1, _ = feet[i]
        for px, pz in (((x0 + x1) / 2, (z0 + z1) / 2), (x0 + 50, z0 + 50), (x1 - 50, z1 - 50),
                       (x0 + 50, z1 - 50), (x1 - 50, z0 + 50)):
            top = top_at(piece, px, pz)
            if top is None:
                continue
            for j in tiles.get((int(math.floor(px / 1000)), int(math.floor(pz / 1000))), ()):
                if j == i:
                    continue
                other = pieces[j]
                ox0, ox1, oz0, oz1, _ = feet[j]
                if ox0 < px < ox1 and oz0 < pz < oz1 and covers(other, px, pz):
                    gap = other["y"] - top
                    if 1 < gap < MARIO_TALL and not _gap_filled(pieces, i, j, px, pz, top,
                                                                other["y"]):
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
            heights = stand(spot["x"], spot["z"])
            if not any(abs(h - spot["y"]) <= 1 for h in heights):
                faults.append("survey %s %d at (%d, %d, %d) stands on nothing clear"
                              % (key, i + 1, spot["x"], spot["y"], spot["z"]))
    if len(arena["spawns"]) < 16:
        faults.append("%d spawns for sixteen players" % len(arena["spawns"]))
    if not faults:
        faults += check_walks(arena)
    return faults
MOVER_MAX_POINTS = 12
MOVER_TOP = {"blk": 200, "slab": 100, "uslab": 100, "plate": 20, "uplate": 20,
             "log": 150, "logwide": 150}
MOVER_BOARD = 400
MOVER_NEAR = 6
def mover_top(key):
    rest = str(key)[2:]
    if rest in MOVER_TOP:
        return MOVER_TOP[rest]
    for shape in sorted(MOVER_TOP, key=len, reverse=True):
        if rest.startswith(shape):
            return MOVER_TOP[shape]
    return 200
def mover_stops(mover):
    top = mover_top(mover.get("key"))
    out = []
    for p in mover.get("points") or []:
        out.append((mover["x"] + p[0], mover["y"] + p[1] + top, mover["z"] + p[2]))
    return out
def mover_edges(arena, cells):
    out = {}
    movers = arena.get("movers") or []
    if not movers:
        return out
    by_column = {}
    for c in cells:
        by_column.setdefault((c[0], c[1]), []).append(c)
    reach = int(math.ceil(MOVER_BOARD / GRID))
    for mover in movers:
        boards, alights = [], []
        for (sx, sy, sz) in mover_stops(mover):
            gx0, gz0 = int(math.floor(sx / GRID)), int(math.floor(sz / GRID))
            on, off = [], []
            for gx in range(gx0 - reach, gx0 + reach + 1):
                for gz in range(gz0 - reach, gz0 + reach + 1):
                    d = math.hypot(gx * GRID + GRID / 2 - sx, gz * GRID + GRID / 2 - sz)
                    if d > MOVER_BOARD:
                        continue
                    for c in by_column.get((gx, gz), ()):
                        rise = sy - c[2]
                        if rise <= JUMP_UP and -rise <= SAFE_DROP:
                            on.append((d, c))
                        if -rise <= JUMP_UP and rise <= SAFE_DROP:
                            off.append((d, c))
            boards.append([c for _, c in sorted(on)[:MOVER_NEAR]])
            alights.append([c for _, c in sorted(off)[:MOVER_NEAR]])
        for i, on in enumerate(boards):
            for j, off in enumerate(alights):
                if i == j:
                    continue
                for a in on:
                    for b in off:
                        if a != b:
                            out.setdefault(a, []).append(b)
    return out
def check_movers(arena):
    faults = []
    level = LEVELS[arena["level"]]
    for i, mover in enumerate(arena.get("movers") or []):
        key = str(mover.get("key", ""))
        name = "mover %d (%s)" % (i + 1, key)
        if not key.startswith("mv") or not key.isalnum():
            faults.append("%s: not a mover key" % name)
        points = mover.get("points") or []
        if not 2 <= len(points) <= MOVER_MAX_POINTS:
            faults.append("%s: %d points (2 to %d)" % (name, len(points), MOVER_MAX_POINTS))
        if points and any(points[0][k] != 0 for k in range(3)):
            faults.append("%s: its first point is not where it stands" % name)
        for (x, y, z) in mover_stops(mover):
            if max(abs(x), abs(z)) > min(BOUND, level["half"]):
                faults.append("%s leaves the level" % name)
                break
            if y < level["plane"] + 2048:
                faults.append("%s runs within the death barrier's reach" % name)
                break
    return faults
WIRE_EVENTS = ("pressed", "entered", "left", "hit", "alldown", "timer")
WIRE_ACTIONS = ("raise", "start", "flip", "timer_start", "timer_stop", "message", "finish")
WIRE_MAX = 31
def check_wires(arena):
    faults = []
    for i, w in enumerate(arena.get("wires") or []):
        name = "wire %d" % (i + 1)
        if w.get("on") not in WIRE_EVENTS:
            faults.append("%s: no event %r" % (name, w.get("on")))
        if w.get("act") not in WIRE_ACTIONS:
            faults.append("%s: no action %r" % (name, w.get("act")))
        top = 3600 if w.get("on") == "timer" else WIRE_MAX
        if not 0 <= int(w.get("src", 0)) <= top or not 0 <= int(w.get("dst", 0)) <= WIRE_MAX:
            faults.append("%s: a number out of range" % name)
    return faults
_WALK_CELLS = []
_WALK_CELLS_KEEP = 4
_WALK_CELLS_PATCH = 48
def _walk_row(p):
    return (p["kind"], p["x"], p["y"], p["z"], p["w"], p["h"], p["d"], p["yaw"])
def _walk_points(pieces, level, points):
    tile = 1000
    buckets = {}
    for piece in pieces:
        x0, x1, z0, z1, _ = footprint(piece)
        rect = (x0, x1, z0, z1)
        for tx in range(int(math.floor(x0 / tile)), int(math.floor(x1 / tile)) + 1):
            for tz in range(int(math.floor(z0 / tile)), int(math.floor(z1 / tile)) + 1):
                buckets.setdefault((tx, tz), []).append((piece, rect))
    cells = {}
    for gx, gz in points:
        x, z = gx * GRID + GRID / 2, gz * GRID + GRID / 2
        near = buckets.get((int(math.floor(x / tile)), int(math.floor(z / tile))), ())
        here = [p for p, (x0, x1, z0, z1) in near if x0 <= x <= x1 and z0 <= z <= z1]
        for h in standable(here, x, z, level):
            cells[(gx, gz, h)] = True
    return cells
def _walk_grid(rect):
    lo_x, hi_x, lo_z, hi_z = rect
    gx = int(math.floor(lo_x / GRID))
    while gx * GRID <= hi_x:
        gz = int(math.floor(lo_z / GRID))
        while gz * GRID <= hi_z:
            yield gx, gz
            gz += 1
        gx += 1
def _walk_under(row):
    fake = {"kind": row[0], "x": row[1], "y": row[2], "z": row[3], "w": row[4],
            "h": row[5], "d": row[6], "yaw": row[7]}
    x0, x1, z0, z1, _ = footprint(fake)
    out = []
    for gx in range(int(math.floor(x0 / GRID)) - 1, int(math.floor(x1 / GRID)) + 1):
        cx = gx * GRID + GRID / 2
        if not x0 <= cx <= x1:
            continue
        for gz in range(int(math.floor(z0 / GRID)) - 1, int(math.floor(z1 / GRID)) + 1):
            cz = gz * GRID + GRID / 2
            if z0 <= cz <= z1:
                out.append((gx, gz))
    return out
class StandIndex:
    TILE = 1000
    def __init__(self, pieces, level):
        self.level = level
        self.buckets = {}
        self.memo = {}
        for piece in pieces:
            x0, x1, z0, z1, _ = footprint(piece)
            for tx in range(int(math.floor(x0 / self.TILE)), int(math.floor(x1 / self.TILE)) + 1):
                for tz in range(int(math.floor(z0 / self.TILE)),
                                int(math.floor(z1 / self.TILE)) + 1):
                    self.buckets.setdefault((tx, tz), []).append((piece, (x0, x1, z0, z1)))
    def at(self, x, z):
        key = (x, z)
        if key not in self.memo:
            near = self.buckets.get((int(math.floor(x / self.TILE)),
                                     int(math.floor(z / self.TILE))), ())
            here = [p for p, (x0, x1, z0, z1) in near if x0 <= x <= x1 and z0 <= z <= z1]
            self.memo[key] = standable(here, x, z, self.level)
        return self.memo[key]
def walk_cells(pieces, level):
    rows = [_walk_row(p) for p in pieces]
    key = (level, tuple(rows))
    for k, _, _, v in _WALK_CELLS:
        if k == key:
            return v
    play = [p for p in pieces if not str(p.get("tag", "")).startswith("dress.backdrop")]
    rects = [footprint(p)[:4] for p in (play or pieces)]
    bounds = (min(r[0] for r in rects), max(r[1] for r in rects),
              min(r[2] for r in rects), max(r[3] for r in rects))
    have = collections.Counter(rows)
    cells = None
    for k, old_have, old_bounds, old in _WALK_CELLS:
        if k[0] != level or old_bounds != bounds:
            continue
        added, gone = have - old_have, old_have - have
        if sum(added.values()) + sum(gone.values()) > _WALK_CELLS_PATCH:
            continue
        changed = set()
        for row in list(added) + list(gone):
            changed.update(_walk_under(row))
        merged = _walk_points(pieces, level, sorted(changed))
        for c in old:
            if (c[0], c[1]) not in changed:
                merged[c] = True
        cells = {c: True for c in sorted(merged)}
        break
    if cells is None:
        cells = _walk_points(pieces, level, _walk_grid(bounds))
    _WALK_CELLS.insert(0, (key, have, bounds, cells))
    del _WALK_CELLS[_WALK_CELLS_KEEP:]
    return cells
def walk_graph(arena):
    pieces = arena["pieces"]
    cells = dict(walk_cells(pieces, arena["level"]))
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
    for a, outs in mover_edges(arena, cells).items():
        edges.setdefault(a, []).extend(outs)
    for a, outs in cannon_edges(arena, cells).items():
        edges.setdefault(a, []).extend(outs)
    for a, outs in swim_edges(arena, cells).items():
        edges.setdefault(a, []).extend(outs)
    for a, outs in warp_edges(arena, cells).items():
        edges.setdefault(a, []).extend(outs)
    return cells, edges
def warp_edges(arena, cells):
    out = {}
    for pk in arena.get("pockets") or ():
        if not isinstance(pk, dict) or len(pk.get("shift") or ()) != 3:
            continue
        dx, dy, dz = (int(round(v)) for v in pk["shift"])
        for key, sign in (("door", 1), ("exit", -1)):
            r = pk.get(key)
            if not r or len(r) != 5:
                continue
            x0, z0, x1, z1, y = r
            for gx in range(int(math.floor(x0 / GRID)), int(math.ceil(x1 / GRID))):
                for gz in range(int(math.floor(z0 / GRID)), int(math.ceil(z1 / GRID))):
                    a = (gx, gz, int(round(y)))
                    b = (gx + sign * dx // GRID, gz + sign * dz // GRID, int(round(y + sign * dy)))
                    if a in cells and b in cells:
                        out.setdefault(a, []).append(b)
    return out
SWIM_OUT = 100
def swim_edges(arena, cells):
    out = {}
    for k, w in enumerate(arena.get("water") or []):
        if len(w) < 5:
            continue
        x0, z0, x1, z1, top = w[:5]
        node = (-1000000 - k, 0, int(top))
        wet, dry = [], []
        for c in cells:
            cx, cz = c[0] * GRID + GRID / 2, c[1] * GRID + GRID / 2
            if x0 < cx < x1 and z0 < cz < z1 and c[2] < top:
                wet.append(c)
            elif x0 - GRID < cx < x1 + GRID and z0 - GRID < cz < z1 + GRID \
                    and top <= c[2] <= top + SWIM_OUT:
                dry.append(c)
        if not wet:
            continue
        out[node] = wet + dry
        for c in wet + dry:
            out.setdefault(c, []).append(node)
    return out
CANNON_SHAFT = 300
CANNON_OUT = 800
CANNON_RISE = 340
def cannon_edges(arena, cells):
    out = {}
    for o in arena.get("objects") or []:
        if not str(o.get("key") or "").startswith("cannon"):
            continue
        x, y, z = o["x"], o.get("y", 0), o["z"]
        shaft = [c for c in cells if abs(c[2] - y) <= 30
                 and math.hypot(c[0] * GRID + GRID / 2 - x, c[1] * GRID + GRID / 2 - z) <= CANNON_SHAFT]
        land = [c for c in cells if y + 100 < c[2] <= y + CANNON_RISE + JUMP_UP
                and math.hypot(c[0] * GRID + GRID / 2 - x, c[1] * GRID + GRID / 2 - z) <= CANNON_OUT]
        for a in shaft:
            out.setdefault(a, []).extend(land)
    return out
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
        if p["tex"] == INVISIBLE:
            d.rectangle([px(x0, z0), px(x1, z1)], outline=(120, 200, 255))
            continue
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
def lua_text(text):
    t = "".join(ch for ch in str(text) if 32 <= ord(ch) < 127)[:40]
    return '"%s"' % t.replace("\\", "\\\\").replace('"', '\\"')
def num(v):
    v = round(v, 3)
    if v == int(v):
        return str(int(v))
    return repr(v)
def solids_faults(arena):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import solids
    return solids.faults(arena, limit=1000)
ARENA_LUA = os.path.join(ROOT, "of_arena.lua")
def offered_venue_rows():
    import re
    with open(ARENA_LUA, encoding="utf-8") as handle:
        text = handle.read()
    out = {}
    for row in re.finditer(r"\{\s*key = \"(\w+)\".*?\n    \},", text, re.S):
        body = row.group(0)
        if "venue = true" not in body:
            continue
        only = re.search(r"onlyFor = \{([^}]*)\}", body)
        modes = re.findall(r"\"(\w+)\"", only.group(1)) if only else ["(every mode)"]
        if modes:
            out[row.group(1)] = modes
    return out
def gate_faults(all_arenas):
    offered = offered_venue_rows()
    out = []
    for arena in all_arenas:
        n = len(arena.get("solids", []))
        if n and arena["key"] in offered:
            out.append("%s: offered to %s with %d overlap/coplanar fault(s) - a venue whose "
                       "solids share space is offered to no mode (first: %s)"
                       % (arena["key"], ", ".join(offered[arena["key"]]), n,
                          arena["solids"][0]))
    return out
def lua_table(all_arenas):
    lines = [BEGIN, "venues.PICTURES_AT_SIZE = %s" % ("true" if PICTURES_AT_SIZE else "false"),
             "venues.LAYOUTS = {"]
    for arena in all_arenas:
        lines.append("    %s = {" % arena["key"])
        lines.append('        level = "%s", budget = %d, faults = %d,'
                     % (arena["level"], arena["budget"], len(arena.get("solids", []))))
        if arena.get("stars") and isinstance(arena.get("course"), int):
            lines.append("        course = %d," % arena["course"])
        if arena.get("stars") and arena.get("coinStar") is True:
            lines.append("        coinStar = true,")
        look = arena["look"]
        extra = ""
        light = look.get("light")
        if isinstance(light, dict):
            light = light.get("dir")
        if isinstance(light, (list, tuple)) and len(light) == 3:
            extra += ", light = { %s, %s, %s }" % tuple(num(v) for v in light)
        if isinstance(look.get("dark"), int) and look["dark"] > 0:
            extra += ", dark = %d" % look["dark"]
        bake = look.get("bake")
        if isinstance(bake, dict):
            bake = venuebake()._bake_module().current(bake)
        if bake is False:
            extra += ", bake = false"
        elif isinstance(bake, dict) and all(isinstance(bake.get(k), (list, tuple))
                                            and len(bake[k]) == 3
                                            for k in ("sun", "sunc", "sky", "gnd")):
            keys = ("sun", "sunc", "sky", "gnd") + tuple(
                k for k in ("lo", "hi", "sun0")
                if isinstance(bake.get(k), (list, tuple)) and len(bake[k]) == 3)
            extra += ", bake = { %s }" % ", ".join(
                "%s = { %s }" % (k, ", ".join(num(round(float(c), 3)) for c in bake[k]))
                for k in keys)
            if isinstance(look.get("sun"), dict):
                extra += ", sun = true"
            hb = look.get("hourBaked")
            if isinstance(hb, (list, tuple)) and len(hb) == 3:
                extra += ", hourBaked = { %s, %s, %s }" % tuple(num(round(float(c), 4)) for c in hb)
        vis = look.get("visuals") or []
        if vis:
            extra += ", visuals = { %s }" % ", ".join('{ "%s", "%s" }' % (row, stop)
                                                      for row, stop in vis)
        if isinstance(look.get("mood"), dict):
            from mapgen import mood as moodmod
            extra += moodmod.lua_fields(look)
        lines.append('        look = { sky = "%s", music = "%s"%s },' % (look["sky"], look["music"],
                                                                        extra))
        runtime = list(range(len(arena["pieces"])))
        static = []
        vb = venuebake()
        lean = lean_static(arena)
        if vb.wants_bake(arena):
            static, runtime = vb.split_rows(arena)
            lines.append("        baked = true,")
            lines += vb.light_lines(arena, static, "        ")
            if lean:
                lines.append("        lean = true, staticCount = %d," % len(static))
                static = []
        def rows(name, indexes):
            lines.append("        %s = {" % name)
            for i in indexes:
                p = arena["pieces"][i]
                kind = "decor" if p.get("decor") and p.get("pass") else p["kind"]
                lines.append('            { "%s", "%s", %s, %s, %s, %s, %s, %s, %s },'
                             % (kind, row_model(p), num(p["x"]), num(p["y"]), num(p["z"]),
                                num(p["w"]), num(p["h"]), num(p["d"]), num(p["yaw"])))
            lines.append("        },")
        lines.append("        -- kind, model, x, y, z, width, height, depth, yaw (degrees)")
        rows("pieces", runtime)
        if static:
            lines.append("        -- the still pieces its level carries (the same columns)")
            rows("static", static)
        lines.append("        -- x, y, z, yaw (degrees)")
        lines.append("        spawns = {")
        for s in arena["spawns"]:
            lines.append("            { %s, %s, %s, %s }," % (num(s["x"]), num(s["y"]),
                                                            num(s["z"]), num(s["yaw"])))
        lines.append("        },")
        w = arena.get("world")
        if isinstance(w, dict) and "x" in w and "z" in w:
            lines.append("        world = { %s, %s, %s, %s }," % (
                num(w["x"]), num(w.get("y", 0)), num(w["z"]), num(w.get("yaw", 0))))
        if arena.get("markers"):
            lines.append("        -- the race's track markers: kind, number, a, b, x, y, z, yaw")
            lines.append("        markers = {")
            for m in arena["markers"]:
                lines.append("            { %d, %d, %d, %d, %s, %s, %s, %s },"
                             % (m["kind"], m["num"], m["a"], m["b"], num(m["x"]),
                                num(m["y"]), num(m["z"]), num(m["yaw"])))
            lines.append("        },")
        if HERE not in sys.path:
            sys.path.insert(0, HERE)
        from mapgen import basins as _basins
        waters = _basins.real_water(arena, LEVELS.get(arena.get("level"), {}).get("floor"))
        waters = waters + venuebake().sheet_rows(arena, waters)
        if waters:
            lines.append("        -- water: x0, z0, x1, z1, surface height, bottom")
            lines.append("        water = {")
            for w in waters:
                w = list(w) + [None] * (6 - len(w))
                if w[5] is None:
                    w[5] = w[4] - 400
                lines.append("            { %s, %s, %s, %s, %s, %s }," % tuple(num(v) for v in w))
            lines.append("        },")
        if arena.get("stars"):
            lines.append("        -- bonus stars: x, y, z, grade (1 easy .. 4 tricky), kind, name")
            lines.append("        stars = {")
            for st in sorted(arena["stars"], key=lambda st: st.get("id") or 99):
                lines.append('            { %s, %s, %s, %d, "%s", %s },'
                             % (num(st["x"]), num(st["y"]), num(st["z"]), int(st["grade"]),
                                st["kind"], lua_text(st.get("name") or "")))
            lines.append("        },")
        if arena.get("objects"):
            lines.append("        -- Forge objects: key, x, y, z, yaw (degrees); modes whose "
                         "rounds use them")
            lines.append("        objects = {")
            for o in arena["objects"]:
                modes = o.get("modes") or []
                extra = ""
                if o.get("variant"):
                    extra += ", variant = %d" % int(o["variant"])
                if o.get("pitch"):
                    extra += ", pitch = %s" % num(o["pitch"])
                if o.get("link"):
                    extra += ", link = %d" % int(o["link"])
                if str(o.get("key", "")).startswith("race"):
                    if o.get("track"):
                        extra += ", track = %d" % int(o["track"])
                    order = o.get("order", (o.get("forge") or {}).get("byte"))
                    if o.get("key") == "racegate" and order:
                        extra += ", order = %d" % int(order)
                    meta = o.get("track_meta") or o.get("meta")
                    if o.get("key") == "racestart" and isinstance(meta, dict):
                        kind = "race" if meta.get("kind") == "race" else "speedrun"
                        extra += ', meta = { name = %s, kind = "%s", laps = %d }' % (
                            lua_text(str(meta.get("name") or "")), kind,
                            int(meta.get("laps") or 3))
                if isinstance(o.get("pipe"), dict):
                    extra += ", pipe = { %s }" % ", ".join(
                        "%s = %d" % (k, int(o["pipe"][k])) for k in
                        ("kind", "level", "area", "tag", "pair") if o["pipe"].get(k) is not None)
                lines.append('            { "%s", %s, %s, %s, %s%s%s },'
                             % (o["key"], num(o["x"]), num(o["y"]), num(o["z"]),
                                num(o.get("yaw", 0)), extra,
                                (", modes = { %s }" % ", ".join('"%s"' % m for m in modes))
                                if modes else ""))
            lines.append("        },")
        if arena.get("movers"):
            lines.append("        -- movers: key, x, y, z, yaw (degrees), way round, start, phase "
                         "(frames), points { dx, dy, dz, speed, wait }")
            lines.append("        movers = {")
            for mv in arena["movers"]:
                modes = mv.get("modes") or []
                pts = ", ".join("{ %s }" % ", ".join(num(v) for v in p[:5]) for p in mv["points"])
                lines.append('            { "%s", %s, %s, %s, %s, "%s", "%s", %d, { %s }%s%s },'
                             % (mv["key"], num(mv["x"]), num(mv["y"]), num(mv["z"]),
                                num(mv.get("yaw", 0)), mv.get("mode", "pingpong"),
                                mv.get("trigger", "always"), int(mv.get("phase", 0)), pts,
                                (", modes = { %s }" % ", ".join('"%s"' % m for m in modes))
                                if modes else "",
                                (", link = %d" % int(mv["link"])) if mv.get("link") else ""))
            lines.append("        },")
        if arena.get("wires"):
            lines.append("        -- wires: event, source number, action, target number, words")
            lines.append("        wires = {")
            for w in arena["wires"]:
                arg = w.get("arg")
                lines.append('            { "%s", %d, "%s", %d%s },'
                             % (w["on"], int(w.get("src", 0)), w["act"], int(w.get("dst", 0)),
                                (", %s" % lua_text(str(arg))) if arg not in (None, "") else ""))
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
_venuebake = None
def lean_static(arena):
    vb = venuebake()
    if not vb.wants_bake(arena) or arena.get("fallback") is True:
        return set()
    return set(vb.split_rows(arena)[0])
def venuebake():
    global _venuebake
    if _venuebake is None:
        spec = importlib.util.spec_from_file_location(
            "make_arenas_venuebake", os.path.join(HERE, "venuebake.py"))
        _venuebake = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_venuebake)
    return _venuebake
def lua_meshes():
    import re
    with open(LUA, encoding="utf-8") as handle:
        text = handle.read()
    at = text.find("venues.MESH = {")
    body = text[at:text.find("}", at)]
    return dict(re.findall(r'(\w+) = "(\w+)"', body))
def luaregion():
    import importlib.util
    import sys
    if "of_luaregion" not in sys.modules:
        spec = importlib.util.spec_from_file_location(
            "of_luaregion", os.path.join(HERE, "luaregion.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules["of_luaregion"] = module
    return sys.modules["of_luaregion"]
def mod_root():
    return os.path.dirname(os.path.abspath(LUA))
def splice(text, table):
    text = luaregion().restore(text, "of_venues.lua")
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
    textures, layered = kit_textures()
    all_arenas = arenas()
    faults = kit_faults()
    meshes = lua_meshes()
    for kind in SOLIDS:
        if kind in VISUAL_KINDS:
            if kind in meshes:
                faults.append("of_venues.lua's venues.MESH names %s, which is drawn only"
                              % kind)
            continue
        if meshes.get(kind) != "%s%s_col" % (PREFIX, kind):
            faults.append("of_venues.lua's venues.MESH has no %s = \"%s%s_col\""
                          % (kind, PREFIX, kind))
    for arena in all_arenas:
        arena["solids"] = solids_faults(arena)
    faults += gate_faults(all_arenas)
    for arena in all_arenas:
        for fault in check_layout(arena):
            faults.append("%s: %s" % (arena["key"], fault))
        for piece in arena["pieces"]:
            if piece["tex"] not in textures and piece["tex"] != INVISIBLE:
                faults.append("%s: no block texture %r" % (arena["key"], piece["tex"]))
            if piece["tex"] == "brick":
                faults.append("%s: the plain Brick block is not used in an arena"
                              % arena["key"])
    if faults:
        raise Refused("; ".join(faults))
    files = {}
    for kind in SOLIDS:
        if kind in VISUAL_KINDS:
            continue
        files["%s%s_col.col" % (PREFIX, kind)] = build_col(kind)
    for arena in all_arenas:
        lean = lean_static(arena)
        for index, piece in enumerate(arena["pieces"]):
            if piece["model"] == NO_MODEL:
                continue
            if index in lean:
                continue
            if runtime_token(piece) is not None:
                continue
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
        new_text = luaregion().finish(splice(text, table), mod_root())
    except Refused as why:
        print("make-arenas: %s" % why)
        return 1
    stale = sorted(name for name in os.listdir(ACTORS)
                   if name.startswith(PREFIX) and name not in files)
    differ = []
    for name, data in sorted(files.items()):
        path = os.path.join(ACTORS, name)
        have = None
        if os.path.exists(path):
            with open(path, "rb") as handle:
                have = handle.read()
        if have != data:
            differ.append(name)
    lua_stale = new_text != text
    pictures = [arena["key"] + ".png" for arena in all_arenas]
    drawn = not luaregion().is_release(mod_root())
    missing_pictures = [p for p in pictures if drawn
                        and not os.path.exists(os.path.join(PICTURES, p))]
    if check:
        faults = []
        unnumbered = [a["key"] for a in all_arenas if a.get("_course_new")]
        if unnumbered:
            faults.append("%d world(s) with bonus stars have no stored course number, first %s"
                          % (len(unnumbered), unnumbered[0]))
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
    for key in store_course_numbers(all_arenas):
        print("make-arenas: %s - its course number is stored in its file" % key)
    for name in differ:
        with open(os.path.join(ACTORS, name), "wb") as handle:
            handle.write(files[name])
    for name in stale:
        os.remove(os.path.join(ACTORS, name))
    if lua_stale:
        with open(LUA, "w", encoding="utf-8") as handle:
            handle.write(new_text)
    if drawn:
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
