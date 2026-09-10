OF = OF or {}

local ROLE_RACE = "racing"
local ROLE_HOME = "home"
local FINISH_RADIUS = 400

local HOME_KEY = "ofTrialHome"
local RUNNERS_HOME_ALL = 16
local RUNNERS_HOME = RUNNERS_HOME_ALL
local RUNNERS_HOME_MAX = RUNNERS_HOME_ALL

local REMOUNT_FRAMES = 15

local function runners_home()
    local value = gGlobalSyncTable[HOME_KEY]

    if type(value) ~= "number" or value < 1 then
        value = OF.gamemodes.target_for("shellrace")
    end
    if type(value) ~= "number" or value < 1 then return RUNNERS_HOME end
    return math.floor(value)
end

OF.gm_shellrace_runners_home = runners_home

local function wants_everybody()
    return runners_home() >= RUNNERS_HOME_ALL
end

OF.gm_shellrace_wants_everybody = wants_everybody

local function still_out()
    return OF.gamemodes.contending(ROLE_RACE)
end

OF.gm_shellrace_still_out = still_out

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local RIDE_GROUND = at_load("allocate_mario_action",
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)
local RIDE_AIR = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)

OF.gm_shellrace = OF.gm_shellrace or {}
OF.gm_shellrace.RIDE_GROUND = RIDE_GROUND
OF.gm_shellrace.RIDE_AIR = RIDE_AIR

local RIDE_JUMP_VEL = 42.0
local RIDE_JUMP_FROM_SPEED = 0.25

local WALL_KEEP = 0.34

local PUSH_OFF = 30.0

local function turn_around(m)
    local yaw = m.faceAngle[1] or 0
    if yaw >= 0 then yaw = yaw - 0x8000 else yaw = yaw + 0x8000 end
    m.faceAngle[1] = yaw
    if m.marioObj ~= nil then m.marioObj.oMoveAngleYaw = yaw end
end

local function act_ride_ground(m)
    if m == nil then return false end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        if set_mario_y_vel_based_on_fspeed ~= nil then
            set_mario_y_vel_based_on_fspeed(m, RIDE_JUMP_VEL, RIDE_JUMP_FROM_SPEED)
        end
        set_mario_action(m, RIDE_AIR, 0)
        return false
    end

    update_shell_speed(m)
    set_character_animation(m, CHAR_ANIM_RIDING_SHELL)

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, RIDE_AIR, 0)
    elseif step == GROUND_STEP_HIT_WALL then

        set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, false)
        turn_around(m)
        mario_set_forward_vel(m, (m.forwardVel or 0) * WALL_KEEP)
    end
    return false
end

local function act_ride_air(m)
    if m == nil then return false end
    set_character_animation(m, CHAR_ANIM_JUMP_RIDING_SHELL)
    update_air_without_turn(m)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then

        set_mario_action(m, RIDE_GROUND, 1)
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    end
    return false
end

if RIDE_GROUND ~= nil and RIDE_AIR ~= nil then
    at_load("hook_mario_action", RIDE_GROUND, { every_frame = act_ride_ground })
    at_load("hook_mario_action", RIDE_AIR, { every_frame = act_ride_air })
end

local function shell_name(localIndex)
    return "shell" .. localIndex
end

local function hide_shells()
    for index = 0, MAX_PLAYERS - 1 do
        OF.gamemodes.hide_token(shell_name(index))
    end
end

local function place_shell(index, m)
    if m == nil or m.pos == nil then
        OF.gamemodes.hide_token(shell_name(index))
        return nil
    end
    local token = OF.gamemodes.show_token(shell_name(index),
        E_MODEL_KOOPA_SHELL,
        { x = m.pos.x, y = m.pos.y, z = m.pos.z })
    if token == nil then return nil end
    local o = m.marioObj
    if o ~= nil and o.oMoveAngleYaw ~= nil then
        token.oFaceAngleYaw = o.oMoveAngleYaw
    end
    return token
end

local function riding(index)
    local np = gNetworkPlayers[index]
    if np == nil or not np.connected then return false end
    local role = OF.gamemodes.role(index)
    if role ~= ROLE_RACE and role ~= ROLE_HOME then return false end
    if not OF.util.can_play(index) then return false end
    return OF.gamemodes.in_place_room(OF.gamemodes.here_place(0), index)
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil then return end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.key ~= "shellrace" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local index = m.playerIndex
    if type(index) ~= "number" then return end
    if not riding(index) then return end
    place_shell(index, m)
