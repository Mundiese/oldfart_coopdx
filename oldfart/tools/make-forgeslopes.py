#!/usr/bin/env python3
import importlib.util
import math
import os
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
SPAWNER = os.path.join(ROOT, "of_spawner.lua")
_spec = importlib.util.spec_from_file_location(
    "make_blocks", os.path.join(HERE, "make-blocks.py"))
blocks = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(blocks)
Refused = blocks.Refused
POINTER, FUNCTION, LUA_VAR = blocks.POINTER, blocks.FUNCTION, blocks.LUA_VAR
PREFIX = "of_slp_"
DATA_TYPE_COLLISION = 11
COL_INIT, COL_TRI_STOP, COL_END = 0x40, 0x41, 0x42
SURFACE_NOT_SLIPPERY = 0x0015
FLOOR_LINE = 0.01
LO, HI, TOP = -100, 100, 200
P = {
    "A": (LO, 0, LO), "B": (HI, 0, LO), "C": (HI, 0, HI), "D": (LO, 0, HI),
    "E": (LO, TOP, LO), "F": (HI, TOP, LO), "G": (LO, TOP, HI),
}
SHAPES = [
    ("slope", "Slopes", "slope", [
        ("DCFE", (0, 1, 1)),
        ("ABFE", (0, 0, -1)),
        ("ABCD", (0, -1, 0)),
        ("ADE", (-1, 0, 0)),
        ("BCF", (1, 0, 0)),
    ]),
    ("outer", "Outer corners", "outer corner", [
        ("EBC", (1, 1, 0)),
        ("ECD", (0, 1, 1)),
        ("ABE", (0, 0, -1)),
        ("ADE", (-1, 0, 0)),
        ("ABCD", (0, -1, 0)),
    ]),
    ("inner", "Inner corners", "inner corner", [
        ("EFC", (0, 1, 1)),
        ("EGC", (1, 1, 0)),
        ("ABFE", (0, 0, -1)),
        ("ADGE", (-1, 0, 0)),
        ("DCG", (0, 0, 1)),
        ("BCF", (1, 0, 0)),
        ("ABCD", (0, -1, 0)),
    ]),
]
STEPS = 10
RISE = TOP // STEPS
RUN = (HI - LO) // STEPS
WALL_REACH = 30
def stair_risers(faces):
    out = []
    for pts, n in faces:
        if n[1] == 0 and len(pts) == 4:
            low, high = min(p[1] for p in pts), max(p[1] for p in pts)
            if high - low < TOP:
                out.append(high - low)
    return out
def stair_faces():
    faces = []
    for k in range(1, STEPS + 1):
        front, back = HI - RUN * (k - 1), HI - RUN * k
        y0, y1 = RISE * (k - 1), RISE * k
        faces.append(([(LO, y0, front), (HI, y0, front), (HI, y1, front), (LO, y1, front)],
                      (0, 0, 1)))
        faces.append(([(LO, y1, front), (HI, y1, front), (HI, y1, back), (LO, y1, back)],
                      (0, 1, 0)))
    for x, out in ((LO, -1), (HI, 1)):
        profile = [(x, 0, LO), (x, 0, HI)]
        for k in range(1, STEPS + 1):
            front, back = HI - RUN * (k - 1), HI - RUN * k
            profile += [(x, RISE * k, front), (x, RISE * k, back)]
        faces.append((profile, (out, 0, 0)))
    faces.append(([P["A"], P["B"], P["F"], P["E"]], (0, 0, -1)))
    faces.append(([P["A"], P["B"], P["C"], P["D"]], (0, -1, 0)))
    return faces
def stair_floor_faces():
    nose = HI - RUN * (STEPS - 1)
    return [
        ([(LO, 0, HI), (HI, 0, HI), (HI, RISE, HI), (LO, RISE, HI)], (0, 0, 1)),
        ([(LO, RISE, HI), (HI, RISE, HI), (HI, TOP, nose), (LO, TOP, nose)], (0, 1, 1)),
        ([(LO, TOP, nose), (HI, TOP, nose), (HI, TOP, LO), (LO, TOP, LO)], (0, 1, 0)),
        ([(LO, 0, LO), (LO, 0, HI), (LO, RISE, HI), (LO, TOP, nose), (LO, TOP, LO)], (-1, 0, 0)),
        ([(HI, 0, LO), (HI, 0, HI), (HI, RISE, HI), (HI, TOP, nose), (HI, TOP, LO)], (1, 0, 0)),
        ([P["A"], P["B"], P["F"], P["E"]], (0, 0, -1)),
        ([P["A"], P["B"], P["C"], P["D"]], (0, -1, 0)),
    ]
def _edges():
    return [None] + [HI - RUN * (k - 1) for k in range(1, STEPS + 2)]
def _stair_side(x=None, z=None):
    e = _edges()
    flat = [(LO, 0), (HI, 0)]
    for k in range(1, STEPS + 1):
        flat += [(e[k], RISE * k), (e[k + 1], RISE * k)]
    if x is not None:
        return ([(x, y, w) for w, y in flat], (-1 if x == LO else 1, 0, 0))
    return ([(w, y, z) for w, y in flat], (0, 0, -1 if z == LO else 1))
def corner_stair_faces(inner):
    e = _edges()
    faces = [([P["A"], P["B"], P["C"], P["D"]], (0, -1, 0))]
    for k in range(1, STEPS + 1):
        y0, y1, a, b = RISE * (k - 1), RISE * k, e[k], e[k + 1]
        if not inner:
            faces.append(([(LO, y0, a), (a, y0, a), (a, y1, a), (LO, y1, a)], (0, 0, 1)))
            faces.append(([(a, y0, LO), (a, y0, a), (a, y1, a), (a, y1, LO)], (1, 0, 0)))
            if k < STEPS:
                tread = [(b, y1, b), (b, y1, LO), (a, y1, LO), (a, y1, a), (LO, y1, a), (LO, y1, b)]
            else:
                tread = [(LO, y1, LO), (a, y1, LO), (a, y1, a), (LO, y1, a)]
        else:
            if k > 1:
                faces.append(([(a, y0, a), (HI, y0, a), (HI, y1, a), (a, y1, a)], (0, 0, 1)))
                faces.append(([(a, y0, a), (a, y0, HI), (a, y1, HI), (a, y1, a)], (1, 0, 0)))
            if k < STEPS:
                tread = [(a, y1, a), (a, y1, HI), (b, y1, HI), (b, y1, b), (HI, y1, b), (HI, y1, a)]
                if k == 1:
                    tread = [(b, y1, b), (HI, y1, b), (HI, y1, HI), (b, y1, HI)]
            else:
                tread = [(a, y1, a), (a, y1, HI), (LO, y1, HI), (LO, y1, LO), (HI, y1, LO),
                         (HI, y1, a)]
        faces.append((tread, (0, 1, 0)))
    if not inner:
        faces += [_stair_side(x=LO), _stair_side(z=LO)]
    else:
        faces += [_stair_side(x=HI), _stair_side(z=HI)]
        faces.append(([P["A"], P["D"], P["G"], P["E"]], (-1, 0, 0)))
        faces.append(([P["A"], P["B"], P["F"], P["E"]], (0, 0, -1)))
    return faces
