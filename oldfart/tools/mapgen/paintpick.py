import math
import random
FIELD = "painting_view"
PAGE = 6
DRAW = 24
GRID = 16
MAX_BACK = 0.08
MAX_VOID = 0.55
MAX_SKY = 0.55
MAX_NEAR = 0.30
NEAR_UNITS = 260.0
MIN_FILL = 0.25
MIN_WHOLE = 0.45
SIMILAR_DEG = 22.0
SIMILAR_SHARE = 0.35
PER_SIDE = 2
def _np():
    import numpy as np
    return np
def _vec(v):
    try:
        out = [float(x) for x in v]
    except (TypeError, ValueError):
        return None
    if len(out) != 3 or not all(math.isfinite(x) for x in out):
        return None
    return out
def chosen(layout):
    view = (layout or {}).get(FIELD)
    return view if camera_of(view) is not None else None
def camera_of(view):
    if not isinstance(view, dict):
        return None
    eye, target = _vec(view.get("eye")), _vec(view.get("target"))
    if eye is None or target is None:
        return None
    if math.dist(eye, target) < 1.0:
        return None
    from .render import raster
    fov = view.get("fov", raster.FOV)
    try:
        fov = float(fov)
    except (TypeError, ValueError):
        return None
    if not 10.0 <= fov <= 120.0:
        return None
    return raster.Camera(eye, target, fov)
def view_of(cam, cid=None, label=None):
    out = {"eye": [round(float(x), 1) for x in cam.eye],
           "target": [round(float(x), 1) for x in cam.target],
           "fov": round(float(cam.fov), 2)}
    if cid:
        out["id"] = cid
    if label:
        out["label"] = label
    return out
def set_view(layout, view):
    import copy
    out = copy.deepcopy(layout)
    if view is None:
        out.pop(FIELD, None)
    else:
        out[FIELD] = copy.deepcopy(view)
    return out
class Context:
    def __init__(self, layout, key="map", name="Map", prepared=False):
        np = _np()
        from . import modpack, painting
        from .render import raster
        self.layout = layout
        arena = layout if prepared else modpack.prepared_arena(layout, key, name)
        self.paint = painting.Paint(arena)
        self.sc = self.paint.sc
        self.arena = self.paint.arena
        self.tris = self.paint.tris
        self.frame = self.paint.frame
        self.lo, self.hi = raster.bounds(self.arena)
        self.centre = (self.lo + self.hi) / 2.0
        self.radius = max(800.0, float(np.linalg.norm((self.hi - self.lo)[[0, 2]])) / 2.0)
        P, _uv, _c, N, _t, _k = self.tris
        self.v0 = P[:, 0]
        self.e1 = P[:, 1] - P[:, 0]
        self.e2 = P[:, 2] - P[:, 0]
        self.normal = N
        self.water = np.isnan(N[:, 0])
        cen = P.mean(axis=1)
        pad = 0.1 * max(1.0, float(np.max(self.hi - self.lo)))
        self.play = ((cen[:, 0] >= self.lo[0] - pad) & (cen[:, 0] <= self.hi[0] + pad)
                     & (cen[:, 2] >= self.lo[2] - pad) & (cen[:, 2] <= self.hi[2] + pad))
        self.landmarks = landmarks(self.arena)
        self.pieces = piece_points(self.arena)
        self.first_side = painting.camera(self.arena)
def piece_points(arena, most=240):
    np = _np()
    play = [p for p in arena.get("pieces") or []
            if p.get("tex") != "invisible" and not str(p.get("tag", "")).startswith("dress.backdrop")]
    step = max(1, len(play) // most)
    pts = [(p["x"], float(p["y"]) + float(p["h"]), p["z"]) for p in play[::step]]
    return np.array(pts, float).reshape(-1, 3)
def _share_in_frame(cam, pts, edge=0.95):
    np = _np()
    if not len(pts):
        return 1.0
    v = cam.to_view(pts)
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0)
    z = np.maximum(v[:, 2], 1e-6)
    inside = (v[:, 2] > 1.0) & (np.abs(v[:, 0] / z * f) < edge) & (np.abs(v[:, 1] / z * f) < edge)
    return float(inside.mean())
