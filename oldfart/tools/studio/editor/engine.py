import copy
import os
import re
from . import REPO
from mapgen import anchors as anchormod, api, brief as briefmod, checks, explain as explainmod
from mapgen import export as exportmod, kit as mkit, refine as refmod, v1, wish as wishmod
from mapgen.brief import Brief, BriefError
from mapgen import skies as _skies
class Cancelled(Exception):
    pass
class EngineError(Exception):
    pass
def _choices(values, labels=None):
    return [(v, (labels or {}).get(v, str(v).replace("_", " "))) for v in values]
FAMILY_LABELS = {"shooter": "Shooter (deathmatch)", "objective": "Objective (CTF, domination)",
                 "knockoff": "Knock-off (sumo)", "race": "Race", "hide": "Hide and seek",
                 "party": "Party plate", "course": "Obstacle course",
                 "explore": "Explore world (a big world to roam)"}
DIFFICULTY_STEPS = [("easy", "Casual"), ("normal", "Normal"), ("hard", "Hard"),
                    ("expert", "Expert"), ("pro", "Pro")]
COURSE_LENGTH_CHOICES = [("short", "short (about 30 s)"), ("medium", "medium (1-2 min)"),
                         ("long", "long (3-5 min)"), ("marathon", "marathon (6-10 min)")]
COURSE_FOCUS_CHOICES = [("mixed", "a bit of everything"), ("jumps", "jumps"),
                        ("climb", "climbing and wall kicks"),
                        ("balance", "balance: beams, stones, posts"),
                        ("moving", "moving platforms")]
_IN_OUT = [("on", "in"), ("off", "left out")]
COURSE_MOVES = (("longjump", "Long jumps", _IN_OUT), ("wallkick", "Wall kicks", _IN_OUT),
                ("sideflip", "Side flips", _IN_OUT), ("dive", "Dives", _IN_OUT),
                ("groundpound", "Ground pounds", _IN_OUT), ("triple", "Triple jumps", _IN_OUT),
                ("movers", "Moving platforms", _IN_OUT),
                ("blj", "BLJ (backward long jump)", [("off", "avoided"),
                                                     ("on", "a BLJ skip")]))
COURSE_CONTROLS = {"course_length": "length", "course_checkpoints": "checkpoints",
                   "course_focus": "focus", "course_sections": "sections"}
CONTROLS = (
    ("family", "Map kind", "choice", _choices(briefmod.FAMILIES, FAMILY_LABELS), True),
    ("players", "Players", "int", (2, 16), True),
    ("size", "Size", "choice", _choices(tuple(briefmod.SIZES)), True),
    ("shape", "Shape", "choice", [("square", "square"), ("wide", "wide (1.6 : 1)"),
                                  ("long", "long and narrow (2.5 : 1)")], True),
    ("theme", "Theme", "choice", _choices(briefmod.THEMES), True),
    ("difficulty", "Difficulty", "steps", DIFFICULTY_STEPS, True),
    ("course_length", "Course length", "choice", COURSE_LENGTH_CHOICES, True),
    ("sky", "Sky", "choice", [("auto", "Theme default")] + list(_skies.SKIES), False),
    ("symmetry", "Symmetry", "choice", _choices(briefmod.SYMMETRIES), True),
    ("verticality", "Verticality", "choice", _choices(briefmod.VERTICALITIES), True),
    ("density", "Cover", "choice", _choices(briefmod.DENSITIES), False),
    ("pace", "Pace", "choice", _choices(tuple(briefmod.PACES)), False),
    ("sides", "Teams", "choice", _choices(briefmod.SIDES), False),
    ("edge", "Edge", "choice", _choices(briefmod.EDGES), False),
    ("boundary", "Map edge", "choice", _choices(briefmod.BOUNDARIES, {
        "visible": "visible wall", "invisible": "invisible wall",
        "both": "both (low rim + invisible wall)"}), False),
    ("level", "Level", "choice", _choices(briefmod.LEVELS, {
        "empty": "The Tiles (a floor)", "empty2": "The Void (a death edge)"}), False),
    ("ground", "The Tiles' ground", "choice", _choices(briefmod.GROUNDS), False),
    ("style", "Style", "choice", _choices(briefmod.STYLES), False),
    ("width_m", "Width (metres)", "int", (15, 300), False),
    ("depth_m", "Depth (metres)", "int", (15, 300), False),
    ("budget", "Piece budget", "int", (20, briefmod.BUDGET_MAX), False),
    ("seed", "Seed", "int", (0, briefmod.SEED_MAX), False),
    ("candidates", "Candidates", "int", (1, 24), False),
    ("bonus_stars", "Bonus stars", "choice",
     [(0, "off")] + [(n, str(n)) for n in range(1, 7)], False),
    ("variety", "Material variety", "choice", _choices(briefmod.VARIETIES), False),
    ("forge_off", "Forge items", "choice",
     [("all", "none (blocks only)"), ("enemies", "no enemies"), ("hazards", "no hazards"),
      ("movers", "no moving parts"), ("items", "no items")], False),
    ("novelty", "Surprise", "choice",
     [("surprise", "Surprise me"), ("novel", "Something different")], False),
    ("course_checkpoints", "Checkpoint every", "choice",
     [(15, "15 seconds"), (20, "20 seconds"), (30, "30 seconds"), (45, "45 seconds"),
      (60, "a minute"), (90, "90 seconds")], False),
    ("course_focus", "Course theme", "choice", COURSE_FOCUS_CHOICES, False),
    ("course_sections", "Course sections", "int", (1, 30), False),
) + tuple(("move_" + m, label, "choice", choices, False) for m, label, choices in COURSE_MOVES)
REQUEST_CONTROLS = ("bonus_stars", "forge_off", "novelty")
def is_course_control(field):
    return field in COURSE_CONTROLS or field.startswith("move_")
