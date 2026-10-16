from . import kit
KINDS = ("tower", "lighthouse", "obelisk", "gate", "temple", "watchtower",
         "windmill", "belltower", "keep", "ruin", "statue", "pyramid", "spirerock", "fountain",
         "shrine", "greattree", "marketsquare", "fortress", "domedhall", "well",
         "shipwreck", "courtyard")
OLD_KINDS = KINDS[:6]
HALF = 600
MIN_PIECES, MAX_PIECES = 6, 20
PIECES = {"keep": (24, 40), "pyramid": (10, 16), "spirerock": (16, 34), "greattree": (14, 30),
          "marketsquare": (14, 26), "domedhall": (14, 20), "fortress": (10, 16),
          "lighthouse": (6, 24), "fountain": (8, 12), "shrine": (8, 10), "statue": (7, 10),
          "ruin": (8, 13), "windmill": (12, 18), "belltower": (12, 18),
          "well": (9, 9),
          "shipwreck": (10, 14), "courtyard": (13, 16)}
FOOT = {"keep": 9, "pyramid": 7, "spirerock": 5, "greattree": 7, "marketsquare": 5,
        "domedhall": 5, "fortress": 7, "lighthouse": 5, "ruin": 5, "windmill": 5, "shrine": 5,
        "shipwreck": 5, "courtyard": 5}
SCOPE_SLACK = 260
META = {
    "tower": ("secondary", None, "vantage"),
    "lighthouse": ("secondary", "lantern", "vantage"),
    "obelisk": ("secondary", "needle", "slot"),
    "gate": ("tertiary", "arch", "crossing"),
    "temple": ("secondary", "dome", "shelter"),
    "watchtower": ("secondary", "pyramid on legs", "vantage"),
    "windmill": ("secondary", "cross of sails", "slot"),
    "belltower": ("secondary", "belfry and spire", "slot"),
    "keep": ("primary", "battlements", "courtyard"),
    "ruin": ("secondary", "broken top", "hiding"),
    "statue": ("tertiary", "figure", "slot"),
    "pyramid": ("primary", "stepped", "climb"),
    "spirerock": ("primary", "rock spire", "climb"),
    "fountain": ("tertiary", "bowl", "node"),
    "shrine": ("tertiary", "shrine gate", "slot"),
    "greattree": ("primary", "canopy", "climb"),
    "marketsquare": ("tertiary", "awnings", "node"),
    "fortress": ("primary", "terraced crown", "climb"),
    "domedhall": ("secondary", "dome and finial", "interior"),
    "well": ("tertiary", "well roof", "node"),
    "shipwreck": ("secondary", "broken mast and flag", "hiding"),
    "courtyard": ("tertiary", "corner turrets", "courtyard"),
}
TIERS = ("primary", "secondary", "tertiary")
SET_PIECES = ("shipwreck", "courtyard")
THEME_KINDS = {
    "castle": ("tower", "gate", "watchtower", "belltower", "keep", "fortress"),
    "garden": ("temple", "obelisk", "gate", "fountain", "shrine", "windmill"),
    "lava": ("obelisk", "tower", "watchtower", "ruin", "fortress", "pyramid"),
    "ice": ("lighthouse", "obelisk", "tower", "ruin", "spirerock"),
    "desert": ("obelisk", "temple", "gate", "pyramid", "domedhall", "statue"),
    "sky": ("lighthouse", "temple", "tower", "belltower", "spirerock"),
    "wood": ("watchtower", "tower", "gate", "windmill", "greattree", "ruin"),
    "village": ("windmill", "belltower", "fountain", "gate", "tower", "courtyard"),
    "forest": ("greattree", "watchtower", "ruin", "shrine"),
    "temple": ("temple", "shrine", "pyramid", "domedhall", "statue"),
    "water": ("lighthouse", "spirerock", "statue", "fountain", "shipwreck"),
    "haunted": ("ruin", "belltower", "statue", "tower"),
    "crystal": ("obelisk", "spirerock", "domedhall", "temple"),
    "machine": ("tower", "belltower", "fortress", "watchtower"),
}
FEATURE_KIND = {"lighthouse": "lighthouse", "obelisk": "obelisk", "watchtower": "watchtower",
                "temple": "temple", "gate": "gate", "windmill": "windmill",
                "fountain": "fountain", "ruin": "ruin", "statue": "statue",
                "pyramid": "pyramid", "keep": "keep", "castle": "keep",
                "belltower": "belltower", "spirerock": "spirerock", "shrine": "shrine",
                "greattree": "greattree", "marketsquare": "marketsquare",
                "fortress": "fortress", "domedhall": "domedhall", "well": "well",
                "shipwreck": "shipwreck", "courtyard": "courtyard"}
