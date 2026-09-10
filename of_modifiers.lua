OF = OF or {}
OF.modifiers = OF.modifiers or {}

local modifiers = OF.modifiers

modifiers.PACKET = "mods"
local NO_FOV      = 0
local NO_SKYBOX   = -1
local NO_ENVFX    = ENVFX_MODE_NO_OVERRIDE or -1

local FOG_LEVELS = {
    [LEVEL_BOB] = true, [LEVEL_HMC] = true, [LEVEL_JRB] = true,
    [LEVEL_LLL] = true, [LEVEL_SSL] = true, [LEVEL_TTM] = true,
    [LEVEL_TTC] = true, [LEVEL_PSS] = true, [LEVEL_COTMC] = true,
    [LEVEL_CASTLE] = true, [LEVEL_BOWSER_1] = true, [LEVEL_BOWSER_2] = true,
}

local function fog_multiplier()
    return modifiers.setting("fog", "fogx", 118) / 100
end

local FOG_GREY = { r = 150, g = 152, b = 160 }
local FULL     = 255

local function fog_tint()
    local hue = modifiers.setting("fog", "hue", nil)
    if hue == nil then return FOG_GREY.r, FOG_GREY.g, FOG_GREY.b end
    return hue[1], hue[2], hue[3]
end

function modifiers.fog_is_real(levelNum)
    return FOG_LEVELS[levelNum] == true
end

local lastFogWasReal = nil

function modifiers.forget_fog_notice()
    lastFogWasReal = nil
end

local FOG_THICKEST = 1.40

function modifiers.set_fog(amount)
    amount = OF.util.clamp(amount or 0, 0, 1)

    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    local real = modifiers.fog_is_real(here)
    if lastFogWasReal ~= real then
        lastFogWasReal = real
        if not real and amount > 0 then

            OF.notify.show(
                "No fog in this level - only twelve have it. Nothing changed.",
                "info", 7)
        end
    end

    if not real then
        OF.util.optional("set_fog_intensity", nil, 1.0)
        for index = 0, 2 do
            OF.util.optional("set_fog_color", nil, index, FULL)
            OF.util.optional("set_skybox_color", nil, index, FULL)
        end
        return
    end

    local tintR, tintG, tintB = fog_tint()
    OF.util.optional("set_fog_color", nil, 0, tintR)
    OF.util.optional("set_fog_color", nil, 1, tintG)
    OF.util.optional("set_fog_color", nil, 2, tintB)
    OF.util.optional("set_fog_intensity", nil, 1.0 + (FOG_THICKEST - 1.0) * amount)

    local tint = { tintR, tintG, tintB }
    for index = 0, 2 do
        OF.util.optional("set_skybox_color", nil, index,
            math.floor(FULL - (FULL - tint[index + 1]) * amount))
    end

end

function modifiers.apply_fog()
    modifiers.set_fog((fog_multiplier() - 1.0) / (FOG_THICKEST - 1.0))
end

function modifiers.fog_step(name)
    local entry = modifiers.BY_KEY["fog"]
    for _, step in ipairs(entry ~= nil and entry.levels or {}) do
        if step.name == name and step.fogx ~= nil then
            return OF.util.clamp((step.fogx / 100 - 1.0) / (FOG_THICKEST - 1.0),
                0, 1)
        end
    end

    return 1
end

local ownsLighting = false
local saidLightingTaken = false

function modifiers.set_lighting(r, g, b)
    r = math.floor(OF.util.clamp(r or 127, 0, 255))
    g = math.floor(OF.util.clamp(g or r, 0, 255))
    b = math.floor(OF.util.clamp(b or r, 0, 255))

    if not ownsLighting then
        if OF.util.optional("le_is_enabled", false)
            and modifiers.lantern_count() == 0 then
            if not saidLightingTaken then
                saidLightingTaken = true
                OF.notify.show("Another mod owns the lighting - darkness is off",
                    "warn", 5)
            end
            return false
        end
        ownsLighting = true
    end

    OF.util.optional("le_set_ambient_color", nil, r, g, b)
    return true
end

function modifiers.set_dark(grey)
    grey = OF.util.clamp(grey or 127, 0, 255)
    return modifiers.set_lighting(grey, grey, grey)
end

function modifiers.clear_dark()
    if not ownsLighting then return false end
    ownsLighting = false
    saidLightingTaken = false

    OF.util.optional("le_set_ambient_color", nil, 127, 127, 127)

    if modifiers.lantern_count() == 0 then
        OF.util.optional("le_set_enabled", nil, false)
    end
    return true
end

function modifiers.owns_lighting()
    return ownsLighting
end

function modifiers.clear_fog()

    lastFogWasReal = nil

    for index = 0, 2 do
        OF.util.optional("set_fog_color", nil, index, FULL)
        OF.util.optional("set_skybox_color", nil, index, FULL)
    end
    OF.util.optional("set_fog_intensity", nil, 1.0)
end

local HIGH_WATER = 1200
local DEEP_WATER = 3000
local DROWNED_WATER = 6000

local LOW_WATER = 1500
local GONE_WATER = 9000

local MAX_REGIONS = 20

local borrowed = {}

local function water_place()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if type(np.currLevelNum) ~= "number" then return nil end
    if type(np.currAreaIndex) ~= "number" then return nil end
    return np.currLevelNum, np.currAreaIndex
end

local function borrowed_at(level, area)
    local rooms = borrowed[level]
    if rooms == nil then return nil end
    return rooms[area]
end

local function region_is_there(index)
    local here = get_water_level(index)
    if type(here) ~= "number" then return false end
    if gLevelValues ~= nil and here == gLevelValues.floorLowerLimit then
        return false
    end
    return true
end

local function water_is_ours()
    if not region_is_there(0) then return false end

    local m = gMarioStates[0]
    if m ~= nil and find_poison_gas_level ~= nil and gLevelValues ~= nil then

        modifiers.gasHushed = true
        local ok, gas = pcall(find_poison_gas_level, m.pos.x, m.pos.z)
        modifiers.gasHushed = false
        if ok and gas ~= nil and gas > gLevelValues.floorLowerLimit then
            return false
        end
    end

    return true
end

local function raise_water(by)
    if not water_is_ours() then return end
    local level, area = water_place()
    if level == nil then return end

    local record = borrowed_at(level, area)
    if record == nil then

        record = {}
        local found = false
        for index = 0, MAX_REGIONS - 1 do
            if region_is_there(index) then
                record[index] = get_water_level(index)
                found = true
            end
        end

        if not found then return end
        local rooms = borrowed[level]
        if rooms == nil then
            rooms = {}
            borrowed[level] = rooms
        end
        rooms[area] = record
    end

    local bottom = nil
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end

    for index, base in pairs(record) do

        local wanted = base + by
        if bottom ~= nil and wanted <= bottom then wanted = bottom + 1 end

        set_water_level(index, wanted, false)
    end
end

local function restore_water()
    local level, area = water_place()
    if level == nil then return end
    local record = borrowed_at(level, area)
    if record == nil then return end
    for index, base in pairs(record) do
        set_water_level(index, base, false)
    end
    borrowed[level][area] = nil
    if next(borrowed[level]) == nil then borrowed[level] = nil end
end

hook_event(HOOK_ON_LEVEL_INIT, function() restore_water() end)

hook_event(HOOK_ON_EXIT, function() restore_water() end)

modifiers.water_baselines = function(level, area)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    local copy = {}
    for index, base in pairs(record) do copy[index] = base end
    return copy
end

modifiers.water_baseline = function(level, area, region)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    return record[region or 0]
end

function modifiers.water_note()
    if modifiers.level("water") <= 0 then return nil end
    if water_is_ours() then return nil end

    return OF.lang.t("No water in this level to move.")
end

local function round_owns(subject)
    if type(subject) ~= "string" or subject == "" then return false end
    if not OF.util.asks(OF.gamemodes, "is_running") then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    if not OF.gamemodes.is_running() then return false end
    local mode = OF.gamemodes.current()
    if mode == nil then return false end
    return mode["uses" .. subject:sub(1, 1):upper() .. subject:sub(2)] == true
end

modifiers.round_owns = round_owns

local function water_is_the_rounds()
    return round_owns("water")
end

modifiers.water_is_the_rounds = water_is_the_rounds

function modifiers.dry_note()
    if modifiers.level("dry") <= 0 then return nil end
    if water_is_the_rounds() then
        return OF.lang.t("The round owns the water - this is standing down.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water in this level to walk through.")
end

local TRUE_SWIM = 2

function modifiers.swim_note()
    local level = modifiers.level("swim")
    if level <= 0 then return nil end
    if level >= TRUE_SWIM then
        return OF.lang.t("No water needed, and no way out until this is off.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water in this level to swim out of - try the next stop.")
end

function modifiers.true_swim_on()
    return modifiers.level("swim") >= TRUE_SWIM
end

hook_event(HOOK_ALLOW_FORCE_WATER_ACTION, function(m, isInWaterAction)
    if m == nil or m.playerIndex ~= 0 then return end

    if isInWaterAction then

        if modifiers.level("swim") <= 0 then return end

        if modifiers.true_swim_on() then return false end

        local probe = m.pos.y + 1.5
        probe = (probe >= 0) and math.floor(probe) or math.ceil(probe)

        if OF.util.has_flag(m.input, INPUT_A_PRESSED)
            and m.pos.y <= m.waterLevel - 80
            and probe >= m.waterLevel - 80
            and m.faceAngle.x >= 0
            and m.controller.stickY < -60 then
            return
        end

        if m.waterLevel - 80 <= m.floorHeight then return end

        return false
    end

    if modifiers.level("dry") <= 0 then return end
    if water_is_the_rounds() then return end

    return false
end)

local trueSwimHealth = nil
local trueSwimHurt = nil

local function group_of(action)
    if type(action) ~= "number" or ACT_GROUP_MASK == nil then return nil end
    return action & ACT_GROUP_MASK
end

modifiers.action_group = group_of

function modifiers.drop_the_swim()
    local m = gMarioStates[0]
    if m == nil or set_mario_action == nil then return false end
    if group_of(m.action or 0) ~= ACT_GROUP_SUBMERGED then return false end

    if m.waterLevel ~= nil and m.pos ~= nil
        and m.pos.y <= m.waterLevel - 80 then return false end
    set_mario_action(m, ACT_FREEFALL, 0)
    return true
end

local function true_swim_before(m)
    if m == nil or m.playerIndex ~= 0 then return end
    trueSwimHealth = nil
    trueSwimHurt = nil
    if not modifiers.true_swim_on() then return end
    if set_mario_action == nil then return end

    trueSwimHealth = m.health
    trueSwimHurt = m.hurtCounter or 0

    if not OF.util.can_play(0) then return end
    local group = group_of(m.action or 0)
    if group == nil then return end
    if group == ACT_GROUP_CUTSCENE then return end
    if group == ACT_GROUP_SUBMERGED then return end
    if m.action == ACT_BUBBLED then return end

    set_mario_action(m, ACT_WATER_IDLE, 0)
end

