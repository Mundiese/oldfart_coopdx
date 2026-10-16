OF = OF or {}
OF.venues = OF.venues or {}

local venues = OF.venues

venues.MESH = { box = "of_ak_box_col", ramp = "of_ak_ramp_col",
    stairs = "of_ak_stairs_col", outer = "of_ak_outer_col", inner = "of_ak_inner_col",
    rail = "of_ak_rail_col", pillar = "of_ak_pillar_col", arch = "of_ak_arch_col",
    prism = "of_ak_prism_col", outerstairs = "of_ak_outerstairs_col",
    innerstairs = "of_ak_innerstairs_col", curve = "of_ak_curve_col", bank = "of_ak_bank_col",
    arcwall = "of_ak_arcwall_col", ice = "of_ak_ice_col", ridge = "of_ak_ridge_col",
    pyramid = "of_ak_pyramid_col", roundcorner = "of_ak_roundcorner_col",
    lava = "of_ak_lava_col", uslope = "of_ak_uslope_col", uouter = "of_ak_uouter_col",
    uinner = "of_ak_uinner_col", wedgetip = "of_ak_wedgetip_col",
    wedgetipouter = "of_ak_wedgetipouter_col", wedgetipinner = "of_ak_wedgetipinner_col",
    pole = "of_ak_pole_col", doorway = "of_ak_doorway_col", window = "of_ak_window_col" }

venues.CELL = 200

venues.REACH = 20000

