#!/usr/bin/env python3
import json
import os
import re
import struct
import sys
import zlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(HERE, "blocks-manifest.txt")
ACTORS = os.path.join(ROOT, "actors")
SPAWNER = os.path.join(ROOT, "of_spawner.lua")
MAGIC = b"DYNOSBIN"
POINTER, FUNCTION, LUA_VAR = 0x52544E50, 0x434E5546, 0x5641554C
TEX_REF = 0x52584554
PNG_SIG = b"\x89PNG\r\n\x1a\n"
BEGIN = "-- BEGIN BLOCKS (written by tools/make-blocks.py from tools/blocks-manifest.txt - edit the manifest, not these lines)"
END = "-- END BLOCKS"
TILE = 32
TILES = (32, 64)
SOFT64 = "assets-incoming/1006/textures/"
SOFT64_HI = SOFT64 + "hi/"
SHELVES = ["Stone", "Cut stone and marble", "Brick", "Wood", "Logs and bark", "Roof", "Metal",
           "Earth and grass",
           "Plants", "Snow and ice", "Desert", "Volcanic", "Water", "Tiles", "Crystal", "Fabric",
           "Special", "Blocks", "Small brick",
           "Wood sets: oak, birch", "Wood sets: pine, dark oak", "Wood sets: jungle, acacia, mangrove",
           "Wood sets: cherry, bamboo", "Wood sets: mystic, ghost",
           "Windows and doors", "Facades", "Roofs of the world", "Paths and edging",
           "Garden plants", "Market and props"]
FIELDS = ("shapes", "key", "was", "roles", "drawn")
class Refused(Exception):
    pass
def unpack_bin(data, where):
    if data[:8] != MAGIC:
        raise Refused("%s: not a compressed DynOS bin" % where)
    length = struct.unpack_from("<Q", data, 8)[0]
    raw = zlib.decompress(data[16:])
    if len(raw) != length:
        raise Refused("%s: length %d, header says %d" % (where, len(raw), length))
    return raw
def pack_bin(raw):
    return MAGIC + struct.pack("<Q", len(raw)) + zlib.compress(raw, 9)
def walk(raw, where):
    pieces = []
    i = 0
    vertices = []
    textures = 0
    geo_roots = []
    def take(n):
        nonlocal i
        if i + n > len(raw):
            raise Refused("%s: runs off the end at %d" % (where, i))
        chunk = raw[i:i + n]
        i += n
        return chunk
    def name():
        size = take(1)[0]
        pieces.append(("name", take(size).decode("ascii")))
        return pieces[-1][1]
    def u32():
        chunk = take(4)
        pieces.append(chunk)
        return struct.unpack("<I", chunk)[0]
    def reference(value):
        if value == POINTER:
            name()
            u32()
        elif value == FUNCTION:
            u32()
        elif value == LUA_VAR:
            name()
    while i < len(raw):
        kind = take(1)
        pieces.append(kind)
        kind = kind[0]
        node = name()
        if kind == 1:
            pieces.append(take(24))
        elif kind == 2:
            count_bytes = take(4)
            count = struct.unpack("<i", count_bytes)[0]
            if count == TEX_REF:
                raise Refused("%s: texture %s is a reference" % (where, node))
            png = take(count)
            if png[:8] != PNG_SIG:
                raise Refused("%s: texture %s is not a PNG" % (where, node))
            pieces.append(("png", png))
            textures += 1
        elif kind == 3:
            count = u32()
            for _ in range(count):
                chunk = take(16)
                pieces.append(chunk)
                vertices.append(struct.unpack("<3h", chunk[:6]))
        elif kind == 4:
            for _ in range(u32()):
                u32()
                reference(u32())
        elif kind == 5:
            geo_roots.append(node)
            for _ in range(u32()):
                reference(u32())
        else:
            raise Refused("%s: node type %d is not part of a plain cube"
                          % (where, kind))
    if textures != 1:
        raise Refused("%s: %d textures, a block wears exactly one"
                      % (where, textures))
    if not geo_roots:
        raise Refused("%s: no geo layout" % where)
    return pieces, vertices, geo_roots[-1]
