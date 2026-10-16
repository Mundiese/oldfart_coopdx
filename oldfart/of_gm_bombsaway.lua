OF = OF or {}

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local OUT_DROP = 400

local START_ACROSS = 1300
local WIDEST_ACROSS = 2000

local LANES = 4
local DROP_EVERY = 1.3
local FALL_SECONDS = 1.1
local BLAST_HOLD = 0.3
local DROP_HEIGHT = 800

local BLAST_GRACE = 1.0

local HIT_RADIUS = 230

local SHOCK_RADIUS = 340
local SHOCK_TRAVEL = 0.12

local THROW_BACK_MIN = 22
local THROW_BACK_MAX = 48
local THROW_UP_MIN = 26
local THROW_UP_MAX = 44

local BOOM_SCALE = 3.0
local BOOM_RING = 6
local BOOM_RING_SCALE = 1.6

local BOOM_RING_AT = 0.45

local SHOCK_STUN = 0.6

local SHOCK_IMMUNE = 1.0

local shellObjs = {}

local forget_booms = nil
hook_event(HOOK_ON_LEVEL_INIT, function()
    for lane in pairs(shellObjs) do shellObjs[lane] = nil end
    if forget_booms ~= nil then forget_booms() end
end)

local HASH_P = 1000003.0
local function seeded01(a, b, c, salt)
    local n = (a * 7919.0 + b * 104729.0 + c * 1299709.0 + (salt or 0) * 15485863.0) % HASH_P
    if n < 0 then n = n + HASH_P end
    n = (n * n + 7777.0) % HASH_P
    n = (n * 1103.0 + b * 31.0 + a) % HASH_P
    n = (n * n + 12345.0) % HASH_P
    return n / HASH_P
end

local LAND_SHARE = 0.96

local function landing_point(lane, drop, at, r)
    local sampleR = r * LAND_SHARE
    local angle = seeded01(lane, drop, 1, 0) * 2 * math.pi
    local out = math.sqrt(seeded01(lane, drop, 2, 0)) * sampleR
    return at.x + math.sin(angle) * out, at.z + math.cos(angle) * out
end

local function lane_cycle(lane, t)
    local phase = (lane == 1 and 0) or (lane == 2 and DROP_EVERY / 2)
        or (lane == 3 and 30 + DROP_EVERY / 4) or (60 + 3 * DROP_EVERY / 4)
    if t < phase then return nil end
    local since = t - phase
    local drop = math.floor(since / DROP_EVERY)
    return drop, since - drop * DROP_EVERY
end

local function fall_height(ground, localT)
    if localT >= FALL_SECONDS then return ground, true end
    local u = localT / FALL_SECONDS
    return ground + DROP_HEIGHT * (1 - u) * (1 - u), false
end

local function shell_state(lane, t, at, r)
    local drop, localT = lane_cycle(lane, t)
    if drop == nil then return nil end
    if localT > FALL_SECONDS + BLAST_HOLD then return nil end
    local lx, lz = landing_point(lane, drop, at, r)
    local ground = OF.util.optional("find_floor_height", nil,
        lx, at.y + 200, lz)
    if type(ground) ~= "number" then ground = at.y end
    local y, landed = fall_height(ground, localT)
    return lx, y, lz, landed, ground
end

local heardDrop, heardLanded = {}, {}

local function shell_at_me(lane, drop, at, r)
    if at == nil or r == nil or OF.ring.am_out() then return false end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    local lx, lz = landing_point(lane, drop, at, r)
    local dx, dz = m.pos.x - lx, m.pos.z - lz
    return dx * dx + dz * dz <= SHOCK_RADIUS * SHOCK_RADIUS
end