venues.PICTURES_AT_SIZE = true
venues.LAYOUTS = {
    skykeep = {
        level = "empty2", budget = 120, faults = 0,
        look = { sky = "BACKGROUND_PURPLE_SKY", music = "SEQ_LEVEL_KOOPA_ROAD" },

        pieces = {
            { "box", "@0:tile2:20:1:20", 0, -200, 0, 4000, 200, 4000, 0 },
            { "box", "@46:stone2:14:5:14", 0, -700, 0, 2800, 500, 2800, 0 },
            { "box", "@0:stone2:7:3:7", 0, -1300, 0, 1400, 600, 1400, 0 },
            { "box", "@8:tile1:6:1:6", 0, 500, 0, 1200, 100, 1200, 0 },
            { "box", "@46:brickdarkgrey:1:5:1", 500, 0, 500, 200, 500, 200, 0 },
            { "box", "of_ak_brickdarkgrey_box_400_200_150_geo", 0, 600, 525, 400, 200, 150, 0 },
            { "ramp", "@1:bricklightgrey:2:3:6", 0, 0, 800, 400, 600, 1200, 90 },
            { "box", "@46:brickdarkgrey:2:7:2", 1100, 0, 1100, 400, 700, 400, 0 },
            { "box", "@47:brickdarkgrey:8:2:1", 0, 0, 1450, 800, 200, 100, 0 },
            { "box", "@0:brickdarkgrey:3:2:3", 1700, 0, 1700, 600, 400, 600, 0 },
            { "ramp", "@1:bricklightgrey:2:2:4", 1000, 0, 1800, 400, 400, 800, 270 },
            { "box", "@8:woodenplank1:3:1:4", 0, -100, 2400, 600, 100, 800, 0 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", -260, 0, 2400, 80, 120, 800, 0 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", 260, 0, 2400, 80, 120, 800, 0 },
            { "ramp", "@1:bricklightgrey:3:2:4", 1700, 0, 2400, 600, 400, 800, 0 },
            { "ramp", "@1:bricklightgrey:3:2:4", -1700, 0, 2400, 600, 400, 800, 0 },
            { "box", "@46:stone1:20:3:6", 0, -300, 3400, 4000, 300, 1200, 0 },
            { "box", "@46:brickdarkgrey:20:9:1", 0, 0, 3900, 4000, 900, 200, 0 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", -1960, 0, 3300, 80, 160, 1000, 0 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", 1960, 0, 3300, 80, 160, 1000, 0 },
            { "box", "@47:brickdarkgrey:11:2:1", -850, 0, 2850, 1100, 200, 100, 0 },
            { "box", "@47:brickdarkgrey:11:2:1", 850, 0, 2850, 1100, 200, 100, 0 },
            { "box", "@0:brickdarkgrey:5:2:1", 0, 0, 3200, 1000, 400, 200, 0 },
            { "box", "@46:brickdarkgrey:1:5:1", 500, 0, -500, 200, 500, 200, 90 },
            { "box", "of_ak_brickdarkgrey_box_400_200_150_geo", 525, 600, 0, 400, 200, 150, 90 },
            { "ramp", "@1:bricklightgrey:2:3:6", 800, 0, 0, 400, 600, 1200, 180 },
            { "box", "@46:brickdarkgrey:2:7:2", 1100, 0, -1100, 400, 700, 400, 90 },
            { "box", "@47:brickdarkgrey:8:2:1", 1450, 0, 0, 800, 200, 100, 90 },
            { "box", "@0:brickdarkgrey:3:2:3", 1700, 0, -1700, 600, 400, 600, 90 },
            { "ramp", "@1:bricklightgrey:2:2:4", 1800, 0, -1000, 400, 400, 800, 0 },
            { "box", "@8:woodenplank1:3:1:4", 2400, -100, 0, 600, 100, 800, 90 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", 2400, 0, 260, 80, 120, 800, 90 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", 2400, 0, -260, 80, 120, 800, 90 },
            { "ramp", "@1:bricklightgrey:3:2:4", 2400, 0, -1700, 600, 400, 800, 90 },
            { "ramp", "@1:bricklightgrey:3:2:4", 2400, 0, 1700, 600, 400, 800, 90 },
            { "box", "@46:brickpyramid:20:3:6", 3400, -300, 0, 4000, 300, 1200, 90 },
            { "box", "@46:brickdarkgrey:20:9:1", 3900, 0, 0, 4000, 900, 200, 90 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", 3300, 0, 1960, 80, 160, 1000, 90 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", 3300, 0, -1960, 80, 160, 1000, 90 },
            { "box", "@47:brickdarkgrey:11:2:1", 2850, 0, 850, 1100, 200, 100, 90 },
            { "box", "@47:brickdarkgrey:11:2:1", 2850, 0, -850, 1100, 200, 100, 90 },
            { "box", "@0:brickdarkgrey:5:2:1", 3200, 0, 0, 1000, 400, 200, 90 },
            { "box", "@46:brickdarkgrey:1:5:1", -500, 0, -500, 200, 500, 200, 180 },
            { "box", "of_ak_brickdarkgrey_box_400_200_150_geo", 0, 600, -525, 400, 200, 150, 180 },
            { "ramp", "@1:bricklightgrey:2:3:6", 0, 0, -800, 400, 600, 1200, 270 },
            { "box", "@46:brickdarkgrey:2:7:2", -1100, 0, -1100, 400, 700, 400, 180 },
            { "box", "@47:brickdarkgrey:8:2:1", 0, 0, -1450, 800, 200, 100, 180 },
            { "box", "@0:brickdarkgrey:3:2:3", -1700, 0, -1700, 600, 400, 600, 180 },
            { "ramp", "@1:bricklightgrey:2:2:4", -1000, 0, -1800, 400, 400, 800, 90 },
            { "box", "@8:woodenplank1:3:1:4", 0, -100, -2400, 600, 100, 800, 180 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", 260, 0, -2400, 80, 120, 800, 180 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", -260, 0, -2400, 80, 120, 800, 180 },
            { "ramp", "@1:bricklightgrey:3:2:4", -1700, 0, -2400, 600, 400, 800, 180 },
            { "ramp", "@1:bricklightgrey:3:2:4", 1700, 0, -2400, 600, 400, 800, 180 },
            { "box", "@46:carpet:20:3:6", 0, -300, -3400, 4000, 300, 1200, 180 },
            { "box", "@46:brickdarkgrey:20:9:1", 0, 0, -3900, 4000, 900, 200, 180 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", 1960, 0, -3300, 80, 160, 1000, 180 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", -1960, 0, -3300, 80, 160, 1000, 180 },
            { "box", "@47:brickdarkgrey:11:2:1", 850, 0, -2850, 1100, 200, 100, 180 },
            { "box", "@47:brickdarkgrey:11:2:1", -850, 0, -2850, 1100, 200, 100, 180 },
            { "box", "@0:brickdarkgrey:5:2:1", 0, 0, -3200, 1000, 400, 200, 180 },
            { "box", "@46:brickdarkgrey:1:5:1", -500, 0, 500, 200, 500, 200, 270 },
            { "box", "of_ak_brickdarkgrey_box_400_200_150_geo", -525, 600, 0, 400, 200, 150, 270 },
            { "ramp", "@1:bricklightgrey:2:3:6", -800, 0, 0, 400, 600, 1200, 0 },
            { "box", "@46:brickdarkgrey:2:7:2", -1100, 0, 1100, 400, 700, 400, 270 },
            { "box", "@47:brickdarkgrey:8:2:1", -1450, 0, 0, 800, 200, 100, 270 },
            { "box", "@0:brickdarkgrey:3:2:3", -1700, 0, 1700, 600, 400, 600, 270 },
            { "ramp", "@1:bricklightgrey:2:2:4", -1800, 0, 1000, 400, 400, 800, 180 },
            { "box", "@8:woodenplank1:3:1:4", -2400, -100, 0, 600, 100, 800, 270 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", -2400, 0, -260, 80, 120, 800, 270 },
            { "box", "of_ak_brickdarkgrey_box_80_120_800_geo", -2400, 0, 260, 80, 120, 800, 270 },
            { "ramp", "@1:bricklightgrey:3:2:4", -2400, 0, 1700, 600, 400, 800, 270 },
            { "ramp", "@1:bricklightgrey:3:2:4", -2400, 0, -1700, 600, 400, 800, 270 },
            { "box", "@46:woodenplank2:20:3:6", -3400, -300, 0, 4000, 300, 1200, 270 },
            { "box", "@46:brickdarkgrey:20:9:1", -3900, 0, 0, 4000, 900, 200, 270 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", -3300, 0, -1960, 80, 160, 1000, 270 },
            { "box", "of_ak_brickdarkgrey_box_80_160_1000_geo", -3300, 0, 1960, 80, 160, 1000, 270 },
            { "box", "@47:brickdarkgrey:11:2:1", -2850, 0, -850, 1100, 200, 100, 270 },
            { "box", "@47:brickdarkgrey:11:2:1", -2850, 0, 850, 1100, 200, 100, 270 },
            { "box", "@0:brickdarkgrey:5:2:1", -3200, 0, 0, 1000, 400, 200, 270 },
        },

        spawns = {
            { -1150, 0, 3550, 180 },
            { 1150, 0, -3550, 0 },
            { 3550, 0, 1150, 270 },
            { -3550, 0, -1150, 90 },
            { -350, 0, 3550, 180 },
            { 350, 0, -3550, 0 },
            { 3550, 0, 350, 270 },
            { -3550, 0, -350, 90 },
            { 350, 0, 3550, 180 },
            { -350, 0, -3550, 0 },
            { 3550, 0, -350, 270 },
            { -3550, 0, 350, 90 },
            { 1150, 0, 3550, 180 },
            { -1150, 0, -3550, 0 },
            { 3550, 0, -1150, 270 },
            { -3550, 0, 1150, 90 },
        },
        survey = {
            points = { single = false, { -1150, 0, 3550, 180 }, { 1150, 0, -3550, 0 }, { 3550, 0, 1150, 270 }, { -3550, 0, -1150, 90 }, { -350, 0, 3550, 180 }, { 350, 0, -3550, 0 }, { 3550, 0, 350, 270 }, { -3550, 0, -350, 90 }, { 350, 0, 3550, 180 }, { -350, 0, -3550, 0 }, { 3550, 0, -350, 270 }, { -3550, 0, 350, 90 }, { 1150, 0, 3550, 180 }, { -1150, 0, -3550, 0 }, { 3550, 0, -1150, 270 }, { -3550, 0, 1150, 90 }, { 1700, 400, 1700, 225 }, { 0, 0, 1150, 180 }, { 300, 600, 300, 225 }, { -1700, 400, -1700, 45 }, { 0, 0, -1150, 0 }, { -300, 600, -300, 45 }, { 1700, 400, -1700, 315 }, { 1150, 0, 0, 270 }, { 300, 600, -300, 315 }, { -1700, 400, 1700, 135 }, { -1150, 0, 0, 90 }, { -300, 600, 300, 135 } },
        },
    },
    cinderswitchback = {
        level = "empty2", budget = 128, faults = 0,
        look = { sky = "BACKGROUND_FLAMING_SKY", music = "SEQ_LEVEL_BOSS_KOOPA_FINAL", light = { 0, 0, 0 }, bake = { sun = { -0.7, 1.05, -0.78 }, sunc = { 1, 0.8, 0.6 }, sky = { 0.44, 0.37, 0.38 }, gnd = { 0.5, 0.3, 0.22 }, lo = { 0.72, 0.62, 0.68 }, hi = { 1, 0.84, 0.62 }, sun0 = { 0.2, 0.7, -0.68 } }, hourBaked = { -0.9, 0.35, -0.1 }, visuals = { { "shading", "a sunset" } }, hour = "late, from the west", fog = "a pink evening", shade = "a sunset" },
        baked = true,
        lightfog = 2,
        pools = true,

        lights = {
            { -14800, 760, -11600, 255, 160, 80, 1800, 3.6, 0.1, 0.3, 0.04, 1.5, 1 },
            { -14800, 760, -10800, 255, 160, 80, 1800, 3.6, 0.1, 0.3, 0.04, 1.5, 1 },
            { -14000, 760, -11600, 255, 160, 80, 1800, 3.6, 0.1, 0.3, 0.04, 1.5, 1 },
            { -14000, 760, -10800, 255, 160, 80, 1800, 3.6, 0.1, 0.3, 0.04, 1.5, 1 },
        },
        lean = true, staticCount = 85,

        pieces = {
        },

        spawns = {
            { 750, 0, -600, 180 },
            { 250, 0, -600, 180 },
            { -250, 0, -600, 180 },
            { -750, 0, -600, 180 },
            { 750, 0, -200, 180 },
            { 250, 0, -200, 180 },
            { -250, 0, -200, 180 },
            { -750, 0, -200, 180 },
            { 750, 0, 200, 180 },
            { 250, 0, 200, 180 },
            { -250, 0, 200, 180 },
            { -750, 0, 200, 180 },
            { 750, 0, 600, 180 },
            { 250, 0, 600, 180 },
            { -250, 0, 600, 180 },
            { -750, 0, 600, 180 },
        },
        world = { 0, 0, -1000, 180 },

        markers = {
            { 1, 0, 18, 4, 0, 0, -1000, 0 },
            { 3, 3, 45, 0, 0, 0, 0, 0 },
            { 16, 0, 23, 2, 0, 0, -1300, 180 },
            { 16, 1, 23, 2, 0, 0, -3600, 180 },
            { 16, 2, 23, 2, 0, 0, -7200, 180 },
            { 16, 3, 23, 2, -1800, 0, -9000, 270 },
            { 16, 4, 23, 2, -5400, 69, -9000, 270 },
            { 16, 5, 23, 2, -7200, 350, -7200, 0 },
            { 16, 6, 23, 2, -5400, 600, -5400, 90 },
            { 16, 7, 23, 2, -3600, 600, -3600, 0 },
            { 16, 8, 23, 2, -5400, 600, -1800, 270 },
            { 16, 9, 23, 2, -7200, 600, 0, 0 },
            { 16, 10, 23, 2, -7200, 185, 3600, 0 },
            { 16, 11, 23, 2, -5400, 0, 5400, 90 },
            { 16, 12, 23, 2, 5400, 0, 5400, 90 },
            { 16, 13, 23, 2, 7200, 0, 3600, 180 },
            { 16, 14, 23, 2, 5400, 0, 1800, 270 },
            { 16, 15, 23, 2, 1800, 0, 1800, 270 },
            { 32, 1, 0, 1, -5600, 700, -4650, 0 },
            { 32, 1, 0, 0, -5600, 700, -4950, 0 },
            { 32, 1, 0, 0, -5600, 700, -5250, 0 },
            { 32, 1, 0, 0, -5600, 700, -5550, 0 },
            { 32, 1, 0, 0, -5600, 700, -5850, 0 },
            { 32, 1, 0, 1, -5600, 700, -6150, 0 },
            { 32, 2, 0, 1, -7950, 700, 1000, 0 },
            { 32, 2, 0, 0, -7650, 700, 1000, 0 },
            { 32, 2, 0, 0, -7350, 700, 1000, 0 },
            { 32, 2, 0, 0, -7050, 700, 1000, 0 },
            { 32, 2, 0, 0, -6750, 700, 1000, 0 },
            { 32, 2, 0, 1, -6450, 700, 1000, 0 },
            { 32, 3, 0, 1, 5200, 100, 6150, 0 },
            { 32, 3, 0, 0, 5200, 100, 5850, 0 },
            { 32, 3, 0, 0, 5200, 100, 5550, 0 },
            { 32, 3, 0, 0, 5200, 100, 5250, 0 },
            { 32, 3, 0, 0, 5200, 100, 4950, 0 },
            { 32, 3, 0, 1, 5200, 100, 4650, 0 },
            { 64, 0, 6, 4, 0, 0, 200, 0 },
            { 33, 1, 0, 0, -500, 300, 5400, 0 },
            { 33, 1, 0, 0, -300, 300, 5400, 0 },
            { 33, 1, 0, 0, -100, 300, 5400, 0 },
            { 33, 1, 0, 0, 100, 300, 5400, 0 },
            { 33, 1, 0, 0, 300, 300, 5400, 0 },
            { 33, 1, 0, 0, 500, 300, 5400, 0 },
        },
        survey = {
        },
    },
    dustcompound = {
        level = "empty2", budget = 1005, faults = 0,
        look = { sky = "BACKGROUND_DESERT", music = "SEQ_LEVEL_HOT", light = { 0.1, 0.4, 0.9 }, bake = { sun = { 0.5, 0.8, 0.3 }, sunc = { 1, 0.91, 0.72 }, sky = { 0.54, 0.52, 0.52 }, gnd = { 0.5, 0.41, 0.31 }, lo = { 0.96, 0.84, 0.74 }, hi = { 1, 0.94, 0.8 } } },
        baked = true,
        lightfog = 2,
        lean = true, staticCount = 144,

        pieces = {
        },

        spawns = {
            { -1600, 300, 3900, 180 },
            { -1600, 300, -3900, 0 },
            { -1100, 300, 3900, 180 },
            { -1100, 300, -3900, 0 },
            { -700, 300, 3900, 180 },
            { -700, 300, -3900, 0 },
            { -200, 300, 3900, 180 },
            { -200, 300, -3900, 0 },
            { 200, 300, 3900, 180 },
            { 200, 300, -3900, 0 },
            { 700, 300, 3900, 180 },
            { 700, 300, -3900, 0 },
            { 1100, 300, 3900, 180 },
            { 1100, 300, -3900, 0 },
            { 1600, 300, 3900, 180 },
            { 1600, 300, -3900, 0 },
        },
        survey = {
            points = { single = false, { -1600, 300, 3900, 180 }, { -1600, 300, -3900, 0 }, { 3350, 300, 50, 272 }, { -3250, 300, 50, 88 }, { 3050, 300, -4150, 325 }, { 3050, 300, 4150, 218 }, { 50, 300, -550, 354 }, { 850, 0, 2250, 203 }, { 1050, 0, -2750, 340 }, { -3350, 300, -2350, 53 }, { -3350, 300, 2450, 124 }, { -1250, 0, 1350, 134 }, { 3250, 300, -2050, 304 }, { 3350, 300, 2150, 240 }, { -1450, 0, -1850, 35 }, { 450, 300, 4150, 187 }, { 1650, 0, 650, 254 }, { 1750, 0, -1150, 307 }, { -3250, 300, -4050, 37 }, { 150, 300, -4150, 358 }, { -1650, 0, -250, 75 }, { -3250, 300, 4050, 140 }, { -650, 0, 2750, 166 }, { 1850, 300, 3350, 211 } },
        },
    },
    frostlineeight = {
        level = "empty2", budget = 120, faults = 0,
        look = { sky = "BACKGROUND_SNOW_MOUNTAINS", music = "SEQ_LEVEL_SNOW", light = { 0, 0, 0 }, bake = { sun = { -0.3, 0.62, 0.72 }, sunc = { 1.16, 1.14, 1.12 }, sky = { 0.41, 0.43, 0.46 }, gnd = { 0.37, 0.38, 0.41 }, lo = { 0.9, 0.94, 1 }, hi = { 1, 0.98, 0.94 } }, visuals = { { "snow", "snow" } }, weather = "snow", fog = "a blue distance", colour = "ice" },
        baked = true,
        lightfog = 2,
        lean = true, staticCount = 69,

        pieces = {
        },

        spawns = {
            { 7600, 0, -10750, 270 },
            { 7600, 0, -10250, 270 },
            { 7600, 0, -9750, 270 },
            { 7600, 0, -9250, 270 },
            { 8000, 0, -10750, 270 },
            { 8000, 0, -10250, 270 },
            { 8000, 0, -9750, 270 },
            { 8000, 0, -9250, 270 },
            { 8400, 0, -10750, 270 },
            { 8400, 0, -10250, 270 },
            { 8400, 0, -9750, 270 },
            { 8400, 0, -9250, 270 },
            { 8800, 0, -10750, 270 },
            { 8800, 0, -10250, 270 },
            { 8800, 0, -9750, 270 },
            { 8800, 0, -9250, 270 },
        },
        world = { 7200, 0, -10000, 270 },

        markers = {
            { 1, 0, 18, 4, 7200, 0, -10000, 0 },
            { 3, 3, 50, 0, 0, 0, 0, 0 },
            { 16, 0, 23, 2, 6900, 0, -10000, 270 },
            { 16, 1, 23, 2, 4000, 0, -10000, 270 },
            { 16, 2, 23, 2, 2000, 433, -8000, 0 },
            { 16, 3, 23, 2, 0, 800, 2000, 270 },
            { 16, 4, 23, 2, -2000, 200, 4000, 0 },
            { 16, 5, 23, 2, -2000, 0, 8000, 0 },
            { 16, 6, 23, 2, -4000, 0, 10000, 270 },
            { 16, 7, 23, 2, -8000, 0, 10000, 270 },
            { 16, 8, 23, 2, -10000, 0, 8000, 180 },
            { 16, 9, 23, 2, -10000, 0, 4000, 180 },
            { 16, 10, 23, 2, -8000, 0, 2000, 90 },
            { 16, 11, 23, 2, -6000, 0, 0, 180 },
            { 16, 12, 23, 2, -4000, 0, -2000, 90 },
            { 16, 13, 23, 2, 6000, 0, -4000, 180 },
            { 16, 14, 23, 2, 8000, 0, -6000, 90 },
            { 16, 15, 23, 2, 10000, 0, -8000, 180 },
            { 32, 1, 0, 1, -2750, 100, 6000, 0 },
            { 32, 1, 0, 0, -2450, 100, 6000, 0 },
            { 32, 1, 0, 0, -2150, 100, 6000, 0 },
            { 32, 1, 0, 0, -1850, 100, 6000, 0 },
            { 32, 1, 0, 0, -1550, 100, 6000, 0 },
            { 32, 1, 0, 1, -1250, 100, 6000, 0 },
            { 32, 2, 0, 1, -8200, 100, 9250, 0 },
            { 32, 2, 0, 0, -8200, 100, 9550, 0 },
            { 32, 2, 0, 0, -8200, 100, 9850, 0 },
            { 32, 2, 0, 0, -8200, 100, 10150, 0 },
            { 32, 2, 0, 0, -8200, 100, 10450, 0 },
            { 32, 2, 0, 1, -8200, 100, 10750, 0 },
            { 32, 3, 0, 1, -5250, 100, -400, 0 },
            { 32, 3, 0, 0, -5550, 100, -400, 0 },
            { 32, 3, 0, 0, -5850, 100, -400, 0 },
            { 32, 3, 0, 0, -6150, 100, -400, 0 },
            { 32, 3, 0, 0, -6450, 100, -400, 0 },
            { 32, 3, 0, 1, -6750, 100, -400, 0 },
            { 32, 4, 0, 1, 6750, 100, -4400, 0 },
            { 32, 4, 0, 0, 6450, 100, -4400, 0 },
            { 32, 4, 0, 0, 6150, 100, -4400, 0 },
            { 32, 4, 0, 0, 5850, 100, -4400, 0 },
            { 32, 4, 0, 0, 5550, 100, -4400, 0 },
            { 32, 4, 0, 1, 5250, 100, -4400, 0 },
            { 64, 0, 6, 4, -4400, 0, -2000, 0 },
            { 33, 1, 0, 0, 5300, 50, -3200, 0 },
            { 33, 1, 0, 0, 5300, 50, -3400, 0 },
            { 33, 1, 0, 0, 5300, 50, -3600, 0 },
            { 33, 1, 0, 0, 5300, 50, -3800, 0 },
            { 33, 1, 0, 0, 5300, 50, -4000, 0 },
            { 33, 1, 0, 0, 5300, 50, -4200, 0 },
        },
        survey = {
        },
    },
    meadowsweep = {
        level = "empty2", budget = 937, faults = 0,
        look = { sky = "BACKGROUND_OCEAN_SKY", music = "SEQ_LEVEL_GRASS", light = { 0, 0, 0 }, bake = { sun = { 0.4, 1.84, 0.36 }, sunc = { 1, 0.93, 0.78 }, sky = { 0.47, 0.5, 0.5 }, gnd = { 0.34, 0.38, 0.3 }, lo = { 0.8, 0.92, 0.84 }, hi = { 1, 0.96, 0.82 }, sun0 = { 0.4, 0.84, 0.36 } }, hourBaked = { 0, 1, 0 }, visuals = { { "shading", "a warm sun" } }, hour = "overhead", shade = "a warm sun" },
        baked = true,
        lightfog = 2,
        lean = true, staticCount = 64,

        pieces = {
        },

        spawns = {
            { -3000, 0, 9750, 90 },
            { -3000, 0, 9250, 90 },
            { -3000, 0, 8750, 90 },
            { -3000, 0, 8250, 90 },
            { -3400, 0, 9750, 90 },
            { -3400, 0, 9250, 90 },
            { -3400, 0, 8750, 90 },
            { -3400, 0, 8250, 90 },
            { -3800, 0, 9750, 90 },
            { -3800, 0, 9250, 90 },
            { -3800, 0, 8750, 90 },
            { -3800, 0, 8250, 90 },
            { -4200, 0, 9750, 90 },
            { -4200, 0, 9250, 90 },
            { -4200, 0, 8750, 90 },
            { -4200, 0, 8250, 90 },
        },
        world = { -2600, 0, 9000, 90 },

        markers = {
            { 1, 0, 18, 4, -2600, 0, 9000, 0 },
            { 3, 3, 45, 0, 0, 0, 0, 0 },
            { 16, 0, 23, 2, -2300, 0, 9000, 90 },
            { 16, 1, 23, 2, 0, 0, 9000, 90 },
            { 16, 2, 23, 2, 1800, 0, 7200, 180 },
            { 16, 3, 23, 2, 3600, 0, 5400, 90 },
            { 16, 4, 23, 2, 5400, 0, 3600, 180 },
            { 16, 5, 23, 2, 7200, 0, 1800, 90 },
            { 16, 6, 23, 2, 9000, 0, 0, 180 },
            { 16, 7, 23, 2, 9000, 0, -3600, 180 },
            { 16, 8, 23, 2, 7200, 0, -5400, 270 },
            { 16, 9, 23, 2, 3600, 415, -5400, 270 },
            { 16, 10, 23, 2, 1800, 600, -7200, 180 },
            { 16, 11, 23, 2, 0, 600, -9000, 270 },
            { 16, 12, 23, 2, -3600, 600, -9000, 270 },
            { 16, 13, 23, 2, -5400, 600, -7200, 0 },
            { 16, 14, 23, 2, -5400, 185, -3600, 0 },
            { 16, 15, 23, 2, -5400, 0, 7200, 0 },
            { 32, 1, 0, 1, 7400, 100, 2550, 0 },
            { 32, 1, 0, 0, 7400, 100, 2250, 0 },
            { 32, 1, 0, 0, 7400, 100, 1950, 0 },
            { 32, 1, 0, 0, 7400, 100, 1650, 0 },
            { 32, 1, 0, 0, 7400, 100, 1350, 0 },
            { 32, 1, 0, 1, 7400, 100, 1050, 0 },
            { 32, 2, 0, 1, 2550, 700, -7000, 0 },
            { 32, 2, 0, 0, 2250, 700, -7000, 0 },
            { 32, 2, 0, 0, 1950, 700, -7000, 0 },
            { 32, 2, 0, 0, 1650, 700, -7000, 0 },
            { 32, 2, 0, 0, 1350, 700, -7000, 0 },
            { 32, 2, 0, 1, 1050, 700, -7000, 0 },
            { 32, 3, 0, 1, -6150, 700, -5800, 0 },
            { 32, 3, 0, 0, -5850, 700, -5800, 0 },
            { 32, 3, 0, 0, -5550, 700, -5800, 0 },
            { 32, 3, 0, 0, -5250, 700, -5800, 0 },
            { 32, 3, 0, 0, -4950, 700, -5800, 0 },
            { 32, 3, 0, 1, -4650, 700, -5800, 0 },
            { 32, 4, 0, 1, -6150, 100, 7000, 0 },
            { 32, 4, 0, 0, -5850, 100, 7000, 0 },
            { 32, 4, 0, 0, -5550, 100, 7000, 0 },
            { 32, 4, 0, 0, -5250, 100, 7000, 0 },
            { 32, 4, 0, 0, -4950, 100, 7000, 0 },
            { 32, 4, 0, 1, -4650, 100, 7000, 0 },
            { 33, 1, 0, 0, -5400, 300, 1300, 0 },
            { 33, 1, 0, 0, -5400, 300, 1500, 0 },
            { 33, 1, 0, 0, -5400, 300, 1700, 0 },
            { 33, 1, 0, 0, -5400, 300, 1900, 0 },
            { 33, 1, 0, 0, -5400, 300, 2100, 0 },
            { 33, 1, 0, 0, -5400, 300, 2300, 0 },
        },
        survey = {
        },
    },
    rustyard = {
        level = "empty2", budget = 1005, faults = 0,
        look = { sky = "BACKGROUND_PURPLE_SKY", music = "SEQ_LEVEL_KOOPA_ROAD", light = { 0.1, 0.4, 0.9 }, bake = { sun = { 0.42, 0.78, 0.46 }, sunc = { 1, 0.91, 0.8 }, sky = { 0.48, 0.47, 0.5 }, gnd = { 0.35, 0.32, 0.33 }, lo = { 0.84, 0.84, 1 }, hi = { 1, 0.94, 0.84 } } },
        baked = true,
        lightfog = 2,
        lean = true, staticCount = 150,

        pieces = {
        },

        spawns = {
            { -1600, 0, 3900, 180 },
            { -1600, 0, -3900, 0 },
            { -1100, 0, 3900, 180 },
            { -1100, 0, -3900, 0 },
            { -700, 0, 3900, 180 },
            { -700, 0, -3900, 0 },
            { -200, 0, 3900, 180 },
            { -200, 0, -3900, 0 },
            { 200, 0, 3900, 180 },
            { 200, 0, -3900, 0 },
            { 700, 0, 3900, 180 },
            { 700, 0, -3900, 0 },
            { 1100, 0, 3900, 180 },
            { 1100, 0, -3900, 0 },
            { 1600, 0, 3900, 180 },
            { 1600, 0, -3900, 0 },
        },
        survey = {
            points = { single = false, { -1600, 0, 3900, 180 }, { -1600, 0, -3900, 0 }, { 3550, 0, 50, 269 }, { -3550, 0, 50, 91 }, { 250, 0, 1050, 193 }, { 1650, 0, -3050, 331 }, { 1650, 0, 4150, 202 }, { -750, 0, -1350, 30 }, { -3450, 0, -2350, 56 }, { 3150, 0, 2350, 233 }, { -3250, 0, 2350, 126 }, { 1450, 0, -850, 299 }, { 3550, 0, -2150, 301 }, { -1750, 0, 950, 120 }, { 150, 0, 3050, 183 }, { 250, 0, -4150, 356 }, { 2050, 0, 950, 244 }, { -2350, 0, -1050, 67 }, { 1550, 0, 2450, 212 }, { -1650, 0, 2450, 147 }, { 150, 0, -2550, 356 }, { -1750, 0, -2450, 36 }, { -750, 600, 50, 97 }, { 2750, 0, -1050, 290 } },
        },
    },
    splinteryard = {
        level = "empty2", budget = 120, faults = 0,
        look = { sky = "BACKGROUND_OCEAN_SKY", music = "SEQ_LEVEL_WATER", light = { 0.1, 0.4, 0.9 }, bake = { sun = { 0.46, 0.8, 0.38 }, sunc = { 1, 0.9, 0.72 }, sky = { 0.47, 0.5, 0.53 }, gnd = { 0.4, 0.34, 0.3 }, lo = { 0.82, 0.9, 0.8 }, hi = { 1, 0.93, 0.78 } } },
        baked = true,
        lightfog = 2,
        lean = true, staticCount = 101,

        pieces = {
        },

        spawns = {
            { -1600, 0, 2600, 180 },
            { -1600, 0, -2600, 0 },
            { -1100, 0, 2600, 180 },
            { -1100, 0, -2600, 0 },
            { -700, 0, 2600, 180 },
            { -700, 0, -2600, 0 },
            { -200, 0, 2600, 180 },
            { -200, 0, -2600, 0 },
            { 200, 0, 2600, 180 },
            { 200, 0, -2600, 0 },
            { 700, 0, 2600, 180 },
            { 700, 0, -2600, 0 },
            { 1100, 0, 2600, 180 },
            { 1100, 0, -2600, 0 },
            { 1600, 0, 2600, 180 },
            { 1600, 0, -2600, 0 },
        },
        survey = {
            points = { single = false, { -1600, 0, 2600, 180 }, { -1600, 0, -2600, 0 }, { 2650, 0, 250, 266 }, { 1650, 0, -2750, 332 }, { 1350, 0, 2750, 205 }, { -250, 0, 250, 116 }, { -2550, 300, -350, 81 }, { 150, 0, -1550, 359 }, { -50, 0, 1850, 175 }, { 1350, 0, 1150, 229 }, { 2350, 300, -1350, 303 }, { -2250, 600, 1150, 114 }, { -1250, 0, -1050, 51 }, { 1050, 300, -150, 283 }, { -250, 0, -2750, 7 }, { -1050, 0, 1150, 133 }, { -1350, 600, 50, 89 }, { 1250, 0, -1650, 327 }, { 2350, 300, 1350, 240 }, { -550, 0, 2750, 166 }, { -50, 0, -650, 13 }, { 650, 0, -2550, 349 }, { 450, 0, 2650, 187 }, { 350, 0, 1050, 193 } },
        },
    },
}

function venues.place_of(key)
    if type(key) ~= "string" or venues.LAYOUTS[key] == nil then return nil end
    if not OF.util.asks(OF.arena, "find") then return nil end
    return OF.arena.find(key)
end

local venueKeys = nil

function venues.forget_keys()
    venueKeys = nil
end
function venues.at(level, area)
    if type(level) ~= "number" then return nil end
    if venueKeys == nil then
        venueKeys = {}
        for key in pairs(venues.LAYOUTS) do venueKeys[#venueKeys + 1] = key end
        table.sort(venueKeys)
    end
    for _, key in ipairs(venueKeys) do
        local place = venues.place_of(key)
        if place ~= nil and place.level ~= nil and place.level == level
            and (area or 1) == (place.area or 1) then
            return key, place
        end
    end
    return nil
end

function venues.wanted()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil end
    return (venues.at(np.currLevelNum, np.currAreaIndex or 1))
end

venues.built = nil
venues.builtLevel = nil
venues.objects = {}
venues.models = {}
venues.arrived = false

local pieceOf = {}

local function mesh_of(kind)
    local name = venues.MESH[kind]
    if name == nil then return nil end
    return OF.util.optional("smlua_collision_util_get", nil, name)
end

venues.NO_MODEL = "none"
function venues.runtime_of(name)
    if type(name) ~= "string" or name:sub(1, 1) ~= "@" then return nil end
    local byte, slug, w, h, d = name:match("^@(%d+):([%w]+):(%d+):(%d+):(%d+)$")
    if byte == nil then return nil end
    return tonumber(byte), slug, tonumber(w), tonumber(h), tonumber(d)
end

function venues.join_of(name)
    if type(name) ~= "string" then return nil end
    local slug, arms, other = name:match("^@j:([%w]+):([01][01][01][01]):([%w%-]+)$")
    if slug == nil then return nil end
    local codes = {}
    for k = 1, 4 do codes[k] = tonumber(arms:sub(k, k)) end
    return slug, codes, other ~= "-" and other or nil
end

function venues.prop_of(name)
    if type(name) ~= "string" then return nil end
    local rid, a, b = name:match("^@p:(%d+):([%w%-]+):([%w%-]+)$")
    if rid == nil then return nil end
    return tonumber(rid), a ~= "-" and a or nil, b ~= "-" and b or nil
end

function venues.runtime_params(name)
    if OF.stretch == nil or not OF.util.asks(OF.spawner, "block_index") then return nil end
    local rid, pa, pb = venues.prop_of(name)
    if rid ~= nil then
        if not OF.util.asks(OF.stretch, "prop_encode") or OF.stretch.RECIPES == nil
            or OF.stretch.RECIPES[rid] == nil then
            return nil
        end
        return OF.stretch.prop_encode(rid, pa ~= nil and OF.spawner.block_index(pa) or 0,
            pb ~= nil and OF.spawner.block_index(pb) or 0)
    end
    local slug, codes, other = venues.join_of(name)
    if slug ~= nil then
        local index = OF.spawner.block_index(slug)
        if index == nil then return nil end
        local otherIndex = other ~= nil and OF.spawner.block_index(other) or 0
        return OF.stretch.join_encode(OF.stretch.JOIN_PILLAR, index, codes, otherIndex or 0)
    end
    local byte, texSlug, w, h, d = venues.runtime_of(name)
    if byte == nil then return nil end
    local index = OF.spawner.block_index(texSlug)
    if index == nil then return nil end
    return OF.stretch.shape_encode(byte, index, w, h, d)
end

local function model_of(name)
    if name == venues.NO_MODEL then return E_MODEL_NONE end
    if venues.runtime_of(name) ~= nil or venues.join_of(name) ~= nil
        or venues.prop_of(name) ~= nil then
        if venues.runtime_params(name) == nil then return E_MODEL_NONE end
        name = (OF.stretch and OF.stretch.SHAPE_MODEL) or "of_shape_geo"
    end
    local id = venues.models[name]
    if id ~= nil then return id end
    if OF.util.optional("mod_file_exists", false, "actors/" .. name .. ".bin") ~= true then
        return nil
    end
    id = OF.util.optional("smlua_model_util_get_id", nil, name)
    if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
    venues.models[name] = id
    return id
end

local function free_floor(o)
    local held = pieceOf[o]
    if held == nil then return end
    for _, handle in ipairs(held.handles or { held.handle }) do
        if handle ~= nil and OF.util.alive(handle) then
            OF.util.optional("remove_static_object_collision", nil, handle)
        end
    end
    held.handle, held.handles = nil, nil
end

local function piece_init(o)
    if o == nil then return end
    local held = pieceOf[o]
    if held == nil then return end
    o.collisionData = mesh_of(held.kind)
    o.oCollisionDistance = venues.REACH
    o.oDrawingDistance = venues.REACH
end

local function drawn_scale(held)
    if venues.PICTURES_AT_SIZE == true then return 1, 1, 1 end
    return held.sx, held.sy, held.sz
end

local function piece_loop(o)
    if o == nil then return end
    local held = pieceOf[o]
    if held == nil then return end

    local gfx = o.header ~= nil and o.header.gfx or nil
    if gfx ~= nil then gfx.skipInViewCheck = true end
    if held.floors ~= nil then
        if not held.built then venues.build_floors(o, held) end
        return
    end
    if held.handle ~= nil and OF.util.alive(held.handle) then return end
    if held.solidDone then return end
    if o.collisionData == nil then o.collisionData = mesh_of(held.kind) end
    o.oFaceAnglePitch, o.oFaceAngleRoll = 0, 0
    o.oFaceAngleYaw = held.yaw
    o.oMoveAngleYaw = held.yaw

    if held.prop ~= nil and OF.util.asks(OF.stretch, "solid") then
        local rid = OF.stretch.prop_decode(held.prop)
        local r = rid ~= nil and OF.stretch.RECIPES ~= nil and OF.stretch.RECIPES[rid] or nil
        if r ~= nil and r.boxes ~= nil then
            held.handles = OF.stretch.solid(o, OF.stretch.solid_pieces(held.prop, nil,
                mesh_of("box"), 1, 1))
            held.handle = held.handles[1]
            held.solidDone = true
            OF.util.optional("obj_scale_xyz", nil, o, drawn_scale(held))
            return
        end
    end
    if o.collisionData == nil then
        OF.util.optional("obj_scale_xyz", nil, o, drawn_scale(held))
        return
    end

    if held.join ~= nil and OF.util.asks(OF.stretch, "solid") then
        held.handles = OF.stretch.solid(o, OF.stretch.solid_pieces(held.join,
            o.collisionData, mesh_of("box"), held.sx, 1))
        held.handle = held.handles[1]
        return
    end

    OF.util.optional("obj_scale_xyz", nil, o, held.sx, held.sy, held.sz)
    held.handle = OF.util.optional("load_static_object_collision", nil)
    OF.util.optional("obj_scale_xyz", nil, o, drawn_scale(held))
end

venues.PIECE = nil
if type(hook_behavior) == "function" then
    venues.PIECE = hook_behavior(nil, OBJ_LIST_SURFACE, false,
        piece_init, piece_loop, "of venue piece")
end

if type(hook_event) == "function" and HOOK_ON_OBJECT_UNLOAD ~= nil then
    hook_event(HOOK_ON_OBJECT_UNLOAD, function(o)
        if o ~= nil and pieceOf[o] ~= nil then
            free_floor(o)
            pieceOf[o] = nil
        end
    end)
end

venues.MERGE_FROM = 150

function venues.sunlit(layout)
    local look = layout ~= nil and layout.look or nil
    return type(look) == "table" and look.sun == true and type(look.bake) == "table"
end
venues.floorObject = nil
venues.batchObjects = {}
venues.mergedRows = 0
venues.levelRows = 0
venues.floorBaked = false
local batchKeys = {}

function venues.can_merge()
    return type(rawget(_G, "obj_build_transform_from_pos_and_angle")) == "function"
        and type(rawget(_G, "load_static_object_collision")) == "function"
        and OF.stretch ~= nil and OF.util.asks(OF.stretch, "merge_plan")
        and OF.util.asks(OF.stretch, "pin")
end

function venues.build_floors(o, held)
    held.built = true
    local handles = {}
    local x, y, z = o.oPosX, o.oPosY, o.oPosZ
    for _, r in ipairs(held.floors) do
        local mesh = mesh_of(r.kind)
        if mesh ~= nil then
            o.collisionData = mesh
            o.oPosX, o.oPosY, o.oPosZ = r.x, r.y, r.z
            o.oFaceAnglePitch, o.oFaceAngleRoll = 0, 0
            o.oFaceAngleYaw, o.oMoveAngleYaw = r.yaw, r.yaw
            OF.util.optional("obj_build_transform_from_pos_and_angle", nil, o, 0x06, 0x12)
            OF.util.optional("obj_scale_xyz", nil, o, r.sx, r.sy, r.sz)
            local handle = OF.util.optional("load_static_object_collision", nil)
            if handle ~= nil then handles[#handles + 1] = handle end
        end
    end
    o.oPosX, o.oPosY, o.oPosZ = x, y, z
    o.oFaceAngleYaw, o.oMoveAngleYaw = 0, 0
    OF.util.optional("obj_build_transform_from_pos_and_angle", nil, o, 0x06, 0x12)
    OF.util.optional("obj_scale_xyz", nil, o, 1, 1, 1)
    o.collisionData = nil
    held.handles = handles
    held.handle = handles[1]
    return #handles
end

local INVISIBLE = GRAPH_RENDER_INVISIBLE or 0x10
local function batch_loop(o)
    if o == nil or o.header == nil or o.header.gfx == nil then return end
    local gfx = o.header.gfx
    gfx.skipInViewCheck = true
    local holds = OF.stretch ~= nil and OF.util.asks(OF.stretch, "pin") and OF.stretch.pin(o)
    local flags = tonumber(gfx.node.flags) or 0
    local hidden = OF.util.has_flag(flags, INVISIBLE)
    if holds and hidden then
        gfx.node.flags = flags - INVISIBLE
    elseif not holds and not hidden then
        gfx.node.flags = OF.util.add_flag(flags, INVISIBLE)
    end
end

local function batch_init(o)
    if o == nil then return end
    o.oDrawingDistance = venues.REACH * 2
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = 0, 0, 0
    o.oMoveAngleYaw = 0
    batch_loop(o)
end

venues.BATCH = nil
if type(hook_behavior) == "function" then
    venues.BATCH = hook_behavior(nil, OBJ_LIST_SURFACE, false,
        batch_init, batch_loop, "of venue batch")
end

local function forget_batches()
    if OF.stretch ~= nil and OF.util.asks(OF.stretch, "merge_forget") then
        for _, params in ipairs(batchKeys) do OF.stretch.merge_forget(params) end
    end
    batchKeys = {}
end

function venues.cost()
    local n = 0
    local function live(o) return o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 end
    for _, o in pairs(venues.objects) do if live(o) then n = n + 1 end end
    for _, o in ipairs(venues.batchObjects) do if live(o) then n = n + 1 end end
    if live(venues.floorObject) then n = n + 1 end
    return n
end

function venues.baked_here(key)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    if layout == nil or layout.baked ~= true then return false end
    local dl = OF.util.optional("gfx_get_from_name", nil, "of_" .. key .. "_static_dl")
    return dl ~= nil
end

function venues.standable(key)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    if layout == nil then return false end
    if layout.lean ~= true then return true end
    return venues.baked_here(key)
end

venues.BASE_SURFACES = { empty = 4, empty2 = 2 }

function venues.level_baked(level, area)
    local key = venues.at(level, area)
    if key == nil or not venues.baked_here(key) then return nil end
    return venues.BASE_SURFACES[venues.LAYOUTS[key].level] or 0
end

function venues.rows_of(layout)
    local rows = {}
    for _, row in ipairs(layout.pieces or {}) do rows[#rows + 1] = row end
    local first = #rows + 1
    for _, row in ipairs(layout.static or {}) do rows[#rows + 1] = row end
    return rows, first
end

local function angle(degrees)
    local turn = math.floor((tonumber(degrees) or 0) * 65536 / 360 + 0.5) % 65536
    if turn >= 32768 then turn = turn - 65536 end
    return turn
end
venues.to_angle = angle

function venues.build(key)
    local layout = venues.LAYOUTS[key]
    if layout == nil or venues.PIECE == nil then return 0 end
    if not venues.standable(key) then

        if venues.unstandableSaid ~= key then
            venues.unstandableSaid = key
            if OF.util.asks(OF.notify, "show") then
                OF.notify.show("This venue's level is out of date - it cannot be built here", "warn", 6)
            end
        end
        return 0
    end
    venues.unstandableSaid = nil
    venues.teardown()
    local stood = 0

    local baked = venues.baked_here(key)
    local rows = baked and (layout.pieces or {}) or (venues.rows_of(layout))

    local shapeModel = OF.stretch ~= nil and model_of(OF.stretch.SHAPE_MODEL) or nil
    local merging = (#rows > venues.MERGE_FROM or venues.sunlit(layout))
        and venues.PIECE ~= nil
        and venues.BATCH ~= nil and shapeModel ~= nil and venues.can_merge()
    local floors = {}
    if merging then
        local still, stillAt = {}, {}
        for index, row in ipairs(rows) do
            local model = model_of(row[2])
            if model ~= nil and (tonumber(row[9]) or 0) % 90 == 0 then
                local byte, slug, w, h, d = venues.runtime_of(row[2])
                if model == E_MODEL_NONE then
                    floors[#floors + 1] = index
                elseif byte ~= nil and venues.runtime_params(row[2]) ~= nil then
                    still[#still + 1] = { byte, OF.spawner.block_index(slug), w, h, d,
                                          row[3], row[4], row[5], tonumber(row[9]) or 0 }
                    stillAt[#still] = index
                end
            end
        end
        venues.bake_prepare(layout)
        local groups = OF.stretch.merge_plan(still)
        for _, g in ipairs(groups) do
            batchKeys[#batchKeys + 1] = g.params
            for _, i in ipairs(g.rows) do floors[#floors + 1] = stillAt[i] end
            local o = OF.slots.spawn_non_sync(venues.BATCH, shapeModel, 0, 0, 0, function(obj)
                obj.oBehParams = g.params
                obj.oFaceAngleYaw, obj.oMoveAngleYaw = 0, 0
                obj.oFaceAnglePitch, obj.oFaceAngleRoll = 0, 0
            end)
            if o ~= nil then
                venues.batchObjects[#venues.batchObjects + 1] = o
            else

                for _ = 1, #g.rows do table.remove(floors) end
            end
        end
        table.sort(floors)
    end
    local merged = {}
    if #floors > 0 then
        local held = { floors = {}, index = 0, yaw = 0, sx = 1, sy = 1, sz = 1 }
        for _, index in ipairs(floors) do
            local row = rows[index]
            held.floors[#held.floors + 1] = { kind = row[1], x = row[3], y = row[4], z = row[5],
                yaw = angle(row[9]), sx = row[6] / venues.CELL, sy = row[7] / venues.CELL,
                sz = row[8] / venues.CELL }
        end
        local o = OF.slots.spawn_non_sync(venues.PIECE, E_MODEL_NONE, 0, 0, 0, function(obj)
            pieceOf[obj] = held
            obj.oFaceAngleYaw, obj.oMoveAngleYaw = 0, 0
            obj.oFaceAnglePitch, obj.oFaceAngleRoll = 0, 0
        end)
        if o ~= nil then
            pieceOf[o] = held
            venues.floorObject = o
            venues.mergedRows = #floors
            stood = stood + #floors
            for _, index in ipairs(floors) do merged[index] = true end
        else

            for _, b in ipairs(venues.batchObjects) do
                OF.util.optional("obj_mark_for_deletion", nil, b)
            end
            venues.batchObjects = {}
            forget_batches()
        end
    end
    for index, row in ipairs(rows) do
        local kind, model = row[1], model_of(row[2])
        if model ~= nil and not merged[index] then
            local held = {
                kind = kind, index = index, yaw = angle(row[9]),
                sx = row[6] / venues.CELL, sy = row[7] / venues.CELL,
                sz = row[8] / venues.CELL,
            }

            local params = venues.runtime_params(row[2])
            if params ~= nil and venues.join_of(row[2]) ~= nil then held.join = params end
            if params ~= nil and venues.prop_of(row[2]) ~= nil then held.prop = params end
            local o = OF.slots.spawn_non_sync(venues.PIECE, model, row[3], row[4], row[5],
                function(obj)
                    pieceOf[obj] = held
                    if params ~= nil then obj.oBehParams = params end
                    obj.oFaceAngleYaw = held.yaw
                    obj.oMoveAngleYaw = held.yaw
                    obj.oFaceAnglePitch, obj.oFaceAngleRoll = 0, 0
                    OF.util.optional("obj_scale_xyz", nil, obj, drawn_scale(held))
                end)
            if o ~= nil then
                pieceOf[o] = held
                venues.objects[index] = o
                stood = stood + 1
            end
        end
    end
    venues.built = key
    venues.floorBaked = baked

    if OF.util.asks(OF.modifiers, "write_fog_colour") then OF.modifiers.write_fog_colour() end
    if baked then

        venues.levelRows = tonumber(layout.staticCount) or #(layout.static or {})
        stood = stood + venues.levelRows
        venues.level_bake_prepare(key, layout)
        venues.wear_lods(venues.LODS)
        venues.cull_prepare()
    else

        venues.hold_start()
    end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    venues.builtLevel = np ~= nil and np.currLevelNum or nil
    venues.markers(layout)
    venues.venue_water(layout, true)
    venues.place_stars()
    venues.settle_look()
    return stood
end

function venues.teardown()
    for _, o in pairs(venues.objects) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            free_floor(o)
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end
    for _, o in ipairs(venues.markerObjects or {}) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end

    local builder = venues.floorObject
    if builder ~= nil and OF.util.alive(builder) and builder.activeFlags ~= 0 then
        free_floor(builder)
        OF.util.optional("obj_mark_for_deletion", nil, builder)
    end
    for _, o in ipairs(venues.batchObjects) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end
    venues.floorObject, venues.batchObjects, venues.mergedRows = nil, {}, 0
    venues.levelRows, venues.floorBaked = 0, false
    forget_batches()
    venues.bake_forget()
    venues.level_bake_forget()
    venues.lights_forget(false)
    venues.wear_lods(false)
    venues.cull_release()
    venues.take_things()
    venues.take_stars()
    venues.venue_water(nil, false)
    venues.objects = {}
    venues.markerObjects = {}
    local was = venues.built
    venues.built = nil
    venues.builtLevel = nil
    if OF.util.asks(OF.modifiers, "write_fog_colour") then OF.modifiers.write_fog_colour() end
    if was ~= nil then venues.settle_look() end
    return was ~= nil
end

function venues.count()
    local n = 0
    for _, o in pairs(venues.objects) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then n = n + 1 end
    end
    local builder = venues.floorObject
    if builder ~= nil and OF.util.alive(builder) and builder.activeFlags ~= 0 then
        n = n + venues.mergedRows
    end
    return n + venues.levelRows
end

venues.markerObjects = {}
function venues.markers(layout)
    venues.markerObjects = {}
    if type(layout.markers) ~= "table" then return 0 end
    local behaviour = rawget(_G, "bhvOfTrackMarker")
    if behaviour == nil then return 0 end
    for _, row in ipairs(layout.markers) do
        local params = row[1] * 16777216 + row[2] * 65536 + row[3] * 256 + row[4]
        local o = OF.slots.spawn_non_sync(behaviour, E_MODEL_NONE, row[5], row[6], row[7],
            function(obj)
                obj.oBehParams = params
                obj.oFaceAngleYaw = angle(row[8] or 0)
            end)
        if o ~= nil then table.insert(venues.markerObjects, o) end
    end
    return #venues.markerObjects
end

venues.things = {}
venues.thingsDone = false

function venues.round_mode()
    local inRound = false
    local scope = OF.roundscope
    if OF.util.asks(scope, "inside") and scope.inside(0) then inRound = true end
    if OF.util.asks(scope, "held_here") and scope.held_here() then inRound = true end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np ~= nil and OF.util.asks(OF.roundact, "private")
        and OF.roundact.private(np.currActNum) then
        inRound = true
    end
    if not inRound then return nil end
    local modes = OF.gamemodes
    local mode = OF.util.asks(modes, "current") and modes.current() or nil
    return mode ~= nil and mode.key or "?"
end

function venues.thing_stands(row, roundMode)
    if roundMode == nil then return true end
    if type(row) ~= "table" or type(row.modes) ~= "table" then return false end
    for _, key in ipairs(row.modes) do
        if key == roundMode then return true end
    end
    return false
end

venues.THINGS_SETTLE = 20
venues.THINGS_WAIT = 10 * 30
venues.thingsWaited = 0
venues.THINGS_NEAR = 400

local function same_room(np, me)
    return np ~= nil and np.connected and np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex and np.currActNum == me.currActNum
end

function venues.things_standing(objects, roundMode)
    if type(objects) ~= "table" or not OF.util.asks(OF.spawner, "find") then return false end
    local first = OF.util.binding("obj_get_first_with_behavior_id")
    local nextOf = OF.util.binding("obj_get_next_with_same_behavior_id")
    if first == nil or nextOf == nil then return false end
    local asked = 0
    for _, row in ipairs(objects) do
        if asked >= 3 then break end
        if venues.thing_stands(row, roundMode) then
            local entry = OF.spawner.find(row[1])
            if entry ~= nil and entry.bhv ~= nil then
                asked = asked + 1
                local o = first(entry.bhv)
                local guard = 0
                while o ~= nil and guard < 2000 do
                    local dx = (o.oPosX or 0) - (row[2] or 0)
                    local dy = (o.oPosY or 0) - (row[3] or 0)
                    local dz = (o.oPosZ or 0) - (row[4] or 0)
                    if dx * dx + dy * dy + dz * dz <= venues.THINGS_NEAR * venues.THINGS_NEAR then
                        return true
                    end
                    o = nextOf(o)
                    guard = guard + 1
                end
            end
        end
    end
    return false
end

function venues.room_shared()
    local me = gNetworkPlayers[0]
    for i = 1, MAX_PLAYERS - 1 do
        if same_room(gNetworkPlayers[i], me) then return true end
    end
    return false
end

function venues.things_turn(objects, roundMode)
    if venues.things_standing(objects, roundMode) then return "skip" end
    local me = gNetworkPlayers[0]
    local mine = me.globalIndex or network_global_index_from_local(0)
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if same_room(np, me) and np.globalIndex < mine
            and venues.thingsWaited < venues.THINGS_WAIT then
            return "wait"
        end
    end
    return "spawn"
end

function venues.place_things()
    if venues.thingsDone or venues.built == nil then return 0 end
    local layout = venues.LAYOUTS[venues.built]
    local objects = layout ~= nil and type(layout.objects) == "table" and layout.objects or {}
    local movers = layout ~= nil and type(layout.movers) == "table" and layout.movers or {}
    if #objects == 0 and #movers == 0 then
        venues.thingsDone = true
        return 0
    end
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil

    if me == nil or not me.currAreaSyncValid then return 0 end
    local roundMode = venues.round_mode()
    venues.thingsWaited = venues.thingsWaited + 1
    if venues.room_shared() and venues.thingsWaited <= venues.THINGS_SETTLE then return 0 end

    local turn = venues.things_turn(objects, roundMode)
    if turn == "wait" then return 0 end
    venues.thingsDone = true
    if turn ~= "spawn" then return 0 end

    if roundMode == nil and OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then
        return 0
    end
    if not OF.util.asks(OF.spawner, "find") then return 0 end
    local stood = 0
    for _, row in ipairs(objects) do
        if venues.thing_stands(row, roundMode) then
            local entry = OF.spawner.find(row[1])
            if entry ~= nil and entry.bhv ~= nil then
                local o = venues.lay_object(row, entry)
                if o ~= nil then
                    table.insert(venues.things, { object = o, key = row[1] })
                    stood = stood + 1
                end
            end
        end
    end
    stood = stood + venues.place_movers(movers, roundMode)
    return stood
end

local function is_onoff(entry)
    return OF.spawner ~= nil and entry.bhv ~= nil and entry.bhv == OF.spawner.ONOFF
end

function venues.row_params(entry, index)
    local variant = nil
    if type(entry.variants) == "table" then
        variant = entry.variants[math.floor(tonumber(index) or 1)] or entry.variants[1]
    end
    local second = variant ~= nil and variant.value or entry.variant
    local first = variant ~= nil and variant.first or nil
    local mask = variant ~= nil and variant.mask or nil
    local params = entry.params
    if type(second) == "number" or type(first) == "number" or type(mask) == "number" then
        params = 0
        if type(second) == "number" then params = params + ((second & 0xFF) << 16) end
        if type(entry.rtex) == "number" then params = params + (math.floor(entry.rtex) & 0x3FF) end
        if type(mask) == "number" then params = params + ((math.floor(mask) & 0xFF) << 8) end
        if type(first) == "number" then params = params + ((math.floor(first) & 0xFF) << 24) end
    end

    if second == nil and type(entry.params) == "number" and entry.variants == nil
        and entry.variant == nil and (is_onoff(entry) or entry.logic) then
        second = (entry.params >> 16) & 0xFF
    end
    local model = (variant ~= nil and variant.model) or entry.model
    return { second = type(second) == "number" and math.floor(second) or nil,
             params = params, model = model, variant = variant }
end

venues.REACH_FRAMES = 6
venues.reach = {}
function venues.lay_object(row, entry)
    local made = venues.row_params(entry, row.variant)
    local yaw = angle(row[5])
    local pitch = row.pitch ~= nil and angle(row.pitch) or nil
    local pipe = entry.pipe and type(row.pipe) == "table" and OF.util.asks(OF.forge, "pipe_setup")
    if pipe then
        OF.forge.pipeDestNext = row.pipe
        OF.forge.pipeTagNext = tonumber(row.pipe.tag)
    end

    local racer = entry.racer ~= nil and OF.util.asks(OF.forge, "racer_setup")
    if racer then
        local meta = type(row.meta) == "table" and row.meta or nil
        OF.forge.racerTrackNext = math.floor(tonumber(row.track) or 1)
        OF.forge.racerOrderNext = tonumber(row.order)
        OF.forge.racerMetaNext = meta ~= nil and { name = tostring(meta.name or ""),
            kind = meta.kind == "race" and "race" or "speedrun",
            laps = tonumber(meta.laps) } or nil
    end
    local ok, o = pcall(OF.slots.spawn_sync, entry.bhv, made.model, row[2], row[3], row[4],
        function(obj)
            obj.oFaceAngleYaw = yaw
            obj.oMoveAngleYaw = yaw
            if pitch ~= nil then obj.oFaceAnglePitch = pitch end
            if made.second ~= nil then obj.oBehParams2ndByte = made.second end
            if made.params ~= nil then obj.oBehParams = made.params end

            if entry.logic and row.link ~= nil then
                obj.oBehParams = (math.floor(tonumber(obj.oBehParams) or 0) & 0xFFFFFF)
                    + ((math.floor(tonumber(row.link) or 0) & 0xFF) << 24)
            end
            if entry.reach ~= nil then obj.oCollisionDistance = entry.reach end

            if entry.action ~= nil then obj.oAction = entry.action end
            if pipe then OF.forge.pipe_setup(obj) end
            if racer then OF.forge.racer_setup(obj, entry) end
        end)
    if pipe then OF.forge.pipeDestNext, OF.forge.pipeTagNext = nil, nil end
    if racer then
        OF.forge.racerOrderNext, OF.forge.racerTrackNext, OF.forge.racerMetaNext = nil, nil, nil
    end
    if not ok then error(o) end
    if o ~= nil and (entry.reach ~= nil or entry.settle ~= nil) then
        table.insert(venues.reach, { object = o, reach = entry.reach, settle = entry.settle,
                                     x = row[2], y = row[3], z = row[4],
                                     frames = venues.REACH_FRAMES })
    end

    if o ~= nil and entry.companion ~= nil and OF.util.asks(OF.spawner, "spawn_companion") then
        OF.spawner.spawn_companion(entry.companion, o, row[2], row[3], row[4])
    end
    return o
end

function venues.reach_update()
    for i = #venues.reach, 1, -1 do
        local r = venues.reach[i]
        local o = r.object
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            if r.reach ~= nil then o.oCollisionDistance = r.reach end
            if r.settle ~= nil then r.settle(o, r.x, r.y, r.z) end
        end
        r.frames = r.frames - 1
        if r.frames <= 0 or o == nil or o.activeFlags == 0 then table.remove(venues.reach, i) end
    end
end

function venues.place_movers(movers, roundMode)
    local stood = 0
    if type(movers) ~= "table" or not OF.util.asks(OF.spawner, "place_mover") then return 0 end
    for _, row in ipairs(movers) do
        if venues.thing_stands(row, roundMode) and type(row[9]) == "table" then
            local points = {}
            for _, p in ipairs(row[9]) do
                table.insert(points, { x = p[1], y = p[2], z = p[3], speed = p[4], wait = p[5] })
            end
            local o = OF.spawner.place_mover(row[1], row[2], row[3], row[4], angle(row[5]),
                { mode = row[6], trigger = row[7], phase = row[8], points = points,
                  link = row.link })
            if o ~= nil then
                table.insert(venues.things, { object = o, key = row[1] })
                stood = stood + 1
            end
        end
    end
    return stood
end

function venues.take_things()
    for _, t in ipairs(venues.things) do
        local o = t.object
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            if OF.util.asks(OF.spawner, "take_down") then
                OF.spawner.take_down(o, t.key)
            else
                OF.util.optional("obj_mark_for_deletion", nil, o)
            end
        end
    end
    venues.things = {}
    venues.thingsDone = false
end

venues.water = {}
venues.WATER_CELL = 1024
local waterIndex = {}
local waterCount = 0

local function water_cells(box, fn)
    local c = venues.WATER_CELL
    for i = math.floor(box[1] / c), math.floor(box[3] / c) do
        for j = math.floor(box[2] / c), math.floor(box[4] / c) do
            fn(i * 65536 + j)
        end
    end
end

function venues.water_remove(id)
    local box = venues.water[id]
    if box == nil then return false end
    water_cells(box, function(k)
        local set = waterIndex[k]
        if set ~= nil then
            set[id] = nil
            if next(set) == nil then waterIndex[k] = nil end
        end
    end)
    venues.water[id] = nil
    waterCount = waterCount - 1
    return true
end

function venues.water_add(id, x0, z0, x1, z1, top, bottom)
    if id == nil or type(x0) ~= "number" or type(top) ~= "number" then return false end
    venues.water_remove(id)
    local box = { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1),
                  top, type(bottom) == "number" and bottom or top - 400 }
    venues.water[id] = box
    water_cells(box, function(k)
        waterIndex[k] = waterIndex[k] or {}
        waterIndex[k][id] = true
    end)
    waterCount = waterCount + 1
    return true
end

function venues.water_at(x, z, y)
    if waterCount == 0 or type(x) ~= "number" or type(z) ~= "number" then return nil end
    local c = venues.WATER_CELL
    local set = waterIndex[math.floor(x / c) * 65536 + math.floor(z / c)]
    if set == nil then return nil end
    local spans = {}
    for id in pairs(set) do
        local b = venues.water[id]
        if b ~= nil and b[1] <= x and x <= b[3] and b[2] <= z and z <= b[4] then
            spans[#spans + 1] = { b[6], b[5] }
        end
    end
    return venues.water_surface(spans, y)
end

function venues.water_surface(spans, y)
    if #spans == 0 then return nil end
    table.sort(spans, function(a, b) return a[1] < b[1] end)

    local bodies = { { spans[1][1], spans[1][2] } }
    for i = 2, #spans do
        local last = bodies[#bodies]
        if spans[i][1] <= last[2] + 1 then
            if spans[i][2] > last[2] then last[2] = spans[i][2] end
        else
            bodies[#bodies + 1] = { spans[i][1], spans[i][2] }
        end
    end
    local ref = y
    if type(ref) ~= "number" then return bodies[#bodies][2] end
    local best = nil
    for _, body in ipairs(bodies) do
        if body[1] <= ref + 50 then best = body end
    end
    return best ~= nil and best[2] or nil
end

venues.PROBE_AT = 31000
function venues.water_possible()
    local find = OF.util.binding("find_water_level")
    if find == nil then return false end
    local p = venues.PROBE_AT
    venues.water_add("probe", p, p, p + 100, p + 100, 12345, -30000)
    local ok, h = pcall(find, p + 50, p + 50)
    venues.water_remove("probe")
    return ok and h == 12345
end

if type(hook_event) == "function" and HOOK_ON_FIND_WATER_LEVEL ~= nil then
    hook_event(HOOK_ON_FIND_WATER_LEVEL, function(x, z, levelSays)
        if waterCount == 0 then return nil end
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        local y = m ~= nil and m.pos ~= nil and m.pos.y or nil
        return venues.water_at(x, z, y)
    end)
end

local function venue_water(layout, on)
    for id in pairs(venues.water) do
        if type(id) == "string" and string.sub(id, 1, 6) == "venue:" then
            venues.water_remove(id)
        end
    end
    if not on or type(layout) ~= "table" or type(layout.water) ~= "table" then return 0 end
    for i, row in ipairs(layout.water) do
        venues.water_add("venue:" .. i, row[1], row[2], row[3], row[4], row[5], row[6])
    end
    return #layout.water
end
venues.venue_water = venue_water

venues.STAR_REACH = 160
venues.STAR_KEY = "ofBonus"
venues.TOOK_KEY = "ofBonusTook"
venues.starObjects = {}
local starSpin = 0
local tookSeen = {}

function venues.bonus_masks()
    local text = gGlobalSyncTable ~= nil and gGlobalSyncTable[venues.STAR_KEY] or nil
    local out = {}
    if type(text) ~= "string" then return out end
    for key, mask in string.gmatch(text, "([%w_]+):(%d+)") do out[key] = tonumber(mask) end
    return out
end

function venues.bonus_taken(key, id)
    local mask = venues.bonus_masks()[key] or 0
    return math.floor(mask / (2 ^ (id - 1))) % 2 == 1
end

function venues.bonus_count(key)
    local mask = venues.bonus_masks()[key] or 0
    local n = 0
    while mask > 0 do
        n = n + mask % 2
        mask = math.floor(mask / 2)
    end
    return n
end

function venues.bonus_publish()
    if not OF.util.is_host() then return nil end
    local parts = {}
    local keys = {}
    for key, layout in pairs(venues.LAYOUTS) do
        if (type(layout.stars) == "table" and #layout.stars > 0) or layout.redStar == true then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local mask = tonumber(OF.util.stored("bonus_" .. key, "0")) or 0
        if mask > 0 then parts[#parts + 1] = key .. ":" .. math.floor(mask) end
    end
    local text = table.concat(parts, ",")
    OF.util.publish(venues.STAR_KEY, text)
    return text
end

function venues.bonus_record(key, id, taker)
    if not OF.util.is_host() then return false end
    if not venues.star_valid(key, id) then return false end
    local mask = tonumber(OF.util.stored("bonus_" .. key, "0")) or 0
    local bit = 2 ^ (id - 1)
    if math.floor(mask / bit) % 2 == 1 then return false end
    mask = mask + bit
    OF.util.store("bonus_" .. key, tostring(math.floor(mask)))
    venues.bonus_publish()

    if taker ~= nil and OF.util.asks(OF.lobbytalk, "bonus_star_line") then
        local place = venues.place_of(key)
        OF.lobbytalk.bonus_star_line(taker, venues.star_name(key, id),
            place ~= nil and place.name or key)
    end
    return true
end

local function star_model(taken)
    if taken and E_MODEL_TRANSPARENT_STAR ~= nil then return E_MODEL_TRANSPARENT_STAR end
    return E_MODEL_STAR
end

venues.COIN_STAR_ID = 30
venues.COIN_STAR_COINS = 100
venues.COIN_STAR_RISE = 300
venues.coinStarDone = false

function venues.coin_star(key)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    return layout ~= nil and layout.coinStar == true and type(layout.stars) == "table"
        and #layout.stars > 0
end

venues.RED_STAR_ID = 31
venues.RED_STAR_RISE = 150
function venues.red_star(key)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    return layout ~= nil and layout.redStar == true
end

function venues.star_valid(key, id)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    if layout == nil then return false end
    if type(layout.stars) == "table" and layout.stars[id] ~= nil then return true end
    if id == venues.RED_STAR_ID then return venues.red_star(key) end
    return id == venues.COIN_STAR_ID and venues.coin_star(key)
end

venues.reds = nil
function venues.red_star_update()
    local key = venues.built
    if not venues.red_star(key) or id_bhvRedCoin == nil
        or OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return false
    end
    if venues.round_mode() ~= nil then return false end
    local live = {}
    local o = obj_get_first_with_behavior_id(id_bhvRedCoin)
    while o ~= nil and #live < 256 do
        if o.activeFlags ~= 0 then live[#live + 1] = { o.oPosX, o.oPosY, o.oPosZ } end
        o = obj_get_next_with_same_behavior_id(o)
    end
    local reds = venues.reds
    if reds == nil or reds.key ~= key then
        reds = { key = key, most = 0, at = {} }
        venues.reds = reds
    end
    if #live > reds.most then reds.most = #live end
    if reds.most > 0 and #live < #reds.at then
        for _, p in ipairs(reds.at) do
            local still = false
            for _, q in ipairs(live) do
                if math.abs(p[1] - q[1]) < 1 and math.abs(p[3] - q[3]) < 1 then still = true end
            end
            if not still then reds.last = p end
        end
        local got = reds.most - #live
        if SOUND_MENU_COLLECT_RED_COIN ~= nil then
            OF.sounds.play(SOUND_MENU_COLLECT_RED_COIN + (math.max(0, math.min(7, got - 1)) << 16))
        end
    end
    reds.at = live
    if #live == 0 and reds.most > 0 and not reds.done and reds.last ~= nil then
        reds.done = true
        local bhv = rawget(_G, "id_bhvStaticObject")
        if bhv == nil then return false end
        local taken = venues.bonus_taken(key, venues.RED_STAR_ID)
        venues.takenAtPlace[venues.RED_STAR_ID] = taken
        local s = OF.slots.spawn_non_sync(bhv, taken and E_MODEL_TRANSPARENT_STAR or E_MODEL_STAR,
            reds.last[1], reds.last[2] + venues.RED_STAR_RISE, reds.last[3],
            function(obj) obj.oFaceAngleYaw = 0 end)
        if s ~= nil then venues.starObjects[venues.RED_STAR_ID] = s end
        return true
    end
    return false
end

function venues.coin_star_update(m)
    local key = venues.built
    if venues.coinStarDone or m == nil or m.pos == nil or not venues.coin_star(key) then return end
    if venues.round_mode() ~= nil or venues.selecting ~= nil then return end
    if (m.numCoins or 0) < venues.COIN_STAR_COINS then return end
    venues.coinStarDone = true
    local bhv = rawget(_G, "id_bhvStaticObject")
    if bhv == nil then return end
    local taken = venues.bonus_taken(key, venues.COIN_STAR_ID)
    venues.takenAtPlace[venues.COIN_STAR_ID] = taken
    local o = OF.slots.spawn_non_sync(bhv, star_model(taken), m.pos.x,
        m.pos.y + venues.COIN_STAR_RISE, m.pos.z, function(obj) obj.oFaceAngleYaw = 0 end)
    if o ~= nil then venues.starObjects[venues.COIN_STAR_ID] = o end
end

venues.takenAtPlace = {}
function venues.place_stars()
    venues.starObjects = {}
    venues.takenAtPlace = {}
    venues.coinStarDone = false
    venues.reds = nil
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    if layout == nil or type(layout.stars) ~= "table" then return 0 end
    if venues.round_mode() ~= nil then return 0 end
    local bhv = rawget(_G, "id_bhvStaticObject")
    if bhv == nil then return 0 end
    local n = 0
    for id, row in ipairs(layout.stars) do
        local taken = venues.bonus_taken(venues.built, id)
        venues.takenAtPlace[id] = taken
        local o = OF.slots.spawn_non_sync(bhv, star_model(taken), row[1], row[2], row[3],
            function(obj) obj.oFaceAngleYaw = 0 end)
        if o ~= nil then
            venues.starObjects[id] = o
            n = n + 1
        end
    end
    return n
end

function venues.take_stars()
    for _, o in pairs(venues.starObjects) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end
    venues.starObjects = {}
end

function venues.stars_update()
    local key = venues.built
    venues.coin_star_update(gMarioStates ~= nil and gMarioStates[0] or nil)
    venues.red_star_update()
    if key == nil or next(venues.starObjects) == nil then return end
    local layout = venues.LAYOUTS[key]
    local m = gMarioStates ~= nil and gMarioStates[0] or nil

    if m ~= nil and venues.selecting == nil then venues.coin_note(key, m.numCoins) end
    starSpin = (starSpin + 0x800) % 0x10000
    local gone = nil
    for id, o in pairs(venues.starObjects) do
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then
            o.oFaceAngleYaw = starSpin
            local taken = venues.bonus_taken(key, id)
            if taken then
                OF.slots.set_model(o, star_model(true))
            end

            local mine = taken and OF.util.asks(OF.split, "on") and OF.split.on()

            if (not taken or mine) and m ~= nil and m.pos ~= nil and venues.selecting == nil then
                local dx = m.pos.x - (o.oPosX or 0)
                local dy = m.pos.y + 80 - (o.oPosY or 0)
                local dz = m.pos.z - (o.oPosZ or 0)
                if dx * dx + dy * dy + dz * dz <= venues.STAR_REACH * venues.STAR_REACH
                    and venues.bonus_touch(key, id) then
                    gone = gone or {}
                    gone[#gone + 1] = id
                end
            end

            if taken and not mine and not venues.takenAtPlace[id] then
                gone = gone or {}
                gone[#gone + 1] = id
            end
        end
    end
    for _, id in ipairs(gone or {}) do
        local o = venues.starObjects[id]
        if o ~= nil then OF.util.optional("obj_mark_for_deletion", nil, o) end
        venues.starObjects[id] = nil
    end
end

venues.touched = {}
function venues.bonus_touch(key, id)
    local tag = key .. ":" .. id
    if venues.touched[tag] then return false end
    venues.touched[tag] = true
    OF.sounds.play(SOUND_MENU_STAR_SOUND)

    if OF.util.asks(OF.split, "count_star") then
        OF.split.count_star("bonus:" .. tag)
    end

    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    venues.star_dance(m)
    if venues.bonus_taken(key, id) then return true end

    local before = venues.bonus_count(key)
    if OF.util.is_host() then
        venues.bonus_record(key, id, 0)
    else
        OF.util.publish_row(0, "ofBonusTook", tag)
    end
    local layout = venues.LAYOUTS[key]
    local all = #(layout.stars or {}) + (venues.coin_star(key) and 1 or 0)
        + (venues.red_star(key) and 1 or 0)
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("Bonus star @: @", "good", 5,
            tostring(math.min(all, before + 1)) .. "/"
                .. tostring(all), venues.star_name(key, id))
    end
    return true
end

function venues.star_name(key, id)
    if id == venues.COIN_STAR_ID and venues.coin_star(key) then
        return OF.lang.t("100 Coins")
    end
    if id == venues.RED_STAR_ID and venues.red_star(key) then
        return OF.lang.t("Red Coins")
    end
    local layout = venues.LAYOUTS[key]
    local row = layout ~= nil and type(layout.stars) == "table" and layout.stars[id] or nil
    local name = row ~= nil and row[6] or nil
    if type(name) == "string" and name ~= "" then return name end
    return OF.lang.fill("Star @", tostring(id))
end

venues.DANCE_CUT = 79
venues.dancing = false
function venues.star_dance(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local ask = OF.util.asks(OF.cheats, "is_on")
    if ask and OF.cheats.is_on("nodance")
        and not (OF.util.asks(OF.cheats, "round_keeps_the_dance")
            and OF.cheats.round_keeps_the_dance()) then
        return false
    end
    return venues.dance_start(m)
end

function venues.dance_update(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    return venues.dance_step(m)
end

function venues.has_bit(value, flag)
    if value == nil or flag == nil or flag == 0 then return false end
    return math.floor(value / flag) % 2 == 1
end

function venues.dance_start(m)
    local action = ACT_STAR_DANCE_NO_EXIT
    local now = tonumber(m.action) or 0
    local water = ACT_FLAG_SWIMMING
    local metal = ACT_FLAG_METAL_WATER
    local air = ACT_FLAG_AIR
    if (water ~= nil and venues.has_bit(now, water))
        or (metal ~= nil and venues.has_bit(now, metal)) then
        action = ACT_STAR_DANCE_WATER
    end
    if air ~= nil and venues.has_bit(now, air) then
        action = ACT_FALL_AFTER_STAR_GRAB
    end
    if action == nil then return false end

    local lv = gLevelValues
    local heal = lv ~= nil and lv.starHeal
    if heal ~= nil and heal ~= false and heal ~= 0 then
        m.healCounter = 31
        m.hurtCounter = 0
    end
    venues.dancing = true
    set_mario_action(m, action, 1)
    return true
end

function venues.dance_step(m)
    if not venues.dancing or m == nil then return false end
    local action = m.action
    local fall = ACT_FALL_AFTER_STAR_GRAB
    if action == fall then return false end
    if action ~= ACT_STAR_DANCE_NO_EXIT
        and action ~= ACT_STAR_DANCE_WATER then

        venues.dancing = false
        return false
    end
    if (tonumber(m.actionTimer) or 0) < venues.DANCE_CUT or (m.actionState or 0) ~= 0 then
        return false
    end
    venues.dancing = false
    venues.optional("enable_background_sound", nil)
    local back = ACT_FREEFALL
    if action == ACT_STAR_DANCE_WATER then
        back = ACT_WATER_IDLE or back
    elseif m.pos ~= nil and m.floorHeight ~= nil and m.pos.y <= m.floorHeight then
        back = ACT_IDLE
    end
    set_mario_action(m, back, 0)
    return true
end

function venues.bonus_host_update()
    if not OF.util.is_host() then return 0 end
    local n = 0
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        local row = gPlayerSyncTable[i]
        if np ~= nil and np.connected and row ~= nil then
            local tag = row[venues.TOOK_KEY]
            if type(tag) == "string" and tag ~= "" and tookSeen[i] ~= tag then
                tookSeen[i] = tag
                local key, id = string.match(tag, "^([%w_]+):(%d+)$")
                if key ~= nil and venues.bonus_record(key, tonumber(id), i) then n = n + 1 end
            end
        end
    end
    return n
end

venues.SELECT_AT = { 0, 7000, 0 }
venues.SELECT_WALL = { 8000, 4000 }
venues.SELECT_WALL_Z = -1500
venues.SELECT_CAMERA = 1000
venues.SELECT_STAR_Y = 248
venues.SELECT_STAR_Z = -300
venues.SELECT_FOV = 45
venues.SELECT_FADE = 16
venues.SELECT_READY = 11
venues.SELECT_AFTER = 10
venues.SELECT_ENTRY_FADE = 0x1A
venues.SELECT_STICK = 60
venues.SELECT_HUD = "starselect"
venues.SELECT_WALL_GEO = "of_star_backdrop_geo"
venues.SELECT_MUSIC = 0x0D
venues.SELECT_MUSIC_FADE = 0xBE
venues.COURSE_FIRST_BONUS = 16
venues.MENU_GLYPH = 0.45
venues.DIALOG_FONT = 0.5
venues.selectFrom = nil

venues.SELECT_AWAY_AT = { 0, 20000, 0 }
venues.SELECT_ARRIVE_FRAMES = 150
venues.selectArrive = nil
venues.selectPassing = false

function venues.select_camera_taken()
    if OF.util.asks(OF.camera, "active") and OF.camera.active() then return true end
    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then return true end
    if OF.util.asks(OF.replay, "holds_camera") and OF.replay.holds_camera() then return true end
    return false
end

venues.SELECT_WAIT_FRAMES = 30 * 30

function venues.select_wanted(key)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    if layout == nil or type(layout.stars) ~= "table" or #layout.stars == 0 then return false end
    if venues.round_mode() ~= nil then return false end
    if venues.select_camera_taken() then return false end
    return true
end

function venues.alive(o) return OF.util.alive(o) end
function venues.spawn_non_sync(bhv, model, x, y, z, setup)
    return OF.slots.spawn_non_sync(bhv, model, x, y, z, setup)
end
function venues.keep_awake(m) return OF.util.keep_awake(m) end
function venues.binding(name) return OF.util.binding(name) end
function venues.play_sound(id) return OF.sounds.play(id) end

function venues.music_after_select()
    if OF.util.asks(OF.music, "in_force") and OF.util.asks(OF.music, "refresh") then
        local room = OF.music.in_force()
        local stream = OF.util.asks(OF.music, "is_stream") and OF.music.is_stream(room)
        if type(room) == "number" and room ~= 0 and not stream then OF.music.refresh() end
    end
end

function venues.pad_more(m)
    local down, pressed = 0, 0
    if OF.util.asks(OF.input, "poll") then
        OF.input.poll(m)
        down = tonumber(OF.input.down) or 0
        for _, b in ipairs({ A_BUTTON, B_BUTTON, START_BUTTON }) do
            if OF.input.pressed(b) then pressed = pressed | b end
        end
    end
    return down, pressed
end
function venues.warp_local(a)
    return OF.util.asks(OF.net, "warp_local")
        and OF.net.warp_local(a.level, a.area, a.act, a.also, a.refusal)
end

function venues.hushed_elsewhere()
    local held = 0
    if OF.modifiers ~= nil and type(OF.modifiers.quietHeld) == "number" then
        held = held | OF.modifiers.quietHeld
    end
    if OF.util.asks(OF.celebrate, "hush_held") then
        local c = OF.celebrate.hush_held()
        if type(c) == "number" then held = held | c end
    end
    return held
end

function venues.select_hud(down)
    for _, name in ipairs({ "HUD_DISPLAY_FLAG_LIVES", "HUD_DISPLAY_FLAG_COIN_COUNT",
        "HUD_DISPLAY_FLAG_STAR_COUNT", "HUD_DISPLAY_FLAG_CAMERA_AND_POWER",
        "HUD_DISPLAY_FLAG_TIMER" }) do
        local flag = rawget(_G, name)
        if flag ~= nil then OF.util.hud_hide(flag, venues.SELECT_HUD, down) end
    end
end

venues.PICKING_KEY = "ofPicking"
function venues.picking(localIndex)
    if localIndex == nil then return false end
    if localIndex == 0 then return venues.selecting ~= nil end
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[localIndex] or nil
    return row ~= nil and row.ofPicking == true
end

function venues.select_publish(on)
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[0] or nil
    if row == nil or (row.ofPicking == true) == (on == true) then return false end
    OF.util.publish_row(0, "ofPicking", on == true)
    return true
end

local function add_flag(value, flag)
    if flag == nil or flag == 0 then return value end
    value = value or 0
    if math.floor(value / flag) % 2 == 1 then return value end
    return value + flag
end

function venues.scene()
    local s = venues.selecting
    return s ~= nil and s.at or venues.SELECT_AT
end

function venues.select_keep_pieces(s)
    if s == nil then return 0 end
    local bhv = rawget(_G, "id_bhvStaticObject")
    if bhv == nil then return 0 end
    local back = 0
    local function gone(o) return o == nil or not venues.alive(o) or o.activeFlags == 0 end
    if gone(s.wall) then
        local wall = model_of(venues.SELECT_WALL_GEO)
        if wall ~= nil then
            local at = s.at
            s.wall = venues.spawn_non_sync(bhv, wall, at[1], at[2], at[3] + venues.SELECT_WALL_Z,
                function(o) o.oFaceAngleYaw = 0 end)
            if s.wall ~= nil then back = back + 1 end
        end
    end
    if s.phase == "pick" then
        for i = 1, s.n do
            if gone(s.stars[i]) then
                local x, y, z = venues.select_star_at(i, s.n)
                local model = venues.bonus_taken(s.key, i) and E_MODEL_STAR or E_MODEL_TRANSPARENT_STAR
                s.stars[i] = venues.spawn_non_sync(bhv, model or E_MODEL_STAR, x, y, z,
                    function(o) o.oFaceAngleYaw = 0 end)
                if s.stars[i] ~= nil then back = back + 1 end
            end
        end
    end
    return back
end

function venues.select_star_at(i, n)
    local at = venues.scene()
    return at[1] + 75 - 75 * n + 152 * (i - 1), at[2] + venues.SELECT_STAR_Y,
        at[3] + venues.SELECT_STAR_Z
end

function venues.select_camera_z()
    local fov = tonumber(venues.optional("get_current_fov", venues.SELECT_FOV)) or venues.SELECT_FOV
    if fov <= 1 or fov >= 179 then fov = venues.SELECT_FOV end
    local plane = venues.SELECT_CAMERA - venues.SELECT_STAR_Z
    local k = math.tan(math.rad(venues.SELECT_FOV / 2)) / math.tan(math.rad(fov / 2))
    return plane * k + venues.SELECT_STAR_Z
end

local function copy_vec(v)
    if v == nil then return nil end
    return { v.x, v.y, v.z }
end

local function put_vec(v, t)
    if v == nil or t == nil then return end
    v.x, v.y, v.z = t[1], t[2], t[3]
end

local function clear_level_queue()
    for _ = 1, 8 do
        local head = venues.optional("get_current_background_music", nil)

        if type(head) ~= "number" or head < 0 or head == 65535 then return end
        venues.optional("stop_background_music", nil, head)
        local after = venues.optional("get_current_background_music", nil)
        if after == head then return end
    end
end

function venues.select_open(key, away)
    if venues.selecting ~= nil or not venues.select_wanted(key) then return false end
    local layout = venues.LAYOUTS[key]
    local n = #layout.stars
    local s = { key = key, n = n, cursor = n, timer = 0, faded = 0, phase = "in", out = 0,
                stars = {}, sizes = {}, hold = 0, holdTimer = 0, music = true,
                away = away, at = away ~= nil and venues.SELECT_AWAY_AT or venues.SELECT_AT }

    for i = 1, n do
        if not venues.bonus_taken(key, i) then s.cursor = i break end
    end
    local bhv = rawget(_G, "id_bhvStaticObject")
    if bhv == nil then return false end
    local wall = model_of(venues.SELECT_WALL_GEO)
    if wall ~= nil then
        local at = s.at
        s.wall = venues.spawn_non_sync(bhv, wall, at[1], at[2], at[3] + venues.SELECT_WALL_Z,
            function(o) o.oFaceAngleYaw = 0 end)
    end
    if gLakituState ~= nil then
        s.cam = { pos = copy_vec(gLakituState.pos), curPos = copy_vec(gLakituState.curPos),
                  goalPos = copy_vec(gLakituState.goalPos), focus = copy_vec(gLakituState.focus),
                  curFocus = copy_vec(gLakituState.curFocus),
                  goalFocus = copy_vec(gLakituState.goalFocus), yaw = gLakituState.yaw }
    end
    venues.selecting = s
    venues.settle_mood()
    venues.select_hud(true)

    venues.select_hush(s)
    venues.select_publish(true)

    clear_level_queue()
    venues.optional("play_transition", nil, WARP_TRANSITION_FADE_FROM_COLOR,
        venues.SELECT_FADE, 255, 255, 255)
    venues.select_camera()
    venues.optional("skip_camera_interpolation", nil)
    return true
end

function venues.select_begin()
    local s = venues.selecting
    if s == nil or s.phase ~= "in" then return false end
    local bhv = rawget(_G, "id_bhvStaticObject")
    for i = 1, s.n do
        local x, y, z = venues.select_star_at(i, s.n)

        local model = venues.bonus_taken(s.key, i) and E_MODEL_STAR or E_MODEL_TRANSPARENT_STAR
        if bhv ~= nil then
            s.stars[i] = venues.spawn_non_sync(bhv, model or E_MODEL_STAR, x, y, z,
                function(o) o.oFaceAngleYaw = 0 end)
        end
        s.sizes[i] = 1.0
    end
    s.phase, s.timer = "pick", 0
    clear_level_queue()
    venues.optional("play_music", nil, SEQ_PLAYER_LEVEL,
        rawget(_G, "SEQ_MENU_STAR_SELECT") or venues.SELECT_MUSIC, 0)
    return true
end

function venues.select_camera()
    local s = gLakituState
    if s == nil or s.pos == nil then return false end
    local at = venues.scene()
    local pos = { at[1], at[2], at[3] + venues.select_camera_z() }
    put_vec(s.pos, pos)
    put_vec(s.curPos, pos)
    put_vec(s.goalPos, pos)
    put_vec(s.focus, at)
    put_vec(s.curFocus, at)
    put_vec(s.goalFocus, at)
    s.posHSpeed, s.posVSpeed, s.focHSpeed, s.focVSpeed = 0, 0, 0, 0

    s.yaw = 0
    return true
end

function venues.holds_camera()
    return venues.selecting ~= nil
end

function venues.select_hush_mask()
    local count = tonumber(rawget(_G, "SOUND_BANK_COUNT")) or 13
    local mask = (1 << count) - 1
    local menu = rawget(_G, "SOUND_BANK_MENU")
    if type(menu) == "number" then mask = mask & ~(1 << menu) end
    return mask
end

function venues.select_hush(sel)
    if sel == nil or venues.binding("sound_banks_disable") == nil then return false end
    local mask = venues.select_hush_mask()

    venues.optional("sound_banks_disable", nil, 0, mask)
    if sel.hush == nil then
        sel.hush = mask
        venues.optional("stop_sounds_in_continuous_banks", nil)
    end
    return true
end

function venues.select_unhush(sel)
    if sel == nil or sel.hush == nil then return false end
    venues.optional("sound_banks_enable", nil, 0, sel.hush & ~venues.hushed_elsewhere())
    sel.hush = nil
    return true
end

local PICK_HIDDEN = GRAPH_RENDER_INVISIBLE or 0x10

function venues.picking_before(m)
    if m == nil or not venues.picking(m.playerIndex) then return false end
    m.visibleToObjects = false
    if m.playerIndex == 0 then venues.keep_awake(m) end
    return true
end

function venues.picking_hide(m)
    if m == nil or m.playerIndex == 0 or not venues.picking(m.playerIndex) then return false end
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil or obj.header.gfx.node == nil then
        return false
    end
    local node = obj.header.gfx.node
    node.flags = add_flag(node.flags or 0, PICK_HIDDEN)
    return true
end

local function player_of_object(o)
    if o == nil or gMarioStates == nil then return nil end
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local other = gMarioStates[i]
        if other ~= nil and other.marioObj ~= nil and other.marioObj == o then return i end
    end
    return nil
end

function venues.picking_interact(m, o, interactType)
    if m == nil or interactType ~= INTERACT_PLAYER then return nil end
    if venues.picking(m.playerIndex) then return false end
    local other = player_of_object(o)
    if other ~= nil and venues.picking(other) then return false end
    return nil
end

function venues.select_music_back(sel, levelGone)
    if sel == nil or not sel.music then return false end
    local menu = rawget(_G, "SEQ_MENU_STAR_SELECT") or venues.SELECT_MUSIC
    local head = venues.optional("get_current_background_music", nil)
    if type(head) == "number" and head % 256 == menu % 256 then
        venues.optional("stop_background_music", nil, menu)
    end
    if levelGone then return true end
    if venues.levelSeq ~= nil and venues.levelSeq ~= 0 then
        venues.optional("play_music", nil, SEQ_PLAYER_LEVEL, venues.levelSeq, 0)
    end
    venues.music_after_select()
    return true
end

function venues.awake_again(m)
    if m == nil then return false end
    venues.keep_awake(m)
    if m.action == ACT_IDLE then m.actionState, m.actionTimer = 0, 0 end
    return true
end

function venues.select_close(fadeIn, levelGone)
    local s = venues.selecting
    if s == nil then return false end
    venues.selecting = nil
    venues.awake_again(gMarioStates ~= nil and gMarioStates[0] or nil)
    venues.settle_mood()
    for _, o in pairs(s.stars) do
        if o ~= nil and venues.alive(o) and o.activeFlags ~= 0 then
            venues.optional("obj_mark_for_deletion", nil, o)
        end
    end
    if s.wall ~= nil and venues.alive(s.wall) and s.wall.activeFlags ~= 0 then
        venues.optional("obj_mark_for_deletion", nil, s.wall)
    end
    local c = gLakituState
    if c ~= nil and s.cam ~= nil then
        put_vec(c.pos, s.cam.pos)
        put_vec(c.curPos, s.cam.curPos)
        put_vec(c.goalPos, s.cam.goalPos)
        put_vec(c.focus, s.cam.focus)
        put_vec(c.curFocus, s.cam.curFocus)
        put_vec(c.goalFocus, s.cam.goalFocus)
        if s.cam.yaw ~= nil then c.yaw = s.cam.yaw end
        c.posHSpeed, c.posVSpeed, c.focHSpeed, c.focVSpeed = 0.3, 0.3, 0.8, 0.3
    end
    venues.optional("skip_camera_interpolation", nil)
    venues.select_hud(false)
    venues.select_music_back(s, levelGone)

    venues.select_unhush(s)
    venues.select_publish(false)
    if fadeIn then
        venues.optional("play_transition", nil, WARP_TRANSITION_FADE_FROM_COLOR,
            venues.SELECT_ENTRY_FADE, 255, 255, 255)
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        if m ~= nil and CHAR_SOUND_LETS_A_GO ~= nil then
            venues.optional("play_character_sound", nil, m, CHAR_SOUND_LETS_A_GO)
        end
    end
    return true
end

function venues.select_input(m)
    local s = venues.selecting
    if s == nil or m == nil or m.playerIndex ~= 0 or m.controller == nil then return false end
    local c = m.controller
    local stick = tonumber(c.rawStickX) or tonumber(c.stickX) or 0
    local down = tonumber(c.buttonDown) or 0
    local pressed = tonumber(c.buttonPressed) or 0

    local moreDown, morePressed = venues.pad_more(m)
    down, pressed = down | moreDown, pressed | morePressed
    if s.phase == "pick" then
        local index = 0
        if stick > venues.SELECT_STICK or (R_JPAD ~= nil and down & R_JPAD ~= 0) then
            index = index + 2
        end
        if stick < -venues.SELECT_STICK or (L_JPAD ~= nil and down & L_JPAD ~= 0) then
            index = index + 1
        end
        local fresh = (index ~ s.hold) & index
        if fresh == 2 and s.cursor < s.n then
            s.cursor = s.cursor + 1
            venues.play_sound(SOUND_MENU_CHANGE_SELECT)
        elseif fresh == 1 and s.cursor > 1 then
            s.cursor = s.cursor - 1
            venues.play_sound(SOUND_MENU_CHANGE_SELECT)
        end
        if s.holdTimer == 10 then
            s.holdTimer, s.hold = 8, 0
        else
            s.holdTimer, s.hold = s.holdTimer + 1, index
        end
        if index & 3 == 0 then s.holdTimer = 0 end
        if s.timer >= venues.SELECT_READY
            and pressed & (A_BUTTON | B_BUTTON | START_BUTTON) ~= 0 then
            venues.select_choose()
        end
    end
    c.buttonDown, c.buttonPressed = 0, 0
    c.stickX, c.stickY, c.stickMag = 0, 0, 0
    return true
end

function venues.select_choose()
    local s = venues.selecting
    if s == nil or s.phase ~= "pick" then return false end
    s.phase, s.out = "out", 0

    venues.play_sound(SOUND_MENU_STAR_SOUND)
    if s.music then venues.optional("fadeout_level_music", nil, venues.SELECT_MUSIC_FADE) end
    venues.optional("play_transition", nil, WARP_TRANSITION_FADE_INTO_COLOR,
        venues.SELECT_FADE, 255, 255, 255)
    return true
end

function venues.select_step()
    local s = venues.selecting
    if s == nil then return false end
    if not venues.select_wanted(s.key) or (s.away == nil and venues.built ~= s.key) then
        venues.select_close(false)
        if s.away ~= nil then venues.select_unwhite() end
        return false
    end
    venues.select_hush(s)
    if s.phase ~= "out" then venues.select_keep_pieces(s) end
    if s.phase == "in" then
        s.faded = s.faded + 1

        if s.faded >= venues.SELECT_FADE then venues.select_begin() end
        venues.select_camera()
        return true
    end
    s.timer = s.timer + 1
    if s.phase == "pick" then
        for i, o in pairs(s.stars) do
            if o ~= nil and venues.alive(o) and o.activeFlags ~= 0 then
                if i == s.cursor then
                    s.sizes[i] = math.min(1.3, s.sizes[i] + 0.1)
                    o.oFaceAngleYaw = (o.oFaceAngleYaw + 0x800) % 0x10000
                else
                    s.sizes[i] = math.max(1.0, s.sizes[i] - 0.1)
                    o.oFaceAngleYaw = 0
                end
                venues.optional("obj_scale", nil, o, s.sizes[i])
            end
        end
    end
    venues.select_camera()
    if s.phase == "out" then
        s.out = s.out + 1
        if s.out >= venues.SELECT_FADE + venues.SELECT_AFTER then
            if s.away ~= nil then venues.select_leave(s) else venues.select_close(true) end
        end
    end
    return true
end

function venues.select_leave(s)
    local a = s ~= nil and s.away or nil
    if a == nil or venues.selecting ~= s then return false end
    venues.selectPassing = true
    local ok = venues.warp_local(a)
    venues.selectPassing = false
    if not ok then
        venues.select_close(false)
        venues.select_unwhite()
        return false
    end
    for _, o in pairs(s.stars) do
        if o ~= nil and venues.alive(o) and o.activeFlags ~= 0 then
            venues.optional("obj_mark_for_deletion", nil, o)
        end
    end
    if s.wall ~= nil and venues.alive(s.wall) and s.wall.activeFlags ~= 0 then
        venues.optional("obj_mark_for_deletion", nil, s.wall)
    end
    s.stars, s.wall, s.cam = {}, nil, nil
    s.arriveFrames = 0
    venues.selecting = nil
    venues.settle_mood()
    venues.selectArrive = s
    return true
end

function venues.select_unwhite()
    venues.optional("play_transition", nil, WARP_TRANSITION_FADE_FROM_COLOR,
        venues.SELECT_FADE, 255, 255, 255)
    return true
end

function venues.select_arrived(s, landed)
    if s == nil then return false end
    if venues.selectArrive == s then venues.selectArrive = nil end
    venues.awake_again(gMarioStates ~= nil and gMarioStates[0] or nil)
    venues.select_hud(false)
    venues.select_music_back(s, true)
    venues.select_unhush(s)
    venues.select_publish(false)
    venues.optional("play_transition", nil, WARP_TRANSITION_FADE_FROM_COLOR,
        venues.SELECT_ENTRY_FADE, 255, 255, 255)
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if landed and m ~= nil and CHAR_SOUND_LETS_A_GO ~= nil then
        venues.optional("play_character_sound", nil, m, CHAR_SOUND_LETS_A_GO)
    end
    return true
end

function venues.select_before_warp(level, area, act, alsoLevels, refusal)
    if venues.selectPassing then return false end
    local up = venues.selecting
    if up ~= nil then

        return up.away ~= nil and up.away.level == level
    end
    local key = venues.at(level, area or 1)
    if key == nil then return false end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil or np.currLevelNum == level then return false end
    if OF.util.asks(OF.roundact, "private") and OF.roundact.private(act) then return false end
    local gm = OF.gamemodes
    if OF.util.asks(gm, "holding") and gm.holding() ~= nil then return false end
    if OF.util.asks(gm, "state") and gm.state() ~= gm.OFF then return false end
    local away = { level = level, area = area or 1, act = act, also = alsoLevels,
                   refusal = refusal, key = key }
    return venues.select_open(key, away)
end

venues.TRAIL_EVERY = 10
venues.TRAIL_MOVE = 40
venues.TRAIL_CHUNK = 48
venues.TRAIL_MAX_CHUNKS = 20
venues.trail = { key = nil, pending = {}, chunks = 0, tick = 0, last = nil }

function venues.trail_name(key, n)
    return "trail_" .. tostring(key) .. (n ~= nil and ("_" .. tostring(n)) or "")
end

function venues.trail_flush()
    local t = venues.trail
    if t.key == nil or #t.pending == 0 then return false end
    if t.chunks >= venues.TRAIL_MAX_CHUNKS then
        t.pending = {}
        return false
    end
    t.chunks = t.chunks + 1
    OF.util.store(venues.trail_name(t.key, t.chunks), table.concat(t.pending, ";"))
    OF.util.store(venues.trail_name(t.key), tostring(t.chunks))
    t.pending = {}
    return true
end

function venues.trail_begin(key)
    venues.trail_flush()
    local t = venues.trail
    local old = math.floor(tonumber(OF.util.stored(venues.trail_name(key), "0")) or 0)
    for n = 1, math.min(old, venues.TRAIL_MAX_CHUNKS) do
        OF.util.clear(venues.trail_name(key, n))
    end
    OF.util.store(venues.trail_name(key), "0")
    OF.util.store("trail_last", key)
    t.key, t.pending, t.chunks, t.tick, t.last = key, {}, 0, 0, nil
    return true
end

function venues.trail_step(key, m)
    if key == nil or m == nil or m.pos == nil then return false end
    if venues.round_mode() ~= nil then return false end
    local t = venues.trail
    if t.key ~= key then venues.trail_begin(key) end
    if venues.selecting ~= nil then return false end
    t.tick = t.tick + 1
    if t.tick < venues.TRAIL_EVERY then return false end
    t.tick = 0
    local x = math.floor(m.pos.x + 0.5)
    local y = math.floor(m.pos.y + 0.5)
    local z = math.floor(m.pos.z + 0.5)
    local last = t.last
    if last ~= nil and math.abs(x - last[1]) + math.abs(y - last[2]) + math.abs(z - last[3])
        < venues.TRAIL_MOVE then
        return false
    end
    t.last = { x, y, z }
    t.pending[#t.pending + 1] = x .. "," .. y .. "," .. z
    if #t.pending >= venues.TRAIL_CHUNK then venues.trail_flush() end
    return true
end

function venues.menu_text(text, x, y)
    local glyph, advance = venues.MENU_GLYPH, venues.DIALOG_FONT

    local top = y - 3 * 2 * glyph
    local at = x
    for ch in string.gmatch(text, utf8 ~= nil and utf8.charpattern or ".") do
        if ch ~= " " then djui_hud_print_text(ch, at, top, glyph) end
        at = at + djui_hud_measure_text(ch) * advance
    end
    return at - x
end

function venues.menu_width(text)
    return djui_hud_measure_text(text) * venues.DIALOG_FONT
end

venues.EMBLEM_R = 32
function venues.emblem_rows()
    local rows = {}
    local r = venues.EMBLEM_R
    for row = 0, 2 * r - 1 do
        local dy = row + 0.5 - r
        local half = math.ceil(math.sqrt(math.max(0, r * r - dy * dy)))
        if half > 0 then rows[#rows + 1] = { row = row, half = half } end
    end
    return rows
end

function venues.draw_emblem(cx, cy)
    local upper = venues.optional("get_texture_info", nil, "texture_menu_course_upper")
    local lower = venues.optional("get_texture_info", nil, "texture_menu_course_lower")
    if upper == nil or lower == nil then return false end
    if type(djui_hud_render_texture_tile) ~= "function" then return false end
    venues.emblemRows = venues.emblemRows or venues.emblem_rows()
    local r = venues.EMBLEM_R
    for _, line in ipairs(venues.emblemRows) do
        local tex, ty = upper, line.row
        if line.row >= r then tex, ty = lower, line.row - r end
        local w = 2 * line.half
        djui_hud_render_texture_tile(tex, cx - line.half, cy - r + line.row, 1 / w, 1,
            r - line.half, ty, w, 1)
    end
    return true
end

function venues.select_paint(screen)
    djui_hud_set_resolution(RESOLUTION_N64)
    local ox = (djui_hud_get_screen_width() - 320) / 2

    local best = tonumber(screen.best) or 0
    if best > 0 then
        djui_hud_set_font(FONT_HUD)
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text("$", ox + 155, 106, 1)
        djui_hud_print_text("@", ox + 171, 106, 1)
        djui_hud_print_text(tostring(best), ox + 187, 106, 1)
        djui_hud_set_font(FONT_NORMAL)
        djui_hud_set_color(0, 0, 0, 255)
        djui_hud_print_text("MY SCORE", ox + 102, 240 - 118 - 16, venues.DIALOG_FONT)
    end

    djui_hud_set_font(FONT_NORMAL)
    djui_hud_set_color(0, 0, 0, 255)
    local world = string.upper(tostring(screen.world or ""))
    local w = djui_hud_measure_text(world) * venues.DIALOG_FONT
    djui_hud_print_text(world, ox + 160 - w / 2, 240 - 33 - 16, venues.DIALOG_FONT)

    djui_hud_set_color(255, 255, 255, 255)
    venues.draw_emblem(ox + 158, 159)
    djui_hud_set_font(FONT_HUD)
    local number = tostring(screen.number or 0)
    djui_hud_print_text(number, ox + (#number < 2 and 152 or 143), 158, 1)

    if screen.phase ~= "in" then
        djui_hud_set_font(FONT_NORMAL)
        djui_hud_set_color(0, 0, 0, 255)
        for i = 1, screen.n do
            venues.menu_text(tostring(i), ox + 139 - screen.n * 17 + i * 34, 38)
        end
        local name = string.upper(tostring(screen.act or ""))
        venues.menu_text(name, ox + 163 - venues.menu_width(name) / 2, 81)
    end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    return true
end

function venues.course_number(layouts, key)
    local layout = key ~= nil and layouts[key] or nil
    if layout == nil then return 0 end
    if type(layout.course) == "number" and layout.course >= venues.COURSE_FIRST_BONUS then
        return math.floor(layout.course)
    end
    local top = venues.COURSE_FIRST_BONUS - 1
    local loose = {}
    for k, other in pairs(layouts) do
        if type(other.course) == "number" then
            top = math.max(top, math.floor(other.course))
        elseif type(other.stars) == "table" and #other.stars > 0 then
            loose[#loose + 1] = k
        end
    end
    table.sort(loose)
    for i, k in ipairs(loose) do
        if k == key then return top + i end
    end
    return 0
end

function venues.optional(name, fallback, ...)
    return OF.util.optional(name, fallback, ...)
end

venues.coinBest = {}
function venues.coin_best(key)
    if key == nil then return 0 end
    local known = venues.coinBest[key]
    if known == nil then
        known = tonumber(OF.util.stored("coins_" .. key, "0")) or 0
        venues.coinBest[key] = known
    end
    return known
end

function venues.coin_note(key, coins)
    coins = math.floor(tonumber(coins) or 0)
    if key == nil or coins <= venues.coin_best(key) then return false end
    venues.coinBest[key] = coins
    OF.util.store("coins_" .. key, tostring(coins))
    return true
end

function venues.select_render()
    local s = venues.selecting
    if s == nil or OF.util.menu_has_screen() then return false end
    local place = venues.place_of(s.key)
    return venues.select_paint({ best = venues.coin_best(s.key),
        world = place ~= nil and place.name or s.key, number = venues.select_number(s.key),
        phase = s.phase, n = s.n, act = venues.star_name(s.key, s.cursor) })
end

function venues.select_number(key)
    return venues.course_number(venues.LAYOUTS, key)
end

venues.selecting = nil
venues.HUD_TINT = { 150, 215, 255 }
venues.HUD_STARS_X = 78
venues.HUD_ROW = 15
venues.HUD_GAP = 8

function venues.bonus_worlds()
    local n = 0
    for _, layout in pairs(venues.LAYOUTS) do
        if type(layout.stars) == "table" and #layout.stars > 0 then n = n + 1 end
    end
    return n
end

function venues.bonus_total()
    local n = 0
    for key, layout in pairs(venues.LAYOUTS) do
        if type(layout.stars) == "table" and #layout.stars > 0 then
            n = n + venues.bonus_count(key)
        end
    end
    return n
end

function venues.hud_counter()
    if venues.bonus_worlds() == 0 then return nil end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then return nil end
    if venues.selecting ~= nil then return nil end

    if OF.util.game_hud_hidden() then return nil end
    if OF.util.asks(OF.split, "on") and OF.split.on() then
        if not OF.util.asks(OF.split, "tally_width") or OF.split.tally_width() <= 0 then
            return nil
        end
        return "split", OF.split.bonus_got()
    end
    local flags = OF.util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" or not OF.util.has_flag(flags, HUD_DISPLAY_FLAG_STAR_COUNT) then
        return nil
    end
    return "game", venues.bonus_total()
end

function venues.travel_suffix(level, area)
    local key = venues.at(level, area)
    local layout = key ~= nil and venues.LAYOUTS[key] or nil
    if layout == nil or type(layout.stars) ~= "table" or #layout.stars == 0 then return "" end
    return "   (" .. OF.lang.fill("@ bonus stars", tostring(venues.bonus_count(key)) .. "/"
        .. tostring(#layout.stars)) .. ")"
end

function venues.hud_render()
    local beside, count = venues.hud_counter()
    if beside == nil then return false end
    if beside == "split" then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
        local glyph = OF.util.asks(OF.speedrun, "star_glyph") and OF.speedrun.star_glyph() or nil
        local gold = OF.util.gold()
        OF.util.corner_counter(glyph, tostring(count), gold.r, gold.g, gold.b,
            OF.split.tally_width(), 0.75, venues.HUD_TINT)
        return true
    end
    return venues.counter_paint(count)
end

function venues.counter_paint(count)
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_HUD)
    local text = tostring(count)
    local cross = count < 100 and 14 or 0
    local width = 16 + cross + 12 * #text
    local x = djui_hud_get_screen_width() - venues.HUD_STARS_X - venues.HUD_GAP - width
    local y = venues.HUD_ROW

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text("*", x, y, 1)
    if cross > 0 then djui_hud_print_text("@", x + 16, y, 1) end
    djui_hud_print_text(text, x + 16 + cross, y, 1)
    djui_hud_set_resolution(RESOLUTION_DJUI)
    return true
end

venues.WORLD_RING = 160
function venues.is_race(layout)
    for _, row in ipairs(type(layout) == "table" and layout.markers or {}) do
        if type(row) == "table" and row[1] == 1 then return true end
    end
    return false
end

function venues.arrival_spot(key, globalIndex)
    local layout = venues.LAYOUTS[key]
    if layout == nil then return nil end
    return venues.arrival_of(layout, venues.is_race(layout), globalIndex)
end

function venues.arrival_of(layout, race, globalIndex)
    local w = layout.world
    local spawns = type(layout.spawns) == "table" and layout.spawns or {}
    if race and #spawns > 0 then w = nil end
    if type(w) == "table" and type(w[1]) == "number" and type(w[3]) == "number" then
        local x0, y0, z0, yaw = w[1], tonumber(w[2]) or 0, w[3], tonumber(w[4]) or 0
        local i = math.floor(tonumber(globalIndex) or 0)
        if i <= 0 then return { x = x0, y = y0, z = z0, yaw = yaw } end
        local a = (i - 1) * (2 * math.pi / 15)
        local x = x0 + math.sin(a) * venues.WORLD_RING
        local z = z0 + math.cos(a) * venues.WORLD_RING
        local floor = venues.optional("find_floor_height", nil, x, y0 + 100, z)
        if type(floor) == "number" and math.abs(floor - y0) <= 60 then
            return { x = x, y = floor, z = z, yaw = yaw }
        end
        return { x = x0, y = y0, z = z0, yaw = yaw }
    end
    if #spawns == 0 then return nil end
    local row = spawns[(math.floor(tonumber(globalIndex) or 0) % #spawns) + 1]
    return { x = row[1], y = row[2], z = row[3], yaw = row[4] }
end

local function round_owns_placing()
    if OF.util.asks(OF.lockdown, "menu_stands_down") then
        return OF.lockdown.menu_stands_down(0) == true
    end
    return false
end

venues.HOLD_MOST = 150
venues.held = nil

function venues.floor_under(x, y, z)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return false end
    local f = OF.util.optional("find_floor_height", nil, x, y + 100, z)
    local lowest = gLevelValues ~= nil and tonumber(gLevelValues.floorLowerLimit) or -11000
    return type(f) == "number" and f > lowest + 1 and f >= y - 400
end

function venues.hold_start()
    venues.held = { frames = 0 }
end

function venues.hold_step()
    local held = venues.held
    if held == nil then return end
    held.frames = held.frames + 1
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil or venues.built == nil
        or venues.floor_under(m.pos.x, m.pos.y, m.pos.z)
        or held.frames > venues.HOLD_MOST then
        venues.held = nil
    end
end

function venues.holding()
    return venues.held ~= nil
end

local function still(m)
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    local c = m.controller
    if c ~= nil then
        c.stickX, c.stickY, c.stickMag = 0, 0, 0
        c.rawStickX, c.rawStickY = 0, 0
        c.buttonDown, c.buttonPressed = 0, 0
    end
end

function venues.hold_before(m)
    local held = venues.held
    if held == nil or m == nil or m.playerIndex ~= 0 or m.pos == nil then return end
    held.x, held.y, held.z = m.pos.x, m.pos.y, m.pos.z
    still(m)
end

function venues.hold_after(m)
    local held = venues.held
    if held == nil or m == nil or m.playerIndex ~= 0 or m.pos == nil or held.x == nil then
        return
    end
    m.pos.x, m.pos.y, m.pos.z = held.x, held.y, held.z
    still(m)
    local o = m.marioObj
    if o ~= nil then o.oPosX, o.oPosY, o.oPosZ = held.x, held.y, held.z end
end

function venues.arrive()
    if venues.arrived or venues.built == nil then return false end
    venues.arrived = true
    if round_owns_placing() then return false end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil then return false end
    local spot = venues.arrival_spot(venues.built, np.globalIndex)
    if spot == nil or not OF.util.asks(OF.doorways, "put_at") then return false end
    if OF.doorways.put_at(m, spot.x, spot.y, spot.z) ~= true then return false end
    if m.faceAngle ~= nil then m.faceAngle.y = angle(spot.yaw) end
    if OF.util.asks(OF.util, "camera_behind_soon") then OF.util.camera_behind_soon() end
    return true
end

function venues.survey_for(level, area)
    local key = venues.at(level, area)
    if key == nil then return nil end
    local out = {}
    for name, rows in pairs(venues.LAYOUTS[key].survey or {}) do
        local list = {}
        for i, row in ipairs(rows) do
            list[i] = { x = row[1], y = row[2], z = row[3], yaw = angle(row[4]) }
        end
        if rows.single then out[name] = list[1] else out[name] = list end
    end
    return out
end

venues.worn = nil

local function constant(name)
    if type(name) ~= "string" then return nil end
    local value = rawget(_G, name)
    if type(value) ~= "number" then return nil end
    return value
end

function venues.look()
    if venues.built == nil then return nil end
    local layout = venues.LAYOUTS[venues.built]
    return layout ~= nil and layout.look or nil
end

function venues.mood_held()
    if venues.selecting ~= nil then return true end
    if not venues.selectArmed or venues.round_mode() ~= nil then return false end
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    return layout ~= nil and type(layout.stars) == "table" and #layout.stars > 0
end

venues.moodHeldWas = nil
function venues.settle_mood()
    local held = venues.mood_held()
    if held == venues.moodHeldWas then return false end
    venues.moodHeldWas = held
    if OF.util.asks(OF.modifiers, "wear_place_light") then
        OF.modifiers.wear_place_light(venues.light())
    end
    if OF.util.asks(OF.modifiers, "wear_place_visuals") then
        OF.modifiers.wear_place_visuals(venues.visuals())
    end
    if OF.util.asks(OF.modifiers, "wear_place_vision") then
        OF.modifiers.wear_place_vision(venues.vision())
    end

    if OF.util.asks(OF.modifiers, "watch_the_round") then
        OF.modifiers.watch_the_round()
    end
    return true
end

function venues.sky()
    local look = venues.look()
    return look ~= nil and constant(look.sky) or nil
end

function venues.light()
    if venues.mood_held() then return nil end
    local look = venues.look()

    local sun = nil
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    if venues.sunlit(layout) then
        local pal = venues.bake_palette(look)
        if pal ~= nil then sun = { pal.sun[1], pal.sun[2], pal.sun[3] } end
    end
    if look == nil or (look.light == nil and look.dark == nil and sun == nil) then return nil end
    local dir = nil
    if type(look.light) == "table" and #look.light == 3 then
        dir = { look.light[1], look.light[2], look.light[3] }
    end
    return { dir = dir, dark = tonumber(look.dark), sun = sun }
end

venues.MOOD_ROWS = { { "weather", "snow" }, { "hour", "sun" }, { "fog", "fog" },
                     { "darkness", "dark" }, { "shade", "shading" }, { "colour", "tint" } }

venues.OBJECT_RAINS = { ["a rain of Bob-ombs"] = true, ["a rain of coins"] = true,
                        ["a rain of 1-Ups"] = true }

function venues.visuals()
    if venues.mood_held() then return nil end
    local look = venues.look()
    if look == nil then return nil end
    local out, named = {}, {}

    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    local baked = layout ~= nil and layout.darkBaked == true
    if baked then named.dark = true end
    for _, pair in ipairs(venues.MOOD_ROWS) do
        local stop = look[pair[1]]
        if type(stop) == "string" and stop ~= "" and not venues.OBJECT_RAINS[stop]
            and not (baked and pair[2] == "dark") then
            out[#out + 1] = { pair[2], stop }
            named[pair[2]] = true
        end
    end
    for _, pair in ipairs(type(look.visuals) == "table" and look.visuals or {}) do
        if type(pair) == "table" and not named[pair[1]] and not venues.OBJECT_RAINS[pair[2]] then
            out[#out + 1] = pair
            named[pair[1]] = true
        end
    end

    if baked and venues.lightfog_v2(layout) then
        for i = #out, 1, -1 do
            if out[i][1] == "shading" then table.remove(out, i) end
        end
        named.shading = true
    end
    if baked and not named.shading then
        out[#out + 1] = { "shading", venues.DARK_SHADING }
    end
    if #out == 0 then return nil end
    return out
end

venues.DARK_SHADING = "moonlight"
venues.SKY_TINTS = {
    night = { 60, 74, 125 },
    dusk = { 235, 140, 125 },
    purple = { 150, 100, 175 },
}

function venues.sky_tint_of(look, hour)
    if type(look) ~= "table" then return nil end
    local t = look.skyTint
    if type(t) == "table" and type(t[1]) == "number" then
        return { t[1], t[2] or t[1], t[3] or t[1] }
    end
    local words = { tostring(hour or ""), tostring(look.darkness or "") }
    local mood = look.mood
    if type(mood) == "table" then
        for _, v in pairs(mood) do words[#words + 1] = tostring(v) end
    elseif mood ~= nil then
        words[#words + 1] = tostring(mood)
    end
    local text = string.lower(table.concat(words, " "))
    local pick = nil
    if string.find(text, "purple", 1, true) then
        pick = venues.SKY_TINTS.purple
    elseif string.find(text, "dusk", 1, true) or string.find(text, "sunset", 1, true)
        or string.find(text, "evening", 1, true) or string.find(text, "twilight", 1, true) then
        pick = venues.SKY_TINTS.dusk
    elseif string.find(text, "night", 1, true) or string.find(text, "pitch", 1, true)
        or string.find(text, "cold blue", 1, true) then
        pick = venues.SKY_TINTS.night
    end
    if pick == nil then return nil end
    return { pick[1], pick[2], pick[3] }
end

function venues.sky_mix(amount, r, g, b, dim, tint, bright)
    amount = math.max(0, math.min(1, tonumber(amount) or 0))
    dim = tonumber(dim) or 255
    bright = tonumber(bright) or 1
    local air = { r or 255, g or 255, b or 255 }
    local out = {}
    for c = 1, 3 do
        local v = (255 - (255 - air[c]) * amount) * dim / 255
        if tint ~= nil then v = v * (tint[c] or 255) / 255 end
        out[c] = math.floor(math.max(0, math.min(255, v * bright)))
    end
    return out[1], out[2], out[3]
end

function venues.sky_tint()
    if venues.mood_held() then return nil end
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    if layout == nil then return nil end
    return venues.sky_tint_of(layout.look, layout.hour)
end

function venues.dark_baked()
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    if layout == nil or layout.darkBaked ~= true then return nil end
    local d = type(layout.look) == "table" and layout.look.darkness or nil
    if type(d) == "number" then
        local g = math.max(45, math.min(110, 255 * (1 - d) + 20))
        return { g, g, g }
    end
    local entry = OF.modifiers ~= nil and OF.modifiers.BY_KEY ~= nil and OF.modifiers.BY_KEY["dark"] or nil
    local night = nil
    for _, stop in ipairs(entry ~= nil and entry.levels or {}) do
        local rgb = stop.light ~= nil and { stop.light[1], stop.light[2], stop.light[3] }
            or (stop.grey ~= nil and { stop.grey, stop.grey, stop.grey }) or nil
        if rgb ~= nil and stop.name == d then return rgb end
        if stop.name == "night" then night = rgb end
    end
    return night or { 70, 70, 70 }
end

function venues.vision()
    if venues.mood_held() then return nil end
    local look = venues.look()
    if look == nil then return nil end
    local name = type(look.vision) == "string" and look.vision or nil
    local dials = type(look.dials) == "table" and look.dials or nil
    if name == nil and dials == nil then return nil end
    return { look = name, dials = dials }
end

function venues.track()
    local look = venues.look()
    if look == nil then return nil end
    local seq = constant(look.music)
    if seq ~= nil or type(look.music) ~= "string" then return seq end
    if not OF.util.asks(OF.music, "seq_for") then return nil end
    if type(OF.music.IMPORT_MARK) ~= "string" then return nil end
    local claimed = OF.music.seq_for(OF.music.IMPORT_MARK .. look.music)
    if type(claimed) ~= "number" or claimed <= 0
            or (OF.util.asks(OF.music, "is_stream") and OF.music.is_stream(claimed)) then
        return nil
    end
    return claimed
end

function venues.stream_track()
    local look = venues.look()
    if look == nil or type(look.music) ~= "string" or constant(look.music) ~= nil then
        return nil
    end
    if not (OF.util.asks(OF.music, "seq_for") and OF.util.asks(OF.music, "is_stream")) then
        return nil
    end
    if type(OF.music.IMPORT_MARK) ~= "string" then return nil end
    local claimed = OF.music.seq_for(OF.music.IMPORT_MARK .. look.music)
    if type(claimed) ~= "number" or claimed <= 0 or not OF.music.is_stream(claimed) then
        return nil
    end
    return claimed
end

venues.levelSeq = nil

local function restart_level_music()
    local own = venues.levelSeq
    if own == nil or own == 0 then return false end
    local head = OF.util.optional("get_current_background_music", nil)
    if type(head) ~= "number" or head < 0 or head % 256 ~= own % 256 then return false end

    OF.util.optional("play_music", nil, SEQ_PLAYER_LEVEL, own, 0)
    return true
end

function venues.settle_look()
    local want = venues.built
    if want == venues.worn then return false end
    venues.worn = want
    if OF.util.asks(OF.modifiers, "wear_place_sky") then
        OF.modifiers.wear_place_sky(venues.sky())
    end
    if OF.util.asks(OF.modifiers, "wear_place_light") then
        OF.modifiers.wear_place_light(venues.light())
    end
    if OF.util.asks(OF.modifiers, "wear_place_visuals") then
        OF.modifiers.wear_place_visuals(venues.visuals())
    end
    if OF.util.asks(OF.modifiers, "wear_place_vision") then
        OF.modifiers.wear_place_vision(venues.vision())
    end
    venues.moodHeldWas = venues.mood_held()
    restart_level_music()

    local stream = venues.stream_track()
    if (stream ~= nil or venues.streamWorn) and OF.util.asks(OF.music, "refresh") then
        OF.music.refresh()
    end
    venues.streamWorn = stream ~= nil
    return true
end

local function asked_for(seq)
    if not OF.util.asks(OF.music, "in_force") then return false end
    local playing = OF.music.in_force()
    return type(playing) == "number" and playing ~= 0 and playing % 256 == seq % 256
end

function venues.answer_load(seqPlayer, seqId)
    if seqPlayer ~= SEQ_PLAYER_LEVEL then return nil end
    local track = venues.track()
    if track == nil or venues.levelSeq == nil then return nil end
    if seqId % 256 ~= venues.levelSeq % 256 then return nil end
    if asked_for(seqId) then return nil end
    return track
end

if type(hook_event) == "function" and HOOK_ON_SEQ_LOAD ~= nil then
    hook_event(HOOK_ON_SEQ_LOAD, function(seqPlayer, seqId)
        return venues.answer_load(seqPlayer, seqId)
    end)
end

venues.EXPORTED_PREFIX = "ofmap_"
function venues.adopt_exported()
    local hub = rawget(_G, "OldfartMapsHub")
    if type(hub) ~= "table" or type(hub.maps) ~= "table" then return 0 end
    local newest = {}
    for _, map in ipairs(hub.maps) do
        if type(map) == "table" and type(map.key) == "string" and type(map.venue) == "table" then
            local had = newest[map.key]
            if had == nil or (tonumber(map.made) or 0) > (tonumber(had.made) or 0) then
                newest[map.key] = map
            end
        end
    end
    local n = 0
    for key, map in pairs(newest) do
        local vkey = venues.EXPORTED_PREFIX .. key
        venues.LAYOUTS[vkey] = map.venue
        local place = OF.util.asks(OF.arena, "find") and OF.arena.find(vkey) or nil
        if place == nil and OF.arena ~= nil and type(OF.arena.PLACES) == "table" then
            place = { key = vkey, name = tostring(map.name or key), blurb = tostring(map.blurb or ""),
                note = "a map exported from Oldfart Studio", script = vkey,
                base = map.venue.level, area = 1, act = 1, sweep = {}, venue = true,
                suits = {}, onlyFor = {}, noTravel = true, exported = true }
            table.insert(OF.arena.PLACES, place)
        end

        if place ~= nil and type(map.venue.face) == "table" then place.face = map.venue.face end
        n = n + 1
    end
    if n > 0 then
        venues.forget_keys()
        if OF.util.asks(OF.arena, "resolve_custom_levels") then OF.arena.resolve_custom_levels() end
    end
    return n
end

if type(hook_event) == "function" and HOOK_ON_MODS_LOADED ~= nil then
    hook_event(HOOK_ON_MODS_LOADED, function() venues.adopt_exported() end)
end

local bonusPublished = false
function venues.update()

    if OF.util.is_host() then
        if not bonusPublished then
            bonusPublished = true
            venues.bonus_publish()
        end
        venues.bonus_host_update()
    end
    local want = venues.wanted()
    if want ~= nil then
        if venues.built ~= want then venues.build(want) end
        venues.arrive()
        venues.hold_step()
        venues.level_relight_step()
        venues.lights_step()
        venues.cull_step()
        venues.place_things()
        venues.reach_update()
        venues.stars_update()

        if venues.selectArmed and venues.arrived then
            if venues.select_camera_taken() and venues.LAYOUTS[want] ~= nil
                and type(venues.LAYOUTS[want].stars) == "table" and #venues.LAYOUTS[want].stars > 0
                and (venues.selectWaited or 0) < venues.SELECT_WAIT_FRAMES then
                venues.selectWaited = (venues.selectWaited or 0) + 1
            else
                venues.selectArmed = false
                venues.selectWaited = 0
                venues.select_open(want)
            end
        end

        venues.select_step()
        venues.settle_mood()
        venues.trail_step(want, gMarioStates ~= nil and gMarioStates[0] or nil)
        return
    end
    if venues.trail.key ~= nil then
        venues.trail_flush()
        venues.trail.key = nil
    end
    if venues.selecting ~= nil then
        if venues.selecting.away ~= nil then venues.select_step() else venues.select_close(false) end
    end
    local arriving = venues.selectArrive
    if arriving ~= nil then
        arriving.arriveFrames = (arriving.arriveFrames or 0) + 1
        if arriving.arriveFrames > venues.SELECT_ARRIVE_FRAMES then venues.select_arrived(arriving, false) end
    end
    venues.held = nil
    if venues.built ~= nil then venues.teardown() end
end

function venues.on_level_init()
    venues.objects = {}
    venues.markerObjects = {}

    venues.floorObject, venues.batchObjects, venues.mergedRows = nil, {}, 0
    venues.levelRows, venues.floorBaked = 0, false
    venues.level_bake_forget()

    venues.lights_forget(true)
    venues.wear_lods(false)

    venues.cull_release(true)
    pieceOf = {}
    forget_batches()

    venues.starObjects = {}

    if venues.selecting ~= nil then
        venues.selecting.cam = nil
        venues.selecting.stars, venues.selecting.wall = {}, nil
        venues.select_close(false, true)
    end
    local here = gNetworkPlayers ~= nil and gNetworkPlayers[0] ~= nil
        and gNetworkPlayers[0].currLevelNum or nil
    venues.selectArmed = here ~= venues.selectFrom
    venues.selectWaited = 0
    venues.thingsWaited = 0

    venues.trail_flush()
    if here ~= venues.selectFrom then venues.trail.key = nil end
    venues.selectFrom = here

    local arriving = venues.selectArrive
    if arriving ~= nil then
        local landed = arriving.away ~= nil and here == arriving.away.level
        if landed then venues.selectArmed = false end
        venues.select_arrived(arriving, landed)
    end
    venues.venue_water(nil, false)

    venues.things = {}
    venues.thingsDone = false
    venues.built = nil
    venues.builtLevel = nil
    venues.arrived = false
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = m ~= nil and m.area or nil
    venues.levelSeq = area ~= nil and tonumber(area.musicParam2) or nil
    venues.update()
    venues.settle_look()

    if venues.built ~= nil and OF.util.asks(OF.modifiers, "wear_place_light") then
        OF.modifiers.wear_place_light(venues.light())
    end
end

if type(hook_event) == "function" then
    hook_event(HOOK_UPDATE, venues.update)
    hook_event(HOOK_ON_LEVEL_INIT, venues.on_level_init)

    if HOOK_ON_INSTANT_WARP ~= nil then
        hook_event(HOOK_ON_INSTANT_WARP, function(area, id, displacement)
            return venues.pocket_arrived(area, id, displacement)
        end)
    end
    hook_event(HOOK_MARIO_UPDATE, venues.dance_update, OF.LOCAL_MARIO)
    hook_event(HOOK_ON_HUD_RENDER_BEHIND or HOOK_ON_HUD_RENDER, venues.hud_render)
    hook_event(HOOK_ON_HUD_RENDER_BEHIND or HOOK_ON_HUD_RENDER, venues.select_render)
    hook_event(HOOK_BEFORE_MARIO_UPDATE, venues.select_input, OF.LOCAL_MARIO)
    hook_event(HOOK_BEFORE_MARIO_UPDATE, venues.picking_before)
    hook_event(HOOK_MARIO_UPDATE, venues.picking_hide)
    hook_event(HOOK_BEFORE_MARIO_UPDATE, venues.hold_before, OF.LOCAL_MARIO)
    hook_event(HOOK_MARIO_UPDATE, venues.hold_after, OF.LOCAL_MARIO)
    hook_event(HOOK_ALLOW_INTERACT, venues.picking_interact)
end

local BAKE_CELL, BAKE_OFF, BAKE_NEAR, BAKE_FAR, BAKE_OUT = 200, 40, 90, 230, 200
local BAKE_DIAG, BAKE_AO, BAKE_SUN = 0.7071, 0.6, 0.60
local BAKE_EXTENT, BAKE_AO_LEAST = 800.0, 0.25
local BAKE_SHADOW_STEP, BAKE_SHADOW_STEPS, BAKE_SHADOW_LIGHT = 120, 24, 0.25
venues.BAKE_DEFAULT = { sun = { 0.36, 0.86, 0.36 }, sunc = { 1.0, 0.93, 0.80 },
                        sky = { 0.50, 0.50, 0.52 }, gnd = { 0.36, 0.33, 0.30 },
                        lo = { 0.84, 0.86, 1.0 }, hi = { 1.0, 0.95, 0.84 } }

local BAKE_TINT = { 0.94, 0.97, 1.05 }

local BAKE_PAINT_GAIN = { 0.55, 0.61, 0.67, 0.73, 0.79, 0.85, 0.90, 0.95, 1.0, 1.025, 1.05,
                          1.075, 1.10, 1.125, 1.15, 1.18 }
local BAKE_PAINT_MID = 8
local BAKE_WHITE = { 1.0, 1.0, 1.0 }

function venues.bake_paint(pal, paint)
    local g = BAKE_PAINT_GAIN[paint + 1]
    local w, tint
    if paint < BAKE_PAINT_MID then
        w = (BAKE_PAINT_MID - paint) / (BAKE_PAINT_MID + 0.0)
        tint = pal.lo or BAKE_WHITE
    else
        w = (paint - BAKE_PAINT_MID) / (#BAKE_PAINT_GAIN - 1 - BAKE_PAINT_MID + 0.0)
        tint = pal.hi or BAKE_WHITE
    end
    return g * (1.0 + (tint[1] - 1.0) * w), g * (1.0 + (tint[2] - 1.0) * w),
        g * (1.0 + (tint[3] - 1.0) * w)
end

local function bake_unit(x, y, z)
    local ln = math.sqrt(x * x + y * y + z * z)
    if ln == 0 then return 0.0, 1.0, 0.0 end
    return x / ln, y / ln, z / ln
end

function venues.bake_box(row)
    local kind, model = row[1], tostring(row[2])
    if kind == "decor" or model == "none" or string.find(model, "invisible", 1, true)
        or string.find(model, "water", 1, true) then
        return nil
    end
    local x, y, z = tonumber(row[3]) + 0.0, tonumber(row[4]) + 0.0, tonumber(row[5]) + 0.0
    local w, h, d = tonumber(row[6]) + 0.0, tonumber(row[7]) + 0.0, tonumber(row[8]) + 0.0
    local q = (tonumber(row[9]) or 0) % 180.0
    if q == 90.0 then w, d = d, w elseif q ~= 0.0 then w = math.max(w, d); d = w end
    return { x - w / 2.0, x + w / 2.0, y, y + h, z - d / 2.0, z + d / 2.0 }
end

function venues.bake_grid(rows)
    local boxes, cells, top = {}, {}, nil
    for _, row in ipairs(rows) do
        local b = venues.bake_box(row)
        if b ~= nil and b[2] > b[1] and b[4] > b[3] and b[6] > b[5] then
            boxes[#boxes + 1] = b
            if top == nil or b[4] > top then top = b[4] end
            local k = #boxes
            for i = math.floor(b[1] / BAKE_CELL), math.floor((b[2] - 0.001) / BAKE_CELL) do
                for j = math.floor(b[5] / BAKE_CELL), math.floor((b[6] - 0.001) / BAKE_CELL) do
                    local key = i * 65536 + j
                    local list = cells[key]
                    if list == nil then list = {}; cells[key] = list end
                    list[#list + 1] = k
                end
            end
        end
    end
    return { boxes = boxes, cells = cells, top = top }
end

local function bake_solid(g, x, y, z)
    local list = g.cells[math.floor(x / BAKE_CELL) * 65536 + math.floor(z / BAKE_CELL)]
    if list == nil then return false end
    for _, k in ipairs(list) do
        local b = g.boxes[k]
        if b[1] <= x and x < b[2] and b[3] <= y and y < b[4] and b[5] <= z and z < b[6] then
            return true
        end
    end
    return false
end

function venues.bake_occlusion(g, x, y, z, nx, ny, nz)
    local t1x, t1y, t1z, t2x, t2y, t2z
    if math.abs(ny) > 0.9 then
        t1x, t1y, t1z, t2x, t2y, t2z = 1.0, 0.0, 0.0, 0.0, 0.0, 1.0
    else
        local ln = math.sqrt(nz * nz + nx * nx)
        t1x, t1y, t1z, t2x, t2y, t2z = 0.0, 1.0, 0.0, -nz / ln, 0.0, nx / ln
    end
    local bx, by, bz = x + nx * BAKE_OFF, y + ny * BAKE_OFF, z + nz * BAKE_OFF
    local hit = 0.0
    for _, s in ipairs({ 1.0, -1.0 }) do
        if bake_solid(g, bx + t1x * s * BAKE_NEAR, by + t1y * s * BAKE_NEAR, bz + t1z * s * BAKE_NEAR) then
            hit = hit + 1.0
        end
        if bake_solid(g, bx + t2x * s * BAKE_NEAR, by + t2y * s * BAKE_NEAR, bz + t2z * s * BAKE_NEAR) then
            hit = hit + 1.0
        end
    end
    for _, a in ipairs({ BAKE_DIAG, -BAKE_DIAG }) do
        for _, b in ipairs({ BAKE_DIAG, -BAKE_DIAG }) do
            local dx = (t1x * a + t2x * b) * BAKE_FAR
            local dy = (t1y * a + t2y * b) * BAKE_FAR
            local dz = (t1z * a + t2z * b) * BAKE_FAR
            if bake_solid(g, bx + dx, by + dy, bz + dz) then hit = hit + 0.5 end
        end
    end
    if bake_solid(g, bx + nx * BAKE_OUT, by + ny * BAKE_OUT, bz + nz * BAKE_OUT) then
        hit = hit + 1.0
    end
    return hit / 7.0
end

local function bake_shadowed(g, x, y, z, nx, ny, nz, sx, sy, sz)
    if g.top == nil then return false end
    local bx, by, bz = x + nx * BAKE_OFF, y + ny * BAKE_OFF, z + nz * BAKE_OFF
    for k = 1, BAKE_SHADOW_STEPS do
        local t = k * BAKE_SHADOW_STEP
        local py = by + sy * t
        if py >= g.top then return false end
        if bake_solid(g, bx + sx * t, py, bz + sz * t) then return true end
    end
    return false
end

function venues.bake_shade(pal, sx, sy, sz, nx, ny, nz, ao, lit, paint)
    local ndl = nx * sx + ny * sy + nz * sz
    if ndl < 0 then ndl = 0.0 end
    ndl = ndl * lit
    local hemi = 0.5 + 0.5 * ny
    local m1, m2, m3 = venues.bake_paint(pal, paint or BAKE_PAINT_MID)
    local out = {}
    for c = 1, 3 do
        local amb = (pal.sky[c] * hemi + pal.gnd[c] * (1.0 - hemi)) * BAKE_TINT[c]
        local v = amb * ao + pal.sunc[c] * ndl * BAKE_SUN * (0.55 + 0.45 * ao)
        v = v * (c == 1 and m1 or (c == 2 and m2 or m3))
        if v > 1.0 then v = 1.0 end
        out[c] = math.floor(v * 255.0 + 0.5)
    end
    return out[1], out[2], out[3]
end

function venues.bake_colour(g, pal, x, y, z, nx, ny, nz, extent)
    nx, ny, nz = bake_unit(nx, ny, nz)

    local k, big = BAKE_AO, 1.0
    if extent ~= nil and extent > BAKE_EXTENT then
        big = math.max(BAKE_AO_LEAST, BAKE_EXTENT / extent)
        k = BAKE_AO * big
    end
    local sx, sy, sz = bake_unit(pal.sun[1], pal.sun[2], pal.sun[3])
    local lit = 1.0
    if nx * sx + ny * sy + nz * sz > 0 and bake_shadowed(g, x, y, z, nx, ny, nz, sx, sy, sz) then

        lit = 1.0 - (1.0 - BAKE_SHADOW_LIGHT) * big
    end
    local ao = 1.0 - k * venues.bake_occlusion(g, x, y, z, nx, ny, nz)
    local r, gr, b = venues.bake_shade(pal, sx, sy, sz, nx, ny, nz, ao, lit)
    return r, gr, b, ao, lit
end

local BAKE_RELIT_KEEP = 0.9

function venues.own_hour(pal, dir)
    local own = pal ~= nil and pal.hour or nil
    if own == nil or type(dir) ~= "table" then return false end
    for i = 1, 3 do
        if math.abs((tonumber(own[i]) or 0) - (tonumber(dir[i]) or 0)) >= 1e-3 then return false end
    end
    return true
end

function venues.bake_relit(pal, dir)
    if dir == nil or venues.own_hour(pal, dir) then return nil end
    local bx, by, bz = bake_unit(pal.sun[1], pal.sun[2], pal.sun[3])
    local base = pal.sun0 or pal.sun
    local sx, sy, sz = bake_unit(base[1] + (tonumber(dir[1]) or 0),
        base[2] + (tonumber(dir[2]) or 0), base[3] + (tonumber(dir[3]) or 0))
    local keep = sx * bx + sy * by + sz * bz >= BAKE_RELIT_KEEP
    return function(nx, ny, nz, ao, lit, paint)
        nx, ny, nz = bake_unit(nx, ny, nz)
        return venues.bake_shade(pal, sx, sy, sz, nx, ny, nz, ao, keep and lit or 1.0, paint)
    end
end

function venues.bake_palette(look)
    local b = nil
    if look ~= nil then b = look.bake end
    if b == false then return nil end
    local pal = {}
    for _, k in ipairs({ "sun", "sunc", "sky", "gnd", "lo", "hi" }) do
        local v = type(b) == "table" and b[k] or nil
        if type(v) == "table" and #v == 3 then
            pal[k] = { tonumber(v[1]) + 0.0, tonumber(v[2]) + 0.0, tonumber(v[3]) + 0.0 }
        else
            pal[k] = venues.BAKE_DEFAULT[k]
        end
    end

    local sun0 = type(b) == "table" and b.sun0 or nil
    if type(sun0) == "table" and #sun0 == 3 then
        pal.sun0 = { tonumber(sun0[1]) + 0.0, tonumber(sun0[2]) + 0.0, tonumber(sun0[3]) + 0.0 }
    end
    local hour = look ~= nil and look.hourBaked or nil
    if type(hour) == "table" and #hour == 3 then
        pal.hour = { tonumber(hour[1]) or 0, tonumber(hour[2]) or 0, tonumber(hour[3]) or 0 }
    end
    return pal
end

function venues.bake_prepare(layout)
    if OF.stretch == nil then return end
    local pal = venues.bake_palette(layout ~= nil and layout.look or nil)
    if pal == nil or layout == nil or type(layout.pieces) ~= "table" then
        venues.bake_forget()
        return
    end

    local rows = {}
    for _, row in ipairs(layout.pieces) do rows[#rows + 1] = row end
    for _, row in ipairs(layout.static or {}) do rows[#rows + 1] = row end
    local g = venues.bake_grid(rows)
    OF.stretch.bake = function(x, y, z, nx, ny, nz, extent)
        return venues.bake_colour(g, pal, x, y, z, nx, ny, nz, extent)
    end
    OF.stretch.relit = function(dir) return venues.bake_relit(pal, dir) end

    local sx, sy, sz = bake_unit(pal.sun[1], pal.sun[2], pal.sun[3])
    OF.stretch.bake_dir = function(nx, ny, nz)
        nx, ny, nz = bake_unit(nx, ny, nz)
        return venues.bake_shade(pal, sx, sy, sz, nx, ny, nz, 1.0, 1.0)
    end
    OF.stretch.bakeSerial = (OF.stretch.bakeSerial or 0) + 1
end

function venues.bake_forget()
    if OF.stretch == nil then return end
    OF.stretch.bake, OF.stretch.relit, OF.stretch.bake_dir = nil, nil, nil
end

local BAKE_OCT_MID, BAKE_OCT_BITS, BAKE_OCT_MASK, BAKE_PAINT_SHIFT = 31, 6, 63, 12
local BAKE_PART_STEPS = 15
function venues.bake_unpack(flag, alpha)
    local u = ((flag & BAKE_OCT_MASK) - BAKE_OCT_MID) / (BAKE_OCT_MID + 0.0)
    local v = (((flag >> BAKE_OCT_BITS) & BAKE_OCT_MASK) - BAKE_OCT_MID) / (BAKE_OCT_MID + 0.0)
    local y = 1.0 - math.abs(u) - math.abs(v)
    if y < 0 then
        u, v = (1.0 - math.abs(v)) * (u >= 0 and 1.0 or -1.0),
            (1.0 - math.abs(u)) * (v >= 0 and 1.0 or -1.0)
    end
    local ln = math.sqrt(u * u + y * y + v * v)
    local lo = 1.0 - BAKE_AO
    local ao = lo + (alpha & 15) / (BAKE_PART_STEPS + 0.0) * (1.0 - lo)
    local lit = BAKE_SHADOW_LIGHT + ((alpha >> 4) & 15) / (BAKE_PART_STEPS + 0.0)
        * (1.0 - BAKE_SHADOW_LIGHT)
    return u / ln, y / ln, v / ln, ao, lit, (flag >> BAKE_PAINT_SHIFT) & 15
end

venues.LEVEL_RELIGHT_VERTICES = 7200
venues.levelBake = nil
venues.bakeShipped = {}
venues.bakeRelit = {}

function venues.level_bake_prepare(key, layout)
    venues.levelBake = nil
    local pal = venues.bake_palette(layout ~= nil and layout.look or nil)
    if pal == nil then return 0 end
    local arrays = {}
    while #arrays < 4096 do
        local first = OF.util.optional("vtx_get_from_name", nil,
            "of_" .. key .. "_bake_v" .. #arrays)
        if first == nil then break end
        arrays[#arrays + 1] = first
    end

    local serial = OF.stretch ~= nil and OF.stretch.sunSerial or 0
    local worn = OF.util.asks(OF.stretch, "sun") and not venues.own_hour(pal, OF.stretch.sun)
    local sunAt = (worn or venues.bakeRelit[key]) and -1 or serial
    venues.bakeShipped[key] = venues.bakeShipped[key] or {}
    venues.levelBake = { key = key, pal = pal, arrays = arrays, sunAt = sunAt,
                         shipped = venues.bakeShipped[key] }
    return #arrays
end

function venues.level_bake_forget()
    venues.levelBake = nil
end

function venues.bake_rescale(c, from, to)
    if from < 1 then return math.min(255, c + to) end
    return math.min(255, math.floor(c * to / from + 0.5))
end

function venues.level_relight_step()
    local lb = venues.levelBake
    if lb == nil then return 0 end
    local serial = OF.stretch ~= nil and OF.stretch.sunSerial or 0
    if lb.sunAt ~= serial then
        lb.sunAt, lb.next, lb.at, lb.i = serial, 1, nil, 0
        local dir = OF.stretch ~= nil and OF.stretch.sun or nil
        local pal = lb.pal
        local sx, sy, sz = bake_unit(pal.sun[1], pal.sun[2], pal.sun[3])
        lb.base = function(nx, ny, nz, ao, lit, paint)
            return venues.bake_shade(pal, sx, sy, sz, nx, ny, nz, ao, lit, paint)
        end
        lb.shade = dir ~= nil and venues.bake_relit(pal, dir) or nil
        if lb.shade ~= nil then
            venues.bakeRelit[lb.key] = true
        elseif not venues.bakeRelit[lb.key] then

            lb.next = nil
        end
    end
    if lb.next == nil then return 0 end
    local done = 0
    while lb.next <= #lb.arrays and done < venues.LEVEL_RELIGHT_VERTICES do
        local at = lb.at or lb.arrays[lb.next]
        local kept = lb.shipped[lb.next]
        if kept == nil then
            kept = {}
            lb.shipped[lb.next] = kept
        end
        while at ~= nil and done < venues.LEVEL_RELIGHT_VERTICES do
            lb.i = lb.i + 1
            local was = kept[lb.i]
            if was == nil then
                was = ((at.r or 0) << 16) | ((at.g or 0) << 8) | (at.b or 0)
                kept[lb.i] = was
            end
            local r, g, b = (was >> 16) & 255, (was >> 8) & 255, was & 255
            local alpha = at.a or 255

            if lb.shade ~= nil and not (r == g and g == b and alpha == 255) then
                local nx, ny, nz, ao, lit, paint = venues.bake_unpack(at.flag or 0, alpha)
                local r0, g0, b0 = lb.base(nx, ny, nz, ao, lit, paint)
                local r1, g1, b1 = lb.shade(nx, ny, nz, ao, lit, paint)
                if r == r0 and g == g0 and b == b0 then
                    r, g, b = r1, g1, b1
                else
                    r, g, b = venues.bake_rescale(r, r0, r1), venues.bake_rescale(g, g0, g1),
                        venues.bake_rescale(b, b0, b1)
                end
            end
            at.r, at.g, at.b = r, g, b
            done = done + 1
            at = OF.util.optional("vtx_get_next_vertex", nil, at)
        end
        if at == nil then
            lb.next, lb.at, lb.i = lb.next + 1, nil, 0
        else
            lb.at = at
        end
    end
    if lb.next > #lb.arrays then
        lb.next = nil

        if lb.shade == nil then venues.bakeRelit[lb.key] = nil end
    end
    return done
end

venues.LODS = false

function venues.wear_lods(on)
    if OF.util.asks(OF.rules, "wear_lods") then return OF.rules.wear_lods(on == true) end
    return false
end

venues.LIGHTS_NEAR = 16
venues.LIGHTS_PICK_EVERY = 8
venues.LIGHTS_MARGIN = 2500
venues.LIGHTS_HZ = 30

local function light_hash(i, seed)
    local h = (i * 1103515245 + seed * 12345 + 7) & 0x7fffffff
    h = (h ~ (h >> 13)) * 1274126177 & 0x7fffffff
    return (h % 20001) / 10000.0 - 1.0
end

function venues.light_noise(u, seed)
    local i = math.floor(u)
    local f = u - i
    local a, b = light_hash(i, seed), light_hash(i + 1, seed)
    local w = (1.0 - math.cos(f * math.pi)) * 0.5
    return a + (b - a) * w
end

function venues.light_flicker(L, t)
    local a1, f1, a2, f2 = tonumber(L[9]) or 0, tonumber(L[10]) or 0, tonumber(L[11]) or 0,
        tonumber(L[12]) or 0
    if a1 <= 0 and a2 <= 0 then return 1.0 end
    local seed = (math.floor(L[1]) * 3 + math.floor(L[2]) * 5 + math.floor(L[3]) * 7) & 0xffff
    local s = t / venues.LIGHTS_HZ
    local k = 1.0 + a1 * venues.light_noise(s * f1, seed) + a2 * venues.light_noise(s * f2, seed + 101)
    if k < 0.2 then k = 0.2 elseif k > 1.6 then k = 1.6 end
    return k
end

function venues.light_pick(lights, x, y, z, most)
    local near = {}
    for i, L in ipairs(lights or {}) do
        local dx, dy, dz = L[1] - x, L[2] - y, L[3] - z
        local d2 = dx * dx + dy * dy + dz * dz
        local reach = (L[7] or 0) + venues.LIGHTS_MARGIN
        if d2 <= reach * reach then near[#near + 1] = { i, d2 } end
    end
    table.sort(near, function(a, b)
        if a[2] ~= b[2] then return a[2] < b[2] end
        return a[1] < b[1]
    end)
    local out = {}
    for k = 1, math.min(most or venues.LIGHTS_NEAR, #near) do out[k] = near[k][1] end
    return out
end

venues.LIGHTS_FADE_IN = 9
local function smooth01(v)
    v = math.max(0, math.min(1, v))
    return v * v * (3 - 2 * v)
end

function venues.lights_apply(st, lights, x, y, z, t, on, le)
    st.ids = st.ids or {}
    st.on = st.on or {}
    st.level = st.level or {}
    local want = {}
    local most = st.most or venues.LIGHTS_NEAR
    if on and lights ~= nil and #lights > 0 then
        if st.chosen == nil or st.pickedAt == nil or t - st.pickedAt >= venues.LIGHTS_PICK_EVERY
            or t < st.pickedAt or st.pickedMost ~= most then
            if st.picker ~= nil then
                st.chosen = st.picker(lights, most, st.chosen)
            else
                st.chosen = venues.light_pick(lights, x, y, z, most)
            end
            st.pickedAt, st.pickedMost = t, most
        end
        for _, i in ipairs(st.chosen) do want[i] = true end
    else
        st.chosen = nil
    end
    local step = 1 / venues.LIGHTS_FADE_IN
    local parks = {}
    for i in pairs(st.on) do
        if not want[i] then parks[#parks + 1] = i end
    end
    table.sort(parks)
    local fading = 0
    for _, i in ipairs(parks) do
        local level = st.fade and lights ~= nil and lights[i] ~= nil and (st.level[i] or 0) - step or 0
        if level > 0 then
            st.level[i] = level
            le.intensity(st.ids[i], lights[i][8] * smooth01(level))
            if st.shown ~= nil then st.shown[i] = lights[i][8] * smooth01(level) end
            fading = fading + 1
        else
            le.intensity(st.ids[i], 0)
            st.on[i], st.level[i] = nil, nil
            if st.shown ~= nil then st.shown[i] = nil end
        end
    end
    local active = 0
    for _, i in ipairs(st.chosen or {}) do
        local L = lights[i]
        local k = venues.light_flicker(L, t)
        local r, g, b = math.min(255, math.floor(L[4] * k + 0.5)),
            math.min(255, math.floor(L[5] * k + 0.5)), math.min(255, math.floor(L[6] * k + 0.5))
        local level = 1
        if st.fade then
            level = math.min(1, (st.level[i] or 0) + step)
            st.level[i] = level
        end
        local v = L[8] * smooth01(level)
        if st.ids[i] == nil then
            local id = le.add(L[1], L[2], L[3], r, g, b, L[7], v)
            if type(id) == "number" and id >= 0 then
                st.ids[i], st.on[i] = id, true
                if L[13] ~= nil and le.normals ~= nil then le.normals(id, L[13] == 1) end
            end
        else
            if not st.on[i] or (st.fade and (st.shown == nil or st.shown[i] ~= v)) then
                le.intensity(st.ids[i], v)
                st.on[i] = true
            end
            le.colour(st.ids[i], r, g, b)
        end
        if st.fade then
            st.shown = st.shown or {}
            st.shown[i] = v
        end
        if st.on[i] then active = active + 1 end
    end
    return active
end

venues.NIGHT_AMBIENT = { 96, 100, 120 }
venues.NIGHT_FLOOR = 90

venues.ACTOR_LIGHT = { 235, 240, 255 }
venues.LIGHTS_ACTIVE = 8
venues.LIGHTS_EYE = 4
venues.LIGHTS_PER_MARIO = 2
venues.LIGHTS_MARIO_REACH = 6000
venues.LIGHTS_HOLD = 0.75
venues.LE_MODE_LEVEL = 0
venues.LE_MODE_ACTORS = 1
venues.LE_MOST_WORN = 8
venues.LE_MOST_PLAIN = 4

function venues.lightfog_v2(layout)
    if type(layout) == "table" then
        local v = tonumber(layout.lightfog or layout.LIGHTFOG_CONTRACT or layout.lightfogContract)
        if v ~= nil then return v >= 2 end
    end
    return venues.cullMarked == true
end

function venues.light_pick_v2(lights, eye, marios, most, prev)
    most = math.min(most or venues.LIGHTS_ACTIVE, venues.LIGHTS_ACTIVE)
    local burning = {}
    for _, i in ipairs(prev or {}) do burning[i] = true end
    local function ranked(p, reach)
        local near = {}
        for i, L in ipairs(lights or {}) do
            local dx, dy, dz = L[1] - p.x, L[2] - p.y, L[3] - p.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if reach == nil or d <= reach then
                if burning[i] then d = d * venues.LIGHTS_HOLD end
                near[#near + 1] = { i, d }
            end
        end
        table.sort(near, function(a, b)
            if a[2] ~= b[2] then return a[2] < b[2] end
            return a[1] < b[1]
        end)
        return near
    end
    local out, taken = {}, {}
    local function take(list, n)
        local got = 0
        for _, e in ipairs(list) do
            if got >= n or #out >= most then return end
            if not taken[e[1]] then
                taken[e[1]] = true
                out[#out + 1] = e[1]
                got = got + 1
            end
        end
    end
    if eye ~= nil then take(ranked(eye, nil), venues.LIGHTS_EYE) end
    for _, p in ipairs(marios or {}) do
        take(ranked(p, venues.LIGHTS_MARIO_REACH), venues.LIGHTS_PER_MARIO)
    end

    if eye ~= nil then take(ranked(eye, nil), most) end
    return out
end

function venues.light_viewers()
    local lk = rawget(_G, "gLakituState")
    local eye = lk ~= nil and (lk.pos or lk.focus) or nil
    local marios = {}
    local ms, nps = rawget(_G, "gMarioStates"), rawget(_G, "gNetworkPlayers")
    if ms ~= nil then
        for i = 0, 15 do
            local m, np = ms[i], nps ~= nil and nps[i] or nil
            if m ~= nil and m.pos ~= nil and (i == 0 or (np ~= nil and np.connected)) then
                marios[#marios + 1] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            end
        end
    end
    if eye == nil and marios[1] ~= nil then eye = marios[1] end
    return eye, marios
end

function venues.le_wear(S, on, le)
    if (S.leWorn == true) == (on == true) then return false end
    S.leWorn = on == true
    if le.mode ~= nil then le.mode(on and venues.LE_MODE_ACTORS or venues.LE_MODE_LEVEL) end
    if le.most ~= nil then le.most(on and venues.LE_MOST_WORN or venues.LE_MOST_PLAIN) end
    return true
end

function venues.lights_release(st, le, gone)
    if st == nil or st.ids == nil then return 0 end
    local ids = {}
    for i in pairs(st.ids) do ids[#ids + 1] = i end
    table.sort(ids)
    if not gone then
        for _, i in ipairs(ids) do le.remove(st.ids[i]) end
    end
    st.ids, st.on, st.chosen, st.pickedAt, st.pickedMost = {}, {}, nil, nil, nil
    st.level, st.shown = {}, nil
    return #ids
end

function venues.lights_engine()
    local function call(name, ...)
        local f = rawget(_G, name)
        if type(f) ~= "function" then return nil end
        return f(...)
    end
    return {
        add = function(x, y, z, r, g, b, radius, v) return call("le_add_light", x, y, z, r, g, b, radius, v) end,
        remove = function(id) return call("le_remove_light", id) end,
        intensity = function(id, v) return call("le_set_light_intensity", id, v) end,
        colour = function(id, r, g, b) return call("le_set_light_color", id, r, g, b) end,
        enabled = function() return call("le_is_enabled") == true end,

        normals = function(id, on) return call("le_set_light_use_surface_normals", id, on == true) end,
        mode = function(m) return call("le_set_mode", m) end,
        most = function(n) return call("le_set_max_lights_per_vertex", n) end,
    }
end

function venues.room_kind(rooms, room)
    if type(rooms) ~= "table" or type(room) ~= "number" or room < 1 then return "open" end
    return rooms[room] or "open"
end

function venues.lights_dark(layout, room)
    if layout == nil then return false end
    if layout.night == true then return true end
    local kind = venues.room_kind(layout.rooms, room)
    return kind == "cave" or kind == "inside"
end

function venues.room_watch(st, rooms)
    if type(rooms) ~= "table" or #rooms < 2 then
        venues.room_release(st)
        return nil
    end
    local lk = rawget(_G, "gLakituState")
    local ms = rawget(_G, "gMarioStates")

    local p = lk ~= nil and lk.pos or nil
    if p == nil and lk ~= nil then p = lk.focus end
    if p == nil and ms ~= nil and ms[0] ~= nil then p = ms[0].pos end
    local find = rawget(_G, "collision_find_floor")
    local set = rawget(_G, "set_room_override")
    if p == nil or find == nil or set == nil then return st.room end
    local s = find(p.x, p.y + 100, p.z)
    local room = s ~= nil and tonumber(s.room) or nil
    if room ~= nil and room >= 1 and room <= #rooms then
        if st.room ~= room or not st.set then set(room) end
        st.room, st.set = room, true
    end
    return st.room
end

function venues.room_release(st)
    if st ~= nil and st.set then
        local set = rawget(_G, "set_room_override")
        if set ~= nil then set(-1) end
    end
    if st ~= nil then st.room, st.set = nil, false end
end

venues.FLAMES_MOST = 48
venues.FLAME_SCALE = 7

function venues.flames_keep(st, key, rows, spawn)
    if st.key ~= key then
        st.key, st.list = key, {}
        for i, r in ipairs(type(rows) == "table" and rows or {}) do
            if i > venues.FLAMES_MOST then break end
            local o = spawn(r[4] == 1, r[1], r[2], r[3])
            if o ~= nil then
                st.list[#st.list + 1] = { o = o, scale = tonumber(r[5]) or venues.FLAME_SCALE,
                                          sized = (tonumber(r[5]) or venues.FLAME_SCALE) == venues.FLAME_SCALE }
            end
        end
    end
    local scale = rawget(_G, "obj_scale")
    for _, f in ipairs(st.list or {}) do
        if not f.sized and f.o ~= nil and (tonumber(f.o.oTimer) or 0) >= 1 and scale ~= nil then
            scale(f.o, f.scale)
            f.sized = true
        end
    end
    return #(st.list or {})
end

function venues.flames_release(st, gone)
    local del = rawget(_G, "obj_mark_for_deletion")
    if not gone and del ~= nil then
        for _, f in ipairs(st.list or {}) do
            if f.o ~= nil then del(f.o) end
        end
    end
    st.key, st.list = nil, {}
end

function venues.flame_spawn(blue, x, y, z)
    local spawn = rawget(_G, "spawn_non_sync_object")
    local bhv = rawget(_G, "id_bhvFlame")
    local model = blue and rawget(_G, "E_MODEL_BLUE_FLAME") or rawget(_G, "E_MODEL_RED_FLAME")
    if spawn == nil or bhv == nil or model == nil then return nil end
    return spawn(bhv, model, x, y, z, nil)
end

venues.DARK_AMBIENT = 208

venues.POCKET_FADE = 14
function venues.pocket_warp(shift, d)
    if type(shift) ~= "table" or #shift ~= 3 or d == nil then return false end
    local dx, dy, dz = tonumber(d.x) or 0, tonumber(d.y) or 0, tonumber(d.z) or 0
    for _, sign in ipairs({ 1, -1 }) do
        if math.abs(dx - sign * shift[1]) < 1 and math.abs(dy - sign * shift[2]) < 1
            and math.abs(dz - sign * shift[3]) < 1 then
            return true
        end
    end
    return false
end

function venues.pocket_door(shift, d)
    if not venues.pocket_warp(shift, d) then return false end
    local fade = rawget(_G, "play_transition")
    if fade ~= nil then
        fade(rawget(_G, "WARP_TRANSITION_FADE_FROM_COLOR") or 1, venues.POCKET_FADE, 0, 0, 0)
    end
    return true
end

venues.LIGHTS_RUNGS = { 16, 8, 4 }
venues.LIGHTS_PACE_WINDOW = 60
venues.LIGHTS_SLOW_MS = 40
venues.LIGHTS_FAST_MS = 36
venues.LIGHTS_CALM = 3
venues.LIGHTS_CALM_MOST = 48
venues.LIGHTS_HITCH_MS = 250
function venues.lights_pace(P, ms)
    P.rung = P.rung or 1
    P.n, P.sum, P.calm = P.n or 0, P.sum or 0, P.calm or 0
    P.need = P.need or venues.LIGHTS_CALM
    if type(ms) == "number" and ms > 0 and ms < venues.LIGHTS_HITCH_MS then
        P.n, P.sum = P.n + 1, P.sum + ms
        if P.n >= venues.LIGHTS_PACE_WINDOW then
            local mean = P.sum / P.n
            P.n, P.sum = 0, 0
            if mean > venues.LIGHTS_SLOW_MS then
                if P.climbed then P.need = math.min(venues.LIGHTS_CALM_MOST, P.need * 2) end
                if P.rung < #venues.LIGHTS_RUNGS then P.rung = P.rung + 1 end
                P.calm = 0
            elseif mean < venues.LIGHTS_FAST_MS then
                P.calm = P.calm + 1
                if P.calm >= P.need and P.rung > 1 then
                    P.rung, P.calm = P.rung - 1, 0
                    P.climbed = true
                    return venues.LIGHTS_RUNGS[P.rung]
                end
            else
                P.calm = 0
            end
            P.climbed = false
        end
    end
    return venues.LIGHTS_RUNGS[P.rung]
end

function venues.lights_paced(S, burning)
    S.lightsPace = S.lightsPace or {}
    local P = S.lightsPace
    local clock = rawget(_G, "clock_elapsed_f64")
    local now = burning and type(clock) == "function" and tonumber(clock()) or nil
    if now ~= nil and P.at ~= nil then venues.lights_pace(P, (now - P.at) * 1000) end
    P.at = now
    return venues.LIGHTS_RUNGS[P.rung or 1]
end

venues.LIGHTS_FADE = 30
function venues.lights_frame(S, key, layout, x, y, z, door)
    venues.flames_keep(S.flameState, key, layout.flames, venues.flame_spawn)
    local le = venues.lights_engine()
    local v2 = venues.lightfog_v2(layout)
    venues.le_wear(S, v2, le)
    local dresser = door.owns() == true
    local dark = venues.lights_dark(layout, venues.room_watch(S.roomState, layout.rooms))

    local target
    if v2 then
        target = {}
        for c = 1, 3 do target[c] = math.max(venues.NIGHT_FLOOR, venues.NIGHT_AMBIENT[c]) end
    else
        local A = venues.DARK_AMBIENT
        target = { A, A, A }
    end
    local function at_fade()
        local f = S.lightsFade / venues.LIGHTS_FADE
        local c = {}
        for i = 1, 3 do c[i] = math.floor(255 - (255 - target[i]) * f + 0.5) end
        return c[1], c[2], c[3]
    end
    if dark and not dresser then
        S.lightsFade = math.min(venues.LIGHTS_FADE, S.lightsFade + 1)
        if door.set(at_fade()) then S.lightsAmbient = target[1] end
        if v2 and door.actor ~= nil then door.actor(true) end
    elseif S.lightsAmbient ~= nil then
        S.lightsFade = S.lightsFade - 1
        if S.lightsFade <= 0 or dresser then
            S.lightsAmbient, S.lightsFade = nil, 0
            door.clear()
            if door.actor ~= nil then door.actor(false) end
        else
            door.set(at_fade())
        end
    end
    local lights = type(layout.lights) == "table" and layout.lights or {}

    local on = #lights > 0 and (dresser or S.lightsAmbient ~= nil)
    S.lightsState.most = venues.lights_paced(S, on)
    S.lightsState.fade = v2
    if v2 then
        S.lightsState.most = math.min(S.lightsState.most, venues.LIGHTS_ACTIVE)
        S.lightsState.picker = function(list, most, prev)
            local eye, marios = venues.light_viewers()
            return venues.light_pick_v2(list, eye, marios, most, prev)
        end
    else
        S.lightsState.picker = nil
    end
    S.lightsFrame = S.lightsFrame + 1
    return venues.lights_apply(S.lightsState, lights, x, y, z, S.lightsFrame, on, le)
end

function venues.lights_drop(S, gone, door)

    venues.le_wear(S, false, venues.lights_engine())
    if door.actor ~= nil then door.actor(false) end
    venues.lights_release(S.lightsState, venues.lights_engine(), gone)
    venues.flames_release(S.flameState, gone)
    venues.room_release(S.roomState)
    if S.lightsPace ~= nil then S.lightsPace.at = nil end
    if S.lightsAmbient ~= nil then
        S.lightsAmbient, S.lightsFade = nil, 0
        door.clear()
    end
end

venues.lightsState = { ids = {}, on = {} }
venues.roomState = {}
venues.flameState = { list = {} }
venues.lightsAmbient = nil
venues.lightsFade = 0
venues.lightsFrame = 0
venues.lightsPace = nil

function venues.dark_held_elsewhere()
    local M = OF.modifiers
    if OF.util.asks(M, "dark_wanted") and M.dark_wanted() ~= nil then return true end
    return venues.lightsAmbient == nil and OF.util.asks(M, "owns_lighting") and M.owns_lighting() == true
end

venues.lightsDoor = {
    owns = function() return venues.dark_held_elsewhere() end,
    set = function(r, g, b)
        g, b = g or r, b or r
        return OF.util.asks(OF.modifiers, "set_lighting") and OF.modifiers.set_lighting(r, g, b) == true
    end,

    actor = function(on)
        local M = OF.modifiers
        if M ~= nil and (M.shadingHeld or M.showHeld) then
            venues.actorLit = false
            return
        end
        if (venues.actorLit == true) == (on == true) then return end
        venues.actorLit = on == true
        for i = 0, 2 do
            OF.util.optional("set_lighting_color", nil, i, on and venues.ACTOR_LIGHT[i + 1] or 255)
            OF.util.optional("set_lighting_color_ambient", nil, i, 255)
        end
    end,
    clear = function()

        if OF.util.asks(OF.modifiers, "dark_wanted") and OF.modifiers.dark_wanted() ~= nil then return end
        if OF.util.asks(OF.modifiers, "clear_dark") then OF.modifiers.clear_dark() end
    end,
}

function venues.lights_forget(gone)
    venues.lights_drop(venues, gone, venues.lightsDoor)
end

function venues.pocket_arrived(area, id, displacement)
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    if layout == nil then return false end
    return venues.pocket_door(layout.pocketShift, displacement)
end

function venues.lights_step()
    local layout = venues.built ~= nil and venues.LAYOUTS[venues.built] or nil
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if layout == nil or m == nil or m.pos == nil then return 0 end
    return venues.lights_frame(venues, venues.built, layout, m.pos.x, m.pos.y, m.pos.z,
        venues.lightsDoor)
end

venues.CULL_ASPECT = 2.4
venues.CULL_MARGIN = 15
venues.cullChunks = nil

local GRAPH_ACTIVE = 1

local function cull_call(name, default, ...)
    local f = rawget(_G, name)
    if type(f) ~= "function" then return default end
    local ok, out = pcall(f, ...)
    if not ok then return default end
    return out
end

local function walk_graph(first, visit, budget)
    budget = budget or { left = 8192 }
    local node = first
    while node ~= nil and budget.left > 0 do
        budget.left = budget.left - 1
        visit(node)
        if node.children ~= nil then walk_graph(node.children, visit, budget) end
        node = node.next
        if node == first then break end
    end
end

function venues.cull_collect(root)
    local out = {}
    if root == nil then return out end
    local TRANSLATION = GRAPH_NODE_TYPE_TRANSLATION or 0x016
    local LOD = GRAPH_NODE_TYPE_LEVEL_OF_DETAIL or 0x00B
    local MARKER = GRAPH_NODE_TYPE_CULLING_RADIUS or 0x02F
    venues.cullMarked = false
    walk_graph(root, function(node)
        local kid = node.children
        if node.type ~= TRANSLATION or kid == nil then return end
        local tn = cull_call("cast_graph_node", nil, node)
        local t = tn ~= nil and tn.translation or nil
        if t == nil then return end
        if kid.type == MARKER then

            local mn = cull_call("cast_graph_node", nil, kid)
            local r = mn ~= nil and tonumber(mn.cullingRadius) or nil
            if r == nil or r <= 0 then return end
            venues.cullMarked = true
            out[#out + 1] = { node = kid, x = t.x, y = t.y, z = t.z, r = r }
            return
        end
        if kid.type ~= LOD then return end
        local ln = cull_call("cast_graph_node", nil, kid)
        local r = ln ~= nil and tonumber(ln.minDistance) or nil
        if r == nil or r >= 0 then return end
        out[#out + 1] = { node = node, x = t.x, y = t.y, z = t.z, r = -r }
    end)
    return out
end

function venues.cull_cone()
    local fov = tonumber(cull_call("get_current_fov", 45)) or 45
    if fov <= 0 or fov >= 170 then fov = 45 end
    local half = math.atan(math.tan(math.rad(fov) / 2) * math.sqrt(1 + venues.CULL_ASPECT ^ 2))
    return half + math.rad(venues.CULL_MARGIN)
end

function venues.cull_sees(ex, ey, ez, fx, fy, fz, cone, c)
    local dx, dy, dz = c.x - ex, c.y - ey, c.z - ez
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d <= c.r then return true end
    local cos = (dx * fx + dy * fy + dz * fz) / d
    if cos > 1 then cos = 1 elseif cos < -1 then cos = -1 end
    return math.acos(cos) - math.asin(c.r / d) <= cone
end

function venues.cull_step()
    local chunks = venues.cullChunks
    if chunks == nil or #chunks == 0 then return 0 end
    local lk = gLakituState
    local eye, at = lk ~= nil and lk.pos or nil, lk ~= nil and lk.focus or nil
    if eye == nil or at == nil then return 0 end
    local fx, fy, fz = at.x - eye.x, at.y - eye.y, at.z - eye.z
    local len = math.sqrt(fx * fx + fy * fy + fz * fz)
    local off = 0
    local cone = venues.cull_cone()
    for _, c in ipairs(chunks) do
        local on = len < 1 or venues.cull_sees(eye.x, eye.y, eye.z, fx / len, fy / len, fz / len, cone, c)
        local flags = c.node.flags
        local now = (flags & GRAPH_ACTIVE) ~= 0
        if on ~= now then c.node.flags = on and (flags | GRAPH_ACTIVE) or (flags & ~GRAPH_ACTIVE) end
        if not on then off = off + 1 end
    end
    return off
end

function venues.cull_prepare()
    venues.cull_release()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = m ~= nil and m.area or nil
    local root = area ~= nil and area.root or nil
    local first = root ~= nil and root.node or nil
    local chunks = venues.cull_collect(first)
    venues.cullChunks = #chunks > 1 and chunks or nil
    return #chunks
end

function venues.cull_release(gone)
    local chunks = venues.cullChunks
    venues.cullChunks = nil
    venues.cullMarked = false
    if gone or chunks == nil then return end
    for _, c in ipairs(chunks) do
        local flags = c.node.flags
        if (flags & GRAPH_ACTIVE) == 0 then c.node.flags = flags | GRAPH_ACTIVE end
    end
end

venues.FOG_SLOT_FIRST = 3
venues.G_FOG = 0x00010000

local function head_lists(key)
    local out = {}
    local get = rawget(_G, "gfx_get_from_name")
    if key == nil or get == nil then return out end
    for _, suffix in ipairs({ "_static_dl", "_water_dl" }) do
        local ok, gfx = pcall(get, "of_" .. key .. suffix)
        if ok and gfx ~= nil then out[#out + 1] = gfx end
    end
    return out
end

function venues.fog_heads_here()
    if venues.built == nil then return false end
    local layout = venues.LAYOUTS ~= nil and venues.LAYOUTS[venues.built] or nil
    if not venues.lightfog_v2(layout) then return false end
    return #head_lists(venues.built) > 0
end

function venues.fog_heads(on, mul, off)
    local entries = {}
    for _, gfx in ipairs(head_lists(venues.built)) do
        entries[#entries + 1] = { gfx, venues.FOG_SLOT_FIRST }
    end
    return venues.fog_slots_write(entries, on, mul, off)
end

function venues.fog_slot_on(cmd, op, w0, w1, mul, off)
    local set = gfx_set_command
    if set == nil then return end
    if op == 0xD9 then
        local clear = (~w0) & 0x00FFFFFF
        set(cmd, "gsSPGeometryMode(%i, %i)", clear & ~venues.G_FOG, (w1 | venues.G_FOG) & 0xFFFFFFFF)
    elseif op == 0xDB then
        set(cmd, "gsSPFogFactor(%i, %i)", mul, off)
    elseif op == 0xF8 then
        set(cmd, "gsDPSetFogColor(%i, %i, %i, %i)", 255, 255, 255, 255)
    elseif op == 0xE2 then
        local len = (w0 & 0xFF) + 1
        local sft = 32 - len - ((w0 >> 8) & 0xFF)
        local data = w1 & 0xFFFFFFFF

        set(cmd, "gsSPSetOtherMode(%i, %i, %i, %i)", 0xE2, sft, len,
            (data & ~0xCCC00000) | 0xC8000000)
    end
end

function venues.fog_slot_back(cmd, op, w0, w1)
    local set = gfx_set_command
    if set == nil then return end
    if op == 0xD9 then
        set(cmd, "gsSPGeometryMode(%i, %i)", (~w0) & 0x00FFFFFF, w1 & 0xFFFFFFFF)
    elseif op == 0xDB then
        local fm, fo = (w1 >> 16) & 0xFFFF, w1 & 0xFFFF
        if fm >= 0x8000 then fm = fm - 0x10000 end
        if fo >= 0x8000 then fo = fo - 0x10000 end
        set(cmd, "gsSPFogFactor(%i, %i)", fm, fo)
    elseif op == 0xF8 then
        set(cmd, "gsDPSetFogColor(%i, %i, %i, %i)", (w1 >> 24) & 0xFF, (w1 >> 16) & 0xFF,
            (w1 >> 8) & 0xFF, w1 & 0xFF)
    elseif op == 0xE2 then
        local len = (w0 & 0xFF) + 1
        local sft = 32 - len - ((w0 >> 8) & 0xFF)
        set(cmd, "gsSPSetOtherMode(%i, %i, %i, %i)", 0xE2, sft, len, w1 & 0xFFFFFFFF)
    end
end

venues.headsHeld = {}
function venues.fog_slots_write(entries, on, mul, off)
    local get, opOf = gfx_get_command, gfx_get_op
    if not on then
        local n = #venues.headsHeld
        for i = n, 1, -1 do
            local h = venues.headsHeld[i]
            pcall(venues.fog_slot_back, h[1], h[2], h[3], h[4])
        end
        venues.headsHeld = {}
        return n
    end
    if get == nil or opOf == nil then return 0 end
    local written = 0
    for _, entry in ipairs(entries) do
        for k = 0, 3 do
            local cmd = get(entry[1], entry[2] + k)
            if cmd ~= nil then
                local held = nil
                for _, h in ipairs(venues.headsHeld) do
                    if h[1] == cmd then held = h end
                end
                if held == nil then
                    held = { cmd, opOf(cmd), (cmd.w0 or 0) & 0xFFFFFFFF, (cmd.w1 or 0) & 0xFFFFFFFF }
                    venues.headsHeld[#venues.headsHeld + 1] = held
                end
                pcall(venues.fog_slot_on, cmd, held[2], held[3], held[4], mul or 3200, off or -2944)
                written = written + 1
            end
        end
    end
    return written
end

function venues.ready()
    return true
end
