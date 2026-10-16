OF = OF or {}

local ROLE_CHASING = "chasing"
local DEFAULT_TARGET = 10

local RABBITS_BASE = 2
local PENGUINS_BASE = 3
local MOST = 15

local BACK_AFTER = 6

local GOLD_POINTS = 3

local FLEE_REACH = 900
local CALM_REACH = 1500
local DODGE_REACH = 320
local HOP_SECONDS = 1.1
local THINK_EVERY = 0.25

local PACES = { calm = 22, quick = 28, wild = 32 }
local PACE_DEFAULT = "quick"
local GOLD_PACE = 1.15

local WADDLE = 7
local SHUFFLE = 12
local SHUFFLE_REACH = 380
local STAND_LEAST, STAND_MOST = 1.0, 2.6

local CARRY_TOP = 24

local PEN_RADIUS = 320
local PEN_TALL = 400

local DROP_COOLDOWN = 1.5

local CARRY_LIFT = 175

local STEP = 60
local RISE = 110
local DROP = 160
local ROAM = 2800

local TURNS = { 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150, 180 }
local SHARES = { 1.0, 0.6, 0.35 }

local BODY = { rabbit = { 50, 75 }, penguin = { 40, 40 } }
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100

local CLAIM_SLACK = 520
local CLAIM_ACTION = "rcclaim"
local CLAIM_AGAIN = 0.6

local MIPS_ANIMS = "mips_seg6_anims_06015634"
local PENGUIN_ANIMS = "penguin_seg5_anims_05008B74"
local ANIM_SIT, ANIM_HOP = 0, 1
local ANIM_WALK, ANIM_STAND = 0, 3

local KEYS = { "ofRcMobs", "ofRcMobs2", "ofRcMobs3" }
local PTS_KEY = "ofRcPts"
local AT_KEY = "ofRcAt"
local GOT_KEY = "ofRcGot"
local PEN_KEY = "ofRcPen"
local TARGET_KEY = "ofRcTo"
local ROUND_KEYS = { "ofRcPts", "ofRcAt", "ofRcGot", "ofRcPen", "ofRcTo" }
local CHUNK = 168
local ENTRY = 21
local OFFSET = 23000
local PUBLISH_EVERY = 3

local SIT, RUN, HELD, GONE = 0, 1, 2, 3

local hostMobs = {}
local hostFrame = 0
local dirty = false
local hostNoPoints = false

local hostGot = {}

local mobs = {}
local wireSeen = nil
local drawn = {}
local asked = {}
local wasState = {}
local sparkleAt = 0
local seenGot = -1

local goldSaid = false
local mother = nil

