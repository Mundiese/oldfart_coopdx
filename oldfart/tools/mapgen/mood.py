import copy
FIELDS = {
    "weather": ("snow", "Weather", [
        "snow", "a blizzard", "flower petals on the ground", "bubbles, deep under water",
        "lava bubbles, over lava", "rain", "a thunderstorm"]),
    "hour": ("sun", "The hour", [
        "early, from the east", "overhead", "late, from the west", "from underneath",
        "from the north", "low and behind", "from the south", "flat on from the east",
        "flat on from the west"]),
    "darkness": ("dark", "Darkness", [
        "dusk", "night", "pitch", "a red night", "a green murk", "a cold blue",
        "sodium dusk", "a purple hour", "hospital light", "under water"]),
    "fog": ("fog", "Fog", [
        "hazy", "thick", "pea soup", "a red haze", "sulphur", "a blue distance",
        "a green murk", "smoke", "a pink evening"]),
    "light": ("shading", "Light colour", [
        "hard shadows", "a warm sun", "moonlight", "sickly", "a sunset",
        "a fluorescent office", "firelight"]),
    "colour": ("tint", "World colour", [
        "sepia", "rust", "verdigris", "ice", "a bruise", "gold", "ash", "bleached",
        "a shadow of itself"]),
}
FIELD_ORDER = ("weather", "hour", "darkness", "fog", "light", "colour")
OBJECT_RAINS = ("a rain of Bob-ombs", "a rain of coins", "a rain of 1-Ups")
def drop_object_rains(layout):
    look = layout.get("look") if isinstance(layout, dict) else None
    if not isinstance(look, dict):
        return 0
    n = 0
    mood = look.get("mood")
    if isinstance(mood, dict) and mood.get("weather") in OBJECT_RAINS:
        del mood["weather"]
        if "preset" in mood:
            del mood["preset"]
        n += 1
    if isinstance(mood, dict) and "preset" in mood and mood["preset"] not in PRESET_BY_KEY:
        del mood["preset"]
    if look.get("weather") in OBJECT_RAINS:
        del look["weather"]
        n += 1
    vis = look.get("visuals")
    if isinstance(vis, list):
        keep = [v for v in vis if not (isinstance(v, (list, tuple)) and len(v) > 1
                                       and v[1] in OBJECT_RAINS)]
        n += len(vis) - len(keep)
        look["visuals"] = keep
    return n
