from studio.editor import geometry as geo
SOURCE = "playground:"
NAME = "Playground"
WHAT = "a ready island to try things on"
TAG = "playground"
LEVEL = "empty2"
SPAWN = (0, 0, 0)
SPOTS = (
    (0, 260, 1000, "Grow me! Click me, then {tools.push_face} (and {tools.pull_face} "
                   "shrinks)"),
    (-1000, 860, -1000, "Paint me! Click a texture in the palette, then {edit.paint}"),
    (1600, 260, 900, "Turn me! Click me, then {edit.turn}"),
    (1000, 660, -1000, "Climb up here in the game: {map.play} plays the map"),
    (-1200, 120, 1100, "Raise the ground here: {tools.brush_raise}, then click and drag"),
    (1500, 1900, 1500, "Copy me: click me, then {edit.duplicate}"),
    (0, 120, 0, "Put something down: click a shape in the palette, then click here. "
                "{map.play} plays it in the game!"),
)
def _keys(aid, table=None):
    from studio.core import keymap
    if table is not None:
        keys = table(aid)
    else:
        keys = keymap.ACTIONS.get(aid, ([],))[0]
    return keys[0] if keys else "(F3: %s)" % aid
def pieces():
    from mapgen import v1
    m = v1.arenas_module()
    def t(p):
        p = dict(p)
        p["tag"] = TAG
        return p
    out = [
        t(m.box("grass", -2000, 2000, -200, 0, -2000, 2000)),
        t(m.box("frostedrock", -1700, 1700, -600, -200, -1700, 1700)),
        t(m.box("frostedrock", -1200, 1200, -1000, -600, -1200, 1200)),
        t(m.box("darkplanks", -1400, -600, 0, 600, -1400, -600)),
        t(m.roof("ridge", "rfclay", -1500, -500, -1500, -500, 600, 800, "x")),
        t(m.box("flowersred", -1400, -1000, 0, 40, -500, -300)),
        t(m.box("flowersyellow", -1000, -600, 0, 40, -500, -300)),
        t(m.box("hedge", -1950, -1750, 0, 200, -400, 400)),
        t(m.box("pathgravel", -300, 300, 0, 20, -1500, -700)),
        t(m.box("stone1", 600, 1400, 0, 400, -1400, -600)),
        t(m.box("stone1", 800, 1200, 0, 200, -600, 200)),
        t(m.stairs("stone1", 800, 1200, -600, -200, 200, 400, "-z")),
        t(m.stairs("stone1", 800, 1200, 200, 600, 0, 200, "-z")),
        t(m.box("crate", -200, 200, 0, 200, 800, 1200)),
        t(m.ramp("stone1", 1400, 1800, 600, 1000, 0, 200, "-z")),
        t(m.box("stone1", 1400, 1800, 0, 200, 200, 600)),
        t(m.box("whitemarble", 1300, 1700, 0, 1600, 1300, 1700)),
        t(m.roof("pyramid", "rfshingleblue", 1200, 1800, 1200, 1800, 1600, 1800)),
    ]
    out += decor()
    return [geo.cleaned(p) if hasattr(geo, "cleaned") else p for p in out]
DECOR = (("decor:bench", 0, -1600, 180), ("decor:lamp", -450, -1100, 0),
         ("decor:lamp", 450, -1100, 0))
TREES = ((-1750, -1750), (1750, -1750), (-1750, 1750), (0, 1750))
def decor():
    from studio.editor import palette as pal
    out = []
    p = pal.Palette()
    for eid, x, z, yaw in DECOR:
        for kind, item in p.get(eid).make("darkplanks"):
            if kind == "piece":
                item = dict(item, x=x, z=z, yaw=yaw)
                item.pop("context", None)
                out.append(item)
    return out
def objects():
    return [{"key": "tree", "x": x, "y": 0, "z": z, "yaw": 0} for x, z in TREES]
def notes(keys=None):
    out = []
    for k, (x, y, z, words) in enumerate(SPOTS):
        text = words
        for aid in ("tools.push_face", "tools.pull_face", "edit.paint", "edit.turn",
                    "map.play", "tools.brush_raise", "edit.duplicate"):
            if "{%s}" % aid in text:
                text = text.replace("{%s}" % aid, _keys(aid, keys))
        out.append({"id": k + 1, "x": x, "y": y, "z": z, "text": text})
    return out
def layout():
    from studio.editor.document import empty_layout
    out = empty_layout()
    out["name"] = NAME
    out["level"] = LEVEL
    out["budget"] = 120
    out["pieces"] = pieces()
    out["spawns"] = spawns()
    out["objects"] = objects()
    return out
def spawns():
    import math
    sx, sy, sz = SPAWN
    out = [{"x": sx, "y": sy, "z": sz, "yaw": 180}]
    for k in range(15):
        a = 2 * math.pi * k / 15.0
        x, z = round(560 * math.sin(a) / 20) * 20, round(560 * math.cos(a) / 20) * 20
        out.append({"x": x, "y": 0, "z": z, "yaw": int(round(math.degrees(a) / 90.0)) * 90 % 360})
    return out
def document(keys=None):
    from studio.editor.document import Document
    doc = Document({"family": "explore"}, layout())
    doc.meta["notes"] = notes(keys)
    doc.meta["origin"] = [{"name": NAME, "author": "Oldfart Studio"}]
    doc.meta["playground"] = True
    return doc
