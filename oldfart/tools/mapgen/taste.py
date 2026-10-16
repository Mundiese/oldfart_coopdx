import json
import math
import os
import time
MIN_CHOICES = 50
ENOUGH = 150
PRIOR = 0.5
SCALE = 2.0
STEPS = 800
RATE = 1.0
PICKS = ("a", "b", "skip", "both_bad")
VERSION = 1
def path():
    env = os.environ.get("OLDFART_TASTE")
    if env:
        return None if env.lower() in ("off", "0", "no", "none") else env
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "oldfart-studio", "taste.json")
def features(rows):
    out = {}
    for k, row in (rows or {}).items():
        c = row.get("closeness") if isinstance(row, dict) else None
        if c is None or (isinstance(row, dict) and row.get("warn_only")):
            continue
        out[k] = float(c)
    return out
def today_weights(family, size=None):
    from .metrics import targets
    return {k: float(b.weight) for k, b in targets.bands(family, size).items()
            if not b.warn_only}
def taste_quality(feats, weights):
    num = den = 0.0
    for k, c in feats.items():
        w = weights.get(k)
        if w is None:
            continue
        num += w * c
        den += w
    return num / den if den else None
def _sig(x):
    if x >= 0:
        return 1.0 / (1.0 + math.exp(-x))
    e = math.exp(x)
    return e / (1.0 + e)
def fit(choices, prior):
    keys = sorted(prior)
    if not keys:
        return {}
    mean = sum(prior.values()) / float(len(prior))
    p0 = [SCALE * prior[k] / mean for k in keys]
    data = []
    for c in choices:
        if c.get("pick") not in ("a", "b"):
            continue
        a, b = c.get("a") or {}, c.get("b") or {}
        d = [(a.get(k, 0.0) - b.get(k, 0.0)) if (k in a and k in b) else 0.0 for k in keys]
        y = 1.0 if c["pick"] == "a" else -1.0
        data.append((d, y))
    beta = list(p0)
    if not data:
        return dict(prior)
    n = float(len(data))
    try:
        beta = _ascend_numpy(data, p0)
    except ImportError:
        beta = _ascend(data, p0, n)
    total = sum(beta) or 1.0
    want = sum(prior.values())
    return {k: round(b * want / total, 4) for k, b in zip(keys, beta)}
def _ascend_numpy(data, p0):
    import numpy as np
    D = np.array([d for d, _ in data], dtype=float)
    y = np.array([y for _, y in data], dtype=float)
    p = np.array(p0, dtype=float)
    beta = p.copy()
    n = float(len(data))
    for step in range(STEPS):
        s = D @ beta
        g = ((y * (1.0 - 1.0 / (1.0 + np.exp(-np.clip(y * s, -50, 50))))) @ D) / n
        g -= PRIOR * (beta - p) / n
        lr = RATE * SCALE / (1.0 + step / 100.0)
        beta = np.maximum(0.0, beta + lr * g)
    return [float(b) for b in beta]
def _ascend(data, p0, n):
    beta = list(p0)
    for step in range(STEPS):
        grad = [-PRIOR * (beta[i] - p0[i]) / n for i in range(len(p0))]
        for d, y in data:
            s = sum(bi * di for bi, di in zip(beta, d))
            g = y * (1.0 - _sig(y * s)) / n
            for i, di in enumerate(d):
                if di:
                    grad[i] += g * di
        lr = RATE * SCALE / (1.0 + step / 100.0)
        beta = [max(0.0, bi + lr * gi) for bi, gi in zip(beta, grad)]
    return beta
def agrees(choice, weights):
    if choice.get("pick") not in ("a", "b"):
        return None
    qa = taste_quality(choice.get("a") or {}, weights)
    qb = taste_quality(choice.get("b") or {}, weights)
    if qa is None or qb is None or abs(qa - qb) < 1e-12:
        return None
    return (qa > qb) == (choice["pick"] == "a")
