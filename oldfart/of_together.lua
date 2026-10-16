OF = OF or {}
OF.together = OF.together or {}

local together = OF.together

together.STAND = 1
together.CARRY = 2
together.ROPE  = 4

together.ROPE_MIN = 300
together.ROPE_MAX = 3000
together.ROPE_STEP = 100
together.ROPE_DEFAULT = 900

together.ROPE_STOPS = {
    { name = "handcuffed",      units = 300 },
    { name = "an arm's length", units = 600 },

    { name = "across a room",   units = 900 },
    { name = "down a corridor", units = 1600 },
    { name = "out of sight",    units = 2400 },
    { name = "the whole level", units = 3000 },
}

together.BITE_STOPS = {
    { name = "holds you back" },
    { name = "reels you in",       pull = 0.03 },
    { name = "snaps you together", snap = true },
    { name = "hurts",              wedges = 1 },
    { name = "springs you back",   spring = 0.7 },
}
together.BITE_PLAIN = 1

together.TOSS_STOPS = {
    { name = "set them down",   push = 0 },
    { name = "a gentle toss",   push = 0.6 },
    { name = "a proper throw",  push = 1.0 },
    { name = "over the trees",  push = 1.6 },
    { name = "across the room", push = 2.4 },
    { name = "they keep your momentum", push = 1.0, keepFall = true },

}
together.TOSS_PLAIN = 3

together.RELOAD_STOPS = {
    { name = "never" },
    { name = "when you die",           onDeath = true },
    { name = "when you reach the end", onFinish = true },
    { name = "either way",             onDeath = true, onFinish = true },
}

together.RELOAD_PLAIN = 1

together.RELOAD_DEFAULT = 4

together.MARK_STOPS = {
    { name = "nowhere - the level start" },
    { name = "every few steps",   every = 150 },
    { name = "every landing",     every = 600 },
    { name = "once a courtyard",  every = 1800 },
    { name = "wherever you last scored", onScore = true },
}
together.MARK_PLAIN = 1

together.BITE_KEY = "ofRopeBite"
together.TOSS_KEY = "ofToss"
local function stop_at(list, value, plain)
    local at = math.floor(tonumber(value) or plain)
    if at < 1 or at > #list then at = plain end
    return list[at], at
end

function together.rope_bite()
    return stop_at(together.BITE_STOPS,
        gGlobalSyncTable[together.BITE_KEY], together.BITE_PLAIN)
end

function together.toss()
    return stop_at(together.TOSS_STOPS,
        gGlobalSyncTable[together.TOSS_KEY], together.TOSS_PLAIN)
end

function together.rope_name(units)
    for _, stop in ipairs(together.ROPE_STOPS) do
        if stop.units == units then return stop.name end
    end
    return nil
end

together.SLOTS = 4

local STORE_PREFIX = "tgstate"
function together.switches()
    local value = gGlobalSyncTable.ofTogether
    if type(value) ~= "number" then return 0 end
    return math.floor(value)
end

together.CARRY_OFFERED = false

function together.allows(bit)
    if bit == together.CARRY and not together.CARRY_OFFERED then return false end
    if not OF.util.has_flag(together.switches(), bit) then return false end
    return not together.stands_down()
end

function together.stands_down()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

function together.rope_length()
    local value = gGlobalSyncTable.ofRopeLen
    if type(value) ~= "number" then return together.ROPE_DEFAULT end
    return OF.util.clamp(value, together.ROPE_MIN, together.ROPE_MAX)
end

function together.still_there(globalIndex)
    if globalIndex == nil then return nil end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex == 0 then return nil end

    local np = gNetworkPlayers[localIndex]
    local me = gNetworkPlayers[0]
    if np == nil or me == nil or not np.connected then return nil end

    if np.globalIndex ~= globalIndex then return nil end

    if OF.util.asks(OF.roundscope, "apart") and OF.roundscope.apart(0, localIndex) then
        return nil
    end

    if np.currLevelNum ~= me.currLevelNum then return nil end
    if np.currAreaIndex ~= me.currAreaIndex then return nil end
    if not np.currAreaSyncValid or not me.currAreaSyncValid then return nil end

    if np.currActNum ~= me.currActNum then return nil end
    if np.currPositionValid == false then return nil end

    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end
    return localIndex
end

local function flat_gap(a, b)
    local dx = a.pos.x - b.pos.x
    local dz = a.pos.z - b.pos.z
    return math.sqrt(dx * dx + dz * dz)
end

local function hold_height(m)
    local box = 160
    if m.marioObj ~= nil and type(m.marioObj.hitboxHeight) == "number"
        and m.marioObj.hitboxHeight > 0 then
        box = m.marioObj.hitboxHeight
    end
    return box
end

local function hold_radius(m)
    local wide = 37
    if m.marioObj ~= nil and type(m.marioObj.hitboxRadius) == "number"
        and m.marioObj.hitboxRadius > 0 then
        wide = m.marioObj.hitboxRadius
    end
    return wide
end

local function standable(x, y, z)
    local lower = -11000
    if gLevelValues ~= nil then
        lower = tonumber(gLevelValues.floorLowerLimit) or lower
    end
    local height = OF.util.optional("find_floor_height", nil, x, y, z)
    if height == nil then return true end
    return height > lower
end

local function drawn_here(m)
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil then return end
    vec3f_copy(obj.header.gfx.pos, m.pos)
end

