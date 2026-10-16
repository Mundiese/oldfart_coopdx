#!/usr/bin/env python3
import importlib.util
import json
import os
import re
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LIBRARY = os.path.join(ROOT, "prefabs")
SPAWNER = os.path.join(ROOT, "of_spawner.lua")
BEGIN = "-- BEGIN PREFABS (written by tools/prefabs.py from prefabs/*.prefab - edit those, not these lines)"
END = "-- END PREFABS"
CELL = 200
FACES = {"-x": (-1, 0), "+x": (1, 0), "-z": (0, -1), "+z": (0, 1)}
KINDS = ("door", "path", "wall", "bridge")
ROLE_TO_THEME = {"wall": ("building", "wall"), "roof": ("roof", "ramp"), "floor": "floor",
                 "path": "bridge", "deck": "deck", "trim": "trim", "cover": "cover",
                 "post": "bridge", "counter": "cover"}
def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
_slopes = None
def slopes():
    global _slopes
    if _slopes is None:
        _slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    return _slopes
class Refused(Exception):
    pass
_recode = None
def old_keys():
    global _recode
    if _recode is None:
        _recode = _load("blockrecode", "blockrecode.py")
    return _recode, _recode.was_map(slopes().blocks.read_manifest()[1])
def load_all():
    out = {}
    if not os.path.isdir(LIBRARY):
        return out
    for name in sorted(os.listdir(LIBRARY)):
        if name.endswith(".prefab"):
            key = name[:-len(".prefab")]
            with open(os.path.join(LIBRARY, name), encoding="utf-8") as handle:
                try:
                    data = json.load(handle)
                except ValueError as why:
                    raise Refused("%s: not JSON (%s)" % (name, why))
            data["key"] = key
            out[key] = data
    rc, mapping = old_keys()
    if mapping:
        for data in out.values():
            rc.recode_prefab(data, mapping)
    return out
def get(key):
    prefab = load_all().get(key)
    if prefab is None:
        raise Refused("no prefab %r" % key)
    return prefab
def turned(x, z, turn):
    for _ in range(turn % 4):
        x, z = z, -x
    return x, z
def face_turned(face, turn):
    dx, dz = turned(*FACES[face], turn)
    for name, vec in FACES.items():
        if vec == (dx, dz):
            return name
    raise Refused("face %r" % face)
STRETCH_MAX = (32, 16, 32)
MERGE_SHAPES = ("cube", "slab", "plate")
def piece_size(piece):
    if len(piece) > 7 and piece[7]:
        sx, sy, sz = (int(v) for v in piece[7])
        return sx, sy, sz
    return 1, 1, 1
def piece_cells(piece):
    sx, sy, sz = piece_size(piece)
    x, y, z = piece[0], piece[1], piece[2]
    return [(x + i, y + j, z + k) for i in range(sx) for j in range(sy) for k in range(sz)]
def local_size(piece):
    sx, sy, sz = piece_size(piece)
    return (sz, sy, sx) if piece[5] % 2 == 1 else (sx, sy, sz)
def merge_runs(pieces):
    groups, rest = {}, []
    for piece in pieces:
        if piece[3] in MERGE_SHAPES and piece_size(piece) == (1, 1, 1):
            groups.setdefault((piece[3], piece[4], piece[5], bool(piece[6])), {})[
                (piece[0], piece[1], piece[2])] = piece
        else:
            rest.append(list(piece))
    out = []
    for (shape, tex, turn, flip), cells_ in sorted(groups.items(), key=lambda kv: str(kv[0])):
        left = set(cells_)
        for start in sorted(cells_, key=lambda c: (c[1], c[2], c[0])):
            if start not in left:
                continue
            x, y, z = start
            most_x = STRETCH_MAX[2] if turn % 2 else STRETCH_MAX[0]
            most_z = STRETCH_MAX[0] if turn % 2 else STRETCH_MAX[2]
            sx = 1
            while sx < most_x and (x + sx, y, z) in left:
                sx += 1
            sz = 1
            while sz < most_z and all((x + i, y, z + sz) in left for i in range(sx)):
                sz += 1
            sy = 1
            while shape == "cube" and sy < STRETCH_MAX[1] and all(
                    (x + i, y + sy, z + k) in left for i in range(sx) for k in range(sz)):
                sy += 1
            for i in range(sx):
                for j in range(sy):
                    for k in range(sz):
                        left.discard((x + i, y + j, z + k))
            piece = [x, y, z, shape, tex, turn, flip]
            if (sx, sy, sz) != (1, 1, 1):
                piece.append([sx, sy, sz])
            out.append(piece)
    return out + rest
def manifest():
    _, rows = slopes().blocks.read_manifest()
    return {row["slug"]: row for row in rows}
def comes_in(slug, shape, rows=None):
    rows = rows or manifest()
    row = rows.get(slug)
    if row is None:
        return False
    if shape == "cube":
        return True
    return shape in slopes().shape_set(row)
def theme_table(theme):
    if theme is None:
        return {}
    sys.path.insert(0, HERE)
    try:
        from mapgen import kit as genkit
    finally:
        sys.path.pop(0)
    if genkit.THEMES.get(theme) is None:
        raise Refused("no theme %r (%s)" % (theme, ", ".join(sorted(genkit.THEMES))))
    return genkit.palette(theme)[0]
def texture_for(prefab, tex, shape, theme=None, rows=None):
    if not tex.startswith("@"):
        return tex
    role = tex[1:]
    table = theme_table(theme)
    want = None
    if role == "accent" and table.get("accents"):
        want = table["accents"][0]
    elif role in ROLE_TO_THEME:
        names = ROLE_TO_THEME[role]
        for name in (names if isinstance(names, tuple) else (names,)):
            want = table.get(name)
            if want is not None and comes_in(want, shape, rows):
                return want
    if want is not None and comes_in(want, shape, rows):
        return want
    default = prefab.get("roles", {}).get(role)
    if default is None:
        raise Refused("%s: role %r has no default texture" % (prefab["key"], role))
    return default
def piece_key(shape, slug, flip):
    if shape == "cube":
        return "blk" + slug
    return ("u" if flip else "") + shape + slug
