OF = OF or {}

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return { E_MODEL_CHAIN_CHOMP } end)

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local OUT_DROP = 400

local START_ACROSS = 1300
local WIDEST_ACROSS = 2000

local CHOMP_GRACE = 1.5

local CHOMP_SCALE = 1.0
local CHOMP_LIFT = 120 * CHOMP_SCALE

local BALL_RADIUS = 100
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100

local CHARGE_SPEED = 75
local SPIN_FRAMES = 30
local TELL_FRAMES = 12
local STUN_FRAMES = 30
local TURN_FRAMES = 8
local EDGE_KEEP = 80
local CHARGE_MOST = 90

local PHASE_SPIN, PHASE_TELL, PHASE_CHARGE, PHASE_STUN, PHASE_TURN = 0, 1, 2, 3, 4

local STRETCHES = 24

local MAX_CHOMPS = 4
local PER_CHOMP = 4
local CHOMP_COUNTS = { one = 1, two = 2, three = 3, four = 4 }

local function chomps_for(players, pick)
    local fixed = CHOMP_COUNTS[pick]
    if fixed ~= nil then return fixed end
    return math.max(1, math.min(MAX_CHOMPS, math.ceil((players or 1) / PER_CHOMP)))
end

local function shown_chomp_count()
    return OF.gamemodes.option_showing("chompfever", "chomps") or "crowd"
end

local CHOMP_KEY = "ofChompAt"
local SEND_EVERY = 10

local chompObjs = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    for i in pairs(chompObjs) do chompObjs[i] = nil end
end)

local heardText = nil
local heard = {}

local sim = {}
local simSend = 0

local function floor_under(x, z, at)
    local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
    if type(y) ~= "number" or y < at.y - 600 then return at.y end
    return y
end

local function clamp_in(x, z, at)
    local r = math.max(60, (OF.ring.radius() or 300) - EDGE_KEEP)
    local dx, dz = x - at.x, z - at.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d <= r then return x, z, false end
    return at.x + dx / d * r, at.z + dz / d * r, true
end

local function sim_reset()
    for i = #sim, 1, -1 do sim[i] = nil end
    simSend = 0
end

local red = {}
local function red_reset()
    for k = 0, STRETCHES - 1 do red[k] = nil end
end

local function stretch_of(x, z, at)
    local angle = math.atan(z - at.z, x - at.x)
    if angle < 0 then angle = angle + 2 * math.pi end
    return math.floor(angle / (2 * math.pi) * STRETCHES) % STRETCHES
end

local function yaw_to(s, x, z)
    return math.floor(math.atan(x - s.x, z - s.z) * 32768 / math.pi) % 65536
end

local function sim_place(count, at)
    sim_reset()
    red_reset()
    local r = (OF.ring.radius() or 300) * 0.35
    for i = 1, count do
        local a = (i - 1) / count * 2 * math.pi + 0.4
        local s = { x = at.x + math.sin(a) * r, z = at.z + math.cos(a) * r,
                    vx = 0, vz = 0, phase = PHASE_SPIN,
                    left = SPIN_FRAMES + (i - 1) * 10, yaw = 0, spun = 0 }
        s.yaw = yaw_to(s, at.x, at.z)
        sim[i] = s
    end
end

