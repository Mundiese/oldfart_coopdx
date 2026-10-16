OF = OF or {}

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local OUT_DROP = 400

local START_ACROSS = 1200
local WIDEST_ACROSS = 1900

local FIRE_HOP = 1.0

local FIRE_GRACE = 1.0

local FIRE_SCALE = 4.0
local FIRE_DRAW_LIFT = 50

local FLAME_HALF_WIDE = 10
local FLAME_HALF_TALL = 20
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100
local FIRE_BODY = FLAME_HALF_WIDE * FIRE_SCALE + MARIO_RADIUS

local TRAIL_SIZE = 3
local LANDING_RADIUS = 45

local FIRE_REACH_SHARE = 0.92

local BASE_FIREBALLS = 1

local MAX_FIREBALLS = 32

local BIG_SCALE, SMALL_SCALE, SPLIT_SHRINK = 8.0, 3.0, 0.75
local ARC_BIG, ARC_SHRINK, ARC_LEAST = 320, 0.75, 60
local HOP_BIG = 1.4

local STUN_SECONDS = 1.0

local STUN_IMMUNE = 1.5

local SPLIT_PACE = { steady = 6.0, fast = 4.0 }

local function split_every()
    return SPLIT_PACE[OF.gamemodes.option_now("split")] or SPLIT_PACE.steady
end

local function shown_split_every()
    return SPLIT_PACE[OF.gamemodes.option_showing("lavaleave", "split")]
        or SPLIT_PACE.steady
end

local function stomps_allowed()
    return OF.gamemodes.option_now("stomp") ~= "off"
end

local stunUntil = 0
local stunFreeAt = 0
local squishWas = 0

local function forget_stun()
    stunUntil = 0
    stunFreeAt = 0
    squishWas = 0
end

local function stun_frame(m, t)
    if m == nil then return false end

    local squish = m.bounceSquishTimer or 0
    local landedOn = squish > 0 and squishWas == 0
    squishWas = squish

    if landedOn and stomps_allowed() and t >= stunFreeAt then
        stunUntil = t + STUN_SECONDS
        stunFreeAt = stunUntil + STUN_IMMUNE

        OF.gamemodes.cue("bad", nil, "lavastomp")
    end

    return t < stunUntil
end

local function generation(t, every)
    if t <= 0 then return 0 end
    return math.floor(t / every)
end

local function active_count(t, every)
    local grown = BASE_FIREBALLS * 2 ^ generation(t, every)
    if grown > MAX_FIREBALLS then return MAX_FIREBALLS end
    return math.floor(grown)
end

local function size_of(g)
    return math.max(SMALL_SCALE, BIG_SCALE * SPLIT_SHRINK ^ g)
end

local function arc_of(g)
    return math.max(ARC_LEAST, ARC_BIG * ARC_SHRINK ^ g)
end
local function hop_scale(g)
    return 1 + (HOP_BIG - 1) * SPLIT_SHRINK ^ g
end

local function born_in(index)
    if index <= 1 then return 0 end
    return math.ceil(math.log(index, 2) - 1e-9)
end
local function parent_of(index)
    local g = born_in(index)
    if g <= 0 then return nil end
    return index - 2 ^ (g - 1)
end

local fireObjs = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    for i in pairs(fireObjs) do fireObjs[i] = nil end
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

local spots = {}

local HOP_LEAST, HOP_MOST = 150, 330
local HOP_TURN = math.pi * 0.5
local walks = {}

local HOME_FROM = 4
local HOME_REACH = 0.92
local CELL_SLACK = 1.3
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local function home_of(index, t, every)
    local count = active_count(t, every)
    if count < HOME_FROM or index > count then return nil end
    local r = math.sqrt((index - 0.5) / count) * HOME_REACH
    local a = index * GOLDEN_ANGLE
    return math.sin(a) * r, math.cos(a) * r, CELL_SLACK / math.sqrt(count)
end

local function forget_spots()
    for key in pairs(spots) do spots[key] = nil end
    for key in pairs(walks) do walks[key] = nil end
end

