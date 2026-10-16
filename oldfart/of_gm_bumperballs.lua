OF = OF or {}

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local OUT_DROP = 400

local START_ACROSS = 1200

local ISLAND_FLOOR = 650

local WIDEST_ACROSS = 2800

local landed = false

local BALL_R = 100
local BALL_CONTACT = 2 * BALL_R

local BALL_BODY = 160
local ROLL_ACCEL = 1.6
local ROLL_FRICTION = 0.975
local ROLL_TOP = 44

local AIR_STEER = 0.33
local AIR_FRICTION = 0.995

local SLOPE_PULL = 2.5

local WALL_KEEP = 0.9

local LAND_BOUNCE_FROM = 16
local LAND_BOUNCE_KEEP = 0.5
local GRAVITY = 4
local TERMINAL = 75

local BUMP_GAIN = 1.4
local BUMP_CUDDLE = 3
local BUMP_MAX = 80
local BUMP_PART = 20

local BOOST_SLOW = 8
local BOOST_CHARGE = 30

local HOST_BALL_GEO, HOST_BALL_R = "of_ball_geo", 100

pcall(function() OF.ball.resolve_at_load({ HOST_BALL_GEO }) end)
local STAND_IN_MODEL, STAND_IN_R = E_MODEL_HMC_ROLLING_ROCK, 180

local function ball_model()
    if OF.util.optional("mod_file_exists", false, "actors/" .. HOST_BALL_GEO .. ".bin") then
        local id = OF.util.optional("smlua_model_util_get_id", nil, HOST_BALL_GEO)
        if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
            return id, HOST_BALL_R
        end
    end
    return STAND_IN_MODEL, STAND_IN_R
end
local PITCH_PER_UNIT = 0x8000 / (math.pi * BALL_R)

local WALK_SPEED_AT_ONE = 4

local ballX, ballZ = 0, 0
local boostCharge = 0

local SHORE, SHORE_CLEAR = 200, 60
local onShore = false

local seenX, seenZ = {}, {}
local seenVX, seenVZ = {}, {}

local bumpedBy = {}
local launchTop = 0

local rodeThisFrame = false

local rolled = {}

local function forget_ball()
    ballX, ballZ = 0, 0
    boostCharge = 0
    onShore = false
    seenX, seenZ, seenVX, seenVZ = {}, {}, {}, {}
    rolled = {}
    bumpedBy, launchTop = {}, 0
end

local function heading(yaw)
    local turn = (tonumber(yaw) or 0) * 2 * math.pi / 0x10000
    return math.sin(turn), math.cos(turn)
end

local function yaw_of(x, z)
    return math.floor(math.atan(x, z) * 0x8000 / math.pi)
end

local function camera_yaw(m)
    local area = m.area
    local cam = area ~= nil and area.camera or nil
    return cam ~= nil and cam.yaw or 0
end

local TAKEN = { A_BUTTON, B_BUTTON, Z_TRIG }
local function without(mask, flag)
    mask = mask or 0
    if OF.util.has_flag(mask, flag) then return mask - flag end
    return mask
end

local function take_the_pad(m)
    local c = m.controller
    if c == nil then return 0, 0, false end
    local sx, sy = tonumber(c.stickX) or 0, tonumber(c.stickY) or 0
    local mag = math.min(64, math.sqrt(sx * sx + sy * sy)) / 64
    local dirX, dirZ = 0, 0
    if mag > 0.05 then
        local yaw = math.floor(math.atan(sx, -sy) * 0x8000 / math.pi)
            + camera_yaw(m)
        dirX, dirZ = heading(yaw)
    else
        mag = 0
    end
    local holdingB = OF.util.has_flag(c.buttonDown or 0, B_BUTTON)
    c.stickX, c.stickY, c.stickMag = 0, 0, 0
    for _, flag in ipairs(TAKEN) do
        c.buttonDown = without(c.buttonDown, flag)
        c.buttonPressed = without(c.buttonPressed, flag)
    end
    return dirX * mag, dirZ * mag, holdingB