local function hear_shell(lane, t, obj, landed, at, r)
    local drop, localT = lane_cycle(lane, t)
    if drop == nil then return end
    local was = heardDrop[lane]
    heardDrop[lane] = drop
    if was ~= nil and drop ~= was and localT < 0.5 then
        heardLanded[lane] = false
        OF.gamemodes.round_sound_throttled("bombs" .. lane, 15,
            SOUND_OBJ_POUNDING_CANNON, obj)
        if shell_at_me(lane, drop, at, r) then
            OF.gamemodes.cue("hazard", nil, "bashell")
        end
    end
    if landed and heardLanded[lane] == false then
        OF.gamemodes.round_sound_throttled("boom" .. lane, 15,
            SOUND_GENERAL2_BOBOMB_EXPLOSION, obj)
    end
    if was ~= nil then heardLanded[lane] = landed end
end

local boomedDrop = {}

local booms, boomAge, boomScale = {}, {}, {}
local BOOM_FRAMES = 9

local BOOM_MOST = 42
forget_booms = function() booms, boomAge, boomScale = {}, {}, {} end

local function is_boom(o)
    if o == nil or o.activeFlags == 0 then return false end
    local has = OF.util.optional("obj_has_model_extended", nil, o, E_MODEL_EXPLOSION)
    return has == true or has == 1
end

