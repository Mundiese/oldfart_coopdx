OF = OF or {}
OF.smashshield = OF.smashshield or {}
local shield = OF.smashshield

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local FLAG_STATIONARY = ACT_FLAG_STATIONARY or (1 << 9)
local FLAG_MOVING = ACT_FLAG_MOVING or (1 << 10)
local FLAG_AIR = ACT_FLAG_AIR or (1 << 11)
local FLAG_INTANGIBLE = ACT_FLAG_INTANGIBLE or (1 << 12)
local FLAG_CUSTOM = ACT_FLAG_CUSTOM_ACTION or (1 << 30)

shield.ACT_SHIELD = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY)
shield.ACT_DODGE = at_load("allocate_mario_action",
    (ACT_GROUP_MOVING or (1 << 6)) | FLAG_MOVING | FLAG_INTANGIBLE)
shield.ACT_AIRDODGE = at_load("allocate_mario_action",
    (ACT_GROUP_AIRBORNE or (2 << 6)) | FLAG_AIR | FLAG_INTANGIBLE)

shield.HP = 60
shield.DRAIN = 0.56
shield.REGEN = 0.14
shield.HIT_COST = 0.7

shield.AFTER_BREAK = 30
shield.BROKEN_FRAMES = 120

shield.STICK = 40
shield.REST = 24
shield.FLICK = 4

shield.DODGE_FRAMES = 10
shield.ROLL_SPEED = 28
shield.AIR_SPEED = 30
shield.AIR_FRAMES = 10
shield.STALE_WINDOW = 60
shield.STALE_STEP = 2
shield.STALE_MOST = 3

shield.SWING_FRAMES = 15

local ANIM_GUARD = MARIO_ANIM_FIRST_PERSON or 0xC0
local ANIM_SPOT = MARIO_ANIM_CROUCHING or 0x98
local ANIM_ROLL = MARIO_ANIM_FORWARD_SPINNING or 0x6A
local ANIM_AIR = MARIO_ANIM_FORWARD_SPINNING_FLIP or 0x6B

local st = {
    hp = 60,
    broken = 0,
    helpless = false,
    stickRest = 0,
    stickRestY = 0,
    lastDodge = -1000,
    stale = 0,
    clock = 0,
    swings = {},
    crouchHeld = false,
}

local function api()
    return OF.gm_smash_api
end

function shield.on()
    return OF.gamemodes.option_now("d") ~= "n"
end

function shield.state()
    return { hp = st.hp, broken = st.broken, helpless = st.helpless,
             stale = st.stale }
end

local function reset()
    st.hp = shield.HP
    st.broken = 0
    st.helpless = false
    st.stale = 0
    st.lastDodge = -1000
    st.swings = {}
    st.crouchHeld = false
end

function shield.dodge_frames()
    return math.max(4, shield.DODGE_FRAMES - shield.STALE_STEP * st.stale)
end

local function start_dodge(m, act, arg)
    if st.clock - st.lastDodge <= shield.STALE_WINDOW then
        st.stale = math.min(shield.STALE_MOST, st.stale + 1)
    else
        st.stale = 0
    end
    st.lastDodge = st.clock
    set_mario_action(m, act, arg or 0)
end

local function stick_yaw(m, sx, sy)
    local camYaw = 0
    if m.area ~= nil and m.area.camera ~= nil then camYaw = m.area.camera.yaw or 0 end
    return atan2s(-sy, sx) + camYaw
end

