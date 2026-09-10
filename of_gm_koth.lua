OF = OF or {}

local ROLE_HUNT = "on the hunt"
local HILL_RADIUS = 550
local TARGET_SECONDS = 45

local HILL_STOREY = 300

local HILL_AIR = 700

local FLOOR_PROBE_UP = 500
local NO_FLOOR_BELOW = -10000

local function target_seconds()
    local value = gGlobalSyncTable.ofHillTarget
    if type(value) ~= "number" or value <= 0 then return TARGET_SECONDS end
    return value
end

local held = 0
local wasInside = false
local contested = false
local wasContested = false

local pulse = 0

local function hill_position()
    return {
        x = gGlobalSyncTable.ofHillX or 0,
        y = gGlobalSyncTable.ofHillY or 0,
        z = gGlobalSyncTable.ofHillZ or 0,
        level = gGlobalSyncTable.ofHillLevel or 0,
        area = gGlobalSyncTable.ofHillArea or 1,

        height = HILL_AIR,
    }
end

local function hill_spot()
    if gGlobalSyncTable.ofHillX == nil then return nil end
    return hill_position()
end

local function place_hill_flag()
    OF.gamemodes.mark_flag("hill", hill_spot())
end

local function place()
    local spot = hill_spot()
    if not OF.gamemodes.in_place_room(spot) then return nil end
    spot.label = "the hill"
    return spot
end

local function distance_to_hill()
    return OF.gamemodes.distance_to_place(hill_spot())
end

local function standing_in_hill(localIndex, at)
    local spot = at or hill_spot()
    local distance = OF.gamemodes.distance_to_place(spot, localIndex)
    if distance == nil or distance >= HILL_RADIUS then return false end
    local m = gMarioStates[localIndex or 0]
    if m == nil then return false end
    local floor = tonumber(m.floorHeight)
    if floor == nil then return false end
    return math.abs(floor - (spot.y or 0)) <= HILL_STOREY
end

local function score_of(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofScore == nil then return 0 end
    return s.ofScore
end

local mode = {
    target = { name = "seconds on the hill",
               asks = "How many seconds on the hill win the round",
               default = 45,
               min = 15, max = 180, step = 15 },
    key = "koth",

    place = place,
    name = "King of the Hill",
    blurb = "hold the circle the longest",

    blurbTeams = "hold the circle - and stand in it to stop them holding it",

    aims = { [ROLE_HUNT] = "Stand inside the circle and the seconds add up." },
    how = "A flag is planted and a circle drawn round it.\n"
        .. "Stand inside and the seconds add up.\n"
        .. "In sides, as many of them inside and nobody scores.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    pinsOnPlayers = true,

    maps = OF.gamemodes.ARENA_SET,

    room = { sweep = { "cannons" } },
    music = SEQ_LEVEL_KOOPA_ROAD,
    defaultLimit = 300,

    teams = true,

    scoreIsTime = true,
}

function mode.terms()
    return OF.lang.fill("first to @s on the hill",
        tostring(math.floor(target_seconds())))
end

function mode.setup(players, options)

    OF.util.publish("ofHillTarget", options.target or TARGET_SECONDS)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNT)
    end
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local sumX, sumZ, count = 0, 0, 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        local np = gNetworkPlayers[entry.localIndex]
        local m = gMarioStates[entry.localIndex]
        if np ~= nil and m ~= nil and m.pos ~= nil
            and np.currLevelNum == here.level
            and np.currAreaIndex == here.area then
            sumX = sumX + m.pos.x
            sumZ = sumZ + m.pos.z
            count = count + 1
        end
    end

    local centreX, centreY, centreZ = here.x, here.y, here.z
    if count > 0 then
        centreX = sumX / count
        centreZ = sumZ / count
    end

    local under = OF.util.optional("find_floor_height", nil,
        centreX, centreY + FLOOR_PROBE_UP, centreZ)
    if type(under) == "number" and under > NO_FLOOR_BELOW then
        centreY = under
    end

    local surveyed = OF.gamemodes.surveyed(here, "hill")
    if surveyed ~= nil then
        centreX, centreY, centreZ = surveyed.x, surveyed.y, surveyed.z
    end

    OF.util.publish("ofHillX", centreX)
    OF.util.publish("ofHillY", centreY)
    OF.util.publish("ofHillZ", centreZ)
    OF.util.publish("ofHillLevel", here.level)
    OF.util.publish("ofHillArea", here.area)
end

function mode.late_join(localIndex)
    return ROLE_HUNT
end

function mode.on_start()
    held = 0
    wasInside = false
    contested = false
    wasContested = false
    pulse = 0
    if OF.teams.in_play() then
        OF.notify.show("Stand in the circle - and stand in it to stop them", "info", 6)
    else
        OF.notify.show("Stand in the circle to score", "info", 6)
    end
end

function mode.cleanup()
    held = 0
    wasInside = false
    contested = false
    wasContested = false
    pulse = 0

    if OF.util.is_host() then
        OF.util.publish("ofHillTarget", nil)
        OF.util.publish("ofHillLevel", nil)
        OF.util.publish("ofHillArea", nil)
        OF.util.publish("ofHillX", nil)
        OF.util.publish("ofHillY", nil)
        OF.util.publish("ofHillZ", nil)
    end
end

