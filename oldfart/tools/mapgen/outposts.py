from . import houses
from .layout import overlaps, rect_of
KINDS = {
    "shed":   ("H1", dict(intent="climbable", enterable=True, openings=2), "buildings"),
    "bunker": ("H6", dict(intent="vantage"), "bunkers"),
    "lookout": ("H13", {}, "perches"),
    "tower":  (None, {}, "towers"),
}
SMALL = {"shed": ("H1", dict(intent="climbable"))}
PER_UNIT = 2
C = 200
def wanted(L):
    brief = L.brief
    feats = brief["features"]
    if "buildings" in feats["avoid"] or brief["verticality"] == "flat":
        return False
    if L.params.get("skeleton") == "rooms" or getattr(L, "rooms_plan", None):
        return False
    if L.family not in ("shooter", "objective"):
        return False
    if "buildings" in feats["want"] or brief.get("style") == "built":
        return True
    return L.dice is not None and L.dice["buildings"] >= 2
def _face_to_centre(cx, cz):
    if abs(cx) >= abs(cz):
        return "w" if cx > 0 else "e"
    return "n" if cz > 0 else "s"
def watchtower(st, r, tag):
    o = houses.Out(tag)
    b = houses.Body(-2 * C, 2 * C, -2 * C, 2 * C, houses.PLINTH_H, 2)
    houses.plinth(o, st, b)
    wall = houses._wall_of(st, r)
    o.box(wall, b.x0, b.x1, b.y, b.top, b.z0, b.z1, "walls", "wall")
    door_pt, cut = houses.door_solid(o, st, b)
    sw = dict(st, wall=wall)
    houses.windows(o, sw, b, 0, ["back", "left", "right"], alt=st.get("window_alt"))
    houses.windows(o, sw, b, 1, ["front", "back", "left", "right"],
                   alt=st.get("window_alt"))
    top = houses.roof(o, st, b, form="pyramid", pitch="steep")
    return houses._finish(o, "T1", b, "out_of_reach", False, 0, door_pt, top,
                          ["a watchtower: the shooter's tall mark"])
def make(kind, st, r, tag, small=False):
    if small:
        recipe, opts = SMALL[kind]
        lot = houses.lot_of(recipe)
        return houses.build(recipe, st, (lot[0] * 400, lot[1] * 400), r, tag=tag, **opts)
    recipe, opts, _ = KINDS[kind]
    if recipe is None:
        return watchtower(st, r, tag)
    lot = houses.lot_of(recipe, opts.get("enterable", False), opts.get("openings", 1))
    lot = (lot[0] * 400, lot[1] * 400)
    b = houses.build(recipe, st, lot, r, tag=tag, **opts)
    return b
def run(F, L, budget):
    if not wanted(L) or budget <= 0:
        return 0
    r = L.streams("outposts")
    try:
        st = houses.style_for(L.brief["theme"], L.pal, r, "shooter")
    except Exception as why:
        L.report.setdefault("outposts", {})["why"] = "no style (%s)" % why.__class__.__name__
        return 0
    d = L.dice
    kinds = sorted(KINDS)
    weights = [max(0.1, d.factor(KINDS[k][2]) if d is not None else 1.0) for k in kinds]
    floors = sorted((fi for fi, f in enumerate(L.floors)
                     if f["fill"] and f["zone"] not in ("base", "lane")),
                    key=lambda fi: -_area(L.floors[fi]["rect"]))
    used, laid = 0, []
    units = F.sym.units
    for _ in range(PER_UNIT):
        left = list(zip(kinds, weights))
        order = []
        while left:
            x = r.random() * sum(w for _, w in left)
            pick = left[-1]
            for kw in left:
                x -= kw[1]
                if x < 0:
                    pick = kw
                    break
            order.append(pick[0])
            left.remove(pick)
        order.sort(key=lambda k: k in laid)
        done = False
        for fi in floors:
            f = L.floors[fi]
            for kind in order:
                spot = None
                for small in ((False, True) if kind in SMALL else (False,)):
                    b = make(kind, st, r, "fill.outpost_%s" % kind, small=small)
                    if b is None or used + len(b["pieces"]) * units > budget:
                        continue
                    spot = _spot(F, L, f, b)
                    if spot is not None:
                        break
                if spot is None:
                    continue
                cx, cz, face, foot = spot
                pieces = houses.place(b, cx, cz, f["y"], face)
                group = []
                for p in pieces:
                    group += F.sym.pieces(p)
                F.pieces += group
                F.groups.append(group)
                F.placed += F.sym.rects(foot)
                for p in group:
                    F.solids.append((rect_of(p), p["y"], p["y"] + p["h"]))
                used += len(group)
                laid.append(kind)
                F.log.append("outpost_" + kind)
                top = max(p["y"] + p["h"] for p in pieces)
                L.notes.append("outpost: a %s (%s, %s) on the %s floor, its door to the "
                               "middle, top %d" % (kind, houses.NAMES.get(KINDS[kind][0], "watchtower"),
                                                   b["intent"], f["zone"], top))
                done = True
                break
            if done:
                break
        if not done:
            break
    L.report.setdefault("outposts", {}).update({"laid": laid, "pieces": used})
    return used
def _area(rect):
    return (rect[1] - rect[0]) * (rect[3] - rect[2])
def _spot(F, L, f, b):
    x0, x1, z0, z1 = f["rect"]
    mx, mz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    face = _face_to_centre(mx, mz)
    fx0, fx1, fz0, fz1 = houses.turn_rect(b["foot"], face)
    gx0, gz0 = (fx0 // C) * C, (fz0 // C) * C
    wc = int(-(-(fx1 - gx0) // C))
    dc = int(-(-(fz1 - gz0) // C))
    area = (x0 - 1200, x1 + 1200, z0 - 1200, z1 + 1200)
    solids = [t for t in F.solids if overlaps(t[0], area)]
    keeps = [k for k in F.keeps if overlaps(k, area)]
    cands = []
    cx = x0 - gx0
    while cx + gx0 + wc * C <= x1:
        cz = z0 - gz0
        while cz + gz0 + dc * C <= z1:
            cands.append((abs(cx - mx) + abs(cz - mz), cx, cz))
            cz += C
        cx += C
    cands.sort()
    for _, cx, cz in cands[:400]:
        fit = F.fits(f, [], wc, dc, "nsew", int(cx + gx0), int(cz + gz0), solids, keeps)
        if fit is None:
            continue
        if not F.still_fits({"foot": fit[0]}):
            continue
        return int(cx), int(cz), face, fit[0]
    return None
