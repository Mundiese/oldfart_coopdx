import copy
import math
from studio.editor import geometry as geo
from studio.editor.commands import Change
FACES = ("+x", "-x", "+y", "-y", "+z", "-z")
STRETCHY = ("box", "ice", "water")
MIN_H = 20
FACE_WORDS = {"+x": "east (+x)", "-x": "west (-x)", "+y": "top", "-y": "bottom",
              "+z": "south (+z)", "-z": "north (-z)"}
def face_at(box_or_piece, point):
    b = box_or_piece if isinstance(box_or_piece, tuple) else geo.aabb(box_or_piece)
    x, y, z = point
    dist = {"-x": abs(x - b[0]), "+x": abs(x - b[1]), "-y": abs(y - b[2]),
            "+y": abs(y - b[3]), "-z": abs(z - b[4]), "+z": abs(z - b[5])}
    return min(FACES, key=lambda f: (dist[f], FACES.index(f)))
def piece_at(doc, point, slack=1.0):
    x, y, z = point
    best = None
    for r in doc.refs("piece"):
        b = geo.aabb(doc.get(r))
        if b[0] - slack <= x <= b[1] + slack and b[2] - slack <= y <= b[3] + slack and \
                b[4] - slack <= z <= b[5] + slack:
            vol = (b[1] - b[0]) * (b[3] - b[2]) * (b[5] - b[4])
            if best is None or vol < best[0]:
                best = (vol, r)
    return best[1] if best else None
def _field(piece, axis):
    if axis == "y":
        return "h"
    turned = geo.yaw_of(piece) in (90, 270)
    if axis == "x":
        return "d" if turned else "w"
    return "w" if turned else "d"
def grown(piece, face, amount):
    axis, sign = face[1], (1 if face[0] == "+" else -1)
    out = dict(piece)
    field = _field(piece, axis)
    size = out[field] + amount
    if axis == "y":
        if size < MIN_H:
            return None
        out["h"] = size
        if sign < 0:
            out["y"] = out.get("y", 0) - amount
    else:
        if size < geo.GRID:
            return None
        out[field] = size
        out[axis] = out.get(axis, 0) + sign * amount / 2.0
    return geo.cleaned(out)
def push_face(doc, refs, face, cells=1):
    if face not in FACES or not cells:
        return Change("Push a face")
    step = geo.YGRID if face[1] == "y" else geo.GRID
    steps, kept, gone = [], [], 0
    for r in refs:
        p = doc.get(r)
        if r[0] != "piece" or p is None:
            continue
        if p.get("kind") not in STRETCHY:
            kept.append(p.get("kind"))
            continue
        new = grown(p, face, cells * step)
        if new is None:
            gone += 1
            continue
        if new != p:
            steps.append(("replace", r, copy.deepcopy(p), new))
    verb = "Push" if cells > 0 else "Pull"
    label = "%s the %s face %s %d %s" % (verb, FACE_WORDS[face], "out" if cells > 0 else "in",
                                         abs(cells), ("step" if face[1] == "y" else "cell")
                                         + ("" if abs(cells) == 1 else "s"))
    ch = Change(label, steps, select=list(refs))
    ch.kept = sorted(set(k for k in kept if k))
    ch.too_small = gone
    return ch
def push_pull(doc, refs, point, out=True):
    pieces = [r for r in refs if r[0] == "piece" and doc.get(r) is not None]
    if not pieces and point is not None:
        hit = piece_at(doc, point)
        pieces = [hit] if hit else []
    if not pieces or point is None:
        return Change("Push a face"), None
    box = geo.union(geo.aabb(doc.get(r)) for r in pieces)
    face = face_at(box, point)
    axis = {"x": (0, 1), "y": (2, 3), "z": (4, 5)}[face[1]]
    edge = box[axis[1]] if face[0] == "+" else box[axis[0]]
    slot = axis[1] if face[0] == "+" else axis[0]
    on_face = [r for r in pieces if abs(geo.aabb(doc.get(r))[slot] - edge) < 0.5]
    return push_face(doc, on_face, face, 1 if out else -1), face
