OF = OF or {}
OF.roundact = OF.roundact or {}

local roundact = OF.roundact

roundact.FIRST_PRIVATE_ACT = 7

roundact.CREDITS_ACT = 99

roundact.ROUND_ACT = 30
roundact.RUN_ACT = 31

local HUB = {}
local function hub_levels()
    if next(HUB) ~= nil then return HUB end
    for _, level in ipairs({ LEVEL_CASTLE, LEVEL_CASTLE_GROUNDS,
                             LEVEL_CASTLE_COURTYARD }) do
        if level ~= nil then HUB[level] = true end
    end
    return HUB
end

function roundact.is_hub(level)
    return level ~= nil and hub_levels()[level] == true
end

roundact.MAIN_COURSES = 15

function roundact.content_bound(level)
    if level == nil then return false end
    if roundact.is_hub(level) then return false end
    local course = OF.util.optional("get_level_course_num", nil, level)
    if type(course) ~= "number" then return true end
    return course >= 1 and course <= roundact.MAIN_COURSES
end

function roundact.private(act)
    return type(act) == "number" and act >= roundact.FIRST_PRIVATE_ACT
        and act ~= roundact.CREDITS_ACT
end

function roundact.holder()
    local modes = OF.gamemodes
    local round = OF.util.asks(modes, "state") and modes.state() ~= modes.OFF
    local run = OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running()
    if round and run then
        local scope = OF.roundscope
        if scope ~= nil and scope.screen_group ~= nil and scope.screen_group() == scope.RUN then
            return "run"
        end
        return "round"
    end
    if round then return "round" end
    if run then return "run" end
    return nil
end

local function watching(li)
    return OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(li) == true
end

local function sitting_out(li)
    return OF.util.asks(OF.speedrun, "is_excluded")
        and OF.speedrun.is_excluded(li) == true
end

local function away(li)
    return OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(li) == true
end

function roundact.plays(li)
    li = li or 0
    if roundact.holder() == nil then return false end

    if OF.util.asks(OF.roundscope, "dealt") then
        if OF.roundscope.dealt(li) ~= true then return false end

        local scope = OF.roundscope
        if scope.group ~= nil and OF.util.asks(OF.speedrun, "is_running")
            and OF.speedrun.is_running() and OF.util.asks(OF.gamemodes, "state")
            and OF.gamemodes.state() ~= OF.gamemodes.OFF then
            local want = roundact.holder() == "run" and scope.RUN or scope.ROUND
            return scope.group(li) == want
        end
        return true
    end
    return false
end

function roundact.watches(li)
    li = li or 0
    local holder = roundact.holder()
    if holder == nil then return false end
    if roundact.plays(li) then return false end
    if watching(li) then

        if li ~= 0 then return true end
        local target = OF.spectate.target
        if target == nil then return true end
        local at = OF.util.local_from_global(target)
        return at == nil or roundact.plays(at)
    end

    return false
end

function roundact.member(li)
    return roundact.plays(li) or roundact.watches(li)
end

local function wants_real_acts(holder)
    if holder == "run" then return true end
    local modes = OF.gamemodes
    local mode = OF.util.asks(modes, "current") and modes.current() or nil
    return mode ~= nil and mode.realActs == true
end

local function own_instance_act()
    if not OF.util.asks(OF.course, "instance_act") then return nil end
    return OF.course.instance_act(network_global_index_from_local(0))
end

function roundact.round_is_here(level)
    local modes = OF.gamemodes
    if not OF.util.asks(modes, "holding") or modes.holding() == nil then
        return true
    end
    return OF.util.asks(modes, "holds_level") and modes.holds_level(level) == true
end

function roundact.whole_game()
    local modes = OF.gamemodes
    local mode = OF.util.asks(modes, "current") and modes.current() or nil
    return mode ~= nil and (mode.wholeGame == true or mode.noCopy == true)
end

local function no_copy_at_all()
    local modes = OF.gamemodes
    local mode = OF.util.asks(modes, "current") and modes.current() or nil
    return mode ~= nil and mode.noCopy == true
end

roundact.ACT_WRAP = 32
roundact.ROUND_FAMILY = 7

function roundact.round_wrapped_act(act)
    local base = math.floor(tonumber(act) or 1)
    if base > roundact.ACT_WRAP then base = base % roundact.ACT_WRAP end
    if base < 1 or base > 6 then base = 1 end
    return base + roundact.ACT_WRAP * roundact.ROUND_FAMILY
