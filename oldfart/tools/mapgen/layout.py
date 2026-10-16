from . import cells, kit, v1
from .skeleton import Graph
GRID = 200
def q(v, step=GRID):
    return int(round(v / float(step))) * step
UNDER_EYE = 100
def open_map(brief):
    try:
        if brief["verticality"] != "flat":
            return False
        dials = brief.get("dials") or {}
        if "openness" in dials:
            return float(dials["openness"]) >= 0.6
        return brief["density"] == "sparse"
    except (KeyError, TypeError):
        return False
def overlaps(a, b, margin=0):
    return (a[0] - margin < b[1] and b[0] - margin < a[1]
            and a[2] - margin < b[3] and b[2] - margin < a[3])
def grow(rect, m):
    return (rect[0] - m, rect[1] + m, rect[2] - m, rect[3] + m)
def inside(rect, outer, margin=0):
    return (rect[0] >= outer[0] + margin and rect[1] <= outer[1] - margin
            and rect[2] >= outer[2] + margin and rect[3] <= outer[3] - margin)
def rect_of(piece):
    return cells.piece_rect(piece)
def mirrored_x(thing):
    out = dict(thing)
    out["x"] = -out["x"]
    out["yaw"] = (360 - out.get("yaw", 0)) % 360
    return out
def _key(p):
    return tuple(sorted((k, str(v)) for k, v in p.items() if k != "tag"))
class Sym:
    def __init__(self, kind):
        if kind not in ("turn4", "turn2", "mirror", "mirrorx", "mirror2", "none"):
            raise ValueError("no symmetry %r" % kind)
        self.kind = kind
        self.units = {"turn4": 4, "turn2": 2, "mirror": 2, "mirrorx": 2, "mirror2": 4,
                      "none": 1}[kind]
    def copy(self, thing, u, point=False):
        m = v1.arenas_module()
        if self.kind == "turn4":
            return (m.turned_point if point else m.turned)(thing, u)
        if self.kind == "turn2":
            return (m.turned_point if point else m.turned)(thing, 2 * u)
        if self.kind == "mirror":
            return dict(thing) if u == 0 else m.mirrored_z(thing)
        if self.kind == "mirrorx":
            if u == 0:
                return dict(thing)
            turn = m.turned_point if point else m.turned
            return turn(m.mirrored_z(turn(thing, 1)), 3)
        if self.kind == "mirror2":
            t = dict(thing)
            if u & 1:
                t = m.mirrored_z(t)
            if u & 2:
                t = mirrored_x(t)
            return t
        return dict(thing)
    def pieces(self, piece):
        out, seen = [], set()
        for u in range(self.units):
            c = self.copy(piece, u)
            k = _key(c)
            if k not in seen:
                seen.add(k)
                out.append(c)
        return out
    def points(self, spot):
        out, seen = [], set()
        for u in range(self.units):
            c = self.copy(spot, u, point=True)
            k = (round(c["x"]), round(c.get("y", 0)), round(c["z"]))
            if k not in seen:
                seen.add(k)
                out.append(c)
        return out
    def rects(self, rect):
        dummy = kit.kind("box").make("tile1", rect[0], rect[1], 0, 1, rect[2], rect[3])
        out = []
        for p in self.pieces(dummy):
            r = rect_of(p)
            if r not in out:
                out.append(r)
        return out
    def order(self):
        return {4: (0, 2, 1, 3), 2: (0, 1), 1: (0,)}[self.units]
