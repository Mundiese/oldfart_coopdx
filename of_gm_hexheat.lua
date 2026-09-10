OF = OF or {}

local ROLE_UP = "up"
local ROLE_OUT = "out"
local AT_KEY = "ofHeatAt"
local LEVEL_KEY = "ofHeatLevel"
local AREA_KEY = "ofHeatArea"
local CALL_KEY = "ofHeatCall"
local COLOURS = {
    { key = "white",  name = "WHITE",  r = 240, g = 240, b = 240 },
    { key = "red",    name = "RED",    r = 235, g = 70,  b = 60 },
    { key = "yellow", name = "YELLOW", r = 250, g = 225, b = 70 },
    { key = "blue",   name = "BLUE",   r = 70,  g = 130, b = 245 },
    { key = "green",  name = "GREEN",  r = 70,  g = 195, b = 95 },
    { key = "purple", name = "PURPLE", r = 185, g = 95,  b = 235 },
    { key = "orange", name = "ORANGE", r = 255, g = 150, b = 45 },
}
local PLATFORMS = #COLOURS

local OFFSETS = { { dx = 0, dz = 0 } }
for step = 0, PLATFORMS - 2 do
    local angle = (step / (PLATFORMS - 1)) * 2 * math.pi
    table.insert(OFFSETS, { dx = math.cos(angle), dz = math.sin(angle) })
end

local GAP = 240

local PLATFORM_SCALE = 1.25

local REACH = 20000

local BASE_LIFT = 900

local HEADROOM = 400

local OUT_DROP = 400

local SINK_DEPTH = 600
local SINK_FRAMES = 18
local DOWN_FRAMES = 18
local RISE_FRAMES = 22

local SETTLE_FRAMES = 15

local lastPhase = nil

local START_SECONDS = 4.0
local STEP_SECONDS = 0.25

local FRAME_SECONDS = 1 / 30

local PACE_STOPS = {
    steady = { start = START_SECONDS, step = STEP_SECONDS },
    gentle = { start = 5.0, step = 0.2 },
    brisk  = { start = 3.0, step = 0.3 },
}

local PROBE_LIMIT = math.ceil(600 * PLATFORM_SCALE)

local PROBE_FANS = 16
local PROBE_STEPS = 8

local OCTAGON_OUT = 1 / math.cos(math.pi / 8)

local S16_PER_RADIAN = 65536 / (2 * math.pi)

local RING_LEAD = 8.0

local PLATE_RIM = 6.0

local function ring_on()
    return OF.gamemodes.option_is("ring", "turning")
end

local function spin_on()
    return OF.gamemodes.option_is("spin", "turning")
end

local function turned(perFrame, radius)
    if radius == nil or radius <= 0 then return 0 end
    return (OF.gamemodes.since_start() / FRAME_SECONDS) * (perFrame / radius)
end

local PROBE_PATIENCE = 30

local FOOTPRINT = 3 * PROBE_LIMIT + GAP
local FOOTPRINT_RINGS = 3
local FOOTPRINT_FANS = 8

local OUT_STEP_OUT = 1.35

local knownSpan = nil
local knownEdge = nil
local knownTop = nil

local knownFlat = nil

local myBoard = nil
local builtFor = nil
local seated = false

local stoodOn = nil

local frame = 0
local heardAt = nil
local lastSerial = nil
local out = false
local pulse = 0

local viewWas = nil

local hostNoRoom = false
local hostNoMesh = false
local hostProbe = nil
local hostProbeAt = nil
local hostProbeFor = 0
local hostSerial = 0
local hostCall = 0
local hostSeconds = nil
local hostLeft = 0

local function octagon()
    local shelf = gGlobalObjectCollisionData
    if shelf == nil then return nil end
    return shelf.lll_seg7_collision_octagonal_moving_platform
end

function OF.gm_hexheat_forget()
    knownSpan, knownEdge, knownTop, knownFlat = nil, nil, nil, nil
end

