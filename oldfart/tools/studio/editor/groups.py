import copy
from .commands import Change, refusal
COLOURS = (("grey", (150, 150, 150)), ("red", (224, 80, 80)), ("orange", (232, 150, 60)),
           ("yellow", (226, 204, 70)), ("green", (96, 190, 110)), ("teal", (70, 186, 180)),
           ("blue", (80, 140, 230)), ("purple", (160, 110, 220)), ("pink", (226, 120, 180)))
COLOUR = dict(COLOURS)
def _key(ref):
    return [ref[0], ref[1]]
def _ref(member):
    return (member[0], member[1])
def groups(doc):
    return [g for g in (doc.meta.get("groups") or []) if isinstance(g, dict)]
def layers(doc):
    return [l for l in (doc.meta.get("layers") or []) if isinstance(l, dict)]
def members(doc, entry):
    return [_ref(m) for m in entry.get("members") or [] if _ref(m) in doc]
def group_of(doc, ref):
    for g in groups(doc):
        if list(ref) in [list(m) for m in g.get("members") or []]:
            return g
    return None
def layer_of(doc, ref):
    for l in layers(doc):
        if list(ref) in [list(m) for m in l.get("members") or []]:
            return l
    return None
def get_layer(doc, lid):
    for l in layers(doc):
        if l.get("id") == lid:
            return l
    return None
def get_group(doc, gid):
    for g in groups(doc):
        if g.get("id") == gid:
            return g
    return None
def layer_words(name):
    name = name or ""
    return name if name.lower().startswith("layer") else "layer %s" % name
def _new_id(entries, prefix):
    have = set(e.get("id") for e in entries)
    n = 1
    while "%s%d" % (prefix, n) in have:
        n += 1
    return "%s%d" % (prefix, n)
def _meta_change(doc, label, key, after, select=None):
    before = copy.deepcopy(doc.meta.get(key))
    after = copy.deepcopy(after) if after else None
    if before == after or (not before and not after):
        return Change(label)
    return Change(label, [("meta", key, before, after)], select=select)
def _without(entries, refs):
    drop = set(tuple(r) for r in refs)
    out = []
    for e in entries:
        e = copy.deepcopy(e)
        e["members"] = [m for m in e.get("members") or [] if _ref(m) not in drop]
        out.append(e)
    return out
def parent_of(doc, g):
    pid = g.get("parent") if g else None
    return get_group(doc, pid) if pid else None
def children(doc, g):
    gid = g.get("id")
    return [c for c in groups(doc) if c.get("parent") == gid]
def all_members(doc, g, _seen=None):
    seen = _seen if _seen is not None else set()
    if g is None or g.get("id") in seen:
        return []
    seen.add(g.get("id"))
    out = members(doc, g)
    for c in children(doc, g):
        out += [m for m in all_members(doc, c, seen) if m not in out]
    return out
def ancestors(doc, g):
    out = []
    while g is not None and g.get("id") not in [a.get("id") for a in out]:
        out.append(g)
        g = parent_of(doc, g)
    return out
def depth(doc, g):
    return len(ancestors(doc, g)) - 1
def level_group(doc, ref, focus=None):
    g = group_of(doc, ref)
    if g is None:
        return None
    chain = ancestors(doc, g)
    if focus:
        ids = [a.get("id") for a in chain]
        if focus in ids:
            k = ids.index(focus)
            return chain[k - 1] if k > 0 else None
    return chain[-1]
def _tidy(entries):
    out = [copy.deepcopy(e) for e in entries]
    ids = set(e.get("id") for e in out)
    for e in out:
        if e.get("parent") not in ids:
            e.pop("parent", None)
    while True:
        kids = {}
        for e in out:
            if e.get("parent"):
                kids[e["parent"]] = kids.get(e["parent"], 0) + 1
        weak = next((e for e in out
                     if len(e.get("members") or []) + kids.get(e.get("id"), 0) < 2), None)
        if weak is None:
            return out
        up = weak.get("parent")
        out = [e for e in out if e is not weak]
        for e in out:
            if e.get("parent") == weak.get("id"):
                if up:
                    e["parent"] = up
                else:
                    e.pop("parent", None)
            if up and e.get("id") == up:
                e["members"] = list(e.get("members") or []) + list(weak.get("members") or [])
