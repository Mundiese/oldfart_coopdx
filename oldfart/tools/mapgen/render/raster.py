import io
import math
import numpy as np
from . import gamelight as gl
from .. import kit, v1
SKY = (0.56, 0.70, 0.86)
WATER = (0.47, 0.64, 0.78)
NEAR = 20.0
FOV = 45.0
_tex_cache = {}
def _decode(png):
    from PIL import Image
    im = Image.open(io.BytesIO(png)).convert("RGB")
    return np.asarray(im, dtype=np.float32) / 255.0
def textures():
    if _tex_cache:
        return _tex_cache
    m = v1.arenas_module()
    _, rows = m.blocks.read_manifest()
    for row in rows:
        top, layers = m.slopes.row_textures(row)
        t = _decode(top)
        if layers:
            _tex_cache[row["slug"]] = (t, _decode(layers[0]), _decode(layers[1]))
        else:
            _tex_cache[row["slug"]] = (t, t, t)
        for old in row.get("was") or ():
            _tex_cache.setdefault(old, _tex_cache[row["slug"]])
    return _tex_cache
class Camera:
    def __init__(self, eye, target, fov=FOV):
        self.eye = np.array(eye, dtype=np.float64)
        self.target = np.array(target, dtype=np.float64)
        self.fov = fov
        fwd = self.target - self.eye
        fwd = fwd / max(1e-9, np.linalg.norm(fwd))
        self.back = -fwd
        right = np.cross(fwd, (0.0, 1.0, 0.0))
        if np.linalg.norm(right) < 1e-6:
            right = np.array((1.0, 0.0, 0.0))
        self.right = right / np.linalg.norm(right)
        self.up = np.cross(self.right, fwd)
    def axes(self):
        return tuple(self.right), tuple(self.up), tuple(self.back)
    def to_view(self, pts):
        d = pts - self.eye
        return np.stack([d @ self.right, d @ self.up, -(d @ self.back)], axis=-1)
class Frame:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.empty((h, w, 3), np.float32)
        self.rgb[:] = SKY
        self.depth = np.full((h, w), np.inf, np.float32)
        self.ids = np.full((h, w), -1, np.int32)
        self.tex = np.full((h, w), -1, np.int32)
        self.up = np.zeros((h, w), bool)
        self.flat = np.zeros((h, w), bool)
        self.upright = np.zeros((h, w), bool)
        self.shade = np.zeros((h, w), np.float32)
        self.textures = []
    @property
    def lum(self):
        return (0.2126 * self.rgb[..., 0] + 0.7152 * self.rgb[..., 1]
                + 0.0722 * self.rgb[..., 2])
    @property
    def sky(self):
        return self.ids < 0
    def image(self):
        from PIL import Image
        return Image.fromarray((np.clip(self.rgb, 0, 1) * 255).astype(np.uint8), "RGB")
def piece_faces(piece):
    m = v1.arenas_module()
    faces = m.solid(piece["kind"], piece=piece)
    size = (float(piece["w"]), float(piece["h"]), float(piece["d"]))
    r = math.radians(piece.get("yaw") or 0)
    c, s = math.cos(r), math.sin(r)
    out = []
    for pts, normal in faces:
        loc = np.array([(p[0] / 200.0 * size[0], p[1] / 200.0 * size[1], p[2] / 200.0 * size[2])
                        for p in pts], dtype=np.float64)
        world = np.stack([loc[:, 0] * c + loc[:, 2] * s + piece["x"],
                          loc[:, 1] + piece["y"],
                          -loc[:, 0] * s + loc[:, 2] * c + piece["z"]], axis=-1)
        out.append((world, normal, gl.real_normal(normal, size)))
    return out
def _clip_near(view, extra):
    out_v, out_e = [], []
    n = len(view)
    for i in range(n):
        a, b = view[i], view[(i + 1) % n]
        ea, eb = extra[i], extra[(i + 1) % n]
        ina, inb = a[2] >= NEAR, b[2] >= NEAR
        if ina:
            out_v.append(a)
            out_e.append(ea)
        if ina != inb:
            t = (NEAR - a[2]) / (b[2] - a[2])
            out_v.append(a + (b - a) * t)
            out_e.append(ea + (eb - ea) * t)
    return out_v, out_e
