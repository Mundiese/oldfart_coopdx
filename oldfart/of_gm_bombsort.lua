OF = OF or {}

local ROLE_SORTING = "sorting"
local DEFAULT_TARGET = 20

local PLACES = {
    empty = { x = 0, y = 0, z = 0 },
}

local PLACE_ORDER = { "empty" }

local PEN_OFF = 1250
local PEN_RADIUS = 330

local WALL_CELL = 200
local OUTER_HALF = 2000
local OUTER_TALL = 2

local WALL_LOOK = { outer = "blkbrickdarkgrey" }
local WALL_MESH = "breakable_box_seg8_collision_08012D70"
local WALK_RADIUS = 850

local START_RING = 650

local FLOW_BASE, FLOW_PER = 0.3, 0.15
local FLOW_GROWS = 0.5
local FLOW_FULL = 120
local OUT_BASE, OUT_PER = 4, 2
local WIRE_MOST = 36

local FUSE_START, FUSE_LEAST, FUSE_FULL = 14, 9, 150
local FLASH = 2.5

local WALK = 5
local TURN_LEAST, TURN_MOST = 2, 4

local THROW_BASE, THROW_PER = 480, 10
local THROW_TIME = 0.75
local THROW_HIGH = 200

local HAND_FWD, HAND_UP = 55, 75

local PICK_REACH = 170

local BLAST_RADIUS = 150 + 37
local BLAST_TALL = 300
local BLAST_HOLD = 0.3

local CLAIM_SLACK = 500
local CLAIM_ACTION = "bsclaim"
local CLAIM_AGAIN = 0.4

local GONE_KEEP = 1.5

local BOBOMB_ANIMS = "bobomb_seg8_anims_0802396C"
local ANIM_WALK = 0
local STAND_RATE, WALK_RATE, FLASH_RATE = 0.4, 1.0, 3.0

local KEYS = { "ofBsBombs", "ofBsBombs2", "ofBsBombs3", "ofBsBombs4", "ofBsBombs5",
    "ofBsBombs6" }
local AT_KEY = "ofBsAt"
local GOT_KEY = "ofBsGot"
local TARGET_KEY = "ofBsTo"
local ROUND_KEYS = { "ofBsAt", "ofBsGot", "ofBsTo" }
local CHUNK = 168
local ENTRY = 24
local OFFSET = 23000
local PUBLISH_EVERY = 3

local WALKING, HELD, FLYING, GONE = 0, 1, 2, 3
local SORTED, BLEW = 0, 1

local hostBombs = {}
local hostNext = 1
local hostSpawnAt = 0
local hostFrame = 0
local dirty = false
local hostGot = {}
local hostNoRoom = false

local bombs = {}
local wireSeen = nil
local drawn = {}
local blasts = {}
local booms = {}
local asked = {}
local seenState = {}
local seenGot = -1
local myThrow = nil
local myThrowAt = 0
local wasHolding = false
local heldFor = nil
local lastSpeed = 0
local posts = {}

local wallSoc = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    drawn, booms, posts, wallSoc = {}, {}, {}, {}
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

local function every_for(players, t)
    local rate = FLOW_BASE + FLOW_PER * math.max(players or 0, 1)
    rate = rate * (1 + FLOW_GROWS * math.min(math.max(t or 0, 0) / FLOW_FULL, 1))
    return 1 / rate
end

local function most_for(players)
    return math.min(OUT_BASE + OUT_PER * math.max(players or 0, 1), WIRE_MOST)
end

local function fuse_at(t)
    local share = math.min(math.max(t or 0, 0) / FUSE_FULL, 1)
    return FUSE_START + (FUSE_LEAST - FUSE_START) * share
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

local function sorters()
    return OF.gamemodes.with_role(ROLE_SORTING)
end

local function field()
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "string" then return nil end
    local key = string.match(at, "^(%S+)")
    return key ~= nil and PLACES[key] or nil
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)$")
    return level ~= nil and np.currLevelNum == tonumber(level)
        and np.currAreaIndex == tonumber(area)
end

local function pen_of(f, pink)
    return { x = f.x + (pink and PEN_OFF or -PEN_OFF), y = f.y, z = f.z }
end

local function in_pen(f, x, z, pink)
    local p = pen_of(f, pink)
    local dx, dz = x - p.x, z - p.z
    return dx * dx + dz * dz <= PEN_RADIUS * PEN_RADIUS
end