def course_values(brief):
    opts = (brief.get("course") if hasattr(brief, "get") else None) or {}
    out = {f: opts.get(k) for f, k in COURSE_CONTROLS.items()}
    if out.get("course_focus") == "mixed":
        out["course_focus"] = None
    moves = opts.get("moves") or {}
    for m, _, _ in COURSE_MOVES:
        out["move_" + m] = None if m not in moves else ("on" if moves[m] else "off")
    return out
def set_course(raw, field, value):
    course = copy.deepcopy(raw.get("course") or {})
    if field.startswith("move_"):
        moves = dict(course.get("moves") or {})
        if value in (None, ""):
            moves.pop(field[5:], None)
        else:
            moves[field[5:]] = value in ("on", True)
        if moves:
            course["moves"] = moves
        else:
            course.pop("moves", None)
    else:
        key = COURSE_CONTROLS[field]
        if value in (None, ""):
            course.pop(key, None)
        else:
            course[key] = value
    if course:
        raw["course"] = course
    else:
        raw.pop("course", None)
SIZE_CONTROLS = ("shape", "width_m", "depth_m")
SHAPES = {"wide": 1.6, "long": 2.5}
def shape_size(raw, shape=None, width_m=None, depth_m=None):
    if width_m and depth_m:
        raw["size"] = {"w": int(width_m) * 100, "d": int(depth_m) * 100}
        return
    a = SHAPES.get(shape)
    if a is None:
        return
    cur = raw.get("size")
    if isinstance(cur, dict) and "across" in cur and "w" not in cur:
        raw["size"] = {"across": cur["across"], "aspect": a}
    elif isinstance(cur, dict) and "tier" in cur:
        raw["size"] = {"aspect": a, "tier": cur["tier"]}
    elif isinstance(cur, str):
        raw["size"] = {"aspect": a, "tier": cur}
    elif not isinstance(cur, dict):
        raw["size"] = {"aspect": a, "tier": "medium"}
def shape_of(size):
    if not isinstance(size, dict):
        return None, None, None, size
    if "w" in size and "d" in size:
        r = float(size["w"]) / max(1.0, float(size["d"]))
        r = max(r, 1.0 / r)
        shape = "long" if r >= 1.9 else ("wide" if r >= 1.25 else "square")
        return shape, int(size["w"]) // 100, int(size["d"]) // 100, None
    a = size.get("aspect")
    if a:
        r = max(a, 1.0 / a)
        return ("long" if r >= 1.9 else "wide" if r >= 1.25 else "square"), None, None, \
            size.get("tier")
    return None, None, None, None
def stars_of(brief):
    for q in (brief.get("requests") or []) if hasattr(brief, "get") else []:
        if isinstance(q, dict) and q.get("kind") == "stars":
            return q.get("count") if q.get("count") is not None else 6
    return None
def set_stars(raw, count):
    old = next((q for q in raw.get("requests") or [] if isinstance(q, dict)
                and q.get("kind") == "stars"), None)
    reqs = [q for q in raw.get("requests") or [] if not (isinstance(q, dict)
                                                         and q.get("kind") == "stars")]
    if count is not None:
        q = {"kind": "stars", "count": int(count)}
        hints = [h for h in (old or {}).get("stars") or [] if h.get("n", 0) <= int(count)]
        if hints and int(count) > 0:
            q["stars"] = hints
        reqs.append(q)
    if reqs:
        raw["requests"] = reqs
    else:
        raw.pop("requests", None)
FEATURES = tuple(briefmod.FEATURES)
FEATURE_HELP = dict(getattr(briefmod, "FUN_FEATURES", {}))
DNA = tuple(briefmod.DNA)
VISUALS = tuple(k for k in briefmod.VISUALS if k != "auto")
def control_values(brief):
    defaulted = set(brief.get("defaulted") or [])
    out = {}
    for field, _, _, _, _ in CONTROLS:
        if field in REQUEST_CONTROLS or field in SIZE_CONTROLS or is_course_control(field):
            continue
        out[field] = None if field in defaulted else brief.get(field)
    out.update(course_values(brief))
    shape, wm, dm, tier = shape_of(None if "size" in defaulted else brief.get("size"))
    out["shape"], out["width_m"], out["depth_m"] = shape, wm, dm
    if isinstance(out.get("size"), dict):
        out["size"] = tier
    out["bonus_stars"] = stars_of(brief)
    off = list(brief.get("forge_off") or [])
    out["forge_off"] = off[0] if len(off) == 1 else None
    out["novelty"] = (brief.get("novelty") or {}).get("mode") \
        if (brief.get("novelty") or {}).get("mode") in ("surprise", "novel") else None
    feats = brief.get("features") or {}
    out["want"] = list(feats.get("want") or [])
    out["avoid"] = list(feats.get("avoid") or [])
    out["dna"] = dict(brief.get("dna") or {})
    out["visuals"] = list(brief.get("visuals") or [])
    out["name"] = brief.get("name")
    return out
def _refused(why):
    text = str(why)
    return EngineError(text if text.startswith("refused:") else "refused: %s" % text)
