SORTS = (("quality", "best quality"), ("verticality", "most vertical"),
         ("openness", "most open"), ("path_redundancy", "most loops"),
         ("pieces", "fewest pieces"), ("fails", "fewest fails"))
class Cell:
    def __init__(self, gen, index):
        self.gen = gen
        self.index = index
        self.quality = getattr(gen, "quality", None)
        self.desc = dict(getattr(gen, "desc", {}) or {})
        self.card = None
        self.gate = None
        self.pinned = False
    @classmethod
    def of(cls, gen, index=0):
        return cls(gen, index)
    def score(self, measured):
        self.card = measured.get("card")
        self.gate = list(measured.get("gate") or [])
        if self.card:
            if self.card.get("quality") is not None:
                self.quality = self.card["quality"]
            for k, v in (self.card.get("descriptors") or {}).items():
                if v is not None:
                    self.desc.setdefault(k, v)
        return self
    def counts(self):
        return dict((self.card or {}).get("counts") or {})
    def pieces(self):
        cost = (self.card or {}).get("cost") or {}
        return cost.get("pieces", len((self.gen.layout or {}).get("pieces", [])))
    def value(self, key):
        if key == "quality":
            return self.quality if self.quality is not None else -1
        if key == "pieces":
            return -self.pieces()
        if key == "fails":
            return -self.counts().get("fail", 99)
        return self.desc.get(key, -1) if self.desc.get(key) is not None else -1
    def summary(self):
        parts = ["#%d" % (self.index + 1)]
        if self.quality is not None:
            parts.append("quality %.2f" % self.quality)
        c = self.counts()
        if c:
            parts.append("%d pass, %d fail" % (c.get("pass", 0), c.get("fail", 0)))
        if self.gate:
            parts.append("GATE: %d" % len(self.gate))
        return "  ".join(parts)
    def details(self):
        lines = [self.summary()]
        for k in ("verticality", "openness", "path_redundancy", "density", "pace"):
            if self.desc.get(k) is not None:
                lines.append("%s %.2f" % (k.replace("_", " "), self.desc[k]))
        lines.append("%d pieces" % self.pieces())
        for m in ((self.card or {}).get("missed_targets") or [])[:4]:
            lines.append("misses: %s (%s, wants %s)" % (m.get("label"), _fmt(m.get("value")),
                                                         m.get("band")))
        for f in (self.gate or [])[:3]:
            lines.append("gate: %s" % f)
        return "\n".join(lines)
def _fmt(v):
    if isinstance(v, float):
        return "%.2f" % v
    if isinstance(v, list):
        return "-".join(_fmt(x) for x in v)
    return str(v)
class Grid:
    def __init__(self, cells=None):
        self.cells = list(cells or [])
        for i, c in enumerate(self.cells):
            c.index = i
        self.order = "quality"
    def sort(self, key):
        self.order = key
        self.cells.sort(key=lambda c: (not c.pinned, -c.value(key), c.index))
        return self.cells
    def best(self):
        ok = [c for c in self.cells if not c.gate]
        pool = ok or self.cells
        return max(pool, key=lambda c: c.value("quality")) if pool else None
    def spread(self):
        out = {}
        for k in ("verticality", "openness", "path_redundancy"):
            vals = [c.desc[k] for c in self.cells if c.desc.get(k) is not None]
            if vals:
                out[k] = (min(vals), max(vals))
        return out
    def columns(self, width, cell=196):
        return max(1, width // cell)