local function may_hold(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return false end
    if m.action == ACT_BUBBLED then return false end
    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        return false
    end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return false
    end
    return true
end

local perch = { on = nil, x = 0, y = 0, z = 0, yaw = 0 }

together.PERCH_REACH = 86
together.PERCH_CATCH = 80

together.PERCH_KEY = "ofPerch"
function together.perched_on()
    return perch.on
end

local function publish_perch(globalIndex)
    OF.util.publish_row(0, "ofPerch", globalIndex)
end

function together.perch_row(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.PERCH_KEY] or nil
    if type(value) ~= "number" then return nil end
    return value
end

local function leave_perch()

    if perch.on ~= nil then publish_perch(nil) end
    perch.on = nil
end

local PERCH_OFF_FRAMES = 60
local perchOff = { who = nil, frames = 0 }

local function step_off(m)
    if perch.on ~= nil then
        perchOff.who = perch.on
        perchOff.frames = PERCH_OFF_FRAMES
    end
    leave_perch()
end

local function stepped_off(m, globalIndex, them)
    if perchOff.who == nil or perchOff.who ~= globalIndex then return false end
    if perchOff.frames <= 0 then perchOff.who = nil; return false end
    if them ~= nil and flat_gap(m, them) > together.PERCH_REACH then
        perchOff.who = nil
        return false
    end
    return true
end

local function spend_step_off(m)
    if perchOff.who == nil then return end
    perchOff.frames = perchOff.frames - 1

    if m ~= nil and (m.action == ACT_FREEFALL or OF.util.action_group(m.action)
        ~= OF.util.action_group(ACT_GROUP_AIRBORNE)) then
        perchOff.frames = 0
    end
    if perchOff.frames <= 0 then perchOff.who = nil end
end

local function lying_down(them)
    if them == nil then return false end
    local action = them.action
    return action == ACT_START_SLEEPING or action == ACT_SLEEPING
end
together.lying_down = lying_down

local function perch_height(mine, theirs)

    local mineBox, theirBox = hold_height(mine), hold_height(theirs)
    return theirs.pos.y + (mineBox > theirBox and mineBox or theirBox) + 12
end

local function find_perch(m)
    if m.vel.y > 0 then return nil end

    local best, bestGap = nil, together.PERCH_REACH + 1
    for _, entry in ipairs(OF.util.connected_players()) do

        if together.still_there(
            network_global_index_from_local(entry.localIndex)) ~= nil then
            local them = gMarioStates[entry.localIndex]

            if them ~= nil and them.pos ~= nil and may_hold(entry.localIndex)
                and together.carried_by(entry.localIndex) == nil
                and not lying_down(them)
                and not stepped_off(m,
                    network_global_index_from_local(entry.localIndex), them) then
                local top = perch_height(m, them)
                local gap = flat_gap(m, them)

                if gap < bestGap and m.pos.y <= top + together.PERCH_CATCH
                    and m.pos.y >= top - 40 then
                    best = entry
                    bestGap = gap
                end
            end
        end
    end

    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

local function hold_perch(m)
    if perch.on == nil then return false end

    local localIndex = together.still_there(perch.on)
    if localIndex == nil then leave_perch(); return false end

    local them = gMarioStates[localIndex]
    if them == nil or them.pos == nil then leave_perch(); return false end
    if not may_hold(localIndex) then leave_perch(); return false end

    if together.carried_by(localIndex) ~= nil then leave_perch(); return false end

    if lying_down(them) then step_off(m); return false end
    if flat_gap(m, them) > together.PERCH_REACH then leave_perch(); return false end

    local moved = { x = them.pos.x - perch.x, z = them.pos.z - perch.z }
    local spun = them.faceAngle.y - perch.yaw
    perch.x, perch.y, perch.z = them.pos.x, them.pos.y, them.pos.z
    perch.yaw = them.faceAngle.y

    m.pos.x = m.pos.x + moved.x
    m.pos.z = m.pos.z + moved.z

    while spun > 32767 do spun = spun - 65536 end
    while spun < -32768 do spun = spun + 65536 end
    if spun ~= 0 then
        local ox, oz = m.pos.x - them.pos.x, m.pos.z - them.pos.z
        local s, c = sins(spun), coss(spun)
        m.pos.x = them.pos.x + ox * c + oz * s
        m.pos.z = them.pos.z + oz * c - ox * s
    end

    m.pos.y = perch_height(m, them)
    if m.vel.y < 0 then m.vel.y = 0 end
    together.perch_footing(m)
    drawn_here(m)
    return true
end

together.PERCH_WALK = 10
function together.perch_footing(m)
    if m == nil or m.vel == nil then return false end
    if (m.intendedMag or 0) < 1 then
        m.forwardVel = 0
        m.vel.x, m.vel.z = 0, 0
        return true
    end
    local speed = m.forwardVel or 0
    if math.abs(speed) > together.PERCH_WALK then
        local k = together.PERCH_WALK / math.abs(speed)
        m.forwardVel = speed * k
        m.vel.x, m.vel.z = (m.vel.x or 0) * k, (m.vel.z or 0) * k
    end
    return true
end

local function perch_pose(m)
    local speed = math.abs(m.forwardVel or 0)
    local want = math.abs(m.intendedMag or 0)
    if want > speed then speed = want end
    if speed < 3 then return CHAR_ANIM_IDLE_HEAD_CENTER end
    if speed <= 11 then return CHAR_ANIM_WALKING end
    return CHAR_ANIM_RUNNING
end

local function perch_look(m)
    set_character_animation(m, perch_pose(m))
end

together.HOLD_KEY = "ofHold"
together.HELD_KEY = "ofHeld"
function together.held_by(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.HELD_KEY] or nil
    if type(value) ~= "number" then return nil end
    return value
end

local function publish_held(globalIndex)
    OF.util.publish_row(0, "ofHeld", globalIndex)
end

together.GRAB_REACH = 120
together.GRAB_CONE = 0x2000

local wriggled = nil
local carriedBy = nil

together.REGRAB_WAIT = 15
local REGRAB_WAIT = together.REGRAB_WAIT
local ESCAPE_GAP = 600
local ESCAPE_FRAMES = 20
local regrab = 0
local escaped = 0

together.CONSENT_WAIT = 15
local CONSENT_WAIT = together.CONSENT_WAIT
local unheld = 0

function together.carried_by(localIndex)
    local mine = network_global_index_from_local(localIndex)
    if mine == nil then return nil end

    local theirs = together.held_by(localIndex)
    if theirs == nil then return nil end

    local hands = OF.util.local_from_global(theirs)
    if hands == nil or hands == localIndex then return nil end
    if hands ~= 0 and together.still_there(theirs) == nil then return nil end
    if together.holding(hands) ~= mine then return nil end
    return theirs
end

local carrier_of = together.carried_by

function together.carrying(localIndex)
    local claim = together.holding(localIndex)
    if claim == nil then return nil end
    local mine = network_global_index_from_local(localIndex)
    if mine == nil then return nil end

    local theirs = OF.util.local_from_global(claim)
    if theirs == nil or theirs == localIndex then return nil end
    if theirs ~= 0 and together.still_there(claim) == nil then return nil end
    if together.held_by(theirs) ~= mine then return nil end
    return claim
end

local function claimed_by()
    local mine = network_global_index_from_local(0)
    if mine == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0
            and together.holding(entry.localIndex) == mine then
            return network_global_index_from_local(entry.localIndex)
        end
    end
    return nil
end

local function my_carrier()
    return carrier_of(0)
end

function together.grabbing(m)
    if m == nil or m.pos == nil then return nil end

    if m.action ~= ACT_PUNCHING and m.action ~= ACT_MOVE_PUNCHING
        and m.action ~= ACT_WATER_PUNCH then
        return nil
    end

    local best, bestGap = nil, together.GRAB_REACH + 1
    for _, entry in ipairs(OF.util.connected_players()) do

        local them = together.still_there(
            network_global_index_from_local(entry.localIndex)) ~= nil
            and gMarioStates[entry.localIndex] or nil

        if them ~= nil and them ~= m and them.pos ~= nil
            and may_hold(entry.localIndex)
            and carrier_of(entry.localIndex) == nil then
            local gap = flat_gap(m, them)
            if gap < bestGap and math.abs(them.pos.y - m.pos.y) < 160 then

                local toward = atan2s(them.pos.z - m.pos.z, them.pos.x - m.pos.x)
                local off = toward - m.faceAngle.y

                while off > 32767 do off = off - 65536 end
                while off < -32768 do off = off + 65536 end
                if math.abs(off) <= together.GRAB_CONE then
                    best = entry
                    bestGap = gap
                end
            end
        end
    end

    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

function together.holding(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.HOLD_KEY] or nil
    if type(value) ~= "number" then return nil end
    return value
end

local function publish_hold(globalIndex)
    OF.util.publish_row(0, "ofHold", globalIndex)
end

local CARRY_LIFT = 0.5

local CARRY_OFF_FLOOR = 0.35
together.CARRY_OFF_FLOOR = CARRY_OFF_FLOOR

local CARRY_CLEAR = 12

local TORSO_FRESH = 2

local function lean_along(m, carrier)
    if m == nil or m.pos == nil then return 0 end
    local body = m.marioBodyState
    if body == nil or body.torsoPos == nil then return 0 end
    local stamp = body.updateTorsoTime
    if type(stamp) ~= "number"
        or get_global_timer() - stamp > TORSO_FRESH then
        return 0
    end
    local dx = body.torsoPos.x - m.pos.x
    local dz = body.torsoPos.z - m.pos.z
    return dx * sins(carrier.faceAngle.y) + dz * coss(carrier.faceAngle.y)
end

function together.arm_height(carrier)
    local box = hold_height(carrier)

    local middle = carrier.pos.y + box * CARRY_LIFT

    local body = carrier.marioBodyState
    local stamp = body ~= nil and body.updateTorsoTime or nil
    local lift = middle
    if type(stamp) == "number" and body.torsoPos ~= nil
        and get_global_timer() - stamp <= TORSO_FRESH then

        lift = OF.util.clamp(body.torsoPos.y, carrier.pos.y, carrier.pos.y + box)
    end
    return lift
end

function together.carry_point(carrier, passenger)
    local lift = together.arm_height(carrier)

    local wide = hold_radius(carrier)
    if passenger ~= nil then wide = math.max(wide, hold_radius(passenger)) end
    local reach = wide * 2 + CARRY_CLEAR + lean_along(carrier, carrier)
    if passenger ~= nil then
        reach = reach - lean_along(passenger, carrier)
    end

    local rider = hold_height(passenger ~= nil and passenger or carrier)
    lift = lift - rider * CARRY_LIFT

    local clear = rider * CARRY_OFF_FLOOR
    if lift < carrier.pos.y + clear then lift = carrier.pos.y + clear end

    local fx, fz = sins(carrier.faceAngle.y), coss(carrier.faceAngle.y)
    local mid = lift + rider * CARRY_LIFT
    if collision_find_surface_on_ray ~= nil and reach > 0 then
        local hit = collision_find_surface_on_ray(carrier.pos.x, mid, carrier.pos.z,
            fx * reach, 0, fz * reach)
        local surface = hit ~= nil and hit.surface or nil
        local n = surface ~= nil and surface.normal or nil
        if surface ~= nil and hit.hitPos ~= nil
            and (n == nil or math.abs(n.y or 0) < 0.7) then
            local gx, gz = hit.hitPos.x - carrier.pos.x, hit.hitPos.z - carrier.pos.z
            local gap = math.sqrt(gx * gx + gz * gz)
            local back = hold_radius(passenger ~= nil and passenger or carrier) + 10
            if gap < reach then reach = math.max(0, gap - back) end
        end
    end
    local x = carrier.pos.x + reach * fx
    local z = carrier.pos.z + reach * fz
    if find_floor_height ~= nil then
        local floor = find_floor_height(x, lift + rider, z)
        if type(floor) == "number" and floor > -10000 and lift < floor + clear then
            lift = floor + clear
        end
    end

    return x, lift, z
end

local carry_point = together.carry_point

local anchor = nil

local function anchor_held(m)
    if anchor == nil then return false end
    if not OF.util.alive(anchor) then anchor = nil; return false end
    return m ~= nil and m.heldObj ~= nil and m.heldObj == anchor
end

local function let_anchor_go(m)
    if anchor ~= nil and OF.util.alive(anchor) then
        if m ~= nil and m.heldObj ~= nil and m.heldObj == anchor then
            mario_drop_held_object(m)
        end
        obj_mark_for_deletion(anchor)
    end
    anchor = nil
end

together.anchor_let_go = let_anchor_go

local function hold_start(m)
    local group = OF.util.action_group(m.action)
    if group == OF.util.action_group(ACT_GROUP_SUBMERGED) then
        return ACT_HOLD_WATER_IDLE
    end
    if group == OF.util.action_group(ACT_GROUP_AIRBORNE) then
        return ACT_HOLD_FREEFALL
    end
    return ACT_HOLD_IDLE
end

local function keep_anchor(m, carrying)
    if m == nil or m.playerIndex ~= 0 then return end

    if not carrying then

        local held = anchor_held(m)
        let_anchor_go(m)
        if held then
            local group = OF.util.action_group(m.action)
            if group == OF.util.action_group(ACT_GROUP_AIRBORNE) then
                set_mario_action(m, ACT_FREEFALL, 0)
            elseif group == OF.util.action_group(ACT_GROUP_STATIONARY)
                or group == OF.util.action_group(ACT_GROUP_MOVING) then
                set_mario_action(m, ACT_IDLE, 0)
            end
        end
        return
    end

    if anchor_held(m) then return end

    let_anchor_go(m)

    anchor = spawn_non_sync_object(id_bhvCarrySomething3, E_MODEL_NONE,
        m.pos.x, m.pos.y, m.pos.z, function(o)

            o.oFlags = OBJ_FLAG_HOLDABLE
            o.oInteractType = INTERACT_GRABBABLE
        end)
    if anchor == nil then return end

    m.usedObj = anchor
    mario_grab_used_object(m)
    if m.heldObj ~= anchor then

        let_anchor_go(m)
        return
    end
    if m.marioBodyState ~= nil then
        m.marioBodyState.grabPos = GRAB_POS_LIGHT_OBJ
    end
    set_mario_action(m, hold_start(m), 0)
end

local function hold_pose(m)
    local group = OF.util.action_group(m.action)
    if group == OF.util.action_group(ACT_GROUP_AIRBORNE) then
        return (m.vel ~= nil and m.vel.y > 0) and CHAR_ANIM_JUMP_WITH_LIGHT_OBJ
            or CHAR_ANIM_FALL_WITH_LIGHT_OBJ
    end
    if group == OF.util.action_group(ACT_GROUP_STATIONARY) then
        return CHAR_ANIM_IDLE_WITH_LIGHT_OBJ
    end
    if group ~= OF.util.action_group(ACT_GROUP_MOVING) then return nil end

    local speed = math.abs(m.forwardVel or 0)
    local want = math.abs(m.intendedMag or 0)
    if want > speed then speed = want end
    if speed < 3 then return CHAR_ANIM_SLOW_WALK_WITH_LIGHT_OBJ end
    if speed <= 11 then return CHAR_ANIM_WALK_WITH_LIGHT_OBJ end
    return CHAR_ANIM_RUN_WITH_LIGHT_OBJ
end

local function wear_hold_pose(m)
    if together.carrying(m.playerIndex) == nil then return end
    local pose = hold_pose(m)
    if pose ~= nil then set_character_animation(m, pose) end
end

local function minted(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

together.ACT_CARRIED = minted("allocate_mario_action",
    ACT_GROUP_AUTOMATIC | ACT_FLAG_STATIONARY)

local function tell_the_camera(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local status = m.statusForCamera
    if status == nil or status.pos == nil then return end
    status.pos.x, status.pos.y, status.pos.z = m.pos.x, m.pos.y, m.pos.z
end
together.tell_the_camera = tell_the_camera

together.CARRY_EASE = 0.4
together.CARRY_SNAP = 400
together.carrySeen = nil

function together.carry_smooth(carrier, x, y, z)
    local seen = together.carrySeen
    local now = get_global_timer ~= nil and get_global_timer() or 0
    local who = carrier ~= nil and carrier.playerIndex or nil

    if seen ~= nil and (now - (seen.frame or -10) ~= 1 or seen.who ~= who) then
        seen = nil
    end
    if seen ~= nil then
        local vx, vy, vz = 0, 0, 0
        if carrier ~= nil and carrier.vel ~= nil then
            vx, vy, vz = carrier.vel.x or 0, carrier.vel.y or 0, carrier.vel.z or 0
        end
        local px, py, pz = seen.x + vx, seen.y + vy, seen.z + vz
        local dx, dy, dz = x - px, y - py, z - pz
        if dx * dx + dy * dy + dz * dz <= together.CARRY_SNAP * together.CARRY_SNAP then
            local k = together.CARRY_EASE
            x, y, z = px + dx * k, py + dy * k, pz + dz * k
        end
    end
    together.carrySeen = { x = x, y = y, z = z, frame = now, who = who }
    return x, y, z
end

local function act_carried(m)
    if m == nil or m.pos == nil then return false end
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    local carrier = carrier_of(m.playerIndex)
    if carrier == nil and m.playerIndex == 0 then carrier = claimed_by() end
    local hands = carrier ~= nil and OF.util.local_from_global(carrier) or nil
    if hands ~= nil and hands ~= 0 and together.still_there(carrier) == nil then
        hands = nil
    end
    if hands == nil or not together.allows(together.CARRY) then
        if m.playerIndex == 0 then
            together.carrySeen = nil
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return false
    end
    local them = gMarioStates[hands]
    if them ~= nil and them.pos ~= nil and hands ~= m.playerIndex then
        local x, y, z = carry_point(them, m)
        if m.playerIndex == 0 then x, y, z = together.carry_smooth(them, x, y, z) end
        m.pos.x, m.pos.y, m.pos.z = x, y, z
        m.faceAngle.y = them.faceAngle.y
    end
    set_character_animation(m, CHAR_ANIM_BEING_GRABBED)
    local obj = m.marioObj
    if obj ~= nil and obj.header ~= nil and obj.header.gfx ~= nil then
        vec3f_copy(obj.header.gfx.pos, m.pos)
        obj.header.gfx.angle.y = m.faceAngle.y
    end
    return false
end
together.act_carried = act_carried

if together.ACT_CARRIED ~= nil then
    minted("hook_mario_action", together.ACT_CARRIED, { every_frame = act_carried })
end

local function carry_look(m)
    if not together.allows(together.CARRY) then return end
    if together.holding(m.playerIndex) ~= nil then
        wear_hold_pose(m)
        return
    end
    local carrier = carrier_of(m.playerIndex)
    if carrier == nil then return end
    set_character_animation(m, CHAR_ANIM_BEING_GRABBED)

    local hands = together.still_there(carrier)
    if hands == nil then return end
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil then return end
    local x, y, z = carry_point(gMarioStates[hands], m)
    local dx, dy, dz = m.pos.x - x, m.pos.y - y, m.pos.z - z
    if (dx * dx + dy * dy + dz * dz) > (ESCAPE_GAP * ESCAPE_GAP) then return end
    obj.header.gfx.pos.x, obj.header.gfx.pos.y, obj.header.gfx.pos.z = x, y, z
end

local function perch_look_remote(m)
    if not together.allows(together.STAND) then return end
    local on = together.perch_row(m.playerIndex)
    if on == nil then return end
    local under = together.still_there(on)
    if under == nil then return end
    local them = gMarioStates[under]
    if them == nil or them.pos == nil then return end
    if flat_gap(m, them) > together.PERCH_REACH then return end
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil then return end
    obj.header.gfx.pos.y = perch_height(m, them)
    perch_look(m)
end

local function thrown_by(m, carrier)
    if carrier ~= nil then
        m.faceAngle.y = carrier.faceAngle.y
        local speed = math.abs(carrier.forwardVel or 0)

        local stop = together.toss()
        local push = stop.push or 1.0
        if speed > 4 and push > 0 then

            mario_set_forward_vel(m, math.min((14 + speed * 1.4) * push, 52))

            if stop.keepFall == true then
                local fall = carrier.vel ~= nil and (carrier.vel.y or 0) or 0
                if fall > 52 then fall = 52 end
                if fall < -52 then fall = -52 end
                m.vel.y = fall
            else
                m.vel.y = 26 * math.min(push, 1.6)
            end
            set_mario_action(m, ACT_THROWN_FORWARD, 0)
            return
        end
    end
    mario_set_forward_vel(m, 0)
    m.vel.y = 0
    set_mario_action(m, ACT_FREEFALL, 0)
end

together.ROPE_KEY = "ofRope"
function together.roped_to(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.ROPE_KEY] or nil
    if type(value) ~= "number" then return nil end
    return value
end

local function rope_partner(m)

    if together.stands_down() then return nil end
    local named = together.roped_to(0)
    if named ~= nil then
        local localIndex = together.still_there(named)
        if localIndex ~= nil then return gMarioStates[localIndex] end
        return nil
    end

    if not together.allows(together.ROPE) then return nil end

    local worst, worstGap = nil, -1
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then
            local them = gMarioStates[entry.localIndex]
            if them ~= nil and them.pos ~= nil
                and together.still_there(
                    network_global_index_from_local(entry.localIndex)) ~= nil then
                local gap = flat_gap(m, them)
                if gap > worstGap then worst, worstGap = them, gap end
            end
        end
    end
    return worst
end

local BITE_EVERY = 30
local WEDGE_FRAMES = 4
local biting = 0

local reeling = false

local REEL_DONE = 6
local REEL_LEAST = 2

local function hold_rope(m)
    local them = rope_partner(m)
    if them == nil then biting = 0; reeling = false; return false end

    local rope = together.rope_length()
    local dx = m.pos.x - them.pos.x
    local dy = m.pos.y - them.pos.y
    local dz = m.pos.z - them.pos.z
    local gap = math.sqrt(dx * dx + dy * dy + dz * dz)

    local bite = together.rope_bite()
    local held = nil

    if bite.pull ~= nil then
        if gap > rope then reeling = true end
        if reeling then

            if gap <= together.PERCH_REACH + REEL_DONE then
                reeling = false
            else
                local slice = (gap - together.PERCH_REACH) * bite.pull
                if slice < REEL_LEAST then slice = REEL_LEAST end
                held = gap - slice
            end
        end
    else
        reeling = false
    end

    if held == nil then
        if gap <= rope or gap <= 0 then biting = 0; return false end
        held = rope
        if bite.snap == true then held = math.min(rope, together.PERCH_REACH) end
    end

    local scale = held / gap
    local x = them.pos.x + dx * scale
    local y = them.pos.y + dy * scale
    local z = them.pos.z + dz * scale

    if not standable(x, y, z) then biting = 0; return false end

    if bite.wedges ~= nil then
        if biting <= 0 then
            m.hurtCounter = (m.hurtCounter or 0) + WEDGE_FRAMES * bite.wedges
            biting = BITE_EVERY
        else
            biting = biting - 1
        end
    else
        biting = 0
    end

    m.pos.x, m.pos.y, m.pos.z = x, y, z
    drawn_here(m)

    local outward = (m.vel.x * dx + m.vel.z * dz) / gap
    if outward > 0 then
        local spring = bite.spring
        local take = outward * (1 + (spring or 0))
        m.vel.x = m.vel.x - (dx / gap) * take
        m.vel.z = m.vel.z - (dz / gap) * take
        if m.forwardVel > 4 then
            if spring ~= nil then
                mario_set_forward_vel(m, -m.forwardVel * spring)
            else
                mario_set_forward_vel(m, m.forwardVel * 0.5)
            end
        end
    end
    return true
end

together.BOND_KEY = "ofBond"
function together.bonded_to(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.BOND_KEY] or nil
    if type(value) ~= "number" then return nil end
    return value
end

local DEATHS = {}
local function is_death(action)
    if type(action) == "number" then DEATHS[action] = true end
end

is_death(ACT_STANDING_DEATH)
is_death(ACT_DEATH_ON_BACK)
is_death(ACT_DEATH_ON_STOMACH)
is_death(ACT_QUICKSAND_DEATH)
is_death(ACT_ELECTROCUTION)
is_death(ACT_SUFFOCATION)
is_death(ACT_DROWNING)
is_death(ACT_WATER_DEATH)
is_death(ACT_DEATH_EXIT)
is_death(ACT_FALLING_DEATH_EXIT)
is_death(ACT_SPECIAL_DEATH_EXIT)

together.FULL_HEALTH = 0x880
together.ONE_WEDGE = 0x100

local sawPartner = nil

local sawWho = nil

local function forget_partner()
    sawPartner = nil
    sawWho = nil
end

function together.share_bar(mine, theirs, seen)
    if seen == nil then return mine end
    if theirs < seen and mine > theirs then return theirs end
    if theirs > seen and mine < theirs then return theirs end
    return mine
end

local function god_holds_bar()
    if not OF.util.asks(OF.cheats, "is_on") then return false end
    return OF.cheats.is_on("godmode") == true
end

function together.bar_is_held()
    if god_holds_bar() then return true end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return true
    end
    if not OF.util.asks(OF.gamemodes, "opening") then return false end
    if OF.util.asks(OF.gamemodes, "is_running")
        and not OF.gamemodes.is_running() then
        return false
    end
    local opening = OF.gamemodes.opening()
    return opening ~= nil and opening.safe == true
end

local function hold_bond(m)
    if together.bar_is_held() then forget_partner(); return false end

    local partner = together.bonded_to(0)
    if partner == nil then forget_partner(); return false end

    local localIndex = OF.util.local_from_global(partner)
    if localIndex == nil or localIndex == 0 then forget_partner(); return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected or np.globalIndex ~= partner then
        forget_partner()
        return false
    end

    local them = gMarioStates[localIndex]

    if them == nil or type(them.health) ~= "number" then
        forget_partner()
        return false
    end

    local theirs = them.health
    local changed = false

    if sawWho ~= partner then
        sawWho = partner
        sawPartner = nil
        if theirs < m.health then
            m.health = theirs
            changed = true
        end
    end

    local wanted = together.share_bar(m.health, theirs, sawPartner)
    if wanted ~= m.health then
        m.health = wanted
        changed = true
    end
    sawPartner = theirs

    if DEATHS[them.action] == true or them.action == ACT_BUBBLED then
        if m.health >= together.ONE_WEDGE then
            m.health = together.ONE_WEDGE - 1
            changed = true
        end
    end

    return changed
end

together.CREW_KEY = "ofCrew"
function together.crewing(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.CREW_KEY] or nil
    if type(value) ~= "number" then return nil end
    if value >= together.CREW_TAKE then return value - together.CREW_TAKE end
    return value
end

together.CREW_TAKE = 256

together.STEER_YAW_KEY = "ofSteerYaw"
together.STEER_YAW_STEP = 0x100

function together.steer_yaw(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.STEER_YAW_KEY] or nil
    return tonumber(value)
end

function together.turn_stick(x, y, delta)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    local a = (tonumber(delta) or 0) * math.pi / 0x8000
    local c, s = math.cos(a), math.sin(a)
    local nx = x * c - y * s
    local ny = y * c + x * s
    return OF.util.clamp(math.floor(nx + 0.5), -128, 127),
        OF.util.clamp(math.floor(ny + 0.5), -128, 127)
end

function together.crew_taking(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[together.CREW_KEY] or nil
    return type(value) == "number" and value >= together.CREW_TAKE
end

function together.crew_of(globalIndex)
    local out = {}
    if globalIndex == nil then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        local at = entry.localIndex
        if at ~= nil and together.crewing(at) == globalIndex
            and network_global_index_from_local(at) ~= globalIndex then
            table.insert(out, at)
        end
    end
    return out
end

function together.crew_size(globalIndex)
    return #together.crew_of(globalIndex)
end

function together.crew_up(passengerGlobal, bodyGlobal, take)
    if not OF.util.is_host() then
        return false, "Only the host can put players on one Mario."
    end
    local at = OF.util.local_from_global(tonumber(passengerGlobal))
    if at == nil then return false, "They have left the lobby." end

    if bodyGlobal == nil then
        OF.util.publish_row(at, "ofCrew", nil)
        return true
    end

    local body = OF.util.local_from_global(tonumber(bodyGlobal))
    if body == nil then return false, "They have left the lobby." end
    if at == body then return false, "Nobody can steer their own Mario twice." end
    if together.crewing(body) ~= nil then
        return false, "They are already steering somebody else's Mario."
    end
    if together.crew_size(tonumber(passengerGlobal)) > 0 then
        return false, "Somebody is already steering their Mario."
    end

    local value = tonumber(bodyGlobal)
    if take == true then value = value + together.CREW_TAKE end
    OF.util.publish_row(at, "ofCrew", value)
    return true
end

function together.sum_the_sticks(sticks)
    local x, y = 0, 0
    for _, pair in ipairs(sticks or {}) do
        x = x + (tonumber(pair.x) or 0)
        y = y + (tonumber(pair.y) or 0)
    end
    local mag = math.sqrt(x * x + y * y)
    local top = 64
    if mag > top then
        x, y, mag = x * (top / mag), y * (top / mag), top
    end
    return x, y, mag
end

together.CREW_BUTTONS = {
    A_BUTTON, B_BUTTON, Z_TRIG, L_TRIG,
    U_CBUTTONS, D_CBUTTONS, L_CBUTTONS, R_CBUTTONS,
    U_JPAD, D_JPAD, L_JPAD, R_JPAD,
}

local function with_bit(value, button)
    if OF.util.has_flag(value, button) then return value end
    return value + button
end

local function without_bit(value, button)
    if not OF.util.has_flag(value, button) then return value end
    return value - button
end

local crewDown = 0

function together.forget_crew_press()
    crewDown = 0
    return true
end

local function drive_the_crew(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local mine = network_global_index_from_local(0)
    local crew = together.crew_of(mine)
    if #crew == 0 then
        crewDown = 0
        return
    end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end

    local taken = false
    for _, at in ipairs(crew) do
        if together.crew_taking(at) then taken = true end
    end
    local sticks = {}
    if not taken then table.insert(sticks, { x = c.stickX, y = c.stickY }) end
    local pads = {}
    for _, at in ipairs(crew) do
        local other = gMarioStates[at]
        local pad = other ~= nil and other.controller or nil

        if pad ~= nil and together.still_there(network_global_index_from_local(at)) == nil then
            pad = nil
        end
        if pad ~= nil then

            local sx, sy = pad.stickX, pad.stickY

            local theirs = together.crew_taking(at) and together.steer_yaw(at) or nil
            local cam = m.area ~= nil and m.area.camera or nil
            if theirs ~= nil and cam ~= nil and cam.yaw ~= nil then
                sx, sy = together.turn_stick(sx, sy, theirs - cam.yaw)
            end
            table.insert(sticks, { x = sx, y = sy })
            table.insert(pads, pad)
        end
    end

    local x, y, mag = together.sum_the_sticks(sticks)
    c.stickX, c.stickY, c.stickMag = x, y, mag

    local down = tonumber(c.buttonDown) or 0
    local pressed = tonumber(c.buttonPressed) or 0
    local released = tonumber(c.buttonReleased) or 0
    local nowDown = 0
    if taken then

        for _, button in ipairs(together.CREW_BUTTONS) do
            down = without_bit(down, button)
        end
    end

    for _, button in ipairs(together.CREW_BUTTONS) do
        local held = OF.util.has_flag(down, button)
        for _, pad in ipairs(pads) do
            if OF.util.has_flag(pad.buttonDown, button) then held = true end
        end
        local was = OF.util.has_flag(crewDown, button)
        if held then
            down = with_bit(down, button)
            nowDown = nowDown + button
            pressed = was and without_bit(pressed, button)
                or with_bit(pressed, button)
            released = without_bit(released, button)
        else
            down = without_bit(down, button)
            pressed = without_bit(pressed, button)
            released = was and with_bit(released, button)
                or without_bit(released, button)
        end
    end

    crewDown = nowDown
    c.buttonDown = down
    c.buttonPressed = pressed
    c.buttonReleased = released
end

local ridingCamera = nil
local ridingAsked = nil
local steerYawSent = nil

local function publish_steer_yaw(yaw)
    if yaw ~= nil then
        local step = together.STEER_YAW_STEP
        yaw = math.floor(yaw / step + 0.5) * step
    end
    if yaw == steerYawSent then return false end
    steerYawSent = yaw
    OF.util.publish_row(0, "ofSteerYaw", yaw ~= nil and yaw or "")
    return true
end
together.publish_steer_yaw = publish_steer_yaw

function together.forget_riding()
    ridingAsked = nil
    return true
end

function together.reachable(globalIndex)
    if globalIndex == nil then return false end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex == 0 then return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected or np.globalIndex ~= globalIndex then return false end
    if OF.util.asks(OF.roundscope, "apart") and OF.roundscope.apart(0, localIndex) then
        return false
    end
    return true
end

local endedBody = nil
function together.end_steering(body, why)
    endedBody = body
    OF.notify.show("@", "warn", 5, OF.lang.t(why or "Steering ended."))
    local mine = network_global_index_from_local(0)
    if OF.util.is_host() then
        OF.util.report(together.crew_up(mine, nil))
    elseif OF.util.asks(OF.net, "host_does") then
        OF.util.report(OF.net.host_does("crew", mine, nil))
    end
    if OF.util.asks(OF.spectate, "stop") and OF.spectate.is_active() then OF.spectate.stop() end
    return true
end

local function ride_along(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local body = together.crewing(0)
    if body == nil or body ~= endedBody then endedBody = nil end
    if body ~= nil and body == endedBody then body = nil end
    if body ~= nil and not together.reachable(body) then
        together.end_steering(body, "Steering ended - they left or a round stands between you.")
        body = nil
    elseif body ~= nil and ridingCamera == body and OF.spectate ~= nil
        and not OF.spectate.is_active() then

        ridingCamera = nil
        together.end_steering(body, "Steering ended - they went where you cannot follow.")
        body = nil
    end

    if body == nil then

        if ridingCamera ~= nil then
            if OF.util.asks(OF.spectate, "stop")
                and OF.spectate.target == ridingCamera then
                OF.spectate.stop()
            end
        end
        ridingCamera, ridingAsked = nil, nil
        if steerYawSent ~= nil then publish_steer_yaw(nil) end
        return
    end

    m.freeze = 2

    if ridingCamera ~= body and ridingAsked ~= body
        and OF.spectate ~= nil and OF.spectate.target ~= body
        and OF.util.asks(OF.spectate, "start") then
        ridingAsked = body

        if OF.util.asks(OF.spectate, "remember_home") and not OF.spectate.is_active() then
            OF.spectate.remember_home(true)
        end
        if OF.spectate.start(body) then
            ridingCamera = body
        elseif not OF.spectate.is_active() then
            OF.spectate.home = nil
        end
    end

    if OF.util.asks(OF.spectate, "view_yaw") and OF.spectate.target == body
        and together.crew_taking(0) then
        publish_steer_yaw(OF.spectate.view_yaw())
    end
end

together.drive_the_crew = drive_the_crew
together.ride_along = ride_along

together.PACKET_ZOOM_ASK = "ofzoomask"
together.PACKET_ZOOM = "ofzoom"
together.zoomOwed = 0

function together.pass_zoom(steererGlobal)
    if not OF.util.is_host() then return false end
    local seat = OF.util.local_from_global(tonumber(steererGlobal))
    if seat == nil then return false end
    local body = together.crewing(seat)
    if body == nil or not together.crew_taking(seat) then return false end
    local li = OF.util.local_from_global(body)
    if li == nil then return false end
    if li == 0 then
        together.zoomOwed = together.zoomOwed + 1
        return true
    end
    return OF.util.send_to_player(li, { ofp = together.PACKET_ZOOM })
end

function together.ask_zoom()
    if together.crewing(0) == nil or not together.crew_taking(0) then return false end
    if OF.util.is_host() then return together.pass_zoom(network_global_index_from_local(0)) end
    return OF.util.send_to_host({ ofp = together.PACKET_ZOOM_ASK })
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end
    if data.ofp == together.PACKET_ZOOM_ASK then
        local _, askerGlobal = OF.util.asked_by(data)
        if askerGlobal ~= nil then together.pass_zoom(askerGlobal) end
    elseif data.ofp == together.PACKET_ZOOM then
        if OF.util.from_host_effect(data) then together.zoomOwed = together.zoomOwed + 1 end
    end
end)

function together.pay_zoom(m)
    if m == nil or m.playerIndex ~= 0 or together.zoomOwed <= 0 then return false end
    together.zoomOwed = together.zoomOwed - 1
    if OF.util.optional("camera_config_is_free_cam_enabled", false) ~= true then return false end
    local c = m.controller
    if c == nil then return false end
    c.buttonPressed = with_bit(tonumber(c.buttonPressed) or 0, R_TRIG)
    return true
end
hook_event(HOOK_MARIO_UPDATE, together.pay_zoom, OF.LOCAL_MARIO)

local function state_here()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil or m.pos == nil then
        return nil, "Nothing is loaded to save."
    end
    if not np.currAreaSyncValid then
        return nil, "Wait for the level to finish loading."
    end
    return {
        level = np.currLevelNum, area = np.currAreaIndex, act = np.currActNum,
        x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = m.faceAngle.y,
        health = m.health, coins = m.numCoins,
    }
end

local slots = {}

local restoring = nil
local drill = { from = nil, at = nil, running = false, frames = 0,
                best = nil, last = nil, auto = true, wasAt = nil,
                reload = together.RELOAD_DEFAULT }

local frozen = false
local stepping = 0

local FREEZE_BITS = (TIME_STOP_ENABLED or 0x02)
    | (TIME_STOP_MARIO_AND_DOORS or 0x08)
    | (TIME_STOP_ALL_OBJECTS or 0x10)
local ALL_TIME_BITS = 0x7F

function together.state(slot)
    return slots[slot]
end

function together.drill_state()
    return drill
end

function together.is_frozen()
    return frozen
end

local function store_state(slot)
    if slot < 1 or slot > together.SLOTS then return end
    local s = slots[slot]
    if s == nil then
        OF.util.store(STORE_PREFIX .. tostring(slot), "")
        return
    end
    OF.util.store(STORE_PREFIX .. tostring(slot), table.concat({
        math.floor(s.level), math.floor(s.area), math.floor(s.act),
        math.floor(s.x), math.floor(s.y), math.floor(s.z),
        math.floor(s.yaw), math.floor(s.health), math.floor(s.coins),
    }, " "))
end

local function restore_slots()
    for slot = 1, together.SLOTS do
        local line = mod_storage_load(STORE_PREFIX .. tostring(slot), "")
        if line ~= nil and line ~= "" then
            local n = {}
            for word in string.gmatch(line, "%S+") do
                table.insert(n, tonumber(word))
            end

            if #n == 9 and n[9] ~= nil then
                slots[slot] = { level = n[1], area = n[2], act = n[3],
                                x = n[4], y = n[5], z = n[6], yaw = n[7],
                                health = n[8], coins = n[9] }
            end
        end
    end
end

hook_event(HOOK_ON_MODS_LOADED, function() restore_slots() end)

together.HAND_PACKET = "handstate"
together.received = nil

local function hand_wire(s)
    return { l = math.floor(s.level), a = math.floor(s.area),
             c = math.floor(s.act or 0), x = math.floor(s.x),
             y = math.floor(s.y), z = math.floor(s.z),
             w = math.floor(s.yaw or 0) }
end

local function take_hand(data, fromGlobal)
    for _, field in ipairs({ "l", "a", "c", "x", "y", "z", "w" }) do
        if type(data[field]) ~= "number" then return false end
    end
    together.received = {
        from = fromGlobal,
        state = { level = data.l, area = data.a, act = data.c,
                  x = data.x, y = data.y, z = data.z, yaw = data.w,
                  placeOnly = true },
    }
    local li = OF.util.local_from_global(fromGlobal)
    local who = li ~= nil and gNetworkPlayers[li] ~= nil
        and OF.util.plain(gNetworkPlayers[li].name) or OF.lang.t("Somebody")
    OF.notify.show(OF.lang.fill("@ handed you a practice state", who), "info", 5)
    return true
end
together.take_hand = take_hand

function together.hand_state(slot, targetGlobal)
    slot = math.floor(tonumber(slot) or 1)
    local s = slots[slot]
    if s == nil then return false, "That slot is empty." end
    if not OF.perms.can("teleport_self") then
        return false, "Your rank cannot do that.", "teleport_self"
    end
    local target = OF.util.local_from_global(targetGlobal)
    if target == nil or target == 0 then
        return false, "They have left the lobby."
    end
    local wire = hand_wire(s)
    wire.ofp = together.HAND_PACKET
    wire.t = targetGlobal
    if OF.util.is_host() then
        wire.f = network_global_index_from_local(0)
        if not OF.util.send_to_player(target, wire) then
            return false, "They are not ready to be sent anything yet."
        end
    elseif not OF.util.send_to_host(wire) then
        return false, "No host to ask yet - try again in a second."
    end
    return true
end

function together.go_to_received()
    local got = together.received
    if got == nil then return false, "Nobody has handed you a state." end
    return go_to(got.state, nil)
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= together.HAND_PACKET then return end
    if OF.util.is_host() then
        local _, sender = OF.util.asked_by(data)
        if sender == nil then return end
        local target = OF.util.local_from_global(data.t)
        if target == nil then return end
        if target == 0 then
            take_hand(data, sender)
            return
        end
        local wire = { ofp = together.HAND_PACKET, f = sender, l = data.l,
            a = data.a, c = data.c, x = data.x, y = data.y, z = data.z, w = data.w }

        if not OF.util.send_to_player(target, wire) then return end
        return
    end
    if not OF.util.from_host_effect(data) then return end
    take_hand(data, data.f)
end)

function together.save_state(slot)
    slot = math.floor(tonumber(slot) or 1)
    if slot < 1 or slot > together.SLOTS then
        return false, "There is no slot with that number."
    end
    if not OF.perms.can("teleport_self") then
        return false, "Your rank cannot do that.", "teleport_self"
    end

    local s, why = state_here()
    if s == nil then return false, why end
    slots[slot] = s
    store_state(slot)
    return true
end

function together.clear_state(slot)
    slot = math.floor(tonumber(slot) or 1)
    if slots[slot] == nil then return false, "That slot is empty." end
    slots[slot] = nil
    store_state(slot)
    return true
end

local function go_to(s, slot)
    if s == nil then return false, "There is nowhere to go back to." end
    if not OF.perms.can("teleport_self") then
        return false, "Your rank cannot do that.", "teleport_self"
    end

    local np = gNetworkPlayers[0]
    if np == nil then return false, "Nothing is loaded." end

    restoring = { state = s, slot = slot, waited = 0 }

    if np.currLevelNum ~= s.level or np.currAreaIndex ~= s.area then
        if not OF.util.asks(OF.net, "warp_local") then
            restoring = nil
            return false, "This build cannot warp."
        end
        if not OF.net.warp_local(s.level, s.area, s.act) then
            restoring = nil
            return false, "There is no way into that part of the level."
        end
    end
    return true
end

function together.load_state(slot)
    slot = math.floor(tonumber(slot) or 1)
    local s = slots[slot]
    if s == nil then return false, "That slot is empty." end
    return go_to(s, slot)
end

local function settle_restore()
    if restoring == nil then return end

    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    local s = restoring.state
    restoring.waited = restoring.waited + 1

    if np == nil or m == nil then return end

    if np.currLevelNum == s.level and np.currAreaIndex == s.area
        and np.currAreaSyncValid then
        if OF.util.asks(OF.net, "snap_to") then
            OF.net.snap_to(s.x, s.y, s.z, s.yaw)
        else
            m.pos.x, m.pos.y, m.pos.z = s.x, s.y, s.z
            m.faceAngle.y = s.yaw
        end

        if not s.placeOnly then
            m.health = s.health
            m.numCoins = s.coins
            m.hurtCounter = 0
            m.healCounter = 0
        end
        restoring = nil
        return
    end

    if restoring.waited > 600 then
        restoring = nil
        OF.notify.show("That state could not be reached", "bad", 5)
    end
end

function together.reset()
    if drill.from ~= nil then
        slots[0] = drill.from
        return together.load_state(0)
    end
    for slot = 1, together.SLOTS do
        if slots[slot] ~= nil then return together.load_state(slot) end
    end
    if together.checkpoint() ~= nil then return together.to_checkpoint() end
    return false, "Save a state first."
end

function together.drill_start()
    if not OF.perms.can("teleport_self") then
        return false, "Your rank cannot do that.", "teleport_self"
    end
    local s, why = state_here()
    if s == nil then return false, why end

    local sameRoom = drill.at ~= nil
        and drill.at.level == s.level and drill.at.area == s.area
    if not sameRoom then drill.at = nil end
    if drill.from == nil or drill.from.x ~= s.x or drill.from.y ~= s.y
        or drill.from.z ~= s.z or not sameRoom then
        drill.best = nil
        drill.last = nil
    end

    drill.from = s
    slots[0] = s
    drill.running = false
    drill.frames = 0
    return true
end

function together.drill_finish()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil or m.pos == nil then
        return false, "Nothing is loaded."
    end
    if drill.from == nil then return false, "Set the start first." end
    drill.at = { level = np.currLevelNum, area = np.currAreaIndex,
                 x = m.pos.x, y = m.pos.y, z = m.pos.z }
    return true
end

function together.drill_clear()
    drill.from = nil
    drill.at = nil
    drill.running = false
    drill.frames = 0
    drill.best = nil
    drill.last = nil

    drill.wasAt = nil
    return true
end

function together.reload_stop()
    local at = math.floor(tonumber(drill.reload) or together.RELOAD_DEFAULT)
    if at < 1 or at > #together.RELOAD_STOPS then at = together.RELOAD_DEFAULT end
    return together.RELOAD_STOPS[at], at
end

function together.set_reload(at)
    at = math.floor(tonumber(at) or together.RELOAD_DEFAULT)
    if at < 1 then at = #together.RELOAD_STOPS end
    if at > #together.RELOAD_STOPS then at = 1 end
    drill.reload = at
    drill.auto = (at ~= together.RELOAD_PLAIN)
    return true
end

function together.drill_auto(on)
    return together.set_reload(on == true and #together.RELOAD_STOPS
        or together.RELOAD_PLAIN)
end

together.DRILL_REACH = 150

local PUT_BACK_GAP = 3000

local START_REACH = 300

local function attempt_is_over(m, np, was)
    if m.health < together.ONE_WEDGE then return true end
    if m.action == ACT_BUBBLED then return true end
    if DEATHS[m.action] == true then return true end

    local here = np.currLevelNum
    if drill.from ~= nil and here ~= drill.from.level
        and (drill.at == nil or here ~= drill.at.level) then
        return true
    end

    if was ~= nil then
        local dx, dy, dz = m.pos.x - was.x, m.pos.y - was.y, m.pos.z - was.z
        if (dx * dx + dy * dy + dz * dz) > (PUT_BACK_GAP * PUT_BACK_GAP) then
            return true
        end

        local spawn = m.spawnInfo ~= nil and m.spawnInfo.startPos or nil
        if spawn ~= nil then
            local nx, ny, nz = m.pos.x - spawn.x, m.pos.y - spawn.y,
                m.pos.z - spawn.z
            local ox, oy, oz = was.x - spawn.x, was.y - spawn.y, was.z - spawn.z
            if (nx * nx + ny * ny + nz * nz) < (START_REACH * START_REACH)
                and (ox * ox + oy * oy + oz * oz)
                    > (PUT_BACK_GAP * PUT_BACK_GAP) then
                return true
            end
        end
    end
    return false
end

together.attempt_is_over = attempt_is_over

local function reload_drill()
    slots[0] = drill.from
    local ok, why = together.load_state(0)
    if ok then return end
    together.set_reload(together.RELOAD_PLAIN)
    OF.notify.show("The drill could not put you back: @", "bad", 6, tostring(why))
end

local function run_drill(m)
    if drill.from == nil then return end
    if restoring ~= nil then

        drill.wasAt = nil
        return
    end

    local np = gNetworkPlayers[0]
    if np == nil or m == nil or m.pos == nil then return end

    local wasAt = drill.wasAt
    drill.wasAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z }

    local atStart = np.currLevelNum == drill.from.level
        and np.currAreaIndex == drill.from.area

    if not drill.running then

        if atStart then
            local dx = m.pos.x - drill.from.x
            local dz = m.pos.z - drill.from.z
            if math.sqrt(dx * dx + dz * dz) > 60 then
                drill.running = true
                drill.frames = 0
            end
        end
        return
    end

    drill.frames = drill.frames + 1

    if drill.at ~= nil and np.currLevelNum == drill.at.level
        and np.currAreaIndex == drill.at.area then
        local dx = m.pos.x - drill.at.x
        local dy = m.pos.y - drill.at.y
        local dz = m.pos.z - drill.at.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) < together.DRILL_REACH then
            drill.last = drill.frames
            if drill.best == nil or drill.frames < drill.best then
                drill.best = drill.frames
            end
            drill.running = false
            OF.notify.show("@ frames", "good", 4, tostring(drill.frames))
            if together.reload_stop().onFinish == true then reload_drill() end
            return
        end
    end

    if together.reload_stop().onDeath == true
        and attempt_is_over(m, np, wasAt) then
        drill.running = false
        reload_drill()
    end
end

local mark = nil
local markAt = together.MARK_PLAIN

function together.mark_stop()
    local at = math.floor(tonumber(markAt) or together.MARK_PLAIN)
    if at < 1 or at > #together.MARK_STOPS then at = together.MARK_PLAIN end
    return together.MARK_STOPS[at], at
end

function together.set_mark(at)
    at = math.floor(tonumber(at) or together.MARK_PLAIN)
    if at < 1 then at = #together.MARK_STOPS end
    if at > #together.MARK_STOPS then at = 1 end
    markAt = at

    if at == together.MARK_PLAIN then mark = nil end
    return true
end

function together.reset_screen()
    local _, at = together.mark_stop()
    if at == together.MARK_PLAIN then return false end
    return together.set_mark(together.MARK_PLAIN)
end

function together.checkpoint()
    return mark
end

local function safe_ground(m)
    if m == nil or m.pos == nil or m.floor == nil then return false end

    local group = OF.util.action_group(m.action)
    if group ~= OF.util.action_group(ACT_GROUP_STATIONARY)
        and group ~= OF.util.action_group(ACT_GROUP_MOVING) then
        return false
    end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_INVULNERABLE) then return false end
    if OF.util.has_flag(m.input or 0, INPUT_ABOVE_SLIDE) then return false end
    if OF.util.has_flag(m.floor.flags or 0, SURFACE_FLAG_DYNAMIC) then return false end
    if m.floor.object ~= nil then return false end
    return true
end

together.safe_ground = safe_ground

local scoreSeen = nil
local scoreArmed = false

local function keep_mark(m)
    local stop = together.mark_stop()

    if stop.onScore == true then
        local coins = m.numCoins or 0
        if scoreSeen ~= nil and coins > scoreSeen then scoreArmed = true end
        scoreSeen = coins
        if not scoreArmed then return false end
    else
        scoreSeen = nil
        scoreArmed = false
        if stop.every == nil then
            mark = nil
            return false
        end
    end

    local np = gNetworkPlayers[0]
    if np == nil or not np.currAreaSyncValid then return false end

    if mark ~= nil and (mark.level ~= np.currLevelNum
        or mark.area ~= np.currAreaIndex) then
        mark = nil
    end

    if restoring ~= nil then return false end
    if my_carrier() ~= nil or perch.on ~= nil then return false end
    if not safe_ground(m) then return false end

    if mark ~= nil and stop.every ~= nil then
        local dx, dy, dz = m.pos.x - mark.x, m.pos.y - mark.y, m.pos.z - mark.z
        if (dx * dx + dy * dy + dz * dz) < (stop.every * stop.every) then
            return false
        end
    end
    scoreArmed = false

    mark = { level = np.currLevelNum, area = np.currAreaIndex,
             act = np.currActNum, placeOnly = true,
             x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = m.faceAngle.y }
    return true
end

function together.to_checkpoint()
    if mark == nil then return false, "Nowhere has been safe yet." end
    return go_to(mark)
end

function together.can_freeze()
    local count = 0
    for _, _ in ipairs(OF.util.connected_players()) do count = count + 1 end
    if count > 1 then
        return false, "Frame steps only work on your own, with nobody else here."
    end
    if OF.util.binding("set_time_stop_flags") == nil then
        return false, "This build cannot stop time."
    end
    return true
end

function together.freeze(on)
    if on == true then
        local may, why = together.can_freeze()
        if not may then return false, why end
        frozen = true
        stepping = 0
        return true
    end
    frozen = false
    stepping = 0
    OF.util.optional("clear_time_stop_flags", nil, ALL_TIME_BITS)
    return true
end

function together.step_frame()
    if not frozen then return false, "Nothing is frozen." end
    stepping = 2
    return true
end

local function hold_freeze()
    if not frozen then return end

    if stepping > 0 then
        stepping = stepping - 1
        OF.util.optional("clear_time_stop_flags", nil, ALL_TIME_BITS)
        return
    end

    OF.util.optional("set_time_stop_flags", nil, FREEZE_BITS)
end

local function player_of_object(o)
    if o == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = gMarioStates[entry.localIndex]
        if other ~= nil and other.marioObj ~= nil and other.marioObj == o then
            return entry.localIndex
        end
    end
    return nil
end

local function held_together(mine, theirs)
    local myGlobal = network_global_index_from_local(mine)
    local theirGlobal = network_global_index_from_local(theirs)
    if myGlobal == nil or theirGlobal == nil then return false end

    if together.allows(together.CARRY) then
        if together.holding(mine) == theirGlobal then return true end
        if together.holding(theirs) == myGlobal then return true end
    end
    if together.allows(together.STAND) then
        if together.perch_row(mine) == theirGlobal then return true end
        if together.perch_row(theirs) == myGlobal then return true end
    end
    return false
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if interactType ~= INTERACT_PLAYER then return end
    if m == nil or o == nil then return end
    local theirs = player_of_object(o)
    if theirs == nil or theirs == m.playerIndex then return end
    if held_together(m.playerIndex, theirs) then return false end
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    drive_the_crew(m)
    ride_along(m)
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 or m.pos == nil then return end

    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        leave_perch()
        return
    end
    if not together.allows(together.STAND) then leave_perch(); return end
    if together.holding(0) ~= nil then leave_perch(); return end

    local carriedNow = my_carrier()
    if carriedNow ~= nil and carriedNow ~= wriggled
        and together.allows(together.CARRY) then
        leave_perch()
        return
    end

    spend_step_off(m)

    if perch.on ~= nil and m.controller ~= nil then
        local pressed = m.controller.buttonPressed
        if OF.util.has_flag(pressed, A_BUTTON) then
            step_off(m)
            set_mario_action(m, ACT_JUMP, 0)
            return
        end
        if OF.util.has_flag(pressed, Z_TRIG) or OF.util.has_flag(pressed, B_BUTTON) then
            step_off(m)
            return
        end
    end

    if perch.on == nil then
        local found = find_perch(m)
        if found == nil then return end
        local localIndex = together.still_there(found)
        if localIndex == nil then return end
        local them = gMarioStates[localIndex]
        perch.on = found
        publish_perch(found)
        perch.x, perch.y, perch.z = them.pos.x, them.pos.y, them.pos.z

        perch.yaw = them.faceAngle.y
    end

    hold_perch(m)
end, OF.LOCAL_MARIO)

