OF = OF or {}

local AT_KEY    = "ofRingAt"
local LEVEL_KEY = "ofRingLevel"
local AREA_KEY  = "ofRingArea"
local RING_KEY  = "ofRingR"
local TARGET_KEY = "ofRingTarget"
local ROLE_IN = "in"
local ROLE_OUT = "out"
local LAST_ONE = "last one"
local RING_EMPTY = "ring empty"
local NOBODY_PUSHABLE = "nobody pushable"
local START_RADIUS = 1100
local FLOOR_RADIUS = 300
local SHRINK_EVERY = 30

local SHRINK_SCALE = 275
local SHRINK_LEAST = 4

local KNOCK_SHARE = 0.125

local OUT_WINDOWS = {
    three = 3 * 30, four = 4 * 30, six = 6 * 30, eight = 8 * 30, two = 2 * 30,
}

local function out_window()
    return OUT_WINDOWS[OF.gamemodes.option_now("window") or "three"]
        or (3 * 30)
end

local CLOCK_NAME = "sumoback"
local CLOCK_FPS = 30

local sinceShrink = 0

local seated = false

local knockedSeen = 0

local function pack_point(pos)
    if pos == nil then return "" end
    return string.format("%.0f %.0f %.0f", pos.x, pos.y, pos.z)
end

local ringText, ringX, ringY, ringZ = nil, nil, nil, nil

