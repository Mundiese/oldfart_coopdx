from . import decor, kit
CELL = 400
BRANCH_EVERY = 5
BEND_AFTER = 3
TURN = 0.18
LANE_MAX = 9
SIDE_MIN, SIDE_MAX = 3, 6
LANE_CLEAR = 1
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
def _perp(d):
    return ((d[1], d[0]), (-d[1], -d[0]))
def grow(W, cs, plaza, r, budget=40, level=None, ok=None):
    if not plaza or budget <= 0:
        return []
    cs = set(cs)
    pset = set(plaza)
    lvl = W.T(plaza[0]) if level is None else level
    if ok is None:
        def ok(c):
            return c in cs and W.free(c) and W.T(c) == lvl and c not in pset
    i0 = min(c[0] for c in plaza)
    i1 = max(c[0] for c in plaza)
    j0 = min(c[1] for c in plaza)
    j1 = max(c[1] for c in plaza)
    mi, mj = (i0 + i1) // 2, (j0 + j1) // 2
    seeds = [((mi, j0 - 1), (0, -1)), ((mi, j1 + 1), (0, 1)),
             ((i0 - 1, mj), (-1, 0)), ((i1 + 1, mj), (1, 0))]
    def reach(c, d):
        n = 0
        while ok(c) and n < LANE_MAX:
            n += 1
            c = (c[0] + d[0], c[1] + d[1])
        return n
    seeds.sort(key=lambda s: (-reach(*s), s))
    lane = set()
    lanes = []
    near_plaza = set()
    for (pi, pj) in pset:
        for a in range(-LANE_CLEAR, LANE_CLEAR + 1):
            for b in range(-LANE_CLEAR, LANE_CLEAR + 1):
                near_plaza.add((pi + a, pj + b))
    queue = [(c, d, LANE_MAX, True) for c, d in seeds]
    side = 0
    while queue and len(lane) < budget:
        start, d, length, from_plaza = queue.pop(0)
        c = start
        run = []
        straight = 0
        for step in range(length):
            if len(lane) >= budget or not ok(c) or c in lane:
                break
            if step > 0 and c in near_plaza:
                break
            back = (c[0] - d[0], c[1] - d[1])
            beside = [(c[0] + p[0], c[1] + p[1]) for p in _perp(d)]
            joined = any(b in lane and b != back for b in beside) or \
                (c[0] + d[0], c[1] + d[1]) in lane
            run.append(c)
            lane.add(c)
            if joined:
                break
            straight += 1
            if step and step % BRANCH_EVERY == 0:
                p = _perp(d)[side % 2]
                side += 1
                queue.append(((c[0] + p[0], c[1] + p[1]), p, r.randint(SIDE_MIN, SIDE_MAX),
                              False))
            nxt = (c[0] + d[0], c[1] + d[1])
            if straight >= BEND_AFTER and r.random() < TURN:
                turns = list(_perp(d))
                r.shuffle(turns)
                for t in turns:
                    m = (c[0] + t[0], c[1] + t[1])
                    if ok(m) and m not in lane:
                        d, nxt, straight = t, m, 0
                        break
            c = nxt
        if len(run) >= 2 or (run and from_plaza):
            lanes.append(run)
        else:
            for x in run:
                lane.discard(x)
    for run in lanes:
        for c in run:
            W.streets.add(c)
    return lanes
def runs(cells):
    cs = set(cells)
    rows, seen = [], set()
    for c in sorted(cs, key=lambda c: (c[1], c[0])):
        if c in seen:
            continue
        i = c[0]
        while (i + 1, c[1]) in cs and (i + 1, c[1]) not in seen:
            i += 1
        for x in range(c[0], i + 1):
            seen.add((x, c[1]))
        rows.append([c[0], c[1], i, c[1]])
    merged = []
    for row in rows:
        for m in merged:
            if m[0] == row[0] and m[2] == row[2] and m[3] + 1 == row[1]:
                m[3] = row[1]
                break
        else:
            merged.append(row)
    return [tuple(m) for m in merged]
def paving(cells, tex, X, Y, tag="lane.paving"):
    out = []
    for (i0, j0, i1, j1) in runs(cells):
        y = Y((i0, j0))
        out.append(kit.kind("box").make(tex, X(i0), X(i1 + 1), y, y + 20, X(j0), X(j1 + 1),
                                        None, tag))
    return out