end

local function watch_riders()
    for _, entry in ipairs(OF.ring.still_in()) do
        local index = entry.localIndex
        local them = index ~= 0 and gMarioStates[index] or nil
        if them ~= nil and them.pos ~= nil then
            local x, z = them.pos.x, them.pos.z
            if seenX[index] ~= nil then
                local vx, vz = x - seenX[index], z - seenZ[index]
                seenVX[index] = (seenVX[index] or 0) * 0.5 + vx * 0.5
                seenVZ[index] = (seenVZ[index] or 0) * 0.5 + vz * 0.5
            end
            seenX[index], seenZ[index] = x, z
        end
    end
end

local function knock_for(theirs, mine)
    mine = mine or 0
    if theirs > BUMP_MAX then theirs = BUMP_MAX end
    local closing = theirs - mine
    local out = mine
    if closing > 0 then out = mine + BUMP_GAIN * closing end
    if out < BUMP_CUDDLE then out = BUMP_CUDDLE end
    if out > BUMP_MAX then out = BUMP_MAX end
    return out, closing
end

local function bounce(m)
    for _, entry in ipairs(OF.ring.still_in()) do
        local index = entry.localIndex
        local them = index ~= 0 and gMarioStates[index] or nil
        if them ~= nil and them.pos ~= nil and not OF.ring.outside(index) then
            local dx, dz = m.pos.x - them.pos.x, m.pos.z - them.pos.z
            local apart = math.sqrt(dx * dx + dz * dz)
            if apart > 0.01 and apart < BALL_CONTACT
                and math.abs(m.pos.y - them.pos.y) <= BALL_BODY then
                local nx, nz = dx / apart, dz / apart
                local mine = ballX * nx + ballZ * nz
                local theirs = (seenVX[index] or 0) * nx + (seenVZ[index] or 0) * nz
                local sent = them.vel ~= nil
                    and ((them.vel.x or 0) * nx + (them.vel.z or 0) * nz) or 0
                if sent > theirs then theirs = sent end
                local kick, closing = knock_for(theirs, mine)
                if bumpedBy[index] then

                    kick = math.max(mine, BUMP_CUDDLE)
                elseif closing > 0 then
                    bumpedBy[index] = true
                end
                if mine < kick then
                    ballX = ballX + nx * (kick - mine)
                    ballZ = ballZ + nz * (kick - mine)
                    if kick > launchTop then launchTop = kick end

                    if closing > BUMP_CUDDLE then
                        OF.gamemodes.round_sound_throttled("bbbump", 10,
                            SOUND_ACTION_BOUNCE_OFF_OBJECT, m.marioObj)
                    end
                end
            elseif bumpedBy[index] and apart >= BALL_CONTACT + BUMP_PART then
                bumpedBy[index] = nil
            end
        end
    end
end

local function boost_on()
    return OF.gamemodes.option_now("boost") == "on"
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end
local BALL_GROUND = at_load("allocate_mario_action", ACT_GROUP_MOVING | ACT_FLAG_MOVING)
local BALL_AIR = at_load("allocate_mario_action", ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)

local function on_ball(m)
    return m ~= nil and BALL_GROUND ~= nil
        and (m.action == BALL_GROUND or m.action == BALL_AIR)
end

