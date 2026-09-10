OF = OF or {}
OF.warp = OF.warp or {}

local warp = OF.warp

warp.KEY = "ofWarp"
local WIDTH = 5

local CODE = "0123456789abcdefghijklmnopqrstuvwxyz"
local function to_code(index)
    if type(index) ~= "number" then return CODE:sub(1, 1) end
    if index < 1 or index > #CODE then return CODE:sub(1, 1) end
    return CODE:sub(index, index)
end

local function from_code(character, fallback)
    if type(character) ~= "string" or #character ~= 1 then return fallback end
    local found = CODE:find(character, 1, true)
    if found == nil then return fallback end
    return found
end

warp.DIRECTIONS = {
    { key = "down", name = "down",
      blurb = "the way it has always been", dx = 0, dz = 0 },

    { key = "up", name = "up", up = true,
      blurb = "you fall towards the ceiling" },

}

local PULL_FACTOR = 1.0

local FALL_PER_FRAME = 4.0
local TERMINAL = 75.0

local FLAT = 1.0 / 512.0

warp.SCALES = {
    { key = "m4",   name = "four times over, mirrored", factor = -4.0 },
    { key = "m2",   name = "twice over, mirrored",      factor = -2.0 },
    { key = "m1",   name = "mirrored",                  factor = -1.0 },
    { key = "mh",   name = "half, mirrored",            factor = -0.5 },
    { key = "mq",   name = "a quarter, mirrored",       factor = -0.25 },
    { key = "flat", name = "flat",                      factor = FLAT },
    { key = "q",    name = "a quarter",                 factor = 0.25 },
    { key = "h",    name = "half",                      factor = 0.5 },
    { key = "one",  name = "unchanged",                 factor = 1.0 },
    { key = "hh",   name = "half again",                factor = 1.5 },
    { key = "two",  name = "twice",                     factor = 2.0 },
    { key = "four", name = "four times",                factor = 4.0 },
}

local SCALE_NEUTRAL = 9

local SCALE_FIRST_XZ = 7

local function legal_stop(axis, index)
    index = tonumber(index) or SCALE_NEUTRAL
    if axis ~= "x" and axis ~= "z" then return index end
    if index < SCALE_FIRST_XZ then return SCALE_NEUTRAL end
    return index
end

warp.SCALE_NEUTRAL = SCALE_NEUTRAL
warp.SCALE_FIRST_XZ = SCALE_FIRST_XZ
warp.FLAT = FLAT

function warp.ladder(axis)
    if axis ~= "x" and axis ~= "z" then return warp.SCALES, 0 end
    local list = {}
    for index = SCALE_FIRST_XZ, #warp.SCALES do
        table.insert(list, warp.SCALES[index])
    end
    return list, SCALE_FIRST_XZ - 1
end

local LISTS = {}