def landmarks(arena, tallest=6):
    np = _np()
    pts = []
    for s in arena.get("stars") or []:
        if isinstance(s, dict):
            pts.append((s.get("x", 0), s.get("y", 0) + 60, s.get("z", 0)))
    spawns = [s for s in arena.get("spawns") or [] if isinstance(s, dict)]
    for s in spawns[::max(1, len(spawns) // 4)][:4]:
        pts.append((s.get("x", 0), s.get("y", 0) + 100, s.get("z", 0)))
    tall = [p for p in arena.get("pieces") or []
            if p.get("tex") != "invisible" and not str(p.get("tag", "")).startswith("dress.")]
    tall.sort(key=lambda p: -(float(p.get("y", 0)) + float(p.get("h", 0))))
    for p in tall[:tallest]:
        pts.append((p["x"], float(p["y"]) + float(p["h"]), p["z"]))
    return np.array(pts, float).reshape(-1, 3)
def _cast(ctx, origins, dirs, chunk=2000, only=None):
    np = _np()
    n = len(dirs)
    best = np.full(n, np.inf)
    idx = np.full(n, -1, np.int64)
    origins = np.broadcast_to(origins, dirs.shape)
    sel = np.arange(len(ctx.v0)) if only is None else np.flatnonzero(only)
    for a in range(0, len(sel), chunk):
        part = sel[a:a + chunk]
        v0, e1, e2 = ctx.v0[part], ctx.e1[part], ctx.e2[part]
        pv = np.cross(dirs[:, None, :], e2[None, :, :])
        det = np.einsum("tk,rtk->rt", e1, pv)
        ok = np.abs(det) > 1e-9
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        tv = origins[:, None, :] - v0[None, :, :]
        u = np.einsum("rtk,rtk->rt", tv, pv) * inv
        qv = np.cross(tv, e1[None, :, :])
        v = np.einsum("rk,rtk->rt", dirs, qv) * inv
        t = np.einsum("tk,rtk->rt", e2, qv) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-3)
        t = np.where(hit, t, np.inf)
        j = np.argmin(t, axis=1)
        tj = t[np.arange(n), j]
        better = tj < best
        best[better] = tj[better]
        idx[better] = part[j[better]]
    return best, idx
def _in_view(ctx, cam, margin=1.15):
    np = _np()
    P = ctx.tris[0]
    V = cam.to_view(P.reshape(-1, 3)).reshape(-1, 3, 3)
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0) / margin
    z = V[..., 2]
    ahead = (z > 1.0).any(axis=1)
    out = ~ahead
    for axis in (0, 1):
        s = V[..., axis] * f
        out |= (s > np.maximum(z, 1.0)).all(axis=1) | (s < -np.maximum(z, 1.0)).all(axis=1)
    return ~out
class Metrics:
    def __init__(self, **kw):
        self.__dict__.update(kw)
    def __repr__(self):
        return "Metrics(%s)" % ", ".join("%s=%s" % (k, round(v, 3) if isinstance(v, float) else v)
                                        for k, v in sorted(self.__dict__.items()))
def _rays(cam, grid=GRID):
    np = _np()
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0)
    s = (np.arange(grid) + 0.5) / grid * 2.0 - 1.0
    sx, sy = np.meshgrid(s, -s)
    fwd = -np.array(cam.back)
    d = (fwd[None, None, :] + sx[..., None] / f * np.array(cam.right)[None, None, :]
         + sy[..., None] / f * np.array(cam.up)[None, None, :])
    d = d.reshape(-1, 3)
    return d / np.linalg.norm(d, axis=1)[:, None], sx.reshape(-1), sy.reshape(-1)
