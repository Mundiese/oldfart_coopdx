OF = OF or {}

local ROLE_FIGHT = "in the fight"
local TARGET_CAPTURES = 3

local PICKUP_REACH = 160
local CAPTURE_REACH = 160
local REACH_HEIGHT = 250
local RETURN_SECONDS = 10
local RETURN_FRAMES = RETURN_SECONDS * 30
local GRACE_FRAMES = 15

local DROP_COOLDOWN = 30
local COMEBACK_GAP = 2
local CARRY_HEIGHT = 120
local CARRIER_SCALE = 0.4

local AT_HOME = -1
local DROPPED = -2

local FLAG_KEY   = "ofOfFlag"
local DROP_KEY   = "ofOfDrop"
local HOME_KEY   = "ofOfHome"
local BASE_KEY   = "ofOfBase"
local LEVEL_KEY  = "ofOfLevel"
local AREA_KEY   = "ofOfArea"
local RED_KEY    = "ofOfRed"
local BLUE_KEY   = "ofOfBlue"
local TARGET_KEY = "ofOfTarget"
local ROUND_KEYS = { "ofOfFlag", "ofOfDrop", "ofOfHome", "ofOfBase", "ofOfLevel",
    "ofOfArea", "ofOfRed", "ofOfBlue", "ofOfTarget" }

local SIDES = { "red", "blue" }
local OTHER = { red = "blue", blue = "red" }

local CARRY_DAMAGE = 2

local function carry_damage()
    return CARRY_DAMAGE
end

local function number_key(key, fallback)
    local value = gGlobalSyncTable[key]
    if type(value) ~= "number" then return fallback end
    return value
end

local function flag_state() return number_key(FLAG_KEY, AT_HOME) end

local function captures(side)
    return number_key(side == "red" and RED_KEY or BLUE_KEY, 0)
end

local function target_captures()
    local value = number_key(TARGET_KEY, TARGET_CAPTURES)
    if value <= 0 then return TARGET_CAPTURES end
    return value
end

local function one_point(key, index)
    local text = gGlobalSyncTable[key]
    if type(text) ~= "string" or text == "" then return nil end
    return OF.gamemodes.unpack_points(text)[index or 1]
end

local function home() return one_point(HOME_KEY) end
local function base_of(side) return one_point(BASE_KEY, side == "blue" and 2 or 1) end
local function drop_spot() return one_point(DROP_KEY) end

local function same_spot(a, b)
    return a ~= nil and b ~= nil and math.abs(a.x - b.x) < 1 and math.abs(a.y - b.y) < 1
        and math.abs(a.z - b.z) < 1
end

local function defending()
    local at = home()
    if at == nil then return nil end
    for _, side in ipairs(SIDES) do
        if same_spot(at, base_of(side)) then return side end
    end
    return nil
end

local function attacking()
    local side = defending()
    return side ~= nil and OTHER[side] or nil
end

local function capture_worth(side)
    if captures(OTHER[side]) - captures(side) >= COMEBACK_GAP then return 2 end
    return 1
end

local function side_of(localIndex)
    if not OF.util.asks(OF.teams, "of") then return nil end
    local key = OF.teams.of(localIndex)
    if key ~= "red" and key ~= "blue" then return nil end
    return key
end

local function my_side() return side_of(0) end

local function sides_on()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

local function on_the_pitch(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil or not np.connected then return false end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]
    if type(level) ~= "number" or np.currLevelNum ~= level then return false end
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
for _, action in ipairs({ ACT_BUBBLED, ACT_DROWNING, ACT_WATER_DEATH,
    ACT_STANDING_DEATH, ACT_QUICKSAND_DEATH, ACT_ELECTROCUTION, ACT_SUFFOCATION,
    ACT_DEATH_ON_STOMACH, ACT_DEATH_ON_BACK, ACT_EATEN_BY_BUBBA }) do
    if action ~= nil then DEATHS[action] = true end
