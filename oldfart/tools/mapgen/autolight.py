import math
from . import decor, kit
LAMP_RADIUS = 1250
SPACING_K = (1.4, 1.9)
GAP_K = 1.8
MIN_GAP = 1500
OFF_PAVING = 160
DENSITY_MOST = 3
PATH_WORDS = ("road", "lane", "street", "path", "plaza.paving", "main_street")
GLOW_TEXTURES = ("glowgreen", "glowblue")
EVERY = 5
CAP_TEXTURES = ("mushroomsred", "mushroomsbrown", "flowersred", "carpet")
def _foot_clear(pieces, x, z, y, half=90):
    for p in pieces:
        w, d = (p["d"], p["w"]) if int(p.get("yaw", 0) or 0) % 180 == 90 else (p["w"], p["d"])
        if abs(p["x"] - x) < w / 2.0 + half and abs(p["z"] - z) < d / 2.0 + half:
            if p["y"] + p["h"] > y + 30 and p["y"] < y + 900:
                return False
    return True
def _lights(arena):
    import os
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake as vb
    return [(L.x, L.z) for L in vb.light_sources(vb.prepared(arena))]
LIQUID_CLEAR = 150
def _foot(p):
    w, d = (p["d"], p["w"]) if int(p.get("yaw", 0) or 0) % 180 == 90 else (p["w"], p["d"])
    return p["x"] - w / 2.0, p["x"] + w / 2.0, p["z"] - d / 2.0, p["z"] + d / 2.0
def _in_liquid(liquids, x, z):
    m = LIQUID_CLEAR
    return any(a - m <= x <= b + m and c - m <= z <= d + m for a, b, c, d in liquids)