local function true_swim_after(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not modifiers.true_swim_on() then return end
    if trueSwimHealth == nil then return end
    if trueSwimHurt ~= 0 then return end

    if OF.util.has_flag(m.input or 0, INPUT_IN_POISON_GAS) then return end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return end
    if m.health >= trueSwimHealth then return end
    m.health = trueSwimHealth
end

modifiers.true_swim_before = true_swim_before
modifiers.true_swim_after = true_swim_after

hook_event(HOOK_BEFORE_MARIO_UPDATE, true_swim_before)
hook_event(HOOK_MARIO_UPDATE, true_swim_after)

function modifiers.gates_note()
    if modifiers.level("gates") <= 0 then return nil end
    return OF.lang.t("Only the courtyard Boo changes now.")
end

modifiers.LIST = {

    {

        key = "lowgrav", id = "lg", name = "Everybody's gravity",
        blurb = "lighter than the moon, or heavier than lead",

        levels = {
            { name = "light", fall = 0.72 },
            { name = "floaty", fall = 0.55 },
            { name = "the moon", fall = 0.33 },

            { name = "a little heavy", fall = 1.30 },
            { name = "like lead", fall = 1.80 },

            { name = "a dropped anvil", fall = 2.60 },
        },
    },

    {
        key = "upsidedown", id = "ud", name = "Upside down",
        blurb = "everybody falls towards the ceiling",
        levels = {
            { name = "on" },
        },
        world = function()
            if not OF.util.asks(OF.warp, "direction_index") then return end
            OF.warp.set("direction", OF.warp.direction_index("up"))
        end,
        restore = function()
            if not OF.util.asks(OF.warp, "direction_index") then return end
            OF.warp.set("direction", OF.warp.direction_index("down"))
        end,
    },
    {
        key = "giant", id = "gi", name = "Everybody is giant",
        blurb = "everyone is enormous",
        excludes = { "tiny" },
        levels = {
            { name = "big", scale = 1.8 },
            { name = "huge", scale = 2.6 },
            { name = "absurd", scale = 3.6 },

            { name = "a kaiju", scale = 5.0 },
        },
        world = function() OF.cheats.apply_scale() end,
        restore = function() OF.cheats.apply_scale() end,
    },
    {
        key = "tiny", id = "ty", name = "Everybody is tiny",
        blurb = "everyone is a thimble",
        excludes = { "giant" },
        levels = {
            { name = "small", scale = 0.45 },
            { name = "tiny", scale = 0.28 },
            { name = "a crumb", scale = 0.15 },

            { name = "a grain of sand", scale = 0.08 },
        },
        world = function() OF.cheats.apply_scale() end,
        restore = function() OF.cheats.apply_scale() end,
    },

    {
        key = "night", id = "sk", name = "The sky",
        blurb = "somebody else's weather, everywhere",
        levels = {
            { name = "haunted", sky = BACKGROUND_HAUNTED },
            { name = "on fire", sky = BACKGROUND_FLAMING_SKY },
            { name = "underwater", sky = BACKGROUND_UNDERWATER_CITY },
            { name = "above the clouds", sky = BACKGROUND_ABOVE_CLOUDS },
            { name = "desert", sky = BACKGROUND_DESERT },
            { name = "green", sky = BACKGROUND_GREEN_SKY },
            { name = "purple", sky = BACKGROUND_PURPLE_SKY },

            { name = "at sea", sky = BACKGROUND_OCEAN_SKY },
            { name = "below the clouds", sky = BACKGROUND_BELOW_CLOUDS },
            { name = "snowy peaks", sky = BACKGROUND_SNOW_MOUNTAINS },
        },
        world = function()
            set_override_skybox(modifiers.setting("night", "sky", BACKGROUND_HAUNTED))
        end,
        restore = function() set_override_skybox(NO_SKYBOX) end,
    },

    {
        key = "sun", id = "su", name = "The hour",
        blurb = "where the light comes from, so the shading turns with it",
        levels = {
            { name = "early, from the east", dir = { 0.9, 0.35, 0.1 } },
            { name = "overhead", dir = { 0, 1, 0 } },
            { name = "late, from the west", dir = { -0.9, 0.35, -0.1 } },

            { name = "from underneath", dir = { 0, -1, 0 } },

            { name = "the day going by", hours = true },

            { name = "from the north", dir = { 0.1, 0.4, 0.9 } },
            { name = "low and behind", dir = { 0, 0.15, -1.0 } },

            { name = "from the south", dir = { -0.1, 0.4, -0.9 } },
            { name = "flat on from the east", dir = { 1.0, 0.05, 0 } },
            { name = "flat on from the west", dir = { -1.0, 0.05, 0 } },
        },
        note = function() return modifiers.sun_note() end,
        world = function()
            local dir = modifiers.setting("sun", "dir", nil)
            if dir ~= nil then modifiers.wear_sun(dir) end
        end,
        restore = function() modifiers.wear_sun(nil) end,
    },

    {
        key = "dark", id = "dk", name = "Darkness",
        blurb = "the light goes out of the world itself",

        levels = {
            { name = "dusk",  grey = 100 },
            { name = "night", grey = 70 },
            { name = "pitch", grey = 45 },
            { name = "a red night",  light = { 110, 45, 45 } },
            { name = "a green murk", light = { 50, 100, 60 } },
            { name = "a cold blue",  light = { 50, 70, 115 } },
            { name = "sodium dusk",  light = { 120, 85, 40 } },

            { name = "a purple hour", light = { 95, 55, 120 } },
            { name = "hospital light", light = { 105, 125, 105 } },
            { name = "under water", light = { 45, 85, 105 } },
        },
        note = function() return modifiers.dark_note() end,
        world = function(level)

            local rgb = modifiers.setting("dark", "light", nil)
            if rgb ~= nil then
                modifiers.set_lighting(rgb[1], rgb[2], rgb[3])
            else
                modifiers.set_dark(modifiers.setting("dark", "grey", 100))
            end
        end,
        restore = function() modifiers.clear_dark() end,
    },
    {
        key = "fog", id = "fg", name = "Fog",
        blurb = "the air thickens and the distance goes grey",
        levels = {

            { name = "hazy",     fogx = 105 },
            { name = "thick",    fogx = 118 },
            { name = "pea soup", fogx = 140 },

            { name = "a red haze",      fogx = 118, hue = { 175, 85, 80 } },
            { name = "sulphur",         fogx = 125, hue = { 185, 175, 90 } },
            { name = "a blue distance", fogx = 112, hue = { 105, 130, 180 } },

            { name = "a green murk",   fogx = 122, hue = { 105, 160, 110 } },
            { name = "smoke",          fogx = 132, hue = { 90, 88, 92 } },
            { name = "a pink evening", fogx = 108, hue = { 200, 150, 175 } },
        },
        note = function() return modifiers.fog_note() end,
        world = function(level)
            modifiers.apply_fog()
        end,
        restore = function() modifiers.clear_fog() end,
    },
    {
        key = "cloud", id = "cl", name = "Cloud flower",
        blurb = "fall far enough and a platform catches you, and it grows back",

        levels = {
            { name = "one save, slow to return",  saves = 1, regen = 60 },
            { name = "two saves",                 saves = 2, regen = 50 },
            { name = "three saves",               saves = 3, regen = 40 },
            { name = "four saves",                saves = 4, regen = 30 },
            { name = "five saves, quick to return", saves = 5, regen = 20 },

            { name = "a pocketful",               saves = 6, regen = 15 },
            { name = "a dozen, and quick",        saves = 12, regen = 10 },
        },

        note = function() return modifiers.cloud_note() end,

        world = function() end,
        restore = function() modifiers.clear_clouds() end,
    },
    {
        key = "demon", id = "gd", name = "The Green Demon",
        blurb = "a 1-UP comes after you, and it does not stop",
        note = function() return modifiers.demon_note() end,
        levels = {
            { name = "patient", speed = 1 },
            { name = "quick",   speed = 2 },
            { name = "relentless", speed = 3 },

            { name = "you had better run", speed = 4 },

            { name = "29 to your 32", speed = 5 },
        },

        world = function() end,
        restore = function() modifiers.clear_demon() end,
    },
    {
        key = "fisheye", id = "fe", name = "Fisheye",
        blurb = "a wider, sillier world",
        levels = {

            { name = "wide", fov = 90 },
            { name = "wider", fov = 115 },
            { name = "absurd", fov = 140 },

            { name = "a long lens", fov = 30 },
            { name = "through a keyhole", fov = 17 },

            { name = "everything at once", fov = 165 },
            { name = "a telescope", fov = 10 },
        },
        note = function() return modifiers.fisheye_note() end,
        world = function(level)
            modifiers.rest_fov()
        end,
        restore = function() modifiers.rest_fov() end,
    },

    {
        key = "snow", id = "we", name = "Weather",
        blurb = "whatever is falling, wherever you are",
        levels = {
            { name = "snow", envfx = ENVFX_SNOW_NORMAL },
            { name = "a blizzard", envfx = ENVFX_SNOW_BLIZZARD },
            { name = "flower petals on the ground", envfx = ENVFX_FLOWERS,
              needs = "ground" },
            { name = "bubbles, deep under water", envfx = ENVFX_SNOW_WATER,
              needs = "water" },
            { name = "lava bubbles, over lava", envfx = ENVFX_LAVA_BUBBLES,
              needs = "lava" },

            { name = "rain", rain = "rain" },
            { name = "a thunderstorm", rain = "storm" },
        },
        note = function() return modifiers.weather_note() end,
        world = function()
            local rain = modifiers.setting("snow", "rain", nil)

            set_override_envfx(rain ~= nil and NO_ENVFX
                or modifiers.setting("snow", "envfx", ENVFX_SNOW_NORMAL))

            if OF.util.asks(OF.celebrate, "set_weather") then
                OF.celebrate.set_weather(rain)
            end
        end,
        restore = function()
            set_override_envfx(NO_ENVFX)
            if OF.util.asks(OF.celebrate, "set_weather") then
                OF.celebrate.set_weather(nil)
            end
        end,
    },

    {
        key = "quick", id = "qk", name = "How fast everybody moves",
        blurb = "the whole lobby, quicker or wading through treacle",

        note = function() return modifiers.quick_note() end,
        levels = {
            { name = "brisk", speed = 1.35 },
            { name = "fast", speed = 1.8 },
            { name = "silly", speed = 2.6 },

            { name = "wading", speed = 0.72 },
            { name = "through treacle", speed = 0.45 },

            { name = "ludicrous", speed = 3.6 },
        },
    },

    {
        key = "momentum", id = "mm", name = "Endless momentum",
        blurb = "the speed you build stays with you, and it keeps on building",
        note = function() return modifiers.momentum_note() end,
        levels = {
            { name = "nothing bleeds off" },
            { name = "and it builds as you run", gain = 0.35 },
            { name = "and it builds quickly", gain = 0.9 },

            { name = "and it runs away with you", gain = 2.0 },
        },
        apply = function(m) modifiers.hold_momentum(m) end,
        restore = function() modifiers.forget_momentum() end,
    },
    {
        key = "softland", id = "sl", name = "Soft landings",
        blurb = "nobody takes fall damage",
    },

    {
        key = "learn", id = "ln", name = "Earn your moveset",
        blurb = "start with almost nothing, and take it back a star at a time",
        note = function() return modifiers.learn_note() end,
        levels = {
            { name = "from scratch" },
            { name = "keep the double jump" },
        },
        world = function() modifiers.begin_learning() end,
        restore = function() modifiers.clear_learning() end,
    },

    {
        key = "made", id = "mo", name = "What everybody is made of",
        blurb = "the whole lobby, metal or barely there",
        levels = {
            { name = "metal", state = MODEL_STATE_METAL },
            { name = "barely there", state = MODEL_STATE_NOISE_ALPHA },

            { name = "metal, and barely there",
              state = MODEL_STATE_METAL | MODEL_STATE_NOISE_ALPHA },
        },
    },

    {
        key = "face", id = "fc", name = "Everybody's face",
        blurb = "what the whole lobby's eyes and hands are doing",
        note = function() return modifiers.face_note() end,
        levels = {

            { name = "asleep", eyes = MARIO_EYES_CLOSED,
              hands = MARIO_HAND_FISTS },
            { name = "sleepwalking", eyes = MARIO_EYES_CLOSED,
              hands = MARIO_HAND_OPEN },
            { name = "half awake", eyes = MARIO_EYES_HALF_CLOSED,
              hands = MARIO_HAND_OPEN },

            { name = "not at all well", eyes = MARIO_EYES_DEAD,
              hands = MARIO_HAND_OPEN },

            { name = "looking somewhere else", eyes = MARIO_EYES_LOOK_LEFT,
              hands = MARIO_HAND_OPEN },
            { name = "watching the sky", eyes = MARIO_EYES_LOOK_UP,
              hands = MARIO_HAND_OPEN },

            { name = "very pleased with themselves", eyes = MARIO_EYES_OPEN,
              hands = MARIO_HAND_PEACE_SIGN },
            { name = "holding an invisible cap", eyes = MARIO_EYES_OPEN,
              hands = MARIO_HAND_HOLDING_CAP },
        },
    },

    {
        key = "posture", id = "ps", name = "Everybody's posture",
        blurb = "the whole lobby standing wrong, from the waist and the neck up",
        levels = {

            { name = "heads on backwards", head = { 0, 0, 0x7FFF } },
            { name = "leaning back", torso = { 0, -0x1200, 0 } },
            { name = "hunched forward", torso = { 0, 0x1600, 0 }, head = { 0, -0x0800, 0 } },
            { name = "listing to one side", torso = { 0x1800, 0, 0 } },
            { name = "looking over one shoulder", head = { 0, 0, 0x3800 } },

            { name = "wrong in every joint", torso = { 0x2000, 0x1800, 0x2000 },
              head = { -0x1800, 0x1000, 0x4000 } },
        },
        restore = function() modifiers.clear_posture() end,
    },

    {
        key = "trail", id = "tl", name = "Everybody leaves a trail",
        blurb = "something comes off the whole lobby as it moves",
        levels = {
            { name = "sparkles", particle = PARTICLE_SPARKLES },
            { name = "fire", particle = PARTICLE_FIRE },
            { name = "snow", particle = PARTICLE_SNOW },
            { name = "leaves", particle = PARTICLE_LEAF },
            { name = "dust", particle = PARTICLE_DUST },
            { name = "bubbles", particle = PARTICLE_BUBBLE },
            { name = "stars", particle = PARTICLE_VERTICAL_STAR },
            { name = "dirt", particle = PARTICLE_DIRT },

            { name = "breath, as if it were freezing", particle = PARTICLE_BREATH },

            { name = "everything at once",
              particle = PARTICLE_SPARKLES | PARTICLE_FIRE | PARTICLE_SNOW
                  | PARTICLE_LEAF | PARTICLE_DUST | PARTICLE_VERTICAL_STAR },
        },
    },

    {
        key = "horizon", id = "hz", name = "The horizon",
        blurb = "the world does not sit level any more",
        levels = {
            { name = "a slight lean", tilt = 0x0700 },
            { name = "properly crooked", tilt = 0x1A00 },

            { name = "slowly turning", drift = 900 },
            { name = "upside down", tilt = 0x8000 },

            { name = "leaning the other way", tilt = -0x1A00 },

            { name = "on its side", tilt = 0x4000 },

            { name = "turning, and quickly", drift = 450 },

            { name = "a lean you can feel", tilt = 0x0E00 },
            { name = "turning, slowly, for ever", drift = 2200 },
        },
    },

    {
        key = "mirror", id = "mi", name = "Mirror",
        blurb = "the whole world, left for right",
        levels = {
            { name = "the world, and your stick with it", stick = true },

            { name = "the world only", stick = false },
        },
        world = function() modifiers.wear_mirror(true) end,
        restore = function() modifiers.wear_mirror(false) end,
        note = function() return modifiers.mirror_note() end,
    },

    {
        key = "budget", id = "bg", name = "Your A presses",
        blurb = "every jump is counted, and there may be a budget",

        excludes = { "buttons" },
        note = function() return modifiers.press_note() end,
        levels = {
            { name = "counted only" },
            { name = "ten a level",  budget = 10 },
            { name = "three a level", budget = 3 },
            { name = "one a level",  budget = 1 },

            { name = "fifty a level", budget = 50 },
            { name = "twenty-five a level", budget = 25 },
        },
        world = function() end,
        restore = function() modifiers.forget_presses() end,
    },
    {
        key = "buttons", id = "bt", name = "The buttons",
        blurb = "a button taken away, or one you can never let go of",
        excludes = { "budget" },
        levels = {
            { name = "no jumping (A)", mask = A_BUTTON },
            { name = "no hands (B)", mask = B_BUTTON },
            { name = "no crouching (Z)", mask = Z_TRIG },
            { name = "walk only", walk = true },
            { name = "all three at once", mask = A_BUTTON | B_BUTTON | Z_TRIG },

            { name = "no jumping and no hands", mask = A_BUTTON | B_BUTTON },
            { name = "no hands and no crouching", mask = B_BUTTON | Z_TRIG },
            { name = "no jumping and no crouching", mask = A_BUTTON | Z_TRIG },

            { name = "a slow walk and nothing else", walk = true,
              mask = A_BUTTON | B_BUTTON | Z_TRIG },

            { name = "crouching for ever (Z)", hold = Z_TRIG },
            { name = "fists up for ever (B)", hold = B_BUTTON },
        },
    },
    {
        key = "controls", id = "ct", name = "The controls",
        blurb = "the stick, turned on its way to Mario",
        levels = {
            { name = "mirrored", turn = "mirror" },
            { name = "backwards", turn = "flip" },
            { name = "sideways", turn = "quarter" },
            { name = "drunk", turn = "drunk" },

            { name = "sideways, the other way", turn = "backquarter" },

            { name = "askew", turn = "askew" },

            { name = "eight directions only", turn = "eight" },
            { name = "no backing up", turn = "noback" },
        },
    },

    {
        key = "view", id = "vw", name = "Where the camera sits",
        blurb = "where the camera stands while you play",
        levels = {
            { name = "over the shoulder", view = { 350, 550, 120, 190 } },
            { name = "far away", view = { 1600, 2400, 500, 800 } },
            { name = "from above", view = { 700, 900, 1300, 1700 } },
            { name = "down at your heels", view = { 900, 1400, 60, 90 } },

            { name = "through your own eyes", eyes = true },

            { name = "right behind you", view = { 200, 320, 90, 140 } },
            { name = "a long way up", view = { 500, 700, 2200, 2800 } },
            { name = "down at ankle height", view = { 700, 1000, 20, 60 } },

            { name = "a satellite", view = { 3200, 4000, 2600, 3400 } },
            { name = "practically inside you", view = { 120, 180, 100, 150 } },
        },
        world = function(level)
            modifiers.wear_eyes(modifiers.setting("view", "eyes", false) == true)
            modifiers.wear_view(modifiers.setting("view", "view", nil))
        end,
        restore = function()
            modifiers.wear_eyes(false)
            modifiers.wear_view(nil)
        end,
    },

    {
        key = "voice", id = "vo", name = "The voice",
        blurb = "what everybody in the lobby sounds like",
        levels = {
            { name = "silent", voice = { silent = true } },
            { name = "a Goomba", voice = {
                jump = SOUND_OBJ_GOOMBA_ALERT,
                hurt = SOUND_OBJ_GOOMBA_ALERT,
                quiet = SOUND_OBJ_GOOMBA_WALK,
                other = SOUND_OBJ_GOOMBA_WALK,
            } },
            { name = "Bowser", voice = {
                jump = SOUND_OBJ_BOWSER_LAUGH,
                hurt = SOUND_OBJ_BOWSER_DEFEATED,
                quiet = SOUND_OBJ_BOWSER_INHALING,
                other = SOUND_OBJ_BOWSER_WALK,
            } },
            { name = "a monkey", voice = {
                jump = SOUND_OBJ_UKIKI_CHATTER_SHORT,
                hurt = SOUND_OBJ_UKIKI_CHATTER_LONG,
                quiet = SOUND_OBJ_UKIKI_CHATTER_IDLE,
                other = SOUND_OBJ_UKIKI_STEP_DEFAULT,
            } },
            { name = "a Boo", voice = {
                jump = SOUND_OBJ_BOO_LAUGH_SHORT,
                hurt = SOUND_OBJ_BOO_LAUGH_LONG,
                quiet = SOUND_OBJ_BOO_LAUGH_LONG,
                other = SOUND_OBJ_BOO_BOUNCE_TOP,
            } },
            { name = "a Wiggler", voice = {
                jump = SOUND_OBJ_WIGGLER_JUMP,
                hurt = SOUND_OBJ_WIGGLER_ATTACKED,
                quiet = SOUND_OBJ_WIGGLER_TALK,
                other = SOUND_OBJ_WIGGLER_LOW_PITCH,
            } },
            { name = "a cartoon", voice = {
                jump = SOUND_GENERAL_BOING1,
                hurt = SOUND_GENERAL_BOING2,
                quiet = SOUND_GENERAL_BOING2_LOWPRIO,
                other = SOUND_GENERAL_BOING1,
            } },
            { name = "money", voice = {
                jump = SOUND_GENERAL_COIN,
                hurt = SOUND_GENERAL_COIN,
                quiet = SOUND_GENERAL_COIN,
                other = SOUND_GENERAL_COIN,
            } },

            { name = "a Koopa", voice = {
                jump = SOUND_OBJ_KOOPA_TALK,
                hurt = SOUND_OBJ_KOOPA_DAMAGE,
                quiet = SOUND_OBJ_KOOPA_TALK,
                other = SOUND_OBJ_KOOPA_DAMAGE,
            } },
            { name = "a penguin", voice = {
                jump = SOUND_OBJ_BIG_PENGUIN_YELL,
                hurt = SOUND_OBJ_BIG_PENGUIN_YELL,
                quiet = SOUND_OBJ_BIG_PENGUIN_WALK,
                other = SOUND_OBJ_BIG_PENGUIN_WALK,
            } },
            { name = "a bully", voice = {
                jump = SOUND_OBJ_BULLY_METAL,
                hurt = SOUND_OBJ_BULLY_EXPLODE,
                quiet = SOUND_OBJ_BULLY_METAL,
                other = SOUND_OBJ_BULLY_METAL,
            } },
            { name = "a piranha plant", voice = {
                jump = SOUND_OBJ2_PIRANHA_PLANT_BITE,
                hurt = SOUND_OBJ_SNUFIT_SHOOT,
                quiet = SOUND_OBJ2_PIRANHA_PLANT_BITE,
                other = SOUND_OBJ2_PIRANHA_PLANT_BITE,
            } },

            { name = "a Bob-omb", voice = {

                jump = SOUND_AIR_BOBOMB_LIT_FUSE,
                hurt = SOUND_OBJ_BOBOMB_BUDDY_TALK,
                quiet = SOUND_OBJ_BOBOMB_WALK,
                other = SOUND_OBJ_BOBOMB_WALK,
                dying = SOUND_GENERAL2_BOBOMB_EXPLOSION,
            } },
            { name = "the Big Bob-omb", voice = {
                jump = SOUND_OBJ_KING_BOBOMB_TALK,
                hurt = SOUND_OBJ2_KING_BOBOMB_DAMAGE,
                quiet = SOUND_OBJ_KING_BOBOMB_TALK,
                other = SOUND_OBJ_KING_BOBOMB_TALK,
                dying = SOUND_GENERAL2_BOBOMB_EXPLOSION,
            } },
            { name = "a Thwomp", voice = {
                jump = SOUND_OBJ_THWOMP,
                hurt = SOUND_OBJ_THWOMP,
                quiet = SOUND_OBJ_POUNDING_LOUD,
                other = SOUND_OBJ_POUNDING_LOUD,
                dying = SOUND_OBJ_THWOMP,
            } },
            { name = "a Chuckya", voice = {
                jump = SOUND_OBJ_HEAVEHO_TOSSED,
                hurt = SOUND_OBJ_CHUCKYA_DEATH,
                quiet = SOUND_OBJ_HEAVEHO_TOSSED,
                other = SOUND_OBJ_HEAVEHO_TOSSED,
                dying = SOUND_OBJ_CHUCKYA_DEATH,
            } },
        },
    },
    {
        key = "floor", id = "fl", name = "The floor",
        blurb = "every surface, as slippery as the lobby decides",
        levels = {
            { name = "slippery", class = SURFACE_CLASS_SLIPPERY },
            { name = "ice", class = SURFACE_CLASS_VERY_SLIPPERY },
            { name = "grippy", class = SURFACE_CLASS_NOT_SLIPPERY },

            { name = "ordinary everywhere", class = SURFACE_CLASS_DEFAULT },
        },
        note = function() return modifiers.floor_note() end,
    },

    {
        key = "lava", id = "lv", name = "The floor is lava",
        blurb = "the low ground burns - climb, or outrun it",
        levels = {

            { name = "the low ground" },
            { name = "all but the high ground" },
            { name = "the whole course" },

            { name = "a spreading fire" },
        },
        world = function(level)

            if level > 3 then
                if OF.util.asks(OF.ground, "creep") then OF.ground.creep() end
            elseif OF.util.asks(OF.ground, "paint") then
                OF.ground.paint(level)
            end
        end,
        restore = function()
            if OF.util.asks(OF.ground, "restore") then OF.ground.restore() end
        end,
    },

    {
        key = "water", id = "wt", name = "The water rises",
        blurb = "the level's own water, somewhere it should not be",

        excludes = { "dry" },
        levels = {
            { name = "high", by = HIGH_WATER },
            { name = "deep", by = DEEP_WATER },
            { name = "drowned", by = DROWNED_WATER },

            { name = "lowered", by = -LOW_WATER },
            { name = "drained", by = -GONE_WATER },
        },
        note = function() return modifiers.water_note() end,
        world = function(level)
            raise_water(modifiers.setting("water", "by", HIGH_WATER))
        end,
        restore = function() restore_water() end,
    },

    {
        key = "dry", id = "dl", name = "The water is gone",
        blurb = "every water box is a pit - walk in, walk about, walk out",

        excludes = { "swim", "water" },
        note = function() return modifiers.dry_note() end,
    },

    {
        key = "swim", id = "sw", name = "Swim anywhere",
        blurb = "the surface does not hold you down - swim up into the sky",
        levels = {
            { name = "past the surface" },
            { name = "in the air, in any level" },
        },
        excludes = { "dry" },
        note = function() return modifiers.swim_note() end,

        world = function() end,
        restore = function() modifiers.drop_the_swim() end,
    },

    {
        key = "invertwater", id = "iw", name = "You breathe water, not air",
        blurb = "the air empties your meter and the water fills it back up",
        note = function() return modifiers.invert_water_note() end,
        levels = {

            { name = "as slow as drowning", drain = 1 },
            { name = "twice as quick", drain = 2 },

            { name = "as quick as the gas", drain = 4 },
        },
        apply = function(m) modifiers.hold_invert_water(m) end,
    },

    {
        key = "coinhealth", id = "ch", name = "A hit costs coins, not health",
        blurb = "your coins are your health - lose them all and the next hit kills",
        note = function() return modifiers.coin_health_note() end,
        levels = {

            { name = "every coin you carry", whole = true },
            { name = "ten coins a hit", coins = 10 },
            { name = "three coins a hit", coins = 3 },

            { name = "one coin a hit", coins = 1 },
        },
        apply = function(m) modifiers.hold_coin_health(m) end,
        restore = function() modifiers.forget_coin_health() end,
    },

    {
        key = "whirl", id = "wh", name = "The water pulls",
        blurb = "an undertow in the middle of the level, dragging swimmers in - or blowing them apart",
        levels = {
            { name = "a tug", pull = 12 },
            { name = "a current", pull = 26 },

            { name = "a drain", pull = 75 },
            { name = "it pushes instead", pull = -26 },
            { name = "a fountain", pull = -75 },
        },
        note = function() return modifiers.whirl_note() end,

        world = function() end,
        restore = function() modifiers.clear_whirlpool() end,
    },

    {
        key = "carousel", id = "ro", name = "The level turns",
        blurb = "the ground swings the whole level around its own middle",
        levels = {
            { name = "a slow turn", spin = 24 },
            { name = "a carousel", spin = 64 },

            { name = "a fairground ride", spin = 144 },
            { name = "the other way", spin = -64 },
        },
        note = function() return modifiers.carousel_note() end,

        world = function() end,
        restore = function() modifiers.clear_carousel() end,
    },

    {
        key = "music", id = "ms", name = "The music",
        blurb = "the level's own track, at the wrong speed, in the wrong key, or keeping pace with your feet",
        levels = {
            { name = "slow", tempo = 60 },
            { name = "quick", tempo = 145 },
            { name = "twice over", tempo = 200 },

            { name = "an octave down", trans = -12 },
            { name = "an octave up", trans = 12 },
            { name = "out of key", trans = 5 },

            { name = "a funeral march", tempo = 38 },
            { name = "three times over", tempo = 300 },
            { name = "two octaves down", trans = -24 },
            { name = "a fifth up", trans = 7 },

            { name = "fast and wrong", tempo = 165, trans = -7 },

            { name = "slow and low", tempo = 50, trans = -12 },

            { name = "synched to your speed", low = 70, high = 130 },

            { name = "inverted to your speed", low = 130, high = 70 },
        },
        world = function() modifiers.wear_music(true) end,
        apply = function(m) modifiers.hold_music(m) end,
        restore = function() modifiers.wear_music(false) end,
    },

    {
        key = "flat", id = "fw", name = "Flat light",
        blurb = "every face lit the same - the world loses its shading",
        world = function() modifiers.wear_flat(true) end,
        restore = function() modifiers.wear_flat(false) end,
    },

    {
        key = "tint", id = "tn", name = "The world's colour",
        blurb = "the course itself, repainted - everybody standing on it is not",
        levels = {
            { name = "sepia", tint = { 255, 205, 150 } },
            { name = "rust", tint = { 255, 130, 90 } },
            { name = "verdigris", tint = { 120, 220, 180 } },
            { name = "ice", tint = { 150, 195, 255 } },
            { name = "a bruise", tint = { 175, 130, 235 } },
            { name = "gold", tint = { 255, 215, 70 } },

            { name = "ash", tint = { 145, 145, 145 } },
            { name = "bleached", tint = { 250, 250, 250 } },

            { name = "a shadow of itself", tint = { 60, 60, 70 } },
        },
        world = function() modifiers.wear_tint(true) end,
        restore = function() modifiers.wear_tint(false) end,
    },

    {
        key = "quake", id = "ea", name = "The camera shakes",
        blurb = "the ground never quite stops moving, or somebody is holding it",
        levels = {
            { name = "a tremor", mag = 0x30 },
            { name = "an earthquake", mag = 0xA0 },
            { name = "the whole world", mag = 0x180 },
            { name = "a steady hand", hand = HAND_CAM_SHAKE_LOW },
            { name = "handheld", hand = HAND_CAM_SHAKE_STAR_DANCE },
            { name = "somebody who has had a coffee", hand = HAND_CAM_SHAKE_HIGH },

            { name = "an earthquake, filmed badly", mag = 0xA0,
              hand = HAND_CAM_SHAKE_HIGH },
        },
        apply = function() modifiers.hold_quake() end,
    },

    {
        key = "anim", id = "am", name = "Everybody's animation",
        blurb = "everybody's limbs running faster or slower than they are",
        levels = {
            { name = "in slow motion", rate = 35 },
            { name = "wound up", rate = 220 },
            { name = "a cartoon", rate = 420 },

            { name = "a flip-book", rate = 8 },
            { name = "a blur", rate = 900 },
        },
    },

    {
        key = "shadow", id = "sd", name = "Shadows",
        blurb = "nothing casts one - judge the landing yourself",
        world = function() modifiers.wear_shadows(false) end,
        restore = function() modifiers.wear_shadows(true) end,
    },

    {
        key = "camlag", id = "cg", name = "The camera drags",
        blurb = "how quickly the camera catches up with you",
        levels = {
            { name = "on a long rope", pos = 0.02, foc = 0.05 },
            { name = "loose", pos = 0.08, foc = 0.2 },
            { name = "welded on", pos = 1.0, foc = 1.0 },

            { name = "half a second behind", pos = 0.008, foc = 0.02 },
            { name = "a step behind", pos = 0.25, foc = 0.45 },
        },
        apply = function() modifiers.hold_camlag() end,
    },

    {
        key = "shading", id = "sg", name = "The light and the shadow",
        blurb = "the lit side and the shaded side, coloured apart",
        levels = {
            { name = "hard shadows", dir = { 255, 255, 255 }, amb = { 25, 25, 30 } },
            { name = "a warm sun", dir = { 255, 205, 130 }, amb = { 70, 80, 130 } },
            { name = "moonlight", dir = { 150, 175, 255 }, amb = { 40, 45, 70 } },
            { name = "sickly", dir = { 150, 255, 120 }, amb = { 110, 70, 110 } },

            { name = "a sunset", dir = { 255, 150, 90 }, amb = { 100, 60, 90 } },
            { name = "a fluorescent office", dir = { 235, 245, 255 },
              amb = { 160, 170, 175 } },
            { name = "firelight", dir = { 255, 170, 80 }, amb = { 60, 30, 25 } },
        },
        world = function() modifiers.wear_shading(true) end,
        restore = function() modifiers.wear_shading(false) end,
    },

    {
        key = "quiet", id = "qt", name = "The level goes quiet",
        blurb = "the world's own sounds, off - the music plays on",
        levels = {
            { name = "the objects" },
            { name = "the whole world" },
            { name = "everything but the music" },
        },
        world = function() modifiers.wear_quiet(true) end,
        restore = function() modifiers.wear_quiet(false) end,
    },

    {
        key = "steps", id = "sp", name = "The ground underfoot",
        blurb = "what every footstep in the lobby sounds like, wherever it lands",
        levels = {
            { name = "grass", terrain = SOUND_TERRAIN_GRASS },
            { name = "stone", terrain = SOUND_TERRAIN_STONE },
            { name = "water", terrain = SOUND_TERRAIN_WATER },
            { name = "the squeaky floor", terrain = SOUND_TERRAIN_SPOOKY },
            { name = "snow", terrain = SOUND_TERRAIN_SNOW },
            { name = "ice", terrain = SOUND_TERRAIN_ICE },
            { name = "sand", terrain = SOUND_TERRAIN_SAND },

            { name = "bare hard ground", terrain = SOUND_TERRAIN_DEFAULT },
        },

    },

    {
        key = "lantern", id = "la", name = "Everybody carries a light",
        blurb = "a lamp on every player, and the world dims to meet it",
        levels = {

            { name = "a candle", light = { 255, 214, 150 }, radius = 900, glow = 1.0 },
            { name = "a lantern", light = { 255, 226, 180 }, radius = 1700, glow = 1.4 },
            { name = "a floodlight", light = { 255, 255, 255 }, radius = 3200, glow = 2.0 },

            { name = "a red flare", light = { 255, 80, 60 }, radius = 1500, glow = 1.7 },
            { name = "a cold blue torch", light = { 110, 170, 255 }, radius = 1500, glow = 1.6 },
            { name = "a green lamp", light = { 110, 255, 140 }, radius = 1500, glow = 1.6 },

            { name = "barely a match", light = { 255, 190, 120 },
              radius = 420, glow = 0.8 },

            { name = "a guttering flame", light = { 255, 186, 104 },
              radius = 1500, glow = 1.5, beat = "gutter" },
            { name = "a slow pulse", light = { 255, 226, 180 },
              radius = 1700, glow = 1.4, beat = "breathe" },
            { name = "an alarm", light = { 255, 60, 60 },
              radius = 1600, glow = 1.8, beat = "alarm" },

            { name = "a glow with no direction", light = { 200, 220, 255 },
              radius = 1500, glow = 1.5, spread = true },
        },
        note = function() return modifiers.lantern_note() end,

        world = function() end,
        restore = function() modifiers.clear_lanterns() end,
    },

    {
        key = "delay", id = "dy", name = "The controls arrive late",
        blurb = "what you press now happens in a moment",
        levels = {

            { name = "a hair late", frames = 3 },
            { name = "late", frames = 6 },
            { name = "a bad connection", frames = 10 },
            { name = "half a second", frames = 15 },

            { name = "a whole second", frames = 30 },
        },
        note = function() return modifiers.delay_note() end,
        world = function() end,
        restore = function() modifiers.forget_delay() end,
    },

    {
        key = "buffer", id = "pr", name = "An early press still counts",
        blurb = "ask for a jump just before you land and the game still hears it",
        levels = {

            { name = "a hair early", frames = 2 },
            { name = "early", frames = 4 },

            { name = "a beat early", frames = 6 },
        },
        world = function() end,
        restore = function() modifiers.forget_early() end,
    },

    {
        key = "cluster", id = "cu", name = "Ground pounds explode",
        blurb = "landing a pound sends rings of explosions out across the floor",
        levels = {
            { name = "one ring", rings = 1, reach = 320 },
            { name = "three rings", rings = 3, reach = 340 },

            { name = "six rings, and they reach", rings = 6, reach = 360 },
        },
        world = function() end,
        restore = function() modifiers.clear_cluster() end,
    },

    {
        key = "blinders", id = "bd", name = "What you see of the screen",
        blurb = "the screen is boarded up, all but a piece in the middle",
        levels = {
            { name = "a letterbox", across = 1.0, down = 0.42 },
            { name = "a narrow slit", across = 1.0, down = 0.18 },
            { name = "a tall window", across = 0.30, down = 1.0 },
            { name = "a keyhole", across = 0.42, down = 0.42 },

            { name = "barely a gap", across = 0.22, down = 0.22 },
        },
    },

    {
        key = "camaggr", id = "cq", name = "How hard the camera chases",
        blurb = "how quickly the shot gets behind you again",
        levels = {
            { name = "it never catches up", aggr = 0 },
            { name = "lazy", aggr = 15 },
            { name = "keen", aggr = 60 },
            { name = "it is already there", aggr = 100 },
        },
        world = function() modifiers.wear_camaggr(true) end,
        restore = function() modifiers.wear_camaggr(false) end,
    },

    {
        key = "campan", id = "cn", name = "How far the camera leads",
        blurb = "how much the shot leads your aim instead of sitting behind you",
        levels = {
            { name = "down your back", pan = 0 },
            { name = "a glance ahead", pan = 30 },
            { name = "well ahead", pan = 70 },
            { name = "all the way ahead", pan = 100 },
        },
        world = function() modifiers.wear_campan(true) end,
        restore = function() modifiers.wear_campan(false) end,
    },

    {
        key = "camdrag", id = "cd", name = "How the camera stops",
        blurb = "whether the shot coasts past you or stops dead",
        levels = {
            { name = "it coasts", decel = 0 },
            { name = "it eases", decel = 40 },
            { name = "it stops dead", decel = 100 },
        },
        world = function() modifiers.wear_camdrag(true) end,
        restore = function() modifiers.wear_camdrag(false) end,
    },

    {
        key = "camstick", id = "ck", name = "How fast the camera turns",
        blurb = "everybody's camera stick, on the same setting",
        levels = {
            { name = "a crawl", sens = 5 },
            { name = "slow", sens = 20 },
            { name = "quick", sens = 70 },
            { name = "a flick sends it round", sens = 100 },
        },
        world = function() modifiers.wear_camstick(true) end,
        restore = function() modifiers.wear_camstick(false) end,
    },

    {
        key = "camwall", id = "cw", name = "The camera goes through walls",
        blurb = "the shot stops being shoved out of the level's geometry",
        world = function() modifiers.wear_camwall(true) end,
        restore = function() modifiers.wear_camwall(false) end,
    },

    {
        key = "camcentre", id = "cr", name = "The camera never re-centres",
        blurb = "the shot keeps whatever angle you left it at",
        world = function() modifiers.wear_camcentre(true) end,
        restore = function() modifiers.wear_camcentre(false) end,
    },

    {
        key = "near", id = "np", name = "How close you can see",
        blurb = "anything close to the camera stops being drawn",
        levels = {
            { name = "the wall in front of you goes", near = 120 },
            { name = "and the ground with it", near = 300 },
            { name = "and most of you", near = 600 },
            { name = "there is barely a world left", near = 1200 },
        },
        world = function() modifiers.wear_near(true) end,
        restore = function() modifiers.wear_near(false) end,
    },

    {
        key = "camlock", id = "cz", name = "The level's own cameras",
        blurb = "the course's own camera scripting, refused",
        levels = {
            { name = "no fixed shots" },
            { name = "no set pieces either" },
            { name = "nothing at all" },
        },
    },

    {
        key = "camangle", id = "cj", name = "Nobody may switch camera style",
        blurb = "the R-trigger swap between Lakitu and Mario cam, off",
    },

    {
        key = "nocoins", id = "nc", name = "Coins cannot be picked up",
        blurb = "every coin in the course stays where it is",
    },

    {
        key = "nostomp", id = "ns", name = "Nothing may be stomped",
        blurb = "landing on an enemy does nothing at all",
    },

    {
        key = "nocarry", id = "ng", name = "Nothing may be picked up",
        blurb = "no bob-ombs, no boxes, nothing carried anywhere",
    },

    {
        key = "nosigns", id = "ni", name = "Signs and characters say nothing",
        blurb = "nobody stops you to talk and no sign reads",
    },

    {
        key = "nobreak", id = "nk", name = "Nothing breaks",
        blurb = "boxes and blocks stay standing however hard you hit them",
    },

    {
        key = "nopoles", id = "nz", name = "Poles cannot be held",
        blurb = "trees and poles are scenery, not a way up",
    },

    {
        key = "nocaps", id = "nq", name = "Caps cannot be picked up",
        blurb = "a cap on the ground is scenery",
    },

    {
        key = "caminvert", id = "ci", name = "The camera is inverted",
        blurb = "the camera axes, flipped for the whole lobby",
        levels = {
            { name = "left is right", invx = true },
            { name = "up is down", invy = false },
            { name = "both at once", invx = true, invy = false },
        },
        world = function() modifiers.wear_caminvert(true) end,
        restore = function() modifiers.wear_caminvert(false) end,
    },

    {
        key = "camdrive", id = "cf", name = "What moves the camera",
        blurb = "the stick, the D-pad or the mouse instead of the C buttons",
        levels = {
            { name = "the right stick", analog = true, dpad = false, mouse = false },
            { name = "the D-pad as well", analog = true, dpad = true, mouse = false },
            { name = "the D-pad alone", analog = false, dpad = true, mouse = false },
            { name = "the mouse, on a PC", analog = true, dpad = false, mouse = true },
        },
        world = function() modifiers.wear_camdrive(true) end,
        restore = function() modifiers.wear_camdrive(false) end,
    },

    {
        key = "breathe", id = "bh", name = "The view never sits still",
        blurb = "the view will not quite sit still",
        levels = {
            { name = "a slow swell", amp = 0x100, speed = 0x200 },
            { name = "seasick", amp = 0x300, speed = 0x400 },
            { name = "a heartbeat", amp = 0x180, speed = 0x900 },
            { name = "something is very wrong", amp = 0x600, speed = 0xC00 },
        },
        apply = function() modifiers.hold_breathe() end,
    },

    {
        key = "pitch", id = "ph", name = "Everything sounds wrong",
        blurb = "every sound in the game, played at the wrong speed",
        levels = {
            { name = "the world is huge", freq = 0.55 },
            { name = "a little slow", freq = 0.8 },
            { name = "a little fast", freq = 1.3 },
            { name = "the world is tiny", freq = 1.9 },

            { name = "underwater", freq = 0.33 },
            { name = "wasps", freq = 2.6 },
        },
    },

    {
        key = "bank", id = "bk", name = "One set of instruments",
        blurb = "every track the lobby plays, on the same soundfont",
        levels = {

            { name = "the outdoor courses", bank = 34 },
            { name = "inside the castle", bank = 14 },
            { name = "the water courses", bank = 19 },
            { name = "the fire courses", bank = 15 },
            { name = "the snow courses", bank = 11 },
            { name = "the slides", bank = 13 },
            { name = "Bowser's Road", bank = 25 },
            { name = "the boss fights", bank = 27 },

            { name = "Big Boo's Haunt", bank = 16 },
            { name = "the title screen", bank = 17 },
            { name = "Bowser's battle", bank = 18 },
            { name = "the Piranha Plant's lullaby", bank = 20 },
            { name = "the caves", bank = 21 },
            { name = "the star select", bank = 22 },
            { name = "the wing cap", bank = 23 },
            { name = "the metal cap", bank = 24 },
            { name = "the race fanfare", bank = 26 },
            { name = "the endless stairs", bank = 28 },
            { name = "Bowser's organ", bank = 29 },
            { name = "Peach's letter", bank = 30 },
            { name = "a new record", bank = 31 },
            { name = "Toad", bank = 32 },
            { name = "the merry-go-round", bank = 33 },
            { name = "the ending", bank = 35 },
            { name = "the file select", bank = 36 },
            { name = "the credits", bank = 37 },
        },
        world = function() modifiers.wear_bank(true) end,
        restore = function() modifiers.wear_bank(false) end,
    },
}

function modifiers.wear_bank(on)
    if OF.util.binding("set_sound_bank_override") == nil then return false end
    local bank = nil
    if on then
        bank = modifiers.setting("bank", "bank", nil)
        if type(bank) ~= "number" then return false end
    end

    if not OF.util.asks(OF.music, "wear_bank") then return false end
    OF.music.wear_bank(bank)

    if not on and OF.util.asks(OF.music, "restore_banks") then
        OF.music.restore_banks()

        if OF.util.asks(OF.music, "free_the_voice") then
            OF.music.free_the_voice()
        end
    end
    if OF.util.asks(OF.music, "play_again") then OF.music.play_again() end
    return true
end

do

local STEP_REACH = 160

local CARVE_MOST = 512

local MOMENTUM_STICK = 8

local momentumHeld = 0

function modifiers.forget_momentum()
    momentumHeld = 0
    return true
end

function modifiers.momentum_held()
    return momentumHeld
end

function modifiers.momentum_note()
    if modifiers.level("momentum") <= 0 then return nil end
    return OF.lang.t("No top of any kind - brake to be rid of what you built.")
end

local WALK_CLAMP_FACTOR = 48 / 32

function modifiers.quick_note()
    if modifiers.setting("quick", "speed", 1) <= WALK_CLAMP_FACTOR then
        return nil
    end
    return OF.lang.t("Past this a plain run is capped - it tells in the air.")
end

function modifiers.hold_momentum(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("momentum") <= 0 then return false end

    if not OF.util.can_play(0) then
        momentumHeld = 0
        return false
    end

    local now = tonumber(m.forwardVel) or 0
    if OF.util.stopping(m) or now < 0 then
        momentumHeld = 0
        return false
    end

    if now > momentumHeld then momentumHeld = now end

    local gain = modifiers.setting("momentum", "gain", 0)
    if gain > 0 and (tonumber(m.intendedMag) or 0) > MOMENTUM_STICK then
        momentumHeld = momentumHeld + gain
    end

    return OF.util.speed_up(m, momentumHeld)
end

local carving = false

local function one_part(m, stepType, stepArg)
    if stepType == STEP_TYPE_GROUND then return perform_ground_step(m) end
    return perform_air_step(m, stepArg)
end

function modifiers.carve_step(m, stepType, stepArg)
    if carving then return nil end
    if m == nil or m.playerIndex ~= 0 then return nil end
    if stepType ~= STEP_TYPE_GROUND and stepType ~= STEP_TYPE_AIR then return nil end
    if modifiers.level("momentum") <= 0 then return nil end
    if not OF.util.can_play(0) then return nil end
    if m.action == ACT_FLYING then return nil end
    if OF.util.asks(OF.underside, "held") and OF.underside.held(m) then
        return nil
    end

    local vel = m.vel
    if vel == nil then return nil end
    local vx = tonumber(vel.x) or 0
    local vz = tonumber(vel.z) or 0

    if stepType == STEP_TYPE_GROUND then
        local before = tonumber(m.forwardVel) or 0
        if before > 0 and OF.util.speed_up(m, momentumHeld) then
            local ratio = ((tonumber(m.forwardVel) or before) / before)
            vx, vz = vx * ratio, vz * ratio
            vel.x, vel.z = vx, vz
            m.slideVelX = (tonumber(m.slideVelX) or 0) * ratio
            m.slideVelZ = (tonumber(m.slideVelZ) or 0) * ratio
        end
    end

    local flat = math.sqrt(vx * vx + vz * vz)

    if not (flat > STEP_REACH) then return nil end

    local parts
    if flat > STEP_REACH * CARVE_MOST then
        parts = CARVE_MOST
    else
        parts = math.ceil(flat / STEP_REACH)
    end
    local slice = 1 / parts

    local restY = tonumber(vel.y) or 0
    local peak = tonumber(m.peakHeight)

    local answer = nil
    local stopped = false
    local carried = 0
    carving = true
    while carried < parts - 1 do
        vel.x, vel.z = vx * slice, vz * slice
        if stepType == STEP_TYPE_AIR then vel.y = 0 end
        local said = one_part(m, stepType, stepArg)
        carried = carried + 1

        if stepType == STEP_TYPE_GROUND then
            if said == GROUND_STEP_LEFT_GROUND
                or said == GROUND_STEP_HIT_WALL_STOP_QSTEPS then
                answer = said
                stopped = true
                break
            end
        else
            if said ~= AIR_STEP_NONE then answer = said end
            if said == AIR_STEP_LANDED or said == AIR_STEP_GRABBED_LEDGE
                or said == AIR_STEP_GRABBED_CEILING
                or said == AIR_STEP_HIT_LAVA_WALL then
                stopped = true
                break
            end
        end
    end

    vel.x, vel.z = vx * slice, vz * slice
    if stepType == STEP_TYPE_AIR then
        vel.y = restY
        if peak ~= nil then m.peakHeight = peak end
    end

    if answer == nil then

        carving = false
        return nil
    end
    if not stopped then

        local said = one_part(m, stepType, stepArg)
        if said ~= AIR_STEP_NONE then answer = said end
    end
    carving = false
    return answer
end

hook_event(HOOK_BEFORE_PHYS_STEP, modifiers.carve_step)

end

do

local BREATH_BACK = 0x1A

local ONE_WEDGE = 0x100

local FULL_METER = 0x880

function modifiers.invert_water_note()
    if modifiers.level("invertwater") <= 0 then return nil end
    if water_is_the_rounds() then
        return OF.lang.t("The round owns the water - this is standing down.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water here to breathe - only air, and it drowns.")
end

function modifiers.hold_invert_water(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("invertwater") <= 0 then return false end
    if water_is_the_rounds() then return false end
    if not OF.util.can_play(0) then return false end

    local health = tonumber(m.health) or 0
    if health < ONE_WEDGE then return false end
    if (tonumber(m.hurtCounter) or 0) ~= 0 then return false end
    if (tonumber(m.healCounter) or 0) ~= 0 then return false end
    if OF.util.has_flag(m.input or 0, INPUT_IN_POISON_GAS) then return false end
    if OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP) then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_INTANGIBLE) then return false end
    if group_of(m.action or 0) == ACT_GROUP_CUTSCENE then return false end

    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then

        if health >= FULL_METER then return false end
        m.health = math.min(FULL_METER, health + BREATH_BACK)
        return true
    end

    local drain = modifiers.setting("invertwater", "drain", 1)
    local left = health - drain
    if left < ONE_WEDGE then left = ONE_WEDGE - 1 end
    m.health = left
    return true
end

end

do

local A_KILLING_BLOW = 31

local coinWasHurt = nil
local coinWasHealth = nil

local coinHeld = nil

local coinFloor = {}

local SCATTER_MAX = 12

local function scatter_live_max()
    return OF.util.COIN_LIVE_MAX or 40
end

local COIN_HUD_HOLD = "coinhealth"
function modifiers.hold_vanilla_coins(hide)
    return OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD,
        hide == true)
