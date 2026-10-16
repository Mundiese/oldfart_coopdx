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

function warp.stands_down()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

function warp.code(raw)
    local value = gGlobalSyncTable[warp.KEY]
    if type(value) ~= "string" then return nil end
    if #value ~= WIDTH then return nil end
    if not raw and warp.stands_down() then return nil end
    return value
end

local function stop_at(list, index, fallback)
    if type(index) ~= "number" then return list[fallback] end
    if index < 1 or index > #list then return list[fallback] end
    return list[index]
end

function warp.published_direction(raw)
    local code = warp.code(raw)
    if code == nil then return nil end
    local index = from_code(code:sub(1, 1), 1)
    if index <= 1 then return nil end
    local step = stop_at(warp.DIRECTIONS, index, 1)
    if step == nil or step.key == "down" then return nil end
    return step
end

function warp.up_step()
    return stop_at(warp.DIRECTIONS, warp.direction_index("up"), 1)
end

function warp.direction(raw)
    local step = warp.published_direction(raw)
    if step ~= nil or raw then return step end
    if OF.util.asks(OF.modifiers, "upside_here") and OF.modifiers.upside_here() then
        return warp.up_step()
    end
    return nil
end

function warp.direction_of(m)
    local index = m ~= nil and m.playerIndex or 0
    if type(index) ~= "number" or index == 0 then return warp.direction() end
    local step = warp.published_direction(false)
    if step ~= nil then return step end
    if OF.util.asks(OF.modifiers, "upside_of") and OF.modifiers.upside_of(index) then
        return warp.up_step()
    end
    return nil
end

function warp.scale(raw)
    local code = warp.code(raw)
    if code == nil then return 1.0, 1.0, 1.0 end

    local x = stop_at(warp.SCALES,
        legal_stop("x", from_code(code:sub(2, 2), SCALE_NEUTRAL)), SCALE_NEUTRAL)
    local y = stop_at(warp.SCALES, from_code(code:sub(3, 3), SCALE_NEUTRAL), SCALE_NEUTRAL)
    local z = stop_at(warp.SCALES,
        legal_stop("z", from_code(code:sub(4, 4), SCALE_NEUTRAL)), SCALE_NEUTRAL)
    return x.factor, y.factor, z.factor
end

function warp.indices(raw)
    local code = warp.code(raw)
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

    if horizon == HORIZON_DEFAULT and OF.util.asks(OF.modifiers, "upside_horizon") then
        local wanted = OF.modifiers.upside_horizon()
        if wanted ~= nil then
            for index, entry in ipairs(warp.HORIZONS) do
                if entry.key == wanted then horizon = index end
            end
        end
    end
    return stop_at(warp.HORIZONS, horizon, HORIZON_DEFAULT)
end

function warp.horizon_turns()
    local stop = warp.horizon_stop()
    return stop ~= nil and (stop.share or 0) > 0
end

function warp.is_on()
    local dir, x, y, z = warp.indices(true)
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

hook_event(HOOK_UPDATE, function()
    ready()
end)

function warp.set(field, index)

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round or a run has the world's size out on loan."
    end

    if not OF.util.is_host() then
        return OF.net.host_does("world", index, nil, field)
    end
    local dir, x, y, z, horizon = warp.indices(true)
    if field == "direction" then dir = index
    elseif field == "x" then x = index
    elseif field == "y" then y = index
    elseif field == "z" then z = index
    elseif field == "horizon" then horizon = index
    else return false, "That is not one of the world's dials." end
    return write(dir, x, y, z, horizon)
end

function warp.clear()

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round or a run has the world's size out on loan."
    end

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
    local dir, x, y, z, horizon = warp.indices(true)
    local fx, fy, fz = warp.scale(true)
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

    local wasDir, wasX, wasY, wasZ, wasHorizon = warp.indices(true)
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
    local dir = warp.direction_of(m)
    if dir == nil then return false end

    local own = m == nil or (m.playerIndex or 0) == 0
    if own and warp.fall_is_owned() then return false end
    if dir.up == true then
        if m == nil or m.pos == nil then return false end

        local height, ceil = find_ceil(m.pos.x, m.pos.y, m.pos.z)
        return ceil ~= nil and height > m.pos.y
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

    if OF.util.asks(OF.venues, "holds_camera") and OF.venues.holds_camera() then
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
    local dir = warp.direction_of(m)
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

        if (m == nil or (m.playerIndex or 0) == 0) and warp.fall_is_owned() then
            return 0, 0, stood
        end

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

    if bodyPitch[index] == nil and bodyRoll[index] == nil
        and not bodyHidden[index] and warp.direction_of(m) == nil then
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

warp.landDeathKept = 0

warp.landRoofs = 0

warp.landStood = 0

warp.landNoFloor = 0

warp.landFlightArrivals = 0

local LAND_INTANGIBLE = SURFACE_FLAG_INTANGIBLE or 4

local STAND_HEIGHT = 160.0

local function land_cramped(fy)
    if fy < 0 then fy = -fy end
    return (2 * VERTEX_MAX) * fy <= STAND_HEIGHT
end

local landCode = nil
local landSize = nil

warp.REFUSED = {}

do

local function refuse_level(level, reason)
    if type(level) ~= "number" then return end
    warp.REFUSED[level] = reason
end

refuse_level(LEVEL_NONE, "not a level: the number a load reports before it has landed")

refuse_level(LEVEL_UNKNOWN_1, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_2, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_3, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_32, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_35, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_37, "a stub: no level script, no area, no terrain")
refuse_level(LEVEL_UNKNOWN_38, "a stub: no level script, no area, no terrain")

refuse_level(LEVEL_ENDING, "a screen, not a place: the ending has no terrain and nobody walks in it")

end

function warp.level_refused(level)
    if type(level) ~= "number" then return nil end
    return warp.REFUSED[level]
end

local landLevelNext = nil

local function land_between_levels()
    local mode = OF.util.optional("get_current_play_mode", PLAY_MODE_NORMAL or 0)
    if type(mode) ~= "number" then return false end
    return mode == (PLAY_MODE_CHANGE_LEVEL or 4)
end

local landCredits = false

function warp.forget_refusal()
    landLevelNext = nil
    warp.landAreaNext = nil
    landCredits = false
end

function warp.land_level_next()
    return landLevelNext
end

function warp.land_credits()
    return landCredits
end

do
local CREDITS_ACT = 99
local creditsHeard = false

local function banks_held_elsewhere()
    local held = 0
    if OF.modifiers ~= nil and type(OF.modifiers.quietHeld) == "number" then
        held = held | OF.modifiers.quietHeld
    end
    if OF.celebrate ~= nil and type(OF.celebrate.hush_left) == "function"
        and OF.celebrate.hush_left() > 0 then

        local background = SOUND_BANKS_BACKGROUND
        if type(background) ~= "number" then
            background = ((1 << (SOUND_BANK_COUNT or 13)) - 1)
                & ~((1 << (SOUND_BANK_ACTION or 0))
                    | (1 << (SOUND_BANK_MARIO_VOICE or 2))
                    | (1 << (SOUND_BANK_MENU or 7))
                    | (1 << (SOUND_BANK_LUIGI_VOICE or 10))
                    | (1 << (SOUND_BANK_WARIO_VOICE or 11))
                    | (1 << (SOUND_BANK_TOAD_VOICE or 12)))
        end
        held = held | background
    end
    return held
end

function warp.in_credits()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.currActNum == CREDITS_ACT
end

function warp.credits_voices(levelNum)
    if warp.in_credits() then
        creditsHeard = true
        return false
    end
    if not creditsHeard then return false end
    if levelNum == nil and gNetworkPlayers[0] ~= nil then
        levelNum = gNetworkPlayers[0].currLevelNum
    end
    if LEVEL_ENDING ~= nil and levelNum == LEVEL_ENDING then return false end
    creditsHeard = false
    local all = SOUND_BANKS_ALL
    if type(all) ~= "number" then all = (1 << (SOUND_BANK_COUNT or 13)) - 1 end
    local mask = all & ~banks_held_elsewhere()
    if mask == 0 then return false end

    OF.util.optional("sound_banks_enable", nil, 0, mask)
    return true
end

function warp.credits_heard()
    return creditsHeard
end
end

function warp.land_warp_seen(destLevel, destWarpNode, destArea)
    if type(destLevel) == "number" then
        landLevelNext = destLevel
    else
        landLevelNext = nil
    end

    warp.landAreaNext = type(destArea) == "number" and destArea or nil
    landCredits = (type(destWarpNode) == "number"
        and destWarpNode >= (WARP_NODE_CREDITS_MIN or 0xF8))
end

do
warp.DEATH_LOOP = { lives = 3, frames = 30 * 5 }
warp.life = warp.life or { start = nil, dead = false, bubbled = false, short = 0, key = nil }
warp.loopSteps = warp.loopSteps or {}

local function life_clock()
    return OF.util.optional("get_global_timer", 0) or 0
end

function warp.life_begin()
    local life = warp.life
    life.start, life.dead, life.bubbled = life_clock(), false, false
end

