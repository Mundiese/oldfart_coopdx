import copy
from . import geometry as geo
from .commands import Change, refusal
DIRECTIONS = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+y": (0, 1, 0), "-y": (0, -1, 0),
              "+z": (0, 0, 1), "-z": (0, 0, -1)}
def _items(doc, refs):
    return [(r, doc.get(r)) for r in refs if doc.get(r) is not None]
def _view_items(doc, refs):
    return [(r, doc.view_item(r)) for r in refs if doc.get(r) is not None]
def _replace_steps(doc, pairs):
    steps = []
    for ref, new in pairs:
        old = doc.get(ref)
        new = dict(new)
        new.pop("_at", None)
        if new != old:
            steps.append(("replace", ref, copy.deepcopy(old), copy.deepcopy(new)))
    return steps
def snapped_delta(dx, dy, dz, snap_on=True, step=geo.GRID, ystep=geo.YGRID):
    if not snap_on:
        return dx, dy, dz
    return geo.snap(dx, step), geo.snap(dy, ystep), geo.snap(dz, step)
def move(doc, refs, dx=0, dy=0, dz=0, snap_on=True, merge=None, label=None):
    dx, dy, dz = snapped_delta(dx, dy, dz, snap_on)
    if not (dx or dy or dz):
        return Change(label or "Move")
    pairs = [(r, geo.cleaned(geo.translated(i, dx, dy, dz))) for r, i in _view_items(doc, refs)]
    return Change(label or "Move %d item%s" % (len(pairs), "" if len(pairs) == 1 else "s"),
                  _replace_steps(doc, pairs), merge=merge, select=list(refs))
def nudge(doc, refs, direction, cells=1):
    vx, vy, vz = DIRECTIONS[direction]
    return move(doc, refs, vx * geo.GRID * cells, vy * geo.YGRID * cells, vz * geo.GRID * cells,
                merge=("nudge", tuple(sorted(refs))), label="Nudge %s" % direction)
def rotate(doc, refs, quarters=1, pivot=None):
    items = _view_items(doc, refs)
    if not items or quarters % 4 == 0:
        return Change("Turn")
    before = [i for _, i in items]
    if pivot is None:
        pivot = geo.centre_of(before)
    after = [geo.turned(i, quarters, pivot) for i in before]
    fx, fz = geo.resnap_after(before, after)
    after = [geo.cleaned(geo.translated(i, fx, 0, fz)) for i in after]
    q = quarters % 4
    label = "Turn a quarter" if q == 1 else ("Turn back a quarter" if q == 3 else "Turn half")
    return Change(label, _replace_steps(doc, zip([r for r, _ in items], after)),
                  select=list(refs))
def mirror(doc, refs, axis="x", pivot=None):
    if axis not in ("x", "z"):
        raise ValueError("mirror across x or z")
    items = _view_items(doc, refs)
    if not items:
        return Change("Mirror")
    before = [i for _, i in items]
    if pivot is None:
        cx, cz = geo.centre_of(before)
        pivot = cx if axis == "x" else cz
    after = [geo.mirrored(i, axis, pivot) for i in before]
    fx, fz = geo.resnap_after(before, after)
    after = [geo.cleaned(geo.translated(i, fx, 0, fz)) for i in after]
    return Change("Mirror across %s" % axis, _replace_steps(doc, zip([r for r, _ in items], after)),
                  select=list(refs))
def delete(doc, refs):
    with_index = [(doc.index_of(r), r) for r in refs if doc.get(r) is not None]
    steps = []
    for index, ref in sorted(with_index, key=lambda t: (t[1][0], -t[0])):
        steps.append(("remove", ref, index, copy.deepcopy(doc.get(ref))))
    n = len(steps)
    from . import groups
    steps += groups.prune_steps(doc, [r for _, r in with_index])
    return Change("Delete %d item%s" % (n, "" if n == 1 else "s"), steps, select=[])
def insert(doc, items, label, select=True):
    steps = []
    taken = {}
    refs = []
    for kind, item in items:
        item = dict(item)
        item.pop("_at", None)
        if kind == "anchor":
            iid = _fresh_anchor_id(doc, taken, item.get("what", "anchor"))
        else:
            iid = _fresh_id(doc, kind, taken)
        ref = (kind, iid)
        refs.append(ref)
        steps.append(("insert", ref, None, item))
    return Change(label, steps, select=refs if select else None)
