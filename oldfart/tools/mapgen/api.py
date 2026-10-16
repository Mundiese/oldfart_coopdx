import copy
import re
from . import anchors as anchormod
from . import checks, place
from . import generate as gen
from .brief import Brief, BriefError
_PATH = re.compile(r"^([a-z_]+)(?:\[(\d+)\])?(?:\.([a-z_]+))?")
Refused = anchormod.Refused
def lenient(raw):
    raw = copy.deepcopy(raw)
    dropped = []
    for _ in range(20):
        try:
            return Brief.from_dict(raw), dropped
        except BriefError as why:
            progress = False
            for problem in why.problems:
                m = _PATH.match(problem)
                if not m:
                    continue
                field, index, sub = m.group(1), m.group(2), m.group(3)
                if index is not None and isinstance(raw.get(field), list):
                    i = int(index)
                    if i < len(raw[field]) and raw[field][i] is not None:
                        raw[field][i] = None
                        dropped.append(problem)
                        progress = True
                elif field == "features" and sub in ("want", "avoid"):
                    bad = re.search(r"'([^']+)' is not one of", problem)
                    f = raw.get("features") or {}
                    if bad and bad.group(1) in (f.get(sub) or []):
                        f[sub] = [x for x in f[sub] if x != bad.group(1)]
                        dropped.append(problem)
                        progress = True
                elif field == "modes" and isinstance(raw.get("modes"), list):
                    bad = re.search(r"'([^']+)' is not a mode", problem)
                    if bad:
                        raw["modes"] = [x for x in raw["modes"] if str(x).lower() != bad.group(1)]
                        dropped.append(problem)
                        progress = True
                elif field in raw:
                    raw.pop(field)
                    dropped.append(problem)
                    progress = True
            for key in ("anchors", "objects"):
                if isinstance(raw.get(key), list):
                    raw[key] = [x for x in raw[key] if x is not None]
            if not progress:
                raise
    return Brief.from_dict(raw), dropped
def raw_of(brief):
    if isinstance(brief, Brief):
        d = brief.to_dict()
        for k in brief.defaulted:
            d.pop(k, None)
        d.pop("defaulted", None)
        return d
    d = copy.deepcopy(dict(brief))
    for k in d.pop("defaulted", []) or []:
        d.pop(k, None)
    return d
class Run:
    def __init__(self, brief, solution, result, dropped, lines):
        self.brief = brief
        self.solution = solution
        self.result = result
        self.dropped = dropped
        self.lines = lines
    @property
    def arena(self):
        return self.result.best.arena
    def layout(self):
        return self.result.layout()
def family_brief(raw, solution):
    fam = copy.deepcopy(raw)
    post = set(solution.problem.post) if solution else set()
    if solution is not None:
        fam["anchors"] = [a for a in solution.brief_edits() if a.get("id") not in post]
    return fam
def history_path(user, history=None):
    import os
    from . import history as histmod
    if history is False:
        return None
    if isinstance(history, str):
        return history
    if history is True or os.environ.get("MAPGEN_HISTORY") or user["novelty"]:
        return histmod.path()
    return None
def run(brief, seed=None, candidates=None, use_metrics=True, progress=None, history=None):
    r = _run(brief, seed, candidates, use_metrics, progress, history)
    from . import levelfit
    if not levelfit.over_line(getattr(r, "fitted", None)):
        got = getattr(r, "fitted", None)
        if got and got[1] is not None and got[1] > levelfit.red_line():
            r.arena.setdefault("report", {}).setdefault("notes", []).append(
                levelfit.within_tolerance_said(got[1]))
        return r
    was = r.fitted[1]
    tried = []
    last = was
    steps = list(levelfit.LINE_STEPS)
    jumped = False
    while steps:
        scale = steps.pop(0)
        try:
            gen.phase("the level is over its size line (%.0f KB): building again with "
                      "%d%% of the structure" % (last, int(round(scale * 100))))
            with levelfit.structure_scaled(scale):
                again = _run(brief, seed, candidates, use_metrics, progress, history,
                             record=False)
        except RuntimeError as why:
            tried.append("%d%%: %s" % (int(round(scale * 100)), str(why)[:60]))
            continue
        got = getattr(again, "fitted", None)
        tried.append("%d%%: %.0f KB" % (int(round(scale * 100)), got[1] if got and got[1] else 0))
        now = got[1] if got and got[1] else None
        if not levelfit.over_line(got):
            again.arena.setdefault("report", {}).setdefault("notes", []).append(
                "level line: built again with %d%% of the structure line (the fit left %.0f KB)"
                % (int(round(scale * 100)), was))
            return again
        if now is None or now > last - levelfit.STEP_MOVES_KB:
            if jumped or not steps:
                tried.append("stopped: no step moved the size %d KB" % levelfit.STEP_MOVES_KB)
                break
            jumped = True
            steps = steps[-1:]
            continue
        last = now
    rep = r.arena.setdefault("report", {})
    rep.setdefault("notes", []).append(
        "level line: not held - the fit left %.0f KB and fewer things built did not bring it "
        "under %d (%s); the world as first built" % (was, levelfit.red_line(), ", ".join(tried)))
    rep.setdefault("not_possible", []).append(levelfit.over_line_said(was))
    return r