end

function modifiers.holding_vanilla_coins()
    return OF.util.hud_hidden(HUD_DISPLAY_FLAG_COIN_COUNT)
end

function modifiers.coin_health_held()
    return coinHeld
end

function modifiers.coin_floor_live()
    return OF.util.coin_live(coinFloor)
end

function modifiers.forget_coin_health()

    if coinHeld == nil and coinWasHurt == nil and #coinFloor == 0
        and not OF.util.hud_hidden(HUD_DISPLAY_FLAG_COIN_COUNT) then
        coinWasHealth = nil
        return true
    end
    coinWasHurt = nil
    coinWasHealth = nil
    coinHeld = nil

    OF.util.coin_sweep(coinFloor)
    for index = #coinFloor, 1, -1 do coinFloor[index] = nil end
    modifiers.hold_vanilla_coins(false)
    return true
end

function modifiers.tally_coin(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_COIN then return false end
    if modifiers.level("coinhealth") <= 0 then return false end
    if o == nil then return false end

    local worth = OF.util.coin_worth(o)
    coinHeld = (coinHeld or 0) + worth
    return true
end

function modifiers.coin_health_cost()
    if modifiers.setting("coinhealth", "whole", false) == true then return nil end
    return modifiers.setting("coinhealth", "coins", 1)
end

function modifiers.coin_health_note()
    if modifiers.level("coinhealth") <= 0 then return nil end
    local held = modifiers.coin_health_held()
    if held ~= nil and held <= 0 then
        return OF.lang.t("Nothing in hand - the next hit is a fatal one.")
    end
    return OF.lang.t("Your own count, and the coins land on the floor.")
end

function modifiers.coin_health_hud()
    if modifiers.level("coinhealth") <= 0 then return nil end
    local held = modifiers.coin_health_held()
    if held == nil then return nil end
    if held <= 0 then return tostring(held), 255, 110, 110 end
    if held < 3 then return tostring(held), 255, 200, 90 end
    return tostring(held), 255, 235, 130
end

local SCATTER_RADIUS = 130
local SCATTER_LIFT = 60

function modifiers.scatter_coins(m, cost)
    if m == nil or m.pos == nil then return 0 end
    local room = scatter_live_max() - OF.util.coin_live(coinFloor)
    local want = math.floor(OF.util.clamp(cost or 0, 0, SCATTER_MAX))
    if want > room then want = math.max(room, 0) end
    if want <= 0 then return 0 end

    local put = 0
    for index = 1, want do
        local angle = (index / want) * 6.28318
        if OF.util.coin_put(coinFloor,
                m.pos.x + math.cos(angle) * SCATTER_RADIUS,
                m.pos.y + SCATTER_LIFT,
                m.pos.z + math.sin(angle) * SCATTER_RADIUS) then
            put = put + 1
        end
    end
    return put
end

function modifiers.hold_coin_health(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("coinhealth") <= 0 then
        modifiers.forget_coin_health()
        return false
    end

    if coinHeld == nil then coinHeld = 0 end

    local hurt = tonumber(m.hurtCounter) or 0
    local health = tonumber(m.health) or 0
    local wasHurt, wasHealth = coinWasHurt, coinWasHealth
    coinWasHurt, coinWasHealth = hurt, health

    if wasHurt == nil then return false end
    if hurt <= wasHurt then return false end

    local coins = math.floor(coinHeld or 0)
    if coins <= 0 then

        m.hurtCounter = A_KILLING_BLOW
        coinWasHurt = A_KILLING_BLOW
        return true
    end

    local cost = modifiers.coin_health_cost()
    if cost == nil or cost > coins then cost = coins end
    coinHeld = coins - cost
    modifiers.scatter_coins(m, cost)

    m.hurtCounter = 0
    coinWasHurt = 0
    if wasHealth ~= nil and health < wasHealth then
        m.health = wasHealth
        coinWasHealth = wasHealth
    end
    return true
end

end

do

    local DIALS = {
        aggression  = { "camera_config_get_aggression",     "camera_config_set_aggression" },
        pan         = { "camera_config_get_pan_level",      "camera_config_set_pan_level" },
        decel       = { "camera_config_get_deceleration",   "camera_config_set_deceleration" },
        sensitivity = { "camera_config_get_x_sensitivity",  "camera_config_set_x_sensitivity" },
        sensitivityY= { "camera_config_get_y_sensitivity",  "camera_config_set_y_sensitivity" },
        centering   = { "camera_config_get_centering",      "camera_config_enable_centering" },
        collision   = { "camera_config_is_collision_enabled", "camera_config_enable_collisions" },

        invertX     = { "camera_config_is_x_inverted",      "camera_config_invert_x" },
        invertY     = { "camera_config_is_y_inverted",      "camera_config_invert_y" },
        analog      = { "camera_config_is_analog_cam_enabled", "camera_config_enable_analog_cam" },
        dpad        = { "camera_config_is_dpad_enabled",    "camera_config_enable_dpad" },
        mouse       = { "camera_config_is_mouse_look_enabled", "camera_config_enable_mouse_look" },
    }

    modifiers.camHeld = modifiers.camHeld or setmetatable({}, {
        __index = function(_, dial)
            return OF.util.setting_was("cam." .. tostring(dial))
        end,
    })

    local DIAL_HOLDER = "modifiers"
    function modifiers.lend_camera(dial, value)
        local pair = DIALS[dial]
        if pair == nil then return false end
        return OF.util.lend_setting("cam." .. dial, DIAL_HOLDER,
            pair[1], pair[2], value)
    end

    function modifiers.return_camera(dial)
        local pair = DIALS[dial]
        if pair == nil then return false end
        if OF.util.setting_was("cam." .. dial) == nil then return true end
        if OF.util.binding(pair[2]) == nil then return false end
        return OF.util.return_setting("cam." .. dial, DIAL_HOLDER)
    end

    function modifiers.wear_camaggr(on)
        if not on then return modifiers.return_camera("aggression") end
        local want = modifiers.setting("camaggr", "aggr", nil)
        if want == nil then return false end
        return modifiers.lend_camera("aggression", want)
    end

    function modifiers.wear_campan(on)
        if not on then return modifiers.return_camera("pan") end
        local want = modifiers.setting("campan", "pan", nil)
        if want == nil then return false end
        return modifiers.lend_camera("pan", want)
    end

    function modifiers.wear_camdrag(on)
        if not on then return modifiers.return_camera("decel") end
        local want = modifiers.setting("camdrag", "decel", nil)
        if want == nil then return false end
        return modifiers.lend_camera("decel", want)
    end

    function modifiers.wear_camstick(on)
        if not on then
            local a = modifiers.return_camera("sensitivity")
            local b = modifiers.return_camera("sensitivityY")
            return a and b
        end
        local want = modifiers.setting("camstick", "sens", nil)
        if want == nil then return false end
        local a = modifiers.lend_camera("sensitivity", want)
        local b = modifiers.lend_camera("sensitivityY", want)
        return a and b
    end

    function modifiers.wear_camwall(on)
        if not on then return modifiers.return_camera("collision") end

        return modifiers.lend_camera("collision", false)
    end

    function modifiers.wear_camcentre(on)
        if not on then return modifiers.return_camera("centering") end
        return modifiers.lend_camera("centering", false)
    end
end

do

    local NO_NEAR = 0

    function modifiers.wear_near(on)
        if OF.util.binding("set_override_near") == nil then return false end
        if not on then
            OF.util.optional("set_override_near", nil, NO_NEAR)
            return true
        end
        local want = modifiers.setting("near", "near", nil)
        if want == nil then return false end
        OF.util.optional("set_override_near", nil, want)
        return true
    end
end

do

    local FIXED_ONLY = {
        [CAMERA_MODE_FIXED or -1] = true,
        [CAMERA_MODE_PARALLEL_TRACKING or -2] = true,
        [CAMERA_MODE_8_DIRECTIONS or -3] = true,
    }
    local AND_THE_SET_PIECES = {
        [CAMERA_MODE_WATER_SURFACE or -4] = true,
        [CAMERA_MODE_INSIDE_CANNON or -5] = true,
        [CAMERA_MODE_BOSS_FIGHT or -6] = true,
        [CAMERA_MODE_SLIDE_HOOT or -7] = true,
        [CAMERA_MODE_SPIRAL_STAIRS or -8] = true,
    }

    function modifiers.camera_mode_refused(mode)
        local step = modifiers.level("camlock")
        if step <= 0 then return false end
        if step >= 3 then return true end
        if FIXED_ONLY[mode] then return true end
        if step >= 2 and AND_THE_SET_PIECES[mode] then return true end
        return false
    end

    hook_event(HOOK_ON_SET_CAMERA_MODE, function(c, mode, frames)
        if modifiers.camera_mode_refused(mode) then return false end
    end)

    hook_event(HOOK_ON_CHANGE_CAMERA_ANGLE, function(angle)
        if modifiers.level("camangle") <= 0 then return end
        return false
    end)

end

do

    local REFUSED = {
        nocoins = INTERACT_COIN,
        nostomp = (INTERACT_BOUNCE_TOP or 0) | (INTERACT_BOUNCE_TOP2 or 0),
        nocarry = INTERACT_GRABBABLE,
        nosigns = INTERACT_TEXT,
        nobreak = INTERACT_BREAKABLE,
        nopoles = INTERACT_POLE,
        nocaps = INTERACT_CAP,
    }

    function modifiers.interaction_refused(interactType)
        if type(interactType) ~= "number" then return false end
        for key, mask in pairs(REFUSED) do
            if mask ~= nil and mask ~= 0
                and (interactType & mask) ~= 0
                and modifiers.level(key) > 0 then
                return true
            end
        end
        return false
    end

    hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)

        if m == nil or m.playerIndex ~= 0 then return end

        if modifiers.interaction_refused(interactType) then return false end
    end)
end

do
    modifiers.camHeld = modifiers.camHeld or {}

    function modifiers.wear_caminvert(on)
        if not on then
            local a = modifiers.return_camera("invertX")
            local b = modifiers.return_camera("invertY")
            return a and b
        end
        local x = modifiers.setting("caminvert", "invx", nil)
        local y = modifiers.setting("caminvert", "invy", nil)
        local ok = true

        if x ~= nil then ok = modifiers.lend_camera("invertX", x) and ok end
        if y ~= nil then ok = modifiers.lend_camera("invertY", y) and ok end
        return ok
    end

    function modifiers.wear_camdrive(on)
        if not on then
            local a = modifiers.return_camera("analog")
            local b = modifiers.return_camera("dpad")
            local c = modifiers.return_camera("mouse")
            return a and b and c
        end
        local analog = modifiers.setting("camdrive", "analog", nil)
        local dpad = modifiers.setting("camdrive", "dpad", nil)
        local mouse = modifiers.setting("camdrive", "mouse", nil)
        local ok = true
        if analog ~= nil then ok = modifiers.lend_camera("analog", analog) and ok end
        if dpad ~= nil then ok = modifiers.lend_camera("dpad", dpad) and ok end
        if mouse ~= nil then ok = modifiers.lend_camera("mouse", mouse) and ok end
        return ok
    end
end

do
    function modifiers.hold_breathe()
        if OF.util.binding("set_fov_shake") == nil then return false end
        if modifiers.level("breathe") <= 0 then return false end

        if not OF.util.can_play(0) then return false end
        local amp = modifiers.setting("breathe", "amp", nil)
        local speed = modifiers.setting("breathe", "speed", nil)
        if amp == nil then return false end

        OF.util.optional("set_fov_shake", nil, amp, 30, speed)
        return true
    end
end

do

    local replaying = false

    function modifiers.pitch_for(soundBits, pos)
        if replaying then return nil end
        if type(soundBits) ~= "number" then return nil end
        local scale = modifiers.setting("pitch", "freq", nil)
        if scale == nil then return nil end
        if OF.util.binding("play_sound_with_freq_scale") == nil then return nil end

        replaying = true
        OF.util.optional("play_sound_with_freq_scale", nil, soundBits, pos, scale)
        replaying = false

        return NO_SOUND or 0
    end
end

modifiers.ROW_RANK = "speedrun"
modifiers.GROUPS = {

    { home = "cheats", name = "How everybody moves",
      help = "what the lobby's body does - weight, speed, landings and grip",

      keys = { "upsidedown", "quick", "momentum", "softland", "floor" } },

    { home = "harsh", name = "The level itself",
      help = "what the course is made of - its floor, its water and what stands on it",
      keys = { "lava", "water", "dry", "swim", "whirl", "carousel", "cloud" } },

    { home = "harsh", name = "What the meter means",
      help = "where your health comes from, and what a hit is paid out of",
      keys = { "invertwater", "coinhealth" } },

    { home = "visuals", name = "Weather and light",
      help = "the sky, the hour, the air and what is falling out of it",
      keys = { "night", "sun", "dark", "fog", "snow", "lantern" } },

    { home = "visuals", name = "The light and the shadow", tail = "lightshow",
      help = "the paint on the level, the lighting model and the shadows under everybody",
      keys = { "tint", "flat", "shading", "shadow" } },

    { home = "shapes", name = "How a body carries itself",
      help = "what everybody is made of, what their face is doing, how they stand and what comes off them",
      keys = { "made", "face", "posture", "trail", "anim" } },

    { home = "controls", name = "What you may press",
      help = "which moves and which buttons exist at all, and how late a press may arrive",
      keys = { "learn", "budget", "buttons", "controls", "delay", "buffer",
               "cluster" } },

    { home = "controls", name = "The camera",
      help = "where the game's own camera stands, how wide it sees and how it follows",
      keys = { "fisheye", "view", "camlag", "quake", "breathe" } },

    { home = "controls", name = "The camera you are given",
      help = "what may take the shot away from a player, and how hard it chases",
      keys = { "camaggr", "campan", "camdrag", "camwall", "camcentre",
               "camlock", "camangle" } },

    { home = "controls", name = "How the camera is driven",
      help = "the hand on the camera: how fast it turns and which way round it is",
      keys = { "camstick", "caminvert", "camdrive" } },

    { home = "controls", name = "The frame it is drawn in",
      help = "which way up the picture is, how much of it you get and how far it reaches",
      keys = { "horizon", "mirror", "blinders", "near" } },

    { home = "music", name = "What the lobby sounds like",
      help = "the music, the voices and the noise underfoot",
      keys = { "voice", "music", "quiet", "steps", "pitch", "bank" } },

    { home = "rules", name = "What may be touched",
      help = "what the lobby allows a player to pick up, break, stomp or hold",
      keys = { "nocoins", "nostomp", "nocarry", "nosigns", "nobreak",
               "nopoles", "nocaps" } },
}

modifiers.HOMELESS = {
    demon = "its own switch on the Fun tab",
    lowgrav = "drawn as the cheat of the same name (PLAYTEST-0907 §18)",
    giant = "drawn as the cheat of the same name (PLAYTEST-0907 §18)",
    tiny = "drawn as the cheat of the same name (PLAYTEST-0907 §18)",
}

modifiers.UNGROUPED = "Everything else"
function modifiers.grouped(home)
    local where = {}
    for index, group in ipairs(modifiers.GROUPS) do
        for _, key in ipairs(group.keys) do where[key] = index end
    end

    local buckets = {}
    for index = 1, #modifiers.GROUPS do buckets[index] = {} end
    local rest = {}

    for _, entry in ipairs(modifiers.LIST) do
        local index = where[entry.key]
        if index == nil then
            if modifiers.HOMELESS[entry.key] == nil then
                table.insert(rest, entry)
            end
        else
            table.insert(buckets[index], entry)
        end
    end

    local out = {}
    for index, group in ipairs(modifiers.GROUPS) do
        if #buckets[index] > 0 and (home == nil or group.home == home) then
            table.insert(out, { name = group.name, tail = group.tail,
                says = group.says, help = group.help,
                entries = buckets[index] })
        end
    end
    if home == nil and #rest > 0 then
        table.insert(out, { name = modifiers.UNGROUPED,
            help = "Modifiers no heading has claimed yet",
            entries = rest })
    end
    return out
end

function modifiers.homes()
    local seen, out = {}, {}
    for _, group in ipairs(modifiers.GROUPS) do
        if group.home ~= nil and not seen[group.home] then
            seen[group.home] = true
            table.insert(out, group.home)
        end
    end
    return out
