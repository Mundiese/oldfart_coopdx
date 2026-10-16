OF = OF or {}

local K = {}

K.ROLE_RACE = "racing"
K.ROLE_HOME = "home"
K.FINISH_RADIUS = 400

K.SEED_KEY = "ofRcSeed"
K.GRID_KEY = "ofRcGrid"
K.ORDER_KEY = "ofRcOrder"
K.ROW_KEY = "ofRcState"
K.PACKET_FIRE = "ofRcFire"
K.PACKET_HIT = "ofRcHit"
K.PACKET_ZAP = "ofRcZap"
K.PACKET_STEAL = "ofRcSteal"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

function K.ride() return OF.shellride or {} end

K.HIT_SPIN, K.HIT_TUMBLE, K.HIT_LAUNCH = 1, 2, 3

OF.gm_shellrace = OF.gm_shellrace or {}
local racer = OF.gm_shellrace
racer.HIT_SPIN, racer.HIT_TUMBLE, racer.HIT_LAUNCH = K.HIT_SPIN, K.HIT_TUMBLE, K.HIT_LAUNCH

K.PUSH_OFF = 30.0
K.LAKITU_DROP_SPEED = 24.0

K.TOP_SPEED = 64.0
K.BOOST_SPEED = 96.0
K.STAR_SPEED = 80.0
K.SHRUNK_SPEED = 40.0
K.SPEED_CEILING = 96.0

K.COIN_BONUS = 0.025
K.COIN_MOST = 10
K.COINS_PER_HIT = 2

local eff = {
    boost = 0,
    starred = 0,
    golden = 0,
    shrunk = 0,
    boo = 0,
    shield = 0,
    carried = 0,
    spin = 0,
}
racer.fx = eff

local coins = 0

K.CLASSES = { ["50"] = 1.0, ["100"] = 1.12, ["150"] = 1.25 }
racer.CLASSES = K.CLASSES

function racer.class_factor()
    local said = OF.util.asks(OF.gamemodes, "option_now")
        and OF.gamemodes.option_now("class") or nil
    return K.CLASSES[tostring(said or "50")] or 1.0
end

local function shape_speed(m)
    local v = m.forwardVel or 0
    local class = racer.class_factor()
    local top = K.TOP_SPEED * class * (1 + K.COIN_BONUS * math.min(coins, K.COIN_MOST))
    local star = math.min(K.SPEED_CEILING, K.STAR_SPEED * class)
    if eff.starred > 0 then top = math.max(top, star) end
    local pushing = (m.intendedMag or 0) >= 28
    if pushing and v >= K.TOP_SPEED - 1 and v < top then

        v = math.min(top, v + 1.5)
    end
    if eff.starred > 0 and pushing and v < star then

        v = math.min(star, v + 2)
    end
    if eff.boost > 0 then v = math.max(v, K.BOOST_SPEED) end
    if eff.shrunk > 0 then v = math.min(v, K.SHRUNK_SPEED) end
    if v > K.SPEED_CEILING then v = K.SPEED_CEILING end
    m.forwardVel = v
end
racer.shape_speed = shape_speed

K.DRIFT_MIN_SPEED = 40
K.DRIFT_TURN = 0x100
K.DRIFT_TIERS = { { at = 30, boost = 25 }, { at = 75, boost = 45 } }
local drift = { charge = 0, held = false, lastYaw = nil, tier = 0 }
racer.drift = drift
function racer.drift_frame(m)
    local pad = m.controller
    local z = pad ~= nil and ((pad.buttonDown or 0) & (Z_TRIG or 0x2000)) ~= 0
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    local turned = 0
    if drift.lastYaw ~= nil then
        turned = math.abs(((yaw - drift.lastYaw + 0x8000) % 0x10000) - 0x8000)
    end
    drift.lastYaw = yaw
    if z and (m.forwardVel or 0) >= K.DRIFT_MIN_SPEED then
        drift.held = true
        if turned >= K.DRIFT_TURN then drift.charge = drift.charge + 1 end
        local tier = 0
        for i, t in ipairs(K.DRIFT_TIERS) do
            if drift.charge >= t.at then tier = i end
        end
        if tier > drift.tier then
            drift.tier = tier
            OF.gamemodes.round_sound(tier == 1 and SOUND_GENERAL_SWISH_AIR or SOUND_GENERAL_SWISH_AIR_2)
        end
        if tier > 0 and drift.charge % (4 - tier) == 0 then
            OF.util.optional("set_mario_particle_flags", nil, m, PARTICLE_SPARKLES, false)
        end
        return 0
    end
    local given = 0
    if drift.held and drift.tier > 0 then
        given = K.DRIFT_TIERS[drift.tier].boost
        eff.boost = math.max(eff.boost, given)
        OF.gamemodes.round_sound(SOUND_ACTION_FLYING_FAST)
    end
    drift.held, drift.charge, drift.tier = false, 0, 0
    return given
end

function racer.shape_ride(m, air)
    if m == nil or m.playerIndex ~= 0 then return end
    if not air then
        racer.drift_frame(m)
        shape_speed(m)
    elseif eff.boost > 0 and (m.forwardVel or 0) < K.BOOST_SPEED then
        m.forwardVel = K.BOOST_SPEED
    end
end

bhvOfTrackMarker = at_load("hook_behavior", nil, OBJ_LIST_LEVEL, false, nil, nil,
    "bhvOfTrackMarker")
racer.MARKER = bhvOfTrackMarker

K.KIND = {
    START = 1, SLOT = 2, INFO = 3,
    GATE = 16, ALT = 17, RESPAWN = 18,
    BOX = 32, COIN = 33,
    BOOST = 64, OUT = 80, BATTLE = 96,
}
racer.KIND = K.KIND

K.GATE_NO_RESPAWN, K.GATE_OWN_YAW, K.GATE_TALL = 1, 2, 4
K.INFO_BATTLE, K.INFO_WATER_DEADLY, K.INFO_LAVA_DEADLY = 1, 2, 4

K.METRE = 100
K.GATES_FEWEST = 8
K.GATE_BELOW, K.GATE_ABOVE, K.GATE_ABOVE_TALL = 300, 1500, 4000

