OF = OF or {}

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local TWO_PI = math.pi * 2

local OUT_DROP = 400

local START_ACROSS = 1200
local WIDEST_ACROSS = 1800

local ROPE_DRAW = 30

local ROPE_BEADS = 9
local ROPE_BEADS_MOST = 40
local ROPE_SPACING = 45
local ROPE_SCALE = 3.0

local FLAME_HALF_WIDE = 10
local FLAME_HALF_TALL = 20
local FLAME_REACH_UP = FLAME_HALF_TALL * ROPE_SCALE
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100
local ROPE_BODY = FLAME_HALF_WIDE * ROPE_SCALE + MARIO_RADIUS

local ROPE_CLEAR = ROPE_DRAW + FLAME_REACH_UP

local function bead_count(reach)
    return math.max(ROPE_BEADS, math.min(ROPE_BEADS_MOST, math.ceil((reach or 0) / ROPE_SPACING)))
end

local function dress_flame(obj, index)
    if obj == nil then return end
    OF.util.optional("obj_set_billboard", nil, obj)
    OF.util.optional("obj_scale", nil, obj, ROPE_SCALE)
    obj.oAnimState = (math.floor(OF.gamemodes.since_start() * 15) + index) % 8
end

local BEAM_DRAW = 170

local ROPE_GRACE = 5.0

local FAIR_FROM = 155

local BEAM_GAP_MIN = 1.25

local BEAM_WOBBLE = 0.13

local BEAM_PHASE0 = math.pi / 2

local ROPE_LOOKBACK = 1.0 / 20.0

local ROPE_SPEEDS = {
    climbing = { base = 1.6, climb = 0.035 },
    quick    = { base = 2.0, climb = 0.060 },
    gentle   = { base = 1.4, climb = 0.015 },
}

local ropeBase = ROPE_SPEEDS.climbing.base
local ropeClimb = ROPE_SPEEDS.climbing.climb

local ropeSeenAt = 0

local PACE_STEP = 10
local paceHeard = nil

local SEAT_SHARE = 0.6

local SEAT_WINDOW = 2.0
local seated = false

local ropeObjs = {}

local beamObjs = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    for i in pairs(ropeObjs) do ropeObjs[i] = nil end
    for i in pairs(beamObjs) do beamObjs[i] = nil end
end)

local function rope_speed()
    return ROPE_SPEEDS[OF.gamemodes.option_now("rope")] or ROPE_SPEEDS.climbing
end

local function shown_rope_speed()
    return OF.gamemodes.option_showing("hotrope", "rope") or "climbing"
end

local function beam_on()
    return OF.gamemodes.option_now("beam") == "on"
end

local function shown_beam_on()
    return OF.gamemodes.option_showing("hotrope", "beam") == "on"
end

local EARLY_FOR, EARLY = 20, 2
local function rope_angle(t)
    local e = math.min(t, EARLY_FOR)
    local early = ropeClimb * EARLY * (e * e * 0.5 + EARLY_FOR * math.max(0, t - EARLY_FOR))
    return ropeBase * t + ropeClimb * t * t * 0.5 + early
end

local function rope_rate(t)
    return ropeBase + ropeClimb * t + ropeClimb * EARLY * math.min(t, EARLY_FOR)
end

local function rope_half_arc(dist)
    if dist <= ROPE_BODY then return math.pi / 2 end
    return math.asin(ROPE_BODY / dist)
end

local function rope_sweeps(fromT, toT, playerAngle, dist)
    local half = rope_half_arc(dist)
    local span = rope_angle(toT) - rope_angle(fromT) + 2 * half
    if span <= 0 then return false end

    if span >= math.pi then return true end
    local into = (playerAngle - (rope_angle(fromT) - half)) % math.pi
    return into <= span
end

local function beam_gap(t)
    local quarter = math.pi / 2
    return quarter
        + (quarter - BEAM_GAP_MIN) * math.cos(BEAM_WOBBLE * t + BEAM_PHASE0)