def emit(pieces):
    out = bytearray()
    for piece in pieces:
        if isinstance(piece, tuple) and piece[0] == "name":
            text = piece[1].encode("ascii")
            if len(text) > 255:
                raise Refused("name too long: %s" % piece[1])
            out += bytes([len(text)]) + text
        elif isinstance(piece, tuple) and piece[0] == "png":
            out += struct.pack("<i", len(piece[1])) + piece[1]
        else:
            out += piece
    return bytes(out)
def template_prefix(geo_root, where):
    if not geo_root.endswith("geo"):
        raise Refused("%s: geo root %s does not end in geo" % (where, geo_root))
    return geo_root[:-3]
def dress(pieces, prefix, block_prefix, png):
    out = []
    for piece in pieces:
        if isinstance(piece, tuple) and piece[0] == "name":
            text = piece[1]
            if text.startswith(prefix):
                text = block_prefix + text[len(prefix):]
            out.append(("name", text))
        elif isinstance(piece, tuple) and piece[0] == "png":
            out.append(("png", png))
        else:
            out.append(piece)
    return out
HI_INDEX = SOFT64_HI + "hi.json"
def hi_twin(rel):
    if rel.startswith(SOFT64) and not rel.startswith(SOFT64_HI):
        return SOFT64_HI + rel[len(SOFT64):]
    return None
def hi_index():
    try:
        with open(os.path.join(ROOT, HI_INDEX), encoding="utf-8") as handle:
            table = json.load(handle)
    except OSError:
        return None
    return {row["file"] for row in table.values()
            if isinstance(row, dict) and isinstance(row.get("file"), str)}
def shipped_texture(path):
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    hi = hi_twin(rel)
    if hi is not None:
        full = os.path.join(ROOT, hi)
        if os.path.isfile(full):
            return read_texture(full)
        index = hi_index()
        if index is None:
            raise Refused("%s has no %s: the 64 px twins are missing, so this build would "
                          "draw every Soft 64 block (%s first) at 32 px - not built"
                          % (ROOT, HI_INDEX, rel))
        if hi[len(SOFT64):] in index:
            raise Refused("%s is missing (%s names it): %s would be drawn at 32 px - not built"
                          % (hi, HI_INDEX, rel))
    return read_texture(path)