local function decode(params)
    local p = math.floor(tonumber(params) or 0) & 0xFFFFFFFF
    return (p >> 24) & 0xFF, (p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF
end
racer.decode = decode

local function has(flags, bit)
    return math.floor((flags or 0) / bit) % 2 == 1
end

local function read_markers()
    local list = {}
    if bhvOfTrackMarker == nil or obj_get_first_with_behavior_id == nil then
        return list
    end
    local o = obj_get_first_with_behavior_id(bhvOfTrackMarker)
    local guard = 0
    while o ~= nil and guard < 2000 do
        guard = guard + 1
        local kind, num, a, b = decode(o.oBehParams)
        table.insert(list, { kind = kind, num = num, a = a, b = b,
            x = o.oPosX or 0, y = o.oPosY or 0, z = o.oPosZ or 0,
            yaw = o.oFaceAngleYaw or 0 })
        o = obj_get_next_with_same_behavior_id(o)
    end
    return list
end
racer.read_markers = read_markers

local function flat_dir(dx, dz)
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1 then return 0, 1 end
    return dx / len, dz / len
end

local function yaw_of(nx, nz)
    return math.floor(atan2s(nz, nx) or 0)
end

K.GATE_FEEL_STEP = 100
K.GATE_FEEL_MOST = 4000
K.GATE_EDGE = 150
function racer.gate_edge(g, side)
    local sx, sz = g.nz * side, -g.nx * side
    local px, py, pz = g.x, g.y, g.z
    local reach = 0
    for d = K.GATE_FEEL_STEP, K.GATE_FEEL_MOST, K.GATE_FEEL_STEP do
        local x, z = g.x + sx * d, g.z + sz * d
        local y = K.road_floor(x, g.y, z)
        if y == nil or math.abs(y - g.y) > K.GATE_BELOW then break end
        if K.road_wall(px, py, pz, x, y, z) then break end
        px, py, pz = x, y, z
        reach = d
    end
    return reach
end

K.GATE_SHIFT_MOST = 300
K.GATE_WIDEN_MOST = 2.5
function racer.fit_gate(g)
    if g == nil or K.road_floor(g.x, g.y, g.z) == nil then return g end
    local right, left = racer.gate_edge(g, 1), racer.gate_edge(g, -1)
    local span = right + left + 2 * K.GATE_EDGE
    if span <= g.w then return g end
    local shift = (right - left) / 2
    shift = math.max(-K.GATE_SHIFT_MOST, math.min(K.GATE_SHIFT_MOST, shift))
    g.x, g.z = g.x + g.nz * shift, g.z - g.nx * shift
    g.w = math.min(span, g.w * K.GATE_WIDEN_MOST)
    return g
end

local function track_from_markers(list, fewest)
    fewest = tonumber(fewest) or K.GATES_FEWEST
    local starts, infos, gates, alts, respawns = {}, {}, {}, {}, {}
    local slots, boxes, coinsAt, boosts, outs, battle = {}, {}, {}, {}, {}, {}
    for _, mk in ipairs(list) do
        if mk.kind == K.KIND.START then table.insert(starts, mk)
        elseif mk.kind == K.KIND.INFO then table.insert(infos, mk)
        elseif mk.kind == K.KIND.GATE then table.insert(gates, mk)
        elseif mk.kind == K.KIND.ALT then table.insert(alts, mk)
        elseif mk.kind == K.KIND.RESPAWN then respawns[mk.num] = mk
        elseif mk.kind == K.KIND.SLOT then slots[mk.num] = mk
        elseif mk.kind == K.KIND.BOX then table.insert(boxes, mk)
        elseif mk.kind == K.KIND.COIN then table.insert(coinsAt, mk)
        elseif mk.kind == K.KIND.BOOST then table.insert(boosts, mk)
        elseif mk.kind == K.KIND.OUT then table.insert(outs, mk)
        elseif mk.kind == K.KIND.BATTLE then table.insert(battle, mk)
        end
    end

    if #infos ~= 1 then
        return nil, #infos == 0 and "This track has no INFO marker."
            or "This track has more than one INFO marker."
    end
    local info = infos[1]
    if has(info.b, K.INFO_BATTLE) then
        return nil, "This is a battle arena; Battle is not built yet."
    end
    if #starts ~= 1 then
        return nil, #starts == 0 and "This track has no START marker."
            or "This track has more than one START marker."
    end
    if #gates < fewest then
        return nil, OF.lang.fill("This track has @ gates; it needs @.",
            #gates, fewest)
    end

    local byNum = {}
    for _, g in ipairs(gates) do
        if byNum[g.num] ~= nil then
            return nil, OF.lang.fill("Gate @ is on this track twice.", g.num)
        end
        byNum[g.num] = g
    end
    for n = 0, #gates - 1 do
        if byNum[n] == nil then
            return nil, OF.lang.fill("Gate @ is missing from this track.", n)
        end
    end

    local count = #gates
    local track = {
        kind = "lap",
        gates = {},
        laps = info.num > 0 and info.num or 3,
        par = info.a > 0 and info.a or 45,
        waterDeadly = has(info.b, K.INFO_WATER_DEADLY),
        lavaDeadly = has(info.b, K.INFO_LAVA_DEADLY),
        boxes = {}, coins = {}, boosts = {}, outs = {}, slots = {},
    }
    for n = 0, count - 1 do
        local g = byNum[n]
        local before = byNum[(n - 1) % count]
        local after = byNum[(n + 1) % count]

        local nx, nz = flat_dir(after.x - before.x, after.z - before.z)
        if has(g.b, K.GATE_OWN_YAW) or (g.yaw or 0) % 0x10000 ~= 0 then
            local ox = math.sin(g.yaw * math.pi / 0x8000)
            local oz = math.cos(g.yaw * math.pi / 0x8000)
            if ox * nx + oz * nz < 0 and not has(g.b, K.GATE_OWN_YAW) then ox, oz = -ox, -oz end
            nx, nz = ox, oz
        end
        local back = respawns[n]
        table.insert(track.gates, {
            num = n, x = g.x, y = g.y, z = g.z,
            w = (g.a > 0 and g.a or 16) * K.METRE,
            nx = nx, nz = nz,
            above = has(g.b, K.GATE_TALL) and K.GATE_ABOVE_TALL or K.GATE_ABOVE,
            noRespawn = has(g.b, K.GATE_NO_RESPAWN),
            respawn = back ~= nil and { x = back.x, y = back.y, z = back.z } or nil,
            alts = {},
        })
    end
    for _, a in ipairs(alts) do
        local main = track.gates[a.num + 1]
        if main ~= nil then
            table.insert(main.alts, { x = a.x, y = a.y, z = a.z,
                w = (a.a > 0 and a.a or 16) * K.METRE, nx = main.nx, nz = main.nz,
                above = has(a.b, K.GATE_TALL) and K.GATE_ABOVE_TALL or K.GATE_ABOVE })
        end
    end

    for _, g in ipairs(track.gates) do
        racer.fit_gate(g)
        for _, alt in ipairs(g.alts) do racer.fit_gate(alt) end
    end

    local s = starts[1]
    local g0 = track.gates[1]
    track.start = { x = s.x, y = s.y, z = s.z, nx = g0.nx, nz = g0.nz,
        width = (s.a > 0 and s.a or 12) * K.METRE,
        row = (s.b > 0 and s.b or 4) * K.METRE }
    for n = 1, 16 do
        if slots[n] ~= nil then
            track.slots[n] = { x = slots[n].x, y = slots[n].y, z = slots[n].z }
        end
    end
    for _, b in ipairs(boxes) do
        table.insert(track.boxes, { x = b.x, y = b.y, z = b.z, extra = has(b.b, 1) })
    end
    for _, c in ipairs(coinsAt) do
        table.insert(track.coins, { x = c.x, y = c.y, z = c.z })
    end
    for _, b in ipairs(boosts) do

        local nx, nz, best = 0, 1, math.huge
        for _, g in ipairs(track.gates) do
            local d = (g.x - b.x) ^ 2 + (g.z - b.z) ^ 2
            if d < best then best, nx, nz = d, g.nx, g.nz end
        end
        table.insert(track.boosts, { x = b.x, y = b.y, z = b.z,
            r = math.max(b.a, b.b, 2) * K.METRE * 0.5, nx = nx, nz = nz })
    end
    for _, o in ipairs(outs) do
        table.insert(track.outs, { x = o.x, y = o.y, z = o.z,
            r = math.max(o.a, 1) * K.METRE, h = math.max(o.b, 1) * K.METRE })
    end
    return track, nil
end
racer.track_from_markers = track_from_markers

K.LINE_BOX_ROWS = { 0.3, 0.6, 0.85 }
K.LINE_COIN_LINES = { 0.15, 0.45, 0.72 }
K.LINE_BOX_GAP = 300
K.LINE_COIN_GAP = 200
K.LINE_FLOOR_REACH = 1500

K.LINE_BOOSTS = { 0.22, 0.52, 0.78 }
K.LINE_BOOST_R = 300

local function floor_near(x, y, z)
    if find_floor_height == nil then return y end
    local h = find_floor_height(x, y + 400, z)
    if h == nil or h < -10000 then return nil end
    if math.abs(h - y) > K.LINE_FLOOR_REACH then return nil end
    return h
end

local function track_from_line(from, to)
    if from == nil or to == nil then return nil, "This level has no flagpole in it." end
    local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1 then return nil, "This level has no flagpole in it." end
    local nx, nz = flat_dir(dx, dz)
    local track = {
        kind = "line", laps = 1, gates = {}, length = length,
        par = math.max(30, math.floor(length / 400)),
        goal = { x = to.x, y = to.y, z = to.z },
        from = { x = from.x, y = from.y, z = from.z },
        start = { x = from.x, y = from.y, z = from.z, nx = nx, nz = nz,
                  width = 12 * K.METRE, row = 4 * K.METRE },
        boxes = {}, coins = {}, boosts = {}, outs = {}, slots = {},
    }

    for _, share in ipairs(K.LINE_BOX_ROWS) do
        for k = -2.5, 2.5, 1 do
            local x = from.x + dx * share + nz * k * K.LINE_BOX_GAP
            local z = from.z + dz * share - nx * k * K.LINE_BOX_GAP
            local y = floor_near(x, from.y + dy * share, z)
            if y ~= nil then
                table.insert(track.boxes, { x = x, y = y + 100, z = z,
                    extra = math.abs(k) > 1.5 })
            end
        end
    end
    for _, share in ipairs(K.LINE_COIN_LINES) do
        for k = 0, 5 do
            local along = share + k * K.LINE_COIN_GAP / length
            local x = from.x + dx * along
            local z = from.z + dz * along
            local y = floor_near(x, from.y + dy * along, z)
            if y ~= nil then table.insert(track.coins, { x = x, y = y + 50, z = z }) end
        end
    end
    for _, share in ipairs(K.LINE_BOOSTS) do
        local x, z = from.x + dx * share, from.z + dz * share
        local y = floor_near(x, from.y + dy * share, z)
        if y ~= nil then
            table.insert(track.boosts, { x = x, y = y, z = z, r = K.LINE_BOOST_R, nx = nx, nz = nz })
        end
    end
    return track, nil
end
racer.track_from_line = track_from_line

K.SLIDE_ROOMS = {
    { level = "LEVEL_PSS", area = 1 },
    { level = "LEVEL_CCM", area = 2 },
    { level = "LEVEL_TTM", area = 2 },
    { level = "LEVEL_TTM", area = 3 },
    { level = "LEVEL_TTM", area = 4 },
}
racer.SLIDE_ROOMS = K.SLIDE_ROOMS

K.GATE_ROADS = {
    { level = "LEVEL_PSS", area = 1, points = {
        { -6381, -4587, 4726 }, { -6381, -4587, 4126 }, { -6381, -4507, 3226 },
        { -6381, -4422, 2326 }, { -6381, -4337, 1426 }, { -6381, -4252, 526 },
        { -6381, -4167, -374 }, { -6381, -4082, -1274 }, { -6081, -3984, -2174 },
        { -5781, -3867, -3074 }, { -4881, -3665, -3974 }, { -3981, -3549, -3974 },
        { -3081, -3412, -3974 }, { -2181, -3191, -3974 }, { -1281, -2951, -4574 },
        { -381, -2741, -5474 }, { 519, -2392, -5774 }, { 1419, -2259, -5174 },
        { 1719, -2130, -4274 }, { 1719, -2016, -3374 }, { 1719, -1911, -2474 },
        { 1719, -1822, -1574 }, { 2019, -1483, -674 }, { 2019, -1476, 226 },
        { 2019, -1227, 1126 }, { 2019, -1200, 2026 }, { 2019, -971, 2926 },
        { 2019, -961, 3826 }, { 2019, -906, 4726 }, { 2319, -772, 5626 },
        { 3219, -613, 6226 }, { 4119, -484, 6226 }, { 5019, -315, 5626 },
        { 5619, -155, 4726 }, { 5319, -38, 3826 }, { 4719, 133, 2926 },
        { 3819, 283, 2626 }, { 2919, 506, 2626 }, { 2019, 949, 2326 },
        { 1119, 1522, 1726 }, { 219, 2070, 1726 }, { -681, 2618, 1726 },
        { -1581, 2784, 1726 }, { -2481, 2809, 1726 }, { -3381, 2922, 1726 },
        { -4281, 3070, 1726 }, { -5181, 3257, 1426 }, { -5781, 3484, 526 },
        { -5781, 3627, -374 }, { -5781, 3750, -1274 }, { -5781, 3873, -2174 },
        { -5781, 3997, -3074 }, { -5781, 4136, -3974 }, { -5181, 4327, -4874 },
        { -4281, 4486, -5174 }, { -3381, 4650, -5174 }, { -2481, 4860, -5474 },
        { -1581, 5067, -5474 }, { -681, 5275, -5474 }, { 219, 5484, -5474 },
        { 1119, 5692, -5474 }, { 2019, 5901, -5474 }, { 2919, 6109, -5474 },
        { 3819, 6144, -5474 }, { 4629, 6144, -5637 },
    } },
}
racer.GATE_ROADS = K.GATE_ROADS

function K.room_is(entry, level, area)
    return entry ~= nil and _G[entry.level] ~= nil and _G[entry.level] == level
        and (entry.area or 1) == (area or 1)
end

function racer.is_slide(level, area)
    for _, entry in ipairs(K.SLIDE_ROOMS) do
        if K.room_is(entry, level, area) then return true end
    end
    return false
end

function K.landed(x, y, z)
    local spot = { x = x, y = y, z = z }
    if OF.util.asks(OF.warp, "land_spot") then
        spot = OF.warp.land_spot(spot)
    end
    return spot
end

function racer.route_between(level, area, from, to, list)
    if from == nil or to == nil or list == nil then return nil end
    local found = nil
    for _, entry in ipairs(list) do
        if K.room_is(entry, level, area) then found = entry end
    end
    if found == nil then return nil end
    local pts = {}
    for _, p in ipairs(found.points) do table.insert(pts, K.landed(p[1], p[2], p[3])) end
    if #pts < 2 then return nil end
    local function gap(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    if gap(pts[1], from) + gap(pts[#pts], to) > gap(pts[#pts], from) + gap(pts[1], to) then
        local turned = {}
        for i = #pts, 1, -1 do table.insert(turned, pts[i]) end
        pts = turned
    end
    table.insert(pts, 1, { x = from.x, y = from.y, z = from.z })
    table.insert(pts, { x = to.x, y = to.y, z = to.z })
    local s = 0
    pts[1].s = 0
    for i = 2, #pts do
        s = s + gap(pts[i - 1], pts[i])
        pts[i].s = s
    end
    return { points = pts, length = s }
end

K.ROAD_CELL = 300
K.ROAD_HOP = 380
K.ROAD_DROP = 2500
K.ROAD_BUDGET = 120
K.ROAD_MOST = 24000
K.ROAD_EVERY = 3

function K.road_floor(x, y, z)
    if find_floor_height == nil then return nil end
    local h = find_floor_height(x, y + K.ROAD_HOP, z)
    if type(h) ~= "number" or h < -10000 then return nil end
    if y - h > K.ROAD_DROP then return nil end
    return h
end

function K.road_wall(ax, ay, az, bx, by, bz)
    if collision_find_surface_on_ray == nil then return false end
    local y = math.max(ay, by) + 60
    local info = collision_find_surface_on_ray(ax, y, az, bx - ax, 0, bz - az)
    local surf = info ~= nil and info.surface or nil
    if surf == nil or surf.normal == nil then return false end
    return math.abs(surf.normal.y or 0) < 0.3
end

function racer.walk_road(from, to, yield)
    local S = K.ROAD_CELL
    local function key(i, j, y) return i .. ":" .. j .. ":" .. math.floor(y / 400) end
    local function guess(x, y, z)
        local dx, dy, dz = to.x - x, to.y - y, to.z - z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    local startY = K.road_floor(from.x, from.y + 50, from.z) or from.y

    local open = {}
    local function push(c)
        open[#open + 1] = c
        local n = #open
        while n > 1 do
            local up = n // 2
            if open[up].f <= open[n].f then break end
            open[up], open[n] = open[n], open[up]
            n = up
        end
    end
    local function pop()
        local top = open[1]
        local last = table.remove(open)
        if #open > 0 then
            open[1] = last
            local n = 1
            while true do
                local l, r, m = n * 2, n * 2 + 1, n
                if l <= #open and open[l].f < open[m].f then m = l end
                if r <= #open and open[r].f < open[m].f then m = r end
                if m == n then break end
                open[m], open[n] = open[n], open[m]
                n = m
            end
        end
        return top
    end
    push({ i = 0, j = 0, y = startY, g = 0, f = guess(from.x, startY, from.z) })
    local cameFrom, best = {}, {}
    best[key(0, 0, startY)] = 0
    local seen, spent = 0, 0
    local reached = nil
    while #open > 0 do
        local cur = pop()

        while cur ~= nil and cur.g > (best[key(cur.i, cur.j, cur.y)] or math.huge) do
            cur = pop()
        end
        if cur == nil then break end
        local cx, cz = from.x + cur.i * S, from.z + cur.j * S
        if math.abs(cx - to.x) <= S and math.abs(cz - to.z) <= S
            and math.abs(cur.y - to.y) <= 600 then
            reached = cur
            break
        end
        seen = seen + 1
        if seen > K.ROAD_MOST then return nil end
        spent = spent + 1
        if yield ~= nil and spent >= K.ROAD_BUDGET then
            spent = 0
            yield()
        end
        for di = -1, 1 do
            for dj = -1, 1 do
                if di ~= 0 or dj ~= 0 then
                    local ni, nj = cur.i + di, cur.j + dj
                    local nx, nz = from.x + ni * S, from.z + nj * S
                    local h = K.road_floor(nx, cur.y, nz)
                    if h ~= nil and not K.road_wall(cx, cur.y, cz, nx, h, nz) then
                        local step = math.sqrt((di * S) ^ 2 + (dj * S) ^ 2 + (h - cur.y) ^ 2)
                        local g = cur.g + step
                        local k = key(ni, nj, h)
                        if best[k] == nil or g < best[k] then
                            best[k] = g
                            cameFrom[k] = cur
                            push({ i = ni, j = nj, y = h, g = g,
                                f = g + guess(nx, h, nz) })
                        end
                    end
                end
            end
        end
    end
    if reached == nil then return nil end

    local cells = {}
    local node = reached
    while node ~= nil do
        table.insert(cells, 1, node)
        node = cameFrom[key(node.i, node.j, node.y)]
    end
    local pts = { { x = from.x, y = from.y, z = from.z } }
    for n = 2, #cells - 1 do
        if n % K.ROAD_EVERY == 0 then
            local c = cells[n]
            table.insert(pts, { x = from.x + c.i * S, y = c.y, z = from.z + c.j * S })
        end
    end
    table.insert(pts, { x = to.x, y = to.y, z = to.z })
    local s = 0
    pts[1].s = 0
    for n = 2, #pts do
        local a, b = pts[n - 1], pts[n]
        s = s + math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
        pts[n].s = s
    end
    return { points = pts, length = s, walked = true }
end

function racer.walk_step(t)
    if t == nil or t.walk == nil then return false end
    local ok, done = coroutine.resume(t.walk)
    if not ok or coroutine.status(t.walk) == "dead" then
        t.walk = nil
        if ok and type(done) == "table" then
            t.route = done
            K.routeSeen = {}
        end
        return true
    end
    return false
end

K.ROUTE_BACK, K.ROUTE_AHEAD = 1500, 3000

K.ROUTE_JUMP = 900

K.ROUTE_UP = 2.0

function racer.along_route(route, x, y, z, hint)
    if route == nil or route.points == nil then return 0, math.huge end
    local pts = route.points
    local bestS, bestD = 0, math.huge
    local nearS, nearD = nil, math.huge
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local ax, ay, az = b.x - a.x, b.y - a.y, b.z - a.z
        local len2 = ax * ax + ay * ay + az * az
        local t = 0
        if len2 > 0 then
            t = ((x - a.x) * ax + (y - a.y) * ay + (z - a.z) * az) / len2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
        end
        local px, py, pz = a.x + ax * t, a.y + ay * t, a.z + az * t
        local dx, dy, dz = x - px, (y - py) * K.ROUTE_UP, z - pz
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        local s = a.s + (b.s - a.s) * t
        if d < bestD then bestS, bestD = s, d end
        if hint ~= nil and s >= hint - K.ROUTE_BACK and s <= hint + K.ROUTE_AHEAD
            and d < nearD then
            nearS, nearD = s, d
        end
    end
    if nearS ~= nil and nearD <= bestD + K.ROUTE_JUMP then return nearS, nearD end
    return bestS, bestD
end

K.routeSeen = {}

function racer.line_progress(t, x, y, z, who)
    if t.route ~= nil then
        local s = racer.along_route(t.route, x, y, z,
            who ~= nil and K.routeSeen[who] or nil)
        if who ~= nil then K.routeSeen[who] = s end
        if t.route.length <= 0 then return 0 end
        return math.max(0, math.min(1, s / t.route.length))
    end
    if t.slide and t.from ~= nil and math.abs(t.goal.y - t.from.y) > 1 then
        return math.max(0, math.min(1, (y - t.from.y) / (t.goal.y - t.from.y)))
    end
    local dx, dy, dz = t.goal.x - x, t.goal.y - y, t.goal.z - z
    local away = math.sqrt(dx * dx + dy * dy + dz * dz)
    return math.max(0, 1 - away / t.length)
end

K.TRACK_KINDS = { lap = true, line = true, ring = false }
racer.TRACK_KINDS = K.TRACK_KINDS

local track = nil
local trackRoom = nil
local trackWhy = nil

local function room_key(level, area)
    return tostring(level) .. ":" .. tostring(area)
end

function racer.track_from_forge(ft)
    if ft == nil or ft.start == nil then return nil, "This level has no Forge track." end

    local laid = #(ft.gates or {})
    local fewest = (tonumber(ft.fewest) or K.GATES_FEWEST) - 1
    if laid < fewest then
        return nil, OF.lang.fill("This Forge track has @ gates; it needs @.", laid, fewest)
    end
    local t, why = track_from_markers(ft.markers or {}, ft.fewest)
    if t == nil then return nil, why end
    t.forge = true
    return t, nil
end

function K.forge_track(level, area)
    if OF.forge == nil or type(OF.forge.racer_track) ~= "function" then return nil end
    return OF.forge.racer_track(level, area)
end

local function build_track(level, area)
    local ft = K.forge_track(level, area)
    if ft ~= nil then return racer.track_from_forge(ft) end
    local list = read_markers()
    if #list > 0 then
        local t, why = track_from_markers(list)
        if t ~= nil then t.studio = true end
        return t, why
    end
    local here = { level = level, area = area }
    local from = OF.gamemodes.surveyed(here, "floodStart")
    local to = OF.gamemodes.surveyed(here, "floodGoal")
    local t, why = track_from_line(from, to)
    if t ~= nil then

        t.slide = racer.is_slide(level, area)

        t.level, t.area = level, area
        t.gateRoad = racer.route_between(level, area, from, to, K.GATE_ROADS)
        if t.route == nil and not t.slide and coroutine ~= nil then
            t.walk = coroutine.create(function()
                return racer.walk_road(t.from, t.goal, coroutine.yield)
            end)
        end
    end
    return t, why
end
racer.build_track = build_track

local function current_track()
    local at = OF.gamemodes.round_place()
    if at == nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum ~= at.level or np.currAreaIndex ~= at.area then
        return nil
    end
    local key = room_key(at.level, at.area)
    if trackRoom ~= key then
        track, trackWhy = build_track(at.level, at.area)
        trackRoom = key
    end
    return track, trackWhy
end
racer.current_track = current_track

local function forget_track()
    track, trackRoom, trackWhy = nil, nil, nil
    K.routeSeen = {}
end
racer.forget_track = forget_track

local function laps_of(t)
    if t == nil or t.kind ~= "lap" then return 1 end
    local said = tonumber(OF.gamemodes.option_now("laps") or "")
    if said ~= nil and said > 0 then return math.floor(said) end
    return t.laps or 3
end
racer.laps_of = laps_of

K.GATE_BAND = 600
local function crossed(g, px, py, pz, x, y, z, forwards)
    local before = (px - g.x) * g.nx + (pz - g.z) * g.nz
    local after = (x - g.x) * g.nx + (z - g.z) * g.nz
    if math.abs(before) > K.GATE_BAND or math.abs(after) > K.GATE_BAND then return false end
    if forwards then
        if not (before < 0 and after >= 0) then return false end
    else
        if not (before >= 0 and after < 0) then return false end
    end

    local share = 0
    if before ~= after then share = before / (before - after) end
    local cx = px + (x - px) * share
    local cy = py + (y - py) * share
    local cz = pz + (z - pz) * share
    local side = (cx - g.x) * g.nz - (cz - g.z) * g.nx
    if math.abs(side) > g.w * 0.5 then return false end
    local up = cy - g.y
    return up >= -K.GATE_BELOW and up <= g.above
end
racer.crossed = crossed

local function crossed_any(g, px, py, pz, x, y, z, forwards)
    if crossed(g, px, py, pz, x, y, z, forwards) then return true end
    for _, alt in ipairs(g.alts or {}) do
        if crossed(alt, px, py, pz, x, y, z, forwards) then return true end
    end
    return false
end

local function lap_of(done, count)
    if done <= 0 then return 0 end
    return math.floor((done - 1) / count) + 1
end
racer.lap_of = lap_of

local function fraction(t, done, x, z)
    local count = #t.gates
    local nextG = t.gates[(done % count) + 1]
    if done <= 0 then
        local into = (x - nextG.x) * nextG.nx + (z - nextG.z) * nextG.nz
        return math.max(0, math.min(0.999, 1 + into / 1500))
    end
    local last = t.gates[((done - 1) % count) + 1]
    local past = (x - last.x) * last.nx + (z - last.z) * last.nz
    local ahead = (nextG.x - x) * nextG.nx + (nextG.z - z) * nextG.nz
    if past < 0 then past = 0 end
    if ahead < 0 then ahead = 0 end
    if past + ahead <= 0 then return 0 end
    return math.min(0.999, past / (past + ahead))
end

local function progress_of(t, done, x, y, z, who)
    if t == nil then return 0 end
    if t.kind == "line" then return racer.line_progress(t, x, y, z, who) end
    return done + fraction(t, done, x, z)
end
racer.progress_of = progress_of

K.LINE_GATE_EVERY = 3000
K.LINE_GATE_WIDTH = 16 * K.METRE

K.LINE_GATE_END = 800

K.LINE_MISS_PAST = 1500
K.LINE_SAY_EVERY = 90

K.LINE_FACE_SPAN = 300

K.LINE_GATE_CAL = {

    { level = "LEVEL_PSS", area = 1, every = 3000, width = 1600 },
}
racer.LINE_GATE_CAL = K.LINE_GATE_CAL

K.line = { next = 1, saidAt = -999, missed = false, seen = nil, said = 0 }

function racer.line_gate_cal(level, area)
    for _, c in ipairs(K.LINE_GATE_CAL) do
        if K.room_is(c, level, area) then
            return c.every or K.LINE_GATE_EVERY, c.width or K.LINE_GATE_WIDTH, c.fair
        end
    end
    return K.LINE_GATE_EVERY, K.LINE_GATE_WIDTH, nil
end

function racer.road_at(route, s)
    local pts = route.points
    local function at(d)
        d = math.max(0, math.min(route.length, d))
        for i = 2, #pts do
            local a, b = pts[i - 1], pts[i]
            if d <= b.s or i == #pts then
                local len = b.s - a.s
                local k = len > 0 and (d - a.s) / len or 0
                k = math.max(0, math.min(1, k))
                return a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k
            end
        end
        return pts[1].x, pts[1].y, pts[1].z
    end
    local x, y, z = at(s)
    local bx, _, bz = at(s - K.LINE_FACE_SPAN)
    local ax, _, az = at(s + K.LINE_FACE_SPAN)
    local nx, nz = flat_dir(ax - bx, az - bz)
    return x, y, z, nx, nz
end

local function line_gate(x, y, z, nx, nz, width, s)
    return { x = x, y = y, z = z, nx = nx, nz = nz, w = width, s = s,
        above = K.GATE_ABOVE, alts = {} }
end

function racer.line_gates(route, every, width, fit, fair)
    local gates = {}
    if route == nil or route.points == nil or #route.points < 2 then return gates end
    local inner = route.length - 2 * K.LINE_GATE_END
    every = every or K.LINE_GATE_EVERY
    if inner <= 0 or every <= 0 then return gates end
    local n = math.max(1, math.floor(inner / every + 0.5))
    local step = inner / n
    for k = 1, n do
        local s = K.LINE_GATE_END + (k - 0.5) * step
        if fair == nil or s < fair.from or s > fair.to then
            local x, y, z, nx, nz = racer.road_at(route, s)
            local g = line_gate(x, y, z, nx, nz, width or K.LINE_GATE_WIDTH, s)
            if fit ~= false then racer.fit_gate(g) end
            table.insert(gates, g)
        end
    end
    return gates
end

function racer.gate_road(t)
    if t == nil then return nil end
    if t.gateRoad ~= nil then return t.gateRoad end
    if t.route ~= nil and not t.route.walked then return t.route end
    return nil
end

function racer.line_gates_of(t)
    if t == nil or t.kind ~= "line" then return nil end
    if t.lineGates ~= nil then return t.lineGates end
    local road = racer.gate_road(t)
    if road == nil then return nil end
    local every, width, fair = racer.line_gate_cal(t.level, t.area)
    t.lineGates = racer.line_gates(road, every, width, nil, fair)
    return t.lineGates
end

function racer.line_clear(t)
    local gates = t ~= nil and t.lineGates or nil
    return gates == nil or K.line.next > #gates
end

function racer.line_forget()
    K.line.next, K.line.saidAt, K.line.missed, K.line.seen, K.line.said = 1, -999, false, nil, 0
end

function racer.say_missed(now)
    K.line.missed = true
    if now - K.line.saidAt < K.LINE_SAY_EVERY then return false end
    K.line.saidAt = now
    K.line.said = K.line.said + 1

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", OF.lang.t("MISSED GATE"), nil, { tone = "bad" })
    end
    return true
end

function racer.line_step(t, px, py, pz, x, y, z, now)
    local gates = t.lineGates
    if gates == nil or K.line.next > #gates then return true end
    local g = gates[K.line.next]
    if crossed_any(g, px, py, pz, x, y, z, true) then
        K.line.next = K.line.next + 1
        K.line.missed = false
        return K.line.next > #gates
    end
    local road = racer.gate_road(t)
    if road ~= nil and now % 15 == 0 then
        local s = racer.along_route(road, x, y, z, K.line.seen)
        K.line.seen = s
        if s > g.s + K.LINE_MISS_PAST then racer.say_missed(now) end
    end
    return false
end

local function parse_row(text)
    local out = { done = 0, coins = 0, item = "", fx = "", rolls = 0 }
    if type(text) ~= "string" then return out end
    local parts = {}
    for piece in (text .. "|"):gmatch("([^|]*)|") do table.insert(parts, piece) end
    out.done = tonumber(parts[1]) or 0
    out.coins = tonumber(parts[2]) or 0
    out.item = parts[3] or ""
    out.fx = parts[4] or ""
    out.rolls = tonumber(parts[5]) or 0
    return out
end
racer.parse_row = parse_row

local function row_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return parse_row(row ~= nil and row[K.ROW_KEY] or nil)
end
racer.row_of = row_of

local mine = { done = 0, item = "", count = 0, rolls = 0 }
local written = nil

local function fx_letters()
    local s = ""
    if eff.starred > 0 then s = s .. "s" end
    if eff.boo > 0 then s = s .. "b" end
    if eff.shield > 0 then s = s .. "h" end
    if eff.shrunk > 0 then s = s .. "k" end
    if eff.carried > 0 then s = s .. "l" end
    return s
end

local function write_row()
    local item = mine.item
    if item ~= "" and mine.count > 1 then item = item .. "*" .. mine.count end
    local text = table.concat({ tostring(mine.done), tostring(coins), item,
        fx_letters(), tostring(mine.rolls) }, "|")
    if text == written then return false end
    written = text
    OF.util.publish_row(0, "ofRcState", text)
    return true
end
racer.write_row = write_row

local function forget_mine()
    mine = { done = 0, item = "", count = 0, rolls = 0 }
    written = nil
    coins = 0
    for k in pairs(eff) do eff[k] = 0 end
end
racer.forget_mine = forget_mine

function racer.mine() return mine end
function racer.coins() return coins end
function racer.set_coins(n) coins = n end

K.DIGITS = "0123456789abcdefghijklmnopqrstuv"
local function encode_list(globals)
    local s = {}
    for _, g in ipairs(globals) do
        local d = (g % 32) + 1
        table.insert(s, K.DIGITS:sub(d, d))
    end
    return table.concat(s)
end

local function decode_list(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for i = 1, #text do
        local at = K.DIGITS:find(text:sub(i, i), 1, true)
        if at ~= nil then table.insert(out, at - 1) end
    end
    return out
end
racer.encode_list, racer.decode_list = encode_list, decode_list

local function global_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    return np ~= nil and np.globalIndex or nil
end

local function local_of(globalIndex)
    if network_local_index_from_global == nil then return nil end
    local li = network_local_index_from_global(globalIndex)
    if li == nil or li < 0 or li >= MAX_PLAYERS then return nil end
    return li
end

local function riders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_RACE)) do table.insert(list, entry) end
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_HOME)) do table.insert(list, entry) end
    return list
end
racer.riders = riders

local function finish_time(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local t = row ~= nil and row.ofGmTime or nil
    if type(t) == "number" and t > 0 then return t end
    return nil
end

local function standings()
    local t = current_track()
    local at = OF.gamemodes.round_place()
    local list = {}
    for _, entry in ipairs(riders()) do
        local li = entry.localIndex
        local m = gMarioStates[li]
        local row = row_of(li)
        local done = row.done
        if li == 0 then done = mine.done end

        local p = 0
        local np = gNetworkPlayers[li]
        local inRoom = at ~= nil and np ~= nil and np.currLevelNum == at.level
            and np.currAreaIndex == at.area
        if inRoom and m ~= nil and m.pos ~= nil then
            p = progress_of(t, done, m.pos.x, m.pos.y, m.pos.z, li)
        end
        table.insert(list, {
            localIndex = li,
            name = entry.np ~= nil and entry.np.name or "",
            time = finish_time(li),
            progress = p,
            done = done,
        })
    end
    table.sort(list, function(a, b)
        if (a.time ~= nil) ~= (b.time ~= nil) then return a.time ~= nil end
        if a.time ~= nil and a.time ~= b.time then return a.time < b.time end
        if a.time == nil and a.progress ~= b.progress then return a.progress > b.progress end
        return a.name < b.name
    end)
    return list
end
racer.standings = standings

local function published_order()
    local out = {}
    for _, g in ipairs(decode_list(gGlobalSyncTable[K.ORDER_KEY])) do
        local li = local_of(g)
        if li ~= nil then table.insert(out, li) end
    end
    return out
end
racer.published_order = published_order

local function agreed_place(localIndex)
    local order = published_order()
    for place, li in ipairs(order) do
        if li == localIndex then return place, #order end
    end
    return #order + 1, math.max(1, #order + 1)
end
racer.agreed_place = agreed_place

local lastResult = nil

local function slot_spot(t, slot)
    if t.slots ~= nil and t.slots[slot] ~= nil then
        local s = t.slots[slot]
        return s.x, s.y, s.z
    end
    local s = t.start
    local col = (slot - 1) % 4
    local row = math.floor((slot - 1) / 4)
    local across = (col - 1.5) * (s.width / 4)
    local back = row * s.row + col * s.row * 0.25
    local x = s.x - s.nx * back + s.nz * across
    local z = s.z - s.nz * back - s.nx * across
    local y = floor_near(x, s.y, z) or s.y
    return x, y, z
end
racer.slot_spot = slot_spot

local function my_slot()
    local me = global_of(0)
    for slot, g in ipairs(decode_list(gGlobalSyncTable[K.GRID_KEY])) do
        if g == me then return slot end
    end
    return nil
end
racer.my_slot = my_slot

K.ITEMS = {
    goomba   = { name = "Goomba",          model = "E_MODEL_GOOMBA" },
    koopa    = { name = "Koopa Shell",     model = "E_MODEL_KOOPA_SHELL" },
    three    = { name = "Three Koopa Shells", model = "E_MODEL_KOOPA_SHELL", count = 3 },
    bullet   = { name = "Bullet Bill",     model = "E_MODEL_BULLET_BILL" },
    spiny    = { name = "Spiny",           model = "E_MODEL_SPINY" },
    mushroom = { name = "Mushroom",        model = "E_MODEL_1UP" },
    golden   = { name = "Golden Mushroom", model = "E_MODEL_1UP" },
    star     = { name = "Power Star",      model = "E_MODEL_STAR" },
    boo      = { name = "Boo",             model = "E_MODEL_BOO" },
    lightning = { name = "Lightning",      model = nil },
    fakebox  = { name = "Fake ! Box",      model = "E_MODEL_EXCLAMATION_BOX" },
    bobomb   = { name = "Bob-omb",         model = "E_MODEL_BLACK_BOBOMB" },
    shield   = { name = "Shield",          model = nil },

    triple   = { name = "Triple Mushroom", model = "E_MODEL_1UP", count = 3 },
    feather  = { name = "Wing Feather",    model = nil },
    coinbag  = { name = "Coin Purse",      model = "E_MODEL_YELLOW_COIN" },
}
racer.ITEMS = K.ITEMS

K.BANDS = {
    { goomba = 25, koopa = 25, fakebox = 15, three = 10, bobomb = 10, shield = 10, coinbag = 5 },
    { goomba = 15, koopa = 20, three = 15, bullet = 15, fakebox = 10, bobomb = 10, boo = 5, mushroom = 5,
      coinbag = 5 },
    { goomba = 5, koopa = 15, three = 15, bullet = 20, bobomb = 10, boo = 10, mushroom = 10, shield = 5,
      feather = 5, coinbag = 5 },
    { koopa = 10, three = 10, bullet = 25, mushroom = 20, boo = 10, bobomb = 5, golden = 5, star = 5,
      triple = 5, feather = 5 },
    { koopa = 5, three = 10, bullet = 20, mushroom = 20, golden = 10, star = 10, boo = 5, lightning = 5,
      triple = 10, feather = 5 },
    { three = 5, bullet = 20, mushroom = 15, golden = 15, star = 15, spiny = 5, lightning = 10, triple = 15 },
    { bullet = 20, mushroom = 15, golden = 20, star = 20, spiny = 10, lightning = 10, triple = 5 },
    { bullet = 15, mushroom = 10, golden = 25, star = 25, spiny = 10, lightning = 10, triple = 5 },
}
racer.BANDS = K.BANDS

K.ITEM_ORDER = { "goomba", "koopa", "three", "fakebox", "bobomb", "shield",
    "bullet", "boo", "mushroom", "golden", "star", "lightning", "spiny",
    "coinbag", "feather", "triple" }
racer.ITEM_ORDER = K.ITEM_ORDER

local function band_of(place, racers)
    racers = math.max(1, racers or 1)
    place = math.max(1, math.min(place or 1, racers))
    return math.floor((place - 1) * 8 / racers) + 1
end
racer.band_of = band_of

local function mix(a, b, c)
    local h = ((a or 0) % 1000003) * 7919 + ((b or 0) % 1009) * 104729 + ((c or 0) % 4099) * 31
    h = (h * 1103515245 + 12345) % 2147483648
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

local function roll(seed, globalIndex, rolls, place, racers, frantic, spinyOut)
    local band = band_of(place, racers)
    if frantic then band = math.min(8, band + 2) end
    local weights = {}
    for k, v in pairs(K.BANDS[band]) do weights[k] = v end
    if (racers or 0) > 8 and (weights.bullet or 0) > 0 then
        local moved = math.floor(weights.bullet / 2)
        weights.bullet = weights.bullet - moved
        weights.koopa = (weights.koopa or 0) + moved
    end
    if spinyOut and (weights.spiny or 0) > 0 then
        weights.bullet = (weights.bullet or 0) + weights.spiny
        weights.spiny = 0
    end
    local pick = mix(seed, (globalIndex or 0) + 1, rolls) % 100
    for _, key in ipairs(K.ITEM_ORDER) do
        local w = weights[key] or 0
        if pick < w then return key end
        pick = pick - w
    end
    return "koopa"
end
racer.roll = roll

local frame = 0
local boxBack = {}
local coinBack = {}
K.BOX_RESPAWN = 60
K.COIN_RESPAWN = 240
K.TOUCH_BOX = 160
K.TOUCH_COIN = 130
K.ROULETTE = 30
local roulette = 0

local shots = {}
local shotCount = 0
K.SHOTS_MOST = 48
K.FIRE_GAP = 10
local sinceFire = 99
local nextShot = 0
K.SHOT_HIT = 140
K.SHOT_SAFE_OWN = 20

local function shot_token(id) return "rcShot" .. tostring(id) end

local function drop_shot(id)
    if shots[id] == nil then return end
    OF.gamemodes.hide_token(shot_token(id))
    shots[id] = nil
    shotCount = math.max(0, shotCount - 1)
end
racer.drop_shot = drop_shot

local function drop_all_shots()
    for id in pairs(shots) do OF.gamemodes.hide_token(shot_token(id)) end
    shots = {}
    shotCount = 0
end

function racer.shots() return shots end

K.USE_SOUND = {
    mushroom = "SOUND_GENERAL_BOING1", triple = "SOUND_GENERAL_BOING1",
    golden = "SOUND_GENERAL_BOING2", star = "SOUND_GENERAL_HEART_SPIN",
    shield = "SOUND_GENERAL_SWISH_AIR", boo = "SOUND_OBJ_BOO_BOUNCE_TOP",
    lightning = "SOUND_GENERAL_BOWSER_BOMB_EXPLOSION", feather = "SOUND_ACTION_FLYING_FAST",
    coinbag = "SOUND_GENERAL_COIN_SPURT", koopa = "SOUND_ACTION_THROW",
    three = "SOUND_ACTION_THROW", bullet = "SOUND_OBJ_CANNON1",
    spiny = "SOUND_OBJ_EVIL_LAKITU_THROW", goomba = "SOUND_ACTION_THROW",
    fakebox = "SOUND_ACTION_THROW", bobomb = "SOUND_ACTION_THROW",
}
K.FEATHER_HOP = 70
K.PURSE_COINS = 3

K.SHOT_LOOK = {
    goomba = { anims = "goomba_seg8_anims_0801DA4C" },
    bobomb = { anims = "bobomb_seg8_anims_0802396C" },
    spiny  = { anims = "spiny_seg5_anims_05016EAC", lift = -17 },
    bullet = {},
    koopa  = { spin = 0x800 },
    fakebox = { spin = 0x800 },
}
function racer.dress_shot(token, s)
    local look = K.SHOT_LOOK[s.kind] or {}
    if look.spin ~= nil then return look end
    local want = look.anims ~= nil and gObjectAnimations ~= nil
        and gObjectAnimations[look.anims] or nil
    if want ~= nil and token.oAnimations ~= want then
        token.oAnimations = want
        OF.util.optional("obj_init_animation_with_accel_and_sound", nil, token, 0, 1.0)
    end
    if s.vx ~= 0 or s.vz ~= 0 then
        token.oFaceAngleYaw = math.floor(atan2s(s.vz, s.vx) or 0)
    elseif s.yaw ~= nil then
        token.oFaceAngleYaw = s.yaw
    end
    token.oGraphYOffset = look.lift or 0
    return look
end

K.SHOT = {
    koopa  = { speed = 72, life = 600, bounces = 5, hit = K.HIT_TUMBLE, ground = true },
    bullet = { speed = 80, life = 450, straight = 30, homes = true, hit = K.HIT_TUMBLE },
    spiny  = { speed = 96, life = 900, homes = true, leader = true, blast = 400, hit = K.HIT_LAUNCH, fly = true },
    goomba = { speed = 0, life = 1800, hit = K.HIT_SPIN, ground = true },
    fakebox = { speed = 0, life = 1800, hit = K.HIT_LAUNCH, ground = true },
    bobomb = { speed = 0, life = 1800, arm = 30, blast = 300, hit = K.HIT_TUMBLE, ground = true },
}
racer.SHOT = K.SHOT

local function launch(kind, id, owner, x, y, z, yaw, speed, target)
    if shots[id] ~= nil then return shots[id] end
    if shotCount >= K.SHOTS_MOST then
        local oldest = nil
        for other in pairs(shots) do
            if oldest == nil or other < oldest then oldest = other end
        end
        if oldest ~= nil then drop_shot(oldest) end
    end
    local spec = K.SHOT[kind]
    if spec == nil then return nil end
    local s = {
        id = id, kind = kind, owner = owner, age = 0, bounces = 0,
        x = x, y = y, z = z,
        vx = math.sin(yaw * math.pi / 0x8000) * speed,
        vz = math.cos(yaw * math.pi / 0x8000) * speed,
        vy = 0, target = target, yaw = yaw,
    }
    shots[id] = s
    shotCount = shotCount + 1
    return s
end
racer.launch = launch

local function send_fire(kind, id, x, y, z, yaw, speed, target)
    OF.util.send_all({ ofp = K.PACKET_FIRE, k = kind, id = id,
        x = math.floor(x), y = math.floor(y), z = math.floor(z),
        yaw = math.floor(yaw), spd = math.floor(speed), t = target })
end

local function target_for(kind, ownerLocal)
    local order = published_order()
    if kind == "spiny" then return order[1] ~= nil and global_of(order[1]) or nil end
    for place, li in ipairs(order) do
        if li == ownerLocal then
            if place <= 1 then return nil end
            return global_of(order[place - 1])
        end
    end
    return nil
end

local function spiny_out()
    for _, s in pairs(shots) do
        if s.kind == "spiny" then return true end
    end
    return false
end

local sinceRide = 0
local finished = false

local heardRace = { home = nil }
local hostRefusal = nil
local orderTick = 0
local wrongFor = 0
local lastPos = nil

local backFrames = 0
K.BACK_FRAMES, K.BACK_DEPTH = 20, 250
local safeSpot = nil
local graceGo = 0
local rocket = { count1At = nil, pressedAt = nil, judged = false, early = false }
local lapStarted = 0
local lastSplit = nil
local shownPlace = nil
local heldPlace = nil
local heldFor = 0

K.REMOUNT_STOPS = { beat = 15, none = 0, moment = 45 }
K.REMOUNT_DEFAULT = "beat"
local function remount_frames()
    local stop = K.REMOUNT_STOPS[OF.gamemodes.option_now("knock") or K.REMOUNT_DEFAULT]
    if stop == nil then return K.REMOUNT_STOPS[K.REMOUNT_DEFAULT] end
    return stop
end
OF.gm_shellrace_remount_frames = remount_frames

local function still_out()
    return OF.gamemodes.contending(K.ROLE_RACE)
end
OF.gm_shellrace_still_out = still_out

local function race_done(home, out)
    if out <= 0 then return true end
    return home > 0 and out <= 1
end
racer.race_done = race_done

local function items_on()
    return OF.gamemodes.option_now("items") ~= "off"
end

local function coins_on()
    return OF.gamemodes.option_now("coins") ~= "off"
end

local function racing_me()
    if OF.gamemodes.role(0) ~= K.ROLE_RACE then return false end
    return OF.util.can_play(0)
end

local function count_racers()
    return #riders()
end

K.LAKITU_FRAMES = 60
K.LAKITU_MANUAL = 30
K.FALL_BELOW = 1200
local lakituAt = nil

local function respawn_spot(t)
    if t == nil then return nil end
    if t.kind == "lap" and mine.done > 0 then
        local count = #t.gates
        local back = mine.done - 1
        local tries = 0
        while tries < count do
            local g = t.gates[(back % count) + 1]
            if not g.noRespawn then
                local nextG = t.gates[((back + 1) % count) + 1]
                local at = g.respawn or g
                local nx, nz = flat_dir(nextG.x - at.x, nextG.z - at.z)
                return { x = at.x, y = at.y + 50, z = at.z, yaw = yaw_of(nx, nz) }
            end
            back = back - 1
            tries = tries + 1
        end
    end
    if t.kind == "line" and safeSpot ~= nil then return safeSpot end
    local s = t.start
    return { x = s.x, y = s.y + 50, z = s.z, yaw = yaw_of(s.nx, s.nz) }
end
racer.respawn_spot = respawn_spot

local function call_lakitu(extra)
    if eff.carried > 0 then return false end
    local t = current_track()
    lakituAt = respawn_spot(t)
    if lakituAt == nil then return false end
    eff.carried = K.LAKITU_FRAMES + (extra or 0)
    eff.boost = 0
    write_row()
    return true
end
racer.call_lakitu = call_lakitu

local function carry(m)
    if lakituAt == nil then eff.carried = 0 return end
    m.pos.x, m.pos.y, m.pos.z = lakituAt.x, lakituAt.y, lakituAt.z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.faceAngle.y = lakituAt.yaw or 0
    if m.marioObj ~= nil then
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ = m.pos.x, m.pos.y, m.pos.z
    end
    OF.input.freeze(m)
    if eff.carried <= 1 and K.ride().RIDE_GROUND ~= nil then
        mario_set_forward_vel(m, K.LAKITU_DROP_SPEED)
        set_mario_action(m, K.ride().RIDE_AIR, 0)
        lakituAt = nil
    end
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.key ~= "shellrace" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not racing_me() then return end
    call_lakitu(0)
    return false
end)

local function shell_name(localIndex) return "shell" .. localIndex end

local function hide_shells()
    for index = 0, MAX_PLAYERS - 1 do
        OF.gamemodes.hide_token(shell_name(index))
        OF.gamemodes.hide_token("rcAbove" .. index)
        if racer.hide_cloud ~= nil then racer.hide_cloud(index) end
    end
end

local function riding(index)
    local np = gNetworkPlayers[index]
    if np == nil or not np.connected then return false end
    local role = OF.gamemodes.role(index)
    if role ~= K.ROLE_RACE and role ~= K.ROLE_HOME then return false end
    if not OF.util.can_play(index) then return false end
    return OF.gamemodes.in_place_room(OF.gamemodes.here_place(0), index)
end
racer.riding = riding

local function place_shell(index, m)
    if m == nil or m.pos == nil then
        OF.gamemodes.hide_token(shell_name(index))
        return nil
    end
    local token = OF.gamemodes.show_token(shell_name(index), E_MODEL_KOOPA_SHELL,
        { x = m.pos.x, y = m.pos.y, z = m.pos.z })
    if token == nil then return nil end

    if OF.util.asks(OF.shellride, "place_shell") then
        OF.shellride.place_shell(token, m)
    else
        local o = m.marioObj
        if o ~= nil and o.oMoveAngleYaw ~= nil then token.oFaceAngleYaw = o.oMoveAngleYaw end
    end
    return token
end

K.LAKITU_ANIMS = "lakitu_enemy_seg5_anims_050144D4"
K.CLOUD_HEIGHTS = { 11, 8, 12, 8, 9 }
K.CLOUD_SIZE = 2
K.LAKITU_LIFT = 260
local cloudAt = { x = 0, y = 0, z = 0 }
local function cloud_name(index, k) return "rcCloud" .. index .. "p" .. k end
local function hide_cloud(index)
    for k = 1, #K.CLOUD_HEIGHTS do OF.gamemodes.hide_token(cloud_name(index, k)) end
end
racer.hide_cloud = hide_cloud

local function dress_lakitu(index, token, m)
    local want = gObjectAnimations ~= nil and gObjectAnimations[K.LAKITU_ANIMS] or nil
    if want ~= nil and token.oAnimations ~= want then
        token.oAnimations = want
        OF.util.optional("obj_init_animation_with_accel_and_sound", nil, token, 0, 1.0)
    end
    token.oOpacity = 255
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    token.oFaceAngleYaw = yaw
    local a0 = yaw / 0x8000 * math.pi
    local r = 25 * K.CLOUD_SIZE
    for k = 1, #K.CLOUD_HEIGHTS do
        local a = a0 + 2 * math.pi / #K.CLOUD_HEIGHTS * k
        cloudAt.x = token.oPosX + math.sin(a) * r
        cloudAt.y = token.oPosY - 40 + K.CLOUD_HEIGHTS[k] * K.CLOUD_SIZE
        cloudAt.z = token.oPosZ + math.cos(a) * r
        local part = OF.gamemodes.show_token(cloud_name(index, k), E_MODEL_MIST, cloudAt, nil)
        if part ~= nil then
            OF.util.optional("obj_set_billboard", nil, part)
            OF.util.optional("obj_scale", nil, part, K.CLOUD_SIZE)
            part.oOpacity = 240
        end
    end
end

local function place_above(index, m)
    local name = "rcAbove" .. index
    local letters = index == 0 and fx_letters() or row_of(index).fx
    local model = nil
    local lakitu = letters:find("l", 1, true) ~= nil
    if lakitu then model = E_MODEL_ENEMY_LAKITU
    elseif letters:find("s", 1, true) then model = E_MODEL_STAR end
    if not lakitu then hide_cloud(index) end
    if model == nil or m == nil or m.pos == nil then
        OF.gamemodes.hide_token(name)
        return
    end

    local token = OF.gamemodes.show_token(name, model,
        { x = m.pos.x, y = m.pos.y + K.LAKITU_LIFT, z = m.pos.z }, not lakitu and 0x400 or nil)
    if lakitu and token ~= nil then dress_lakitu(index, token, m) end
end
racer.place_above = place_above

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil then return end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.key ~= "shellrace" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local index = m.playerIndex
    if type(index) ~= "number" then return end
    if not riding(index) then return end
    place_shell(index, m)
    place_above(index, m)
end)

local function tidy_shells()
    for index = 0, MAX_PLAYERS - 1 do
        if not riding(index) then
            OF.gamemodes.hide_token(shell_name(index))
            OF.gamemodes.hide_token("rcAbove" .. index)
            hide_cloud(index)
        end
    end
end

local function box_name(i) return "rcBox" .. i end
local function coin_name(i) return "rcCoin" .. i end

local function hide_furniture()
    for i = 1, 200 do
        OF.gamemodes.hide_token(box_name(i))
        OF.gamemodes.hide_token(coin_name(i))
    end
    OF.gamemodes.hide_token("finish")
end

local function rider_near(x, y, z, reach)
    for _, entry in ipairs(riders()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil then
            local dx, dy, dz = m.pos.x - x, m.pos.y - y, m.pos.z - z
            if dx * dx + dz * dz <= reach * reach and math.abs(dy) <= reach * 1.5 then
                return entry.localIndex
            end
        end
    end
    return nil
end

local function update_boxes(t, many)
    if not items_on() then return end
    for i, b in ipairs(t.boxes) do
        local shown = (not b.extra or many) and (boxBack[i] or 0) <= frame
        if shown then
            local who = rider_near(b.x, b.y, b.z, K.TOUCH_BOX)
            if who ~= nil then
                boxBack[i] = frame + K.BOX_RESPAWN
                shown = false
                if who == 0 and racing_me() and mine.item == "" and roulette == 0
                    and eff.carried == 0 then
                    roulette = K.ROULETTE

                    OF.gamemodes.round_sound(SOUND_GENERAL_BREAK_BOX)
                end
            end
        end
        if shown then
            OF.gamemodes.show_token(box_name(i), E_MODEL_EXCLAMATION_BOX,
                { x = b.x, y = b.y, z = b.z }, 0x200)
        else
            OF.gamemodes.hide_token(box_name(i))
        end
    end
end

local function update_coins(t)
    if not coins_on() then return end
    for i, c in ipairs(t.coins) do
        local shown = (coinBack[i] or 0) <= frame
        if shown then
            local who = rider_near(c.x, c.y, c.z, K.TOUCH_COIN)
            if who ~= nil then
                coinBack[i] = frame + K.COIN_RESPAWN
                shown = false
                if who == 0 and racing_me() and coins < K.COIN_MOST then
                    coins = coins + 1
                    write_row()
                end
            end
        end
        if shown then

            OF.gamemodes.show_token(coin_name(i), E_MODEL_YELLOW_COIN,
                { x = c.x, y = c.y, z = c.z }, nil, nil, true)
        else
            OF.gamemodes.hide_token(coin_name(i))
        end
    end
end

local function take_hit(m, severity, shotId)
    if m == nil then return false end
    if shotId ~= nil then
        drop_shot(shotId)
        OF.util.send_all({ ofp = K.PACKET_HIT, id = shotId })
    end
    if eff.starred > 0 or eff.boo > 0 then return false end
    if eff.shield > 0 then
        eff.shield = 0
        write_row()
        return false
    end
    if mine.item == "three" and mine.count > 0 then

        mine.count = mine.count - 1
        if mine.count <= 0 then mine.item = "" end
        write_row()
        return false
    end
    if K.ride().RIDE_HIT ~= nil then set_mario_action(m, K.ride().RIDE_HIT, severity or K.HIT_SPIN) end
    coins = math.max(0, coins - K.COINS_PER_HIT)
    eff.boost = 0
    write_row()

    OF.gamemodes.cue("bad")
    return true
end
racer.take_hit = take_hit

local function my_yaw(m)
    return m.faceAngle.y or 0
end

local function use_item(m)
    local item = mine.item
    if item == "" or sinceFire < K.FIRE_GAP then return false end
    local back = (m.controller ~= nil and (m.controller.stickY or 0) < -40)
    local yaw = my_yaw(m)
    if back then yaw = yaw + 0x8000 end
    if yaw > 0x7FFF then yaw = yaw - 0x10000 end
    local me = global_of(0) or 0
    local spent = true

    local heard = K.USE_SOUND[item]
    if heard ~= nil and _G[heard] ~= nil then OF.gamemodes.round_sound(_G[heard]) end

    if item == "mushroom" or item == "triple" then
        eff.boost = 40
    elseif item == "feather" then

        if m.action == K.ride().RIDE_GROUND and K.ride().RIDE_AIR ~= nil then
            m.vel.y = K.FEATHER_HOP
            set_mario_action(m, K.ride().RIDE_AIR, 0)
        else
            return false
        end
    elseif item == "coinbag" then
        coins = math.min(K.COIN_MOST, coins + K.PURSE_COINS)
    elseif item == "golden" then
        if eff.golden <= 0 then eff.golden = 300 end
        eff.boost = 40
        spent = false
    elseif item == "star" then
        eff.starred = 240
    elseif item == "shield" then
        eff.shield = 180
    elseif item == "boo" then
        eff.boo = 180

        local place = agreed_place(0)
        local order = published_order()
        if place > 1 then
            local pick = order[(mix(frame, me, mine.rolls) % (place - 1)) + 1]
            local victim = pick ~= nil and global_of(pick) or nil
            if victim ~= nil then
                OF.util.send_all({ ofp = K.PACKET_STEAL, to = victim, by = me })
            end
        end
    elseif item == "lightning" then
        OF.util.send_all({ ofp = K.PACKET_ZAP, by = me })
    else
        local spec = K.SHOT[item == "three" and "koopa" or item]
        local kind = item == "three" and "koopa" or item
        if spec == nil then return false end
        nextShot = nextShot + 1
        local id = me * 10000 + (nextShot % 10000)
        local dropped = spec.speed == 0
        local d = dropped and -180 or 160
        local x = m.pos.x + math.sin(my_yaw(m) * math.pi / 0x8000) * d
        local z = m.pos.z + math.cos(my_yaw(m) * math.pi / 0x8000) * d
        local speed = spec.speed
        if kind == "koopa" then speed = math.max(48, (m.forwardVel or 0) * 1.2) end
        if back and not dropped then
            x = m.pos.x - math.sin(my_yaw(m) * math.pi / 0x8000) * 160
            z = m.pos.z - math.cos(my_yaw(m) * math.pi / 0x8000) * 160
        end
        local target = spec.homes and target_for(kind, 0) or nil
        launch(kind, id, me, x, m.pos.y + 40, z, yaw, speed, target)
        send_fire(kind, id, x, m.pos.y + 40, z, yaw, speed, target)
    end

    sinceFire = 0
    if item == "three" or item == "triple" then
        mine.count = mine.count - 1
        if mine.count <= 0 then mine.item = "" end
    elseif spent then
        mine.item = ""
        mine.count = 0
    end
    write_row()
    return true
end
racer.use_item = use_item

local function give_item(key)
    mine.item = key
    mine.count = (K.ITEMS[key] and K.ITEMS[key].count) or 1
    write_row()
end
racer.give_item = give_item

local function finish_roulette()
    local seed = tonumber(gGlobalSyncTable[K.SEED_KEY]) or 0
    local place, field = agreed_place(0)
    local key = roll(seed, global_of(0), mine.rolls, place, math.max(field, count_racers()),
        OF.gamemodes.option_now("items") == "frantic", spiny_out())
    mine.rolls = mine.rolls + 1
    give_item(key)

    OF.gamemodes.round_sound(OF.sounds.TICK)
end

local function ray_wall(x, y, z, dx, dz)
    if collision_find_surface_on_ray == nil then return nil end
    local info = collision_find_surface_on_ray(x, y + 60, z, dx, 0, dz)
    if info == nil or info.surface == nil then return nil end
    return info.surface
end

local function rider_pos(globalIndex)
    if globalIndex == nil then return nil end
    local li = local_of(globalIndex)
    if li == nil then return nil end
    local m = gMarioStates[li]
    if m == nil or m.pos == nil then return nil end
    return m.pos
end

local function steer(s, tx, tz, speed)
    local want = atan2s(tz - s.z, tx - s.x) or 0
    local have = atan2s(s.vz, s.vx) or 0
    local diff = ((want - have + 0x8000) % 0x10000) - 0x8000
    if diff > 0x800 then diff = 0x800 elseif diff < -0x800 then diff = -0x800 end
    local yaw = have + diff
    s.vx = math.sin(yaw * math.pi / 0x8000) * speed
    s.vz = math.cos(yaw * math.pi / 0x8000) * speed
end

local function explode(s)
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil and racing_me() then
        local dx, dz = m.pos.x - s.x, m.pos.z - s.z
        local spec = K.SHOT[s.kind]
        if dx * dx + dz * dz <= spec.blast * spec.blast
            and math.abs(m.pos.y - s.y) <= spec.blast then
            take_hit(m, spec.hit, s.id)
            return
        end
    end
    drop_shot(s.id)
end

function racer.hear_the_shot(s, spec, me)
    if s.warned or s.owner == me or not racing_me() then return false end
    local atMe = false
    if spec.leader then
        atMe = published_order()[1] == 0
    elseif spec.homes then
        atMe = s.target == me
    end
    if not atMe then return false end
    s.warned = true
    OF.gamemodes.cue("hazard")
    return true
end

local function update_shots()
    local m = gMarioStates[0]
    local me = global_of(0)
    for id, s in pairs(shots) do
        local spec = K.SHOT[s.kind]
        s.age = s.age + 1
        racer.hear_the_shot(s, spec, me)
        if s.age > spec.life then
            drop_shot(id)
        else
            if spec.homes and s.age > (spec.straight or 0) then
                local tp = rider_pos(s.target)
                if spec.leader then
                    local order = published_order()
                    tp = order[1] ~= nil and gMarioStates[order[1]] ~= nil
                        and gMarioStates[order[1]].pos or nil
                end
                if tp ~= nil then
                    steer(s, tp.x, tp.z, spec.speed)
                    if spec.fly then s.y = s.y + ((tp.y + 150) - s.y) * 0.1 end
                    if spec.blast ~= nil then
                        local dx, dz = tp.x - s.x, tp.z - s.z
                        if dx * dx + dz * dz <= 300 * 300 then explode(s) end
                    end
                end
            end
            if shots[id] ~= nil and (s.vx ~= 0 or s.vz ~= 0) then
                if not spec.fly then
                    local wall = ray_wall(s.x, s.y, s.z, s.vx, s.vz)
                    if wall ~= nil then
                        if spec.bounces ~= nil and s.bounces < spec.bounces
                            and wall.normal ~= nil then

                            local wx, wz = flat_dir(wall.normal.x, wall.normal.z)
                            local dot = s.vx * wx + s.vz * wz
                            s.vx = s.vx - 2 * dot * wx
                            s.vz = s.vz - 2 * dot * wz
                            s.bounces = s.bounces + 1
                        else
                            drop_shot(id)
                        end
                    end
                end
                if shots[id] ~= nil then
                    s.x = s.x + s.vx
                    s.z = s.z + s.vz
                    if spec.ground then
                        local h = floor_near(s.x, s.y, s.z)
                        if h == nil then drop_shot(id) else s.y = h + 40 end
                    end
                end
            end

            if shots[id] ~= nil and m ~= nil and m.pos ~= nil and racing_me()
                and eff.carried == 0 and not (s.owner == me and s.age < K.SHOT_SAFE_OWN)
                and (m.action ~= K.ride().RIDE_HIT) then
                local armed = spec.arm == nil or s.age >= spec.arm
                local dx, dy, dz = m.pos.x - s.x, m.pos.y - s.y, m.pos.z - s.z
                if armed and spec.leader == nil
                    and dx * dx + dz * dz <= K.SHOT_HIT * K.SHOT_HIT and math.abs(dy) <= 200 then
                    if spec.blast ~= nil then explode(s) else take_hit(m, spec.hit, id) end
                end
            end
            if shots[id] ~= nil then
                local model = _G[K.ITEMS[s.kind == "koopa" and "koopa" or s.kind].model]
                local look = K.SHOT_LOOK[s.kind] or {}
                local token = OF.gamemodes.show_token(shot_token(id), model,
                    { x = s.x, y = s.y, z = s.z }, look.spin)
                if token ~= nil then racer.dress_shot(token, s) end
                if token ~= nil and s.kind == "fakebox" then token.oFaceAngleRoll = 0x8000 end
            end
        end
    end
end
racer.update_shots = update_shots

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or type(data.ofp) ~= "string" then return end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.key ~= "shellrace" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if data.ofp == K.PACKET_FIRE then
        if type(data.id) ~= "number" or K.SHOT[data.k] == nil then return end
        launch(data.k, data.id, math.floor(data.id / 10000), tonumber(data.x) or 0,
            tonumber(data.y) or 0, tonumber(data.z) or 0, tonumber(data.yaw) or 0,
            tonumber(data.spd) or 0, tonumber(data.t))
    elseif data.ofp == K.PACKET_HIT then
        if type(data.id) == "number" then drop_shot(data.id) end
    elseif data.ofp == K.PACKET_ZAP then
        if not racing_me() then return end
        if data.by == global_of(0) or eff.starred > 0 or eff.boo > 0 then return end
        if eff.shield > 0 then eff.shield = 0 write_row() return end
        eff.shrunk = 180
        mine.item = mine.item == "golden" and "golden" or ""
        if mine.item == "" then mine.count = 0 end
        local m = gMarioStates[0]
        if m ~= nil and K.ride().RIDE_HIT ~= nil then set_mario_action(m, K.ride().RIDE_HIT, K.HIT_SPIN) end
        write_row()
    elseif data.ofp == K.PACKET_STEAL then
        if data.to ~= global_of(0) then return end
        if mine.item ~= "" then
            mine.item = ""
            mine.count = 0
            write_row()

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("medal", OF.lang.t("ITEM STOLEN"), nil, { tone = "bad" })
            end
        end
    end
end)

local shrunkDrawn = {}

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.marioObj == nil then return end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.key ~= "shellrace" then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local index = m.playerIndex
    if type(index) ~= "number" or not riding(index) then return end
    local letters = index == 0 and fx_letters() or row_of(index).fx
    local gfx = m.marioObj.header ~= nil and m.marioObj.header.gfx or nil
    if gfx == nil or gfx.scale == nil then return end
    if letters:find("k", 1, true) then
        gfx.scale.x, gfx.scale.y, gfx.scale.z = 0.6, 0.6, 0.6
        shrunkDrawn[index] = true
    elseif shrunkDrawn[index] then

        gfx.scale.x, gfx.scale.y, gfx.scale.z = 1, 1, 1
        shrunkDrawn[index] = nil
    end
end)

local mode = {
    key = "shellrace",
    name = "Shell Racer",
    blurb = "laps on a shell that never lets go - items, coins and a Lakitu",

    how = "Everybody surfs a shell round the track; it never lets go.\n"
        .. "Laps on host tracks; on a course, start to the gold ring.\n"
        .. "Boxes give items: B uses one, back on the stick drops it.\n"
        .. "Coins make the shell faster; a hit knocks some loose.\n"
        .. "Hold Z through a bend to drift; let go for a boost.\n"
        .. "Fall off and a Lakitu fishes you back onto the road.\n"
        .. "It ends when all but the last are home - first home wins.",
    minPlayers = 2,

    maps = "surveyed",
    surveyKeys = { "floodStart", "floodGoal" },

    studioTracksOnly = "Shell Racer runs on tracks built in Oldfart Studio or the Forge.",

    contentActs = { [LEVEL_BBH or -2] = 2 },

    forgeTracks = true,

    room = { sweep = { "cannons", "pickups", "enemies", "bosses", "projectiles",
                       "spawners" } },
    music = SEQ_LEVEL_SLIDE,
    defaultLimit = 300,
    countsUp = true,

    roamOnCountdown = true,
    teams = false,

    resultsBy = "splits",

    placesOnBoard = true,

    unsolidInAFight = true,
    options = {
        { key = "laps", name = "Laps",
          help = "how many laps a race on a host-built track is",
          choices = {
              { key = "track", name = "what the track says",
                help = "the track's own number, three if it says none" },
              { key = "1", name = "one", help = "one lap" },
              { key = "2", name = "two", help = "two laps" },
              { key = "3", name = "three", help = "three laps" },
              { key = "5", name = "five", help = "five laps" },
          } },
        { key = "class", name = "Speed class",
          help = "how fast every shell in the race goes",
          choices = {
              { key = "50", name = "50cc",
                help = "the shell's own speed - the usual race" },
              { key = "100", name = "100cc",
                help = "every shell an eighth faster" },
              { key = "150", name = "150cc",
                help = "every shell a quarter faster" },
          } },
        { key = "items", name = "Items",
          help = "what the item boxes hand out",
          choices = {
              { key = "normal", name = "normal",
                help = "defence at the front, speed at the back" },
              { key = "off", name = "off",
                help = "no boxes on the track at all" },
              { key = "frantic", name = "frantic",
                help = "everybody rolls as if two places further back" },
          } },
        { key = "coins", name = "Coins",
          help = "whether coins on the track make a shell faster",
          choices = {
              { key = "speed", name = "on",
                help = "each held is a little top speed, ten at most" },
              { key = "off", name = "off",
                help = "nothing to pick up but boxes" },
          } },
        { key = "rocket", name = "Rocket start",
          help = "press A just before GO for a boost",
          choices = {
              { key = "on", name = "on", help = "half a second's window before GO" },
              { key = "off", name = "off", help = "everybody leaves the line alike" },
          } },

        { key = "knock", name = "Time off the shell after a hit",
          help = "how long anything that takes the ride costs you",
          choices = {
              { key = "beat", name = "half a second",
                help = "on your feet long enough to see it" },
              { key = "none", name = "none",
                help = "the shell is back under you the same frame" },
              { key = "moment", name = "a second and a half",
                help = "a moment on your feet before the shell comes back" },
          } },
        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual race", sets = {} },
    { key = "gp", name = "Grand Prix", help = "three laps at 100cc",
      sets = { laps = "3", class = "100" } },
    { key = "trial", name = "Time trial", help = "no items, coins are speed",
      sets = { items = "off", coins = "speed" } },
    { key = "frantic", name = "Frantic", help = "150cc and frantic items",
      sets = { class = "150", items = "frantic" } },
}
mode.boardTitle = "Race"
racer.mode = mode
mode.shape_ride = racer.shape_ride

function mode.terms()
    return OF.lang.t("all but the last home")
end

K.FINISH_SECONDS = 30
local clockAsked, clockFromTrack, finishTimer = false, false, false
function racer.backstop_for(t)
    if t == nil then return nil end
    return 2 * (t.par or 45) * laps_of(t) + 60
end

function mode.setup(players, options)
    clockAsked = options ~= nil and tonumber(options.limit) ~= nil
    clockFromTrack, finishTimer = false, false
    local globals = {}
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, K.ROLE_RACE)
        local g = global_of(entry.localIndex)
        if g ~= nil then table.insert(globals, g) end
    end
    local seed = math.random(1, 1000000)
    local rank = {}
    if type(lastResult) == "table" then
        for place, g in ipairs(lastResult) do rank[g] = place end
    end
    table.sort(globals, function(a, b)
        local ra, rb = rank[a], rank[b]
        if ra ~= nil and rb ~= nil then return ra > rb end

        if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
        return mix(seed, a, 0) < mix(seed, b, 0)
    end)
    OF.util.publish("ofRcSeed", seed)
    OF.util.publish("ofRcGrid", encode_list(globals))
    OF.util.publish("ofRcOrder", encode_list(globals))
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end

    local ft = K.forge_track(np.currLevelNum, np.currAreaIndex)
    if ft ~= nil then
        return { x = ft.start.x, y = ft.start.y, z = ft.start.z,
                 level = np.currLevelNum, area = np.currAreaIndex }
    end
    local list = read_markers()
    if #list > 0 then
        local t = track_from_markers(list)
        if t ~= nil then
            return { x = t.start.x, y = t.start.y, z = t.start.z,
                     level = np.currLevelNum, area = np.currAreaIndex }
        end
    end
    local here = { level = np.currLevelNum, area = np.currAreaIndex }
    local at = OF.gamemodes.surveyed(here, "floodStart")
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z, level = np.currLevelNum, area = np.currAreaIndex }
end