end

local function beam_angle(t)
    return rope_angle(t) + beam_gap(t)
end

local function beam_sweeps(fromT, toT, playerAngle, dist)
    local half = rope_half_arc(dist)
    local span = beam_angle(toT) - beam_angle(fromT) + 2 * half
    if span <= 0 then return false end
    if span >= math.pi then return true end
    local into = (playerAngle - (beam_angle(fromT) - half)) % math.pi
    return into <= span
end

local function floor_under(x, z, at)
    local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
    if type(y) ~= "number" or y < at.y - 600 then return at.y end
    return y
end

local function move_rope(at)
    if at == nil then return end
    local angle = rope_angle(OF.gamemodes.since_start())
    local reach = OF.ring.radius()
    local beads = bead_count(reach)
    local drawn = 2 * beads + 1
    for index = drawn + 1, 2 * ROPE_BEADS_MOST + 1 do
        local extra = ropeObjs[index]
        if extra ~= nil and extra.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, extra)
        end
        ropeObjs[index] = nil
    end

    for index = 1, drawn do
        local out = reach * (index - beads - 1) / beads
        local x = at.x + math.sin(angle) * out
        local z = at.z + math.cos(angle) * out
        local y = floor_under(x, z, at) + ROPE_DRAW
        local obj = ropeObjs[index]
        if obj == nil or obj.activeFlags == 0 then
            obj = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvStaticObject, E_MODEL_RED_FLAME, x, y, z, nil)
            ropeObjs[index] = obj
        end
        if obj ~= nil then
            obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
            dress_flame(obj, index)
        end
    end
end

local function clear_rope()
    for index, obj in pairs(ropeObjs) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        ropeObjs[index] = nil
    end
end

local function move_beam(at)
    if at == nil or not beam_on() then return end
    local angle = beam_angle(OF.gamemodes.since_start())
    local reach = OF.ring.radius()
    local beads = bead_count(reach)
    local drawn = 2 * beads + 1
    for index = drawn + 1, 2 * ROPE_BEADS_MOST + 1 do
        local extra = beamObjs[index]
        if extra ~= nil and extra.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, extra)
        end
        beamObjs[index] = nil
    end

    for index = 1, drawn do
        local out = reach * (index - beads - 1) / beads
        local x = at.x + math.sin(angle) * out
        local z = at.z + math.cos(angle) * out
        local y = floor_under(x, z, at) + BEAM_DRAW
        local obj = beamObjs[index]
        if obj == nil or obj.activeFlags == 0 then
            obj = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvStaticObject, E_MODEL_RED_FLAME, x, y, z, nil)
            beamObjs[index] = obj
        end
        if obj ~= nil then
            obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
            dress_flame(obj, index)
        end
    end
end

local function clear_beam()
    for index, obj in pairs(beamObjs) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        beamObjs[index] = nil
    end
end

local function flame_height(objs, angle, at, dx, dz, lift)
    local reach = OF.ring.radius()
    local beads = bead_count(reach)
    local along = dx * math.sin(angle) + dz * math.cos(angle)
    local index = math.floor(along / math.max(reach, 1) * beads + 0.5) + beads + 1
    if index < 1 then index = 1 end
    if index > 2 * beads + 1 then index = 2 * beads + 1 end
    local obj = objs[index]
    if obj ~= nil and obj.activeFlags ~= 0 then return obj.oPosY end
    local out = reach * (index - beads - 1) / beads
    return floor_under(at.x + math.sin(angle) * out, at.z + math.cos(angle) * out, at) + lift
end

local function body_meets_flame(m, y)
    local tall = MARIO_TALL
    if m.action ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0 then tall = MARIO_SHORT end
    return m.pos.y < y + FLAME_REACH_UP and m.pos.y + tall > y - FLAME_REACH_UP
end

