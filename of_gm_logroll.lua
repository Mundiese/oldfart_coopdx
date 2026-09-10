OF = OF or {}

local ROLE_ON   = "on"
local ROLE_TURN = "turn"
local ROLE_OUT  = "out"
local AT_KEY    = "ofRollAt"
local LEVEL_KEY = "ofRollLevel"
local AREA_KEY  = "ofRollArea"
local AIM_KEY   = "ofRollAim"
local LOG_RADIUS = 400

local RIM_TARGET = 32.0

local S16_PER_RADIAN = 65536 / (2 * math.pi)

local ROLL_CAP = math.floor(RIM_TARGET / LOG_RADIUS * S16_PER_RADIAN)

local ROLL_RAMP_FRAMES = 32
local ROLL_STEP = ROLL_CAP / ROLL_RAMP_FRAMES

local ROLL_SENSE = -1

local AIM_STOPS = 16

local STICK_FULL = 64

local RIDER_STEP = 170
local RIDERS_WIDE = 15

local LOG_HALF_LENGTH = 1400

local BASE_LIFT = 900

local OUT_DROP = 600

local PODIUM_AWAY = 2000

local PODIUM_SCALE = 1.6

local PODIUM_RISE = 220

local STAND_LIFT = 60

local PROBE_LIMIT = 1300
local PROBE_STEPS = 12
local PROBE_LIFT = 1500
local PROBE_PATIENCE = 90

local REACH = 8000

local SETTLE_FRAMES = 45

local myLog, myPodium = nil, nil
local builtFor = nil
local frame = 0
local roll = 0
local out = false
local seated = false
local placed = false
local hostProbe, hostProbeAt = nil, nil
local hostProbeFor = 0
local hostNoMesh, hostNoRoom = false, false
local knownHalf, knownRadius, knownTop = nil, nil, nil

local turned = false

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local OPERATE = at_load("allocate_mario_action",
    ACT_GROUP_AUTOMATIC | ACT_FLAG_STATIONARY | ACT_FLAG_INVULNERABLE)

OF.gm_logroll = OF.gm_logroll or {}
OF.gm_logroll.OPERATE = OPERATE
OF.gm_logroll.ROLL_CAP = ROLL_CAP
OF.gm_logroll.ROLL_STEP = ROLL_STEP
OF.gm_logroll.LOG_RADIUS = LOG_RADIUS
OF.gm_logroll.RIM_TARGET = RIM_TARGET
OF.gm_logroll.RIDER_STEP = RIDER_STEP
OF.gm_logroll.RIDERS_WIDE = RIDERS_WIDE
OF.gm_logroll.LOG_HALF_LENGTH = LOG_HALF_LENGTH
OF.gm_logroll.PODIUM_AWAY = PODIUM_AWAY
OF.gm_logroll.OUT_DROP = OUT_DROP
OF.gm_logroll.AIM_STOPS = AIM_STOPS

function OF.gm_logroll_rim_speed()
    return ROLL_CAP * (2 * math.pi / 65536) * LOG_RADIUS
end

function OF.gm_logroll.slot_offset(globalIndex)
    local slot = (globalIndex or 0) % RIDERS_WIDE
    return (slot - (RIDERS_WIDE - 1) * 0.5) * RIDER_STEP
end

local function log_mesh()
    if gGlobalObjectCollisionData == nil then return nil end
    return gGlobalObjectCollisionData.lll_seg7_collision_pitoune
end

local function podium_mesh()
    if gGlobalObjectCollisionData == nil then return nil end
    return gGlobalObjectCollisionData.checkerboard_platform_seg8_collision_0800D710
end

local mode = {
    key = "logroll",
    resultsBy = "survival",
    name = "Log Roll",
    blurb = "fifteen walk the log, the sixteenth turns it - stay on",

    how = "Fifteen stand along one huge log over the place.\n"
        .. "The sixteenth watches from a podium and turns it.\n"
        .. "Walk against the roll. Jumping is off for the riders.\n"
        .. "Fall past the line under the log and you are out.\n"
        .. "Last one still up wins.",

    minPlayers = 2,

    pinsOnPlayers = true,

    maps = OF.gamemodes.TILE_ARENAS,

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { interactions = 0 } },

    defaultLimit = 60,

    target = { name = "seconds on the clock",
               asks = "How many seconds a round runs",
               default = 60, min = 60, max = 240, step = 30 },
    teams = false,

    music = SEQ_LEVEL_SLIDE,

    lensRole = ROLE_OUT,
    aims = {
        [ROLE_ON] = "Walk against the roll. You cannot jump - stay on your feet.",
        [ROLE_TURN] = "Push the stick up and down to turn the log. Time the reversal.",
        [ROLE_OUT] = "You are out - watch, or press D-pad left to ride along.",
    },
}

