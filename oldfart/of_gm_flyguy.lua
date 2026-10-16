OF = OF or {}

local ROLE_BOUNCING = "bouncing"
local ROLE_OUT = "out"
local DEFAULT_TARGET = 25

local PLACES = {
    empty = { x = 0, y = 0, z = 0 },
}

local PLACE_ORDER = { "empty" }

local RADIUS_BASE, RADIUS_PER, RADIUS_MOST = 1100, 45, 1700

local FALLS = 3

local BACK_AFTER = 1.0
local BACK_HIGH = 600

local FLIES_BASE, FLIES_MOST = 4, 20
local HEIGHTS = { 230, 390, 560 }
local ORBIT_LEAST, ORBIT_MOST = 150, 420
local TURN_LEAST, TURN_MOST = 5, 10
local BOB = 40
local BACK_IN = 2.0
local FLY_SCALE = 1.5
local FLY_RADIUS, FLY_TALL = 70 * FLY_SCALE, 60 * FLY_SCALE
local MARIO_RADIUS = 37

local STOMP_BOUNCE = 56

local KNOCK_EVERY = 1.0

local CHAIN_MOST = 5

local STEER_TURN = 0x2000
local STEER_TOP = 30
local STEER_ACCEL = 3.0

local CLAIM_SLACK = 600
local CLAIM_ACTION = "fgclaim"
local CLAIM_AGAIN = 0.4

local FLYGUY_ANIMS = "flyguy_seg8_anims_08011A64"
local KEYS = { "ofFgFlies", "ofFgFlies2", "ofFgFlies3" }
local AT_KEY = "ofFgAt"
local GOT_KEY = "ofFgGot"
local TARGET_KEY = "ofFgTo"
local ROUND_KEYS = { "ofFgAt", "ofFgGot", "ofFgTo" }
local CHUNK = 160
local ENTRY = 20
local OFFSET = 23000
local PUBLISH_EVERY = 3

local hostFlies = {}
local hostFrame = 0
local dirty = false
local hostGot = {}
local hostFalls = {}
local hostNoRoom = false
local flies = {}
local wireSeen = nil
local drawn = {}
local asked = {}
local seenAlive = {}
local knockedAt = -99
local lastFeet = nil
local fallenAt = nil

local launched = false
local seenGot = -1
local placed = false
local chain = 0
local hostChain = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    drawn = {}
end)

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function to36(n, width)
    n = math.floor(n)
    if n < 0 then n = 0 end
    local out = ""
    for _ = 1, width do
        local d = n % 36
        out = string.sub(DIGITS, d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

local function from36(text)
    return tonumber(text, 36) or 0
end

local HASH_P = 1000003.0
local function seeded01(a, b, salt)
    local n = (a * 7919.0 + b * 104729.0 + (salt or 0) * 15485863.0) % HASH_P
    if n < 0 then n = n + HASH_P end
    n = (n * n + 7777.0) % HASH_P
    n = (n * 1103.0 + b * 31.0 + a) % HASH_P
    return n / HASH_P
end

local function radius_for(players)
    return math.min(RADIUS_BASE + RADIUS_PER * math.max((players or 0) - 4, 0), RADIUS_MOST)
end

local function flies_for(players)
    return math.min(FLIES_BASE + math.max(players or 0, 1), FLIES_MOST)
end

local function target_points()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return DEFAULT_TARGET end
    return value
end

local function points_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function bouncers()
    return OF.gamemodes.with_role(ROLE_BOUNCING)
end

local function field()
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "string" then return nil end
    local key, _, _, r = string.match(at, "^(%S+) (%-?%d+) (%-?%d+) (%d+)$")
    local place = key ~= nil and PLACES[key] or nil
    if place == nil then return nil end
    return { x = place.x, y = place.y, z = place.z, r = tonumber(r) or RADIUS_BASE }
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)")
    return level ~= nil and np.currLevelNum == tonumber(level)
        and np.currAreaIndex == tonumber(area)
end

local function fly_at(g, t, f)
    local spent = math.max(t - g.born, 0)
    local a = g.phase + g.dir * spent / g.turn * 2 * math.pi
    local x = g.cx + math.sin(a) * g.orbit
    local z = g.cz + math.cos(a) * g.orbit
    local y = f.y + g.high + math.sin(spent * 2.1 + g.phase) * BOB
    return x, y, z, a + g.dir * math.pi / 2
end

