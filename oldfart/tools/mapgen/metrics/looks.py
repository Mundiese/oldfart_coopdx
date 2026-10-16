import math
import numpy as np
from ..render import raster
from .mario import CELL
MARIO_LUM = 0.27
FIGHT = (600.0, 2400.0)
A1_MIN = {"shooter": 0.25, "objective": 0.22, "knockoff": 0.25, "race": 0.22, "course": 0.22,
          "party": 0.18, "hide": 0.10, "explore": 0.18}
BLEND = ("hide",)
SKY_KEEP = {"A1": 0.432, "A2": 0.259, "A3": 0.232, "A4": (0.299, 0.659, 0.042), "A5": 0.833,
            "A6": 0.497, "A7": 0.0, "A8": 9, "A9": 0.455, "A10": 3.08, "C2": 0.791,
            "C7": 0.412}
CALIBRATION = {
    "A3": "research contrast >= 0.2; pass >= 0.12 (the Sky Keep 0.28 passes with room)",
    "A4": "research each band >= 8 %; the floor under the camera is always near, so only "
          "masses count: middle >= 10 %, far >= 5 %. The Sky Keep's far band is 4 % (it "
          "predates C3's backdrop masses): it warns, and A4 never fails (advisory)",
    "A8": "research: the landmark holds the top blob; the Sky Keep's crown ranks #10 behind "
          "its walls' edges under the game's light (#6 under the old block's) - pass within "
          "the top 10, warn within 16 (advisory)",
    "A9": "the Sky Keep's edge density is the bar: shooters <= x 1.2, hide >= x 1.1",
    "C2": "research >= 90 % of the perimeter; the Sky Keep frames 79 % of its drops (its "
          "bridges and ramp mouths are open on purpose) - pass >= 75 %, warn >= 50 %",
    "A10": "research runs <= 3; the Sky Keep's walls give flat runs of 7 segments of 600 - "
           "pass <= 7 (advisory)",
}
A8_TOP = 10
A8_NEAR = 16
ADVISORY = ("A4", "A8", "A10", "C2", "C7")
FAMILY_ADVISORY = {"race": ("A5",), "course": ("A5",), "knockoff": ("A5",), "party": ("A5",),
                   "hide": ("A9",)}
def _status(ok, near):
    return "pass" if ok else ("warn" if near else "fail")
def _row(value, target, ok, near, why):
    if isinstance(value, float):
        value = round(value, 3)
    return {"value": value, "target": target, "status": _status(ok, near), "why": why}
def _kmeans3(x, iters=12):
    c = np.quantile(x, (0.16, 0.5, 0.84))
    for _ in range(iters):
        lab = np.argmin(np.abs(x[:, None] - c[None, :]), axis=1)
        for k in range(3):
            if (lab == k).any():
                c[k] = x[lab == k].mean()
    lab = np.argmin(np.abs(x[:, None] - c[None, :]), axis=1)
    shares = np.array([(lab == k).mean() for k in range(3)])
    order = np.argsort(c)
    return c[order], shares[order]
def landmark_index(arena):
    pieces = arena.get("pieces") or []
    for i, p in enumerate(pieces):
        if "landmark" in str(p.get("tag") or "") and "cap" not in str(p.get("tag") or ""):
            return i
    lo, hi = raster.bounds(arena)
    mx, mz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    rx, rz = 0.3 * (hi[0] - lo[0]) / 2, 0.3 * (hi[2] - lo[2]) / 2
    best = central = None
    for i, p in enumerate(pieces):
        if p.get("tex") == "invisible" or p.get("kind") == "water":
            continue
        key = (p["y"] + p["h"], p["h"])
        if best is None or key > best[0]:
            best = (key, i)
        if abs(p["x"] - mx) <= rx and abs(p["z"] - mz) <= rz:
            if central is None or key > central[0]:
                central = (key, i)
    return (central or best or (None, None))[1]