function together.follow_carrier(carrier)
    if carrier == nil or carrier.pos == nil then return false end
    if not together.allows(together.CARRY) then return false end
    local claim = together.carrying(carrier.playerIndex)
    if claim == nil then return false end
    local p = OF.util.local_from_global(claim)
    if p == nil or p == carrier.playerIndex then return false end
    local them = gMarioStates[p]
    if them == nil or them.pos == nil or them.marioObj == nil then return false end
    local x, y, z = carry_point(carrier, them)
    if p == 0 then

        if carriedBy == nil
            or network_global_index_from_local(carrier.playerIndex) ~= carriedBy then
            return false
        end
        them.pos.x, them.pos.y, them.pos.z = x, y, z
        local obj = them.marioObj
        obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
        drawn_here(them)
        return true
    end
    local dx, dy, dz = them.pos.x - x, them.pos.y - y, them.pos.z - z
    if (dx * dx + dy * dy + dz * dz) > (ESCAPE_GAP * ESCAPE_GAP) then return false end
    local gfx = them.marioObj.header ~= nil and them.marioObj.header.gfx or nil
    if gfx == nil then return false end
    gfx.pos.x, gfx.pos.y, gfx.pos.z = x, y, z
    return true
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.pos == nil then return end

    together.follow_carrier(m)

    if m.playerIndex ~= 0 then carry_look(m); perch_look_remote(m); return end

    hold_bond(m)

    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        leave_perch()

        if together.held_by(0) ~= nil then publish_held(nil) end
        keep_anchor(m, false)
        return
    end

    local named = claimed_by()
    if named == nil then wriggled = nil end
    local carrier = (named ~= wriggled) and named or nil
    local hands = carrier ~= nil and together.still_there(carrier) or nil

    local jumped = m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed, A_BUTTON)
        and not (OF.util.asks(OF.perms, "is_muted_rank") and OF.perms.is_muted_rank(0))

    if hands ~= nil and carrier_of(hands) ~= nil then
        carrier, hands = nil, nil
    end

    if hands ~= nil and not may_hold(hands) then carrier, hands = nil, nil end

    if carrier ~= nil and hands ~= nil and together.allows(together.CARRY)
        and not jumped then

        if together.held_by(0) ~= carrier then publish_held(carrier) end
        carriedBy = carrier
        leave_perch()
        local them = gMarioStates[hands]
        local x, y, z = carry_point(them, m)
        m.pos.x, m.pos.y, m.pos.z = x, y, z
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        mario_set_forward_vel(m, 0)
        m.faceAngle.y = them.faceAngle.y
        drawn_here(m)

        if together.ACT_CARRIED ~= nil and m.action ~= together.ACT_CARRIED then

            together.carrySeen = nil
            set_mario_action(m, together.ACT_CARRIED, 0)
        end

        tell_the_camera(m)

        set_character_animation(m, CHAR_ANIM_BEING_GRABBED)
        return
    end

    if carrier ~= nil and jumped then wriggled = carrier end

    if together.held_by(0) ~= nil then publish_held(nil) end

    if carriedBy ~= nil then
        local last = together.still_there(carriedBy)
        thrown_by(m, last ~= nil and gMarioStates[last] or nil)
        carriedBy = nil
    end

    if regrab > 0 then regrab = regrab - 1 end

    local held = together.holding(0)
    if held ~= nil then
        local localIndex = together.still_there(held)

        local mine = network_global_index_from_local(0)
        local mutual = localIndex ~= nil and mine ~= nil
            and together.holding(localIndex) == mine and held < mine
        if localIndex == nil or mutual or not together.allows(together.CARRY)
            or not may_hold(localIndex) then
            publish_hold(nil)
            regrab = REGRAB_WAIT
        elseif m.controller ~= nil
            and OF.util.has_flag(m.controller.buttonPressed, B_BUTTON) then
            publish_hold(nil)
            regrab = REGRAB_WAIT
        else

            if together.held_by(localIndex) == mine then
                unheld = 0
            else
                unheld = unheld + 1
                if unheld >= CONSENT_WAIT then
                    publish_hold(nil)
                    regrab = REGRAB_WAIT
                    unheld = 0
                end
            end

            local them = gMarioStates[localIndex]
            local hx, hy, hz = carry_point(m, them)
            local dx, dy, dz = them.pos.x - hx, them.pos.y - hy, them.pos.z - hz
            if (dx * dx + dy * dy + dz * dz) > (ESCAPE_GAP * ESCAPE_GAP) then
                escaped = escaped + 1
                if escaped >= ESCAPE_FRAMES then
                    publish_hold(nil)
                    regrab = REGRAB_WAIT
                    escaped = 0
                end
            else
                escaped = 0
            end
        end
    elseif regrab == 0 and together.allows(together.CARRY) then
        escaped = 0

        unheld = 0
        local grabbed = together.grabbing(m)
        if grabbed ~= nil and together.still_there(grabbed) ~= nil then
            publish_hold(grabbed)
        end
    end

    keep_anchor(m, together.carrying(0) ~= nil)

    wear_hold_pose(m)

    if together.allows(together.STAND) and hold_perch(m) then perch_look(m) end
    hold_rope(m)

    keep_mark(m)
