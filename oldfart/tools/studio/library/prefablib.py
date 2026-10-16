import contextlib
import io
import os
from . import tool
CELL = 200
def prefabs():
    return tool("prefabs")
def entries():
    pf = prefabs()
    out = []
    for key, p in pf.load_all().items():
        x0, x1, z0, z1, h = pf.footprint(p)
        try:
            _, skipped = pf.arena_pieces(p)
        except Exception:
            skipped = []
        out.append({"key": key, "name": p.get("name", key), "tags": list(p.get("tags", [])),
                    "size": (x1 - x0 + 1, h, z1 - z0 + 1), "pieces": len(p.get("pieces", [])),
                    "connectors": list(p.get("connectors", [])), "roles": dict(p.get("roles", {})),
                    "forge_only": len(skipped)})
    return out
def search(items, text):
    from studio.editor.palette import _fold
    words = [_fold(w) for w in (text or "").split() if w]
    out = []
    for e in items:
        hay = _fold(" ".join([e["name"], e["key"]] + e["tags"]))
        if all(w in hay for w in words):
            out.append(e)
    return out
def thumb_pieces(key, theme=None):
    pf = prefabs()
    pieces, _ = pf.arena_pieces(pf.get(key), (0, 0, 0), 0, theme)
    return pieces
def _extents(p):
    sideways = int(p.get("yaw", 0)) % 180 == 90
    xs = p["d"] if sideways else p["w"]
    zs = p["w"] if sideways else p["d"]
    return (p["x"] - xs / 2.0, p["x"] + xs / 2.0, p["y"], p["y"] + p["h"],
            p["z"] - zs / 2.0, p["z"] + zs / 2.0)