function warp.life_frame(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local life = warp.life
    if not life.dead then return end
    if m.action == ACT_BUBBLED then
        life.bubbled = true
    elseif life.bubbled then
        warp.life_begin()
    end
end

local function toward_one(factor)
    for index, step in ipairs(warp.SCALES) do
        if step.factor == factor then
            if index < SCALE_NEUTRAL then return warp.SCALES[index + 1].factor end
            if index > SCALE_NEUTRAL then return warp.SCALES[index - 1].factor end
            return factor
        end
    end
    return 1.0
end
warp.toward_one = toward_one

function warp.loop_step(fx, fy, fz)
    if fy < 0 then return fx, 1.0, fz end
    local narrow = math.min(fx, fz)
    if narrow > 0 and math.abs(fy) / narrow > 1.0 then
        if narrow < 1.0 then
            if fx == narrow then fx = toward_one(fx) end
            if fz == narrow then fz = toward_one(fz) end
            return fx, fy, fz
        end
        return fx, toward_one(fy), fz
    end
    if math.abs(fy) < 1.0 then return fx, toward_one(fy), fz end
    if fx > 1.0 or fz > 1.0 then
        local wide = math.max(fx, fz)
        if fx == wide then fx = toward_one(fx) end
        if fz == wide then fz = toward_one(fz) end
    end
    return fx, fy, fz
end

warp.LEVEL_FLOORS = {
    { level = "LEVEL_CASTLE_GROUNDS", area = 1, xz = 1.0 },
    { level = "LEVEL_TTM", area = 1, xz = 1.0 },
    { level = "LEVEL_CASTLE", area = 1, xz = 0.5, y = 0.5 },
    { level = "LEVEL_CASTLE", area = 2, y = 0.5 },
    { level = "LEVEL_CASTLE", area = 3, xz = 0.5, y = 0.5 },
    { level = "LEVEL_BOB", area = 1, xz = 0.5 },
    { level = "LEVEL_WF", area = 1, xz = 0.5 },
    { level = "LEVEL_JRB", area = 1, xz = 0.5 },
    { level = "LEVEL_SL", area = 2, xz = 0.5, y = 0.5 },
    { level = "LEVEL_TTM", area = 2, xz = 0.5, y = 0.5 },
    { level = "LEVEL_THI", area = 1, xz = 0.5 },
    { level = "LEVEL_BITFS", area = 1, xz = 0.5 },
    { level = "LEVEL_COTMC", area = 1, xz = 0.5 },
    { level = "LEVEL_WMOTR", area = 1, xz = 0.5 },
    { level = "LEVEL_RR", area = 1, y = 0.5 },
    { level = "LEVEL_PSS", area = 1, y = 0.5 },
}

warp.LEVEL_CEILINGS = {
    { level = "LEVEL_CASTLE", area = 3, most = 2.0 },
    { level = "LEVEL_DDD", area = 1, most = 2.0 },
    { level = "LEVEL_PSS", area = 1, most = 2.0 },
    { level = "LEVEL_TTM", area = 3, most = 2.0 },
}

function warp.level_ceiling(level, area)
    if type(level) ~= "number" then return nil end
    local most = nil
    for _, row in ipairs(warp.LEVEL_CEILINGS) do
        if _G[row.level] == level and (area == nil or row.area == area) then
            if most == nil or row.most < most then most = row.most end
        end
    end
    return most
end

function warp.land_level_factors(level, area, code, fx, fy, fz)
    if type(level) == "number" then
        local xz, y = nil, nil
        for _, row in ipairs(warp.LEVEL_FLOORS) do
            if _G[row.level] == level and (area == nil or row.area == area) then
                if row.xz ~= nil and (xz == nil or row.xz > xz) then xz = row.xz end
                if row.y ~= nil and (y == nil or row.y > y) then y = row.y end
            end
        end
        if xz ~= nil then
            if fx < xz then fx = xz end
            if fz < xz then fz = xz end
        end
        if y ~= nil and math.abs(fy) < y then
            fy = fy < 0 and -y or y
        end
        local stepped = warp.loopSteps[level]
        if stepped ~= nil and stepped.code == code then
            fx, fy, fz = stepped.x, stepped.y, stepped.z
        end

        local most = warp.level_ceiling(level, area)
        if most ~= nil then
            if math.abs(fx) > most then fx = fx < 0 and -most or most end
            if math.abs(fy) > most then fy = fy < 0 and -most or most end
            if math.abs(fz) > most then fz = fz < 0 and -most or most end
        end
    end
    return fx, fy, fz
end

function warp.note_death(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local life = warp.life

    if life.dead then return false end
    life.dead = true
    if (warp.landShaped or 0) <= 0 then
        life.short = 0
        return false
    end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local level = np ~= nil and np.currLevelNum or nil
    local area = np ~= nil and np.currAreaIndex or nil
    if type(level) ~= "number" then return false end
    local code = warp.code(true) or ""
    local key = tostring(level) .. ":" .. tostring(area) .. ":" .. code
    local alive = life.start ~= nil and (life_clock() - life.start) or nil
    if life.key ~= key then life.short = 0 end
    life.key = key
    if alive == nil or alive >= warp.DEATH_LOOP.frames then
        life.short = 0
        return false
    end
    life.short = life.short + 1
    if life.short < warp.DEATH_LOOP.lives then return false end
    life.short = 0
    return warp.loop_step_level(level, area, code)
end

function warp.loop_step_level(level, area, code)
    local fx, fy, fz = warp.land_level_factors(level, area, code, warp.scale(true))
    local nx, ny, nz = warp.loop_step(fx, fy, fz)
    if nx == fx and ny == fy and nz == fz then return false end
    warp.loopSteps[level] = { code = code, x = nx, y = ny, z = nz }
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("This level kept killing you - it now loads at @ for you", "warn", 6,
            string.format("%g x %g x %g", nx, ny, nz))
    end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local act = np ~= nil and np.currActNum or 0
    OF.util.optional("warp_to_warpnode", nil, level, 1, act, 0x0A)
    return true
end

hook_event(HOOK_ON_DEATH, function(m)
    warp.note_death(m)
end)
end

function warp.land_refuses()
    if landCredits then
        return true, "credits"
    end
    if land_between_levels() then
        return true, "screen"
    end

    if warp.level_refused(landLevelNext) ~= nil then
        return true, "level"
    end
    return false, nil
end

function warp.land_refused()
    local size = landSize
    return size ~= nil and size.refused == true
end

function warp.land_refused_why()
    local size = landSize
    if size == nil then return nil end
    return size.why
end

warp.landRefused = 0

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

        local fx, fy, fz = warp.land_level_factors(landLevelNext, warp.landAreaNext, code,
            warp.scale())

        local refused, why = warp.land_refuses()
        landCode = code
        landSize = { x = fx, y = fy, z = fz, cramped = land_cramped(fy),
            refused = refused == true, why = why,
            level = landLevelNext, area = warp.landAreaNext }
    end

    if landSize.refused then
        warp.landRefused = warp.landRefused + 1
        return false
    end

    local fx, fy, fz = landSize.x, landSize.y, landSize.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return false end

    local v1, v2, v3 = surface.vertex1, surface.vertex2, surface.vertex3

    if fy > 0 and fy < 1.0 and surface.type == SURFACE_DEATH_PLANE
        and v1 ~= nil and v2 ~= nil and v3 ~= nil
        and math_max(v1.y or 0, v2.y or 0, v3.y or 0) <= 0 then
        fy = 1.0
        warp.landDeathKept = (warp.landDeathKept or 0) + 1
    end
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

    if warp.forget_seams ~= nil then warp.forget_seams() end
    warp.landClamped = 0
    warp.landShaped = 0

    warp.landRefused = 0
    warp.landDropped = 0
    warp.landDeathKept = 0
    warp.landRoofs = 0
    landCode = nil
    landSize = nil
    landPlaced = false
    landArrived = false
    landArrivedWhere = nil
    warp.landStood = 0
    warp.landNoFloor = 0

    warp.landFlightArrivals = 0

    warp.landFlights = 0

    warp.landFlightRefusals = 0
    warp.landFlightWhy = nil

    warp.landFlightSeen = 0

    warp.landArrivalsKept = 0

    warp.landGrown = 0

    warp.landPressed = 0
    warp.landClimbed = 0

    warp.landWarped = 0

    warp.landCulled = 0
    warp.landCullRefused = 0

    warp.landClimbStubs = 0

    warp.landPoleTops = 0
    warp.landLate = 0

    warp.landPathed = 0
    warp.landReached = 0

    warp.landSeated = 0

    warp.landTravel = 0
    warp.landTravelRefused = 0

    warp.landMotion = 0
    warp.landMotionRefused = 0

    warp.landFixtures = 0
    warp.landFixtureRefused = 0

    warp.landBombRefused = 0

    warp.landRouted = 0
    warp.landRouteRefused = 0

    warp.landRouteCapped = 0

    warp.landDoors = 0

    warp.landLeaves = 0

    warp.landLids = 0

    warp.landGates = 0
    warp.landQueueFull = 0
    landGrew = false
    landGrowAt = nil
    landQueue = {}
    landQueueLen = 0
    landLoaded = nil

    warp.landSizedAt = setmetatable({}, { __mode = "k" })

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

local land_seat_object
do

local LAND_REACHABLE = {}

warp.landReachableMissing = 0

for _, name in ipairs({

    "id_bhvExclamationBox", "id_bhvHiddenObject", "id_bhvBreakableBox",

    "id_bhvYellowCoin", "id_bhvOneCoin", "id_bhvRedCoin",
    "id_bhvHiddenBlueCoin", "id_bhv1Up", "id_bhv1upJumpOnApproach",

    "id_bhvStar", "id_bhvHiddenStar", "id_bhvHiddenRedCoinStar",
    "id_bhvBowserCourseRedCoinStar",
}) do
    local id = _G[name]
    if type(id) == "number" then
        LAND_REACHABLE[#LAND_REACHABLE + 1] = id
    else
        warp.landReachableMissing = warp.landReachableMissing + 1
    end
end

local function land_is_reachable(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil then return false end
    local ok, reachable = pcall(function()
        for _, id in ipairs(LAND_REACHABLE) do
            if obj_has_behavior_id(object, id) ~= 0 then return true end
        end
        return false
    end)
    return ok and reachable
end

warp.land_is_reachable = land_is_reachable
warp.LAND_REACHABLE = LAND_REACHABLE

local LAND_REACH_MAX = 630.0 + STAND_HEIGHT

warp.landSeated = 0

warp.LAND_CLIMB_TOPS = { bhvTree = 500, bhvGiantPole = 2100, bhvKoopaFlag = 700,
    bhvDDDPole = 800 }
local CLIMB_TOP_REACH = 300.0

function warp.land_climb_top_under(object, vanillaY)
    local size = landSize
    if size == nil or object == nil or obj_get_first == nil then return nil end
    local ax, ay, az = math_abs(size.x), math_abs(size.y), math_abs(size.z)
    if ax == 0 or ay == 0 or az == 0 then return nil end
    local bestS, bestV = nil, nil
    local climb = obj_get_first(OBJ_LIST_POLELIKE)
    local seen = 0
    while climb ~= nil and seen < 256 do
        local h = nil
        for name, height in pairs(warp.LAND_CLIMB_TOPS) do
            local id = _G["id_" .. name]
            if id ~= nil and obj_has_behavior_id(climb, id) ~= 0 then h = height end
        end
        if h == nil and id_bhvPoleGrabbing ~= nil and obj_has_behavior_id(climb, id_bhvPoleGrabbing) ~= 0 then
            h = math_floor((tonumber(climb.oBehParams) or 0) / 0x10000) % 0x100 * 10
        end
        if h ~= nil and h > 0 then
            local dx = (climb.oPosX - object.oPosX) / ax
            local dz = (climb.oPosZ - object.oPosZ) / az
            if dx * dx + dz * dz <= CLIMB_TOP_REACH * CLIMB_TOP_REACH then
                local topV = climb.oPosY / ay + h
                if topV <= vanillaY and (bestV == nil or topV > bestV) then
                    bestV, bestS = topV, climb.oPosY + h * ay
                end
            end
        end
        seen = seen + 1
        climb = obj_get_next(climb)
    end
    return bestS, bestV
end

function land_seat_object(object, vanillaY, fy)
    if object == nil then return false end
    if find_floor == nil then return false end
    if type(vanillaY) ~= "number" or type(fy) ~= "number" then return false end

    if fy == 1.0 then return false end

    if fy == 0 then return false end
    if land_cramped(fy) then return false end
    if not land_is_reachable(object) then return false end
    local ok, wrote = pcall(function()
        local x, y, z = object.oPosX, object.oPosY, object.oPosZ
        if type(x) ~= "number" or type(y) ~= "number"
            or type(z) ~= "number" then return false end

        local topS, topV = warp.land_climb_top_under(object, vanillaY)
        if topS ~= nil and vanillaY - topV <= LAND_REACH_MAX then
            local seat = topS + (vanillaY - topV)
            if seat == y then return false end
            local delta = seat - y
            object.oPosY = seat
            if type(object.oHomeY) == "number" and object.oHomeY == y then object.oHomeY = seat end
            local gfx = object.header ~= nil and object.header.gfx or nil
            if gfx ~= nil and gfx.pos ~= nil and type(gfx.pos.y) == "number" then
                gfx.pos.y = gfx.pos.y + delta
            end
            return true
        end
        local height, floor = find_floor(x, y, z)

        if floor == nil or type(height) ~= "number" then return false end
        local twin = height / fy
        local gap = math_abs(vanillaY - twin)
        if gap > LAND_REACH_MAX then return false end
        local seat = height + gap
        if seat == y then return false end
        local delta = seat - y
        object.oPosY = seat

        local hy = object.oHomeY
        if type(hy) == "number" and hy == y then object.oHomeY = seat end

        local header = object.header
        local gfx = header ~= nil and header.gfx or nil
        local at = gfx ~= nil and gfx.pos or nil
        if at ~= nil and type(at.y) == "number" then at.y = at.y + delta end
        return true
    end)
    if not (ok and wrote) then return false end
    warp.landSeated = (warp.landSeated or 0) + 1
    return true
end

end

warp.land_seat_object = land_seat_object

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
    local seats, seatsY = {}, {}
    for _, list in ipairs(LISTS) do
        warp.walks = warp.walks + 1
        local object = obj_get_first(list)

        local seen = 0
        while object ~= nil and seen < 1200 do

            local wasY = object.oPosY
            if land_carry_object(object, fx, fy, fz) then
                moved = moved + 1
                seats[#seats + 1] = object
                seatsY[#seatsY + 1] = wasY
            end
            seen = seen + 1
            object = obj_get_next(object)
        end
    end

    for i = 1, #seats do land_seat_object(seats[i], seatsY[i], fy) end
    return moved
end

function warp.land_pending()

    if warp.land_refused() then return false end
    if warp.land_refuses() then return false end

    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local lvl = landSize ~= nil and landSize.level or (np ~= nil and np.currLevelNum or nil)
    local ar = landSize ~= nil and landSize.area or (np ~= nil and np.currAreaIndex or nil)
    local fx, fy, fz = warp.land_level_factors(lvl, ar, warp.code() or "", warp.scale())

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

    warp.apply_warps()

    warp.apply_whirlpools()
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

function warp.land_signed_height(ay)
    if type(ay) ~= "number" then return ay end
    local size = landSize
    if size ~= nil and type(size.y) == "number" and size.y < 0 then
        return -math_abs(ay)
    end
    return ay
end

warp.BODY_LISTS = { OBJ_LIST_GENACTOR, OBJ_LIST_PUSHABLE, OBJ_LIST_DESTRUCTIVE }
warp.BODY_BEHAVIOURS = {

    "bhvMrIBody",

    "bhvSmallWhomp", "bhvWhompKingBoss",

    "bhvEyerokHand",
}

function warp.land_body_ids()
    if warp.bodyIds ~= nil then return warp.bodyIds end
    local ids = {}
    for _, name in ipairs(warp.BODY_BEHAVIOURS) do
        local id = _G["id_" .. name]
        if type(id) == "number" then ids[#ids + 1] = id end
    end
    warp.bodyIds = ids
    return ids
end

function warp.land_is_body(object)
    if object == nil then return false end
    if type(get_object_list_from_behavior) == "function" then
        local ok, list = pcall(function() return get_object_list_from_behavior(object.behavior) end)
        if ok and type(list) == "number" then
            for _, body in ipairs(warp.BODY_LISTS) do
                if body ~= nil and list == body then return true end
            end
        end
    end
    if obj_has_behavior_id == nil then return false end
    for _, id in ipairs(warp.land_body_ids()) do
        local ok, is = pcall(obj_has_behavior_id, object, id)
        if ok and is ~= 0 and is ~= false and is ~= nil then return true end
    end
    return false
end

function warp.land_height_factor()
    local size = landSize
    if (warp.landShaped or 0) <= 0 or size == nil or size.refused then return 1.0 end
    if type(size.y) ~= "number" or size.y == 0 then return 1.0 end
    return math_abs(size.y)
end

local function land_size_object(object, ax, ay, az, kept)

    if not kept and warp.land_is_body(object) then return false end
    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local was = gfx ~= nil and gfx.scale or nil
    local sx, sy, sz = 1.0, 1.0, 1.0
    if was ~= nil and type(was.x) == "number" and type(was.y) == "number"
        and type(was.z) == "number" then
        sx, sy, sz = was.x, was.y, was.z
    end
    obj_scale_xyz(object, sx * ax, sy * ay, sz * az)

    local now = gfx ~= nil and gfx.scale or nil
    if now ~= nil then warp.landSizedAt[object] = now.x end
    return true
end

warp.landSizedAt = setmetatable({}, { __mode = "k" })

function warp.loaded_size()
    if (warp.landShaped or 0) <= 0 then return nil end
    return landSize
end

function warp.land_was_sized(object)
    if object == nil then return false end
    local was = warp.landSizedAt[object]
    if was == nil then return false end
    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local size = gfx ~= nil and gfx.scale or nil
    return size ~= nil and size.x == was
end

function warp.land_attach_offset(dx, dy, dz, fx, fy, fz)
    if type(dx) ~= "number" or type(dy) ~= "number" or type(dz) ~= "number"
        or type(fx) ~= "number" or type(fy) ~= "number"
        or type(fz) ~= "number" then
        return nil
    end
    return dx * math_abs(fx), dy * fy, dz * math_abs(fz)
end

warp.landFixtures = 0
warp.landFixtureRefused = 0

function warp.land_attach_size(object, ax, ay, az)
    if object == nil then return false end
    if obj_scale_xyz == nil then return false end
    local ok, sized = pcall(land_size_object, object, ax, ay, az)
    if not ok or sized == false then return false end
    warp.landFixtures = (warp.landFixtures or 0) + 1
    return true
end

warp.LAND_FIXTURES = {}
for _, id in ipairs({ id_bhvClockMinuteHand, id_bhvClockHourHand,
    id_bhvDecorativePendulum }) do

    if id ~= nil then
        warp.LAND_FIXTURES[#warp.LAND_FIXTURES + 1] = id
    end
end

function warp.land_fixture_object(object, ax, ay, az)
    if object == nil then return false end
    if obj_has_behavior_id == nil then return false end
    local matched = false
    for _, id in ipairs(warp.LAND_FIXTURES) do
        local ok, is = pcall(obj_has_behavior_id, object, id)
        if ok and is ~= 0 and is ~= false and is ~= nil then
            matched = true
            break
        end
    end
    if not matched then return false end
    if not warp.land_attach_size(object, ax, ay, az) then
        warp.landFixtureRefused = (warp.landFixtureRefused or 0) + 1
        return false
    end
    return true
end

warp.landBombRefused = 0

function warp.land_bomb_refuse(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil or id_bhvBowserBomb == nil then return false end
    local ok, is = pcall(obj_has_behavior_id, object, id_bhvBowserBomb)
    if not (ok and is ~= 0 and is ~= false and is ~= nil) then return false end
    warp.landBombRefused = (warp.landBombRefused or 0) + 1
    return true
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

warp.PIPE_MOUTH = 102
warp.PIPE_TRIGGER = 50
function warp.pipe_trigger(factor)
    if type(factor) ~= "number" or not (factor > 1.0) then return nil end
    return warp.PIPE_MOUTH * factor - (warp.PIPE_MOUTH - warp.PIPE_TRIGGER)
end

function warp.land_is_pipe(object)
    if obj_has_behavior_id == nil or id_bhvWarpPipe == nil then return false end
    local ok, yes = pcall(function()
        return obj_has_behavior_id(object, id_bhvWarpPipe) ~= 0
    end)
    return ok and yes == true
end

local function land_hitbox_object(object, ax, ay, az)
    if object == nil then return false end
    if warp.land_is_body(object) then return false end

    if land_engine_hitbox(object) then return false end
    local wrote = false
    if land_press_fields(object, HITBOX_WIDE, math_max(ax, az)) then
        wrote = true
        local mouth = warp.land_is_pipe(object) and warp.pipe_trigger(math_max(ax, az)) or nil
        if mouth ~= nil then
            pcall(function()
                if mouth > (tonumber(object.hitboxRadius) or 0) then
                    object.hitboxRadius = mouth
                end
            end)
        end
    end
    if land_press_fields(object, HITBOX_TALL, ay) then wrote = true end
    if wrote then warp.landPressed = (warp.landPressed or 0) + 1 end
    return wrote
end

warp.land_hitbox_object = land_hitbox_object

do

local WARP_TYPE = INTERACT_WARP or 0x2000

warp.landWarped = 0

local function land_warp_object(object, ax, ay, az)
    if object == nil then return false end

    if land_is_landscape(object) then return false end
    local ok, kind = pcall(function() return object.oInteractType end)
    if not (ok and type(kind) == "number") then return false end
    if kind & WARP_TYPE == 0 then return false end
    local wrote = land_hitbox_object(object, ax, ay, az)

    if land_reach_grow(object, math_max(ax, ay, az)) then wrote = true end
    if wrote then warp.landWarped = (warp.landWarped or 0) + 1 end
    return wrote
end

warp.land_warp_object = land_warp_object

end

do

local CULL_NEAR = OBJ_FLAG_COMPUTE_DIST_TO_MARIO or (1 << 6)
local CULL_AFAR = OBJ_FLAG_ACTIVE_FROM_AFAR or (1 << 7)

local CULL_NO_ROOM = -1

warp.landCulled = 0

warp.landCullRefused = 0

local function land_cull_object(object, ax, ay, az)
    if object == nil then return false end

    if land_is_landscape(object) then return false end
    local ok, flags = pcall(function() return object.oFlags end)
    if not (ok and type(flags) == "number") then return false end

    if flags & CULL_NEAR == 0 then return false end

    if flags & CULL_AFAR ~= 0 then return false end
    local seen, room = pcall(function() return object.oRoom end)
    if not (seen and type(room) == "number") then return false end
    if room ~= CULL_NO_ROOM then return false end

    if not land_reach_grow(object, math_max(ax, ay, az)) then
        warp.landCullRefused = (warp.landCullRefused or 0) + 1
        return false
    end
    warp.landCulled = (warp.landCulled or 0) + 1
    return true
end

warp.land_cull_object = land_cull_object

end

local LAND_QUARTER = 0x4000
local LAND_TURN = 0x10000

local function land_is_static_geometry(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil or id_bhvStaticObject == nil then
        return false
    end
    local ok, is = pcall(function()
        return obj_has_behavior_id(object, id_bhvStaticObject) ~= 0
    end)
    return ok and is
end

warp.land_is_static_geometry = land_is_static_geometry

function warp.land_static_axes(object, ax, ay, az)
    if object == nil then return nil end
    local pitch, yaw, roll =
        object.oFaceAnglePitch, object.oFaceAngleYaw, object.oFaceAngleRoll

    if type(pitch) ~= "number" or type(yaw) ~= "number"
        or type(roll) ~= "number" then return nil end

    if pitch % LAND_TURN ~= 0 or roll % LAND_TURN ~= 0 then return nil end
    local turn = yaw % LAND_TURN
    if turn == 0 or turn == 2 * LAND_QUARTER then
        return ax, ay, az
    end
    if turn == LAND_QUARTER or turn == 3 * LAND_QUARTER then

        return az, ay, ax
    end
    return nil
end

warp.LAND_BACKDROPS = { "E_MODEL_TTM_BLUE_SMILEY", "E_MODEL_TTM_YELLOW_SMILEY",
    "E_MODEL_TTM_STAR_SMILEY", "E_MODEL_TTM_MOON_SMILEY" }

function warp.land_is_backdrop(object)
    if object == nil or obj_has_model_extended == nil then return false end
    for _, name in ipairs(warp.LAND_BACKDROPS) do
        local id = _G[name]
        if id ~= nil then
            local ok, is = pcall(obj_has_model_extended, object, id)
            if ok and is ~= 0 and is ~= false and is ~= nil then return true end
        end
    end
    return false
end

function warp.land_put_by_mod(object)
    if object == nil then return false end
    local flags = tonumber(object.coopFlags) or 0
    return OF.util.has_flag(flags, COOP_OBJ_FLAG_LUA or 0x2)
        or OF.util.has_flag(flags, COOP_OBJ_FLAG_NETWORK or 0x1)
end

local function land_static_object(object, ax, ay, az)
    if obj_scale_xyz == nil then return false end
    if not land_is_static_geometry(object) then return false end
    if warp.land_put_by_mod(object) then return false end
    if warp.land_is_backdrop(object) then return false end

    if warp.land_is_static_cloud(object) then return false end
    local sx, sy, sz = warp.land_static_axes(object, ax, ay, az)
    if sx == nil then return false end
    land_size_object(object, sx, warp.land_signed_height(sy), sz)
    return true
end

warp.land_static_object = land_static_object

function warp.land_is_static_cloud(object)
    if not land_is_static_geometry(object) then return false end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    return np ~= nil and LEVEL_TOTWC ~= nil and np.currLevelNum == LEVEL_TOTWC
end

function warp.land_keeps_size(object)
    if object == nil then return false end
    return warp.land_is_body(object) or warp.land_is_kept(object)
        or warp.land_is_reachable(object) or warp.land_is_backdrop(object)
        or warp.land_is_static_cloud(object)
end

function warp.land_keep_axes(ax, ay, az)
    return math_min(1.0, ax), math_min(1.0, ay), math_min(1.0, az)
end

do
local function land_keep_object(object, ax, ay, az)
    if obj_scale_xyz == nil or object == nil then return false end
    if not warp.land_keeps_size(object) then return false end
    if warp.land_was_sized(object) then return false end
    local kx, ky, kz = warp.land_keep_axes(ax, ay, az)
    if kx == 1.0 and ky == 1.0 and kz == 1.0 then return false end
    kx, ky, kz = warp.land_grow_axes(object, kx, ky, kz)
    return land_size_object(object, kx, ky, kz, true)
end

warp.land_keep_object = land_keep_object
end

function warp.land_grow_refused(object)
    if object == nil or obj_has_behavior_id == nil then return false end
    local ok, refused = pcall(function()
        return (id_bhvToxBox ~= nil and obj_has_behavior_id(object, id_bhvToxBox) ~= 0)
            or (id_bhvSpindel ~= nil and obj_has_behavior_id(object, id_bhvSpindel) ~= 0)

            or (id_bhvControllablePlatformSub ~= nil
                and obj_has_behavior_id(object, id_bhvControllablePlatformSub) ~= 0)
    end)
    return (ok and refused == true) or warp.land_is_body(object) or warp.land_is_kept(object)
end

warp.LAND_KEPT = { "bhvBreakableBox", "bhvExclamationBox", "bhvMessagePanel",
    "bhvSignOnWall", "bhvCapSwitch", "bhvCapSwitchBase" }

function warp.land_is_kept(object)
    if object == nil or obj_has_behavior_id == nil then return false end
    for _, name in ipairs(warp.LAND_KEPT) do
        local id = _G["id_" .. name]
        if id ~= nil then
            local ok, is = pcall(obj_has_behavior_id, object, id)
            if ok and is ~= 0 and is ~= false and is ~= nil then return true end
        end
    end
    return false
end

warp.LAND_TURNING = { "bhvRotatingPlatform", "bhvWfRotatingWoodenPlatform",
    "bhvLllRotatingHexagonalPlatform", "bhvLllRotatingHexagonalRing",
    "bhvLllRotatingBlockWithFireBars", "bhvTTCCog", "bhvTTCRotatingSolid",
    "bhvMerryGoRound", "bhvFerrisWheelAxle" }

function warp.land_grow_axes(object, ax, ay, az)
    if ax == az or object == nil then return ax, ay, az end
    local turning = false
    if obj_has_behavior_id ~= nil then
        for _, name in ipairs(warp.LAND_TURNING) do
            local id = _G["id_" .. name]
            if id ~= nil and obj_has_behavior_id(object, id) ~= 0 then turning = true end
        end
    end
    local yaw = tonumber(object.oFaceAngleYaw) or 0
    local turn = yaw % 0x10000
    if not turning and (turn == 0 or turn == 0x8000) then return ax, ay, az end
    if not turning and (turn == 0x4000 or turn == 0xC000) then return az, ay, ax end
    local even = math_sqrt(ax * az)
    return even, ay, even
end

local function land_grow_object(object, ax, ay, az)
    if not land_is_landscape(object) then return false end

    if warp.land_was_sized(object) then return false end
    if warp.land_grow_refused(object) then return false end
    ax, ay, az = warp.land_grow_axes(object, ax, ay, az)

    land_size_object(object, ax, warp.land_signed_height(ay), az)

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

warp.landClimbStubs = 0

local CLIMB_WIDE = { "hitboxRadius" }
local CLIMB_TALL = { "hitboxDownOffset" }

warp.LAND_SHAFTS = { "bhvDddMovingPole", "bhvGiantPole" }

function warp.land_is_shaft(object)
    if object == nil or obj_has_behavior_id == nil then return false end
    for _, name in ipairs(warp.LAND_SHAFTS) do
        local id = _G["id_" .. name]
        if id ~= nil then
            local ok, is = pcall(obj_has_behavior_id, object, id)
            if ok and is ~= 0 and is ~= false and is ~= nil then return true end
        end
    end
    return false
end

local function land_climb_object(object, ax, ay, az)
    if not land_is_climbed(object) then return false end

    if warp.land_was_sized(object) then return false end
    local wrote = false

    local shaft = warp.land_is_shaft(object)
    if obj_scale_xyz ~= nil then
        local wide, deep = ax, az
        if shaft then wide, deep = 1.0, 1.0 end
        land_size_object(object, wide, ay, deep)
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

        if type(high) == "number" and high > 0 and now ~= nil
            and now > high * ay then
            warp.landClimbStubs = (warp.landClimbStubs or 0) + 1
        end
    end

    if not shaft and land_press_fields(object, CLIMB_WIDE, math_max(ax, az)) then
        wrote = true
    end
    if land_press_fields(object, CLIMB_TALL, ay) then wrote = true end

    if wrote then warp.landClimbed = (warp.landClimbed or 0) + 1 end
    return wrote
end

warp.land_climb_object = land_climb_object

do

local POLE_BALL_GAP = 50.0

local function land_pole_top(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil or id_bhvYellowBall == nil then return false end

    local ok, ball = pcall(function()
        return obj_has_behavior_id(object, id_bhvYellowBall) ~= 0
    end)
    if not (ok and ball) then return false end
    local parent = object.parentObj
    if parent == nil then return false end

    if not land_is_climbed(parent) then return false end
    local read, px, py, pz, high = pcall(function()
        return parent.oPosX, parent.oPosY, parent.oPosZ, parent.hitboxHeight
    end)
    if not read then return false end
    if type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number"
        or type(high) ~= "number" then return false end
    object.oPosX, object.oPosY, object.oPosZ = px, py + high + POLE_BALL_GAP, pz

    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local at = gfx ~= nil and gfx.pos or nil
    if at ~= nil and type(at.x) == "number" and type(at.y) == "number"
        and type(at.z) == "number" then
        at.x, at.y, at.z = object.oPosX, object.oPosY, object.oPosZ
    end
    warp.landPoleTops = (warp.landPoleTops or 0) + 1
    return true
end

warp.land_pole_top = land_pole_top

end

warp.landPoleTops = 0

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

        local function is(id) return id ~= nil and obj_has_behavior_id(object, id) ~= 0 end
        if not (is(id_bhvRrElevatorPlatform) or is(id_bhvHmcElevatorPlatform)
            or is(id_bhvMeshElevator) or is(id_bhvAnotherElavator)) then
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

local TRAVEL_MIN_FRAMES = 1

warp.landTravel = 0
warp.landTravelRefused = 0

local function travel_along(yaw, ax, az)
    if type(yaw) ~= "number" then return math_max(ax, az) end
    local sx, sz = coss(yaw) * ax, sins(yaw) * az
    local length = math_sqrt(sx * sx + sz * sz)
    if length <= 0.0 then return math_max(ax, az) end
    return length
end

do

local function travel_forward(yaw, ax, az)
    if type(yaw) ~= "number" then return math_max(ax, az) end
    local sx, sz = sins(yaw) * ax, coss(yaw) * az
    local length = math_sqrt(sx * sx + sz * sz)
    if length <= 0.0 then return math_max(ax, az) end
    return length
end

warp.land_travel_forward = travel_forward

local RISE_BASE = 41
local RISE_TAIL = 5.0
local RISE_LEAD = (10.0 * RISE_BASE + RISE_TAIL) / 10.0

local RISE_MIN = 1 - RISE_BASE

local function thwomp_rise(held, factor)
    local want = math_floor(held * factor + RISE_LEAD * (factor - 1.0) + 0.5)
    if want < RISE_MIN then return RISE_MIN, false end
    return want, true
end

warp.land_thwomp_rise = thwomp_rise

local function tower_cycle(reach, speed)
    return (1 + math_floor(reach / speed)) * 2 + 1
end

warp.land_tower_cycle = tower_cycle

end

local function land_travel_object(object, ax, ay, az)
    if object == nil then return false end
    if ax == 1.0 and ay == 1.0 and az == 1.0 then return false end
    local ok, wrote = pcall(function()

        if obj_has_behavior_id(object, id_bhvCheckerboardPlatformSub) ~= 0 then
            local frames = object.oCheckerBoardPlatformUnkFC
            if type(frames) ~= "number" then return false end

            local want = math_floor(frames * ay + 0.5)
            if want < TRAVEL_MIN_FRAMES then want = TRAVEL_MIN_FRAMES end
            object.oCheckerBoardPlatformUnkFC = want

            local cycle = object.areaTimerDuration
            if type(cycle) == "number" and cycle == 132 + frames * 2 then
                object.areaTimerDuration = 132 + want * 2
            end

            local turn = object.oCheckerBoardPlatformUnk1AC
            if type(turn) == "number" and turn ~= 0 then
                object.oCheckerBoardPlatformUnk1AC = turn * ay
            end
            return true
        end

        if obj_has_behavior_id(object, id_bhvSlidingPlatform2) ~= 0 then
            local length = object.oBackAndForthPlatformPathLength
            if type(length) ~= "number" or length == 0 then return false end

            local dir = object.oBackAndForthPlatformDirection
            local factor
            if type(dir) == "number" and dir ~= 0.0 then
                factor = ay
            else
                factor = travel_along(object.oMoveAngleYaw, ax, az)
            end
            object.oBackAndForthPlatformPathLength = length * factor
            return true
        end

        if obj_has_behavior_id(object, id_bhvThwomp) ~= 0
            or obj_has_behavior_id(object, id_bhvThwomp2) ~= 0
            or obj_has_behavior_id(object, id_bhvGrindel) ~= 0 then
            local held = object.oBehParams2ndByte
            if type(held) ~= "number" then return false end
            local want, exact = warp.land_thwomp_rise(held, ay)
            if want == held then return false end
            object.oBehParams2ndByte = want
            if not exact then
                warp.landTravelRefused = (warp.landTravelRefused or 0) + 1
                return false
            end
            return true
        end

        if obj_has_behavior_id(object, id_bhvWfSlidingTowerPlatform) ~= 0 then
            local reach = object.oPlatformUnk110
            local speed = object.oPlatformUnk10C
            if type(reach) ~= "number" or reach == 0.0 then return false end
            if type(speed) ~= "number" or speed == 0.0 then return false end
            local want = reach
                * warp.land_travel_forward(object.oMoveAngleYaw, ax, az)
            object.oPlatformUnk110 = want

            local cycle = object.areaTimerDuration
            if type(cycle) == "number"
                and cycle == warp.land_tower_cycle(reach, speed) then
                object.areaTimerDuration = warp.land_tower_cycle(want, speed)
            end
            return true
        end

        if obj_has_behavior_id(object, id_bhvHorizontalGrindel) ~= 0 then
            warp.landTravelRefused = (warp.landTravelRefused or 0) + 1
            return false
        end

        return false
    end)
    if not (ok and wrote) then return false end
    warp.landTravel = (warp.landTravel or 0) + 1
    return true
end

warp.land_travel_object = land_travel_object

do

warp.landMotion = 0
warp.landMotionRefused = 0

local function motion_shape()
    if (warp.landShaped or 0) <= 0 then return false end
    if not landPlaced then return false end
    local size = landSize
    if size == nil then return false end
    local fx, fy, fz = size.x, size.y, size.z
    if type(fx) ~= "number" or type(fy) ~= "number"
        or type(fz) ~= "number" then return false end
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return false end

    if fx == 0.0 or fy == 0.0 or fz == 0.0 then return false end
    return true, fx, fy, fz
end

local function motion_size()
    local ok, fx, fy, fz = motion_shape()
    if not ok then return false end
    return true, math_abs(fx), math_abs(fy), math_abs(fz)
end

local STAGGER_SLOP = 1.0

local PLATE_ACT_UP = 1
local PLATE_ACT_DOWN = 3

local function land_stagger_plate(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok then return false end
    local ax, az = math_abs(fx), math_abs(fz)
    local parent = object.parentObj
    if parent == nil then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    local rx = object.oParentRelativePosX
    local ry = object.oParentRelativePosY
    local rz = object.oParentRelativePosZ
    local pitch = object.oFaceAnglePitch
    local roll = object.oFaceAngleRoll
    local yaw = object.oFaceAngleYaw
    if type(rx) ~= "number" or type(ry) ~= "number" or type(rz) ~= "number"
        or type(yaw) ~= "number"
        or (type(pitch) == "number" and pitch ~= 0)
        or (type(roll) == "number" and roll ~= 0) then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end

    local s, c = sins(yaw), coss(yaw)
    local wx = rx * c + rz * s
    local wy = ry
    local wz = rz * c - rx * s
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local ox, oy, oz = object.oPosX, object.oPosY, object.oPosZ
    if type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number"
        or type(ox) ~= "number" or type(oy) ~= "number"
        or type(oz) ~= "number" then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end

    if math_abs((ox - px) - wx) > STAGGER_SLOP
        or math_abs((oy - py) - wy) > STAGGER_SLOP
        or math_abs((oz - pz) - wz) > STAGGER_SLOP then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end

    object.oPosX = px + wx * ax
    object.oPosY = py + wy * fy
    object.oPosZ = pz + wz * az

    if fy < 0.0 then
        local act = object.oAction
        if act == PLATE_ACT_UP then
            object.oAction = PLATE_ACT_DOWN
        elseif act == PLATE_ACT_DOWN then
            object.oAction = PLATE_ACT_UP
        end
    end

    object.oHomeX, object.oHomeY, object.oHomeZ =
        object.oPosX, object.oPosY, object.oPosZ
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

warp.land_stagger_plate = land_stagger_plate

local SQUARE_LEG_FRAMES = 62
local SQUARE_LEG_FLIP = 61
local SQUARE_LEG_MIN = 2

local function square_leg(factor)
    local legs = math_floor(SQUARE_LEG_FRAMES * factor + 0.5)
    if legs < SQUARE_LEG_MIN then return SQUARE_LEG_MIN, false end
    return legs, true
end

local function land_square_leg(object)
    local ok, ax, _, az = motion_size()
    if not ok then return false end
    local action = object.oAction
    if type(action) ~= "number" then return false end

    if action ~= object.oPrevAction then return false end
    local factor
    if action == 2 or action == 4 then
        factor = ax
    elseif action == 1 or action == 3 then
        factor = az
    else
        return false
    end
    local legs = square_leg(factor)

    if legs == SQUARE_LEG_FRAMES then return false end
    local count = object.oSubAction
    if type(count) ~= "number" then count = 0 end
    count = count + 1
    object.oSubAction = count
    object.oTimer = math_floor(count * SQUARE_LEG_FLIP / (legs - 1)) - 1
    return true
end

warp.land_square_leg = land_square_leg

function warp.land_tower_child(object, fx, fy, fz)
    if object == nil or obj_has_behavior_id == nil then return false end
    local ok, tower = pcall(function()
        return (id_bhvWfSolidTowerPlatform ~= nil
                and obj_has_behavior_id(object, id_bhvWfSolidTowerPlatform) ~= 0)
            or (id_bhvWfSlidingTowerPlatform ~= nil
                and obj_has_behavior_id(object, id_bhvWfSlidingTowerPlatform) ~= 0)
            or (id_bhvWfElevatorTowerPlatform ~= nil
                and obj_has_behavior_id(object, id_bhvWfElevatorTowerPlatform) ~= 0)
    end)
    if not (ok and tower) then return false end
    local parent = object.parentObj
    if parent == nil then return false end
    local bx, by, bz = parent.oPosX, parent.oPosY - 300.0, parent.oPosZ
    object.oPosX = bx + (object.oPosX - bx) * fx
    object.oPosY = by + (object.oPosY - by) * fy
    object.oPosZ = bz + (object.oPosZ - bz) * fz
    return true
end

function warp.land_tower_group_init(object)
    local ok, _, fy = motion_size()
    if not ok or type(fy) ~= "number" or fy <= 0 or fy == 1.0 then return false end
    local base = object.oPosY - 300.0
    object.oHomeY = base + (300.0 - 1000.0) * fy + 1000.0
    return true
end

warp.land_square_leg_frames = square_leg

function warp.land_square_child(object, fx, fz)
    if object == nil or obj_has_behavior_id == nil or id_bhvSquarishPathMoving == nil then
        return false
    end
    if obj_has_behavior_id(object, id_bhvSquarishPathMoving) == 0 then return false end
    local parent = object.parentObj
    if parent == nil then return false end
    local radius = 307
    local side = radius * 2
    local function placed(p, corner, f)
        local rel = p - corner
        local sides = math_floor(rel / side + 0.5)
        return corner + sides * side * f + (rel - sides * side)
    end
    object.oPosX = placed(object.oPosX, parent.oPosX - radius, fx)
    object.oPosZ = placed(object.oPosZ, parent.oPosZ - radius, fz)
    return true
end

local function land_square_init(object)
    local ok, ax, _, az = motion_size()
    if not ok then return false end
    local _, exactX = square_leg(ax)
    local _, exactZ = square_leg(az)
    if exactX and exactZ then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_square_leg(object)
end

local SINE_STEP = 0x100
local SINE_STEP_MAX = 0x4000

local function sine_step(factor)
    local want = SINE_STEP / factor
    if want > SINE_STEP_MAX then return SINE_STEP_MAX, false end
    return want, true
end

local function land_swing_platform(object)
    local ok, _, ay, _ = motion_size()
    if not ok then return false end

    if ay == 1.0 then return false end
    local t = object.oPlatformTimer
    if type(t) ~= "number" then return false end
    local step = sine_step(ay)
    object.oPlatformTimer = math_floor(t - SINE_STEP + step + 0.5)
    return true
end

warp.land_swing_platform = land_swing_platform

local function land_swing_init(object)
    local ok, _, ay, _ = motion_size()
    if not ok then return false end
    local _, exact = sine_step(ay)
    if exact then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_swing_platform(object)
end

local CAGE_DROP = 300.0

local function land_swing_drop(object)
    local ok, _, fy, _ = motion_shape()
    if ok then
        local caged = object.oBehParams2ndByte
        local timer = object.oTimer
        local y = object.oPosY
        if type(caged) == "number" and caged ~= 0 and timer == 0
            and type(y) == "number" then

            object.oPosY = y - CAGE_DROP * (fy - 1.0)
        end
    end
    return land_swing_init(object)
end

warp.land_swing_drop = land_swing_drop

local function land_hook_motion(id, initFn, loopFn, objList)
    if id == nil then return false end
    if type(hook_behavior) ~= "function" then return false end
    if objList == nil then objList = OBJ_LIST_SURFACE end
    hook_behavior(id, objList, false, initFn, loopFn)
    return true
end

land_hook_motion(id_bhvCheckerboardPlatformSub, land_stagger_plate, nil)
land_hook_motion(id_bhvSquarishPathMoving, land_square_init, land_square_leg)
land_hook_motion(id_bhvBitfsSinkingPlatforms, land_swing_init,
    land_swing_platform)
land_hook_motion(id_bhvBitfsSinkingCagePlatform, land_swing_drop,
    land_swing_platform)

do

local BOMP_POKE_OFFSET = 150.0
local BOMP_EXTEND_OFFSET = 530.0
local BOMP_RETRACT_OFFSET = 30.0

local BOMP_ACT_WAIT = 0
local BOMP_ACT_POKE_OUT = 1
local BOMP_ACT_EXTEND = 2
local BOMP_ACT_RETRACT = 3

local BOMP_LEG_END = { [BOMP_ACT_POKE_OUT] = 15, [BOMP_ACT_EXTEND] = 60,
    [BOMP_ACT_RETRACT] = 90 }

local function bomp_offset(action, m, large)
    if action == BOMP_ACT_POKE_OUT then
        return math_min(BOMP_POKE_OFFSET, BOMP_RETRACT_OFFSET + 25.0 * m)
    elseif action == BOMP_ACT_EXTEND then
        return math_min(BOMP_EXTEND_OFFSET, BOMP_POKE_OFFSET + (large and 10.0 or 40.0) * m)
    elseif action == BOMP_ACT_RETRACT then
        return math_max(BOMP_RETRACT_OFFSET, BOMP_EXTEND_OFFSET - 10.0 * m)
    end

    return BOMP_RETRACT_OFFSET
end

warp.land_bomp_offset = bomp_offset

local function land_bomp_correct(object, base, ax)
    if ax == 1.0 then return false end
    local action = object.oAction
    if type(action) ~= "number" then return false end
    local large = obj_has_behavior_id ~= nil and id_bhvLargeBomp ~= nil
        and obj_has_behavior_id(object, id_bhvLargeBomp) ~= 0
    local stretch = math_max(ax, 1.0)
    local m
    if action ~= object.oPrevAction then

        m = 1.0 / stretch
    elseif stretch > 1.0 and BOMP_LEG_END[action] ~= nil then
        local n = (tonumber(object.oSubAction) or 0) + 1
        object.oSubAction = n
        m = (n + 1) / stretch

        object.oTimer = math_floor(n / stretch) - 1
    else
        m = (tonumber(object.oTimer) or 0) + 2
    end
    object.oForwardVel = 0.0
    object.oPosX = base + bomp_offset(action, m, large) * ax
    return true
end

local function land_bomp_loop(object)
    local ok, ax = motion_size()
    if not ok then return false end
    local base = object.oSmallBompInitX
    if type(base) ~= "number" then return false end
    return land_bomp_correct(object, base, math_abs(ax))
end

function warp.land_bomp_cycle(ax)
    if type(ax) ~= "number" or ax <= 1.0 then return 168 end
    return math.ceil(15 * ax) + math.ceil(60 * ax) + math.ceil(90 * ax) + 3
end

local function land_bomp_cycle_write(object)
    local ok, ax = motion_size()
    if not ok then return end
    if object.areaTimerDuration == 168 then
        object.areaTimerDuration = warp.land_bomp_cycle(math_abs(ax))
    end
end

local function land_small_bomp_init(object)
    if motion_size() then
        land_bomp_cycle_write(object)
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_bomp_loop(object)
end

local function land_large_bomp_init(object)
    if motion_size() then
        object.oSmallBompInitX = object.oPosX
        land_bomp_cycle_write(object)
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_bomp_loop(object)
end

warp.land_bomp_correct = land_bomp_correct

land_hook_motion(id_bhvSmallBomp, land_small_bomp_init, land_bomp_loop,
    OBJ_LIST_SURFACE)
land_hook_motion(id_bhvLargeBomp, land_large_bomp_init, land_bomp_loop,
    OBJ_LIST_SURFACE)

end

do

local TOX_REACH = 1000.0
local TOX_HALF = 256.0
local TOX_LIFT = 3.0
local TOX_ROLL_FIRST, TOX_ROLL_LAST = 4, 7

function warp.land_tox_scale()
    local ok, ax, _, az = motion_size()
    if not ok then return nil end
    local s = math_min(math_abs(ax), math_abs(az))
    if s == 1.0 or s <= 0 then return nil end
    return s
end

local function land_tox_init(object)
    local s = warp.land_tox_scale()
    if s == nil then return false end

    land_size_object(object, s, s, s)
    local lift = TOX_HALF * (s - 1.0)
    object.oHomeY = object.oHomeY + lift
    object.oPosY = object.oPosY + lift

    object.oCollisionDistance = 0.0
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

function warp.land_tox_loop(object)
    if type(load_object_collision_model) ~= "function" then return false end
    local s = warp.land_tox_scale()
    if s == nil then
        if object.oCollisionDistance == 0.0 then object.oCollisionDistance = TOX_REACH end
        return false
    end

    local ran = object.oPrevAction
    if type(ran) == "number" and ran >= TOX_ROLL_FIRST and ran <= TOX_ROLL_LAST then
        object.oPosX = object.oPosX + (s - 1.0) * (tonumber(object.oVelX) or 0)
        object.oPosZ = object.oPosZ + (s - 1.0) * (tonumber(object.oVelZ) or 0)
        local rest = object.oHomeY + TOX_LIFT
        object.oPosY = rest + (object.oPosY - rest) * s
    end

    object.oCollisionDistance = TOX_REACH * s
    load_object_collision_model()
    object.oCollisionDistance = 0.0
    return true
end

land_hook_motion(id_bhvToxBox, land_tox_init, warp.land_tox_loop, OBJ_LIST_SURFACE)
end

warp.landBombPending = setmetatable({}, { __mode = "k" })

function warp.land_bomb_place(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end

    local flags = tonumber(object.coopFlags) or 0
    if OF.util.has_flag(flags, COOP_OBJ_FLAG_LUA or 0x2)
        or OF.util.has_flag(flags, COOP_OBJ_FLAG_NETWORK or 0x1) then
        return false
    end
    if fx == 0 or fz == 0 then return false end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return false end

    warp.landBombPending[object] = true
    warp.land_bomb_seat(object)
    return true
end

function warp.land_bomb_seat(object)
    if object == nil or not warp.landBombPending[object] then return false end
    if not warp.land_grown() then return false end
    warp.landBombPending[object] = nil
    local ok, _, fy = motion_shape()
    if not ok or fy <= 0 or fy == 1.0 then return false end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    local floor = OF.util.optional("find_floor_height", nil, x, y + 200, z)
    if type(floor) ~= "number" or floor <= -10000 or floor > y then return false end
    y = floor + (y - floor) / fy
    object.oPosY, object.oHomeY = y, y
    return true
end

land_hook_motion(id_bhvBowserBomb, warp.land_bomb_place, warp.land_bomb_seat, OBJ_LIST_GENACTOR)

warp.BOWSER_THROWN = 1
warp.landBowserThrow = setmetatable({}, { __mode = "k" })

function warp.land_bowser_throw(object)
    if object == nil then return false end
    if object.oAction ~= warp.BOWSER_THROWN then
        warp.landBowserThrow[object] = nil
        return false
    end
    if warp.landBowserThrow[object] then return false end
    warp.landBowserThrow[object] = true
    local ok, fx, _, fz = motion_shape()
    if not ok or warp.land_put_by_mod(object) then return false end
    local ax, az = math_abs(fx), math_abs(fz)
    if ax == 1.0 and az == 1.0 then return false end
    local v, yaw = tonumber(object.oForwardVel) or 0, tonumber(object.oMoveAngleYaw) or 0
    if v == 0 then return false end
    local vx, vz = v * sins(yaw) * ax, v * coss(yaw) * az

    object.oForwardVel = math.sqrt(vx * vx + vz * vz)
    object.oMoveAngleYaw = atan2s(vz, vx)
    return true
end

if id_bhvBowser ~= nil then
    land_hook_motion(id_bhvBowser, nil, warp.land_bowser_throw, OBJ_LIST_GENACTOR)
end

function warp.land_hand_child(object, fx, fy, fz)
    if object == nil or obj_has_behavior_id == nil then return false end
    local function is(id)
        return id ~= nil and obj_has_behavior_id(object, id) ~= 0
    end
    local ok, kind = pcall(function()
        if is(id_bhvLllDrawbridge) or is(id_bhvLllBowserPuzzlePiece) then return "offset" end
        if is(id_bhvPyramidElevatorTrajectoryMarkerBall) then return "ball" end
        return nil
    end)
    if not ok or kind == nil then return false end
    local parent = object.parentObj
    if parent == nil then return false end
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    local homed = object.oHomeX == x and object.oHomeY == y and object.oHomeZ == z
    if kind == "ball" then
        object.oPosX, object.oPosY, object.oPosZ = px, y * fy, pz
    else
        object.oPosX = px + (x - px) * fx
        object.oPosY = py + (y - py) * fy
        object.oPosZ = pz + (z - pz) * fz
    end
    if homed then
        object.oHomeX, object.oHomeY, object.oHomeZ = object.oPosX, object.oPosY, object.oPosZ
    end
    return true
end

function warp.land_puzzle_piece(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    local hx, hy, hz = object.oHomeX, object.oHomeY, object.oHomeZ
    local ox, oy, oz = object.oBowserPuzzlePieceOffsetX, object.oBowserPuzzlePieceOffsetY,
        object.oBowserPuzzlePieceOffsetZ
    if type(hx) ~= "number" or type(ox) ~= "number" then return false end
    object.oPosX = hx + ox * math_abs(fx)
    object.oPosY = hy + (tonumber(oy) or 0) * fy
    object.oPosZ = hz + (tonumber(oz) or 0) * math_abs(fz)
    return true
end

land_hook_motion(id_bhvLllBowserPuzzlePiece, nil, warp.land_puzzle_piece, OBJ_LIST_SURFACE)

function warp.land_grindel_beat(object)
    local ok, ax, _, az = motion_size()
    if not ok or object == nil then return false end
    local f = math_max(ax, az)
    if f <= 1.0 then return false end
    local d = object.oHorizontalGrindelDistToHome
    if type(d) ~= "number" or d <= 0 then return false end
    local dx, dz = object.oPosX - object.oHomeX, object.oPosZ - object.oHomeZ
    if math_abs(math_sqrt(dx * dx + dz * dz) - d) > 0.01 then return false end
    object.oHorizontalGrindelDistToHome = d / f
    return true
end

land_hook_motion(id_bhvHorizontalGrindel, nil, warp.land_grindel_beat, OBJ_LIST_SURFACE)

do

local HOP_RISE_G, HOP_FALL_G = -4.0, -16.0

function warp.land_grindel_hop(object)
    local ok, ax, ay, az = motion_size()
    if not ok or object == nil then return false end
    if not warp.land_route_kit.level_own(object) then return false end
    local state = warp.land_route_kit.npc_state(object)
    if object.oHorizontalGrindelOnGround == 1 or object.oHorizontalGrindelOnGround == true then
        state.hop = nil
        return false
    end
    local vy, g = tonumber(object.oVelY) or 0, tonumber(object.oGravity) or 0
    if not state.hop then
        if g ~= HOP_RISE_G or vy <= 0 then return false end
        state.hop = true
        local yaw = tonumber(object.oMoveAngleYaw) or 0
        object.oVelY = vy * ay
        object.oGravity = HOP_RISE_G * ay
        object.oForwardVel = (tonumber(object.oForwardVel) or 0)
            * math_sqrt((sins(yaw) * ax) ^ 2 + (coss(yaw) * az) ^ 2)
        return true
    end
    if g == HOP_FALL_G then
        object.oVelY = vy + HOP_FALL_G * (ay - 1.0)
        return true
    end
    return false
end

land_hook_motion(id_bhvHorizontalGrindel, nil, warp.land_grindel_hop, OBJ_LIST_SURFACE)
end

do
local function gated_load(object, reach)
    object.oCollisionDistance = reach
    load_object_collision_model()
    object.oCollisionDistance = 0.0
end

local ELEVATOR_REACH, ELEVATOR_FLOOR = 20000.0, 128.0
local ELEV_CONSTANT, ELEV_END, ELEV_BOTTOM = 2, 3, 4

function warp.land_pyramid_elevator(object)
    if type(load_object_collision_model) ~= "function" or object == nil then return false end
    local ok, _, fy = motion_shape()
    if not ok or fy <= 0 or fy == 1.0 then
        if object.oCollisionDistance == 0.0 then object.oCollisionDistance = ELEVATOR_REACH end
        return false
    end

    if object.oCollisionDistance ~= 0.0 then
        object.oCollisionDistance = 0.0
        return false
    end
    local bottom = ELEVATOR_FLOOR * fy
    local a = object.oAction
    if a == ELEV_CONSTANT then
        if object.oPosY < bottom then
            object.oPosY = bottom
            object.oAction = ELEV_END
        end
    elseif a == ELEV_END then
        if object.oPrevAction == ELEV_CONSTANT and bottom < ELEVATOR_FLOOR then
            object.oAction = ELEV_CONSTANT
        else
            object.oPosY = object.oPosY - ELEVATOR_FLOOR + bottom
        end
    elseif a == ELEV_BOTTOM then
        object.oPosY = bottom
    end
    gated_load(object, ELEVATOR_REACH)
    return true
end

local WALL_REACH = 1000.0
local WALL_DROP = { [1] = 256.0, [2] = 512.0 }

local function land_pyramid_wall_init(object)
    if type(load_object_collision_model) ~= "function" then return false end
    local ok, _, fy = motion_shape()
    if not ok or fy <= 0 or fy == 1.0 then return false end
    local drop = WALL_DROP[tonumber(object.oBehParams2ndByte) or 0] or 0.0
    object.oPosY = object.oPosY - drop * (fy - 1.0)
    object.oCollisionDistance = 0.0
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

function warp.land_pyramid_wall(object)
    if type(load_object_collision_model) ~= "function" or object == nil then return false end
    local ok, ax, fy, az = motion_shape()
    if not ok or fy <= 0 or fy == 1.0 then
        if object.oCollisionDistance == 0.0 then object.oCollisionDistance = WALL_REACH end
        return false
    end

    object.oPosY = object.oPosY + (tonumber(object.oVelY) or 0) * (fy - 1.0)
    gated_load(object, WALL_REACH * math_max(math_abs(ax), fy, math_abs(az)))
    return true
end

land_hook_motion(id_bhvPyramidElevator, nil, warp.land_pyramid_elevator, OBJ_LIST_SURFACE)

function warp.land_lll_sink(object)
    local ok, _, ay = motion_size()
    if not ok or object == nil or ay <= 1.0 then return false end
    local t = object.oLllWoodPieceOscillationTimer
    if type(t) ~= "number" then return false end
    local step
    if obj_has_behavior_id ~= nil and id_bhvLllWoodPiece ~= nil
        and obj_has_behavior_id(object, id_bhvLllWoodPiece) ~= 0 then
        step = 0x400
    else
        if object.oAction ~= 1 or object.oPrevAction ~= 1 then return false end
        if id_bhvLllSinkingRectangularPlatform ~= nil
            and obj_has_behavior_id(object, id_bhvLllSinkingRectangularPlatform) ~= 0
            and object.oMoveAngleYaw == 0 then
            return false
        end
        step = 0x100
    end
    object.oLllWoodPieceOscillationTimer = math_floor(t - step + step / ay + 0.5)
    return true
end

land_hook_motion(id_bhvLllSinkingRectangularPlatform, nil, warp.land_lll_sink, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvLllSinkingSquarePlatforms, nil, warp.land_lll_sink, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvLllWoodPiece, nil, warp.land_lll_sink, OBJ_LIST_SURFACE)

local FLAME_DONE = -987654.0
function warp.land_fire_bar_flame(object)
    local ok, _, fy = motion_shape()
    if not ok or object == nil then return false end
    local parent = object.parentObj
    if parent == nil then return false end
    if object.oLllRotatingHexFlameUnkF8 ~= FLAME_DONE then
        local sc = parent.header ~= nil and parent.header.gfx ~= nil and parent.header.gfx.scale or nil
        local sx = sc ~= nil and tonumber(sc.x) or 1.0
        local sz = sc ~= nil and tonumber(sc.z) or 1.0
        object.oLllRotatingHexFlameUnkF4 = (tonumber(object.oLllRotatingHexFlameUnkF4) or 0) * sx
        object.oLllRotatingHexFlameUnkFC = (tonumber(object.oLllRotatingHexFlameUnkFC) or 0) * sz
        object.oLllRotatingHexFlameUnkF8 = FLAME_DONE
    end
    object.oPosY = parent.oPosY + 100.0 * fy
    return true
end

land_hook_motion(id_bhvLllRotatingHexFlame, nil, warp.land_fire_bar_flame, OBJ_LIST_LEVEL)

function warp.land_arrow_lift(object)
    local ok, ax, _, az = motion_size()
    if not ok or object == nil then return false end
    if object.oForwardVel ~= 12 then return false end
    local f = warp.land_travel_forward(object.oMoveAngleYaw, ax, az)
    if f == 1.0 or f <= 0 then return false end

    local k = tonumber(object.oTimer) or 0
    if object.oAction == 1 then
        object.oArrowLiftDisplacement = 12 * (k + 2) - 384 * f + 372
    elseif object.oAction == 2 then
        k = k - 61
        object.oArrowLiftDisplacement = 12 + 384 * f - 12 * (k + 2)
    else
        return false
    end
    return true
end

function warp.land_bf_reach(object)
    local ok, ax, ay, az = motion_size()
    if not ok or object == nil then return false end
    local reach = object.oActivatedBackAndForthPlatformMaxOffset
    if type(reach) ~= "number" then return false end
    local f
    if object.oActivatedBackAndForthPlatformVertical ~= 0
        and object.oActivatedBackAndForthPlatformVertical ~= false then
        f = ay
    else
        local yaw = object.oActivatedBackAndForthPlatformStartYaw
        local sx, sz = coss(yaw or 0) * ax, sins(yaw or 0) * az
        f = math_sqrt(sx * sx + sz * sz)
    end
    if f == 1.0 or f <= 0 then return false end
    object.oActivatedBackAndForthPlatformMaxOffset = reach * f
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

land_hook_motion(id_bhvArrowLift, nil, warp.land_arrow_lift, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvActivatedBackAndForthPlatform, warp.land_bf_reach, nil, OBJ_LIST_SURFACE)

function warp.land_express_elevator(object)
    local ok, _, fy = motion_size()
    if not ok or object == nil or fy <= 1.0 then return false end
    if object.oAction ~= 1 or object.oPrevAction ~= 1 then return false end

    local rides = math_floor(134 * fy + 0.5)
    local n = (tonumber(object.oSubAction) or 0) + 1
    object.oSubAction = n
    object.oTimer = math_floor(n * 133 / (rides - 1)) - 1
    return true
end

local FLOAT_REACH = 1000.0
function warp.land_floating_platform(object)
    if type(load_object_collision_model) ~= "function" or object == nil then return false end
    local ok, ax, fy, az = motion_shape()
    if not ok or fy <= 0 or fy == 1.0 then
        if object.oCollisionDistance == 0.0 then object.oCollisionDistance = FLOAT_REACH end
        return false
    end
    if object.oCollisionDistance ~= 0.0 then
        object.oCollisionDistance = 0.0
        return false
    end
    local home = object.oHomeY
    local above = tonumber(object.oFloatingPlatformUnkFC) or 0
    if type(home) == "number" then
        object.oPosY = home + (fy - 1.0) * above + (object.oPosY - home) * fy
    end
    gated_load(object, FLOAT_REACH * math_max(math_abs(ax), fy, math_abs(az)))
    return true
end

land_hook_motion(id_bhvWdwExpressElevator, nil, warp.land_express_elevator, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvWdwSquareFloatingPlatform, nil, warp.land_floating_platform, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvWdwRectangularFloatingPlatform, nil, warp.land_floating_platform,
    OBJ_LIST_SURFACE)
land_hook_motion(id_bhvJrbFloatingPlatform, nil, warp.land_floating_platform, OBJ_LIST_SURFACE)

function warp.land_cap_switch(object)
    local ok, _, fy = motion_shape()
    if not ok or object == nil or fy <= 0 or fy == 1.0 then return false end

    if fy >= 1.0 then return false end
    object.oPosY = object.oPosY + 71.0 * (fy - 1.0)
    return true
end

land_hook_motion(id_bhvCapSwitch, warp.land_cap_switch, nil, OBJ_LIST_SURFACE)

local PENGUIN_FORWARD, PENGUIN_TURN_BACK = 0, 1
local PENGUIN_RETURN, PENGUIN_TURN_FORWARD = 2, 3

function warp.land_sl_penguin(object)
    local ok, ax = motion_size()
    if not ok or object == nil or ax == 1.0 then return false end
    local x, a, was = object.oPosX, object.oAction, object.oPrevAction
    local near, far = 300.0 * ax, 1700.0 * ax
    if a == PENGUIN_TURN_BACK and was == PENGUIN_FORWARD and x >= near then
        object.oAction = PENGUIN_FORWARD
    elseif a == PENGUIN_FORWARD and x < near then
        object.oAction = PENGUIN_TURN_BACK
    elseif a == PENGUIN_TURN_FORWARD and was == PENGUIN_RETURN and x <= far then
        object.oAction = PENGUIN_RETURN
    elseif a == PENGUIN_RETURN and x > far then
        object.oAction = PENGUIN_TURN_FORWARD
    else
        return false
    end
    return true
end

local CHOMP_TARGETS = { { 1450.0, 562.0, 8.0 }, { 3288.0, -1770.0, 50.0 } }

function warp.land_chain_chomp(object)
    local ok, ax, _, az = motion_size()
    if not ok or object == nil or (ax == 1.0 and az == 1.0) then return false end
    for _, t in ipairs(CHOMP_TARGETS) do
        if object.oHomeX == t[1] and object.oHomeZ == t[2] then
            local hx, hz = t[1] * ax, t[2] * az
            object.oHomeX, object.oHomeZ = hx, hz
            local dx, dz = hx - object.oPosX, hz - object.oPosZ
            object.oMoveAngleYaw = atan2s(dz, dx)
            object.oForwardVel = math_sqrt(dx * dx + dz * dz) / t[3]
            return true
        end
    end
    return false
end

land_hook_motion(id_bhvSLWalkingPenguin, nil, warp.land_sl_penguin, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvChainChomp, nil, warp.land_chain_chomp, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvSslMovingPyramidWall, land_pyramid_wall_init, warp.land_pyramid_wall,
    OBJ_LIST_SURFACE)
end

do
local SPINDEL_REACH = 1000.0

function warp.land_spindel_scale()
    local ok, ax, ay, az = motion_size()
    if not ok or az == 1.0 or az <= 0 then return nil end
    return ax, ay, az
end

local function land_spindel_init(object)
    local ax, ay, s = warp.land_spindel_scale()
    if ax == nil then return false end

    if obj_scale_xyz ~= nil then land_size_object(object, ax, s, s) end
    local home = object.oHomeY
    local floor = OF.util.optional("find_floor_height", nil, object.oPosX, home + 100, object.oPosZ)
    if type(floor) == "number" and floor > -10000 and floor <= home and ay > 0 then
        home = floor + (home - floor) / ay * s
    end
    object.oHomeY, object.oPosY = home, home
    object.oHomeZ = object.oPosZ
    object.oCollisionDistance = 0.0
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

function warp.land_spindel_loop(object)
    if type(load_object_collision_model) ~= "function" then return false end
    local ax, _, s = warp.land_spindel_scale()
    if ax == nil then
        if object.oCollisionDistance == 0.0 then object.oCollisionDistance = SPINDEL_REACH end
        return false
    end
    local last = object.oHomeZ
    if type(last) == "number" then
        local step = object.oPosZ - last
        if step ~= 0 then
            object.oPosZ = last + step * s
            object.oPosY = object.oHomeY + (object.oPosY - object.oHomeY) * s
        end
    end
    object.oHomeZ = object.oPosZ
    object.oCollisionDistance = SPINDEL_REACH * math_max(ax, s)
    load_object_collision_model()
    object.oCollisionDistance = 0.0
    return true
end

land_hook_motion(id_bhvSpindel, land_spindel_init, warp.land_spindel_loop, OBJ_LIST_SURFACE)
end

do

local function level_own(object)
    local flags = tonumber(object.coopFlags) or 0
    if OF.util.has_flag(flags, COOP_OBJ_FLAG_LUA or 0x2)
        or OF.util.has_flag(flags, COOP_OBJ_FLAG_NETWORK or 0x1) then
        return false
    end
    return true
end

local function s16(a)
    a = math_floor(a) % 65536
    if a >= 32768 then a = a - 65536 end
    return a
end

local function yaw_toward(value, target, step)
    local dist = s16(target - value)
    if dist >= 0 then
        if dist > step then return s16(value + step) end
        return s16(target)
    end
    if dist < -step then return s16(value - step) end
    return s16(target)
end

local function turned_from(value, target, step)
    local dist = s16(target - value)
    if dist == 0 then return s16(value) end
    if dist > 0 then return s16(value - step) end
    return s16(value + step)
end

local function scaled_yaw(yaw, fx, fz)
    return s16(atan2s(coss(yaw) * fz, sins(yaw) * fx))
end

local function dist3(object, x, y, z)
    local dx, dy, dz = x - object.oPosX, y - object.oPosY, z - object.oPosZ
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

local npcState = setmetatable({}, { __mode = "k" })
local function npc_state(object, fresh)
    local state = npcState[object]
    if state == nil or fresh then
        state = {}
        npcState[object] = state
    end
    return state
end
warp.land_npc_state = npc_state

local function scaled_pitch(yaw, pitch, fx, fy, fz)
    local sx, sz = sins(yaw) * fx, coss(yaw) * fz
    return s16(atan2s(coss(pitch) * math_sqrt(sx * sx + sz * sz), sins(pitch) * fy))
end

local function follow_vanilla(object, fx, fy, fz, state, join)
    if type(cur_obj_follow_path) ~= "function" then return nil end
    if object.oPlatformOnTrackStartWaypoint == nil then return nil end
    if state.waypoint ~= nil then
        object.oPlatformOnTrackPrevWaypoint = state.waypoint
        object.oPlatformOnTrackPrevWaypointFlags = state.waypointFlags
    elseif not join then
        object.oPlatformOnTrackPrevWaypointFlags = 0
    end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    object.oPosX, object.oPosY, object.oPosZ = x / fx, y / fy, z / fz
    local answer = cur_obj_follow_path(0)
    object.oPosX, object.oPosY, object.oPosZ = x, y, z
    state.waypoint = object.oPlatformOnTrackPrevWaypoint
    state.waypointFlags = object.oPlatformOnTrackPrevWaypointFlags
    local yaw = tonumber(object.oPathedTargetYaw) or 0
    local pitch = tonumber(object.oPathedTargetPitch) or 0
    return answer, scaled_yaw(yaw, fx, fz), scaled_pitch(yaw, pitch, fx, fy, fz)
end
warp.land_follow_vanilla = follow_vanilla

warp.land_route_kit = {
    level_own = level_own, s16 = s16, yaw_toward = yaw_toward,
    turned_from = turned_from, scaled_yaw = scaled_yaw, npc_state = npc_state,
    follow = follow_vanilla,
}

do

local SNOW_X, SNOW_Y, SNOW_Z = -4230.0, -1344.0, 1813.0
local SNOW_REACH = 300.0
local SNOW_REST = 350.0
local SNOW_ROLL, SNOW_JUMP, SNOW_LAND = 1, 2, 3
local SNOW_TURN = 0x400

function warp.land_snowman_bottom(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local was, now = object.oPrevAction, object.oAction
    if was == SNOW_ROLL then
        local state = npc_state(object, (tonumber(object.oTimer) or 0) == 0)
        local from = turned_from(object.oMoveAngleYaw, object.oSnowmansBottomUnkF8, SNOW_TURN)
        local answer, yaw = follow_vanilla(object, fx, fy, fz, state)
        if answer == nil then return false end
        object.oSnowmansBottomUnkF8 = yaw
        object.oMoveAngleYaw = yaw_toward(from, yaw, SNOW_TURN)
        if answer == -1 then

            object.oSnowmansBottomUnkF8 = object.oMoveAngleYaw
            local player = OF.util.optional("nearest_player_to_object", nil, object)
            if player ~= nil and object.oSnowmansBottomUnk1AC == 1 then
                local toward = OF.util.optional("obj_angle_to_object", nil, object, player)
                if type(toward) == "number"
                    and math_abs(s16(toward - object.oMoveAngleYaw)) < 0x2000 then
                    object.oSnowmansBottomUnkF8 = s16(toward)
                end
            end
            object.oAction = SNOW_JUMP
        elseif now == SNOW_JUMP then
            object.oAction = SNOW_ROLL
        end
        return true
    end
    if was == SNOW_JUMP and now == SNOW_JUMP then
        local hx, hy, hz = SNOW_X * fx, SNOW_Y * fy, SNOW_Z * fz
        if dist3(object, hx, hy, hz) >= SNOW_REACH then return false end

        OF.util.optional("spawn_mist_particles_variable", nil, 0, 0, 70.0)
        object.oMoveAngleYaw = s16(atan2s(hz - object.oPosZ, hx - object.oPosX))
        object.oVelY, object.oForwardVel = 80.0, 15.0
        object.oAction = SNOW_LAND
        local head = object.parentObj
        if head ~= nil then head.oAction, head.oVelY = 2, 100.0 end
        if SOUND_OBJ_SNOWMAN_BOUNCE ~= nil then
            OF.util.optional("cur_obj_play_sound_2", nil, SOUND_OBJ_SNOWMAN_BOUNCE)
        end
        return true
    end
    if was == SNOW_LAND and object.oPosX == SNOW_X and object.oPosZ == SNOW_Z then
        object.oPosX, object.oPosZ = SNOW_X * fx, SNOW_Z * fz
        return true
    end
    return false
end

local SNOW_HEAD_FALL, SNOW_HEAD_DONE = 3, 4
local SNOW_HEAD_VANILLA = -994.0

function warp.land_snowman_head_init(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end

    if object.oPosX == SNOW_X and object.oPosZ == SNOW_Z and object.oPosY == SNOW_HEAD_VANILLA then
        object.oPosX, object.oPosZ = SNOW_X * fx, SNOW_Z * fz
        object.oPosY = SNOW_Y * fy + SNOW_REST
        return true
    end
    return false
end

function warp.land_snowman_head(object)
    local ok, _, fy = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    if object.oPrevAction ~= SNOW_HEAD_FALL then return false end
    local rest = SNOW_Y * fy + SNOW_REST
    local state = npc_state(object)
    if object.oAction == SNOW_HEAD_DONE and rest < SNOW_HEAD_VANILLA - 0.5 then

        object.oAction = SNOW_HEAD_FALL
        state.sounded = true
        return true
    end
    if object.oAction == SNOW_HEAD_FALL and object.oPosY < rest then
        object.oPosY = rest
        object.oAction = SNOW_HEAD_DONE
        if not state.sounded then
            if SOUND_OBJ_SNOWMAN_EXPLODE ~= nil then
                OF.util.optional("cur_obj_play_sound_2", nil, SOUND_OBJ_SNOWMAN_EXPLODE)
            end
            OF.util.optional("play_puzzle_jingle", nil)
        end
        state.sounded = nil
        return true
    end
    return false
end
end

do

local YOSHI_HOMES = { { 0, -5625 }, { -1364, -5912 }, { -1403, -4609 }, { -1004, -5308 } }
local YOSHI_RESPAWN = { -12406.0, 1076.0, -8567.0 }
local YOSHI_ROOF, YOSHI_FALL, YOSHI_REACH = 3174.0, 2100.0, 200.0
local YOSHI_IDLE, YOSHI_WALK, YOSHI_OFF_ROOF = 0, 1, 3
local YOSHI_JUMP_DOWN, YOSHI_PRESENT, YOSHI_REAPPEAR = 4, 5, 7
local YOSHI_REAPPEAR_FRAMES = 60

local function yoshi_home(object, fx, fz)
    for _, home in ipairs(YOSHI_HOMES) do
        if object.oHomeX == home[1] and object.oHomeZ == home[2] then
            object.oHomeX, object.oHomeZ = home[1] * fx, home[2] * fz
            object.oYoshiTargetYaw = s16(atan2s(object.oHomeZ - object.oPosZ,
                object.oHomeX - object.oPosX))
            return true
        end
    end
    return false
end

function warp.land_yoshi(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local was, now = object.oPrevAction, object.oAction
    local wrote = false
    if now ~= was and (now == YOSHI_WALK or now == YOSHI_PRESENT) then
        wrote = yoshi_home(object, fx, fz)
    end
    if was == YOSHI_IDLE and now == YOSHI_WALK and YOSHI_ROOF * fy < YOSHI_FALL then
        object.oAction = YOSHI_IDLE
        return true
    end
    local near = dist3(object, object.oHomeX, YOSHI_ROOF * fy, object.oHomeZ) < YOSHI_REACH
    if was == YOSHI_WALK then
        if now == YOSHI_IDLE and not near then
            object.oAction = YOSHI_WALK
            return true
        elseif now == YOSHI_WALK and near then
            object.oAction = YOSHI_IDLE
            return true
        end
    elseif was == YOSHI_OFF_ROOF then
        if now == YOSHI_OFF_ROOF and near then

            OF.util.optional("cur_obj_init_animation", nil, 2)
            if SOUND_GENERAL_ENEMY_ALERT1 ~= nil then
                OF.util.optional("cur_obj_play_sound_2", nil, SOUND_GENERAL_ENEMY_ALERT1)
            end
            object.oForwardVel, object.oVelY = 50.0, 40.0
            object.oMoveAngleYaw = -0x3FFF
            object.oAction = YOSHI_JUMP_DOWN
            return true
        elseif now == YOSHI_JUMP_DOWN and not near then
            object.oForwardVel, object.oVelY = 10.0, 0.0
            object.oMoveAngleYaw = s16(object.oYoshiTargetYaw or object.oMoveAngleYaw)
            object.oAction = YOSHI_OFF_ROOF
            return true
        end
    elseif was == YOSHI_REAPPEAR then
        local rx, ry, rz = YOSHI_RESPAWN[1], YOSHI_RESPAWN[2], YOSHI_RESPAWN[3]
        if now == YOSHI_REAPPEAR and (tonumber(object.oTimer) or 0) == 0 then

            object.oHomeX = YOSHI_HOMES[2][1] * fx
            object.oHomeZ = YOSHI_HOMES[2][2] * fz
            object.oHomeY = YOSHI_ROOF * fy
            object.oPosX = object.oPosX + rx * (fx - 1.0)
            object.oPosY = object.oPosY + ry * (fy - 1.0)
            object.oPosZ = object.oPosZ + rz * (fz - 1.0)
            return true
        elseif now == YOSHI_REAPPEAR then

            local dx, dz = object.oHomeX - rx * fx, object.oHomeZ - rz * fz
            local want = math_sqrt(dx * dx + dz * dz) / YOSHI_REAPPEAR_FRAMES
            local extra = want - (tonumber(object.oForwardVel) or 0)
            object.oPosX = object.oPosX + extra * sins(object.oMoveAngleYaw)
            object.oPosZ = object.oPosZ + extra * coss(object.oMoveAngleYaw)
            return true
        elseif now == YOSHI_IDLE and object.oPosY == YOSHI_ROOF then
            object.oPosY, object.oHomeY = YOSHI_ROOF * fy, YOSHI_ROOF * fy
            if object.oPosX == YOSHI_HOMES[2][1] and object.oPosZ == YOSHI_HOMES[2][2] then
                object.oPosX, object.oPosZ = YOSHI_HOMES[2][1] * fx, YOSHI_HOMES[2][2] * fz
                object.oHomeX, object.oHomeZ = object.oPosX, object.oPosZ
            end
            return true
        end
    end
    return wrote
end
end

do

local HOOT_PERCH = { 800.0, -150.0, 300.0 }
local HOOT_CLIMB, HOOT_BOUND = 6500.0, 8000.0
local HOOT_ASCENT, HOOT_CARRY = 0, 1

function warp.land_hoot_init(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    object.oHomeX = object.oPosX + HOOT_PERCH[1] * fx
    object.oHomeY = object.oPosY + HOOT_PERCH[2] * fy
    object.oHomeZ = object.oPosZ + HOOT_PERCH[3] * fz
    return true
end

function warp.land_hoot(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local state = npc_state(object)
    local lastX, lastZ = state.x, state.z
    local x, z = object.oPosX, object.oPosZ
    local grabbed = object.oInteractStatus == (INT_STATUS_HOOT_GRABBED_BY_MARIO or 1)
    local changed = false
    if grabbed then
        local climb = HOOT_CLIMB * math_max(math_abs(fy), 1.0)
        local was, now = object.oPrevAction, object.oAction
        if was == HOOT_ASCENT and now == HOOT_CARRY and object.oPosY <= climb then
            object.oAction, changed = HOOT_ASCENT, true
        elseif was == HOOT_ASCENT and now == HOOT_ASCENT and object.oPosY > climb then
            object.oAction, changed = HOOT_CARRY, true
        end

        local vx, vz = tonumber(object.oVelX) or 0, tonumber(object.oVelZ) or 0
        local edgeX, edgeZ = HOOT_BOUND * math_abs(fx), HOOT_BOUND * math_abs(fz)
        if lastX ~= nil and x == lastX and math_abs(x + vx) > HOOT_BOUND
            and math_abs(x + vx) <= edgeX then
            object.oPosX, changed = x + vx, true
        elseif math_abs(x) > edgeX and lastX ~= nil then
            object.oPosX, changed = lastX, true
        end
        if lastZ ~= nil and z == lastZ and math_abs(z + vz) > HOOT_BOUND
            and math_abs(z + vz) <= edgeZ then
            object.oPosZ, changed = z + vz, true
        elseif math_abs(z) > edgeZ and lastZ ~= nil then
            object.oPosZ, changed = lastZ, true
        end
    end
    state.x, state.z = object.oPosX, object.oPosZ
    return changed
end
end

do

local KLEPTO_TARGETS = { { 2200.0, 1250.0, -2820.0 }, { -6200.0, 1250.0, -2800.0 },
    { -6200.0, 1250.0, 1150.0 } }
local KLEPTO_RESET_Y = 1500.0
local KLEPTO_AWAY_X, KLEPTO_AWAY_Z = -2000.0, -1000.0
local KLEPTO_RESET, KLEPTO_RETREAT = 5, 7

function warp.land_klepto(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local was, now = object.oPrevAction, object.oAction
    local target = KLEPTO_TARGETS[(tonumber(object.oKleptoTargetNumber) or -1) + 1]

    local climb = tonumber(object.oKleptoUnkF8) or 0
    if target ~= nil and object.oHomeX == target[1] and object.oHomeZ == target[3]
        and object.oHomeY == target[2] + climb then
        object.oHomeX, object.oHomeZ = target[1] * fx, target[3] * fz
        object.oHomeY = object.oHomeY * fy
        object.oKleptoUnkF8 = climb * fy
        if now ~= was then

            local dx, dz = object.oHomeX - object.oPosX, object.oHomeZ - object.oPosZ
            object.oKleptoUnkFC = math_sqrt(dx * dx + dz * dz) / 2
        end
        return true
    end
    if now == KLEPTO_RESET and was == KLEPTO_RETREAT and object.oHomeY == KLEPTO_RESET_Y then
        object.oHomeY = KLEPTO_RESET_Y * fy
        return true
    end
    if object.oHomeX == KLEPTO_AWAY_X and object.oHomeZ == KLEPTO_AWAY_Z then
        object.oHomeX, object.oHomeZ = KLEPTO_AWAY_X * fx, KLEPTO_AWAY_Z * fz
        return true
    end
    return false
end
end

do

local BOO_HOME_X, BOO_HOME_Z, BOO_FADE_Z = -1000.0, -9000.0, -5000.0
local BOO_TURN = 0x5A8

function warp.land_castle_boo(object)
    local ok, fx, _, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    if object.oHomeX ~= BOO_HOME_X or object.oHomeZ ~= BOO_HOME_Z then return false end
    local vx, vz = tonumber(object.oVelX) or 0, tonumber(object.oVelZ) or 0
    local x0, z0 = object.oPosX - vx, object.oPosZ - vz
    local engine = s16(atan2s(BOO_HOME_Z - z0, BOO_HOME_X - x0))
    local from = turned_from(object.oMoveAngleYaw, engine, BOO_TURN)
    local hx, hz = BOO_HOME_X * fx, BOO_HOME_Z * fz
    local yaw = yaw_toward(from, s16(atan2s(hz - z0, hx - x0)), BOO_TURN)
    local speed = tonumber(object.oForwardVel) or 0
    object.oMoveAngleYaw = yaw
    object.oVelX, object.oVelZ = speed * sins(yaw), speed * coss(yaw)
    object.oPosX, object.oPosZ = x0 + object.oVelX, z0 + object.oVelZ
    object.oHomeX, object.oHomeZ = hx, hz

    local fadeV, fadeS = object.oPosZ < BOO_FADE_Z, object.oPosZ < BOO_FADE_Z * fz
    local opacity = tonumber(object.oOpacity) or 0
    if fadeV and not fadeS then
        object.oOpacity = math_min(opacity + 20, 255)
    elseif fadeS and not fadeV then
        object.oOpacity = math_max(opacity - 20, 0)
    end
    return true
end
end

do

local UKIKI_LOW, UKIKI_GONE = -1550.0, -1300.0
local UKIKI_IDLE, UKIKI_GO_TO_CAGE, UKIKI_RETURN_HOME = 0, 4, 7
local UKIKI_CAGE, UKIKI_CAP = 0, 1
local UKIKI_CAGE_DESPAWN = 7

local UKIKI_RUN_TO_CAGE, UKIKI_WAIT_AT_CAGE = 0, 1
local UKIKI_TURN, UKIKI_RUN = 0x400, 10.0

local function ukiki_run_to_cage(object, fx, fy, fz)
    local state = npc_state(object, (tonumber(object.oTimer) or 0) == 0)
    local sub = object.oSubAction
    if sub ~= UKIKI_RUN_TO_CAGE and not (sub == UKIKI_WAIT_AT_CAGE and state.running) then
        return false
    end
    local ended = sub == UKIKI_WAIT_AT_CAGE
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local from = yaw0
    if not ended then from = turned_from(yaw0, tonumber(object.oPathedTargetYaw) or 0, UKIKI_TURN) end
    local answer, toward = follow_vanilla(object, fx, fy, fz, state)
    if answer == nil then return false end
    if answer == -1 then
        state.running = nil
        object.oForwardVel = 0.0
        object.oSubAction = UKIKI_WAIT_AT_CAGE
        return true
    end
    state.running = true
    object.oSubAction = UKIKI_RUN_TO_CAGE
    object.oForwardVel = UKIKI_RUN
    local yaw = yaw_toward(from, toward, UKIKI_TURN)
    if not ended then
        object.oPosX = object.oPosX + UKIKI_RUN * (sins(yaw) - sins(yaw0))
        object.oPosZ = object.oPosZ + UKIKI_RUN * (coss(yaw) - coss(yaw0))
    end
    object.oMoveAngleYaw = yaw
    return true
end

function warp.land_ukiki(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local was, now = object.oPrevAction, object.oAction
    local kind = object.oBehParams2ndByte
    if kind == UKIKI_CAGE and was == UKIKI_GO_TO_CAGE and now == UKIKI_GO_TO_CAGE
        and ukiki_run_to_cage(object, fx, fy, fz) then
        return true
    end

    if fy == 1.0 then return false end
    local y = object.oPosY / fy
    if kind == UKIKI_CAP then
        local low = y < UKIKI_LOW
        if was == UKIKI_IDLE and now == UKIKI_RETURN_HOME and not low then
            object.oAction = UKIKI_IDLE
            return true
        elseif was == UKIKI_IDLE and now == UKIKI_IDLE and low then
            object.oAction = UKIKI_RETURN_HOME
            return true
        elseif was == UKIKI_RETURN_HOME and now == UKIKI_IDLE and low then
            object.oAction = UKIKI_RETURN_HOME
            return true
        elseif was == UKIKI_RETURN_HOME and now == UKIKI_RETURN_HOME and not low then
            object.oAction = UKIKI_IDLE
            return true
        end
    elseif kind == UKIKI_CAGE and was == UKIKI_GO_TO_CAGE
        and object.oSubAction == UKIKI_CAGE_DESPAWN and y < UKIKI_GONE
        and (tonumber(object.activeFlags) or 0) ~= 0 then

        OF.util.optional("obj_mark_for_deletion", nil, object)
        return true
    end
    return false
end
end

do

local MIRROR_X = 0x875C3D / 0x800
local MIRROR_NEAR = 1700.0
local LAKITU_FOLLOW = 0
local LAKITU_START = { 1800.0, 2400.0, -2400.0 }
local LAKITU_FLY = 2

function warp.land_camera_lakitu(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    if object.oBehParams2ndByte ~= LAKITU_FOLLOW then
        if object.oAction == LAKITU_FLY and object.oPrevAction ~= LAKITU_FLY
            and object.oPosX == LAKITU_START[1] and object.oPosZ == LAKITU_START[3] then
            object.oPosX = LAKITU_START[1] * fx
            object.oPosY = LAKITU_START[2] * fy
            object.oPosZ = LAKITU_START[3] * fz
            return true
        end
        return false
    end
    if fx == 1.0 then return false end
    local cam = gLakituState ~= nil and gLakituState.curPos or nil
    if cam == nil or type(cam.x) ~= "number" then return false end
    local mirror = MIRROR_X * fx
    local near = MIRROR_NEAR * fx
    local lo, hi = math_min(near, mirror), math_max(near, mirror)
    if cam.x < lo or cam.x > hi then
        OF.util.optional("cur_obj_hide", nil)
        return true
    end
    OF.util.optional("cur_obj_unhide", nil)
    object.oPosX = mirror + (mirror - cam.x)
    return true
end
end

do
local ARROW_SPEED, ARROW_AHEAD, ARROW_SIDE = 10.0, 300.0, 250.0
local ARROW_PROBE, ARROW_PROBE_MAX = 50.0, 200.0
local ARROW_NEAR, ARROW_SHAKE, ARROW_FLICKER, ARROW_BOB = 400.0, 32, 150, 20.0
local ARROW_REACH = 1000.0
local ARROW_IDLE, ARROW_SHAKING, ARROW_GONE = 0, 5, 6

local ARROW_DIRS = { { 0, 1, 2 }, { 0, -1, 1 }, { 1, 0, 4 }, { -1, 0, 3 } }

local BUTTON_AT = { { 0, 204 }, { 0, -204 }, { 204, 0 }, { -204, 0 } }
local BUTTON_UP, BUTTON_DOWN, BUTTON_STEP, BUTTON_ARM = 51.0, 41.0, 4.0, 30

local function arrow_load(object, reach)
    if type(load_object_collision_model) ~= "function" then return end
    object.oCollisionDistance = reach
    load_object_collision_model()
    object.oCollisionDistance = 0.0
end

local function arrow_ridden(object)
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[i]
        local body = m ~= nil and m.marioObj or nil
        local on = body ~= nil and body.platform or nil
        if on ~= nil and (on == object or on.parentObj == object) then return true end
    end
    return false
end

local function arrow_probe(x, y, z, radius)
    local dist = { x = 0, y = 0, z = 0 }
    local hit = OF.util.optional("obj_find_wall_displacement", 0, dist, x, y, z, radius)
    return hit == 1 or hit == true, dist
end

local function arrow_move(object, state, ax, ay, az)
    local dir = ARROW_DIRS[state]
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    local points
    if dir[1] == 0 then
        local ahead = z + dir[2] * ARROW_AHEAD * az
        points = { { x + ARROW_SIDE * ax, ahead }, { x, ahead }, { x - ARROW_SIDE * ax, ahead } }
    else
        local ahead = x + dir[1] * ARROW_AHEAD * ax
        points = { { ahead, z + ARROW_SIDE * az }, { ahead, z }, { ahead, z - ARROW_SIDE * az } }
    end
    local radius = math_min(ARROW_PROBE * math_max(ax, az), ARROW_PROBE_MAX)
    local hits, moves = {}, {}
    for i = 1, 3 do hits[i], moves[i] = arrow_probe(points[i][1], y, points[i][2], radius) end

    local wall = hits[2] or (hits[1] and hits[3])
    if not wall then
        for _, i in ipairs({ 1, 3 }) do
            if hits[i] then
                local along = dir[1] == 0 and moves[i].z or moves[i].x
                if along >= 1.0 or along <= -1.0 then
                    wall = true
                else
                    object.oPosX = object.oPosX + moves[i].x
                    object.oPosZ = object.oPosZ + moves[i].z
                end
            end
        end
    end
    if wall then
        object.oControllablePlatformUnkF8 = dir[3]
        object.oAction = ARROW_SHAKING
        if SOUND_GENERAL_QUIET_POUND1 ~= nil then
            OF.util.optional("cur_obj_play_sound_2", nil, SOUND_GENERAL_QUIET_POUND1)
        end
    end
    local near = OF.util.optional("is_point_within_radius_of_any_player", true, object.oPosX,
        object.oPosY, object.oPosZ, ARROW_NEAR * math_max(ax, ay, az))
    if near == false or near == 0 then
        object.oAction = ARROW_GONE
        npc_state(object).again = true
    end
    object.oVelX = dir[1] * ARROW_SPEED * ax
    object.oVelZ = dir[2] * ARROW_SPEED * az
    object.oPosX = object.oPosX + object.oVelX
    object.oPosZ = object.oPosZ + object.oVelZ
    if SOUND_ENV_ELEVATOR2 ~= nil then
        OF.util.optional("cur_obj_play_sound_1", nil, SOUND_ENV_ELEVATOR2)
    end
end

local function land_arrow_platform_size(object, ax, ay, az)
    if obj_scale_xyz == nil then return false end
    ax, ay, az = warp.land_grow_axes(object, ax, ay, az)
    local size = object.header ~= nil and object.header.gfx ~= nil and object.header.gfx.scale or nil
    if size ~= nil and (size.x ~= 1.0 or size.y ~= 1.0 or size.z ~= 1.0) then return false end
    return land_size_object(object, ax, warp.land_signed_height(ay), az)
end

warp.land_arrow_platform_size = land_arrow_platform_size

function warp.land_arrow_platform(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)
    land_arrow_platform_size(object, ax, ay, az)
    local state, timer = object.oAction, tonumber(object.oTimer) or 0
    local was = state
    if state == ARROW_SHAKING then

        local back = object.oControllablePlatformUnkF8
        local wave = sins((timer + 1) * 0x1000) * 182.04444 * 10.0
        if back == 1 or back == 2 then
            object.oFaceAnglePitch = wave
        else
            object.oFaceAngleRoll = wave
        end
        local base = tonumber(object.oControllablePlatformUnkFC) or object.oPosY
        object.oPosY = base + sins((timer + 1) * 0x2000) * ARROW_BOB * ay
        if timer + 1 >= ARROW_SHAKE then
            object.oFaceAnglePitch, object.oFaceAngleRoll = 0, 0
            object.oPosY = base
            object.oAction = back
        end
    elseif state == ARROW_GONE then
        if arrow_ridden(object) then

            object.oAction = ARROW_IDLE
            OF.util.optional("cur_obj_unhide", nil)
        elseif OF.util.optional("obj_flicker_and_disappear", false, object, ARROW_FLICKER) == true then

            object.activeFlags = ACTIVE_FLAG_ACTIVE or 1
            OF.util.optional("cur_obj_unhide", nil)
            object.oPosX, object.oPosY, object.oPosZ = object.oHomeX, object.oHomeY, object.oHomeZ
            object.oVelX, object.oVelZ = 0, 0
            object.oAction = ARROW_IDLE
            npc_state(object).again = nil
        end
    elseif state == ARROW_IDLE then
        if npc_state(object).again and timer > 30 then object.oAction = ARROW_GONE end
    elseif ARROW_DIRS[state] ~= nil then
        arrow_move(object, state, ax, ay, az)
    end
    local sync = tonumber(object.oSyncID)
    if object.oAction ~= was and sync ~= nil and sync ~= 0
        and OF.util.optional("sync_object_is_owned_locally", false, sync) == true then
        OF.util.optional("network_send_object", nil, object, false)
    end
    arrow_load(object, ARROW_REACH * math_max(ax, ay, az))
    return true
end

local function land_arrow_button(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local parent, kind = object.parentObj, object.oBehParams2ndByte
    local at = BUTTON_AT[kind]
    if parent == nil or at == nil then return false end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)

    object.oTimer, object.oAction = 0, 0
    local state = npc_state(object)
    local y = state.y or BUTTON_UP
    local down = parent.oAction == kind
    if down then
        y = math_max(y - BUTTON_STEP, BUTTON_DOWN)
        state.up = 0
    elseif y < BUTTON_UP then
        y = math_min(y + BUTTON_STEP, BUTTON_UP)
        state.up = 0
    else
        state.up = (state.up or 0) + 1
    end

    local m = gMarioStates[0]
    local body = m ~= nil and m.marioObj or nil
    if not down and y >= BUTTON_UP and state.up > BUTTON_ARM and body ~= nil
        and body.platform == object then
        parent.oAction = kind
        if SOUND_GENERAL_MOVING_PLATFORM_SWITCH ~= nil then
            OF.util.optional("cur_obj_play_sound_2", nil, SOUND_GENERAL_MOVING_PLATFORM_SWITCH)
        end
        OF.util.optional("network_send_object", nil, parent, false)
    end
    state.y = y
    object.oParentRelativePosX = at[1] * fx
    object.oParentRelativePosY = y * fy
    object.oParentRelativePosZ = at[2] * fz
    local sx, sy, sz = warp.land_grow_axes(object, ax, ay, az)
    land_size_object(object, sx, warp.land_signed_height(sy), sz)
    arrow_load(object, ARROW_REACH * math_max(ax, ay, az))
    return true
end
warp.land_arrow_button = land_arrow_button

land_hook_motion(id_bhvControllablePlatform, nil, warp.land_arrow_platform, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvControllablePlatformSub, nil, land_arrow_button, OBJ_LIST_SURFACE)
end

do
local THWOMP_HEARD = 1500.0
local THWOMP_LANDED = 3
local KICK_ABOVE = 160.0
local PLANK_UNDER = 300.0
local DONUT_NEAR, DONUT_FAR, DONUT_DROP = 1000.0, 2000.0, 2500.0
local DONUT_GONE = 2

local function size_of(fx, fy, fz)
    return math_max(math_abs(fx), math_abs(fy), math_abs(fz))
end

function warp.land_thwomp_slam(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    if object.oAction ~= THWOMP_LANDED or object.oPrevAction ~= THWOMP_LANDED
        or (tonumber(object.oTimer) or 0) ~= 0 then return false end
    local s = size_of(fx, fy, fz)
    local body = gMarioStates[0] ~= nil and gMarioStates[0].marioObj or nil
    if s <= 1.0 or body == nil then return false end
    local d = dist3(object, body.oPosX, body.oPosY, body.oPosZ)
    if d < THWOMP_HEARD or d >= THWOMP_HEARD * s then return false end
    OF.util.optional("cur_obj_shake_screen", nil, SHAKE_POS_SMALL or 1)
    if SOUND_OBJ_THWOMP ~= nil then
        OF.util.optional("cur_obj_play_sound_2", nil, SOUND_OBJ_THWOMP)
    end
    return true
end

local function kicked_high(object, m)
    local body = m.marioObj
    if body == nil then return false end
    local touched = OF.util.optional("obj_check_if_collided_with_object", 0, object, body)
    if touched ~= 1 and touched ~= true then return false end
    if math_abs(s16((tonumber(object.oMoveAngleYaw) or 0) - (tonumber(body.oMoveAngleYaw) or 0)))
        <= 0x6000 then return false end
    return m.action == ACT_JUMP_KICK or m.action == ACT_WALL_KICK_AIR
end

function warp.land_kickable_board(object)
    local ok, _, fy = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local ay = math_abs(fy)
    local state = npc_state(object)
    local start = state.timer
    state.timer = (tonumber(object.oTimer) or 0) + 1
    if ay >= 1.0 or object.oPrevAction ~= 1 or object.oAction ~= 1 then return false end

    if start == nil or start <= 30 or object.oTimer ~= 0 then return false end
    local m = OF.util.optional("nearest_mario_state_to_object", nil, object) or gMarioStates[0]
    if m == nil or m.marioObj == nil then return false end
    if m.marioObj.oPosY <= object.oPosY + KICK_ABOVE * ay then return false end
    if not kicked_high(object, m) then return false end
    object.oAction = 2
    state.timer = nil
    if SOUND_GENERAL_BUTTON_PRESS_2 ~= nil then
        OF.util.optional("cur_obj_play_sound_2", nil, SOUND_GENERAL_BUTTON_PRESS_2)
    end
    local sync = tonumber(object.oSyncID)
    if sync ~= nil and sync ~= 0
        and OF.util.optional("sync_object_is_owned_locally", false, sync) == true then
        OF.util.optional("network_send_object", nil, object, false)
    end
    return true
end

function warp.land_plank_fall(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or object.oPrevAction ~= 2 then return false end
    local s = size_of(fx, fy, fz)
    local floor = tonumber(object.oFloorHeight)
    if s == 1.0 or floor == nil then return false end
    local under = object.oPosY < floor - PLANK_UNDER * s
    if object.oAction == 3 and not under then
        object.oAction = 2
        return true
    elseif object.oAction == 2 and under then
        object.oAction = 3
        return true
    end
    return false
end

function warp.land_donut(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local s = size_of(fx, fy, fz)
    if s == 1.0 then return false end
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    if player == nil and gMarioStates[0] ~= nil then player = gMarioStates[0].marioObj end
    if player == nil then return false end
    local d = dist3(object, player.oPosX, player.oPosY, player.oPosZ)
    local was, now = object.oPrevAction, object.oAction
    if was == DONUT_GONE then
        local back = d > DONUT_NEAR * s and d < DONUT_FAR * s
        if now ~= DONUT_GONE and not back then
            OF.util.optional("cur_obj_hide", nil)
            OF.util.optional("cur_obj_become_intangible", nil)
            object.oPosX, object.oPosY, object.oPosZ = object.oHomeX, object.oHomeY, object.oHomeZ
            object.oAction = DONUT_GONE
            return true
        elseif now == DONUT_GONE and back then
            OF.util.optional("cur_obj_unhide", nil)
            OF.util.optional("cur_obj_become_tangible", nil)
            object.oAction = 0
            return true
        end
        return false
    end
    if now == DONUT_GONE and d > DONUT_DROP and d <= DONUT_DROP * s then

        local flags = object.activeFlags
        OF.util.optional("obj_explode_and_spawn_coins", nil, 150.0, 1)
        object.activeFlags = flags
        if SOUND_GENERAL_DONUT_PLATFORM_EXPLOSION ~= nil then
            OF.util.optional("create_sound_spawner", nil, SOUND_GENERAL_DONUT_PLATFORM_EXPLOSION)
        end
        OF.util.optional("network_send_object", nil, object, false)
        return true
    end
    return false
end

land_hook_motion(id_bhvThwomp, nil, warp.land_thwomp_slam, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvThwomp2, nil, warp.land_thwomp_slam, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvGrindel, nil, warp.land_thwomp_slam, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvKickableBoard, nil, warp.land_kickable_board, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvTumblingBridgePlatform, nil, warp.land_plank_fall, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvDonutPlatform, nil, warp.land_donut, OBJ_LIST_SURFACE)
end

do
local BOO_WAIT_X, BOO_WAIT_Z, BOO_STAIR_Z = 973.0, 626.0, 717.0
local BOO_BEATEN = 4
local STEP_RISE, STEP_UNDER = 8.0, 620.0
local STEP_TOPS = { [0] = -206.0, [1] = 0.0, [2] = -413.0 }
local SHELF_STEP = 5.0
local SUMMIT_POUND = 500.0
local GRAPH_INVISIBLE = 0x10

function warp.land_ghost_hunt_boo(object)
    local ok, fx, _, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    if object.oAction ~= BOO_BEATEN or object.oBehParams2ndByte ~= 0 then return false end
    if object.oPosX ~= BOO_WAIT_X or object.oPosZ ~= BOO_WAIT_Z then return false end
    object.oPosX, object.oPosZ = BOO_WAIT_X * fx, BOO_WAIT_Z * fz
    return true
end

function warp.land_boo_step_init(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    local hx, hz = object.oHomeX, object.oHomeZ
    if math_abs(hx - BOO_WAIT_X) > 300 or math_abs(hz - BOO_STAIR_Z) > 300 then return false end
    object.oHomeX, object.oHomeY, object.oHomeZ = hx * fx, object.oHomeY * fy, hz * fz
    object.oPosX, object.oPosZ = object.oHomeX, object.oHomeZ
    local state = npc_state(object, true)
    state.y = object.oHomeY - (STEP_UNDER - STEP_RISE) * math_abs(fy)
    object.oPosY = state.y
    land_grow_object(object, math_abs(fx), math_abs(fy), math_abs(fz))
    return true
end

function warp.land_boo_step(object)
    local ok, _, fy = motion_shape()
    if not ok or object == nil then return false end
    local state = npcState[object]
    if state == nil or state.y == nil or object.oPrevAction ~= 1 then return false end
    local top = (STEP_TOPS[object.oBehParams2ndByte] or 0.0) * fy
    state.y = state.y + STEP_RISE * math_abs(fy)
    if state.y > top then
        state.y = top
        object.oAction = 2
    else
        object.oAction = 1
    end
    object.oPosY = state.y
    if object.oAction == 2 then state.y = nil end
    return true
end

function warp.land_bookshelf(object)
    local ok, fx = motion_shape()
    if not ok or object == nil or fx == 1.0 then return false end
    if object.oAction ~= 1 or object.oPrevAction ~= 1 then return false end
    object.oPosX = object.oPosX + SHELF_STEP * (fx - 1.0)
    return true
end

function warp.land_tiny_summit(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    if object.oAction ~= 0 then return false end
    local s = math_max(math_abs(fx), math_abs(fy), math_abs(fz))
    if s <= 1.0 then return false end

    local header = object.header
    local flags = header ~= nil and header.gfx ~= nil and header.gfx.node ~= nil
        and header.gfx.node.flags or 0
    if OF.util.has_flag(tonumber(flags) or 0, GRAPH_INVISIBLE) then return false end
    local m = OF.util.optional("nearest_mario_state_to_object", nil, object) or gMarioStates[0]
    local body = m ~= nil and m.marioObj or nil
    if body == nil then return false end
    local d = dist3(object, body.oPosX, body.oPosY, body.oPosZ)
    if d < SUMMIT_POUND or d >= SUMMIT_POUND * s then return false end
    local landing = OF.util.optional("mario_is_ground_pound_landing", false, m)
    if landing ~= true and landing ~= 1 then return false end

    object.oAction = 1
    OF.util.optional("spawn_triangle_break_particles", nil, 20, 138, 0.3, 3)
    if SOUND_GENERAL_ACTIVATE_CAP_SWITCH ~= nil then
        OF.util.optional("cur_obj_play_sound_2", nil, SOUND_GENERAL_ACTIVATE_CAP_SWITCH)
    end
    OF.util.optional("cur_obj_hide", nil)
    OF.util.optional("network_send_object", nil, object, false)
    return true
end

land_hook_motion(id_bhvGhostHuntBigBoo, nil, warp.land_ghost_hunt_boo, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvBooBossSpawnedBridge, warp.land_boo_step_init, warp.land_boo_step,
    OBJ_LIST_SURFACE)
land_hook_motion(id_bhvHauntedBookshelf, nil, warp.land_bookshelf, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvThiTinyIslandTop, nil, warp.land_tiny_summit, OBJ_LIST_DEFAULT)
end

land_hook_motion(id_bhvSnowmansBottom, nil, warp.land_snowman_bottom, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvSnowmansHead, warp.land_snowman_head_init, warp.land_snowman_head,
    OBJ_LIST_DEFAULT)
land_hook_motion(id_bhvYoshi, nil, warp.land_yoshi, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvHoot, warp.land_hoot_init, warp.land_hoot, OBJ_LIST_POLELIKE)
land_hook_motion(id_bhvKlepto, nil, warp.land_klepto, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvBooInCastle, nil, warp.land_castle_boo, OBJ_LIST_DEFAULT)
land_hook_motion(id_bhvUkiki, nil, warp.land_ukiki, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvMacroUkiki, nil, warp.land_ukiki, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvCameraLakitu, nil, warp.land_camera_lakitu, OBJ_LIST_DEFAULT)
end

function warp.land_layout_child(object, fx, fy, fz)
    if object == nil or obj_has_behavior_id == nil then return false end

    local function is(id) return id ~= nil and obj_has_behavior_id(object, id) ~= 0 end
    local ok, layout = pcall(function()
        return is(id_bhvTumblingBridgePlatform) or is(id_bhvDonutPlatform)
            or is(id_bhvLllWoodPiece) or is(id_bhvCoffin)
    end)
    if not (ok and layout) then return false end
    local parent = object.parentObj
    if parent == nil then return false end
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    local homed = object.oHomeX == x and object.oHomeY == y and object.oHomeZ == z
    object.oPosX = px + (x - px) * fx
    object.oPosY = py + (y - py) * fy
    object.oPosZ = pz + (z - pz) * fz
    if homed then
        object.oHomeX, object.oHomeY, object.oHomeZ = object.oPosX, object.oPosY, object.oPosZ
    end
    return true
end

do

function warp.land_coin_formation(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    if object.oPrevAction ~= 0 or object.oAction ~= 1 then return false end
    if id_bhvCoinFormationSpawn == nil then return false end

    if not warp.land_route_kit.level_own(object) then return false end
    local ax, az = math_abs(fx), math_abs(fz)
    local ky = math_min(1.0, math_abs(fy)) * (fy < 0 and -1.0 or 1.0)
    local px, py, pz = object.oPosX, object.oPosY, object.oPosZ
    local laid = 0
    local coin = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvCoinFormationSpawn)
    local guard = 0
    while coin ~= nil and guard < 256 do
        if coin.parentObj == object and (tonumber(coin.oTimer) or 0) == 0 then
            coin.oPosX = px + (coin.oPosX - px) * ax
            coin.oPosY = py + (coin.oPosY - py) * ky
            coin.oPosZ = pz + (coin.oPosZ - pz) * az
            laid = laid + 1
        end
        guard = guard + 1
        coin = OF.util.optional("obj_get_next_with_same_behavior_id", nil, coin)
    end
    return laid > 0
end

land_hook_motion(id_bhvCoinFormation, nil, warp.land_coin_formation, OBJ_LIST_SPAWNER)

local POST_REACH, POST_TURNS, POST_TIME, POST_SINK = 400.0, 0x30000, 200, -190.0
local POST_NO_COINS = 0x0000FF00

function warp.land_wooden_post(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)
    local off = tonumber(object.oWoodenPostOffsetY) or 0
    if off ~= 0 then
        local home = tonumber(object.oHomeY)
        if home ~= nil then object.oPosY = home + math_max(off, POST_SINK) * ay end
        return true
    end
    local bp = tonumber(object.oBehParams) or 0
    if math_floor(bp / 0x100) % 0x100 ~= 0 then return false end

    if not warp.land_route_kit.level_own(object) then return false end
    local state = warp.land_route_kit.npc_state(object)
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    if player == nil then return false end
    local dx, dy, dz = player.oPosX - object.oPosX, player.oPosY - object.oPosY,
        player.oPosZ - object.oPosZ
    local near = math_sqrt((dx / ax) ^ 2 + (dy / ay) ^ 2 + (dz / az) ^ 2) <= POST_REACH
    local angle = atan2s(dz, dx)
    if not near then
        state.total, state.timer = 0, 0
    else
        local step = (angle - (state.lastAngle or angle)) % 0x10000
        if step >= 0x8000 then step = step - 0x10000 end
        state.total = (state.total or 0) + step
        state.timer = (state.timer or 0) + 1
    end
    state.lastAngle = angle

    local f = math_max(ax, az, 1.0)
    object.oWoodenPostTotalMarioAngle = state.total
    object.oWoodenPostPrevAngleToMario = angle
    object.oTimer = math_floor((state.timer or 0) / f)
    if near and math_abs(state.total) > POST_TURNS and state.timer < POST_TIME * f then
        OF.util.optional("obj_spawn_loot_yellow_coins", nil, object, 5, 20.0)
        OF.util.optional("set_object_respawn_info_bits", nil, object, 1)
        object.oBehParams = POST_NO_COINS
        OF.util.optional("network_send_object", nil, object, false)
        state.total, state.timer = 0, 0
    end
    return true
end

land_hook_motion(id_bhvWoodenPost, nil, warp.land_wooden_post, OBJ_LIST_SURFACE)

local WIND_TALK_X, WIND_TALK_Y, WIND_TALK_Z = 1100.0, 3328.0, 1164.0
local WIND_TALK_REACH, WIND_TALK_UNDER, WIND_TALK_OVER = 1000.0, 160.0, 30.0
local WIND_BLOW_REACH, WIND_BLOW_HIGH, WIND_TURN = 1500.0, 500.0, 0x1500
local WIND_IDLE, WIND_TALKING, WIND_BLOWING = 0, 1, 2

function warp.land_snowman_wind(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    if not warp.land_route_kit.level_own(object) then return false end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)
    local sub = object.oSubAction
    if sub == WIND_IDLE then
        local m = gMarioStates[0]
        local body = m ~= nil and m.marioObj or nil
        if body == nil or m.visibleToObjects == false or m.visibleToObjects == 0 then return false end
        local dx, dz = (body.oPosX - WIND_TALK_X * fx) / ax, (body.oPosZ - WIND_TALK_Z * fz) / az
        local py = WIND_TALK_Y * fy
        local air = ACT_FLAG_AIR ~= nil and OF.util.has_flag(tonumber(m.action) or 0, ACT_FLAG_AIR)
        if math_sqrt(dx * dx + dz * dz) < WIND_TALK_REACH and py < body.oPosY + WIND_TALK_UNDER * ay
            and body.oPosY < py + WIND_TALK_OVER * ay and not air
            and OF.util.optional("mario_ready_to_speak", 0, m) ~= 0 then
            object.oSubAction = WIND_TALKING
            return true
        end
        return false
    end
    if sub ~= WIND_BLOWING then return false end
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    if player == nil then return false end
    local dx, dy, dz = player.oPosX - object.oPosX, player.oPosY - object.oPosY,
        player.oPosZ - object.oPosZ

    if math_sqrt(dx * dx + dy * dy + dz * dz) < WIND_BLOW_REACH
        and math_abs(player.oPosY - object.oHomeY) < WIND_BLOW_HIGH then return false end
    local vanilla = math_sqrt((dx / ax) ^ 2 + (dy / ay) ^ 2 + (dz / az) ^ 2)
    if vanilla >= WIND_BLOW_REACH or math_abs(player.oPosY - object.oHomeY) / ay >= WIND_BLOW_HIGH then
        return false
    end
    local toward = atan2s(dz, dx)
    local base = tonumber(object.oSLSnowmanWindOriginalYaw) or 0
    local off = (toward - base) % 0x10000
    if off >= 0x8000 then off = off - 0x10000 end
    if off > WIND_TURN then off = WIND_TURN elseif off < -WIND_TURN then off = -WIND_TURN end
    object.oMoveAngleYaw = (base + off) % 0x10000
    OF.util.optional("cur_obj_spawn_strong_wind_particles", nil, 12, 3.0, 0, 0, 0)
    if SOUND_AIR_BLOW_WIND ~= nil then
        OF.util.optional("cur_obj_play_sound_1", nil, SOUND_AIR_BLOW_WIND)
    end
    return true
end

function warp.land_wind_particle(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)
    local yaw = tonumber(object.oMoveAngleYaw) or 0

    local across = math_sqrt((sins(yaw) * ax) ^ 2 + (coss(yaw) * az) ^ 2)
    object.oForwardVel = (tonumber(object.oForwardVel) or 0) * across
    object.oVelY = (tonumber(object.oVelY) or 0) * ay
    return true
end

land_hook_motion(id_bhvSLSnowmanWind, nil, warp.land_snowman_wind, OBJ_LIST_DEFAULT)
land_hook_motion(id_bhvStrongWindParticle, warp.land_wind_particle, nil, OBJ_LIST_POLELIKE)

local FLAME_WAKE = 2000.0
local FLAME_UP = 4

function warp.land_flamethrower(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or object.oAction ~= 0 then return false end
    if not warp.land_route_kit.level_own(object) then return false end

    if LEVEL_BBH ~= nil and gNetworkPlayers[0] ~= nil
        and gNetworkPlayers[0].currLevelNum == LEVEL_BBH then return false end
    local m = OF.util.optional("nearest_mario_state_to_object", nil, object)
    if m == nil or m.playerIndex ~= 0 or m.marioObj == nil then return false end
    local body = m.marioObj
    local dx, dy, dz = body.oPosX - object.oPosX, body.oPosY - object.oPosY,
        body.oPosZ - object.oPosZ
    local vanilla = math_sqrt((dx / math_abs(fx)) ^ 2 + (dy / math_abs(fy)) ^ 2
        + (dz / math_abs(fz)) ^ 2)
    if vanilla >= FLAME_WAKE then return false end
    object.oAction = 1
    OF.util.optional("network_send_object", nil, object, false)
    return true
end

function warp.land_flame(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    local vel = tonumber(object.oForwardVel) or 0
    if object.oBehParams2ndByte == FLAME_UP then
        object.oForwardVel = vel * math_abs(fy)
    else
        local yaw = tonumber(object.oMoveAngleYaw) or 0
        object.oForwardVel = vel * math_sqrt((sins(yaw) * fx) ^ 2 + (coss(yaw) * fz) ^ 2)
    end
    return true
end

land_hook_motion(id_bhvFlamethrower, nil, warp.land_flamethrower, OBJ_LIST_DEFAULT)
land_hook_motion(id_bhvRrRotatingBridgePlatform, nil, warp.land_flamethrower, OBJ_LIST_SURFACE)
land_hook_motion(id_bhvFlamethrowerFlame, warp.land_flame, nil, OBJ_LIST_GENACTOR)
end

do
local BRIDGE_WAKE, BRIDGE_KEEP = 1000.0, 1200.0

function warp.land_bridge_reach(object)
    local ok, ax, _, az = motion_size()
    if not ok or object == nil then return false end
    local f = math_max(ax, az)
    if f <= 1.0 then return false end
    local action = object.oAction
    if action ~= 0 and not (action == 3 and object.oPrevAction == 2) then return false end
    local nearest = nil
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        local body = m ~= nil and m.marioObj or nil
        if body ~= nil and (type(is_player_active) ~= "function" or is_player_active(m) ~= 0) then

            local dx, dy, dz = body.oPosX - object.oPosX, body.oPosY - object.oPosY,
                body.oPosZ - object.oPosZ
            local d = math_sqrt(dx * dx + dy * dy + dz * dz)
            if nearest == nil or d < nearest then nearest = d end
        end
    end
    if nearest == nil then return false end
    if action == 0 and nearest < BRIDGE_WAKE * f then
        object.oAction = 1
        return true
    end
    if action == 3 and nearest <= BRIDGE_KEEP * f then
        object.oAction = 2
        return true
    end
    return false
end

local function land_bridge_size(object)
    local ok, ax, ay, az = motion_size()
    if not ok or object == nil or obj_scale_xyz == nil then return false end
    ax, ay, az = warp.land_grow_axes(object, ax, ay, az)
    return land_size_object(object, ax, warp.land_signed_height(ay), az)
end

warp.land_bridge_size = land_bridge_size

land_hook_motion(id_bhvWfTumblingBridge, warp.land_bridge_size, warp.land_bridge_reach, OBJ_LIST_SPAWNER)
land_hook_motion(id_bhvBbhTumblingBridge, warp.land_bridge_size, warp.land_bridge_reach, OBJ_LIST_SPAWNER)
land_hook_motion(id_bhvLllTumblingBridge, warp.land_bridge_size, nil, OBJ_LIST_SPAWNER)
end

local SQUISH_REACH = 10000.0

local function land_squish_platform(object)

    if type(load_object_collision_model) ~= "function" then return false end
    local ok, _, ay = motion_size()

    local shut = (object.oCollisionDistance == 0.0)
    if not ok then

        if shut then object.oCollisionDistance = SQUISH_REACH end
        return false
    end
    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    local scale = gfx ~= nil and gfx.scale or nil
    if scale == nil then return false end

    if not shut then
        object.oCollisionDistance = 0.0
        return false
    end
    local tall = scale.y
    if type(tall) ~= "number" then return false end
    object.oCollisionDistance = SQUISH_REACH
    scale.y = tall * warp.land_signed_height(ay)
    load_object_collision_model()
    object.oCollisionDistance = 0.0
    return true
end

warp.land_squish_platform = land_squish_platform

local function land_squish_init(object)
    if type(load_object_collision_model) ~= "function" then return false end
    local ok = motion_size()
    if not ok then return land_squish_platform(object) end
    warp.landMotion = (warp.landMotion or 0) + 1
    return land_squish_platform(object)
end

land_hook_motion(id_bhvSquishablePlatform, land_squish_init,
    land_squish_platform)

local WF_EXTEND = 1
local WF_RETRACT = 2
local WF_SLIDE_SNAP = 510.0

local WF_CYCLE = 152

local function brick_on_x(object)
    local yaw = object.oMoveAngleYaw
    if type(yaw) ~= "number" then return false end
    return math_abs(sins(yaw)) > 0.999
end

local function land_brick_leg(object)
    local ok, ax = motion_size()
    if not ok then return false end
    if ax <= 1.0 then return false end
    if not brick_on_x(object) then return false end

    local running = object.oPrevAction
    local timer = object.oTimer
    local vel = object.oWFSlidBrickPtfmMovVel
    if type(running) ~= "number" or type(timer) ~= "number" then return false end

    if running == WF_EXTEND and type(vel) == "number" and vel ~= 0.0
        and timer >= 500.0 / vel then
        local home = object.oHomeX
        if type(home) == "number" then
            object.oPosX = home + WF_SLIDE_SNAP * ax
        end
    end

    if object.oAction ~= running then return false end

    if running ~= WF_EXTEND and running ~= WF_RETRACT then return false end
    local count = object.oSubAction
    if type(count) ~= "number" then count = 0 end
    count = count + 1
    object.oSubAction = count
    object.oTimer = math_floor(count / ax) - 1
    return true
end

warp.land_brick_leg = land_brick_leg

local function land_brick_init(object)
    local ok, ax = motion_size()
    if not ok then return false end
    if ax < 1.0 or not brick_on_x(object) then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    warp.landMotion = (warp.landMotion or 0) + 1
    if ax > 1.0 then
        local cycle = object.areaTimerDuration
        if type(cycle) == "number" and cycle == WF_CYCLE then

            object.areaTimerDuration = math.ceil(60 * ax) + math.ceil(90 * ax) + 2
        end
    end
    return land_brick_leg(object)
end

land_hook_motion(id_bhvWfSlidingPlatform, land_brick_init, land_brick_leg)

do

local LIFT_CLIMB = 141
local LIFT_FLIP = 141

local LIFT_MIN = 1
local LIFT_ACT_UP = 1
local LIFT_ACT_DOWN = 3

local function lift_climb(factor)
    local travel = LIFT_CLIMB * factor
    local mirrored = travel < 0.0
    local climbs = math_floor(math_abs(travel) + 0.5)
    if climbs < LIFT_MIN then return LIFT_MIN, false, mirrored end
    return climbs, true, mirrored
end

warp.land_tower_lift_climb = lift_climb

local function land_tower_lift(object)
    local ok, _, fy = motion_shape()
    if not ok then return false end
    local action = object.oAction
    if type(action) ~= "number" then return false end

    if action ~= object.oPrevAction then return false end

    if action ~= LIFT_ACT_UP and action ~= LIFT_ACT_DOWN then return false end
    local climbs = lift_climb(fy)

    if climbs == LIFT_CLIMB then return false end
    local count = object.oSubAction
    if type(count) ~= "number" then count = 0 end
    count = count + 1
    object.oSubAction = count
    object.oTimer = math_floor(count * LIFT_FLIP / climbs) - 1
    return true
end

warp.land_tower_lift = land_tower_lift

local function land_tower_lift_init(object)
    local ok, _, fy = motion_shape()
    if not ok then return false end

    local _, exact, mirrored = lift_climb(fy)
    if exact and not mirrored then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_tower_lift(object)
end

land_hook_motion(id_bhvTowerPlatformGroup, warp.land_tower_group_init, nil)
land_hook_motion(id_bhvWfElevatorTowerPlatform, land_tower_lift_init,
    land_tower_lift)

end

do

local function land_child_from_parent(object, refX, refY, refZ, kept)
    local ok, fx, fy, fz = motion_shape()
    if not ok then return false end

    if kept then
        local sy = fy < 0 and -1.0 or 1.0
        fx, fz = math_min(1.0, math_abs(fx)), math_min(1.0, math_abs(fz))
        fy = sy * math_min(1.0, math_abs(fy))
        if fx == 1.0 and fz == 1.0 and fy == 1.0 then return false end
    end
    local ox, oy, oz = object.oPosX, object.oPosY, object.oPosZ
    if type(ox) ~= "number" or type(oy) ~= "number" or type(oz) ~= "number"
        or type(refX) ~= "number" or type(refY) ~= "number"
        or type(refZ) ~= "number" then return false end
    local dx, dy, dz = warp.land_attach_offset(ox - refX, oy - refY, oz - refZ,
        fx, fy, fz)
    if dx == nil then return false end
    object.oPosX, object.oPosY, object.oPosZ = refX + dx, refY + dy, refZ + dz
    return true
end

local function land_cloud_part(object)
    local parent = object.parentObj
    if parent == nil then return false end

    return land_child_from_parent(object, parent.oCloudCenterX,
        parent.oCloudCenterY, parent.oPosZ, true)
end

local function land_cloud_part_init(object)
    local wrote = land_cloud_part(object)
    if wrote then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return wrote
end

land_hook_motion(id_bhvCloudPart, land_cloud_part_init, land_cloud_part,
    OBJ_LIST_DEFAULT)

local DORRIE_MOVE, DORRIE_REACH = 0, 30000.0
local DORRIE_IN, DORRIE_OUT, DORRIE_NECK, DORRIE_CIRCLE = 1650.0, 2300.0, 440.0, 2000.0

local function dorrie_ridden(object)
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[i]
        local body = m ~= nil and m.marioObj or nil
        if body ~= nil and body.platform == object then return true end
    end
    return false
end

local function land_dorrie(object)
    local ok, fx, _, fz = motion_shape()
    if not ok or object == nil then return false end
    local hx, hz = object.oHomeX, object.oHomeZ
    if type(hx) ~= "number" or type(hz) ~= "number" then return false end
    local kit = warp.land_route_kit
    local s16, toward, scaled_yaw = kit.s16, kit.yaw_toward, kit.scaled_yaw
    local ax, az = math_abs(fx), math_abs(fz)
    local state = kit.npc_state(object)
    if state.vx == nil then

        state.vx, state.vz = object.oPosX - hx, object.oPosZ - hz
        state.yaw = s16(tonumber(object.oMoveAngleYaw) or 0)
        state.yawVel = tonumber(object.oDorrieYawVel) or 0
    else

        local fvel = tonumber(state.fvel) or 0
        state.vx = state.vx + fvel * sins(state.yaw)
        state.vz = state.vz + fvel * coss(state.yaw)

        local home = atan2s(-state.vz, -state.vx)
        local d = math_sqrt(state.vx * state.vx + state.vz * state.vz)
        local shift = DORRIE_NECK * coss(tonumber(object.oDorrieNeckAngle) or 0)
            * coss(state.yaw - home)
        local lo, hi = DORRIE_IN + shift, DORRIE_OUT + shift
        if d < lo or d > hi then
            d = math_min(math_max(d, lo), hi)
            state.vx, state.vz = -d * sins(home), -d * coss(home)
        end

        if object.oAction == DORRIE_MOVE and not dorrie_ridden(object)
            and (tonumber(object.oForwardVel) or 0) ~= 0 then
            local turn = 0x4000 - atan2s(DORRIE_CIRCLE, d - DORRIE_CIRCLE)
            if s16(state.yaw - home) < 0 then turn = -turn end
            local target = s16(home + turn)
            state.yawVel = toward(state.yawVel, math_floor(s16(target - state.yaw) / 50), 5)
            state.yaw = s16(state.yaw + state.yawVel)
        else

            local y = tonumber(object.oMoveAngleYaw) or 0
            state.yaw = s16(atan2s(coss(y) / az, sins(y) / ax))
            state.yawVel = tonumber(object.oDorrieYawVel) or 0
        end
    end
    state.fvel = tonumber(object.oForwardVel) or 0
    local was = tonumber(object.oMoveAngleYaw) or 0
    local drawn = scaled_yaw(state.yaw, ax, az)
    object.oPosX, object.oPosZ = hx + state.vx * ax, hz + state.vz * az
    object.oMoveAngleYaw, object.oFaceAngleYaw = drawn, drawn
    object.oDorrieYawVel = state.yawVel
    object.oAngleVelYaw = s16(drawn - was)
    if type(load_object_collision_model) == "function" then
        object.oCollisionDistance = DORRIE_REACH * math_max(ax, az, 1.0)
        load_object_collision_model()
        object.oCollisionDistance = 0.0
    end
    return true
end

warp.land_dorrie = land_dorrie

local function land_dorrie_init(object)

    warp.land_route_kit.npc_state(object, true)
    local wrote = land_dorrie(object)
    if wrote then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return wrote
end

land_hook_motion(id_bhvDorrie, land_dorrie_init, land_dorrie,
    OBJ_LIST_SURFACE)

warp.EYEROK_REACH = 400
warp.EYEROK_FAR = 100000

function warp.eyerok_sees_front(object, fz)
    if object == nil or type(object.oPosZ) ~= "number" then return false end
    if type(fz) ~= "number" or fz == 0.0 then return false end
    local home = object.oPosZ
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        local body = m ~= nil and m.marioObj or nil
        local active = body ~= nil and (type(is_player_active) ~= "function"
            or is_player_active(m) ~= 0)
        if active and type(body.oPosZ) == "number"
            and (body.oPosZ - home) / fz >= warp.EYEROK_REACH then
            return true
        end
    end
    return false
end

function warp.land_eyerok(object)
    local ok, _, _, fz = motion_shape()
    if not ok or fz == 1.0 then return false end
    if fz > 1.0 then return false end
    if object == nil or type(object.oPosZ) ~= "number" then return false end
    if warp.eyerok_sees_front(object, fz) then
        object.oHomeZ = object.oPosZ - warp.EYEROK_FAR
    else
        object.oHomeZ = object.oPosZ + warp.EYEROK_FAR
    end
    return true
end

land_hook_motion(id_bhvEyerokBoss, nil, warp.land_eyerok, OBJ_LIST_GENACTOR)

do

local EYEROK_WAKE = 500.0
local EYEROK_SLEEP, EYEROK_WAKE_UP = 0, 1

function warp.land_eyerok_wake(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or object.oAction ~= EYEROK_SLEEP then return false end
    if (tonumber(object.oTimer) or 0) == 0 then return false end
    local sync = object.parentObj ~= nil and tonumber(object.parentObj.oSyncID) or nil
    if sync ~= nil and sync ~= 0
        and OF.util.optional("sync_object_is_owned_locally", true, sync) == false then
        return false
    end
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    if player == nil then return false end
    local dx = (player.oPosX - object.oPosX) / math_abs(fx)
    local dy = (player.oPosY - object.oPosY) / math_abs(fy)
    local dz = (player.oPosZ - object.oPosZ) / math_abs(fz)
    if math_sqrt(dx * dx + dy * dy + dz * dz) >= EYEROK_WAKE then return false end
    if SOUND_OBJ_EYEROK_EXPLODE ~= nil then
        OF.util.optional("cur_obj_play_sound_2", nil, SOUND_OBJ_EYEROK_EXPLODE)
    end
    object.oAction = EYEROK_WAKE_UP
    OF.util.optional("network_send_object", nil, object, false)
    return true
end

land_hook_motion(id_bhvEyerokBoss, nil, warp.land_eyerok_wake, OBJ_LIST_GENACTOR)

local BULLY_PATROL, BULLY_CHASE = 0, 1
local BULLY_SEE, BULLY_LOSE = 800.0, 1000.0

warp.landMinionPlaced = setmetatable({}, { __mode = "k" })

function warp.land_minion_placed(object)
    return object ~= nil and warp.landMinionPlaced[object] == true
end

function warp.land_bully_minions(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or id_bhvSmallBully == nil then return false end
    if not warp.land_route_kit.level_own(object) then return false end
    local placed = 0
    local bully = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvSmallBully)
    local guard = 0
    while bully ~= nil and guard < 64 do
        if bully.parentObj == object and (tonumber(bully.oTimer) or 0) == 0
            and not warp.landMinionPlaced[bully] then
            bully.oPosX, bully.oPosY, bully.oPosZ = bully.oPosX * fx, bully.oPosY * fy, bully.oPosZ * fz
            bully.oHomeX, bully.oHomeY, bully.oHomeZ = bully.oPosX, bully.oPosY, bully.oPosZ
            local at = bully.header ~= nil and bully.header.gfx ~= nil and bully.header.gfx.pos or nil
            if at ~= nil then at.x, at.y, at.z = bully.oPosX, bully.oPosY, bully.oPosZ end
            warp.landMinionPlaced[bully] = true
            placed = placed + 1
        end
        guard = guard + 1
        bully = OF.util.optional("obj_get_next_with_same_behavior_id", nil, bully)
    end
    return placed > 0
end

local function bully_sees(object, radius, fx, fy, fz)
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[i]
        local body = m ~= nil and m.marioObj or nil
        if body ~= nil and (type(is_player_active) ~= "function" or is_player_active(m) ~= 0)
            and m.visibleToObjects ~= false and m.visibleToObjects ~= 0 then
            local dx = (body.oPosX - object.oHomeX) / math_abs(fx)
            local dy = (body.oPosY - object.oPosY) / math_abs(fy)
            local dz = (body.oPosZ - object.oHomeZ) / math_abs(fz)
            if dx * dx + dy * dy + dz * dz < radius * radius then return true end
        end
    end
    return false
end

function warp.land_bully_territory(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil then return false end
    if not warp.land_route_kit.level_own(object) and not warp.land_minion_placed(object) then
        return false
    end
    local action, prev = object.oAction, object.oPrevAction
    if action ~= BULLY_PATROL then return false end
    local chase = (prev == BULLY_PATROL and bully_sees(object, BULLY_SEE, fx, fy, fz))
        or (prev == BULLY_CHASE and bully_sees(object, BULLY_LOSE, fx, fy, fz))
    if not chase then return false end
    object.oAction = BULLY_CHASE
    OF.util.optional("cur_obj_init_animation", nil, 1)
    return true
end

land_hook_motion(id_bhvBigBullyWithMinions, warp.land_bully_minions, warp.land_bully_territory,
    OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvSmallBully, nil, warp.land_bully_territory, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvBigBully, nil, warp.land_bully_territory, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvSmallChillBully, nil, warp.land_bully_territory, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvBigChillBully, nil, warp.land_bully_territory, OBJ_LIST_GENACTOR)
end

local function land_snow_mound(object)
    local ok, fx, fy, _ = motion_shape()
    if not ok then return false end
    local wrote = false
    local vx = object.oVelX
    if type(vx) == "number" and vx ~= 0.0 then
        object.oPosX = object.oPosX + vx * (fx - 1.0)
        wrote = true
    end
    local vy = object.oVelY
    if type(vy) == "number" and vy ~= 0.0 then
        object.oPosY = object.oPosY + vy * (fy - 1.0)
        wrote = true
    end
    return wrote
end

local function land_snow_mound_init(object)
    local ok, ax, ay, az = motion_size()
    if ok then
        land_grow_object(object, ax, ay, az)
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return land_snow_mound(object)
end

land_hook_motion(id_bhvSlidingSnowMound, land_snow_mound_init,
    land_snow_mound, OBJ_LIST_SURFACE)

local function land_ddd_moving_pole_init(object)
    local ok, ax, ay, az = motion_size()
    if ok and land_climb_object(object, ax, ay, az) then
        warp.landMotion = (warp.landMotion or 0) + 1
    else
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return true
end

land_hook_motion(id_bhvDddMovingPole, land_ddd_moving_pole_init, nil,
    OBJ_LIST_POLELIKE)

end

do

local RING_STEP = 400

local RING_REACH = 1000.0

local RING_STEP_MAX = 0x2000

local function ring_factor(yaw, ax, ay, az)
    if type(yaw) ~= "number" then return nil end
    if type(ax) ~= "number" or type(ay) ~= "number"
        or type(az) ~= "number" then return nil end
    local sx, cz = sins(yaw) * ax, coss(yaw) * az
    local across = math_sqrt(sx * sx + cz * cz)

    if not (across > 0.0) then across = math_max(ax, az) end
    if across > ay then return across end
    return ay
end

local function ring_turn(yaw, ax, ay, az)
    local factor = ring_factor(yaw, ax, ay, az)
    if factor == nil then return nil end

    if not (factor > 0.0) then return nil end
    local step = math_floor(RING_STEP / factor + 0.5)
    if step < 1 or step > RING_STEP_MAX then return nil end
    return step, factor
end

warp.land_ring_turn = ring_turn

local function land_ring_axle(object)
    local ok, ax, ay, az = motion_size()
    if not ok then return false end
    local step = ring_turn(object.oMoveAngleYaw, ax, ay, az)
    if step == nil or step == RING_STEP then return false end
    local roll = object.oFaceAngleRoll
    if type(roll) ~= "number" then return false end

    object.oFaceAngleRoll = fold_s16(roll + step - RING_STEP)
    return true
end

local function land_ring_axle_init(object)
    local ok, ax, ay, az = motion_size()
    if not ok then return false end
    if ring_turn(object.oMoveAngleYaw, ax, ay, az) == nil then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    warp.landMotion = (warp.landMotion or 0) + 1
    return land_ring_axle(object)
end

local function land_ring_plate(object)

    if type(load_object_collision_model) ~= "function" then return false end
    local ok, fx, fy, fz = motion_shape()

    local shut = (object.oCollisionDistance == 0.0)
    local ax, ay, az = 1.0, 1.0, 1.0
    if ok then ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz) end
    local reach = RING_REACH
    local widest = math_max(ax, ay, az)
    if widest > 1.0 then reach = RING_REACH * widest end
    if not ok then

        if shut then object.oCollisionDistance = reach end
        return false
    end
    local parent = object.parentObj

    if parent == nil
        or ring_turn(parent.oMoveAngleYaw, ax, ay, az) == nil then
        if shut then object.oCollisionDistance = reach end
        return false
    end

    if not shut then
        object.oCollisionDistance = 0.0
        return false
    end
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local ox, oy, oz = object.oPosX, object.oPosY, object.oPosZ
    if type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number"
        or type(ox) ~= "number" or type(oy) ~= "number"
        or type(oz) ~= "number" then return false end
    local cx, cy, cz = warp.land_attach_offset(ox - px, oy - py, oz - pz,
        fx, fy, fz)
    if cx == nil then return false end
    local nx, ny, nz = px + cx, py + cy, pz + cz

    local vx, vy, vz = object.oVelX, object.oVelY, object.oVelZ
    if type(vx) == "number" then object.oVelX = nx - (ox - vx) end
    if type(vy) == "number" then object.oVelY = ny - (oy - vy) end
    if type(vz) == "number" then object.oVelZ = nz - (oz - vz) end
    object.oPosX, object.oPosY, object.oPosZ = nx, ny, nz

    object.oCollisionDistance = reach
    load_object_collision_model()
    object.oCollisionDistance = 0.0
    return true
end

local function land_ring_plate_init(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok then return false end
    local parent = object.parentObj

    if parent == nil
        or ring_turn(parent.oMoveAngleYaw, math_abs(fx), math_abs(fy),
            math_abs(fz)) == nil then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    warp.landMotion = (warp.landMotion or 0) + 1
    return land_ring_plate(object)
end

land_hook_motion(id_bhvFerrisWheelAxle, land_ring_axle_init, land_ring_axle)
land_hook_motion(id_bhvFerrisWheelPlatform, land_ring_plate_init,
    land_ring_plate)

local TRAP_SLOP = 1.0

local function land_trap_leaf(object)
    local ok, fx, fy, fz = motion_shape()
    if not ok then return false end
    local parent = object.parentObj
    if parent == nil then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    local rx = object.oParentRelativePosX
    local ry = object.oParentRelativePosY
    local rz = object.oParentRelativePosZ
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local ox, oy, oz = object.oPosX, object.oPosY, object.oPosZ
    if type(rx) ~= "number" or type(ry) ~= "number" or type(rz) ~= "number"
        or type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number"
        or type(ox) ~= "number" or type(oy) ~= "number"
        or type(oz) ~= "number" then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    local dx, dy, dz = ox - px, oy - py, oz - pz
    local kept = math_sqrt(rx * rx + ry * ry + rz * rz)

    if not (kept > 0.0) then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    if math_abs(math_sqrt(dx * dx + dy * dy + dz * dz) - kept) > TRAP_SLOP then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end

    local cx, cy, cz = warp.land_attach_offset(dx, dy, dz, fx, fy, fz)
    if cx == nil then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    object.oPosX, object.oPosY, object.oPosZ = px + cx, py + cy, pz + cz

    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

warp.land_trap_leaf = land_trap_leaf

land_hook_motion(id_bhvFloorTrapInCastle, land_trap_leaf, nil)

local function land_amp_orbit(object)
    local ok, fx, _, fz = motion_shape()
    if not ok then return false end
    local ax, az = math_abs(fx), math_abs(fz)

    if ax ~= az then
        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
        return false
    end
    local was = object.oAmpRadiusOfRotation

    if type(was) ~= "number" or was == 0.0 then return false end
    object.oAmpRadiusOfRotation = was * ax
    warp.landMotion = (warp.landMotion or 0) + 1
    return true
end

warp.land_amp_orbit = land_amp_orbit

land_hook_motion(id_bhvCirclingAmp, land_amp_orbit, nil, OBJ_LIST_GENACTOR)

local KING_REACH = 1000.0

local KING_ACT_DONE = 9

local function land_king_size(object)

    if type(load_object_collision_model) ~= "function" then return false end
    local ok, ax, ay, az = motion_size()

    local shut = (object.oCollisionDistance == 0.0)
    local reach = KING_REACH
    if ok then
        local widest = math_max(ax, ay, az)

        if widest > 1.0 then reach = KING_REACH * widest end
    end
    if not ok then

        if shut then object.oCollisionDistance = reach end
        return false
    end

    if not shut then
        object.oCollisionDistance = 0.0
        return false
    end
    if object.oAction == KING_ACT_DONE then return false end

    if object.oAction == 0 and object.oBehParams2ndByte ~= 0 then
        land_size_object(object, ax, ay, az)
    end
    object.oCollisionDistance = reach
    load_object_collision_model()
    object.oCollisionDistance = 0.0
    return true
end

warp.land_king_size = land_king_size

local function land_king_init(object)
    if type(load_object_collision_model) ~= "function" then return false end
    if motion_size() then
        warp.landMotion = (warp.landMotion or 0) + 1
    end
    return land_king_size(object)
end

land_hook_motion(id_bhvWhompKingBoss, land_king_init, land_king_size)
end

local landRoutes = {}

warp.landRouted = 0
warp.landRouteRefused = 0

warp.landRouteCapped = 0

local function route_size()
    if (warp.landShaped or 0) <= 0 then return false end
    if not landPlaced then return false end
    local size = landSize
    if size == nil then return false end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return false end
    return true, fx, fy, fz
end

local ROUTE_PROBE = 1000000.0
local ROUTE_DIRS = {
    { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
}

local ROUTE_MAX_WAYPOINTS = 400

local PATH_REACHED_END = -1
local PATH_NONE = 0

local ROUTE_S16_MAX = 32767

local ROUTE_BALL_INIT = BBALL_ACT_INITIALIZE or 0
local ROUTE_KOOPA_RACER = KOOPA_BP_KOOPA_THE_QUICK_BASE or 2

local function route_index(object)
    local bp = object.oBehParams
    if type(bp) ~= "number" then return nil end
    return (bp & 0xF0000) >> 16
end

local function route_walk(object, visit)
    local start = object.oPlatformOnTrackStartWaypoint
    if start == nil then return nil end

    object.oPlatformOnTrackPrevWaypointFlags = 0
    local px, py, pz = visit(1, start)
    if px == nil then return nil end
    for index = 2, ROUTE_MAX_WAYPOINTS do
        local answer = PATH_NONE
        for _, dir in ipairs(ROUTE_DIRS) do
            object.oPosX = px + ROUTE_PROBE * dir[1]
            object.oPosY = py + ROUTE_PROBE * dir[2]
            object.oPosZ = pz + ROUTE_PROBE * dir[3]
            answer = cur_obj_follow_path(0)
            if answer ~= PATH_NONE then break end
        end

        if answer == PATH_NONE then return nil end
        local here = object.oPlatformOnTrackPrevWaypoint
        if here == nil then return nil end
        px, py, pz = visit(index, here)
        if px == nil then return nil end
        if answer == PATH_REACHED_END then return index end
    end
    return nil
end

warp.ROUTE_WRITES = false
warp.landRouteHeld = 0

local function route_scale(object, key, joining)
    if key == nil then return false end
    if not warp.ROUTE_WRITES then
        warp.landRouteHeld = (warp.landRouteHeld or 0) + 1
        return nil
    end
    if object.oPlatformOnTrackStartWaypoint == nil then return false end
    if cur_obj_follow_path == nil then return false end

    local ok, fx, fy, fz = route_size()
    local route = landRoutes[key]

    if not ok and route == nil then return false end
    if not ok then fx, fy, fz = 1.0, 1.0, 1.0 end

    if route == nil then

        route = { n = 0, farX = 0, farY = 0, farZ = 0 }
        local walked = route_walk(object, function(at, waypoint)
            local pos = waypoint.pos
            if pos == nil then return nil end
            local x, y, z = pos.x, pos.y, pos.z
            if type(x) ~= "number" or type(y) ~= "number"
                or type(z) ~= "number" then return nil end
            route[at] = { x = x, y = y, z = z }
            if math_abs(x) > route.farX then route.farX = math_abs(x) end
            if math_abs(y) > route.farY then route.farY = math_abs(y) end
            if math_abs(z) > route.farZ then route.farZ = math_abs(z) end
            return x, y, z
        end)
        if walked == nil then
            warp.landRouteRefused = (warp.landRouteRefused or 0) + 1
            return "refused", fx, fy, fz
        end
        route.n = walked
        landRoutes[key] = route
    end

    local capped = false
    local function route_cap(factor, far)
        if far <= 0 then return factor end
        local limit = ROUTE_S16_MAX / far
        local size = math_abs(factor)
        if size <= limit then return factor end
        capped = true
        if factor < 0 then return -limit end
        return limit
    end
    if ok then
        fx = route_cap(fx, route.farX)
        fy = route_cap(fy, route.farY)
        fz = route_cap(fz, route.farZ)
        if capped then
            warp.landRouteCapped = (warp.landRouteCapped or 0) + 1
        end
    end

    if route.atX == fx and route.atY == fy and route.atZ == fz then
        if ok and joining then
            warp.landRouted = (warp.landRouted or 0) + 1
        end
        return "skipped", fx, fy, fz
    end

    local wrote = route_walk(object, function(at, waypoint)
        local base = route[at]
        local pos = waypoint.pos
        if base == nil or pos == nil then return nil end

        local x = math_floor(base.x * fx + 0.5)
        local y = math_floor(base.y * fy + 0.5)
        local z = math_floor(base.z * fz + 0.5)
        pos.x, pos.y, pos.z = x, y, z
        return x, y, z
    end)

    if wrote == nil then
        warp.landRouteRefused = (warp.landRouteRefused or 0) + 1
        return "refused", fx, fy, fz
    end

    route.atX, route.atY, route.atZ = fx, fy, fz
    if ok then
        warp.landRouted = (warp.landRouted or 0) + 1
    end
    return "written", fx, fy, fz
end

local function land_route_object(object)
    local index = route_index(object)
    if index == nil then return false end
    local state, fx, fy, fz = route_scale(object, index, true)
    if state == nil then return false end

    local route = landRoutes[index]
    if route == nil then return false end

    local balls = object.oPlatformOnTrackBaseBallIndex
    if type(balls) == "number" then
        object.oPlatformOnTrackBaseBallIndex = balls + 99
    end
    object.oPlatformOnTrackPrevWaypointFlags = 0
    object.oAction = 0

    local first = route ~= nil and route[1] or nil
    if first ~= nil then
        object.oPosX = first.x * fx
        object.oPosY = first.y * fy
        object.oPosZ = first.z * fz
    end
    return state ~= "refused"
end

local function land_route_ball(object)
    local style = object.oBehParams2ndByte
    if type(style) ~= "number" then return false end
    local where, why, when = object.oPosX, object.oPosY, object.oPosZ
    local state = route_scale(object, "bball" .. style, true)
    if state == nil or state == "skipped" then return false end

    object.oPosX, object.oPosY, object.oPosZ = where, why, when
    object.oPlatformOnTrackPrevWaypointFlags = 0
    object.oAction = ROUTE_BALL_INIT
    return state == "written"
end

local function land_route_koopa(object)
    local movement = object.oKoopaMovementType
    if type(movement) ~= "number"
        or movement < ROUTE_KOOPA_RACER then return false end
    if object.oPlatformOnTrackStartWaypoint == nil then return false end
    local race = object.oKoopaTheQuickRaceIndex
    if type(race) ~= "number" then return false end
    local where, why, when = object.oPosX, object.oPosY, object.oPosZ
    local at = object.oPlatformOnTrackPrevWaypoint
    local flags = object.oPlatformOnTrackPrevWaypointFlags

    local state = route_scale(object, "ktq" .. race, flags == 0)
    if state == nil or state == "skipped" then return false end
    object.oPosX, object.oPosY, object.oPosZ = where, why, when
    object.oPlatformOnTrackPrevWaypoint = at
    object.oPlatformOnTrackPrevWaypointFlags = flags
    return state == "written"
end

warp.land_route_ball = land_route_ball
warp.land_route_koopa = land_route_koopa

warp.land_route_object = land_route_object

function warp.land_route_base(index)
    return landRoutes[index]
end

function warp.forget_routes()
    landRoutes = {}
end

land_hook_motion(id_bhvPlatformOnTrack, land_route_object, nil)

land_hook_motion(id_bhvBowlingBall, land_route_ball, nil, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvKoopa, nil, land_route_koopa, OBJ_LIST_PUSHABLE)

;(function()
local kit = warp.land_route_kit
local level_own, s16, yaw_toward = kit.level_own, kit.s16, kit.yaw_toward
local turned_from, npc_state, follow = kit.turned_from, kit.npc_state, kit.follow

local function route_shape(object)
    if warp.ROUTE_WRITES then return false end
    local ok, fx, fy, fz = motion_shape()
    if not ok or object == nil or not level_own(object) then return false end
    return true, fx, fy, fz
end

local function approach_value(value, target, delta)
    if value > target then delta = -delta end
    value = value + delta
    if (value - target) * delta >= 0 then return target end
    return value
end

local function angle_gap(a, b)
    local d = s16(b - a)
    if d == -0x8000 then d = -0x7FFF end
    return math_abs(d)
end

local function vanilla_dist(a, b, fx, fy, fz)
    local dx = (b.oPosX - a.oPosX) / fx
    local dy = (b.oPosY - a.oPosY) / fy
    local dz = (b.oPosZ - a.oPosZ) / fz
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

local function resend(object)
    local id = object.oSyncID
    if id == nil then return end
    if OF.util.optional("sync_object_is_owned_locally", false, id) == true then
        OF.util.optional("network_send_object", nil, object, false)
    end
end

local function restep(object, fwd0, yaw0, fwd, yaw)
    object.oPosX = object.oPosX + fwd * sins(yaw) - fwd0 * sins(yaw0)
    object.oPosZ = object.oPosZ + fwd * coss(yaw) - fwd0 * coss(yaw0)
    object.oVelX = fwd * sins(yaw)
    object.oVelZ = fwd * coss(yaw)
end

local function restep_swim(object, fwd, pitch0, yaw0, pitch, yaw)
    local dx = coss(pitch) * sins(yaw) - coss(pitch0) * sins(yaw0)
    local dy = sins(pitch0) - sins(pitch)
    local dz = coss(pitch) * coss(yaw) - coss(pitch0) * coss(yaw0)
    object.oPosX = object.oPosX + fwd * dx
    object.oPosY = object.oPosY + fwd * dy
    object.oPosZ = object.oPosZ + fwd * dz
    object.oVelX = (tonumber(object.oVelX) or 0) + fwd * dx
    object.oVelY = (tonumber(object.oVelY) or 0) + fwd * dy
    object.oVelZ = (tonumber(object.oVelZ) or 0) + fwd * dz
end

local function rate(value)
    if value >= 0 then return math_floor(value) end
    return -math_floor(-value)
end

local KTQ_RACE, KTQ_DECELERATE = 3, 4
local KTQ_SUB_RUN = 1
local KTQ_GO = 50
local KTQ_FINISH = 400.0

function warp.land_ktq_race(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local movement = object.oKoopaMovementType
    if type(movement) ~= "number" or movement < (KOOPA_BP_KOOPA_THE_QUICK_BASE or 2) then
        return false
    end
    if object.oPrevAction ~= KTQ_RACE then return false end
    local timer = tonumber(object.oTimer) or 0
    if timer <= KTQ_GO then return false end
    local state = npc_state(object, timer == KTQ_GO + 1)
    local ended = object.oAction == KTQ_DECELERATE
    local agility = tonumber(object.oKoopaAgility) or 1.0
    local step = rate((state.agility or agility) * 150.0)
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local enginePitch = tonumber(object.oPathedTargetPitch) or 0
    local from = yaw0
    if not ended then from = turned_from(yaw0, tonumber(object.oPathedTargetYaw) or 0, step) end
    local answer, toward, pitch = follow(object, fx, fy, fz, state, timer > KTQ_GO + 1)
    if answer == nil then return false end
    local parent = object.parentObj
    if answer == -1 then
        if parent ~= nil and parent ~= object then
            parent.oKoopaRaceEndpointKoopaFinished = 1
        end
        if not ended then
            object.oAction = KTQ_DECELERATE
            resend(object)
        end
    else
        if ended then
            object.oAction = KTQ_RACE
            resend(object)
        end
        local fwd0 = tonumber(object.oForwardVel) or 0.0
        local fwd = fwd0

        if not ended and state.fwd ~= nil and state.sub == KTQ_SUB_RUN
            and object.oSubAction == KTQ_SUB_RUN then
            local top, accel = agility * 6.0, agility * 0.1
            fwd = fwd0 + approach_value(state.fwd, top * (1.0 + sins(pitch)), accel)
                - approach_value(state.fwd, top * (1.0 + sins(enginePitch)), accel)
            object.oForwardVel = fwd
        end
        local yaw = yaw_toward(from, toward, step)
        restep(object, fwd0, yaw0, fwd, yaw)
        object.oMoveAngleYaw = yaw
    end
    state.agility = tonumber(object.oKoopaAgility) or agility
    state.fwd = tonumber(object.oForwardVel) or 0.0
    state.sub = object.oSubAction
    return true
end

function warp.land_ktq_finish(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    if (tonumber(object.oKoopaRaceEndpointRaceBegun) or 0) == 0 then return false end
    if (tonumber(object.oKoopaRaceEndpointRaceEnded) or 0) ~= 0 then return false end
    if type(bhv_koopa_race_endpoint_update) ~= "function" then return false end
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    if player == nil then return false end
    if vanilla_dist(object, player, fx, fy, fz) >= KTQ_FINISH then return false end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    object.oPosX, object.oPosY, object.oPosZ = player.oPosX, player.oPosY, player.oPosZ
    pcall(bhv_koopa_race_endpoint_update)
    object.oPosX, object.oPosY, object.oPosZ = x, y, z
    return true
end

land_hook_motion(id_bhvKoopa, nil, warp.land_ktq_race, OBJ_LIST_PUSHABLE)
land_hook_motion(id_bhvKoopaRaceEndpoint, nil, warp.land_ktq_finish, OBJ_LIST_DEFAULT)

local PENGUIN_RACE, PENGUIN_FINISH = 3, 4

function warp.land_racing_penguin(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    if object.oPrevAction ~= PENGUIN_RACE then return false end
    local timer = tonumber(object.oTimer) or 0
    local state = npc_state(object, timer == 0)
    local ended = object.oAction == PENGUIN_FINISH
    local fwd = tonumber(object.oForwardVel) or 0.0
    local step = rate(15.0 * fwd)
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local from = yaw0
    if not ended then from = turned_from(yaw0, tonumber(object.oPathedTargetYaw) or 0, step) end
    local answer, toward = follow(object, fx, fy, fz, state, timer > 0)
    if answer == nil then return false end
    if answer == -1 then
        if not ended then
            object.oRacingPenguinReachedBottom = 1
            object.oAction = PENGUIN_FINISH
            resend(object)
        end
        return true
    end
    if ended then
        object.oRacingPenguinReachedBottom = 0
        object.oAction = PENGUIN_RACE
        resend(object)
    end
    local yaw = yaw_toward(from, toward, step)
    restep(object, fwd, yaw0, fwd, yaw)
    object.oMoveAngleYaw = yaw
    return true
end

local LINE_REACH, SHORTCUT_REACH = 1000.0, 500.0

local function penguin_player(object)
    return OF.util.optional("nearest_player_to_object", nil, object)
end

local function real_dist(a, b)
    local dx, dy, dz = b.oPosX - a.oPosX, b.oPosY - a.oPosY, b.oPosZ - a.oPosZ
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

function warp.land_penguin_finish_line(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local racer = object.parentObj
    if racer == nil then return false end
    local state = npc_state(object)
    local before = state.won
    local won = (tonumber(racer.oRacingPenguinMarioWon) or 0) ~= 0
    state.won = won
    if (tonumber(racer.oRacingPenguinReachedBottom) or 0) ~= 0 then return false end
    local player = penguin_player(object)
    if player == nil then return false end
    local inside = vanilla_dist(object, player, fx, fy, fz) < LINE_REACH
        and (player.oPosZ - object.oPosZ) / fz < 0.0
    if inside and not won then
        racer.oRacingPenguinMarioWon = 1
        state.won = true
        OF.util.optional("network_send_object", nil, racer, false)
        return true
    end
    local engine = real_dist(object, player) < LINE_REACH and player.oPosZ - object.oPosZ < 0.0
    if won and before == false and engine and not inside then
        racer.oRacingPenguinMarioWon = 0
        state.won = false
        OF.util.optional("network_send_object", nil, racer, false)
        return true
    end
    return false
end

function warp.land_penguin_shortcut(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local racer = object.parentObj
    if racer == nil then return false end
    local state = npc_state(object)
    local before = state.cheated
    local cheated = (tonumber(racer.oRacingPenguinMarioCheated) or 0) ~= 0
    state.cheated = cheated
    local player = penguin_player(object)
    if player == nil then return false end
    local inside = vanilla_dist(object, player, fx, fy, fz) < SHORTCUT_REACH
    if inside and not cheated then
        racer.oRacingPenguinMarioCheated = 1
        state.cheated = true
        OF.util.optional("network_send_object", nil, racer, false)
        return true
    end
    if cheated and before == false and real_dist(object, player) < SHORTCUT_REACH and not inside then
        racer.oRacingPenguinMarioCheated = 0
        state.cheated = false
        OF.util.optional("network_send_object", nil, racer, false)
        return true
    end
    return false
end

land_hook_motion(id_bhvRacingPenguin, nil, warp.land_racing_penguin, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvPenguinRaceFinishLine, nil, warp.land_penguin_finish_line, OBJ_LIST_DEFAULT)
land_hook_motion(id_bhvPenguinRaceShortcutCheck, nil, warp.land_penguin_shortcut, OBJ_LIST_DEFAULT)

local MIPS_WAIT, MIPS_FOLLOW, MIPS_GIVE_UP = 0, 1, 2
local MIPS_NEAR = 800.0
local MIPS_STARTS = {
    { -1831, -1177, -1178 }, { -3674, -1379, -962 }, { -1463, -1210, -2231 },
    { -2019, -1279, -3077 }, { -3005, -1197, -1874 }, { -1387, -1254, -2541 },
    { -894, -1223, -1421 }, { -187, -1279, -1662 }, { -1092, -1279, -3188 },
    { -214, -1279, -2432 },
}
local mipsTableOff = false

local function mips_pick(object, fx, fy, fz)
    local x, y, z = object.oPosX / fx, object.oPosY / fy, object.oPosZ / fz
    local player = OF.util.optional("nearest_player_to_object", nil, object)
    local best, far = -1, -10000.0
    for i, p in ipairs(MIPS_STARTS) do
        local dx, dy, dz = p[1] - x, p[2] - y, p[3] - z
        if dx * dx + dy * dy + dz * dz < MIPS_NEAR * MIPS_NEAR then
            local d = 10000.0
            if player ~= nil then
                local px, pz = p[1] - player.oPosX / fx, p[3] - player.oPosZ / fz
                d = px * px + pz * pz
            end
            if far < d then best, far = i - 1, d end
        end
    end
    return best
end

function warp.land_mips(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    if (tonumber(object.oHeldState) or 0) ~= 0 then return false end
    local was, now = object.oPrevAction, object.oAction
    if was == MIPS_WAIT then

        if now == MIPS_WAIT or mipsTableOff then return false end
        local pick = mips_pick(object, fx, fy, fz)
        object.oMipsStartWaypointIndex = pick
        npc_state(object, true)
        if pick < 0 then
            object.oAction = MIPS_GIVE_UP
        else
            object.oAction = MIPS_FOLLOW
            OF.util.optional("cur_obj_init_animation", nil, 1)
        end
        return true
    end
    if was ~= MIPS_FOLLOW then return false end

    local start = object.oPlatformOnTrackStartWaypoint
    local first = MIPS_STARTS[(tonumber(object.oMipsStartWaypointIndex) or -1) + 1]
    local pos = start ~= nil and start.pos or nil
    if first == nil or pos == nil or pos.x ~= first[1] or pos.y ~= first[2] or pos.z ~= first[3] then
        mipsTableOff = true
    end
    local timer = tonumber(object.oTimer) or 0
    local state = npc_state(object, timer == 0)
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local answer, toward = follow(object, fx, fy, fz, state, timer > 0)
    if answer == nil then return false end
    local ended = now == MIPS_WAIT
    if answer == -1 and not ended then
        object.oAction = MIPS_WAIT
        OF.util.optional("cur_obj_init_animation", nil, 0)
    elseif answer ~= -1 and ended then
        object.oAction = MIPS_FOLLOW
        OF.util.optional("cur_obj_init_animation", nil, 1)
    end
    local fwd = tonumber(object.oForwardVel) or 0.0
    restep(object, fwd, yaw0, fwd, toward)
    object.oMoveAngleYaw = toward
    return true
end

function warp.land_mips_table_off()
    return mipsTableOff
end

land_hook_motion(id_bhvMips, nil, warp.land_mips, OBJ_LIST_GENACTOR)

local UNAGI_SHIP, UNAGI_ROUTE, UNAGI_HOME, UNAGI_OUT = 0, 1, 2, 4
local UNAGI_PITCH, UNAGI_TURN = 50, 120

function warp.land_unagi(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local was, now = object.oPrevAction, object.oAction
    if was == UNAGI_SHIP then
        if now ~= UNAGI_ROUTE then return false end
        local start = object.oPlatformOnTrackStartWaypoint
        local pos = start ~= nil and start.pos or nil
        if pos == nil or object.oPosX ~= pos.x or object.oPosY ~= pos.y
            or object.oPosZ ~= pos.z then return false end
        object.oPosX, object.oPosY, object.oPosZ = pos.x * fx, pos.y * fy, pos.z * fz
        return true
    end
    if was ~= UNAGI_ROUTE and was ~= UNAGI_OUT then return false end
    local timer = tonumber(object.oTimer) or 0
    local state = npc_state(object, timer == 0)
    local pitch0 = tonumber(object.oMoveAnglePitch) or 0
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local fromPitch = turned_from(pitch0, tonumber(object.oPathedTargetPitch) or 0, UNAGI_PITCH)
    local fromYaw = turned_from(yaw0, tonumber(object.oPathedTargetYaw) or 0, UNAGI_TURN)
    local answer, toward, pitch = follow(object, fx, fy, fz, state, timer > 0)
    if answer == nil then return false end
    if was == UNAGI_OUT then
        local ended = now == UNAGI_HOME
        if answer == -1 and not ended then
            object.oAction = UNAGI_HOME
        elseif answer ~= -1 and ended then
            object.oAction = UNAGI_OUT
        end
    end
    local newPitch = yaw_toward(fromPitch, pitch, UNAGI_PITCH)
    local newYaw = yaw_toward(fromYaw, toward, UNAGI_TURN)
    restep_swim(object, tonumber(object.oForwardVel) or 0.0, pitch0, yaw0, newPitch, newYaw)
    object.oMoveAnglePitch, object.oFaceAnglePitch = newPitch, newPitch
    object.oMoveAngleYaw = newYaw
    return true
end

land_hook_motion(id_bhvUnagi, nil, warp.land_unagi, OBJ_LIST_GENACTOR)

local MANTA_SWIM_RINGS, MANTA_SWIM = 0, 1
local MANTA_TURN = 0x80

function warp.land_manta_ray(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local was = object.oPrevAction
    if was ~= MANTA_SWIM_RINGS and was ~= MANTA_SWIM then return false end
    local state = npc_state(object)
    local pitch0 = tonumber(object.oMoveAnglePitch) or 0
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local fromPitch = turned_from(pitch0, tonumber(object.oMantaTargetPitch) or 0, MANTA_TURN)
    local fromYaw = turned_from(yaw0, tonumber(object.oMantaTargetYaw) or 0, MANTA_TURN)
    local answer, toward, pitch = follow(object, fx, fy, fz, state, true)
    if answer == nil then return false end
    local newPitch = yaw_toward(fromPitch, pitch, MANTA_TURN)
    local newYaw = yaw_toward(fromYaw, toward, MANTA_TURN)
    restep_swim(object, tonumber(object.oForwardVel) or 0.0, pitch0, yaw0, newPitch, newYaw)
    object.oMoveAnglePitch, object.oMoveAngleYaw = newPitch, newYaw
    object.oMantaTargetPitch, object.oMantaTargetYaw = pitch, toward
    return true
end

land_hook_motion(id_bhvMantaRay, warp.land_manta_ray, warp.land_manta_ray, OBJ_LIST_GENACTOR)

local BALL_AIM, BALL_ROLL = 0, 1
local BALL_TURN = 0x400
local BALL_MIST_NEAR = 7000

local function ball_unmist(ball)
    if id_bhvWhitePuffExplosion == nil then return end
    local puff = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvWhitePuffExplosion)
    while puff ~= nil do
        local after = OF.util.optional("obj_get_next_with_same_behavior_id", nil, puff)
        if puff.parentObj == ball then OF.util.optional("obj_mark_for_deletion", nil, puff) end
        puff = after
    end
end

function warp.land_ball_roll(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local was = object.oPrevAction
    if was == BALL_AIM then
        local state = npc_state(object, true)
        local answer, toward = follow(object, fx, fy, fz, state, false)
        if answer == nil then return false end
        object.oMoveAngleYaw = toward
        state.active = object.activeFlags
        return true
    end
    if was ~= BALL_ROLL then return false end
    local state = npc_state(object)
    local yaw0 = tonumber(object.oMoveAngleYaw) or 0
    local from = turned_from(yaw0, tonumber(object.oPathedTargetYaw) or 0, BALL_TURN)
    local ended = (tonumber(object.activeFlags) or 0) == 0
    local answer, toward = follow(object, fx, fy, fz, state, true)
    if answer == nil then return false end
    object.oMoveAngleYaw = yaw_toward(from, toward, BALL_TURN)
    object.oBowlingBallTargetYaw = toward
    if answer == -1 and not ended then
        local near = OF.util.optional("is_point_within_radius_of_mario", false, object.oPosX,
            object.oPosY, object.oPosZ, BALL_MIST_NEAR)
        if near == true or (type(near) == "number" and near ~= 0) then
            OF.util.optional("spawn_mist_particles", nil)
            OF.util.optional("spawn_mist_particles_variable", nil, 0, 0, 92.0)
        end
        OF.util.optional("obj_mark_for_deletion", nil, object)
        return true
    end
    if answer ~= -1 and ended then
        object.activeFlags = state.active or ACTIVE_FLAG_ACTIVE or 1
        ball_unmist(object)
    end
    state.active = object.activeFlags
    return true
end

land_hook_motion(id_bhvBowlingBall, warp.land_ball_roll, warp.land_ball_roll, OBJ_LIST_GENACTOR)

function warp.land_ball_spawner(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local reach = tonumber(object.oBBallSpawnerMaxSpawnDist)
    if reach == nil or reach <= 0 then return false end
    object.oBBallSpawnerMaxSpawnDist = reach * math_max(math_abs(fx), math_abs(fy), math_abs(fz))
    return true
end

land_hook_motion(id_bhvBobBowlingBallSpawner, warp.land_ball_spawner, nil, OBJ_LIST_GENACTOR)
land_hook_motion(id_bhvTtmBowlingBallSpawner, warp.land_ball_spawner, nil, OBJ_LIST_GENACTOR)

local TRACK_INIT, TRACK_MOVE = 0, 2
local TRACK_END = -1
local TRACK_BALLS_BIT, TRACK_LOOP_BIT = 0x80, 0x100
local TRACK_KEEP_YAW_BIT, TRACK_ROLL_BIT = 0x400, 0x800
local TRACK_CARPET = 0
local TRACK_BALL_GAP, TRACK_BALL_COUNT = 300.0, 5
local TRACK_REACH = 1000.0
local trackRoutes = {}

local function track_bits(object)
    return math_floor((tonumber(object.oBehParams) or 0) / 65536) % 65536
end

local function track_route(object)
    local start = object.oPlatformOnTrackStartWaypoint
    local p = start ~= nil and start.pos or nil
    if p == nil then return nil end
    local key = tostring(route_index(object)) .. ":" .. p.x .. "," .. p.y .. "," .. p.z
    local known = trackRoutes[key]
    if known ~= nil then return known or nil end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    local prev = object.oPlatformOnTrackPrevWaypoint
    local flags = object.oPlatformOnTrackPrevWaypointFlags
    local pitch, yaw = object.oPlatformOnTrackPitch, object.oPlatformOnTrackYaw
    local list = {}
    local n = route_walk(object, function(at, waypoint)
        local pos = waypoint.pos
        if pos == nil then return nil end
        list[at] = { wp = waypoint, x = pos.x, y = pos.y, z = pos.z,
                     flags = tonumber(waypoint.flags) or 0 }
        return pos.x, pos.y, pos.z
    end)
    object.oPosX, object.oPosY, object.oPosZ = x, y, z
    object.oPlatformOnTrackPrevWaypoint = prev
    object.oPlatformOnTrackPrevWaypointFlags = flags
    object.oPlatformOnTrackPitch, object.oPlatformOnTrackYaw = pitch, yaw
    if n == nil then
        trackRoutes[key] = false
        return nil
    end
    trackRoutes[key] = list
    return list
end

local function track_walk(list, k, x, y, z, amount, loop)
    local n = #list
    local prev, nextK = k, k
    local dx, dy, dz, dist = 0.0, 0.0, 0.0, 100.0
    local ended = false
    repeat
        prev = nextK
        nextK = nextK + 1
        if nextK > n then
            ended = true
            if not loop then return nil, prev, true end
            nextK = 1
        end
        local w = list[nextK]
        dx, dy, dz = w.x - x, w.y - y, w.z - z
        dist = math_sqrt(dx * dx + dy * dy + dz * dz)
        amount = amount - dist
        x, y, z = x + dx, y + dy, z + dz
    until not (amount > 0.0)
    local t = 0.0
    if dist > 0.0 then t = amount / dist end
    return { x + dx * t, y + dy * t, z + dz * t }, prev, ended
end

local function track_find(list, waypoint)
    local pos = waypoint ~= nil and waypoint.pos or nil
    if pos == nil then return 1 end
    for i, w in ipairs(list) do
        if w.x == pos.x and w.y == pos.y and w.z == pos.z
            and w.flags == (tonumber(waypoint.flags) or 0) then return i end
    end
    return 1
end

local function track_moves(flags, loop, skiLift)
    if flags == TRACK_END and not loop then return false end
    if flags ~= 0 and skiLift then return false end
    return true
end

local function track_balls(object, list, k, x, y, z, loop, base, first, last, fx, fy, fz)
    if id_bhvTrackBall == nil then return end
    local mine = {}
    local ball = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvTrackBall)
    while ball ~= nil do
        if ball.parentObj == object then
            local i = (tonumber(ball.oBehParams2ndByte) or 0) - base
            if i >= first and i <= last then mine[#mine + 1] = { ball, i } end
        end
        ball = OF.util.optional("obj_get_next_with_same_behavior_id", nil, ball)
    end
    for _, entry in ipairs(mine) do
        local at = track_walk(list, k, x, y, z, TRACK_BALL_GAP * entry[2], loop)
        if at == nil then
            OF.util.optional("obj_mark_for_deletion", nil, entry[1])
        else
            entry[1].oPosX, entry[1].oPosY, entry[1].oPosZ = at[1] * fx, at[2] * fy, at[3] * fz
        end
    end
end

local function clamp_speed(value)
    return math_min(math_max(value, 100), 500)
end

function warp.land_track(object)
    if object == nil then return false end
    local state = npc_state(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then

        if state.reach ~= nil and object.oCollisionDistance == 0.0 then
            object.oCollisionDistance = state.reach
        end
        return false
    end
    if object.oPlatformOnTrackStartWaypoint == nil then return false end
    local list = state.list
    if list == nil then
        list = track_route(object)
        if list == nil or #list < 1 then return false end
        state.list = list
    end

    local first = state.reach == nil
    if first then
        local reach = tonumber(object.oCollisionDistance) or 0.0
        state.reach = reach > 0.0 and reach or TRACK_REACH
    end
    local bits = track_bits(object)
    local loop = OF.util.has_flag(bits, TRACK_LOOP_BIT)
    local skiLift = (tonumber(object.oPlatformOnTrackIsNotSkiLift) or 1) == 0
    local base = tonumber(object.oPlatformOnTrackBaseBallIndex) or 0
    local was = object.oPrevAction
    if was == TRACK_INIT then

        local s = list[1]
        state.k, state.wpFlags = 1, 0
        object.oPosX, object.oPosY, object.oPosZ = s.x * fx, s.y * fy, s.z * fz
        object.oHomeX, object.oHomeY, object.oHomeZ = s.x * fx, s.y * fy, s.z * fz
        if OF.util.has_flag(bits, TRACK_BALLS_BIT) then
            track_balls(object, list, 1, s.x, s.y, s.z, loop, base, 1, TRACK_BALL_COUNT, fx, fy, fz)
        end
    elseif state.vx == nil then

        state.k = track_find(list, object.oPlatformOnTrackPrevWaypoint)
        state.wpFlags = tonumber(object.oPlatformOnTrackPrevWaypointFlags) or 0
        state.pitch = tonumber(object.oPlatformOnTrackPitch) or 0
        state.yaw = tonumber(object.oPlatformOnTrackYaw) or 0
    elseif was == TRACK_MOVE and track_moves(state.wpFlags, loop, skiLift) then
        local vx, vy, vz, k = state.vx, state.vy, state.vz, state.k
        local at, prev, ended = track_walk(list, k, vx, vy, vz,
            tonumber(object.oForwardVel) or 0.0, loop)
        local flags = 0
        if ended then flags = TRACK_END end
        if at ~= nil then
            if prev ~= k then
                if flags == 0 then flags = list[k].flags end
                state.k = prev
            end
            local velX, velY, velZ = (at[1] - vx) * fx, (at[2] - vy) * fy, (at[3] - vz) * fz
            object.oPosX, object.oPosY, object.oPosZ = at[1] * fx, at[2] * fy, at[3] * fz
            object.oVelX, object.oVelY, object.oVelZ = velX, velY, velZ
            state.pitch = s16(atan2s(math_sqrt(velX * velX + velZ * velZ), -velY))
            state.yaw = s16(atan2s(velZ, velX))
        else

            object.oPosX, object.oPosY, object.oPosZ = vx * fx, vy * fy, vz * fz
            object.oVelX, object.oVelY, object.oVelZ = state.velX, state.velY, state.velZ
        end
        state.wpFlags = flags
        object.oPlatformOnTrackPitch, object.oPlatformOnTrackYaw = state.pitch, state.yaw
        object.oMoveAnglePitch, object.oMoveAngleYaw = state.pitch, state.yaw
        if not OF.util.has_flag(bits, TRACK_KEEP_YAW_BIT) then
            local target = s16(state.yaw + 0x4000)
            local face = yaw_toward(state.face, target,
                clamp_speed(math_floor(angle_gap(target, state.face) / 20)))
            object.oFaceAngleYaw = face
            object.oAngleVelYaw = s16(face - state.face)
        end
        if OF.util.has_flag(bits, TRACK_ROLL_BIT) and not skiLift then
            local roll = yaw_toward(state.roll, state.pitch,
                clamp_speed(math_floor(angle_gap(state.pitch, state.roll) / 20)))
            object.oFaceAngleRoll = roll
            object.oAngleVelRoll = s16(roll - state.roll)
        end

        if not skiLift and object.oPlatformOnTrackType == TRACK_CARPET then
            object.oPosY = object.oPosY + (tonumber(object.oPlatformOnTrackOffsetY) or 0.0)
        end

        if base ~= state.base and OF.util.has_flag(bits, TRACK_BALLS_BIT) then
            track_balls(object, list, k, vx, vy, vz, loop, base, TRACK_BALL_COUNT,
                TRACK_BALL_COUNT, fx, fy, fz)
        end
    end

    object.oPlatformOnTrackPrevWaypoint = list[state.k].wp
    object.oPlatformOnTrackPrevWaypointFlags = state.wpFlags

    state.vx, state.vy, state.vz = object.oPosX / fx, object.oPosY / fy, object.oPosZ / fz
    state.velX = tonumber(object.oVelX) or 0.0
    state.velY = tonumber(object.oVelY) or 0.0
    state.velZ = tonumber(object.oVelZ) or 0.0
    state.face = tonumber(object.oFaceAngleYaw) or 0
    state.roll = tonumber(object.oFaceAngleRoll) or 0
    state.base = base
    if state.pitch == nil then
        state.pitch = tonumber(object.oPlatformOnTrackPitch) or 0
        state.yaw = tonumber(object.oPlatformOnTrackYaw) or 0
    end
    if not first and type(load_object_collision_model) == "function" then
        object.oCollisionDistance = math_max(state.reach,
            TRACK_REACH * math_max(math_abs(fx), math_abs(fy), math_abs(fz)))
        load_object_collision_model()
    end
    object.oCollisionDistance = 0.0
    return true
end

land_hook_motion(id_bhvPlatformOnTrack, warp.land_track, warp.land_track)

local SUSHI_RADIUS, SUSHI_BOB, SUSHI_STEP = 1700.0, 200.0, 0x80

function warp.land_sushi_shark(object)
    local ok, fx, fy, fz = route_shape(object)
    if not ok then return false end
    local a = s16((tonumber(object.oSushiSharkUnkF4) or 0) - SUSHI_STEP)
    local x0, y0, z0 = object.oPosX, object.oPosY, object.oPosZ
    if math_abs(x0 - (object.oHomeX + sins(a) * SUSHI_RADIUS)) > 0.01
        or math_abs(z0 - (object.oHomeZ + coss(a) * SUSHI_RADIUS)) > 0.01 then
        return false
    end
    local water = y0 - object.oHomeY - sins(a) * SUSHI_BOB
    object.oPosX = object.oHomeX + sins(a) * SUSHI_RADIUS * fx
    object.oPosZ = object.oHomeZ + coss(a) * SUSHI_RADIUS * fz
    object.oPosY = water + object.oHomeY + sins(a) * SUSHI_BOB * fy
    object.oMoveAngleYaw = s16(atan2s(-sins(a) * fz, coss(a) * fx))
    if id_bhvObjectWaveTrail ~= nil then
        local trail = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvObjectWaveTrail)
        while trail ~= nil do
            if trail.parentObj == object and trail.oPosX == x0 and trail.oPosZ == z0 then
                trail.oPosX, trail.oPosY, trail.oPosZ = object.oPosX, object.oPosY, object.oPosZ
            end
            trail = OF.util.optional("obj_get_next_with_same_behavior_id", nil, trail)
        end
    end
    return true
end

land_hook_motion(id_bhvSushiShark, nil, warp.land_sushi_shark, OBJ_LIST_GENACTOR)

end)()

local TTC_BAR_ACT_RETRACT = 3

local TTC_BAR_RETRACT_WAIT = 30

local landBarHomes = {}

local function land_bar_next(object, offset, speed)
    local at = offset + speed
    if object.oAction ~= TTC_BAR_ACT_RETRACT then return at end
    if at >= 0.0 then return at end
    local timer = object.oTimer
    if type(timer) ~= "number" then return at end
    if object.oAction ~= object.oPrevAction then
        timer = 0
    else
        timer = timer + 1
    end
    if timer > TTC_BAR_RETRACT_WAIT then return 0.0 end
    return at
end

warp.land_bar_next = land_bar_next

local function land_ttc_bar(object)
    local sid = object.oSyncID
    if type(sid) ~= "number" or sid == 0 then return false end
    local ok, ax, _, az = motion_size()
    local home = landBarHomes[sid]
    if not ok then

        if home ~= nil then
            object.oHomeX, object.oHomeZ = home.x, home.z
            landBarHomes[sid] = nil
        end
        return false
    end
    if home == nil then
        local hx, hz = object.oHomeX, object.oHomeZ
        if type(hx) ~= "number" or type(hz) ~= "number" then return false end
        home = { x = hx, z = hz }
        landBarHomes[sid] = home
    end
    local offset = object.oTTCMovingBarOffset
    local speed = object.oTTCMovingBarSpeed
    local yaw = object.oMoveAngleYaw
    if type(offset) ~= "number" or type(speed) ~= "number"
        or type(yaw) ~= "number" then return false end
    local at = land_bar_next(object, offset, speed)
    object.oHomeX = home.x + at * coss(yaw) * (ax - 1.0)
    object.oHomeZ = home.z + at * sins(yaw) * (az - 1.0)
    return true
end

warp.land_ttc_bar = land_ttc_bar

local function land_ttc_bar_init(object)
    local ok = motion_size()
    if not ok then return false end
    local carried = land_ttc_bar(object)
    if carried then
        warp.landMotion = (warp.landMotion or 0) + 1
    else

        warp.landMotionRefused = (warp.landMotionRefused or 0) + 1
    end
    return carried
end

function warp.forget_bars()
    landBarHomes = {}
end

land_hook_motion(id_bhvTTCMovingBar, land_ttc_bar_init, land_ttc_bar)

end

local DOOR_PROBE = 200.0

local function land_is_door(object)
    if object == nil then return false end
    local ok, door = pcall(function()
        return obj_has_behavior_id(object, id_bhvDoor) ~= 0
            or obj_has_behavior_id(object, id_bhvDoorWarp) ~= 0
    end)
    return ok and door
end

warp.land_is_door = land_is_door

warp.landDoors = 0

local function land_door_rooms(object, ax, az)
    if object == nil then return false end
    if find_floor == nil or sins == nil or coss == nil then return false end
    local reach = math_max(ax, az)

    if not (reach > 1.0) then return false end
    if not land_is_door(object) then return false end
    local ok, wrote = pcall(function()
        local x, y, z = object.oPosX, object.oPosY, object.oPosZ
        local yaw = object.oMoveAngleYaw
        if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number"
            or type(yaw) ~= "number" then return false end
        local out = DOOR_PROBE * reach
        local dx, dz = sins(yaw) * out, coss(yaw) * out

        local room = function(px, pz)
            local _, floor = find_floor(px, y, pz)
            if floor == nil then return nil end
            local n = floor.room
            if type(n) ~= "number" then return nil end
            return n
        end

        local here, ahead, behind =
            room(x, z), room(x + dx, z + dz), room(x - dx, z - dz)
        local any = false
        if here ~= nil then object.oDoorUnkF8 = here; any = true end
        if ahead ~= nil then object.oDoorUnkFC = ahead; any = true end
        if behind ~= nil then object.oDoorUnk100 = behind; any = true end
        return any
    end)
    if not (ok and wrote) then return false end
    warp.landDoors = (warp.landDoors or 0) + 1
    return true
end

warp.land_door_rooms = land_door_rooms

do

local STAR_LEAF_OPEN, STAR_LEAF_SHUT = 1, 3

warp.landLeaves = 0

local function star_leaf_reach()
    if (warp.landShaped or 0) <= 0 then return false end
    if not landPlaced then return false end
    local size = landSize
    if size == nil then return false end
    local fx, fz = size.x, size.z
    if type(fx) ~= "number" or type(fz) ~= "number" then return false end
    local gx, gz = math_max(fx, 1.0), math_max(fz, 1.0)
    if gx == 1.0 and gz == 1.0 then return false end
    return true, gx, gz
end

local function land_star_leaf(object)
    if object == nil then return false end

    local ran = object.oPrevAction
    if ran ~= STAR_LEAF_OPEN and ran ~= STAR_LEAF_SHUT then return false end
    local ok, gx, gz = star_leaf_reach()
    if not ok then return false end

    local vx, vz = object.oVelX, object.oVelZ
    local px, pz = object.oPosX, object.oPosZ
    if type(vx) ~= "number" or type(vz) ~= "number"
        or type(px) ~= "number" or type(pz) ~= "number" then return false end

    if vx == 0.0 and vz == 0.0 then return false end
    object.oPosX = px + vx * (gx - 1.0)
    object.oPosZ = pz + vz * (gz - 1.0)

    if ran == STAR_LEAF_OPEN and object.oTimer == 0 then
        warp.landLeaves = (warp.landLeaves or 0) + 1
    end
    return true
end

warp.land_star_leaf = land_star_leaf

if id_bhvStarDoor ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvStarDoor, OBJ_LIST_SURFACE, false,
        land_star_leaf, land_star_leaf)
end

end

do

local CANNON_LID_OPENING = 2

warp.landLids = 0

local function cannon_lid_reach()
    if (warp.landShaped or 0) <= 0 then return false end
    if not landPlaced then return false end
    local size = landSize
    if size == nil then return false end
    local fx, fy = size.x, size.y
    if type(fx) ~= "number" or type(fy) ~= "number" then return false end
    local gx, gy = math_max(fx, 1.0), math_max(math_abs(fy), 1.0)
    if gx == 1.0 and gy == 1.0 then return false end
    return true, gx, gy
end

local function land_cannon_lid(object)
    if object == nil then return false end

    if object.oPrevAction ~= CANNON_LID_OPENING then return false end
    local flags = object.activeFlags
    if type(flags) ~= "number" or flags == 0 then return false end
    local ok, gx, gy = cannon_lid_reach()
    if not ok then return false end

    local vx, vy = object.oVelX, object.oVelY
    local px, py = object.oPosX, object.oPosY
    if type(vx) ~= "number" or type(vy) ~= "number"
        or type(px) ~= "number" or type(py) ~= "number" then return false end
    if vx == 0.0 and vy == 0.0 then return false end
    object.oPosX = px + vx * (gx - 1.0)
    object.oPosY = py + vy * (gy - 1.0)

    if object.oTimer == 0 then
        warp.landLids = (warp.landLids or 0) + 1
    end
    return true
end

warp.land_cannon_lid = land_cannon_lid

if id_bhvCannonClosed ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvCannonClosed, OBJ_LIST_SURFACE, false,
        land_cannon_lid, land_cannon_lid)
end

end

do

warp.landGates = 0

local function grill_half_reach()
    if (warp.landShaped or 0) <= 0 then return false end
    if not landPlaced then return false end
    local size = landSize
    if size == nil then return false end
    local fx = size.x
    if type(fx) ~= "number" then return false end
    local ax = math_abs(fx)
    if ax == 1.0 then return false end
    return true, ax
end

local function land_grill_half(object)
    if object == nil then return false end
    local ok, ax = grill_half_reach()
    if not ok then return false end

    local rx = object.oParentRelativePosX
    local ry = object.oParentRelativePosY
    local rz = object.oParentRelativePosZ
    if type(rx) ~= "number" or type(ry) ~= "number"
        or type(rz) ~= "number" then return false end
    if rx == 0.0 or ry ~= 0.0 or rz ~= 0.0 then return false end
    local parent = object.parentObj
    if parent == nil then return false end

    local px, pz = object.oPosX, object.oPosZ
    local qx, qz = parent.oPosX, parent.oPosZ
    if type(px) ~= "number" or type(pz) ~= "number"
        or type(qx) ~= "number" or type(qz) ~= "number" then return false end

    object.oPosX = px + (px - qx) * (ax - 1.0)
    object.oPosZ = pz + (pz - qz) * (ax - 1.0)

    object.oParentRelativePosX = rx * ax
    warp.landGates = (warp.landGates or 0) + 1
    return true
end

warp.land_grill_half = land_grill_half

if id_bhvOpenableCageDoor ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvOpenableCageDoor, OBJ_LIST_SURFACE, false,
        land_grill_half, nil)
end

end

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

            elseif sizes and land_static_object(object, ax, ay, az) then
                grown = grown + 1

            elseif land_climb_object(object, ax, ay, az) then
                grown = grown + 1

            elseif warp.land_fixture_object(object, ax, ay, az) then
                grown = grown + 1

            elseif sizes and warp.land_keep_object(object, ax, ay, az) then
                grown = grown + 1
            end

            if not warp.land_warp_object(object, ax, ay, az) then
                warp.land_cull_object(object, ax, ay, az)
            end

            warp.land_bomb_refuse(object)

            land_reach_object(object, fy, false)

            land_travel_object(object, ax, ay, az)

            land_door_rooms(object, ax, az)

            warp.land_pole_top(object)
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

warp.landLeave = setmetatable({}, { __mode = "k" })
warp.landLeft = 0

function warp.land_leave(object)
    if object ~= nil then warp.landLeave[object] = true end
    return object
end

function warp.land_left(object)
    if object == nil then return false end
    if warp.landLeave[object] then return true end
    return OF.util.asks(OF.powerups, "owns") and OF.powerups.owns(object) == true
end

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

local function land_is_star(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil then return false end
    local ok, star = pcall(function()
        return obj_has_behavior_id(object, id_bhvStarSpawnCoordinates) ~= 0
            or obj_has_behavior_id(object, id_bhvSpawnedStar) ~= 0
            or obj_has_behavior_id(object, id_bhvSpawnedStarNoLevelExit) ~= 0
    end)
    return ok and star
end

warp.land_is_star = land_is_star

function warp.star_lands_over_its_earner(object)
    if object == nil then return end
    if not OF.util.asks(OF.modifiers, "level") then return end
    if not OF.util.asks(OF.modifiers, "star_home_lift") then return end
    local over = OF.modifiers.star_home_lift()
    if type(over) ~= "number" then return end

    local m = OF.util.optional("nearest_mario_state_to_object", nil, object)
    if m == nil or m.pos == nil then return end

    object.oHomeX = m.pos.x
    object.oHomeY = m.pos.y + over
    object.oHomeZ = m.pos.z
end

if hook_behavior ~= nil and id_bhvStarSpawnCoordinates ~= nil then

    hook_behavior(id_bhvStarSpawnCoordinates, OBJ_LIST_LEVEL, false,
        warp.star_lands_over_its_earner)
end

local function land_carry_home(object, fx, fy, fz)
    if land_is_star(object) then return false end
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

do

warp.landRespawnRefused = 0
warp.landRespawnReach = 0

local function land_is_respawner(object)
    if object == nil then return false end
    if obj_has_behavior_id == nil or id_bhvRespawner == nil then return false end
    local ok, yes = pcall(function()
        return obj_has_behavior_id(object, id_bhvRespawner) ~= 0
    end)
    return ok and yes
end

warp.land_is_respawner = land_is_respawner

function warp.land_respawner(object, ax, az)
    if not land_is_respawner(object) then return false end
    warp.landRespawnRefused = (warp.landRespawnRefused or 0) + 1

    local reach = object.oRespawnerMinSpawnDist
    if type(reach) ~= "number" or reach <= 0 then return true end
    local factor = ax
    if type(factor) ~= "number" or type(az) ~= "number" then return true end
    if az < factor then factor = az end

    if factor <= 0 or factor == 1.0 then return true end
    object.oRespawnerMinSpawnDist = reach * factor
    warp.landRespawnReach = (warp.landRespawnReach or 0) + 1
    return true
end
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

                if warp.land_left(object) then
                    warp.landLeft = warp.landLeft + 1
                    return
                end
                if land_is_pathed(object) then

                    if landGrew then
                        warp.landPathed = (warp.landPathed or 0) + 1
                    end
                elseif warp.land_is_respawner(object) then
                    warp.land_respawner(object, math_abs(fx), math_abs(fz))

                elseif land_is_star(object) then

                elseif warp.land_minion_placed(object)
                    or warp.land_square_child(object, math_abs(fx), math_abs(fz))
                    or warp.land_tower_child(object, math_abs(fx), fy, math_abs(fz))
                    or warp.land_layout_child(object, math_abs(fx), fy, math_abs(fz))
                    or warp.land_hand_child(object, math_abs(fx), fy, math_abs(fz)) then

                    carried = carried + 1
                elseif land_derived(object) then

                    if land_carry_home(object, fx, fy, fz) then
                        carried = carried + 1
                    end
                else

                    local wasY = object.oPosY

                    if landGrew then
                        land_reach_object(object, fy, true)

                        land_travel_object(object, math_abs(fx), math_abs(fy),
                            math_abs(fz))
                    end
                    if land_carry_object(object, fx, fy, fz) then

                        land_seat_object(object, wasY, fy)

                        if landGrew then
                            land_door_rooms(object, math_abs(fx), math_abs(fz))
                        end
                        carried = carried + 1
                    end
                end

                if landGrew and land_is_landscape(object)
                    and obj_scale_xyz ~= nil then
                    if land_grow_object(object, math_abs(fx), math_abs(fy),
                        math_abs(fz)) then
                        warp.landGrown = (warp.landGrown or 0) + 1
                    end

                elseif landGrew and obj_scale_xyz ~= nil
                    and land_static_object(object, math_abs(fx), math_abs(fy),
                        math_abs(fz)) then
                    warp.landGrown = (warp.landGrown or 0) + 1

                elseif landGrew then
                    if not land_climb_object(object, math_abs(fx), math_abs(fy),
                        math_abs(fz)) then

                        warp.land_keep_object(object, math_abs(fx), math_abs(fy),
                            math_abs(fz))
                    end
                end

                if landGrew then
                    if not warp.land_warp_object(object, math_abs(fx),
                        math_abs(fy), math_abs(fz)) then
                        warp.land_cull_object(object, math_abs(fx),
                            math_abs(fy), math_abs(fz))
                    end
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

local EXIT_ACTIONS = {}

for _, name in ipairs({
    "ACT_EXIT_AIRBORNE", "ACT_FALLING_EXIT_AIRBORNE",
    "ACT_SPECIAL_EXIT_AIRBORNE", "ACT_DEATH_EXIT",
    "ACT_FALLING_DEATH_EXIT", "ACT_SPECIAL_DEATH_EXIT",
    "ACT_UNUSED_DEATH_EXIT",
}) do

    local value = _G[name]
    if type(value) == "number" then EXIT_ACTIONS[value] = true end
end

warp.EXIT_ACTIONS = EXIT_ACTIONS

warp.landFlights = 0

warp.landFlightRefusals = 0
warp.landFlightWhy = nil

warp.landFlightSeen = 0

local function land_is_exit_flight(m)
    if m == nil then return false end
    local action = m.action
    if type(action) ~= "number" then return false end
    return EXIT_ACTIONS[action] == true
end

warp.land_is_exit_flight = land_is_exit_flight

do

local EXIT_LAUNCH, EXIT_MARGIN = 64.0, 1.1

function warp.exit_lift(ay)
    if type(ay) ~= "number" or ay <= 0 or ay == 1.0 then return 1.0 end
    local lift = math_sqrt(ay)
    if ay > 1.0 then lift = lift * EXIT_MARGIN end
    return lift
end

local function flight_refused(why)
    warp.landFlightRefusals = (warp.landFlightRefusals or 0) + 1
    warp.landFlightWhy = why
    return false
end

function warp.exit_frame(m, stepType)
    if stepType ~= nil and stepType ~= STEP_TYPE_AIR then return false end
    if not is_mine(m) then return false end

    warp.landFlightSeen = (warp.landFlightSeen or 0) + 1
    if not land_is_exit_flight(m) then return false end

    if (warp.landShaped or 0) <= 0 then
        return flight_refused("the level being entered is not shaped")
    end
    local size = landSize
    if size == nil then return flight_refused("no size carved for this level") end
    local fx, fz = math_abs(size.x), math_abs(size.z)
    local ay = math_abs(size.y)
    if fx == 1.0 and fz == 1.0 and ay == 1.0 then
        return flight_refused("the course is unchanged")
    end
    local vel = m.vel
    if vel == nil or type(vel.x) ~= "number" or type(vel.z) ~= "number"
        or type(vel.y) ~= "number" then
        return flight_refused("the velocity could not be read")
    end

    local lift = warp.exit_lift(ay)
    if vel.y == EXIT_LAUNCH and lift ~= 1.0 then vel.y = vel.y * lift end
    local fall = math_sqrt(ay)

    if vel.x == 0.0 and vel.z == 0.0 then
        return flight_refused("the launch has no horizontal speed")
    end
    vel.x, vel.z = vel.x * fx / fall, vel.z * fz / fall
    warp.landFlights = (warp.landFlights or 0) + 1
    return true
end

end

do
local DOOR_ARRIVAL = 300.0
local DOOR_TRIGGER = 80.0
warp.landDoorCleared = 0

function warp.door_clearance(fx, fz)
    local grow = math_max(1.0, math_abs(fx or 1), math_abs(fz or 1))
    return DOOR_TRIGGER * grow + DOOR_ARRIVAL - DOOR_TRIGGER
end

local function door_clear(at, pre, yaw, fx, fy, fz)
    if at == nil or pre == nil or type(yaw) ~= "number" then return false end
    local rad = yaw * math.pi / 32768
    local dx, dz = math.sin(rad), math.cos(rad)
    local sx, sz = dx * fx, dz * fz
    local len = math_sqrt(sx * sx + sz * sz)
    if len <= 0 then return false end
    local need = warp.door_clearance(fx, fz)
    if DOOR_ARRIVAL * len >= need then return false end
    local doorX = (pre.x - DOOR_ARRIVAL * dx) * fx
    local doorZ = (pre.z - DOOR_ARRIVAL * dz) * fz
    local x = land_s16(doorX + sx / len * need)
    local z = land_s16(doorZ + sz / len * need)
    if find_floor ~= nil then
        local _, floor = find_floor(x, at.y, z)
        if floor == nil then return false end
    end

    if not warp.same_room(at.x, at.y, at.z, x, at.y, z) then return false end
    at.x, at.z = x, z
    return true
end
warp.door_clear = door_clear
end

do
warp.DOOR_SPAWN_LIMIT = 60
warp.doorSpawnsReleased = 0
local spawnHeld = 0

function warp.room_at(x, y, z)
    if type(find_floor) ~= "function" then return nil end
    local _, floor = find_floor(x, y + 100, z)
    if floor == nil then return nil end
    return floor.room
end

function warp.same_room(ax, ay, az, bx, by, bz)
    local a = warp.room_at(ax, ay, az)
    if a == nil or a == 0 then return true end
    return warp.room_at(bx, by, bz) == a
end

function warp.door_draws_at(door, x, y, z)
    if door == nil then return true end
    local room = warp.room_at(x, y, z)
    if room == nil or room == 0 then return true end
    for _, field in ipairs({ "oDoorUnkF8", "oDoorUnkFC", "oDoorUnk100" }) do
        if door[field] == room then return true end
    end
    return false
end

function warp.door_spawn_watch(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if ACT_WARP_DOOR_SPAWN == nil or m.action ~= ACT_WARP_DOOR_SPAWN or m.actionState ~= 1 then
        spawnHeld = 0
        return false
    end
    spawnHeld = spawnHeld + 1
    if spawnHeld <= warp.DOOR_SPAWN_LIMIT then return false end
    spawnHeld = 0
    set_mario_action(m, ACT_IDLE, 0)
    warp.doorSpawnsReleased = warp.doorSpawnsReleased + 1
    return true
end
end

do
warp.DOOR_SPARE = 183
warp.DOOR_ARRIVAL_FRAMES = 30
warp.doorArrivalsCleared = 0
local doorArrival = 0

function warp.arm_door_arrival()
    doorArrival = warp.DOOR_ARRIVAL_FRAMES
end

function warp.door_arrival_need(m, door)
    if m == nil or m.marioObj == nil or door == nil then return nil end
    local doorR = tonumber(door.hitboxRadius) or 80
    local mine = tonumber(m.marioObj.hitboxRadius) or 37
    return doorR + mine + warp.DOOR_SPARE
end

function warp.door_arrival_clear(m)
    if m == nil or m.playerIndex ~= 0 or m.pos == nil or m.marioObj == nil then
        return false
    end
    if ACT_WARP_DOOR_SPAWN == nil or m.action ~= ACT_WARP_DOOR_SPAWN then return false end
    if id_bhvDoorWarp == nil then return false end
    local door = OF.util.optional("obj_get_nearest_object_with_behavior_id", nil,
        m.marioObj, id_bhvDoorWarp)
    if door == nil or type(door.oPosX) ~= "number" then return false end
    local need = warp.door_arrival_need(m, door)
    if need == nil then return false end
    local dx, dz = m.pos.x - door.oPosX, m.pos.z - door.oPosZ
    local dist = math_sqrt(dx * dx + dz * dz)
    if dist >= need then return false end
    local ux, uz
    if dist > 1 then
        ux, uz = dx / dist, dz / dist
    else
        local info = m.spawnInfo
        local yaw = (info ~= nil and info.startAngle ~= nil and info.startAngle.y)
            or (m.faceAngle ~= nil and m.faceAngle.y) or 0
        local rad = yaw * math.pi / 32768
        ux, uz = math.sin(rad), math.cos(rad)
    end
    local x, z = door.oPosX + ux * need, door.oPosZ + uz * need
    local ground = OF.util.optional("find_floor_height", nil, x, m.pos.y + 100, z)
    if type(ground) ~= "number" then return false end
    local void = -11000
    if OF.is_object(gLevelValues) and type(gLevelValues.floorLowerLimit) == "number" then
        void = gLevelValues.floorLowerLimit
    end
    if ground <= void or math_abs(ground - m.pos.y) > 150 then return false end

    if not warp.door_draws_at(door, x, ground, z) then return false end
    if not OF.util.place_player(0, x, ground, z) then return false end
    warp.doorArrivalsCleared = warp.doorArrivalsCleared + 1
    return true
end

function warp.door_arrival_frame(m)
    if doorArrival <= 0 then return false end
    if m == nil or m.playerIndex ~= 0 then return false end
    doorArrival = doorArrival - 1
    if ACT_WARP_DOOR_SPAWN == nil or m.action ~= ACT_WARP_DOOR_SPAWN then
        doorArrival = 0
        return false
    end
    local moved = warp.door_arrival_clear(m)
    if moved then doorArrival = 0 end
    return moved
end
end

do
warp.DOOR_PASS_END = 300
warp.STAR_PASS_END = 150
warp.doorPassHeld = 0
local passedDoor = nil

local function door_pass_action(action)
    return action ~= nil and (action == ACT_PULLING_DOOR or action == ACT_PUSHING_DOOR)
end

function warp.inside_door_trigger(m, door)
    if m == nil or m.pos == nil or door == nil or type(door.oPosX) ~= "number" then return false end
    local reach = (tonumber(door.hitboxRadius) or 80)
        + (m.marioObj ~= nil and tonumber(m.marioObj.hitboxRadius) or 37)
    local dx, dz = m.pos.x - door.oPosX, m.pos.z - door.oPosZ
    return math_sqrt(dx * dx + dz * dz) < reach
end

function warp.door_pass_frame(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if door_pass_action(m.action) then
        passedDoor = m.usedObj
        return
    end
    if passedDoor ~= nil then
        local gone = (tonumber(passedDoor.activeFlags) or 1) == 0
        if gone or not warp.inside_door_trigger(m, passedDoor) then passedDoor = nil end
    end
end

function warp.door_pass_allow(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 or obj == nil then return nil end
    if interactType ~= INTERACT_DOOR or passedDoor == nil or obj ~= passedDoor then return nil end
    if not warp.inside_door_trigger(m, obj) then
        passedDoor = nil
        return nil
    end
    warp.doorPassHeld = warp.doorPassHeld + 1
    return false
end

function warp.forget_door_pass()
    passedDoor = nil
end
end

do
local FLAG_PSS = SAVE_FLAG_UNLOCKED_PSS_DOOR or (1 << 10)
local FLAG_WF = SAVE_FLAG_UNLOCKED_WF_DOOR or (1 << 11)
local FLAG_CCM = SAVE_FLAG_UNLOCKED_CCM_DOOR or (1 << 12)
local FLAG_JRB = SAVE_FLAG_UNLOCKED_JRB_DOOR or (1 << 13)
warp.doorFlagsMended = 0
local unlocking = nil

function warp.door_flag_at(stars, x, y)
    if stars == 1 then return y > 500.0 and FLAG_PSS or FLAG_WF end
    if stars == 3 then return x < 0.0 and FLAG_CCM or FLAG_JRB end
    return nil
end

function warp.door_flags(door)
    if door == nil or type(door.oPosX) ~= "number" or type(door.oPosY) ~= "number" then return nil end
    local stars = math.floor((tonumber(door.oBehParams) or 0) / 0x1000000) % 0x100
    if stars ~= 1 and stars ~= 3 then return nil end
    local size = landSize
    local fx = size ~= nil and tonumber(size.x) or 1.0
    local fy = size ~= nil and tonumber(size.y) or 1.0
    if (warp.landShaped or 0) <= 0 or fx == 0 or fy == 0 then fx, fy = 1.0, 1.0 end
    local read = warp.door_flag_at(stars, door.oPosX, door.oPosY)
    local truth = warp.door_flag_at(stars, door.oPosX / fx, door.oPosY / fy)
    return read, truth, stars
end

local function push_or_pull(m, door)
    local dx, dz = door.oPosX - m.pos.x, door.oPosZ - m.pos.z
    local turn = ((door.oMoveAngleYaw or 0) - atan2s(dz, dx)) % 0x10000
    if turn >= 0x8000 then turn = turn - 0x10000 end
    return (turn >= -0x4000 and turn <= 0x4000) and 1 or 2
end

function warp.door_flag_allow(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 or obj == nil or interactType ~= INTERACT_DOOR then return nil end
    if m.action ~= ACT_WALKING and m.action ~= ACT_DECELERATING then return nil end
    local read, truth, stars = warp.door_flags(obj)
    if read == nil or read == truth then return nil end
    local have = OF.util.optional("save_file_get_total_star_count", 0,
        (gCurrSaveFileNum or 1) - 1, (COURSE_MIN or 1) - 1, (COURSE_MAX or 25) - 1) or 0
    if have < stars then return nil end
    local flags = OF.util.optional("save_file_get_flags", 0) or 0
    local arg = push_or_pull(m, obj)
    m.interactObj, m.usedObj = obj, obj
    if flags & truth ~= 0 then
        set_mario_action(m, arg == 1 and ACT_PULLING_DOOR or ACT_PUSHING_DOOR, arg)
    else
        unlocking = { door = obj, truth = truth, read = read, had = flags & read ~= 0 }
        set_mario_action(m, ACT_UNLOCKING_STAR_DOOR, arg)
    end
    warp.doorFlagsMended = warp.doorFlagsMended + 1
    return false
end

function warp.door_flag_frame(m)
    if unlocking == nil or m == nil or m.playerIndex ~= 0 then return end
    if m.action == ACT_UNLOCKING_STAR_DOOR then return end
    OF.util.optional("save_file_set_flags", nil, unlocking.truth)
    if not unlocking.had then OF.util.optional("save_file_clear_flags", nil, unlocking.read) end
    unlocking = nil
end
end

local function arrival_has_floor(fx, fy, fz)
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    local info = me ~= nil and me.spawnInfo or nil
    local at = info ~= nil and info.startPos or nil
    if at == nil then return true end
    local sx, sy, sz = at.x, at.y, at.z
    if type(sx) ~= "number" or type(sy) ~= "number"
        or type(sz) ~= "number" then return true end

    if land_is_exit_flight(me) then
        warp.landFlightArrivals = (warp.landFlightArrivals or 0) + 1
        return true
    end
    if find_floor == nil then return true end
    local _, floor = find_floor(sx * fx, sy * fy, sz * fz)
    return floor ~= nil
end

function warp.land_arrived()
    return landArrived
end

local SAME_AREA = WARP_TYPE_SAME_AREA or 3

warp.landArrivalsKept = 0

function warp.land_arrive(warpType)

    if (warp.landShaped or 0) <= 0 then return 0 end
    local size = landSize
    if size == nil then return 0 end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return 0 end

    local sameArea = (type(warpType) == "number" and warpType == SAME_AREA)
    if sameArea then
        warp.landArrivalsKept = (warp.landArrivalsKept or 0) + 1
    end

    local where = land_where()
    local carried = 0
    if (not sameArea) and ((not landArrived) or where ~= landArrivedWhere) then
        landArrived = true
        landArrivedWhere = where

        if not arrival_has_floor(fx, fy, fz) then
            warp.landNoFloor = (warp.landNoFloor or 0) + 1
            return 0
        end

        local me0 = gMarioStates ~= nil and gMarioStates[0] or nil
        local rec0 = me0 ~= nil and me0.spawnInfo or nil
        local pre = nil
        if rec0 ~= nil and rec0.startPos ~= nil then
            pre = { x = rec0.startPos.x, y = rec0.startPos.y, z = rec0.startPos.z }
        end
        for i = 0, (MAX_PLAYERS or 1) - 1 do
            local m = gMarioStates ~= nil and gMarioStates[i] or nil
            if carry_spawn(m, fx, fy, fz) then carried = carried + 1 end
        end

        if me0 ~= nil and ACT_WARP_DOOR_SPAWN ~= nil and me0.action == ACT_WARP_DOOR_SPAWN
            and pre ~= nil and rec0.startAngle ~= nil then
            local yaw = rec0.startAngle.y
            local fixed = nil
            for i = 0, (MAX_PLAYERS or 1) - 1 do
                local m = gMarioStates ~= nil and gMarioStates[i] or nil
                local rec = m ~= nil and m.spawnInfo or nil
                if rec ~= nil and rec.startPos ~= nil then
                    if i == 0 then
                        if warp.door_clear(rec.startPos, pre, yaw, fx, fy, fz) then
                            fixed = { x = rec.startPos.x, z = rec.startPos.z }
                            warp.landDoorCleared = (warp.landDoorCleared or 0) + 1
                        end
                    elseif fixed ~= nil then
                        rec.startPos.x, rec.startPos.z = fixed.x, fixed.z
                    end
                end
            end
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

do
local DIAMOND_INIT = 0

function warp.land_water_diamond(object)
    if object == nil or object.oAction ~= DIAMOND_INIT then return false end
    if (warp.landShaped or 0) <= 0 then return false end
    local size = landSize
    local fy = size ~= nil and size.y or nil
    if type(fy) ~= "number" or fy == 0 or fy == 1.0 then return false end
    local y = tonumber(object.oPosY)
    if y == nil then return false end
    local authored = y / fy
    if authored >= 0 then authored = math_floor(authored) else authored = -math_floor(-authored) end
    object.oWaterLevelTriggerTargetWaterLevel = authored
    return true
end

if id_bhvWaterLevelDiamond ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvWaterLevelDiamond, OBJ_LIST_SURFACE, false, nil, warp.land_water_diamond)
end
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

    if land_no_water(under) then return under end

    return under * fy
end

warp.land_water = land_water

do
local inGas = false

local function land_gas(x, z)
    if inGas then return nil end
    if (warp.landShaped or 0) <= 0 then return nil end
    local size = landSize
    if size == nil then return nil end
    local fx, fy, fz = size.x, size.y, size.z
    if fx == 1.0 and fy == 1.0 and fz == 1.0 then return nil end

    if fx == 0 or fy == 0 or fz == 0 then return nil end
    local ask = OF.util.binding("find_poison_gas_level")
    if ask == nil then return nil end
    inGas = true
    local under = ask(x / fx, z / fz)
    inGas = false
    if type(under) ~= "number" then return nil end

    if land_no_water(under) then return under end
    return under * fy
end

warp.land_gas = land_gas
end

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

        if (not held.sentinel) and held.base < 0 and moved > held.base then
            moved = held.base
        end

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

local STAR_HOMES = {
    "BalconyBooStarPos", "BigBullyStarPos", "BigBullyTrioStarPos",
    "BigPiranhasStarPos", "CcmSlideStarPos", "ChillBullyStarPos",
    "EyerockStarPos", "GhostHuntBooStarPos", "JetstreamRingStarPos",
    "KingBobombStarPos", "KingWhompStarPos", "KleptoStarPos",
    "KoopaBobStarPos", "KoopaThiStarPos", "MantaRayStarPos",
    "MerryGoRoundStarPos", "MrIStarPos", "PssSlideStarPos",
    "RacingPenguinStarPos", "SnowmanHeadStarPos", "TreasureChestStarPos",
    "TreasureJrbStarPos", "TuxieMotherStarPos", "UkikiCageStarPos",
    "UnagiStarPos", "WigglerStarPos",
}

warp.STAR_HOMES = STAR_HOMES

local landStars = nil

local landStarred = false

local landStarredAt = nil

local function land_stars_remember()
    if landStars ~= nil then return true end
    if gLevelValues == nil then return false end
    local all = gLevelValues.starPositions
    if all == nil then return false end
    landStars = {}
    for _, field in ipairs(STAR_HOMES) do
        local spot = all[field]
        if spot ~= nil and type(spot.x) == "number"
            and type(spot.y) == "number" and type(spot.z) == "number" then
            landStars[field] = { x = spot.x, y = spot.y, z = spot.z }
        end
    end
    return true
end

function warp.apply_stars()

    if not OF.util.asks(OF.rules, "set_star_home") then return false end
    if not land_stars_remember() then return false end
    local fx, fy, fz = 1.0, 1.0, 1.0
    local size = landSize
    if (warp.landShaped or 0) > 0 and size ~= nil then
        fx, fy, fz = size.x, size.y, size.z
    end

    local plain = (fx == 1.0 and fy == 1.0 and fz == 1.0)
    if plain and not landStarred then return false end

    local at = tostring(fx) .. "," .. tostring(fy) .. "," .. tostring(fz)
    if at == landStarredAt then return false end

    local wrote = 0
    for _, field in ipairs(STAR_HOMES) do
        local base = landStars[field]
        if base ~= nil then
            if OF.rules.set_star_home(field, base.x * fx, base.y * fy,
                base.z * fz) then
                wrote = wrote + 1
            end
        end
    end

    landStarred = not plain
    if wrote > 0 then landStarredAt = at end
    return wrote > 0
end

function warp.land_star_base(field)
    land_stars_remember()
    if landStars == nil then return nil end
    local base = landStars[field]
    if base == nil then return nil end
    return base.x, base.y, base.z
end

do

local landBully = nil

local landBullied = false

local function land_bully_remember()
    if landBully ~= nil then return true end
    if gBehaviorValues == nil then return false end
    local base = nil
    if OF.util.asks(OF.rules, "bully_death_base") then
        base = OF.rules.bully_death_base()
    end

    if type(base) ~= "number" then base = gBehaviorValues.ChillBullyDeathPosY end
    if type(base) ~= "number" then return false end
    landBully = base
    return true
end

function warp.apply_bully()

    if not OF.util.asks(OF.rules, "set_bully_death") then return false end
    if not land_bully_remember() then return false end
    local fy = 1.0
    local size = landSize
    if (warp.landShaped or 0) > 0 and size ~= nil then
        fy = size.y
    end

    if fy == 0 then fy = 1.0 end

    if fy == 1.0 and not landBullied then return false end
    local wrote = OF.rules.set_bully_death(landBully * fy)

    landBullied = (fy ~= 1.0)
    return wrote
end

function warp.land_bully_base()
    land_bully_remember()
    return landBully
end

end

local landWarps = {}

warp.landWarpsRefused = 0

local function land_warp_fits(value)
    return value >= -VERTEX_MAX and value <= VERTEX_MAX
end

warp.seamRest = warp.seamRest or {}

function warp.seam_key(level, id, destArea)
    return tostring(level) .. ":" .. tostring(id) .. ":" .. tostring(destArea)
end

function warp.forget_seams()
    warp.seamRest = {}
end

function warp.carry_seam(destArea, id)
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil then return false end

    if (warp.landShaped or 0) <= 0 then return false end
    local rest = warp.seamRest[warp.seam_key(me.currLevelNum, id, destArea)]
    if rest == nil then return false end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil then return false end
    m.pos.x, m.pos.y, m.pos.z = m.pos.x + rest.x, m.pos.y + rest.y, m.pos.z + rest.z
    if m.nonInstantWarpPos ~= nil then
        m.nonInstantWarpPos.x = m.pos.x
        m.nonInstantWarpPos.y = m.pos.y
        m.nonInstantWarpPos.z = m.pos.z
    end
    local o = m.marioObj
    if o ~= nil then o.oPosX, o.oPosY, o.oPosZ = m.pos.x, m.pos.y, m.pos.z end
    OF.util.optional("warp_camera", nil, rest.x, rest.y, rest.z)
    warp.seamsCarried = (warp.seamsCarried or 0) + 1
    return true
end

if HOOK_ON_INSTANT_WARP ~= nil then
    hook_event(HOOK_ON_INSTANT_WARP, function(area, id)
        warp.carry_seam(area, id)
    end)
end

function warp.apply_warps()
    if get_instant_warp == nil then return 0 end
    local where = land_where()
    if where == nil then return 0 end

    local fx, fy, fz = 1.0, 1.0, 1.0
    local size = landSize
    if (warp.landShaped or 0) > 0 and size ~= nil then
        fx, fy, fz = size.x, size.y, size.z
    end
    local plain = (fx == 1.0 and fy == 1.0 and fz == 1.0)

    local wrote = 0
    for index = 0, 3 do

        pcall(function()
            local seam = get_instant_warp(index)
            if seam == nil then return end
            local id = seam.id

            if type(id) ~= "number" or id == 0 then return end
            local at = seam.displacement
            if at == nil then return end
            if type(at.x) ~= "number" or type(at.y) ~= "number"
                or type(at.z) ~= "number" then return end

            local key = where .. ":" .. tostring(index)
            local held = landWarps[key]
            if held ~= nil and (held.id ~= id or held.area ~= seam.area) then
                held = nil
            end
            if held == nil then
                held = { x = at.x, y = at.y, z = at.z, away = false,
                    id = id, area = seam.area }
                landWarps[key] = held
            end

            local seamKey = warp.seam_key(where:match("^([^:]*)"), id, seam.area)
            if plain and not held.away then
                warp.seamRest[seamKey] = nil
                return
            end

            local nx = land_round(held.x * fx)
            local ny = land_round(held.y * fy)
            local nz = land_round(held.z * fz)
            if not (land_warp_fits(nx) and land_warp_fits(ny)
                and land_warp_fits(nz)) then
                warp.landWarpsRefused = (warp.landWarpsRefused or 0) + 1

                if held.away then
                    at.x, at.y, at.z = held.x, held.y, held.z
                    held.away = false
                end

                warp.seamRest[seamKey] = { x = nx - held.x, y = ny - held.y,
                    z = nz - held.z }
                return
            end
            warp.seamRest[seamKey] = nil
            at.x, at.y, at.z = nx, ny, nz
            held.away = not plain
            wrote = wrote + 1
        end)
    end
    return wrote
end

function warp.land_warp_base(where, index)
    local held = landWarps[tostring(where) .. ":" .. tostring(index)]
    if held == nil then return nil end
    return held.x, held.y, held.z
end

do

local landWhirls = {}

warp.landWhirlRefused = 0
warp.landWhirls = 0

function warp.apply_whirlpools()
    local where = land_where()
    if where == nil then return 0 end
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    if me == nil then return 0 end
    local area = me.area
    if area == nil then return 0 end
    local pools = area.whirlpools
    if pools == nil then return 0 end

    local fx, fy, fz = 1.0, 1.0, 1.0
    local size = landSize
    if (warp.landShaped or 0) > 0 and size ~= nil then
        fx, fy, fz = size.x, size.y, size.z
    end
    local plain = (fx == 1.0 and fy == 1.0 and fz == 1.0)

    local wrote = 0
    for index = 1, 2 do

        pcall(function()
            local pool = pools[index]
            if pool == nil then return end
            local at = pool.pos
            if at == nil then return end
            if type(at.x) ~= "number" or type(at.y) ~= "number"
                or type(at.z) ~= "number" then return end

            local key = where .. ":" .. tostring(index)
            local held = landWhirls[key]
            if held ~= nil and held.strength ~= pool.strength then held = nil end
            if held == nil then
                held = { x = at.x, y = at.y, z = at.z, away = false,
                    strength = pool.strength }
                landWhirls[key] = held
            end

            if plain and not held.away then return end

            local nx = land_round(held.x * fx)
            local ny = land_round(held.y * fy)
            local nz = land_round(held.z * fz)
            if not (land_warp_fits(nx) and land_warp_fits(ny)
                and land_warp_fits(nz)) then
                warp.landWhirlRefused = (warp.landWhirlRefused or 0) + 1

                if held.away then
                    at.x, at.y, at.z = held.x, held.y, held.z
                    held.away = false
                end
                return
            end
            at.x, at.y, at.z = nx, ny, nz
            held.away = not plain
            wrote = wrote + 1
        end)
    end
    warp.landWhirls = (warp.landWhirls or 0) + wrote
    return wrote
end

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

local COUNTER_FLOOR = 0.0001

local COUNTER_CEILING = 4096

do

local BILLBOARD_UPRIGHT = GRAPH_RENDER_CYLBOARD or 0x0040
local BILLBOARD_FLAGS = (GRAPH_RENDER_BILLBOARD or 0x0004) | BILLBOARD_UPRIGHT
local FORCE_3D = GRAPH_EXTRA_FORCE_3D or 0x0001

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

warp.land_is_billboard = land_is_billboard

local function land_is_upright(gfx)
    if gfx == nil then return false end
    local node = gfx.node
    local flags = node ~= nil and node.flags or nil
    if type(flags) ~= "number" then return false end
    return flags & BILLBOARD_UPRIGHT ~= 0
end

warp.land_is_upright = land_is_upright

local function land_is_sized(object)
    if object == nil then return false end
    return land_is_landscape(object) or land_is_climbed(object)
end

warp.land_is_sized = land_is_sized

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

function warp.billboard_landscape(fx, fy, fz)
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then
        return nil
    end
    local ax, ay, az = math_abs(fx), math_abs(fy), math_abs(fz)

    if ax == 0 or ay == 0 or az == 0 then return nil end
    return 1.0 / ax, 1.0 / ay, 1.0 / az, fy / ay
end

local landHeld = {}
local landHeldCount = 0

local function land_shape_list(list, cx, cy, cz, gx, gy, gz, hy)

    local is_billboard = warp.land_is_billboard
    local is_upright = warp.land_is_upright
    local is_sized = warp.land_is_sized
    local mark_inner = warp.land_inner_mark_shared
    local object = obj_get_first(list)
    local seen = 0
    while object ~= nil and seen < 1200 do
        if landHeldCount >= COUNTER_CEILING then return end
        local header = object.header
        local gfx = header ~= nil and header.gfx or nil

        if gfx ~= nil then mark_inner(gfx.sharedChild) end
        if is_billboard(gfx) then
            local size = gfx.scale
            if size ~= nil then
                local sx, sy, sz = size.x, size.y, size.z
                if type(sx) == "number" and type(sy) == "number"
                    and type(sz) == "number" then

                    local useX, useY, useZ = cx, cy, cz
                    if gx ~= nil and is_sized(object) then
                        useX, useZ = gx, gz
                        useY = is_upright(gfx) and hy or gy
                    end
                    local at = landHeldCount * 4
                    landHeld[at + 1] = object
                    landHeld[at + 2] = sx
                    landHeld[at + 3] = sy
                    landHeld[at + 4] = sz
                    landHeldCount = landHeldCount + 1
                    size.x, size.y, size.z = sx * useX, sy * useY, sz * useZ
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
    warp.landInner.on = false
    if landView == nil then return 0 end
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return 0 end
    local cx, cy, cz = warp.billboard_counter(fx, fy, fz, landView)
    if cx == nil then return 0 end

    if cx == 1.0 and cy == 1.0 and cz == 1.0 then return 0 end

    local gx, gy, gz, hy = warp.billboard_landscape(fx, fy, fz)

    local inner = warp.landInner
    inner.on, inner.cx, inner.cy, inner.cz = true, cx, cy, cz
    inner.gx, inner.gy, inner.gz = gx, gy, gz
    for _, list in ipairs(ALL_LISTS) do
        warp.walks = warp.walks + 1
        land_shape_list(list, cx, cy, cz, gx, gy, gz, hy)
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

warp.landInner = { on = false }
warp.landInnerMarked = 0
do
local INNER_NODE = GRAPH_NODE_TYPE_BILLBOARD or 0x01A
local INNER_BUDGET = 128
local innerSeen = setmetatable({}, { __mode = "k" })

local borrow = { size = nil, prevSize = nil }

local function mark(first, budget)
    if first == nil or budget <= 0 then return 0, budget end
    local marked, node = 0, first
    repeat
        budget = budget - 1
        if budget < 0 then return marked, 0 end
        if node.type == INNER_NODE then
            if (node.hookProcess or 0) == 0 then node.hookProcess = LAND_MARK end
            marked = marked + 1
        end
        local more
        more, budget = mark(node.children, budget)
        marked = marked + more
        node = node.next
    until node == nil or node == first or budget <= 0
    return marked, budget
end

function warp.land_inner_mark_shared(shared)
    if shared == nil or innerSeen[shared] then return 0 end
    innerSeen[shared] = true
    local marked = mark(shared, INNER_BUDGET)
    warp.landInnerMarked = (warp.landInnerMarked or 0) + marked
    return marked
end

function warp.land_inner_factors(object)
    local inner = warp.landInner
    if not inner.on or object == nil then return nil end
    local header = object.header
    local gfx = header ~= nil and header.gfx or nil
    if gfx == nil or warp.land_is_billboard(gfx) then return nil end
    if warp.land_was_sized(object) and inner.gx ~= nil then
        return inner.gx, inner.gy, inner.gz
    end
    return inner.cx, inner.cy, inner.cz
end

function warp.land_inner_before(node)
    if node == nil or node.type ~= INNER_NODE then return false end
    if borrow.size ~= nil then return false end
    local object = nil
    local held = OF.util.optional("geo_get_current_held_object", nil)
    if held ~= nil then object = held.objNode end
    if object == nil then object = OF.util.optional("geo_get_current_object", nil) end
    local ax, ay, az = warp.land_inner_factors(object)
    if ax == nil then return false end
    local gfx = object.header.gfx
    local size, prev = gfx.scale, gfx.prevScale
    if size == nil then return false end
    borrow.size, borrow.sx, borrow.sy, borrow.sz = size, size.x, size.y, size.z
    size.x, size.y, size.z = size.x * ax, size.y * ay, size.z * az
    if prev ~= nil then
        borrow.prevSize, borrow.px, borrow.py, borrow.pz = prev, prev.x, prev.y, prev.z
        prev.x, prev.y, prev.z = prev.x * ax, prev.y * ay, prev.z * az
    end
    return true
end

function warp.land_inner_after(node)
    if node == nil or node.type ~= INNER_NODE then return false end
    local size = borrow.size
    if size == nil then return false end
    size.x, size.y, size.z = borrow.sx, borrow.sy, borrow.sz
    local prev = borrow.prevSize
    if prev ~= nil then prev.x, prev.y, prev.z = borrow.px, borrow.py, borrow.pz end
    borrow.size, borrow.prevSize = nil, nil
    return true
end
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

local function land_scale_rows(slot, fx, fy, fz)
    if slot == nil then return false end
    slot.m00 = (slot.m00 or 0) * fx
    slot.m01 = (slot.m01 or 0) * fx
    slot.m02 = (slot.m02 or 0) * fx
    slot.m03 = (slot.m03 or 0) * fx
    slot.m10 = (slot.m10 or 0) * fy
    slot.m11 = (slot.m11 or 0) * fy
    slot.m12 = (slot.m12 or 0) * fy
    slot.m13 = (slot.m13 or 0) * fy
    slot.m20 = (slot.m20 or 0) * fz
    slot.m21 = (slot.m21 or 0) * fz
    slot.m22 = (slot.m22 or 0) * fz
    slot.m23 = (slot.m23 or 0) * fz
    return true
end

warp.LAND_MOVE_TYPES = {
    [GRAPH_NODE_TYPE_TRANSLATION_ROTATION or 0x015] = true,
    [GRAPH_NODE_TYPE_TRANSLATION or 0x016] = true,
    [GRAPH_NODE_TYPE_ROTATION or 0x017] = true,
}

warp.LAND_OBJECT_PARENT = GRAPH_NODE_TYPE_OBJECT_PARENT or 0x029

warp.LAND_MOVE_HOLDERS = {
    [GRAPH_NODE_TYPE_START or 0x00A] = true,
    [GRAPH_NODE_TYPE_LEVEL_OF_DETAIL or 0x00B] = true,
    [GRAPH_NODE_TYPE_SWITCH_CASE or 0x10C] = true,
    [GRAPH_NODE_TYPE_CULLING_RADIUS or 0x02F] = true,
}

function warp.land_find_moves(first, parent, budget, out)
    if first == nil or budget <= 0 then return budget end
    local node = first
    repeat
        budget = budget - 1
        if budget < 0 then return 0 end
        local kind = node.type
        if warp.LAND_MOVE_TYPES[kind] then
            if parent ~= nil and warp.LAND_MOVE_HOLDERS[parent.type] then
                local dup = false
                for _, have in ipairs(out) do if have == parent then dup = true end end
                if not dup then out[#out + 1] = parent end
            end
        elseif kind ~= warp.LAND_OBJECT_PARENT then
            budget = warp.land_find_moves(node.children, node, budget, out)
        end
        node = node.next
    until node == nil or node == first or budget <= 0
    return budget
end

warp.landMovesNode = nil
function warp.land_moves(camera)
    if camera == nil then return 0 end
    if warp.landMovesNode ~= nil and camera == warp.landMovesNode then return 0 end
    warp.landMovesNode = camera
    local found = {}
    warp.land_find_moves(camera.children, camera, 256, found)
    local marked = 0
    for _, node in ipairs(found) do
        if (node.hookProcess or 0) == 0 then
            node.hookProcess = LAND_MARK
            marked = marked + 1
        end
    end
    warp.landMoves = marked
    return marked
end

function warp.forget_moves()
    warp.landMovesNode = nil
    warp.landMoves = 0
end

warp.landMoveSlot = nil
function warp.land_move_in(node, index)
    if node == nil or not warp.LAND_MOVE_HOLDERS[node.type] then return false end
    if (node.hookProcess or 0) ~= LAND_MARK then return false end
    if warp.landMoveSlot ~= nil then return false end
    local lit, fx, fy, fz = warp.picture_scaled()
    if not lit or gMatStack == nil or index == nil then return false end
    if not land_scale_rows(gMatStack[index], fx, fy, fz) then return false end
    if gMatStackPrev ~= nil then land_scale_rows(gMatStackPrev[index], fx, fy, fz) end
    warp.landMoveSlot = index
    return true
end

function warp.land_move_out(node)
    if node == nil or (node.hookProcess or 0) ~= LAND_MARK then return false end
    if not warp.LAND_MOVE_HOLDERS[node.type] then return false end
    local index = warp.landMoveSlot
    if index == nil then return false end
    warp.landMoveSlot = nil
    local lit, fx, fy, fz = warp.picture_scaled()
    if not lit or gMatStack == nil then return false end
    land_scale_slot(gMatStack[index], fx, fy, fz)
    if gMatStackPrev ~= nil then land_scale_slot(gMatStackPrev[index], fx, fy, fz) end
    return true
end

local LAND_SCALE_ONE = GRAPH_NODE_TYPE_SCALE or 0x01C
local LAND_SCALE_XYZ = GRAPH_NODE_TYPE_SCALE_XYZ or 0x01D

local LAND_TREE_BUDGET = 64

local landIslandNode = nil

warp.landIslands = 0

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

        if not warp.LAND_MOVE_TYPES[kind]
            and not ((node.hookProcess or 0) == LAND_MARK and warp.LAND_MOVE_HOLDERS[kind]) then
            local found
            found, budget = land_find_scale(node.children, budget)
            if found ~= nil then return found, budget end
        end
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

function warp.land_island(node, fx, fy, fz)
    if node == nil then return false end
    if landIslandNode ~= nil and node == landIslandNode then return false end
    local found = land_find_scale(node.children, LAND_TREE_BUDGET)
    if found == nil then return false end

    local kind = found.type

    if kind == LAND_SCALE_ONE and not warp.land_island_uniform(fx, fy, fz) then
        landIslandNode = node
        if (found.hookProcess or 0) == 0 then
            found.hookProcess = LAND_MARK
        end

        warp.landIslands = (warp.landIslands or 0) + 1
        return true
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
    warp.forget_moves()
    landIslandNode = nil
    warp.landIslands = 0
end

function warp.landscape_frame(node, matStackIndex)
    if node == nil then return false end

    if node.type == LAND_SCALE_ONE or node.type == LAND_SCALE_XYZ then
        if (node.hookProcess or 0) ~= LAND_MARK then return false end
        local lit, ix, iy, iz = warp.picture_scaled()
        if not lit then return false end
        if gMatStack == nil or matStackIndex == nil then return false end
        local wrote = land_scale_rows(gMatStack[matStackIndex], ix, iy, iz)
        if gMatStackPrev ~= nil then
            land_scale_rows(gMatStackPrev[matStackIndex], ix, iy, iz)
        end
        return wrote
    end

    if node.type ~= LAND_CAMERA then return warp.land_move_in(node, matStackIndex) end
    landUnseen = 0

    warp.landMoveSlot = nil
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return false end
    if gMatStack == nil or matStackIndex == nil then return false end

    land_remember_view(gMatStack[matStackIndex])
    local done = land_scale_slot(gMatStack[matStackIndex], fx, fy, fz)

    if done then landDrawnAt = OF.util.optional("get_global_timer", nil) end
    if gMatStackPrev ~= nil then
        land_scale_slot(gMatStackPrev[matStackIndex], fx, fy, fz)
    end

    pcall(warp.land_moves, node)
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

warp.READBACK_PARENTS = {
    "id_bhvBowser", "id_bhvKingBobomb", "id_bhvChuckya", "id_bhvEnemyLakitu",
}

do

local holpPut = {}
local readAt = nil

local function undo(v, ux, uy, uz)
    if v == nil then return false end
    local x, y, z = v.x, v.y, v.z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return false
    end
    v.x, v.y, v.z = x * ux, y * uy, z * uz
    return true
end

local function put_back_child(parent, child, ux, uy, uz)
    if parent == nil or child == nil then return false end
    local px, py, pz = parent.oPosX, parent.oPosY, parent.oPosZ
    local cx, cy, cz = child.oPosX, child.oPosY, child.oPosZ
    if type(px) ~= "number" or type(cx) ~= "number" then return false end
    local tx, ty, tz = cx * ux, cy * uy, cz * uz
    local nowGap = (cx - px) ^ 2 + (cy - py) ^ 2 + (cz - pz) ^ 2
    local trueGap = (tx - px) ^ 2 + (ty - py) ^ 2 + (tz - pz) ^ 2
    if not (trueGap < nowGap) then return false end
    child.oPosX, child.oPosY, child.oPosZ = tx, ty, tz

    local gfx = child.header ~= nil and child.header.gfx or nil
    local at = gfx ~= nil and gfx.pos or nil
    if at ~= nil and at.x == cx and at.y == cy and at.z == cz then
        at.x, at.y, at.z = tx, ty, tz
    end
    return true
end

local function children(ux, uy, uz)
    if obj_get_first_with_behavior_id == nil then return 0 end
    local given = 0
    for _, name in ipairs(warp.READBACK_PARENTS) do
        local id = _G[name]
        if type(id) == "number" then
            local parent = obj_get_first_with_behavior_id(id)
            local seen = 0
            while parent ~= nil and seen < 64 do
                local ok, child = pcall(function() return parent.prevObj end)
                if ok and child ~= nil and child ~= parent
                    and put_back_child(parent, child, ux, uy, uz) then
                    given = given + 1
                end
                seen = seen + 1
                parent = obj_get_next_with_same_behavior_id ~= nil
                    and obj_get_next_with_same_behavior_id(parent) or nil
            end
        end
    end
    return given
end

local function parts(body, ux, uy, uz)
    local list = body.animPartsPos
    local count = MARIO_ANIM_PART_MAX
    if list == nil or type(count) ~= "number" then return 0 end
    local given = 0
    for index = 1, count do
        if undo(list[index], ux, uy, uz) then given = given + 1 end
    end
    return given
end

local function landing(index, m, body, ux, uy, uz)
    local holp = body.heldObjLastPosition
    if holp == nil or m.heldObj == nil then
        holpPut[index] = nil
        return false
    end
    local put = holpPut[index]
    if put ~= nil and put.x == holp.x and put.y == holp.y and put.z == holp.z then
        return false
    end
    if not undo(holp, ux, uy, uz) then return false end
    holpPut[index] = { x = holp.x, y = holp.y, z = holp.z }
    return true
end

function warp.land_readback()
    local on, fx, fy, fz = warp.picture_scaled()
    if not on then return 0 end
    local now = OF.util.optional("get_global_timer", nil)
    if type(now) ~= "number" then return 0 end
    if landDrawnAt ~= now then return 0 end
    if readAt == now then return 0 end
    readAt = now
    local ux, uy, uz = warp.reach_counter(fx, fy, fz)
    if ux == nil then return 0 end

    local given = warp.land_reach()
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[index]
        local body = m ~= nil and m.marioBodyState or nil
        if body ~= nil then
            if body.updateHeadPosTime == now and undo(body.headPos, ux, uy, uz) then
                given = given + 1
            end
            if body.updateTorsoTime == now then
                given = given + parts(body, ux, uy, uz)
                if landing(index, m, body, ux, uy, uz) then given = given + 1 end
            end
        end
    end
    return given + children(ux, uy, uz)
end

function warp.forget_readback()
    holpPut = {}
    readAt = nil
end
end

warp.ARENA_SLACK = 30

warp.ARENA_ASK = 30000
warp.ARENA_BOWSER_JUMP_BACK = 2

function warp.arena_deck(x, z)
    if find_floor == nil or id_bhvTiltingBowserLavaPlatform == nil then return nil end
    if type(x) ~= "number" or type(z) ~= "number" then return nil end
    local height, floor = find_floor(x, warp.ARENA_ASK, z)
    if floor == nil or type(height) ~= "number" then return nil end
    local ok, object = pcall(function() return floor.object end)
    if not ok or object == nil then return nil end
    if obj_has_behavior_id(object, id_bhvTiltingBowserLavaPlatform) == 0 then return nil end
    return height
end

function warp.arena_floor_frame()
    if gNetworkPlayers[0] == nil
        or gNetworkPlayers[0].currLevelNum ~= LEVEL_BOWSER_2 then return 0 end
    if not warp.picture_scaled() then return 0 end
    local given = 0
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil then
        local deck = warp.arena_deck(m.pos.x, m.pos.z)
        if deck ~= nil and m.pos.y < deck - warp.ARENA_SLACK then
            m.pos.y = deck
            if m.vel ~= nil and (m.vel.y or 0) < 0 then m.vel.y = 0 end
            given = given + 1
        end
    end
    local bowser = id_bhvBowser ~= nil and obj_get_first_with_behavior_id(id_bhvBowser) or nil
    if bowser ~= nil and bowser.oAction ~= warp.ARENA_BOWSER_JUMP_BACK then
        local deck = warp.arena_deck(bowser.oPosX, bowser.oPosZ)
        if deck ~= nil and bowser.oPosY < deck - warp.ARENA_SLACK then
            bowser.oPosY = deck
            if (bowser.oVelY or 0) < 0 then bowser.oVelY = 0 end
            given = given + 1
        end
    end
    return given
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

function warp.scale_name(axis)
    local _, x, y, z = warp.indices(true)
    local index = x
    if axis == "y" then index = y elseif axis == "z" then index = z end
    local step = stop_at(warp.SCALES, index, SCALE_NEUTRAL)
    return step ~= nil and step.name or "unchanged"
end

function warp.direction_name()
    local dir = warp.direction(true)
    if dir == nil then return OF.lang.t("down") end
    return dir.name
end

function warp.summary()
    local dir = warp.direction(true)
    local fx, fy, fz = warp.scale(true)
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

function warp.land_diag()
    local lines = {}
    local function add(label, value)
        lines[#lines + 1] = { label = label, value = value }
    end

    local size = landSize
    local shaped = warp.landShaped or 0

    if size == nil then
        add("level scaler", "no level carved yet")
    elseif size.refused then
        add("level scaler", "refused here - " .. tostring(size.why or "no reason recorded"))
    else
        add("level scaler", string.format("%s / %s / %s  (wide / tall / deep)",
            tostring(size.x), tostring(size.y), tostring(size.z)))
    end

    add("terrain", shaped .. " triangles shaped, "
        .. tostring(warp.landDropped or 0) .. " flattened, "
        .. tostring(warp.landRoofs or 0) .. " roofs out, "
        .. tostring(warp.landClamped or 0) .. " corners clamped, "
        .. tostring(warp.landRefused or 0) .. " refused")

    local acting = size ~= nil and not size.refused and shaped > 0
    local function verdict(done, word, idle)
        if not acting then return idle end
        return done and word or ("NOT " .. string.upper(word))
    end

    add("objects", verdict(warp.land_placed(), "carried", "nothing to carry")
        .. ", " .. verdict(warp.land_grown(), "sized", "nothing to size")
        .. "   " .. tostring(warp.landGrown or 0) .. " sized, "
        .. tostring(warp.landLate or 0) .. " arrived late")

    add("the arrival", verdict(warp.land_arrived(), "carried", "nothing to carry")
        .. ", " .. tostring(warp.landStood or 0) .. " stood on the floor, "
        .. tostring(warp.landNoFloor or 0) .. " refused for no floor, "
        .. tostring(warp.landArrivalsKept or 0) .. " already carried")

    local flown = warp.landFlights or 0
    local turned = warp.landFlightRefusals or 0
    local flight = flown .. " frames lengthened, " .. turned .. " turned down"
    if turned > 0 then
        flight = flight .. "   (" .. tostring(warp.landFlightWhy
            or "no reason recorded") .. ")"
    elseif flown == 0 then

        local watched = warp.landFlightSeen or 0
        if watched == 0 then
            flight = flight .. "   (the pass has not been reached in this"
                .. " course)"
        else
            flight = flight .. "   (reached on " .. watched
                .. " airborne steps here, none of them a launch)"
        end
    end
    add("the flight out", flight .. "   "
        .. tostring(warp.landFlightArrivals or 0) .. " launch arrivals")

    return lines
end

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType, stepArg)
    warp.step_frame(m, stepType, stepArg)

    warp.exit_frame(m, stepType)

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

function warp.reset_screen()
    if cameraHold == true then return false end
    warp.hold_camera(true)
    return true
end

do

function warp.camera_angle_stops()
    local n = 0
    for _, stop in ipairs(warp.SCALES) do
        if math_abs(stop.factor or 1.0) > 1.0 then n = n + 1 end
    end
    return n
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

function warp.camera_is_claimed()
    if OF.util.asks(OF.camera, "mode_live") and OF.camera.mode_live() then
        return true
    end
    if OF.util.asks(OF.spectate, "mode_live") and OF.spectate.mode_live() then
        return true
    end
    if OF.util.asks(OF.modifiers, "camera_is_held")
        and OF.modifiers.camera_is_held() then
        return true
    end
    return false
end

local function camera_clear_rise(foc, x, wantY, z)

    local CAM_CLEAR = 0.9
    if foc == nil then return wantY end
    local dx, dy, dz = x - foc.x, wantY - foc.y, z - foc.z
    if dx == 0 and dy == 0 and dz == 0 then return wantY end
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        foc.x, foc.y, foc.z, dx, dy, dz)
    if hit == nil or hit.surface == nil then return wantY end
    local at = hit.hitPos
    if at == nil or type(at.y) ~= "number" then return wantY end
    return foc.y + (at.y - foc.y) * CAM_CLEAR
end

local function camera_angle_frame(reach)

    if not (reach >= 1.0) then reach = 1.0 end
    local eye = gLakituState.pos
    local foc = gLakituState.focus
    local rise = eye.y - foc.y
    local want = foc.y + rise / reach
    want = camera_clear_rise(foc, eye.x, want, eye.z)
    local step = want - eye.y

    if math_abs(step) < 1.0 then return false end
    eye.y = eye.y + step
    if gLakituState.curPos ~= nil then
        gLakituState.curPos.y = gLakituState.curPos.y + step
    end
    return true
end

function warp.camera_frame()

    if gLakituState == nil or gLakituState.pos == nil then return false end
    if gLakituState.focus == nil then return false end

    if not camera_follows_at_a_rate() then return false end

    local shaped, _, fy = warp.picture_scaled()
    if not shaped or type(fy) ~= "number" then return false end
    local tall = math_abs(fy)

    local mirrored = (fy < 0)
    if not (tall > 1.0 or mirrored) then return false end
    local reach = tall
    if reach < 1.0 then reach = 1.0 end

    if warp.camera_is_claimed() then return false end

    local moved = camera_angle_frame(reach)

    if not cameraHold then return moved end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return moved end

    local gap = gLakituState.pos.y - m.pos.y
    local most = CAM_GAP * reach
    local over = 0
    if gap > most then over = most - gap
    elseif gap < -most then over = -most - gap

    else return moved end

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

end

do

local CAMERA_FLOORS = {
    [COURSE_WF]    = { any = 8 },
    [COURSE_CCM]   = { any = -5068, [2] = -5856 },
    [COURSE_PSS]   = { any = -4600 },
    [COURSE_BITDW] = { any = -3416 },
    [COURSE_TTM]   = { [1] = -6000 },
    [COURSE_RR]    = { any = -4790 },
    [COURSE_BITS]  = { any = -5065 },
}

function warp.camera_floor_of(course, area)
    local row = CAMERA_FLOORS[course]
    if row == nil then return nil end
    local exact = row[area]
    if type(exact) == "number" then return exact end
    return row.any
end

function warp.camera_floor_courses()
    local n = 0
    for _ in pairs(CAMERA_FLOORS) do n = n + 1 end
    return n
end

function warp.camera_floor_scaled(minY, fy)
    if type(minY) ~= "number" or type(fy) ~= "number" then return nil end
    if fy == 0 then return nil end
    return minY * fy, (fy < 0)
end

function warp.camera_floor_needs_lever(minY, fy)
    local bound, upper = warp.camera_floor_scaled(minY, fy)
    if bound == nil then return false end

    if upper then return true end
    return bound < minY
end

function warp.camera_floor_stops()
    local n = 0
    for _, stop in ipairs(warp.SCALES) do
        local factor = stop.factor or 1.0
        local hit = false
        for _, row in pairs(CAMERA_FLOORS) do
            for _, minY in pairs(row) do
                local bound = warp.camera_floor_scaled(minY, factor)
                if bound ~= nil and bound ~= minY then hit = true end
            end
        end
        if hit then n = n + 1 end
    end
    return n
end

local floorHeld = nil

local floorOwned = false

function warp.camera_floor_release()
    if floorHeld == nil then return false end
    floorHeld = nil
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local levelNum = me ~= nil and me.currLevelNum or 0

    local vanilla = OF.util.optional("level_is_vanilla_level", true, levelNum)
    OF.util.optional("camera_set_use_course_specific_settings", nil,
        vanilla ~= false and 1 or 0)
    return true
end

function warp.camera_floor_held()
    return floorHeld ~= nil
end

function warp.camera_floor_owns_flag()
    return floorOwned == true
end

function warp.camera_floor_init()
    if not floorOwned then return false end
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local levelNum = me ~= nil and me.currLevelNum or 0

    local vanilla = OF.util.optional("level_is_vanilla_level", true, levelNum)

    OF.util.optional("camera_set_use_course_specific_settings", nil,
        vanilla ~= false and 1 or 0)
    return true
end

local function refuse()
    warp.camera_floor_release()
    return false
end

function warp.camera_floor_frame()

    if OF.util.optional("camera_config_is_free_cam_enabled", false) ~= true then
        return refuse()
    end
    if gFirstPersonCamera ~= nil and gFirstPersonCamera.enabled == true then
        return refuse()
    end
    if warp.camera_is_claimed() then return refuse() end
    if gLakituState == nil or gLakituState.pos == nil then
        return refuse()
    end
    if CAMERA_MODE_NEWCAM == nil then return refuse() end
    if gLakituState.mode ~= CAMERA_MODE_NEWCAM then return refuse() end

    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil then return refuse() end

    local shaped, _, fy = warp.picture_scaled()
    if not shaped or type(fy) ~= "number" then
        return refuse()
    end

    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil then return refuse() end

    if OF.util.optional("level_is_vanilla_level", false, me.currLevelNum) ~= true then
        return refuse()
    end

    local minY = warp.camera_floor_of(me.currCourseNum, me.currAreaIndex)
    if minY == nil then return refuse() end

    local bound, upper = warp.camera_floor_scaled(minY, fy)
    if bound == nil then return refuse() end

    local eye = gLakituState.pos

    local where = tostring(me.currLevelNum) .. ":" .. tostring(me.currAreaIndex)

    local pinned = (eye.y <= minY + 1.0) and (m.pos.y < minY)

    if pinned and warp.camera_floor_needs_lever(minY, fy) then

        if floorHeld ~= nil and floorHeld ~= where then
            warp.camera_floor_release()
        end
        if floorHeld ~= where then
            floorHeld = where

            floorOwned = true

            OF.util.optional("camera_set_use_course_specific_settings", nil, 0)
        end
    else
        warp.camera_floor_release()
    end

    local want = eye.y
    if upper then
        if want > bound then want = bound end
    else
        if want < bound then want = bound end
    end

    local step = want - eye.y

    if math_abs(step) < 1.0 then return false end
    eye.y = want
    if gLakituState.curPos ~= nil then
        gLakituState.curPos.y = gLakituState.curPos.y + step
    end
    return true
end
end

hook_event(HOOK_UPDATE, function()
    warp.uncull_frame()

    warp.far_frame()
    warp.land_watch()

    warp.land_area_watch()

    warp.arena_floor_frame()

    warp.land_object_frame()

    warp.settle_shape()

    warp.camera_frame()

    warp.camera_floor_frame()
end)

do
local bakedSeen, bakedBase = 0, false
function warp.baked_surface(dynamic)
    if dynamic then return false end
    if bakedBase == false then
        bakedBase = nil
        if OF.util.asks(OF.venues, "level_baked") then
            bakedBase = OF.venues.level_baked(landLevelNext, warp.landAreaNext or 1)
        end
    end
    if bakedBase == nil then return false end
    bakedSeen = bakedSeen + 1
    return bakedSeen > bakedBase
end

function warp.baked_surface_forget()
    bakedSeen, bakedBase = 0, false
end
end

hook_event(HOOK_ON_CLEAR_AREAS, warp.baked_surface_forget)

hook_event(HOOK_ON_ADD_SURFACE, function(surface, dynamic)

    if dynamic then return end
    if warp.baked_surface(false) then return end
    warp.shape_surface(surface, false)

    if not dynamic then
        warp.apply_limits()

        warp.apply_stars()

        warp.apply_bully()
    end
end)

hook_event(HOOK_ON_FIND_WATER_LEVEL, function(x, z)
    return warp.land_water(x, z)
end)

hook_event(HOOK_ON_FIND_POISON_GAS_LEVEL, function(x, z)
    return warp.land_gas(x, z)
end)

hook_event(HOOK_ON_GEO_PROCESS_CHILDREN, function(node, matStackIndex)
    warp.landscape_frame(node, matStackIndex)
end)

hook_event(HOOK_ON_GEO_PROCESS, function(node)
    if node == nil then return end

    if warp.land_inner_after(node) then return end

    if warp.land_move_out(node) then return end
    if node.type ~= LAND_CAMERA then return end
    warp.land_readback()
end)

hook_event(HOOK_BEFORE_GEO_PROCESS, function(node)
    warp.land_inner_before(node)
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
    warp.door_arrival_frame(m)
    warp.door_spawn_watch(m)
    warp.door_pass_frame(m)
    warp.door_flag_frame(m)
    warp.life_frame(m)
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if warp.door_pass_allow(m, obj, interactType) == false then return false end
    if warp.door_flag_allow(m, obj, interactType) == false then return false end
end)

hook_event(HOOK_BEFORE_WARP, function(destLevel, destArea, destWarpNode)
    warp.land_warp_seen(destLevel, destWarpNode, destArea)
end)

hook_event(HOOK_ON_WARP, function(warpType)

    warp.life_begin()

    warp.land_arrive(warpType)

    warp.arm_door_arrival()

    warp.forget_door_pass()
    warp.credits_voices(nil)

    warp.camera_floor_release()
end)

hook_event(HOOK_ON_OBJECT_LOAD, function(object)
    warp.land_watch_object(object)
end)

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    return warp.stand_floor_class(m, floorClass)
end)

hook_event(HOOK_ON_LEVEL_INIT, function(warpType, levelNum)
    forget_level()

    warp.credits_voices(levelNum)

    warp.forget_refusal()

    warp.camera_floor_release()

    warp.camera_floor_init()

    warp.land_place()

    warp.apply_warps()

    warp.land_stand()

    warp.forget_tilt()

    warp.forget_bodies()
end)

hook_event(HOOK_ON_CLEAR_AREAS, function()

    warp.forget_land()

    warp.forget_bars()

    warp.forget_island()

    warp.apply_limits()

    warp.apply_stars()

    warp.apply_bully()
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
    local _, x, y, z = warp.indices(true)

    table.insert(rows, panel.label_row(warp.summary()))

    table.insert(rows, panel.header_row(OF.lang.t("Level scale")))

    local pending = warp.land_pending()

    local reloadG = pending and 215 or 255
    local reloadB = pending and 0 or 255

    table.insert(rows, panel.with_help(panel.gated_row("warp_lobby",
        pending and OF.lang.t("Reload this map to take the new size")
            or OF.lang.t("Reload this map"),
        255, reloadG, reloadB,
        function()
            OF.util.report(OF.net.reload_level())
        end), OF.lang.t("loads this level again for everybody - a new size takes then and not before")))

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
                "a quarter to four times over - width and depth are never mirrored and never flattened, and a tree faces you, so it takes the width across your view when these two differ"
        end
        table.insert(rows, ladder_row(panel, "vision", axis.label, help,
            warp.scale_name(axis.field), axis.index - offset, list,
            function(stop) return warp.set(axis.field, stop + offset) end))
    end

    table.insert(rows, panel.with_help(
        panel.row(panel.tick(warp.camera_holds(),
            OF.lang.t("The size may steady your camera")),
            255, 255, 255, function() warp.hold_camera() end),
        "in a tall course the game's camera cannot follow a fall at its own rate - untick and the fall is left to it, while the drawn angle is put back either way"))

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
            title = "Level scale", tab = "room", up = "room",
            build = function() return warp.build_page(panel) end,
        }
    end
end)

warp.RIPPLING_POOLS = {
    { field = "hmc_painting", level = "LEVEL_CASTLE", area = 3 },
    { field = "cotmc_painting", level = "LEVEL_HMC", area = 1 },
}
warp.PAINTING_IDLE, warp.PAINTING_RIPPLE = 0, 1
warp.RIPPLE_CONTINUOUS = 20

function warp.keep_pools_rippling()
    local values = gPaintingValues
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if values == nil or np == nil then return 0 end
    local started = 0
    for _, row in ipairs(warp.RIPPLING_POOLS) do
        local p = values[row.field]
        if p ~= nil and _G[row.level] == np.currLevelNum and row.area == np.currAreaIndex
            and p.state == warp.PAINTING_IDLE and p.rippleTrigger == warp.RIPPLE_CONTINUOUS then
            p.currRippleMag = p.passiveRippleMag
            p.rippleDecay = p.passiveRippleDecay
            p.currRippleRate = p.passiveRippleRate
            p.dispersionFactor = p.passiveDispersionFactor
            p.rippleTimer = 0
            p.state = warp.PAINTING_RIPPLE
            started = started + 1
        end
    end
    return started
end
hook_event(HOOK_UPDATE, function() warp.keep_pools_rippling() end)

function warp.loaded()
    return true
end
