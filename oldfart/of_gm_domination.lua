OF = OF or {}

local ROLE_HOLD = "holding the points"
local POINTS = 3
local NAMES = { "A", "B", "C" }

local AT_KEY     = "ofDomAt"
local LEVEL_KEY  = "ofDomLevel"
local AREA_KEY   = "ofDomArea"
local CAP_KEY    = "ofDomCap"
local RED_KEY    = "ofDomRed"
local BLUE_KEY   = "ofDomBlue"
local TARGET_KEY = "ofDomTarget"
local LOST_KEY   = "ofDomLost"
local TARGET_POINTS = 400

local FULL = 100

local CAPTURE_STEP = FULL / (5 * 30)

local CAPTURE_SPEEDS = { normal = 1, quick = 5 / 3, slow = 5 / 8 }

local ADVANTAGE_CAP = 1
local ADVANTAGE_BONUS = 0.5

local POINT_RADIUS = 500

local RATES = { [0] = 0, 1, 3, 7 }

local COMEBACK_AT = 0.25
local COMEBACK_SPEED = 1.5

local LOST_GRACE = 5 * 30

local REACHES = { 1100, 860, 660 }

local STOREY = 700

local function pack_points(list)
    local parts = {}
    for _, spot in ipairs(list) do
        table.insert(parts, string.format("%.0f %.0f %.0f", spot.x, spot.y, spot.z))
    end
    return table.concat(parts, "|")
end

local pointsText, pointsParsed, pointsCount = nil, nil, 0

local function parsed_points(text)
    if text ~= pointsText then
        local flat, count = {}, 0
        for part in string.gmatch(text, "[^|]+") do
            local x, y, z = string.match(part,
                "^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if x ~= nil and y ~= nil and z ~= nil and count < POINTS then
                local at = count * 3
                flat[at + 1], flat[at + 2], flat[at + 3] = x, y, z
                count = count + 1
            end
        end
        pointsText, pointsParsed, pointsCount = text, flat, count
    end
    return pointsParsed, pointsCount
end

local function points()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return {} end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]

    local flat, count = parsed_points(text)
    local list = {}
    for index = 1, count do
        local at = (index - 1) * 3
        list[index] = {
            x = flat[at + 1], y = flat[at + 2], z = flat[at + 3],
            level = level, area = area,
            index = index, name = NAMES[index] or "?",
        }
    end
    return list
end

local QUANT = 5

local function pack_meters(values)
    local parts = {}
    for index = 1, POINTS do
        local value = values[index] or 0
        local size = math.floor(math.abs(value) / QUANT) * QUANT
        if size == 0 then

            parts[index] = "0"
        elseif value < 0 then
            parts[index] = string.format("%.0f", -size)
        else
            parts[index] = string.format("%.0f", size)
        end
    end
    return table.concat(parts, "|")
end

local metersText, metersParsed = nil, nil

local function meters()
    local out = {}
    for index = 1, POINTS do out[index] = 0 end
    local text = gGlobalSyncTable[CAP_KEY]
    if type(text) ~= "string" or text == "" then return out end
    if text ~= metersText then
        local parsed = {}
        for index = 1, POINTS do parsed[index] = 0 end
        local index = 1
        for part in string.gmatch(text, "[^|]+") do
            if index > POINTS then break end
            parsed[index] = tonumber(part) or 0
            index = index + 1
        end
        metersText, metersParsed = text, parsed
    end
    for index = 1, POINTS do out[index] = metersParsed[index] end
    return out
end

local function owner_of(meter)
    if meter >= FULL then return "red" end
    if meter <= -FULL then return "blue" end
    return nil
end

local function target_points()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_POINTS end
    return value
end

local function score_of(side)
    local value = gGlobalSyncTable[side == "red" and RED_KEY or BLUE_KEY]
    if type(value) ~= "number" then return 0 end
    return value
end

local function held_by(side, list)
    list = list or meters()
    local count = 0
    for index = 1, POINTS do
        if owner_of(list[index] or 0) == side then count = count + 1 end
    end
    return count
end

local function side_of(localIndex)
    if not OF.util.asks(OF.teams, "of") then return nil end
    local key = OF.teams.of(localIndex)
    if key ~= "red" and key ~= "blue" then return nil end
    return key
end

local function my_side()
    return side_of(0)
end

local function sides_on()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

