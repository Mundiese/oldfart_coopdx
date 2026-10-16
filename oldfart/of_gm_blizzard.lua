OF = OF or {}
OF.ring = OF.ring or {}
OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local ROLE_IN = "in"
local ROLE_OUT = "out"
local START_ACROSS = 1000
local WIDEST_ACROSS = 1600
local OUT_DROP = 400

local THROWERS = 6
local WAKE = { 0, 0, 0, 8, 18, 28 }

local THROWER_IN = 0.9

local KEEP_CLEAR = 180
local THROWER_SCALE = 1.0
local GIANT_SCALE = 1.6

local PERIOD_LEAST, PERIOD_MOST = 2.0, 5.0

local PERIOD_FLOOR = 0.5

local WINDUP = 0.6

local FLIGHT = 1.2
local GIANT_FLIGHT = 1.7
local ARC = 450
local GIANT_ARC = 700
local RELEASE_HEIGHT = 180

local LEAD_FRAMES = 10
local SCATTER = 120

local HIT_RADIUS = 120
local GIANT_HIT_RADIUS = 300
local HIT_BELOW = 40
local HIT_ABOVE = 170

local HIT_FROM = 0.5

local WARN_REACH = 250
local HIT_AFTER = 0.1

local TEMPO_FULL = 60
local THROW_MOST = 0.6
local FLIGHT_MOST = 0.35

local SNOWMAN_ANIMS = "snowman_seg5_anims_0500D118"
local ANIM_SCOOP, ANIM_THROW = 0, 1
local THROW_LEAD = 7 / 30
local THROW_HOLD = 0.6
local STAND_OFFSET = 24

local GIANT_AT = { 15, 32, 48, 62, 74, 84 }

local THROWS_KEY = "ofBzThrows"
local WIRE_THROWS = 8

local BALL_SCALE = 2.5
local GIANT_BALL_SCALE = 1.4
local SHADOW_SCALE = 0.8

local SLICK = SURFACE_CLASS_VERY_SLIPPERY or 0x0014

local nextAt = {}
local nextId = 1
local nextGiant = 1
local sent = {}

local heard = {}
local wireSeen = nil

local balls, shades, statues = {}, {}, {}
local landed = {}

local thrown, warned = {}, {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    balls, shades, statues, landed = {}, {}, {}, {}
end)

local HASH_P = 1000003.0
local function seeded01(a, b, salt)
    local n = (a * 7919.0 + b * 104729.0 + (salt or 0) * 15485863.0) % HASH_P
    if n < 0 then n = n + HASH_P end
    n = (n * n + 7777.0) % HASH_P
    n = (n * 1103.0 + b * 31.0 + a) % HASH_P
    n = (n * n + 12345.0) % HASH_P
    return n / HASH_P
end

local function thrower_spot(k, at, r)
    local a = (k - 1) * 2 * math.pi / THROWERS
    local out = r * THROWER_IN
    return at.x + math.sin(a) * out, at.y, at.z + math.cos(a) * out
end

local function keep_radius(r)
    return math.max(200, r * THROWER_IN - KEEP_CLEAR)
end

local function keep_in(m, at, r)
    if at == nil or r == nil then return false end
    return OF.util.wall_in(m, at.x, at.z, keep_radius(r))
end

local function tempo_share(t)
    return math.min(math.max(t or 0, 0) / TEMPO_FULL, 1)
end

local function period_for(k, id, up, t)
    local base = PERIOD_LEAST + (PERIOD_MOST - PERIOD_LEAST) * seeded01(k, id, 3)
    local crowd = math.max(up or 0, 4) / 4
    local tempo = 1 + THROW_MOST * tempo_share(t)
    return math.max(base / crowd / tempo, PERIOD_FLOOR)
end

local function flight_of(throw)
    local base = throw.giant and GIANT_FLIGHT or FLIGHT
    return base / (1 + FLIGHT_MOST * tempo_share(throw.rel))
end

local function ball_at(throw, t, at, r)
    local sx, sy, sz = thrower_spot(throw.k, at, r)
    sy = sy + RELEASE_HEIGHT
    local flight = flight_of(throw)
    local arc = throw.giant and GIANT_ARC or ARC
    local u = (t - throw.rel) / flight
    if u <= 0 then return sx, sy, sz, u end
    local v = math.min(u, 1)
    local x = sx + (throw.x - sx) * v
    local z = sz + (throw.z - sz) * v
    local y = sy + (at.y - sy) * v + arc * 4 * v * (1 - v)
    return x, y, z, u
end