class Layout:
    def __init__(self, brief, streams, dice, sym, pal, family="shooter"):
        self.brief = brief
        self.streams = streams
        self.dice = dice
        self.sym = sym
        self.pal = pal
        self.family = family
        self.structure = []
        self.carves = []
        self.top = []
        self.fill = []
        self.fill_groups = []
        self.dress = []
        self.shields = []
        self.keeps = []
        self.floors = []
        self.bases = []
        self.spots = []
        self.edges_open = []
        self.graph = Graph()
        self.modules = {}
        self.params = {}
        self.notes = []
        self.anchor_lines = []
        self.landmark = None
        self.world_spawn = None
        self.solid = brief["level"] == "empty"
        self.spawns = []
        self.base_points = []
        self.field = []
        self.report = {}
    def _add(self, piece, copy, where):
        if not copy:
            out = [piece]
        else:
            out = []
            seen = set()
            side = (str(piece.get("tag", "")).startswith("base") and
                    str(piece.get("tag", "")).endswith(".floor") and
                    piece["tex"] == self.pal.get("accents", [None])[0])
            for u in range(self.sym.units):
                c = self.sym.copy(piece, u)
                if side:
                    acc = [t for t in self.pal["accents"]
                           if t not in (self.pal.get("floor"), self.pal.get("deck"))] \
                        or [piece["tex"]]
                    c["tex"] = acc[u % len(acc)]
                    c["tag"] = "base%d.floor" % u
                k = _key(c)
                if k not in seen:
                    seen.add(k)
                    out.append(c)
        where.extend(out)
        return out
    def box(self, role, x0, x1, y0, y1, z0, z1, tag, tex=None, copy=True, late=False):
        if x1 <= x0 or z1 <= z0 or y1 <= y0:
            return []
        p = kit.kind("box").make(tex or self.pal[role], x0, x1, y0, y1, z0, z1, None, tag)
        return self._add(p, copy, self.top if late else self.structure)
    def ramp(self, role, x0, x1, y0, y1, z0, z1, rises, tag, tex=None, copy=True, late=False,
             stairs=None):
        if x1 <= x0 or z1 <= z0 or y1 <= y0:
            return []
        if stairs is None:
            stairs = self.params.get("stairs", False)
        kind = "stairs" if stairs else "ramp"
        p = kit.kind(kind).make(tex or self.pal[role], x0, x1, y0, y1, z0, z1, rises, tag)
        return self._add(p, copy, self.top if late else self.structure)
    def slab(self, rect, y, role, tag, thick=None, tex=None, copy=True, zone="field",
             fill=True, late=False):
        x0, x1, z0, z1 = rect
        if self.solid and y > 0:
            bottom = 0
        else:
            bottom = y - (thick or 200)
        out = self.box(role, x0, x1, bottom, y, z0, z1, tag, tex=tex, copy=copy, late=late)
        self.floor(rect, y, zone, fill, copy=True)
        return out
    def floor(self, rect, y, zone="field", fill=True, copy=True):
        self.floors.append({"rect": tuple(rect), "y": y, "zone": zone, "fill": fill,
                            "copy": copy})
    def keep(self, rect, copy=True):
        rs = self.sym.rects(rect) if copy else [tuple(rect)]
        self.keeps.extend(rs)
        return rs
    def opening(self, rect, copy=True):
        rs = self.sym.rects(rect) if copy else [tuple(rect)]
        self.edges_open.extend(rs)
        return rs
    def base(self, bid, rect, y, facing, tex=None):
        self.bases.append({"id": bid, "rect": tuple(rect), "y": y, "facing": facing,
                           "tex": tex})
        self.keep(grow(rect, 0))
    def spot(self, x, y, z, yaw=0, why=""):
        self.spots.append({"x": x, "y": y, "z": z, "yaw": yaw, "why": why})
    def carve(self, x0, x1, y0, y1, z0, z1):
        self.carves.append((x0, x1, y0, y1, z0, z1))
    def note(self, text):
        self.notes.append(text)
    def all_pieces(self):
        return self.structure + self.top + self.fill + self.shields + self.dress
    def bounds(self):
        rs = [rect_of(p) for p in self.structure + self.top]
        return (min(r[0] for r in rs), max(r[1] for r in rs),
                min(r[2] for r in rs), max(r[3] for r in rs))