local function bomb_at(b, t, f)
    local floorY = f ~= nil and f.y or b.y
    if b.state == FLYING then
        local s = math.min(math.max((t - b.t0) / math.max(b.time, 0.05), 0), 1)
        local d = b.dist * s
        local y = b.y + (floorY - b.y) * s + 4 * THROW_HIGH * s * (1 - s)
        return b.x + math.sin(b.yaw) * d, y, b.z + math.cos(b.yaw) * d
    end
    if b.state == WALKING then
        local walked = math.max(t - b.t0, 0) * 30 * WALK
        return b.x + math.sin(b.yaw) * walked, floorY, b.z + math.cos(b.yaw) * walked
    end
    return b.x, b.y, b.z
end

local function hands_of(globalIndex)
    local li = globalIndex ~= nil and OF.util.local_from_global(globalIndex) or nil
    local m = li ~= nil and gMarioStates[li] or nil
    if m == nil or m.pos == nil then return nil end
    local yaw = (m.faceAngle ~= nil and m.faceAngle.y or 0) / 32768 * math.pi
    return m.pos.x + math.sin(yaw) * HAND_FWD, m.pos.y + HAND_UP,
        m.pos.z + math.cos(yaw) * HAND_FWD, m
end

local function pack_bomb(b, f)
    local who = b.holder ~= nil and (b.holder + 1) or 0
    return to36(b.id % 1296, 2)
        .. to36(b.state * 2 + (b.pink and 1 or 0), 1)
        .. to36(b.x - f.x + OFFSET, 3) .. to36(b.z - f.z + OFFSET, 3)
        .. to36(b.y - f.y + OFFSET, 3)
        .. to36(math.floor((b.yaw % (2 * math.pi)) / (2 * math.pi) * 1296 + 0.5) % 1296, 2)
        .. to36(b.t0 * 10, 3) .. to36(b.boom * 10, 3) .. to36(who, 1)
        .. to36(b.dist or 0, 2) .. to36((b.time or 0) * 10, 1)
end

