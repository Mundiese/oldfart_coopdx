from . import kit, solids as solidsmod, v1
class Result:
    def __init__(self, faults, graph=None):
        self.faults = faults
        self.graph = graph
    @property
    def ok(self):
        return not self.faults
    def __repr__(self):
        return "checks: %s" % ("pass" if self.ok else "; ".join(self.faults))
def is_hand_venue(arena):
    return (arena.get("key") in v1.venue_keys() and "family" not in arena
            and "generator" not in arena)
def venue_overlaps(arena):
    return solidsmod.faults(arena, limit=100)
def run(arena, solids=None):
    m = v1.arenas_module()
    faults = []
    if solids is None:
        solids = True
    have = kit.textures()
    for p in arena["pieces"]:
        for tex in kit.textures_of(p):
            if tex == "invisible":
                continue
            if tex in kit.FORBIDDEN:
                faults.append("%s: the plain Brick block is not used in an arena"
                              % m.piece_name(p))
            elif tex not in have:
                faults.append("%s: no block texture %r" % (m.piece_name(p), tex))
            elif have[tex].get("layered") and p["h"] > kit.TRANSITION_MAX:
                faults.append("%s: a transition block taller than %d (only the top layer "
                              "wears it)" % (m.piece_name(p), kit.TRANSITION_MAX))
        if p["kind"] not in kit.kinds():
            faults.append("%s: no piece kind %r" % (m.piece_name(p), p["kind"]))
    if arena.get("level") not in m.LEVELS:
        return Result(faults + ["no level %r" % arena.get("level")])
    if solids and not faults:
        faults += solidsmod.faults(arena)
    if faults:
        return Result(faults)
    captured = {}
    original = m.walk_graph
    def capture(a):
        captured["graph"] = original(a)
        return captured["graph"]
    m.walk_graph = capture
    try:
        faults += m.check_layout(arena)
    except m.Refused as why:
        faults.append(str(why))
    finally:
        m.walk_graph = original
    if arena.get("movers"):
        from . import movers
        faults += [i["text"] for i in movers.issues(arena)
                   if i["kind"] in ("crosses", "stranded", "key", "cap")]
    if any(str(o.get("key") or "").startswith("cannon") for o in arena.get("objects") or ()):
        from . import cannons
        faults += cannons.faults(arena, captured.get("graph"))
    return Result(faults, captured.get("graph"))
def collision_order():
    m = v1.arenas_module()
    faults = []
    for kind in sorted(m.SOLIDS):
        data = m.build_col(kind)
        name_len = data[1]
        words_at = 2 + name_len + 4
        import struct
        n = struct.unpack("<I", data[2 + name_len:words_at])[0]
        words = struct.unpack("<%dh" % n, data[words_at:words_at + 2 * n])
        nv = words[1]
        verts = [words[2 + 3 * i: 5 + 3 * i] for i in range(nv)]
        at = 2 + 3 * nv
        nt = words[at + 1]
        for t in range(nt):
            a, b, c = words[at + 2 + 3 * t: at + 5 + 3 * t]
            pts = [verts[a], verts[b], verts[c]]
            if list(m.slopes.sort_first(pts)) != pts:
                faults.append("%s collision: triangle %d is not filed by its first vertex"
                              % (kind, t))
    return faults