local mode = {
    key = "hexheat",
    resultsBy = "survival",
    name = "Hexagon Heat",
    blurb = "a colour is called and the rest of the board drops - be on it",

    how = "Seven coloured platforms hang in the air over the place.\n"
        .. "A colour is called and a short clock runs down.\n"
        .. "When it stops, every other platform sinks away.\n"
        .. "Fall below the board and you are out.\n"
        .. "The clock shortens every call. Last player up wins.",
    minPlayers = 2,

    pinsOnPlayers = true,

    maps = OF.gamemodes.TILE_ARENAS,

    saysOut = true,

    room = { sweep = { "cannons" } },

    defaultLimit = 360,
    teams = false,

    music = SEQ_EVENT_POWERUP,

    lensRole = ROLE_OUT,
    aims = {
        [ROLE_UP] = "Get onto the colour that was called before the clock stops.",
        [ROLE_OUT] = "You are out - watch, or press D-pad left to ride along.",
    },
    options = {
        { key = "pace", name = "How fast the calls tighten",
          help = "where the clock starts and how much each call takes off it - "
              .. "it never stops shortening, so the board always takes somebody",
          choices = {
              { key = "steady", name = "four seconds, a quarter off",
                help = "the round this mode shipped with - long enough at the "
                    .. "start to read the colour and walk, and unanswerable "
                    .. "about sixteen calls in" },
              { key = "gentle", name = "five seconds, a fifth off",
                help = "for a lobby meeting the board for the first time, or "
                    .. "one big enough that the called platform takes filling" },
              { key = "brisk", name = "three seconds, three tenths off",
                help = "for a lobby that already knows all seven colours - it "
                    .. "runs out of answerable calls inside a minute" },
          } },
        { key = "view", name = "What you see it from",
          help = "a ring reads very differently from inside it and from above "
              .. "it, and this is a round about reading",
          choices = {
              { key = "lobby", name = "your own camera",
                help = "whatever camera you already play on, left exactly as it "
                    .. "is - the board is drawn through walls either way" },
              { key = "above", name = "from above, for the round",
                help = "the lobby's own camera row, put at its steepest stop "
                    .. "for the length of the round and handed back after it - "
                    .. "the ring reads as a ring from up there" },
          } },

        { key = "ring", name = "Whether the outer row turns",
          help = "the six outer platforms orbiting the middle one, so the "
              .. "colour you were sent to is not where it was when it was "
              .. "called",
          choices = {
              { key = "still", name = "no, the board stands still",
                help = "the board this mode shipped with, and Mario Party's "
                    .. "own - seven plates that only ever move up and down" },
              { key = "turning", name = "yes, the six outer plates orbit",
                help = "eight units a frame against a walk of thirty-two, so "
                    .. "standing still is carried and a jump between two "
                    .. "plates is not - a crossing has to be led" },
          } },
        { key = "spin", name = "Whether a platform turns on the spot",
          help = "each plate rotating about its own middle, which carries "
              .. "whoever is standing on it round with it",
          choices = {
              { key = "still", name = "no, they face the way they were built",
                help = "the plates as the board has always had them, on the "
                    .. "one behaviour in the game that is nothing but a slab" },
              { key = "turning", name = "yes, every plate turns",
                help = "a rim of six units a frame - a lip that carries you "
                    .. "and a board with motion in it, rather than a change to "
                    .. "what the round is asking you to do" },
          } },
    },
}

local function ramp()
    local said = PACE_STOPS[OF.gamemodes.option_now("pace") or "steady"]
    if said == nil then return PACE_STOPS.steady end
    return said
end

local function in_the_round_room(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil then return false end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return false end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return false end
    return true
end

local function up_players()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_UP)) do
        if OF.util.can_play(entry.localIndex)
            and in_the_round_room(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

OF.gm_hexheat_up_count = function() return #up_players() end

local function am_up()
    return OF.gamemodes.role(0) == ROLE_UP
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function published_board()
    local packed = gGlobalSyncTable[AT_KEY]
    if type(packed) ~= "string" then return nil end
    local x, y, z, span, edge, top, flat = string.match(packed,
        "^(%-?%d+) (%-?%d+) (%-?%d+) (%d+) (%d+) (%-?%d+) (%d+)$")
    if x == nil then return nil end
    span, edge, flat = tonumber(span), tonumber(edge), tonumber(flat)

    if span < 40 or edge < span then return nil end

    if flat >= PROBE_FANS then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
             span = span, edge = edge, top = tonumber(top),

             flat = flat * 2 * math.pi / PROBE_FANS,
             radius = 2 * span + GAP,

             ring = ring_on() and turned(RING_LEAD, 2 * span + GAP) or 0,
             spin = spin_on() and turned(PLATE_RIM, span * OCTAGON_OUT) or 0,
             packed = packed }
