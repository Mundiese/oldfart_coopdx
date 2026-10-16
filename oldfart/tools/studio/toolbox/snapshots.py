import copy
import json
import time
from studio.editor import geometry as geo
KEY = "snapshots"
CAP = 20
LIMIT = CAP
KINDS = ("piece", "spawn", "object")
LISTS = {"piece": "pieces", "spawn": "spawns", "object": "objects"}
def _state(doc):
    return {"brief": copy.deepcopy(doc.brief), "layout": doc.to_layout(models=False),
            "ids": doc.ids()}
def _delta(prev, cur):
    out = {}
    if cur["brief"] != prev["brief"]:
        out["brief"] = copy.deepcopy(cur["brief"])
    pl, cl = prev["layout"], cur["layout"]
    rest = {k: copy.deepcopy(v) for k, v in cl.items()
            if k not in LISTS.values() and pl.get(k) != v}
    drop = [k for k in pl if k not in LISTS.values() and k not in cl]
    if rest:
        out["rest"] = rest
    if drop:
        out["drop"] = drop
    lists = {}
    for key in LISTS.values():
        ids_c = (cur.get("ids") or {}).get(key) or []
        ids_p = (prev.get("ids") or {}).get(key) or []
        items_c = cl.get(key)
        items_p = pl.get(key) or []
        if items_c is None and key not in pl:
            continue
        items_c = items_c or []
        if len(ids_c) != len(items_c) or len(ids_p) != len(items_p) or None in ids_c:
            return None
        before = dict(zip(ids_p, items_p))
        changed = {str(i): copy.deepcopy(it) for i, it in zip(ids_c, items_c)
                   if before.get(i) != it}
        entry = {}
        if ids_c != ids_p:
            entry["order"] = list(ids_c)
        if changed:
            entry["set"] = changed
        if key in cl and key not in pl:
            entry["new"] = True
        if entry:
            lists[key] = entry
    if lists:
        out["lists"] = lists
    if (cur.get("ids") or {}).keys() != (prev.get("ids") or {}).keys():
        out["ids_keys"] = sorted((cur.get("ids") or {}).keys())
    return out
def _apply(prev, delta):
    cur = copy.deepcopy(prev)
    if "brief" in delta:
        cur["brief"] = copy.deepcopy(delta["brief"])
    lay = cur["layout"]
    for k in delta.get("drop", []):
        lay.pop(k, None)
    for k, v in (delta.get("rest") or {}).items():
        lay[k] = copy.deepcopy(v)
    ids = cur.setdefault("ids", {})
    for key, entry in (delta.get("lists") or {}).items():
        before = dict(zip(ids.get(key) or [], lay.get(key) or []))
        order = entry.get("order", ids.get(key) or [])
        sets = entry.get("set") or {}
        lay[key] = [copy.deepcopy(sets[str(i)]) if str(i) in sets else before[i] for i in order]
        ids[key] = list(order)
    if "ids_keys" in delta:
        for k in list(ids):
            if k not in delta["ids_keys"]:
                ids.pop(k)
    return cur
def states(doc):
    out = []
    for e in entries(doc):
        if "state" in e or not out:
            out.append(copy.deepcopy(e.get("state") or {"brief": {}, "layout": {}, "ids": {}}))
        else:
            out.append(_apply(out[-1], e.get("delta") or {}))
    return out
def state(doc, index):
    return states(doc)[index]
def _encode(rows):
    out, prev = [], None
    for head, st in rows:
        e = dict(head)
        e.pop("state", None)
        e.pop("delta", None)
        d = _delta(prev, st) if prev is not None else None
        if d is None:
            e["state"] = copy.deepcopy(st)
        else:
            e["delta"] = d
        out.append(e)
        prev = st
    return out
def _rows(doc):
    return [({k: v for k, v in e.items() if k not in ("state", "delta")}, st)
            for e, st in zip(entries(doc), states(doc))]
