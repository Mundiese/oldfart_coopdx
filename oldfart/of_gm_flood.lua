OF = OF or {}

local ROLE_PLAYING = "playing"
local ROLE_DEAD = "out"
local ROLE_SAFE = "safe"
local GOAL_RADIUS = 400

local AT_KEY = "ofFloodAt"
local LEVEL_KEY = "ofFloodLevel"
local AREA_KEY = "ofFloodArea"
local CHEST = 100

local UNDER = 5

local LAVA_BITE = 4

local LAVA_EVERY = 15

local LAVA_FLOOR = 0x300

local GAS_DRAIN = 2

local CLOUD_LIFT = 0

local START_BELOW = 400

local SURVEY_KEYS = { "floodStart", "floodGoal" }

local waterAt = nil
local under = 0
local dipped = false
local burnedAt = 0
local seeded = false

local hostRate = nil

local mode = {
    key = "flood",
    resultsBy = "survival",
    name = "Flood",
    blurb = "it rises from where you stand and nothing swims in it - be the last one above it",

    how = "Water, lava, cloud or gas - by the course or set below.\n"
        .. "It rises from where you stand - how high is set below.\n"
        .. "Lava burns, gas clings, cloud will not lift you.\n"
        .. "Nothing swims in it. Climb whatever is standing.\n"
        .. "The floor grips, the level is cleared, warp points are off.\n"
        .. "Bodies pass through each other - nobody can be a wall.\n"
        .. "Five seconds under it and you are out. Last one up wins.",
    minPlayers = 2,

    pinsOnPlayers = false,

    maps = "surveyed",

    saysOut = true,

    surveyKeys = SURVEY_KEYS,

    defaultLimit = 180,
    teams = false,

    usesWater = true,

    target = { name = "rise rate",
               asks = "Rise rate",
               shownIf = function() return false end,
               default = 120,
               min = 20, max = 200, step = 20 },

    outWord = "UNDER",

    presets = {
        { key = "classic", name = "Classic", help = "the usual round", sets = {} },
        { key = "volcano", name = "Volcano", help = "lava, a fast rise and a storm",
          sets = { kind = "lava", rise = "fast", storm = "often" } },
        { key = "calm", name = "Calm", help = "water and no storm",
          sets = { kind = "water", storm = "never" } },
    },

    options = {

        { key = "rise", name = "Rise speed",
          help = "how fast the water climbs",
          choices = {
              { key = "normal", name = "normal", help = "paced to the course's own climb" },
              { key = "slow", name = "slow", help = "half the usual pace - time to look for the way" },
              { key = "fast", name = "fast", help = "a third quicker - no time to wait" },
              { key = "faster", name = "very fast", help = "the fastest it goes" },
          } },
        { key = "top", name = "Water top",
          help = "whether the rise has a ceiling",
          choices = {
              { key = "never", name = "never stops",
                help = "it keeps coming until there is one of you left" },
              { key = "goal", name = "stops at the goal",
                help = "the flag on top stays dry; the clock settles it" },
          } },

        { key = "kind", name = "Floods with",
          help = "what the rise is made of",
          choices = {
              { key = "course", name = "the course's own",
                help = "lava, water or cloud - whatever belongs in it" },
              { key = "lava", name = "lava",
                help = "it burns while you are under it, in all seventeen" },
              { key = "water", name = "water",
                help = "plain water everywhere; the climb without a bite" },
          } },

        { key = "storm", name = "Lightning",
          help = "whether a storm strikes everybody under the surface",
          choices = {
              { key = "never", name = "off",
                help = "it comes up in silence" },
              { key = "sometimes", name = "now and then",
                help = "every twenty seconds, and it finds all of you" },
              { key = "often", name = "often",
                help = "every eight seconds; the water is not a place to wait" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

local function alive()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAYING)) do
        table.insert(list, entry)
    end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SAFE)) do
        table.insert(list, entry)
    end
    return list
end

local function climbing()
    return OF.gamemodes.with_role(ROLE_PLAYING)
end

local function safe_here()
    return OF.gamemodes.with_role(ROLE_SAFE)
end

local function am_dead()
    return OF.gamemodes.role(0) == ROLE_DEAD
end

local function am_safe()
    return OF.gamemodes.role(0) == ROLE_SAFE
end

mode.PUBLISH_EVERY = 3

local function height_here()
    if gGlobalSyncTable[LEVEL_KEY] ~= gNetworkPlayers[0].currLevelNum then
        return nil
    end
    if gGlobalSyncTable[AREA_KEY] ~= gNetworkPlayers[0].currAreaIndex then
        return nil
    end
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "number" then return nil end
    return at
end

local MAX_REGIONS = 20

local S16_MAX = 32767

local borrowed = {}

local wrote = {}

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

local function picture_is_ours()
    if not region_is_there(0) then return false end

    local np = gNetworkPlayers[0]
    if np ~= nil and np.currLevelNum == LEVEL_WDW then return false end

    local m = gMarioStates[0]
    if m ~= nil and find_poison_gas_level ~= nil and gLevelValues ~= nil then
        local modifiers = OF.modifiers
        if modifiers ~= nil then modifiers.gasHushed = true end
        local ok, gas = pcall(find_poison_gas_level, m.pos.x, m.pos.z)
        if modifiers ~= nil then modifiers.gasHushed = false end
        if ok and type(gas) == "number"
            and gas > gLevelValues.floorLowerLimit then
            return false
        end
    end

    return true
end

local function restore_water()

    wrote = {}
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

local function show_water(at)
    local level, area = water_place()
    if level == nil then return end

    local record = borrowed_at(level, area)
    if record == nil then
        if not picture_is_ours() then return end

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

    local held = {}
    for index, base in pairs(record) do

        local wanted = at
        if wanted > S16_MAX then wanted = S16_MAX end
        if wanted < base then wanted = base end
        wanted = math.floor(wanted)
        if wanted > base then
            local was = held[wanted]
            if was == nil or base < was then held[wanted] = base end
        end
        set_water_level(index, wanted, false)
    end
    wrote = held
end

hook_event(HOOK_ON_FIND_WATER_LEVEL, function(x, z, levelSays)
    if type(levelSays) ~= "number" then return end

    local held = math.floor(levelSays)
    if held ~= levelSays then return end
    local base = wrote[held]
    if base == nil then return end
    if OF.util.asks(OF.warp, "land_height") then
        return OF.warp.land_height(base)
    end
    return base
end)

local PLATE_ACROSS = 5
local PLATE_STEP = 700

local PLATE_SCALE = 9.0

local PLATE_KIND = {}
do
    local kinds = {
        { LEVEL_LLL, "lava" }, { LEVEL_BITFS, "lava" }, { LEVEL_BOWSER_2, "lava" },
        { LEVEL_HMC, "gas" },
        { LEVEL_RR, "cloud" }, { LEVEL_TOTWC, "cloud" },
        { LEVEL_WMOTR, "cloud" }, { LEVEL_BITS, "cloud" },
        { LEVEL_BOWSER_3, "cloud" },
    }
    for i = 1, 9 do
        local one = kinds[i]
        if one ~= nil and one[1] ~= nil then PLATE_KIND[one[1]] = one[2] end
    end
end

local function plate_kind()

    local said = OF.gamemodes.option_now("kind")
    if said ~= nil and said ~= "course" then return said end

    local np = gNetworkPlayers[0]
    return (np ~= nil and PLATE_KIND[np.currLevelNum]) or "water"
end

local KIND_LOOK = {
    water = { model = E_MODEL_IDLE_WATER_WAVE, faces = false, state = 0 },
    lava  = { model = E_MODEL_RED_FLAME, faces = true, state = 1 },
    cloud = { model = E_MODEL_MIST, faces = true, state = 2 },
    gas   = { model = E_MODEL_SMOKE, faces = true, state = 3 },
}

local function plate_look()
    return KIND_LOOK[plate_kind()] or KIND_LOOK.water
end

local function plate_model()
    return plate_look().model
end

OF.gm_flood_model = plate_model

OF.gm_flood_kind = plate_kind

local TINT_LOOK = {
    water = { r = 40, g = 95, b = 190, a = 105 },
    lava  = { r = 200, g = 70, b = 20, a = 120 },
    cloud = { r = 210, g = 215, b = 230, a = 110 },
    gas   = { r = 90, g = 165, b = 70, a = 115 },
}

local function eye_height()
    if gLakituState == nil or gLakituState.pos == nil then return nil end
    local y = gLakituState.pos.y
    if type(y) ~= "number" then return nil end
    return y
end

local function light_of(channel)
    local v = OF.util.optional("get_lighting_color_ambient", nil, channel)
    if type(v) ~= "number" then return 1 end
    if v < 0 then return 0 end
    if v > 255 then return 1 end
    return v / 255
end

OF.gm_flood_tint = function()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    local at = height_here()
    if at == nil then return nil end
    local eye = eye_height()
    if eye == nil or eye >= at then return nil end
    local look = TINT_LOOK[plate_kind()] or TINT_LOOK.water
    return {
        r = look.r * light_of(0),
        g = look.g * light_of(1),
        b = look.b * light_of(2),
        a = look.a,
    }
end

local function draw_tint()
    local wash = OF.gm_flood_tint()
    if wash == nil then return end
    OF.util.rect(0, 0, djui_hud_get_screen_width(),
        djui_hud_get_screen_height(), wash.r, wash.g, wash.b, wash.a)
end

local STORM_EVERY = { sometimes = 20, often = 8 }

local SHOCK_BITE = 4

local GAS_LIT = 8

local STORM_CLING = 45

local FLASH_FRAMES = 8

local struckAt = nil
local flash = 0

local function storm_tick()
    local every = STORM_EVERY[OF.gamemodes.option_now("storm")]
    if every == nil then
        struckAt = nil
        return false
    end
    local now = OF.gamemodes.elapsed()
    if type(now) ~= "number" or now < every then return false end
    if now % every ~= 0 then return false end
    if struckAt == now then return false end
    struckAt = now
    return true
end

local function shock()
    local at = height_here()
    if at == nil then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if m.pos.y + CHEST >= at then return end

    local kind = plate_kind()
    if kind == "cloud" then
        under = under + STORM_CLING
    elseif kind == "lava" then
        burnedAt = 0
    elseif m.health > LAVA_FLOOR then

        m.hurtCounter = math.min(255, (m.hurtCounter or 0)
            + (kind == "gas" and GAS_LIT or SHOCK_BITE))
    end

    OF.gamemodes.round_sound(SOUND_GENERAL_VOLCANO_EXPLOSION)
end

local function draw_flash()
    if flash <= 0 then return end
    local at = height_here()
    if at == nil then return end
    local strength = 0.3
    local eye = eye_height()
    if eye ~= nil and eye < at then strength = 1.0 end
    OF.util.rect(0, 0, djui_hud_get_screen_width(),
        djui_hud_get_screen_height(), 255, 255, 255,
        200 * strength * (flash / FLASH_FRAMES))
end

local plateSpot = {}

local function plate_name(i)
    return "flood" .. i
end

local PLATE_GEOS ={ "of_flood_plane", "of_flood_plane_geo" }

pcall(function() OF.ball.resolve_at_load(PLATE_GEOS) end)
local function plane_file(geo) return "actors/" .. geo .. ".bin" end

local PLATE_TOKEN = "floodplane"
local planeAsked = false
local planeModel = nil

local function plane_asset()
    if planeAsked then return planeModel end
    planeAsked = true
    for _, geo in ipairs(PLATE_GEOS) do

        if OF.util.optional("mod_file_exists", false, plane_file(geo)) then
            local id = OF.util.optional("smlua_model_util_get_id", nil, geo)

            if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
                planeModel = id
                return planeModel
            end
        end
    end
    return nil
end

OF.gm_flood_plane = plane_asset

OF.gm_flood_forget_plane = function()
    planeAsked = false
    planeModel = nil
end

local PLATE_UV_VTX = "of_flood_plane_Plane_mesh_layer_5_vtx_0"
local PLATE_SCROLL_U = 5
local PLATE_SCROLL_V = 3

local planeUvAsked = false

local planeUvOriginal = nil

local function plane_uv()
    if planeUvAsked then return planeUvOriginal end
    planeUvAsked = true
    local v = OF.util.optional("vtx_get_from_name", nil, PLATE_UV_VTX)
    if v == nil then return nil end
    local list = {}
    while v ~= nil do
        list[#list + 1] = { vtx = v, tu = v.tu, tv = v.tv }
        v = OF.util.optional("vtx_get_next_vertex", nil, v)
    end
    planeUvOriginal = list
    return planeUvOriginal
end

OF.gm_flood_forget_plane_uv = function()
    planeUvAsked = false
    planeUvOriginal = nil
end

local planeUvTick = 0

local function scroll_plane()
    local list = plane_uv()
    if list == nil then return end
    planeUvTick = planeUvTick + 1
    for i = 1, #list do
        local one = list[i]
        one.vtx.tu = one.tu + planeUvTick * PLATE_SCROLL_U
        one.vtx.tv = one.tv + planeUvTick * PLATE_SCROLL_V
    end
end

local function hide_plate()
    OF.gamemodes.hide_token(PLATE_TOKEN)
    for i = 1, PLATE_ACROSS * PLATE_ACROSS do
        OF.gamemodes.hide_token(plate_name(i))
    end
end

local PLATE_ANIM_EVERY = 8
local animPhase = 0

local function dress_tile(token, look)
    if token == nil then return end
    OF.util.optional("obj_scale", nil, token, PLATE_SCALE)

    if look.faces then OF.util.optional("obj_set_billboard", nil, token) end
    if animPhase == 0 then
        token.oAnimState = (token.oAnimState or 0) + 1
    end
end

local PLATE_CENTRE = 0

local function show_plate(at)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if at > S16_MAX then at = S16_MAX end

    animPhase = (animPhase + 1) % PLATE_ANIM_EVERY

    local look = plate_look()

    local plate = plane_asset()
    if plate ~= nil then

        scroll_plane()

        local token = OF.gamemodes.show_token(PLATE_TOKEN, plate,
            { x = PLATE_CENTRE, y = at, z = PLATE_CENTRE })
        if token ~= nil then

            token.oAnimState = look.state
        end
        if token ~= nil and token.header ~= nil and token.header.gfx ~= nil then

            token.header.gfx.skipInViewCheck = true
        end

        for i = 1, PLATE_ACROSS * PLATE_ACROSS do
            OF.gamemodes.hide_token(plate_name(i))
        end
        return
    end

    OF.gamemodes.hide_token(PLATE_TOKEN)

    local centreX = math.floor(m.pos.x / PLATE_STEP + 0.5) * PLATE_STEP
    local centreZ = math.floor(m.pos.z / PLATE_STEP + 0.5) * PLATE_STEP

    local model = look.model
    local half = math.floor(PLATE_ACROSS / 2)
    local i = 0

    local spot = plateSpot
    spot.y = at
    for row = -half, half do
        for col = -half, half do
            i = i + 1
            spot.x = centreX + col * PLATE_STEP
            spot.z = centreZ + row * PLATE_STEP
            dress_tile(OF.gamemodes.show_token(plate_name(i), model, spot), look)
        end
    end
end

local WARP_SLOTS = 4

local warpsHeld = {}

local function warps_held_at(level, area)
    local rooms = warpsHeld[level]
    if rooms == nil then return nil end
    return rooms[area]
end

local function release_warps()
    local level, area = water_place()
    if level == nil then return end
    local held = warps_held_at(level, area)
    if held == nil then return end
    for slot, id in pairs(held) do
        local warp = OF.util.optional("get_instant_warp", nil, slot)
        if warp ~= nil then warp.id = id end
    end
    warpsHeld[level][area] = nil
    if next(warpsHeld[level]) == nil then warpsHeld[level] = nil end
end

local function hold_warps()
    local level, area = water_place()
    if level == nil then return end
    if warps_held_at(level, area) ~= nil then return end

    local held = nil
    for slot = 0, WARP_SLOTS - 1 do
        local warp = OF.util.optional("get_instant_warp", nil, slot)

        if warp ~= nil and type(warp.id) == "number" and warp.id ~= 0 then
            held = held or {}
            held[slot] = warp.id
            warp.id = 0
        end
    end
    if held == nil then return end

    local rooms = warpsHeld[level]
    if rooms == nil then
        rooms = {}
        warpsHeld[level] = rooms
    end
    rooms[area] = held
end

local floorWas = nil

local function wear_grippy(step)
    if not OF.util.is_host() then return false end

    if not OF.util.asks(OF.modifiers, "set_round_level") then return false end
    return OF.modifiers.set_round_level("floor", step) == true
end

local function take_the_floor()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF, "gm_line_grip_step") then return end
    local step = OF.gm_line_grip_step()
    if step == nil then return end
    local was = OF.util.asks(OF.modifiers, "level")
        and OF.modifiers.level("floor") or 0
    if not wear_grippy(step) then return end
    floorWas = was
end

local function give_the_floor_back()
    if not OF.util.is_host() then return end
    if floorWas == nil then return end
    local was = floorWas
    floorWas = nil
    wear_grippy(was)
end

local terrainWas = nil
local terrainLevel, terrainArea = nil, nil

local function grip_the_slide()
    if terrainWas ~= nil then return end
    if not OF.util.asks(OF, "gm_line_walkable_terrain") then return end
    local m = gMarioStates[0]
    if m == nil or m.area == nil then return end
    if type(m.area.terrainType) ~= "number" then return end
    local level, area = water_place()
    if level == nil then return end

    local walkable = OF.gm_line_walkable_terrain(m.area.terrainType)
    if walkable == nil then return end
    terrainWas = m.area.terrainType
    terrainLevel, terrainArea = level, area
    m.area.terrainType = walkable
end

local function release_the_slide()
    if terrainWas == nil then return end
    local was = terrainWas
    local level, area = terrainLevel, terrainArea
    terrainWas, terrainLevel, terrainArea = nil, nil, nil

    local m = gMarioStates[0]
    if m == nil or m.area == nil then return end
    local here, hereArea = water_place()
    if here ~= level or hereArea ~= area then return end
    m.area.terrainType = was
end

local SWEEP_SPARED = { pickups = true, cannons = true }

local function sweep_keys()
    local keys = {}
    for _, option in ipairs(OF.util.asks(OF.arena, "OPTIONS")
        and OF.arena.OPTIONS or {}) do
        if not SWEEP_SPARED[option.key] then table.insert(keys, option.key) end
    end
    return keys
end

OF.gm_flood_sweep_keys = sweep_keys

local sweptRound = false

local function sweep_the_level()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.arena, "arm") then return end

    if gGlobalSyncTable.ofArenaClear == true then return end
    OF.arena.arm(true, sweep_keys(), nil)
    sweptRound = true