end

local function board()
    if not in_the_round_room(0) then return nil end
    return published_board()
end

local function board_top(at)
    return at.y + BASE_LIFT
end

local function platform_pos(at, index)
    local spot = OFFSETS[index]
    if spot == nil then return nil end
    local turn = at.ring or 0
    if turn == 0 or index == 1 then
        return at.x + spot.dx * at.radius, at.z + spot.dz * at.radius
    end

    local cos, sin = math.cos(turn), math.sin(turn)
    return at.x + (spot.dx * cos - spot.dz * sin) * at.radius,
           at.z + (spot.dx * sin + spot.dz * cos) * at.radius
end

local function call_now()
    local packed = gGlobalSyncTable[CALL_KEY]
    if type(packed) ~= "string" then return nil end
    local serial, colour, frames = string.match(packed, "^(%d+) (%d+) (%d+)$")
    if serial == nil then return nil end
    colour = tonumber(colour)
    if colour < 1 or colour > PLATFORMS then return nil end
    return { serial = tonumber(serial), colour = colour,
             frames = tonumber(frames) }
end

local function beat(call)
    if call == nil or heardAt == nil then return "waiting", 0 end
    local since = frame - heardAt
    if since < call.frames then return "call", 0 end
    since = since - call.frames
    if since < SINK_FRAMES then return "sink", since / SINK_FRAMES end
    since = since - SINK_FRAMES
    if since < DOWN_FRAMES then return "down", 1 end
    since = since - DOWN_FRAMES
    if since < RISE_FRAMES then return "rise", 1 - since / RISE_FRAMES end
    return "waiting", 0
end

local function platform_y(at, index, call, phase, fallen)
    local top = board_top(at)
    if call == nil or index == call.colour then return top end
    if phase == "call" or phase == "waiting" then return top end
    return top - SINK_DEPTH * fallen
end

local function over_platform(at, index, x, z)
    local px, pz = platform_pos(at, index)
    if px == nil then return false end
    local dx, dz = x - px, z - pz
    local out = at.span * OCTAGON_OUT
    if dx * dx + dz * dz > out * out then return false end
    for quarter = 0, 3 do

        local angle = at.flat + (at.spin or 0) + quarter * (math.pi / 4)
        local reach = dx * math.cos(angle) + dz * math.sin(angle)
        if reach > at.span or reach < -at.span then return false end
    end
    return true
end

OF.gm_hexheat_over_platform = over_platform

function OF.gm_hexheat_turns()
    return { ring = RING_LEAD, plate = PLATE_RIM, walk = 32.0 }
end

local function platform_gone(at, index, call, phase, fallen)
    return platform_y(at, index, call, phase, fallen) <= board_top(at) - OUT_DROP
end

local function height_wanted()
    return BASE_LIFT + HEADROOM
end

local function above_step()
    local entry = OF.util.asks(OF.modifiers, "BY_KEY")
        and OF.modifiers.BY_KEY["view"] or nil
    if entry == nil or entry.levels == nil then return nil end
    local best, steepest = nil, nil
    for index, step in ipairs(entry.levels) do
        local stand = step.view

        if type(stand) == "table" and #stand >= 4 then
            local away = (stand[1] or 0) + (stand[2] or 0)
            local up = (stand[3] or 0) + (stand[4] or 0)
            if away > 0 and (steepest == nil or up / away > steepest) then
                best, steepest = index, up / away
            end
        end
    end
    return best
end

OF.gm_hexheat_view_step = above_step

local function wear_view(step)
    if not OF.util.is_host() then return false end

    if not OF.util.asks(OF.modifiers, "set_round_level") then return false end
    return OF.modifiers.set_round_level("view", step) == true
end

local function take_the_view()
    if not OF.gamemodes.option_is("view", "above") then return end
    local step = above_step()
    if step == nil then return end
    local was = OF.util.asks(OF.modifiers, "level")
        and OF.modifiers.level("view") or 0

    if not wear_view(step) then return end
    viewWas = was
end