local function in_the_round_room(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil then return false end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return false end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return false end
    return true
end

local function published_log()
    local said = gGlobalSyncTable[AT_KEY]
    if type(said) ~= "string" or said == "" then return nil end
    local x, y, z, axis, round, top =
        string.match(said, "^(-?%d+) (-?%d+) (-?%d+) (%d+) (%d+) (-?%d+)$")
    if x == nil then return nil end
    return {
        packed = said,
        x = tonumber(x), y = tonumber(y), z = tonumber(z),

        axisScale = tonumber(axis) / 1000,
        roundScale = tonumber(round) / 1000,
        top = tonumber(top),
    }
end

local function board()
    if not in_the_round_room(0) then return nil end
    return published_log()
end

local function crest_y(at) return at.y + at.top end

local function podium_pos(at)
    return at.x, crest_y(at) + PODIUM_RISE, at.z + PODIUM_AWAY
end

local function my_role() return OF.gamemodes.role(0) end
local function am_rider() return my_role() == ROLE_ON end
local function am_turner() return my_role() == ROLE_TURN end
local function am_out() return my_role() == ROLE_OUT end

local function riders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ON)) do
        if OF.util.can_play(entry.localIndex)
            and in_the_round_room(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function turner()
    local found = OF.gamemodes.with_role(ROLE_TURN)
    return found[1]
end

local function aim_now()
    local at = turner()
    if at == nil then return 0 end
    local row = gPlayerSyncTable[at.localIndex]
    if row == nil then return 0 end
    local said = tonumber(row[AIM_KEY]) or 0
    if said > AIM_STOPS then said = AIM_STOPS end
    if said < -AIM_STOPS then said = -AIM_STOPS end
    return said / AIM_STOPS
end

local function highest_floor_under(x, z, footY)
    local best = footY
    for _, offset in ipairs({ -LOG_HALF_LENGTH, 0, LOG_HALF_LENGTH }) do
        for _, across in ipairs({ 0, PODIUM_AWAY }) do
            local here = OF.util.optional("find_floor_height", nil,
                x + offset, footY + 200, z + across)
            if type(here) == "number" and here > gLevelValues.floorLowerLimit
                and here > best then
                best = here
            end
        end
    end
    return best
end

local function publish_log(x, y, z)

    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f %.0f %.0f %.0f",
        x, y, z,
        math.floor(LOG_HALF_LENGTH / knownHalf * 1000 + 0.5),
        math.floor(LOG_RADIUS / knownTop * 1000 + 0.5),
        math.floor(LOG_RADIUS + 0.5)))
end

function mode.pin()
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return end

    if log_mesh() == nil then
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
    local z = math.floor(sumZ / count - PODIUM_AWAY * 0.5 + 0.5)

    local footY = OF.util.optional("find_floor_height", nil,
        x, lowest or m.pos.y, z)
    if type(footY) ~= "number" or footY <= gLevelValues.floorLowerLimit then
        footY = lowest or m.pos.y
    end
    footY = math.floor(highest_floor_under(x, z, math.floor(footY + 0.5)) + 0.5)

    local ceilY = OF.util.optional("find_ceil_height", nil, x, footY + 100, z)
    if type(ceilY) == "number"
        and ceilY - footY < BASE_LIFT + LOG_RADIUS + PODIUM_RISE + 400 then
        hostNoRoom = true
        return
    end

    OF.util.publish(LEVEL_KEY, np.currLevelNum)
    OF.util.publish(AREA_KEY, np.currAreaIndex)

    local axisY = footY + BASE_LIFT
    if knownHalf ~= nil then
        publish_log(x, axisY, z)
        return
    end

    hostProbeAt = { x = x, y = footY + PROBE_LIFT, z = z, ground = footY }
    hostProbeFor = 0
    hostProbe = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvLllHexagonalMesh, E_MODEL_LLL_ROLLING_LOG,
        hostProbeAt.x, hostProbeAt.y, hostProbeAt.z, function(o)
            o.oCollisionDistance = REACH
            o.oFaceAngleYaw = 0
            o.oFaceAnglePitch = 0
            o.oFaceAngleRoll = 0
        end)
    if hostProbe == nil then hostNoMesh = true end
end