end

local function give_the_level_back()
    if not OF.util.is_host() then return end
    if not sweptRound then return end
    sweptRound = false
    if OF.util.asks(OF.arena, "close") then OF.arena.close() end
end

local function hold_the_room()
    hold_warps()
    grip_the_slide()
end

local function release_the_room()
    release_warps()
    release_the_slide()
end

local GOAL_TOKEN = "floodgoal"
local function goal_place()
    local level, area = water_place()
    if level == nil then return nil end
    local at = OF.gamemodes.surveyed({ level = level, area = area },
        "floodGoal")
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z, level = level, area = area }
end

local function show_goal()
    local at = goal_place()
    if at == nil then

        OF.gamemodes.hide_token(GOAL_TOKEN)
        return
    end
    OF.gamemodes.mark_flag(GOAL_TOKEN, at)
end

local function hide_goal()
    OF.gamemodes.hide_token(GOAL_TOKEN)
end

local FLOOD_STOREY = 400
local heardStorey = nil

local function hear_the_water(at)
    local storey = math.floor(at / FLOOD_STOREY)
    if heardStorey ~= nil and storey > heardStorey then
        OF.gamemodes.round_sound(SOUND_GENERAL_WATER_LEVEL_TRIG)
    end
    if heardStorey == nil or storey > heardStorey then heardStorey = storey end
