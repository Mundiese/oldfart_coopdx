import math
import random
from . import contract, houses, kit, landmarks, pcg, soft64, villagecore
CELL = 400
KINDS = {"S1": "street village", "S2": "hill town", "S3": "walled town", "S4": "desert town",
         "S5": "water village", "S6": "forge town"}
THEME_KIND = {"castle": "S3", "machine": "S3", "lava": "S6", "desert": "S4", "temple": "S4",
              "water": "S5", "ice": "S2", "wood": "S2", "forest": "S2"}
ANCHORS = {"S1": ("belltower", "fountain", "windmill"), "S2": ("windmill", "belltower"),
           "S3": ("keep", "belltower", "fortress"), "S4": ("domedhall", "pyramid", "obelisk"),
           "S5": ("statue", "lighthouse", "fountain"), "S6": ("fortress", "obelisk", "watchtower")}
RINGS = {
    "S1": {"core": ("H2", "H1"), "middle": ("H1", "H3", "H4", "H1"), "edge": ("H11", "H1", "H14")},
    "S2": {"core": ("H4", "H1"), "middle": ("H5", "H1", "H4", "H14"), "edge": ("H11", "H5")},
    "S3": {"core": ("H2", "H4", "H14"), "middle": ("H1", "H4", "H3"), "edge": ("H11", "H1")},
    "S4": {"core": ("H6", "H7"), "middle": ("H6", "H7", "H6"), "edge": ("H6",)},
    "S5": {"core": ("H1", "H8"), "middle": ("H8", "H1"), "edge": ("H8", "H13")},
    "S6": {"core": ("H4", "H1", "H14"), "middle": ("H1", "H4", "H3"), "edge": ("H11", "H1")},
}
THEME_RINGS = {"temple": {"core": ("H9", "H7"), "middle": ("H9",), "edge": ("H9", "H7")},
               "ice": {"core": ("H5", "H4"), "middle": ("H5", "H1", "H14"), "edge": ("H12", "H5")},
               "garden": {"core": ("H1", "H3"), "middle": ("H1", "H9", "H3"),
                          "edge": ("H1", "H11", "H14")}}
FUNCTIONS = {"core": ("shop", "tavern"), "middle": ("home", "home", "chapel"),
             "edge": ("barn", "forge", "home")}
KIND_FUNCTIONS = {"S6": {"core": ("forge", "tavern"), "middle": ("forge", "home"),
                         "edge": ("forge", "barn")}}
RING_CORE, RING_MIDDLE = 5, 9
PREFAB_EVERY = (4, 6)
PREFAB_TAGS = ("house", "home", "shop", "building", "cottage", "barn", "inn", "chapel", "hut")
STARTER = ("castlewall", "cottage", "footbridge", "gate", "marketstall", "watchtower")
STALLS = {"S1": 2, "S3": 3, "S4": 2}
FIELDS = {"S1": 1, "S2": 2}
FALLBACK = {"S1": "H1", "S2": "H1", "S3": "H1", "S4": "H7", "S5": "H8", "S6": "H1",
            "temple": "H7"}
HOUSE_PIECES = 11
TOWER = "H14"
WALL_ROOM = 24
LOT_STEP = 1
AWAY_OF_FACE = dict((f, d) for d, f in {(0, 1): "n", (0, -1): "s", (1, 0): "w",
                                        (-1, 0): "e"}.items())