local function level_list(list)
    if list ~= nil then LISTS[#LISTS + 1] = list end
end

level_list(OBJ_LIST_SURFACE)
level_list(OBJ_LIST_GENACTOR)
level_list(OBJ_LIST_PUSHABLE)
level_list(OBJ_LIST_LEVEL)
level_list(OBJ_LIST_DESTRUCTIVE)
level_list(OBJ_LIST_POLELIKE)
level_list(OBJ_LIST_DEFAULT)

level_list(OBJ_LIST_SPAWNER)

local UNSIZED = {}

local function unsized_list(list)
    if list ~= nil then UNSIZED[#UNSIZED + 1] = list end
end

unsized_list(OBJ_LIST_PLAYER)
unsized_list(OBJ_LIST_EXT)
unsized_list(OBJ_LIST_UNIMPORTANT)

local ALL_LISTS = {}
for _, list in ipairs(LISTS) do ALL_LISTS[#ALL_LISTS + 1] = list end
for _, list in ipairs(UNSIZED) do ALL_LISTS[#ALL_LISTS + 1] = list end
warp.ALL_LISTS = ALL_LISTS

warp.LEVEL_LISTS = LISTS
warp.UNSIZED_LISTS = UNSIZED

warp.HORIZONS = {
    { key = "flat", name = "not at all",  share = 0.0 },
    { key = "full", name = "all the way", share = 1.0 },
}

local HORIZON_DEFAULT = 2

local TILT_PER_TICK = 0x0200

local TILT_SENSE = -1

local BODY_SHARE = 1.0

local BODY_PER_TICK = 0x0400

local BODY_SHADOW_FROM = 0x4000

local BODY_SENSE = -1

local BODY_HEIGHT = 160.0

function warp.code()
    local value = gGlobalSyncTable[warp.KEY]
    if type(value) ~= "string" then return nil end
    if #value ~= WIDTH then return nil end
    return value
end

local function stop_at(list, index, fallback)
    if type(index) ~= "number" then return list[fallback] end
    if index < 1 or index > #list then return list[fallback] end
    return list[index]
end

function warp.direction()
    local code = warp.code()
    if code == nil then return nil end
    local index = from_code(code:sub(1, 1), 1)
    if index <= 1 then return nil end
    local step = stop_at(warp.DIRECTIONS, index, 1)
    if step == nil or step.key == "down" then return nil end
    return step
end

function warp.scale()
    local code = warp.code()
    if code == nil then return 1.0, 1.0, 1.0 end

    local x = stop_at(warp.SCALES,
        legal_stop("x", from_code(code:sub(2, 2), SCALE_NEUTRAL)), SCALE_NEUTRAL)
    local y = stop_at(warp.SCALES, from_code(code:sub(3, 3), SCALE_NEUTRAL), SCALE_NEUTRAL)
    local z = stop_at(warp.SCALES,
        legal_stop("z", from_code(code:sub(4, 4), SCALE_NEUTRAL)), SCALE_NEUTRAL)
    return x.factor, y.factor, z.factor
end

function warp.indices()
    local code = warp.code()
    if code == nil then
        return 1, SCALE_NEUTRAL, SCALE_NEUTRAL, SCALE_NEUTRAL, HORIZON_DEFAULT
    end

    return from_code(code:sub(1, 1), 1),
        legal_stop("x", from_code(code:sub(2, 2), SCALE_NEUTRAL)),
        from_code(code:sub(3, 3), SCALE_NEUTRAL),
        legal_stop("z", from_code(code:sub(4, 4), SCALE_NEUTRAL)),
        from_code(code:sub(5, 5), HORIZON_DEFAULT)
end

function warp.horizon_stop()
    local _, _, _, _, horizon = warp.indices()
    return stop_at(warp.HORIZONS, horizon, HORIZON_DEFAULT)
end

function warp.horizon_turns()
    local stop = warp.horizon_stop()
    return stop ~= nil and (stop.share or 0) > 0
end

function warp.is_on()
    local dir, x, y, z = warp.indices()
    if dir > 1 then return true end
    if x ~= SCALE_NEUTRAL or y ~= SCALE_NEUTRAL or z ~= SCALE_NEUTRAL then return true end

    return false
end

local function write(dir, x, y, z, horizon)
    if not OF.util.is_host() then
        return false, "Only the host can change the world."
    end
    if not OF.perms.can("vision") then return false, OF.util.RANK_REFUSAL end

    x = legal_stop("x", x)
    z = legal_stop("z", z)

    local code = to_code(dir)
        .. to_code(x) .. to_code(y) .. to_code(z)
        .. to_code(horizon)

    if dir <= 1
        and x == SCALE_NEUTRAL and y == SCALE_NEUTRAL and z == SCALE_NEUTRAL
        and horizon == HORIZON_DEFAULT then
        OF.util.publish(warp.KEY, "")
        return true
    end

    OF.util.publish(warp.KEY, code)
    return true
end

warp.write = write

function warp.direction_index(key)
    for index, entry in ipairs(warp.DIRECTIONS) do
        if entry.key == key then return index end
    end
    return 1
end

local registered = false

local function ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true

    OF.net.register_action("world", "vision", function(fromLocal, x, _, z)
        if not OF.util.is_host() then return false, "Only the host." end
        local field = tostring(z)
        if field == "clear" then return warp.clear() end
        local index = tonumber(x)
        if index == nil then return false, "That is not one of the world's dials." end
        return warp.set(field, index)
    end)
end

hook_event(HOOK_UPDATE, function() ready() end)

function warp.set(field, index)

    if not OF.util.is_host() then
        return OF.net.host_does("world", index, nil, field)
    end
    local dir, x, y, z, horizon = warp.indices()
    if field == "direction" then dir = index
    elseif field == "x" then x = index
    elseif field == "y" then y = index
    elseif field == "z" then z = index
    elseif field == "horizon" then horizon = index
    else return false, "That is not one of the world's dials." end
    return write(dir, x, y, z, horizon)
end

function warp.clear()

    if not OF.util.is_host() then
        return OF.net.host_does("world", 0, nil, "clear")
    end
    return write(1, SCALE_NEUTRAL, SCALE_NEUTRAL, SCALE_NEUTRAL, HORIZON_DEFAULT)
end

local function stop_for_factor(factor)
    if type(factor) ~= "number" then return nil end
    for index, step in ipairs(warp.SCALES) do
        if step.factor == factor then return index end
    end
    return nil
end

function warp.world_snapshot()
    local dir, x, y, z, horizon = warp.indices()
    local fx, fy, fz = warp.scale()
    return {
        x = fx, y = fy, z = fz,
        xStop = x, yStop = y, zStop = z,
        direction = dir, horizon = horizon,
    }
end

function warp.borrow_world(value)
    if not OF.util.is_host() then return false end
    if type(value) ~= "table" then return false end

    local dir = tonumber(value.direction) or 1
    local horizon = tonumber(value.horizon) or HORIZON_DEFAULT

    local x = legal_stop("x",
        tonumber(value.xStop) or stop_for_factor(value.x) or SCALE_NEUTRAL)
    local y = tonumber(value.yStop) or stop_for_factor(value.y) or SCALE_NEUTRAL
    local z = legal_stop("z",
        tonumber(value.zStop) or stop_for_factor(value.z) or SCALE_NEUTRAL)

    local wasDir, wasX, wasY, wasZ, wasHorizon = warp.indices()
    if dir == wasDir and x == wasX and y == wasY and z == wasZ
        and horizon == wasHorizon then
        return false
    end
    return write(dir, x, y, z, horizon) == true
end

local function is_mine(m)
    return m ~= nil and m.playerIndex == 0
end

function warp.fall_is_owned()
    if OF.util.asks(OF.ground, "pull") and OF.ground.pull() ~= nil then return true end
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("lowgrav") then return true end
    if OF.util.asks(OF.cheats, "is_on") and OF.cheats.is_on("lowgrav") then return true end
    return false
end

function warp.is_yielding()
    local dir = warp.direction()
    return dir ~= nil and dir.up == true and warp.fall_is_owned()
end

function warp.stand_owns(m)
    if OF.util.asks(OF.underside, "stand_is_on")
        and OF.underside.stand_is_on(m) == true then
        return true
    end

    return false
end

function warp.stand_is_holding(m)
    if OF.util.asks(OF.underside, "held") and OF.underside.held(m) == true then
        return true
    end
    return false
end

function warp.stand_holds_body(m)
    local dir = warp.direction()
    if dir == nil then return false end

    if warp.fall_is_owned() then return false end
    if dir.up == true then
        if m == nil or m.pos == nil then return false end
        local _, ceil = find_ceil(m.pos.x, m.pos.y, m.pos.z)
        return ceil ~= nil
    end
    return false
end

function warp.drop_walk_lean(m)
    if m == nil or m.action ~= ACT_WALKING then return false end
    local obj = m.marioObj
    if obj == nil then return false end
    local gfx = obj.header ~= nil and obj.header.gfx or nil
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.x = 0
        gfx.angle.z = 0
    end
    if type(obj.oMarioWalkingPitch) == "number" then
        obj.oMarioWalkingPitch = 0
    end
    return true
end

function warp.drop_floor_align(m)
    local obj = m ~= nil and m.marioObj or nil
    local gfx = obj ~= nil and obj.header ~= nil and obj.header.gfx or nil
    if gfx == nil then return false end
    if gfx.throwMatrix == nil then return false end
    gfx.throwMatrix = nil
    return true
end

local STAND_FACTOR = 64.0

function warp.tilt_factor(m, holding)
    if holding == nil then holding = warp.stand_is_holding(m) end
    if holding then return STAND_FACTOR end
    return PULL_FACTOR
end

local driftX, driftZ = 0.0, 0.0

function warp.drift()
    return driftX, driftZ
end

function warp.forget_drift()
    driftX, driftZ = 0.0, 0.0
end

function warp.step_frame(m, stepType, stepArg)
    if not is_mine(m) then return end
    if warp.stand_owns(m) then return end

    if stepType == STEP_TYPE_GROUND then
        warp.forget_drift()
        return
    end
    if stepType ~= STEP_TYPE_AIR then return end

    local dir = warp.direction()
    if dir == nil then
        warp.forget_drift()
        return
    end

    local vel = m.vel
    if vel == nil or type(vel.x) ~= "number" or type(vel.y) ~= "number"
        or type(vel.z) ~= "number" then
        return
    end

    local pull = FALL_PER_FRAME * PULL_FACTOR
    local cap = TERMINAL * PULL_FACTOR

    local dx = dir.dx or 0
    local dz = dir.dz or 0
    if dx == 0 and dz == 0 then return end

    driftX = OF.util.clamp(driftX + pull * dx, -cap, cap)
    driftZ = OF.util.clamp(driftZ + pull * dz, -cap, cap)
    vel.x = vel.x + driftX
    vel.z = vel.z + driftZ
end

local function fold_s16(value)
    value = math.floor(value) & 0xFFFF
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

local tilt = 0

function warp.tilt()
    return tilt
end

function warp.forget_tilt()
    tilt = 0
    warp.forget_picture()
end

local HOLD_PER_TICK = 1.0 / 20.0

local RUN_FLOOR = 0.05

local hold = 0.0

function warp.picture_hold()
    return hold
end

function warp.forget_picture()
    hold = 0.0
end

function warp.picture_map(vx, vy, vz)
    local dir = warp.direction()
    if dir == nil then return nil end
    if type(vx) ~= "number" or type(vy) ~= "number" or type(vz) ~= "number" then
        return nil
    end
    if dir.up == true then return vx, -vy, vz end

    local dx, dz = dir.dx, dir.dz
    if type(dx) ~= "number" or type(dz) ~= "number" then return nil end
    if dx == 0 and dz == 0 then return nil end
    local length = math.sqrt(dx * dx + dz * dz)
    dx, dz = dx / length, dz / length

    local upX, upZ = -dx, -dz
    local sideX, sideZ = dz, -dx
    local along = vx * sideX + vz * sideZ
    local climb = vx * upX + vz * upZ
    return along * sideX + vy * upX,
           climb,
           along * sideZ + vy * upZ
end

local function turn_toward(vx, vy, vz, wx, wy, wz, share, axX, axY, axZ)
    if share <= 0.0 then return vx, vy, vz end
    if share >= 1.0 then return wx, wy, wz end
    local length = math.sqrt(vx * vx + vy * vy + vz * vz)
    if length < 0.0001 then return vx, vy, vz end

    local ax, ay, az = vx / length, vy / length, vz / length
    local wl = math.sqrt(wx * wx + wy * wy + wz * wz)
    if wl < 0.0001 then return vx, vy, vz end
    local bx, by, bz = wx / wl, wy / wl, wz / wl

    local dot = ax * bx + ay * by + az * bz
    if dot > 1.0 then dot = 1.0 elseif dot < -1.0 then dot = -1.0 end

    local kx, ky, kz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
    local ks = math.sqrt(kx * kx + ky * ky + kz * kz)
    local angle
    if ks < 0.0001 then

        if dot > 0.0 then return vx, vy, vz end
        local al = math.sqrt((axX or 0) ^ 2 + (axY or 0) ^ 2 + (axZ or 0) ^ 2)
        if al < 0.0001 then return vx, vy, vz end
        kx, ky, kz = (axX or 0) / al, (axY or 0) / al, (axZ or 0) / al
        angle = math.pi
    else
        kx, ky, kz = kx / ks, ky / ks, kz / ks
        angle = math.atan(ks, dot)
    end

    angle = angle * share
    local c, s = math.cos(angle), math.sin(angle)

    local rx = ax * c + (ky * az - kz * ay) * s
    local ry = ay * c + (kz * ax - kx * az) * s
    local rz = az * c + (kx * ay - ky * ax) * s
    return rx * length, ry * length, rz * length
end

function warp.picture_pull(m)
    local dir = warp.direction()
    if dir == nil then return nil end
    if not warp.horizon_turns() then return nil end

    if warp.stand_is_holding(m) then

        if not warp.camera_is_free() then return nil end
        if dir.up == true then return 0.0, 1.0, 0.0, true end
        local dx, dz = dir.dx, dir.dz
        if type(dx) ~= "number" or type(dz) ~= "number" then return nil end
        if dx == 0 and dz == 0 then return nil end
        local length = math.sqrt(dx * dx + dz * dz)
        return dx / length, 0.0, dz / length, true
    end

    if dir.up == true then return nil end
    local dx, dz = dir.dx, dir.dz
    if type(dx) ~= "number" or type(dz) ~= "number" then return nil end
    if dx == 0 and dz == 0 then return nil end

    local px, py, pz = dx * PULL_FACTOR, -1.0, dz * PULL_FACTOR
    local length = math.sqrt(px * px + py * py + pz * pz)
    if length < 0.0001 then return nil end
    return px / length, py / length, pz / length, false
end

function warp.camera_is_free()
    if gLakituState == nil then return false end
    if gLakituState.pos == nil or gLakituState.focus == nil then return false end
    if OF.util.asks(OF.camera, "active") and OF.camera.active() then return false end
    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        return false
    end
    if gFirstPersonCamera ~= nil and gFirstPersonCamera.enabled == true then
        return false
    end
    return true
end

function warp.camera_place(m, share)
    if m == nil or m.pos == nil then return nil end
    if not warp.camera_is_free() then return nil end
    share = share or hold
    if share <= 0.0 then return nil end

    local pos, focus = gLakituState.pos, gLakituState.focus

    local atX, atY, atZ = m.pos.x, m.pos.y, m.pos.z
    if type(atX) ~= "number" or type(atY) ~= "number"
        or type(atZ) ~= "number" then
        return nil
    end

    local dir = warp.direction()
    local axX, axY, axZ = 1.0, 0.0, 0.0
    if dir ~= nil and dir.up ~= true then
        local dx, dz = dir.dx or 0, dir.dz or 0
        local length = math.sqrt(dx * dx + dz * dz)
        if length > 0.0001 then axX, axY, axZ = dz / length, 0.0, -dx / length end
    end

    local function carried(v)
        local ox, oy, oz = (v.x or 0) - atX, (v.y or 0) - atY, (v.z or 0) - atZ
        local wx, wy, wz = warp.picture_map(ox, oy, oz)
        if wx == nil then return nil end
        local tx, ty, tz = turn_toward(ox, oy, oz, wx, wy, wz, share,
            axX, axY, axZ)
        return atX + tx, atY + ty, atZ + tz
    end

    local px, py, pz = carried(pos)
    if px == nil then return nil end
    local fx, fy, fz = carried(focus)
    if fx == nil then return nil end

    local vx, vy, vz = fx - px, fy - py, fz - pz
    local length = math.sqrt(vx * vx + vy * vy + vz * vz)
    if length < 0.0001 then return px, py, pz, fx, fy, fz end
    local run = math.sqrt(vx * vx + vz * vz) / length
    if run < RUN_FLOOR then
        local hx, hz = vx, vz
        local hl = math.sqrt(hx * hx + hz * hz)
        if hl < 0.0001 then hx, hz, hl = axX, axZ, 1.0 end

        local want = RUN_FLOOR * length
        fx = px + hx / hl * want
        fz = pz + hz / hl * want
    end
    return px, py, pz, fx, fy, fz
end

local function screen_axes(px, py, pz, fx, fy, fz)
    local vx, vy, vz = fx - px, fy - py, fz - pz
    local length = math.sqrt(vx * vx + vy * vy + vz * vz)
    if length < 0.0001 then return nil end
    vx, vy, vz = vx / length, vy / length, vz / length

    local rx, ry, rz = -vz, 0.0, vx
    local rl = math.sqrt(rx * rx + rz * rz)
    if rl < 0.0001 then return nil end
    rx, rz = rx / rl, rz / rl

    local ux = ry * vz - rz * vy
    local uy = rz * vx - rx * vz
    local uz = rx * vy - ry * vx
    return rx, ry, rz, ux, uy, uz, vx, vy, vz
end

warp.screen_axes = screen_axes

local function roll_for(pullX, pullY, pullZ, px, py, pz, fx, fy, fz)
    local rx, ry, rz, ux, uy, uz = screen_axes(px, py, pz, fx, fy, fz)
    if rx == nil then return 0 end
    local a = pullX * rx + pullY * ry + pullZ * rz
    local b = pullX * ux + pullY * uy + pullZ * uz

    if a == 0 and b == 0 then return 0 end

    return fold_s16(TILT_SENSE * (0x4000 + atan2s(a, b)))
end

function warp.tilt_target()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local pullX, pullY, pullZ, place = warp.picture_pull(m)
    if pullX == nil then return 0 end

    if gLakituState == nil or gLakituState.pos == nil
        or gLakituState.focus == nil then return 0 end

    local px, py, pz = gLakituState.pos.x, gLakituState.pos.y, gLakituState.pos.z
    local fx, fy, fz = gLakituState.focus.x, gLakituState.focus.y,
                       gLakituState.focus.z

    if place then
        local qx, qy, qz, gx, gy, gz = warp.camera_place(m)
        if qx ~= nil then px, py, pz, fx, fy, fz = qx, qy, qz, gx, gy, gz end
    end
    return roll_for(pullX, pullY, pullZ, px, py, pz, fx, fy, fz)
end

function warp.tilt_step(from, target)
    local delta = fold_s16(target - from)
    if delta > TILT_PER_TICK then delta = TILT_PER_TICK end
    if delta < -TILT_PER_TICK then delta = -TILT_PER_TICK end
    return fold_s16(from + delta)
end

function warp.tilt_frame()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local pullX, pullY, pullZ, place = warp.picture_pull(m)

    local want = (place == true and warp.camera_is_free()) and 1.0 or 0.0
    if hold < want then
        hold = hold + HOLD_PER_TICK
        if hold > want then hold = want end
    elseif hold > want then
        hold = hold - HOLD_PER_TICK
        if hold < want then hold = want end
    end

    local px, py, pz, fx, fy, fz
    if gLakituState ~= nil and gLakituState.pos ~= nil
        and gLakituState.focus ~= nil then
        px, py, pz = gLakituState.pos.x, gLakituState.pos.y, gLakituState.pos.z
        fx, fy, fz = gLakituState.focus.x, gLakituState.focus.y,
                     gLakituState.focus.z
    end

    if hold > 0.0 and px ~= nil then
        local qx, qy, qz, gx, gy, gz = warp.camera_place(m)
        if qx ~= nil then
            px, py, pz, fx, fy, fz = qx, qy, qz, gx, gy, gz
            gLakituState.pos.x, gLakituState.pos.y, gLakituState.pos.z =
                px, py, pz
            gLakituState.focus.x, gLakituState.focus.y, gLakituState.focus.z =
                fx, fy, fz
        end
    end

    local target = 0
    if pullX ~= nil and px ~= nil then
        target = roll_for(pullX, pullY, pullZ, px, py, pz, fx, fy, fz)
    end

    if hold >= 1.0 then
        tilt = target
    else
        if tilt == 0 and target == 0 then return end
        tilt = warp.tilt_step(tilt, target)
    end
    if tilt == 0 then return end

    if gLakituState == nil then return end
    gLakituState.roll = fold_s16((gLakituState.roll or 0) + tilt)
end

local bodyPitch, bodyRoll = {}, {}

local bodyHidden = {}

function warp.body_angles(index)
    return bodyPitch[index] or 0, bodyRoll[index] or 0
end

function warp.forget_bodies()
    for index in pairs(bodyHidden) do
        local m = gMarioStates ~= nil and gMarioStates[index] or nil
        local gfx = m ~= nil and m.marioObj ~= nil and m.marioObj.header ~= nil
            and m.marioObj.header.gfx or nil
        if gfx ~= nil then gfx.shadowInvisible = false end
    end
    bodyPitch, bodyRoll, bodyHidden = {}, {}, {}
end

function warp.body_target(m)
    local dir = warp.direction()
    if dir == nil then return 0, 0, false end

    if m ~= nil and type(m.action) == "number" then
        local group = OF.util.action_group(m.action)
        if group == OF.util.action_group(ACT_GROUP_SUBMERGED)
            or group == OF.util.action_group(ACT_GROUP_AUTOMATIC)
            or group == OF.util.action_group(ACT_GROUP_CUTSCENE) then

            return 0, 0, false
        end
    end

    local stood = warp.stand_holds_body(m)

    local share = BODY_SHARE

    if dir.up == true then

        if warp.fall_is_owned() then return 0, 0, stood end

        if not stood then return 0, 0, stood end
        return 0, fold_s16(0x8000 * share), stood
    end

    local dx, dz = dir.dx, dir.dz
    if type(dx) ~= "number" or type(dz) ~= "number" then return 0, 0, stood end
    if dx == 0 and dz == 0 then return 0, 0, stood end

    local factor = warp.tilt_factor(m, stood)
    local angle = atan2s(1.0, factor) * share

    local ux, uz = -dx, -dz

    local yaw = 0
    if m ~= nil and m.faceAngle ~= nil and type(m.faceAngle.y) == "number" then
        yaw = m.faceAngle.y
    end

    local forward = ux * sins(yaw) + uz * coss(yaw)
    local right = ux * coss(yaw) - uz * sins(yaw)

    return fold_s16(angle * forward), fold_s16(angle * right * BODY_SENSE), stood
end

function warp.body_step(from, target)
    local delta = fold_s16(target - from)
    if delta > BODY_PER_TICK then delta = BODY_PER_TICK end
    if delta < -BODY_PER_TICK then delta = -BODY_PER_TICK end
    return fold_s16(from + delta)
end

function warp.body_lift(pitch, roll)
    return BODY_HEIGHT * 0.5 * (1.0 - coss(pitch) * coss(roll))
end

function warp.body_frame(m)
    if m == nil or type(m.playerIndex) ~= "number" then return end
    local index = m.playerIndex

    if warp.direction() == nil and bodyPitch[index] == nil
        and bodyRoll[index] == nil and not bodyHidden[index] then
        return
    end

    local targetPitch, targetRoll, stood = warp.body_target(m)
    local pitch = warp.body_step(bodyPitch[index] or 0, targetPitch)
    local roll = warp.body_step(bodyRoll[index] or 0, targetRoll)

    if stood then
        warp.drop_walk_lean(m)
        warp.drop_floor_align(m)
    end

    if pitch == 0 and roll == 0 then
        bodyPitch[index], bodyRoll[index] = nil, nil
        if bodyHidden[index] then
            local gfx = m.marioObj ~= nil and m.marioObj.header ~= nil
                and m.marioObj.header.gfx or nil
            if gfx ~= nil then gfx.shadowInvisible = false end
            bodyHidden[index] = nil
        end
        return
    end

    bodyPitch[index], bodyRoll[index] = pitch, roll

    local gfx = m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx or nil
    if gfx == nil then return end

    if gfx.angle ~= nil then
        gfx.angle.x = fold_s16((gfx.angle.x or 0) + pitch)
        gfx.angle.z = fold_s16((gfx.angle.z or 0) + roll)
    end

    if gfx.pos ~= nil and type(gfx.pos.y) == "number" then
        gfx.pos.y = gfx.pos.y + warp.body_lift(pitch, roll)
    end

    local hide = math.max(math.abs(pitch), math.abs(roll)) >= BODY_SHADOW_FROM
    if hide then
        gfx.shadowInvisible = true
        bodyHidden[index] = true
    elseif bodyHidden[index] then
        gfx.shadowInvisible = false
        bodyHidden[index] = nil
    end
end

local floorClasses = nil

local function build_floor_classes()
    floorClasses = {}
    local function put(kind, class)
        if kind ~= nil and class ~= nil then floorClasses[kind] = class end
    end

    put(SURFACE_NOT_SLIPPERY, SURFACE_CLASS_NOT_SLIPPERY)
    put(SURFACE_HARD_NOT_SLIPPERY, SURFACE_CLASS_NOT_SLIPPERY)
    put(SURFACE_SWITCH, SURFACE_CLASS_NOT_SLIPPERY)

    put(SURFACE_SLIPPERY, SURFACE_CLASS_SLIPPERY)
    put(SURFACE_NOISE_SLIPPERY, SURFACE_CLASS_SLIPPERY)
    put(SURFACE_HARD_SLIPPERY, SURFACE_CLASS_SLIPPERY)
    put(SURFACE_NO_CAM_COL_SLIPPERY, SURFACE_CLASS_SLIPPERY)

    put(SURFACE_VERY_SLIPPERY, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_ICE, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_HARD_VERY_SLIPPERY, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_NOISE_VERY_SLIPPERY_73, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_NOISE_VERY_SLIPPERY_74, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_NOISE_VERY_SLIPPERY, SURFACE_CLASS_VERY_SLIPPERY)
    put(SURFACE_NO_CAM_COL_VERY_SLIPPERY, SURFACE_CLASS_VERY_SLIPPERY)

    return floorClasses
end

function warp.forget_floor_classes()
    floorClasses = nil
end

function warp.stand_floor_class(m, floorClass)

    if floorClass ~= SURFACE_CLASS_VERY_SLIPPERY then return nil end

    if m == nil or m.playerIndex ~= 0 then return nil end

    local surface, planted = nil, false
    if OF.util.asks(OF.underside, "held") and OF.underside.held(m) == true then
        planted = true
        if OF.util.asks(OF.underside, "standing") then
            surface = OF.underside.standing()
        end
    end
    if not planted then return nil end

    local kind = surface ~= nil and surface.type or nil
    local class = SURFACE_CLASS_DEFAULT
    if type(kind) == "number" then
        class = (floorClasses or build_floor_classes())[kind] or SURFACE_CLASS_DEFAULT
    end

    if class == SURFACE_CLASS_DEFAULT and m ~= nil and m.action == ACT_CRAWLING then
        class = SURFACE_CLASS_NOT_SLIPPERY
    end

    return class
end

warp.walks = 0

local unculled = false

function warp.uncull_frame()

    local unculling = warp.picture_scaled() == true

    if not unculling and not unculled then return 0 end

    local touched = 0
    for _, list in ipairs(ALL_LISTS) do
        warp.walks = warp.walks + 1
        local object = obj_get_first(list)

        local seen = 0
        while object ~= nil and seen < 1200 do
            local header = object.header
            local gfx = header ~= nil and header.gfx or nil

            if gfx ~= nil then gfx.skipInViewCheck = unculling end
            touched = touched + 1
            seen = seen + 1
            object = obj_get_next(object)
        end
    end

    unculled = unculling
    return touched
end

local FAR_BASE = 30000

local farPushed = nil

function warp.far_reach(fx, fy, fz)
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then
        return nil
    end
    local biggest = math.max(math.abs(fx), math.abs(fy), math.abs(fz))

    if not (biggest > 1.0) then return nil end
    return FAR_BASE * biggest
end

function warp.far_frame()
    if type(set_override_far) ~= "function" then return nil end

    local want = nil
    local on, fx, fy, fz = warp.picture_scaled()
    if on then want = warp.far_reach(fx, fy, fz) end

    if want ~= nil and type(draw_distance_scalar_is_infinite) == "function"
        and draw_distance_scalar_is_infinite() then
        want = nil
    end

    if want == farPushed then return farPushed end

    set_override_far(want or 0)
    farPushed = want
    return farPushed
end

local VERTEX_MAX = 32767

warp.landClamped = 0
warp.landShaped = 0

warp.landDropped = 0

warp.landRoofs = 0

warp.landStood = 0

warp.landNoFloor = 0

local LAND_INTANGIBLE = SURFACE_FLAG_INTANGIBLE or 4

local STAND_HEIGHT = 160.0

local function land_cramped(fy)
    if fy < 0 then fy = -fy end
    return (2 * VERTEX_MAX) * fy <= STAND_HEIGHT
end

local landCode = nil
local landSize = nil

local landView = nil

local landDrawnAt = nil
local landReachAt = nil

local landLoaded = nil

local math_floor = math.floor
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max

local function land_clamp(value)
    if value > VERTEX_MAX then
        warp.landClamped = warp.landClamped + 1
        return VERTEX_MAX
    end
    if value < -VERTEX_MAX then
        warp.landClamped = warp.landClamped + 1
        return -VERTEX_MAX
    end
    return value
end

local function land_limit_clamp(value)
    if value > VERTEX_MAX then return VERTEX_MAX end
    if value < -VERTEX_MAX then return -VERTEX_MAX end
    return value
end

local function land_round(value)
    return math_floor(value + 0.5)
end

function warp.shape_surface(surface, dynamic)

    if dynamic then return false end
    if surface == nil then return false end

    local pool = surface.poolType
    if pool ~= nil and pool ~= (SURFACE_POOL_STATIC or 0) then return false end

    local code = warp.code() or ""
    if landCode ~= code or landSize == nil then
        local fx, fy, fz = warp.scale()
        landCode = code
        landSize = { x = fx, y = fy, z = fz, cramped = land_cramped(fy) }
    end

    local fx, fy, fz = landSize.x, landSize.y, landSize.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return false end

    local v1, v2, v3 = surface.vertex1, surface.vertex2, surface.vertex3
    local n = surface.normal
    if v1 == nil or v2 == nil or v3 == nil or n == nil then return false end

    local x1 = land_clamp(land_round((v1.x or 0) * fx))
    local y1 = land_clamp(land_round((v1.y or 0) * fy))
    local z1 = land_clamp(land_round((v1.z or 0) * fz))
    local x2 = land_clamp(land_round((v2.x or 0) * fx))
    local y2 = land_clamp(land_round((v2.y or 0) * fy))
    local z2 = land_clamp(land_round((v2.z or 0) * fz))
    local x3 = land_clamp(land_round((v3.x or 0) * fx))
    local y3 = land_clamp(land_round((v3.y or 0) * fy))
    local z3 = land_clamp(land_round((v3.z or 0) * fz))

    local ux, uy, uz = x2 - x1, y2 - y1, z2 - z1
    local wx, wy, wz = x3 - x1, y3 - y1, z3 - z1
    local cx = uy * wz - uz * wy
    local cy = uz * wx - ux * wz
    local cz = ux * wy - uy * wx
    local flattened = (cx == 0 and cy == 0 and cz == 0)

    local nx = (n.x or 0) * fy * fz
    local ny = (n.y or 0) * fx * fz
    local nz = (n.z or 0) * fx * fy
    local mag = math_sqrt(nx * nx + ny * ny + nz * nz)

    if mag < 0.0001 then flattened = true end

    v1.x, v1.y, v1.z = x1, y1, z1
    v2.x, v2.y, v2.z = x2, y2, z2
    v3.x, v3.y, v3.z = x3, y3, z3

    if flattened then

        surface.flags = (surface.flags or 0) | LAND_INTANGIBLE
        surface.lowerY = land_clamp(math_min(y1, y2, y3) - 5)
        surface.upperY = land_clamp(math_max(y1, y2, y3) + 5)

        if OF.util.asks(OF.ground, "remeasure") then
            OF.ground.remeasure(surface)
        end
        warp.landDropped = warp.landDropped + 1
        warp.landShaped = warp.landShaped + 1
        if landLoaded == nil then
            landLoaded = { x = fx, y = fy, z = fz }
        end
        return true
    end

    nx = nx / mag
    ny = ny / mag
    nz = nz / mag
    n.x, n.y, n.z = nx, ny, nz

    surface.originOffset = -(nx * x1 + ny * y1 + nz * z1)
    surface.lowerY = land_clamp(math_min(y1, y2, y3) - 5)
    surface.upperY = land_clamp(math_max(y1, y2, y3) + 5)

    if landSize.cramped and ny < ((gLevelValues or {}).ceilNormalMaxY or -0.01) then
        surface.flags = (surface.flags or 0) | LAND_INTANGIBLE
        warp.landRoofs = warp.landRoofs + 1
    end

    if OF.util.asks(OF.ground, "remeasure") then
        OF.ground.remeasure(surface)
    end

    if landLoaded == nil then
        landLoaded = { x = fx, y = fy, z = fz }
    end

    warp.landShaped = warp.landShaped + 1
    return true
end

local landWhere = nil

local function land_where()
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil then return nil end
    return tostring(me.currLevelNum) .. ":" .. tostring(me.currAreaIndex)
end

local landPlaced = false

local landArrived = false
local landArrivedWhere = nil

local landGrew = false
local landGrowAt = nil
local landQueue = {}
local landQueueLen = 0

function warp.forget_land()
    warp.landClamped = 0
    warp.landShaped = 0
    warp.landDropped = 0
    warp.landRoofs = 0
    landCode = nil
    landSize = nil
    landPlaced = false
    landArrived = false
    landArrivedWhere = nil
    warp.landStood = 0
    warp.landNoFloor = 0

    warp.landGrown = 0

    warp.landPressed = 0
    warp.landClimbed = 0
    warp.landLate = 0

    warp.landPathed = 0
    warp.landReached = 0
    warp.landQueueFull = 0
    landGrew = false
    landGrowAt = nil
    landQueue = {}
    landQueueLen = 0
    landLoaded = nil

    landView = nil

    landDrawnAt = nil
    landReachAt = nil
end

local function land_carry_object(object, fx, fy, fz)
    local px, py, pz = object.oPosX, object.oPosY, object.oPosZ
    if type(px) ~= "number" or type(py) ~= "number"
        or type(pz) ~= "number" then return false end
    object.oPosX, object.oPosY, object.oPosZ = px * fx, py * fy, pz * fz

    local hx, hy, hz = object.oHomeX, object.oHomeY, object.oHomeZ
    if type(hx) == "number" and type(hy) == "number"
        and type(hz) == "number" then
        object.oHomeX, object.oHomeY, object.oHomeZ = hx * fx, hy * fy, hz * fz
    end

    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local at = gfx ~= nil and gfx.pos or nil
    if at ~= nil and type(at.x) == "number"
        and type(at.y) == "number" and type(at.z) == "number" then
        at.x, at.y, at.z = at.x * fx, at.y * fy, at.z * fz
    end
    return true
end

function warp.land_place()
    landWhere = land_where() or landWhere
    if landPlaced then return 0 end

    if (warp.landShaped or 0) <= 0 then return 0 end
    local size = landSize
    if size == nil then return 0 end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return 0 end

    landPlaced = true
    local moved = 0
    for _, list in ipairs(LISTS) do
        warp.walks = warp.walks + 1
        local object = obj_get_first(list)

        local seen = 0
        while object ~= nil and seen < 1200 do
            if land_carry_object(object, fx, fy, fz) then moved = moved + 1 end
            seen = seen + 1
            object = obj_get_next(object)
        end
    end
    return moved
end

function warp.land_pending()
    local fx, fy, fz = warp.scale()

    local wx, wy, wz = 1.0, 1.0, 1.0
    local was = landLoaded
    if was ~= nil then wx, wy, wz = was.x, was.y, was.z end

    return fx ~= wx or fy ~= wy or fz ~= wz
end

local settleCode = nil
local settleWhere = nil
local settleTried = nil

function warp.forget_settle()
    settleCode = nil
    settleWhere = nil
    settleTried = nil
end

function warp.settled_at()
    return settleTried
end

function warp.settle_shape()
    local code = warp.code() or ""
    local room = land_where() or ""
    if code == settleCode and room == settleWhere then return false end

    if OF.net ~= nil and OF.net.pendingWarp ~= nil then return false end
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil or me.currAreaSyncValid == false then return false end

    settleCode = code
    settleWhere = room

    if not OF.util.asks(OF.lockdown, "is_on") then return false end
    if not OF.lockdown.is_on() then return false end

    if not warp.land_pending() then return false end

    local key = room .. "|" .. code
    if settleTried == key then return false end
    settleTried = key

    if not OF.util.asks(OF.net, "reload_here") then return false end
    local ok = OF.net.reload_here()
    if ok and OF.util.asks(OF.notify, "show") then

        OF.notify.show("Loading the map at the world's own size.", "info", 5)
    end
    return ok == true
end

function warp.land_placed()
    return landPlaced
end

function warp.land_area_watch()
    local where = land_where()
    if where == nil or where == landWhere then return 0 end
    landWhere = where
    landPlaced = false

    landGrew = false
    landGrowAt = nil
    landQueue = {}
    landQueueLen = 0
    return warp.land_place()
end

warp.landGrown = 0

warp.landLate = 0

warp.landPathed = 0

warp.landReached = 0

local LAND_GROW_DELAY = 2

local function land_is_landscape(object)
    if object == nil then return false end
    local ok, data = pcall(function() return object.collisionData end)
    return ok and data ~= nil
end

warp.land_is_landscape = land_is_landscape

local REACH_FIELDS = { "oCollisionDistance", "oDrawingDistance" }

local function land_reach_grow(object, a)
    if type(a) ~= "number" or not (a > 1.0) then return false end
    local wrote = false
    for _, field in ipairs(REACH_FIELDS) do
        local was = object[field]

        if type(was) == "number" and was > 0 then
            object[field] = was * a
            wrote = true
        end
    end
    return wrote
end

local function land_size_object(object, ax, ay, az)
    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local was = gfx ~= nil and gfx.scale or nil
    local sx, sy, sz = 1.0, 1.0, 1.0
    if was ~= nil and type(was.x) == "number" and type(was.y) == "number"
        and type(was.z) == "number" then
        sx, sy, sz = was.x, was.y, was.z
    end
    obj_scale_xyz(object, sx * ax, sy * ay, sz * az)
end

local HITBOX_ENGINE_FLAG = OBJ_FLAG_30 or 0x40000000

local HITBOX_WIDE = { "hitboxRadius", "hurtboxRadius" }
local HITBOX_TALL = { "hitboxHeight", "hurtboxHeight", "hitboxDownOffset" }

local function land_engine_hitbox(object)
    if object == nil then return false end
    local ok, flags = pcall(function() return object.oFlags end)
    if not (ok and type(flags) == "number") then return false end
    return flags & HITBOX_ENGINE_FLAG ~= 0
end

warp.land_engine_hitbox = land_engine_hitbox

warp.landPressed = 0

local function land_press_fields(object, fields, factor)
    if type(factor) ~= "number" or not (factor > 1.0) then return false end
    local wrote = false
    for _, field in ipairs(fields) do
        local ok, did = pcall(function()
            local was = object[field]
            if type(was) ~= "number" or not (was > 0) then return false end
            object[field] = was * factor
            return true
        end)
        if ok and did then wrote = true end
    end
    return wrote
end

local function land_hitbox_object(object, ax, ay, az)
    if object == nil then return false end

    if land_engine_hitbox(object) then return false end
    local wrote = false
    if land_press_fields(object, HITBOX_WIDE, math_max(ax, az)) then
        wrote = true
    end
    if land_press_fields(object, HITBOX_TALL, ay) then wrote = true end
    if wrote then warp.landPressed = (warp.landPressed or 0) + 1 end
    return wrote
end

warp.land_hitbox_object = land_hitbox_object

local function land_grow_object(object, ax, ay, az)
    if not land_is_landscape(object) then return false end
    land_size_object(object, ax, ay, az)

    land_reach_grow(object, math_max(ax, ay, az))

    land_hitbox_object(object, ax, ay, az)
    return true
end

warp.land_reach_grow = land_reach_grow

local CLIMB_TYPE = INTERACT_POLE or 0x40

local CLIMB_FLOOR = 100.0

local function land_is_climbed(object)
    if object == nil then return false end
    local ok, kind = pcall(function() return object.oInteractType end)
    if not (ok and type(kind) == "number") then return false end
    return kind & CLIMB_TYPE ~= 0
end

warp.land_is_climbed = land_is_climbed

function warp.climb_height(was, ay)
    if type(was) ~= "number" or type(ay) ~= "number" then return nil end
    if not (was > 0) then return nil end
    local now = was * ay
    if now < CLIMB_FLOOR then now = CLIMB_FLOOR end
    return now
end

warp.landClimbed = 0

local CLIMB_WIDE = { "hitboxRadius" }
local CLIMB_TALL = { "hitboxDownOffset" }

local function land_climb_object(object, ax, ay, az)
    if not land_is_climbed(object) then return false end
    local wrote = false

    if obj_scale_xyz ~= nil then
        land_size_object(object, ax, ay, az)
    end

    if land_engine_hitbox(object) then
        if wrote then warp.landClimbed = (warp.landClimbed or 0) + 1 end
        return wrote
    end

    local ok, high = pcall(function() return object.hitboxHeight end)
    if ok then
        local now = warp.climb_height(high, ay)
        if now ~= nil and now ~= high then
            object.hitboxHeight = now
            wrote = true
        end
    end

    if land_press_fields(object, CLIMB_WIDE, math_max(ax, az)) then
        wrote = true
    end
    if land_press_fields(object, CLIMB_TALL, ay) then wrote = true end

    if wrote then warp.landClimbed = (warp.landClimbed or 0) + 1 end
    return wrote
end

warp.land_climb_object = land_climb_object

local function land_is_pathed(object)
    if object == nil then return false end
    local ok, pathed = pcall(function()
        return obj_has_behavior_id(object, id_bhvPlatformOnTrack) ~= 0
    end)
    return ok and pathed
end

warp.land_is_pathed = land_is_pathed

local function land_reach_object(object, fy, whole)
    if object == nil or fy == 1.0 then return false end
    local ok, wrote = pcall(function()
        local home = object.oHomeY
        if type(home) ~= "number" then return false end

        local peak = nil
        if obj_has_behavior_id(object, id_bhvTTCElevator) ~= 0 then
            peak = "oTTCElevatorPeakY"
        elseif obj_has_behavior_id(object, id_bhvTTCPitBlock) ~= 0 then
            peak = "oTTCPitBlockPeakY"
        end
        if peak ~= nil then
            local was = object[peak]
            if type(was) ~= "number" then return false end
            if whole then
                object[peak] = fy * was
            else
                object[peak] = home + fy * (was - home)
            end
            return true
        end

        if obj_has_behavior_id(object, id_bhvRrElevatorPlatform) == 0
            and obj_has_behavior_id(object, id_bhvHmcElevatorPlatform) == 0 then
            return false
        end

        local low, high = object.oElevatorUnkF4, object.oElevatorUnkF8
        if type(low) ~= "number" or type(high) ~= "number" then return false end
        if whole or low ~= home then low = fy * low end
        if whole or high ~= home then high = fy * high end
        object.oElevatorUnkF4 = low
        object.oElevatorUnkF8 = high
        object.oElevatorUnkFC = (low + high) / 2
        return true
    end)
    if not (ok and wrote) then return false end
    warp.landReached = (warp.landReached or 0) + 1
    return true
end

warp.land_reach_object = land_reach_object

function warp.land_grow()
    if landGrew then return 0 end
    if (warp.landShaped or 0) <= 0 then return 0 end
    local size = landSize
    if size == nil then return 0 end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return 0 end

    landGrew = true

    local sizes = obj_scale_xyz ~= nil
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)
    local grown = 0
    for _, list in ipairs(LISTS) do
        warp.walks = warp.walks + 1
        local object = obj_get_first(list)

        local seen = 0
        while object ~= nil and seen < 1200 do
            if sizes and land_grow_object(object, ax, ay, az) then
                grown = grown + 1

            elseif land_climb_object(object, ax, ay, az) then
                grown = grown + 1
            end

            land_reach_object(object, fy, false)
            if land_is_pathed(object) then
                warp.landPathed = (warp.landPathed or 0) + 1
            end
            seen = seen + 1
            object = obj_get_next(object)
        end
    end
    warp.landGrown = (warp.landGrown or 0) + grown
    return grown
end

function warp.land_grown()
    return landGrew
end

local LAND_QUEUE_MAX = 200
warp.landQueueFull = 0

function warp.land_watch_object(object)
    if object == nil then return false end
    if not landPlaced then return false end
    if (warp.landShaped or 0) <= 0 then return false end
    if landSize == nil then return false end
    if landQueueLen >= LAND_QUEUE_MAX then
        warp.landQueueFull = (warp.landQueueFull or 0) + 1
        return false
    end
    landQueueLen = landQueueLen + 1
    landQueue[landQueueLen] = object
    return true
end

local function land_derived(object)
    local parent = object.parentObj
    if parent == nil then return false end
    local rx = object.oParentRelativePosX
    local ry = object.oParentRelativePosY
    local rz = object.oParentRelativePosZ
    if (type(rx) == "number" and rx ~= 0)
        or (type(ry) == "number" and ry ~= 0)
        or (type(rz) == "number" and rz ~= 0) then return true end
    local ok, same = pcall(function()
        return parent.oPosX == object.oPosX
            and parent.oPosY == object.oPosY
            and parent.oPosZ == object.oPosZ
    end)
    return ok and same
end

local function land_carry_home(object, fx, fy, fz)
    local flag = object.setHome
    if flag ~= nil and flag ~= 0 and flag ~= false then return false end
    local hx, hy, hz = object.oHomeX, object.oHomeY, object.oHomeZ
    if type(hx) ~= "number" or type(hy) ~= "number"
        or type(hz) ~= "number" then return false end
    if hx == 0 and hy == 0 and hz == 0 then return false end
    if hx == object.oPosX and hy == object.oPosY
        and hz == object.oPosZ then return false end
    object.oHomeX, object.oHomeY, object.oHomeZ = hx * fx, hy * fy, hz * fz
    return true
end

function warp.land_late_frame()
    if landQueueLen == 0 then return 0 end
    local size = landSize
    local shaped = (warp.landShaped or 0) > 0
    local fx, fy, fz = 1.0, 1.0, 1.0
    if size ~= nil then fx, fy, fz = size.x, size.y, size.z end
    local carried = 0

    for i = 1, landQueueLen do
        local object = landQueue[i]
        landQueue[i] = nil
        if object ~= nil and shaped and size ~= nil
            and not (fx == 1.0 and fy == 1.0 and fz == 1.0) then

            pcall(function()

                local flags = object.activeFlags
                if type(flags) == "number" and flags == 0 then return end
                if land_is_pathed(object) then

                    if landGrew then
                        warp.landPathed = (warp.landPathed or 0) + 1
                    end
                elseif land_derived(object) then

                    if land_carry_home(object, fx, fy, fz) then
                        carried = carried + 1
                    end
                else

                    if landGrew then land_reach_object(object, fy, true) end
                    if land_carry_object(object, fx, fy, fz) then
                        carried = carried + 1
                    end
                end

                if landGrew and land_is_landscape(object)
                    and obj_scale_xyz ~= nil then
                    if land_grow_object(object, math_abs(fx), math_abs(fy),
                        math_abs(fz)) then
                        warp.landGrown = (warp.landGrown or 0) + 1
                    end

                elseif landGrew then
                    land_climb_object(object, math_abs(fx), math_abs(fy),
                        math_abs(fz))
                end
            end)
        end
    end
    landQueueLen = 0
    warp.landLate = (warp.landLate or 0) + carried
    return carried
end

function warp.land_object_frame()
    warp.land_late_frame()
    if landGrew then return false end
    if not landPlaced then return false end
    if landGrowAt == nil then
        landGrowAt = 0
        return false
    end
    landGrowAt = landGrowAt + 1
    if landGrowAt < LAND_GROW_DELAY then return false end
    warp.land_grow()
    return true
end

local ARRIVE_S16_LOW = -32768
local ARRIVE_S16_HIGH = 32767

local function land_s16(value)
    local n = math_floor(value + 0.5)
    if n < ARRIVE_S16_LOW then return ARRIVE_S16_LOW end
    if n > ARRIVE_S16_HIGH then return ARRIVE_S16_HIGH end
    return n
end

local function carry_spawn(m, fx, fy, fz)
    local info = m ~= nil and m.spawnInfo or nil
    local at = info ~= nil and info.startPos or nil
    if at == nil then return false end
    local sx, sy, sz = at.x, at.y, at.z
    if type(sx) ~= "number" or type(sy) ~= "number"
        or type(sz) ~= "number" then return false end
    at.x, at.y, at.z =
        land_s16(sx * fx), land_s16(sy * fy), land_s16(sz * fz)
    return true
end

local function stand_on_floor(m)
    local at = m ~= nil and m.pos or nil
    if at == nil then return false end
    local x, y, z = at.x, at.y, at.z
    if type(x) ~= "number" or type(y) ~= "number"
        or type(z) ~= "number" then return false end
    local height, floor = find_floor(x, y, z)
    if floor == nil or type(height) ~= "number" then return false end
    if y >= height then return false end
    at.y = height

    local obj = m.marioObj
    if obj ~= nil and type(obj.oPosY) == "number" then obj.oPosY = height end

    OF.util.skip_interpolation(obj)
    return true
end

function warp.land_stand()
    if (warp.landShaped or 0) <= 0 then return false end
    return stand_on_floor(gMarioStates ~= nil and gMarioStates[0] or nil)
end

local function arrival_has_floor(fx, fy, fz)
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    local info = me ~= nil and me.spawnInfo or nil
    local at = info ~= nil and info.startPos or nil
    if at == nil then return true end
    local sx, sy, sz = at.x, at.y, at.z
    if type(sx) ~= "number" or type(sy) ~= "number"
        or type(sz) ~= "number" then return true end
    if find_floor == nil then return true end
    local _, floor = find_floor(sx * fx, sy * fy, sz * fz)
    return floor ~= nil
end

function warp.land_arrived()
    return landArrived
end

function warp.land_arrive()

    if (warp.landShaped or 0) <= 0 then return 0 end
    local size = landSize
    if size == nil then return 0 end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return 0 end

    local where = land_where()
    local carried = 0
    if (not landArrived) or where ~= landArrivedWhere then
        landArrived = true
        landArrivedWhere = where

        if not arrival_has_floor(fx, fy, fz) then
            warp.landNoFloor = (warp.landNoFloor or 0) + 1
            return 0
        end

        for i = 0, (MAX_PLAYERS or 1) - 1 do
            local m = gMarioStates ~= nil and gMarioStates[i] or nil
            if carry_spawn(m, fx, fy, fz) then carried = carried + 1 end
        end

        local me = gMarioStates ~= nil and gMarioStates[0] or nil
        local info = me ~= nil and me.spawnInfo or nil
        local at = info ~= nil and info.startPos or nil
        if at ~= nil then
            OF.util.place_player(0, at.x, at.y, at.z)
        end
    end

    if stand_on_floor(gMarioStates ~= nil and gMarioStates[0] or nil) then
        warp.landStood = (warp.landStood or 0) + 1
    end
    return carried
end

local function land_no_water(under)
    if gLevelValues == nil then return false end
    local bottom = gLevelValues.floorLowerLimit
    if type(bottom) ~= "number" then return false end
    return under == bottom
end

local inWater = false

local function land_water(x, z)
    if inWater then return nil end
    if (warp.landShaped or 0) <= 0 then return nil end
    local size = landSize
    if size == nil then return nil end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return nil end
    if fx == 0 or fy == 0 or fz == 0 then return nil end

    local ask = OF.util.binding("find_water_level")
    if ask == nil then return nil end
    inWater = true
    local under = ask(x / fx, z / fz)
    inWater = false
    if type(under) ~= "number" then return nil end
    if land_no_water(under) then return nil end
    return under * fy
end

warp.land_water = land_water

function warp.land_height(y)
    if type(y) ~= "number" then return y end
    local scaled, _, fy = warp.picture_scaled()
    if not scaled then return y end
    return y * fy
end

function warp.land_point(x, y, z)
    local scaled, fx, fy, fz = warp.picture_scaled()
    if not scaled then return x, y, z end
    if type(x) == "number" then x = x * fx end
    if type(y) == "number" then y = y * fy end
    if type(z) == "number" then z = z * fz end
    return x, y, z
end

function warp.land_spot(spot)
    if type(spot) ~= "table" then return spot end
    local x, y, z = warp.land_point(spot.x, spot.y, spot.z)
    local out = {}
    for key, value in pairs(spot) do out[key] = value end
    out.x, out.y, out.z = x, y, z
    return out
end

local landLimits = nil

local landLimited = false

local function land_limits_remember()
    if landLimits ~= nil then return true end
    if gLevelValues == nil then return false end

    landLimits = {}
    local names = {
        lower = "floorLowerLimit",
        misc = "floorLowerLimitMisc",
        shadow = "floorLowerLimitShadow",
        ceiling = "cellHeightLimit",
    }
    for key, field in pairs(names) do

        local value = nil
        if OF.util.asks(OF.rules, "land_limit_base") then
            value = OF.rules.land_limit_base(field)
        end
        if type(value) ~= "number" then value = gLevelValues[field] end
        if type(value) == "number" then

            landLimits[key] = { field = field, base = value,
                sentinel = (field == "cellHeightLimit") }
        end
    end
    return true
end

function warp.apply_limits()

    if not OF.util.asks(OF.rules, "set_land_limit") then return false end
    if not land_limits_remember() then return false end
    local fy = 1.0
    local size = landSize
    if (warp.landShaped or 0) > 0 and size ~= nil then
        fy = size.y
    end
    if fy == 0 then fy = 1.0 end

    local reach = fy
    if reach < 0 then reach = -reach end

    if reach == 1.0 and not landLimited then return false end

    local keys = {}
    for key in pairs(landLimits) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local held = landLimits[key]
        local moved = held.base * reach

        if held.sentinel and moved < held.base then moved = held.base end

        OF.rules.set_land_limit(held.field, land_limit_clamp(land_round(moved)))
    end

    landLimited = (reach ~= 1.0)
    return true
end

function warp.land_limits_base()
    land_limits_remember()
    local out = {}
    if landLimits ~= nil then
        for key, held in pairs(landLimits) do out[key] = held.base end
    end
    return out
end

local LAND_CAMERA = GRAPH_NODE_TYPE_CAMERA or 0x114

local LAND_MARK = 0x57

local landNode = nil

local landUnseen = 0
local LAND_PATIENCE = 4

local function land_camera_here()
    if not OF.util.asks(OF.modifiers, "camera_node") then return nil end
    return OF.modifiers.camera_node()
end

local function land_mark()
    local node = land_camera_here()
    if node == nil then return false end
    local was = node.hookProcess or 0
    if was == 0 then
        node.hookProcess = LAND_MARK
        landNode = node
    elseif was ~= LAND_MARK then
        landNode = nil
    end
    return true
end

local function land_unmark()
    landUnseen = 0
    if landNode == nil then return end
    local node = land_camera_here()
    if node ~= nil and node == landNode
        and (node.hookProcess or 0) == LAND_MARK then
        node.hookProcess = 0
    end
    landNode = nil
end

function warp.picture_scaled()
    if (warp.landShaped or 0) <= 0 then return false end
    local size = landSize
    if size == nil then return false end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return false end
    if fx == 0 or fy == 0 or fz == 0 then return false end
    return true, fx, fy, fz
end

local function land_remember_view(slot)
    if slot == nil then return false end
    landView = landView or {}
    local v = landView
    v[1], v[2], v[3] = slot.m00 or 0, slot.m01 or 0, slot.m02 or 0
    v[4], v[5], v[6] = slot.m10 or 0, slot.m11 or 0, slot.m12 or 0
    v[7], v[8], v[9] = slot.m20 or 0, slot.m21 or 0, slot.m22 or 0
    v[10], v[11], v[12] = slot.m30 or 0, slot.m31 or 0, slot.m32 or 0
    return true
end

function warp.land_view()
    return landView
end

function warp.land_earshot(px, py, pz)
    local v = landView
    if v == nil then return nil end
    if type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number" then
        return nil
    end
    return px * v[1] + py * v[4] + pz * v[7] + v[10],
        px * v[2] + py * v[5] + pz * v[8] + v[11],
        px * v[3] + py * v[6] + pz * v[9] + v[12]
end

local BILLBOARD_FLAGS = (GRAPH_RENDER_BILLBOARD or 0x0004)
    | (GRAPH_RENDER_CYLBOARD or 0x0040)
local FORCE_3D = GRAPH_EXTRA_FORCE_3D or 0x0001

local COUNTER_FLOOR = 0.0001

local COUNTER_CEILING = 4096

local function land_is_billboard(gfx)
    if gfx == nil then return false end
    local node = gfx.node
    local flags = node ~= nil and node.flags or nil
    if type(flags) ~= "number" then return false end
    if flags & BILLBOARD_FLAGS == 0 then return false end

    local shared = gfx.sharedChild
    local extra = shared ~= nil and shared.extraFlags or nil
    if type(extra) == "number" and extra & FORCE_3D ~= 0 then return false end
    return true
end

function warp.billboard_counter(fx, fy, fz, view)
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then
        return nil
    end
    if type(view) ~= "table" then return nil end
    local function axis(a, b, c)
        if type(a) ~= "number" or type(b) ~= "number" or type(c) ~= "number" then
            return nil
        end
        local s = fx * a * a + fy * b * b + fz * c * c
        if s < COUNTER_FLOOR and s > -COUNTER_FLOOR then return 1.0 end
        return 1.0 / s
    end
    local cx = axis(view[1], view[4], view[7])
    local cy = axis(view[2], view[5], view[8])
    local cz = axis(view[3], view[6], view[9])
    if cx == nil or cy == nil or cz == nil then return nil end
    return cx, cy, cz
end

local landHeld = {}
local landHeldCount = 0

local function land_shape_list(list, cx, cy, cz)
    local object = obj_get_first(list)
    local seen = 0
    while object ~= nil and seen < 1200 do
        if landHeldCount >= COUNTER_CEILING then return end
        local header = object.header
        local gfx = header ~= nil and header.gfx or nil
        if land_is_billboard(gfx) then
            local size = gfx.scale
            if size ~= nil then
                local sx, sy, sz = size.x, size.y, size.z
                if type(sx) == "number" and type(sy) == "number"
                    and type(sz) == "number" then
                    local at = landHeldCount * 4
                    landHeld[at + 1] = object
                    landHeld[at + 2] = sx
                    landHeld[at + 3] = sy
                    landHeld[at + 4] = sz
                    landHeldCount = landHeldCount + 1
                    size.x, size.y, size.z = sx * cx, sy * cy, sz * cz
                end
            end
        end
        seen = seen + 1
        object = obj_get_next(object)
    end
end

function warp.land_unshape()
    if landHeldCount == 0 then return 0 end
    local given = 0
    for index = 0, landHeldCount - 1 do
        local at = index * 4
        local object = landHeld[at + 1]
        landHeld[at + 1] = nil
        if object ~= nil then
            local header = object.header
            local gfx = header ~= nil and header.gfx or nil
            local size = gfx ~= nil and gfx.scale or nil
            if size ~= nil then
                size.x = landHeld[at + 2]
                size.y = landHeld[at + 3]
                size.z = landHeld[at + 4]
                given = given + 1
            end
        end
    end
    landHeldCount = 0
    return given
end

function warp.land_shape()
    warp.land_unshape()
    if landView == nil then return 0 end
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return 0 end
    local cx, cy, cz = warp.billboard_counter(fx, fy, fz, landView)
    if cx == nil then return 0 end

    if cx == 1.0 and cy == 1.0 and cz == 1.0 then return 0 end
    for _, list in ipairs(ALL_LISTS) do
        warp.walks = warp.walks + 1
        land_shape_list(list, cx, cy, cz)
    end
    return landHeldCount
end

function warp.land_held()
    return landHeldCount
end

function warp.forget_held()
    for index = 0, landHeldCount - 1 do
        landHeld[index * 4 + 1] = nil
    end
    landHeldCount = 0
end

local function land_scale_slot(slot, fx, fy, fz)
    if slot == nil then return false end
    local ix, iy, iz = 1.0 / fx, 1.0 / fy, 1.0 / fz
    slot.m00 = (slot.m00 or 0) * ix
    slot.m01 = (slot.m01 or 0) * ix
    slot.m02 = (slot.m02 or 0) * ix
    slot.m03 = (slot.m03 or 0) * ix
    slot.m10 = (slot.m10 or 0) * iy
    slot.m11 = (slot.m11 or 0) * iy
    slot.m12 = (slot.m12 or 0) * iy
    slot.m13 = (slot.m13 or 0) * iy
    slot.m20 = (slot.m20 or 0) * iz
    slot.m21 = (slot.m21 or 0) * iz
    slot.m22 = (slot.m22 or 0) * iz
    slot.m23 = (slot.m23 or 0) * iz
    return true
end

local LAND_SCALE_ONE = GRAPH_NODE_TYPE_SCALE or 0x01C
local LAND_SCALE_XYZ = GRAPH_NODE_TYPE_SCALE_XYZ or 0x01D

local LAND_TREE_BUDGET = 64

local landIslandNode = nil

warp.landIslands = 0
warp.landIslandsLeft = 0

local function land_find_scale(first, budget)
    if first == nil or budget <= 0 then return nil, budget end
    local node = first
    repeat
        budget = budget - 1
        if budget < 0 then return nil, 0 end
        local kind = node.type
        if kind == LAND_SCALE_ONE or kind == LAND_SCALE_XYZ then
            return node, budget
        end
        local found
        found, budget = land_find_scale(node.children, budget)
        if found ~= nil then return found, budget end
        node = node.next
    until node == nil or node == first or budget <= 0
    return nil, budget
end

function warp.land_island_uniform(fx, fy, fz)
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then
        return false
    end
    return fx == fy and fy == fz
end

function warp.land_islands_left()
    return warp.landIslandsLeft or 0
end

function warp.land_island(node, fx, fy, fz)
    if node == nil then return false end
    if landIslandNode ~= nil and node == landIslandNode then return false end
    local found = land_find_scale(node.children, LAND_TREE_BUDGET)
    if found == nil then return false end

    local kind = found.type
    if kind == LAND_SCALE_ONE and not warp.land_island_uniform(fx, fy, fz) then
        landIslandNode = node
        warp.landIslandsLeft = (warp.landIslandsLeft or 0) + 1
        return false
    end

    if cast_graph_node == nil then return false end
    local shaped = cast_graph_node(found)

    if shaped == nil then return false end
    local was = shaped.scale
    if was == nil then return false end

    landIslandNode = node
    if kind == LAND_SCALE_XYZ then

        if type(was.x) ~= "number" or type(was.y) ~= "number"
            or type(was.z) ~= "number" then
            return false
        end
        was.x, was.y, was.z = was.x * fx, was.y * fy, was.z * fz
    else
        if type(was) ~= "number" then return false end

        shaped.scale = was * fx
    end
    warp.landIslands = (warp.landIslands or 0) + 1
    return true
end

function warp.forget_island()
    landIslandNode = nil
    warp.landIslands = 0
    warp.landIslandsLeft = 0
end

function warp.landscape_frame(node, matStackIndex)
    if node == nil or node.type ~= LAND_CAMERA then return false end
    landUnseen = 0
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return false end
    if gMatStack == nil or matStackIndex == nil then return false end

    land_remember_view(gMatStack[matStackIndex])
    local done = land_scale_slot(gMatStack[matStackIndex], fx, fy, fz)

    if done then landDrawnAt = OF.util.optional("get_global_timer", nil) end
    if gMatStackPrev ~= nil then
        land_scale_slot(gMatStackPrev[matStackIndex], fx, fy, fz)
    end

    pcall(warp.land_island, node, fx, fy, fz)

    warp.land_shape()
    return done
end

local function land_hear_list(list, count)
    local object = obj_get_first(list)
    local seen = 0
    while object ~= nil and seen < 1200 do
        local header = object.header
        local gfx = header ~= nil and header.gfx or nil
        local pos = gfx ~= nil and gfx.pos or nil
        local ear = gfx ~= nil and gfx.cameraToObject or nil
        if pos ~= nil and ear ~= nil then
            local ex, ey, ez = warp.land_earshot(pos.x, pos.y, pos.z)
            if ex ~= nil then
                ear.x, ear.y, ear.z = ex, ey, ez
                count = count + 1
            end
        end
        seen = seen + 1
        object = obj_get_next(object)
    end
    return count
end

function warp.land_hear()

    if not warp.picture_scaled() then return 0 end
    if landView == nil then return 0 end
    local count = 0
    for _, list in ipairs(LISTS) do
        warp.walks = warp.walks + 1
        count = land_hear_list(list, count)
    end

    for _, list in ipairs(UNSIZED) do
        warp.walks = warp.walks + 1
        count = land_hear_list(list, count)
    end
    return count
end

function warp.reach_counter(fx, fy, fz)
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then
        return nil
    end
    return fx * fx, fy * fy, fz * fz
end

function warp.land_reach()
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return 0 end
    local now = OF.util.optional("get_global_timer", nil)
    if type(now) ~= "number" then return 0 end

    if landDrawnAt ~= now then return 0 end

    if landReachAt == now then return 0 end
    landReachAt = now
    local ux, uy, uz = warp.reach_counter(fx, fy, fz)
    if ux == nil then return 0 end
    local given = 0
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[index]
        local body = m ~= nil and m.marioBodyState or nil
        local torso = body ~= nil and body.torsoPos or nil
        if torso ~= nil and body.updateTorsoTime == now then
            local x, y, z = torso.x, torso.y, torso.z
            if type(x) == "number" and type(y) == "number"
                and type(z) == "number" then
                torso.x, torso.y, torso.z = x * ux, y * uy, z * uz
                given = given + 1
            end
        end
    end
    return given
end

function warp.land_reached()
    return landReachAt
end

function warp.land_watch()
    if not warp.picture_scaled() then
        landUnseen = 0
        if landNode ~= nil then land_unmark() end
        return false
    end
    landUnseen = landUnseen + 1
    if landUnseen <= LAND_PATIENCE then return false end
    landUnseen = 0
    return land_mark()
end

local function forget_level()
    wrote = false
    warp.forget_drift()

    warp.forget_held()
end

warp.forget_level = forget_level

function warp.camera_pitch()
    if gLakituState == nil then return nil end
    local pos, focus = gLakituState.pos, gLakituState.focus
    if pos == nil or focus == nil then return nil end
    local dx = (focus.x or 0) - (pos.x or 0)
    local dy = (focus.y or 0) - (pos.y or 0)
    local dz = (focus.z or 0) - (pos.z or 0)
    local run = math.sqrt(dx * dx + dz * dz)
    if run == 0 and dy == 0 then return nil end
    return fold_s16(atan2s(run, dy))
end

warp.AIM_STEEP = 0x2000

local function index_of_key(key)
    for index, step in ipairs(warp.DIRECTIONS) do
        if step.key == key then return index end
    end
    return 1
end

function warp.scale_name(axis)
    local _, x, y, z = warp.indices()
    local index = x
    if axis == "y" then index = y elseif axis == "z" then index = z end
    local step = stop_at(warp.SCALES, index, SCALE_NEUTRAL)
    return step ~= nil and step.name or "unchanged"
end

function warp.direction_name()
    local dir = warp.direction()
    if dir == nil then return OF.lang.t("down") end
    return dir.name
end

function warp.summary()
    local dir = warp.direction()
    local fx, fy, fz = warp.scale()
    local parts = {}

    if dir ~= nil then
        table.insert(parts, OF.lang.fill("gravity pulls @", dir.name))
    end
    if fx ~= 1.0 or fy ~= 1.0 or fz ~= 1.0 then

        table.insert(parts, OF.lang.fill("the landscape is @ (wide / tall / deep)",
            warp.scale_name("x") .. " / " .. warp.scale_name("y")
                .. " / " .. warp.scale_name("z")))
    end

    local horizon = warp.horizon_stop()
    if dir ~= nil and dir.up ~= true and horizon ~= nil and horizon.share ~= nil
        and horizon.share < 1.0 then
        table.insert(parts, OF.lang.fill("the horizon tips @", horizon.name))
    end

    if dir ~= nil and dir.up == true and not warp.fall_is_owned() then
        table.insert(parts, OF.lang.t("the ceiling is a floor you walk on"))
    end

    if #parts == 0 then return OF.lang.t("The world is the way it was built.") end
    return table.concat(parts, "; ")
end

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType, stepArg)
    warp.step_frame(m, stepType, stepArg)

end)

local CAM_GAP = 800.0

local cameraHold = true

function warp.camera_holds()
    return cameraHold == true
end

function warp.hold_camera(on)
    if on == nil then on = not cameraHold end
    cameraHold = (on == true)
    return cameraHold
end

local function camera_follows_at_a_rate()
    if OF.util.optional("camera_config_is_free_cam_enabled", false) == true then
        return false
    end
    if gFirstPersonCamera ~= nil and gFirstPersonCamera.enabled == true then
        return false
    end
    return true
end

local function camera_is_somebody_else_s()
    if OF.util.asks(OF.camera, "mode_live") and OF.camera.mode_live() then
        return true
    end
    if OF.util.asks(OF.spectate, "mode_live") and OF.spectate.mode_live() then
        return true
    end
    return false
end

function warp.camera_frame()

    if not cameraHold then return false end

    if gLakituState == nil or gLakituState.pos == nil then return false end
    if gLakituState.focus == nil then return false end

    if not camera_follows_at_a_rate() then return false end

    local _, fy = warp.scale()
    if type(fy) ~= "number" then return false end
    local tall = math.abs(fy)

    if not (tall > 1.0) then return false end

    if camera_is_somebody_else_s() then return false end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end

    local gap = gLakituState.pos.y - m.pos.y
    local most = CAM_GAP * tall
    local over = 0
    if gap > most then over = most - gap
    elseif gap < -most then over = -most - gap
    else return false end

    gLakituState.pos.y = gLakituState.pos.y + over
    gLakituState.focus.y = gLakituState.focus.y + over

    if gLakituState.curPos ~= nil then
        gLakituState.curPos.y = gLakituState.curPos.y + over
    end
    if gLakituState.curFocus ~= nil then
        gLakituState.curFocus.y = gLakituState.curFocus.y + over
    end
    return true
end

hook_event(HOOK_UPDATE, function()
    warp.uncull_frame()

    warp.far_frame()
    warp.land_watch()

    warp.land_area_watch()

    warp.land_object_frame()

    warp.settle_shape()

    warp.camera_frame()
end)

hook_event(HOOK_ON_ADD_SURFACE, function(surface, dynamic)
    warp.shape_surface(surface, dynamic)

    if not dynamic then warp.apply_limits() end
end)

hook_event(HOOK_ON_FIND_WATER_LEVEL, function(x, z)
    return warp.land_water(x, z)
end)

hook_event(HOOK_ON_GEO_PROCESS_CHILDREN, function(node, matStackIndex)
    warp.landscape_frame(node, matStackIndex)
end)

hook_event(HOOK_ON_HUD_RENDER, function()

    warp.land_unshape()
    warp.land_hear()

    warp.land_reach()
end)

hook_event(HOOK_ON_PLAY_MODE_UPDATE, function()
    warp.tilt_frame()
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    warp.body_frame(m)
end)

hook_event(HOOK_ON_WARP, function()
    warp.land_arrive()
end)

hook_event(HOOK_ON_OBJECT_LOAD, function(object)
    warp.land_watch_object(object)
end)

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    return warp.stand_floor_class(m, floorClass)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    forget_level()

    warp.land_place()

    warp.land_stand()

    warp.forget_tilt()

    warp.forget_bodies()
end)