def _fresh_id(doc, kind, taken):
    from .document import PREFIX
    have = set(i for i, _ in doc.items[kind]) | taken.setdefault(kind, set())
    n = doc._next[kind]
    while "%s%d" % (PREFIX[kind], n) in have:
        n += 1
    iid = "%s%d" % (PREFIX[kind], n)
    taken[kind].add(iid)
    return iid
def _fresh_anchor_id(doc, taken, what):
    have = set(a.get("id") for a in doc.anchors()) | taken.setdefault("anchor", set())
    n = 1
    while "%s%d" % (what, n) in have:
        n += 1
    iid = "%s%d" % (what, n)
    taken["anchor"].add(iid)
    return iid
def _with_groups(doc, change, pattern, copies=1):
    if not pattern:
        return change
    from . import groups
    new = [s[1] for s in change.steps if s[0] == "insert"]
    n = len(new) // max(1, copies)
    change.steps += groups.copies_steps(doc, [(pattern, new[k * n:(k + 1) * n])
                                              for k in range(copies)])
    return change
def duplicate(doc, refs, dx=0, dy=0, dz=0):
    from . import groups
    items = _view_items(doc, refs)
    dx, dy, dz = snapped_delta(dx, dy, dz)
    out = [(r[0], geo.cleaned(geo.translated(i, dx, dy, dz))) for r, i in items]
    change = insert(doc, out, "Duplicate %d item%s" % (len(out), "" if len(out) == 1 else "s"))
    return _with_groups(doc, change, groups.template(doc, [r for r, _ in items]))
def stack(doc, refs, count=2, direction="+x", gap=0):
    items = _view_items(doc, refs)
    if not items or count < 1:
        return Change("Stack")
    b = geo.grid_box([i for _, i in items])
    vx, vy, vz = DIRECTIONS[direction]
    sx = ((b[1] - b[0]) or geo.GRID) + gap * geo.GRID
    sy = ((b[3] - b[2]) or geo.POINT_TALL) + gap * geo.YGRID
    sz = ((b[5] - b[4]) or geo.GRID) + gap * geo.GRID
    out = []
    for k in range(1, count + 1):
        for r, i in items:
            out.append((r[0], geo.cleaned(geo.translated(i, vx * sx * k, vy * sy * k, vz * sz * k))))
    change = insert(doc, out, "Stack %d copies %s" % (count, direction))
    from . import groups
    change = _with_groups(doc, change, groups.template(doc, [r for r, _ in items]), count)
    change.select = list(refs) + (change.select or [])
    return change
def place(doc, items, cursor, snap_on=True, label="Place", anchor=None):
    if any(k == "setpiece" for k, _ in items):
        item = [i for k, i in items if k == "setpiece"][0]
        if item.get("kind") == "hall_house":
            return place_hall_house(doc, item, cursor, label)
        return place_setpiece(doc, item, cursor, label)
    pieces = [i for _, i in items]
    moved = geo.placed_at(pieces, cursor, snap_on, anchor=anchor)
    out = []
    for (k, _), m in zip(items, moved):
        if k == "star":
            m = dict(m, y=m.get("y", 0) + star_lift(),
                     id=next_star_number(doc, [x for kk, x in out if kk == "star"]))
            if not m.get("name"):
                m["name"] = "Bonus Star %d" % m["id"]
        if k == "object" and m.get("key") == "triblock":
            m = snap_triblock(doc, m)
        out.append((k, m))
    return insert(doc, out, label)
def place_setpiece(doc, item, cursor, label="Place set piece"):
    from mapgen import setpieces
    lay = doc.to_layout(models=False)
    arena = {"level": lay.get("level", "empty"), "pieces": lay.get("pieces") or [],
             "spawns": lay.get("spawns") or [], "objects": lay.get("objects") or [],
             "survey": lay.get("survey") or {}, "water": lay.get("water") or []}
    theme = item.get("theme") or (doc.brief or {}).get("theme")
    try:
        pieces, objs, water, why = setpieces.build_at(arena, item["kind"], cursor[0], cursor[2],
                                                      theme)
    except Exception as e:
        return refusal("%s: the ground here could not be read (%s)" % (label, e))
    if pieces is None:
        return refusal("%s: %s near here - try a wider, level spot" % (label, why))
    out = [("piece", p) for p in pieces]
    out += [("object", {k: o[k] for k in ("key", "x", "y", "z", "yaw") if k in o})
            for o in objs]
    ch = insert(doc, out, label)
    if water:
        before = copy.deepcopy(doc.rest.get("water"))
        ch.steps.append(("rest", "water", before, list(before or []) + [list(w) for w in water]))
    return ch