def _same_placed(a, b):
    if not (isinstance(a, dict) and isinstance(b, dict)):
        return False
    if a.get("id") and b.get("id"):
        return a["id"] == b["id"]
    keys = [k for k in a if k != "id"]
    return bool(keys) and all(b.get(k) == a[k] for k in keys)
def join_placed(have, new):
    have = list(have or [])
    return have + [a for a in new or [] if not any(_same_placed(a, b) for b in have)]
def brief_from(controls=None, wish=None, base=None):
    raw = api.raw_of(base) if base else {}
    reading = None
    if wish and wish.strip():
        reading = read_wish(wish, base=raw or None)
        for k, v in reading.raw.items():
            if k in ("anchors", "objects") and raw.get(k):
                raw[k] = join_placed(raw[k], v)
            else:
                raw[k] = copy.deepcopy(v)
    sized = {}
    for field, value in (controls or {}).items():
        if field in SIZE_CONTROLS:
            sized[field] = value
        elif is_course_control(field):
            if value is not None and value != "":
                set_course(raw, field, value)
        elif field == "bonus_stars":
            if value is not None and value != "":
                set_stars(raw, value)
        elif field == "forge_off":
            if value:
                raw["forge_off"] = [value]
        elif field == "novelty":
            if value:
                raw["novelty"] = {"mode": value}
        elif field in ("want", "avoid"):
            f = raw.setdefault("features", {"want": [], "avoid": []})
            f.setdefault("want", [])
            f.setdefault("avoid", [])
            other = "avoid" if field == "want" else "want"
            for x in value or []:
                if x not in f[field]:
                    f[field].append(x)
                if x in f[other]:
                    f[other].remove(x)
        elif field == "dna":
            if value:
                d = dict(raw.get("dna") or {})
                d.update(value)
                raw["dna"] = d
        elif field == "visuals":
            if value:
                v = list(raw.get("visuals") or [])
                raw["visuals"] = v + [x for x in value if x not in v]
        elif value is None or value == "":
            continue
        else:
            raw[field] = value
    if any(v not in (None, "") for v in sized.values()):
        shape_size(raw, **sized)
    if raw.get("ground") not in (None, "auto", "tiles") and raw.get("level") in (None, "auto"):
        raw["level"] = "empty"
    return raw, reading
_READINGS = {}
def _taught_stamp():
    try:
        from mapgen import userlex
        p = userlex.path()
        return (p, os.path.getmtime(p)) if os.path.exists(p) else (p, None)
    except Exception:
        return None
def read_wish(text, base=None):
    try:
        import json
        key = (text, json.dumps(base, sort_keys=True) if base is not None else None,
               _taught_stamp())
    except (TypeError, ValueError):
        return wishmod.understand(text, base=base)
    got = _READINGS.get(key)
    if got is None:
        got = wishmod.understand(text, base=copy.deepcopy(base) if base is not None else None)
        if len(_READINGS) >= 32:
            _READINGS.pop(next(iter(_READINGS)))
        _READINGS[key] = got
    return copy.deepcopy(got)
def explain(raw):
    try:
        brief = Brief.from_dict(api.raw_of(raw), mkit.forge_keys())
    except BriefError as why:
        return "The brief is not valid:\n  " + "\n  ".join(why.problems)
    lines = [explainmod.brief_text(brief)]
    try:
        sol = anchormod.solve(api.raw_of(brief))
        if sol.problem.anchors:
            lines.append("Anchors (solved before any module is chosen):")
            for status, aid, note in sol.lines():
                lines.append("  [%s] %s: %s" % (status, aid, note))
            lines += ["  note: %s" % n for n in sol.notes]
    except anchormod.Refused as why:
        lines.append("Anchors: %s" % why)
    return "\n".join(lines)
class Generated:
    def __init__(self, brief, layout, report_text="", lines=None, candidates=None, label=""):
        self.brief = brief
        self.layout = layout
        self.report_text = report_text
        self.lines = lines or []
        self.candidates = candidates or []
        self.label = label
    @property
    def ok(self):
        return not (self.layout.get("report") or {}).get("faults")
def _progress_fn(progress, cancel, total):
    seen = [0]
    import time as _time
    t0 = [_time.time()]
    def eta():
        if not seen[0]:
            return ""
        left = max(0, total - min(seen[0], total)) * (_time.time() - t0[0]) / seen[0]
        return " - about %d min left" % max(1, int(round(left / 60.0))) if left >= 30 else ""
    def fn(candidate):
        if cancel is not None and cancel():
            raise Cancelled()
        seen[0] += 1
        if progress is not None:
            s = candidate.summary()
            progress(min(seen[0], total), total, "candidate %d of %d: %s, quality %s%s" % (
                (seen[0] - 1) % total + 1, total, "ok" if s["ok"] else "failed", s["quality"],
                eta()))
    def on_phase(text):
        if cancel is not None and cancel():
            raise Cancelled()
        if progress is not None:
            progress(min(seen[0], total), total, "%s%s" % (text, eta()))
    fn.on_phase = on_phase
    return fn
HISTORY = True
PATTERNS = True
STAMPS = True
def host_patterns_on():
    from mapgen import hostpatterns, stamps
    was = (hostpatterns.ACTIVE, stamps.ACTIVE)
    if PATTERNS:
        try:
            hostpatterns.ACTIVE = hostpatterns.Store.load().items or None
        except Exception:
            hostpatterns.ACTIVE = None
    if STAMPS:
        try:
            stamps.ACTIVE = stamps.Store.load().in_use() or None
        except Exception:
            stamps.ACTIVE = None
    return was