local function measure()
    if hostProbe == nil or hostProbeAt == nil then return true end
    hostProbeFor = hostProbeFor + 1

    local mesh = log_mesh()
    if mesh ~= nil and OF.util.alive(hostProbe) then
        hostProbe.collisionData = mesh
        hostProbe.oCollisionDistance = REACH
    end
    if hostProbeFor < 3 then return false end

    local from = hostProbeAt.y + PROBE_LIMIT

    local ON_IT = hostProbeAt.ground + PROBE_LIFT * 0.5
    local function is_log(here)
        return type(here) == "number" and here > ON_IT
    end

    local top = OF.util.optional("find_floor_height", nil,
        hostProbeAt.x, from, hostProbeAt.z)
    if not is_log(top) then
        if hostProbeFor < PROBE_PATIENCE then return false end
        hostNoMesh = true
        return true
    end

    local function reach(dx, dz)
        local near, far = 0, PROBE_LIMIT
        for _ = 1, PROBE_STEPS do
            local mid = (near + far) * 0.5
            local here = OF.util.optional("find_floor_height", nil,
                hostProbeAt.x + dx * mid, from, hostProbeAt.z + dz * mid)
            if is_log(here) then near = mid else far = mid end
        end
        return near
    end

    local alongX = math.min(reach(1, 0), reach(-1, 0))
    local alongZ = math.min(reach(0, 1), reach(0, -1))

    OF.util.optional("obj_mark_for_deletion", nil, hostProbe)
    hostProbe = nil

    if alongX < 40 or alongZ < 40 then
        hostNoMesh = true
        return true
    end

    knownHalf = math.max(alongX, alongZ)
    knownRadius = math.min(alongX, alongZ)
    knownTop = top - hostProbeAt.y

    if knownTop <= 40 or math.abs(knownTop - knownRadius) > knownRadius * 0.35 then
        hostNoMesh = true
        return true
    end

    publish_log(hostProbeAt.x, hostProbeAt.ground + BASE_LIFT, hostProbeAt.z)
    return true
end

function OF.gm_logroll_forget()
    knownHalf, knownRadius, knownTop = nil, nil, nil
end

function mode.setup(players, options)

    if options == nil or tonumber(options.limit) == nil then
        local want = OF.util.clamp(math.floor(tonumber(options ~= nil
            and options.target) or OF.gamemodes.target_for(mode.key)
            or mode.target.default), mode.target.min, mode.target.max)
        OF.util.publish("ofGmLimit", want)
    end

    local it = OF.gamemodes.deal_it(players, 1, false)

    local pick = nil
    for _, entry in ipairs(players) do
        if it[entry.localIndex] then
            OF.gamemodes.set_role(entry.localIndex, ROLE_TURN)
            pick = entry
        else
            OF.gamemodes.set_role(entry.localIndex, ROLE_ON)
        end
    end

    OF.util.report(pick ~= nil, "Nobody could be put at the switch.")
end

function mode.late_join(localIndex)
    return ROLE_OUT
end

function mode.on_start()

    frame = 0
    roll = 0
    out = false
    seated = false
    placed = false

    turned = false
end

function mode.terms()
    return OF.lang.t("the last one still up when the clock stops")
end

function mode.standing(localIndex)
    local role = OF.gamemodes.role(localIndex)
    if role == ROLE_OUT then return "OUT" end
    if role == ROLE_TURN then return "TURN" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return "ON"
end

local function build(at)
    builtFor = at.packed

    local mesh = log_mesh()
    myLog = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvLllHexagonalMesh, E_MODEL_LLL_ROLLING_LOG,
        at.x, at.y, at.z, function(o)
            o.oCollisionDistance = REACH
            if mesh ~= nil then o.collisionData = mesh end

            o.oFaceAngleYaw = 0
            o.oFaceAngleRoll = 0
            o.oFaceAnglePitch = 0

            OF.util.optional("obj_scale_xyz", nil, o,
                at.axisScale, at.roundScale, at.roundScale)
        end)

    local px, py, pz = podium_pos(at)
    local pmesh = podium_mesh()
    myPodium = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvLllHexagonalMesh, E_MODEL_CHECKERBOARD_PLATFORM,
        px, py, pz, function(o)
            o.oCollisionDistance = REACH
            if pmesh ~= nil then o.collisionData = pmesh end
            o.oFaceAngleYaw = 0
            o.oFaceAnglePitch = 0
            o.oFaceAngleRoll = 0
            OF.util.optional("obj_scale", nil, o, PODIUM_SCALE)
        end)
end