end

modifiers.BY_KEY = {}

modifiers.BY_ID = {}
for _, entry in ipairs(modifiers.LIST) do
    modifiers.BY_KEY[entry.key] = entry
    if entry.id ~= nil then modifiers.BY_ID[entry.id] = entry end
end

local wireStamp, textAt, textNow, setAt, setNow = 0, nil, nil, nil, nil

function modifiers.active()
    if setNow == nil or setAt ~= wireStamp then
        setAt = wireStamp
        setNow = modifiers.parse(modifiers.text())
    end
    return setNow
end

local function level_of(piece)
    local key, level = string.match(piece, "^([^=]+)=(%d+)$")
    if key == nil then key, level = piece, 1 end

    local entry = modifiers.BY_KEY[key] or modifiers.BY_ID[key]
    if entry == nil then return nil end
    return entry, math.max(1, math.min(modifiers.step_count(entry),
        math.floor(tonumber(level) or 1)))
end

local function run_of(piece)
    local found = nil
    local at = 1
    while at <= #piece do
        local id, digits, after = string.match(piece, "^(%a%a)(%d*)()", at)
        if id == nil or modifiers.BY_ID[id] == nil then return nil end
        found = found or {}
        local entry = modifiers.BY_ID[id]
        found[entry.key] = math.max(1, math.min(modifiers.step_count(entry),
            math.floor(tonumber(digits) or 1)))
        at = after
    end
    return found
end

function modifiers.parse(packed)
    local set = {}
    if packed == nil or packed == "" then return set end

    for piece in string.gmatch(packed, "[^,]+") do

        local entry, level = level_of(piece)
        if entry ~= nil then
            set[entry.key] = level
        else
            local run = run_of(piece)
            if run ~= nil then
                for key, at in pairs(run) do set[key] = at end
            end
        end
    end
    return set
end

function modifiers.step_count(entry)
    if entry == nil then return 1 end
    if entry.levels == nil then return 1 end
    return #entry.levels
end

local function room_step(key)
    if not OF.util.asks(OF.rules, "step") then return 0 end
    return OF.rules.step(key)
end

local function room_setting(key, field, fallback)
    if not OF.util.asks(OF.rules, "step_setting") then return fallback end
    return OF.rules.step_setting(key, field, fallback)
end

modifiers.room_step = room_step
modifiers.room_setting = room_setting

modifiers.LOBBY_ONLY = {

    lowgrav = "set as a cheat - your own box is on the Cheats page",
    giant = "set as a cheat - your own box is on the Cheats page",
    tiny = "set as a cheat - your own box is on the Cheats page",

    water = "the level has one water line - the whole lobby shares it",
    dry = "the level has one water line - the whole lobby shares it",
    swim = "the level has one water line - the whole lobby shares it",

    whirl = "one pull, in the middle of the level, on everybody in it",

    cluster = "your pounds still reach everybody else - this one is the lobby's",

    lava = "one floor, and it burns for the whole lobby or for nobody",
    demon = "one demon, coming after whoever in the lobby it can reach",
}

function modifiers.can_be_mine(key)
    if modifiers.BY_KEY[key] == nil then return false end
    return modifiers.LOBBY_ONLY[key] == nil
end

function modifiers.lobby_only_why(key)
    return modifiers.LOBBY_ONLY[key]
end

modifiers.mine = modifiers.mine or {}
modifiers.mineLevel = modifiers.mineLevel or {}

function modifiers.mine_level(key)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return 1 end
    return OF.util.clamp(math.floor(modifiers.mineLevel[key] or 1), 1,
        modifiers.step_count(entry))
end

function modifiers.mine_state(key)
    if not modifiers.can_be_mine(key) then return nil end
    local held = modifiers.mine[key]
    if held == nil then return nil end
    local roomLevel = modifiers.active()[key]
    if held == false then

        if roomLevel == nil or roomLevel <= 0 then return nil end
        return false
    end
    if roomLevel ~= nil and roomLevel == modifiers.mine_level(key) then
        return nil
    end
    return true
end

function modifiers.mine_any()
    for key in pairs(modifiers.mine) do
        if modifiers.mine_state(key) ~= nil then return true end
    end
    return false
end

modifiers.ROUND_KEY = "ofRoundMods"
do

    local roundAt, roundSet = nil, nil

    function modifiers.round_text()
        local text = gGlobalSyncTable[modifiers.ROUND_KEY]
        if type(text) ~= "string" then return "" end
        return text
    end

    function modifiers.round_set()
        local text = modifiers.round_text()
        if roundSet == nil or roundAt ~= text then
            roundAt = text
            roundSet = modifiers.parse(text)
        end
        return roundSet
    end
end

function modifiers.round_level(key)
    return modifiers.round_set()[key] or 0
end

function modifiers.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function modifiers.in_force(key, ignoreRound)
    local entry = modifiers.BY_KEY[key]

    if entry == nil then return room_step(key), false end

    if not ignoreRound and modifiers.round_holds() then
        return modifiers.round_level(key), false
    end

    local state = modifiers.mine_state(key)
    if state == true then return modifiers.mine_level(key), true end

    if state == false then return 0, true end

    local level = modifiers.active()[key]
    if level ~= nil then
        for _, other in ipairs(entry.excludes or {}) do
            if modifiers.mine_state(other) == true then return 0, false end
        end
        return level, false
    end
    return 0, false
end

function modifiers.level_is_yours(key)
    local _, mine = modifiers.in_force(key)
    return mine
end

function modifiers.suspended(key)
    if not modifiers.round_holds() then return false end
    return (modifiers.in_force(key, true)) > 0 and (modifiers.in_force(key)) == 0
end

function modifiers.settle_mine(key)
    if modifiers.mine_state(key) == nil then
        modifiers.mine[key] = nil
        modifiers.mineLevel[key] = nil
    end
end

function modifiers.set_mine(key, state)
    if modifiers.BY_KEY[key] == nil then return false, "No such modifier." end
    if not modifiers.can_be_mine(key) then
        return false, OF.lang.t(modifiers.LOBBY_ONLY[key])
    end
    if state == nil then
        modifiers.mine[key] = nil
        modifiers.mineLevel[key] = nil
    else
        modifiers.mine[key] = state == true
        if state == true and modifiers.mineLevel[key] == nil then
            modifiers.mineLevel[key] = 1
        end
        modifiers.settle_mine(key)
    end
    modifiers.mine_changed()
    return true
end