end

local function is_dead(localIndex)
    local m = gMarioStates[localIndex]
    return m ~= nil and DEATHS[m.action] == true
end

local function can_touch(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or is_dead(localIndex) then return false end
    return OF.util.action_group(m.action) ~= OF.util.action_group(ACT_GROUP_CUTSCENE)
end

local function flag_spot()
    local state = flag_state()
    if state == AT_HOME then return home() end
    if state == DROPPED then return drop_spot() end
    local carrier = OF.util.local_from_global(state)
    local m = carrier ~= nil and gMarioStates[carrier] or nil
    if m == nil or m.pos == nil then return nil end
    return { x = m.pos.x, y = m.pos.y + CARRY_HEIGHT, z = m.pos.z }
end

local function carrier_side()
    local state = flag_state()
    if state < 0 then return nil end
    local carrier = OF.util.local_from_global(state)
    if carrier == nil then return nil end
    return side_of(carrier)
end

local onFloor = 0
local grace = 0
local carriedAt = nil
local droppedBy = nil
local droppedFor = 0
local prevHurt = 0
local seenState = AT_HOME
local seenDefence = nil
local floorFor = 0
local doubleSaid = false

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    target = { name = "captures to win",
               asks = "How many captures win the round",
               default = TARGET_CAPTURES,
               min = 1, max = 10, step = 1 },
    key = "oneflag",
    name = "One Flag CTF",
    blurb = "one side defends the flag, the other steals it home",
    blurbTeams = "one side defends the flag, the other steals it home",
    how = "One flag stands at the defending side's base.\n"
        .. "Attackers carry it into THEIR OWN base to score.\n"
        .. "A hit knocks it off the carrier - who cannot hit back.\n"
        .. "A defender's touch sends a loose flag home: their point.\n"
        .. "Ten seconds loose and it goes home: the defence held.\n"
        .. "After every point the sides swap.\n"
        .. "A carrier takes double damage.\n"
        .. "Two behind, and your captures count double.\n"
        .. "First side to the target wins; then the clock.",
    aims = { [ROLE_FIGHT] = "Attack: steal the flag home. Defend: stop the carrier." },

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

    pointBanner = "POINT",
    rolesDiffer = true,
    roleNoun = function()
        local mine, attack = my_side(), attacking()
        if mine == nil or attack == nil then return nil end
        return mine == attack and "Attack" or "Defend"
    end,
    options = {
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

function mode.terms()
    return OF.lang.fill("first to @ - steal it home, or stop the steal",
        string.format("%.0f", target_captures()))
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
    end
    OF.util.publish(TARGET_KEY, options.target or TARGET_CAPTURES)
    OF.util.publish(RED_KEY, 0)
    OF.util.publish(BLUE_KEY, 0)
    OF.util.publish(FLAG_KEY, AT_HOME)
    OF.util.publish(DROP_KEY, nil)
    OF.util.report(OF.rules.lend("interactions", "oneflag",
        PLAYER_INTERACTIONS_PVP))
end

local function flat(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

local function lay_bases(here)
    local red = OF.gamemodes.surveyed(here, "ctfRed")
    local blue = OF.gamemodes.surveyed(here, "ctfBlue")
    if red ~= nil and blue ~= nil then return red, blue end
    local list = OF.gamemodes.surveyed_list(here, "points", 2)
    if list ~= nil and #list >= 2 then return list[1], list[2] end
    local spots = OF.gamemodes.derived_spots(here, 16) or {}
    local best, a, b = -1, nil, nil
    for i = 1, #spots do
        for j = i + 1, #spots do
            local d = flat(spots[i], spots[j])
            if d > best then best, a, b = d, spots[i], spots[j] end
        end
    end
    return a, b
end

function mode.pin()
    if not OF.util.is_host() then return end
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)
    local red, blue = lay_bases(here)
    if red == nil or blue == nil then
        OF.util.publish(BASE_KEY, nil)
        OF.util.publish(HOME_KEY, nil)
        return
    end
    OF.util.publish(BASE_KEY, OF.gamemodes.pack_points({ red, blue }))

    local first = math.random(2) == 1 and "red" or "blue"
    OF.util.publish(HOME_KEY, OF.gamemodes.pack_points({ first == "red" and red or blue }))
    OF.util.publish(FLAG_KEY, AT_HOME)
    OF.util.publish(DROP_KEY, nil)
    onFloor, grace, carriedAt = 0, 0, nil
end

function mode.side_place(side)
    if side ~= "red" and side ~= "blue" then return nil end
    local at = base_of(side)
    local level = gGlobalSyncTable[LEVEL_KEY]
    if at == nil or type(level) ~= "number" then return nil end
    return { x = at.x, y = at.y, z = at.z, level = level,
             area = gGlobalSyncTable[AREA_KEY] }
end

function mode.death_place(from)
    local side = my_side()
    if side ~= "red" and side ~= "blue" then return mode.side_place(side) end
    return OF.gamemodes.team_respawn(side, from, mode)
end

function mode.spawn_focus(side)
    if side ~= "red" and side ~= "blue" then return nil end
    if flag_state() == AT_HOME then return nil end
    return flag_spot()
end

function mode.late_join(localIndex)
    return ROLE_FIGHT
end

local function reset_host()
    if not OF.util.is_host() then return end
    onFloor, grace, carriedAt = 0, 0, nil
    droppedBy, droppedFor = nil, 0
end

local function reset_round_state()
    reset_host()
    seenState, floorFor = AT_HOME, 0
    local m = gMarioStates[0]
    prevHurt = m ~= nil and (m.hurtCounter or 0) or 0
end

function mode.on_start()
    reset_round_state()
    seenDefence = defending()
    doubleSaid = false

end

function mode.cleanup()
    OF.rules.give_back("interactions", "oneflag")
    OF.gamemodes.hide_token("oneflag")
    reset_round_state()
    prevHurt, seenDefence = 0, nil
    if OF.util.is_host() then
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
end

local function end_on_score()
    local target = target_captures()
    for _, side in ipairs(SIDES) do
        if captures(side) >= target then
            OF.gamemodes.finish(OF.teams.result_text(captures("red"), captures("blue")),
                OF.gamemodes.team_winner(OF.teams.find(side)))
            return true
        end
    end
    return false
end

local function send_home(text)
    if not OF.util.is_host() then return end
    OF.util.publish(FLAG_KEY, AT_HOME)
    OF.util.publish(DROP_KEY, nil)
    onFloor, grace, carriedAt = 0, 0, nil
    droppedBy, droppedFor = nil, 0
    if text ~= nil then OF.notify.send_all(text, "info", 3) end
end

local function point_and_swap(side, worth)
    if not OF.util.is_host() then return false end
    OF.util.publish(side == "red" and RED_KEY or BLUE_KEY, captures(side) + worth)
    local nextDefence = attacking()
    local at = nextDefence ~= nil and base_of(nextDefence) or nil
    if at ~= nil then OF.util.publish(HOME_KEY, OF.gamemodes.pack_points({ at })) end
    send_home(nil)
    return end_on_score()
end

local function drop_at(spot)
    if not OF.util.is_host() then return end
    local state = flag_state()
    if state >= 0 then droppedBy, droppedFor = state, 0 end
    carriedAt = nil
    if spot == nil then
        send_home(nil)
        return
    end
    OF.util.publish(DROP_KEY, OF.gamemodes.pack_points({ spot }))
    OF.util.publish(FLAG_KEY, DROPPED)
    onFloor = 0
end

local function carrier_still_good(localIndex)
    if localIndex == nil then return false end
    if OF.gamemodes.role(localIndex) ~= ROLE_FIGHT then return false end
    if not OF.gamemodes.can_play(localIndex) then return false end
    if not on_the_pitch(localIndex) then return false end
    if is_dead(localIndex) then return false end
    return side_of(localIndex) ~= nil
end

local function nearest_taker(spot, side)
    if not OF.util.is_host() then return nil end
    local best, bestAt = nil, nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        local index = entry.localIndex
        local np = gNetworkPlayers[index]
        local barred = np ~= nil and np.globalIndex == droppedBy
            and droppedFor < DROP_COOLDOWN
        if OF.gamemodes.can_play(index) and side_of(index) == side
            and on_the_pitch(index) and can_touch(index) and not barred then
            local d = within(index, spot, PICKUP_REACH)
            if d ~= nil and (bestAt == nil or d < bestAt) then best, bestAt = index, d end
        end
    end
    return best
end

local function on_pvp_tag(attacker, victim)
    if not OF.util.is_host() then return end
    if attacker == nil or victim == nil then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "oneflag" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[victim.playerIndex]
    if np == nil or flag_state() ~= np.globalIndex or grace > 0 then return end
    local a, v = side_of(attacker.playerIndex), side_of(victim.playerIndex)
    if a == nil or v == nil or a == v then return end
    drop_at({ x = victim.pos.x, y = victim.pos.y, z = victim.pos.z })
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not sides_on() then return end
    if home() == nil then return end
    local defence, attack = defending(), attacking()
    if defence == nil then return end
    if grace > 0 then grace = grace - 1 end
    droppedFor = droppedFor + 1

    local state = flag_state()
    if state >= 0 then
        local carrier = OF.util.local_from_global(state)
        if not carrier_still_good(carrier) then
            drop_at(carriedAt)
            return
        end
        local m = gMarioStates[carrier]
        carriedAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z }

        local side = side_of(carrier)
        local goal = side == attack and base_of(attack) or nil
        if goal ~= nil and within(carrier, goal, CAPTURE_REACH) ~= nil then

            point_and_swap(side, capture_worth(side))
        end
        return
    end

    if state == DROPPED then
        onFloor = onFloor + 1
        if onFloor >= RETURN_FRAMES then
            point_and_swap(defence, 1)
            return
        end

        local spot = drop_spot()
        local back = spot ~= nil and nearest_taker(spot, defence) or nil
        if back ~= nil then
            point_and_swap(defence, 1)
            return
        end
    end

    local spot = state == DROPPED and drop_spot() or home()
    if spot == nil then return end
    local taker = nearest_taker(spot, attack)
    if taker ~= nil then
        local np = gNetworkPlayers[taker]
        OF.util.publish(FLAG_KEY, np.globalIndex)
        OF.util.publish(DROP_KEY, nil)
        grace, onFloor = GRACE_FRAMES, 0
        local m = gMarioStates[taker]
        carriedAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    end
end

function mode.overtime()
    if not sides_on() then return false end
    local side = carrier_side()
    if side == nil then return false end
    local red, blue = captures("red"), captures("blue")
    if red == blue then return true end
    return side == (red < blue and "red" or "blue")
end

function mode.still_winnable()
    return sides_on()
end

function mode.on_timeout()
    if not sides_on() then
        OF.gamemodes.finish("Nobody had a side to carry for.")
        return
    end
    local red, blue = captures("red"), captures("blue")
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, red)
        return
    end
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(OF.teams.find(red > blue and "red" or "blue")))
end