local function lost_left()
    local value = gGlobalSyncTable[LOST_KEY]
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

local function comeback_for(side)
    local mine = score_of(side)
    local theirs = score_of(side == "red" and "blue" or "red")
    if theirs - mine >= target_points() * COMEBACK_AT then return COMEBACK_SPEED end
    return 1
end

local held = {}
local lastSecond = nil
local lostFrames = 0
local pushing = {}

local seenOwner = {}
local pulse = 0

local lastOwner = {}
local lostSaid = false

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    target = { name = "points to win",
               asks = "How many points win the round",
               default = TARGET_POINTS,
               min = 50, max = 600, step = 25 },
    key = "domination",
    name = "Domination",

    blurb = "three points - hold two to pull ahead, all three to run away with it",

    blurbTeams = "three points - hold two to pull ahead, all three to run away with it",

    how = "Three points, A B and C, around where you land.\n"
        .. "Stand in one and it swings to your side.\n"
        .. "One they hold is dragged back through the middle.\n"
        .. "One point pays 1 a second, two pays 3, all three 7.\n"
        .. "Equal numbers inside and it does not move at all.\n"
        .. "A side well behind takes points half again faster.\n"
        .. "First side to the target wins; then the clock.",

    minPlayers = 2,
    sidesFrom = 2,

    pinsOnPlayers = false,

    maps = "surveyed",

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },

    surveyKeys = { "points" },

    surveyOut = { { level = LEVEL_THI, area = 1 }, { level = LEVEL_PSS, area = 1 },
        { level = LEVEL_VCUTM, area = 1 }, { level = LEVEL_TTC, area = 1 },
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_TTM, area = 1 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 } },

    music = SEQ_LEVEL_GRASS,
    defaultLimit = 300,

    teams = "always",

    symmetric = true,

    noMatchPoint = true,
    overtimeSub = "A point is being taken",
    boardTitle = "Points",
    options = {
        { key = "capture", name = "Capture speed",
          help = "how long one player takes to turn a point",
          choices = {
              { key = "normal", name = "normal", help = "about five seconds" },
              { key = "quick", name = "quick", help = "about three seconds" },
              { key = "slow", name = "slow", help = "about eight seconds" },
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

function mode.terms()
    local ladder = tostring(RATES[1]) .. "/" .. tostring(RATES[2])
        .. "/" .. tostring(RATES[3])
    return OF.lang.fill("first to @ - 1/2/3 points pay @ a second",
        string.format("%.0f", target_points()), ladder)
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HOLD)
    end

    OF.util.publish(TARGET_KEY, options.target or TARGET_POINTS)
    OF.util.publish(RED_KEY, 0)
    OF.util.publish(BLUE_KEY, 0)
    OF.util.publish(CAP_KEY, pack_meters({ 0, 0, 0 }))

    OF.util.report(OF.rules.lend("interactions", "domination",
        PLAYER_INTERACTIONS_PVP))
end

local function floor_under(x, z, from)
    local found = OF.util.optional("find_floor_height", nil, x, from + 400, z)
    if type(found) ~= "number" then return nil end
    if math.abs(found - from) > STOREY then return nil end
    return found
end

function mode.side_place(side)

    if side ~= "red" and side ~= "blue" then return nil end
    local list = points()
    local at = list[side == "red" and 1 or 2]
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z, level = at.level, area = at.area }
end

function mode.death_place(from)
    local side = my_side()
    if side ~= "red" and side ~= "blue" then return nil end

    local list = points()
    local values = meters()

    local measure = nil
    local room = list[1]
    if room ~= nil and type(from) == "table"
        and type(from.x) == "number" and type(from.y) == "number"
        and type(from.z) == "number"
        and from.level == room.level and from.area == room.area then
        measure = from
    end

    local held = {}
    for index = 1, POINTS do
        local at = list[index]
        if at ~= nil and owner_of(values[index] or 0) == side then
            table.insert(held, at)
        end
    end
    if held[1] == nil then return nil end
    local ctx = OF.gamemodes.spawn_context(side, measure, mode, room)
    ctx.noDeath = true
    local best = OF.gamemodes.pick_spawn(held, ctx, function(at)
        if measure == nil then return 0 end
        local dx = at.x - measure.x
        local dy = at.y - measure.y
        local dz = at.z - measure.z
        return -(dx * dx + dy * dy + dz * dz)
    end)
    if best == nil then return nil end
    return { x = best.x, y = best.y, z = best.z,
             level = best.level, area = best.area }
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    held = {}
    for index = 1, POINTS do held[index] = 0 end
    OF.util.publish(CAP_KEY, pack_meters(held))

    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)

    local sumX, sumZ, count = 0, 0, 0
    for _, entry in ipairs(OF.gamemodes.landed(OF.gamemodes.with_role(ROLE_HOLD))) do
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

    local centreX, centreZ = here.x, here.z
    if count > 0 then
        centreX = sumX / count
        centreZ = sumZ / count
    end

    local surveyed = OF.gamemodes.surveyed_list(here, "points", POINTS)
    if surveyed ~= nil and #surveyed >= POINTS then
        local set = {}
        for index = 1, POINTS do set[index] = surveyed[index] end
        OF.util.publish(AT_KEY, pack_points(set))
        return
    end

    local turn = math.random() * 2 * math.pi
    local function ring_at(reach, probe)
        local list = {}
        for step = 1, POINTS do
            local angle = turn + (step - 1) * (2 * math.pi / POINTS)
            local x = centreX + math.cos(angle) * reach
            local z = centreZ + math.sin(angle) * reach
            local y = here.y
            if probe then
                y = floor_under(x, z, here.y)
                if y == nil then return nil end
            end
            list[step] = { x = x, y = y, z = z }
        end
        return list
    end

    local chosen = nil
    for _, reach in ipairs(REACHES) do
        chosen = ring_at(reach, true)
        if chosen ~= nil then break end
    end
    if chosen == nil then
        chosen = ring_at(REACHES[#REACHES], false)
    end

    OF.util.publish(AT_KEY, pack_points(chosen))
end

function mode.late_join(localIndex)
    return ROLE_HOLD
end

function mode.on_start()
    held = {}
    for index = 1, POINTS do held[index] = 0 end
    lastSecond = nil
    pushing = {}
    seenOwner = {}
    pulse = 0

    lostFrames = 0
    lastOwner = {}
    lostSaid = false
    if OF.util.is_host() then OF.util.publish(LOST_KEY, 0) end

end

function mode.cleanup()

    OF.rules.give_back("interactions", "domination")

    held = {}
    lastSecond = nil
    pushing = {}
    seenOwner = {}
    pulse = 0

    if OF.util.is_host() then
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(CAP_KEY, nil)
        OF.util.publish(RED_KEY, nil)
        OF.util.publish(BLUE_KEY, nil)

        OF.util.publish(LOST_KEY, nil)
    end
end

local function bodies_on(spot)
    local red, blue = 0, 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HOLD)) do

        if OF.gamemodes.can_play(entry.localIndex) then
            local distance = OF.gamemodes.distance_to_place(spot, entry.localIndex)
            if distance ~= nil and distance <= POINT_RADIUS then
                local side = side_of(entry.localIndex)
                if side == "red" then red = red + 1
                elseif side == "blue" then blue = blue + 1 end
            end
        end
    end
    return red, blue