def group(doc, refs, name=None, focus=None):
    refs = [tuple(r) for r in refs if tuple(r) in doc]
    units, loose = [], []
    for r in refs:
        top = level_group(doc, r, focus)
        if top is not None and set(all_members(doc, top)) <= set(refs):
            if top.get("id") not in [u.get("id") for u in units]:
                units.append(top)
        else:
            loose.append(r)
    if len(units) + len(loose) < 2:
        return refusal("Group: select two or more things first" if len(refs) < 2 else
                       "Group: this is one group already - select more to group it with")
    rest = _without(groups(doc), loose)
    gid = _new_id(groups(doc), "g")
    name = (name or "").strip() or "Group %s" % gid[1:]
    entry = {"id": gid, "name": name, "members": [_key(r) for r in loose]}
    if focus and get_group(doc, focus) is not None:
        entry["parent"] = focus
    unit_ids = set(u.get("id") for u in units)
    for e in rest:
        if e.get("id") in unit_ids:
            e["parent"] = gid
    rest.append(entry)
    rest = _tidy(rest)
    what = "%d item%s" % (len(refs), "" if len(refs) == 1 else "s")
    if units:
        what += " (%d group%s inside)" % (len(units), "" if len(units) == 1 else "s")
    return _meta_change(doc, "Group %s as %s" % (what, name), "groups", rest, select=refs)
def ungroup(doc, refs, focus=None):
    hit = []
    for r in refs:
        g = level_group(doc, r, focus)
        if g is not None and g.get("id") not in [h.get("id") for h in hit]:
            hit.append(g)
    if not hit:
        return refusal("Ungroup: nothing selected is in a group")
    drop = set(h.get("id") for h in hit)
    rest = [g for g in copy.deepcopy(groups(doc)) if g.get("id") not in drop]
    for h in hit:
        up = h.get("parent")
        for g in rest:
            if g.get("parent") == h.get("id"):
                if up:
                    g["parent"] = up
                else:
                    g.pop("parent", None)
            if up and g.get("id") == up:
                g["members"] = list(g.get("members") or []) + list(h.get("members") or [])
    rest = _tidy(rest)
    n = len(hit)
    return _meta_change(doc, "Ungroup %d group%s" % (n, "" if n == 1 else "s"), "groups", rest,
                        select=list(refs))
def rename_group(doc, gid, name):
    name = (name or "").strip()
    out = copy.deepcopy(groups(doc))
    for g in out:
        if g.get("id") == gid and name and g.get("name") != name:
            g["name"] = name
            return _meta_change(doc, "Rename group to %s" % name, "groups", out)
    return Change("Rename group")
def expand(doc, refs, focus=None):
    out = []
    for r in refs:
        r = tuple(r)
        g = level_group(doc, r, focus)
        for m in (all_members(doc, g) if g is not None else [r]):
            if m not in out:
                out.append(m)
    return out
def template(doc, refs):
    index = {tuple(r): n for n, r in enumerate(refs)}
    out = []
    for g in groups(doc):
        ms = [index[_ref(m)] for m in g.get("members") or [] if _ref(m) in index]
        out.append({"id": g.get("id"), "name": g.get("name"), "parent": g.get("parent"),
                    "members": ms})
    return [{"key": e["id"], "name": e.get("name"), "parent": e.get("parent"),
             "members": list(e["members"])} for e in _tidy(out)]
