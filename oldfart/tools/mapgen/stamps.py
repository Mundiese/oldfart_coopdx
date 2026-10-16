import json
import os
import random
CELL = 400
LAYER = 200
MAX_LAYERS = 8
VERSION = 1
ACTIVE = None
def path():
    env = os.environ.get("OLDFART_STAMPS")
    if env:
        return None if env.lower() in ("off", "0", "no", "none") else env
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "oldfart-studio", "stamps.json")
def new(name, cells=None, use=True):
    return {"name": name, "cells": dict(cells or {}), "use": use}
def normal(stamp):
    cells = {k: v for k, v in stamp["cells"].items() if v > 0}
    if not cells:
        return dict(stamp, cells={})
    i0 = min(i for i, _ in cells)
    j0 = min(j for _, j in cells)
    return dict(stamp, cells={(i - i0, j - j0): min(MAX_LAYERS, v) for (i, j), v in cells.items()})
def size(stamp):
    cells = stamp["cells"]
    if not cells:
        return (0, 0)
    return (max(i for i, _ in cells) + 1, max(j for _, j in cells) + 1)
def paint(stamp, cell, layers):
    layers = max(0, min(MAX_LAYERS, int(layers)))
    if layers:
        stamp["cells"][tuple(cell)] = layers
    else:
        stamp["cells"].pop(tuple(cell), None)
    return stamp
def capture(pieces, name="captured"):
    tops = {}
    for p in pieces:
        w, d = p.get("w", 0), p.get("d", 0)
        if int(round(p.get("yaw", 0) or 0)) % 180 == 90:
            w, d = d, w
        x0, x1 = p["x"] - w / 2.0, p["x"] + w / 2.0
        z0, z1 = p["z"] - d / 2.0, p["z"] + d / 2.0
        top = p["y"] + p.get("h", 0)
        for i in range(int(x0 // CELL), int(-(-x1 // CELL))):
            for j in range(int(z0 // CELL), int(-(-z1 // CELL))):
                cx, cz = (i + 0.5) * CELL, (j + 0.5) * CELL
                if x0 <= cx <= x1 and z0 <= cz <= z1:
                    tops[(i, j)] = max(tops.get((i, j), top), top)
    if not tops:
        return new(name)
    lo = min(tops.values())
    cells = {c: int(round((t - lo) / LAYER)) for c, t in tops.items()}
    return normal(new(name, cells))
def vary(stamp, rng):
    cells = dict(normal(stamp)["cells"])
    if not cells:
        return dict(stamp, cells={})
    turns = rng.randrange(4)
    for _ in range(turns):
        w = max(i for i, _ in cells) + 1
        cells = {(j, w - 1 - i): v for (i, j), v in cells.items()}
    if rng.random() < 0.5:
        w = max(i for i, _ in cells) + 1
        cells = {(w - 1 - i, j): v for (i, j), v in cells.items()}
    delta = rng.choice((-1, 0, 0, 1))
    cells = {c: max(1, min(MAX_LAYERS, v + delta)) for c, v in cells.items()}
    edge = [c for c in cells if any((c[0] + a, c[1] + b) not in cells
                                    for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for c in edge:
        if cells[c] > 1 and rng.random() < 0.25:
            cells[c] -= 1
    return dict(stamp, cells=cells)
def lay(G, seed, stamps=None, avoid=(), keep=()):
    from . import landform
    stamps = ACTIVE if stamps is None else stamps
    if not stamps or not G:
        return []
    avoid = set(avoid)
    rng = random.Random("stamps:%s" % seed)
    laid = []
    fixed = set(keep)
    for k, stamp in enumerate(s for s in stamps if s.get("use", True)):
        v = vary(stamp, rng)
        if not v["cells"]:
            continue
        w, d = size(v)
        spots = sorted(c for c in G if all((c[0] + i, c[1] + j) in G and
                                           (c[0] + i, c[1] + j) not in avoid and
                                           (c[0] + i, c[1] + j) not in fixed
                                           for (i, j) in v["cells"]))
        if not spots:
            continue
        o = spots[rng.randrange(len(spots))]
        base = G[o]
        cells = []
        for (i, j), h in v["cells"].items():
            c = (o[0] + i, o[1] + j)
            G[c] = max(G[c], base + h)
            cells.append(c)
        fixed |= set(cells)
        laid.append((stamp.get("name", "stamp %d" % (k + 1)), o, cells))
    if laid:
        landform.settle(G, keep=fixed | set(keep), up=True)
    return laid
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
        except (OSError, ValueError):
            return cls([], where)
        items = []
        for s in data.get("stamps") or []:
            items.append({"name": s.get("name", "stamp"), "use": s.get("use", True),
                          "cells": {(int(i), int(j)): int(v) for i, j, v in s.get("cells", [])}})
        return cls(items, where)
    def save(self):
        if self.where is None:
            return None
        os.makedirs(os.path.dirname(self.where) or ".", exist_ok=True)
        out = [{"name": s["name"], "use": s.get("use", True),
                "cells": [[i, j, v] for (i, j), v in sorted(s["cells"].items())]}
               for s in self.items]
        with open(self.where, "w", encoding="utf-8") as fh:
            json.dump({"version": VERSION, "stamps": out}, fh, indent=1)
            fh.write("\n")
        return self.where
    def in_use(self):
        return [s for s in self.items if s.get("use", True) and s["cells"]]