local function roll_frame(m)
    if m == nil or m.pos == nil then return end
    watch_riders()
    rodeThisFrame = true
    local ax, az, holdingB = take_the_pad(m)
    local air = BALL_AIR ~= nil and m.action == BALL_AIR
    local steer = air and AIR_STEER or 1
    local keep = air and AIR_FRICTION or ROLL_FRICTION
    ballX = (ballX + ax * ROLL_ACCEL * steer) * keep
    ballZ = (ballZ + az * ROLL_ACCEL * steer) * keep
    bounce(m)
    local speed = math.sqrt(ballX * ballX + ballZ * ballZ)

    if boost_on() and not air then
        if holdingB and speed < BOOST_SLOW then
            boostCharge = math.min(BOOST_CHARGE, boostCharge + 1)
        elseif not holdingB and boostCharge > 0 then
            local dx, dz = ax, az
            if dx * dx + dz * dz < 0.01 then dx, dz = heading(m.faceAngle.y) end
            local len = math.sqrt(dx * dx + dz * dz)
            local launch = ROLL_TOP * boostCharge / BOOST_CHARGE
            ballX, ballZ = dx / len * launch, dz / len * launch
            boostCharge = 0

            OF.gamemodes.round_sound_throttled("bbdash", 10, SOUND_ACTION_SPIN,
                m.marioObj)
            speed = launch
        end
    else
        boostCharge = 0
    end
    speed = math.sqrt(ballX * ballX + ballZ * ballZ)

    local top = ROLL_TOP
    if launchTop > top then
        top = launchTop
        launchTop = launchTop * keep
    else
        launchTop = 0
    end
    if speed > top then
        ballX, ballZ = ballX * top / speed, ballZ * top / speed
        speed = top
    end
    if math.abs(ballX) < 0.02 then ballX = 0 end
    if math.abs(ballZ) < 0.02 then ballZ = 0 end

    if speed > 2 and m.faceAngle ~= nil then
        m.faceAngle.y = yaw_of(ballX, ballZ)
    end
    if BALL_GROUND ~= nil and not on_ball(m) then
        local group = (m.action or 0) & (ACT_GROUP_MASK or 0x1C0)
        local held = OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING)
            or group == (ACT_GROUP_CUTSCENE or 0x1C0)
            or group == (ACT_GROUP_SUBMERGED or 0x0C0)
            or (m.health or 0x880) < 0x100
        if not held then
            local up = m.pos.y > (m.floorHeight or m.pos.y) + 10
            set_mario_action(m, up and BALL_AIR or BALL_GROUND, 0)
        end
    end
end

local function ball_speed_of(m)
    if m.playerIndex == 0 then return ballX, ballZ end
    local vx, vz = m.vel ~= nil and m.vel.x or 0, m.vel ~= nil and m.vel.z or 0
    return vx, vz
end

local function rider_animation(m, speed)
    if speed < 1 then
        set_character_animation(m, CHAR_ANIM_IDLE_HEAD_CENTER)
        return
    end
    local accel = math.floor(math.max(speed, WALK_SPEED_AT_ONE) / WALK_SPEED_AT_ONE * 0x10000)
    set_character_anim_with_accel(m, CHAR_ANIM_WALKING, accel)
end

local function off_the_wall(m)
    local n = m.wallNormal
    if n == nil or m.playerIndex ~= 0 then return end
    local nx, nz = n.x or 0, n.z or 0
    local len = math.sqrt(nx * nx + nz * nz)
    if len < 0.01 then return end
    nx, nz = nx / len, nz / len
    local into = ballX * nx + ballZ * nz
    if into >= 0 then return end
    ballX = (ballX - 2 * into * nx) * WALL_KEEP
    ballZ = (ballZ - 2 * into * nz) * WALL_KEEP
end

local function act_ball_ground(m)
    if m == nil then return false end
    local vx, vz = ball_speed_of(m)
    if m.playerIndex == 0 and m.floor ~= nil and m.floor.normal ~= nil then
        ballX = ballX + (m.floor.normal.x or 0) * SLOPE_PULL
        ballZ = ballZ + (m.floor.normal.z or 0) * SLOPE_PULL
        vx, vz = ballX, ballZ
    end
    local speed = math.sqrt(vx * vx + vz * vz)
    m.vel.x, m.vel.y, m.vel.z = vx, 0, vz
    m.forwardVel = speed
    m.slideVelX, m.slideVelZ = vx, vz
    rider_animation(m, speed)
    local result = perform_ground_step(m)
    if result == GROUND_STEP_LEFT_GROUND then

        m.vel.y = 0
        set_mario_action(m, BALL_AIR, 0)
    elseif result == GROUND_STEP_HIT_WALL then
        off_the_wall(m)
    end
    return false