local function give_the_view_back()
    if viewWas == nil then return end
    local was = viewWas
    viewWas = nil
    wear_view(was)
end

function mode.setup(players)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_UP)
    end

    if OF.util.asks(OF.util, "seed_random") then OF.util.seed_random() end

    if OF.util.asks(OF.rules, "lend") then
        OF.rules.lend("interactions", mode.key, PLAYER_INTERACTIONS_NONE)
    end

    take_the_view()
end

local function highest_floor_under(x, z, footY)
    local from = footY + BASE_LIFT
    local highest = footY
    local found = OF.util.optional("find_floor_height", nil, x, from, z)
    if type(found) == "number" and found > gLevelValues.floorLowerLimit
        and found > highest then
        highest = found
    end
    for ring = 1, FOOTPRINT_RINGS do
        local away = FOOTPRINT * ring / FOOTPRINT_RINGS
        for fan = 0, FOOTPRINT_FANS - 1 do
            local angle = (fan / FOOTPRINT_FANS) * 2 * math.pi
            local px = x + math.cos(angle) * away
            local pz = z + math.sin(angle) * away
            local here = OF.util.optional("find_floor_height", nil, px, from, pz)
            if type(here) == "number" and here > gLevelValues.floorLowerLimit
                and here > highest then
                highest = here
            end
        end
    end
    return highest
end

local function publish_board(x, footY, z)

    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f",
        x, footY, z, knownSpan, knownEdge, knownTop, knownFlat))
end

function mode.pin()
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return end

    if octagon() == nil then
        hostNoMesh = true
        return
    end

    local sumX, sumZ, count, lowest = 0, 0, 0, nil
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local other = gMarioStates[entry.localIndex]
        if other ~= nil and other.pos ~= nil then
            sumX = sumX + other.pos.x
            sumZ = sumZ + other.pos.z
            count = count + 1
            if lowest == nil or other.pos.y < lowest then lowest = other.pos.y end
        end
    end
    if count == 0 then
        sumX, sumZ, count, lowest = m.pos.x, m.pos.z, 1, m.pos.y
    end

    local x = math.floor(sumX / count + 0.5)
    local z = math.floor(sumZ / count + 0.5)

    local footY = OF.util.optional("find_floor_height", nil, x, lowest or m.pos.y, z)
    if type(footY) ~= "number" or footY <= gLevelValues.floorLowerLimit then
        footY = lowest or m.pos.y
    end

    footY = math.floor(highest_floor_under(x, z, math.floor(footY + 0.5)) + 0.5)

    local ceilY = OF.util.optional("find_ceil_height", nil, x, footY + 100, z)
    if type(ceilY) == "number" and ceilY - footY < height_wanted() then
        hostNoRoom = true
        return
    end

    OF.util.publish(LEVEL_KEY, np.currLevelNum)
    OF.util.publish(AREA_KEY, np.currAreaIndex)

    if knownSpan ~= nil then
        publish_board(x, footY, z)
        return
    end

    hostProbeAt = { x = x, y = footY + BASE_LIFT, z = z }
    hostProbeFor = 0
    hostProbe = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvStaticCheckeredPlatform,
        E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM,
        hostProbeAt.x, hostProbeAt.y, hostProbeAt.z, function(o)
            o.oCollisionDistance = REACH

            OF.util.optional("obj_scale", nil, o, PLATFORM_SCALE)
        end)
    if hostProbe == nil then hostNoMesh = true end
end