end

local function pay(list)
    local red = score_of("red") + RATES[held_by("red", list)]
    local blue = score_of("blue") + RATES[held_by("blue", list)]
    OF.util.publish(RED_KEY, red)
    OF.util.publish(BLUE_KEY, blue)
    return red, blue
end

function mode.host_update()

    if not sides_on() then
        lostFrames = lostFrames + 1

        OF.util.publish(LOST_KEY,
            math.max(0, math.ceil((LOST_GRACE - lostFrames) / 30)))
        if lostFrames >= LOST_GRACE then
            lostFrames = 0
            OF.util.publish(LOST_KEY, 0)
            OF.gamemodes.abandon("Domination lost its sides.")
        end
        return
    end

    if lostFrames > 0 then
        lostFrames = 0
        OF.util.publish(LOST_KEY, 0)
    end

    local list = points()
    if #list < POINTS then return end

    local published = meters()
    pushing = { red = false, blue = false }

    for index, spot in ipairs(list) do
        local red, blue = bodies_on(spot)
        local advantage = red - blue
        local now = held[index] or 0

        if advantage ~= 0 then

            local extra = math.min(math.abs(advantage) - 1, ADVANTAGE_CAP)
            local mover = advantage > 0 and "red" or "blue"
            local speed = CAPTURE_STEP * (1 + extra * ADVANTAGE_BONUS)
                * comeback_for(mover) * mode.capture_speed()
            if advantage > 0 then now = now + speed else now = now - speed end
            now = OF.util.clamp(now, -FULL, FULL)

            if owner_of(published[index] or 0) ~= mover then
                pushing[mover] = true
            end
        end

        held[index] = now
    end

    OF.util.publish(CAP_KEY, pack_meters(held))

    local second = gGlobalSyncTable.ofGmElapsed or 0
    if lastSecond == nil then

        lastSecond = second
        return
    end
    if second == lastSecond then return end
    lastSecond = second

    local red, blue = pay(meters())

    local target = target_points()
    if red < target and blue < target then return end
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, red)
        return
    end
    local winner = OF.teams.find(red > blue and "red" or "blue")
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(winner))
end

