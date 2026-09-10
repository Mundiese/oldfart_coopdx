OF = OF or {}
OF.spectate = OF.spectate or {}

local spectate = OF.spectate

local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16

spectate.target = nil

spectate.free = false
spectate.auto = false
spectate.role = nil

spectate.look = { yaw = 0, pitch = 0 }

spectate.eye = nil
spectate.anchor = nil

spectate.waited = 0

local function has_bit(value, bit)
    if value == nil then return false end
    return math.floor(value / bit) % 2 == 1
end

local function add_bit(value, bit)
    if has_bit(value, bit) then return value end
    return value + bit
end

local function remove_bit(value, bit)
    if not has_bit(value, bit) then return value end
    return value - bit
end

function spectate.is_spectating(localIndex)
    local s = gPlayerSyncTable[localIndex]
    return s ~= nil and s.ofSpectating == true
end

local function hide_if_spectating(m)
    if m == nil or m.marioObj == nil then return end
    if not spectate.is_spectating(m.playerIndex) then return end
    local node = m.marioObj.header.gfx.node
    node.flags = add_bit(node.flags, INVISIBLE)
end

spectate.borrowed = spectate.borrowed or false

local function set_intangible(on)
    if gMarioStates[0] == nil then return end
    OF.util.intangible("spectate", on)
    spectate.borrowed = on and true or false
end

function spectate.is_active()
    return spectate.target ~= nil or spectate.free
end

function spectate.mode_live()
    return spectate.is_active()
end

local function held_elsewhere()
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(0) then
        return true, "You are in jail - the jail decides where you are."
    end
    return false
end

spectate.held_elsewhere = held_elsewhere

local function look_at(globalIndex)
    spectate.target = globalIndex

    spectate.free = false
    spectate.eye = nil
    spectate.anchor = nil

    spectate.waited = 0

    OF.util.enter_mode("spectate")

    OF.util.publish_row(0, "ofSpectating", true)
    set_intangible(true)

    OF.net.teleport_to(globalIndex)
end

function spectate.start(globalIndex)
    if globalIndex == network_global_index_from_local(0) then return false end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false end

    local taken, why = held_elsewhere()

    if taken then return OF.util.report(false, why) end

    look_at(globalIndex)

    OF.notify.show("Spectating @", "info", 4,
        OF.util.plain(gNetworkPlayers[li].name))
    return true
end

function spectate.watchable()
    local list = {}
    local mine = network_global_index_from_local(0)
    for _, entry in ipairs(OF.util.connected_players()) do
        local gi = network_global_index_from_local(entry.localIndex)
        if gi ~= mine and not spectate.is_spectating(entry.localIndex) then
            table.insert(list, gi)
        end
    end
    return list
end

