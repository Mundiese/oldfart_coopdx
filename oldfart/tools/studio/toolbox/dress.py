import copy
import random
from mapgen import beauty, kit, tops as topsmod, values as valuesmod
from mapgen.metrics import beauty as mbeauty
from mapgen.metrics.world import Piece as WorldPiece
from studio.editor import geometry as geo
from studio.editor.commands import Change
RULES = ("palette", "values", "tops", "trims", "pillars", "crenels", "legs", "light")
LABELS = {"palette": "Theme colours", "trims": "Edge rails",
          "pillars": "Wall pillars", "crenels": "Battlements",
          "legs": "Columns under overhangs", "light": "Light direction",
          "values": "Lighter and darker walls", "tops": "Grass and snow tops"}
RULE_IDS = {"palette": "R1, R2", "trims": "R3", "pillars": "R4", "crenels": "R7",
            "legs": "R10", "values": "M1", "tops": "M5"}
HAZARDS = ("lava", "hazardstripes")
LEG_MAX_GAP = 800
LEG = 200
CLEAR_RING = 400
CRENEL_THEMES = ("castle", "lava", "desert")
class Report:
    def __init__(self):
        self.rules = {}
        self.notes = []
        self.cap = 0
        self.theme = None
    def add(self, rule, n=1):
        self.rules[rule] = self.rules.get(rule, 0) + n
    def lines(self):
        out = ["%s: %d" % (LABELS.get(k, k), v) for k, v in sorted(self.rules.items()) if v]
        if not out:
            out = ["nothing to dress (every rule that fits is already met)"]
        return out + self.notes
def theme_of(doc):
    t = doc.brief.get("theme")
    if t in (None, "auto"):
        t = (doc.rest.get("report") or {}).get("beauty", {}).get("theme")
    return t if t in kit.THEMES else "castle"
def _in(box, rect):
    return box[0] < rect[1] and rect[0] < box[1] and box[4] < rect[3] and rect[2] < box[5]
def auto_dress(doc, refs=None, theme=None, rules=RULES, seed=1):
    rep = Report()
    theme = theme or theme_of(doc)
    rep.theme = theme
    rng = random.Random("dress:%s:%d" % (theme, seed))
    all_refs = doc.refs("piece")
    scope = [r for r in (refs if refs is not None else all_refs) if r[0] == "piece" and r in doc]
    pal, notes = beauty.palette(theme)
    rep.notes += notes
    accents = list(pal.get("accents") or [])
    current = {r: dict(doc.get(r)) for r in all_refs}
    steps = []
    if "palette" in rules and scope:
        keep = set(v for k, v in pal.items() if k != "accents" and isinstance(v, str)) | \
            set(accents) | set(HAZARDS)
        wp = [WorldPiece(i, current[r]) for i, r in enumerate(scope)]
        team = mbeauty.accent_textures(wp)
        for r, w in zip(scope, wp):
            p = current[r]
            if p["tex"] in keep or p["tex"] in team:
                continue
            role = mbeauty.role(w)
            tex = {"floor": pal.get("floor"), "wall": pal.get("wall"), "trim": pal.get("trim"),
                   "accent": accents[0] if accents else pal.get("wall"),
                   "mass": pal.get("cover") or pal.get("wall")}.get(role)
            if not tex or tex == p["tex"]:
                continue
            new = dict(p, tex=tex)
            for k in ("tex_top", "tex_side", "tex_bottom"):
                new.pop(k, None)
            steps.append(("replace", r, copy.deepcopy(p), copy.deepcopy(new)))
            current[r] = new
            rep.add("palette")
    if "values" in rules and scope:
        work = [dict(current[r]) for r in all_refs]
        before = [p["tex"] for p in work]
        rep.notes += valuesmod.measured(work, theme, doc.brief.get("family"))
        for r, p, was in zip(all_refs, work, before):
            if p["tex"] != was and r in scope:
                steps.append(("replace", r, copy.deepcopy(current[r]), copy.deepcopy(p)))
                current[r] = p
                rep.add("values")
    grown = []
    if "tops" in rules and scope:
        work = [dict(current[r]) for r in scope]
        n0 = len(work)
        budget = doc.rest.get("budget") or doc.brief.get("budget") or 120
        others = len(all_refs) - len(scope)
        rep.notes += topsmod.apply(work, theme, budget - others)
        for r, p in zip(scope, work[:n0]):
            if p != current[r]:
                steps.append(("replace", r, copy.deepcopy(current[r]), copy.deepcopy(p)))
                current[r] = p
                rep.add("tops")
        grown = work[n0:]
    spawns = doc.spawns()
    rings = [(s["x"] - CLEAR_RING, s["x"] + CLEAR_RING, s["z"] - CLEAR_RING, s["z"] + CLEAR_RING)
             for s in spawns]
    n = len(all_refs)
    budget = doc.rest.get("budget") or doc.brief.get("budget") or 120
    cap = max(0, min(int(0.25 * n) + 4, int(0.85 * budget) - n))
    rep.cap = cap
    dress = []
    pieces_now = [current[r] for r in all_refs]
    def free(p):
        b = geo.aabb(p)
        if any(_in(b, ring) for ring in rings):
            return False
        for q in pieces_now + dress:
            if q.get("tag", "").startswith("dress") and geo.overlap_volume(b, geo.aabb(q)) > 1:
                return False
        return True
    def add(p, rule):
        if len(dress) >= cap:
            return False
        if not free(p):
            return True
        dress.append(geo.cleaned(p))
        rep.add(rule)
        return True
    in_scope = [current[r] for r in scope]
    floor_y = 0 if doc.rest.get("level", "empty") == "empty" else None
    for g in grown:
        dress.append(geo.cleaned(g))
        rep.add("tops")
    if "legs" in rules and theme != "sky":
        for p in in_scope:
            if p["kind"] != "box" or p["h"] > 400:
                continue
            for leg in _legs(p, pieces_now, floor_y, pal.get("wall") or p["tex"]):
                if not add(leg, "legs"):
                    break
    if "trims" in rules:
        H = beauty.Heights(pieces_now + dress)
        clear = list(rings)
        for p in in_scope:
            if p["kind"] != "box" or mbeauty.role(WorldPiece(0, p)) != "floor":
                continue
            x0, x1, z0, z1 = beauty.rect_of(p)
            f = {"rect": (x0, x1, z0, z1), "y": p["y"] + p["h"], "zone": "field"}
            for run in beauty._edge_runs(f, H, [], clear):
                for (s0, s1) in beauty._split(run, rng.choice((4, 5))):
                    rect = beauty._rail_rect(run[4], s0, s1, f["rect"])
                    rail = kit.kind("box").make(pal["trim"], rect[0], rect[1], f["y"],
                                                f["y"] + beauty.RAIL_H, rect[2], rect[3],
                                                None, "dress.rail")
                    if not add(rail, "trims"):
                        break
    walls = beauty.long_walls(in_scope)
    if "pillars" in rules and walls:
        every = rng.choice((600, 800, 1000))
        tex = accents[1] if len(accents) > 1 else pal["wall"]
        for w in walls[:8]:
            for pillar in beauty.wall_pillars(w, every, tex):
                if not add(pillar, "pillars"):
                    break
    if "crenels" in rules and walls and theme in CRENEL_THEMES:
        for w in walls[:4]:
            for c in beauty.wall_crenels(w, pal["wall"]):
                if not add(c, "crenels"):
                    break
    if len(dress) >= cap and cap:
        rep.notes.append("R12: stopped at %d dress pieces (a quarter of the map, 85 %% of the "
                         "budget)" % cap)
    if dress:
        steps += _resolved_steps(doc, current, all_refs, dress)
    if "light" in rules:
        look = dict(doc.rest.get("look") or {})
        if not look.get("light"):
            lt, dark = kit.light(theme)
            look["light"] = lt
            steps.append(("rest", "look", copy.deepcopy(doc.rest.get("look")), look))
            rep.add("light")
    label = "Auto-dress (%s)" % (", ".join("%s %d" % (k, v) for k, v in sorted(rep.rules.items()))
                                 or "nothing to do")
    ch = Change(label, steps)
    ch.twins = True
    return ch, rep