end)

local function tidy_shells()
    for index = 0, MAX_PLAYERS - 1 do
        if not riding(index) then
            OF.gamemodes.hide_token(shell_name(index))
        end
    end
end

local function goal_place()
    local at = OF.gamemodes.round_place()
    if at == nil then return nil end
    local spot = OF.gamemodes.surveyed(at, "floodGoal")
    if spot == nil then return nil end
    return { x = spot.x, y = spot.y, z = spot.z,
             level = at.level, area = at.area }
end

local function show_goal()
    local at = goal_place()
    if at == nil then
        OF.gamemodes.hide_token("finish")
        return
    end
    OF.gamemodes.mark_flag("finish", at)
end

local function hide_goal()
    OF.gamemodes.hide_token("finish")
end

local function my_distance()
    local at = goal_place()
    if at == nil then return nil end
    return OF.gamemodes.distance_to_place(at, 0)
end

local function home_order()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HOME)) do
        local row = gPlayerSyncTable[entry.localIndex]
        local at = (row ~= nil and type(row.ofGmTime) == "number")
            and row.ofGmTime or math.huge
        if entry.np ~= nil then
            table.insert(list, {
                localIndex = entry.localIndex,
                name = entry.np.name,
                at = at,
            })
        end
    end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.name < b.name
    end)
    return list
end

local function leaders()
    local order = home_order()
    if #order == 0 then return {} end
    local best = order[1].at
    if best == math.huge then return { order[1].name } end
    local names = {}
    for _, row in ipairs(order) do
        if row.at ~= best then break end
        table.insert(names, row.name)
    end
    return names
end

local function winner_of(names)
    if #names == 0 then return nil, nil end
    if #names == 1 then return names[1], names[1] end
    return { names = names }, OF.util.list_of(names)
end

local sinceRide = 0
local finished = false
local hostNoGoal = false

local mode = {
    key = "shellrace",
    name = "Shell Circuit",
    blurb = "start to flagpole on a shell that never lets go - fastest wins",

    how = "Everybody rides a shell and cannot get off it.\n"
        .. "The round opens at the start the host walked.\n"
        .. "A flagpole stands at the other end. Get to it.\n"
        .. "Water and lava are road; a wall only turns you round.\n"
        .. "Your time is taken the moment you reach it.\n"
        .. "Fastest wins; on the clock, whoever got closest.",
    minPlayers = 2,

    maps = "surveyed",
    surveyKeys = { "floodStart", "floodGoal" },

    room = { sweep = { "cannons" } },
    music = SEQ_LEVEL_SLIDE,
    defaultLimit = 300,

    teams = false,

    resultsBy = "survival",
    target = { name = "runners home",
               asks = "How many have to reach the flagpole",
               default = RUNNERS_HOME,
               min = 1, max = RUNNERS_HOME_MAX, step = 1 },

    place = function()
        local at = goal_place()
        if at == nil then return nil end

        if not OF.gamemodes.in_place_room(at) then return nil end
        at.label = "the flagpole"
        at.r, at.g, at.b = 120, 255, 140
        return at
    end,
}

function mode.terms()
    if wants_everybody() then
        return OF.lang.t("everybody to the flagpole")
    end
    local wanted = runners_home()
    if wanted <= 1 then return OF.lang.t("first to the flagpole") end
    return OF.lang.fill("first @ to the flagpole", tostring(wanted))
end

function mode.setup(players, options)
    OF.util.publish(HOME_KEY,
        math.floor(tonumber(options ~= nil and options.target) or RUNNERS_HOME))
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RACE)
    end
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    local at = OF.gamemodes.surveyed(here, "floodStart")
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z,
             level = np.currLevelNum, area = np.currAreaIndex }
end

function mode.death_place()
    local at = OF.gamemodes.round_place()
    if at == nil then return nil end
    local spot = OF.gamemodes.surveyed(at, "floodStart")
    if spot == nil then return nil end
    return { x = spot.x, y = spot.y, z = spot.z,
             level = at.level, area = at.area }
end

function mode.pin()

    local np = gNetworkPlayers[0]
    if np == nil then return end
    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    if OF.gamemodes.surveyed(here, "floodGoal") == nil then hostNoGoal = true end
end

function mode.late_join(localIndex)
    return ROLE_RACE
end

function mode.on_start()
    sinceRide = 0
    finished = false
end