HOUR_DIRS = {
    "early, from the east": (0.9, 0.35, 0.1), "overhead": (0, 1, 0),
    "late, from the west": (-0.9, 0.35, -0.1), "from underneath": (0, -1, 0),
    "from the north": (0.1, 0.4, 0.9), "low and behind": (0, 0.15, -1.0),
    "from the south": (-0.1, 0.4, -0.9), "flat on from the east": (1.0, 0.05, 0),
    "flat on from the west": (-1.0, 0.05, 0),
}
DIALS = [
    ("hue", 0.0, 1.0, 0.05, 0.0),
    ("saturation", 0.0, 3.0, 0.1, 1.0),
    ("brightness", 0.0, 3.0, 0.1, 1.0),
    ("contrast", -1.0, 3.0, 0.05, 1.0),
    ("exposure", 0.0, 3.0, 0.1, 1.0),
    ("posterization", 1.0, 16.0, 1.0, 8.0),
    ("scanlines", 0.0, 10.0, 0.5, 1.0),
]
DIAL_NAMES = [d[0] for d in DIALS]
LOOKS = {
    "black and white": {"saturation": 0.0},
    "an old photograph": {"saturation": 0.25, "hue": 0.08, "contrast": 0.85},
    "a comic book": {"posterization": 3.0, "contrast": 1.35, "saturation": 1.4},
    "a CRT in 1996": {"scanlines": 6.0, "posterization": 6.0, "dithering": 1.0},
    "night vision": {"saturation": 0.0, "hue": 0.33, "contrast": 1.6, "brightness": 1.3},
    "a fever dream": {"hue": 0.5, "saturation": 2.2, "contrast": 1.2},
    "a photo negative": {"contrast": -1.0},
    "sun-bleached": {"brightness": 1.6, "saturation": 0.5, "contrast": 0.75},
    "newsprint": {"saturation": 0.0, "brightness": 1.15, "contrast": 1.6, "dithering": 1.0},
    "thermal": {"hue": 0.62, "saturation": 3.0, "brightness": 1.25, "posterization": 4.0},
    "bleach bypass": {"saturation": 0.3, "contrast": 1.9, "exposure": 1.3},
    "moonless": {"brightness": 0.4, "saturation": 0.45, "contrast": 1.25},
    "blown out": {"brightness": 1.6, "contrast": 1.25, "saturation": 0.7},
    "a cheap VHS": {"scanlines": 3.0, "saturation": 0.75, "contrast": 0.85, "brightness": 1.1},
    "eight colours": {"posterization": 2.0, "saturation": 1.5},
    "a blueprint": {"saturation": 0.0, "hue": 0.6, "contrast": 1.4, "brightness": 0.85},
}
LOOK_ORDER = list(LOOKS)
PRESETS = [
    ("clear", "Clear", "No weather of its own - the map as it is drawn, under the lobby's "
     "own look", {}),
    ("rain", "Rain", "Rain falls and the air goes a little grey - a wet harbour, a jungle",
     {"weather": "rain", "fog": "hazy", "darkness": "dusk"}),
    ("storm", "Storm", "A thunderstorm with lightning in a dark sky - a haunted castle, a "
     "pirate fight", {"weather": "a thunderstorm", "darkness": "night", "fog": "thick"}),
    ("snow", "Snow", "Gentle snow and a cold blue far away - a winter village",
     {"weather": "snow", "fog": "a blue distance", "colour": "ice"}),
    ("blizzard", "Blizzard", "A snow storm you can hardly see through - a mountain top",
     {"weather": "a blizzard", "fog": "pea soup", "colour": "ice"}),
    ("foggy", "Foggy", "Thick fog hides the far side - a moor, a ghost town",
     {"fog": "thick", "darkness": "dusk"}),
    ("spooky", "Spooky night", "A green-dark night in a murky fog - a graveyard, a haunted "
     "house", {"darkness": "night", "fog": "a green murk", "light": "moonlight",
               "vision": "moonless"}),
    ("sunset", "Sunset glow", "Low warm light from the west and a pink evening sky - a beach, "
     "a race at dusk", {"hour": "late, from the west", "light": "a sunset",
                        "fog": "a pink evening"}),
    ("sunny", "Sunny day", "A warm sun from overhead - a park, a sports field",
     {"hour": "overhead", "light": "a warm sun"}),
    ("night", "Night", "A cold moonlit night - a city, a hide-and-seek map",
     {"darkness": "night", "light": "moonlight", "hour": "low and behind"}),
    ("underwater", "Underwater", "Blue-green and dim, as on the sea floor - a sunken ship",
     {"darkness": "under water", "fog": "a blue distance", "colour": "verdigris",
      "weather": "bubbles, deep under water"}),
    ("spring", "Spring", "Flower petals drift over a warm day - a garden, a picnic",
     {"weather": "flower petals on the ground", "light": "a warm sun"}),
    ("desert", "Desert heat", "Dusty yellow air under a bleaching sun - a desert, a canyon",
     {"fog": "sulphur", "light": "a warm sun", "vision": "sun-bleached"}),
    ("volcano", "Volcano", "A red haze and firelight - a lava cave, Bowser's keep",
     {"fog": "a red haze", "light": "firelight", "darkness": "a red night"}),
    ("oldfilm", "Old film", "Faded and warm, like an old photograph - a western town",
     {"vision": "an old photograph", "colour": "sepia"}),
    ("dusk", "Dusk", "The sun is down and the lamps come on - a village at evening",
     {"darkness": "dusk", "hour": "late, from the west", "light": "a sunset"}),
    ("purple", "Purple hour", "Violet twilight after the sun - castle ruins, a quiet valley",
     {"darkness": "a purple hour", "hour": "low and behind", "fog": "a pink evening"}),
]
PRESET_KEYS = [p[0] for p in PRESETS]
PRESET_BY_KEY = {p[0]: p for p in PRESETS}
NONE_LABEL = "None"
def clean(mood):
    if not isinstance(mood, dict):
        return {}
    out = {}
    for field in FIELD_ORDER:
        stop = mood.get(field)
        if isinstance(stop, str) and stop in FIELDS[field][2]:
            out[field] = stop
    if isinstance(mood.get("vision"), str) and mood["vision"] in LOOKS:
        out["vision"] = mood["vision"]
    dials = {}
    for name, lo, hi, _step, _rest in DIALS:
        v = (mood.get("dials") or {}).get(name) if isinstance(mood.get("dials"), dict) else None
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            dials[name] = round(min(hi, max(lo, float(v))), 3)
    if dials:
        out["dials"] = dials
    if isinstance(mood.get("preset"), str) and mood["preset"] in PRESET_BY_KEY:
        if preset(mood["preset"]) == {k: v for k, v in out.items()}:
            out["preset"] = mood["preset"]
    return out