local function burned(m, at, fromT, toT)
    if m == nil or m.pos == nil or at == nil then return false end
    if toT < ROPE_GRACE then return false end

    local dx, dz = m.pos.x - at.x, m.pos.z - at.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > OF.ring.radius() + ROPE_BODY then return false end

    if not body_meets_flame(m, flame_height(ropeObjs, rope_angle(toT), at, dx, dz,
            ROPE_DRAW)) then
        return false
    end
    return rope_sweeps(fromT, toT, math.atan(dx, dz) % TWO_PI, dist)
end

local function beam_burned(m, at, fromT, toT)
    if not beam_on() then return false end
    if m == nil or m.pos == nil or at == nil then return false end
    if toT < ROPE_GRACE then return false end

    local dx, dz = m.pos.x - at.x, m.pos.z - at.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > OF.ring.radius() + ROPE_BODY then return false end
    if not body_meets_flame(m, flame_height(beamObjs, beam_angle(toT), at, dx, dz,
            BEAM_DRAW)) then
        return false
    end
    return beam_sweeps(fromT, toT, math.atan(dx, dz) % TWO_PI, dist)
end

local function fell_off(m, at)
    if at == nil or m == nil or m.pos == nil then return false end
    return m.pos.y < at.y - OUT_DROP
end