def push_note(ch, face):
    if face is None:
        return "Point at a face of a box (select it, or have the mouse on it) and press E"
    if not ch:
        why = []
        if getattr(ch, "kept", None):
            why.append("%s come at fixed sizes - change those in Properties" % ", ".join(ch.kept))
        if getattr(ch, "too_small", 0):
            why.append("one cell is the smallest a box gets")
        return "Nothing to push: " + ("; ".join(why) if why else "select a box")
    extra = ""
    if getattr(ch, "kept", None):
        extra = " (%s kept - fixed sizes)" % ", ".join(ch.kept)
    return ch.label + extra
VARIANT_FAMILIES = (
    ("ramp", "outer", "inner", "stairs", "outerstairs", "innerstairs"),
    ("ridge", "pyramid"),
    ("curve", "bank", "arcwall", "roundcorner"),
    ("box", "prism", "arch"),
)
SQUARE_ONLY = ("outer", "inner", "outerstairs", "innerstairs", "pyramid", "curve", "bank",
               "arcwall", "roundcorner", "prism")
def family_of(kind):
    for fam in VARIANT_FAMILIES:
        if kind in fam:
            return fam
    return None
def next_variant(piece, step=1):
    fam = family_of(piece.get("kind"))
    if fam is None:
        return None
    square = piece.get("w") == piece.get("d")
    i = fam.index(piece["kind"])
    for k in range(1, len(fam)):
        kind = fam[(i + k * (1 if step >= 0 else -1)) % len(fam)]
        if kind in SQUARE_ONLY and not square:
            continue
        return kind
    return None
def cycle_variant(doc, refs, step=1):
    steps, names = [], []
    for r in refs:
        p = doc.get(r)
        if r[0] != "piece" or p is None:
            continue
        kind = next_variant(p, step)
        if kind is None:
            continue
        new = dict(p, kind=kind)
        steps.append(("replace", r, copy.deepcopy(p), new))
        names.append(kind)
    if not steps:
        return Change("Next variant")
    label = "Variant: %s" % (names[0] if len(set(names)) == 1 else
                             "%d pieces" % len(names))
    return Change(label, steps, select=list(refs))
def _hash01(*vals):
    h = 2166136261
    for v in vals:
        for byte in int(round(v)).to_bytes(8, "little", signed=True):
            h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5bd1e995) & 0xFFFFFFFF
    h ^= h >> 15
    return h / 4294967296.0
def _centre(p, axis):
    if axis == "y":
        return p.get("y", 0) + p.get("h", 0) / 2.0
    return p.get(axis, 0)