def preset(key):
    p = PRESET_BY_KEY.get(key)
    return copy.deepcopy(p[3]) if p is not None else None
def of_preset(key):
    m = preset(key)
    if m is None:
        return None
    if m:
        m["preset"] = key
    return m
def which_preset(mood):
    m = {k: v for k, v in clean(mood).items() if k != "preset"}
    for key, _label, _tip, want in PRESETS:
        if m == want:
            return key
    return None
def label(mood):
    m = clean(mood)
    key = which_preset(m)
    if key is not None:
        return PRESET_BY_KEY[key][1]
    parts = [m[f] for f in FIELD_ORDER if f in m]
    if "vision" in m:
        parts.append(m["vision"])
    if "dials" in m:
        parts.append("%d dial%s" % (len(m["dials"]), "" if len(m["dials"]) == 1 else "s"))
    return ", ".join(parts) if parts else "Clear"
def look_dials(mood):
    m = clean(mood)
    out = {name: rest for name, _lo, _hi, _step, rest in DIALS}
    dither = False
    for k, v in LOOKS.get(m.get("vision"), {}).items():
        if k == "dithering":
            dither = True
        else:
            out[k] = v
    out.update(m.get("dials") or {})
    out["dithering"] = 1.0 if dither else 0.0
    return out
LUA_NAMES = {"light": "shade"}
def lua_fields(look):
    if not isinstance(look, dict):
        return ""
    m = clean(look.get("mood"))
    out = ""
    for field in FIELD_ORDER:
        if field in m:
            out += ', %s = "%s"' % (LUA_NAMES.get(field, field), m[field])
    if "vision" in m:
        out += ', vision = "%s"' % m["vision"]
    if "dials" in m:
        out += ", dials = { %s }" % ", ".join("%s = %s" % (k, _num(m["dials"][k]))
                                             for k in DIAL_NAMES if k in m["dials"])
    return out
def _num(v):
    v = round(float(v), 3)
    return ("%d" % v) if v == int(v) else ("%s" % v)
def keep(old_look, layout):
    mood = (old_look or {}).get("mood") if isinstance(old_look, dict) else None
    if not isinstance(mood, dict) or not isinstance(layout, dict):
        return layout
    look = layout.get("look") if isinstance(layout.get("look"), dict) else {}
    if isinstance(look.get("mood"), dict):
        return layout
    out = dict(layout)
    out["look"] = dict(copy.deepcopy(look), mood=copy.deepcopy(mood))
    return out
MOOD_WORDS = [
    (r"\bgewitter\w*|\bthunderstorm\w*|\bstormy\b|\bstuermisch\w*|\bunwetter\w*", "storm"),
    (r"\bschneesturm\w*|\bblizzard\w*", "blizzard"),
    (r"\bverschneit\w*|\bsnowy\b|\bsnowing\b|\bes schneit\b|\bwinterlich\w*|\bwintry\b|"
     r"\bfalling snow\b|\bsnow ?fall\w*|\bschneefall\w*", "snow"),
    (r"\bregnerisch\w*|\brainy\b|\braining\b|\bes regnet\b|\bverregnet\w*|\bim regen\b|"
     r"\bin the rain\b", "rain"),
    (r"\bneblig\w*|\bnebelig\w*|\bfoggy\b|\bmisty\b|\bim nebel\b|\bin the fog\b", "foggy"),
    (r"\bgruselig\w*|\bspooky\b|\bcreepy\b|\bunheimlich\w*|\bschaurig\w*|\bhaunted\b|"
     r"\bspuk\w*|\bscary\b|\bbeaengstigend\w*", "spooky"),
    (r"\bpurple hour\b|\bviolet hour\b|\blila stunde\b|\bviolette(n)? stunde\b", "purple"),
    (r"\bat dusk\b|\bdusk\b|\btwilight\b|\bdaemmerung\b|\bdämmerung\b|\babenddaemmerung\b|"
     r"\bin der daemmerung\b", "dusk"),
    (r"\bsonnenuntergang\w*|\bsunset\b|\babendrot\w*|\babendstimmung\b", "sunset"),
    (r"\bunter ?wasser\b|\bunderwater\b|\bunder water\b|\bmeeresgrund\w*|\bsea floor\b", "underwater"),
    (r"\bvulkan\w*|\bvolcan\w*", "volcano"),
    (r"\bfruehling\w*|\bspringtime\b|\bin spring\b", "spring"),
    (r"\bsonnig\w*|\bsunny\b", "sunny"),
    (r"\bbirthday\w*|\bgeburtstag\w*|\bfeier\w*",
     "sunny"),
    (r"\bnachts\b|\bbei nacht\b|\bat night\b|\bnight ?time\b|\bnaechtlich\w*|"
     r"\bnight\b|\bnacht\w*|\bdunkel\w*|\bdark\b|\bfinster\w*", "night"),
    (r"\bwuestenhitze\b|\bdesert heat\b|\bheisse wueste\b|\bhot desert\b", "desert"),
    (r"\balter film\b|\bold film\b|\bold movie\b|\balte(s|r)? foto\w*|\bold photo\w*", "oldfilm"),
    (r"\bklares wetter\b|\bclear weather\b|\bclear sky\b|\bklarer himmel\b|\bkein wetter\b|"
     r"\bno weather\b", "clear"),
]
def from_wish(text):
    import re
    from . import negation
    from .wish import fold
    low = fold(text or "")
    for pat, key in MOOD_WORDS:
        for m in re.finditer(pat, low):
            before = low[max(0, m.start() - 12):m.start()]
            if re.search(r"\b(no|not|without|kein\w*|ohne|nicht)\s+(\w+\s+)?$", before) \
                    or negation.negated(low, m.start()):
                continue
            return key
    return None