function modifiers.set_mine_level(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end
    if not modifiers.can_be_mine(key) then
        return false, OF.lang.t(modifiers.LOBBY_ONLY[key])
    end
    if type(level) ~= "number" then return false, "That is not a setting." end
    level = math.floor(level)
    if level <= 0 then return modifiers.set_mine(key, false) end
    if level > modifiers.step_count(entry) then
        return false, "That modifier does not go that far."
    end
    modifiers.mine[key] = true
    modifiers.mineLevel[key] = level

    modifiers.settle_mine(key)
    modifiers.mine_changed()
    return true
end

function modifiers.clear_mine()
    modifiers.mine = {}
    modifiers.mineLevel = {}
    modifiers.mine_changed()
    return true
end

function modifiers.level(key)
    return (modifiers.in_force(key))
end

function modifiers.is_on(key)
    return modifiers.level(key) > 0
end

function modifiers.setting(key, field, fallback)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return room_setting(key, field, fallback) end
    local level = modifiers.level(key)
    if level <= 0 then return fallback end
    local step = (entry.levels or {})[level]
    if step == nil or step[field] == nil then return fallback end
    return step[field]
end

local BUBBLE_DEPTH = 1400

function modifiers.bubbles_would_show()
    local m = gMarioStates[0]
    if m == nil or find_water_level == nil then return true end
    local ok, level = pcall(find_water_level, m.pos.x, m.pos.z)
    if not ok or type(level) ~= "number" then return true end
    return (level - m.pos.y) > BUBBLE_DEPTH
end

local LAVA_COURSES = "Lethal Lava Land and the Fire Sea"
function modifiers.fog_note()
    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    if here == nil then return nil end
    if modifiers.fog_is_real(here) then return nil end

    return OF.lang.t("No fog here - only twelve levels have any.")
end

local function count_hooked(roster, total)
    for _, entry in ipairs(roster) do
        if entry.bhv ~= nil then
            local ok, found = pcall(count_objects_with_behavior,
                get_behavior_from_id(entry.bhv))
            if ok and type(found) == "number" then
                total = total + found
            end
        end
    end
    return total
end

function modifiers.fight_count()
    if OF.spawner == nil or OF.spawner.FIGHTS == nil then return nil end
    if OF.spawner.CLOCKWORK == nil then return nil end
    if count_objects_with_behavior == nil or get_behavior_from_id == nil then
        return nil
    end
    return count_hooked(OF.spawner.CLOCKWORK, count_hooked(OF.spawner.FIGHTS, 0))
end

function modifiers.fight_note()

    if modifiers.level("fightback") <= 0 then return nil end

    local found = modifiers.fight_count()
    if found == nil then
        return OF.lang.t("Acts on crushers and turntables already here.")
    end
    if found <= 0 then
        return OF.lang.t("Nothing here to turn up - most courses have some.")
    end
    return OF.lang.fill("@ of them here, turned up.", found)
end

function modifiers.clock_note()
    if modifiers.level("fightback") > 0 then
        return OF.lang.t("The level fights back is driving this too.")
    end
    if modifiers.clock_overdrive() > 1 then
        return OF.lang.t("Past the game's own top - the mod drives it.")
    end
    return OF.lang.t("Acts on clock parts - place some, or visit the clock.")
end

function modifiers.clock_overdrive()
    local factor = modifiers.setting("clock", "overdrive", 1)
    if type(factor) ~= "number" or factor < 1 then return 1 end
    return factor
end

function modifiers.dark_note()
    if modifiers.level("dark") <= 0 then return nil end
    return OF.lang.t("The sky is not lit by this - the picture reaches it.")
end

function modifiers.sun_note()
    if modifiers.level("sun") <= 0 then return nil end
    return OF.lang.t("Metal keeps the level's own light.")
end

function modifiers.fisheye_note()
    if modifiers.level("fisheye") <= 0 then return nil end
    if modifiers.setting("view", "eyes", false) ~= true then return nil end
    return OF.lang.t("Nothing here: first person has a view of its own.")
end

function modifiers.floor_note()
    if modifiers.level("floor") <= 0 then return nil end
    if modifiers.setting("floor", "class", nil) ~= SURFACE_CLASS_DEFAULT then
        return nil
    end
    return OF.lang.t("Only bites where the level is icy or a slide.")
end

function modifiers.weather_note()

    if modifiers.setting("snow", "rain", nil) ~= nil then
        if OF.util.asks(OF.celebrate, "spectacle")
            and not OF.celebrate.spectacle() then
            return OF.lang.t("Your own presentation setting is hiding this.")
        end
        return nil
    end

    local needs = modifiers.setting("snow", "needs", nil)
    if needs == nil then return nil end

    if needs == "ground" then
        return OF.lang.t("These settle on the ground rather than falling.")
    end
    if needs == "lava" then

        if modifiers.level("lava") > 0 then return nil end
        return OF.lang.fill("Only over lava - @", LAVA_COURSES)
    end
    if needs == "water" and not modifiers.bubbles_would_show() then
        return OF.lang.t("Nothing until you are deep under water.")
    end
    return nil
end

function modifiers.any()
    return modifiers.text() ~= ""
end

function modifiers.count_on()
    local n = 0
    for _ in pairs(modifiers.active()) do n = n + 1 end
    return n
end

function modifiers.count_on_home(home)
    local n = 0
    for _, group in ipairs(modifiers.grouped(home)) do
        for _, entry in ipairs(group.entries) do
            if modifiers.level(entry.key) > 0 then n = n + 1 end
        end
    end
    return n
end

function modifiers.names(packed)
    local set = packed ~= nil and modifiers.parse(packed) or modifiers.active()
    local list = {}
    for _, entry in ipairs(modifiers.LIST) do
        if set[entry.key] then table.insert(list, entry.name) end
    end
    return list
end

local SHADER_DEFAULTS = {
    [SHADER_FLAG_HUE] = 0.0,
    [SHADER_FLAG_SATURATION] = 1.0,
    [SHADER_FLAG_BRIGHTNESS] = 1.0,
    [SHADER_FLAG_CONTRAST] = 1.0,
    [SHADER_FLAG_EXPOSURE] = 1.0,
    [SHADER_FLAG_DITHERING] = 0.0,

    [SHADER_FLAG_POSTERIZATION] = 8.0,
    [SHADER_FLAG_SCANLINES] = 1.0,
}

modifiers.shaderHeld = modifiers.shaderHeld or {}

modifiers.viewHeld = modifiers.viewHeld or nil

local EIGHTH_TURN = math.pi / 4

local function turned(x, y, how, frame)
    if how == "mirror" then return -x, y end
    if how == "flip" then return -x, -y end
    if how == "quarter" then return -y, x end

    if how == "backquarter" then return y, -x end

    if how == "askew" then
        local c, s = math.cos(EIGHTH_TURN), math.sin(EIGHTH_TURN)
        return x * c - y * s, x * s + y * c
    end

    if how == "eight" then
        local mag = math.sqrt(x * x + y * y)
        if mag < 1 then return x, y end
        local step = math.pi / 4
        local angle = math.floor(math.atan(y, x) / step + 0.5) * step
        return math.cos(angle) * mag, math.sin(angle) * mag
    end

    if how == "noback" then
        if y < 0 then return x, 0 end
        return x, y
    end
    if how == "drunk" then

        local angle = math.sin(frame / 47.0) * 2.2
        local c, s = math.cos(angle), math.sin(angle)
        return x * c - y * s, x * s + y * c
    end
    return x, y
end

modifiers.turned = turned

local controlFrame = 0

local function turn_the_stick(m)
    if m == nil or m.playerIndex ~= 0 then return end
    controlFrame = controlFrame + 1

    local how = modifiers.setting("controls", "turn", nil)
    if how == nil then return end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end
    local x, y = turned(c.stickX or 0, c.stickY or 0, how, controlFrame)
    c.stickX, c.stickY = x, y
end

local climbFrom = nil

function modifiers.forget_climb()
    climbFrom = nil
    return true
end

function modifiers.climb_origin()
    return climbFrom
end

local function climb_stand_down()
    return modifiers.round_holds()
end

function modifiers.climb_note()

    if not OF.util.asks(OF.rules, "shown_value") then return nil end
    local shown = OF.rules.shown_value("climb")
    if type(shown) ~= "number" or shown <= 0 then return nil end

    if OF.util.asks(OF.rules, "value") and OF.rules.value("stairs") == 999 then
        return OF.lang.t("The castle's own stairs are on How the game plays.")
    end
    return OF.lang.t("Any climb on foot, anywhere - not only stairs.")
end

local function on_own_feet(m)
    if m == nil or m.pos == nil or m.floor == nil then return false end
    if m.action == nil then return false end
    return OF.util.has_flag(m.action, ACT_FLAG_STATIONARY)
        or OF.util.has_flag(m.action, ACT_FLAG_MOVING)
end

local function climb_update(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local climb = modifiers.setting("climb", "climb", nil)
    if climb == nil or climb_stand_down() then
        climbFrom = nil
        return
    end

    local np = gNetworkPlayers[0]
    if np == nil then return end

    if not on_own_feet(m) then return end

    if climbFrom == nil
        or climbFrom.level ~= np.currLevelNum
        or climbFrom.area ~= np.currAreaIndex then
        climbFrom = { level = np.currLevelNum, area = np.currAreaIndex,
                      x = m.pos.x, y = m.pos.y, z = m.pos.z,

                      facing = m.faceAngle.y }
        return
    end

    if m.pos.y <= climbFrom.y then
        climbFrom.x, climbFrom.y, climbFrom.z = m.pos.x, m.pos.y, m.pos.z
        climbFrom.facing = m.faceAngle.y
        return
    end

    if m.pos.y - climbFrom.y < climb then return end

    m.pos.x, m.pos.y, m.pos.z = climbFrom.x, climbFrom.y, climbFrom.z
    m.faceAngle.y = climbFrom.facing

    if m.marioObj ~= nil then
        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ =
            m.pos.x, m.pos.y, m.pos.z

        OF.util.skip_interpolation(m.marioObj)
    end
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
end

hook_event(HOOK_MARIO_UPDATE, climb_update)

local LEVEL_CONSTANTS = {}
for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "number"
        and string.sub(name, 1, 6) == "LEVEL_" then

        if LEVEL_CONSTANTS[value] == nil then LEVEL_CONSTANTS[value] = name end
    end
end

function modifiers.rest_fov()
    if set_override_fov == nil then return end
    local fov = modifiers.setting("fisheye", "fov", nil)
    set_override_fov(fov or NO_FOV)
end

local LENS_FOV = 18

function modifiers.lens_fov(on)
    if set_override_fov == nil then return false end
    if not on then
        modifiers.rest_fov()
        return true
    end
    set_override_fov(LENS_FOV)
    return true
end

local pressedLevel = nil
local pressWasDown = true

function modifiers.presses(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row.ofPresses or 0
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

function modifiers.press_budget()
    return modifiers.setting("budget", "budget", nil)
end

function modifiers.forget_presses()
    pressedLevel = nil

    pressWasDown = true
    if modifiers.presses(0) ~= 0 then
        OF.util.publish_row(0, "ofPresses", nil)
    end
end

function modifiers.press_note()
    if modifiers.level("budget") <= 0 then return nil end
    local budget = modifiers.press_budget()
    if budget == nil then
        return OF.lang.fill("@ so far this level", tostring(modifiers.presses(0)))
    end
    return OF.lang.fill("@ of @ this level", tostring(modifiers.presses(0)),
        tostring(budget))
end

function modifiers.count_the_press(c)
    if modifiers.level("budget") <= 0 then return end
    if c == nil then return end

    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    local down = OF.util.has_flag(c.buttonDown or 0, A_BUTTON)

    if pressedLevel ~= here then
        modifiers.forget_presses()
        pressedLevel = here

        pressWasDown = down
        return
    end

    local newPress = down and not pressWasDown
    pressWasDown = down
    if not newPress then return end

    local spent = modifiers.presses(0)
    local budget = modifiers.press_budget()
    if budget ~= nil and spent >= budget then

        c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~A_BUTTON
        c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~A_BUTTON
        pressWasDown = false
        return
    end
    OF.util.publish_row(0, "ofPresses", spent + 1)
end

local function mask_the_buttons(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end

    modifiers.count_the_press(c)

    local hold = modifiers.setting("buttons", "hold", nil)
    if hold ~= nil then
        c.buttonDown = (c.buttonDown or 0) & 0xFFFF | hold
    end

    local mask = modifiers.setting("buttons", "mask", nil)
    if mask ~= nil then

        c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~mask
        c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~mask
    end

    if modifiers.setting("buttons", "walk", false) == true then
        local mag = c.stickMag or 0
        if mag > 24 then c.stickMag = 24 end
    end
end

modifiers.mask_the_buttons = mask_the_buttons

local function fold_s16(value)
    value = math.floor(value) & 0xFFFF
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

local function tilt_the_horizon()
    if gLakituState == nil then return end

    local tilt = modifiers.setting("horizon", "tilt", nil)
    local drift = modifiers.setting("horizon", "drift", nil)
    if tilt == nil and drift == nil then return end

    local amount = tilt or 0
    if drift ~= nil then

        local now = OF.util.optional("get_global_timer", 0) or 0
        amount = amount + (now % drift) * 0x10000 / drift
    end

    gLakituState.roll = fold_s16((gLakituState.roll or 0) + amount)

end

modifiers.tilt_the_horizon = tilt_the_horizon

local WALL_KICK_WINDOW = 5

local function kicks_held()
    return OF.util.asks(OF.cheats, "is_on") and OF.cheats.is_on("kicks") == true
end

local function hold_the_wall_kick(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not kicks_held() then return false end
    if (m.wallKickTimer or 0) < WALL_KICK_WINDOW then
        m.wallKickTimer = WALL_KICK_WINDOW
    end
    return true
end

modifiers.hold_the_wall_kick = hold_the_wall_kick

hook_event(HOOK_MARIO_UPDATE, hold_the_wall_kick)

do

local MAX_DELAY_FRAMES = 30

local DELAY_RING = MAX_DELAY_FRAMES + 1

local delayRing = {}
local delayAt = 0

function modifiers.forget_delay()
    for index = 1, DELAY_RING do delayRing[index] = nil end
    delayAt = 0
    return true
end

function modifiers.delay_held()
    local held = 0
    for index = 1, DELAY_RING do
        if delayRing[index] ~= nil then held = held + 1 end
    end
    return held
end

function modifiers.delay_note()
    local frames = modifiers.setting("delay", "frames", nil)
    if frames == nil then return nil end

    return OF.lang.fill("@ frames, about @ of a second",
        tostring(frames), tostring(math.floor(frames / 30 * 100 + 0.5) / 100))
end

local function delay_the_pad(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local frames = modifiers.setting("delay", "frames", nil)
    if frames == nil then

        if delayAt ~= 0 then modifiers.forget_delay() end
        return
    end

    if OF.util.menu_has_screen() then
        if delayAt ~= 0 then modifiers.forget_delay() end
        return
    end

    local c = m.controller
    if c == nil then return end

    frames = math.floor(OF.util.clamp(frames, 1, MAX_DELAY_FRAMES))

    delayAt = (delayAt % DELAY_RING) + 1
    delayRing[delayAt] = {
        stickX = c.stickX or 0,
        stickY = c.stickY or 0,
        stickMag = c.stickMag or 0,
        buttonDown = (c.buttonDown or 0) & 0xFFFF,
        buttonPressed = (c.buttonPressed or 0) & 0xFFFF,
    }

    local from = ((delayAt - 1 - frames) % DELAY_RING) + 1
    local was = delayRing[from]

    if was == nil then
        c.stickX, c.stickY, c.stickMag = 0, 0, 0
        c.buttonDown, c.buttonPressed = 0, 0
        return
    end

    c.stickX, c.stickY, c.stickMag = was.stickX, was.stickY, was.stickMag
    c.buttonDown, c.buttonPressed = was.buttonDown, was.buttonPressed
end

modifiers.delay_the_pad = delay_the_pad

hook_event(HOOK_BEFORE_MARIO_UPDATE, delay_the_pad)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.forget_delay() end)
end

do

local MAX_EARLY_FRAMES = 10

local groundedAt = nil

function modifiers.forget_early()
    groundedAt = nil
    return true
end

function modifiers.early_press(since, frames, now, wasGrounded)
    if type(since) ~= "number" then return nil end
    if type(frames) ~= "number" or type(now) ~= "number" then return nil end
    if type(wasGrounded) ~= "number" then return nil end
    if since < 1 or since > frames then return nil end
    local made = now - 1 - since
    if made <= wasGrounded then return nil end
    return made
end

local function on_the_ground(m)
    local group = group_of(m.action or 0)
    if group == nil then return false end
    return group == group_of(ACT_GROUP_STATIONARY)
        or group == group_of(ACT_GROUP_MOVING)
end

local function remember_the_press(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local frames = modifiers.setting("buffer", "frames", nil)
    if frames == nil then

        if groundedAt ~= nil then modifiers.forget_early() end
        return
    end

    if OF.util.menu_has_screen() or not OF.util.can_play(0) then
        modifiers.forget_early()
        return
    end

    local c = m.controller
    if c == nil then
        modifiers.forget_early()
        return
    end

    frames = math.floor(OF.util.clamp(frames, 1, MAX_EARLY_FRAMES))
    local now = OF.util.optional("get_global_timer", 0) or 0

    local wasGrounded = groundedAt
    local grounded = on_the_ground(m)
    if grounded then groundedAt = now end
    if not grounded or wasGrounded == nil then return end

    local pressed = (c.buttonPressed or 0) & 0xFFFF

    local madeA = modifiers.early_press(m.framesSinceA, frames, now, wasGrounded)
    if madeA ~= nil then pressed = pressed | A_BUTTON end

    local madeB = modifiers.early_press(m.framesSinceB, frames, now, wasGrounded)
    if madeB ~= nil then pressed = pressed | B_BUTTON end

    c.buttonPressed = pressed
end

modifiers.remember_the_press = remember_the_press

hook_event(HOOK_BEFORE_MARIO_UPDATE, remember_the_press)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.forget_early() end)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, mask_the_buttons)
hook_event(HOOK_BEFORE_MARIO_UPDATE, turn_the_stick)
hook_event(HOOK_ON_PLAY_MODE_UPDATE, tilt_the_horizon)

local MIRROR_CAMERA = GRAPH_NODE_TYPE_CAMERA or 0x114

local MIRROR_BUDGET = 96

local MIRROR_PATIENCE = 4

local MIRROR_MARK = 0x4D

local mirrorNode = nil

local mirrorUnseen = 0

local function mirror_find(first, budget)
    if first == nil or budget <= 0 then return nil, budget end
    local node = first
    repeat
        budget = budget - 1
        if budget < 0 then return nil, 0 end
        if node.type == MIRROR_CAMERA then return node, budget end
        local found
        found, budget = mirror_find(node.children, budget)
        if found ~= nil then return found, budget end
        node = node.next
    until node == nil or node == first or budget <= 0
    return nil, budget
end

local function mirror_camera_here()
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    if me == nil then return nil end
    local area = me.area
    if area == nil then return nil end
    local root = area.root
    if root == nil then return nil end
    local top = root.node
    if top == nil then return nil end
    return (mirror_find(top.children, MIRROR_BUDGET))
end

modifiers.mirror_camera_here = mirror_camera_here

modifiers.camera_node = mirror_camera_here

local function mirror_mark()
    local node = mirror_camera_here()
    if node == nil then return false end

    local was = node.hookProcess or 0
    if was == 0 then
        node.hookProcess = MIRROR_MARK
        mirrorNode = node
    elseif was ~= MIRROR_MARK then

        mirrorNode = nil
    end
    return true
end

local function mirror_unmark()
    mirrorUnseen = 0
    if mirrorNode == nil then return end
    local node = mirror_camera_here()
    if node ~= nil and node == mirrorNode
        and (node.hookProcess or 0) == MIRROR_MARK then
        node.hookProcess = 0
    end
    mirrorNode = nil
end

local function mirror_the_camera(node, matStackIndex)
    if node == nil or node.type ~= MIRROR_CAMERA then return end
    mirrorUnseen = 0
    if not modifiers.is_on("mirror") then return end
    if gMatStack == nil or matStackIndex == nil then return end

    local view = gMatStack[matStackIndex]
    if view ~= nil then
        view.m00 = -(view.m00 or 0)
        view.m10 = -(view.m10 or 0)
        view.m20 = -(view.m20 or 0)
        view.m30 = -(view.m30 or 0)
    end

    if gMatStackPrev == nil then return end
    local prev = gMatStackPrev[matStackIndex]
    if prev ~= nil then
        prev.m00 = -(prev.m00 or 0)
        prev.m10 = -(prev.m10 or 0)
        prev.m20 = -(prev.m20 or 0)
        prev.m30 = -(prev.m30 or 0)
    end
end

modifiers.mirror_the_camera = mirror_the_camera

function modifiers.mirroring()
    return modifiers.is_on("mirror")
end

function modifiers.mirror_screen_x(x, width)
    if x == nil or not modifiers.mirroring() then return x end
    if width == nil then
        width = OF.util.optional("djui_hud_get_screen_width", nil)
    end
    if type(width) ~= "number" or width <= 0 then return x end
    return width - x
end

local G_GEOMETRYMODE_OP = 0xD9
local CULL_INVERT       = 0x00000100
local GEOMETRY_WORD     = 0x00FFFFFF

local SYNC_OPS = { [0xE6] = true, [0xE7] = true, [0xE8] = true }

local DL_NODE_TYPES = {
    [0x015] = true, [0x016] = true, [0x017] = true, [0x019] = true,
    [0x01A] = true, [0x01B] = true, [0x01C] = true, [0x01D] = true,
    [0x030] = true,
}

local CULL_BUDGET = 4096

local cullInverted = false

local cullEverOn = false

local cullChanged = 0

local cullNode = nil

local CULL_EVERY = 15
local cullTick = 0

local cullSettling = false

local function cull_is_spent(cmd)
    return ((~(cmd.w0 or 0)) & GEOMETRY_WORD) == 0
        and ((cmd.w1 or 0) & GEOMETRY_WORD) == CULL_INVERT
end

local function cull_rewrite(cmd, op, wanted)
    if op ~= G_GEOMETRYMODE_OP then return false end

    if not wanted and cull_is_spent(cmd) then return false end
    if gfx_set_command == nil then return true end

    local w0 = cmd.w0 or 0
    local set = (cmd.w1 or 0) & GEOMETRY_WORD

    local clear = (~w0) & GEOMETRY_WORD

    if ((set & CULL_INVERT) ~= 0) == (wanted and true or false)
        and (clear & CULL_INVERT) == 0 then
        return true
    end

    clear = clear & ~CULL_INVERT
    if wanted then
        set = set | CULL_INVERT
    else
        set = set & ~CULL_INVERT
    end

    cullChanged = cullChanged + 1
    gfx_set_command(cmd, "gsSPGeometryMode(%i, %i)", clear, set)
    return true
end

local function cull_spend_sync(cmd, op, wanted)
    if wanted then
        if not SYNC_OPS[op] then return false end
        if gfx_set_command == nil then return true end
        cullChanged = cullChanged + 1
        gfx_set_command(cmd, "gsSPGeometryMode(%i, %i)", 0, CULL_INVERT)
        return true
    end

    if op ~= G_GEOMETRYMODE_OP then return false end
    if not cull_is_spent(cmd) then return false end
    if gfx_set_command == nil then return true end
    cullChanged = cullChanged + 1
    gfx_set_command(cmd, "gsDPPipeSync()")
    return true
end

local function cull_patch_list(gfx, wanted)
    if gfx == nil or gfx_parse == nil then return end

    local touched = 0
    gfx_parse(gfx, function(cmd, op)
        if cull_rewrite(cmd, op, wanted) then touched = touched + 1 end
    end)
    if touched > 0 then return end

    gfx_parse(gfx, function(cmd, op)
        return cull_spend_sync(cmd, op, wanted)
    end)
end

local function cull_walk(first, wanted, budget)
    if first == nil or budget <= 0 then return budget end
    local node = first
    repeat
        budget = budget - 1
        if budget <= 0 then return 0 end
        local kind = node.type
        if kind ~= nil and DL_NODE_TYPES[kind] and cast_graph_node ~= nil then
            local shaped = cast_graph_node(node)
            if shaped ~= nil then cull_patch_list(shaped.displayList, wanted) end
        end
        budget = cull_walk(node.children, wanted, budget)
        node = node.next
    until node == nil or node == first or budget <= 0
    return budget
end

local function cull_level(wanted, budget)
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = me ~= nil and me.area or nil
    local root = area ~= nil and area.root or nil
    local top = root ~= nil and root.node or nil
    if top == nil then return budget end
    return cull_walk(top.children, wanted, budget)
end

local function cull_models(wanted, budget)
    if obj_get_first == nil or obj_get_next == nil then return budget end
    local seen, seenCount = {}, 0
    for list = 0, 12 do
        local object = obj_get_first(list)
        while object ~= nil and budget > 0 do
            local gfxNode = object.header ~= nil and object.header.gfx or nil
            local shared = gfxNode ~= nil and gfxNode.sharedChild or nil
            if shared ~= nil then
                local already = false
                for index = 1, seenCount do
                    if seen[index] == shared then
                        already = true
                        break
                    end
                end
                if not already then
                    seenCount = seenCount + 1
                    seen[seenCount] = shared
                    budget = cull_walk(shared, wanted, budget)
                end
            end
            object = obj_get_next(object)
        end
    end
    return budget
end

local function cull_all(wanted, modelsOnly)
    cullChanged = 0
    if gfx_parse == nil or gfx_set_command == nil then return 0 end

    local budget = CULL_BUDGET
    if not modelsOnly then budget = cull_level(wanted, budget) end
    cull_models(wanted, budget)
    return cullChanged
end

function modifiers.mirror_cull(wanted)
    cullInverted = wanted and true or false
    if cullInverted then
        cullEverOn = true
        cullSettling = false
    else

        cullSettling = cullEverOn
    end
    cullTick = 0
    cullNode = mirror_camera_here()
    return cull_all(cullInverted)
end

function modifiers.mirror_cull_again()
    if not cullInverted and not cullEverOn then return 0 end
    if not cullInverted then cullSettling = true end
    cullTick = 0
    cullNode = mirror_camera_here()
    return cull_all(cullInverted)
end

function modifiers.wear_mirror(on)
    if not on then
        mirror_unmark()
        modifiers.mirror_cull(false)
        return true
    end
    mirrorUnseen = 0
    local marked = mirror_mark()
    modifiers.mirror_cull(true)
    return marked
end

local function mirror_watch()
    if not modifiers.is_on("mirror") then return end
    mirrorUnseen = mirrorUnseen + 1
    if mirrorUnseen <= MIRROR_PATIENCE then return end
    mirrorUnseen = 0
    mirror_mark()

    modifiers.mirror_cull_again()
end

modifiers.mirror_watch = mirror_watch

local function cull_watch()
    if not cullInverted and not cullEverOn then return false end

    cullTick = cullTick + 1
    if cullTick < CULL_EVERY then return false end
    cullTick = 0

    local node = mirror_camera_here()
    local moved = node ~= cullNode
    cullNode = node

    if not cullInverted and not cullSettling and not moved then return false end

    local changed = cull_all(cullInverted, not moved)
    if cullInverted then
        cullSettling = false
    elseif moved or changed > 0 then

        cullSettling = true
    else

        cullSettling = false
    end
    return true
end

modifiers.cull_watch = cull_watch

local function mirror_the_stick(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if modifiers.setting("mirror", "stick", false) ~= true then return end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end
    c.stickX = -(c.stickX or 0)
end

modifiers.mirror_the_stick = mirror_the_stick

function modifiers.mirror_note()
    if not modifiers.is_on("mirror") then return nil end

    return OF.lang.t("The sky does not flip. Writing reads backwards.")
end

hook_event(HOOK_ON_GEO_PROCESS, mirror_the_camera)
hook_event(HOOK_BEFORE_MARIO_UPDATE, mirror_the_stick)
hook_event(HOOK_UPDATE, mirror_watch)
hook_event(HOOK_UPDATE, cull_watch)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.mirror_cull_again() end)

hook_event(HOOK_ON_OBJECT_LOAD, function()
    if cullEverOn and not cullInverted then cullSettling = true end
end)

local function char_sound_set(names)
    local set = {}
    for _, name in ipairs(names) do
        local value = _G[name]
        if type(value) == "number" then set[value] = true end
    end
    return set
end

local VOICE_JUMP = char_sound_set({
    "CHAR_SOUND_YAH_WAH_HOO", "CHAR_SOUND_HOOHOO", "CHAR_SOUND_YAHOO",
    "CHAR_SOUND_WAH2", "CHAR_SOUND_HERE_WE_GO", "CHAR_SOUND_YAHOO_WAHA_YIPPEE",
    "CHAR_SOUND_TWIRL_BOUNCE", "CHAR_SOUND_LETS_A_GO",
})

local VOICE_HURT = char_sound_set({
    "CHAR_SOUND_UH", "CHAR_SOUND_WHOA", "CHAR_SOUND_EEUH", "CHAR_SOUND_ATTACKED",
    "CHAR_SOUND_OOOF", "CHAR_SOUND_OOOF2", "CHAR_SOUND_WAAAOOOW",
    "CHAR_SOUND_UH2", "CHAR_SOUND_UH2_2", "CHAR_SOUND_ON_FIRE",
    "CHAR_SOUND_DOH",
})

local VOICE_DYING = char_sound_set({
    "CHAR_SOUND_DYING", "CHAR_SOUND_DROWNING", "CHAR_SOUND_GAME_OVER",
})

local VOICE_QUIET = char_sound_set({
    "CHAR_SOUND_HRMM", "CHAR_SOUND_YAWNING", "CHAR_SOUND_SNORING1",
    "CHAR_SOUND_SNORING2", "CHAR_SOUND_SNORING3", "CHAR_SOUND_PANTING_COLD",
    "CHAR_SOUND_PANTING", "CHAR_SOUND_COUGHING1", "CHAR_SOUND_COUGHING2",
    "CHAR_SOUND_COUGHING3", "CHAR_SOUND_IMA_TIRED",
})

modifiers.VOICE_JUMP, modifiers.VOICE_HURT, modifiers.VOICE_QUIET =
    VOICE_JUMP, VOICE_HURT, VOICE_QUIET
modifiers.VOICE_DYING = VOICE_DYING

function modifiers.voice_for(characterSound)
    if type(characterSound) ~= "number" then return nil end
    local voice = modifiers.setting("voice", "voice", nil)
    if voice == nil then return nil end
    if voice.silent then return 0 end

    local pick
    if VOICE_JUMP[characterSound] then pick = voice.jump

    elseif VOICE_DYING[characterSound] then pick = voice.dying or voice.hurt
    elseif VOICE_HURT[characterSound] then pick = voice.hurt
    elseif VOICE_QUIET[characterSound] then pick = voice.quiet
    else pick = voice.other end

    if type(pick) ~= "number" then return nil end
    return pick
end

local function speak(m, characterSound)
    local sound = modifiers.voice_for(characterSound)
    if sound == nil then return nil end
    if sound == 0 then return 0 end

    local obj = m ~= nil and m.marioObj or nil
    local pos = obj ~= nil and obj.header ~= nil and obj.header.gfx ~= nil
        and obj.header.gfx.cameraToObject or nil
    local play = OF.util.binding("play_sound")
    if pos == nil or play == nil then return nil end
    play(sound, pos)
    return 0
end

modifiers.speak = speak

hook_event(HOOK_CHARACTER_SOUND, speak)

function modifiers.wear_sun(dir)
    if OF.util.binding("set_lighting_dir") == nil then return false end

    if dir == nil then

        if modifiers.sunHeld == nil then return true end
        for i = 0, 2 do
            OF.util.optional("set_lighting_dir", nil, i, modifiers.sunHeld[i + 1])
        end
        modifiers.sunHeld = nil
        return true
    end

    if modifiers.sunHeld == nil then
        modifiers.sunHeld = {}
        for i = 0, 2 do
            modifiers.sunHeld[i + 1] = OF.util.optional("get_lighting_dir", 0, i) or 0
        end
    end
    for i = 0, 2 do
        OF.util.optional("set_lighting_dir", nil, i, dir[i + 1] or 0)
    end
    return true
end

local SUN_TURN = 90 * 30

local function turn_the_sun()
    local hours = modifiers.setting("sun", "hours", nil)
    if hours ~= true then return end
    if OF.util.binding("set_lighting_dir") == nil then return end

    local now = OF.util.optional("get_global_timer", 0) or 0
    local angle = (now % SUN_TURN) / SUN_TURN * math.pi * 2

    modifiers.wear_sun({ math.sin(angle), math.cos(angle) * 0.8, 0 })
end

modifiers.turn_the_sun = turn_the_sun

hook_event(HOOK_UPDATE, turn_the_sun)

do

local CLOUD_FALL = 260
local CLOUD_LIFE = 6 * 30
local CLOUD_DROP = 40

local CLOUD_REACH = 500

local CLOUD_LAND = 1150
local CLOUD_GRACE = 3

local CLOUD_HOLD = 45

local clouds = {}
local cloudsLeft = 0
local cloudLevel = nil
local safeY = nil

local airFrames = 0
local catchHold = 0
local regrowFrames = 0

function modifiers.clouds_left()
    return cloudsLeft
end

function modifiers.cloud_max()
    local level = modifiers.level("cloud")
    if level <= 0 then return 0 end
    return modifiers.setting("cloud", "saves", level)
end

function modifiers.cloud_regen_seconds()
    return modifiers.setting("cloud", "regen", 40)
end

function modifiers.cloud_landing()
    return CLOUD_LAND
end

function modifiers.cloud_note()
    local most = modifiers.cloud_max()
    if most <= 0 then return nil end
    if cloudsLeft >= most then
        return OF.lang.fill("@ of @ ready", tostring(cloudsLeft), tostring(most))
    end
    local left = math.max(0,
        math.ceil((modifiers.cloud_regen_seconds() * 30 - regrowFrames) / 30))

    return OF.lang.fill("@ ready, another in @s",
        OF.lang.fill("@ of @", tostring(cloudsLeft), tostring(most)),
        tostring(left))
end

function modifiers.cloud_drop_total()
    return CLOUD_FALL + CLOUD_DROP
end

function modifiers.cloud_reach()
    return CLOUD_REACH
end

function modifiers.clear_clouds()
    for _, entry in ipairs(clouds) do
        if entry.object ~= nil then
            OF.util.optional("obj_mark_for_deletion", nil, entry.object)
        end
    end
    clouds = {}
    cloudsLeft = 0
    cloudLevel = nil
    safeY = nil
    airFrames = 0
    catchHold = 0
    regrowFrames = 0
end

local function cloud_budget()
    return modifiers.cloud_max()
end

local function regrow_frames()
    return math.max(1, math.floor(modifiers.cloud_regen_seconds() * 30))
end

local function about_to_land(m)
    local floor = m.floor
    if floor == nil then return false end
    local kind = floor.type
    if kind == SURFACE_DEATH_PLANE or kind == SURFACE_VERTICAL_WIND
        or kind == SURFACE_BURNING then
        return false
    end
    local height = m.floorHeight
    if type(height) ~= "number" then return false end
    return (m.pos.y - height) <= CLOUD_LAND
end

local function cloud_update()
    local budget = cloud_budget()
    if budget <= 0 then return end

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.pos == nil or np == nil then return end

    if cloudLevel ~= np.currLevelNum then
        modifiers.clear_clouds()
        cloudLevel = np.currLevelNum
        cloudsLeft = budget
    end

    if cloudsLeft > budget then cloudsLeft = budget end

    if cloudsLeft < budget then
        regrowFrames = regrowFrames + 1
        if regrowFrames >= regrow_frames() then
            regrowFrames = 0
            cloudsLeft = cloudsLeft + 1

            OF.notify.show("A cloud grew back - @ ready", "info", 2,
                tostring(cloudsLeft))
        end
    else
        regrowFrames = 0
    end

    if catchHold > 0 then catchHold = catchHold - 1 end

    for index = #clouds, 1, -1 do
        local entry = clouds[index]
        entry.frames = entry.frames - 1
        if entry.frames <= 0 then
            if entry.object ~= nil then
                OF.util.optional("obj_mark_for_deletion", nil, entry.object)
            end
            table.remove(clouds, index)
        end
    end

    if not OF.util.can_play(0) then return end

    if math.abs(m.pos.y - (m.floorHeight or m.pos.y)) < 30 then
        safeY = m.pos.y
        airFrames = 0
        return
    end
    if safeY == nil then return end

    if (m.vel ~= nil and m.vel.y or 0) >= 0 then
        airFrames = 0
        return
    end
    airFrames = airFrames + 1
    if m.pos.y > safeY - CLOUD_FALL then return end
    if airFrames < CLOUD_GRACE then return end

    if about_to_land(m) then return end

    if catchHold > 0 then return end
    if cloudsLeft <= 0 then return end

    if spawn_sync_object == nil or id_bhvStaticCheckeredPlatform == nil then
        return
    end
    local made = spawn_sync_object(id_bhvStaticCheckeredPlatform,
        E_MODEL_CHECKERBOARD_PLATFORM,
        m.pos.x, m.pos.y - CLOUD_DROP, m.pos.z, nil)

    if made == nil then return end

    table.insert(clouds, { object = made, frames = CLOUD_LIFE })
    cloudsLeft = cloudsLeft - 1
    catchHold = CLOUD_HOLD

    regrowFrames = 0

    safeY = m.pos.y - CLOUD_DROP
    airFrames = 0
    OF.notify.show("A cloud catches you - @ left", "good", 4,
        tostring(cloudsLeft))
end

modifiers.cloud_update = cloud_update

hook_event(HOOK_UPDATE, cloud_update)

end

do
local DEMON_SPEEDS = { 6, 11, 17, 23, 29 }
local DEMON_REACH = 90
local DEMON_START = 700
local DEMON_WOKE = 120

local DEMON_TRAIL_COST = 30

local DEMON_TRAIL_BUDGET = 150

local DEMON_TRAIL_CEILING = 600
local trailAllowed = true
local trailStride = 1

local demons = {}
local demonWokeAt = {}
local demonLevel = {}
local demonArea = {}
local demonHome = {}

function modifiers.demon_home(localIndex)
    return demonHome[localIndex or 0]
end

local function demon_is_ours(localIndex)
    local demon = demons[localIndex or 0]
    if demon == nil then return false end

    local ok, flags = pcall(function() return demon.activeFlags end)
    if not ok or type(flags) ~= "number" or flags == 0 then return false end
    if OF.util.optional("obj_has_behavior_id", 1, demon, id_bhvStaticObject) ~= 1 then
        return false
    end
    if OF.util.optional("obj_has_model_extended", 1, demon, E_MODEL_1UP) ~= 1 then
        return false
    end
    return true
end

modifiers.demon_is_ours = demon_is_ours

function modifiers.demon_allowed(levelNum)
    if levelNum == nil then return false end
    return (OF.util.course_of_level(levelNum) or 0) > 0
end

local STRANGERS_WORTH_SAYING = 8

function modifiers.demon_note()
    local speed = modifiers.setting("demon", "speed", nil)
    if speed == nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil or not modifiers.demon_allowed(np.currLevelNum) then
        return OF.lang.t("Only in the fifteen courses - not here.")
    end
    local step = DEMON_SPEEDS[speed] or DEMON_SPEEDS[1]

    local refused, strangers = modifiers.demon_faults()
    if (refused or 0) > 0 or (strangers or 0) > STRANGERS_WORTH_SAYING then
        return OF.lang.fill("@ per frame - @", step,
            tostring(refused or 0) .. " refused, "
                .. tostring(strangers or 0) .. " re-made.")
    end

    if #OF.util.connected_players() > 1 then
        return OF.lang.fill("@ per frame - @ chases running here.",
            step, modifiers.demon_count())
    end
    return OF.lang.fill("@ per frame - a run is 32.", step)
end

function modifiers.demon_awake(localIndex)
    local index = localIndex or 0
    return demons[index] ~= nil and demonWokeAt[index] ~= nil
end

function modifiers.demon_count()
    local n = 0
    for _ in pairs(demons) do n = n + 1 end
    return n
end

modifiers.demonRefused = 0
modifiers.demonStrangers = 0

function modifiers.demon_faults()
    return modifiers.demonRefused, modifiers.demonStrangers
end

function modifiers.clear_demon(localIndex)

    if localIndex == nil then
        for index in pairs(demons) do modifiers.clear_demon(index) end
        demonWokeAt = {}
        demonLevel = {}
        demonArea = {}
        demonHome = {}
        return
    end

    if demons[localIndex] ~= nil then
        if demon_is_ours(localIndex) then
            OF.util.optional("obj_mark_for_deletion", nil, demons[localIndex])
        end
        demons[localIndex] = nil
    end
    demonWokeAt[localIndex] = nil
    demonLevel[localIndex] = nil
    demonArea[localIndex] = nil

    demonHome[localIndex] = nil
end

local function chase_one(localIndex, speed)
    local m = gMarioStates[localIndex]
    local np = gNetworkPlayers[localIndex]
    if m == nil or m.pos == nil or np == nil then return end
    if not np.connected then
        modifiers.clear_demon(localIndex)
        return
    end

    if localIndex ~= 0 and np.currPositionValid == false then
        modifiers.clear_demon(localIndex)
        return
    end

    if demonLevel[localIndex] ~= np.currLevelNum
        or demonArea[localIndex] ~= np.currAreaIndex then
        modifiers.clear_demon(localIndex)
        demonLevel[localIndex] = np.currLevelNum
        demonArea[localIndex] = np.currAreaIndex
    end

    if not modifiers.demon_allowed(np.currLevelNum) then
        modifiers.clear_demon(localIndex)
        return
    end

    if not OF.util.can_play(localIndex) then return end

    if demons[localIndex] ~= nil and not demon_is_ours(localIndex) then
        demons[localIndex] = nil
        demonWokeAt[localIndex] = nil
        demonHome[localIndex] = nil
        modifiers.demonStrangers = modifiers.demonStrangers + 1
    end

    if demons[localIndex] == nil then
        if spawn_non_sync_object == nil or id_bhvStaticObject == nil then
            return
        end

        local made = spawn_non_sync_object(id_bhvStaticObject,
            E_MODEL_1UP,
            m.pos.x - sins(m.faceAngle.y) * DEMON_START,
            m.pos.y + 60,
            m.pos.z - coss(m.faceAngle.y) * DEMON_START, nil)

        if made == nil then
            modifiers.demonRefused = modifiers.demonRefused + 1
            return
        end
        demons[localIndex] = made
        local demon = made

        OF.util.optional("obj_set_billboard", nil, demon)

        if localIndex == 0 then
            OF.util.optional("play_sound", nil, SOUND_GENERAL2_1UP_APPEAR,
                gGlobalSoundSource)
        end
        demonWokeAt[localIndex] = nil
        demonHome[localIndex] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
        return
    end

    local demon = demons[localIndex]

    if demonWokeAt[localIndex] == nil then
        local home = demonHome[localIndex]
        if home == nil then
            demonHome[localIndex] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            return
        end
        local dx, dz = m.pos.x - home.x, m.pos.z - home.z
        if dx * dx + dz * dz < DEMON_WOKE * DEMON_WOKE then return end
        demonWokeAt[localIndex] = OF.util.optional("get_global_timer", 0) or 0

        if localIndex == 0 then
            OF.notify.show("It has noticed you", "bad", 4)
        end
    end

    local dx = m.pos.x - demon.oPosX
    local dy = m.pos.y + 60 - demon.oPosY
    local dz = m.pos.z - demon.oPosZ
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    if distance < DEMON_REACH then

        if localIndex == 0 then

            m.hurtCounter = 31
        end
        modifiers.clear_demon(localIndex)
        return
    end

    if distance > 0.001 then
        local step = DEMON_SPEEDS[speed] or DEMON_SPEEDS[1]
        demon.oPosX = demon.oPosX + dx / distance * step
        demon.oPosY = demon.oPosY + dy / distance * step
        demon.oPosZ = demon.oPosZ + dz / distance * step

        local mine = (localIndex or 0) == 0
        if trailAllowed and (mine or trailStride <= 1
            or ((OF.util.optional("get_global_timer", 0) or 0) + localIndex)
                % trailStride == 0) then
            OF.util.optional("spawn_non_sync_object", nil, id_bhvSparkleSpawn,
                E_MODEL_NONE, demon.oPosX, demon.oPosY, demon.oPosZ, nil)
        end
    end

    local ground = OF.util.optional("find_floor_height", nil,
        demon.oPosX, demon.oPosY + 200, demon.oPosZ)
    if ground ~= nil and ground > -10000 and demon.oPosY < ground + 40 then
        demon.oPosY = ground + 40
    end
end

local function chase_update()

    local speed = modifiers.setting("demon", "speed", nil)
    if speed == nil then return end

    local running = modifiers.demon_count()
    local others = math.max(0, running - 1)
    if others == 0 then
        trailStride = 1
    else
        local each = (DEMON_TRAIL_BUDGET - DEMON_TRAIL_COST) / others
        trailStride = math.max(1, math.ceil(DEMON_TRAIL_COST / math.max(1, each)))
    end

    local held = OF.util.optional("count_unimportant_objects", false)
    trailAllowed = not (type(held) == "number" and held > DEMON_TRAIL_CEILING)

    chase_one(0, speed)
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then chase_one(entry.localIndex, speed) end
    end
end

modifiers.chase_update = chase_update

hook_event(HOOK_UPDATE, chase_update)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    modifiers.clear_demon(m.playerIndex)
end)
end

function modifiers.wear_eyes(on)
    if OF.util.binding("set_first_person_enabled") == nil then return false end

    if not on then

        if modifiers.eyesHeld == nil then return true end
        OF.util.optional("set_first_person_enabled", nil, modifiers.eyesHeld)
        modifiers.eyesHeld = nil
        return true
    end

    if modifiers.eyesHeld == nil then

        modifiers.eyesHeld = gFirstPersonCamera ~= nil
            and gFirstPersonCamera.enabled == true or false
    end
    OF.util.optional("set_first_person_enabled", nil, true)
    return true
end

function modifiers.wear_view(view)
    local get = {
        "camera_romhack_get_zoomed_in_dist", "camera_romhack_get_zoomed_out_dist",
        "camera_romhack_get_zoomed_in_height", "camera_romhack_get_zoomed_out_height",
    }
    local set = {
        "camera_romhack_set_zoomed_in_dist", "camera_romhack_set_zoomed_out_dist",
        "camera_romhack_set_zoomed_in_height", "camera_romhack_set_zoomed_out_height",
    }
    if OF.util.binding(set[1]) == nil then return false end

    if view == nil then

        if modifiers.viewHeld == nil then return true end
        for i = 1, 4 do
            OF.util.optional(set[i], nil, modifiers.viewHeld[i])
        end
        OF.util.optional("camera_set_romhack_override", nil, modifiers.viewHeld[5])
        OF.util.optional("camera_romhack_allow_only_mods", nil, 0)

        OF.util.return_free_cam("viewModifier")
        OF.util.reset_camera_overrides()

        modifiers.viewHeld = nil
        return true
    end

    if modifiers.viewHeld == nil then
        local was = {}
        for i = 1, 4 do was[i] = OF.util.optional(get[i], nil) end
        was[5] = OF.util.optional("camera_get_romhack_override", nil)

        modifiers.viewHeld = was
    end

    OF.util.lend_free_cam("viewModifier")

    OF.util.optional("camera_romhack_allow_only_mods", nil, 1)

    OF.util.optional("camera_set_romhack_override", nil, RCO_ALL_INCLUDING_VANILLA)
    for i = 1, 4 do
        OF.util.optional(set[i], nil, view[i])
    end
    return true
end

modifiers.VISION_KEY = "ofVision"
modifiers.LOOKS = {
    { name = "black and white",
      blurb = "every colour drained out - the world in grey",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
    } },
    { name = "an old photograph",
      blurb = "faded and warm, like a print left in a drawer",
      look = {
        { SHADER_FLAG_SATURATION, 0.25 },
        { SHADER_FLAG_HUE, 0.08 },
        { SHADER_FLAG_CONTRAST, 0.85 },
    } },
    { name = "a comic book",
      blurb = "loud colour in a few flat shades, hard-edged",
      look = {
        { SHADER_FLAG_POSTERIZATION, 3.0 },
        { SHADER_FLAG_CONTRAST, 1.35 },
        { SHADER_FLAG_SATURATION, 1.4 },
    } },
    { name = "a CRT in 1996",
      blurb = "banded and stippled, under lines across the glass",
      look = {
        { SHADER_FLAG_SCANLINES, 6.0 },
        { SHADER_FLAG_POSTERIZATION, 6.0 },
        { SHADER_FLAG_DITHERING, 1.0 },
    } },
    { name = "night vision",
      blurb = "green and hard, as through a scope",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_HUE, 0.33 },
        { SHADER_FLAG_CONTRAST, 1.6 },
        { SHADER_FLAG_BRIGHTNESS, 1.3 },
    } },
    { name = "a fever dream",
      blurb = "colour spun round the wheel, past real",
      look = {
        { SHADER_FLAG_HUE, 0.5 },
        { SHADER_FLAG_SATURATION, 2.2 },
        { SHADER_FLAG_CONTRAST, 1.2 },
    } },

    { name = "a photo negative",
      blurb = "every channel reflected through mid grey",
      look = {
        { SHADER_FLAG_CONTRAST, -1.0 },
    } },
    { name = "sun-bleached",
      blurb = "bright and washed out, with the contrast gone",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 1.6 },
        { SHADER_FLAG_SATURATION, 0.5 },
        { SHADER_FLAG_CONTRAST, 0.75 },
    } },

    { name = "newsprint",
      blurb = "halftone dots instead of shading, as cheap print",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_BRIGHTNESS, 1.15 },
        { SHADER_FLAG_CONTRAST, 1.6 },
        { SHADER_FLAG_DITHERING, 1.0 },
    } },

    { name = "thermal",
      blurb = "the level read as heat, in banded false colour",
      look = {
        { SHADER_FLAG_HUE, 0.62 },
        { SHADER_FLAG_SATURATION, 3.0 },
        { SHADER_FLAG_BRIGHTNESS, 1.25 },
        { SHADER_FLAG_POSTERIZATION, 4.0 },
    } },

    { name = "bleach bypass",
      blurb = "silvery and harsh, with the blacks stretched flat",
      look = {
        { SHADER_FLAG_SATURATION, 0.3 },
        { SHADER_FLAG_CONTRAST, 1.9 },
        { SHADER_FLAG_EXPOSURE, 1.3 },
    } },

    { name = "moonless",
      blurb = "night that takes the sky with it, shading left in",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 0.4 },
        { SHADER_FLAG_SATURATION, 0.45 },
        { SHADER_FLAG_CONTRAST, 1.25 },
    } },

    { name = "blown out",
      blurb = "overexposed - the highlights gone to white",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 1.6 },
        { SHADER_FLAG_CONTRAST, 1.25 },
        { SHADER_FLAG_SATURATION, 0.7 },
    } },
    { name = "a cheap VHS",
      blurb = "soft, dull and lined, like a worn-out tape",
      look = {
        { SHADER_FLAG_SCANLINES, 3.0 },
        { SHADER_FLAG_SATURATION, 0.75 },
        { SHADER_FLAG_CONTRAST, 0.85 },
        { SHADER_FLAG_BRIGHTNESS, 1.1 },
    } },

    { name = "eight colours",
      blurb = "each channel down to two shades, and colour up",
      look = {
        { SHADER_FLAG_POSTERIZATION, 2.0 },
        { SHADER_FLAG_SATURATION, 1.5 },
    } },
    { name = "a blueprint",
      blurb = "cold blue ink on a hard, pale drawing ground",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_HUE, 0.6 },
        { SHADER_FLAG_CONTRAST, 1.4 },
        { SHADER_FLAG_BRIGHTNESS, 0.85 },
    } },
}

