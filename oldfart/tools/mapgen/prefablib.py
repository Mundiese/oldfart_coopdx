import importlib.util
import os
from . import v1
CELL = 200
_tool = None
def tool():
    global _tool
    if _tool is None:
        path = os.path.join(v1.REPO, "tools", "prefabs.py")
        spec = importlib.util.spec_from_file_location("of_prefabs_tool", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _tool = mod
    return _tool
_lib = None
def library():
    global _lib
    if _lib is None:
        try:
            _lib = tool().load_all()
        except Exception:
            _lib = {}
    return _lib
def _norm(s):
    return "".join(ch for ch in str(s).lower() if ch.isalnum())
def find(name):
    want = _norm(name)
    if not want:
        return None
    for key, p in sorted(library().items()):
        if _norm(key) == want or _norm(p.get("name", "")) == want:
            return p
    return None
def names():
    return [(k, p.get("name", k), list(p.get("tags", []))) for k, p in sorted(library().items())]
def with_tag(tag):
    return [k for k, p in sorted(library().items()) if tag in (p.get("tags") or [])]
def size(prefab, turn=0):
    x0, x1, z0, z1, h = tool().footprint(prefab, turn)
    return ((x1 - x0 + 1) * CELL, (z1 - z0 + 1) * CELL)
def door_turn(prefab, want):
    conns = [c for c in prefab.get("connectors", []) if c.get("kind") in ("door", "path")]
    if not conns:
        return 0
    for t in range(4):
        if tool().face_turned(conns[0]["face"], t) == want:
            return t
    return 0
def lay(prefab, x0, z0, y, turn=0, theme=None):
    T = tool()
    fx0, fx1, fz0, fz1, _ = T.footprint(prefab, turn)
    arenas = v1.arenas_module()
    try:
        pieces, skipped = T.arena_pieces(prefab, (0, 0, 0), turn, theme, arenas=arenas)
    except Exception:
        pieces, skipped = T.arena_pieces(prefab, (0, 0, 0), turn, None, arenas=arenas)
    dx = x0 - (fx0 * CELL - CELL // 2)
    dz = z0 - (fz0 * CELL - CELL // 2)
    out = []
    for p in pieces:
        q = dict(p)
        q["x"] += dx
        q["z"] += dz
        q["y"] += y
        q["tag"] = "prefab.%s" % prefab["key"]
        q.pop("model", None)
        out.append(q)
    return close_slots(out), skipped
def close_slots(pieces):
    m = v1.arenas_module()
    for _ in range(3):
        changed = False
        for i, low in enumerate(pieces):
            if low["kind"] != "box":
                continue
            x0, x1, z0, z1, _ = m.footprint(low)
            top = low["y"] + low["h"]
            for j, up in enumerate(pieces):
                if j == i:
                    continue
                ux0, ux1, uz0, uz1, _ = m.footprint(up)
                if ux1 <= x0 or x1 <= ux0 or uz1 <= z0 or z1 <= uz0:
                    continue
                gap = up["y"] - top
                if 1 < gap < m.MARIO_TALL:
                    low["h"] += gap
                    top += gap
                    changed = True
        if not changed:
            break
    return pieces