def cells(prefab, at=(0, 0, 0), turn=0, theme=None):
    rows = manifest()
    out = []
    for piece in prefab["pieces"]:
        x, y, z, shape, tex, piece_turn, flip = piece[:7]
        sx, sy, sz = piece_size(piece)
        ax, az = turned(x, z, turn)
        bx, bz = turned(x + sx - 1, z + sz - 1, turn)
        tx, tz = min(ax, bx), min(az, bz)
        slug = texture_for(prefab, tex, shape, theme, rows)
        q = (piece_turn + turn) % 4
        out.append({"cell": (at[0] + tx, at[1] + y, at[2] + tz), "shape": shape, "slug": slug,
                    "turn": q, "flip": bool(flip), "key": piece_key(shape, slug, flip),
                    "yaw": q * 0x4000, "size": (abs(bx - ax) + 1, sy, abs(bz - az) + 1),
                    "local": local_size(piece)})
    return out
def footprint(prefab, turn=0):
    pts = [turned(c[0], c[2], turn) for p in prefab["pieces"] for c in piece_cells(p)]
    return (min(p[0] for p in pts), max(p[0] for p in pts),
            min(p[1] for p in pts), max(p[1] for p in pts),
            max(p[1] + piece_size(p)[1] for p in prefab["pieces"]))
def connectors(prefab, at=(0, 0, 0), turn=0):
    out = []
    for c in prefab.get("connectors", []):
        tx, tz = turned(c["at"][0], c["at"][2], turn)
        out.append({"cell": (at[0] + tx, at[1] + c["at"][1], at[2] + tz),
                    "face": face_turned(c["face"], turn), "kind": c["kind"]})
    return out
DIR = {(0, -1): "-z", (-1, 0): "-x", (0, 1): "+z", (1, 0): "+x"}
def _corner(turn):
    dx, dz = turned(-1, -1, turn)
    return ("-x" if dx < 0 else "+x") + ("-z" if dz < 0 else "+z")
def arena_pieces(prefab, at=(0, 0, 0), turn=0, theme=None, arenas=None):
    if arenas is None:
        arenas = _load("make_arenas", "make-arenas.py")
    sl = slopes()
    pieces, skipped = [], []
    for c in cells(prefab, at, turn, theme):
        cx, cy, cz = c["cell"]
        ex, ey, ez = c.get("size", (1, 1, 1))
        lw, lh, ld = c.get("local", (1, 1, 1))
        x0, x1 = cx * CELL - CELL // 2, (cx + ex - 1) * CELL + CELL // 2
        z0, z1 = cz * CELL - CELL // 2, (cz + ez - 1) * CELL + CELL // 2
        y0, y1 = cy * CELL, (cy + ey) * CELL
        mx, mz = (x0 + x1) // 2, (z0 + z1) // 2
        shape, tex, q = c["shape"], c["slug"], c["turn"]
        rises = DIR[turned(0, -1, q)]
        boxes = None
        if shape == "cube":
            boxes = [(-100, 100, 0, 200, -100, 100)]
        elif shape == "slab":
            boxes = [(-100, 100, 100, 200, -100, 100)] if c["flip"] else [(-100, 100, 0, 100, -100, 100)]
        elif shape == "plate" and not c["flip"]:
            pieces.append(arenas.slab(tex, x0, x1, z0, z1, y0, 20 * lh))
            continue
        elif shape == "plate":
            boxes = [(-100, 100, 180, 200, -100, 100)]
        elif shape in ("wall", "wallcorner", "wallt", "wallcross", "doorway", "window", "panel", "pole"):
            boxes = {"wall": sl.arms(sl.WALL_THICK, sl.TOP, False),
                     "wallcorner": sl.arms(sl.WALL_THICK, sl.TOP, True),
                     "wallt": sl.joint_boxes(False), "wallcross": sl.joint_boxes(True),
                     "doorway": sl.doorway_boxes(), "window": sl.window_boxes(),
                     "panel": [(-100, 100, 0, 200, -100, -100 + sl.PANEL_THICK)],
                     "pole": [(-sl.POLE_HALF, sl.POLE_HALF, 0, 200, -sl.POLE_HALF, sl.POLE_HALF)]}[shape]
            boxes = [(b[0], b[1], b[2], b[3], b[4], b[5]) for b in boxes]
        elif shape in getattr(sl, "LONG_SPANS", {}) and not c["flip"]:
            end = -100 + CELL * sl.LONG_SPANS[shape]
            t = sl.WALL_THICK // 2
            boxes = {"slab": [(-100, end, 0, 100, -100, 100)],
                     "plate": [(-100, end, 0, sl.PLATE_HIGH, -100, 100)],
                     "wall": [(-100, end, 0, 200, -t, t)],
                     "panel": [(-100, end, 0, 200, -100, -100 + sl.PANEL_THICK)]}[shape[:-1]]
        if boxes is not None:
            for bx0, bx1, by0, by1, bz0, bz1 in boxes:
                ax, az = turned(bx0 * lw, bz0 * ld, q)
                bx, bz = turned(bx1 * lw, bz1 * ld, q)
                pieces.append(arenas.box(tex, mx + min(ax, bx), mx + max(ax, bx),
                                         y0 + by0 * lh, y0 + by1 * lh,
                                         mz + min(az, bz), mz + max(az, bz)))
            continue
        if shape == "slope" and not c["flip"]:
            pieces.append(arenas.ramp(tex, x0, x1, z0, z1, y0, y1, rises))
        elif shape == "stairs":
            pieces.append(arenas.stairs(tex, x0, x1, z0, z1, y0, y1, rises))
        elif shape in ("outer", "inner") and not c["flip"]:
            pieces.append(arenas.ramp_corner(tex, x0, x1, z0, z1, y0, y1, _corner(q),
                                             inner=shape == "inner"))
        elif shape in ("outerstairs", "innerstairs"):
            pieces.append(arenas.corner_stairs(tex, x0, x1, z0, z1, y0, y1, _corner(q),
                                               inner=shape == "innerstairs"))
        elif shape == "pillar":
            pieces.append(arenas.pillar(tex, mx, mz, y0, y1, CELL * max(lw, ld)))
        elif shape == "arch":
            pieces.append(arenas.arch(tex, x0, x1, z0, z1, y0, y1))
        elif shape == "prism":
            pieces.append(arenas.prism(tex, x0, x1, z0, z1, y0, y1, _corner(q)))
        elif shape in ("fence", "fencecorner"):
            if shape == "fence":
                along_x = q % 2 == 0
                t = sl.FENCE_THICK // 2
                if along_x:
                    pieces.append(arenas.rail(tex, x0, x1, mz - t * ld, mz + t * ld, y0,
                                              sl.FENCE_HIGH * lh))
                else:
                    pieces.append(arenas.rail(tex, mx - t * ld, mx + t * ld, z0, z1, y0,
                                              sl.FENCE_HIGH * lh))
            else:
                t = sl.FENCE_THICK // 2
                corner = _corner(q)
                mx, mz = cx * CELL, cz * CELL
                xa = (x0, mx + t) if corner[0] == "-" else (mx - t, x1)
                za = (z0, mz + t) if corner[2] == "-" else (mz - t, z1)
                pieces.append(arenas.rail(tex, xa[0], xa[1], mz - t, mz + t, y0, sl.FENCE_HIGH))
                pieces.append(arenas.rail(tex, mx - t, mx + t, za[0], za[1], y0, sl.FENCE_HIGH))
        elif shape in ("wedge", "wedgetip") and not c["flip"] and hasattr(arenas, "ramp"):
            lo = sl.WEDGE_HIGH * lh if shape == "wedgetip" else 0
            if lo:
                pieces.append(arenas.box(tex, x0, x1, y0, y0 + lo, z0, z1))
            pieces.append(arenas.ramp(tex, x0, x1, z0, z1, y0 + lo, y0 + lo + sl.WEDGE_HIGH * lh,
                                      rises))
        elif shape in ("wedgeouter", "wedgeinner", "wedgetipouter", "wedgetipinner") \
                and not c["flip"]:
            lo = sl.WEDGE_HIGH * lh if "tip" in shape else 0
            if lo:
                pieces.append(arenas.box(tex, x0, x1, y0, y0 + lo, z0, z1))
            pieces.append(arenas.ramp_corner(tex, x0, x1, z0, z1, y0 + lo,
                                             y0 + lo + sl.WEDGE_HIGH * lh, _corner(q),
                                             inner=shape.endswith("inner")))
        elif shape in ("ridge", "pyramid") and hasattr(arenas, "roof") and not c["flip"]:
            along = "x" if q % 2 == 0 else "z"
            pieces.append(arenas.roof(shape, tex, x0, x1, z0, z1, y0, y0 + sl.RIDGE_HIGH * lh,
                                      along))
        elif shape == "roundcorner" and hasattr(arenas, "round_corner"):
            pieces.append(arenas.round_corner(tex, x0, x1, z0, z1, y0, y1, _corner(q)))
        else:
            skipped.append((c["cell"], shape, "no arena kind for it (Forge only)"))
    return pieces, skipped