end

function roundact.is_round_wrapped(act)
    if type(act) ~= "number" then return false end
    local low = roundact.ACT_WRAP * roundact.ROUND_FAMILY
    return act > low and act <= low + 6
end

function roundact.copy_act(level, holder, realActs, act)
    if level == nil or holder == nil then return nil end
    if roundact.is_hub(level) then return nil end

    if holder == "round" and realActs and roundact.content_bound(level)
        and not no_copy_at_all() then
        return roundact.round_wrapped_act(act)
    end
    if holder == "round" and roundact.whole_game() then return nil end

    if holder == "run" and OF.util.asks(OF.speedrun, "copy_act") then
        return OF.speedrun.copy_act(level, 1, network_global_index_from_local(0))
    end
    if realActs and roundact.content_bound(level) then return nil end
    return holder == "run" and roundact.RUN_ACT or roundact.ROUND_ACT
end

local function watched_act(level)
    if not OF.util.asks(OF.spectate, "is_spectating")
        or not OF.spectate.is_spectating(0) then
        return nil
    end
    local target = OF.spectate.target
    if target == nil then return nil end
    local at = OF.util.local_from_global(target)
    local np = at ~= nil and gNetworkPlayers[at] or nil
    if np == nil or np.currLevelNum ~= level then return nil end
    return np.currActNum
end

function roundact.act_for(level, act)
    local holder = roundact.holder()
    if holder == nil then return act end
    if act ~= nil and act == own_instance_act() then return act end

    if holder == "run" and OF.util.asks(OF.speedrun, "copy_act") then
        if roundact.plays(0) then
            local mine = OF.speedrun.copy_act(level, act,
                network_global_index_from_local(0))
            if mine == nil then return act end
            return mine
        end
        local theirs = watched_act(level)
        if theirs ~= nil and not roundact.is_hub(level) then return theirs end
        return act
    end

    if holder == "round" and not roundact.round_is_here(level) then return act end

    if holder == "run" and OF.util.asks(OF.speedrun, "is_arena")
        and OF.speedrun.is_arena(level)
        and not (OF.util.asks(OF.speedrun, "arena_is_shared")
            and OF.speedrun.arena_is_shared()) then
        return act
    end
    local copy = roundact.copy_act(level, holder, wants_real_acts(holder), act)
    if copy == nil then return act end
    return copy
end

function roundact.translate(level, act)
    roundact.unsettle()
    if not roundact.member(0) then return act end
    return roundact.act_for(level, act)
end

function roundact.opening_act(level, act)
    local copy = roundact.copy_act(level, "round", false)
    if copy == nil then return act end
    if act ~= nil and roundact.private(act) then return act end
    return copy
end

function roundact.plays_as(level, currAct, wanted)
    if currAct == wanted then return true end

    if roundact.is_round_wrapped(currAct) and type(wanted) == "number"
        and currAct % roundact.ACT_WRAP == wanted then
        return true
    end
    if currAct ~= roundact.RUN_ACT and currAct ~= roundact.ROUND_ACT then
        return false
    end
    return not roundact.content_bound(level) and not roundact.is_hub(level)
end

function roundact.has_copy(level)
    local holder = roundact.holder()
    if holder == nil or level == nil then return false end
    if holder == "round" and not roundact.round_is_here(level) then return false end
    return roundact.copy_act(level, holder, wants_real_acts(holder), 1) ~= nil
end

function roundact.separates(level)
    if not roundact.has_copy(level) then return false end
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    if np.currLevelNum == level and roundact.private(np.currActNum)
        and np.currActNum ~= own_instance_act() then
        return false
    end
    return true
end

local normalActs = {}

local function usable(level, act)
    if act == nil or roundact.private(act) then return false end
    if act == 0 and roundact.content_bound(level) then return false end
    return true
end

function roundact.normal_act(level)
    if level == nil then return 1 end
    if roundact.is_hub(level) then return 0 end
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and np.currLevelNum == level
            and usable(level, np.currActNum) and not roundact.member(i) then
            return np.currActNum
        end
    end
    local seen = normalActs[level]
    if usable(level, seen) then return seen end
    return 1
end

function roundact.forget_normal_acts()
    normalActs = {}
end

roundact.SETTLE_FRAMES = 45

roundact.MAX_TRIES = 3

roundact.SPOT_FRAMES = 300

local settled = 0
local tries = 0
local triedFor = nil
local spot = nil

function roundact.pending_spot()
    return spot