def host_patterns_off(was):
    from mapgen import hostpatterns, stamps
    hostpatterns.ACTIVE, stamps.ACTIVE = was
def history_flag(history=None):
    return HISTORY if history is None else history
def generate(raw, seed=None, candidates=None, use_metrics=True, progress=None, cancel=None,
             wish=None, reading=None, history=None):
    raw = api.raw_of(raw)
    if seed is not None:
        raw["seed"] = seed
    if candidates is not None:
        raw["candidates"] = candidates
    try:
        total = Brief.from_dict(api.lenient(raw)[0].to_dict())["candidates"]
    except BriefError:
        total = raw.get("candidates", 6)
    from mapgen import score as scoremod
    old_taste = scoremod.TASTE
    if TASTE:
        try:
            scoremod.TASTE = taste_store()
        except Exception:
            scoremod.TASTE = None
    old_patterns = host_patterns_on()
    pfn = _progress_fn(progress, cancel, total)
    from mapgen import generate as _genmod
    _genmod.PHASE_HOOKS.append(pfn.on_phase)
    try:
        run = api.run(raw, use_metrics=use_metrics, progress=pfn,
                      history=history_flag(history))
    except Cancelled:
        raise
    except anchormod.Refused as why:
        raise _refused(why)
    except (BriefError, RuntimeError, ValueError) as why:
        raise EngineError(str(why))
    finally:
        scoremod.TASTE = old_taste
        host_patterns_off(old_patterns)
        if pfn.on_phase in _genmod.PHASE_HOOKS:
            _genmod.PHASE_HOOKS.remove(pfn.on_phase)
    layout = run.layout()
    report = layout.setdefault("report", {})
    report["not_understood"] = list(report.get("not_understood", [])) + run.dropped
    if reading is not None:
        report["not_understood"] += [n for n in reading.not_understood
                                     if n not in report["not_understood"]]
    understood = None
    nu = None
    if reading is not None:
        understood = reading.understood + ["assumed: " + a for a in reading.assumed]
        nu = reading.not_understood
    text = explainmod.report(run.result, wish, understood, nu, language=run.lines)
    cands = [c.summary() for c in run.result.candidates]
    brief = run.brief.to_dict()
    return Generated(brief, layout, text, run.lines, cands, "Generate")
def refine(brief, layout, text, use_metrics=True, progress=None, cancel=None, history=None,
           ops=None):
    if cancel is not None and cancel():
        raise Cancelled()
    try:
        b = Brief.from_dict(api.raw_of(brief), mkit.forge_keys())
    except BriefError as why:
        raise EngineError(str(why))
    index = ((layout or {}).get("generator") or {}).get("candidate", 0)
    given = ops
    ops, later, not_understood, reading = refmod.parse_ops(text or "", b)
    if given:
        ops = list(given)
    said = ["not yet: %s" % x for x in later]
    said += ["assumed: %s" % a for a in reading.assumed]
    said += ["not understood: %s" % n for n in not_understood]
    if not ops:
        raise EngineError("nothing to change in %r%s" % (text, ("; " + "; ".join(said))
                                                            if said else ""))
    if progress is not None:
        progress(0, 1, "refine: " + "; ".join(" ".join(str(x) for x in op) for op in ops))
    if any(op[0] == "novelty" for op in ops):
        new_brief, why = refmod.apply(b, ops)
        g = generate(api.raw_of(new_brief), use_metrics=use_metrics, progress=progress,
                     cancel=cancel, wish="refine: " + (text or ""),
                     history=history_flag(history) or True)
        g.lines = said + ["why: %s" % w for w in why] + list(g.lines or [])
        return g
    try:
        result, changed = refmod.refine(b, index, ops, use_metrics=use_metrics, old_layout=layout)
    except anchormod.Refused as why:
        raise _refused(why)
    if not result.best.ok:
        raise EngineError("the refined map fails the hard checks: %s"
                          % "; ".join(result.best.checks.faults[:3]))
    new = result.layout()
    rep = new.get("report", {})
    for d in rep.get("done", []):
        said.append("[%s] %s: %s" % (d.get("status"), d.get("id"), d.get("note")))
    said += ["why: %s" % w for w in rep.get("refine", [])]
    said.append("modules that changed: %s" % (", ".join(changed) or "none"))
    report_text = explainmod.report(result, "refine: " + (text or ""))
    return Generated(result.brief.to_dict(), new, report_text, said, [], "Refine: %s" % text)
def variety(raw, count=6, children=60, workers=None, progress=None, cancel=None):
    from mapgen import variety as varmod
    raw = api.raw_of(raw)
    try:
        user = Brief.from_dict(api.lenient(raw)[0].to_dict())
        sol = anchormod.solve(raw)
        fam, _ = api.lenient(api.family_brief(raw, sol))
    except anchormod.Refused as why:
        raise _refused(why)
    except BriefError as why:
        raise EngineError(str(why))
    def step(done, total, archive, elapsed):
        if cancel is not None and cancel():
            raise Cancelled()
        if progress is not None:
            progress(done, total, "%d of %d maps searched" % (done, total))
    res = varmod.run(fam, children=children, k=max(1, count - 1), workers=workers,
                     progress=step)
    out = []
    for n, e in enumerate(res.picks[:count]):
        arena = copy.deepcopy(e.arena)
        api.postprocess(arena, user, sol)
        b = varmod.brief_of(fam, e.genome)
        arena["generator"] = {"seed": b["seed"], "candidate": e.genome.get("index", 0),
                              "family": b["family"], "quality": e.quality,
                              "variety": e.genome, "score_source": "variety"}
        keep = varmod.brief_of(user, e.genome).to_dict()
        out.append(Generated(keep, arena, "", ["%s %.2f" % (a, v) for a, v in
                                               sorted((e.desc or {}).items()) if v is not None],
                             [], "Variety %d" % (n + 1)))
        out[-1].quality = e.quality
        out[-1].desc = dict(e.desc or {})
    return out