def _legs(p, pieces, floor_y, tex):
    b = geo.aabb(p)
    xs = _spots(b[0], b[1])
    zs = _spots(b[4], b[5])
    for x in xs:
        for z in zs:
            below = None
            for q in pieces:
                if q is p:
                    continue
                qb = geo.aabb(q)
                if qb[0] <= x - LEG / 2 and x + LEG / 2 <= qb[1] and \
                        qb[4] <= z - LEG / 2 and z + LEG / 2 <= qb[5] and qb[3] <= p["y"] + 1:
                    if q["kind"] == "box" and (below is None or qb[3] > below):
                        below = qb[3]
            if below is None:
                below = floor_y
            if below is None:
                continue
            gap = p["y"] - below
            if 50 < gap <= LEG_MAX_GAP:
                yield kit.kind("box").make(tex, x - LEG / 2, x + LEG / 2, below, p["y"],
                                           z - LEG / 2, z + LEG / 2, None, "dress.leg")
def _spots(a0, a1):
    if a1 - a0 < LEG:
        return []
    lo, hi = a0 + LEG / 2, a1 - LEG / 2
    if hi - lo < LEG:
        return [(lo + hi) / 2]
    n = max(1, int((hi - lo) // 1200))
    return [lo + (hi - lo) * k / n for k in range(n + 1)]
def _resolved_steps(doc, current, all_refs, dress):
    from mapgen import solids
    from studio.editor import ops
    touched = []
    boxes = [geo.aabb(d) for d in dress]
    for r in all_refs:
        b = geo.aabb(current[r])
        if any(geo.overlap_volume(b, d) > 1 for d in boxes):
            touched.append(r)
    group = [dict(current[r]) for r in touched] + [dict(d) for d in dress]
    painted, _ = solids.resolve(group)
    had_model = any("model" in current[r] for r in all_refs)
    out = []
    for p in painted:
        p = dict(p)
        if not had_model:
            p.pop("model", None)
        out.append(geo.cleaned(p))
    steps = []
    ids = [i for i, _ in doc.items["piece"]]
    for r in sorted(touched, key=lambda r: -ids.index(r[1])):
        steps.append(("remove", r, ids.index(r[1]), copy.deepcopy(current[r])))
    steps += ops.insert(doc, [("piece", p) for p in out], "dress", select=False).steps
    return steps