hook_event(HOOK_ON_LEVEL_INIT, function()
    drawn = {}
    mother = nil
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

local function penguins()
    return OF.gamemodes.option_now("what") == "penguins"
end

local function kind()
    return penguins() and "penguin" or "rabbit"
end

local function pace()
    return PACES[OF.gamemodes.option_now("pace") or PACE_DEFAULT] or PACES[PACE_DEFAULT]
end

local function hop_pace(gold)
    local spd = pace() * (gold and GOLD_PACE or 1)
    return math.floor(spd / 2 + 0.5) * 2
end

local function count_for(players, carrying)
    local n = math.max(players or 0, 1)
    if carrying then
        return math.min(PENGUINS_BASE + math.ceil(n * 3 / 4), MOST)
    end
    return math.min(RABBITS_BASE + math.ceil(n / 2), MOST)
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

local function chasers()
    return OF.gamemodes.with_role(ROLE_CHASING)
end

local poolText, poolList = nil, nil
local function pool()
    local text = gGlobalSyncTable[PTS_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text ~= poolText then
        poolText = text
        poolList = OF.gamemodes.unpack_points(text)
    end
    if poolList == nil or poolList[1] == nil then return nil end
    return poolList
end

local function origin()
    local list = pool()
    return list ~= nil and list[1] or nil
end

local function pen()
    local text = gGlobalSyncTable[PEN_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    return OF.gamemodes.unpack_points(text)[1]
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    return at == tostring(np.currLevelNum) .. "." .. tostring(np.currAreaIndex)
end

local function floor_near(x, z, fromY)
    local y = OF.util.optional("find_floor_height", nil, x, fromY + RISE + 10, z)
    if type(y) ~= "number" or y < fromY - DROP - 40 then return nil end
    return y
end

local function mob_at(mob, t)
    if mob.state ~= RUN then return mob.x, mob.y, mob.z, false end
    local spent = math.max(math.min(t - mob.t0, mob.dur), 0)
    local walked = spent * 30 * mob.spd
    local x = mob.x + math.sin(mob.yaw) * walked
    local z = mob.z + math.cos(mob.yaw) * walked
    local y = floor_near(x, z, mob.y) or mob.y
    return x, y, z, t < mob.t0 + mob.dur
end

local function pack_mob(mob, at)
    local who = mob.holder ~= nil and (mob.holder + 1) or 0
    return to36(mob.id % 1296, 2)
        .. to36(mob.state * 2 + (mob.gold and 1 or 0), 1)
        .. to36(mob.x - at.x + OFFSET, 3) .. to36(mob.z - at.z + OFFSET, 3)
        .. to36(mob.y - at.y + OFFSET, 3)
        .. to36(math.floor((mob.yaw % (2 * math.pi)) / (2 * math.pi) * 1296 + 0.5) % 1296, 2)
        .. to36(mob.t0 * 10, 3) .. to36(mob.dur * 10, 2)
        .. to36(mob.spd / 2, 1) .. to36(who, 1)
end

local function unpack_mob(e, at)
    if #e ~= ENTRY then return nil end
    local sg = from36(string.sub(e, 3, 3))
    local who = from36(string.sub(e, 21, 21))
    return { id = from36(string.sub(e, 1, 2)),
             state = math.floor(sg / 2), gold = sg % 2 == 1,
             x = from36(string.sub(e, 4, 6)) - OFFSET + at.x,
             z = from36(string.sub(e, 7, 9)) - OFFSET + at.z,
             y = from36(string.sub(e, 10, 12)) - OFFSET + at.y,
             yaw = from36(string.sub(e, 13, 14)) / 1296 * 2 * math.pi,
             t0 = from36(string.sub(e, 15, 17)) / 10,
             dur = from36(string.sub(e, 18, 19)) / 10,
             spd = from36(string.sub(e, 20, 20)) * 2,
             holder = who > 0 and (who - 1) or nil }
end

local function sorted_ids(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function publish_all()
    local at = origin()
    if at == nil then return end
    local parts = {}
    for _, id in ipairs(sorted_ids(hostMobs)) do
        parts[#parts + 1] = pack_mob(hostMobs[id], at)
    end
    local chunks = OF.util.chunk_parts(parts, CHUNK) or {}
    for index, key in ipairs(KEYS) do
        OF.util.publish(key, chunks[index])
    end
end

local function publish_got()
    local out = {}
    for g = 0, 15 do out[#out + 1] = to36(math.min(hostGot[g] or 0, 1295), 2) end
    OF.util.publish(GOT_KEY, table.concat(out))
end

local function got_of(globalIndex)
    local text = gGlobalSyncTable[GOT_KEY]
    if type(text) ~= "string" or globalIndex == nil then return 0 end
    local at = globalIndex * 2 + 1
    if #text < at + 1 then return 0 end
    return from36(string.sub(text, at, at + 1))
end

local function listen()
    local at = origin()
    if at == nil then return end
    local text = OF.util.joined(KEYS)
    if text == wireSeen then return end
    wireSeen = text
    local seen = {}
    for i = 1, #text - ENTRY + 1, ENTRY do
        local mob = unpack_mob(string.sub(text, i, i + ENTRY - 1), at)
        if mob ~= nil then
            mobs[mob.id] = mob
            seen[mob.id] = true
        end
    end
    for id in pairs(mobs) do
        if not seen[id] then mobs[id] = nil end
    end
end

local function nearest_player(x, z)
    local best, bestD = nil, nil
    for _, entry in ipairs(chasers()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil and OF.util.can_play(entry.localIndex) then
            local dx, dz = m.pos.x - x, m.pos.z - z
            local d = dx * dx + dz * dz
            if bestD == nil or d < bestD then best, bestD = m, d end
        end
    end
    return best, bestD ~= nil and math.sqrt(bestD) or nil
end

local function away_yaw(x, z)
    local px, pz, any = 0, 0, false
    for _, entry in ipairs(chasers()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil and OF.util.can_play(entry.localIndex) then
            local dx, dz = x - m.pos.x, z - m.pos.z
            local d = math.sqrt(dx * dx + dz * dz)
            if d < CALM_REACH and d > 1 then
                local w = 1 / d
                px, pz, any = px + dx / d * w, pz + dz / d * w, true
            end
        end
    end
    if not any then return nil end
    return math.atan(px, pz)
end

local BAD_FLOORS = {}
local function bad_floor(kindId)
    if next(BAD_FLOORS) == nil then
        for _, name in ipairs({ "SURFACE_BURNING", "SURFACE_DEATH_PLANE",
            "SURFACE_INSTANT_QUICKSAND", "SURFACE_DEEP_QUICKSAND",
            "SURFACE_INSTANT_MOVING_QUICKSAND", "SURFACE_DEEP_MOVING_QUICKSAND",
            "SURFACE_QUICKSAND", "SURFACE_MOVING_QUICKSAND" }) do
            local value = _G[name]
            if type(value) == "number" then BAD_FLOORS[value] = true end
        end
        BAD_FLOORS.filled = true
    end
    return kindId ~= nil and BAD_FLOORS[kindId] == true
end

local function on_course(x, z)
    local list = pool()
    if list == nil then return false end
    for _, p in ipairs(list) do
        local dx, dz = x - p.x, z - p.z
        if dx * dx + dz * dz <= ROAM * ROAM then return true end
    end
    return false
end

local function hop_ok(x0, y0, z0, yaw, len)
    local sx, sz = math.sin(yaw), math.cos(yaw)
    local wall = OF.util.optional("collision_find_surface_on_ray", nil,
        x0, y0 + 40, z0, sx * (len + 60), 0, sz * (len + 60))
    if wall ~= nil and wall.surface ~= nil then return nil end
    local endY = y0
    local steps = math.max(1, math.ceil(len / STEP))
    for s = 1, steps do
        local d = len * s / steps
        local x, z = x0 + sx * d, z0 + sz * d
        local y = OF.util.optional("find_floor_height", nil, x, y0 + RISE + 10, z)
        if type(y) ~= "number" or y < y0 - DROP or y > y0 + RISE then return nil end
        local floor = OF.util.optional("collision_find_floor", nil, x, y0 + RISE + 10, z)
        if floor ~= nil and bad_floor(floor.type) then return nil end
        local water = OF.util.optional("find_water_level", nil, x, z)
        if type(water) == "number" and water > y + 30 then return nil end
        endY = y
    end
    if not on_course(x0 + sx * len, z0 + sz * len) then return nil end
    return endY
end

local function plan_hop(mob, t, want, spd, seconds)
    local x, y, z = mob_at(mob, t)
    local jitter = (seeded01(mob.id, math.floor(t * 10), 3) - 0.5) * 0.5
    for _, share in ipairs(SHARES) do
        local len = spd * 30 * seconds * share
        for _, turn in ipairs(TURNS) do
            local yaw = want + jitter + math.rad(turn)
            if hop_ok(x, y, z, yaw, len) ~= nil then
                mob.x, mob.y, mob.z = x, y, z
                mob.yaw, mob.t0, mob.spd = yaw % (2 * math.pi), t, spd
                mob.dur = seconds * share
                mob.state = RUN
                dirty = true
                return true
            end
        end
    end
    return false
end

local function sit(mob, t)
    local x, y, z = mob_at(mob, t)
    mob.x, mob.y, mob.z, mob.state = x, y, z, SIT
    mob.t0, mob.dur = t, 0
    dirty = true
end

local function think_rabbit(mob, t)
    local x, _, z, moving = mob_at(mob, t)
    local _, near = nearest_player(x, z)
    local spd = hop_pace(mob.gold)
    if mob.state == SIT then
        if near ~= nil and near < FLEE_REACH then
            local want = away_yaw(x, z)
            if want ~= nil and not plan_hop(mob, t, want, spd, HOP_SECONDS) then sit(mob, t) end
        end
        return
    end

    local threat = false
    if moving and near ~= nil and near < DODGE_REACH then
        local m = nearest_player(x, z)
        if m ~= nil then
            local dx, dz = m.pos.x - x, m.pos.z - z
            local d = math.max(math.sqrt(dx * dx + dz * dz), 1)
            threat = (math.sin(mob.yaw) * dx + math.cos(mob.yaw) * dz) / d > 0.3
        end
    end
    if moving and not threat then return end
    if near == nil or near > CALM_REACH then
        sit(mob, t)
        return
    end
    local want = away_yaw(x, z) or mob.yaw
    if not plan_hop(mob, t, want, spd, HOP_SECONDS) then sit(mob, t) end
end

local function think_penguin(mob, t)
    local x, _, z, moving = mob_at(mob, t)
    if moving then return end
    local _, near = nearest_player(x, z)
    if near ~= nil and near < SHUFFLE_REACH then
        local want = away_yaw(x, z)
        if want ~= nil and plan_hop(mob, t, want, SHUFFLE, 0.8) then return end
    end
    if mob.state == RUN then
        sit(mob, t)
        mob.wake = t + STAND_LEAST + (STAND_MOST - STAND_LEAST) * seeded01(mob.id, math.floor(t), 5)
        return
    end
    if t >= (mob.wake or 0) then
        local want = seeded01(mob.id, math.floor(t * 10), 6) * 2 * math.pi
        if not plan_hop(mob, t, want, WADDLE, 2.0) then
            mob.wake = t + STAND_LEAST
        end
    end
end

local function respawn_spot(id, t)
    local list = pool()
    if list == nil then return nil end
    local best, bestScore = nil, nil
    local home = penguins() and pen() or nil
    for k = 1, 6 do
        local p = list[math.floor(seeded01(id, math.floor(t * 10) + k, 7) * #list) + 1]
        if p ~= nil then
            local _, near = nearest_player(p.x, p.z)
            local score = (near or 9999) + seeded01(id, k, 8) * 400
            if home ~= nil then
                local dx, dz = p.x - home.x, p.z - home.z
                if dx * dx + dz * dz < 1200 * 1200 then score = score - 3000 end
            end
            if bestScore == nil or score > bestScore then best, bestScore = p, score end
        end
    end
    return best
end

local function any_gold()
    for _, mob in pairs(hostMobs) do
        if mob.gold and mob.state ~= GONE then return true end
    end
    return false
end

local function place(mob, p, t)
    local a = seeded01(mob.id, math.floor(t * 10), 9) * 2 * math.pi
    local x, z = p.x + math.sin(a) * 120, p.z + math.cos(a) * 120
    local y = OF.util.optional("find_floor_height", nil, x, p.y + 300, z)
    if type(y) ~= "number" or y < p.y - 600 then x, z, y = p.x, p.z, p.y end
    mob.x, mob.y, mob.z = x, y, z
    mob.yaw = a
    mob.state, mob.t0, mob.dur, mob.spd = SIT, t, 0, 0
    mob.holder = nil
    mob.gold = not any_gold()
    mob.wake = t + 1
    mob.thinkAt = t + THINK_EVERY
    dirty = true
end

local function award(globalIndex, points)
    if globalIndex == nil then return end
    hostGot[globalIndex] = (hostGot[globalIndex] or 0) + points
    publish_got()
end

local function gone(mob, t)
    mob.state, mob.holder = GONE, nil
    mob.back = t + BACK_AFTER
    dirty = true
end

local function mario_of(globalIndex)
    local li = globalIndex ~= nil and OF.util.local_from_global(globalIndex) or nil
    if li == nil then return nil, nil end
    return gMarioStates[li], li
end

local function holding(globalIndex)
    for _, mob in pairs(hostMobs) do
        if mob.state == HELD and mob.holder == globalIndex then return mob end
    end
    return nil
end

local function drop(mob, t)
    local m = mario_of(mob.holder)
    local x, y, z = mob.x, mob.y, mob.z
    if m ~= nil and m.pos ~= nil then
        x, z = m.pos.x, m.pos.z
        y = OF.util.optional("find_floor_height", nil, x, m.pos.y + 100, z)
        if type(y) ~= "number" or y < m.pos.y - 2000 then y = m.pos.y end
    end
    mob.dropBy, mob.dropAt = mob.holder, t
    mob.holder = nil
    mob.x, mob.y, mob.z = x, y, z
    mob.state, mob.t0, mob.dur = SIT, t, 0
    mob.wake = t + STAND_LEAST
    dirty = true
end
local mode_drop = drop

local function host_tick(t)

    if not OF.gamemodes.asks_the_room() then return end
    hostFrame = hostFrame + 1
    for _, mob in pairs(hostMobs) do
        if mob.state == GONE then
            if t >= (mob.back or 0) then
                local p = respawn_spot(mob.id, t)
                if p ~= nil then place(mob, p, t) end
            end
        elseif mob.state == HELD then

            local m, li = mario_of(mob.holder)
            if m == nil or li == nil or not gNetworkPlayers[li].connected
                or OF.gamemodes.role(li) ~= ROLE_CHASING or not OF.util.can_play(li) then
                drop(mob, t)
            end
        elseif t >= (mob.thinkAt or 0) then
            mob.thinkAt = t + THINK_EVERY
            if penguins() then think_penguin(mob, t) else think_rabbit(mob, t) end
        end
    end
    if dirty and hostFrame % PUBLISH_EVERY == 0 then
        dirty = false
        publish_all()
    end
end

local function host_claim(fromLocal, idText, what)

    if OF.util.is_host() and OF.gamemodes.room_by_lead() then
        local np = gNetworkPlayers[tonumber(fromLocal) or -1]
        if np == nil then return false, "Not chasing." end
        OF.gamemodes.hand_to_room("claim", { g = np.globalIndex,
            id = tostring(idText), w = tostring(what) })
        return true
    end
    if not OF.gamemodes.asks_the_room() then return false, "Only the host." end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "rabbitchase"
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return false, "No round."
    end
    local li = tonumber(fromLocal) or -1
    local np = gNetworkPlayers[li]
    local m = gMarioStates[li]
    if np == nil or m == nil or m.pos == nil or OF.gamemodes.role(li) ~= ROLE_CHASING then
        return false, "Not chasing."
    end
    local t = OF.gamemodes.since_start()
    local mob = hostMobs[tonumber(idText) or -1]
    if mob == nil then return false, "No such animal." end
    what = tostring(what)
    if what == "d" then
        local home = pen()
        if home == nil or mob.state ~= HELD or mob.holder ~= np.globalIndex then
            return false, "Not carrying it."
        end
        local dx, dz = m.pos.x - home.x, m.pos.z - home.z
        if dx * dx + dz * dz > (PEN_RADIUS + CLAIM_SLACK) ^ 2 then return false, "Not home." end
        award(np.globalIndex, mob.gold and GOLD_POINTS or 1)
        gone(mob, t)
        return true
    end
    if mob.state ~= SIT and mob.state ~= RUN then return false, "Already taken." end
    local x, _, z = mob_at(mob, t)
    if (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 > CLAIM_SLACK * CLAIM_SLACK then
        return false, "Not near it."
    end
    if what == "p" then
        if not penguins() or holding(np.globalIndex) ~= nil then return false, "Hands full." end
        if mob.dropBy == np.globalIndex and t - (mob.dropAt or -99) < DROP_COOLDOWN then
            return false, "Just dropped it."
        end
        mob.state, mob.holder = HELD, np.globalIndex
        mob.x, mob.z = x, z
        dirty = true
        return true
    end
    if penguins() then return false, "Carry it home." end
    award(np.globalIndex, mob.gold and GOLD_POINTS or 1)
    gone(mob, t)
    return true
end

local registered = false
local function register_claim()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action(CLAIM_ACTION, "round_move", host_claim)
end

local function on_pvp_tag(attacker, victim)
    if attacker == nil or victim == nil then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "rabbitchase" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.is_host() then return end
    local np = gNetworkPlayers[victim.playerIndex]
    if np == nil then return end

    if OF.gamemodes.room_by_lead() then
        OF.gamemodes.hand_to_room("tag", { v = np.globalIndex })
        return
    end
    local mob = holding(np.globalIndex)
    if mob ~= nil then drop(mob, OF.gamemodes.since_start()) end
end

local function gone_obj(o)
    return o == nil or o.activeFlags == 0
end

local function unmake(o)
    if not gone_obj(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function clear_all()
    for id, o in pairs(drawn) do unmake(o) drawn[id] = nil end
    if mother ~= nil then unmake(mother) mother = nil end
end

local function dress(o, anims, index)
    local table_ = gObjectAnimations ~= nil and gObjectAnimations[anims] or nil
    if table_ == nil then return end
    o.oAnimations = table_
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, index, 1.0)
end

local function poof(x, y, z, rabbit)
    OF.util.optional("spawn_non_sync_object", nil, id_bhvStarKeyCollectionPuffSpawner,
        E_MODEL_NONE, x, y + 30, z, nil)
    OF.gamemodes.round_sound_throttled("rcpoof", 4,
        rabbit and SOUND_OBJ_MIPS_RABBIT or SOUND_OBJ2_BABY_PENGUIN_YELL, nil)
end

local function sparkle(x, y, z)
    local bhv = id_bhvSparkleSpawn or id_bhvSparkle
    if type(bhv) ~= "number" or type(E_MODEL_SPARKLES) ~= "number" then return end
    OF.slots.spawn_non_sync(bhv, E_MODEL_SPARKLES, x, y, z, nil)
end

local function held_at(mob)
    local m = mario_of(mob.holder)
    if m == nil or m.pos == nil then return nil end
    return m.pos.x, m.pos.y + CARRY_LIFT, m.pos.z, (m.faceAngle ~= nil and m.faceAngle.y or 0)
end

local function draw(t)
    local rabbit = not penguins()
    local model = rabbit and E_MODEL_MIPS or E_MODEL_PENGUIN
    local anims = rabbit and MIPS_ANIMS or PENGUIN_ANIMS
    local sparkleNow = t - sparkleAt > 0.25
    if sparkleNow then sparkleAt = t end
    for id, mob in pairs(mobs) do
        local was = wasState[id]
        wasState[id] = mob.state
        if mob.state == GONE then
            local o = drawn[id]
            if not gone_obj(o) and was ~= nil and was ~= GONE then
                poof(o.oPosX, o.oPosY, o.oPosZ, rabbit)
            end
            unmake(o)
            drawn[id] = nil
        else
            local x, y, z, yawS
            local moving = false
            if mob.state == HELD then
                local hx, hy, hz, hyaw = held_at(mob)
                if hx ~= nil then x, y, z, yawS = hx, hy, hz, hyaw end
            end
            if x == nil then
                x, y, z, moving = mob_at(mob, t)
                yawS = math.floor(mob.yaw * 32768 / math.pi) % 65536
            end
            local o = drawn[id]
            if gone_obj(o) then
                o = OF.slots.spawn_non_sync(id_bhvStaticObject, model, x, y, z, nil)
                drawn[id] = o

                if o ~= nil then dress(o, anims, rabbit and ANIM_SIT or ANIM_STAND) end
            end
            if o ~= nil then
                o.oPosX, o.oPosY, o.oPosZ = x, y, z
                o.oFaceAngleYaw = yawS
                o.oFaceAnglePitch, o.oFaceAngleRoll = 0, 0
                if o.oAnimations ~= nil then
                    local index = rabbit and (moving and ANIM_HOP or ANIM_SIT)
                        or (moving and ANIM_WALK or ANIM_STAND)
                    OF.util.optional("obj_init_animation_with_accel_and_sound", nil,
                        o, index, moving and 1.0 + mob.spd / 40 or 1.0)
                end
                OF.util.optional("obj_scale", nil, o, mob.gold and 1.3 or 1.0)
                if mob.gold and sparkleNow then sparkle(x, y + 60, z) end
                if moving and rabbit then
                    OF.gamemodes.round_sound_throttled("rchop" .. id, 24, SOUND_OBJ_MIPS_RABBIT, o)
                end
            end
        end
    end
    for id, o in pairs(drawn) do
        if mobs[id] == nil then unmake(o) drawn[id] = nil wasState[id] = nil end
    end

    local home = (not rabbit) and pen() or nil
    if home ~= nil then
        if gone_obj(mother) then
            mother = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_PENGUIN,
                home.x, home.y, home.z, nil)
            if mother ~= nil then dress(mother, PENGUIN_ANIMS, ANIM_STAND) end
        end
        if mother ~= nil then
            mother.oPosX, mother.oPosY, mother.oPosZ = home.x, home.y, home.z
            mother.oFaceAnglePitch, mother.oFaceAngleRoll = 0, 0
            OF.util.optional("obj_scale", nil, mother, 4.0)
        end
    elseif mother ~= nil then
        unmake(mother)
        mother = nil
    end
end

local function body_tall(m)
    if m.action ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0 then return MARIO_SHORT end
    return MARIO_TALL
end

local function touching(m)
    if m == nil or m.pos == nil then return nil end
    local tall = body_tall(m)
    local body = BODY[kind()]
    for _, id in ipairs(sorted_ids(mobs)) do
        local mob = mobs[id]
        local o = drawn[id]
        if (mob.state == SIT or mob.state == RUN) and not gone_obj(o) then
            local scale = mob.gold and 1.3 or 1.0
            local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
            local reach = body[1] * scale + MARIO_RADIUS
            if dx * dx + dz * dz < reach * reach
                and m.pos.y < o.oPosY + body[2] * scale and m.pos.y + tall > o.oPosY then
                return id
            end
        end
    end
    return nil
end

local function my_carry()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for id, mob in pairs(mobs) do
        if mob.state == HELD and mob.holder == np.globalIndex then return id end
    end
    return nil
end

local function ask(id, what, t)
    if asked[id] ~= nil and t - asked[id] < CLAIM_AGAIN then return false end
    asked[id] = t
    register_claim()
    if OF.util.asks(OF.net, "host_does") then
        OF.net.host_does(CLAIM_ACTION, id, what)
        return true
    end
    return false
end

local function judge_frame(t)
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_CHASING or not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local carrying = my_carry()
    if carrying ~= nil then
        local home = pen()
        if home ~= nil then
            local dx, dz = m.pos.x - home.x, m.pos.z - home.z
            if dx * dx + dz * dz < PEN_RADIUS * PEN_RADIUS
                and math.abs(m.pos.y - home.y) < PEN_TALL then
                ask(carrying, "d", t)
            end
        end
        return
    end
    local id = touching(m)
    if id ~= nil then ask(id, penguins() and "p" or "c", t) end
end

local mode = {
    key = "rabbitchase",
    name = "Rabbit Chase",
    blurb = "rabbits hop away from you - touch one to catch it",
    how = "Rabbits sit about the course and hop off when you near.\n"
        .. "Touch one and it is caught - a point to you.\n"
        .. "A caught rabbit comes back somewhere else soon after.\n"
        .. "The golden one is worth three, and it is quicker.\n"
        .. "With penguins: pick one up and carry it into the ring.\n"
        .. "A punch on a carrier makes them drop it.\n"
        .. "First to the target wins, or the most at the clock.",
    aims = { [ROLE_CHASING] = "Catch the rabbits - corner them, cut them off." },
    minPlayers = 2,
    maps = "surveyed",
    surveyKeys = { "points" },
    openCourses = true,

    roomsOut = {
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_BITDW, area = 1 },
        { level = LEVEL_BITFS, area = 1 }, { level = LEVEL_TTC, area = 1 },

        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },

        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },
    },
    room = { rules = { interactions = PLAYER_INTERACTIONS_PVP } },
    target = { name = "points to win",
               asks = "Points to win",
               default = DEFAULT_TARGET, min = 5, max = 30, step = 5 },
    options = {
        { key = "what", name = "What you chase",
          help = "rabbits caught on touch, or baby penguins carried home",
          choices = {
              { key = "rabbits", name = "rabbits",
                help = "they sit until you come near, then hop away" },
              { key = "penguins", name = "baby penguins",
                help = "pick one up, carry it into the big penguin's ring" },
          } },

        { key = "pace", name = "Rabbit speed",
          help = "how fast a rabbit hops away from you",
          shownIf = { what = "rabbits" },
          choices = {
              { key = "quick", name = "quick",
                help = "a run catches one that is cut off" },
              { key = "calm", name = "calm",
                help = "easy to run down - for a small lobby" },
              { key = "wild", name = "wild",
                help = "nearly as fast as you - cornering is the only way" },
          } },
    },
    defaultLimit = 180,
    music = SEQ_LEVEL_GRASS,
    teams = false,

    boardTitle = "Points",
}
mode.count_for = count_for
mode.hop_pace = hop_pace
mode.mob_at = mob_at
mode.pack_mob = pack_mob
mode.unpack_mob = unpack_mob
mode.hop_ok = hop_ok
mode.got_of = got_of
mode.host_claim = host_claim
mode.drop = mode_drop

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_CHASING)
    end
    OF.util.publish(TARGET_KEY, options.target or DEFAULT_TARGET)
end

function mode.pin()
    hostNoPoints = false
    hostMobs, hostGot, dirty = {}, {}, false
    local here = OF.gamemodes.here_place(0)
    local points = here ~= nil and OF.gamemodes.surveyed_list(here, "points", 16) or nil
    if points == nil or points[1] == nil then
        hostNoPoints = true
        OF.util.publish(PTS_KEY, nil)
        return
    end
    OF.util.publish(PTS_KEY, OF.gamemodes.pack_points(points))
    OF.util.publish(AT_KEY, tostring(here.level) .. "." .. tostring(here.area))
    publish_got()
    local carry = penguins()
    if carry then
        local cx, cz = 0, 0
        for _, p in ipairs(points) do cx, cz = cx + p.x, cz + p.z end
        cx, cz = cx / #points, cz / #points
        local best, bestD = points[1], nil
        for _, p in ipairs(points) do
            local d = (p.x - cx) ^ 2 + (p.z - cz) ^ 2
            if bestD == nil or d < bestD then best, bestD = p, d end
        end
        OF.util.publish(PEN_KEY, OF.gamemodes.pack_points({ best }))
    else
        OF.util.publish(PEN_KEY, nil)
    end
    local n = count_for(#chasers(), carry)
    for id = 1, n do
        local mob = { id = id }
        hostMobs[id] = mob
        local p = points[((id - 1) % #points) + 1]
        if carry then p = respawn_spot(id, id) or p end
        place(mob, p, 0)
    end
    publish_all()
end

function mode.on_start()
    mobs, wireSeen, asked, wasState = {}, nil, {}, {}
    sparkleAt, seenGot = 0, -1
    clear_all()
    register_claim()
    goldSaid = false

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_CHASING)

    local np = gNetworkPlayers[localIndex]
    if OF.util.is_host() and np ~= nil and OF.gamemodes.room_by_lead() then

        OF.gamemodes.hand_to_room("late", { g = np.globalIndex })
    elseif OF.util.is_host() and np ~= nil then
        hostGot[np.globalIndex] = 0
        publish_got()
    end
    return ROLE_CHASING
end

function mode.scenery()

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE and not OF.util.is_host()
        and OF.gamemodes.room_by_global() ~= nil and OF.gamemodes.asks_the_room() then
        OF.gamemodes.room_publish(host_tick, OF.gamemodes.since_start())
    end
    if OF.gamemodes.state() == OF.gamemodes.OFF or origin() == nil
        or not here_ok(0) or not OF.util.round_screen() then
        clear_all()
        return
    end
    local t = OF.gamemodes.since_start()
    listen()
    draw(t)
    judge_frame(t)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil then return end
    if OF.gamemodes.role(0) ~= ROLE_CHASING then return end
    local got = got_of(np.globalIndex)
    if got ~= points_of(0) then

        if got > points_of(0) and seenGot >= 0 then
            OF.gamemodes.cue("good")
        end
        OF.util.publish_row(0, "ofScore", got)
    end
    seenGot = got

    local carrying = my_carry()
    if carrying ~= nil and m.forwardVel ~= nil and m.forwardVel > CARRY_TOP
        and m.action ~= nil and (m.action & ACT_FLAG_AIR) == 0 then
        m.forwardVel = CARRY_TOP
    end

    if carrying ~= nil and m.pos ~= nil then
        for _, entry in ipairs(chasers()) do
            local other = gMarioStates[entry.localIndex]
            if entry.localIndex ~= 0 and other ~= nil and other.pos ~= nil then
                local dx, dz = other.pos.x - m.pos.x, other.pos.z - m.pos.z
                if dx * dx + dz * dz < 300 * 300 then
                    OF.gamemodes.cue("hazard", nil, "rcnear")
                    break
                end
            end
        end
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoPoints then
        OF.gamemodes.abandon("No spread of points was found on this course.")
        return
    end
    host_tick(OF.gamemodes.since_start())
    local target = target_points()
    for _, entry in ipairs(chasers()) do
        local got = entry.np ~= nil and got_of(entry.np.globalIndex) or 0
        if got >= target then
            OF.gamemodes.finish("@ reached @ points and won.",
                entry.np.name, entry.np.name, tostring(got))
            return
        end
    end
end

function mode.still_winnable()
    return #chasers() >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ points, or most at the clock", tostring(target_points()))
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(chasers(),
        function(entry) return entry.np ~= nil and got_of(entry.np.globalIndex) or 0 end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish(penguins() and "Nobody brought a penguin home." or "Nobody caught a rabbit.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points.", names[1], names[1])
    end
end

function mode.hud()
    if not here_ok(0) then
        OF.gamemodes.away_banner(penguins() and "The penguins are somewhere else"
            or "The rabbits are somewhere else")
        return
    end
    local carry = penguins()
    local home = carry and pen() or nil
    local playing = OF.gamemodes.role(0) == ROLE_CHASING
    local goldLoose = false
    for _, mob in pairs(mobs) do
        if mob.gold and (mob.state == SIT or mob.state == RUN) then goldLoose = true end
    end

    if goldLoose and not goldSaid then
        goldSaid = true
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("GOLDEN"),
                OF.lang.t(carry and "A golden penguin - worth three" or "A golden rabbit - worth three"))
        end
    elseif not goldLoose then
        goldSaid = false
    end
    if playing and OF.util.asks(OF.hud, "state_line") then
        if my_carry() ~= nil then
            OF.hud.state_line("carry", OF.lang.t("Carrying"), { prio = 70, tone = "target" })
        elseif goldLoose then
            OF.hud.state_line("golden", OF.lang.t("Golden"), { prio = 50, tone = "target" })
        end
    end

    if home ~= nil and not OF.util.asks(OF.markers, "ring") then
        local r, g, b = OF.util.round_tone("good")
        OF.util.zone_ring(home, PEN_RADIUS, 40, 4, r, g, b, 230)
    end
    if carry and playing then
        OF.util.legend({ OF.lang.t("Touch a penguin - pick it up"),
            OF.lang.t("B - punch a carrier: they drop it"),
            OF.lang.t("Into the ring - it counts") })
    end

end

function mode.cleanup()
    clear_all()
    if OF.util.is_host() then
        for _, key in ipairs(KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
    hostMobs, hostGot, dirty, hostNoPoints = {}, {}, false, false
    mobs, wireSeen, asked, wasState = {}, nil, {}, {}
    poolText, poolList = nil, nil
    sparkleAt, seenGot = 0, -1
    return true
end

mode.leadPin = {
    keys = { KEYS[1], KEYS[2], KEYS[3], PTS_KEY, AT_KEY, GOT_KEY, PEN_KEY },
    handover = "repin",
    facts = function()
        local said = { nopoints = hostNoPoints and 1 or nil }
        hostNoPoints = false
        return said
    end,
    take = function(facts)
        hostNoPoints = facts.nopoints ~= nil
    end,
    handed = function(tag, f)
        local t = OF.gamemodes.since_start()
        if tag == "claim" then
            local li = OF.util.local_from_global(tonumber(f.g) or -1)
            if li ~= nil then OF.gamemodes.room_publish(host_claim, li, f.id, f.w) end
        elseif tag == "tag" then
            local mob = holding(tonumber(f.v))
            if mob ~= nil then drop(mob, t) end
        elseif tag == "late" and tonumber(f.g) ~= nil then
            hostGot[tonumber(f.g)] = 0
            OF.gamemodes.room_publish(publish_got)
        end
    end,
}

mode.on_tag = function(a, v)
    return on_pvp_tag(gMarioStates[a], gMarioStates[v])
end

local goldTarget = { id = "golden", label = "golden one", tone = "target",
    priority = 80, compass = "offscreen" }
local penTarget = { id = "pen", label = "the pen", tone = "good",
    ring = { radius = PEN_RADIUS } }
local rabbitList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #rabbitList, 1, -1 do rabbitList[i] = nil end
    if not here_ok(0) then return nil end
    for _, mob in pairs(mobs) do
        if mob.gold and (mob.state == SIT or mob.state == RUN) then
            local o = drawn[mob.id]
            if not gone_obj(o) then
                goldTarget.pos = { x = o.oPosX, y = o.oPosY, z = o.oPosZ }
                rabbitList[#rabbitList + 1] = goldTarget
                break
            end
        end
    end
    local home = penguins() and pen() or nil
    if home ~= nil then
        local carrying = OF.gamemodes.role(0) == ROLE_CHASING and my_carry() ~= nil
        penTarget.pos = home
        penTarget.priority = carrying and 95 or 40
        penTarget.compass = carrying and "offscreen" or "never"
        rabbitList[#rabbitList + 1] = penTarget
    end
    return rabbitList
end

OF.gamemodes.register(mode)
