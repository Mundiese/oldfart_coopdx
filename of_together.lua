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
}
together.BITE_PLAIN = 1

together.TOSS_STOPS = {
    { name = "set them down",   push = 0 },
    { name = "a gentle toss",   push = 0.6 },
    { name = "a proper throw",  push = 1.0 },
    { name = "over the trees",  push = 1.6 },
    { name = "across the room", push = 2.4 },
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

function together.allows(bit)
    return OF.util.has_flag(together.switches(), bit)
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

    if np.currLevelNum ~= me.currLevelNum then return nil end
    if np.currAreaIndex ~= me.currAreaIndex then return nil end
    if not np.currAreaSyncValid or not me.currAreaSyncValid then return nil end

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
            if them ~= nil and them.pos ~= nil and may_hold(entry.localIndex) then
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
    drawn_here(m)
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

local function carrier_of(localIndex)
    local mine = network_global_index_from_local(localIndex)
    if mine == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= localIndex then
            local held = together.holding(entry.localIndex)
            if held ~= nil and held == mine then
                return network_global_index_from_local(entry.localIndex)
            end
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

function together.carry_point(carrier, passenger)
    local box = hold_height(carrier)

    local middle = carrier.pos.y + box * CARRY_LIFT

    local body = carrier.marioBodyState
    local stamp = body ~= nil and body.updateTorsoTime or nil
    local lift = middle
    if type(stamp) == "number" and body.torsoPos ~= nil
        and get_global_timer() - stamp <= TORSO_FRESH then

        lift = OF.util.clamp(body.torsoPos.y, carrier.pos.y, carrier.pos.y + box)
    end

    local wide = hold_radius(carrier)
    if passenger ~= nil then wide = math.max(wide, hold_radius(passenger)) end
    local reach = wide * 2 + CARRY_CLEAR + lean_along(carrier, carrier)
    if passenger ~= nil then
        reach = reach - lean_along(passenger, carrier)
    end
    return carrier.pos.x + reach * sins(carrier.faceAngle.y),
        lift,
        carrier.pos.z + reach * coss(carrier.faceAngle.y)
end

local carry_point = together.carry_point

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
    if together.holding(m.playerIndex) == nil then return end
    local pose = hold_pose(m)
    if pose ~= nil then set_character_animation(m, pose) end
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

        local push = together.toss().push or 1.0
        if speed > 4 and push > 0 then

            mario_set_forward_vel(m, math.min((14 + speed * 1.4) * push, 52))
            m.vel.y = 26 * math.min(push, 1.6)
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
        m.vel.x = m.vel.x - (dx / gap) * outward
        m.vel.z = m.vel.z - (dz / gap) * outward
        if m.forwardVel > 4 then mario_set_forward_vel(m, m.forwardVel * 0.5) end
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

local offers = {}

local askedBy = {}

function together.offered_to(globalIndex)
    globalIndex = tonumber(globalIndex)
    if globalIndex == nil or not askedBy[globalIndex] then return false end
    if together.bonded_to(0) ~= nil then return false end
    local at = OF.util.local_from_global(globalIndex)
    if at == nil or together.bonded_to(at) ~= nil then return false end
    return true
end

function together.forget_offer(globalIndex)
    if globalIndex == nil then askedBy = {} return end
    askedBy[tonumber(globalIndex)] = nil
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

local function keep_mark(m)
    local stop = together.mark_stop()
    if stop.every == nil then
        mark = nil
        return false
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

    if mark ~= nil then
        local dx, dy, dz = m.pos.x - mark.x, m.pos.y - mark.y, m.pos.z - mark.z
        if (dx * dx + dy * dy + dz * dz) < (stop.every * stop.every) then
            return false
        end
    end

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

    if perch.on ~= nil and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed, A_BUTTON) then
        leave_perch()
        return
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
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.pos == nil then return end

    if m.playerIndex ~= 0 then carry_look(m); perch_look_remote(m); return end

    hold_bond(m)

    if OF.util.action_group(m.action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        leave_perch()
        return
    end

    local named = my_carrier()
    if named == nil then wriggled = nil end
    local carrier = (named ~= wriggled) and named or nil
    local hands = carrier ~= nil and together.still_there(carrier) or nil
    local jumped = m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed, A_BUTTON)

    if hands ~= nil and carrier_of(hands) ~= nil then
        carrier, hands = nil, nil
    end

    if hands ~= nil and not may_hold(hands) then carrier, hands = nil, nil end

    if carrier ~= nil and hands ~= nil and together.allows(together.CARRY)
        and not jumped then
        carriedBy = carrier
        leave_perch()
        local them = gMarioStates[hands]
        local x, y, z = carry_point(them, m)
        m.pos.x, m.pos.y, m.pos.z = x, y, z
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        mario_set_forward_vel(m, 0)
        m.faceAngle.y = them.faceAngle.y
        drawn_here(m)

        set_character_animation(m, CHAR_ANIM_BEING_GRABBED)
        return
    end

    if carrier ~= nil and jumped then wriggled = carrier end

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
        local grabbed = together.grabbing(m)
        if grabbed ~= nil and together.still_there(grabbed) ~= nil then
            publish_hold(grabbed)
        end
    end

    wear_hold_pose(m)

    if together.allows(together.STAND) and hold_perch(m) then perch_look(m) end
    hold_rope(m)

    keep_mark(m)
