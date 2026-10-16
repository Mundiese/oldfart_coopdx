import json
import os
from ..metrics.measure import measure as measure_fn
from ..metrics import fun as funmod
from ..metrics import qd
from ..metrics import targets as T
from ..metrics import v1
MARK = {"pass": "✔", "warn": "~", "fail": "✘", "n/a": "-"}
DONE_MARK = {"placed": "✔", "approximated": "~", "refused": "✘", "ok": "✔"}
MODES = {
    "shooter": ["Deathmatch", "One in the Chamber", "Rocket Arena", "Juggernaut", "Kill Confirmed",
                "Wanted!", "Assassins", "Last One Standing", "Crown", "Coin Rush", "Green Demon",
                "The Bank", "Murder Mystery"],
    "objective": ["Capture the Flag", "One Flag", "Domination", "King of the Hill", "Harvester",
                  "Overload", "Turf", "Football", "Volleyball", "Cops and Robbers"],
    "knockoff": ["Sumo", "Knock Out", "Ram Ring", "Chomp Chase", "Log Roll", "Mega Rampage",
                 "Hot Potato", "Deflect", "Last One Standing"],
    "race": ["Shell Racer", "Shell Battle", "Downhill", "Red Light Green Light", "Flood"],
    "hide": ["Hide and Seek", "Sardines", "Prop Hunt", "Manhunt", "Zombies", "Rabbit Chase",
             "Hide the Balloon", "Cops and Robbers"],
    "party": ["Shell Shower", "Octagon Heat", "Musical Spots", "Last Tile", "Glass Bridge", "Frenzy"],
    "course": ["Spiral to the Star", "Silver Five", "Glass Bridge", "free play"],
}
ONLY_THE_GAME = [
    "textures and light on scaled pieces",
    "frame cost with sixteen players",
    "jumps at real speed (the walk graph assumes a clean single jump of 200)",
    "the camera in tight spaces and against tall walls behind spawns",
]
_REF_CACHE = {}
def reference_result(family, tier):
    key = T.REFERENCE.get(T.family_of(family))
    if not key:
        return None, None
    ck = (key, tier)
    if ck not in _REF_CACHE:
        arena = v1.venue(key)
        sim = tier.endswith("+sim")
        _REF_CACHE[ck] = measure_fn(arena, family=family, tier=tier.split("+")[0], sim=sim)
    return key, _REF_CACHE[ck]
def about(arena, result):
    m = result["metrics"]
    fam = result["family"]
    d = qd.descriptors(result)
    sym = qd.symmetry_of(arena)
    words = []
    v = d.get("verticality") or 0
    words.append("flat" if v < 0.2 else "vertical" if v > 0.5 else "layered")
    o = d.get("openness")
    if o is not None and m.get("openness") is not None:
        words.append("open" if o > 0.4 else "closed-in" if o < 0.2 else "half-open")
    sym_text = {"turn4": "four-fold turned", "turn2": "two-fold turned", "mirror_z": "mirrored end to end",
                "mirror_x": "mirrored side to side", "none": "asymmetric"}[sym]
    parts = ["A %s, %s %s map (%s)." % (", ".join(words), sym_text, fam, arena.get("key", "?"))]
    plats = m.get("plateaus") or []
    if plats:
        parts.append("%d height layer%s (%s)." % (len(plats), "" if len(plats) == 1 else "s",
                                                  " / ".join(str(p) for p in plats)))
    cd = d.get("centre_dominance") or 0
    if cd > 0.6:
        parts.append("It is about its raised centre: the highest floor sits in the middle.")
    elif cd < -0.3:
        parts.append("It is about a sunken centre.")
    if m.get("bases"):
        if m["bases"] >= 2 and m.get("exits_per_base"):
            parts.append("%d bases, each with %s way%s out." % (m["bases"], m["exits_per_base"],
                                                              "" if m["exits_per_base"] == 1 else "s"))
    if m.get("cycle_cover") is not None:
        parts.append("%d%% of the floor lies on a loop, %d dead end%s." % (
            round(100 * m["cycle_cover"]), m.get("dead_ends") or 0, "" if m.get("dead_ends") == 1 else "s"))
    if m.get("open_pairs_over_2400") is not None:
        parts.append("Open lines past 2400: %d%% of floor pairs; the longest %d." % (
            round(100 * m["open_pairs_over_2400"]), m.get("sightline_max") or 0))
    if m.get("lap_s"):
        parts.append("A lap of %d units: %.1f s on a shell, %d gates." % (m["lap_length"], m["lap_s"],
                                                                         m.get("gates_per_lap") or 0))
    if m.get("ring_radius"):
        parts.append("The ring is %d across from the middle." % m["ring_radius"])
    gen = arena.get("report") or {}
    if gen.get("skeleton"):
        parts.append("Skeleton: %s." % gen["skeleton"])
    if gen.get("about"):
        parts.append("Style: %s." % gen["about"])
    if gen.get("beauty_score") is not None:
        parts.append("Beauty %.2f." % gen["beauty_score"])
    return " ".join(parts)
