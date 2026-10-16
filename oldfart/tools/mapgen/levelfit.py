import math
from . import budget, checks
TARGET_KB = 595
PIECE_KB = 0.4
ROUNDS = 4
TEXTURE_CAPS = (42, 36, 32)
FIT_FROM = 600
ORDER = (("scatter.cover", False), ("scatter.flowers", False), ("scatter.rocks.rock", False),
         ("scatter.", False), ("detail.", False), ("decor.", True))
KEEP_WORDS = ("water", "well", "fountain", "lamp", "hero", "landmark", "sign", "star", "spawn",
              "cannon", "bridge", "door", "stair", "ladder", "dock", "lookout",
              "beacon")
LINE_STEPS = (0.98, 0.95, 0.9, 0.85, 0.75)
def red_line():
    return budget.BAKED_METERS["lvl_kb"][1]
STEP_MOVES_KB = 5
def over_line_said(kb):
    return ("level size: %.0f KB, over the %d KB line the Studio keeps a level under (a level "
            "holds up to %d KB, so it still loads) - in game it loads slower and takes more of "
            "the map pack's room; fewer things (a smaller size, or fewer wished features) bring "
            "it under" % (kb, red_line(), budget.BAKED_LVL_RED_KB))
TOLERANCE_KB = 10
assert 600 + TOLERANCE_KB < budget.BAKED_LVL_RED_KB
def over_line(fitted):
    return bool(fitted) and fitted[1] is not None and fitted[1] > red_line() + TOLERANCE_KB
def within_tolerance_said(kb):
    return ("level size: %.0f KB, %.0f KB over the %d KB guide - loads fine (hard limit %d; "
            "a level up to %d KB over the guide is kept as built)"
            % (kb, kb - red_line(), red_line(), budget.BAKED_LVL_RED_KB, TOLERANCE_KB))
class structure_scaled(object):
    def __init__(self, scale):
        self.scale = scale
    def __enter__(self):
        from .families import explore
        self.was = dict(explore.STRUCTURE_LINE)
        for k, v in self.was.items():
            explore.STRUCTURE_LINE[k] = int(v * self.scale)
        return self
    def __exit__(self, *exc):
        from .families import explore
        explore.STRUCTURE_LINE.clear()
        explore.STRUCTURE_LINE.update(self.was)
        return False
def applies(arena, family=None):
    fam = family or arena.get("family")
    return fam in budget.BAKED_TIER_FAMILIES and bool(arena.get("terrain")) \
        and arena.get("bake") is not False
def level_kb(arena):
    import sys
    from . import v1
    if v1.TOOLS not in sys.path:
        sys.path.insert(0, v1.TOOLS)
    import venuebake
    try:
        got = venuebake.measure(arena, shade=True).get("lvl_bytes")
    except Exception:
        return None
    return None if got is None else got / 1024.0
def removable(pieces):
    out = []
    seen = set()
    for prefix, prop in ORDER:
        for i, p in enumerate(pieces):
            if i in seen:
                continue
            tag = str(p.get("tag", ""))
            if not tag.startswith(prefix):
                continue
            if any(w in tag for w in KEEP_WORDS) or str(p.get("decor") or "") in KEEP_WORDS:
                continue
            if prop and p.get("kind") != "box":
                continue
            seen.add(i)
            out.append(i)
    return out
def spread(idx, n):
    if n >= len(idx):
        return list(idx)
    step = len(idx) / float(n)
    return sorted(set(idx[int(k * step)] for k in range(n)))
HANG_OVER = 120
def _hung(arena):
    from . import v1
    m = v1.arenas_module()
    out = {}
    airs = [o for o in arena.get("objects") or [] if o.get("air")]
    if not airs:
        return out
    for o in airs:
        for p in arena.get("pieces") or ():
            if abs(p["x"] - o["x"]) > p["w"] + p["d"] or abs(p["z"] - o["z"]) > p["w"] + p["d"]:
                continue
            try:
                x0, x1, z0, z1, _ = m.footprint(p)
                if not (x0 <= o["x"] <= x1 and z0 <= o["z"] <= z1):
                    continue
                t = m.top_at(p, o["x"], o["z"])
            except Exception:
                continue
            if t is not None and 0 <= o["y"] - t <= HANG_OVER:
                out[id(o)] = True
                break
    return out
def _drop_unhung(arena, hung):
    if not hung:
        return 0
    now = _hung(arena)
    objs = arena.get("objects") or []
    keep = [o for o in objs if not (id(o) in hung and id(o) not in now)]
    arena["objects"] = keep
    return len(objs) - len(keep)