def faults_of(prefab, rows=None, tags=None):
    rows = rows or manifest()
    tags = tags or set(slopes().shape_tags())
    out = []
    key = prefab["key"]
    if not re.match(r"^[a-z0-9]+$", key):
        out.append("%s: a prefab's key (its file name) is lower-case letters and digits" % key)
    if not prefab.get("name"):
        out.append("%s: no name" % key)
    pieces = prefab.get("pieces") or []
    if not pieces:
        out.append("%s: no pieces" % key)
        return out
    seen = {}
    long_spans = getattr(slopes(), "LONG_SPANS", {})
    for index, piece in enumerate(pieces):
        if len(piece) not in (7, 8):
            out.append("%s piece %d: want [x, y, z, shape, texture, turn, flip(, size)]"
                       % (key, index))
            continue
        x, y, z, shape, tex, turn, flip = piece[:7]
        if min(x, y, z) < 0:
            out.append("%s piece %d: below the anchor's corner (%d, %d, %d)" % (key, index, x, y, z))
        if len(piece) == 8:
            size = piece[7]
            if not (isinstance(size, list) and len(size) == 3
                    and all(isinstance(v, int) and v >= 1 for v in size)):
                out.append("%s piece %d: a size is [sx, sy, sz] whole cells" % (key, index))
                continue
            w, h, d = local_size(piece)
            if w > STRETCH_MAX[0] or h > STRETCH_MAX[1] or d > STRETCH_MAX[2]:
                out.append("%s piece %d: %dx%dx%d is past the stretch's %dx%dx%d"
                           % ((key, index, w, h, d) + STRETCH_MAX))
            if shape in long_spans:
                out.append("%s piece %d: a long %s does not stretch" % (key, index, shape))
        for cell in piece_cells(piece):
            if cell in seen:
                out.append("%s: two pieces in cell (%d, %d, %d)" % ((key,) + cell))
            seen[cell] = True
        if shape not in tags:
            out.append("%s piece %d: no shape %r" % (key, index, shape))
            continue
        if turn not in (0, 1, 2, 3):
            out.append("%s piece %d: turn %r" % (key, index, turn))
        try:
            slug = texture_for(prefab, tex, shape, None, rows)
        except Refused as why:
            out.append(str(why))
            continue
        if flip and not comes_in(slug, "u" + shape, rows):
            out.append("%s piece %d: %s has no upside-down %s" % (key, index, slug, shape))
        elif not comes_in(slug, shape, rows):
            out.append("%s piece %d: %s does not come in %s (tools/kit.py shapes)"
                       % (key, index, slug, shape))
    if min(p[0] for p in pieces if len(p) >= 3) != 0 \
            or min(p[1] for p in pieces if len(p) >= 3) != 0 \
            or min(p[2] for p in pieces if len(p) >= 3) != 0:
        out.append("%s: the anchor (0, 0, 0) is not the footprint's corner" % key)
    x0, x1, z0, z1, _ = footprint(prefab)
    for c in prefab.get("connectors", []):
        cx, cy, cz = c.get("at", (None, None, None))
        face, kind = c.get("face"), c.get("kind")
        if face not in FACES or kind not in KINDS:
            out.append("%s: connector %r (faces %s, kinds %s)" % (key, c, list(FACES), KINDS))
            continue
        dx, dz = FACES[face]
        edge = (dx < 0 and cx == x0) or (dx > 0 and cx == x1) or \
               (dz < 0 and cz == z0) or (dz > 0 and cz == z1)
        if not edge:
            out.append("%s: connector at %s does not face out of the footprint" % (key, c["at"]))
    return out