def render(arena, cam, size=(320, 180), skew=False, hour=None, shading=None, textured=True,
           extra=None, baked=False, lights=None):
    lights = lights or gl.CALIBRATED
    w, h = size
    fr = Frame(w, h)
    texs = textures() if textured else {}
    cols = None
    if not textured:
        cols = {k: np.array(v, np.float32) / 255.0 for k, v in kit.colours().items()}
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0)
    aspect = w / float(h)
    axes_cam = cam.axes()
    if hour is None:
        light = (arena.get("look") or {}).get("light")
        if isinstance(light, dict):
            light = light.get("dir")
        hour = tuple(light) if isinstance(light, (list, tuple)) and len(light) == 3 else None
    tex_index = {}
    bk = None
    if baked:
        from .. import bake as bakemod
        pal = bakemod.look_palette(arena.get("look") or {})
        if pal is not None:
            pal = bakemod.sun_palette(arena.get("look") or {})
            bk = (bakemod, bakemod.Grid(bakemod.rows_of(arena)), pal)
    from .. import decor
    pieces = decor.drawn(list(arena.get("pieces") or [])) + list(extra or [])
    ys, xs = np.mgrid[0:h, 0:w]
    px = xs.astype(np.float64) + 0.5
    py = ys.astype(np.float64) + 0.5
    for index, piece in enumerate(pieces):
        tex = piece.get("tex")
        if tex == "invisible":
            continue
        size3 = (float(piece["w"]), float(piece["h"]), float(piece["d"]))
        cf = gl.coeffs(axes_cam, gl.piece_axes(piece.get("yaw") or 0), size3, hour, skew,
                       lights)
        top_y = piece["y"] + piece["h"]
        ti = tex_index.setdefault(tex, len(tex_index))
        for world, n_unit, n_real in piece_faces(piece):
            nw = np.array(gl.real_normal(n_unit, size3))
            r = math.radians(piece.get("yaw") or 0)
            nw = np.array((nw[0] * math.cos(r) + nw[2] * math.sin(r), nw[1],
                           -nw[0] * math.sin(r) + nw[2] * math.cos(r)))
            if np.dot(nw, cam.eye - world[0]) <= 0:
                continue
            if piece.get("kind") == "water" or tex == "water":
                rgb_shade = None
            else:
                rgb_shade = np.array(gl.shade(n_real, cf, shading, lights),
                                     np.float32) / 255.0
            layer = 0 if nw[1] > 0.5 else (2 if nw[1] < -0.5 else 1)
            if abs(nw[1]) > 0.5:
                uv = np.stack([world[:, 0], world[:, 2]], -1) / 200.0
            else:
                tdir = np.array((nw[2], 0.0, -nw[0]))
                tdir /= max(1e-9, np.linalg.norm(tdir))
                uv = np.stack([world @ tdir, (top_y - world[:, 1])], -1) / 200.0
            if bk is not None and rgb_shade is not None:
                ext = max(float(np.linalg.norm(a_ - b_)) for a_ in world for b_ in world)
                cols3 = np.array([bk[0].colour(bk[1], bk[2], p_[0], p_[1], p_[2], nw[0], nw[1],
                                               nw[2], ext) for p_ in world], np.float64) / 255.0
                uv = np.concatenate([uv, cols3], axis=1)
            view = cam.to_view(world)
            vlist, ulist = _clip_near(list(view), list(uv))
            if len(vlist) < 3:
                continue
            V = np.array(vlist)
            U = np.array(ulist)
            sx = (V[:, 0] / V[:, 2] * f / aspect + 1.0) * 0.5 * w
            sy = (1.0 - V[:, 1] / V[:, 2] * f) * 0.5 * h
            inv = 1.0 / V[:, 2]
            for k in range(1, len(V) - 1):
                tri = (0, k, k + 1)
                x0, x1 = sx[list(tri)].min(), sx[list(tri)].max()
                y0, y1 = sy[list(tri)].min(), sy[list(tri)].max()
                ix0, ix1 = max(0, int(math.floor(x0))), min(w, int(math.ceil(x1)) + 1)
                iy0, iy1 = max(0, int(math.floor(y0))), min(h, int(math.ceil(y1)) + 1)
                if ix0 >= ix1 or iy0 >= iy1:
                    continue
                X = px[iy0:iy1, ix0:ix1]
                Y = py[iy0:iy1, ix0:ix1]
                (ax, ay), (bx, by), (cx, cy) = [(sx[i], sy[i]) for i in tri]
                area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
                if abs(area) < 1e-9:
                    continue
                w0 = ((bx - X) * (cy - Y) - (by - Y) * (cx - X)) / area
                w1 = ((cx - X) * (ay - Y) - (cy - Y) * (ax - X)) / area
                w2 = 1.0 - w0 - w1
                inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
                if not inside.any():
                    continue
                iz = w0 * inv[tri[0]] + w1 * inv[tri[1]] + w2 * inv[tri[2]]
                depth = 1.0 / np.maximum(iz, 1e-12)
                sub_d = fr.depth[iy0:iy1, ix0:ix1]
                win = inside & (depth < sub_d)
                if not win.any():
                    continue
                if rgb_shade is None:
                    colour = np.broadcast_to(np.array(WATER, np.float32), win.shape + (3,))
                    shade_v = 1.0
                elif textured and tex in texs:
                    img = texs[tex][layer]
                    th, tw = img.shape[:2]
                    uu = (w0 * U[tri[0], 0] * inv[tri[0]] + w1 * U[tri[1], 0] * inv[tri[1]]
                          + w2 * U[tri[2], 0] * inv[tri[2]]) * depth
                    vv = (w0 * U[tri[0], 1] * inv[tri[0]] + w1 * U[tri[1], 1] * inv[tri[1]]
                          + w2 * U[tri[2], 1] * inv[tri[2]]) * depth
                    ti_ = (np.floor(np.mod(uu, 1.0) * tw).astype(int)) % tw
                    tj_ = (np.floor(np.mod(vv, 1.0) * th).astype(int)) % th
                    colour = img[tj_, ti_] * rgb_shade
                    if U.shape[1] > 2:
                        vc = np.stack([(w0 * U[tri[0], 2 + c_] * inv[tri[0]]
                                        + w1 * U[tri[1], 2 + c_] * inv[tri[1]]
                                        + w2 * U[tri[2], 2 + c_] * inv[tri[2]]) * depth
                                       for c_ in range(3)], -1)
                        colour = img[tj_, ti_] * vc
                    shade_v = float(gl.grey(rgb_shade * 255.0)) / 255.0
                else:
                    base = (cols or {}).get(tex)
                    if base is None:
                        base = np.array((0.5, 0.5, 0.5), np.float32)
                    colour = np.broadcast_to(base * rgb_shade, win.shape + (3,))
                    shade_v = float(gl.grey(rgb_shade * 255.0)) / 255.0
                sub_d[win] = depth[win]
                fr.rgb[iy0:iy1, ix0:ix1][win] = colour[win]
                fr.ids[iy0:iy1, ix0:ix1][win] = index
                fr.tex[iy0:iy1, ix0:ix1][win] = ti
                fr.up[iy0:iy1, ix0:ix1][win] = nw[1] > 0.5
                fr.flat[iy0:iy1, ix0:ix1][win] = nw[1] > 0.999
                fr.upright[iy0:iy1, ix0:ix1][win] = abs(nw[1]) < 0.2
                fr.shade[iy0:iy1, ix0:ix1][win] = shade_v
    fr.textures = [t for t, _ in sorted(tex_index.items(), key=lambda kv: kv[1])]
    if bk is not None:
        from . import levelview
        arena_bk = dict(arena)
        arena_bk["pieces"] = list(arena.get("pieces") or []) + list(extra or [])
        pic = levelview.render(levelview.scene_of(arena_bk), cam, (w, h),
                               sky=(arena.get("look") or {}).get("sky"))
        fr.rgb = np.asarray(pic, np.float32) / 255.0
    return fr