def _cells(a, b):
    if (a + 100) % CELL or (b + 100) % CELL or b <= a:
        return None
    return list(range(int((a + 100) // CELL), int((b + 100) // CELL)))
def _quarter_for(pf, test):
    for q in range(4):
        if test(q):
            return q
    return None
def from_pieces(pieces):
    if not pieces:
        return [], []
    low = min(p["y"] for p in pieces)
    dy = -(low % CELL)
    def phase(axis):
        votes = {}
        for p in pieces:
            x0, x1, _, _, z0, z1 = _extents(p)
            lo, hi = (x0, x1) if axis == "x" else (z0, z1)
            if (hi - lo) % CELL:
                continue
            shift = (100 - lo) % CELL
            votes[shift] = votes.get(shift, 0) + 1
        if not votes:
            return 0
        best = max(votes.items(), key=lambda kv: (kv[1], -kv[0]))[0]
        return best if best in (0, 100) else 0
    dx, dz = phase("x"), phase("z")
    moved = [dict(p, x=p["x"] + dx, y=p["y"] + dy, z=p["z"] + dz) for p in pieces]
    return _from_pieces(moved)
def _sized(x, y, z, shape, tex, q, flip, sx, sy, sz):
    pf = prefabs()
    w, h, d = (sz, sy, sx) if q % 2 else (sx, sy, sz)
    most = getattr(pf, "STRETCH_MAX", (1, 1, 1))
    if (sx, sy, sz) == (1, 1, 1):
        return [[x, y, z, shape, tex, q, flip]]
    if w <= most[0] and h <= most[1] and d <= most[2]:
        return [[x, y, z, shape, tex, q, flip, [sx, sy, sz]]]
    return [[x + i, y + j, z + k, shape, tex, q, flip]
            for i in range(sx) for j in range(sy) for k in range(sz)]
def _from_pieces(pieces):
    pf = prefabs()
    sl = pf.slopes()
    corner_of = {v: k for k, v in _corners().items()}
    rises_of = {v: k for k, v in _rises().items()}
    cells, skipped = [], []
    for i, p in enumerate(pieces):
        kind = p.get("kind")
        x0, x1, y0, y1, z0, z1 = _extents(p)
        cx, cz = _cells(x0, x1), _cells(z0, z1)
        tex = p.get("tex")
        one = cx is not None and cz is not None and len(cx) == 1 and len(cz) == 1
        h = y1 - y0
        if kind == "box":
            if cx is None or cz is None:
                skipped.append((i, "a box off the Forge's 200 grid"))
                continue
            if y0 % CELL == 0 and h % CELL == 0:
                cells += _sized(cx[0], int(y0 // CELL), cz[0], "cube", tex, 0, False,
                                len(cx), int(h // CELL), len(cz))
                continue
            flat = {(0, 100): ("slab", False), (100, 100): ("slab", True),
                    (0, 20): ("plate", False), (180, 20): ("plate", True)}.get((y0 % CELL, h))
            if flat:
                cells += _sized(cx[0], int(y0 // CELL), cz[0], flat[0], tex, 0, flat[1],
                                len(cx), 1, len(cz))
                continue
            skipped.append((i, "a box %d high at %d: the Forge stacks whole cells, slabs and "
                            "plates" % (h, y0)))
            continue
        if kind in ("ridge", "pyramid") and one and y0 % CELL == 0 and h == sl.RIDGE_HIGH:
            q = 0 if kind == "pyramid" or int(p.get("yaw", 0)) % 180 == 0 else 1
            cells.append([cx[0], int(y0 // CELL), cz[0], kind, tex, q, False])
            continue
        if kind in ("ramp", "stairs") and not one and cx is not None and cz is not None \
                and y0 % CELL == 0 and h % CELL == 0:
            rises = rises_of.get(int(p.get("yaw", 0)) % 360)
            q = _quarter_for(pf, lambda q: pf.DIR[pf.turned(0, -1, q)] == rises)
            if q is not None:
                cells += _sized(cx[0], int(y0 // CELL), cz[0],
                                "slope" if kind == "ramp" else "stairs", tex, q, False,
                                len(cx), int(h // CELL), len(cz))
                continue
        if not one or y0 % CELL or h != CELL:
            if kind == "pillar" and y0 % CELL == 0 and h % CELL == 0 and \
                    abs(p["w"] - CELL) < 1 and (p["x"] % CELL == 0) and \
                    (p["z"] % CELL == 0):
                for gy in range(int(y0 // CELL), int(y1 // CELL)):
                    cells.append([int(p["x"] // CELL), gy, int(p["z"] // CELL), "pillar", tex, 0,
                                  False])
                continue
            if kind == "rail" and h == sl.FENCE_HIGH and y0 % CELL == 0:
                along_x = int(p.get("yaw", 0)) % 180 == 0
                t = sl.FENCE_THICK // 2
                if along_x and cx is not None and abs((z0 + z1) / 2.0 % CELL) < 1 and \
                        z1 - z0 == 2 * t:
                    for gx in cx:
                        cells.append([gx, int(y0 // CELL), int(round((z0 + z1) / 2.0 / CELL)),
                                      "fence", tex, 0, False])
                    continue
                if not along_x and cz is not None and abs((x0 + x1) / 2.0 % CELL) < 1 and \
                        x1 - x0 == 2 * t:
                    for gz in cz:
                        cells.append([int(round((x0 + x1) / 2.0 / CELL)), int(y0 // CELL), gz,
                                      "fence", tex, 1, False])
                    continue
            skipped.append((i, "a %s that is not one Forge cell (200 x 200 x 200)" % kind))
            continue
        gx, gy, gz = cx[0], int(y0 // CELL), cz[0]
        q = None
        shape = kind
        if kind in ("ramp", "stairs"):
            rises = rises_of.get(int(p.get("yaw", 0)) % 360)
            q = _quarter_for(pf, lambda q: pf.DIR[pf.turned(0, -1, q)] == rises)
            shape = "slope" if kind == "ramp" else "stairs"
        elif kind in ("outer", "inner", "outerstairs", "innerstairs", "prism", "roundcorner"):
            high = corner_of.get(int(p.get("yaw", 0)) % 360)
            q = _quarter_for(pf, lambda q: pf._corner(q) == high)
        elif kind == "arch":
            q = 0
        if q is None:
            skipped.append((i, "a %s the Forge has no shape for" % kind))
            continue
        cells.append([gx, gy, gz, shape, tex, q, False])
    return _wall_cells(pieces, cells, skipped)
BOXED = ("doorway", "window", "wallcross", "wallt", "wallcorner", "wall", "panel", "pole")
def _box_key(p):
    x0, x1, y0, y1, z0, z1 = _extents(p)
    return (p.get("tex"), round(x0), round(x1), round(y0), round(y1), round(z0), round(z1))
def _wall_cells(pieces, cells, skipped):
    pf = prefabs()
    left = {}
    for i, why in skipped:
        p = pieces[i]
        if p.get("kind") != "box":
            continue
        x0, x1, y0, y1, z0, z1 = _extents(p)
        cell = (int(round((x0 + x1) / 2.0 / CELL)), int(y0 // CELL),
                int(round((z0 + z1) / 2.0 / CELL)))
        left.setdefault((cell, p.get("tex")), {})[_box_key(p)] = i
    used = set()
    for (cell, tex), boxes in sorted(left.items(), key=lambda kv: (kv[0][0], str(kv[0][1]))):
        for shape in BOXED:
            for q in range(4):
                probe = {"key": "probe", "name": "probe", "roles": {},
                         "pieces": [[0, 0, 0, shape, tex, q, False]]}
                try:
                    laid, _ = pf.arena_pieces(probe, cell, 0)
                except Exception:
                    laid = []
                want = [_box_key(b) for b in laid]
                if want and all(k in boxes and boxes[k] not in used for k in want):
                    cells.append([cell[0], cell[1], cell[2], shape, tex, q, False])
                    used.update(boxes[k] for k in want)
    return cells, [(i, why) for i, why in skipped if i not in used]
def _corners():
    return _arenas().CORNERS
def _rises():
    return _arenas().RISES
_ARENAS = None
def _arenas():
    global _ARENAS
    if _ARENAS is None:
        from mapgen import v1
        _ARENAS = v1.arenas_module()
    return _ARENAS
def anchored(cells):
    if not cells:
        return []
    mx = min(c[0] for c in cells)
    my = min(c[1] for c in cells)
    mz = min(c[2] for c in cells)
    return [[c[0] - mx, c[1] - my, c[2] - mz] + list(c[3:]) for c in cells]
def textures_in(cells):
    out = []
    for c in cells:
        if c[4] not in out:
            out.append(c[4])
    return out
def with_roles(cells, roles):
    by_slug = {slug: role for role, slug in roles.items() if slug}
    return [c[:4] + (["@" + by_slug[c[4]]] if c[4] in by_slug else [c[4]]) + c[5:]
            for c in cells]
def connector_slots(cells):
    if not cells:
        return []
    every = [cell for c in cells for cell in prefabs().piece_cells(c)]
    x0, x1 = min(c[0] for c in every), max(c[0] for c in every)
    z0, z1 = min(c[2] for c in every), max(c[2] for c in every)
    out = []
    for x in range(x0, x1 + 1):
        out.append(((x, 0, z0), "-z"))
        out.append(((x, 0, z1), "+z"))
    for z in range(z0, z1 + 1):
        out.append(((x0, 0, z), "-x"))
        out.append(((x1, 0, z), "+x"))
    return out
def make(cells, name, tags=(), roles=None, connectors=()):
    roles = dict(roles or {})
    pieces = with_roles(anchored(cells), roles)
    return {"name": name, "tags": list(tags), "roles": {r: s for r, s in roles.items() if s},
            "pieces": pieces,
            "connectors": [{"at": list(at), "face": face, "kind": kind}
                           for at, face, kind in connectors]}
def faults(prefab, key=None):
    pf = prefabs()
    p = dict(prefab)
    p["key"] = key or pf.key_for(prefab.get("name", ""))
    return pf.faults_of(p)
def _quiet(fn, *args, **kwargs):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        got = fn(*args, **kwargs)
    return got, out.getvalue().strip()
def save(prefab, replace=False):
    pf = prefabs()
    key = pf.key_for(prefab["name"])
    path = pf.add(prefab, key, replace=replace)
    _, said = _quiet(pf.build, False)
    return key, "%s written; %s" % (os.path.relpath(path, pf.ROOT), said)
def edit(key, name=None, tags=None, roles=None, connectors=None):
    pf = prefabs()
    pf.update(key, name=name, tags=tags, roles=roles, connectors=connectors)
    _, said = _quiet(pf.build, False)
    return said
def delete(key):
    pf = prefabs()
    from . import trash
    trash.keep("prefab", "Prefab %s" % key, [os.path.join(pf.LIBRARY, key + ".prefab")])
    pf.delete(key)
    _, said = _quiet(pf.build, False)
    return said
def rebuild():
    _, said = _quiet(prefabs().build, False)
    return said
def import_save(path, name, roles=None):
    argv = ["import-save", path, "--name", name]
    if roles:
        argv += ["--roles", ",".join("%s=%s" % kv for kv in sorted(roles.items()) if kv[1])]
    code, said = _quiet(prefabs().main, argv)
    return code, said
def read_draft(path):
    pf = prefabs()
    return pf.parse_draft(pf.read_save(path))
def save_locations():
    home = os.path.expanduser("~")
    out = []
    for base in (os.path.join(home, ".local", "share", "sm64coopdx"),
                 os.path.join(home, ".local", "share", "sm64ex-coop")):
        sav = os.path.join(base, "sav")
        if os.path.isdir(sav):
            out.append(sav)
    return out
MERGEABLE = ("box",)
def _mergeable(p):
    return p.get("kind") in MERGEABLE and p.get("w", 0) % CELL == 0 and \
        p.get("d", 0) % CELL == 0 and \
        not any(k in p for k in ("tex_top", "tex_side", "tex_bottom"))
def merged(pieces):
    from mapgen import cells as mcells
    boxes = [p for p in pieces if _mergeable(p)]
    rest = [dict(p) for p in pieces if not _mergeable(p)]
    if len(boxes) < 2:
        return [dict(p) for p in pieces]
    tag = next((p.get("tag") for p in boxes if p.get("tag")), "")
    groups = {}
    for p in boxes:
        groups.setdefault(p["h"] if p["h"] % CELL else 0, []).append(p)
    out = []
    for _, group in sorted(groups.items()):
        for p in (mcells.CellGrid.from_pieces(group).to_pieces(disjoint=True)
                  if len(group) > 1 else group):
            p = dict(p)
            if tag:
                p["tag"] = tag
            out.append(p)
    return out + rest
def mirrored(pieces, axis="x"):
    from studio.editor import geometry as geo
    if axis not in ("x", "z") or not pieces:
        return [dict(p) for p in pieces]
    cx, cz = geo.centre_of(pieces)
    out = [geo.mirrored(p, axis, cx if axis == "x" else cz) for p in pieces]
    fx, fz = geo.resnap_after(pieces, out)
    return [geo.cleaned(geo.translated(p, fx, 0, fz)) for p in out]
def _supports(a, b):
    from studio.editor import geometry as geo
    ba, bb = geo.aabb(a), geo.aabb(b)
    return abs(bb[2] - ba[3]) < 1 and bb[0] < ba[1] and ba[0] < bb[1] and \
        bb[4] < ba[5] and ba[4] < bb[5]
def ruined(pieces, share=0.3, seed=1):
    from studio.toolbox.build import _hash01
    from studio.editor import geometry as geo
    share = max(0.0, min(0.9, float(share)))
    left = [dict(p) for p in pieces]
    if not left or share <= 0:
        return left
    ground = min(geo.aabb(p)[2] for p in left)
    top = max(geo.aabb(p)[3] for p in left)
    span = max(1.0, top - ground)
    want = int(round(share * sum(1 for p in left if geo.aabb(p)[2] > ground + 1)))
    def score(p):
        b = geo.aabb(p)
        return (b[3] - ground) / span + _hash01(p.get("x", 0), p.get("y", 0), p.get("z", 0),
                                                seed)
    for _ in range(want):
        free = [p for p in left if geo.aabb(p)[2] > ground + 1 and
                not any(q is not p and _supports(p, q) for q in left)]
        if not free:
            break
        left.remove(max(free, key=score))
    return left
def laid(pieces, opts=None):
    opts = opts or {}
    out = [dict(p) for p in pieces]
    if opts.get("merge", True):
        out = merged(out)
    if opts.get("mirror") in ("x", "z"):
        out = mirrored(out, opts["mirror"])
    if opts.get("ruin", 0) > 0:
        out = ruined(out, opts["ruin"], opts.get("seed", 1))
    return out
