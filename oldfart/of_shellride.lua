OF = OF or {}

OF.shellride = OF.shellride or {}
local ride = OF.shellride

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

ride.RIDE_GROUND = at_load("allocate_mario_action",
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)
ride.RIDE_AIR = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)
ride.RIDE_HIT = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_RIDING_SHELL)

ride.JUMP_VEL = 42.0
ride.JUMP_FROM_SPEED = 0.25

ride.WALL_KEEP = 0.34

ride.TOP_SPEED = 64.0

ride.HIT_SPIN, ride.HIT_TUMBLE, ride.HIT_LAUNCH = 1, 2, 3
ride.HIT = {
    [ride.HIT_SPIN]   = { up = 12, keep = 0.3, frames = 30 },
    [ride.HIT_TUMBLE] = { up = 30, keep = 0.2, frames = 45 },
    [ride.HIT_LAUNCH] = { up = 55, keep = 0.0, frames = 60 },
}

ride.AIR_LIFT = 42.0

function ride.shell_lift(m)
    if m == nil or ride.RIDE_AIR == nil then return 0 end
    if m.action == ride.RIDE_AIR or m.action == ride.RIDE_HIT then return ride.AIR_LIFT end
    return 0
end

local function lift_the_rider(m)
    local o = m.marioObj
    if o == nil or o.header == nil or o.header.gfx == nil or o.header.gfx.pos == nil then return end
    local pos = o.header.gfx.pos
    pos.x, pos.y, pos.z = m.pos.x, m.pos.y + ride.AIR_LIFT, m.pos.z
end
ride.lift_the_rider = lift_the_rider

function ride.shell_place(m)
    if m == nil or m.pos == nil then return nil end
    local o = m.marioObj
    local gfx = o ~= nil and o.header ~= nil and o.header.gfx or nil
    local yaw = (o ~= nil and o.oMoveAngleYaw) or (m.faceAngle ~= nil and m.faceAngle.y) or 0
    local drawn = gfx ~= nil and gfx.pos ~= nil and gfx.angle ~= nil
        and math.abs((gfx.pos.x or 0) - m.pos.x) < 1 and math.abs((gfx.pos.z or 0) - m.pos.z) < 1
        and math.abs((gfx.pos.y or 0) - m.pos.y) < 400
    if not drawn then return m.pos.x, m.pos.y, m.pos.z, 0, yaw, 0 end
    local px, py, pz = gfx.pos.x, gfx.pos.y, gfx.pos.z
    local pitch, roll = gfx.angle.x or 0, gfx.angle.z or 0
    local lift = ride.shell_lift(m)
    if lift ~= 0 then
        local k = math.pi / 0x8000
        local sp, cp = math.sin(pitch * k), math.cos(pitch * k)
        local sy, cy = math.sin(yaw * k), math.cos(yaw * k)
        local sr, cr = math.sin(roll * k), math.cos(roll * k)
        local ux = -sr * cy + cr * sp * sy
        local uy = cr * cp
        local uz = sr * sy + cr * sp * cy
        px, py, pz = px - lift * ux, py - lift * uy, pz - lift * uz
    end
    return px, py, pz, pitch, yaw, roll
end

function ride.place_shell(token, m)
    if token == nil then return false end
    local x, y, z, pitch, yaw, roll = ride.shell_place(m)
    if x == nil then return false end
    token.oPosX, token.oPosY, token.oPosZ = x, y, z
    token.oFaceAnglePitch, token.oFaceAngleYaw, token.oFaceAngleRoll = pitch, yaw, roll
    local gfx = token.header ~= nil and token.header.gfx or nil
    if gfx ~= nil and gfx.pos ~= nil and gfx.angle ~= nil then
        gfx.pos.x, gfx.pos.y, gfx.pos.z = x, y, z
        gfx.angle.x, gfx.angle.y, gfx.angle.z = pitch, yaw, roll
    end
    return true
end

function ride.on_the_ride(m)
    if m == nil or ride.RIDE_GROUND == nil then return false end
    return m.action == ride.RIDE_GROUND or m.action == ride.RIDE_AIR
        or m.action == ride.RIDE_HIT
end

function ride.turn_around(m)
    local yaw = m.faceAngle.y or 0
    if yaw >= 0 then yaw = yaw - 0x8000 else yaw = yaw + 0x8000 end
    m.faceAngle.y = yaw
    if m.marioObj ~= nil then m.marioObj.oMoveAngleYaw = yaw end
end

local function shape(m, air)
    local modes = OF.gamemodes
    if modes == nil or modes.current == nil then return end
    local mode = modes.current()
    if mode == nil or type(mode.shape_ride) ~= "function" then return end
    mode.shape_ride(m, air)
end
ride.shape = shape

local function ask(m, name)
    local modes = OF.gamemodes
    if modes == nil or modes.current == nil then return nil end
    local mode = modes.current()
    if mode == nil or type(mode[name]) ~= "function" then return nil end
    return mode[name](m)
