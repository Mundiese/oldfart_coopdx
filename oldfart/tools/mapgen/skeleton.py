COMPASS_VEC = {"n": (0, -1), "ne": (1, -1), "e": (1, 0), "se": (1, 1), "s": (0, 1),
               "sw": (-1, 1), "w": (-1, 0), "nw": (-1, -1), "c": (0, 0)}
def compass_of(x, z):
    if abs(x) < 1e-6 and abs(z) < 1e-6:
        return "c"
    best = None
    for name, (vx, vz) in COMPASS_VEC.items():
        if name == "c":
            continue
        n = (vx * vx + vz * vz) ** 0.5
        d = (x * vx + z * vz) / n / ((x * x + z * z) ** 0.5)
        if best is None or d > best[0]:
            best = (d, name)
    return best[1]
def clock_vec(hour):
    import math
    a = math.radians((hour % 12) * 30)
    return (math.sin(a), -math.cos(a))
class Zone:
    def __init__(self, zid, kind, unit, x, z):
        self.id = zid
        self.kind = kind
        self.unit = unit
        self.x, self.z = x, z
        self.compass = compass_of(x, z)
    def __repr__(self):
        return "Zone(%s %s @%s)" % (self.id, self.kind, self.compass)
class Graph:
    def __init__(self):
        self.zones = {}
        self.edges = set()
        self.loops = []
    def add(self, zone):
        self.zones[zone.id] = zone
    def loop(self, ids, label):
        self.loops.append((label, list(ids)))
        for a, b in zip(ids, ids[1:] + ids[:1]):
            self.edges.add(tuple(sorted((a, b))))
    def neighbours(self, zid):
        return sorted(b if a == zid else a for a, b in self.edges if zid in (a, b))
    def degree(self, zid):
        return len(self.neighbours(zid))
    def articulation_points(self):
        ids = sorted(self.zones)
        index, low, out = {}, {}, set()
        counter = [0]
        def visit(v, parent):
            index[v] = low[v] = counter[0]
            counter[0] += 1
            children = 0
            for w in self.neighbours(v):
                if w not in index:
                    children += 1
                    visit(w, v)
                    low[v] = min(low[v], low[w])
                    if parent is not None and low[w] >= index[v]:
                        out.add(v)
                elif w != parent:
                    low[v] = min(low[v], index[w])
            if parent is None and children > 1:
                out.add(v)
        visit(ids[0], None)
        unreached = [i for i in ids if i not in index]
        return sorted(out), unreached
    def faults(self):
        out = []
        cut, unreached = self.articulation_points()
        if unreached:
            out.append("zones not connected: %s" % ", ".join(unreached))
        if cut:
            out.append("zones that are not on a loop: %s" % ", ".join(cut))
        for z in self.zones.values():
            if z.kind == "base" and self.degree(z.id) < 3:
                out.append("%s has %d exits, a base needs 3" % (z.id, self.degree(z.id)))
        return out
def shooter_graph(units, reach):
    I, R = reach
    g = Graph()
    g.add(Zone("centre", "centre", None, 0, 0))
    if units == 4:
        dirs = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        corners = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
        for q in range(4):
            dx, dz = dirs[q]
            g.add(Zone("base%d" % q, "base", q, dx * R, dz * R))
            g.add(Zone("field%d" % q, "field", q, dx * I * 0.6, dz * I * 0.6))
            cx, cz = corners[q]
            g.add(Zone("corner%d" % q, "corner", q, cx * (I - 300), cz * (I - 300)))
        g.loop(["base0", "corner0", "base1", "corner1", "base2", "corner2", "base3", "corner3"],
               "outer ring (flank ramps)")
        g.loop(["field0", "field1", "field2", "field3"], "inner ring (the island)")
        for q in range(4):
            g.loop(["base%d" % q, "field%d" % q, "centre", "field%d" % ((q + 1) % 4),
                    "corner%d" % q], "spoke %d" % q)
    else:
        g.add(Zone("base0", "base", 0, 0, R))
        g.add(Zone("base1", "base", 1, 0, -R))
        g.add(Zone("field0", "field", 0, 0, I * 0.6))
        g.add(Zone("field1", "field", 1, 0, -I * 0.6))
        for zid, x, z in (("corner0a", 1, 1), ("corner0b", -1, 1),
                          ("corner1a", 1, -1), ("corner1b", -1, -1)):
            g.add(Zone(zid, "corner", int(zid[6]), x * (I - 300), z * (I - 300)))
        g.loop(["base0", "corner0a", "field0", "corner0b"], "south loop")
        g.loop(["base1", "corner1a", "field1", "corner1b"], "north loop")
        g.loop(["field0", "corner0a", "corner1a", "field1", "corner1b", "corner0b"],
               "island ring")
        g.loop(["base0", "field0", "centre", "field1", "base1", "corner1a", "corner0a"],
               "spine")
    return g
