import base64
import json
import math
import os
import struct
import zlib
from ..core import meshes, textures
GENERATOR = "Oldfart Studio glTF exchange"
NEAREST, REPEAT = 9728, 10497
FLOAT, UINT = 5126, 5125
ARRAY_BUFFER = 34962
PIECE_FIELDS = ("kind", "tex", "x", "y", "z", "w", "h", "d", "yaw")
def png_bytes(width, height, rgba):
    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    rows = b"".join(b"\x00" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))
def yaw_quat(deg):
    h = math.radians(deg) / 2.0
    return [0.0, math.sin(h), 0.0, math.cos(h)]
def quat_yaw(q):
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    vertical = abs(x) < 1e-4 and abs(z) < 1e-4
    return math.degrees(2.0 * math.atan2(y, w)) % 360.0, vertical
class _Buffer:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []
    def view(self, raw, target=None):
        while len(self.data) % 4:
            self.data += b"\x00"
        v = {"buffer": 0, "byteOffset": len(self.data), "byteLength": len(raw)}
        if target:
            v["target"] = target
        self.data += raw
        self.views.append(v)
        return len(self.views) - 1
    def floats(self, values, width, kind):
        raw = struct.pack("<%df" % len(values), *values)
        acc = {"bufferView": self.view(raw, ARRAY_BUFFER), "componentType": FLOAT,
               "count": len(values) // width, "type": kind}
        if kind == "VEC3":
            cols = [values[i::3] for i in range(3)]
            acc["min"] = [min(c) for c in cols]
            acc["max"] = [max(c) for c in cols]
        self.accessors.append(acc)
        return len(self.accessors) - 1
def _piece_primitives(piece, registry, scale):
    mesh = meshes.build(meshes.mesh_key(piece))
    layers = registry.layers_for(piece)
    out = {}
    v = mesh.vertices
    for i in range(0, len(v), meshes.VERTEX_FLOATS):
        p, n = (v[i], v[i + 1], v[i + 2]), (v[i + 3], v[i + 4], v[i + 5])
        layer, ramp = int(v[i + 6]), v[i + 7] > 0.5
        q = meshes.scaled(p, piece)
        m = (n[0] / max(piece["w"], 1e-6), n[1] / max(piece["h"], 1e-6),
             n[2] / max(piece["d"], 1e-6))
        ln = math.sqrt(sum(c * c for c in m)) or 1.0
        s, t = meshes.face_uv(p, n, piece, ramp)
        pos, nor, uv = out.setdefault(layers[layer], ([], [], []))
        pos += [q[0] * scale, q[1] * scale, q[2] * scale]
        nor += [m[0] / ln, m[1] / ln, m[2] / ln]
        uv += [s, t]
    return out
def build(pieces, markers=(), scale=0.01, registry=None, name="map"):
    registry = registry or textures.Registry()
    buf = _Buffer()
    gl = {"asset": {"version": "2.0", "generator": GENERATOR},
          "scene": 0, "scenes": [{"name": name, "nodes": []}], "nodes": [], "meshes": [],
          "materials": [], "textures": [], "images": [], "buffers": [],
          "samplers": [{"magFilter": NEAREST, "minFilter": NEAREST,
                        "wrapS": REPEAT, "wrapT": REPEAT}],
          "extras": {"oldfart": {"scale": scale, "units": "game units x scale"}}}
    material_of = {}
    def material(layer):
        if layer in material_of:
            return material_of[layer]
        label, px = registry.layers[layer]
        img = png_bytes(textures.SIZE, textures.SIZE, px)
        gl["images"].append({"name": label, "mimeType": "image/png",
                             "bufferView": buf.view(img)})
        gl["textures"].append({"source": len(gl["images"]) - 1, "sampler": 0})
        gl["materials"].append({"name": label, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": len(gl["textures"]) - 1},
            "metallicFactor": 0.0, "roughnessFactor": 1.0}})
        material_of[layer] = len(gl["materials"]) - 1
        return material_of[layer]
    for i, piece in enumerate(pieces):
        prims = []
        for layer, (pos, nor, uv) in sorted(_piece_primitives(piece, registry, scale).items()):
            prims.append({"attributes": {"POSITION": buf.floats(pos, 3, "VEC3"),
                                         "NORMAL": buf.floats(nor, 3, "VEC3"),
                                         "TEXCOORD_0": buf.floats(uv, 2, "VEC2")},
                          "material": material(layer)})
        label = "%03d %s %s" % (i, piece["kind"], piece.get("tex", ""))
        gl["meshes"].append({"name": label, "primitives": prims})
        keep = {k: piece[k] for k in piece if k != "model"}
        gl["nodes"].append({"name": label, "mesh": len(gl["meshes"]) - 1,
                            "translation": [piece["x"] * scale, piece["y"] * scale,
                                            piece["z"] * scale],
                            "rotation": yaw_quat(piece.get("yaw", 0)),
                            "extras": {"oldfart": {"piece": keep}}})
        gl["scenes"][0]["nodes"].append(len(gl["nodes"]) - 1)
    for j, m in enumerate(markers):
        gl["nodes"].append({"name": "%s %s" % (m.kind, m.label or j + 1),
                            "translation": [m.x * scale, m.y * scale, m.z * scale],
                            "rotation": yaw_quat(m.yaw or 0),
                            "extras": {"oldfart": {"marker": m.kind,
                                                   "data": m.data if isinstance(m.data, dict)
                                                   else None}}})
        gl["scenes"][0]["nodes"].append(len(gl["nodes"]) - 1)
    gl["bufferViews"] = buf.views
    gl["accessors"] = buf.accessors
    gl["buffers"] = [{"byteLength": len(buf.data)}]
    for k in ("textures", "images", "materials"):
        if not gl[k]:
            del gl[k]
    return gl, bytes(buf.data)
