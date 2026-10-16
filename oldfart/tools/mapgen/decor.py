import math
SHAPES = {"box": 0, "slope": 1, "wedge": 21, "ridge": 27, "pyramid": 28,
          "roundcorner": 33, "prism": 16, "arch": 15, "pillar": 14, "doorway": 34,
          "window": 35, "slab": 8, "outer": 2}
PROP_BYTE = 48
MAX_RECIPES = 128
MAX_PARTS = 16
MAX_VERTS = 480
CELL = 200
SKIN_LOW = 60
OUT_OF_REACH = 600
SLENDER = 40
def P(shape, x0, x1, y0, y1, z0, z1, slot="a", q=0):
    return (shape, x0, x1, y0, y1, z0, z1, slot, q)
def C(w, h, d):
    return (w, h, d)
WOOD = ("trim", "darkplanks")
STONE = ("structure", "greystone")
COVER = ("cover", "crateslat")
CLOTH = ("awning", "clothred")
GLASS = ("light", "lanternwarm")
SIGN = ("sign", "signboard")
FLOWERS = ("foliage", "flowersred")
RECIPES = [
    dict(key="fence", ref="R1", name="Fence run",
         parts=[P("box", -200, -160, 0, 220, -20, 20), P("box", 160, 200, 0, 220, -20, 20),
                P("box", -200, 200, 80, 110, -15, 15), P("box", -200, 200, 170, 200, -15, 15)],
         collide=C(400, 220, 40), slots={"a": WOOD}, context=("path", "field", "drop"),
         tier="mid"),
    dict(key="fence.long", ref="R1", name="Fence run, long",
         parts=[P("box", -400, -360, 0, 220, -20, 20), P("box", -20, 20, 0, 220, -20, 20),
                P("box", 360, 400, 0, 220, -20, 20),
                P("box", -400, 400, 80, 110, -15, 15), P("box", -400, 400, 170, 200, -15, 15)],
         collide=C(800, 220, 40), slots={"a": WOOD}, context=("path", "field", "drop"),
         tier="mid"),
    dict(key="gatepost", ref="R2", name="Gate post",
         parts=[P("box", -80, 80, 0, 760, -80, 80), P("pyramid", -100, 100, 760, 860, -100, 100)],
         collide=C(160, 760, 160), slots={"a": STONE}, context=("gate",), tier="mid"),
    dict(key="lamp", ref="R3", name="Lamp post",
         parts=[P("box", -30, 30, 0, 700, -30, 30), P("box", -70, 70, 700, 840, -70, 70, "b"),
                P("pyramid", -90, 90, 840, 920, -90, 90), P("box", -60, 60, 0, 40, -60, 60)],
         collide=C(60, 700, 60), slots={"a": WOOD, "b": GLASS}, context=("main_road", "door", "node"),
         tier="mid"),
    dict(key="lamp.arm", ref="R3", name="Lamp post with an arm",
         parts=[P("box", -30, 30, 0, 760, -30, 30), P("box", 30, 220, 720, 760, -20, 20),
                P("box", 120, 220, 600, 700, -20, 20, "b"),
                P("pyramid", 110, 230, 700, 720, -60, 60), P("box", -60, 60, 0, 40, -60, 60)],
         collide=C(60, 760, 60), slots={"a": WOOD, "b": GLASS}, context=("main_road", "door"),
         tier="mid"),
    dict(key="bench", ref="R4", name="Bench",
         parts=[P("box", -200, 200, 100, 140, -80, 80), P("box", -180, -140, 0, 100, -70, 70),
                P("box", 140, 180, 0, 100, -70, 70)],
         collide=C(400, 140, 160), slots={"a": WOOD}, context=("view", "node", "path"),
         tier="near"),
    dict(key="bench.back", ref="R4", name="Bench with a back",
         parts=[P("box", -200, 200, 100, 140, -80, 80), P("box", -180, -140, 0, 100, -70, 70),
                P("box", 140, 180, 0, 100, -70, 70), P("box", -200, 200, 140, 300, -80, -50)],
         collide=C(400, 140, 160), slots={"a": WOOD}, context=("view", "node"), tier="near"),
    dict(key="signpost", ref="R5", name="Signpost",
         parts=[P("box", -30, 30, 0, 420, -30, 30), P("box", 30, 300, 320, 410, -15, 15, "b"),
                P("pyramid", -40, 40, 420, 460, -40, 40)],
         collide=C(60, 420, 60), slots={"a": WOOD, "b": SIGN}, context=("node",), tier="mid"),
    dict(key="signpost.two", ref="R5", name="Signpost, two boards",
         parts=[P("box", -30, 30, 0, 460, -30, 30), P("box", 30, 300, 410, 460, -15, 15, "b"),
                P("box", -15, 15, 320, 400, 30, 300, "b"), P("pyramid", -40, 40, 460, 500, -40, 40)],
         collide=C(60, 460, 60), slots={"a": WOOD, "b": SIGN}, context=("node",), tier="mid"),
    dict(key="well", ref="R6", name="Well",
         parts=[P("box", -200, 200, 0, 260, -200, -150), P("box", -200, 200, 0, 260, 150, 200),
                P("box", -200, -150, 0, 260, -150, 150), P("box", 150, 200, 0, 260, -150, 150),
                P("box", -150, 150, 200, 220, -150, 150, "c")],
         collide=C(400, 260, 400), slots={"a": STONE}, fixed={"c": "watersurface"},
         context=("plaza", "farm", "site"), tier="mid", hero=True),
    dict(key="well.roof", ref="R6", name="Well with a roof",
         parts=[P("box", -200, 200, 0, 260, -200, -150), P("box", -200, 200, 0, 260, 150, 200),
                P("box", -200, -150, 0, 260, -150, 150), P("box", 150, 200, 0, 260, -150, 150),
                P("box", -150, 150, 200, 220, -150, 150, "c"),
                P("box", -190, -150, 260, 700, -20, 20, "b"), P("box", 150, 190, 260, 700, -20, 20, "b"),
                P("ridge", -260, 260, 700, 860, -180, 180), P("box", -150, 150, 480, 520, -20, 20, "b")],
         collide=C(400, 260, 400), slots={"a": STONE, "b": WOOD}, fixed={"c": "watersurface"},
         context=("plaza", "farm", "site"), tier="mid", hero=True),
    dict(key="stall", ref="R7", name="Market stall",
         parts=[P("box", -300, 300, 0, 200, -100, 200, "c"),
                P("box", -300, -260, 0, 700, -200, -160), P("box", 260, 300, 0, 700, -200, -160),
                P("box", -300, -260, 200, 600, 160, 200), P("box", 260, 300, 200, 600, 160, 200),
                P("slope", -320, 320, 600, 700, -220, 240, "b", 2)],
         collide=C(600, 200, 400), slots={"a": WOOD, "b": CLOTH}, fixed={"c": "crateslat"},
         context=("plaza", "market"), tier="mid", hero=True),
    dict(key="crates", ref="R8", name="Crates",
         parts=[P("box", -200, 0, 0, 200, -100, 100), P("box", 0, 200, 0, 180, -100, 80),
                P("box", -150, 50, 200, 380, -90, 90, "b")],
         collide=C(400, 200, 200), slots={"a": COVER, "b": ("cover", "cratedark")},
         context=("stall", "dock", "door", "cart"), tier="near"),
    dict(key="barrels", ref="R8", name="Barrels",
         parts=[P("pillar", -150, -10, 0, 180, -70, 70), P("pillar", 10, 150, 0, 180, -70, 70),
                P("box", -140, -20, 180, 190, -60, 60, "b"), P("box", 20, 140, 180, 190, -60, 60, "b")],
         collide=C(300, 180, 140), slots={"a": ("cover", "barrelside"), "b": ("cover", "barreltop")},
         context=("stall", "dock", "door", "cart"), tier="near"),
    dict(key="flowerbed", ref="R9", name="Flower bed",
         parts=[P("box", -200, 200, 0, 80, -100, 100), P("box", -180, 180, 80, 100, -80, 80, "b")],
         collide=C(400, 100, 200), slots={"a": ("trim", "greystone"), "b": FLOWERS},
         context=("door", "path", "garden"), tier="near"),
    dict(key="planter", ref="R9", name="Flower pot",
         parts=[P("box", -70, 70, 0, 120, -70, 70), P("box", -60, 60, 120, 140, -60, 60, "b")],
         collide=C(140, 140, 140), slots={"a": ("trim", "terracottasmall"), "b": FLOWERS},
         context=("door",), tier="near"),
    dict(key="dock", ref="R10", name="Dock",
         parts=[P("box", -200, 200, 0, 30, -400, 400), P("box", -200, -140, -270, 90, 340, 400, "b"),
                P("box", 140, 200, -270, 90, 340, 400, "b")],
         collide=C(400, 30, 800), base=-30, slots={"a": ("bridge", "wddeck"), "b": WOOD},
         context=("water",), tier="mid"),
    dict(key="statue", ref="R11", name="Statue on a plinth",
         parts=[P("box", -200, 200, 0, 200, -200, 200), P("box", -60, 60, 200, 360, -40, 40, "b"),
                P("box", -80, 80, 360, 560, -60, 60, "b"), P("box", -180, 180, 500, 550, -30, 30, "b"),
                P("box", -50, 50, 560, 660, -50, 50, "b")],
         collide=C(400, 200, 400), slots={"a": STONE, "b": ("structure", "whitemarble")},
         context=("plaza", "garden", "site"), tier="mid", hero=True),
    dict(key="obelisk", ref="R11", name="Obelisk",
         parts=[P("box", -200, 200, 0, 200, -200, 200), P("box", -80, 80, 200, 900, -80, 80, "b"),
                P("pyramid", -80, 80, 900, 1020, -80, 80, "b")],
         collide=C(400, 200, 400), slots={"a": STONE, "b": ("structure", "whitemarble")},
         context=("plaza", "garden", "site"), tier="far", hero=True),
    dict(key="fountain", ref="R12", name="Fountain",
         parts=[P("box", -400, 400, 0, 220, -400, -340), P("box", -400, 400, 0, 220, 340, 400),
                P("box", -400, -340, 0, 220, -340, 340), P("box", 340, 400, 0, 220, -340, 340),
                P("box", -340, 340, 180, 200, -340, 340, "c"), P("box", -100, 100, 0, 500, -100, 100),
                P("box", -200, 200, 500, 560, -200, 200), P("pyramid", -60, 60, 560, 680, -60, 60)],
         collide=C(800, 220, 800), slots={"a": ("structure", "whitemarble")},
         fixed={"c": "watersurface"}, context=("plaza",), tier="mid", hero=True),
    dict(key="retaining", ref="R13", name="Retaining step",
         parts=[P("box", -200, 200, 0, 200, -100, 100), P("box", -210, 210, 200, 230, -110, 110, "b")],
         collide=C(400, 230, 200), slots={"a": STONE, "b": ("trim", "whitestonebrick")},
         context=("step",), tier="near"),
    dict(key="tent", ref="R14", name="Tent",
         parts=[P("ridge", -200, 200, 0, 400, -300, 300, "a", 1),
                P("box", -60, 60, 0, 260, 300, 304, "b")],
         collide=C(400, 200, 600), slots={"a": ("awning", "canvasstripe"), "b": ("awning", "canvasblue")},
         context=("camp",), tier="far", hero=True),
    dict(key="campfire", ref="R15", name="Campfire",
         parts=[P("box", -150, 150, 0, 60, -30, 30), P("box", -30, 30, 0, 60, -150, 150),
                P("box", -50, 50, 20, 60, -50, 50, "b"),
                P("box", -200, -120, 0, 60, -40, 40, "c"), P("box", 120, 200, 0, 60, -40, 40, "c"),
                P("box", -40, 40, 0, 60, -200, -120, "c"), P("box", -40, 40, 0, 60, 120, 200, "c")],
         collide=None, slots={"a": ("cover", "darklog"), "b": ("light", "glowamber")},
         fixed={"c": "rockgrey"}, context=("camp",), tier="near"),
    dict(key="stones", ref="R16", name="Wayside stones",
         parts=[P("box", -130, 130, 0, 180, -110, 110), P("box", 150, 300, 0, 60, -40, 100),
                P("box", -260, -170, 0, 60, 60, 150)],
         collide=C(260, 180, 220), slots={"a": ("structure", "rockgrey")},
         context=("path", "bend", "field"), tier="near"),
    dict(key="logpile", ref="R17", name="Log pile",
         parts=[P("box", -200, 200, 0, 100, -110, -10), P("box", -200, 200, 0, 100, 10, 110),
                P("box", -180, 180, 100, 200, -50, 50), P("box", -210, -200, 0, 100, -100, 100, "b")],
         collide=C(420, 200, 220), slots={"a": ("cover", "barkoak"), "b": ("cover", "logoaktop")},
         context=("camp", "door", "farm"), tier="near"),
    dict(key="fallentree", ref="R18", name="Fallen tree",
         parts=[P("box", -500, 500, 0, 160, -80, 80), P("box", -600, -400, 0, 200, -100, 100),
                P("box", -590, -410, 200, 210, -90, 90, "b"), P("box", 200, 460, 160, 220, -60, 120, "c")],
         collide=C(1200, 160, 200), slots={"a": ("cover", "barkoak"), "b": ("cover", "logoaktop")},
         fixed={"c": "leaves"}, context=("path", "stream", "forest"), tier="mid"),
    dict(key="ruin", ref="R19", name="Ruin wall",
         parts=[P("box", -200, 200, 0, 600, -100, 100), P("box", -200, 200, 600, 700, -100, -20),
                P("box", 220, 330, 0, 50, -80, 60, "b"), P("box", -340, -230, 0, 40, 20, 140, "b")],
         collide=C(400, 600, 200), slots={"a": ("structure", "sbgreyworn"), "b": ("structure", "mossyrock")},
         context=("ruin", "site"), tier="far"),
    dict(key="rubble", ref="R20", name="Rubble",
         parts=[P("box", -180, -60, 0, 60, -120, 0), P("box", 0, 140, 0, 50, -60, 80),
                P("box", -60, 40, 0, 40, 60, 160), P("box", 160, 240, 0, 30, -160, -80)],
         collide=None, slots={"a": ("structure", "sbgreyworn")}, context=("ruin",), tier="near"),
    dict(key="standingstone", ref="R21", name="Standing stone",
         parts=[P("box", -100, 100, 0, 520, -80, 80), P("box", -120, 120, 0, 40, -100, 100, "b")],
         collide=C(200, 520, 160), slots={"a": ("structure", "rockgrey"), "b": ("structure", "mossyrock")},
         context=("circle",), tier="far"),
    dict(key="standingstone.fallen", ref="R21", name="Fallen standing stone",
         parts=[P("box", -260, 260, 0, 160, -100, 100), P("box", -280, -200, 0, 60, -120, 120, "b")],
         collide=C(520, 160, 200), slots={"a": ("structure", "rockgrey"), "b": ("structure", "mossyrock")},
         context=("circle",), tier="mid"),
    dict(key="haybale", ref="R22", name="Hay bale",
         parts=[P("box", -100, 100, 0, 200, -100, 100), P("box", -102, 102, 60, 80, -102, 102, "b"),
                P("box", -102, 102, 130, 150, -102, 102, "b")],
         collide=C(200, 200, 200), slots={"a": ("cover", "rfthatch"), "b": ("cover", "darkplanks")},
         context=("farm",), tier="near"),
    dict(key="doorframe", ref="R23", name="Door frame",
         parts=[P("box", -240, -200, 0, 520, -30, 30), P("box", 200, 240, 0, 520, -30, 30),
                P("box", -260, 260, 520, 580, -40, 40)],
         collide=None, slots={"a": WOOD}, context=("door",), tier="near"),
    dict(key="awning", ref="R24", name="Awning",
         parts=[P("slope", -300, 300, 440, 540, -10, 290, "b", 2)],
         collide=None, slots={"b": CLOTH}, context=("door", "stall"), tier="mid"),
    dict(key="porch", ref="R24", name="Porch roof on posts",
         parts=[P("slope", -300, 300, 440, 540, -10, 330, "b", 2),
                P("box", -280, -240, 0, 440, 250, 290), P("box", 240, 280, 0, 440, 250, 290)],
         collide=None, slots={"a": WOOD, "b": ("roof", "rfshingle")}, context=("door",), tier="mid"),
    dict(key="stoop", ref="R25", name="Stoop",
         parts=[P("box", -200, 200, 0, 60, -100, 100), P("box", -160, 160, 60, 100, -100, 0, "b")],
         collide=C(400, 60, 200), slots={"a": STONE, "b": ("trim", "whitestonebrick")},
         context=("door",), tier="near"),
    dict(key="windowbox", ref="R26", name="Window box",
         parts=[P("box", -100, 100, 260, 320, -30, 30), P("box", -90, 90, 320, 340, -20, 20, "b")],
         collide=None, slots={"a": WOOD, "b": FLOWERS}, context=("window",), tier="near"),
    dict(key="chimney", ref="R27", name="Chimney",
         parts=[P("box", -100, 100, 0, 400, -100, 100), P("box", -130, 130, 400, 440, -130, 130, "b")],
         collide=C(200, 400, 200), slots={"a": ("building_wall", "redbrick"), "b": STONE},
         context=("roof",), tier="far"),
    dict(key="windmill", ref="R28", name="Windmill",
         parts=[P("box", -300, 300, 0, 1200, -300, 300),
                P("pyramid", -360, 360, 1200, 1600, -360, 360, "b"),
                P("box", -800, 800, 1050, 1250, 320, 360, "c"), P("box", -100, 100, 600, 1700, 320, 360, "c"),
                P("doorway", -200, 200, 0, 500, 260, 300)],
         collide=C(600, 1200, 600), slots={"a": ("structure", "plasterwhite"), "b": ("roof", "rfthatch")},
         fixed={"c": "darkplanks"}, context=("farm", "hill"), tier="far", hero=True),
    dict(key="lookout", ref="R29", name="Lookout stump",
         parts=[P("box", -300, 300, 0, 600, -300, 300),
                P("box", -300, -220, 600, 700, -300, 300, "b"), P("box", 220, 300, 600, 700, -300, 300, "b"),
                P("box", -220, 220, 600, 700, -300, -220, "b"), P("box", -20, 20, 600, 1100, -20, 20, "c"),
                P("box", 20, 260, 960, 1100, -10, 10, "c")],
         collide=C(600, 600, 600), slots={"a": STONE, "b": ("trim", "darkplanks")},
         fixed={"c": "clothred"}, context=("view", "hill", "site"), tier="far", hero=True),
    dict(key="archtop", ref="R30", name="Arch over a path",
         parts=[P("arch", -400, 400, 760, 1100, -100, 100), P("box", -60, 60, 1100, 1180, -100, 100, "b")],
         collide=None, slots={"a": STONE, "b": ("trim", "whitestonebrick")},
         context=("gate",), tier="far"),
    dict(key="flag", ref="PI6", name="Flag on a pole",
         parts=[P("box", -20, 20, 0, 1000, -20, 20), P("box", 20, 320, 760, 960, -10, 10, "b"),
                P("pyramid", -40, 40, 1000, 1060, -40, 40)],
         collide=C(40, 1000, 40), slots={"a": WOOD, "b": ("awning", "bannerred")},
         context=("site",), tier="far"),
    dict(key="smoke", ref="PI6", name="Smoke plume",
         parts=[P("box", -60, 60, 0, 600, -60, 60), P("box", -90, 50, 600, 1100, -70, 70),
                P("box", -40, 120, 1100, 1500, -60, 80)],
         collide=None, slots={}, fixed={"a": "wool"}, context=("camp", "site"), tier="far"),
    dict(key="cart", ref="V2", name="Broken cart",
         parts=[P("box", -300, 300, 120, 220, -150, 150), P("box", -300, 300, 220, 320, -150, -130),
                P("box", -300, 300, 220, 320, 130, 150), P("box", -200, 0, 0, 40, 160, 360, "b"),
                P("box", 180, 380, 0, 40, -260, -60, "b"), P("box", 300, 520, 160, 190, -20, 20)],
         collide=C(600, 220, 300), slots={"a": WOOD, "b": ("cover", "darkplanks")},
         context=("path", "site"), tier="mid"),
    dict(key="column.fallen", ref="V2", name="Fallen column",
         parts=[P("box", -400, 400, 0, 200, -100, 100), P("box", -440, -360, 0, 60, -120, 120, "b")],
         collide=C(800, 200, 200), slots={"a": ("structure", "whitemarble"), "b": ("structure", "sbgreyworn")},
         context=("ruin",), tier="mid"),
    dict(key="post", ref="B9", name="Mooring post",
         parts=[P("box", -40, 40, -300, 160, -40, 40), P("box", -50, 50, 160, 180, -50, 50)],
         collide=C(80, 180, 80), base=0, slots={"a": WOOD}, context=("water",), tier="near"),
    dict(key="steppingstone", ref="B8", name="Stepping stone",
         parts=[P("box", -100, 100, 0, 40, -100, 100), P("box", -110, 110, -200, 0, -110, 110)],
         collide=C(200, 40, 200), base=0, slots={"a": ("path", "pathstepping")},
         context=("water",), tier="near"),
    dict(key="tuft", ref="S1", name="Grass tuft",
         parts=[P("box", -110, 110, -20, 30, -50, 70), P("box", -40, 70, -20, 40, -110, 100)],
         collide=None, slots={"a": ("foliage", "grasslush")}, context=("field", "path"),
         tier="near"),
    dict(key="flowers.patch", ref="S2", name="Flower patch",
         parts=[P("box", -120, 120, -20, 12, -60, 60), P("box", -60, 60, -20, 16, -120, 120)],
         collide=None, slots={"a": FLOWERS}, context=("field", "path", "garden"), tier="near"),
    dict(key="fern", ref="S3", name="Fern",
         parts=[P("box", -100, 100, -20, 120, -10, 10), P("box", -10, 10, -20, 120, -100, 100)],
         collide=None, slots={"a": ("foliage", "fern")}, context=("forest", "stream"), tier="near"),
    dict(key="bush", ref="S4", name="Bush",
         parts=[P("box", -110, 110, -30, 150, -110, 110), P("box", -70, 70, 150, 230, -80, 60)],
         collide=C(220, 150, 220), slots={"a": ("foliage", "leaves")},
         context=("forest", "field", "path"), tier="near"),
    dict(key="rock.small", ref="S5", name="Small rocks",
         parts=[P("box", -100, 60, -40, 90, -80, 70), P("box", 20, 120, -40, 50, -100, 0)],
         collide=C(240, 90, 200), slots={"a": ("structure", "rockgrey")},
         context=("field", "bend", "drop"), tier="near"),
    dict(key="boulder", ref="S6", name="Boulder",
         parts=[P("box", -130, 120, -40, 200, -120, 110), P("box", -90, 70, 200, 280, -80, 60)],
         collide=C(250, 200, 230), slots={"a": ("structure", "rockgrey")},
         context=("field", "drop", "hill"), tier="mid"),
    dict(key="mushrooms", ref="S7", name="Mushrooms",
         parts=[P("box", -30, 30, -20, 60, -30, 30, "b"), P("pyramid", -90, 90, 60, 110, -90, 90)],
         collide=None, slots={"a": ("foliage", "mushroomsred"), "b": ("structure", "cutlight")},
         context=("forest",), tier="near"),
    dict(key="reeds", ref="S8", name="Reeds",
         parts=[P("box", -70, 50, -20, 220, -10, 10), P("box", -10, 10, -20, 180, -60, 70)],
         collide=None, slots={"a": ("foliage", "grassdry")}, context=("water", "stream"),
         tier="near"),
]
SOLID_TALL = 100
SOLID_WIDE = 80
def B(x0, x1, y0, y1, z0, z1):
    return (x0, x1, y0, y1, z0, z1)