end

local function act_ball_air(m)
    if m == nil then return false end
    local vx, vz = ball_speed_of(m)
    local speed = math.sqrt(vx * vx + vz * vz)
    m.vel.x, m.vel.z = vx, vz
    m.vel.y = math.max((m.vel.y or 0) - GRAVITY, -TERMINAL)
    m.forwardVel = speed
    rider_animation(m, speed)
    local falling = m.vel.y
    local result = perform_air_step(m, 0)
    if result == AIR_STEP_LANDED then
        if falling < -LAND_BOUNCE_FROM then
            m.vel.y = -falling * LAND_BOUNCE_KEEP
        else
            m.vel.y = 0
            set_mario_action(m, BALL_GROUND, 0)
        end
    elseif result == AIR_STEP_HIT_WALL then
        off_the_wall(m)
    end
    return false
end

if BALL_GROUND ~= nil and BALL_AIR ~= nil then
    at_load("hook_mario_action", BALL_GROUND, { every_frame = act_ball_ground })
    at_load("hook_mario_action", BALL_AIR, { every_frame = act_ball_air })
end

local function off_ball(m)
    if not on_ball(m) then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) or m.action == BALL_AIR then
        set_mario_action(m, ACT_FREEFALL, 0)
    else
        set_mario_action(m, ACT_IDLE, 0)
    end
    return true
end

local function ball_velocity()
    return ballX, ballZ
end

local ballsShown = {}

local RIDE_CAP = 300
local RIDE_SEATS = MAX_PLAYERS or 16
local rideRec = {}
for k = 1, RIDE_CAP * RIDE_SEATS do rideRec[k] = 0 end
local function ride_slot(seat, index)
    return seat * RIDE_CAP + (index % RIDE_CAP) + 1
end
local function note_riders()
    if not OF.util.asks(OF.replay, "recording") or not OF.replay.recording() then return end
    local index = OF.replay.written()
    for s = 0, RIDE_SEATS - 1 do rideRec[ride_slot(s, index)] = 0 end
    for _, entry in ipairs(OF.ring.still_in()) do
        if entry.localIndex < RIDE_SEATS then rideRec[ride_slot(entry.localIndex, index)] = 1 end
    end
end
local function replay_balls(live, model, meshR)
    if not OF.util.asks(OF.replay, "playing") or OF.replay.playing() ~= "end" then return false end
    local at = OF.replay.shown()
    if at == nil then return false end
    for s = 0, RIDE_SEATS - 1 do
        local x, y, z = OF.replay.at(s, at)
        if x ~= nil and rideRec[ride_slot(s, math.floor(at))] == 1 then
            local name = "bumperball" .. tostring(s)
            local token = OF.gamemodes.show_token(name, model,
                { x = x, y = y - BALL_CONTACT + BALL_R, z = z })
            if token ~= nil then
                local px, _, pz = OF.replay.at(s, math.max(0, at - 1))
                local moved = px ~= nil and math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) or 0
                rolled[s] = ((rolled[s] or 0) + moved * PITCH_PER_UNIT) % 0x10000
                token.oFaceAnglePitch = math.floor(rolled[s])
                if moved > 0.5 then token.oFaceAngleYaw = yaw_of(x - px, z - pz) end
                OF.util.optional("obj_scale", nil, token, BALL_R / meshR)
            end
            live[name] = token ~= nil
        end
    end
    return true
end