function mode.standing(localIndex)
    local side = side_of(localIndex)
    if side == nil then return nil end
    return tostring(captures(side))
end

function mode.say_near_if()
    if not on_the_pitch(0) then return false end
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    local spot = flag_spot()
    if flag_state() < 0 and spot ~= nil and within(0, spot, PICKUP_REACH) ~= nil then
        return OF.gamemodes.say_near()
    end
    local attack = attacking()
    if flag_state() == np.globalIndex and attack ~= nil and my_side() == attack
        and within(0, base_of(attack), CAPTURE_REACH) ~= nil then
        return OF.gamemodes.say_near()
    end
    return false
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    mode.say_near_if()
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil then return end
    local state = flag_state()
    local mine = my_side()

    local defence = defending()

    if defence ~= seenDefence then
        if defence ~= nil and seenDefence ~= nil and OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("sideswitch", nil, mine ~= nil
                and (mine == OTHER[defence] and OF.lang.t("You attack now") or OF.lang.t("You defend now"))
                or nil)
        end
        if defence ~= nil then
            OF.gamemodes.cue(mine == OTHER[defence] and "good" or "hazard")
        end
        seenDefence = defence
    end

    if state ~= seenState then
        if state == np.globalIndex then
            OF.gamemodes.cue("good")
        elseif seenState == np.globalIndex and state == AT_HOME then

            local row = gPlayerSyncTable[0]
            OF.util.publish_row(0, "ofScore", (row ~= nil and row.ofScore or 0) + 1)
        elseif state >= 0 and mine ~= nil and seenState < 0 then

            local carrier = OF.util.local_from_global(state)
            local theirs = carrier ~= nil and side_of(carrier) ~= mine
            if theirs then OF.gamemodes.cue("hazard") end
            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("FLAG TAKEN"), nil,
                    { side = theirs and "them" or "us", quiet = true })
            end
        end
        seenState = state
    end
    if state == DROPPED then floorFor = floorFor + 1 else floorFor = 0 end

    local hurt = m.hurtCounter or 0
    if state == np.globalIndex and m.action ~= ACT_SHOT_FROM_CANNON then
        local again = carry_damage() - 1
        if hurt > prevHurt and again > 0 then
            m.hurtCounter = hurt + (hurt - prevHurt) * again
            hurt = m.hurtCounter
        end
    end
    prevHurt = hurt