end)

together.parked = {}
local steerBusy = false

function together.lobby_busy()
    local gm = OF.gamemodes
    if OF.util.asks(gm, "state") and gm.state() ~= gm.OFF then return true end
    if OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running() then return true end
    if OF.util.asks(OF.mapvote, "running") and OF.mapvote.running() then return true end
    if OF.util.asks(OF.vote, "current") then
        local q = OF.vote.current()
        if q ~= nil and (q.kind == "playlist" or q.kind == "finale") then return true end
    end
    return false
end

local function seat_name(globalIndex)
    local at = OF.util.local_from_global(tonumber(globalIndex))
    local np = at ~= nil and gNetworkPlayers[at] or nil
    if np == nil or not np.connected or np.globalIndex ~= globalIndex then return nil end
    return np.name
end

function together.park_crews()
    if not OF.util.is_host() then return 0 end
    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local at = entry.localIndex
        local body = together.crewing(at)
        if body ~= nil then
            local seat = network_global_index_from_local(at)
            table.insert(together.parked, {
                seat = seat, body = body, take = together.crew_taking(at),
                seatName = seat_name(seat), bodyName = seat_name(body),
            })
            OF.util.publish_row(at, "ofCrew", nil)
            count = count + 1
            for _, who in ipairs({ seat, body }) do
                OF.notify.send_to(who, "Steering paused for the round - it comes back after.",
                    "info", 5)
            end
        end
    end
    return count