def compile_pieces(L):
    xs, zs = [], []
    for p in L.top:
        r = rect_of(p)
        xs += [r[0], r[1]]
        zs += [r[2], r[3]]
    grid = cells.CellGrid.from_pieces(L.structure, xs, zs)
    for (x0, x1, y0, y1, z0, z1) in L.carves:
        grid.carve(x0, x1, z0, z1, y0, y1)
    for p in L.top:
        grid.add_piece(p)
    merged = split_layered(grid.to_pieces())
    extra = []
    for group in (L.shields, L.fill, L.dress):
        if group:
            g = cells.CellGrid.from_pieces(group)
            extra += split_layered(g.to_pieces())
    return merged + extra
def split_layered(pieces):
    out = []
    for p in pieces:
        if p["kind"] == "box" and kit.layered(p["tex"]) and p["h"] > kit.TRANSITION_MAX:
            top = p["y"] + p["h"]
            base = dict(p, h=p["h"] - kit.TRANSITION_MAX,
                        tex=kit.TRANSITION_BASE.get(p["tex"], p["tex"]))
            cap = dict(p, y=top - kit.TRANSITION_MAX, h=kit.TRANSITION_MAX)
            out += [base, cap]
        else:
            out.append(p)
    return out
def polish(arena, brief, streams, sym="none", pal=None, fill_on=True, dress_on=True,
           landmark=None, dice_=None):
    from . import beauty, fill, dice as dicemod
    if pal is None:
        pal, _ = beauty.palette(brief["theme"], brief["palette"])
    d = dice_ if dice_ is not None else dicemod.roll(brief, streams("style"))
    L = Layout(brief, streams, d, Sym(sym), pal, family=brief["family"])
    pieces = [dict(p) for p in arena["pieces"]]
    L.structure = pieces
    L.fixed_count = len(pieces) + len(arena.get("markers", []) or [])
    L.parapets = False
    tops = [(rect_of(p), p["y"] + p["h"]) for p in pieces]
    support = []
    for p in pieces:
        if p["kind"] != "box":
            continue
        r = rect_of(p)
        top = p["y"] + p["h"]
        support.append((r, top))
        if r[1] - r[0] < 600 or r[3] - r[2] < 600:
            continue
        covered = any(q is not p and t > top and overlaps(rr, r) and q2_y(q) < top + 900
                      for (rr, t), q in zip(tops, pieces))
        L.floors.append({"rect": r, "y": top, "bottom": p["y"], "zone": "field", "fill": not covered,
                         "copy": False})
    L.support = support
    L.arena_spawns = [dict(s) for s in arena.get("spawns", [])]
    L.clear = []
    for s in arena.get("spawns", []):
        rr = (s["x"] - 600, s["x"] + 600, s["z"] - 600, s["z"] + 600)
        L.keeps.append(rr)
        L.clear.append(rr)
    survey = arena.get("survey", {}) or {}
    for key, pts in survey.items():
        if isinstance(pts, list):
            for s in pts:
                if isinstance(s, dict) and "x" in s:
                    L.keeps.append((s["x"] - 400, s["x"] + 400, s["z"] - 400, s["z"] + 400))
    for mk in arena.get("markers", []) or []:
        if isinstance(mk, dict) and "x" in mk:
            L.keeps.append((mk["x"] - 600, mk["x"] + 600, mk["z"] - 600, mk["z"] + 600))
    for p in pieces:
        if p["kind"] != "box":
            L.keeps.append(grow(rect_of(p), 400))
    L.landmark = landmark
    report = {}
    if fill_on:
        fill.run(L)
        report["fill"] = L.report.get("fill")
    if dress_on:
        beauty.dress(L)
        from . import kitpass
        kitpass.run(L)
        beauty.scenery(L)
        report["beauty"] = L.report.get("beauty")
        report["kit"] = L.report.get("kit")
    out = dict(arena)
    extra = []
    for group in (L.fill, L.dress):
        if group:
            g = cells.CellGrid.from_pieces(group)
            extra += split_layered(g.to_pieces())
    m = v1.arenas_module()
    base = [dict(p) for p in L.structure]
    for p in extra + base:
        p["model"] = m.model_name(p)
    out["pieces"] = base + extra
    report["added"] = len(extra)
    report["style"] = d.as_dict()
    return out, report