TASTE = True
class Pair:
    def __init__(self, brief, family, size, a, b, seed):
        self.brief = brief
        self.family = family
        self.size = size
        self.a = a
        self.b = b
        self.seed = seed
def taste_pair(raw, seed=None, candidates=4, progress=None, cancel=None):
    from mapgen import generate as genmod
    raw = api.raw_of(raw)
    if seed is not None:
        raw["seed"] = seed
    was = host_patterns_on()
    try:
        sol = anchormod.solve(raw)
        fam, _ = api.lenient(api.family_brief(raw, sol))
        result = genmod.generate(fam, candidates, use_metrics=True, report_fit=False,
                                 progress=_progress_fn(progress, cancel, candidates),
                                 finals=False)
    except Cancelled:
        raise
    except anchormod.Refused as why:
        raise _refused(why)
    except (BriefError, RuntimeError, ValueError) as why:
        raise EngineError(str(why))
    finally:
        host_patterns_off(was)
    good = [c for c in result.candidates if c.ok and c.score and not c.meta.get("reference")]
    good.sort(key=lambda c: (-(c.quality or 0), c.index))
    if len(good) < 2:
        raise EngineError("only %d candidate passed the gate - try another seed" % len(good))
    def side(c):
        return {"layout": c.arena, "rows": c.score.get("rows") or {},
                "quality": c.quality, "index": c.index}
    return Pair(fam.to_dict(), fam["family"], fam["size"], side(good[0]), side(good[1]),
                fam["seed"])
def taste_store():
    from mapgen import taste
    return taste.Taste.load()
def regenerate_region(brief, layout, box, tries=8, use_metrics=False, progress=None,
                      cancel=None):
    from mapgen import region as regmod
    def step(done, total, text):
        if cancel is not None and cancel():
            raise Cancelled()
        if progress is not None:
            progress(done, total, text)
    try:
        return regmod.regenerate(brief, layout, box, tries=tries, use_metrics=use_metrics,
                                 progress=step, forge_keys=mkit.forge_keys())
    except regmod.Refused as why:
        raise EngineError(str(why))
def gate(layout):
    arena = copy.deepcopy(layout)
    arena.setdefault("key", "generated")
    m = v1.arenas_module()
    try:
        for p in arena.get("pieces", []):
            p["model"] = m.model_name(p)
        return checks.run(arena)
    except Exception as why:
        return checks.Result(["%s: %s" % (why.__class__.__name__, why)])
def card(layout, brief=None, tier="cheap", sim=False, wish=None, looks=None):
    from mapgen.report.card import build_card
    arena = copy.deepcopy(layout)
    arena.setdefault("key", "generated")
    if brief:
        arena.setdefault("players", brief.get("players"))
    rep = arena.get("report", {}) or {}
    g = gate(layout)
    out = {"gate": list(g.faults), "ok": g.ok}
    if not arena.get("pieces") or not arena.get("spawns"):
        out["card"] = None
        out["why_no_card"] = "the map needs pieces and spawns before it can be measured"
        return out
    family = (brief or {}).get("family") or arena.get("family")
    want = (tier == "full") if looks is None else looks
    audit = looks if isinstance(looks, dict) else None
    if want is True:
        try:
            from mapgen.metrics import looks as looksmod
            audit = looksmod.audit(arena, family)
        except Exception:
            audit = None
    try:
        c = build_card(arena, brief=brief, wish=wish or (brief or {}).get("wish"),
                       defaulted=(brief or {}).get("defaulted"), done=rep.get("done"),
                       not_understood=rep.get("not_understood"),
                       not_possible=rep.get("not_possible"), tier=tier, sim=sim,
                       looks=audit if audit is not None else bool(want))
    except Exception as why:
        out["card"] = None
        out["why_no_card"] = "the metrics could not read this map: %s" % why
        return out
    world = world_rows(layout)
    if world and isinstance(c, dict):
        c.setdefault("metrics", []).append({"group": "World landform", "rows": world})
    line, rows = course_rows(layout)
    if line:
        out["course_line"] = line
        if isinstance(c, dict):
            c.setdefault("metrics", []).append({"group": "Obstacle course", "rows": rows})
    try:
        from mapgen import critic
        cr = critic.judge(arena, family, looks=audit, modes=(brief or {}).get("modes"))
        out["critic"] = cr
        if isinstance(c, dict):
            c.setdefault("metrics", []).append({"group": "Critic", "rows": critic_rows(cr)})
    except Exception:
        out["critic"] = None
    modes = mode_rows(layout, brief)
    if modes and isinstance(c, dict):
        c.setdefault("metrics", []).insert(0, {"group": "Game modes", "rows": modes})
    why = why_rows(rep.get("why_won"))
    if why and isinstance(c, dict):
        c.setdefault("metrics", []).insert(0, {"group": "Why this map won", "rows": why})
    out["card"] = c
    return out