local WALK_KEEP = 4
local function walk_spot(index, leg)
    if leg < 0 then leg = 0 end
    local across = (OF.ring.opening ~= nil and OF.ring.opening() or nil)
        or OF.ring.radius() or OF.ring.FLOOR_RADIUS
    local ref = math.max(across * FIRE_REACH_SHARE, 1)
    local every = SPLIT_PACE[OF.gamemodes.option_now("split")] or SPLIT_PACE.steady

    local parent = parent_of(index)
    local first = 0
    if parent ~= nil then first = math.floor(born_in(index) * every / FIRE_HOP) end
    if leg < first then leg = first end
    local w = walks[index]
    if w == nil or leg < w.leg - WALK_KEEP + 1 then
        local u, v
        if parent ~= nil then
            u, v = walk_spot(parent, first)
        else
            local a = seeded01(index, 0, 1, 0) * 2 * math.pi
            local r = math.sqrt(seeded01(index, 0, 2, 0)) * 0.8
            u, v = math.sin(a) * r, math.cos(a) * r
        end
        w = { leg = first, heading = seeded01(index, 0, 3, 0) * 2 * math.pi,
              at = { [first] = { u, v } } }
        walks[index] = w
    end
    while w.leg < leg do
        local n = w.leg + 1
        local u0, v0 = w.at[w.leg][1], w.at[w.leg][2]
        local heading = w.heading + (seeded01(index, n, 1, 0) * 2 - 1) * HOP_TURN
        local len = (HOP_LEAST + (HOP_MOST - HOP_LEAST) * seeded01(index, n, 2, 0))
            * hop_scale(generation(n * FIRE_HOP, every)) / ref
        local u, v = u0 + math.sin(heading) * len, v0 + math.cos(heading) * len
        local hu, hv, cell = home_of(index, n * FIRE_HOP, every)
        if hu ~= nil and (u - hu) * (u - hu) + (v - hv) * (v - hv) > cell * cell then
            heading = math.atan(hu - u0, hv - v0) + (seeded01(index, n, 4, 0) * 2 - 1) * HOP_TURN * 0.5
            u, v = u0 + math.sin(heading) * len, v0 + math.cos(heading) * len
        end
        if u * u + v * v > 1 then
            heading = math.atan(-u0, -v0) + (seeded01(index, n, 3, 0) * 2 - 1) * HOP_TURN * 0.5
            u, v = u0 + math.sin(heading) * len, v0 + math.cos(heading) * len
            local d = math.sqrt(u * u + v * v)
            if d > 1 then u, v = u / d, v / d end
        end
        w.leg, w.heading = n, heading
        w.at[n] = { u, v }
        w.at[n - WALK_KEEP] = nil
    end
    local spot = w.at[leg]
    return spot[1], spot[2]
end

local function waypoint(index, leg, at)

    local parent = parent_of(index)
    if parent ~= nil then
        local every = SPLIT_PACE[OF.gamemodes.option_now("split")] or SPLIT_PACE.steady
        if leg < math.floor(born_in(index) * every / FIRE_HOP) then
            return waypoint(parent, leg, at)
        end
    end
    local key = index * 100000 + leg
    local spot = spots[key]
    if spot ~= nil then return spot[1], spot[2] end
    local sampleR = (OF.ring.radius() or OF.ring.FLOOR_RADIUS) * FIRE_REACH_SHARE
    local u, v = walk_spot(index, leg)
    local x, z = at.x + u * sampleR, at.z + v * sampleR
    spots[key] = { x, z }

    spots[key - 2] = nil
    return x, z
end

local function floor_under(x, z, at)
    local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
    if type(y) ~= "number" or y < at.y - 600 then return at.y end
    return y
end

local function fire_position(index, t, at)
    local leg = math.floor(t / FIRE_HOP)
    local frac = (t - leg * FIRE_HOP) / FIRE_HOP
    local fromX, fromZ = waypoint(index, leg, at)
    local toX, toZ = waypoint(index, leg + 1, at)

    local every = SPLIT_PACE[OF.gamemodes.option_now("split")] or SPLIT_PACE.steady
    local lift = math.sin(frac * math.pi) * arc_of(generation(t, every))
    local x, z = fromX + (toX - fromX) * frac, fromZ + (toZ - fromZ) * frac
    return x, floor_under(x, z, at) + lift, z
end

local function fire_leg(index, t, at)
    local leg = math.floor(t / FIRE_HOP)
    local frac = (t - leg * FIRE_HOP) / FIRE_HOP
    local toX, toZ = waypoint(index, leg + 1, at)
    local x, _, z = fire_position(index, t, at)
    return x, z, toX, toZ, frac
end

local heardFires = nil