def bounds(arena):
    lo = np.array([np.inf] * 3)
    hi = -lo
    pieces = arena.get("pieces") or []
    play = [p for p in pieces if not str(p.get("tag", "")).startswith("dress.backdrop")]
    for p in play or pieces:
        if p.get("tex") == "invisible":
            continue
        r = max(p["w"], p["d"]) / 2.0
        lo = np.minimum(lo, (p["x"] - r, p["y"], p["z"] - r))
        hi = np.maximum(hi, (p["x"] + r, p["y"] + p["h"], p["z"] + r))
    if not np.isfinite(lo).all():
        return np.zeros(3), np.zeros(3)
    return lo, hi
def far_cameras(arena, pitch=35.0, fov=FOV):
    lo, hi = bounds(arena)
    centre = (lo + hi) / 2.0
    radius = max(1000.0, float(np.linalg.norm(hi - lo)) / 2.0)
    dist = radius / math.tan(math.radians(fov) / 2.0) * 1.05
    corners = []
    for q in arena.get("pieces") or []:
        if q.get("tex") == "invisible" or str(q.get("tag", "")).startswith("dress.backdrop"):
            continue
        w, dd = q["w"], q["d"]
        if int(round(q.get("yaw") or 0)) % 180 == 90:
            w, dd = dd, w
        corners += [(q["x"] + sx * w / 2.0, q["y"] + sy * q["h"], q["z"] + sz * dd / 2.0)
                    for sx in (-1, 1) for sy in (0, 1) for sz in (-1, 1)]
    corners = np.array(corners or [tuple(lo), tuple(hi)], float)
    out = []
    for yaw in (45, 135, 225, 315):
        y, p = math.radians(yaw), math.radians(pitch)
        d = np.array((math.cos(p) * math.sin(y), math.sin(p), math.cos(p) * math.cos(y)))
        k = dist
        for _ in range(3):
            cam = Camera(centre + d * k, centre, fov)
            v = cam.to_view(corners)
            f = 1.0 / math.tan(math.radians(fov) / 2.0)
            ext = max(np.max(np.abs(v[:, 0] / v[:, 2])) * f / (16 / 9.0),
                      np.max(np.abs(v[:, 1] / v[:, 2])) * f)
            k = k * (0.55 + 0.45 * ext / 0.9)
        out.append(Camera(centre + d * k, centre, fov))
    return out