function mode.overtime()
    if not sides_on() then return false end
    local red, blue = score_of("red"), score_of("blue")
    if red == blue then
        return pushing.red == true or pushing.blue == true
    end
    return pushing[red < blue and "red" or "blue"] == true
end

function mode.on_timeout()

    if not sides_on() then
        OF.gamemodes.abandon("Nobody had a side to hold the points for.")
        return
    end
    local red, blue = score_of("red"), score_of("blue")
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, red)
        return
    end

    local winner = OF.teams.find(red > blue and "red" or "blue")
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(winner))
end

function mode.update()
    local mine = my_side()
    local list = points()
    local values = meters()

    if lost_left() > 0 then OF.gamemodes.tick_down(lost_left()) end

    for index = 1, POINTS do
        local now = owner_of(values[index] or 0)
        local was = seenOwner[index]
        seenOwner[index] = now

        if was ~= nil and was == mine and now == nil and list[index] ~= nil then
            OF.gamemodes.cue("hazard")
        end

        if was ~= now and now ~= nil and list[index] ~= nil then
            local name = list[index].name
            local before = lastOwner[index]
            if now == mine then
                local distance = OF.gamemodes.distance_to_place(list[index])
                if distance ~= nil and distance <= POINT_RADIUS then
                    local row = gPlayerSyncTable[0]
                    OF.util.publish_row(0, "ofScore",
                        (row ~= nil and row.ofScore or 0) + 1)
                end

                mode.say_point(name, "us")
            elseif mine ~= nil and before == mine then

                mode.say_point(name, "them")
            end
        end
        if now ~= nil then lastOwner[index] = now end
    end
end

function mode.capture_speed()
    local pick = OF.util.asks(OF.gamemodes, "option_now") and OF.gamemodes.option_now("capture") or nil
    return CAPTURE_SPEEDS[pick or "normal"] or 1
end

function mode.say_point(name, side)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    local word = side == "us" and OF.lang.fill("@ CAPTURED", name) or OF.lang.fill("@ LOST", name)
    return OF.hud.banner("objective", word, nil, { side = side })
end

local function nearest_open()
    local mine = my_side()
    local list = points()
    if #list == 0 then return nil end
    local values = meters()

    local best, bestAt, fallback, fallbackAt = nil, nil, nil, nil
    for index, spot in ipairs(list) do
        local distance = OF.gamemodes.distance_to_place(spot)
        if distance ~= nil then
            if fallbackAt == nil or distance < fallbackAt then
                fallback, fallbackAt = spot, distance
            end
            if owner_of(values[index] or 0) ~= mine then
                if bestAt == nil or distance < bestAt then
                    best, bestAt = spot, distance
                end
            end
        end
    end

    local spot = best or fallback
    if spot == nil then return nil end
    return { x = spot.x, y = spot.y, z = spot.z,
             label = OF.lang.fill("point @", spot.name) }
end

function mode.standing(localIndex)
    local side = side_of(localIndex)
    if side == nil then return nil end
    return string.format("%.0f", score_of(side))
end

function mode.scenery()
    local list = points()
    for index, spot in ipairs(list) do
        OF.gamemodes.mark_flag("dom" .. index, spot)
    end

    for index = #list + 1, POINTS do
        OF.gamemodes.hide_token("dom" .. index)
    end
end

local NEUTRAL = { r = 200, g = 200, b = 200 }
local CONTEST = { r = 255, g = 230, b = 120 }

local function colour_of(meter)
    local side = owner_of(meter)
    if side == nil then return NEUTRAL end
    local team = OF.util.asks(OF.teams, "find") and OF.teams.find(side) or nil
    if team == nil then return NEUTRAL end
    return team