def evaluate(ctx, cam, grid=GRID):
    np = _np()
    from .render import raster
    eye = np.array(cam.eye, float)
    dirs, sx, sy = _rays(cam, grid)
    dist, tri = _cast(ctx, eye[None, :], dirs, only=_in_view(ctx, cam))
    hit = tri >= 0
    n = float(len(dirs))
    nrm = ctx.normal[np.maximum(tri, 0)]
    solid = hit & ~ctx.water[np.maximum(tri, 0)]
    back = solid & (np.einsum("rk,rk->r", nrm, dirs) > 0)
    play = hit & ctx.play[np.maximum(tri, 0)] & ~back
    below = dirs[:, 1] < -0.02
    m = dict(fill=play.sum() / n, sky=(~hit & ~below).sum() / n, void=(~hit & below).sum() / n,
             back=back.sum() / n, near=(hit & (dist < NEAR_UNITS)).sum() / n)
    m["whole"] = _share_in_frame(cam, ctx.pieces)
    if play.any():
        nb = np.nan_to_num(nrm[play])
        axis = np.argmax(np.abs(nb), axis=1) * 2 + (nb[np.arange(len(nb)), np.argmax(np.abs(nb), axis=1)] > 0)
        dom = np.bincount(axis, minlength=6).max() / float(len(nb))
        m["detail"] = float(1.0 - max(0.0, dom - 0.45) / 0.55)
        m["tops"] = float((nb[:, 1] > 0.7).mean())
    else:
        m["detail"] = m["tops"] = 0.0
    if play.any():
        logs = np.log(np.maximum(dist[play], 1.0))
        m["depth"] = float(min(1.0, np.std(logs) / 0.45))
        cx, cy = sx[play].mean(), sy[play].mean()
        m["centre"] = float(max(0.0, 1.0 - math.hypot(cx, cy * 0.6) / 0.6))
    else:
        m["depth"] = m["centre"] = 0.0
    m["marks"] = _marks_seen(ctx, cam)
    why = None
    if raster._inside_any(ctx.arena, eye, 30.0):
        why = "inside a wall"
    elif eye[1] < ctx.lo[1] - 1.0 or _under_floor(ctx, eye):
        why = "under the floor"
    elif m["back"] > MAX_BACK:
        why = "inside a wall"
    elif m["sky"] > MAX_SKY:
        why = "mostly sky"
    elif m["near"] > MAX_NEAR or (m["whole"] < MIN_WHOLE and m["fill"] >= MIN_FILL):
        why = "too close"
    elif m["fill"] < MIN_FILL and m["whole"] >= 0.9:
        why = "too far"
    elif m["void"] > MAX_VOID:
        why = "looks at the void"
    elif m["fill"] < MIN_FILL:
        why = "too far"
    m["why"] = why
    m["score"] = score(m) if why is None else -1.0
    return Metrics(**m)
def _under_floor(ctx, eye):
    np = _np()
    dirs = np.array(((0.0, -1.0, 0.0), (0.0, 1.0, 0.0)))
    dist, tri = _cast(ctx, eye[None, :], dirs)
    for k, d in enumerate(dirs):
        j = tri[k]
        if j < 0 or ctx.water[j]:
            continue
        if k == 0:
            return float(np.dot(ctx.normal[j], d)) > 0
        return tri[0] < 0 and float(np.dot(ctx.normal[j], d)) > 0
    return False
def _marks_seen(ctx, cam):
    np = _np()
    if not len(ctx.landmarks):
        return 0
    eye = np.array(cam.eye, float)
    v = cam.to_view(ctx.landmarks)
    f = 1.0 / math.tan(math.radians(cam.fov) / 2.0)
    ok = v[:, 2] > 50.0
    with np.errstate(divide="ignore", invalid="ignore"):
        x = np.where(ok, v[:, 0] / v[:, 2] * f, 9.0)
        y = np.where(ok, v[:, 1] / v[:, 2] * f, 9.0)
    inside = ok & (np.abs(x) < 0.9) & (np.abs(y) < 0.9)
    if not inside.any():
        return 0
    pts = ctx.landmarks[inside]
    d = pts - eye
    far = np.linalg.norm(d, axis=1)
    dist, _ = _cast(ctx, eye[None, :], d / far[:, None])
    return int((dist >= far - 120.0).sum())
def score(m):
    g = m if isinstance(m, dict) else m.__dict__
    fill_s = 1.0 - min(1.0, abs(g["fill"] - 0.52) / 0.4)
    sky_s = 1.0 - min(1.0, abs(g["sky"] - 0.22) / 0.3)
    marks = 1.0 - math.exp(-g["marks"] / 2.5)
    tops = min(1.0, g.get("tops", 0.0) / 0.55)
    return round(0.8 * fill_s + 1.2 * g["whole"] + 0.4 * g["depth"] + 0.4 * g["detail"]
                 + 1.0 * tops + 0.6 * marks + 0.3 * sky_s + 0.3 * g["centre"]
                 - 0.5 * g["near"], 4)
