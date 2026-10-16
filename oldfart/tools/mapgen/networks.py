import heapq
import math
from . import decor, kit, pcg
RUN = 960
T2_EVERY = 6.0
T2_APART = 3800
T2_FROM_T1 = 1920
T3_EVERY = (2.0, 3.0)
LAMP_EVERY = (6, 8)
PATH_W = 200
STRIP_H = 20
CURB = 50
SCENE_TYPES = {
    "village": ("market", "cart", "watchpost", "garden", "farm"),
    "plaza": ("market", "garden", "watchpost"),
    "garden": ("garden", "circle", "watchpost"),
    "forest": ("camp", "fallentower", "circle"),
    "hills": ("camp", "circle", "fallentower", "farm"),
    "ruins": ("fallentower", "circle", "camp"),
    "lake": ("dock", "camp", "watchpost"),
    "volcano": ("fallentower", "camp"),
}
class Ctx:
    def __init__(self, W, brief, sites, edges, kinds, mid, r, pal, lift, off, cell, level_y,
                 theme):
        self.W, self.brief, self.sites, self.edges = W, brief, sites, edges
        self.kinds, self.mid, self.r, self.pal = kinds, mid, r, pal
        self.lift, self.off, self.cell, self.level_y = lift, off, cell, level_y
        self.theme = theme
        self.n = W.n
    def X(self, i):
        return self.off + i * self.cell
    def mid_of(self, c):
        return self.off + c[0] * self.cell + self.cell // 2, self.off + c[1] * self.cell + self.cell // 2
    def Y(self, c):
        return self.level_y(self.W.T(c), self.lift)
    def ground_at(self, x, z):
        W = self.W
        c = (int((x - self.off) // self.cell), int((z - self.off) // self.cell))
        if not (0 <= c[0] < W.n and 0 <= c[1] < W.n):
            return None
        if c in W.river or c in W.lake or c in W.cuts:
            return None
        return self.Y(c)
def _flat_free(W, cells, own=None):
    for c in cells:
        if not (0 <= c[0] < W.n and 0 <= c[1] < W.n):
            return False
        if c in W.solid or c in W.road or c in W.streets or c in W.lake or c in W.river \
                or c in W.cuts or c in W.roofs or c in W.ramps:
            return False
        if own is not None and W.owner.get(c) != own:
            return False
    return W.flat(cells)
def _square(c, k=1):
    return [(c[0] + a, c[1] + b) for a in range(-k, k + 1) for b in range(-k, k + 1)]
def t1_points(ctx):
    W = ctx.W
    out = [("landmark", lm["cell"]) for lm in W.landmarks]
    out += [("spire", sp["cell"]) for sp in W.spires]
    return out
LOOKOUT_STEPS = (450, 300, 150)
def ladder_t1(ctx, pieces):
    W = ctx.W
    t1 = t1_points(ctx)
    want = max(1, int(math.ceil(len(ctx.sites) / 3.0)))
    added = []
    if len(t1) >= want:
        return t1, added
    have = set(W.owner.get(c) for _, c in t1)
    order = sorted((i for i in ctx.kinds if i not in have and ctx.kinds[i] not in ("lake",)),
                   key=lambda i: (-W.plinth.get(i, 0), i))
    for i in order:
        if len(t1) + len(added) >= want:
            break
        near = [j for _, c in t1 for j in [W.owner.get(c)]]
        cs = sorted((c for c, d in W.owner.items() if d == i),
                    key=lambda c: (-W.T(c), c))
        for c in cs[:200]:
            foot = [(c[0] + a, c[1] + b) for a in (0, 1) for b in (0, 1)]
            ring = [(c[0] + a, c[1] + b) for a in range(-1, 3) for b in range(-1, 3)]
            if not _flat_free(W, ring):
                continue
            key = "windmill" if ctx.kinds.get(i) in ("hills", "village", "garden") \
                and ctx.r.random() < 0.6 else "lookout"
            x, z = ctx.X(c[0]) + ctx.cell, ctx.X(c[1]) + ctx.cell
            p = decor.piece(key, x, ctx.Y(c), z, 0, theme=ctx.theme, pal=ctx.pal,
                            tag="decor.t1.%s" % key)
            p["context"] = "landmark"
            p["district"] = i
            pieces.append(p)
            if key == "lookout":
                y0 = ctx.Y(c)
                tex = p["mats"].get("a") or p["tex"]
                for k_, top in enumerate(LOOKOUT_STEPS):
                    z0 = z + 300 + 100 * k_
                    step = kit.kind("box").make(tex, x - 150, x + 150, y0, y0 + top, z0, z0 + 100,
                                                None, "decor.t1.lookout.steps")
                    step["district"] = i
                    pieces.append(step)
            for x_ in ring:
                W.solid[x_] = (0, None, "decor")
            _keep_clear(ctx, [(c[0] + a, c[1] + b) for a in range(-2, 4) for b in range(-2, 4)])
            added.append(("decor:" + key, c))
            break
    return t1 + added, added
def ladder_t2(ctx, t1, pieces, objects):
    W, r = ctx.W, ctx.r
    square = max(4, int(T2_EVERY * RUN / ctx.cell))
    apart = T2_APART / float(ctx.cell)
    from_t1 = T2_FROM_T1 / float(ctx.cell)
    sites = []
    per_district = {}
    max_per = 3 if len(ctx.sites) >= 20 else 2
    for gi in range(0, W.n, square):
        for gj in range(0, W.n, square):
            ci = gi + int(r.random() * square)
            cj = gj + int(r.random() * square)
            options = sorted(((i, j) for i in range(gi, min(W.n, gi + square))
                              for j in range(gj, min(W.n, gj + square))),
                             key=lambda c: (abs(c[0] - ci) + abs(c[1] - cj), c))
            for c in options:
                foot = _square(c, 1)
                ring = _square(c, 2)
                d = W.owner.get(c)
                if d is None or per_district.get(d, 0) >= max_per:
                    continue
                if not _flat_free(W, foot):
                    continue
                if any(x in W.road or x in W.solid for x in ring if x not in foot):
                    continue
                if any(math.hypot(c[0] - s["cell"][0], c[1] - s["cell"][1]) < apart for s in sites):
                    continue
                if any(math.hypot(c[0] - t[1][0], c[1] - t[1][1]) < from_t1 for t in t1):
                    continue
                sites.append({"cell": c, "district": d})
                per_district[d] = per_district.get(d, 0) + 1
                break
    used = []
    for s in sites:
        kind = ctx.kinds.get(s["district"]) or "garden"
        prefs = list(SCENE_TYPES.get(kind, ("camp", "circle", "watchpost")))
        near = [o["scene"] for o in sites if o is not s and o.get("scene")
                and math.hypot(o["cell"][0] - s["cell"][0], o["cell"][1] - s["cell"][1])
                < 2 * apart]
        choice = [p for p in prefs if p not in near] or prefs
        fresh = [p for p in choice if p not in used]
        s["scene"] = (fresh or choice)[int(r.random() * len(fresh or choice))]
        used.append(s["scene"])
    placed = []
    for k, s in enumerate(sites):
        c = s["cell"]
        x, z = ctx.mid_of(c)
        quarter = int(r.random() * 4)
        y = ctx.Y(c)
        ps, reward = decor.scene_pieces(s["scene"], x, y, z, quarter, theme=ctx.theme,
                                        pal=ctx.pal, index=k)
        for p in ps:
            p["district"] = s["district"]
        pieces.extend(ps)
        for x_ in _square(c, 1):
            W.solid[x_] = (0, None, "decor")
        s["reward"] = reward
        if reward is not None:
            objects.append({"key": "coins", "what": "a coin ring at %s" % s["scene"],
                            "x": int(reward[0]), "y": int(reward[1]) + COIN_LIFT,
                            "z": int(reward[2]), "yaw": 0, "pattern": "poi.t2." + s["scene"],
                            "air": True, "formation": "ring",
                            "variant": kit.coin_variant("ring", air=True)})
        placed.append(s)
    return placed
HERO_BY_KIND = {"village": "well.roof", "plaza": "statue", "garden": "statue",
                "hills": "obelisk", "ruins": "obelisk", "forest": "obelisk",
                "volcano": "obelisk", "lake": "statue"}
def heroes(ctx, t1, sites, pieces):
    W = ctx.W
    have = set(s["district"] for s in sites)
    have |= set(W.owner.get(c) for k, c in t1 if str(k).startswith("decor:"))
    out = 0
    for i in sorted(ctx.kinds):
        if i in have:
            continue
        site = ctx.sites[i]
        cs = sorted((c for c, d in W.owner.items() if d == i),
                    key=lambda c: (abs(c[0] - site[0]) + abs(c[1] - site[1]), c))
        key = HERO_BY_KIND.get(ctx.kinds.get(i), "statue")
        done = False
        for reach in (1, 0):
            for c in cs:
                ring = _square(c, reach)
                if not _flat_free(W, ring, own=i):
                    continue
                x, z = ctx.mid_of(c)
                p = decor.piece(key, x, ctx.Y(c), z, 0, theme=ctx.theme, pal=ctx.pal, index=out,
                                tag="decor.hero.%s" % key)
                if reach == 0 and any(
                        q.get("decor") and decor._gap(p, q) < 400 for q in pieces):
                    continue
                p["context"] = "landmark"
                p["district"] = i
                pieces.append(p)
                for x_ in ring:
                    W.solid[x_] = (0, None, "decor")
                _keep_clear(ctx, _square(c, 2))
                out += 1
                done = True
                break
            if done:
                break
    return out
def _neighbours(c):
    for a, b in pcg.N4:
        yield (c[0] + a, c[1] + b), (a, b)
def route(ctx, start, goal_set, paved, climbs_max=1):
    W = ctx.W
    goals = set(goal_set)
    if not goals:
        return None
    gx = sum(c[0] for c in goals) / float(len(goals))
    gz = sum(c[1] for c in goals) / float(len(goals))
    best_goal = min(goals, key=lambda g: (abs(g[0] - start[0]) + abs(g[1] - start[1]), g))
    def h(c):
        return 0.3 * (abs(c[0] - best_goal[0]) + abs(c[1] - best_goal[1]))
    def passable(c):
        if not (0 <= c[0] < W.n and 0 <= c[1] < W.n):
            return False
        if c in W.solid or c in W.lake or c in W.cuts or c in W.roofs:
            return False
        return True
    open_ = [(h(start), 0.0, start, None, 0)]
    came = {}
    cost = {start: 0.0}
    while open_:
        f, g, c, prev, climbed = heapq.heappop(open_)
        if c in came:
            continue
        came[c] = prev
        if c in goals:
            out = [c]
            while came[out[-1]] is not None:
                out.append(came[out[-1]])
            return list(reversed(out))
        for x, d in _neighbours(c):
            if x in came or not passable(x) and x not in goals:
                continue
            dz = W.T(x) - W.T(c) if x not in W.river and c not in W.river else 0
            if abs(dz) > climbs_max:
                continue
            step = 1.0
            if x in paved:
                step *= 0.3
            elif any((x[0] + a, x[1] + b) in W.road for a, b in pcg.N4):
                step *= 0.6
            if dz:
                step += 2.0 + (3.0 if climbed else 0.0)
            if prev is not None and (c[0] - prev[0], c[1] - prev[1]) != d:
                step += 0.3
            if x in W.river:
                step += 4.0
            if any(W.solid.get((x[0] + a, x[1] + b), (0, 0, ""))[2] == "hedge" for a, b in pcg.N4):
                step += 6.0
            step += 0.05 * abs((x[0] - start[0]) * (gz - start[1]) - (x[1] - start[1]) * (gx - start[0])) \
                / max(1.0, math.hypot(gx - start[0], gz - start[1]))
            ng = g + step
            if ng < cost.get(x, 1e18):
                cost[x] = ng
                heapq.heappush(open_, (ng + h(x), ng, x, c, 1 if dz else 0))
    return None
def footpaths(ctx, pois):
    W = ctx.W
    paved = set()
    goal = set(W.road) | set(W.streets)
    paths = []
    for rank, name, around in sorted(pois, key=lambda p: (p[0], p[1])):
        starts = []
        for c in around:
            for x, _ in _neighbours(c):
                if x not in around and 0 <= x[0] < W.n and 0 <= x[1] < W.n \
                        and x not in W.solid and x not in W.lake and x not in W.river:
                    starts.append(x)
        starts = sorted(set(starts))
        if not starts:
            continue
        if any(s in goal for s in starts):
            paths.append({"name": name, "cells": [], "joined": True})
            continue
        best = None
        for s in starts[:6]:
            p = route(ctx, s, goal | paved, paved)
            if p is not None and (best is None or len(p) < len(best)):
                best = p
        if best is None:
            paths.append({"name": name, "cells": None})
            continue
        cells = [c for c in best if c not in W.road and c not in W.streets]
        paths.append({"name": name, "cells": cells})
        paved |= set(cells)
    return {"paths": paths, "cells": paved}
def traffic(ctx, net, spawns):
    count = {}
    for p in net["paths"]:
        if not p.get("cells"):
            continue
        weight = 1 + sum(1 for s in spawns if s in p["cells"])
        for c in p["cells"]:
            count[c] = count.get(c, 0) + weight
    return count
def classes(ctx):
    W = ctx.W
    main = set()
    W.gu4_road_paths = []
    by_edge = {}
    if ctx.edges:
        from . import landform
        for a, b in ctx.edges:
            path = landform.road_path(W.base, ctx.sites[a], ctx.sites[b], river=W.river,
                                      river_level=W.river_level)
            cells = [c for c in path or [] if c in W.road and c not in W.river]
            by_edge[(a, b)] = cells
            if cells:
                W.gu4_road_paths.append({"name": "road@%d-%d" % (a, b), "cells": cells})
            if ctx.mid is not None and ctx.mid in (a, b):
                main.update(cells)
    main.update(hero_trunk(ctx, by_edge))
    return {c: ("main" if c in main else "road") for c in W.road}
def hero_trunk(ctx, by_edge):
    way = getattr(ctx.W, "hero_way", None) or {}
    goal = way.get("district")
    if goal is None or ctx.mid is None or goal == ctx.mid or not by_edge:
        return set()
    nbr = {}
    for a, b in sorted(by_edge):
        nbr.setdefault(a, []).append(b)
        nbr.setdefault(b, []).append(a)
    came = {ctx.mid: None}
    todo = [ctx.mid]
    while todo and goal not in came:
        a = todo.pop(0)
        for b in nbr.get(a, []):
            if b not in came:
                came[b] = a
                todo.append(b)
    if goal not in came:
        return set()
    out = set()
    b = goal
    while came[b] is not None:
        a = came[b]
        out.update(by_edge.get((a, b)) or by_edge.get((b, a)) or [])
        b = a
    return out
def strip_runs(cells):
    left = set(cells)
    runs = []
    for c in sorted(cells):
        if c not in left:
            continue
        run = [c]
        x = (c[0] + 1, c[1])
        while x in left and x not in run:
            run.append(x)
            x = (x[0] + 1, x[1])
        if len(run) == 1:
            x = (c[0], c[1] + 1)
            while x in left:
                run.append(x)
                x = (x[0], x[1] + 1)
        for x in run:
            left.discard(x)
        runs.append(run)
    return runs
def path_pieces(ctx, net, worn_cells, tex, worn_tex, shaped):
    W = ctx.W
    out = []
    cells = [c for c in net["cells"] if c not in shaped and c not in W.river and c not in W.bridges]
    by = {}
    for c in cells:
        by.setdefault((W.T(c), c in worn_cells), []).append(c)
    for (lv, worn), cs in sorted(by.items()):
        for run in strip_runs(cs):
            i0 = min(c[0] for c in run)
            i1 = max(c[0] for c in run)
            j0 = min(c[1] for c in run)
            j1 = max(c[1] for c in run)
            y = ctx.Y(run[0])
            x0, x1 = ctx.X(i0), ctx.X(i1 + 1)
            z0, z1 = ctx.X(j0), ctx.X(j1 + 1)
            inset = (ctx.cell - PATH_W) / 2.0
            if i0 == i1:
                x0, x1 = x0 + inset, x1 - inset
            if j0 == j1:
                z0, z1 = z0 + inset, z1 - inset
            out.append({"kind": "box", "tex": worn_tex if worn else tex, "x": (x0 + x1) / 2.0,
                        "y": y, "z": (z0 + z1) / 2.0, "w": x1 - x0, "h": STRIP_H, "d": z1 - z0,
                        "yaw": 0, "tag": "path.worn" if worn else "path.foot"})
    return out
def curbs(ctx, main_cells, tex, shaped):
    W = ctx.W
    out = []
    cells = [c for c in main_cells if c not in shaped and c not in W.bridges and c not in W.river]
    by = {}
    for c in cells:
        by.setdefault(W.T(c), []).append(c)
    for lv, cs in sorted(by.items()):
        cs_set = set(cs)
        for run in strip_runs(cs):
            if len(run) < 3:
                continue
            along_x = run[0][1] == run[-1][1] and len(set(c[0] for c in run)) > 1
            y = ctx.Y(run[0]) + STRIP_H
            for side in (-1, 1):
                beside = [((c[0], c[1] + side) if along_x else (c[0] + side, c[1])) for c in run]
                if any(b in W.road for b in beside):
                    continue
                i0 = min(c[0] for c in run)
                i1 = max(c[0] for c in run)
                j0 = min(c[1] for c in run)
                j1 = max(c[1] for c in run)
                if along_x:
                    z = ctx.X(j0) if side < 0 else ctx.X(j1 + 1) - CURB
                    p = {"x0": ctx.X(i0), "x1": ctx.X(i1 + 1), "z0": z, "z1": z + CURB}
                else:
                    x = ctx.X(i0) if side < 0 else ctx.X(i1 + 1) - CURB
                    p = {"x0": x, "x1": x + CURB, "z0": ctx.X(j0), "z1": ctx.X(j1 + 1)}
                out.append({"kind": "box", "tex": tex, "x": (p["x0"] + p["x1"]) / 2.0,
                            "y": y - STRIP_H, "z": (p["z0"] + p["z1"]) / 2.0,
                            "w": p["x1"] - p["x0"], "h": CURB + STRIP_H, "d": p["z1"] - p["z0"],
                            "yaw": 0, "tag": "road.curb"})
    return out
def river_crossings(ctx, net, chooser, tex, rail_tex, deck_tex, kinds_of):
    from . import crossings
    W = ctx.W
    out, done = [], []
    cells = [c for c in net["cells"] if c in W.river]
    for run in strip_runs(cells):
        along = "x" if len(set(c[0] for c in run)) > 1 else "z"
        i0 = min(c[0] for c in run)
        i1 = max(c[0] for c in run)
        j0 = min(c[1] for c in run)
        j1 = max(c[1] for c in run)
        lv = max(W.river_level.get(c, 0) for c in run) + 1
        y = ctx.level_y(lv, ctx.lift)
        water = ctx.level_y(lv - 1, ctx.lift) + 150
        if along == "x":
            a0, a1, c = ctx.X(i0), ctx.X(i1 + 1), ctx.X(j0) + ctx.cell / 2.0
        else:
            a0, a1, c = ctx.X(j0), ctx.X(j1 + 1), ctx.X(i0) + ctx.cell / 2.0
        span = a1 - a0
        lands, _ = crossings.ends_land(along, a0, a1, c, y, ctx.ground_at, ctx.cell / 2.0,
                                       ctx.cell)
        if not lands:
            done.append({"kind": "none", "cells": run, "class": "foot",
                         "skipped": "no bank at the deck's height"})
            continue
        kind = chooser.for_class("foot", span, deep=True)
        if kind == "stones":
            ps = crossings.stepping_stones(along, a0, a1, c, y, water, deep=True, r=ctx.r)
        elif kind == "rope":
            ps = crossings.rope(along, a0 - 100, a1 + 100, c, 400, y, deck_tex, rail_tex, rail_tex)
        elif kind == "log":
            ps = crossings.log(along, a0 - 100, a1 + 100, c, y, deck_tex)
        else:
            ps = crossings.plank(along, a0, a1, c, 400, y, deck_tex, tag="bridge.foot")
        ps, gone = crossings.seat_posts(ps, ctx.ground_at)
        out += ps
        done.append({"kind": kind, "cells": run, "class": "foot", "posts_left_out": len(gone)})
    return out, done
def road_bridges(ctx, road_class, chooser, stone, trim, deck_tex, arch_kind, roof_kind, roof_tex):
    from . import crossings
    W = ctx.W
    out, covered, done = [], set(), []
    for run in strip_runs(sorted(W.bridges)):
        cls = "main" if any(road_class.get(c) == "main" for c in run) else "road"
        along = "x" if len(set(c[0] for c in run)) > 1 else "z"
        if len(run) == 1:
            c0 = run[0]
            along = "x" if ((c0[0] - 1, c0[1]) in W.road or (c0[0] + 1, c0[1]) in W.road) else "z"
        i0 = min(c[0] for c in run)
        i1 = max(c[0] for c in run)
        j0 = min(c[1] for c in run)
        j1 = max(c[1] for c in run)
        lv = max(W.river_level.get(c, 0) for c in run) + 1
        y = ctx.level_y(lv, ctx.lift)
        water = ctx.level_y(lv - 1, ctx.lift) + 150
        if along == "x":
            a0, a1, c = ctx.X(i0), ctx.X(i1 + 1), (ctx.X(j0) + ctx.X(j1 + 1)) / 2.0
            width = ctx.X(j1 + 1) - ctx.X(j0)
        else:
            a0, a1, c = ctx.X(j0), ctx.X(j1 + 1), (ctx.X(i0) + ctx.X(i1 + 1)) / 2.0
            width = ctx.X(i1 + 1) - ctx.X(i0)
        span = a1 - a0
        lands, got = crossings.ends_land(along, a0, a1, c, y, ctx.ground_at, ctx.cell / 2.0,
                                         width)
        if not lands:
            done.append({"kind": "none", "cells": run, "class": cls,
                          "skipped": "no bank at the deck's height"})
            continue
        sides = tuple(sd for k, sd in enumerate((-1, 1))
                      if not any(g is not None and abs(g - y) <= crossings.LAND_STEP
                                 for g in got[2 + k::2]))
        kind = chooser.for_class(cls, span, deep=True)
        if kind == "arch":
            ps, _ = crossings.stone_arch(along, a0, a1, c, width, y, None, stone, trim, arch_kind,
                                         sides=sides)
        elif kind == "covered":
            ps = crossings.covered(along, a0, a1, c, width, y, deck_tex, trim, roof_tex, roof_kind,
                                   sides=sides)
        else:
            ps = crossings.plank_rails(along, a0, a1, c, width, y, deck_tex, trim,
                                       posts=(cls == "main"), sides=sides)
        ps, _ = crossings.seat_posts(ps, ctx.ground_at)
        out += ps
        covered |= set(run)
        done.append({"kind": kind, "cells": run, "class": cls})
    return out, covered, done
def _keep_clear(ctx, cells):
    if not hasattr(ctx, "hero_clear"):
        ctx.hero_clear = set()
    ctx.hero_clear |= set(cells)
def _free_beside(ctx, c, taken):
    W = ctx.W
    clear = getattr(ctx, "hero_clear", ())
    for x, _ in _neighbours(c):
        if x in clear:
            continue
        if 0 <= x[0] < W.n and 0 <= x[1] < W.n and x not in taken and W.free(x) \
                and x not in W.hills or (x in W.hills and W.free(x) and x not in taken):
            if x in W.road or x in W.streets or x in taken:
                continue
            if W.T(x) != W.T(c):
                continue
            return x
    return None
def _place(ctx, key, c, pieces, taken, context, district=None, yaw=0, tag=None, index=0):
    x, z = ctx.mid_of(c)
    for k in range(4):
        p = decor.piece(key, x, ctx.Y(c), z, yaw, theme=ctx.theme, pal=ctx.pal, index=index + k,
                        tag=tag or "decor.%s" % key)
        same = sum(1 for q in pieces if q.get("decor") == key and q.get("mats") == p["mats"]
                   and math.hypot(q["x"] - x, q["z"] - z) <= 1500)
        if same < 2:
            break
    p["context"] = context
    p["district"] = district if district is not None else ctx.W.owner.get(c)
    pieces.append(p)
    taken.add(c)
    ctx.W.solid[c] = (0, None, "decor")
    return p
def junctions(ctx, net, road_class, pieces, taken):
    W = ctx.W
    ways = set(net["cells"]) | set(W.road) | set(W.streets)
    out = 0
    seen = []
    meet = [c for c in sorted(net["cells"])
            if sum(1 for x, _ in _neighbours(c) if x in ways) >= 3]
    meet += [p["cells"][-1] for p in net["paths"] if p.get("cells")]
    walks = getattr(W, "gu4_road_paths", [])
    count = {}
    for wk in walks:
        for c in set(wk["cells"]):
            count[c] = count.get(c, 0) + 1
    for c in sorted(count):
        if count[c] >= 2 and any(count.get(x, 0) == 1 for x, _ in _neighbours(c)):
            meet.append(c)
    for c in meet:
        if any(abs(c[0] - s[0]) + abs(c[1] - s[1]) < 6 for s in seen):
            continue
        spot = _free_beside(ctx, c, taken)
        if spot is None:
            continue
        kind = ctx.kinds.get(W.owner.get(c))
        key = ("well" if kind == "village" and ctx.r.random() < 0.3 else "signpost.two")
        _place(ctx, key, spot, pieces, taken, "node", tag="decor.node.%s" % key, index=out)
        seen.append(c)
        out += 1
    return out
T3_SET = (("stones", "bend"), ("bench", "view"), ("flowerbed", "path"), ("logpile", "path"),
          ("standingstone", "path"), ("haybale", "farm"), ("crates", "path"), ("planter", "path"))
ODD = (("rubble", "odd"), ("logpile", "odd"), ("standingstone", "odd"))
COIN_LIFT = 60
def curios(ctx, net, pieces, objects, taken):
    W, r = ctx.W, ctx.r
    count, odd = 0, 0
    for p in list(net["paths"]) + list(getattr(W, "gu4_road_paths", [])):
        cells = p.get("cells") or []
        if len(cells) < 3:
            continue
        gap = (T3_EVERY[0] + r.random() * (T3_EVERY[1] - T3_EVERY[0])) * RUN / ctx.cell
        walked = gap * 0.5
        for k, c in enumerate(cells):
            walked += 1
            if walked < gap:
                continue
            spot = _free_beside(ctx, c, taken)
            if spot is None:
                continue
            walked = 0
            gap = (T3_EVERY[0] + r.random() * (T3_EVERY[1] - T3_EVERY[0])) * RUN / ctx.cell \
                * (0.7 + 0.6 * r.random())
            bend = 0 < k < len(cells) - 1 and \
                (cells[k - 1][0] - c[0], cells[k - 1][1] - c[1]) != (c[0] - cells[k + 1][0], c[1] - cells[k + 1][1])
            high = W.T(c) >= 2
            kind = ctx.kinds.get(W.owner.get(c))
            if count % 3 == 2:
                key, why = ODD[odd % len(ODD)]
                odd += 1
                x, z = ctx.mid_of(spot)
                top = (decor.BY_KEY[key].get("collide") or (0, 0, 0))[1]
                objects.append({"key": "coins", "what": "a coin over an odd find",
                                "x": int(x), "y": int(ctx.Y(spot)) + top + COIN_LIFT,
                                "z": int(z), "yaw": 0, "pattern": "poi.t3.odd", "air": True,
                                "formation": "arch",
                                "variant": kit.coin_variant("arch", air=True)})
            elif bend:
                key, why = "stones", "bend"
            elif high:
                key, why = "bench", "view"
            elif kind == "hills" or kind == "garden" and r.random() < 0.3:
                key, why = ("haybale", "farm") if kind == "hills" else ("flowerbed", "path")
            else:
                key, why = T3_SET[int(r.random() * len(T3_SET))]
                if why in ("view", "bend", "farm"):
                    key, why = "flowerbed", "path"
            d = (c[0] - spot[0], c[1] - spot[1])
            yaw = {(1, 0): 90, (-1, 0): 270, (0, 1): 0, (0, -1): 180}.get(d, 0)
            _place(ctx, key, spot, pieces, taken, why, yaw=yaw, tag="decor.t3.%s" % key,
                   index=count)
            count += 1
    return count, odd
def pointers(ctx, sites, net, pieces, taken):
    W = ctx.W
    out = 0
    by_name = {p["name"]: p for p in net["paths"]}
    for s in sites:
        p = by_name.get("t2@%d,%d" % s["cell"])
        cells = (p or {}).get("cells") or []
        far = cells[-1] if cells else None
        hidden = far is not None and (abs(W.T(far) - W.T(s["cell"])) >= 2 or len(cells) >= 8)
        if not hidden:
            continue
        spot = None
        for x in _square(s["cell"], 2):
            if x not in _square(s["cell"], 1) and W.free(x) and x not in taken \
                    and x not in W.road and x not in W.streets:
                spot = x
                break
        if spot is None:
            continue
        key = "smoke" if s["scene"] == "camp" else "flag"
        _place(ctx, key, spot, pieces, taken, "site", district=s["district"],
               tag="decor.pointer.%s" % key)
        out += 1
    return out
def lamps(ctx, road_class, pieces, taken):
    W, r = ctx.W, ctx.r
    main = sorted(c for c, k in road_class.items() if k == "main")
    out = 0
    every = LAMP_EVERY[0] + int(r.random() * (LAMP_EVERY[1] - LAMP_EVERY[0] + 1))
    since = every
    side = 1
    for c in main:
        since += 1
        if since < every:
            continue
        cand = [(c[0] + side, c[1]), (c[0], c[1] + side), (c[0] - side, c[1]), (c[0], c[1] - side)]
        spot = next((x for x in cand if 0 <= x[0] < W.n and 0 <= x[1] < W.n and W.free(x)
                     and x not in taken and W.T(x) == W.T(c)), None)
        if spot is None:
            continue
        _place(ctx, "lamp", spot, pieces, taken, "main_road", tag="decor.lamp.main", index=out)
        out += 1
        since = 0
        side = -side
    return out
def climbs(ctx, sites, net, objects, pieces, vine_tex):
    W = ctx.W
    out = 0
    for s in sites:
        c = s["cell"]
        for x in _square(c, 2):
            if x in _square(c, 1):
                continue
            if x not in net["cells"] and x not in W.road and x not in W.streets:
                continue
            rise = W.T(c) - W.T(x)
            if rise < 2:
                continue
            px, pz = ctx.mid_of(x)
            if x in W.ramps or ctx.ground_at(px, pz) is None:
                continue
            from . import crossings
            o = crossings.pole(int(px), int(ctx.Y(x)) + STRIP_H, int(pz), height=200 * rise + 300)
            o["air"] = True
            o["district"] = s["district"]
            objects.append(o)
            dx, dz = c[0] - x[0], c[1] - x[1]
            if abs(dx) >= abs(dz):
                d = (1 if dx > 0 else -1, 0)
            else:
                d = (0, 1 if dz > 0 else -1)
            vx = px + d[0] * (ctx.cell / 2.0 - 10)
            vz = pz + d[1] * (ctx.cell / 2.0 - 10)
            pieces.append(crossings.vine(vx, ctx.Y(x), vz, 90 if d[0] else 0, 200 * rise,
                                         vine_tex))
            out += 1
            break
    return out
def strips(ctx, shaped):
    W = ctx.W
    net = getattr(W, "gu4_net", None)
    if net is None:
        return []
    path_tex, worn, trim = W.gu4_texs[0], W.gu4_texs[1], W.gu4_texs[2]
    out = path_pieces(ctx, net, W.gu4_worn, path_tex, worn, shaped)
    main = [c for c, k in getattr(W, "gu4_road_class", {}).items() if k == "main" and c in W.road]
    out += curbs(ctx, main, trim, shaped)
    return out
def _box_of(p):
    a = decor._extent(p)
    return a[0], a[1], a[2], a[3], p["y"], p["y"] + p["h"]
def _shares(a, b, pad=0, touch=1):
    if a[4] >= b[5] - touch or b[4] >= a[5] - touch:
        return False
    return a[0] < b[1] + pad - touch and b[0] - pad < a[1] - touch \
        and a[2] < b[3] + pad - touch and b[2] - pad < a[3] - touch
def clear_of(props, ways, solid=()):
    lanes = [_box_of(q) for q in ways if str(q.get("tag", "")).split(".")[0] in ("road", "path")]
    slopes = [_box_of(q) for q in list(ways) + list(solid) if q.get("kind") in ("stairs", "ramp")]
    others = [_box_of(q) for q in list(ways) + list(solid) if not q.get("decor")
              and q.get("kind") not in ("water",)]
    out, kept = [], []
    for p in props:
        if p.get("decor") and not p.get("pass"):
            a = _box_of(p)
            if any(_shares(a, b, pad=200, touch=-1) for b in slopes) \
                    or any(_shares(a, b, touch=-1) for b in lanes) \
                    or any(_shares(a, b) for b in others) \
                    or any(_shares(a, b) for b in kept):
                continue
            kept.append(a)
        out.append(p)
    return out
THIN = (("odd", "path", "bend", "farm", "view"), ("main_road",), ("node", "site"))
def thin(pieces, step):
    if step >= len(THIN):
        return pieces, 0
    ctxs = THIN[step]
    mine = [k for k, p in enumerate(pieces) if p.get("decor") and p.get("context") in ctxs]
    drop = set(mine[::2])
    return [p for k, p in enumerate(pieces) if k not in drop], len(drop)
def describe(report):
    if not report:
        return "paths and decor: none"
    return ("paths and decor: %d landmarks (%s added), %d sites (%s), %d footpaths over "
            "%d cells (%d worn), %d crossings, %d junction props, %d curios (%d odd), "
            "%d pointers, %d lamps, %d climbs, %d district heroes" % (
                report["t1"], ", ".join(report["t1_added"]) or "none", report["t2"],
                ", ".join(report["t2_types"]) or "none", report["footpaths"],
                report["footpath_cells"], report["worn"], len(report["crossings"]),
                report["junctions"], report["t3"], report["odd"], report["pointers"],
                report["lamps"], report["climbs"], report.get("heroes", 0)))
def dress(ctx, spawns=()):
    from . import contract, crossings, kit
    W = ctx.W
    pieces, objects = [], []
    tex_all = kit.textures()
    path_tex = contract.material(ctx.theme, "path", ctx.pal,
                                 prefer=("pathgravel", "path", "gravel", ctx.pal.get("path") or ""),
                                 kind=None) if hasattr(contract, "material") else None
    path_tex = path_tex if path_tex in tex_all else (ctx.pal.get("path") or ctx.pal.get("road"))
    worn = contract.material(ctx.theme, "path", ctx.pal,
                             prefer=tuple(t for t in ("dirt", "pathgrass", "gravelbrown", "path")
                                          if t != path_tex)) or path_tex
    if worn == path_tex or worn not in tex_all:
        others = [t for t in (contract.members(ctx.theme, "path") or []) if t != path_tex]
        worn = others[0] if others else path_tex
    trim = contract.material(ctx.theme, "trim", ctx.pal, prefer=("curbgranite", ctx.pal.get("trim") or "")) \
        or ctx.pal.get("trim") or ctx.pal["wall"]
    curb = contract.material(ctx.theme, "path", ctx.pal,
                             prefer=("curbgranite", "curbgrass", ctx.pal.get("trim") or "")) \
        or path_tex
    stone = contract.material(ctx.theme, "bridge", ctx.pal, prefer=("sbgrey", "greystone",
                                                                     ctx.pal.get("wall") or "")) \
        or ctx.pal["wall"]
    deck_tex = "darkplanks" if "darkplanks" in tex_all else ctx.pal.get("road")
    vine_tex = "leaves" if "leaves" in tex_all else (ctx.pal.get("foliage") or ctx.pal["accents"][0])
    taken = set()
    t1, t1_added = ladder_t1(ctx, pieces)
    sites = ladder_t2(ctx, t1, pieces, objects)
    heroed = heroes(ctx, t1, sites, pieces)
    pois = []
    for kind, c in t1:
        foot = _square(c, 1) if kind in ("landmark", "spire") else [c]
        pois.append((0, "t1@%d,%d" % c, foot))
    for s in sites:
        pois.append((1, "t2@%d,%d" % s["cell"], _square(s["cell"], 1)))
    for pf in W.prefabs:
        pois.append((2, "prefab@%d,%d" % pf["cell"], list(pf["cells"])))
    for run in W.caves:
        if run:
            pois.append((2, "cave@%d,%d" % run[0], [run[0]]))
    net = footpaths(ctx, pois)
    road_class = classes(ctx)
    count = traffic(ctx, net, [tuple(s) for s in spawns])
    worn_cells = set()
    if count:
        top = sorted(count.values(), reverse=True)
        cut = top[max(0, len(top) // 10 - 1)] if len(top) >= 10 else top[0] + 1
        worn_cells = set(c for c, v in count.items() if v >= cut)
    chooser = crossings.Chooser(ctx.r, ctx.theme)
    cross_pieces, cross_done = river_crossings(ctx, net, chooser, ctx.pal.get("road"), deck_tex,
                                               deck_tex, ctx.kinds)
    roof_tex = ctx.pal.get("roof") or ctx.pal.get("road")
    rb_pieces, rb_cells, rb_done = road_bridges(ctx, road_class, chooser, stone, trim, deck_tex,
                                                kit.kind("arch").make, kit.kind("ridge").make,
                                                roof_tex)
    cross_done += rb_done
    nodes = junctions(ctx, net, road_class, pieces, taken)
    t3, odd = curios(ctx, net, pieces, objects, taken)
    pointed = pointers(ctx, sites, net, pieces, taken)
    lit = lamps(ctx, road_class, pieces, taken)
    climbed = climbs(ctx, sites, net, objects, pieces, vine_tex)
    pieces += cross_pieces
    W.footpath = {c: "foot" for c in net["cells"]}
    W.gu4_net = net
    W.gu4_bridges = (rb_pieces, rb_cells)
    W.gu4_road_class = road_class
    W.gu4_bridge_chooser = chooser
    report = {
        "t1": len(t1), "t1_added": [k for k, _ in t1_added], "t2": len(sites),
        "t2_types": sorted(set(s["scene"] for s in sites)),
        "sites": [{"cell": list(s["cell"]), "scene": s["scene"], "district": s["district"],
                   "reward": [int(v) for v in s["reward"]] if s.get("reward") else None}
                  for s in sites],
        "footpaths": sum(1 for p in net["paths"] if p.get("cells")),
        "footpath_cells": len(net["cells"]), "unreached": [p["name"] for p in net["paths"]
                                                           if p.get("cells") is None],
        "worn": len(worn_cells), "junctions": nodes, "t3": t3, "odd": odd, "pointers": pointed,
        "lamps": lit, "climbs": climbed, "heroes": heroed,
        "crossings": [{"kind": d["kind"], "class": d["class"], "cells": len(d["cells"])}
                      for d in cross_done],
        "main_road_cells": sum(1 for v in road_class.values() if v == "main"),
        "path_tex": path_tex, "worn_tex": worn, "curb_tex": curb, "bridge_stone": stone,
    }
    W.gu4 = report
    W.gu4_worn = worn_cells
    W.gu4_texs = (path_tex, worn, curb, stone, deck_tex)
    return pieces, objects, report
