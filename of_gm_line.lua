OF = OF or {}

local ROLE_RACING = "racing"
local ROLE_OUT = "out"
local ROLE_HOME = "home"
local FINISH_RADIUS = 400

local RUNNERS_HOME_ALL = 16
local RUNNERS_HOME = RUNNERS_HOME_ALL
local RUNNERS_HOME_MAX = RUNNERS_HOME_ALL

local TARGET_KEY = "ofHillTarget"
local DRIFT_PER_FRAME = 2.0

local DRIFT_FRAMES = 6

local GREEN_MIN, GREEN_MAX = 2.5, 5.0
local RED_MIN, RED_MAX = 1.5, 3.0

local TURNING_SECONDS = 0.7

local LIGHT_RED, LIGHT_AMBER, LIGHT_GREEN = 0, 1, 2

local phaseFrames = 0

local lastX, lastZ = nil, nil
local driftedFor = 0
local wasLight = nil
local finished = false

local wasFloor = nil

local terrainWas = nil
local terrainLevel, terrainArea = nil, nil

local startedAt = nil

local leftTheLine = false

local lineWasAt = nil

local function light()
    return gGlobalSyncTable.ofLineLight or LIGHT_GREEN
end

local function runners_home()
    local value = gGlobalSyncTable[TARGET_KEY]

    if type(value) ~= "number" or value < 1 then
        value = OF.gamemodes.target_for("line")
    end
    if type(value) ~= "number" or value < 1 then return RUNNERS_HOME end
    return math.floor(value)
end

OF.gm_line_runners_home = runners_home

local function wants_everybody()
    return runners_home() >= RUNNERS_HOME_ALL
end

OF.gm_line_wants_everybody = wants_everybody

local function still_out()
    return OF.gamemodes.contending(ROLE_RACING)
end

OF.gm_line_still_out = still_out

local function finish_position()
    return {
        x = gGlobalSyncTable.ofHillX or 0,
        y = gGlobalSyncTable.ofHillY or 0,
        z = gGlobalSyncTable.ofHillZ or 0,
    }
end

local function line_spot()
    if gGlobalSyncTable.ofHillX == nil then return nil end
    local spot = finish_position()
    spot.level = gGlobalSyncTable.ofHillLevel or 0
    spot.area = gGlobalSyncTable.ofHillArea or 1
    return spot
end

local hostAway = {}

local function place()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if np.currLevelNum ~= (gGlobalSyncTable.ofHillLevel or 0) then return nil end
    if np.currAreaIndex ~= (gGlobalSyncTable.ofHillArea or 1) then return nil end

    local spot = finish_position()
    spot.label = "the line"
    spot.r, spot.g, spot.b = 120, 255, 140
    return spot
end

local function place_finish_flag()
    local at = place()
    if at == nil then
        OF.gamemodes.hide_token("finish")
        return
    end
    OF.gamemodes.mark_flag("finish", at)
end

local function place_start_pad()
    if startedAt == nil then
        OF.gamemodes.hide_token("start")
        return
    end

    OF.gamemodes.mark_place("start", E_MODEL_PURPLE_SWITCH, startedAt)
end

local function distance_to_line()
    local spot = place()
    if spot == nil then return nil end
    local m = gMarioStates[0]
    if m == nil then return nil end
    local dx = m.pos.x - spot.x
    local dz = m.pos.z - spot.z

    if math.abs(m.pos.y - spot.y) > 600 then return nil end
    return math.sqrt(dx * dx + dz * dz)
end

local function ring_the_line()
    if not OF.util.asks(OF.markers, "place_ring") then return end
    local at = place()
    if at == nil then return end
    OF.markers.place_ring(at, FINISH_RADIUS, {
        r = at.r, g = at.g, b = at.b,
        label = at.label, arrow = true,

        distance = distance_to_line(),
    })
end

local function am_racing()
    return OF.gamemodes.role(0) == ROLE_RACING
end

local function grippy_step()
    local entry = OF.util.asks(OF.modifiers, "BY_KEY")
        and OF.modifiers.BY_KEY["floor"] or nil
    if entry == nil or entry.levels == nil then return nil end
    for index, step in ipairs(entry.levels) do
        if step.class == SURFACE_CLASS_NOT_SLIPPERY then return index end
    end
    return nil
