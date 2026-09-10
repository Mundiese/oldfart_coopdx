OF = OF or {}
OF.enemies = OF.enemies or {}

local enemies = OF.enemies

enemies.KEY = "ofEnemy"
enemies.PACKET = "enmy"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

enemies.ROSTER = {
    { key = "goomba",     name = "Goomba",         bhv = id_bhvGoomba,
      list = OBJ_LIST_PUSHABLE,    model = E_MODEL_GOOMBA },
    { key = "koopa",      name = "Koopa",          bhv = id_bhvKoopa,
      list = OBJ_LIST_PUSHABLE,    model = E_MODEL_KOOPA_WITH_SHELL },
    { key = "spiny",      name = "Spiny",          bhv = id_bhvSpiny,
      list = OBJ_LIST_PUSHABLE,    model = E_MODEL_SPINY },
    { key = "bobomb",     name = "Bob-omb",        bhv = id_bhvBobomb,
      list = OBJ_LIST_DESTRUCTIVE, model = E_MODEL_BLACK_BOBOMB },
    { key = "chuckya",    name = "Chuckya",        bhv = id_bhvChuckya,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_CHUCKYA },
    { key = "bully",      name = "Bully",          bhv = id_bhvSmallBully,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BULLY },
    { key = "chillbully", name = "Chill Bully",    bhv = id_bhvSmallChillBully,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_CHILL_BULLY },
    { key = "flyguy",     name = "Fly Guy",        bhv = id_bhvFlyGuy,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_FLYGUY },
    { key = "blizzard",   name = "Mr. Blizzard",   bhv = id_bhvMrBlizzard,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_MR_BLIZZARD },
    { key = "mole",       name = "Monty Mole",     bhv = id_bhvMontyMole,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_MONTY_MOLE },
    { key = "scuttlebug", name = "Scuttlebug",     bhv = id_bhvScuttlebug,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SCUTTLEBUG },
    { key = "pokey",      name = "Pokey",          bhv = id_bhvPokey,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_POKEY_HEAD },
    { key = "swoop",      name = "Swoop",          bhv = id_bhvSwoop,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SWOOP },
    { key = "boo",        name = "Boo",            bhv = id_bhvBoo,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BOO },
    { key = "snufit",     name = "Snufit",         bhv = id_bhvSnufit,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SNUFIT },
    { key = "lakitu",     name = "Enemy Lakitu",   bhv = id_bhvEnemyLakitu,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_ENEMY_LAKITU },
    { key = "klepto",     name = "Klepto",         bhv = id_bhvKlepto,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_KLEPTO },
    { key = "moneybag",   name = "Moneybag",       bhv = id_bhvMoneybag,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_MONEYBAG },
    { key = "spindrift",  name = "Spindrift",      bhv = id_bhvSpindrift,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SPINDRIFT },
    { key = "skeeter",    name = "Skeeter",        bhv = id_bhvSkeeter,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SKEETER },
    { key = "sushi",      name = "Sushi",          bhv = id_bhvSushiShark,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_SUSHI },
    { key = "unagi",      name = "Unagi",          bhv = id_bhvUnagi,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_UNAGI },
    { key = "bubba",      name = "Bubba",          bhv = id_bhvBubba,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BUBBA },
    { key = "amp",        name = "Amp",            bhv = id_bhvHomingAmp,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_AMP },
    { key = "circleamp",  name = "Circling Amp",   bhv = id_bhvCirclingAmp,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_AMP },
    { key = "chomp",      name = "Chain Chomp",    bhv = id_bhvChainChomp,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_CHAIN_CHOMP },
    { key = "piano",      name = "Mad Piano",      bhv = id_bhvMadPiano,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_MAD_PIANO },
    { key = "chair",      name = "Haunted Chair",  bhv = id_bhvHauntedChair,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_HAUNTED_CHAIR },
    { key = "bookend",    name = "Flying Bookend", bhv = id_bhvFlyingBookend,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BOOKEND },
    { key = "mri",        name = "Mr. I",          bhv = id_bhvMrI,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_MR_I },

    { key = "piranha",    name = "Piranha Plant",  bhv = id_bhvPiranhaPlant,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_PIRANHA_PLANT },
    { key = "firepiranha", name = "Fire Piranha",  bhv = id_bhvFirePiranhaPlant,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_PIRANHA_PLANT },
    { key = "heaveho",    name = "Heave-Ho",       bhv = id_bhvHeaveHo,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_HEAVE_HO },

    { key = "wiggler",    name = "Wiggler",        bhv = id_bhvWigglerHead,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_WIGGLER_HEAD, boss = true },
    { key = "kingbobomb", name = "King Bob-omb",   bhv = id_bhvKingBobomb,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_KING_BOBOMB,  boss = true },
    { key = "bigbully",   name = "Big Bully",      bhv = id_bhvBigBully,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BULLY_BOSS,   boss = true },
    { key = "bigchill",   name = "Big Chill Bully", bhv = id_bhvBigChillBully,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BIG_CHILL_BULLY, boss = true },
    { key = "bigboo",     name = "Big Boo",        bhv = id_bhvBalconyBigBoo,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_BOO,          boss = true },
    { key = "eyerok",     name = "Eyerok",         bhv = id_bhvEyerokHand,
      list = OBJ_LIST_GENACTOR,    model = E_MODEL_EYEROK_LEFT_HAND, boss = true },
    { key = "whomp",      name = "King Whomp",     bhv = id_bhvWhompKingBoss,
      list = OBJ_LIST_SURFACE,     model = E_MODEL_WHOMP,        boss = true },
}