local function hits(throw, m, t, at, r)
    if m == nil or m.pos == nil then return false end
    local x, y, z, u = ball_at(throw, t, at, r)
    local flight = flight_of(throw)
    if u < HIT_FROM or u > 1 + HIT_AFTER / flight then return false end
    local reach = throw.giant and GIANT_HIT_RADIUS or HIT_RADIUS
    local dx, dz = m.pos.x - x, m.pos.z - z
    if dx * dx + dz * dz > reach * reach then return false end
    return y >= m.pos.y - HIT_BELOW and y <= m.pos.y + HIT_ABOVE + reach * 0.5
end

local function pack(list)
    local parts = {}
    for _, w in ipairs(list) do
        parts[#parts + 1] = string.format("%.0f %.0f %.0f %.0f %.0f %.0f",
            w.id, w.k, w.rel * 10, w.x, w.z, w.giant and 1 or 0)
    end
    return table.concat(parts, ";")
end

local function unpack_throws(text)
    local list = {}
    if type(text) ~= "string" then return list end
    for entry in string.gmatch(text, "[^;]+") do
        local n = {}
        for word in string.gmatch(entry, "%S+") do n[#n + 1] = tonumber(word) end
        if #n >= 6 and n[1] ~= nil then
            list[#list + 1] = { id = n[1], k = n[2] or 1, rel = (n[3] or 0) / 10,
                x = n[4] or 0, z = n[5] or 0, giant = n[6] == 1 }
        end
    end
    return list
end

local function listen()
    local wire = gGlobalSyncTable[THROWS_KEY]
    if wire == wireSeen then return end
    wireSeen = wire
    for _, w in ipairs(unpack_throws(wire)) do
        if heard[w.id] == nil then heard[w.id] = w end
    end
end

local function forget_old(t)
    for id, w in pairs(heard) do
        if t > w.rel + GIANT_FLIGHT + 1 then heard[id] = nil end
    end
end

local function targets()
    local list = {}
    for _, entry in ipairs(OF.ring.pushable()) do
        if entry.np ~= nil then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b) return a.np.globalIndex < b.np.globalIndex end)
    return list
end

