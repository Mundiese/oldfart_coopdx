import copy
from . import REPO
from mapgen import modeready, modes as modesmod
from mapgen.brief import FAMILY_MODES
from . import ops
ONLY, EXCEPT = "only", "except"
FAMILY_LABEL = {
    "shooter": "Shooter", "objective": "Objective", "knockoff": "Knock-off", "race": "Race",
    "hide": "Hide and seek", "party": "Party", "course": "Obstacle course", "explore": "Explore",
}
FAMILY_WORDS = {
    "shooter": "everybody against everybody",
    "objective": "teams, flags and points to hold",
    "knockoff": "push each other off",
    "race": "a start and a finish",
    "hide": "hide, seek and chase",
    "party": "party games on a plate",
    "course": "jumps to the finish",
}
FAMILY_ORDER = tuple(modesmod.FAMILY)
class Pick:
    def __init__(self, how=ONLY, keys=(), explicit=False):
        self.how = how
        self.keys = list(keys)
        self.explicit = explicit
    def __eq__(self, other):
        return (self.how, self.keys, self.explicit) == (other.how, other.keys, other.explicit)
    def __repr__(self):
        return "Pick(%r, %r, %r)" % (self.how, self.keys, self.explicit)
def family_of(doc):
    return doc.rest.get("family") or doc.brief.get("family") or "shooter"
def defaults(layout, family):
    keys = list(FAMILY_MODES.get(family, []))
    if not layout or not (layout.get("pieces") or layout.get("spawns")):
        return keys
    return modeready.usable(layout, keys)
def current(doc):
    nf = doc.rest.get("notFor")
    if isinstance(nf, list):
        return Pick(EXCEPT, list(nf), True)
    only = doc.rest.get("onlyFor")
    if only is None:
        only = doc.brief.get("modes") or None
    if only is not None:
        return Pick(ONLY, list(only), True)
    return Pick(ONLY, defaults(doc.to_layout(models=False), family_of(doc)), False)
def resolve(pick, layout, family):
    if pick.how == EXCEPT:
        kept = set(pick.keys)
        return [k for k in modeready.shown(layout or {}, family) if k not in kept], \
            list(pick.keys)
    return list(pick.keys), []
def store(doc, how, keys, label=None):
    pick = Pick(how, keys, True)
    only, nf = resolve(pick, doc.to_layout(models=False), family_of(doc))
    steps = []
    if doc.rest.get("onlyFor") != only:
        steps.append(("rest", "onlyFor", copy.deepcopy(doc.rest.get("onlyFor")), list(only)))
    after_nf = list(nf) if how == EXCEPT else None
    if doc.rest.get("notFor") != after_nf:
        steps.append(("rest", "notFor", copy.deepcopy(doc.rest.get("notFor")), after_nf))
    brief = copy.deepcopy(doc.brief)
    brief["modes"] = list(only)
    if isinstance(brief.get("defaulted"), list) and "modes" in brief["defaulted"]:
        brief["defaulted"].remove("modes")
    if brief != doc.brief:
        steps.append(("brief", copy.deepcopy(doc.brief), brief))
    return ops.Change(label or "Game modes: %s" % summary(pick), steps, hand=False)
def name_of(key):
    return modeready.name_of(key)
def summary(pick, limit=4):
    names = [name_of(k) for k in pick.keys]
    more = "" if len(names) <= limit else " and %d more" % (len(names) - limit)
    listed = ", ".join(names[:limit]) + more
    if pick.how == EXCEPT:
        return "every fitting mode except %s" % listed if names else "every fitting mode"
    return listed or "no mode (free roam only)"
def tip(key):
    k = modeready.modeknow.knowledge(key)
    fam = k.get("family")
    lines = ["%s - %s" % (name_of(key), FAMILY_WORDS.get(fam, FAMILY_LABEL.get(fam, "")))]
    named = [modeready.SPOTS[s][0].lower() for s in modeready.survey_keys(key)
             if s in modeready.SPOTS]
    if named:
        lines.append("Needs on the map: %s." % " and ".join(named))
    if modeready.studio_tracks_only(key):
        lines.append("Needs a start gate (a race track built here).")
    rng = modeready.modeknow.size_range(key)
    if rng:
        lines.append("Best size: %s." % (rng[0] if rng[0] == rng[1] else "%s to %s" % rng))
    lines.append("Ticked: the mode's map picker offers this map.")
    return "\n".join(lines)
def groups(layout, family, chosen=(), everything=False, search=""):
    if everything:
        keys = [k for fam in FAMILY_ORDER for k in modesmod.FAMILY[fam]
                if k in modesmod.all() and modeready.venue_ok(k)[0]]
    else:
        keys = modeready.shown(layout or {}, family, chosen)
    words = [w for w in (search or "").lower().split() if w]
    order = [family] + [f for f in FAMILY_ORDER if f != family]
    out = []
    for fam in order:
        got = []
        for k in keys:
            if modesmod.family_of(k) != fam:
                continue
            hay = " ".join((k, name_of(k), FAMILY_LABEL.get(fam, ""))).lower()
            if all(w in hay for w in words):
                got.append(k)
        if got:
            out.append((fam, FAMILY_LABEL.get(fam, fam), got))
    return out
def status(layout, keys, players=16, size=None):
    ready = modeready.readiness(layout or {}, keys, players, size)
    return [(k, name_of(k), ready[k]) for k in keys]
def brief_size(doc):
    return doc.brief.get("size") if doc.brief.get("size") in modeready.TIERS else None
def players_of(doc):
    p = doc.brief.get("players")
    return p if isinstance(p, int) and p > 0 else 16
def spot_change(doc, name):
    at = modeready.default_spot(doc.to_layout(models=False), name)
    label = modeready.SPOTS.get(name, (name, ""))[0]
    return ops.insert(doc, [("spot", dict(at, _name=name))], "Place the %s" % label.lower())