end)

hook_event(HOOK_UPDATE, function()
    together.ready()
    hold_freeze()
    settle_restore()
    run_drill(gMarioStates[0])
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
    if together.perch_row(0) == network_global_index_from_local(m.playerIndex) then
        publish_perch(nil)
    end

    together.forget_offer(network_global_index_from_local(m.playerIndex))
    if not OF.util.is_host() then return end

    local gone = network_global_index_from_local(m.playerIndex)
    for _, entry in ipairs(OF.util.connected_players()) do
        if together.roped_to(entry.localIndex) == gone then
            OF.util.publish_row(entry.localIndex, "ofRope", nil)
        end
        if together.bonded_to(entry.localIndex) == gone then
            OF.util.publish_row(entry.localIndex, "ofBond", nil)
        end
    end
    OF.util.publish_row(m.playerIndex, "ofRope", nil)
    OF.util.publish_row(m.playerIndex, "ofBond", nil)

    offers[gone] = nil
    for asker, asked in pairs(offers) do
        if asked == gone then offers[asker] = nil end
    end
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
    return true, nil, cut
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

function together.pact(fromGlobal, toGlobal)
    if not OF.util.is_host() then return false, "Only the host." end
    local from = OF.util.local_from_global(tonumber(fromGlobal))
    local to = OF.util.local_from_global(tonumber(toGlobal))
    if from == nil or to == nil then return false, "They have left the lobby." end
    if from == to then return false, "Nobody can pair with themselves." end

    if together.bonded_to(from) == tonumber(toGlobal) then
        OF.util.publish_row(from, "ofBond", nil)
        OF.util.publish_row(to, "ofBond", nil)
        offers[tonumber(fromGlobal)] = nil
        offers[tonumber(toGlobal)] = nil
        OF.notify.send_to(tonumber(fromGlobal), "The pact is over", "info", 5)
        OF.notify.send_to(tonumber(toGlobal), "The pact is over", "info", 5)
        return true
    end

    if together.bonded_to(from) ~= nil or together.bonded_to(to) ~= nil then
        return false, "One of you is already paired."
    end

    if offers[tonumber(toGlobal)] == tonumber(fromGlobal) then
        offers[tonumber(toGlobal)] = nil
        offers[tonumber(fromGlobal)] = nil
        OF.util.publish_row(from, "ofBond", tonumber(toGlobal))
        OF.util.publish_row(to, "ofBond", tonumber(fromGlobal))
        OF.notify.send_to(tonumber(fromGlobal), "One bar between you now", "good", 6)
        OF.notify.send_to(tonumber(toGlobal), "One bar between you now", "good", 6)
        return true
    end

    offers[tonumber(fromGlobal)] = tonumber(toGlobal)
    local np = gNetworkPlayers[from]
    OF.notify.send_to(tonumber(toGlobal),
        "@ wants to share a health bar - offer back to accept", "info", 8,
        OF.util.plain(np ~= nil and np.name or ""))
    return true, "Asked them."
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

    OF.net.register_action("together", "settings", function(fromLocal, bit, on)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_switch(tonumber(bit), tonumber(on) == 1)
    end)

    OF.net.register_action("rope", "settings", function(fromLocal, units)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_rope(tonumber(units))
    end)

    OF.net.register_action("ropebite", "settings", function(fromLocal, at)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.set_bite(tonumber(at))
    end)

    OF.net.register_action("toss", "settings", function(fromLocal, at)
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

    OF.net.register_action("pact", "pact", function(fromLocal, who)
        if not OF.util.is_host() then return false, "Only the host." end
        return together.pact(network_global_index_from_local(fromLocal), tonumber(who))
    end)
end

function together.offer(localIndex)
    if localIndex == nil then return false, "Nobody by that name." end
    if not OF.perms.can("pact") then
        return false, "Your rank cannot do that.", "pact"
    end
    local globalIndex = network_global_index_from_local(localIndex)

    if together.bonded_to(0) == globalIndex then
        together.forget_offer(globalIndex)
        return OF.net.host_does("pact", globalIndex, 0)
    end
    local ok, why, needs = OF.net.host_does("pact", globalIndex, 0)

    if ok then askedBy[globalIndex] = true end
    return ok, why, needs
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

    local mine = together.bonded_to(0)
    local theirs = together.bonded_to(localIndex)
    if mine ~= nil and mine == globalIndex then
        table.insert(rows, panel.with_help(panel.gated_row("pact",
            OF.lang.fill("Leave the pact with @", name), 255, 180, 120,
            function() OF.util.report(together.offer(localIndex)) end),
            OF.lang.t("either of you can end it, and the other does not have to agree")))
    elseif mine == nil and theirs ~= nil
        and theirs ~= network_global_index_from_local(0) then

        table.insert(rows, panel.label_row(OF.lang.fill(
            "   @ already shares a bar with somebody else.", name), 170, 170, 170))
    elseif mine == nil then
        local waiting = together.offered_to(globalIndex)
        local share = panel.gated_row("pact",
            OF.lang.fill("Share one health bar with @", name), 180, 255, 200,
            function() OF.util.report(together.offer(localIndex)) end)

        if panel.with_right ~= nil and waiting then
            share = panel.with_right(share, OF.lang.t("asked"))
        end
        if panel.with_help ~= nil then
            share = panel.with_help(share, waiting
                and OF.lang.fill("a pact takes two - @ has to offer you the same", name)
                or OF.lang.t("a pact takes two: they have to offer you the same before one bar appears"))
        end
        table.insert(rows, share)
        if waiting then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "   Asked. Waiting for @ to offer back.", name), 255, 215, 0))
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
    table.insert(rows, panel.host_row("settings",
        box(together.allows(together.STAND))
            .. OF.lang.t("Stand on each other"), 200, 220, 255,
        function()
            OF.util.report(together.set_switch(together.STAND,
                not together.allows(together.STAND)))
        end))
    rows[#rows] = panel.with_help(rows[#rows],
        OF.lang.t("a head becomes a floor - the lobby can build a ladder of itself"))
    table.insert(rows, panel.host_row("settings",
        box(together.allows(together.CARRY))
            .. OF.lang.t("Pick each other up"), 200, 220, 255,
        function()
            OF.util.report(together.set_switch(together.CARRY,
                not together.allows(together.CARRY)))
        end))
    rows[#rows] = panel.with_help(rows[#rows],
        OF.lang.t("somebody can be carried, and thrown where they did not want to go"))

    local toss, tossAt = together.toss()
    table.insert(rows, panel.with_help(panel.with_slider(
        panel.host_row("settings",
            OF.lang.fill("A throw is: @", OF.lang.t(toss.name)), 200, 220, 255,
            function() OF.util.report(together.set_toss(tossAt + 1)) end),
        tossAt - 1, #together.TOSS_STOPS - 1,
        function(value) OF.util.report(together.set_toss(value + 1)) end),
        OF.lang.t("a carrier standing still sets you down at every stop")))

    table.insert(rows, panel.label_row(
        OF.lang.t("   Punch somebody to pick them up. B throws, A wriggles out.")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The rope")),
        "an invisible line between players that neither of them can walk past"))
    table.insert(rows, panel.host_row("settings",
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
        panel.host_row("settings",
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
        panel.host_row("settings",
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
            end
        end),
        OF.lang.t("unties everybody at once, however they were tied")))
    table.insert(rows, panel.label_row(
        OF.lang.t("   Tie two players from a player's own page.")))

    table.insert(rows, panel.label_row(
        OF.lang.t("   To swap two players, open one of them in the list behind this page.")))

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
            OF.lang.t("Takes the start, the finish and both times away.")))
    end

    local may, why = together.can_freeze()
    if may then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            box(frozen) .. OF.lang.t("Stop time"), 220, 220, 200,
            function() OF.util.report(together.freeze(not frozen)) end),
            OF.lang.t("The level holds still so a landing can be read frame by frame.")))
        if frozen then
            table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
                OF.lang.t("One frame"), 220, 220, 200,
                function() OF.util.report(together.step_frame()) end),
                OF.lang.t("Lets exactly one frame through, then stops again.")))
        end
    else
        table.insert(rows, panel.label_row("   " .. tostring(why)))
    end

    table.insert(rows, panel.back_row())
    return rows
end
