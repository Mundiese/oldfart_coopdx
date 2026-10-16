import copy
from . import engine
from .commands import Change
MODE_ROWS = ("mode_fit",)
def has_fix(row_key):
    from mapgen import critic
    return row_key in critic.REPAIRS
def preview(doc, row_key):
    layout = doc.to_layout(models=False)
    family = doc.rest.get("family") or doc.brief.get("family")
    return engine.critic_fix_preview(layout, row_key, family)
def refs(doc, pv, after=False):
    from .document import LISTS
    kinds = dict((v, k) for k, v in LISTS.items())
    out = []
    for key, d in (pv.get("diff") or {}).items():
        kind = kinds.get(key)
        if kind is None:
            continue
        if after:
            ids = (pv.get("_ids") or {}).get(key) or []
            for i in d["changed"] + d["added"]:
                if i < len(ids):
                    out.append((kind, ids[i]))
        else:
            now = doc.refs(kind)
            for i in d["changed"] + d["removed"]:
                if i < len(now):
                    out.append(now[i])
    return out
def _ids_after(doc, pv):
    ids = doc.ids()
    out = {}
    for key, lst in ids.items():
        d = (pv.get("diff") or {}).get(key)
        if d and d["removed"]:
            gone = set(d["removed"])
            lst = [i for n, i in enumerate(lst) if n not in gone]
        out[key] = list(lst)
    return out
def change_for(doc, pv, label=None):
    from .document import Document
    before = doc.state()
    ids = _ids_after(doc, pv)
    after = {"brief": copy.deepcopy(doc.brief), "layout": copy.deepcopy(pv["layout"]),
             "ids": ids, "meta": copy.deepcopy(doc.meta)}
    probe = Document(after["brief"], after["layout"], after["ids"], after["meta"])
    after["ids"] = probe.ids()
    after["follows"] = probe.survey_follows
    pv = dict(pv, _ids=after["ids"])
    sel = refs(doc, pv, after=True)
    return Change(label or "Fix: %s" % pv.get("label", pv.get("row")),
                  [("state", before, after)], hand=True, select=sel or None)