end

OF.gm_line_grip_step = grippy_step

local function wear_floor(step)
    if not OF.util.is_host() then return false end

    if not OF.util.asks(OF.modifiers, "set_round_level") then return false end
    return OF.modifiers.set_round_level("floor", step) == true
end

local function take_the_floor()
    local step = grippy_step()
    if step == nil then return false end
    local was = OF.util.asks(OF.modifiers, "level")
        and OF.modifiers.level("floor") or 0
    if not wear_floor(step) then return false end
    wasFloor = was
    return true
end

local function give_the_floor_back()
    if wasFloor == nil then return end
    local was = wasFloor
    wasFloor = nil
    if not OF.util.is_host() then return end
    wear_floor(was)
end

local TERRAIN_KINDS = 8

local function walkable_terrain(terrainType)
    if type(terrainType) ~= "number" then return nil end
    if terrainType % TERRAIN_KINDS ~= TERRAIN_SLIDE then return nil end
    return terrainType - TERRAIN_SLIDE + TERRAIN_STONE
end

OF.gm_line_walkable_terrain = walkable_terrain

local function grip_the_slide()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.area == nil or np == nil then return end
    if type(m.area.terrainType) ~= "number" then return end

    local at = line_spot()
    if at == nil then return end
    if np.currLevelNum ~= at.level or np.currAreaIndex ~= at.area then return end

    local walkable = walkable_terrain(m.area.terrainType)
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

local SWEEP_SPARED = { pickups = true, cannons = true }

local function sweep_keys()
    local keys = {}
    for _, option in ipairs(OF.util.asks(OF.arena, "OPTIONS")
        and OF.arena.OPTIONS or {}) do
        if not SWEEP_SPARED[option.key] then table.insert(keys, option.key) end
    end
    return keys
end

OF.gm_line_sweep_keys = sweep_keys

local sweptRound = false

local function sweep_the_course()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.arena, "arm") then return end

    if gGlobalSyncTable.ofArenaClear == true then return end
    OF.arena.arm(true, sweep_keys(), nil)
    sweptRound = true
end

local function give_the_course_back()
    if not OF.util.is_host() then return end
    if not sweptRound then return end
    sweptRound = false
    if OF.util.asks(OF.arena, "close") then OF.arena.close() end
end

local mode = {
    key = "line",
    name = "Red Light, Green Light",
    blurb = "run on green, freeze on red, first to the line wins",

    how = "Green light, a moment of amber, then red.\n"
        .. "Move on green. What moving on red costs is set below.\n"
        .. "You start on the pad and run at the flag.\n"
        .. "The floor grips for the round - slopes are walkable.\n"
        .. "The course is cleared - nothing in it walks into you.\n"
        .. "First across wins; everybody still in gets home.\n"
        .. "On the clock, whoever got closest.",
    minPlayers = 2,

    maps = "surveyed",

    saysOut = true,

    room = { rules = { cannons = 0 } },
    surveyKeys = { "lineStart", "lineFinish" },

    music = SEQ_LEVEL_SLIDE,
    defaultLimit = 240,

    resultsBy = "survival",
    place = place,

    teams = false,

    target = { name = "runners home",
               asks = "How many runners have to reach the line",
               default = RUNNERS_HOME,
               min = 1, max = RUNNERS_HOME_MAX, step = 1 },

    options = {
        { key = "red", name = "Moving on red",
          choices = {
              { key = "out", name = "puts you out",
                help = "the playground rule - one mistake and you watch the "
                    .. "rest of the round" },

              { key = "back", name = "sends you back to where you started",
                help = "nobody is ever out, so everybody who started is still "
                    .. "running at the end" },
          } },
    },
}

function mode.setup(players, options)

    OF.util.publish("ofLineLight", LIGHT_GREEN)

    OF.util.publish(TARGET_KEY, math.floor(tonumber(options ~= nil
        and options.target) or RUNNERS_HOME))

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RACING)
    end

    take_the_floor()

    if OF.util.asks(OF.rules, "lend") then
        OF.rules.lend("interactions", mode.key, PLAYER_INTERACTIONS_NONE)
    end