def place_hall_house(doc, item, cursor, label="Place a hall house"):
    from mapgen import pockets
    lay = doc.to_layout(models=False)
    arena = {"pieces": lay.get("pieces") or [], "pockets": lay.get("pockets") or []}
    theme = item.get("theme") or (doc.brief or {}).get("theme")
    try:
        pieces, rec = pockets.hall_house(arena, cursor[0], cursor[2], cursor[1], theme)
    except Exception as e:
        return refusal("%s: %s" % (label, e))
    if pieces is None:
        return refusal("%s: %s" % (label, rec))
    from mapgen import v1
    m = v1.arenas_module()
    for p in pieces:
        p["model"] = m.model_name(p)
    ch = insert(doc, [("piece", p) for p in pieces], label)
    before = copy.deepcopy(doc.rest.get("pockets"))
    ch.steps.append(("rest", "pockets", before, list(before or []) + [rec]))
    return ch
def snap_triblock(doc, obj):
    from mapgen import triblock
    lay = doc.to_layout(models=False)
    arena = {"level": lay.get("level", "empty"), "pieces": lay.get("pieces") or [],
             "objects": []}
    try:
        f = triblock.snap(arena, obj)
    except Exception:
        return obj
    if f is None:
        return obj
    out = dict(obj, x=int(round(f[0])), y=int(round(f[1])), z=int(round(f[2])), yaw=int(f[3]))
    out.pop("air", None)
    return out
STAR_NUMBERS = 6
def star_lift():
    from mapgen import gameplay
    return gameplay.STAR_LIFT
def next_star_number(doc, extra=()):
    used = set(s.get("id") for _, s in doc.items["star"]) | set(s.get("id") for s in extra)
    n = 1
    while n in used:
        n += 1
    return n
def set_star_number(doc, ref, number):
    number = int(number)
    if not 1 <= number <= STAR_NUMBERS:
        raise ValueError("a bonus star's number is 1 to %d" % STAR_NUMBERS)
    star = doc.get(ref)
    if star is None or star.get("id") == number:
        return Change("Star number")
    pairs = [(ref, dict(star, id=number))]
    for r in doc.refs("star"):
        other = doc.get(r)
        if r != ref and other.get("id") == number:
            pairs.append((r, dict(other, id=star.get("id"))))
    return Change("Star %d is now star %d" % (star.get("id", 0), number),
                  _replace_steps(doc, pairs), select=[ref])
def set_star_name(doc, ref, name):
    name = " ".join(str(name or "").split())[:40]
    star = doc.get(ref)
    if star is None or star.get("name") == name:
        return Change("Star name")
    return Change("Name star %d" % star.get("id", 0), _replace_steps(doc, [(ref, dict(
        star, name=name))]), select=[ref])
def set_fields(doc, refs, label=None, **fields):
    pairs = []
    for r, item in _items(doc, refs):
        new = dict(item)
        for k, v in fields.items():
            if k == "yaw" and r[0] == "piece":
                v = int(v) % 360
                if v not in (0, 90, 180, 270):
                    raise ValueError("only quarter turns (0, 90, 180, 270)")
            new[k] = v
        if r[0] == "piece" and any(k in fields for k in ("w", "d", "yaw")):
            b0 = geo.aabb(item)
            b1 = geo.aabb(new)
            new = geo.translated(new, b0[0] - b1[0], 0, b0[4] - b1[4])
        pairs.append((r, geo.cleaned(new)))
    name = label or "Set %s" % ", ".join(sorted(fields))
    return Change(name, _replace_steps(doc, pairs), select=list(refs))
def retexture(doc, refs, tex):
    pairs = []
    for r, item in _items(doc, refs):
        if r[0] != "piece":
            continue
        new = dict(item)
        new["tex"] = tex
        for k in ("tex_top", "tex_side", "tex_bottom"):
            new.pop(k, None)
        pairs.append((r, new))
    return Change("Paint %s" % tex, _replace_steps(doc, pairs), select=list(refs))