def corner_stair_floor_faces(inner):
    n = HI - RUN * (STEPS - 1)
    faces = [([P["A"], P["B"], P["C"], P["D"]], (0, -1, 0))]
    side_x = [(0, LO), (0, HI), (RISE, HI), (TOP, n), (TOP, LO)]
    if not inner:
        faces += [
            ([(HI, RISE, LO), (HI, RISE, HI), (n, TOP, n), (n, TOP, LO)], (1, 1, 0)),
            ([(LO, RISE, HI), (HI, RISE, HI), (n, TOP, n), (LO, TOP, n)], (0, 1, 1)),
            ([(LO, TOP, LO), (n, TOP, LO), (n, TOP, n), (LO, TOP, n)], (0, 1, 0)),
            ([(LO, 0, HI), (HI, 0, HI), (HI, RISE, HI), (LO, RISE, HI)], (0, 0, 1)),
            ([(HI, 0, LO), (HI, 0, HI), (HI, RISE, HI), (HI, RISE, LO)], (1, 0, 0)),
            ([(LO, y, w) for y, w in side_x], (-1, 0, 0)),
            ([(w, y, LO) for y, w in side_x], (0, 0, -1)),
        ]
    else:
        faces += [
            ([(HI, RISE, HI), (HI, TOP, n), (n, TOP, n)], (0, 1, 1)),
            ([(HI, RISE, HI), (n, TOP, n), (n, TOP, HI)], (1, 1, 0)),
            ([(n, TOP, n), (n, TOP, HI), (LO, TOP, HI), (LO, TOP, LO), (HI, TOP, LO), (HI, TOP, n)],
             (0, 1, 0)),
            ([(HI, y, w) for y, w in side_x], (1, 0, 0)),
            ([(w, y, HI) for y, w in side_x], (0, 0, 1)),
            ([P["A"], P["D"], P["G"], P["E"]], (-1, 0, 0)),
            ([P["A"], P["B"], P["F"], P["E"]], (0, 0, -1)),
        ]
    return faces
SHAPES_UPRIGHT_ONLY = [
    ("stairs", "Stairs", "stairs", stair_faces(), stair_floor_faces()),
]
WALL_THICK = 50
FENCE_THICK = 40
FENCE_HIGH = 160
PILLAR_HALF = 60
PILLAR_CUT = 25
ARCH_SEGMENTS = 8
ARCH_RADIUS = 100
def box_faces(x0, x1, y0, y1, z0, z1):
    return [
        ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
        ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
        ([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
        ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
        ([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], (-1, 0, 0)),
        ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
    ]
def union_faces(boxes):
    xs = sorted({v for b in boxes for v in b[0:2]})
    ys = sorted({v for b in boxes for v in b[2:4]})
    zs = sorted({v for b in boxes for v in b[4:6]})
    def filled(i, j, k):
        if not (0 <= i < len(xs) - 1 and 0 <= j < len(ys) - 1 and 0 <= k < len(zs) - 1):
            return False
        cx, cy, cz = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2, (zs[k] + zs[k + 1]) / 2
        return any(b[0] < cx < b[1] and b[2] < cy < b[3] and b[4] < cz < b[5] for b in boxes)
    faces = []
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            for k in range(len(zs) - 1):
                if not filled(i, j, k):
                    continue
                x0, x1, y0, y1, z0, z1 = xs[i], xs[i + 1], ys[j], ys[j + 1], zs[k], zs[k + 1]
                cell = box_faces(x0, x1, y0, y1, z0, z1)
                beside = [(i, j + 1, k), (i, j - 1, k), (i, j, k - 1), (i, j, k + 1),
                          (i - 1, j, k), (i + 1, j, k)]
                for face, other in zip(cell, beside):
                    if not filled(*other):
                        faces.append(face)
    return faces
def pillar_faces():
    h, c = PILLAR_HALF, PILLAR_CUT
    ring = [(h, -c), (h, c), (c, h), (-c, h), (-h, c), (-h, -c), (-c, -h), (c, -h)]
    faces = [([(x, TOP, z) for x, z in ring], (0, 1, 0)),
             ([(x, 0, z) for x, z in ring], (0, -1, 0))]
    for k in range(len(ring)):
        (ax, az), (bx, bz) = ring[k], ring[(k + 1) % len(ring)]
        normal = (bz - az, 0, -(bx - ax))
        faces.append(([(ax, 0, az), (bx, 0, bz), (bx, TOP, bz), (ax, TOP, az)], normal))
    return faces
def arch_points():
    out = []
    for k in range(ARCH_SEGMENTS + 1):
        a = math.pi * k / ARCH_SEGMENTS
        out.append((int(round(ARCH_RADIUS * math.cos(a))), int(round(ARCH_RADIUS * math.sin(a)))))
    return out
def arch_faces():
    arc = arch_points()
    half = ARCH_SEGMENTS // 2
    if arc[half][0] != 0:
        raise Refused("arch: the curve has no point over its middle")
    faces = []
    for z, out in ((LO, -1), (HI, 1)):
        right = [(HI, TOP, z)] + [(x, y, z) for x, y in arc[:half + 1]] + [(0, TOP, z)]
        left = [(LO, TOP, z), (0, TOP, z)] + [(x, y, z) for x, y in arc[half:]]
        faces.append((right, (0, 0, out)))
        faces.append((left, (0, 0, out)))
    faces.append(([(0, TOP, LO), (HI, TOP, LO), (HI, TOP, HI), (0, TOP, HI)], (0, 1, 0)))
    faces.append(([(LO, TOP, LO), (0, TOP, LO), (0, TOP, HI), (LO, TOP, HI)], (0, 1, 0)))
    faces.append(([(HI, 0, LO), (HI, TOP, LO), (HI, TOP, HI), (HI, 0, HI)], (1, 0, 0)))
    faces.append(([(LO, 0, LO), (LO, TOP, LO), (LO, TOP, HI), (LO, 0, HI)], (-1, 0, 0)))
    for k in range(ARCH_SEGMENTS):
        (ax, ay), (bx, by) = arc[k], arc[k + 1]
        normal = (-(by - ay), (bx - ax), 0)
        if normal[0] * (ax + bx) + normal[1] * (ay + by) > 0:
            normal = (-normal[0], -normal[1], 0)
        faces.append(([(ax, ay, LO), (bx, by, LO), (bx, by, HI), (ax, ay, HI)], normal))
    return faces
def prism_faces():
    return [
        ([(LO, TOP, LO), (HI, TOP, LO), (LO, TOP, HI)], (0, 1, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (LO, 0, HI)], (0, -1, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, TOP, LO), (LO, TOP, LO)], (0, 0, -1)),
        ([(LO, 0, LO), (LO, TOP, LO), (LO, TOP, HI), (LO, 0, HI)], (-1, 0, 0)),
        ([(HI, 0, LO), (LO, 0, HI), (LO, TOP, HI), (HI, TOP, LO)], (1, 0, 1)),
    ]
FENCE_RAILS = [(50, 75), (120, 145)]
FENCE_RAIL_HALF = 10
def fence_picture(corner):
    p, r = FENCE_THICK // 2, FENCE_RAIL_HALF
    rails = FENCE_RAILS
    faces = box_faces(-p, p, 0, FENCE_HIGH, -p, p)
    for y0, y1 in rails:
        if corner:
            faces += box_faces(LO, 0, y0, y1, -r, r)
            faces += box_faces(-r, r, y0, y1, LO, 0)
        else:
            faces += box_faces(LO, HI, y0, y1, -r, r)
    return faces
def arms(thick, high, corner):
    t = thick // 2
    if not corner:
        return [(LO, HI, 0, high, -t, t)]
    return [(LO, t, 0, high, -t, t), (-t, t, 0, high, LO, -t)]
WALL_TEXTURES = {"shelves": ("Stone", "Brick", "Wood", "Metal", "Tiles"),
                 "slugs": ("glassblock", "hazardstripes")}
FENCE_TEXTURES = {"shelves": ("Wood", "Metal"),
                  "slugs": ("greystone", "whitestonebrick", "whitemarble")}
PILLAR_TEXTURES = {"shelves": ("Stone", "Brick"),
                   "slugs": ("whitemarble", "woodenplank1", "darkplanks", "shipplanks",
                             "studdedsteel")}
ARCH_TEXTURES = {"shelves": ("Stone", "Brick"),
                 "slugs": ("whitemarble", "hexpaving", "woodenplank1", "darkplanks")}
SHAPES_MORE = [
    ("slab", "Slabs", "slab", box_faces(LO, HI, 0, TOP // 2, LO, HI), None, 8, 9, None),
    ("wall", "Walls", "wall", union_faces(arms(WALL_THICK, TOP, False)), None, 10, None,
     WALL_TEXTURES),
    ("wallcorner", "Wall corners", "wall corner", union_faces(arms(WALL_THICK, TOP, True)),
     None, 11, None, WALL_TEXTURES),
    ("fence", "Fences", "fence", fence_picture(False),
     union_faces(arms(FENCE_THICK, FENCE_HIGH, False)), 12, None, FENCE_TEXTURES),
    ("fencecorner", "Fence corners", "fence corner", fence_picture(True),
     union_faces(arms(FENCE_THICK, FENCE_HIGH, True)), 13, None, FENCE_TEXTURES),
    ("pillar", "Pillars", "pillar", pillar_faces(), None, 14, None, PILLAR_TEXTURES),
    ("arch", "Arches", "arch", arch_faces(), None, 15, None, ARCH_TEXTURES),
    ("prism", "Diagonal halves", "diagonal half", prism_faces(), None, 16, None, None),
    ("outerstairs", "Outer corner stairs", "outer corner stairs", corner_stair_faces(False),
     corner_stair_floor_faces(False), 17, None, None),
    ("innerstairs", "Inner corner stairs", "inner corner stairs", corner_stair_faces(True),
     corner_stair_floor_faces(True), 18, None, None),
]
CLIMBED = ("outerstairs", "innerstairs")
PLATE_HIGH = 20
WEDGE_HIGH = 100
RIDGE_HIGH = 100
PANEL_THICK = 40
POLE_HALF = 20
ROUND_RADIUS = 200
ROUND_SEGMENTS = 6
DOOR_HALF = 70
DOOR_HIGH = 180
WINDOW_HALF = 50
WINDOW_SILL, WINDOW_HEAD = 80, 160
MARIO_REACH = 50
def wedge_faces(tip):
    lo = WEDGE_HIGH if tip else 0
    hi = lo + WEDGE_HIGH
    faces = [
        ([(LO, lo, HI), (HI, lo, HI), (HI, hi, LO), (LO, hi, LO)], (0, 2, 1)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, hi, LO), (LO, hi, LO)], (0, 0, -1)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0)),
        ([(LO, 0, LO), (LO, 0, HI)] + ([(LO, lo, HI)] if tip else []) + [(LO, hi, LO)],
         (-1, 0, 0)),
        ([(HI, 0, LO), (HI, 0, HI)] + ([(HI, lo, HI)] if tip else []) + [(HI, hi, LO)],
         (1, 0, 0)),
    ]
    if tip:
        faces.append(([(LO, 0, HI), (HI, 0, HI), (HI, lo, HI), (LO, lo, HI)], (0, 0, 1)))
    return faces