SOLIDS = {
    "gatepost": [B(-80, 80, 0, 760, -80, 80), B(-50, 50, 760, 810, -50, 50)],
    "lamp": [B(-30, 30, 0, 700, -30, 30), B(-70, 70, 700, 840, -70, 70), B(-45, 45, 840, 880, -45, 45)],
    "lamp.arm": [B(-30, 30, 0, 760, -30, 30), B(30, 220, 720, 760, -20, 20),
                 B(120, 220, 600, 700, -20, 20), B(140, 200, 700, 710, -30, 30)],
    "bench.back": [B(-200, 200, 0, 140, -80, 80), B(-200, 200, 140, 300, -80, -50)],
    "signpost": [B(-30, 30, 0, 420, -30, 30), B(30, 300, 320, 410, -15, 15), B(-20, 20, 420, 440, -20, 20)],
    "signpost.two": [B(-30, 30, 0, 460, -30, 30), B(30, 300, 410, 460, -15, 15),
                     B(-15, 15, 320, 400, 30, 300), B(-20, 20, 460, 480, -20, 20)],
    "well": [B(-200, 200, 0, 260, -200, -150), B(-200, 200, 0, 260, 150, 200),
             B(-200, -150, 0, 260, -150, 150), B(150, 200, 0, 260, -150, 150)],
    "well.roof": [B(-200, 200, 0, 260, -200, -150), B(-200, 200, 0, 260, 150, 200),
                  B(-200, -150, 0, 260, -150, 150), B(150, 200, 0, 260, -150, 150),
                  B(-190, -150, 260, 700, -20, 20), B(150, 190, 260, 700, -20, 20),
                  B(-150, 150, 480, 520, -20, 20), B(-260, 260, 700, 780, -90, 90)],
    "stall": [B(-300, 300, 0, 200, -100, 200), B(-300, -260, 0, 700, -200, -160),
              B(260, 300, 0, 700, -200, -160), B(-300, -260, 200, 600, 160, 200),
              B(260, 300, 200, 600, 160, 200), B(-320, 320, 600, 630, -220, 240)],
    "crates": [B(-200, 0, 0, 200, -100, 100), B(0, 200, 0, 180, -100, 80), B(-150, 50, 200, 380, -90, 90)],
    "barrels": [B(-150, 150, 0, 190, -70, 70)],
    "dock": [B(-200, 200, 0, 30, -400, 400), B(-200, -140, -270, 90, 340, 400),
             B(140, 200, -270, 90, 340, 400)],
    "statue": [B(-200, 200, 0, 200, -200, 200), B(-60, 60, 200, 360, -40, 40), B(-80, 80, 360, 560, -60, 60),
               B(-180, 180, 500, 550, -30, 30), B(-50, 50, 560, 660, -50, 50)],
    "obelisk": [B(-200, 200, 0, 200, -200, 200), B(-80, 80, 200, 900, -80, 80), B(-40, 40, 900, 960, -40, 40)],
    "fountain": [B(-400, 400, 0, 220, -400, -340), B(-400, 400, 0, 220, 340, 400),
                 B(-400, -340, 0, 220, -340, 340), B(340, 400, 0, 220, -340, 340),
                 B(-100, 100, 0, 500, -100, 100), B(-200, 200, 500, 560, -200, 200),
                 B(-30, 30, 560, 620, -30, 30)],
    "tent": [B(-150, 150, 0, 100, -300, 300), B(-100, 100, 100, 200, -300, 300),
             B(-50, 50, 200, 300, -300, 300)],
    "fallentree": [B(-600, 600, 0, 160, -100, 100), B(-600, -400, 0, 210, -100, 100),
                   B(200, 460, 160, 220, -60, 120)],
    "ruin": [B(-200, 200, 0, 600, -100, 100), B(-200, 200, 600, 700, -100, -20)],
    "doorframe": [B(-240, -200, 0, 520, -30, 30), B(200, 240, 0, 520, -30, 30),
                  B(-260, 260, 520, 580, -40, 40)],
    "awning": [B(-300, 300, 440, 465, -10, 290)],
    "porch": [B(-300, 300, 440, 465, -10, 330), B(-280, -240, 0, 440, 250, 290),
              B(240, 280, 0, 440, 250, 290)],
    "stoop": [B(-200, 200, 0, 60, -100, 100), B(-160, 160, 60, 100, -100, 0)],
    "windowbox": [B(-100, 100, 260, 320, -30, 30)],
    "chimney": [B(-100, 100, 0, 400, -100, 100), B(-130, 130, 400, 440, -130, 130)],
    "windmill": [B(-300, 300, 0, 1200, -300, 300), B(-180, 180, 1200, 1400, -180, 180),
                 B(-800, 800, 1050, 1250, 320, 360), B(-100, 100, 600, 1700, 320, 360)],
    "lookout": [B(-300, 300, 0, 600, -300, 300), B(-300, -220, 600, 700, -300, 300),
                B(220, 300, 600, 700, -300, 300), B(-220, 220, 600, 700, -300, -220),
                B(-20, 20, 600, 1100, -20, 20)],
    "archtop": [B(-400, 400, 1000, 1100, -100, 100), B(-400, -250, 760, 1000, -100, 100),
                B(250, 400, 760, 1000, -100, 100), B(-60, 60, 1100, 1180, -100, 100)],
    "cart": [B(-300, 300, 0, 220, -150, 150), B(-300, 300, 220, 320, -150, -130),
             B(-300, 300, 220, 320, 130, 150), B(300, 520, 160, 190, -20, 20)],
    "post": [B(-40, 40, 0, 160, -40, 40), B(-50, 50, 160, 180, -50, 50)],
    "bush": [B(-110, 110, -30, 150, -110, 110), B(-70, 70, 150, 230, -80, 60)],
    "boulder": [B(-130, 120, -40, 200, -120, 110), B(-90, 70, 200, 280, -80, 60)],
}
WALK = {
    "well": {4: "the water's surface: swum in"},
    "well.roof": {4: "the water's surface: swum in"},
    "fountain": {4: "the water's surface: swum in"},
    "tent": {1: "the door is painted on the cloth (4 thick)"},
    "windowbox": {1: "flowers"},
    "flag": {1: "a cloth banner"},
    "lookout": {5: "a cloth flag"},
    "smoke": {0: "smoke", 1: "smoke", 2: "smoke"},
    "fern": {0: "a fern's frond", 1: "a fern's frond"},
    "mushrooms": {0: "a mushroom", 1: "a mushroom"},
    "reeds": {0: "reeds", 1: "reeds"},
}
WATER = {
    "well": (-150, 150, -150, 150, 220),
    "well.roof": (-150, 150, -150, 150, 220),
    "fountain": (-340, 340, -340, 340, 200),
}
for _n, _r in enumerate(RECIPES):
    _r["rid"] = _n
