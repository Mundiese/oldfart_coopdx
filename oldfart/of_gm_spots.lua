OF = OF or {}

local WIRE_KEYS = { "ofSpotsAt", "ofSpotsAt2", "ofSpotsAt3", "ofSpotsAt4" }

local WIRE_CHUNK = 160
local LEVEL_KEY  = "ofSpotsLevel"
local AREA_KEY   = "ofSpotsArea"
local GRAB_KEY   = "ofSpotsGrab"
local ROUND_KEY  = "ofSpotsRound"
local CLAIM_KEY  = "ofSpotsClaim"
local ROLE_IN = "in"
local ROLE_OUT = "out"
local SPOT_RADIUS = 260

local MIN_SPOT_RADIUS = 150

local SPOT_DRAW_RANGE = 6000
local SPOT_NEAR_RANGE = 2000
local RING_RADIUS = 900
local GRAB_FRAMES = 120

local MAX_SPOTS = 15

local SPIN_MIN_DEGREES = 45
local SPIN_MAX_DEGREES = 120

local SPIN_PROBES = 24
local FLOOR_DROP = 700

local WALKS = {
    usual = { 5 * 30, 11 * 30 },
    short = { 3 * 30, 6 * 30 },
    long  = { 10 * 30, 22 * 30 },
}

local SHORT_BY = { one = 1, two = 2, three = 3 }

local walkLeft = 0
local resolved = true

local pulse = 0
local wasGrabbing = false

local wasSafe = false

local grabFrames = GRAB_FRAMES

local claimSpot, claimAt = 0, 0

local function walk_span()
    local row = WALKS[OF.gamemodes.option_now("walk") or "usual"] or WALKS.usual
    return row[1], row[2]
end

local function short_by(left)
    local said = OF.gamemodes.option_now("gap") or "auto"
    if said == "auto" then
        left = left or #OF.gamemodes.participants()
        if left >= 12 then return 3 end
        if left >= 7 then return 2 end
        return 1
    end
    return SHORT_BY[said] or 1
end

local ringX, ringZ = 0, 0
local spinPhase, spinRate = 0, 0

local function pack(spots)
    local parts = { string.format("%.0f", grabFrames / 30) .. "|" }
    if spots == nil then return parts end

    table.insert(parts,
        string.format("%.0f %.0f %.0f %.4f", ringX, ringZ, spinPhase, spinRate)
            .. "|")
    for _, spot in ipairs(spots) do
        table.insert(parts,
            string.format("%.0f %.0f %.0f", spot.x, spot.y, spot.z) .. "|")
    end
    return parts
end

local function phase_tag()
    return string.format("#%.0f|", spinPhase)
end