modifiers.VISION_DIALS = {
    { flag = SHADER_FLAG_HUE, name = "Hue",
      blurb = "every colour walked round the wheel",
      from = 0, to = 1, step = 0.05, rest = 0.0 },
    { flag = SHADER_FLAG_SATURATION, name = "Saturation",
      blurb = "how much colour the world keeps",
      from = 0, to = 3, step = 0.1, rest = 1.0 },
    { flag = SHADER_FLAG_BRIGHTNESS, name = "Brightness",
      blurb = "lifts the picture before the contrast",
      from = 0, to = 3, step = 0.1, rest = 1.0 },

    { flag = SHADER_FLAG_CONTRAST, name = "Contrast",
      blurb = "pushes light and dark apart - under zero it swaps them",
      from = -1, to = 3, step = 0.05, rest = 1.0 },

    { flag = SHADER_FLAG_EXPOSURE, name = "Exposure",
      blurb = "lifts the picture after the contrast",
      from = 0, to = 3, step = 0.1, rest = 1.0 },
    { flag = SHADER_FLAG_POSTERIZATION, name = "Posterization",
      blurb = "how many shades a colour is cut to",
      from = 1, to = 16, step = 1, rest = 8.0 },
    { flag = SHADER_FLAG_SCANLINES, name = "Scanlines",
      blurb = "dark lines drawn across the picture",
      from = 0, to = 10, step = 0.5, rest = 1.0 },
}

modifiers.VISION_DITHER = SHADER_FLAG_DITHERING

local VISION_SEP = ","
local function vision_defaults()
    local dials = {}
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        dials[index] = dial.rest
    end
    return dials, false
end

function modifiers.vision_pack(dials, dither)
    local parts = {}
    for index in ipairs(modifiers.VISION_DIALS) do
        parts[index] = string.format("%.2f", dials[index] or 0)
    end
    table.insert(parts, dither and "1" or "0")
    return table.concat(parts, VISION_SEP)
end

function modifiers.vision_parse(text)
    local dials, dither = vision_defaults()
    if type(text) ~= "string" or text == "" then return dials, dither end

    local index = 0
    for field in string.gmatch(text, "[^" .. VISION_SEP .. "]+") do
        index = index + 1
        if index <= #modifiers.VISION_DIALS then
            local value = tonumber(field)
            if value ~= nil then
                local dial = modifiers.VISION_DIALS[index]
                dials[index] = OF.util.clamp(value, dial.from, dial.to)
            end
        elseif index == #modifiers.VISION_DIALS + 1 then
            dither = (field == "1")
        end
    end
    return dials, dither
end

function modifiers.vision()
    return modifiers.vision_parse(gGlobalSyncTable[modifiers.VISION_KEY])
end

local MINE_KEY = "visionMine"
local MINE_ON_KEY = "visionMineOn"
local mineAt = nil
local mineDither = nil

local function same_dial(one, two)
    if one == nil or two == nil then return false end
    return math.abs(one - two) < 0.001
end

local function mine_unpack(text)
    local at, dither = {}, nil
    if type(text) ~= "string" or text == "" then return at, dither end
    local index = 0
    for field in string.gmatch(text .. VISION_SEP,
                               "([^" .. VISION_SEP .. "]*)" .. VISION_SEP) do
        index = index + 1
        if index <= #modifiers.VISION_DIALS then
            local value = tonumber(field)
            if value ~= nil then
                local dial = modifiers.VISION_DIALS[index]
                at[index] = OF.util.clamp(value, dial.from, dial.to)
            end
        elseif index == #modifiers.VISION_DIALS + 1 then
            if field == "1" then dither = true
            elseif field == "0" then dither = false end
        end
    end
    return at, dither
end

local function mine_packed()
    local parts = {}
    for index in ipairs(modifiers.VISION_DIALS) do
        local value = mineAt[index]
        parts[index] = value == nil and "" or string.format("%.2f", value)
    end
    parts[#modifiers.VISION_DIALS + 1] =
        (mineDither == true and "1") or (mineDither == false and "0") or ""
    return table.concat(parts, VISION_SEP)
end

local function mine_written()
    if mineDither ~= nil then return true end
    for index in ipairs(modifiers.VISION_DIALS) do
        if mineAt[index] ~= nil then return true end
    end
    return false
end

local function mine_load()
    if mineAt ~= nil then return end
    local packed = mod_storage_load(MINE_KEY, "") or ""
    local was = mod_storage_load(MINE_ON_KEY, "") or ""
    if was ~= "" then
        mineAt, mineDither = {}, nil
        if was == "true" then
            local dials, dither = modifiers.vision_parse(packed)
            for index in ipairs(modifiers.VISION_DIALS) do
                mineAt[index] = dials[index]
            end
            mineDither = dither
        end
        OF.util.store(MINE_KEY, mine_written() and mine_packed() or "")

        OF.util.store(MINE_ON_KEY, "")
        return
    end

    mineAt, mineDither = mine_unpack(packed)
end

local function mine_store()
    if not OF.util.store(MINE_KEY, mine_written() and mine_packed() or "") then
        return false, "That did not fit in the save file."
    end
    modifiers.mine_changed()
    return true
end

function modifiers.vision_mine_state(what)
    mine_load()
    if what == "dither" then
        if mineDither == nil then return nil end
        local _, room = modifiers.vision()
        if mineDither == room then return nil end
        return mineDither
    end
    local dial = modifiers.VISION_DIALS[what]
    if dial == nil then return nil end
    local value = mineAt[what]
    if value == nil then return nil end
    local room = modifiers.vision()[what]
    if same_dial(value, room) then return nil end
    if same_dial(value, dial.rest) then return false end
    return true
end

function modifiers.vision_mine_value(index)
    mine_load()
    if modifiers.vision_mine_state(index) == nil then return nil end
    return mineAt[index]
end

function modifiers.vision_mine_any()
    if modifiers.vision_mine_state("dither") ~= nil then return true end
    for index in ipairs(modifiers.VISION_DIALS) do
        if modifiers.vision_mine_state(index) ~= nil then return true end
    end
    return false
end

function modifiers.vision_in_force(ignoreRound)
    if not ignoreRound and modifiers.round_holds() then
        return vision_defaults()
    end
    mine_load()
    local dials, dither = modifiers.vision()
    for index in ipairs(modifiers.VISION_DIALS) do
        if mineAt[index] ~= nil then dials[index] = mineAt[index] end
    end
    if mineDither ~= nil then dither = mineDither end
    return dials, dither
end

local function keep_mine(dials, dither)
    mine_load()
    for index in ipairs(modifiers.VISION_DIALS) do
        mineAt[index] = dials[index]
        if modifiers.vision_mine_state(index) == nil then mineAt[index] = nil end
    end
    mineDither = dither and true or false
    if modifiers.vision_mine_state("dither") == nil then mineDither = nil end
    return mine_store()
end

function modifiers.look_from(dials, dither)
    local look = {}
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        local value = dials[index]
        if value ~= nil and math.abs(value - dial.rest) > 0.001 then
            table.insert(look, { dial.flag, value })
        end
    end

    if dither then table.insert(look, { modifiers.VISION_DITHER, 1.0 }) end
    if #look == 0 then return nil end
    return look
end

function modifiers.vision_look()
    return modifiers.look_from(modifiers.vision())
end

function modifiers.look()
    return modifiers.look_from(modifiers.vision_in_force())
end

function modifiers.set_dial(index, value)
    local dial = modifiers.VISION_DIALS[index]
    if dial == nil then return false, "No such dial." end
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end

    local dials, dither = modifiers.vision()
    dials[index] = OF.util.clamp(tonumber(value) or dial.rest, dial.from, dial.to)
    return modifiers.publish_vision(dials, dither)
end

function modifiers.set_dial_mine(index, value)
    local dial = modifiers.VISION_DIALS[index]
    if dial == nil then return false, "No such dial." end
    mine_load()
    if value == nil then
        mineAt[index] = nil
    else
        mineAt[index] = OF.util.clamp(tonumber(value) or dial.rest,
            dial.from, dial.to)

        if modifiers.vision_mine_state(index) == nil then mineAt[index] = nil end
    end
    return mine_store()
end

function modifiers.set_dither(on)
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials = modifiers.vision()
    return modifiers.publish_vision(dials, on and true or false)
end

function modifiers.set_dither_mine(state)
    mine_load()
    if state ~= true and state ~= false then state = nil end
    mineDither = state
    if modifiers.vision_mine_state("dither") == nil then mineDither = nil end
    return mine_store()
end

function modifiers.vision_snapshot()
    local packed = gGlobalSyncTable[modifiers.VISION_KEY]
    if type(packed) ~= "string" then return "" end
    return packed
end

function modifiers.borrow_vision(packed)
    if not OF.util.is_host() then return false end
    if type(packed) ~= "string" then packed = "" end

    local rest = modifiers.vision_pack(vision_defaults())
    if packed ~= "" then
        local dials, dither = modifiers.vision_parse(packed)
        packed = modifiers.vision_pack(dials, dither)
    else
        packed = rest
    end
    local now = modifiers.vision_snapshot()
    if now == packed then return false end

    if now == "" and packed == rest then return false end
    OF.util.publish(modifiers.VISION_KEY, packed)
    return true
end

function modifiers.vision_is_on()
    local rest = modifiers.vision_pack(vision_defaults())
    local now = modifiers.vision_snapshot()
    return now ~= "" and now ~= rest
end

function modifiers.clear_vision()
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials, dither = vision_defaults()
    return modifiers.publish_vision(dials, dither)
end

function modifiers.clear_vision_mine()
    local dials, dither = vision_defaults()
    return keep_mine(dials, dither)
end

function modifiers.forget_vision_mine()
    mine_load()
    mineAt, mineDither = {}, nil
    return mine_store()
end

local function preset_dials(name)
    local look = modifiers.look_named(name)
    if look == nil then return nil end

    local dials, dither = vision_defaults()
    for _, pair in ipairs(look) do
        local flag, value = pair[1], pair[2]
        if flag == modifiers.VISION_DITHER then
            dither = true
        else
            for index, dial in ipairs(modifiers.VISION_DIALS) do
                if dial.flag == flag then
                    dials[index] = OF.util.clamp(value, dial.from, dial.to)
                end
            end
        end
    end
    return dials, dither
end

function modifiers.load_preset(name)
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials, dither = preset_dials(name)
    if dials == nil then return false, "No such preset." end
    return modifiers.publish_vision(dials, dither)
end

function modifiers.load_preset_mine(name)
    local dials, dither = preset_dials(name)
    if dials == nil then return false, "No such preset." end
    return keep_mine(dials, dither)
end

function modifiers.set_vision_here(asker, packed)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("vision") then
        return false, "Your rank cannot do that."
    end

    local dials, dither = modifiers.vision_parse(packed)
    OF.util.publish(modifiers.VISION_KEY, modifiers.vision_pack(dials, dither))
    return true
end

function modifiers.publish_vision(dials, dither)
    local packed = modifiers.vision_pack(dials, dither)
    if OF.util.is_host() then
        OF.util.publish(modifiers.VISION_KEY, packed)

        return true
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("vision", packed)
    end
    return false, "No host to ask yet - try again in a second."
end

hook_on_sync_table_change(gGlobalSyncTable, "ofVision", 0,
    function()
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(modifiers.VISION_KEY) then
            return
        end
        modifiers.wear_look(modifiers.look())
    end)

local lookOver = nil

function modifiers.look_over(look)
    lookOver = look
    return modifiers.wear_look(modifiers.look())
end

function modifiers.look_overridden()
    return lookOver ~= nil
end

function modifiers.look_named(name)
    for _, entry in ipairs(modifiers.LOOKS) do
        if entry.name == name then return entry.look end
    end
    return nil
end

function modifiers.wear_look(look)
    if set_shader_flag_enabled == nil or set_shader_flag_value == nil then
        return false
    end

    if lookOver ~= nil then look = lookOver end

    for flag in pairs(modifiers.shaderHeld) do
        set_shader_flag_value(flag, SHADER_DEFAULTS[flag] or 0.0)
        set_shader_flag_enabled(flag, false)
    end
    modifiers.shaderHeld = {}

    if look == nil then return true end
    for _, pair in ipairs(look) do
        local flag, value = pair[1], pair[2]
        if flag ~= nil then
            set_shader_flag_value(flag, value)
            set_shader_flag_enabled(flag, true)
            modifiers.shaderHeld[flag] = true
        end
    end
    return true
end

local MUSIC_PLAYER = SEQ_PLAYER_LEVEL

modifiers.musicHeld = modifiers.musicHeld or nil

local function fold_u16(value)
    return math.floor(value) & 0xFFFF
end

local function speed_fraction(m)
    local speed = math.abs(tonumber(m ~= nil and m.forwardVel or 0) or 0)
    if speed <= 0 then return 0 end
    if speed >= 48.0 then return 1 end
    return speed / 48.0
end
modifiers.speed_fraction = speed_fraction

function modifiers.hold_music(m)
    local held = modifiers.musicHeld
    if held == nil or MUSIC_PLAYER == nil then return false end

    local tempo = modifiers.setting("music", "tempo", nil)
    local trans = modifiers.setting("music", "trans", nil)

    local low = modifiers.setting("music", "low", nil)
    local high = modifiers.setting("music", "high", nil)
    if low ~= nil and high ~= nil then
        tempo = low + (high - low) * speed_fraction(m)
    end

    if tempo ~= nil then
        local now = OF.util.optional("sequence_player_get_tempo", nil, MUSIC_PLAYER)
        if type(now) ~= "number" then return false end

        if held.wroteTempo == nil or now ~= held.wroteTempo then held.tempo = now end
        held.wroteTempo = math.floor(held.tempo * tempo / 100)

        if held.wroteTempo < 1 then held.wroteTempo = 1 end
        OF.util.optional("sequence_player_set_tempo", nil, MUSIC_PLAYER,
            held.wroteTempo)
    end

    if trans ~= nil then
        local now = OF.util.optional("sequence_player_get_transposition", nil,
            MUSIC_PLAYER)
        if type(now) ~= "number" then return false end
        if held.wroteTrans == nil or now ~= held.wroteTrans then
            held.trans = now
        end
        held.wroteTrans = fold_u16(held.trans + trans)
        OF.util.optional("sequence_player_set_transposition", nil, MUSIC_PLAYER,
            held.wroteTrans)
    end

    return true
end

function modifiers.wear_music(on)
    if MUSIC_PLAYER == nil then return false end
    if OF.util.binding("sequence_player_set_tempo") == nil then return false end

    if not on then
        local held = modifiers.musicHeld
        if held == nil then return true end

        if held.wroteTempo ~= nil then
            OF.util.optional("sequence_player_set_tempo", nil, MUSIC_PLAYER,
                held.tempo)
        end
        if held.wroteTrans ~= nil then
            OF.util.optional("sequence_player_set_transposition", nil,
                MUSIC_PLAYER, held.trans)
        end
        modifiers.musicHeld = nil
        return true
    end

    if modifiers.musicHeld == nil then modifiers.musicHeld = {} end
    return modifiers.hold_music()
end

modifiers.hudHeld = modifiers.hudHeld or nil

local function hud_wanted_gone()
    if modifiers.hudHeld then return true end
    if OF.util.asks(OF.camera, "holds_hud") and OF.camera.holds_hud() then
        return true
    end
    return false
end

function modifiers.settle_hud()
    if OF.util.binding("hud_hide") == nil then return false end
    if hud_wanted_gone() then
        OF.util.optional("hud_hide", nil)
    else
        OF.util.optional("hud_show", nil)
    end
    return true
end

function modifiers.wear_hud(on)
    if OF.util.binding("hud_hide") == nil then return false end

    modifiers.hudHeld = on and true or nil
    return modifiers.settle_hud()
end

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.settle_hud() end)

modifiers.flatHeld = modifiers.flatHeld or nil

function modifiers.wear_flat(on)
    if OF.util.binding("set_shading_fullbright_enabled") == nil then return false end

    if not on then
        if modifiers.flatHeld == nil then return true end
        OF.util.optional("set_shading_fullbright_enabled", nil, modifiers.flatHeld)
        modifiers.flatHeld = nil
        return true
    end

    if modifiers.flatHeld == nil then
        modifiers.flatHeld =
            OF.util.optional("get_shading_fullbright_enabled", false) == true
    end
    OF.util.optional("set_shading_fullbright_enabled", nil, true)
    return true
end

local SHAKE_DECAY = 0x3
local SHAKE_SPEED = 0x8000

function modifiers.hold_quake()
    local mag = modifiers.setting("quake", "mag", nil)
    local hand = modifiers.setting("quake", "hand", nil)
    if mag == nil and hand == nil then return false end

    if hand ~= nil then
        OF.util.optional("set_handheld_shake", nil, hand)
    end

    if mag == nil then return true end
    if OF.util.binding("set_camera_pitch_shake") == nil then return false end

    local half = math.floor(mag / 2)
    OF.util.optional("set_camera_pitch_shake", nil, mag, SHAKE_DECAY, SHAKE_SPEED)
    OF.util.optional("set_camera_yaw_shake", nil, half, SHAKE_DECAY, SHAKE_SPEED)
    OF.util.optional("set_camera_roll_shake", nil, half, SHAKE_DECAY, SHAKE_SPEED)
    return true
end

local ANIM_NORMAL = 0x10000

function modifiers.wear_animation(m)
    local rate = modifiers.setting("anim", "rate", nil)
    if rate == nil or m == nil then return false end

    local obj = m.marioObj
    if obj == nil or obj.header == nil then return false end
    local gfx = obj.header.gfx
    if gfx == nil or gfx.animInfo == nil then return false end

    gfx.animInfo.animAccel = math.max(1, math.floor(ANIM_NORMAL * rate / 100))
    return true
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    modifiers.wear_animation(m)
end)

function modifiers.face_note()
    if modifiers.setting("face", "hands", nil) ~= MARIO_HAND_FISTS then
        return nil
    end
    return OF.lang.t("The hands open in water and under a wing cap.")
end

local function set_joint(angle, three)
    if angle == nil then return end
    angle.x = three ~= nil and (three[1] or 0) or 0
    angle.y = three ~= nil and (three[2] or 0) or 0
    angle.z = three ~= nil and (three[3] or 0) or 0
end

function modifiers.wear_body(m)
    if m == nil then return false end
    local did = false

    local body = m.marioBodyState

    local state = modifiers.setting("made", "state", nil)
    if state ~= nil and body ~= nil and body.modelState ~= nil then
        body.modelState = body.modelState | state
        did = true
    end

    local eyes = modifiers.setting("face", "eyes", nil)
    if eyes ~= nil and body ~= nil then
        body.eyeState = eyes
        local hands = modifiers.setting("face", "hands", nil)
        if hands ~= nil then body.handState = hands end
        did = true
    end

    local yielding = m.playerIndex == 0 and OF.util.limping == true
    local torso = modifiers.setting("posture", "torso", nil)
    local head = modifiers.setting("posture", "head", nil)
    if (torso ~= nil or head ~= nil) and body ~= nil and not yielding then
        body.allowPartRotation = true
        set_joint(body.torsoAngle, torso)
        set_joint(body.headAngle, head)
        did = true
    end

    local particle = modifiers.setting("trail", "particle", nil)
    if particle ~= nil and m.particleFlags ~= nil then
        m.particleFlags = m.particleFlags | particle
        did = true
    end

    return did
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    modifiers.wear_body(m)
end)

function modifiers.clear_posture()
    for index = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[index]
        local body = m ~= nil and m.marioBodyState or nil

        if index == 0 and OF.util.limping == true then body = nil end
        if body ~= nil then
            body.allowPartRotation = false
            set_joint(body.torsoAngle, nil)
            set_joint(body.headAngle, nil)
        end
    end
    return true
end

local NO_TINT = 255

function modifiers.wear_tint(on)
    if OF.util.binding("set_vertex_color") == nil then return false end

    local tint = nil
    if on then tint = modifiers.setting("tint", "tint", nil) end

    for index = 0, 2 do
        local value = NO_TINT
        if tint ~= nil and tint[index + 1] ~= nil then value = tint[index + 1] end
        OF.util.optional("set_vertex_color", nil, index, value)
    end
    return true
end

local function mercy_refuses(hazardType)
    if hazardType == HAZARD_TYPE_LAVA_FLOOR
        or hazardType == HAZARD_TYPE_LAVA_WALL then
        return modifiers.setting("mercy", "lava", false) == true
    end
    if hazardType == HAZARD_TYPE_QUICKSAND then
        return modifiers.setting("mercy", "sand", false) == true
    end

    return false