def light_path(arena, lots=False, have=None):
    pieces = arena.get("pieces") or []
    spacing = SPACING_K[0 if lots else 1] * LAMP_RADIUS
    gap = max(MIN_GAP, spacing * 0.75 if lots else GAP_K * LAMP_RADIUS)
    lit = list(_lights(arena))
    out = []
    per = {}
    liquids = [_foot(p) for p in pieces if p.get("kind") in ("water", "lava")
               or p.get("tex") == "lava"]
    paths = [p for p in pieces if any(w in (p.get("tag") or "") for w in PATH_WORDS)
             and p.get("kind") == "box" and p["h"] <= 60]
    paths.sort(key=lambda p: (round(p["x"]), round(p["z"]), round(p["y"])))
    side = 1
    for p in paths:
        w, d = (p["d"], p["w"]) if int(p.get("yaw", 0) or 0) % 180 == 90 else (p["w"], p["d"])
        along_x = w >= d
        length = w if along_x else d
        width = d if along_x else w
        n = max(1, int(length // spacing))
        top = p["y"] + p["h"]
        for k in range(n):
            t = (k + 0.5) / n - 0.5
            off = width / 2.0 + OFF_PAVING
            x = p["x"] + (t * length if along_x else side * off)
            z = p["z"] + (side * off if along_x else t * length)
            side = -side
            if any(math.hypot(x - lx, z - lz) < gap for lx, lz in lit):
                continue
            cell = (int(math.floor(x / 1000.0)), int(math.floor(z / 1000.0)))
            if per.get(cell, 0) >= DENSITY_MOST:
                continue
            if _in_liquid(liquids, x, z):
                continue
            ground = [q for q in pieces if abs(q["x"] - x) < q["w"] / 2.0 + 1
                      and abs(q["z"] - z) < q["d"] / 2.0 + 1 and abs(q["y"] + q["h"] - top) <= 20]
            if not ground or not _foot_clear(pieces + out, x, z, top):
                continue
            lamp = decor.piece("lamp", int(round(x)), top, int(round(z)), 0,
                               tag="decor.lamp.autolight")
            out.append(lamp)
            lit.append((x, z))
            per[cell] = per.get(cell, 0) + 1
    return out
def _hash01(x, z):
    h = (int(x) * 73856093) ^ (int(z) * 19349663)
    return (h & 0xffff) / 65535.0
def glow_mushrooms(arena, every=EVERY, everyone=False, glow="glowgreen"):
    pieces = arena.get("pieces") or []
    have = kit.textures()
    tex = glow if glow in have else next((t for t in GLOW_TEXTURES if t in have), None)
    if tex is None:
        return []
    caps = [p for p in pieces if (p.get("tag") or "").endswith(".crown") and p.get("kind") == "box"
            and p.get("tex") in CAP_TEXTURES]
    stalks = [p for p in pieces if (p.get("tag") or "").endswith(".trunk")]
    out = []
    for p in pieces:
        tag = p.get("tag") or ""
        if not tag.endswith(".cap.under"):
            continue
        if not everyone and int(_hash01(p["x"], p["z"]) * every) != 0:
            continue
        base = tag[:-len(".cap.under")]
        for q in pieces:
            if (q.get("tag") or "") in (base + ".cap.under", base + ".cap.spot") \
                    and abs(q["x"] - p["x"]) < 1 and abs(q["z"] - p["z"]) < 1:
                q["glow"] = True
        p["light"] = {"preset": "mushroom", "below": True}
    for c in caps:
        stalk = next((s for s in stalks if abs(s["x"] - c["x"]) < 1 and abs(s["z"] - c["z"]) < 1
                      and abs(s["y"] + s["h"] - c["y"]) < 1), None)
        if stalk is None:
            continue
        if not everyone and int(_hash01(c["x"], c["z"]) * every) != 0:
            continue
        a = c["w"] / 2.0 - 20
        s = stalk["w"] / 2.0 + 10
        if a - s < 40:
            continue
        y0, y1 = c["y"] - 20, c["y"]
        tag = (c.get("tag") or "flora").rsplit(".", 1)[0] + ".glow"
        for x0, x1 in ((c["x"] - a, c["x"] - s), (c["x"] + s, c["x"] + a)):
            out.append(kit.kind("box").make(tex, int(x0), int(x1), int(y0), int(y1),
                                            int(c["z"] - a), int(c["z"] + a), None, tag))
    return out
DAY_SKIES = ("BACKGROUND_OCEAN_SKY", "BACKGROUND_BELOW_CLOUDS", "BACKGROUND_SNOW_MOUNTAINS",
             "BACKGROUND_DESERT", "BACKGROUND_ABOVE_CLOUDS", "BACKGROUND_GREEN_SKY")
NIGHT_SKIES = {"dusk": "BACKGROUND_FLAMING_SKY", "sodium dusk": "BACKGROUND_FLAMING_SKY",
               "a red night": "BACKGROUND_FLAMING_SKY", "a cold blue": "BACKGROUND_UNDERWATER_CITY",
               "under water": "BACKGROUND_UNDERWATER_CITY", "a purple hour": "BACKGROUND_PURPLE_SKY"}
NIGHT_SKY = "BACKGROUND_HAUNTED"
SKY_SWAP = False
def night_sky(mood, sky, asked=None):
    if not SKY_SWAP or asked not in (None, "", "auto"):
        return None
    d = mood.get("darkness") if isinstance(mood, dict) else None
    if not d or sky not in DAY_SKIES:
        return None
    return NIGHT_SKIES.get(str(d), NIGHT_SKY)
SKY_TINT_FIELD = "skyTint"
SKY_TINTS = {"dusk": (235, 140, 125), "night": (60, 74, 125), "pitch": (40, 44, 70),
             "a red night": (150, 60, 50), "a green murk": (70, 110, 80),
             "a cold blue": (70, 95, 160), "sodium dusk": (200, 140, 80),
             "a purple hour": (150, 100, 175), "hospital light": (170, 190, 170),
             "under water": (60, 110, 140)}
DARK_SKIES = ("BACKGROUND_HAUNTED", "BACKGROUND_FLAMING_SKY", "BACKGROUND_UNDERWATER_CITY",
              "BACKGROUND_PURPLE_SKY")
def sky_tint(mood, sky):
    d = mood.get("darkness") if isinstance(mood, dict) else None
    if not d or sky in DARK_SKIES:
        return None
    t = SKY_TINTS.get(str(d), SKY_TINTS["night"])
    return [int(c) for c in t]
LIGHTY_DECOR = ("lamp", "campfire", "lantern", "torch", "brazier", "candle")
def critic_rows(arena):
    look = arena.get("look") if isinstance(arena.get("look"), dict) else {}
    mood = look.get("mood") if isinstance(look.get("mood"), dict) else {}
    vb = _vb()
    lighty = mood.get("darkness") or any(
        p.get("light") or p.get("decor") in LIGHTY_DECOR or p.get("tex") in vb.GLOW_SLUGS
        for p in arena.get("pieces") or ())
    if not lighty:
        return {}
    return vb.light_critic(arena)
def _vb():
    import os
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake as vb
    return vb