MOVER_SHAPES = ("log", "logwide")
MOVER_MODES = ("loop", "pingpong", "oneway")
MOVER_TRIGGERS = ("always", "ridden", "wired")
MAX_LINK = 31
LOGIC_KINDS = ("target", "button", "zone")
WIRE_EVENTS = ("pressed", "entered", "left", "hit", "alldown", "timer")
WIRE_ACTIONS = ("raise", "start", "flip", "timer_start", "timer_stop", "message", "finish")
WIRE_NUMBERED = ("raise", "start")
_WIRE_EVENT_CODE = {"pressed": "p", "entered": "e", "left": "l", "hit": "h", "alldown": "a",
                    "timer": "t"}
_WIRE_ACTION_CODE = {"raise": "r", "start": "s", "flip": "o", "timer_start": "b",
                     "timer_stop": "x", "message": "m", "finish": "f"}
MOVER_MAX_POINTS = 12
def mover_faults(prefab, rows=None, tags=None):
    out = []
    key = prefab["key"]
    for index, mv in enumerate(prefab.get("movers") or []):
        name = "%s mover %d" % (key, index)
        at = mv.get("at") or []
        if len(at) != 3 or min(at) < 0:
            out.append("%s: at %r (a cell from the anchor's corner)" % (name, at))
        shape = mv.get("shape")
        if shape not in MOVER_SHAPES:
            if shape != "cube" and shape not in (tags or ()):
                out.append("%s: no shape %r" % (name, shape))
            else:
                try:
                    slug = texture_for(prefab, mv.get("tex"), shape, None, rows)
                    if shape != "cube" and not comes_in(slug, shape, rows):
                        out.append("%s: %s does not come in %s" % (name, slug, shape))
                except Refused as why:
                    out.append(str(why))
        if mv.get("mode", "pingpong") not in MOVER_MODES:
            out.append("%s: way round %r" % (name, mv.get("mode")))
        if mv.get("trigger", "always") not in MOVER_TRIGGERS:
            out.append("%s: start %r" % (name, mv.get("trigger")))
        if mv.get("trigger") == "wired" and not 1 <= int(mv.get("link", 0)) <= MAX_LINK:
            out.append("%s: a mover started by a wire needs a number 1-%d" % (name, MAX_LINK))
        pts = mv.get("points") or []
        if not 2 <= len(pts) <= MOVER_MAX_POINTS:
            out.append("%s: %d points (2 to %d)" % (name, len(pts), MOVER_MAX_POINTS))
        elif list(pts[0][:3]) != [0, 0, 0]:
            out.append("%s: its first point is not where it stands" % name)
        if any(len(p) != 5 for p in pts):
            out.append("%s: a point is [dx, dy, dz, speed, wait]" % name)
    return out
def logic_faults(prefab):
    out = []
    key = prefab["key"]
    links = set()
    for index, lg in enumerate(prefab.get("logic") or []):
        name = "%s logic %d" % (key, index)
        at = lg.get("at") or []
        if len(at) != 3 or min(at) < 0:
            out.append("%s: at %r (a cell from the anchor's corner)" % (name, at))
        if lg.get("kind") not in LOGIC_KINDS:
            out.append("%s: kind %r" % (name, lg.get("kind")))
        if not 1 <= int(lg.get("link", 0)) <= MAX_LINK:
            out.append("%s: number %r (1-%d)" % (name, lg.get("link"), MAX_LINK))
        links.add(int(lg.get("link", 0)))
    for mv in prefab.get("movers") or []:
        if mv.get("trigger") == "wired":
            links.add(int(mv.get("link", 0)))
    for index, w in enumerate(prefab.get("wires") or []):
        name = "%s wire %d" % (key, index)
        if len(w) < 4 or w[0] not in WIRE_EVENTS or w[2] not in WIRE_ACTIONS:
            out.append("%s: %r is not a wire" % (name, w))
            continue
        if w[0] != "timer" and int(w[1]) not in links:
            out.append("%s: number %r is nothing of this prefab" % (name, w[1]))
        if w[2] in WIRE_NUMBERED and int(w[3]) not in links:
            out.append("%s: number %r is nothing of this prefab" % (name, w[3]))
    return out
def _logic_lua(prefab):
    return ['{ %d, %d, %d, "%s", %d, %d }'
            % (lg["at"][0], lg["at"][1], lg["at"][2], lg["kind"], int(lg.get("turn", 0)),
               int(lg["link"])) for lg in prefab.get("logic") or []]
def _wire_lua(prefab):
    out = []
    for w in prefab.get("wires") or []:
        arg = "" if len(w) < 5 or w[4] in (None, "") else (', "%s"' % str(w[4]).replace('"', ""))
        out.append('{ "%s", %d, "%s", %d%s }' % (w[0], int(w[1]), w[2], int(w[3]), arg))
    return out
def pipe_faults(prefab):
    out = []
    key = prefab["key"]
    pipes = prefab.get("pipes") or []
    tags = [p.get("tag", 0) for p in pipes]
    for index, pp in enumerate(pipes):
        name = "%s pipe %d" % (key, index)
        at = pp.get("at") or []
        if len(at) != 3 or min(at) < 0:
            out.append("%s: at %r (a cell from the anchor's corner)" % (name, at))
        if pp.get("turn", 0) not in (0, 1, 2, 3):
            out.append("%s: turn %r" % (name, pp.get("turn")))
        if "level" in pp:
            if not re.match(r"^(\d+|c[A-Za-z0-9]+)$", str(pp["level"])):
                out.append("%s: level %r (a number, or c and a name)" % (name, pp["level"]))
        elif pp.get("pair", 0):
            if pp["pair"] not in tags or pp["pair"] == pp.get("tag", 0):
                out.append("%s: its pair %r is no other pipe here" % (name, pp["pair"]))
    return out
def _pipe_lua(prefab):
    out = []
    for pp in prefab.get("pipes") or []:
        if "level" in pp:
            kind, level, area = 1, str(pp["level"]), int(pp.get("area", 1))
        elif pp.get("pair", 0):
            kind, level, area = 2, "-", 1
        else:
            kind, level, area = 0, "-", 1
        out.append('{ %d, %d, %d, %d, %d, "%s", %d, %d, %d }'
                   % (pp["at"][0], pp["at"][1], pp["at"][2], pp.get("turn", 0), kind, level,
                      area, int(pp.get("tag", 0)), int(pp.get("pair", 0))))
    return out