function mode.death_place()
    local at = OF.gamemodes.round_place()
    if at == nil then return nil end
    local t = current_track()
    local spot = respawn_spot(t)
    if spot == nil then
        spot = OF.gamemodes.surveyed(at, "floodStart")
        if spot == nil then return nil end
    end
    return { x = spot.x, y = spot.y, z = spot.z, level = at.level, area = at.area }
end

function mode.pin()
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local _, why = build_track(np.currLevelNum, np.currAreaIndex)
    if why ~= nil then hostRefusal = why end
end

function mode.on_start()
    sinceRide = 0
    finished = false
    heardRace.home = nil
    frame = 0
    boxBack, coinBack = {}, {}
    roulette = 0
    sinceFire = 99
    wrongFor = 0
    lastPos = nil
    backFrames = 0
    racer.line_forget()
    safeSpot = nil
    lakituAt = nil
    lapStarted = 0
    lastSplit = nil
    shownPlace, heldPlace, heldFor = nil, nil, 0
    rocket = { count1At = nil, pressedAt = nil, judged = false, early = false }
    drop_all_shots()
    forget_mine()
    forget_track()
    K.forget_grid()
end

function mode.cleanup()
    if K.ride().open_the_ways ~= nil then K.ride().open_the_ways() end
    sinceRide = 0
    finished = false

    for index in pairs(shrunkDrawn) do
        local m = gMarioStates[index]
        local gfx = m ~= nil and m.marioObj ~= nil and m.marioObj.header ~= nil
            and m.marioObj.header.gfx or nil
        if gfx ~= nil and gfx.scale ~= nil then
            gfx.scale.x, gfx.scale.y, gfx.scale.z = 1, 1, 1
        end
    end
    shrunkDrawn = {}
    hide_shells()
    hide_furniture()
    drop_all_shots()
    hostRefusal = nil
    lakituAt = nil
    forget_mine()

    OF.util.publish_row(0, "ofRcState", nil)
    forget_track()
    K.forget_grid()
    if OF.util.is_host() then
        OF.util.publish("ofRcSeed", nil)
        OF.util.publish("ofRcGrid", nil)
        OF.util.publish("ofRcOrder", nil)
    end