INSET = 110
FOUNTAIN_HALF = 400
def square_dressing(plaza, X, Y, theme=None, pal=None, fountain=True, keep=()):
    if not plaza:
        return []
    keep = set(keep)
    i0 = min(c[0] for c in plaza)
    i1 = max(c[0] for c in plaza)
    j0 = min(c[1] for c in plaza)
    j1 = max(c[1] for c in plaza)
    x0, x1, z0, z1 = X(i0), X(i1 + 1), X(j0), X(j1 + 1)
    y = Y(plaza[0]) + 20
    out = []
    span = min(x1 - x0, z1 - z0)
    if fountain and span >= 3 * CELL:
        cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        mid = set(c for c in plaza
                  if abs(X(c[0]) + CELL / 2.0 - cx) < FOUNTAIN_HALF + CELL / 2.0
                  and abs(X(c[1]) + CELL / 2.0 - cz) < FOUNTAIN_HALF + CELL / 2.0)
        if not mid & keep:
            out.append(decor.piece("fountain", cx, y, cz, 0, theme=theme, pal=pal,
                                   tag="plaza.fountain"))
    corners = [((i0, j0), (x0 + INSET, z0 + INSET), 180, "lamp"),
               ((i1, j1), (x1 - INSET, z1 - INSET), 0, "lamp")]
    if span >= 4 * CELL:
        corners += [((i1, j0), (x1 - 200 - 20, z0 + 80 + 20), 0, "bench"),
                    ((i0, j1), (x0 + 200 + 20, z1 - 80 - 20), 180, "bench")]
    for c, (x, z), yaw, key in corners:
        if c in keep:
            continue
        out.append(decor.piece(key, x, y, z, yaw, theme=theme, pal=pal, tag="plaza." + key))
    return out