BY_KEY = {r["key"]: r for r in RECIPES}
def recipe(key):
    return BY_KEY[key]
def word_bytes(rid):
    return PROP_BYTE + rid // 16, rid % 16
def visual_box(r):
    ps = r["parts"]
    return (min(p[1] for p in ps), max(p[2] for p in ps), min(p[3] for p in ps),
            max(p[4] for p in ps), min(p[5] for p in ps), max(p[6] for p in ps))
def solid_boxes(r):
    if r["key"] in SOLIDS:
        return list(SOLIDS[r["key"]])
    c = r.get("collide")
    if c is None:
        return []
    w, h, d = c
    return [(-w / 2.0, w / 2.0, 0, h, -d / 2.0, d / 2.0)]
_CORE = {"pyramid": (0.5, 0.5, 0.8), "ridge": (0.5, 0.5, 0.8), "slope": (0.5, 0.25, 0.8),
         "wedge": (0.5, 0.25, 0.8), "arch": (1.0, 1.0, 0.5)}
def covered(part, boxes, n=5):
    shape, x0, x1, y0, y1, z0, z1 = part[:7]
    y0 = max(y0, 0)
    if y1 <= y0:
        return 1.0
    hc, vc, _ = _CORE.get(shape, (1.0, 1.0, 0.85))
    cx, cz, hw, hd = (x0 + x1) / 2.0, (z0 + z1) / 2.0, (x1 - x0) * hc / 2.0, (z1 - z0) * hc / 2.0
    top = y0 + (y1 - y0) * vc
    inside = total = 0
    for i in range(n):
        x = cx - hw + (i + 0.5) * 2 * hw / n
        for j in range(n):
            y = y0 + (j + 0.5) * (top - y0) / n
            for k in range(n):
                z = cz - hd + (k + 0.5) * 2 * hd / n
                total += 1
                if any(b[0] - 1 <= x <= b[1] + 1 and b[2] - 1 <= y <= b[3] + 1
                       and b[4] - 1 <= z <= b[5] + 1 for b in boxes):
                    inside += 1
    return inside / float(total)