function shield.act_shield(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    OF.util.optional("stationary_ground_step", nil, m)
    OF.util.optional("set_mario_animation", nil, m, ANIM_GUARD)
    if m.playerIndex ~= 0 then return false end
    st.hp = st.hp - shield.DRAIN
    m.actionArg = math.max(0, math.floor(st.hp))
    if st.hp <= 0 then
        shield.break_it(m)
        return true
    end
    local c = m.controller
    local down = c ~= nil and (tonumber(c.buttonDown) or 0) or 0
    local pressed = c ~= nil and (tonumber(c.buttonPressed) or 0) or 0
    if OF.util.has_flag(pressed, A_BUTTON) then
        set_mario_action(m, ACT_JUMP, 0)
        return true
    end
    if not OF.util.has_flag(down, Z_TRIG) then
        set_mario_action(m, ACT_IDLE, 0)
        return true
    end

    return false
end

function shield.flick(m, sx, sy)
    if -sy >= shield.STICK and -sy >= math.abs(sx) and st.stickRestY <= shield.FLICK then
        start_dodge(m, shield.ACT_DODGE, 0)
        return true
    end
    if math.abs(sx) >= shield.STICK and st.stickRest <= shield.FLICK then
        m.faceAngle.y = stick_yaw(m, sx, 0)
        start_dodge(m, shield.ACT_DODGE, 1)
        return true
    end
    return false
end

function shield.act_dodge(m)
    local t = m.actionTimer or 0
    m.actionTimer = t + 1
    local rolling = (m.actionArg or 0) == 1
    if rolling then
        m.forwardVel = shield.ROLL_SPEED
        OF.util.optional("set_mario_animation", nil, m, ANIM_ROLL)
        if m.vel ~= nil then
            m.vel.x = shield.ROLL_SPEED * sins(m.faceAngle.y)
            m.vel.z = shield.ROLL_SPEED * coss(m.faceAngle.y)
        end
        OF.util.optional("perform_ground_step", nil, m)
    else
        m.forwardVel = 0
        if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
        OF.util.optional("set_mario_animation", nil, m, ANIM_SPOT)
        OF.util.optional("stationary_ground_step", nil, m)
    end
    if m.playerIndex ~= 0 then return false end
    if t >= shield.dodge_frames() then
        m.forwardVel = 0

        local c = m.controller
        local held = c ~= nil and OF.util.has_flag(tonumber(c.buttonDown) or 0, Z_TRIG)
        if held and st.broken <= 0 and shield.on() and st.hp > 0 then
            set_mario_action(m, shield.ACT_SHIELD, math.max(0, math.floor(st.hp)))
        else
            set_mario_action(m, ACT_IDLE, 0)
        end
        return true
    end
    return false
end

function shield.act_airdodge(m)
    local t = m.actionTimer or 0
    m.actionTimer = t + 1
    OF.util.optional("set_mario_animation", nil, m, ANIM_AIR)
    if t == 0 and m.vel ~= nil then

        local sx, sy = st.airX or 0, st.airY or 0
        local mag = math.sqrt(sx * sx + sy * sy)
        if m.playerIndex == 0 and mag >= shield.REST then
            local across, up = sx / mag, sy / mag
            local yaw = stick_yaw(m, 1, 0)
            m.vel.x = shield.AIR_SPEED * across * sins(yaw)
            m.vel.z = shield.AIR_SPEED * across * coss(yaw)
            m.vel.y = shield.AIR_SPEED * up
        else
            m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        end
        m.forwardVel = 0
    end
    if m.vel ~= nil then
        m.vel.x, m.vel.y, m.vel.z = m.vel.x * 0.9, m.vel.y * 0.9, m.vel.z * 0.9
    end
    local stepped = OF.util.optional("perform_air_step", nil, m, 0)
    if m.playerIndex ~= 0 then return false end
    if stepped == AIR_STEP_LANDED then
        st.helpless = false
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
        return true
    end
    if t >= shield.AIR_FRAMES then
        st.helpless = true
        set_mario_action(m, ACT_FREEFALL, 0)
        return true
    end
    return false
end

if shield.ACT_SHIELD ~= nil then
    at_load("hook_mario_action", shield.ACT_SHIELD, { every_frame = shield.act_shield })
end
if shield.ACT_DODGE ~= nil then
    at_load("hook_mario_action", shield.ACT_DODGE, { every_frame = shield.act_dodge })
end
if shield.ACT_AIRDODGE ~= nil then
    at_load("hook_mario_action", shield.ACT_AIRDODGE, { every_frame = shield.act_airdodge })
end

function shield.break_it(m)
    st.broken = shield.BROKEN_FRAMES
    st.hp = shield.AFTER_BREAK
    set_mario_action(m, ACT_IDLE, 0)
    local a = api()
    if a ~= nil and m ~= nil and m.pos ~= nil then
        if a.MOVES ~= nil and a.MOVES.shieldbreak == nil then
            a.MOVES.shieldbreak = { d = 0, bkb = 70, kbg = 0, angle = 90 }
        end
        a.take_hit({ pos = { x = m.pos.x, y = m.pos.y - 10, z = m.pos.z },
                     faceAngle = { y = m.faceAngle.y }, flags = 0 }, "shieldbreak", 0)
    end
    OF.notify.show("Shield broken", "bad", 3)
    OF.gamemodes.cue("bad", nil, "smashbreak")
    return true
end

shield.ACT_GRAB = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY)
shield.ACT_THROW = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY)
shield.ACT_HELD = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY)

shield.GRAB_REACH = 170
shield.GRAB_BEHIND = 40
shield.GRAB_UP = 160

shield.GRAB_WHIFF = 12

shield.HOLD_DIST = 110
shield.SWING_DIST = 150

shield.HOLD_BASE = 45
shield.HOLD_PER_PCT = 0.85
shield.HOLD_MOST = 120
shield.MASH_STEP = 4

shield.HOLD_CONFIRM = 24
shield.HOLD_LAG = 8

shield.THROW_RELEASE = 5
shield.THROW_AFTER = 10

shield.SWING_FRAMES = 24
shield.SWING_START = 0x0800
shield.SWING_TOP = 0x1C00