def export(pieces, markers, path, scale=0.01, registry=None, name="map"):
    gl, data = build(pieces, markers, scale, registry, name)
    if path.lower().endswith(".glb"):
        js = json.dumps(gl, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        data += b"\x00" * (-len(data) % 4)
        out = (struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(data)) +
               struct.pack("<II", len(js), 0x4E4F534A) + js +
               struct.pack("<II", len(data), 0x004E4942) + data)
        with open(path, "wb") as f:
            f.write(out)
    else:
        gl["buffers"][0]["uri"] = "data:application/octet-stream;base64," + \
            base64.b64encode(data).decode()
        with open(path, "w", encoding="utf-8") as f:
            json.dump(gl, f, indent=1)
    return path
class Imported:
    def __init__(self):
        self.pieces = []
        self.spawns = []
        self.notes = []
        self.refused = []
def load_json(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:4] == b"glTF":
        length, kind = struct.unpack_from("<II", raw, 12)
        if kind != 0x4E4F534A:
            raise ValueError("%s: a .glb whose first chunk is not JSON" % path)
        return json.loads(raw[20:20 + length].decode("utf-8"))
    return json.loads(raw.decode("utf-8"))
def _walk(gl):
    nodes = gl.get("nodes") or []
    scene = (gl.get("scenes") or [{}])[gl.get("scene", 0)]
    roots = scene.get("nodes") or list(range(len(nodes)))
    out = []
    def visit(i, t, yaw, s, vertical):
        n = nodes[i]
        lt = n.get("translation", [0.0, 0.0, 0.0])
        ly, lv = quat_yaw(n.get("rotation", [0.0, 0.0, 0.0, 1.0]))
        ls = n.get("scale", [1.0, 1.0, 1.0])
        if "matrix" in n:
            lv = False
        c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        x, y, z = lt[0] * s[0], lt[1] * s[1], lt[2] * s[2]
        wt = (t[0] + x * c + z * sn, t[1] + y, t[2] - x * sn + z * c)
        ws = [s[k] * ls[k] for k in range(3)]
        out.append((n, wt, (yaw + ly) % 360.0, ws, vertical and lv))
        for ch in n.get("children") or []:
            visit(ch, wt, (yaw + ly) % 360.0, ws, vertical and lv)
    for r in roots:
        visit(r, (0.0, 0.0, 0.0), 0.0, [1.0, 1.0, 1.0], True)
    return out
def _extras(node):
    e = node.get("extras") or {}
    o = e.get("oldfart")
    if isinstance(o, str):
        try:
            o = json.loads(o)
        except ValueError:
            o = None
    return o if isinstance(o, dict) else {}
def read(path, scale=None):
    gl = load_json(path)
    if scale is None:
        scale = ((gl.get("extras") or {}).get("oldfart") or {}).get("scale", 0.01)
    imp = Imported()
    for node, t, yaw, s, vertical in _walk(gl):
        o = _extras(node)
        name = node.get("name", "?")
        if "piece" in o:
            p = dict(o["piece"])
            if not all(k in p for k in PIECE_FIELDS):
                imp.refused.append("%s: its piece data is incomplete" % name)
                continue
            if not vertical:
                imp.refused.append("%s: turned about a tilted axis - pieces turn only about "
                                   "the vertical; kept as it was" % name)
                imp.pieces.append(p)
                continue
            q = round(yaw / 90.0) * 90 % 360
            if abs((yaw - q + 180) % 360 - 180) > 0.5:
                imp.refused.append("%s: turned by %.1f degrees - the kit turns by quarter turns "
                                   "only; kept at %d" % (name, yaw, p.get("yaw", 0)))
                q = p.get("yaw", 0)
            new = dict(p, x=round(t[0] / scale, 2), y=round(t[1] / scale, 2),
                       z=round(t[2] / scale, 2), yaw=int(q))
            for k, axis in (("w", 0), ("h", 1), ("d", 2)):
                new[k] = round(p[k] * abs(s[axis]), 2)
            imp.pieces.append(new)
        elif "marker" in o:
            if o["marker"] == "spawn":
                d = dict(o.get("data") or {})
                d.update(x=round(t[0] / scale, 2), y=round(t[1] / scale, 2),
                         z=round(t[2] / scale, 2), yaw=int(round(yaw)) % 360)
                imp.spawns.append(d)
        elif node.get("mesh") is not None:
            imp.refused.append("%s: a mesh made outside Oldfart Studio - the kit builds only its "
                               "own kinds (box, ramp, stairs, ...); place kit pieces instead"
                               % name)
    return imp
def _key(p):
    return tuple(p.get(k) for k in PIECE_FIELDS)
def merge(layout, imp):
    import copy
    old = [p for p in layout.get("pieces") or []]
    new = copy.deepcopy(layout)
    new["pieces"] = imp.pieces
    if imp.spawns:
        new["spawns"] = imp.spawns
    before = {}
    for p in old:
        before.setdefault((p["kind"], p.get("tex")), []).append(p)
    same = sum(1 for p in imp.pieces if _key(p) in {_key(q) for q in old})
    lines = ["%d pieces back (%d unchanged, %d changed or new), %d before"
             % (len(imp.pieces), same, len(imp.pieces) - same, len(old))]
    if len(imp.pieces) < len(old):
        lines.append("%d piece(s) removed in Blender" % (len(old) - len(imp.pieces)))
    lines += ["could not come back: %s" % r for r in imp.refused]
    return new, lines