local ROLE_OUT = "out"
local mode = {
    key = "hotrope",
    resultsBy = "survival",
    name = "Fire Skipper",
    blurb = "a rope of fire turns the floor - jump it or you are out",

    how = "A rope of fire spans the floor and turns, faster and faster.\n"
        .. "Jump it when it reaches you - miss and you are out.\n"
        .. "Everybody jumps one rope, each at their own moment.\n"
        .. "Hold the jump longer to go higher, as the rope quickens.\n"
        .. "The middle is always under it, so keep out of it.\n"
        .. "Step past the edge and you have seconds to get back.\n"
        .. "Slide off below the floor and that is out too.\n"
        .. "How fast the rope turns is set below.\n"
        .. "A head-height beam is a setting below - duck it.\n"
        .. "In the original everybody cleared it together; not here.\n"
        .. "Last one still jumping wins, or the clock pays who is left.",
    minPlayers = 2,

    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 120,
    saysOut = true,

    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_HOT,

    target = { name = "floor width",
               asks = "Floor width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 700, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,

    options = {
        { key = "size", name = "Floor size",
          help = "how big the floor starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual floor, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller floor - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger floor - more room to run" },
          } },

        { key = "rope", name = "Rope speed",

          help = "the climb decides whether a round is a minute or ten",
          choices = {
              { key = "climbing", name = "normal",
                help = "gentle at first, quicker every second" },
              { key = "quick", name = "quick",
                help = "starts fast and steepens; a full lobby, short" },
              { key = "gentle", name = "gentle",
                help = "quickens too, only slowly, so the clock decides more" },
          } },

        { key = "beam", name = "Second rope",
          help = "a beam at head height too - duck it, do not jump",
          choices = {
              { key = "off", name = "off",
                help = "one rope, at the floor" },
              { key = "on", name = "on",
                help = "a second rope at head height - duck it" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, OF.ring.ROLE_IN)
    end

    local named = options ~= nil and (options.targetNamed
        or (OF.gamemodes.targetChoice ~= nil and OF.gamemodes.targetChoice[mode.key] ~= nil))
    if named then
        OF.ring.set_opening(options.target)
    else
        OF.ring.set_opening(mode.size_opening(OF.gamemodes.option_now("size"), #players))
    end
end

mode.SIZE_SCALE = { normal = 1, snug = 0.8, roomy = 1.25 }
function mode.size_opening(pick, count)
    local base = math.floor(START_ACROSS * (mode.SIZE_SCALE[pick] or 1) + 0.5)
    return OF.ring.opening_for(base, count, WIDEST_ACROSS)
end

function mode.pin()
    OF.ring.pin()
end

function mode.on_start()
    OF.ring.on_start()
    local speed = rope_speed()
    ropeBase, ropeClimb = speed.base, speed.climb
    ropeSeenAt = 0
    paceHeard = nil
    seated = false
end

function mode.before_mario_update(m)

    if OF.util.round_screen() then
        local at = OF.ring.at()
        move_rope(at)

        move_beam(at)
    else
        clear_rope()
        clear_beam()
    end
    OF.ring.tick_window()
    if OF.ring.am_out() then OF.ring.watch_frame(m) end
end

local function hear_the_rope(m, at, fromT, toT)
    if m == nil or m.pos == nil or at == nil then return end
    local pace = math.floor(rope_rate(toT) * 60 / TWO_PI / PACE_STEP)
    if paceHeard ~= nil and pace > paceHeard then
        OF.gamemodes.cue("hazard", nil, "hrfaster")

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("roundstate", OF.lang.t("FASTER"), nil, { quiet = true })
        end
    end
    if paceHeard == nil or pace > paceHeard then paceHeard = pace end
    if toT < ROPE_GRACE then return end
    local dx, dz = m.pos.x - at.x, m.pos.z - at.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > OF.ring.radius() + ROPE_BODY then return end
    local angle = math.atan(dx, dz) % TWO_PI
    if rope_sweeps(fromT, toT, angle, dist)
        or (beam_on() and beam_sweeps(fromT, toT, angle, dist)) then
        OF.gamemodes.round_sound_throttled("hrpass", 8, SOUND_OBJ_FLAME_BLOWN,
            m.marioObj)
    end
end

local function seat_of(globalIndex, at)
    if at == nil or globalIndex == nil then return nil end
    local order = {}
    for _, entry in ipairs(OF.gamemodes.with_role(OF.ring.ROLE_IN)) do
        local np = entry.np or gNetworkPlayers[entry.localIndex]
        if np ~= nil and np.globalIndex ~= nil then
            table.insert(order, np.globalIndex)
        end
    end
    table.sort(order)
    local place = nil
    for k, g in ipairs(order) do
        if g == globalIndex then place = k end
    end
    if place == nil then return nil end
    local angle = TWO_PI * (place - 1) / #order
    local out = OF.ring.radius() * SEAT_SHARE
    return angle, at.x + math.sin(angle) * out, at.z + math.cos(angle) * out
end

local function take_my_seat(m, at)
    if seated then return end
    if OF.gamemodes.since_start() > SEAT_WINDOW then
        seated = true
        return
    end
    if m == nil or m.pos == nil then return end
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    if at.level ~= nil and np.currLevelNum ~= at.level then return end
    if at.area ~= nil and np.currAreaIndex ~= at.area then return end
    local _, x, z = seat_of(np.globalIndex, at)
    if x == nil then return end
    local yaw = atan2s ~= nil and atan2s(at.z - z, at.x - x) or 0
    OF.net.snap_to(x, floor_under(x, z, at) + 60, z, yaw)
    if m.faceAngle ~= nil then m.intendedYaw = m.faceAngle.y end
    OF.util.camera_behind_soon()
    seated = true
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local at = OF.ring.at()
    if at == nil then return end

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < 0x880 then m.health = 0x880 end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    local now = OF.gamemodes.since_start()
    local from = ropeSeenAt
    if from > now or now - from > ROPE_LOOKBACK * 40 then from = now end
    if now - from < ROPE_LOOKBACK then from = now - ROPE_LOOKBACK end
    if from < 0 then from = 0 end
    ropeSeenAt = now

    take_my_seat(m, at)

    if OF.gamemodes.in_grace() then
        if fell_off(m, at) then OF.ring.go_out("Off the edge") end
        return
    end

    if burned(m, at, from, now) then
        OF.ring.go_out("Caught by the rope")
        return
    end

    if beam_burned(m, at, from, now) then
        OF.ring.go_out("Caught by the beam")
        return
    end
    hear_the_rope(m, at, from, now)
    if fell_off(m, at) then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the floor")
    end
end

function mode.host_update()

    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the floor to burn.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("The rope took everybody.")
    end
end

mode.symmetric = true
function mode.overtime()
    return OF.ring.overtime(15)
end

function mode.on_timeout()

    local standing = OF.ring.pushable()
    if #standing == 1 then
        OF.gamemodes.finish("@ won.", standing[1].np.name,
            standing[1].np.name)
        return
    end
    if #standing == 0 then
        OF.gamemodes.finish("Nobody was left jumping.")
        return
    end

    local one = OF.ring.overtime_ran() and OF.ring.nearest_middle(standing) or nil
    if one ~= nil and one.np ~= nil then
        OF.gamemodes.finish("@ won.", one.np.name, one.np.name)
        return
    end
    local names = {}
    for _, entry in ipairs(standing) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish(#standing == 1 and "Time - 1 player won." or "Time - @ players won.",
        { names = names }, tostring(#standing))
end

function mode.cleanup()
    clear_rope()
    clear_beam()
    OF.ring.let_go()
    ropeBase = ROPE_SPEEDS.climbing.base
    ropeClimb = ROPE_SPEEDS.climbing.climb
    ropeSeenAt = 0
    seated = false
end

function mode.terms()
    return OF.lang.fill("last one jumping, a @ rope@", shown_rope_speed(),
        shown_beam_on() and " and a beam" or "")
end

function mode.seat_for(globalIndex)
    return seat_of(globalIndex, OF.ring.at())
end

function mode.seat_share()
    return SEAT_SHARE
end

function mode.rope_angle(t)
    return rope_angle(t) % TWO_PI
end

function mode.rope_sweeps(fromT, toT, playerAngle, dist)
    return rope_sweeps(fromT, toT, playerAngle, dist)
end

function mode.rope_rate(t)
    return rope_rate(t)
end

function mode.rope_speeds()
    return ROPE_SPEEDS
end

function mode.rope_clear()
    return ROPE_CLEAR
end

function mode.beam_angle(t)
    return beam_angle(t) % TWO_PI
end

function mode.beam_sweeps(fromT, toT, playerAngle, dist)
    return beam_sweeps(fromT, toT, playerAngle, dist)
end

function mode.beam_gap(t)
    return beam_gap(t)
end

function mode.beam_gap_min()
    return BEAM_GAP_MIN
end

function mode.rope_half_arc(dist)
    return rope_half_arc(dist)
end

function mode.judge_now()
    local at = OF.ring.at()
    local m = gMarioStates[0]
    if at == nil or m == nil then return nil end
    local t = OF.gamemodes.since_start()
    return burned(m, at, t, t), beam_burned(m, at, t, t)
end

mode.ROPE_BODY = ROPE_BODY
mode.FAIR_FROM = FAIR_FROM
mode.FLAME_REACH_UP = FLAME_REACH_UP
mode.BEAM_DRAW = BEAM_DRAW

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == OF.ring.ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = OF.ring.at()

    if at ~= nil then
        local over = OF.ring.margin(0)
        local red, green, blue = 230, 150, 60
        if over ~= nil and over < 0 then red, green, blue = 255, 90, 90 end
        OF.util.zone_ring(at, OF.ring.radius(), 48, 4, red, green, blue, 220, "edge")
    end

    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

    local over = OF.ring.margin(0)
    if over == nil then
        OF.gamemodes.away_banner("You are not in the floor's area")
        return
    end

    local left = OF.ring.window_left(0)
    if left ~= nil and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("back", OF.lang.t("Back in"), { prio = 85, tone = "warn",
            urgent = true, figure = math.max(1, math.ceil(left)) })
    end
end

OF.gamemodes.register(mode)