local function publish_places(spots)
    local kept = nil
    if spots ~= nil then
        kept = {}
        for index, spot in ipairs(spots) do kept[index] = spot end
    end

    local chunks = nil
    while true do
        chunks = OF.util.chunk_parts(pack(kept), WIRE_CHUNK - #phase_tag())
        if chunks ~= nil and #chunks <= #WIRE_KEYS then break end
        if kept == nil or #kept == 0 then

            chunks = { table.concat(pack(kept)) }
            break
        end
        table.remove(kept)
    end

    for index = #WIRE_KEYS, 1, -1 do
        local chunk = chunks[index]
        if chunk ~= nil and index > 1 then chunk = phase_tag() .. chunk end
        OF.util.publish(WIRE_KEYS[index], chunk or "")
    end
    return kept ~= nil and #kept or 0
end

local function places_text()
    return OF.util.joined(WIRE_KEYS)
end

local function grab_seconds()
    local text = places_text()
    if type(text) == "string" then
        local said = tonumber(string.match(text, "^(%d+)"))
        if said ~= nil and said > 0 then return said end
    end
    return grabFrames / 30
end

local function ring_now()
    local text = places_text()
    if type(text) ~= "string" then return nil end
    local cx, cz, phase, rate = text:match(
        "|(%-?[%d%.]+) (%-?[%d%.]+) (%d+) (%-?[%d%.]+)|")
    cx, cz, phase, rate = tonumber(cx), tonumber(cz), tonumber(phase),
        tonumber(rate)
    if cx == nil or cz == nil or phase == nil or rate == nil then return nil end
    return cx, cz, phase, rate
end

local spinSeenAt, spinSeen = nil, nil

local function spin_angle()
    local _, _, phase, rate = ring_now()
    if phase == nil then return 0 end
    if spinSeen ~= phase then
        spinSeen = phase
        spinSeenAt = clock_elapsed()
    end

    if rate == 0 then return 0 end
    return rate * math.max(0, clock_elapsed() - (spinSeenAt or 0))
end

local spotsMemo, spotsMemoKey = nil, nil

local lastWhole = nil

local function reads_whole(text, phase)
    for tag in text:gmatch("#(%d+)") do
        if tonumber(tag) ~= phase then return false end
    end
    return true
end

local function circle_radius(spots)
    local widest = SPOT_RADIUS
    for i = 1, #spots - 1 do
        for j = i + 1, #spots do
            local dx = spots[i].x - spots[j].x
            local dz = spots[i].z - spots[j].z
            local half = math.sqrt(dx * dx + dz * dz) / 2
            if half < widest then widest = half end
        end
    end

    return math.max(MIN_SPOT_RADIUS, math.floor(widest))
end

local function circles_that_fit(reach)
    if reach == nil or reach <= 0 then return 1 end
    local ratio = MIN_SPOT_RADIUS / reach
    if ratio >= 1 then return 1 end
    return math.max(1, math.min(MAX_SPOTS,
        math.floor(math.pi / math.asin(ratio))))
end

local function unpack_spots()
    local text = places_text()
    if type(text) ~= "string" or text == "" then return {} end
    local level = gGlobalSyncTable[LEVEL_KEY]
    local area = gGlobalSyncTable[AREA_KEY]

    local cx, cz, phase, rate = ring_now()
    local angle = 0
    if cx ~= nil and rate ~= 0 then angle = spin_angle() end

    local key = spotsMemoKey
    if spotsMemo ~= nil and key ~= nil and key.text == text and key.level == level
        and key.area == area then
        if key.turn == angle then return spotsMemo end
        local angleText = string.format("%.4f", angle)
        if key.turnText == angleText then
            key.turn = angle
            return spotsMemo
        end
    end
    key = { text = text, level = level, area = area, turn = angle,
            turnText = string.format("%.4f", angle) }

    local here = gNetworkPlayers[0]
    local inRoom = here ~= nil and here.currLevelNum == level
        and here.currAreaIndex == area

    local spots = {}
    for part in text:gmatch("[^|]+") do
        local x, y, z = part:match("^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if x ~= nil and y ~= nil and z ~= nil then
            if angle ~= 0 and cx ~= nil then
                local dx, dz = x - cx, z - cz
                local cosA, sinA = math.cos(angle), math.sin(angle)
                x = cx + dx * cosA - dz * sinA
                z = cz + dx * sinA + dz * cosA
                if inRoom then
                    local floor = OF.util.optional("find_floor_height", nil,
                        x, y + 300, z)
                    if type(floor) == "number"
                        and math.abs(floor - y) <= FLOOR_DROP then
                        y = floor
                    end
                end
            end
            table.insert(spots, { x = x, y = y, z = z, level = level, area = area })
        end
    end

    if not reads_whole(text, phase) then
        spotsMemoKey, spotsMemo = key, lastWhole or spots
        return spotsMemo
    end

    lastWhole = spots
    spotsMemoKey, spotsMemo = key, spots
    return spots
end

local radiusMemo, radiusMemoFor = SPOT_RADIUS, nil

local function spot_radius()
    local spots = unpack_spots()
    if radiusMemoFor ~= spots then
        radiusMemoFor = spots
        radiusMemo = circle_radius(spots)
    end
    return radiusMemo
end

function OF.gm_spots_radius()
    return spot_radius()
end

function OF.gm_spots_places()
    return unpack_spots()
end

function OF.gm_spots_ring()
    return ring_now()
end

local function my_spot()
    local spots = unpack_spots()

    local radius = spot_radius()
    local best, bestAt = nil, nil
    for index, spot in ipairs(spots) do
        local distance = OF.gamemodes.distance_to_place(spot)
        if distance ~= nil and distance <= radius then
            if bestAt == nil or distance < bestAt then
                best, bestAt = index, distance
            end
        end
    end
    return best
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function still_in()
    return OF.gamemodes.with_role(ROLE_IN)
end

local CLAIM_STRIDE = MAX_SPOTS + 1

local function pack_claim(spot, since)
    if spot <= 0 then return 0 end
    return spot + math.floor(since) * CLAIM_STRIDE
end

local function read_claim(value)
    if type(value) ~= "number" or value <= 0 then return 0, 0 end
    value = math.floor(value)
    return value % CLAIM_STRIDE, math.floor(value / CLAIM_STRIDE)
end

local function by_claim_order(a, b)
    if a.since ~= b.since then return a.since > b.since end
    if a.global ~= b.global then return a.global < b.global end
    return a.entry.localIndex < b.entry.localIndex
end

local claimantPool = {}

local function settle()
    local circles = #unpack_spots()
    local taken, out = {}, {}

    local order = {}
    for slot, entry in ipairs(still_in()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local spot, since = read_claim((row ~= nil and row[CLAIM_KEY]) or 0)
        local claimant = claimantPool[slot]
        if claimant == nil then claimant = {}; claimantPool[slot] = claimant end
        claimant.entry, claimant.spot, claimant.since = entry, spot, since
        claimant.global = (entry.np ~= nil and entry.np.globalIndex)
            or entry.localIndex
        order[slot] = claimant
    end
    table.sort(order, by_claim_order)

    for _, claimant in ipairs(order) do
        local claim = claimant.spot
        if claim <= 0 or claim > circles or taken[claim] ~= nil
            or not OF.util.can_play(claimant.entry.localIndex) then
            table.insert(out, claimant.entry)
        else
            taken[claim] = claimant.entry
        end
    end
    return taken, out
end

local mode = {
    key = "spots",
    resultsBy = "survival",
    name = "Musical Spots",
    blurb = "the circles turn with the music - be in one when it stops",

    how = "The music plays and the circles turn with it.\n"
        .. "When it stops, they stop - get into one in seconds.\n"
        .. "One circle fewer than players by default, up to 15.\n"
        .. "A tight floor holds fewer, and the round says so.\n"
        .. "Two in one circle: only the first one keeps it.\n"
        .. "How many go, and how long you run, are set below.",
    minPlayers = 2,

    pinsOnPlayers = false,

    maps = { "surveyed", "desert_cage", "the_plate", "bowser1", "bowser3" },

    surveyOut = { { level = LEVEL_PSS, area = 1 }, { level = LEVEL_RR, area = 1 },
        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_TTM, area = 1 } },

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { interactions = 0 } },
    surveyKeys = { "musicalSpot" },

    defaultLimit = 180,
    music = SEQ_EVENT_MERRY_GO_ROUND,

    teams = false,

    target = { name = "seconds to find a circle",
               asks = "Time to find a circle",
               help = "seconds to reach a circle once the music stops",
               default = 4,
               min = 2, max = 12, step = 1 },

    options = {
        { key = "gap", name = "Circles out a stop",
          help = "how many go every time the music stops",
          choices = {
              { key = "auto", name = "auto",
                help = "one with six or fewer left, two to eleven, then three" },
              { key = "one", name = "one",
                help = "one player out at every stop; the long round" },
              { key = "two", name = "two",
                help = "two out at every stop; a big lobby halves fast" },
              { key = "three", name = "three",
                help = "three out at every stop; a party round, and brutal" },
          } },

        { key = "walk", name = "Music length",
          help = "how long a leg runs before the music stops",
          choices = {
              { key = "usual", name = "normal",
                help = "five to eleven seconds - long enough to be elsewhere" },
              { key = "short", name = "short",
                help = "three to six seconds - short sprints" },
              { key = "long", name = "long",
                help = "ten to twenty-two seconds - a big level's worth" },
          } },
    },

}

function mode.stops_for(players, gap)
    local left, stops = math.max(tonumber(players) or 0, 1), 0
    while left > 1 and stops < 64 do
        local out = SHORT_BY[gap or "auto"]
        if out == nil then
            out = left >= 12 and 3 or (left >= 7 and 2 or 1)
        end
        left = left - out
        stops = stops + 1
    end
    return stops
end

function mode.clock_for(players, gap, walk, findSeconds)
    local row = WALKS[walk or "usual"] or WALKS.usual
    local stop = row[2] / 30 + (tonumber(findSeconds) or 4) + 2
    return math.max(180, math.floor(mode.stops_for(players, gap) * stop + 30 + 0.5))
end

function mode.setup(players, options)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
    grabFrames = math.floor((tonumber(options ~= nil and options.target) or 4) * 30)

    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.clock_for(#players,
            OF.gamemodes.option_now("gap"), OF.gamemodes.option_now("walk"),
            grabFrames / 30))
    end
    OF.util.publish(ROUND_KEY, 1)
    OF.util.publish(GRAB_KEY, 0)

    publish_places(nil)