local function pack_fly(g, f)
    return to36(g.id % 1296, 2)
        .. to36((g.alive and 2 or 0) + (g.dir > 0 and 1 or 0), 1)
        .. to36(g.cx - f.x + OFFSET, 3) .. to36(g.cz - f.z + OFFSET, 3)
        .. to36(g.orbit, 2) .. to36(g.high, 2) .. to36(g.turn, 1)
        .. to36(math.floor((g.phase % (2 * math.pi)) / (2 * math.pi) * 1296 + 0.5) % 1296, 2)
        .. to36(g.born * 10, 3) .. to36(0, 1)
end

local function unpack_fly(e, f)
    if #e ~= ENTRY then return nil end
    local ad = from36(string.sub(e, 3, 3))
    return { id = from36(string.sub(e, 1, 2)),
             alive = ad >= 2, dir = (ad % 2 == 1) and 1 or -1,
             cx = from36(string.sub(e, 4, 6)) - OFFSET + f.x,
             cz = from36(string.sub(e, 7, 9)) - OFFSET + f.z,
             orbit = from36(string.sub(e, 10, 11)),
             high = from36(string.sub(e, 12, 13)),
             turn = math.max(from36(string.sub(e, 14, 14)), 1),
             phase = from36(string.sub(e, 15, 16)) / 1296 * 2 * math.pi,
             born = from36(string.sub(e, 17, 19)) / 10 }
end