end

function roundact.forget()
    spot = nil
    tries, triedFor = 0, nil
    settled = 0
end

local function moves_its_own()
    local modes = OF.gamemodes
    local mode = OF.util.asks(modes, "current") and modes.current() or nil
    return mode ~= nil and mode.holdsPerRunner == true
end

function roundact.wanted_act()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local level, act = np.currLevelNum, np.currActNum
    if level == nil or level == 0 then return nil end

    if roundact.member(0) then

        if roundact.holder() == "round" and moves_its_own() then return nil end

        if roundact.holder() == "run" and roundact.plays(0)
            and OF.util.asks(OF.speedrun, "copy_act") then
            return nil
        end
        local want = roundact.act_for(level, act)
        if want ~= act then return want end

        if (act == roundact.ROUND_ACT or act == roundact.RUN_ACT)
            and roundact.holder() == "round" and not roundact.has_copy(level) then
            return roundact.normal_act(level)
        end
        return nil
    end

    if OF.util.asks(OF.roundscope, "standing") and OF.roundscope.standing(0) == "unknown" then
        return nil
    end
    if roundact.private(act) then return roundact.normal_act(level) end
    return nil
end

local function warp_pending()
    local net = OF.net
    if net == nil then return false end
    return net.pendingWarp ~= nil or net.pendingTarget ~= nil
        or net.pendingPos ~= nil
end

function roundact.move_to(act)
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return false end
    local level, area = np.currLevelNum, np.currAreaIndex or 1

    spot = { level = level, area = area, act = act,
             x = m.pos.x, y = m.pos.y, z = m.pos.z,
             yaw = m.faceAngle ~= nil and m.faceAngle.y or nil,
             frames = roundact.SPOT_FRAMES }

    if not OF.net.entrance_into_here(level, area) then
        local id = roundact.way_into_here()
        local into = OF.util.binding("warp_to_warpnode")
        if id ~= nil and into ~= nil then

            if OF.util.asks(OF.gamemodes, "hold_here") and OF.gamemodes.holding() ~= nil then
                OF.gamemodes.hold_here(level, area, act)
            end
            if into(level, area, act, id) then return true end
        end
    end

    if OF.net.warp_local(level, area, act, nil, "") then return true end

    spot = nil
    return OF.net.warp_local(level, 1, act, nil,
        "The round could not take you into its copy of this level.")
end

local DOOR_BEHAVIOURS = { "id_bhvDoorWarp", "id_bhvDoor", "id_bhvStarDoor" }
local function is_door(o)
    if o == nil then return false end
    for _, name in ipairs(DOOR_BEHAVIOURS) do
        local id = _G[name]
        if id ~= nil and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then return true end
    end
    return false
end

function roundact.way_into_here()
    local probe = OF.util.binding("area_get_warp_node")
    if probe == nil then return nil end
    local door = nil
    for id = 0, 0xFF do
        local node = probe(id)
        if node ~= nil then
            if not is_door(node.object) then return id end
            if door == nil then door = id end
        end
    end
    return door
end

local function land_on_spot()
    if spot == nil then return end
    spot.frames = spot.frames - 1
    if spot.frames <= 0 then spot = nil return end

    local np = gNetworkPlayers[0]
    if np == nil or not np.currAreaSyncValid then return end
    if np.currLevelNum ~= spot.level or np.currAreaIndex ~= spot.area
        or np.currActNum ~= spot.act then
        return
    end
    local here = spot
    spot = nil
    OF.util.place_player(0, here.x, here.y, here.z)
    local m = gMarioStates[0]
    if here.yaw ~= nil and m ~= nil and m.faceAngle ~= nil then
        m.faceAngle.y = here.yaw
    end
end

function roundact.update()
    settled = settled + 1
    land_on_spot()

    local np = gNetworkPlayers[0]
    if np == nil then return end
    if np.currLevelNum ~= nil and np.currLevelNum ~= 0
        and not roundact.is_hub(np.currLevelNum)
        and usable(np.currLevelNum, np.currActNum) and not roundact.member(0) then
        normalActs[np.currLevelNum] = np.currActNum
    end

    if settled < roundact.SETTLE_FRAMES then return end
    if not np.currAreaSyncValid then return end
    if spot ~= nil or warp_pending() then return end

    local want = roundact.wanted_act()
    if want == nil then
        tries, triedFor = 0, nil
        return
    end

    local key = tostring(np.currLevelNum) .. ":" .. tostring(want)
    if triedFor ~= key then tries, triedFor = 0, key end
    if tries >= roundact.MAX_TRIES then return end
    tries = tries + 1
    settled = 0
    roundact.move_to(want)
