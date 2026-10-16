import importlib.util
import math
import os
import re
import struct
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
DATA_TYPE_LIGHT, DATA_TYPE_TEXTURE, DATA_TYPE_VERTEX = 1, 2, 3
DATA_TYPE_DISPLAY_LIST, DATA_TYPE_GEO_LAYOUT = 4, 5
DATA_TYPE_COLLISION, DATA_TYPE_LEVEL_SCRIPT, DATA_TYPE_MACRO_OBJECT = 11, 12, 13
POINTER, FUNCTION, LUA_VAR, TEX_REF = 0x52544E50, 0x434E5546, 0x5641554C, 0x52584554
class BakeError(ValueError):
    pass
def read_nodes(body):
    nodes = []
    i = 0
    n = len(body)
    def take(k):
        nonlocal i
        if i + k > n:
            raise BakeError("the level body runs off its end at %d" % i)
        chunk = body[i:i + k]
        i += k
        return chunk
    def name():
        return take(take(1)[0]).decode("latin-1")
    def u32():
        return struct.unpack("<I", take(4))[0]
    def word():
        v = u32()
        if v == POINTER:
            label = name()
            return ("ptr", label, u32())
        if v == FUNCTION:
            return ("fn", u32())
        if v == LUA_VAR:
            return ("lua", name())
        return v
    while i < n:
        kind = take(1)[0]
        label = name()
        if kind == DATA_TYPE_LIGHT:
            data = take(24)
        elif kind == DATA_TYPE_TEXTURE:
            size = struct.unpack("<i", take(4))[0]
            data = ("ref", name()) if size == struct.unpack("<i", struct.pack("<I", TEX_REF))[0] \
                else ("png", take(size))
        elif kind == DATA_TYPE_VERTEX:
            data = [take(16) for _ in range(u32())]
        elif kind == DATA_TYPE_DISPLAY_LIST:
            data = [(word(), word()) for _ in range(u32())]
        elif kind in (DATA_TYPE_GEO_LAYOUT, DATA_TYPE_LEVEL_SCRIPT):
            data = [word() for _ in range(u32())]
        elif kind in (DATA_TYPE_COLLISION, DATA_TYPE_MACRO_OBJECT):
            count = u32()
            data = list(struct.unpack("<%dh" % count, take(2 * count)))
        elif kind == 17:
            data = take(u32())
        else:
            raise BakeError("node type %d (%s) is not one a venue level carries" % (kind, label))
        nodes.append((kind, label, data))
    return nodes
def _name_bytes(label):
    raw = label.encode("latin-1")
    if len(raw) > 255:
        raise BakeError("%s is too long for a DynOS name" % label)
    return bytes([len(raw)]) + raw
def _word_bytes(w):
    if isinstance(w, tuple):
        if w[0] == "ptr":
            return struct.pack("<I", POINTER) + _name_bytes(w[1]) + struct.pack("<I", w[2])
        if w[0] == "fn":
            return struct.pack("<II", FUNCTION, w[1])
        if w[0] == "lua":
            return struct.pack("<I", LUA_VAR) + _name_bytes(w[1])
        raise BakeError("unknown word %r" % (w,))
    return struct.pack("<I", w & 0xFFFFFFFF)
def write_nodes(nodes):
    out = bytearray()
    for kind, label, data in nodes:
        out.append(kind)
        out += _name_bytes(label)
        if kind == DATA_TYPE_LIGHT:
            out += data
        elif kind == DATA_TYPE_TEXTURE:
            if data[0] == "ref":
                out += struct.pack("<I", TEX_REF) + _name_bytes(data[1])
            else:
                out += struct.pack("<i", len(data[1])) + data[1]
        elif kind == DATA_TYPE_VERTEX:
            out += struct.pack("<I", len(data)) + b"".join(data)
        elif kind == DATA_TYPE_DISPLAY_LIST:
            out += struct.pack("<I", len(data))
            for w0, w1 in data:
                out += _word_bytes(w0) + _word_bytes(w1)
        elif kind in (DATA_TYPE_GEO_LAYOUT, DATA_TYPE_LEVEL_SCRIPT):
            out += struct.pack("<I", len(data)) + b"".join(_word_bytes(w) for w in data)
        elif kind == 17:
            out += struct.pack("<I", len(data)) + bytes(data)
        else:
            out += struct.pack("<I", len(data)) + struct.pack("<%dh" % len(data), *data)
    return bytes(out)
_arenas = None
def arenas_tool():
    global _arenas
    if _arenas is None:
        spec = importlib.util.spec_from_file_location(
            "venuebake_arenas", os.path.join(HERE, "make-arenas.py"))
        _arenas = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_arenas)
    return _arenas
def wants_bake(arena):
    return bool(arena.get("_generated", arena.get("_file"))) and arena.get("bake") is not False
def prepared(arena):
    import copy
    m = arenas_tool()
    arena = copy.deepcopy(arena)
    m.connect([p for p in arena["pieces"] if float(p.get("yaw", 0) or 0) % 90 == 0])
    for piece in arena["pieces"]:
        piece["model"] = m.model_name(piece)
    return arena
WORLD = 32767
def _turn(yaw):
    a = math.radians(float(yaw or 0))
    return math.cos(a), math.sin(a)
def to_world(point, piece, c, s):
    x, y, z = point
    return (piece["x"] + x * c + z * s, piece["y"] + y, piece["z"] - x * s + z * c)
def kind_of_row(piece):
    return "decor" if piece.get("decor") and piece.get("pass") else piece["kind"]
def _box_piece(x0, x1, y0, y1, z0, z1, tex="invisible"):
    return {"kind": "box", "tex": tex, "x": (x0 + x1) / 2.0, "y": y0, "z": (z0 + z1) / 2.0,
            "w": x1 - x0, "h": y1 - y0, "d": z1 - z0, "yaw": 0}
def _in_frame(part, piece):
    c, s = _turn(piece.get("yaw", 0))
    x, y, z = to_world((part["x"], part["y"], part["z"]), piece, c, s)
    out = dict(part)
    out.update(x=x, y=y, z=z, yaw=(float(piece.get("yaw", 0) or 0) + float(part.get("yaw", 0) or 0)))
    return out
JOIN_CELL, JOIN_TOP, JOIN_WALL, JOIN_PILLAR = 200, 200, 50, 60
JOIN_ARMS = ((1, 0), (0, 1), (-1, 0), (0, -1))
def join_arms(piece):
    join = piece.get("join") or {}
    arms = join.get("arms") or "0000"
    tex = join.get("other") or piece["tex"]
    lo, hi = JOIN_PILLAR - JOIN_WALL, JOIN_CELL / 2.0
    half = JOIN_WALL / 2.0
    out = []
    for k, (dx, dz) in enumerate(JOIN_ARMS):
        if arms[k:k + 1] != "1":
            continue
        if dx:
            a, b = sorted((dx * lo, dx * hi))
            box = _box_piece(a, b, 0, JOIN_TOP, -half, half, tex)
        else:
            a, b = sorted((dz * lo, dz * hi))
            box = _box_piece(-half, half, 0, JOIN_TOP, a, b, tex)
        out.append(box)
    return out
def _decor():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import decor
    return decor
_solids = {}
def kit_solid(kind, floor=False, piece=None):
    m = arenas_tool()
    key = (kind, floor, (piece["w"], piece["h"]) if kind == "rail" and not floor and piece else None)
    if key not in _solids:
        _solids[key] = m.solid(kind, floor=floor, piece=piece)
    return _solids[key]
def solid_parts(piece):
    m = arenas_tool()
    kind = kind_of_row(piece)
    if piece.get("decor"):
        dec = _decor()
        r = dec.BY_KEY.get(piece["decor"])
        if r is not None and r["key"] in dec.SOLIDS:
            return [("box", _in_frame(_box_piece(*b), piece)) for b in dec.solid_boxes(r)]
        if kind == "decor":
            return []
        return [("box", piece)]
    if kind not in m.SOLIDS or kind in m.VISUAL_KINDS:
        return []
    out = [(kind, piece)]
    if piece.get("join") and kind == "pillar":
        out += [("box", _in_frame(arm, piece)) for arm in join_arms(piece)]
    return out
def collision_triangles(piece):
    m = arenas_tool()
    out = []
    for kind, part in solid_parts(piece):
        c, s = _turn(part.get("yaw", 0))
        surface = m.SURFACES[kind]
        if part.get("slide") and kind == "ramp":
            surface = m.SURFACE_ICE
        for pts, _ in kit_solid(kind, floor=True):
            world = [tuple(int(round(v)) for v in to_world(m.scaled(p, part), part, c, s))
                     for p in pts]
            for tri in m.slopes.triangles(world):
                a, b, cc = tri
                n = m.slopes.cross(m.slopes.sub(b, a), m.slopes.sub(cc, b))
                if n == (0, 0, 0) or tuple(n) == (0, 0, 0):
                    continue
                out.append((surface, m.slopes.sort_first(tri)))
    return out
def bakeable(piece):
    m = arenas_tool()
    if piece.get("decor"):
        if piece["decor"] not in _decor().BY_KEY:
            return False
    elif piece.get("kind") not in m.SOLIDS:
        return False
    reach = math.sqrt(piece["w"] ** 2 + piece["d"] ** 2) / 2.0 + 1200
    return (abs(piece["x"]) + reach < WORLD and abs(piece["z"]) + reach < WORLD
            and -WORLD < piece["y"] - 1200 and piece["y"] + piece["h"] + 1200 < WORLD)
def split_rows(arena):
    static, runtime = [], []
    for i, piece in enumerate(arena["pieces"]):
        (static if bakeable(piece) else runtime).append(i)
    return static, runtime
TERRAIN_LOAD_VERTICES, TERRAIN_LOAD_CONTINUE, TERRAIN_LOAD_END = 0x40, 0x41, 0x42
TERRAIN_LOAD_OBJECTS, TERRAIN_LOAD_ENVIRONMENT = 0x43, 0x44
SURFACE_FORCE = (0x0004, 0x000E, 0x0024, 0x0025, 0x0027, 0x002C, 0x002D)
SECTION_MOST = 32767
SURFACE_NAMES = {0x0000: "SURFACE_DEFAULT", 0x0001: "SURFACE_BURNING",
                 0x000A: "SURFACE_DEATH_PLANE", 0x0014: "SURFACE_SLIPPERY",
                 0x0015: "SURFACE_NOT_SLIPPERY",
                 0x002E: "SURFACE_ICE"}
def split_collision(words):
    sections = []
    i = 0
    while True:
        t = words[i]
        if t == TERRAIN_LOAD_VERTICES:
            count = words[i + 1]
            verts = [tuple(words[i + 2 + 3 * k:i + 5 + 3 * k]) for k in range(count)]
            sections.append((verts, []))
            i += 2 + 3 * count
        elif t == TERRAIN_LOAD_CONTINUE:
            return sections, list(words[i:])
        elif t < TERRAIN_LOAD_VERTICES or t > 0x65:
            if not sections:
                raise BakeError("a triangle group before any vertices")
            per = 4 if t in SURFACE_FORCE else 3
            count = words[i + 1]
            tris = [tuple(words[i + 2 + per * k:i + 2 + per * (k + 1)]) for k in range(count)]
            sections[-1][1].append((t, tris))
            i += 2 + per * count
        else:
            raise BakeError("collision word %#x before TERRAIN_LOAD_CONTINUE is not read here" % t)
def join_collision(sections, tail):
    words = []
    for verts, groups in sections:
        words += [TERRAIN_LOAD_VERTICES, len(verts)]
        for v in verts:
            words += list(v)
        for surface, tris in groups:
            words += [surface, len(tris)]
            for t in tris:
                words += list(t)
    return words + list(tail)
def collision_sections(triangles):
    sections = []
    index, verts, groups = None, None, None
    def close():
        if verts:
            sections.append((verts, [(s, groups[s]) for s in order]))
    order = []
    for surface, tri in triangles:
        if index is None or len(verts) + sum(1 for p in tri if p not in index) > SECTION_MOST \
                or len(groups.get(surface, ())) >= SECTION_MOST:
            close()
            index, verts, groups, order = {}, [], {}, []
        ids = []
        for p in tri:
            if p not in index:
                index[p] = len(verts)
                verts.append(p)
            ids.append(index[p])
        if surface not in groups:
            groups[surface] = []
            order.append(surface)
        groups[surface].append(tuple(ids))
    close()
    return sections
def _find(nodes, kind, label):
    for k, node in enumerate(nodes):
        if node[0] == kind and node[1] == label:
            return k
    raise BakeError("the level has no %s node %s" % (kind, label))
def _collision_node(nodes):
    for k, node in enumerate(nodes):
        if node[0] == DATA_TYPE_COLLISION and node[1].endswith("_area_1_collision"):
            return k
    raise BakeError("the level has no area collision node")
SPLIT = 800
CHUNK_SPAN = 2048
CHUNK_SPAN_GIANT = 4096
GIANT_HALF = 13000
CHUNK_LEAST, CHUNK_MOST = 1500, 6000
CHUNK_FROM_ACROSS = 6000
CHUNK_FROM_TRIANGLES = 20000
LOAD_MOST = 64
TAB = "\t"
TEX_PERIOD = 32 * 32
TEX_SHIFT = 8
CULL_MARGIN = 1.15
FAR = 32767
LOD_NEAR = 16000
FAR_GROUND = False
HORIZON_SPAN = 8192
LOD_LEAST = 60
FRUSTUM_FAR_BASE = 30000
WATER_TINT = (225, 240, 255)
WATER_ALPHA = 120
_kit = None
def kit_textures():
    global _kit
    if _kit is None:
        _kit = arenas_tool().kit_textures()
    return _kit
GROUND_PERIOD = 640
LIBRARY = os.path.join("assets-incoming", "1006", "textures")
GROUND_FAMILIES = ("snowice", "volcanic")
NOT_GROUND_FAMILIES = ("wood", "woodset", "fabric", "metal", "decor", "facade", "special")
FOLIAGE_NAMES = ("leaves", "hedge", "fern", "flowers", "mushrooms", "vine", "ivy")
COARSE_SIDE = 2000
MASONRY_CLASSES = ("brick", "ashlar", "block", "cobble", "flag", "tile", "rib", "grain")
_texinfo = None
def _library():
    path = os.path.join(os.path.dirname(HERE), LIBRARY, "library.json")
    if not os.path.isfile(path):
        return {}
    import json
    with open(path, encoding="utf-8") as handle:
        lib = json.load(handle)
    return {e["file"]: e for e in lib.values() if isinstance(e, dict) and e.get("file")}
def role_of_entry(entry):
    if entry is None:
        return "detail"
    if str(entry.get("name", "")).startswith(FOLIAGE_NAMES):
        return "detail"
    cls, fam = entry.get("scale_class"), entry.get("family")
    roles = set(entry.get("roles") or ())
    if cls == "grain" and fam not in NOT_GROUND_FAMILIES and not roles & {"accent", "foliage"} \
            and ("nature" in roles or fam in GROUND_FAMILIES):
        return "ground"
    if cls == "roof":
        return "roof"
    if cls == "plank" or fam in ("wood", "woodset"):
        return "wood"
    if cls in MASONRY_CLASSES:
        return "masonry"
    return "detail"
def texture_info():
    global _texinfo
    if _texinfo is None:
        m = arenas_tool()
        lib = _library()
        root = os.path.dirname(HERE)
        prefix = LIBRARY.replace(os.sep, "/") + "/"
        out = {}
        _, rows = m.blocks.read_manifest()
        for row in rows:
            top = (row.get("layers") or [row["source"]])[0]
            rel = top.replace(os.sep, "/")
            entry = lib.get(rel[len(prefix):]) if rel.startswith(prefix) else None
            info = (role_of_entry(entry), os.path.join(root, top))
            out[row["slug"]] = info
            for old in row.get("was") or ():
                out.setdefault(old, info)
        _texinfo = out
    return _texinfo
def texture_role(slug):
    return texture_info().get(slug, ("detail", None))[0]
_hi = {}
def hi_png(slug):
    if slug not in _hi:
        path = texture_info().get(slug, (None, None))[1]
        png = None
        if path:
            got = arenas_tool().blocks.shipped_texture(path)
            if png_size(got) == (64, 64):
                png = got
        _hi[slug] = png
    return _hi[slug]
def coarse(slug, layer):
    return texture_role(slug) == "ground" and layer in (0, None) and hi_png(slug) is not None
def ground_uv(point, normal):
    m = arenas_tool()
    unit = m.TEX_PX * 32 / float(GROUND_PERIOD)
    x, y, z = point
    if abs(normal[1]) > 0.5:
        return x * unit, z * unit
    ux, uz = normal[2], -normal[0]
    ln = math.sqrt(ux * ux + uz * uz) or 1.0
    return (x * ux + z * uz) / ln * unit, -y * unit
GLOW_SLUGS = ("crystalamethyst", "crystalblue", "crystalrose", "glowamber", "glowblue",
              "glowgreen", "glowpink", "lanterncool", "lanternwarm", "lava", "magmacrust")
WINDOW_SLUGS = ("winarched", "wincottage", "winround", "winshop", "winshutter", "winstone")
GLOW_RGB = (255, 255, 255)
DAY_GLOW = 0.62
DAY_WHOLE = ("lava", "magmacrust")
LIT_GLASS = (255, 204, 118)
EVENING_EL = 15.0
def glows(tex):
    return tex[0] in GLOW_SLUGS or (len(tex) > 2 and tex[2] == "lit")
def evening(arena):
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    mood = look.get("mood") if isinstance(look.get("mood"), dict) else {}
    if mood.get("darkness"):
        return True
    pal = venue_palette(look)
    sun = _unit(pal["sun"])
    if math.degrees(math.asin(max(-1.0, min(1.0, sun[1])))) < EVENING_EL:
        return True
    return pal["sunc"][2] > pal["sunc"][0]
DARK_STOPS = {"dusk": (100, 100, 100), "night": (70, 70, 70), "pitch": (45, 45, 45),
              "a red night": (110, 45, 45), "a green murk": (50, 100, 60),
              "a cold blue": (50, 70, 115), "sodium dusk": (120, 85, 40),
              "a purple hour": (95, 55, 120), "hospital light": (105, 125, 105),
              "under water": (45, 85, 105)}
MOON = (0.86, 0.94, 1.22)
NIGHT_FLOOR = (17, 20, 28)
DARK_LIFT = 0.85
def night_tint(arena):
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    mood = look.get("mood") if isinstance(look.get("mood"), dict) else {}
    d = mood.get("darkness")
    if not d:
        return None
    if isinstance(d, (int, float)) and not isinstance(d, bool):
        g = max(45.0, min(110.0, 255.0 * (1.0 - float(d)) + 20.0))
        stop = (g, g, g)
    else:
        stop = DARK_STOPS.get(str(d), DARK_STOPS["night"])
    grey = stop[0] == stop[1] == stop[2]
    return tuple(min(1.0, c / 255.0 * DARK_LIFT * (m if grey else 1.0))
                 for c, m in zip(stop, MOON))
def _glass(r, g, b):
    return b >= r + 10 and b >= g - 4 and (r + g + b) < 3 * 190
_lit = {}
TEXTURE_MOST = 64
LIT_FALLBACK = ("glowamber", 0)
def lit_within(polys):
    used = set(p[0] for p in polys)
    lit = set(t for t in used if len(t) > 2 and t[2] == "lit")
    if not lit or len(used) <= TEXTURE_MOST:
        return polys
    return [((LIT_FALLBACK,) + p[1:]) if p[0] in lit else p for p in polys]
def lit_png(slug, layer=0):
    if (slug, layer) not in _lit:
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(texture_png((slug, layer)))).convert("RGBA")
        px = im.load()
        for yy in range(im.size[1]):
            for xx in range(im.size[0]):
                r, g, b, a = px[xx, yy]
                if _glass(r, g, b):
                    k = 0.78 + 0.22 * min(1.0, (r + g + b) / (3 * 150.0))
                    px[xx, yy] = (int(LIT_GLASS[0] * k), int(LIT_GLASS[1] * k),
                                  int(LIT_GLASS[2] * k), a)
        for yy in range(im.size[1]):
            for xx in range(im.size[0]):
                r, g, b, a = px[xx, yy]
                px[xx, yy] = ((r >> 3) * 255 // 31, (g >> 3) * 255 // 31, (b >> 3) * 255 // 31,
                              255 if a >= 128 else 0)
        out = io.BytesIO()
        im.save(out, "PNG", optimize=True)
        _lit[(slug, layer)] = out.getvalue()
    return _lit[(slug, layer)]
_panes = {}
PANE_LIFT = 2
def glass_rect(slug, layer=0):
    if (slug, layer) not in _panes:
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(texture_png((slug, layer)))).convert("RGBA")
        px = im.load()
        xs, ys = [], []
        for yy in range(im.size[1]):
            for xx in range(im.size[0]):
                r, g, b, _ = px[xx, yy]
                if _glass(r, g, b):
                    xs.append(xx)
                    ys.append(yy)
        k = TEX_PERIOD // im.size[0]
        _panes[(slug, layer)] = None if not xs else (min(xs) * k, min(ys) * k, (max(xs) + 1) * k,
                                                     (max(ys) + 1) * k)
    return _panes[(slug, layer)]
def glass_polys(poly, tex, normal):
    rect = glass_rect(tex[0], tex[1])
    if rect is None:
        return []
    out = []
    s_lo, s_hi = min(p[3] for p in poly), max(p[3] for p in poly)
    t_lo, t_hi = min(p[4] for p in poly), max(p[4] for p in poly)
    for i in range(int(math.floor(s_lo / TEX_PERIOD)), int(math.floor(s_hi / TEX_PERIOD)) + 1):
        for j in range(int(math.floor(t_lo / TEX_PERIOD)), int(math.floor(t_hi / TEX_PERIOD)) + 1):
            piece = list(poly)
            for axis, lo, hi in ((3, i * TEX_PERIOD + rect[0], i * TEX_PERIOD + rect[2]),
                                 (4, j * TEX_PERIOD + rect[1], j * TEX_PERIOD + rect[3])):
                piece = _clip(piece, axis, lo)[1] if piece else piece
                piece = _clip(piece, axis, hi)[0] if piece else piece
            if _area_ok(piece):
                out.append([(p[0] + normal[0] * PANE_LIFT, p[1] + normal[1] * PANE_LIFT,
                             p[2] + normal[2] * PANE_LIFT, p[3], p[4]) for p in piece])
    return out
LIGHT_PRESETS = {
    "lantern": {"colour": (255, 190, 125), "radius": 1800, "peak": 2.0, "live": (2000, 2.4),
                "flicker": (0.04, 0.5, 0.0, 0.0)},
    "torch": {"colour": (255, 160, 70), "radius": 700, "peak": 0.5, "live": (1200, 3.4),
              "flicker": (0.10, 2.0, 0.05, 8.0)},
    "campfire": {"colour": (255, 150, 60), "radius": 1100, "peak": 0.55, "live": (1650, 4.5),
                 "flicker": (0.12, 1.2, 0.08, 5.0)},
    "candle": {"colour": (255, 175, 100), "radius": 300, "peak": 0.35, "live": (600, 2.5),
               "flicker": (0.04, 0.7, 0.03, 8.0)},
    "crystal": {"colour": (120, 205, 255), "radius": 800, "peak": 0.8, "live": (1200, 2.4),
                "flicker": (0.15, 0.25, 0.0, 0.0)},
    "lava": {"colour": (255, 100, 30), "radius": 1000, "peak": 0.4, "live": (1800, 3.6),
             "live_colour": (255, 160, 80),
             "flicker": (0.10, 0.3, 0.04, 1.5)},
    "window": {"colour": (255, 200, 135), "radius": 500, "peak": 0.35, "live": (900, 1.9),
               "flicker": (0.0, 0.0, 0.0, 0.0)},
    "mushroom": {"colour": (90, 240, 200), "radius": 400, "peak": 0.3, "live": (750, 2.0),
                 "flicker": (0.20, 0.2, 0.0, 0.0)},
    "magic": {"colour": (255, 240, 160), "radius": 800, "peak": 0.5, "live": (1200, 1.5),
              "flicker": (0.08, 4.0, 0.05, 7.0)},
    "neon": {"colour": (255, 60, 170), "radius": 450, "peak": 0.4, "live": (900, 3.3),
             "live_colour": (255, 150, 215),
             "flicker": (0.0, 0.0, 0.0, 0.0)},
}
LIVE_NORMALS = ("campfire", "lava")
LIVE_ORDER = ("campfire", "torch", "lantern", "candle", "magic", "crystal", "lava", "mushroom",
              "neon", "window")
