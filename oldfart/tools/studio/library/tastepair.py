LINE = "Pick the map you like more - the generator learns your taste."
HELP = (
    "Two maps of your wish, the two the generator itself likes best. Pick the one you like "
    "(1 or Left: A, 2 or Right: B), skip a pair you cannot tell apart (S), or say both are "
    "bad (X). Your choices are kept on this computer, for each kind of map. After 50 choices "
    "of one kind the generator builds that kind your way (Preferences > Taste > Use my "
    "taste); 50-150 choices settle it. Reset forgets the choices of one kind.")
KEYS = {"a": ("1", "Left"), "b": ("2", "Right"), "skip": ("S",), "both_bad": ("X",)}
LABELS = {"a": "A is better", "b": "B is better", "skip": "Skip", "both_bad": "Both bad"}
class Session:
    def __init__(self, store):
        self.store = store
        self.pair = None
        self.seed = None
        self.history = []
    def show(self, pair):
        self.pair = pair
        self.seed = pair.seed
    def next_seed(self, base):
        if self.seed is None:
            return base
        return self.seed + 1
    def choose(self, pick):
        if self.pair is None:
            return None
        p = self.pair
        rec = self.store.add(p.family, p.a["rows"], p.b["rows"], pick, qa=p.a["quality"],
                             qb=p.b["quality"], size=p.size,
                             about={"seed": p.seed, "a": p.a["index"], "b": p.b["index"]})
        self.history.append((p.family, pick))
        self.pair = None
        try:
            self.store.save()
        except OSError:
            pass
        return rec
    def family(self):
        if self.pair is not None:
            return self.pair.family
        return self.history[-1][0] if self.history else None
    def lines(self, family=None):
        from mapgen import taste
        fam = family or self.family()
        if fam is None:
            return ["No pair yet: press Next pair (the wish panel's wish, any family)."]
        out = [self.store.status(fam)]
        c = self.store.counts(fam)
        if c["decisive"] >= 10:
            cv = self.store.cv_agreement(fam)
            if cv["n"]:
                out.append("your fitted taste predicts %d of %d choices it never saw (%d%%)"
                           % (cv["agree"], cv["n"], round(100 * cv["rate"])))
        if c["decisive"] >= taste.MIN_CHOICES:
            w = self.store.fitted(fam)
            today = taste.today_weights(fam)
            moved = sorted(((w.get(k, 0) - today[k], k) for k in today), reverse=True)
            ups = ", ".join("%s +%.1f" % (k, d) for d, k in moved[:3] if d > 0.05)
            downs = ", ".join("%s %.1f" % (k, d) for d, k in moved[::-1][:3] if d < -0.05)
            if ups or downs:
                out.append("you weigh more: %s; less: %s" % (ups or "-", downs or "-"))
        if c["decisive"] < taste.ENOUGH:
            out.append("%d of the 50-150 A/B choices a family needs" % c["decisive"])
        return out
    def quality_line(self):
        if self.pair is None:
            return ""
        return "today's score: A %.3f, B %.3f" % (self.pair.a["quality"] or 0,
                                                   self.pair.b["quality"] or 0)