def set_brief(doc, changes, label="Change the brief"):
    before = copy.deepcopy(doc.brief)
    after = copy.deepcopy(doc.brief)
    defaulted = after.get("defaulted")
    for k, v in changes.items():
        if v is None:
            after.pop(k, None)
            if isinstance(defaulted, list) and k not in defaulted:
                defaulted.append(k)
        else:
            after[k] = copy.deepcopy(v)
            if isinstance(defaulted, list) and k in defaulted:
                defaulted.remove(k)
    if after == before:
        return Change(label)
    return Change(label, [("brief", before, after)], hand=False)
def set_rest(doc, key, value, label=None):
    before = copy.deepcopy(doc.rest.get(key))
    if before == value:
        return Change(label or "Set %s" % key)
    return Change(label or "Set %s" % key, [("rest", key, before, copy.deepcopy(value))])
def set_sun(doc, sun, label=None):
    from mapgen import bake
    look = copy.deepcopy(doc.rest.get("look") or {})
    want = bake.clean_sun(sun) if sun is not None else None
    if sun is not None and want is None:
        raise ValueError("not a sun: %r" % (sun,))
    if want is None:
        look.pop("sun", None)
    else:
        look["sun"] = want
    before = copy.deepcopy(doc.rest.get("look"))
    if (before or {}) == look:
        return Change(label or "Sun")
    if label is None:
        from studio.core import sungizmo
        label = sungizmo.label(want) if want else "Sun: the map's own"
        for name, p in bake.PRESETS.items():
            if want is not None and bake.clean_sun(p) == want:
                label = "Sun: %s" % name
    return Change(label, [("rest", "look", before, look)])
def set_mood(doc, mood, label=None):
    from mapgen import mood as moodmod
    look = copy.deepcopy(doc.rest.get("look") or {})
    want = moodmod.clean(mood) if mood else {}
    if want:
        look["mood"] = want
    else:
        look.pop("mood", None)
    before = copy.deepcopy(doc.rest.get("look"))
    if (before or {}) == look:
        return Change(label or "Weather")
    if label is None:
        label = "Weather: %s" % moodmod.label(want)
    return Change(label, [("rest", "look", before, look)])
def set_sky(doc, name):
    from mapgen import skies
    name = name or skies.AUTO
    if not skies.valid(name):
        raise ValueError("not a sky: %r" % (name,))
    look = copy.deepcopy(doc.rest.get("look") or {})
    theme = doc.brief.get("theme") if doc.brief.get("theme") not in (None, "auto") else None
    look["sky"] = skies.for_theme(theme or "castle") if name == skies.AUTO else name
    look.setdefault("music", "SEQ_LEVEL_GRASS")
    steps = []
    before = copy.deepcopy(doc.rest.get("look"))
    if before != look:
        steps.append(("rest", "look", before, look))
    brief = copy.deepcopy(doc.brief)
    if name == skies.AUTO:
        brief.pop("sky", None)
    else:
        brief["sky"] = name
    if brief != doc.brief:
        steps.append(("brief", copy.deepcopy(doc.brief), brief))
    return Change("Sky: %s" % skies.label(name), steps)
def set_boundary(doc, mode):
    from mapgen import boundary
    brief = copy.deepcopy(doc.brief)
    if mode in (None, "auto"):
        brief.pop("boundary", None)
    else:
        brief["boundary"] = mode
    layout = doc.to_layout(models=False)
    if mode in boundary.MODES:
        layout["pieces"], _ = boundary.restyle(layout.get("pieces") or [], mode)
    return replace_map(doc, brief, layout, "Map edge: %s" % (mode or "auto"))
def replace_map(doc, brief, layout, label, ids=None, meta=None):
    before = doc.state()
    after = {"brief": copy.deepcopy(brief), "layout": copy.deepcopy(layout),
             "ids": ids or {}, "meta": dict(meta if meta is not None else doc.meta)}
    from .document import Document
    probe = Document(after["brief"], after["layout"], after["ids"], after["meta"])
    after["ids"] = probe.ids()
    after["follows"] = probe.survey_follows
    return Change(label, [("state", before, after)], hand=False, select=[])