def wedge_corner_faces(inner, tip):
    lo = WEDGE_HIGH if tip else 0
    hi = lo + WEDGE_HIGH
    E, C = (LO, hi, LO), (HI, lo, HI)
    faces = [([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0))]
    if not inner:
        B, D = (HI, lo, LO), (LO, lo, HI)
        faces += [([E, B, C], (1, 2, 0)), ([E, C, D], (0, 2, 1))]
        faces.append(([(LO, 0, LO), (LO, 0, HI)] + ([D] if tip else []) + [E], (-1, 0, 0)))
        faces.append(([(LO, 0, LO), (HI, 0, LO)] + ([B] if tip else []) + [E], (0, 0, -1)))
        if tip:
            faces.append(([(HI, 0, LO), (HI, 0, HI), C, B], (1, 0, 0)))
            faces.append(([(LO, 0, HI), (HI, 0, HI), C, D], (0, 0, 1)))
    else:
        F, G = (HI, hi, LO), (LO, hi, HI)
        faces += [([E, F, C], (0, 2, 1)), ([E, G, C], (1, 2, 0))]
        faces.append(([(LO, 0, LO), (HI, 0, LO), F, E], (0, 0, -1)))
        faces.append(([(LO, 0, LO), (LO, 0, HI), G, E], (-1, 0, 0)))
        faces.append(([(HI, 0, LO), (HI, 0, HI)] + ([C] if tip else []) + [F], (1, 0, 0)))
        faces.append(([(LO, 0, HI), (HI, 0, HI)] + ([C] if tip else []) + [G], (0, 0, 1)))
    return faces
def ridge_faces():
    h = RIDGE_HIGH
    return [
        ([(LO, 0, HI), (HI, 0, HI), (HI, h, 0), (LO, h, 0)], (0, 1, 1)),
        ([(LO, h, 0), (HI, h, 0), (HI, 0, LO), (LO, 0, LO)], (0, 1, -1)),
        ([(LO, 0, LO), (LO, 0, HI), (LO, h, 0)], (-1, 0, 0)),
        ([(HI, 0, LO), (HI, 0, HI), (HI, h, 0)], (1, 0, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0)),
    ]
def pyramid_faces():
    top = (0, RIDGE_HIGH, 0)
    return [
        ([(LO, 0, HI), (HI, 0, HI), top], (0, 1, 1)),
        ([(HI, 0, HI), (HI, 0, LO), top], (1, 1, 0)),
        ([(HI, 0, LO), (LO, 0, LO), top], (0, 1, -1)),
        ([(LO, 0, LO), (LO, 0, HI), top], (-1, 1, 0)),
        ([(LO, 0, LO), (HI, 0, LO), (HI, 0, HI), (LO, 0, HI)], (0, -1, 0)),
    ]
def round_corner_faces():
    arc = []
    for k in range(ROUND_SEGMENTS + 1):
        a = (math.pi / 2) * k / ROUND_SEGMENTS
        arc.append((LO + int(round(ROUND_RADIUS * math.cos(a))),
                    LO + int(round(ROUND_RADIUS * math.sin(a)))))
    ring = [(LO, LO)] + arc
    faces = [([(x, TOP, z) for x, z in ring], (0, 1, 0)),
             ([(x, 0, z) for x, z in ring], (0, -1, 0)),
             ([(LO, 0, LO), (HI, 0, LO), (HI, TOP, LO), (LO, TOP, LO)], (0, 0, -1)),
             ([(LO, 0, LO), (LO, 0, HI), (LO, TOP, HI), (LO, TOP, LO)], (-1, 0, 0))]
    for k in range(ROUND_SEGMENTS):
        (ax, az), (bx, bz) = arc[k], arc[k + 1]
        faces.append(([(ax, 0, az), (bx, 0, bz), (bx, TOP, bz), (ax, TOP, az)],
                      (bz - az, 0, -(bx - ax))))
    return faces
def doorway_boxes():
    t = WALL_THICK // 2
    return [(LO, -DOOR_HALF, 0, TOP, -t, t), (DOOR_HALF, HI, 0, TOP, -t, t),
            (-DOOR_HALF, DOOR_HALF, DOOR_HIGH, TOP, -t, t)]
def window_boxes():
    t = WALL_THICK // 2
    return [(LO, HI, 0, WINDOW_SILL, -t, t), (LO, HI, WINDOW_HEAD, TOP, -t, t),
            (LO, -WINDOW_HALF, WINDOW_SILL, WINDOW_HEAD, -t, t),
            (WINDOW_HALF, HI, WINDOW_SILL, WINDOW_HEAD, -t, t)]
def joint_boxes(cross):
    t = WALL_THICK // 2
    out = [(LO, HI, 0, TOP, -t, t), (-t, t, 0, TOP, LO, -t)]
    if cross:
        out.append((-t, t, 0, TOP, t, HI))
    return out
FLOOR_TEXTURES = {"shelves": ("Stone", "Wood", "Tiles"),
                  "slugs": ("grass", "dirt", "sand", "carpet", "diamondplate")}
JOINT_TEXTURES = {"shelves": ("Stone", "Brick", "Wood"),
                  "slugs": ("whitemarble", "studdedsteel")}
ROOF_TEXTURES = {"shelves": ("Wood",),
                 "slugs": ("redbrick", "bricklightgrey", "brickdarkgrey", "greystone",
                           "stone1", "studdedsteel", "whitemarble")}
