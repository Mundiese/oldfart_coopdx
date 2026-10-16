import io
import math
import os
import sys
import numpy as np
from .raster import Camera, NEAR, FOV
TILES_GROUNDS = {"grass": "grass", "ice": "ice", "sand": "sand", "stone": "flagstone",
                 "snow": "snowblock", "wood": "woodenplank1"}
_TOOLS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def venuebake():
    if _TOOLS not in sys.path:
        sys.path.insert(0, _TOOLS)
    import venuebake as vb
    return vb
def scene_of(arena, shade=True):
    vb = venuebake()
    prep = vb.prepared(arena)
    static, _ = vb.split_rows(prep)
    sc = vb.scene(prep, static, shade=shade, terrain=vb.terrain_of(prep))
    sc.arena = prep
    return sc
_pictures = {}
_alphas = {}
FLAT = ("#flat", 0)
def picture(tex):
    if tex == FLAT:
        return np.ones((1, 1, 3), np.float32)
    if tex not in _pictures:
        from PIL import Image
        png = venuebake().texture_png(tex)
        im = Image.open(io.BytesIO(png)).convert("RGB")
        _pictures[tex] = np.asarray(im, dtype=np.float32) / 255.0
    return _pictures[tex]
def triangles(sc):
    vb = venuebake()
    pts, uvs, cols, nrm, tid = [], [], [], [], []
    keys = list(sc.textures)
    for ch in sc.chunks:
        cx, cy, cz = ch.centre
        for tex, first, count, tris in ch.loads:
            ti = keys.index(tex)
            for a, b, c in tris:
                vs = [ch.vertices[first + k] for k in (a, b, c)]
                pts.append([(v[0] + cx, v[1] + cy, v[2] + cz) for v in vs])
                uvs.append([(v[4] / 1024.0, v[5] / 1024.0) for v in vs])
                cols.append([(v[6] / 255.0, v[7] / 255.0, v[8] / 255.0) for v in vs])
                if ch.water:
                    nrm.append((float("nan"),) * 3)
                else:
                    nrm.append(vb.unpack_parts(vs[0][3], vs[0][9])[0])
                tid.append(ti)
    arena = getattr(sc, "arena", None) or {}
    if arena.get("level") == getattr(vb, "TILES_LEVEL", "empty") and not getattr(sc, "ground", None):
        slug = TILES_GROUNDS.get(arena.get("ground"), "flagstone")
        key = (slug, 0)
        if key not in keys:
            keys.append(key)
        r, k = getattr(vb, "TILES_REACH", 15000), 500.0
        corners = [(-r, 0, -r), (r, 0, -r), (r, 0, r), (-r, 0, r)]
        for tri in ((0, 2, 1), (0, 3, 2)):
            pts.append([corners[i] for i in tri])
            uvs.append([(corners[i][0] / k, corners[i][2] / k) for i in tri])
            cols.append([(0.86, 0.86, 0.86)] * 3)
            nrm.append((0.0, 1.0, 0.0))
            tid.append(keys.index(key))
    return (np.array(pts, np.float64).reshape(-1, 3, 3), np.array(uvs, np.float64).reshape(-1, 3, 2),
            np.array(cols, np.float64).reshape(-1, 3, 3), np.array(nrm, np.float64).reshape(-1, 3),
            np.array(tid, np.int32), keys)
def sky_colours(sky):
    from .. import skies
    top, low, _, _ = skies.LOOK.get(sky or "", skies.LOOK["BACKGROUND_OCEAN_SKY"])
    return np.array(top, np.float64) / 255.0, np.array(low, np.float64) / 255.0
def _clip(view, extra):
    out_v, out_e = [], []
    n = len(view)
    for i in range(n):
        a, b = view[i], view[(i + 1) % n]
        ea, eb = extra[i], extra[(i + 1) % n]
        if a[2] >= NEAR:
            out_v.append(a)
            out_e.append(ea)
        if (a[2] >= NEAR) != (b[2] >= NEAR):
            t = (NEAR - a[2]) / (b[2] - a[2])
            out_v.append(a + (b - a) * t)
            out_e.append(ea + (eb - ea) * t)
    return out_v, out_e