end

function mode.pin()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil then return end

    hostAway = {}

    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    local finish = OF.gamemodes.surveyed(here, "lineFinish")
    local at = finish or { x = m.pos.x, y = m.pos.y, z = m.pos.z }

    OF.util.publish("ofHillX", at.x)
    OF.util.publish("ofHillY", at.y)
    OF.util.publish("ofHillZ", at.z)
    OF.util.publish("ofHillLevel", np.currLevelNum)
    OF.util.publish("ofHillArea", np.currAreaIndex)

    sweep_the_course()
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    local at = OF.gamemodes.surveyed(here, "lineStart")
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z,
             level = np.currLevelNum, area = np.currAreaIndex }
end

function mode.late_join(localIndex)
    return ROLE_RACING
end

function mode.on_start()

    phaseFrames = math.floor(GREEN_MIN * 30)
    lastX, lastZ = nil, nil
    driftedFor = 0
    wasLight = nil
    finished = false
    leftTheLine = false
    lineWasAt = nil
    hostAway = {}
    startedAt = nil
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m ~= nil and m.pos ~= nil then
        startedAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z,
                      angle = m.faceAngle ~= nil and m.faceAngle.y or nil,
                      level = np ~= nil and np.currLevelNum or nil,
                      area = np ~= nil and np.currAreaIndex or nil }
    end
    if am_racing() then
        OF.notify.show("Run on green. Freeze on red.", "info", 6)
    end
end

function mode.cleanup()
    lastX, lastZ = nil, nil
    driftedFor = 0
    wasLight = nil
    finished = false
    leftTheLine = false
    lineWasAt = nil
    hostAway = {}
    startedAt = nil

    if OF.util.asks(OF.modifiers, "clear_dark") then OF.modifiers.clear_dark() end

    give_the_floor_back()
    release_the_slide()

    if OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("interactions", mode.key)
    end

    give_the_course_back()

    if OF.util.is_host() then
        OF.util.publish("ofHillLevel", nil)
        OF.util.publish("ofHillArea", nil)
        OF.util.publish("ofHillX", nil)
        OF.util.publish("ofHillY", nil)
        OF.util.publish("ofHillZ", nil)

        OF.util.publish(TARGET_KEY, nil)

        OF.util.publish("ofLineLight", nil)
    end
end

local LIGHT_COLOURS = {
    [LIGHT_RED]   = { 200, 70, 70 },
    [LIGHT_AMBER] = { 210, 170, 90 },
    [LIGHT_GREEN] = { 120, 200, 120 },
}

local function paint(value)
    if not OF.util.asks(OF.modifiers, "set_lighting") then return end
    local colour = LIGHT_COLOURS[value]
    if colour == nil then return end
    OF.modifiers.set_lighting(colour[1], colour[2], colour[3])
end

local function announce(value)
    if value == LIGHT_GREEN then
        OF.sounds.play(OF.sounds.GO)
    elseif value == LIGHT_AMBER then
        OF.sounds.play(OF.sounds.COUNT)
    else
        OF.sounds.play(OF.sounds.DENIED)
    end
end

hook_on_sync_table_change(gGlobalSyncTable, "ofLineLight", 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofLineLight") then
        return
    end
    if newVal == oldVal then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "line" then return end

    if LIGHT_COLOURS[newVal] == nil then return end

    paint(newVal)

    if OF.gamemodes.role(0) ~= "" then announce(newVal) end
end)

local function sent_back(reason)
    if startedAt == nil then return false end
    if not OF.util.asks(OF.net, "snap_to") then return false end
    OF.net.snap_to(startedAt.x, startedAt.y, startedAt.z, startedAt.angle)

    leftTheLine = false
    lastX, lastZ = nil, nil
    driftedFor = 0
    OF.notify.show(reason, "warn", 5)
    OF.sounds.play(OF.sounds.DENIED)
    return true
end

local function go_out(reason)
    if not am_racing() then return end

    if OF.gamemodes.option_is("red", "back") then
        if sent_back(OF.lang.fill("@ - back to where you started",
            OF.lang.t(reason))) then
            return
        end
    end
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.set_ghost(true)
    OF.notify.show(reason, "bad", 5)
    OF.sounds.play(OF.sounds.DENIED)