shield.ESCAPE_HOP = 22
shield.ESCAPE_PUSH = 14

shield.THROWS = { f = "fthrow", b = "bthrow", d = "dthrow", u = "uthrow" }
local THROW_ARG = { f = 1, b = 2, d = 3, u = 4 }
local THROW_OF_ARG = { [1] = "f", [2] = "b", [3] = "d", [4] = "u" }

local ANIM_REACH = MARIO_ANIM_GRAB_BOWSER or 0xB5
local ANIM_HOLD = MARIO_ANIM_HOLDING_BOWSER or 0xB8
local ANIM_SWING = MARIO_ANIM_SWINGING_BOWSER or 0xB6
local ANIM_RELEASE = MARIO_ANIM_RELEASE_BOWSER or 0xB7
local ANIM_THROW = MARIO_ANIM_GROUND_THROW or 0x65
local ANIM_HEAVY = MARIO_ANIM_HEAVY_THROW or 0x5A
local ANIM_SLAM = MARIO_ANIM_PLACE_LIGHT_OBJ or 0x6C
local ANIM_HELD = MARIO_ANIM_BEING_GRABBED or 0x58

local gr = { seq = 0, hold = nil, held = nil, seen = {} }

local function my_global()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex or nil
end

local function local_of(globalIndex)
    if globalIndex == nil then return nil end
    return OF.util.local_from_global(globalIndex)
end

function shield.hold_frames(pct)
    local f = shield.HOLD_BASE + shield.HOLD_PER_PCT * math.max(0, tonumber(pct) or 0)
    return math.floor(math.min(shield.HOLD_MOST, f))
end

function shield.grab_target(m)
    local a = api()
    if a == nil or m == nil or m.pos == nil then return nil end
    local me = gNetworkPlayers[0]
    local yaw = m.faceAngle.y or 0
    local fx, fz = sins(yaw), coss(yaw)
    local best, bestD = nil, nil
    for _, entry in ipairs(OF.gamemodes.with_role(a.ROLE_FIGHT)) do
        local i = entry.localIndex
        local o = gMarioStates[i]
        local np = gNetworkPlayers[i]
        if i ~= 0 and o ~= nil and o.pos ~= nil and np ~= nil and np.connected
            and OF.util.can_play(i) and me ~= nil
            and OF.util.same_world(i)
            and not OF.util.has_flag(o.action or 0, FLAG_INTANGIBLE)
            and o.action ~= shield.ACT_HELD then
            local dx, dz = o.pos.x - m.pos.x, o.pos.z - m.pos.z
            local ahead = dx * fx + dz * fz
            local side = math.abs(dx * fz - dz * fx)
            if ahead >= -shield.GRAB_BEHIND and ahead <= shield.GRAB_REACH
                and side <= shield.GRAB_REACH * 0.6
                and math.abs(o.pos.y - m.pos.y) <= shield.GRAB_UP then
                local d = dx * dx + dz * dz
                if bestD == nil or d < bestD then best, bestD = i, d end
            end
        end
    end
    return best
end

function shield.try_grab(m)
    if shield.ACT_GRAB == nil or m == nil then return nil end
    local target = shield.grab_target(m)
    local np = target ~= nil and gNetworkPlayers[target] or nil
    if np == nil or type(np.globalIndex) ~= "number" then
        gr.hold = nil
        set_mario_action(m, shield.ACT_GRAB, 0)
        return false
    end
    gr.seq = gr.seq + 1
    gr.hold = { global = np.globalIndex, seq = gr.seq, seen = false, lost = 0 }
    set_mario_action(m, shield.ACT_GRAB, np.globalIndex + 1)
    OF.util.publish_row(0, OF.smashitems.USE_KEY,
        "g:" .. tostring(np.globalIndex) .. ":" .. tostring(gr.seq))
    if OF.util.asks(OF.smashitems, "grab_sound") then OF.smashitems.grab_sound(m) end
    return target
end

local function holder_lets_go(m)
    gr.hold = nil
    set_mario_action(m, ACT_IDLE, 0)
    return true
end

