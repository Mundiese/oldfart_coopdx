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
local burnedAt = 0
local seeded = false

local hostRate = nil

local mode = {
    key = "flood",
    resultsBy = "survival",
    name = "Flood",
    blurb = "it rises from where you stand and nothing swims in it - be the last one above it",

    how = "Water, lava, cloud or gas, by the course.\n"
        .. "It rises from where you stand and never stops.\n"
        .. "Lava burns, gas clings, cloud will not lift you.\n"
        .. "Nothing swims in it. Climb whatever is standing.\n"
        .. "The floor grips, the level is cleared, warp points are off.\n"
        .. "Bodies pass through each other - nobody can be a wall.\n"
        .. "Five seconds under it and you are out. Last one up wins.",
    minPlayers = 2,

    pinsOnPlayers = true,

    maps = "surveyed",

    saysOut = true,

    surveyKeys = SURVEY_KEYS,
    defaultLimit = 300,
    teams = false,

    usesWater = true,

    target = { name = "units a second",
               asks = "How many units the water rises a second",
               default = 120,
               min = 20, max = 200, step = 20 },
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

local function plate_name(i)
    return "flood" .. i
end

local PLATE_GEOS = { "of_flood_plate", "of_flood_plate_geo" }
local function plate_file(geo) return "actors/" .. geo .. ".bin" end

local PLATE_TOKEN = "floodplate"
local plateAsked = false
local plateModel = nil

local function plate_asset()
    if plateAsked then return plateModel end
    plateAsked = true
    for _, geo in ipairs(PLATE_GEOS) do

        if OF.util.optional("mod_file_exists", false, plate_file(geo)) then
            local id = OF.util.optional("smlua_model_util_get_id", nil, geo)

            if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
                plateModel = id
                return plateModel
            end
        end
    end
    return nil
end

OF.gm_flood_plate = plate_asset

OF.gm_flood_forget_plate = function()
    plateAsked = false
    plateModel = nil
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

    local plate = plate_asset()
    if plate ~= nil then

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
    for row = -half, half do
        for col = -half, half do
            i = i + 1
            dress_tile(OF.gamemodes.show_token(plate_name(i), model,
                { x = centreX + col * PLATE_STEP, y = at,
                  z = centreZ + row * PLATE_STEP }), look)
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

OF.gm_flood_warps_held = function(level, area)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    return warps_held_at(level, area)
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

function mode.scenery()
    local at = height_here()
    if at == nil then
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

    hostRate = OF.util.clamp(math.floor(tonumber(options ~= nil
        and options.target) or OF.gamemodes.target_for(mode.key)
        or mode.target.default), mode.target.min, mode.target.max)

    take_the_floor()
end

function mode.pin()
    if not OF.util.is_host() then return end

    local lowest = nil
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and (lowest == nil or m.pos.y < lowest) then
            lowest = m.pos.y
        end
    end
    if lowest ~= nil then
        waterAt = lowest - START_BELOW
        OF.util.publish(AT_KEY, waterAt)
    end

    OF.util.publish(LEVEL_KEY, gNetworkPlayers[0].currLevelNum)
    OF.util.publish(AREA_KEY, gNetworkPlayers[0].currAreaIndex)

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

function mode.late_join(localIndex)
    return ROLE_PLAYING
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not seeded then return end

    local rate = hostRate or mode.target.default
    waterAt = waterAt + rate / 30
    OF.util.publish(AT_KEY, waterAt)

    local left = alive()
    if #OF.gamemodes.still_here() <= 1 then return end

    if #left <= 1 then
        if #left == 1 then

            local one = left[1]
            OF.gamemodes.finish(
                OF.gamemodes.role(one.localIndex) == ROLE_SAFE
                    and "@ made it to the goal." or "@ stayed above it.",
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
            OF.gamemodes.finish("@ made it to the goal.", { names = names },
                tostring(#names))
        end
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if am_dead() then return end

    if am_safe() then return end

    local goal = goal_place()
    if goal ~= nil and OF.gamemodes.in_place_room(goal) then
        local reach = OF.gamemodes.distance_to_place(goal)
        if reach ~= nil and reach <= GOAL_RADIUS then
            OF.gamemodes.set_role(0, ROLE_SAFE)
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
            OF.util.publish_row(0, "ofScore", 1)
            OF.notify.show("You made it to the goal - the water cannot reach you",
                "good", 5)
            under = 0
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

    if under >= UNDER * 30 then
        under = 0
        OF.gamemodes.set_role(0, ROLE_DEAD)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        OF.notify.show("Under. You are out.", "bad", 5)
        OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
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
        OF.gamemodes.finish("Time - @ still above it.", { names = names },
            tostring(#left))
    end
end

function mode.terms()
    return OF.lang.t("the last one above the water")
end

function mode.on_start()
    under = 0
    burnedAt = 0
    if goal_place() ~= nil then
        OF.notify.show("Climb - the circle on the high ground is safe", "info", 6)
    end
end

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
end

function mode.hud()

    local goal = goal_place()
    if goal ~= nil and OF.gamemodes.in_place_room(goal) then
        local gold = OF.util.gold()
        OF.util.world_ring(goal, GOAL_RADIUS, 40, 4,
            gold.r, gold.g, gold.b, 200)
    end

    if am_safe() then
        OF.util.banner(OF.lang.fill("Safe on the goal   -   @ still climbing",
            tostring(#climbing())), 1.0, 255, 220, 130, 255)
        return
    end

    if am_dead() then
        OF.util.banner(OF.lang.t("Under - watch the rest"),
            1.0, 255, 140, 140, 255)
        return
    end

    local at = height_here()
    if at == nil then
        OF.util.banner(OF.lang.t("The flood is somewhere else"),
            1.0, 200, 200, 200, 255)
        return
    end

    local over = gMarioStates[0].pos.y - at
    if under > 0 then

        OF.util.banner(OF.lang.fill("UNDER @   -   @s", plate_kind(),
            string.format("%.0f", (UNDER * 30 - under) / 30)),
            1.0, 255, 120, 120, 255)
        return
    end

    OF.util.banner(OF.lang.fill("@ above it   -   @ still up",
        tostring(math.floor(over)), tostring(#alive())),
        1.0, 160, 200, 255, 255)
end

OF.gamemodes.register(mode)