local function move_fireballs(at, every)
    if at == nil then return end
    local t = OF.gamemodes.since_start()
    local count = active_count(t, every)
    local split = heardFires ~= nil and count > heardFires
    heardFires = count
    for index = 1, count do
        local x, y, z = fire_position(index, t, at)
        local obj = fireObjs[index]
        if obj == nil or obj.activeFlags == 0 then
            obj = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvStaticObject, E_MODEL_RED_FLAME, x, y, z, nil)
            fireObjs[index] = obj
        end
        if obj ~= nil then

            local size = size_of(generation(t, every))
            obj.oPosX, obj.oPosY, obj.oPosZ = x, y + FIRE_DRAW_LIFT * size / FIRE_SCALE, z
            OF.util.optional("obj_set_billboard", nil, obj)
            OF.util.optional("obj_scale", nil, obj, size)
            obj.oAnimState = (math.floor(t * 15) + index) % 8
        end
        if split and index == count then
            OF.gamemodes.round_sound_throttled("lavasplit", 15,
                SOUND_OBJ_FLAME_BLOWN, obj)
        end
    end

    for index = count + 1, MAX_FIREBALLS do
        local obj = fireObjs[index]
        if obj ~= nil then
            if obj.activeFlags ~= 0 then
                OF.util.optional("obj_mark_for_deletion", nil, obj)
            end
            fireObjs[index] = nil
        end
    end
end

local trailsDrawn = 0
local function draw_trails(at)
    trailsDrawn = 0
    local t = OF.gamemodes.since_start()
    if t < 0 then return 0 end
    local count = active_count(t, split_every())
    for index = 1, count do
        local x, z, toX, toZ, frac = fire_leg(index, t, at)
        if x ~= nil then
            local alpha = math.floor(90 + 150 * frac)
            local from = { x = x, y = floor_under(x, z, at) + 4, z = z }
            local to = { x = toX, y = floor_under(toX, toZ, at) + 4, z = toZ }
            if OF.util.world_line(from, to, TRAIL_SIZE, 255, 140, 40, alpha) then
                trailsDrawn = trailsDrawn + 1
            end
            OF.util.zone_ring(to, LANDING_RADIUS, 12, TRAIL_SIZE, 255, 90, 30, alpha)
        end
    end
    return trailsDrawn
end

local function clear_fireballs()
    for index, obj in pairs(fireObjs) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        fireObjs[index] = nil
    end
end

local function flame_of(index, t, at)
    local obj = fireObjs[index]
    if obj ~= nil and obj.activeFlags ~= 0 then
        local scale = FIRE_SCALE
        if obj.header ~= nil and obj.header.gfx ~= nil and obj.header.gfx.scale ~= nil then
            scale = obj.header.gfx.scale.x or scale
        end
        return obj.oPosX, obj.oPosY, obj.oPosZ, FLAME_HALF_WIDE * scale,
            FLAME_HALF_TALL * scale
    end
    local x, y, z = fire_position(index, t, at)
    local size = size_of(generation(t, split_every()))
    return x, y + FIRE_DRAW_LIFT * size / FIRE_SCALE, z, FLAME_HALF_WIDE * size,
        FLAME_HALF_TALL * size
end

local function touched_by_fire(m, at, t, every)
    if m == nil or m.pos == nil then return false end
    if t < FIRE_GRACE then return false end
    local tall = MARIO_TALL
    if m.action ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0 then tall = MARIO_SHORT end
    local count = active_count(t, every)
    for index = 1, count do
        local x, y, z, wide, high = flame_of(index, t, at)
        local dx, dz = m.pos.x - x, m.pos.z - z
        local reach = wide + MARIO_RADIUS
        if dx * dx + dz * dz <= reach * reach
            and m.pos.y < y + high and m.pos.y + tall > y - high then
            return true
        end
    end
    return false
end

local function fell_in(m, at)
    if at == nil or m == nil or m.pos == nil then return false end
    return m.pos.y < at.y - OUT_DROP
end

local ROLE_OUT = "out"
local mode = {
    key = "lavaleave",
    resultsBy = "survival",
    name = "Magma Mayhem",
    blurb = "fireballs loose on the rock, splitting as the round runs - flee",

    how = "A rock plateau over the lava, with fireballs loose.\n"
        .. "They split into more of themselves as the round runs.\n"
        .. "Touch one and you are out - no second chance.\n"
        .. "Jump on somebody and they are held still for a second.\n"
        .. "Step past the edge and you have seconds to get back.\n"
        .. "Slide off below it and that is out too, on the spot.\n"
        .. "The plateau narrows a little as the round runs,\n"
        .. "and more each time somebody goes out.\n"
        .. "How fast they split is set below.\n"
        .. "Last one on the rock wins.\n"
        .. "On the clock, everybody still standing on it.",
    minPlayers = 2,

    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_SOLID } },

    defaultLimit = 60,
    saysOut = true,

    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_HOT,

    target = { name = "plateau width",
               asks = "Plateau width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 600, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,

    options = {
        { key = "size", name = "Plateau size",
          help = "how big the plateau starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual plateau, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller plateau - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger plateau - more room to run" },
          } },

        { key = "split", name = "Fireball split",
          help = "sixteen want the rock crowded faster than four ever did",
          choices = {
              { key = "steady", name = "normal",
                help = "one more every few seconds; what a small lobby "
                    .. "sees" },
              { key = "fast", name = "fast",
                help = "the same split, on a tighter schedule - for a full plateau" },
          } },

        { key = "stomp", name = "Stomps",
          help = "the round's only move players can use on one another",
          choices = {
              { key = "land", name = "on",
                help = "land on somebody and they are held a second" },
              { key = "off", name = "off",
                help = "the fire and the edge are the only things that "
                    .. "reach you" },
          } },
    },
}

