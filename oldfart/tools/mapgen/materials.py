import random
import zlib
from . import budget, kit
LOW_KEEP = 1
HIGH_SHARE = 0.34
KEEP_TEX = {"carpet", "glassblock", "lava", "water", "ice", "hazardstripes", "snowblock",
            "sand", "grass"}
KEEP_KINDS = {"water", "ice"}
def _roles(tex):
    t = kit.textures().get(tex) or {}
    return tuple(r for r in (t.get("roles") or ()) if r not in ("any", "cap")) \
        or tuple(kit.ROLES.get(tex) or ())
def _role(tex):
    roles = _roles(tex)
    return roles[0] if roles else None
def _retex(p, new):
    old = p["tex"]
    p["tex"] = new
    m = p.get("model")
    if isinstance(m, str) and m.startswith("of_ak_%s_" % old):
        p["model"] = "of_ak_%s_" % new + m[len("of_ak_%s_" % old):]
def _groups(pieces):
    parent = list(range(len(pieces)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    boxes = []
    for p in pieces:
        hw, hd = p["w"] / 2.0, p["d"] / 2.0
        if int(p.get("yaw", 0)) % 180 == 90:
            hw, hd = hd, hw
        boxes.append((p["x"] - hw, p["x"] + hw, p["y"], p["y"] + p["h"], p["z"] - hd,
                      p["z"] + hd))
    for i, a in enumerate(boxes):
        for j in range(i + 1, len(boxes)):
            b = boxes[j]
            if a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3] and \
                    a[4] < b[5] and b[4] < a[5]:
                parent[find(i)] = find(j)
    out = {}
    for i in range(len(pieces)):
        out.setdefault(find(i), []).append(i)
    return list(out.values())
def pictures(arena):
    r = budget.report(arena)
    return r["pictures"], r["download_kb"]
def apply(arena, brief):
    v = brief["variety"] if "variety" in brief.to_dict() else "auto"
    if v not in ("low", "high"):
        return None
    before = pictures(arena)
    pieces = arena["pieces"]
    if v == "low":
        by_kind = {}
        for p in pieces:
            if p["kind"] in KEEP_KINDS or p["tex"] in KEEP_TEX:
                continue
            by_kind.setdefault(p["kind"], {}).setdefault(p["tex"], 0)
            by_kind[p["kind"]][p["tex"]] += 1
        keep = {k: sorted(t, key=lambda x: (-t[x], x))[:LOW_KEEP] for k, t in by_kind.items()}
        for group in _groups(pieces):
            first = pieces[group[0]]
            if any(pieces[i]["tex"] in KEEP_TEX or pieces[i]["kind"] in KEEP_KINDS
                   for i in group) or first["kind"] not in keep:
                continue
            ks = keep[first["kind"]]
            if first["tex"] in ks:
                continue
            same_role = [t for t in ks if _role(t) == _role(first["tex"])]
            new = (same_role or ks)[0]
            for i in group:
                _retex(pieces[i], new)
    else:
        from . import beauty
        rng = random.Random(zlib.crc32(("variety:%d" % brief["seed"]).encode()))
        alts = [t for t in beauty.WALL_ALTS if t in kit.ROLES]
        for group in _groups(pieces):
            gp = [pieces[i] for i in group]
            if any(p["kind"] != "box" or p["tex"] in KEEP_TEX or "wall" not in _roles(p["tex"])
                   for p in gp):
                continue
            if rng.random() < HIGH_SHARE and alts:
                new = rng.choice(alts)
                for p in gp:
                    _retex(p, new)
    after = pictures(arena)
    note = ("material variety %s: %d -> %d pictures, ~%.0f -> ~%.0f KB download per joiner"
            % (v, before[0], after[0], before[1], after[1]))
    arena.setdefault("report", {}).setdefault("notes", []).append(note)
    return note
