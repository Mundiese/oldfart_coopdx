from studio.editor import geometry as geo
WARN_SHARE = 0.9
HARD_REACH = ("triple", "kick", "out", "hurts")
class Verdict:
    __slots__ = ("level", "reason", "clash", "reach")
    def __init__(self, level="ok", reason="", clash=(), reach=None):
        self.level, self.reason, self.clash, self.reach = level, reason, list(clash), reach
    @property
    def meaning(self):
        return {"ok": "good", "warn": "warn", "bad": "bad"}[self.level]
    def __bool__(self):
        return self.level != "bad"
    def __repr__(self):
        return "<Verdict %s: %s>" % (self.level, self.reason)
class BoxCache:
    def __init__(self):
        self.rev = None
        self.doc = None
        self.boxes = []
    def get(self, doc):
        if doc is not self.doc or doc.revision != self.rev:
            self.doc, self.rev = doc, doc.revision
            self.boxes = [(r, geo.aabb(doc.get(r))) for r in doc.refs("piece")]
        return self.boxes
_CACHE = BoxCache()
def _name(doc, ref):
    p = doc.get(ref) or {}
    kind = p.get("kind", "piece")
    words = {"box": "a block", "floor": "the floor", "slab": "a slab", "wall": "a wall",
             "ramp": "a ramp", "stairs": "stairs"}
    return words.get(kind, "a %s" % kind)
def clashes(doc, items, cache=None):
    pieces = [geo.aabb(i) for i in items if not geo.is_point(i)]
    if not pieces:
        return []
    out = []
    for ref, b in (cache or _CACHE).get(doc):
        for a in pieces:
            if geo.overlap_volume(a, b) > 0:
                out.append((ref, b[3] - a[2]))
                break
    return out
def budget_of(doc):
    return int(doc.rest.get("budget") or 120)
def verdict(doc, items, reach=None, cache=None):
    items = [i for i in items]
    new = len([i for i in items if not geo.is_point(i)])
    have = len(doc.refs("piece"))
    budget = budget_of(doc)
    if new and have + new > budget:
        return Verdict("bad", "Over the budget (%d + %d > %d) - delete something first, or "
                       "raise the budget in Properties" % (have, new, budget))
    hit = clashes(doc, items, cache)
    if hit:
        ref, lift = hit[0]
        what = _name(doc, ref) if len(hit) == 1 else "%d pieces" % len(hit)
        steps = max(1, int(round(lift / float(geo.YGRID))))
        how = ("aim at its top, or PgUp lifts the work plane" if lift <= 400 else
               "move it, or aim at a free spot")
        return Verdict("bad", "Inside %s (%d step%s down) - %s" % (
            what, steps, "" if steps == 1 else "s", how), [r for r, _ in hit])
    if reach is not None and reach.get("cls") in HARD_REACH and new:
        return Verdict("warn", "Mario can't easily get on top: %s" % reach.get("words"),
                       reach=reach)
    if new and have + new >= WARN_SHARE * budget:
        return Verdict("warn", "Uses %d of the last %d pieces of the budget" % (
            new, budget - have), reach=reach)
    return Verdict("ok", "", reach=reach)