def _mover_lua(prefab, rows):
    out = []
    for mv in prefab.get("movers") or []:
        shape = mv["shape"]
        slug = "" if shape in MOVER_SHAPES else texture_for(prefab, mv.get("tex"), shape, None, rows)
        pts = ", ".join("{ %d, %d, %d, %d, %d }" % tuple(int(v) for v in p) for p in mv["points"])
        out.append('{ %d, %d, %d, "%s", "%s", %d, "%s", "%s", %d, { %s } }'
                   % (mv["at"][0], mv["at"][1], mv["at"][2], shape, slug, mv.get("turn", 0),
                      mv.get("mode", "pingpong"), mv.get("trigger", "always"),
                      int(mv.get("phase", 0)), pts))
        if mv.get("trigger") == "wired":
            out[-1] = out[-1][:-2] + ", %d }" % int(mv.get("link", 0))
    return out
def lua_table(library):
    rows = manifest()
    lines = [BEGIN,
             "-- Each prefab: its cells relative to the anchor (x, y, z), the shape, the",
             "-- default texture's slug, the quarter turn and the flip, and a stretched",
             "-- piece's size in the prefab's cells. Laid by `OF.forge.prefab_place`;",
             "-- the library is prefabs/*.prefab.",
             "spawner.PREFABS = {"]
    for key, prefab in library.items():
        x0, x1, z0, z1, h = footprint(prefab)
        lines.append('    { key = "%s", name = "%s", size = { %d, %d, %d }, pieces = {'
                     % (key, prefab["name"].replace('"', ""), x1 - x0 + 1, h, z1 - z0 + 1))
        for piece in prefab["pieces"]:
            x, y, z, shape, tex, turn, flip = piece[:7]
            slug = texture_for(prefab, tex, shape, None, rows)
            size = piece_size(piece)
            tail = "" if size == (1, 1, 1) else (", { %d, %d, %d }" % size)
            lines.append('        { %d, %d, %d, "%s", "%s", %d, %s%s },'
                         % (x, y, z, shape, slug, turn, "true" if flip else "false", tail))
        movers = _mover_lua(prefab, rows)
        if movers:
            lines.append("    }, movers = {")
            for row in movers:
                lines.append("        %s," % row)
        logic = _logic_lua(prefab)
        if logic:
            lines.append("    }, logic = {")
            for row in logic:
                lines.append("        %s," % row)
        wires = _wire_lua(prefab)
        if wires:
            lines.append("    }, wires = {")
            for row in wires:
                lines.append("        %s," % row)
        pipes = _pipe_lua(prefab)
        if pipes:
            lines.append("    }, pipes = {")
            for row in pipes:
                lines.append("        %s," % row)
        lines.append("    } },")
    lines.append("}")
    lines.append(END)
    return "\n".join(lines) + "\n"
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
def spliced(text, block):
    text = luaregion().restore(text, "of_spawner.lua")
    start, stop = text.find(BEGIN), text.find(END)
    if start < 0 or stop < start or text.count(BEGIN) != 1:
        raise Refused("of_spawner.lua has no single PREFABS region")
    return text[:start] + block + text[stop + len(END) + 1:]
def build(check):
    library = load_all()
    rows = manifest()
    tags = set(slopes().shape_tags())
    faults = []
    for prefab in library.values():
        faults += faults_of(prefab, rows, tags)
        faults += mover_faults(prefab, rows, tags)
        faults += pipe_faults(prefab)
        faults += logic_faults(prefab)
    if faults:
        raise Refused("; ".join(faults))
    with open(SPAWNER, encoding="utf-8") as handle:
        text = handle.read()
    wanted = luaregion().finish(spliced(text, lua_table(library)),
                               os.path.dirname(os.path.abspath(SPAWNER)))
    if check:
        if wanted != text:
            raise Refused("the PREFABS table in of_spawner.lua is out of date - run tools/prefabs.py")
        print("prefabs: %d prefabs, %d pieces, all current"
              % (len(library), sum(len(p["pieces"]) for p in library.values())))
        return 0
    if wanted != text:
        with open(SPAWNER, "w", encoding="utf-8") as handle:
            handle.write(wanted)
    print("prefabs: %d prefabs written into of_spawner.lua" % len(library))
    return 0
def read_save(path):
    parts = {}
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            found = re.match(r"^\s*prefab_draft(\d+)\s*=\s*(.*?)\s*$", line)
            if found:
                parts[int(found.group(1))] = found.group(2)
    if not parts:
        raise Refused("%s: no prefab draft in it (Forge -> Save the marked box as a prefab)" % path)
    return "".join(parts[k] for k in sorted(parts))
def parse_draft(text):
    items = text.split(";")
    if items[0] != "v1":
        raise Refused("a draft of another version (%r)" % items[0])
    pieces = []
    for item in items[1:]:
        if not item or item.startswith(("mv.", "pp.", "lg.", "lw.")):
            continue
        fields = item.split(".")
        shape, slug, x, y, z, turn, flip = fields[:7]
        piece = [int(x), int(y), int(z), shape, slug, int(turn), flip == "1"]
        if len(fields) > 7 and re.match(r"^\d+x\d+x\d+$", fields[7]):
            size = [int(v) for v in fields[7].split("x")]
            if size != [1, 1, 1]:
                piece.append(size)
        pieces.append(piece)
    if not pieces:
        raise Refused("an empty draft")
    return pieces
def parse_draft_movers(text):
    out = []
    for item in text.split(";")[1:]:
        if not item.startswith("mv."):
            continue
        parts = item.split(".")
        if len(parts) not in (11, 12):
            raise Refused("a mover in the draft is not readable (%r)" % item[:40])
        _, shape, slug, x, y, z, turn, mode, trigger, phase, pts = parts[:11]
        row = {"at": [int(x), int(y), int(z)], "shape": shape, "turn": int(turn),
               "mode": mode, "trigger": trigger, "phase": int(phase),
               "points": [[int(v) for v in p.split(":")] for p in pts.split(",") if p]}
        if len(parts) == 12:
            row["link"] = int(parts[11])
        if slug != "-":
            row["tex"] = slug
        out.append(row)
    return out
