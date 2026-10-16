from .engine import CRITIC_LABELS
GOOD = 0.8
FAIR = 0.5
ADVICE = {
    "emptiness": "Add something to do or look at in the empty ground (a rise, cover, an object)",
    "mud": "Spread the props out - too many stand in one spot",
    "overlaps": "Two pieces share space - pull them apart or delete one",
    "floating": "An object stands on nothing - set it down on a floor",
    "monotony": "One texture everywhere - paint some pieces another one (P)",
    "composition": "Give each part of the map something to look at (a landmark, a tower)",
    "reach": "Some pickups are out of reach - add a ramp or stairs up to them",
    "grounding": "A big block hangs in the air - the report card's Fix it puts it on posts",
    "liminal": "Empty and samey, like a dream maze - add a landmark, mix textures, light and "
               "dark (the report card's Fix it helps)",
    "mode_fit": "A game mode you picked misses something - the report card's Game modes "
                "group places it",
    "world_edge": "Something is too far out - the game cannot go past 32,000 from the "
                  "middle. The report card's Fix it moves it inside",
}
class Row:
    def __init__(self, key, label, score, note, where=()):
        self.key = key
        self.label = label
        self.score = score
        self.note = note
        self.where = list(where)
    @property
    def state(self):
        return "ok" if self.score >= GOOD else "warn" if self.score >= FAIR else "bad"
    def text(self):
        return "%s: %s" % (self.label, self.note)
    def __repr__(self):
        return "<Row %s %.2f>" % (self.key, self.score)
def judge(layout, brief=None):
    from mapgen import critic
    if not layout.get("pieces"):
        return None
    arena = dict(layout)
    arena.setdefault("key", "generated")
    family = (brief or {}).get("family") or arena.get("family")
    from .engine import picked_modes
    cr = critic.judge(arena, family, modes=picked_modes(layout, brief) or None)
    rows = []
    for key, r in cr["rows"].items():
        label = CRITIC_LABELS.get(key, key.capitalize())
        rows.append(Row(key, label, float(r["score"]), str(r.get("note", "")),
                        r.get("where") or ()))
    return {"score": cr["score"], "pass": cr["pass"], "line": cr["line"], "rows": rows,
            "worst": cr["worst"], "warnings": list(cr.get("warnings") or [])}
def row(res, key):
    for r in (res or {}).get("rows") or []:
        if r.key == key:
            return r
    return None
def issue(res, key, doc=None):
    from studio.toolbox.issues import Issue
    r = row(res, key)
    if r is None:
        return None
    points = []
    for w in r.where[:12]:
        x, z = w[0], w[1]
        y = 0
        if doc is not None:
            y = ground_at(doc, x, z)
        points.append((x, y, z))
    text = "Critic - %s. %s" % (r.text(), ADVICE.get(key, ""))
    return Issue("ok" if r.state == "ok" else "warn" if r.state == "warn" else "fail", "critic",
                 text.strip(), points=points, data={"critic": key})
def ground_at(doc, x, z):
    from . import geometry as geo
    top = 0
    for p in doc.pieces():
        b = geo.aabb(p)
        if b[0] <= x <= b[1] and b[4] <= z <= b[5]:
            top = max(top, b[3])
    return top
def summary(res):
    if res is None:
        return "Critic: nothing to judge yet - place some pieces"
    worst = row(res, res["worst"])
    out = "Critic %.0f/100 (%s, the line is %d) - weakest: %s" % (
        res["score"], "passes" if res["pass"] else "below the line", res["line"],
        worst.text() if worst else "-")
    for w in res.get("warnings") or []:
        out += "\n" + w
    return out
