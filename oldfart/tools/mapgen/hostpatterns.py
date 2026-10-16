import json
import os
import time
VERSION = 1
KINDS = ("never", "like")
NEAR = 200
TOUCH = 2
ANY = "any"
LIKE_BONUS = 0.01
LIKE_CAP = 5
FIELDS = ("kind", "cls", "fam")
ACTIVE = None
def path():
    env = os.environ.get("OLDFART_PATTERNS")
    if env:
        return None if env.lower() in ("off", "0", "no", "none") else env
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "oldfart-studio", "patterns.json")
def _rect(p):
    w, d = p.get("w", 0), p.get("d", 0)
    if int(round(p.get("yaw", 0) or 0)) % 180 == 90:
        w, d = d, w
    return (p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0)
def side(p):
    from . import contract, kit
    try:
        cls = contract.object_class(p)
    except Exception:
        cls = None
    try:
        fam = contract.family(kit.tex_key(p))
    except Exception:
        fam = None
    return {"kind": p.get("kind"), "cls": cls or "none", "fam": fam or "none"}
def relation(a, b):
    ra, rb = _rect(a), _rect(b)
    ya0, ya1 = a["y"], a["y"] + a.get("h", 0)
    yb0, yb1 = b["y"], b["y"] + b.get("h", 0)
    gx = max(ra[0], rb[0]) - min(ra[1], rb[1])
    gz = max(ra[2], rb[2]) - min(ra[3], rb[3])
    gy = max(ya0, yb0) - min(ya1, yb1)
    if gx < -TOUCH and gz < -TOUCH:
        if abs(yb0 - ya1) <= TOUCH:
            return "on", int(round((yb1 - yb0) / 100.0))
        if abs(ya0 - yb1) <= TOUCH:
            return "under", int(round((ya1 - ya0) / 100.0))
        if gy < -TOUCH:
            return "inside", 0
        return None, 0
    if gy < -TOUCH:
        if (abs(gx) <= TOUCH and gz < -TOUCH) or (abs(gz) <= TOUCH and gx < -TOUCH):
            return "beside", int(round((yb1 - ya1) / 100.0))
        if 0 < max(gx, gz) < NEAR and min(gx, gz) < NEAR:
            return "near", 0
    return None, 0
def pattern(a, b, kind="never", widen=()):
    rel, rise = relation(a, b)
    if rel == "under":
        a, b = b, a
        rel, rise = relation(a, b)
    p = {"kind": kind, "a": side(a), "b": side(b), "rel": rel or "near", "rise": rise,
         "made": time.strftime("%Y-%m-%d")}
    for w in widen:
        if w == "rise":
            p["rise"] = ANY
        elif "." in w:
            s, f = w.split(".", 1)
            if s in ("a", "b") and f in FIELDS:
                p[s][f] = ANY
    return p
def _side_ok(want, got):
    return all(want.get(f, ANY) in (ANY, got.get(f)) for f in FIELDS)
def match(pat, a, b):
    for x, y in ((a, b), (b, a)):
        rel, rise = relation(x, y)
        if rel is None or rel != pat["rel"]:
            continue
        if pat.get("rise", ANY) not in (ANY, rise):
            continue
        if _side_ok(pat["a"], side(x)) and _side_ok(pat["b"], side(y)):
            return True
    return False
def matches(pieces, patterns, kind=None):
    pats = [p for p in patterns or () if kind is None or p.get("kind") == kind]
    if not pats:
        return []
    grid = {}
    for i, p in enumerate(pieces):
        r = _rect(p)
        for gi in range(int((r[0] - NEAR) // 400), int((r[1] + NEAR) // 400) + 1):
            for gj in range(int((r[2] - NEAR) // 400), int((r[3] + NEAR) // 400) + 1):
                grid.setdefault((gi, gj), []).append(i)
    seen = set()
    out = []
    for ids in grid.values():
        for x in range(len(ids)):
            for y in range(x + 1, len(ids)):
                i, j = ids[x], ids[y]
                key = (min(i, j), max(i, j))
                if key in seen:
                    continue
                seen.add(key)
                a, b = pieces[i], pieces[j]
                if relation(a, b)[0] is None:
                    continue
                for pat in pats:
                    if match(pat, a, b):
                        out.append((pat, a, b))
                        break
    return out
def describe(pat):
    def s(x):
        bits = [x.get("fam"), x.get("cls"), x.get("kind")]
        bits = [b for b in bits if b not in (None, ANY, "none")]
        return " ".join(bits).replace("_", " ") or "anything"
    rise = "" if pat.get("rise", ANY) == ANY else " (rise %s00)" % pat["rise"]
    return "%s: %s %s %s%s" % ("Never" if pat["kind"] == "never" else "Like", s(pat["b"]),
                               pat["rel"], s(pat["a"]), rise)
YIELDS = ("tree", "hedge", "bush", "crate", "barrel", "flower", "rock", "dress", "detail")
def yields(p):
    t = str(p.get("tag", "")).lower()
    return any(w in t for w in YIELDS)
def faults(arena, patterns=None):
    pats = ACTIVE if patterns is None else patterns
    texts, gone = [], []
    for pat, a, b in matches(arena.get("pieces") or [], pats, "never"):
        cut = b if yields(b) else a if yields(a) else None
        if cut is not None:
            gone.append(cut)
        texts.append("host never: %s (%s at %d, %d, %d)" % (describe(pat), b.get("tag") or
                                                              b.get("kind"), b["x"], b["y"],
                                                              b["z"]))
    return texts, gone
def likes(arena, patterns=None):
    pats = ACTIVE if patterns is None else patterns
    return len(matches(arena.get("pieces") or [], pats, "like"))
def bonus(arena, patterns=None):
    return LIKE_BONUS * min(LIKE_CAP, likes(arena, patterns))
class Store:
    def __init__(self, items=None, where=None):
        self.items = list(items or [])
        self.where = where
    @classmethod
    def load(cls, where=None):
        where = where or path()
        if where is None:
            return cls([], None)
        try:
            with open(where, encoding="utf-8") as fh:
                data = json.load(fh)
            return cls(data.get("patterns") or [], where)
        except (OSError, ValueError):
            return cls([], where)
    def save(self):
        if self.where is None:
            return None
        os.makedirs(os.path.dirname(self.where) or ".", exist_ok=True)
        with open(self.where, "w", encoding="utf-8") as fh:
            json.dump({"version": VERSION, "patterns": self.items}, fh, indent=1)
            fh.write("\n")
        return self.where
    def add(self, pat):
        for p in self.items:
            if {k: v for k, v in p.items() if k != "made"} == \
                    {k: v for k, v in pat.items() if k != "made"}:
                return False
        self.items.append(pat)
        return True
    def remove(self, index):
        if 0 <= index < len(self.items):
            del self.items[index]
            return True
        return False
    def of(self, kind):
        return [p for p in self.items if p.get("kind") == kind]