def read_texture(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if path.endswith(".tex"):
        if data[:1] != b"\x02":
            raise Refused("%s: not a PNG texture node" % path)
        size = data[1]
        count = struct.unpack_from("<i", data, 2 + size)[0]
        data = data[6 + size:6 + size + count]
    if data[:8] != PNG_SIG:
        raise Refused("%s: not a PNG" % path)
    return data
def png_pixels(png, where):
    i = 8
    width = height = None
    idat = b""
    while i < len(png):
        length = struct.unpack(">I", png[i:i + 4])[0]
        tag = png[i + 4:i + 8]
        body = png[i + 8:i + 8 + length]
        if tag == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or colour not in (2, 6) or interlace != 0:
                raise Refused("%s: depth %d colour %d interlace %d - re-save it as"
                              " plain 8-bit RGBA" % (where, depth, colour, interlace))
            channels = 4 if colour == 6 else 3
        elif tag == b"IDAT":
            idat += body
        i += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    rows = []
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        kind = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for x in range(stride):
            left = line[x - channels] if x >= channels else 0
            up = previous[x]
            corner = previous[x - channels] if x >= channels else 0
            if kind == 1:
                line[x] = (line[x] + left) & 255
            elif kind == 2:
                line[x] = (line[x] + up) & 255
            elif kind == 3:
                line[x] = (line[x] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                pred = left if pa <= pb and pa <= pc else (up if pb <= pc else corner)
                line[x] = (line[x] + pred) & 255
        rows.append([tuple(line[x:x + channels]) + ((255,) if channels == 3 else ())
                     for x in range(0, stride, channels)])
        previous = line
    return width, height, rows
def vet_texture(png, where):
    width, height, rows = png_pixels(png, where)
    if width != height or width not in TILES:
        raise Refused("%s: %dx%d, a block face is %dx%d (or its %dx%d twin)"
                      % (where, width, height, TILE, TILE, TILES[-1], TILES[-1]))
    see_through = sum(1 for row in rows for px in row if px[3] < 250)
    if see_through:
        raise Refused("%s: %d see-through texels, a block is solid"
                      % (where, see_through))
    return tuple(px for row in rows for px in row)
def slug(name):
    text = re.sub(r"[^a-z0-9]", "", name.lower())
    if not text:
        raise Refused("block name %r has no letters" % name)
    return text
def read_manifest(path=MANIFEST):
    template = None
    rows = []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.startswith("template:"):
                template = line.split(":", 1)[1].strip()
                continue
            if line.startswith("long:"):
                continue
            parts = [part.strip() for part in line.split("|")]
            named = {}
            while len(parts) > 3 and "=" in parts[-1]:
                field, _, value = parts.pop().partition("=")
                field, value = field.strip(), value.strip()
                if field not in FIELDS or field in named:
                    raise Refused("manifest line %d: %r is not a field (%s)"
                                  % (number, field, ", ".join(f + "=" for f in FIELDS)))
                named[field] = value
            if named.get("drawn") not in (None, "runtime"):
                raise Refused("manifest line %d: drawn=%s - only drawn=runtime"
                              % (number, named["drawn"]))
            if len(parts) not in (3, 4) or not all(parts):
                raise Refused("manifest line %d: want 'Shelf | Block name | "
                              "source file' and optionally '| swatch'" % number)
            if len(parts) == 4 and parts[3] == "-":
                parts = parts[:3]
            shelf, name, source = parts[:3]
            layers = None
            if "+" in source:
                layers = [part.strip() for part in source.split("+")]
                if len(layers) != 3 or not all(layers):
                    raise Refused("manifest line %d: a transition block is "
                                  "'top + side + bottom'" % number)
                source = layers[0]
            swatch = parts[3] if len(parts) == 4 else None
            if swatch is not None and not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", swatch):
                raise Refused("manifest line %d: swatch %r is not a texture name"
                              % (number, swatch))
            if shelf not in SHELVES:
                raise Refused("manifest line %d: shelf %r is not one of %s"
                              % (number, shelf, ", ".join(SHELVES)))
            key = named.get("key") or slug(name)
            if not re.match(r"^[a-z0-9]+$", key):
                raise Refused("manifest line %d: key %r is not lower-case letters "
                              "and digits" % (number, key))
            was = [w.strip() for w in named.get("was", "").split(",") if w.strip()]
            for old in was:
                if not re.match(r"^[a-z0-9]+$", old) or old == key:
                    raise Refused("manifest line %d: was=%r is not an old key"
                                  % (number, old))
            rows.append({"shelf": shelf, "name": name, "source": source,
                         "slug": key, "line": number, "swatch": swatch,
                         "layers": layers, "shapes": named.get("shapes"),
                         "drawn": named.get("drawn"),
                         "was": was, "roles": tuple(r.strip() for r in
                                                    named["roles"].split(",") if r.strip())
                         if "roles" in named else None})
    if template is None:
        raise Refused("the manifest names no template:")
    seen = {}
    for row in rows:
        for name in [row["slug"]] + row["was"]:
            if name in seen:
                raise Refused("manifest lines %d and %d are both %r"
                              % (seen[name], row["line"], name))
            seen[name] = row["line"]
    return template, rows
def manifest_from(folder):
    lines = []
    for entry in sorted(os.listdir(folder)):
        if entry.lower().endswith((".png", ".tex")):
            source = os.path.relpath(os.path.join(folder, entry), ROOT)
            lines.append("Blocks | %s | %s" % (os.path.splitext(entry)[0], source))
    for shelf in SHELVES:
        where = os.path.join(folder, shelf)
        if not os.path.isdir(where):
            continue
        for entry in sorted(os.listdir(where)):
            if entry.lower().endswith((".png", ".tex")):
                source = os.path.relpath(os.path.join(where, entry), ROOT)
                lines.append("%s | %s | %s" % (shelf, os.path.splitext(entry)[0], source))
    unknown = [d for d in sorted(os.listdir(folder))
               if os.path.isdir(os.path.join(folder, d)) and d not in SHELVES]
    if unknown:
        raise Refused("folders that are not shelves: %s (shelves are %s)"
                      % (", ".join(unknown), ", ".join(SHELVES)))
    with open(MANIFEST, encoding="utf-8") as handle:
        head = [line for line in handle
                if line.startswith("#") or line.startswith("template:")]
    with open(MANIFEST, "w", encoding="utf-8") as handle:
        handle.writelines(head)
        handle.write("\n")
        handle.write("\n".join(lines) + "\n")
def geo_name(row):
    return "of_blk_%s_geo" % row["slug"]
def own_swatch(row):
    return "of_blk_%s_texture" % row["slug"]
BUILTIN_TEX = os.environ.get(
    "OF_BUILTIN_TEX",
    "/workspace/coop-deluxe/sm64coopdx/data/dynos_mgr_builtin_tex.cpp")
def check_swatches(rows):
    named = [row for row in rows if row.get("swatch")]
    if not named or not os.path.exists(BUILTIN_TEX):
        return "not checked (no %s)" % BUILTIN_TEX if named else "none"
    sizes = {}
    pattern = re.compile(r'define_builtin_tex_?\((\w+), "[^"]+", (\d+), (\d+)')
    with open(BUILTIN_TEX, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            found = pattern.search(line)
            if found:
                sizes[found.group(1)] = (int(found.group(2)), int(found.group(3)))
    for row in named:
        size = sizes.get(row["swatch"])
        if size is None:
            raise Refused("manifest line %d: swatch %r is not in the engine's "
                          "builtin texture table" % (row["line"], row["swatch"]))
        if any(side & (side - 1) for side in size):
            raise Refused("manifest line %d: swatch %r is %dx%d, not a power of two"
                          % (row["line"], row["swatch"], size[0], size[1]))
    return "%d in the engine's table" % len(named)
def build():
    template_path, rows = read_manifest()
    check_swatches(rows)
    stale_template(template_path)
    where = os.path.relpath(os.path.join(ROOT, template_path), ROOT)
    with open(os.path.join(ROOT, template_path), "rb") as handle:
        raw = unpack_bin(handle.read(), where)
    pieces, vertices, root = walk(raw, where)
    if emit(pieces) != raw:
        raise Refused("%s: the walk does not give the file back" % where)
    prefix = template_prefix(root, where)
    spans = [max(v[k] for v in vertices) - min(v[k] for v in vertices)
             for k in range(3)]
    if len(set(spans)) != 1:
        raise Refused("%s: %s is not a cube" % (where, spans))
    width = spans[0]
    floor = min(v[1] for v in vertices)
    files = {}
    faces = {}
    for row in rows:
        source = os.path.join(ROOT, row["source"])
        png = shipped_texture(source)
        pixels = vet_texture(png, row["source"])
        same = (pixels,) if not row["layers"] else tuple(
            vet_texture(shipped_texture(os.path.join(ROOT, layer)), layer) for layer in row["layers"])
        if same in faces:
            raise Refused("%s and %s are the same picture"
                          % (faces[same], row["name"]))
        faces[same] = row["name"]
        name = geo_name(row)
        if row["layers"]:
            files[name + ".bin"] = layered_cube(raw, where, name[:-3], row)
            continue
        if "water" in (row.get("roles") or ()):
            files[name + ".bin"] = water_cube(raw, where, name[:-3], png)
            continue
        copy = dress(pieces, prefix, name[:-3], png)
        files[name + ".bin"] = pack_bin(emit(copy))
    lua = [BEGIN,
           "-- The cube every block is a copy of, measured off its vertices:"
           " %d units on every axis," % width,
           "-- standing on its own origin (lowest vertex at y = %d)." % floor,
           "local BLOCK_WIDTH = %d" % width,
           "local BLOCK_SHELVES = {"]
    for shelf in SHELVES:
        mine = [row for row in rows if row["shelf"] == shelf]
        if not mine:
            continue
        lua.append('    { name = "%s", blocks = {' % shelf)
        for row in mine:
            swatch = ', tex = "%s"' % (row["swatch"] or own_swatch(row))
            runtime = ", layered = true" if row["layers"] else ""
            if row.get("drawn") == "runtime":
                runtime += ', runtime = "%s"' % ",".join(sorted(runtime_shapes(row)))
            lua.append('        { key = "blk%s", name = "%s", geo = "%s"%s%s },'
                       % (row["slug"], row["name"].replace('"', ''), geo_name(row),
                          swatch, runtime))
        lua.append("    } },")
    lua.append("}")
    lua.append("local BLOCK_WAS = {")
    for row in rows:
        for old in row["was"]:
            lua.append('    ["%s"] = "%s",' % (old, row["slug"]))
    lua.append("}")
    lua.append(END)
    return files, "\n".join(lua) + "\n", len(rows)
def stale_template(template_path):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "make_cube_template", os.path.join(HERE, "make-cube-template.py"))
    cube = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cube)
    if os.path.normpath(os.path.join(ROOT, template_path)) != os.path.normpath(cube.OUT):
        raise Refused("the manifest's template is %s, not the generated %s"
                      % (template_path, os.path.relpath(cube.OUT, ROOT)))
    why = cube.stale()
    if why:
        raise Refused(why)
def runtime_shapes(row):
    if "slopes" not in _SLOPES:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "make_forgeslopes", os.path.join(HERE, "make-forgeslopes.py"))
        slopes = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(slopes)
        _SLOPES["slopes"] = slopes
    return _SLOPES["slopes"].shape_set(row)