end

function mode.update()

    local spot = line_spot()
    if spot ~= nil then
        if lineWasAt == nil
            or lineWasAt.x ~= spot.x or lineWasAt.y ~= spot.y
            or lineWasAt.z ~= spot.z
            or lineWasAt.level ~= spot.level or lineWasAt.area ~= spot.area then
            lineWasAt = spot
            leftTheLine = false
        end
    end

    if not am_racing() then return end

    local m = gMarioStates[0]
    if m == nil then return end

    local value = light()

    local distance = distance_to_line()
    if distance ~= nil and distance >= FINISH_RADIUS then leftTheLine = true end

    if not finished and leftTheLine and distance ~= nil and distance < FINISH_RADIUS then
        finished = true

        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

        OF.util.publish_row(0, "ofScore", 1)

        OF.gamemodes.set_role(0, ROLE_HOME)

        OF.notify.show("You made it to the line", "good", 5)
        return
    end

    local movedBy = 0
    if lastX ~= nil then
        local dx, dz = m.pos.x - lastX, m.pos.z - lastZ
        movedBy = math.sqrt(dx * dx + dz * dz)
    end
    lastX, lastZ = m.pos.x, m.pos.z

    if value ~= LIGHT_RED then
        driftedFor = 0
        return
    end

    if movedBy <= DRIFT_PER_FRAME then
        driftedFor = 0
        return
    end

    driftedFor = driftedFor + 1
    if driftedFor >= DRIFT_FRAMES then
        driftedFor = 0
        go_out("You moved on red")
    end
end

local function roll(minSeconds, maxSeconds)
    local span = maxSeconds - minSeconds
    return math.floor((minSeconds + math.random() * span) * 30)
end

local DEAD_HEAT_SECONDS = 1 / 3

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

    local groupAt, groupPlace = nil, 1
    for index, row in ipairs(list) do
        if groupAt ~= nil and row.at < math.huge
            and row.at - groupAt <= DEAD_HEAT_SECONDS then
            row.place = groupPlace
        else
            row.place, groupPlace, groupAt = index, index, row.at
        end
    end

    local sharing = {}
    for _, row in ipairs(list) do
        sharing[row.place] = (sharing[row.place] or 0) + 1
    end
    for _, row in ipairs(list) do row.shared = sharing[row.place] > 1 end

    return list
end

local function leaders()
    local names = {}
    for _, row in ipairs(home_order()) do
        if row.place ~= 1 then break end
        table.insert(names, row.name)
    end
    return names
end

local function home_line(place, shared, total)
    if place == nil or total == nil or total < 2 then
        return OF.lang.t("You are home")
    end

    if not OF.util.asks(OF.stats, "ordinal") then
        return OF.lang.t("You are home")
    end
    if shared then
        return OF.lang.fill("You are home - joint @", OF.stats.ordinal(place))
    end
    return OF.lang.fill("You are home - @", OF.stats.ordinal(place))
end

OF.gm_line_home_line = home_line

local function winner_of(names)
    if #names == 0 then return nil, nil end
    if #names == 1 then return names[1], names[1] end
    return { names = names }, OF.util.list_of(names)
end

OF.gm_line_winner_of = winner_of

OF.gm_line_home_order = home_order
OF.gm_line_leaders = leaders

