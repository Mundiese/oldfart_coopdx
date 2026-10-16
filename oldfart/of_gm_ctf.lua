OF = OF or {}

local ROLE_FIGHT = "in the fight"
local TARGET_CAPTURES = 3
local PICKUP_REACH = 160
local CAPTURE_REACH = 160

local REACH_HEIGHT = 250

local LANDED_FRAMES = 30

local COMEBACK_GAP = 2

local RETURN_FRAMES = 10 * 30
local GRACE_FRAMES = 15

local CARRY_STOPS = { double = 2, even = 1, triple = 3 }
local CARRY_DEFAULT = "double"
local function carry_damage()
    local stop = CARRY_STOPS[OF.gamemodes.option_now("carry") or CARRY_DEFAULT]
    if stop == nil then return CARRY_STOPS[CARRY_DEFAULT] end
    return stop
end

OF.gm_ctf_carry_damage = carry_damage

local CARRIER_SCALE = 0.4

local AT_BASE = -1
local DROPPED = -2

local RED_KEY = "ofCtfRed"
local BLUE_KEY = "ofCtfBlue"
local RED_SCORE = "ofCtfRedS"
local BLUE_SCORE = "ofCtfBlueS"
local TARGET_KEY = "ofCtfTarget"
local LEVEL_KEY = "ofCtfLevel"
local AREA_KEY = "ofCtfArea"
local BASE_KEY = { red = "ofCtfRedBase", blue = "ofCtfBlueBase" }
local DROP_KEY = { red = "ofCtfRedDrop", blue = "ofCtfBlueDrop" }

local function pack_point(pos)
    if pos == nil then return nil end
    return string.format("%.1f %.1f %.1f", pos.x, pos.y, pos.z)
end

local function unpack_point(text)
    if type(text) ~= "string" then return nil end
    local x, y, z = string.match(text, "^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil then return nil end
    return { x = x, y = y, z = z }
end

local SIDES = { "red", "blue" }
local OTHER = { red = "blue", blue = "red" }

local onFloor = { red = 0, blue = 0 }
local grace = { red = 0, blue = 0 }

local floorFor = { red = 0, blue = 0 }
local floorWas = { red = nil, blue = nil }

local prevHurt = 0
local sayAgainIn = {}

local doubleSaid = false

local groundWas = nil

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
    groundWas = was
end

local function give_the_floor_back()
    if not OF.util.is_host() then return end
    if groundWas == nil then return end
    local was = groundWas
    groundWas = nil
    wear_grippy(was)
end

local terrainWas = nil
local terrainLevel, terrainArea = nil, nil

local function grip_the_slide()
    if terrainWas ~= nil then return end
    if not OF.util.asks(OF, "gm_line_walkable_terrain") then return end
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.area == nil or np == nil then return end
    if type(m.area.terrainType) ~= "number" then return end

    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if level == nil then return end
    if np.currLevelNum ~= level or np.currAreaIndex ~= area then return end

    local walkable = OF.gm_line_walkable_terrain(m.area.terrainType)
    if walkable == nil then return end
    terrainWas = m.area.terrainType
    terrainLevel, terrainArea = np.currLevelNum, np.currAreaIndex
    m.area.terrainType = walkable
end

local function release_the_slide()
    if terrainWas == nil then return end
    local was = terrainWas
    local level, area = terrainLevel, terrainArea
    terrainWas, terrainLevel, terrainArea = nil, nil, nil

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.area == nil or np == nil then return end
    if np.currLevelNum ~= level or np.currAreaIndex ~= area then return end
    m.area.terrainType = was
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    terrainWas, terrainLevel, terrainArea = nil, nil, nil
end)

local function tick_floor()
    for _, side in ipairs(SIDES) do
        local state = gGlobalSyncTable[side == "red" and RED_KEY or BLUE_KEY]
        if state ~= DROPPED or floorWas[side] ~= DROPPED then
            floorFor[side] = 0
        else
            floorFor[side] = floorFor[side] + 1
        end
        floorWas[side] = state
    end
end

local function return_by_touch()
    return not OF.gamemodes.option_is("return", "timer")
end
local function return_by_timer()
    return not OF.gamemodes.option_is("return", "touch")
end

local function seconds_left(side)
    local left = RETURN_FRAMES - floorFor[side]
    if left < 0 then left = 0 end
    return math.ceil(left / 30)
end

local carriedAt = { red = nil, blue = nil }

local function state_key(side) return side == "red" and RED_KEY or BLUE_KEY end
local function score_key(side) return side == "red" and RED_SCORE or BLUE_SCORE end