function shield.act_grab(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    local t = (m.actionTimer or 0) + 1
    m.actionTimer = t
    OF.util.optional("set_mario_animation", nil, m, t <= 6 and ANIM_REACH or ANIM_HOLD)
    OF.util.optional("stationary_ground_step", nil, m)
    if m.playerIndex ~= 0 then return false end
    if (m.actionArg or 0) == 0 or gr.hold == nil then
        if t >= shield.GRAB_WHIFF then return holder_lets_go(m) end
        return false
    end
    local i = local_of(gr.hold.global)
    local o = i ~= nil and gMarioStates[i] or nil
    if o == nil then return holder_lets_go(m) end
    if o.action == shield.ACT_HELD then
        gr.hold.seen, gr.hold.lost = true, 0
    else
        gr.hold.lost = gr.hold.lost + 1
    end
    if not gr.hold.seen and t > shield.HOLD_CONFIRM then return holder_lets_go(m) end
    if gr.hold.seen and gr.hold.lost > shield.HOLD_LAG then return holder_lets_go(m) end
    if t > shield.HOLD_MOST + shield.HOLD_CONFIRM then return holder_lets_go(m) end
    return false
end

function shield.throw_dir(m, sx, sy)
    sx, sy = tonumber(sx) or 0, tonumber(sy) or 0
    if math.max(math.abs(sx), math.abs(sy)) < shield.STICK then return nil end
    if math.abs(sy) > math.abs(sx) then return sy > 0 and "u" or "d" end
    local dYaw = stick_yaw(m, sx, 0) - (m.faceAngle.y or 0)
    return coss(dYaw) >= 0 and "f" or "b"
end

function shield.throw(m, dir, sx)
    if gr.hold == nil or not gr.hold.seen or THROW_ARG[dir] == nil then return false end

    gr.hold.dir = dir
    gr.hold.yaw = m.faceAngle.y or 0
    if dir == "b" then gr.hold.yaw = stick_yaw(m, tonumber(sx) or 0, 0) end
    m.angleVel.y = shield.SWING_START
    set_mario_action(m, shield.ACT_THROW, THROW_ARG[dir])
    return true
end

local function release(m)
    local h = gr.hold
    if h == nil or h.released then return end
    h.released = true
    local yaw = h.yaw or (m.faceAngle.y or 0)
    yaw = math.floor(yaw) % 0x10000
    if yaw >= 0x8000 then yaw = yaw - 0x10000 end
    m.faceAngle.y = yaw
    OF.util.publish_row(0, OF.smashitems.USE_KEY, "t:" .. tostring(h.global) .. ":"
        .. tostring(h.seq) .. ":" .. h.dir .. ":" .. tostring(yaw))
    OF.util.optional("play_character_sound", nil, m,
        h.dir == "b" and (CHAR_SOUND_SO_LONGA_BOWSER or 0) or (CHAR_SOUND_HERE_WE_GO or 0))
end

function shield.act_throw(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    local t = (m.actionTimer or 0) + 1
    m.actionTimer = t
    local dir = THROW_OF_ARG[m.actionArg or 0] or "f"
    local letGo = shield.THROW_RELEASE
    if dir == "b" then
        letGo = shield.SWING_FRAMES
        if t < letGo then
            local share = t / shield.SWING_FRAMES
            m.angleVel.y = math.floor(shield.SWING_START
                + (shield.SWING_TOP - shield.SWING_START) * share)
            m.faceAngle.y = ((m.faceAngle.y or 0) + m.angleVel.y + 0x8000) % 0x10000 - 0x8000
            OF.util.optional("set_mario_animation", nil, m, ANIM_SWING)
        else
            m.angleVel.y = 0
            OF.util.optional("set_mario_animation", nil, m, ANIM_RELEASE)
        end
    elseif dir == "u" then
        OF.util.optional("set_mario_animation", nil, m, ANIM_HEAVY)
    elseif dir == "d" then
        OF.util.optional("set_mario_animation", nil, m, ANIM_SLAM)
    else
        OF.util.optional("set_mario_animation", nil, m, ANIM_THROW)
    end
    OF.util.optional("stationary_ground_step", nil, m)
    if m.playerIndex ~= 0 then return false end
    if t == letGo then release(m) end
    if t >= letGo + shield.THROW_AFTER then
        gr.hold = nil
        set_mario_action(m, ACT_IDLE, 0)
        return true
    end
    return false
end

function shield.held_spot(holder)
    local yaw = holder.faceAngle.y or 0
    local d = shield.HOLD_DIST
    if holder.action == shield.ACT_THROW and THROW_OF_ARG[holder.actionArg or 0] == "b" then
        d = shield.SWING_DIST
    end
    return holder.pos.x + d * sins(yaw), holder.pos.y, holder.pos.z + d * coss(yaw), yaw
end

local function break_free(m, why)
    gr.held = nil
    if m.playerIndex ~= 0 then return true end
    set_mario_action(m, ACT_FREEFALL, 0)
    if m.vel ~= nil then m.vel.y = shield.ESCAPE_HOP end
    m.forwardVel = -shield.ESCAPE_PUSH
    if why == "mash" then OF.gamemodes.cue("good", nil, "smashfree") end
    return true
end

function shield.act_held(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.y, m.vel.z = 0, 0, 0 end
    OF.util.optional("set_mario_animation", nil, m, ANIM_HELD)
    if m.playerIndex ~= 0 then return false end
    local h = gr.held
    local i = h ~= nil and local_of(h.global) or nil
    local holder = i ~= nil and gMarioStates[i] or nil
    if holder == nil or holder.pos == nil then return break_free(m, "gone") end
    if holder.action == shield.ACT_GRAB or holder.action == shield.ACT_THROW then
        h.lost = 0
    else
        h.lost = h.lost + 1
        if h.lost > shield.HOLD_LAG then return break_free(m, "dropped") end
    end
    local x, y, z, yaw = shield.held_spot(holder)
    m.pos.x, m.pos.y, m.pos.z = x, y, z
    m.faceAngle.y = ((yaw + 0x8000) + 0x8000) % 0x10000 - 0x8000

    if holder.action ~= shield.ACT_THROW then
        h.left = h.left - 1
        if h.left <= 0 then return break_free(m, "mash") end
    end
    return false
end

if shield.ACT_GRAB ~= nil then
    at_load("hook_mario_action", shield.ACT_GRAB, { every_frame = shield.act_grab })
end
if shield.ACT_THROW ~= nil then
    at_load("hook_mario_action", shield.ACT_THROW, { every_frame = shield.act_throw })
end
if shield.ACT_HELD ~= nil then
    at_load("hook_mario_action", shield.ACT_HELD, { every_frame = shield.act_held })
end

function shield.grabbed_by(holderLocal, holderGlobal, seq)
    local a = api()
    local m = gMarioStates[0]
    if a == nil or m == nil or shield.ACT_HELD == nil or not a.fighting() then return false end
    if a.grace() > 0 or gr.held ~= nil then return false end
    local act = m.action or 0
    if OF.util.has_flag(act, FLAG_INTANGIBLE) then return false end

    if act == shield.ACT_GRAB or act == shield.ACT_THROW then return false end
    local holder = gMarioStates[holderLocal]
    if holder == nil or holder.pos == nil or m.pos == nil then return false end

    local dx, dz = holder.pos.x - m.pos.x, holder.pos.z - m.pos.z
    local far = shield.GRAB_REACH * 2
    if dx * dx + dz * dz > far * far then return false end
    gr.held = { global = holderGlobal, seq = seq, lost = 0,
                left = shield.hold_frames(a.percent()) }
    set_mario_action(m, shield.ACT_HELD, 0)
    OF.gamemodes.cue("bad", nil, "smashgrabbed")
    return true
end

function shield.thrown(holderLocal, holderGlobal, seq, dir, yaw)
    local a = api()
    local m = gMarioStates[0]
    local h = gr.held
    if a == nil or m == nil or h == nil or shield.THROWS[dir] == nil then return nil end
    if h.global ~= holderGlobal or h.seq ~= seq or m.action ~= shield.ACT_HELD then return nil end
    local holder = gMarioStates[holderLocal]
    if holder == nil or holder.pos == nil then return nil end
    gr.held = nil

    local d = dir == "b" and shield.SWING_DIST or shield.HOLD_DIST
    m.pos.x = holder.pos.x + d * sins(yaw)
    m.pos.z = holder.pos.z + d * coss(yaw)
    m.pos.y = holder.pos.y
    if dir == "d" then

        if m.floorHeight ~= nil then m.pos.y = m.floorHeight end
        OF.gamemodes.round_sound(SOUND_ACTION_TERRAIN_HEAVY_LANDING or SOUND_GENERAL_BREAK_BOX)
    end
    local from = { pos = { x = holder.pos.x, y = holder.pos.y, z = holder.pos.z },
                   faceAngle = { y = yaw }, flags = 0 }
    return a.take_hit(from, shield.THROWS[dir], nil, holderGlobal)
end

function shield.read_holds()
    local me = my_global()
    for _, entry in ipairs(OF.util.connected_players()) do
        local who = entry.localIndex
        if who ~= 0 then
            local row = gPlayerSyncTable[who]
            local said = row ~= nil and row[OF.smashitems.USE_KEY] or ""
            if said == nil then said = "" end
            if type(said) == "string" then
                local first = gr.seen[who] == nil
                if said ~= gr.seen[who] then
                    gr.seen[who] = said
                    local by = entry.np ~= nil and entry.np.globalIndex or nil
                    if not first and me ~= nil and by ~= nil then
                        local g, n = string.match(said, "^g:(%d+):(%d+)$")
                        if tonumber(g) == me then
                            shield.grabbed_by(who, by, tonumber(n))
                        end
                        local tg, tn, dir, yaw = string.match(said, "^t:(%d+):(%d+):(%a):(%-?%d+)$")
                        if tonumber(tg) == me then
                            shield.thrown(who, by, tonumber(tn), dir, tonumber(yaw))
                        end
                    end
                end
            end
        end
    end
end

local function pad_while_grabbing(m, sx, sy, pressed)
    local act = m.action
    if act == shield.ACT_HELD and gr.held ~= nil then
        local n = 0
        for _, b in ipairs({ A_BUTTON, B_BUTTON, Z_TRIG }) do
            if b ~= nil and OF.util.has_flag(pressed, b) then n = n + 1 end
        end

        local outX, outY = math.abs(sx) >= shield.STICK, math.abs(sy) >= shield.STICK
        if outX and not gr.wasX then n = n + 1 end
        if outY and not gr.wasY then n = n + 1 end
        gr.wasX, gr.wasY = outX, outY
        gr.held.left = gr.held.left - shield.MASH_STEP * n
        return true
    end
    if act == shield.ACT_GRAB then
        local dir = shield.throw_dir(m, sx, sy)
        if dir ~= nil then shield.throw(m, dir, sx) end
        return true
    end
    return act == shield.ACT_THROW
end

function shield.grab_state()
    return { hold = gr.hold, held = gr.held, seq = gr.seq }
end

local function forget_grabs()
    gr.hold, gr.held, gr.seen = nil, nil, {}
end

local part = {}
OF.gm_smash_parts = OF.gm_smash_parts or {}
table.insert(OF.gm_smash_parts, part)

local function is_shielding(m)
    return m ~= nil and shield.ACT_SHIELD ~= nil and m.action == shield.ACT_SHIELD
end

function part.before_moveset(m)
    if not shield.on() or m == nil or m.controller == nil then return nil end
    local c = m.controller
    local sx = tonumber(c.stickX) or 0
    local sy = tonumber(c.stickY) or 0
    if math.abs(sx) < shield.REST then st.stickRest = 0
    elseif st.stickRest < 99 then st.stickRest = st.stickRest + 1 end
    if math.abs(sy) < shield.REST then st.stickRestY = 0
    elseif st.stickRestY < 99 then st.stickRestY = st.stickRestY + 1 end

    local act = m.action or 0
    local air = OF.util.has_flag(act, FLAG_AIR)
    if not air then st.helpless = false end

    if st.helpless and air then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, B_BUTTON)
        OF.input.take(m, Z_TRIG)
        if OF.util.has_flag(c.buttonPressed or 0, A_BUTTON) then
            c.buttonPressed = c.buttonPressed - A_BUTTON
        end
        return true
    end
    local pressed = tonumber(c.buttonPressed) or 0

    if (act == shield.ACT_GRAB or act == shield.ACT_HELD or act == shield.ACT_THROW)
        and act ~= nil then
        pad_while_grabbing(m, sx, sy, pressed)
        return true
    end
    if act == shield.ACT_SHIELD then

        if OF.util.has_flag(pressed, B_BUTTON) and shield.ACT_GRAB ~= nil then
            if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
            OF.input.take(m, B_BUTTON)
            shield.try_grab(m)
            return true
        end
        shield.flick(m, sx, sy)
        return true
    end
    if act == shield.ACT_DODGE or act == shield.ACT_AIRDODGE then
        return true
    end

    local down = tonumber(c.buttonDown) or 0
    local group = act & (ACT_GROUP_MASK or 0x1C0)
    local a = api()
    local busy = a ~= nil and a.hitstun() > 0
    if busy or m.heldObj ~= nil then return nil end

    local standing = group == (ACT_GROUP_STATIONARY or 0)
        and not OF.util.has_flag(act, FLAG_CUSTOM)
        and not OF.util.has_flag(act, FLAG_INTANGIBLE)

    local moving = group == (ACT_GROUP_MOVING or 0x40)
        and not OF.util.has_flag(act, FLAG_CUSTOM)
        and not OF.util.has_flag(act, FLAG_INTANGIBLE)
        and act ~= ACT_CROUCH_SLIDE
    local onFoot = standing or moving
    if onFoot and OF.util.has_flag(pressed, Z_TRIG) then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, Z_TRIG)

        if OF.util.has_flag(pressed, B_BUTTON) and shield.ACT_GRAB ~= nil then
            OF.input.take(m, B_BUTTON)
            shield.try_grab(m)
            return true
        end
        if st.broken <= 0 and shield.ACT_SHIELD ~= nil and act ~= ACT_CROUCHING
            and act ~= ACT_START_CROUCHING then
            set_mario_action(m, shield.ACT_SHIELD, math.floor(st.hp))

            c.buttonDown = OF.util.add_flag(c.buttonDown or 0, Z_TRIG)
        end
        return true
    end

    if onFoot and OF.util.has_flag(down, Z_TRIG) and st.broken <= 0
        and shield.ACT_SHIELD ~= nil and act ~= ACT_CROUCHING
        and act ~= ACT_START_CROUCHING and act ~= ACT_STOP_CROUCHING then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        set_mario_action(m, shield.ACT_SHIELD, math.floor(st.hp))
        return true
    end

    if air and OF.util.has_flag(pressed, Z_TRIG) and shield.ACT_AIRDODGE ~= nil
        and not (-sy >= shield.STICK and -sy >= math.abs(sx)) then

        if OF.util.has_flag(act, ACT_FLAG_ATTACKING or (1 << 23))
            or OF.util.has_flag(act, FLAG_CUSTOM) or act == ACT_GROUND_POUND then
            return nil
        end
        local moves = OF.util.asks(OF, "gm_smash_moveset") and OF.gm_smash_moveset() or nil
        if moves ~= nil and moves.helpless then return nil end
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, Z_TRIG)
        st.airX, st.airY = sx, sy
        start_dodge(m, shield.ACT_AIRDODGE, 0)
        return true
    end

    if onFoot and (OF.util.has_flag(down, Z_TRIG) or OF.util.has_flag(pressed, Z_TRIG)) then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, Z_TRIG)
    end
    local stickDown = -sy >= shield.STICK and -sy >= math.abs(sx)
    if stickDown and not OF.util.has_flag(pressed, B_BUTTON)
        and (standing or act == ACT_CROUCH_SLIDE) then
        if not st.crouchHeld then
            c.buttonPressed = OF.util.add_flag(c.buttonPressed or 0, Z_TRIG)
        end
        c.buttonDown = OF.util.add_flag(c.buttonDown or 0, Z_TRIG)
        st.crouchHeld = true
        return nil
    end
    st.crouchHeld = false
    return nil