end

function roundact.unsettle()
    settled = 0
end

local ghosted = false

function roundact.is_ghost()
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    return roundact.watches(0) and roundact.private(np.currActNum)
        and np.currActNum ~= own_instance_act()
end

function roundact.settle_ghost()
    local want = roundact.is_ghost()
    if want then
        ghosted = true
        OF.util.intangible("roundact", true)
    elseif ghosted then
        ghosted = false
        OF.util.intangible("roundact", false)
    end
    return want
end

local GHOST_MAY = {}
local function ghost_may()
    if next(GHOST_MAY) ~= nil then return GHOST_MAY end
    for _, kind in ipairs({ INTERACT_DOOR, INTERACT_WARP_DOOR, INTERACT_WARP,
                            INTERACT_POLE, INTERACT_TEXT, INTERACT_IGLOO_BARRIER,
                            INTERACT_BBH_ENTRANCE }) do
        if kind ~= nil then GHOST_MAY[kind] = true end
    end
    return GHOST_MAY
end

function roundact.ghost_may_touch(interactType)
    return ghost_may()[interactType] == true
end

function roundact.may_attack(attacker, victim)
    if attacker == nil or victim == nil then return true end
    if roundact.holder() == nil then return true end
    local a, v = attacker.playerIndex, victim.playerIndex
    if a == nil or v == nil then return true end

    if OF.util.asks(OF.roundscope, "apart") and OF.roundscope.apart(a, v) then
        return false
    end
    return roundact.plays(a) == roundact.plays(v)
end

function roundact.shares_the_round()

    if OF.util.asks(OF.roundscope, "shares_room_with_round") then
        return OF.roundscope.shares_room_with_round() == true
    end
    return false
end

function roundact.game_angle(degrees)
    local raw = (tonumber(degrees) or 0) * 0x8000
    if raw < 0 then return -math.floor(-raw / 180) end
    return math.floor(raw / 180)
end

function roundact.stock_one(thing)
    if thing == nil or thing.bhv == nil then return nil end
    local turn = roundact.game_angle(thing.yaw)
    local pitch = roundact.game_angle(thing.pitch)
    local roll = roundact.game_angle(thing.roll)
    local params = thing.params or 0
    return OF.slots.spawn_sync(
        thing.bhv, thing.model, thing.x, thing.y, thing.z,
        function(o)
            o.oBehParams = params
            o.oBehParams2ndByte = math.floor(params / 0x10000) % 0x100
            o.oMoveAngleYaw = turn
            o.oFaceAngleYaw = turn
            o.oMoveAnglePitch = pitch
            o.oFaceAnglePitch = pitch
            o.oMoveAngleRoll = roll
            o.oFaceAngleRoll = roll
        end, true)
end

function roundact.stock_list(list)
    if list == nil or #list == 0 then return false end
    if roundact.stock_one(list[1]) == nil then return false end
    for index = 2, #list do roundact.stock_one(list[index]) end
    return true
end

roundact.STOCK = {

    [LEVEL_BBH or -2] = {
        [2] = {
            [1] = {
                { bhv = id_bhvHiddenStaircaseStep, model = E_MODEL_BBH_STAIRCASE_STEP,
                  x = 973, y = 0, z = 517, yaw = 0, params = 0 },
                { bhv = id_bhvHiddenStaircaseStep, model = E_MODEL_BBH_STAIRCASE_STEP,
                  x = 973, y = -206, z = 717, yaw = 0, params = 0 },
                { bhv = id_bhvHiddenStaircaseStep, model = E_MODEL_BBH_STAIRCASE_STEP,
                  x = 973, y = -412, z = 917, yaw = 0, params = 0 },
            },
        },
    },
    [LEVEL_JRB or -1] = {
        [1] = {
            [1] = {
                { bhv = id_bhvSunkenShipPart, model = E_MODEL_JRB_SUNKEN_SHIP,
                  x = 2385, y = 3589, z = 3727, yaw = 0, params = 0 },
                { bhv = id_bhvSunkenShipPart, model = E_MODEL_JRB_SUNKEN_SHIP_BACK,
                  x = 2385, y = 3589, z = 3727, yaw = 0, params = 0 },
                { bhv = id_bhvSunkenShipPart2, model = E_MODEL_JRB_SHIP_LEFT_HALF_PART,
                  x = 5385, y = -5520, z = 2428, yaw = 0, params = 0 },
                { bhv = id_bhvSunkenShipPart2, model = E_MODEL_JRB_SHIP_RIGHT_HALF_PART,
                  x = 5385, y = -5520, z = 2428, yaw = 0, params = 0 },
                { bhv = id_bhvInSunkenShip, model = E_MODEL_NONE,
                  x = 5385, y = -5520, z = 2428, yaw = 0, params = 0 },
                { bhv = id_bhvInSunkenShip2, model = E_MODEL_NONE,
                  x = 5385, y = -5520, z = 2428, yaw = 0, params = 0 },
            },
        },
    },
}

