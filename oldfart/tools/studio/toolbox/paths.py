import copy
from studio.editor.commands import Change
from mapgen import movers as M
KINDS = {"platform": "slab", "log": "log", "logwide": "logwide", "block": "blk"}
PATH_RGBA = (1.0, 0.82, 0.25, 0.95)
OTHER_RGBA = (1.0, 0.82, 0.25, 0.45)
POINT_RGBA = (1.0, 1.0, 1.0, 1.0)
MOVER_RGBA = (0.3, 0.9, 1.0, 1.0)
FAST_RGBA = (1.0, 0.35, 0.3, 1.0)
class PathError(ValueError):
    pass
def world_points(m):
    return [(m["x"] + p[0], m["y"] + p[1], m["z"] + p[2], p[3], p[4]) for p in m["points"]]
def with_world_points(m, pts):
    out = dict(m)
    x0, y0, z0 = pts[0][0], pts[0][1], pts[0][2]
    out["x"], out["y"], out["z"] = x0, y0, z0
    out["points"] = [[p[0] - x0, p[1] - y0, p[2] - z0, p[3], p[4]] for p in pts]
    return M.normalise(out)
class PathTool:
    def __init__(self, session):
        self.session = session
        self.ref = None
        self.point = 0
        self.listeners = []
    @property
    def doc(self):
        return self.session.doc
    def _said(self, what):
        for fn in list(self.listeners):
            fn(what)
    def mover(self):
        if self.ref is None:
            return None
        m = self.doc.get(self.ref)
        if m is None:
            self.ref, self.point = None, 0
        return m
    def begin(self, ref, point=0):
        if self.doc.get(ref) is None:
            raise PathError("no mover %s" % (ref,))
        self.ref = ref
        self.point = point
        self._said("begin")
    def end(self):
        self.ref, self.point = None, 0
        self._said("end")
    def choose(self, step):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        self.point = (self.point + step) % len(m["points"])
        self._said("choose")
        return self.point
    def _replace(self, label, new):
        old = self.doc.get(self.ref)
        return Change(label, [("replace", self.ref, copy.deepcopy(old), new)], select=[self.ref])
    def place(self, at, kind="platform", tex="stone1", shape=None, length=1200):
        shape = shape or KINDS.get(kind, "slab")
        key = M.platform_key(shape, tex)
        if not M.key_known(key):
            raise PathError("the mod has no %s in %s" % (shape, tex))
        m = M.mover(key, at, [at, (at[0] + length, at[1], at[2])])
        ref = ("mover", self.doc.new_id("mover"))
        self.ref, self.point = ref, 1
        return Change("Place a mover", [("insert", ref, len(self.doc.refs("mover")), m)],
                      select=[ref])
    def add_point(self, world):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        pts = world_points(m)
        if len(pts) >= M.LIMITS["max_points"]:
            raise PathError("a path has %d points at most" % M.LIMITS["max_points"])
        ref_pt = pts[self.point]
        pts.insert(self.point + 1, (world[0], world[1], world[2], ref_pt[3], ref_pt[4]))
        self.point += 1
        return self._replace("Add a path point", with_world_points(m, pts))
    def move_point(self, i, world):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        pts = world_points(m)
        pts[i] = (world[0], world[1], world[2], pts[i][3], pts[i][4])
        if i == 0:
            return self._replace("Move the mover", with_world_points(m, pts))
        return self._replace("Move a path point", with_world_points(m, pts))
    def nudge_point(self, i, offset):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        p = world_points(m)[i]
        return self.move_point(i, (p[0] + offset[0], p[1] + offset[1], p[2] + offset[2]))
    def delete_point(self, i=None):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        i = self.point if i is None else i
        if i == 0:
            raise PathError("the first point is where the mover stands")
        pts = world_points(m)
        if len(pts) <= 2:
            raise PathError("a path needs two points")
        del pts[i]
        if self.point >= i:
            self.point -= 1
        return self._replace("Delete a path point", with_world_points(m, pts))
    def set_point(self, i=None, speed=None, wait=None):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        i = self.point if i is None else i
        new = copy.deepcopy(m)
        if speed is not None:
            new["points"][i][3] = speed
        if wait is not None:
            new["points"][i][4] = wait
        return self._replace("Set a path point", M.normalise(new))
    def set(self, **fields):
        m = self.mover()
        if m is None:
            raise PathError("no path in hand")
        new = copy.deepcopy(m)
        for k, v in fields.items():
            if k not in ("mode", "trigger", "phase", "key", "modes", "yaw"):
                raise PathError("no mover field %r" % k)
            new[k] = v
        if not M.key_known(new["key"]):
            raise PathError("the mod has no %s" % new["key"])
        return self._replace("Set the mover", M.normalise(new))
    def gizmo_pivot(self):
        m = self.mover()
        if m is None:
            return None
        p = world_points(m)[self.point]
        return (p[0], p[1], p[2])
    def positions(self, doc, t):
        out = {}
        for ref in doc.refs("mover"):
            m = doc.get(ref)
            tl = M.timeline(m)
            frame = int(t * M.FPS) + tl["mover"]["phase"]
            if tl["mover"]["trigger"] == "ridden":
                frame = (tl["first_wait"] + int(t * M.FPS)) % max(1, tl["period"])
            dx, dy, dz = M.position(m, frame)
            out[ref] = (m["x"] + dx, m["y"] + dy, m["z"] + dz)
        return out
    def layer(self, doc, t=None):
        from studio.toolbox.overlays import Layer
        L = Layer("paths", "Paths")
        fast = {i["mover"] for i in M.issues({"movers": [doc.get(r) for r in doc.refs("mover")]})
                if i["kind"] == "fast"}
        for k, ref in enumerate(doc.refs("mover")):
            m = doc.get(ref)
            mine = ref == self.ref
            rgba = FAST_RGBA if k in fast else (PATH_RGBA if mine else OTHER_RGBA)
            top = M.SHAPES[M.shape_of(m["key"])][1]
            pts = [(p[0], p[1] + top, p[2]) for p in world_points(m)]
            for a, b in zip(pts, pts[1:]):
                L.line(a, b, rgba, 3.0 if mine else 2.0)
            if m["mode"] == "loop" and len(pts) > 2:
                L.line(pts[-1], pts[0], rgba, 3.0 if mine else 2.0)
            for i, p in enumerate(pts):
                chosen = mine and i == self.point
                L.dot(p, POINT_RGBA if chosen else rgba, 8.0 if chosen else 5.0)
                if mine:
                    sp = m["points"][i][3]
                    L.label(p, "%d  %d/s  %.1fs" % (i + 1, sp, m["points"][i][4] / 10.0))
        if t is not None:
            for ref, (x, y, z) in self.positions(doc, t).items():
                m = doc.get(ref)
                top = M.SHAPES[M.shape_of(m["key"])][1]
                L.dot((x, y + top, z), MOVER_RGBA, 11.0)
        L.legend = [(PATH_RGBA, "a path (the one in hand brighter)"),
                    (FAST_RGBA, "too fast to stand on")]
        if t is not None:
            L.legend.append((MOVER_RGBA, "where each mover is now"))
        return L
def issues(doc):
    from studio.toolbox.issues import Issue
    layout = doc.to_layout(models=False)
    if not layout.get("movers"):
        return []
    refs = doc.refs("mover")
    out = []
    for row in M.issues(layout):
        level = "fail" if row["kind"] in ("crosses", "stranded", "key", "cap") else "warn"
        r = [refs[row["mover"]]] if row["mover"] is not None and row["mover"] < len(refs) else []
        out.append(Issue(level, "movers", row["text"], refs=r,
                         points=[row["at"]] if row["at"] else [],
                         data={"mover": row["kind"]}))
    return out
