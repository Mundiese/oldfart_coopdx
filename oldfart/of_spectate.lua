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

    if OF.util.asks(OF.roundscope, "hide_body") and OF.roundscope.hide_body(m) then
        return
    end
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

spectate.home = nil

local function in_a_round()
    return OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) == true
end

function spectate.remember_home(always)
    if spectate.home ~= nil then
        if always then spectate.home.always = true end
        return false
    end
    if in_a_round() then return false end
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil or m.pos == nil then return false end
    local venue = nil
    if OF.util.asks(OF.venues, "at") then venue = OF.venues.at(np.currLevelNum, np.currAreaIndex) end
    spectate.home = {
        level = np.currLevelNum, area = np.currAreaIndex, act = np.currActNum,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        angle = m.faceAngle ~= nil and m.faceAngle.y or 0,
        cam = OF.util.optional("cam_select_alt_mode", nil, 0),
        venue = venue, always = always == true,
    }
    return true
end

function spectate.home_exists(home)
    if home == nil or type(home.level) ~= "number" then return false end
    if home.venue ~= nil and OF.venues ~= nil and type(OF.venues.LAYOUTS) == "table"
        and OF.venues.LAYOUTS[home.venue] == nil then
        return false
    end
    if home.level >= 50 then
        local info = OF.util.optional("smlua_level_util_get_info", nil, home.level)
        if info == nil then return false end
    end
    return true
end

function spectate.go_home()
    local home = spectate.home
    spectate.home = nil
    if home == nil or in_a_round() then return nil end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil then return nil end
    local sameRoom = np.currLevelNum == home.level and np.currAreaIndex == home.area
    if sameRoom and not home.always then return nil end
    if not spectate.home_exists(home) then
        local level, area = home.level, 1
        if type(level) ~= "number" or (level >= 50
            and OF.util.optional("smlua_level_util_get_info", nil, level) == nil) then
            level = (gLevelValues ~= nil and gLevelValues.entryLevel) or LEVEL_CASTLE_GROUNDS
        end
        if OF.util.asks(OF.net, "warp_to") then OF.net.warp_to(level, area, 0) end
        OF.notify.show("The place you left is gone - you are at the level's start", "warn", 5)
        return "spawn"
    end
    if home.cam ~= nil then OF.util.optional("cam_select_alt_mode", nil, home.cam) end
    if sameRoom then
        m.pos.x, m.pos.y, m.pos.z = home.x, home.y, home.z
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        if m.faceAngle ~= nil then m.faceAngle.y = home.angle end
        if m.marioObj ~= nil then vec3f_copy(m.marioObj.header.gfx.pos, m.pos) end
        return "here"
    end
    if OF.util.asks(OF.net, "teleport_to_position") then
        OF.net.teleport_to_position({ level = home.level, area = home.area, act = home.act,
            x = home.x, y = home.y, z = home.z, angle = home.angle })
        return "warp"
    end
    return nil
end

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

    if OF.util.asks(OF.roundscope, "may_watch") and not OF.roundscope.may_watch(li) then
        return OF.util.report(false,
            "A hide round is on - its players cannot be watched from outside it")
    end

    if not spectate.is_active() then spectate.remember_home(false) end
    look_at(globalIndex)

    OF.notify.show("Spectating @", "info", 4,
        OF.util.name_safe(gNetworkPlayers[li].name))
    return true
end

function spectate.watchable()
    local list = {}
    local mine = network_global_index_from_local(0)
    for _, entry in ipairs(OF.util.connected_players()) do
        local gi = network_global_index_from_local(entry.localIndex)
        if gi ~= mine and not spectate.is_spectating(entry.localIndex)
            and not (OF.util.asks(OF.roundscope, "may_watch")
                and not OF.roundscope.may_watch(entry.localIndex)) then
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

local CHASE_STEPS = { 750, 1250, 2000 }

local FLY_FOCUS = 1000

local FLY_STEPS = { 6, 18, 45, 95, 240 }
local FLY_SPRINT = 3
local FLY_LIFT = 38

local LOOK_SPEED = 0x0300

local PITCH_LIMIT = 0x3600

local SNAP = 400

spectate.dist = spectate.dist or 2
spectate.pace = spectate.pace or 3

spectate.DIST_STORE = "spectateZoom"
spectate.PACE_STORE = "spectatePace"
function spectate.load_settings()
    if not OF.util.asks(OF.util, "stored_integer") then return false end
    local d = OF.util.stored_integer(spectate.DIST_STORE, spectate.dist)
    local p = OF.util.stored_integer(spectate.PACE_STORE, spectate.pace)
    if type(d) == "number" and d >= 1 and d <= #CHASE_STEPS then spectate.dist = d end
    if type(p) == "number" and p >= 1 and p <= #FLY_STEPS then spectate.pace = p end
    return true