def unsolid_parts(r):
    boxes = solid_boxes(r)
    walk = WALK.get(r["key"], {})
    out = []
    for i, p in enumerate(r["parts"]):
        shape, x0, x1, y0, y1, z0, z1 = p[:7]
        if i in walk or y1 <= SKIN_LOW:
            continue
        tall = y1 - max(y0, 0) > SOLID_TALL
        wide = max(x1 - x0, z1 - z0) > SOLID_WIDE
        if not (tall or wide):
            continue
        need = _CORE.get(shape, (1.0, 1.0, 0.85))[2]
        got = covered(p, boxes)
        if got < need:
            out.append((i, "%s %dx%dx%d, %d%% inside the solid" % (
                shape, x1 - x0, y1 - y0, z1 - z0, int(round(got * 100)))))
    return out
def solid_top(r):
    return max([b[3] for b in solid_boxes(r)] or [0])
def water_boxes(pieces):
    out = []
    for p in pieces:
        r = BY_KEY.get(p.get("decor")) if p.get("decor") else None
        if r is None or r["key"] not in WATER:
            continue
        x0, x1, z0, z1, top = WATER[r["key"]]
        a = math.radians(p.get("yaw") or 0)
        c, s = math.cos(a), math.sin(a)
        xs, zs = [], []
        for x, z in ((x0, z0), (x0, z1), (x1, z0), (x1, z1)):
            xs.append(p["x"] + x * c + z * s)
            zs.append(p["z"] - x * s + z * c)
        out.append([int(round(min(xs))), int(round(min(zs))), int(round(max(xs))),
                    int(round(max(zs))), int(round(p["y"] + top)), int(round(p["y"]))])
    return out