local function measure()
    if hostProbe == nil or hostProbeAt == nil then return true end
    hostProbeFor = hostProbeFor + 1

    local mesh = octagon()
    if mesh ~= nil and OF.util.alive(hostProbe) then
        hostProbe.collisionData = mesh
        hostProbe.oCollisionDistance = REACH
    end
    if hostProbeFor < 3 then return false end

    local from = hostProbeAt.y + 400
    local top = OF.util.optional("find_floor_height", nil,
        hostProbeAt.x, from, hostProbeAt.z)

    if type(top) ~= "number" or top < hostProbeAt.y - 200 then
        if hostProbeFor < PROBE_PATIENCE then return false end
        hostNoMesh = true
        return true
    end

    local ON_IT = 40

    local shortest, longest, flatFan = nil, nil, 0
    for fan = 0, PROBE_FANS - 1 do
        local angle = (fan / PROBE_FANS) * 2 * math.pi
        local cos, sin = math.cos(angle), math.sin(angle)
        local near, far = 0, PROBE_LIMIT
        for _ = 1, PROBE_STEPS do
            local mid = (near + far) * 0.5
            local here = OF.util.optional("find_floor_height", nil,
                hostProbeAt.x + cos * mid, from, hostProbeAt.z + sin * mid)
            if type(here) == "number" and math.abs(here - top) <= ON_IT then
                near = mid
            else
                far = mid
            end
        end

        if shortest == nil or near < shortest then
            shortest, flatFan = near, fan
        end
        if longest == nil or near > longest then longest = near end
    end

    OF.util.optional("obj_mark_for_deletion", nil, hostProbe)
    hostProbe = nil

    if shortest == nil or shortest < 40 then
        hostNoMesh = true
        return true
    end

    knownSpan = math.floor(shortest)
    knownEdge = math.floor(math.max(longest or shortest, shortest))
    knownTop = math.floor(top - hostProbeAt.y + 0.5)
    knownFlat = flatFan
    publish_board(hostProbeAt.x, hostProbeAt.y - BASE_LIFT, hostProbeAt.z)
    return true
end

function mode.on_start()

    frame = 0
    heardAt = nil
    lastSerial = nil
    out = false
    seated = false
    stoodOn = nil
    lastPhase = nil
    pulse = 0
    hostSerial = 0
    hostCall = 0
    hostSeconds = nil
    hostLeft = SETTLE_FRAMES
end

function mode.late_join(localIndex)
    return ROLE_OUT
end

function mode.terms()
    local said = PACE_STOPS[OF.gamemodes.option_showing(mode.key, "pace")
        or "steady"] or PACE_STOPS.steady

    return OF.lang.fill("the last one still up - @s a call, then @s less",
        string.format("%.0f", said.start), string.format("%g", said.step))
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return "UP"
end

local function build(at)
    myBoard = {}
    builtFor = at.packed

    local mesh = octagon()
    local function ready(o)
        o.oCollisionDistance = REACH
        if mesh ~= nil then o.collisionData = mesh end
        OF.util.optional("obj_scale", nil, o, PLATFORM_SCALE)
    end

    local carrier = spin_on() and id_bhvLllHexagonalMesh
        or id_bhvStaticCheckeredPlatform

    for index = 1, PLATFORMS do
        local x, z = platform_pos(at, index)

        myBoard[index] = OF.util.optional("spawn_non_sync_object", nil,
            carrier,
            E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM,
            x, board_top(at) - at.top, z, ready)
    end
end

local function tear_down()
    if myBoard ~= nil then
        for index, platform in pairs(myBoard) do
            if OF.util.alive(platform) then
                OF.util.optional("obj_mark_for_deletion", nil, platform)
            end
            myBoard[index] = nil
        end
    end
    myBoard = nil
    builtFor = nil
end

local function drive_board(at, call, phase, fallen)
    if myBoard == nil then return end
    local mesh = octagon()
    local spinning = spin_on()

    local yaw = math.floor((at.spin or 0) * S16_PER_RADIAN + 0.5) % 0x10000
    for index = 1, PLATFORMS do
        local platform = myBoard[index]
        if OF.util.alive(platform) then
            if mesh ~= nil then platform.collisionData = mesh end
            platform.oCollisionDistance = REACH
            platform.oPosY = platform_y(at, index, call, phase, fallen) - at.top

            local x, z = platform_pos(at, index)
            platform.oVelX = x - platform.oPosX
            platform.oVelZ = z - platform.oPosZ
            platform.oPosX = x
            platform.oPosZ = z

            if spinning then
                local was = platform.oFaceAngleYaw or 0
                local delta = yaw - was

                if delta > 0x8000 then delta = delta - 0x10000 end
                if delta < -0x8000 then delta = delta + 0x10000 end
                platform.oAngleVelYaw = delta
                platform.oFaceAngleYaw = yaw
            end
        end
    end
end