def _run(brief, seed=None, candidates=None, use_metrics=True, progress=None, history=None,
         record=True):
    raw = raw_of(brief)
    if seed is not None:
        raw["seed"] = seed
    user, dropped = lenient(raw)
    if "seed" not in raw:
        raw["seed"] = user["seed"]
    hpath = history_path(user, history)
    plan = None
    base_raw, base_user, failed = raw, user, []
    for salt in range(4):
        if hpath:
            from . import novelty
            raw, plan = novelty.plan(base_raw, base_user, hpath, salt)
            user, more = lenient(raw)
            dropped += [d for d in more if d not in dropped]
        sol = anchormod.solve(raw)
        fam_raw = family_brief(raw, sol)
        fam, more = lenient(fam_raw)
        dropped += [d for d in more if d not in dropped]
        n = candidates or fam["candidates"]
        forces = plan.forces_for(n) if plan is not None else None
        try:
            result = gen.generate(fam, candidates, use_metrics=use_metrics, progress=progress,
                                  forces=forces)
            break
        except RuntimeError as why:
            if plan is None or not plan.rolled or salt == 3:
                raise
            failed.append("%s (%s)" % (", ".join("%s %s" % kv for kv in sorted(
                plan.rolled.items()) if kv[0] in ("theme", "size", "preset")), str(why)[:80]))
    if failed and plan is not None:
        plan.notes.append("rolled again: %d roll(s) the gate refused - %s" % (
            len(failed), "; ".join(failed)))
    if plan is not None:
        from . import novelty
        got = novelty.choose(result, fam, plan, use_metrics)
        rounds = 0
        while got is None and rounds < 3:
            rounds += 1
            more = gen.generate(fam, n, use_metrics=use_metrics, progress=progress,
                                start=n * rounds)
            result.candidates += more.candidates
            got = novelty.choose(result, fam, plan, use_metrics)
        if got is None:
            plan.notes.append("formation: every candidate wore a rejected formation; the best "
                              "one is kept")
    lines = postprocess(result.best.arena, user, sol)
    from . import materials, teamzones
    materials.apply(result.best.arena, user)
    teamzones.apply(result.best.arena, user)
    rep = result.best.arena.setdefault("report", {})
    unbuilt_wants(result.best.arena, user, asked=base_raw)
    if user["requests"]:
        answered = set((result.best.arena.get("gameplay") or {}).get("answered") or [])
        answered.add("lanes")
        placed = set((result.best.arena.get("gameplay") or {}).get("placed") or [])
        rep["not_possible"] = list(rep.get("not_possible", [])) + [
            "requested, not built on this map: %s%s" % (q["kind"], " x%d" % q["count"]
                                                         if q.get("count") else "")
            if q["kind"] != "place" else
            "requested, not placed yet: %s%s %s the %s" % (
                "hidden " if q.get("hidden") else "", q.get("what"),
                str(q.get("relation")).replace("_", " "), q.get("of"))
            for i, q in enumerate(user["requests"]) if q["kind"] not in answered
            and not (q["kind"] == "place" and i in placed)]
    if user["forge_off"]:
        rep.setdefault("notes", []).append("Forge objects off: %s" % ", ".join(user["forge_off"]))
    if plan is not None:
        from . import history as histmod
        summ = result.best.summary()
        desc = None
        try:
            from . import variety as qd
            desc = qd.descriptors(result.best.score) if result.best.score else None
            desc = dict(desc or {}, **qd.arena_descriptors(result.best.arena))
        except Exception:
            desc = None
        summ["about"] = (summ.get("about") or "").split(";")[0]
        entry = histmod.entry_of(result.best.arena, user, summ, desc)
        d, near = histmod.novelty(entry, hpath)
        plan.notes.append("history: %.2f from the nearest of the recent %s maps%s" % (
            d, user["family"], (" (%s, %s)" % (near["formation"], near["theme"])) if near else ""))
        if record:
            histmod.record(result.best.arena, user, summ, desc, hpath)
        rep["notes"] = list(rep.get("notes", [])) + plan.notes
        rep["novelty"] = {"mode": plan.mode, "rolled": plan.rolled, "banned": plan.banned,
                          "distance": d}
    if user["modes"]:
        result.best.arena["onlyFor"] = list(user["modes"])
    from . import levelfit
    gen.phase("fitting the level under its size line")
    fitted = levelfit.fit(result.best.arena, user["family"])
    levelfit.fit_cells(result.best.arena, user["family"])
    result.brief = user
    out = Run(user, sol, result, dropped, lines)
    out.fitted = fitted
    return out