end

hook_event(HOOK_ALLOW_HAZARD_SURFACE, function(m, hazardType)
    if m == nil or m.playerIndex ~= 0 then return end

    if mercy_refuses(hazardType) then return false end
end)

function modifiers.mercy_note()
    if modifiers.level("mercy") <= 0 then return nil end
    if modifiers.setting("mercy", "lava", false) ~= true then return nil end
    if modifiers.level("lava") <= 0 then return nil end
    return OF.lang.t("The floor is lava is on - it will not burn either.")
end

function modifiers.wear_shadows(on)
    if not OF.util.asks(OF.rules, "set_shadows") then return false end
    return OF.rules.set_shadows(on) == true
end

function modifiers.hold_camlag()
    local pos = modifiers.setting("camlag", "pos", nil)
    local foc = modifiers.setting("camlag", "foc", nil)
    if pos == nil or gLakituState == nil then return false end

    gLakituState.posHSpeed = pos
    gLakituState.posVSpeed = pos
    gLakituState.focHSpeed = foc
    gLakituState.focVSpeed = foc
    return true
end

local LIGHT_FULL = 255

modifiers.shadingHeld = modifiers.shadingHeld or false

function modifiers.wear_shading(on)
    if OF.util.binding("set_lighting_color") == nil then return false end

    if not on then
        if not modifiers.shadingHeld then return true end
        modifiers.shadingHeld = false
        for index = 0, 2 do
            OF.util.optional("set_lighting_color", nil, index, LIGHT_FULL)
            OF.util.optional("set_lighting_color_ambient", nil, index, LIGHT_FULL)
        end
        return true
    end

    local dir = modifiers.setting("shading", "dir", nil)
    local amb = modifiers.setting("shading", "amb", nil)
    if dir == nil or amb == nil then return false end

    modifiers.shadingHeld = true
    for index = 0, 2 do

        OF.util.optional("set_lighting_color", nil, index, dir[index + 1])
        OF.util.optional("set_lighting_color_ambient", nil, index, amb[index + 1])
    end
    return true
end

modifiers.showHeld = modifiers.showHeld or false

function modifiers.wear_lightshow(world, light, shadow)
    if OF.util.binding("set_vertex_color") == nil then return false end

    if world == nil and light == nil and shadow == nil then
        if not modifiers.showHeld then return true end
        modifiers.showHeld = false
        for index = 0, 2 do
            OF.util.optional("set_vertex_color", nil, index, NO_TINT)
            OF.util.optional("set_lighting_color", nil, index, LIGHT_FULL)
            OF.util.optional("set_lighting_color_ambient", nil, index, LIGHT_FULL)
        end
        return true
    end

    modifiers.showHeld = true

    local function part(colour, which)
        return math.floor(OF.util.clamp(colour[which] or 255, 0, 255))
    end

    if world ~= nil then
        OF.util.optional("set_vertex_color", nil, 0, part(world, "r"))
        OF.util.optional("set_vertex_color", nil, 1, part(world, "g"))
        OF.util.optional("set_vertex_color", nil, 2, part(world, "b"))
    end

    if light ~= nil then
        OF.util.optional("set_lighting_color", nil, 0, part(light, "r"))
        OF.util.optional("set_lighting_color", nil, 1, part(light, "g"))
        OF.util.optional("set_lighting_color", nil, 2, part(light, "b"))
    end
    if shadow ~= nil then
        OF.util.optional("set_lighting_color_ambient", nil, 0, part(shadow, "r"))
        OF.util.optional("set_lighting_color_ambient", nil, 1, part(shadow, "g"))
        OF.util.optional("set_lighting_color_ambient", nil, 2, part(shadow, "b"))
    end
    return true
end

local function quiet_mask(level)
    local function bit(name)
        local value = _G[name]
        if type(value) ~= "number" then return 0 end
        return 1 << value
    end

    local objects = bit("SOUND_BANK_OBJ") | bit("SOUND_BANK_OBJ2")
    if level <= 1 then return objects end

    local world = objects | bit("SOUND_BANK_ENV") | bit("SOUND_BANK_GENERAL")
        | bit("SOUND_BANK_GENERAL2") | bit("SOUND_BANK_AIR")
    if level <= 2 then return world end

    return world | bit("SOUND_BANK_ACTION") | bit("SOUND_BANK_MOVING")
        | bit("SOUND_BANK_MARIO_VOICE") | bit("SOUND_BANK_LUIGI_VOICE")
        | bit("SOUND_BANK_WARIO_VOICE") | bit("SOUND_BANK_TOAD_VOICE")
end

modifiers.quietHeld = modifiers.quietHeld or nil

function modifiers.wear_quiet(on)
    if OF.util.binding("sound_banks_disable") == nil then return false end

    if not on then
        if modifiers.quietHeld == nil then return true end

        OF.util.optional("sound_banks_enable", nil, 0, modifiers.quietHeld)
        modifiers.quietHeld = nil
        return true
    end

    local level = modifiers.level("quiet")
    if level <= 0 then return false end
    modifiers.quietHeld = quiet_mask(level)
    OF.util.optional("sound_banks_disable", nil, 0, modifiers.quietHeld)
    return true
end

function modifiers.step_name(key, packed)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    if modifiers.step_count(entry) <= 1 then return nil end

    local level
    if packed ~= nil then
        level = modifiers.parse(packed)[key] or 0
    else
        level = modifiers.level(key)
    end
    if level <= 0 then return nil end

    local step = (entry.levels or {})[level]
    return step ~= nil and step.name or nil
end

function modifiers.label(packed)
    local list = modifiers.names(packed)
    if #list == 0 then return OF.lang.t("none") end
    local said = {}
    for _, name in ipairs(list) do
        local entry = nil
        for _, candidate in ipairs(modifiers.LIST) do
            if candidate.name == name then entry = candidate break end
        end
        local step = entry ~= nil and modifiers.step_name(entry.key, packed) or nil
        if step ~= nil then
            table.insert(said, OF.lang.fill("@: @", OF.lang.t(name), OF.lang.t(step)))
        else
            table.insert(said, OF.lang.t(name))
        end
    end
    return table.concat(said, ", ")
end

local function pack_parts(set)
    local list = {}
    for _, entry in ipairs(modifiers.LIST) do
        local level = set[entry.key]
        if level ~= nil and level > 0 then
            local id = entry.id or entry.key

            if level <= 1 then
                table.insert(list, id)
            else
                table.insert(list, id .. math.floor(level))
            end
        end
    end

    return list
end

function modifiers.pack(set)
    return table.concat(pack_parts(set))
end

local WIRE_CHUNK = 160

local WIRE_KEYS = { "ofMods", "ofMods2", "ofMods3", "ofMods4" }

modifiers.WIRE_CHUNK = WIRE_CHUNK
modifiers.WIRE_KEYS = WIRE_KEYS