from mapgen.critic import LABELS as CRITIC_LABELS
def critic_rows(cr):
    from mapgen import critic
    rows = [{"metric": "critic", "label": "Critic score", "value": cr["score"],
             "band": ">= %d" % cr["line"], "status": "pass" if cr["pass"] else "fail",
             "explain": "The critic looks at the whole map like a picture and a "
                        "playground: over %d it is a good map." % cr["line"]}]
    for w in cr.get("warnings") or []:
        rows.append({"metric": "critic.warning", "label": "Warning", "value": w, "band": "",
                     "status": "warn", "explain": critic.EXPLAIN.get("liminal", ""),
                     "fix": critic.FIXES.get("liminal"), "one_click": True,
                     "row": "liminal"})
    for k, r in cr["rows"].items():
        st = "pass" if r["score"] >= 0.8 else "warn" if r["score"] >= 0.5 else "fail"
        row = {"metric": "critic.%s" % k, "label": critic.LABELS.get(k, k),
               "value": r["note"], "band": "", "status": st, "row": k,
               "explain": critic.EXPLAIN.get(k, "")}
        if r.get("advisory"):
            row["advisory"] = True
        if r.get("where"):
            row["where"] = [list(w)[:2] for w in r["where"][:12]]
        if st != "pass" and k in critic.FIXES:
            row["fix"] = critic.FIXES[k]
            row["one_click"] = k in critic.REPAIRS
        rows.append(row)
    return rows
def picked_modes(layout, brief=None):
    brief = brief or {}
    keys = brief.get("modes")
    if keys and "modes" not in (brief.get("defaulted") or ()):
        return list(keys)
    only = (layout or {}).get("onlyFor")
    if isinstance(only, list) and only and isinstance((layout or {}).get("notFor"), list):
        return []
    return list(only) if isinstance(only, list) else []
MODE_EXPLAIN = ("Each game mode needs some things on the map: spawn points for everybody, "
                "flags for Capture the Flag, a hill for King of the Hill. A red or amber "
                "line says what is missing - the button puts it there.")
def mode_rows(layout, brief=None):
    keys = picked_modes(layout, brief)
    if not keys:
        return []
    from mapgen import modeready
    players = (brief or {}).get("players")
    players = players if isinstance(players, int) and players > 0 else 16
    size = (brief or {}).get("size")
    size = size if size in modeready.TIERS else None
    try:
        ready = modeready.readiness(layout or {}, keys, players, size)
    except Exception:
        return []
    rows = []
    for k in keys:
        issues = ready.get(k) or []
        name = modeready.name_of(k)
        if not issues:
            rows.append({"metric": "mode.%s" % k, "label": name, "value": "Ready", "band": "",
                         "status": "pass", "explain": MODE_EXPLAIN})
            continue
        worst = issues[0]
        row = {"metric": "mode.%s" % k, "label": name,
               "value": worst.get("short", worst.text) + (
                   " (+%d more)" % (len(issues) - 1) if len(issues) > 1 else ""),
               "band": "", "status": "fail" if worst.level == modeready.BLOCK else "warn",
               "explain": MODE_EXPLAIN, "fix": "; ".join(i.text for i in issues)}
        if worst.get("fix"):
            row["mode_fix"] = {"key": k, "fix": dict(worst["fix"]),
                               "fix_label": worst.get("fix_label") or "Fix it"}
        rows.append(row)
    return rows
def course_report(layout):
    gen = (layout or {}).get("generator") or {}
    rep = (gen.get("params") or {}).get("course")
    return rep if isinstance(rep, dict) and rep.get("tier") else None
def course_rows(layout):
    rep = course_report(layout)
    if rep is None:
        return "", []
    from mapgen import coursecheck
    line = rep.get("text") or coursecheck.card_text(rep)
    band = rep.get("band_s") or [None, None]
    clean = rep.get("clean_s")
    ok = band[0] is not None and clean is not None and band[0] <= clean <= band[1]
    rows = [{"metric": "course.difficulty", "label": "Difficulty",
             "value": line.split("Difficulty: ", 1)[-1], "band": "", "status": "n/a"}]
    rows.append({"metric": "course.clean_s", "label": "A good run",
                 "value": "%d s" % round(clean or 0),
                 "band": "%s-%s s (%s)" % (band[0], band[1], rep.get("length")) if band[0]
                 else "", "status": "pass" if ok else ("warn" if band[0] else "n/a")})
    rows.append({"metric": "course.expected_s", "label": "A first run (falls counted)",
                 "value": "%d s" % round(rep.get("expected_s") or 0), "band": "",
                 "status": "n/a"})
    bad = rep.get("infeasible") or []
    rows.append({"metric": "course.feasible", "label": "Every jump possible (frame-exact)",
                 "value": "yes, %d moves" % rep.get("moves", 0) if not bad else
                 "%d impossible: %s" % (len(bad), bad[0]["label"]), "band": "",
                 "status": "fail" if bad else "pass"})
    rows.append({"metric": "course.checkpoints", "label": "Checkpoints",
                 "value": len(rep.get("checkpoints") or []), "band": "", "status": "n/a"})
    for i, h in enumerate(rep.get("hotspots") or []):
        rows.append({"metric": "course.hotspot%d" % (i + 1), "label": "Death hotspot %d" % (i + 1),
                     "value": "%s (%d%% a try)" % (h["text"], round(100 * h["p"])),
                     "band": "", "status": "warn" if h["p"] >= 0.25 else "n/a"})
    for sk in rep.get("skips") or []:
        rows.append({"metric": "course.skip", "label": "Experts' skip", "value": sk.get("label"),
                     "band": "", "status": "n/a"})
    rows.append({"metric": "course.blj", "label": "BLJ", "value": rep.get("blj", ""),
                 "band": "", "status": "n/a"})
    return line, rows