end

local pointTargets = {}
local pointList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #pointList, 1, -1 do pointList[i] = nil end
    local list = points()
    if #list == 0 then return nil end
    local mine = my_side()
    local values = meters()
    local aim = nearest_open()
    for index, spot in ipairs(list) do
        if OF.gamemodes.in_place_room(spot) then
            local meter = values[index] or 0
            local hereRed, hereBlue = bodies_on(spot)
            local locked = hereRed > 0 and hereRed == hereBlue
            local partway = math.abs(meter) > 0 and math.abs(meter) < FULL
            local colour = (partway or locked) and CONTEST or colour_of(meter)
            local owner = owner_of(meter)
            local ours = mine ~= nil and owner == mine
            local t = pointTargets[index] or {}
            pointTargets[index] = t
            t.id = "point:" .. tostring(spot.name)
            t.pos = spot
            t.label = spot.name
            t.tone = { colour.r, colour.g, colour.b }

            local item = mode.point_icon(index, spot, meter)
            t.icon = t.icon or {}
            t.icon.name, t.icon.text, t.icon.fill = "letter", spot.name, item.fill
            t.icon.ring, t.icon.ringTone = item.ring, item.ringTone
            t.ring = t.ring or {}
            t.ring.radius = POINT_RADIUS
            t.contested = partway or locked
            t.urgent = ours and partway
            if aim ~= nil and aim.x == spot.x and aim.z == spot.z then
                t.priority, t.compass = 90, "offscreen"
            elseif not ours then
                t.priority, t.compass = 80, "offscreen"
            elseif partway then
                t.priority, t.compass = 85, "offscreen"
            else
                t.priority, t.compass = 30, "never"
            end
            pointList[#pointList + 1] = t
        end
    end
    return pointList
end

local iconItems = {}
function mode.point_icon(index, spot, meter)
    local owner = owner_of(meter)
    local partway = math.abs(meter) > 0 and math.abs(meter) < FULL
    local hereRed, hereBlue = bodies_on(spot)
    return {
        icon = "letter", text = spot.name,
        fill = owner,
        ring = partway and math.abs(meter) / FULL or nil,
        ringTone = partway and (meter > 0 and "red" or "blue") or nil,
        blink = hereRed > 0 and hereBlue > 0,
    }
end

function mode.state_icons()
    for i = #iconItems, 1, -1 do iconItems[i] = nil end
    local list = points()
    local values = meters()
    for index, spot in ipairs(list) do
        iconItems[#iconItems + 1] = mode.point_icon(index, spot, values[index] or 0)
    end
    return iconItems
end

function mode.hud()
    pulse = pulse + 1

    local list = points()
    local values = meters()

    for index, spot in ipairs(list) do
        local meter = values[index] or 0
        local hereRed, hereBlue = bodies_on(spot)
        local locked = hereRed > 0 and hereRed == hereBlue
        if OF.gamemodes.in_place_room(spot) and OF.util.asks(OF.markers, "place_ring")
            and not OF.util.asks(OF.markers, "ring") then
            local colour = colour_of(meter)
            local size, alpha = 3, 200
            local partway = math.abs(meter) > 0 and math.abs(meter) < FULL
            if partway or locked then
                colour = CONTEST
                size = 5
                alpha = 170 + math.floor(70 * (0.5 + 0.5 * math.sin(pulse * 0.12)))
            end
            OF.markers.place_ring(spot, POINT_RADIUS, {
                r = colour.r, g = colour.g, b = colour.b,
                alpha = alpha, size = size, segments = 40, style = "edge",
                distance = OF.gamemodes.distance_to_place(spot),
            })
        end
    end

    if #list > 0 and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("points", nil, { prio = 50, icons = mode.state_icons() })
    end

    local left = lost_left()
    if left > 0 then
        if not lostSaid and OF.util.asks(OF.hud, "banner") then
            lostSaid = true
            OF.hud.banner("roundstate", OF.lang.t("NO SIDES LEFT"),
                OF.lang.fill("Ending in @", string.format("%.0f", left)),
                { hold = left * 30 })
        end
    else
        lostSaid = false
    end
end

function mode.cluster() return OF.gamemodes.side_cluster(score_of, target_points()) end

mode.target_now = target_points

OF.gamemodes.register(mode)