def _box(tex, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(tex, x0, x1, y0, y1, z0, z1, None, tag)
def _pillar(tex, x, z, y0, y1, w, tag):
    return kit.kind("pillar").make(tex, x - w // 2, x + w // 2, y0, y1, z - w // 2, z + w // 2,
                                   None, tag)
def _pyramid(tex, a, y0, y1, tag, x=0, z=0):
    return kit.kind("pyramid").make(tex, x - a, x + a, y0, y1, z - a, z + a, "x", tag)
def _accent(pal):
    a = pal.get("accent")
    return a if a and a in kit.textures() else (pal.get("trim") or pal.get("wall") or "greystone")
def _texes(pal):
    wall = pal.get("wall") or "greystone"
    trim = pal.get("trim") or wall
    roof = pal.get("roof") or kit.for_kind("pyramid", [trim, wall], "roof")
    deck = pal.get("deck") or trim
    return wall, trim, roof, deck
def tower(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    out = [_box(trim, -500, 500, 0, 200, -500, 500, tag + ".base")]
    n = r.choice((3, 4, 5))
    setback = r.random() < 0.5
    y = 200
    a = 400
    for k in range(n):
        h = 400 if k else 600
        out.append(_box(wall if (k % 2 == 0 or setback) else trim, -a, a, y, y + h, -a, a,
                        tag + ".storey"))
        y += h
        if setback and k % 2 == 1 and a > 300:
            a -= 50
    crown = r.choice(("battlement", "roof", "lantern"))
    if crown == "battlement":
        out.append(_box(deck, -a - 50, a + 50, y, y + 100, -a - 50, a + 50, tag + ".deck"))
        y += 100
        for sx in (-1, 1):
            for sz in (-1, 1):
                x0 = sx * (a + 50) - (100 if sx > 0 else -100) - 100
                z0 = sz * (a + 50) - (100 if sz > 0 else -100) - 100
                out.append(_box(wall, x0, x0 + 200, y, y + 200, z0, z0 + 200, tag + ".merlon"))
        out.append(_pillar(trim, 0, 0, y, y + 600, 100, tag + ".pole"))
        out.append(_box(_accent(pal), 50, 350, y + 400, y + 600, -10, 10, tag + ".accent"))
        y += 600
    elif crown == "roof":
        out.append(_box(trim, -a - 50, a + 50, y, y + 100, -a - 50, a + 50, tag + ".cornice"))
        y += 100
        out.append(_pyramid(roof, a + 50, y, y + 600, tag + ".roof"))
        y += 600
        out.append(_pillar(_accent(pal), 0, 0, y, y + 200, 100, tag + ".accent"))
        y += 200
    else:
        out.append(_box(deck, -a, a, y, y + 100, -a, a, tag + ".deck"))
        y += 100
        for sx in (-1, 1):
            for sz in (-1, 1):
                out.append(_pillar(trim, sx * (a - 75), sz * (a - 75), y, y + 400, 150,
                                   tag + ".post"))
        y += 400
        out.append(_pyramid(roof, a, y, y + 400, tag + ".roof"))
        y += 400
        out.append(_pillar(_accent(pal), 0, 0, y, y + 200, 100, tag + ".accent"))
        y += 200
    return out, y
def lighthouse(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    lift = 0
    out = []
    if r.random() < 0.35:
        rock = pal.get("rock") or wall
        for sx in (-1, 1):
            x0, x1 = sorted((sx * 500, sx * 1000))
            out.append(_box(rock, x0, x1, 0, 1200, -600, 600, tag + ".pier"))
        out.append(_box(rock, -1000, 1000, 1200, 1600, -600, 600, tag + ".lintel"))
        lift = 1600
    out += [_box(trim, -600, 600, lift, lift + 100, -600, 600, tag + ".base"),
            _box(wall, -450, 450, lift + 100, lift + 300, -450, 450, tag + ".base")]
    y = lift + 300
    bands = r.choice((3, 4))
    for k in range(bands):
        h = r.choice((500, 600))
        out.append(_pillar(wall if k % 2 == 0 else trim, 0, 0, y, y + h, 600, tag + ".drum"))
        y += h
    out.append(_box(deck, -450, 450, y, y + 100, -450, 450, tag + ".gallery"))
    y += 100
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(_pillar(trim, sx * 250, sz * 250, y, y + 300, 100, tag + ".lantern"))
    y += 300
    out.append(_pyramid(roof, 350, y, y + 300, tag + ".roof"))
    out.append(_pillar(_accent(pal), 0, 0, y + 300, y + 500, 100, tag + ".accent"))
    return out, y + 500
def obelisk(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    out = []
    y = 0
    for a in (600, 450, 300):
        out.append(_box(trim if a != 450 else wall, -a, a, y, y + 100, -a, a, tag + ".dais"))
        y += 100
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(_pillar(trim, sx * 525, sz * 525, 100, 100 + r.choice((300, 400)), 100,
                               tag + ".post"))
    h = r.choice((1600, 2000, 2400))
    w = r.choice((150, 200))
    out.append(_box(wall, -w, w, y, y + h, -w, w, tag + ".needle"))
    y += h
    out.append(_pyramid(_accent(pal), w, y, y + 300, tag + ".accent"))
    return out, y + 300
def gate(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    out = []
    ph = r.choice((1000, 1200))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 400, sx * 800))
        out.append(_box(trim, x0 - (50 if sx < 0 else 0), x1 + (50 if sx > 0 else 0), 0, 200,
                        -250, 250, tag + ".pierbase"))
        out.append(_box(wall, x0, x1, 200, ph, -200, 200, tag + ".pier"))
    out.append(kit.kind("arch").make(wall, -400, 400, ph - 400, ph, -200, 200, None,
                                     tag + ".arch"))
    out.append(_box(trim, -850, 850, ph, ph + 200, -250, 250, tag + ".lintel"))
    out.append(_box(wall, -700, 700, ph + 200, ph + 500, -200, 200, tag + ".attic"))
    for sx in (-1, 1):
        out.append(_pyramid(roof, 150, ph + 500, ph + 800, tag + ".finial", x=sx * 550))
    cloth = pal.get("awning")
    if cloth and r.random() < 0.6:
        for sx in (-1, 1):
            x0, x1 = sorted((sx * 500, sx * 700))
            out.append(_box(cloth, x0, x1, ph - 700, ph - 300, 200, 220, tag + ".banner"))
    return out, ph + 800
def temple(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    out = [_box(trim, -600, 600, 0, 150, -600, 600, tag + ".platform")]
    ch = r.choice((700, 800, 900))
    for x in (-500, 0, 500):
        for z in (-500, 0, 500):
            if x == 0 and z == 0:
                continue
            out.append(_pillar(wall, x, z, 150, 150 + ch, 120, tag + ".column"))
    y = 150 + ch
    out.append(_box(trim, -600, 600, y, y + 100, -600, -450, tag + ".entablature"))
    out.append(_box(trim, -600, 600, y, y + 100, 450, 600, tag + ".entablature"))
    out.append(_box(trim, -600, -450, y, y + 100, -450, 450, tag + ".entablature"))
    out.append(_box(trim, 450, 600, y, y + 100, -450, 450, tag + ".entablature"))
    y += 100
    dh = r.choice((300, 400))
    out.append(_pyramid(roof, 600, y, y + dh, tag + ".dome"))
    out.append(_pillar(_accent(pal), 0, 0, y + dh, y + dh + 200, 100, tag + ".accent"))
    return out, y + dh + 200
def watchtower(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    wood = "darkplanks" if "darkplanks" in kit.textures() else wall
    out = []
    lh = r.choice((1000, 1200, 1400))
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(_pillar(wood, sx * 350, sz * 350, 0, lh, 120, tag + ".leg"))
    out.append(_box(deck, -500, 500, lh, lh + 100, -500, 500, tag + ".platform"))
    y = lh + 100
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(_pillar(wood, sx * 425, sz * 425, y, y + 400, 100, tag + ".post"))
    y += 400
    out.append(_pyramid(roof, 550, y, y + 400, tag + ".roof"))
    out.append(_pillar(_accent(pal), 0, 0, y + 400, y + 600, 100, tag + ".accent"))
    return out, y + 600
def _make(kind, tex, x0, x1, y0, y1, z0, z1, rises, tag):
    return kit.kind(kind).make(tex, x0, x1, y0, y1, z0, z1, rises, tag)
def _more(pal):
    wall, trim, roof, deck = _texes(pal)
    have = kit.textures()
    def first(*names):
        for n in names:
            if n and n in have and not kit.layered(n):
                return n
        return None
    water = [s for s, t in sorted(have.items()) if "water" in (t.get("roles") or ())]
    return {
        "rock": first(pal.get("rock"), "mossyrock", "greystone") or wall,
        "worn": first(pal.get("worn"), "mossyrock") or wall,
        "bark": first(pal.get("bark"), "barkoak", "darkplanks") or trim,
        "leaves": first(pal.get("leaves"), pal.get("foliage"), "leaves", "leavesoak", "hedge")
        or trim,
        "accent": first(pal.get("accent")) or trim,
        "planks": first(pal.get("planks"), "darkplanks") or deck,
        "awning": first(pal.get("awning")),
        "water": first(*water),
        "path": first(pal.get("path"), pal.get("road")) or deck,
        "door": first(pal.get("door")),
        "door_top": first(pal.get("door_top"), pal.get("door")),
    }
def windmill(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = [_pillar(wall, 0, 0, 0, 800, 800, tag + ".drum"),
           _pillar(deck, 0, 0, 800, 840, 1100, tag + ".gallery"),
           _pillar(trim, 0, 0, 840, 1440, 700, tag + ".drum"),
           _pillar(wall, 0, 0, 1440, 2040, 600, tag + ".drum"),
           _pyramid(roof, 350, 2040, 2440, tag + ".cap"),
           _pillar(m["accent"], 0, 0, 2440, 2640, 100, tag + ".accent")]
    out.append(_box(trim, -100, 100, 1640, 1840, 300, 560, tag + ".hub"))
    wood = m["planks"]
    out.append(_box(wood, -1100, 1100, 1690, 1790, 560, 600, tag + ".arm"))
    out.append(_box(wood, -50, 50, 1790, 2840, 560, 600, tag + ".arm"))
    out.append(_box(wood, -50, 50, 640, 1690, 560, 600, tag + ".arm"))
    for x0, x1, y0, y1 in ((50, 350, 1790, 2690), (-350, -50, 790, 1690), (150, 1050, 1390, 1690),
                           (-1050, -150, 1790, 2090)):
        out.append(_box(wood, x0, x1, y0, y1, 570, 590, tag + ".blade"))
    if m["door"]:
        out.append(_box(m["door"], -100, 100, 0, 200, 400, 420, tag + ".door"))
        out.append(_box(m["door_top"], -100, 100, 200, 400, 400, 420, tag + ".door"))
    return out, 2840
def belltower(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = [_box(trim, -400, 400, 0, 200, -400, 400, tag + ".base")]
    h = r.choice((2400, 2700, 3000))
    h1 = h * 2 // 3 // 100 * 100
    out.append(_box(wall, -300, 300, 200, 200 + h1, -300, 300, tag + ".shaft"))
    y = 200 + h1
    out.append(_box(trim, -350, 350, y, y + 100, -350, 350, tag + ".band"))
    y += 100
    out.append(_box(wall, -300, 300, y, y + h - h1, -300, 300, tag + ".shaft"))
    y += h - h1
    faces = r.choice((1, 2, 4))
    for k, (x0, x1, z0, z1) in enumerate(((-150, 150, 300, 320), (-150, 150, -320, -300),
                                          (300, 320, -150, 150), (-320, -300, -150, 150))):
        if k < faces:
            out.append(_box(m["accent"], x0, x1, y - 400, y - 200, z0, z1, tag + ".clock"))
    out.append(_box(deck, -350, 350, y, y + 100, -350, 350, tag + ".belfry"))
    y += 100
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(_pillar(trim, sx * 300, sz * 300, y, y + 500, 100, tag + ".post"))
    out.append(_box(m["accent"], -100, 100, y + 300, y + 500, -100, 100, tag + ".accent"))
    y += 500
    out.append(_pyramid(roof, 350, y, y + 800, tag + ".spire"))
    y += 800
    out.append(_pillar(m["accent"], 0, 0, y, y + 300, 100, tag + ".accent"))
    return out, y + 300
def keep(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = [_box(trim, -600, 600, 0, 200, -600, 600, tag + ".base"),
           _box(wall, -500, 500, 200, 3600, -500, 500, tag + ".body"),
           _box(deck, -600, 600, 3600, 3700, -600, 600, tag + ".deck")]
    for x, z in ((-500, -500), (0, -500), (500, -500), (-500, 0), (500, 0), (-500, 500),
                 (0, 500), (500, 500)):
        h = 300 if (x, z) != (0, 500) else 200
        out.append(_box(wall, x - 100, x + 100, 3700, 3700 + h, z - 100, z + 100,
                        tag + ".merlon"))
    out.append(_pillar(trim, 0, 0, 3700, 4300, 100, tag + ".pole"))
    out.append(_box(m["accent"], 50, 350, 4100, 4300, -10, 10, tag + ".accent"))
    out.append(_box(wall, -1100, 1100, 0, 1000, -1600, -1200, tag + ".curtain"))
    out.append(_box(wall, -1100, -300, 0, 1000, 1200, 1600, tag + ".curtain"))
    out.append(_box(wall, 300, 1100, 0, 1000, 1200, 1600, tag + ".curtain"))
    out.append(_box(wall, -1600, -1200, 0, 1000, -1100, 1100, tag + ".curtain"))
    out.append(_box(wall, 1200, 1600, 0, 1000, -1100, 1100, tag + ".curtain"))
    out.append(_make("arch", wall, -300, 300, 600, 1000, 1200, 1600, None, tag + ".gate"))
    out.append(_box(trim, -500, 500, 1000, 1400, 1100, 1700, tag + ".gatehouse"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            x0, x1 = sorted((sx * 1100, sx * 1700))
            z0, z1 = sorted((sz * 1100, sz * 1700))
            out.append(_box(wall, x0, x1, 0, 1600, z0, z1, tag + ".tower"))
            out.append(_pyramid(roof, 350, 1600, 2100, tag + ".cap", x=sx * 1400, z=sz * 1400))
    if m["door"]:
        out.append(_box(m["door"], -100, 100, 200, 400, 500, 520, tag + ".door"))
        out.append(_box(m["door_top"], -100, 100, 400, 600, 500, 520, tag + ".door"))
    out.append(_box(trim, -200, 200, 0, 200, 600, 800, tag + ".step"))
    return out, 4300
def ruin(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    worn = m["worn"]
    h = r.choice((800, 1200, 1600))
    out = [_box(worn, -600, 200, 0, h, -600, 200, tag + ".stump")]
    for x0, z0, jh in ((-600, -600, 400), (0, -600, 200), (-600, 0, 200)):
        out.append(_box(worn, x0, x0 + 200, h, h + jh, z0, z0 + 200, tag + ".jag"))
    out.append(_box(m["accent"], -600, -400, h + 400, h + 600, -600, -400, tag + ".accent"))
    out.append(_box(worn, 400, 600, 0, 600, -200, 1000, tag + ".stub"))
    out.append(_box(worn, -400, 400, 0, 400, 800, 1000, tag + ".stub"))
    out.append(_box(m["path"], -400, 400, 0, 20, 200, 800, tag + ".floor"))
    out.append(_box(worn, -1000, -700, 0, 200, -200, 400, tag + ".fallen"))
    out.append(_make("ramp", worn, -1000, -700, 0, 200, 400, 800, "-z", tag + ".fallen"))
    return out, h + 600
def statue(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    stone = m["rock"]
    out = [_box(trim, -500, 500, 0, 200, -400, 400, tag + ".plinth"),
           _box(stone, -400, 400, 200, 1400, -300, 300, tag + ".head"),
           _box(stone, -450, 450, 1000, 1100, 300, 400, tag + ".brow"),
           _box(m["accent"], -300, -100, 900, 1000, 300, 320, tag + ".eye"),
           _box(m["accent"], 100, 300, 900, 1000, 300, 320, tag + ".eye"),
           _box(stone, -100, 100, 500, 1000, 300, 500, tag + ".nose"),
           _box(trim, -200, 200, 450, 500, 300, 320, tag + ".mouth"),
           _box(m["accent"], -100, 100, 1400, 1600, -100, 100, tag + ".accent")]
    return out, 1600
def pyramid(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = []
    halves = (1200, 900, 600, 300)
    y = 0
    for k, a in enumerate(halves):
        out.append(_box(wall if k % 2 == 0 else trim, -a, a, y, y + 250, -a, a, tag + ".tier"))
        out.append(_make("stairs", m["path"], -200, 200, y, y + 250, a, a + 300, "-z",
                         tag + ".stairs"))
        y += 250
    out.append(_box(wall, -200, 200, y, y + 400, -300, 100, tag + ".shrine"))
    out.append(_pyramid(roof, 250, y + 400, y + 700, tag + ".roof", z=-100))
    out.append(_pillar(m["accent"], 0, -100, y + 700, y + 900, 100, tag + ".accent"))
    return out, y + 900
def _ledges(tiers, start_top, rise, count, tex, tag, skip=(), depth=400, size=400, gap=100,
            middles=False, slot0=0):
    out = []
    rects = []
    faces = (((-1, 1), (1, 0), (0, 1)), ((1, 1), (0, -1), (1, 0)), ((1, -1), (-1, 0), (0, -1)),
             ((-1, -1), (0, 1), (-1, 0)))
    slot = slot0
    for i in range(count):
        top = start_top + i * rise
        bottom = top - 200
        tier = None
        for t in tiers:
            if t[3] <= bottom < t[4]:
                tier = t
        if tier is None:
            break
        cx, cz, half, _, _ = tier
        length = 2 * half
        per = [length // 2 - size // 2] if middles else \
            list(range(gap, length - size - gap + 1, size + gap))
        lap = len(per) * 4
        k = slot % lap
        slot += 1
        if k in skip:
            continue
        f = faces[k // len(per)]
        s = per[k % len(per)]
        (sx, sz), (ax, az), (nx, nz) = f
        x0 = cx + sx * half + ax * s
        z0 = cz + sz * half + az * s
        x1 = x0 + ax * size + nx * depth
        z1 = z0 + az * size + nz * depth
        rect = (min(x0, x1), max(x0, x1), min(z0, z1), max(z0, z1), bottom, top)
        if any(a[0] < rect[1] and rect[0] < a[1] and a[2] < rect[3] and rect[2] < a[3]
               and a[4] < rect[5] + 300 and rect[4] < a[5] + 300 for a in rects):
            continue
        rects.append(rect)
        out.append(_box(tex, rect[0], rect[1], bottom, top, rect[2], rect[3], tag))
    return out
def spirerock(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    rock = m["rock"]
    tiers = ((0, 0, 600, 0, 1600), (100, 100, 500, 1600, 3200), (0, 0, 400, 3200, 4400))
    out = [_box(rock, cx - a, cx + a, y0, y1, cz - a, cz + a, tag + ".rock")
           for cx, cz, a, y0, y1 in tiers]
    out += _ledges(tiers, 250, 250, 18, rock, tag + ".ledge")
    out.append(_pillar(trim, 0, 0, 4400, 5000, 100, tag + ".pole"))
    out.append(_box(m["accent"], 50, 350, 4800, 5000, -10, 10, tag + ".accent"))
    return out, 5000
def fountain(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    rim = FOUNTAIN_SURFACE + POOL_DROP
    out = [_box(trim, -600, 600, 0, rim, -600, -400, tag + ".rim"),
           _box(trim, -600, 600, 0, rim, 400, 600, tag + ".rim"),
           _box(trim, -600, -400, 0, rim, -400, 400, tag + ".rim"),
           _box(trim, 400, 600, 0, rim, -400, 400, tag + ".rim")]
    if m["water"]:
        for x0, x1, z0, z1 in ((-400, -100, -400, 400), (100, 400, -400, 400),
                               (-100, 100, -400, -100), (-100, 100, 100, 400)):
            out.append(_make("water", m["water"], x0, x1, FOUNTAIN_SURFACE - 20, FOUNTAIN_SURFACE,
                             z0, z1, None, tag + ".water"))
    out.append(_box(trim, -400, 400, 0, BASIN_FLOOR, -400, 400, tag + ".floor"))
    out.append(_pillar(wall, 0, 0, BASIN_FLOOR, 800, 200, tag + ".column"))
    out.append(_pillar(trim, 0, 0, 800, 900, 800, tag + ".bowl"))
    out.append(_pillar(m["accent"], 0, 0, 900, 1200, 100, tag + ".accent"))
    return out, 1200
FOUNTAIN_SURFACE = 220
POOL_DROP = 40
BASIN_FLOOR = 60
def _well(wall, trim, roof, water, y, tag):
    rim = y + FOUNTAIN_SURFACE + POOL_DROP
    out = [_box(wall, -200, 200, y, rim, -200, -150, tag + ".curb"),
           _box(wall, -200, 200, y, rim, 150, 200, tag + ".curb"),
           _box(wall, -200, -150, y, rim, -150, 150, tag + ".curb"),
           _box(wall, 150, 200, y, rim, -150, 150, tag + ".curb")]
    if water:
        out.append(_make("water", water, -150, 150, y + FOUNTAIN_SURFACE - 20, y + FOUNTAIN_SURFACE,
                         -150, 150, None, tag + ".water"))
        out.append(_box(wall, -150, 150, y, y + BASIN_FLOOR, -150, 150, tag + ".floor"))
    else:
        out.append(_box(wall, -150, 150, y, y + 200, -150, 150, tag + ".drum"))
    for px in (-175, 175):
        out.append(_pillar(trim, px, 0, rim, y + 700, 50, tag + ".post"))
    out.append(_pyramid(roof, 300, y + 700, y + 950, tag + ".roof"))
    return out
def well(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    return _well(wall, trim, roof, _more(pal)["water"], 0, tag), 950
def shrine(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    acc = m["accent"]
    out = [_box(trim, -600, 600, 0, 200, -600, 600, tag + ".platform"),
           _make("stairs", m["path"], -200, 200, 0, 200, 600, 1000, "-z", tag + ".stairs")]
    for sx in (-1, 1):
        out.append(_pillar(acc, sx * 400, 450, 200, 1000, 100, tag + ".post"))
    out.append(_box(acc, -550, 550, 1000, 1100, 400, 500, tag + ".accent"))
    out.append(_box(acc, -350, 350, 650, 750, 425, 475, tag + ".beam"))
    out.append(_box(wall, -300, 300, 200, 700, -550, -50, tag + ".hall"))
    out.append(_make("pyramid", roof, -400, 400, 700, 1000, -650, 50, "x", tag + ".roof"))
    return out, 1100
def greattree(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    bark = m["bark"]
    out = [_pillar(bark, 0, 0, 0, 3600, 800, tag + ".trunk")]
    for z0, z1 in ((400, 1000), (-1000, -400)):
        out.append(_box(bark, -100, 100, 0, 200, z0, z1, tag + ".root"))
    steps = _ledges(((0, 0, 400, 0, 3600),), 450, 250, 9, m["planks"], tag + ".ledge",
                    depth=400, size=300, middles=True, slot0=1)
    out += steps
    top = max(p["y"] + p["h"] for p in steps) if steps else 200
    deck_y = top + 250 - 40
    out.append(_box(m["planks"], -400, 400, deck_y, deck_y + 40, -1200, -400, tag + ".deck"))
    leaves = m["leaves"]
    out.append(_box(leaves, -1200, 1200, 3600, 4200, -1200, 1200, tag + ".crown"))
    out.append(_box(leaves, -500, 1100, 4200, 4800, -600, 1000, tag + ".crown"))
    out.append(_box(leaves, -700, 300, 4800, 5200, -800, 200, tag + ".crown"))
    out.append(_box(m["accent"], -300, -100, 5200, 5400, -400, -200, tag + ".accent"))
    return out, 5400
def marketsquare(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = [_box(m["path"], -800, 800, 0, 20, -800, 800, tag + ".paving")]
    y = 20
    for cx in (-400, 400):
        out.append(_box(m["planks"], cx - 300, cx + 300, y, y + 200, -500, -300, "stall.counter"))
        for px in (cx - 250, cx + 250):
            out.append(_pillar(trim, px, -650, y, y + 500, 100, "stall.post"))
        out.append(_make("ramp", m["awning"] or roof, cx - 350, cx + 350, y + 500, y + 600, -700,
                         -200, "-z", "stall.awning.roof"))
    out += _well(wall, trim, roof, m["water"], y, tag + ".well")
    for px in (-700, 700):
        out.append(_pillar(trim, px, 700, y, y + 800, 100, tag + ".lamp"))
        out.append(_box(m["accent"], px - 100, px + 100, y + 800, y + 1000, 600, 800,
                        tag + ".accent"))
    return out, y + 1000
def fortress(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = []
    halves = (1200, 800, 400)
    for k, a in enumerate(halves):
        out.append(_box(wall if k % 2 == 0 else trim, -a, a, 600 * k, 600 * (k + 1), -a, a,
                        tag + ".tier"))
    path = m["path"]
    out.append(_make("ramp", path, -600, 600, 0, 600, 1200, 1540, "+x", tag + ".ramp"))
    out.append(_box(trim, -600, 600, 0, 600, 1540, 1600, tag + ".cheek"))
    out.append(_make("ramp", path, 800, 1140, 600, 1200, -600, 600, "-z", tag + ".ramp"))
    out.append(_box(trim, 1140, 1200, 600, 1200, -600, 600, tag + ".cheek"))
    out.append(_make("ramp", path, -400, 400, 1200, 1800, -740, -400, "-x", tag + ".ramp"))
    out.append(_box(trim, -400, 400, 1200, 1800, -800, -740, tag + ".cheek"))
    out.append(_box(wall, -200, 200, 1800, 2600, -200, 200, tag + ".crown"))
    out.append(_pyramid(roof, 250, 2600, 2900, tag + ".roof"))
    out.append(_pillar(m["accent"], 0, 0, 2900, 3100, 100, tag + ".accent"))
    return out, 3100
def domedhall(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    out = []
    for z0, z1 in ((-1000, -800), (800, 1000)):
        out.append(_box(wall, -1000, -200, 0, 800, z0, z1, tag + ".wall"))
        out.append(_box(wall, 200, 1000, 0, 800, z0, z1, tag + ".wall"))
        out.append(_make("arch", wall, -200, 200, 400, 800, z0, z1, None, tag + ".arch"))
    for x0, x1 in ((-1000, -800), (800, 1000)):
        out.append(_box(wall, x0, x1, 0, 800, -800, -200, tag + ".wall"))
        out.append(_box(wall, x0, x1, 0, 800, 200, 800, tag + ".wall"))
        out.append(_make("arch", wall, x0, x1, 400, 800, -200, 200, None, tag + ".arch"))
    out.append(_box(m["planks"], -800, 800, 0, 20, -800, 800, tag + ".floor"))
    dome = roof if kit.comes_in(roof, "pillar") else trim
    y = 800
    for w in (2000, 1400, 800):
        out.append(_pillar(dome, 0, 0, y, y + 300, w, tag + ".dome"))
        y += 300
    out.append(_pillar(m["accent"], 0, 0, y, y + 300, 100, tag + ".accent"))
    return out, y + 300
def shipwreck(r, pal, tag):
    m = _more(pal)
    planks = m["planks"]
    bark = m["bark"]
    mast = r.choice((1600, 2000, 2400))
    broken = r.choice((-200, 0, 200))
    out = [_box(planks, -800, 800, 0, 200, -300, 300, tag + ".keel"),
           _box(planks, -800, 800, 0, 600, -400, -300, tag + ".side"),
           _box(planks, -800, broken, 0, 600, 300, 400, tag + ".side"),
           _box(planks, -1000, -800, 0, 800, -400, 400, tag + ".stern"),
           _box(planks, 800, 1000, 0, 400, -200, 200, tag + ".bow"),
           _box(planks, -800, 200, 560, 600, -300, 300, tag + ".deck"),
           _box(bark, -800, -500, 600, 900, -300, 300, tag + ".cabin"),
           _pillar(bark, -200, 0, 600, mast, 120, tag + ".mast"),
           _box(planks, -400, 0, mast, mast + 60, -200, 200, tag + ".platform"),
           _box(m["accent"], -220, -180, mast + 60, mast + 360, -20, 20, tag + ".accent")]
    if r.random() < 0.5:
        out.append(_box(planks, 200, 400, 200, 400, -200, 0, tag + ".crate"))
    return out, mast + 360
def courtyard(r, pal, tag):
    wall, trim, roof, deck = _texes(pal)
    m = _more(pal)
    h = r.choice((600, 800))
    gate = r.choice((200, 300))
    out = [_box(wall, -1000, 1000, 0, h, -1000, -800, tag + ".wall"),
           _box(wall, -1000, -800, 0, h, -800, 800, tag + ".wall"),
           _box(wall, 800, 1000, 0, h, -800, 800, tag + ".wall"),
           _box(wall, -1000, -gate, 0, h, 800, 1000, tag + ".wall"),
           _box(wall, gate, 1000, 0, h, 800, 1000, tag + ".wall"),
           _box(trim, -gate, gate, h - 200, h, 800, 1000, tag + ".gate"),
           _box(m["path"], -800, 800, 0, 20, -800, 800, tag + ".floor")]
    for x0, z0 in ((-1000, -1000), (800, -1000), (-1000, 800), (800, 800)):
        out.append(_box(trim, x0, x0 + 200, h, h + 300, z0, z0 + 200, tag + ".turret"))
    out.append(_box(trim, -150, 150, 20, 300, -150, 150, tag + ".plinth"))
    out.append(_box(m["accent"], -60, 60, 300, 700, -60, 60, tag + ".accent"))
    return out, max(h + 300, 700)
RULES = {"tower": tower, "lighthouse": lighthouse, "obelisk": obelisk, "gate": gate,
         "temple": temple, "watchtower": watchtower, "windmill": windmill,
         "belltower": belltower, "keep": keep, "ruin": ruin, "statue": statue, "pyramid": pyramid,
         "spirerock": spirerock, "fountain": fountain, "shrine": shrine, "greattree": greattree,
         "marketsquare": marketsquare, "fortress": fortress, "domedhall": domedhall,
         "well": well, "shipwreck": shipwreck, "courtyard": courtyard}
def derive(kind, r, pal, tag="landmark"):
    pieces, h = RULES[kind](r, pal, "%s.%s" % (tag, kind))
    return pieces, h
def foot(kind):
    return FOOT.get(kind, 3)
def _top_shape(kind, pieces):
    tier, top, use = META[kind]
    if top:
        return top
    words = set(str(p.get("tag", "")).split(".")[-1] for p in pieces)
    if "merlon" in words:
        return "battlements"
    if "lantern" in words or "post" in words:
        return "lantern"
    return "pyramid roof"
def derive_full(kind, r, pal, tag="landmark"):
    from . import v1
    pieces, h = derive(kind, r, pal, tag)
    mm = v1.arenas_module()
    rects = [mm.footprint(p) for p in pieces]
    width = max(max(rc[1] for rc in rects) - min(rc[0] for rc in rects),
                max(rc[3] for rc in rects) - min(rc[2] for rc in rects))
    body = max((max(p["w"], p["d"]) for p in pieces
                if p["y"] + p["h"] > h * 0.4 and p["kind"] not in ("water",)), default=width)
    tier, _, use = META[kind]
    words = [str(p.get("tag", "")).split(".")[-1] for p in pieces]
    accent = any(w == "accent" and p["y"] + p["h"] >= h - 400 for w, p in zip(words, pieces))
    usable = any(w in ("stairs", "door", "gallery", "deck", "belfry", "ledge", "platform",
                       "step", "floor", "arch", "ramp", "gate", "paving", "rim", "base",
                       "dais", "plinth", "pierbase", "drum")
                 or p["kind"] in ("stairs", "ramp", "arch") for w, p in zip(words, pieces))
    return {"kind": kind, "pieces": pieces, "height": h, "width": width, "mass_width": body,
            "tier": tier, "top": _top_shape(kind, pieces), "use": use, "accent": accent,
            "usable": usable}
def pick(r, theme, have=(), wanted=(), tier=None):
    for k in wanted:
        if k in RULES and k not in have:
            return k
    pref = THEME_KINDS.get(theme or "garden", ())
    pool = [k for k in KINDS if (tier is None or META[k][0] == tier)
            and (k not in SET_PIECES or k in pref)] or list(KINDS)
    if tier != "tertiary":
        fresh = [k for k in pool if k not in have]
        if fresh:
            pool = fresh
    w = {}
    for k in pool:
        w[k] = (3.0 if k in pref else 1.0) * (0.15 if k in have else 1.0)
    total = sum(w.values())
    x = r.random() * total
    for k in pool:
        x -= w[k]
        if x < 0:
            return k
    return pool[-1]
def readability(lms, house_top=0, sky=None):
    out = {}
    tops = [x["top"] for x in lms if x["tier"] != "tertiary"]
    dup = sorted(set(t for t in tops if tops.count(t) > 1))
    out["LR1"] = {"ok": not dup, "text": "unique tops (%d)" % len(tops) if not dup else
                  "tops shared: %s" % ", ".join(dup)}
    lad = ladder(lms, house_top)
    out["LR2"] = {"ok": lad["ok"], "text": lad["text"]}
    bad3 = [x["kind"] for x in lms if x["tier"] != "tertiary"
            and not (x["height"] >= 3 * max(1, x["mass_width"]) or x["width"] >= 2400
                     or x["height"] >= 2 * max(1, house_top))]
    out["LR3"] = {"ok": not bad3, "text": "thin or massive" if not bad3 else
                  "medium blobs: %s" % ", ".join(bad3)}
    out["LR4"] = {"ok": None, "text": "the render audit's value against the sky"}
    no5 = [x["kind"] for x in lms if x["tier"] != "tertiary" and not x["accent"]]
    out["LR5"] = {"ok": not no5, "text": "an accent at every top" if not no5 else
                  "no accent at the top: %s" % ", ".join(no5)}
    no6 = [x["kind"] for x in lms if not x["usable"]]
    out["LR6"] = {"ok": not no6, "text": "each has a part to use" if not no6 else
                  "nothing to use near: %s" % ", ".join(no6)}
    out["LR7"] = {"ok": None, "text": "sight rays (metrics/vis): not measured here"}
    turned = [x for x in lms if "faces_ok" in x]
    bad8 = [x["kind"] for x in turned if not x["faces_ok"]]
    out["LR8"] = {"ok": not bad8 if turned else None,
                  "text": "%d turned to the plaza or road" % len(turned) if not bad8 else
                  "facing away: %s" % ", ".join(bad8)}
    echo = [x for x in lms if x.get("echo")]
    out["LR9"] = {"ok": bool(echo) if lms else None,
                  "text": "%d echoes of the primary" % len(echo)}
    no10 = [x["kind"] for x in lms if not x["use"]]
    out["LR10"] = {"ok": not no10, "text": "every one offers something" if not no10 else
                   "no use: %s" % ", ".join(no10)}
    return out
def ladder(lms, house_top):
    if not lms:
        return {"ok": None, "text": "no landmarks", "primary": None}
    order = sorted(lms, key=lambda x: -x["height"])
    prim = order[0]
    rest = order[1:]
    need = 2 * house_top
    ok = prim["height"] >= need and all(prim["height"] >= 1.3 * x["height"] for x in rest
                                        if x is not prim)
    text = "primary %s %d (houses %d, needs %d)" % (prim["kind"], prim["height"], house_top, need)
    if rest:
        text += "; next %s %d" % (rest[0]["kind"], rest[0]["height"])
    return {"ok": ok, "text": text, "primary": prim}