def landmark_group(arena, li):
    if li is None:
        return []
    pieces = arena["pieces"]
    head = str(pieces[li].get("tag") or "").split(" ")[0]
    out = [li]
    if not head:
        return out
    for i, p in enumerate(pieces):
        if i != li and str(p.get("tag") or "").split(" ")[0] == head \
                and abs(p["x"] - pieces[li]["x"]) <= 1500 and abs(p["z"] - pieces[li]["z"]) <= 1500:
            out.append(i)
    return out
def a1_contrast(frames, family):
    floor = np.concatenate([f.lum[f.up] for f in frames]) if frames else np.array([])
    wall = np.concatenate([f.lum[f.upright] for f in frames]) if frames else np.array([])
    if floor.size < 50 or wall.size < 50:
        return _row(None, None, True, True, "too few floor or wall pixels to judge")
    v = float(abs(np.median(floor) - np.median(wall)))
    want = A1_MIN.get(family, 0.18)
    return _row(v, ">= %.2f" % (want * 0.6), v >= want * 0.6, v >= want * 0.4,
                "median floor %.2f, wall %.2f on screen" % (np.median(floor), np.median(wall)))
def a2_bands(frames):
    x = np.concatenate([f.lum[~f.sky] for f in frames])
    if x.size < 100:
        return _row(None, None, True, True, "nothing drawn")
    x = x[:: max(1, x.size // 20000)]
    c, shares = _kmeans3(x)
    gap = float(min(c[1] - c[0], c[2] - c[1]))
    ok = gap >= 0.12 and shares.min() >= 0.10
    near = gap >= 0.08 and shares.min() >= 0.05
    return _row(gap, "band gaps >= 0.12, each band >= 10 %", ok, near,
                "bands at %.2f / %.2f / %.2f holding %d / %d / %d %%"
                % (c[0], c[1], c[2], *(int(round(s * 100)) for s in shares)))
def _proxies(cam, frame, n=12):
    ok = frame.up & (frame.depth >= FIGHT[0]) & (frame.depth <= FIGHT[1])
    rows, cols = np.nonzero(ok)
    if rows.size == 0:
        return []
    pick = np.linspace(0, rows.size - 1, min(n, rows.size)).astype(int)
    return [(rows[i], cols[i], float(frame.depth[rows[i], cols[i]])) for i in pick]
def a3_silhouette(cams, frames, family):
    contrasts, sds = [], []
    for cam, fr in zip(cams, frames):
        f = 1.0 / math.tan(math.radians(cam.fov) / 2.0) * fr.h / 2.0
        lum = fr.lum
        for r, c, d in _proxies(cam, fr):
            tall = max(2, int(160.0 * f / d))
            wide = max(1, int(50.0 * f / d))
            r0, r1 = max(0, r - tall), r
            c0, c1 = max(0, c - wide), min(fr.w, c + wide + 1)
            bg = lum[r0:r1, c0:c1]
            if bg.size < 2:
                continue
            contrasts.append(abs(MARIO_LUM - float(np.median(bg))))
            sds.append(float(bg.std()))
    if not contrasts:
        return _row(None, None, True, True, "no floor at fight range in the spawn views")
    con, sd = float(np.median(contrasts)), float(np.median(sds))
    if family in BLEND:
        ok = con <= 0.15 or sd >= 0.12
        return _row(con, "blend: contrast <= 0.15 or background sd >= 0.12", ok,
                    con <= 0.25, "hide wants Mario to blend: contrast %.2f, background sd %.2f"
                    % (con, sd))
    return _row(con, ">= 0.12", con >= 0.12, con >= 0.05,
                "Mario (value %.2f) against a background of contrast %.2f, sd %.2f"
                % (MARIO_LUM, con, sd))
def a4_depth(frames):
    d = np.concatenate([f.depth[~f.sky & ~f.up] for f in frames]) if frames else np.array([])
    if d.size < 100:
        return _row(None, None, True, True, "no spawn view")
    near = float((d < 1200).mean())
    far = float((d > 5000).mean())
    mid = 1.0 - near - far
    v = (round(near, 3), round(mid, 3), round(far, 3))
    ok = mid >= 0.10 and far >= 0.05
    return {"value": v, "target": "middle >= 10 %, far >= 5 % of the masses",
            "status": _status(ok, mid >= 0.05 and far >= 0.01),
            "why": "near %d %%, middle %d %%, far %d %% of the masses the spawn views show"
                   % tuple(int(round(x * 100)) for x in v)}
def a5_landmark(arena, family, world=None):
    li = landmark_index(arena)
    if li is None:
        return _row(None, None, False, True, "no landmark"), None
    group = [arena["pieces"][i] for i in landmark_group(arena, li)]
    def span(p):
        w, d = p["w"], p["d"]
        if int(round(p.get("yaw") or 0)) % 180 == 90:
            w, d = d, w
        return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
    x0 = min(span(p)[0] for p in group)
    x1 = max(span(p)[1] for p in group)
    z0 = min(span(p)[2] for p in group)
    z1 = max(span(p)[3] for p in group)
    y0 = min(p["y"] for p in group)
    top = max(p["y"] + p["h"] for p in group)
    tall = top - y0
    try:
        from .world import World
        world = world or World(arena)
    except Exception:
        return _row(None, None, True, True, "no walk graph to sample"), li
    nodes = [world.nodes[i] for i in sorted(world.columns.values())]
    if not nodes:
        return _row(None, None, True, True, "no walk cells"), li
    step = max(1, len(nodes) // 24)
    pts = nodes[::step][:24]
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    hi = top - tall / 6.0
    targets = [(cx, top + 60.0, cz), (x0 - 1, hi, cz), (x1 + 1, hi, cz), (cx, hi, z0 - 1),
               (cx, hi, z1 + 1)]
    f = 1.0 / math.tan(math.radians(raster.FOV) / 2.0) * 180.0
    seen = 0
    for gx, gz, h in pts:
        e = ((gx + .5) * CELL, h + 160.0, (gz + .5) * CELL)
        t = (cx, hi, cz)
        dist = math.dist(e, t)
        if dist < 1.0:
            seen += 1
            continue
        if all(world.blocked(e, q) for q in targets):
            continue
        tall_px = tall / dist * f
        far = tuple(e[k] + (t[k] - e[k]) / dist * 20000.0 for k in range(3))
        far = (far[0], max(far[1], top + 400.0), far[2])
        sky = not world.blocked((cx, top + 60.0, cz), far)
        if tall_px >= 24 and sky:
            seen += 1
    share = seen / float(len(pts))
    return _row(share, ">= 0.80", share >= 0.8, share >= 0.6,
                "seen tall and against the sky from %d of %d walk points" % (seen, len(pts))), li
def a6_shares(frames):
    counts = {}
    total = 0
    for f in frames:
        m = ~f.sky
        total += int(m.sum())
        ids, n = np.unique(f.tex[m], return_counts=True)
        for i, k in zip(ids, n):
            name = f.textures[i]
            counts[name] = counts.get(name, 0) + int(k)
    if not total:
        return _row(None, None, True, True, "nothing drawn"), {}
    shares = sorted(((k / total, t) for t, k in counts.items()), reverse=True)
    dom = shares[0][0]
    sec = shares[1][0] if len(shares) > 1 else 0.0
    rest = 1.0 - dom - sec
    ok = 0.35 <= dom <= 0.75 and rest <= 0.35
    near = 0.25 <= dom <= 0.85
    return (_row(dom, "dominant 35-75 %, accents and trims <= 35 %", ok, near,
                 "%s %d %%, %s %d %%, the rest %d %%"
                 % (shares[0][1], dom * 100, shares[1][1] if len(shares) > 1 else "-",
                    sec * 100, rest * 100)),
            {t: round(s, 3) for s, t in shares})
def a7_seams(frames):
    diffs = []
    for f in frames:
        for a, b in (((slice(None), slice(None, -1)), (slice(None), slice(1, None))),
                     ((slice(None, -1), slice(None)), (slice(1, None), slice(None)))):
            m = (f.flat[a] & f.flat[b] & (f.ids[a] != f.ids[b]) & (f.tex[a] == f.tex[b])
                 & (f.ids[a] >= 0))
            if m.any():
                sa, sb = f.shade[a][m], f.shade[b][m]
                diffs.append(np.abs(sa - sb) / np.maximum(1e-3, np.maximum(sa, sb)))
    if not diffs:
        return _row(0.0, "< 0.08", True, True, "no seams between same-texture floors in view")
    d = np.concatenate(diffs)
    v = float(np.percentile(d, 90))
    return _row(v, "< 0.08", v < 0.08, v < 0.15,
                "the 90th percentile of the shade step across %d seam pixels" % d.size)
def a8_thumbnail(frame, li, objective_ids=()):
    from PIL import Image, ImageFilter
    if li is None:
        return _row(None, None, True, True, "no landmark")
    im = Image.fromarray((np.clip(frame.lum, 0, 1) * 255).astype(np.uint8), "L")
    w = 231
    h = max(1, int(round(frame.h * w / float(frame.w))))
    small = im.resize((w, h), Image.BILINEAR)
    blur = small.filter(ImageFilter.GaussianBlur(radius=6))
    sal = np.abs(np.asarray(small, np.float32) - np.asarray(blur, np.float32))
    ids = np.asarray(Image.fromarray(frame.ids.astype(np.int32)).resize((w, h), Image.NEAREST))
    cut = np.quantile(sal, 0.97)
    top = ids[(sal >= cut) & (ids >= 0)]
    if top.size == 0:
        return _row(None, None, True, True, "a flat picture")
    vals, counts = np.unique(top, return_counts=True)
    ranked = [int(v) for v in vals[np.argsort(-counts)]]
    wanted = {li} | set(objective_ids)
    rank = next((k for k, v in enumerate(ranked) if v in wanted), None)
    ok = rank is not None and rank < A8_TOP
    return _row(rank if rank is not None else -1,
                "the landmark among the %d most salient pieces" % A8_TOP,
                ok, rank is not None and rank < A8_NEAR,
                "the landmark ranks %s by salient pixels at 231 px"
                % ("unseen" if rank is None else "#%d" % (rank + 1)))
def a9_clutter(frames, family):
    vals = []
    for f in frames:
        lum = f.lum
        gx = np.abs(np.diff(lum, axis=1))[:-1, :]
        gy = np.abs(np.diff(lum, axis=0))[:, :-1]
        g = np.maximum(gx, gy)
        r0, r1 = int(f.h * 0.35), int(f.h * 0.75)
        band = g[r0:r1]
        m = ~f.sky[r0:r1, :-1]
        if m.sum() > 50:
            vals.append(float((band[m] > 0.08).mean()))
    if not vals:
        return _row(None, None, True, True, "no spawn view")
    v = float(np.median(vals))
    bar = SKY_KEEP["A9"]
    if family in BLEND:
        return _row(v, ">= %.2f (busier than the Sky Keep)" % (bar * 1.1), v >= bar * 1.1,
                    v >= bar * 0.8, "edge density %.2f in the player band (hide wants busy)" % v)
    return _row(v, "<= %.2f (the Sky Keep x 1.2)" % (bar * 1.2), v <= bar * 1.2, v <= bar * 1.5,
                "edge density %.2f in the player band" % v)
def skyline(arena, side):
    xs = {}
    for p in arena.get("pieces") or []:
        if p.get("tex") == "invisible" or p.get("kind") == "water":
            continue
        w, d = p["w"], p["d"]
        if int(round(p.get("yaw") or 0)) % 180 == 90:
            w, d = d, w
        c, half = (p["x"], w / 2.0) if side in ("front", "back") else (p["z"], d / 2.0)
        top = p["y"] + p["h"]
        for k in range(int(math.floor((c - half) / 200.0)), int(math.ceil((c + half) / 200.0))):
            xs[k] = max(xs.get(k, -1e9), top)
    if not xs:
        return []
    lo, hi = min(xs), max(xs)
    return [xs.get(k, None) for k in range(lo, hi + 1)]
def a10_skyline(arena):
    worst = None
    notes = []
    for side in ("front", "left"):
        prof = [v for v in skyline(arena, side) if v is not None]
        if len(prof) < 6:
            continue
        segs = [max(prof[i:i + 3]) for i in range(0, len(prof), 3)]
        events = sum(1 for a, b in zip(segs, segs[1:]) if abs(a - b) >= 150)
        spacing = len(prof) * 200.0 / (events + 1)
        run = best = 1
        for a, b in zip(segs, segs[1:]):
            run = run + 1 if abs(a - b) < 150 else 1
            best = max(best, run)
        base = min(prof)
        peaks = sorted(set(s - base for s in segs), reverse=True)
        prom = (peaks[0] / max(1.0, peaks[1])) if len(peaks) > 1 and peaks[1] > 0 else 9.9
        notes.append("%s: an event every %d, longest flat run %d, peak %.2fx"
                     % (side, spacing, best, prom))
        score = min(1.0, 2400.0 / max(1.0, spacing)) + (1.0 if prom >= 1.15 else 0.0) \
            - (0.5 if best > 5 else 0.0)
        if worst is None or score < worst[0]:
            worst = (score, spacing, best, prom)
    if worst is None:
        return _row(None, None, True, True, "too small for a skyline")
    _, spacing, run, prom = worst
    ok = spacing <= 3200 and prom >= 1.15 and run <= 7
    near = spacing <= 4800 and run <= 10
    return _row(round(prom, 2), "an event every <= 3200, a peak >= 1.15x, flat runs <= 7",
                ok, near, "; ".join(notes))
def _tops(arena, cell=100):
    out = {}
    for p in arena.get("pieces") or []:
        if p.get("kind") == "water" or str(p.get("tag", "")).startswith("dress.backdrop"):
            continue
        w, d = p["w"], p["d"]
        if int(round(p.get("yaw") or 0)) % 180 == 90:
            w, d = d, w
        top = p["y"] + p["h"]
        for gx in range(int(math.floor((p["x"] - w / 2.0) / cell)),
                        int(math.ceil((p["x"] + w / 2.0) / cell))):
            for gz in range(int(math.floor((p["z"] - d / 2.0) / cell)),
                            int(math.ceil((p["z"] + d / 2.0) / cell))):
                if (gx, gz) not in out or top > out[(gx, gz)][0]:
                    out[(gx, gz)] = (top, p.get("tex"))
    return out
def c2_edges(arena, world):
    tops = _tops(arena)
    cols = {(gx, gz): world.nodes[i][2] for (gx, gz), i in world.columns.items()}
    edge = framed = 0
    for (gx, gz), h in cols.items():
        outs = [(gx + dx, gz + dz) for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        drops = [c for c in outs if c not in cols or cols[c] < h - 200]
        if not drops:
            continue
        edge += 1
        mine = tops.get((gx, gz), (h, None))
        inner = [tops.get((2 * gx - c[0], 2 * gz - c[1])) for c in drops]
        raised = any(tops.get(c, (-1e9, None))[0] >= h + 100 for c in drops)
        trim = any(t is not None and t[1] != mine[1] for t in inner)
        if raised or trim or mine[0] >= h + 100:
            framed += 1
    if not edge:
        return _row(None, None, True, True, "no edge to frame")
    share = framed / float(edge)
    return _row(share, ">= 0.75", share >= 0.75, share >= 0.5,
                "%d of %d edge cells framed (a rise beside them or a trim line)" % (framed, edge))
def c7_space(arena, world, family):
    cols = {(gx, gz): world.nodes[i][2] for (gx, gz), i in world.columns.items()}
    if not cols:
        return _row(None, None, True, True, "no walk")
    clear = set()
    for (gx, gz), h in cols.items():
        win = [(gx + i, gz + j) for i in range(6) for j in range(6)]
        if all(cols.get(c) == h for c in win):
            clear.update(win)
    share = len(clear) / float(len(cols))
    if family in BLEND:
        return _row(share, "<= 0.10 (hide: alcoves, not plazas)", share <= 0.10, share <= 0.3,
                    "%d %% of the walk lies in clear patches" % (share * 100))
    return _row(share, ">= 0.20", share >= 0.2, share >= 0.1,
                "%d %% of the walk lies in clear 600 x 600 patches" % (share * 100))
CHECKS = ("A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "C2", "C7")
NAMES = {"A1": "floor/wall contrast on screen", "A2": "three value bands",
         "A3": "Mario's silhouette", "A4": "near, middle and far",
         "A5": "landmark seen against the sky", "A6": "material shares (60-30-10)",
         "A7": "seam steps between floors", "A8": "thumbnail: the eye goes to the landmark",
         "A9": "clutter in the player band", "A10": "skyline",
         "C2": "edges framed (no render)", "C7": "clear floor (no render)"}
FIXES = {"A1": "M1: a wall from the theme's family that stands off the floor",
         "A2": "M1/L3: a light stop from kit.L3_STOPS, a darker base course",
         "A3": "M3: light, calm walls at player height (or busy ones in a hide map)",
         "A4": "C3: backdrop masses beyond the edge; a frame near the spawns",
         "A5": "C1: raise the landmark or clear what hides it",
         "A6": "M2: fewer accent textures, one dominant floor",
         "A7": "L1: pictures at their real size (make-arenas PICTURES_AT_SIZE)",
         "A8": "C1/M8: an accent cap on the landmark, fewer accents elsewhere",
         "A9": "M3/C7: calmer walls, clear floor patches",
         "A10": "C4: roofs and towers to break the flat runs, a taller landmark",
         "C2": "C2/R3: one rail, parapet or trim line round every drop",
         "C7": "C7: fewer cover and dress pieces on the plazas (it saves budget)"}
def audit(arena, family=None, size=(320, 180), skew=False, far=2, spawns=4):
    fam = family or arena.get("family")
    far_cams = raster.far_cameras(arena)[:far]
    spawn_cams = raster.spawn_cameras(arena, limit=spawns)
    far_frames = [raster.render(arena, c, size, skew=skew) for c in far_cams]
    spawn_frames = [raster.render(arena, c, size, skew=skew) for c in spawn_cams]
    both = far_frames + spawn_frames
    out = {}
    out["A1"] = a1_contrast(both, fam)
    out["A2"] = a2_bands(both)
    out["A3"] = a3_silhouette(spawn_cams, spawn_frames, fam)
    out["A4"] = a4_depth(spawn_frames)
    try:
        from .world import World
        world = World(arena)
    except Exception:
        world = None
    out["A5"], li = a5_landmark(arena, fam, world)
    out["A6"], shares = a6_shares(both)
    out["A7"] = a7_seams(both)
    out["A8"] = a8_thumbnail(far_frames[0], li, landmark_group(arena, li)) if far_frames else _row(None, None, True, True,
                                                                         "no far view")
    out["A9"] = a9_clutter(spawn_frames, fam)
    out["A10"] = a10_skyline(arena)
    none = _row(None, None, True, True, "no walk graph")
    out["C2"] = c2_edges(arena, world) if world else none
    out["C7"] = c7_space(arena, world, fam) if world else dict(none)
    for k in ADVISORY + FAMILY_ADVISORY.get(fam, ()):
        if out[k]["status"] == "fail":
            out[k]["status"] = "warn"
    tally = {"pass": 0, "warn": 0, "fail": 0}
    for row in out.values():
        tally[row["status"]] += 1
    return {"checks": out, "landmark": li, "shares": shares, "family": fam,
            "summary": "%d pass, %d warn, %d fail" % (tally["pass"], tally["warn"], tally["fail"]),
            "frames": {"far": far_frames, "spawn": spawn_frames}}
def issues(result):
    out = []
    for k in CHECKS:
        row = result["checks"].get(k)
        if row and row["status"] != "pass":
            out.append((k, row["status"], NAMES[k], row["why"], FIXES[k]))
    return out
def contact_sheet(result, path):
    from PIL import Image
    frames = result["frames"]["far"] + result["frames"]["spawn"]
    if not frames:
        return None
    w, h = frames[0].w, frames[0].h
    cols = 3
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (24, 24, 34))
    for i, f in enumerate(frames):
        sheet.paste(f.image(), ((i % cols) * w, (i // cols) * h))
    sheet.save(path)
    return path