local function ring_xyz(text)
    if text ~= ringText then
        local x, y, z = text:match("^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
        ringX, ringY, ringZ = tonumber(x), tonumber(y), tonumber(z)
        ringText = text
    end
    return ringX, ringY, ringZ
end

local function ring_at()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local x, y, z = ring_xyz(text)
    if x == nil or y == nil or z == nil then return nil end
    return {
        x = x, y = y, z = z,
        level = gGlobalSyncTable[LEVEL_KEY],
        area = gGlobalSyncTable[AREA_KEY],
    }
end

local ringPlace = {}

local function ring_place()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local x, y, z = ring_xyz(text)
    if x == nil or y == nil or z == nil then return nil end
    ringPlace.x, ringPlace.y, ringPlace.z = x, y, z
    ringPlace.level = gGlobalSyncTable[LEVEL_KEY]
    ringPlace.area = gGlobalSyncTable[AREA_KEY]
    return ringPlace
end

local function radius()
    local value = gGlobalSyncTable[RING_KEY]
    if type(value) ~= "number" or value <= 0 then return START_RADIUS end
    return value
end

local function margin(localIndex)
    local at = ring_place()
    if at == nil then return nil end
    local distance = OF.gamemodes.distance_to_place(at, localIndex)
    if distance == nil then return nil end
    return radius() - distance
end

local function outside(localIndex)
    local at = ring_place()
    if at == nil then return false end
    local distance = OF.gamemodes.distance_to_place(at, localIndex)
    if distance == nil then return true end
    return distance > radius()
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function still_in()
    return OF.gamemodes.with_role(ROLE_IN)
end

local function pushable()
    local list = {}
    for _, entry in ipairs(still_in()) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function seconds_back(localIndex)
    local frames = OF.util.row_ticks(localIndex, CLOCK_NAME)
    if frames == nil then return nil end
    return math.ceil(frames / CLOCK_FPS)
end

local function most_urgent()
    local who, least = nil, nil
    for _, entry in ipairs(still_in()) do
        if entry.localIndex ~= 0 then
            local left = seconds_back(entry.localIndex)
            if left ~= nil and (least == nil or left < least
                or (left == least and entry.np.name < who.np.name)) then
                who, least = entry, left
            end
        end
    end
    if who == nil then return nil end
    return who, least
end

local function clock_frame()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or OF.gamemodes.role(0) ~= ROLE_IN
        or not OF.util.can_play(0) then
        OF.util.tick_row(CLOCK_NAME, nil)
        return
    end

    if not outside(0) then
        OF.util.tick_row(CLOCK_NAME, nil)
        return
    end

    if OF.util.row_ticks(0, CLOCK_NAME) ~= nil then
        if OF.util.asks(OF.gamemodes, "tick_down") then
            OF.gamemodes.tick_down(seconds_back(0))
        end
        return
    end

    OF.util.report(OF.util.tick_row(CLOCK_NAME, out_window() / CLOCK_FPS))

    OF.gamemodes.cue("hazard", nil, "ringout")
end

local function timed_out(localIndex)
    local left = OF.util.row_ticks(localIndex or 0, CLOCK_NAME)
    return left ~= nil and left <= 0
end

local outCause = nil
local function go_out(text)
    OF.util.tick_row(CLOCK_NAME, nil)
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    outCause = text
    local cur = OF.gamemodes.current()
    if cur == nil or type(cur.out_cause) ~= "function" then
        OF.notify.show(text, "bad", 6)
    end
end

local function seat_rank(localIndex)
    local at = ring_place()

    local rank = -math.huge
    if at ~= nil then
        local distance = OF.gamemodes.distance_to_place(at, localIndex)
        if distance ~= nil then rank = radius() - distance end
    end
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local mine = OF.teams.of(0)
        if mine ~= nil and mine ~= OF.teams.NONE
            and OF.teams.of(localIndex) == mine then
            rank = rank + radius() + 1
        end
    end
    return rank
end

local function best_seat()
    local best, bestRank, bestNear = nil, nil, nil

    for _, entry in ipairs(pushable()) do
        if entry.localIndex ~= 0 then
            local rank = seat_rank(entry.localIndex)

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or rank > bestRank
                or (rank == bestRank and near < bestNear) then
                best, bestRank, bestNear = entry, rank, near
            end
        end
    end
    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end

    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end

    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end

    local seat = best_seat()
    if seat == nil then

        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function watch_frame(m)
    OF.gamemodes.set_ghost(true)
    watch_toggle(m)
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    key = "sumo",
    resultsBy = "survival",
    name = "Sumo",
    blurb = "stay in the ring - it closes",

    blurbTeams = "stay in the ring - the last side with anybody inside wins",
    how = "Fists are on and the ring is drawn on the ground.\n"
        .. "Stay inside it. Knock the others out of it.\n"
        .. "It closes all round, and steps in at every knockout.\n"
        .. "Being thrown clear is survivable - get back in.\n"
        .. "Last one in the ring wins; in sides, the last side.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "the_plate", "desert_cage",
             "aquarium" },

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },

    defaultLimit = 180,
    music = SEQ_LEVEL_BOSS_KOOPA,
    teams = true,

    lensRole = ROLE_OUT,

    target = { name = "ring width",
               asks = "Ring width",
               shownIf = function() return false end,
               default = START_RADIUS,

               min = 400, max = 3200, step = 200 },

    outWord = "OUT",
    options = {

        { key = "size", name = "Ring size",
          help = "how big the ring starts",
          choices = {
              { key = "auto", name = "for the lobby",
                help = "normal for four, growing with every player after" },
              { key = "small", name = "small", help = "a scrum from the first second" },
              { key = "normal", name = "normal", help = "room to circle" },
              { key = "large", name = "large", help = "a brawl that takes a while to matter" },
              { key = "huge", name = "huge", help = "the widest ring - for a full lobby" },
          } },

        { key = "window", name = "How long you have to get back in",
          help = "how long the chance to get back after a shove lasts",

          choices = {
              { key = "three", name = "three seconds",
                help = "long enough to ride the knockback out and turn back" },
              { key = "two", name = "two seconds",
                help = "long enough to turn and run, and no longer" },
              { key = "four", name = "four seconds",
                help = "long enough to turn round and run back in" },
              { key = "six", name = "six seconds",
                help = "a fall is survivable if the way back up is short" },
              { key = "eight", name = "eight seconds",
                help = "the widest this goes; the ring is closing all the while" },
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

local startRadius = START_RADIUS

local function set_opening(units)
    startRadius = math.floor(tonumber(units) or START_RADIUS)
    OF.util.publish(TARGET_KEY, startRadius)
end

local function opening_for(units, count, widest)
    local base = math.floor(tonumber(units) or START_RADIUS)
    local share = math.sqrt(math.max(tonumber(count) or 0, 4) / 4)
    local grown = math.floor(base * math.min(share, 2) + 0.5)
    if type(widest) == "number" and grown > widest then grown = math.max(base, widest) end
    return grown
end

local function opening()
    local said = gGlobalSyncTable[TARGET_KEY]
    if type(said) ~= "number" or said <= 0 then return startRadius end
    return said
end

local SIZE_STOPS = { small = 800, normal = START_RADIUS, large = 1600, huge = 2200 }
mode.SIZE_STOPS = SIZE_STOPS
function mode.size_opening(pick, count)
    if SIZE_STOPS[pick] ~= nil then return SIZE_STOPS[pick] end
    return opening_for(START_RADIUS, count, mode.target.max)
end

function mode.size_word(width)
    width = tonumber(width) or START_RADIUS
    if width < 950 then return "small" end
    if width < 1350 then return "normal" end
    if width < 1900 then return "large" end
    return "huge"
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end

    local named = options ~= nil and (options.targetNamed
        or (OF.gamemodes.targetChoice ~= nil and OF.gamemodes.targetChoice[mode.key] ~= nil))
    if named then
        set_opening(options.target)
    else
        set_opening(mode.size_opening(OF.gamemodes.option_now("size") or "auto", #players))
    end

    OF.util.report(OF.rules.lend("interactions", "sumo",
        PLAYER_INTERACTIONS_PVP))
end

local PLATE_STEP, PLATE_MARGIN, PLATE_DROP = 100, 100, 200
local function plate_radius(at, most)
    if at == nil then return nil end
    local shortest = nil
    for k = 0, 15 do
        local a = k * math.pi / 8
        local reach = 0
        for d = PLATE_STEP, most, PLATE_STEP do
            local x, z = at.x + math.sin(a) * d, at.z + math.cos(a) * d
            local y = OF.util.optional("find_floor_height", nil, x, at.y + 300, z)
            if type(y) ~= "number" or y < at.y - PLATE_DROP then break end
            reach = d
        end
        if shortest == nil or reach < shortest then shortest = reach end
    end
    return shortest
end

local function pin_here()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    if OF.util.asks(OF.venues, "at") and OF.venues.at(here.level, here.area) ~= nil then
        local fits = plate_radius(here, startRadius + PLATE_STEP)
        if fits ~= nil and fits < startRadius then
            set_opening(math.max(PLATE_STEP * 3, fits - PLATE_MARGIN))
        end
    end
    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)
    OF.util.publish(AT_KEY, pack_point(here))
    OF.util.publish(RING_KEY, startRadius)
    sinceShrink = 0
end

function mode.pin()
    pin_here()
end

local otFrames = 0
local function ring_start()
    knockedSeen = 0
    otFrames = 0
    seated = false

    OF.util.tick_row(CLOCK_NAME, nil)
end

function mode.on_start()
    ring_start()
end

local FULL_HEALTH = 0x880

function mode.update()
    if am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    if not timed_out(0) then return end
    go_out("Out of the ring")
end

function mode.before_mario_update(m)

    clock_frame()
    if not am_out() then return end
    watch_frame(m)
end

local function floor_radius()
    local mode = OF.gamemodes.current()
    if mode ~= nil and type(mode.ringFloor) == "number" then
        return math.max(FLOOR_RADIUS, mode.ringFloor)
    end
    return FLOOR_RADIUS
end

local function overtime(seconds)
    if not OF.util.is_host() then return false end
    if #pushable() <= 1 then otFrames = 0 return false end
    local total = math.max(1, math.floor((seconds or 15) * 30))
    otFrames = otFrames + 1
    if otFrames > total then return false end
    local floorR = floor_radius()
    local now = radius()
    if now ~= nil and now > floorR then
        local left = total - otFrames + 1
        OF.util.publish(RING_KEY, math.max(floorR, now - math.ceil((now - floorR) / left)))
    end
    return true
end
local function nearest_middle(list)
    local at = ring_at()
    if at == nil then return list ~= nil and list[1] or nil end
    local best, bestD = nil, nil
    for _, entry in ipairs(list or {}) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil then
            local d = (m.pos.x - at.x) ^ 2 + (m.pos.z - at.z) ^ 2
            if bestD == nil or d < bestD then best, bestD = entry, d end
        end
    end
    return best
end

local function close_frame(toFloor)

    local FLOOR_RADIUS = floor_radius()
    sinceShrink = sinceShrink + 1
    if sinceShrink >= SHRINK_EVERY then
        sinceShrink = 0
        local now = radius()
        if now > FLOOR_RADIUS then

            local rate = math.floor(startRadius / SHRINK_SCALE)
            if type(toFloor) == "number" and toFloor > 0 then
                rate = math.ceil((startRadius - FLOOR_RADIUS) / toFloor)
            end
            if rate < SHRINK_LEAST then rate = SHRINK_LEAST end
            OF.util.publish(RING_KEY, math.max(FLOOR_RADIUS, now - rate))
        end
    end

    local knocked = #OF.gamemodes.with_role(ROLE_OUT)
    if knocked > knockedSeen then
        local now = radius()
        local closed = now
        for _ = knockedSeen + 1, knocked do
            closed = closed - (closed - FLOOR_RADIUS) * KNOCK_SHARE
        end
        knockedSeen = knocked

        closed = math.max(FLOOR_RADIUS, math.floor(closed))
        if closed < now then OF.util.publish(RING_KEY, closed) end
    end
end

local function verdict()
    local inside = pushable()
    if #inside == 1 and #OF.gamemodes.still_here() > 1 then
        return LAST_ONE, inside[1]
    end
    if #inside > 0 then return nil end

    if #still_in() > 0 then return NOBODY_PUSHABLE end
    return RING_EMPTY
end

mode.FLOOR_SHARE = 0.65
function mode.to_floor()
    local secs = OF.gamemodes.round_seconds(gGlobalSyncTable.ofGmLimit)
    if secs == nil then return nil end
    return secs * mode.FLOOR_SHARE
end

function mode.host_update()
    close_frame(mode.to_floor())

    if OF.teams.in_play() then
        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_IN
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
        end
        return
    end

    local ending, who = verdict()
    if ending == LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left in the ring to push.")
    elseif ending == RING_EMPTY then
        OF.gamemodes.finish("Everybody went over the edge.")
    end
end

function mode.on_timeout()

    local inside = pushable()
    if #inside == 1 then
        OF.gamemodes.finish("@ won.", inside[1].np.name,
            inside[1].np.name)
    elseif #inside == 0 then
        OF.gamemodes.finish("Nobody was left in the ring.")
    else

        local names = {}
        for _, entry in ipairs(inside) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish(#inside == 1 and "Time - 1 player won." or "Time - @ players won.",
            { names = names }, tostring(#inside))
    end
end

function mode.terms()
    local said = opening()

    return OF.lang.fill("the last one in a @ ring, and it closes",
        OF.lang.t(mode.size_word(said)))
end

local function hand_back_seat()

    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    OF.util.tick_row(CLOCK_NAME, nil)
end

local function clear_the_ring()

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(RING_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(TARGET_KEY, nil)
    end
    sinceShrink = 0
    knockedSeen = 0
end

local function let_go()
    hand_back_seat()
    clear_the_ring()
end

function mode.cleanup()
    hand_back_seat()

    OF.rules.give_back("interactions", "sumo")

    clear_the_ring()
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = ring_at()
    local r = radius()
    local distance = at ~= nil and OF.gamemodes.distance_to_place(at) or nil

    if at ~= nil and distance ~= nil then
        local ringR, ringG, ringB = 255, 230, 120
        if distance > r then ringR, ringG, ringB = 255, 120, 120 end
        OF.util.zone_ring(at, r, 48, 4, ringR, ringG, ringB, 220, "edge")
    end

    if am_out() then

        OF.gamemodes.out_banner()
        return
    end

    if distance == nil then
        OF.gamemodes.away_banner("You are not in the ring's area")
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    local margin = r - distance
    if margin < 0 then
        local left = seconds_back(0)
        if left == nil then left = math.ceil(out_window() / CLOCK_FPS) end
        state("outside", OF.lang.t("Out of the ring"), { prio = 85, tone = "bad", urgent = true,
            figure = math.max(1, left) })
    elseif margin < 200 then
        state("edge", OF.lang.t("On the edge"), { prio = 60, tone = "warn" })
    end
end

function mode.out_cause() return outCause end

mode.roundKeys = { "ofRingAt", "ofRingLevel", "ofRingArea", "ofRingR" }
OF.gamemodes.register(mode)

OF.ring = OF.ring or {}

do
    local ring = OF.ring

    ring.ROLE_IN = ROLE_IN
    ring.ROLE_OUT = ROLE_OUT

    ring.LAST_ONE = LAST_ONE
    ring.RING_EMPTY = RING_EMPTY
    ring.NOBODY_PUSHABLE = NOBODY_PUSHABLE

    ring.at = ring_at

    ring.radius = radius

    ring.outside = outside
    ring.margin = margin

    ring.START_RADIUS = START_RADIUS
    ring.FLOOR_RADIUS = FLOOR_RADIUS
    ring.floor_radius = floor_radius
    ring.SHRINK_EVERY = SHRINK_EVERY
    ring.SHRINK_SCALE = SHRINK_SCALE
    ring.SHRINK_LEAST = SHRINK_LEAST
    ring.KNOCK_SHARE = KNOCK_SHARE

    ring.set_opening = set_opening
    ring.opening_for = opening_for
    ring.opening = opening

    ring.pin = pin_here
    ring.plate_radius = plate_radius

    ring.PLACE_KEYS = { AT_KEY, LEVEL_KEY, AREA_KEY }
    function ring.host_half()
        OF.util.publish(RING_KEY, startRadius)
        sinceShrink = 0
    end

    ring.close_frame = close_frame

    ring.OUT_WINDOWS = OUT_WINDOWS
    ring.window_frames = out_window
    ring.window_left = seconds_back
    ring.most_urgent = most_urgent
    ring.CLOCK_NAME = CLOCK_NAME
    ring.CLOCK_FPS = CLOCK_FPS

    ring.tick_window = clock_frame

    ring.timed_out = timed_out
    ring.go_out = go_out

    function ring.cause() return outCause end

    ring.am_out = am_out
    ring.still_in = still_in
    ring.pushable = pushable

    ring.verdict = verdict

    ring.on_start = ring_start
    ring.overtime = overtime
    ring.nearest_middle = nearest_middle
    function ring.forget_overtime()
        if OF.util.is_host() then otFrames = 0 end
    end

    function ring.overtime_ran()

        if not OF.util.is_host() then return false end
        return otFrames > 0
    end
    ring.let_go = let_go

    ring.watch_frame = watch_frame
end
