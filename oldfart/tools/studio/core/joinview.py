import copy
from . import kitbridge
ARM_FROM = 60
ARM_TO = 100
ARM_THICK = 50
SIDES = ((1, 0), (0, 1), (-1, 0), (0, -1))
def joins(pieces):
    try:
        a = kitbridge.arenas()
    except Exception:
        return [], {}
    if not hasattr(a, "connect"):
        return [], {}
    work = []
    for i, p in enumerate(pieces):
        if not isinstance(p, dict) or "kind" not in p or "x" not in p:
            continue
        q = copy.deepcopy(p)
        q.setdefault("yaw", 0)
        q["_index"] = i
        work.append(q)
    if not any(q.get("kind") in ("pillar", "rail") for q in work):
        return [], {}
    try:
        a.connect(work)
    except Exception:
        return [], {}
    extras, grown = [], {}
    for q in work:
        i = q["_index"]
        join = q.get("join")
        if q.get("kind") == "pillar" and join:
            tex = join.get("other") or q.get("tex")
            for (dx, dz), on in zip(SIDES, join.get("arms", "")):
                if on != "1":
                    continue
                mid = (ARM_FROM + ARM_TO) / 2.0
                length = ARM_TO - ARM_FROM
                arm = {"kind": "box", "tex": tex, "x": q["x"] + dx * mid, "y": q["y"],
                       "z": q["z"] + dz * mid, "w": length if dx else ARM_THICK,
                       "d": ARM_THICK if dx else length, "h": q["h"], "yaw": 0,
                       "tag": "join.arm"}
                extras.append((i, arm))
        elif q.get("kind") == "rail":
            p = pieces[i]
            if any(abs(q[k] - p[k]) > 0.01 for k in ("w", "x", "z")):
                g = dict(p)
                g.update({"w": q["w"], "x": q["x"], "z": q["z"]})
                grown[i] = g
    return extras, grown