def why_rows(why):
    if not why:
        return []
    from mapgen import critic
    rows = [{"metric": "why", "label": "Why this map won", "value": why["headline"],
             "band": "", "status": "pass",
             "explain": "The generator built a few maps and kept the best one. These rows "
                        "say where this map beat the next best."}]
    for r in why.get("rows") or []:
        st = "pass" if r["delta"] > 0.0 else "warn" if r["delta"] < 0.0 else "n/a"
        rows.append({"metric": "why.%s" % r["row"], "label": r["label"],
                     "value": r["say"].split(": ", 1)[-1],
                     "band": "runner-up %s" % _pct(r["runner_up"]), "status": st,
                     "explain": WHY_EXPLAIN.get(r["row"]) or critic.EXPLAIN.get(r["row"], "")})
    return rows
WHY_EXPLAIN = {"quality": "How well the map hits the targets for its kind of game: size, "
                          "time to cross, places to hide or fight.",
               "play": "How it plays: fair starts, good paths, a middle worth fighting for.",
               "looks": "How it looks: landmarks, light and dark, calm and detail."}
def _pct(v):
    return "%d" % round(100 * v) if isinstance(v, (int, float)) else str(v)
def critic_fix(layout, row):
    from mapgen import critic
    out = copy.deepcopy(layout)
    notes = critic.fix(out, row)
    return (out if notes else layout), notes
def critic_fix_preview(layout, row, family=None):
    from mapgen import critic
    new, notes = critic_fix(layout, row)
    if not notes:
        return None
    diff = {}
    for key in ("pieces", "objects", "spawns", "stars", "movers"):
        a, b = layout.get(key) or [], new.get(key) or []
        changed, added, removed = [], [], []
        if len(b) >= len(a):
            changed = [i for i in range(len(a)) if a[i] != b[i]]
            added = list(range(len(a), len(b)))
        else:
            j = 0
            for i, item in enumerate(a):
                if j < len(b) and b[j] == item:
                    j += 1
                else:
                    removed.append(i)
        if changed or added or removed:
            diff[key] = {"changed": changed, "added": added, "removed": removed}
    fam = family or layout.get("family")
    def score(lay):
        try:
            arena = dict(lay)
            arena.setdefault("key", "generated")
            return critic.judge(arena, fam)["score"]
        except Exception:
            return None
    return {"row": row, "label": critic.LABELS.get(row, row), "layout": new, "notes": notes,
            "diff": diff, "before": score(layout), "after": score(new),
            "says": fix_words(notes, diff)}
def fix_words(notes, diff):
    out = [n[0].upper() + n[1:] for n in notes if n]
    names = {"pieces": ("block", "blocks"), "objects": ("object", "objects"),
             "spawns": ("spawn", "spawns"), "stars": ("star", "stars"),
             "movers": ("mover", "movers")}
    bits = []
    for key, d in diff.items():
        one, many = names.get(key, (key, key))
        for what, verb in (("changed", "changed"), ("added", "added"), ("removed", "taken out")):
            n = len(d[what])
            if n:
                bits.append("%d %s %s" % (n, one if n == 1 else many, verb))
    if bits:
        out.append("In all: " + ", ".join(bits) + ".")
    return out
WORLD_ROWS = (("raised", "Raised floor (>= 200)", (0.4, 0.7), "%"),
              ("under400", "Floor under 400", (None, 0.8), "%"),
              ("levels", "Ground levels", (3, None), ""),
              ("plateaus", "Plateaus", (3, None), ""),
              ("sloped_share", "Steps sloped (the rest are ledges)", None, "%"),
              ("weirs", "Weirs on the river", None, ""),
              ("bridges", "Bridge cells", None, ""),
              ("road_climbs", "Road climbs", None, ""),
              ("road_turns", "Turns at landings", None, ""),
              ("caves", "Caves", None, ""))
def world_rows(layout):
    rel = ((layout or {}).get("sites") or {}).get("relief")
    if not isinstance(rel, dict):
        return []
    rows = []
    for key, label, band, unit in WORLD_ROWS:
        if key not in rel:
            continue
        v = rel[key]
        status = "n/a"
        band_s = ""
        if band:
            lo, hi = band
            ok = (lo is None or v >= lo) and (hi is None or v <= hi)
            status = "pass" if ok else "warn"
            fmt = (lambda x: "%d%%" % round(100 * x)) if unit == "%" else str
            band_s = "%s-%s" % ("" if lo is None else fmt(lo), "" if hi is None else fmt(hi))
        value = ("%d%%" % round(100 * v)) if unit == "%" else v
        rows.append({"metric": "world." + key, "label": label, "value": value, "band": band_s,
                     "status": status})
    lms = ((layout or {}).get("sites") or {}).get("landmarks") or []
    if lms:
        rows.append({"metric": "world.landmarks", "label": "Landmarks",
                     "value": ", ".join(x["kind"] for x in lms), "band": "", "status": "n/a"})
    return rows
KEY_RE = briefmod.KEY_RE
def key_for(name):
    key = "".join(ch for ch in (name or "").lower() if ch.isalnum())
    if key.startswith("the") and len(key) > 6:
        key = key[3:]
    if key and not key[0].isalpha():
        key = "m" + key
    return key[:24]