local function publish_parts(parts)
    local chunks = OF.util.chunk_parts(parts, WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then
        OF.util.chat("\\#ff6060\\Too many modifiers to send at once ("
            .. tostring(#parts) .. " of them).")
        return false
    end
    local ok = true
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then ok = false end
    end
    return ok
end

local function publish(set)
    if OF.util.asks(OF.cheats, "forget_room_scale") then
        OF.cheats.forget_room_scale()
    end
    return publish_parts(pack_parts(set))
end

function modifiers.publish_text(text)
    if not OF.util.is_host() then return false end
    return publish(modifiers.parse(text))
end

function modifiers.publish_round(text)
    if not OF.util.is_host() then return false end
    local packed = modifiers.pack(modifiers.parse(text or ""))
    if #packed > WIRE_CHUNK then
        OF.util.chat("\\#ff6060\\The round's modifier set is too long to send.")
        return false
    end
    return OF.util.publish(modifiers.ROUND_KEY, packed)
end

function modifiers.set_round_level(key, level)
    if not OF.util.is_host() then return false end
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false end
    local set = modifiers.parse(modifiers.round_text())
    level = math.floor(tonumber(level) or 0)
    if level > 0 then
        set[key] = math.min(level, modifiers.step_count(entry))
    else
        set[key] = nil
    end
    return modifiers.publish_round(modifiers.pack(set))
end

local LEARNABLE = {
    ACT_LONG_JUMP, ACT_BACKFLIP, ACT_SIDE_FLIP,
    ACT_DIVE, ACT_GROUND_POUND, ACT_TRIPLE_JUMP, ACT_DOUBLE_JUMP,
}

local BECOMES = {
    [ACT_LONG_JUMP] = ACT_JUMP, [ACT_BACKFLIP] = ACT_JUMP,
    [ACT_SIDE_FLIP] = ACT_JUMP, [ACT_DOUBLE_JUMP] = ACT_JUMP,
    [ACT_TRIPLE_JUMP] = ACT_JUMP, [ACT_DIVE] = ACT_JUMP,
    [ACT_GROUND_POUND] = ACT_FREEFALL,
}

local MOVE_NAMES = {
    [ACT_LONG_JUMP] = "The long jump",
    [ACT_BACKFLIP] = "The backflip",
    [ACT_SIDE_FLIP] = "The side flip",
    [ACT_DIVE] = "The dive",
    [ACT_GROUND_POUND] = "The ground pound",
    [ACT_TRIPLE_JUMP] = "The triple jump",
    [ACT_DOUBLE_JUMP] = "The double jump",
}

function modifiers.move_name(action)
    return MOVE_NAMES[action]
end

modifiers.LEARN_KEY = "ofLearn"
local function learning()
    local packed = gGlobalSyncTable[modifiers.LEARN_KEY]
    if type(packed) ~= "string" or packed == "" then return nil end
    local seed, count = string.match(packed, "^(%d+),(%d+)$")
    if seed == nil then return nil end
    return tonumber(seed), tonumber(count)
end

function modifiers.learned()
    local _, count = learning()
    return count or 0
end

function modifiers.learnable_count()
    return #LEARNABLE
end

function modifiers.learn_order(seed)
    local order = {}
    for index, action in ipairs(LEARNABLE) do order[index] = action end
    local state = math.floor(seed or 1) % 2147483648
    for i = #order, 2, -1 do
        state = (1664525 * state + 1013904223) % 4294967296
        local j = math.floor(state / 65536) % i + 1
        order[i], order[j] = order[j], order[i]
    end
    return order
end

function modifiers.begin_learning()
    if not OF.util.is_host() then return false end
    if learning() ~= nil then return true end
    local now = OF.util.optional("get_global_timer", 1) or 1
    OF.util.publish(modifiers.LEARN_KEY,
        tostring(math.floor(now) % 2147483647 + 1) .. ",0")
    return true
end

function modifiers.clear_learning()
    if not OF.util.is_host() then return false end
    OF.util.publish(modifiers.LEARN_KEY, nil)
    return true
end

function modifiers.learn_one()
    if not OF.util.is_host() then return nil end
    local seed, count = learning()
    if seed == nil then return nil end
    if count >= #LEARNABLE then return nil end

    OF.util.publish(modifiers.LEARN_KEY, tostring(seed) .. "," .. (count + 1))
    local order = modifiers.learn_order(seed)
    return order[count + 1]
end

function modifiers.learn_note()
    local level = modifiers.level("learn")
    if level <= 0 then return nil end
    local _, count = learning()
    if count == nil then return nil end
    return OF.lang.fill("@ of @ moves back", tostring(count),
        tostring(#LEARNABLE))
end

function modifiers.moves_taken()
    local learnLevel = modifiers.level("learn")
    if learnLevel > 0 then
        local seed, count = learning()
        if seed == nil then return nil end
        local order = modifiers.learn_order(seed)
        local taken = {}
        for index = count + 1, #order do
            local action = order[index]

            if not (learnLevel >= 2 and action == ACT_DOUBLE_JUMP) then
                taken[action] = BECOMES[action] or ACT_JUMP
            end
        end
        return taken
    end

    return nil
end

function modifiers.substitute_move(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local taken = modifiers.moves_taken()
    if taken == nil then return nil end
    return taken[action]
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return modifiers.substitute_move(m, action)
end)

modifiers.borrowing = false

function modifiers.borrow(fn)
    local was = modifiers.borrowing
    modifiers.borrowing = true
    local ok, err = pcall(fn)
    modifiers.borrowing = was
    if not ok then error(err, 0) end
end

function modifiers.set_text(packed)
    if not OF.util.is_host() then return false end

    if not modifiers.borrowing and OF.util.asks(OF.chaos, "release_all") then
        OF.chaos.release_all()
    end
    publish(modifiers.parse(packed))
    return true
end

function modifiers.text()
    if textNow == nil or textAt ~= wireStamp then
        textAt = wireStamp
        textNow = OF.util.joined(WIRE_KEYS)
    end
    return textNow
end

function modifiers.toggle(key)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end

    local next = modifiers.level(key) + 1
    if next > modifiers.step_count(entry) then next = 0 end
    return modifiers.set_level(key, next)
end

function modifiers.set_level_here(asker, key, level)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    return modifiers.apply_level(key, level, asker)
end

function modifiers.set_level(key, level)
    local entry = modifiers.BY_KEY[key]

    if entry == nil and OF.util.asks(OF.rules, "find")
        and OF.rules.find(key) ~= nil then
        return OF.rules.set(key, level)
    end
    if entry == nil then return false, "No such modifier." end
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end

    if OF.util.is_host() then return modifiers.apply_level(key, level, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("modset", key, level)
    end
    return false, "No host to ask yet - try again in a second."
end

function modifiers.apply_level(key, level, askerLocal)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end

    level = math.floor(tonumber(level) or 0)
    if level < 0 then level = 0 end
    if level > modifiers.step_count(entry) then
        return false, "That modifier does not go that far."
    end

    if OF.util.asks(OF.chaos, "release") then OF.chaos.release(key) end

    local set = modifiers.parse(modifiers.text())
    if level <= 0 then
        set[key] = nil
    else
        set[key] = level

        for _, other in ipairs(entry.excludes or {}) do set[other] = nil end
    end

    publish(set)

    if modifiers.round_holds() and level > 0 then

        if askerLocal ~= nil and OF.util.asks(OF.notify, "send_to") then
            OF.notify.send_to(network_global_index_from_local(askerLocal),
                "A round has the modifiers - this takes effect when it ends.",
                "quiet", 4)
        end
    end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, modifiers.change_line(key, level))
    end
    return true
end

function modifiers.clear_here(asker)
    if not OF.util.is_host() then return false, "Only the host clears these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    return modifiers.clear_now(asker)
end

function modifiers.clear()
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    if not modifiers.any() then return false, "Nothing is on." end
    if OF.util.is_host() then return modifiers.clear_now(0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("modclear")
    end
    return false, "No host to ask yet - try again in a second."
end

function modifiers.clear_now(askerLocal)
    if not modifiers.any() then return false, "Nothing is on." end
    publish({})
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, OF.lang.t("everything off"))
    end
    return true
end

local applied = {}

local function sync_world()
    for _, entry in ipairs(modifiers.LIST) do
        local wanted = (modifiers.in_force(entry.key))
        local have = applied[entry.key] or 0

        if have ~= 0 and have ~= wanted then
            if entry.restore ~= nil then entry.restore() end
            applied[entry.key] = nil
            have = 0
        end
        if wanted ~= 0 and have == 0 then
            if entry.world ~= nil then entry.world(wanted) end
            applied[entry.key] = wanted
        end
    end

    modifiers.wear_look(modifiers.look())
end

modifiers.sync_world = sync_world

function modifiers.resync()

    for _, entry in ipairs(modifiers.LIST) do
        if (modifiers.in_force(entry.key)) ~= 0 then applied[entry.key] = nil end
    end
    sync_world()
    return true
end

function modifiers.mine_changed()
    if OF.util.asks(OF.cheats, "forget_room_scale") then
        OF.cheats.forget_room_scale()
    end
    if modifiers.sync_world ~= nil then modifiers.sync_world() end
end

modifiers.roundWas = nil

function modifiers.watch_the_round()
    local now = modifiers.round_holds() == true
    if now == modifiers.roundWas then return false end
    modifiers.roundWas = now
    modifiers.mine_changed()
    return true
end

hook_event(HOOK_UPDATE, function() modifiers.watch_the_round() end)

for _, wireKey in ipairs(WIRE_KEYS) do
    hook_on_sync_table_change(gGlobalSyncTable, wireKey, wireKey, function(tag, prevValue)

        wireStamp = wireStamp + 1
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(wireKey) then
            return
        end
        sync_world()

        local credited = OF.util.asks(OF.notify, "credits_on")
            and OF.notify.credits_on()
        local putBack = OF.util.asks(OF.guard, "putting_back")
            and OF.guard.putting_back()
        if OF.util.asks(OF.notify, "show") and not credited and not putBack then
            local line = modifiers.changed_line(
                OF.util.joined(WIRE_KEYS, wireKey, prevValue), modifiers.text())
            if line ~= nil then
                OF.notify.show("Modifiers: @", "quiet", 3, line)
            end
        end
    end)
end

hook_on_sync_table_change(gGlobalSyncTable, modifiers.ROUND_KEY,
    modifiers.ROUND_KEY, function()
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(modifiers.ROUND_KEY) then
            return
        end

        sync_world()
    end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end
    if data.ofp ~= modifiers.PACKET then return end
    if not OF.util.from_host(data) then return end
    if data.what == "clearmine" then

        local had = modifiers.mine_any()
        modifiers.clear_mine()
        if had then
            OF.notify.show("The host cleared your own modifier settings",
                "info", 4)
        end
    end

    if data.what == "clearvision" then

        local had = modifiers.vision_mine_any()
        modifiers.forget_vision_mine()
        if had then
            OF.notify.show("The host cleared the picture you built", "info", 4)
        end
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    for key in pairs(applied) do applied[key] = nil end
    sync_world()

    modifiers.coin_floor_live()
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not modifiers.any() then return end

    local set = modifiers.active()
    for _, entry in ipairs(modifiers.LIST) do
        if set[entry.key] and entry.apply ~= nil then entry.apply(m) end
    end
end)

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    if m == nil or m.playerIndex ~= 0 then return end

    return modifiers.setting("floor", "class", nil)
end)

do

local TERRAIN_COUNT = 8
local terrainBack = nil

local function terrain_lookup()
    if terrainBack ~= nil then return terrainBack end

    local bases = {
        "SOUND_ACTION_TERRAIN_JUMP",
        "SOUND_ACTION_TERRAIN_LANDING",
        "SOUND_ACTION_TERRAIN_STEP",
        "SOUND_ACTION_TERRAIN_BODY_HIT_GROUND",
        "SOUND_ACTION_TERRAIN_STEP_TIPTOE",
        "SOUND_ACTION_TERRAIN_STUCK_IN_GROUND",
        "SOUND_ACTION_TERRAIN_HEAVY_LANDING",
        "SOUND_MOVING_TERRAIN_SLIDE",
        "SOUND_MOVING_TERRAIN_RIDING_SHELL",
    }

    local map = {}
    for _, name in ipairs(bases) do
        local base = _G[name]
        if type(base) == "number" then
            for terrain = 0, TERRAIN_COUNT - 1 do
                map[base + (terrain << 16)] = base
            end
        end
    end
    terrainBack = map
    return map
end

function modifiers.footstep_for(soundBits)
    if type(soundBits) ~= "number" then return nil end
    local wanted = modifiers.setting("steps", "terrain", nil)
    if wanted == nil then return nil end

    local base = terrain_lookup()[soundBits]
    if base == nil then return nil end

    local swapped = base + (wanted << 16)
    if swapped == soundBits then return nil end
    return swapped
end

hook_event(HOOK_ON_PLAY_SOUND, function(soundBits, pos)
    local swapped = modifiers.footstep_for(soundBits)
    local pitched = modifiers.pitch_for(swapped or soundBits, pos)
    if pitched ~= nil then return pitched end
    return swapped
end)
end

do

local MAX_LANTERNS = 16

local lanterns = {}
local saidLanternTaken = false

local LANTERN_HEIGHT = 90

function modifiers.lantern_count()
    local count = 0
    for _ in pairs(lanterns) do count = count + 1 end
    return count
end

function modifiers.clear_lanterns()
    local had = next(lanterns) ~= nil
    for localIndex, id in pairs(lanterns) do
        OF.util.optional("le_remove_light", nil, id)
        lanterns[localIndex] = nil
    end
    saidLanternTaken = false

    if had and not modifiers.owns_lighting() then
        OF.util.optional("le_set_enabled", nil, false)
    end
    return true
end

function modifiers.lantern_note()
    if modifiers.level("lantern") <= 0 then return nil end
    if modifiers.level("dark") > 0 then return nil end

    return OF.lang.t("Darkness under it - a lamp wants a dark room.")
end

local function lantern_pos(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end

    if OF.util.optional("is_player_active", 0, m) == 0 then return nil end
    return m.pos.x, m.pos.y + LANTERN_HEIGHT, m.pos.z
end

local function lantern_beat(kind, localIndex, rgb, radius, glow)
    if kind == nil then return nil end
    local frame = OF.util.optional("get_global_timer", 0) or 0

    if kind == "gutter" then

        local tick = math.floor(frame / 3) + localIndex * 977
        local n = (tick * 1103515245 + 12345) % 2147483648
        local amount = (n % 1000) / 1000
        return rgb[1], rgb[2], rgb[3], radius, glow * (0.45 + 0.55 * amount)
    end

    if kind == "breathe" then

        local phase = ((frame + localIndex * 11) % 90) / 90
        local swing = math.sin(phase * 2 * math.pi)
        return rgb[1], rgb[2], rgb[3],
            radius * (0.78 + 0.22 * swing), glow * (0.70 + 0.30 * swing)
    end

    if kind == "alarm" then

        local other = (math.floor(frame / 12) + localIndex) % 2 == 1
        if other then
            return 255 - rgb[1], 255 - rgb[2], 255 - rgb[3], radius, glow
        end
        return rgb[1], rgb[2], rgb[3], radius, glow
    end

    return nil
end

local function lantern_byte(value)
    local n = math.floor((value or 0) + 0.5)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

local function lantern_update()
    local step = modifiers.level("lantern")

    if step <= 0 then

        if next(lanterns) ~= nil then modifiers.clear_lanterns() end
        return
    end

    if next(lanterns) == nil and not modifiers.owns_lighting()
        and OF.util.optional("le_is_enabled", false) then
        if not saidLanternTaken then
            saidLanternTaken = true
            OF.notify.show("Another mod owns the lighting - the lanterns are off",
                "warn", 5)
        end
        return
    end

    local rgb = modifiers.setting("lantern", "light", nil)
    if rgb == nil then return end
    local radius = modifiers.setting("lantern", "radius", 1200)
    local glow = modifiers.setting("lantern", "glow", 1.2)
    local beat = modifiers.setting("lantern", "beat", nil)
    local spread = modifiers.setting("lantern", "spread", false)

    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local localIndex = entry.localIndex
        if modifiers.lantern_count() < MAX_LANTERNS or lanterns[localIndex] ~= nil then
            local x, y, z = lantern_pos(localIndex)
            if x ~= nil then
                here[localIndex] = true
                local id = lanterns[localIndex]

                if id == nil or not OF.util.optional("le_light_exists", false, id) then
                    id = OF.util.optional("le_add_light", nil,
                        x, y, z, rgb[1], rgb[2], rgb[3], radius, glow)
                    lanterns[localIndex] = id

                    if spread and id ~= nil then
                        OF.util.optional("le_set_light_use_surface_normals",
                            nil, id, false)
                    end
                else
                    OF.util.optional("le_set_light_pos", nil, id, x, y, z)

                    local r, g, b, wide, bright =
                        lantern_beat(beat, localIndex, rgb, radius, glow)
                    if r ~= nil then
                        OF.util.optional("le_set_light_color", nil, id,
                            lantern_byte(r), lantern_byte(g), lantern_byte(b))

                        OF.util.optional("le_set_light_radius", nil, id, wide)
                        OF.util.optional("le_set_light_intensity", nil, id, bright)
                    end
                end
            end
        end
    end

    for localIndex, id in pairs(lanterns) do
        if not here[localIndex] then
            OF.util.optional("le_remove_light", nil, id)
            lanterns[localIndex] = nil
        end
    end
end

modifiers.lantern_update = lantern_update

hook_event(HOOK_UPDATE, lantern_update)
end

do

local GAS_EVERYWHERE = 30000

function modifiers.gas_level()
    if modifiers.level("gas") <= 0 then return nil end

    if modifiers.setting("gas", "everywhere", false) == true then
        return GAS_EVERYWHERE
    end

    local share = modifiers.setting("gas", "share", nil)
    if share == nil then return nil end
    if not (OF.util.asks(OF.ground, "lowest") and OF.util.asks(OF.ground, "highest")) then
        return nil
    end

    local low = OF.ground.lowest()
    local high = OF.ground.highest()
    if low == nil or high == nil or high <= low then return nil end
    return low + (high - low) * share
end

function modifiers.gas_reaches()
    local ours = modifiers.gas_level()
    if ours == nil then return false end
    if find_poison_gas_level == nil then return true end

    local m = gMarioStates[0]
    local x, z = 0, 0
    if m ~= nil and m.pos ~= nil then x, z = m.pos.x, m.pos.z end

    local ok, answer = pcall(find_poison_gas_level, x, z)

    if not ok or type(answer) ~= "number" then return true end
    return answer >= ours
end

function modifiers.gas_note()
    if modifiers.level("gas") <= 0 then return nil end
    if modifiers.gas_level() == nil then
        return OF.lang.t("This level's floors are not measured yet.")
    end
    if not modifiers.gas_reaches() then
        return OF.lang.t("This course will not take gas - nothing happens.")
    end
    if modifiers.setting("gas", "everywhere", false) == true then
        return OF.lang.t("Everywhere - eighteen seconds from full.")
    end
    if modifiers.level("made") > 0 then

        return OF.lang.t("Metal bodies do not breathe it.")
    end
    return nil
end

function modifiers.clear_gas()
    return true
end

hook_event(HOOK_ON_FIND_POISON_GAS_LEVEL, function(x, z, current)

    if modifiers.gasHushed then return nil end

    local ours = modifiers.gas_level()
    if ours == nil then return nil end
    if type(current) == "number" and current > ours then return nil end
    return ours
end)
end

do

local MAX_CLUSTER_PENDING = 6

local CLUSTER_AROUND = 8

local CLUSTER_GAP = 5

local clusters = {}

local poundWas = {}

function modifiers.cluster_pending()
    return #clusters
end

function modifiers.clear_cluster()
    for index = #clusters, 1, -1 do clusters[index] = nil end
    for key in pairs(poundWas) do poundWas[key] = nil end
    return true
end

local function cluster_now()
    return OF.util.optional("get_global_timer", 0) or 0
end

function modifiers.begin_cluster(x, y, z)
    local rings = modifiers.setting("cluster", "rings", nil)
    if rings == nil then return false end
    if x == nil or y == nil or z == nil then return false end

    while #clusters >= MAX_CLUSTER_PENDING do table.remove(clusters, 1) end

    table.insert(clusters, {
        x = x, y = y, z = z,
        rings = rings,
        reach = modifiers.setting("cluster", "reach", 340),
        ring = 0,
        at = cluster_now(),
    })
    return true
end

local function cluster_ring(spot, ring)
    local radius = spot.reach * ring
    for index = 0, CLUSTER_AROUND - 1 do
        local angle = index * 2 * math.pi / CLUSTER_AROUND
        OF.util.optional("spawn_non_sync_object", nil,
            id_bhvExplosion, E_MODEL_EXPLOSION,
            spot.x + math.sin(angle) * radius,
            spot.y + 30,
            spot.z + math.cos(angle) * radius,
            nil)
    end
end

local function cluster_update()
    if #clusters == 0 then return end

    if modifiers.level("cluster") <= 0 then
        modifiers.clear_cluster()
        return
    end

    local now = cluster_now()
    for index = #clusters, 1, -1 do
        local spot = clusters[index]
        if now - spot.at >= spot.ring * CLUSTER_GAP then
            spot.ring = spot.ring + 1
            cluster_ring(spot, spot.ring)
            if spot.ring >= spot.rings then table.remove(clusters, index) end
        end
    end
end

modifiers.cluster_update = cluster_update

function modifiers.watch_the_pound(m)
    if m == nil then return false end
    if modifiers.level("cluster") <= 0 then return false end

    local landing = _G["ACT_GROUND_POUND_LAND"]
    if landing == nil then return false end

    local index = m.playerIndex or 0
    local was = poundWas[index]
    poundWas[index] = m.action

    if m.action ~= landing or was == landing then return false end
    if m.pos == nil then return false end
    return modifiers.begin_cluster(m.pos.x, m.pos.y, m.pos.z)
end

hook_event(HOOK_MARIO_UPDATE, function(m) modifiers.watch_the_pound(m) end)
hook_event(HOOK_UPDATE, cluster_update)
end

local function room_middle()
    local sumX, sumY, sumZ, count = 0, 0, 0, 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and OF.util.optional("is_player_active", 0, m) ~= 0 then
            sumX = sumX + m.pos.x
            sumY = sumY + m.pos.y
            sumZ = sumZ + m.pos.z
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sumX / count, sumY / count, sumZ / count, count
end

local function room_area()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if type(np.currAreaIndex) ~= "number" then return nil end
    return np.currAreaIndex
end

do

local WHIRL_SLOT = 0

local LAST_AREA = 15

local wroteAt = nil

local function whirl_area()
    local area = room_area()
    if area == nil then return nil end
    if area < 0 or area > LAST_AREA then return nil end
    return area
end

function modifiers.clear_whirlpool()
    if wroteAt == nil then return false end
    if wroteAt == whirl_area() then
        OF.util.optional("set_whirlpools", nil, 0, 0, 0, 0, wroteAt, WHIRL_SLOT)
    end
    wroteAt = nil
    return true
end

function modifiers.whirl_note()
    if modifiers.level("whirl") <= 0 then return nil end
    if modifiers.true_swim_on() then return nil end
    return OF.lang.t("Only somebody swimming feels this.")
end

function modifiers.whirlpool_area()
    return wroteAt
end

local function whirl_update()
    local strength = modifiers.setting("whirl", "pull", nil)
    if strength == nil then

        if wroteAt ~= nil then modifiers.clear_whirlpool() end
        return
    end

    local area = whirl_area()
    if area == nil then return end
    local x, y, z = room_middle()
    if x == nil then return end

    OF.util.optional("set_whirlpools", nil, x, y, z, strength, area, WHIRL_SLOT)
    wroteAt = area
end

modifiers.whirl_update = whirl_update

hook_event(HOOK_UPDATE, whirl_update)
end

do

local anchor = nil

local riders = {}

local function anchor_alive()
    return anchor ~= nil and anchor.activeFlags ~= 0
end

function modifiers.clear_carousel()
    for localIndex in pairs(riders) do
        local m = gMarioStates[localIndex]
        if m ~= nil and m.marioObj ~= nil then m.marioObj.platform = nil end
        riders[localIndex] = nil
    end
    if anchor_alive() then
        OF.util.optional("obj_mark_for_deletion", nil, anchor)
    end
    anchor = nil
    return true
end

function modifiers.carousel_note()
    if modifiers.level("carousel") <= 0 then return nil end
    local _, _, _, count = room_middle()
    if count ~= nil and count > 1 then return nil end
    return OF.lang.t("Alone in this area there is nothing to swing around but you.")
end

function modifiers.carousel_riders()
    local count = 0
    for _ in pairs(riders) do count = count + 1 end
    return count
end

function modifiers.carousel_anchor()
    if not anchor_alive() then return nil end
    return anchor
end

local function carousel_update()
    local rate = modifiers.setting("carousel", "spin", nil)
    if rate == nil then

        if anchor ~= nil or next(riders) ~= nil then modifiers.clear_carousel() end
        return
    end

    local x, y, z = room_middle()
    if x == nil then return end

    if not anchor_alive() then

        for localIndex in pairs(riders) do
            local rider = gMarioStates[localIndex]
            if rider ~= nil and rider.marioObj ~= nil then
                rider.marioObj.platform = nil
            end
            riders[localIndex] = nil
        end
        anchor = OF.util.optional("spawn_non_sync_object", nil,
            id_bhvStaticObject, E_MODEL_NONE, x, y, z, nil)
        if not anchor_alive() then
            anchor = nil
            return
        end
    end

    anchor.oPosX, anchor.oPosY, anchor.oPosZ = x, y, z

    anchor.oVelX, anchor.oVelZ = 0, 0
    anchor.oAngleVelYaw = rate
    anchor.oAngleVelPitch, anchor.oAngleVelRoll = 0, 0

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    if OF.util.optional("is_player_active", 0, m) == 0 then return end

    if m.marioObj.platform ~= nil then return end

    m.marioObj.platform = anchor
    riders[0] = true
end

modifiers.carousel_update = carousel_update

hook_event(HOOK_UPDATE, carousel_update)
end

do

local BLIND = { r = 8, g = 8, b = 10 }

function modifiers.blinder_gap(width, height)
    local across = modifiers.setting("blinders", "across", nil)
    local down = modifiers.setting("blinders", "down", nil)
    if across == nil or down == nil then return nil end
    if width == nil or height == nil or width <= 0 or height <= 0 then return nil end

    local gapW = math.floor(width * OF.util.clamp(across, 0, 1) + 0.5)
    local gapH = math.floor(height * OF.util.clamp(down, 0, 1) + 0.5)
    return math.floor((width - gapW) / 2), math.floor((height - gapH) / 2),
        gapW, gapH
end

local function render_blinders()

    if OF.util.menu_has_screen() then return end

    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()
    local x, y, gapW, gapH = modifiers.blinder_gap(width, height)
    if x == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    if y > 0 then
        OF.util.rect(0, 0, width, y, BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if y + gapH < height then
        OF.util.rect(0, y + gapH, width, height - (y + gapH),
            BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if x > 0 then
        OF.util.rect(0, y, x, gapH, BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if x + gapW < width then
        OF.util.rect(x + gapW, y, width - (x + gapW), gapH,
            BLIND.r, BLIND.g, BLIND.b, 255)
    end
end

modifiers.render_blinders = render_blinders

hook_event(HOOK_ON_HUD_RENDER, render_blinders)
end

do

local MOST_HURT = 255

local stungFrom = {}

function modifiers.forget_stings()
    for key in pairs(stungFrom) do stungFrom[key] = nil end
    return true
end

function modifiers.sting_worth(added)
    if added == nil or added <= 0 then return added end

    local wedges = modifiers.setting("sting", "wedges", nil)
    if wedges ~= nil then return math.floor(OF.util.clamp(wedges * 4, 0, MOST_HURT)) end

    local factor = modifiers.setting("sting", "factor", nil)
    if factor == nil then return added end

    return math.floor(OF.util.clamp(added * factor + 0.5, 1, MOST_HURT))
end

local function sting_remember(m)
    if m == nil or m.playerIndex ~= 0 then return end
    stungFrom[m.playerIndex] = m.hurtCounter or 0
end

function modifiers.sting_the_hit(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("sting") <= 0 then return false end

    local from = stungFrom[m.playerIndex]
    if from == nil then return false end

    local now = m.hurtCounter or 0
    local added = now - from
    if added <= 0 then return false end

    local worth = modifiers.sting_worth(added)
    if worth == added then return false end

    m.hurtCounter = math.floor(OF.util.clamp(from + worth, 0, MOST_HURT))

    stungFrom[m.playerIndex] = m.hurtCounter
    return true
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, sting_remember)

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    modifiers.sting_the_hit(m)
    modifiers.tally_coin(m, o, interactType)
end)
end

local PRESS_HUD_Y = 78

function modifiers.press_hud()
    if modifiers.level("budget") <= 0 then return nil end
    local spent = modifiers.presses(0)
    local budget = modifiers.press_budget()

    if budget == nil then
        return tostring(spent), nil, 255, 255, 255
    end

    local left = budget - spent
    local r, g, b = 255, 255, 255
    if left <= 0 then
        r, g, b = 255, 110, 110
    elseif left <= 2 then
        r, g, b = 255, 200, 90
    end
    return tostring(spent), OF.lang.fill("of @", tostring(budget)), r, g, b
end

local function coin_icon()
    if gTextures == nil then return nil end
    local info = gTextures.coin
    if info == nil then return nil end
    return info
end

local function render_coin_health()
    local count, r, g, b = modifiers.coin_health_hud()

    modifiers.hold_vanilla_coins(count ~= nil)
    if count == nil then return end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local beside = 0
    if OF.util.asks(OF.speedrun, "tally_width") then
        beside = OF.speedrun.tally_width()
    end
    OF.util.corner_counter(coin_icon(), count, r, g, b, beside, 1.0)
end

local function render_presses()
    local count, ofWhat, r, g, b = modifiers.press_hud()
    if count == nil then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    djui_hud_set_font(FONT_HUD)
    local scale = 1.15
    local width = djui_hud_measure_text(count) * scale
    local x = (djui_hud_get_screen_width() - width) / 2
    local y = djui_hud_get_screen_height() - PRESS_HUD_Y

    djui_hud_set_color(0, 0, 0, 160)
    djui_hud_print_text(count, x + 2, y + 2, scale)
    djui_hud_set_color(r, g, b, 255)
    djui_hud_print_text(count, x, y, scale)

    djui_hud_set_font(FONT_NORMAL)

    if ofWhat ~= nil then
        OF.util.text(ofWhat, x + width + 6, y + 6, 0.5, r, g, b, 200)
    end
end

hook_event(HOOK_ON_HUD_RENDER, function()
    render_coin_health()
    render_presses()
end)

local VISION_SLOT = "vis_"
modifiers.VISION_SLOTS = 16

local NAME_SEP = "|"
local function slot_read(slot)
    local stored = mod_storage_load(VISION_SLOT .. slot, "")
    if stored == nil or stored == "" then return nil end
    local at = string.find(stored, NAME_SEP, 1, true)
    if at == nil then return nil end
    local name = string.sub(stored, 1, at - 1)
    local packed = string.sub(stored, at + 1)
    if name == "" or packed == "" then return nil end
    return { slot = slot, name = name, packed = packed }
end

function modifiers.saved_visions()
    local list = {}
    for slot = 1, modifiers.VISION_SLOTS do
        local kept = slot_read(slot)
        if kept ~= nil then table.insert(list, kept) end
    end
    return list
end

function modifiers.forget_vision(slot)
    mod_storage_remove(VISION_SLOT .. slot)
    return true
end

function modifiers.keep_vision(name)
    name = string.gsub(tostring(name or ""), "%" .. NAME_SEP, "/")
    name = string.match(name, "^%s*(.-)%s*$")
    if name == "" then

        name = OF.lang.fill("Vision @", #modifiers.saved_visions() + 1)
    end

    local free = nil
    for slot = 1, modifiers.VISION_SLOTS do
        local kept = slot_read(slot)
        if kept ~= nil and kept.name == name then
            free = slot
            break
        end
        if kept == nil and free == nil then free = slot end
    end
    if free == nil then
        return false, "All " .. modifiers.VISION_SLOTS .. " vision slots are full."
    end

    local dials, dither = modifiers.vision_in_force(true)

    local ok = OF.util.store(VISION_SLOT .. free,
        name .. NAME_SEP .. modifiers.vision_pack(dials, dither))
    if not ok then return false, "That did not fit in the save file." end
    return true, name
end

function modifiers.wear_saved(name)
    local needle = string.lower(tostring(name or ""))
    for _, kept in ipairs(modifiers.saved_visions()) do
        if string.lower(kept.name) == needle then
            local dials, dither = modifiers.vision_parse(kept.packed)
            if OF.perms.can("vision") then
                return modifiers.publish_vision(dials, dither)
            end
            return keep_mine(dials, dither)
        end
    end
    return false, "No vision of that name is saved."
end

local VISION_LOBBY_NEED = "vision"
local VISION_MINE_NEED = "costume_self"
local function first_notch(dial)
    local up = dial.rest + dial.step
    if up <= dial.to + 0.0001 then return up end
    return dial.rest - dial.step
end

function modifiers.build_visuals_page(panel)
    local rows = {}

    local roomDials, roomStipple = modifiers.vision()

    local livedDials, livedStipple = modifiers.vision_in_force()

    local seen = modifiers.look_from(modifiers.vision_in_force(true))
    local roomLook = modifiers.vision_look()
    if seen == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("Nothing turned - you see it as the game drew it.")))
    elseif modifiers.vision_mine_any() then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ dial(s) away from rest on your screen, and the lobby has @.",
            #seen, roomLook == nil and 0 or #roomLook)))
    else
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ dial(s) away from rest, and everybody sees them.", #seen)))
    end

    if modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has the picture - every dial comes back after it.")))
    end

    table.insert(rows, panel.with_help(panel.two_box({
        boxes = false,
        name = OF.lang.t("Put every dial back to normal"),
        lobbyNeed = VISION_LOBBY_NEED,
        mineNeed = VISION_MINE_NEED,
        r = 255, g = 200, b = 120,
        onLobby = function() OF.util.report(modifiers.clear_vision()) end,
        onMine = function()
            OF.util.report(modifiers.clear_vision_mine())
            panel.mark_dirty()
        end,
    }), OF.lang.t("A puts the lobby's dials back, Z puts your screen back")))

    if #modifiers.grouped("visuals") > 0 then
        table.insert(rows, panel.label_row(OF.lang.t(
            "What the lobby wears this session - the right-hand box keeps you "
                .. "out of it, and the host or a round takes them off.")))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The dials")),
        "the picture itself, turned one property at a time"))
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        local steps = math.floor((dial.to - dial.from) / dial.step + 0.5)
        local roomValue = roomDials[index] or dial.rest
        local roomTurned = math.abs(roomValue - dial.rest) > 0.001
        local mineSays = modifiers.vision_mine_state(index)
        local mineValue = modifiers.vision_mine_value(index)

        local lived = livedDials[index] or dial.rest
        local livedOn = math.abs(lived - dial.rest) > 0.001

        local r, g, b = 255, 255, 255
        if livedOn then
            r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
        end

        local built = panel.with_help(panel.two_box({
            lobbyOn = roomTurned,

            mineBox = panel.mine_shown(mineSays, roomTurned),
            name = OF.lang.t(dial.name),
            lobbyNeed = VISION_LOBBY_NEED,
            mineNeed = VISION_MINE_NEED,
            r = r, g = g, b = b,

            onLobby = function()
                OF.util.report(modifiers.set_dial(index,
                    roomTurned and dial.rest or first_notch(dial)))
            end,

            onMine = function()
                local want = panel.next_mine(mineSays, roomTurned)
                local value = nil
                if want == false then value = dial.rest
                elseif want == true then value = first_notch(dial) end
                OF.util.report(modifiers.set_dial_mine(index, value))
                panel.mark_dirty()
            end,
        }), OF.lang.t(dial.blurb))

        local column = nil
        if livedOn then
            column = panel.two_box_level(string.format("%.2f", lived),
                mineSays ~= nil)
        end
        if mineSays == false then

            column = panel.two_box_level(OF.lang.t("normal"), true)
        end
        built = panel.level_right(built, livedOn or column ~= nil, column)

        local dialsRoom = (mineSays == nil) and panel.may(VISION_LOBBY_NEED)
        local need = dialsRoom and VISION_LOBBY_NEED or VISION_MINE_NEED
        local handle = roomValue
        if not dialsRoom and mineValue ~= nil then handle = mineValue end
        local at = math.floor((handle - dial.from) / dial.step + 0.5)
        if panel.may(need) then
            built = panel.with_slider(built, at, steps, function(wanted)
                local value = dial.from + wanted * dial.step
                if dialsRoom then
                    OF.util.report(modifiers.set_dial(index, value))
                else

                    OF.util.report(modifiers.set_dial_mine(index, value))
                end
            end)
        else

            built = panel.with_slider(built, at, steps, nil)
        end

        table.insert(rows, built)
    end

    local stippleMine = modifiers.vision_mine_state("dither")
    local stippleR, stippleG, stippleB = 255, 255, 255
    if livedStipple then
        stippleR, stippleG, stippleB =
            OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end
    table.insert(rows, panel.with_help(panel.two_box({
        lobbyOn = roomStipple,
        mineBox = panel.mine_shown(stippleMine, roomStipple),
        name = OF.lang.t("Dithering"),
        lobbyNeed = VISION_LOBBY_NEED,
        mineNeed = VISION_MINE_NEED,
        r = stippleR, g = stippleG, b = stippleB,
        onLobby = function()
            OF.util.report(modifiers.set_dither(not roomStipple))
        end,
        onMine = function()
            OF.util.report(modifiers.set_dither_mine(
                panel.next_mine(stippleMine, roomStipple)))
            panel.mark_dirty()
        end,
    }), OF.lang.t("stipples the picture instead of shading it")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Start from one of these")),
        "a whole look in one press, and the dials above are still yours "
        .. "afterwards"))
    for _, step in ipairs(modifiers.LOOKS) do
        local name = step.name

        table.insert(rows, panel.with_help(
            panel.two_box({
                boxes = false,
                name = OF.lang.t(name),
                lobbyNeed = VISION_LOBBY_NEED,
                mineNeed = VISION_MINE_NEED,
                r = 200, g = 230, b = 255,
                onLobby = function()
                    OF.util.report(modifiers.load_preset(name))
                end,
                onMine = function()
                    OF.util.report(modifiers.load_preset_mine(name))
                    panel.mark_dirty()
                end,
            }),
            OF.lang.t(step.blurb)))
    end

    local kept = modifiers.saved_visions()
    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.fill("Kept by you (@)", #kept)),
        "looks you have saved on this machine, and nobody else has them"))

    table.insert(rows, panel.with_help(panel.gated_row(VISION_MINE_NEED,
        OF.lang.t("+ Keep this one"), 120, 255, 120, function()
            local ok, what = modifiers.keep_vision(nil)
            if ok then

                OF.notify.show("Kept @", "good", 4, tostring(what))
            else
                OF.util.report(ok, what)
            end
        end),

        OF.lang.t("keeps the picture on your screen, on this machine only")))

    for _, entry in ipairs(kept) do
        local slot, name = entry.slot, entry.name

        local built = panel.gated_row(VISION_MINE_NEED, name,
            200, 230, 255, function()
                OF.util.report(modifiers.wear_saved(name))
            end)
        if built ~= nil and built.action ~= nil then
            built.altAction = function()

                if OF.util.report(modifiers.forget_vision(slot)) then
                    OF.notify.show("Forgot @", "info", 4, name)
                end
            end
        end
        table.insert(rows, panel.with_help(built,
            panel.may(VISION_LOBBY_NEED)
                and OF.lang.t("Press to wear it on the lobby's dials, the left "
                    .. "strip to forget it")
                or OF.lang.t("Press to wear it on your screen, the left strip "
                    .. "to forget it")))
    end

    for _, r in ipairs(modifiers.build_rows(panel, "visuals")) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.back_row("fun"))

    return rows
end

function modifiers.change_line(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    local name = OF.lang.t(entry.name)
    level = math.floor(tonumber(level) or 0)
    if level <= 0 then return OF.lang.fill("@ off", name) end
    local step = modifiers.step_name(key, modifiers.pack({ [key] = level }))
    if step == nil then return OF.lang.fill("@ on", name) end
    return OF.lang.fill("@: @", name, OF.lang.t(step))
end

function modifiers.changed_line(before, after)
    local was, now = modifiers.parse(before), modifiers.parse(after)
    local moved, only = 0, nil
    local keys = {}
    for key in pairs(was) do keys[key] = true end
    for key in pairs(now) do keys[key] = true end
    for key in pairs(keys) do
        if (was[key] or 0) ~= (now[key] or 0) then
            moved = moved + 1
            only = key
        end
    end
    if moved == 0 then return nil end
    if moved == 1 then return modifiers.change_line(only, now[only] or 0) end
    return OF.lang.fill("@ modifiers changed", tostring(moved))
end

function modifiers.stop_name_at(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    if type(level) ~= "number" or level <= 0 then return nil end
    local step = (entry.levels or {})[level]
    return step ~= nil and step.name or nil
end

function modifiers.two_box_row(panel, entry)
    local key = entry.key
    local steps = modifiers.step_count(entry)
    local roomLevel = modifiers.active()[key] or 0
    local room = roomLevel > 0
    local level, yours = modifiers.in_force(key)
    local on = level > 0

    local r, g, b = 255, 255, 255
    if on then
        r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end

    local title = OF.lang.t(entry.name)

    local function step_after(from)
        if steps <= 1 then return from > 0 and 0 or 1 end
        local next = from + 1
        if next > steps then next = 0 end
        return next
    end

    if not modifiers.can_be_mine(key) then
        local built = panel.with_help(
            panel.gated_row(modifiers.ROW_RANK, panel.tick(room, title),
                r, g, b, function() modifiers.toggle(key) end),
            OF.lang.t(modifiers.LOBBY_ONLY[key]))
        local stop = room and modifiers.stop_name_at(key, roomLevel) or nil
        if stop ~= nil then stop = OF.lang.t(stop) end
        built = panel.level_right(built, room, stop)
        if steps > 1 then
            built = panel.with_slider(built, roomLevel, steps, function(wanted)
                OF.util.report(modifiers.set_level(key, wanted))
            end)
        end
        built.catalogue = "modifier"
        return built
    end

    local mine = modifiers.mine_state(key)

    local help = entry.blurb
    if modifiers.suspended(key) then
        help = OF.lang.t("Put away until the round ends - your setting is kept.")
    end

    local built = panel.with_help(panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(mine, room),
        name = title,
        lobbyNeed = modifiers.ROW_RANK,
        mineNeed = "modifier_self",
        r = r, g = g, b = b,
        onLobby = function()
            OF.util.report(modifiers.set_level(key, step_after(roomLevel)))
        end,

        onMine = function()
            local want = panel.next_mine_level(mine,
                modifiers.mine_level(key), steps, roomLevel)
            if want == nil then
                OF.util.report(modifiers.set_mine(key, nil))
                return
            end
            OF.util.report(modifiers.set_mine_level(key, want))
        end,
    }), help)

    local stop = nil
    if steps > 1 and on then
        stop = modifiers.stop_name_at(key, level)
        if stop ~= nil then stop = OF.lang.t(stop) end
    end
    local column = panel.two_box_level(stop, yours)
    if mine == false then

        column = panel.two_box_level(OF.lang.t("off"), true)
    end
    built = panel.level_right(built, on or column ~= nil, column)

    if steps > 1 then

        local dialsRoom = (mine == nil) and panel.may(modifiers.ROW_RANK)
        local need = dialsRoom and modifiers.ROW_RANK or "modifier_self"
        local at = dialsRoom and roomLevel or (mine == false and 0 or level)
        if panel.may(need) then
            built = panel.with_slider(built, at, steps, function(wanted)
                if dialsRoom then
                    OF.util.report(modifiers.set_level(key, wanted))
                else

                    OF.util.report(modifiers.set_mine_level(key, wanted))
                end
            end)
        else

            built = panel.with_slider(built, at, steps, nil)
        end
    end

    built.catalogue = "modifier"
    return built
end

function modifiers.demon_row(panel)
    local entry = modifiers.BY_KEY["demon"]
    if entry == nil then return nil end
    return modifiers.two_box_row(panel, entry)
end

function modifiers.build_rows(panel, home)
    local rows = {}

    local groups = modifiers.grouped(home)
    if #groups == 0 then return rows end

    if modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - the settings come back after it.")))
    end

    for _, group in ipairs(groups) do

        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t(group.name)),
            group.help ~= nil and OF.lang.t(group.help) or nil))

        if group.says ~= nil then
            table.insert(rows, panel.label_row(OF.lang.t(group.says)))
        end

        if not OF.perms.can(modifiers.ROW_RANK) then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "Modifiers ask @ wherever they are drawn.",
                OF.lang.t(OF.perms.tier_name(
                    OF.perms.required(modifiers.ROW_RANK))))))
        end

        for _, entry in ipairs(group.entries) do

            table.insert(rows, modifiers.two_box_row(panel, entry))

            local note = entry.note ~= nil and entry.note() or nil
            if type(note) == "string" and note ~= "" then
                table.insert(rows, panel.label_row("   " .. note))
            end
        end

        if group.tail == "lightshow" and OF.util.asks(OF.theme, "show_rows") then
            for _, row in ipairs(OF.theme.show_rows(panel)) do
                table.insert(rows, row)
            end
        end
    end

    return rows
end