end

function part.may_attack(attacker, victim)
    if not shield.on() or not is_shielding(victim) then return nil end
    if victim.playerIndex == 0 and attacker ~= nil then
        local key = attacker.playerIndex or -1
        local last = st.swings[key]
        if last == nil or last.action ~= attacker.action
            or st.clock - last.at > shield.SWING_FRAMES then
            st.swings[key] = { action = attacker.action, at = st.clock }
            local _, damage = OF.gm_smash_hit_of(attacker)
            shield.take(victim, damage)
        end
    end
    return false
end

function part.blocks(kind, damage)
    if not shield.on() then return nil end
    local m = gMarioStates[0]
    if not is_shielding(m) or kind == "shieldbreak" then return nil end
    shield.take(m, tonumber(damage) or 8)
    return true
end

function shield.take(m, damage)
    st.hp = st.hp - shield.HIT_COST * (tonumber(damage) or 0)
    OF.gamemodes.cue("tick", nil, "smashshield")
    if st.hp <= 0 and m ~= nil and m.playerIndex == 0 then
        shield.break_it(m)
        return true
    end
    if m ~= nil then m.actionArg = math.max(0, math.floor(st.hp)) end
    return false
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= (INTERACT_DAMAGE or (1 << 3)) then return end
    if OF.util.asks(OF.smashitems, "power_of") and OF.smashitems.power_of(0) == "s" then
        local a = api()
        if a ~= nil and a.fighting() then return false end
    end
    if not is_shielding(m) then return end
    local a = api()
    if a == nil or not a.fighting() or not shield.on() then return end
    if id_bhvExplosion == nil
        or OF.util.optional("obj_has_behavior_id", 0, o, id_bhvExplosion) ~= 1 then
        return
    end
    local key = "blast"
    local last = st.swings[key]
    if last == nil or st.clock - last.at > shield.SWING_FRAMES then
        st.swings[key] = { action = 0, at = st.clock }
        local d = a.MOVES ~= nil and a.MOVES.bomb ~= nil and a.MOVES.bomb.d or 20
        shield.take(m, d)
    end
    return false