enemies.DRESSES = {

    { key = "goomba",  name = "a Goomba",      model = E_MODEL_GOOMBA,
      radius = 72,  height = 50,  down = 0,  hurtR = 42, hurtH = 40,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "bobomb",  name = "a Bob-omb",     model = E_MODEL_BLACK_BOBOMB,
      radius = 85,  height = 70,  down = 0,  hurtR = 50, hurtH = 40,
      damage = 0, interact = INTERACT_GRABBABLE },
    { key = "spiny",   name = "a Spiny",       model = E_MODEL_SPINY,
      radius = 80,  height = 50,  down = 0,  hurtR = 50, hurtH = 40,
      damage = 2, interact = INTERACT_SPINY_WALKING },
    { key = "scuttle", name = "a Scuttlebug",  model = E_MODEL_SCUTTLEBUG,
      radius = 100, height = 60,  down = 0,  hurtR = 50, hurtH = 40,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "boo",     name = "a Boo",         model = E_MODEL_BOO,
      radius = 140, height = 80,  down = 0,  hurtR = 40, hurtH = 60,
      damage = 3, interact = INTERACT_BOUNCE_TOP },
    { key = "amp",     name = "an Amp",        model = E_MODEL_AMP,
      radius = 40,  height = 50,  down = 40, hurtR = 40, hurtH = 50,
      damage = 1, interact = INTERACT_SHOCK },
    { key = "chuckya", name = "a Chuckya",     model = E_MODEL_CHUCKYA,
      radius = 150, height = 100, down = 0,  hurtR = 80, hurtH = 60,
      damage = 0, interact = INTERACT_GRABBABLE },
    { key = "piranha", name = "a Piranha Plant", model = E_MODEL_PIRANHA_PLANT,
      radius = 100, height = 200, down = 0,  hurtR = 50, hurtH = 100,
      damage = 3, interact = INTERACT_DAMAGE },
    { key = "blizzard", name = "a Mr. Blizzard", model = E_MODEL_MR_BLIZZARD,
      radius = 70,  height = 100, down = 0,  hurtR = 50, hurtH = 80,
      damage = 2, interact = INTERACT_BOUNCE_TOP },
    { key = "chomp",   name = "a Chain Chomp", model = E_MODEL_CHAIN_CHOMP,
      radius = 150, height = 100, down = 0,  hurtR = 80, hurtH = 60,
      damage = 3, interact = INTERACT_BOUNCE_TOP },

    { key = "koopa",   name = "a Koopa",       model = E_MODEL_KOOPA_WITH_SHELL,
      radius = 60,  height = 40,  down = 0,  hurtR = 40, hurtH = 30,
      damage = 0, interact = INTERACT_KOOPA },
    { key = "flyguy",  name = "a Fly Guy",     model = E_MODEL_FLYGUY,
      radius = 70,  height = 60,  down = 0,  hurtR = 40, hurtH = 50,
      damage = 2, interact = INTERACT_BOUNCE_TOP },
    { key = "mole",    name = "a Monty Mole",  model = E_MODEL_MONTY_MOLE,
      radius = 70,  height = 50,  down = 0,  hurtR = 30, hurtH = 40,
      damage = 2, interact = INTERACT_BOUNCE_TOP },

    { key = "bully",   name = "a Bully",       model = E_MODEL_BULLY,
      radius = 73,  height = 123, down = 0,  hurtR = 63, hurtH = 113,
      damage = 1, interact = INTERACT_BULLY },
    { key = "swoop",   name = "a Swoop",       model = E_MODEL_SWOOP,
      radius = 100, height = 80,  down = 0,  hurtR = 70, hurtH = 70,
      damage = 1, interact = INTERACT_HIT_FROM_BELOW },
    { key = "spindrift", name = "a Spindrift", model = E_MODEL_SPINDRIFT,
      radius = 90,  height = 80,  down = 0,  hurtR = 80, hurtH = 70,
      damage = 2, interact = INTERACT_BOUNCE_TOP },
    { key = "snufit",  name = "a Snufit",      model = E_MODEL_SNUFIT,
      radius = 100, height = 60,  down = 0,  hurtR = 70, hurtH = 50,
      damage = 2, interact = INTERACT_HIT_FROM_BELOW },
    { key = "lakitu",  name = "an Enemy Lakitu", model = E_MODEL_ENEMY_LAKITU,
      radius = 50,  height = 50,  down = 0,  hurtR = 40, hurtH = 50,
      damage = 2, interact = INTERACT_HIT_FROM_BELOW },
    { key = "klepto",  name = "a Klepto",      model = E_MODEL_KLEPTO,
      radius = 160, height = 250, down = 0,  hurtR = 80, hurtH = 200,
      damage = 0, interact = INTERACT_HIT_FROM_BELOW },
    { key = "moneybag", name = "a Moneybag",   model = E_MODEL_MONEYBAG,
      radius = 120, height = 60,  down = 0,  hurtR = 100, hurtH = 50,
      damage = 2, interact = INTERACT_BOUNCE_TOP },

    { key = "wiggler", name = "a Wiggler",     model = E_MODEL_WIGGLER_HEAD,
      radius = 60,  height = 50,  down = 0,  hurtR = 30, hurtH = 40,
      damage = 3, interact = INTERACT_BOUNCE_TOP },
    { key = "skeeter", name = "a Skeeter",     model = E_MODEL_SKEETER,
      radius = 180, height = 100, down = 20, hurtR = 150, hurtH = 90,
      damage = 2, interact = INTERACT_BOUNCE_TOP },

    { key = "piano",   name = "a Mad Piano",   model = E_MODEL_MAD_PIANO,
      radius = 200, height = 150, down = 0,  hurtR = 200, hurtH = 150,
      damage = 3, interact = INTERACT_MR_BLIZZARD },
    { key = "chair",   name = "a Haunted Chair", model = E_MODEL_HAUNTED_CHAIR,
      radius = 50,  height = 50,  down = 0,  hurtR = 50, hurtH = 50,
      damage = 2, interact = INTERACT_MR_BLIZZARD },

    { key = "crate",   name = "a crate",       model = E_MODEL_BREAKABLE_BOX,
      radius = 90,  height = 60,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },

    { key = "mario",   name = "Mario",         model = E_MODEL_MARIO,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "luigi",   name = "Luigi",         model = E_MODEL_LUIGI,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "wario",   name = "Wario",         model = E_MODEL_WARIO,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "waluigi", name = "Waluigi",       model = E_MODEL_WALUIGI,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "toad",    name = "Toad",          model = E_MODEL_TOAD_PLAYER,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "peach",   name = "Peach",         model = E_MODEL_PEACH,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "yoshi",   name = "Yoshi",         model = E_MODEL_YOSHI,
      radius = 37,  height = 160, down = 0,  hurtR = 37, hurtH = 160,
      damage = 1, interact = INTERACT_BOUNCE_TOP },
    { key = "metalbox", name = "a metal box",  model = E_MODEL_METAL_BOX,
      radius = 90,  height = 90,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },

    { key = "coin",    name = "a coin",        model = E_MODEL_YELLOW_COIN,
      radius = 100, height = 64,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 1, interact = INTERACT_COIN },
    { key = "post",    name = "a wooden post", model = E_MODEL_WOODEN_POST,
      radius = 80,  height = 300, down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
    { key = "tree",    name = "a tree",        model = E_MODEL_BUBBLY_TREE,
      radius = 80,  height = 400, down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
    { key = "bubble",  name = "a bubble",      model = E_MODEL_BUBBLE,
      radius = 60,  height = 60,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },

    { key = "penguin", name = "a penguin",     model = E_MODEL_PENGUIN,
      radius = 40,  height = 40,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
    { key = "mips",    name = "a rabbit",      model = E_MODEL_MIPS,
      radius = 50,  height = 75,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },

    { key = "snowtree", name = "a snow tree",  model = E_MODEL_SNOW_TREE,
      radius = 80,  height = 400, down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
    { key = "sphere",  name = "a yellow ball", model = E_MODEL_YELLOW_SPHERE,
      radius = 60,  height = 60,  down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },

    { key = "dorrie",  name = "a Dorrie",      model = E_MODEL_DORRIE,
      radius = 0,   height = 0,   down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
    { key = "bowser",  name = "a Bowser",      model = E_MODEL_BOWSER,
      radius = 400, height = 400, down = 0,  hurtR = 0,  hurtH = 0,
      damage = 0, interact = 0 },
}

local DARK_MODELS = {}
for _, name in ipairs({

    "E_MODEL_BOO", "E_MODEL_BOO_CASTLE", "E_MODEL_BOWSER",
    "E_MODEL_MONEYBAG", "E_MODEL_PEACH", "E_MODEL_TOAD",
}) do
    local id = _G[name]
    if type(id) == "number" then DARK_MODELS[id] = true end
end
enemies.DARK_MODELS = DARK_MODELS

local FLAT_MODELS = {}
for _, name in ipairs({
    "E_MODEL_BUBBLY_TREE", "E_MODEL_SNOW_TREE", "E_MODEL_PALM_TREE",
    "E_MODEL_COURTYARD_SPIKY_TREE", "E_MODEL_MR_I", "E_MODEL_BOWLING_BALL",
    "E_MODEL_METALLIC_BALL", "E_MODEL_PURPLE_MARBLE", "E_MODEL_YELLOW_SPHERE",
}) do
    local id = _G[name]
    if type(id) == "number" then FLAT_MODELS[id] = true end
end
enemies.FLAT_MODELS = FLAT_MODELS

local HURT_STEPS = {
    { name = "as the game made them" },
    { name = "one wedge more",          add = 1 },
    { name = "two wedges more",         add = 2 },
    { name = "four wedges more",        add = 4 },
    { name = "one hit and you are out", add = 8 },
}

local SIZE_STEPS = {
    { name = "tiny",     scale = 0.4 },
    { name = "small",    scale = 0.7 },
    { name = "as the game made them", scale = 1.0 },
    { name = "big",      scale = 1.5 },
    { name = "huge",     scale = 2.2 },
    { name = "enormous", scale = 3.5 },
}

local TEMPER_STEPS = {
    { name = "statues",    freeze = true },
    { name = "terrified",  push = -22 },
    { name = "shy",        push = -9 },
    { name = "as the game made them" },
    { name = "bold",       push = 9 },
    { name = "relentless", push = 22 },
}

local REACH_STEPS = {
    { name = "arm's length",    units = 600 },
    { name = "a room away",     units = 1500 },
    { name = "far",             units = 3500 },
    { name = "the whole level", units = 20000 },
}

local BACK_STEPS = {
    { name = "gone for good" },
    { name = "at once",                  seconds = 0 },
    { name = "after five seconds",       seconds = 5 },
    { name = "after ten seconds",        seconds = 10 },
    { name = "after twenty seconds",     seconds = 20 },
    { name = "after forty-five seconds", seconds = 45 },
}

local SPEED_STEPS = {
    { name = "a crawl",       factor = 0.25 },
    { name = "half speed",    factor = 0.5 },
    { name = "as the game made them" },
    { name = "quick",         factor = 1.5 },
    { name = "twice as fast", factor = 2.0 },
    { name = "a blur",        factor = 3.0 },
    { name = "a bullet",      factor = 5.0 },
    { name = "not remotely fair", factor = 8.0 },
}

local MIRROR_STEPS = {
    { name = "off" },
    { name = "arm's length",     units = 500 },
    { name = "a room away",      units = 1200 },
    { name = "across the level", units = 4000 },
}

local MIRROR_WALK = 18

local function dress_steps()
    local steps = { { name = "as the game made them" } }
    for _, dress in ipairs(enemies.DRESSES) do
        table.insert(steps, { name = dress.name, dress = dress })
    end
    return steps
end

enemies.ROWS = {
    { key = "dress",    id = "dr", name = "Every enemy is",
      help = "model, hitbox, damage and all - a dress, not a behaviour swap",
      steps = dress_steps(), plain = 1 },
    { key = "temper",   id = "tp", name = "Temper",
      help = "what they do about you, from statues to relentless",
      steps = TEMPER_STEPS, plain = 4 },
    { key = "reach",    id = "rc", name = "How far they notice you",
      help = "how far the temper carries - the whole level never loses you",
      steps = REACH_STEPS, plain = 2 },

    { key = "speed",    id = "sp", name = "How fast they move",
      help = "everything that walks, swims or flies - not the ones circling a fixed spot",
      steps = SPEED_STEPS, plain = 3 },

    { key = "hurt",     id = "ht", name = "Enemy damage",
      help = "a wedge is one stop of the health meter",
      steps = HURT_STEPS, plain = 1, mine = true },
    { key = "bosshurt", id = "bh", name = "Boss damage",
      help = "the same ladder, for the seven the game calls a fight",
      steps = HURT_STEPS, plain = 1, mine = true },
    { key = "size",     id = "sz", name = "Enemy size",
      help = "the hitbox goes with it - nothing here is only a picture",
      steps = SIZE_STEPS, plain = 3 },

    { key = "back",     id = "bk", name = "Beaten enemies come back",
      help = "back where they fell, in every level the lobby is spread across",
      steps = BACK_STEPS, plain = 1 },
    { key = "mirror",   id = "mr", name = "They copy your stick",
      help = "within this far, an enemy walks where you are pushing",
      steps = MIRROR_STEPS, plain = 1 },
}

enemies.BY_KEY = {}
for _, row in ipairs(enemies.ROWS) do enemies.BY_KEY[row.key] = row end

local function parse()
    local text = gGlobalSyncTable[enemies.KEY]
    local set = {}
    if type(text) ~= "string" then return set end
    for id, step in string.gmatch(text, "(%a%a):(%d+)") do
        set[id] = tonumber(step)
    end
    return set
end

local function pack(set)
    local parts = {}
    for _, row in ipairs(enemies.ROWS) do
        local step = set[row.key]
        if step ~= nil and step ~= row.plain then
            table.insert(parts, row.id .. ":" .. tostring(step))
        end
    end
    return table.concat(parts, ",")
end

function enemies.text()
    local text = gGlobalSyncTable[enemies.KEY]
    return type(text) == "string" and text or ""
end

function enemies.put_text(text)
    if not OF.util.is_host() then return false end
    text = tostring(text or "")
    if enemies.text() == text then return false end
    return OF.util.publish(enemies.KEY, text) == true
end

function enemies.wire_width()
    local set = {}
    for _, row in ipairs(enemies.ROWS) do set[row.key] = #row.steps end
    return #pack(set)
end

local function round_asks_back()
    if not OF.util.asks(OF.lockdown, "round_refills_enemies") then return nil end
    local secs = OF.lockdown.round_refills_enemies()
    if type(secs) ~= "number" then return nil end
    for at, stop in ipairs(BACK_STEPS) do
        if stop.seconds == secs then return at end
    end
    return nil
end

enemies.round_asks_back = round_asks_back

local function round_has_the_room()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

enemies.round_has_the_room = round_has_the_room

function enemies.room_step(key)
    local row = enemies.BY_KEY[key]
    if row == nil then return 1 end

    if round_has_the_room() then

        if row.key == "back" then
            local asked = round_asks_back()
            if asked ~= nil then return asked end
        end
        return row.plain
    end

    return enemies.wanted_step(key)
end

function enemies.wanted_step(key)
    local row = enemies.BY_KEY[key]
    if row == nil then return 1 end
    local step = parse()[row.id]
    if type(step) ~= "number" then return row.plain end
    step = math.floor(step)
    if step < 1 then return 1 end
    if step > #row.steps then return #row.steps end
    return step
end

enemies.mine = enemies.mine or {}
enemies.mine_at = enemies.mine_at or {}

local function first_choice(row)
    if row.plain < #row.steps then return row.plain + 1 end
    if row.plain > 1 then return row.plain - 1 end
    return row.plain
end

function enemies.mine_state(key)
    local row = enemies.BY_KEY[key]
    if row == nil or not row.mine then return nil end
    local held = enemies.mine[key]
    if held == nil then return nil end
    local room = enemies.wanted_step(key)
    if held == false then

        if room == row.plain then return nil end
        return false
    end
    local at = enemies.mine_at[key] or first_choice(row)
    if at < 1 then at = 1 end
    if at > #row.steps then at = #row.steps end
    if at == room then return nil end
    return true
end

function enemies.settle_mine(key)
    if enemies.mine_state(key) == nil then
        enemies.mine[key] = nil
        enemies.mine_at[key] = nil
    end
end

function enemies.in_force(key, ignoreRound)
    local row = enemies.BY_KEY[key]
    if row == nil then return 1, false end
    if not ignoreRound and round_has_the_room() then
        return enemies.room_step(key), false
    end

    local state = enemies.mine_state(key)
    if state == true then
        local at = enemies.mine_at[key] or first_choice(row)
        if at < 1 then at = 1 end
        if at > #row.steps then at = #row.steps end
        return at, true
    end

    if state == false then return row.plain, true end
    return enemies.wanted_step(key), false
end

function enemies.step(key)
    return (enemies.in_force(key))
end

function enemies.step_is_yours(key)
    local _, mine = enemies.in_force(key)
    return mine
end

function enemies.suspended(key)
    if not round_has_the_room() then return false end
    return enemies.in_force(key, true) ~= enemies.step(key)
end

function enemies.stop(key)
    local row = enemies.BY_KEY[key]
    if row == nil then return nil end
    return row.steps[enemies.step(key)]
end

function enemies.stop_name(key)
    local stop = enemies.stop(key)
    return stop ~= nil and stop.name or "?"
end

function enemies.anything_on()
    for _, row in ipairs(enemies.ROWS) do
        if enemies.room_step(row.key) ~= row.plain then return true end
    end
    return false
end

function enemies.label()
    local said = {}
    for _, row in ipairs(enemies.ROWS) do
        local at = enemies.room_step(row.key)
        if at ~= row.plain then
            local stop = row.steps[at]
            table.insert(said, row.name .. ": "
                .. (stop ~= nil and stop.name or "?"))
        end
    end
    if #said == 0 then return OF.lang.t("the course as it was written") end
    return table.concat(said, ", ")
end

function enemies.set_step(key, step, quiet, askerLocal)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the enemies are.")
    end

    local row = enemies.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end

    step = math.floor(tonumber(step) or row.plain)
    if step < 1 then step = 1 end
    if step > #row.steps then step = #row.steps end

    if OF.util.asks(OF.chaos, "release_enemy") then OF.chaos.release_enemy(key) end

    local wasName = row.steps[enemies.wanted_step(key)] ~= nil
        and row.steps[enemies.wanted_step(key)].name or nil

    local set = {}
    for _, other in ipairs(enemies.ROWS) do
        set[other.key] = enemies.wanted_step(other.key)
    end
    set[key] = step

    if not OF.util.publish(enemies.KEY, pack(set)) then
        return false, OF.lang.t("That is too much to send to the lobby at once.")
    end

    if not quiet then

        local said = row.name .. ": " .. row.steps[step].name
        local who = OF.util.presser(askerLocal)
        if who == nil then

            OF.notify.send_all("@ - @", "info", 4,
                row.name, row.steps[step].name)
        else
            OF.notify.send_all("@ set @", "info", 4, who, said)
            OF.actionlog.by_hand(who, OF.lang.fill("set the enemies: @", said),
                wasName, row.steps[step].name)
        end
    end
    return true
end

function enemies.ask_step(key, step)
    if not OF.perms.can("speedrun") then
        return false, OF.util.RANK_REFUSAL, "speedrun"
    end
    if enemies.BY_KEY[key] == nil then return false, OF.lang.t("No such row.") end

    if OF.util.is_host() then return enemies.set_step(key, step, false, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("enemy", key, step)
    end
    return false, OF.lang.t("No host to ask yet - try again in a second.")
end

function enemies.set_here(asker, key, step)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the enemies are.")
    end
    if asker == nil then return false, OF.lang.t("Who asked?") end
    if OF.perms.tier(asker) < OF.perms.required("speedrun") then
        return false, OF.util.RANK_REFUSAL
    end

    return enemies.set_step(key, step, false, asker)
end

function enemies.next_step(key)
    local row = enemies.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end
    local step = enemies.wanted_step(key) + 1
    if step > #row.steps then step = 1 end
    return enemies.ask_step(key, step)
end

function enemies.clear(askerLocal)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the enemies are.")
    end
    if not enemies.anything_on() then
        return false, OF.lang.t("The enemies are already as the game made them.")
    end

    local wasLabel = enemies.label()
    if not OF.util.publish(enemies.KEY, "") then
        return false, OF.lang.t("That is too much to send to the lobby at once.")
    end
    local who = OF.util.presser(askerLocal)
    if who == nil then
        OF.notify.send_all("The enemies are as the game made them again",
            "info", 4)
    else
        OF.notify.send_all("@ put the enemies back as the game made them",
            "info", 4, who)
        OF.actionlog.by_hand(who,
            OF.lang.t("put the enemies back as the game made them"),
            wasLabel, nil)
    end
    return true
end

function enemies.ask_clear()
    if not OF.perms.can("speedrun") then
        return false, OF.util.RANK_REFUSAL, "speedrun"
    end
    if OF.util.is_host() then return enemies.clear(0) end

    if not enemies.anything_on() then
        return false, OF.lang.t("The enemies are already as the game made them.")
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("enemyclear")
    end
    return false, OF.lang.t("No host to ask yet - try again in a second.")
end

function enemies.clear_here(asker)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the enemies are.")
    end
    if asker == nil then return false, OF.lang.t("Who asked?") end
    if OF.perms.tier(asker) < OF.perms.required("speedrun") then
        return false, OF.util.RANK_REFUSAL
    end
    return enemies.clear(asker)
end

function enemies.set_mine(key, state)
    local row = enemies.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end

    if not row.mine then
        return false, OF.lang.t("That one is the lobby's - an enemy is one enemy.")
    end

    if state == nil then
        enemies.mine[key] = nil
        enemies.mine_at[key] = nil
    elseif state == false then
        enemies.mine[key] = false
    else
        enemies.mine[key] = true
        if enemies.mine_at[key] == nil then
            enemies.mine_at[key] = first_choice(row)
        end
    end
    enemies.settle_mine(key)

    enemies.forget_tune()
    return true
end

function enemies.set_mine_step(key, step)
    local row = enemies.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end
    if not row.mine then
        return false, OF.lang.t("That one is the lobby's - an enemy is one enemy.")
    end
    step = math.floor(tonumber(step) or row.plain)
    if step < 1 then step = 1 end
    if step > #row.steps then step = #row.steps end
    if step == row.plain then return enemies.set_mine(key, false) end
    enemies.mine[key] = true
    enemies.mine_at[key] = step
    enemies.settle_mine(key)
    enemies.forget_tune()
    return true
end

function enemies.mine_any()
    for _, row in ipairs(enemies.ROWS) do
        if row.mine and enemies.mine_state(row.key) ~= nil then return true end
    end
    return false
end

function enemies.forget_mine()
    enemies.mine = {}
    enemies.mine_at = {}
    enemies.forget_tune()
end

local function on_packet(data)
    if data == nil or data.ofp ~= enemies.PACKET then return end
    if not OF.util.from_host(data) then return end
    if data.what == "clear" then enemies.forget_mine() end
end

local held = {}

function enemies.held_count()
    local n = 0
    for _ in pairs(held) do n = n + 1 end
    return n
end

function enemies.forget_held()
    held = {}
end

local function follow(slot, now)
    if slot == nil or slot.wrote ~= now then return { base = now } end
    return slot
end

local take_turn_off

local function write_box(o, box, factor)
    o.hitboxRadius      = box.radius * factor
    o.hitboxHeight      = box.height * factor
    o.hitboxDownOffset  = box.down * factor
    o.hurtboxRadius     = box.hurtR * factor
    o.hurtboxHeight     = box.hurtH * factor
    o.oWallHitboxRadius = box.wall * factor
end

local function hand_back(o, record)
    if o == nil or record == nil then return end

    if record.damage ~= nil then o.oDamageOrCoinValue = record.damage.base end
    if record.interact ~= nil then o.oInteractType = record.interact.base end

    if record.opacity ~= nil then o.oOpacity = record.opacity.base end
    take_turn_off(o, record)
    if record.scale ~= nil then
        OF.util.optional("obj_scale", nil, o, record.scale.base)
    end
    if record.boxWritten and record.box ~= nil then write_box(o, record.box, 1) end
    if record.model ~= nil then
        OF.util.optional("obj_set_model_extended", nil, o, record.model)
    end

    held[o] = nil
end

enemies.hand_back = hand_back

local function flat_distance_squared(o, m)
    if o == nil or m == nil or m.pos == nil then return nil end
    local dx = (o.oPosX or 0) - m.pos.x
    local dz = (o.oPosZ or 0) - m.pos.z
    return dx * dx + dz * dz
end

local function target_of(o)
    local nearest = OF.util.optional("nearest_mario_state_to_object", nil, o)
    if nearest == nil or nearest.pos == nil then return nil end
    return nearest
end

local function wanted_push(o, tune)
    local m = target_of(o)
    if m == nil then return nil end

    local away = flat_distance_squared(o, m)
    if away == nil then return nil end

    if tune.mirror ~= nil and away < tune.mirror * tune.mirror then
        local mag = m.intendedMag or 0
        if mag > 1 then
            if mag > 32 then mag = 32 end
            return m.intendedYaw or 0, MIRROR_WALK * mag / 32
        end
    end

    if tune.push == nil then return nil end
    if away > tune.reach * tune.reach then return nil end

    local toPlayer = atan2s(m.pos.z - (o.oPosZ or 0), m.pos.x - (o.oPosX or 0))
    if tune.push < 0 then return toPlayer + 0x8000, -tune.push end
    return toPlayer, tune.push
end

local function steer(o, tune)
    local yaw, step = wanted_push(o, tune)
    if yaw == nil or step == nil or step == 0 then return false end

    o.oMoveAngleYaw = yaw
    o.oFaceAngleYaw = yaw
    o.oPosX = (o.oPosX or 0) + step * sins(yaw)
    o.oPosZ = (o.oPosZ or 0) + step * coss(yaw)

    OF.util.optional("cur_obj_resolve_wall_collisions", nil)
    return true
end

local SPEED_SLIDE = 22

local SPEED_HOPS = 4

local function hurry(o, factor)
    if factor == nil or factor == 1 then return false end

    local vx = o.oVelX or 0
    local vz = o.oVelZ or 0
    if vx == 0 and vz == 0 then return false end

    local extra = factor - 1
    local dx = vx * extra
    local dz = vz * extra

    if extra < 0 then
        o.oPosX = (o.oPosX or 0) + dx
        o.oPosZ = (o.oPosZ or 0) + dz
        OF.util.optional("cur_obj_resolve_wall_collisions", nil)
        return true
    end

    local far = math.sqrt(dx * dx + dz * dz)

    local hops = 1
    if far > SPEED_SLIDE then
        hops = math.ceil(far / SPEED_SLIDE)
        if hops > SPEED_HOPS then hops = SPEED_HOPS end
        local reach = SPEED_SLIDE * hops
        if far > reach then
            dx = dx * reach / far
            dz = dz * reach / far
        end
    end

    local stepX = dx / hops
    local stepZ = dz / hops
    for _ = 1, hops do
        o.oPosX = (o.oPosX or 0) + stepX
        o.oPosZ = (o.oPosZ or 0) + stepZ

        OF.util.optional("cur_obj_resolve_wall_collisions", nil)
    end
    return true
end

local tuned = nil
local tunedFrame = -1

local function tune_now()
    local dressStop = enemies.stop("dress")
    local temperStop = enemies.stop("temper")
    local sizeStop = enemies.stop("size")
    local mirrorStop = enemies.stop("mirror")
    local reachStop = enemies.stop("reach")
    local speedStop = enemies.stop("speed")

    return {
        dress  = dressStop ~= nil and dressStop.dress or nil,
        push   = temperStop ~= nil and temperStop.push or nil,
        freeze = temperStop ~= nil and temperStop.freeze == true,
        reach  = reachStop ~= nil and reachStop.units or REACH_STEPS[2].units,
        scale  = sizeStop ~= nil and sizeStop.scale or 1,

        speed  = speedStop ~= nil and speedStop.factor or 1,
        mirror = mirrorStop ~= nil and mirrorStop.units or nil,
        hurt   = enemies.stop("hurt"),
        boss   = enemies.stop("bosshurt"),

        back   = enemies.stop("back"),
    }
end

function enemies.tune()
    local frame = get_global_timer ~= nil and get_global_timer() or 0
    if tuned == nil or frame ~= tunedFrame then
        tuned = tune_now()
        tunedFrame = frame
    end
    return tuned
end

function enemies.forget_tune()
    tuned = nil
    tunedFrame = -1
end

function enemies.scaled_damage(base, stop)
    if stop == nil or base == 0 or stop.add == nil then return base end
    return math.floor(base + stop.add)
end

local function wear_size(o, record, factor)
    local scale = o.header ~= nil and o.header.gfx ~= nil
        and o.header.gfx.scale or nil
    if scale == nil then return record end

    record.scale = follow(record.scale, scale.x or 1)
    local wanted = record.scale.base * factor
    OF.util.optional("obj_scale", nil, o, wanted)
    record.scale.wrote = wanted
    return record
end

local function render_node(o)
    local header = o ~= nil and o.header or nil
    local gfx = header ~= nil and header.gfx or nil
    return gfx ~= nil and gfx.node or nil
end

local function drop_flag(node, flag)
    if type(node.flags) ~= "number" then return end
    if OF.util.has_flag(node.flags, flag) then node.flags = node.flags - flag end
end

local function wear_light(o, record, dress)
    if not DARK_MODELS[dress.model] then
        if record.opacity ~= nil then
            o.oOpacity = record.opacity.base
            record.opacity = nil
        end
        return record
    end
    record.opacity = follow(record.opacity, o.oOpacity or 0)
    if o.oOpacity ~= 255 then o.oOpacity = 255 end
    record.opacity.wrote = 255
    return record
end

local function turn_flat(o, record, dress)
    local node = render_node(o)
    if node == nil then return record end

    if not FLAT_MODELS[dress.model] then return take_turn_off(o, record) end

    if record.turn == nil then
        record.turn = {
            billboard = OF.util.has_flag(node.flags, GRAPH_RENDER_BILLBOARD),
            cylboard  = OF.util.has_flag(node.flags, GRAPH_RENDER_CYLBOARD),
        }
    end

    local upright = OF.util.asks(OF.costumes, "vanilla_turn")
        and OF.costumes.vanilla_turn() == true
    if upright then
        drop_flag(node, GRAPH_RENDER_BILLBOARD)
        OF.util.optional("obj_set_cylboard", nil, o)
    else
        drop_flag(node, GRAPH_RENDER_CYLBOARD)
        OF.util.optional("obj_set_billboard", nil, o)
    end
    return record
end

function take_turn_off(o, record)
    if record == nil or record.turn == nil then return record end
    local was = record.turn
    record.turn = nil

    local node = render_node(o)
    if node == nil or type(node.flags) ~= "number" then return record end
    drop_flag(node, GRAPH_RENDER_BILLBOARD)
    drop_flag(node, GRAPH_RENDER_CYLBOARD)
    if was.billboard then OF.util.optional("obj_set_billboard", nil, o) end
    if was.cylboard then OF.util.optional("obj_set_cylboard", nil, o) end
    return record
end

local function wear_dress(o, record, dress)
    local now = OF.util.optional("obj_get_model_id_extended", nil, o)
    if record.model == nil and now ~= nil then record.model = now end
    if now ~= dress.model then
        OF.util.optional("obj_set_model_extended", nil, o, dress.model)
    end

    record.interact = follow(record.interact, o.oInteractType or 0)
    o.oInteractType = dress.interact
    record.interact.wrote = dress.interact

    record = wear_light(o, record, dress)
    record = turn_flat(o, record, dress)
    return record
end

local function take_dress_off(o, record)
    if record.interact ~= nil then
        o.oInteractType = record.interact.base
        record.interact = nil
    end
    if record.opacity ~= nil then
        o.oOpacity = record.opacity.base
        record.opacity = nil
    end
    take_turn_off(o, record)
    if record.model ~= nil then
        OF.util.optional("obj_set_model_extended", nil, o, record.model)
        record.model = nil
    end
end

function enemies.tune_object(o, entry)
    if o == nil or entry == nil or o.activeFlags == 0 then return false end

    local tune = enemies.tune()
    local record = held[o]

    local wantsDress = tune.dress ~= nil
    local wantsSize  = tune.scale ~= 1
    local hurtStop   = entry.boss and tune.boss or tune.hurt
    local wantsHurt  = hurtStop ~= nil and hurtStop.add ~= nil
    local wantsMove  = tune.push ~= nil or tune.freeze or tune.mirror ~= nil
        or tune.speed ~= 1

    if not (wantsDress or wantsSize or wantsHurt or wantsMove) then
        if record ~= nil then hand_back(o, record) end
        return false
    end

    if record ~= nil and record.what ~= entry.key then
        held[o] = nil
        record = nil
    end
    if record == nil then
        record = {
            what = entry.key,

            box = {
                radius = o.hitboxRadius or 0,
                height = o.hitboxHeight or 0,
                down   = o.hitboxDownOffset or 0,
                hurtR  = o.hurtboxRadius or 0,
                hurtH  = o.hurtboxHeight or 0,
                wall   = o.oWallHitboxRadius or 0,
            },
        }
        held[o] = record
    end

    if wantsDress then
        record = wear_dress(o, record, tune.dress)
    elseif record.model ~= nil or record.interact ~= nil then
        take_dress_off(o, record)
    end

    if wantsSize then
        record = wear_size(o, record, tune.scale)
    elseif record.scale ~= nil then
        OF.util.optional("obj_scale", nil, o, record.scale.base)
        record.scale = nil
    end

    local factor = wantsSize and tune.scale or 1
    if wantsDress then
        write_box(o, {
            radius = tune.dress.radius, height = tune.dress.height,
            down = tune.dress.down, hurtR = tune.dress.hurtR,
            hurtH = tune.dress.hurtH, wall = record.box.wall,
        }, factor)
        record.boxWritten = true
    elseif wantsSize then
        write_box(o, record.box, factor)
        record.boxWritten = true
    elseif record.boxWritten then
        write_box(o, record.box, 1)
        record.boxWritten = nil
    end

    if wantsHurt or wantsDress then
        record.damage = follow(record.damage, o.oDamageOrCoinValue or 0)
        local from = wantsDress and tune.dress.damage or record.damage.base
        local value = wantsHurt and enemies.scaled_damage(from, hurtStop) or from
        o.oDamageOrCoinValue = value
        record.damage.wrote = value
    elseif record.damage ~= nil then
        o.oDamageOrCoinValue = record.damage.base
        record.damage = nil
    end

    if tune.freeze then

        hurry(o, 0)
        o.oForwardVel = 0
        o.oVelX = 0
        o.oVelZ = 0
    elseif wantsMove then

        hurry(o, tune.speed)
        steer(o, tune)
    end

    return true
end

enemies.queue = {}

enemies.MOST_OWED = 40

enemies.refused = 0

enemies.MOST_AT_ONCE = 4

function enemies.forget_queue()
    enemies.queue = {}
    enemies.refused = 0
end

function enemies.owed()
    return #enemies.queue
end

local function frames_from_now(seconds)
    local now = get_global_timer ~= nil and get_global_timer() or 0
    return now + math.floor(seconds * 60)
end

local function where_we_are()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil, nil end
    return np.currLevelNum, np.currAreaIndex
end

local function my_place()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil, nil, nil end
    return np.currLevelNum, np.currAreaIndex, np.globalIndex
end

function enemies.mine_to_put_back()
    local level, area, me = my_place()
    if level == nil or me == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        if np ~= nil and np.currLevelNum == level
            and np.currAreaIndex == area
            and type(np.globalIndex) == "number"
            and np.globalIndex < me then
            return false
        end
    end
    return true
end

local KOOPA_THE_QUICK_FIRST = 2
local KOOPA_THE_QUICK_LAST = 3

function enemies.is_a_person(o, entry)
    if o == nil or entry == nil then return false end
    if entry.key ~= "koopa" then return false end
    local byte = o.oBehParams2ndByte
    if type(byte) ~= "number" then return false end
    return byte >= KOOPA_THE_QUICK_FIRST and byte <= KOOPA_THE_QUICK_LAST
end

function enemies.remember_fallen(o, entry)
    if o == nil or entry == nil or entry.boss then return false end
    if enemies.is_a_person(o, entry) then return false end
    if not enemies.mine_to_put_back() then return false end

    local stop = enemies.tune().back
    if stop == nil or stop.seconds == nil then return false end

    if #enemies.queue >= enemies.MOST_OWED then
        enemies.refused = enemies.refused + 1
        return false
    end

    local level, area = where_we_are()
    table.insert(enemies.queue, {
        bhv = entry.bhv,

        model = entry.model,
        x = o.oPosX or 0, y = o.oPosY or 0, z = o.oPosZ or 0,
        due = frames_from_now(stop.seconds),

        level = level, area = area,
    })
    return true
end

function enemies.put_back_due()
    if #enemies.queue == 0 then return 0 end
    if not enemies.mine_to_put_back() then return 0 end

    local now = get_global_timer ~= nil and get_global_timer() or 0
    local level, area = where_we_are()

    local waiting = {}
    local put = 0
    for _, owed in ipairs(enemies.queue) do
        if owed.level ~= level or owed.area ~= area then

            owed.due = nil
        elseif owed.due <= now and put < enemies.MOST_AT_ONCE then
            if OF.util.optional("spawn_sync_object", nil, owed.bhv, owed.model,
                owed.x, owed.y, owed.z, nil) ~= nil then
                put = put + 1
            end
        else
            table.insert(waiting, owed)
        end
    end
    enemies.queue = waiting
    return put
end

function enemies.build_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(OF.lang.fill("Now: @", enemies.label())))
    table.insert(rows, panel.label_row(
        OF.lang.t("These reach the course itself, on every machine at once.")))

    table.insert(rows, panel.label_row(OF.lang.t(
        "Enemy damage and Boss damage carry a box of your own. The rest are "
        .. "the lobby's: an enemy has one size and one place it is standing.")))

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        local said = "A round has the course - the lobby's own come back after it."
        if round_asks_back() ~= nil then
            said = "This round asks for beaten enemies back - the lobby's own come back after it."
        end
        table.insert(rows, panel.label_row(OF.lang.t(said)))
    end

    table.insert(rows, panel.gated_row("speedrun",
        OF.lang.t("Put the course back as it was"), 255, 140, 90,
        function() OF.util.report(enemies.ask_clear()) end))

    for _, row in ipairs(enemies.ROWS) do
        local key = row.key
        local step, yours = enemies.in_force(key)

        local help = OF.lang.t(row.help)

        if not row.mine then

            local text = row.name .. ": " .. row.steps[step].name

            local built = panel.with_help(panel.gated_row("speedrun", text,
                255, 255, 255,
                function() OF.util.report(enemies.next_step(key)) end), help)

            built = panel.with_slider(built, step - 1, #row.steps - 1,
                function(wanted)
                    OF.util.report(enemies.ask_step(key, wanted + 1))
                end)
            table.insert(rows, built)
        else

            local roomAt = enemies.wanted_step(key)
            local roomOn = roomAt ~= row.plain
            local mine = enemies.mine_state(key)

            if enemies.suspended(key) then
                help = OF.lang.t(
                    "Put away until the round ends - your setting is kept.")
            end

            local built = panel.with_help(panel.two_box({
                lobbyOn = roomOn,

                mineBox = panel.mine_shown(mine, roomOn),
                name = OF.lang.t(row.name),
                lobbyNeed = "speedrun",

                mineNeed = "powerup_self",
                r = 255, g = 255, b = 255,
                onLobby = function()
                    OF.util.report(enemies.next_step(key))
                end,

                onMine = function()

                    local mineAt = enemies.in_force(key, true)
                    local want = panel.next_mine_level(mine,
                        mineAt - row.plain,
                        #row.steps - row.plain, roomAt - row.plain)
                    if want == nil then
                        OF.util.report(enemies.set_mine(key, nil))
                        return
                    end
                    OF.util.report(enemies.set_mine_step(key, want + row.plain))
                end,
            }), help)

            local column = nil
            if step ~= row.plain then
                column = panel.two_box_level(
                    OF.lang.t(row.steps[step].name), yours)
            elseif mine == false then

                column = panel.two_box_level(
                    OF.lang.t(row.steps[row.plain].name), true)
            end
            built = panel.level_right(built, column ~= nil, column)

            local dialsRoom = (mine == nil) and panel.may("speedrun")
            local need = dialsRoom and "speedrun" or "powerup_self"
            local at = dialsRoom and roomAt or step
            if panel.may(need) then
                built = panel.with_slider(built, at - 1, #row.steps - 1,
                    function(wanted)
                        if dialsRoom then
                            OF.util.report(enemies.ask_step(key, wanted + 1))
                        else
                            OF.util.report(
                                enemies.set_mine_step(key, wanted + 1))
                        end
                    end)
            else

                built = panel.with_slider(built, at - 1, #row.steps - 1, nil)
            end
            table.insert(rows, built)
        end
    end

    local owed = enemies.owed()
    if owed > 0 then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "Waiting to come back: @", tostring(owed))))
    end
    if enemies.refused > 0 then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "Turned away: @, the course was already owed @",
            tostring(enemies.refused), tostring(enemies.MOST_OWED))))
    end

    table.insert(rows, panel.back_row())
    return rows
end

hook_on_sync_table_change(gGlobalSyncTable, "ofEnemy", "enemies", function()
    if OF.util.asks(OF.guard, "repair") then OF.guard.repair("ofEnemy") end
    enemies.forget_tune()
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.enemies == nil then
        panel.PAGES.enemies = {
            title = "The enemies", tab = "room", up = "roomrules",
            build = function() return enemies.build_page(panel) end,
        }
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    enemies.forget_held()
    enemies.forget_queue()
    enemies.forget_tune()
end)

hook_event(HOOK_UPDATE, function()
    enemies.put_back_due()
end)

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet)

hook_event(HOOK_ON_OBJECT_UNLOAD, function(o)
    if o == nil then return end
    held[o] = nil

    local stop = enemies.tune().back
    if stop == nil or stop.seconds == nil then return end
    for _, entry in ipairs(enemies.ROSTER) do
        if entry.bhv ~= nil and not entry.boss then
            local yes = OF.util.optional("obj_has_behavior_id", 0, o, entry.bhv)
            if yes ~= nil and yes ~= 0 and yes ~= false then
                enemies.remember_fallen(o, entry)
                return
            end
        end
    end
end)

enemies.installed = {}

for _, entry in ipairs(enemies.ROSTER) do
    if entry.bhv ~= nil then
        local mine = entry
        local loop = function(o) enemies.tune_object(o, mine) end
        if at_load("hook_behavior", entry.bhv, entry.list, false, nil, loop)
            ~= nil then
            table.insert(enemies.installed, entry.key)
        end
    end
end

function enemies.count()
    return #enemies.installed
end