class Clipboard:
    def __init__(self):
        self.items = []
        self.origin = None
        self.groups = []
    def __bool__(self):
        return bool(self.items)
    def copy(self, doc, refs):
        items = _view_items(doc, refs)
        if not items:
            return 0
        b = geo.grid_box([i for _, i in items])
        self.origin = (b[0], b[2], b[4])
        self.items = [(r[0], geo.cleaned(geo.translated(i, -b[0], -b[2], -b[4])))
                      for r, i in items]
        from . import groups
        self.groups = groups.template(doc, [r for r, _ in items])
        return len(self.items)
    def ghost(self, cursor, quarters=0, snap_on=True):
        items = [i for _, i in self.items]
        if quarters % 4:
            items = [geo.turned(i, quarters, geo.centre_of(items)) for i in items]
        return geo.placed_at(items, cursor, snap_on)
    def paste_at(self, doc, cursor, quarters=0, snap_on=True):
        if not self.items:
            return Change("Paste")
        moved = self.ghost(cursor, quarters, snap_on)
        return _with_groups(doc, insert(doc, [(k, m) for (k, _), m in zip(self.items, moved)],
                                        "Paste %d item%s" % (len(moved), "" if len(moved) == 1
                                                             else "s")), self.groups)
    def paste_in_place(self, doc):
        if not self.items or self.origin is None:
            return Change("Paste in place")
        ox, oy, oz = self.origin
        out = [(k, geo.cleaned(geo.translated(i, ox, oy, oz))) for k, i in self.items]
        return _with_groups(doc, insert(doc, out, "Paste in place"), self.groups)
    def cut(self, doc, refs):
        self.copy(doc, refs)
        change = delete(doc, refs)
        n = len([s for s in change.steps if s[0] == "remove"])
        change.label = "Cut %d item%s" % (n, "" if n == 1 else "s")
        return change
LIGHT_CHOICES = (("", "None"), ("lantern", "Lamp"), ("torch", "Torch"), ("campfire", "Fire"),
                 ("candle", "Candle"), ("crystal", "Crystal"), ("lava", "Lava glow"),
                 ("window", "Window"), ("mushroom", "Mushroom"), ("magic", "Magic"),
                 ("neon", "Neon"))
LIGHT_STOPS = (("dim", "Dim"), ("normal", "Normal"), ("bright", "Bright"))
def set_light(doc, refs, preset, bright="normal"):
    value = {"preset": preset, "bright": bright or "normal"} if preset else None
    pairs = []
    for r, item in _items(doc, refs):
        if r[0] != "piece":
            continue
        new = dict(item)
        if value is None:
            new.pop("light", None)
        else:
            old = item.get("light") if isinstance(item.get("light"), dict) else {}
            new["light"] = dict((k, v) for k, v in old.items() if k in ("radius", "colour"))
            new["light"].update(value)
        if new != item:
            pairs.append((r, new))
    label = "Light: %s" % (dict(LIGHT_CHOICES).get(preset or "", "None"))
    return Change(label, _replace_steps(doc, pairs), select=list(refs))
LIGHT_COLOURS = (("", "Its own"), ("255,190,125", "Warm"), ("255,140,60", "Fire"),
                 ("140,200,255", "Cold"), ("200,130,255", "Violet"), ("110,240,170", "Green"),
                 ("255,90,90", "Red"))
def set_light_detail(doc, refs, radius=None, colour=None):
    pairs = []
    for r, item in _items(doc, refs):
        if r[0] != "piece" or not isinstance(item.get("light"), dict):
            continue
        light = dict(item["light"])
        if radius:
            light["radius"] = max(100, min(4000, int(radius)))
        else:
            light.pop("radius", None)
        if colour:
            light["colour"] = [max(0, min(255, int(c))) for c in str(colour).split(",")][:3]
        else:
            light.pop("colour", None)
        new = dict(item, light=light)
        if new != item:
            pairs.append((r, new))
    return Change("Light: reach and colour", _replace_steps(doc, pairs), select=list(refs))
def light_my_path(doc, lots=False):
    from mapgen import autolight
    layout = doc.to_layout(models=False)
    lamps = autolight.light_path(layout, lots=lots)
    if not lamps:
        from .commands import refusal
        return refusal("No path here wants a lamp (every one is lit, or there is no path)")
    return insert(doc, [("piece", p) for p in lamps], "Light my path (%d lamps)" % len(lamps))