def skin_faults(r):
    c = r.get("collide")
    out = []
    boxes = solid_boxes(r) if r["key"] in SOLIDS else []
    for i, p in enumerate(r["parts"]):
        _, x0, x1, y0, y1, z0, z1, _, _ = p
        if boxes and covered(p, boxes) >= 0.85:
            continue
        if i in WALK.get(r["key"], {}):
            continue
        if c is None:
            if y1 - y0 <= SKIN_LOW or y0 >= 400 or set(r["context"]) & {"door", "window", "gate"} \
                    or r["key"] == "smoke":
                continue
            if r["key"] == "campfire" and y1 <= SKIN_LOW:
                continue
            out.append(i)
            continue
        w, h, d = c
        inside = (x0 >= -w / 2 - 1 and x1 <= w / 2 + 1 and z0 >= -d / 2 - 1 and z1 <= d / 2 + 1)
        if inside or y1 - max(0, y0) <= SKIN_LOW or y0 >= OUT_OF_REACH or y1 <= 0:
            continue
        on_top = y0 >= h - 1 and (x1 - x0) <= 400 and (z1 - z0) <= 400
        hung = y0 >= 300 and min(x1 - x0, z1 - z0) <= SLENDER
        if on_top or hung:
            continue
        out.append(i)
    return out