def fit(arena, family=None, target=TARGET_KB):
    if not applies(arena, family) or len(arena.get("pieces") or ()) < FIT_FROM:
        return None
    kb = level_kb(arena)
    if kb is None or kb <= target:
        return (kb, kb, 0)
    first = kb
    per = PIECE_KB
    gone = 0
    hung = _hung(arena)
    for _ in range(ROUNDS):
        pieces = arena["pieces"]
        idx = removable(pieces)
        if not idx:
            break
        n = int(math.ceil((kb - target) / per * 1.25)) + 4
        cut = set(spread(idx, n))
        kept = [p for i, p in enumerate(pieces) if i not in cut]
        trial = dict(arena, pieces=kept)
        if checks.run(trial).faults:
            break
        new = level_kb(trial)
        if new is None:
            break
        if new < kb and len(cut):
            per = max(0.1, (kb - new) / float(len(cut)))
        arena["pieces"] = kept
        gone += len(cut)
        kb = new
        if kb <= target:
            break
    if kb > target:
        kb, far = thin_far(arena, kb, target)
        gone += far
    simpler = None
    if kb > target:
        from . import heightfield
        tol = (arena.get("terrain") or {}).get("tolerance", heightfield.TOLERANCE)
        for step in heightfield.LADDER:
            if step.get("tolerance", 0) <= tol:
                continue
            trial = dict(arena, terrain=dict(arena["terrain"], **step))
            new = level_kb(trial)
            if new is None:
                break
            arena["terrain"], kb, simpler = trial["terrain"], new, step
            if kb <= target:
                break
    cap = None
    if kb > target:
        for c in TEXTURE_CAPS:
            trial = dict(arena, texture_cap=c)
            new = level_kb(trial)
            if new is None:
                break
            arena["texture_cap"], kb, cap = c, new, c
            if kb <= target:
                break
    if cap:
        simpler = dict(simpler or {}, pictures=cap)
    _drop_unhung(arena, hung)
    rep = arena.setdefault("report", {})
    rep.setdefault("notes", []).append(
        "level fit: %d dressing pieces left out%s%s to keep the baked level at %.0f KB "
        "(was %.0f, line %d)" % (gone, (", the ground merged at tolerance %d" % simpler["tolerance"])
                                 if simpler and simpler.get("tolerance") else "",
                                 (", %d pictures at most" % cap) if cap else "", kb, first, target))
    return (first, kb, gone)
FAR_TAGS = ("tree", "decor", "hedge", "rock", "ruin", "stall", "scatter", "detail", "flora",
            "bush", "fence", "plaza")
FAR_KEEP = KEEP_WORDS + ("setpiece", "region", "glow", "torch", "campfire", "crystal", "light",
                         "paving", "statue", "obelisk")
SPAWN_CLEAR = 2400
def far_groups(arena):
    from . import flora
    pieces = arena["pieces"]
    spawns = [(s["x"], s["z"]) for s in arena.get("spawns") or []] or [(0, 0)]
    def ok(p):
        tag = str(p.get("tag", ""))
        if tag.split(".")[0] not in FAR_TAGS and not flora.is_tree(p):
            return False
        word = tag + " " + str(p.get("decor") or "")
        return not any(w in word for w in FAR_KEEP) and not p.get("light") \
            and not p.get("glow")
    def away(ps):
        return min(math.hypot(p["x"] - sx, p["z"] - sz) for p in ps for sx, sz in spawns)
    ids = dict((id(p), i) for i, p in enumerate(pieces))
    out, seen = [], set()
    for g in flora.groups(pieces):
        idx = [ids[id(p)] for p in g if id(p) in ids]
        if idx and all(ok(pieces[i]) for i in idx):
            out.append(idx)
        seen.update(idx)
    for i, p in enumerate(pieces):
        if i not in seen and ok(p):
            out.append([i])
    out = [g for g in out if away([pieces[i] for i in g]) >= SPAWN_CLEAR]
    out.sort(key=lambda g: -away([pieces[i] for i in g]))
    return out
def thin_far(arena, kb, target):
    per = PIECE_KB
    gone = 0
    for _ in range(ROUNDS * 2):
        groups = far_groups(arena)
        if not groups:
            break
        need = int(math.ceil((kb - target) / per * 1.2)) + 4
        cut, n = set(), 0
        for g in groups:
            if n >= need:
                break
            cut.update(g)
            n += len(g)
        kept = [p for i, p in enumerate(arena["pieces"]) if i not in cut]
        trial = dict(arena, pieces=kept)
        if checks.run(trial).faults:
            break
        new = level_kb(trial)
        if new is None:
            break
        if new < kb:
            per = max(0.1, (kb - new) / float(len(cut)))
        arena["pieces"] = kept
        gone += len(cut)
        kb = new
        if kb <= target:
            break
    return kb, gone
CELL = 1024
CELL_WALLS = 235
CELL_FLOORS = 140
def _measure(arena):
    import sys
    from . import v1
    if v1.TOOLS not in sys.path:
        sys.path.insert(0, v1.TOOLS)
    import venuebake
    try:
        return venuebake.measure(arena, shade=True)
    except Exception:
        return None
def fit_cells(arena, family=None, walls_line=CELL_WALLS, floors_line=CELL_FLOORS):
    if not applies(arena, family):
        return 0
    from . import flora
    gone = 0
    hung = _hung(arena)
    for _ in range(ROUNDS):
        m = _measure(arena)
        if m is None:
            break
        walls, wat = m["worst_walls"]
        floors, fat = m["worst_floors"]
        if walls <= walls_line and floors <= floors_line:
            break
        at = wat if walls > walls_line else fat
        if at is None:
            break
        cx, cz = int(at[0] // CELL), int(at[1] // CELL)
        def inside(p):
            return int(p["x"] // CELL) == cx and int(p["z"] // CELL) == cz
        pieces = arena["pieces"]
        cut = set(i for i in removable(pieces) if inside(pieces[i]))
        ids = dict((id(p), i) for i, p in enumerate(pieces))
        for g in flora.groups(pieces):
            if any(inside(p) for p in g):
                cut |= set(ids[id(p)] for p in g if id(p) in ids)
        if not cut:
            break
        kept = [p for i, p in enumerate(pieces) if i not in cut]
        trial = dict(arena, pieces=kept)
        if checks.run(trial).faults:
            break
        arena["pieces"] = kept
        gone += len(cut)
    if gone:
        _drop_unhung(arena, hung)
        rep = arena.setdefault("report", {})
        rep.setdefault("notes", []).append(
            "level fit: %d trees and dressing pieces left out of the busiest collision cell"
            % gone)
    return gone