def postprocess(arena, brief, sol):
    report = arena.setdefault("report", {})
    lines = []
    for aid in sol.problem.post:
        a = sol.problem.anchors[aid]
        where = a.get("where") or {}
        if "on" in where and "relation" not in where:
            where = {"on": where["on"]}
        status, note = place.respawn(arena, where, 16, checks_run=checks.run)
        lines.append((status, aid, note))
    if brief["objects"]:
        solved = {aid: [tuple(w) for g in got for w in g["world"]]
                  for aid, got in sol.placements().items()}
        from . import budget as budgetmod
        budget = brief["budget"] if "budget" not in brief.defaulted else budgetmod.ceiling(
            brief["family"], brief["modes"] or arena.get("onlyFor") or ())
        have = list(arena.get("objects") or [])
        objs, olines = place.place_objects(arena, brief["objects"], solved, budget - len(have))
        objs, trees = place.blocks_for_trees(objs, brief.get("theme"), brief.get("seed", 0))
        if trees:
            arena["pieces"] = list(arena["pieces"]) + trees
        if objs:
            arena["objects"] = have + objs
            used = (len(arena["pieces"]) + len(arena.get("markers", []))
                    + len(arena["objects"]))
            arena["budget"] = max(arena.get("budget", 0), used)
        lines += olines
    if any(q.get("kind") == "place" for q in brief["requests"] or []):
        from . import placefeat
        done, plines = placefeat.apply(arena, brief)
        arena.setdefault("gameplay", {})["placed"] = done
        if plines:
            report["notes"] = list(report.get("notes", [])) + plines
        for line in plines:
            if line.startswith("placed: ") and " - " in line:
                what, how = line[len("placed: "):].split(" - ", 1)
                lines.append(("ok", what, how))
            elif ": " in line:
                what, why = line.split(": ", 1)
                lines.append(("not placed", what, why))
    from . import triblock
    tnotes = triblock.enforce(arena)
    if tnotes:
        report["notes"] = list(report.get("notes", [])) + tnotes
    from . import playable
    try:
        pnotes = playable.repair(arena)
        pnotes += playable.order_by_curve(arena)
        rho, _ = playable.curve(arena)
        arena["playable"] = {"unreached": len(playable.faults(arena)),
                             "curve": None if rho is None else round(rho, 3)}
        if pnotes:
            report["notes"] = list(report.get("notes", [])) + pnotes
    except Exception as why:
        report["notes"] = list(report.get("notes", [])) + ["playable: not run (%s)" % why]
    from . import budget as budgetfit
    if brief["family"] in budgetfit.BAKED_TIER_FAMILIES:
        try:
            got = budgetfit.fit_level(arena, brief["family"], brief.get("modes") or ())
            if got and got[2]:
                report["notes"] = list(report.get("notes", [])) + [
                    "level size: %d KB over the line, %d props thinned to %d KB"
                    % (round(got[0]), got[2], round(got[1]))]
        except Exception as why:
            report["notes"] = list(report.get("notes", [])) + ["level size: not fitted (%s)" % why]
    from . import critic
    try:
        arena["critic"] = dict(critic.rejudge(arena, brief["family"], brief.get("modes")),
                               repairs=(arena.get("critic") or {}).get("repairs") or [])
    except Exception as why:
        report["notes"] = list(report.get("notes", [])) + ["critic: not run (%s)" % why]
    checked = {aid: (st, note) for st, aid, note in anchormod.verify(arena, sol)}
    for st, aid, note in sol.lines():
        if aid in sol.problem.post:
            continue
        vst, vnote = checked.get(aid, ("unverified", ""))
        status = "placed" if vst in ("placed", "unverified") else vst
        lines.append((status, aid, "%s; %s" % (note, vnote) if vnote else note))
    merge_report(report, brief, sol, lines)
    from .worldspawn import ensure
    ensure(arena)
    return lines
