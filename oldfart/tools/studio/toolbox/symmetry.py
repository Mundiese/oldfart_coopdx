import copy
import json
import math
from studio.editor import geometry as geo
from studio.editor.commands import Change
MODES = ("off", "mirror_x", "mirror_z", "mirror_xz", "radial2", "radial3", "radial4",
         "radial6", "radial8")
LABELS = {"off": "Off", "mirror_x": "Mirror left-right (across x)",
          "mirror_z": "Mirror front-back (across z)", "mirror_xz": "Mirror both ways",
          "radial2": "Radial 2", "radial3": "Radial 3 (facings: quarter turns)",
          "radial4": "Radial 4", "radial6": "Radial 6 (facings: quarter turns)",
          "radial8": "Radial 8 (facings: quarter turns)"}
FACING_NOTE = ("Copies go exactly where the angle puts them, but a piece can only face a "
               "quarter turn: each copy faces the nearest one.")
def facing_note(mode):
    if mode.startswith("radial") and (360 // int(mode[len("radial"):])) % 90:
        return FACING_NOTE
    return ""
KINDS = ("piece", "spawn", "object")
TAG = "Symmetry"
def _key(item):
    return json.dumps(geo.cleaned(item), sort_keys=True)
def snap_centre(centre, mode):
    step = 200 if mode.startswith("radial") else 100
    return (geo.snap(centre[0], step), geo.snap(centre[1], step))
def _rotate_free(item, degrees, pivot):
    t = math.radians(degrees)
    c, s = math.cos(t), math.sin(t)
    out = dict(item)
    x, z = geo.point_xz(item)
    rx, rz = x - pivot[0], z - pivot[1]
    nx, nz = rx * c + rz * s, -rx * s + rz * c
    quarters = int(round(degrees / 90.0)) % 4
    if geo.is_anchor(out):
        return geo.cleaned(geo.translated(out, nx + pivot[0] - x, 0, nz + pivot[1] - z))
    out["x"], out["z"] = nx + pivot[0], nz + pivot[1]
    if "yaw" in out or not geo.is_point(out):
        out["yaw"] = (geo.yaw_of(out) + 90 * quarters) % 360
    if geo.is_point(out):
        out["x"], out["z"] = int(round(out["x"])), int(round(out["z"]))
        return geo.cleaned(out)
    b = geo.aabb(out)
    out["x"] += geo.snap(b[0]) - b[0]
    out["z"] += geo.snap(b[4]) - b[4]
    return geo.cleaned(out)
class Symmetry:
    def __init__(self, mode="off", centre=(0, 0)):
        if mode not in MODES:
            raise ValueError("symmetry %r: one of %s" % (mode, ", ".join(MODES)))
        self.mode = mode
        self.centre = snap_centre(centre, mode)
    def __bool__(self):
        return self.mode != "off"
    def __repr__(self):
        return "<Symmetry %s about %s>" % (self.mode, self.centre)
    @property
    def order(self):
        if self.mode == "off":
            return 1
        if self.mode == "mirror_xz":
            return 4
        if self.mode.startswith("mirror"):
            return 2
        return int(self.mode[len("radial"):])
    def transforms(self):
        cx, cz = self.centre
        mx = lambda i: geo.mirrored(i, "x", cx)
        mz = lambda i: geo.mirrored(i, "z", cz)
        if self.mode == "off":
            return []
        if self.mode == "mirror_x":
            return [mx]
        if self.mode == "mirror_z":
            return [mz]
        if self.mode == "mirror_xz":
            return [mx, mz, lambda i: mz(mx(i))]
        n = self.order
        out = []
        for k in range(1, n):
            deg = 360.0 * k / n
            if abs(deg / 90.0 - round(deg / 90.0)) < 1e-9:
                out.append(lambda i, q=int(round(deg / 90.0)): geo.turned(i, q, (cx, cz)))
            else:
                out.append(lambda i, d=deg: _rotate_free(i, d, (cx, cz)))
        return out
    def images(self, item):
        seen = {_key(item)}
        out = []
        for g in self.transforms():
            img = g(dict(item))
            k = _key(img)
            if k in seen:
                continue
            seen.add(k)
            out.append(img)
        return out
    def applies(self, change):
        if not self or not change:
            return False
        if getattr(change, "no_symmetry", False):
            return False
        if not change.hand and not getattr(change, "twins", False):
            return False
        if change.label.startswith(TAG):
            return False
        return any(s[0] in ("insert", "replace", "remove") and s[1][0] in KINDS
                   for s in change.steps)
    def expand(self, doc, change):
        if not self.applies(change):
            return change
        from studio.editor import ops
        own = set(s[1] for s in change.steps if s[0] in ("insert", "replace", "remove"))
        taken = {}
        for ref in own:
            if ref[0] in KINDS:
                taken.setdefault(ref[0], set()).add(ref[1])
        index = {}
        for kind in KINDS:
            table = {}
            for iid, item in doc.items[kind]:
                table.setdefault(_key(item), []).append((kind, iid))
            index[kind] = table
        used = set(own)
        def twin_refs(kind, item):
            out = []
            for img in self.images(item):
                for ref in index[kind].get(_key(img), []):
                    if ref not in used:
                        used.add(ref)
                        out.append((ref, img))
                        break
                else:
                    out.append((None, img))
            return out
        extra = []
        removes = []
        new_items = [_key(s[3]) for s in change.steps
                     if s[0] == "insert" and s[1][0] in KINDS]
        for step in change.steps:
            op = step[0]
            if op not in ("insert", "replace", "remove") or step[1][0] not in KINDS:
                continue
            kind = step[1][0]
            if op == "insert":
                item = step[3]
                for img in self.images(item):
                    k = _key(img)
                    if k in index[kind] or k in new_items:
                        continue
                    new_items.append(k)
                    iid = ops._fresh_id(doc, kind, taken)
                    extra.append(("insert", (kind, iid), None, img))
            elif op == "replace":
                before, after = step[2], step[3]
                gs = self.transforms()
                for g in gs:
                    img_b = g(dict(before))
                    if _key(img_b) == _key(before):
                        continue
                    for ref in index[kind].get(_key(img_b), []):
                        if ref in used:
                            continue
                        used.add(ref)
                        extra.append(("replace", ref, copy.deepcopy(doc.get(ref)),
                                      geo.cleaned(g(dict(after)))))
                        break
            else:
                for ref, _ in twin_refs(kind, step[3]):
                    if ref is not None:
                        removes.append(ref)
        if removes:
            lists = {k: [i for i, _ in doc.items[k]] for k in KINDS}
            for step in change.steps:
                if step[0] == "remove" and step[1][0] in KINDS and step[1][1] in lists[step[1][0]]:
                    lists[step[1][0]].remove(step[1][1])
            for ref in removes:
                ids = lists[ref[0]]
                at = ids.index(ref[1])
                extra.append(("remove", ref, at, copy.deepcopy(doc.get(ref))))
                ids.pop(at)
        if not extra:
            return change
        out = Change(change.label, list(change.steps) + extra, change.merge, change.hand,
                     change.select)
        out.symmetric = len(extra)
        return out
    def axes(self, radius=4000.0):
        cx, cz = self.centre
        r = float(radius)
        if self.mode == "off":
            return []
        out = []
        if self.mode in ("mirror_x", "mirror_xz"):
            out.append(((cx, cz - r), (cx, cz + r)))
        if self.mode in ("mirror_z", "mirror_xz"):
            out.append(((cx - r, cz), (cx + r, cz)))
        if self.mode.startswith("radial"):
            n = self.order
            for k in range(n):
                t = math.radians(360.0 * k / n + 180.0 / n)
                out.append(((cx, cz), (cx + r * math.sin(t), cz - r * math.cos(t))))
        return out
    def state(self):
        return {"mode": self.mode, "centre": list(self.centre)}
    @classmethod
    def from_state(cls, state):
        state = state or {}
        try:
            return cls(state.get("mode", "off"), tuple(state.get("centre") or (0, 0)))
        except ValueError:
            return cls()
def map_centre(doc):
    boxes = [geo.aabb(p) for p in doc.pieces()]
    if not boxes:
        return (0, 0)
    b = geo.union(boxes)
    return ((b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0)