TERRAIN_TEXTURES = {"shelves": ("Earth and grass",),
                    "slugs": ("stone1", "stone2", "flagstone", "frostedrock", "greystone",
                              "woodenplank1", "hatchedwood")}
OPENING_TEXTURES = {"shelves": ("Stone", "Brick", "Wood", "Metal"),
                    "slugs": ("whitemarble",)}
POLE_TEXTURES = {"shelves": ("Wood", "Metal"), "slugs": ("greystone", "whitemarble")}
ROUND_TEXTURES = {"shelves": ("Stone", "Brick"), "slugs": ("whitemarble",)}
SHAPES_KIT = [
    ("plate", "Plates", "plate", box_faces(LO, HI, 0, PLATE_HIGH, LO, HI), None, 19, 20,
     FLOOR_TEXTURES, "flat"),
    ("wedge", "Wedges", "wedge", wedge_faces(False), None, 21, None,
     TERRAIN_TEXTURES, "slope"),
    ("wedgetip", "Wedge tips", "wedge tip", wedge_faces(True), None, 22, None,
     TERRAIN_TEXTURES, "slope"),
    ("wedgeouter", "Wedge outer corners", "wedge outer corner",
     wedge_corner_faces(False, False), None, 23, None, TERRAIN_TEXTURES, "slope"),
    ("wedgeinner", "Wedge inner corners", "wedge inner corner",
     wedge_corner_faces(True, False), None, 24, None, TERRAIN_TEXTURES, "slope"),
    ("wedgetipouter", "Wedge tip outer corners", "wedge tip outer corner",
     wedge_corner_faces(False, True), None, 25, None, TERRAIN_TEXTURES, "slope"),
    ("wedgetipinner", "Wedge tip inner corners", "wedge tip inner corner",
     wedge_corner_faces(True, True), None, 26, None, TERRAIN_TEXTURES, "slope"),
    ("ridge", "Ridges", "ridge", ridge_faces(), None, 27, None, ROOF_TEXTURES, "roof"),
    ("pyramid", "Pyramids", "pyramid", pyramid_faces(), None, 28, None, ROOF_TEXTURES, "roof"),
    ("wallt", "Wall T joints", "wall T joint", union_faces(joint_boxes(False)), None, 29, None,
     JOINT_TEXTURES, "flat"),
    ("wallcross", "Wall crossings", "wall crossing", union_faces(joint_boxes(True)), None, 30,
     None, JOINT_TEXTURES, "flat"),
    ("panel", "Panels", "panel", box_faces(LO, HI, 0, TOP, LO, LO + PANEL_THICK), None, 31, None,
     JOINT_TEXTURES, "flat"),
    ("pole", "Poles", "pole", box_faces(-POLE_HALF, POLE_HALF, 0, TOP, -POLE_HALF, POLE_HALF),
     None, 32, None, POLE_TEXTURES, "flat"),
    ("roundcorner", "Round corners", "round corner", round_corner_faces(), None, 33, None,
     ROUND_TEXTURES, "flat"),
    ("doorway", "Doorways", "doorway", union_faces(doorway_boxes()), None, 34, None,
     OPENING_TEXTURES, "flat"),
    ("window", "Windows", "window", union_faces(window_boxes()), None, 35, None,
     OPENING_TEXTURES, "flat"),
]
LONG_DEFAULT = ("stone1", "bricklightgrey", "dirt", "whitestonebrick", "tile1",
                "brickpyramid", "stone2", "darkplanks", "mossyrock", "hexpaving",
                "brickdarkgrey", "carpet", "woodenplank2", "frostedrock", "ice",
                "whitemarble", "flagstone", "grass", "tile2", "glassblock")
