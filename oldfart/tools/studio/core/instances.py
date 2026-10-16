import array
import math
from . import joinview, meshes
INSTANCE_FLOATS = 13
JOINS = True
STATE_SELECTED = 1
STATE_HOVER = 2
STATE_GHOST = 4
STATE_PREVIEW = 8
STATE_OUTLINE = 16
def outlined(piece):
    tag = str(piece.get("tag", ""))
    return piece.get("tex") == "invisible" and (tag.startswith("edge")
                                                 or tag.endswith(".invisible"))
class Batch:
    __slots__ = ("key", "data", "count", "ids")
    def __init__(self, key):
        self.key = key
        self.data = array.array("f")
        self.count = 0
        self.ids = []
    def add(self, piece, state, slot, layers, index):
        self.data.extend((float(piece["x"]), float(piece["y"]), float(piece["z"]),
                          float(piece["w"]), float(piece["h"]), float(piece["d"]),
                          math.radians(piece.get("yaw", 0)), float(state), float(slot),
                          float(index), float(layers[0]), float(layers[1]), float(layers[2])))
        self.count += 1
        self.ids.append(index)
def build(scene, registry, hover=True):
    slots = sorted(scene.highlights)
    slot_of = {}
    colours = []
    for s, name in enumerate(slots):
        ids, rgb = scene.highlights[name]
        colours.append(rgb)
        for i in ids:
            slot_of.setdefault(i, s + 1)
    opaque, ghosts = {}, {}
    sel, hov = scene.selection, scene.hover
    preview = scene.preview
    extras, grown = joinview.joins(scene.pieces) if JOINS else ([], {})
    states = {}
    for i, piece in enumerate(scene.pieces):
        if i in scene.hidden:
            continue
        state = STATE_OUTLINE if outlined(piece) else 0
        if i in sel:
            state |= STATE_SELECTED
        if hover and hov == i:
            state |= STATE_HOVER
        states[i] = state
        layers = registry.layers_for(piece)
        if preview is not None and i in preview.ids:
            moved = preview.apply(piece)
            _batch(opaque, moved).add(moved, state | STATE_PREVIEW, slot_of.get(i, 0), layers, i)
            _batch(ghosts, piece).add(piece, STATE_GHOST, 0, layers, i)
            continue
        drawn = grown.get(i, piece)
        _batch(opaque, drawn).add(drawn, state, slot_of.get(i, 0), layers, i)
    for i, arm in extras:
        if i not in states or (preview is not None and i in preview.ids):
            continue
        _batch(opaque, arm).add(arm, states[i], slot_of.get(i, 0), registry.layers_for(arm), i)
    for piece in scene.ghosts:
        _batch(ghosts, piece).add(piece, STATE_GHOST, 0, registry.layers_for(piece), -1)
    return opaque, ghosts, colours
def _batch(table, piece):
    key = meshes.mesh_key(piece)
    b = table.get(key)
    if b is None:
        b = table[key] = Batch(key)
    return b