def new_pictures_kb(arena):
    ma = v1.tool()
    actors = os.path.join(v1.ROOT, "actors")
    seen = set()
    new = 0
    for p in arena["pieces"]:
        name = (p.get("model") or ma.model_name(p)) + ".bin"
        if name in seen:
            continue
        seen.add(name)
        if not os.path.exists(os.path.join(actors, name)):
            new += 1
    return new * 3, len(seen)
def build_card(arena, result=None, brief=None, wish=None, defaulted=None, done=None,
               not_understood=None, not_possible=None, candidates=None, pictures=None,
               tier="full", sim=True, reference=True, looks=None):
    if result is None:
        result = measure_fn(arena, tier=tier, sim=sim)
    fam = result["family"]
    rows, quality = T.score(result["metrics"], fam)
    ref_key = ref_rows = None
    if reference:
        ref_key, ref = reference_result(fam, result["tier"])
        if ref is not None:
            ref_rows, _ = T.score(ref["metrics"], fam)
    groups = {}
    for name, row in rows.items():
        entry = dict(row)
        entry["metric"] = name
        if ref_rows is not None and ref_key != arena.get("key"):
            entry["reference"] = ref_rows[name]["value"]
        groups.setdefault(row["group"], []).append(entry)
    ordered = []
    for g in T.GROUPS:
        if g in groups:
            ordered.append({"group": g, "rows": groups[g]})
    looks_card = None
    if looks:
        from ..metrics import looks as looksmod
        if looks is True:
            looks = looksmod.audit(arena, fam)
        looks_rows = []
        for k in looksmod.CHECKS:
            row = looks["checks"][k]
            looks_rows.append({"metric": k, "label": "%s %s" % (k, looksmod.NAMES[k]),
                               "value": _plain(row["value"]), "band": row["target"],
                               "status": row["status"], "group": "looks", "note": row["why"],
                               "fix": looksmod.FIXES[k]})
        ordered.append({"group": "looks", "rows": looks_rows})
        looks_card = {"summary": looks["summary"], "landmark": looks.get("landmark"),
                      "shares": looks.get("shares")}
    counts = {"pass": 0, "warn": 0, "fail": 0, "n/a": 0}
    for row in rows.values():
        counts[row["status"]] += 1
    missed = [{"metric": n, "label": r["label"], "value": r["value"], "band": r["band"],
               "lo": r["lo"], "hi": r["hi"]}
              for n, r in rows.items() if r["status"] == "fail"]
    kb, sizes = new_pictures_kb(arena)
    survey = arena.get("survey", {}) or {}
    keys = sorted(k for k, v in survey.items() if v)
    if arena.get("markers"):
        keys.append("track markers")
    if brief and defaulted is None:
        defaulted = brief.get("defaulted") or brief.get("_defaulted")
    card = {
        "card": 1,
        "key": arena.get("key", "?"),
        "family": fam,
        "tier": result["tier"],
        "wish": wish,
        "brief": brief,
        "defaulted": defaulted or [],
        "about": about(arena, result),
        "done": done or [],
        "not_understood": not_understood or [],
        "not_possible": not_possible or [],
        "missed_targets": missed,
        "quality": None if quality is None else round(quality, 3),
        "counts": counts,
        "reference": ref_key if ref_key != arena.get("key") else None,
        "metrics": ordered,
        "beauty_rules": result["extra"].get("beauty_rules", {}),
        "bots": result["extra"].get("sim", {}).get("metrics") if result["extra"].get("sim") else None,
        "candidates": candidates or [],
        "cost": {"pieces": len(arena["pieces"]), "objects": result["metrics"].get("objects"),
                 "budget": arena.get("budget"), "distinct_pictures": sizes,
                 "new_pictures_kb": kb, "objects_requested": len(arena.get("objects", []) or [])},
        "modes": MODES.get(fam, []),
        "survey_keys": keys,
        "only_the_game": ONLY_THE_GAME,
        "notes": result.get("notes", []),
        "timings": result.get("timings", {}),
        "descriptors": qd.descriptors(result),
        "symmetry": qd.symmetry_of(arena),
        "pictures": pictures or {},
        "all_metrics": _plain(result["metrics"]),
        "fun_where": funmod.where(result["extra"], result.get("world")),
        "looks": looks_card,
    }
    try:
        from .. import shapeuse
        su = shapeuse.measure(arena)
        su["judged"] = shapeuse.judge(fam, su)
        card["shapes"] = su
    except Exception:
        card["shapes"] = None
    try:
        from .. import refstats
        card["sm64_reference"] = refstats.compare(arena)
    except Exception:
        card["sm64_reference"] = None
    g = (arena.get("report") or {}).get("guards")
    card["guards"] = g.get("counts") if isinstance(g, dict) else None
    return card