end

function mode.scenery()
    local at = height_here()
    if at == nil then
        heardStorey = nil
        restore_water()
        hide_plate()
        hide_goal()

        release_the_room()
        return
    end
    show_water(at)
    show_plate(at)
    show_goal()

    hold_the_room()
    hear_the_water(at)
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    restore_water()

    warpsHeld = {}
    terrainWas, terrainLevel, terrainArea = nil, nil, nil
end)

hook_event(HOOK_ON_EXIT, function()
    restore_water()

    release_the_room()
end)

OF.gm_flood_baselines = function(level, area)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    local copy = {}
    for index, base in pairs(record) do copy[index] = base end
    return copy
end

OF.gm_flood_baseline = function(level, area, region)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    return record[region or 0]
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAYING)
    end
    if not OF.util.is_host() then return end
    mode.clockAsked = options ~= nil and tonumber(options.limit) ~= nil

    OF.util.report(OF.rules.lend("interactions", "flood",
        PLAYER_INTERACTIONS_NONE))

    local lowest = nil
    for _, entry in ipairs(players) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and (lowest == nil or m.pos.y < lowest) then
            lowest = m.pos.y
        end
    end
    if lowest == nil then lowest = 0 end

    waterAt = lowest - START_BELOW
    seeded = true
    OF.util.publish(AT_KEY, waterAt)

    local named = options ~= nil and (options.targetNamed
        or (OF.gamemodes.targetChoice ~= nil and OF.gamemodes.targetChoice[mode.key] ~= nil))
    local asked = named and tonumber(options.target) or nil
    if asked == nil then asked = mode.RISE_STOPS[OF.gamemodes.option_now("rise") or "normal"] end
    hostRate = OF.util.clamp(math.floor(asked or mode.target.default),
        mode.target.min, mode.target.max)

    take_the_floor()