def materials(r, theme=None, pal=None, index=0):
    from . import contract, kit
    out = {}
    tex = kit.textures()
    for slot, (cls, default) in sorted(r.get("slots", {}).items()):
        pick = None
        if theme and cls in contract.classes():
            pick = contract.material(theme, cls, pal, prefer=(default,), index=index)
            if pick in kit.NOT_NATURAL and theme == "garden":
                alt = contract.material(theme, cls, pal, index=index)
                if alt in tex and alt not in kit.NOT_NATURAL:
                    pick = alt
        out[slot] = pick if pick in tex else default
    for slot, fixed in (r.get("fixed") or {}).items():
        out[slot] = fixed
    return out
def piece(key, x, y, z, yaw=0, mats=None, tag=None, theme=None, pal=None, index=0):
    r = BY_KEY[key]
    m = dict(mats or materials(r, theme, pal, index))
    c = r.get("collide")
    base = r.get("base", 0)
    if c is None:
        x0, x1, y0, y1, z0, z1 = visual_box(r)
        w, h, d = max(x1 - x0, 20), max(y1 - max(y0, 0), 20), max(z1 - z0, 20)
    else:
        w, h, d = c
    tex = m.get("a") or m.get("b") or m.get("c")
    p = {"kind": "box", "tex": tex, "x": x, "y": y + base, "z": z, "w": w, "h": h, "d": d,
         "yaw": yaw, "tag": tag or ("decor." + key), "decor": key, "mats": m}
    if c is None:
        p["pass"] = True
    if r["key"] in SOLIDS:
        p["solid_h"] = solid_top(r)
    return p
