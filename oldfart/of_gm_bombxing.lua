OF = OF or {}
OF.ring = OF.ring or {}
OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local ROLE_IN = "in"
local ROLE_OUT = "out"
local START_ACROSS = 1200
local WIDEST_ACROSS = 1800
local OUT_DROP = 400

local RUN = 32
local SPEED = { 0.3 * RUN, 0.5 * RUN, 0.9 * RUN }
local WANDER, CHASE, FAST = 1, 2, 3

local WEIGHTS = { 70, 30, 0 }
local SHIFT = { -5, -5, 10 }
local SHIFT_EVERY = 30
local FAST_MOST = 40

local CAP_BASE = 5
local CAP_TOP = 14
local GROW_EVERY = 10
local MAX_BOMBS = 40

local ENTER_EVERY = 0.3

local FUSE_LEAST, FUSE_MOST = 3, 8
local FLASH = { { 60, 1.0 }, { 120, 0.83 }, { 180, 0.67 }, { 210, 0.5 },
                { 240, 0.33 } }
local FLASH_LAST = 0.17

local WANDER_LEAST, WANDER_MOST = 2, 4

local STEER_EVERY = 0.5

local EDGE_SHARE = 0.92

local INWARD = 0.7

local GATES = 16
local GATE_JITTER = 0.8
local CROSS_SHARE = 0.5

local HUNT_SHARE = 0.15
local CROSS_INWARD = 0.8

local WAVE_FIRST = 8
local WAVE_GAP_START, WAVE_GAP_LEAST, WAVE_GAP_SHRINK = 12, 6, 10
local WAVE_MOST = 12
local WAVE_SPACING_LEAST, WAVE_SPACING_MOST = 140, 240
local WAVE_TILT = 0.35
local RING_STOP = 0.55
local FILE_EVERY = 0.35
local WAVE_LINE, WAVE_PINCER, WAVE_RING, WAVE_FILE = 1, 2, 3, 4
local WAVE_SHAPES = 4

local PACE_MOST = 0.6
local PACE_FULL = 120

local BOBOMB_ANIMS = "bobomb_seg8_anims_0802396C"
local ANIM_WALK = 0
local STRIDE = { 1.0, 1.6, 2.6 }
local STAND_RATE = 0.4
local FLASH_RATE = 3.0

local BLAST_RADIUS = 150
local BLAST_BELOW = 150
local BLAST_LIFT = 60
local BLAST_HOLD = 0.3
local BODY_RADIUS, BODY_TALL = 65, 113
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100

local TOUCH_ACTION = "bxtouch"
local TOUCH_SLACK = 600

local KEYS = { "ofBxBombs", "ofBxBombs2", "ofBxBombs3", "ofBxBombs4", "ofBxBombs5" }
local CHUNK = 160
local ENTRY = 17
local OFFSET = 23000
local PUBLISH_EVERY = 3

local hostBombs = {}
local nextId = 1
local lastEnter = -99
local hostFrame = 0
local dirty = false

local hostWaves = 0
local nextWave = WAVE_FIRST
local hostQueue = {}
local bombs = {}
local wireSeen = nil
local drawn = {}
local blown = {}
local judged = {}
local fused = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    drawn = {}
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

local function flash_for(t)
    for _, step in ipairs(FLASH) do
        if t < step[1] then return step[2] end
    end
    return FLASH_LAST
end

local function cap_for(t, players)
    local n = math.max(players or 0, 1)
    local grown = (CAP_BASE + n) + math.floor(t / GROW_EVERY) * math.max(math.ceil(n / 3), 2)
    local cap = math.min(grown, CAP_TOP + 2 * n)

    if OF.gamemodes.option_now("bombs") == "more" then cap = math.floor(cap * 1.5 + 0.5) end
    return math.min(cap, MAX_BOMBS)
end

local function weights_at(t)
    local shifts = math.floor(t / SHIFT_EVERY)
    local most = (FAST_MOST - WEIGHTS[3]) / SHIFT[3]
    shifts = math.min(shifts, most)
    return { WEIGHTS[1] + SHIFT[1] * shifts, WEIGHTS[2] + SHIFT[2] * shifts,
             WEIGHTS[3] + SHIFT[3] * shifts }
