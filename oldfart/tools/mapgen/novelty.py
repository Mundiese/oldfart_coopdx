import random
import zlib
from . import history
ROLL_FIELDS = ("preset", "theme", "size", "verticality", "density", "style")
SIZES_ROLLED = (("small", 2), ("medium", 2), ("large", 3), ("huge", 3), ("gigantic", 1),
                ("tiny", 1))
VISUAL_ROLL = ("warm_sun", "sunset", "moonlight", "firelight", "hard_shadows", "snow",
               "petals", "rain", "sepia", "rust", "gold")
QUALITY_FLOOR = 0.8
NEAR_BEST = 0.95
class Plan:
    def __init__(self):
        self.notes = []
        self.rolled = {}
        self.forces = None
        self.banned = {}
        self.mode = None
        self.path = None
    def forces_for(self, n):
        if not self.forces:
            return None
        return [{"skeleton": self.forces[i % len(self.forces)]} for i in range(n)]
def _rng(brief, p, salt=0):
    h = history.load(p)
    key = "%d:%d:%d" % (brief["seed"], h.get("count", 0), salt)
    return random.Random(zlib.crc32(key.encode()))
def _rare(rng, choices, counts):
    weights = [(c, w / (1.0 + 2.0 * counts.get(c, 0))) for c, w in choices]
    total = sum(w for _, w in weights)
    x = rng.random() * total
    for c, w in weights:
        x -= w
        if x < 0:
            return c
    return weights[-1][0]
def _roll(raw, user, rng, p, banned):
    from . import brief as briefmod
    from . import presets
    fam = user["family"]
    out = {}
    free = set(user.defaulted)
    if "preset" in free and rng.random() < 0.6:
        keys = [k for k, _, _ in presets.table() if k not in banned.get("preset", [])]
        if keys:
            out["preset"] = _rare(rng, [(k, 1) for k in keys], history.counts("preset", fam, p))
    if "theme" in free:
        themes = [t for t in briefmod.THEMES if t != "auto" and t not in banned.get("theme", [])]
        out["theme"] = _rare(rng, [(t, 1) for t in themes], history.counts("theme", fam, p))
    if "size" in free:
        sizes = [(s, w) for s, w in SIZES_ROLLED if s not in banned.get("size", [])
                 and s in briefmod.SIZES]
        out["size"] = _rare(rng, sizes, history.counts("size", fam, p))
    if "verticality" in free:
        out["verticality"] = rng.choice(briefmod.VERTICALITIES)
    if "density" in free:
        out["density"] = rng.choice(briefmod.DENSITIES)
    if "style" in free:
        out["style"] = rng.choice(("plain", "built"))
    named = dict(user["dna"] or {})
    if not named:
        out["dna"] = {k: round(rng.random(), 1) for k in ("complexity", "age", "nature")}
    else:
        rolled = {k: round(rng.random(), 1) for k in ("complexity", "age", "nature")
                  if k not in named}
        if rolled:
            out["dna"] = dict(named, **rolled)
    if not user["visuals"] and rng.random() < 0.5:
        out["visuals"] = [rng.choice(VISUAL_ROLL)]
    if fam == "shooter" and "symmetry" in free and rng.random() < 0.3:
        out["symmetry"] = rng.choice(("mirror", "none", "turn2"))
    return out
def _family_bounds(fam):
    try:
        import importlib
        mod = importlib.import_module("mapgen.families.%s" % fam)
    except Exception:
        return None
    if not all(hasattr(mod, k) for k in ("family_across", "MIN_ACROSS", "MAX_ACROSS")):
        return None
    return mod.family_across, mod.MIN_ACROSS, mod.MAX_ACROSS
