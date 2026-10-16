HIGH_VERTICALITY = 0.667
FLAT_VERTICALITY = 0.2
OPEN_OPENNESS = 0.667
JUMP = 200
FIT_FAMILIES = ("shooter", "objective", "hide")
def targets(brief):
    if brief["family"] not in FIT_FAMILIES:
        return []
    out = []
    vert = brief["verticality"]
    defaulted = set(getattr(brief, "defaulted", ()) or ())
    if "verticality" not in defaulted:
        if vert == "high":
            out.append(("verticality", HIGH_VERTICALITY, None, "verticality high"))
            out.append(("layers", 3, None, "verticality high: three height layers"))
        elif vert == "flat":
            out.append(("rise", None, JUMP, "verticality flat: nothing over a jump"))
    if "tall_walls" in brief["features"]["avoid"]:
        out.append(("rise", None, JUMP, "no walls higher than a jump"))
    if "second_floor" in brief["features"]["want"]:
        out.append(("layers", 2, 2 if vert != "high" else None, "two floors"))
    want = set(brief["features"]["want"])
    avoid = set(brief["features"]["avoid"])
    if "flanks" in want:
        out.append(("lf1_viable_routes", 3, None, "flanks: three ways within 1.3x the fastest"))
        out.append(("lf3_flank_unseen", 0.6, None, "flanks: out of sight of the main way"))
        out.append(("lf4_flank_angle", 60, None, "flanks: arriving from the side"))
    if "routes" in want:
        out.append(("lf1_viable_routes", 3, None, "routes: three ways within 1.3x the fastest"))
    if "comeback" in want:
        out.append(("cb1_home_ratio", None, 0.7, "comeback: the losing side's trip is shorter"))
    if "spawn_camping" in avoid:
        out.append(("exits_per_base", 3, None, "no spawn camping: three ways out of a base"))
        out.append(("cb2_unseen_exits", 2, None, "no spawn camping: exits no camper sees"))
    if "move_shortcuts" in want:
        if brief["family"] == "hide":
            out.append(("vm1_shortcuts", 4, None, "move shortcuts: four a map"))
        else:
            out.append(("vm1_per_unit", 2, None, "move shortcuts: two per symmetry unit"))
    from .layout import open_map
    if open_map(brief):
        out.append(("openness", OPEN_OPENNESS, None, "an open map"))
    from . import modeknow
    needs = modeknow.spawn_needs_for(brief["modes"], brief["family"])
    if needs.get("point_gap_min") and ("domination" in (brief["modes"] or [])):
        out.append(("point_gap", needs["point_gap_min"], None,
                    "Domination: every pair of points more than %d apart"
                    % needs["point_gap_min"]))
    if needs.get("spawn_points") and brief["family"] == "shooter":
        out.append(("spawn_points", needs["spawn_points"], None,
                    "a free-for-all shooter: a point per player"))
    seen = {}
    for name, lo, hi, why in out:
        if name in seen:
            _, lo0, hi0, why0 = seen[name]
            lo = lo0 if lo is None else (lo if lo0 is None else max(lo, lo0))
            hi = hi0 if hi is None else (hi if hi0 is None else min(hi, hi0))
            why = why0 if why0 == why else "%s; %s" % (why0, why)
        seen[name] = (name, lo, hi, why)
    return list(seen.values())
def rise(arena, main):
    worst = 0
    for p in arena["pieces"]:
        if p["kind"] in ("ramp", "stairs", "outer", "inner", "outerstairs", "innerstairs",
                         "bank", "ridge", "pyramid"):
            continue
        if p["y"] >= main - 1:
            worst = max(worst, p["y"] + p["h"] - main)
    return worst
def point_gap(arena):
    import math
    pts = [p for p in ((arena.get("survey") or {}).get("points") or [])[:3]
           if isinstance(p, dict)]
    if len(pts) < 3:
        return None
    return min(math.hypot(a["x"] - b["x"], a["z"] - b["z"])
               for i, a in enumerate(pts) for b in pts[i + 1:])
def spawn_gap(arena):
    import math
    pts = [p for p in ((arena.get("survey") or {}).get("points") or []) if isinstance(p, dict)]
    if len(pts) < 2:
        return None
    near = sorted(min(math.hypot(a["x"] - b["x"], a["z"] - b["z"]) for b in pts if b is not a)
                  for a in pts)
    return near[len(near) // 2]
def value_of(name, res, arena):
    m = res.get("metrics", {}) if res else {}
    if name == "point_gap":
        return point_gap(arena)
    if name == "spawn_points":
        return len([p for p in ((arena.get("survey") or {}).get("points") or [])
                    if isinstance(p, dict)])
    if name == "rise":
        return rise(arena, m.get("main_plane", 0))
    if name == "layers":
        return m.get("layers")
    if name == "openness":
        return m.get("openness")
    if name == "verticality":
        from .metrics import qd
        return qd.descriptors(res).get("verticality")
    if name in FUN_ASKS:
        v = m.get(name)
        return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None
    return None
FUN_ASKS = ("lf1_viable_routes", "lf3_flank_unseen", "lf4_flank_angle", "cb1_home_ratio",
            "cb2_unseen_exits", "exits_per_base", "vm1_per_unit", "vm1_shortcuts")
FULL_ASKS = ("openness", "lf3_flank_unseen", "lf4_flank_angle", "cb2_unseen_exits")
def measure_fit(brief, res, arena, names=None):
    out = []
    for name, lo, hi, why in targets(brief):
        if names is not None and name not in names:
            continue
        v = value_of(name, res, arena)
        if v is None:
            continue
        ok = (lo is None or v >= lo - 1e-9) and (hi is None or v <= hi + 1e-9)
        want = (">= %s" % lo) if hi is None else ("<= %s" % hi) if lo is None else \
            "%s-%s" % (lo, hi)
        out.append({"name": name, "value": round(v, 3) if isinstance(v, float) else v,
                    "ok": ok, "want": want, "why": why})
    return out
def met(fit):
    return sum(1 for f in fit or () if f["ok"])
def misses(fit):
    return ["%s: %s is %s, the wish asks %s - the best of the candidates "
            "built; try another seed or fewer other asks" % (f["why"], f["name"], f["value"],
                                                            f["want"])
            for f in fit or () if not f["ok"]]
BAND_GROUPS = ("time", "sight", "spawn safety")
BAND_CLOSE = 0.75
def band_misses(rows):
    out = []
    for key, row in sorted((rows or {}).items()):
        far = row.get("status") == "fail" or (
            row.get("status") == "warn" and (row.get("closeness") or 0) < BAND_CLOSE)
        if not far or (row.get("weight") or 0) < 2:
            continue
        if row.get("group") not in BAND_GROUPS:
            continue
        out.append("band: %s is %s, the family's target is %s"
                   % (row.get("label", key), row.get("value"), row.get("band")))
    return out
def after_measured(brief, res, arena):
    from . import metrics
    rows, _ = metrics.quality(res)
    return measure_fit(brief, res, arena, names=FULL_ASKS), band_misses(rows)
def after_choice(brief, arena, fit_cheap, measured=None, course_s=None):
    if measured is None:
        try:
            from . import metrics
            res = metrics.measure(arena, family=brief["family"], tier="full",
                                  players=brief["players"], size=brief.get("size"),
                                  course_s=course_s)
            measured = after_measured(brief, res, arena)
        except Exception:
            return fit_cheap, misses(fit_cheap)
    full, bands = measured
    fit = [f for f in (fit_cheap or []) if f["name"] not in FULL_ASKS]
    fit += list(full)
    return fit, misses(fit) + list(bands)