def glow_mask(sc, count):
    out = []
    for ch in sc.chunks:
        for _, _, _, tris in ch.loads:
            out += [bool(getattr(ch, "glow", False))] * len(tris)
    return np.array(out + [False] * (count - len(out)), bool)
def game_colours(sc, P, C, tint=None, ambient=None, live=None):
    if tint is None and ambient is None and not live:
        return C
    C = C.copy()
    keep = glow_mask(sc, len(C))
    if tint is not None:
        C[~keep] = C[~keep] * np.array(tint, np.float64)[None, None, :]
    if ambient is not None:
        C[~keep] = C[~keep] * (np.array(ambient, np.float64) / 255.0)[None, None, :]
    if live:
        pts = P[~keep]
        add = np.zeros(pts.shape, np.float64)
        for lx, ly, lz, lr, lg, lb, radius, inten in live:
            d = np.sqrt(((pts - np.array((lx, ly, lz), np.float64)) ** 2).sum(-1))
            k = np.clip(1.0 - d / float(radius), 0.0, 1.0) ** 2 * float(inten)
            add += k[..., None] * (np.array((lr, lg, lb), np.float64) / 255.0)[None, None, :]
        C[~keep] = np.clip(C[~keep] + add, 0.0, 1.0)
    return C
TOO_DARK = 0.16
TOO_BRIGHT = 0.92
HEAT_DARK = (0.15, 0.35, 1.0)
HEAT_BRIGHT = (1.0, 0.2, 0.15)
def heat_colours(sc, C):
    keep = glow_mask(sc, len(C))
    lum = C[..., 0] * 0.3 + C[..., 1] * 0.59 + C[..., 2] * 0.11
    out = np.repeat(lum[..., None], 3, axis=-1)
    dark = lum < TOO_DARK
    bright = lum > TOO_BRIGHT
    out[dark] = HEAT_DARK
    out[bright] = HEAT_BRIGHT
    out[keep] = C[keep]
    return out
def hour_look(layout, hour):
    if hour not in ("day", "dusk", "night"):
        return layout
    from .. import autolight
    out = dict(layout)
    look = dict(out.get("look") or {})
    mood = dict(look.get("mood") or {}) if isinstance(look.get("mood"), dict) else {}
    if hour == "day":
        mood.pop("darkness", None)
        if look.get("sky") in tuple(autolight.NIGHT_SKIES.values()) + (autolight.NIGHT_SKY,):
            look["sky"] = "BACKGROUND_OCEAN_SKY"
    else:
        mood["darkness"] = hour
        sky = look.get("sky") or "BACKGROUND_OCEAN_SKY"
        look["sky"] = autolight.night_sky(mood, sky) or sky
        tint = autolight.sky_tint(mood, look["sky"])
        if tint:
            look[autolight.SKY_TINT_FIELD] = list(tint)
    if hour == "day":
        look.pop(autolight.SKY_TINT_FIELD, None)
    look["mood"] = mood
    out["look"] = look
    return out
def game_light(sc):
    vb = venuebake()
    if not getattr(sc, "night", False):
        return None, None
    if not hasattr(vb, "DARK_AMBIENT"):
        return None, None
    live = [tuple(r[:8]) for r in vb.live_rows(getattr(sc, "lights", None) or [])]
    return (vb.DARK_AMBIENT,) * 3, live
def game_fog(layout):
    from . import gamefog
    return gamefog.look_fog((layout or {}).get("look"))
def sky_painted(sky, fog):
    zen, hor = sky_colours(sky)
    if fog is None:
        return zen, hor
    amount = max(0.0, min(1.0, (fog[2] - 1.0) / 0.4))
    k = np.array([1.0 - (1.0 - c) * amount for c in fog[3]], np.float64)
    return zen * k, hor * k
def _sky_multiplier(game, sky_tint):
    k = np.ones(3, np.float64)
    if game is not None:
        amount = max(0.0, min(1.0, (game[2] - 1.0) / 0.4))
        k = k * np.array([1.0 - (1.0 - c) * amount for c in game[3]], np.float64)
    if sky_tint:
        k = k * np.array([float(c) for c in sky_tint[:3]], np.float64) / 255.0
    return k