_SLOPES = {}
def water_cube(raw, where, prefix, png):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "make_forgeslopes", os.path.join(HERE, "make-forgeslopes.py"))
    slopes = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slopes)
    try:
        nodes = slopes.read_nodes(raw, where)
        nodes = [[2, n[1], [("png", png)]] if n[0] == 2 else n for n in nodes]
        nodes = slopes.water_look(nodes)
    except slopes.Refused as why:
        raise Refused(str(why))
    template = slopes.TEMPLATE_PREFIX
    def rename(label):
        return prefix + label[len(template):] if label.startswith(template) else label
    return pack_bin(slopes.write_nodes(nodes, rename))
def layered_cube(raw, where, prefix, row):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "make_forgeslopes", os.path.join(HERE, "make-forgeslopes.py"))
    slopes = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slopes)
    pngs = []
    for source in row["layers"]:
        png = shipped_texture(os.path.join(ROOT, source))
        vet_texture(png, source)
        pngs.append(png)
    try:
        return slopes.layered_cube(slopes.read_nodes(raw, where), prefix, pngs)
    except slopes.Refused as why:
        raise Refused(str(why))
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
    start = text.find(BEGIN)
    stop = text.find(END)
    if start < 0 or stop < 0 or stop < start or text.count(BEGIN) != 1:
        raise Refused("of_spawner.lua has no single BLOCKS region")
    stop += len(END) + 1
    return text[:start] + block + text[stop:]