local function draw_balls()
    local live = {}
    if not rodeThisFrame and OF.gamemodes.is_running() then watch_riders() end
    rodeThisFrame = false
    note_riders()
    if OF.gamemodes.is_running() then
        local model, meshR = ball_model()
        for _, entry in ipairs(OF.ring.still_in()) do
            local index = entry.localIndex
            local m = gMarioStates[index]
            if m ~= nil and m.pos ~= nil then
                local name = "bumperball" .. tostring(index)
                local token = OF.gamemodes.show_token(name, model,
                    { x = m.pos.x, y = m.pos.y + BALL_R, z = m.pos.z })
                if token ~= nil then
                    local vx, vz = ball_speed_of(m)
                    if index ~= 0 and vx * vx + vz * vz < 0.01 then
                        vx, vz = seenVX[index] or vx, seenVZ[index] or vz
                    end
                    local speed = math.sqrt(vx * vx + vz * vz)
                    rolled[index] = ((rolled[index] or 0) + speed * PITCH_PER_UNIT) % 0x10000
                    token.oFaceAnglePitch = math.floor(rolled[index])
                    if speed > 0.5 then token.oFaceAngleYaw = yaw_of(vx, vz) end
                    OF.util.optional("obj_scale", nil, token, BALL_R / meshR)
                end
                live[name] = token ~= nil
            end
        end
    else
        replay_balls(live, ball_model())
    end
    for name in pairs(ballsShown) do
        if not live[name] then OF.gamemodes.hide_token(name) end
    end
    ballsShown = live
end

local function lift_riders(m)
    if m == nil or m.marioObj == nil then return end
    local now = OF.gamemodes.current()
    if now == nil or now.key ~= "bumperballs" then return end
    if not OF.gamemodes.is_running() then return end
    if OF.gamemodes.role(m.playerIndex) ~= OF.ring.ROLE_IN then return end
    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.pos ~= nil and m.pos ~= nil then
        gfx.pos.y = m.pos.y + BALL_CONTACT
    end
end

local function tide_rising()
    return OF.gamemodes.option_now("tide") ~= "still"
end

local function fell_in(m)
    local at = OF.ring.at()
    if at == nil then return false end
    if m == nil or m.pos == nil then return false end
    return m.pos.y < at.y - OUT_DROP
end