def gradient_pick(texs, t, x, z, seed=0):
    if len(texs) == 1:
        return texs[0]
    t = min(1.0, max(0.0, t))
    pos = t * (len(texs) - 1)
    i = min(int(pos), len(texs) - 2)
    frac = pos - i
    return texs[i + 1] if _hash01(x // geo.GRID, z // geo.GRID, seed) < frac else texs[i]
def gradient(doc, refs, texs, axis="y", seed=0):
    texs = [t for t in texs if t]
    pieces = [(r, doc.get(r)) for r in refs if r[0] == "piece" and doc.get(r) is not None]
    if len(texs) < 2 or not pieces:
        return Change("Gradient")
    cs = [_centre(p, axis) for _, p in pieces]
    lo, hi = min(cs), max(cs)
    steps = []
    for (r, p), c in zip(pieces, cs):
        t = 0.5 if hi == lo else (c - lo) / float(hi - lo)
        tex = gradient_pick(texs, t, p.get("x", 0), p.get("z", 0) + p.get("y", 0), seed)
        if tex != p.get("tex"):
            new = dict(p, tex=tex)
            for k in ("tex_top", "tex_side", "tex_bottom"):
                new.pop(k, None)
            steps.append(("replace", r, copy.deepcopy(p), new))
    return Change("Gradient %s by %s" % (" -> ".join(texs), "height" if axis == "y" else axis),
                  steps, select=list(refs))
def value_noise(x, z, patch, seed=0):
    patch = max(1.0, float(patch))
    gx, gz = x / patch, z / patch
    ix, iz = math.floor(gx), math.floor(gz)
    fx, fz = gx - ix, gz - iz
    sx, sz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    a = _hash01(ix, iz, seed)
    b = _hash01(ix + 1, iz, seed)
    c = _hash01(ix, iz + 1, seed)
    d = _hash01(ix + 1, iz + 1, seed)
    return (a * (1 - sx) + b * sx) * (1 - sz) + (c * (1 - sx) + d * sx) * sz
def noise_pick(texs, share, x, y, z, patch, seed=0):
    if len(texs) < 2:
        return texs[0]
    v = value_noise(x, z + y * 0.5, patch, seed)
    if v < 1.0 - share:
        return texs[0]
    if len(texs) == 2:
        return texs[1]
    w = value_noise(x + 7919, z - 104729, patch * 0.5, seed + 1)
    return texs[1 + min(len(texs) - 2, int(w * (len(texs) - 1)))]
def noise(doc, refs, texs, share=0.35, patch=600, seed=1):
    texs = [t for t in texs if t]
    pieces = [(r, doc.get(r)) for r in refs if r[0] == "piece" and doc.get(r) is not None]
    if len(texs) < 2 or not pieces:
        return Change("Noise")
    share = min(1.0, max(0.0, share))
    steps = []
    for r, p in pieces:
        tex = noise_pick(texs, share, p.get("x", 0), p.get("y", 0), p.get("z", 0), patch, seed)
        if tex != p.get("tex"):
            new = dict(p, tex=tex)
            for k in ("tex_top", "tex_side", "tex_bottom"):
                new.pop(k, None)
            steps.append(("replace", r, copy.deepcopy(p), new))
    return Change("Noise %s (%d%%)" % (" + ".join(texs), round(100 * share)), steps,
                  select=list(refs))
ROOM_MIN = 3 * geo.GRID
DOOR_W = geo.GRID
DOOR_H = 400
def _box(tex, x0, x1, y0, y1, z0, z1, tag="room"):
    return {"kind": "box", "tex": tex, "x": (x0 + x1) / 2.0, "y": y0, "z": (z0 + z1) / 2.0,
            "w": x1 - x0, "h": y1 - y0, "d": z1 - z0, "yaw": 0, "tag": tag}
def _wall_run(tex, axis, a0, a1, fixed0, fixed1, y0, y1, door):
    def piece(b0, b1, lo, hi):
        if axis == "x":
            return _box(tex, b0, b1, lo, hi, fixed0, fixed1)
        return _box(tex, fixed0, fixed1, lo, hi, b0, b1)
    if not door or a1 - a0 < DOOR_W + 2 * geo.GRID:
        return [piece(a0, a1, y0, y1)]
    mid = geo.snap((a0 + a1) / 2.0 - DOOR_W / 2.0, geo.GRID)
    g0, g1 = mid, mid + DOOR_W
    out = [piece(a0, g0, y0, y1), piece(g1, a1, y0, y1)]
    if y1 - y0 > DOOR_H:
        out.append(piece(g0, g1, y0 + DOOR_H, y1))
    return out
def metres(units):
    m = units / 100.0
    return ("%d m" % round(m)) if abs(m - round(m)) < 0.05 else ("%.1f m" % m)
def room(x0, x1, z0, z1, y, wall_tex, floor_tex=None, height=600, thick=200,
         doors=("+z",), roof=False, roof_tex=None, floor=True):
    x0, x1 = sorted((geo.snap(x0, geo.GRID), geo.snap(x1, geo.GRID)))
    z0, z1 = sorted((geo.snap(z0, geo.GRID), geo.snap(z1, geo.GRID)))
    y = geo.snap(y, geo.YGRID)
    if x1 - x0 < ROOM_MIN or z1 - z0 < ROOM_MIN:
        return [], "A room needs at least 3 x 3 cells - drag a bigger rectangle"
    height = max(geo.YGRID * 4, geo.snap(height, geo.YGRID))
    t = thick
    out = []
    y1 = y + height
    out += _wall_run(wall_tex, "x", x0, x1, z0, z0 + t, y, y1, "-z" in doors)
    out += _wall_run(wall_tex, "x", x0, x1, z1 - t, z1, y, y1, "+z" in doors)
    out += _wall_run(wall_tex, "z", z0 + t, z1 - t, x0, x0 + t, y, y1, "-x" in doors)
    out += _wall_run(wall_tex, "z", z0 + t, z1 - t, x1 - t, x1, y, y1, "+x" in doors)
    if floor:
        out.append(_box(floor_tex or wall_tex, x0 + t, x1 - t, y - 50, y, z0 + t, z1 - t))
    if roof:
        out.append(_box(roof_tex or wall_tex, x0, x1, y1, y1 + 50, z0, z1))
    out = [geo.cleaned(p) for p in out]
    note = "Room %d x %d cells (%s x %s), %s high, %d door%s%s" % (
        (x1 - x0) // geo.GRID, (z1 - z0) // geo.GRID, metres(x1 - x0), metres(z1 - z0),
        metres(height), len(doors), "" if len(doors) == 1 else "s",
        ", roofed" if roof else "")
    return out, note
def room_change(doc, rect, y, wall_tex, **kw):
    from studio.editor import ops
    pieces, note = room(rect[0], rect[1], rect[2], rect[3], y, wall_tex, **kw)
    from studio.editor import rooms
    pieces = rooms.level_floor_free(doc, pieces)
    if not pieces:
        return Change(note), note
    return ops.insert(doc, [("piece", p) for p in pieces], note), note
REACH_CLASSES = (
    ("walk", "walk on", (0.36, 0.84, 0.47, 0.95)),
    ("drop", "a safe drop", (0.55, 0.80, 0.95, 0.95)),
    ("jump", "one jump", (0.80, 0.90, 0.35, 0.95)),
    ("double", "a double jump", (0.98, 0.80, 0.25, 0.95)),
    ("triple", "a triple jump or a ledge grab", (0.98, 0.58, 0.20, 0.95)),
    ("hurts", "a drop that hurts", (0.95, 0.45, 0.65, 0.95)),
    ("kick", "wall kicks only", (0.75, 0.50, 0.95, 0.95)),
    ("out", "out of reach", (0.92, 0.30, 0.30, 0.95)),
)
RANK = {k: n for n, (k, _, _) in enumerate(REACH_CLASSES)}
WORDS = {k: w for k, w, _ in REACH_CLASSES}
COLOUR = {k: c for k, _, c in REACH_CLASSES}
NEAR = 1000
def _mv():
    from mapgen import movement
    return movement
def thresholds():
    m = _mv()
    return {"walk": m.STEP_MAX, "jump": m.land_reach("single_run"),
            "double": m.land_reach("double_run"),
            "triple": max(m.land_reach("triple_run"), m.REACH),
            "drop_safe": m.DROP_SAFE}
def reach_class(rise, wall_near=False):
    t = thresholds()
    if rise < 0:
        return "hurts" if -rise > t["drop_safe"] else ("walk" if -rise <= t["walk"] else "drop")
    if rise <= t["walk"]:
        return "walk"
    if rise <= t["jump"]:
        return "jump"
    if rise <= t["double"]:
        return "double"
    if rise <= t["triple"]:
        return "triple"
    return "kick" if wall_near else "out"
def _gap(a, b):
    dx = max(0.0, max(a[0], b[0]) - min(a[1], b[1]))
    dz = max(0.0, max(a[4], b[4]) - min(a[5], b[5]))
    return math.hypot(dx, dz)
def ghost_reach(doc, pieces, skip=()):
    boxes = [geo.aabb(p) for p in pieces if not geo.is_point(p)]
    if not boxes:
        return None
    g = geo.union(boxes)
    top = g[3]
    m = _mv()
    skip = set(skip)
    best = None
    wall_near = False
    for r in doc.refs("piece"):
        if r in skip:
            continue
        b = geo.aabb(doc.get(r))
        gap = _gap(g, b)
        if gap > NEAR:
            continue
        if b[3] > top + m.STEP_MAX and gap <= m.CHIMNEY_MAX:
            wall_near = True
        if b[4] < g[5] and g[4] < b[5] and b[0] < g[1] and g[0] < b[1] and b[3] <= g[2] + 1:
            continue
        rise = top - b[3]
        cls = "out" if rise > 0 and gap > 0 and rise > m.reach_at(gap) else reach_class(rise)
        above = 1 if rise < -m.STEP_MAX else 0
        cand = (above, RANK[cls], abs(rise), cls, rise, b[3])
        if best is None or cand < best:
            best = cand
    if best is None:
        rise = top - 0
        cls = reach_class(rise)
        best = (0, RANK[cls], abs(rise), cls, rise, 0)
    cls, rise, from_top = best[3], best[4], best[5]
    if cls == "out" and wall_near:
        cls = "kick"
    line = "Top %d %s the floor beside it: %s" % (
        abs(rise), "above" if rise >= 0 else "below", WORDS[cls])
    return {"cls": cls, "words": WORDS[cls], "rgba": COLOUR[cls], "rise": rise, "top": top,
            "from": from_top, "box": g, "line": line}
def reach_layer(info, title="Reach"):
    from .overlays import Layer
    layer = Layer("reach", title)
    if not info:
        return layer
    b, y, c = info["box"], info["top"] + 2, info["rgba"]
    corners = ((b[0], y, b[4]), (b[1], y, b[4]), (b[1], y, b[5]), (b[0], y, b[5]))
    for i in range(4):
        layer.line(corners[i], corners[(i + 1) % 4], c, 3.0)
    layer.label(((b[0] + b[1]) / 2.0, y + 60, (b[4] + b[5]) / 2.0), info["words"], c)
    return layer
NOTE_MAX = 200
def notes(doc):
    return [dict(n) for n in (doc.meta.get("notes") or [])]
def _notes_change(doc, after, label):
    before = doc.meta.get("notes")
    after = after or None
    if after == before:
        return Change(label)
    return Change(label, [("meta", "notes", copy.deepcopy(before), copy.deepcopy(after))],
                  hand=False)
def add_note(doc, point, text):
    text = " ".join(str(text or "").split())[:NOTE_MAX]
    if not text:
        return Change("Note")
    have = notes(doc)
    nid = max([n.get("id", 0) for n in have] + [0]) + 1
    x, y, z = point
    have.append({"id": nid, "x": int(round(x)), "y": int(round(y)), "z": int(round(z)),
                 "text": text})
    return _notes_change(doc, have, "Note %d" % nid)
def edit_note(doc, nid, text):
    text = " ".join(str(text or "").split())[:NOTE_MAX]
    have = notes(doc)
    for n in have:
        if n.get("id") == nid:
            if not text:
                return remove_note(doc, nid)
            n["text"] = text
    return _notes_change(doc, have, "Edit note %d" % nid)
def remove_note(doc, nid):
    have = [n for n in notes(doc) if n.get("id") != nid]
    return _notes_change(doc, have, "Remove note %d" % nid)
def note_near(doc, point, radius=300):
    best = None
    for n in notes(doc):
        d = math.hypot(n["x"] - point[0], n["z"] - point[2])
        if d <= radius and (best is None or d < best[0]):
            best = (d, n)
    return best[1] if best else None
def notes_layer(doc):
    from .overlays import Layer
    layer = Layer("notes", "Notes")
    for n in notes(doc):
        p = (n["x"], n["y"] + 40, n["z"])
        layer.dot(p, (1.0, 0.86, 0.35, 1.0), 7.0)
        layer.label((n["x"], n["y"] + 120, n["z"]), "%d: %s" % (n["id"], n["text"]),
                    (1.0, 0.92, 0.6, 1.0))
    return layer