def parse_draft_logic(text):
    events = {v: k for k, v in _WIRE_EVENT_CODE.items()}
    actions = {v: k for k, v in _WIRE_ACTION_CODE.items()}
    logic, wires = [], []
    for item in text.split(";")[1:]:
        if item.startswith("lg."):
            parts = item.split(".")
            if len(parts) != 7:
                raise Refused("a logic piece in the draft is not readable (%r)" % item[:40])
            _, kind, x, y, z, turn, link = parts
            logic.append({"at": [int(x), int(y), int(z)], "kind": kind, "turn": int(turn),
                          "link": int(link)})
        elif item.startswith("lw."):
            m = re.match(r"^lw\.([a-z])(\d+)([a-z])(\d+)(?::(.*))?$", item)
            if m is None or m.group(1) not in events or m.group(3) not in actions:
                raise Refused("a wire in the draft is not readable (%r)" % item[:40])
            row = [events[m.group(1)], int(m.group(2)), actions[m.group(3)], int(m.group(4))]
            if m.group(5):
                row.append(m.group(5))
            wires.append(row)
    return logic, wires
def parse_draft_pipes(text):
    out = []
    for item in text.split(";")[1:]:
        if not item.startswith("pp."):
            continue
        parts = item.split(".")
        if len(parts) != 10:
            raise Refused("a pipe in the draft is not readable (%r)" % item[:40])
        _, x, y, z, turn, kind, level, area, tag, pair = parts
        row = {"at": [int(x), int(y), int(z)], "turn": int(turn)}
        if kind == "1" and level != "-":
            row["level"], row["area"] = level, int(area)
        elif kind == "2":
            row["tag"], row["pair"] = int(tag), int(pair)
        out.append(row)
    tags = {r.get("tag") for r in out if "tag" in r}
    for r in out:
        if "pair" in r and r["pair"] not in tags:
            del r["pair"], r["tag"]
    return out
def read_draft(path):
    rc, mapping = old_keys()
    return parse_draft(rc.recode_draft(read_save(path), mapping)[0])
def cmd_import_save(argv):
    if len(argv) < 1 or "--name" not in argv:
        raise Refused('import-save <file.sav> --name "Its name" [--roles wall=redbrick,...]')
    path = argv[0]
    name = argv[argv.index("--name") + 1]
    key = key_for(name)
    pieces = merge_runs(read_draft(path))
    rc, mapping = old_keys()
    movers = parse_draft_movers(rc.recode_draft(read_save(path), mapping)[0])
    pipes = parse_draft_pipes(read_save(path))
    logic, wires = parse_draft_logic(read_save(path))
    roles = {}
    if "--roles" in argv:
        for pair in argv[argv.index("--roles") + 1].split(","):
            role, slug = pair.split("=")
            roles[role.strip()] = slug.strip()
        by_slug = {slug: role for role, slug in roles.items()}
        for piece in pieces:
            if piece[4] in by_slug:
                piece[4] = "@" + by_slug[piece[4]]
    prefab = {"name": name, "tags": [], "roles": roles, "pieces": pieces, "connectors": []}
    if movers:
        prefab["movers"] = movers
    if pipes:
        prefab["pipes"] = pipes
    if logic:
        prefab["logic"] = logic
    if wires:
        prefab["wires"] = wires
    target = add(prefab, key)
    print("prefabs: %s, %d pieces - add connectors by hand if it joins others"
          % (os.path.relpath(target, ROOT), len(pieces)))
    return build(False)
def key_for(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())
def add(prefab, key=None, replace=False):
    key = key or key_for(prefab.get("name", ""))
    prefab = dict(prefab)
    prefab["key"] = key
    faults = (faults_of(prefab) + mover_faults(prefab, tags=set(slopes().shape_tags()))
              + pipe_faults(prefab) + logic_faults(prefab))
    if faults:
        raise Refused("; ".join(faults))
    target = os.path.join(LIBRARY, key + ".prefab")
    if os.path.exists(target) and not replace:
        raise Refused("%s exists - pick another name" % os.path.relpath(target, ROOT))
    del prefab["key"]
    os.makedirs(LIBRARY, exist_ok=True)
    write_prefab(target, prefab)
    return target
def update(key, **fields):
    prefab = get(key)
    for field, value in fields.items():
        if field not in ("name", "tags", "roles", "connectors"):
            raise Refused("a prefab has no field %r to change" % field)
        if value is not None:
            prefab[field] = value
    own = prefab.pop("key")
    add(prefab, own, replace=True)
    prefab["key"] = own
    return prefab
def delete(key):
    path = os.path.join(LIBRARY, key + ".prefab")
    if not os.path.exists(path):
        raise Refused("no prefab %r" % key)
    os.remove(path)
def write_prefab(path, prefab):
    head = {k: v for k, v in prefab.items() if k not in ("pieces", "key")}
    text = json.dumps(head, indent=2)
    pieces = ",\n".join("    " + json.dumps(p) for p in prefab["pieces"])
    text = text[:-2] + ',\n  "pieces": [\n' + pieces + "\n  ]\n}\n"
    json.loads(text)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
def cmd_list(argv):
    for key, prefab in load_all().items():
        x0, x1, z0, z1, h = footprint(prefab)
        print("%-12s %-16s %dx%dx%d cells, %3d pieces, connectors: %s" % (
            key, prefab["name"], x1 - x0 + 1, h, z1 - z0 + 1, len(prefab["pieces"]),
            ", ".join("%s %s" % (c["kind"], c["face"]) for c in prefab.get("connectors", []))
            or "none"))
    return 0
