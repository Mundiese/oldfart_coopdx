import copy
import json
import os
from . import geometry as geo
from .commands import Change
KINDS = ("piece", "object", "mover")
PARTS = ("whole", "region", "layers", "groups")
class InsertError(ValueError):
    pass
def load(source):
    from .document import Document, DocumentError
    try:
        if str(source) == "playground:":
            from studio.ux import playground
            return playground.document()
        if str(source).startswith("venue:"):
            from mapgen import v1
            return Document({}, v1.venue(source.split(":", 1)[1]))
        if os.path.isdir(source):
            with open(os.path.join(source, "layout.json"), encoding="utf-8") as h:
                layout = json.load(h)
            brief = {}
            bp = os.path.join(source, "brief.json")
            if os.path.exists(bp):
                with open(bp, encoding="utf-8") as h:
                    brief = json.load(h)
            return Document(brief, layout)
        if source.endswith(".json"):
            with open(source, encoding="utf-8") as h:
                return Document({}, json.load(h))
        return Document.load(source)
    except (OSError, ValueError, KeyError, DocumentError) as why:
        raise InsertError("could not read %s: %s" % (os.path.basename(str(source)), why))
def name_of(src, source=""):
    n = (src.rest.get("name") or src.brief.get("name") or "").strip()
    if n and n != "Untitled map":
        return n
    base = os.path.basename(str(source).rstrip("/"))
    return os.path.splitext(base)[0].replace("-", " ").title() or "another map"
def parts(src):
    from . import groups
    whole = sum(len(src.refs(k)) for k in KINDS)
    lays = [(lay["id"], lay.get("name") or lay["id"], len(groups.members(src, lay)))
            for lay in groups.layers(src)]
    gs = [(g["id"], g.get("name") or g["id"], len(groups.all_members(src, g)))
          for g in groups.groups(src) if not g.get("parent")]
    return {"count": whole, "layers": lays, "groups": gs}
