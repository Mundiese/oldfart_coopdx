OF = OF or {}
OF.blastgrid = OF.blastgrid or {}

local bg = OF.blastgrid

local ROLE_IN = "in"
local ROLE_OUT = "out"
local K = {

    CELL = 200,

    TALL_HARD = 2, TALL_SOFT = 1.5, TALL_DROP = 2,

    MIN_W = 13,

    MAX_W = 31,

    SOFT_SHARE = 0.55,

    FUSE = 2.5, FUSE_HASTY = 1.2, FUSE_LEISURE = 4.0,

    REMOTE_MOST = 12,

    FLAME_HOLD = 0.5,

    BURST_KEEP = 1.2,

    FLAME_DRAW_MAX = 120, BOOMS_PER_FRAME = 4,

    START_BOMBS = 1, START_FIRE = 2, MOST_BOMBS = 8, MOST_FIRE = 8,
    SPEED_STEPS = 4, SPEED_STEP = 0.08,

    WALK_TARGET = 32,

    KICK_SPEED = 5,

    FLY_TIME = 0.6, PUNCH_CELLS = 3, LOB_CELLS = 3, FLY_HIGH = 300,

    WIRE_MOST = 64,

    ITEM_SHARE = 0.30,

    SD_AT = 60, SD_LENGTH = 60, SD_LEFT_W = 9, SD_LEFT_H = 7,

    DROP_TIME = 0.5, DROP_FROM = 900, SHADOW = 0.5,

    SEATS = 4, SEAT_TURN = 15, REVENGE_FIRE = 2,

    CURSE_TIME = 10,

    ASK_SLACK = 450,

    TOP_ABOVE = 120,

    BLINK = 0.6,

    DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz",

    BOMB_SCALE = 1.4, BOOM_SCALE = 3.0, BOOM_ONCE = 1.0,
}

local PLACES = {
    empty = { x = 0, z = 0, y = 0 },
}

local PLACE_ORDER = { "empty" }

local LOOK = {
    border = { key = "blkbrickdarkgrey" },
    pillar = { key = "blkstone2" },
    soft = { key = "blkwoodenplank1" },
    drop = { key = "blktile2" },
}