function roundact.stock_for(level, contentAct, area)
    local byLevel = roundact.STOCK[level]
    if byLevel == nil then return nil end
    local byAct = byLevel[contentAct or 1]
    if byAct == nil then return nil end
    return byAct[area or 1]
end

local function content_act()
    local modes = OF.gamemodes
    if OF.util.asks(modes, "round_place") then
        local place = modes.round_place()
        local mode = OF.util.asks(modes, "current") and modes.current() or nil
        if place ~= nil and mode ~= nil and type(mode.contentActs) == "table" then
            local wanted = mode.contentActs[place.level]
            if type(wanted) == "number" then return wanted end
        end
        if place ~= nil and place.act ~= nil and not roundact.private(place.act) then
            return place.act
        end
    end
    return 1
end
roundact.content_act = content_act

local STOCK_FRAMES = 300
local stocking = 0

function roundact.stock_tick()
    if stocking <= 0 then return false end
    stocking = stocking - 1

    local np = gNetworkPlayers[0]
    if np == nil or not np.currAreaSyncValid then return false end
    if np.currActNum ~= roundact.ROUND_ACT and np.currActNum ~= roundact.RUN_ACT then
        stocking = 0
        return false
    end
    if not roundact.content_bound(np.currLevelNum) then stocking = 0 return false end

    local want = roundact.stock_for(np.currLevelNum, content_act(), np.currAreaIndex)
    if want == nil or #want == 0 then stocking = 0 return false end
    if not OF.util.i_decide_here() then return false end

    if OF.util.optional("obj_get_first_with_behavior_id", nil, want[1].bhv) ~= nil then
        stocking = 0
        return false
    end
    if not roundact.stock_list(want) then return false end
    stocking = 0
    return true
end

function roundact.arm_stocking()
    stocking = STOCK_FRAMES
end

roundact.LAVA_THROWS = 4
roundact.LAVA_STAND_FRAMES = 45

roundact.LAVA_LIFT = 200

local lavaThrows, lavaStood, wasThrown = 0, 0, false
local safeGround = nil

local healthAtThrow = nil

local BOWSER_ARENAS = {}
local function bowser_arena(level)
    if next(BOWSER_ARENAS) == nil then
        for _, l in ipairs({ LEVEL_BOWSER_1, LEVEL_BOWSER_2, LEVEL_BOWSER_3 }) do
            if l ~= nil then BOWSER_ARENAS[l] = true end
        end
    end
    return level ~= nil and BOWSER_ARENAS[level] == true
end

local function burning(floor)
    return floor ~= nil and SURFACE_BURNING ~= nil and floor.type == SURFACE_BURNING
end

function roundact.forget_lava()
    lavaThrows, lavaStood, wasThrown = 0, 0, false
    safeGround, healthAtThrow = nil, nil
end

local function lava_live()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil or modes.state() ~= modes.ACTIVE then
        return false
    end
    return OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) == true
end

function roundact.spares_life()
    local modes = OF.gamemodes
    if modes == nil then return false end
    if OF.util.asks(modes, "is_ghost") and modes.is_ghost() == true then return true end
    local opening = OF.util.asks(modes, "opening") and modes.opening() or nil
    if opening == nil then return false end
    if opening.safe == true then return true end
    return opening.grace == true and OF.util.asks(modes, "in_grace")
        and modes.in_grace() == true
end

function roundact.lava_loop_level(level)
    return LEVEL_BOWSER_2 ~= nil and level == LEVEL_BOWSER_2
end