def render(sc, cam, size=(640, 360), sky=None, fog=0.0, fog_colour=None, tris=None, tint=None,
           only=None, ambient=None, live=None, game=None, sky_tint=None, sky_picture=None):
    from PIL import Image
    w, h = size
    P, UV, C, N, T, keys = tris if tris is not None else triangles(sc)
    C = game_colours(sc, P, C, tint=tint, ambient=ambient, live=live)
    if only is not None:
        sel = []
        for k, ch in enumerate(sc.chunks):
            for _, _, _, t in ch.loads:
                sel += [k in only] * len(t)
        sel = np.array(sel + [True] * (len(P) - len(sel)), bool)
        P, UV, C, N, T = P[sel], UV[sel], C[sel], N[sel], T[sel]
    pics = [picture(k) for k in keys]
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0)
    aspect = w / float(h)
    zen, hor = sky_painted(sky, game) if game is not None else sky_colours(sky)
    if sky_tint:
        k = np.array([float(c) for c in sky_tint[:3]], np.float64) / 255.0
        zen, hor = zen * k, hor * k
    if game is not None:
        from . import gamefog
        fog = 0.0
    ys = (np.arange(h) + 0.5) / h
    rays_up = (1.0 - 2.0 * ys) / f
    fwd = -np.array(cam.back)
    up = np.array(cam.up)
    elev = (fwd[1] + rays_up * up[1]) / np.sqrt(1.0 + rays_up ** 2)
    t = np.clip(elev / 0.6, 0.0, 1.0) ** 0.7
    rgb = np.empty((h, w, 3), np.float64)
    rgb[:] = (hor[None, :] * (1 - t[:, None]) + zen[None, :] * t[:, None])[:, None, :]
    if sky_picture is not None:
        from . import gamesky
        rgb[:] = gamesky.project(sky_picture, cam, w, h) * _sky_multiplier(game, sky_tint)
    depth = np.full((h, w), np.inf)
    fogc = hor if fog_colour is None else np.array(fog_colour, np.float64)
    V = (P - cam.eye) @ np.stack([cam.right, cam.up, -np.array(cam.back)], axis=1)
    eye = np.array(cam.eye)
    py, px = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    for i in range(len(P)):
        if not np.isnan(N[i, 0]) and np.dot(N[i], eye - P[i, 0]) <= 0:
            continue
        view = V[i]
        if (view[:, 2] < NEAR).all():
            continue
        ex = np.concatenate([UV[i], C[i]], axis=1)
        if game is not None:
            ex = np.concatenate([ex, gamefog.factors(view[:, 2], game[0], game[1], game[2])[:, None]],
                                axis=1)
        if (view[:, 2] < NEAR).any():
            vl, el = _clip(list(view), list(ex))
            if len(vl) < 3:
                continue
            vl, el = np.array(vl), np.array(el)
        else:
            vl, el = view, ex
        sx = (vl[:, 0] / vl[:, 2] * f / aspect + 1.0) * 0.5 * w
        sy = (1.0 - vl[:, 1] / vl[:, 2] * f) * 0.5 * h
        inv = 1.0 / vl[:, 2]
        pic = pics[T[i]]
        th, tw = pic.shape[:2]
        for k in range(1, len(vl) - 1):
            tri = (0, k, k + 1)
            xs, ys_ = sx[list(tri)], sy[list(tri)]
            ix0, ix1 = max(0, int(math.floor(xs.min()))), min(w, int(math.ceil(xs.max())) + 1)
            iy0, iy1 = max(0, int(math.floor(ys_.min()))), min(h, int(math.ceil(ys_.max())) + 1)
            if ix0 >= ix1 or iy0 >= iy1:
                continue
            X, Y = px[iy0:iy1, ix0:ix1], py[iy0:iy1, ix0:ix1]
            (ax, ay), (bx, by), (cx, cy) = zip(xs, ys_)
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
            d = 1.0 / np.maximum(iz, 1e-12)
            sub = depth[iy0:iy1, ix0:ix1]
            win = inside & (d < sub)
            if not win.any():
                continue
            def attr(j):
                return (w0 * el[tri[0], j] * inv[tri[0]] + w1 * el[tri[1], j] * inv[tri[1]]
                        + w2 * el[tri[2], j] * inv[tri[2]]) * d
            uu, vv = attr(0), attr(1)
            ti_ = np.floor(np.mod(uu, 1.0) * tw).astype(int) % tw
            tj_ = np.floor(np.mod(vv, 1.0) * th).astype(int) % th
            cut = _alphas.get(keys[T[i]])
            if cut is not None:
                win = win & (cut[tj_ % cut.shape[0], ti_ % cut.shape[1]] >= 0.5)
                if not win.any():
                    continue
            vc = np.stack([attr(2), attr(3), attr(4)], -1)
            col = pic[tj_, ti_] * vc
            if np.isnan(N[i, 0]):
                col = col * 0.55 + np.array((0.47, 0.64, 0.78)) * 0.45
            if game is not None:
                ff = np.clip(attr(5), 0.0, 1.0)[..., None]
                col = col * (1 - ff) + np.array(game[3], np.float64) * ff
            elif fog > 0:
                ff = np.clip((d - 6000.0) / 12000.0, 0.0, 1.0)[..., None] * fog
                col = col * (1 - ff) + fogc * ff
            sub[win] = d[win]
            rgb[iy0:iy1, ix0:ix1][win] = col[win]
    _billboards(sc, cam, rgb, depth, f, aspect, tint)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