pcall(function()
    local geos = {}
    for _, role in ipairs({ "border", "pillar", "soft", "drop" }) do
        geos[#geos + 1] = "of_blk_" .. LOOK[role].key:sub(4) .. "_geo"
    end
    OF.ball.resolve_at_load(geos)
end)
local MESH = "breakable_box_seg8_collision_08012D70"
local ITEM = {
    BOMB = 1, FIRE = 2, FULL = 3, SPEED = 4, KICK = 5, GLOVE = 6,
    REMOTE = 7, PIERCE = 8, HEART = 9, SKULL = 10,
}
local ITEM_ROWS = {
    [1] = { weight = 30, word = "Bomb +", model = "E_MODEL_BOWSER_BOMB", scale = 0.22 },
    [2] = { weight = 26, word = "Fire +", model = "E_MODEL_BLUE_FLAME", scale = 3.0, flame = true },
    [3] = { weight = 3, word = "Full fire", model = "E_MODEL_STAR", scale = 0.6 },
    [4] = { weight = 12, word = "Speed +", model = "E_MODEL_MARIOS_WING_CAP", scale = 1.6 },
    [5] = { weight = 7, word = "Kick", model = "E_MODEL_KOOPA_SHELL", scale = 0.9 },
    [6] = { weight = 6, word = "Glove", model = "E_MODEL_MARIOS_METAL_CAP", scale = 1.6 },
    [7] = { weight = 4, word = "Remote", model = "E_MODEL_PURPLE_SWITCH", scale = 0.5 },
    [8] = { weight = 4, word = "Pierce", model = "E_MODEL_BLUE_COIN_SWITCH", scale = 0.5 },
    [9] = { weight = 4, word = "Heart", model = "E_MODEL_HEART", scale = 0.9 },
    [10] = { weight = 4, word = "Skull", model = "E_MODEL_BOO", scale = 0.35 },
}

local CURSE = {
    SLOW = 1, FAST = 2, DIARRHEA = 3, INABILITY = 4, LOWEST = 5, HASTY = 6,
    LEISURE = 7, REVERSE = 8, INVISIBLE = 9, NOSTOP = 10, HICCUP = 11,
}
local CURSE_WORDS = {
    "Slow", "Too fast", "Bob-ombs on their own", "No Bob-ombs", "Fire 1",
    "Short fuse", "Long fuse", "Controls reversed", "Invisible", "Cannot stop",
    "Hiccups",
}
local CURSES = 11

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local ROOM_STOPS = { ordinary = 32, big = 40, small = 26 }
local ITEM_STOPS = { classic = 30, more = 45, fewer = 15 }

local KEYS = {
    field = "ofBmField", at = "ofBmAt", board = "ofBmBoard", got = "ofBmGot",
    loose = "ofBmLoose", pow = "ofBmPow", sd = "ofBmSD", seats = "ofBmSeats",
    back = "ofBmBack",
}

local BOMB_KEYS = { "ofBmBombs", "ofBmBombs2", "ofBmBombs3", "ofBmBombs4",
                    "ofBmBombs5", "ofBmBombs6" }
local BURST_KEYS = { "ofBmBurst", "ofBmBurst2", "ofBmBurst3", "ofBmBurst4" }
local ROUND_KEYS = { "ofBmBoard", "ofBmGot", "ofBmLoose", "ofBmSD", "ofBmSeats",
                     "ofBmBack" }
local ALL_KEYS = { "ofBmField", "ofBmAt", "ofBmBoard", "ofBmGot", "ofBmLoose",
                   "ofBmPow", "ofBmSD", "ofBmSeats", "ofBmBack" }

local BOMB_W = 17
local BOMB_CHUNK = 17 * 14

local BURST_W = 12
local BURST_CHUNK = 12 * 20
local POW_W = 10
local NO_FUSE = 46655

local ASK = {
    lay = "bglay", kick = "bgkick", punch = "bgpunch", boom = "bgboom",
    get = "bgget", down = "bgdown", curse = "bgcurse", heart = "bgheart",
    lob = "bglob",
}

local S = {
    fieldText = nil,
    field = nil,
    built = false,
    blocks = {},
    soc = {},
    boardText = nil, gotText = nil, looseText = nil, powText = nil,
    gone = {},
    got = {},
    loose = {},
    pow = {},
    bombs = {},
    bombsText = nil,
    drawnBombs = {},
    bursts = {},
    burstText = nil,
    flames = {},
    blasts = {},
    booms = 0,
    itemObjs = {},
    itemKinds = {},
    drops = {},
    sdAt = nil,
    order = nil,
    seats = {}, seatUntil = 0, seatsText = nil,
    backSeen = nil,
    placedFor = nil,
    lastFree = nil,
    pendingLay = nil,
    askedAt = {},
    heartUntil = 0,
    wasSeated = false,
    hurryShown = nil,
    hiccupAt = 0,
}

local H = {
    bombs = {},
    nextId = 1,
    bursts = {},
    gone = {}, got = {}, loose = {},
    pow = {},
    revealedAt = {},
    dirtyBombs = false, dirtyBursts = false, dirtyBoard = false,
    dirtyPow = false, dirtyLoose = false,
    frame = 0,
    outOrder = {},
    downSeen = {},
    seats = {}, seatUntil = 0,
    sdStarted = false, sdApplied = 0,
    backSerial = 0,
    backPending = {},
    hiccupAt = {},
    noRoom = false,
}

local HASH_P = 1000003.0
local function seeded01(a, b, salt)
    local n = (a * 7919.0 + b * 104729.0 + (salt or 0) * 15485863.0) % HASH_P
    if n < 0 then n = n + HASH_P end
    n = (n * n + 7777.0) % HASH_P
    n = (n * 1103.0 + b * 31.0 + a) % HASH_P
    n = (n * n + 12345.0) % HASH_P
    return n / HASH_P
end

local function to36(n, width)
    n = math.floor(n)
    if n < 0 then n = 0 end
    local out = ""
    for _ = 1, width do
        local d = n % 36
        out = string.sub(K.DIGITS, d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

local function from36(text)
    return tonumber(text, 36) or 0
end

local function tenths(t)
    return math.floor((t or 0) * 10 + 0.5)
end

local function open_cells(w, h)
    return w * h - ((w - 1) / 2) * ((h - 1) / 2)
end

local function field_size(players, perPlayer)
    local n = math.max(players or 0, 1)
    local want = (perPlayer or ROOM_STOPS.ordinary) * n
    if n <= 4 then want = math.min(want, open_cells(K.MIN_W, K.MIN_W - 2)) end
    local w = K.MIN_W
    while w < K.MAX_W and open_cells(w, w - 2) < want do w = w + 2 end
    return w, w - 2
end

local function bits_to_hex(set, n)
    local out = {}
    for at = 1, n, 4 do
        local v = 0
        for b = 0, 3 do
            if set[at + b] then v = v + 2 ^ b end
        end
        out[#out + 1] = string.format("%x", math.floor(v))
    end
    return table.concat(out)
end

local function hex_to_bits(text, n)
    local set = {}
    if type(text) ~= "string" then return set end
    for i = 1, #text do
        local v = tonumber(string.sub(text, i, i), 16) or 0
        for b = 0, 3 do
            local index = (i - 1) * 4 + b + 1
            if index <= n and math.floor(v / 2 ^ b) % 2 == 1 then set[index] = true end
        end
    end
    return set
end

local function cell_at(f, cx, cz)
    return cz * f.cols + cx
end

local function cell_xz(f, cell)
    return cell % f.cols, math.floor(cell / f.cols)
end

local function cell_world(f, cell)
    local cx, cz = cell_xz(f, cell)
    return f.x + (cx - (f.w + 1) / 2) * K.CELL, f.z + (cz - (f.h + 1) / 2) * K.CELL
end

local function cell_of(f, x, z)
    if f == nil or x == nil or z == nil then return nil end
    local cx = math.floor((x - f.x) / K.CELL + (f.w + 1) / 2 + 0.5)
    local cz = math.floor((z - f.z) / K.CELL + (f.h + 1) / 2 + 0.5)
    if cx < 0 or cz < 0 or cx > f.w + 1 or cz > f.h + 1 then return nil end
    return cell_at(f, cx, cz)
end

local function inside(f, cx, cz)
    return cx >= 1 and cz >= 1 and cx <= f.w and cz <= f.h
end

local function is_pillar(cx, cz)
    return cx % 2 == 0 and cz % 2 == 0
end

local function oddest(v, lo, hi)
    v = math.floor(v + 0.5)
    if v % 2 == 0 then v = v + 1 end
    if v > hi then v = v - 2 end
    if v < lo then v = lo end
    return v
end

local function start_cells(f, n, seed)
    local spots = {}
    if n <= 4 then
        local corners = { { 1, 1 }, { f.w, f.h }, { f.w, 1 }, { 1, f.h } }
        for i = 1, math.max(n, 1) do spots[#spots + 1] = corners[i] end
        return spots
    end
    local cols = math.ceil(math.sqrt(n))
    local rows = math.ceil(n / cols)
    local all = {}
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local cx = cols == 1 and (f.w + 1) / 2 or 1 + c * (f.w - 1) / (cols - 1)
            local cz = rows == 1 and (f.h + 1) / 2 or 1 + r * (f.h - 1) / (rows - 1)
            all[#all + 1] = { oddest(cx, 1, f.w), oddest(cz, 1, f.h) }
        end
    end

    while #all > n do
        local at = math.floor(seeded01(seed, #all, 31) * #all) + 1
        table.remove(all, math.min(at, #all))
    end
    return all
end

local function derive_field(text, place)
    if type(text) ~= "string" then return nil end
    local seed, w, h, items, skulls, starts = string.match(text,
        "^(%d+) (%d+) (%d+) (%d+) (%d) (%x*)$")
    seed, w, h = tonumber(seed), tonumber(w), tonumber(h)
    if seed == nil or w == nil or h == nil or w < 5 or h < 5 then return nil end
    local at = place or PLACES.empty
    local f = { seed = seed, w = w, h = h, cols = w + 2, rows = h + 2,
                x = at.x, z = at.z, y = at.y, text = text,
                items = tonumber(items) or ITEM_STOPS.classic,
                skulls = skulls == "1",
                hard = {}, softAt = {}, softCell = {}, item = {},
                starts = {}, startOf = {}, clear = {} }
    for cz = 0, h + 1 do
        for cx = 0, w + 1 do
            local cell = cell_at(f, cx, cz)
            if not inside(f, cx, cz) then
                f.hard[cell] = "border"
            elseif is_pillar(cx, cz) then
                f.hard[cell] = "pillar"
            end
        end
    end

    local globals = {}
    for i = 1, #starts do globals[#globals + 1] = tonumber(string.sub(starts, i, i), 16) end
    local spots = start_cells(f, #globals, seed)
    for i, g in ipairs(globals) do
        local spot = spots[i]
        if spot ~= nil then
            local cx, cz = spot[1], spot[2]
            local cell = cell_at(f, cx, cz)
            f.starts[i] = cell
            f.startOf[g] = cell
            f.clear[cell] = true
            local sx = cx < (w + 1) / 2 and 1 or -1
            local sz = cz < (h + 1) / 2 and 1 or -1
            f.clear[cell_at(f, cx + sx, cz)] = true
            f.clear[cell_at(f, cx, cz + sz)] = true
        end
    end

    local total = 0
    for _, row in ipairs(ITEM_ROWS) do total = total + row.weight end
    local skullWeight = ITEM_ROWS[ITEM.SKULL].weight
    for cz = 1, h do
        for cx = 1, w do
            local cell = cell_at(f, cx, cz)
            if f.hard[cell] == nil and not f.clear[cell]
                and seeded01(seed, cell, 1) < K.SOFT_SHARE then
                local index = #f.softCell + 1
                f.softCell[index] = cell
                f.softAt[cell] = index
                if seeded01(seed, cell, 2) * 100 < f.items then
                    local pool = f.skulls and total or (total - skullWeight)
                    local roll = seeded01(seed, cell, 3) * pool
                    for kind, row in ipairs(ITEM_ROWS) do
                        if kind ~= ITEM.SKULL or f.skulls then
                            if roll < row.weight then
                                f.item[index] = kind
                                break
                            end
                            roll = roll - row.weight
                        end
                    end
                end
            end
        end
    end
    f.softCount = #f.softCell
    return f
end

local function sd_order(f, random)
    local order = {}
    local rings = math.max(math.min((f.w - K.SD_LEFT_W) / 2, (f.h - K.SD_LEFT_H) / 2), 0)
    for ring = 0, rings - 1 do
        local x0, z0, x1, z1 = 1 + ring, 1 + ring, f.w - ring, f.h - ring
        local function add(cx, cz)
            if not is_pillar(cx, cz) then order[#order + 1] = cell_at(f, cx, cz) end
        end
        for cx = x0, x1 do add(cx, z0) end
        for cz = z0 + 1, z1 do add(x1, cz) end
        for cx = x1 - 1, x0, -1 do add(cx, z1) end
        for cz = z1 - 1, z0 + 1, -1 do add(x0, cz) end
    end
    if random then
        for i = #order, 2, -1 do
            local j = math.floor(seeded01(f.seed, i, 41) * i) + 1
            order[i], order[j] = order[j], order[i]
        end
    end
    return order
end

local function sd_land_time(f, order, k, at)
    local step = K.SD_LENGTH / math.max(#order, 1)
    return at + k * step
end

local function option(key, default)
    return OF.gamemodes.option_now(key) or default
end

local function revenge_mode()
    return option("revenge", "on")
end

local function sd_mode()
    return option("sudden", "spiral")
end

local function pack_bomb(b)
    local flags = (b.pierce and 1 or 0) + (b.remote and 2 or 0) + (b.revenge and 4 or 0)
    return to36(b.id % 1296, 2) .. to36(b.owner, 1) .. to36(b.cell, 2)
        .. to36(b.fuse ~= nil and tenths(b.fuse) or NO_FUSE, 3)
        .. to36(b.fire, 1) .. to36(flags, 1) .. to36(b.motion or 0, 1)
        .. to36(b.dir or 0, 1) .. to36(tenths(b.t0 or 0), 3) .. to36(b.to or b.cell, 2)
end

local function unpack_bomb(e)
    if #e ~= BOMB_W then return nil end
    local flags = from36(string.sub(e, 10, 10))
    local fuse = from36(string.sub(e, 6, 8))
    return { id = from36(string.sub(e, 1, 2)), owner = from36(string.sub(e, 3, 3)),
             cell = from36(string.sub(e, 4, 5)),
             fuse = fuse ~= NO_FUSE and fuse / 10 or nil,
             fire = from36(string.sub(e, 9, 9)),
             pierce = flags % 2 == 1, remote = math.floor(flags / 2) % 2 == 1,
             revenge = math.floor(flags / 4) % 2 == 1,
             motion = from36(string.sub(e, 11, 11)), dir = from36(string.sub(e, 12, 12)),
             t0 = from36(string.sub(e, 13, 15)) / 10, to = from36(string.sub(e, 16, 17)) }
end

local function pack_burst(u)
    return to36(u.id % 1296, 2) .. to36(u.cell, 2) .. to36(tenths(u.at), 3)
        .. to36(u.arms[1], 1) .. to36(u.arms[2], 1) .. to36(u.arms[3], 1)
        .. to36(u.arms[4], 1) .. to36(u.owner + (u.revenge and 16 or 0), 1)
end

local function unpack_burst(e)
    if #e ~= BURST_W then return nil end
    local owner = from36(string.sub(e, 12, 12))
    return { id = from36(string.sub(e, 1, 2)), cell = from36(string.sub(e, 3, 4)),
             at = from36(string.sub(e, 5, 7)) / 10,
             arms = { from36(string.sub(e, 8, 8)), from36(string.sub(e, 9, 9)),
                      from36(string.sub(e, 10, 10)), from36(string.sub(e, 11, 11)) },
             owner = owner % 16, revenge = owner >= 16 }
end

local function fresh_pow()
    return { bombs = K.START_BOMBS, fire = K.START_FIRE, speed = 0, kick = false,
             glove = false, remote = false, pierce = false, hearts = 0,
             curse = 0, curseUntil = 0, kills = 0 }
end

local function pack_pow(p)
    local powers = (p.kick and 1 or 0) + (p.glove and 2 or 0) + (p.remote and 4 or 0)
        + (p.pierce and 8 or 0)
    return to36(p.bombs, 1) .. to36(p.fire, 1) .. to36(p.speed, 1) .. to36(powers, 1)
        .. to36(p.hearts, 1) .. to36(p.curse, 1) .. to36(tenths(p.curseUntil), 3)
        .. to36(math.min(p.kills, 35), 1)
end

local function unpack_pow(e)
    if e == nil or #e ~= POW_W then return nil end
    local powers = from36(string.sub(e, 4, 4))
    return { bombs = from36(string.sub(e, 1, 1)), fire = from36(string.sub(e, 2, 2)),
             speed = from36(string.sub(e, 3, 3)), kick = powers % 2 == 1,
             glove = math.floor(powers / 2) % 2 == 1,
             remote = math.floor(powers / 4) % 2 == 1,
             pierce = math.floor(powers / 8) % 2 == 1,
             hearts = from36(string.sub(e, 5, 5)), curse = from36(string.sub(e, 6, 6)),
             curseUntil = from36(string.sub(e, 7, 9)) / 10,
             kills = from36(string.sub(e, 10, 10)) }
end

local function my_global()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    return np ~= nil and np.globalIndex or 0
end

local function global_of(localIndex)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[localIndex] or nil
    return np ~= nil and np.globalIndex or nil
end

local function pow_of(globalIndex)
    return S.pow[globalIndex] or fresh_pow()
end

local function cursed(p, kind, t)
    return p ~= nil and p.curse == kind and (t or 0) < (p.curseUntil or 0)
end

local function place_here()
    if not OF.util.asks(OF.arena, "find") then return nil, nil end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil, nil end
    for _, placeKey in ipairs(PLACE_ORDER) do
        local place = OF.arena.find(placeKey)
        if place ~= nil and place.level ~= nil and place.level == np.currLevelNum
            and (place.area or 1) == (np.currAreaIndex or 1) then
            return placeKey, PLACES[placeKey]
        end
    end
    return nil, nil
end

local function in_room(localIndex)
    local at = gGlobalSyncTable[KEYS.at]
    if type(at) ~= "string" then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)$")
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[localIndex or 0] or nil
    if np == nil or level == nil then return false end
    return np.currLevelNum == tonumber(level) and np.currAreaIndex == tonumber(area)
end

local function sd_lands(cell)
    if S.sdAt == nil or S.order == nil or S.field == nil then return nil end
    local k = S.orderAt ~= nil and S.orderAt[cell] or nil
    if k == nil then return nil end
    return sd_land_time(S.field, S.order, k, S.sdAt)
end

local function solid(f, cell, t, gone)
    if f.hard[cell] ~= nil then return true end
    local index = f.softAt[cell]
    if index ~= nil and not (gone or S.gone)[index] then return true end
    local lands = sd_lands(cell)
    if lands ~= nil and t ~= nil and t >= lands then return true end
    return false
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local function gone_obj(o)
    return o == nil or o.activeFlags == 0
end

local function drop_obj(o)
    if not gone_obj(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function block_init(o)
    if o == nil then return end
    local data = _G["gGlobalObjectCollisionData"]
    o.collisionData = data ~= nil and data[MESH] or nil
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = 0, 0, 0
    o.oMoveAnglePitch, o.oMoveAngleYaw, o.oMoveAngleRoll = 0, 0, 0
    local cell = math.floor(tonumber(o.oBehParams) or 0)
    if o.collisionData ~= nil then
        local handle = OF.util.optional("load_static_object_collision", nil)
        if handle ~= nil then S.soc[cell] = handle end
    end
end

local function drop_loop(o)
    if o == nil then return end
    local cell = math.floor(tonumber(o.oBehParams) or 0)
    local lands = sd_lands(cell)
    if S.field == nil or lands == nil then return end
    local t = OF.gamemodes.since_start()
    local left = lands - t
    local floor = S.field.y
    if left > 0 then
        o.oPosY = floor + K.DROP_FROM * math.min(left / K.DROP_TIME, 1)
        return
    end
    o.oPosY = floor
    if S.soc[cell] == nil and o.collisionData ~= nil then
        local handle = OF.util.optional("load_static_object_collision", nil)
        if handle ~= nil then S.soc[cell] = handle end
        OF.gamemodes.round_sound_throttled("bgthud", 3, SOUND_OBJ_THWOMP, o)
    end
end

local function drop_init(o)
    if o == nil then return end
    local data = _G["gGlobalObjectCollisionData"]
    o.collisionData = data ~= nil and data[MESH] or nil
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = 0, 0, 0
    o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    drop_loop(o)
end

bg.BLOCK = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    block_init, nil, "of blast block")
bg.DROP = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    drop_init, drop_loop, "of blast drop")

local function model_of(look)
    if look == nil then return nil end
    local entry = OF.util.asks(OF.spawner, "block_entry") and OF.spawner.block_entry(look.key) or nil
    local id = entry ~= nil and entry.model or nil
    if id == nil then
        local geo = OF.util.asks(OF.spawner, "block_geo") and OF.spawner.block_geo(look.key) or nil
        id = geo ~= nil and OF.util.optional("smlua_model_util_get_id", nil, geo) or nil
        if id == E_MODEL_ERROR_MODEL then id = nil end
    end
    return id
end

local function free_soc(cell)
    local handle = S.soc[cell]
    S.soc[cell] = nil
    if handle ~= nil then
        OF.util.optional("remove_static_object_collision", nil, handle)
    end
end

local function spawn_block(f, cell, look, tall, behaviour)
    local model = model_of(LOOK[look])
    if model == nil or behaviour == nil then return nil end
    local x, z = cell_world(f, cell)
    local y = f.y
    if behaviour == bg.DROP then y = f.y + K.DROP_FROM end
    local fit = 1
    if OF.util.asks(OF.spawner, "build_fit") then fit = OF.spawner.build_fit(0) or 1 end
    return OF.util.optional("spawn_non_sync_object", nil, behaviour, model, x, y, z,
        function(o)
            o.oBehParams = cell
            OF.util.optional("obj_scale_xyz", nil, o, fit, fit * tall, fit)
        end)
end

local function clear_world()
    for cell in pairs(S.soc) do free_soc(cell) end
    for cell, o in pairs(S.blocks) do drop_obj(o) S.blocks[cell] = nil end
    for cell, o in pairs(S.drops) do drop_obj(o) S.drops[cell] = nil end
    for id, o in pairs(S.drawnBombs) do drop_obj(o) S.drawnBombs[id] = nil end
    for key, o in pairs(S.itemObjs) do drop_obj(o) S.itemObjs[key] = nil end
    for _, flame in ipairs(S.flames) do drop_obj(flame.o) end
    for _, blast in ipairs(S.blasts) do drop_obj(blast.o) end
    S.flames, S.blasts = {}, {}
    if S.pendingLay ~= nil then drop_obj(S.pendingLay.o) S.pendingLay = nil end
    S.built = false
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    S.soc, S.blocks, S.drops, S.drawnBombs, S.itemObjs, S.flames = {}, {}, {}, {}, {}, {}
    S.blasts = {}
    S.pendingLay = nil
    S.built = false
    S.placedFor = nil
end)

local function build_field(f)
    clear_world()
    if bg.BLOCK == nil then return false end
    for cell, kind in pairs(f.hard) do
        S.blocks[cell] = spawn_block(f, cell, kind, K.TALL_HARD, bg.BLOCK)
    end
    for index, cell in ipairs(f.softCell) do
        if not S.gone[index] then
            S.blocks[cell] = spawn_block(f, cell, "soft", K.TALL_SOFT, bg.BLOCK)
        end
    end
    S.built = true
    return true
end

local function break_soft(cell)
    free_soc(cell)
    drop_obj(S.blocks[cell])
    S.blocks[cell] = nil
end

local function host_field()
    if S.field == nil then
        local text = gGlobalSyncTable[KEYS.field]
        if type(text) == "string" then
            S.field = derive_field(text, PLACES.empty)
            S.fieldText = text
            S.built = false
        end
    end
    if S.field ~= nil and S.order == nil then
        S.order = sd_order(S.field, option("sudden", "spiral") == "random")
        S.orderAt = {}
        for k, cell in ipairs(S.order) do S.orderAt[cell] = k end
    end
    return S.field
end

local function host_pow(globalIndex)
    if H.pow[globalIndex] == nil then H.pow[globalIndex] = fresh_pow() end
    return H.pow[globalIndex]
end

local function host_bomb_in(cell, t)
    for _, b in pairs(H.bombs) do
        if b.motion == 0 and b.cell == cell then return b end
        if b.motion == 1 and b.cur == cell then return b end
    end
    return nil
end

local function host_item_in(f, cell, t)
    local index = f.softAt[cell]
    if index ~= nil and H.gone[index] and f.item[index] ~= nil and not H.got[index] then
        return { soft = index, kind = f.item[index] }
    end
    for i, item in ipairs(H.loose) do
        if item.cell == cell then return { loose = i, kind = item.kind } end
    end
    return nil
end

local function host_solid(f, cell, t)
    return solid(f, cell, t, H.gone)
end

local function host_player_in(f, cell)
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_IN)) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil and cell_of(f, m.pos.x, m.pos.z) == cell then
            return true
        end
    end
    return false
end

local function remove_item(item)
    if item == nil then return end
    if item.soft ~= nil then
        H.got[item.soft] = true
        H.dirtyBoard = true
    elseif item.loose ~= nil then
        table.remove(H.loose, item.loose)
        H.dirtyLoose = true
    end
end

local function compute_burst(f, b, t, fire)
    local cx, cz = cell_xz(f, b.cell)
    local arms, chained = { 0, 0, 0, 0 }, {}
    for d, dir in ipairs(DIRS) do
        for step = 1, fire do
            local cell = cell_at(f, cx + dir[1] * step, cz + dir[2] * step)
            if f.hard[cell] ~= nil then break end
            local lands = sd_lands(cell)
            if lands ~= nil and t >= lands then break end
            local index = f.softAt[cell]
            if index ~= nil and not H.gone[index] then
                arms[d] = step
                H.gone[index] = true
                H.revealedAt[index] = t
                H.dirtyBoard = true
                if not b.pierce then break end
            else
                arms[d] = step
                local other = host_bomb_in(cell, t)
                if other ~= nil and other.id ~= b.id then
                    chained[#chained + 1] = other
                    break
                end
                local item = host_item_in(f, cell, t)
                if item ~= nil then
                    local opened = item.soft ~= nil and H.revealedAt[item.soft] or nil
                    if opened == nil or t - opened > K.FLAME_HOLD then
                        remove_item(item)
                        break
                    end
                end
            end
        end
    end
    return { id = b.id, cell = b.cell, at = t, arms = arms, owner = b.owner,
             revenge = b.revenge == true }, chained
end

local function host_burst(b, t)
    local f = host_field()
    if f == nil or b == nil then return end
    local queue = { b }
    while #queue > 0 do
        local next = table.remove(queue, 1)
        if H.bombs[next.id] ~= nil and next.motion ~= 2 then
            H.bombs[next.id] = nil
            if next.motion == 1 then next.cell = next.cur or next.cell end
            local p = host_pow(next.owner)
            local fire = next.fire
            if cursed(p, CURSE.LOWEST, t) and not next.revenge then fire = 1 end
            local burst, chained = compute_burst(f, next, t, fire)
            H.bursts[#H.bursts + 1] = burst
            for _, other in ipairs(chained) do queue[#queue + 1] = other end
            H.dirtyBombs, H.dirtyBursts = true, true
        end
    end
end

local function burst_cells(f, u)
    local cells = { [u.cell] = true }
    local cx, cz = cell_xz(f, u.cell)
    for d, dir in ipairs(DIRS) do
        for step = 1, u.arms[d] or 0 do
            cells[cell_at(f, cx + dir[1] * step, cz + dir[2] * step)] = true
        end
    end
    return cells
end

local function host_burning(f, cell, t)
    for _, u in ipairs(H.bursts) do
        if t - u.at <= K.FLAME_HOLD then
            if u.cells == nil then u.cells = burst_cells(f, u) end
            if u.cells[cell] then return true end
        end
    end
    return false
end

local function slide_cell(f, b, t)
    local cx, cz = cell_xz(f, b.from or b.cell)
    local tx, tz = cell_xz(f, b.to or b.cell)
    local far = math.abs(tx - cx) + math.abs(tz - cz)
    local went = math.min(math.floor((t - b.t0) * K.KICK_SPEED + 0.5), far)
    local dir = DIRS[(b.dir or 0) + 1] or DIRS[1]
    return cell_at(f, cx + dir[1] * went, cz + dir[2] * went), went >= far
end

local function host_open(f, cell, t, self)
    if host_solid(f, cell, t) then return false end
    local other = host_bomb_in(cell, t)
    if other ~= nil and other ~= self then return false end
    if host_item_in(f, cell, t) ~= nil then return false end
    return true
end

local function slide_end(f, cell, dir, t, self, most)
    local cx, cz = cell_xz(f, cell)
    local step = DIRS[dir + 1]
    local last = cell
    for n = 1, most or 99 do
        local next = cell_at(f, cx + step[1] * n, cz + step[2] * n)
        if not host_open(f, next, t, self) or host_player_in(f, next) then break end
        last = next
    end
    return last
end

local function landing(f, from, dir, cells, t, self)
    local cx, cz = cell_xz(f, from)
    local step = DIRS[dir + 1]
    for n = cells, math.max(f.w, f.h) do
        local x, z = cx + step[1] * n, cz + step[2] * n
        if not inside(f, x, z) then break end
        local cell = cell_at(f, x, z)
        if host_open(f, cell, t, self) then return cell end
    end
    for n = cells - 1, 1, -1 do
        local x, z = cx + step[1] * n, cz + step[2] * n
        if inside(f, x, z) then
            local cell = cell_at(f, x, z)
            if host_open(f, cell, t, self) then return cell end
        end
    end
    return from
end

local function host_count_bombs(owner, revengeOnly)
    local n = 0
    for _, b in pairs(H.bombs) do
        if b.owner == owner and (not revengeOnly or b.revenge) then
            if revengeOnly or not b.revenge then n = n + 1 end
        end
    end
    return n
end

local function host_bomb_total()
    local n = 0
    for _ in pairs(H.bombs) do n = n + 1 end
    return n
end

local function new_id()
    for _ = 1, 1296 do
        local id = H.nextId % 1296
        H.nextId = H.nextId + 1
        if H.bombs[id] == nil and id ~= 0 then return id end
    end
    return nil
end

local function host_lay(f, owner, cell, t)
    local cx, cz = cell_xz(f, cell)
    if not inside(f, cx, cz) or host_solid(f, cell, t) then return false, "blocked" end
    if host_bomb_in(cell, t) ~= nil then return false, "taken" end
    local p = host_pow(owner)
    if cursed(p, CURSE.INABILITY, t) then return false, "cursed" end
    if host_count_bombs(owner) >= p.bombs then return false, "cap" end
    if host_bomb_total() >= K.WIRE_MOST then return false, "wire" end
    local id = new_id()
    if id == nil then return false, "wire" end
    local fuse = K.FUSE
    if cursed(p, CURSE.HASTY, t) then fuse = K.FUSE_HASTY end
    if cursed(p, CURSE.LEISURE, t) then fuse = K.FUSE_LEISURE end
    H.bombs[id] = { id = id, owner = owner, cell = cell, fire = p.fire,
                    fuse = (not p.remote) and (t + fuse) or nil,
                    pierce = p.pierce, remote = p.remote, motion = 0, dir = 0,
                    t0 = t, to = cell, laid = t }
    H.dirtyBombs = true

    if host_burning(f, cell, t) then host_burst(H.bombs[id], t) end
    return true
end

local function apply_item(p, kind, t)
    if kind ~= ITEM.SKULL then p.curse, p.curseUntil = 0, 0 end
    if kind == ITEM.BOMB then p.bombs = math.min(p.bombs + 1, K.MOST_BOMBS)
    elseif kind == ITEM.FIRE then p.fire = math.min(p.fire + 1, K.MOST_FIRE)
    elseif kind == ITEM.FULL then p.fire = K.MOST_FIRE
    elseif kind == ITEM.SPEED then p.speed = math.min(p.speed + 1, K.SPEED_STEPS)
    elseif kind == ITEM.KICK then p.kick = true
    elseif kind == ITEM.GLOVE then p.glove = true
    elseif kind == ITEM.REMOTE then p.remote = true
    elseif kind == ITEM.PIERCE then p.pierce = true
    elseif kind == ITEM.HEART then p.hearts = math.min(p.hearts + 1, 1)
    elseif kind == ITEM.SKULL then
        p.curse = math.floor(seeded01(tenths(t), p.bombs + p.fire, 51) * CURSES) + 1
        p.curseUntil = t + K.CURSE_TIME
    end
    H.dirtyPow = true
end

local function scatter(f, p, globalIndex, t)
    local kinds = {}
    for _ = 1, p.bombs - K.START_BOMBS do kinds[#kinds + 1] = ITEM.BOMB end
    for _ = 1, p.fire - K.START_FIRE do kinds[#kinds + 1] = ITEM.FIRE end
    for _ = 1, p.speed do kinds[#kinds + 1] = ITEM.SPEED end
    if p.kick then kinds[#kinds + 1] = ITEM.KICK end
    if p.glove then kinds[#kinds + 1] = ITEM.GLOVE end
    if p.remote then kinds[#kinds + 1] = ITEM.REMOTE end
    if p.pierce then kinds[#kinds + 1] = ITEM.PIERCE end
    local placed = 0
    local tries = 0
    local room = f.w * f.h
    for _, kind in ipairs(kinds) do
        if #H.loose >= 80 then break end
        while tries < room * 2 do
            tries = tries + 1
            local cx = math.floor(seeded01(globalIndex * 97 + tries, tenths(t), 61) * f.w) + 1
            local cz = math.floor(seeded01(globalIndex * 89 + tries, tenths(t), 62) * f.h) + 1
            local cell = cell_at(f, cx, cz)
            if host_open(f, cell, t, nil) and not host_burning(f, cell, t)
                and not host_player_in(f, cell) and sd_lands(cell) == nil then
                H.loose[#H.loose + 1] = { cell = cell, kind = kind }
                placed = placed + 1
                break
            end
        end
    end
    if placed > 0 then H.dirtyLoose = true end
    return placed
end

local function sorted_ids(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function publish_bombs()
    local parts = {}
    for _, id in ipairs(sorted_ids(H.bombs)) do parts[#parts + 1] = pack_bomb(H.bombs[id]) end
    local chunks = OF.util.chunk_parts(parts, BOMB_CHUNK) or {}
    for index, key in ipairs(BOMB_KEYS) do OF.util.publish(key, chunks[index]) end
end

local function publish_bursts()
    local parts = {}
    for _, u in ipairs(H.bursts) do parts[#parts + 1] = pack_burst(u) end
    local chunks = OF.util.chunk_parts(parts, BURST_CHUNK) or {}
    for index, key in ipairs(BURST_KEYS) do OF.util.publish(key, chunks[index]) end
end

local function publish_board()
    local f = host_field()
    if f == nil then return end
    local any, anyGot = false, false
    for _ in pairs(H.gone) do any = true break end
    for _ in pairs(H.got) do anyGot = true break end
    OF.util.publish(KEYS.board, any and bits_to_hex(H.gone, f.softCount) or nil)
    OF.util.publish(KEYS.got, anyGot and bits_to_hex(H.got, f.softCount) or nil)
end

local function publish_loose()
    local parts = {}
    for _, item in ipairs(H.loose) do
        parts[#parts + 1] = to36(item.cell, 2) .. to36(item.kind, 1)
    end
    local text = table.concat(parts)
    OF.util.publish(KEYS.loose, text ~= "" and text or nil)
end

local function publish_pow()
    local parts = {}
    for g = 0, 15 do parts[#parts + 1] = pack_pow(H.pow[g] or fresh_pow()) end
    OF.util.publish(KEYS.pow, table.concat(parts))
end

local function publish_seats()
    if #H.seats == 0 then
        OF.util.publish(KEYS.seats, nil)
        return
    end
    local digits = {}
    for _, g in ipairs(H.seats) do digits[#digits + 1] = string.format("%x", g) end
    OF.util.publish(KEYS.seats, string.format("%s %.0f", table.concat(digits),
        tenths(H.seatUntil)))
end

local function host_publish(force)
    if H.dirtyBombs or force then H.dirtyBombs = false publish_bombs() end
    if H.dirtyBursts or force then H.dirtyBursts = false publish_bursts() end
    if H.dirtyBoard or force then H.dirtyBoard = false publish_board() end
    if H.dirtyLoose or force then H.dirtyLoose = false publish_loose() end
    if H.dirtyPow or force then H.dirtyPow = false publish_pow() end
end

local function asker(fromLocal, cell, wantRole)
    if not OF.util.is_host() then return nil end
    if OF.gamemodes.current() == nil or OF.gamemodes.current().key ~= "blastgrid"
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return nil
    end
    local f = host_field()
    local li = tonumber(fromLocal)
    if f == nil or li == nil then return nil end
    if OF.gamemodes.role(li) ~= (wantRole or ROLE_IN) then return nil end
    local m = gMarioStates[li]
    local g = global_of(li)
    if m == nil or m.pos == nil or g == nil then return nil end
    if cell ~= nil then
        local x, z = cell_world(f, cell)
        if (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 > K.ASK_SLACK * K.ASK_SLACK then
            return nil
        end
    end
    return m, g, f
end

local registered = false
local function register_asks()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    local t_now = function() return OF.gamemodes.since_start() end

    OF.net.register_action(ASK.lay, "round_move", function(fromLocal, cellText)
        local cell = tonumber(cellText)
        local _, g, f = asker(fromLocal, cell)
        if g == nil or cell == nil then return false end
        host_lay(f, g, cell, t_now())
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.kick, "round_move", function(fromLocal, cellText, dirText)
        local cell, dir = tonumber(cellText), tonumber(dirText)
        local _, g, f = asker(fromLocal, cell)
        if g == nil or dir == nil or dir < 0 or dir > 3 then return false end
        local t = t_now()
        local b = host_bomb_in(cell, t)
        if b == nil or b.motion ~= 0 or not host_pow(g).kick then return false end
        local to = slide_end(f, cell, dir, t, b)
        if to == cell then return false end
        b.motion, b.dir, b.from, b.to, b.t0, b.cur = 1, dir, cell, to, t, cell
        H.dirtyBombs = true
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.punch, "round_move", function(fromLocal, cellText, dirText)
        local cell, dir = tonumber(cellText), tonumber(dirText)
        local _, g, f = asker(fromLocal, cell)
        if g == nil or dir == nil or dir < 0 or dir > 3 then return false end
        local t = t_now()
        local b = host_bomb_in(cell, t)
        if b == nil or not host_pow(g).glove then return false end
        local from = b.motion == 1 and (b.cur or b.cell) or b.cell
        local to = landing(f, from, dir, K.PUNCH_CELLS, t, b)
        b.motion, b.dir, b.from, b.to, b.t0, b.cell = 2, dir, from, to, t, from
        H.dirtyBombs = true
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.boom, "round_move", function(fromLocal)
        local _, g = asker(fromLocal, nil)
        if g == nil then return false end
        local t = t_now()

        local oldest = nil
        for _, b in pairs(H.bombs) do
            if b.owner == g and b.fuse == nil and b.motion ~= 2
                and (oldest == nil or b.laid < oldest.laid) then
                oldest = b
            end
        end
        if oldest == nil then return false end
        host_burst(oldest, t)
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.get, "round_move", function(fromLocal, cellText)
        local cell = tonumber(cellText)
        local _, g, f = asker(fromLocal, cell)
        if g == nil or cell == nil then return false end
        local t = t_now()
        local item = host_item_in(f, cell, t)
        if item == nil then return false end
        remove_item(item)
        apply_item(host_pow(g), item.kind, t)
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.down, "round_move", function(fromLocal, ownerText)
        if not OF.util.is_host() then return false end
        local li = tonumber(fromLocal)
        local g = li ~= nil and global_of(li) or nil
        if g == nil or H.downSeen[g] then return false end
        local f = host_field()
        if f == nil then return false end
        local t = t_now()
        H.downSeen[g] = true
        H.outOrder[#H.outOrder + 1] = g
        local owner = tonumber(ownerText)
        if owner ~= nil and owner >= 0 and owner < 32 then
            local revenge = owner >= 16
            owner = owner % 16
            if owner ~= g then
                local p = host_pow(owner)
                p.kills = p.kills + 1
                H.dirtyPow = true

                if revenge and revenge_mode() == "super" and not H.sdStarted then
                    local m = gMarioStates[li]
                    local cell = (m ~= nil and m.pos ~= nil) and cell_of(f, m.pos.x, m.pos.z) or nil
                    if cell ~= nil and not host_solid(f, cell, t) then
                        H.backSerial = H.backSerial + 1
                        OF.util.publish(KEYS.back, string.format("%.0f %.0f %.0f",
                            H.backSerial, owner, cell))
                        H.downSeen[owner] = nil
                        H.backPending[owner] = t
                        H.pow[owner] = fresh_pow()
                        for i, seated in ipairs(H.seats) do
                            if seated == owner then table.remove(H.seats, i) break end
                        end
                        for i, out in ipairs(H.outOrder) do
                            if out == owner then table.remove(H.outOrder, i) break end
                        end
                        publish_seats()
                    end
                end
            end
        end
        scatter(f, host_pow(g), g, t)
        H.pow[g] = fresh_pow()
        H.dirtyPow = true
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.curse, "round_move", function(fromLocal, cursedText)
        local _, g = asker(fromLocal, nil)
        local other = tonumber(cursedText)
        if g == nil or other == nil or other == g then return false end
        local t = t_now()
        local from = host_pow(other)
        if from.curse == 0 or t >= from.curseUntil then return false end
        local to = host_pow(g)
        if to.curse ~= 0 and t < to.curseUntil then return false end
        to.curse, to.curseUntil = from.curse, t + K.CURSE_TIME
        from.curse, from.curseUntil = 0, 0
        H.dirtyPow = true
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.heart, "round_move", function(fromLocal)
        local _, g = asker(fromLocal, nil)
        if g == nil then return false end
        local p = host_pow(g)
        if p.hearts <= 0 then return false end
        p.hearts = p.hearts - 1
        H.dirtyPow = true
        host_publish()
        return true
    end)

    OF.net.register_action(ASK.lob, "round_move", function(fromLocal, cellText, targetText)
        local li = tonumber(fromLocal)
        local g = li ~= nil and global_of(li) or nil
        local f = host_field()
        local from, target = tonumber(cellText), tonumber(targetText)
        if g == nil or f == nil or from == nil or target == nil then return false end
        if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
        if OF.gamemodes.role(li) ~= ROLE_OUT or H.sdStarted then return false end
        local seated = false
        for _, s in ipairs(H.seats) do if s == g then seated = true end end
        if not seated or host_count_bombs(g, true) > 0 then return false end
        if host_bomb_total() >= K.WIRE_MOST then return false end
        local t = t_now()
        local tx, tz = cell_xz(f, target)
        tx = math.max(1, math.min(f.w, tx))
        tz = math.max(1, math.min(f.h, tz))
        target = cell_at(f, tx, tz)
        if not host_open(f, target, t, nil) then

            local found = nil
            for r = 1, 4 do
                for dz = -r, r do
                    for dx = -r, r do
                        local x, z = tx + dx, tz + dz
                        if found == nil and inside(f, x, z)
                            and host_open(f, cell_at(f, x, z), t, nil) then
                            found = cell_at(f, x, z)
                        end
                    end
                end
            end
            if found == nil then return false end
            target = found
        end
        local id = new_id()
        if id == nil then return false end
        H.bombs[id] = { id = id, owner = g, cell = from, fire = K.REVENGE_FIRE,
                        fuse = t + K.FLY_TIME + K.FUSE, revenge = true, motion = 2,
                        dir = 0, from = from, to = target, t0 = t, laid = t }
        H.dirtyBombs = true
        host_publish()
        return true
    end)
end

local function host_seats(t)
    local before = table.concat(H.seats, ",")
    if revenge_mode() == "off" or H.sdStarted then
        H.seats = {}
    else
        local queue = {}
        for _, g in ipairs(H.outOrder) do
            local li = OF.util.local_from_global(g)
            if li ~= nil and OF.gamemodes.role(li) == ROLE_OUT then queue[#queue + 1] = g end
        end
        H.outOrder = queue
        if #queue > K.SEATS and t >= H.seatUntil then

            local turned = {}
            for i = K.SEATS + 1, #queue do turned[#turned + 1] = queue[i] end
            for i = 1, K.SEATS do turned[#turned + 1] = queue[i] end
            H.outOrder = turned
            queue = turned
            H.seatUntil = t + K.SEAT_TURN
        elseif #queue <= K.SEATS then
            H.seatUntil = t + K.SEAT_TURN
        end
        local seats = {}
        for i = 1, math.min(K.SEATS, #queue) do seats[i] = queue[i] end
        H.seats = seats
    end
    if table.concat(H.seats, ",") ~= before then publish_seats() end
end

local function host_sudden(t)
    local f = host_field()
    if f == nil or sd_mode() == "off" then return end
    if not H.sdStarted then
        local left = OF.gamemodes.time_left()
        if left == nil or left > K.SD_AT then return end
        H.sdStarted = true
        S.sdAt = tenths(t) / 10
        OF.util.publish(KEYS.sd, string.format("%.0f", tenths(t)))
        publish_seats()
    end
    if S.order == nil then return end
    while H.sdApplied < #S.order do
        local k = H.sdApplied + 1
        local cell = S.order[k]
        if sd_land_time(f, S.order, k, S.sdAt) > t then break end
        H.sdApplied = k
        local b = host_bomb_in(cell, t)
        if b ~= nil then H.bombs[b.id] = nil H.dirtyBombs = true end
        local item = host_item_in(f, cell, t)
        if item ~= nil then remove_item(item) end
        local index = f.softAt[cell]
        if index ~= nil and not H.gone[index] then
            H.gone[index] = true
            H.got[index] = true
            H.dirtyBoard = true
        end
    end
end

local function host_hiccups(f, t)
    for g, p in pairs(H.pow) do
        if cursed(p, CURSE.HICCUP, t) and t >= (H.hiccupAt[g] or 0) then
            H.hiccupAt[g] = t + 3
            local li = OF.util.local_from_global(g)
            local m = li ~= nil and gMarioStates[li] or nil
            local cell = (m ~= nil and m.pos ~= nil) and cell_of(f, m.pos.x, m.pos.z) or nil
            local kind = nil
            if p.bombs > K.START_BOMBS then kind = ITEM.BOMB p.bombs = p.bombs - 1
            elseif p.fire > K.START_FIRE then kind = ITEM.FIRE p.fire = p.fire - 1
            elseif p.speed > 0 then kind = ITEM.SPEED p.speed = p.speed - 1 end
            if kind ~= nil and cell ~= nil and #H.loose < 80 then
                H.loose[#H.loose + 1] = { cell = cell, kind = kind }
                H.dirtyLoose, H.dirtyPow = true, true
            end
        end
    end
end

local function host_can_fire(b, t)
    if t - (b.laid or b.t0 or t) >= K.REMOTE_MOST then return false end
    local li = OF.util.local_from_global(b.owner)
    if li == nil or OF.gamemodes.role(li) ~= ROLE_IN then return false end
    return host_pow(b.owner).remote == true
end

local function host_tick(t)
    if not OF.util.is_host() then return end
    local f = host_field()
    if f == nil then return end
    H.frame = H.frame + 1

    for _, id in ipairs(sorted_ids(H.bombs)) do
        local b = H.bombs[id]
        if b ~= nil then
            if b.motion == 1 then
                local cell, done = slide_cell(f, b, t)
                if cell ~= b.cur then
                    b.cur = cell
                    H.dirtyBombs = true
                end

                local cx, cz = cell_xz(f, cell)
                local step = DIRS[b.dir + 1]
                local ahead = cell_at(f, cx + step[1], cz + step[2])
                if done or not host_open(f, ahead, t, b) or host_player_in(f, ahead) then
                    b.motion, b.cell, b.to, b.cur = 0, cell, cell, nil
                    H.dirtyBombs = true
                end
            elseif b.motion == 2 and t >= b.t0 + K.FLY_TIME then
                b.motion, b.cell = 0, b.to
                if host_bomb_in(b.cell, t) ~= nil and host_bomb_in(b.cell, t) ~= b then
                    b.cell = landing(f, b.cell, b.dir, 1, t, b)
                end
                H.dirtyBombs = true
            end
            if H.bombs[id] ~= nil and b.fuse == nil and not host_can_fire(b, t) then
                b.fuse = t + K.FUSE
                H.dirtyBombs = true
            end
            if H.bombs[id] ~= nil and b.motion ~= 2 then
                local here = b.motion == 1 and b.cur or b.cell
                if (b.fuse ~= nil and t >= b.fuse) or host_burning(f, here, t) then
                    host_burst(b, t)
                end
            end
        end
    end

    local keep = {}
    for _, u in ipairs(H.bursts) do
        if t - u.at <= K.BURST_KEEP then keep[#keep + 1] = u else H.dirtyBursts = true end
    end
    H.bursts = keep

    for _, p in pairs(H.pow) do
        if p.curse ~= 0 and t >= p.curseUntil then
            p.curse, p.curseUntil = 0, 0
            H.dirtyPow = true
        end
    end
    host_hiccups(f, t)
    host_sudden(t)
    host_seats(t)

    if H.dirtyBursts then host_publish() elseif H.frame % 3 == 0 then host_publish() end
end

local function power_of(p)
    if p == nil then return 0 end
    return p.bombs + p.fire + p.speed + p.hearts + (p.kick and 1 or 0)
        + (p.glove and 1 or 0) + (p.remote and 1 or 0) + (p.pierce and 1 or 0)
end

local function hear_pow(was, now, t)
    if was == nil or now == nil or OF.gamemodes.role(0) ~= ROLE_IN then return end
    if now.curse ~= 0 and now.curse ~= was.curse and t < now.curseUntil then
        OF.gamemodes.cue("bad", nil, "bgskull")
    elseif power_of(now) > power_of(was) or now.kills > was.kills then
        OF.gamemodes.cue("good", nil, "bggood")
    end
end

local function listen(t)
    local f = S.field
    if f == nil then return end
    local board = gGlobalSyncTable[KEYS.board]
    if board ~= S.boardText then
        S.boardText = board
        local now = hex_to_bits(board, f.softCount)
        for index in pairs(now) do
            if not S.gone[index] then
                S.gone[index] = true
                break_soft(f.softCell[index])
            end
        end
    end
    local got = gGlobalSyncTable[KEYS.got]
    if got ~= S.gotText then
        S.gotText = got
        S.got = hex_to_bits(got, f.softCount)
    end
    local loose = gGlobalSyncTable[KEYS.loose]
    if loose ~= S.looseText then
        S.looseText = loose
        S.loose = {}
        local text = type(loose) == "string" and loose or ""
        for i = 1, #text - 2, 3 do
            S.loose[#S.loose + 1] = { cell = from36(string.sub(text, i, i + 1)),
                                      kind = from36(string.sub(text, i + 2, i + 2)) }
        end
    end
    local pow = gGlobalSyncTable[KEYS.pow]
    if pow ~= S.powText then
        S.powText = pow
        local was = S.pow[my_global()]
        S.pow = {}
        local text = type(pow) == "string" and pow or ""
        for g = 0, 15 do
            local p = unpack_pow(string.sub(text, g * POW_W + 1, g * POW_W + POW_W))
            if p ~= nil then S.pow[g] = p end
        end
        hear_pow(was, S.pow[my_global()], t)
    end
    local bombs = OF.util.joined(BOMB_KEYS)
    if bombs ~= S.bombsText then
        S.bombsText = bombs
        S.bombs = {}
        for i = 1, #bombs - BOMB_W + 1, BOMB_W do
            local b = unpack_bomb(string.sub(bombs, i, i + BOMB_W - 1))
            if b ~= nil then S.bombs[b.id] = b end
        end
    end
    local bursts = OF.util.joined(BURST_KEYS)
    if bursts ~= S.burstText then
        S.burstText = bursts
        for i = 1, #bursts - BURST_W + 1, BURST_W do
            local u = unpack_burst(string.sub(bursts, i, i + BURST_W - 1))
            if u ~= nil then
                local key = u.id .. "@" .. tenths(u.at)
                if S.bursts[key] == nil then
                    u.heard = t
                    u.cells = burst_cells(f, u)
                    u.fresh = true
                    S.bursts[key] = u
                end
            end
        end
    end
    for key, u in pairs(S.bursts) do
        if t - u.heard > K.BURST_KEEP + 1 then S.bursts[key] = nil end
    end
    local sd = gGlobalSyncTable[KEYS.sd]
    S.sdAt = tonumber(sd) ~= nil and tonumber(sd) / 10 or nil
    local seats = gGlobalSyncTable[KEYS.seats]
    if seats ~= S.seatsText then
        S.seatsText = seats
        S.seats = {}
        S.seatUntil = 0
        local digits, untilText = string.match(tostring(seats or ""), "^(%x+) (%d+)$")
        if digits ~= nil then
            for i = 1, #digits do S.seats[#S.seats + 1] = tonumber(string.sub(digits, i, i), 16) end
            S.seatUntil = (tonumber(untilText) or 0) / 10
        end
    end
end

local function burning(cell, t)
    for _, u in pairs(S.bursts) do
        if t - u.heard <= K.FLAME_HOLD and u.cells[cell] then return u end
    end
    return nil
end

local function bomb_cell_of(b, t)
    if b.motion == 1 and S.field ~= nil then
        local cell = slide_cell(S.field, b, t)
        return cell
    end
    if b.motion == 2 then return nil end
    return b.cell
end

local function bomb_in(cell, t)
    for _, b in pairs(S.bombs) do
        if bomb_cell_of(b, t) == cell then return b end
    end
    return nil
end

local function item_in(f, cell)
    local index = f.softAt[cell]
    if index ~= nil and S.gone[index] and f.item[index] ~= nil and not S.got[index] then
        return f.item[index]
    end
    for _, item in ipairs(S.loose) do
        if item.cell == cell then return item.kind end
    end
    return nil
end

local BOBOMB_ANIMS = "bobomb_seg8_anims_0802396C"
local function pose(o, rate)
    local anims = gObjectAnimations ~= nil and gObjectAnimations[BOBOMB_ANIMS] or nil
    if anims == nil then return end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, rate or 0.4)
end

local function bomb_world(f, b, t)
    if b.motion == 1 then
        local fx, fz = cell_world(f, b.from or b.cell)
        local cx0, cz0 = cell_xz(f, b.from or b.cell)
        local tx, tz = cell_xz(f, b.to or b.cell)
        local far = math.abs(tx - cx0) + math.abs(tz - cz0)
        local went = math.min(math.max(t - b.t0, 0) * K.KICK_SPEED, far)
        local dir = DIRS[(b.dir or 0) + 1]
        return fx + dir[1] * went * K.CELL, f.y, fz + dir[2] * went * K.CELL
    elseif b.motion == 2 then
        local fx, fz = cell_world(f, b.from or b.cell)
        local tx, tz = cell_world(f, b.to or b.cell)
        local k = math.min(math.max((t - b.t0) / K.FLY_TIME, 0), 1)
        local lift = 0
        if b.revenge then lift = (1 - k) * K.CELL * K.TALL_HARD end
        return fx + (tx - fx) * k, f.y + lift + math.sin(k * math.pi) * K.FLY_HIGH,
            fz + (tz - fz) * k
    end
    local x, z = cell_world(f, b.cell)
    return x, f.y, z
end

local function draw_bombs(f, t)
    S.booms = 0
    local m = gMarioStates[0]
    for id, b in pairs(S.bombs) do
        local o = S.drawnBombs[id]
        local x, y, z = bomb_world(f, b, t)
        if gone_obj(o) then
            o = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_BLACK_BOBOMB, x, y, z, nil)
            S.drawnBombs[id] = o

            if o ~= nil then
                pose(o)
                OF.gamemodes.round_sound_from(o, SOUND_OBJ_BOBOMB_WALK)
            end
            b.bornAt = t
        end
        if o ~= nil then
            o.oPosX, o.oPosY, o.oPosZ = x, y, z

            local scale = 1 + 0.05 * math.sin(t * 8)
            local last = b.fuse ~= nil and b.fuse - t < 1
            if last then
                scale = scale * ((math.floor(t * 12) % 2 == 0) and 1.25 or 1.0)
                OF.gamemodes.round_sound_from(o, SOUND_AIR_BOBOMB_LIT_FUSE)
                if m ~= nil and m.pos ~= nil and OF.gamemodes.role(0) == ROLE_IN then
                    local dx, dz = m.pos.x - x, m.pos.z - z
                    local reach = (b.fire + 1) * K.CELL
                    if (math.abs(dx) < K.CELL * 0.5 and math.abs(dz) < reach)
                        or (math.abs(dz) < K.CELL * 0.5 and math.abs(dx) < reach) then
                        OF.gamemodes.cue("hazard", nil, "bgline")
                    end
                end
            end
            if o.oAnimations ~= nil then
                OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0,
                    last and 3.0 or 0.4)
            end
            OF.util.optional("obj_scale", nil, o, scale * K.BOMB_SCALE)

            if b.fuse ~= nil and t >= b.fuse and not b.boomed then
                b.boomed = true
                bg.boom_at(f, x, z, b.cell, t)
            end
        end
    end
    for id, o in pairs(S.drawnBombs) do
        if S.bombs[id] == nil then drop_obj(o) S.drawnBombs[id] = nil end
    end

    local pending = S.pendingLay
    if pending ~= nil then
        if bomb_in(pending.cell, t) ~= nil or t - pending.at > 1 then
            drop_obj(pending.o)
            S.pendingLay = nil
        elseif gone_obj(pending.o) then
            local x, z = cell_world(f, pending.cell)
            pending.o = OF.slots.spawn_non_sync(id_bhvStaticObject, E_MODEL_BLACK_BOBOMB,
                x, f.y, z, nil)
            if pending.o ~= nil then
                pose(pending.o)
                OF.util.optional("obj_scale", nil, pending.o, K.BOMB_SCALE)
            end
        end
    end
end

function bg.boom_at(f, x, z, cell, t)
    S.boomed = S.boomed or {}
    local at = S.boomed[cell]
    if at ~= nil and t - at < K.BOOM_ONCE then return false end
    if (S.booms or 0) >= K.BOOMS_PER_FRAME then return false end
    S.booms = (S.booms or 0) + 1
    S.boomed[cell] = t
    local o = OF.util.optional("spawn_non_sync_object", nil, id_bhvStaticObject,
        E_MODEL_EXPLOSION, x, f.y + 100, z, nil)
    if o ~= nil then
        OF.util.optional("obj_set_billboard", nil, o)
        o.oAnimState = 0
        S.blasts[#S.blasts + 1] = { o = o, frame = 0 }
    end
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil and (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 < 1500 * 1500 then
        OF.util.optional("set_environmental_camera_shake", nil, SHAKE_ENV_EXPLOSION)
    end
    OF.gamemodes.round_sound_throttled("bgboom", 3, SOUND_GENERAL2_BOBOMB_EXPLOSION, nil)
    return true
end

local function draw_bursts(f, t)
    for _, u in pairs(S.bursts) do
        if u.fresh then
            u.fresh = false
            local x, z = cell_world(f, u.cell)

            bg.boom_at(f, x, z, u.cell, t)
            for cell in pairs(u.cells) do
                if #S.flames < K.FLAME_DRAW_MAX then
                    local fx, fz = cell_world(f, cell)
                    local o = OF.util.optional("spawn_non_sync_object", nil, id_bhvStaticObject,
                        E_MODEL_RED_FLAME, fx, f.y + 20, fz, nil)
                    if o ~= nil then
                        OF.util.optional("obj_set_billboard", nil, o)
                        OF.util.optional("obj_scale", nil, o, 6)
                        o.oAnimState = (cell % 8)
                        S.flames[#S.flames + 1] = { o = o, untilT = t + K.FLAME_HOLD }
                    end
                end
            end
        end
    end
    local live = {}
    for _, blast in ipairs(S.blasts) do
        blast.frame = blast.frame + 1
        if blast.frame >= 9 or gone_obj(blast.o) then
            drop_obj(blast.o)
        else
            blast.o.oAnimState = blast.frame
            OF.util.optional("obj_scale", nil, blast.o, (blast.frame / 9 + 1) * K.BOOM_SCALE)
            live[#live + 1] = blast
        end
    end
    S.blasts = live
    local keep = {}
    for _, flame in ipairs(S.flames) do
        if t >= flame.untilT or gone_obj(flame.o) then
            drop_obj(flame.o)
        else
            flame.o.oAnimState = ((flame.o.oAnimState or 0) + 1) % 8
            keep[#keep + 1] = flame
        end
    end
    S.flames = keep
end

local function draw_items(f, t)
    local want = {}
    for index, kind in pairs(f.item) do
        if S.gone[index] and not S.got[index] then want["h" .. index] = { f.softCell[index], kind } end
    end
    for _, item in ipairs(S.loose) do want["l" .. item.cell] = { item.cell, item.kind } end
    for key, o in pairs(S.itemObjs) do
        local w = want[key]
        if w == nil or gone_obj(o) or S.itemKinds[key] ~= w[2] then
            drop_obj(o)
            S.itemObjs[key] = nil
        end
    end
    for key, w in pairs(want) do
        local o = S.itemObjs[key]
        local row = ITEM_ROWS[w[2]]
        if o == nil and row ~= nil then
            local x, z = cell_world(f, w[1])
            local model = _G[row.model]
            if model ~= nil then

                o = OF.slots.spawn_non_sync(id_bhvStaticObject, model, x, f.y + 60, z, nil)
                if o ~= nil then
                    OF.util.optional("obj_scale", nil, o, row.scale)
                    if row.flame then OF.util.optional("obj_set_billboard", nil, o) end
                    S.itemKinds[key] = w[2]
                    S.itemObjs[key] = o
                end
            end
        end
        if o ~= nil then
            o.oFaceAngleYaw = math.floor(t * 4000) % 65536
            o.oPosY = f.y + 60 + 15 * math.sin(t * 3)
            if row ~= nil and row.flame then o.oAnimState = math.floor(t * 20) % 8 end
        end
    end
end

local function draw_drops(f, t)
    if S.sdAt == nil or S.order == nil then return end
    for k, cell in ipairs(S.order) do
        local lands = sd_land_time(f, S.order, k, S.sdAt)
        if lands - K.DROP_TIME > t then break end
        if S.drops[cell] == nil then
            local index = f.softAt[cell]
            if index ~= nil and not S.gone[index] then
                S.gone[index] = true
                break_soft(cell)
            end
            S.drops[cell] = spawn_block(f, cell, "drop", K.TALL_DROP, bg.DROP) or false
        end
    end
end

local function round_live()
    return OF.gamemodes.state() == OF.gamemodes.ACTIVE
end

local function am_in()
    return OF.gamemodes.role(0) == ROLE_IN
end

local function seated(globalIndex)
    for _, g in ipairs(S.seats) do if g == globalIndex then return true end end
    return false
end

local function ask(key, gap, t, name, x, y)
    if t - (S.askedAt[key] or -99) < gap then return false end
    S.askedAt[key] = t
    register_asks()
    if not OF.util.asks(OF.net, "host_does") then return false end
    OF.net.host_does(name, x, y)
    return true
end

local function go_out(text, owner)
    if not am_in() then return end
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    register_asks()
    if OF.util.asks(OF.net, "host_does") then
        OF.net.host_does(ASK.down, owner or -1)
    end

    S.outCause = text
end

local function facing_dir(m)
    local yaw = (m.faceAngle.y or 0) / 32768 * math.pi
    local sx, cz = math.sin(yaw), math.cos(yaw)
    if math.abs(sx) >= math.abs(cz) then return sx >= 0 and 0 or 1 end
    return cz >= 0 and 2 or 3
end

local function judge(f, t, m)
    if not am_in() or not round_live() then return end
    if not OF.util.can_play(0) or not in_room(0) then return end
    local cell = cell_of(f, m.pos.x, m.pos.z)
    if cell == nil then return end

    local lands = sd_lands(cell)
    if lands ~= nil and t >= lands then
        go_out("Crushed by a pressure block", -1)
        return
    end
    local u = burning(cell, t)
    if u == nil or m.pos.y > f.y + K.CELL * K.TALL_HARD then return end
    if t < S.heartUntil then return end
    local p = pow_of(my_global())
    if p.hearts > 0 then
        S.heartUntil = t + 2
        ask("heart", 0.5, t, ASK.heart)
        OF.gamemodes.cue("bad", nil, "bgheart")

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("HEART LOST"), nil, { quiet = true })
        end
        return
    end
    local owner = u.owner + (u.revenge and 16 or 0)
    if u.owner == my_global() and not u.revenge then
        go_out("Caught in your own blast", owner)
    else
        go_out("Caught in a blast", owner)
    end
end

local function keep_off_tops(f, t, m)
    local cell = cell_of(f, m.pos.x, m.pos.z)
    local onFloor = m.pos.y <= f.y + 20
    if cell ~= nil and not solid(f, cell, t) and onFloor then
        S.lastFree = { x = m.pos.x, z = m.pos.z, cell = cell }
    end
    if cell == nil then return false end
    if solid(f, cell, t) and m.pos.y > f.y + K.TOP_ABOVE and S.lastFree ~= nil then
        local x, z = cell_world(f, S.lastFree.cell)
        OF.util.place_player(0, x, f.y, z)
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        return true
    end
    return false
end

local lastPos = { x = 0, z = 0 }
local function bump_bombs(f, t, m)
    local cell = cell_of(f, m.pos.x, m.pos.z)
    local refused = nil
    if cell ~= nil and bomb_in(cell, t) ~= nil then
        local wasCell = cell_of(f, lastPos.x, lastPos.z)
        if wasCell ~= nil and wasCell ~= cell then
            refused = cell
            local xOnly = cell_of(f, m.pos.x, lastPos.z)
            local zOnly = cell_of(f, lastPos.x, m.pos.z)
            if xOnly ~= nil and xOnly ~= cell and bomb_in(xOnly, t) == nil then
                m.pos.z = lastPos.z
            elseif zOnly ~= nil and zOnly ~= cell and bomb_in(zOnly, t) == nil then
                m.pos.x = lastPos.x
            else
                m.pos.x, m.pos.z = lastPos.x, lastPos.z
            end
        end
    end
    lastPos.x, lastPos.z = m.pos.x, m.pos.z
    return refused
end

local lastStick = { x = 0, y = 64 }
local function steer(m, p, t)
    local pad = m.controller
    if pad ~= nil then
        if cursed(p, CURSE.REVERSE, t) then
            pad.stickX, pad.stickY = -(pad.stickX or 0), -(pad.stickY or 0)
        end
        if cursed(p, CURSE.NOSTOP, t) then
            if (pad.stickMag or 0) < 32 then
                pad.stickX, pad.stickY, pad.stickMag = lastStick.x, lastStick.y, 64
            end
        end
        if (pad.stickMag or 0) >= 32 then lastStick.x, lastStick.y = pad.stickX, pad.stickY end
    end
    local factor = 1 + K.SPEED_STEP * (p.speed or 0)
    if cursed(p, CURSE.FAST, t) then factor = 1.6 end
    if cursed(p, CURSE.SLOW, t) then factor = 0.55 end
    local grounded = m.action ~= nil and not OF.util.has_flag(m.action, ACT_FLAG_AIR)
    if not grounded then return end
    if factor > 1 then
        OF.util.speed_up(m, math.min(m.intendedMag or 0, K.WALK_TARGET) * factor)
    elseif factor < 1 and (m.forwardVel or 0) > K.WALK_TARGET * factor then
        m.forwardVel = K.WALK_TARGET * factor
    end
end

local function hands(f, t, m, p, refused)
    local cell = cell_of(f, m.pos.x, m.pos.z)
    if cell == nil then return end
    OF.input.poll(m)
    local pressedB = OF.input.pressed(B_BUTTON)
    local grounded = m.action ~= nil and not OF.util.has_flag(m.action, ACT_FLAG_AIR)

    if refused ~= nil and p.kick and (m.forwardVel or 0) > 8 then
        local fx, fz = cell_xz(f, cell)
        local bx, bz = cell_xz(f, refused)
        local dir = nil
        if bx > fx then dir = 0 elseif bx < fx then dir = 1
        elseif bz > fz then dir = 2 elseif bz < fz then dir = 3 end
        if dir ~= nil and ask("kick" .. refused, 0.4, t, ASK.kick, refused, dir) then
            OF.gamemodes.round_sound(SOUND_ACTION_HIT)
        end
    end

    if p.remote then
        local waiting = false
        for _, b in pairs(S.bombs) do
            if b.owner == my_global() and b.fuse == nil then waiting = true end
        end
        if waiting then
            if OF.input.pressed(Z_TRIG) then ask("boom", 0.15, t, ASK.boom) end
            OF.input.take(m, Z_TRIG)
        end
    end
    if pressedB and grounded then

        local dir = facing_dir(m)
        local cx, cz = cell_xz(f, cell)
        local ahead = cell_at(f, cx + DIRS[dir + 1][1], cz + DIRS[dir + 1][2])
        if p.glove and bomb_in(ahead, t) ~= nil then
            ask("punch", 0.3, t, ASK.punch, ahead, dir)
            OF.gamemodes.round_sound(SOUND_ACTION_THROW)

            if (m.forwardVel or 0) >= 28 then OF.input.take(m, B_BUTTON) end
            return
        end
        OF.input.take(m, B_BUTTON)
        if cursed(p, CURSE.INABILITY, t) then
            OF.gamemodes.cue("bad", nil, "bgnolay")
            return
        end
        if bomb_in(cell, t) == nil and not solid(f, cell, t) then
            if ask("lay", 0.15, t, ASK.lay, cell) then
                if S.pendingLay ~= nil then drop_obj(S.pendingLay.o) end
                S.pendingLay = { cell = cell, at = t }
            end
        end
    elseif pressedB then
        OF.input.take(m, B_BUTTON)
    end

    if cursed(p, CURSE.DIARRHEA, t) and grounded and bomb_in(cell, t) == nil then
        ask("lay", 0.4, t, ASK.lay, cell)
    end

    if item_in(f, cell) ~= nil then ask("get" .. cell, 0.5, t, ASK.get, cell) end

    local mine = pow_of(my_global())
    if mine.curse == 0 or t >= mine.curseUntil then
        for _, entry in ipairs(OF.gamemodes.with_role(ROLE_IN)) do
            local li = entry.localIndex
            local g = global_of(li)
            local other = gMarioStates[li]
            if li ~= 0 and g ~= nil and other ~= nil and other.pos ~= nil then
                local q = pow_of(g)
                if q.curse ~= 0 and t < q.curseUntil then
                    local dx, dz = other.pos.x - m.pos.x, other.pos.z - m.pos.z
                    if dx * dx + dz * dz < 90 * 90 then
                        ask("curse", 1, t, ASK.curse, g)
                    end
                end
            end
        end
    end
end

local function rim_spot(f, m)
    local cx = math.floor((m.pos.x - f.x) / K.CELL + (f.w + 1) / 2 + 0.5)
    local cz = math.floor((m.pos.z - f.z) / K.CELL + (f.h + 1) / 2 + 0.5)
    cx = math.max(0, math.min(f.w + 1, cx))
    cz = math.max(0, math.min(f.h + 1, cz))

    local toX = math.min(cx, f.w + 1 - cx)
    local toZ = math.min(cz, f.h + 1 - cz)
    if toX <= toZ then cx = (cx <= (f.w + 1) / 2) and 0 or f.w + 1
    else cz = (cz <= (f.h + 1) / 2) and 0 or f.h + 1 end
    return cell_at(f, cx, cz)
end

local function on_the_wall(f, t, m)
    local top = f.y + K.CELL * K.TALL_HARD
    local cell = cell_of(f, m.pos.x, m.pos.z)
    local onRim = cell ~= nil and f.hard[cell] == "border" and m.pos.y >= top - 40
    if not onRim then
        local spot = rim_spot(f, m)
        local x, z = cell_world(f, spot)
        OF.net.snap_to(x, top + 10, z, nil)
        return
    end
    OF.input.poll(m)
    if OF.input.pressed(B_BUTTON) then
        OF.input.take(m, B_BUTTON)
        local yaw = (m.faceAngle.y or 0) / 32768 * math.pi
        local tx = m.pos.x + math.sin(yaw) * K.CELL * K.LOB_CELLS
        local tz = m.pos.z + math.cos(yaw) * K.CELL * K.LOB_CELLS
        local target = cell_of(f, tx, tz)
        if target == nil then

            local cx, cz = cell_xz(f, cell)
            local ix = cx == 0 and K.LOB_CELLS or (cx == f.w + 1 and f.w + 1 - K.LOB_CELLS or cx)
            local iz = cz == 0 and K.LOB_CELLS or (cz == f.h + 1 and f.h + 1 - K.LOB_CELLS or cz)
            target = cell_at(f, ix, iz)
        end
        if ask("lob", 0.5, t, ASK.lob, cell, target) then
            OF.gamemodes.round_sound(SOUND_ACTION_THROW)
        end
    end
end

local function place_me(f)
    if S.placedFor == f.text then return end
    local cell = f.startOf[my_global()]
    if cell == nil then return end
    if not am_in() then return end
    S.placedFor = f.text
    local x, z = cell_world(f, cell)
    local yaw = math.atan(f.x - x, f.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
    S.lastFree = { x = x, z = z, cell = cell }
    lastPos.x, lastPos.z = x, z
end

local function hear_back(f)
    local back = gGlobalSyncTable[KEYS.back]
    if back == nil or back == S.backSeen then return end
    S.backSeen = back
    local serial, g, cell = string.match(tostring(back), "^(%d+) (%d+) (%d+)$")
    if tonumber(g) ~= my_global() or OF.gamemodes.role(0) ~= ROLE_OUT then return end
    OF.gamemodes.set_role(0, ROLE_IN)
    OF.gamemodes.set_ghost(false)
    local x, z = cell_world(f, tonumber(cell))
    OF.net.snap_to(x, f.y + 10, z, nil)
    S.lastFree = { x = x, z = z, cell = tonumber(cell) }
    lastPos.x, lastPos.z = x, z
    OF.gamemodes.cue("good", nil, "bgback")

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("role", OF.lang.t("BACK IN"), OF.lang.t("Revenge"), { quiet = true })
    end
end

local mode = {
    key = "blastgrid",
    resultsBy = "survival",
    name = "Blast Grid",
    blurb = "lay Bob-ombs on a grid of blocks - every blast is a cross",
    aims = { [ROLE_IN] = "Blast the others - and stay out of every cross, yours too." },
    how = "B lays a Bob-omb; it bursts in a cross, row and column.\n"
        .. "A blast breaks soft blocks and sets off other Bob-ombs.\n"
        .. "Broken blocks drop power-ups: bombs, fire, speed.\n"
        .. "Any blast takes you out, yours too. Blocks are solid.\n"
        .. "In the last minute blocks fall in from the edge.\n"
        .. "Out? Throw Bob-ombs from the wall. Last one up wins.",
    minPlayers = 2,

    maps = { "empty" },
    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    studio = { tint = { 150, 150, 140 } },
    defaultLimit = 180,
    saysOut = true,
    lensRole = ROLE_OUT,
    music = SEQ_LEVEL_UNDERGROUND,
    options = {
        { key = "field", name = "Field size",
          help = "the field grows with the players - this is how much",
          choices = {
              { key = "ordinary", name = "normal",
                help = "32 open cells each: 13 x 11 for four, 27 x 25 for sixteen" },
              { key = "big", name = "bigger",
                help = "40 cells a player - longer rounds, fewer early blasts" },
              { key = "small", name = "smaller",
                help = "26 cells a player - a crowded field" },
          } },
        { key = "revenge", name = "Revenge from the wall",
          help = "out players throw Bob-ombs from the wall, four at a time",

          choices = {
              { key = "off", name = "off",
                help = "out players only watch" },
              { key = "on", name = "on",
                help = "one Bob-omb at a time, fire 2 - gone in sudden death" },
              { key = "super", name = "super",
                help = "a wall blast that takes somebody buys you back in" },
          } },
        { key = "sudden", name = "Sudden death",
          help = "the last minute: blocks fall until the middle is left",
          choices = {
              { key = "spiral", name = "a spiral from the edge",
                help = "clockwise from the corner, ring by ring" },
              { key = "random", name = "in random order",
                help = "the same cells, falling anywhere" },
              { key = "off", name = "off",
                help = "the buzzer ends it, and all still up share it" },
          } },
        { key = "items", name = "Power-ups in the blocks",
          help = "how many soft blocks hide a power-up",
          choices = {
              { key = "classic", name = "normal", help = "three blocks in ten, the series' share" },
              { key = "more", name = "more", help = "nearly half of them" },
              { key = "fewer", name = "fewer", help = "about one in seven" },
          } },
        { key = "skulls", name = "Skulls",
          help = "a skull is a ten-second curse, passed on by touch",
          choices = {
              { key = "on", name = "in the blocks", help = "eleven curses, ten seconds each" },
              { key = "off", name = "none", help = "only power-ups that help" },
          } },
    },

    presets = {
        { key = "classic", name = "Classic", help = "the usual round", sets = {} },
        { key = "royale", name = "Battle Royale", help = "super revenge, more power-ups",
          sets = { revenge = "super", items = "more" } },
        { key = "pure", name = "Pure", help = "no skulls, fewer power-ups",
          sets = { items = "fewer", skulls = "off" } },
    },

    out_cause = function() return S.outCause end,
}

local viewWas = nil

local function steepest_view()
    local entry = OF.util.asks(OF.modifiers, "BY_KEY") and OF.modifiers.BY_KEY["view"] or nil
    if entry == nil or entry.levels == nil then return nil end
    local best, steepest = nil, nil
    for index, step in ipairs(entry.levels) do
        local stand = step.view
        if type(stand) == "table" and #stand >= 4 then
            local away = (stand[1] or 0) + (stand[2] or 0)
            local up = (stand[3] or 0) + (stand[4] or 0)
            if away > 0 and (steepest == nil or up / away > steepest) then
                best, steepest = index, up / away
            end
        end
    end
    return best
end
mode.steepest_view = steepest_view

local function take_the_view()
    if not OF.util.is_host() or not OF.util.asks(OF.modifiers, "set_round_level") then return end
    local step = steepest_view()
    if step == nil then return end
    local was = OF.util.asks(OF.modifiers, "level") and OF.modifiers.level("view") or 0
    if OF.modifiers.set_round_level("view", step) == true then viewWas = was end
end

local function give_the_view_back()
    if viewWas == nil then return end
    local was = viewWas
    viewWas = nil
    if OF.util.is_host() and OF.util.asks(OF.modifiers, "set_round_level") then
        OF.modifiers.set_round_level("view", was)
    end
end

function mode.setup(players, options)
    take_the_view()
    local globals = {}
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
        local g = global_of(entry.localIndex)
        if g ~= nil then globals[#globals + 1] = g end
    end
    table.sort(globals)
    local seed = math.random(1, 999999)

    for i = #globals, 2, -1 do
        local j = math.floor(seeded01(seed, i, 21) * i) + 1
        globals[i], globals[j] = globals[j], globals[i]
    end
    local digits = {}
    for _, g in ipairs(globals) do digits[#digits + 1] = string.format("%x", g) end

    local sizeKey = option("field", "ordinary")
    local itemKey = option("items", "classic")
    local skullKey = option("skulls", "on")
    local w, h = field_size(#globals, ROOM_STOPS[sizeKey] or ROOM_STOPS.ordinary)
    OF.util.publish(KEYS.field, string.format("%.0f %.0f %.0f %.0f %s %s", seed, w, h,
        ITEM_STOPS[itemKey] or ITEM_STOPS.classic, skullKey == "off" and "0" or "1",
        table.concat(digits)))
end

function mode.pin()
    local key = place_here()
    if key == nil then
        H.noRoom = true
        return
    end
    H.noRoom = false
    local np = gNetworkPlayers[0]
    OF.util.publish(KEYS.at, string.format("%s %.0f %.0f", key, np.currLevelNum,
        np.currAreaIndex))
end

local function host_forget()
    if not OF.util.is_host() then return end
    H.bombs, H.nextId, H.bursts = {}, 1, {}
    H.gone, H.got, H.loose, H.pow, H.revealedAt = {}, {}, {}, {}, {}
    H.dirtyBombs, H.dirtyBursts, H.dirtyBoard, H.dirtyPow, H.dirtyLoose =
        false, false, false, true, false
    H.frame, H.outOrder, H.downSeen, H.seats, H.seatUntil = 0, {}, {}, {}, 0
    H.sdStarted, H.sdApplied, H.hiccupAt, H.backPending = false, 0, {}, {}
    for _, key in ipairs(BOMB_KEYS) do OF.util.publish(key, nil) end
    for _, key in ipairs(BURST_KEYS) do OF.util.publish(key, nil) end
    for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    publish_pow()
end

local function forget_round()
    S.boardText, S.gotText, S.looseText, S.powText = nil, nil, nil, nil
    S.gone, S.got, S.loose, S.pow = {}, {}, {}, {}
    S.bombs, S.bombsText, S.bursts, S.burstText = {}, nil, {}, nil
    S.sdAt, S.seats, S.seatUntil, S.seatsText = nil, {}, 0, nil
    S.askedAt, S.heartUntil, S.hurryShown = {}, 0, nil
    S.backSeen = gGlobalSyncTable[KEYS.back]
    S.wasSeated = false
end

function mode.on_start()
    host_forget()
    forget_round()
    register_asks()
    S.outCause, S.sdSaid = nil, nil

end

function mode.scenery()
    local state = OF.gamemodes.state()
    if state ~= OF.gamemodes.ACTIVE and state ~= OF.gamemodes.COUNTDOWN then
        if S.built then clear_world() end
        return
    end
    local key, place = place_here()
    local text = gGlobalSyncTable[KEYS.field]

    if key == nil or type(text) ~= "string" or not OF.util.round_screen() then
        if S.built then clear_world() end
        bg.let_the_camera_go()
        return
    end
    if text ~= S.fieldText then
        S.fieldText = text
        S.field = derive_field(text, place)
        S.order, S.orderAt = nil, nil
        forget_round()
        if S.built then clear_world() end
    end
    local f = S.field
    if f == nil then return end
    if S.order == nil then
        S.order = sd_order(f, option("sudden", "spiral") == "random")
        S.orderAt = {}
        for k, cell in ipairs(S.order) do S.orderAt[cell] = k end
    end
    local t = state == OF.gamemodes.ACTIVE and OF.gamemodes.since_start() or 0
    listen(t)
    if not S.built then build_field(f) end
    place_me(f)
    if state ~= OF.gamemodes.ACTIVE then return end
    hear_back(f)
    draw_drops(f, t)
    draw_bombs(f, t)
    draw_bursts(f, t)
    draw_items(f, t)
    bg.hold_the_camera(f)
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil then judge(f, t, m) end
end

local CAM = { UP = 2600, BACK = 550, EASE = 0.25,
              POS_H = 0.3, POS_V = 0.3, FOC_H = 0.8, FOC_V = 0.3 }
local camAt = nil
local function cam_put(vec, x, y, z)
    if vec == nil then return end
    vec.x, vec.y, vec.z = x, y, z
end
function bg.let_the_camera_go()
    if camAt == nil then return false end
    camAt = nil
    local s = gLakituState
    if s ~= nil then
        s.posHSpeed, s.posVSpeed = CAM.POS_H, CAM.POS_V
        s.focHSpeed, s.focVSpeed = CAM.FOC_H, CAM.FOC_V
    end
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end
function bg.hold_the_camera(f)
    local s = gLakituState
    if s == nil or s.pos == nil or f == nil or not in_room(0) or OF.util.hands_on() ~= nil then
        bg.let_the_camera_go()
        return nil
    end
    local m = gMarioStates[0]
    local fx, fy, fz
    if OF.gamemodes.role(0) == ROLE_IN and m ~= nil and m.pos ~= nil then
        fx, fy, fz = m.pos.x, f.y, m.pos.z
    else
        fx, fy, fz = f.x or 0, f.y, f.z or 0
    end
    if camAt == nil then
        camAt = { x = fx, z = fz }
        OF.util.optional("skip_camera_interpolation", nil)
    else
        camAt.x = camAt.x + (fx - camAt.x) * CAM.EASE
        camAt.z = camAt.z + (fz - camAt.z) * CAM.EASE
    end
    local px, py, pz = camAt.x, fy + CAM.UP, camAt.z + CAM.BACK
    cam_put(s.pos, px, py, pz)
    cam_put(s.curPos, px, py, pz)
    cam_put(s.goalPos, px, py, pz)
    cam_put(s.focus, camAt.x, fy, camAt.z)
    cam_put(s.curFocus, camAt.x, fy, camAt.z)
    cam_put(s.goalFocus, camAt.x, fy, camAt.z)
    s.posHSpeed, s.posVSpeed, s.focHSpeed, s.focVSpeed = 0, 0, 0, 0
    s.yaw = 0
    return py
end

local SWALLOW = nil
function bg.swallowed(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    if OF.gamemodes.current() ~= mode or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return nil
    end
    if OF.gamemodes.role(0) ~= ROLE_IN then return nil end
    if SWALLOW == nil then
        SWALLOW = {}
        for _, act in ipairs({ ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP, ACT_LONG_JUMP,
                               ACT_BACKFLIP, ACT_SIDE_FLIP, ACT_STEEP_JUMP, ACT_HOLD_JUMP,
                               ACT_WALL_KICK_AIR, ACT_SPECIAL_TRIPLE_JUMP,
                               ACT_FORWARD_ROLLOUT, ACT_BACKWARD_ROLLOUT,
                               ACT_GROUND_BONK, ACT_SOFT_BONK, ACT_AIR_HIT_WALL }) do
            if act ~= nil then SWALLOW[act] = true end
        end
    end
    if SWALLOW[action] then return 1 end
    return nil
end
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return bg.swallowed(m, action)
end)

function mode.before_mario_update(m)
    local f = S.field
    if f == nil or not round_live() or not S.built then return end
    if not in_room(0) then return end
    local t = OF.gamemodes.since_start()

    if camAt ~= nil and m.area ~= nil and m.area.camera ~= nil then
        m.area.camera.yaw = 0
    end
    if OF.gamemodes.role(0) == ROLE_OUT then

        local watching = OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active()
        if revenge_mode() ~= "off" and S.sdAt == nil and seated(my_global()) and not watching then
            S.wasSeated = true
            on_the_wall(f, t, m)
        else
            if S.wasSeated then
                S.wasSeated = false

                local x, z = cell_world(f, cell_at(f, 0, 0))
                OF.net.snap_to(x - K.CELL, f.y + 10, z - K.CELL, nil)
            end

            OF.gamemodes.set_ghost(true)
        end
        return
    end
    if not am_in() then return end
    local p = pow_of(my_global())
    if keep_off_tops(f, t, m) then return end
    local refused = bump_bombs(f, t, m)
    steer(m, p, t)
    hands(f, t, m, p, refused)
end

function mode.update()
    if not am_in() or not round_live() then return end
    local m = gMarioStates[0]
    if m == nil then return end

    if (m.health or 0) < 0x880 then m.health = 0x880 end
    m.hurtCounter = 0
end

local ARRIVE = 8
local function still_up()
    local list = {}
    local early = OF.gamemodes.since_start() < ARRIVE
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_IN)) do
        if OF.util.can_play(entry.localIndex) and (early or in_room(entry.localIndex)) then
            list[#list + 1] = entry
        end
    end
    return list
end

function mode.host_update()
    if H.noRoom then
        OF.gamemodes.abandon("Blast Grid needs The Tiles.")
        return
    end
    host_tick(OF.gamemodes.since_start())

    local now = OF.gamemodes.since_start()
    for g, at in pairs(H.backPending) do
        local li = OF.util.local_from_global(g)
        if (li ~= nil and OF.gamemodes.role(li) == ROLE_IN) or now - at > 3 then
            H.backPending[g] = nil
        end
    end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_OUT)) do
        local g = global_of(entry.localIndex)
        if g ~= nil and not H.downSeen[g] and H.backPending[g] == nil and S.field ~= nil then
            H.downSeen[g] = true
            H.outOrder[#H.outOrder + 1] = g
            scatter(S.field, host_pow(g), g, OF.gamemodes.since_start())
            H.pow[g] = fresh_pow()
            H.dirtyPow = true
        end
    end
    local up = still_up()
    if #up == 1 then
        local np = up[1].np or gNetworkPlayers[up[1].localIndex]
        OF.gamemodes.finish("@ won.", np.name, np.name)
    elseif #up == 0 and #OF.gamemodes.with_role(ROLE_OUT) > 0 then
        OF.gamemodes.finish("Nobody won - the last blasts took everybody.")
    elseif #up == 0 then
        OF.gamemodes.abandon("Nobody left on the field.")
    end
end

function mode.on_timeout()
    local up = still_up()
    if #up == 1 then
        local np = up[1].np or gNetworkPlayers[up[1].localIndex]
        OF.gamemodes.finish("@ won.", np.name, np.name)
        return
    end
    if #up == 0 then
        OF.gamemodes.finish("Nobody won.")
        return
    end
    local names = {}
    for _, entry in ipairs(up) do
        local np = entry.np or gNetworkPlayers[entry.localIndex]
        if np ~= nil and np.name ~= nil then names[#names + 1] = np.name end
    end
    OF.gamemodes.finish(#up == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names }, tostring(#up))
end

function mode.late_join(localIndex)
    return nil
end

function mode.cleanup()
    give_the_view_back()
    bg.let_the_camera_go()
    clear_world()
    S.field, S.fieldText, S.order, S.orderAt = nil, nil, nil, nil
    forget_round()
    S.placedFor, S.lastFree, S.pendingLay = nil, nil, nil
    if OF.util.is_host() then
        for _, key in ipairs(BOMB_KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(BURST_KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(ALL_KEYS) do OF.util.publish(key, nil) end
        H.bombs, H.bursts = {}, {}
    end
end

function mode.terms()
    local revenge = OF.gamemodes.option_showing(mode.key, "revenge") or "on"
    local sudden = OF.gamemodes.option_showing(mode.key, "sudden") or "spiral"
    local first = (revenge == "off") and "no revenge" or
        (revenge == "super" and "Super revenge" or "wall revenge")
    local second = (sudden == "off") and "no sudden death" or "sudden death 1:00"
    return OF.lang.fill("last one up, @, @", first, second)
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

local labelAt = { x = 0, y = 0, z = 0 }
local labelOut = { x = 0, y = 0, z = 0 }
local SQUARE = {
    { x = -K.CELL / 2, z = -K.CELL / 2 }, { x = K.CELL / 2, z = -K.CELL / 2 },
    { x = K.CELL / 2, z = K.CELL / 2 }, { x = -K.CELL / 2, z = K.CELL / 2 },
}

local function label_items(f, m)
    local function one(cell, kind)
        local x, z = cell_world(f, cell)
        if (x - m.pos.x) ^ 2 + (z - m.pos.z) ^ 2 > 1100 * 1100 then return end
        labelAt.x, labelAt.y, labelAt.z = x, f.y + 190, z
        local row = ITEM_ROWS[kind]
        if row ~= nil and OF.util.world_screen(labelAt, labelOut) then
            local r, g, b = OF.util.round_tone(kind == ITEM.SKULL and "bad" or "gold")
            OF.util.world_label(labelOut.x, labelOut.y, OF.lang.t(row.word), 0.6, r, g, b, 230)
        end
    end
    for index, kind in pairs(f.item) do
        if S.gone[index] and not S.got[index] then one(f.softCell[index], kind) end
    end
    for _, item in ipairs(S.loose) do one(item.cell, item.kind) end
end

local function mark_drops(f, t)
    if S.sdAt == nil or S.order == nil then return end
    for k, cell in ipairs(S.order) do
        local lands = sd_land_time(f, S.order, k, S.sdAt)
        if lands - K.SHADOW - K.DROP_TIME > t then break end
        if lands > t then
            local x, z = cell_world(f, cell)
            labelAt.x, labelAt.y, labelAt.z = x, f.y + 4, z
            OF.util.world_outline(labelAt, SQUARE, 4, 255, 90, 60, 220)
        end
    end
end

local function legend(p, t)
    local lines = { OF.lang.t("B - lay a Bob-omb") }
    if p.glove then lines[#lines + 1] = OF.lang.t("B facing a Bob-omb - punch it over") end
    if p.kick then lines[#lines + 1] = OF.lang.t("Run into a Bob-omb - kick it") end
    if p.remote then lines[#lines + 1] = OF.lang.t("Z - set off your oldest Bob-omb") end
    lines[#lines + 1] = OF.lang.fill("Speed @ of @", tostring(p.speed), tostring(K.SPEED_STEPS))
    OF.util.legend(lines)
end

function mode.hud()
    local f = S.field
    if f == nil then return end
    local t = OF.gamemodes.since_start()
    local m = gMarioStates[0]

    if S.sdAt ~= nil and S.sdSaid ~= S.sdAt and t - S.sdAt < 3 then
        S.sdSaid = S.sdAt
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("roundstate", OF.lang.t("SUDDEN DEATH"), OF.lang.t("The blocks are falling"))
        end
    end
    mark_drops(f, t)
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if OF.gamemodes.role(0) == ROLE_OUT then

        OF.gamemodes.out_banner()
        if revenge_mode() ~= "off" and S.sdAt == nil then
            if seated(my_global()) then
                state("wall", OF.lang.t("On the wall"), { prio = 50, tone = "target" })
                OF.util.legend({ OF.lang.t("B - throw a Bob-omb in"),
                    OF.lang.t("One at a time") })
            elseif #S.seats >= K.SEATS then
                state("seat", OF.lang.t("Seat in"), { prio = 50, tone = "mute",
                    figure = math.max(1, math.floor(S.seatUntil - t + 0.5)) })
            end
        end
        return
    end
    if not in_room(0) then
        OF.gamemodes.away_banner("The field is somewhere else")
        return
    end
    local p = pow_of(my_global())

    if p.curse ~= 0 and t < p.curseUntil then
        state("skull", OF.lang.t("Skull"), { prio = 70, tone = "warn",
            figure = math.max(1, math.ceil(p.curseUntil - t)) })
    end
    state("loadout", nil, { prio = 50, icons = mode.loadout_icons(p) })
    legend(p, t)
    if m ~= nil and m.pos ~= nil then label_items(f, m) end
end

function mode.loadout_icons(p)
    local items = { { icon = "bomb", count = p.bombs, tone = "ink" },
                    { icon = "cross", count = p.fire, tone = "warn" } }
    for _ = 1, math.max(0, p.hearts or 0) do
        items[#items + 1] = { icon = "heart", tone = "bad" }
    end
    return items
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or OF.gamemodes.current() ~= mode or not round_live() then return end
    if OF.gamemodes.role(m.playerIndex) ~= ROLE_IN then return end
    local g = global_of(m.playerIndex)
    if g == nil then return end
    local t = OF.gamemodes.since_start()
    if not cursed(pow_of(g), CURSE.INVISIBLE, t) then return end
    local body = m.marioBodyState
    if body == nil or type(body.modelState) ~= "number" then return end
    local alpha = 0
    if m.playerIndex == 0 then alpha = 0x60
    elseif (t % 1) < K.BLINK then alpha = 0 else return end
    if not OF.util.has_flag(body.modelState, 0x100) then
        body.modelState = body.modelState - body.modelState % 0x100 + 0x100 + alpha
    end
end)

bg.K = K
bg.KEYS = KEYS
bg.BOMB_KEYS = BOMB_KEYS
bg.BURST_KEYS = BURST_KEYS
bg.ITEM = ITEM
bg.CURSE = CURSE
bg.PLACES = PLACES
bg.field_size = field_size
bg.LOOK = LOOK
bg.model_of = model_of
bg.open_cells = open_cells
bg.derive_field = derive_field
bg.start_cells = start_cells
bg.sd_order = sd_order
bg.sd_land_time = sd_land_time
bg.cell_world = cell_world
bg.cell_of = cell_of
bg.cell_at = cell_at
bg.cell_xz = cell_xz
bg.pack_bomb = pack_bomb
bg.unpack_bomb = unpack_bomb
bg.pack_burst = pack_burst
bg.unpack_burst = unpack_burst
bg.pack_pow = pack_pow
bg.unpack_pow = unpack_pow
bg.bits_to_hex = bits_to_hex
bg.hex_to_bits = hex_to_bits
bg.burst_cells = burst_cells
bg.slide_cell = slide_cell
bg.slide_end = slide_end
bg.landing = landing
bg.host_lay = host_lay
bg.host_pow = host_pow
bg.host_burst = host_burst
bg.host_tick = host_tick
bg.apply_item = apply_item
bg.scatter = scatter
bg.register_asks = register_asks
bg.ASK_DOWN = ASK.down
function bg.state() return S end
function bg.host() return H end
function bg.field() return S.field end

function bg.use_field(f)
    S.field = f
    S.fieldText = f ~= nil and f.text or nil
    if f ~= nil then
        S.order = sd_order(f, false)
        S.orderAt = {}
        for k, cell in ipairs(S.order) do S.orderAt[cell] = k end
    end
end
bg.mode = mode

OF.gamemodes.register(mode)
