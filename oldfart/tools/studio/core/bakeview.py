import array
import math
FLOATS = 13
WATER_MIX = ((0.47, 0.64, 0.78), 0.45)
class BakedMesh:
    def __init__(self, data, count, keys, ground, flames=()):
        self.data = data
        self.count = count
        self.keys = keys
        self.ground = ground
        self.flames = list(flames)
def level_layout(meta, pieces, theme=None, hour=None):
    from mapgen import bake
    from mapgen.render import levelview
    out = {k: v for k, v in (meta or {}).items() if k not in ("source", "problems")}
    out.setdefault("level", "empty")
    out["pieces"] = [dict(p) for p in pieces]
    look = out.get("look") if isinstance(out.get("look"), dict) else {}
    out["look"] = bake.export_look(look, theme) or {}
    return levelview.hour_look(out, hour)
def triangles(layout):
    from mapgen.render import levelview
    sc = levelview.scene_of(layout)
    return sc, levelview.triangles(sc)
def mesh(layout, layer_of, lightmap=False):
    from mapgen.render import levelview
    sc, (P, UV, C, N, T, keys) = triangles(layout)
    sc.arena = getattr(sc, "arena", None) or layout
    ambient, live = levelview.game_light(sc)
    C = levelview.game_colours(sc, P, C, ambient=ambient, live=live)
    if lightmap:
        C = levelview.heat_colours(sc, C)
    layers = [float(layer_of(k)) for k in keys]
    out = array.array("f")
    for i in range(len(P)):
        water = 1.0 if math.isnan(N[i][0]) else 0.0
        n = (0.0, 0.0, 0.0) if water else tuple(float(v) for v in N[i])
        lay = layers[int(T[i])]
        for k in range(3):
            p, uv, c = P[i][k], UV[i][k], C[i][k]
            out.extend((float(p[0]), float(p[1]), float(p[2]), float(uv[0]), float(uv[1]),
                        float(c[0]), float(c[1]), float(c[2]), lay) + n + (water,))
    return BakedMesh(out, len(P) * 3, keys, bool(getattr(sc, "ground", False)),
                     getattr(sc, "flames", None) or ())
FLAME_FLOATS = 7
FLAME_FPS = 15
def flame_sway(t, phase):
    a = math.sin(t * 2.0 * math.pi * 2.3 + phase)
    b = math.sin(t * 2.0 * math.pi * 5.1 + phase * 1.7)
    k = 1.0 + 0.10 * a + 0.05 * b
    return k, 1.0 + (1.0 - k) * 0.6, 0.92 + 0.08 * (0.5 + 0.5 * b)
def flame_vertices(flames, right, up, t):
    from mapgen.render import levelview
    vb = levelview.venuebake()
    out = array.array("f")
    meshes = {}
    for x, y, z, blue, scale in flames or ():
        key = (bool(blue), float(scale))
        if key not in meshes:
            meshes[key] = vb.vanilla_flame_mesh(scale, bool(blue))
        verts, tris = meshes[key]
        k, w, lum = flame_sway(t, x * 0.0131 + y * 0.0071 + z * 0.0113)
        for tri in tris:
            for i in tri:
                vx, vy = verts[i][0] * w, verts[i][1] * k
                c = verts[i][3:]
                out.extend((x + vx * right[0] + vy * up[0], y + vx * right[1] + vy * up[1],
                            z + vx * right[2] + vy * up[2], min(1.0, c[0] / 255.0 * lum),
                            min(1.0, c[1] / 255.0 * lum), min(1.0, c[2] / 255.0 * lum),
                            c[3] / 255.0))
    return out
def registry_layer(registry):
    def layer_of(key):
        slug, face = key[0], key[1] if len(key) > 1 else 0
        trio = registry.slugs.get(slug)
        if trio is None:
            return 0
        return trio[min(2, max(0, int(face or 0)))]
    return layer_of
def shade_of(row):
    return tuple(row[5:8])