local function sorted_ids(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function publish_all()
    local f = field()
    if f == nil then return end
    local parts = {}
    for _, id in ipairs(sorted_ids(hostFlies)) do parts[#parts + 1] = pack_fly(hostFlies[id], f) end
    local chunks = OF.util.chunk_parts(parts, CHUNK) or {}
    for index, key in ipairs(KEYS) do OF.util.publish(key, chunks[index]) end
end

local function publish_got()
    local out = {}
    for g = 0, 15 do
        out[#out + 1] = to36(math.min(hostGot[g] or 0, 1295), 2) .. to36(math.min(hostFalls[g] or 0, 35), 1)
    end
    OF.util.publish(GOT_KEY, table.concat(out))
end

local function ledger_of(globalIndex)
    local text = gGlobalSyncTable[GOT_KEY]
    if type(text) ~= "string" or globalIndex == nil then return 0, 0 end
    local at = globalIndex * 3 + 1
    if #text < at + 2 then return 0, 0 end
    return from36(string.sub(text, at, at + 1)), from36(string.sub(text, at + 2, at + 2))
end

local function got_of(globalIndex)
    local got = ledger_of(globalIndex)
    return got
end

local function falls_of(globalIndex)
    local _, falls = ledger_of(globalIndex)
    return falls
end

local function listen()
    local f = field()
    if f == nil then return end
    local text = OF.util.joined(KEYS)
    if text == wireSeen then return end
    wireSeen = text
    local seen = {}
    for i = 1, #text - ENTRY + 1, ENTRY do
        local g = unpack_fly(string.sub(text, i, i + ENTRY - 1), f)
        if g ~= nil then flies[g.id] = g seen[g.id] = true end
    end
    for id in pairs(flies) do if not seen[id] then flies[id] = nil end end
end

local function new_flight(g, t, f)
    local k = math.floor(t * 10)
    local a = seeded01(g.id, k, 1) * 2 * math.pi
    g.orbit = math.floor(ORBIT_LEAST + (ORBIT_MOST - ORBIT_LEAST) * seeded01(g.id, k, 2))
    local reach = math.max(f.r - g.orbit - FLY_RADIUS, 0)
    local out = math.sqrt(seeded01(g.id, k, 3)) * reach
    g.cx, g.cz = f.x + math.sin(a) * out, f.z + math.cos(a) * out
    g.high = HEIGHTS[math.floor(seeded01(g.id, k, 4) * #HEIGHTS) + 1]
    g.turn = math.floor(TURN_LEAST + (TURN_MOST - TURN_LEAST) * seeded01(g.id, k, 5))
    g.phase = seeded01(g.id, k, 6) * 2 * math.pi
    g.dir = seeded01(g.id, k, 7) < 0.5 and -1 or 1
    g.born = t
    g.alive = true
    dirty = true
end

local function award(globalIndex, delta)
    if globalIndex == nil then return end
    hostGot[globalIndex] = math.max((hostGot[globalIndex] or 0) + delta, 0)
    publish_got()
end

local function host_tick(t)
    if not OF.util.is_host() then return end
    local f = field()
    if f == nil then return end
    hostFrame = hostFrame + 1
    for _, g in pairs(hostFlies) do
        if not g.alive and t >= (g.back or 0) then new_flight(g, t, f) end
    end
    if dirty and hostFrame % PUBLISH_EVERY == 0 then
        dirty = false
        publish_all()
    end
end

local function host_claim(fromLocal, idText, what, chainText)
    if not OF.util.is_host() then return false, "Only the host." end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "flyguy" or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return false, "No round."
    end
    local f = field()
    local li = tonumber(fromLocal) or -1
    local np = gNetworkPlayers[li]
    local m = gMarioStates[li]
    if f == nil or np == nil or m == nil or m.pos == nil then return false, "Nobody." end
    local t = OF.gamemodes.since_start()
    if tonumber(what) == 2 then
        if OF.gamemodes.role(li) ~= ROLE_BOUNCING then return false, "Not bouncing." end
        hostChain[np.globalIndex] = 0
        hostFalls[np.globalIndex] = math.min((hostFalls[np.globalIndex] or 0) + 1, FALLS)
        publish_got()
        return true
    end
    if OF.gamemodes.role(li) ~= ROLE_BOUNCING then return false, "Not bouncing." end
    local g = hostFlies[tonumber(idText) or -1]
    if g == nil or not g.alive then return false, "Already stomped." end
    local x, y, z = fly_at(g, t, f)
    if (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 + (m.pos.y - y) ^ 2 > CLAIM_SLACK * CLAIM_SLACK then
        return false, "Not near it."
    end
    g.alive = false
    g.back = t + BACK_IN
    dirty = true

    local claimed = math.floor(tonumber(chainText) or 1)
    local link = 1
    if claimed > 1 then
        link = math.min(claimed, (hostChain[np.globalIndex] or 0) + 1, CHAIN_MOST)
    end
    hostChain[np.globalIndex] = link
    award(np.globalIndex, link)
    return true
end

local registered = false
local function register_claim()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action(CLAIM_ACTION, "round_move", host_claim)
end

local function gone_obj(o)
    return o == nil or o.activeFlags == 0
end

local function unmake(o)
    if not gone_obj(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function clear_all()
    for id, o in pairs(drawn) do unmake(o) drawn[id] = nil end
end

local function pose(o)
    local anims = gObjectAnimations ~= nil and gObjectAnimations[FLYGUY_ANIMS] or nil
    if anims == nil then return end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, 1.0)
end

local function puff(x, y, z)
    OF.util.optional("spawn_non_sync_object", nil, id_bhvStarKeyCollectionPuffSpawner,
        E_MODEL_NONE, x, y, z, nil)
end

local function draw(t, f)
    for id, g in pairs(flies) do
        local was = seenAlive[id]
        seenAlive[id] = g.alive
        local o = drawn[id]
        if not g.alive then
            if was == true and not gone_obj(o) then
                puff(o.oPosX, o.oPosY, o.oPosZ)
                OF.gamemodes.round_sound_from(o, SOUND_OBJ_ENEMY_DEFEAT_SHRINK)
            end
            unmake(o)
            drawn[id] = nil
        else
            local x, y, z, heading = fly_at(g, t, f)
            if gone_obj(o) then
                o = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_FLYGUY, x, y, z, nil)
                drawn[id] = o

                if o ~= nil then pose(o) end
            end
            if o ~= nil then
                o.oPosX, o.oPosY, o.oPosZ = x, y, z
                o.oFaceAngleYaw = math.floor(heading * 32768 / math.pi) % 65536
                o.oFaceAnglePitch, o.oFaceAngleRoll = 0, 0
                OF.util.optional("obj_scale", nil, o, FLY_SCALE)
            end
        end
    end
    for id, o in pairs(drawn) do
        if flies[id] == nil then unmake(o) drawn[id] = nil seenAlive[id] = nil end
    end
end

local function in_round()
    return OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and OF.gamemodes.role(0) == ROLE_BOUNCING and OF.util.can_play(0)
end

local function ask(id, what, t, link)
    local key = tostring(id) .. ":" .. tostring(what)
    if asked[key] ~= nil and t - asked[key] < CLAIM_AGAIN then return false end
    asked[key] = t
    register_claim()
    if OF.util.asks(OF.net, "host_does") then
        OF.net.host_does(CLAIM_ACTION, id, what, link ~= nil and tostring(link) or nil)
        return true
    end
    return false
end

local function judge_flies(t)
    if not in_round() then
        lastFeet = nil
        return
    end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    local was = lastFeet
    lastFeet = m.pos.y
    for _, id in ipairs(sorted_ids(flies)) do
        local g = flies[id]
        local o = drawn[id]
        if g.alive and not gone_obj(o) then
            local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
            local reach = FLY_RADIUS + MARIO_RADIUS
            local top = o.oPosY + FLY_TALL * 0.4
            local crossed = was ~= nil and was >= top and m.pos.y < top and m.pos.y + 160 > o.oPosY
            if dx * dx + dz * dz < reach * reach
                and ((m.pos.y + 160 > o.oPosY and m.pos.y < o.oPosY + FLY_TALL) or crossed) then
                if (m.vel.y or 0) < 0 and (m.pos.y > top or crossed) then
                    m.vel.y = STOMP_BOUNCE
                    if ACT_DOUBLE_JUMP ~= nil then set_mario_action(m, ACT_DOUBLE_JUMP, 0) end
                    m.vel.y = STOMP_BOUNCE
                    launched = true
                    chain = math.min(chain + 1, CHAIN_MOST)
                    ask(id, 1, t, chain)

                    if chain >= 2 and OF.util.asks(OF.hud, "banner") then
                        OF.hud.banner("medal", OF.lang.fill("CHAIN x@", tostring(chain)), nil,
                            { quiet = true })
                    end
                    OF.gamemodes.round_sound_throttled("fgstomp", 3, SOUND_OBJ_STOMPED, nil)
                    return
                elseif t - knockedAt > KNOCK_EVERY then
                    knockedAt = t
                    if atan2s ~= nil then m.faceAngle.y = atan2s(dz, dx) end
                    m.forwardVel = -24
                    m.vel.y = 20
                    if ACT_BACKWARD_AIR_KB ~= nil then set_mario_action(m, ACT_BACKWARD_AIR_KB, 0) end
                    launched = true
                    OF.gamemodes.cue("bad")
                    return
                end
            end
        end
    end
end

local function hold_inside(m, f)
    local inset = OF.gamemodes.RING_WALL_INSET or 5
    return OF.util.wall_in(m, f.x, f.z, math.max(0, f.r - inset - 1))
end

local function rim_wall(m, f, air)
    local _ = air
    if launched then return false end
    return hold_inside(m, f)
end

local function bounce_frame(t, f)
    if not in_round() then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if fallenAt ~= nil then
        if t - fallenAt >= BACK_AFTER then
            fallenAt = nil
            local np = gNetworkPlayers[0]
            local a = ((np ~= nil and np.globalIndex or 0) / 16) * 2 * math.pi
            OF.net.snap_to(f.x + math.sin(a) * 200, f.y + BACK_HIGH, f.z + math.cos(a) * 200, nil)
            if ACT_FREEFALL ~= nil then set_mario_action(m, ACT_FREEFALL, 0) end
        end
        return
    end
    local air = m.action ~= nil and (m.action & ACT_FLAG_AIR) ~= 0

    rim_wall(m, f, air)
    if air or m.pos.y > f.y + 30 then return end
    local dx, dz = m.pos.x - f.x, m.pos.z - f.z
    local wasThrown = launched
    launched = false
    if dx * dx + dz * dz > f.r * f.r and not wasThrown then

        hold_inside(m, f)
        dx, dz = m.pos.x - f.x, m.pos.z - f.z
    end
    if dx * dx + dz * dz <= f.r * f.r then
        local high = m.controller ~= nil and (m.controller.buttonDown & A_BUTTON) ~= 0
        local act = high and ACT_TRIPLE_JUMP or ACT_DOUBLE_JUMP
        if act ~= nil then set_mario_action(m, act, 0) end
        launched = true
        chain = 0
        OF.gamemodes.round_sound_throttled("fgboing", 6, SOUND_GENERAL_BOING1, nil)
        return
    end

    fallenAt = t
    chain = 0
    ask("f", 2, t)
    OF.gamemodes.cue("bad")

    if OF.util.asks(OF.hud, "banner") then
        local np = gNetworkPlayers[0]
        local left = np ~= nil and (FALLS - falls_of(np.globalIndex) - 1) or 0
        if left > 0 then
            OF.hud.banner("out", OF.lang.t("FALL"),
                OF.lang.plural(left, "1 fall left", "@ falls left"), { quiet = true })
        end
    end
end

local function steer_frame()
    if not in_round() or fallenAt ~= nil then return false end
    local m = gMarioStates[0]
    if m == nil or m.faceAngle == nil then return false end
    local act = m.action
    if act == nil or (act ~= ACT_DOUBLE_JUMP and act ~= ACT_TRIPLE_JUMP and act ~= ACT_FREEFALL) then
        return false
    end
    local mag = tonumber(m.intendedMag) or 0
    if mag <= 0 then return false end
    local want = math.floor(tonumber(m.intendedYaw) or 0) % 65536
    local face = math.floor(m.faceAngle.y or 0) % 65536
    local diff = (want - face + 32768) % 65536 - 32768
    if diff > STEER_TURN then diff = STEER_TURN elseif diff < -STEER_TURN then diff = -STEER_TURN end
    face = (face + diff) % 65536
    if face >= 32768 then face = face - 65536 end
    m.faceAngle.y = face

    local fwd = m.forwardVel or 0
    local vel = m.vel
    if vel ~= nil and type(vel.x) == "number" and type(vel.z) == "number" then
        local along = vel.x * sins(face) + vel.z * coss(face)
        fwd = math.max(0, math.min(fwd, along))
    end
    local top = STEER_TOP * math.min(mag, 32) / 32
    if fwd < top then fwd = math.min(fwd + STEER_ACCEL, top) end
    m.forwardVel = fwd
    return true
end

local mode = {
    key = "flyguy",
    name = "Fly Guy Stomp",
    blurb = "bounce on the trampoline and stomp the Fly Guys",
    how = "The middle of the floor is a trampoline: land to bounce.\n"
        .. "Hold A on landing for a high bounce. Steer with the stick.\n"
        .. "Come down on top of a Fly Guy and it is yours.\n"
        .. "Chain stomps before you land: each is worth one more.\n"
        .. "Touch one any other way and it throws you back.\n"
        .. "Bounce off the edge: a fall. Three falls and you are out.\n"
        .. "First to the target wins, or the most at the clock.",
    aims = { [ROLE_BOUNCING] = "Come down on the Fly Guys - and stay on the trampoline." },
    minPlayers = 2,

    maps = { "empty" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    target = { name = "points to win",
               asks = "How many points win the round",
               default = DEFAULT_TARGET, min = 5, max = 50, step = 5 },
    defaultLimit = 150,
    saysOut = true,
    lensRole = ROLE_OUT,
    music = SEQ_LEVEL_SLIDE,
    teams = false,
    studio = { tint = { 150, 170, 200 } },
}
mode.radius_for = radius_for
mode.flies_for = flies_for
mode.fly_at = fly_at
mode.pack_fly = pack_fly
mode.unpack_fly = unpack_fly
mode.got_of = got_of
mode.falls_of = falls_of
mode.host_claim = host_claim
mode.steer_frame = steer_frame
mode.rim_wall = rim_wall
function mode.launch(on) launched = on == true end
mode.CHAIN_MOST = CHAIN_MOST
mode.PLACES = PLACES

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_BOUNCING)
    end
    OF.util.publish(TARGET_KEY, options.target or DEFAULT_TARGET)
end

local function place_here()
    if not OF.util.asks(OF.arena, "find") then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for _, placeKey in ipairs(PLACE_ORDER) do
        local place = OF.arena.find(placeKey)
        if place ~= nil and place.level ~= nil and place.level == np.currLevelNum
            and (place.area or 1) == (np.currAreaIndex or 1) then
            return placeKey
        end
    end
    return nil
end

function mode.pin()
    hostFlies, dirty, hostGot, hostFalls = {}, false, {}, {}
    local key = place_here()
    if key == nil then
        hostNoRoom = true
        return
    end
    hostNoRoom = false
    local np = gNetworkPlayers[0]
    local players = #bouncers()
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f %.0f", key, np.currLevelNum,
        np.currAreaIndex, radius_for(players)))
    publish_got()
    local f = field()
    for id = 1, flies_for(players) do
        local g = { id = id }
        hostFlies[id] = g
        new_flight(g, id * 0.1, f)
        g.born = 0
    end
    publish_all()
end

local function place_me(f)
    if placed then return end
    local np = gNetworkPlayers[0]
    if np == nil or OF.gamemodes.role(0) ~= ROLE_BOUNCING then return end
    placed = true
    local a = (np.globalIndex or 0) / 16 * 2 * math.pi
    local x, z = f.x + math.sin(a) * f.r * 0.5, f.z + math.cos(a) * f.r * 0.5
    local yaw = math.atan(f.x - x, f.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
end

function mode.on_start()
    flies, wireSeen, asked, seenAlive = {}, nil, {}, {}
    knockedAt, fallenAt, seenGot, placed = -99, nil, -1, false
    chain, hostChain = 0, {}
    clear_all()
    register_claim()

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_BOUNCING)
    local np = gNetworkPlayers[localIndex]
    if OF.util.is_host() and np ~= nil then
        hostGot[np.globalIndex], hostFalls[np.globalIndex] = 0, 0
        publish_got()
    end
    return ROLE_BOUNCING
end

function mode.scenery()
    local f = field()
    if OF.gamemodes.state() == OF.gamemodes.OFF or f == nil
        or not here_ok(0) or not OF.util.round_screen() then
        clear_all()
        return
    end
    local t = OF.gamemodes.since_start()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then place_me(f) end
    listen()
    draw(t, f)
    judge_flies(t)
    bounce_frame(t, f)
    steer_frame()
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local role = OF.gamemodes.role(0)
    if role ~= ROLE_BOUNCING and role ~= ROLE_OUT then return end
    local got = got_of(np.globalIndex)
    if got ~= points_of(0) then
        if got > points_of(0) and seenGot >= 0 then OF.gamemodes.cue("good") end
        OF.util.publish_row(0, "ofScore", got)
    end
    seenGot = got
    if role == ROLE_BOUNCING and falls_of(np.globalIndex) >= FALLS then
        OF.gamemodes.set_role(0, ROLE_OUT)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        OF.gamemodes.abandon("Fly Guy Stomp is played in The Tiles.")
        return
    end
    host_tick(OF.gamemodes.since_start())
    local target = target_points()
    local still = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_BOUNCING)) do
        still = still + 1
        local got = entry.np ~= nil and got_of(entry.np.globalIndex) or 0
        if got >= target then
            OF.gamemodes.finish("@ reached @ points and won.", entry.np.name, entry.np.name,
                tostring(got))
            return
        end
    end
    if still == 0 then mode.on_timeout() end
end

function mode.still_winnable()
    return #bouncers() + #OF.gamemodes.with_role(ROLE_OUT) >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ points, or most at the clock", tostring(target_points()))
end

function mode.on_timeout()
    local everybody = {}
    for _, entry in ipairs(bouncers()) do everybody[#everybody + 1] = entry end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_OUT)) do everybody[#everybody + 1] = entry end
    local best, names = OF.gamemodes.best_of(everybody,
        function(entry) return entry.np ~= nil and got_of(entry.np.globalIndex) or 0 end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody stomped a Fly Guy.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points.", names[1], names[1])
    end
end

function mode.hud()
    local f = field()
    if f == nil then return end
    if not here_ok(0) then
        OF.gamemodes.away_banner("The trampoline is somewhere else")
        return
    end
    local np = gNetworkPlayers[0]
    local role = OF.gamemodes.role(0)
    if role == ROLE_OUT then
        OF.gamemodes.out_banner("Three falls")
        return
    end
    if role == ROLE_BOUNCING and np ~= nil then

        local left = FALLS - falls_of(np.globalIndex)
        if OF.util.asks(OF.hud, "state_line") then
            if left == 1 then
                OF.hud.state_line("last", OF.lang.t("Last fall"), { prio = 60, tone = "warn" })
            else
                OF.hud.state_line("falls", nil, { prio = 50, icons = mode.fall_icons(left) })
            end
        end
        OF.util.legend({ OF.lang.t("Land on the trampoline - you bounce"),
            OF.lang.t("A held as you land - the high bounce"),
            OF.lang.t("Come down on a Fly Guy to stomp it") })
    end
    local r, g, b = OF.util.round_tone("cold")
    OF.util.zone_ring(f, f.r, 48, 4, r, g, b, 220, "edge")

end

function mode.fall_icons(left)
    local items = {}
    for i = 1, FALLS do
        items[i] = { icon = "pip", tone = "ink", empty = i > (left or 0) }
    end
    return items
end

function mode.out_cause() return OF.lang.t("Three falls") end
mode.boardTitle = "Points"
function mode.cleanup()
    clear_all()
    if OF.util.is_host() then
        for _, key in ipairs(KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
    hostFlies, dirty, hostGot, hostFalls, hostNoRoom = {}, false, {}, {}, false
    flies, wireSeen, asked, seenAlive = {}, nil, {}, {}
    knockedAt, fallenAt, seenGot, placed = -99, nil, -1, false
    chain, hostChain = 0, {}
    return true
end

OF.gamemodes.register(mode)