end

K.RIDE_GROUPS = nil

local function may_ride(m)
    if m == nil or m.action == nil then return false end
    if (m.health or 0) < 0x100 then return false end
    if K.RIDE_GROUPS == nil then
        K.RIDE_GROUPS = {
            [ACT_GROUP_STATIONARY] = true,
            [ACT_GROUP_MOVING] = true,
            [ACT_GROUP_AIRBORNE] = true,
        }
    end
    return K.RIDE_GROUPS[m.action & ACT_GROUP_MASK] == true
end

local function on_the_ride(m)
    return OF.util.asks(OF.shellride, "on_the_ride") and OF.shellride.on_the_ride(m)
end
racer.on_the_ride = on_the_ride

K.ROCKET_WINDOW = 15
K.ROCKET_BEST = 7

local function rocket_boost(framesBefore)
    if framesBefore == nil or framesBefore < 1 or framesBefore > K.ROCKET_WINDOW then return 0 end
    return math.max(8, 24 - math.abs(framesBefore - K.ROCKET_BEST) * 2)
end
racer.rocket_boost = rocket_boost

local gridTrack, gridRoom = nil, nil
function K.countdown_track()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local key = room_key(np.currLevelNum, np.currAreaIndex)
    if gridRoom == key then return gridTrack end
    if K.forge_track(np.currLevelNum, np.currAreaIndex) == nil
        and #read_markers() == 0 then
        return nil
    end
    gridTrack = build_track(np.currLevelNum, np.currAreaIndex)
    gridRoom = key
    return gridTrack