end

function together.resume_crews()
    if not OF.util.is_host() then return 0 end
    local back = 0
    local list = together.parked
    together.parked = {}
    for _, p in ipairs(list) do
        local seatName, bodyName = seat_name(p.seat), seat_name(p.body)
        local seatAt = OF.util.local_from_global(p.seat)
        local bodyAt = OF.util.local_from_global(p.body)
        local apart = seatAt ~= nil and bodyAt ~= nil
            and OF.util.asks(OF.roundscope, "apart") and OF.roundscope.apart(seatAt, bodyAt)
        if seatName ~= nil and seatName == p.seatName and bodyName ~= nil
            and bodyName == p.bodyName and not apart
            and together.crew_up(p.seat, p.body, p.take) == true then
            back = back + 1
            for _, who in ipairs({ p.seat, p.body }) do
                OF.notify.send_to(who, "Steering is back.", "info", 4)
            end
        end
    end
    return back
end

function together.forget_parked(globalIndex)
    local keep = {}
    for _, p in ipairs(together.parked) do
        if p.seat ~= globalIndex and p.body ~= globalIndex then table.insert(keep, p) end
    end
    together.parked = keep
end

function together.steer_hold()
    if not OF.util.is_host() then return end
    local busy = together.lobby_busy()
    if busy and not steerBusy then
        together.park_crews()
    elseif steerBusy and not busy and #together.parked > 0 then
        together.resume_crews()
    end
    steerBusy = busy
