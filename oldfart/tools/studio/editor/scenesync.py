from . import geometry as geo, ops
from .document import LISTS
MARKER_OF = {"spawn": "spawn", "anchor": "anchor", "object": "object"}
def star_label(st):
    return "star %s: %s" % (st.get("id", "?"), st.get("name") or "(no name)")
def _marker_class():
    from studio.core.scene import Marker
    return Marker
BAKE_KEYS = ("terrain", "ground", "water", "survey")
def region_label(region):
    return "~ %s ~" % region["name"]
class SceneSync:
    def __init__(self, doc, scene, selection, stack=None):
        self.doc = doc
        self.scene = scene
        self.selection = selection
        self.stack = stack
        self.piece_refs = []
        self.piece_index = {}
        self.marker_refs = []
        self._hidden_markers = frozenset()
        self._quiet = 0
        doc.listeners.append(self._doc_changed)
        selection.listeners.append(self._sel_changed)
        scene.listen(self._scene_event)
        self.rebuild()
    def detach(self):
        if self._doc_changed in self.doc.listeners:
            self.doc.listeners.remove(self._doc_changed)
        if self._sel_changed in self.selection.listeners:
            self.selection.listeners.remove(self._sel_changed)
        self.scene.unlisten(self._scene_event)
    def attach(self, doc, stack=None):
        self.detach()
        self.doc = doc
        if stack is not None:
            self.stack = stack
        self.selection.doc = doc
        doc.listeners.append(self._doc_changed)
        self.selection.listeners.append(self._sel_changed)
        self.scene.listen(self._scene_event)
        self.rebuild()
    def meta(self):
        rest = self.doc.rest
        out = {k: rest.get(k) for k in ("name", "key", "family", "level", "look", "budget",
                                        "report", "onlyFor", "generator") if k in rest}
        for k in BAKE_KEYS:
            if k in rest:
                out[k] = rest.get(k)
        if "terrain" in rest:
            for kind, key in LISTS.items():
                if kind != "piece" and self.doc.items.get(kind):
                    out[key] = [item for _, item in self.doc.items[kind]]
        out["source"] = "editor"
        return out
    def markers(self):
        out, refs = self._all_markers()
        from . import groups
        hidden = groups.hidden_refs(self.doc) if (groups.layers(self.doc) or
                                                  self.doc.meta.get("isolated")) else ()
        self._hidden_markers = frozenset(r for r in refs if r is not None and r in hidden)
        if not self._hidden_markers:
            return out, refs
        keep = [n for n, r in enumerate(refs) if r is None or r not in hidden]
        if self.doc.meta.get("isolated"):
            keep = [n for n in keep if refs[n] is not None]
        return [out[n] for n in keep], [refs[n] for n in keep]
    def _all_markers(self):
        Marker = _marker_class()
        out, refs = [], []
        for n, ref in enumerate(self.doc.refs("spawn")):
            s = self.doc.get(ref)
            out.append(Marker("spawn", s.get("x", 0), s.get("y", 0), s.get("z", 0),
                              s.get("yaw", 0), "spawn %d" % (n + 1), ref))
            refs.append(ref)
        for ref in self.doc.refs("anchor"):
            a = self.doc.view_item(ref)
            x, z = geo.point_xz(a)
            pinned = "x" in (a.get("where") or {})
            out.append(Marker("anchor", x, a.get("height", 0) or 0, z, 0,
                              "%s%s" % (a.get("what", "anchor").replace("_", " "),
                                        "" if pinned else " (solved)"), ref))
            refs.append(ref)
        for ref in self.doc.refs("object"):
            o = self.doc.get(ref)
            out.append(Marker("object", o.get("x", 0), o.get("y", 0), o.get("z", 0),
                              o.get("yaw", 0), o.get("key", "object"), ref))
            refs.append(ref)
        for ref in self.doc.refs("mover"):
            m = self.doc.get(ref)
            out.append(Marker("object", m.get("x", 0), m.get("y", 0), m.get("z", 0),
                              m.get("yaw", 0), "%s (path)" % m.get("key", "mover"), ref))
            refs.append(ref)
        for ref in self.doc.refs("star"):
            st = self.doc.get(ref)
            out.append(Marker("star", st.get("x", 0), st.get("y", 0), st.get("z", 0), 0,
                              star_label(st), ref))
            refs.append(ref)
        for reg in self.doc.rest.get("regions") or []:
            if isinstance(reg, dict) and reg.get("name"):
                out.append(Marker("survey", reg.get("x", 0), reg.get("y", 0), reg.get("z", 0), 0,
                                  region_label(reg), None))
                refs.append(None)
        survey = (self.doc.rest.get("survey") or {}).get("points") or []
        skip = self.doc._spawn_copies if self.doc.survey_follows else 0
        for p in survey[skip:]:
            out.append(Marker("survey", p.get("x", 0), p.get("y", 0), p.get("z", 0),
                              p.get("yaw", 0), "survey", None))
            refs.append(None)
        for ref, p in self.doc.spots():
            name = p.get("_name") or "spot"
            if name == "world":
                out.append(Marker("spawn", p.get("x", 0), p.get("y", 0), p.get("z", 0),
                                  p.get("yaw", 0), "world spawn", ref))
            else:
                label = name if "_slot" not in p else "%s %d" % (name, p["_slot"] + 1)
                out.append(Marker("survey", p.get("x", 0), p.get("y", 0), p.get("z", 0),
                                  p.get("yaw", 0), label, ref))
            refs.append(ref)
        return out, refs
    def rebuild(self):
        self.piece_refs = self.doc.refs("piece")
        self.piece_index = {r: i for i, r in enumerate(self.piece_refs)}
        self._quiet += 1
        try:
            self.scene.set_pieces(self.doc.pieces(), keep_selection=False, meta=self.meta())
            markers, self.marker_refs = self.markers()
            self.scene.set_markers(markers)
            self._push_selection()
            self.push_hidden()
        finally:
            self._quiet -= 1
    def push_hidden(self):
        from . import groups
        hidden = groups.hidden_refs(self.doc)
        ids = [self.piece_index[r] for r in hidden if r in self.piece_index]
        if set(ids) != set(getattr(self.scene, "hidden", ())):
            self.scene.set_hidden(ids)
    def _doc_changed(self, what, refs):
        if what == "replace" and refs and all(r[0] == "piece" for r in refs) and \
                all(r in self.piece_index for r in refs):
            self._quiet += 1
            try:
                self.scene.update_pieces({self.piece_index[r]: self.doc.get(r) for r in refs})
            finally:
                self._quiet -= 1
        elif what in ("replace", "insert", "remove") and refs and \
                all(r[0] != "piece" for r in refs):
            self._quiet += 1
            try:
                markers, self.marker_refs = self.markers()
                self.scene.set_markers(markers)
                self._push_selection()
            finally:
                self._quiet -= 1
        elif what == "meta":
            self.push_hidden()
            self._quiet += 1
            try:
                was = (self._hidden_markers, len(self.marker_refs))
                markers, refs = self.markers()
                if (self._hidden_markers, len(refs)) != was or refs != self.marker_refs:
                    self.marker_refs = refs
                    self.scene.set_markers(markers)
                    self._push_selection()
            finally:
                self._quiet -= 1
            return
        elif what == "brief":
            self._quiet += 1
            try:
                markers, self.marker_refs = self.markers()
                self.scene.set_markers(markers)
                self._push_selection()
            finally:
                self._quiet -= 1
        else:
            self.rebuild()
    def _push_selection(self):
        ids = [self.piece_index[r] for r in self.selection.refs if r in self.piece_index]
        self._quiet += 1
        try:
            self.scene.set_selection(ids)
            setter = getattr(self.scene, "set_marker_selection", None)
            if setter is not None:
                marks = [n for n, r in enumerate(self.marker_refs)
                         if r is not None and r in self.selection.refs]
                setter(marks)
        finally:
            self._quiet -= 1
    def _sel_changed(self, refs):
        if not self._quiet:
            self._push_selection()
    def _scene_event(self, event, payload):
        if self._quiet or event not in ("selection", "marker_selection"):
            return
        sc = self.scene
        pieces = [self.piece_refs[i] for i in sorted(sc.selection) if i < len(self.piece_refs)]
        if hasattr(sc, "marker_selection"):
            marks = [self.marker_refs[i] for i in sorted(sc.marker_selection)
                     if i < len(self.marker_refs) and self.marker_refs[i] is not None]
        else:
            before = set(self.selection.of_kind("piece"))
            keep = set(pieces) >= before and bool(before)
            marks = [r for r in self.selection.refs if r[0] != "piece"] if keep else []
        self._quiet += 1
        try:
            self.selection.set(pieces + marks)
        finally:
            self._quiet -= 1
        if list(self.selection.refs) != pieces + marks:
            self._push_selection()
    def ref_of_piece(self, index):
        return self.piece_refs[index] if 0 <= index < len(self.piece_refs) else None
    def ref_of_marker(self, index):
        return self.marker_refs[index] if 0 <= index < len(self.marker_refs) else None
    def commit_transform(self, indices=None, offset=(0, 0, 0), quarters=0, pivot=None,
                         snap_on=True):
        refs = list(self.selection.refs) if indices is None else \
            [self.piece_refs[i] for i in indices if i < len(self.piece_refs)]
        if hasattr(self.scene, "set_preview"):
            self.scene.set_preview(None)
        change = None
        if quarters % 4:
            change = ops.rotate(self.doc, refs, quarters, pivot)
            if change and self.stack is not None:
                self.stack.push(change)
        dx, dy, dz = offset
        if dx or dy or dz:
            mv = ops.move(self.doc, refs, dx, dy, dz, snap_on=snap_on, label="Move (gizmo)")
            if mv and self.stack is not None:
                self.stack.push(mv)
            change = mv or change
        return change
    def show_ghost(self, items):
        self.scene.set_ghosts([i for i in items if not geo.is_point(i)])
    def clear_ghost(self):
        self.scene.set_ghosts([])
    def show_issues(self, faults):
        ids = set()
        for f in faults:
            for i, p in enumerate(self.doc.pieces()):
                tag = "%s %s at (%d, %d, %d)" % (p["kind"], p["tex"], p["x"], p["y"], p["z"])
                if tag in f:
                    ids.add(i)
        if ids:
            self.scene.set_highlight("issue", ids)
        else:
            self.scene.clear_highlight("issue")
        return ids
__all__ = ["SceneSync", "LISTS"]