def for_brief(key):
    if key in (None, "auto"):
        return None
    return of_preset(key)
FOG_PREVIEW = {
    "hazy": (0.30, None), "thick": (0.55, None), "pea soup": (0.80, None),
    "a red haze": (0.55, (175, 85, 80)), "sulphur": (0.62, (185, 175, 90)),
    "a blue distance": (0.45, (105, 130, 180)), "a green murk": (0.60, (105, 160, 110)),
    "smoke": (0.70, (90, 88, 92)), "a pink evening": (0.35, (200, 150, 175)),
}
DARK_PREVIEW = {
    "dusk": (100, 100, 100), "night": (70, 70, 70), "pitch": (45, 45, 45),
    "a red night": (110, 45, 45), "a green murk": (50, 100, 60), "a cold blue": (50, 70, 115),
    "sodium dusk": (120, 85, 40), "a purple hour": (95, 55, 120),
    "hospital light": (105, 125, 105), "under water": (45, 85, 105),
}
TINT_PREVIEW = {
    "sepia": (255, 205, 150), "rust": (255, 130, 90), "verdigris": (120, 220, 180),
    "ice": (150, 195, 255), "a bruise": (175, 130, 235), "gold": (255, 215, 70),
    "ash": (145, 145, 145), "bleached": (250, 250, 250), "a shadow of itself": (60, 60, 70),
}
PARTICLES = {
    "snow": ("dot", (1.0, 1.0, 1.0), 70, 0), "a blizzard": ("dot", (1.0, 1.0, 1.0), 220, 6),
    "flower petals on the ground": ("dot", (1.0, 0.65, 0.80), 45, 0),
    "bubbles, deep under water": ("ring", (0.75, 0.90, 1.0), 40, 0),
    "lava bubbles, over lava": ("ring", (1.0, 0.45, 0.15), 30, 0),
    "rain": ("streak", (0.70, 0.78, 0.92), 120, 14),
    "a thunderstorm": ("streak", (0.70, 0.75, 0.90), 200, 18),
}
def preview(mood, background=(0.18, 0.2, 0.23)):
    m = clean(mood)
    fog, fog_col = 0.0, tuple(background)
    if "fog" in m:
        fog, hue = FOG_PREVIEW[m["fog"]]
        if hue is not None:
            fog_col = tuple(c / 255.0 for c in hue)
        else:
            fog_col = (0.62, 0.64, 0.66)
    mul = [1.0, 1.0, 1.0]
    if "darkness" in m:
        mul = [c / 127.0 for c in DARK_PREVIEW[m["darkness"]]]
    if "colour" in m:
        mul = [a * b / 255.0 for a, b in zip(mul, TINT_PREVIEW[m["colour"]])]
    dials = look_dials(m)
    parts = PARTICLES.get(m.get("weather"))
    unshown = []
    if m.get("weather") == "a thunderstorm":
        unshown.append("the lightning and thunder")
    if m.get("weather") in ("bubbles, deep under water", "lava bubbles, over lava"):
        unshown.append("bubbles only rise in deep water or over lava")
    if dials.get("dithering"):
        unshown.append("the stipple")
    if "hour" in m:
        unshown.append("the hour's turning shade on single pieces")
    return {"fog": fog, "fog_colour": fog_col, "multiply": tuple(mul), "dials": dials,
            "particles": parts, "unshown": unshown, "light": m.get("light")}
