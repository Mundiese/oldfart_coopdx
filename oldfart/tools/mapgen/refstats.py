import json
import math
import os
import re
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "reference", "sm64_geometry.json")
COURSES = ("bob", "wf", "jrb", "ccm", "bbh", "hmc", "lll", "ssl", "ddd", "sl", "wdw", "ttm",
           "thi", "ttc", "rr", "castle_grounds")
STATS = ("wall_height", "platform_side", "step_rise", "path_width")
PCTS = (10, 25, 50, 75, 90)
_VERT = re.compile(r"COL_VERTEX\(\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\)")
_TRI = re.compile(r"COL_TRI(?:_SPECIAL)?\(\s*(\d+),\s*(\d+),\s*(\d+)")
_INIT = re.compile(r"COL_TRI_INIT\(\s*(\w+)")
SKIP_SURFACES = ("SURFACE_DEATH_PLANE", "SURFACE_INSTANT_QUICKSAND", "SURFACE_INTANGIBLE",
                 "SURFACE_VERTICAL_WIND", "SURFACE_CAMERA_BOUNDARY")
US_DEFINED = ("VERSION_US",)
_IFDEF = re.compile(r"^\s*#\s*(ifdef|ifndef)\s+(\w+)")
_IF = re.compile(r"^\s*#\s*(if|elif)\s+(.*)$")
def _cond(expr, defined):
    e = re.sub(r"defined\s*\(\s*(\w+)\s*\)", lambda m: "1" if m.group(1) in defined else "0", expr)
    e = re.sub(r"defined\s+(\w+)", lambda m: "1" if m.group(1) in defined else "0", e)
    e = re.sub(r"\b[A-Za-z_]\w*\b", lambda m: "1" if m.group(0) in defined else "0", e)
    e = e.replace("&&", " and ").replace("||", " or ").replace("!", " not ")
    e = re.sub(r"//.*$", "", e)
    try:
        return bool(eval(e, {"__builtins__": {}}, {}))
    except Exception:
        return True
def us_only(lines, defined=US_DEFINED):
    out = []
    stack = []
    on = True
    for line in lines:
        m = _IFDEF.match(line)
        m2 = _IF.match(line)
        if m or (m2 and m2.group(1) == "if"):
            want = ((m.group(2) in defined) == (m.group(1) == "ifdef")) if m \
                else _cond(m2.group(2), defined)
            stack.append([on, want])
            on = on and want
        elif m2 and m2.group(1) == "elif" and stack:
            parent, taken = stack[-1]
            want = not taken and _cond(m2.group(2), defined)
            stack[-1][1] = taken or want
            on = parent and want
        elif re.match(r"^\s*#\s*else\b", line) and stack:
            parent, taken = stack[-1]
            stack[-1][1] = True
            on = parent and not taken
        elif re.match(r"^\s*#\s*endif\b", line) and stack:
            on = stack.pop()[0]
        elif on:
            out.append(line)
    return out
def read_collision(path):
    verts, tris = [], []
    surface = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in us_only(fh.read().splitlines(True)):
            m = _VERT.search(line)
            if m:
                verts.append(tuple(int(v) for v in m.groups()))
                continue
            m = _INIT.search(line)
            if m:
                surface = m.group(1)
                continue
            m = _TRI.search(line)
            if m and surface not in SKIP_SURFACES:
                a, b, c = (int(v) for v in m.groups())
                if max(a, b, c) < len(verts):
                    tris.append((a, b, c, surface))
            if "COL_TRI_STOP" in line or "COL_SPECIAL_INIT" in line or "COL_WATER_BOX" in line:
                surface = None
    return verts, tris
def _normal(p, q, r):
    ux, uy, uz = q[0] - p[0], q[1] - p[1], q[2] - p[2]
    vx, vy, vz = r[0] - p[0], r[1] - p[1], r[2] - p[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    n = math.sqrt(nx * nx + ny * ny + nz * nz)
    if n == 0:
        return None, 0.0
    return (nx / n, ny / n, nz / n), n / 2.0
def _components(items, keyfn):
    parent = list(range(len(items)))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    seen = {}
    for i, it in enumerate(items):
        for k in keyfn(it):
            if k in seen:
                ra, rb = find(i), find(seen[k])
                if ra != rb:
                    parent[ra] = rb
            else:
                seen[k] = i
    out = {}
    for i in range(len(items)):
        out.setdefault(find(i), []).append(i)
    return list(out.values())
def _in_tri(px, pz, a, b, c):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    p = (px, pz)
    d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)
def _floor_y(px, pz, P, Q, R, n):
    if abs(n[1]) < 1e-6:
        return None
    return P[1] - (n[0] * (px - P[0]) + n[2] * (pz - P[2])) / n[1]
