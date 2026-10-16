from studio.editor import ops
from . import gltf
def export_document(doc, path, markers=(), registry=None):
    layout = doc.to_layout()
    pieces = layout.get("pieces") or []
    name = layout.get("name") or (doc.brief or {}).get("name") or "map"
    gltf.export(pieces, markers, path, registry=registry, name=name)
    return path, len(pieces), len(markers)
def import_change(doc, path):
    imp = gltf.read(path)
    if not imp.pieces:
        raise ValueError("%s has no Oldfart Studio pieces in it (was it exported from Oldfart Studio, "
                         "and saved from Blender with Custom Properties ticked?)" % path)
    before = doc.to_layout(models=False)
    layout, lines = gltf.merge(before, imp)
    from studio.editor.document import model_name
    worn = [q for q in before.get("pieces") or [] if "model" in q]
    keys = {gltf._key(q) for q in worn}
    kinds = {(q.get("kind"), q.get("tex"), q.get("tag")) for q in worn if q.get("tag")}
    for p in layout["pieces"]:
        p.pop("model", None)
        if gltf._key(p) in keys or (p.get("tag") and (p.get("kind"), p.get("tex"),
                                                      p.get("tag")) in kinds):
            p["model"] = model_name(p)
    return ops.replace_map(doc, doc.brief, layout, "Import from Blender"), lines