local function flag_state(side)
    local value = gGlobalSyncTable[state_key(side)]
    if type(value) ~= "number" then return AT_BASE end
    return value
end

local function captures(side)
    local value = gGlobalSyncTable[score_key(side)]
    if type(value) ~= "number" then return 0 end
    return value
end

local function capture_worth(side)
    local mine = gGlobalSyncTable[side == "red" and RED_SCORE or BLUE_SCORE]
    local theirs = gGlobalSyncTable[side == "red" and BLUE_SCORE or RED_SCORE]
    if type(mine) ~= "number" then mine = 0 end
    if type(theirs) ~= "number" then theirs = 0 end
    if theirs - mine >= COMEBACK_GAP then return 2 end
    return 1
end

local function target_captures()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_CAPTURES end
    return value
end

local function base_of(side)
    return unpack_point(gGlobalSyncTable[BASE_KEY[side]])
end

local function drop_of(side)
    return unpack_point(gGlobalSyncTable[DROP_KEY[side]])
end

local function publish_base(side, pos)
    if side == "red" then
        OF.util.publish("ofCtfRedBase", pack_point(pos))
    else
        OF.util.publish("ofCtfBlueBase", pack_point(pos))
    end
end

local function publish_drop(side, pos)
    if side == "red" then
        OF.util.publish("ofCtfRedDrop", pack_point(pos))
    else
        OF.util.publish("ofCtfBlueDrop", pack_point(pos))
    end
end

local function flag_position(side)
    local state = flag_state(side)
    if state == AT_BASE then return base_of(side) end
    if state == DROPPED then return drop_of(side) end
    return nil
end

local CARRY_HEIGHT = 120

local function flag_spot(side)
    local at = flag_position(side)
    if at ~= nil then return at end

    local carrier = OF.util.local_from_global(flag_state(side))
    local m = carrier ~= nil and gMarioStates[carrier] or nil
    if m == nil or m.pos == nil then return nil end
    return { x = m.pos.x, y = m.pos.y + CARRY_HEIGHT, z = m.pos.z }
end

local function flag_token(name, at)
    local token = OF.gamemodes.show_token(name, E_MODEL_KOOPA_FLAG, at, nil,
        id_bhvKoopaFlag)
    if token ~= nil then
        token.oInteractType = 0
        token.oIntangibleTimer = -1
        token.oTimer = 0
    end
    return token
end

local function place_flags()
    for _, side in ipairs(SIDES) do
        local at = flag_spot(side)

        if at == nil then
            OF.gamemodes.hide_token("flag" .. side)
        else
            local token = flag_token("flag" .. side, at)

            if token ~= nil then
                local np = gNetworkPlayers[0]
                local scale = 1.0
                if np ~= nil and flag_state(side) == np.globalIndex then
                    scale = CARRIER_SCALE
                end
                OF.util.optional("obj_scale", nil, token, scale)
            end
        end
    end
end

function OF.gm_ctf_flag_object(side)
    return OF.gamemodes.tokens["flag" .. side]
end

function OF.gm_ctf_base(side)
    return base_of(side)
end

local function side_of(localIndex)
    if not (OF.util.asks(OF.teams, "of")) then return nil end
    local key = OF.teams.of(localIndex)
    if key ~= "red" and key ~= "blue" then return nil end
    return key
end

local function my_side()
    return side_of(0)
end

local function playing()
    return OF.gamemodes.with_role(ROLE_FIGHT)
end

local function on_the_pitch(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil or not np.connected then return false end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) ~= "number" then return false end
    if np.currLevelNum ~= level then return false end
    if type(area) == "number" and np.currAreaIndex ~= area then return false end
    return true
end

local function within(localIndex, spot, reach)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil or spot == nil then return nil end

    reach = OF.gamemodes.reach_for(localIndex, reach)
    local dx, dz = m.pos.x - spot.x, m.pos.z - spot.z
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat >= reach then return nil end
    if math.abs(m.pos.y - spot.y) >= REACH_HEIGHT then return nil end
    return flat
end

local DEATHS = {}
local function a_death(action)
    if action ~= nil then DEATHS[action] = true end
end
a_death(ACT_BUBBLED)
a_death(ACT_DROWNING)
a_death(ACT_WATER_DEATH)
a_death(ACT_STANDING_DEATH)
a_death(ACT_QUICKSAND_DEATH)
a_death(ACT_ELECTROCUTION)
a_death(ACT_SUFFOCATION)
a_death(ACT_DEATH_ON_STOMACH)
a_death(ACT_DEATH_ON_BACK)
a_death(ACT_EATEN_BY_BUBBA)

