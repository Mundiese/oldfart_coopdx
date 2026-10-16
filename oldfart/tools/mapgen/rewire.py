import copy
from . import cyclic
LINK_GAP = (300, 1600)
LINK_W = 400
LINK_RISE = 600
TOUCH = 100
JUMP = 200
HEAD = 250
OVERLAP_MIN = 600
SHARE = 0.5
FUN_RULES = ("lf1_viable_routes", "lf3_flank_unseen", "lf4_flank_angle", "cb1_home_ratio",
             "cb2_unseen_exits")
FUN_WORDS = {"flanks": ("flank",), "routes": ("shortcut", "close"), "loops": ("shortcut", "close"),
             "move_shortcuts": ("shortcut",)}
def _rect(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw") or 0)) % 180 == 90:
        w, d = d, w
    return (p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0)
def _overlap(a0, a1, b0, b1):
    return min(a1, b1) - max(a0, b0)
def _touch(a, b, gap=TOUCH):
    ox = _overlap(a[0], a[1], b[0], b[1])
    oz = _overlap(a[2], a[3], b[2], b[3])
    if ox > 0 and oz > 0:
        return True
    return (ox >= -gap and oz >= TOUCH) or (oz >= -gap and ox >= TOUCH)
def floors(L):
    out, seen = [], set()
    for f in L.floors:
        rects = L.sym.rects(f["rect"]) if f.get("copy", True) else [tuple(f["rect"])]
        for r in rects:
            k = (tuple(round(v) for v in r), round(f["y"]))
            if k in seen:
                continue
            seen.add(k)
            out.append({"rect": tuple(r), "y": f["y"], "zone": f.get("zone")})
    return out
def graph(L, fl=None):
    fl = floors(L) if fl is None else fl
    nodes = list(range(len(fl)))
    edges = set()
    for i in nodes:
        for j in range(i + 1, len(fl)):
            if abs(fl[i]["y"] - fl[j]["y"]) <= JUMP and _touch(fl[i]["rect"], fl[j]["rect"]):
                edges.add((i, j))
    for p in L.structure + L.top:
        if p.get("kind") not in ("ramp", "stairs"):
            continue
        r = _rect(p)
        lo = [i for i in nodes if abs(fl[i]["y"] - p["y"]) <= 10 and _touch(r, fl[i]["rect"])]
        hi = [i for i in nodes if abs(fl[i]["y"] - (p["y"] + p["h"])) <= 10
              and _touch(r, fl[i]["rect"])]
        for a in lo:
            for b in hi:
                if a != b:
                    edges.add((min(a, b), max(a, b)))
    return nodes, sorted(edges)
def links_of(fa, fb):
    out = []
    a, b = fa["rect"], fb["rect"]
    dy = fb["y"] - fa["y"]
    for axis in ("x", "z"):
        if axis == "x":
            lo_a, hi_a, lo_b, hi_b = a[0], a[1], b[0], b[1]
            share = _overlap(a[2], a[3], b[2], b[3])
            mid = (max(a[2], b[2]) + min(a[3], b[3])) / 2.0
        else:
            lo_a, hi_a, lo_b, hi_b = a[2], a[3], b[2], b[3]
            share = _overlap(a[0], a[1], b[0], b[1])
            mid = (max(a[0], b[0]) + min(a[1], b[1])) / 2.0
        if share < OVERLAP_MIN:
            continue
        if hi_a <= lo_b:
            g0, g1, sign = hi_a, lo_b, 1
        elif hi_b <= lo_a:
            g0, g1, sign = hi_b, lo_a, -1
        else:
            continue
        gap = g1 - g0
        if not LINK_GAP[0] <= gap <= LINK_GAP[1]:
            continue
        mid = int(round(mid / 100.0)) * 100
        w0, w1 = mid - LINK_W // 2, mid + LINK_W // 2
        rect = (g0, g1, w0, w1) if axis == "x" else (w0, w1, g0, g1)
        if dy == 0:
            out.append({"kind": "bridge", "rect": rect, "y0": fa["y"], "y1": fa["y"],
                        "rises": None, "floor": None})
        elif abs(dy) <= LINK_RISE and gap >= 2 * abs(dy):
            up = sign if dy > 0 else -sign
            rises = ("+" if up > 0 else "-") + axis
            out.append({"kind": "ramp", "rect": rect, "y0": min(fa["y"], fb["y"]),
                        "y1": max(fa["y"], fb["y"]), "rises": rises, "floor": None})
    lo, hi = (fa, fb) if dy > 0 else (fb, fa)
    rise = abs(dy)
    if JUMP < rise <= LINK_RISE:
        L_, H_ = lo["rect"], hi["rect"]
        run = 2 * rise
        for side in ("x0", "x1", "z0", "z1"):
            if side in ("x0", "x1"):
                along = (max(H_[2], L_[2]), min(H_[3], L_[3]))
                face = H_[0] if side == "x0" else H_[1]
                x0, x1 = (face - run, face) if side == "x0" else (face, face + run)
                if along[1] - along[0] < OVERLAP_MIN or x0 < L_[0] or x1 > L_[1]:
                    continue
                m = int(round((along[0] + along[1]) / 200.0)) * 100
                rect = (x0, x1, m - LINK_W // 2, m + LINK_W // 2)
                rises = "+x" if side == "x0" else "-x"
            else:
                along = (max(H_[0], L_[0]), min(H_[1], L_[1]))
                face = H_[2] if side == "z0" else H_[3]
                z0, z1 = (face - run, face) if side == "z0" else (face, face + run)
                if along[1] - along[0] < OVERLAP_MIN or z0 < L_[2] or z1 > L_[3]:
                    continue
                m = int(round((along[0] + along[1]) / 200.0)) * 100
                rect = (m - LINK_W // 2, m + LINK_W // 2, z0, z1)
                rises = "+z" if side == "z0" else "-z"
            if rect[2] < L_[2] or rect[3] > L_[3] or rect[0] < L_[0] or rect[1] > L_[1]:
                continue
            out.append({"kind": "ledge ramp", "rect": rect, "y0": lo["y"], "y1": hi["y"],
                        "rises": rises, "floor": lo["y"]})
    return out
def link_of(fa, fb):
    got = links_of(fa, fb)
    return got[0] if got else None
def _clear(L, rect, y0, y1, floor=None):
    bottom = floor + 1 if floor is not None else y0 - 100
    for p in L.structure + L.top:
        r = _rect(p)
        if _overlap(r[0], r[1], rect[0], rect[1]) <= 1 or _overlap(r[2], r[3], rect[2], rect[3]) <= 1:
            continue
        if p["y"] < y1 + HEAD and p["y"] + p["h"] > bottom:
            return False
    return True
def _copies_apart(L, rect):
    rs = L.sym.rects(rect)
    for i, a in enumerate(rs):
        for b in rs[i + 1:]:
            if _overlap(a[0], a[1], b[0], b[1]) > -TOUCH and _overlap(a[2], a[3], b[2], b[3]) > -TOUCH:
                return False
    return True
def allowed_links(L, fl, edges):
    have = set(edges)
    out = {}
    for i in range(len(fl)):
        for j in range(i + 1, len(fl)):
            if (i, j) in have:
                continue
            for lk in links_of(fl[i], fl[j]):
                if _clear(L, lk["rect"], lk["y0"], lk["y1"], lk.get("floor")) and \
                        _copies_apart(L, lk["rect"]):
                    out[(i, j)] = lk
                    break
    return out
def lay(L, lk, tag="link"):
    from . import skeletons
    x0, x1, z0, z1 = lk["rect"]
    if lk["kind"] == "bridge":
        skeletons.bridge(L, lk["rect"], lk["y0"], "%s bridge" % tag)
    elif lk["kind"] == "ledge ramp":
        skeletons.ramp(L, x0, x1, lk["y0"], lk["y1"], z0, z1, lk["rises"], "%s ramp" % tag)
    else:
        skeletons.ramp(L, x0, x1, lk["y0"], lk["y1"], z0, z1, lk["rises"], "%s ramp" % tag)
        L.floor(lk["rect"], lk["y1"], "lane", fill=False)
    L.opening((x0 - 100, x1 + 100, z0 - 100, z1 + 100))
    L.keep((x0 - 100, x1 + 100, z0 - 100, z1 + 100))
def wished_rules(brief):
    want = set((brief.get("features") or {}).get("want") or ())
    rules = []
    for w, rs in FUN_WORDS.items():
        if w in want:
            rules += [r for r in rs if r not in rules]
    if base_wished(brief):
        rules += [r for r in ("close", "shortcut", "flank") if r not in rules]
    return tuple(rules)
def base_wished(brief):
    return "spawn_camping" in ((brief.get("features") or {}).get("avoid") or ())
def plan(L, r, steps=None, rules=None):
    fl = floors(L)
    nodes, edges = graph(L, fl)
    allowed = allowed_links(L, fl, edges)
    if base_wished(L.brief):
        at_base = {e: lk for e, lk in allowed.items()
                   if "base" in (fl[e[0]]["zone"], fl[e[1]]["zone"])}
        allowed = at_base or allowed
    if not allowed:
        return [], "no two floors face each other across open air the kit can span"
    rules = rules or cyclic.RULES
    steps = steps if steps is not None else 1 + (1 if r.random() < 0.5 else 0)
    def length(e):
        lk = allowed[e]
        x0, x1, z0, z1 = lk["rect"]
        return max(x1 - x0, z1 - z0)
    new, log = cyclic.rewrite(nodes, edges, list(allowed), r, steps, length=length, rules=rules)
    if not log:
        return [], "no %s link the space can carry" % "/".join(rules)
    out, seen = [], set()
    for rule, a, b in log:
        lk = allowed[(min(a, b), max(a, b))]
        key = tuple(sorted(L.sym.rects(lk["rect"])))
        if key in seen:
            continue
        seen.add(key)
        out.append((rule, lk))
    return out, None
def fun_closeness(arena, brief):
    from . import metrics
    from .metrics import targets
    res = metrics.measure(arena, family=brief["family"], tier="full",
                          players=brief["players"], size=brief.get("size"))
    bands = targets.bands(brief["family"], brief.get("size"))
    out = {}
    for k in FUN_RULES:
        if k in bands:
            out[k] = bands[k].closeness(res["metrics"].get(k))
    return out
def keeps_fun(before, after):
    worse = []
    for k, b in before.items():
        a = after.get(k)
        if b is None:
            continue
        if a is None or a < b - 1e-9:
            worse.append(k)
    return not worse, worse
def finish(L):
    from . import layout
    brief = L.brief
    r = L.streams("rewire")
    rules = wished_rules(brief)
    if not rules and r.random() >= SHARE:
        return layout.finish(L)
    links, why = plan(L, r, rules=rules or None)
    if not links:
        arena, meta = layout.finish(L)
        if rules:
            meta.setdefault("notes", []).append("rewire: no new link (%s)" % why)
        return arena, meta
    base = copy.deepcopy(L)
    try_L = L
    for rule, lk in links:
        lay(try_L, lk, tag="link %s" % rule)
    arena1, meta1 = layout.finish(try_L)
    arena0, meta0 = layout.finish(base)
    try:
        before = fun_closeness(arena0, brief)
        after = fun_closeness(arena1, brief)
    except Exception as e:
        meta0.setdefault("notes", []).append("rewire: not measured (%s)" % e.__class__.__name__)
        return arena0, meta0
    ok, worse = keeps_fun(before, after)
    said = ", ".join("%s %s %s" % (rule, lk["kind"], "x".join(str(int(v)) for v in (
        lk["rect"][1] - lk["rect"][0], lk["rect"][3] - lk["rect"][2]))) for rule, lk in links)
    if not ok:
        meta0.setdefault("notes", []).append(
            "rewire: %s taken out again - it cost %s" % (said, ", ".join(worse)))
        meta0.setdefault("modules", {})["rewire"] = "kept none"
        return arena0, meta0
    meta1.setdefault("notes", []).append(
        "rewire: %s (the fun rules kept or better: %s)" % (said, ", ".join(
            "%s %.2f->%.2f" % (k, before[k], after[k]) for k in sorted(before)
            if before[k] is not None and after.get(k) is not None)))
    meta1.setdefault("modules", {})["rewire"] = ", ".join(rule for rule, _ in links)
    return arena1, meta1
