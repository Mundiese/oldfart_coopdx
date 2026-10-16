OF = OF or {}
OF.camera = OF.camera or {}

local cam = OF.camera

local ENGINE_POS_H = 0.3
local ENGINE_POS_V = 0.3
local ENGINE_FOC_H = 0.8
local ENGINE_FOC_V = 0.3

local LOOK_AHEAD = 1000

local LOOK_SPEED = 0x0300
local ROLL_SPEED = 0x00C0

local MOUSE_LOOK_SENSITIVITY = 40

local PITCH_LIMIT = 0x3600

local SNAP = 400

function cam.snap_distance()
    return SNAP
end

local LENS = {
    { name = "wide", degrees = 80, func = "CAM_FOV_APP_80" },
    { name = "open", degrees = 60, func = "CAM_FOV_APP_60" },
    { name = "normal", degrees = 45, func = "CAM_FOV_APP_45" },
    { name = "tight", degrees = 30, func = "CAM_FOV_APP_30" },
    { name = "long", degrees = 20, func = "CAM_FOV_APP_20" },
}

local LENS_DEFAULT = 3

cam.on = false

cam.eye = nil

cam.look = { yaw = 0, pitch = 0 }
cam.roll = 0
cam.lens = LENS_DEFAULT
cam.bars = true
cam.freeze = false

cam.mouseLook = false

cam.where = nil

cam.watching = nil

local held = { hud = nil, frozen = false, mouse = false }
local holding = false

local function fold_s16(value)
    value = math.floor(value or 0) % 0x10000
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

local function along(x, y, z, dist, pitch, yaw)
    return x + dist * coss(pitch) * sins(yaw),
           y + dist * sins(pitch),
           z + dist * coss(pitch) * coss(yaw)
end

local function put(vec, x, y, z)
    if vec == nil then return end
    vec.x, vec.y, vec.z = x, y, z
end

local function constant(name)
    local value = _G[name]
    if type(value) ~= "number" then return nil end
    return value
end

function cam.lens_step(index)
    return LENS[index] or LENS[LENS_DEFAULT]
end

function cam.pace_name()
    return OF.util.fly_pace_name()
end

local function room_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    return tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex)
end

local function here()
    return room_of(0)
end

local SUBJECT_LIFT = 120

local function subject_pos(localIndex)
    if localIndex == nil then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return nil end
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end
    return m.pos.x, m.pos.y + SUBJECT_LIFT, m.pos.z, m
end

local function bearing(ex, ey, ez, tx, ty, tz, fallbackYaw)
    local dx, dy, dz = tx - ex, ty - ey, tz - ez
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat < 1 and math.abs(dy) < 1 then return nil end
    local yaw = (flat >= 1) and fold_s16(atan2s(dz, dx)) or fold_s16(fallbackYaw or 0)
    return yaw, OF.util.clamp(fold_s16(atan2s(flat, dy)), -PITCH_LIMIT, PITCH_LIMIT)
end

local function in_first_person()
    return OF.util.optional("get_first_person_enabled", false) == true
end

function cam.active()
    if not cam.on then return false end
    if cam.eye == nil then return false end

    if gLakituState == nil then return false end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false
    end

    local m = gMarioStates[0]
    if m == nil then return false end

    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        return false
    end

    if OF.util.optional("is_transition_playing", false) then return false end

    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        return false
    end

    if in_first_person() then return false end

    if cam.where ~= nil and here() ~= cam.where then return false end

    return true
end

function cam.is_photographing(localIndex)
    local s = gPlayerSyncTable[localIndex]
    return s ~= nil and s.ofPhoto == true
end

local function hold_hud()
    if OF.util.binding("hud_hide") == nil then return end
    if held.hud == nil then

        held.hud = OF.util.optional("hud_is_hidden", false) == true
            and not (OF.util.asks(OF.modifiers, "is_on")
                and OF.modifiers.is_on("hud"))
            and not (OF.util.asks(OF.pause, "holds_hud") and OF.pause.holds_hud())
    end
    OF.util.optional("hud_hide", nil)
end

local function release_hud()
    if held.hud == nil then return end
    local wanted = held.hud
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("hud") then
        wanted = true
    end
    if OF.util.asks(OF.pause, "holds_hud") and OF.pause.holds_hud() then wanted = true end
    held.hud = nil
    if wanted then
        OF.util.optional("hud_hide", nil)
    else
        OF.util.optional("hud_show", nil)
    end
end

function cam.holds_hud()
    return held.hud ~= nil
end

local function exempt_everybody()
    local bit = constant("ACTIVE_FLAG_INITIATED_TIME_STOP")
    if bit == nil then return 0 end
    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        local obj = m ~= nil and m.marioObj or nil
        if obj ~= nil then
            obj.activeFlags = (obj.activeFlags or 0) | bit
            count = count + 1
        end
    end
    return count
end

local function unexempt_everybody()
    local bit = constant("ACTIVE_FLAG_INITIATED_TIME_STOP")
    if bit == nil then return end
    for index = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[index]
        local obj = m ~= nil and m.marioObj or nil
        if obj ~= nil then
            obj.activeFlags = (obj.activeFlags or 0) & ~bit
        end
    end
end

local function hold_freeze()
    local bit = constant("TIME_STOP_ENABLED")
    if bit == nil then return false end
    if OF.util.binding("set_time_stop_flags") == nil then return false end

    if not held.frozen then

        local already = OF.util.optional("get_time_stop_flags", 0)
        if type(already) == "number" and (already & bit) ~= 0 then return false end

        if exempt_everybody() == 0 then return false end
        OF.util.optional("set_time_stop_flags", nil, bit)
        held.frozen = true
        return true
    end

    exempt_everybody()
    return true