end
ride.ask = ask

local function act_ride_ground(m)
    if m == nil then return false end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        if set_mario_y_vel_based_on_fspeed ~= nil then
            set_mario_y_vel_based_on_fspeed(m, ride.JUMP_VEL, ride.JUMP_FROM_SPEED)
        end
        set_mario_action(m, ride.RIDE_AIR, 0)
        return false
    end

    update_shell_speed(m)
    shape(m, false)
    set_character_animation(m, CHAR_ANIM_RIDING_SHELL)

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ride.RIDE_AIR, 0)
    elseif step == GROUND_STEP_HIT_WALL then
        set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, false)
        ride.turn_around(m)
        mario_set_forward_vel(m, (m.forwardVel or 0) * ride.WALL_KEEP)
    end
    return false
end
ride.act_ground = act_ride_ground

local function act_ride_air(m)
    if m == nil then return false end
    set_character_animation(m, CHAR_ANIM_JUMP_RIDING_SHELL)
    if ask(m, "ride_air") ~= true then update_air_without_turn(m) end
    shape(m, true)

    local step = perform_air_step(m, 0)
    lift_the_rider(m)
    if step == AIR_STEP_LANDED then
        local crash = ask(m, "ride_land")
        if type(crash) == "number" and ride.HIT[crash] ~= nil then
            set_mario_action(m, ride.RIDE_HIT, crash)
            return false
        end

        set_mario_action(m, ride.RIDE_GROUND, 1)
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    end
    return false
end
ride.act_air = act_ride_air

local function act_ride_hit(m)
    if m == nil then return false end
    local how = ride.HIT[m.actionArg] or ride.HIT[ride.HIT_SPIN]
    if (m.actionTimer or 0) == 0 then
        m.vel.y = how.up
        mario_set_forward_vel(m, (m.forwardVel or 0) * how.keep)
    end
    m.actionTimer = (m.actionTimer or 0) + 1
    set_character_animation(m, CHAR_ANIM_JUMP_RIDING_SHELL)

    local yaw = (m.faceAngle.y or 0) + 0x1000
    if yaw > 0x7FFF then yaw = yaw - 0x10000 end
    m.faceAngle.y = yaw

    local step = perform_air_step(m, 0)
    lift_the_rider(m)
    if step == AIR_STEP_LANDED then
        m.vel.y = 0
        if m.actionTimer >= how.frames then
            set_mario_action(m, ride.RIDE_GROUND, 1)
        end
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    end
    if m.actionTimer >= how.frames * 3 then set_mario_action(m, ride.RIDE_AIR, 0) end
    return false
end
ride.act_hit = act_ride_hit

if ride.RIDE_GROUND ~= nil and ride.RIDE_AIR ~= nil and ride.RIDE_HIT ~= nil then
    at_load("hook_mario_action", ride.RIDE_GROUND, { every_frame = act_ride_ground })
    at_load("hook_mario_action", ride.RIDE_AIR, { every_frame = act_ride_air })
    at_load("hook_mario_action", ride.RIDE_HIT, { every_frame = act_ride_hit })
end

ride.shut = ride.shut or {}

ride.shutIn = nil
local function room_key()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil end
    return tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex) .. ":" .. tostring(np.currActNum)
end
local function shut_one(o)
    if o == nil or o.activeFlags == 0 then return end
    o.oIntangibleTimer = -1
    ride.shut[o] = true
end
function ride.shut_the_ways(poles)
    local here = room_key()
    if here ~= ride.shutIn then ride.shut, ride.shutIn = {}, here end
    local first = _G.obj_get_first_with_behavior_id
    local nextOf = _G.obj_get_next_with_same_behavior_id
    if first ~= nil and nextOf ~= nil and _G.id_bhvCannon ~= nil then
        local o = first(id_bhvCannon)
        while o ~= nil do
            shut_one(o)
            o = nextOf(o)
        end
    end
    if not poles then return end
    local firstIn, nextIn = _G.obj_get_first, _G.obj_get_next
    if firstIn == nil or nextIn == nil or _G.OBJ_LIST_POLELIKE == nil then return end
    local o = firstIn(OBJ_LIST_POLELIKE)
    while o ~= nil do
        if OF.util.has_flag(tonumber(o.oInteractType) or 0, INTERACT_POLE or 0x40) then
            shut_one(o)
        end
        o = nextIn(o)
    end
end
function ride.open_the_ways()
    if ride.shutIn ~= nil and ride.shutIn == room_key() then
        for o in pairs(ride.shut) do
            if o.activeFlags ~= 0 and o.oIntangibleTimer == -1 then o.oIntangibleTimer = 0 end
        end
    end
    ride.shut, ride.shutIn = {}, nil
end

function ride.ready()
    return ride.RIDE_GROUND ~= nil and ride.RIDE_AIR ~= nil and ride.RIDE_HIT ~= nil
end
