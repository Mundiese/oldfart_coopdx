BOX_KINDS = ("box", "floor", "slab", "wall", "block")
BARS = {
    "one": [("gizmo.move", "Move"), ("edit.turn", "Turn"), ("tools.variant_next", "Shape"),
            ("edit.paint", "Paint"), ("edit.duplicate", "Copy"), ("edit.delete", "Delete"),
            ("more", "More")],
    "many": [("gizmo.move", "Move"), ("edit.turn", "Turn"), ("edit.group", "Group"),
             ("edit.paint", "Paint"), ("edit.mirror_x", "Mirror"),
             ("lib.save_prefab", "Save as prefab"), ("more", "More")],
    "box": [("tools.push_face", "Grow"), ("tools.pull_face", "Shrink"), ("edit.turn", "Turn"),
            ("build.hollow", "Make it a room"), ("build.carve", "Cut a hole"),
            ("edit.drop", "Drop"), ("more", "More")],
    "marker": [("gizmo.move", "Move"), ("edit.turn", "Turn"), ("edit.duplicate", "Copy"),
               ("edit.delete", "Delete"), ("more", "More")],
    "hand": [("hand", ""), ("edit.turn", "Turn"), ("tools.paste_sticky", "Stamp"),
             ("plane.up", "Higher"), ("plane.down", "Lower"), ("select.none", "Put away")],
    "nothing": [("hotbar.slot1", "Place last"), ("tools.room", "Room"),
                ("tools.brush_raise", "Raise ground"), ("tools.brush_paint", "Paint"),
                ("house.brush", "Houses"), ("map.play", "Play it"), ("more", "More")],
}
def kind_of(doc, refs, armed=None):
    if armed:
        return "hand"
    refs = [r for r in refs if r in doc]
    if not refs:
        return "nothing"
    if len(refs) > 1:
        return "many"
    r = refs[0]
    if r[0] != "piece":
        return "marker"
    if (doc.get(r) or {}).get("kind") in BOX_KINDS:
        return "box"
    return "one"
def buttons(kind, have=None):
    out = []
    for aid, word in BARS[kind]:
        if have is None or aid in ("more", "hand") or aid in have:
            out.append((aid, word))
    return out[:7]