local function tear_down()
    for _, held in ipairs({ myLog, myPodium }) do
        if OF.util.alive(held) then
            OF.util.optional("obj_mark_for_deletion", nil, held)
        end
    end
    myLog, myPodium = nil, nil
    builtFor = nil
end

local function drive(at)
    local mesh = log_mesh()
    if OF.util.alive(myPodium) then
        local pmesh = podium_mesh()
        if pmesh ~= nil then myPodium.collisionData = pmesh end
        myPodium.oCollisionDistance = REACH
    end
    if not OF.util.alive(myLog) then return end
    if mesh ~= nil then myLog.collisionData = mesh end
    myLog.oCollisionDistance = REACH

    local wanted = 0
    if frame >= SETTLE_FRAMES then
        wanted = aim_now() * ROLL_CAP * ROLL_SENSE
    end
    if roll < wanted then
        roll = math.min(wanted, roll + ROLL_STEP)
    elseif roll > wanted then
        roll = math.max(wanted, roll - ROLL_STEP)
    end

    local delta = math.floor(roll + 0.5)
    myLog.oAngleVelPitch = delta

    local face = myLog.oFaceAnglePitch + delta
    if face > 0x10000 then face = face - 0x10000 end
    if face < -0x10000 then face = face + 0x10000 end
    myLog.oFaceAnglePitch = face
end

function mode.scenery()
    if hostNoMesh or hostNoRoom then return end

    local at = board()
    if at == nil then

        if builtFor ~= nil then tear_down() end
        return
    end

    frame = frame + 1

    if builtFor ~= at.packed then
        tear_down()
        build(at)
    end

    drive(at)
end

local function stand_me_up(at)
    if placed then return end
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    if am_turner() then
        local px, py, pz = podium_pos(at)

        OF.net.snap_to(px, py + STAND_LIFT, pz, -0x8000)
        placed = true
        return
    end
    if not am_rider() then return end

    OF.net.snap_to(at.x + OF.gm_logroll.slot_offset(np.globalIndex),
        crest_y(at) + STAND_LIFT, at.z, 0)
    placed = true
end

local function set_me_down(at)
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    local offset = OF.gm_logroll.slot_offset(np ~= nil and np.globalIndex or 0)
    local groundY = OF.util.optional("find_floor_height", nil,
        at.x + offset, at.y - BASE_LIFT + 200, at.z - PODIUM_AWAY * 0.5)
    if type(groundY) ~= "number" or groundY <= gLevelValues.floorLowerLimit then
        groundY = at.y - BASE_LIFT
    end
    OF.net.snap_to(at.x + offset, groundY + 40, at.z - PODIUM_AWAY * 0.5, 0)
end

local function go_out(at)
    if out or not am_rider() then return end
    out = true
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    set_me_down(at)
    OF.notify.show("Off the log. You are out.", "bad", 5)
    OF.sounds.play(OF.sounds.DENIED)
    OF.notify.show("D-pad left rides along with somebody - hold L to look further",
        "info", 7)
end

