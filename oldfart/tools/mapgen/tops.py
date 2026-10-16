from . import kit, values
TOP_CAP = {"garden": "grassblock", "ice": "snowblock", "desert": "sandblock"}
TOP_BUDGET = 0.9
MIN_AREA = 400 * 400
SOFT64_CAPS = {
    "grassblock": {"top": "grassmeadow", "side": "grassside", "bottom": "dirtbrown"},
    "snowblock": {"top": "snowfresh", "side": "snowside", "bottom": "dirtbrown"},
    "sandblock": {"top": "sandbeach", "side": "sandside", "bottom": "sandstone"},
}
def caps_from_soft64(palettes):
    out = {}
    for theme, row in (palettes.get("themes") or {}).items():
        cap = row.get("cap") if isinstance(row, dict) else None
        if isinstance(cap, dict) and {"top", "side", "bottom"} <= set(cap):
            out[theme] = dict(cap)
    return out
def _soft64_caps():
    try:
        from . import soft64
        for theme, block in soft64.caps().items():
            if theme in kit.THEMES:
                TOP_CAP[theme] = block
    except Exception:
        pass
def _rect(p):
    w, d = p["w"], p["d"]
    if int(round(p.get("yaw") or 0)) % 180 == 90:
        w, d = d, w
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def _covered(p, pieces, share=0.5):
    top = p["y"] + p["h"]
    x0, x1, z0, z1 = _rect(p)
    area = (x1 - x0) * (z1 - z0)
    over = 0.0
    for q in pieces:
        if q is p or abs(q["y"] - top) > 1:
            continue
        a0, a1, b0, b1 = _rect(q)
        w = min(x1, a1) - max(x0, a0)
        d = min(z1, b1) - max(z0, b0)
        if w > 0 and d > 0:
            over += w * d
    return area > 0 and over >= share * area
def apply(pieces, theme, budget=None, cap=None):
    notes = []
    have = kit.textures()
    under = 0
    for p in pieces:
        if p.get("kind") == "box" and not p.get("decor") and kit.layered(p.get("tex")) \
                and _covered(p, pieces):
            p["tex"] = kit.TRANSITION_BASE.get(p["tex"], p["tex"])
            values.remodel(p)
            under += 1
    if under:
        notes.append("auto-tops: %d transition block(s) under another piece wear their base"
                     % under)
    cap = cap or TOP_CAP.get(theme)
    if cap is None or cap not in have:
        return notes
    base = kit.TRANSITION_BASE.get(cap)
    room = (int(TOP_BUDGET * budget) - len(pieces)) if budget else 10 ** 6
    cands = [p for p in pieces if p.get("kind") == "box" and p.get("tex") == base
             and not p.get("decor")
             and p["w"] * p["d"] >= MIN_AREA and not _covered(p, pieces)
             and not str(p.get("tag", "")).startswith("dress.backdrop")]
    cands.sort(key=lambda p: -(p["w"] * p["d"]))
    grown = 0
    for p in cands:
        if p["h"] <= kit.TRANSITION_MAX:
            p["tex"] = cap
            values.remodel(p)
            grown += 1
            continue
        if room < 1:
            continue
        top = p["y"] + p["h"]
        p["h"] -= kit.TRANSITION_MAX
        slab = dict(p, y=top - kit.TRANSITION_MAX, h=kit.TRANSITION_MAX, tex=cap)
        slab["tag"] = str(p.get("tag", "")) + " top"
        values.remodel(p)
        values.remodel(slab)
        pieces.append(slab)
        room -= 1
        grown += 1
    if grown:
        notes.append("auto-tops: %s on %d top block(s) under the sky" % (cap, grown))
    notes += cliff_tops(pieces, theme)
    return notes
CLIFF_CAP = {"garden": "grasscliffcube", "ice": "snowcliffcube", "wood": "grasscliffcube"}
CLIFF_ROCK = ("rockgrey", "mossyrock", "rockdark", "rockbrown")
CAP_TOPS = {"grasscliffcube": ("grassteal", "grasslush", "grassmeadow", "grassblock",
                               "grasslushcube", "grassdry"),
            "snowcliffcube": ("snowfresh", "snowblock", "snow")}
def cliff_tops(pieces, theme):
    cap = CLIFF_CAP.get(theme)
    have = kit.textures()
    if cap is None or cap not in have:
        return []
    from . import v1
    m = v1.arenas_module()
    rocks = [p for p in pieces if p.get("kind") == "box" and p.get("tex") in CLIFF_ROCK]
    if not rocks:
        return []
    top_of = {}
    for q in rocks:
        top_of.setdefault(int(round(q["y"] + q["h"])), []).append((q, m.footprint(q)))
    n = 0
    for p in pieces:
        if p.get("kind") != "box" or p.get("decor") or p.get("tex") not in CAP_TOPS[cap] \
                or p["h"] > kit.TRANSITION_MAX:
            continue
        r = m.footprint(p)
        area = (r[1] - r[0]) * (r[3] - r[2])
        under = 0.0
        for q, s in top_of.get(int(round(p["y"])), ()):
            ox = min(r[1], s[1]) - max(r[0], s[0])
            oz = min(r[3], s[3]) - max(r[2], s[2])
            if ox > 0 and oz > 0:
                under += ox * oz
        if area > 0 and under >= 0.5 * area and not _covered(p, pieces):
            p["tex"] = cap
            values.remodel(p)
            n += 1
    return ["cliff tops: %d caps on rock wear %s" % (n, cap)] if n else []
_soft64_caps()