end

local function release_freeze()
    if not held.frozen then return end
    held.frozen = false
    local bit = constant("TIME_STOP_ENABLED")
    if bit ~= nil then OF.util.optional("clear_time_stop_flags", nil, bit) end

    unexempt_everybody()
end

local MOUSE_HOLD = "hudMouseLock"
local function hold_mouse_look()
    if not cam.mouseLook or held.mouse then return end
    held.mouse = OF.util.lend_setting(MOUSE_HOLD, "camera",
        "djui_hud_is_mouse_locked", "djui_hud_set_mouse_locked", true)
end

local function release_mouse()
    if not held.mouse then return end
    held.mouse = false
    OF.util.return_setting(MOUSE_HOLD, "camera")
end

local function drive(px, py, pz, fx, fy, fz)
    local s = gLakituState

    local dx, dy, dz = px - s.pos.x, py - s.pos.y, pz - s.pos.z
    local jumped = (dx * dx + dy * dy + dz * dz) > SNAP * SNAP

    put(s.pos, px, py, pz)
    put(s.curPos, px, py, pz)
    put(s.goalPos, px, py, pz)
    put(s.focus, fx, fy, fz)
    put(s.curFocus, fx, fy, fz)
    put(s.goalFocus, fx, fy, fz)

    s.posHSpeed, s.posVSpeed = 0, 0
    s.focHSpeed, s.focVSpeed = 0, 0

    s.yaw = fold_s16(cam.look.yaw + 0x8000)

    s.roll = fold_s16((s.roll or 0) + cam.roll)
    holding = true

    local step = cam.lens_step(cam.lens)
    local func = constant(step.func)
    if func ~= nil then OF.util.optional("set_fov_function", nil, func) end

    if jumped then OF.util.optional("skip_camera_interpolation", nil) end
end

local function release()
    if not holding then return false end
    holding = false
    if gLakituState == nil then return false end
    gLakituState.posHSpeed = ENGINE_POS_H
    gLakituState.posVSpeed = ENGINE_POS_V
    gLakituState.focHSpeed = ENGINE_FOC_H
    gLakituState.focVSpeed = ENGINE_FOC_V
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end

function cam.driving()
    return holding
end

local function handback()
    local was = release()
    release_hud()
    release_freeze()
    release_mouse()
    return was
end

cam.handback = handback

local function seed_look()
    local s = gLakituState
    if s == nil then return end

    local view = s.oldYaw
    if view == nil then view = (s.yaw or 0) + 0x8000 end
    cam.look.yaw = fold_s16(view)
    cam.look.pitch = OF.util.clamp(fold_s16(s.oldPitch or 0),
        -PITCH_LIMIT, PITCH_LIMIT)
end

function cam.start()

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "a round or a run owns where everybody is standing"
    end
    if cam.on then return true end

    local m = gMarioStates[0]
    if m == nil then return false, "There is no camera to take yet." end
    if gLakituState == nil or gLakituState.pos == nil then
        return false, "There is no camera to take yet."
    end

    if in_first_person() then
        return false, "You are looking out of your own eyes. Turn that off first."
    end

    local mayHave, why = OF.util.enter_mode("photo")
    if not mayHave then return false, why end

    cam.on = true
    cam.roll = 0
    cam.where = here()

    cam.eye = {
        x = gLakituState.pos.x,
        y = gLakituState.pos.y,
        z = gLakituState.pos.z,
    }
    seed_look()

    OF.util.publish_row(0, "ofPhoto", true)
    return true
end

function cam.stop()
    if not cam.on then return false end
    cam.on = false

    OF.util.publish_row(0, "ofPhoto", false)
    cam.watching = nil
    OF.util.leave_mode("photo")
    cam.eye = nil
    cam.where = nil
    cam.roll = 0
    cam.playFrame = nil
    handback()

    local m = gMarioStates[0]
    local area = m ~= nil and m.area or nil
    if area ~= nil and area.camera ~= nil then
        OF.util.optional("soft_reset_camera", nil, area.camera)
    end
    return true
end

function cam.toggle()
    if cam.on then
        cam.stop()
        return true
    end
    return cam.start()
end

local suspendedShot = nil

function cam.mode_live()
    return cam.on == true
end

function cam.mode_suspend()
    if not cam.on then return false end
    suspendedShot = {
        eye = { x = cam.eye.x, y = cam.eye.y, z = cam.eye.z },
        yaw = cam.look.yaw,
        pitch = cam.look.pitch,
        roll = cam.roll,
        lens = cam.lens,
        where = cam.where,

        watching = cam.watching,
    }
    cam.stop()
    return true
end

function cam.mode_resume()
    if cam.on then return true end
    local shot = suspendedShot
    suspendedShot = nil
    if not cam.start() then return false end

    if shot ~= nil and shot.where == cam.where then
        cam.eye.x, cam.eye.y, cam.eye.z = shot.eye.x, shot.eye.y, shot.eye.z
        cam.look.yaw, cam.look.pitch = shot.yaw, shot.pitch
        cam.roll = shot.roll
        cam.lens = shot.lens

        if shot.watching ~= nil and room_of(shot.watching) == cam.where then
            cam.watching = shot.watching
        end
    end
    return true
end

local stickX, stickY = 0, 0
local rightX, rightY = 0, 0