function spectate.step(delta)
    local list = spectate.watchable()
    if #list < 2 then
        return OF.util.report(false, "There is nobody else to watch.")
    end

    local at = 1
    for i, gi in ipairs(list) do
        if gi == spectate.target then at = i end
    end

    look_at(list[((at - 1 + delta) % #list) + 1])
    if OF.util.asks(OF.sounds, "play") then OF.sounds.play(OF.sounds.MOVE) end
    return true
end

function spectate.can_stop()
    return spectate.target ~= nil or spectate.free or spectate.borrowed
end

local ENGINE_POS_H = 0.3
local ENGINE_POS_V = 0.3
local ENGINE_FOC_H = 0.8
local ENGINE_FOC_V = 0.3

local CHASE_LIFT = 120

local CHASE_STEPS = { 260, 480, 900 }

local FLY_FOCUS = 1000

local FLY_STEPS = { 18, 45, 95 }
local FLY_SPRINT = 3
local FLY_LIFT = 38

local LOOK_SPEED = 0x0300

local PITCH_LIMIT = 0x3600

local SNAP = 400

spectate.dist = spectate.dist or 2
spectate.pace = spectate.pace or 2

local function fold_s16(value)
    value = math.floor(value) % 0x10000
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

local function along(x, y, z, dist, pitch, yaw)
    return x + dist * coss(pitch) * sins(yaw),
           y + dist * sins(pitch),
           z + dist * coss(pitch) * coss(yaw)
end

function spectate.shot()

    if not spectate.is_active() then return nil end

    if gLakituState == nil then return nil end

    if OF.util.optional("is_transition_playing", false) then return nil end

    local m = gMarioStates[0]
    if m == nil then return nil end

    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        return nil
    end

    local look = spectate.look

    if spectate.free then
        local eye = spectate.eye
        if eye == nil then return nil end
        local fx, fy, fz = along(eye.x, eye.y, eye.z, FLY_FOCUS,
            look.pitch, look.yaw)
        return eye.x, eye.y, eye.z, fx, fy, fz
    end

    local li = OF.util.local_from_global(spectate.target)
    if li == nil then return nil end

    if OF.net.pendingTarget ~= nil then return nil end

    local them = gNetworkPlayers[li]
    local t = gMarioStates[li]
    if them == nil or t == nil then return nil end

    if not them.currPositionValid then return nil end

    local hx, hy, hz = t.pos.x, t.pos.y + CHASE_LIFT, t.pos.z
    local dist = CHASE_STEPS[spectate.dist] or CHASE_STEPS[2]
    local px, py, pz = along(hx, hy, hz, -dist, look.pitch, look.yaw)
    return px, py, pz, hx, hy, hz
end

local holding = false

local function put(vec, x, y, z)
    if vec == nil then return end
    vec.x, vec.y, vec.z = x, y, z
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

    s.yaw = fold_s16(spectate.look.yaw + 0x8000)
    holding = true

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

spectate.release = release

function spectate.driving()
    return holding
end

local function seed_look()
    local s = gLakituState
    if s == nil then return end

    local view = s.oldYaw
    if view == nil then view = (s.yaw or 0) + 0x8000 end
    spectate.look.yaw = fold_s16(view)
    spectate.look.pitch = OF.util.clamp(fold_s16(s.oldPitch or 0),
        -PITCH_LIMIT, PITCH_LIMIT)
end

function spectate.fly(on)
    if on == false then
        spectate.free = false
        spectate.eye = nil
        spectate.anchor = nil
        return true
    end

    local m = gMarioStates[0]
    if m == nil then return false, "There is no Mario to fly." end

    local taken, why = held_elsewhere()
    if taken then return false, why end

    OF.util.enter_mode("spectate")

    spectate.free = true
    spectate.target = nil
    spectate.anchor = { x = m.pos.x, y = m.pos.y, z = m.pos.z }

    local s = gLakituState
    if s ~= nil and s.pos ~= nil then
        spectate.eye = { x = s.pos.x, y = s.pos.y, z = s.pos.z }
        seed_look()
    else
        spectate.eye = { x = m.pos.x, y = m.pos.y + CHASE_LIFT, z = m.pos.z }
    end

    OF.util.publish_row(0, "ofSpectating", true)
    set_intangible(true)
    return true
end

function spectate.toggle_fly()
    if not spectate.free then return spectate.fly(true) end

    local ok, why = spectate.fly(false)
    if not ok then return false, why end

    local list = spectate.watchable()
    if #list > 0 then
        look_at(list[1])
    else
        spectate.stop()
    end
    return true
end

local stickX, stickY = 0, 0
local rightX, rightY = 0, 0

local function fly_step()
    local pos = spectate.eye
    if pos == nil then return end

    local yaw = spectate.look.yaw
    local raw = math.sqrt(stickX * stickX + stickY * stickY)
    local mag = math.min(raw, 64) / 64
    local speed = (FLY_STEPS[spectate.pace] or FLY_STEPS[2]) * mag
    if OF.input.held(A_BUTTON) then speed = speed * FLY_SPRINT end

    if mag > 0.05 then

        local ux = stickX / math.max(raw, 1)
        local uy = stickY / math.max(raw, 1)
        pos.x = pos.x + (uy * sins(yaw) - ux * coss(yaw)) * speed
        pos.z = pos.z + (uy * coss(yaw) + ux * sins(yaw)) * speed
    end

    if OF.input.held(R_TRIG) then pos.y = pos.y + FLY_LIFT end
    if OF.input.held(L_TRIG) then pos.y = pos.y - FLY_LIFT end
end

local NUDGE_FRAMES = 10

local NUDGE_WAYS = {
    forward = { 0, 1 }, back = { 0, -1 },
    left = { -1, 0 }, right = { 1, 0 },
}

function spectate.nudge(way)
    local pos = spectate.eye
    if pos == nil then return false, "The free camera is not on." end

    if way == "up" or way == "down" then
        pos.y = pos.y + FLY_LIFT * NUDGE_FRAMES * (way == "up" and 1 or -1)
        return true
    end

    local step = NUDGE_WAYS[way]
    if step == nil then
        return false, "Move forward, back, left, right, up or down."
    end

    local yaw = spectate.look.yaw
    local speed = (FLY_STEPS[spectate.pace] or FLY_STEPS[2]) * NUDGE_FRAMES
    local ux, uy = step[1], step[2]
    pos.x = pos.x + (uy * sins(yaw) - ux * coss(yaw)) * speed
    pos.z = pos.z + (uy * coss(yaw) + ux * sins(yaw)) * speed
    return true
end

function spectate.turn(dyaw, dpitch)
    local look = spectate.look
    look.yaw = fold_s16(look.yaw + (dyaw or 0))
    look.pitch = OF.util.clamp(fold_s16(look.pitch + (dpitch or 0)),
        -PITCH_LIMIT, PITCH_LIMIT)
    return true
end

local function look_step(m)
    local dead = OF.input.DEVICE_DEAD or 30
    if not OF.input.arrows_are_keys(m) then
        local x = rightX / 64
        local y = rightY / 64
        if math.abs(rightX) > dead or math.abs(rightY) > dead then

            spectate.turn(-x * LOOK_SPEED, y * LOOK_SPEED)
            return
        end
    end

    local dyaw, dpitch = 0, 0
    if OF.input.held(L_CBUTTONS) then dyaw = dyaw - LOOK_SPEED end
    if OF.input.held(R_CBUTTONS) then dyaw = dyaw + LOOK_SPEED end
    if OF.input.held(U_CBUTTONS) then dpitch = dpitch + LOOK_SPEED end
    if OF.input.held(D_CBUTTONS) then dpitch = dpitch - LOOK_SPEED end
    if dyaw ~= 0 or dpitch ~= 0 then spectate.turn(dyaw, dpitch) end
end

function spectate.get_behind()
    if spectate.free then return false, "Nobody is being watched." end
    local li = OF.util.local_from_global(spectate.target)
    local t = li ~= nil and gMarioStates[li] or nil
    if t == nil then return false, "Nobody is being watched." end
    spectate.look.yaw = fold_s16(t.faceAngle.y or 0)
    return true
end

function spectate.step_range(delta)
    delta = delta or 1
    if spectate.free then
        spectate.pace = ((spectate.pace - 1 + delta) % #FLY_STEPS) + 1
        return true
    end
    spectate.dist = ((spectate.dist - 1 + delta) % #CHASE_STEPS) + 1
    return true
end

function spectate.stop()

    if not spectate.can_stop() then return end
    spectate.target = nil

    spectate.free = false
    spectate.eye = nil
    spectate.anchor = nil
    spectate.auto = false
    spectate.role = nil
    spectate.waited = 0

    local wasDriving = release()

    local area = gMarioStates[0] ~= nil and gMarioStates[0].area or nil
    if wasDriving and area ~= nil and area.camera ~= nil then
        OF.util.optional("soft_reset_camera", nil, area.camera)
    end

    OF.util.publish_row(0, "ofSpectating", false)
    set_intangible(false)

    local m = gMarioStates[0]
    if m ~= nil then

        m.marioObj.header.gfx.node.flags =
            remove_bit(m.marioObj.header.gfx.node.flags, INVISIBLE)
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    if OF.util.asked_in_chat() then
        OF.util.chat("Stopped spectating.")
    end
end

local AUTO_EVERY = 6 * 30
local AUTO_MARGIN = 1
local autoDue = 0

local wasAt = {}

local function interest(localIndex)
    local score = 0
    local t = gMarioStates[localIndex]
    if t == nil then return 0 end

    if spectate.DOING ~= nil and t.action ~= nil and spectate.DOING[t.action] ~= nil then
        score = score + 3
    end

    local was = wasAt[localIndex]
    if was ~= nil then
        local dx, dy, dz = t.pos.x - was.x, t.pos.y - was.y, t.pos.z - was.z
        local moved = math.sqrt(dx * dx + dy * dy + dz * dz)

        score = score + math.min(moved / 20, 2)
    end
    return score
end

local function remember_positions()
    for _, entry in ipairs(OF.util.connected_players()) do
        local t = gMarioStates[entry.localIndex]
        if t ~= nil then
            local was = wasAt[entry.localIndex]
            if was == nil then
                was = {}
                wasAt[entry.localIndex] = was
            end
            was.x, was.y, was.z = t.pos.x, t.pos.y, t.pos.z
        end
    end
end

function spectate.candidates()
    local list = spectate.watchable()
    if spectate.role == nil or spectate.role == "" then return list end

    local kept = {}
    for _, gi in ipairs(list) do
        local li = OF.util.local_from_global(gi)
        if li ~= nil and OF.util.asks(OF.gamemodes, "role")
            and OF.gamemodes.role(li) == spectate.role then
            table.insert(kept, gi)
        end
    end

    return kept
end

local function auto_step()
    if autoDue > 0 then
        autoDue = autoDue - 1
        return
    end
    autoDue = AUTO_EVERY

    local best, bestScore = nil, -1
    for _, gi in ipairs(spectate.candidates()) do
        local li = OF.util.local_from_global(gi)
        if li ~= nil then
            local score = interest(li)
            if score > bestScore then best, bestScore = gi, score end
        end
    end
    if best == nil then return end
    if best == spectate.target then return end

    if spectate.target ~= nil then
        local li = OF.util.local_from_global(spectate.target)
        if li ~= nil and bestScore <= interest(li) + AUTO_MARGIN then return end
    end
    look_at(best)
end

local function role_step()
    if spectate.role == nil or spectate.role == "" then return end
    if not OF.util.asks(OF.gamemodes, "role") then return end

    if spectate.target ~= nil then
        local li = OF.util.local_from_global(spectate.target)
        if li ~= nil and OF.gamemodes.role(li) == spectate.role then return end
    end

    local list = spectate.candidates()
    if #list == 0 then return end
    if list[1] == spectate.target then return end
    look_at(list[1])
end

function spectate.watch_role(role)
    if not OF.util.asks(OF.gamemodes, "with_role") then
        return false, "There is no round to take sides in."
    end
    if role == nil or role == "" then
        spectate.role = nil
        return true
    end

    local was = spectate.role
    spectate.role = role
    if #spectate.candidates() == 0 then
        spectate.role = was
        return false, "Nobody in the round has that job."
    end
    role_step()
    return true
end

local FOLLOW_PATIENCE = 15 * 30

local toldHeld = false

local function update()

    if spectate.is_active() then
        local taken, why = held_elsewhere()
        if taken then
            spectate.stop()
            if not toldHeld then
                toldHeld = true

                OF.util.report(false, why)
            end
            return
        end
    end
    toldHeld = false

    if spectate.free then

        local m = gMarioStates[0]
        local at = spectate.anchor
        if m ~= nil and at ~= nil then
            m.pos.x, m.pos.y, m.pos.z = at.x, at.y, at.z
            m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
            m.forwardVel = 0
            vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        end
        fly_step()
        remember_positions()
        local px, py, pz, fx, fy, fz = spectate.shot()
        if px == nil then release() else drive(px, py, pz, fx, fy, fz) end
        return
    end

    if spectate.is_active() then
        role_step()
        if spectate.auto then auto_step() end
    end
    remember_positions()

    if spectate.target == nil then
        release()
        return
    end

    local li = OF.util.local_from_global(spectate.target)
    if li == nil then

        local list = spectate.candidates()
        if (spectate.auto or spectate.role ~= nil) and #list > 0 then
            look_at(list[1])
            return
        end

        OF.notify.show("The player you were watching left", "warn", 5)
        spectate.stop()
        return
    end

    local me = gNetworkPlayers[0]
    local them = gNetworkPlayers[li]

    if me.currLevelNum ~= them.currLevelNum or me.currAreaIndex ~= them.currAreaIndex then
        release()
        spectate.waited = spectate.waited + 1
        if spectate.waited > FOLLOW_PATIENCE then

            local list = spectate.candidates()
            if (spectate.auto or spectate.role ~= nil) and #list > 0
                and list[1] ~= spectate.target then
                look_at(list[1])
                return
            end
            OF.notify.show("Cannot reach the player you were watching",
                "warn", 5)
            spectate.stop()
            return
        end
        if OF.net.pendingTarget == nil then OF.net.teleport_to(spectate.target) end
        return
    end
    if not them.currPositionValid then
        release()
        return
    end
    spectate.waited = 0

    local m = gMarioStates[0]
    local t = gMarioStates[li]
    if m == nil or t == nil then
        release()
        return
    end

    m.pos.x = t.pos.x
    m.pos.y = t.pos.y + CHASE_LIFT
    m.pos.z = t.pos.z
    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0
    m.faceAngle.y = t.faceAngle.y
    vec3f_copy(m.marioObj.header.gfx.pos, m.pos)

    local px, py, pz, fx, fy, fz = spectate.shot()
    if px == nil then release() else drive(px, py, pz, fx, fy, fz) end
end

local function on_before_mario_update(m)
    if not spectate.is_active() then return end
    if m.playerIndex ~= 0 then return end

    local menuHasIt = OF.util.menu_has_screen()
    stickX = (not menuHasIt) and (m.controller.stickX or 0) or 0
    stickY = (not menuHasIt) and (m.controller.stickY or 0) or 0
    rightX = (not menuHasIt) and (m.controller.extStickX or 0) or 0
    rightY = (not menuHasIt) and (m.controller.extStickY or 0) or 0

    OF.input.freeze(m)

    if not menuHasIt then
        look_step(m)

        if OF.input.pressed(Z_TRIG) then spectate.toggle_fly() end
        if OF.input.pressed(B_BUTTON) then spectate.step_range(1) end

        if not spectate.free then
            if OF.input.pressed(R_TRIG) then spectate.step(1) end
            if OF.input.pressed(L_TRIG) then spectate.step(-1) end
            if OF.input.pressed(A_BUTTON) then spectate.get_behind() end
        end
    end

    set_intangible(true)
end

spectate.DOING = {}
local DOING = spectate.DOING

local function says(action, phrase)
    if action == nil then return end
    DOING[action] = phrase
end

says(ACT_BUBBLED, "down")

says(ACT_STAR_DANCE_EXIT, "taking a star")
says(ACT_DROWNING, "drowning")
says(ACT_BURNING_GROUND, "on fire")
says(ACT_BURNING_JUMP, "on fire")
says(ACT_SHOCKED, "shocked")
says(ACT_STANDING_DEATH, "dying")
says(ACT_DEATH_ON_BACK, "dying")
says(ACT_DEATH_ON_STOMACH, "dying")
says(ACT_QUICKSAND_DEATH, "dying")
says(ACT_ELECTROCUTION, "dying")
says(ACT_SUFFOCATION, "dying")

local function doing(localIndex)
    local t = gMarioStates[localIndex]
    if t == nil or t.action == nil then return "somewhere" end

    local named = DOING[t.action]
    if named ~= nil then return named end

    if OF.util.has_flag(t.action, ACT_FLAG_ON_POLE) then return "on a pole" end
    if OF.util.has_flag(t.action, ACT_FLAG_HANGING) then return "hanging on" end
    if OF.util.has_flag(t.action, ACT_FLAG_SWIMMING) then return "swimming" end
    if OF.util.has_flag(t.action, ACT_FLAG_RIDING_SHELL) then return "on a shell" end

    local group = OF.util.action_group(t.action)
    if group == OF.util.action_group(ACT_GROUP_SUBMERGED) then return "underwater" end
    if group == OF.util.action_group(ACT_GROUP_AIRBORNE) then return "in the air" end
    if group == OF.util.action_group(ACT_GROUP_MOVING) then return "running" end
    if group == OF.util.action_group(ACT_GROUP_STATIONARY) then return "standing" end
    if group == OF.util.action_group(ACT_GROUP_CUTSCENE) then return "in a cutscene" end
    if group == OF.util.action_group(ACT_GROUP_OBJECT) then return "grappling" end
    return "climbing"
end

local function wedges(localIndex)
    local t = gMarioStates[localIndex]
    if t == nil or t.health == nil or t.health <= 0 then return 0 end
    return math.min(math.floor(t.health / 0x100), 8)
end

function spectate.watchers()
    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 and spectate.is_spectating(entry.localIndex) then
            count = count + 1
        end
    end
    return count
end

local function exit_line(unders)
    table.insert(unders, {
        text = OF.lang.t("Z   -   swap chase and free      Travel   -   Stop spectating"),
        r = 150, g = 150, b = 150, scale = 0.6 })
end

local function camera_line(unders)
    if spectate.driving() then return end
    table.insert(unders, {
        text = OF.lang.t("the game has the camera for a moment"),
        r = 255, g = 176, b = 96, scale = 0.6 })
end

local HINT_FRAMES = 150
local hintFor = 0
local hintShot = nil

local function hints_wanted()
    local shot = tostring(spectate.free) .. "\31" .. tostring(spectate.target)
    if shot ~= hintShot then
        hintShot = shot
        hintFor = HINT_FRAMES
    end
    if hintFor > 0 then hintFor = hintFor - 1 end
    return hintFor > 0
end

function spectate.forget_hints()
    hintFor, hintShot = 0, nil
    return true
end

local function render_free_hud()
    local unders = {}
    local showHints = hints_wanted()

    local me = gNetworkPlayers[0]
    local where = me ~= nil
        and OF.util.level_name(me.currLevelNum, me.currAreaIndex) or nil
    table.insert(unders, { text = OF.lang.fill("over @",
        where or OF.lang.t("somewhere")), r = 190, g = 190, b = 190,
        scale = 0.65 })

    camera_line(unders)

    if showHints then
        table.insert(unders, {
            text = OF.lang.t("stick   -   move      L / R   -   down / up      A   -   faster"),
            r = 150, g = 150, b = 150, scale = 0.6 })
        table.insert(unders, {
            text = OF.lang.t("C or right stick   -   look      B   -   speed"),
            r = 150, g = 150, b = 150, scale = 0.6 })
    end
    exit_line(unders)

    OF.util.banner(OF.lang.t("Free camera"), 0.9,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, nil,
        { under = unders })
end

local function render_hud()
    if OF.util.menu_has_screen() then return end

    if spectate.free then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
        render_free_hud()
        return
    end

    if spectate.target == nil then return end
    local li = OF.util.local_from_global(spectate.target)
    if li == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local unders = {}
    local showHints = hints_wanted()

    local me = gNetworkPlayers[0]
    local them = gNetworkPlayers[li]
    local ready = them ~= nil and me ~= nil
        and me.currLevelNum == them.currLevelNum
        and me.currAreaIndex == them.currAreaIndex
        and them.currPositionValid

    local head = {
        { text = OF.lang.t("Spectating") .. "  ", r = 190, g = 190, b = 190 },
        { text = OF.util.plain(tostring(gNetworkPlayers[li].name)),
          r = OF.util.gold().r, g = OF.util.gold().g, b = OF.util.gold().b },
    }
    if ready then
        local w = wedges(li)
        local r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
        if w <= 4 then r, g, b = 255, 96, 96
        elseif w < 8 then r, g, b = 255, 176, 96 end
        table.insert(head, { text = "   " .. tostring(w) .. "/8",
            r = r, g = g, b = b })
    end

    if not ready then
        table.insert(unders, { text = OF.lang.t("catching up with them"),
            r = 200, g = 200, b = 200, scale = 0.65 })
    else
        local parts = {}
        if OF.util.asks(OF.gamemodes, "role") then
            local role = OF.gamemodes.role(li)
            if role ~= nil and role ~= "" then table.insert(parts, role) end
        end
        local where = them ~= nil
            and OF.util.level_name(them.currLevelNum, them.currAreaIndex) or nil
        if where ~= nil then table.insert(parts, where) end
        table.insert(parts, doing(li))
        table.insert(unders, { text = table.concat(parts, "   -   "),
            r = 190, g = 190, b = 190, scale = 0.65 })
    end

    camera_line(unders)

    local driven = nil
    if spectate.role ~= nil and spectate.auto then
        driven = OF.lang.fill("following the @, picking for itself", spectate.role)
    elseif spectate.role ~= nil then
        driven = OF.lang.fill("following the @", spectate.role)
    elseif spectate.auto then
        driven = OF.lang.t("picking for itself")
    end
    if driven ~= nil then
        table.insert(unders, { text = driven, r = 255, g = 176, b = 96,
            scale = 0.6 })
    end

    if showHints then

        local others = spectate.watchers()
        if others > 0 then
            table.insert(unders, {
                text = OF.lang.fill("@ other(s) are watching too", tostring(others)),
                r = 150, g = 150, b = 150, scale = 0.6 })
        end

        if #spectate.watchable() > 1 then
            table.insert(unders, {
                text = OF.lang.t("L / R   -   watch somebody else      A   -   get behind them"),
                r = 150, g = 150, b = 150, scale = 0.6 })
        else
            table.insert(unders, { text = OF.lang.t("A   -   get behind them"),
                r = 150, g = 150, b = 150, scale = 0.6 })
        end
        table.insert(unders, {
            text = OF.lang.t("C or right stick   -   look      B   -   distance"),
            r = 150, g = 150, b = 150, scale = 0.6 })
    end
    exit_line(unders)

    OF.util.banner("", 0.9, 255, 255, 255, nil,
        { segments = head, under = unders })
end

function spectate.set_auto(on)
    if not on then
        spectate.auto = false
        return true
    end
    if #spectate.watchable() == 0 then
        return false, "There is nobody to watch."
    end
    spectate.auto = true
    return true
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update)
hook_event(HOOK_MARIO_UPDATE, hide_if_spectating)
hook_event(HOOK_ON_HUD_RENDER, render_hud)

hook_event(HOOK_ON_NAMETAGS_RENDER, function(playerIndex)
    if spectate.is_spectating(playerIndex) then return { name = "" } end
end)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if spectate.is_active() then return false end
end)

function spectate.toggle(globalIndex)
    if spectate.is_active() then
        spectate.stop()
    else
        spectate.start(globalIndex)
    end
end