end)

function part.update(m)
    st.clock = st.clock + 1
    if not is_shielding(m) and not (m ~= nil and m.action == shield.ACT_DODGE) then
        st.hp = math.min(shield.HP, st.hp + shield.REGEN)
    end
    if st.broken > 0 then st.broken = st.broken - 1 end
    return nil
end

local bubbles = {}

local BUBBLE_MARK = 0x5348D000
shield.BUBBLE_MARK = BUBBLE_MARK

local function is_my_bubble(b)
    if b == nil or not OF.util.alive(b) then return false end
    if b.activeFlags == nil or b.activeFlags == 0 then return false end
    if OF.util.optional("obj_has_behavior_id", 1, b, id_bhvStaticObject) == 0 then
        return false
    end
    local mark = tonumber(b.oBehParams) or 0
    return mark >= BUBBLE_MARK and mark < BUBBLE_MARK + 0x100
end
shield.is_my_bubble = is_my_bubble

local function drop_bubble(i)
    local b = bubbles[i]
    if b ~= nil and is_my_bubble(b) then
        OF.util.optional("obj_mark_for_deletion", nil, b)
    end
    bubbles[i] = nil
end

function shield.sweep_orphans()
    if id_bhvStaticObject == nil or OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return 0
    end
    local held = {}
    for _, b in pairs(bubbles) do held[b] = true end
    local gone = 0
    local o = obj_get_first_with_behavior_id(id_bhvStaticObject)
    local guard = 0
    while o ~= nil and guard < 2000 do
        guard = guard + 1
        local nextOne = obj_get_next_with_same_behavior_id(o)
        if not held[o] and is_my_bubble(o) then
            OF.util.optional("obj_mark_for_deletion", nil, o)
            gone = gone + 1
        end
        o = nextOne
    end
    return gone