def copies_steps(doc, patterns):
    patterns = [(pat, refs) for pat, refs in patterns if pat]
    if not patterns:
        return []
    now = copy.deepcopy(groups(doc))
    taken = list(now)
    for pat, refs in patterns:
        ids = {}
        for e in pat:
            gid = _new_id(taken, "g")
            ids[e["key"]] = gid
            taken.append({"id": gid})
        for e in pat:
            entry = {"id": ids[e["key"]], "name": e.get("name") or "Group",
                     "members": [_key(refs[i]) for i in e["members"] if i < len(refs)]}
            if e.get("parent") in ids:
                entry["parent"] = ids[e["parent"]]
            now.append(entry)
    after = _tidy(now)
    before = copy.deepcopy(doc.meta.get("groups"))
    if after == (before or []):
        return []
    return [("meta", "groups", before, after)]
def new_layer(doc, name=None, refs=(), colour=None):
    refs = [tuple(r) for r in refs if tuple(r) in doc]
    out = _without(layers(doc), refs)
    lid = _new_id(out, "l")
    if colour not in COLOUR:
        colour = COLOURS[(len(out) + 1) % len(COLOURS)][0]
    name = (name or "").strip() or "Layer %s" % lid[1:]
    out.append({"id": lid, "name": name, "colour": colour, "hidden": False, "locked": False,
                "members": [_key(r) for r in refs]})
    label = "New %s" % layer_words(name) + (" with %d item%s" % (len(refs), "" if len(refs) == 1
                                                        else "s") if refs else "")
    return _meta_change(doc, label, "layers", out)
def assign(doc, lid, refs):
    refs = [tuple(r) for r in refs if tuple(r) in doc]
    if not refs:
        return refusal("Move to layer: select something first")
    out = _without(layers(doc), refs)
    name = "no layer"
    if lid is not None:
        for l in out:
            if l.get("id") == lid:
                l["members"] += [_key(r) for r in refs]
                name = l.get("name")
                break
        else:
            return refusal("Move to layer: no layer %s" % lid)
    return _meta_change(doc, "Move %d item%s to %s" % (len(refs), "" if len(refs) == 1 else "s",
                                                     name), "layers", out, select=refs)
def set_layer(doc, lid, **fields):
    out = copy.deepcopy(layers(doc))
    for l in out:
        if l.get("id") != lid:
            continue
        words = []
        for k, v in fields.items():
            if k == "name":
                v = (v or "").strip()
                if not v:
                    continue
            if k == "colour" and v not in COLOUR:
                raise ValueError("not a colour tag: %r" % (v,))
            if k in ("hidden", "locked"):
                v = bool(v)
            if l.get(k) != v:
                l[k] = v
                words.append({"hidden": "hide" if v else "show",
                              "locked": "lock" if v else "unlock"}.get(k, "%s %s" % (k, v)))
        if not words:
            return Change("Layer")
        what = layer_words(l.get("name"))
        return _meta_change(doc, "%s%s: %s" % (what[:1].upper(), what[1:], ", ".join(words)),
                            "layers",
                            out)
    return refusal("No layer %s" % lid)
def delete_layer(doc, lid):
    out = [l for l in layers(doc) if l.get("id") != lid]
    if len(out) == len(layers(doc)):
        return refusal("No layer %s" % lid)
    ch = _meta_change(doc, "Delete %s" % layer_words(get_layer(doc, lid).get("name")), "layers",
                      out)
    if doc.meta.get("isolated") == lid:
        ch.steps.append(("meta", "isolated", lid, None))
    return ch
def isolate(doc, lid):
    now = doc.meta.get("isolated")
    after = None if (lid is None or now == lid) else lid
    if after is not None and get_layer(doc, after) is None:
        return refusal("No layer %s" % lid)
    if after == now:
        return Change("Isolate")
    label = "Show every layer" if after is None else \
        "Isolate %s" % layer_words(get_layer(doc, after).get("name"))
    return Change(label, [("meta", "isolated", now, after)])
