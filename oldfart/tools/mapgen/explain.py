from .brief import FAMILY_MODES, FIELDS
WHY = {
    "family": "the map's kind; it picks the defaults below",
    "players": "sets the footprint (8000 across at 16, like the Sky Keep)",
    "size": "a factor on the footprint (tiny 0.6 .. huge 1.5) or an exact across / walk time",
    "symmetry": "turn4 = four bases a quarter turn apart (fair for free-for-all); mirror = two",
    "verticality": "flat 1 plane, low 2, medium 3 (Sky Keep: 0/400/600), high 3 + towers",
    "density": "how much cover the fill step scatters on the island",
    "edge": "rails over the void (default), walls, or a bare edge",
    "level": "empty2 = The Void (a death edge), empty = The Tiles (a floor everywhere)",
    "theme": "the texture palette (castle is the Sky Keep's own)",
    "seed": "the map's identity: same brief + seed = the same map, byte for byte",
    "budget": "objects the venue may use (the size tier's default; at most the "
              "family's measured ceiling, tools/mapgen/budget.py)",
    "candidates": "how many seeded candidates are built; the best by score is kept",
}
def brief_text(brief):
    d = brief.to_dict()
    lines = ["Brief (version %d)" % d["brief"]]
    for k in FIELDS[1:]:
        v = d.get(k)
        if v in (None, [], {}) and k in brief.defaulted:
            continue
        mark = "  (default)" if k in brief.defaulted else ""
        why = WHY.get(k)
        lines.append("  %-12s %s%s%s" % (k, _short(v), mark, ("   - " + why) if why else ""))
    return "\n".join(lines)
def _short(v):
    import json
    s = json.dumps(v, ensure_ascii=False)
    return s if len(s) <= 70 else s[:67] + "..."
def report(result, wish=None, understood=None, not_understood=None, language=None):
    b = result.brief
    best = result.best
    meta = best.meta
    out = ["# Map report - %s" % (b["name"] or b["key"] or "generated map"), ""]
    if wish:
        out += ["**Wish:** %s" % wish, ""]
    if understood:
        out += ["**Understood:** " + "; ".join(understood), ""]
    if not_understood:
        out += ["**Not understood:** " + "; ".join(not_understood), ""]
    out += ["## The brief", "", "```", brief_text(b), "```", ""]
    out += ["## What was done", ""]
    mark = {"placed": "OK", "approximated": "~", "refused": "NO", "not yet": "LATER",
            "unverified": "?"}
    lang = language or [(d.get("status"), d.get("id"), d.get("note"))
                        for d in best.arena.get("report", {}).get("done", [])]
    for how, aid, note in lang:
        out.append("- [%s] %s: %s" % (mark.get(how, how), aid, note))
    for why in best.arena.get("report", {}).get("refine", []):
        out.append("- refine: %s" % why)
    if best.arena.get("objects"):
        out.append("- Forge objects: %d in the venue table (%s); free play only unless a "
                   "mode is named" % (len(best.arena["objects"]), ", ".join(sorted(set(
                       o["key"] for o in best.arena["objects"])))))
    for how, aid, note in [] if lang else meta.get("anchors", []):
        mark = {"placed": "OK", "approximated": "~", "refused": "NO", "not yet": "LATER"}.get(how,
                                                                                         how)
        out.append("- [%s] %s: %s" % (mark, aid, note))
    if not meta.get("anchors") and not lang:
        out.append("- no anchors asked for")
    try:
        p = meta["params"]
        out.append("- skeleton: %d symmetry units (%s), zones %s; loops: %s"
                   % (meta["units"], meta["symmetry"], ", ".join(meta["graph"]["zones"]),
                      "; ".join(label for label, _ in meta["graph"]["loops"])))
        out.append("- modules: centre %s, lanes %s, corners %s, shield %s, %d cover pieces"
                   % (p["centre"], p["lane"], p["corner"], p["shield"], meta["cover"]))
        out.append("- size: island %d half, gap %d, bastion %d deep - %d across; decks %d, perches %d"
                   % (p["I"], p["G"], p["B"], 2 * (p["I"] + p["G"] + p["B"]), p["Dh"], p["Ph"]))
    except (KeyError, TypeError):
        out.append("- modules: %s" % _short(meta.get("modules")))
    for n in meta.get("notes", []):
        out.append("- note: %s" % n)
    stars = best.arena.get("stars") or []
    if stars:
        out += ["", "## Bonus stars", ""]
        for st in stars:
            out.append("%d. \"%s\" - %s, grade %d%s" % (
                st["id"], st.get("name") or "(no name)", st["kind"], st["grade"],
                " (as the wish asked)" if st.get("asked") else ""))
        out.append("")
    for d in best.arena.get("report", {}).get("gameplay", []) or []:
        if str(d.get("id", "")).startswith("star ") and d.get("status") == "refused":
            out.append("- [NO] %s: %s" % (d["id"], d.get("note")))
    for r in best.repairs:
        out.append("- repair: %s" % r)
    out += ["", "## Hard checks (v1's)", "",
            "- %s" % ("all passed" if best.ok else "; ".join(best.checks.faults))]
    esc = (best.arena.get("report") or {}).get("escapes") or []
    out += ["", "## Escapes", ""] + (["- %s" % e for e in esc] or
                                     ["- none: nobody gets over the map edge, no maze wall top "
                                      "is reached without a wall kick"])
    if best.score:
        out += ["", "## Metrics (%s)" % best.score["source"], ""]
        if best.score.get("note"):
            out.append("_%s_" % best.score["note"])
            out.append("")
        out.append("| metric | value | band | score |")
        out.append("|---|---|---|---|")
        rows = best.score.get("rows", [])
        if isinstance(rows, dict):
            rows = [dict(r, metric=n) for n, r in rows.items() if r.get("value") is not None]
        for row in rows:
            if isinstance(row, dict):
                out.append("| %s | %s | %s | %s |" % (
                    row.get("label") or row.get("metric"), _short(row.get("value")),
                    row.get("band"), row.get("status", row.get("score"))))
        out.append("")
        out.append("Quality %.3f" % best.quality)
    out += ["", "## Why this one", ""]
    for c in sorted(result.candidates, key=lambda c: (-(c.quality or -1), c.index)):
        s = c.summary()
        out.append("- candidate %d: %s, quality %s, %d pieces, centre %s, lanes %s%s"
                   % (s["candidate"], "ok" if s["ok"] else "FAILED", s["quality"], s["pieces"],
                      s.get("centre"), s.get("lane"), "" if s["ok"] else " - " + "; ".join(s["faults"])))
    out += ["", "## Cost", "",
            "- %d pieces + markers against a budget of %d" % (len(best.arena["pieces"]),
                                                           best.arena["budget"]),
            "- %d survey points (16 bases + %d field spawns; the wire carries 28)"
            % (len((best.arena.get("survey") or {}).get("points", [])), meta.get("field_spots", 0)),
            "", "## Modes it suits", "",
            "- onlyFor: %s" % ", ".join(best.arena.get("onlyFor")
                                        or FAMILY_MODES.get(b["family"], [])),
            "", "## What only the game confirms", "",
            "- textures and light on scaled pieces; frame cost with sixteen players;",
            "  jumps and ramps at real speed; the camera in tight spaces.", ""]
    return "\n".join(out)