end

hook_event(HOOK_UPDATE, function()
    together.ready()
    hold_freeze()
    together.steer_hold()
    settle_restore()
    run_drill(gMarioStates[0])
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    together.forget_crew_press()
    together.forget_riding()
end)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end

    if perch.on ~= nil
        and perch.on == network_global_index_from_local(m.playerIndex) then
        leave_perch()
    end
    if together.holding(0) == network_global_index_from_local(m.playerIndex) then
        publish_hold(nil)
    end

    if together.held_by(0) == network_global_index_from_local(m.playerIndex) then
        publish_held(nil)
    end
    if together.perch_row(0) == network_global_index_from_local(m.playerIndex) then
        publish_perch(nil)
    end

    if not OF.util.is_host() then return end

    local gone = network_global_index_from_local(m.playerIndex)
    for _, entry in ipairs(OF.util.connected_players()) do
        if together.roped_to(entry.localIndex) == gone then
            OF.util.publish_row(entry.localIndex, "ofRope", nil)
        end
        if together.bonded_to(entry.localIndex) == gone then
            OF.util.publish_row(entry.localIndex, "ofBond", nil)
        end

        if together.crewing(entry.localIndex) == gone then
            OF.util.publish_row(entry.localIndex, "ofCrew", nil)
        end
    end
    OF.util.publish_row(m.playerIndex, "ofRope", nil)
    OF.util.publish_row(m.playerIndex, "ofBond", nil)
    OF.util.publish_row(m.playerIndex, "ofCrew", nil)
    together.forget_parked(gone)

end)

function together.set_switch(bit, on)
    if not OF.util.is_host() then
        return OF.net.host_does("together", bit, on and 1 or 0)
    end
    bit = math.floor(tonumber(bit) or 0)
    if bit ~= together.STAND and bit ~= together.CARRY and bit ~= together.ROPE then
        return false, "There is no such switch."
    end

    local now = together.switches()
    local wanted

    if on then
        wanted = OF.util.has_flag(now, bit) and now or (now + bit)
    else
        wanted = OF.util.has_flag(now, bit) and (now - bit) or now
    end
    OF.util.publish("ofTogether", wanted)
    return true
end

function together.set_rope(units)
    if not OF.util.is_host() then
        return OF.net.host_does("rope", math.floor(tonumber(units) or 0), 0)
    end
    units = OF.util.clamp(math.floor(tonumber(units) or together.ROPE_DEFAULT),
        together.ROPE_MIN, together.ROPE_MAX)
    OF.util.publish("ofRopeLen", units)
    return true
end

local function set_stop(key, list, at, plain)
    at = math.floor(tonumber(at) or plain)
    if at < 1 then at = #list end
    if at > #list then at = 1 end
    OF.util.publish(key, at)
    return true
end

function together.set_bite(at)
    if not OF.util.is_host() then
        return OF.net.host_does("ropebite", math.floor(tonumber(at) or 0), 0)
    end
    return set_stop(together.BITE_KEY, together.BITE_STOPS, at, together.BITE_PLAIN)
end

function together.set_toss(at)
    if not OF.util.is_host() then
        return OF.net.host_does("toss", math.floor(tonumber(at) or 0), 0)
    end
    return set_stop(together.TOSS_KEY, together.TOSS_STOPS, at, together.TOSS_PLAIN)
end