DUSK_LIVE = 0.7
LIGHT_PRESET_ORDER = ("lantern", "torch", "campfire", "candle", "crystal", "lava", "window",
                      "mushroom", "magic", "neon")
LIGHT_STOPS = {"dim": (0.6, 0.85), "normal": (1.0, 1.0), "bright": (1.3, 1.15)}
GLOW_LIGHT = {
    "crystalamethyst": ("crystal", (200, 130, 255)), "crystalblue": ("crystal", (120, 205, 255)),
    "crystalrose": ("crystal", (255, 150, 210)), "glowamber": ("lantern", (255, 182, 100)),
    "glowblue": ("crystal", (110, 180, 255)), "glowgreen": ("mushroom", (110, 240, 170)),
    "glowpink": ("neon", (255, 90, 190)), "lanterncool": ("lantern", (200, 220, 255)),
    "lanternwarm": ("lantern", None), "lava": ("lava", None), "magmacrust": ("lava", (255, 90, 30)),
}
LIGHTS_MOST = 512
LIVE_MOST = 256
LIGHT_MERGE = 450
DAY_POOL = 0.35
LIGHT_BELOW = 80
LAVA_CELL = 800
LAVA_LIFT = 150
CAMPFIRE_LIFT = 80
WINDOW_OUT = 150
class Light(tuple):
    __slots__ = ()
    def __new__(cls, x, y, z, colour, radius, peak, live, flicker, preset):
        lr, li = live if live else (0, 0.0)
        return tuple.__new__(cls, (int(round(x)), int(round(y)), int(round(z)),
                                   tuple(int(c) for c in colour), int(round(radius)),
                                   round(float(peak), 3), int(round(lr)), round(float(li), 3),
                                   tuple(round(float(v), 3) for v in flicker), preset))
    x = property(lambda s: s[0])
    y = property(lambda s: s[1])
    z = property(lambda s: s[2])
    colour = property(lambda s: s[3])
    radius = property(lambda s: s[4])
    peak = property(lambda s: s[5])
    live_radius = property(lambda s: s[6])
    live_intensity = property(lambda s: s[7])
    flicker = property(lambda s: s[8])
    preset = property(lambda s: s[9])
LIVE_MOST_INTENSITY = 5.0
def light_of(spec):
    if isinstance(spec, str):
        spec = {"preset": spec}
    if not isinstance(spec, dict):
        return None
    name = spec.get("preset") if spec.get("preset") in LIGHT_PRESETS else "lantern"
    base = LIGHT_PRESETS[name]
    k, kr = LIGHT_STOPS.get(spec.get("bright"), LIGHT_STOPS["normal"])
    try:
        col = tuple(max(0, min(255, int(c))) for c in (spec.get("colour") or base["colour"]))
        radius = max(100.0, min(4000.0, float(spec.get("radius", base["radius"] * kr))))
        peak = max(0.0, min(2.0, float(spec.get("peak", base["peak"] * k))))
        live = spec.get("live") or base["live"]
        if live:
            live = (max(100.0, min(4000.0, float(live[0]) * kr)), max(0.0, min(LIVE_MOST_INTENSITY, float(live[1]) * k)))
        flicker = tuple(float(v) for v in (spec.get("flicker") or base["flicker"]))
    except (TypeError, ValueError, IndexError):
        return None
    if len(col) != 3 or len(flicker) != 4:
        return None
    return col, radius, peak, live or None, flicker, name
def _box_middle(part):
    return (part["x"], part["y"] + part["h"] / 2.0, part["z"])
def light_sources(arena, static=None, terrain=None):
    pieces = arena["pieces"] if static is None else [arena["pieces"][i] for i in static]
    consumed = terrain.consumed if terrain is not None else set()
    if static is not None:
        pieces = [p for i, p in zip(static, pieces) if i not in consumed]
    lit = evening(arena)
    raw = []
    lava = {}
    for piece in pieces:
        own = light_of(piece.get("light"))
        if own is not None:
            col, radius, peak, live, flicker, name = own
            h = piece.get("h", 0)
            y = piece["y"] + (h + 40 if name in FLAME_SIZE else h * 0.75)
            if isinstance(piece.get("light"), dict) and piece["light"].get("below"):
                y = piece["y"] - LIGHT_BELOW
            raw.append((piece["x"], y, piece["z"], col, radius, peak, live, flicker, name, 4.0))
        fire = piece.get("decor") == "campfire"
        done_fire = False
        for part in drawn_parts(piece):
            slug = part.get("tex")
            if slug in GLOW_LIGHT and own is None:
                name, col = GLOW_LIGHT[slug]
                if fire:
                    if done_fire:
                        continue
                    done_fire = True
                    name, col = "campfire", None
                spec = LIGHT_PRESETS[name]
                x, y, z = _box_middle(part)
                if fire:
                    y = piece["y"] + CAMPFIRE_LIFT
                if name == "lava" and not piece.get("decor"):
                    for (lx, lz) in _cells_over(part, LAVA_CELL):
                        lava.setdefault((lx, lz), []).append(part["y"] + part["h"])
                    continue
                raw.append((x, y, z, col or spec["colour"], spec["radius"], spec["peak"],
                            spec["live"], spec["flicker"], name, 1.0))
            elif lit and slug in WINDOW_SLUGS and part.get("kind") == "box":
                spec = LIGHT_PRESETS["window"]
                x, y, z = _box_middle(part)
                yaw = math.radians(part.get("yaw", 0) or 0)
                if part["w"] <= part["d"]:
                    nx, nz = math.cos(yaw), -math.sin(yaw)
                    half = part["w"] / 2.0
                else:
                    nx, nz = math.sin(yaw), math.cos(yaw)
                    half = part["d"] / 2.0
                for sgn in (1, -1):
                    out_ = half + WINDOW_OUT
                    raw.append((x + sgn * nx * out_, y, z + sgn * nz * out_, spec["colour"],
                                spec["radius"], spec["peak"], spec["live"], spec["flicker"],
                                "window", 0.5))
    if terrain is not None:
        for tface in terrain.faces:
            corners, normal, tex = tface[:3]
            if GLOW_LIGHT.get(tex[0], ("",))[0] == "lava" and normal[1] > 0.5:
                x = sum(c[0] for c in corners) / len(corners)
                z = sum(c[2] for c in corners) / len(corners)
                key = (int(math.floor(x / LAVA_CELL)), int(math.floor(z / LAVA_CELL)))
                lava.setdefault(key, []).append(max(c[1] for c in corners))
    spec = LIGHT_PRESETS["lava"]
    for (i, j) in sorted(lava):
        raw.append(((i + 0.5) * LAVA_CELL, max(lava[(i, j)]) + LAVA_LIFT, (j + 0.5) * LAVA_CELL,
                    spec["colour"], spec["radius"], spec["peak"], spec["live"], spec["flicker"],
                    "lava", 1.0))
    merged = []
    for r in sorted(raw, key=lambda r: (r[0], r[1], r[2], r[8], tuple(r[3]))):
        x, y, z, col, radius, peak, live, flicker, name, wgt = r
        for m in merged:
            if m[8] == name and tuple(m[3]) == tuple(col) and abs(m[0] / m[9] - x) < LIGHT_MERGE \
                    and abs(m[2] / m[9] - z) < LIGHT_MERGE and abs(m[1] / m[9] - y) < LIGHT_MERGE:
                m[0] += x * wgt
                m[1] += y * wgt
                m[2] += z * wgt
                m[9] += wgt
                break
        else:
            merged.append([x * wgt, y * wgt, z * wgt, col, radius, peak, live, flicker, name, wgt])
    merged.sort(key=lambda m: (-m[9] * m[4], m[0], m[2]))
    out = [Light(m[0] / m[9], m[1] / m[9], m[2] / m[9], m[3], m[4], m[5], m[6], m[7], m[8])
           for m in merged[:LIGHTS_MOST]]
    out.sort()
    return out
def _cells_over(part, cell):
    x0, x1 = part["x"] - part["w"] / 2.0, part["x"] + part["w"] / 2.0
    z0, z1 = part["z"] - part["d"] / 2.0, part["z"] + part["d"] / 2.0
    out = []
    for i in range(int(math.floor(x0 / cell)), int(math.floor((x1 - 1) / cell)) + 1):
        for j in range(int(math.floor(z0 / cell)), int(math.floor((z1 - 1) / cell)) + 1):
            out.append((i, j))
    return out
LIGHT_BANDS = {"night": ((0.25, 0.45), (3.0, 8.0)), "dusk": ((0.15, 0.45), (2.0, 8.0))}
LIGHT_SAMPLES = 400
LIT_AT = 0.5
GLOW_STRUCTURE = 600
STREET_NEAR = 400
FOOT_NEAR = (250, 650)
LEAK_PROBE = 150
LIVE_REACH = 2500
def _band(v, lo, hi, soft):
    if lo <= v <= hi:
        return 1.0
    d = (lo - v) if v < lo else (v - hi)
    return max(0.0, 1.0 - d / soft)