hook_event(HOOK_ON_CLEAR_AREAS, function()

    warp.forget_land()

    warp.forget_island()

    warp.apply_limits()
end)

local function next_stop(index, list)
    if #list == 0 then return index end
    index = index + 1
    if index > #list then index = 1 end
    return index
end

local function slider_stop(step, list)
    return OF.util.clamp(math.floor(step or 1), 1, #list)
end

local function ladder_row(panel, key, name, helpText, stopName, index, list,
                          apply)
    local shown = OF.lang.t(name)
    if stopName ~= nil and stopName ~= "" then
        shown = shown .. ": " .. OF.lang.t(stopName)
    end

    local built = panel.with_help(
        panel.gated_row(key, shown, 255, 255, 255, function()
            OF.util.report(apply(next_stop(index, list)))
        end), helpText)

    return panel.with_slider(built, index - 1, #list - 1, function(step)
        OF.util.report(apply(slider_stop((step or 0) + 1, list)))
    end)
end

function warp.build_page(panel)
    local rows = {}
    local _, x, y, z = warp.indices()

    table.insert(rows, panel.label_row(warp.summary()))

    table.insert(rows, panel.header_row(OF.lang.t("The size of the landscape")))

    local pending = warp.land_pending()

    local reloadG = pending and 215 or 255
    local reloadB = pending and 0 or 255

    table.insert(rows, panel.gated_row("warp_lobby",
        pending and OF.lang.t("Reload this map to take the new size")
            or OF.lang.t("Reload this map"),
        255, reloadG, reloadB,
        function()
            OF.util.report(OF.net.reload_level())
        end))

    local shaped = warp.landShaped or 0
    local clamped = warp.landClamped or 0
    local dropped = warp.landDropped or 0
    local roofs = warp.landRoofs or 0
    local notes = {}
    if pending then
        notes[#notes + 1] = OF.lang.t(
            "The ground is only re-shaped as a course loads, so this lands")
        notes[#notes + 1] = OF.lang.t(
            "on the next level rather than on the one you are in.")
    else
        notes[#notes + 1] = OF.lang.t(
            "This course is standing at the size below.")
    end

    if (warp.landNoFloor or 0) > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.t(
            "Nothing under the spawn at this size, so it was left where it was.")
    end

    if warp.land_islands_left() > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.t(
            "One part of this course draws its own ground and needs all three the same.")
    end

    if (warp.landPathed or 0) > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.fill(
            "@ platforms still travel the route the level built, at its own size.",
            tostring(warp.landPathed or 0))
    end

    if clamped > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.fill(
            "@ far corners were too far out to hold and were cut back.",
            tostring(clamped))
    end

    if dropped > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.fill(
            "@ walls had no thickness left and were taken out of it.",
            tostring(dropped))
    end

    if roofs > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.fill(
            "@ ceilings had no room left under them and came out too.",
            tostring(roofs))
    end
    if shaped > 0 and #notes < 3 then
        notes[#notes + 1] = OF.lang.fill(
            "Ground re-shaped on the way in: @.", tostring(shaped))
    end
    if shaped == 0 and not pending and #notes < 3 then
        notes[#notes + 1] = OF.lang.t(
            "Move a slider and this row takes the level round again.")
    end
    for _, note in ipairs(notes) do
        table.insert(rows, panel.label_row("   " .. note))
    end

    local axes = {
        { field = "x", index = x, label = "Wide (x)" },
        { field = "y", index = y, label = "Tall (y)" },
        { field = "z", index = z, label = "Deep (z)" },
    }

    for _, axis in ipairs(axes) do

        local list, offset = warp.ladder(axis.field)

        local help =
            "four times over mirrored, through flat, to four times over - the big steps put the camera in the scenery, and a distance built into the game never scales"
        if offset > 0 then
            help =
                "a quarter to four times over - width and depth are never mirrored and never flattened"
        end
        table.insert(rows, ladder_row(panel, "vision", axis.label, help,
            warp.scale_name(axis.field), axis.index - offset, list,
            function(stop) return warp.set(axis.field, stop + offset) end))
    end

    table.insert(rows, panel.with_help(
        panel.row(panel.tick(warp.camera_holds(),
            OF.lang.t("The size may steady your camera")),
            255, 255, 255, function() warp.hold_camera() end),
        "in a tall course the game's camera cannot follow a fall at its own rate - untick and it is never touched"))

    table.insert(rows, panel.label_row("   " .. OF.lang.t(
        "The course changes shape - the picture and what you stand")))
    table.insert(rows, panel.label_row("   " .. OF.lang.t(
        "on, together. You, the enemies and the coins keep their")))
    table.insert(rows, panel.label_row("   " .. OF.lang.t(
        "size and their reach, and go where the ground goes.")))

    if warp.is_on() then
        table.insert(rows, panel.gated_row("vision",
            OF.lang.t("Put the world back"), 255, 140, 90, function()
                OF.util.report(warp.clear())
            end))
    end

    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.warp == nil then
        panel.PAGES.warp = {
            title = "The size of the landscape", tab = "room", up = "room",
            build = function() return warp.build_page(panel) end,
        }
    end
end)

function warp.loaded()
    return true
end