WALLED = {"S3": (600, 1200, True), "S4": (400, 800, False), "S6": (600, 1000, True)}
WALL_T = 200
TOWER_W = 400
def plan_wall(W, cs, core, kind):
    if kind not in WALLED or not core:
        return None
    cs = set(cs)
    i0 = min(c[0] for c in core) - 1
    i1 = max(c[0] for c in core) + 1
    j0 = min(c[1] for c in core) - 1
    j1 = max(c[1] for c in core) + 1
    sides = {"n": [(i, j0) for i in range(i0, i1 + 1)],
             "s": [(i, j1) for i in range(i0, i1 + 1)],
             "w": [(i0, j) for j in range(j0 + 1, j1)],
             "e": [(i1, j) for j in range(j0 + 1, j1)]}
    paved = getattr(W, "paved", set())
    def passage(c):
        return c in W.streets or c in W.road or c in paved or c in W.river or c in W.lake
    lvl = W.T(core[0])
    def level_ok(c, name):
        if W.T(c) != lvl:
            return False
        a, b = (0, 1) if name in ("n", "s") else (1, 0)
        return all(W.T((c[0] + s * a, c[1] + s * b)) == lvl for s in (-1, 1))
    wall, gaps = [], []
    for name in ("n", "s", "w", "e"):
        mine = []
        for c in sides[name]:
            if c not in cs:
                continue
            if passage(c):
                gaps.append(c)
            elif W.free(c) and level_ok(c, name):
                mine.append(c)
        side_gaps = [c for c in sides[name] if c in gaps]
        if len(mine) >= 3 and not side_gaps:
            mid = sides[name][len(sides[name]) // 2]
            if mid in mine:
                mine.remove(mid)
                gaps.append(mid)
        wall += mine
    if len(wall) < 3:
        return None
    start = [c for c in core if c not in wall and
             (c not in W.solid or W.solid[c][2] == "plaza")]
    if not start:
        return None
    before = _walk(W, start, set())
    for _ in range(12):
        after = _walk(W, start, set(wall))
        cut = [c for c in before if c not in after and c not in wall]
        if not cut:
            break
        opened = False
        for c in cut:
            for a, b in N4:
                m = (c[0] + a, c[1] + b)
                if m in wall:
                    wall.remove(m)
                    gaps.append(m)
                    opened = True
                    break
            if opened:
                break
        if not opened:
            break
    if len(wall) < 3:
        return None
    for c in wall:
        W.solid[c] = (0, None, "townwall")
    corners = [c for c in ((i0, j0), (i1, j0), (i0, j1), (i1, j1)) if c in wall]
    return {"cells": wall, "gaps": gaps, "corners": corners, "rect": (i0, j0, i1, j1),
            "kind": kind}
def _walk(W, start, blocked, reach=30):
    seen = set(start)
    todo = list(start)
    i0 = min(c[0] for c in start) - reach
    i1 = max(c[0] for c in start) + reach
    j0 = min(c[1] for c in start) - reach
    j1 = max(c[1] for c in start) + reach
    while todo:
        c = todo.pop()
        for a, b in N4:
            m = (c[0] + a, c[1] + b)
            if m in seen or m in blocked or not (i0 <= m[0] <= i1 and j0 <= m[1] <= j1):
                continue
            if not (0 <= m[0] < W.n and 0 <= m[1] < W.n):
                continue
            s = W.solid.get(m)
            if (s is not None and s[2] != "plaza") or m in W.lake or m in W.river:
                continue
            if abs(W.T(m) - W.T(c)) > 1:
                continue
            seen.add(m)
            todo.append(m)
    return seen
def wall_pieces(plan, X, Y, st):
    from . import roofs
    if not plan:
        return []
    h, th, cap = WALLED[plan["kind"]]
    i0, j0, i1, j1 = plan["rect"]
    corners = set(plan["corners"])
    cells = set(plan["cells"]) - corners
    tex = st["base"]
    out = []
    for horizontal in (True, False):
        line = sorted(c for c in cells if (c[1] in (j0, j1)) == horizontal
                      and (c[0] in (i0, i1)) != horizontal)
        line.sort(key=lambda c: (c[1], c[0]) if horizontal else (c[0], c[1]))
        run = []
        for c in line + [None]:
            if run and (c is None or Y(c) != Y(run[0]) or
                        (horizontal and (c[1] != run[-1][1] or c[0] != run[-1][0] + 1)) or
                        (not horizontal and (c[0] != run[-1][0] or c[1] != run[-1][1] + 1))):
                a, b = run[0], run[-1]
                y = Y(a)
                if horizontal:
                    zc = X(a[1]) + CELL // 2
                    out.append(kit.kind("box").make(tex, X(a[0]), X(b[0] + 1), y, y + h,
                                                    zc - WALL_T // 2, zc + WALL_T // 2, None,
                                                    "townwall.wall"))
                else:
                    xc = X(a[0]) + CELL // 2
                    out.append(kit.kind("box").make(tex, xc - WALL_T // 2, xc + WALL_T // 2, y,
                                                    y + h, X(a[1]), X(b[1] + 1), None,
                                                    "townwall.wall"))
                run = []
            if c is not None:
                run.append(c)
    for c in plan["corners"]:
        y = Y(c)
        x0, z0 = X(c[0]), X(c[1])
        out.append(kit.kind("box").make(tex, x0, x0 + TOWER_W, y, y + th, z0, z0 + TOWER_W, None,
                                        "townwall.tower"))
        if cap:
            specs, _ = roofs.pieces("cap", st["roof"], x0 - 100, x0 + TOWER_W + 100, z0 - 100,
                                    z0 + TOWER_W + 100, y + th, trim=st.get("trim"),
                                    finial=None)
            out += [roofs.make(sp, "townwall") for sp in specs]
    return out
SMOKE_KINDS = ("S6",)
SMOKE_THEMES = ("ice",)
BOX_THEMES = ("garden", "village", "wood", "sky", "auto")
BOXES_MAX = 2
def house_dressing(e, kind, theme, detail="full"):
    out = []
    ps = e.get("world") or []
    if not ps:
        return out
    if kind in SMOKE_KINDS or theme in SMOKE_THEMES:
        stacks = [p for p in ps if str(p.get("tag", "")).endswith("house.chimney")]
        if stacks:
            s = max(stacks, key=lambda p: p["y"] + p["h"])
            out.append(decor.piece("smoke", s["x"], s["y"] + s["h"], s["z"], 0, theme=theme,
                                   tag="house.smoke"))
    if theme in BOX_THEMES and detail != "lean":
        cx, cz, _ = e.get("at") or (0, 0, 0)
        door = e.get("face", "s")
        n = 0
        for p in sorted(ps, key=lambda p: (p["y"], p["x"], p["z"])):
            if n >= BOXES_MAX:
                break
            if not str(p.get("tag", "")).endswith("facade.window"):
                continue
            w, d = p["w"], p["d"]
            if int(round(p.get("yaw", 0))) % 180 == 90:
                w, d = d, w
            along_x = d <= 40
            if along_x:
                out_dir = 1 if p["z"] > cz else -1
                if (door, out_dir) not in (("s", 1), ("n", -1)):
                    continue
                x, z, yaw = p["x"], p["z"] + out_dir * (d / 2.0 + 30), 0
            else:
                out_dir = 1 if p["x"] > cx else -1
                if (door, out_dir) not in (("e", 1), ("w", -1)):
                    continue
                x, z, yaw = p["x"] + out_dir * (w / 2.0 + 30), p["z"], 90
            box = decor.piece("windowbox", x, p["y"] - 320, z, yaw, theme=theme,
                              tag="house.windowbox")
            box["context"] = "window"
            out.append(box)
            n += 1
    return out