HOSTS = {
    "tower": ("corner", "centre"), "vantage": ("corner",), "perch": ("corner",),
    "crown": ("centre",), "pit": ("centre",), "plaza": ("centre",), "hill": ("centre",),
    "landmark": ("centre", "corner"), "centre": ("centre",),
    "bridge": ("lane", "centre"), "base": ("base",), "spawns": ("base",), "spawn": ("base",),
    "world_spawn": ("base", "centre", "corner"), "pillar": ("field",), "wall": ("field",),
}
CENTRE_MODULE = {"crown": "crown", "pit": "pit", "plaza": "bandstand", "hill": "bandstand",
                 "bridge": "bridge_cross", "tower": "crown_high", "landmark": "crown",
                 "centre": None}
def anchor_direction(where):
    if "compass" in where:
        return COMPASS_VEC[where["compass"]]
    if "clock" in where:
        return clock_vec(where["clock"])
    if "x" in where:
        return (where["x"], where["z"])
    if where.get("relation") in ("middle", "above") or where.get("relation") is None:
        return (0, 0)
    return None
def solve_anchors(brief, graph):
    plan = {"zones": {}, "world_spawn": None, "asymmetric": False}
    lines = []
    taken = {}
    for a in brief["anchors"]:
        what, where = a["what"], a["where"]
        hosts = HOSTS.get(what)
        if hosts is None:
            lines.append(("refused", a["id"], "%s is not part of a shooter map (family %s); "
                          "milestone 2 brings the other families" % (what, brief["family"])))
            continue
        vec = anchor_direction(where)
        if vec is None:
            lines.append(("not yet", a["id"], "relations (%s) are solved from milestone 2"
                          % where.get("relation") or where.get("on")))
            continue
        if "on" in where:
            lines.append(("not yet", a["id"], "spawns on a feature (%s) come with the spawn "
                          "computation in milestone 2" % where["on"]))
            continue
        cands = []
        for z in graph.zones.values():
            kind = z.kind
            if kind not in hosts and not ("lane" in hosts and kind == "base"):
                continue
            cands.append(z)
        if not cands:
            lines.append(("refused", a["id"], "no zone can hold a %s" % what))
            continue
        target = (vec[0], vec[1])
        centre_wanted = abs(target[0]) < 1e-6 and abs(target[1]) < 1e-6
        def dist(z):
            if centre_wanted:
                return (0 if z.kind == "centre" else 1, abs(z.x) + abs(z.z))
            n = (target[0] ** 2 + target[1] ** 2) ** 0.5
            zn = (z.x ** 2 + z.z ** 2) ** 0.5 or 1
            return (0, -(z.x * target[0] + z.z * target[1]) / n / zn)
        cands.sort(key=lambda z: (dist(z), z.id))
        zone = cands[0]
        if what == "world_spawn":
            plan["world_spawn"] = {"zone": zone.id, "anchor": a["id"]}
            lines.append(("placed", a["id"], "world spawn on %s (%s): the layout is moved so it "
                          "stands at the origin" % (zone.id, zone.compass)))
            continue
        wanted_compass = where.get("compass")
        exact = wanted_compass is None or wanted_compass == zone.compass
        if zone.id in taken and taken[zone.id][1] != what:
            other = taken[zone.id][0]
            if a.get("hard"):
                raise AnchorConflict([other, a["id"]], zone.id)
            lines.append(("refused", a["id"], "%s is already %s's" % (zone.id, other)))
            continue
        taken[zone.id] = (a["id"], what)
        module = what
        if zone.kind == "centre":
            module = CENTRE_MODULE.get(what)
        elif zone.kind == "corner":
            module = "tower" if what in ("tower", "landmark") else "perch"
        elif zone.kind == "base" and what == "bridge":
            module = "bridge"
        entry = {"module": module, "anchor": a["id"], "once": bool(a.get("once"))}
        plan["zones"][zone.id] = entry
        if a.get("once") and zone.kind != "centre":
            plan["asymmetric"] = True
        how = "placed" if exact else "approximated"
        note = "%s on %s (%s)" % (what, zone.id, zone.compass)
        if not exact:
            note += ", the nearest %s to %s" % (zone.kind, wanted_compass)
        if zone.kind != "centre":
            note += "; only there (asymmetric)" if a.get("once") else \
                "; copied to every symmetry unit (say once: true for one)"
        lines.append((how, a["id"], note))
    return plan, lines
class AnchorConflict(ValueError):
    def __init__(self, ids, zone):
        self.ids = ids
        ValueError.__init__(self, "refused: anchors %s both want %s (the smallest conflicting "
                            "set)" % (" and ".join(ids), zone))
