from . import geometry as geo
MODES = ("replace", "add", "remove", "toggle")
MATCHES = ("texture", "kind", "height")
class Selection:
    def __init__(self, doc=None):
        self.doc = doc
        self.refs = []
        self.listeners = []
        self.filter = None
    def _tell(self):
        for fn in list(self.listeners):
            fn(list(self.refs))
    def __contains__(self, ref):
        return ref in self.refs
    def __len__(self):
        return len(self.refs)
    def __iter__(self):
        return iter(list(self.refs))
    def set(self, refs):
        new = []
        if self.filter is not None:
            refs = self.filter([tuple(r) for r in refs])
        for r in refs:
            r = tuple(r)
            if r not in new:
                new.append(r)
        if new != self.refs:
            self.refs = new
            self._tell()
    def combine(self, refs, mode="replace"):
        refs = [tuple(r) for r in refs]
        if mode == "replace":
            self.set(refs)
        elif mode == "add":
            self.set(self.refs + refs)
        elif mode == "remove":
            self.set([r for r in self.refs if r not in refs])
        elif mode == "toggle":
            keep = [r for r in self.refs if r not in refs]
            self.set(keep + [r for r in refs if r not in self.refs])
        else:
            raise ValueError("mode %r is not one of %s" % (mode, ", ".join(MODES)))
    def click(self, ref, mode="replace"):
        if ref is None:
            if mode == "replace":
                self.set([])
            return
        self.combine([ref], mode)
    def clear(self):
        self.set([])
    def refilter(self):
        self.set(list(self.refs))
    def prune(self):
        if self.doc is not None:
            self.set([r for r in self.refs if r in self.doc])
    def of_kind(self, kind):
        return [r for r in self.refs if r[0] == kind]
def all_refs(doc, kinds=None):
    return [r for r in doc.refs() if kinds is None or r[0] in kinds]
def inverted(doc, refs, kinds=None):
    have = set(refs)
    return [r for r in all_refs(doc, kinds) if r not in have]
def box_select(doc, view, rect, contain=False, depth=None, kinds=None, hidden=()):
    out = []
    for ref in all_refs(doc, kinds):
        if ref in hidden:
            continue
        item = doc.view_item(ref)
        box = geo.aabb(item)
        if depth is not None:
            lo, hi = geo.depth_range(box, view)
            if hi < min(depth) or lo > max(depth):
                continue
        if geo.rect_hits(rect, geo.projected(box, view), contain):
            out.append(ref)
    return out
def screen_box_select(doc, project, rect, contain=False, kinds=None):
    out = []
    for ref in all_refs(doc, kinds):
        b = geo.aabb(doc.view_item(ref))
        pts = []
        for x in (b[0], b[1]):
            for y in (b[2], b[3]):
                for z in (b[4], b[5]):
                    p = project((x, y, z))
                    if p is not None:
                        pts.append(p)
        if len(pts) < 8:
            continue
        box = (min(p[0] for p in pts), max(p[0] for p in pts),
               min(p[1] for p in pts), max(p[1] for p in pts))
        if geo.rect_hits(rect, box, contain):
            out.append(ref)
    return out
def _key(piece, match):
    out = []
    if "texture" in match:
        out.append(piece.get("tex"))
        out.append(piece.get("tex_top"))
    if "kind" in match:
        out.append(piece.get("kind"))
    if "height" in match:
        out.append(round(piece.get("y", 0) + piece.get("h", 0)))
    return tuple(out)
def magic_select(doc, seed, match=("texture",), connected=True, gap=0.5):
    match = tuple(match)
    for m in match:
        if m not in MATCHES:
            raise ValueError("match %r is not one of %s" % (m, ", ".join(MATCHES)))
    first = doc.get(seed)
    if first is None or seed[0] != "piece":
        return [seed] if first is not None else []
    want = _key(first, match)
    pieces = [(r, doc.get(r)) for r in doc.refs("piece")]
    like = [(r, p, geo.aabb(p)) for r, p in pieces if _key(p, match) == want]
    if not connected:
        return [r for r, _, _ in like]
    boxes = {r: b for r, _, b in like}
    seen = [seed]
    todo = [seed]
    while todo:
        cur = todo.pop()
        b = boxes[cur]
        for r, _, other in like:
            if r not in boxes or r in seen:
                continue
            if geo.touching(b, other, gap):
                seen.append(r)
                todo.append(r)
    order = {r: n for n, (r, _, _) in enumerate(like)}
    return sorted(seen, key=lambda r: order.get(r, 0))
def info(doc, refs):
    items = [doc.view_item(r) for r in refs if r in doc]
    if not items:
        return {"count": 0}
    b = geo.union(geo.aabb(i) for i in items)
    across = max(b[1] - b[0], b[5] - b[4])
    per_tex = {}
    per_kind = {}
    for r, i in zip(refs, items):
        per_kind[r[0]] = per_kind.get(r[0], 0) + 1
        if r[0] == "piece":
            per_tex[i.get("tex")] = per_tex.get(i.get("tex"), 0) + 1
    return {"count": len(items), "kinds": per_kind, "textures": per_tex,
            "size": (b[1] - b[0], b[3] - b[2], b[5] - b[4]),
            "cells": (round((b[1] - b[0]) / geo.GRID), round((b[5] - b[4]) / geo.GRID)),
            "seconds": round(geo.mario_seconds(across), 1), "box": b}