def merge_report(report, brief, sol, lines):
    mine = {aid for _, aid, _ in lines}
    done = [d for d in report.get("done", [])
            if d.get("id") not in mine and not any(str(d.get("id", "")).startswith(m + ".")
                                                   for m in mine)]
    family_notes = {d.get("id"): d for d in report.get("done", [])}
    for status, aid, note in lines:
        a = sol.problem.anchors.get(aid, {})
        fam = [d for k, d in family_notes.items() if k == aid or str(k).startswith(aid + ".")]
        fam_bad = [d for d in fam if d.get("status") in ("refused", "not yet")]
        if fam_bad and status == "placed":
            status = "approximated"
            note += "; the family: " + "; ".join(d.get("note", "") for d in fam_bad)
        done.append({"id": aid, "what": a.get("what", aid.split(" ")[-1]),
                     "where": a.get("where"), "status": status, "note": note})
    report["done"] = done
    not_possible = [n for n in report.get("not_possible", [])
                    if not n.startswith("object ") or not brief["objects"]]
    not_possible = [n for n in not_possible if not any(n.startswith(m + ":") or
                                                       n.startswith(m + ".") for m in mine)]
    for status, aid, note in lines:
        if status in ("refused", "approximated"):
            not_possible.append("%s: %s" % (aid, note))
    report["not_possible"] = not_possible
    report["notes"] = list(report.get("notes", [])) + [n for n in sol.notes
                                                       if n not in report.get("notes", [])]
    report["anchors_solved"] = sol.placements()
    report["symmetry_solved"] = sol.frame.symmetry
UNBUILT_WHY = {
    "river": "a river runs through explore worlds only; the %s family builds none",
    "water": "the %s family built no water on this map",
}
def unbuilt_wants(arena, brief, asked=None):
    from . import generate as genmod
    asked = brief if asked is None else asked
    want = list((asked.get("features") or {}).get("want") or ())
    pieces = arena.get("pieces") or []
    if arena.get("water"):
        pieces = pieces + [{"kind": "water"}]
    fam = brief.get("family") or "?"
    np = arena.setdefault("report", {}).setdefault("not_possible", [])
    lines = []
    for f in ("river", "water"):
        if any(n.startswith(f + ":") for n in np):
            continue
        if f in want and not genmod.wanted_kept(pieces, {f}):
            if f == "water" and "river" in want and lines:
                continue
            lines.append("%s: not built - %s" % (f, UNBUILT_WHY[f] % fam))
    for q in brief.get("requests") or ():
        if q.get("kind") != "lanes" or not isinstance(q.get("count"), int):
            continue
        row = ((arena.get("critic") or {}).get("rows") or {}).get("lanes") or {}
        have = row.get("value")
        if have == q["count"]:
            continue
        lines.append("%d lanes: not built to order - %s; the %s family lays its own routes"
                     % (q["count"], ("this map has %d lanes between the bases" % have)
                        if isinstance(have, int) else "this map's lanes were not counted",
                        fam))
    for line in lines:
        if line not in np:
            np.append(line)
    return lines
def generate(brief, seed=None, candidates=None, use_metrics=True, history=None):
    r = run(brief, seed, candidates, use_metrics, history=history)
    arena = r.layout()
    report = arena.setdefault("report", {})
    report["not_understood"] = list(report.get("not_understood", [])) + r.dropped
    return arena