end
function K.forget_grid() gridTrack, gridRoom = nil, nil end
racer.countdown_track = K.countdown_track

local function hold_on_grid(m, t)
    t = t or current_track()
    if t == nil then return end
    local slot = my_slot()
    if slot == nil then return end
    local x, y, z = slot_spot(t, slot)
    m.pos.x, m.pos.y, m.pos.z = x, y, z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.faceAngle.y = yaw_of(t.start.nx, t.start.nz)
    if m.marioObj ~= nil then
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ = x, y, z
        m.marioObj.oMoveAngleYaw = m.faceAngle.y
    end
end

local function countdown_frame(m)
    if not OF.util.can_play(0) then return end
    local count = gGlobalSyncTable.ofGmCount or 99
    local pressed = m.controller ~= nil
        and ((m.controller.buttonPressed or 0) & A_BUTTON) ~= 0

    local t = current_track() or K.countdown_track()
    if count <= 3 or (t ~= nil and (t.forge or t.studio)) then hold_on_grid(m, t) end
    if count == 1 and rocket.count1At == nil then rocket.count1At = frame end
    if pressed and OF.gamemodes.option_now("rocket") ~= "off" then
        if count >= 2 then
            rocket.early = true
        elseif rocket.pressedAt == nil then
            rocket.pressedAt = frame
        end
    end
    OF.input.freeze(m)
    m.vel.x, m.vel.z, m.forwardVel = 0, 0, 0