end

function shield.bubble_scale(hp)
    local share = math.max(0, math.min(1, (tonumber(hp) or 0) / shield.HP))
    return 0.45 + 0.55 * share
end

local function drawn_here(i)
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    local m = gMarioStates[i]
    local np = gNetworkPlayers[i]
    if m == nil or m.pos == nil or np == nil or not np.connected then return false end
    if not is_shielding(m) then return false end
    if i == 0 then return true end
    local me = gNetworkPlayers[0]
    if me == nil then return false end
    if np.currAreaSyncValid == false then return false end

    return OF.util.same_world(i)
end
shield.drawn_here = drawn_here

function shield.keep(i)
    if not drawn_here(i) then
        if bubbles[i] ~= nil then drop_bubble(i) end
        return false
    end
    local m = gMarioStates[i]
    local b = bubbles[i]
    if b ~= nil and not is_my_bubble(b) then
        drop_bubble(i)
        b = nil
    end
    if b == nil then
        b = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_BUBBLE_PLAYER,
            m.pos.x, m.pos.y + 80, m.pos.z, nil, true)
        if b == nil then return false end
        b.oBehParams = BUBBLE_MARK + i
        bubbles[i] = b
    end
    b.oPosX, b.oPosY, b.oPosZ = m.pos.x, m.pos.y + 80, m.pos.z

    local gfx = b.header ~= nil and b.header.gfx or nil
    if gfx ~= nil and gfx.pos ~= nil then
        gfx.pos.x, gfx.pos.y, gfx.pos.z = b.oPosX, b.oPosY, b.oPosZ
    end
    OF.util.optional("obj_scale", nil, b, shield.bubble_scale(m.actionArg))
    return true