def measure_area(verts, tris, grid=100):
    floors, walls = [], []
    flat_area = slope_area = 0.0
    for a, b, c, s in tris:
        P, Q, R = verts[a], verts[b], verts[c]
        n, area = _normal(P, Q, R)
        if n is None:
            continue
        if n[1] > 0.7:
            floors.append((a, b, c, n, area))
            if n[1] > 0.95:
                flat_area += area
            else:
                slope_area += area
        elif abs(n[1]) < 0.2:
            walls.append((a, b, c))
    out = {}
    wh = []
    for comp in _components(walls, lambda t: t):
        ys = [verts[v][1] for i in comp for v in walls[i]]
        h = max(ys) - min(ys)
        if h >= 20:
            wh.append(h)
    out["wall_height"] = wh
    flats = [f for f in floors if f[3][1] > 0.95]
    sides = []
    levels = {}
    for comp in _components(flats, lambda t: t[:3]):
        area = sum(flats[i][4] for i in comp)
        ys = [verts[v][1] for i in comp for v in flats[i][:3]]
        if max(ys) - min(ys) > 60 or area < 100 * 100:
            continue
        sides.append(math.sqrt(area))
        band = int(sum(ys) / len(ys) // 200)
        levels[band] = levels.get(band, 0) + area
    out["platform_side"] = sides
    total = sum(levels.values()) or 1.0
    out["levels"] = sum(1 for v in levels.values() if v / total >= 0.02)
    out["slope_share"] = round(slope_area / max(1.0, flat_area + slope_area), 3)
    top = {}
    flat = {}
    for a, b, c, n, _ in floors:
        P, Q, R = verts[a], verts[b], verts[c]
        x0, x1 = min(P[0], Q[0], R[0]), max(P[0], Q[0], R[0])
        z0, z1 = min(P[2], Q[2], R[2]), max(P[2], Q[2], R[2])
        for gx in range(int(math.ceil(x0 / grid)), int(math.floor(x1 / grid)) + 1):
            for gz in range(int(math.ceil(z0 / grid)), int(math.floor(z1 / grid)) + 1):
                px, pz = gx * grid, gz * grid
                if not _in_tri(px, pz, (P[0], P[2]), (Q[0], Q[2]), (R[0], R[2])):
                    continue
                y = _floor_y(px, pz, P, Q, R, n)
                if y is not None and y > top.get((gx, gz), -1e9):
                    top[(gx, gz)] = y
                    flat[(gx, gz)] = n[1] > 0.95
    rises = []
    for (gx, gz), y in top.items():
        for d in ((1, 0), (0, 1)):
            o = top.get((gx + d[0], gz + d[1]))
            if o is not None and flat.get((gx, gz)) and flat.get((gx + d[0], gz + d[1])):
                r = abs(o - y)
                if 25 <= r <= 1500:
                    rises.append(r)
    out["step_rise"] = rises
    walk = set(top)
    edge = set()
    for c in walk:
        y = top[c]
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = (c[0] + d[0], c[1] + d[1])
            if m not in walk or abs(top[m] - y) > 200:
                edge.add(c)
                break
    dist = {c: 0 for c in edge}
    frontier = list(edge)
    while frontier:
        nxt = []
        for c in frontier:
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                m = (c[0] + d[0], c[1] + d[1])
                if m in walk and m not in dist and abs(top[m] - top[c]) <= 200:
                    dist[m] = dist[c] + 1
                    nxt.append(m)
        frontier = nxt
    widths = []
    for c, k in dist.items():
        if all(dist.get((c[0] + d[0], c[1] + d[1]), -1) <= k
               for d in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            widths.append((2 * k + 1) * grid)
    out["path_width"] = widths
    if top:
        xs = [c[0] for c in top]
        zs = [c[1] for c in top]
        out["span_xz"] = max(max(xs) - min(xs), max(zs) - min(zs)) * grid
        out["span_y"] = round(max(top.values()) - min(top.values()))
    out["floor_area_cells"] = len(top)
    return out
def pct(values, p):
    if not values:
        return None
    v = sorted(values)
    k = (len(v) - 1) * p / 100.0
    f = int(math.floor(k))
    c = min(len(v) - 1, f + 1)
    return round(v[f] + (v[c] - v[f]) * (k - f), 1)
def summary(values):
    return {"n": len(values), "p": {str(p): pct(values, p) for p in PCTS}}
def build(decomp):
    per = {}
    pooled = {s: [] for s in STATS}
    scalars = {"slope_share": [], "levels": [], "span_xz": [], "span_y": []}
    for course in COURSES:
        areas = os.path.join(decomp, "levels", course, "areas")
        if not os.path.isdir(areas):
            continue
        for area in sorted(os.listdir(areas)):
            path = os.path.join(areas, area, "collision.inc.c")
            if not os.path.exists(path):
                continue
            verts, tris = read_collision(path)
            if len(tris) < 50:
                continue
            m = measure_area(verts, tris)
            key = "%s/%s" % (course, area)
            row = {s: summary(m[s]) for s in STATS}
            for k in scalars:
                if k in m:
                    row[k] = m[k]
                    scalars[k].append(m[k])
            per[key] = row
            for s in STATS:
                pooled[s] += m[s]
    course_wide = {}
    for s in STATS:
        course_wide[s] = {str(p): pct([r[s]["p"][str(p)] for r in per.values()
                                       if r[s]["p"][str(p)] is not None], 50) for p in PCTS}
    return {
        "_about": "SM64's own level geometry (the decomp's collision, 15 courses and the castle "
                  "grounds), read by tools/mapgen/refstats.py - numbers only. A distribution, "
                  "never one map: no single map is the yardstick. Units are "
                  "the game's (Mario 160 tall).",
        "stats": list(STATS),
        "percentiles": list(PCTS),
        "median_of_areas": course_wide,
        "scalars": {k: {"p": {str(p): pct(v, p) for p in PCTS}, "n": len(v)}
                    for k, v in scalars.items()},
        "areas": per,
    }
def load():
    with open(OUT, encoding="utf-8") as fh:
        return json.load(fh)
def measure(arena):
    from . import v1
    m = v1.arenas_module()
    verts, tris = [], []
    def quad(a, b, c, d):
        i = len(verts)
        verts.extend([a, b, c, d])
        tris.append((i, i + 1, i + 2, "SURFACE_DEFAULT"))
        tris.append((i, i + 2, i + 3, "SURFACE_DEFAULT"))
    for p in arena.get("pieces") or []:
        if p.get("tex") == "invisible" or p.get("kind") == "water":
            continue
        x0, x1, z0, z1, up = m.footprint(p)
        y0, y1 = p["y"], p["y"] + p["h"]
        if p["kind"] in ("ramp", "stairs"):
            if up[0] > 0:
                quad((x0, y0, z0), (x0, y0, z1), (x1, y1, z1), (x1, y1, z0))
            elif up[0] < 0:
                quad((x1, y0, z0), (x0, y1, z0), (x0, y1, z1), (x1, y0, z1))
            elif up[1] > 0:
                quad((x0, y0, z0), (x0, y1, z1), (x1, y1, z1), (x1, y0, z0))
            else:
                quad((x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z0))
        else:
            quad((x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0))
        for (a, b) in (((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)),
                       ((x0, z1), (x0, z0))):
            if y1 - y0 >= 20 and p["kind"] not in ("ramp", "stairs"):
                quad((a[0], y0, a[1]), (a[0], y1, a[1]), (b[0], y1, b[1]), (b[0], y0, b[1]))
    if not tris:
        return {}
    return measure_area(verts, tris)
def placement(value, dist):
    if value is None or not dist:
        return None
    keys = [int(k) for k in sorted(dist, key=int)]
    if dist[str(keys[0])] is not None and value < dist[str(keys[0])]:
        return "under p%d" % keys[0]
    for a, b in zip(keys, keys[1:]):
        if dist[str(a)] is not None and dist[str(b)] is not None and dist[str(a)] <= value <= dist[str(b)]:
            return "p%d-p%d" % (a, b)
    return "over p%d" % keys[-1]
def compare(arena, ref=None):
    ref = ref or load()
    mine = measure(arena)
    out = {}
    for s in STATS:
        v = pct(mine.get(s) or [], 50)
        out[s] = {"map": v, "sm64": ref["median_of_areas"][s],
                  "where": placement(v, ref["median_of_areas"][s])}
    for k in ("slope_share", "levels"):
        if k in mine:
            out[k] = {"map": mine[k], "sm64": ref["scalars"][k]["p"],
                      "where": placement(mine[k], ref["scalars"][k]["p"])}
    return out
USAGE = """Reference statistics from SM64's own level geometry.

    python3 tools/mapgen/refstats.py build DECOMP_DIR   read the decomp's level
        collision (levels/<course>/areas/<n>/collision.inc.c, read-only) and
        write reference/sm64_geometry.json - numbers only, no geometry
    python3 tools/mapgen/refstats.py show"""
def main(argv):
    if not argv or argv[0] not in ("build", "show"):
        print(USAGE)
        return 2
    if argv[0] == "build":
        if len(argv) < 2:
            print("refstats build DECOMP_DIR")
            return 2
        data = build(argv[1])
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=1, sort_keys=True)
            fh.write("\n")
        print("wrote %s (%d course areas)" % (OUT, len(data["areas"])))
        return 0
    data = load()
    for s in STATS:
        print("%-14s %s" % (s, data["median_of_areas"][s]))
    for k, v in data["scalars"].items():
        print("%-14s %s" % (k, v["p"]))
    return 0
if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(HERE))
    sys.exit(main(sys.argv[1:]))