class Taste:
    def __init__(self, data=None, file=None):
        self.data = data or {"version": VERSION, "families": {}}
        self.file = file
    @classmethod
    def load(cls, file=None):
        f = file if file is not None else path()
        if f and os.path.exists(f):
            try:
                with open(f, encoding="utf-8") as h:
                    data = json.load(h)
                if isinstance(data, dict) and isinstance(data.get("families"), dict):
                    return cls(data, f)
            except (OSError, ValueError):
                pass
        return cls(None, f)
    def save(self):
        if not self.file:
            return None
        os.makedirs(os.path.dirname(os.path.abspath(self.file)), exist_ok=True)
        tmp = self.file + ".tmp"
        with open(tmp, "w", encoding="utf-8") as h:
            json.dump(self.data, h, indent=1, sort_keys=True)
        os.replace(tmp, self.file)
        return self.file
    def family(self, fam):
        return self.data["families"].setdefault(fam, {"choices": [], "use": True,
                                                       "fitted": None})
    def add(self, fam, rows_a, rows_b, pick, qa=None, qb=None, size=None, about=None):
        if pick not in PICKS:
            raise ValueError("a choice is one of %s" % ", ".join(PICKS))
        rec = {"pick": pick, "a": features(rows_a) if _rows(rows_a) else dict(rows_a or {}),
               "b": features(rows_b) if _rows(rows_b) else dict(rows_b or {}),
               "qa": qa, "qb": qb, "size": size, "t": int(time.time())}
        if about:
            rec["about"] = about
        f = self.family(fam)
        f["choices"].append(rec)
        f["fitted"] = None
        return rec
    def counts(self, fam):
        cs = self.family(fam)["choices"]
        out = {p: sum(1 for c in cs if c.get("pick") == p) for p in PICKS}
        out["decisive"] = out["a"] + out["b"]
        out["total"] = len(cs)
        return out
    def agreement(self, fam, weights=None):
        w = weights or today_weights(fam)
        verdicts = [agrees(c, w) for c in self.family(fam)["choices"]]
        n = sum(1 for v in verdicts if v is not None)
        agree = sum(1 for v in verdicts if v)
        return {"agree": agree, "n": n, "rate": round(agree / float(n), 3) if n else None}
    def fitted(self, fam):
        f = self.family(fam)
        if f.get("fitted") is None:
            f["fitted"] = fit(f["choices"], today_weights(fam))
        return f["fitted"]
    def cv_agreement(self, fam, folds=5):
        cs = [c for c in self.family(fam)["choices"] if c.get("pick") in ("a", "b")]
        if len(cs) < folds:
            return {"agree": 0, "n": 0, "rate": None}
        prior = today_weights(fam)
        agree = n = 0
        for k in range(folds):
            train = [c for i, c in enumerate(cs) if i % folds != k]
            test = [c for i, c in enumerate(cs) if i % folds == k]
            w = fit(train, prior)
            for c in test:
                v = agrees(c, w)
                if v is not None:
                    n += 1
                    agree += 1 if v else 0
        return {"agree": agree, "n": n, "rate": round(agree / float(n), 3) if n else None}
    def active(self, fam):
        f = self.family(fam)
        return bool(f.get("use", True)) and self.counts(fam)["decisive"] >= MIN_CHOICES
    def weights(self, fam):
        return self.fitted(fam) if self.active(fam) else None
    def set_use(self, fam, on):
        self.family(fam)["use"] = bool(on)
    def reset(self, fam):
        self.data["families"][fam] = {"choices": [], "use": True, "fitted": None}
    def status(self, fam):
        c = self.counts(fam)
        ag = self.agreement(fam)
        line = "%s: %d choices (%d A/B, %d skipped, %d both bad)" % (
            fam, c["total"], c["decisive"], c["skip"], c["both_bad"])
        if ag["n"]:
            line += "; today's score agrees with you on %d of %d (%d%%)" % (
                ag["agree"], ag["n"], round(100 * ag["rate"]))
        if c["decisive"] < MIN_CHOICES:
            line += "; your taste counts from %d A/B choices (%d to go)" % (
                MIN_CHOICES, MIN_CHOICES - c["decisive"])
        elif not self.family(fam).get("use", True):
            line += "; your taste is switched off"
        else:
            line += "; your taste is used when generating"
        return line
def _rows(x):
    return isinstance(x, dict) and any(isinstance(v, dict) for v in x.values())
def apply(score, family, taste):
    if not score or taste is None:
        return score
    w = taste.weights(family)
    if not w:
        return score
    q = taste_quality(features(score.get("rows") or {}), w)
    if q is None:
        return score
    score["quality_today"] = score.get("quality")
    score["quality"] = round(q, 4)
    score["taste"] = {"choices": taste.counts(family)["decisive"]}
    return score