local function is_dead(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil then return false end
    return DEATHS[m.action] == true
end

local function can_touch(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil then return false end
    if is_dead(localIndex) then return false end
    return OF.util.action_group(m.action)
        ~= OF.util.action_group(ACT_GROUP_CUTSCENE)
end

local landed = {}

local function place_of(np)
    return tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex)
end

local function tick_landings()
    if not OF.util.is_host() then return end
    local seen = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        local where = place_of(np)
        local was = landed[np.globalIndex]
        if was == nil or was.where ~= where then
            landed[np.globalIndex] = { where = where, frames = 0 }
        else
            was.frames = was.frames + 1
        end
        seen[np.globalIndex] = true
    end

    for globalIndex in pairs(landed) do
        if not seen[globalIndex] then landed[globalIndex] = nil end
    end
end

local function has_landed(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false end
    local entry = landed[np.globalIndex]
    if entry ~= nil and entry.where ~= place_of(np) then return false end

    if entry == nil then return true end
    return entry.frames >= LANDED_FRAMES
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    target = { name = "captures to win",
               asks = "How many captures win the round",
               default = 3,
               min = 1, max = 10, step = 1 },

    options = {

        { key = "home", name = "Flag at home to score",
          help = "whether a capture needs your own flag at its base",
          choices = {
              { key = "anyway", name = "no",
                help = "both sides can be out at once and both runs land" },
              { key = "wait", name = "yes",
                help = "a run only counts while your own flag is standing" },
          } },
        { key = "carry", name = "Carrier damage",
          help = "how hard a carrier is to stop",
          choices = {
              { key = "double", name = "double damage",
                help = "every new hit takes twice what it would" },
              { key = "even", name = "nothing extra",
                help = "a carrier is as hard to stop as anybody else" },
              { key = "triple", name = "triple damage",
                help = "crossing alone is a mistake" },
          } },

        { key = "return", name = "Flag return",
          help = "how a dropped flag goes back to its base",
          choices = {
              { key = "both", name = "touch or timer",
                help = "its side touches it home, or it goes home in ten seconds" },
              { key = "timer", name = "timer only",
                help = "it lies there ten seconds whatever its side does" },
              { key = "touch", name = "touch only",
                help = "it waits on the floor until its own side touches it" },
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
    key = "ctf",
    name = "Capture the Flag",

    pointBanner = "CAPTURED",

    blurb = "two flags, two bases - carry theirs home while yours still stands",
    blurbTeams = "two flags, two bases - carry theirs home while yours still stands",

    how = "Two flags, two bases, two sides.\n"
        .. "Carry theirs home to score.\n"
        .. "Whether yours must be on base is set below.\n"
        .. "A dropped flag lies there until somebody takes it.\n"
        .. "What carrying costs you is set below.\n"
        .. "Two behind, and your captures count double.\n"
        .. "First side to the target wins; then the clock.",
    minPlayers = 2,
    sidesFrom = 2,

    pinsOnPlayers = false,

    maps = "surveyed",

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },

    surveyKeys = { "ctfRed", "ctfBlue" },

    surveyOut = {
        { level = LEVEL_THI, area = 1 },
        { level = LEVEL_WDW, area = 1 },

        { level = LEVEL_BITDW, area = 1 },
        { level = LEVEL_TTC, area = 1 },
        { level = LEVEL_PSS, area = 1 },

        { level = LEVEL_RR, area = 1 }, { level = LEVEL_VCUTM, area = 1 },
        { level = LEVEL_BITFS, area = 1 },

        { level = LEVEL_TTM, area = 1 },
    },
    music = SEQ_LEVEL_KOOPA_ROAD,

    defaultLimit = 300,

    teams = "always",

    symmetric = true,
}

function mode.terms()

    if OF.gamemodes.option_showing(mode.key, "home") == "wait" then
        return OF.lang.fill("first to @ - and yours must be home to score",
            tostring(target_captures()))
    end
    return OF.lang.fill("first to @ - two behind and yours count double",
        tostring(target_captures()))
end

local function flag_label(side, mine)
    if mine == nil then
        return side == "red" and "red flag" or "blue flag"
    end
    if side == mine then return "your flag" end
    return "their flag"
end

local function side_colour(side)
    local team = OF.util.asks(OF.teams, "find") and OF.teams.find(side) or nil
    if team == nil then return 230, 230, 230 end
    return team.r, team.g, team.b
end

function mode.side_place(side)
    local at = base_of(side)
    if at == nil then return nil end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) ~= "number" then return nil end
    return { x = at.x, y = at.y, z = at.z, level = level,
             area = type(area) == "number" and area or nil }
end

function mode.death_place(from)
    local side = my_side()
    if side ~= "red" and side ~= "blue" then return nil end
    return OF.gamemodes.team_respawn(side, from, mode)
end

function mode.spawn_focus(side)
    if side ~= "red" and side ~= "blue" then return nil end
    if flag_state(side) ~= AT_BASE then return flag_spot(side) end
    local other = side == "red" and "blue" or "red"
    local carrier = flag_state(other)
    if carrier >= 0 then
        local li = OF.util.local_from_global(carrier)
        if li ~= nil and side_of(li) == side then return flag_spot(other) end
    end
    return nil
end

local flagTargets = { red = {}, blue = {} }
local baseTarget = { id = "base", label = "your base", priority = 95,
    compass = "offscreen", ring = { radius = CAPTURE_REACH } }
local ctfList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #ctfList, 1, -1 do ctfList[i] = nil end
    if not on_the_pitch(0) then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local mine = my_side()
    local carrying = mine ~= nil and flag_state(OTHER[mine]) == np.globalIndex

    for _, side in ipairs(SIDES) do
        local state = flag_state(side)
        local homeAndCarrying = carrying and side == mine and state == AT_BASE
        if state ~= np.globalIndex and not homeAndCarrying then
            local t = flagTargets[side]
            local r, g, b = side_colour(side)
            t.id = "flag:" .. side
            t.label = flag_label(side, mine)
            t.tone = { r, g, b }
            t.compass = "offscreen"
            t.pos, t.player, t.ring = nil, nil, nil
            local ours = mine ~= nil and side == mine
            t.priority = ours and (state == AT_BASE and 30 or 85) or 90
            t.urgent = ours and state ~= AT_BASE
            if state >= 0 then
                t.player = OF.util.local_from_global(state)
            else
                t.pos = flag_spot(side)
                t.ring = { radius = PICKUP_REACH }
            end
            if t.pos ~= nil or t.player ~= nil then ctfList[#ctfList + 1] = t end
        end
    end

    if carrying then
        local home = base_of(mine)
        if home ~= nil then
            local r, g, b = side_colour(mine)
            baseTarget.pos = home
            baseTarget.tone = { r, g, b }
            ctfList[#ctfList + 1] = baseTarget
        end
    end
    return ctfList
end

local function pick_bases(players)
    local best, bestRed, bestBlue = -1, nil, nil
    for _, a in ipairs(players) do
        local sideA = side_of(a.localIndex)
        local ma = gMarioStates[a.localIndex]
        if sideA ~= nil and ma ~= nil and ma.pos ~= nil then
            for _, b in ipairs(players) do
                local sideB = side_of(b.localIndex)
                local mb = gMarioStates[b.localIndex]
                if sideB ~= nil and sideB ~= sideA and mb ~= nil and mb.pos ~= nil then
                    local dx = ma.pos.x - mb.pos.x
                    local dy = ma.pos.y - mb.pos.y
                    local dz = ma.pos.z - mb.pos.z
                    local d = dx * dx + dy * dy + dz * dz
                    if d > best then
                        best = d
                        if sideA == "red" then
                            bestRed = { x = ma.pos.x, y = ma.pos.y, z = ma.pos.z }
                            bestBlue = { x = mb.pos.x, y = mb.pos.y, z = mb.pos.z }
                        else
                            bestRed = { x = mb.pos.x, y = mb.pos.y, z = mb.pos.z }
                            bestBlue = { x = ma.pos.x, y = ma.pos.y, z = ma.pos.z }
                        end
                    end
                end
            end
        end
    end
    if bestRed == nil then return nil, nil, 0 end
    return bestRed, bestBlue, math.sqrt(best)
end

local SHORT_PITCH = 900

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
    end

    OF.util.publish(TARGET_KEY, options.target or TARGET_CAPTURES)
    OF.util.publish(RED_SCORE, 0)
    OF.util.publish(BLUE_SCORE, 0)
    OF.util.publish(RED_KEY, AT_BASE)
    OF.util.publish(BLUE_KEY, AT_BASE)

    publish_drop("red", nil)
    publish_drop("blue", nil)

    OF.util.report(OF.rules.lend("interactions", "ctf",
        PLAYER_INTERACTIONS_PVP))

    take_the_floor()
end

function mode.pin()
    local np = gNetworkPlayers[0]
    if np ~= nil then
        OF.util.publish(LEVEL_KEY, np.currLevelNum)
        OF.util.publish(AREA_KEY, np.currAreaIndex)
    end

    local here = { level = np ~= nil and np.currLevelNum or nil,
                   area = np ~= nil and np.currAreaIndex or nil }
    local setRed = OF.gamemodes.surveyed(here, "ctfRed")
    local setBlue = OF.gamemodes.surveyed(here, "ctfBlue")
    if setRed ~= nil and setBlue ~= nil then
        publish_base("red", setRed)
        publish_base("blue", setBlue)
    else

        local red, blue, apart = pick_bases(
            OF.gamemodes.landed(OF.gamemodes.with_role(ROLE_FIGHT)))

        if red == nil or apart < SHORT_PITCH then
            local course = OF.gamemodes.derived_spots(here, 2)
            if course ~= nil and #course >= 2 then
                local a, b = course[1], course[2]
                local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
                local span = math.sqrt(dx * dx + dy * dy + dz * dz)
                if red == nil or span > apart then
                    red, blue, apart = a, b, span
                end
            end
        end
        publish_base("red", red)
        publish_base("blue", blue)

        if red ~= nil and apart < SHORT_PITCH then
            OF.notify.send_all("The bases came out close - spread out next round",
                "warn", 5)
        end
    end

    local moved = false
    for _, side in ipairs(SIDES) do
        local state = flag_state(side)
        if state ~= AT_BASE then moved = true end
        publish_drop(side, nil)

        if state ~= AT_BASE and state ~= DROPPED then
            OF.util.publish(state_key(side), DROPPED)
        end
        OF.util.publish(state_key(side), AT_BASE)
        onFloor[side] = 0
        grace[side] = 0
        carriedAt[side] = nil
    end
    if moved then
        OF.notify.send_all("The pitch moved - both flags are back on their bases",
            "info", 4)
    end
end

function mode.late_join(localIndex)
    return ROLE_FIGHT
end

function mode.on_start()
    onFloor = { red = 0, blue = 0 }
    grace = { red = 0, blue = 0 }
    carriedAt = { red = nil, blue = nil }
    floorFor = { red = 0, blue = 0 }
    floorWas = { red = nil, blue = nil }
    sayAgainIn = {}

    local m = gMarioStates[0]
    prevHurt = m ~= nil and (m.hurtCounter or 0) or 0

    doubleSaid = false
end

local function my_flag()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for _, side in ipairs(SIDES) do
        if flag_state(side) == np.globalIndex then return side end
    end
    return nil
end

function mode.say_near_if()
    if not on_the_pitch(0) then return false end
    for _, side in ipairs(SIDES) do
        local spot = flag_position(side)
        if spot ~= nil and within(0, spot, PICKUP_REACH) ~= nil then
            return OF.gamemodes.say_near()
        end
    end
    local mine = my_side()
    if my_flag() ~= nil and mine ~= nil and within(0, base_of(mine), CAPTURE_REACH) ~= nil then
        return OF.gamemodes.say_near()
    end
    return false
end

function mode.update()
    mode.say_near_if()
    local m = gMarioStates[0]
    if m == nil then
        prevHurt = 0
        return
    end

    local hurt = m.hurtCounter or 0

    if my_flag() == nil then
        prevHurt = hurt
        return
    end

    if m.action ~= ACT_SHOT_FROM_CANNON then

        local again = carry_damage() - 1
        if hurt > prevHurt and again > 0 then
            m.hurtCounter = hurt + (hurt - prevHurt) * again
            hurt = m.hurtCounter
        end
    end

    prevHurt = hurt
end

function mode.cleanup()

    give_the_floor_back()
    release_the_slide()

    OF.rules.give_back("interactions", "ctf")
    onFloor = { red = 0, blue = 0 }
    grace = { red = 0, blue = 0 }
    carriedAt = { red = nil, blue = nil }
    floorFor = { red = 0, blue = 0 }
    floorWas = { red = nil, blue = nil }
    sayAgainIn = {}
    landed = {}
    prevHurt = 0
    if OF.util.is_host() then
        for _, side in ipairs(SIDES) do
            OF.util.publish(state_key(side), nil)
            OF.util.publish(score_key(side), nil)
            publish_base(side, nil)
            publish_drop(side, nil)
        end
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
    end
end

local function on_pvp_tag(attacker, victim, interaction)
    if not OF.util.is_host() then return end
    if attacker == nil or victim == nil then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "ctf" then return end

    local np = gNetworkPlayers[victim.playerIndex]
    if np == nil then return end
    local attackerSide = side_of(attacker.playerIndex)
    local victimSide = side_of(victim.playerIndex)

    if attackerSide == nil or victimSide == nil or attackerSide == victimSide then
        return
    end

    for _, side in ipairs(SIDES) do
        if flag_state(side) == np.globalIndex and grace[side] <= 0 then
            local m = gMarioStates[victim.playerIndex]
            if m ~= nil and m.pos ~= nil then
                publish_drop(side, { x = m.pos.x, y = m.pos.y, z = m.pos.z })
                OF.util.publish(state_key(side), DROPPED)
                onFloor[side] = 0
                OF.notify.send_all("The @ flag was knocked loose", "warn", 3,
                    OF.lang.t(side == "red" and "red" or "blue"))
            end
        end
    end
end

local function nearest_to(spot, allowed, held_back)
    local bestIndex, bestDistance = nil, nil
    local downIndex, downDistance = nil, nil
    local heldIndex, heldDistance = nil, nil
    for _, entry in ipairs(playing()) do

        if OF.gamemodes.can_play(entry.localIndex)
            and allowed(entry.localIndex) and on_the_pitch(entry.localIndex) then
            local d = within(entry.localIndex, spot, PICKUP_REACH)
            if d ~= nil then

                if not can_touch(entry.localIndex) then
                    if downDistance == nil or d < downDistance then
                        downIndex, downDistance = entry.localIndex, d
                    end
                elseif held_back ~= nil and held_back(entry.localIndex) then
                    if heldDistance == nil or d < heldDistance then
                        heldIndex, heldDistance = entry.localIndex, d
                    end
                elseif bestDistance == nil or d < bestDistance then
                    bestIndex, bestDistance = entry.localIndex, d
                end
            end
        end
    end
    return bestIndex, downIndex, heldIndex
end

local function say_why_not(localIndex, message, value)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false end
    if (sayAgainIn[np.globalIndex] or 0) > 0 then return false end
    sayAgainIn[np.globalIndex] = 3 * 30
    OF.notify.send_to(np.globalIndex, message, "warn", 3, value)
    return true
end

local function tick_refusals()
    for globalIndex, frames in pairs(sayAgainIn) do
        if frames <= 1 then
            sayAgainIn[globalIndex] = nil
        else
            sayAgainIn[globalIndex] = frames - 1
        end
    end
end

local function carrier_still_good(side)
    local state = flag_state(side)
    if state == AT_BASE or state == DROPPED then return true end
    local localIndex = OF.util.local_from_global(state)
    if localIndex == nil then return false end
    if OF.gamemodes.role(localIndex) ~= ROLE_FIGHT then return false end

    if not OF.gamemodes.can_play(localIndex) then return false end
    if not on_the_pitch(localIndex) then return false end

    if is_dead(localIndex) then return false end
    local carrierSide = side_of(localIndex)

    if carrierSide == nil or carrierSide == side then return false end
    return true
end

local function drop_where_they_stood(side)
    local state = flag_state(side)
    local localIndex = type(state) == "number"
        and OF.util.local_from_global(state) or nil
    local m = localIndex ~= nil and gMarioStates[localIndex] or nil
    local spot = carriedAt[side]
    if m ~= nil and m.pos ~= nil and on_the_pitch(localIndex) then
        spot = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    end
    carriedAt[side] = nil
    if spot ~= nil then
        publish_drop(side, spot)
        OF.util.publish(state_key(side), DROPPED)
        onFloor[side] = 0
    else

        OF.util.publish(state_key(side), AT_BASE)
    end
end

function mode.host_update()
    tick_refusals()

    for _, side in ipairs(SIDES) do
        if grace[side] > 0 then grace[side] = grace[side] - 1 end

        local state = flag_state(side)
        if state ~= AT_BASE and state ~= DROPPED then
            local at = OF.util.local_from_global(state)
            local m = at ~= nil and gMarioStates[at] or nil
            if m ~= nil and m.pos ~= nil and on_the_pitch(at) then
                carriedAt[side] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            end
        end
    end

    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        return
    end

    for _, side in ipairs(SIDES) do
        local thieves = OTHER[side]

        if not carrier_still_good(side) then
            drop_where_they_stood(side)
        end

        local state = flag_state(side)

        if state == DROPPED then

            onFloor[side] = onFloor[side] + 1
            if onFloor[side] >= RETURN_FRAMES and return_by_timer() then
                OF.util.publish(state_key(side), AT_BASE)
                publish_drop(side, nil)
                onFloor[side] = 0

                state = AT_BASE
            end
        end

        local spot = flag_position(side)
        if spot ~= nil then

            local defender, deadDefender = nil, nil
            if state == DROPPED and return_by_touch() then
                defender, deadDefender = nearest_to(spot, function(index)
                    return side_of(index) == side
                end)
            end
            if deadDefender ~= nil and defender == nil then
                say_why_not(deadDefender,
                    "You cannot send your flag home while you are down")
            end
            if defender ~= nil then
                OF.util.publish(state_key(side), AT_BASE)
                publish_drop(side, nil)
                onFloor[side] = 0
            else

                local thief, downThief, tooSoon = nearest_to(spot,
                    function(index) return side_of(index) == thieves end,
                    function(index) return not has_landed(index) end)
                if thief == nil then
                    if tooSoon ~= nil then
                        say_why_not(tooSoon,
                            "Find your feet first - you have only just landed")
                    elseif downThief ~= nil then
                        say_why_not(downThief,
                            "You cannot pick the flag up while you are down")
                    end
                end
                if thief ~= nil then
                    local np = gNetworkPlayers[thief]
                    if np ~= nil then
                        OF.util.publish(state_key(side), np.globalIndex)
                        publish_drop(side, nil)
                        grace[side] = GRACE_FRAMES
                        onFloor[side] = 0
                    end
                end
            end
        end
    end

    for _, side in ipairs(SIDES) do
        local theirs = OTHER[side]
        local state = flag_state(theirs)
        if state ~= AT_BASE and state ~= DROPPED then
            local localIndex = OF.util.local_from_global(state)
            local home = base_of(side)
            local d = nil
            if localIndex ~= nil and home ~= nil and on_the_pitch(localIndex) then
                d = within(localIndex, home, CAPTURE_REACH)
            end
            if d ~= nil and flag_state(side) ~= AT_BASE
                and OF.gamemodes.option_is("home", "wait") then
                say_why_not(localIndex,
                    "Your own @ flag is out - get it home before you can score",
                    OF.lang.t(side))
                d = nil
            end
            if d ~= nil then
                local worth = capture_worth(side)
                OF.util.publish(state_key(theirs), AT_BASE)
                publish_drop(theirs, nil)
                OF.util.publish(score_key(side), captures(side) + worth)
                onFloor[theirs] = 0
                grace[theirs] = 0

                local np = gNetworkPlayers[localIndex]

                local _ = np

            end
        end
    end

    local target = target_captures()
    for _, side in ipairs(SIDES) do
        if captures(side) >= target then
            local team = OF.util.asks(OF.teams, "find") and OF.teams.find(side) or nil

            OF.gamemodes.finish(OF.teams.result_text(captures("red"), captures("blue")),
                OF.gamemodes.team_winner(team))
            return
        end
    end
end

function mode.overtime()
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        return false
    end
    local red, blue = captures("red"), captures("blue")

    local function running(side)
        local state = flag_state(OTHER[side])
        return state ~= AT_BASE and state ~= DROPPED
    end

    if red == blue then return running("red") or running("blue") end
    return running(red < blue and "red" or "blue")
end

function mode.still_winnable()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

function mode.on_timeout()
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        OF.gamemodes.finish("Nobody had a side to carry for.")
        return
    end
    local red, blue = captures("red"), captures("blue")
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, red)
        return
    end
    local team = OF.teams.find(red > blue and "red" or "blue")
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(team))
end

function mode.standing(localIndex)
    local side = side_of(localIndex)
    if side == nil then return nil end
    return tostring(captures(side))
end

local function ring_the_flags(mine)

    if OF.util.asks(OF.markers, "ring") then return end
    if not on_the_pitch(0) then return end
    if not OF.util.asks(OF.markers, "place_ring") then return end

    local np = gNetworkPlayers[0]
    if np == nil then return end
    local m = gMarioStates[0]

    local function reach_to(at)
        if m == nil or m.pos == nil then return nil end
        local dx, dz = at.x - m.pos.x, at.z - m.pos.z
        return math.sqrt(dx * dx + dz * dz)
    end

    local carrying = mine ~= nil and flag_state(OTHER[mine]) == np.globalIndex
    local home = carrying and base_of(mine) or nil

    for _, side in ipairs(SIDES) do
        local atBase = home ~= nil and side == mine
            and flag_state(side) == AT_BASE
        if flag_state(side) ~= np.globalIndex and not atBase then
            local at = flag_spot(side)
            if at ~= nil then
                local cr, cg, cb = side_colour(side)
                OF.markers.place_ring(at, PICKUP_REACH, {
                    r = cr, g = cg, b = cb,

                    distance = reach_to(at),
                })
            end
        end
    end

    if home ~= nil then
        local cr, cg, cb = side_colour(mine)

        OF.markers.place_ring(home, CAPTURE_REACH, {
            r = cr, g = cg, b = cb,
            distance = reach_to(home),
        })
    end
end

function mode.hud()
    local mine = my_side()

    ring_the_flags(mine)

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local np = gNetworkPlayers[0]
    if mine ~= nil and np ~= nil then
        if flag_state(OTHER[mine]) == np.globalIndex then
            state("carry", OF.lang.t("You have the flag"), { prio = 60, tone = "target" })
        end
        local ours = flag_state(mine)
        if ours == DROPPED then
            state("return", OF.lang.t("Return it"), { prio = 70, tone = "warn",
                figure = return_by_timer() and seconds_left(mine) or nil })
        elseif ours ~= AT_BASE then
            state("taken", OF.lang.t("Flag taken"), { prio = 65, tone = "bad", colour = true })
        end
        if capture_worth(mine) > 1 then
            if not doubleSaid and OF.util.asks(OF.hud, "banner") then
                doubleSaid = true
                OF.hud.banner("objective", OF.lang.t("DOUBLE POINTS"),
                    OF.lang.t("Two behind"), { side = "us" })
            end
        else
            doubleSaid = false
        end
    end
end

function mode.flag_icon(side)
    local state = flag_state(side)
    if state == AT_BASE then return { icon = "flag", tone = side, state = "home" } end
    if state == DROPPED then return { icon = "flag", tone = side, dim = true, state = "dropped" } end
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    return { icon = "flag", tone = "warn", dim = math.floor(now / 15) % 2 == 1, state = "carried" }
end

local function flag_news(side, oldVal, newVal)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    local mine = my_side()
    local np = gNetworkPlayers[0]
    if type(newVal) == "number" and newVal >= 0 and (oldVal == AT_BASE or oldVal == DROPPED) then
        if np ~= nil and newVal == np.globalIndex then return nil end
        if mine == nil then return OF.hud.banner("objective", OF.lang.t("FLAG TAKEN"), nil, { quiet = true }) end
        return OF.hud.banner("objective", OF.lang.t("FLAG TAKEN"), nil,
            { side = side == mine and "them" or "us", quiet = true })
    end
    if newVal == AT_BASE and oldVal == DROPPED then
        if mine == nil then return OF.hud.banner("objective", OF.lang.t("RETURNED"), nil, { quiet = true }) end
        return OF.hud.banner("objective", OF.lang.t("RETURNED"), nil,
            { side = side == mine and "us" or "them", quiet = true })
    end
    return nil
end
mode.flag_news = flag_news

local function watch(side)
    hook_on_sync_table_change(gGlobalSyncTable, state_key(side), 0,
        function(tag, oldVal, newVal)

        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(state_key(side)) then
            return
        end
        if newVal == oldVal then return end
        local current = OF.gamemodes.current()
        if current == nil or current.key ~= "ctf" then return end
        local np = gNetworkPlayers[0]
        if np == nil then return end
        flag_news(side, oldVal, newVal)

        if type(newVal) == "number" and newVal >= 0 and newVal ~= np.globalIndex
            and side == my_side() then
            local carrier = OF.util.local_from_global(newVal)
            if carrier == nil or side_of(carrier) ~= side then
                OF.gamemodes.cue("hazard")
            end
        end
        if newVal == np.globalIndex then

            OF.gamemodes.cue("good")
        elseif oldVal == np.globalIndex then

            if newVal == AT_BASE then
                local row = gPlayerSyncTable[0]
                OF.util.publish_row(0, "ofScore",
                    (row ~= nil and row.ofScore or 0) + 1)
            end
        end
    end)
end

for _, side in ipairs(SIDES) do watch(side) end

function OF.gm_ctf_flag(side)
    return flag_state(side)
end

function mode.scenery()

    OF.gamemodes.hear_sides(captures("red"), captures("blue"))

    grip_the_slide()
    tick_landings()
    tick_floor()
    place_flags()
end

mode.on_tag = function(a, v)
    return on_pvp_tag(gMarioStates[a], gMarioStates[v])
end

function mode.carries(localIndex)
    local np = localIndex ~= nil and gNetworkPlayers[localIndex] or nil
    if np == nil then return false end
    for _, side in ipairs(SIDES) do
        if flag_state(side) == np.globalIndex then return true end
    end
    return false
end

function mode.may_attack(attacker, victim)
    if attacker == nil or victim == nil then return false end
    return not mode.carries(attacker.playerIndex)
end

function mode.cluster()
    local out = OF.gamemodes.side_cluster(captures, target_captures())
    if out == nil then return nil end

    for _, side in ipairs({ out.left, out.right }) do
        if side ~= nil and (side.key == "red" or side.key == "blue") then
            side.icon = mode.flag_icon(side.key)
        end
    end
    return out
end

mode.target_now = target_captures

OF.gamemodes.register(mode)