local function fly_step()
    local pos = cam.eye
    if pos == nil then return end

    local yaw = cam.look.yaw

    local down = OF.util.menu_has_screen() and 0 or (OF.input.down or 0)
    local mag, raw = OF.util.fly_mag(stickX, stickY)
    local speed = OF.util.fly_speed(down) * mag

    if mag > 0.05 then
        local ux = stickX / raw
        local uy = stickY / raw
        pos.x = pos.x + (uy * sins(yaw) - ux * coss(yaw)) * speed
        pos.z = pos.z + (uy * coss(yaw) + ux * sins(yaw)) * speed
    end

    pos.y = pos.y + OF.util.fly_lift(down)
end

function cam.turn(dyaw, dpitch)
    cam.look.yaw = fold_s16(cam.look.yaw + (dyaw or 0))
    cam.look.pitch = OF.util.clamp(fold_s16(cam.look.pitch + (dpitch or 0)),
        -PITCH_LIMIT, PITCH_LIMIT)
    return true
end

local ROLL_LIMIT = 0x4000

function cam.tilt(droll)
    cam.roll = OF.util.clamp(fold_s16(cam.roll + (droll or 0)),
        -ROLL_LIMIT, ROLL_LIMIT)
    return true
end

function cam.level_horizon()
    cam.roll = 0
    return true
end

function cam.watch(localIndex)
    if localIndex == nil then
        cam.watching = nil
        return true
    end
    if subject_pos(localIndex) == nil then
        return false, "They are not in the lobby."
    end
    cam.watching = localIndex
    return true
end

function cam.step_watch(delta)
    local order = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        table.insert(order, entry.localIndex)
    end

    local count = #order + 1
    local at = count
    for index, who in ipairs(order) do
        if who == cam.watching then at = index end
    end

    return cam.watch(order[((at - 1 + (delta or 1)) % count) + 1])
end

function cam.watch_name()
    if cam.watching == nil then return nil end
    local np = gNetworkPlayers[cam.watching]
    if np == nil or not np.connected then return nil end
    return OF.util.short_name(np.name or "", 14)
end

local function aim_step()
    if cam.watching == nil then return false end
    if cam.eye == nil then return false end

    local tx, ty, tz = subject_pos(cam.watching)
    if tx == nil or room_of(cam.watching) ~= cam.where then
        cam.watching = nil
        return false
    end

    local eye = cam.eye
    local yaw, pitch = bearing(eye.x, eye.y, eye.z, tx, ty, tz, cam.look.yaw)
    if yaw == nil then return false end
    cam.look.yaw, cam.look.pitch = yaw, pitch
    return true
end

local SHOTS = {
    { key = "shoulder", name = "Over the shoulder",
      turn = 0x8900, back = 230, lift = 150, look = 130, lens = 3,
      help = "behind them and a little to one side, looking past their head" },
    { key = "low", name = "Low, looking up",
      turn = 0, back = 280, lift = -30, look = 200, lens = 2,
      help = "on the floor in front of them, looking up - nothing checks the "
          .. "wall behind it" },
    { key = "wide", name = "The establishing shot",
      turn = 0xA000, back = 1600, lift = 900, look = 120, lens = 1,
      help = "far back and high, with as much of the level in frame as fits" },
}

function cam.shot_count()
    return #SHOTS
end

function cam.shot(index)
    return SHOTS[index]
end

function cam.frame_shot(index)
    local shot = SHOTS[index]
    if shot == nil then return false end
    if not cam.on or cam.eye == nil then
        return false, "Start the camera first."
    end

    if cam.playing() then
        return false, "The move is flying the camera."
    end

    local tx, ty, tz, m = subject_pos(cam.watching or 0)
    if tx == nil then return false, "There is nobody to frame." end

    local feet = ty - SUBJECT_LIFT
    local facing = (m.faceAngle ~= nil and m.faceAngle.y) or 0

    local ex, ey, ez = along(tx, feet + shot.lift, tz,
        shot.back, 0, fold_s16(facing + shot.turn))

    local yaw, pitch = bearing(ex, ey, ez, tx, feet + shot.look, tz,
        cam.look.yaw)
    cam.eye.x, cam.eye.y, cam.eye.z = ex, ey, ez
    if yaw ~= nil then
        cam.look.yaw, cam.look.pitch = yaw, pitch
    end
    cam.lens = shot.lens
    return true
end

local function look_mouse()
    if not cam.mouseLook or not held.mouse then return end
    local mx = OF.util.optional("djui_hud_get_raw_mouse_x", 0) or 0
    local my = OF.util.optional("djui_hud_get_raw_mouse_y", 0) or 0
    if mx == 0 and my == 0 then return end
    cam.turn(-mx * MOUSE_LOOK_SENSITIVITY, -my * MOUSE_LOOK_SENSITIVITY)
end

local function look_step(m)
    look_mouse()

    local dead = OF.input.DEVICE_DEAD or 30
    if not OF.input.arrows_are_keys(m) then
        if math.abs(rightX) > dead or math.abs(rightY) > dead then

            cam.turn(-(rightX / 64) * LOOK_SPEED, (rightY / 64) * LOOK_SPEED)
            return
        end
    end

    local dyaw, dpitch = 0, 0
    if OF.input.held(L_CBUTTONS) then dyaw = dyaw - LOOK_SPEED end
    if OF.input.held(R_CBUTTONS) then dyaw = dyaw + LOOK_SPEED end
    if OF.input.held(U_CBUTTONS) then dpitch = dpitch + LOOK_SPEED end
    if OF.input.held(D_CBUTTONS) then dpitch = dpitch - LOOK_SPEED end
    if dyaw ~= 0 or dpitch ~= 0 then cam.turn(dyaw, dpitch) end

    if OF.input.held(Z_TRIG) then
        if OF.input.held(R_TRIG) then cam.tilt(ROLL_SPEED) end
        if OF.input.held(L_TRIG) then cam.tilt(-ROLL_SPEED) end
    end