local function best_seat()
    local best, bestNear = nil, nil
    for _, entry in ipairs(riders()) do
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
        OF.util.report(false, "There is nobody left on the log.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function block_the_jump(m)
    if not am_rider() then return end
    if OF.util.menu_has_screen() then return end
    local c = m.controller
    if c == nil then return end

    c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~A_BUTTON
    c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~A_BUTTON
end

local function act_operate(m)
    if m == nil then return false end

    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.y, m.vel.z = 0, 0, 0 end
    m.faceAngle[0] = 0
    m.faceAngle[1] = -0x8000
    if m.marioObj ~= nil then m.marioObj.oMoveAngleYaw = -0x8000 end

    local at = board()
    if at ~= nil and m.pos ~= nil then
        local px, py, pz = podium_pos(at)
        m.pos.x, m.pos.y, m.pos.z = px, py + STAND_LIFT, pz
    end

    local said = 0
    if m.controller ~= nil and not OF.util.menu_has_screen() then
        said = m.controller.stickY or 0
    end
    local stops = math.floor(said / STICK_FULL * AIM_STOPS + 0.5)
    if stops > AIM_STOPS then stops = AIM_STOPS end
    if stops < -AIM_STOPS then stops = -AIM_STOPS end

    if am_turner() then
        OF.util.publish_row(0, AIM_KEY, stops)

        if stops ~= 0 then turned = true end
    end

    if m.marioObj ~= nil and m.marioObj.header ~= nil then
        local gfx = m.marioObj.header.gfx
        if gfx ~= nil and gfx.pos ~= nil and m.pos ~= nil then
            gfx.pos.x, gfx.pos.y, gfx.pos.z = m.pos.x, m.pos.y, m.pos.z
        end
    end
    OF.util.optional("set_character_animation", nil, m, CHAR_ANIM_IDLE_HEAD_CENTER)
    return false
end

if OPERATE ~= nil then
    at_load("hook_mario_action", OPERATE, { every_frame = act_operate })
end

local function hold_the_switch(m)
    if OPERATE == nil or not am_turner() then return end
    if m.action == OPERATE then return end
    if board() == nil then return end
    OF.util.optional("set_mario_action", nil, m, OPERATE, 0)
end

function mode.update()
    local at = board()
    if at == nil then

        placed = false
        return
    end

    stand_me_up(at)

    if am_out() or am_turner() then return end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if m.pos.y < crest_y(at) - OUT_DROP then go_out(at) end
end

function mode.before_mario_update(m)
    if am_out() then
        watch_toggle(m)
        return
    end
    hold_the_switch(m)
    block_the_jump(m)
end

function mode.host_update()
    if hostNoMesh then
        OF.gamemodes.abandon("This build has no rolling log to turn.")
        return
    end
    if hostNoRoom then
        OF.gamemodes.abandon("There is not enough air over this floor.")
        return
    end
    if hostProbe ~= nil then
        measure()
        return
    end

    if OF.gamemodes.role_is_gone(ROLE_TURN) then
        OF.gamemodes.abandon("Nobody is turning the log any more.")
        return
    end

    local left = riders()
    if #left == 0 and #OF.gamemodes.still_here() > 1 then
        local who = turner()
        if who ~= nil and who.np ~= nil then
            OF.gamemodes.finish("@ turned everybody off the log.",
                who.np.name, who.np.name)
        else
            OF.gamemodes.finish("The log took everybody.")
        end
    end
end

function mode.on_timeout()
    local left = riders()
    if #left == 1 then
        OF.gamemodes.finish("@ was the last one on the log.",
            left[1].np.name, left[1].np.name)
    elseif #left == 0 then
        local who = turner()
        if who ~= nil and who.np ~= nil then
            OF.gamemodes.finish("@ turned everybody off the log.",
                who.np.name, who.np.name)
        else
            OF.gamemodes.finish("The log took everybody.")
        end
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("Time - @ still on the log.", { names = names },
            tostring(#left))
    end
end

local function turner_teach()
    if not am_turner() then return nil end
    if turned then return nil end
    return {
        { text = OF.lang.t("Stick up rolls the log away from you, down rolls it back") },
        { text = OF.lang.t("Left and right do nothing") },
    }
end

function OF.gm_logroll_teach()
    return turner_teach()
end

function mode.hud()
    local at = board()
    local left = #riders()

    if am_out() then
        OF.util.banner(OF.lang.t("Out - watch the rest"),
            1.0, 255, 140, 140, 255)
        if at ~= nil then
            OF.util.banner(OF.lang.fill("@ still on the log", tostring(left)),
                0.9, 200, 200, 200, 255)
        end
        return
    end

    if at == nil then
        OF.util.banner(OF.lang.t("The log is somewhere else"),
            1.0, 200, 200, 200, 255)
        return
    end

    if am_turner() then
        OF.util.banner(OF.lang.fill("Turning it - @ still on the log",
            tostring(left)), 0.8, 255, 215, 120, 255,
            { under = turner_teach() })
        return
    end

    OF.util.banner(OF.lang.fill("@ still on the log", tostring(left)),
        0.8, 140, 255, 150, 255)
end

function mode.cleanup()

    tear_down()

    if OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("interactions", mode.key)
    end

    local m = gMarioStates[0]
    if m ~= nil and OPERATE ~= nil and m.action == OPERATE then
        OF.util.optional("set_mario_action", nil, m, ACT_FREEFALL, 0)
    end
    OF.util.publish_row(0, AIM_KEY, 0)

    if seated and OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
    seated = false

    if am_out() then
        OF.util.publish_row(0, "ofRole", ROLE_ON)
    end

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
    end

    if hostProbe ~= nil then
        OF.util.optional("obj_mark_for_deletion", nil, hostProbe)
        hostProbe = nil
    end
    hostProbeAt = nil
    hostProbeFor = 0
    hostNoMesh = false
    hostNoRoom = false
    frame = 0
    roll = 0
    out = false
    placed = false
    turned = false
end

OF.gamemodes.register(mode)