end

local RATE_OVER = 105

local function climb_here(floor)
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) == "number" and type(area) == "number" then
        local place = { level = level, area = area }
        local top = OF.gamemodes.surveyed(place, "floodGoal")
        local bottom = OF.gamemodes.surveyed(place, "floodStart")
        if top ~= nil and bottom ~= nil and type(top.y) == "number"
            and type(bottom.y) == "number" and top.y > bottom.y then
            return top.y - bottom.y
        end
    end

    if type(floor) ~= "number" then return nil end
    local roof = OF.util.optional("find_ceil_height", nil,
        PLATE_CENTRE, floor + 1, PLATE_CENTRE)
    if type(roof) ~= "number" then return nil end
    local open = (gLevelValues ~= nil and gLevelValues.cellHeightLimit) or 20000
    if roof >= open then return nil end
    if roof <= floor then return nil end
    return roof - floor
end

local MAP = { RUN = 600, WIND = 1.6, CLIMB = 2.5, SLACK = 1.1, GRACE = 8, LEAST = 50 }
function mode.map_rate(level, area)
    local place = { level = level, area = area }
    local top = OF.gamemodes.surveyed(place, "floodGoal")
    local bottom = OF.gamemodes.surveyed(place, "floodStart")
    if top == nil or bottom == nil or type(top.y) ~= "number" or type(bottom.y) ~= "number"
        or top.y <= bottom.y then
        return nil
    end
    local dy = top.y - bottom.y
    local flat = math.sqrt((top.x - bottom.x) ^ 2 + (top.z - bottom.z) ^ 2)
    local travel = (flat * MAP.WIND + dy * MAP.CLIMB) / MAP.RUN
    local seconds = travel * MAP.SLACK + MAP.GRACE

    local route = mode.route_time(level, area)
    if route ~= nil then
        seconds = math.max(seconds, route * MAP.SLACK + MAP.GRACE)
        local rate = math.floor((dy + START_BELOW) / seconds)
        return math.max(1, math.min(mode.target.max, rate)), seconds
    end
    local rate = math.floor((dy + START_BELOW) / seconds + 0.5)
    return math.max(MAP.LEAST, math.min(mode.target.max, rate)), seconds