def long_slugs(path=None):
    try:
        with open(path or blocks.MANIFEST, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("long:"):
                    return tuple(w.strip() for w in line.split(":", 1)[1].split(",") if w.strip())
    except OSError:
        pass
    return ()
LONG_TEXTURES = {"shelves": (), "slugs": long_slugs()}
LONG_SPANS = {"slab2": 2, "slab4": 4, "plate2": 2, "plate4": 4, "wall2": 2, "wall4": 4,
              "panel2": 2, "panel4": 4}
LONG_CULL = 1000
def long_end(tag):
    return LO + LONG_SPANS[tag] * (HI - LO)
SHAPES_LONG = [
    ("slab2", "Slabs, 2 long", "slab, 2 long", box_faces(LO, long_end("slab2"), 0, TOP // 2, LO, HI),
     None, 36, None, LONG_TEXTURES, "flat"),
    ("slab4", "Slabs, 4 long", "slab, 4 long", box_faces(LO, long_end("slab4"), 0, TOP // 2, LO, HI),
     None, 37, None, LONG_TEXTURES, "flat"),
    ("plate2", "Plates, 2 long", "plate, 2 long",
     box_faces(LO, long_end("plate2"), 0, PLATE_HIGH, LO, HI), None, 38, None, LONG_TEXTURES,
     "flat"),
    ("plate4", "Plates, 4 long", "plate, 4 long",
     box_faces(LO, long_end("plate4"), 0, PLATE_HIGH, LO, HI), None, 39, None, LONG_TEXTURES,
     "flat"),
    ("wall2", "Walls, 2 long", "wall, 2 long",
     box_faces(LO, long_end("wall2"), 0, TOP, -(WALL_THICK // 2), WALL_THICK // 2), None, 40,
     None, LONG_TEXTURES, "flat"),
    ("wall4", "Walls, 4 long", "wall, 4 long",
     box_faces(LO, long_end("wall4"), 0, TOP, -(WALL_THICK // 2), WALL_THICK // 2), None, 41,
     None, LONG_TEXTURES, "flat"),
    ("panel2", "Panels, 2 long", "panel, 2 long",
     box_faces(LO, long_end("panel2"), 0, TOP, LO, LO + PANEL_THICK), None, 42, None,
     LONG_TEXTURES, "flat"),
    ("panel4", "Panels, 4 long", "panel, 4 long",
     box_faces(LO, long_end("panel4"), 0, TOP, LO, LO + PANEL_THICK), None, 43, None,
     LONG_TEXTURES, "flat"),
]
SHAPES_KIT = SHAPES_KIT + SHAPES_LONG
FAMILIES = [
    ("Blocks", ("cube", "slab", "plate", "slab2", "slab4", "plate2", "plate4")),
    ("Ramps", ("slope", "outer", "inner", "ridge", "pyramid")),
    ("Wedges", ("wedge", "wedgetip", "wedgeouter", "wedgeinner", "wedgetipouter",
                "wedgetipinner")),
    ("Stairs", ("stairs", "outerstairs", "innerstairs")),
    ("Walls", ("wall", "wallcorner", "wallt", "wallcross", "panel", "prism", "wall2", "wall4",
               "panel2", "panel4")),
    ("Fences", ("fence", "fencecorner")),
    ("Columns", ("pillar", "pole", "roundcorner")),
    ("Openings", ("doorway", "window", "arch")),
]
JUMP_SAFE = 200
FENCE_MARGIN = 40
MARIO_TALL = 160
FLAT_TOPS = {"slab": 100, "uslab": 200, "wall": 200, "wallcorner": 200,
             "fence": FENCE_HIGH, "fencecorner": FENCE_HIGH, "pillar": 200,
             "arch": 200, "prism": 200,
             "plate": PLATE_HIGH, "uplate": 200, "wallt": 200, "wallcross": 200,
             "panel": 200, "pole": 200, "roundcorner": 200, "doorway": 200,
             "window": 200, "slab2": 100, "slab4": 100, "plate2": PLATE_HIGH,
             "plate4": PLATE_HIGH, "wall2": 200, "wall4": 200, "panel2": 200, "panel4": 200}
STEPPED_ON = ("plate", "uplate", "plate2", "plate4")
def measure_flat(variant, floor):
    tag = variant["tag"]
    floors, walls, ceils = [], [], []
    for pts, n in floor:
        if n[1] > 0:
            floors.append(pts)
            if n[0] != 0 or n[2] != 0:
                raise Refused("%s: a floor that is not level" % tag)
        elif n[1] < 0:
            ceils.append(pts)
        else:
            walls.append(pts)
    top = max(p[1] for pts in floors for p in pts)
    if top != FLAT_TOPS[tag]:
        raise Refused("%s: its top is at %d, not %d" % (tag, top, FLAT_TOPS[tag]))
    low = min(p[1] for pts, _ in floor for p in pts)
    rise = top - low
    if tag in STEPPED_ON:
        if rise >= WALL_REACH:
            raise Refused("%s: %d high is a wall to a walk, not a floor tile" % (tag, rise))
        return top
    if rise < WALL_REACH:
        raise Refused("%s: %d high is walked over, not a block" % (tag, rise))
    if tag == "doorway":
        if 2 * DOOR_HALF <= 2 * MARIO_REACH or DOOR_HIGH <= MARIO_TALL:
            raise Refused("doorway: %d x %d is too small for Mario"
                          % (2 * DOOR_HALF, DOOR_HIGH))
        if not any(n[1] < 0 and all(p[1] == DOOR_HIGH for p in pts) for pts, n in floor):
            raise Refused("doorway: no lintel over the opening")
    if tag == "window":
        if 2 * WINDOW_HALF > 2 * MARIO_REACH and WINDOW_HEAD - WINDOW_SILL > MARIO_TALL:
            raise Refused("window: Mario fits through it")
        if WINDOW_SILL < WALL_REACH:
            raise Refused("window: a sill of %d is walked over" % WINDOW_SILL)
    if tag.startswith("fence") and rise > JUMP_SAFE - FENCE_MARGIN:
        raise Refused("%s: %d high - a single jump must clear a fence (at most %d)"
                      % (tag, rise, JUMP_SAFE - FENCE_MARGIN))
    if tag == "arch":
        if any(n[1] >= 0 for pts, n in floor if all(p[1] < TOP for p in pts)
               and not all(abs(p[0]) == HI for p in pts)):
            raise Refused("arch: a piece of the tunnel is not a ceiling")
        if 2 * ARCH_RADIUS <= 2 * 50 or TOP < MARIO_TALL:
            raise Refused("arch: the doorway is too small for Mario")
    return top
def measure_slope(variant, floor):
    tag = variant["tag"]
    top = max(p[1] for pts, _ in floor for p in pts)
    if top > TOP:
        raise Refused("%s: rises past the cell (%d)" % (tag, top))
    rising = 0
    for pts, n in floor:
        if n[1] <= 0:
            continue
        length = math.sqrt(dot(n, n))
        if n[1] / length < 0.7 - 1e-9:
            raise Refused("%s: a floor steeper than 45 degrees" % tag)
        if n[0] != 0 or n[2] != 0:
            rising += 1
    if rising == 0:
        raise Refused("%s: nothing rises" % tag)
    return top
def shape_tags():
    return ["cube"] + [v["tag"] for v in variants() if not v["flip"]]
def layered_allowed():
    return tuple(v["tag"] for v in variants()
                 if not v["flip"] and v["tag"] not in LONG_SPANS)
def default_in(variant, row):
    if row.get("layers"):
        return variant["tag"] in LAYERED_SHAPES
    pick = variant.get("textures")
    if pick is None:
        return True
    return row["shelf"] in pick["shelves"] or row["slug"] in pick["slugs"]
_SETS = {}
def shape_set(row):
    key = (row["slug"], row.get("shapes"), bool(row.get("layers")), row["shelf"],
           row["slug"] in LONG_TEXTURES["slugs"])
    if key in _SETS:
        return _SETS[key]
    every = variants()
    by_tag = {v["tag"]: v for v in every}
    twin_of = {v["tag"]: "u" + v["tag"] for v in every
               if not v["flip"] and ("u" + v["tag"]) in by_tag}
    layered_ok = set(layered_allowed())
    allowed = {v["tag"] for v in every
               if not row.get("layers") or v["tag"] in layered_ok}
    defaults = {v["tag"] for v in every if default_in(v, row)}
    families = {name.lower(): tuple(t for t in shapes if t not in LONG_SPANS)
                for name, shapes in FAMILIES}
    spec = row.get("shapes")
    long_here = {t for t in LONG_SPANS if row["slug"] in LONG_TEXTURES["slugs"]
                 and not row.get("layers")}
    if spec is None:
        _SETS[key] = defaults
        return defaults
    items = [item.strip().lower() for item in spec.split(",") if item.strip()]
    chosen = set(defaults) if items and items[0][0] in "+-" else set()
    def expand(word):
        if word == "default":
            return set(defaults)
        if word == "all":
            return set(allowed)
        if word in families:
            return {t for t in families[word] if t != "cube"}
        if word == "cube":
            return set()
        if word in by_tag:
            return {word}
        raise Refused("manifest line %d: shapes=%s - %r is no shape or family (%s)"
                      % (row["line"], spec, word, ", ".join(sorted(set(by_tag) | set(families)))))
    for item in items:
        if item == "none":
            chosen = set()
            continue
        sign, word = ("-", item[1:]) if item[0] == "-" else ("+", item.lstrip("+"))
        tags = expand(word)
        if sign == "+":
            for tag in sorted(tags):
                if tag not in allowed and word not in ("all", "default"):
                    raise Refused("manifest line %d: a transition block does not "
                                  "come in %s" % (row["line"], tag))
                chosen.add(tag)
                if tag in twin_of and twin_of[tag] in allowed:
                    chosen.add(twin_of[tag])
        else:
            chosen -= tags
    taken_away = {item[1:] for item in items if item.startswith("-")}
    chosen = (chosen - set(LONG_SPANS)) | (long_here - taken_away)
    chosen &= allowed
    _SETS[key] = chosen
    return chosen
def builds_in(variant, row):
    return variant["tag"] in shape_set(row)
def variants():
    out = []
    for index, (tag, shelf, noun, faces) in enumerate(SHAPES):
        out.append({"tag": tag, "shelf": shelf, "noun": noun, "faces": faces,
                    "flip": False, "byte": 1 + index})
    for index, (tag, shelf, noun, faces) in enumerate(SHAPES):
        out.append({"tag": "u" + tag, "shelf": shelf, "noun": noun, "faces": faces,
                    "flip": True, "byte": 1 + len(SHAPES) + index})
    for index, (tag, shelf, noun, faces, floor) in enumerate(SHAPES_UPRIGHT_ONLY):
        out.append({"tag": tag, "shelf": shelf, "noun": noun, "faces": faces,
                    "floor": floor, "flip": False, "byte": 1 + 2 * len(SHAPES) + index,
                    "steps": True})
    for tag, shelf, noun, faces, floor, byte, twin, textures, measure in SHAPES_KIT:
        out.append({"tag": tag, "shelf": shelf, "noun": noun, "faces": faces,
                    "floor": floor, "flip": False, "byte": byte,
                    "flat": measure == "flat", "measure": measure, "textures": textures})
        if twin is not None:
            out.append({"tag": "u" + tag, "shelf": shelf, "noun": noun, "faces": faces,
                        "floor": floor, "flip": True, "byte": twin, "flat": True,
                        "measure": measure, "textures": textures})
    for tag, shelf, noun, faces, floor, byte, twin, textures in SHAPES_MORE:
        out.append({"tag": tag, "shelf": shelf, "noun": noun, "faces": faces,
                    "floor": floor, "flip": False, "byte": byte, "flat": tag not in CLIMBED,
                    "steps": tag in CLIMBED, "textures": textures})
        if twin is not None:
            out.append({"tag": "u" + tag, "shelf": shelf, "noun": noun, "faces": faces,
                        "floor": floor, "flip": True, "byte": twin, "flat": True,
                        "textures": textures})
    return sorted(out, key=lambda v: v["byte"])
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])
def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def solid(variant):
    faces = []
    for corners, normal in variant["faces"]:
        pts = [P[c] if isinstance(c, str) else c for c in corners]
        if variant["flip"]:
            pts = [(x, TOP - y, z) for x, y, z in pts]
            normal = (normal[0], -normal[1], normal[2])
        area = (0, 0, 0)
        for i in range(len(pts)):
            c = cross(pts[i], pts[(i + 1) % len(pts)])
            area = (area[0] + c[0], area[1] + c[1], area[2] + c[2])
        if dot(area, normal) < 0:
            pts = list(reversed(pts))
            if not isinstance(corners, str):
                pts = pts[-1:] + pts[:-1]
        faces.append((pts, normal))
    return faces
def triangles(pts):
    return [(pts[0], pts[i], pts[i + 1]) for i in range(1, len(pts) - 1)]
def vet(variant, faces):
    edges = {}
    for pts, normal in faces:
        for a, b, c in triangles(pts):
            n = cross(sub(b, a), sub(c, b))
            if dot(n, normal) <= 0:
                raise Refused("%s: a triangle points into the solid" % variant["tag"])
            length = math.sqrt(dot(n, n))
            want = math.sqrt(dot(normal, normal))
            if any(abs(n[k] / length - normal[k] / want) > 1e-6 for k in range(3)):
                raise Refused("%s: a face is not flat" % variant["tag"])
            for e in ((a, b), (b, c), (c, a)):
                edges[e] = edges.get(e, 0) + 1
    for (a, b), count in edges.items():
        if count != 1 or edges.get((b, a)) != 1:
            raise Refused("%s: the solid is open at %s-%s" % (variant["tag"], a, b))
def col_name(variant):
    return "%s%s_col" % (PREFIX, variant["tag"])
def sort_first(tri):
    a, b, c = tri
    n = cross(sub(b, a), sub(c, b))
    if n[1] > 0:
        key = max
    elif n[1] < 0:
        key = min
    else:
        return tri
    want = key(p[1] for p in tri)
    while tri[0][1] != want:
        tri = (tri[1], tri[2], tri[0])
    return tri
def build_col(variant, faces):
    verts, tris = [], []
    for pts, _ in faces:
        for tri in triangles(pts):
            idx = []
            for p in sort_first(tri):
                if p not in verts:
                    verts.append(p)
                idx.append(verts.index(p))
            tris.append(tuple(idx))
    words = [COL_INIT, len(verts)]
    for p in verts:
        words += list(p)
    words += [SURFACE_NOT_SLIPPERY, len(tris)]
    for t in tris:
        words += list(t)
    words += [COL_TRI_STOP, COL_END]
    name = col_name(variant).encode("ascii")
    return (bytes([DATA_TYPE_COLLISION]) + bytes([len(name)]) + name
            + struct.pack("<I", len(words)) + struct.pack("<%dh" % len(words), *words))
def read_nodes(raw, where):
    nodes = []
    i = 0
    def take(n):
        nonlocal i
        if i + n > len(raw):
            raise Refused("%s: runs off the end at %d" % (where, i))
        chunk = raw[i:i + n]
        i += n
        return chunk
    def name():
        size = take(1)[0]
        return take(size).decode("ascii")
    while i < len(raw):
        kind = take(1)[0]
        label = name()
        body = []
        if kind == 1:
            body.append(take(24))
        elif kind == 2:
            count = struct.unpack("<i", take(4))[0]
            body.append(("png", take(count)))
        elif kind == 3:
            count = struct.unpack("<I", take(4))[0]
            body.append(struct.pack("<I", count))
            body.append(take(16 * count))
        elif kind in (4, 5):
            count = struct.unpack("<I", take(4))[0]
            body.append(struct.pack("<I", count))
            words = count * (2 if kind == 4 else 1)
            commands = []
            for _ in range(words):
                value = struct.unpack("<I", take(4))[0]
                if value == POINTER:
                    commands.append(("ptr", name(), struct.unpack("<I", take(4))[0]))
                elif value == FUNCTION:
                    commands.append(("fn", struct.unpack("<I", take(4))[0]))
                elif value == LUA_VAR:
                    commands.append(("lua", name()))
                else:
                    commands.append(("word", value))
            body.append(("words", commands))
        else:
            raise Refused("%s: node type %d is not part of a plain cube" % (where, kind))
        nodes.append([kind, label, body])
    return nodes
WATER_TINT = (225, 240, 255)
WATER_ALPHA = 120
G_LIGHTING = 0x00020000
G_SHADING_SMOOTH = 0x00200000
GEO_DL_OPAQUE = 0x0115
GEO_DL_TRANSPARENT = 0x0515
def water_look(nodes):
    out, cleared, restored, layered = [], 0, 0, 0
    for node in nodes:
        kind, label, body = node[0], node[1], node[2]
        if kind == 3:
            count = body[0]
            data = bytearray(body[1])
            for k in range(0, len(data), 16):
                data[k + 12:k + 16] = bytes(WATER_TINT + (WATER_ALPHA,))
            out.append([kind, label, [count, bytes(data)]])
        elif kind == 4:
            words = list(body[1][1])
            for i in range(0, len(words) - 1, 2):
                w0, w1 = words[i], words[i + 1]
                if w0[0] != "word" or (w0[1] >> 24) != 0xD9 or w1[0] != "word":
                    continue
                clear = ~w0[1] & 0xFFFFFF
                if clear & G_SHADING_SMOOTH and w1[1] == 0:
                    words[i] = ("word", 0xD9000000 | (~(clear | G_LIGHTING) & 0xFFFFFF))
                    cleared += 1
                elif clear == 0 and w1[1] & G_SHADING_SMOOTH:
                    words[i + 1] = ("word", w1[1] | G_LIGHTING)
                    restored += 1
            out.append([kind, label, [body[0], ("words", words)]])
        elif kind == 5:
            words = list(body[1][1])
            for i, w in enumerate(words):
                if w == ("word", GEO_DL_OPAQUE):
                    words[i] = ("word", GEO_DL_TRANSPARENT)
                    layered += 1
            out.append([kind, label, [body[0], ("words", words)]])
        else:
            out.append(node)
    if not (cleared and restored and layered):
        raise Refused("the cube template's geometry mode / draw layer are not the ones the "
                      "water look knows (%d cleared, %d restored, %d layers)"
                      % (cleared, restored, layered))
    return out
def write_nodes(nodes, rename):
    out = []
    for kind, label, body in nodes:
        out.append(bytes([kind]))
        out.append(("name", rename(label)))
        for piece in body:
            if isinstance(piece, tuple) and piece[0] == "words":
                for command in piece[1]:
                    if command[0] == "ptr":
                        out.append(struct.pack("<I", POINTER))
                        out.append(("name", rename(command[1])))
                        out.append(struct.pack("<I", command[2]))
                    elif command[0] == "fn":
                        out.append(struct.pack("<I", FUNCTION))
                        out.append(struct.pack("<I", command[1]))
                    elif command[0] == "lua":
                        out.append(struct.pack("<I", LUA_VAR))
                        out.append(("name", command[1]))
                    else:
                        out.append(struct.pack("<I", command[1]))
            else:
                out.append(piece)
    return blocks.emit(out)
def normal_bytes(n):
    length = math.sqrt(dot(n, n))
    return tuple(int(round(c / length * 127)) & 0xFF for c in n)
def uv(p, normal):
    full = 31 << 5
    length = math.sqrt(dot(normal, normal))
    if (normal[0] == 0 and normal[2] == 0) or normal[1] / length > 0.8:
        s, t = (p[0] - LO) / (HI - LO), (p[2] - LO) / (HI - LO)
    else:
        u = (normal[2], 0, -normal[0])
        length = math.sqrt(dot(u, u))
        s = (dot(p, u) / length - LO) / (HI - LO)
        t = (TOP - p[1]) / TOP
    return int(round(s * full)), int(round(t * full))
def tri_words(chunk):
    commands = []
    for k in range(0, len(chunk), 2):
        a = chunk[k]
        packed_a = (a[0] * 2 << 16) | (a[1] * 2 << 8) | (a[2] * 2)
        if k + 1 < len(chunk):
            b = chunk[k + 1]
            packed_b = (b[0] * 2 << 16) | (b[1] * 2 << 8) | (b[2] * 2)
            commands.append((0x06000000 | packed_a, packed_b))
        else:
            commands.append((0x05000000 | packed_a, 0))
    return commands
CHUNK = 30
LAYERED_SHAPES = ("slope", "outer", "inner", "stairs", "outerstairs", "innerstairs",
                  "slab", "plate", "prism", "wedge", "wedgetip", "wedgeouter",
                  "wedgeinner", "wedgetipouter", "wedgetipinner", "ridge", "pyramid")
TEMPLATE_PREFIX = "of_cube_"
LAYER_LABELS = tuple(TEMPLATE_PREFIX + s for s in ("texture", "texture_side", "texture_bottom"))
def layer_of(normal):
    if normal[1] > 0:
        return 0
    if normal[1] < 0:
        return 2
    return 1
def side_top(pts, normal, p):
    u = (normal[2], 0, -normal[0])
    at = dot(p, u)
    best = None
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        sa, sb = dot(a, u), dot(b, u)
        lo, hi = min(sa, sb), max(sa, sb)
        if at < lo - 1e-6 or at > hi + 1e-6:
            continue
        if abs(sb - sa) < 1e-9:
            y = max(a[1], b[1])
        else:
            y = a[1] + (b[1] - a[1]) * (at - sa) / (sb - sa)
        best = y if best is None else max(best, y)
    return best
def layered_uv(pts, normal, p):
    s, t = uv(p, normal)
    if layer_of(normal) == 1:
        full = 31 << 5
        t = int(round((side_top(pts, normal, p) - p[1]) / TOP * full))
    return s, t
def load_layer(label):
    return [(("word", 0xE7000000), ("word", 0)),
            (("word", 0xFD100000), ("ptr", label, 0)),
            (("word", 0xE6000000), ("word", 0)),
            (("word", 0xF3000000), ("word", 0x073FF100))]
SETTILE_W0 = 0xF5101000
SETTILE_CLAMP = 0x00094250
SETTILE_WRAP = SETTILE_CLAMP & ~((2 << 8) | (2 << 18))
CULL_WORD = (500 << 16) | 0x0020
def long_look(nodes):
    out, wrapped, culled = [], 0, 0
    for kind, label, body in nodes:
        if kind in (4, 5):
            new_body = []
            for piece in body:
                if isinstance(piece, tuple) and piece[0] == "words":
                    words = list(piece[1])
                    for i in range(len(words)):
                        if kind == 4 and i % 2 == 1 and words[i] == ("word", SETTILE_CLAMP) \
                                and words[i - 1] == ("word", SETTILE_W0):
                            words[i] = ("word", SETTILE_WRAP)
                            wrapped += 1
                        if kind == 5 and words[i] == ("word", CULL_WORD):
                            words[i] = ("word", (LONG_CULL << 16) | 0x0020)
                            culled += 1
                    piece = ("words", words)
                new_body.append(piece)
            body = new_body
        out.append([kind, label, body])
    if wrapped != 1 or culled != 1:
        raise Refused("the cube template's render tile or culling radius is not the one "
                      "this tool knows (wrapped %d, culled %d)" % (wrapped, culled))
    return out
def build_geo(template_nodes, prefix, png, faces, layers=None, water=False, long=False):
    if long:
        template_nodes = long_look(template_nodes)
    tri_dl = vtx_nodes = None
    for node in template_nodes:
        if node[0] == 4:
            words = node[2][1][1]
            if any(c[0] == "word" and i % 2 == 0 and (c[1] >> 24) == 0x01
                   for i, c in enumerate(words)):
                tri_dl = node
    vtx_nodes = [node for node in template_nodes if node[0] == 3]
    if tri_dl is None or not vtx_nodes:
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
        groups = [[f for f in faces if layer_of(f[1]) == k] for k in range(3)]
    chunks, loads = [], {}
    for k, group in enumerate(groups):
        if not group:
            continue
        if k > 0:
            loads[len(chunks)] = LAYER_LABELS[k]
        chunks.append([])
        for pts, normal in group:
            if sum(len(p) for p, _ in chunks[-1]) + len(pts) > CHUNK:
                chunks.append([])
            chunks[-1].append((pts, normal))
    new_vtx = []
    commands = list(head)
    for index, chunk in enumerate(chunks):
        if index in loads:
            commands += load_layer(loads[index])
        label = "%svertex%d" % (TEMPLATE_PREFIX, index)
        data = b""
        count = 0
        tris = []
        for pts, normal in chunk:
            base = count
            nb = normal_bytes(normal)
            for p in pts:
                s, t = uv(p, normal) if layers is None else layered_uv(pts, normal, p)
                data += struct.pack("<3hHhh4B", p[0], p[1], p[2], 0, s, t,
                                    nb[0], nb[1], nb[2], 255)
                count += 1
            for k in range(1, len(pts) - 1):
                tris.append((base, base + k, base + k + 1))
        new_vtx.append([3, label, [struct.pack("<I", count), data]])
        commands.append((("word", 0x01000000 | (count << 12) | (count * 2)),
                         ("ptr", label, 0)))
        for w0, w1 in tri_words(tris):
            commands.append((("word", w0), ("word", w1)))
    commands += tail
    flat = []
    for w0, w1 in commands:
        flat += [w0, w1]
    new_tri = [4, tri_dl[1], [struct.pack("<I", len(commands)), ("words", flat)]]
    out = []
    placed = False
    for node in template_nodes:
        if node[0] == 3:
            if not placed:
                out += new_vtx
                placed = True
            continue
        if node is tri_dl:
            out.append(new_tri)
        elif node[0] == 2:
            out.append([2, node[1], [("png", png)]])
            if layers is not None:
                if node[1] != LAYER_LABELS[0]:
                    raise Refused("the cube template's texture is %s, not %s"
                                  % (node[1], LAYER_LABELS[0]))
                out.append([2, LAYER_LABELS[1], [("png", layers[0])]])
                out.append([2, LAYER_LABELS[2], [("png", layers[1])]])
        else:
            out.append(node)
    if water:
        out = water_look(out)
    template_prefix = TEMPLATE_PREFIX
    def rename(label):
        if label.startswith(template_prefix):
            return prefix + label[len(template_prefix):]
        return label
    return blocks.pack_bin(write_nodes(out, rename))
def geo_name(variant, row):
    return "%s%s_%s_geo" % (PREFIX, variant["tag"], row["slug"])
def build():
    template_path, rows = blocks.read_manifest()
    where = os.path.relpath(os.path.join(ROOT, template_path), ROOT)
    with open(os.path.join(ROOT, template_path), "rb") as handle:
        raw = blocks.unpack_bin(handle.read(), where)
    nodes = read_nodes(raw, where)
    if write_nodes(nodes, lambda label: label) != raw:
        raise Refused("%s: the walk does not give the file back" % where)
    roots = [node[1] for node in nodes if node[0] == 5]
    if roots != [TEMPLATE_PREFIX + "geo"]:
        raise Refused("%s: the geo root is %s, not %sgeo" % (where, roots, TEMPLATE_PREFIX))
    files = {}
    for variant in variants():
        faces = solid(variant)
        vet(variant, faces)
        floor = faces
        if variant.get("floor") is not None:
            floor = solid({"tag": variant["tag"], "faces": variant["floor"],
                           "flip": variant["flip"]})
            vet(variant, floor)
            for riser in (stair_risers(floor) if variant.get("steps") else ()):
                if riser >= WALL_REACH:
                    raise Refused("%s: a riser of %d is a wall to a walking Mario "
                                  "(under %d walks, see STEPS)" % (variant["tag"], riser, WALL_REACH))
        if variant.get("flat"):
            measure_flat(variant, floor)
        elif variant.get("measure") in ("slope", "roof"):
            measure_slope(variant, floor)
        files[col_name(variant) + ".col"] = build_col(variant, floor)
        for row in rows:
            if row.get("drawn") == "runtime" or not builds_in(variant, row):
                continue
            png, layers = row_textures(row)
            name = geo_name(variant, row)
            if layers is not None:
                fringe_faults(variant, faces)
            files[name + ".bin"] = build_geo(nodes, name[:-3], png, faces, layers,
                                             water=is_water(row),
                                             long=variant["tag"] in LONG_SPANS)
    return files, len(rows)
def is_water(row):
    return "water" in (row.get("roles") or ())
def row_textures(row):
    pngs = []
    for source in row.get("layers") or [row["source"]]:
        png = blocks.read_texture(os.path.join(ROOT, source))
        blocks.vet_texture(png, source)
        pngs.append(png)
    return pngs[0], (pngs[1:] if len(pngs) == 3 else None)
def fringe_faults(variant, faces):
    for pts, normal in faces:
        if layer_of(normal) != 1:
            continue
        for p in pts:
            _, t = layered_uv(pts, normal, p)
            on_edge = abs(side_top(pts, normal, p) - p[1]) < 1e-6
            if (t == 0) != on_edge or t < 0:
                raise Refused("%s: a side's fringe is not along its top (t %d at %s)"
                              % (variant["tag"], t, p))
def layered_cube(template_nodes, prefix, pngs):
    faces = solid({"tag": "cube", "flip": False, "faces": box_faces(LO, HI, 0, TOP, LO, HI)})
    vet({"tag": "cube"}, faces)
    fringe_faults({"tag": "cube"}, faces)
    return build_geo(template_nodes, prefix, pngs[0], faces, pngs[1:])
def shape_table():
    full = 31 << 5
    out = []
    for variant in variants():
        faces = solid(variant)
        floor_faces = faces
        if variant.get("floor") is not None:
            floor_faces = solid({"tag": variant["tag"], "faces": variant["floor"],
                                 "flip": variant["flip"]})
        rows = []
        for pts, normal in faces:
            rows.append({
                "points": [list(p) for p in pts],
                "normal": list(normal),
                "layer": ("top", "side", "bottom")[layer_of(normal)],
                "uv": [list(uv(p, normal)) for p in pts],
                "layered_uv": [list(layered_uv(pts, normal, p)) for p in pts],
                "tris": [[0, k, k + 1] for k in range(1, len(pts) - 1)],
            })
        out.append({
            "tag": variant["tag"], "byte": variant["byte"],
            "up": variant["tag"][1:] if variant["flip"] else "",
            "span": LONG_SPANS.get(variant["tag"], 1),
            "flat": bool(variant.get("flat")), "measure": variant.get("measure"),
            "wraps": variant["tag"] in LONG_SPANS,
            "faces": rows,
            "floor": [{"points": [list(p) for p in pts], "normal": list(n)}
                      for pts, n in floor_faces],
        })
    return {"cell": [LO, HI, 0, TOP], "uv_full": full, "families": FAMILIES,
            "layered_default": list(LAYERED_SHAPES), "layered_allowed": list(layered_allowed()),
            "shapes": out}
def lua_shapes():
    with open(SPAWNER, encoding="utf-8") as handle:
        text = handle.read()
    found = []
    import re
    for match in re.finditer(r'\{ tag = "(\w+)", byte = (\d+), up = "(\w*)"', text):
        found.append((match.group(1), int(match.group(2))))
    return found
def lua_families():
    import re
    with open(os.path.join(ROOT, "of_forge.lua"), encoding="utf-8") as handle:
        text = handle.read()
    region = re.search(r"forge\.SHAPE_FAMILIES = \{(.*?)\n\}", text, re.S)
    if region is None:
        return None
    out = []
    for match in re.finditer(r'name = "([^"]+)", shapes = \{([^}]*)\}', region.group(1)):
        out.append((match.group(1), tuple(re.findall(r'"(\w+)"', match.group(2)))))
    return out
def family_faults():
    have = lua_families()
    if have != [(name, tuple(shapes)) for name, shapes in FAMILIES]:
        return "of_forge.lua's SHAPE_FAMILIES say %s, the tool's FAMILIES %s" % (have, FAMILIES)
    on_wheel = [t for _, shapes in FAMILIES for t in shapes]
    upright = shape_tags()
    if sorted(on_wheel) != sorted(upright):
        return "the families hold %s, the tool builds %s" % (sorted(on_wheel), sorted(upright))
    return None
def col_order_faults():
    faults = []
    for name in sorted(os.listdir(ACTORS)):
        if not name.endswith(".col"):
            continue
        raw = open(os.path.join(ACTORS, name), "rb").read()
        off = 2 + raw[1]
        count = struct.unpack("<I", raw[off:off + 4])[0]
        words = struct.unpack("<%dh" % count, raw[off + 4:off + 4 + 2 * count])
        if words[0] != COL_INIT:
            continue
        nv = words[1]
        verts = [tuple(words[2 + 3 * k:5 + 3 * k]) for k in range(nv)]
        i = 2 + 3 * nv
        while i < len(words) and words[i] != COL_TRI_STOP:
            kind, nt = words[i], words[i + 1]
            i += 2
            for t in range(nt):
                tri = tuple(verts[k] for k in words[i:i + 3])
                if sort_first(tri) != tri:
                    faults.append("%s triangle %d" % (name, t))
                i += 3
    return faults
def main(argv):
    if "--table" in argv:
        import json
        at = argv.index("--table")
        path = argv[at + 1] if at + 1 < len(argv) else None
        text = json.dumps(shape_table(), indent=None, separators=(",", ":"))
        if path in (None, "-"):
            print(text)
        else:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text + "\n")
            print("make-forgeslopes: %d shapes written to %s" % (len(variants()), path))
        return 0
    check = "--check" in argv
    try:
        files, count = build()
        want = [(v["tag"], v["byte"]) for v in variants()]
        have = lua_shapes()
        if sorted(have) != sorted(want):
            raise Refused("of_spawner.lua's SLOPE_SHAPES say %s, the tool builds %s"
                          % (have, want))
        wheel = family_faults()
        if wheel:
            raise Refused(wheel)
    except Refused as why:
        print("make-forgeslopes: %s" % why)
        return 1
    stale = sorted(name for name in os.listdir(ACTORS)
                   if name.startswith(PREFIX) and name not in files)
    differ = []
    for name, data in sorted(files.items()):
        path = os.path.join(ACTORS, name)
        have = open(path, "rb").read() if os.path.exists(path) else None
        if have != data:
            differ.append(name)
    if check:
        faults = []
        misfiled = col_order_faults()
        if misfiled:
            faults.append("%d triangle(s) filed by a vertex the engine does not sort "
                          "them by, first %s (see sort_first)" % (len(misfiled), misfiled[0]))
        if differ:
            faults.append("%d file(s) out of date, first %s" % (len(differ), differ[0]))
        if stale:
            faults.append("%d file(s) no shape or texture names, first %s"
                          % (len(stale), stale[0]))
        if faults:
            print("make-forgeslopes: " + "; ".join(faults))
            print("run tools/make-forgeslopes.py to rebuild them")
            return 1
        print("make-forgeslopes: %d shapes in %d textures, all current"
              % (len(variants()), count))
        return 0
    for name in differ:
        with open(os.path.join(ACTORS, name), "wb") as handle:
            handle.write(files[name])
    for name in stale:
        os.remove(os.path.join(ACTORS, name))
    size = sum(len(data) for data in files.values())
    print("make-forgeslopes: %d shapes in %d textures, %d files, %d bytes; %d written, %d removed"
          % (len(variants()), count, len(files), size, len(differ), len(stale)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