local ROLE_OUT = "out"
local mode = {
    key = "bumperballs",
    resultsBy = "survival",
    name = "Ram Ring",
    blurb = "ride a ball and bump everybody else's into the sea",

    how = "Everybody rides a ball on an island in the sea.\n"
        .. "The stick rolls it; there is no jumping and no punching.\n"
        .. "Balls that meet bounce apart - the faster one hits harder.\n"
        .. "Cross the shore and you are in - there is no way back.\n"
        .. "A drop below the island counts the same.\n"
        .. "Whether the tide comes in is set below.\n"
        .. "Last one left on the island wins.\n"
        .. "On the clock, anybody still up shares the draw.",
    minPlayers = 2,

    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 120,

    saysOut = true,

    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_WATER,

    target = { name = "island width",
               asks = "Island width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 700, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,

    ringFloor = ISLAND_FLOOR,

    options = {
        { key = "size", name = "Island size",
          help = "how big the island starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual island, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller island - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger island - more room to run" },
          } },

        { key = "tide", name = "Tide",
          help = "stops two players stalling a round between them",
          choices = {
              { key = "rising", name = "rises",
                help = "the island narrows all round, faster with each "
                    .. "fall" },
              { key = "still", name = "still",
                help = "stays its opening size; fair footing for a small "
                    .. "lobby" },
          } },

        { key = "boost", name = "B-charge boost",
          help = "hold B while nearly still, let go to launch",
          choices = {
              { key = "off", name = "off",
                help = "the stick is the only way to speed up" },
              { key = "on", name = "on",
                help = "a longer hold launches harder, up to top speed" },
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

function mode.setup(players, options)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, OF.ring.ROLE_IN)
    end

    local named = options ~= nil and (options.targetNamed
        or (OF.gamemodes.targetChoice ~= nil and OF.gamemodes.targetChoice[mode.key] ~= nil))
    if named then
        OF.ring.set_opening(OF.ring.opening_for(options.target, #players, WIDEST_ACROSS))
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
    landed = false
    forget_ball()
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    if OF.ring.at() == nil then return end

    local over = OF.ring.margin(0)
    if over ~= nil and over < SHORE and over >= 0 then
        if not onShore then
            onShore = true
            OF.gamemodes.cue("hazard", nil, "bbshore")
        end
    elseif over == nil or over > SHORE + SHORE_CLEAR then
        onShore = false
    end

    if not OF.ring.outside(0) then
        landed = true
        if not fell_in(gMarioStates[0]) then return end
    elseif not landed then
        return
    end

    OF.ring.go_out("In the sea")
end

function mode.before_mario_update(m)
    if OF.ring.am_out() then
        forget_ball()
        off_ball(m)
        OF.ring.watch_frame(m)
        return
    end

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    roll_frame(m)
end

function mode.scenery()
    draw_balls()
end

function mode.host_update()

    if tide_rising() then OF.ring.close_frame() end

    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then

        OF.gamemodes.abandon("Nobody left on the island to push.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("Everybody went in the sea.")
    end
end

mode.symmetric = true
function mode.overtime()
    return OF.ring.overtime(20)
end

function mode.on_timeout()

    local standing = OF.ring.pushable()
    if #standing == 1 then
        OF.gamemodes.finish("@ won.", standing[1].np.name,
            standing[1].np.name)
        return
    end
    if #standing == 0 then
        OF.gamemodes.finish("Nobody won.")
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
    OF.gamemodes.finish(#standing == 1 and "Time - a draw, 1 player won." or "Time - a draw, @ players won.",
        { names = names }, tostring(#standing))
end

function mode.cleanup()

    OF.ring.let_go()
    landed = false
    forget_ball()

    off_ball(gMarioStates[0])
    for name in pairs(ballsShown) do OF.gamemodes.hide_token(name) end
    ballsShown = {}
end

function mode.terms()

    return OF.lang.fill("the last one left on a @ island",
        OF.lang.t(OF.gamemodes.option_showing("bumperballs", "size") or "normal"))
end

function mode.ball_velocity()
    return ball_velocity()
end

mode.BALL_GROUND = BALL_GROUND
mode.BALL_AIR = BALL_AIR
mode.act_ball_ground = act_ball_ground
mode.act_ball_air = act_ball_air
function mode.knock_for(theirs, mine) return knock_for(theirs, mine) end
function mode.boost_charge() return boostCharge end
function mode.rolled(index) return rolled[index] end
function mode.set_ball(x, z) ballX, ballZ = x, z end
function mode.note_riders() return note_riders() end
mode.RIDE_CAP = RIDE_CAP
function mode.replay_balls(live) return replay_balls(live, ball_model()) end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == OF.ring.ROLE_OUT then return "SEA" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.controls_lines()
    local lines = { OF.lang.t("Stick - roll the ball") }
    if boost_on() then
        lines[#lines + 1] = OF.lang.t("Hold B nearly still - let go to dash")
    end
    lines[#lines + 1] = OF.lang.t("No jumping off: the ball is yours")
    return lines
end

function mode.hud()
    local at = OF.ring.at()

    if at ~= nil then
        local over = OF.ring.margin(0)
        local red, green, blue = 120, 200, 255
        if over ~= nil and over < 0 then red, green, blue = 255, 120, 120 end
        OF.util.zone_ring(at, OF.ring.radius(), 48, 4, red, green, blue, 220, "edge")
    end

    if OF.ring.am_out() then

        OF.gamemodes.out_banner("In the sea")
        return
    end

    local over = OF.ring.margin(0)
    if over == nil then
        OF.gamemodes.away_banner("You are not in the island's area")
        return
    end

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        OF.util.legend(mode.controls_lines())
    end

    if over < SHORE and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("shore", OF.lang.t("On the shore"), { prio = 60, tone = "mute" })
    end
end

OF.gamemodes.register(mode)

hook_event(HOOK_MARIO_UPDATE, lift_riders)