local function unpack_bomb(e, f)
    if #e ~= ENTRY then return nil end
    local sp = from36(string.sub(e, 3, 3))
    local who = from36(string.sub(e, 21, 21))
    return { id = from36(string.sub(e, 1, 2)),
             state = math.floor(sp / 2), pink = sp % 2 == 1,
             x = from36(string.sub(e, 4, 6)) - OFFSET + f.x,
             z = from36(string.sub(e, 7, 9)) - OFFSET + f.z,
             y = from36(string.sub(e, 10, 12)) - OFFSET + f.y,
             yaw = from36(string.sub(e, 13, 14)) / 1296 * 2 * math.pi,
             t0 = from36(string.sub(e, 15, 17)) / 10,
             boom = from36(string.sub(e, 18, 20)) / 10,
             holder = who > 0 and (who - 1) or nil,
             dist = from36(string.sub(e, 22, 23)),
             time = from36(string.sub(e, 24, 24)) / 10 }
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
    for _, id in ipairs(sorted_ids(hostBombs)) do
        parts[#parts + 1] = pack_bomb(hostBombs[id], f)
    end
    local chunks = OF.util.chunk_parts(parts, CHUNK) or {}
    for index, key in ipairs(KEYS) do
        OF.util.publish(key, chunks[index])
    end
end

local GOT_BIAS = 648

local function publish_got()
    local out = {}
    for g = 0, 15 do
        local packed = (hostGot[g] or 0) + GOT_BIAS
        out[#out + 1] = to36(math.max(0, math.min(packed, 1295)), 2)
    end
    OF.util.publish(GOT_KEY, table.concat(out))
end

local function got_of(globalIndex)
    local text = gGlobalSyncTable[GOT_KEY]
    if type(text) ~= "string" or globalIndex == nil then return 0 end
    local at = globalIndex * 2 + 1
    if #text < at + 1 then return 0 end
    return from36(string.sub(text, at, at + 1)) - GOT_BIAS
end

local function listen()
    local f = field()
    if f == nil then return end
    local text = OF.util.joined(KEYS)
    if text == wireSeen then return end
    wireSeen = text
    local seen = {}
    for i = 1, #text - ENTRY + 1, ENTRY do
        local b = unpack_bomb(string.sub(text, i, i + ENTRY - 1), f)
        if b ~= nil then
            bombs[b.id] = b
            seen[b.id] = true
        end
    end
    for id in pairs(bombs) do
        if not seen[id] then bombs[id] = nil end
    end
end

local function award(globalIndex, delta)
    if globalIndex == nil then return end
    hostGot[globalIndex] = (hostGot[globalIndex] or 0) + delta
    publish_got()
end

local function new_walk(b, t, f, salt)
    local x, _, z = bomb_at(b, t, f)
    local a = seeded01(b.id, math.floor(t * 10) + (salt or 0), 3) * 2 * math.pi
    local r = math.sqrt(seeded01(b.id, math.floor(t * 10), 4)) * WALK_RADIUS * 0.6
    local tx, tz = f.x + math.sin(a) * r, f.z + math.cos(a) * r
    b.x, b.y, b.z = x, f.y, z
    b.yaw = math.atan(tx - x, tz - z) % (2 * math.pi)
    b.t0, b.state, b.holder, b.dist, b.time = t, WALKING, nil, 0, 0
    b.turnAt = t + TURN_LEAST + (TURN_MOST - TURN_LEAST) * seeded01(b.id, math.floor(t), 5)
    dirty = true
end

local function spawn_one(t, f)
    local id = hostNext
    hostNext = hostNext % 1295 + 1
    local b = { id = id, pink = seeded01(id, math.floor(t * 10), 1) < 0.5,
        x = f.x, y = f.y, z = f.z, yaw = 0, t0 = t, boom = t + fuse_at(t) }
    hostBombs[id] = b
    new_walk(b, t, f, 7)
    return b
end

local function gone(b, t, why, x, z)
    b.x, b.z = x or b.x, z or b.z
    b.y = field() ~= nil and field().y or b.y
    b.state, b.holder, b.dist, b.time = GONE, nil, why, 0
    b.t0 = t
    dirty = true
end

local function mario_of(globalIndex)
    local li = globalIndex ~= nil and OF.util.local_from_global(globalIndex) or nil
    if li == nil then return nil, nil end
    return gMarioStates[li], li
end

local function holding(globalIndex)
    for _, b in pairs(hostBombs) do
        if b.state == HELD and b.holder == globalIndex then return b end
    end
    return nil
end

local function let_go(b, t, f)
    local m = mario_of(b.holder)
    if m ~= nil and m.pos ~= nil then
        local yaw = (m.faceAngle ~= nil and m.faceAngle.y or 0) / 32768 * math.pi
        b.x, b.z = m.pos.x + math.sin(yaw) * 80, m.pos.z + math.cos(yaw) * 80
    end
    b.thrower = nil
    new_walk(b, t, f, 11)
end

local function host_tick(t)
    if not OF.util.is_host() then return end
    local f = field()
    if f == nil then return end
    hostFrame = hostFrame + 1
    local out = 0
    for id, b in pairs(hostBombs) do
        if b.state == GONE then
            if t - b.t0 > GONE_KEEP then
                hostBombs[id] = nil
                dirty = true
            end
        else
            out = out + 1
            if t >= b.boom then

                local x, _, z = bomb_at(b, t, f)
                if b.state == HELD then
                    local hx, _, hz = hands_of(b.holder)
                    if hx ~= nil then x, z = hx, hz end
                    award(b.holder, -1)
                end
                gone(b, t, BLEW, x, z)
            elseif b.state == HELD then
                local m, li = mario_of(b.holder)
                if m == nil or li == nil or not gNetworkPlayers[li].connected
                    or OF.gamemodes.role(li) ~= ROLE_SORTING or not OF.util.can_play(li) then
                    let_go(b, t, f)
                end
            elseif b.state == FLYING then
                if t >= b.t0 + b.time then
                    local x, _, z = bomb_at(b, b.t0 + b.time, f)
                    if in_pen(f, x, z, b.pink) then
                        award(b.thrower, 1)
                        gone(b, t, SORTED, x, z)
                    elseif in_pen(f, x, z, not b.pink) then
                        award(b.thrower, -1)
                        gone(b, t, BLEW, x, z)
                    else
                        b.x, b.z = x, z
                        b.thrower = nil
                        new_walk(b, t, f, 13)
                    end
                end
            elseif b.state == WALKING then
                local x, _, z = bomb_at(b, t, f)
                local dx, dz = x - f.x, z - f.z
                local outward = math.sin(b.yaw) * dx + math.cos(b.yaw) * dz > 0
                if t >= (b.turnAt or 0)
                    or (outward and dx * dx + dz * dz > WALK_RADIUS * WALK_RADIUS) then
                    new_walk(b, t, f, 17)
                end
            end
        end
    end
    local players = #sorters()
    if out < most_for(players) and t >= hostSpawnAt then
        hostSpawnAt = t + every_for(players, t)
        spawn_one(t, f)
    end
    if dirty and hostFrame % PUBLISH_EVERY == 0 then
        dirty = false
        publish_all()
    end
end

local function host_claim(fromLocal, idText, extra)
    if not OF.util.is_host() then return false, "Only the host." end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "bombsort"
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return false, "No round."
    end
    local f = field()
    local li = tonumber(fromLocal) or -1
    local np = gNetworkPlayers[li]
    local m = gMarioStates[li]
    if f == nil or np == nil or m == nil or m.pos == nil
        or OF.gamemodes.role(li) ~= ROLE_SORTING then
        return false, "Not sorting."
    end
    local t = OF.gamemodes.since_start()
    local idNumber = tonumber(idText) or -1
    local what = "p"
    local packed = tonumber(extra)
    if idNumber >= 100000 then
        what = idNumber >= 200000 and "z" or "t"
        idNumber = idNumber % 100000
    end
    local b = hostBombs[idNumber]
    if b == nil then return false, "No such Bob-omb." end
    if what == "t" or what == "z" then
        if b.state ~= HELD or b.holder ~= np.globalIndex then return false, "Not holding it." end
        if what == "z" then
            let_go(b, t, f)
            return true
        end
        local yawUnits = math.floor((packed or 0) / 64)
        local speed = math.min(math.max((packed or 0) % 64, 0), 48)
        local yaw = (yawUnits % 1296) / 1296 * 2 * math.pi
        local hx, hy, hz = hands_of(np.globalIndex)
        b.x, b.y, b.z = hx or m.pos.x, hy or (m.pos.y + HAND_UP), hz or m.pos.z
        b.yaw, b.t0, b.state, b.holder = yaw, t, FLYING, nil
        b.dist = math.floor(THROW_BASE + THROW_PER * speed)
        b.time = THROW_TIME
        b.thrower = np.globalIndex
        dirty = true
        return true
    end
    if b.state ~= WALKING then return false, "Already taken." end
    if holding(np.globalIndex) ~= nil then return false, "Hands full." end
    local x, _, z = bomb_at(b, t, f)
    if (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 > CLAIM_SLACK * CLAIM_SLACK then
        return false, "Not near it."
    end
    b.x, b.z, b.state, b.holder = x, z, HELD, np.globalIndex
    b.t0 = t
    dirty = true
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
    if current == nil or current.key ~= "bombsort" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.is_host() then return end
    local np = gNetworkPlayers[victim.playerIndex]
    local f = field()
    if np == nil or f == nil then return end
    local b = holding(np.globalIndex)
    if b ~= nil then let_go(b, OF.gamemodes.since_start(), f) end
end

local function gone_obj(o)
    return o == nil or o.activeFlags == 0
end

local function unmake(o)
    if not gone_obj(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function clear_all()
    for id, o in pairs(drawn) do unmake(o) drawn[id] = nil end
    for i, boom in ipairs(booms) do unmake(boom.o) booms[i] = nil end

    for k, handle in pairs(wallSoc) do
        OF.util.optional("remove_static_object_collision", nil, handle)
        wallSoc[k] = nil
    end
    for i, o in pairs(posts) do unmake(o) posts[i] = nil end
end

local function pose(o)
    local anims = gObjectAnimations ~= nil and gObjectAnimations[BOBOMB_ANIMS] or nil
    if anims == nil then return end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, ANIM_WALK, 1.0)
end

local function bang(x, y, z, t)
    local o = OF.util.optional("spawn_non_sync_object", nil, id_bhvStaticObject,
        E_MODEL_EXPLOSION, x, y + 100, z, nil)
    if o ~= nil then
        OF.util.optional("obj_set_billboard", nil, o)
        o.oAnimState = 0
        booms[#booms + 1] = { o = o, frame = 0 }
    end
    blasts[#blasts + 1] = { x = x, y = y, z = z, t = t }
    OF.gamemodes.round_sound_throttled("bsboom", 3, SOUND_GENERAL2_BOBOMB_EXPLOSION, nil)
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil and (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 < 1500 * 1500 then
        OF.util.optional("set_environmental_camera_shake", nil, SHAKE_ENV_EXPLOSION)
    end
end

local function sorted_puff(x, y, z)
    OF.util.optional("spawn_non_sync_object", nil, id_bhvStarKeyCollectionPuffSpawner,
        E_MODEL_NONE, x, y + 40, z, nil)
end

local function wall_init(o)
    if o == nil then return end
    local data = _G["gGlobalObjectCollisionData"]
    o.collisionData = data ~= nil and data[WALL_MESH] or nil
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = 0, 0, 0
    o.oMoveAnglePitch, o.oMoveAngleYaw, o.oMoveAngleRoll = 0, 0, 0
    if o.collisionData ~= nil then
        local handle = OF.util.optional("load_static_object_collision", nil)
        if handle ~= nil then wallSoc[math.floor(tonumber(o.oBehParams) or 0)] = handle end
    end
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end
local WALL_BHV = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    wall_init, nil, "of sort wall")

local function wall_model(which)
    local entry = OF.util.asks(OF.spawner, "block_entry") and OF.spawner.block_entry(WALL_LOOK[which]) or nil
    local id = entry ~= nil and entry.model or nil
    if id == nil then
        local geo = OF.util.asks(OF.spawner, "block_geo") and OF.spawner.block_geo(WALL_LOOK[which]) or nil
        id = geo ~= nil and OF.util.optional("smlua_model_util_get_id", nil, geo) or nil
        if id == E_MODEL_ERROR_MODEL then id = nil end
    end
    return id
end

local function wall_spots(f)
    local n = math.floor(2 * OUTER_HALF / WALL_CELL + 0.5)
    local out = {}
    for layer = 0, OUTER_TALL - 1 do
        local y = f.y + layer * WALL_CELL
        for i = 0, n - 1 do
            local along = -OUTER_HALF + i * WALL_CELL

            out[#out + 1] = { x = f.x + along, y = y, z = f.z - OUTER_HALF }
            out[#out + 1] = { x = f.x + OUTER_HALF, y = y, z = f.z + along }
            out[#out + 1] = { x = f.x - along, y = y, z = f.z + OUTER_HALF }
            out[#out + 1] = { x = f.x - OUTER_HALF, y = y, z = f.z - along }
        end
    end
    return out
end

local function draw_posts(f)
    if posts[1] ~= nil and not gone_obj(posts[1]) then return end
    if WALL_BHV == nil then return end
    local fit = 1
    if OF.util.asks(OF.spawner, "build_fit") then fit = OF.spawner.build_fit(0) or 1 end
    local model = wall_model("outer")
    if model == nil then return end
    for k, spot in ipairs(wall_spots(f)) do
        local index = k
        posts[index] = OF.slots.spawn_non_sync(WALL_BHV, model, spot.x, spot.y, spot.z,
            function(o)
                o.oBehParams = index
                OF.util.optional("obj_scale", nil, o, fit)
            end)
    end
end

local function draw(t, f)
    draw_posts(f)
    for id, b in pairs(bombs) do
        local was = seenState[id]
        seenState[id] = b.state
        if b.state == GONE then
            local o = drawn[id]
            if was ~= nil and was ~= GONE then
                if b.dist == BLEW then
                    bang(b.x, b.y, b.z, t)
                else
                    sorted_puff(b.x, b.y, b.z)
                    OF.gamemodes.round_sound_throttled("bssort", 4, SOUND_GENERAL_COIN_SPURT, nil)
                end
            end
            unmake(o)
            drawn[id] = nil
        else
            local x, y, z
            if b.state == HELD then x, y, z = hands_of(b.holder) end
            if x == nil then x, y, z = bomb_at(b, t, f) end
            local o = drawn[id]
            if gone_obj(o) then
                o = OF.slots.spawn_non_sync(id_bhvStaticObject,
                    b.pink and E_MODEL_BOBOMB_BUDDY or E_MODEL_BLACK_BOBOMB, x, y, z, nil)
                drawn[id] = o

                if o ~= nil then pose(o) end
            end
            if o ~= nil then
                local flashing = t >= b.boom - FLASH
                o.oPosX, o.oPosY, o.oPosZ = x, y, z
                o.oFaceAnglePitch, o.oFaceAngleRoll = 0, 0
                if b.state == HELD then
                    local hm = select(4, hands_of(b.holder))
                    if hm ~= nil and hm.faceAngle ~= nil then o.oFaceAngleYaw = hm.faceAngle.y end
                else
                    o.oFaceAngleYaw = math.floor(b.yaw * 32768 / math.pi) % 65536
                end
                if o.oAnimations ~= nil then
                    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, ANIM_WALK,
                        flashing and FLASH_RATE or (b.state == WALKING and WALK_RATE or STAND_RATE))
                end
                local scale = 1.0
                if flashing and math.floor(t * 12) % 2 == 0 then scale = 1.3 end
                OF.util.optional("obj_scale", nil, o, scale)
                if flashing then

                    OF.gamemodes.round_sound_from(o, SOUND_AIR_BOBOMB_LIT_FUSE)
                end
            end
        end
    end
    for id, o in pairs(drawn) do
        if bombs[id] == nil then unmake(o) drawn[id] = nil seenState[id] = nil end
    end
    local live = {}
    for _, boom in ipairs(booms) do
        boom.frame = boom.frame + 1
        if boom.frame >= 9 or gone_obj(boom.o) then
            unmake(boom.o)
        else
            boom.o.oAnimState = boom.frame
            live[#live + 1] = boom
        end
    end
    booms = live
end

local function my_bomb()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for id, b in pairs(bombs) do
        if b.state == HELD and b.holder == np.globalIndex then return id end
    end
    return nil
end

local function ask(id, extra, t)
    local key = tostring(id)
    if asked[key] ~= nil and t - asked[key] < CLAIM_AGAIN then return false end
    asked[key] = t
    register_claim()
    if OF.util.asks(OF.net, "host_does") then
        OF.net.host_does(CLAIM_ACTION, id, extra)
        return true
    end
    return false
end

local HOLD_OF = {}
local HOLDS = {}
local function holds()
    if next(HOLD_OF) ~= nil then return end
    local pairs_ = {
        { "ACT_IDLE", "ACT_HOLD_IDLE" }, { "ACT_WALKING", "ACT_HOLD_WALKING" },
        { "ACT_DECELERATING", "ACT_HOLD_DECELERATING" }, { "ACT_FREEFALL", "ACT_HOLD_FREEFALL" },
        { "ACT_JUMP", "ACT_HOLD_JUMP" }, { "ACT_JUMP_LAND", "ACT_HOLD_JUMP_LAND" },
        { "ACT_FREEFALL_LAND", "ACT_HOLD_FREEFALL_LAND" },
        { "ACT_JUMP_LAND_STOP", "ACT_HOLD_JUMP_LAND_STOP" },
        { "ACT_FREEFALL_LAND_STOP", "ACT_HOLD_FREEFALL_LAND_STOP" },
        { "ACT_BUTT_SLIDE", "ACT_HOLD_BUTT_SLIDE" },
    }
    for _, pair in ipairs(pairs_) do
        local plain, hold = _G[pair[1]], _G[pair[2]]
        if type(plain) == "number" and type(hold) == "number" then
            HOLD_OF[plain] = hold
            HOLDS[hold] = true
        end
    end
    for _, name in ipairs({ "ACT_HOLD_BEGIN_SLIDING", "ACT_HOLD_BUTT_SLIDE_AIR",
        "ACT_HOLD_BUTT_SLIDE_STOP", "ACT_HOLD_QUICKSAND_JUMP_LAND",
        "ACT_HOLD_PANTING_UNUSED", "ACT_THROWING", "ACT_AIR_THROW", "ACT_PLACING_DOWN" }) do
        if type(_G[name]) == "number" then HOLDS[_G[name]] = true end
    end
end

local function bomb_in_reach(m)
    local best, bestD = nil, nil
    for _, id in ipairs(sorted_ids(bombs)) do
        local b = bombs[id]
        local o = drawn[id]
        if b.state == WALKING and not gone_obj(o) then
            local dx, dz = o.oPosX - m.pos.x, o.oPosZ - m.pos.z
            local d = dx * dx + dz * dz
            if d < PICK_REACH * PICK_REACH and math.abs(o.oPosY - m.pos.y) < 150
                and (bestD == nil or d < bestD) then
                best, bestD = id, d
            end
        end
    end
    return best
end

local function hands_frame(t, f)
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_SORTING or not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    holds()
    local mine = my_bomb()

    if mine ~= nil and myThrow == mine and t - myThrowAt > 1.0 then myThrow = nil end
    if mine == nil and wasHolding and HOLDS[m.action] and m.action ~= ACT_THROWING
        and m.action ~= ACT_AIR_THROW and m.action ~= ACT_PLACING_DOWN then

        set_mario_action(m, (m.action & ACT_FLAG_AIR) ~= 0 and ACT_FREEFALL or ACT_IDLE, 0)
    end
    wasHolding = mine ~= nil

    if mine ~= nil and heldFor ~= mine then
        heldFor = mine
        local air = m.action ~= nil and (m.action & ACT_FLAG_AIR) ~= 0
        local hold = air and ACT_HOLD_FREEFALL or ACT_HOLD_IDLE
        if hold ~= nil and not HOLDS[m.action] then set_mario_action(m, hold, 0) end
    elseif mine == nil then
        heldFor = nil
    end
    if mine ~= nil and myThrow ~= mine then
        local act = m.action
        if act == ACT_THROWING or act == ACT_AIR_THROW then
            myThrow, myThrowAt = mine, t
            local yawUnits = math.floor(((m.faceAngle.y or 0) % 65536) / 65536 * 1296 + 0.5) % 1296
            local speed = math.floor(math.min(math.max(lastSpeed, 0), 48))
            ask(100000 + mine, yawUnits * 64 + speed, t)
        elseif act == ACT_PLACING_DOWN then
            myThrow, myThrowAt = mine, t
            ask(200000 + mine, 0, t)
        elseif HOLD_OF[act] ~= nil then
            set_mario_action(m, HOLD_OF[act], 0)
        elseif not HOLDS[act] then

            myThrow, myThrowAt = mine, t
            ask(200000 + mine, 0, t)
        end
    elseif mine == nil then
        myThrow = nil
        if m.controller ~= nil and (m.controller.buttonPressed & B_BUTTON) ~= 0 then
            local best = bomb_in_reach(m)
            if best ~= nil then ask(best, 0, t) end
        end
    end
    lastSpeed = m.forwardVel or 0
end

local function judge_blasts(t)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local live = {}
    for _, blast in ipairs(blasts) do
        if t - blast.t <= BLAST_HOLD then
            live[#live + 1] = blast
            if not blast.judged and OF.gamemodes.role(0) == ROLE_SORTING
                and OF.util.can_play(0) and not OF.gamemodes.in_grace() then
                local dx, dz = m.pos.x - blast.x, m.pos.z - blast.z
                if dx * dx + dz * dz < BLAST_RADIUS * BLAST_RADIUS
                    and m.pos.y < blast.y + BLAST_TALL and m.pos.y + 160 > blast.y then
                    blast.judged = true
                    if atan2s ~= nil then m.faceAngle.y = atan2s(-dz, -dx) end
                    m.forwardVel = -28
                    m.vel.y = 32
                    if ACT_BACKWARD_AIR_KB ~= nil then set_mario_action(m, ACT_BACKWARD_AIR_KB, 0) end
                    OF.gamemodes.cue("bad")
                end
            end
        end
    end
    blasts = live
end

local mode = {
    key = "bombsort",
    name = "Bomb Sort",
    blurb = "carry each Bob-omb to its own pen before it blows",
    how = "Black and pink Bob-ombs walk out of the middle.\n"
        .. "B picks one up, B again throws it, Z sets it down.\n"
        .. "Black into the black pen, pink into the pink pen.\n"
        .. "Right pen: a point. Wrong pen: it blows up, a point off.\n"
        .. "A fuse that runs out blows it up - in your hands too.\n"
        .. "First to the target wins, or the most at the clock.",
    aims = { [ROLE_SORTING] = "Black to the black pen, pink to the pink pen." },
    minPlayers = 2,

    maps = { "empty" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_PVP } },
    target = { name = "points to win",
               asks = "How many points win the round",
               default = DEFAULT_TARGET, min = 5, max = 40, step = 5 },
    defaultLimit = 150,
    music = SEQ_EVENT_MERRY_GO_ROUND,
    teams = false,
    studio = { tint = { 150, 150, 140 } },
}
mode.every_for = every_for
mode.most_for = most_for
mode.fuse_at = fuse_at
mode.bomb_at = bomb_at
mode.pack_bomb = pack_bomb
mode.unpack_bomb = unpack_bomb
mode.got_of = got_of
mode.host_claim = host_claim
mode.award = award
mode.in_pen = in_pen
mode.wall_spots = wall_spots
mode.OUTER_HALF = OUTER_HALF
mode.wall_model = wall_model
mode.WALL_BHV = WALL_BHV
mode.WALL_LOOK = WALL_LOOK
mode.pen_of = pen_of
mode.PLACES = PLACES

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_SORTING)
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
    hostBombs, hostNext, hostSpawnAt, dirty, hostGot = {}, 1, 0, false, {}
    local key = place_here()
    if key == nil then
        hostNoRoom = true
        return
    end
    hostNoRoom = false
    local np = gNetworkPlayers[0]
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f", key, np.currLevelNum,
        np.currAreaIndex))
    publish_got()
end

local placed = false
local function place_me(f)
    if placed then return end
    local np = gNetworkPlayers[0]
    if np == nil or OF.gamemodes.role(0) ~= ROLE_SORTING then return end
    placed = true
    local a = (np.globalIndex or 0) / 16 * 2 * math.pi + math.pi / 2
    local x, z = f.x + math.sin(a) * START_RING, f.z + math.cos(a) * START_RING
    local yaw = math.atan(f.x - x, f.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
end

function mode.on_start()
    bombs, wireSeen, blasts, asked, seenState = {}, nil, {}, {}, {}
    seenGot, myThrow, lastSpeed, placed, wasHolding = -1, nil, 0, false, false
    heldFor = nil
    clear_all()
    register_claim()

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_SORTING)
    local np = gNetworkPlayers[localIndex]
    if OF.util.is_host() and np ~= nil then
        hostGot[np.globalIndex] = 0
        publish_got()
    end
    return ROLE_SORTING
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
    judge_blasts(t)
    hands_frame(t, f)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[0]
    if np == nil or OF.gamemodes.role(0) ~= ROLE_SORTING then return end
    local got = got_of(np.globalIndex)
    local had = points_of(0)
    if got ~= had then
        if seenGot >= 0 then

            if got > had then
                OF.gamemodes.cue("good")
            else
                OF.gamemodes.cue("bad")
            end
        end
        OF.util.publish_row(0, "ofScore", got)
    end
    seenGot = got

    local mine = my_bomb()
    if mine ~= nil and bombs[mine] ~= nil then
        local left = bombs[mine].boom - OF.gamemodes.since_start()
        if left < FLASH then OF.gamemodes.cue("hazard", nil, "bshot") end
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        OF.gamemodes.abandon("Bomb Sort is played in The Tiles.")
        return
    end
    host_tick(OF.gamemodes.since_start())
    local target = target_points()
    for _, entry in ipairs(sorters()) do
        local got = entry.np ~= nil and got_of(entry.np.globalIndex) or 0
        if got >= target then
            OF.gamemodes.finish("@ sorted @ and won.", entry.np.name, entry.np.name, tostring(got))
            return
        end
    end
end

function mode.still_winnable()
    return #sorters() >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ points, or most at the clock", tostring(target_points()))
end

mode.boardTitle = "Sorted"
function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(sorters(),
        function(entry) return entry.np ~= nil and got_of(entry.np.globalIndex) or 0 end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody sorted a Bob-omb.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points.", names[1], names[1])
    end
end

local labelAt = { x = 0, y = 0, z = 0 }
local labelScreen = { x = 0, y = 0, z = 0 }

local function pen_label(f, pink)
    local p = pen_of(f, pink)
    labelAt.x, labelAt.y, labelAt.z = p.x, p.y + 380, p.z
    if OF.util.world_screen(labelAt, labelScreen) then
        if pink then
            OF.util.world_label(labelScreen.x, labelScreen.y, OF.lang.t("PINK"), 1.0,
                255, 150, 210, 255)
        else
            OF.util.world_label(labelScreen.x, labelScreen.y, OF.lang.t("BLACK"), 1.0,
                235, 235, 235, 255)
        end
    end
end

function mode.hud()
    local f = field()
    if f == nil then return end
    if not here_ok(0) then
        OF.gamemodes.away_banner("The Bob-ombs are somewhere else")
        return
    end
    local playing = OF.gamemodes.role(0) == ROLE_SORTING
    local mine = my_bomb()

    if playing and mine ~= nil and bombs[mine] ~= nil and OF.util.asks(OF.hud, "state_line") then
        local b = bombs[mine]
        local left = math.max(0, math.ceil(b.boom - OF.gamemodes.since_start()))
        OF.hud.state_line("carry", b.pink and OF.lang.t("Pink") or OF.lang.t("Black"),
            { prio = 70, tone = b.pink and "warn" or "ink", colour = b.pink,
              figure = left, urgent = left <= FLASH })
    elseif playing and mine == nil and OF.util.asks(OF.hud, "prompt") then
        local m = gMarioStates[0]
        if m ~= nil and m.pos ~= nil and bomb_in_reach(m) ~= nil then
            OF.hud.prompt("attack", OF.lang.t("Pick up"), nil, { id = "bspick" })
        end
    end
    OF.util.zone_ring(pen_of(f, false), PEN_RADIUS, 40, 4, 235, 235, 235, 230)
    OF.util.zone_ring(pen_of(f, true), PEN_RADIUS, 40, 4, 255, 150, 210, 230)
    pen_label(f, false)
    pen_label(f, true)
    if playing then
        OF.util.legend({ OF.lang.t("B - pick up a Bob-omb"), OF.lang.t("B - throw it"),
            OF.lang.t("Z - set it down"), OF.lang.t("Black to black, pink to pink") })
    end

end

function mode.cleanup()
    clear_all()
    if OF.util.is_host() then
        for _, key in ipairs(KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end

    local m = gMarioStates[0]
    holds()
    if m ~= nil and wasHolding and HOLDS[m.action] then
        set_mario_action(m, (m.action & ACT_FLAG_AIR) ~= 0 and ACT_FREEFALL or ACT_IDLE, 0)
    end
    hostBombs, hostGot, dirty, hostNoRoom = {}, {}, false, false
    bombs, wireSeen, blasts, asked, seenState = {}, nil, {}, {}, {}
    seenGot, myThrow, lastSpeed, placed, wasHolding = -1, nil, 0, false, false
    heldFor = nil
    return true
end

mode.on_tag = function(a, v)
    return on_pvp_tag(gMarioStates[a], gMarioStates[v])
end

OF.gamemodes.register(mode)