def taken_keys(mod=None):
    mod = mod or REPO
    try:
        return set(exportmod._existing_keys(mod)) | set(v1.venue_keys())
    except OSError:
        return set(v1.venue_keys())
class ExportSize(tuple):
    level = None
def export_size(layout, mod=None):
    mod = mod or REPO
    now, after, wall = exportmod.wall_after(layout, mod)
    out = ExportSize((now, after, wall))
    try:
        out.level = exportmod.level_bytes(layout, mod)
    except Exception:
        out.level = None
    return out
def export_checks(layout, mod=None):
    faults = list(gate(layout).faults)
    size = None
    if mod:
        try:
            size = export_size(layout, mod)
        except Exception:
            size = None
    return faults, size
def size_line(size):
    now, after, wall = size
    rs = exportmod._release_size()
    line = "The mod folder: %s now, about %.1f MB after this export" % (
        rs.wall_line(now), after / 1048576.0)
    level = getattr(size, "level", None)
    if level and level[1]:
        line = "This map's level file: %s. %s" % (exportmod.level_words(level[0]), line)
    return line
def check_export(layout, name, key, mod=None, gate_faults=None, size=None, modes=None,
                 mode_layout=None, players=16, map_size=None):
    problems = []
    if size is None and layout is not None and os.path.isdir(mod or REPO):
        size = export_size(layout, mod)
    if size is not None:
        too_big = exportmod.wall_refusal(*size)
        if too_big:
            problems.append(too_big)
    named = bool((name or "").strip())
    if not named:
        problems.append("give the map a name")
    if not KEY_RE.match(key or ""):
        if key or named:
            problems.append("key %r (the short name the game uses): 3-24 lower-case letters "
                            "or digits, starting with a letter" % (key or ""))
    elif key in taken_keys(mod):
        problems.append("key %r is already a place in of_arena.lua - pick a new one" % key)
    if modes:
        from mapgen import modeready
        on = mode_layout if mode_layout is not None else layout
        for k in modes:
            problems += ["%s is not playable yet: %s" % (
                modeready.name_of(k), i["short"][:1].lower() + i["short"][1:])
                         for i in modeready.issues(on or {}, k, players, map_size)
                         if i.level == modeready.BLOCK]
    faults = list(gate(layout).faults if gate_faults is None else gate_faults)
    problems += ["safety gate: %s" % f for f in faults[:8]]
    if len(faults) > 8:
        problems.append("... and %d more" % (len(faults) - 8))
    return problems
def replaces(key, mod=None):
    path = os.path.join(exportmod.generated_dir(mod or REPO), "%s.json" % key)
    return os.path.exists(path)
def export(layout, brief, name, key, mod=None, blurb=None, note=None):
    mod = mod or REPO
    problems = check_export(layout, name, key, mod, modes=layout.get("onlyFor"))
    if problems:
        raise EngineError("; ".join(problems))
    lay = copy.deepcopy(layout)
    lay.setdefault("family", (brief or {}).get("family", "shooter"))
    if brief and brief.get("modes") and not lay.get("onlyFor"):
        lay["onlyFor"] = list(brief["modes"])
    try:
        res = exportmod.export_mod(lay, mod, key, name, blurb, note)
    except exportmod.ExportError as why:
        raise EngineError(str(why))
    res["handoff"] = handoff(lay, key, name, mod)
    return res
def unexport(key, mod=None):
    try:
        return exportmod.unexport_mod(mod or REPO, key)
    except exportmod.ExportError as why:
        raise EngineError(str(why))
def handoff(layout, key, name, mod=None):
    modes = layout.get("onlyFor") or exportmod.default_modes(layout)
    lines = [
        "%s is in the mod as the venue `%s`." % (name, key),
        "",
        "Play it:",
        "1. Close Coop DX if it is running (a new level is compiled when the game starts; "
        "a running lobby cannot load it).",
        "2. Start Coop DX with the mod%s and host a lobby." % (
            "" if os.path.abspath(mod or REPO) == os.path.abspath(REPO)
            else " from %s" % mod),
        "3. Open the menu: Travel > Arenas > %s - everybody goes there." % name,
    ]
    if modes:
        from mapgen import modeready
        lines.append("4. Or start a round of %s: its map picker offers %s." % (
            ", ".join(modeready.name_of(m) for m in modes), name))
    lines += [
        "",
        "Guests need the same files: share the mod folder again (actors/, levels/, "
        "of_venues.lua, of_arena.lua changed).",
        "Take it out again: Oldfart Studio's Export panel > Remove, or "
        "`python3 tools/mapgen export --remove %s`." % key,
    ]
    return "\n".join(lines)
def forge_objects():
    return list(mkit.forge_keys() or [])
def music_tracks():
    return list(mkit.music_tracks())
def say_reading(reading, final=None):
    if reading is None:
        return []
    from mapgen import vocab
    out = [vocab.summary(final if final is not None else reading.raw, "en",
                         partly=bool(reading.not_understood))]
    if reading.assumed:
        out.append("assumed: %s" % "; ".join(reading.assumed))
    if reading.not_understood:
        out.append("not understood: %s" % "; ".join(
            ("%s (in %r)" % (n, reading.heard_in[n])) if n in reading.heard_in else n
            for n in reading.not_understood))
    return out
def fold(text):
    return re.sub(r"\s+", " ", (text or "").strip())