local function stand_me_up(at)
    if stoodOn == at.packed then return end

    if not am_up() then
        stoodOn = at.packed
        return
    end
    if not OF.util.asks(OF.net, "snap_to") then
        stoodOn = at.packed
        return
    end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    local angle = (np.globalIndex % MAX_PLAYERS) / MAX_PLAYERS * 2 * math.pi
    local away = at.span * 0.6
    OF.net.snap_to(at.x + math.cos(angle) * away, board_top(at) + 80,
        at.z + math.sin(angle) * away, nil)
    stoodOn = at.packed
end

local function set_me_down(at)
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    local angle = 0
    if np ~= nil then
        angle = (np.globalIndex % MAX_PLAYERS) / MAX_PLAYERS * 2 * math.pi
    end
    local away = (at.radius + at.edge) * OUT_STEP_OUT
    OF.net.snap_to(at.x + math.cos(angle) * away, at.y + 60,
        at.z + math.sin(angle) * away, nil)
end

local function go_out(at, inTheAir)
    if out or not am_up() then return end
    out = true
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    set_me_down(at)
    if inTheAir then
        OF.notify.show("The platform under you is gone. You are out.", "bad", 5)
    else
        OF.notify.show("Off the board. You are out.", "bad", 5)
    end
    OF.sounds.play(OF.sounds.DENIED)

    OF.notify.show("D-pad left rides along with somebody - hold L to look further",
        "info", 7)
end

local function best_seat()
    local best, bestNear = nil, nil
    for _, entry in ipairs(up_players()) do
        if entry.localIndex ~= 0 then

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or near < bestNear then best, bestNear = entry, near end
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

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    frame = frame + 1
    pulse = pulse + 1

    local at = board()
    if at == nil then

        if builtFor ~= nil then tear_down() end
        return
    end

    if builtFor ~= at.packed then
        tear_down()
        build(at)
    end

    local call = call_now()

    if call ~= nil and call.serial ~= lastSerial then
        lastSerial = call.serial
        heardAt = frame
    end

    local phase, fallen = beat(call)
    drive_board(at, call, phase, fallen)
end

function mode.update()
    local at = board()
    if at == nil then

        stoodOn = nil
        return
    end

    stand_me_up(at)

    if am_out() then return end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if m.pos.y < board_top(at) - OUT_DROP then
        go_out(at)
        return
    end

    local call = call_now()
    local phase = beat(call)

    local wasRising = lastPhase == "rise"
    lastPhase = phase
    if not (wasRising and phase ~= "rise") then return end
    if call == nil then return end

    if not over_platform(at, call.colour, m.pos.x, m.pos.z) then
        go_out(at, true)
    end
end

function mode.before_mario_update(m)
    if not am_out() then return end
    watch_toggle(m)
end

local function next_window()
    local said = ramp()
    if hostSeconds == nil then
        hostSeconds = said.start
    else

        hostSeconds = math.max(FRAME_SECONDS, hostSeconds - said.step)
    end
    return math.max(1, math.floor(hostSeconds * 30))
end