end

local function orbit_is_floored(ground, cx, cz, reach)
    for step = 0, SPIN_PROBES - 1 do
        local angle = step * (2 * math.pi / SPIN_PROBES)
        local x = cx + math.cos(angle) * reach
        local z = cz + math.sin(angle) * reach
        local y = OF.util.optional("find_floor_height", nil,
            x, ground.y + 300, z)
        if type(y) ~= "number" or math.abs(y - ground.y) > FLOOR_DROP then
            return false
        end
    end
    return true
end

local turning = nil

local function roll_the_spin()
    spinPhase = spinPhase + 1
    if turning == nil then
        spinRate = 0
        return
    end
    local degrees = OF.util.random_int(SPIN_MIN_DEGREES, SPIN_MAX_DEGREES)
    if OF.util.random_int(0, 1) == 0 then degrees = -degrees end
    spinRate = degrees * math.pi / 180
end

local function freeze_the_spin()
    spinPhase = spinPhase + 1
    spinRate = 0
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local asked = math.max(1, #OF.gamemodes.participants()
        - short_by(#OF.gamemodes.participants()))
    local wanted = math.min(MAX_SPOTS, asked)

    local sumX, sumZ, count = 0, 0, 0
    for _, entry in ipairs(OF.gamemodes.landed(OF.gamemodes.with_role(ROLE_IN))) do
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

    local surveyed = OF.gamemodes.surveyed(here, "musicalSpot")
    if surveyed ~= nil then
        centreX, centreZ = surveyed.x, surveyed.z
    end

    local reaches = { RING_RADIUS, RING_RADIUS * 0.55, RING_RADIUS * 0.3 }
    turning = nil
    for _, reach in ipairs(reaches) do
        if orbit_is_floored(here, centreX, centreZ, reach) then
            turning = reach
            break
        end
    end
    ringX, ringZ = centreX, centreZ

    local holds = circles_that_fit(turning or RING_RADIUS)
    wanted = math.max(1, math.min(wanted, holds))

    local apart = 2 * MIN_SPOT_RADIUS
    local function clear_of(spots, x, z)
        for _, spot in ipairs(spots) do
            local dx, dz = spot.x - x, spot.z - z
            if (dx * dx + dz * dz) < apart * apart then return false end
        end
        return true
    end

    local spots = {}
    for step = 1, wanted do
        local angle = (step - 1) * (2 * math.pi / wanted)

        for _, reach in ipairs(turning ~= nil and { turning } or reaches) do
            local x = centreX + math.cos(angle) * reach
            local z = centreZ + math.sin(angle) * reach
            local y = OF.util.optional("find_floor_height", here.y, x, here.y + 300, z)
            if type(y) == "number" and math.abs(y - here.y) <= FLOOR_DROP
                and clear_of(spots, x, z) then
                table.insert(spots, { x = x, y = y, z = z })
                break
            end
        end
    end

    if #spots == 0 then
        table.insert(spots, { x = centreX, y = here.y, z = centreZ })

        turning = nil
    end

    roll_the_spin()

    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)
    local planted = publish_places(spots)

    local short = asked - planted

    mode.plantedShort = short > 0 and { planted, short + short_by() } or nil
    if short > 0 then
        OF.notify.send_all(planted == 1
            and "This floor holds @ circle - @ go out at the first stop"
            or "This floor holds @ circles - @ go out at the first stop",
            "warn", 6, tostring(planted), tostring(short + short_by()))
    end

    OF.util.publish(GRAB_KEY, 0)

    walkLeft = walk_span()
    resolved = true
end

mode.leadPin = {
    keys = { LEVEL_KEY, AREA_KEY, GRAB_KEY,
             WIRE_KEYS[1], WIRE_KEYS[2], WIRE_KEYS[3], WIRE_KEYS[4] },
    give = function() return { grab = grabFrames, phase = spinPhase } end,
    given = function(ctx)
        grabFrames = tonumber(ctx.grab) or grabFrames
        spinPhase = tonumber(ctx.phase) or spinPhase
        mode.plantedShort = nil
    end,
    facts = function()
        local short = mode.plantedShort
        return { turning = turning, rx = ringX, rz = ringZ, phase = spinPhase,
                 rate = spinRate, planted = short ~= nil and short[1] or nil,
                 out = short ~= nil and short[2] or nil }
    end,
    take = function(facts)
        turning = tonumber(facts.turning)
        ringX = tonumber(facts.rx) or ringX
        ringZ = tonumber(facts.rz) or ringZ
        spinPhase = tonumber(facts.phase) or spinPhase
        spinRate = tonumber(facts.rate) or 0
        walkLeft = walk_span()
        resolved = true
        if tonumber(facts.planted) ~= nil then
            OF.notify.send_all(tonumber(facts.planted) == 1
                and "This floor holds @ circle - @ go out at the first stop"
                or "This floor holds @ circles - @ go out at the first stop",
                "warn", 6, tostring(facts.planted), tostring(facts.out))
        end
    end,
}

function mode.scenery()
    local grab = gGlobalSyncTable[GRAB_KEY] or 0
    local grabbing = grab > 0

    if grabbing ~= wasGrabbing then
        wasGrabbing = grabbing
        if grabbing then
            OF.gamemodes.cue("hazard", nil, "spotsstop")

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("roundstate", OF.lang.t("MUSIC STOPPED"), nil, { quiet = true })
            end
        else
            OF.gamemodes.round_sound(OF.sounds.TICK)
        end

        if OF.util.asks(OF.music, "hush") then
            OF.music.hush(grabbing and OF.gamemodes.hears_round())
        end
    end

    local spots = unpack_spots()
    for index, spot in ipairs(spots) do
        OF.gamemodes.mark_flag("spot" .. index, spot)
    end
    for index = #spots + 1, MAX_SPOTS do
        OF.gamemodes.hide_token("spot" .. index)
    end
end

function mode.update()
    if am_out() then return end
    local grab = gGlobalSyncTable[GRAB_KEY] or 0
    if grab <= 0 then

        claimSpot, claimAt = 0, 0
        wasSafe = false
        OF.util.publish_row(0, CLAIM_KEY, 0)
        return
    end

    local here = my_spot() or 0
    if here ~= claimSpot then
        claimSpot, claimAt = here, grab
    end
    OF.util.publish_row(0, CLAIM_KEY, pack_claim(claimSpot, claimAt))

    OF.gamemodes.tick_down(math.ceil(grab / 30))
    local holder = here > 0 and settle()[here] or nil
    local safe = holder ~= nil and holder.localIndex == 0
    if safe and not wasSafe then OF.gamemodes.cue("good", nil, "spotsafe") end
    wasSafe = safe
end

local function decide_if_over()
    local left = still_in()
    if #left == 1 then
        OF.gamemodes.finish("@ won.", left[1].np.name, left[1].np.name)
        return true
    elseif #left == 0 then
        OF.gamemodes.finish("Nobody found a circle.")
        return true
    end
    return false
end
mode.decide_if_over = decide_if_over

function mode.host_update()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE and decide_if_over() then return end
    local published = gGlobalSyncTable[GRAB_KEY] or 0
    if mode.grabSaid ~= published then mode.hostGrab = published end
    local grab = mode.hostGrab or published

    if grab > 0 then
        mode.hostGrab = grab - 1
        mode.grabSaid = math.ceil((grab - 1) / 30) * 30
        OF.util.publish(GRAB_KEY, mode.grabSaid)
        if grab - 1 > 0 then return end

        local _, out = settle()
        for _, entry in ipairs(out) do
            OF.gamemodes.set_role(entry.localIndex, ROLE_OUT)
        end
        resolved = true

        local baked = unpack_spots()
        roll_the_spin()
        publish_places(baked)

        local left = still_in()
        if #left == 1 then
            OF.gamemodes.finish("@ won.", left[1].np.name,
                left[1].np.name)
        elseif #left == 0 then
            OF.gamemodes.finish("Nobody found a circle.")
        end
        return
    end

    if not resolved then return end

    walkLeft = walkLeft - 1
    if walkLeft > 0 then return end

    local left = still_in()
    local spots = unpack_spots()

    local take = math.max(1, math.min(short_by(#left), #left - 1))
    local wanted = math.max(0, math.min(#spots, #left - take))
    local kept = spots
    if wanted < #spots then
        kept = {}
        for index = 1, wanted do table.insert(kept, spots[index]) end
    end

    freeze_the_spin()
    publish_places(kept)

    OF.util.publish(ROUND_KEY, (gGlobalSyncTable[ROUND_KEY] or 1) + 1)
    OF.util.publish(GRAB_KEY, grabFrames)
    resolved = false
    local least, most = walk_span()
    walkLeft = least + math.random(0, most - least)

    if #left <= 1 then
        if #left == 1 then
            OF.gamemodes.finish("@ won.", left[1].np.name,
                left[1].np.name)
        else
            OF.gamemodes.finish("Nobody found a circle.")
        end
    end
end

function mode.before_mario_update(m)
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
end

function mode.on_timeout()
    local left = still_in()
    if #left == 1 then
        OF.gamemodes.finish("@ won.", left[1].np.name,
            left[1].np.name)
    elseif #left == 0 then
        OF.gamemodes.finish("Nobody was left standing.")
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish(#left == 1 and "Time - 1 player won." or "Time - @ players won.",
            { names = names }, tostring(#left))
    end
end

function mode.terms()

    local gap = OF.gamemodes.option_showing("spots", "gap") or "one"
    local short = SHORT_BY[gap]
    if short == nil then
        local left = #OF.gamemodes.participants()
        short = left >= 12 and 3 or (left >= 7 and 2 or 1)
    end
    if short > 1 then
        return OF.lang.fill("@ circles fewer than players, max @s",
            tostring(short),

            string.format("%.0f - %.0f", MAX_SPOTS, grab_seconds()))
    end
    return OF.lang.fill("one circle fewer than players, max @ - @s",
        tostring(MAX_SPOTS), string.format("%.0f", grab_seconds()))
end

function mode.cleanup()

    if OF.util.asks(OF.music, "hush") then OF.music.hush(false) end

    if OF.util.is_host() then

        for _, wireKey in ipairs(WIRE_KEYS) do
            OF.util.publish(wireKey, nil)
        end
        OF.util.publish(GRAB_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(ROUND_KEY, nil)
    end
    walkLeft = 0
    resolved = true
    pulse = 0
    wasGrabbing = false

    turning = nil
    spinRate = 0
    spotsMemo, spotsMemoKey = nil, nil
    radiusMemo, radiusMemoFor = SPOT_RADIUS, nil
    lastWhole = nil
    spinSeenAt, spinSeen = nil, nil

    claimSpot, claimAt = 0, 0
end

local OPEN = { r = 220, g = 220, b = 220 }
local SAFE = { r = 140, g = 255, b = 160 }
local CONTEST = { r = 255, g = 230, b = 120 }

local SPOT_ROOM = 1

local function spot_tally(held)
    return (held and SPOT_ROOM or 0) .. "/" .. SPOT_ROOM
end

OF.gm_spots_tally = spot_tally
OF.gm_spots_settle = settle
OF.gm_spots_unpack = unpack_spots
OF.gm_spots_room = SPOT_ROOM

local freeTarget = { id = "free", label = "Free circle", tone = "target",
    priority = 90, compass = "offscreen" }
local freeList = { freeTarget }
function mode.targets(viewer)
    local _ = viewer
    local grab = gGlobalSyncTable[GRAB_KEY] or 0
    if grab <= 0 or am_out() then return nil end
    local taken = settle()
    local best, bestD = nil, nil
    for index, spot in ipairs(unpack_spots()) do
        if taken[index] == nil then
            local d = OF.gamemodes.distance_to_place(spot)
            if d ~= nil and (bestD == nil or d < bestD) then best, bestD = spot, d end
        end
    end
    if best == nil or bestD <= spot_radius() then return nil end
    freeTarget.pos = best
    freeTarget.id = "free:" .. tostring(math.floor(best.x)) .. ":" .. tostring(math.floor(best.z))
    return freeList
end

local ringLook = {}

function mode.hud()
    pulse = pulse + 1

    local grab = gGlobalSyncTable[GRAB_KEY] or 0
    local grabbing = grab > 0
    local spots = unpack_spots()

    local radius = spot_radius()

    local taken = grabbing and settle() or {}
    local mine = grabbing and my_spot() or nil
    local ringing = OF.util.asks(OF.markers, "place_ring")
    for index, spot in ipairs(spots) do
        local away = OF.gamemodes.distance_to_place(spot)
        if away ~= nil and away <= SPOT_DRAW_RANGE then
            local colour, size, alpha = OPEN, 3, 190
            local holder = taken[index]
            if holder ~= nil and holder.localIndex == 0 then
                colour, size, alpha = SAFE, 5, 230
            elseif holder ~= nil then
                colour, size = CONTEST, 4
                alpha = 170 + math.floor(70 * (0.5 + 0.5 * math.sin(pulse * 0.12)))
            end
            if ringing then

                local look = ringLook
                look.segments = away > SPOT_NEAR_RANGE and 12 or 32
                look.size, look.alpha = size, alpha
                look.r, look.g, look.b = colour.r, colour.g, colour.b
                look.label, look.distance = spot_tally(holder ~= nil), away
                OF.markers.place_ring(spot, radius, look)
            end
        end
    end

    if am_out() then
        OF.gamemodes.out_banner()
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    if not grabbing then
        state("music", OF.lang.t("Music"), { prio = 20, tone = "mute" })
        return
    end
    local secs = math.max(0, math.ceil(grab / 30))
    if mine ~= nil then
        local holder = taken[mine]
        if holder ~= nil and holder.localIndex == 0 then
            state("safe", OF.lang.t("Safe"), { prio = 70, tone = "good", figure = secs })
        else
            state("another", OF.lang.t("Find another"), { prio = 85, tone = "warn",
                urgent = true, figure = secs })
        end
        return
    end
    state("find", OF.lang.t("Find a circle"), { prio = 85, tone = "bad", urgent = true,
        figure = secs })
end

OF.gamemodes.register(mode)