end

local function kind_for(t, roll)
    local w = weights_at(t)
    local at = roll * (w[1] + w[2] + w[3])
    if at < w[1] then return WANDER end
    if at < w[1] + w[2] then return CHASE end
    return FAST
end

local function pace_at(t)
    return 1 + PACE_MOST * math.min(math.max(t or 0, 0) / PACE_FULL, 1)
end

local function bomb_pos(b, t)
    local stop = b.boom - flash_for(b.boom)
    local flashing = t >= stop
    local walked = 0
    if b.walking then
        walked = math.max(math.min(t, stop) - b.seg, 0) * 30 * SPEED[b.kind]
            * pace_at(b.seg)
    end
    return b.x + math.sin(b.yaw) * walked, b.z + math.cos(b.yaw) * walked, flashing
end

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

local function pack_entry(b, at)
    return to36(b.id % 1296, 2)
        .. to36((b.kind - 1) * 2 + (b.walking and 1 or 0), 1)
        .. to36(b.x - at.x + OFFSET, 3) .. to36(b.z - at.z + OFFSET, 3)
        .. to36(math.floor((b.yaw % (2 * math.pi)) / (2 * math.pi) * 1296 + 0.5) % 1296, 2)
        .. to36(b.seg * 10, 3) .. to36(b.boom * 10, 3)
end

local function unpack_entry(e, at)
    if #e ~= ENTRY then return nil end
    local kw = from36(string.sub(e, 3, 3))
    return { id = from36(string.sub(e, 1, 2)),
             kind = math.floor(kw / 2) + 1, walking = kw % 2 == 1,
             x = from36(string.sub(e, 4, 6)) - OFFSET + at.x,
             z = from36(string.sub(e, 7, 9)) - OFFSET + at.z,
             yaw = from36(string.sub(e, 10, 11)) / 1296 * 2 * math.pi,
             seg = from36(string.sub(e, 12, 14)) / 10,
             boom = from36(string.sub(e, 15, 17)) / 10 }
end