DRAWN_KIND = {"box": "box", "slope": "ramp", "wedge": "ramp", "ridge": "ridge",
              "pyramid": "pyramid", "roundcorner": "roundcorner", "prism": "prism",
              "arch": "arch", "pillar": "pillar", "doorway": "box", "window": "box",
              "slab": "box", "outer": "outer"}
def drawn(pieces):
    out = []
    for p in pieces:
        r = BY_KEY.get(p.get("decor")) if p.get("decor") else None
        if r is None:
            out.append(p)
            continue
        mats = dict(r.get("fixed") or {})
        mats.update(p.get("mats") or {})
        a = math.radians(p.get("yaw") or 0)
        c, s = math.cos(a), math.sin(a)
        foot = p["y"] - (r.get("base") or 0)
        for shape, x0, x1, y0, y1, z0, z1, slot, q in r["parts"]:
            cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
            w, d = x1 - x0, z1 - z0
            if q % 2:
                w, d = d, w
            out.append({"kind": DRAWN_KIND.get(shape, "box"), "tex": mats.get(slot) or p["tex"],
                        "x": p["x"] + cx * c + cz * s, "y": foot + y0,
                        "z": p["z"] - cx * s + cz * c, "w": w, "h": y1 - y0, "d": d,
                        "yaw": ((p.get("yaw") or 0) + 90 * q) % 360, "tag": p.get("tag")})
    return out
def token(p):
    r = BY_KEY[p["decor"]]
    m = p.get("mats") or {}
    return "@p:%d:%s:%s" % (r["rid"], m.get("a") or "-", m.get("b") or "-")
SCENES = [
    dict(key="camp", name="Camp", items=[("tent", 0, -500, 0), ("campfire", 0, 300, 0),
                                         ("logpile", 500, 300, 1), ("smoke", 0, 300, 0)],
         disturbance=("logpile", "knocked over, pointing at the reward"), reward=(-400, 300),
         poi="camp"),
    dict(key="cart", name="Broken cart", items=[("cart", 0, 0, 0), ("crates", 0, 500, 0),
                                                ("barrels", -500, 300, 1)],
         disturbance=("crates", "spilled toward the ditch"), reward=(0, -400), poi="wreck"),
    dict(key="market", name="Market day", items=[("stall", -500, 0, 0), ("stall", 500, 0, 0),
                                                 ("well", 0, 600, 0), ("crates", -500, -500, 0)],
         disturbance=("stall", "one stall packed up"), reward=(500, -500), poi="market"),
    dict(key="fallentower", name="Fallen tower", items=[("ruin", 0, 0, 0),
                                                        ("column.fallen", 0, 600, 0),
                                                        ("rubble", 500, 200, 0)],
         disturbance=("column.fallen", "points back at the tower it fell from"),
         reward=(-500, 400), poi="ruin"),
    dict(key="watchpost", name="Watch post", items=[("lamp", -400, 0, 0), ("bench", 0, 0, 0),
                                                    ("signpost", 400, 0, 0)],
         disturbance=("lamp", "lit, nobody there"), reward=None, poi="cue"),
    dict(key="garden", name="Garden at rest", items=[("flowerbed", -500, 0, 0), ("flowerbed", 500, 0, 0),
                                                     ("bench.back", 0, -500, 0), ("statue", 0, 600, 0)],
         disturbance=("flowerbed", "one bed dug up"), reward=(500, 400), poi="garden"),
    dict(key="dock", name="Dock", items=[("dock", 0, 0, 0), ("crates", 300, -300, 0),
                                         ("post", -260, 500, 0), ("post", 260, 500, 0)],
         disturbance=("crates", "one crate in the water"), reward=(0, 700), poi="dock"),
    dict(key="circle", name="Stone circle", items=[("standingstone", 0, -600, 0),
                                                   ("standingstone", 570, -190, 1),
                                                   ("standingstone", 350, 490, 2),
                                                   ("standingstone", -350, 490, 3),
                                                   ("standingstone.fallen", -570, -190, 1)],
         disturbance=("standingstone.fallen", "the fallen stone points at the secret"),
         reward=(0, 0), poi="circle"),
    dict(key="farm", name="Farm edge", items=[("fence.long", 0, -500, 0), ("haybale", -300, 0, 0),
                                              ("haybale", 300, 200, 1), ("well", 0, 500, 0)],
         disturbance=("haybale", "bales scattered outside an open gate"), reward=None, poi="farm"),
]
SCENE_BY_KEY = {s["key"]: s for s in SCENES}
def _turn(dx, dz, quarter):
    for _ in range(quarter % 4):
        dx, dz = dz, -dx
    return dx, dz
def scene_pieces(key, x, y, z, quarter=0, theme=None, pal=None, index=0, floor=None):
    s = SCENE_BY_KEY[key]
    out = []
    for n, (rk, dx, dz, q) in enumerate(s["items"]):
        ox, oz = _turn(dx, dz, quarter)
        gy = floor(x + ox, z + oz) if floor else y
        if gy is None:
            continue
        p = piece(rk, x + ox, gy, z + oz, ((q + quarter) % 4) * 90,
                  theme=theme, pal=pal, index=index + n, tag="decor.%s.%s" % (key, rk))
        p["scene"] = "%s@%d,%d" % (key, int(x), int(z))
        p["context"] = key
        out.append(p)
    reward = None
    if s.get("reward") is not None:
        rx, rz = _turn(s["reward"][0], s["reward"][1], quarter)
        reward = (x + rx, y, z + rz)
    return out, reward