function mode.clock_for(total)
    return total >= 9 and 90 or 60
end

function mode.setup(players, options)
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.clock_for(#players))
    end
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
    forget_stun()
    forget_spots()
end

function mode.before_mario_update(m)

    if OF.util.round_screen() then
        move_fireballs(OF.ring.at(), split_every())
    else
        clear_fireballs()
    end
    OF.ring.tick_window()
    if OF.ring.am_out() then

        forget_stun()
        OF.ring.watch_frame(m)
        return
    end
    if stun_frame(m, OF.gamemodes.since_start()) then OF.input.hold(m) end
end

local HOP_WARN = 150
local heardLeg = nil

local function warn_hops(m, at, t, every)
    if m == nil or m.pos == nil or t < FIRE_GRACE then return end
    local leg = math.floor(t / FIRE_HOP)
    if heardLeg == leg then return end
    heardLeg = leg
    local reach = FIRE_BODY + HOP_WARN
    for index = 1, active_count(t, every) do
        local toX, toZ = waypoint(index, leg + 1, at)
        local dx, dz = m.pos.x - toX, m.pos.z - toZ
        if dx * dx + dz * dz <= reach * reach then
            OF.gamemodes.cue("hazard", nil, "lavahop")
            return
        end
    end
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
    local every = split_every()

    if touched_by_fire(m, at, t, every) then
        OF.ring.go_out("Caught by the fire")
        return
    end
    warn_hops(m, at, t, every)
    if fell_in(m, at) then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the plateau")
    end
end

function mode.host_update()
    OF.ring.close_frame()

    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name,
            who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the rock to threaten.")
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
    clear_fireballs()
    forget_stun()
    forget_spots()
    OF.ring.let_go()
end

function mode.terms()
    return OF.lang.fill("last one on the rock, fireballs splitting @",
        (shown_split_every() <= SPLIT_PACE.fast) and "fast" or "steadily")
end

function mode.fire_leg(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return fire_leg(index, OF.gamemodes.since_start(), at)
end

function mode.flame(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return flame_of(index, OF.gamemodes.since_start(), at)
end

function mode.judge_now()
    local at = OF.ring.at()
    if at == nil then return nil end
    return touched_by_fire(gMarioStates[0], at, OF.gamemodes.since_start(), split_every())
end

mode.FIRE_BODY = FIRE_BODY

function mode.trails_drawn()
    return trailsDrawn
end

function mode.fire_position(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return fire_position(index, OF.gamemodes.since_start(), at)
end

function mode.fastest_hop(index, legs)
    local at = OF.ring.at()
    if at == nil then return nil end
    local most = 0
    for leg = 0, (legs or 30) - 1 do
        local x0, z0 = waypoint(index, leg, at)
        local x1, z1 = waypoint(index, leg + 1, at)
        local d = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
        most = math.max(most, d / (FIRE_HOP * 30))
    end
    return most
end

function mode.count_at(t) return active_count(t, split_every()) end
function mode.size_at(t) return size_of(generation(t, split_every())) end

function mode.fire_position_at(index, t)
    local at = OF.ring.at()
    if at == nil then return nil end
    return fire_position(index, t, at)
end

function mode.stun_left()
    local t = OF.gamemodes.since_start()
    return math.max(0, stunUntil - t), math.max(0, stunFreeAt - t)
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == OF.ring.ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = OF.ring.at()

    if at ~= nil then
        local over = OF.ring.margin(0)
        local red, green, blue = 255, 150, 60
        if over ~= nil and over < 0 then red, green, blue = 255, 90, 90 end
        OF.util.zone_ring(at, OF.ring.radius(), 48, 4, red, green, blue, 220, "edge")
        draw_trails(at)
    end

    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

    local over = OF.ring.margin(0)
    if over == nil then
        OF.gamemodes.away_banner("You are not in the plateau's area")
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