def street_cell(e):
    di, dj = AWAY_OF_FACE[e["face"]]
    cells = set(map(tuple, e["cells"]))
    front = sorted(c for c in cells if (c[0] - di, c[1] - dj) not in cells)
    mid = front[len(front) // 2]
    return (mid[0] - di, mid[1] - dj)
def pad_lot(W, e):
    level = W.T(street_cell(e))
    cut = fill = 0
    for c in e["cells"]:
        c = tuple(c)
        t = W.T(c)
        if t == level:
            continue
        if t > level:
            cut += 1
        else:
            fill += 1
        W.cuts[c] = level
    return {"level": level, "cut": cut, "fill": fill}
def detail_for(brief):
    from .brief import dna
    try:
        return "full" if dna(brief, "complexity") >= 0.6 else "lean"
    except Exception:
        return "lean"
ANCHOR_ROOM = 70
VILLAGE_SHARE = 0.35
WANTED_SHARE = 0.5
LANE_SHARE = 0.25
LANE_CELLS_MAX = 60
def lane_budget(cells, room):
    if room < 2 * HOUSE_PIECES:
        return 0
    return min(LANE_CELLS_MAX, int(cells * LANE_SHARE))
def allotment(brief, villages, k):
    budget = (brief or {}).get("budget") or 300
    total = VILLAGE_SHARE * budget
    want = set(((brief or {}).get("features") or {}).get("want") or ())
    if "buildings" in want or (brief or {}).get("family") == "hide":
        total = WANTED_SHARE * budget
    if villages <= 1:
        return int(total)
    return int(total * 0.6) if k == 0 else int(total * 0.4 / (villages - 1))
def kind_for(theme, brief=None):
    k = THEME_KIND.get(theme, "S1")
    size = (brief or {}).get("size")
    if k == "S3" and size in ("tiny", "small"):
        k = "S1"
    return k
def recipes_for(kind, theme, ring):
    rows = dict(RINGS[kind])
    rows.update(THEME_RINGS.get(theme, {}))
    return rows.get(ring) or RINGS[kind][ring]
def ring_of(d):
    return "core" if d <= RING_CORE else "middle" if d <= RING_MIDDLE else "edge"
def prefab_pool():
    from . import prefablib
    out = []
    for key, name, tags in prefablib.names():
        p = prefablib.find(key)
        if not p or not any(c.get("kind") == "door" for c in p.get("connectors", [])):
            continue
        if set(t.lower() for t in tags) & set(PREFAB_TAGS):
            out.append(key)
    return sorted(out, key=lambda k: (k in STARTER, k))
FACE_OF_DIR = {(0, 1): "n", (0, -1): "s", (1, 0): "w", (-1, 0): "e"}
WORLD_FACE = {"n": "-z", "s": "+z", "e": "+x", "w": "-x"}
def lot_cells(a, away, w, d):
    di, dj = away
    if di == 0:
        i0 = a[0] - w // 2
        j0 = a[1] if dj > 0 else a[1] - d + 1
        return [(i0 + x, j0 + z) for x in range(w) for z in range(d)], (i0, j0, w, d)
    j0 = a[1] - w // 2
    i0 = a[0] if di > 0 else a[0] - d + 1
    return [(i0 + x, j0 + z) for x in range(d) for z in range(w)], (i0, j0, d, w)
def _ring(cells, gap):
    cs = set(cells)
    out = set()
    for (i, j) in cs:
        for a in range(-gap, gap + 1):
            for b in range(-gap, gap + 1):
                c = (i + a, j + b)
                if c not in cs:
                    out.add(c)
    return out
class Site:
    def __init__(self, cells, free, flat, street, taken, level_ok=None):
        self.cells, self.free, self.flat, self.street = set(cells), free, flat, street
        self.taken = taken
        self.level_ok = level_ok
class Taken:
    def __init__(self, cells=()):
        self.cells = set(cells)
        self.reserved = set()
    def add(self, cells, gap):
        self.cells |= set(cells)
        if gap:
            self.reserved |= _ring(cells, gap)
    def __contains__(self, c):
        return c in self.cells
def _lot_ok(site, cells, gap, others):
    others = others if isinstance(others, Taken) else Taken(others)
    if not all(c in site.cells and site.free(c) and c not in others.cells
               and c not in others.reserved for c in cells):
        return False
    if not site.flat(cells):
        return False
    for c in _ring(cells, gap):
        if c in others.cells:
            return False
    for c in _ring(cells, max(1, gap)):
        if c in site.cells and site.taken(c) and c not in others.cells:
            return False
    return True
def _place_lot(site, a, away, w, d, gap, taken):
    di, dj = away
    for s in (0, -1, 1, -2, 2):
        if abs(s) > (w - 1) // 2:
            continue
        b = (a[0] + s, a[1]) if di == 0 else (a[0], a[1] + s)
        cells, rect = lot_cells(b, away, w, d)
        mid = (b[0] - di, b[1] - dj)
        if not site.street(mid) or mid in taken.cells:
            continue
        if site.level_ok is not None and not site.level_ok(cells, mid):
            continue
        if _lot_ok(site, cells, gap, taken):
            taken.reserved.add(mid)
            return cells, rect
    return None
SMALL_HOUSES = ("H12", "H10")
def plan_lots(site, r, frontage, centre, kind, theme, family, budget_lots, used=None,
              small=False):
    hide = family == "hide"
    lots = []
    prefabs = []
    taken = Taken(used or ())
    pool = prefab_pool()
    every = r.randint(*PREFAB_EVERY)
    grammar_since = 0
    for a, away in frontage:
        if len(lots) + len(prefabs) >= budget_lots:
            break
        dist = max(abs(a[0] - centre[0]), abs(a[1] - centre[1]))
        ring = ring_of(dist)
        if pool and grammar_since >= every:
            pe = _try_prefab(site, r, a, away, pool[len(prefabs) % len(pool)], taken)
            if pe is not None:
                prefabs.append(pe)
                taken.add(pe["cells"], 1)
                grammar_since = 0
                every = r.randint(*PREFAB_EVERY)
                continue
        recs = list(recipes_for(kind, theme, ring))
        r.shuffle(recs)
        if r.random() < 0.65:
            area = {x: houses.lot_of(x)[0] * houses.lot_of(x)[1] for x in recs}
            recs.sort(key=lambda x: area[x])
        if TOWER in recs:
            recs.remove(TOWER)
            if not hide and not any(e["recipe"] == TOWER for e in lots):
                recs.insert(0, TOWER)
        fall = FALLBACK.get(theme, FALLBACK[kind])
        tries = [(x, None) for x in recs] + [(fall, "solid")]
        if small:
            tries = [(x, "solid") for x in SMALL_HOUSES]
        got = None
        for rec, how in tries:
            if how == "solid":
                enterable, openings = (True, 2) if hide and rec == "H1" else (False, 0)
            else:
                enterable, openings = _interior_for(rec, family, r)
            intent = _intent_for(rec, ring, family, r)
            lw, ld = houses.lot_of(rec, enterable, openings)
            if rec == "H2":
                lw = r.choice((7, 9))
            gap = 2 if intent == "out_of_reach" else 1 if intent == "vantage" else 0
            fit = _place_lot(site, a, away, lw, ld, gap, taken)
            if fit:
                cells, (i0, j0, wx, wz) = fit
                got = rec
                break
            if intent == "out_of_reach" and rec in ("H1", "H3", "H5", "H9", "H11", "H7"):
                intent, gap = "climbable", 0
                lw, ld = houses.lot_of(rec, enterable, openings)
                fit = _place_lot(site, a, away, lw, ld, gap, taken)
                if fit:
                    cells, (i0, j0, wx, wz) = fit
                    got = rec
                    break
            if enterable and how is None:
                lw, ld = houses.lot_of(rec, False, 0)
                fit = _place_lot(site, a, away, lw, ld, gap, taken)
                if fit:
                    cells, (i0, j0, wx, wz) = fit
                    enterable, openings = False, 0
                    got = rec
                    break
        if got is None:
            continue
        func = None
        if enterable:
            fs = KIND_FUNCTIONS.get(kind, FUNCTIONS)[ring]
            func = fs[int(r.random() * len(fs))]
        lots.append({"cell": (i0, j0), "w": wx, "d": wz, "lot": (lw * CELL, ld * CELL),
                     "face": FACE_OF_DIR[away], "recipe": rec, "intent": intent,
                     "enterable": enterable, "openings": openings, "function": func,
                     "seed": r.randrange(1 << 30), "ring": ring, "cells": cells,
                     "street": True})
        taken.add(cells, gap)
        grammar_since += 1
    return lots, prefabs
def _interior_for(rec, family, r):
    if rec in ("H2", "H6", "H10", "H12", "H13", "H8", "H7"):
        return False, 0
    if rec == TOWER:
        return True, 1
    if family == "hide":
        return True, 2
    if family == "explore" and r.random() < 1 / 3.0:
        return True, 1
    return False, 0
def _intent_for(rec, ring, family, r):
    if rec in ("H6", TOWER):
        return "vantage"
    if family == "hide":
        return "out_of_reach"
    if rec in ("H2", "H4", "H8", "H13"):
        return "out_of_reach"
    if ring == "core" and r.random() < 0.3:
        return "out_of_reach"
    return "climbable" if r.random() < 0.85 else "out_of_reach"
def _try_prefab(site, r, a, away, key, taken):
    from . import prefablib
    pf = prefablib.find(key)
    if pf is None:
        return None
    want = WORLD_FACE[FACE_OF_DIR[away]]
    turn = prefablib.door_turn(pf, want)
    w, d = prefablib.size(pf, turn)
    ci, cj = -(-w // CELL), -(-d // CELL)
    along, back = (ci, cj) if away[0] == 0 else (cj, ci)
    cells, (i0, j0, wx, wz) = lot_cells(a, away, along, back)
    if not _lot_ok(site, cells, 1, taken):
        return None
    return {"key": key, "cell": (i0, j0), "turn": turn, "cells": cells, "mixed": True}
def _square(W, cs, centre, k):
    order = sorted(cs, key=lambda c: (abs(c[0] - centre[0]) + abs(c[1] - centre[1]), c))
    for c in order[:300]:
        sq = [(c[0] + a, c[1] + b) for a in range(k) for b in range(k)]
        if all(x in cs and W.free(x) for x in sq) and W.flat(sq):
            return sq
    return None
def _main_street(W, cs, plaza):
    ps = set(plaza)
    h = W.T(plaza[0])
    start = [c for c in plaza]
    prev = {c: None for c in start}
    todo = list(start)
    goal = None
    while todo and goal is None:
        nxt = []
        for c in todo:
            for a, b in pcg.N4:
                m = (c[0] + a, c[1] + b)
                if m in prev:
                    continue
                if (m in W.streets or m in W.road) and m not in ps:
                    prev[m] = c
                    goal = m
                    break
                if m in cs and W.free(m) and W.T(m) == h:
                    prev[m] = c
                    nxt.append(m)
            if goal is not None:
                break
        todo = nxt
    if goal is None:
        return []
    path = []
    c = prev[goal]
    while c is not None and c not in ps:
        path.append(c)
        c = prev[c]
    return list(reversed(path))
def plan_explore(W, cells, r, brief, pal, site_cell, district, allot=None):
    from .paths import common
    theme = common.theme_of(brief)
    kind = kind_for(theme, brief)
    family = brief.get("family")
    st = houses.style_for(theme, pal, r, kind)
    st["detail"] = detail_for(brief)
    cs = set(cells)
    allot = allot or allotment(brief, 1, 0)
    rec = {"district": district, "kind": kind, "name": KINDS[kind], "style": houses.record(st),
           "theme": theme, "notes": [], "allot": allot}
    spent = 0
    k = 4 if kind in ("S3", "S4") else 3
    plaza = _square(W, cs, site_cell, k) or _square(W, cs, site_cell, 3)
    if plaza is None:
        rec["notes"].append("no level square for a plaza: houses only")
        plaza = []
    centre = site_cell
    if plaza:
        centre = (min(c[0] for c in plaza) + k // 2, min(c[1] for c in plaza) + k // 2)
        for c in plaza:
            W.solid[c] = (0, None, "plaza")
        spent += len(_runs(plaza))
    rec["plaza"] = sorted(plaza)
    have = [x["kind"] for x in W.landmarks]
    big = allot >= ANCHOR_ROOM
    pool = (list(ANCHORS[kind]) + ["fountain", "statue", "shrine"]) if big else \
        ["well", "fountain"]
    anchor = None
    for ak in [a for a in pool if a not in have or a == "well"]:
        anchor = _anchor(W, cs, plaza, centre, ak, r, pal, theme)
        if anchor:
            break
    rec["anchor"] = anchor["kind"] if anchor else None
    spent += len(anchor["pieces"]) if anchor else 0
    street = _main_street(W, cs, plaza) if plaza else []
    for c in street:
        W.streets.add(c)
    rec["main_street"] = street
    spent += len(_runs(street))
    lanes = villagecore.grow(W, cs, plaza, r, budget=lane_budget(len(cs), allot - spent)) \
        if plaza else []
    rec["lanes"] = [c for run in lanes for c in run]
    if not hasattr(W, "paved"):
        W.paved = set()
    W.paved |= set(rec["lanes"]) | set(street)
    spent += len(_runs(rec["lanes"]))
    spent += 5 if plaza else 0
    want_echo = allot - spent >= 40
    want_field = FIELDS.get(kind, 0) and allot - spent >= 90
    want_stalls = STALLS.get(kind) and plaza and allot - spent >= 110
    want_gate = kind in ("S1", "S3", "S4") and street and allot - spent >= 140
    reserve = 2 * want_echo + 4 * bool(want_field) + 4 * (STALLS.get(kind) or 0) * \
        bool(want_stalls) + 11 * bool(want_gate)
    stalls = _stalls(W, cs, plaza, street, STALLS[kind]) if want_stalls else []
    rec["stalls"] = stalls
    pset = set(plaza)
    hide = family == "hide"
    def opens_onto(c):
        return c in W.streets or c in W.road or c in pset or \
            (hide and c in cs and W.free(c))
    front = []
    for a in sorted(cs, key=lambda c: (max(abs(c[0] - centre[0]), abs(c[1] - centre[1])), c)):
        if not W.free(a):
            continue
        for di, dj in pcg.N4:
            s = (a[0] - di, a[1] - dj)
            if s in W.streets or s in W.road or s in pset:
                front.append((a, (di, dj)))
                break
        else:
            if hide:
                for di, dj in pcg.N4:
                    s = (a[0] - di, a[1] - dj)
                    if opens_onto(s):
                        front.append((a, (di, dj)))
                        break
    def spread_ok(cells):
        hs = [W.T(c) for c in cells]
        return max(hs) - min(hs) <= LOT_STEP
    def level_ok(cells, mid):
        t = W.T(mid)
        return all(abs(W.T(c) - t) <= LOT_STEP for c in cells)
    site = Site(cs, W.free, spread_ok, opens_onto,
                lambda c: c in W.solid and W.solid[c][2] != "plaza", level_ok=level_ok)
    budget_lots = max(2, min(len(cells) // 16, (allot - spent - reserve) // HOUSE_PIECES))
    lots, prefabs = plan_lots(site, r, front, centre, kind, theme, family, budget_lots)
    if not lots and not prefabs and front:
        lots, prefabs = plan_lots(site, r, front, centre, kind, theme, family, budget_lots,
                                  small=True)
        if lots:
            rec["notes"].append("cottages: no lot for the ring's houses, %d small ones"
                                % len(lots))
    for e in lots:
        e["pad"] = pad_lot(W, e)
        e["settlement"] = len(W.settlements)
        e["tex"] = st["wall"]
        b = build_entry(e, st)
        e["top_rel"] = b["top"] if b else 0
        spent += len(b["pieces"]) if b else 0
        for c in e["cells"]:
            W.solid[c] = (houses.STOREY, st["wall"], "house")
        W.houses.append(e)
    for pe in prefabs:
        for c in pe["cells"]:
            W.solid[c] = (0, None, "prefab")
        W.prefabs.append(pe)
        W.prefabs_laid.add(pe["key"])
    rec["gate"] = None
    if want_gate:
        rec["gate"] = _town_gate(W, cs, street, r, pal, theme)
    rec["wall"] = None
    if kind in villagecore.WALLED and allot - spent >= WALL_ROOM:
        core = list(plaza) + list(rec["lanes"]) + [c for e in lots if e["ring"] != "edge"
                                                   for c in e["cells"]]
        rec["wall"] = villagecore.plan_wall(W, cs, core, kind)
    rec["fields"] = []
    for _ in range(FIELDS.get(kind, 0) if want_field else 0):
        f = _field(W, cs, centre)
        if f:
            rec["fields"].append(f)
    rec["want_echo"] = want_echo
    rec["houses"] = len(lots)
    rec["prefabs"] = [p["key"] for p in prefabs]
    rec["rings"] = {g: sum(1 for e in lots if e["ring"] == g) for g in ("core", "middle", "edge")}
    rec["recipes"] = sorted(set(e["recipe"] for e in lots))
    rec["style_full"] = st
    W.settlements.append(rec)
    return len(lots) + len(prefabs)
def _anchor(W, cs, plaza, centre, kind, r, pal, theme):
    from .families.explore import landmark_pal
    f = landmarks.foot(kind)
    h = f // 2
    if plaza:
        i0 = min(c[0] for c in plaza)
        i1 = max(c[0] for c in plaza)
        j0 = min(c[1] for c in plaza)
        j1 = max(c[1] for c in plaza)
        mid_i, mid_j = (i0 + i1) // 2, (j0 + j1) // 2
        spots = [((mid_i, j0 - 1 - h), (0, 1)), ((mid_i, j1 + 1 + h), (0, -1)),
                 ((i0 - 1 - h, mid_j), (1, 0)), ((i1 + 1 + h, mid_j), (-1, 0))]
    else:
        spots = [(centre, (0, 1))]
    for spot, towards in spots:
        foot = [(spot[0] + a, spot[1] + b) for a in range(-h, h + 1) for b in range(-h, h + 1)]
        if not all(c in cs and W.free(c) for c in foot) or not W.flat(foot):
            continue
        if plaza and W.T(foot[0]) != W.T(plaza[0]):
            continue
        lp = landmark_pal(W, pal, theme)
        full = landmarks.derive_full(kind, r, lp)
        q = {(0, 1): 0, (1, 0): 1, (0, -1): 2, (-1, 0): 3}[towards]
        from . import v1
        m = v1.arenas_module()
        pieces = [m.turned(p, q) for p in full["pieces"]]
        entry = {"kind": kind, "cell": spot, "pieces": pieces, "height": full["height"],
                 "foot": f, "tier": full["tier"], "top": full["top"], "use": full["use"],
                 "accent": full["accent"], "usable": full["usable"], "width": full["width"],
                 "mass_width": full["mass_width"], "faces_ok": True, "anchor": True,
                 "settlement": len(W.settlements)}
        W.landmarks.append(entry)
        for c in foot:
            W.solid[c] = (0, None, "landmark")
        return entry
    return None
def _stalls(W, cs, plaza, street, n):
    i0 = min(c[0] for c in plaza)
    i1 = max(c[0] for c in plaza)
    j0 = min(c[1] for c in plaza)
    j1 = max(c[1] for c in plaza)
    s0 = street[0] if street else None
    side = "s" if (s0 is not None and s0[1] < j0) else "n"
    row = [(i, j0) for i in range(i0, i1 + 1)] if side == "n" else \
        [(i, j1) for i in range(i0, i1 + 1)]
    return [{"cell": c, "face": "s" if side == "n" else "n"} for c in row[::2][:n]]
def _town_gate(W, cs, street, r, pal, theme):
    from .families.explore import landmark_pal
    from . import v1
    end = street[-1]
    before = street[-2] if len(street) > 1 else None
    if before is None:
        return None
    along_x = before[1] == end[1]
    side = [(end[0], end[1] - 1), (end[0], end[1] + 1)] if along_x else \
        [(end[0] - 1, end[1]), (end[0] + 1, end[1])]
    if not all(c in cs and W.free(c) and W.T(c) == W.T(end) for c in side):
        return None
    full = landmarks.derive_full("gate", r, landmark_pal(W, pal, theme))
    m = v1.arenas_module()
    pieces = [m.turned(p, 1) for p in full["pieces"]] if along_x else full["pieces"]
    entry = {"kind": "gate", "cell": end, "pieces": pieces, "height": full["height"], "foot": 3,
             "tier": "tertiary", "top": full["top"], "use": full["use"],
             "accent": full["accent"], "usable": True, "width": full["width"],
             "mass_width": full["mass_width"], "faces_ok": True, "town_gate": True,
             "cells": side, "settlement": len(W.settlements)}
    W.landmarks.append(entry)
    for c in side:
        W.solid[c] = (0, None, "landmark")
    return {"cell": end, "along_x": along_x}
def _field(W, cs, centre):
    order = sorted(cs, key=lambda c: (-max(abs(c[0] - centre[0]), abs(c[1] - centre[1])), c))
    for c in order[:200]:
        cells = [(c[0] + a, c[1] + b) for a in range(3) for b in range(4)]
        if all(x in cs and W.free(x) for x in cells) and W.flat(cells) and \
                not any(x in W.solid for x in _ring(cells, 1)):
            for x in cells:
                W.solid[x] = (0, None, "field")
            return cells
    return None
def plan_quarter(g, box, r, brief, pal, tex):
    from .paths import common
    theme = common.theme_of(brief)
    if not hasattr(g, "settlements"):
        g.settlements = []
    st = houses.style_for(theme, pal, r, "quarter")
    st["detail"] = detail_for(brief)
    x0, x1, z0, z1 = box
    cells = [(i, j) for i in range(x0, x1) for j in range(z0, z1)]
    def flat(cs):
        return len(set(g.h(c) for c in cs)) <= 1
    cellset = set(cells)
    site = Site(cells, g.free, flat, lambda c: c not in cellset,
                lambda c: c in g.solid or c in g.perch or c in g.ramp)
    front = []
    for i in range(x0, x1):
        front.append(((i, z0), (0, 1)))
        front.append(((i, z1 - 1), (0, -1)))
    for j in range(z0, z1):
        front.append(((x0, j), (1, 0)))
        front.append(((x1 - 1, j), (-1, 0)))
    k0 = int(r.random() * len(front))
    front = front[k0:] + front[:k0]
    centre = ((x0 + x1) // 2, (z0 + z1) // 2)
    lots, prefabs = plan_lots(site, r, front, centre, "S1", theme, "hide", 6)
    rec = {"district": None, "kind": "S1", "name": "village quarter", "style": houses.record(st),
           "theme": theme, "notes": [], "plaza": [], "main_street": [], "stalls": [],
           "fields": [], "anchor": None, "gate": None, "style_full": st,
           "houses": len(lots), "prefabs": [p["key"] for p in prefabs],
           "rings": {g_: sum(1 for e in lots if e["ring"] == g_)
                     for g_ in ("core", "middle", "edge")},
           "recipes": sorted(set(e["recipe"] for e in lots))}
    for e in lots:
        e["settlement"] = len(g.settlements)
        e["tex"] = st["wall"]
        b = build_entry(e, st)
        e["top_rel"] = b["top"] if b else 0
        for c in e["cells"]:
            g.solid[c] = (houses.STOREY, tex, "house")
        g.houses.append(e)
    for pe in prefabs:
        for c in pe["cells"]:
            g.solid[c] = (houses.STOREY, tex, "prefab")
        g.prefabs.append(pe)
        g.prefabs_laid.add(pe["key"])
    g.settlements.append(rec)
    return len(lots) + len(prefabs)
def quarter_pieces(g, X, Y):
    out = []
    for e in g.houses:
        if "recipe" not in e:
            continue
        st = style_of(g, e)
        b = build_entry(e, st)
        cx, cz = lot_centre(e, X)
        y = Y(e["cells"][0])
        e["built"] = b
        e["world"] = houses.place(b, cx, cz, y, e["face"])
        e["at"] = (cx, cz, y)
    roof_check(g)
    for e in g.houses:
        if "world" in e:
            out += e["world"]
    return out
def style_of(W, e):
    s = W.settlements[e["settlement"]]
    return s["style_full"]
def build_entry(e, st):
    rb = random.Random(e["seed"])
    b = houses.build(e["recipe"], st, e["lot"], rb, e["intent"], e["enterable"],
                     e.get("openings", 1), e.get("function") or "home")
    if b is None:
        b = houses.build("H1", st, e["lot"], rb, "climbable", False, 1)
    return b
def lot_centre(e, X):
    i0, j0 = e["cell"]
    return X(i0) + e["w"] * CELL / 2.0, X(j0) + e["d"] * CELL / 2.0
def world_pieces(W, X, Y, pal, theme):
    out, extra = [], []
    for e in W.houses:
        if "recipe" not in e:
            continue
        st = style_of(W, e)
        b = build_entry(e, st)
        cx, cz = lot_centre(e, X)
        y = Y(e["cells"][0])
        e["built"] = b
        e["world"] = houses.place(b, cx, cz, y, e["face"])
        e["at"] = (cx, cz, y)
    roof_check(W)
    for e in W.houses:
        if "world" in e:
            out += e["world"]
            s = W.settlements[e["settlement"]]
            extra += villagecore.house_dressing(e, s["kind"], s.get("theme") or theme,
                                                s["style_full"].get("detail", "full"))
    for s in W.settlements:
        st = s["style_full"]
        path = st.get("path") or pal.get("path") or pal.get("road")
        for run in _runs(s["plaza"]) + _runs(s["main_street"]):
            (i0, j0, i1, j1) = run
            y = Y((i0, j0))
            extra.append(kit.kind("box").make(path, X(i0), X(i1 + 1), y, y + 20, X(j0),
                                              X(j1 + 1), None, "plaza.paving"))
        lanes = [c for c in s.get("lanes", []) if c not in set(s["plaza"]) | set(s["main_street"])]
        extra += villagecore.paving(lanes, path, X, Y)
        if s["plaza"]:
            keep = set()
            for sl in s.get("stalls", []):
                keep |= {(sl["cell"][0] + a, sl["cell"][1] + b) for a in (-1, 0, 1)
                         for b in (-1, 0, 1)}
            if s.get("echo"):
                keep.add(s["echo"]["cell"])
            extra += villagecore.square_dressing(s["plaza"], X, Y, theme=theme, pal=pal,
                                                 fountain=s.get("anchor") != "fountain",
                                                 keep=keep)
        for sl in s.get("stalls", []):
            c = sl["cell"]
            b = houses.stall(st, (2 * CELL, 2 * CELL), random.Random(c[0] * 131 + c[1]))
            got = houses.place(b, X(c[0]) + CELL / 2.0, X(c[1]) + CELL / 2.0, Y(c) + 20,
                               sl["face"])
            paved = set(s["plaza"]) | set(s["main_street"])
            x0 = X(0)
            for p in got:
                if p.get("kind") != "pillar" or not str(p.get("tag", "")).endswith("post"):
                    continue
                pc = (int((p["x"] - x0) // CELL), int((p["z"] - x0) // CELL))
                if pc in paved:
                    continue
                g = Y(pc)
                top = p["y"] + p["h"]
                if g < p["y"] and top - g > 0:
                    p["h"], p["y"] = top - g, g
            extra += got
        for cells in s.get("fields", []):
            extra += _field_pieces(cells, X, Y, st, theme)
        extra += villagecore.wall_pieces(s.get("wall"), X, Y, st)
        if s.get("echo"):
            extra += _echo_pieces(s["echo"], X, Y, st)
    return out, extra
def _runs(cells):
    cs = set(cells)
    rows = []
    seen = set()
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
def _field_pieces(cells, X, Y, st, theme):
    b = soft64.buildings(theme) or {}
    plants = [p for p in (b.get("plants") or []) if p in kit.textures()]
    tex = plants[0] if plants else (st.get("path") or st["base"])
    i0 = min(c[0] for c in cells)
    i1 = max(c[0] for c in cells)
    j0 = min(c[1] for c in cells)
    j1 = max(c[1] for c in cells)
    y = Y(cells[0])
    rail = st["rail"] if kit.comes_in(st["rail"], "rail") else st["trim"]
    out = [kit.kind("box").make(tex, X(i0) + 100, X(i1 + 1) - 100, y, y + 20, X(j0) + 100,
                                X(j1 + 1) - 100, None, "field")]
    out.append(kit.kind("rail").make(rail, X(i0), X(i1 + 1), y, y + 160, X(j0), X(j0) + 60,
                                     None, "fence"))
    out.append(kit.kind("rail").make(rail, X(i0), X(i0) + 60, y, y + 160, X(j0) + 60,
                                     X(j1 + 1), None, "fence"))
    out.append(kit.kind("rail").make(rail, X(i1 + 1) - 60, X(i1 + 1), y, y + 160, X(j0) + 60,
                                     X(j1 + 1), None, "fence"))
    return out
def _echo_pieces(echo, X, Y, st):
    c = echo["cell"]
    x0, z0 = X(c[0]) + 100, X(c[1]) + 100
    y = Y(c) + 20
    xc, zc = x0 + 100, z0 + 100
    acc = st.get("accent") or st["trim"]
    shape = echo["shape"]
    if shape in ("battlements", "terraced crown"):
        return [kit.kind("box").make(st["base"], x0 + 20, x0 + 180, y, y + 500, z0 + 20, z0 + 180,
                                     None, "landmark.echo.tower"),
                kit.kind("box").make(acc, x0 + 20, x0 + 80, y + 500, y + 560, z0 + 20, z0 + 80,
                                     None, "landmark.echo.accent")]
    if shape in ("canopy",):
        return [kit.kind("pillar").make(st["trim"], xc - 40, xc + 40, y, y + 400, zc - 40,
                                        zc + 40, None, "landmark.echo.trunk"),
                kit.kind("box").make(acc, x0, x0 + 200, y + 400, y + 560, z0, z0 + 200, None,
                                     "landmark.echo.accent")]
    return [kit.kind("pillar").make(st["base"], xc - 80, xc + 80, y, y + 600, zc - 80, zc + 80,
                                    None, "landmark.echo.spire"),
            kit.kind("pyramid").make(acc, xc - 80, xc + 80, y + 600, y + 800, zc - 80, zc + 80,
                                     "x", "landmark.echo.accent")]
SPIRE_MAX = 6200
def hierarchy(W, notes=None):
    tallest = 0
    for e in W.houses:
        tallest = max(tallest, e.get("top_rel", 0))
    lms = [dict(kind=x["kind"], height=x.get("height", 0), top=x.get("top", x["kind"]))
           for x in W.landmarks]
    grand = [sp for sp in W.spires if sp.get("grand")]
    top_lm = max((x["height"] for x in lms), default=0)
    built_primary = top_lm >= 2 * tallest
    for sp in grand:
        need = max(2 * tallest, int(1.3 * top_lm), 3 * 2 * sp["a"]) - 400
        if not built_primary and need > sp["h"]:
            new = min(int(math.ceil(need / 200.0) * 200), SPIRE_MAX)
            if new <= sp["h"]:
                lms.append(dict(kind="spire", height=sp["h"] + 400, top="octagon spire"))
                continue
            if notes is not None:
                notes.append("the grand spire grows %d -> %d (twice the tallest house, "
                             "%d, and 1.3 times the next landmark, %d)"
                             % (sp["h"], new, tallest, top_lm))
            sp["h"] = new
        lms.append(dict(kind="spire", height=sp["h"] + 400, top="octagon spire"))
    if not lms:
        return None
    prim = max(lms, key=lambda x: x["height"])
    for s in W.settlements:
        if not s["plaza"] or not s.get("want_echo", True):
            continue
        rows = set(sl["cell"][1] for sl in s.get("stalls", []))
        corners = sorted((c for c in s["plaza"] if c[1] not in rows),
                         key=lambda c: (-c[1], -c[0]))
        if corners:
            s["echo"] = {"cell": corners[0], "shape": prim["top"], "of": prim["kind"]}
    return {"primary": prim["kind"], "height": prim["height"], "house_top": tallest}
def readability(W):
    tallest = max([e.get("top_rel", 0) for e in W.houses] + [0])
    lms = []
    for x in W.landmarks:
        if "tier" not in x:
            continue
        d = dict(x)
        d["echo"] = False
        lms.append(d)
    for sp in W.spires:
        lms.append({"kind": "spire", "height": sp["h"] + 400, "width": 2 * sp["a"],
                    "mass_width": 2 * sp["a"], "tier": "primary" if sp.get("grand")
                    else "secondary", "top": "octagon spire", "use": "vantage",
                    "accent": True, "usable": True})
    for s in W.settlements:
        if s.get("echo"):
            lms.append({"kind": "echo", "height": 760, "width": 200, "mass_width": 200,
                        "tier": "tertiary", "top": "echo of %s" % s["echo"]["of"],
                        "use": "node", "accent": True, "usable": True, "echo": True})
    return landmarks.readability(lms, tallest)
def _body_rect(e):
    b = e["built"]
    bx = b.get("body")
    if not bx:
        return None
    cx, cz, _ = e["at"]
    r = houses.turn_rect(bx, e["face"])
    return (r[0] + cx, r[1] + cx, r[2] + cz, r[3] + cz)
def _gap(a, b):
    gx = max(a[0], b[0]) - min(a[1], b[1])
    gz = max(a[2], b[2]) - min(a[3], b[3])
    return gx, gz
def roof_check(W):
    from . import movement
    lo, hi = movement.CHIMNEY_MIN, movement.CHIMNEY_MAX
    es = [e for e in W.houses if "built" in e]
    rects = {id(e): _body_rect(e) for e in es}
    for e in es:
        e["roof_holds"] = True
        if e["built"]["intent"] != "out_of_reach":
            continue
        ra = rects[id(e)]
        if ra is None:
            continue
        eave = e["at"][2] + e["built"]["eave"]
        why = None
        for o in es:
            if o is e or rects[id(o)] is None:
                continue
            rb = rects[id(o)]
            gx, gz = _gap(ra, rb)
            d = max(gx, gz, 0)
            if gx > 0 and gz < 0 or gz > 0 and gx < 0:
                if lo <= d <= hi:
                    why = "a wall-kick gap of %d to a neighbour" % d
                    break
            otop = o["at"][2] + (o["built"]["top"] if o["built"]["intent"] != "out_of_reach"
                                 else max(houses.launch_tops(o["built"]) or [0]))
            if d <= houses.REACH_SAFE and eave - otop < houses.REACH_SAFE:
                why = "a neighbour's top %d under the eave within %d" % (eave - otop, d)
                break
        if why:
            e["roof_holds"] = False
            e["roof_note"] = why
    for e in es:
        if e.get("roof_holds") is False:
            st = style_of(W, e)
            e2 = dict(e, intent="climbable")
            b = build_entry(e2, st)
            if b is not None:
                cx, cz, y = e["at"]
                e["built"] = b
                e["world"] = houses.place(b, cx, cz, y, e["face"])
                e["intent"] = "climbable"
                s = W.settlements[e["settlement"]]
                note = "a %s at %s rebuilt climbable: %s" % (
                    houses.NAMES.get(e["recipe"], e["recipe"]), e["cell"], e["roof_note"])
                if note not in s["notes"]:
                    s["notes"].append(note)
def report(W):
    out = []
    for k, s in enumerate(W.settlements):
        hs = [e for e in W.houses if e.get("settlement") == k and "built" in e]
        intents = {}
        for e in hs:
            intents[e["built"]["intent"]] = intents.get(e["built"]["intent"], 0) + 1
        five = sum(1 for e in hs if e["built"]["recipe"] in houses.FIVE_PART
                   and all(houses.five_parts(e["built"]).values()))
        pieces = [p for e in hs for p in e["world"]]
        out.append({"kind": s["kind"], "name": s["name"], "district": s["district"],
                    "anchor": s["anchor"], "houses": len(hs), "rings": s["rings"],
                    "recipes": sorted(set(e["recipe"] for e in hs)),
                    "prefabs": s["prefabs"], "intents": intents,
                    "holds": sum(1 for e in hs if e.get("roof_holds", True)),
                    "enterable": sum(1 for e in hs if e["built"]["enterable"]),
                    "five_parts": five, "pieces": len(pieces),
                    "keys": len(houses.keys(pieces)), "style": s["style"],
                    "notes": list(s["notes"])})
    return out