def footprint(key, quarter=0):
    s = SCENE_BY_KEY[key]
    xs, zs = [], []
    for rk, dx, dz, q in s["items"]:
        r = BY_KEY[rk]
        x0, x1, _, _, z0, z1 = visual_box(r)
        for cx, cz in ((x0, z0), (x1, z1), (x0, z1), (x1, z0)):
            ax, az = _turn(cx, cz, q)
            bx, bz = _turn(dx + ax, dz + az, quarter)
            xs.append(bx)
            zs.append(bz)
    return min(xs), max(xs), min(zs), max(zs)
def decor_pieces(pieces):
    return [p for p in pieces if p.get("decor")]
def dressing_checks(arena, family="explore", contexts=None, edge_half=None):
    pieces = arena.get("pieces") or []
    props = decor_pieces(pieces)
    res = {}
    worst = 0
    for i, p in enumerate([q for q in props if not q.get("scatter")]):
        same = [q for q in props if q is not p and q["decor"] == p["decor"]
                and q.get("mats") == p.get("mats")
                and not (p.get("scene") and q.get("scene") == p.get("scene"))
                and math.hypot(q["x"] - p["x"], q["z"] - p["z"]) <= 1500]
        worst = max(worst, len(same) + 1)
    res["D1"] = (worst, 3, worst <= 3 or worst == 0, "most identical props within 1500")
    contexts = contexts or {}
    lacking = sum(1 for p in props if not (p.get("context") or contexts.get(id(p))))
    res["D2"] = (lacking, 0, lacking == 0, "props placed without a context (CL4)")
    stairs = [q for q in pieces if q.get("kind") in ("stairs", "ramp")]
    lanes = [q for q in pieces if str(q.get("tag", "")).split(".")[0] in ("road", "path", "footpath")]
    blocked = 0
    for p in props:
        if p.get("pass"):
            continue
        for q in stairs + lanes:
            if _overlap(p, q, pad=200 if q in stairs else 0):
                blocked += 1
                break
    res["D3"] = (blocked, 0, blocked == 0, "props on a lane or a stair's approach")
    heroes = [p for p in props if BY_KEY[p["decor"]].get("hero")]
    crowded = 0
    for p in heroes:
        for q in props:
            if q is p or (q.get("scene") and q.get("scene") == p.get("scene")):
                continue
            if _gap(p, q) < 400:
                crowded += 1
                break
    res["D4"] = (crowded, 0, crowded == 0, "hero props without a clear ring of 2 cells")
    sites = arena.get("sites") or {}
    districts = sites.get("districts") or []
    if family == "explore" and len(districts) >= 8:
        dressed = set(p.get("district") for p in props if p.get("district") is not None
                      and (p.get("scene") or BY_KEY[p["decor"]].get("hero")))
        bare = sum(1 for k in range(len(districts)) if k not in dressed)
        share = bare / float(len(districts))
        res["D5"] = (round(share, 2), 0.2, share <= 0.2 + 1e-9,
                     "share of districts without a hero prop or a vignette")
    share = len(props) / float(max(1, len(pieces)))
    res["D6"] = (round(share, 3), (0.10, 0.20), True, "props' share of the pieces (report)")
    tops = sum(1 for p in props if not p.get("pass"))
    res["D7"] = (tops, None, True, "prop tops in the escape check's launch set")
    if family == "hide":
        traps = 0
        for p in props:
            if p.get("pass"):
                continue
            near = [q for q in props if q is not p and not q.get("pass") and 0 < _gap(p, q) < 200]
            if len(near) >= 2:
                traps += 1
        res["D8"] = (traps, 0, traps == 0, "one-cell gaps inside prop clusters")
    return res
def _extent(p):
    a = math.radians(p.get("yaw", 0) or 0)
    w, d = p["w"], p["d"]
    ew = abs(w * math.cos(a)) + abs(d * math.sin(a))
    ed = abs(w * math.sin(a)) + abs(d * math.cos(a))
    return p["x"] - ew / 2, p["x"] + ew / 2, p["z"] - ed / 2, p["z"] + ed / 2
def _overlap(p, q, pad=0):
    a, b = _extent(p), _extent(q)
    if p["y"] >= q["y"] + q.get("h", 0) + 1 or q["y"] >= p["y"] + p["h"] + 1:
        return False
    return a[0] < b[1] + pad and b[0] - pad < a[1] and a[2] < b[3] + pad and b[2] - pad < a[3]
def _gap(p, q):
    a, b = _extent(p), _extent(q)
    dx = max(0, max(a[0], b[0]) - min(a[1], b[1]))
    dz = max(0, max(a[2], b[2]) - min(a[3], b[3]))
    return math.hypot(dx, dz)
def lua_table():
    lines = ["-- BEGIN DECOR (tools/make-decor.py from tools/mapgen/decor.py - do not edit)",
             "stretch.PROP_BYTE = %d" % PROP_BYTE,
             "stretch.RECIPES = {"]
    layer = {"a": 0, "b": 1, "c": 2}
    for r in RECIPES:
        parts = ", ".join("{%d,%d,%d,%d,%d,%d,%d,%d,%d}" % (SHAPES[p[0]], p[1], p[2], p[3], p[4],
                                                          p[5], p[6], layer[p[7]], p[8])
                          for p in r["parts"])
        c = r.get("collide")
        solid = "{%d,%d,%d}" % c if c else "nil"
        fixed = r.get("fixed") or {}
        slots = r.get("slots") or {}
        dflt = ", ".join('%s = "%s"' % (s, (fixed.get(s) or slots.get(s, (None, None))[1]))
                         for s in ("a", "b", "c") if fixed.get(s) or s in slots)
        lines.append('    [%d] = { key = "%s", name = "%s", solid = %s, base = %d, mats = { %s },'
                     % (r["rid"], r["key"], r["name"], solid, r.get("base", 0), dflt))
        if r["key"] in SOLIDS:
            lines.append("        boxes = { %s }," % ", ".join(
                "{%d,%d,%d,%d,%d,%d}" % tuple(int(round(v)) for v in b) for b in SOLIDS[r["key"]]))
        lines.append("        parts = { %s } }," % parts)
    lines.append("}")
    lines.append("-- END DECOR")
    return "\n".join(lines) + "\n"
