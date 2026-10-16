from . import v1
BANDS = {
    "shooter": (6, 10, 0.6, 0.15, 0.35),
    "objective": (7, 11, 0.6, 0.20, 0.40),
    "course": (6, 10, 0.5, 0.15, 0.35),
    "race": (5, 9, 0.6, 0.40, 0.65),
    "knockoff": (3, 6, 0.5, 0.10, 0.30),
    "party": (4, 8, 0.5, 0.20, 0.45),
    "hide": (8, 12, 0.7, 0.25, 0.45),
    "explore": (10, 14, 0.7, 0.25, 0.50),
}
FAMILY_OF = {"ctf": "objective", "domination": "objective", "koth": "objective",
             "sumo": "knockoff", "chase": "hide", "hunt": "hide"}
ROOFS = ("ridge", "pyramid", "prism", "roundcorner", "ramp", "outer", "inner")
CAPS = ("pyramid", "prism", "ridge", "roundcorner")
CORNERS = ("outer", "inner", "outerstairs", "innerstairs", "roundcorner")
def _root(p):
    t = str(p.get("tag", "")).lower()
    return t.split(".")[0].split(" ")[0]
def _visible(p):
    return p.get("tex") != "invisible" and p.get("kind") != "water"
def _groups(pieces, roots):
    m = v1.arenas_module()
    out = []
    for p in pieces:
        if _root(p) not in roots:
            continue
        x0, x1, z0, z1, _ = m.footprint(p)
        for g in out:
            if g["rect"][0] - 1 <= x1 and x0 <= g["rect"][1] + 1 and \
                    g["rect"][2] - 1 <= z1 and z0 <= g["rect"][3] + 1 and g["root"] == _root(p):
                g["rect"] = (min(g["rect"][0], x0), max(g["rect"][1], x1),
                             min(g["rect"][2], z0), max(g["rect"][3], z1))
                g["pieces"].append(p)
                break
        else:
            out.append({"root": _root(p), "rect": (x0, x1, z0, z1), "pieces": [p]})
    return out
def sites(arena):
    pieces = arena.get("pieces") or []
    out = []
    for g in _groups(pieces, ("house", "cottage", "prefab", "hut")):
        ps = g["pieces"]
        roofed = any(p["kind"] in ROOFS for p in ps) or any(
            "parapet" in str(p.get("tag", "")) for p in ps)
        out.append(("roof", roofed))
        for p in ps:
            if str(p.get("tag", "")).endswith((".door", ".lintel")) and \
                    min(p.get("w", 0), p.get("d", 0)) >= 0 and max(p.get("w", 0), p.get("d", 0)) >= 400:
                out.append(("arch", p["kind"] == "arch"))
    for g in _groups(pieces, ("tower", "spire", "landmark", "watchtower", "turret", "keep",
                              "obelisk", "lighthouse")):
        ps = g["pieces"]
        top = max(p["y"] + p["h"] for p in ps)
        capped = any(p["kind"] in CAPS and p["y"] + p["h"] >= top - 1 for p in ps) or any(
            "crenel" in str(p.get("tag", "")) or "merlon" in str(p.get("tag", ""))
            or "battlement" in str(p.get("tag", "")) for p in ps)
        out.append(("cap", capped))
    from . import guards
    try:
        fl = guards.flights(arena)
    except Exception:
        fl = []
    for f in fl:
        if f["rule"] == "ST6":
            out.append(("side", False))
    cheeks = sum(1 for p in pieces if str(p.get("tag", "")).endswith(".cheek"))
    out += [("side", True)] * cheeks
    ramps = [p for p in pieces if p.get("kind") in ("ramp", "stairs") and
             _root(p) in ("slope", "hills")]
    corners = [p for p in pieces if p.get("kind") in CORNERS]
    if ramps:
        n = _run_ends(ramps)
        out += [("corner", True)] * min(len(corners), n)
        out += [("corner", False)] * max(0, n - len(corners))
    return out
def _run_ends(ramps):
    m = v1.arenas_module()
    rects = []
    for p in ramps:
        x0, x1, z0, z1, up = m.footprint(p)
        rects.append((x0, x1, z0, z1, "x" if up[0] else "z", p["y"]))
    n = 0
    for i, a in enumerate(rects):
        for b in rects[i + 1:]:
            if a[4] == b[4] or abs(a[5] - b[5]) > 1:
                continue
            touch_x = min(a[1], b[1]) - max(a[0], b[0])
            touch_z = min(a[3], b[3]) - max(a[2], b[2])
            if (touch_x == 0 and touch_z <= 0) or (touch_z == 0 and touch_x <= 0):
                if touch_x >= -1 and touch_z >= -1:
                    n += 1
    return n
def measure(arena):
    from . import kitpass
    pieces = [p for p in arena.get("pieces") or [] if _visible(p)]
    count = {}
    for p in pieces:
        kind = "decor" if p.get("decor") else p["kind"]
        count[kind] = count.get(kind, 0) + 1
    st = sites(arena)
    fitted = sum(1 for _, ok in st if ok)
    show = set("dress.%s" % f for f in getattr(kitpass, "SHOWCASE", {}))
    forced = sum(1 for p in pieces if p.get("tag") in show)
    return {"kinds_used": sum(1 for v in count.values() if v >= 2),
            "kinds": dict(sorted(count.items())),
            "fit_coverage": round(fitted / float(len(st)), 3) if st else None,
            "sites": len(st),
            "non_box_share": round(1 - count.get("box", 0) / float(len(pieces)), 3)
            if pieces else 0.0,
            "forced": forced}
def judge(family, m):
    b = BANDS.get(FAMILY_OF.get(family, family))
    if not b:
        return {}
    out = {"kinds_used": "under" if m["kinds_used"] < b[0] else "over" if m["kinds_used"] > b[1]
           else "in", "forced": "in" if m["forced"] == 0 else "over"}
    if m["fit_coverage"] is not None:
        out["fit_coverage"] = "in" if m["fit_coverage"] >= b[2] else "under"
    out["band"] = {"kinds_used": [b[0], b[1]], "fit_coverage": b[2],
                   "non_box_share (reported)": [b[3], b[4]]}
    return out