def thin(rows, cap):
    rows = list(rows)
    cap = max(2, int(cap))
    while len(rows) > cap:
        half = max(2, len(rows) // 2)
        cands = range(1, half)
        gone = min(cands, key=lambda i: (rows[i][0].get("at", 0) - rows[i - 1][0].get("at", 0),
                                         i))
        rows.pop(gone)
    return rows
def entries(doc):
    return list(doc.meta.get(KEY) or [])
def take(doc, name=None, now=None, cap=None):
    rows = _rows(doc)
    now = time.time() if now is None else now
    if not name:
        name = "Version %d" % (len(rows) + 1)
    st = _state(doc)
    rows.append(({"name": name, "at": now, "pieces": len(st["layout"].get("pieces") or []),
                  "spawns": len(st["layout"].get("spawns") or [])}, st))
    rows = thin(rows, CAP if cap is None else cap)
    doc.meta[KEY] = _encode(rows)
    return len(rows) - 1
def remove(doc, index):
    rows = _rows(doc)
    gone = rows.pop(index)
    doc.meta[KEY] = _encode(rows)
    return dict(gone[0], state=gone[1])
def rename(doc, index, name):
    snaps = list(doc.meta.get(KEY) or [])
    snaps[index] = dict(snaps[index], name=name)
    doc.meta[KEY] = snaps
def label(entry, now=None):
    at = time.strftime("%H:%M", time.localtime(entry.get("at", 0)))
    day = time.strftime("%d %b", time.localtime(entry.get("at", 0)))
    today = time.strftime("%d %b", time.localtime(now if now is not None else time.time()))
    return "%s - %s%s, %d pieces" % (entry.get("name", "?"), at,
                                     "" if day == today else " " + day, entry.get("pieces", 0))
def restore(doc, index):
    from studio.editor import ops
    snap = entries(doc)[index]
    st = state(doc, index)
    meta = dict(doc.meta)
    change = ops.replace_map(doc, st["brief"], st["layout"], "Restore %s" % snap["name"],
                             ids=st.get("ids"), meta=meta)
    return change
class Diff:
    def __init__(self):
        self.added = []
        self.moved = []
        self.changed = []
        self.removed = []
        self.moved_from = []
        self.by = "ids"
    def __bool__(self):
        return bool(self.added or self.moved or self.changed or self.removed)
    def counts(self):
        return {"added": len(self.added), "removed": len(self.removed),
                "moved": len(self.moved), "changed": len(self.changed)}
    def summary(self):
        c = self.counts()
        if not self:
            return "No difference"
        return ", ".join("%d %s" % (n, k) for k, n in c.items() if n)
def _key(item):
    return json.dumps(geo.cleaned(item), sort_keys=True)
def _place(item):
    return (item.get("x"), item.get("y"), item.get("z"))
def _shape(item):
    return json.dumps({k: v for k, v in geo.cleaned(item).items() if k not in ("x", "y", "z")},
                      sort_keys=True)
def compare(doc, index):
    st = state(doc, index)
    from studio.editor.document import LISTS
    old = {}
    for kind in KINDS:
        items = (st["layout"].get(LISTS[kind]) or [])
        ids = (st.get("ids") or {}).get(LISTS[kind]) or []
        old[kind] = [(ids[i] if i < len(ids) else None, it) for i, it in enumerate(items)]
    by_ids = _compare_by_ids(doc, old)
    by_shape = _compare_by_shape(doc, old)
    if sum(by_shape.counts().values()) < sum(by_ids.counts().values()):
        return by_shape
    return by_ids
def _compare_by_ids(doc, old):
    d = Diff()
    for kind in KINDS:
        then = dict((i, it) for i, it in old[kind] if i)
        for iid, item in doc.items[kind]:
            ref = (kind, iid)
            if iid not in then:
                d.added.append(ref)
                continue
            before = then.pop(iid)
            if _key(before) == _key(item):
                continue
            if _shape(before) == _shape(item):
                d.moved.append(ref)
                d.moved_from.append(before)
            else:
                d.changed.append(ref)
                if _place(before) != _place(item):
                    d.moved_from.append(before)
        d.removed += list(then.values())
    return d
def _compare_by_shape(doc, old):
    d = Diff()
    d.by = "shape"
    for kind in KINDS:
        pool = {}
        for _, it in old[kind]:
            pool.setdefault(_key(it), []).append(it)
        rest_now = []
        for iid, item in doc.items[kind]:
            k = _key(item)
            if pool.get(k):
                pool[k].pop()
            else:
                rest_now.append(((kind, iid), item))
        rest_old = [it for lst in pool.values() for it in lst]
        by_shape = {}
        for it in rest_old:
            by_shape.setdefault(_shape(it), []).append(it)
        for ref, item in rest_now:
            cands = by_shape.get(_shape(item)) or []
            if cands:
                best = min(cands, key=lambda o: sum(abs((a or 0) - (b or 0)) for a, b in
                                                    zip(_place(o), _place(item))))
                cands.remove(best)
                d.moved.append(ref)
                d.moved_from.append(best)
            else:
                d.added.append(ref)
        for lst in by_shape.values():
            d.removed += lst
    return d