local function throw(k, giant, t, at, r, list)
    if #list == 0 then return end
    local id = nextId
    nextId = nextId + 1
    local who = list[math.floor(seeded01(id, k, 1) * #list) + 1] or list[1]
    local m = gMarioStates[who.localIndex]
    if m == nil or m.pos == nil then return end
    local angle = seeded01(id, k, 2) * 2 * math.pi
    local off = math.sqrt(seeded01(id, k, 4)) * SCATTER
    local x = m.pos.x + (m.vel ~= nil and m.vel.x or 0) * LEAD_FRAMES + math.sin(angle) * off
    local z = m.pos.z + (m.vel ~= nil and m.vel.z or 0) * LEAD_FRAMES + math.cos(angle) * off

    local kr = keep_radius(r)
    local dx, dz = x - at.x, z - at.z
    local away = math.sqrt(dx * dx + dz * dz)
    if away > kr and away > 0 then
        x, z = at.x + dx / away * kr, at.z + dz / away * kr
    end
    sent[#sent + 1] = { id = id, k = k, rel = t + WINDUP, x = x, z = z, giant = giant }
    while #sent > WIRE_THROWS do table.remove(sent, 1) end
    OF.util.publish(THROWS_KEY, pack(sent))
end

local function host_forget()
    if not OF.util.is_host() then return end
    nextAt, nextId, nextGiant, sent = {}, 1, 1, {}
end

local function host_throw(t)
    if not OF.util.is_host() then return end
    local at, r = OF.ring.at(), OF.ring.radius()
    if at == nil or r == nil then return end
    local list = targets()
    for k = 1, THROWERS do
        if nextAt[k] == nil then
            nextAt[k] = WAKE[k] + seeded01(k, 0, 5) * PERIOD_LEAST
        end
        if t >= nextAt[k] then
            throw(k, false, t, at, r, list)
            nextAt[k] = t + period_for(k, nextId, #list, t)
        end
    end
    local g = GIANT_AT[nextGiant]
    if g ~= nil and t >= g then
        nextGiant = nextGiant + 1
        throw(((nextGiant - 1) % THROWERS) + 1, true, t, at, r, list)
    end
end

local function gone(o)
    return o == nil or o.activeFlags == 0
end

local function drop(o)
    if not gone(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function clear_all()
    for id, o in pairs(balls) do drop(o) balls[id] = nil end
    for id, o in pairs(shades) do drop(o) shades[id] = nil end
    for k, o in pairs(statues) do drop(o) statues[k] = nil end
    landed = {}
    thrown, warned = {}, {}
end

local function spawn(model, x, y, z)
    return OF.slots.spawn_non_sync(id_bhvStaticObject, model, x, y, z, nil)
end

local function pose(o)
    local anims = gObjectAnimations ~= nil and gObjectAnimations[SNOWMAN_ANIMS] or nil
    if anims == nil then return end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, ANIM_SCOOP, 1.0)
end

local function yaw_to(fx, fz, tx, tz)
    return math.floor(math.atan(tx - fx, tz - fz) * 32768 / math.pi) % 65536
end

local function draw(t, at, r)

    local facing = {}
    for _, w in pairs(heard) do
        local flight = flight_of(w)
        if t >= w.rel - WINDUP and t <= w.rel + flight then
            local was = facing[w.k]
            if was == nil or w.id > was.id then facing[w.k] = w end
        end
    end
    for k = 1, THROWERS do
        local x, y, z = thrower_spot(k, at, r)
        local o = statues[k]
        if t >= WAKE[k] then
            if gone(o) then
                o = spawn(E_MODEL_MR_BLIZZARD, x, y, z)
                statues[k] = o

                if o ~= nil then pose(o) end
            end
            if o ~= nil then
                o.oPosX, o.oPosY, o.oPosZ = x, y, z
                o.oGraphYOffset = STAND_OFFSET
                local w = facing[k]

                if o.oAnimations ~= nil then
                    local throwing = w ~= nil and t >= w.rel - THROW_LEAD
                        and t <= w.rel + THROW_HOLD
                    OF.util.optional("obj_init_animation_with_accel_and_sound", nil,
                        o, throwing and ANIM_THROW or ANIM_SCOOP, 1.0)
                end
                o.oFaceAngleYaw = w ~= nil and yaw_to(x, z, w.x, w.z)
                    or yaw_to(x, z, at.x, at.z)
                OF.util.optional("obj_scale", nil, o,
                    (w ~= nil and w.giant) and GIANT_SCALE or THROWER_SCALE)
            end
        elseif not gone(o) then
            drop(o)
            statues[k] = nil
        end
    end

    local m = gMarioStates[0]
    local mine = m ~= nil and m.pos ~= nil and not OF.ring.am_out()
        and OF.util.can_play(0)
    for id, w in pairs(heard) do
        if mine and not warned[id] and t >= w.rel - WINDUP and t < w.rel then
            warned[id] = true
            local reach = (w.giant and GIANT_HIT_RADIUS or HIT_RADIUS) + WARN_REACH
            local dx, dz = m.pos.x - w.x, m.pos.z - w.z
            if dx * dx + dz * dz <= reach * reach then
                OF.gamemodes.cue("hazard", nil, "bzaim")
            end
        end
        if not thrown[id] and t >= w.rel and t < w.rel + flight_of(w) then
            thrown[id] = true
            OF.gamemodes.round_sound_throttled("bzthrow" .. tostring(w.k), 6,
                SOUND_OBJ2_SCUTTLEBUG_ALERT, statues[w.k])
        end
    end

    for id, w in pairs(heard) do
        local x, y, z, u = ball_at(w, t, at, r)
        local live = u > -WINDUP / flight_of(w) and u < 1
        if live then
            local o = balls[id]
            if gone(o) then
                o = spawn(w.giant and E_MODEL_CCM_SNOWMAN_HEAD or E_MODEL_WHITE_PARTICLE,
                    x, y, z)
                balls[id] = o
                if o ~= nil and not w.giant then
                    OF.util.optional("obj_set_billboard", nil, o)
                end
            end
            if o ~= nil then
                o.oPosX, o.oPosY, o.oPosZ = x, y, z
                OF.util.optional("obj_scale", nil, o,
                    w.giant and GIANT_BALL_SCALE or BALL_SCALE)
            end
            if u > 0 and E_MODEL_WATER_BOMB_SHADOW ~= nil then
                local s = shades[id]
                if gone(s) then
                    s = spawn(E_MODEL_WATER_BOMB_SHADOW, x, y, z)
                    shades[id] = s
                end
                if s ~= nil then
                    s.oPosX, s.oPosY, s.oPosZ = x, y, z
                    OF.util.optional("obj_scale", nil, s,
                        SHADOW_SCALE * (w.giant and 2.5 or 1))
                end
            end
        else
            drop(balls[id])
            drop(shades[id])
            balls[id], shades[id] = nil, nil
            if u >= 1 and not landed[id] then
                landed[id] = true
                OF.gamemodes.round_sound_throttled("bzland", 3,
                    w.giant and SOUND_OBJ_SNOWMAN_EXPLODE or SOUND_OBJ_SNOW_SAND1, nil)
            end
        end
    end
end

local mode = {
    key = "blizzard",
    resultsBy = "survival",
    name = "Snowman Stakeout",
    blurb = "snowballs lobbed by Mr. Blizzards - one hit and you are out",
    aims = { [ROLE_IN] = "Dodge every snowball - one hit and you are out." },
    how = "Mr. Blizzards stand round the arena and lob snowballs.\n"
        .. "Each throw aims a little ahead of somebody.\n"
        .. "A snowball's shadow on the floor shows where it lands.\n"
        .. "One hit and you are out. A jump clears a landing ball.\n"
        .. "The floor is slick: stopping takes a while.\n"
        .. "The ring holds you in; the Mr. Blizzards stand outside it.\n"
        .. "More wake as it runs, and now and then a giant one.\n"
        .. "Everybody still standing at the buzzer wins.",
    minPlayers = 2,
    maps = OF.PARTY_ARENAS,
    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 90,
    saysOut = true,
    lensRole = ROLE_OUT,
    music = SEQ_LEVEL_SNOW,

    target = { name = "arena width",
               asks = "Arena width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 600, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,
    options = {
        { key = "size", name = "Arena size",
          help = "how big the arena starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual arena, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller arena - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger arena - more room to run" },
          } },
        { key = "floor", name = "The floor",
          help = "how the arena feels under your feet",
          choices = {
              { key = "ice", name = "slick",
                help = "stopping takes a while, as in the original" },
              { key = "grip", name = "ordinary",
                help = "you stop where you let go" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
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
    host_forget()
    heard, wireSeen = {}, nil
    clear_all()

end

function mode.scenery()
    local at, r = OF.ring.at(), OF.ring.radius()

    if at == nil or r == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or not OF.util.round_screen() then
        clear_all()
        return
    end
    local t = OF.gamemodes.since_start()
    listen()
    forget_old(t)
    draw(t, at, r)
end

function mode.before_mario_update(m)
    OF.ring.tick_window()
    if OF.ring.am_out() then
        OF.ring.watch_frame(m)
    end
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local at, r = OF.ring.at(), OF.ring.radius()
    if at == nil or r == nil then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    if (m.health or 0) < 0x880 then m.health = 0x880 end
    m.hurtCounter = 0
    m.peakHeight = m.pos.y
    local t = OF.gamemodes.since_start()

    local graced = OF.gamemodes.in_grace()
    for _, w in pairs(heard) do
        if not graced and hits(w, m, t, at, r) then
            OF.ring.go_out("Hit by a snowball")
            return
        end
    end
    keep_in(m, at, r)
    if m.pos.y < at.y - OUT_DROP then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the arena")
    end
end

function mode.host_update()
    host_throw(OF.gamemodes.since_start())
    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name, who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the arena to throw at.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("The snowballs got everybody.")
    end
end

function mode.on_timeout()
    local standing = OF.ring.pushable()
    if #standing == 1 then
        OF.gamemodes.finish("@ won.", standing[1].np.name, standing[1].np.name)
        return
    end
    if #standing == 0 then
        OF.gamemodes.finish("Nobody won.")
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
    clear_all()
    heard, wireSeen = {}, nil
    if OF.util.is_host() then OF.util.publish(THROWS_KEY, nil) end
    OF.ring.let_go()
end

function mode.terms()

    return OF.lang.fill("survive on a @ arena, @",
        OF.lang.t(OF.gamemodes.option_showing("blizzard", "size") or "normal"),
        OF.gamemodes.option_showing("blizzard", "floor") == "grip"
            and "ordinary floor" or "slick floor")
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at, r = OF.ring.at(), OF.ring.radius()
    if at ~= nil and r ~= nil then
        OF.util.zone_ring(at, keep_radius(r), 48, 4, 170, 210, 255, 200, "edge")
    end
    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

end

function mode.floor_class(m)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local current = OF.gamemodes.current and OF.gamemodes.current() or nil
    if current ~= mode or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    if OF.gamemodes.option_now("floor") == "grip" then return nil end
    if OF.ring.am_out() then return nil end
    return SLICK
end

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    return mode.floor_class(m)
end)

mode.ball_at = ball_at
mode.hits = hits
mode.period_for = period_for
mode.flight_of = flight_of
function mode.statues()
    return statues
end
mode.thrower_spot = thrower_spot
mode.keep_radius = keep_radius
mode.keep_in = keep_in
function mode.heard()
    return heard
end
function mode.wire(text)
    return unpack_throws(text)
end
function mode.numbers()
    return { throwers = THROWERS, wake = WAKE, flight = FLIGHT,
             giantFlight = GIANT_FLIGHT, hit = HIT_RADIUS, windup = WINDUP,
             anims = SNOWMAN_ANIMS, tempoFull = TEMPO_FULL, throwMost = THROW_MOST,
             flightMost = FLIGHT_MOST, throwLead = THROW_LEAD, stand = STAND_OFFSET,
             wireThrows = WIRE_THROWS }
end

OF.gamemodes.register(mode)
