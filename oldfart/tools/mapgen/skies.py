SKIES = (
    ("BACKGROUND_OCEAN_SKY", "Ocean sky"),
    ("BACKGROUND_FLAMING_SKY", "Flaming sky"),
    ("BACKGROUND_UNDERWATER_CITY", "Underwater city"),
    ("BACKGROUND_BELOW_CLOUDS", "Below the clouds"),
    ("BACKGROUND_SNOW_MOUNTAINS", "Snow mountains"),
    ("BACKGROUND_DESERT", "Desert"),
    ("BACKGROUND_HAUNTED", "Haunted"),
    ("BACKGROUND_GREEN_SKY", "Green sky"),
    ("BACKGROUND_ABOVE_CLOUDS", "Above the clouds"),
    ("BACKGROUND_PURPLE_SKY", "Purple sky"),
)
AUTO = "auto"
AUTO_LABEL = "Theme default"
LOOK = {
    "BACKGROUND_OCEAN_SKY": ((112, 124, 255), (137, 194, 250), (10, 90, 224), "sea"),
    "BACKGROUND_FLAMING_SKY": ((137, 15, 0), (173, 43, 2), (94, 27, 0), "hills"),
    "BACKGROUND_UNDERWATER_CITY": ((1, 145, 255), (45, 40, 140), (101, 90, 135), "towers"),
    "BACKGROUND_BELOW_CLOUDS": ((4, 4, 74), (64, 102, 255), (183, 212, 255), "clouds"),
    "BACKGROUND_SNOW_MOUNTAINS": ((136, 147, 246), (189, 198, 243), (107, 155, 219), "peaks"),
    "BACKGROUND_DESERT": ((80, 85, 238), (145, 182, 205), (198, 162, 108), "dunes"),
    "BACKGROUND_HAUNTED": ((14, 13, 64), (21, 21, 89), (0, 0, 3), "towers"),
    "BACKGROUND_GREEN_SKY": ((0, 24, 34), (0, 56, 40), (0, 35, 26), "hills"),
    "BACKGROUND_ABOVE_CLOUDS": ((154, 200, 250), (141, 194, 250), (53, 110, 204), "clouds"),
    "BACKGROUND_PURPLE_SKY": ((40, 19, 119), (104, 29, 80), (64, 21, 131), "peaks"),
}
def names():
    return [k for k, _ in SKIES]
def label(name):
    if name in (None, AUTO):
        return AUTO_LABEL
    return dict(SKIES).get(name, str(name).replace("BACKGROUND_", "").replace("_", " ").title())
def valid(name):
    return name == AUTO or name in dict(SKIES)
def for_theme(theme):
    from . import kit
    return kit.LOOKS.get(theme, kit.LOOKS["castle"])[0]
def thumbnail(name, w=64, h=40, theme=None):
    from PIL import Image, ImageDraw
    auto = name in (None, AUTO)
    key = for_theme(theme or "castle") if auto else name
    top, low, ground, motif = LOOK.get(key, LOOK["BACKGROUND_OCEAN_SKY"])
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / float(max(1, h - 1))
        c = tuple(int(top[i] + (low[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    d = ImageDraw.Draw(img)
    base = int(h * 0.72)
    if motif == "sea":
        d.rectangle((0, base, w, h), fill=ground)
    elif motif == "peaks":
        for k, x in enumerate(range(-w // 4, w, w // 3)):
            d.polygon(((x, h), (x + w // 6, int(h * (0.35 + 0.1 * (k % 2)))), (x + w // 3, h)),
                      fill=ground)
    elif motif == "dunes" or motif == "hills":
        for k, x in enumerate(range(-w // 3, w, w // 3)):
            d.ellipse((x, base - h // 8 + (k % 2) * 3, x + w // 2, base + h // 3), fill=ground)
        d.rectangle((0, base + h // 8, w, h), fill=ground)
    elif motif == "clouds":
        for k, x in enumerate(range(0, w, w // 4)):
            d.ellipse((x - 4, base - 4 - (k % 2) * 3, x + w // 4 + 4, base + 8), fill=ground)
        d.rectangle((0, base + 4, w, h), fill=ground)
    elif motif == "towers":
        for k, x in enumerate(range(2, w, w // 5)):
            d.rectangle((x, int(h * (0.45 + 0.1 * (k % 3))), x + w // 10, h), fill=ground)
    if auto:
        d.polygon(((w - 12, 0), (w, 0), (w, 12)), fill=(255, 255, 255))
    return img