end

local sweepClock = 0

function shield.draw()
    local seen = {}
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        if shield.keep(i) then seen[i] = true end
    end
    for i in pairs(bubbles) do
        if not seen[i] then drop_bubble(i) end
    end
    sweepClock = sweepClock + 1
    if sweepClock >= 30 then
        sweepClock = 0
        shield.sweep_orphans()
    end
    return seen
end

function part.scenery()
    shield.draw()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then shield.read_holds() end
    return nil
end

function part.hud()
    local a = api()
    if a == nil or not a.fighting() then return nil end
    local lines = {
        OF.lang.t("Up or Down + B - specials"),
        OF.lang.t("Stick and A held - charged strike"),
    }
    if shield.on() then
        lines[#lines + 1] = OF.lang.t("Z - shield; flick the stick to dodge")
        lines[#lines + 1] = OF.lang.t("Z + B - grab; the stick throws")
        lines[#lines + 1] = OF.lang.t("Z in the air - air dodge")
        lines[#lines + 1] = OF.lang.t("Stick down - crouch")
    end
    OF.util.legend(lines)
    return nil
end

function shield.controls()
    local lines = {
        "Up or Down + B - specials",
        "Stick and A held - charged strike",
    }
    if shield.on() then
        lines[#lines + 1] = "Z - shield; flick the stick to dodge"
        lines[#lines + 1] = "Z in the air - air dodge"
        lines[#lines + 1] = "Z + B - grab; mash to break free"
        lines[#lines + 1] = "Stick forward - forward throw"
        lines[#lines + 1] = "Stick back - spin and throw"
        lines[#lines + 1] = "Stick down - slam throw"
        lines[#lines + 1] = "Stick up - up throw"
    end
    return lines
end
part.controls = shield.controls

local function leave(m)
    forget_grabs()
    if m ~= nil and m.action ~= nil and (m.action == shield.ACT_SHIELD
        or m.action == shield.ACT_DODGE or m.action == shield.ACT_GRAB
        or m.action == shield.ACT_THROW or m.action == shield.ACT_HELD) then
        set_mario_action(m, ACT_IDLE, 0)
    elseif m ~= nil and m.action == shield.ACT_AIRDODGE then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
end

function part.stock_lost()
    reset()
    gr.hold, gr.held = nil, nil
    return nil
end

function part.on_start()
    reset()
    forget_grabs()
    return nil
end

function part.cleanup()
    leave(gMarioStates[0])
    reset()
    for i in pairs(bubbles) do drop_bubble(i) end
    bubbles = {}
    shield.sweep_orphans()
    return nil
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    bubbles = {}
end)

function shield.ready()
    return shield.act_shield ~= nil and part.may_attack ~= nil
end