def q2_y(p):
    return p["y"]
def module_pieces(pieces):
    out = {}
    for p in pieces:
        mod = str(p.get("tag", "")).split(".")[0]
        out.setdefault(mod, []).append(tuple(sorted((k, str(v)) for k, v in p.items()
                                                    if k != "tag")))
    return {k: sorted(v) for k, v in out.items()}
def summit_rule(L):
    if L.params.get("centre") != "summit":
        return 0
    if not any(a["what"] == "hill" for a in L.brief["anchors"]):
        return 0
    top = L.params.get("Dh") or 0
    half = L.params.get("I") or 0
    if top <= 0 or half <= 0:
        return 0
    cap = top + 50
    summit = (-half, half, -half, half)
    touched = 0
    for group in (L.fill, L.dress, L.shields):
        keep = []
        for p in group:
            r = rect_of(p)
            spire = str(p.get("tag", "")).startswith("centre.") and r[0] >= summit[0] \
                and r[1] <= summit[1] and r[2] >= summit[2] and r[3] <= summit[3]
            if spire or p["y"] + p["h"] <= cap:
                keep.append(p)
                continue
            touched += 1
            if p["kind"] == "box" and cap - p["y"] >= 100:
                q2 = dict(p)
                q2["h"] = (cap - p["y"]) // 50 * 50
                keep.append(q2)
        group[:] = keep
    if touched:
        L.notes.append("hill in the middle: %d piece(s) off the summit lowered or left out so "
                       "the summit (%d) stays the highest floor" % (touched, top))
    return touched
def finish(L, reference=False):
    from . import beauty, fill, spawns
    m = v1.arenas_module()
    if not reference:
        fill.run(L)
    spawns.place_bases(L)
    if not reference:
        beauty.dress(L)
        from . import kitpass
        kitpass.run(L)
        beauty.scenery(L)
        summit_rule(L)
    mods = module_pieces(L.structure + L.top + L.fill + L.dress + L.shields)
    mods.setdefault("carves", []).extend("carve %s" % (c,) for c in L.carves)
    pieces = compile_pieces(L)
    order = [dict(s) for s in L.spawns]
    arena = {"key": L.brief["key"] or "generated", "level": L.brief["level"],
             "budget": L.brief["budget"], "pieces": pieces, "spawns": order,
             "survey": {}, "look": kit.look(L.brief["theme"], L.brief["sky"], L.brief["music"],
                                             L.streams("light"), L.brief.get("family"))}
    dx = dz = 0
    if L.world_spawn:
        dx, dz = -int(L.world_spawn[0]), -int(L.world_spawn[1])
    lift = 10 if L.brief["level"] == "empty" else 0
    if dx or dz or lift:
        for p in arena["pieces"]:
            p["x"] += dx
            p["z"] += dz
            p["y"] += lift
        for s in order:
            s["x"] += dx
            s["z"] += dz
            s["y"] += lift
    for p in arena["pieces"]:
        p["model"] = m.model_name(p)
    shift = (dx, lift, dz)
    field = spawns.choose_field(L, arena, shift)
    arena["survey"] = {"points": order + field}
    P = L.params
    meta = {"params": P, "units": L.sym.units, "symmetry": L.sym.kind, "modules": L.modules,
            "anchors": L.anchor_lines, "notes": L.notes, "graph_faults": L.graph.faults(),
            "graph": {"zones": sorted(L.graph.zones), "loops": L.graph.loops},
            "centre": (dx, dz), "field_spots": len(field), "cover": len(L.fill),
            "module_pieces": mods, "skeleton": P.get("skeleton"),
            "bases": [[(x + dx, y + lift, z + dz) for (x, y, z) in grp] for grp in L.base_points],
            "style": L.dice.as_dict() if L.dice is not None else None,
            "beauty": L.report.get("beauty"), "fill": L.report.get("fill"),
            "kit": L.report.get("kit"),
            "spawn_report": L.report.get("spawns")}
    return arena, meta