def _size_ok(raw, user, size):
    from . import anchors
    from .brief import across_units
    b = _family_bounds(user["family"])
    if b is not None:
        players = raw.get("players") if isinstance(raw.get("players"), int) else \
            user["players"]
        a = across_units(size, b[0](players))
        if not b[1] <= a <= b[2]:
            return False
    if raw.get("anchors") and _light(raw["anchors"]):
        import json
        key = json.dumps([raw["anchors"], raw.get("players"), raw.get("symmetry"),
                          raw.get("family"), user["family"], size], sort_keys=True, default=str)
        if key not in _SOLVED:
            try:
                _SOLVED[key] = anchors.solve(dict(raw, size=size)) is not None
            except anchors.Refused:
                _SOLVED[key] = False
            except Exception:
                _SOLVED[key] = True
        return _SOLVED[key]
    return True
_SOLVED = {}
LIGHT_INSTANCES = 8
def _light(anchor_list):
    return sum(a.get("count") or 1 for a in anchor_list if isinstance(a, dict)) <= \
        LIGHT_INSTANCES
def feasible_sizes(raw, user):
    return [s for s, _ in SIZES_ROLLED if _size_ok(raw, user, s)]
def _feasible(raw, user, roll, rng, p, banned, notes):
    from . import anchors
    from . import brief as briefmod
    if isinstance(roll.get("size"), str) and not _size_ok(raw, user, roll["size"]):
        ok = [(s, w) for s, w in SIZES_ROLLED if s not in banned.get("size", [])
              and s in briefmod.SIZES and _size_ok(raw, user, s)]
        bad = roll.pop("size")
        if ok:
            roll["size"] = _rare(rng, ok, history.counts("size", user["family"], p))
            notes.append("surprise: size %s does not fit this wish; rolled %s instead"
                         % (bad, roll["size"]))
        else:
            notes.append("surprise: size %s does not fit this wish; kept the size" % bad)
    if roll.get("symmetry") and raw.get("anchors") and _light(raw["anchors"]):
        try:
            ok = anchors.solve(dict(raw, **roll)) is not None
        except anchors.Refused:
            ok = False
        except Exception:
            ok = True
        if not ok:
            notes.append("surprise: symmetry %s does not fit the wish's anchors; left out"
                         % roll.pop("symmetry"))
    return roll
def _proxy(user, roll, formation=None):
    size = roll.get("size", user["size"])
    return {"family": user["family"], "theme": roll.get("theme", user["theme"]),
            "preset": roll.get("preset", user["preset"]),
            "size": size if isinstance(size, str) else "medium",
            "formation": formation or "?", "symmetry": roll.get("symmetry", user["symmetry"]),
            "features": sorted(user["features"]["want"]), "about": ""}
def _skeletons(user, banned):
    if user["family"] != "shooter":
        return []
    from . import variety
    return [s for s in variety._skeletons(user) if s not in banned]