def hide_selection(doc, refs):
    refs = [tuple(r) for r in refs if tuple(r) in doc]
    if not refs:
        return refusal("Hide: select something first")
    found = next((l for l in layers(doc) if l.get("name") == "Hidden"), None)
    out = _without(layers(doc), refs)
    if found is None:
        lid = _new_id(out, "l")
        out.append({"id": lid, "name": "Hidden", "colour": "grey", "hidden": True,
                    "locked": False, "members": [_key(r) for r in refs]})
    else:
        for l in out:
            if l["id"] == found["id"]:
                l["members"] += [_key(r) for r in refs]
                l["hidden"] = True
    return _meta_change(doc, "Hide %d item%s (layer Hidden)" % (len(refs), "" if len(refs) == 1
                                                                 else "s"), "layers", out,
                        select=[])
def show_all(doc):
    out = copy.deepcopy(layers(doc))
    for l in out:
        l["hidden"] = False
    ch = _meta_change(doc, "Show everything", "layers", out)
    if doc.meta.get("isolated"):
        ch.steps.append(("meta", "isolated", doc.meta.get("isolated"), None))
    return ch
def hidden_refs(doc):
    iso = doc.meta.get("isolated")
    out = set()
    if iso and get_layer(doc, iso) is not None:
        keep = set(members(doc, get_layer(doc, iso)))
        return set(r for r in doc.refs() if r not in keep)
    for l in layers(doc):
        if l.get("hidden"):
            out.update(members(doc, l))
    return out
def hidden_points(doc):
    from . import geometry as geo
    out = []
    for r in hidden_refs(doc):
        if r[0] == "piece":
            continue
        item = doc.view_item(r)
        if item is not None:
            out.append(tuple(geo.point_xz(item)))
    return out
def locked_refs(doc):
    out = set()
    for l in layers(doc):
        if l.get("locked"):
            out.update(members(doc, l))
    return out
_FROZEN = {}
def frozen_refs(doc):
    if not layers(doc) and not doc.meta.get("isolated"):
        return frozenset()
    key = (id(doc), getattr(doc, "revision", None), repr(doc.meta.get("layers")),
           doc.meta.get("isolated"))
    got = _FROZEN.get(id(doc))
    if got is None or got[0] != key:
        got = (key, frozenset(locked_refs(doc) | hidden_refs(doc)))
        _FROZEN.clear()
        _FROZEN[id(doc)] = got
    return got[1]
def editable(doc, refs):
    frozen = frozen_refs(doc)
    return [r for r in refs if tuple(r) not in frozen] if frozen else list(refs)
def guard_locked(doc, change):
    locked = locked_refs(doc) if layers(doc) else ()
    if not locked:
        return None
    hit = []
    for step in change.steps:
        if step[0] in ("replace", "remove") and tuple(step[1]) in locked:
            hit.append(tuple(step[1]))
    if not hit:
        return None
    lay = layer_of(doc, hit[0])
    name = layer_words(lay.get("name")) if lay else "a locked layer"
    return refusal("Locked: %s would change %d thing%s on %s - unlock it in the Outliner "
                   "or press Alt+L" % (change.label, len(hit), "" if len(hit) == 1 else "s",
                                       name))
def select_filter(doc, refs, whole_groups=True, focus=None):
    if whole_groups and groups(doc):
        refs = expand(doc, refs, focus)
    if not layers(doc):
        return list(refs)
    skip = hidden_refs(doc) | locked_refs(doc)
    return [r for r in refs if tuple(r) not in skip]
def prune_steps(doc, removed):
    removed = set(tuple(r) for r in removed)
    steps = []
    gs = groups(doc)
    if gs and any(_ref(m) in removed for g in gs for m in g.get("members") or []):
        after = _tidy(_without(gs, removed))
        steps.append(("meta", "groups", copy.deepcopy(doc.meta.get("groups")), after or None))
    ls = layers(doc)
    if ls and any(_ref(m) in removed for l in ls for m in l.get("members") or []):
        steps.append(("meta", "layers", copy.deepcopy(doc.meta.get("layers")),
                      _without(ls, removed)))
    return steps