end

local function side_colour(side)
    local team = OF.util.asks(OF.teams, "find") and OF.teams.find(side) or nil
    if team == nil then return 230, 230, 230 end
    return team.r, team.g, team.b
end

local flagTarget = { id = "flag", label = "the flag", priority = 90,
    compass = "offscreen" }
local goalTarget = { id = "goal", ring = { radius = CAPTURE_REACH } }
local oneList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #oneList, 1, -1 do oneList[i] = nil end
    if not on_the_pitch(0) then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local mine = my_side()
    local state = flag_state()
    local carrying = state == np.globalIndex

    if not carrying then
        local r, g, b = side_colour(defending())
        flagTarget.tone = { r, g, b }
        flagTarget.pos, flagTarget.player, flagTarget.ring = nil, nil, nil
        if type(state) == "number" and state >= 0 then
            flagTarget.player = OF.util.local_from_global(state)
        else
            flagTarget.pos = flag_spot()
            flagTarget.ring = { radius = PICKUP_REACH }
        end
        if flagTarget.pos ~= nil or flagTarget.player ~= nil then
            oneList[#oneList + 1] = flagTarget
        end
    end

    local attack = attacking()
    local goal = attack ~= nil and base_of(attack) or nil
    if goal ~= nil then
        local r, g, b = side_colour(attack)
        goalTarget.pos = goal
        goalTarget.tone = { r, g, b }
        goalTarget.label = (mine == attack) and "your base" or "their goal"
        goalTarget.priority = carrying and 95 or 40
        goalTarget.compass = carrying and "offscreen" or "never"
        oneList[#oneList + 1] = goalTarget
    end
    return oneList
end

function mode.scenery()
    OF.gamemodes.hear_sides(captures("red"), captures("blue"))
    local at = flag_spot()
    if at == nil or not on_the_pitch(0) then
        OF.gamemodes.hide_token("oneflag")
        return
    end
    local token = OF.gamemodes.mark_flag("oneflag", at)
    if token ~= nil then
        local np = gNetworkPlayers[0]
        local scale = 1.0
        if np ~= nil and flag_state() == np.globalIndex then scale = CARRIER_SCALE end
        OF.util.optional("obj_scale", nil, token, scale)
    end
end

function mode.draw_rings()

    if OF.util.asks(OF.markers, "ring") then return 0 end
    if not on_the_pitch(0) or not OF.util.asks(OF.markers, "place_ring") then return 0 end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil then return 0 end
    local function reach_to(at)
        if m == nil or m.pos == nil then return nil end
        local dx, dz = at.x - m.pos.x, at.z - m.pos.z
        return math.sqrt(dx * dx + dz * dz)
    end
    local drawn = 0
    local mine = my_side()
    local attack = attacking()
    local at = flag_spot()
    if at ~= nil and flag_state() ~= np.globalIndex then
        local r, g, b = side_colour(defending())

        OF.markers.place_ring(at, PICKUP_REACH, { r = r, g = g, b = b,
            distance = reach_to(at) })
        drawn = drawn + 1
    end
    local goal = attack ~= nil and base_of(attack) or nil
    if goal ~= nil then
        local r, g, b = side_colour(attack)
        OF.markers.place_ring(goal, CAPTURE_REACH, { r = r, g = g, b = b,
            distance = reach_to(goal) })
        drawn = drawn + 1
    end
    return drawn
end

function mode.hud()
    local mine = my_side()
    mode.draw_rings()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local np = gNetworkPlayers[0]
    local flag = flag_state()
    local defence = defending()
    if np ~= nil and flag == np.globalIndex then
        state("carry", OF.lang.t("You have the flag"), { prio = 60, tone = "target" })
    elseif mine ~= nil and mine == defence then
        if flag == DROPPED then
            state("return", OF.lang.t("Return it"), { prio = 70, tone = "warn",
                figure = math.max(0, math.ceil((RETURN_FRAMES - floorFor) / 30)) })
        elseif flag >= 0 then
            state("taken", OF.lang.t("Flag taken"), { prio = 65, tone = "bad", colour = true })
        end
    end
    if mine ~= nil and capture_worth(mine) > 1 then
        if not doubleSaid and OF.util.asks(OF.hud, "banner") then
            doubleSaid = true
            OF.hud.banner("objective", OF.lang.t("DOUBLE POINTS"), OF.lang.t("Two behind"),
                { side = "us" })
        end
    else
        doubleSaid = false
    end
end

function mode.flag_icon()
    local flag = flag_state()
    local defence = defending()
    if flag == AT_HOME then return { icon = "flag", tone = defence or "ink", state = "home" } end
    if flag == DROPPED then return { icon = "flag", tone = defence or "ink", dim = true, state = "dropped" } end
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    return { icon = "flag", tone = "warn", dim = math.floor(now / 15) % 2 == 1, state = "carried" }
end

mode.AT_HOME = AT_HOME
mode.DROPPED = DROPPED
mode.RETURN_FRAMES = RETURN_FRAMES
mode.defending = defending

mode.on_tag = function(a, v)
    return on_pvp_tag(gMarioStates[a], gMarioStates[v])
end

function mode.carries(localIndex)
    local np = localIndex ~= nil and gNetworkPlayers[localIndex] or nil
    return np ~= nil and flag_state() == np.globalIndex
end

function mode.may_attack(attacker, victim)
    if attacker == nil or victim == nil then return false end
    return not mode.carries(attacker.playerIndex)
end

function mode.cluster()
    local out = OF.gamemodes.side_cluster(captures, target_captures())
    if out == nil then return nil end
    local attack = attacking()
    for _, side in ipairs({ out.left, out.right }) do
        if side ~= nil and side.key ~= nil and side.key == attack then
            side.icon = mode.flag_icon()
        end
    end
    return out
end

mode.target_now = target_captures

OF.gamemodes.register(mode)