end
hook_event(HOOK_ON_MODS_LOADED, spectate.load_settings)

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

    if not spectate.is_active() then spectate.remember_home(false) end
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
    local speed = (FLY_STEPS[spectate.pace] or FLY_STEPS[3]) * mag

    local free = not OF.util.menu_has_screen()
    if free and OF.input.held(A_BUTTON) then speed = speed * FLY_SPRINT end

    if mag > 0.05 then

        local ux = stickX / math.max(raw, 1)
        local uy = stickY / math.max(raw, 1)
        pos.x = pos.x + (uy * sins(yaw) - ux * coss(yaw)) * speed
        pos.z = pos.z + (uy * coss(yaw) + ux * sins(yaw)) * speed
    end

    if free and OF.input.held(R_TRIG) then pos.y = pos.y + FLY_LIFT end
    if free and OF.input.held(L_TRIG) then pos.y = pos.y - FLY_LIFT end
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
        if OF.util.asks(OF.util, "store_integer") then
            OF.util.store_integer(spectate.PACE_STORE, spectate.pace)
        end
        return true
    end
    spectate.dist = ((spectate.dist - 1 + delta) % #CHASE_STEPS) + 1
    if OF.util.asks(OF.util, "store_integer") then
        OF.util.store_integer(spectate.DIST_STORE, spectate.dist)
    end
    return true
end

function spectate.chase_range()
    return CHASE_STEPS[spectate.dist] or CHASE_STEPS[2]
end

function spectate.fly_pace()
    return FLY_STEPS[spectate.pace] or FLY_STEPS[3]
end

function spectate.chase_steps()
    local out = {}
    for i, one in ipairs(CHASE_STEPS) do out[i] = one end
    return out
end

function spectate.fly_steps()
    local out = {}
    for i, one in ipairs(FLY_STEPS) do out[i] = one end
    return out
end

function spectate.fly_pace_top()
    local top = 0
    for _, one in ipairs(FLY_STEPS) do
        if one > top then top = one end
    end
    return top
end

function spectate.snap_distance()
    return SNAP
end

function spectate.fly_sprint()
    return FLY_SPRINT
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

    spectate.go_home()

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

    if me.currLevelNum ~= them.currLevelNum or me.currAreaIndex ~= them.currAreaIndex
        or (me.currActNum or 0) ~= (them.currActNum or 0) then
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

function spectate.view_yaw()
    return fold_s16(spectate.look.yaw + 0x8000)
end

function spectate.riding()
    local together = OF.together
    if not OF.util.asks(together, "crewing") then return false end
    local body = together.crewing(0)
    return body ~= nil and spectate.target == body
end

spectate.ENTRY = {}
for _, act in ipairs({ ACT_SPAWN_SPIN_AIRBORNE or 0, ACT_SPAWN_SPIN_LANDING or 0,
    ACT_SPAWN_NO_SPIN_AIRBORNE or 0, ACT_SPAWN_NO_SPIN_LANDING or 0,
    ACT_TELEPORT_FADE_IN or 0, ACT_EMERGE_FROM_PIPE or 0, ACT_WARP_DOOR_SPAWN or 0,
    ACT_EXIT_AIRBORNE or 0, ACT_FALLING_EXIT_AIRBORNE or 0,
    ACT_SPECIAL_EXIT_AIRBORNE or 0, ACT_DEATH_EXIT or 0 }) do
    if act ~= 0 then spectate.ENTRY[act] = true end
end

local function on_before_mario_update(m)
    if not spectate.is_active() then return end
    if m.playerIndex ~= 0 then return end
    if spectate.riding() then
        set_intangible(true)

        local menuHasIt = OF.util.menu_has_screen()
        rightX = (not menuHasIt) and (m.controller.extStickX or 0) or 0
        rightY = (not menuHasIt) and (m.controller.extStickY or 0) or 0
        if not menuHasIt then
            look_step(m)

            OF.input.poll(m)
            if OF.input.pressed(R_TRIG) then
                spectate.step_range(1)

                if OF.util.asks(OF.together, "ask_zoom") then OF.together.ask_zoom() end
            end

        end
        return
    end

    local menuHasIt = OF.util.menu_has_screen()
    stickX = (not menuHasIt) and (m.controller.stickX or 0) or 0
    stickY = (not menuHasIt) and (m.controller.stickY or 0) or 0
    rightX = (not menuHasIt) and (m.controller.extStickX or 0) or 0
    rightY = (not menuHasIt) and (m.controller.extStickY or 0) or 0

    OF.input.freeze(m)

    if spectate.ENTRY[m.action] then set_mario_action(m, ACT_FREEFALL, 0) end

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

local function exit_lines(notes)
    if spectate.riding() then
        notes[#notes + 1] = { text = OF.lang.t("Players page   -   Stop steering"), tone = "mute" }
    else
        notes[#notes + 1] = { text = OF.lang.t("Travel   -   Stop spectating"), tone = "mute" }
    end
    local leave = OF.util.asks(OF.outseat, "leave_hint") and OF.outseat.leave_hint()
    if leave ~= nil and leave ~= false then
        notes[#notes + 1] = { text = leave, tone = "mute" }
    end
end

local function camera_line(notes)
    if spectate.driving() then return end
    notes[#notes + 1] = { text = OF.lang.t("the game has the camera for a moment"), tone = "warn" }
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

spectate.KEYS = {
    L = { pad = "L", key = "LShift" }, R = { pad = "R", key = "RShift" },
    A = { pad = "A", key = "L" }, B = { pad = "B", key = "," },
    Z = { pad = "Z", key = "K" }, C = { pad = "C", key = "Arrows" },
    STICK = { pad = "STICK", key = "WASD" },
}
function spectate.legend(kind, others)
    local K = spectate.KEYS
    if kind == "steer" then
        return { { { K.STICK, OF.lang.t("drive their Mario") } },
                 { { K.R, OF.lang.t("zoom") }, { K.C, OF.lang.t("look") } } }
    end
    if kind == "free" then
        return { { { K.STICK, OF.lang.t("move") }, { K.L, OF.lang.t("down") },
                   { K.R, OF.lang.t("up") }, { K.A, OF.lang.t("faster") } },
                 { { K.B, OF.lang.t("speed") }, { K.C, OF.lang.t("look") },
                   { K.Z, OF.lang.t("back to a player") } } }
    end
    local low = {}
    if others then
        low[#low + 1] = { K.L, OF.lang.t("previous") }
        low[#low + 1] = { K.R, OF.lang.t("watch somebody else") }
    end
    low[#low + 1] = { K.A, OF.lang.t("get behind them") }
    return { low, { { K.B, OF.lang.t("zoom") }, { K.C, OF.lang.t("look") },
                    { K.Z, OF.lang.t("free camera") } } }
end

spectate.CARD = { width = 460, pad = 12, gap = 6, chip = 22 }
spectate.layout = nil

local function draw_card(c)
    local H = OF.hud
    if H == nil then return end
    local sw, sh = H.screen()
    local P = spectate.CARD
    local _, _, capL = H.cap("caption", 1, "A")
    local _, _, capN = H.cap("heading", 1, "A")
    local chipRoom = c.chips and (P.chip * 2 + H.S.s3 * 2) or 0
    local w = math.min(P.width, sw - H.MARGIN * 2 - chipRoom * 2)
    local h = P.pad * 2 + capL + P.gap + capN + P.gap + capL
    local noteStep = capL + H.S.s2
    local x = math.floor((sw - w) / 2)
    local bottom = sh - H.MARGIN - (c.hints and (H.HINT_SIZE * 2 + H.S.s3) or 0)
    local y = math.floor(bottom - #c.notes * noteStep - H.S.s2 - h)
    local lay = { card = { x = x, y = y, w = w, h = h }, screen = { w = sw, h = sh } }

    H.plate(x, y, w, h, { strip = c.colour })
    local left = x + P.pad + 4
    local ty = y + P.pad
    H.text_mid(c.kind, left, ty + capL / 2, "caption", "mute", 255, "left")
    if c.role ~= nil and c.role ~= "" then
        H.text_mid(c.role, x + w - P.pad, ty + capL / 2, "caption", "gold", 255, "right")
    end
    ty = ty + capL + P.gap
    local nameRoom = w - P.pad * 2 - 4 - (c.health and 70 or 0)

    H.name_mid(c.name, left, ty + capN / 2, "heading", c.colour, 255, "left", nameRoom,
        { key = "spectate-name" })
    if c.health ~= nil then
        H.text_mid(c.health.text, x + w - P.pad, ty + capN / 2, "heading", c.health.tone, 255, "right")
    end
    ty = ty + capN + P.gap
    if c.line ~= nil and c.line ~= "" then
        H.text_mid(H.fit(c.line, "caption", w - P.pad * 2 - 4), left, ty + capL / 2,
            "caption", "ink2", 255, "left")
    end

    if c.chips then
        local K = spectate.KEYS
        local cy = y + h / 2
        local gw = H.glyph_width(K.L, P.chip)
        local lx = x - H.S.s3 - gw
        H.glyph(K.L, lx, cy - P.chip / 2, P.chip, 255)
        H.arrow_glyph("left", lx - H.S.s2 - 4, cy, 10, "ink2", 255)
        local rx = x + w + H.S.s3
        H.glyph(K.R, rx, cy - P.chip / 2, P.chip, 255)
        H.arrow_glyph("right", rx + H.glyph_width(K.R, P.chip) + H.S.s2 + 4, cy, 10, "ink2", 255)
        lay.prev = { x = lx - H.S.s2 - 9, y = cy - P.chip / 2, w = gw + H.S.s2 + 9, h = P.chip }
        lay.next = { x = rx, y = cy - P.chip / 2, w = H.glyph_width(K.R, P.chip) + H.S.s2 + 9, h = P.chip }
    end

    local ny = y + h + H.S.s2
    for _, note in ipairs(c.notes) do
        H.text_mid(note.text, sw / 2, ny + capL / 2, "caption", note.tone or "mute", 255, "center")
        ny = ny + noteStep
    end

    if c.hints then
        local rows = c.hints
        local base = sh - H.MARGIN - H.HINT_SIZE
        if rows[1] ~= nil then H.hints(rows[1], { y = base }) end
        if rows[2] ~= nil then H.hints(rows[2], { y = base - H.HINT_SIZE - H.S.s2 }) end
    end
    spectate.layout = lay
end

local function render_free_hud()
    local notes = {}
    local me = gNetworkPlayers[0]
    local where = me ~= nil and OF.util.level_name(me.currLevelNum, me.currAreaIndex) or nil
    camera_line(notes)
    exit_lines(notes)
    draw_card({
        kind = OF.lang.t("FREE CAMERA"),
        name = OF.lang.t("Free camera"),
        colour = "gold",
        line = OF.lang.fill("over @", where or OF.lang.t("somewhere")),
        notes = notes,
        hints = hints_wanted() and spectate.legend("free") or nil,
    })
end

local function render_hud()
    if OF.util.menu_has_screen() then return end
    if spectate.free then
        render_free_hud()
        return
    end
    if spectate.target == nil then return end
    local li = OF.util.local_from_global(spectate.target)
    if li == nil then return end

    local me = gNetworkPlayers[0]
    local them = gNetworkPlayers[li]

    local ready = them ~= nil and me ~= nil and OF.util.same_world(li)

    local r, g, b = OF.util.player_color(li)
    local colour = { OF.hud.readable(r or 255, g or 255, b or 255) }

    local health = nil
    if ready then
        local wv = wedges(li)
        local tone = "good"
        if wv <= 4 then tone = "bad" elseif wv < 8 then tone = "warn" end
        health = { text = tostring(wv) .. "/8", tone = tone }
    end

    local role = nil
    if OF.util.asks(OF.gamemodes, "role") then
        local said = OF.gamemodes.role(li)
        if type(said) == "string" and said ~= "" then role = string.upper(said) end
    end

    local line
    if not ready then
        line = OF.lang.t("catching up with them")
    else
        local parts = {}
        local where = them ~= nil and OF.util.level_name(them.currLevelNum, them.currAreaIndex) or nil
        if where ~= nil then parts[#parts + 1] = where end
        parts[#parts + 1] = doing(li)
        line = table.concat(parts, "   -   ")
    end

    local notes = {}
    camera_line(notes)

    local driven = nil
    if spectate.role ~= nil and spectate.auto then
        driven = OF.lang.fill("following the @, picking for itself", spectate.role)
    elseif spectate.role ~= nil then
        driven = OF.lang.fill("following the @", spectate.role)
    elseif spectate.auto then
        driven = OF.lang.t("picking for itself")
    end
    if driven ~= nil then notes[#notes + 1] = { text = driven, tone = "warn" } end

    local riding = spectate.riding()
    local showHints = hints_wanted()
    if showHints and not riding then
        local others = spectate.watchers()
        if others > 0 then
            notes[#notes + 1] = { text = OF.lang.fill("@ other(s) are watching too", tostring(others)),
                tone = "mute" }
        end
    end
    exit_lines(notes)

    local several = #spectate.watchable() > 1
    draw_card({
        kind = riding and OF.lang.t("STEERING") or OF.lang.t("SPECTATING"),
        name = OF.util.name_safe(tostring(them ~= nil and them.name or "")),
        colour = colour,
        role = role,
        health = health,
        line = line,
        notes = notes,
        chips = several and not riding,
        hints = showHints and spectate.legend(riding and "steer" or "watch", several) or nil,
    })
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

    if OF.util.asks(OF.roundscope, "hides_body")
        and OF.roundscope.hides_body(playerIndex) then
        return { name = "" }
    end
end)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if spectate.is_active() then return false end
end)

function spectate.parks_body(m)
    return m ~= nil and m.playerIndex == 0 and spectate.is_active()
end

hook_event(HOOK_MARIO_OVERRIDE_GEOMETRY_INPUTS, function(m)
    if spectate.parks_body(m) then return false end
end)

function spectate.toggle(globalIndex)
    if spectate.is_active() then
        spectate.stop()
    else
        spectate.start(globalIndex)
    end
end