local function deal()
    local deck = {}
    for index = 1, PLATFORMS do
        if index ~= hostCall then table.insert(deck, index) end
    end
    hostCall = deck[math.random(#deck)]
    hostSerial = hostSerial + 1
    local window = next_window()

    OF.util.publish(CALL_KEY, string.format("%.0f %.0f %.0f",
        hostSerial, hostCall, window))

    hostLeft = window + SINK_FRAMES + DOWN_FRAMES + RISE_FRAMES + SETTLE_FRAMES
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if hostNoMesh then
        hostNoMesh = false
        OF.gamemodes.abandon("This build has no octagon and cannot make a board.")
        return
    end
    if hostNoRoom then
        hostNoRoom = false
        OF.gamemodes.abandon("There is not enough air over this floor.")
        return
    end

    if hostProbe ~= nil then
        measure()
        return
    end

    local left = up_players()
    if #left <= 1 and #OF.gamemodes.still_here() > 1 then
        if #left == 1 then

            OF.gamemodes.finish("@ was the last one on the board.",
                left[1].np.name, left[1].np.name)
        elseif #OF.gamemodes.with_role(ROLE_UP) > 0 then

            OF.gamemodes.abandon(OF.gamemodes.NO_CONTEST)
        else
            OF.gamemodes.finish("The board took everybody.")
        end
        return
    end

    if published_board() == nil then return end

    hostLeft = hostLeft - 1
    if hostLeft > 0 then return end
    deal()
end

function mode.on_timeout()
    local left = up_players()
    if #left == 1 then
        OF.gamemodes.finish("@ was the last one on the board.",
            left[1].np.name, left[1].np.name)
    elseif #left == 0 then
        OF.gamemodes.finish("The board took everybody.")
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("Time - @ still up.", { names = names },
            tostring(#left))
    end
end

function mode.cleanup()

    tear_down()

    give_the_view_back()
    if OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("interactions", mode.key)
    end

    if seated and OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
    seated = false

    if am_out() then
        OF.util.publish_row(0, "ofRole", ROLE_UP)
    end

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(CALL_KEY, nil)
    end

    if hostProbe ~= nil then
        OF.util.optional("obj_mark_for_deletion", nil, hostProbe)
        hostProbe = nil
    end
    hostProbeAt = nil
    hostProbeFor = 0
    hostSeconds = nil
    hostCall = 0
    hostSerial = 0
    hostLeft = 0

    hostNoRoom = false
    hostNoMesh = false

    heardAt = nil
    lastSerial = nil
    out = false
    stoodOn = nil
    lastPhase = nil
end

local function draw_name(at, index, x, y, z, colour, alpha)
    local screen = { x = 0, y = 0, z = 0 }
    if not OF.util.world_screen({ x = x, y = y + 190, z = z }, screen) then
        return
    end
    OF.util.world_label(screen.x, screen.y, OF.lang.t(colour.name), 0.9,
        colour.r, colour.g, colour.b, alpha)
end

function mode.hud()
    local at = board()
    if at == nil then
        OF.util.banner(OF.lang.t("The board is somewhere else"),
            1.0, 200, 200, 200, 255)
        return
    end

    local call = call_now()
    local phase, fallen = beat(call)

    for index = 1, PLATFORMS do
        local colour = COLOURS[index]
        local x, z = platform_pos(at, index)
        local y = platform_y(at, index, call, phase, fallen)
        local named = call ~= nil and index == call.colour
        local alpha, size = 235, 3
        if named then
            size = 6

            alpha = 190 + math.floor(65 * (0.5 + 0.5 * math.sin(pulse * 0.14)))
        elseif phase ~= "call" and phase ~= "waiting" then
            alpha = math.floor(90 + 145 * (1 - fallen))
        end

        OF.util.world_ring({ x = x, y = y, z = z }, at.span,
            named and 32 or 16, size, colour.r, colour.g, colour.b, alpha)
        draw_name(at, index, x, y, z, colour, alpha)
    end

    if am_out() then
        OF.util.banner(OF.lang.t("Out - watch the rest"), 1.0, 255, 140, 140, 255)

        local watching = OF.util.asks(OF.spectate, "is_active")
            and OF.spectate.is_active()
        OF.util.banner(OF.lang.t(watching and "L / R ride with somebody else"
            or "D-pad left rides along"), 0.7, 255, 150, 150, 255)
        return
    end

    if call == nil then
        OF.util.banner(OF.lang.t("Wait for the colour..."),
            1.0, 220, 220, 220, 255)
        return
    end

    local colour = COLOURS[call.colour]
    OF.util.banner(OF.lang.fill("@ - get on it", OF.lang.t(colour.name)),
        1.0, colour.r, colour.g, colour.b, 255)

    local m = gMarioStates[0]
    local safe = false
    if m ~= nil and m.pos ~= nil then
        local px, pz = platform_pos(at, call.colour)
        if px ~= nil then
            local dx, dz = m.pos.x - px, m.pos.z - pz
            safe = math.sqrt(dx * dx + dz * dz) <= at.span
        end
    end

    local left = 0
    if heardAt ~= nil and phase == "call" then
        left = math.max(0, math.ceil((call.frames - (frame - heardAt)) / 30))
    end

    if safe then
        OF.util.banner(OF.lang.fill("@ - you are on it   -   @ still up",
            tostring(left), tostring(#up_players())), 0.7, 140, 255, 150, 255)
    else
        OF.util.banner(OF.lang.fill("@ - not on it yet   -   @ still up",
            tostring(left), tostring(#up_players())), 0.7, 255, 150, 150, 255)
    end
end

OF.gamemodes.register(mode)
