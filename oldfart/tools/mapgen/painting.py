import importlib.util
import math
import os
TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 192
SCALE = 2
PITCH = 16.0
FRAMES = {"garden": "bob", "castle": "wf", "ice": "ccm", "lava": "lll", "desert": "wdw",
          "sky": "ttm", "wood": "thi", "water": "jrb"}
_faces = None
def faces():
    global _faces
    if _faces is None:
        path = os.path.join(TOOLS, "make-painting-faces.py")
        spec = importlib.util.spec_from_file_location("make_painting_faces", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _faces = mod
    return _faces
def frame_for(theme):
    return FRAMES.get(theme or "garden", "bob")
def tex_name(key, half):
    return "ofmap_pnt_%s_%s" % (key, half)
def camera(arena):
    from .render import raster
    import numpy as np
    lo, hi = raster.bounds(arena)
    centre = (lo + hi) / 2.0
    spawns = arena.get("spawns") or []
    if spawns:
        s = spawns[0]
        yaw = math.atan2(centre[0] - s.get("x", 0), centre[2] - s.get("z", 0))
    else:
        yaw = math.radians(45)
    radius = max(800.0, float(np.linalg.norm((hi - lo)[[0, 2]])) / 2.0)
    fov = raster.FOV
    dist = radius / math.tan(math.radians(fov) / 2.0) * 0.78
    p = math.radians(PITCH)
    back = np.array((-math.sin(yaw) * math.cos(p), math.sin(p), -math.cos(yaw) * math.cos(p)))
    target = centre.copy()
    target[1] = lo[1] + (hi[1] - lo[1]) * 0.35
    return raster.Camera(target + back * dist, target, fov)
TRIBLOCK = "make-triblock.py"
def modpack_vb():
    from . import modpack
    return modpack.tool("make-venue-levels.py").venuebake()
class Paint:
    def __init__(self, arena):
        from .render import levelview
        from . import autolight, modpack
        self.layout = arena
        drawn = with_movers(arena)
        self.sc = levelview.scene_of(drawn)
        self.arena = getattr(self.sc, "arena", None) or drawn
        self.tris = with_objects(levelview.triangles(self.sc), arena)
        look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
        self.sky = look.get("sky") or None
        try:
            worn, _ = modpack.resolve_look(arena, [])
        except Exception:
            worn = {}
        try:
            self.sky_tint = modpack.worn_sky_tint(arena)
        except Exception:
            self.sky_tint = (look.get(autolight.SKY_TINT_FIELD)
                             or autolight.sky_tint(look.get("mood"), self.sky))
        from .render import gamesky
        self.sky_picture = gamesky.picture(self.sky)
        tint = worn.get("tint")
        self.tint = tuple(float(c) / 255.0 for c in tint) if tint else None
        self.theme = look.get("theme") or arena.get("theme")
        self.frame = frame_for(self.theme)
        from . import romobjects
        self.vanilla = romobjects.placed(arena)
        self.rom = romobjects.root() if self.vanilla else None
        self.rom_missing = bool(self.vanilla) and self.rom is None
def with_movers(arena):
    rows = arena.get("movers") or []
    if not rows:
        return arena
    from . import modpack, movers
    out = dict(arena)
    pieces = list(arena.get("pieces") or [])
    for raw in rows:
        try:
            mv = movers.normalise(raw)
            block = modpack.mover_block(mv["key"])
        except Exception:
            continue
        if block is None:
            continue
        _shape, _tex, piece = block
        piece = dict(piece, x=mv["x"], y=mv["y"], z=mv["z"], yaw=mv.get("yaw", 0) or 0,
                     tag="paint.mover")
        pieces.append(piece)
    out["pieces"] = pieces
    return out
_triblock = None
def _triblock_tool():
    global _triblock
    if _triblock is None:
        path = os.path.join(TOOLS, TRIBLOCK)
        spec = importlib.util.spec_from_file_location("make_triblock", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _triblock = mod
    return _triblock
def triblock_faces():
    t = _triblock_tool()
    hw, d, h = t.WIDE / 2.0, float(t.DEEP), float(t.TALL)
    pink, side, back = ([c / 255.0 for c in col[:3]] for col in (t.PINK, t.SIDE, t.BACK))
    A, B = (-hw, 0.0, d), (hw, 0.0, d)
    C, D = (hw, h, 0.0), (-hw, h, 0.0)
    E, F = (-hw, 0.0, 0.0), (hw, 0.0, 0.0)
    return [((A, B, C), pink), ((A, C, D), pink),
            ((E, A, D), side), ((F, C, B), side),
            ((E, D, C), back), ((E, C, F), back)]
def with_objects(tris, arena):
    import numpy as np
    from .render import levelview
    objs = [o for o in arena.get("objects") or [] if isinstance(o, dict)
            and o.get("key") == "triblock"]
    if not objs:
        return tris
    P, UV, C, N, T, keys = tris
    keys = list(keys)
    if levelview.FLAT not in keys:
        keys.append(levelview.FLAT)
    flat = keys.index(levelview.FLAT)
    faces = triblock_faces()
    pts, cols, nrm = [], [], []
    for o in objs:
        r = math.radians(float(o.get("yaw", 0) or 0))
        c, s = math.cos(r), math.sin(r)
        at = np.array((float(o.get("x", 0)), float(o.get("y", 0)), float(o.get("z", 0))))
        for corners, rgb in faces:
            w = [at + np.array((x * c + z * s, y, -x * s + z * c)) for x, y, z in corners]
            n = np.cross(w[1] - w[0], w[2] - w[0])
            n = n / max(1e-9, np.linalg.norm(n))
            pts.append(w)
            cols.append([rgb] * 3)
            nrm.append(n)
    n = len(pts)
    return (np.concatenate([P, np.array(pts, np.float64)]),
            np.concatenate([UV, np.zeros((n, 3, 2))]),
            np.concatenate([C, np.array(cols, np.float64)]),
            np.concatenate([N, np.array(nrm, np.float64)]),
            np.concatenate([T, np.full(n, flat, np.int32)]), keys)
def merged(tris, more):
    if more is None:
        return tris
    import numpy as np
    P, UV, C, N, T, keys = tris
    P2, UV2, C2, N2, T2, keys2 = more
    return (np.concatenate([P, P2]), np.concatenate([UV, UV2]), np.concatenate([C, C2]),
            np.concatenate([N, N2]), np.concatenate([T, T2 + len(keys)]),
            list(keys) + list(keys2))
def draw(paint, cam, size=SIZE):
    from .render import levelview
    from . import romobjects
    w = h = size * 2
    tris = merged(paint.tris, romobjects.triangles(paint.vanilla, cam, paint.rom))
    img = levelview.render(paint.sc, cam, size=(w, h), sky=paint.sky,
                           sky_tint=paint.sky_tint, tint=paint.tint, tris=tris,
                           sky_picture=getattr(paint, "sky_picture", None))
    return img.convert("RGB").resize((size, size))
def source(layout, size=SIZE):
    from . import paintpick
    ctx = paintpick.Context(layout, prepared=True)
    cam = paintpick.camera_of(layout.get(paintpick.FIELD)) or paintpick.best(ctx).cam
    return draw(ctx.paint, cam, size)
def halves(picture, frame="bob", k=SCALE, stylised=True):
    from PIL import Image
    top, bottom = faces().halves_from(picture, frame, k, stylised)
    return Image.fromarray(top), Image.fromarray(bottom)
def png_bytes(img):
    import io
    out = io.BytesIO()
    img.save(out, "PNG")
    return out.getvalue()
def for_layout(layout, k=SCALE):
    try:
        pic = source(layout)
    except Exception:
        return None
    look = layout.get("look") if isinstance(layout.get("look"), dict) else {}
    theme = look.get("theme") or layout.get("theme")
    return halves(pic, frame_for(theme), k)
def tex_bytes(name, png):
    import struct
    raw = name.encode("ascii")
    return bytes([2, len(raw)]) + raw + struct.pack("<i", len(png)) + png
def export_files(layout, key, k=SCALE):
    pair = for_layout(layout, k)
    if pair is None:
        return {}, None
    files, names = {}, {}
    for half, img in zip(("top", "bottom"), pair):
        name = tex_name(key, half)
        files["textures/%s.tex" % name] = tex_bytes(name, png_bytes(img))
        names[half] = name
    return files, names