function mode.cleanup()
    sinceRide = 0
    finished = false

    hide_shells()
    hide_goal()

    hostNoGoal = false

    if OF.util.is_host() then
        OF.util.publish(HOME_KEY, nil)
    end
end

local RIDE_GROUPS = nil

local function may_ride(m)
    if m == nil or m.action == nil then return false end
    if (m.health or 0) < 0x100 then return false end
    if RIDE_GROUPS == nil then
        RIDE_GROUPS = {
            [ACT_GROUP_STATIONARY] = true,
            [ACT_GROUP_MOVING] = true,
            [ACT_GROUP_AIRBORNE] = true,
        }
    end
    return RIDE_GROUPS[m.action & ACT_GROUP_MASK] == true
end

local function on_the_ride(m)
    if m == nil or RIDE_GROUND == nil then return false end
    return m.action == RIDE_GROUND or m.action == RIDE_AIR
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_RACE then return end
    if not OF.util.can_play(0) then return end
    if RIDE_GROUND == nil then return end

    if on_the_ride(m) then
        sinceRide = 0
        return
    end

    sinceRide = sinceRide + 1
    if sinceRide < REMOUNT_FRAMES then return end
    if not may_ride(m) then return end

    sinceRide = 0
    if (m.forwardVel or 0) < PUSH_OFF then mario_set_forward_vel(m, PUSH_OFF) end
    set_mario_action(m, RIDE_GROUND, 0)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if finished then return end
    if OF.gamemodes.role(0) ~= ROLE_RACE then return end
    if not OF.util.can_play(0) then return end

    local away = my_distance()
    if away == nil or away >= FINISH_RADIUS then return end

    finished = true

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    OF.util.publish_row(0, "ofScore", 1)
    OF.gamemodes.set_role(0, ROLE_HOME)
    OF.notify.show("You made it to the flagpole", "good", 5)
    OF.sounds.play(OF.sounds.PICK)
end

function mode.host_update()

    if hostNoGoal then
        hostNoGoal = false
        OF.gamemodes.abandon("This level has no flagpole in it.")
        return
    end

    local home = OF.gamemodes.with_role(ROLE_HOME)
    local out = still_out()
    if OF.gamemodes.race_over(#home, #out, runners_home()) then
        local who, said = winner_of(leaders())
        if who ~= nil then
            OF.gamemodes.finish("@ takes it to the flagpole.", who, said)
            return
        end
    end

    if #out == 0 and #home == 0 then
        OF.gamemodes.finish("Nobody was left to reach it.")
        return
    end
end

function mode.on_timeout()

    local who, said = winner_of(leaders())
    if who ~= nil then
        OF.gamemodes.finish("@ takes it to the flagpole.", who, said)
        return
    end

    local at = goal_place()
    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_RACE),
        function(entry)
            if at == nil then return nil end
            return OF.gamemodes.distance_to_place(at, entry.localIndex)
        end,
        true)

    if best == nil then
        OF.gamemodes.finish("Nobody got near the flagpole.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw, nobody reached it.")
    else
        OF.gamemodes.finish("@ got closest.", names[1], names[1])
    end
end

function mode.scenery()
    tidy_shells()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        hide_goal()
        return
    end
    show_goal()
end

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local role = OF.gamemodes.role(0)
    local text, r, g, b

    if role == ROLE_HOME then
        local row = gPlayerSyncTable[0]
        local at = (row ~= nil and type(row.ofGmTime) == "number")
            and row.ofGmTime or 0
        text = OF.lang.fill("Home in @", OF.gamemodes.clock(at))
        r, g, b = 120, 255, 140
    elseif role == ROLE_RACE then
        local away = my_distance()
        if away ~= nil then

            text = OF.lang.fill("@ - @ to the flagpole",
                OF.gamemodes.clock(OF.gamemodes.since_start()),
                string.format("%.0f", away))
        else
            text = OF.lang.fill("@ - the flagpole is elsewhere",
                OF.gamemodes.clock(OF.gamemodes.since_start()))
        end
        r, g, b = 200, 230, 255
    else
        return
    end

    OF.util.banner(text, 0.95, r, g, b)

    local rows = {}
    for _, row in ipairs(home_order()) do
        table.insert(rows, {
            localIndex = row.localIndex,
            name = row.name,
            right = row.at == math.huge and "--"
                or OF.gamemodes.clock(row.at),
        })
    end
    if #rows > 0 then
        OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
            OF.lang.t("Home"), rows, { column = 130 })
    end
end

OF.gamemodes.register(mode)