end

function mode.clock_for(route)
    if route == nil then return 180 end
    return math.floor(OF.util.clamp(route * 1.3, 120, 240) + 0.5)
end

function mode.route_time(level, area)
    if not OF.util.asks(OF.venues, "at") then return nil end
    local key = OF.venues.at(level, area)
    local layout = key ~= nil and OF.venues.LAYOUTS ~= nil and OF.venues.LAYOUTS[key] or nil
    if layout == nil then return nil end
    local said = tonumber(layout.routeTime or (layout.survey ~= nil and layout.survey.routeTime))
    if said == nil or said <= 0 then return nil end
    return said
end

local function derived_rate(floor, asked)
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) == "number" and type(area) == "number" then
        local mapped = mode.map_rate(level, area)
        if mapped ~= nil then return mapped end
    end
    local climb = climb_here(floor)
    if climb == nil then return asked end
    local step = mode.target.step
    local want = math.floor(climb / RATE_OVER / step + 0.5) * step
    if want <= asked then return asked end
    if want > mode.target.max then return mode.target.max end
    return want
end

function mode.pin()
    if not OF.util.is_host() then return end

    local lowest = nil
    for _, entry in ipairs(OF.gamemodes.landed(OF.gamemodes.participants())) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and (lowest == nil or m.pos.y < lowest) then
            lowest = m.pos.y
        end
    end
    local me = gMarioStates[0]
    if lowest == nil and me ~= nil and me.pos ~= nil then lowest = me.pos.y end
    if lowest ~= nil then
        waterAt = lowest - START_BELOW
        OF.util.publish(AT_KEY, waterAt)
    end

    OF.util.publish(LEVEL_KEY, gNetworkPlayers[0].currLevelNum)
    OF.util.publish(AREA_KEY, gNetworkPlayers[0].currAreaIndex)

    if not mode.clockAsked then
        OF.util.publish("ofGmLimit", mode.clock_for(mode.route_time(
            gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)))
    end

    if hostRate == mode.target.default then
        hostRate = derived_rate(lowest, hostRate)
    end

    sweep_the_level()
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local level, area = water_place()
    if level == nil then return nil end
    local at = OF.gamemodes.surveyed({ level = level, area = area },
        "floodStart")
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z, level = level, area = area }
end

