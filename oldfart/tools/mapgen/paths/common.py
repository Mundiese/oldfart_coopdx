from .. import kit, v1
from ..skeleton import anchor_direction
SIZE_NAMES = ("tiny", "small", "medium", "large", "huge")
def size_name(size):
    if size == "gigantic":
        return "huge"
    return size if isinstance(size, str) and size in SIZE_NAMES else "medium"
def want_avoid(brief):
    f = brief["features"]
    return set(f.get("want", [])), set(f.get("avoid", []))
def level_info(level):
    return v1.arenas_module().LEVELS[level]
def theme_of(brief):
    return brief["theme"] if brief["theme"] != "auto" else "sky"
def palette(brief):
    pal, notes = kit.palette(theme_of(brief), brief["palette"])
    def solid(tex, fallback):
        return kit.TRANSITION_BASE.get(tex, tex) if kit.layered(tex) else tex or fallback
    out = {
        "road": solid(pal["ramp"], "stone1"),
        "pad": solid(pal["deck"], "tile1"),
        "wall": solid(pal["wall"], "bricklightgrey"),
        "bridge": solid(pal["bridge"], "woodenplank2"),
        "floor": pal["floor"],
        "keel": solid(pal["keel"], "stone2"),
        "cover": solid(pal["cover"], "brickdarkgrey"),
        "trim": solid(pal["trim"], "rivetedplate"),
        "accents": [solid(t, "stone1") for t in pal["accents"]],
        "accents_built": [solid(t, "stone1") for t in pal.get("accents_built") or pal["accents"]],
    }
    for role in ("foliage", "hedge", "building", "roof", "path", "stair", "awning",
                 "wall_base", "wall_cap"):
        if pal.get(role):
            out[role] = solid(pal[role], out["wall"])
    if out["pad"] == out["road"]:
        out["pad"] = out["accents"][0] if out["accents"][0] != out["road"] else "tile1"
    return out, notes
def compass_score(x, z, where):
    vec = anchor_direction(where)
    if vec is None:
        return None
    if abs(vec[0]) < 1e-6 and abs(vec[1]) < 1e-6:
        return -(abs(x) + abs(z))
    n = (vec[0] ** 2 + vec[1] ** 2) ** 0.5
    return (x * vec[0] + z * vec[1]) / n
def fit_budget(pieces, markers, budget, droppable):
    notes = []
    for label, pred in droppable:
        if len(pieces) + len(markers) <= budget:
            break
        over = len(pieces) + len(markers) - budget
        drop = [m for m in markers if pred(m)]
        if not drop:
            continue
        drop = drop[-over:] if over < len(drop) else drop
        ids = set(id(m) for m in drop)
        markers = [m for m in markers if id(m) not in ids]
        notes.append("budget: dropped %d %s" % (len(drop), label))
    return markers, notes
def compat_params(across, extra):
    p = {"I": int(across // 2), "G": 0, "B": 0, "centre": extra.get("shape", "-"),
         "lane": extra.get("lane", "-"), "corner": extra.get("corner", "-"), "shield": "-"}
    p.update(extra)
    return p
def report_text(result):
    from ..explain import brief_text
    b = result.brief
    best = result.best
    meta = best.meta
    arena = best.arena
    out = ["# Map report - %s" % (b["name"] or b["key"] or "generated map"), "",
           "## The brief", "", "```", brief_text(b), "```", "", "## What was done", ""]
    for how, aid, note in meta["anchors"]:
        out.append("- [%s] %s: %s" % (how, aid, note))
    if not meta["anchors"]:
        out.append("- no anchors asked for")
    out.append("- modules: %s" % ", ".join("%s %s" % (k, v) for k, v in
                                          sorted(meta["modules"].items())))
    keep = ("shape", "lap_estimate_s", "lap_length", "course_estimate_s", "run_estimate_s",
            "W", "C", "gates", "chicanes", "shortcut_saves_s", "heights", "concepts",
            "max_class", "safety_floors", "rise", "regions", "perches", "cells")
    for k in keep:
        if k in meta["params"] and k != "cells":
            out.append("- %s: %s" % (k, meta["params"][k]))
    for n in meta["notes"]:
        out.append("- note: %s" % n)
    out += ["", "## Hard checks (v1's)", "",
            "- %s" % ("all passed" if best.ok else "; ".join(best.checks.faults))]
    if best.score:
        out += ["", "## Metrics (%s)" % best.score["source"], "",
                "| metric | value | band | status |", "|---|---|---|---|"]
        rows = best.score.get("rows", [])
        if isinstance(rows, dict):
            rows = [dict(r, metric=n) for n, r in rows.items() if r.get("value") is not None]
        for row in rows:
            if isinstance(row, dict):
                out.append("| %s | %s | %s | %s |" % (row.get("label") or row.get("metric"),
                                                     row.get("value"), row.get("band"),
                                                     row.get("status", row.get("score"))))
        out += ["", "Quality %.3f" % best.quality]
    out += ["", "## Candidates", ""]
    for c in sorted(result.candidates, key=lambda c: (-(c.quality or -1), c.index)):
        out.append("- candidate %d: %s, quality %s, %d pieces" % (
            c.index, "ok" if c.ok else "FAILED: " + "; ".join(c.checks.faults[:2]), c.quality,
            len(c.arena["pieces"])))
    out += ["", "## Cost and modes", "",
            "- %d pieces + %d markers against a budget of %d" % (
                len(arena["pieces"]), len(arena.get("markers", [])), arena["budget"]),
            "- survey: %s" % ", ".join(sorted(arena.get("survey", {}))) or "-",
            "- onlyFor: %s" % ", ".join(arena.get("onlyFor", [])),
            "- %s" % arena.get("note", ""),
            "", "## What only the game confirms", "",
            "- shells on the ramps and over the gap at real speed, the item rows and boost",
            "  pads where they are; jumps, nets and rests on foot; hiding spots with a camera.",
            ""]
    return "\n".join(out)
def footprint(pieces):
    m = v1.arenas_module()
    xs, zs = [], []
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        xs += [x0, x1]
        zs += [z0, z1]
    return min(xs), max(xs), min(zs), max(zs)