local function pick_target(index, at)
    local taken = {}
    for i, s in ipairs(sim) do
        if i ~= index and s.target ~= nil then taken[s.target] = true end
    end
    local free, any = {}, {}
    for _, entry in ipairs(OF.ring.pushable()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and OF.gamemodes.distance_to_place(at, entry.localIndex) ~= nil then
            table.insert(any, entry.localIndex)
            if not taken[entry.localIndex] then table.insert(free, entry.localIndex) end
        end
    end
    local pool = #free > 0 and free or any
    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function face_target(s, at)
    local m = s.target ~= nil and gMarioStates[s.target] or nil
    if m ~= nil and m.pos ~= nil then
        local dx, dz = m.pos.x - s.x, m.pos.z - s.z
        if dx * dx + dz * dz > 50 * 50 then s.yaw = yaw_to(s, m.pos.x, m.pos.z) end
    elseif at ~= nil then
        s.yaw = yaw_to(s, at.x, at.z)
    end
end

local function start_charge(s, at)
    local w = s.yaw * math.pi / 32768
    s.vx, s.vz = math.sin(w) * CHARGE_SPEED, math.cos(w) * CHARGE_SPEED
    s.phase, s.left = PHASE_CHARGE, CHARGE_MOST
end

local function sim_step(index, at)
    local s = sim[index]
    s.left = s.left - 1
    local changed = false
    if s.phase == PHASE_SPIN then
        s.vx, s.vz = 0, 0
        if s.target == nil then s.target = pick_target(index, at) end
        s.yaw = (s.yaw + math.floor(65536 / SPIN_FRAMES)) % 65536
        s.spun = (s.spun or 0) + math.floor(65536 / SPIN_FRAMES)
        if s.left <= 0 then

            s.target = s.target or pick_target(index, at)
            face_target(s, at)
            s.phase, s.left, changed = PHASE_TELL, TELL_FRAMES, true
        end
    elseif s.phase == PHASE_TELL then
        s.vx, s.vz = 0, 0
        if s.left <= 0 then
            start_charge(s, at)
            changed = true
        end
    elseif s.phase == PHASE_TURN then
        s.vx, s.vz = 0, 0
        if s.left <= 0 then
            face_target(s, at)
            start_charge(s, at)
            changed = true
        end
    elseif s.phase == PHASE_STUN then
        s.vx, s.vz = 0, 0
        if s.left <= 0 then

            if s.hit ~= nil then red[s.hit] = true end
            s.hit = nil
            s.target = pick_target(index, at)
            s.spun = 0
            s.phase, s.left, changed = PHASE_SPIN, SPIN_FRAMES, true
        end
    end

    local hit
    s.x, s.z, hit = clamp_in(s.x + s.vx, s.z + s.vz, at)
    if s.phase == PHASE_CHARGE and (hit or s.left <= 0) then
        s.vx, s.vz = 0, 0
        local k = stretch_of(s.x, s.z, at)
        if red[k] then

            s.target = pick_target(index, at)
            s.phase, s.left = PHASE_TURN, TURN_FRAMES
            face_target(s, at)
        else
            s.hit = k
            s.phase, s.left = PHASE_STUN, STUN_FRAMES
        end
        changed = true
    end
    return changed
end

local packParts = {}
local simSerial = 0

local function red_hex()
    local digits = {}
    for nibble = 0, STRETCHES / 4 - 1 do
        local v = 0
        for bit = 0, 3 do
            if red[nibble * 4 + bit] then v = v + 2 ^ bit end
        end
        digits[STRETCHES / 4 - nibble] = string.format("%x", math.floor(v))
    end
    return table.concat(digits)
end

local function pack_sim()
    for i = #packParts, 1, -1 do packParts[i] = nil end
    simSerial = (simSerial + 1) % 1000
    packParts[1] = string.format("%.0f", simSerial) .. ":" .. red_hex()
    for i, s in ipairs(sim) do
        packParts[i + 1] = string.format("%.0f %.0f %.0f %.0f %.0f %.0f", s.x, s.z,
            s.vx * 10, s.vz * 10, s.phase, s.yaw)
    end
    return table.concat(packParts, ";")
end

local NUM = "(%-?%d+)"
local ONE = "^" .. NUM .. " " .. NUM .. " " .. NUM .. " " .. NUM .. " " .. NUM
    .. " " .. NUM .. "$"
local quietFor = 0
local QUIET_MOST = 2 * SEND_EVERY

local heardRed = {}

local SPIN_HOP_FRAMES = 10
local SOUND_SPIN = SOUND_GENERAL_CHAIN_CHOMP1
local SOUND_CHARGE = SOUND_GENERAL_CHAIN_CHOMP2
local SOUND_WALL = SOUND_OBJ_THWOMP
local SOUND_BREAK = SOUND_GENERAL_WALL_EXPLOSION
local SOUND_BITE = SOUND_OBJ2_PIRANHA_PLANT_BITE

local function phase_sound(index, was, now)
    local obj = chompObjs[index]
    if obj ~= nil and obj.activeFlags == 0 then obj = nil end
    local sound = nil
    if now == PHASE_CHARGE then
        sound = SOUND_CHARGE
    elseif now == PHASE_STUN then
        sound = SOUND_WALL
    elseif was == PHASE_STUN and now == PHASE_SPIN then
        sound = SOUND_BREAK
    elseif now == PHASE_TURN then
        sound = SOUND_SPIN
    end
    if sound == nil then return nil end
    return OF.gamemodes.round_sound_throttled("chomp" .. index .. ":" .. now, 4, sound, obj)
end

local AIM_LANE = BALL_RADIUS * CHOMP_SCALE + 150

local function warn_if_mine(c)
    if c.phase ~= PHASE_TELL and c.phase ~= PHASE_TURN then return nil end
    if c.yaw == nil or OF.ring.am_out() or not OF.util.can_play(0) then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    local a = c.yaw * math.pi / 32768
    local dx, dz = m.pos.x - c.x, m.pos.z - c.z
    local ahead = dx * math.sin(a) + dz * math.cos(a)
    local aside = math.abs(dx * math.cos(a) - dz * math.sin(a))
    if ahead <= 0 or aside > AIM_LANE then return nil end
    return OF.gamemodes.cue("hazard", nil, "chompaim")
end

local function hear(text)
    heardText = text
    quietFor = 0
    local n = 0
    local mask = string.match(text or "", "^%d+:(%x+)")
    for k = 0, STRETCHES - 1 do heardRed[k] = nil end
    if mask ~= nil then
        local value = tonumber(mask, 16) or 0
        for k = 0, STRETCHES - 1 do
            if OF.util.has_flag(value, math.floor(2 ^ k)) then heardRed[k] = true end
        end
    end
    for part in string.gmatch(text or "", "[^;]+") do
        local x, z, vx, vz, phase, yaw = string.match(part, ONE)
        if x ~= nil and n < MAX_CHOMPS then
            n = n + 1
            local c = heard[n] or {}
            local was = c.phase
            c.x, c.z = tonumber(x), tonumber(z)
            c.vx, c.vz = tonumber(vx) / 10, tonumber(vz) / 10
            c.phase = tonumber(phase)
            c.yaw = tonumber(yaw)
            heard[n] = c
            if was ~= nil and was ~= c.phase then
                phase_sound(n, was, c.phase)
                warn_if_mine(c)
            end
        end
    end
    for i = #heard, n + 1, -1 do heard[i] = nil end
end

local function carry(at)

    local text = OF.gamemodes.stream_read(CHOMP_KEY)
    if type(text) ~= "string" then text = nil end
    if text ~= heardText then
        hear(text)
        return
    end
    quietFor = quietFor + 1
    if quietFor > QUIET_MOST then return end
    for _, c in ipairs(heard) do
        c.x, c.z = clamp_in(c.x + c.vx, c.z + c.vz, at)
        if c.phase == PHASE_SPIN and c.yaw ~= nil then
            c.yaw = (c.yaw + math.floor(65536 / SPIN_FRAMES)) % 65536
        end
    end
end

local function chomp_at(index, at)
    local c = heard[index]
    if c == nil then return nil end
    return c.x, floor_under(c.x, c.z, at), c.z
end

local function move_chomps(at)
    if at == nil then return end
    carry(at)
    for index, c in ipairs(heard) do
        local x, y, z = chomp_at(index, at)
        local obj = chompObjs[index]
        if obj == nil or obj.activeFlags == 0 then
            obj = OF.slots.spawn_non_sync(
                id_bhvStaticObject, E_MODEL_CHAIN_CHOMP, x, y, z, nil, true)
            chompObjs[index] = obj
            if obj ~= nil then
                OF.util.optional("obj_scale", nil, obj, CHOMP_SCALE)
                obj.oGraphYOffset = CHOMP_LIFT
                if gObjectAnimations ~= nil
                    and gObjectAnimations.chain_chomp_seg6_anims_06025178 ~= nil then
                    obj.oAnimations = gObjectAnimations.chain_chomp_seg6_anims_06025178
                    OF.util.optional("obj_init_animation_with_accel_and_sound", nil,
                        obj, 0, 1.0)
                end
            end
        end
        if obj ~= nil then
            obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z

            if c.yaw ~= nil then
                obj.oFaceAngleYaw = math.floor(c.yaw)
                obj.oMoveAngleYaw = obj.oFaceAngleYaw
            end

            if c.phase == PHASE_STUN then
                obj.oPosY = y + math.abs(math.sin(OF.gamemodes.since_start() * 20)) * 15
            end

            if c.phase == PHASE_SPIN then
                OF.gamemodes.round_sound_throttled("chompspin" .. index,
                    SPIN_HOP_FRAMES, SOUND_SPIN, obj)
            end
        end
    end
    for index = #heard + 1, MAX_CHOMPS do
        local obj = chompObjs[index]
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        chompObjs[index] = nil
    end
end

local function clear_chomps()
    for index, obj in pairs(chompObjs) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        chompObjs[index] = nil
    end
    heardText = nil
    for i = #heard, 1, -1 do heard[i] = nil end
    for k = 0, STRETCHES - 1 do heardRed[k] = nil end
end

local function ball_of(index, at)
    local obj = chompObjs[index]
    if obj ~= nil and obj.activeFlags ~= 0 then
        local scale = CHOMP_SCALE
        if obj.header ~= nil and obj.header.gfx ~= nil and obj.header.gfx.scale ~= nil then
            scale = obj.header.gfx.scale.x or scale
        end
        return obj.oPosX, obj.oPosY + (obj.oGraphYOffset or 0), obj.oPosZ,
            BALL_RADIUS * scale
    end
    local x, y, z = chomp_at(index, at)
    if x == nil then return nil end
    return x, y + CHOMP_LIFT, z, BALL_RADIUS * CHOMP_SCALE
end

local function ball_touches(m, cx, cy, cz, r)
    local feet = m.pos.y
    local tall = MARIO_TALL
    if m.action ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0 then tall = MARIO_SHORT end
    local nearY = math.max(feet, math.min(feet + tall, cy))
    local dx, dy, dz = m.pos.x - cx, nearY - cy, m.pos.z - cz
    local reach = r + MARIO_RADIUS
    return dx * dx + dy * dy + dz * dz <= reach * reach
end

local function touched_by_chomp(m, at, t)
    if m == nil or m.pos == nil then return false end
    if t < CHOMP_GRACE then return false end
    for index = 1, #heard do
        local cx, cy, cz, r = ball_of(index, at)
        if cx ~= nil and ball_touches(m, cx, cy, cz, r) then return true end
    end
    return false
end

local function fell_in(m, at)
    if at == nil or m == nil or m.pos == nil then return false end
    return m.pos.y < at.y - OUT_DROP
end

local ROLE_OUT = "out"
local mode = {
    key = "chompfever",
    resultsBy = "survival",
    name = "Chomp Chase",
    blurb = "a Chain Chomp is loose on the platform - last one on it wins",

    how = "A platform over lava, with Chain Chomps loose on it.\n"
        .. "Each one spins, picks somebody, charges to the edge.\n"
        .. "It is stunned where it hits; that part turns red.\n"
        .. "Off a red part it turns at once and charges again.\n"
        .. "Touch one and you are out - no second chance.\n"
        .. "No jumping: step aside from a charge.\n"
        .. "Step past the edge and you have seconds to get back.\n"
        .. "Slide off below it and that is out too, on the spot.\n"
        .. "The platform narrows a little as the round runs,\n"
        .. "and more each time somebody goes out.\n"
        .. "How many Chomps are loose is set below.\n"
        .. "Last one on the platform wins.\n"
        .. "On the clock, everybody still standing on it.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "the_plate", "desert_cage", "aquarium" },

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 90,
    saysOut = true,

    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_BOSS_KOOPA,

    target = { name = "platform width",
               asks = "Platform width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 600, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,

    options = {
        { key = "size", name = "Platform size",
          help = "how big the platform starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual platform, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller platform - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger platform - more room to run" },
          } },

        { key = "chomps", name = "Chain Chomps",
          help = "one Chomp thins sixteen fast; more Chomps fixes that",
          choices = {
              { key = "crowd", name = "for the lobby",
                help = "one per four players: sixteen meet four" },
              { key = "one", name = "one",
                help = "the original count - plenty for a small lobby" },
              { key = "two", name = "two",
                help = "a fuller lobby, still space to breathe" },
              { key = "three", name = "three",
                help = "a full platform, nowhere quiet for long" },
              { key = "four", name = "four",
                help = "sixteen players and nowhere is safe for long" },
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
    sim_reset()
    clear_chomps()
end

function mode.takes_crouch(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if OF.gamemodes.current() ~= mode then return false end
    local state = OF.gamemodes.state()
    if state ~= OF.gamemodes.ACTIVE and state ~= OF.gamemodes.COUNTDOWN then return false end
    return OF.gamemodes.role(0) == OF.ring.ROLE_IN
end

function mode.before_mario_update(m)

    if OF.util.round_screen() then
        move_chomps(OF.ring.at())
    else
        clear_chomps()
    end
    OF.ring.tick_window()
    if OF.ring.am_out() then OF.ring.watch_frame(m) end
    if mode.takes_crouch(m) then OF.input.take(m, Z_TRIG) end
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local at = OF.ring.at()
    if at == nil then return end

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < 0x880 then m.health = 0x880 end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    local t = OF.gamemodes.since_start()

    if touched_by_chomp(m, at, t) then
        OF.gamemodes.round_sound(SOUND_BITE)
        OF.ring.go_out("Rammed by the Chain Chomp")
        return
    end
    if fell_in(m, at) then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the platform")
    end
end

local function run_chomps()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local at = OF.ring.at()
    if at == nil then return end
    if #sim == 0 then
        local players = #OF.ring.still_in()
        sim_place(chomps_for(players, OF.gamemodes.option_now("chomps")), at)
        OF.gamemodes.stream_send(CHOMP_KEY, pack_sim())
        return
    end
    if OF.gamemodes.since_start() < CHOMP_GRACE then return end
    local changed = false
    for index = 1, #sim do
        if sim_step(index, at) then changed = true end
    end
    simSend = simSend + 1
    if changed or simSend >= SEND_EVERY then
        simSend = 0
        OF.gamemodes.stream_send(CHOMP_KEY, pack_sim())
    end
end

function mode.host_update()
    OF.ring.close_frame()
    run_chomps()

    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the platform to threaten.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("Everybody went out.")
    end
end

mode.symmetric = true
function mode.overtime()
    return OF.ring.overtime(15)
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
    OF.gamemodes.finish(#standing == 1 and "Time - 1 player won." or "Time - @ players won.",
        { names = names }, tostring(#standing))
end

function mode.cleanup()
    clear_chomps()
    if OF.util.is_host() then OF.gamemodes.stream_send(CHOMP_KEY, nil) end
    sim_reset()
    OF.ring.let_go()
end

function mode.terms()
    local pick = shown_chomp_count()
    if CHOMP_COUNTS[pick] == nil then
        return OF.lang.t("last on the platform, a Chomp per four players")
    end
    return OF.lang.plural(CHOMP_COUNTS[pick], "last one on the platform, 1 Chain Chomp",
        "last one on the platform, @ Chain Chomps")
end

function mode.chomp_position(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return chomp_at(index, at)
end

function mode.chomp_state(index)
    local c = heard[index]
    if c == nil then return nil end
    return c.phase, c.vx, c.vz, c.yaw
end

mode.PHASES = { spin = PHASE_SPIN, tell = PHASE_TELL, charge = PHASE_CHARGE,
                stun = PHASE_STUN, turn = PHASE_TURN }
mode.STRETCHES = STRETCHES
mode.EDGE_KEEP = EDGE_KEEP
mode.BALL_RADIUS = BALL_RADIUS
mode.MARIO_RADIUS = MARIO_RADIUS

function mode.ball(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return ball_of(index, at)
end

function mode.red_stretches()
    local list = {}
    for k = 0, STRETCHES - 1 do
        if heardRed[k] then table.insert(list, k) end
    end
    return list
end

function mode.break_the_ring()
    for k = 0, STRETCHES - 1 do red[k] = true end
end

function mode.chomp_count()
    return #heard
end

mode.chomps_for = chomps_for

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == OF.ring.ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = OF.ring.at()

    if at ~= nil then
        local over = OF.ring.margin(0)
        local red, green, blue = 220, 140, 80
        if over ~= nil and over < 0 then red, green, blue = 255, 90, 90 end
        OF.util.zone_ring(at, OF.ring.radius(), 48, 4, red, green, blue, 220, "edge")

        local radius = OF.ring.radius()
        for k = 0, STRETCHES - 1 do
            if heardRed[k] then
                for part = 0, 2 do
                    local a0 = (k + part / 3) / STRETCHES * 2 * math.pi
                    local a1 = (k + (part + 1) / 3) / STRETCHES * 2 * math.pi
                    OF.util.world_line(
                        { x = at.x + math.cos(a0) * radius, y = at.y,
                          z = at.z + math.sin(a0) * radius },
                        { x = at.x + math.cos(a1) * radius, y = at.y,
                          z = at.z + math.sin(a1) * radius },
                        7, 255, 40, 40, 255)
                end
            end
        end
    end

    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

    local over = OF.ring.margin(0)
    if over == nil then
        OF.gamemodes.away_banner("You are not in the platform's area")
        return
    end

    local left = OF.ring.window_left(0)
    if left ~= nil and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("back", OF.lang.t("Back in"), { prio = 85, tone = "warn",
            urgent = true, figure = math.max(1, math.ceil(left)) })
    end
end

local JUMPS = nil
local function jump_set()
    if JUMPS == nil then
        JUMPS = {}
        for _, act in ipairs({ ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP,
                               ACT_LONG_JUMP, ACT_BACKFLIP, ACT_SIDE_FLIP,
                               ACT_STEEP_JUMP, ACT_HOLD_JUMP, ACT_WALL_KICK_AIR,
                               ACT_SPECIAL_TRIPLE_JUMP, ACT_FORWARD_ROLLOUT,
                               ACT_BACKWARD_ROLLOUT }) do
            if act ~= nil then JUMPS[act] = true end
        end
    end
    return JUMPS
end

local SWALLOWED = 1

function mode.instead_of_jump(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    if not jump_set()[action] then return nil end
    if OF.gamemodes.current() ~= mode then return nil end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    if OF.gamemodes.role(0) ~= OF.ring.ROLE_IN then return nil end
    return SWALLOWED
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return mode.instead_of_jump(m, action)
end)

OF.gamemodes.register(mode)