function together.pair_up()
    if not OF.util.is_host() then return OF.net.host_does("pairup") end

    local order = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        table.insert(order, network_global_index_from_local(entry.localIndex))
    end
    table.sort(order)
    if #order < 2 then return false, "There is nobody to tie you to." end

    local tied = 0
    local at = 1
    while at + 1 <= #order do
        if together.tie(order[at], order[at + 1]) then tied = tied + 1 end
        at = at + 2
    end

    if at == #order then together.tie(order[at], nil) end
    return true, nil, tied
end

function together.cut_all()
    if not OF.util.is_host() then return OF.net.host_does("cutall") end
    local cut = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if together.roped_to(entry.localIndex) ~= nil then
            OF.util.publish_row(entry.localIndex, "ofRope", nil)
            cut = cut + 1
        end
    end

    local why = nil
    if together.allows(together.ROPE) then
        local ok, refused = together.set_switch(together.ROPE, false)
        if ok then cut = cut + 1 else why = refused end
    end

    return true, why, cut
end

function together.tie(globalA, globalB)

    if not OF.util.is_host() then
        return false, "Only the host can tie players together."
    end
    local a = OF.util.local_from_global(tonumber(globalA))
    if a == nil then return false, "They have left the lobby." end

    local was = together.roped_to(a)
    if was ~= nil then
        local other = OF.util.local_from_global(was)
        if other ~= nil then OF.util.publish_row(other, "ofRope", nil) end
    end

    if globalB == nil then
        OF.util.publish_row(a, "ofRope", nil)
        return true
    end

    local b = OF.util.local_from_global(tonumber(globalB))
    if b == nil then return false, "They have left the lobby." end
    if a == b then return false, "Nobody can be tied to themselves." end

    local wasB = together.roped_to(b)
    if wasB ~= nil then
        local other = OF.util.local_from_global(wasB)
        if other ~= nil then OF.util.publish_row(other, "ofRope", nil) end
    end

    OF.util.publish_row(a, "ofRope", tonumber(globalB))
    OF.util.publish_row(b, "ofRope", tonumber(globalA))
    return true
end

function together.share_health(globalA, globalB)
    if not OF.util.is_host() then return false, "Only the host can share a health bar." end
    local a = OF.util.local_from_global(tonumber(globalA))
    if a == nil then return false, "They have left the lobby." end
    if globalB == nil then
        local was = together.bonded_to(a)
        if was == nil then return false, "They do not share a health bar." end
        local other = OF.util.local_from_global(was)
        OF.util.publish_row(a, "ofBond", nil)
        if other ~= nil then OF.util.publish_row(other, "ofBond", nil) end
        OF.notify.send_to(tonumber(globalA), "Your health is your own again", "info", 5)
        if other ~= nil then
            OF.notify.send_to(was, "Your health is your own again", "info", 5)
        end
        return true
    end
    local b = OF.util.local_from_global(tonumber(globalB))
    if b == nil then return false, "They have left the lobby." end
    if a == b then return false, "Nobody can share a health bar with themselves." end
    if together.bonded_to(a) == tonumber(globalB) then return true end
    if together.bonded_to(a) ~= nil or together.bonded_to(b) ~= nil then
        return false, "One of them already shares a health bar."
    end
    OF.util.publish_row(a, "ofBond", tonumber(globalB))
    OF.util.publish_row(b, "ofBond", tonumber(globalA))
    OF.notify.send_to(tonumber(globalA), "One bar between you now", "good", 6)
    OF.notify.send_to(tonumber(globalB), "One bar between you now", "good", 6)
    return true
end

function together.snapshot()
    local _, bite = together.rope_bite()
    local _, toss = together.toss()
    local snap = {
        switches = together.switches(),
        rope = together.rope_length(),
        bite = bite,
        toss = toss,
        ropes = {},
    }
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil then
            snap.ropes[np.globalIndex] = together.roped_to(entry.localIndex)
        end
    end
    return snap
end

function together.restore(snap)
    if not OF.util.is_host() then return 0 end
    snap = type(snap) == "table" and snap or {}
    local moved = 0

    local switches = math.floor(tonumber(snap.switches) or 0)
    local most = together.STAND + together.CARRY + together.ROPE
    if switches < 0 or switches > most then switches = 0 end
    if switches ~= together.switches() then
        OF.util.publish("ofTogether", switches)
        moved = moved + 1
    end

    local units = OF.util.clamp(
        math.floor(tonumber(snap.rope) or together.ROPE_DEFAULT),
        together.ROPE_MIN, together.ROPE_MAX)
    if units ~= together.rope_length() then
        OF.util.publish("ofRopeLen", units)
        moved = moved + 1
    end

    local wantBite = math.floor(tonumber(snap.bite) or together.BITE_PLAIN)
    if wantBite < 1 or wantBite > #together.BITE_STOPS then
        wantBite = together.BITE_PLAIN
    end
    local _, nowBite = together.rope_bite()
    if wantBite ~= nowBite then
        OF.util.publish(together.BITE_KEY, wantBite)
        moved = moved + 1
    end

    local wantToss = math.floor(tonumber(snap.toss) or together.TOSS_PLAIN)
    if wantToss < 1 or wantToss > #together.TOSS_STOPS then
        wantToss = together.TOSS_PLAIN
    end
    local _, nowToss = together.toss()
    if wantToss ~= nowToss then
        OF.util.publish(together.TOSS_KEY, wantToss)
        moved = moved + 1
    end

    local ropes = type(snap.ropes) == "table" and snap.ropes or {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = gNetworkPlayers[entry.localIndex]

        local rope = nil
        if np ~= nil then rope = tonumber(ropes[np.globalIndex]) end
        if rope ~= together.roped_to(entry.localIndex) then
            OF.util.publish_row(entry.localIndex, "ofRope", rope)
            moved = moved + 1
        end
    end

    return moved
end

function together.on_now()
    local said = {}
    for _, switch in ipairs({
        { bit = together.STAND, name = "standing on each other" },
        { bit = together.CARRY, name = "carrying each other" },
        { bit = together.ROPE,  name = "everybody roped" },
    }) do
        if together.allows(switch.bit) then said[#said + 1] = switch.name end
    end

    local tied = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if together.roped_to(entry.localIndex) ~= nil then tied = tied + 1 end
    end
    if tied > 0 then said[#said + 1] = OF.lang.fill("@ on a rope", tied) end
    return said
end

local registered = false

function together.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true

    OF.net.register_action("together", "rules", function(fromLocal, bit, on)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_switch(tonumber(bit), tonumber(on) == 1)
    end)

    OF.net.register_action("rope", "rules", function(fromLocal, units)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_rope(tonumber(units))
    end)

    OF.net.register_action("ropebite", "rules", function(fromLocal, at)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_bite(tonumber(at))
    end)

    OF.net.register_action("toss", "rules", function(fromLocal, at)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_toss(tonumber(at))
    end)

    OF.net.register_action("pairup", "teleport_other", function(fromLocal)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.pair_up()
    end)

    OF.net.register_action("cutall", "teleport_other", function(fromLocal)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.cut_all()
    end)

    local function may_tie(fromLocal, globalIndex)
        local at = OF.util.local_from_global(tonumber(globalIndex))
        if at == fromLocal then return true end
        return OF.util.may_act_on(fromLocal, at)
    end

    OF.net.register_action("tie", "teleport_other", function(fromLocal, a, b)
        if not OF.util.is_host() then
            return false, "Only the host can tie players together."
        end
        local may, whyNot = may_tie(fromLocal, a)
        if not may then return false, whyNot end
        if b ~= nil and tonumber(b) ~= nil then
            local mayB, whyB = may_tie(fromLocal, b)
            if not mayB then return false, whyB end
        end
        return together.tie(a, b)
    end)

    OF.net.register_action("crew", "teleport_other", function(fromLocal, a, b, c)
        if not OF.util.is_host() then
            return false, "Only the host can put players on one Mario."
        end
        local may, whyNot = may_tie(fromLocal, a)
        if not may then return false, whyNot end
        if b ~= nil and tonumber(b) ~= nil then
            local mayB, whyB = may_tie(fromLocal, b)
            if not mayB then return false, whyB end
        end
        return together.crew_up(a, b, c == "take")
    end)

    OF.net.register_action("bond", "share_health", function(fromLocal, a, b)
        if not OF.util.is_host() then
            return false, "Only the host can share a health bar."
        end
        local may, whyNot = may_tie(fromLocal, a)
        if not may then return false, whyNot end
        if b ~= nil and tonumber(b) ~= nil then
            local mayB, whyB = may_tie(fromLocal, b)
            if not mayB then return false, whyB end
        end
        return together.share_health(a, tonumber(b))
    end)
end

function together.summary(localIndex)
    local parts = {}
    local held = together.holding(localIndex)
    if held ~= nil then
        local li = OF.util.local_from_global(held)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        table.insert(parts, OF.lang.fill("carrying @",
            OF.util.plain(np ~= nil and np.name or "somebody")))
    end
    local rope = together.roped_to(localIndex)
    if rope ~= nil then
        local li = OF.util.local_from_global(rope)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        table.insert(parts, OF.lang.fill("roped to @",
            OF.util.plain(np ~= nil and np.name or "somebody")))
    end
    local bond = together.bonded_to(localIndex)
    if bond ~= nil then
        local li = OF.util.local_from_global(bond)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        table.insert(parts, OF.lang.fill("one bar with @",
            OF.util.plain(np ~= nil and np.name or "somebody")))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

function together.tie_candidates(localIndex)
    local out = {}
    if localIndex == nil then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= localIndex and entry.localIndex ~= 0 then
            table.insert(out, entry)
        end
    end
    return out
end

function together.build_tie_page(panel)
    local localIndex = OF.util.local_from_global(panel.selected)
    if localIndex == nil then
        return {

            panel.label_row(OF.lang.t("They have left the lobby.")),
            panel.back_row(),
        }
    end

    local name = OF.util.plain(gNetworkPlayers[localIndex].name)
    local rows = { panel.label_row(
        OF.lang.fill("Tie @ to which player?", name)) }

    local globalIndex = network_global_index_from_local(localIndex)
    for _, entry in ipairs(together.tie_candidates(localIndex)) do
        local other = network_global_index_from_local(entry.localIndex)
        local r, g, b = OF.util.name_colour()

        table.insert(rows, panel.gated_row("teleport_other", entry.np.name,
            r, g, b, function()
                OF.util.report(OF.net.host_does("tie", globalIndex, other))
                panel.go("player")
            end))
    end

    table.insert(rows, panel.back_row())
    return rows
end

function together.bond_candidates(localIndex)
    local out = {}
    if localIndex == nil then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= localIndex and together.bonded_to(entry.localIndex) == nil then
            table.insert(out, entry)
        end
    end
    return out
end

function together.build_bond_page(panel)
    local localIndex = OF.util.local_from_global(panel.selected)
    if localIndex == nil then
        return {
            panel.label_row(OF.lang.t("They have left the lobby.")),
            panel.back_row(),
        }
    end
    local name = OF.util.plain(gNetworkPlayers[localIndex].name)
    local rows = { panel.label_row(
        OF.lang.fill("Share @'s health bar with which player?", name)) }
    local globalIndex = network_global_index_from_local(localIndex)
    for _, entry in ipairs(together.bond_candidates(localIndex)) do
        local other = network_global_index_from_local(entry.localIndex)
        local r, g, b = OF.util.name_colour()
        table.insert(rows, panel.gated_row("share_health", entry.np.name,
            r, g, b, function()
                OF.util.report(OF.net.host_does("bond", globalIndex, other))
                panel.go("player")
            end))
    end
    table.insert(rows, panel.back_row())
    return rows
end

function together.build_rows(panel, localIndex)
    local rows = {}
    if localIndex == nil or localIndex == 0 then return rows end

    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return rows end
    local name = OF.util.plain(np.name)
    local globalIndex = network_global_index_from_local(localIndex)

    local rope = together.roped_to(localIndex)
    if rope ~= nil then
        table.insert(rows, panel.gated_confirm_row("teleport_other",
            "untie" .. tostring(globalIndex),
            OF.lang.fill("Cut @'s rope", name), 255, 180, 120, function()
                OF.util.report(OF.net.host_does("tie", globalIndex, nil))
            end))
    else
        table.insert(rows, panel.gated_confirm_row("teleport_other",
            "tie" .. tostring(globalIndex),
            OF.lang.fill("Tie @ to me", name), 180, 220, 255, function()
                OF.util.report(OF.net.host_does("tie", globalIndex,
                    network_global_index_from_local(0)))
            end))

        if #together.tie_candidates(localIndex) > 0 then
            table.insert(rows, panel.with_help(
                panel.gated_row("teleport_other",
                    OF.lang.fill("Tie @ to somebody else...", name),
                    180, 220, 255, function() panel.go("tie") end),
                OF.lang.t("two other players, tied to each other rather than to you")))
        end
    end

    local ridingMe = together.crewing(localIndex) == network_global_index_from_local(0)
    local ridingThem = together.crewing(0) == globalIndex
    if ridingMe then
        table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
            "uncrew" .. tostring(globalIndex),
            OF.lang.fill("Take @ off my Mario", name), 255, 180, 120, function()
                OF.util.report(OF.net.host_does("crew", globalIndex, nil))
            end), OF.lang.t("they get their own body and their own camera back")))
    elseif ridingThem then
        table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
            "uncrewme" .. tostring(globalIndex),
            OF.lang.fill("Stop steering @'s Mario", name), 255, 180, 120, function()
                OF.util.report(OF.net.host_does("crew",
                    network_global_index_from_local(0), nil))
            end), OF.lang.t("you get your own body and your own camera back")))
    else
        table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
            "crew" .. tostring(globalIndex),
            OF.lang.fill("Put @ on my Mario", name), 180, 220, 255, function()
                OF.util.report(OF.net.host_does("crew", globalIndex,
                    network_global_index_from_local(0)))
            end), OF.lang.t("their stick is added to yours and the sum is capped; any one press counts")))
        table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
            "crewme" .. tostring(globalIndex),
            OF.lang.fill("Steer @'s Mario", name), 180, 220, 255, function()
                OF.util.report(OF.net.host_does("crew",
                    network_global_index_from_local(0), globalIndex, "take"))
            end), OF.lang.t("you take their Mario over and see through it; yours stands still")))
    end

    local partner = together.bonded_to(localIndex)
    if partner ~= nil then
        local pi = OF.util.local_from_global(partner)
        local pname = pi ~= nil and gNetworkPlayers[pi] ~= nil
            and OF.util.plain(gNetworkPlayers[pi].name) or OF.lang.t("somebody")
        table.insert(rows, panel.with_help(panel.gated_confirm_row("share_health",
            "unbond" .. tostring(globalIndex),
            OF.lang.fill("Untie @'s health", name), 255, 180, 120, function()
                OF.util.report(OF.net.host_does("bond", globalIndex, nil))
            end), OF.lang.fill("@ and @ each get their own bar back", name, pname)))
    elseif #together.bond_candidates(localIndex) > 0 then
        table.insert(rows, panel.with_help(panel.gated_row("share_health",
            OF.lang.fill("Share @'s health bar with...", name), 180, 255, 200,
            function() panel.go("bond") end),
            OF.lang.t("pick a second player; the two of them get one bar at once")))
    end

    for slot = 1, together.SLOTS do
        local s = slots[slot]
        if s ~= nil then
            table.insert(rows, panel.with_help(panel.with_right(
                panel.gated_row("teleport_self",
                    OF.lang.fill("Hand @ your practice slot @", name, slot),
                    220, 220, 200, function()
                        if OF.util.report(together.hand_state(slot, globalIndex)) then
                            OF.notify.show(OF.lang.fill("Handed to @", name), "good", 3)
                        end
                    end),
                OF.util.level_name(s.level, s.area) or OF.lang.t("somewhere")),
                OF.lang.t("they get the place as an offer, and go there when they choose")))
        end
    end

    local caught = together.summary(localIndex)
    if caught ~= nil then
        table.insert(rows, panel.label_row("   " .. caught))
    end
    return rows