def cmd_sheet(argv):
    from PIL import Image, ImageDraw
    sheet_tool = _load("make_shape_sheet", "make-shape-sheet.py")
    sl = slopes()
    rows = manifest()
    tiles = []
    for key, prefab in load_all().items():
        faces, textures = [], {}
        for c in cells(prefab):
            variant = next((v for v in sl.variants() if v["tag"] == ("u" if c["flip"] else "") + c["shape"]),
                           None)
            if c["shape"] == "cube":
                variant = {"tag": "cube", "flip": False,
                           "faces": sl.box_faces(sl.LO, sl.HI, 0, sl.TOP, sl.LO, sl.HI)}
            solid = sl.solid(variant)
            cx, cy, cz = c["cell"]
            for pts, n in solid:
                moved = []
                for p in pts:
                    x, z = turned(p[0], p[2], c["turn"])
                    moved.append((x + cx * CELL, p[1] + cy * CELL, z + cz * CELL))
                nx, nz = turned(n[0], n[2], c["turn"])
                faces.append((moved, (nx, n[1], nz), c["slug"], pts, n))
            if c["slug"] not in textures:
                png, _ = sl.row_textures(rows[c["slug"]])
                textures[c["slug"]] = sheet_tool.texture(png)
        tiles.append((prefab["name"], render_group(sheet_tool, sl, faces, textures)))
    cell, columns = 440, 3
    rows_n = (len(tiles) + columns - 1) // columns
    out = Image.new("RGB", (columns * cell, rows_n * (cell + 18) + 24), (20, 21, 28))
    draw = ImageDraw.Draw(out)
    draw.text((8, 6), "Prefab library - tools/prefabs.py sheet", fill=(240, 240, 240))
    for i, (label, img) in enumerate(tiles):
        x, y = (i % columns) * cell, 24 + (i // columns) * (cell + 18)
        out.paste(img, (x, y))
        draw.text((x + 6, y + cell + 2), label, fill=(220, 220, 220))
    path = os.path.join(ROOT, "docs", "shapes", "prefabs.png")
    out.save(path, optimize=True)
    print("prefabs: %s" % os.path.relpath(path, ROOT))
    return 0
def render_group(sheet_tool, sl, faces, textures, size=440):
    import math
    from PIL import Image
    xs = [p[0] for f in faces for p in f[0]]
    ys = [p[1] for f in faces for p in f[0]]
    zs = [p[2] for f in faces for p in f[0]]
    mid = ((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2)
    span = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    k = 250.0 / span
    img = None
    zbuf = None
    d = sheet_tool.norm(sheet_tool.VIEW)
    right = sheet_tool.norm((d[2], 0.0, -d[0]))
    up = sheet_tool.norm((d[1] * right[2] - d[2] * right[1], d[2] * right[0] - d[0] * right[2],
                          d[0] * right[1] - d[1] * right[0]))
    if up[1] < 0:
        up = tuple(-c for c in up)
    light = sheet_tool.norm(sheet_tool.LIGHT)
    img = Image.new("RGB", (size, size), (34, 36, 46))
    px = img.load()
    zbuf = [[-1e9] * size for _ in range(size)]
    scale = size / 330.0
    def project(p):
        q = ((p[0] - mid[0]) * k, (p[1] - mid[1]) * k, (p[2] - mid[2]) * k)
        sx = size / 2 + (q[0] * right[0] + q[1] * right[1] + q[2] * right[2]) * scale
        sy = size / 2 - (q[0] * up[0] + q[1] * up[1] + q[2] * up[2]) * scale
        depth = q[0] * d[0] + q[1] * d[1] + q[2] * d[2]
        return sx, sy, depth
    for pts, normal, slug, own, own_normal in faces:
        nn = sheet_tool.norm(normal)
        if nn[0] * d[0] + nn[1] * d[1] + nn[2] * d[2] <= 0:
            continue
        shade = 0.45 + 0.55 * max(0.0, nn[0] * light[0] + nn[1] * light[1] + nn[2] * light[2])
        tex = textures[slug]
        tw, th = tex.size
        tpx = tex.load()
        local = own
        for i in range(1, len(pts) - 1):
            tri = [pts[0], pts[i], pts[i + 1]]
            loc = [local[0], local[i], local[i + 1]]
            uvs = [sl.uv(l, own_normal) for l in loc]
            scr = [project(p) for p in tri]
            minx = max(0, int(min(s[0] for s in scr)))
            maxx = min(size - 1, int(max(s[0] for s in scr)) + 1)
            miny = max(0, int(min(s[1] for s in scr)))
            maxy = min(size - 1, int(max(s[1] for s in scr)) + 1)
            (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = scr
            area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            if abs(area) < 1e-9:
                continue
            for yy in range(miny, maxy + 1):
                for xx in range(minx, maxx + 1):
                    w0 = ((x1 - xx) * (y2 - yy) - (x2 - xx) * (y1 - yy)) / area
                    w1 = ((x2 - xx) * (y0 - yy) - (x0 - xx) * (y2 - yy)) / area
                    w2 = 1 - w0 - w1
                    if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                        continue
                    depth = w0 * z0 + w1 * z1 + w2 * z2
                    if depth <= zbuf[yy][xx]:
                        continue
                    zbuf[yy][xx] = depth
                    u = (w0 * uvs[0][0] + w1 * uvs[1][0] + w2 * uvs[2][0]) / 992.0
                    v = (w0 * uvs[0][1] + w1 * uvs[1][1] + w2 * uvs[2][1]) / 992.0
                    r, g, b = tpx[int(min(max(u, 0), 0.999) * tw), int(min(max(v, 0), 0.999) * th)][:3]
                    px[xx, yy] = (int(r * shade), int(g * shade), int(b * shade))
    return img
def cmd_selftest(argv):
    import tempfile
    faults = []
    try:
        build(True)
    except Refused as why:
        faults.append(str(why))
    rows = manifest()
    library = load_all()
    arenas = _load("make_arenas", "make-arenas.py")
    laid = 0
    for key, prefab in library.items():
        for turn in range(4):
            placed = cells(prefab, (10, 2, -7), turn)
            spots = {c["cell"] for c in placed}
            if len(spots) != len(prefab["pieces"]):
                faults.append("%s turned %d: pieces share a cell" % (key, turn))
            x0, x1, z0, z1, _ = footprint(prefab, turn)
            xs = [c["cell"][0] - 10 for c in placed]
            zs = [c["cell"][2] + 7 for c in placed]
            if (min(xs), max(xs), min(zs), max(zs)) != (x0, x1, z0, z1):
                faults.append("%s turned %d: footprint" % (key, turn))
            for c in connectors(prefab, (10, 2, -7), turn):
                dx, dz = FACES[c["face"]]
                cx, cz = c["cell"][0] - 10, c["cell"][2] + 7
                if not ((dx < 0 and cx == x0) or (dx > 0 and cx == x1)
                        or (dz < 0 and cz == z0) or (dz > 0 and cz == z1)):
                    faults.append("%s turned %d: a connector turned off the edge" % (key, turn))
            for theme in (None, "castle", "ice", "wood"):
                pieces, skipped = arena_pieces(prefab, (10, 2, -7), turn, theme, arenas)
                laid += len(pieces)
                for piece in pieces:
                    if piece["tex"] not in rows:
                        faults.append("%s: arena texture %s" % (key, piece["tex"]))
                for c in cells(prefab, (10, 2, -7), turn, theme):
                    if not comes_in(c["slug"], ("u" if c["flip"] else "") + c["shape"]
                                    if c["shape"] != "cube" else "cube", rows):
                        faults.append("%s in %s: %s does not come in %s"
                                      % (key, theme, c["slug"], c["shape"]))
    with tempfile.TemporaryDirectory() as tmp:
        sav = os.path.join(tmp, "oldfart.sav")
        with open(sav, "w") as handle:
            handle.write("[storage]\nprefab_draft1 = v1;cube.redbrick.0.0.0.0.0;slope.re\n"
                         "prefab_draft2 = dbrick.0.1.0.2.0\nprefab_draft3 = \n")
        draft = parse_draft(read_save(sav))
        if draft != [[0, 0, 0, "cube", "redbrick", 0, False], [0, 1, 0, "slope", "redbrick", 2, False]]:
            faults.append("a saved draft read back as %s" % draft)
    pipe_draft = ("v1;cube.redbrick.0.0.0.0.0;pp.1.0.0.0.2.-.1.11.12;pp.2.0.0.1.2.-.1.12.11;"
                  "pp.0.1.0.0.1.cWonderTower.2.13.0;pp.3.0.0.0.2.-.1.14.99")
    pipes = parse_draft_pipes(pipe_draft)
    want = [{"at": [1, 0, 0], "turn": 0, "tag": 11, "pair": 12},
            {"at": [2, 0, 0], "turn": 1, "tag": 12, "pair": 11},
            {"at": [0, 1, 0], "turn": 0, "level": "cWonderTower", "area": 2},
            {"at": [3, 0, 0], "turn": 0}]
    if pipes != want or len(parse_draft(pipe_draft)) != 1:
        faults.append("a draft's pipes read back as %s" % pipes)
    piped = {"key": "pipetest", "pipes": pipes}
    if pipe_faults(piped):
        faults.append("good pipes refused: %s" % pipe_faults(piped))
    if not pipe_faults({"key": "pipetest", "pipes": [dict(want[0], pair=77)]}):
        faults.append("a pipe paired with nothing was let through")
    if '{ 2, 0, 0, 1, 2, "-", 1, 12, 11 }' not in _pipe_lua(piped) \
            or '{ 0, 1, 0, 0, 1, "cWonderTower", 2, 0, 0 }' not in _pipe_lua(piped):
        faults.append("the pipes' Lua rows read %s" % _pipe_lua(piped))
    table = lua_table({"pipetest": dict(piped, name="Pipe test", roles={},
                                        pieces=[[0, 0, 0, "cube", "redbrick", 0, False]])})
    if "}, pipes = {" not in table or '"cWonderTower"' not in table:
        faults.append("the PREFABS table has no pipes")
    wired_draft = ("v1;cube.redbrick.0.0.0.0.0;mv.slab.redbrick.1.0.0.0.pingpong.wired.0."
                   "0:0:0:300:10,0:600:0:300:10.7;lg.button.0.1.0.0.7;lw.p7s7;lw.p7m0:2")
    logic, wires = parse_draft_logic(wired_draft)
    movers = parse_draft_movers(wired_draft)
    if (logic != [{"at": [0, 1, 0], "kind": "button", "turn": 0, "link": 7}]
            or wires != [["pressed", 7, "start", 7], ["pressed", 7, "message", 0, "2"]]
            or movers[0].get("link") != 7 or len(parse_draft(wired_draft)) != 1):
        faults.append("a wired draft read back as %s %s %s" % (logic, wires, movers))
    wired = {"key": "wiretest", "logic": logic, "wires": wires, "movers": movers}
    if logic_faults(wired):
        faults.append("good wires refused: %s" % logic_faults(wired))
    if not logic_faults(dict(wired, wires=[["pressed", 9, "start", 7]])):
        faults.append("a wire to a number outside the prefab was let through")
    if '{ 0, 1, 0, "button", 0, 7 }' not in _logic_lua(wired) \
            or '{ "pressed", 7, "message", 0, "2" }' not in _wire_lua(wired):
        faults.append("the logic's Lua rows read %s %s" % (_logic_lua(wired), _wire_lua(wired)))
    if not _mover_lua(dict(wired, roles={}), manifest())[0].endswith(", 7 }"):
        faults.append("a wired mover's Lua row has no number")
    if faults:
        print("prefabs selftest: " + "; ".join(faults[:6]))
        return 1
    print("prefabs selftest: ok, %d prefabs four ways, %d arena pieces, a draft read back"
          % (len(library), laid))
    return 0
def cmd_merge(argv):
    library = load_all()
    keys = argv or list(library)
    for key in keys:
        prefab = library.get(key)
        if prefab is None:
            raise Refused("no prefab %r" % key)
        before = len(prefab["pieces"])
        merged = merge_runs(prefab["pieces"])
        if len(merged) == before:
            print("prefabs: %s - %d pieces, nothing to merge" % (key, before))
            continue
        prefab["pieces"] = merged
        own = prefab.pop("key")
        add(prefab, own, replace=True)
        print("prefabs: %s - %d pieces -> %d" % (key, before, len(merged)))
    return build(False)
USAGE = """Prefabs: a built structure kept as one reusable object.

    tools/prefabs.py                  write the Forge's PREFABS table
    tools/prefabs.py --check          exit 1 if a prefab is broken or the table stale
    tools/prefabs.py list             every prefab: size, pieces, connectors, KB
    tools/prefabs.py import-save <file.sav> --name "My house" [--roles wall=redbrick,...]
                                      a structure saved in the game -> prefabs/<key>.prefab
    tools/prefabs.py sheet            docs/shapes/prefabs.png, the library drawn
    tools/prefabs.py merge [key...]   runs of one cube/slab/plate -> stretched pieces"""
def main(argv):
    try:
        if not argv or argv[0] == "--check":
            return build(argv[:1] == ["--check"])
        command, rest = argv[0], argv[1:]
        if command == "list":
            return cmd_list(rest)
        if command == "import-save":
            return cmd_import_save(rest)
        if command == "sheet":
            return cmd_sheet(rest)
        if command == "selftest":
            return cmd_selftest(rest)
        if command == "merge":
            return cmd_merge(rest)
        print(USAGE)
        return 2
    except Refused as why:
        print("prefabs: %s" % why)
        return 1
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
