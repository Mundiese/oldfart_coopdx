import math
from .. import kit, v1
SKELETONS = (("courtyard", 3), ("terraces", 2), ("hub", 2), ("ring", 1))
TEAM_TEX = {"red": "carpet", "blue": "glassblock"}
CORNER_SHARE = 0.25
FLAG_MODES = ("ctf", "oneflag")
def plain_flag_wish(brief):
    modes = set(brief.get("modes") or ())
    if brief["family"] != "objective" or (modes and not modes & set(FLAG_MODES)):
        return False
    if brief.get("preset") or brief["sides"] not in ("auto", "2", 2, None):
        return False
    if any(a["what"] in ("base", "flag", "hill", "point") for a in brief["anchors"]):
        return False
    if "symmetry" not in (getattr(brief, "defaulted", None) or ("symmetry",)) \
            and brief.get("symmetry") not in (None, "auto", "turn4"):
        return False
    return "corner_bases" not in brief["features"]["want"]
def dice(brief):
    from ..rng import stream
    return stream(brief["seed"], "fort.dice").random() < CORNER_SHARE
def wanted(brief, r):
    want = set(brief["features"]["want"])
    if "corner_bases" in brief["features"]["avoid"]:
        return False
    corners = any(a["what"] == "base" and a.get("where", {}).get("compass") == "corners"
                  for a in brief["anchors"])
    if brief["sides"] == "4" or "corner_bases" in want or corners:
        return True
    return plain_flag_wish(brief) and dice(brief)
def _pick(r, weights):
    total = sum(w for _, w in weights)
    x = r.random() * total
    for name, w in weights:
        x -= w
        if x < 0:
            return name
    return weights[-1][0]