function roundact.lava_spot(m)
    local np = gNetworkPlayers[0]
    local level = np ~= nil and np.currLevelNum or nil
    local info = m ~= nil and m.spawnInfo or nil
    local start = info ~= nil and info.startPos or nil
    local spawn = nil
    if start ~= nil and type(start.x) == "number" then
        spawn = { x = start.x, y = start.y, z = start.z }
    end
    if bowser_arena(level) and spawn ~= nil then return spawn end

    local modes = OF.gamemodes
    if np ~= nil and OF.util.asks(modes, "return_spot") then
        local spot = modes.return_spot(level)
        if spot ~= nil and (spot.area == nil or spot.area == np.currAreaIndex)
            and type(spot.x) == "number" then
            return spot
        end
    end
    if safeGround ~= nil and np ~= nil and safeGround.level == level
        and safeGround.area == np.currAreaIndex then
        return safeGround
    end
    return spawn
end

function roundact.lift_out_of_lava(m)
    local spot = roundact.lava_spot(m)
    lavaThrows, lavaStood, wasThrown = 0, 0, false
    healthAtThrow = nil
    if spot == nil then return false end
    if not OF.util.place_player(0, spot.x, spot.y + roundact.LAVA_LIFT, spot.z) then
        return false
    end
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.hurtCounter = 0
    if ACT_FREEFALL ~= nil then set_mario_action(m, ACT_FREEFALL, 0) end
    return true
end

function roundact.lava_step(m)
    if m == nil or m.playerIndex ~= 0 or m.pos == nil then return false end
    if not lava_live() then
        if lavaThrows ~= 0 or lavaStood ~= 0 or safeGround ~= nil then
            roundact.forget_lava()
        end
        return false
    end

    local np = gNetworkPlayers[0]
    local airborne = OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x00000800)
    local onFloor = not airborne and m.floor ~= nil
        and (m.pos.y - (m.floorHeight or m.pos.y)) < 10
    if onFloor and not burning(m.floor) then
        lavaThrows, lavaStood = 0, 0
        healthAtThrow = nil
        if np ~= nil then
            safeGround = { level = np.currLevelNum, area = np.currAreaIndex,
                           x = m.pos.x, y = m.pos.y, z = m.pos.z }
        end
    end

    local firework = OF.powerups ~= nil and OF.powerups.FIREWORK_ARG ~= nil
        and (m.actionArg or 0) == OF.powerups.FIREWORK_ARG
    local thrown = ACT_LAVA_BOOST ~= nil and m.action == ACT_LAVA_BOOST and not firework

    local held = false
    if thrown and not wasThrown then
        lavaThrows = lavaThrows + 1
        local health = m.health or 0
        held = healthAtThrow ~= nil and health >= healthAtThrow
        healthAtThrow = health
    end
    wasThrown = thrown

    local metal = MARIO_METAL_CAP ~= nil and OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP)
    if onFloor and burning(m.floor) and not thrown and not metal then
        lavaStood = lavaStood + 1
    else
        lavaStood = 0
    end

    local spared = lavaThrows >= 1 and roundact.spares_life()
    local ghost = lavaStood >= 1 and OF.util.asks(OF.gamemodes, "is_ghost")
        and OF.gamemodes.is_ghost() == true

    local level = np ~= nil and np.currLevelNum or nil
    if not roundact.lava_loop_level(level) then return false end
    if lavaThrows >= roundact.LAVA_THROWS or held or spared or ghost
        or lavaStood >= roundact.LAVA_STAND_FRAMES then
        return roundact.lift_out_of_lava(m)
    end
    return false
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    roundact.unsettle()
    roundact.arm_stocking()
end)

local lastHolder = nil
hook_event(HOOK_UPDATE, function()
    local holder = roundact.holder()
    if holder ~= lastHolder then
        lastHolder = holder
        roundact.unsettle()
        tries, triedFor = 0, nil
    end
    roundact.update()
    roundact.stock_tick()
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    roundact.settle_ghost()
    roundact.lava_step(m)
end, OF.LOCAL_MARIO)

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if not roundact.is_ghost() then return end
    if roundact.ghost_may_touch(interactType) then return end
    return false
end)

hook_event(HOOK_ALLOW_PVP_ATTACK, function(attacker, victim)
    if roundact.may_attack(attacker, victim) then return end
    return false
end)

function roundact.skips_act_select(level)
    local holder = roundact.holder()
    if holder ~= "round" or not roundact.member(0) then return false end

    if wants_real_acts(holder) and roundact.content_bound(level) then return false end
    return roundact.has_copy(level)
end

hook_event(HOOK_USE_ACT_SELECT, function(level)
    if roundact.skips_act_select(level) then return false end
end)