function mode.host_update()
    local at = line_spot()

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RACING)) do
        if at ~= nil then
            local away = OF.gamemodes.distance_to_place(at, entry.localIndex)
            if away ~= nil and away >= FINISH_RADIUS then
                hostAway[entry.localIndex] = true
            end
        end
    end

    local home = OF.gamemodes.with_role(ROLE_HOME)
    local out = still_out()
    if OF.gamemodes.race_over(#home, #out, runners_home()) then
        local who, said = winner_of(leaders())
        if who ~= nil then
            OF.gamemodes.finish("@ made it to the line.", who, said)
            return
        end
    end

    if #out == 0 and #home == 0 then
        if #OF.gamemodes.with_role(ROLE_RACING) == 0 then
            OF.gamemodes.finish("Everybody moved. Nobody made it.")
        else
            OF.gamemodes.finish("Nobody was left to reach it.")
        end
        return
    end

    phaseFrames = phaseFrames - 1
    if phaseFrames > 0 then return end

    local value = light()
    if value == LIGHT_GREEN then
        OF.util.publish("ofLineLight", LIGHT_AMBER)
        phaseFrames = math.floor(TURNING_SECONDS * 30)
    elseif value == LIGHT_AMBER then
        OF.util.publish("ofLineLight", LIGHT_RED)
        phaseFrames = roll(RED_MIN, RED_MAX)
    else
        OF.util.publish("ofLineLight", LIGHT_GREEN)
        phaseFrames = roll(GREEN_MIN, GREEN_MAX)
    end
end

function mode.terms()

    local back = OF.gamemodes.option_showing("line", "red") == "back"
    local wanted = runners_home()
    if wants_everybody() then
        if back then
            return OF.lang.t("everybody home - red sends you back")
        end
        return OF.lang.t("everybody home - move on red, you are out")
    end

    if wanted > 1 then
        if back then
            return OF.lang.fill("@ have to get home - red sends you back",
                tostring(wanted))
        end
        return OF.lang.fill("@ have to get home - move on red, you are out",
            tostring(wanted))
    end

    if back then
        return OF.lang.t("first across the line - red sends you back")
    end
    return OF.lang.t("first across the line - move on red, you are out")
end

function mode.on_timeout()

    local who, said = winner_of(leaders())
    if who ~= nil then
        OF.gamemodes.finish("@ made it to the line.", who, said)
        return
    end

    local at = line_spot()
    local bestName, bestDistance = nil, nil

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RACING)) do
        local np = entry.np
        if np ~= nil and at ~= nil and hostAway[entry.localIndex] then
            local distance = OF.gamemodes.distance_to_place(at, entry.localIndex)
            if distance ~= nil
                and (bestDistance == nil or distance < bestDistance) then
                bestDistance = distance
                bestName = np.name
            end
        end
    end

    if bestName ~= nil then
        OF.gamemodes.finish("@ got closest.", bestName, bestName)
    elseif #OF.gamemodes.with_role(ROLE_RACING) == 0 then
        OF.gamemodes.finish("Nobody was left to reach it.")
    else

        OF.gamemodes.finish("Nobody got away from the line.")
    end
end

local WORDS = {
    [LIGHT_RED]   = "RED - do not move",
    [LIGHT_AMBER] = "turning...",
    [LIGHT_GREEN] = "GREEN - go",
}

function mode.hud()

    ring_the_line()

    local screenWidth = djui_hud_get_screen_width()
    local value = light()
    local colour = LIGHT_COLOURS[value] or LIGHT_COLOURS[LIGHT_GREEN]

    OF.util.banner(OF.lang.t(WORDS[value] or ""), 1.0,
        colour[1], colour[2], colour[3])

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.util.banner(OF.lang.t("You are out - watch the rest"),
            1.0, 255, 140, 140, 255)
        return
    end

    if OF.gamemodes.role(0) == ROLE_HOME then
        local order = home_order()
        local place, shared = nil, false
        for _, row in ipairs(order) do
            if row.localIndex == 0 then place, shared = row.place, row.shared end
        end

        local wanted = runners_home()
        if wants_everybody() then wanted = #order + #still_out() end
        local opts = nil
        if wanted > 1 then
            opts = { under = { text = OF.lang.fill("@ of @ home",
                tostring(#order), tostring(wanted)) } }
        end
        OF.util.banner(home_line(place, shared, #order), 1.0,
            140, 255, 160, 255, opts)
        return
    end

    if not am_racing() then return end
    local distance = distance_to_line()
    if distance == nil then return end

    if not leftTheLine then
        OF.util.banner(OF.lang.t("Step away from the line to begin"), 0.7,
            255, 255, 255)
        return
    end

    OF.util.banner(OF.lang.fill("@ to the line", math.floor(distance)), 0.7,
        255, 255, 255)
end

function mode.scenery()

    grip_the_slide()
    place_finish_flag()

    place_start_pad()
end

OF.gamemodes.register(mode)
