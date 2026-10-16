from collections import deque
from . import brief as briefmod
MARIO_RUN = 960.0
TASTE = None
GRID = 100
def band(value, lo, hi):
    if value is None:
        return 0.0
    if lo <= value <= hi:
        return 1.0
    width = max(hi - lo, 1e-9)
    off = (lo - value) if value < lo else (value - hi)
    return max(0.0, 1.0 - off / width)
def seconds(steps):
    return steps * GRID / MARIO_RUN + 0.6
def _bfs(edges, starts):
    dist = {s: 0 for s in starts}
    todo = deque(starts)
    while todo:
        n = todo.popleft()
        for m in edges.get(n, ()):
            if m not in dist:
                dist[m] = dist[n] + 1
                todo.append(m)
    return dist
def _cell(spot):
    import math
    return (int(math.floor(spot[0] / GRID)), int(math.floor(spot[2] / GRID)), int(round(spot[1])))
def builtin(arena, graph, meta, brief):
    cells, edges = graph
    pace = briefmod.PACES[brief["pace"]]
    factor = (briefmod.size_factor(brief["size"]) or 1.0) * pace
    cx, cz = meta.get("centre", (0, 0))
    centre_cells = [c for c in cells if (c[0] * GRID + 50 - cx) ** 2 + (c[1] * GRID + 50 - cz) ** 2
                    <= 600 ** 2]
    m = {}
    bases = meta.get("bases", [])
    to_centre = _bfs({k: v for k, v in edges.items()}, centre_cells) if centre_cells else {}
    times = [seconds(to_centre[_cell(s)]) for base in bases for s in base
             if _cell(s) in to_centre]
    m["spawn_to_centre_s"] = round(sum(times) / len(times), 2) if times else None
    enemy = []
    for i, base in enumerate(bases):
        if not base:
            continue
        d = _bfs(edges, [_cell(base[0])])
        others = [d[_cell(s)] for j, b in enumerate(bases) if j != i for s in b if _cell(s) in d]
        if others:
            enemy.append(seconds(min(others)))
    m["spawn_to_enemy_spawn_s"] = round(min(enemy), 2) if enemy else None
    reached = len(cells)
    m["area_per_player_M"] = round(reached * GRID * GRID / 1e6 / max(brief["players"], 1), 2)
    heights = {}
    for c in cells:
        h = int(round(c[2] / 100.0)) * 100
        heights[h] = heights.get(h, 0) + 1
    m["layers"] = sum(1 for n in heights.values() if n >= 0.05 * reached)
    cols = {}
    for c in cells:
        cols.setdefault((c[0], c[1]), []).append(c[2])
    covered = 0
    for c in cells:
        found = False
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                for h in cols.get((c[0] + dx, c[1] + dz), ()):
                    if h >= c[2] + 100:
                        found = True
                        break
                if found:
                    break
            if found:
                break
        covered += found
    m["cover_within_300"] = round(covered / float(reached), 3) if reached else 0
    m["pieces"] = len(arena["pieces"])
    want_layers = {"flat": (1, 1), "low": (2, 2), "medium": (2, 3), "high": (3, 5)}[
        brief["verticality"]]
    bands = {
        "spawn_to_centre_s": ((4 * factor, 7 * factor), 2),
        "spawn_to_enemy_spawn_s": ((3.5, 99), 3),
        "area_per_player_M": ((0.25 * 1.8 * factor * factor, 3.0 * factor * factor), 1),
        "layers": (want_layers, 2),
        "cover_within_300": ((0.6, 0.8), 2),
        "pieces": ((40, 100), 1),
    }
    total = wsum = 0.0
    rows = []
    for name, ((lo, hi), w) in bands.items():
        b = band(m[name], lo, hi)
        rows.append({"metric": name, "value": m[name], "band": [round(lo, 2), round(hi, 2)],
                     "score": round(b, 3), "weight": w})
        total += w * b
        wsum += w
    return {"source": "built-in placeholder", "quality": round(total / wsum, 4),
            "metrics": m, "rows": rows}
def course_clean_s(meta):
    rep = ((meta or {}).get("params") or {}).get("course")
    v = rep.get("clean_s") if isinstance(rep, dict) else None
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None
def external(arena, brief, meta=None):
    try:
        from . import metrics
    except Exception as why:
        return None, "metrics package not importable (%s)" % why.__class__.__name__
    try:
        res = metrics.measure(arena, family=brief["family"], tier="cheap",
                              players=brief["players"], size=brief.get("size"),
                              course_s=course_clean_s(meta))
        rows, quality = metrics.quality(res)
        out = {"source": "tools/mapgen/metrics", "quality": round(float(quality), 4),
               "metrics": res.get("metrics", {}), "rows": rows}
        if TASTE is not None:
            from . import taste
            out = taste.apply(out, brief["family"], TASTE)
        from . import hostpatterns
        if hostpatterns.ACTIVE:
            out["host_like"] = hostpatterns.likes(arena)
            out["quality"] = round(out["quality"] + hostpatterns.bonus(arena), 4)
        try:
            from . import fit
            out["fit"] = fit.measure_fit(brief, res, arena)
        except Exception as why:
            out["fit_note"] = "wish fit not measured: %s" % why.__class__.__name__
        return out, None
    except Exception as why:
        return None, "metrics package failed: %s: %s" % (why.__class__.__name__, why)
def score(arena, graph, meta, brief, use_metrics=True):
    note = None
    if use_metrics:
        res, note = external(arena, brief, meta)
        if res is not None:
            return res
    res = builtin(arena, graph, meta, brief)
    if note:
        res["note"] = note
    return res
