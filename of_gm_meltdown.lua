OF = OF or {}

local ROLE_RACE = "racing"
local ROLE_HOME = "home"
local FINISH_RADIUS = 400

local HOME_KEY = "ofTrialHome"
local RUNNERS_HOME_ALL = 16
local RUNNERS_HOME = RUNNERS_HOME_ALL
local RUNNERS_HOME_MAX = RUNNERS_HOME_ALL

local REAL_METAL = MARIO_METAL_CAP or 0x00000004

local wearing = false

local hostNoFloor = false
local hostNoGoal = false

local finished = false

local function runners_home()
    local value = gGlobalSyncTable[HOME_KEY]

    if type(value) ~= "number" or value < 1 then
        value = OF.gamemodes.target_for("meltdown")
    end
    if type(value) ~= "number" or value < 1 then return RUNNERS_HOME end
    return math.floor(value)
end

OF.gm_meltdown_runners_home = runners_home

local function wants_everybody()
    return runners_home() >= RUNNERS_HOME_ALL
end

OF.gm_meltdown_wants_everybody = wants_everybody

local function still_out()
    return OF.gamemodes.contending(ROLE_RACE)
end

OF.gm_meltdown_still_out = still_out

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

local mode = {
    key = "meltdown",
    name = "Meltdown",
    blurb = "every floor is lava and your metal never runs out - ride it to the flagpole",

    how = "Every floor in the level burns for the whole round.\n"
        .. "You are metal, and the metal never runs out.\n"
        .. "So the lava cannot hurt you - it throws you.\n"
        .. "Ride the throws. A flagpole stands at the far end.\n"
        .. "Your time is taken the moment you reach it.\n"
        .. "Fastest wins; on the clock, whoever got closest.",
    minPlayers = 2,

    maps = "surveyed",
    surveyKeys = { "floodStart", "floodGoal" },

    room = { sweep = { "cannons" } },
    music = SEQ_LEVEL_HOT,
    defaultLimit = 300,
    mods = "lava=3,water=5",

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

function mode.death_place()
    local at = OF.gamemodes.round_place()
    if at == nil then return nil end
    local spot = OF.gamemodes.surveyed(at, "floodStart")
    if spot == nil then return nil end
    return { x = spot.x, y = spot.y, z = spot.z,
             level = at.level, area = at.area }
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

function mode.terms()
    if wants_everybody() then
        return OF.lang.t("everybody to the flagpole")
    end
    local wanted = runners_home()
    if wanted <= 1 then return OF.lang.t("first to the flagpole") end
    return OF.lang.fill("first @ to the flagpole", tostring(wanted))
end

function mode.pin()
    if not OF.util.asks(OF.ground, "counted")
        or OF.ground.counted() <= 0 then
        hostNoFloor = true
    end

    local np = gNetworkPlayers[0]
    if np == nil then return end
    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    if OF.gamemodes.surveyed(here, "floodGoal") == nil then hostNoGoal = true end
end

function mode.setup(players, options)
    OF.util.publish(HOME_KEY,
        math.floor(tonumber(options ~= nil and options.target) or RUNNERS_HOME))
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RACE)
    end
end

function mode.on_start()
    finished = false
end

local function metal_off()
    if not wearing then return end
    wearing = false
    local m = gMarioStates[0]
    if m == nil then return end
    if (m.capTimer or 0) > 0 then return end
    if not OF.util.has_flag(m.flags or 0, REAL_METAL) then return end
    m.flags = m.flags - REAL_METAL
end

function mode.cleanup()
    finished = false
    metal_off()

    hide_goal()

    hostNoFloor = false
    hostNoGoal = false

    if OF.util.is_host() then
        OF.util.publish(HOME_KEY, nil)
    end
end

function mode.late_join(localIndex)
    if localIndex == 0 then finished = false end
    return ROLE_RACE
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or OF.gamemodes.role(0) == ""
        or not OF.util.can_play(0) then
        metal_off()
        return
    end

    wearing = true
    if not OF.util.has_flag(m.flags or 0, REAL_METAL) then
        m.flags = (m.flags or 0) + REAL_METAL
    end
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

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        hide_goal()
        return
    end
    show_goal()
end

function mode.host_update()

    if hostNoFloor then
        hostNoFloor = false
        hostNoGoal = false
        if not OF.util.asks(OF.ground, "counted") then
            OF.gamemodes.abandon("This build cannot set the floor alight.")
        else
            OF.gamemodes.abandon("This level has no floor to set alight.")
        end
        return
    end
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
        r, g, b = 255, 200, 120
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