def plan(raw, user, p=None, salt=0):
    P = Plan()
    P.path = p
    fam = user["family"]
    nov = dict(user["novelty"] or {})
    P.mode = nov.get("mode")
    if P.mode == "reject" and salt == 0:
        aspects = list(nov.get("avoid") or []) or ["formation", "theme"]
        got = history.reject(aspects, p, family=fam)
        for a, v in got:
            P.notes.append("rejected: the last %s map's %s %s stays out for the next %d maps"
                           % (fam, a, v, history.REJECT_FOR))
        if not got:
            P.notes.append("rejected: no earlier %s map in the history to differ from" % fam)
    for a in ("formation", "theme", "size", "preset"):
        b = history.banned(fam, a, p)
        if b:
            P.banned[a] = b
    raw = dict(raw)
    raw.pop("novelty", None)
    rng = _rng(user, p, salt)
    roll = {}
    if P.mode == "surprise":
        roll = _feasible(raw, user, _roll(raw, user, rng, p, P.banned), rng, p, P.banned,
                         P.notes)
    elif P.mode in ("novel", "reject"):
        rolls = [_feasible(raw, user, _roll(raw, user, rng, p, P.banned), rng, p, P.banned,
                           []) for _ in range(12)]
        recent = history.recent(fam, 10, p)
        if recent:
            roll = max(rolls, key=lambda r: history.novelty(_proxy(user, r), entries=recent)[0])
        else:
            roll = rolls[0]
        if P.mode == "reject":
            keep = set(nov.get("avoid") or ["formation", "theme"])
            roll = {k: v for k, v in roll.items()
                    if k in keep or (k == "preset" and "preset" in keep)}
    for a in ("theme", "size", "preset"):
        if a in P.banned and a in user.defaulted and roll.get(a) is None:
            if user[a] in P.banned[a]:
                alt = _roll(raw, user, rng, p, P.banned).get(a)
                if alt is not None:
                    roll[a] = alt
    for k, v in roll.items():
        raw[k] = v
    P.rolled = roll
    if roll:
        P.notes.append("%s: rolled %s" % (
            {"surprise": "surprise", "novel": "novelty", "reject": "novelty"}.get(P.mode, "history"),
            ", ".join("%s %s" % (k, v) for k, v in sorted(roll.items()))))
    skels = _skeletons(user, P.banned.get("formation", []))
    if user["family"] == "shooter" and (P.mode or P.banned.get("formation")) and skels:
        counts = history.counts("formation", fam, p)
        order = sorted(skels, key=lambda s: (counts.get(s, 0), rng.random()))
        if P.mode == "surprise":
            rng.shuffle(order)
        P.forces = order
        if P.banned.get("formation"):
            P.notes.append("formation: %s left out (rejected)" % ", ".join(P.banned["formation"]))
    return raw, P
def _entry(c, brief):
    try:
        from . import variety
        desc = variety.arena_descriptors(c.arena)
    except Exception:
        desc = None
    return history.entry_of(c.arena, brief, c.summary(), desc)
def choose(result, brief, P, use_metrics=True):
    good = [c for c in result.candidates if c.ok and not c.meta.get("reference")]
    if not good:
        return result.best
    bans = set(P.banned.get("formation", []))
    allowed = [c for c in good if str(c.summary().get("skeleton")) not in bans]
    if not allowed:
        return None
    best_q = max((c.quality or 0) for c in allowed)
    floor = [c for c in allowed if (c.quality or 0) >= QUALITY_FLOOR * best_q]
    pick = result.best if result.best in floor else max(
        floor, key=lambda c: (c.quality or 0, -c.index))
    if P.mode in ("novel", "reject", "surprise"):
        recent = history.recent(brief["family"], 10, P.path)
        if recent:
            scored = [(history.novelty(_entry(c, brief), entries=recent)[0], c) for c in floor]
            d, pick = max(scored, key=lambda t: (t[0], t[1].quality or 0, -t[1].index))
            P.notes.append("novelty: candidate %d kept, %.2f from the nearest recent map "
                           "(%d recent %s maps)" % (pick.index, d, len(recent), brief["family"]))
    else:
        recent = history.recent(brief["family"], 10, P.path) if P.path else []
        near = [c for c in floor if (c.quality or 0) >= NEAR_BEST * best_q]
        if recent and len(near) > 1:
            scored = [(history.novelty(_entry(c, brief), entries=recent)[0], c) for c in near]
            d0 = history.novelty(_entry(pick, brief), entries=recent)[0]
            d, far = max(scored, key=lambda t: (round(t[0], 3), t[1].quality or 0,
                                                 -t[1].index))
            if far is not pick and d > d0 + 0.02:
                P.notes.append("variety: candidate %d kept (%.0f%% of the best's quality), "
                               "%.2f from the recent maps against the best's %.2f"
                               % (far.index, 100 * (far.quality or 0) / max(1e-9, best_q),
                                  d, d0))
                pick = far
    if pick is not result.best:
        result.best = pick
        if use_metrics:
            try:
                from . import generate as gen
                gen.report_wish_fit(result.brief, pick)
            except Exception:
                pass
    return pick