def main(argv):
    check = "--check" in argv
    if "--manifest-from" in argv:
        manifest_from(argv[argv.index("--manifest-from") + 1])
    try:
        files, block, count = build()
    except Refused as why:
        print("make-blocks: %s" % why)
        return 1
    with open(SPAWNER, encoding="utf-8") as handle:
        text = handle.read()
    try:
        wanted = luaregion().finish(spliced(text, block),
                                   os.path.dirname(os.path.abspath(SPAWNER)))
    except Refused as why:
        print("make-blocks: %s" % why)
        return 1
    stale = sorted(name for name in os.listdir(ACTORS)
                   if name.startswith("of_blk_") and name not in files)
    differ = []
    for name, data in sorted(files.items()):
        path = os.path.join(ACTORS, name)
        have = None
        if os.path.exists(path):
            with open(path, "rb") as handle:
                have = handle.read()
        if have != data:
            differ.append(name)
    if check:
        faults = []
        if differ:
            faults.append("%d actor(s) out of date, first %s" % (len(differ), differ[0]))
        if stale:
            faults.append("%d actor(s) the manifest no longer names, first %s"
                          % (len(stale), stale[0]))
        if wanted != text:
            faults.append("the BLOCKS table in of_spawner.lua is out of date")
        if faults:
            print("make-blocks: " + "; ".join(faults))
            print("run tools/make-blocks.py to rebuild them")
            return 1
        print("make-blocks: %d blocks, all current" % count)
        return 0
    for name in differ:
        with open(os.path.join(ACTORS, name), "wb") as handle:
            handle.write(files[name])
    for name in stale:
        os.remove(os.path.join(ACTORS, name))
    if wanted != text:
        with open(SPAWNER, "w", encoding="utf-8") as handle:
            handle.write(wanted)
    size = sum(len(data) for data in files.values())
    print("make-blocks: %d blocks, %d bytes of actors; %d written, %d removed"
          % (count, size, len(differ), len(stale)))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