local function sorted_ids(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local FULL_EVERY = 5
local sentAs, sendsSinceFull = {}, FULL_EVERY
function OF.gm_bombxing_forget_sent()
    sentAs, sendsSinceFull = {}, FULL_EVERY
end
local function publish_all(at)
    local parts = {}
    local full = sendsSinceFull >= FULL_EVERY
    for _, id in ipairs(sorted_ids(hostBombs)) do
        local text = pack_entry(hostBombs[id], at)
        if full or sentAs[id] ~= text then parts[#parts + 1] = text end
        sentAs[id] = text
    end
    if #parts == 0 then
        sendsSinceFull = sendsSinceFull + 1
        return
    end
    sendsSinceFull = full and 1 or sendsSinceFull + 1
    local chunks = OF.util.chunk_parts(parts, CHUNK) or {}

    OF.gamemodes.stream_send(KEYS[1], chunks)
end

local function listen(at, t)
    local text = OF.gamemodes.stream_read(KEYS[1]) or ""
    if text ~= wireSeen then
        wireSeen = text
        for i = 1, #text - ENTRY + 1, ENTRY do
            local b = unpack_entry(string.sub(text, i, i + ENTRY - 1), at)
            if b ~= nil and not blown[b.id] then bombs[b.id] = b end
        end
    end
    for id, b in pairs(bombs) do
        if t > b.boom + 1 then bombs[id] = nil end
    end
end

local function hunted(b)
    if b.hunt == nil then return nil end
    for _, entry in ipairs(OF.ring.pushable()) do
        if entry.np ~= nil and entry.np.globalIndex == b.hunt then
            local m = gMarioStates[entry.localIndex]
            if m ~= nil and m.pos ~= nil then return m end
        end
    end
    return nil
end

local function nearest(x, z)
    local best, bestD = nil, nil
    for _, entry in ipairs(OF.ring.pushable()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil then
            local dx, dz = m.pos.x - x, m.pos.z - z
            local d = dx * dx + dz * dz
            if bestD == nil or d < bestD then best, bestD = m, d end
        end
    end
    return best
end

local function turn(b, t, yaw, walking)
    local x, z = bomb_pos(b, t)
    b.x, b.z, b.seg, b.yaw, b.walking = x, z, t, yaw, walking
    dirty = true
end

local function inward_yaw(b, x, z, at, r, salt, share)
    local a = seeded01(b.id, salt, 7) * 2 * math.pi
    local out = math.sqrt(seeded01(b.id, salt, 8)) * r * (share or INWARD)
    local tx, tz = at.x + math.sin(a) * out, at.z + math.cos(a) * out
    return math.atan(tx - x, tz - z)
end

local function wave_size(players)
    return math.min(4 + math.floor(math.max(players or 0, 0) / 2), WAVE_MOST)
end

local function wave_gap(t)
    return math.max(WAVE_GAP_START - math.floor(t / WAVE_GAP_SHRINK), WAVE_GAP_LEAST)
end

local function enter(t, at, r, spec)
    if not OF.util.is_host() then return nil end
    local id = nextId
    nextId = nextId + 1
    local gate, gx, gz
    if spec ~= nil and spec.angle ~= nil then
        gate = -1
        gx = at.x + math.sin(spec.angle) * r * EDGE_SHARE
        gz = at.z + math.cos(spec.angle) * r * EDGE_SHARE
    else

        gate = math.floor(seeded01(id, 1, 1) * GATES)
        local slice = 2 * math.pi / GATES
        local jitter = (seeded01(id, 1, 9) - 0.5) * GATE_JITTER * slice
        for step = 0, GATES - 1 do
            local g = (gate + step) % GATES
            local busy = false
            for _, b in pairs(hostBombs) do
                if t - b.born < 1 and b.gate == g then busy = true end
            end
            if not busy then gate = g break end
        end
        local a = gate * slice + jitter
        gx, gz = at.x + math.sin(a) * r * EDGE_SHARE, at.z + math.cos(a) * r * EDGE_SHARE
    end
    local kind = (spec ~= nil and spec.kind) or kind_for(t, seeded01(id, 2, 2))

    local firstTurn = t + STEER_EVERY
    if kind == WANDER then
        firstTurn = t + WANDER_LEAST + (WANDER_MOST - WANDER_LEAST) * seeded01(id, 5, 5)
    end
    local b = { id = id, kind = kind, walking = true,
                x = gx, z = gz, seg = t, born = t, gate = gate,
                boom = t + FUSE_LEAST + (FUSE_MOST - FUSE_LEAST) * seeded01(id, 3, 3),
                nextTurn = firstTurn }
    if spec == nil and seeded01(id, 6, 6) < HUNT_SHARE then
        local room = OF.ring.pushable()
        local pick = room[math.floor(seeded01(id, 6, 7) * #room) + 1]
        if pick ~= nil and pick.np ~= nil then
            b.kind, b.hunt, b.nextTurn = CHASE, pick.np.globalIndex, t + STEER_EVERY
        end
    end
    if spec ~= nil and spec.fuse ~= nil then b.boom = t + spec.fuse end
    b.boom = b.boom + flash_for(b.boom)
    if spec ~= nil and spec.yaw ~= nil then
        b.yaw = spec.yaw
    else
        local crossing = seeded01(id, 4, 6) < CROSS_SHARE
        b.yaw = inward_yaw(b, gx, gz, at, r, 0, crossing and CROSS_INWARD or INWARD)
    end
    if spec ~= nil and spec.nextTurn ~= nil then b.nextTurn = spec.nextTurn end

    if b.kind ~= WANDER and (spec == nil or spec.yaw == nil) then
        local m = hunted(b) or nearest(gx, gz)
        if m ~= nil then b.yaw = math.atan(m.pos.x - gx, m.pos.z - gz) end
    end
    hostBombs[id] = b
    dirty = true
    return b
end

local function across(a)
    return a + math.pi
end

local function plan_wave(n, t, r, size, shape)
    shape = shape or (math.floor(seeded01(n, 11, 12) * WAVE_SHAPES) + 1)
    local base = seeded01(n, 13, 14) * 2 * math.pi
    local spacing = WAVE_SPACING_LEAST
        + (WAVE_SPACING_MOST - WAVE_SPACING_LEAST) * seeded01(n, 15, 16)
    local tilt = (seeded01(n, 17, 18) - 0.5) * 2 * WAVE_TILT
    local fuse = FUSE_LEAST + 1 + (FUSE_MOST - FUSE_LEAST - 1) * seeded01(n, 19, 20)
    local plan = {}
    local function line(centre, count, heading)

        local step = math.min(spacing / math.max(r * EDGE_SHARE, 1),
            (2 * math.pi / 3) / math.max(count, 1))
        for j = 1, count do
            local off = (j - (count + 1) / 2) * step

            plan[#plan + 1] = { at = t, angle = centre + off, yaw = heading,
                kind = WANDER, fuse = fuse + (j - 1) * 0.15,
                nextTurn = t + fuse * 0.8 }
        end
    end
    if shape == WAVE_LINE then
        line(base, size, across(base) + tilt)
    elseif shape == WAVE_PINCER then
        local half = math.ceil(size / 2)
        line(base, half, across(base) + tilt)
        line(base + math.pi, size - half, base + tilt)
    elseif shape == WAVE_RING then

        local walk = r * (EDGE_SHARE - RING_STOP) / (30 * SPEED[WANDER] * pace_at(t))
        for j = 1, size do
            local a = base + (j - 1) * 2 * math.pi / size
            plan[#plan + 1] = { at = t, angle = a, yaw = across(a), kind = WANDER,
                fuse = math.max(walk + 1.2, FUSE_LEAST), nextTurn = t + walk }
        end
    else

        for j = 1, size do
            plan[#plan + 1] = { at = t + (j - 1) * FILE_EVERY, angle = base,
                kind = CHASE, fuse = fuse }
        end
    end
    return plan, shape
end

local function host_tick(t)
    if not OF.util.is_host() then return end
    local at, r = OF.ring.at(), OF.ring.radius()
    if at == nil or r == nil then return end
    hostFrame = hostFrame + 1
    local count = 0
    for id, b in pairs(hostBombs) do
        if t > b.boom + BLAST_HOLD then
            hostBombs[id] = nil
            dirty = true
        else
            count = count + 1
            local x, z, flashing = bomb_pos(b, t)
            if not flashing then
                local dx, dz = x - at.x, z - at.z
                local out = math.sqrt(dx * dx + dz * dz)
                local outward = math.sin(b.yaw) * dx + math.cos(b.yaw) * dz > 0
                if out > r * EDGE_SHARE and outward and b.walking then
                    turn(b, t, inward_yaw(b, x, z, at, r, math.floor(t * 10)), true)
                elseif t >= b.nextTurn then
                    if b.kind == WANDER then
                        local span = WANDER_LEAST
                            + (WANDER_MOST - WANDER_LEAST) * seeded01(b.id, math.floor(t * 10), 4)
                        b.nextTurn = t + span
                        if b.walking then
                            turn(b, t, b.yaw, false)
                        else
                            turn(b, t, seeded01(b.id, math.floor(t * 10), 5) * 2 * math.pi, true)
                        end
                    else
                        b.nextTurn = t + STEER_EVERY
                        local m = hunted(b) or nearest(x, z)
                        if m ~= nil then
                            turn(b, t, math.atan(m.pos.x - x, m.pos.z - z), true)
                        end
                    end
                end
            end
        end
    end
    local players = #OF.ring.pushable()
    local want = cap_for(t, players)
    if count < want and t - lastEnter >= ENTER_EVERY then
        lastEnter = t
        enter(t, at, r)
        count = count + 1
    end

    if t >= nextWave then
        hostWaves = hostWaves + 1
        nextWave = t + wave_gap(t)
        local size = math.min(wave_size(players), MAX_BOMBS - count - #hostQueue)
        if size > 0 then
            local plan = plan_wave(hostWaves, t, r, size)
            for _, spec in ipairs(plan) do hostQueue[#hostQueue + 1] = spec end
        end
    end
    local i = 1
    while i <= #hostQueue do
        local spec = hostQueue[i]
        if t >= spec.at then
            table.remove(hostQueue, i)
            if count < MAX_BOMBS then
                enter(t, at, r, spec)
                count = count + 1
            end
        else
            i = i + 1
        end
    end

    local refresh = hostFrame % (PUBLISH_EVERY * FULL_EVERY) == 0
    if (dirty or refresh) and hostFrame % PUBLISH_EVERY == 0 then
        dirty = false
        if refresh then sendsSinceFull = FULL_EVERY end
        publish_all(at)
    end
end

local function gone(o)
    return o == nil or o.activeFlags == 0
end

local function drop(o)
    if not gone(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function clear_all()
    for id, o in pairs(drawn) do drop(o) drawn[id] = nil end
end

local function floor_under(x, z, at)
    local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
    if type(y) ~= "number" or y < at.y - 600 then return at.y end
    return y
end

local blasts = {}

local function boom(id, x, y, z, t)
    blasts[id] = { x = x, y = y, z = z, t = t }
    local o = OF.util.optional("spawn_non_sync_object", nil,
        id_bhvExplosion, E_MODEL_EXPLOSION, x, y, z, nil)
    if o == nil then return end

    o.oIntangibleTimer = -1
    o.oInteractType = 0
end

local function blow(id, x, z, at, t)
    drop(drawn[id])
    drawn[id] = nil
    if blown[id] then return end
    blown[id] = true
    boom(id, x, floor_under(x, z, at) + BLAST_LIFT, z, t)
    OF.gamemodes.round_sound_throttled("bxboom", 4,
        SOUND_GENERAL2_BOBOMB_EXPLOSION, nil)
end

local function pose(o)
    local anims = gObjectAnimations ~= nil and gObjectAnimations[BOBOMB_ANIMS] or nil
    if anims == nil then return end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, ANIM_WALK, 1.0)
end

local WARN_REACH = BLAST_RADIUS + 250

local function warn_me(id, x, z)
    if fused["w" .. id] then return end
    fused["w" .. id] = true
    if OF.ring.am_out() or not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local dx, dz = m.pos.x - x, m.pos.z - z
    if dx * dx + dz * dz <= WARN_REACH * WARN_REACH then
        OF.gamemodes.cue("hazard", nil, "bxnear")
    end
end

local function draw(t, at)
    for id, b in pairs(bombs) do
        local x, z, flashing = bomb_pos(b, t)
        if flashing and t < b.boom then warn_me(id, x, z) end
        if t >= b.boom then
            blow(id, x, z, at, t)
        else
            local o = drawn[id]
            local y = floor_under(x, z, at)
            if gone(o) then
                o = OF.util.optional("spawn_non_sync_object", nil,
                    id_bhvStaticObject, E_MODEL_BLACK_BOBOMB, x, y, z, nil)
                drawn[id] = o

                if o ~= nil then pose(o) end
            end
            if o ~= nil then

                local rate = STAND_RATE
                if flashing then
                    rate = FLASH_RATE
                elseif b.walking then
                    rate = STRIDE[b.kind] * pace_at(b.seg)
                end

                if o.oAnimations ~= nil then
                    OF.util.optional("obj_init_animation_with_accel_and_sound", nil,
                        o, ANIM_WALK, rate)
                end
                o.oPosX, o.oPosY, o.oPosZ = x, y, z

                if flashing then
                    OF.gamemodes.round_sound_from(o, SOUND_AIR_BOBOMB_LIT_FUSE)
                end
                o.oFaceAngleYaw = math.floor(b.yaw * 32768 / math.pi) % 65536

                local scale = 1.0
                if flashing and math.floor(t * 12) % 2 == 0 then scale = 1.3 end

                if b.kind == FAST then scale = scale * 1.2 end
                OF.util.optional("obj_scale", nil, o, scale)
            end
        end
    end
    for id, o in pairs(drawn) do
        if bombs[id] == nil then drop(o) drawn[id] = nil end
    end
end

local function body_tall(m)
    if m.action ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0 then return MARIO_SHORT end
    return MARIO_TALL
end

local function caught(m, t)
    if m == nil or m.pos == nil then return false end
    local tall = body_tall(m)
    for id, blast in pairs(blasts) do
        if t - blast.t > BLAST_HOLD then
            blasts[id] = nil
        else
            local dx, dz = m.pos.x - blast.x, m.pos.z - blast.z
            local reach = BLAST_RADIUS + MARIO_RADIUS
            if dx * dx + dz * dz < reach * reach
                and m.pos.y < blast.y and m.pos.y + tall > blast.y - BLAST_BELOW then
                return true
            end
        end
    end
    return false
end

local function touching(m, t)
    if m == nil or m.pos == nil then return nil end
    local tall = body_tall(m)
    for id, b in pairs(bombs) do
        local o = drawn[id]
        if t < b.boom and not blown[id] and not gone(o) then
            local scale = 1
            if o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.scale ~= nil then
                scale = o.header.gfx.scale.x or 1
            end
            local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
            local reach = BODY_RADIUS * scale + MARIO_RADIUS
            if dx * dx + dz * dz < reach * reach
                and m.pos.y < o.oPosY + BODY_TALL * scale and m.pos.y + tall > o.oPosY then
                return id
            end
        end
    end
    return nil
end

local registered = false
local function register_touch()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action(TOUCH_ACTION, "round_move", function(fromLocal, idText)
        if not OF.util.is_host() then return false, "Only the host." end
        if OF.gamemodes.current() == nil or OF.gamemodes.current().key ~= "bombxing"
            or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
            return false, "No round."
        end
        local at = OF.ring.at()
        local b = hostBombs[tonumber(idText) or -1]
        if at == nil or b == nil then return false, "No such Bob-omb." end
        local t = OF.gamemodes.since_start()
        if t >= b.boom then return true end
        local x, z = bomb_pos(b, t)

        local m = gMarioStates[tonumber(fromLocal) or -1]
        if m == nil or m.pos == nil
            or (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 > TOUCH_SLACK * TOUCH_SLACK then
            return false, "Not near that Bob-omb."
        end
        b.x, b.z, b.seg, b.walking = x, z, t, false
        b.boom = t
        dirty = false
        publish_all(at)
        return true
    end)
end

local function judge_frame(t, at)
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    if OF.gamemodes.in_grace() then return end
    local id = touching(m, t)
    if id ~= nil then
        local b = bombs[id]
        local x, z = bomb_pos(b, t)
        b.boom = t
        blow(id, x, z, at, t)
        register_touch()
        if OF.util.asks(OF.net, "host_does") then
            OF.util.report(OF.net.host_does(TOUCH_ACTION, id))
        end
        OF.ring.go_out("Touched a Bob-omb")
        return
    end
    if caught(m, t) then
        OF.ring.go_out("Caught in a Bob-omb's blast")
    end
end

local mode = {
    key = "bombxing",
    resultsBy = "survival",
    name = "Blast Crossing",
    blurb = "walking Bob-ombs keep coming in - be anywhere but the blast",
    aims = { [ROLE_IN] = "Stay out of every blast - one and you are out." },
    how = "Bob-ombs walk in from all round the arena's edge.\n"
        .. "Some wander, some chase the nearest player.\n"
        .. "Each one blows up a few seconds after it walks in.\n"
        .. "It stops and flashes first: that is your warning.\n"
        .. "Touch one and it goes off - and you are out.\n"
        .. "Caught in a blast is out. Off the edge is out too.\n"
        .. "More of them come in as it runs.\n"
        .. "Last one standing wins, or all still up at the buzzer.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "the_plate", "desert_cage", "aquarium" },
    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    defaultLimit = 120,
    saysOut = true,
    lensRole = ROLE_OUT,
    music = SEQ_EVENT_BOSS,

    target = { name = "arena width",
               asks = "Arena width",
               shownIf = function() return false end,
               default = START_ACROSS,
               min = 800, max = WIDEST_ACROSS, step = 100 },

    out_cause = function() return OF.ring.cause and OF.ring.cause() or nil end,
    options = {
        { key = "size", name = "Arena size",
          help = "how big the arena starts - it grows with the lobby",
          choices = {
              { key = "normal", name = "normal", help = "the usual arena, grown for a big lobby" },
              { key = "snug", name = "snug", help = "a smaller arena - less room to dodge" },
              { key = "roomy", name = "roomy", help = "a bigger arena - more room to run" },
          } },

        { key = "bombs", name = "Bob-ombs",
          help = "how many Bob-ombs walk the arena at once",
          choices = {
              { key = "normal", name = "normal", help = "the usual crowd, growing as it runs" },
              { key = "more", name = "more", help = "half as many again - very little room" },
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

local function host_forget()
    if not OF.util.is_host() then return end
    hostBombs, nextId, lastEnter, hostFrame, dirty = {}, 1, -99, 0, false
    OF.gm_bombxing_forget_sent()
    hostWaves, nextWave, hostQueue = 0, WAVE_FIRST, {}
end

function mode.on_start()
    OF.ring.on_start()
    host_forget()
    bombs, wireSeen, blown, judged, fused, blasts = {}, nil, {}, {}, {}, {}
    clear_all()
    register_touch()

end

function mode.scenery()
    local at = OF.ring.at()

    if at == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or not OF.util.round_screen() then
        clear_all()
        return
    end
    local t = OF.gamemodes.since_start()
    listen(at, t)
    draw(t, at)
    judge_frame(t, at)
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
    local at = OF.ring.at()
    if at == nil then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if (m.health or 0) < 0x880 then m.health = 0x880 end
    m.hurtCounter = 0
    m.peakHeight = m.pos.y
    if m.pos.y < at.y - OUT_DROP then
        OF.ring.go_out("Off the edge")
        return
    end
    if OF.ring.timed_out(0) then
        OF.ring.go_out("Off the arena")
    end
end

function mode.host_update()
    host_tick(OF.gamemodes.since_start())
    local ending, who = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.", who.np.name, who.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left on the arena for the Bob-ombs.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("The Bob-ombs got everybody.")
    end
end

mode.symmetric = true
function mode.overtime()
    return OF.ring.overtime(20)
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
    OF.gamemodes.finish(#standing == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names },
        tostring(#standing))
end

function mode.cleanup()
    clear_all()
    bombs, wireSeen, blown, judged, fused, blasts = {}, nil, {}, {}, {}, {}
    if OF.util.is_host() then
        OF.gamemodes.stream_send(KEYS[1], nil)
    end
    OF.ring.let_go()
end

function mode.terms()

    return OF.lang.fill("last one up, @ arena, @ bombs at most",
        OF.lang.t(OF.gamemodes.option_showing("bombxing", "size") or "normal"), tostring(MAX_BOMBS))
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at, r = OF.ring.at(), OF.ring.radius()
    if at ~= nil and r ~= nil then
        OF.util.zone_ring(at, r, 48, 4, 255, 200, 120, 200, "edge")
    end
    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

end

mode.bomb_pos = bomb_pos
mode.pace_at = pace_at
mode.plan_wave = plan_wave
mode.wave_size = wave_size
mode.wave_gap = wave_gap
function mode.drawn()
    return drawn
end
mode.HUNT_SHARE, mode.WANDER_LEAST = HUNT_SHARE, WANDER_LEAST

function mode.host_bombs()
    return hostBombs
end
mode.cap_for = cap_for
mode.weights_at = weights_at
mode.flash_for = flash_for
mode.pack_entry = pack_entry
mode.unpack_entry = unpack_entry
function mode.bombs()
    return bombs
end

function mode.hear(b)
    if b ~= nil and b.id ~= nil then bombs[b.id] = b end
end

function mode.blasts()
    return blasts
end
mode.touching = touching
function mode.numbers()
    return { blast = BLAST_RADIUS, blastBelow = BLAST_BELOW, body = BODY_RADIUS,
             bodyTall = BODY_TALL, touch = TOUCH_ACTION,
             speed = SPEED, keys = KEYS, entry = ENTRY,
             most = MAX_BOMBS, anims = BOBOMB_ANIMS, waveFirst = WAVE_FIRST,
             paceMost = PACE_MOST, paceFull = PACE_FULL, ringStop = RING_STOP,
             edge = EDGE_SHARE, shapes = WAVE_SHAPES }
end

OF.gamemodes.register(mode)
