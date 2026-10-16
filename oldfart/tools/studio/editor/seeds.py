SEED_MAX = 2 ** 31 - 2
KEEP = 40
class SeedBook:
    def __init__(self, state=None):
        self.entries = []
        self.at = -1
        self.locked = False
        self._results = {}
        if state:
            self.restore(state)
    def current(self):
        return self.entries[self.at] if 0 <= self.at < len(self.entries) else None
    def current_seed(self):
        cur = self.current()
        return cur["seed"] if cur else None
    def next_seed(self, rng, asked=None):
        if asked is not None:
            return int(asked)
        if self.locked and self.current_seed() is not None:
            return self.current_seed()
        while True:
            seed = rng.randrange(1, SEED_MAX)
            if seed != self.current_seed():
                return seed
    def lock(self, on=True):
        self.locked = bool(on)
    def record(self, seed, label="Generate", result=None):
        del self.entries[self.at + 1:]
        for k in [k for k in self._results if k > self.at]:
            del self._results[k]
        self.entries.append({"seed": int(seed), "label": label})
        self.at = len(self.entries) - 1
        if result is not None:
            self._results[self.at] = result
        if len(self.entries) > KEEP:
            drop = len(self.entries) - KEEP
            self.entries = self.entries[drop:]
            self.at -= drop
            self._results = {k - drop: v for k, v in self._results.items() if k >= drop}
        return self.current()
    def can_back(self):
        return self.at > 0
    def can_forward(self):
        return self.at < len(self.entries) - 1
    def back(self):
        if not self.can_back():
            return None
        self.at -= 1
        return self.current()
    def forward(self):
        if not self.can_forward():
            return None
        self.at += 1
        return self.current()
    def result(self):
        return self._results.get(self.at)
    def keep(self, result):
        if self.current() is not None:
            self._results[self.at] = result
    def state(self):
        return {"history": [dict(e) for e in self.entries], "at": self.at,
                "locked": self.locked}
    def restore(self, state):
        hist = state.get("history") or []
        self.entries = [{"seed": int(e["seed"]), "label": str(e.get("label", "Generate"))}
                        for e in hist if isinstance(e, dict) and isinstance(e.get("seed"), int)]
        at = state.get("at", len(self.entries) - 1)
        self.at = at if isinstance(at, int) and -1 <= at < len(self.entries) \
            else len(self.entries) - 1
        self.locked = bool(state.get("locked"))
        self._results = {}
    def line(self):
        cur = self.current()
        if cur is None:
            return "no seed yet - Generate rolls one"
        return "seed %d%s  (%d of %d)" % (cur["seed"], ", locked" if self.locked else "",
                                         self.at + 1, len(self.entries))
