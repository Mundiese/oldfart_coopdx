from . import kitbridge
HIGHLIGHT_COLOURS = {
    "issue": (0.94, 0.33, 0.31),
    "warning": (0.96, 0.69, 0.25),
    "ok": (0.36, 0.78, 0.47),
    "info": (0.38, 0.62, 0.96),
    "region": (0.62, 0.49, 0.98),
}
MAX_HIGHLIGHT_LAYERS = 6
class Marker:
    __slots__ = ("kind", "x", "y", "z", "yaw", "label", "data")
    def __init__(self, kind, x, y, z, yaw=0.0, label="", data=None):
        self.kind, self.x, self.y, self.z = kind, float(x), float(y), float(z)
        self.yaw, self.label, self.data = float(yaw or 0.0), label, data
    def pos(self):
        return (self.x, self.y, self.z)
    def __repr__(self):
        return "Marker(%s %r at %d,%d,%d)" % (self.kind, self.label, self.x, self.y, self.z)
MARKER_KINDS = ("spawn", "survey", "race", "object", "anchor", "star")
class Preview:
    __slots__ = ("ids", "offset", "quarters", "pivot")
    def __init__(self, ids, offset=(0.0, 0.0, 0.0), quarters=0, pivot=(0.0, 0.0)):
        self.ids = frozenset(ids)
        self.offset = tuple(float(v) for v in offset)
        self.quarters = int(quarters) % 4
        self.pivot = tuple(float(v) for v in pivot)
    def apply(self, piece):
        out = dict(piece)
        px, pz = self.pivot
        for _ in range(self.quarters):
            dx, dz = out["x"] - px, out["z"] - pz
            out["x"], out["z"] = px + dz, pz - dx
            out["yaw"] = (out.get("yaw", 0) + 90) % 360
        out["x"] += self.offset[0]
        out["y"] += self.offset[1]
        out["z"] += self.offset[2]
        return out
class Scene:
    def __init__(self):
        self.pieces = []
        self.markers = []
        self.selection = frozenset()
        self.marker_selection = frozenset()
        self.hover = None
        self.hidden = frozenset()
        self.highlights = {}
        self.ghosts = []
        self.preview = None
        self.meta = {}
        self.version = 0
        self._listeners = []
        self._bounds = None
    def listen(self, fn):
        self._listeners.append(fn)
        return fn
    def unlisten(self, fn):
        if fn in self._listeners:
            self._listeners.remove(fn)
    def _emit(self, event, payload=None):
        self.version += 1
        for fn in list(self._listeners):
            fn(event, payload)
    def set_pieces(self, pieces, keep_selection=False, meta=None):
        self.pieces = [dict(p) for p in pieces]
        self._bounds = None
        if meta is not None:
            self.meta = dict(meta)
        n = len(self.pieces)
        if keep_selection:
            self.selection = frozenset(i for i in self.selection if i < n)
        else:
            self.selection = frozenset()
        self.hidden = frozenset(i for i in self.hidden if i < n) if keep_selection else frozenset()
        self.highlights = {k: (frozenset(i for i in ids if i < n), c)
                           for k, (ids, c) in self.highlights.items()} if keep_selection else {}
        self.hover = None
        self.preview = None
        self._emit("pieces", None)
        self._emit("selection", self.selection)
    def update_pieces(self, changes):
        for i, p in changes.items():
            self.pieces[i] = dict(p)
        self._bounds = None
        self._emit("pieces", frozenset(changes))
    def set_markers(self, markers):
        self.markers = list(markers)
        self._bounds = None
        self.marker_selection = frozenset()
        self._emit("markers")
    def set_selection(self, ids):
        ids = frozenset(i for i in ids if 0 <= i < len(self.pieces))
        if ids != self.selection:
            self.selection = ids
            self._emit("selection", ids)
    def select(self, ids, mode="set"):
        ids = frozenset(ids)
        if mode == "add":
            new = self.selection | ids
        elif mode == "remove":
            new = self.selection - ids
        elif mode == "toggle":
            new = self.selection ^ ids
        else:
            new = ids
        self.set_selection(new)
    def set_marker_selection(self, ids):
        ids = frozenset(i for i in ids if 0 <= i < len(self.markers))
        if ids != self.marker_selection:
            self.marker_selection = ids
            self._emit("marker_selection", ids)
    def set_hover(self, target):
        if target != self.hover:
            self.hover = target
            self._emit("hover", target)
    def set_highlight(self, name, ids, colour=None):
        ids = frozenset(ids)
        if not ids:
            return self.clear_highlight(name)
        if name not in self.highlights and len(self.highlights) >= MAX_HIGHLIGHT_LAYERS:
            raise ValueError("at most %d highlight layers" % MAX_HIGHLIGHT_LAYERS)
        rgb = tuple(colour) if colour else HIGHLIGHT_COLOURS.get(name, HIGHLIGHT_COLOURS["info"])
        self.highlights[name] = (ids, rgb)
        self._emit("highlight", name)
    def clear_highlight(self, name=None):
        if name is None:
            if self.highlights:
                self.highlights = {}
                self._emit("highlight", None)
        elif name in self.highlights:
            del self.highlights[name]
            self._emit("highlight", name)
    def set_hidden(self, ids):
        self.hidden = frozenset(ids)
        self._emit("hidden", self.hidden)
    def set_ghosts(self, pieces):
        self.ghosts = [dict(p) for p in pieces]
        self._emit("ghosts")
    def set_preview(self, preview):
        self.preview = preview
        self._emit("preview")
    def shown_piece(self, i):
        p = self.pieces[i]
        if self.preview is not None and i in self.preview.ids:
            return self.preview.apply(p)
        return p
    def bounds(self, ids=None):
        from . import meshes
        if ids is None and self._bounds is not None:
            return self._bounds
        lo, hi = [1e18] * 3, [-1e18] * 3
        found = False
        chosen = range(len(self.pieces)) if ids is None else ids
        for i in chosen:
            a, b = meshes.world_bounds(self.shown_piece(i))
            for k in range(3):
                lo[k] = min(lo[k], a[k])
                hi[k] = max(hi[k], b[k])
            found = True
        if ids is None:
            for m in self.markers:
                for k, v in enumerate(m.pos()):
                    lo[k] = min(lo[k], v)
                    hi[k] = max(hi[k], v + (160 if k == 1 else 0))
                found = True
        if not found:
            return None
        out = (tuple(lo), tuple(hi))
        if ids is None:
            self._bounds = out
        return out
    def radius(self):
        b = self.bounds()
        if b is None:
            return 5000.0
        lo, hi = b
        return max(2000.0, max(abs(v) for v in lo + hi) * 1.8)
    def selection_pivot(self):
        b = self.bounds(self.selection) if self.selection else None
        if b is None:
            return None
        lo, hi = b
        return ((lo[0] + hi[0]) / 2.0, lo[1], (lo[2] + hi[2]) / 2.0)
    def stats(self):
        kinds, texs = {}, {}
        for p in self.pieces:
            kinds[p["kind"]] = kinds.get(p["kind"], 0) + 1
            texs[p.get("tex", "?")] = texs.get(p.get("tex", "?"), 0) + 1
        return {"pieces": len(self.pieces), "kinds": kinds, "textures": texs,
                "markers": len(self.markers)}
def known_kind(kind):
    return kind in kitbridge.arenas().KINDS