end

local function walk(index, delta, count)
    return ((index - 1 + (delta or 1)) % count) + 1
end

function cam.step_pace(delta)
    return OF.util.step_fly_pace(delta)
end

function cam.step_lens(delta)
    cam.lens = walk(cam.lens, delta, #LENS)
    return true
end

function cam.toggle_bars()
    cam.bars = not cam.bars
    return true
end

function cam.toggle_freeze()
    cam.freeze = not cam.freeze
    return true
end

function cam.toggle_mouse_look()
    cam.mouseLook = not cam.mouseLook
    if not cam.mouseLook then release_mouse() end
    return true
end

cam.marks = cam.marks or {}

local TRAVEL_STEPS = { 30, 60, 120, 240 }
cam.travel = 2

local MARKS_PER_KEY = 20
local KEYS_PER_PATH = 4
cam.MAX_MARKS = MARKS_PER_KEY * KEYS_PER_PATH

function cam.mark()
    if not cam.on or cam.eye == nil then
        return false, "Start the camera first."
    end
    if #cam.marks >= cam.MAX_MARKS then
        return false, "That is as many points as one move can hold."
    end
    table.insert(cam.marks, {
        x = cam.eye.x, y = cam.eye.y, z = cam.eye.z,
        yaw = fold_s16(cam.look.yaw),
        pitch = fold_s16(cam.look.pitch),
        roll = fold_s16(cam.roll),
        lens = cam.lens,
        travel = TRAVEL_STEPS[cam.travel] or TRAVEL_STEPS[2],
    })
    return true
end

function cam.drop_last()
    if #cam.marks == 0 then return false, "There are no points to remove." end
    table.remove(cam.marks)
    return true
end

function cam.clear_marks()
    cam.marks = {}
    cam.playFrame = nil

    cam.cutOrder = nil
    cam.cutShowing = nil
    return true
end

function cam.step_travel(delta)
    cam.travel = walk(cam.travel, delta, #TRAVEL_STEPS)
    return true
end

function cam.travel_frames()
    return TRAVEL_STEPS[cam.travel] or TRAVEL_STEPS[2]
end

function cam.path_length(marks)
    marks = marks or cam.marks
    local total = 0
    for index = 2, #marks do
        total = total + (marks[index].travel or TRAVEL_STEPS[2])
    end
    return total
end

local PLAY_STOPS = {
    { key = "glide", name = "it glides",
      help = "the camera flies from point to point along a curve" },
    { key = "cut", name = "it cuts",
      help = "the camera stands at each point for its time, then jumps" },
    { key = "round", name = "it cuts, for ever",
      help = "the same cut, and after the last point it begins again" },
    { key = "shuffle", name = "it cuts, for ever, shuffled",
      help = "the same round, in a new order every time it comes back" },
}

cam.playStyle = 1

cam.cutOrder = nil
cam.cutShowing = nil

function cam.play_stop_count()
    return #PLAY_STOPS
end

function cam.play_stop(index)
    return PLAY_STOPS[index] or PLAY_STOPS[1]
end

function cam.step_play_style(delta)
    cam.playStyle = walk(cam.playStyle, delta, #PLAY_STOPS)
    return true
end

function cam.cuts()
    return cam.play_stop(cam.playStyle).key ~= "glide"
end

function cam.plays_for_ever()
    local key = cam.play_stop(cam.playStyle).key
    return key == "round" or key == "shuffle"
end

function cam.cut_length(marks)
    marks = marks or cam.marks
    local total = 0
    for index = 1, #marks do
        total = total + (marks[index].travel or TRAVEL_STEPS[2])
    end
    return total
end

function cam.play_length(marks)
    if cam.cuts() then return cam.cut_length(marks) end
    return cam.path_length(marks)
end

function cam.cut_at(marks, frame, order)
    marks = marks or cam.marks
    if #marks == 0 then return nil end
    local total = 0
    for seat = 1, #marks do
        local index = (order ~= nil and order[seat]) or seat
        local mark = marks[index]
        if mark == nil then return nil end
        total = total + (mark.travel or TRAVEL_STEPS[2])
        if frame < total then return index end
    end
    return nil
end

local function deal_order(marks, lastShown)
    local order = {}
    for index = 1, #marks do order[index] = index end
    if cam.play_stop(cam.playStyle).key ~= "shuffle" then return order end
    for index = #order, 2, -1 do
        local pick = OF.util.random_int(1, index)
        order[index], order[pick] = order[pick], order[index]
    end
    if lastShown ~= nil and #order > 1 and order[1] == lastShown then
        order[1], order[#order] = order[#order], order[1]
    end
    return order
end

local function cut_step()
    local index = cam.cut_at(cam.marks, cam.playFrame, cam.cutOrder)
    if index == nil then
        if not cam.plays_for_ever() then
            cam.playFrame = nil
            return false
        end
        cam.cutOrder = deal_order(cam.marks, cam.cutShowing)
        cam.playFrame = 0
        index = cam.cut_at(cam.marks, 0, cam.cutOrder)

        if index == nil then
            cam.playFrame = nil
            return false
        end
    end
    local mark = cam.marks[index]
    cam.cutShowing = index
    cam.eye.x, cam.eye.y, cam.eye.z = mark.x, mark.y, mark.z
    cam.look.yaw = mark.yaw
    cam.look.pitch = OF.util.clamp(mark.pitch, -PITCH_LIMIT, PITCH_LIMIT)
    cam.roll = mark.roll or 0
    cam.lens = mark.lens or LENS_DEFAULT
    cam.playFrame = cam.playFrame + 1
    return true
end

local function spline(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * ((2 * p1)
        + (-p0 + p2) * t
        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
        + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function turn_toward(from, to, t)
    return fold_s16(from + fold_s16(to - from) * t)
end

function cam.path_at(marks, frame)
    marks = marks or cam.marks
    local count = #marks
    if count == 0 then return nil end
    if count == 1 then
        local only = marks[1]
        return only.x, only.y, only.z, only.yaw, only.pitch, only.roll, only.lens
    end

    local total = cam.path_length(marks)
    if total <= 0 then return nil end
    if frame == nil or frame < 0 then return nil end
    if frame > total then return nil end

    local u = frame / total
    local eased = (u * u * (3 - 2 * u)) * total

    local index = 1
    local walked = 0
    while index < count - 1 do
        local leg = marks[index + 1].travel or TRAVEL_STEPS[2]
        if walked + leg >= eased then break end
        walked = walked + leg
        index = index + 1
    end

    local a = marks[index]
    local b = marks[index + 1]
    local leg = b.travel or TRAVEL_STEPS[2]
    local t = leg > 0 and OF.util.clamp((eased - walked) / leg, 0, 1) or 1

    local before = marks[index - 1] or a
    local after = marks[index + 2] or b

    return spline(before.x, a.x, b.x, after.x, t),
        spline(before.y, a.y, b.y, after.y, t),
        spline(before.z, a.z, b.z, after.z, t),
        turn_toward(a.yaw, b.yaw, t),
        turn_toward(a.pitch, b.pitch, t),
        turn_toward(a.roll, b.roll, t),
        (t < 0.5) and a.lens or b.lens
end

cam.playFrame = nil

function cam.playing()
    return cam.playFrame ~= nil
end

function cam.play()
    if #cam.marks < 2 then
        return false, "A move needs at least two points."
    end
    if not cam.on then
        local ok, why = cam.start()
        if not ok then return false, why end
    end
    cam.cutShowing = nil
    cam.cutOrder = deal_order(cam.marks, nil)
    cam.playFrame = 0
    return true
end

function cam.stop_playing()
    if cam.playFrame == nil then return false end
    cam.playFrame = nil
    return true
end

local function play_step()
    if cam.playFrame == nil then return false end

    if cam.cuts() then return cut_step() end
    local px, py, pz, yaw, pitch, roll, lens = cam.path_at(cam.marks, cam.playFrame)
    if px == nil then
        cam.playFrame = nil
        return false
    end
    cam.eye.x, cam.eye.y, cam.eye.z = px, py, pz
    cam.look.yaw = yaw
    cam.look.pitch = OF.util.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
    cam.roll = roll
    cam.lens = lens
    cam.playFrame = cam.playFrame + 1
    return true
end

cam.SLOTS = 3

local HEAD_PREFIX = "ofcamh_"
local BODY_PREFIX = "ofcamb_"
local FIELD = ","
local MARK = ";"
local function head_key(slot)
    return HEAD_PREFIX .. tostring(slot)
end

local function body_key(slot, chunk)
    return BODY_PREFIX .. tostring(slot) .. "_" .. tostring(chunk)
end

local function pack_mark(entry)
    return table.concat({
        tostring(math.floor(entry.x + 0.5)),
        tostring(math.floor(entry.y + 0.5)),
        tostring(math.floor(entry.z + 0.5)),
        tostring(fold_s16(entry.yaw)),
        tostring(fold_s16(entry.pitch)),
        tostring(fold_s16(entry.roll)),
        tostring(math.floor(entry.lens or LENS_DEFAULT)),
        tostring(math.floor(entry.travel or TRAVEL_STEPS[2])),
    }, FIELD)
end

local function unpack_mark(text)
    local fields = {}
    for piece in string.gmatch(text, "[^" .. FIELD .. "]+") do
        table.insert(fields, tonumber(piece))
    end
    if #fields < 8 then return nil end
    for _, value in ipairs(fields) do
        if value == nil then return nil end
    end

    return {
        x = fields[1], y = fields[2], z = fields[3],
        yaw = fold_s16(fields[4]),
        pitch = OF.util.clamp(fold_s16(fields[5]), -PITCH_LIMIT, PITCH_LIMIT),
        roll = OF.util.clamp(fold_s16(fields[6]), -ROLL_LIMIT, ROLL_LIMIT),
        lens = OF.util.clamp(math.floor(fields[7]), 1, #LENS),
        travel = OF.util.clamp(math.floor(fields[8]), 1, TRAVEL_STEPS[#TRAVEL_STEPS]),
    }
end

function cam.slot_head(slot)
    local packed = mod_storage_load(head_key(slot), "")
    if packed == nil or packed == "" then return nil end
    local level, area, count = string.match(packed, "^(%-?%d+)|(%-?%d+)|(%d+)$")
    if level == nil then return nil end
    return {
        level = tonumber(level),
        area = tonumber(area),
        count = tonumber(count),
    }
end

function cam.slot_place(slot)
    local head = cam.slot_head(slot)
    if head == nil then return "" end
    return OF.util.level_name(head.level, head.area)
end

function cam.save(slot)
    if slot == nil or slot < 1 or slot > cam.SLOTS then return false end
    if #cam.marks < 2 then
        return false, "A move needs at least two points."
    end
    local np = gNetworkPlayers[0]
    if np == nil then return false, "There is nowhere to save this from." end

    for chunk = 0, KEYS_PER_PATH - 1 do
        local pieces = {}
        for offset = 1, MARKS_PER_KEY do
            local entry = cam.marks[chunk * MARKS_PER_KEY + offset]
            if entry == nil then break end
            table.insert(pieces, pack_mark(entry))
        end
        local packed = table.concat(pieces, MARK)

        if not OF.util.store(body_key(slot, chunk), packed) then return false end
    end

    return OF.util.store(head_key(slot), table.concat({
        tostring(math.floor(np.currLevelNum or 0)),
        tostring(math.floor(np.currAreaIndex or 0)),
        tostring(#cam.marks),
    }, "|"))
end

function cam.load(slot)
    if slot == nil or slot < 1 or slot > cam.SLOTS then return false end
    local head = cam.slot_head(slot)
    if head == nil then return false, "That slot is empty." end

    local list = {}
    for chunk = 0, KEYS_PER_PATH - 1 do
        local packed = mod_storage_load(body_key(slot, chunk), "")
        if packed ~= nil and packed ~= "" then
            for piece in string.gmatch(packed, "[^" .. MARK .. "]+") do
                local entry = unpack_mark(piece)

                if entry ~= nil then table.insert(list, entry) end
            end
        end
    end

    if #list < 2 then return false, "That slot is empty." end
    cam.marks = list
    cam.playFrame = nil
    return true
end

function cam.forget(slot)
    if slot == nil or slot < 1 or slot > cam.SLOTS then return false end
    for chunk = 0, KEYS_PER_PATH - 1 do
        OF.util.clear(body_key(slot, chunk))
    end
    OF.util.clear(head_key(slot))
    return true
end

local function tick()
    if not cam.active() then

        handback()
        if cam.on and cam.where ~= nil and here() ~= cam.where then cam.stop() end
        return
    end

    play_step()
    if not cam.playing() then fly_step() end

    aim_step()

    hold_hud()
    if cam.freeze then
        hold_freeze()
    else
        release_freeze()
    end
    if cam.mouseLook then
        hold_mouse_look()
    else
        release_mouse()
    end

    local eye = cam.eye
    local fx, fy, fz = along(eye.x, eye.y, eye.z, LOOK_AHEAD,
        cam.look.pitch, cam.look.yaw)
    drive(eye.x, eye.y, eye.z, fx, fy, fz)
end

function cam.steady_on()
    return OF.settings ~= nil and OF.settings.steadyCamera == true
end

function cam.set_steady(value)
    if OF.settings == nil or OF.settings.set_steady_camera == nil then
        return false, OF.lang.t("Settings are not loaded.")
    end
    OF.settings.set_steady_camera(value == true)
    return true
end

function cam.steady_stands_down()
    return OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0)
end

function cam.hold_steady()
    if not cam.steady_on() or cam.steady_stands_down() then return false end
    local lakitu = gLakituState
    if lakitu == nil then return false end
    local mag = lakitu.shakeMagnitude
    if mag == nil then return false end
    mag.x, mag.y, mag.z = 0, 0, 0
    lakitu.shakePitchPhase = 0
    lakitu.shakeYawPhase = 0
    lakitu.shakeRollPhase = 0
    return true
end

cam.BOWSER_ARENAS = {}
for _, name in ipairs({ "LEVEL_BOWSER_1", "LEVEL_BOWSER_2", "LEVEL_BOWSER_3" }) do
    local level = _G[name]
    if level ~= nil then cam.BOWSER_ARENAS[level] = true end
end

function cam.skips_bowser_intro()
    local me = gNetworkPlayers[0]
    if me == nil or not cam.BOWSER_ARENAS[me.currLevelNum] then return false end

    if gGlobalSyncTable.ofArenaClear == true then return true end
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil or modes.state() == modes.OFF then
        return false
    end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
        return true
    end
    local spectate = OF.spectate
    return spectate ~= nil and spectate.is_spectating ~= nil
        and spectate.is_spectating(0) == true
end

function cam.skip_bowser_intro()
    local cutscene = rawget(_G, "CUTSCENE_ENTER_BOWSER_ARENA") or 144
    local m = gMarioStates[0]
    local camera = m ~= nil and m.area ~= nil and m.area.camera or nil
    if camera == nil or camera.cutscene ~= cutscene then return false end
    if not cam.skips_bowser_intro() then return false end
    camera.cutscene = 0
    OF.util.optional("play_cutscene", nil, camera)
    if m.action == ACT_READING_NPC_DIALOG then
        set_mario_action(m, ACT_IDLE, 0)
    end
    local bowser = obj_get_first_with_behavior_id(id_bhvBowser)
    while bowser ~= nil do
        if bowser.oBowserUnk88 ~= nil and bowser.oBowserUnk88 < 2 then
            bowser.oBowserUnk88 = 2
        end
        bowser = obj_get_next_with_same_behavior_id(bowser)
    end
    return true
end

hook_event(HOOK_UPDATE, function()
    tick()
    cam.hold_steady()
    cam.skip_bowser_intro()
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not cam.active() then return end

    local menuHasIt = OF.util.menu_has_screen()
    stickX = (not menuHasIt) and (m.controller.stickX or 0) or 0
    stickY = (not menuHasIt) and (m.controller.stickY or 0) or 0
    rightX = (not menuHasIt) and (m.controller.extStickX or 0) or 0
    rightY = (not menuHasIt) and (m.controller.extStickY or 0) or 0

    OF.input.hold(m)

    if not menuHasIt and cam.watching == nil then look_step(m) end
end, OF.LOCAL_MARIO)

local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16

cam.inShot = false
cam.poseLock = false
cam.pose = nil

function cam.toggle_in_shot()
    cam.inShot = not cam.inShot
    return true
end

function cam.toggle_pose_lock()
    cam.poseLock = not cam.poseLock
    return true
end

function cam.reset_screen()
    local moved = false
    if cam.bars ~= true then cam.toggle_bars() moved = true end
    if cam.freeze then cam.toggle_freeze() moved = true end
    if cam.mouseLook then cam.toggle_mouse_look() moved = true end
    if cam.inShot then cam.toggle_in_shot() moved = true end
    if cam.poseLock then cam.toggle_pose_lock() moved = true end

    if not cam.controls_shown() then cam.toggle_controls() moved = true end
    return moved
end

function cam.take_pose(m)
    if cam.pose ~= nil or m == nil or m.marioObj == nil then return end
    local info = m.marioObj.header.gfx.animInfo
    if info == nil then return end
    cam.pose = { id = info.animID, frame = info.animFrame }
end

function cam.hold_pose(m)
    if m == nil or m.marioObj == nil then return false end
    local info = m.marioObj.header.gfx.animInfo
    if info == nil then return false end
    cam.take_pose(m)
    if info.animID ~= cam.pose.id then
        OF.util.optional("set_mario_animation", nil, m, cam.pose.id)
    end

    info.animFrame = cam.pose.frame
    local now = OF.util.optional("get_area_update_counter", nil)
    if type(now) == "number" then info.animTimer = now end
    return true
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not cam.active() then
        cam.pose = nil
        return
    end
    local obj = m.marioObj
    if obj == nil then return end
    cam.take_pose(m)
    if cam.poseLock then cam.hold_pose(m) end
    if cam.inShot then return end
    local node = obj.header.gfx.node
    if OF.util.has_flag(node.flags, INVISIBLE) then return end
    node.flags = node.flags + INVISIBLE
end, OF.LOCAL_MARIO)

local BAR_SHARE = 0.115

cam.showControls = true
cam.FLY_HINTS = {
    { "move", "Fly" },
    { { pad = "R", padText = "R/L", key = "Shift" }, "Up / down" },
    { "jump", "Faster" },
}
cam.LOOK_HINT = { "camera", "Look" }

function cam.controls_shown()
    return cam.showControls ~= false
end

function cam.toggle_controls()
    cam.showControls = not cam.controls_shown()
    return true
end

function cam.control_hints()
    return { cam.FLY_HINTS[1], cam.LOOK_HINT, cam.FLY_HINTS[2], cam.FLY_HINTS[3] }
end

local function render()
    if not cam.active() then return end
    if OF.util == nil or type(OF.util.rect) ~= "function" then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    if cam.bars then
        local bar = math.floor(screenHeight * BAR_SHARE)
        OF.util.rect(0, 0, screenWidth, bar, 0, 0, 0, 255)
        OF.util.rect(0, screenHeight - bar, screenWidth, bar, 0, 0, 0, 255)
    end

    local scale = 0.7
    local lineHeight = OF.util.line_height(scale)

    local degrees = math.floor(OF.util.optional("get_current_fov",
        cam.lens_step(cam.lens).degrees) + 0.5)

    local line = OF.lang.fill("@ - @",
        cam.playing() and OF.lang.t("playing") or cam.pace_name(),
        degrees .. " deg - " .. #cam.marks .. " points")

    local textWidth = OF.util.width(line, scale)
    local inset = math.floor(screenHeight * BAR_SHARE) + lineHeight
    OF.util.text(line, screenWidth - textWidth - lineHeight,
        screenHeight - inset, scale, 220, 220, 220, 200)

    if cam.controls_shown() and OF.util.asks(OF.hud, "hints") then
        local H = OF.hud
        local size = H.HINT_SIZE or 22
        local y
        if cam.bars then
            local bar = math.floor(screenHeight * BAR_SHARE)
            y = screenHeight - bar + math.floor((bar - size) / 2)
        else
            y = screenHeight - inset - size - lineHeight
        end
        cam.hintsDrawnAt = y
        H.hints(cam.control_hints(), { y = y })
    end
end

hook_event(HOOK_ON_HUD_RENDER, function()
    render()
end)

function cam.build_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        "A camera of your own. Your Mario stays where he is."))

    if cam.on then
        table.insert(rows, panel.with_help(panel.row("Put the camera back",
            160, 255, 160, function() cam.stop() end),
            OF.lang.t("the game takes its camera back and you are where you left")))
    else
        table.insert(rows, panel.with_help(panel.row("Take the camera",
            255, 220, 120, function() OF.util.report(cam.start()) end),
            OF.lang.t("the stick flies the camera - your Mario stands still")))

        local notice = OF.util.mode_notice("photo")
        if notice ~= nil then table.insert(rows, panel.label_row(notice)) end
    end

    table.insert(rows, panel.with_help(panel.header_row("The shot"),
        "what the camera sees and how quickly it moves while you fly it"))

    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("Lens"),
            255, 255, 255, function() cam.step_lens(1) end),
            OF.lang.fill("@ (@ deg)", cam.lens_step(cam.lens).name,
                cam.lens_step(cam.lens).degrees)),
        OF.lang.t("how much of the level fits in the shot")))
    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("Pace"),
            255, 255, 255, function() cam.step_pace(1) end),
            OF.lang.t(cam.pace_name())),
        OF.lang.t("how fast the stick flies the camera")))

    table.insert(rows, panel.label_row(
        "How fast noclip flies, too - they share one ladder."))

    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.bars, OF.lang.t("Black bars")),
            255, 255, 255, function() cam.toggle_bars() end),
        OF.lang.t("a strip top and bottom, so the shot is the shape of a film")))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.freeze, OF.lang.t("Hold the level still")),
            255, 255, 255, function() cam.toggle_freeze() end),
        OF.lang.t("stops the level's own moving parts while you line a shot up")))

    table.insert(rows, panel.label_row(
        "The level holds still; people keep moving."))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.inShot, OF.lang.t("Put yourself in the shot")),
            255, 255, 255, function() cam.toggle_in_shot() end),
        OF.lang.t("your own Mario stays in your picture instead of stepping out")))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.poseLock, OF.lang.t("Hold your pose")),
            255, 255, 255, function() cam.toggle_pose_lock() end),
        OF.lang.t("frozen mid-move as you were when you took the camera")))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.mouseLook, OF.lang.t("Mouse look")),
            255, 255, 255, function() cam.toggle_mouse_look() end),
        OF.lang.t("steers the look with the mouse too, grabbed while this is on")))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(cam.controls_shown(), OF.lang.t("On-screen controls")),
            255, 255, 255, function() cam.toggle_controls() end),
        OF.lang.t("the buttons and what they do, in the corner - noclip's too")))
    if cam.roll ~= 0 then
        table.insert(rows, panel.with_help(panel.row("Level the horizon",
            255, 255, 255, function() cam.level_horizon() end),
            OF.lang.t("takes the roll back out, so the shot sits square again")))
    end

    table.insert(rows, panel.with_help(panel.header_row("The subject"),
        "who the camera is pointed at, and the framings it drops into"))

    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("Follow"),
            255, 255, 255, function() cam.step_watch(1) end),
            cam.watch_name() or OF.lang.t("nobody")),
        OF.lang.t("keeps the camera pointed at one person while you fly it")))
    for index = 1, cam.shot_count() do
        local shot = cam.shot(index)
        table.insert(rows, panel.with_help(panel.row(OF.lang.t(shot.name),
            255, 255, 255,
            function() OF.util.report(cam.frame_shot(index)) end),
            OF.lang.t(shot.help)))
    end

    table.insert(rows, panel.label_row(
        "A framing goes where the shot says. Nothing checks the wall."))

    table.insert(rows, panel.with_help(panel.header_row("The move"),
        "a flight saved as a run of points, and the press that flies it"))
    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("Take a point here"),
            255, 220, 120, function() OF.util.report(cam.mark()) end),
            OF.lang.fill("@ so far", #cam.marks)),
        OF.lang.t("saves where the camera is standing as one step of a move")))

    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("Time to each point"),
            255, 255, 255, function() cam.step_travel(1) end),
            OF.lang.fill("@ frames", cam.travel_frames())),
        cam.cuts()
            and OF.lang.t("how long the camera stands at a point before it jumps")
            or OF.lang.t("how long the camera takes to fly from one point to the next")))

    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("How it plays"),
            255, 255, 255, function() cam.step_play_style(1) end),
            OF.lang.t(cam.play_stop(cam.playStyle).name)),
        OF.lang.t(cam.play_stop(cam.playStyle).help)))

    if #cam.marks > 0 then
        table.insert(rows, panel.with_help(panel.row("Remove the last point",
            255, 200, 120, function() OF.util.report(cam.drop_last()) end),
            OF.lang.t("takes the newest point off - the rest of the move stands")))
        table.insert(rows, panel.with_help(
            panel.confirm_row("camclear", "Remove them all",
                255, 140, 90, function() cam.clear_marks() end),
            OF.lang.t("throws the whole move away - a saved slot is untouched")))
    end

    if cam.playing() then
        table.insert(rows, panel.with_help(panel.row("Stop the move",
            160, 255, 160, function() cam.stop_playing() end),
            OF.lang.t("the camera stays where the move had got to")))
    else
        table.insert(rows, panel.with_help(
            panel.with_right(panel.row(OF.lang.t("Play it"),
                160, 255, 160, function() OF.util.report(cam.play()) end),
                cam.plays_for_ever()
                    and OF.lang.fill("@ frames, then again", cam.play_length())
                    or OF.lang.fill("@ frames", cam.play_length())),
            cam.cuts()
                and OF.lang.t("cuts the camera between every point, on the beat above")
                or OF.lang.t("flies the camera through every point in the order taken")))
    end

    table.insert(rows, panel.with_help(
        panel.header_row("Kept on this machine"),
        "three slots for the flight in hand - yours, and they outlive the "
        .. "level"))
    for slot = 1, cam.SLOTS do
        local head = cam.slot_head(slot)
        if head == nil then

            table.insert(rows, panel.with_help(
                panel.with_right(panel.row(OF.lang.fill("Slot @", slot),
                    255, 255, 255, function() OF.util.report(cam.save(slot)) end),
                    OF.lang.t("empty")),
                OF.lang.t("keeps the move in hand on this machine, for later")))
        else

            table.insert(rows, panel.with_help(
                panel.with_right(
                    panel.confirm_row("camload" .. slot,
                        OF.lang.fill("Slot @", slot), 255, 255, 255,
                        function() OF.util.report(cam.load(slot)) end),
                    head.count .. " points, " .. cam.slot_place(slot)),
                OF.lang.t("loads it, and whatever points are in hand are lost")))
            table.insert(rows, panel.with_help(
                panel.confirm_row("camdel" .. slot,
                    OF.lang.fill("   Clear slot @", slot),
                    255, 140, 90, function() cam.forget(slot) end),
                OF.lang.t("empties the slot - what is in hand is untouched")))
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end