local function bodies_in_hill()
    local counts = { red = 0, blue = 0, any = 0 }
    local spot = hill_spot()
    if spot == nil then return counts end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if OF.gamemodes.can_play(entry.localIndex) then

            if standing_in_hill(entry.localIndex, spot) then
                counts.any = counts.any + 1
                local side = OF.teams.of(entry.localIndex)
                if counts[side] ~= nil then counts[side] = counts[side] + 1 end
            end
        end
    end
    return counts
end

local function hill_state()
    local counts = bodies_in_hill()
    if not OF.teams.in_play() then
        return counts, false, nil
    end
    if counts.red == 0 and counts.blue == 0 then return counts, false, nil end
    if counts.red == counts.blue then return counts, true, nil end
    return counts, false, counts.red > counts.blue and "red" or "blue"
end

function mode.update()
    local inside = standing_in_hill(0)

    if inside ~= wasInside then
        wasInside = inside
        if inside then
            OF.sounds.play(OF.sounds.TICK)
        end
    end

    if not inside then
        contested = false
        wasContested = false
        return
    end

    if OF.teams.in_play() then
        local _, _, holder = hill_state()
        contested = holder ~= OF.teams.of(0)

        if contested and not wasContested then
            OF.sounds.play(OF.sounds.WARN)
        end
        wasContested = contested
        if contested then return end
    else
        contested = false
        wasContested = false
    end

    held = held + 1

    if held % 30 == 0 then
        OF.util.publish_row(0, "ofScore", math.floor(held / 30))
    end
end

function mode.host_update()
    local target = target_seconds()

    if OF.teams.in_play() then
        local red, blue = OF.teams.score("red"), OF.teams.score("blue")
        if red >= target or blue >= target then
            local winner = OF.teams.leader(red, blue)
            OF.gamemodes.finish(OF.teams.result_text(red, blue),
                OF.gamemodes.team_winner(winner))
        end
        return
    end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ holds the hill.", entry.np.name, entry.np.name)
            return
        end
    end
end

function mode.on_timeout()
    if OF.teams.in_play() then
        local winner = OF.teams.leader()
        OF.gamemodes.finish(OF.teams.result_text(), OF.gamemodes.team_winner(winner))
        return
    end

    local bestScore, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_HUNT),
        function(entry) return score_of(entry.localIndex) end,
        false,
        function(entry)
            return standing_in_hill(entry.localIndex) and 1 or 0
        end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody held the hill.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, bestScore)
    else
        OF.gamemodes.finish("@ wins with @ seconds.", names[1], names[1], bestScore)
    end
end

local CONTEST = { r = 255, g = 230, b = 120 }

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local target = target_seconds()
    pulse = pulse + 1

    local hill = hill_position()
    local screen = { x = 0, y = 0, z = 0 }
    local here = OF.gamemodes.in_place_room(hill_spot())

    local counts, deadlocked, holder = hill_state()
    if here then
        local gold = OF.util.gold()
        local ringR, ringG, ringB = gold.r, gold.g, gold.b
        local size, alpha = 3, 200
        if deadlocked then
            ringR, ringG, ringB = CONTEST.r, CONTEST.g, CONTEST.b
            size = 5

            alpha = 170 + math.floor(70 * (0.5 + 0.5 * math.sin(pulse * 0.12)))
        else
            local team = holder ~= nil and OF.teams.find(holder) or nil
            if team ~= nil then
                ringR, ringG, ringB = team.r, team.g, team.b
                size = 4
            elseif counts.any > 0 then

                ringR, ringG, ringB = 140, 255, 160
                size = 4
            end
        end
        OF.util.world_ring(hill_spot(), HILL_RADIUS, 40, size,
            ringR, ringG, ringB, alpha)
    end

    local close = standing_in_hill(0)

    if here and not close then
        hill.y = hill.y + 120
        if OF.util.world_screen(hill, screen) then

            OF.util.world_label(screen.x, screen.y, "HILL", 0.9,
                OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
        end
    end

    local distance = distance_to_hill()
    local mine = OF.teams.of(0)
    local clock = math.floor(held / 30) .. " / " .. target .. "s"
    local text, r, g, b
    if distance == nil then
        text = "You are not in the hill's area"
        r, g, b = 200, 160, 160
    elseif distance >= HILL_RADIUS then
        text = math.floor(distance - HILL_RADIUS) .. " units from the hill"
        r, g, b = 230, 230, 230
    elseif not close then

        text = "Not standing in the circle   -   " .. clock
        r, g, b = 230, 230, 230
    elseif deadlocked then

        text = "Contested - nobody is scoring   -   " .. clock
        r, g, b = CONTEST.r, CONTEST.g, CONTEST.b
    elseif holder ~= nil and holder ~= mine then

        text = OF.lang.fill("They hold it @ to @", tostring(counts[holder] or 0),
            tostring(counts[mine] or 0)) .. "   -   " .. clock
        r, g, b = 255, 160, 160
    else
        text = "In the hill   -   " .. clock
        r, g, b = 140, 255, 160
    end

    local top, x, width = OF.util.banner(text, 0.95, r, g, b)

    if top ~= nil and target > 0 then
        OF.util.banner_meter(top, x, width,
            OF.util.share_of(math.floor(held / 30), math.max(0, target - held / 30)),
            { r = r, g = g, b = b }, { r = 70, g = 70, b = 70 })
    end

    local board = OF.gamemodes.score_board(ROLE_HUNT, score_of, function(s) return s .. "s" end)
    OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
        OF.lang.t("Hill time"), board, { column = 130 })
end

function mode.scenery()
    place_hill_flag()
end

OF.gamemodes.register(mode)