def outline(doc):
    in_layer = set()
    out = {"layers": [], "groups": [], "loose": {}}
    iso = doc.meta.get("isolated")
    for l in layers(doc):
        ms = members(doc, l)
        in_layer.update(ms)
        out["layers"].append({"id": l["id"], "name": l.get("name"), "colour": l.get("colour"),
                              "hidden": bool(l.get("hidden")), "locked": bool(l.get("locked")),
                              "isolated": iso == l["id"], "members": ms})
    def tree(g, seen):
        seen.add(g["id"])
        return {"id": g["id"], "name": g.get("name"), "members": members(doc, g),
                "all": all_members(doc, g),
                "groups": [tree(c, seen) for c in children(doc, g) if c["id"] not in seen]}
    seen = set()
    for g in groups(doc):
        if parent_of(doc, g) is None:
            out["groups"].append(tree(g, seen))
    for r in doc.refs():
        if r not in in_layer:
            out["loose"].setdefault(r[0], []).append(r)
    return out
def describe(doc, ref):
    item = doc.get(ref)
    if item is None:
        return str(ref)
    kind = ref[0]
    if kind == "piece":
        return "%s %s %dx%d at (%d, %d, %d)" % (item.get("kind"), item.get("tex"),
                                               round(item.get("w", 0) / 200.0),
                                               round(item.get("d", 0) / 200.0),
                                               item.get("x", 0), item.get("y", 0),
                                               item.get("z", 0))
    if kind == "anchor":
        return "anchor %s" % item.get("what", "")
    if kind == "object":
        return "object %s" % item.get("key", "")
    if kind == "star":
        return "star %s %s" % (item.get("id", ""), item.get("name") or "")
    if kind == "spot":
        return "spot %s" % item.get("_name", "")
    return "%s at (%d, %d, %d)" % (kind, item.get("x", 0), item.get("y", 0), item.get("z", 0))
def keep_locked(doc, layout):
    from . import geometry as geo
    from .document import LISTS, PREFIX, Document
    layout = copy.deepcopy(layout)
    meta = copy.deepcopy(doc.meta)
    kept = [r for r in sorted(locked_refs(doc)) if r[0] in LISTS]
    ids = Document({}, layout).ids()
    if kept:
        solid = [geo.aabb(doc.get(r)) for r in kept if r[0] == "piece"]
        pieces = layout.get("pieces") or []
        stay = [i for i, p in enumerate(pieces)
                if not any(geo.overlap_volume(geo.aabb(p), b) > 1.0 for b in solid)]
        layout["pieces"] = [pieces[i] for i in stay]
        ids["pieces"] = [ids["pieces"][i] for i in stay]
    remap = {}
    for r in kept:
        key = LISTS[r[0]]
        seq = layout.setdefault(key, [])
        have = set(ids.get(key) or [])
        n = len(have) + 1
        while "%s%d" % (PREFIX[r[0]], n) in have:
            n += 1
        nid = "%s%d" % (PREFIX[r[0]], n)
        seq.append(copy.deepcopy(doc.get(r)))
        ids.setdefault(key, []).append(nid)
        remap[(r[0], r[1])] = [r[0], nid]
    def moved(entries):
        return [list(remap[_ref(m)]) for m in entries or [] if _ref(m) in remap]
    lays = []
    for lay in layers(doc):
        lay = copy.deepcopy(lay)
        lay["members"] = moved(lay.get("members")) if lay.get("locked") else []
        lays.append(lay)
    if lays:
        meta["layers"] = lays
    gs = []
    for g in groups(doc):
        g = copy.deepcopy(g)
        g["members"] = moved(g.get("members"))
        gs.append(g)
    if gs:
        alive = set(g["id"] for g in gs if g["members"])
        grown = True
        while grown:
            grown = False
            for g in gs:
                if g["id"] not in alive and any(c.get("parent") == g["id"] and c["id"] in alive
                                                for c in gs):
                    alive.add(g["id"])
                    grown = True
        out = []
        for g in gs:
            if g["id"] in alive:
                if g.get("parent") not in alive:
                    g.pop("parent", None)
                out.append(g)
        meta["groups"] = out
    if meta.get("isolated") and not any(lay["id"] == meta["isolated"] for lay in lays):
        meta["isolated"] = None
    return layout, ids, meta, len(kept)