def pick(src, part="whole", region=None, layers=(), groups_=(), spawns=False):
    from . import groups
    kinds = KINDS + (("spawn",) if spawns else ())
    every = [r for k in kinds for r in src.refs(k)]
    if part == "whole":
        return every
    if part == "region":
        if not region:
            raise InsertError("draw or type the box to take")
        x0, x1, z0, z1 = (min(region[0], region[1]), max(region[0], region[1]),
                          min(region[2], region[3]), max(region[2], region[3]))
        out = []
        for r in every:
            b = geo.aabb(src.get(r))
            cx, cz = (b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0
            if x0 <= cx <= x1 and z0 <= cz <= z1:
                out.append(r)
        return out
    want = set()
    if part == "layers":
        for lid in layers:
            lay = groups.get_layer(src, lid)
            if lay is not None:
                want.update(groups.members(src, lay))
    elif part == "groups":
        for gid in groups_:
            want.update(groups.all_members(src, groups.get_group(src, gid)))
    else:
        raise InsertError("no part %r" % (part,))
    return [r for r in every if r in want]
def _link_kind(item, kind):
    from studio.toolbox import logic
    if kind == "object" and logic.kind_of(item):
        return int(item.get("link") or 0)
    if kind == "mover" and item.get("trigger") == "wired":
        return int(item.get("link") or 0)
    return None
class Insert:
    def __init__(self, src, part="whole", region=None, layers=(), groups_=(), logic=True,
                 look=False, spawns=False, source=""):
        from . import groups
        self.src = src
        self.name = name_of(src, source)
        self.refs = pick(src, part, region, layers, groups_, spawns)
        if not self.refs:
            raise InsertError("that part of %s holds nothing" % self.name)
        items = [(r[0], copy.deepcopy(src.get(r))) for r in self.refs]
        if not logic:
            from studio.toolbox import logic as lg
            keep = [n for n, (k, i) in enumerate(items) if not (k == "object" and lg.kind_of(i))]
            items = [items[n] for n in keep]
            self.refs = [self.refs[n] for n in keep]
            for k, i in items:
                if k == "mover" and i.get("trigger") == "wired":
                    i["trigger"] = "always"
        b = geo.grid_box([i for _, i in items])
        self.origin = (b[0], b[2], b[4])
        self.items = [(k, geo.cleaned(geo.translated(i, -b[0], -b[2], -b[4]))) for k, i in items]
        self.groups = groups.template(src, self.refs)
        self.wires = self._wires() if logic else []
        self.look = copy.deepcopy(src.rest.get("look")) if look else None
    def _wires(self):
        from studio.toolbox import logic as lg
        links = set(n for k, i in self.items for n in [_link_kind(i, k)] if n)
        out = []
        for w in lg.wires_of(self.src):
            src_ok = w["on"] == "timer" or w["src"] in links
            dst_ok = w["act"] not in lg.NUMBERED or w["dst"] in links
            if src_ok and dst_ok:
                out.append(dict(w))
        return out
    def __len__(self):
        return len(self.items)
    def counts(self):
        out = {}
        for k, _ in self.items:
            out[k] = out.get(k, 0) + 1
        return out
    def renumbered(self, doc):
        from studio.toolbox import logic as lg
        used = lg.used_links(doc)
        mine = sorted(set(n for k, i in self.items for n in [_link_kind(i, k)] if n)
                      | set(w["src"] for w in self.wires if w["on"] != "timer")
                      | set(w["dst"] for w in self.wires if w["act"] in lg.NUMBERED))
        mine = [n for n in mine if n]
        new, taken = {}, set(used)
        for n in mine:
            m = n if n not in taken else next((c for c in range(1, lg.MAX_LINK + 1)
                                               if c not in taken), None)
            if m is None:
                raise InsertError("this map has no free logic numbers left for %s's wires"
                                  % self.name)
            new[n] = m
            taken.add(m)
        items = []
        for k, i in self.items:
            i = dict(i)
            n = _link_kind(i, k)
            if n:
                i["link"] = new.get(n, n)
            items.append((k, i))
        wires = []
        for w in self.wires:
            w = dict(w)
            if w["on"] != "timer":
                w["src"] = new.get(w["src"], w["src"])
            if w["act"] in lg.NUMBERED:
                w["dst"] = new.get(w["dst"], w["dst"])
            wires.append(w)
        return items, wires, new
    def ghost(self, cursor, quarters=0, snap_on=True):
        items = [i for _, i in self.items]
        if quarters % 4:
            items = [geo.turned(i, quarters, geo.centre_of(items)) for i in items]
        return geo.placed_at(items, cursor, snap_on)
    def budget_line(self, doc):
        have = len(doc.refs("piece"))
        add = sum(1 for k, _ in self.items if k == "piece")
        budget = int(doc.rest.get("budget") or 120)
        total = have + add
        return total <= budget, "%d + %d = %d of %d pieces%s" % (
            have, add, total, budget, "" if total <= budget else
            " - over the budget: take a smaller part, or raise the budget in Properties")
    def change(self, doc, cursor, quarters=0, snap_on=True):
        from . import groups, ops
        from studio.toolbox import logic as lg
        items, wires, _ = self.renumbered(doc)
        moved = geo.placed_at([i for _, i in items], cursor, snap_on) if not quarters % 4 else \
            geo.placed_at([geo.turned(i, quarters, geo.centre_of([j for _, j in items]))
                           for _, i in items], cursor, snap_on)
        ch = ops.insert(doc, [(k, m) for (k, _), m in zip(items, moved)],
                        "Insert %s (%d thing%s)" % (self.name, len(moved),
                                                    "" if len(moved) == 1 else "s"))
        ch = ops._with_groups(doc, ch, self.groups)
        new = [s[1] for s in ch.steps if s[0] == "insert"]
        lays = copy.deepcopy(groups.layers(doc))
        lid = groups._new_id(lays, "l")
        colour = groups.COLOURS[(len(lays) + 1) % len(groups.COLOURS)][0]
        lays = [dict(lay, members=[m for m in lay.get("members") or []]) for lay in lays]
        lays.append({"id": lid, "name": "From %s" % self.name, "colour": colour,
                     "hidden": False, "locked": False, "members": [[r[0], r[1]] for r in new]})
        ch.steps.append(("meta", "layers", copy.deepcopy(doc.meta.get("layers")), lays))
        if wires:
            have = lg.wires_of(doc)
            if len(have) + len(wires) > lg.MAX_WIRES:
                raise InsertError("a map holds %d wires at most: this one has %d, %s brings %d"
                                  % (lg.MAX_WIRES, len(have), self.name, len(wires)))
            ch.steps.append(("rest", "wires", copy.deepcopy(doc.rest.get("wires")),
                             have + wires))
        if self.look:
            before = copy.deepcopy(doc.rest.get("look"))
            after = dict(before or {})
            for k in ("sun", "mood", "fog", "weather"):
                if k in self.look:
                    after[k] = copy.deepcopy(self.look[k])
            if after != (before or {}):
                ch.steps.append(("rest", "look", before, after))
        return ch
