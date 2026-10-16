import copy
import json
from studio.editor import engine, geometry as geo
from studio.editor.commands import Change
MARGIN = 0
def box_of(doc, refs, margin=MARGIN):
    boxes = [geo.aabb(doc.view_item(r)) for r in refs if r in doc]
    if not boxes:
        return None
    b = geo.union(boxes)
    return (geo.snap_floor(b[0] - margin), -geo.snap_floor(-(b[1] + margin)),
            geo.snap_floor(b[4] - margin), -geo.snap_floor(-(b[5] + margin)))
def run(doc, box, tries=8, use_metrics=False, progress=None, cancel=None):
    if not doc.brief:
        raise engine.EngineError("this map has no wish yet - generate it from a wish first "
                                 "(the region is built from the same wish)")
    return engine.regenerate_region(doc.brief, doc.to_layout(), box, tries=tries,
                                    use_metrics=use_metrics, progress=progress, cancel=cancel)
def _key(item):
    return json.dumps({k: v for k, v in geo.cleaned(item).items() if k != "model"},
                      sort_keys=True)
def change(doc, layout, label="Regenerate the region"):
    from studio.editor import ops
    steps = []
    want = {}
    for p in layout.get("pieces") or []:
        want.setdefault(_key(p), []).append(p)
    gone = []
    for ref in doc.refs("piece"):
        k = _key(doc.get(ref))
        if want.get(k):
            want[k].pop()
        else:
            gone.append(ref)
    steps += ops.delete(doc, gone).steps
    new = [p for lst in want.values() for p in lst]
    has_model = any("model" in doc.get(r) for r in doc.refs("piece"))
    clean = []
    for p in new:
        p = dict(p)
        if not has_model:
            p.pop("model", None)
        clean.append(geo.cleaned(p))
    steps += ops.insert(doc, [("piece", p) for p in clean], label, select=False).steps
    spawns = layout.get("spawns") or []
    refs = doc.refs("spawn")
    if len(spawns) == len(refs):
        for ref, s in zip(refs, spawns):
            if _key(doc.get(ref)) != _key(s):
                steps.append(("replace", ref, copy.deepcopy(doc.get(ref)), copy.deepcopy(s)))
    survey = (layout.get("survey") or {})
    if survey and survey != doc.rest.get("survey") and not doc.survey_follows:
        steps.append(("rest", "survey", copy.deepcopy(doc.rest.get("survey")),
                      copy.deepcopy(survey)))
    ch = Change("%s (%d out, %d in)" % (label, len(gone), len(clean)), steps, hand=False,
                select=None)
    ch.twins = True
    return ch