def light_critic(arena, points=None):
    prep = prepared(arena)
    static, _ = split_rows(prep)
    terrain = terrain_of(prep)
    lights = light_sources(prep, static, terrain)
    tint = night_tint(prep)
    dark = evening(prep)
    if not lights and not dark:
        return {}
    bake = _bake_module()
    consumed = terrain.consumed if terrain is not None else set()
    rows_ = [r for k, r in enumerate(light_rows(prep)) if k not in consumed]
    if terrain is not None:
        rows_ += carved_occluders(terrain, [prep["pieces"][i] for i in static])
    grid = bake.Grid(rows_)
    out = {}
    around = ((LEAK_PROBE, 0, 0), (-LEAK_PROBE, 0, 0), (0, 0, LEAK_PROBE), (0, 0, -LEAK_PROBE),
              (0, LEAK_PROBE, 0))
    inside = [L for L in lights if L.preset != "window" and all(
        grid.solid(L.x + dx, L.y + dy, L.z + dz) for dx, dy, dz in around)]
    out["light_leaks"] = {"value": len(inside), "score": round(max(0.0, 1.0 - len(inside) / 3.0), 3),
                          "note": "%d light(s) inside a solid (their pools never reach out)"
                                  % len(inside) if inside else "every light stands in the open",
                          "where": [(int(L.x), int(L.z)) for L in inside[:20]]}
    pieces = [prep["pieces"][i] for i in static]
    glowing = [p for p in pieces if p.get("tex") in GLOW_SLUGS and p.get("kind") != "water"
               and p.get("tex") not in DAY_WHOLE]
    struct = [p for p in glowing if sorted((p.get("w", 0), p.get("h", 0), p.get("d", 0)))[1]
              >= GLOW_STRUCTURE]
    out["glow_on_structure"] = {
        "value": len(struct), "score": round(max(0.0, 1.0 - len(struct) / 4.0), 3),
        "note": "%d big piece(s) glowing - a lamp's glass glows, its post and walls do not"
                % len(struct) if struct else "only small parts glow",
        "where": [(int(p["x"]), int(p["z"])) for p in struct[:20]]}
    unlit = [p for p in glowing if p not in struct and not any(
        abs(L.x - p["x"]) < L.radius and abs(L.z - p["z"]) < L.radius for L in lights)]
    out["emitter_without_light"] = {
        "value": len(unlit), "score": round(max(0.0, 1.0 - len(unlit) / 6.0), 3),
        "note": "%d glowing part(s) cast no light" % len(unlit) if unlit else
                "every glowing part is a light"}
    live = [L for L in lights if L.live_radius > 0]
    most = 0
    for L in live:
        most = max(most, sum(1 for M in live if abs(M.x - L.x) < LIVE_REACH
                             and abs(M.z - L.z) < LIVE_REACH))
    out["live_budget"] = {"value": most, "score": round(1.0 if most <= 16 else
                                                        max(0.0, 1.0 - (most - 16) / 16.0), 3),
                          "note": "at most %d live lights near one spot (the engine burns the "
                                  "nearest 16)" % most}
    if not dark:
        return out
    look = prep.get("look") if isinstance(prep.get("look"), dict) else {}
    stop = str(((look.get("mood") or {}) if isinstance(look.get("mood"), dict) else {})
               .get("darkness") or "dusk")
    (slo, shi), (clo, chi) = LIGHT_BANDS["dusk" if stop in ("dusk", "sodium dusk") else "night"]
    if points is None:
        from mapgen import place
        points = [(x, y, z) for x, y, z, _ in place.standing_points(prep)]
    from mapgen import autolight
    ways = [p for p in pieces if any(w in (p.get("tag") or "") for w in autolight.PATH_WORDS)]
    if ways:
        def near_way(pt):
            for w in ways:
                hw, hd = w["w"] / 2.0 + STREET_NEAR, w["d"] / 2.0 + STREET_NEAR
                if int(w.get("yaw", 0) or 0) % 180 == 90:
                    hw, hd = hd, hw
                if abs(pt[0] - w["x"]) <= hw and abs(pt[2] - w["z"]) <= hd:
                    return True
            return False
        on = [pt for pt in points if near_way(pt)]
        if on:
            points = on
    if len(points) > LIGHT_SAMPLES:
        k = len(points) / float(LIGHT_SAMPLES)
        points = [points[int(i * k)] for i in range(LIGHT_SAMPLES)]
    pal = venue_palette(look)
    sun = _unit(pal["sun"])
    base = bake.shade(pal, sun, (0.0, 1.0, 0.0), 1.0, 1.0, bake.PAINT_MID)
    if tint is not None:
        base = tuple(c * k for c, k in zip(base, tint))
    floor = max(1.0, sum(base) / 3.0)
    spots = Lights(lights)
    lit, ratios = 0, []
    for x, y, z in points:
        add, share = spots.add(grid, x, y + 2, z, (0.0, 1.0, 0.0), 1.0)
        a = sum(add) / 3.0
        if a >= LIT_AT * floor:
            lit += 1
    for L in lights:
        if L.preset not in ("lantern", "campfire", "torch", "crystal", "mushroom", "magic"):
            continue
        foot = [p for p in points if FOOT_NEAR[0] <= math.hypot(p[0] - L.x, p[2] - L.z)
                <= FOOT_NEAR[1] and -1200 < p[1] - L.y < 0]
        if not foot:
            continue
        x, y, z = min(foot, key=lambda p: ((p[0] - L.x) ** 2 + (p[2] - L.z) ** 2, p))
        add, _ = spots.add(grid, x, y + 2, z, (0.0, 1.0, 0.0), 1.0)
        ratios.append((floor + sum(add) / 3.0) / floor)
    share = lit / float(len(points)) if points else 0.0
    out["lit_share"] = {"value": round(share, 3),
                        "score": round(_band(share, slo, shi, 0.25), 3),
                        "note": "%d %% of the streets' floor in a pool (%s wants %d - %d %%)"
                                % (round(share * 100), stop, slo * 100, shi * 100)}
    if ratios:
        ratios.sort()
        med = ratios[len(ratios) // 2]
        out["pool_contrast"] = {"value": round(med, 2),
                                "score": round(_band(med, clo, chi, 2.0), 3),
                                "note": "a pool %.1f : 1 over its floor (%s wants %g - %g : 1)"
                                        % (med, stop, clo, chi)}
    return out
def dusk(arena):
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    mood = look.get("mood") if isinstance(look.get("mood"), dict) else {}
    d = mood.get("darkness")
    if d:
        return "dusk" in str(d)
    return evening(arena)
def live_rows(lights, dusk_=False):
    k = DUSK_LIVE if dusk_ else 1.0
    keyed = []
    for L in lights:
        if L.live_radius <= 0:
            continue
        base = LIGHT_PRESETS.get(L.preset) or {}
        col = tuple(base["live_colour"]) if base.get("live_colour") and \
            L.colour == tuple(base["colour"]) else L.colour
        row = (L.x, L.y, L.z) + col + (L.live_radius, round(L.live_intensity * k, 3)) + \
            L.flicker + (1 if L.preset in LIVE_NORMALS else 0,)
        rank = LIVE_ORDER.index(L.preset) if L.preset in LIVE_ORDER else len(LIVE_ORDER)
        keyed.append(((rank, row), row))
    keyed.sort()
    return [row for _, row in keyed[:LIVE_MOST]]
def light_fields(arena, static=None):
    prep = prepared(arena)
    if static is None:
        static, _ = split_rows(prep)
    terrain = terrain_of(prep)
    lights = light_sources(prep, static, terrain)
    consumed = terrain.consumed if terrain is not None else set()
    rows = [r for k, r in enumerate(light_rows(prep)) if k not in consumed]
    if terrain is not None:
        rows += carved_occluders(terrain, [prep["pieces"][i] for i in static])
    rooms = Rooms([prep["pieces"][i] for i in static], _bake_module().Grid(rows), prep.get("pockets"))
    shifts = [pk.get("shift") for pk in prep.get("pockets") or () if isinstance(pk, dict)]
    return {"pools": bool(lights), "night": evening(prep),
            "scroll": scroll_fields(prep) if SCROLL_ROWS and liquids_in(prep) else [],
            "lava": lava_fields(prep),
            "lights": live_rows(lights, dusk(prep)), "lightfog": LIGHTFOG_CONTRACT,
            "darkBaked": night_tint(prep) is not None,
            "flames": [list(r) for r in flame_rows(lights)],
            "rooms": rooms.kinds if rooms.count > 1 else None,
            "shift": [int(v) for v in shifts[0]] if shifts and shifts[0] else None}
SCROLL_ROWS = False
SCROLL_CONTRACT = 1
_compiled = {}
def liquids_in(arena):
    terr = arena.get("terrain") if isinstance(arena.get("terrain"), dict) else {}
    return bool(arena.get("water")) or any(
        p.get("kind") in ("water", "lava") or p.get("tex") in FLOW_LAVA
        for p in arena.get("pieces") or []) or bool(terr.get("mesh") and arena.get("water"))
def compiled(arena, shade=True):
    sig = (_signature(arena), arena.get("key"), arena.get("script"), shade)
    if sig not in _compiled:
        if len(_compiled) > 2:
            _compiled.clear()
        _compiled[sig] = compile_level(arena, shade=shade)
    return _compiled[sig]
def scroll_fields(arena):
    a = dict(arena)
    a.setdefault("key", "venue")
    a["_generated"] = True
    try:
        return list(getattr(compiled(a), "scroll", None) or [])
    except BakeError:
        return []
LAVA_MOST = 64
def lava_fields(arena):
    out = []
    for p in arena.get("pieces") or []:
        if p.get("tex") in FLOW_LAVA or p.get("kind") == "lava":
            x0, x1, z0, z1 = _foot(p)
            out.append([int(x0), int(z0), int(x1), int(z1), int(p["y"] + p["h"])])
    out.sort(key=lambda r: -(r[2] - r[0]) * (r[3] - r[1]))
    return out[:LAVA_MOST]
def _num(v):
    return ("%d" % v) if float(v) == int(v) else ("%g" % v)
def light_lines(arena, static=None, pad="        "):
    f = light_fields(arena, static)
    out = []
    out.append(pad + "lightfog = %d," % f["lightfog"])
    if f["pools"]:
        out.append(pad + "pools = true,")
    if f["night"]:
        out.append(pad + "night = true,")
    if f.get("darkBaked"):
        out.append(pad + "darkBaked = true,")
    if f.get("flames"):
        out.append(pad + "flames = { " + ", ".join(
            "{ %s }" % ", ".join(_num(v) for v in r) for r in f["flames"]) + " },")
    if SCROLL_ROWS and f.get("scroll"):
        out.append(pad + "-- flowing liquids: array, axis, speed, mode, cycle, "
                   "count, kind")
        out.append(pad + "scroll = { " + ", ".join(
            '{ "%s", %s, "%s" }' % (r[0], ", ".join(_num(v) for v in r[1:6]), r[6])
            for r in f["scroll"]) + " },")
    if SCROLL_ROWS and f.get("lava"):
        out.append(pad + "lava = { " + ", ".join(
            "{ %s }" % ", ".join(_num(v) for v in r) for r in f["lava"]) + " },")
    if f["rooms"]:
        out.append(pad + "rooms = { %s }," % ", ".join('"%s"' % k for k in f["rooms"]))
    if f["shift"]:
        out.append(pad + "pocketShift = { %d, %d, %d }," % tuple(f["shift"]))
    if f["lights"]:
        out.append(pad + "-- live lights: x, y, z, r, g, b, radius, intensity, a1, f1, a2, f2, "
                   "normals")
        out.append(pad + "lights = {")
        for row in f["lights"]:
            out.append(pad + "    { %s }," % ", ".join(_num(v) for v in row))
        out.append(pad + "},")
    return out
SHADOW_STEP_POINT = 120
POOL_AO = 0.7
POOL_MOST = 3
LIGHT_SPLIT_MIN = 200
LIGHT_SPLIT_SKIP = ("window",)
POOL_KEEP = 8.0
POOL_HALF = 400
LIGHT_SPLIT_DAY = 2.0
class Lights(object):
    CELL = 1024
    def __init__(self, lights):
        self.lights = list(lights)
        self.reach = max([L.radius for L in self.lights] or [0])
        self.cells = {}
        for k, L in enumerate(self.lights):
            r = L.radius
            for i in range(int(math.floor((L.x - r) / self.CELL)), int(math.floor((L.x + r) / self.CELL)) + 1):
                for j in range(int(math.floor((L.z - r) / self.CELL)),
                               int(math.floor((L.z + r) / self.CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
    def near(self, x, z):
        return [self.lights[k] for k in self.cells.get((int(math.floor(x / self.CELL)),
                                                         int(math.floor(z / self.CELL))), ())]
    def split_step(self, poly, day=False):
        xs, ys, zs = [p[0] for p in poly], [p[1] for p in poly], [p[2] for p in poly]
        best = None
        for L in self.near(sum(xs) / len(xs), sum(zs) / len(zs)):
            if L.preset in LIGHT_SPLIT_SKIP:
                continue
            dx = max(min(xs) - L.x, 0, L.x - max(xs))
            dy = max(min(ys) - L.y, 0, L.y - max(ys))
            dz = max(min(zs) - L.z, 0, L.z - max(zs))
            if dx * dx + dy * dy + dz * dz < L.radius * L.radius:
                step = max(LIGHT_SPLIT_MIN, L.radius / (LIGHT_SPLIT_DAY if day else 3.0))
                best = step if best is None else min(best, step)
        return best
    def add(self, grid, x, y, z, n, ao):
        got = []
        for L in self.near(x, z):
            dx, dy, dz = L.x - x, L.y - y, L.z - z
            d2 = dx * dx + dy * dy + dz * dz
            r2 = float(L.radius * L.radius)
            if d2 >= r2:
                continue
            d = math.sqrt(d2)
            lam = 1.0 if d < 1e-6 else (dx * n[0] + dy * n[1] + dz * n[2]) / d
            if lam <= 0.0:
                continue
            f = (1.0 - d2 / r2) ** 2
            w = L.peak * f * min(1.0, lam) * (POOL_AO + (1.0 - POOL_AO) * ao)
            if w <= 0.004:
                continue
            got.append((w, L, d))
        got.sort(key=lambda g: (-g[0], g[1]))
        rgb = [0.0, 0.0, 0.0]
        best = 0.0
        taken = 0
        for w, L, d in got:
            if taken >= POOL_MOST:
                break
            if self.shadowed(grid, x, y, z, n, L, d):
                continue
            taken += 1
            best = max(best, w)
            for c in range(3):
                rgb[c] += w * L.colour[c]
        return rgb, best
    @staticmethod
    def shadowed(grid, x, y, z, n, L, d):
        bx, by, bz = x + n[0] * 40, y + n[1] * 40, z + n[2] * 40
        dx, dy, dz = L.x - bx, L.y - by, L.z - bz
        ln = math.sqrt(dx * dx + dy * dy + dz * dz)
        if ln < 1e-6:
            return False
        stop = ln - 110.0
        t = SHADOW_STEP_POINT
        while t < stop:
            if grid.solid(bx + dx / ln * t, by + dy / ln * t, bz + dz / ln * t):
                return True
            t += SHADOW_STEP_POINT
        return False
def pooled_parts(ao, lit, paint, w):
    if w <= 0:
        return ao, lit, paint
    w = min(1.0, 2.0 * w)
    bake = _bake_module()
    ao = ao + (1.0 - ao) * 0.85 * w
    top = bake.PAINT_STEPS - 1
    paint = max(paint, int(math.floor(bake.PAINT_MID + (top - bake.PAINT_MID) * w + 0.5)))
    return ao, lit, paint
CAVE_TALL = 1000
CAVE_FLOOR = 0.78
CAVE_PATH = 1.02
PATH_HALF = 170
CAVE_CEILING = 0.72
CAVE_STREAK = (0.84, 1.06)
MINERAL_K = 0.16
def cave_boxes(pieces):
    slabs = [p for p in pieces if p.get("tag") == "cave.floor"]
    ceilings = [p for p in pieces if p.get("tag") == "cave.ceiling"]
    boxes = []
    for p in slabs:
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
        top = p["y"] + p["h"]
        along = "x" if p["w"] > p["d"] else ("z" if p["d"] > p["w"] else None)
        over = [c["y"] for c in ceilings
                if c["x"] - c["w"] / 2.0 < x1 and x0 < c["x"] + c["w"] / 2.0
                and c["z"] - c["d"] / 2.0 < z1 and z0 < c["z"] + c["d"] / 2.0 and c["y"] > top]
        y1 = (max(over) + 5) if over else top + CAVE_TALL
        boxes.append([x0, x1, top - 40, y1, z0, z1, None, None, along])
    n = 0
    for b in boxes:
        if b[6] is not None:
            continue
        b[6] = n
        stack = [b]
        while stack:
            c = stack.pop()
            for o in boxes:
                if o[6] is None and abs(o[2] - c[2]) < 1 and o[0] <= c[1] and c[0] <= o[1] \
                        and o[4] <= c[5] and c[4] <= o[5]:
                    o[6] = n
                    stack.append(o)
        n += 1
    crystals = [p for p in pieces if p.get("tag") == "cave.crystal" and p.get("tex") in GLOW_LIGHT]
    for b in boxes:
        for p in crystals:
            if b[0] - 400 <= p["x"] <= b[1] + 400 and b[4] - 400 <= p["z"] <= b[5] + 400 \
                    and b[2] - 50 <= p["y"] <= b[3]:
                col = GLOW_LIGHT[p["tex"]][1] or LIGHT_PRESETS["crystal"]["colour"]
                for o in boxes:
                    if o[6] == b[6]:
                        o[7] = col
                break
    return [tuple(b) for b in boxes]
class Caves(object):
    CELL = 1024
    def __init__(self, pieces):
        self.boxes = cave_boxes(pieces)
        self.cells = {}
        for k, b in enumerate(self.boxes):
            for i in range(int(math.floor(b[0] / self.CELL)), int(math.floor(b[1] / self.CELL)) + 1):
                for j in range(int(math.floor(b[4] / self.CELL)), int(math.floor(b[5] / self.CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
    def at(self, x, y, z, pad=30):
        for k in self.cells.get((int(math.floor(x / self.CELL)), int(math.floor(z / self.CELL))), ()):
            b = self.boxes[k]
            if b[0] - pad <= x <= b[1] + pad and b[2] - pad <= y < b[3] \
                    and b[4] - pad <= z <= b[5] + pad:
                return b
        return None
    def paint(self, rgb, x, y, z, n):
        b = self.at(x, y, z)
        if b is None:
            return rgb
        bake = _bake_module()
        if n[1] > 0.5:
            k = CAVE_FLOOR
            if b[8] is not None:
                mid = (b[4] + b[5]) / 2.0 if b[8] == "x" else (b[0] + b[1]) / 2.0
                off = abs((z if b[8] == "x" else x) - mid)
                k = CAVE_FLOOR + (CAVE_PATH - CAVE_FLOOR) * (1.0 - _smooth(0.0, PATH_HALF * 2, off))
        elif n[1] < -0.5:
            k = CAVE_CEILING
        else:
            t = 0.5 + 0.5 * bake.value_noise(x + z * 0.7, y * 2.2, 480.0, seed=11)
            k = CAVE_STREAK[0] + (CAVE_STREAK[1] - CAVE_STREAK[0]) * t
        hue = b[7]
        out = []
        for c in range(3):
            m = 1.0 if hue is None else (1.0 - MINERAL_K) + MINERAL_K * hue[c] / 255.0 * 1.1
            out.append(max(0, min(255, int(round(rgb[c] * k * m)))))
        return tuple(out)
def cave_walls(caves, rocks):
    out = []
    if not caves.boxes:
        return out
    for rock in rocks:
        if rock.get("kind") != "box" or float(rock.get("yaw", 0) or 0) % 90:
            continue
        faces = None
        for b in caves.boxes:
            x0, x1 = rock["x"] - rock["w"] / 2.0, rock["x"] + rock["w"] / 2.0
            z0, z1 = rock["z"] - rock["d"] / 2.0, rock["z"] + rock["d"] / 2.0
            if float(rock.get("yaw", 0) or 0) % 180:
                x0, x1, z0, z1 = (rock["x"] - rock["d"] / 2.0, rock["x"] + rock["d"] / 2.0,
                                  rock["z"] - rock["w"] / 2.0, rock["z"] + rock["w"] / 2.0)
            if x1 < b[0] - 1 or x0 > b[1] + 1 or z1 < b[4] - 1 or z0 > b[5] + 1 \
                    or rock["y"] > b[3] or rock["y"] + rock["h"] < b[2]:
                continue
            if faces is None:
                faces = part_faces(rock)
            for f in faces:
                n = f.normal
                if abs(n[1]) > 0.1:
                    continue
                axis = 0 if abs(n[0]) > 0.9 else (2 if abs(n[2]) > 0.9 else None)
                if axis is None:
                    continue
                plane = f.corners[0][axis]
                side = b[0] if (axis == 0 and n[0] > 0) else b[1] if axis == 0 else \
                    (b[4] if n[2] > 0 else b[5])
                if abs(plane - side) > 2 or any(abs(c[axis] - plane) > 2 for c in f.corners):
                    continue
                other = 2 - axis
                lo, hi = (b[4], b[5]) if axis == 0 else (b[0], b[1])
                poly = list(f.corners)
                for cut_axis, a, z in ((other, lo, hi), (1, b[2], b[3])):
                    poly = _clip(poly, cut_axis, a)[1] if poly else poly
                    poly = _clip(poly, cut_axis, z)[0] if poly else poly
                if poly and _area_ok(poly):
                    out.append(Face(poly, n, f.tex, False, f.extent))
    return out
def carved_occluders(terrain, pieces):
    rows = list(terrain.occluders)
    boxes = cave_boxes(pieces)
    if not boxes:
        return rows
    out = []
    for r in rows:
        x, y, z, w, h, d = (float(v) for v in r[2:8])
        y1 = y + h
        cut = None
        for b in boxes:
            if b[0] <= x <= b[1] and b[4] <= z <= b[5] and y < b[3] and b[2] < y1:
                cut = b
                break
        if cut is None:
            out.append(r)
            continue
        if cut[2] > y:
            out.append(tuple(r[:3]) + (y, z, w, cut[2] - y, d) + tuple(r[8:]))
        if y1 > cut[3]:
            out.append(tuple(r[:3]) + (cut[3], z, w, y1 - cut[3], d) + tuple(r[8:]))
    return out
def _smooth(a, b, v):
    t = (v - a) / (b - a) if b != a else 1.0
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return t * t * (3.0 - 2.0 * t)
ROOM_OPEN = 1
GEO_SWITCH_AREA = 16
GEO_SWITCH = 0x0E
VIS_INTO = 4000
PORTAL_REACH = 12000
PORTAL_MARGIN = 600
ROOM_PAD = 600
POCKET_PAD = 260
PORTAL_PROBE = 80
LEVEL_CMD_ROOMS = 0x0000082F
LEVEL_CMD_TERRAIN = 0x0000082E
DATA_TYPE_ROOMS = 17
class Rooms(object):
    def __init__(self, pieces, grid, pockets=()):
        self.caves = Caves(pieces)
        count = 1 + max([b[6] for b in self.caves.boxes] or [-1])
        self.kinds = ["open"] + ["cave"] * count
        self.pockets = [tuple(float(v) for v in pk["box"]) for pk in (pockets or ())
                        if isinstance(pk, dict) and len(pk.get("box") or ()) == 6]
        self.kinds += ["inside"] * len(self.pockets)
        self.first_pocket = 2 + count
        self.portals = dict((c, []) for c in range(count))
        self.bounds = {}
        for b in self.caves.boxes:
            c = b[6]
            lo = self.bounds.get(c)
            self.bounds[c] = (b[0], b[1], b[2], b[3], b[4], b[5]) if lo is None else (
                min(lo[0], b[0]), max(lo[1], b[1]), min(lo[2], b[2]), max(lo[3], b[3]),
                min(lo[4], b[4]), max(lo[5], b[5]))
            ys = sorted(set(min(y, b[3] - PORTAL_PROBE) for y in
                            (b[2] + 300, (b[2] + b[3]) / 2.0, b[3] - PORTAL_PROBE)))
            for axis, at, sign in ((0, b[0], -1), (0, b[1], 1), (2, b[4], -1), (2, b[5], 1)):
                span = (b[4], b[5]) if axis == 0 else (b[0], b[1])
                k = span[0] + 200
                while k < span[1]:
                    for y in ys:
                        p = [0.0, y, 0.0]
                        p[axis] = at + sign * PORTAL_PROBE
                        p[2 - axis] = k
                        if not grid.solid(p[0], p[1], p[2]) and \
                                self.caves.at(p[0], p[1], p[2], 0) is None:
                            n = [0.0, 0.0, 0.0]
                            n[axis] = float(sign)
                            q = list(p)
                            q[axis] = at
                            self.portals[c].append((tuple(q), tuple(n), False))
                            break
                    k += 400
            x = b[0] + 200
            while x < b[1]:
                z = b[4] + 200
                while z < b[5]:
                    if not grid.solid(x, b[3] + 300, z) and not grid.solid(x, b[3] + 60, z):
                        self.portals[c].append(((x, b[3], z), (0.0, 1.0, 0.0), True))
                    z += 400
                x += 400
    @property
    def count(self):
        return len(self.kinds)
    def room_at(self, x, y, z, pad=30):
        q = max(pad, POCKET_PAD)
        for k, (x0, x1, y0, y1, z0, z1) in enumerate(self.pockets):
            if x0 - q <= x <= x1 + q and y0 - q <= y <= y1 + q and z0 - q <= z <= z1 + q:
                return self.first_pocket + k
        b = self.caves.at(x, y, z, pad)
        return ROOM_OPEN if b is None else 2 + b[6]
    def is_pocket(self, room):
        return room >= self.first_pocket
    def sees_into(self, cave, centre, radius):
        for (px, py, pz), _, _ in self.portals.get(cave, ()):
            if math.sqrt((centre[0] - px) ** 2 + (centre[1] - py) ** 2 + (centre[2] - pz) ** 2) \
                    - radius < VIS_INTO:
                return True
        return False
    def sees_out(self, cave, centre, radius):
        b = self.bounds.get(cave)
        if b is not None and b[0] - ROOM_PAD - radius <= centre[0] <= b[1] + ROOM_PAD + radius \
                and b[2] - ROOM_PAD - radius <= centre[1] <= b[3] + ROOM_PAD + radius \
                and b[4] - ROOM_PAD - radius <= centre[2] <= b[5] + ROOM_PAD + radius:
            return True
        for (px, py, pz), n, sky in self.portals.get(cave, ()):
            d = (centre[0] - px, centre[1] - py, centre[2] - pz)
            if math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2) - radius > PORTAL_REACH:
                continue
            if sky or d[0] * n[0] + d[1] * n[1] + d[2] * n[2] > -radius - PORTAL_MARGIN:
                return True
        return False
def chunk_cases(ch, rooms):
    r = getattr(ch, "room", ROOM_OPEN) or ROOM_OPEN
    if r == ROOM_OPEN:
        out = [0]
        for cave in range(rooms.first_pocket - 2):
            if rooms.sees_out(cave, ch.centre, ch.radius):
                out.append(cave + 1)
        return out
    if rooms.is_pocket(r):
        return [r - 1]
    out = [r - 1]
    if rooms.sees_into(r - 2, ch.centre, ch.radius):
        out.append(0)
    return out
def room_cases(sc, rooms):
    cases = [[] for _ in range(rooms.count)]
    for k, ch in enumerate(sc.chunks):
        for c in chunk_cases(ch, rooms):
            cases[c].append(k)
    for c in cases:
        c.sort()
    return cases
def triangle_rooms(sections, rooms):
    out = []
    for verts, groups in sections:
        for _, tris in groups:
            for t in tris:
                a, b, c = (verts[i] for i in t[:3])
                out.append(rooms.room_at((a[0] + b[0] + c[0]) / 3.0, (a[1] + b[1] + c[1]) / 3.0,
                                         (a[2] + b[2] + c[2]) / 3.0))
    return out
def rooms_name(key):
    return "of_%s_bake_rooms" % key
ROOMS_FILE = "area_1/room.inc.c"
def rooms_source(key, values, bare=False):
    lines = ([] if bare else
             ["/* The rooms of every collision triangle, in load order (tools/venuebake.py",
              "   `triangle_rooms`): 1 the open world, 2.. its caves. */"]) + [
             "u8 %s[] = {" % rooms_name(key)]
    for k in range(0, len(values), 32):
        lines.append("\t" + ", ".join(str(v) for v in values[k:k + 32]) + ",")
    lines.append("};")
    return "\n".join(lines) + "\n"
def base_triangles(sections):
    return sum(len(tris) for _, groups in sections for _, tris in groups)
LEVEL_CMD_INSTANT_WARP = 0x28
SURFACE_WARP_IN, SURFACE_WARP_OUT = 0x1B, 0x1C
WARP_LIFT = 2
def pocket_drops(pockets):
    out = []
    for pk in pockets or ():
        b = pk.get("inner") if isinstance(pk, dict) else None
        if b and len(b) == 6:
            b = tuple(float(v) for v in b)
            out.append((b, ((b[0] + b[1]) / 2.0, (b[2] + b[3]) / 2.0, (b[4] + b[5]) / 2.0)))
    return out
def dropped(drops, poly, normal):
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    cz = sum(p[2] for p in poly) / len(poly)
    for (x0, x1, y0, y1, z0, z1), m in drops:
        reach = 420
        if not (x0 - reach <= cx <= x1 + reach and y0 - reach <= cy <= y1 + reach
                and z0 - reach <= cz <= z1 + reach):
            continue
        if x0 - 1 <= cx <= x1 + 1 and y0 - 1 <= cy <= y1 + 1 and z0 - 1 <= cz <= z1 + 1:
            return False
        return (cx - m[0]) * normal[0] + (cy - m[1]) * normal[1] + (cz - m[2]) * normal[2] > 0
    return False
def warp_triangles(pockets):
    m = arenas_tool()
    out = []
    for pk in pockets or ():
        for key, surface in (("door", SURFACE_WARP_IN), ("exit", SURFACE_WARP_OUT)):
            r = pk.get(key)
            if not r or len(r) != 5:
                continue
            x0, z0, x1, z1, y = (int(round(v)) for v in r)
            y += WARP_LIFT
            a, b, c, d = (x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)
            for tri in ((a, d, c), (a, c, b)):
                p, q, r_ = tri
                if (q[2] - p[2]) * (r_[0] - q[0]) - (q[0] - p[0]) * (r_[2] - q[2]) <= 0:
                    tri = (p, r_, q)
                out.append((surface, m.slopes.sort_first(tri)))
    return out
def warp_commands(pockets):
    shifts = sorted(set(tuple(int(v) for v in pk["shift"]) for pk in pockets or ()
                        if isinstance(pk, dict) and len(pk.get("shift") or ()) == 3))
    if not shifts:
        return []
    if len(shifts) > 1:
        raise BakeError("the halls of a level share one shift, not %d" % len(shifts))
    dx, dy, dz = shifts[0]
    words = []
    for index, (a, b, c) in ((0, (dx, dy, dz)), (1, (-dx, -dy, -dz))):
        words += [LEVEL_CMD_INSTANT_WARP | (0x0C << 8) | (index << 16) | (1 << 24),
                  (a & 0xFFFF) | ((b & 0xFFFF) << 16), c & 0xFFFF]
    return words
def warp_lines(pockets):
    w = warp_commands(pockets)
    out = []
    for k in range(0, len(w), 3):
        index = (w[k] >> 16) & 0xFF
        out.append("\t\tINSTANT_WARP(%d, 0x01, %d, %d, %d),\n" % (
            index, _s16(w[k + 1]), _s16(w[k + 1] >> 16), _s16(w[k + 2])))
    return "".join(out)
BILLBOARD_REACH = 6000
HALO_DARK = 85
HALO_COVER = 0.35
HALO_SIZE = {"lantern": 300, "torch": 160, "campfire": 520, "candle": 70, "crystal": 360,
             "mushroom": 260, "magic": 340, "lava": 0, "window": 0, "neon": 0}
FLAME_SIZE = {"campfire": (300, 420), "torch": (90, 160), "candle": (34, 60)}
SMOKE_PUFFS = ((300, 230, 150), (760, 330, 110), (1260, 440, 70))
SMOKE_RGB = (196, 196, 202)
RIM = 10
def _fan(cx, cy, rx, ry, centre_rgba, rim_rgba, pointy=0.0):
    verts = [(int(round(cx)), int(round(cy)), 0) + tuple(centre_rgba)]
    for k in range(RIM):
        a = 2.0 * math.pi * k / RIM
        x, y = math.cos(a) * rx, math.sin(a) * ry
        if pointy and y > 0:
            y = y * (1.0 + pointy * (1.0 - abs(math.cos(a))))
            x = x * (1.0 - 0.45 * (y / (ry * (1 + pointy))))
        verts.append((int(round(cx + x)), int(round(cy + y)), 0) + tuple(rim_rgba))
    tris = [(0, 1 + k, 1 + (k + 1) % RIM) for k in range(RIM)]
    return verts, tris
def _merge(*meshes):
    verts, tris = [], []
    for v, t in meshes:
        base = len(verts)
        verts += v
        tris += [(a + base, b + base, c + base) for a, b, c in t]
    return verts, tris
FLAME_OBJECTS = {"campfire": (False, 7.0), "torch": (False, 7.0), "candle": (False, 3.0),
                 "magic": (True, 7.0)}
FLAME_HALF = 25
FLAME_RISE = 0.6
FLAMES_MOST = 48
def flame_rows(lights):
    out = []
    for L in lights:
        spec = FLAME_OBJECTS.get(L.preset)
        if spec is None:
            continue
        blue, scale = spec
        top = L.y - (CAMPFIRE_LIFT - 60 if L.preset == "campfire"
                     else 40 if L.preset in FLAME_SIZE else 0)
        y = top + FLAME_HALF * scale * FLAME_RISE
        out.append((int(round(L.x)), int(round(y)), int(round(L.z)), 1 if blue else 0, scale))
    out.sort()
    return out[:FLAMES_MOST]
def vanilla_flame_mesh(scale, blue=False):
    w = FLAME_HALF * 2 * scale * 0.55
    h = FLAME_HALF * 2 * scale * 0.8
    if blue:
        outer = _fan(0, -h * 0.18, w / 2.0, h * 0.32, (90, 140, 255, 210), (40, 60, 255, 0),
                     pointy=1.2)
        inner = _fan(0, -h * 0.24, w * 0.28, h * 0.2, (210, 230, 255, 235), (120, 160, 255, 0),
                     pointy=1.1)
        return _merge(outer, inner)
    outer = _fan(0, -h * 0.18, w / 2.0, h * 0.32, (255, 120, 30, 215), (255, 50, 0, 0),
                 pointy=1.2)
    inner = _fan(0, -h * 0.24, w * 0.28, h * 0.2, (255, 236, 170, 235), (255, 190, 60, 0),
                 pointy=1.1)
    return _merge(outer, inner)
def flame_mesh(width, height):
    outer = _fan(0, height * 0.32, width / 2.0, height * 0.32, (255, 150, 40, 210),
                 (255, 70, 10, 0), pointy=1.2)
    inner = _fan(0, height * 0.26, width * 0.28, height * 0.2, (255, 244, 190, 235),
                 (255, 200, 80, 0), pointy=1.1)
    return _merge(outer, inner)
def halo_mesh(size, colour, alpha):
    lifted = tuple(int(round(c + (255 - c) * 0.3)) for c in colour)
    return _fan(0, 0, size / 2.0, size / 2.0, lifted + (alpha,), lifted + (0,))
def puff_mesh(size, alpha):
    return _fan(0, 0, size / 2.0, size / 2.0 * 0.85, SMOKE_RGB + (alpha,), SMOKE_RGB + (0,))
def billboards(arena, static, lights, grid=None, dark=False):
    bake = _bake_module()
    out = []
    meshes = {}
    def mesh(key, make):
        if key not in meshes:
            meshes[key] = make()
        return meshes[key]
    for L in lights:
        if L.preset in FLAME_SIZE and L.preset not in FLAME_OBJECTS:
            w, h = FLAME_SIZE[L.preset]
            foot = L.y - (CAMPFIRE_LIFT - 20 if L.preset == "campfire" else h * 0.3)
            out.append((L.x, foot, L.z, ("flame", w, h), mesh(("flame", w, h),
                                                            lambda: flame_mesh(w, h))))
        size = HALO_SIZE.get(L.preset, 0)
        if not size:
            continue
        cover = False
        if not dark and grid is not None:
            cover = bake.sky_open(grid, L.x, L.y, L.z, 0.0, 1.0, 0.0) < HALO_COVER
        if dark or cover:
            key = ("halo", size, L.colour, HALO_DARK)
            out.append((L.x, L.y, L.z, key, mesh(key, lambda: halo_mesh(size, L.colour, HALO_DARK))))
    pieces = arena["pieces"] if static is None else [arena["pieces"][i] for i in static]
    for p in pieces:
        if p.get("decor") == "smoke":
            for up, size, alpha in SMOKE_PUFFS:
                key = ("puff", size, alpha)
                out.append((p["x"] + (up - 300) * 0.08, p["y"] + up, p["z"], key,
                            mesh(key, lambda: puff_mesh(size, alpha))))
    out = [(int(round(x)), int(round(y)), int(round(z)), k, m) for x, y, z, k, m in out]
    out.sort(key=lambda b: (b[3], b[0], b[1], b[2]))
    return out
def billboard_name(key, mesh_key):
    kind = mesh_key[0]
    tail = "_".join(str(v) if not isinstance(v, tuple) else "x".join(str(c) for c in v)
                    for v in mesh_key[1:])
    return "of_%s_bake_bb_%s_%s" % (key, kind, tail)
def png_size(png):
    if png[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", png[16:24])
def drawn_parts(piece):
    m = arenas_tool()
    if piece.get("tex") == m.INVISIBLE:
        return []
    if piece.get("decor") == "smoke":
        return []
    if piece.get("decor"):
        return _decor().drawn([piece])
    out = [piece]
    if piece.get("join") and piece["kind"] == "pillar":
        out += [_in_frame(arm, piece) for arm in join_arms(piece)]
    return out
def _sub3(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def _unit(v):
    ln = math.sqrt(_dot(v, v))
    return (0.0, 1.0, 0.0) if ln == 0 else (v[0] / ln, v[1] / ln, v[2] / ln)
def _extent(points):
    most = 0.0
    for i in range(len(points)):
        for j in range(i + 1, len(points)):
            d = _sub3(points[i], points[j])
            most = max(most, math.sqrt(_dot(d, d)))
    return most
class Face(object):
    __slots__ = ("corners", "normal", "tex", "water", "extent")
    def __init__(self, corners, normal, tex, water, extent):
        self.corners, self.normal, self.tex, self.water, self.extent = \
            corners, normal, tex, water, extent
def part_faces(part):
    m = arenas_tool()
    kind = part["kind"]
    if kind not in m.SOLIDS:
        return []
    textures, layered = kit_textures()
    slug = part["tex"]
    if slug not in textures:
        raise BakeError("no block texture %r" % slug)
    layers = slug in layered
    faces = kit_solid(kind, piece=part)
    water = kind in m.VISUAL_KINDS
    if water:
        faces = [f for f in faces if f[1][1] != 0]
    c, s = _turn(part.get("yaw", 0))
    out = []
    for pts, normal in faces:
        corners = m.face_corners(part, pts, normal, layers)
        world = [to_world(q, part, c, s) for q, _, _ in corners]
        n = m.real_normal(pts, part)
        n = _unit((n[0] * c + n[2] * s, n[1], -n[0] * s + n[2] * c))
        tex = (slug, m.slopes.layer_of(normal) if layers else 0)
        out.append(Face([(w[0], w[1], w[2], cs, ct) for w, (_, cs, ct) in zip(world, corners)],
                        n, tex, water, _extent(world)))
    return out
def sculpted_faces(part):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import sculpt
    textures, layered = kit_textures()
    out = []
    for corners, normal, tex in sculpt.faces(part, lambda slug: texture_png((slug, 0)),
                                             layered):
        if tex[0] not in textures:
            raise BakeError("no block texture %r" % tex[0])
        out.append(Face(corners, normal, tex, part["kind"] in arenas_tool().VISUAL_KINDS,
                        _extent([c[:3] for c in corners])))
    return out
def sculpted_row(row, piece):
    kind, model, x, y, z, w, h, d = row[:8]
    k = 0.42 if piece.get("kind") == "pillar" else 0.7
    return (kind, model, x, y, z, w * k, h * 0.9, d * k) + tuple(row[8:])
def _convex(corners, normal):
    pts = [c[:3] for c in corners]
    for i in range(len(pts)):
        a, b, c = pts[i], pts[(i + 1) % len(pts)], pts[(i + 2) % len(pts)]
        if _dot(_cross(_sub3(b, a), _sub3(c, b)), normal) < -1e-6:
            return False
    return True
def _clip(poly, axis, at):
    below, above = [], []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        da, db = a[axis] - at, b[axis] - at
        if da <= 0:
            below.append(a)
        if da >= 0:
            above.append(a)
        if (da < 0 < db) or (db < 0 < da):
            t = da / (da - db)
            p = tuple(a[k] + (b[k] - a[k]) * t for k in range(len(a)))
            below.append(p)
            above.append(p)
    return below, above
def _area_ok(poly):
    if len(poly) < 3:
        return False
    a = poly[0]
    total = (0.0, 0.0, 0.0)
    for i in range(1, len(poly) - 1):
        cr = _cross(_sub3(poly[i][:3], a[:3]), _sub3(poly[i + 1][:3], a[:3]))
        total = (total[0] + cr[0], total[1] + cr[1], total[2] + cr[2])
    return _dot(total, total) > 1e-6
LIGHT_STEPS = (3200, 1600)
LIGHT_KEEP = 1
def _plane_axes(normal):
    k = max(range(3), key=lambda a: abs(normal[a]))
    return [a for a in range(3) if a != k]
def _in_poly(pt, poly, ax):
    a, b = ax
    sign = 0
    for k in range(len(poly)):
        p, q = poly[k], poly[(k + 1) % len(poly)]
        c = (q[a] - p[a]) * (pt[b] - p[b]) - (q[b] - p[b]) * (pt[a] - p[a])
        if abs(c) < 1e-6:
            continue
        s_ = 1 if c > 0 else -1
        if sign and s_ != sign:
            return False
        sign = s_
    return True
def _fan_weights(pt, poly, ax):
    a, b = ax
    for k in range(1, len(poly) - 1):
        p0, p1, p2 = poly[0], poly[k], poly[k + 1]
        d = (p1[a] - p0[a]) * (p2[b] - p0[b]) - (p2[a] - p0[a]) * (p1[b] - p0[b])
        if abs(d) < 1e-9:
            continue
        u = ((pt[a] - p0[a]) * (p2[b] - p0[b]) - (p2[a] - p0[a]) * (pt[b] - p0[b])) / d
        v = ((p1[a] - p0[a]) * (pt[b] - p0[b]) - (pt[a] - p0[a]) * (p1[b] - p0[b])) / d
        if u >= -1e-6 and v >= -1e-6 and u + v <= 1 + 1e-6:
            return [(0, 1 - u - v), (k, u), (k + 1, v)]
    return None
def coarse_split(face, polys, light):
    bake = _bake_module()
    lo = 1.0 - bake.AO_K
    ao_step = (1.0 - lo) / PART_STEPS
    lit_step = (1.0 - bake.SHADOW_LIGHT) / PART_STEPS
    ax = _plane_axes(face.normal)
    points = {}
    for poly in polys:
        for c in poly:
            points[(round(c[0], 3), round(c[1], 3), round(c[2], 3))] = c
    for step in LIGHT_STEPS:
        coarse = split_face(face, step)
        if len(coarse) >= len(polys):
            continue
        ok = True
        for key, c in points.items():
            if not ok:
                break
            for poly in coarse:
                if not _in_poly(c, poly, ax):
                    continue
                w = _fan_weights(c, poly, ax)
                if w is None:
                    ok = False
                    break
                parts = [light(*poly[k][:3]) for k, _ in w]
                ao = sum(p[0] * f for p, (_, f) in zip(parts, w))
                lit = sum(p[1] * f for p, (_, f) in zip(parts, w))
                paint = sum(p[2] * f for p, (_, f) in zip(parts, w))
                own = light(*c[:3])
                if abs(ao - own[0]) > LIGHT_KEEP * ao_step or \
                        abs(lit - own[1]) > LIGHT_KEEP * lit_step or \
                        abs(paint - own[2]) > LIGHT_KEEP:
                    ok = False
                break
        if ok:
            return coarse
    return polys
PRESSED_MOST = 120
def pressed_faces(parts_faces):
    out = set()
    if len(parts_faces) < 2 or sum(len(fs) for fs in parts_faces) > PRESSED_MOST:
        return out
    flat = [(k, f) for k, fs in enumerate(parts_faces) for f in fs
            if not f.water and len(f.corners) >= 3]
    for k, f in flat:
        n = f.normal
        p0 = f.corners[0]
        ax = _plane_axes(n)
        for k2, g in flat:
            if k2 == k or n[0] * g.normal[0] + n[1] * g.normal[1] + n[2] * g.normal[2] > -0.999:
                continue
            q0 = g.corners[0]
            if abs(n[0] * (q0[0] - p0[0]) + n[1] * (q0[1] - p0[1]) + n[2] * (q0[2] - p0[2])) > 0.5:
                continue
            if all(_in_poly(c, g.corners, ax) for c in f.corners):
                out.add(id(f))
                break
    return out
def split_face(face, step=SPLIT, axes=(0, 1, 2)):
    if _convex(face.corners, face.normal):
        polys = [list(face.corners)]
    else:
        polys = [[face.corners[0], face.corners[i], face.corners[i + 1]]
                 for i in range(1, len(face.corners) - 1)]
    for axis in axes:
        out = []
        for poly in polys:
            lo = min(p[axis] for p in poly)
            hi = max(p[axis] for p in poly)
            k = int(math.floor(lo / step)) + 1
            rest = poly
            while k * step < hi - 1e-6:
                below, rest = _clip(rest, axis, k * step)
                if _area_ok(below):
                    out.append(below)
                k += 1
            if _area_ok(rest):
                out.append(rest)
        polys = out
    return polys
class Cull(object):
    CELL = 1024
    def __init__(self, pieces):
        m = arenas_tool()
        self.boxes, self.cells = [], {}
        for p in pieces:
            if p.get("kind") not in ("box", "ice", "lava") or p.get("decor") \
                    or p.get("tex") == m.INVISIBLE or float(p.get("yaw", 0) or 0) % 90 \
                    or p.get("sculpt"):
                continue
            x0, x1, z0, z1, _ = m.footprint(dict(p, yaw=int(round(float(p.get("yaw", 0) or 0))) % 360))
            b = (x0, x1, p["y"], p["y"] + p["h"], z0, z1)
            k = len(self.boxes)
            self.boxes.append(b)
            for i in range(int(math.floor(b[0] / self.CELL)), int(math.floor(b[1] / self.CELL)) + 1):
                for j in range(int(math.floor(b[4] / self.CELL)), int(math.floor(b[5] / self.CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
    def inside(self, x, y, z):
        for k in self.cells.get((int(math.floor(x / self.CELL)), int(math.floor(z / self.CELL))), ()):
            b = self.boxes[k]
            if b[0] < x < b[1] and b[2] < y < b[3] and b[4] < z < b[5]:
                return True
        return False
    def hidden(self, poly, normal):
        cx = sum(p[0] for p in poly) / len(poly)
        cy = sum(p[1] for p in poly) / len(poly)
        cz = sum(p[2] for p in poly) / len(poly)
        tests = [(cx, cy, cz)] + [(p[0] + (cx - p[0]) * 0.02, p[1] + (cy - p[1]) * 0.02,
                                   p[2] + (cz - p[2]) * 0.02) for p in poly]
        for x, y, z in tests:
            if not self.inside(x + normal[0] * 2, y + normal[1] * 2, z + normal[2] * 2):
                return False
        return True
OCT_MID = 31
OCT_BITS = 6
OCT_MASK = 63
PAINT_SHIFT = 12
PART_STEPS = 15
def _bake_module():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import bake
    return bake
def pack_parts(n, ao, lit, paint=None):
    bake = _bake_module()
    if paint is None:
        paint = bake.PAINT_MID
    nx, ny, nz = n
    d = abs(nx) + abs(ny) + abs(nz)
    u, v = nx / d, nz / d
    if ny < 0:
        u, v = (1 - abs(v)) * (1 if u >= 0 else -1), (1 - abs(u)) * (1 if v >= 0 else -1)
    qu = int(math.floor(u * OCT_MID + OCT_MID + 0.5))
    qv = int(math.floor(v * OCT_MID + OCT_MID + 0.5))
    lo = 1.0 - bake.AO_K
    qa = int(math.floor((ao - lo) / (1.0 - lo) * PART_STEPS + 0.5))
    ql = int(math.floor((lit - bake.SHADOW_LIGHT) / (1.0 - bake.SHADOW_LIGHT) * PART_STEPS + 0.5))
    qu, qv = max(0, min(2 * OCT_MID, qu)), max(0, min(2 * OCT_MID, qv))
    qa, ql = max(0, min(PART_STEPS, qa)), max(0, min(PART_STEPS, ql))
    qp = max(0, min(bake.PAINT_STEPS - 1, int(paint)))
    return qu | (qv << OCT_BITS) | (qp << PAINT_SHIFT), qa | (ql << 4)
def paint_of(flag):
    return (flag >> PAINT_SHIFT) & 15
def unpack_parts(flag, alpha):
    bake = _bake_module()
    u = ((flag & OCT_MASK) - OCT_MID) / float(OCT_MID)
    v = (((flag >> OCT_BITS) & OCT_MASK) - OCT_MID) / float(OCT_MID)
    y = 1.0 - abs(u) - abs(v)
    if y < 0:
        u, v = (1.0 - abs(v)) * (1.0 if u >= 0 else -1.0), (1.0 - abs(u)) * (1.0 if v >= 0 else -1.0)
    ln = math.sqrt(u * u + y * y + v * v)
    lo = 1.0 - bake.AO_K
    ao = lo + (alpha & 15) / float(PART_STEPS) * (1.0 - lo)
    lit = bake.SHADOW_LIGHT + ((alpha >> 4) & 15) / float(PART_STEPS) * (1.0 - bake.SHADOW_LIGHT)
    return (u / ln, y / ln, v / ln), ao, lit
def venue_palette(look):
    bake = _bake_module()
    pal = bake.palette("default")
    b = bake.current((look or {}).get("bake"))
    if isinstance(b, dict) and all(isinstance(b.get(k), (list, tuple)) and len(b[k]) == 3
                                   for k in bake.PALETTE_KEYS):
        for k in bake.PALETTE_KEYS + bake.PAINT_KEYS:
            if isinstance(b.get(k), (list, tuple)) and len(b[k]) == 3:
                pal[k] = [float(round(float(c), 3)) for c in b[k]]
    return pal
TILES_LEVEL = "empty"
TILES_REACH = 15000
def light_rows(arena):
    m = arenas_tool()
    out = []
    for p in arena["pieces"]:
        out.append((kind_of_row(p), m.row_model(p), p["x"], p["y"], p["z"], p["w"], p["h"],
                    p["d"], p.get("yaw", 0) or 0))
    if arena.get("level") == TILES_LEVEL:
        out.append(("box", "tiles_floor", 0, -200, 0, 2 * TILES_REACH, 200, 2 * TILES_REACH, 0))
    return out
class Scene(object):
    def __init__(self):
        self.textures = []
        self.chunks = []
        self.merged = {}
        self.faces = 0
        self.culled = 0
        self.ground = False
        self.lights = []
        self.night = False
        self.fog = None
        self.dark = None
        self.billboards = []
        self.flames = []
        self.rooms = None
        self.cases = None
FLOW_LAVA = ("lava", "magmacrust")
FLOW_SPEED = {"fall": 520.0, "river": 140.0, "still": 3.0, "lava": 4.0}
FLOW_SINE = {"still": 6, "lava": 4}
SCROLL_UV_X, SCROLL_UV_Y = 4, 5
SCROLL_MODE_UV, SCROLL_MODE_SINE = 0, 1
class Flows(object):
    def __init__(self, arena):
        self.rivers = []
        pieces = arena.get("pieces") or []
        river_pieces = [p for p in pieces
                        if "river" in str(p.get("tag", "")) and (p.get("kind") == "water"
                                                                 or "water" in str(p.get("tag", "")))]
        lakes = [p for p in pieces if p not in river_pieces and (
            p.get("kind") == "water" or "lake" in str(p.get("tag", "")) or "pool" in str(p.get("tag", "")))]
        for course in self.courses(river_pieces, lakes):
            for k, p in enumerate(course):
                x0, x1, z0, z1 = _foot(p)
                nxt = course[k + 1] if k + 1 < len(course) else None
                prv = course[k - 1] if k > 0 else None
                if nxt is not None:
                    d = (nxt["x"] - p["x"], nxt["z"] - p["z"])
                elif prv is not None:
                    d = (p["x"] - prv["x"], p["z"] - prv["z"])
                else:
                    d = (1, 0) if (x1 - x0) >= (z1 - z0) else (0, 1)
                if abs(d[0]) >= abs(d[1]):
                    f = (1.0 if d[0] >= 0 else -1.0, 0.0)
                else:
                    f = (0.0, 1.0 if d[1] >= 0 else -1.0)
                self.rivers.append((x0 - 20, x1 + 20, z0 - 20, z1 + 20, p["y"] + p["h"], f))
        self.rates = {}
    @staticmethod
    def courses(river_pieces, lakes):
        left = list(river_pieces)
        out = []
        def near(a, b):
            ax0, ax1, az0, az1 = _foot(a)
            bx0, bx1, bz0, bz1 = _foot(b)
            return ax0 <= bx1 + 50 and bx0 <= ax1 + 50 and az0 <= bz1 + 50 and bz0 <= az1 + 50
        while left:
            group, todo = [], [left.pop(0)]
            while todo:
                q = todo.pop()
                group.append(q)
                for o in [o for o in left if near(o, q)]:
                    left.remove(o)
                    todo.append(o)
            ends = [g for g in group if sum(1 for o in group if o is not g and near(o, g)) <= 1] or group
            start = ends[0]
            chain, rest = [start], [g for g in group if g is not start]
            while rest:
                last = chain[-1]
                nxt = min(rest, key=lambda o: (o["x"] - last["x"]) ** 2 + (o["z"] - last["z"]) ** 2)
                rest.remove(nxt)
                chain.append(nxt)
            def lake_near(p):
                px0, px1, pz0, pz1 = _foot(p)
                out = 1e9
                for l in lakes:
                    lx0, lx1, lz0, lz1 = _foot(l)
                    dx = max(0.0, lx0 - px1, px0 - lx1)
                    dz = max(0.0, lz0 - pz1, pz0 - lz1)
                    out = min(out, math.hypot(dx, dz))
                return out
            a, b = chain[0], chain[-1]
            la, lb = lake_near(a), lake_near(b)
            if min(la, lb) < 1500 and la != lb:
                down_first = la < lb
            else:
                down_first = max(abs(a["x"]), abs(a["z"])) > max(abs(b["x"]), abs(b["z"]))
            out.append(chain[::-1] if down_first else chain)
        return out
    @staticmethod
    def gradients(poly):
        if len(poly) < 3:
            return None
        p0, p1, p2 = poly[0], poly[1], poly[2]
        e1 = [p1[i] - p0[i] for i in range(3)]
        e2 = [p2[i] - p0[i] for i in range(3)]
        a, b, c = (sum(e1[i] * e1[i] for i in range(3)), sum(e1[i] * e2[i] for i in range(3)),
                   sum(e2[i] * e2[i] for i in range(3)))
        det = a * c - b * b
        if abs(det) < 1e-6:
            return None
        out = []
        for k in (3, 4):
            d1, d2 = p1[k] - p0[k], p2[k] - p0[k]
            al = (d1 * c - d2 * b) / det
            be = (d2 * a - d1 * b) / det
            out.append([al * e1[i] + be * e2[i] for i in range(3)])
        return out
    def of(self, poly, normal, water, tex):
        g = self.gradients(poly)
        if g is None:
            return None, 0.0
        cx = sum(p[0] for p in poly) / float(len(poly))
        cz = sum(p[2] for p in poly) / float(len(poly))
        cy = sum(p[1] for p in poly) / float(len(poly))
        if not water:
            kind, f = "lava", (1.0, 0.0, 0.0)
        elif abs(normal[1]) < 0.5:
            kind, f = "fall", (0.0, -1.0, 0.0)
        else:
            kind, f = "still", (1.0, 0.0, 0.0)
            for x0, x1, z0, z1, top, d in self.rivers:
                if x0 <= cx <= x1 and z0 <= cz <= z1 and abs(top - cy) <= 60:
                    kind, f = "river", (d[0], 0.0, d[1])
                    break
        rs = sum(g[0][i] * f[i] for i in range(3))
        rt = sum(g[1][i] * f[i] for i in range(3))
        axis, rate = ("s", rs) if abs(rs) >= abs(rt) else ("t", rt)
        if abs(rate) < 1e-6:
            return None, 0.0
        if kind in FLOW_SINE:
            return "%s:%s" % (kind, axis), abs(rate)
        return "%s:%s%s" % (kind, axis, "-" if rate > 0 else "+"), abs(rate)
def scroll_row(vname, ch, flows):
    fk = ch.water if isinstance(ch.water, str) else (
        ch.glow if isinstance(getattr(ch, "glow", None), str) else None)
    if not fk or flows is None or not ch.vertices:
        return None
    kind, _, rest = fk.partition(":")
    axis = SCROLL_UV_X if rest.startswith("s") else SCROLL_UV_Y
    rates = sorted(flows.rates.get(fk) or [1.0])
    rate = rates[len(rates) // 2]
    if kind in FLOW_SINE:
        speed = max(1, int(round(FLOW_SPEED[kind] * rate)))
        return [vname, axis, speed, SCROLL_MODE_SINE, FLOW_SINE[kind], len(ch.vertices), kind]
    speed = max(1, int(round(FLOW_SPEED[kind] / 30.0 * rate)))
    if rest.endswith("-"):
        speed = -speed
    return [vname, axis, speed, SCROLL_MODE_UV, 0, len(ch.vertices), kind]
class Chunk(object):
    __slots__ = ("cell", "water", "glow", "room", "centre", "radius", "vertices", "loads",
                 "near_from", "far")
    def __init__(self, cell, water):
        self.cell, self.water = cell, water
        self.glow = False
        self.room = 1
        self.centre, self.radius = (0, 0, 0), 0
        self.vertices = []
        self.loads = []
        self.near_from = None
        self.far = None
    def parts(self):
        if self.far is None:
            return self.loads, [], []
        return self.loads[:self.near_from], self.loads[self.near_from:], self.far.loads
def sheet_rows(arena, rows, terrain=None):
    if terrain is None:
        if not isinstance(arena.get("terrain"), dict) or not arena["terrain"].get("mesh"):
            return []
        terrain = terrain_of(prepared(arena))
    if terrain is None:
        return []
    have = [list(r) for r in rows or []]
    def covered(x0, z0, x1, z1, y):
        return any(r[0] <= x0 and x1 <= r[2] and r[1] <= z0 and z1 <= r[3]
                   and abs(r[4] - y) <= 30 for r in have)
    runs = []
    for corners, n, _tex, _ext in getattr(terrain, "water_faces", None) or []:
        if n[1] < 0.5:
            continue
        xs = [c[0] for c in corners]
        zs = [c[2] for c in corners]
        y = int(round(corners[0][1]))
        box = (int(round(min(xs))), int(round(min(zs))), int(round(max(xs))), int(round(max(zs))), y)
        if not covered(*box):
            runs.append(list(box))
    runs.sort(key=lambda r: (r[4], r[0], r[2], r[1]))
    out = []
    for r in runs:
        last = out[-1] if out else None
        if last is not None and last[0] == r[0] and last[2] == r[2] and last[4] == r[4] \
                and last[3] == r[1]:
            last[3] = r[3]
        else:
            out.append(list(r))
    return [r + [r[4] - 400] for r in out]
def terrain_of(arena):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import heightfield
    if not heightfield.wants(arena):
        return None
    textures, layered = kit_textures()
    return heightfield.build(arena, layered=layered, known=textures)
RIM_TOL = 12
RIM_OUT = 10
RIM_STEP = 100
RIM_OVER = 400
def _liquid_piece(p):
    if p.get("kind") == "lava" or (p.get("kind") == "box" and p.get("tex") == "lava"):
        return True
    return p.get("kind") == "water" and min(p["w"], p["d"]) >= 200 and \
        p["h"] < min(p["w"], p["d"])
def _foot(p):
    w, d = p["w"], p["d"]
    if int(round(float(p.get("yaw", 0) or 0))) % 180 == 90:
        w, d = d, w
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def liquid_rims(arena, triangles, terrain=None, floor=None):
    from mapgen import heightfield
    G_ = 200.0
    book = {}
    for _s, t in triangles:
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = t
        ny = (bz - az) * (cx - ax) - (bx - ax) * (cz - az)
        if ny <= 0:
            continue
        xs, zs = (ax, bx, cx), (az, bz, cz)
        for i in range(int(min(xs) // G_), int(max(xs) // G_) + 1):
            for j in range(int(min(zs) // G_), int(max(zs) // G_) + 1):
                book.setdefault((i, j), []).append(t)
    def heights(x, z):
        out = []
        for t in book.get((int(x // G_), int(z // G_)), ()):
            (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = t
            d = (z1 - z2) * (x0 - x2) + (x2 - x1) * (z0 - z2)
            if d == 0:
                continue
            l0 = ((z1 - z2) * (x - x2) + (x2 - x1) * (z - z2)) / float(d)
            l1 = ((z2 - z0) * (x - x2) + (x0 - x2) * (z - z2)) / float(d)
            if l0 >= -1e-6 and l1 >= -1e-6 and 1 - l0 - l1 >= -1e-6:
                out.append(l0 * y0 + l1 * y1 + (1 - l0 - l1) * y2)
        return out
    surfaces = []
    feet = []
    for corners, n, _tex, _ext in (getattr(terrain, "water_faces", None) or []):
        if n[1] > 0.5:
            surfaces.append(([(c[0], c[2]) for c in corners], corners[0][1]))
    for p in arena.get("pieces") or []:
        if p.get("kind") in ("water", "lava") or p.get("tex") == "lava":
            feet.append(_foot(p) + (None,))
        if not _liquid_piece(p) or (terrain is not None and heightfield.is_sheet(p)):
            continue
        x0, x1, z0, z1 = _foot(p)
        surfaces.append(([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], p["y"] + p["h"]))
    for cs, y in surfaces:
        xs, zs = [c[0] for c in cs], [c[1] for c in cs]
        feet.append((min(xs) - 1, max(xs) + 1, min(zs) - 1, max(zs) + 1, y))
    solid = [_foot(p) + (p["y"], p["y"] + p["h"]) for p in arena.get("pieces") or []
             if p.get("kind") == "box" and p.get("tex") not in (None, "invisible", "lava")
             and not p.get("decor") and float(p.get("yaw", 0) or 0) % 90 == 0]
    def walled(x, z, y):
        return any(a <= x <= b and c <= z <= d and y0 <= y and y1 >= y - RIM_TOL
                   for a, b, c, d, y0, y1 in solid)
    out = []
    for cs, y in surfaces:
        k = len(cs)
        mx, mz = sum(c[0] for c in cs) / float(k), sum(c[1] for c in cs) / float(k)
        for i in range(k):
            (px, pz), (qx, qz) = cs[i], cs[(i + 1) % k]
            dx, dz = qx - px, qz - pz
            ln = (dx * dx + dz * dz) ** 0.5
            if ln < 1:
                continue
            nx, nz = dz / ln, -dx / ln
            if nx * ((px + qx) / 2.0 - mx) + nz * ((pz + qz) / 2.0 - mz) < 0:
                nx, nz = -nx, -nz
            n = max(1, int(ln // RIM_STEP))
            for s in range(n):
                t = (s + 0.5) / n
                ex, ez = px + t * dx, pz + t * dz
                if any(h > y + RIM_TOL for h in heights(ex - nx * RIM_OUT, ez - nz * RIM_OUT)):
                    continue
                x, z = ex + nx * RIM_OUT, ez + nz * RIM_OUT
                if any(a <= x <= b and c <= z <= d and (w is None or abs(w - y) <= RIM_TOL)
                       for a, b, c, d, w in feet):
                    continue
                every = heights(x, z)
                if every and min(every) >= y - RIM_TOL or walled(x, z, y):
                    continue
                hs = [h for h in every if h <= y + RIM_OVER]
                if floor is not None:
                    hs.append(floor)
                if not hs or max(hs) < y - RIM_TOL:
                    low = max(hs) if hs else -9999
                    out.append((int(round(y - low)), int(x), int(round(y)), int(z)))
    return sorted(out, reverse=True)
GROUND_Y = -2
GROUND_MID = 800
GROUND_FINE = 400
GROUND_EDGE = 400
GROUND_FAR = 1600
GROUND_MARGIN = 1600
TILES_GROUND_DL = "%s_dl_Ground_mesh_layer_1_with_revert"
TILES_PERIOD = 500
TILES_DEFAULT = "tile2"
def ground_slug(arena):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import v1
    grounds = v1.venue_levels_module().TILES_GROUNDS
    return grounds.get(arena.get("ground") or "", TILES_DEFAULT)
def ground_faces(arena, pieces):
    if arena.get("level") != TILES_LEVEL:
        return []
    slug = ground_slug(arena)
    if slug not in kit_textures()[0]:
        return []
    hi = coarse(slug, 0)
    tex = (slug, 0, "hi") if hi else (slug, 0)
    m = arenas_tool()
    xs, zs = [], []
    for p in pieces:
        if p.get("tex") == m.INVISIBLE:
            continue
        r = math.hypot(p["w"], p["d"]) / 2.0
        xs += [p["x"] - r, p["x"] + r]
        zs += [p["z"] - r, p["z"] + r]
    R = TILES_REACH
    if xs:
        def snap_lo(v):
            return max(-R, int(math.floor((v - GROUND_MARGIN) / GROUND_FAR)) * GROUND_FAR)
        def snap_hi(v):
            return min(R, int(math.ceil((v + GROUND_MARGIN) / GROUND_FAR)) * GROUND_FAR)
        fine = (snap_lo(min(xs)), snap_hi(max(xs)), snap_lo(min(zs)), snap_hi(max(zs)))
    else:
        fine = (0, 0, 0, 0)
    def in_fine(x0, z0):
        return fine[0] <= x0 < fine[1] and fine[2] <= z0 < fine[3]
    def uv(x, z):
        if hi:
            return ground_uv((x, GROUND_Y, z), (0.0, 1.0, 0.0))
        unit = m.TEX_PX * 32 / float(TILES_PERIOD)
        return x * unit, z * unit
    def face(points):
        corners = [(x, GROUND_Y, z) + tuple(uv(x, z)) for x, z in points]
        return Face(corners, (0.0, 1.0, 0.0), tex, False, float(GROUND_FINE))
    edge = set()
    near = set()
    for p in pieces:
        if p.get("tex") == m.INVISIBLE or p.get("kind") in m.VISUAL_KINDS:
            continue
        if not (p["y"] <= 50 and p["y"] + p["h"] >= GROUND_Y):
            continue
        try:
            fx0, fx1, fz0, fz1, _ = m.footprint(dict(p, yaw=int(round(float(p.get("yaw", 0)
                                                                          or 0))) % 360))
        except Exception:
            r = math.hypot(p["w"], p["d"]) / 2.0
            fx0, fx1, fz0, fz1 = p["x"] - r, p["x"] + r, p["z"] - r, p["z"] + r
        g = GROUND_FINE
        for a in range(int(math.floor(fx0 / g)) * g, int(math.ceil(fx1 / g)) * g, g):
            for b in range(int(math.floor(fz0 / g)) * g, int(math.ceil(fz1 / g)) * g, g):
                if fx0 <= a and a + g <= fx1 and fz0 <= b and b + g <= fz1:
                    continue
                edge.add((a, b))
        for a in range(int(math.floor((fx0 - g) / g)) * g, int(math.ceil((fx1 + g) / g)) * g, g):
            for b in range(int(math.floor((fz0 - g) / g)) * g, int(math.ceil((fz1 + g) / g)) * g,
                           g):
                near.add((a, b))
    busy = set((int(math.floor(a / float(GROUND_MID))) * GROUND_MID,
                int(math.floor(b / float(GROUND_MID))) * GROUND_MID) for a, b in near | edge)
    def leaf(x, z):
        if not in_fine(int(math.floor(x / GROUND_FAR)) * GROUND_FAR,
                       int(math.floor(z / GROUND_FAR)) * GROUND_FAR):
            return GROUND_FAR
        g = GROUND_FINE
        if (int(math.floor(x / g)) * g, int(math.floor(z / g)) * g) in edge:
            return GROUND_EDGE
        if (int(math.floor(x / GROUND_MID)) * GROUND_MID,
                int(math.floor(z / GROUND_MID)) * GROUND_MID) in busy:
            return g
        return GROUND_MID
    def cell(x0, z0, x1, z1):
        corners = ((x0, z0), (x0, z1), (x1, z1), (x1, z0))
        pts, seam = [], False
        for k in range(4):
            (ax, az), (bx, bz) = corners[k], corners[(k + 1) % 4]
            pts.append((ax, az))
            ox, oz = (az - bz, bx - ax)
            ln = float(max(abs(ox), abs(oz)) or 1)
            ox, oz = ox / ln, oz / ln
            span = max(abs(bx - ax), abs(bz - az))
            for t in range(GROUND_EDGE, span, GROUND_EDGE):
                px = ax + (bx - ax) * t // span
                pz = az + (bz - az) * t // span
                if abs(px) >= R or abs(pz) >= R:
                    continue
                dx, dz = (bx - ax) / float(span), (bz - az) / float(span)
                size = min(leaf(px + ox - dx, pz + oz - dz), leaf(px + ox + dx, pz + oz + dz))
                if size < span and (px % size == 0 and pz % size == 0):
                    pts.append((px, pz))
                    seam = True
        if not seam:
            out.append(face(pts))
            return
        mid = ((x0 + x1) // 2, (z0 + z1) // 2)
        for k in range(len(pts)):
            out.append(face([mid, pts[k], pts[(k + 1) % len(pts)]]))
    out = []
    k0 = int(math.floor(-R / float(GROUND_FAR)))
    k1 = int(math.ceil(R / float(GROUND_FAR)))
    for i in range(k0, k1):
        for j in range(k0, k1):
            x0, z0 = max(-R, i * GROUND_FAR), max(-R, j * GROUND_FAR)
            x1, z1 = min(R, (i + 1) * GROUND_FAR), min(R, (j + 1) * GROUND_FAR)
            if x1 <= x0 or z1 <= z0:
                continue
            if not in_fine(i * GROUND_FAR, j * GROUND_FAR):
                cell(x0, z0, x1, z1)
                continue
            for e in range(x0, x1, GROUND_MID):
                for f in range(z0, z1, GROUND_MID):
                    e1, f1 = min(x1, e + GROUND_MID), min(z1, f + GROUND_MID)
                    if (e, f) not in busy:
                        cell(e, f, e1, f1)
                        continue
                    for a in range(e, e1, GROUND_FINE):
                        for b in range(f, f1, GROUND_FINE):
                            a1, b1 = min(e1, a + GROUND_FINE), min(f1, b + GROUND_FINE)
                            if (a, b) not in edge:
                                cell(a, b, a1, b1)
                                continue
                            for c in range(a, a1, GROUND_EDGE):
                                for d in range(b, b1, GROUND_EDGE):
                                    cell(c, d, min(a1, c + GROUND_EDGE),
                                         min(b1, d + GROUND_EDGE))
    return out
class GroundCull(object):
    def __init__(self, pieces):
        m = arenas_tool()
        self.boxes, self.cells = [], {}
        for p in pieces:
            if p.get("kind") not in ("box", "ice", "lava") or p.get("decor") \
                    or p.get("tex") == m.INVISIBLE or float(p.get("yaw", 0) or 0) % 90:
                continue
            if not (p["y"] <= 1 and p["y"] + p["h"] >= GROUND_Y):
                continue
            x0, x1, z0, z1, _ = m.footprint(dict(p, yaw=int(round(float(p.get("yaw", 0) or 0))) % 360))
            k = len(self.boxes)
            self.boxes.append((x0, x1, z0, z1))
            for i in range(int(math.floor(x0 / Cull.CELL)), int(math.floor(x1 / Cull.CELL)) + 1):
                for j in range(int(math.floor(z0 / Cull.CELL)), int(math.floor(z1 / Cull.CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
    def hidden(self, poly):
        cx = sum(p[0] for p in poly) / len(poly)
        cz = sum(p[2] for p in poly) / len(poly)
        tests = [(cx, cz)] + [(p[0] + (cx - p[0]) * 0.02, p[2] + (cz - p[2]) * 0.02) for p in poly]
        for x, z in tests:
            ok = False
            for k in self.cells.get((int(math.floor(x / Cull.CELL)), int(math.floor(z / Cull.CELL))), ()):
                b = self.boxes[k]
                if b[0] <= x <= b[1] and b[2] <= z <= b[3]:
                    ok = True
                    break
            if not ok:
                return False
        return True
class MeshCull(object):
    CELL = 400
    def __init__(self, polys):
        self.tops, self.cells = [], {}
        for tex, water, corners, normal, extent, role, on_hero, lod in polys:
            if water or not callable(on_hero) or lod == "far" or normal[1] <= 0.0 \
                    or len(corners) < 3:
                continue
            if min(c[1] for c in corners) < GROUND_Y + 1:
                continue
            pts = [(float(c[0]), float(c[2])) for c in corners]
            k = len(self.tops)
            self.tops.append(pts)
            xs, zs = [p[0] for p in pts], [p[1] for p in pts]
            for i in range(int(math.floor(min(xs) / self.CELL)),
                           int(math.floor(max(xs) / self.CELL)) + 1):
                for j in range(int(math.floor(min(zs) / self.CELL)),
                               int(math.floor(max(zs) / self.CELL)) + 1):
                    self.cells.setdefault((i, j), []).append(k)
    @staticmethod
    def _inside(pts, x, z):
        sign = 0
        for k in range(len(pts)):
            ax, az = pts[k]
            bx, bz = pts[(k + 1) % len(pts)]
            c = (bx - ax) * (z - az) - (bz - az) * (x - ax)
            if abs(c) < 1e-9:
                continue
            s = 1 if c > 0 else -1
            if sign and s != sign:
                return False
            sign = s
        return True
    def hidden(self, poly):
        if not self.tops:
            return False
        cx = sum(p[0] for p in poly) / len(poly)
        cz = sum(p[2] for p in poly) / len(poly)
        tests = [(cx, cz)] + [(p[0] + (cx - p[0]) * 0.02, p[2] + (cz - p[2]) * 0.02) for p in poly]
        for x, z in tests:
            if not any(self._inside(self.tops[k], x, z) for k in
                       self.cells.get((int(math.floor(x / self.CELL)),
                                       int(math.floor(z / self.CELL))), ())):
                return False
        return True
def hero_of(arena, pieces):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import critic
    try:
        h = critic.hero(arena)
    except Exception:
        return None
    if h is None:
        return None
    root = h[3]
    ids = set(id(p) for p in pieces if critic.landmark_root(p) == root
              and math.hypot(p["x"] - h[0], p["z"] - h[1]) <= 2000)
    base = h[5] if len(h) > 5 and h[5] is not None else min(
        [p["y"] for p in pieces if id(p) in ids] or [0])
    if not ids or h[2] - base < 200:
        return None
    return base, h[2], ids
def paint_tops(arena, pieces):
    m = arenas_tool()
    tops = [p["y"] + p["h"] for p in pieces
            if p.get("tex") != m.INVISIBLE and p.get("kind") not in m.VISUAL_KINDS]
    if arena.get("level") == TILES_LEVEL:
        tops.append(0.0)
    return tops
def scene(arena, static, shade=True, terrain=None):
    bake = _bake_module()
    pal = venue_palette(arena.get("look"))
    sun = bake._unit(pal["sun"])
    consumed = terrain.consumed if terrain is not None else set()
    rows = light_rows(arena)
    for k, p in enumerate(arena["pieces"]):
        if p.get("sculpt"):
            rows[k] = sculpted_row(rows[k], p)
    if terrain is not None:
        rows = [r for k, r in enumerate(rows) if k not in consumed] + carved_occluders(
            terrain, [arena["pieces"][i] for i in static])
    grid = bake.Grid(rows)
    pieces = [arena["pieces"][i] for i in static]
    cull = Cull(pieces)
    out = Scene()
    hero = hero_of(arena, pieces) if shade else None
    painter = bake.Painter(grid, paint_tops(arena, pieces), hero[:2] if hero else None)
    out.lights = light_sources(arena, static, terrain) if shade else []
    spots = Lights(out.lights)
    caves = Caves(pieces)
    rooms = out.rooms = Rooms(pieces, grid, arena.get("pockets"))
    drops = pocket_drops(arena.get("pockets"))
    probes = {}
    def probe(x, y, z, n, extent, role, on_hero):
        key = (int(round(x)), int(round(y)), int(round(z)), n, extent, role, bool(on_hero))
        got = probes.get(key)
        if got is None:
            nn, ao, lit = bake.parts(grid, pal, key[0], key[1], key[2], n[0], n[1], n[2], extent)
            ao = bake.sky_ao(ao, bake.sky_open(grid, key[0], key[1], key[2], nn[0], nn[1], nn[2]))
            got = probes[key] = (ao, lit, painter.step(key[0], key[1], key[2], nn, role,
                                                       on_hero))
        return got
    def light_split(face, role, on_hero):
        polys = split_face(face)
        if not shade or role == "glow" or face.water or len(polys) < 2:
            return polys
        return coarse_split(face, polys, lambda x, y, z: probe(
            x, y, z, face.normal, face.extent, role, on_hero))
    def fine(poly, normal, tex, water, extent):
        step = None if water or not spots.lights or abs(normal[1]) < 0.5 \
            else spots.split_step(poly, day=not night)
        if step is None:
            return [poly]
        if step >= SPLIT:
            xs_, zs_ = [c[0] for c in poly], [c[2] for c in poly]
            if max(max(xs_) - min(xs_), max(zs_) - min(zs_)) <= SPLIT + 1:
                return [poly]
            step = SPLIT
        face = Face(poly, normal, tex, water, extent)
        polys = split_face(face, step)
        if len(polys) < 2:
            return polys
        probes = [c for sub in polys for c in sub]
        for cand in ([poly], split_face(face, POOL_HALF, (0,)), split_face(face, POOL_HALF, (2,)),
                     split_face(face, POOL_HALF, (0, 2))):
            if len(cand) < len(polys) and pool_fits(cand, probes, normal):
                return cand
        return polys
    pool_cache = {}
    def pool_rgb(x, y, z, n):
        key = (int(round(x)), int(round(y)), int(round(z)), n)
        got = pool_cache.get(key)
        if got is None:
            add, _ = spots.add(grid, key[0], key[1], key[2], n, 1.0)
            k = 1.0 if night else DAY_POOL
            got = pool_cache[key] = tuple(c * k for c in add)
        return got
    def pool_fits(parts, probes, n):
        ax = _plane_axes(n)
        own = [[pool_rgb(c[0], c[1], c[2], n) for c in part] for part in parts]
        for c in probes:
            for k, part in enumerate(parts):
                if not _in_poly(c, part, ax):
                    continue
                w = _fan_weights(c, part, ax)
                if w is None:
                    return False
                want = pool_rgb(c[0], c[1], c[2], n)
                if any(abs(sum(own[k][i][ch] * f for i, f in w) - want[ch]) > POOL_KEEP
                       for ch in range(3)):
                    return False
                break
            else:
                return False
        return True
    polys = []
    lit = shade and evening(arena)
    night = out.night = lit
    out.fog = fog_of(arena)
    dark = out.dark = night_tint(arena) if shade else None
    for i, piece in zip(static, pieces):
        if i in consumed:
            continue
        on_hero = hero is not None and id(piece) in hero[2]
        parts_faces = [(part, list(sculpted_faces(part) if part.get("sculpt")
                                   else part_faces(part)))
                       for part in drawn_parts(piece)]
        inner = pressed_faces([fs for part_, fs in parts_faces if not part_.get("sculpt")])
        for part, faces_ in parts_faces:
            toned = bool((part.get("sculpt") or {}).get("tone"))
            for face in faces_:
                out.faces += 1
                if id(face) in inner:
                    out.culled += 1
                    continue
                if not face.water and not toned and coarse(face.tex[0], face.tex[1]) \
                        and (face.normal[1] > 0.5 or face.extent >= COARSE_SIDE):
                    face = Face([(c[0], c[1], c[2]) + ground_uv(c[:3], face.normal) + tuple(c[5:])
                                 for c in face.corners],
                                face.normal, (face.tex[0], face.tex[1], "hi"), face.water,
                                face.extent)
                role = "glow" if shade and (glows(face.tex) or part.get("glow")
                                            or piece.get("glow")) \
                    else texture_role(face.tex[0])
                for poly in light_split(face, role, on_hero):
                    if not face.water and cull.hidden(poly, face.normal):
                        out.culled += 1
                        continue
                    if drops and dropped(drops, poly, face.normal):
                        out.culled += 1
                        continue
                    for piece_ in (fine(poly, face.normal, face.tex, face.water, face.extent)
                                   if role != "glow" else [poly]):
                        polys.append((face.tex, face.water, piece_, face.normal, face.extent,
                                      role, on_hero, None))
                    if lit and face.tex[0] in WINDOW_SLUGS and len(face.tex) < 3:
                        lit_tex = (face.tex[0], face.tex[1], "lit")
                        for pane in glass_polys(poly, face.tex, face.normal):
                            polys.append((lit_tex, False, pane, face.normal, face.extent,
                                          "glow", False, None))
    if terrain is not None:
        tcull = Cull([p for i, p in zip(static, pieces) if i not in consumed])
        far = list(getattr(terrain, "far_faces", None) or []) if FAR_GROUND else []
        near_faces = [(f, "near" if far else None) for f in terrain.faces]
        far_faces = [(f, "far") for f in far]
        horizon = [(f, "horizon") for f in getattr(terrain, "horizon_faces", None) or []]
        for (corners, normal, tex, extent, split, own_uv), lod in near_faces + far_faces + horizon:
            out.faces += 1
            face = Face(corners, normal, tex, False, extent)
            if own_uv and coarse(tex[0], tex[1]):
                face = Face(corners, normal, (tex[0], tex[1], "hi"), False, extent)
            elif not own_uv and coarse(tex[0], tex[1]) and (normal[1] > 0.5
                                                            or extent >= COARSE_SIDE):
                face = Face([(x, y, z) + ground_uv((x, y, z), normal)
                             for x, y, z, _, _ in corners],
                            normal, (tex[0], tex[1], "hi"), False, extent)
            role = "glow" if shade and glows(face.tex) else texture_role(face.tex[0])
            for poly in (split_face(face) if split else [list(face.corners)]):
                if tcull.hidden(poly, normal):
                    out.culled += 1
                    continue
                for piece_ in (fine(poly, normal, face.tex, False, extent)
                               if role != "glow" and lod in (None, "near") else [poly]):
                    polys.append((face.tex, False, piece_, normal, extent, role, terrain.tone,
                                  lod))
        rocks = [p for i, p in zip(static, pieces) if i in consumed]
        for face in cave_walls(caves, rocks):
            out.faces += 1
            role = texture_role(face.tex[0])
            for poly in split_face(face):
                if tcull.hidden(poly, face.normal):
                    out.culled += 1
                    continue
                for piece_ in fine(poly, face.normal, face.tex, False, face.extent):
                    polys.append((face.tex, False, piece_, face.normal, face.extent, role, False,
                                  None))
    if terrain is not None:
        for corners, normal, tex, extent in getattr(terrain, "water_faces", None) or []:
            out.faces += 1
            for poly in split_face(Face(corners, normal, tex, True, extent)):
                polys.append((tex, True, poly, normal, extent, "detail", False, None))
    floor = ground_faces(arena, pieces)
    if floor:
        out.ground = True
        gcull = GroundCull(pieces)
        under = MeshCull(polys)
        for face in floor:
            out.faces += 1
            for poly in split_face(face, GROUND_FAR):
                if gcull.hidden(poly) or under.hidden(poly):
                    out.culled += 1
                    continue
                polys.append((face.tex, False, poly, face.normal, face.extent, "ground", False,
                              None))
    polys = lit_within(polys)
    if shade:
        out.billboards = billboards(arena, static, out.lights, grid, night)
        out.flames = flame_rows(out.lights)
    if not polys:
        return out
    merged = consolidate(polys, arena.get("texture_cap"))
    gains = [1.0] * len(polys)
    if merged:
        gains = [merged[p[0]][1] if p[0] in merged else 1.0 for p in polys]
        polys = [(merged[p[0]][0],) + p[1:] if p[0] in merged else p for p in polys]
        out.merged = dict((a, b[0]) for a, b in merged.items())
    xs = [p[0] for _, _, poly, _, _, _, _, lod in polys if lod != "far" for p in poly]
    zs = [p[2] for _, _, poly, _, _, _, _, lod in polys if lod != "far" for p in poly]
    tris = sum(len(poly) - 2 for _, _, poly, _, _, _, _, lod in polys if lod != "far")
    chunked = (max(xs) - min(xs) > CHUNK_FROM_ACROSS or max(zs) - min(zs) > CHUNK_FROM_ACROSS
               or tris > CHUNK_FROM_TRIANGLES)
    if not chunked:
        keep = [k for k, p in enumerate(polys) if p[7] != "far"]
        gains = [gains[k] for k in keep]
        polys = [polys[k][:7] + (None if polys[k][7] == "near" else polys[k][7],)
                 for k in keep]
    colours = {}
    light = {}
    groups = {}
    flows = out.flows = Flows(arena)
    smooth = smooth_ground(polys) if shade else {}
    span = chunk_span(arena)
    shifts = uv_shifts(polys, chunked, span)
    for k_, ((tex, water, poly, normal, extent, role, on_hero, lod), gain) in enumerate(
            zip(polys, gains)):
        glow = role == "glow"
        if tex not in out.textures:
            out.textures.append(tex)
        cx = sum(p[0] for p in poly) / len(poly)
        cy = sum(p[1] for p in poly) / len(poly)
        cz = sum(p[2] for p in poly) / len(poly)
        cell, lod = poly_cell(poly, lod, chunked, span)
        ds, dt = shifts[k_]
        verts = []
        for corner in poly:
            x, y, z, s, t = corner[:5]
            vn = _unit(corner[5:8]) if len(corner) >= 8 else normal
            x, y, z = int(round(x)), int(round(y)), int(round(z))
            vext = extent
            if smooth and callable(on_hero) and normal[1] > SMOOTH_NY:
                got = smooth.get((x, y, z))
                if got is not None:
                    vn, vext = got
            s, t = int(round(s - ds)), int(round(t - dt))
            if not (-32768 <= s <= 32767 and -32768 <= t <= 32767):
                raise BakeError("a face's texture runs past s16 at (%d, %d, %d)" % (x, y, z))
            if water:
                flag, rgba = 0, WATER_TINT + (WATER_ALPHA,)
            elif not shade:
                flag, rgba = 0, (128, 128, 128, 255)
            elif glow:
                k = 1.0
                if not night and tex[0] not in DAY_WHOLE:
                    sky = bake.sky_open(grid, x, y, z, normal[0], normal[1], normal[2])
                    k = DAY_GLOW + (1.0 - DAY_GLOW) * (1.0 - sky)
                flag = pack_parts(normal, 1.0, 1.0)[0]
                rgba = tuple(int(round(c * k)) for c in GLOW_RGB) + (255,)
            else:
                key = (x, y, z, vn, vext, role, on_hero, gain)
                if key not in colours:
                    lk = (x, y, z, vn, vext)
                    if lk not in light:
                        n, ao, lit = bake.parts(grid, pal, x, y, z, vn[0], vn[1],
                                                vn[2], vext)
                        ao = bake.sky_ao(ao, bake.sky_open(grid, x, y, z, n[0], n[1], n[2]))
                        light[lk] = (n, ao, lit)
                    n, ao, lit = light[lk]
                    if callable(on_hero):
                        paint = bake.paint_step(painter.gain(x, y, z, n, role, False)
                                                * on_hero(x, y, z, vn if smooth else normal)
                                                * gain)
                    elif gain != 1.0:
                        paint = bake.paint_step(painter.gain(x, y, z, n, role, on_hero) * gain)
                    else:
                        paint = painter.step(x, y, z, n, role, on_hero)
                    flag, alpha = pack_parts(n, ao, lit, paint)
                    dn, dao, dlit = unpack_parts(flag, alpha)
                    rgb = bake.shade(pal, sun, dn, dao, dlit, paint_of(flag))
                    if caves.boxes:
                        rgb = caves.paint(rgb, x, y, z, dn)
                    if dark is not None:
                        rgb = tuple(int(round(c * k + f)) for c, k, f in zip(rgb, dark, NIGHT_FLOOR))
                    if spots.lights:
                        add, share = spots.add(grid, x, y, z, dn, dao)
                        if not night:
                            add = [a * DAY_POOL for a in add]
                            share *= DAY_POOL
                        if share > 0:
                            rgb = tuple(min(255, int(round(c + a))) for c, a in zip(rgb, add))
                            flag, alpha = pack_parts(n, *pooled_parts(ao, lit, paint, share))
                    colours[key] = (flag, tuple(rgb) + (alpha,))
                flag, rgba = colours[key]
            verts.append((x, y, z, flag, s, t) + tuple(rgba))
        room = rooms.room_at(cx, cy, cz) if rooms.count > 1 else ROOM_OPEN
        wkey, gkey = water, glow
        if shade and (water or (glow and tex[0] in FLOW_LAVA)):
            fk, rate = flows.of(poly, normal, water, tex)
            if fk is not None:
                flows.rates.setdefault(fk, []).append(rate)
                if water:
                    wkey = fk
                else:
                    gkey = fk
        groups.setdefault((room, cell, wkey, gkey), {None: [], "near": [], "far": []})[lod].append(
            (tex, verts))
    if chunked:
        groups = split_chunks(groups)
    built = []
    for gk in sorted(groups, key=_gk_order):
        room, cell, water, glow = gk
        g = groups[gk]
        if not g["far"] or (g["near"] and sum(len(v) - 2 for _, v in g["near"]) < LOD_LEAST):
            g = {None: g[None] + g["near"], "near": [], "far": []}
        ch = _chunk(cell, water, g[None], out.textures, g["near"], g["far"])
        ch.glow, ch.room = glow, room
        built.append((g, ch))
    if chunked:
        built = merge_chunks(built, out.textures, rooms if rooms.count > 1 else None)
    out.chunks = [ch for _, ch in built]
    out.cases = room_cases(out, rooms) if rooms.count > 1 else None
    return out
TEXTURE_CAP = 48
FOLD_MOST = 0.09
FOLD_DETAIL = 0.045
_means = {}
def picture_mean(tex):
    thumb = picture_thumb(tex)
    return tuple(sum(c[k] for c in thumb) / len(thumb) for k in range(3))
def picture_thumb(tex):
    if tex not in _means:
        import io
        from PIL import Image
        im = Image.open(io.BytesIO(texture_png(tex))).convert("RGB").resize((4, 4), Image.BOX)
        _means[tex] = [tuple(c / 255.0 for c in im.getpixel((x, y)))
                       for y in range(4) for x in range(4)]
    return _means[tex]
def picture_distance(a, b):
    ta, tb = picture_thumb(a), picture_thumb(b)
    return sum(abs(p[k] - q[k]) for p, q in zip(ta, tb) for k in range(3)) / (3.0 * len(ta))
def consolidate(polys, cap=None):
    cap = TEXTURE_CAP if cap is None else cap
    use = {}
    for p in polys:
        use[p[0]] = use.get(p[0], 0) + len(p[2]) - 2
    if len(use) <= cap:
        return {}
    textures, layered = kit_textures()
    water = set(p[0] for p in polys if p[1])
    def kind(t):
        return texture_role(t[0])
    def foldable(t):
        return t not in water and not (t[0] in layered and t[1])
    out = {}
    live = set(use)
    for a in sorted(use, key=lambda t: (use[t], t)):
        if len(live) <= cap:
            break
        if not foldable(a):
            continue
        ma = picture_mean(a)
        best = None
        for b in live:
            if b == a or not foldable(b) or kind(b) != kind(a) or b in out:
                continue
            d = picture_distance(a, b)
            if d <= (FOLD_DETAIL if kind(a) == "detail" else FOLD_MOST) and (best is None or (d, -use[b], b) < best[:3]):
                best = (d, -use[b], b, picture_mean(b))
        if best is None:
            continue
        b, mb = best[2], best[3]
        la = sum(ma) / 3.0
        lb = sum(mb) / 3.0 or 1e-3
        out[a] = (b, max(0.8, min(1.2, la / lb)))
        live.discard(a)
        use[b] += use[a]
    for a in list(out):
        b, g = out[a]
        while b in out:
            b, g = out[b][0], g * out[b][1]
        out[a] = (b, g)
    return out
SMOOTH_NY = 0.3
def smooth_ground(polys):
    acc = {}
    for tex, water, poly, normal, extent, role, on_hero, lod in polys:
        if water or not callable(on_hero) or normal[1] <= SMOOTH_NY:
            continue
        for corner in poly:
            k = (int(round(corner[0])), int(round(corner[1])), int(round(corner[2])))
            a = acc.get(k)
            if a is None:
                acc[k] = [normal[0], normal[1], normal[2], extent or 0]
            else:
                a[0] += normal[0]
                a[1] += normal[1]
                a[2] += normal[2]
                a[3] = max(a[3], extent or 0)
    out = {}
    for k, (nx, ny, nz, ext) in acc.items():
        n = _unit((nx, ny, nz))
        out[k] = (tuple(round(c, 4) for c in n), ext or None)
    return out
def chunk_span(arena):
    t = arena.get("terrain") if isinstance(arena.get("terrain"), dict) else {}
    half = ((t.get("backdrop") or {}).get("half") if isinstance(t.get("backdrop"), dict)
            else None)
    if not half:
        half = max([max(abs(p["x"]) + p["w"] / 2.0, abs(p["z"]) + p["d"] / 2.0)
                    for p in arena.get("pieces") or [] if "x" in p] or [0])
    return CHUNK_SPAN_GIANT if half >= GIANT_HALF else CHUNK_SPAN
def poly_cell(poly, lod, chunked, span=CHUNK_SPAN):
    n = float(len(poly))
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    cz = sum(p[2] for p in poly) / n
    cell = (int(math.floor(cx / span)), int(math.floor(cy / span)),
            int(math.floor(cz / span))) if chunked else (0, 0, 0)
    if lod == "horizon":
        lod = None
        if chunked:
            cell = (int(math.floor(cx / HORIZON_SPAN)), -99999,
                    int(math.floor(cz / HORIZON_SPAN)))
    return cell, lod
def uv_shifts(polys, chunked, span_=CHUNK_SPAN):
    span = TEX_PERIOD * TEX_SHIFT
    own = []
    groups = {}
    for k, (tex, water, poly, normal, extent, role, on_hero, lod) in enumerate(polys):
        s0, s1 = min(p[3] for p in poly), max(p[3] for p in poly)
        t0, t1 = min(p[4] for p in poly), max(p[4] for p in poly)
        own.append((int(math.floor(s0 / span)) * span, int(math.floor(t0 / span)) * span))
        g = groups.setdefault((poly_cell(poly, lod, chunked, span_), tex),
                              [s0, s1, t0, t1, []])
        g[0], g[1] = min(g[0], s0), max(g[1], s1)
        g[2], g[3] = min(g[2], t0), max(g[3], t1)
        g[4].append(k)
    out = list(own)
    room = 32767 - span // 2 - 1
    for s0, s1, t0, t1, ks in groups.values():
        if (s1 - s0) / 2.0 > room or (t1 - t0) / 2.0 > room:
            continue
        ds = int(round((s0 + s1) / 2.0 / span)) * span
        dt = int(round((t0 + t1) / 2.0 / span)) * span
        for k in ks:
            out[k] = (ds, dt)
    return out
def _unique(polys):
    return len(set((tex,) + tuple(v) for tex, vs in polys for v in vs))
def _middle(polys):
    xs = [v[0] for _, vs in polys for v in vs]
    zs = [v[2] for _, vs in polys for v in vs]
    return (min(xs) + max(xs)) / 2.0, (min(zs) + max(zs)) / 2.0, max(xs) - min(xs), \
        max(zs) - min(zs)
def split_chunks(groups):
    out = {}
    todo = sorted(groups.items(), key=lambda kv: _gk_order(kv[0]))
    while todo:
        gk, g = todo.pop(0)
        polys = g[None] + g["near"]
        if g["far"] or len(polys) < 2 or _unique(polys) <= CHUNK_MOST:
            out[gk] = g
            continue
        mx, mz, ex, ez = _middle(polys)
        axis = 0 if ex >= ez else 2
        keyed = sorted(polys, key=lambda pv: sum(v[axis] for v in pv[1]) / len(pv[1]))
        half = len(keyed) // 2
        room, cell, water, glow = gk
        for k, part in enumerate((keyed[:half], keyed[half:])):
            todo.append(((room, tuple(cell) + (k,), water, glow),
                         {None: part, "near": [], "far": []}))
    return out
MERGE_TRIES = 4
def _gk_order(gk):
    room, cell, water, glow = gk
    return (room, cell, str(water), str(glow))
def _glow_kind(glow):
    return glow if isinstance(glow, str) else bool(glow)
def merge_chunks(built, textures, rooms=None):
    def cases(ch):
        return frozenset(chunk_cases(ch, rooms)) if rooms is not None else frozenset()
    items = [[g, ch, cases(ch)] for g, ch in built]
    order = sorted(range(len(items)), key=lambda k: (len(items[k][1].vertices), k))
    gone = set()
    for k in order:
        g, ch, mine = items[k]
        if k in gone or ch.far is not None or len(ch.vertices) >= CHUNK_LEAST:
            continue
        near = []
        for j, (og, och, theirs) in enumerate(items):
            if j == k or j in gone or och.far is not None or och.room != ch.room \
                    or och.water != ch.water or _glow_kind(och.glow) != _glow_kind(ch.glow) \
                    or theirs != mine or len(och.vertices) + len(ch.vertices) > CHUNK_MOST:
                continue
            d = sum((a - b) ** 2 for a, b in zip(och.centre, ch.centre))
            near.append((d, j))
        for _, j in sorted(near)[:MERGE_TRIES]:
            og, och, theirs = items[j]
            polys = og[None] + g[None]
            _, _, ex, ez = _middle(polys)
            if max(ex, ez) > CHUNK_SPAN_GIANT:
                continue
            both = _chunk(och.cell, och.water, polys, textures)
            both.glow, both.room = och.glow, och.room
            if len(both.vertices) > CHUNK_MOST or cases(both) != mine:
                continue
            items[j] = [{None: polys, "near": [], "far": []}, both, theirs]
            gone.add(k)
            break
    return [(g, ch) for k, (g, ch, _) in enumerate(items) if k not in gone]
def _pack(polys, textures, centre):
    cx, cy, cz = centre
    order = sorted(range(len(polys)), key=lambda i: textures.index(polys[i][0]))
    loads = []
    load = None
    for i in order:
        tex, verts = polys[i]
        local = [(v[0] - cx, v[1] - cy, v[2] - cz) + tuple(v[3:]) for v in verts]
        if load is not None and load[0] == tex:
            index = load[4]
            fresh = sum(1 for v in local if v not in index)
            if len(load[3]) + fresh > LOAD_MOST:
                load = None
        if load is None or load[0] != tex:
            load = [tex, 0, [], [], {}]
            loads.append(load)
        ids = []
        for v in local:
            if v not in load[4]:
                load[4][v] = len(load[3])
                load[3].append(v)
            ids.append(load[4][v])
        for k in range(1, len(ids) - 1):
            if len(set((ids[0], ids[k], ids[k + 1]))) == 3:
                load[2].append((ids[0], ids[k], ids[k + 1]))
    vertices, final = [], []
    for tex, _, tris, verts, _ in loads:
        final.append((tex, len(vertices), len(verts), tris))
        vertices.extend(verts)
    return vertices, final
def _chunk(cell, water, polys, textures, near=(), far=()):
    ch = Chunk(cell, water)
    every = list(polys) + list(near) + list(far)
    xs = [v[0] for _, vs in every for v in vs]
    ys = [v[1] for _, vs in every for v in vs]
    zs = [v[2] for _, vs in every for v in vs]
    lo, hi = (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))
    ch.centre = tuple(int(round((a + b) / 2.0)) for a, b in zip(lo, hi))
    half = [(b - a) / 2.0 for a, b in zip(lo, hi)]
    ch.radius = int(math.ceil(math.sqrt(sum(h * h for h in half)) * CULL_MARGIN)) + 1
    ch.vertices, ch.loads = _pack(list(polys), textures, ch.centre)
    if far:
        nv, nl = _pack(list(near), textures, ch.centre)
        ch.near_from = len(ch.loads)
        ch.loads += [(t, first + len(ch.vertices), n, tris) for t, first, n, tris in nl]
        ch.vertices += nv
        ch.far = Chunk(cell, water)
        ch.far.centre, ch.far.radius = ch.centre, ch.radius
        ch.far.vertices, ch.far.loads = _pack(list(far), textures, ch.centre)
    for part in (ch, ch.far):
        if part is not None and any(not -32768 <= c <= 32767 for v in part.vertices
                                    for c in v[:3]):
            raise BakeError("a chunk vertex lies outside s16")
    return ch
G_SETOTHERMODE_L, G_TEXTURE, G_GEOMETRYMODE, G_DL = 0xE2, 0xD7, 0xD9, 0xDE
G_LIGHTING, G_FOG = 0x00020000, 0x00010000
G_LIGHTING_ENGINE_EXT = 0x00004000
RM_OPA = 0x00552078
RM_XLU = 0x005049D8
CC_MODULATERGB = (0xFC127E24, 0xFFFFF9FC)
CC_SHADE = (0xFCFFFFFF, 0xFFFE793C)
SETTILE_LOAD = (0xF5100000, 0x07000000)
SETTILE_RENDER = (0xF5101000, 0x00014050)
TILESIZE_32 = (0xF2000000, 0x0007C07C)
LOADBLOCK_32 = (0xF3000000, 0x073FF100)
SETTIMG_RGBA16 = 0xFD100000
PIPESYNC, LOADSYNC = (0xE7000000, 0), (0xE6000000, 0)
TEXTURE_ON = (0xD7000002, 0xFFFFFFFF)
TEXTURE_OFF = (0xD7000000, 0xFFFFFFFF)
ENDDL = (0xDF000000, 0)
G_SETOTHERMODE_H, G_MOVEWORD, G_SETFOGCOLOR = 0xE3, 0xDB, 0xF8
G_SHADE, G_CULL_FRONT, G_CULL_BACK, G_SHADING_SMOOTH = 0x4, 0x200, 0x400, 0x200000
CYCLE_1 = (0xE3000A01, 0)
AC_NONE = (0xE2001E01, 0)
RM_FOG_OPA = 0xC8152078
RM_FOG_XLU = 0xC81049D8
HEAD_CLEAR = G_CULL_FRONT | G_LIGHTING | G_LIGHTING_ENGINE_EXT
HEAD_SET = G_CULL_BACK | G_SHADE | G_SHADING_SMOOTH
FOG_SLOTS = (3, 4, 5, 6)
def cmd_render_mode(data):
    return ((G_SETOTHERMODE_L << 24) | ((32 - 3 - 29) << 8) | (29 - 1), data)
def cmd_geometry(clear, set_):
    return ((G_GEOMETRYMODE << 24) | (~clear & 0xFFFFFF), set_)
def cmd_fog_factor(fm, fo):
    return ((G_MOVEWORD << 24) | (0x08 << 16), ((fm & 0xFFFF) << 16) | (fo & 0xFFFF))
def cmd_fog_colour(r, g, b, a=255):
    return (G_SETFOGCOLOR << 24, ((r & 0xFF) << 24) | ((g & 0xFF) << 16) | ((b & 0xFF) << 8)
            | (a & 0xFF))
def fog_slots(fog, water):
    on, (fm, fo), rgb = fog
    if on:
        geo = cmd_geometry(HEAD_CLEAR, HEAD_SET | G_FOG)
        rm = RM_FOG_XLU if water else RM_FOG_OPA
    else:
        geo = cmd_geometry(HEAD_CLEAR | G_FOG, HEAD_SET)
        rm = RM_XLU if water else RM_OPA
    return [geo, cmd_fog_factor(fm, fo), cmd_fog_colour(*rgb), cmd_render_mode(rm)]
def cmd_call(label):
    return ((G_DL << 24), ("ptr", label, 0))
G_VTX, G_VTX_EXT = 0x01, 0x11
def cmd_vertex(label, offset, count, glow=False):
    return (((G_VTX_EXT if glow else G_VTX) << 24) | (count << 12) | ((count & 0x7F) << 1),
            ("ptr", label, offset))
def cmd_tris(tris):
    out = []
    for k in range(0, len(tris), 2):
        a = tris[k]
        pa = (a[0] * 2 << 16) | (a[1] * 2 << 8) | (a[2] * 2)
        if k + 1 < len(tris):
            b = tris[k + 1]
            out.append((0x06000000 | pa, (b[0] * 2 << 16) | (b[1] * 2 << 8) | (b[2] * 2)))
        else:
            out.append((0x05000000 | pa, 0))
    return out
C_OF = {
    PIPESYNC: "gsDPPipeSync()", LOADSYNC: "gsDPLoadSync()", ENDDL: "gsSPEndDisplayList()",
    cmd_render_mode(RM_OPA): "gsDPSetRenderMode(G_RM_AA_ZB_OPA_SURF, G_RM_AA_ZB_OPA_SURF2)",
    cmd_render_mode(RM_XLU): "gsDPSetRenderMode(G_RM_AA_ZB_XLU_SURF, G_RM_AA_ZB_XLU_SURF2)",
    cmd_geometry(G_LIGHTING, 0): "gsSPGeometryMode(G_LIGHTING, 0)",
    cmd_geometry(0, G_LIGHTING): "gsSPGeometryMode(0, G_LIGHTING)",
    cmd_geometry(G_LIGHTING, G_LIGHTING_ENGINE_EXT):
        "gsSPGeometryMode(G_LIGHTING, G_LIGHTING_ENGINE_EXT)",
    cmd_geometry(G_LIGHTING_ENGINE_EXT, G_LIGHTING):
        "gsSPGeometryMode(G_LIGHTING_ENGINE_EXT, G_LIGHTING)",
    cmd_geometry(G_LIGHTING_ENGINE_EXT, 0): "gsSPGeometryMode(G_LIGHTING_ENGINE_EXT, 0)",
    CC_MODULATERGB: "gsDPSetCombineMode(G_CC_MODULATERGB, G_CC_MODULATERGB)",
    CC_SHADE: "gsDPSetCombineMode(G_CC_SHADE, G_CC_SHADE)",
    TEXTURE_ON: "gsSPTexture(65535, 65535, 0, G_TX_RENDERTILE, G_ON)",
    TEXTURE_OFF: "gsSPTexture(65535, 65535, 0, G_TX_RENDERTILE, G_OFF)",
    SETTILE_LOAD: "gsDPSetTile(G_IM_FMT_RGBA, G_IM_SIZ_16b, 0, 0, G_TX_LOADTILE, 0, "
                  "G_TX_WRAP | G_TX_NOMIRROR, 0, 0, G_TX_WRAP | G_TX_NOMIRROR, 0, 0)",
    SETTILE_RENDER: "gsDPSetTile(G_IM_FMT_RGBA, G_IM_SIZ_16b, 8, 0, G_TX_RENDERTILE, 0, "
                    "G_TX_WRAP | G_TX_NOMIRROR, 5, 0, G_TX_WRAP | G_TX_NOMIRROR, 5, 0)",
    TILESIZE_32: "gsDPSetTileSize(G_TX_RENDERTILE, 0, 0, 124, 124)",
    LOADBLOCK_32: "gsDPLoadBlock(G_TX_LOADTILE, 0, 0, 1023, 256)",
    CYCLE_1: "gsDPSetCycleType(G_CYC_1CYCLE)",
    AC_NONE: "gsDPSetAlphaCompare(G_AC_NONE)",
    cmd_render_mode(RM_FOG_OPA): "gsDPSetRenderMode(G_RM_FOG_SHADE_A | G_BL_A_MEM << 18, "
                                 "G_RM_AA_ZB_OPA_SURF2)",
    cmd_render_mode(RM_FOG_XLU): "gsDPSetRenderMode(G_RM_FOG_SHADE_A, G_RM_AA_ZB_XLU_SURF2)",
}
GEOMETRY_BITS = (("G_SHADE", G_SHADE), ("G_CULL_FRONT", G_CULL_FRONT),
                 ("G_CULL_BACK", G_CULL_BACK), ("G_LIGHTING_ENGINE_EXT", G_LIGHTING_ENGINE_EXT),
                 ("G_FOG", G_FOG), ("G_LIGHTING", G_LIGHTING),
                 ("G_SHADING_SMOOTH", G_SHADING_SMOOTH))
def _bits_c(v):
    names = [n for n, b in GEOMETRY_BITS if v & b]
    if sum(b for n, b in GEOMETRY_BITS if v & b) != v:
        raise BakeError("no C for the geometry bits %#x" % v)
    return " | ".join(names) or "0"
def c_of(w0, w1):
    if (w0, w1) in C_OF:
        return C_OF[(w0, w1)]
    if w0 == (G_MOVEWORD << 24) | (0x08 << 16):
        return "gsSPFogFactor(%d, %d)" % (_s16(w1 >> 16), _s16(w1))
    if w0 == G_SETFOGCOLOR << 24:
        return "gsDPSetFogColor(%d, %d, %d, %d)" % ((w1 >> 24) & 0xFF, (w1 >> 16) & 0xFF,
                                                    (w1 >> 8) & 0xFF, w1 & 0xFF)
    if (w0 >> 24) == G_GEOMETRYMODE:
        return "gsSPGeometryMode(%s, %s)" % (_bits_c(~w0 & 0xFFFFFF), _bits_c(w1))
    return None
def gfx_source(label, commands):
    lines = ["Gfx %s[] = {" % label]
    for w0, w1 in commands:
        if isinstance(w1, tuple):
            op = w0 >> 24
            if op == G_DL:
                lines.append("\tgsSPDisplayList(%s)," % w1[1])
            elif op in (G_VTX, G_VTX_EXT):
                count = (w0 >> 12) & 0xFF
                ref = w1[1] if w1[2] == 0 else "%s + %d" % (w1[1], w1[2])
                lines.append("\t%s(%s, %d, 0)," % ("gsSPVertex" if op == G_VTX
                                                    else "gsSPVertexNonGlobal", ref, count))
            elif w0 == SETTIMG_RGBA16:
                lines.append("\tgsDPSetTextureImage(G_IM_FMT_RGBA, G_IM_SIZ_16b, 1, %s)," % w1[1])
            else:
                raise BakeError("no C for a pointer command %#x" % w0)
        elif c_of(w0, w1) is not None:
            lines.append("\t%s," % c_of(w0, w1))
        elif (w0 >> 24) in (0x05, 0x06):
            a = ((w0 >> 16) & 0xFF) // 2, ((w0 >> 8) & 0xFF) // 2, (w0 & 0xFF) // 2
            if (w0 >> 24) == 0x05:
                lines.append("\tgsSP1Triangle(%d, %d, %d, 0)," % a)
            else:
                b = ((w1 >> 16) & 0xFF) // 2, ((w1 >> 8) & 0xFF) // 2, (w1 & 0xFF) // 2
                lines.append("\tgsSP2Triangles(%d, %d, %d, 0, %d, %d, %d, 0)," % (a + b))
        else:
            raise BakeError("no C for the command %#010x %#010x" % (w0, w1))
    lines.append("};")
    return "\n".join(lines) + "\n"
def vtx_bytes(v):
    x, y, z, flag, s, t, r, g, b, a = v
    return struct.pack("<3hH2h4B", x, y, z, flag, s, t, r, g, b, a)
def vtx_source(label, verts):
    lines = ["Vtx %s[%d] = {" % (label, len(verts))]
    for x, y, z, flag, s, t, r, g, b, a in verts:
        lines.append("\t{{{%d, %d, %d}, %d, {%d, %d}, {%d, %d, %d, %d}}}," % (x, y, z, flag, s, t,
                                                                               r, g, b, a))
    lines.append("};")
    return "\n".join(lines) + "\n"
def _bbh(a, b, c):
    return ((c & 0xFFFF) << 16) | ((b & 0xFF) << 8) | (a & 0xFF)
def _hh(a, b):
    return ((b & 0xFFFF) << 16) | (a & 0xFFFF)
GEO_START, GEO_OPEN, GEO_CLOSE, GEO_RETURN = 0x0B, 0x04, 0x05, 0x03
GEO_CULLING_RADIUS = 0x20
def texture_name(key, tex):
    slug, layer = tex[0], tex[1]
    hi = "_%s" % tex[2] if len(tex) > 2 else ""
    return "of_%s_bake_t_%s%s%s" % (key, slug, "" if not layer else "_%d" % layer, hi)
def texture_png(tex):
    slug, layer = tex[0], tex[1]
    if len(tex) > 2 and tex[2] == "lit":
        return lit_png(slug, layer)
    if len(tex) > 2:
        return hi_png(slug)
    textures, layered = kit_textures()
    if slug in layered and layer:
        return layered[slug][layer - 1]
    return textures[slug]
LIGHTFOG_CONTRACT = 2
FOG_CLEAR = 3000
def fog_of(arena):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    from mapgen import modpack, mood
    from mapgen.render import gamefog
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    try:
        got, _ = modpack.resolve_look({"look": look}, [])
    except Exception:
        got = {}
    air = tuple(gamefog.sky_air(got.get("sky")) or modpack.FOG_GREY)
    fog = got.get("fog")
    stop = None
    if fog:
        wants = {}
        for pair in look.get("visuals") or []:
            if isinstance(pair, (list, tuple)) and len(pair) == 2:
                wants[pair[0]] = pair[1]
        m = mood.clean(look.get("mood"))
        for field, row in modpack.MOOD_ROW.items():
            if field in m:
                wants[row] = m[field]
        stop = modpack.stop_of("fog", wants.get("fog"))
    if stop and "fogx" in stop:
        start, end = gamefog.reach(stop)
        start = max(FOG_CLEAR, start)
        if end is not None:
            end = max(end, start + 1000)
        words = gamefog.haze_words(start, end, fog[0], **gamefog.ENGINE_PLANES)
        return True, words, tuple(int(c) for c in fog[1:4])
    return False, gamefog.haze_words(gamefog.HAZE_START, None, **gamefog.ENGINE_PLANES), air
def head_name(key, water):
    return water_dl_name(key) if water else static_dl_name(key)
def revert_name(key, water):
    return "of_%s_bake_%s" % (key, "wrevert" if water else "revert")
def build_level_nodes(lv, sc, key):
    nodes, source, seen = [], [], set()
    def add(node, text):
        if node[1] not in seen:
            seen.add(node[1])
            nodes.append(node)
            source.append(text)
    fog = getattr(sc, "fog", None) or (False, (10182, -9960), (150, 152, 160))
    def head(water):
        cmds = [PIPESYNC, CYCLE_1, AC_NONE] + fog_slots(fog, water) + [
            CC_MODULATERGB, TEXTURE_ON, ENDDL]
        return (DATA_TYPE_DISPLAY_LIST, head_name(key, water), cmds)
    def revert(water):
        cmds = [PIPESYNC, cmd_geometry(G_FOG | G_LIGHTING_ENGINE_EXT, G_LIGHTING),
                cmd_render_mode(RM_XLU if water else RM_OPA), CC_SHADE, TEXTURE_OFF, ENDDL]
        return (DATA_TYPE_DISPLAY_LIST, revert_name(key, water), cmds)
    geo = [GEO_START, GEO_OPEN]
    numbers = {"v": 0, "w": 0, "g": 0}
    chunk_geo = []
    def chunk_list(dname, vname, vertices, loads, water, glow=False):
        h = head(water)
        cmds = [cmd_call(h[1])]
        add(h, gfx_source(h[1], h[2]))
        vnode = (DATA_TYPE_VERTEX, vname, [vtx_bytes(v) for v in vertices])
        current = None
        for tex, first, count, tris in loads:
            if tex != current:
                tname = texture_name(key, tex)
                add((DATA_TYPE_TEXTURE, tname, ("png", texture_png(tex))),
                    "ALIGNED8 static const Texture %s[] = {\n#include \"levels/%s/%s.rgba16.inc.c\"\n};\n"
                    % (tname, lv.script, tname))
                lv.files["%s.rgba16.png" % tname] = texture_png(tex)
                cmds += [PIPESYNC, (SETTIMG_RGBA16, ("ptr", tname, 0)), SETTILE_LOAD, LOADSYNC,
                         LOADBLOCK_32, PIPESYNC, SETTILE_RENDER, TILESIZE_32]
                current = tex
            if vname not in seen:
                add(vnode, vtx_source(vname, vertices))
            cmds.append(cmd_vertex(vname, first, count, glow))
            cmds += cmd_tris(tris)
        r = revert(water)
        add(r, gfx_source(r[1], r[2]))
        cmds += [cmd_call(r[1]), ENDDL]
        add((DATA_TYPE_DISPLAY_LIST, dname, cmds), gfx_source(dname, cmds))
    lv.scroll = []
    for index, ch in enumerate(sc.chunks):
        kind = "w" if ch.water else ("g" if getattr(ch, "glow", False) else "v")
        vname = vertex_name(key, ch.water, numbers[kind], getattr(ch, "glow", False))
        numbers[kind] += 1
        row = scroll_row(vname, ch, getattr(sc, "flows", None))
        if row is not None:
            lv.scroll.append(row)
        dname = "of_%s_bake_c%d" % (key, index)
        layer = LAYER_TRANSPARENT if ch.water else LAYER_OPAQUE
        cx, cy, cz = ch.centre
        always, near, far = ch.parts()
        glow = getattr(ch, "glow", False)
        words = [_bbh(0x11, layer, cx), _hh(cy, cz), GEO_OPEN,
                 _bbh(GEO_CULLING_RADIUS, 0, min(ch.radius, 32767)), GEO_OPEN]
        loads = list(always) + list(near)
        if loads:
            chunk_list(dname, vname, ch.vertices, loads, ch.water, glow)
            words += [_bbh(0x15, layer, 0), ("ptr", dname, 0)]
        words += [GEO_CLOSE, GEO_CLOSE]
        chunk_geo.append(words)
    cases = getattr(sc, "cases", None)
    if cases:
        geo += [_bbh(GEO_SWITCH, 0, len(cases)), ("fn", GEO_SWITCH_AREA), GEO_OPEN]
        for case in cases:
            geo.append(GEO_START)
            if case:
                geo.append(GEO_OPEN)
                for k in case:
                    geo += chunk_geo[k]
                geo.append(GEO_CLOSE)
        geo.append(GEO_CLOSE)
    else:
        for words in chunk_geo:
            geo += words
    done = set()
    for x, y, z, mkey, (bverts, btris) in getattr(sc, "billboards", []):
        bname = billboard_name(key, mkey)
        if bname not in done:
            done.add(bname)
            vname_ = bname + "_v"
            recs = [(vx, vy, vz, 0, 0, 0) + tuple(rgba) for vx, vy, vz, *rgba in bverts]
            add((DATA_TYPE_VERTEX, vname_, [vtx_bytes(v) for v in recs]), vtx_source(vname_, recs))
            on, words_, rgb_ = fog
            slots = [cmd_geometry(G_LIGHTING, G_FOG) if on else
                     cmd_geometry(G_LIGHTING | G_FOG, 0),
                     cmd_fog_factor(*words_), cmd_fog_colour(*rgb_),
                     cmd_render_mode(RM_FOG_XLU if on else RM_XLU)]
            cmds = [PIPESYNC] + slots + [
                CC_SHADE,
                TEXTURE_OFF, cmd_vertex(vname_, 0, len(recs), mkey[0] != "puff")] + \
                cmd_tris(btris) + [
                    PIPESYNC, cmd_geometry(G_FOG, G_LIGHTING), cmd_render_mode(RM_OPA), ENDDL]
            add((DATA_TYPE_DISPLAY_LIST, bname, cmds), gfx_source(bname, cmds))
        geo += [_bbh(0x11, LAYER_TRANSPARENT, x), _hh(y, z), GEO_OPEN,
                _bbh(0x0D, 0, 0), _hh(0, BILLBOARD_REACH), GEO_OPEN,
                _bbh(GEO_BILLBOARD, LAYER_TRANSPARENT | 0x80, 0), _hh(0, 0), ("ptr", bname, 0),
                GEO_CLOSE, GEO_CLOSE]
    if getattr(sc, "ground", False):
        hide = ground_hide_name(key)
        add((DATA_TYPE_DISPLAY_LIST, hide, [ENDDL]), gfx_source(hide, [ENDDL]))
        geo += [_bbh(0x15, LAYER_OPAQUE, 0), ("ptr", hide, 0)]
    if static_dl_name(key) not in seen:
        h, r = head(False), revert(False)
        add(h, gfx_source(h[1], h[2]))
        add(r, gfx_source(r[1], r[2]))
        mark = "of_%s_bake_mark" % key
        cmds = [cmd_call(h[1]), cmd_call(r[1]), ENDDL]
        add((DATA_TYPE_DISPLAY_LIST, mark, cmds), gfx_source(mark, cmds))
        geo += [_bbh(0x15, LAYER_OPAQUE, 0), ("ptr", mark, 0)]
    geo += [GEO_CLOSE, GEO_RETURN]
    gname = bake_geo_name(key)
    add((DATA_TYPE_GEO_LAYOUT, gname, geo), geo_layout_source(gname, geo))
    return nodes, source
def vertex_name(key, water, number, glow=False):
    return "of_%s_bake_%s%d" % (key, "w" if water else ("g" if glow else "v"), number)
def bake_geo_name(key):
    return "of_%s_bake_geo" % key
def ground_hide_name(key):
    return "of_%s_bake_ground" % key
LAYER_NAMES = {1: "LAYER_OPAQUE", 5: "LAYER_TRANSPARENT"}
def _s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v
def geo_layout_source(gname, words):
    lines = ["const GeoLayout %s[] = {" % gname]
    depth = 1
    k = 0
    while k < len(words):
        w = words[k]
        op = w & 0xFF
        pad = TAB * depth
        if op == GEO_START:
            lines.append(pad + "GEO_NODE_START(),")
        elif op == GEO_OPEN:
            lines.append(pad + "GEO_OPEN_NODE(),")
            depth += 1
        elif op == GEO_CLOSE:
            depth -= 1
            lines.append(TAB * depth + "GEO_CLOSE_NODE(),")
        elif op == GEO_RETURN:
            lines.append(pad + "GEO_RETURN(),")
        elif op == 0x11:
            y, z = _s16(words[k + 1]), _s16(words[k + 1] >> 16)
            lines.append(pad + "GEO_TRANSLATE_NODE(%s, %d, %d, %d)," % (
                LAYER_NAMES[(w >> 8) & 0xFF], _s16(w >> 16), y, z))
            k += 1
        elif op == 0x0D:
            lines.append(pad + "GEO_RENDER_RANGE(%d, %d)," % (_s16(words[k + 1]),
                                                              _s16(words[k + 1] >> 16)))
            k += 1
        elif op == GEO_CULLING_RADIUS:
            lines.append(pad + "GEO_CULLING_RADIUS(%d)," % _s16(w >> 16))
        elif op == GEO_DISPLAY_LIST:
            lines.append(pad + "GEO_DISPLAY_LIST(%s, %s)," % (LAYER_NAMES[(w >> 8) & 0xFF],
                                                              words[k + 1][1]))
            k += 1
        elif op == GEO_SWITCH:
            if words[k + 1] != ("fn", GEO_SWITCH_AREA):
                raise BakeError("a switch the bake did not write")
            lines.append(pad + "GEO_SWITCH_CASE(%d, geo_switch_area)," % _s16(w >> 16))
            k += 1
        elif op == GEO_BILLBOARD and (w >> 8) & 0x80:
            lines.append(pad + "GEO_BILLBOARD_WITH_PARAMS_AND_DL(%s, %d, %d, %d, %s)," % (
                LAYER_NAMES[(w >> 8) & 0x7F], _s16(w >> 16), _s16(words[k + 1]),
                _s16(words[k + 1] >> 16), words[k + 2][1]))
            k += 2
        else:
            raise BakeError("no C for the geo word %#x" % w)
        k += 1
    lines.append("};")
    return "\n".join(lines) + "\n"
LAYER_OPAQUE, LAYER_TRANSPARENT = 1, 5
GEO_BRANCH = 0x02
GEO_BILLBOARD = 0x14
GEO_DISPLAY_LIST = 0x15
GEO_CLOSE_NODE = 0x05
def static_dl_name(key):
    return "of_%s_static_dl" % key
def water_dl_name(key):
    return "of_%s_water_dl" % key
def baked_name(key, label):
    return label in (static_dl_name(key), water_dl_name(key)) \
        or label.startswith("of_%s_bake_" % key)
class Level(object):
    def __init__(self, key, script=None):
        self.key = key
        self.script = script or "of_" + key
        self.sections = []
        self.nodes = []
        self.branch = None
        self.files = {}
        self.source = []
        self.static = []
        self.runtime = []
        self.stats = {}
        self.scene = None
        self.rooms = None
        self.warps = []
def compile_level(arena, key=None, script=None, shade=True):
    arena = prepared(arena)
    key = key or arena["key"]
    lv = Level(key, script or arena.get("script"))
    lv.static, lv.runtime = split_rows(arena)
    terrain = terrain_of(arena)
    skip = terrain.consumed if terrain is not None else set()
    tris = []
    for i in lv.static:
        if i not in skip:
            tris += collision_triangles(arena["pieces"][i])
    if terrain is not None:
        m = arenas_tool()
        tris += [(surface, m.slopes.sort_first(tri)) for surface, tri in terrain.collision]
    tris += warp_triangles(arena.get("pockets"))
    lv.sections = collision_sections(tris)
    lv.collision, lv.terrain = tris, terrain
    lv.warps = warp_commands(arena.get("pockets"))
    lv.pockets = arena.get("pockets") or []
    sc = scene(arena, lv.static, shade, terrain)
    lv.scene = sc
    for tex in sc.textures:
        size = png_size(texture_png(tex))
        want = (64, 64) if len(tex) > 2 and tex[2] == "hi" else (32, 32)
        if size != want:
            raise BakeError("the block texture %s is %r, the bake loads %d x %d"
                            % (tex[0], size, want[0], want[1]))
    lv.rooms = triangle_rooms(lv.sections, sc.rooms) \
        if sc.rooms is not None and sc.rooms.count > 1 else None
    lv.nodes, lv.source = build_level_nodes(lv, sc, key)
    lv.branch = bake_geo_name(key)
    verts = sum(len(c.vertices) + (len(c.far.vertices) if c.far else 0) for c in sc.chunks)
    draw = sum(len(t) for c in sc.chunks for _, _, _, t in c.loads + (
        c.far.loads if c.far else []))
    lv.stats = {"collision_vertices": sum(len(v) for v, _ in lv.sections),
                "collision_triangles": len(tris), "sections": len(lv.sections),
                "static": len(lv.static), "runtime": len(lv.runtime),
                "draw_vertices": verts, "draw_triangles": draw, "chunks": len(sc.chunks),
                "textures": len(sc.textures), "faces": sc.faces, "culled": sc.culled,
                "loads": sum(len(c.loads) for c in sc.chunks)}
    if terrain is not None:
        lv.stats["terrain"] = dict(terrain.stats)
    return lv
FAR_WORD = (FRUSTUM_FAR_BASE << 16) | 100
def _far_words(words, old, new):
    return [new if w == old else w for w in words]
def bake_body(body, lv, script):
    nodes = read_nodes(body)
    k = _collision_node(nodes)
    kind, label, words = nodes[k]
    sections, tail = split_collision(words)
    nodes[k] = (kind, label, join_collision(sections + lv.sections, tail))
    g = _find(nodes, DATA_TYPE_GEO_LAYOUT, "%s_area_1_geo" % script)
    gkind, glabel, gwords = nodes[g]
    close = len(gwords) - 1 - gwords[::-1].index(GEO_CLOSE_NODE)
    gwords = gwords[:close] + [_bbh(GEO_BRANCH, 1, 0), ("ptr", lv.branch, 0)] + gwords[close:]
    if lv.scene is not None and getattr(lv.scene, "ground", False):
        floor = TILES_GROUND_DL % script
        hit = [k for k in range(1, len(gwords)) if gwords[k] == ("ptr", floor, 0)
               and isinstance(gwords[k - 1], int) and (gwords[k - 1] & 0xFF) == GEO_DISPLAY_LIST]
        if len(hit) != 1:
            raise BakeError("the area geo draws The Tiles' floor %d times, not once" % len(hit))
        gwords[hit[0]] = ("ptr", ground_hide_name(lv.key), 0)
    nodes[g] = (gkind, glabel, gwords)
    a = _find(nodes, DATA_TYPE_GEO_LAYOUT, "%s_area_1" % script)
    nodes[a] = (nodes[a][0], nodes[a][1], _far_words(nodes[a][2], FAR_WORD, (FAR << 16) | 100))
    nodes = nodes[:g] + list(lv.nodes) + nodes[g:]
    if getattr(lv, "rooms", None):
        nodes = with_rooms(nodes, lv, script, len(sections))
    if getattr(lv, "warps", None):
        nodes = with_warps(nodes, lv, script)
    return write_nodes(nodes)
def with_warps(nodes, lv, script):
    s = _find(nodes, DATA_TYPE_LEVEL_SCRIPT, "level_%s_entry" % script)
    kind, label, words = nodes[s]
    at = [i for i in range(len(words) - 1) if words[i] == LEVEL_CMD_TERRAIN]
    if len(at) != 1:
        raise BakeError("the level script has %d TERRAIN commands, not one" % len(at))
    i = at[0] + 2
    if i < len(words) and words[i] == LEVEL_CMD_ROOMS:
        i += 2
    nodes = list(nodes)
    nodes[s] = (kind, label, words[:i] + list(lv.warps) + words[i:])
    return nodes
def level_rooms(base_sections, lv):
    return [ROOM_OPEN] * sum(base_triangles([s]) for s in base_sections) + list(lv.rooms)
def with_rooms(nodes, lv, script, base_count):
    k = _collision_node(nodes)
    sections, _ = split_collision(nodes[k][2])
    values = level_rooms(sections[:base_count], lv)
    s = _find(nodes, DATA_TYPE_LEVEL_SCRIPT, "level_%s_entry" % script)
    kind, label, words = nodes[s]
    at = [i for i in range(len(words) - 1) if words[i] == LEVEL_CMD_TERRAIN
          and isinstance(words[i + 1], tuple) and words[i + 1][0] == "ptr"]
    if len(at) != 1:
        raise BakeError("the level script has %d TERRAIN commands, not one" % len(at))
    i = at[0] + 2
    words = words[:i] + [LEVEL_CMD_ROOMS, ("ptr", rooms_name(lv.key), 0)] + words[i:]
    nodes = list(nodes)
    nodes[s] = (kind, label, words)
    return nodes[:s] + [(DATA_TYPE_ROOMS, rooms_name(lv.key), bytes(values))] + nodes[s:]
def unbake_body(body, key, script):
    nodes = [n for n in read_nodes(body) if not baked_name(key, n[1])]
    out = []
    for kind, label, data in nodes:
        if kind == DATA_TYPE_COLLISION and label.endswith("_area_1_collision"):
            sections, tail = split_collision(data)
            data = join_collision(sections[:1], tail)
        elif kind == DATA_TYPE_GEO_LAYOUT and label == "%s_area_1_geo" % script:
            data = [("ptr", TILES_GROUND_DL % script, 0) if w == ("ptr", ground_hide_name(key), 0)
                    else w for w in data]
            words, k = [], 0
            while k < len(data):
                if isinstance(data[k], int) and (data[k] & 0xFF) in (GEO_BRANCH, GEO_DISPLAY_LIST) \
                        and k + 1 < len(data) and isinstance(data[k + 1], tuple) \
                        and data[k + 1][0] == "ptr" and baked_name(key, data[k + 1][1]):
                    k += 2
                    continue
                words.append(data[k])
                k += 1
            data = words
        elif kind == DATA_TYPE_GEO_LAYOUT and label == "%s_area_1" % script:
            data = _far_words(data, (FAR << 16) | 100, FAR_WORD)
        elif kind == DATA_TYPE_LEVEL_SCRIPT:
            words, k = [], 0
            while k < len(data):
                if data[k] == LEVEL_CMD_ROOMS and k + 1 < len(data) \
                        and data[k + 1] == ("ptr", rooms_name(key), 0):
                    k += 2
                    continue
                if isinstance(data[k], int) and (data[k] & 0xFFFF) == \
                        (LEVEL_CMD_INSTANT_WARP | (0x0C << 8)):
                    k += 3
                    continue
                words.append(data[k])
                k += 1
            data = words
        out.append((kind, label, data))
    return write_nodes(out)
TAB = "\t"
def collision_source(text, lv):
    lines = []
    for verts, groups in lv.sections:
        lines.append(TAB + "COL_INIT(),")
        lines.append(TAB + "COL_VERTEX_INIT(%d)," % len(verts))
        lines += [TAB + "COL_VERTEX(%d, %d, %d)," % v for v in verts]
        for surface, tris in groups:
            lines.append(TAB + "COL_TRI_INIT(%s, %d)," % (SURFACE_NAMES.get(surface, "%#06x" % surface),
                                                         len(tris)))
            lines += [TAB + "COL_TRI(%d, %d, %d)," % t for t in tris]
    at = text.find(TAB + "COL_TRI_STOP(),")
    if at < 0:
        raise BakeError("collision.inc.c has no COL_TRI_STOP()")
    return text[:at] + "".join(line + "\n" for line in lines) + text[at:]
def geo_source(text, lv, script):
    m = re.search(r"const GeoLayout %s_area_1_geo\[\] = \{.*?\n\};" % re.escape(script), text, re.S)
    if m is None:
        raise BakeError("geo.inc.c has no %s_area_1_geo" % script)
    block = m.group(0)
    close = block.rfind(TAB + "GEO_CLOSE_NODE(),")
    block = block[:close] + TAB + TAB + "GEO_BRANCH(1, %s),\n" % lv.branch + block[close:]
    if lv.scene is not None and getattr(lv.scene, "ground", False):
        floor = "GEO_DISPLAY_LIST(LAYER_OPAQUE, %s)" % (TILES_GROUND_DL % script)
        if block.count(floor) != 1:
            raise BakeError("geo.inc.c draws The Tiles' floor %d times, not once"
                            % block.count(floor))
        block = block.replace(floor, "GEO_DISPLAY_LIST(LAYER_OPAQUE, %s)"
                              % ground_hide_name(lv.key))
    text = text[:m.start()] + block + text[m.end():]
    far = "100, %d, geo_camera_fov)" % FRUSTUM_FAR_BASE
    if far not in text:
        raise BakeError("geo.inc.c has no frustum at %d" % FRUSTUM_FAR_BASE)
    return text.replace(far, "100, %d, geo_camera_fov)" % FAR)
STATIC_FILE = "static.inc.c"
def source_files(files, lv, script, bare=False):
    out = dict(files)
    col = "area_1/collision.inc.c"
    geo = "area_1/geo.inc.c"
    out[col] = collision_source(out[col], lv)
    out[geo] = geo_source(out[geo], lv, script)
    head = "" if bare else (
        "/* The venue's still pieces, baked into its level (tools/venuebake.py) -\n"
        "   written by tools/make-venue-levels.py; edit the venue, not this file. */\n")
    out[STATIC_FILE] = head + "\n".join(lv.source)
    if getattr(lv, "rooms", None):
        base = split_collision(collision_words(files[col]))[0]
        out[ROOMS_FILE] = rooms_source(lv.key, level_rooms(base, lv), bare)
        line = "\t\tTERRAIN(%s_area_1_collision),\n" % script
        if "script.c" in out:
            if out["script.c"].count(line) != 1:
                raise BakeError("script.c has no one TERRAIN line")
            out["script.c"] = out["script.c"].replace(
                line, line + "\t\tROOMS(%s),\n" % rooms_name(lv.key))
    if getattr(lv, "warps", None) and "script.c" in out:
        anchor = "\t\tROOMS(%s),\n" % rooms_name(lv.key) if getattr(lv, "rooms", None) \
            else "\t\tTERRAIN(%s_area_1_collision),\n" % script
        if out["script.c"].count(anchor) != 1:
            raise BakeError("script.c has no one line to put the warps after")
        out["script.c"] = out["script.c"].replace(anchor, anchor + warp_lines(lv.pockets))
    include = '#include "levels/%s/%s"\n' % (script, STATIC_FILE)
    if getattr(lv, "rooms", None) and "leveldata.inc.c" in out:
        rinc = '#include "levels/%s/%s"\n' % (script, ROOMS_FILE)
        if rinc not in out["leveldata.inc.c"]:
            out["leveldata.inc.c"] = out["leveldata.inc.c"].rstrip("\n") + "\n" + rinc
    if "leveldata.inc.c" in out and include not in out["leveldata.inc.c"]:
        out["leveldata.inc.c"] = out["leveldata.inc.c"].rstrip("\n") + "\n" + include
    decl = "extern const GeoLayout %s[];\nextern Gfx %s[];\n" % (lv.branch, static_dl_name(lv.key))
    if "header.inc.h" in out and decl not in out["header.inc.h"]:
        out["header.inc.h"] = out["header.inc.h"].rstrip("\n") + "\n" + decl
    return out
GBI = {
    "G_IM_FMT_RGBA": 0, "G_IM_SIZ_16b": 2, "G_TX_LOADTILE": 7, "G_TX_RENDERTILE": 0,
    "G_TX_WRAP": 0, "G_TX_NOMIRROR": 0, "G_TX_CLAMP": 2, "G_TX_MIRROR": 1,
    "G_ON": 1, "G_OFF": 0, "G_LIGHTING": G_LIGHTING, "G_FOG": G_FOG,
    "G_LIGHTING_ENGINE_EXT": G_LIGHTING_ENGINE_EXT,
    "G_RM_AA_ZB_OPA_SURF": 0x00442078, "G_RM_AA_ZB_OPA_SURF2": 0x00112078,
    "G_RM_AA_ZB_XLU_SURF": 0x004049D8, "G_RM_AA_ZB_XLU_SURF2": 0x001049D8,
    "LAYER_OPAQUE": LAYER_OPAQUE, "LAYER_TRANSPARENT": LAYER_TRANSPARENT,
    "G_SHADE": G_SHADE, "G_CULL_FRONT": G_CULL_FRONT, "G_CULL_BACK": G_CULL_BACK,
    "G_SHADING_SMOOTH": G_SHADING_SMOOTH, "G_CYC_1CYCLE": 0, "G_AC_NONE": 0,
    "G_RM_FOG_SHADE_A": 0xC8000000, "G_BL_A_MEM": 1,
}
_CCMUX = {"TEXEL0": 1, "SHADE": 4, "0": 31}
_ACMUX = {"TEXEL0": 1, "SHADE": 4, "0": 7}
CC_MODES = {"G_CC_MODULATERGB": ("TEXEL0", "0", "SHADE", "0", "0", "0", "0", "SHADE"),
            "G_CC_SHADE": ("0", "0", "0", "SHADE", "0", "0", "0", "SHADE")}
def _sl(v, s, w):
    return (int(v) & ((1 << w) - 1)) << s
def gbi_combine(c0, c1):
    a0, b0, cc0, d0, Aa0, Ab0, Ac0, Ad0 = c0
    a1, b1, cc1, d1, Aa1, Ab1, Ac1, Ad1 = c1
    C, A = _CCMUX, _ACMUX
    w0 = (_sl(C[a0], 20, 4) | _sl(C[cc0], 15, 5) | _sl(A[Aa0], 12, 3) | _sl(A[Ac0], 9, 3)
          | _sl(C[a1], 5, 4) | _sl(C[cc1], 0, 5))
    w1 = (_sl(C[b0], 28, 4) | _sl(C[d0], 15, 3) | _sl(A[Ab0], 12, 3) | _sl(A[Ad0], 9, 3)
          | _sl(C[b1], 24, 4) | _sl(A[Aa1], 21, 3) | _sl(A[Ac1], 18, 3) | _sl(C[d1], 6, 3)
          | _sl(A[Ab1], 3, 3) | _sl(A[Ad1], 0, 3))
    return (0xFC << 24) | (w0 & 0xFFFFFF), w1
def gbi_settile(fmt, siz, line, tmem, tile, palette, cmt, maskt, shiftt, cms, masks, shifts):
    return ((0xF5 << 24) | _sl(fmt, 21, 3) | _sl(siz, 19, 2) | _sl(line, 9, 9) | _sl(tmem, 0, 9),
            _sl(tile, 24, 3) | _sl(palette, 20, 4) | _sl(cmt, 18, 2) | _sl(maskt, 14, 4)
            | _sl(shiftt, 10, 4) | _sl(cms, 8, 2) | _sl(masks, 4, 4) | _sl(shifts, 0, 4))
def gbi_tile_cmd(op, tile, uls, ult, lrs, lrt):
    return (op << 24) | _sl(uls, 12, 12) | _sl(ult, 0, 12), _sl(tile, 24, 3) | _sl(lrs, 12, 12) | _sl(lrt, 0, 12)
def gbi_texture(s, t, level, tile, on):
    return (0xD7 << 24) | _sl(level, 11, 3) | _sl(tile, 8, 3) | _sl(on, 1, 7), _sl(s, 16, 16) | _sl(t, 0, 16)
def gbi_othermode(cmd, sft, length, data):
    return (cmd << 24) | _sl(32 - sft - length, 8, 8) | _sl(length - 1, 0, 8), data & 0xFFFFFFFF
def gbi_tri(a, b, c):
    return _sl(a * 2, 16, 8) | _sl(b * 2, 8, 8) | _sl(c * 2, 0, 8)
def dynos_tokens(text):
    out = {}
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    for m in re.finditer(r"(?:ALIGNED8\s+)?(?:static\s+)?(?:const\s+)?(\w+)\s+(\w+)\s*\[\s*\d*\s*\]\s*=", text):
        start = m.end()
        end = text.index(";", start)
        tokens, tok, depth = [], "", 0
        for ch in text[start:end + 1]:
            if ch == "(":
                depth += 1
            if ch in " \t\r\n":
                continue
            if depth <= 1 and ch in "(),{};":
                if tok:
                    tokens.append(tok)
                    tok = ""
            else:
                tok += ch
            if ch == ")":
                depth -= 1
        out[m.group(2)] = (m.group(1), tokens)
    return out
def _arg(tok):
    def one(part):
        if part in GBI:
            return GBI[part]
        if re.match(r"^-?0x[0-9a-fA-F]+$", part):
            return int(part, 16)
        return int(part)
    total = 0
    for part in tok.split("|"):
        if "<<" in part:
            a, b = part.split("<<")
            total |= one(a) << one(b)
        else:
            total |= one(part)
    return total
def _gfx(tokens, where):
    out = []
    k = 0
    while k < len(tokens):
        sym = tokens[k]
        k += 1
        def take(n):
            nonlocal k
            got = tokens[k:k + n]
            k += n
            return got
        if sym in ("gsDPPipeSync", "gsDPLoadSync", "gsDPTileSync", "gsSPEndDisplayList"):
            out.append(({"gsDPPipeSync": 0xE7, "gsDPLoadSync": 0xE6, "gsDPTileSync": 0xE8,
                         "gsSPEndDisplayList": 0xDF}[sym] << 24, 0))
        elif sym == "gsDPSetCycleType":
            out.append(gbi_othermode(G_SETOTHERMODE_H, 20, 2, _arg(take(1)[0])))
        elif sym == "gsDPSetAlphaCompare":
            out.append(gbi_othermode(G_SETOTHERMODE_L, 0, 2, _arg(take(1)[0])))
        elif sym == "gsSPFogFactor":
            fm, fo = (_arg(t) for t in take(2))
            out.append(cmd_fog_factor(fm, fo))
        elif sym == "gsDPSetFogColor":
            out.append(cmd_fog_colour(*(_arg(t) for t in take(4))))
        elif sym == "gsDPSetRenderMode":
            a, b = take(2)
            out.append(gbi_othermode(G_SETOTHERMODE_L, 3, 29, _arg(a) | _arg(b)))
        elif sym == "gsSPGeometryMode":
            c, s = (_arg(t) for t in take(2))
            out.append(((G_GEOMETRYMODE << 24) | (~c & 0xFFFFFF), s))
        elif sym == "gsDPSetCombineMode":
            a, b = take(2)
            out.append(gbi_combine(CC_MODES[a], CC_MODES[b]))
        elif sym == "gsSPTexture":
            out.append(gbi_texture(*(_arg(t) for t in take(5))))
        elif sym == "gsDPSetTile":
            out.append(gbi_settile(*(_arg(t) for t in take(12))))
        elif sym == "gsDPSetTileSize":
            out.append(gbi_tile_cmd(0xF2, *(_arg(t) for t in take(5))))
        elif sym == "gsDPLoadBlock":
            out.append(gbi_tile_cmd(0xF3, *(_arg(t) for t in take(5))))
        elif sym == "gsDPSetTextureImage":
            fmt, siz, width, tex = take(4)
            out.append(((0xFD << 24) | _sl(_arg(fmt), 21, 3) | _sl(_arg(siz), 19, 2)
                        | _sl(_arg(width) - 1, 0, 12), ("ptr", tex, 0)))
        elif sym == "gsSPDisplayList":
            out.append((G_DL << 24, ("ptr", take(1)[0], 0)))
        elif sym in ("gsSPVertex", "gsSPVertexNonGlobal"):
            ref, n, v0 = take(3)
            name, _, off = ref.partition("+")
            n, v0 = _arg(n), _arg(v0)
            op = G_VTX if sym == "gsSPVertex" else G_VTX_EXT
            out.append(((op << 24) | _sl(n, 12, 8) | _sl(v0 + n, 1, 7),
                        ("ptr", name, int(off) if off else 0)))
        elif sym == "gsSP1Triangle":
            a, b, c, _ = (_arg(t) for t in take(4))
            out.append((0x05000000 | gbi_tri(a, b, c), 0))
        elif sym == "gsSP2Triangles":
            a, b, c, _, d, e, f, _ = (_arg(t) for t in take(8))
            out.append((0x06000000 | gbi_tri(a, b, c), gbi_tri(d, e, f)))
        else:
            raise BakeError("%s: the model compiler does not read %s" % (where, sym))
    return out
def _geo(tokens, where):
    out = []
    k = 0
    while k < len(tokens):
        sym = tokens[k]
        k += 1
        if sym == "GEO_NODE_START":
            out.append(GEO_START)
        elif sym == "GEO_OPEN_NODE":
            out.append(GEO_OPEN)
        elif sym == "GEO_CLOSE_NODE":
            out.append(GEO_CLOSE)
        elif sym == "GEO_RETURN":
            out.append(GEO_RETURN)
        elif sym == "GEO_TRANSLATE_NODE":
            layer, x, y, z = (_arg(t) for t in tokens[k:k + 4])
            k += 4
            out += [_bbh(0x11, layer, x), _hh(y, z)]
        elif sym == "GEO_CULLING_RADIUS":
            out.append(_bbh(GEO_CULLING_RADIUS, 0, _arg(tokens[k])))
            k += 1
        elif sym == "GEO_RENDER_RANGE":
            lo, hi = (_arg(t) for t in tokens[k:k + 2])
            k += 2
            out += [_bbh(0x0D, 0, 0), _hh(lo, hi)]
        elif sym == "GEO_DISPLAY_LIST":
            layer = _arg(tokens[k])
            out += [_bbh(GEO_DISPLAY_LIST, layer, 0), ("ptr", tokens[k + 1], 0)]
            k += 2
        elif sym == "GEO_SWITCH_CASE":
            if tokens[k + 1] != "geo_switch_area":
                raise BakeError("%s: a switch on %s" % (where, tokens[k + 1]))
            out += [_bbh(GEO_SWITCH, 0, _arg(tokens[k])), ("fn", GEO_SWITCH_AREA)]
            k += 2
        elif sym == "GEO_BILLBOARD_WITH_PARAMS_AND_DL":
            layer, x, y, z = (_arg(t) for t in tokens[k:k + 4])
            out += [_bbh(GEO_BILLBOARD, layer | 0x80, x), _hh(y, z), ("ptr", tokens[k + 4], 0)]
            k += 5
        else:
            raise BakeError("%s: the model compiler does not read %s" % (where, sym))
    return out
def _vtx(tokens):
    out = []
    for k in range(0, len(tokens) - 9, 10):
        x, y, z, flag, s, t, r, g, b, a = (int(float(v)) for v in tokens[k:k + 10])
        out.append(struct.pack("<3hH2h4B", x, y, z, flag & 0xFFFF, s, t, r & 0xFF, g & 0xFF,
                               b & 0xFF, a & 0xFF))
    return out
def parse_static(text, read_file, where="static.inc.c"):
    out = {}
    for name, (kind, tokens) in dynos_tokens(text).items():
        if kind == "Gfx":
            out[name] = (DATA_TYPE_DISPLAY_LIST, _gfx(tokens, where))
        elif kind == "Vtx":
            out[name] = (DATA_TYPE_VERTEX, _vtx(tokens))
        elif kind == "Texture":
            m = re.match(r'#include"(.+)\.inc\.c"', tokens[0])
            if m is None:
                raise BakeError("%s: %s is not a texture include" % (where, name))
            rel = m.group(1).split("/", 1)[1] + ".png"
            out[name] = (DATA_TYPE_TEXTURE, ("png", read_file(rel)))
        elif kind == "GeoLayout":
            out[name] = (DATA_TYPE_GEO_LAYOUT, _geo(tokens, where))
        else:
            raise BakeError("%s: %s is a %s, not a type the bake writes" % (where, name, kind))
    return out
def load_order(parsed, root):
    order, seen = [], set()
    def visit(name):
        if name in seen:
            return
        seen.add(name)
        kind, data = parsed[name]
        words = []
        if kind == DATA_TYPE_DISPLAY_LIST:
            for w0, w1 in data:
                words += [w0, w1]
        elif kind == DATA_TYPE_GEO_LAYOUT:
            words = data
        for w in words:
            if isinstance(w, tuple) and w[0] == "ptr" and w[1] in parsed:
                visit(w[1])
        order.append(name)
    visit(root)
    return order
def collision_words(text):
    names = dict((v, k) for k, v in SURFACE_NAMES.items())
    names["SURFACE_DEATH_PLANE"] = 0x000A
    tokens = list(dynos_tokens(text).values())[0][1]
    out = []
    k = 0
    while k < len(tokens):
        sym = tokens[k]
        k += 1
        if sym == "COL_INIT":
            out.append(TERRAIN_LOAD_VERTICES)
        elif sym in ("COL_VERTEX_INIT", "COL_WATER_BOX_INIT"):
            if sym == "COL_WATER_BOX_INIT":
                out.append(TERRAIN_LOAD_ENVIRONMENT)
            out.append(int(tokens[k]))
            k += 1
        elif sym in ("COL_VERTEX", "COL_TRI"):
            out += [int(t) for t in tokens[k:k + 3]]
            k += 3
        elif sym == "COL_TRI_INIT":
            out += [names[tokens[k]] if tokens[k] in names else int(tokens[k], 0), int(tokens[k + 1])]
            k += 2
        elif sym == "COL_TRI_STOP":
            out.append(TERRAIN_LOAD_CONTINUE)
        elif sym == "COL_WATER_BOX":
            out += [int(t) for t in tokens[k:k + 6]]
            k += 6
        elif sym == "COL_END":
            out.append(TERRAIN_LOAD_END)
        else:
            raise BakeError("collision.inc.c: the model compiler does not read %s" % sym)
    return out
def source_faults(body, folder_text, read_file, key, script):
    faults = []
    nodes = read_nodes(body)
    baked = [(k, n, d) for k, n, d in nodes if baked_name(key, n) and k != DATA_TYPE_ROOMS]
    try:
        parsed = parse_static(folder_text(STATIC_FILE), read_file)
    except (BakeError, ValueError, KeyError, IndexError) as why:
        return ["static.inc.c does not compile: %s" % why]
    root = bake_geo_name(key)
    if root not in parsed:
        return ["static.inc.c has no %s" % root]
    order = load_order(parsed, root)
    if [n for _, n, _ in baked] != order:
        faults.append("the .lvl's baked nodes are not in the order DynOS writes them from the source")
    for kind, name, data in baked:
        want = parsed.get(name)
        if want is None:
            faults.append("%s is in the .lvl and not in the source" % name)
        elif write_nodes([(kind, name, data)]) != write_nodes([(want[0], name, want[1])]):
            faults.append("%s differs between the .lvl and the source" % name)
    extra = set(parsed) - set(n for _, n, _ in baked)
    if extra:
        faults.append("the source has nodes the .lvl does not: %s" % ", ".join(sorted(extra)[:3]))
    col = [d for k, n, d in nodes if k == DATA_TYPE_COLLISION and n.endswith("_area_1_collision")]
    try:
        cwords = collision_words(folder_text("area_1/collision.inc.c"))
    except (BakeError, ValueError, KeyError, IndexError) as why:
        cwords = None
        faults.append("area_1/collision.inc.c does not compile: %s" % why)
    if cwords is not None and (not col or cwords != col[0]):
        faults.append("the collision differs between the .lvl and area_1/collision.inc.c")
    rnodes = [(n, d) for k, n, d in nodes if k == DATA_TYPE_ROOMS]
    if rnodes:
        name, data = rnodes[0]
        try:
            got = dynos_tokens(folder_text(ROOMS_FILE)).get(name)
            values = bytes(int(t) for t in got[1]) if got else None
        except (BakeError, ValueError, KeyError, IndexError, OSError, TypeError):
            values = None
        if values != bytes(data):
            faults.append("the rooms differ between the .lvl and %s" % ROOMS_FILE)
        try:
            script_text = folder_text("script.c")
        except (OSError, KeyError):
            script_text = ""
        if "ROOMS(%s)" % name not in script_text:
            faults.append("script.c does not hand the area its rooms")
    geo = folder_text("area_1/geo.inc.c")
    if "GEO_BRANCH(1, %s)" % root not in geo:
        faults.append("area_1/geo.inc.c does not branch to %s" % root)
    if "100, %d, geo_camera_fov" % FAR not in geo:
        faults.append("area_1/geo.inc.c keeps the base's far plane")
    return faults
VIEW_HALF = 50.0
VIEW_SPOTS = 32
VIEW_TURNS = 8
CELL_BORDER = 50
_measured = {}
def collision_cells(sections):
    cells = {}
    size = 1024
    for verts, groups in sections:
        for _, tris in groups:
            for t in tris:
                a, b, c = (verts[i] for i in t[:3])
                n = _cross(_sub3(b, a), _sub3(c, b))
                ln = math.sqrt(_dot(n, n)) or 1.0
                ny = n[1] / ln
                kind = 1 if ny > 0.01 else (None if ny < -0.01 else 0)
                if kind is None:
                    continue
                x0, x1 = min(a[0], b[0], c[0]) - CELL_BORDER, max(a[0], b[0], c[0]) + CELL_BORDER
                z0, z1 = min(a[2], b[2], c[2]) - CELL_BORDER, max(a[2], b[2], c[2]) + CELL_BORDER
                for i in range(int(math.floor(x0 / size)), int(math.floor(x1 / size)) + 1):
                    for j in range(int(math.floor(z0 / size)), int(math.floor(z1 / size)) + 1):
                        cells.setdefault((i, j), [0, 0])[kind] += 1
    return cells
def in_view(chunks, spots):
    best, where = 0, None
    tris = [tuple(sum(len(t) for _, _, _, t in part) for part in ch.parts()) for ch in chunks]
    half = math.radians(VIEW_HALF)
    for sx, sy, sz in spots:
        for k in range(VIEW_TURNS):
            a = 2 * math.pi * k / VIEW_TURNS
            fx, fz = math.sin(a), -math.cos(a)
            total = 0
            for ch, (n0, n1, n2) in zip(chunks, tris):
                dx, dz = ch.centre[0] - sx, ch.centre[2] - sz
                dist = math.hypot(dx, dz)
                n = n0 + n1
                if dist <= ch.radius:
                    total += n
                    continue
                if dist - ch.radius > FAR:
                    continue
                off = math.acos(max(-1.0, min(1.0, (dx * fx + dz * fz) / dist)))
                if off - math.asin(min(1.0, ch.radius / dist)) <= half:
                    total += n
            if total > best:
                best, where = total, (int(sx), int(sz), int(round(math.degrees(a))))
    return best, where
def view_of(sc, spots):
    cases = getattr(sc, "cases", None)
    rooms = getattr(sc, "rooms", None)
    if not cases or rooms is None:
        return in_view(sc.chunks, spots)
    by_room = {}
    for spot in spots:
        by_room.setdefault(rooms.room_at(*spot), []).append(spot)
    best = (0, None)
    for room in sorted(by_room):
        got = in_view([sc.chunks[k] for k in cases[room - 1]], by_room[room])
        if got[0] > best[0]:
            best = got
    return best
def _signature(arena):
    import json
    keep = dict((k, arena.get(k)) for k in ("pieces", "look", "level", "spawns", "terrain",
                                            "texture_cap"))
    return json.dumps(keep, sort_keys=True, default=str)
def measure(arena, levels=None, shade=True):
    sig = (_signature(arena), shade)
    if sig in _measured:
        return _measured[sig]
    import zlib
    arena = dict(arena)
    arena.setdefault("key", "measure")
    arena["_generated"] = True
    lv = compile_level(arena, shade=shade)
    out = dict(lv.stats)
    cells = collision_cells(lv.sections)
    worst = max(cells.items(), key=lambda kv: (kv[1][0] + kv[1][1], kv[0]), default=None)
    walls = max(cells.items(), key=lambda kv: (kv[1][0], kv[0]), default=None)
    floors = max(cells.items(), key=lambda kv: (kv[1][1], kv[0]), default=None)
    out["worst_walls"] = (walls[1][0], (walls[0][0] * 1024 + 512, walls[0][1] * 1024 + 512)) \
        if walls else (0, None)
    out["worst_floors"] = (floors[1][1], (floors[0][0] * 1024 + 512, floors[0][1] * 1024 + 512)) \
        if floors else (0, None)
    out["worst_cell"] = worst[1] if worst else [0, 0]
    sc = lv.scene
    spots = [(s["x"], s.get("y", 0), s["z"]) for s in (arena.get("spawns") or [])][:VIEW_SPOTS]
    if not spots:
        spots = [tuple(ch.centre) for ch in sc.chunks[:VIEW_SPOTS]]
    out["view"] = view_of(sc, spots)
    reach = 0
    for ch in sc.chunks:
        for v in ch.vertices + (ch.far.vertices if ch.far else []):
            reach = max(reach, abs(v[0] + ch.centre[0]), abs(v[2] + ch.centre[2]))
    out["reach"] = reach
    info = arenas_tool().LEVELS.get(arena.get("level") or "empty2") or {}
    open_ = liquid_rims(prepared(arena), lv.collision, lv.terrain, info.get("floor"))
    out["liquid_open"] = (len(open_), (open_[0][1], open_[0][3]) if open_ else None)
    levels = levels or os.path.join(os.path.dirname(HERE), "levels")
    base = arena.get("level") or "empty2"
    try:
        spec = importlib.util.spec_from_file_location("venuebake_levels",
                                                      os.path.join(HERE, "make-venue-levels.py"))
        tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tool)
        body = tool.rename_body(tool.read_lvl(os.path.join(levels, "level_%s_entry.lvl" % base)),
                                base, lv.script)
        body = bake_body(body, lv, lv.script)
        out["lvl_bytes"] = 16 + len(zlib.compress(body, 9))
    except (OSError, SystemExit, BakeError) as why:
        out["lvl_bytes"] = None
        out["lvl_why"] = str(why)
    if len(_measured) > 4:
        _measured.clear()
    _measured[sig] = out
    return out