COMPASS = ("north", "north-east", "east", "south-east", "south", "south-west", "west",
           "north-west")
def side_name(ctx, eye):
    dx, dz = eye[0] - ctx.centre[0], eye[2] - ctx.centre[2]
    if math.hypot(dx, dz) < 1.0:
        return "above"
    a = math.degrees(math.atan2(dx, -dz)) % 360.0
    return COMPASS[int((a + 22.5) // 45) % 8]
def orbit(ctx, yaw, pitch, distk, height=0.35, aim=(0.0, 0.0)):
    np = _np()
    from .render import raster
    fov = raster.FOV
    dist = ctx.radius / math.tan(math.radians(fov) / 2.0) * 0.78 * distk
    p = math.radians(pitch)
    back = np.array((-math.sin(yaw) * math.cos(p), math.sin(p), -math.cos(yaw) * math.cos(p)))
    target = ctx.centre.copy()
    target[1] = ctx.lo[1] + (ctx.hi[1] - ctx.lo[1]) * height
    target[0] += aim[0] * ctx.radius
    target[2] += aim[1] * ctx.radius
    return raster.Camera(target + back * dist, target, fov)
def _spread_spawns(ctx, limit=8):
    spawns = [s for s in ctx.arena.get("spawns") or [] if isinstance(s, dict)]
    if not spawns:
        return []
    picked = [spawns[0]]
    while len(picked) < min(limit, len(spawns)):
        picked.append(max((s for s in spawns if s not in picked),
                          key=lambda s: min(math.hypot(s.get("x", 0) - q.get("x", 0),
                                                       s.get("z", 0) - q.get("z", 0))
                                            for q in picked)))
    return picked
def _draw(ctx, rng, count):
    out = []
    spawns = _spread_spawns(ctx)
    for _ in range(count):
        roll = rng.random()
        pitch = rng.choice((8.0, 12.0, 16.0, 20.0, 26.0, 32.0, 40.0))
        distk = rng.choice((0.55, 0.65, 0.72, 0.8, 0.9, 1.0))
        height = rng.choice((0.15, 0.25, 0.35, 0.5))
        if roll < 0.35 and spawns:
            s = rng.choice(spawns)
            yaw = math.atan2(ctx.centre[0] - s.get("x", 0), ctx.centre[2] - s.get("z", 0))
            yaw += math.radians(rng.uniform(-12.0, 12.0))
            kind = "spawn"
        elif roll < 0.55 and len(ctx.landmarks):
            mark = ctx.landmarks[rng.randrange(len(ctx.landmarks))]
            yaw = rng.uniform(0.0, 2 * math.pi)
            aim = ((mark[0] - ctx.centre[0]) / ctx.radius * 0.6,
                   (mark[2] - ctx.centre[2]) / ctx.radius * 0.6)
            cam = orbit(ctx, yaw, pitch, distk, height, aim)
            kind = "landmark"
            cid = "l%.0f_%.0f_%.2f_%.2f_%.2f_%.2f" % (math.degrees(yaw) % 360, pitch, distk, height,
                                                       aim[0], aim[1])
            out.append((cid, _label(ctx, cam, pitch, distk, kind), cam))
            continue
        else:
            yaw = rng.uniform(0.0, 2 * math.pi)
            kind = "side"
        cam = orbit(ctx, yaw, pitch, distk, height)
        cid = "%s%.0f_%.0f_%.2f_%.2f" % ({"spawn": "p", "side": "o"}[kind],
                                          math.degrees(yaw) % 360, pitch, distk, height)
        out.append((cid, _label(ctx, cam, pitch, distk, kind), cam))
    return out
def _label(ctx, cam, pitch, distk, kind):
    side = side_name(ctx, cam.eye)
    words = ["From the %s" % side if side != "above" else "From above"]
    if pitch >= 30:
        words.append("high")
    elif pitch <= 10:
        words.append("low")
    if distk <= 0.6:
        words.append("close")
    elif distk >= 0.95:
        words.append("wide")
    if kind == "spawn":
        words.append("over a spawn")
    elif kind == "landmark":
        words.append("a landmark")
    return ", ".join(words[:3])
def similar(a, b, radius):
    np = _np()
    fa, fb = -np.array(a.back), -np.array(b.back)
    ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(fa, fb))))))
    return ang < SIMILAR_DEG and float(np.linalg.norm(a.eye - b.eye)) < SIMILAR_SHARE * radius