local startedAt = nil

function mode.death_place()
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) ~= "number" or type(area) ~= "number" then return nil end
    local at = OF.gamemodes.surveyed({ level = level, area = area },
        "floodStart")
    if at ~= nil then
        return { x = at.x, y = at.y, z = at.z, level = level, area = area }
    end
    if startedAt ~= nil and startedAt.level == level
        and startedAt.area == area then
        return { x = startedAt.x, y = startedAt.y, z = startedAt.z,
                 level = level, area = area }
    end
    return nil
end

function mode.late_join(localIndex)
    return ROLE_PLAYING
end

local function ceiling_at()
    if not OF.gamemodes.option_is("top", "goal") then return nil end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) ~= "number" or type(area) ~= "number" then return nil end
    local at = OF.gamemodes.surveyed({ level = level, area = area },
        "floodGoal")
    return at ~= nil and at.y or nil
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not seeded then return end

    local rate = hostRate or mode.target.default
    waterAt = waterAt + rate / 30

    local top = ceiling_at()
    if top ~= nil and waterAt > top then waterAt = top end

    mode.publishIn = (mode.publishIn or 0) - 1
    if mode.publishIn <= 0 then
        mode.publishIn = mode.PUBLISH_EVERY
        OF.util.publish(AT_KEY, waterAt)
    end

    local left = alive()
    if #OF.gamemodes.still_here() <= 1 then return end

    if #left <= 1 then
        if #left == 1 then

            local one = left[1]

            OF.gamemodes.finish(
                OF.gamemodes.role(one.localIndex) == ROLE_SAFE
                    and "@ won at the goal." or "@ won.",
                one.np.name, one.np.name)
        else
            OF.gamemodes.finish("The water took everybody.")
        end
        return
    end

    if #climbing() == 0 then
        local names = {}
        for _, entry in ipairs(safe_here()) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        if #names > 0 then
            OF.gamemodes.finish(#names == 1 and "1 player won at the goal." or "@ players won at the goal.", { names = names },
                tostring(#names))
        end
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if flash > 0 then flash = flash - 1 end
    if storm_tick() then
        flash = FLASH_FRAMES
        if not am_dead() and not am_safe() then shock() end
    end

    if am_dead() then return end

    if am_safe() then return end

    local goal = goal_place()
    if goal ~= nil and OF.gamemodes.in_place_room(goal) then
        local reach = OF.gamemodes.distance_to_place(goal)
        if reach ~= nil and reach <= GOAL_RADIUS then
            OF.gamemodes.set_role(0, ROLE_SAFE)
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
            OF.util.publish_row(0, "ofScore", 1)

            OF.gamemodes.cue("good", nil, "flsafe")
            under = 0
            dipped = false
            return
        end
    end

    local at = height_here()
    if at == nil then
        under = 0
        return
    end

    local kind = plate_kind()

    if gMarioStates[0].pos.y + CHEST < at then

        if not dipped then OF.gamemodes.cue("hazard", nil, "flunder") end
        dipped = true
        under = under + 1

        if kind == "lava" then
            local m = gMarioStates[0]
            burnedAt = burnedAt - 1
            if burnedAt <= 0 then
                burnedAt = LAVA_EVERY
                if m.health > LAVA_FLOOR then

                    m.hurtCounter = math.min(255,
                        (m.hurtCounter or 0) + LAVA_BITE)
                end
            end
        end
    elseif kind == "gas" then

        under = under - GAS_DRAIN
        if under < 0 then under = 0 end
    else
        under = 0

        burnedAt = 0
    end
    if gMarioStates[0].pos.y + CHEST >= at then dipped = false end

    if under > 0 then
        OF.gamemodes.tick_down(math.ceil((UNDER * 30 - under) / 30))
    end

    if under >= UNDER * 30 then
        under = 0
        dipped = false
        OF.gamemodes.set_role(0, ROLE_DEAD)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    end
end

function mode.on_timeout()
    local left = alive()
    if #left == 0 then
        OF.gamemodes.finish("The water took everybody.")
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish(#left == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names },
            tostring(#left))
    end
end

function mode.terms()
    return OF.lang.t("the last one above the water")
end

function mode.on_start()
    under = 0
    burnedAt = 0

    struckAt = nil
    flash = 0

    startedAt = nil
    local me = gMarioStates[0]
    local level, area = water_place()
    if me ~= nil and me.pos ~= nil and level ~= nil then
        startedAt = { x = me.pos.x, y = me.pos.y, z = me.pos.z,
                      level = level, area = area }
    end

end

function mode.out_cause()
    return OF.lang.fill("Too long under the @", OF.lang.t(plate_kind()))
end

mode.RISE_STOPS = { normal = 120, slow = 60, fast = 160, faster = 200 }

function mode.standing(localIndex)
    local role = OF.gamemodes.role(localIndex)
    if role == ROLE_DEAD then return "OUT" end

    if role == ROLE_SAFE then return "SAFE" end
    if role ~= ROLE_PLAYING then return nil end

    local np = gNetworkPlayers[localIndex]
    local m = gMarioStates[localIndex]
    local at = gGlobalSyncTable[AT_KEY]
    if np == nil or m == nil or m.pos == nil then return nil end
    if type(at) ~= "number" then return nil end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return nil end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return nil end

    local over = math.floor((m.pos.y - at) / 100)
    if over < 0 then over = 0 end
    return tostring(over) .. "00"
end

function mode.before_mario_update(m)

    if am_dead() then
        OF.gamemodes.set_ghost(true)
        return
    end

    if plate_kind() ~= "cloud" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if m == nil or m.pos == nil or m.vel == nil then return end

    local at = height_here()
    if at == nil then return end
    if m.pos.y + CHEST >= at then return end

    if m.vel.y > CLOUD_LIFT then m.vel.y = CLOUD_LIFT end
end

function mode.cleanup()

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
    end

    restore_water()
    hide_plate()

    hide_goal()

    release_the_room()

    give_the_floor_back()
    give_the_level_back()
    waterAt = nil
    seeded = false
    under = 0
    burnedAt = 0
    hostRate = nil
    struckAt = nil
    flash = 0
end

function mode.hud()

    draw_tint()
    draw_flash()

    local goal = goal_place()
    if goal ~= nil and OF.gamemodes.in_place_room(goal) then
        local gold = OF.util.gold()
        OF.util.zone_ring(goal, GOAL_RADIUS, 40, 4,
            gold.r, gold.g, gold.b, 200)
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if am_safe() then
        state("safe", OF.lang.t("Safe"), { prio = 50, tone = "good" })
        return
    end

    if am_dead() then
        OF.gamemodes.out_banner("Under")
        return
    end

    local at = height_here()
    if at == nil then
        OF.gamemodes.away_banner("The flood is somewhere else")
        return
    end

    if under > 0 then
        state("under", OF.lang.t("Under"), { prio = 85, tone = "bad", urgent = true,
            figure = math.max(0, math.ceil((UNDER * 30 - under) / 30)) })
    end
end

OF.gamemodes.register(mode)