def _plain(v):
    if isinstance(v, dict):
        return {str(k): _plain(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [_plain(x) for x in v]
    if isinstance(v, float):
        return round(v, 4)
    return v
def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, bool):
        return "yes" if v else "no"
    if isinstance(v, (list, tuple)):
        return " - ".join(fmt(x) for x in v)
    if isinstance(v, float):
        if abs(v) < 1:
            return "%.0f%%" % (100 * v) if v != 0 else "0"
        return "%.1f" % v
    if isinstance(v, int) and abs(v) >= 100000:
        return "%.2f M" % (v / 1e6)
    return str(v)
SHARES = set(["open_pairs_over_2400", "cover_within_300", "spawn_exposure_mean", "spawn_exposure_max",
              "field_spawn_exposure_max", "spawn_front_cover", "spawn_back_clear", "high_ground_share",
              "landmark_visible_from_spawns", "spawn_equity", "cycle_cover", "pieces_share", "beauty",
              "ring_cover", "hiding_share", "sim_kill_entropy", "sim_spawn_kill_share", "sim_unused_floor",
              "sim_kill_hotspot_share", "sim_kill_spread", "side_time_gap"])
def fmt_bound(name, v):
    if name in SHARES:
        return "%g%%" % round(100 * v, 1)
    if isinstance(v, (int, float)) and abs(v) >= 100000:
        return "%g M" % (v / 1e6)
    return "%g" % v
def band_of(name, row):
    lo, hi = row.get("lo"), row.get("hi")
    if lo is None and hi is None:
        return row.get("band", "-")
    if lo is not None and hi is not None:
        if lo == hi:
            return "= " + fmt_bound(name, lo)
        return "%s-%s" % (fmt_bound(name, lo), fmt_bound(name, hi))
    if lo is not None:
        return ">= " + fmt_bound(name, lo)
    return "<= " + fmt_bound(name, hi)
def fmt_metric(name, v):
    if v is None:
        return "-"
    if name in SHARES and isinstance(v, (int, float)) and not isinstance(v, bool):
        return "%g%%" % round(100 * v, 1)
    if name in ("layers", "tiers", "dead_ends", "chokes", "lanes_between_bases", "exits_per_base",
                "hill_approaches", "vantage_points", "gates_per_lap", "jump_class_needed",
                "climb_routes_per_high_point", "spawn_kill_risk", "markers_ok", "ways_up_per_tier"):
        return str(v)
    if name.endswith("_s") or name in ("side_time_gap",):
        if isinstance(v, (list, tuple)):
            return " - ".join(fmt_metric(name, x) for x in v)
        return "%.2f" % v if name == "side_time_gap" else "%.1f" % v
    return fmt(v)
def band_text(name, band):
    if not band or band == "-":
        return "-"
    return band
def to_markdown(card):
    L = []
    L.append("# Report card - %s" % card["key"])
    L.append("")
    L.append("Family **%s**, measured at tier `%s`. Quality **%s** (weighted closeness to the "
             "target bands: %d pass, %d warn, %d fail)." % (
                 card["family"], card["tier"],
                 "-" if card["quality"] is None else "%.2f" % card["quality"],
                 card["counts"]["pass"], card["counts"]["warn"], card["counts"]["fail"]))
    L.append("")
    pics = card.get("pictures") or {}
    if pics.get("plan"):
        L.append("![plan](%s)" % pics["plan"])
        L.append("")
    L.append("## What the map is about")
    L.append("")
    L.append(card["about"])
    L.append("")
    L.append("## 1. The wish and the brief")
    L.append("")
    L.append("Wish: %s" % (("\"%s\"" % card["wish"]) if card["wish"] else "- (a v1 venue or a layout file, no wish)"))
    if card["brief"]:
        L.append("")
        L.append("| field | value |")
        L.append("|---|---|")
        for k, v in card["brief"].items():
            if k in ("defaulted", "_defaulted"):
                continue
            mark = " - default" if k in card["defaulted"] else ""
            L.append("| %s | %s%s |" % (k, json.dumps(v, ensure_ascii=False), mark))
    L.append("")
    L.append("## 2. What was done")
    L.append("")
    if card["done"]:
        for d in card["done"]:
            L.append("- %s %s%s" % (DONE_MARK.get(d.get("status"), "-"), d.get("what"),
                                    (" - " + d["note"]) if d.get("note") else ""))
    else:
        L.append("- nothing was asked beyond the family's defaults")
    L.append("")
    L.append("## 3. Not understood / not possible")
    L.append("")
    if card["not_understood"]:
        L.append("Not understood: " + "; ".join(card["not_understood"]))
    if card["not_possible"]:
        L.append("Not possible: " + "; ".join(card["not_possible"]))
    if card["missed_targets"]:
        L.append("Targets missed (fail): " + "; ".join(
            "%s %s (target %s)" % (m["label"], fmt_metric(m["metric"], m["value"]), band_of(m["metric"], m))
            for m in card["missed_targets"]))
    if not (card["not_understood"] or card["not_possible"] or card["missed_targets"]):
        L.append("- nothing")
    L.append("")
    L.append("## 4. Metrics against targets")
    L.append("")
    ref = card.get("reference")
    head = "| | metric | value | target |" + (" %s |" % ref if ref else "") + " tier |"
    L.append(head)
    L.append("|---|---|---|---|" + ("---|" if ref else "") + "---|")
    for grp in card["metrics"]:
        if grp["group"] == "looks":
            continue
        L.append("| | **%s** | | |" % grp["group"] + (" |" if ref else "") + " |")
        for r in grp["rows"]:
            cells = [MARK[r["status"]], r["label"], fmt_metric(r["metric"], r["value"]), band_of(r["metric"], r)]
            if ref:
                cells.append(fmt_metric(r["metric"], r.get("reference")))
            cells.append(r["tier"])
            L.append("| " + " | ".join(cells) + " |")
    L.append("")
    fun_rows = [r for g in card["metrics"] if g["group"] == "fun" for r in g["rows"]]
    if fun_rows:
        L.append("Fun rules (a warn-only rule never fails a map):")
        L.append("")
        for r in fun_rows:
            L.append("- %s %s: %s%s" % (MARK[r["status"]], r["label"], r.get("note") or "",
                                        " (warn only)" if r.get("warn_only") else ""))
        L.append("")
    if card["beauty_rules"]:
        L.append("Beauty rules (share satisfied): " + ", ".join(
            "%s %s" % (k, "-" if v is None else "%.0f%%" % (100 * v)) for k, v in card["beauty_rules"].items()))
        L.append("")
    if card["bots"]:
        b = card["bots"]
        L.append("Bots (%s, %d runs): kill balance %.2f, kills/min %.0f, mean life %.1f s, spawn kills %.0f%%, "
                 "unused floor %.0f%%, median engagement %s." % (
                     b["mode"], b["runs"], b["kill_entropy"] or 0, b["kills_per_min"] or 0,
                     b["mean_life_s"] or 0, 100 * (b["spawn_kill_share"] or 0), 100 * (b["unused_floor"] or 0),
                     "-" if b["engagement_distance"] is None else "%d" % b["engagement_distance"]))
        if b.get("rh_fight_share") is not None:
            L.append("Rhythm (aware bots): in a fight %.0f%% of the time, calm gaps "
                     "%s s median / %s s p90, longest stretch with no enemy seen %s s." % (
                         100 * b["rh_fight_share"], b.get("rh_calm_p50_s"), b.get("rh_calm_p90_s"),
                         b.get("rh_unseen_p90_s")))
        L.append("")
    L.append("## 5. Why this one")
    L.append("")
    if card["candidates"]:
        for c in card["candidates"]:
            L.append("- %s: quality %.2f%s" % (c.get("name"), c.get("quality") or 0,
                                               (" - " + c["differs"]) if c.get("differs") else ""))
    else:
        L.append("- a single layout was measured (no candidates to compare)")
    L.append("")
    L.append("## 6. Cost")
    L.append("")
    c = card["cost"]
    L.append("- objects %s of a budget of %s (pieces %s)" % (c["objects"], c["budget"], c["pieces"]))
    L.append("- %d distinct pictures, ~%d KB new for each joiner" % (c["distinct_pictures"], c["new_pictures_kb"]))
    L.append("- Forge objects requested: %d" % c["objects_requested"])
    L.append("")
    su = card.get("shapes")
    if su:
        j = su.get("judged") or {}
        band = j.get("band") or {}
        L.append("## Shapes used (reported, never forced)")
        L.append("")
        L.append("- kinds used (two pieces or more): **%d** %s - %s" % (
            su["kinds_used"], band.get("kinds_used", ""), j.get("kinds_used", "-")))
        L.append("- fit coverage: **%s** of %d sites (want >= %s) - %s" % (
            "-" if su["fit_coverage"] is None else "%.2f" % su["fit_coverage"], su["sites"],
            band.get("fit_coverage", "-"), j.get("fit_coverage", "-")))
        L.append("- non-box share: %.2f (reported only; expected %s)" % (
            su["non_box_share"], band.get("non_box_share (reported)", "-")))
        L.append("- forced showcase pieces: %d (must be 0)" % su["forced"])
        L.append("")
    ref = card.get("sm64_reference")
    if ref:
        L.append("SM64's proportions (the vanilla courses' spread, never one map): " + "; ".join(
            "%s %s (%s)" % (k.replace("_", " "), v["map"], v["where"]) for k, v in ref.items()
            if v.get("map") is not None))
        L.append("")
    if card.get("guards"):
        L.append("Rules (guards): " + ", ".join(
            "%s %d" % (k, v) for k, v in sorted(card["guards"].items())))
        L.append("")
    L.append("## 7. Modes it suits")
    L.append("")
    L.append("Proposed `onlyFor`: " + ", ".join(card["modes"]))
    L.append("")
    L.append("Survey keys it carries: " + (", ".join(card["survey_keys"]) or "none"))
    L.append("")
    L.append("## 8. What only the game confirms")
    L.append("")
    for s in card["only_the_game"]:
        L.append("- " + s)
    L.append("")
    if card["notes"]:
        L.append("Notes: " + "; ".join(card["notes"]))
        L.append("")
    if card.get("looks"):
        L.append("## Looks (the render audit A1-A10, in the game's light)")
        L.append("")
        L.append("%s. Guards against ugly, calibrated on the Sky Keep." % card["looks"]["summary"])
        L.append("")
        L.append("| check | value | target | status | why |")
        L.append("|---|---|---|---|---|")
        for g in card["metrics"]:
            if g["group"] != "looks":
                continue
            for r in g["rows"]:
                L.append("| %s | %s | %s | %s | %s |" % (r["label"], fmt(r["value"]), r["band"],
                                                       r["status"], r["note"]))
        L.append("")
        if pics.get("looks"):
            L.append("![looks](%s)" % pics["looks"])
            L.append("")
    if pics:
        L.append("## Pictures")
        L.append("")
        for name in ("sides", "iso", "sight", "heat", "deaths"):
            if pics.get(name):
                L.append("![%s](%s)" % (name, pics[name]))
                L.append("")
    t = card.get("timings", {})
    if t:
        L.append("Measured in %.2f s (cheap tier %.2f s)." % (t.get("total", 0), t.get("cheap_total", 0)))
    return "\n".join(L) + "\n"
def write_card(card, outdir, name=None):
    os.makedirs(outdir, exist_ok=True)
    name = name or card["key"]
    jp = os.path.join(outdir, name + ".card.json")
    mp = os.path.join(outdir, name + ".card.md")
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(card, f, indent=1, sort_keys=False, ensure_ascii=False)
        f.write("\n")
    with open(mp, "w", encoding="utf-8") as f:
        f.write(to_markdown(card))
    return jp, mp
def report(arena, outdir, pictures=True, **kw):
    result = measure_fn(arena, tier="full", sim=True)
    pics = {}
    looks = None
    if pictures:
        from ..render import render_all
        paths = render_all(arena, outdir, result=result)
        pics = {k: os.path.basename(v) for k, v in paths.items()}
        from ..metrics import looks as looksmod
        looks = looksmod.audit(arena, result["family"])
        sheet = looksmod.contact_sheet(looks, os.path.join(outdir, "looks.png"))
        if sheet:
            pics["looks"] = os.path.basename(sheet)
    card = build_card(arena, result=result, pictures=pics, looks=looks, **kw)
    jp, mp = write_card(card, outdir)
    return card, jp, mp