def build(brief, streams):
    from . import shooter
    from .. import dice as dicemod, skeletons
    d = dicemod.roll(brief, streams("style"))
    across = skeletons.across_of(brief, brief["players"])
    across = max(across, 7200)
    r = streams("fort.variety")
    weights = list(SKELETONS)
    modes = set(brief["modes"])
    if "koth" in modes or any(a["what"] == "hill" for a in brief["anchors"]):
        weights = [("terraces", 4), ("courtyard", 2)]
    if "walls" in brief["features"]["want"] or "gate" in brief["features"]["want"]:
        weights = [("courtyard", 5), ("terraces", 1)]
    name = _pick(r, weights)
    why = "fort variety: corner bases on the %s skeleton (turn4)" % name
    arena, meta = shooter.build_skeleton(brief, streams, d, name, "turn4", across, why)
    groups = meta.get("bases") or []
    notes = meta.setdefault("notes", [])
    if len(groups) < 4:
        raise ValueError("the %s skeleton built %d bases, not four" % (name, len(groups)))
    order = [0, 2, 1, 3]
    team_of = {order[0]: "red", order[1]: "red", order[2]: "blue", order[3]: "blue"}
    red = [p for i in (0, 1) for p in groups[i]]
    blue = [p for i in (2, 3) for p in groups[i]]
    spawns = []
    for i in range(8):
        for side in (red, blue):
            if i < len(side):
                x, y, z = side[i]
                yaw = int(round(math.degrees(math.atan2(-x, -z)) / 90.0)) * 90 % 360
                spawns.append({"x": x, "y": y, "z": z, "yaw": yaw})
    arena["spawns"] = spawns[:16]
    def centroid(g):
        return {"x": int(round(sum(p[0] for p in g) / len(g) / 50.0)) * 50,
                "y": g[0][1],
                "z": int(round(sum(p[2] for p in g) / len(g) / 50.0)) * 50, "yaw": 0}
    flag_red, flag_blue = centroid(groups[0]), centroid(groups[2])
    flag_red = dict(min(({"x": p[0], "y": p[1], "z": p[2], "yaw": 0} for p in groups[0]),
                        key=lambda s: (s["x"] - flag_red["x"]) ** 2 + (s["z"] - flag_red["z"]) ** 2))
    flag_blue = dict(min(({"x": p[0], "y": p[1], "z": p[2], "yaw": 0} for p in groups[2]),
                         key=lambda s: (s["x"] - flag_blue["x"]) ** 2 + (s["z"] - flag_blue["z"]) ** 2))
    field = [s for s in (arena.get("survey") or {}).get("points", [])
             if not any(s["x"] == q["x"] and s["z"] == q["z"] for q in arena["spawns"])]
    if not field:
        field = [dict(s) for s in (arena.get("survey") or {}).get("points", [])[16:]]
    if len(field) < 3:
        raise ValueError("the %s fort has %d field spots, three points need three" % (
            name, len(field)))
    cx = sum(p["x"] for p in arena["pieces"]) / float(len(arena["pieces"]))
    cz = sum(p["z"] for p in arena["pieces"]) / float(len(arena["pieces"]))
    B = min(field, key=lambda s: ((s["x"] - cx) ** 2 + (s["z"] - cz) ** 2, s["x"], s["z"]))
    gc = [centroid(g) for g in groups]
    mids = [((gc[0]["x"] + gc[2]["x"]) / 2.0, (gc[0]["z"] + gc[2]["z"]) / 2.0),
            ((gc[1]["x"] + gc[3]["x"]) / 2.0, (gc[1]["z"] + gc[3]["z"]) / 2.0)]
    rest = [s for s in field if s is not B]
    A = min(rest, key=lambda s: ((s["x"] - mids[0][0]) ** 2 + (s["z"] - mids[0][1]) ** 2,
                                 s["x"], s["z"]))
    rest2 = [s for s in rest if s is not A] or rest
    C = min(rest2, key=lambda s: ((s["x"] - mids[1][0]) ** 2 + (s["z"] - mids[1][1]) ** 2,
                                  s["x"], s["z"]))
    pts = [dict(A, yaw=0), dict(B, yaw=0), dict(C, yaw=0)]
    arena["survey"] = {"points": pts, "hill": dict(B, yaw=0), "ctfRed": flag_red,
                       "ctfBlue": flag_blue}
    arena["marks"] = [dict(pts[0], label="A"), dict(pts[1], label="B hill"),
                      dict(pts[2], label="C"), dict(flag_red, label="red flag"),
                      dict(flag_blue, label="blue flag")]
    if TEAM_TEX["red"] in kit.textures() and TEAM_TEX["blue"] in kit.textures():
        for p in arena["pieces"]:
            tag = str(p.get("tag", ""))
            if tag.endswith(".bastion") or ".base" in tag and tag.endswith("floor"):
                side = None
                for gi, g in enumerate(groups):
                    gx, gz = gc[gi]["x"], gc[gi]["z"]
                    if abs(p["x"] - gx) <= p["w"] and abs(p["z"] - gz) <= p["d"]:
                        side = "red" if gi in (0, 1) else "blue"
                        break
                if side:
                    p["tex"] = TEAM_TEX[side]
                    p["model"] = v1.arenas_module().model_name(p)
    if brief["sides"] == "4":
        notes.append("sides 4: four corner bases of four spawns each are built; the mod's "
                     "team modes deal two sides (of_teams), so they play two teams here")
    meta["bases"] = [list(red), list(blue)]
    meta["units"] = 2
    meta["symmetry"] = "turn4"
    meta.setdefault("modules", {})
    meta["modules"] = dict(meta["modules"], fort="corners", skeleton=name)
    meta["family"] = "objective"
    meta["params"] = dict(meta.get("params") or {}, fort="corners", skeleton=name)
    length = int(abs(flag_red["x"] - flag_blue["x"]) + abs(flag_red["z"] - flag_blue["z"]))
    arena["blurb"] = "a generated corner fort: four bases, two teams, a hill that can move"
    arena["note"] = ("a %s fort with its bases in the corners (red north-west and south-east, "
                     "blue the others), flags %d apart, points on three sides of the middle"
                     % (name, length))
    return arena, meta