local function one_boom(x, y, z, scale)
    if #booms >= BOOM_MOST then return end
    local o = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvStaticObject, E_MODEL_EXPLOSION, x, y, z, nil)
    if o == nil then return end
    OF.util.optional("obj_set_billboard", nil, o)
    OF.util.optional("obj_scale", nil, o, scale)
    o.oAnimState = 0
    o.oOpacity = 255
    booms[#booms + 1] = o
    boomAge[#boomAge + 1] = 0
    boomScale[#boomScale + 1] = scale
end

local function sweep_booms(all)
    local keep, keepAge, keepScale = {}, {}, {}
    for i, o in ipairs(booms) do
        local age = boomAge[i] + 1
        if all or age >= BOOM_FRAMES then
            if is_boom(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
        elseif is_boom(o) then
            o.oAnimState = age
            o.oOpacity = math.max(0, 255 - 14 * age)
            OF.util.optional("obj_scale", nil, o, (age / BOOM_FRAMES + 1) * boomScale[i])
            keep[#keep + 1] = o
            keepAge[#keepAge + 1] = age
            keepScale[#keepScale + 1] = boomScale[i]
        end
    end
    booms, boomAge, boomScale = keep, keepAge, keepScale
end

local function explode(lane, drop, x, y, z)
    if boomedDrop[lane] == drop then return end
    boomedDrop[lane] = drop
    one_boom(x, y + 60, z, BOOM_SCALE)
    local out = HIT_RADIUS * BOOM_RING_AT
    for k = 0, BOOM_RING - 1 do
        local a = (k + lane * 0.5) * 2 * math.pi / BOOM_RING
        one_boom(x + math.sin(a) * out, y + 40, z + math.cos(a) * out, BOOM_RING_SCALE)
    end
    OF.util.optional("set_camera_shake_from_point", nil, SHAKE_POS_LARGE, x, y, z)
end

local function move_shells(at, r)
    if at == nil then return end
    sweep_booms(false)
    local t = OF.gamemodes.since_start()
    for lane = 1, LANES do
        local x, y, z, landed = shell_state(lane, t, at, r)
        local obj = shellObjs[lane]

        if x ~= nil and landed then
            explode(lane, (lane_cycle(lane, t)), x, y, z)
            hear_shell(lane, t, obj, landed, at, r)
            x = nil
        end
        if x == nil then
            if obj ~= nil then
                if obj.activeFlags ~= 0 then
                    OF.util.optional("obj_mark_for_deletion", nil, obj)
                end
                shellObjs[lane] = nil
            end
        else
            if obj == nil or obj.activeFlags == 0 then
                obj = OF.util.optional("spawn_non_sync_object", nil,
                    id_bhvStaticObject, E_MODEL_BOWLING_BALL, x, y, z, nil)
                shellObjs[lane] = obj
                if obj ~= nil then OF.util.optional("obj_set_billboard", nil, obj) end
            end
            if obj ~= nil then
                obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
            end
            hear_shell(lane, t, obj, landed, at, r)
        end
    end
end

local BANZAI_EVERY = 4.5
local BANZAI_CROSS = 3.0
local BANZAI_SCALE = 4.0
local BANZAI_REACH = 210
local BANZAI_HIGH = 140
local BANZAI_TALL = 330
local banzaiObj = nil
local banzaiHeard = nil

local function banzai_on()
    return OF.gamemodes.option_now("fire") == "banzai"
end

local function banzai_at(t, at, r)
    if at == nil or r == nil or t < BLAST_GRACE then return nil end
    local since = t - BLAST_GRACE
    local sweep = math.floor(since / BANZAI_EVERY)
    local into = since - sweep * BANZAI_EVERY
    if into > BANZAI_CROSS then return nil end
    local a = seeded01(7, sweep, 3, 0) * 2 * math.pi
    local off = (seeded01(7, sweep, 4, 0) * 2 - 1) * r * 0.6
    local reach = r + 400
    local u = into / BANZAI_CROSS
    local along = -reach + 2 * reach * u
    local fx, fz = math.sin(a), math.cos(a)
    local x = at.x + fx * along + fz * off
    local z = at.z + fz * along - fx * off
    return x, at.y + BANZAI_HIGH, z, a, sweep
end

local function run_over(m, at, r, t)
    if m == nil or m.pos == nil or not banzai_on() then return false end
    local x, y, z = banzai_at(t, at, r)
    if x == nil then return false end
    local dx, dz = m.pos.x - x, m.pos.z - z
    return dx * dx + dz * dz <= BANZAI_REACH * BANZAI_REACH
        and m.pos.y < y + BANZAI_TALL - BANZAI_HIGH and m.pos.y + 160 > y - BANZAI_HIGH
end

local function clear_banzai()
    if banzaiObj ~= nil and banzaiObj.activeFlags ~= 0 then
        OF.util.optional("obj_mark_for_deletion", nil, banzaiObj)
    end
    banzaiObj, banzaiHeard = nil, nil
end

local function move_banzai(at, r)
    local x, y, z, a, sweep = banzai_at(OF.gamemodes.since_start(), at, r)
    if x == nil then
        clear_banzai()
        return nil
    end
    if banzaiObj == nil or banzaiObj.activeFlags == 0 then
        banzaiObj = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_BULLET_BILL, x, y, z, nil)
        if banzaiObj ~= nil then OF.util.optional("obj_scale", nil, banzaiObj, BANZAI_SCALE) end
    end
    if banzaiObj ~= nil then
        banzaiObj.oPosX, banzaiObj.oPosY, banzaiObj.oPosZ = x, y, z
        local yaw = math.floor(a * 0x8000 / math.pi) % 0x10000
        banzaiObj.oFaceAngleYaw, banzaiObj.oMoveAngleYaw = yaw, yaw
    end
    if banzaiHeard ~= sweep then
        banzaiHeard = sweep
        OF.gamemodes.round_sound_throttled("banzai", 15, SOUND_OBJ_POUNDING_CANNON, banzaiObj)
    end
    return banzaiObj
end

local function clear_shells()
    for lane, obj in pairs(shellObjs) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        shellObjs[lane] = nil
    end
end

local function caught_in_blast(m, at, r, t)
    if m == nil or m.pos == nil then return false end
    if t < BLAST_GRACE then return false end
    for lane = 1, LANES do
        local x, y, z, landed = shell_state(lane, t, at, r)
        if x ~= nil and landed then
            local dx, dz = m.pos.x - x, m.pos.z - z
            if math.sqrt(dx * dx + dz * dz) <= HIT_RADIUS then
                return true
            end
        end
    end
    return false
end

local function shock_front(tau)
    if tau < 0 or tau > BLAST_HOLD then return nil end
    if tau >= SHOCK_TRAVEL then return SHOCK_RADIUS end
    return HIT_RADIUS + (SHOCK_RADIUS - HIT_RADIUS) * (tau / SHOCK_TRAVEL)
end

local stunUntil = 0
local stunFreeAt = 0
local waveSeen = {}

local function forget_stun()
    stunUntil = 0
    stunFreeAt = 0
    waveSeen = {}
end

local function throw_from(m, lx, lz, away)
    if m == nil or m.pos == nil then return end
    local share = 1 - (away - HIT_RADIUS) / (SHOCK_RADIUS - HIT_RADIUS)
    share = OF.util.clamp(share, 0, 1)
    local toward = math.atan(lx - m.pos.x, lz - m.pos.z)
    m.faceAngle.y = math.floor(toward * 0x8000 / math.pi)
    OF.util.optional("set_mario_action", nil, m, ACT_THROWN_BACKWARD, 1)
    m.forwardVel = -(THROW_BACK_MIN + (THROW_BACK_MAX - THROW_BACK_MIN) * share)
    m.vel.y = THROW_UP_MIN + (THROW_UP_MAX - THROW_UP_MIN) * share
end

local function shock_frame(m, at, r, t)
    if m == nil or m.pos == nil or at == nil then return false end
    if t < BLAST_GRACE then return t < stunUntil end

    local airborne = OF.util.has_flag(m.action, ACT_FLAG_AIR)

    for lane = 1, LANES do
        local drop, localT = lane_cycle(lane, t)
        if drop ~= nil and waveSeen[lane] ~= drop then
            local front = shock_front(localT - FALL_SECONDS)
            if front ~= nil then
                local lx, lz = landing_point(lane, drop, at, r)
                local dx, dz = m.pos.x - lx, m.pos.z - lz
                local away = math.sqrt(dx * dx + dz * dz)
                if away <= front then

                    waveSeen[lane] = drop

                    if away > HIT_RADIUS and not airborne
                        and t >= stunFreeAt then
                        stunUntil = t + SHOCK_STUN
                        stunFreeAt = stunUntil + SHOCK_IMMUNE
                        throw_from(m, lx, lz, away)

                        OF.gamemodes.cue("bad", nil, "bawave")
                    end
                end
            end
        end
    end

    return t < stunUntil
end

local function fell_in(m, at)
    if at == nil or m == nil or m.pos == nil then return false end
    return m.pos.y < at.y - OUT_DROP
end

local ROLE_OUT = "out"
local mode = {
    key = "bombsaway",
    resultsBy = "survival",
    name = "Shell Shower",
    blurb = "a ship shells the island - dodge, or ride out the clock",

    how = "An island in the sea, and a ship is shelling it.\n"
        .. "Shells fall on the island itself, never aimed at you.\n"
        .. "Caught under one and you are out - no second chance.\n"
        .. "A near miss sends a wave out along the ground.\n"
        .. "Jump it and nothing happens; stand and it holds you.\n"
        .. "Step past the edge and you have seconds to get back.\n"
        .. "Slide off below it and that is out too, on the spot.\n"
        .. "Last one on the island wins.\n"
        .. "On the clock, everybody still standing on it.",
    minPlayers = 2,

    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 90,
    saysOut = true,

    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_WATER,

    target = { name = "island width",
               asks = "Island width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 500, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,

    options = {
        { key = "size", name = "Island size",
          help = "how big the island starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual island, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller island - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger island - more room to run" },
          } },
        { key = "fire", name = "What the ship fires",
          help = "shells on the island, or one huge sweep across it",
          choices = {
              { key = "shells", name = "shells",
                help = "they land anywhere - a direct hit is out" },
              { key = "banzai", name = "a Banzai Bill",
                help = "a huge Bill sweeps across - it flies too low to jump" },
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
        OF.ring.set_opening(options.target)
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
    forget_stun()
    boomedDrop = {}
end

function mode.before_mario_update(m)

    if not OF.util.round_screen() then
        clear_shells()
        clear_banzai()
        sweep_booms(true)
        return
    end

    if banzai_on() then
        clear_shells()
        move_banzai(OF.ring.at(), OF.ring.radius())
    else
        clear_banzai()
        move_shells(OF.ring.at(), OF.ring.radius())
    end
    OF.ring.tick_window()
    if OF.ring.am_out() then

        forget_stun()
        OF.ring.watch_frame(m)
        return
    end

    if not OF.util.can_play(0) or OF.gamemodes.role(0) ~= OF.ring.ROLE_IN then
        forget_stun()
        return
    end

    if shock_frame(m, OF.ring.at(), OF.ring.radius(),
                   OF.gamemodes.since_start()) then
        OF.input.freeze(m)
    end
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local at = OF.ring.at()
    if at == nil then return end
    local r = OF.ring.radius()

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < 0x880 then m.health = 0x880 end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    local t = OF.gamemodes.since_start()

    if banzai_on() then
        if run_over(m, at, r, t) then
            OF.ring.go_out("Run over by the Banzai Bill")
            return
        end
    elseif caught_in_blast(m, at, r, t) then
        OF.ring.go_out("Caught in the blast")
        return
    end
    if fell_in(m, at) then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the island")
    end
end

function mode.host_update()

    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the island to shell.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("Everybody went in the sea.")
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
    clear_shells()
    clear_banzai()
    sweep_booms(true)
    boomedDrop = {}
    forget_stun()
    OF.ring.let_go()
end

function mode.terms()

    return OF.lang.fill("last one on a @ island under the shells",
        OF.lang.t(OF.gamemodes.option_showing("bombsaway", "size") or "normal"))
end

mode.lane_cycle = lane_cycle

function mode.boom_count() return #booms end

function mode.shell_position(lane)
    local at = OF.ring.at()
    if at == nil then return nil end
    local r = OF.ring.radius()
    return shell_state(lane, OF.gamemodes.since_start(), at, r)
end

mode.landing_point = landing_point

function mode.shock_front(lane)
    local t = OF.gamemodes.since_start()
    local _, localT = lane_cycle(lane, t)
    if localT == nil then return nil end
    return shock_front(localT - FALL_SECONDS)
end

function mode.banzai_at(t, at, r)
    return banzai_at(t, at, r)
end
function mode.run_over(m, at, r, t)
    return run_over(m, at, r, t)
end
mode.BANZAI_EVERY = BANZAI_EVERY
mode.BANZAI_CROSS = BANZAI_CROSS

function mode.stun_left()
    local t = OF.gamemodes.since_start()
    return math.max(0, stunUntil - t), math.max(0, stunFreeAt - t)
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == OF.ring.ROLE_OUT then return "SEA" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = OF.ring.at()
    local r = OF.ring.radius()

    if at ~= nil then
        local over = OF.ring.margin(0)
        local red, green, blue = 140, 180, 255
        if over ~= nil and over < 0 then red, green, blue = 255, 120, 120 end
        OF.util.zone_ring(at, r, 48, 4, red, green, blue, 220, "edge")

        local t = OF.gamemodes.since_start()
        for lane = 1, LANES do
            local x, y, z, landed = shell_state(lane, t, at, r)
            if x ~= nil and landed then

                OF.util.zone_ring({ x = x, y = y, z = z },
                    HIT_RADIUS, 24, 3, 255, 120, 60, 200)

                local _, localT = lane_cycle(lane, t)
                local front = localT ~= nil
                    and shock_front(localT - FALL_SECONDS) or nil
                if front ~= nil then
                    OF.util.zone_ring({ x = x, y = y, z = z },
                        front, 32, 2, 255, 220, 120, 200)
                end
            end
        end
    end

    if OF.ring.am_out() then
        OF.gamemodes.out_banner("In the sea")
        return
    end

    local over = OF.ring.margin(0)
    if over == nil then
        OF.gamemodes.away_banner("You are not in the island's area")
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local left = OF.ring.window_left(0)
    if left ~= nil then
        OF.hud.state_line("back", OF.lang.t("Back in"), { prio = 85, tone = "warn",
            urgent = true, figure = math.max(1, math.ceil(left)) })
    elseif OF.gamemodes.since_start() < stunUntil then
        OF.hud.state_line("held", OF.lang.t("Held"), { prio = 70, tone = "cold" })
    end
end

OF.gamemodes.register(mode)