end

local function judge_rocket()
    if rocket.judged then return end
    rocket.judged = true
    if rocket.early or rocket.pressedAt == nil or rocket.count1At == nil then return end
    local before = (rocket.count1At + 30) - rocket.pressedAt
    local boost = rocket_boost(before)
    if boost > 0 then
        eff.boost = boost

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("ROCKET START"), nil)
        end
    end
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local state = OF.gamemodes.state()

    if (state == OF.gamemodes.ACTIVE or state == OF.gamemodes.COUNTDOWN)
        and OF.util.round_screen() and K.ride().shut_the_ways ~= nil then
        K.ride().shut_the_ways(false)
    end
    if state == OF.gamemodes.COUNTDOWN then
        if OF.gamemodes.role(0) == K.ROLE_RACE then countdown_frame(m) end
        return
    end
    if state ~= OF.gamemodes.ACTIVE then return end
    if not racing_me() then return end
    if K.ride().RIDE_GROUND == nil then return end

    if eff.carried > 0 then
        carry(m)
        return
    end

    if on_the_ride(m) then
        sinceRide = 0
        return
    end

    sinceRide = sinceRide + 1
    if sinceRide < remount_frames() then return end
    if not may_ride(m) then return end

    sinceRide = 0
    if (m.forwardVel or 0) < K.PUSH_OFF then mario_set_forward_vel(m, K.PUSH_OFF) end
    set_mario_action(m, K.ride().RIDE_GROUND, 0)