def _inside_any(arena, q, pad=0.0):
    for p in arena.get("pieces") or []:
        if p.get("tex") == "invisible" or p.get("kind") == "water":
            continue
        w, d = p["w"], p["d"]
        if int(round(p.get("yaw") or 0)) % 180 == 90:
            w, d = d, w
        if (abs(q[0] - p["x"]) <= w / 2.0 + pad and abs(q[2] - p["z"]) <= d / 2.0 + pad
                and p["y"] - pad <= q[1] <= p["y"] + p["h"] + pad):
            return True
    return False
def spawn_cameras(arena, limit=4, fov=FOV):
    lo, hi = bounds(arena)
    centre = (lo + hi) / 2.0
    spawns = list(arena.get("spawns") or [])
    if not spawns:
        return []
    picked = [spawns[0]]
    while len(picked) < min(limit, len(spawns)):
        picked.append(max((s for s in spawns if s not in picked),
                          key=lambda s: min(math.hypot(s["x"] - q["x"], s["z"] - q["z"])
                                            for q in picked)))
    out = []
    for s in picked:
        foot = np.array((s["x"], s["y"], s["z"]), float)
        if s.get("yaw") is not None:
            r = math.radians(float(s["yaw"]))
            d = np.array((math.sin(r), 0.0, math.cos(r)))
        else:
            d = centre - foot
            d[1] = 0.0
        n = np.linalg.norm(d)
        d = d / n if n > 1e-6 else np.array((0.0, 0.0, -1.0))
        head = foot + np.array((0.0, 160.0, 0.0))
        eye = foot - d * 1000.0 + np.array((0.0, 460.0, 0.0))
        for t in np.linspace(0.0, 1.0, 41)[1:]:
            q = head + (eye - head) * t
            if _inside_any(arena, q, 60.0):
                eye = head + (eye - head) * max(0.0, t - 0.05)
                if np.linalg.norm(eye - head) < 500.0:
                    eye = eye + np.array((0.0, 400.0, 0.0))
                break
        target = foot + d * 1500.0 + np.array((0.0, 220.0, 0.0))
        cam = Camera(eye, target, fov)
        cam.spawn = foot
        out.append(cam)
    return out
