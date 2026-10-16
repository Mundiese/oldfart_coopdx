from studio.editor import geometry as geo, ops
from studio.editor.commands import Change
from studio.toolbox.issues import Issue
NUMBERS = 6
HALF = 64
BELOW = 50
ABOVE = 62
MIN_HOVER = 100
JUMP_REACH = 450
FIX_LABELS = {"star_renumber": "Number the stars 1 to n in their order",
              "star_to_lift": "Hang it 200 over the floor (a vanilla star's height)"}
def _box(st):
    return (st["x"] - HALF, st["x"] + HALF, st["y"] - BELOW, st["y"] + ABOVE,
            st["z"] - HALF, st["z"] + HALF)
def floor_under(doc, st):
    best = None
    for p in doc.pieces():
        b = geo.aabb(p)
        if b[0] <= st["x"] <= b[1] and b[4] <= st["z"] <= b[5] and b[3] <= st["y"]:
            if best is None or b[3] > best:
                best = b[3]
    return best
def inside_piece(doc, st):
    box = _box(st)
    for iid, p in doc.items["piece"]:
        if p.get("kind") != "box":
            continue
        if geo.overlap_volume(box, geo.aabb(p)) > 1.0:
            return ("piece", iid)
    return None
def _reached_floors(doc):
    from mapgen import v1
    m = v1.arenas_module()
    lay = doc.to_layout()
    if not lay.get("spawns") or not lay.get("pieces"):
        return None, m
    cells, edges = m.walk_graph(lay)
    first = m.spawn_cell(lay["spawns"][0])
    if first not in cells:
        return None, m
    cols = {}
    for (gx, gz, h) in m.reach(edges, first):
        cols.setdefault((gx, gz), []).append(h)
    return cols, m
def reached(cols, m, st):
    import math
    g = (int(math.floor(st["x"] / m.GRID)), int(math.floor(st["z"] / m.GRID)))
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            for h in cols.get((g[0] + dx, g[1] + dz), []):
                if st["y"] - JUMP_REACH <= h <= st["y"]:
                    return True
    return False
def issues(doc, reach=True):
    refs = doc.refs("star")
    if not refs:
        return []
    out = []
    stars = [(r, doc.get(r)) for r in refs]
    nums = [s.get("id") for _, s in stars]
    if len(stars) > NUMBERS:
        out.append(Issue("fail", "gate", "%d bonus stars: a world holds six at most"
                         % len(stars), [r for r, _ in stars[NUMBERS:]]))
    for n in sorted(set(x for x in nums if isinstance(x, int))):
        same = [r for r, s in stars if s.get("id") == n]
        if len(same) > 1:
            out.append(Issue("fail", "gate", "bonus star number %d is used %d times "
                             "(each number once)" % (n, len(same)), same,
                             fixes=["star_renumber"]))
    bad = [r for r, s in stars if not isinstance(s.get("id"), int) or not 1 <= s["id"] <= NUMBERS]
    if bad:
        out.append(Issue("fail", "gate", "a bonus star's number must be 1 to %d" % NUMBERS, bad,
                         fixes=["star_renumber"]))
    good = sorted(x for x in nums if isinstance(x, int) and 1 <= x <= NUMBERS)
    if good and len(set(good)) == len(good) and good != list(range(1, len(good) + 1)) \
            and not bad:
        out.append(Issue("warn", "gate", "bonus star numbers %s skip a number: the game "
                         "numbers them 1 to %d in this order" % (
                             ", ".join(str(x) for x in good), len(good)),
                         [r for r, _ in stars], fixes=["star_renumber"]))
    for r, s in stars:
        label = "bonus star %s" % s.get("id")
        if not (s.get("name") or "").strip():
            out.append(Issue("warn", "gate", "%s has no name (the star select shows its "
                             "name)" % label, [r]))
        hit = inside_piece(doc, s)
        if hit is not None:
            out.append(Issue("fail", "gate", "%s is inside a piece" % label, [r, hit],
                             fixes=["star_to_lift"]))
            continue
        fl = floor_under(doc, s)
        if fl is not None and s["y"] - fl < MIN_HOVER:
            out.append(Issue("fail", "gate", "%s hangs %d over the floor: under %d it is half "
                             "in it (the game's stars hang 200-300)" % (
                                 label, s["y"] - fl, MIN_HOVER), [r], fixes=["star_to_lift"]))
    if reach:
        cols, m = _reached_floors(doc)
        if cols is not None:
            for r, s in stars:
                if not reached(cols, m, s):
                    out.append(Issue("warn", "gate", "bonus star %s cannot be reached: no "
                                     "floor walked to from spawn 1 is within a jump under it"
                                     % s.get("id"), [r]))
    return out
def fix(doc, issue, key):
    if key == "star_renumber":
        return renumber(doc)
    if key == "star_to_lift":
        return to_lift(doc, issue.refs[0])
    raise KeyError(key)
def renumber(doc):
    refs = doc.refs("star")
    order = sorted(range(len(refs)), key=lambda i: (
        doc.get(refs[i]).get("id") if isinstance(doc.get(refs[i]).get("id"), int) else 99, i))
    pairs = [(refs[i], dict(doc.get(refs[i]), id=n + 1)) for n, i in enumerate(order)]
    return Change("number the stars 1 to %d" % len(refs), ops._replace_steps(doc, pairs),
                  select=refs)
def to_lift(doc, ref):
    st = doc.get(ref)
    lift = ops.star_lift()
    hit = inside_piece(doc, st)
    fl = geo.aabb(doc.get(hit))[3] if hit is not None else floor_under(doc, st)
    if fl is None:
        return Change("star: no floor under it")
    return Change("hang star %s %d over the floor" % (st.get("id"), lift),
                  ops._replace_steps(doc, [(ref, dict(st, y=fl + lift))]), select=[ref])