end

local function tick_fx()
    local before = fx_letters()
    local hadGolden = eff.golden > 0
    for k, v in pairs(eff) do
        if v > 0 then eff[k] = v - 1 end
    end

    if hadGolden and eff.golden == 0 and mine.item == "golden" then
        mine.item = ""
        mine.count = 0
        write_row()
    end
    if before ~= fx_letters() then write_row() end
end

local function check_falls(m, t)
    if eff.carried > 0 then return end
    local manual = m.controller ~= nil
        and ((m.controller.buttonPressed or 0) & D_JPAD) ~= 0
    if manual then call_lakitu(K.LAKITU_MANUAL) return end

    local floorY = nil
    if t.kind == "lap" and mine.done > 0 then
        floorY = t.gates[((mine.done - 1) % #t.gates) + 1].y
    elseif t.kind == "line" then
        floorY = safeSpot ~= nil and safeSpot.y or t.start.y
    end
    if floorY ~= nil and m.pos.y < floorY - K.FALL_BELOW and (m.vel.y or 0) < 0 then
        call_lakitu(0)
        return
    end
    for _, o in ipairs(t.outs) do
        local dx, dz = m.pos.x - o.x, m.pos.z - o.z
        if dx * dx + dz * dz <= o.r * o.r and m.pos.y >= o.y and m.pos.y <= o.y + o.h then
            call_lakitu(0)
            return
        end
    end
    if t.waterDeadly and m.waterLevel ~= nil and m.pos.y < m.waterLevel - 40 then
        call_lakitu(0)
        return
    end
    if t.lavaDeadly and m.floor ~= nil and m.floor.type == SURFACE_BURNING
        and m.pos.y <= (m.floorHeight or m.pos.y) + 10 then
        call_lakitu(0)
        return
    end

    if t.kind == "line" and m.action == K.ride().RIDE_GROUND and frame % 30 == 0
        and m.floor ~= nil and m.floor.type ~= SURFACE_BURNING
        and m.floor.type ~= SURFACE_DEATH_PLANE then
        safeSpot = { x = m.pos.x, y = m.pos.y + 50, z = m.pos.z, yaw = m.faceAngle.y or 0 }
    end
end

local function check_boosts(m, t)
    for _, b in ipairs(t.boosts) do
        local dx, dz = m.pos.x - b.x, m.pos.z - b.z
        if dx * dx + dz * dz <= b.r * b.r and math.abs(m.pos.y - b.y) <= 200 then

            local more = (m.controller ~= nil
                and ((m.controller.buttonDown or 0) & A_BUTTON) == 0) and 15 or 0
            if eff.boost <= 0 then OF.gamemodes.round_sound(SOUND_GENERAL_BOING2) end
            eff.boost = math.max(eff.boost, 45 + more)
        end
    end
end

K.PAD_SEEN = 9000
K.GOAL_RING = 400
local padFrom, padTo = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }
function racer.draw_boosts(t, m)
    if t == nil or m == nil or m.pos == nil then return 0 end
    local r, g, b = OF.util.round_tone("gold")
    local drawn = 0
    for _, pad in ipairs(t.boosts) do
        local dx, dz = pad.x - m.pos.x, pad.z - m.pos.z
        if dx * dx + dz * dz <= K.PAD_SEEN * K.PAD_SEEN then
            local nx, nz = pad.nx or 0, pad.nz or 1
            local sx, sz = nz, -nx
            local w = pad.r * 0.7
            for k = -1, 1 do
                local tipX = pad.x + nx * (k * pad.r * 0.5 + pad.r * 0.3)
                local tipZ = pad.z + nz * (k * pad.r * 0.5 + pad.r * 0.3)
                local backX, backZ = tipX - nx * pad.r * 0.4, tipZ - nz * pad.r * 0.4
                padTo.x, padTo.y, padTo.z = tipX, pad.y + 4, tipZ
                for side = -1, 1, 2 do
                    padFrom.x, padFrom.y, padFrom.z = backX + sx * w * side, pad.y + 4, backZ + sz * w * side
                    if OF.util.world_line(padFrom, padTo, 3, r, g, b, 230) then drawn = drawn + 1 end
                end
            end
        end
    end
    return drawn
end

local function check_star_contact(m)
    if eff.starred > 0 or eff.boo > 0 or m.action == K.ride().RIDE_HIT then return end
    for _, entry in ipairs(riders()) do
        local li = entry.localIndex
        if li ~= 0 and row_of(li).fx:find("s", 1, true) then
            local o = gMarioStates[li]
            if o ~= nil and o.pos ~= nil then
                local dx, dy, dz = o.pos.x - m.pos.x, o.pos.y - m.pos.y, o.pos.z - m.pos.z
                if dx * dx + dz * dz <= 150 * 150 and math.abs(dy) <= 200 then
                    take_hit(m, K.HIT_TUMBLE, nil)
                    return
                end
            end
        end
    end
end

local function cross_the_line()
    finished = true

    local place = #OF.gamemodes.with_role(K.ROLE_HOME) + 1
    OF.util.publish_row(0, "ofScore", math.max(1, count_racers() - place + 1))
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.set_role(0, K.ROLE_HOME)

    OF.gamemodes.cue("good")

    if OF.util.asks(OF.hud, "banner") then
        local said = OF.util.asks(OF.hud, "ordinal") and OF.hud.ordinal(place) or nil
        OF.hud.banner("objective", OF.lang.t("FINISHED"), said, { quiet = true })
    end
end

local function check_gates(m, t)
    if t.kind == "line" then

        racer.line_gates_of(t)
        K.line.frame = (K.line.frame or 0) + 1
        local now = K.line.frame
        if lastPos ~= nil then
            racer.line_step(t, lastPos.x, lastPos.y, lastPos.z, m.pos.x, m.pos.y, m.pos.z, now)
        end
        lastPos = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
        local dx, dy, dz = t.goal.x - m.pos.x, t.goal.y - m.pos.y, t.goal.z - m.pos.z
        if dx * dx + dy * dy + dz * dz <= K.FINISH_RADIUS * K.FINISH_RADIUS then
            if not racer.line_clear(t) then
                racer.say_missed(now)
                return
            end
            mine.done = 1
            write_row()
            cross_the_line()
        end
        return
    end
    if lastPos == nil then
        lastPos = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
        return
    end
    local count = #t.gates
    local nextG = t.gates[(mine.done % count) + 1]

    local afterG = count >= 3 and t.gates[((mine.done + 1) % count) + 1] or nil
    local steps = 0
    if crossed_any(nextG, lastPos.x, lastPos.y, lastPos.z, m.pos.x, m.pos.y, m.pos.z, true) then
        steps = 1
    elseif afterG ~= nil and mine.done > 0
        and crossed_any(afterG, lastPos.x, lastPos.y, lastPos.z, m.pos.x, m.pos.y, m.pos.z, true) then
        steps = 2
    end
    for _ = 1, steps do
        backFrames = 0
        mine.done = mine.done + 1
        local laps = laps_of(t)
        if mine.done % count == 1 then

            local lap = lap_of(mine.done, count)
            local now = OF.gamemodes.since_start()
            if lap >= 2 then
                lastSplit = now - lapStarted

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("medal", OF.lang.fill("LAP @  @", lap - 1,
                        OF.gamemodes.clock(lastSplit)), nil)
                end
            end
            lapStarted = now
            if mine.done >= laps * count + 1 then
                write_row()
                cross_the_line()
                return
            end

            if lap == laps and laps > 1 and OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("roundstate", OF.lang.t("FINAL LAP"), nil)
            end
        end
        write_row()
    end
    if steps == 0 and mine.done > 0 then

        local lastG = t.gates[((mine.done - 1) % count) + 1]
        if backFrames == 0 then
            if crossed_any(lastG, lastPos.x, lastPos.y, lastPos.z, m.pos.x, m.pos.y, m.pos.z, false) then
                backFrames = 1
            end
        else
            local depth = (m.pos.x - lastG.x) * lastG.nx + (m.pos.z - lastG.z) * lastG.nz
            local side = (m.pos.x - lastG.x) * lastG.nz - (m.pos.z - lastG.z) * lastG.nx
            if depth >= 0 or math.abs(side) > lastG.w * 0.5 or depth < -K.GATE_BAND then
                backFrames = 0
            else
                backFrames = backFrames + 1
                if backFrames >= K.BACK_FRAMES and depth <= -K.BACK_DEPTH then
                    backFrames = 0
                    mine.done = mine.done - 1
                    write_row()
                end
            end
        end
    end
    lastPos.x, lastPos.y, lastPos.z = m.pos.x, m.pos.y, m.pos.z
end
racer.check_gates = check_gates

K.WRONG_AFTER = 60

K.WRONG_OFF = 0x5555
function racer.road_dir(t, done, x, z)
    local count = #t.gates
    local nextG = t.gates[(done % count) + 1]
    if done <= 0 then return nextG.nx, nextG.nz end
    local lastG = t.gates[((done - 1) % count) + 1]
    local past = (x - lastG.x) * lastG.nx + (z - lastG.z) * lastG.nz
    local ahead = (nextG.x - x) * nextG.nx + (nextG.z - z) * nextG.nz
    local k = 0.5
    if past + ahead > 1 then k = math.max(0, math.min(1, past / (past + ahead))) end

    return flat_dir(1000 * (lastG.nx * (1 - k) + nextG.nx * k), 1000 * (lastG.nz * (1 - k) + nextG.nz * k))
end
local function check_wrong_way(m, t)
    if t.kind ~= "lap" then wrongFor = 0 return end
    local vx, vz = (m.vel ~= nil and m.vel.x or 0), (m.vel ~= nil and m.vel.z or 0)
    if vx * vx + vz * vz <= 64 and (m.forwardVel or 0) > 8 then

        local yaw = (m.faceAngle.y or 0) * math.pi / 0x8000
        vx, vz = math.sin(yaw) * m.forwardVel, math.cos(yaw) * m.forwardVel
    end
    local moving = vx * vx + vz * vz > 64
    if not moving then
        wrongFor = math.max(0, wrongFor - 2)
        return
    end
    local rx, rz = racer.road_dir(t, mine.done, m.pos.x, m.pos.z)
    local want = atan2s(rz, rx) or 0
    local going = atan2s(vz, vx) or 0
    local diff = math.abs(((going - want + 0x8000) % 0x10000) - 0x8000)
    if diff > K.WRONG_OFF then
        wrongFor = wrongFor + 1
    else
        wrongFor = math.max(0, wrongFor - 2)
    end
end
racer.check_wrong_way = check_wrong_way
function racer.wrong_way() return wrongFor >= K.WRONG_AFTER end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    sinceFire = sinceFire + 1
    local t = current_track()
    if t == nil then return end

    racer.walk_step(t)

    if not racing_me() or finished then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    judge_rocket()
    tick_fx()
    if roulette > 0 then
        roulette = roulette - 1
        if roulette == 0 then finish_roulette() end
    end

    check_falls(m, t)
    if eff.carried > 0 then return end
    check_gates(m, t)
    if finished then return end
    check_boosts(m, t)
    check_star_contact(m)
    check_wrong_way(m, t)

    local pressedB = m.controller ~= nil
        and ((m.controller.buttonPressed or 0) & B_BUTTON) ~= 0
    if pressedB then
        if mine.item == "golden" and eff.golden > 0 then
            eff.boost = 40
        else
            use_item(m)
        end
    end
    if written == nil then write_row() end
end

function mode.board()
    local t = current_track()
    local rows = {}
    for place, s in ipairs(standings()) do
        local right
        if s.time ~= nil then
            right = OF.gamemodes.clock(s.time)
        elseif t ~= nil and t.kind == "lap" then
            right = OF.lang.fill("lap @ of @", math.max(1, lap_of(s.done, #t.gates)), laps_of(t))
        else
            right = string.format("%.0f%%", s.progress * 100)
        end
        table.insert(rows, { localIndex = s.localIndex, name = s.name, right = right,
                             place = place })
    end
    return rows
end

local function score_and_name()
    local list = standings()
    local order = {}
    for _, s in ipairs(list) do
        local g = global_of(s.localIndex)
        if g ~= nil then table.insert(order, g) end
    end
    lastResult = order
    return list
end
racer.score_and_name = score_and_name

local function end_race()
    local list = score_and_name()
    local first = list[1]
    if first == nil then
        OF.gamemodes.finish("Nobody was left racing.")
        return
    end
    if first.time ~= nil then
        local names = {}
        for _, s in ipairs(list) do
            if s.time == first.time then table.insert(names, s.name) end
        end
        if #names > 1 then
            OF.gamemodes.finish("@ won.", { names = names }, OF.util.list_of(names))
        else
            OF.gamemodes.finish("@ won.", first.name, first.name)
        end
        return
    end
    if first.progress <= 0 then
        OF.gamemodes.finish("Nobody got anywhere.")
        return
    end
    local t = current_track()
    if t ~= nil and t.kind == "line" then
        OF.gamemodes.finish("@ won - closest to the flagpole.", first.name, first.name)
    else
        OF.gamemodes.finish("@ won - furthest round the track.", first.name, first.name)
    end
end

function mode.host_update()
    if hostRefusal ~= nil then
        local why = hostRefusal
        hostRefusal = nil
        OF.gamemodes.abandon(why)
        return
    end

    orderTick = orderTick + 1
    if orderTick >= 10 then
        orderTick = 0
        local globals = {}
        for _, s in ipairs(standings()) do
            local g = global_of(s.localIndex)
            if g ~= nil then table.insert(globals, g) end
        end
        local text = encode_list(globals)
        if text ~= gGlobalSyncTable[K.ORDER_KEY] then OF.util.publish("ofRcOrder", text) end
    end

    if not clockFromTrack and not clockAsked then
        local want = racer.backstop_for(current_track())
        if want ~= nil then
            clockFromTrack = true
            OF.util.publish("ofGmLimit", want)
        end
    end

    local home = #OF.gamemodes.with_role(K.ROLE_HOME)
    local out = #still_out()
    if not finishTimer and home > 0 then
        finishTimer = true
        local want = math.floor(gGlobalSyncTable.ofGmElapsed or 0) + K.FINISH_SECONDS
        local limit = gGlobalSyncTable.ofGmLimit or 0
        if limit <= 0 or want < limit then OF.util.publish("ofGmLimit", want) end
    end
    if race_done(home, out) then end_race() end
end

function mode.on_timeout()
    end_race()
end

local function hear_the_race()
    local home = 0
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_HOME)) do
        if entry.localIndex ~= 0 then home = home + 1 end
    end
    if heardRace.home ~= nil and home > heardRace.home then OF.gamemodes.cue("chime") end
    heardRace.home = home
end

function mode.scenery()
    tidy_shells()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        hide_furniture()
        heardRace.home = nil
        return
    end
    hear_the_race()

    frame = frame + 1
    local t = current_track()
    if t ~= nil then
        update_boxes(t, count_racers() >= 9)
        update_coins(t)

        update_shots()
    end

end

local function damped_place()
    local list = standings()
    local now = nil
    for place, s in ipairs(list) do
        if s.localIndex == 0 then now = place end
    end
    if now == nil then return nil, #list end
    if now ~= heldPlace then
        heldPlace = now
        heldFor = 0
    else
        heldFor = heldFor + 1
    end
    if shownPlace == nil or heldFor >= 3 then shownPlace = now end
    return shownPlace, #list
end
racer.damped_place = damped_place

local function ordinal(n)
    local last = n % 10
    local teen = math.floor(n / 10) % 10 == 1
    if not teen and last == 1 then return n .. "st" end
    if not teen and last == 2 then return n .. "nd" end
    if not teen and last == 3 then return n .. "rd" end
    return n .. "th"
end
racer.ordinal = ordinal

local ITEM_SLOT_SCALE = 0.8

K.GATE_POST = 600
function racer.draw_gates(t, done)
    if t == nil or t.kind ~= "lap" or t.gates == nil or #t.gates == 0 then return 0 end
    local count, drawn = #t.gates, 0
    for k = 0, 1 do
        local g = t.gates[((done + k) % count) + 1]
        if g ~= nil then
            local half = g.w * 0.5
            local lx, lz = g.x + g.nz * half, g.z - g.nx * half
            local rx, rz = g.x - g.nz * half, g.z + g.nx * half
            local a = k == 0 and 230 or 110
            local y = g.y + 6
            OF.util.world_line({ x = lx, y = y, z = lz }, { x = rx, y = y, z = rz }, 4, 120, 255, 140, a)
            OF.util.world_line({ x = lx, y = y, z = lz }, { x = lx, y = y + K.GATE_POST, z = lz }, 4, 120, 255, 140, a)
            OF.util.world_line({ x = rx, y = y, z = rz }, { x = rx, y = y + K.GATE_POST, z = rz }, 4, 120, 255, 140, a)
            drawn = drawn + 1
        end
    end
    return drawn
end

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local role = OF.gamemodes.role(0)
    local t = current_track()
    if role == K.ROLE_RACE and t ~= nil and t.kind == "lap" then racer.draw_gates(t, mine.done) end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if role == K.ROLE_HOME then
        state("home", OF.lang.t("Home"), { prio = 50, tone = "good",
            figure = OF.gamemodes.clock(finish_time(0) or 0) })
    elseif role == K.ROLE_RACE and t ~= nil then
        if eff.carried > 0 then
            state("lakitu", OF.lang.t("Lakitu has you"), { prio = 60, tone = "mute" })
        elseif racer.wrong_way() then
            state("wrong", OF.lang.t("Wrong way"), { prio = 85, tone = "bad", urgent = true })
        end
        local icons = mode.race_icons(t)
        if icons ~= nil then state("race", nil, { prio = 20, icons = icons }) end
    else
        return
    end

    if role == K.ROLE_RACE then

        local held = nil
        if roulette > 0 then
            local key = K.ITEM_ORDER[(math.floor(roulette / 3) % #K.ITEM_ORDER) + 1]
            held = K.ITEMS[key].name
        elseif mine.item ~= "" and K.ITEMS[mine.item] ~= nil then
            held = K.ITEMS[mine.item].name
            if mine.count > 1 then held = held .. " x" .. mine.count end
        end
        local right = {}
        if held ~= nil then table.insert(right, held) end

        if #right > 0 then

            local said = table.concat(right, "   ")
            local size = ITEM_SLOT_SCALE
            local gr, gg, gb = OF.util.round_tone("gold")
            local w = OF.util.round_title_size(said, size)
            OF.util.round_title(said, screenWidth - w - 24, screenHeight * 0.12, size,
                gr, gg, gb, 255)
        end
    end

    local rows = mode.board()
    if #rows > 0 then
        if OF.util.asks(OF.gamemodes, "board_cap") then
            rows = OF.gamemodes.board_cap(rows, OF.gamemodes.SIDE_BOARD_ROWS or 4)
        end
        OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
            OF.lang.t("Race"), rows, { column = 130 })
    end
    racer.draw_boosts(t, gMarioStates[0])

    if t ~= nil and t.kind == "line" and t.goal ~= nil then
        local gr, gg, gb = OF.util.round_tone("gold")
        OF.util.zone_ring(t.goal, K.GOAL_RING, 40, 4, gr, gg, gb, 200)
    end
end

function mode.race_icons(t)
    local items = {}
    if t ~= nil and t.kind == "lap" then
        local lap = math.max(1, lap_of(mine.done, #t.gates))
        items[1] = { icon = "flag", tone = "ink",
            text = tostring(math.min(lap, laps_of(t))) .. "/" .. tostring(laps_of(t)) }
    end

    if coins_on() then items[#items + 1] = { icon = "coin", count = coins, tone = "target" } end
    if #items == 0 then return nil end
    return items
end

local function race_spot()
    local t = current_track()
    local at = OF.gamemodes.round_place()
    if t == nil or at == nil then return nil end
    local spot
    if t.kind == "line" and K.line.missed and not racer.line_clear(t) then

        local g = t.lineGates[K.line.next]
        spot = { x = g.x, y = g.y, z = g.z, level = at.level, area = at.area,
                 label = "the gate you missed" }
    elseif t.kind == "line" then
        spot = { x = t.goal.x, y = t.goal.y, z = t.goal.z, level = at.level,
                 area = at.area, label = "the flagpole" }
    else
        local g = t.gates[(mine.done % #t.gates) + 1]
        spot = { x = g.x, y = g.y, z = g.z, level = at.level, area = at.area,
                 label = "the next gate" }
    end
    if not OF.gamemodes.in_place_room(spot) then return nil end
    spot.r, spot.g, spot.b = 120, 255, 140
    return spot
end

local SHORT = { ["the gate you missed"] = "Missed gate", ["the flagpole"] = "Flagpole",
                ["the next gate"] = "Next gate" }
local raceTarget = { id = "race", tone = { 120, 255, 140 }, priority = 90,
    compass = "offscreen" }
local raceList = { raceTarget }
function mode.targets(viewer)
    local _ = viewer
    local spot = race_spot()
    if spot == nil then return nil end
    raceTarget.pos = spot
    raceTarget.label = SHORT[spot.label] or spot.label

    raceTarget.id = "race:" .. tostring(SHORT[spot.label] or "") .. ":"
        .. tostring(math.floor(spot.x)) .. ":" .. tostring(math.floor(spot.z))
    return raceList
end

OF.gamemodes.register(mode)