end

local function box(on)

    return OF.panel.tick(on, "")
end

function together.build_page(panel)
    local rows = {}

    table.insert(rows, panel.header_row(OF.lang.t("What players may do to each other")))
    table.insert(rows, panel.gated_row("rules",
        box(together.allows(together.STAND))
            .. OF.lang.t("Stand on each other"), 200, 220, 255,
        function()
            OF.util.report(together.set_switch(together.STAND,
                not together.allows(together.STAND)))
        end))
    rows[#rows] = panel.with_help(rows[#rows],
        OF.lang.t("a head becomes a floor - the lobby can build a ladder of itself"))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The rope")),
        "an invisible line between players that neither of them can walk past"))
    table.insert(rows, panel.gated_row("rules",
        box(together.allows(together.ROPE))
            .. OF.lang.t("Everybody roped together"), 200, 220, 255,
        function()
            OF.util.report(together.set_switch(together.ROPE,
                not together.allows(together.ROPE)))
        end))
    rows[#rows] = panel.with_help(rows[#rows],
        OF.lang.t("nobody in the lobby can get further from the rest than the rope"))

    local rope = together.rope_length()
    local steps = math.floor((together.ROPE_MAX - together.ROPE_MIN) / together.ROPE_STEP)
    local named = together.rope_name(rope)
    table.insert(rows, panel.with_right(panel.with_slider(
        panel.gated_row("rules",
            named ~= nil and OF.lang.fill("How far apart: @", OF.lang.t(named))
                or OF.lang.fill("How far apart: @", tostring(rope)),
            200, 220, 255, function()

                local wanted = together.ROPE_STOPS[1].units
                for _, stop in ipairs(together.ROPE_STOPS) do
                    if stop.units > rope then
                        wanted = stop.units
                        break
                    end
                end
                OF.util.report(together.set_rope(wanted))
            end),
        math.floor((rope - together.ROPE_MIN) / together.ROPE_STEP), steps,
        function(value)
            OF.util.report(together.set_rope(
                together.ROPE_MIN + value * together.ROPE_STEP))
        end), tostring(rope)))
    rows[#rows] = panel.with_help(rows[#rows],
        OF.lang.t("press for the next named length, drag for anything between"))

    local bite, biteAt = together.rope_bite()
    table.insert(rows, panel.with_help(panel.with_slider(
        panel.gated_row("rules",
            OF.lang.fill("At the end of the rope it: @", OF.lang.t(bite.name)),
            200, 220, 255,
            function() OF.util.report(together.set_bite(biteAt + 1)) end),
        biteAt - 1, #together.BITE_STOPS - 1,
        function(value) OF.util.report(together.set_bite(value + 1)) end),

        OF.lang.t("what the rope does to somebody who reaches the end of it")))

    table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
        "pairup", OF.lang.t("Tie the lobby into pairs"), 180, 220, 255,
        function()
            local ok, why, tied = together.pair_up()
            if OF.util.report(ok, why) and type(tied) == "number" then

                OF.notify.show("Tied the lobby into @ pair(s).", "info", 4,
                    tostring(tied))
            end
        end), OF.lang.t("two by two, in the order everybody already agrees about")))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
        "cutall", OF.lang.t("Cut every rope"), 255, 180, 120,
        function()
            local ok, why, cut = together.cut_all()
            if OF.util.report(ok, why) and type(cut) == "number" then
                OF.notify.show("Cut @ rope(s).", "info", 4, tostring(cut))

                if why ~= nil then OF.util.report(false, why) end
            end
        end),
        OF.lang.t("unties everybody at once, however they were tied")))
    table.insert(rows, panel.label_row(
        OF.lang.t("   Tie two players from a player's own page.")))

    table.insert(rows, panel.label_row(
        OF.lang.t("   To swap two players, open one of them in the list behind this page.")))

    if OF.util.asks(OF.swap, "build_timer_row") then
        local timer = OF.swap.build_timer_row(panel)
        if timer ~= nil then table.insert(rows, timer) end
    end

    table.insert(rows, panel.back_row())
    return rows
end

function together.build_practice(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.t("Save where you are standing, and drill the bit you keep losing.")))

    for slot = 1, together.SLOTS do
        local s = slots[slot]

        local text = OF.lang.fill("Slot @", tostring(slot))
        local held = s == nil and OF.lang.t("empty")
            or (OF.util.level_name(s.level, s.area) or OF.lang.t("somewhere"))
        local slotRow = panel.with_right(
            panel.gated_row("teleport_self", text, 220, 220, 200,
            function()
                if slots[slot] == nil then
                    OF.util.report(together.save_state(slot))
                else
                    OF.util.report(together.load_state(slot))
                end
            end), held)

        if slotRow.action ~= nil and s ~= nil then
            slotRow.altAction = function()
                OF.util.report(together.save_state(slot))
            end
        end
        table.insert(rows, panel.with_help(slotRow,
            s == nil and "stand where you want to come back to, and press"
                or "press to go there, tick to save over it"))
    end

    if together.received ~= nil then
        local got = together.received.state
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("teleport_self", OF.lang.t("The state you were handed"),
                220, 220, 200,
                function() OF.util.report(together.go_to_received()) end),
            OF.util.level_name(got.level, got.area) or OF.lang.t("somewhere")),
            OF.lang.t("press to go there - the place only, your meter stays yours")))
    end

    table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
        OF.lang.t("Put me back now"), 220, 220, 200,
        function() OF.util.report(together.reset()) end),
        "the drill's start, then a saved state, then the checkpoint"))

    local markStop, markIndex = together.mark_stop()
    table.insert(rows, panel.with_help(panel.with_slider(panel.with_right(
        panel.row(OF.lang.t("Remember where I last stood"), 220, 220, 200,
            function() OF.util.report(together.set_mark(markIndex + 1)) end),
        OF.lang.t(markStop.name)),
        markIndex - 1, #together.MARK_STOPS - 1,
        function(value) OF.util.report(together.set_mark(value + 1)) end),
        OF.lang.t("anything that ends your attempt puts you here, not at the door")))

    local kept = together.checkpoint()
    if kept ~= nil then
        table.insert(rows, panel.label_row(OF.lang.fill("   Kept in @",
            OF.util.level_name(kept.level, kept.area) or OF.lang.t("somewhere"))))
    end

    table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
        drill.from == nil and OF.lang.t("Start a drill here")
            or OF.lang.t("Move the drill's start here"), 220, 220, 200,
        function() OF.util.report(together.drill_start()) end),
        OF.lang.t("where the clock starts, and where you are put back to")))
    if drill.from ~= nil then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            OF.lang.t("The drill ends here"), 220, 220, 200,
            function() OF.util.report(together.drill_finish()) end),
            "where the clock stops - reaching it counts the frames it took"))
        local back, backAt = together.reload_stop()
        table.insert(rows, panel.with_help(panel.with_slider(
            panel.gated_row("teleport_self",
                OF.lang.fill("Put me back: @", OF.lang.t(back.name)),
                220, 220, 200,
                function() OF.util.report(together.set_reload(backAt + 1)) end),
            backAt - 1, #together.RELOAD_STOPS - 1,
            function(value) OF.util.report(together.set_reload(value + 1)) end),
            OF.lang.t("drill a landing without losing the run, or a survival without being sent back")))
        table.insert(rows, panel.label_row(OF.lang.fill("   Last @, best @",
            drill.last ~= nil and (tostring(drill.last) .. OF.lang.t(" frames"))
                or OF.lang.t("nothing yet"),
            drill.best ~= nil and (tostring(drill.best) .. OF.lang.t(" frames"))
                or OF.lang.t("nothing yet"))))
        table.insert(rows, panel.with_help(panel.confirm_row("drillclear",
            OF.lang.t("Forget the drill"), 255, 180, 120,
            function() OF.util.report(together.drill_clear()) end),
            OF.lang.t("takes the start, the finish and both times away")))
    end

    local may, why = together.can_freeze()
    if may then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            box(frozen) .. OF.lang.t("Stop time"), 220, 220, 200,
            function() OF.util.report(together.freeze(not frozen)) end),
            OF.lang.t("the level holds still so a landing can be read frame by frame")))
        if frozen then
            table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
                OF.lang.t("One frame"), 220, 220, 200,
                function() OF.util.report(together.step_frame()) end),
                OF.lang.t("lets exactly one frame through, then stops again")))
        end
    else
        table.insert(rows, panel.label_row("   " .. tostring(why)))
    end

    table.insert(rows, panel.back_row())
    return rows
end