class Candidate:
    def __init__(self, cid, label, cam, metrics, default=False):
        self.id, self.label, self.cam, self.metrics = cid, label, cam, metrics
        self.default = default
    @property
    def score(self):
        return self.metrics.score
    @property
    def why(self):
        return self.metrics.why
    @property
    def view(self):
        return None if self.default else view_of(self.cam, self.id, self.label)
    def __repr__(self):
        return "Candidate(%s, %r, %.3f)" % (self.id, self.label, self.score)
DEFAULT_SEED = 1
def seed_of(layout):
    return DEFAULT_SEED
def best(ctx):
    return Picker(ctx.layout, ctx=ctx).first()[0]
class Picker:
    def __init__(self, layout, seed=None, key="map", name="Map", ctx=None, draw=DRAW):
        self.layout = layout
        self.seed = seed_of(layout) if seed is None else int(seed)
        self.ctx = ctx or Context(layout, key, name)
        self.rng = random.Random(self.seed)
        self.draw = draw
        self.pages = []
        self.shown = []
        self.seen_ids = set()
        self.reserve = []
        self.refused = []
        self.cast = 0
    def first(self):
        return self.page(0)
    def reroll(self):
        return self.page(len(self.pages))
    def page(self, n):
        while len(self.pages) <= n:
            self.pages.append(self._next())
        return self.pages[n]
    def _make(self, cid, label, cam, default=False):
        self.cast += 1
        return Candidate(cid, label, cam, evaluate(self.ctx, cam), default)
    def _next(self):
        out = []
        pool = list(self.reserve)
        first = None
        if not self.pages:
            first = self._make("side0", "The first spawn's side", self.ctx.first_side)
            (pool if first.why is None else self.refused).append(first)
        tries = 0
        while True:
            fresh = [c for c in (self._make(*v) for v in _draw(self.ctx, self.rng, self.draw))
                     if c.id not in self.seen_ids]
            for c in fresh:
                (pool if c.why is None else self.refused).append(c)
            pool.sort(key=lambda c: (-c.score, c.id))
            picked = self._pick(pool, out, strict=True)
            if len(out) + len(picked) >= PAGE or tries >= 3:
                break
            tries += 1
        if len(out) + len(picked) < PAGE:
            picked += self._pick([c for c in pool if c not in picked], out + picked,
                                 strict=False)
        out += picked[:PAGE - len(out)]
        if not self.pages:
            if not out:
                out = [first]
            out[0].default = True
        for c in out:
            self.seen_ids.add(c.id)
        self.shown += out
        self.reserve = [c for c in pool if c.id not in self.seen_ids]
        return out
    def _pick(self, pool, page, strict):
        picked = []
        for c in pool:
            if len(page) + len(picked) >= PAGE:
                break
            if c.id in self.seen_ids or any(c.id == p.id for p in page + picked):
                continue
            against = page + picked + (self.shown if strict else [])
            if any(similar(c.cam, o.cam, self.ctx.radius) for o in against):
                continue
            side = side_name(self.ctx, c.cam.eye)
            if strict and sum(side_name(self.ctx, o.cam.eye) == side
                              for o in page + picked) >= PER_SIDE:
                continue
            picked.append(c)
        return picked
def picture(ctx, cam, size=None):
    from . import painting
    return painting.draw(ctx.paint, cam, size or painting.SIZE)
def preview_of(top, bottom):
    from PIL import Image
    w, h = top.size
    k = max(1, w // 64)
    out = Image.new("RGB", (w, 2 * h - k))
    out.paste(top.convert("RGB"), (0, 0))
    out.paste(bottom.convert("RGB").crop((0, k, w, h)), (0, h))
    return out
def face(ctx, cam, k=None):
    from . import painting
    top, bottom = painting.halves(picture(ctx, cam), ctx.frame, k or painting.SCALE)
    return top, bottom, preview_of(top, bottom)
def export_files(layout, key, k=None):
    from . import painting
    return painting.export_files(layout, key, k or painting.SCALE)