def _billboards(sc, cam, rgb, depth, f, aspect, tint=None):
    h, w = depth.shape
    right, up = np.array(cam.right), np.array(cam.up)
    view = np.stack([cam.right, cam.up, -np.array(cam.back)], axis=1)
    eye = np.array(cam.eye)
    py, px = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    vb = venuebake()
    flames = [(x, y, z, ("vflame", blue, scale), vb.vanilla_flame_mesh(scale, bool(blue)))
              for x, y, z, blue, scale in getattr(sc, "flames", None) or []]
    for x, y, z, mkey, (verts, tris) in list(getattr(sc, "billboards", [])) + flames:
        centre = np.array((x, y, z), np.float64)
        pts = np.array([centre + vx * right + vy * up for vx, vy, _, *_c in verts])
        cols = np.array([c[3:] for c in verts], np.float64) / 255.0
        if tint is not None and mkey[0] == "puff":
            cols[:, :3] *= np.array(tint)
        V = (pts - eye) @ view
        if (V[:, 2] < NEAR).any():
            continue
        sx = (V[:, 0] / V[:, 2] * f / aspect + 1.0) * 0.5 * w
        sy = (1.0 - V[:, 1] / V[:, 2] * f) * 0.5 * h
        for a, b, c in tris:
            xs, ys = sx[[a, b, c]], sy[[a, b, c]]
            ix0, ix1 = max(0, int(math.floor(xs.min()))), min(w, int(math.ceil(xs.max())) + 1)
            iy0, iy1 = max(0, int(math.floor(ys.min()))), min(h, int(math.ceil(ys.max())) + 1)
            if ix0 >= ix1 or iy0 >= iy1:
                continue
            X, Y = px[iy0:iy1, ix0:ix1], py[iy0:iy1, ix0:ix1]
            (ax, ay), (bx, by), (cx, cy) = zip(xs, ys)
            area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
            if abs(area) < 1e-9:
                continue
            w0 = ((bx - X) * (cy - Y) - (by - Y) * (cx - X)) / area
            w1 = ((cx - X) * (ay - Y) - (cy - Y) * (ax - X)) / area
            w2 = 1.0 - w0 - w1
            d = V[a, 2] * w0 + V[b, 2] * w1 + V[c, 2] * w2
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0) & (d < depth[iy0:iy1, ix0:ix1])
            if not inside.any():
                continue
            col = (w0[..., None] * cols[a] + w1[..., None] * cols[b] + w2[..., None] * cols[c])
            al = col[..., 3:4]
            region = rgb[iy0:iy1, ix0:ix1]
            blend = region * (1 - al) + col[..., :3] * al
            region[inside] = blend[inside]
def views(arena, limit=2):
    from . import raster
    far = raster.far_cameras(arena)
    return far[:limit] + raster.spawn_cameras(arena, limit=limit)
