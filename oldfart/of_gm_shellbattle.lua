OF = OF or {}

local K = {}

K.ROLE_RIDE = "riding"
K.ROLE_OUT = "out"
K.RULE_KEY = "ofSbRule"
K.PTS_KEY = "ofSbPts"
K.BOMBS_KEY = "ofSbBombs"
K.SHINE_KEY = "ofSbShine"
local ROW_KEY = "ofSbState"
local GRAB_KEY = "ofSbGrab"
K.ROW_KEY, K.GRAB_KEY = ROW_KEY, GRAB_KEY
K.PACKET_THROW = "ofSbThrow"
K.PACKET_BURST = "ofSbBurst"
K.DIGITS = "0123456789abcdefghijklmnopqrstuv"
K.SLOTS_MIN, K.SLOTS_MAX, K.SLOTS_PER_RIDER = 4, 14, 0.6

K.BLAST_SLOTS_MIN, K.BLAST_SLOTS_MAX, K.BLAST_SLOTS_PER_RIDER = 6, 22, 0.9

K.SLOTS_FLOOR, K.BLAST_SLOTS_FLOOR = 10, 14
K.SLOTS_CEILING, K.BLAST_SLOTS_CEILING = 20, 28
K.SLOT_AREA = 1500 * 1500
K.BACK_MIN, K.BACK_MAX = 60, 120

K.FRENZY_SECONDS = 30
K.FRENZY_BACK = 0.5
K.PICK_REACH = 150
K.SPOT_SCATTER = 300
K.SPOT_CLEAR = 800

K.POINTS_WANT = 28

K.STACK_BASE, K.STACK_STEP = 170, 80
K.STACK_LEAN, K.STACK_LEAN_MOST = 0.6, 60
K.STACK_DRAWN_MOST = 5

K.FLIGHT_FRAMES = 24
K.GRAVITY = 3
K.FIRE_GAP = 12
K.DIRECT_REACH = 90
K.FLIGHT_LIFE = 120
K.MINE_BACK = 180
K.MINE_ARM = 20
K.MINE_REACH = 120
K.MINE_LIFE = 900
K.MOVING_MOST = 32
K.BLAST = 350
K.TUMBLE_INSIDE = 150
K.BODY_TALL = 160
K.BOMB_JUMP_UP = 58
K.WARN_FALLING = 700
K.WARN_MINE = 400

K.INVINCIBLE = 100

K.LAKITU_FRAMES = 45
K.LAKITU_MANUAL = 30
K.LAKITU_DROP_SPEED = 24
K.EMPTY_WAIT = 60
K.FALL_BELOW = 1500
K.PUSH_OFF = 30
K.REMOUNT_FRAMES = 15
K.COMEBACK_BALLOONS = 3
K.CATCH_UP_BEHIND = 3

K.RAM_SPEED = 56
K.RAM_REACH = 120

K.SHINE_PER = 5
K.SHINE_MOST = 3
K.SHINE_REACH = 225
K.SHINE_OVER = 480
K.SHINE_BAR = 40
K.SHINE_DROP = 5
K.SHINE_FLOOR = 10
K.SHINE_POP = 15
K.SHINE_GRAVITY = 1.0
K.SHINE_BOUNCE = 0.55
K.SHINE_BOUNCES = 5
K.SHINE_REGRAB = 60

K.BALLOON_Y, K.BALLOON_R = 110, 70

K.BALLOON_SCALE = 0.9

K.HELD = { ["5"] = 5, ["3"] = 3, ["10"] = 10 }
K.THROW = { ["15"] = 1500, ["10"] = 1000, ["22"] = 2200 }
K.ROUND_SECONDS = { ["3"] = 180, ["2"] = 120, ["5"] = 300, first = 300 }

OF.gm_shellbattle = OF.gm_shellbattle or {}
local SB = OF.gm_shellbattle
SB.K = K

local function ride()
    return OF.shellride or {}
end
SB.ride = ride

local function on_the_ride(m)
    local r = ride()
    if m == nil or r.RIDE_GROUND == nil then return false end
    return m.action == r.RIDE_GROUND or m.action == r.RIDE_AIR or m.action == r.RIDE_HIT
end
SB.on_the_ride = on_the_ride

local function global_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return nil end
    return np.globalIndex
end

local function local_of(globalIndex)
    if globalIndex == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.np ~= nil and entry.np.globalIndex == globalIndex then
            return entry.localIndex
        end
    end
    return nil
end

local function mix(a, b, c)
    local h = ((a or 0) * 73856093 + (b or 0) * 19349663 + (c or 0) * 83492791) % 2147483648
    h = (h * 1103515245 + 12345) % 2147483648
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end
SB.mix = mix

local function digit(n)
    n = math.floor(n or 0) % 32
    return K.DIGITS:sub(n + 1, n + 1)
end

local function undigit(ch)
    local at = K.DIGITS:find(ch or "", 1, true)
    if at == nil then return nil end
    return at - 1
end

local function yaw_dir(yaw)
    local a = (yaw or 0) * math.pi / 0x8000
    return math.sin(a), math.cos(a)
end

local function floor_at(x, y, z)
    local h = OF.util.optional("find_floor_height", nil, x, y, z)
    if type(h) ~= "number" or h < -20000 then return nil end
    return h
end

local function option(key) return OF.gamemodes.option_now(key) end

local function game_is(which) return option("game") == which end

local function frame_now() return OF.util.optional("get_global_timer", 0) or 0 end

local function rule()
    local text = gGlobalSyncTable[K.RULE_KEY]
    local b, t, s, turn = 3, 0, K.SLOTS_MIN, 0
    if type(text) == "string" then
        local x, y, z, w = text:match("^(%d+) (%d+) (%d+) ?(%d*)$")
        b, t, s = tonumber(x) or b, tonumber(y) or t, tonumber(z) or s
        turn = tonumber(w) or 0
    end
    return { balloons = b, target = t, slots = s, turn = turn }
end
SB.rule = rule

function SB.dials(riders, balloonsChoice, roundChoice, game)
    riders = math.max(1, riders or 1)
    local balloons = riders > 8 and 5 or 3
    if balloonsChoice == "3" then balloons = 3 elseif balloonsChoice == "5" then balloons = 5 end
    local slots = OF.util.clamp(K.SLOTS_MIN + math.floor(K.SLOTS_PER_RIDER * riders + 0.5),
        K.SLOTS_MIN, K.SLOTS_MAX)
    slots = math.max(slots, K.SLOTS_FLOOR)
    if game == "blast" then
        slots = OF.util.clamp(K.BLAST_SLOTS_MIN
            + math.floor(K.BLAST_SLOTS_PER_RIDER * riders + 0.5),
            K.BLAST_SLOTS_MIN, K.BLAST_SLOTS_MAX)
        slots = math.max(slots, K.BLAST_SLOTS_FLOOR)
    end
    local target = 0
    if roundChoice == "first" then
        target = OF.util.clamp(3 + math.floor(riders / 2), 4, 10)
    end
    return balloons, target, slots
end

function SB.slots_for_map(slots, game, list)
    slots = slots or K.SLOTS_FLOOR
    local ceiling = game == "blast" and K.BLAST_SLOTS_CEILING or K.SLOTS_CEILING
    if type(list) ~= "table" or list[1] == nil then return math.min(slots, ceiling) end
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for _, p in ipairs(list) do
        minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
        minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
    end
    local byMap = math.floor((maxX - minX) * (maxZ - minZ) / K.SLOT_AREA)

    return math.min(math.max(slots, byMap), ceiling, #list)
end

local function held_most() return K.HELD[option("held") or "5"] or 5 end
local function throw_reach() return K.THROW[option("throw") or "15"] or 1500 end
local function last_standing() return option("empty") == "out" end

local function fresh_me()
    return {
        balloons = 0, stack = 0, hitBy = -1, hitSerial = 0, hitKind = "b",
        emptied = 0, landed = 0, shine = 0,
        carried = 0, waiting = 0, invUntil = -1, ready = false,

        shineLeft = 0, dropSerial = 0, dropX = 0, dropY = 0, dropZ = 0, dropHome = 0,

        spent = false,
    }
end
local me = fresh_me()
local written = nil
local lakituAt = nil
local frame = 0

local function flags()
    local f = ""
    if me.carried > 0 then f = f .. "l" end
    if me.waiting > 0 then f = f .. "w" end
    if me.invUntil > frame then f = f .. "i" end
    if me.spent then f = f .. "s" end
    return f
end

local function write_row()
    local text = table.concat({
        string.format("%.0f", me.balloons), string.format("%.0f", me.stack),
        string.format("%.0f", me.hitBy), string.format("%.0f", me.hitSerial),
        flags(), string.format("%.0f", me.emptied), string.format("%.0f", me.landed),
        string.format("%.0f", math.ceil(me.shineLeft / 30)), me.hitKind,
        string.format("%.0f", me.dropSerial), string.format("%.0f", me.dropX),
        string.format("%.0f", me.dropY), string.format("%.0f", me.dropZ),
        string.format("%.0f", me.dropHome),
    }, "|")
    if text == written then return end
    written = text
    OF.util.publish_row(0, ROW_KEY, text)
end
SB.write_row = write_row

local function parse_row(text)
    local out = { balloons = 0, stack = 0, hitBy = -1, hitSerial = 0, flags = "",
                  emptied = 0, landed = 0, shine = 0, hitKind = "b", dropSerial = 0,
                  dropX = 0, dropY = 0, dropZ = 0, dropHome = 0 }
    if type(text) ~= "string" or text == "" then return out end
    local f = {}
    for field in (text .. "|"):gmatch("([^|]*)|") do table.insert(f, field) end
    out.balloons = tonumber(f[1]) or 0
    out.stack = tonumber(f[2]) or 0
    out.hitBy = tonumber(f[3]) or -1
    out.hitSerial = tonumber(f[4]) or 0
    out.flags = f[5] or ""
    out.emptied = tonumber(f[6]) or 0
    out.landed = tonumber(f[7]) or 0
    out.shine = tonumber(f[8]) or 0
    out.hitKind = (f[9] ~= nil and f[9] ~= "") and f[9] or "b"
    out.dropSerial = tonumber(f[10]) or 0
    out.dropX = tonumber(f[11]) or 0
    out.dropY = tonumber(f[12]) or 0
    out.dropZ = tonumber(f[13]) or 0
    out.dropHome = tonumber(f[14]) or 0
    return out
end
SB.parse_row = parse_row

local mineRow = {}
local rowText, rowParsed = {}, {}

local function row_of(localIndex)
    if localIndex == 0 then
        local r = mineRow
        r.balloons, r.stack, r.hitBy = me.balloons, me.stack, me.hitBy
        r.hitSerial, r.flags, r.emptied = me.hitSerial, flags(), me.emptied
        r.landed, r.shine = me.landed, math.ceil(me.shineLeft / 30)
        r.hitKind, r.dropSerial, r.dropX = me.hitKind, me.dropSerial, me.dropX
        r.dropY, r.dropZ, r.dropHome = me.dropY, me.dropZ, me.dropHome
        return r
    end
    local row = gPlayerSyncTable[localIndex]
    local text = row ~= nil and row[K.ROW_KEY] or nil
    local kept = rowParsed[localIndex]
    if kept ~= nil and rowText[localIndex] == text then return kept end
    kept = parse_row(text)
    rowText[localIndex], rowParsed[localIndex] = text, kept
    return kept
end
SB.row_of = row_of

function SB.mine() return me end

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return tonumber(row ~= nil and row.ofScore or 0) or 0
end
SB.score_of = score_of

local function add_score(n)
    local now = math.max(0, score_of(0) + n)
    OF.util.publish_row(0, "ofScore", now)
end

local function forget_me()
    me = fresh_me()
    written = nil
    lakituAt = nil
end

local function riding_me()
    if OF.gamemodes.role(0) ~= K.ROLE_RIDE then return false end
    return OF.util.can_play(0)
end
SB.riding_me = riding_me

local function ghost_seat(index)
    if OF.gamemodes.role(index) ~= K.ROLE_OUT then return false end
    if OF.gamemodes.option_now("empty") ~= "out" then return false end
    local row = gPlayerSyncTable[index]
    local text = row ~= nil and row[K.ROW_KEY] or nil
    if index == 0 then return not me.spent end
    if type(text) ~= "string" then return false end
    local flagsField = text:match("^[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)") or ""
    return flagsField:find("s", 1, true) == nil
end
SB.ghost_seat = ghost_seat

local function ghost_me()
    return ghost_seat(0) and OF.util.can_play(0)
end
SB.ghost_me = ghost_me

local function riding(index)
    local np = gNetworkPlayers[index]
    if np == nil or not np.connected then return false end
    if OF.gamemodes.role(index) ~= K.ROLE_RIDE then return false end
    if not OF.util.can_play(index) then return false end
    return OF.gamemodes.in_place_room(OF.gamemodes.here_place(0), index)
end
SB.riding = riding

local function riders()
    return OF.gamemodes.with_role(K.ROLE_RIDE)
end

local function hittable()
    if not riding_me() then return false end
    if me.carried > 0 or me.waiting > 0 then return false end
    if me.invUntil > frame then return false end
    return true
end
SB.hittable = hittable

local pointsRaw, points = nil, nil

local function the_points()
    local text = gGlobalSyncTable[K.PTS_KEY]
    if type(text) ~= "string" or text == "" then
        pointsRaw, points = nil, nil
        return nil
    end
    if text == pointsRaw then return points end
    pointsRaw = text
    points = OF.gamemodes.unpack_points(text)
    if points[1] == nil then points = nil end
    return points
end
SB.points = the_points

local function middle(list)
    local x, z = 0, 0
    for _, p in ipairs(list) do x, z = x + p.x, z + p.z end
    return x / #list, z / #list
end

local function face_to(x, z, tx, tz)
    return atan2s ~= nil and atan2s(tz - z, tx - x) or 0
end

local function lowest(list)
    local y = nil
    for _, p in ipairs(list) do if y == nil or p.y < y then y = p.y end end
    return y
end

local host = { slots = {}, serial = 0, seenGrab = {}, laid = false, frenzySaid = false }

function SB.frenzy()
    local left = OF.gamemodes.time_left()
    return left ~= nil and left > 0 and left <= K.FRENZY_SECONDS
end

local groundText, groundRead = nil, nil

local function ground()
    local text = gGlobalSyncTable[K.BOMBS_KEY]
    if groundRead ~= nil and text == groundText then return groundRead end
    local out = {}
    groundText, groundRead = text, out
    if type(text) ~= "string" then return out end
    local slot = 0
    for at = 1, #text - 2, 3 do
        slot = slot + 1
        local chunk = text:sub(at, at + 2)
        if chunk == "---" then
            out[slot] = false
        else
            local p = undigit(chunk:sub(1, 1))
            local hi, lo = undigit(chunk:sub(2, 2)), undigit(chunk:sub(3, 3))
            if p ~= nil and hi ~= nil and lo ~= nil then
                out[slot] = { point = p + 1, serial = hi * 32 + lo }
            else
                out[slot] = false
            end
        end
    end
    return out
end
SB.ground = ground

local function pack_ground(slots)
    local parts = {}
    for i, s in ipairs(slots) do
        if s.away then
            parts[i] = "---"
        else
            local serial = s.serial % 1024
            parts[i] = digit(s.point - 1) .. digit(math.floor(serial / 32)) .. digit(serial % 32)
        end
    end
    return table.concat(parts)
end
SB.pack_ground = pack_ground

local spotCache = {}

local function spot_of(pointIndex, serial)
    local list = the_points()
    if list == nil then return nil end
    local p = list[pointIndex]
    if p == nil then return nil end

    if spotCache.of ~= pointsRaw then spotCache = { of = pointsRaw } end
    local perPoint = spotCache[pointIndex]
    if perPoint == nil then perPoint = {}; spotCache[pointIndex] = perPoint end
    local cached = perPoint[serial]
    if cached ~= nil then return cached end
    local h1 = mix(serial, pointIndex, 1)
    local h2 = mix(serial, pointIndex, 2)
    local dx = (h1 % 601) - K.SPOT_SCATTER
    local dz = (h2 % 601) - K.SPOT_SCATTER
    local x, z = p.x + dx, p.z + dz
    local y = floor_at(x, p.y + 400, z)
    if y == nil or math.abs(y - p.y) > 500 then
        x, z = p.x, p.z
        y = floor_at(x, p.y + 200, z) or p.y
    end
    local spot = { x = x, y = y, z = z }
    perPoint[serial] = spot
    return spot
end
SB.spot_of = spot_of
function SB.forget_spots() spotCache = {} end

local function pick_point(used)
    local list = the_points()
    if list == nil then return 1 end
    local best, bestGap, fair = nil, -1, {}
    for i, p in ipairs(list) do
        if not used[i] then
            local gap = math.huge
            for _, entry in ipairs(riders()) do
                local m = gMarioStates[entry.localIndex]
                if m ~= nil and m.pos ~= nil then
                    local dx, dz = m.pos.x - p.x, m.pos.z - p.z
                    gap = math.min(gap, dx * dx + dz * dz)
                end
            end
            if gap >= K.SPOT_CLEAR * K.SPOT_CLEAR then table.insert(fair, i) end
            if gap > bestGap then best, bestGap = i, gap end
        end
    end
    if #fair > 0 then return fair[math.random(1, #fair)] end
    return best or math.random(1, #list)
end

local function used_points(except)
    local used = {}
    for i, s in ipairs(host.slots) do
        if i ~= except and not s.away then used[s.point] = true end
    end
    return used
end

local function publish_ground()
    OF.util.publish(K.BOMBS_KEY, pack_ground(host.slots))
end

local function lay_ground(count)
    host.slots = {}
    host.serial = 0
    local list = the_points() or {}
    local reserve = math.min(#riders(), math.max(0, #list - count))
    for i = 1, count do
        host.serial = host.serial + 1
        host.slots[i] = { point = 1, serial = host.serial, away = false, backAt = 0 }
        local used = used_points(i)
        for p = 1, reserve do used[p] = true end
        host.slots[i].point = pick_point(used)
    end
    publish_ground()
end
SB.lay_ground = lay_ground

local function settle_grabs()
    local changed = false
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local v = row ~= nil and row[K.GRAB_KEY] or nil
        if type(v) == "string" and v ~= "" and v ~= host.seenGrab[entry.localIndex] then
            host.seenGrab[entry.localIndex] = v
            local _, slot, serial = v:match("^(%d+) (%d+) (%d+)$")
            slot, serial = tonumber(slot), tonumber(serial)
            local s = slot ~= nil and host.slots[slot] or nil
            if s ~= nil and not s.away and s.serial % 1024 == serial then
                s.away = true
                local wait = math.random(K.BACK_MIN, K.BACK_MAX)
                if SB.frenzy() then wait = math.floor(wait * K.FRENZY_BACK) end
                s.backAt = frame + wait
                changed = true
            end
        end
    end
    for i, s in ipairs(host.slots) do
        if s.away and frame >= s.backAt then
            host.serial = host.serial + 1
            s.serial = host.serial
            s.point = pick_point(used_points(i))
            s.away = false
            changed = true
        end
    end
    if changed then publish_ground() end
end
SB.settle_grabs = settle_grabs

local taken = {}
local grabSerial = 0

local function leader_score()
    local best = 0
    for _, entry in ipairs(riders()) do best = math.max(best, score_of(entry.localIndex)) end
    return best
end

local function seg_gap2(ax, ay, az, bx, by, bz, px, py, pz)
    local dx, dy, dz = bx - ax, by - ay, bz - az
    local len = dx * dx + dy * dy + dz * dz
    local t = 0
    if len > 0 then
        t = OF.util.clamp(((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / len, 0, 1)
    end
    local cx, cy, cz = ax + dx * t - px, ay + dy * t - py, az + dz * t - pz
    return cx * cx + cy * cy + cz * cz
end
SB.seg_gap2 = seg_gap2

local lastPos = nil

local function watch_pickups(m)
    if me.carried > 0 or me.waiting > 0 then return end
    local cap = held_most()
    if me.stack >= cap then return end
    local from = lastPos or { x = m.pos.x, y = m.pos.y, z = m.pos.z }

    local jx, jz = m.pos.x - from.x, m.pos.z - from.z
    if jx * jx + jz * jz > 400 * 400 then from = { x = m.pos.x, y = m.pos.y, z = m.pos.z } end
    for slot, b in ipairs(ground()) do
        if b and not taken[slot .. ":" .. b.serial] then
            local spot = spot_of(b.point, b.serial)
            if spot ~= nil and seg_gap2(from.x, from.y + 60, from.z,
                    m.pos.x, m.pos.y + 60, m.pos.z, spot.x, spot.y + 60, spot.z)
                    <= K.PICK_REACH * K.PICK_REACH then
                local gain = 1
                if option("catchup") ~= "off"
                    and leader_score() - score_of(0) >= K.CATCH_UP_BEHIND then
                    gain = 2
                end
                me.stack = math.min(cap, me.stack + gain)
                taken[slot .. ":" .. b.serial] = true
                grabSerial = grabSerial + 1
                OF.util.publish_row(0, GRAB_KEY, string.format("%.0f %.0f %.0f",
                    grabSerial, slot, b.serial % 1024))
                OF.gamemodes.cue("good", nil, "sbgrab")
                write_row()
                if me.stack >= cap then return end
            end
        end
    end
end
SB.watch_pickups = watch_pickups

K.BOBOMB_ANIMS = "bobomb_seg8_anims_0802396C"
K.LAKITU_ANIMS = "lakitu_enemy_seg5_anims_050144D4"
local function pose(o, animsName, rate)
    if o == nil then return end
    if o.oAnimations == nil then
        local anims = gObjectAnimations ~= nil and gObjectAnimations[animsName] or nil
        if anims == nil then return end
        o.oAnimations = anims
    end
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, rate or 1.0)
end

local function pose_bobomb(o, rate) pose(o, K.BOBOMB_ANIMS, rate) end
SB.pose_bobomb = pose_bobomb

local showAt = { x = 0, y = 0, z = 0 }

local function show(name, model, x, y, z, spin)
    showAt.x, showAt.y, showAt.z = x, y, z
    return OF.gamemodes.show_token(name, model, showAt, spin)
end

local function hide(name) OF.gamemodes.hide_token(name) end

local groundDrawn = {}

local function draw_ground()
    local list = ground()
    local t = frame_now()
    local wanted = {}
    for slot, b in ipairs(list) do
        if b and not taken[slot .. ":" .. b.serial] then
            local spot = spot_of(b.point, b.serial)
            if spot ~= nil then
                local name = "sbGround" .. slot
                local o = show(name, E_MODEL_BLACK_BOBOMB, spot.x,
                    spot.y + 20 + 10 * math.sin(t / 8 + slot), spot.z, 0x300)
                if o ~= nil then pose_bobomb(o, 0.5) end
                wanted[slot] = true
            end
        end
    end
    for slot in pairs(groundDrawn) do
        if not wanted[slot] then hide("sbGround" .. slot) end
    end
    groundDrawn = wanted
end

local flying = {}
local flyingCount = 0
local burstIds = {}
local throwSerial = 0
local sinceThrow = 99
local bangs = {}
local bangSerial = 0

local function fly_name(id) return "sbFly" .. id end

local function drop_flight(id)
    if flying[id] == nil then return end
    flying[id] = nil
    flyingCount = math.max(0, flyingCount - 1)
    hide(fly_name(id))
end

local function drop_all_flights()
    for id in pairs(flying) do hide(fly_name(id)) end
    flying = {}
    flyingCount = 0
end

local function launch(id, owner, kind, x, y, z, vx, vy, vz)
    if flying[id] ~= nil or burstIds[id] then return end

    if flyingCount >= K.MOVING_MOST then
        local oldest, at = nil, nil
        for other, f in pairs(flying) do
            if at == nil or f.born < at or (f.born == at and other < oldest) then
                oldest, at = other, f.born
            end
        end
        if oldest ~= nil then drop_flight(oldest) end
    end
    flying[id] = { owner = owner, kind = kind, x = x, y = y, z = z,
                   vx = vx, vy = vy, vz = vz, age = 0, born = frame }
    flyingCount = flyingCount + 1
end
SB.launch = launch
function SB.flying() return flying end

local function bang(x, y, z)
    bangSerial = bangSerial + 1
    local name = "sbBang" .. bangSerial
    local o = show(name, E_MODEL_EXPLOSION, x, y, z, nil)
    if o ~= nil then
        OF.util.optional("obj_set_billboard", nil, o)
        o.oAnimState = 0
        OF.util.optional("obj_scale", nil, o, 1.5)
    end
    table.insert(bangs, { name = name, age = 0, x = x, y = y, z = z })
    OF.gamemodes.round_sound_throttled("sbboom", 2, SOUND_GENERAL2_BOBOMB_EXPLOSION, o)
end

local function step_bangs()
    for at = #bangs, 1, -1 do
        local b = bangs[at]
        b.age = b.age + 1
        if b.age >= 9 then
            hide(b.name)
            table.remove(bangs, at)
        else
            local o = OF.gamemodes.tokens[b.name]
            if o ~= nil then
                o.oAnimState = b.age
                OF.util.optional("obj_scale", nil, o, 1.5 + b.age / 6)
            end
        end
    end
end

local function drop_bangs()
    for _, b in ipairs(bangs) do hide(b.name) end
    bangs = {}
end

local function body_gap(m, x, y, z)
    local cy = OF.util.clamp(y, m.pos.y, m.pos.y + K.BODY_TALL)
    local dx, dy, dz = m.pos.x - x, cy - y, m.pos.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
SB.body_gap = body_gap

local be_hit
local drop_shine

local function burst(id, x, y, z)
    if burstIds[id] then return false end
    burstIds[id] = true
    local f = flying[id]
    local owner = f ~= nil and f.owner or math.floor(id / 10000)
    drop_flight(id)
    bang(x, y, z)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil or not riding_me() then return true end
    local gap = body_gap(m, x, y, z)
    if gap > K.BLAST then return true end
    if owner == global_of(0) then
        if option("own") ~= "harmless" and me.carried == 0 and me.waiting == 0
            and on_the_ride(m) then
            local r = ride()
            m.vel.y = K.BOMB_JUMP_UP
            if r.RIDE_AIR ~= nil then set_mario_action(m, r.RIDE_AIR, 0) end
            m.vel.y = K.BOMB_JUMP_UP
        end
        return true
    end
    be_hit(m, owner, gap <= K.TUMBLE_INSIDE)
    return true
end
SB.burst = burst

K.HEARD_BURST_SLACK = 600
function SB.hear_burst(data)
    local id = tonumber(data.id)
    if id == nil then return false end
    local f = flying[id]
    if f == nil then return false end
    local x, y, z = tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0
    local dx, dy, dz = x - f.x, y - f.y, z - f.z
    if dx * dx + dy * dy + dz * dz > K.HEARD_BURST_SLACK * K.HEARD_BURST_SLACK then
        return false
    end
    return burst(id, x, y, z)
end

local function burst_here(id, x, y, z)
    if burst(id, x, y, z) then
        OF.util.send_all({ ofp = K.PACKET_BURST, id = id, x = x, y = y, z = z })
    end
end

local function ray(x, y, z, dx, dy, dz)
    if collision_find_surface_on_ray == nil then return nil end
    local info = collision_find_surface_on_ray(x, y, z, dx, dy, dz)
    if info == nil or info.surface == nil or info.hitPos == nil then return nil end
    return info.hitPos.x, info.hitPos.y, info.hitPos.z
end

function SB.warn(f, m, mine, canHit)
    if f.warned or not canHit or f.owner == mine or m == nil or m.pos == nil then
        return false
    end
    local dx, dz = m.pos.x - f.x, m.pos.z - f.z
    local reach
    if f.kind == 2 then
        if f.age < K.MINE_ARM then return false end
        reach = K.WARN_MINE
    else
        if f.vy >= 0 then return false end
        reach = K.WARN_FALLING
    end
    if dx * dx + dz * dz > reach * reach then return false end
    f.warned = true
    OF.gamemodes.cue("hazard", nil, "sbincoming")
    return true
end

local function step_flights()
    local m = gMarioStates[0]
    local mine = global_of(0)
    local canHit = m ~= nil and m.pos ~= nil and hittable()
    for id, f in pairs(flying) do
        f.age = f.age + 1
        SB.warn(f, m, mine, canHit)
        if f.kind == 2 then
            if f.age == 1 then f.y = floor_at(f.x, f.y + 200, f.z) or f.y end
            if f.age > K.MINE_LIFE then
                drop_flight(id)
            elseif canHit and f.owner ~= mine and f.age >= K.MINE_ARM
                and body_gap(m, f.x, f.y, f.z) <= K.MINE_REACH then
                burst_here(id, f.x, f.y, f.z)
            end
        else
            local nx, ny, nz = f.x + f.vx, f.y + f.vy, f.z + f.vz
            local hx, hy, hz = ray(f.x, f.y, f.z, f.vx, f.vy, f.vz)
            if canHit and f.owner ~= mine
                and seg_gap2(f.x, f.y, f.z, nx, ny, nz, m.pos.x,
                    OF.util.clamp(f.y, m.pos.y, m.pos.y + K.BODY_TALL), m.pos.z)
                    <= K.DIRECT_REACH * K.DIRECT_REACH then
                burst_here(id, m.pos.x, m.pos.y + 80, m.pos.z)
            elseif hx ~= nil then
                burst(id, hx, hy, hz)
            else
                local fy = floor_at(nx, ny + 100, nz)
                if fy ~= nil and ny <= fy and f.vy < 0 then
                    burst(id, nx, fy, nz)
                elseif f.age > K.FLIGHT_LIFE then
                    drop_flight(id)
                else
                    f.x, f.y, f.z = nx, ny, nz
                    f.vy = f.vy - K.GRAVITY
                end
            end
        end
        local live = flying[id]
        if live ~= nil then
            local o = show(fly_name(id), E_MODEL_BLACK_BOBOMB, live.x, live.y, live.z,
                live.kind == 2 and 0x200 or 0x1800)
            if o ~= nil then
                local armed = live.kind ~= 2 or live.age >= K.MINE_ARM
                pose_bobomb(o, armed and 3.0 or 0.4)

                local scale = 1.0
                if live.kind == 2 and armed and math.floor(live.age / 4) % 2 == 0 then scale = 1.2 end
                OF.util.optional("obj_scale", nil, o, scale)
            end
        end
    end
end
SB.step_flights = step_flights

local function throw(m)
    if me.stack <= 0 or sinceThrow < K.FIRE_GAP then return false end
    if me.carried > 0 or me.waiting > 0 then return false end
    local mine = global_of(0)
    if mine == nil then return false end
    local back = m.controller ~= nil and (m.controller.stickY or 0) < -40
    local sx, sz = yaw_dir(m.faceAngle.y)
    throwSerial = throwSerial + 1
    local id = mine * 10000 + (throwSerial % 10000)
    local x, y, z, vx, vy, vz, kind
    if back then
        kind = 2
        x, y, z = m.pos.x - sx * K.MINE_BACK, m.pos.y, m.pos.z - sz * K.MINE_BACK
        vx, vy, vz = 0, 0, 0
    else
        kind = 1
        local lift = K.STACK_BASE + K.STACK_STEP * (math.min(me.stack, K.STACK_DRAWN_MOST) - 1)
        x, y, z = m.pos.x, m.pos.y + lift, m.pos.z
        local push = throw_reach() / K.FLIGHT_FRAMES
        vx = sx * push + (m.vel.x or 0)
        vz = sz * push + (m.vel.z or 0)

        vy = (0.5 * K.GRAVITY * K.FLIGHT_FRAMES * K.FLIGHT_FRAMES - lift) / K.FLIGHT_FRAMES
    end
    me.stack = me.stack - 1
    sinceThrow = 0
    write_row()
    launch(id, mine, kind, x, y, z, vx, vy, vz)
    OF.util.send_all({ ofp = K.PACKET_THROW, id = id, k = kind,
        x = x, y = y, z = z, vx = vx, vy = vy, vz = vz })
    OF.gamemodes.round_sound_throttled("sbthrow", 4, SOUND_ACTION_THROW, nil)
    return true
end
SB.throw = throw

local function call_lakitu(extra)
    if me.carried > 0 then return false end
    local list = the_points()
    if list == nil then return false end

    local best, bestGap = nil, -1
    for _, p in ipairs(list) do
        local gap = math.huge
        for _, entry in ipairs(riders()) do
            if entry.localIndex ~= 0 then
                local o = gMarioStates[entry.localIndex]
                if o ~= nil and o.pos ~= nil then
                    local dx, dz = o.pos.x - p.x, o.pos.z - p.z
                    gap = math.min(gap, dx * dx + dz * dz)
                end
            end
        end
        if gap > bestGap then best, bestGap = p, gap end
    end
    if best == nil then return false end
    local cx, cz = middle(list)
    lakituAt = { x = best.x, y = best.y + 60, z = best.z, yaw = face_to(best.x, best.z, cx, cz) }
    me.carried = K.LAKITU_FRAMES + (extra or 0)
    write_row()
    return true
end
SB.call_lakitu = call_lakitu

local function carry(m)
    if lakituAt == nil then me.carried = 0 return end
    m.pos.x, m.pos.y, m.pos.z = lakituAt.x, lakituAt.y, lakituAt.z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.faceAngle.y = lakituAt.yaw or 0
    if m.marioObj ~= nil then
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ = m.pos.x, m.pos.y, m.pos.z
        m.marioObj.oMoveAngleYaw = m.faceAngle.y
    end
    OF.input.freeze(m)
    if me.carried <= 1 then
        local r = ride()
        if r.RIDE_AIR ~= nil then
            mario_set_forward_vel(m, K.LAKITU_DROP_SPEED)
            set_mario_action(m, r.RIDE_AIR, 0)
        end
        lakituAt = nil
        OF.util.camera_behind_soon()
    end
end

local function emptied()
    me.emptied = me.emptied + 1
    if last_standing() then
        me.balloons = 0
        write_row()
        OF.gamemodes.set_role(0, K.ROLE_OUT)
        return
    end
    add_score(-math.ceil(score_of(0) / 2))
    me.waiting = K.EMPTY_WAIT
    write_row()

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("out", OF.lang.t("NO BALLOONS"), OF.lang.t("Half your points"))
    end
end
SB.emptied = emptied

local function lose_balloon(by, kind)
    me.balloons = math.max(0, me.balloons - 1)
    if by ~= nil then
        me.hitBy = by
        me.hitSerial = me.hitSerial + 1
        me.hitKind = kind or "b"
    end
    me.invUntil = frame + K.INVINCIBLE
    local m = gMarioStates[0]
    if m ~= nil then m.invincTimer = K.INVINCIBLE end
    if me.balloons <= 0 then emptied() else write_row() end
end
SB.lose_balloon = lose_balloon

function SB.fell(m)
    if game_is("shine") then
        drop_shine(m, true)
        call_lakitu(0)
        return
    end
    if ghost_me() then
        call_lakitu(0)
        return
    end
    lose_balloon(nil)
    if me.waiting == 0 and riding_me() then call_lakitu(0) end
end

be_hit = function(m, byGlobal, close, kind)
    if not hittable() then return false end
    local r = ride()
    if r.RIDE_HIT ~= nil and on_the_ride(m) then
        set_mario_action(m, r.RIDE_HIT, close and (r.HIT_TUMBLE or 2) or (r.HIT_SPIN or 1))
    end
    OF.gamemodes.cue("bad")
    if game_is("shine") then
        me.invUntil = frame + K.INVINCIBLE
        m.invincTimer = K.INVINCIBLE
        if drop_shine ~= nil then drop_shine(m, false) end
        write_row()
        return true
    end
    lose_balloon(byGlobal, kind)
    return true
end
SB.be_hit = be_hit

local seenHit = {}
local rowsRead = false

local function mark_rows_read()
    for _, entry in ipairs(OF.util.connected_players()) do
        local r = row_of(entry.localIndex)
        seenHit[entry.localIndex] = r.hitSerial
    end
    rowsRead = true
end

local function watch_hits()
    if not rowsRead then mark_rows_read() end
    local mine = global_of(0)
    if mine == nil then return end
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        if i ~= 0 then
            local r = row_of(i)
            if r.hitSerial ~= (seenHit[i] or 0) then
                seenHit[i] = r.hitSerial
                if r.hitBy == mine and not game_is("shine") then
                    add_score(1)
                    me.landed = me.landed + 1

                    if r.hitKind == "r" and riding_me() and me.waiting == 0 then
                        me.balloons = math.min(rule().balloons, me.balloons + 1)
                    end

                    if r.hitKind == "g" and ghost_seat(0) then me.spent = true end
                    write_row()
                    OF.gamemodes.cue("good", nil, "sbhit")
                end
            end
        end
    end
end
SB.watch_hits = watch_hits

local function ram(m)
    if not game_is("balloon") or not hittable() then return false end
    local myX, myZ = yaw_dir(m.faceAngle.y)
    local mineFast = (m.forwardVel or 0) >= K.RAM_SPEED
    for _, entry in ipairs(riders()) do
        local i = entry.localIndex
        local o = gMarioStates[i]
        if i ~= 0 and o ~= nil and o.pos ~= nil and on_the_ride(o)
            and (o.forwardVel or 0) >= K.RAM_SPEED then
            local r = row_of(i)
            local busy = r.flags:find("l", 1, true) or r.flags:find("w", 1, true)
            local dx, dz = m.pos.x - o.pos.x, m.pos.z - o.pos.z
            if not busy and dx * dx + dz * dz <= K.RAM_REACH * K.RAM_REACH
                and math.abs(m.pos.y - o.pos.y) <= 150 then
                local ax, az = yaw_dir(o.faceAngle.y)
                local toward = ax * dx + az * dz > 0
                local headOn = mineFast and ax * myX + az * myZ < -0.5
                if toward and not headOn then
                    return be_hit(m, global_of(i), false, "r")
                end
            end
        end
    end
    return false
end
SB.ram = ram

local function ghost_touch(m)
    if not hittable() then return false end
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_OUT)) do
        local i = entry.localIndex
        local o = gMarioStates[i]
        if i ~= 0 and ghost_seat(i) and o ~= nil and o.pos ~= nil then
            local dx, dz = m.pos.x - o.pos.x, m.pos.z - o.pos.z
            if dx * dx + dz * dz <= K.RAM_REACH * K.RAM_REACH
                and math.abs(m.pos.y - o.pos.y) <= 150 then
                return be_hit(m, global_of(i), true, "g")
            end
        end
    end
    return false
end
SB.ghost_touch = ghost_touch

local shineRaw, shineParsed = nil, nil

local function shines()
    local text = gGlobalSyncTable[K.SHINE_KEY]
    if type(text) ~= "string" or text == "" then
        shineRaw, shineParsed = nil, nil
        return nil
    end
    if text == shineRaw then return shineParsed end
    local out = { bar = K.SHINE_BAR, list = {} }
    local first = true
    for part in (text .. ";"):gmatch("([^;]*);") do
        if first then
            out.bar = tonumber(part) or K.SHINE_BAR
            first = false
        else
            local f = {}
            for field in (part .. ","):gmatch("([^,]*),") do table.insert(f, field) end
            if f[1] == "h" then
                table.insert(out.list, { holder = tonumber(f[2]), serial = tonumber(f[3]) or 0 })
            elseif f[1] == "l" then
                table.insert(out.list, { x = tonumber(f[2]) or 0, y = tonumber(f[3]) or 0,
                    z = tonumber(f[4]) or 0, serial = tonumber(f[5]) or 0 })
            end
        end
    end
    shineRaw, shineParsed = text, out
    return out
end
SB.shines = shines

local function pack_shines(bar, list)
    local parts = { string.format("%.0f", bar) }
    for _, sh in ipairs(list) do
        if sh.holder ~= nil then
            table.insert(parts, string.format("h,%.0f,%.0f", sh.holder, sh.serial))
        else
            table.insert(parts, string.format("l,%.0f,%.0f,%.0f,%.0f", sh.x, sh.y, sh.z, sh.serial))
        end
    end
    return table.concat(parts, ";")
end
SB.pack_shines = pack_shines

function SB.shine_count(riderCount)
    return OF.util.clamp(math.ceil(math.max(1, riderCount or 1) / K.SHINE_PER), 1, K.SHINE_MOST)
end

local function my_shine()
    local st = shines()
    local mine = global_of(0)
    if st == nil or mine == nil then return nil end
    for i, sh in ipairs(st.list) do
        if sh.holder == mine then return i end
    end
    return nil
end
SB.my_shine = my_shine

local hostShine = { list = {}, bar = K.SHINE_BAR, start = {}, seenDrop = {},
                    dropper = {}, dropAt = {}, seenTake = {}, serial = 0 }

function SB.pin_shines()
    if not game_is("shine") then
        OF.util.publish(K.SHINE_KEY, nil)
        return
    end
    local list = the_points()
    if list == nil then return end
    local cx, cz = middle(list)
    local count = SB.shine_count(#riders())
    local reserve = math.min(#riders(), math.max(0, #list - count))
    local order = {}
    for i, p in ipairs(list) do
        if i > reserve then
            table.insert(order, { i = i, gap = (p.x - cx) ^ 2 + (p.z - cz) ^ 2 })
        end
    end
    if #order == 0 then
        for i, p in ipairs(list) do
            table.insert(order, { i = i, gap = (p.x - cx) ^ 2 + (p.z - cz) ^ 2 })
        end
    end
    table.sort(order, function(a, b)
        if a.gap ~= b.gap then return a.gap < b.gap end
        return a.i < b.i
    end)
    hostShine = { list = {}, bar = K.SHINE_BAR, start = {}, seenDrop = {},
                  dropper = {}, dropAt = {}, seenTake = {}, serial = 0 }
    for n = 1, count do
        local p = list[order[((n - 1) % #order) + 1].i]
        hostShine.serial = hostShine.serial + 1
        hostShine.start[n] = { x = p.x, y = p.y + 60, z = p.z }
        hostShine.list[n] = { x = p.x, y = p.y + 60, z = p.z, serial = hostShine.serial }
    end
    for _, entry in ipairs(OF.util.connected_players()) do
        local r = row_of(entry.localIndex)
        hostShine.seenDrop[entry.localIndex] = r.dropSerial
        local row = gPlayerSyncTable[entry.localIndex]
        hostShine.seenTake[entry.localIndex] = row ~= nil and row[K.GRAB_KEY] or nil
    end
    OF.util.publish(K.SHINE_KEY, pack_shines(hostShine.bar, hostShine.list))
end

function SB.start_shine()
    me.shineLeft = K.SHINE_BAR * 30
    shineRaw, shineParsed = nil, nil
end

function SB.host_shine()
    if not game_is("shine") then return false end
    if #hostShine.list == 0 then return false end
    local changed = false
    local function holder_seat(g) return local_of(g) end

    for n, sh in ipairs(hostShine.list) do
        if sh.holder ~= nil then
            local seat = holder_seat(sh.holder)
            local r = seat ~= nil and row_of(seat) or nil
            local gone = seat == nil or OF.gamemodes.role(seat) ~= K.ROLE_RIDE
            if r ~= nil and r.dropSerial ~= (hostShine.seenDrop[seat] or 0) then
                hostShine.seenDrop[seat] = r.dropSerial
                hostShine.serial = hostShine.serial + 1
                local at = (r.dropHome == 1) and hostShine.start[n]
                    or { x = r.dropX, y = r.dropY, z = r.dropZ }
                hostShine.list[n] = { x = at.x, y = at.y, z = at.z, serial = hostShine.serial }
                hostShine.dropper[n] = sh.holder
                hostShine.dropAt[n] = frame
                hostShine.bar = math.max(K.SHINE_FLOOR, hostShine.bar - K.SHINE_DROP)
                changed = true
            elseif gone then
                hostShine.serial = hostShine.serial + 1
                local at = hostShine.start[n]
                local o = seat ~= nil and gMarioStates[seat] or nil
                if o ~= nil and o.pos ~= nil then at = { x = o.pos.x, y = o.pos.y + 60, z = o.pos.z } end
                hostShine.list[n] = { x = at.x, y = at.y, z = at.z, serial = hostShine.serial }
                hostShine.dropper[n] = nil
                changed = true
            end
        end
    end

    for _, entry in ipairs(OF.util.connected_players()) do
        local seat = entry.localIndex
        local row = gPlayerSyncTable[seat]
        local v = row ~= nil and row[K.GRAB_KEY] or nil
        if type(v) == "string" and v:sub(1, 1) == "s" and v ~= hostShine.seenTake[seat] then
            hostShine.seenTake[seat] = v
            local _, n, serial = v:match("^s (%d+) (%d+) (%d+)$")
            n, serial = tonumber(n), tonumber(serial)
            local sh = n ~= nil and hostShine.list[n] or nil
            local g = global_of(seat)
            local locked = hostShine.dropper[n] == g
                and frame - (hostShine.dropAt[n] or -999) < K.SHINE_REGRAB
            local holdsOne = false
            for _, other in ipairs(hostShine.list) do
                if other.holder == g then holdsOne = true end
            end
            if sh ~= nil and sh.holder == nil and sh.serial == serial and g ~= nil
                and not locked and not holdsOne
                and OF.gamemodes.role(seat) == K.ROLE_RIDE then
                hostShine.serial = hostShine.serial + 1
                hostShine.list[n] = { holder = g, serial = hostShine.serial }
                changed = true
            end
        end
    end
    if changed then OF.util.publish(K.SHINE_KEY, pack_shines(hostShine.bar, hostShine.list)) end

    for _, sh in ipairs(hostShine.list) do
        if sh.holder ~= nil then
            local seat = holder_seat(sh.holder)
            if seat ~= nil and row_of(seat).shine <= 0 and row_of(seat).flags ~= nil
                and gPlayerSyncTable[seat][K.ROW_KEY] ~= nil then
                local name = gNetworkPlayers[seat].name
                OF.gamemodes.finish("@ won holding the Shine to the end.", name, name)
                return true
            end
        end
    end
    return false
end

local askedShine = {}
local shineGrabSerial = 0

function SB.touch_shine(m)
    if not game_is("shine") then return false end
    if me.invUntil > frame or my_shine() ~= nil then return false end
    local st = shines()
    if st == nil then return false end
    for n, sh in ipairs(st.list) do
        if sh.holder == nil and not askedShine[n .. ":" .. sh.serial] then
            local y = SB.shine_y(n, sh)
            local dx, dy, dz = m.pos.x - sh.x, (m.pos.y + 80) - y, m.pos.z - sh.z
            if dx * dx + dy * dy + dz * dz <= K.SHINE_REACH * K.SHINE_REACH then
                askedShine[n .. ":" .. sh.serial] = true
                shineGrabSerial = shineGrabSerial + 1
                OF.util.publish_row(0, GRAB_KEY, string.format("s %.0f %.0f %.0f",
                    shineGrabSerial, n, sh.serial))
                return true
            end
        end
    end
    return false
end

local heldBefore = nil

function SB.tick_shine()
    if not game_is("shine") then return end
    local st = shines()
    local held = my_shine()
    if held ~= nil and heldBefore == nil and st ~= nil then
        local bar = st.bar * 30
        if option("shinecount") == "reset" then
            me.shineLeft = bar
        else
            me.shineLeft = math.min(me.shineLeft, bar)
        end
        OF.gamemodes.cue("good", nil, "sbshine")
    end
    heldBefore = held
    if held ~= nil then
        local before = math.ceil(me.shineLeft / 30)
        me.shineLeft = math.max(0, me.shineLeft - 1)
        if math.ceil(me.shineLeft / 30) ~= before then write_row() end
    end
end

drop_shine = function(m, home)
    if my_shine() == nil then return false end
    me.dropSerial = me.dropSerial + 1
    me.dropX, me.dropY, me.dropZ = m.pos.x, m.pos.y + 100, m.pos.z
    me.dropHome = home and 1 or 0
    write_row()
    return true
end
SB.drop_shine = drop_shine

local shineSeen = {}

function SB.shine_y(n, sh)
    local key = n .. ":" .. sh.serial
    local seen = shineSeen[key]
    if seen == nil then
        local floorY = floor_at(sh.x, sh.y + 100, sh.z) or (sh.y - 60)
        seen = { at = frame, y = sh.y, vy = K.SHINE_POP, bounces = 0, floor = floorY + 60 }
        shineSeen[key] = seen
    end

    while (seen.stepped or seen.at) < frame and seen.bounces < K.SHINE_BOUNCES do
        seen.stepped = (seen.stepped or seen.at) + 1
        seen.y = seen.y + seen.vy
        seen.vy = seen.vy - K.SHINE_GRAVITY
        if seen.y <= seen.floor and seen.vy < 0 then
            seen.y = seen.floor
            seen.vy = -seen.vy * K.SHINE_BOUNCE
            seen.bounces = seen.bounces + 1
            if seen.vy < 2 then seen.bounces = K.SHINE_BOUNCES end
        end
    end
    if seen.bounces >= K.SHINE_BOUNCES then seen.y = seen.floor end
    return seen.y
end

local shineDrawn = {}
local springs = {}

function SB.shine_scenery()
    local st = shines()
    local wanted = {}
    if st ~= nil then
        for n, sh in ipairs(st.list) do
            local name = "sbShine" .. n
            local x, y, z
            if sh.holder ~= nil then
                local seat = local_of(sh.holder)
                local o = seat ~= nil and gMarioStates[seat] or nil
                if o ~= nil and o.pos ~= nil and OF.gamemodes.in_place_room(
                        OF.gamemodes.here_place(0), seat) then
                    local stack = math.min(row_of(seat).stack, K.STACK_DRAWN_MOST)
                    local over = math.max(K.SHINE_OVER, K.STACK_BASE + K.STACK_STEP * stack + 60)
                    local want = { x = o.pos.x, y = o.pos.y + over, z = o.pos.z }
                    local sp = springs[n]
                    if sp == nil or sp.holder ~= sh.holder then
                        sp = { x = want.x, y = want.y, z = want.z, holder = sh.holder }
                        springs[n] = sp
                    end
                    sp.x = sp.x + (want.x - sp.x) * 0.35
                    sp.y = sp.y + (want.y - sp.y) * 0.35
                    sp.z = sp.z + (want.z - sp.z) * 0.35
                    x, y, z = sp.x, sp.y, sp.z
                end
            else
                springs[n] = nil
                x, y, z = sh.x, SB.shine_y(n, sh), sh.z
            end
            if x ~= nil then
                local o = show(name, E_MODEL_STAR, x, y, z, 0x800)
                if o ~= nil then OF.util.optional("obj_scale", nil, o, 1.0) end
                wanted[n] = true
            end
        end
    end
    for n in pairs(shineDrawn) do
        if not wanted[n] then hide("sbShine" .. n) end
    end
    shineDrawn = wanted
end

function SB.shine_left_text(localIndex)
    local r = row_of(localIndex)
    local held = false
    local st = shines()
    local g = global_of(localIndex)
    for _, sh in ipairs(st ~= nil and st.list or {}) do
        if sh.holder ~= nil and sh.holder == g then held = true end
    end
    return (held and "* " or "") .. OF.lang.fill("@s", tostring(r.shine))
end

function SB.shine_timeout()
    local list = riders()
    local best, names = OF.gamemodes.best_of(list,
        function(entry) return row_of(entry.localIndex).shine end, true)
    if best == nil then
        OF.gamemodes.finish("Nobody was left riding.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @s to go.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won - closest, @s to go.", names[1], names[1], tostring(best))
    end
end

function SB.cleanup_shine()
    for n in pairs(shineDrawn) do hide("sbShine" .. n) end
    shineDrawn = {}
    springs = {}
    shineSeen = {}
    askedShine = {}
    heldBefore = nil
    shineRaw, shineParsed = nil, nil
    hostShine = { list = {}, bar = K.SHINE_BAR, start = {}, seenDrop = {},
                  dropper = {}, dropAt = {}, seenTake = {}, serial = 0 }
end

local function draw_rider(index, m)
    local r = row_of(index)
    local o = m.marioObj
    local yaw = (o ~= nil and o.oMoveAngleYaw) or m.faceAngle.y or 0
    local carried = r.flags:find("l", 1, true) ~= nil
    local waiting = r.flags:find("w", 1, true) ~= nil
    local shell = show("sbShell" .. index, E_MODEL_KOOPA_SHELL, m.pos.x, m.pos.y, m.pos.z, nil)

    if shell ~= nil and OF.util.asks(OF.shellride, "place_shell") then
        OF.shellride.place_shell(shell, m)
    elseif shell ~= nil then
        shell.oFaceAngleYaw = yaw
    end

    local t = frame_now()
    local count = waiting and 0 or math.min(r.balloons, 5)
    for k = 1, 5 do
        local name = "sbBal" .. index .. "_" .. k
        if k <= count then
            local a = (t * 0x180 + k * 0x10000 / math.max(count, 1)) % 0x10000
            local sx, sz = yaw_dir(a)

            OF.ball.balloon_draw(name, { x = m.pos.x + sx * K.BALLOON_R,
                y = m.pos.y + K.BALLOON_Y + 8 * math.sin(t / 6 + k),
                z = m.pos.z + sz * K.BALLOON_R }, OF.ball.balloon_colour(index),
                { scale = K.BALLOON_SCALE, standInScale = 1.6 })
        else
            OF.ball.balloon_hide(name)
        end
    end

    local fx, fz = yaw_dir(yaw)
    local lean = math.min(K.STACK_LEAN_MOST, K.STACK_LEAN * math.max(0, m.forwardVel or 0))
    local drawn = math.min(r.stack, K.STACK_DRAWN_MOST)
    for k = 1, K.STACK_DRAWN_MOST do
        local name = "sbStack" .. index .. "_" .. k
        if k <= drawn then
            local share = k / K.STACK_DRAWN_MOST
            local b = show(name, E_MODEL_BLACK_BOBOMB, m.pos.x - fx * lean * share,
                m.pos.y + K.STACK_BASE + K.STACK_STEP * (k - 1), m.pos.z - fz * lean * share, nil)
            if b ~= nil then
                b.oFaceAngleYaw = yaw
                pose_bobomb(b, 0.4)
            end
        else
            hide(name)
        end
    end

    if carried then
        local lakitu = show("sbAbove" .. index, E_MODEL_ENEMY_LAKITU, m.pos.x, m.pos.y + 260,
            m.pos.z, 0x400)
        pose(lakitu, K.LAKITU_ANIMS, 1.0)
    else
        hide("sbAbove" .. index)
    end
end
SB.draw_rider = draw_rider

local function hide_rider(index, keepShell)
    if not keepShell then hide("sbShell" .. index) end
    if not riding(index) and not ghost_seat(index) then hide("sbGhost" .. index) end
    hide("sbAbove" .. index)
    for k = 1, 5 do OF.ball.balloon_hide("sbBal" .. index .. "_" .. k) end
    for k = 1, K.STACK_DRAWN_MOST do hide("sbStack" .. index .. "_" .. k) end
end
SB.hide_rider = hide_rider

local function round_live()
    local cur = OF.gamemodes.current()
    return cur ~= nil and cur.key == "shellbattle"
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
end
SB.round_live = round_live

local function draw_ghost(index, m)
    local o = m.marioObj
    if o ~= nil and o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node ~= nil then
        local node = o.header.gfx.node
        node.flags = OF.util.add_flag(node.flags, GRAPH_RENDER_INVISIBLE)
    end
    local yaw = (o ~= nil and o.oMoveAngleYaw) or m.faceAngle.y or 0
    local shell = show("sbShell" .. index, E_MODEL_KOOPA_SHELL, m.pos.x, m.pos.y, m.pos.z, nil)
    if shell ~= nil then shell.oFaceAngleYaw = yaw end
    local b = show("sbGhost" .. index, E_MODEL_BLACK_BOBOMB, m.pos.x, m.pos.y + 30, m.pos.z, nil)
    if b ~= nil then
        b.oFaceAngleYaw = yaw
        pose_bobomb(b, 2.0)
        OF.util.optional("obj_scale", nil, b, 1.6)
    end
end
SB.draw_ghost = draw_ghost

local function ghost_here(index)
    if not ghost_seat(index) then return false end
    local np = gNetworkPlayers[index]
    if np == nil or not np.connected then return false end
    return OF.gamemodes.in_place_room(OF.gamemodes.here_place(0), index)
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.pos == nil then return end
    if not round_live() then return end
    local index = m.playerIndex
    if type(index) ~= "number" then return end
    if riding(index) then
        hide("sbGhost" .. index)
        draw_rider(index, m)
    elseif ghost_here(index) then
        hide_rider(index, true)
        draw_ghost(index, m)
    else
        hide_rider(index)
        hide("sbGhost" .. index)
    end
end)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not round_live() then return end
    if not riding_me() and not ghost_me() then return end
    if me.carried == 0 and me.waiting == 0 then SB.fell(m) end
    return false
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or type(data.ofp) ~= "string" then return end
    if not round_live() then return end
    if data.ofp == K.PACKET_THROW then
        local id = tonumber(data.id)
        local kind = tonumber(data.k)
        if id == nil or (kind ~= 1 and kind ~= 2) then return end
        launch(id, math.floor(id / 10000), kind, tonumber(data.x) or 0, tonumber(data.y) or 0,
            tonumber(data.z) or 0, tonumber(data.vx) or 0, tonumber(data.vy) or 0,
            tonumber(data.vz) or 0)
    elseif data.ofp == K.PACKET_BURST then
        SB.hear_burst(data)
    end
end)

local mode = {
    key = "shellbattle",
    name = "Shell Battle",
    blurb = "bombs stacked over your head, on a shell, in a vanilla level",

    how = "Everybody rides a shell; Bob-ombs lie about the level.\n"
        .. "Ride over one to stack it over your head.\n"
        .. "B throws the top one ahead; stick back drops a mine.\n"
        .. "A burst pops a balloon and the thrower scores a point.\n"
        .. "Lose your last balloon and half your points go with it.\n"
        .. "Most points at the end wins.",
    aims = { riding = "Stack bombs, throw them, keep your balloons." },
    minPlayers = 2,
    saysOut = true,
    maps = "surveyed",
    surveyKeys = { "points" },

    surveyOut = {
        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_RR, area = 1 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 },
        { level = LEVEL_CCM, area = 1 }, { level = LEVEL_TTM, area = 1 },
        { level = LEVEL_HMC, area = 1 }, { level = LEVEL_COTMC, area = 1 },
        { level = LEVEL_BBH, area = 1 }, { level = LEVEL_PSS, area = 1 },
        { level = LEVEL_VCUTM, area = 1 }, { level = LEVEL_WF, area = 1 },
        { level = LEVEL_THI, area = 1 }, { level = LEVEL_WDW, area = 1 },
        { level = LEVEL_DDD, area = 2 },

        { level = LEVEL_CASTLE_COURTYARD, area = 1 },
    },
    room = { sweep = { "cannons", "pickups", "enemies", "bosses", "projectiles",
                       "spawners" } },
    music = SEQ_LEVEL_KOOPA_ROAD,
    defaultLimit = 180,
    teams = false,
    options = {
        { key = "game", name = "The game",
          help = "which battle the shells fight",
          choices = {
              { key = "blast", name = "Bob-omb Blast",
                help = "a burst pops a balloon - the thrower scores" },
              { key = "balloon", name = "Balloon Battle",
                help = "bombs, and ramming at full speed steals a balloon" },
              { key = "shine", name = "Shine Grab",
                help = "hold the Shine until your count runs out" },
          } },

        { key = "balloons", name = "Balloons",
          help = "how many balloons every rider starts with",
          shownIf = { game = { "blast", "balloon" } },
          choices = {
              { key = "lobby", name = "for the lobby",
                help = "three, or five when more than eight ride" },
              { key = "3", name = "three", help = "three each" },
              { key = "5", name = "five", help = "five each" },
          } },
        { key = "empty", name = "When you run out",
          help = "what losing your last balloon costs",
          shownIf = { game = { "blast", "balloon" } },
          choices = {
              { key = "half", name = "half your points",
                help = "the Lakitu brings you back with three" },
              { key = "out", name = "out of the round",
                help = "ride on as a Bob-omb that pops one balloon" },
          } },
        { key = "held", name = "Bombs held",
          help = "how many bombs a stack holds",
          choices = {
              { key = "5", name = "five", help = "a stack you can see over" },
              { key = "3", name = "three", help = "a short stack - throw often" },
              { key = "10", name = "ten", help = "a tall stack for a barrage" },
          } },
        { key = "throw", name = "Throw",
          help = "how far ahead of you a bomb comes down",
          choices = {

              { key = "15", name = "medium", help = "the usual throw" },
              { key = "10", name = "short", help = "a lob just ahead of you" },
              { key = "22", name = "long", help = "a long throw down the track" },
          } },
        { key = "catchup", name = "Catch-up",
          help = "whoever trails picks up more",
          choices = {
              { key = "on", name = "on",
                help = "two bombs a pickup when three points behind" },
              { key = "off", name = "off", help = "one bomb a pickup for all" },
          } },
        { key = "own", name = "Your own bomb",
          help = "what your own blast does to you",
          choices = {
              { key = "throws", name = "throws you",
                help = "a bomb jump - it costs you nothing" },
              { key = "harmless", name = "harmless",
                help = "it does nothing to you at all" },
          } },
        { key = "shinecount", name = "When the Shine is lost",
          help = "what the one who lost it keeps of their count",
          shownIf = { game = "shine" },
          choices = {
              { key = "keep", name = "keep your own count",
                help = "pick it up again where you left off" },
              { key = "reset", name = "start again",
                help = "the whole count from the top" },
          } },
        { key = "round", name = "Round",
          help = "how long a battle lasts",
          choices = {
              { key = "3", name = "three minutes", help = "most points wins" },
              { key = "2", name = "two minutes", help = "most points wins" },
              { key = "5", name = "five minutes", help = "most points wins" },
              { key = "first", name = "first to a score",
                help = "set by the lobby's size - Shine Grab plays the clock" },
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

    presets = {
        { key = "blast", name = "Bob-omb Blast", help = "the usual battle", sets = {} },
        { key = "balloon", name = "Balloon Battle", help = "three balloons, out when they are gone",
          sets = { game = "balloon", balloons = "3", empty = "out" } },
        { key = "shine", name = "Shine Grab", help = "hold the Shine, your count kept",
          sets = { game = "shine", shinecount = "keep" } },
    },

    outWord = "NO BALLOONS",
    boardTitle = "Battle",
}
SB.mode = mode

function mode.terms()
    local game = OF.gamemodes.option_showing(mode.key, "game")
    if game == "shine" then return OF.lang.t("hold the Shine until your count runs out") end
    if OF.gamemodes.option_showing(mode.key, "round") == "first" then
        local target = rule().target
        if target > 0 then
            return OF.lang.fill("pop balloons - first to @ points", tostring(target))
        end
        return OF.lang.t("pop balloons - first to a score set by the lobby")
    end
    return OF.lang.t("pop balloons - most points wins")
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, K.ROLE_RIDE)
    end

    local balloons, target, slots = SB.dials(#players, option("balloons"), option("round"),
        option("game") or "blast")

    SB.turns = (SB.turns or 0) + 1
    OF.util.publish(K.RULE_KEY, string.format("%.0f %.0f %.0f %.0f",
        balloons, target, slots, SB.turns))
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", K.ROUND_SECONDS[option("round") or "3"] or 180)
    end
    return true
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, K.ROLE_RIDE)
    return K.ROLE_RIDE
end

local function pin_points()
    local here = OF.gamemodes.here_place(0)
    local list = here ~= nil and OF.gamemodes.surveyed_list(here, "points", K.POINTS_WANT) or nil
    if list == nil or #list == 0 then
        OF.util.publish(K.PTS_KEY, nil)
        OF.util.publish(K.BOMBS_KEY, nil)
        return nil
    end
    if #list > K.POINTS_WANT then
        local trimmed = {}
        for i = 1, K.POINTS_WANT do trimmed[i] = list[i] end
        list = trimmed
    end
    OF.util.publish(K.PTS_KEY, OF.gamemodes.pack_points(list))
    return list
end

local function pin_ground(list)
    host.seenGrab = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        host.seenGrab[entry.localIndex] = row ~= nil and row[K.GRAB_KEY] or nil
    end
    host.laid = true

    local r = rule()
    local slots = SB.slots_for_map(r.slots, option("game") or "blast", list)
    if slots ~= r.slots then
        OF.util.publish(K.RULE_KEY, string.format("%.0f %.0f %.0f %.0f",
            r.balloons, r.target, slots, r.turn or SB.turns or 0))
    end
    lay_ground(slots)
    if SB.pin_shines ~= nil then SB.pin_shines() end
end

function mode.pin()
    local list = pin_points()
    if list ~= nil then pin_ground(list) end
end

mode.leadPin = {
    keys = { K.PTS_KEY, K.BOMBS_KEY },
    run = pin_points,
    take = function()
        local list = the_points()
        if list ~= nil then pin_ground(list) end
    end,
}

function mode.death_place(from)
    local at = OF.gamemodes.round_place()
    local list = the_points()
    if at == nil or list == nil then return nil end
    local enemies = OF.gamemodes.spawn_bodies(nil, at)
    local p = OF.gamemodes.pick_spawn(list, { enemies = enemies,
        from = type(from) == "table" and from or nil }) or list[1]
    return { x = p.x, y = p.y, z = p.z, level = at.level, area = at.area }
end

local opened = false
local sinceRide = 0

function mode.on_start()
    host.frenzySaid = false
    SB.frenzySaid = false
    forget_me()
    frame = 0
    opened = false
    sinceRide = 0
    sinceThrow = 99
    lastPos = nil
    taken = {}
    spotCache = {}
    grabSerial = 0
    throwSerial = 0
    burstIds = {}
    seenHit = {}
    rowsRead = false
    drop_all_flights()
    SB.ready_me()
    mark_rows_read()
    return true
end

function SB.ready_me()
    me.ready = true
    me.balloons = rule().balloons
    OF.util.publish_row(0, "ofScore", 0)
    OF.util.publish_row(0, GRAB_KEY, nil)
    write_row()
    if SB.start_shine ~= nil then SB.start_shine() end
end

local function open_round(m)
    local list = the_points()
    if list == nil then return false end
    local np = gNetworkPlayers[0]
    if np == nil or np.currAreaSyncValid == false then return false end
    local place = OF.gamemodes.round_place()
    if place ~= nil and (np.currLevelNum ~= place.level or np.currAreaIndex ~= place.area) then
        return false
    end
    if (tonumber(gGlobalSyncTable.ofGmElapsed) or 0) > 3 then
        opened = true
        call_lakitu(0)
        return true
    end
    local order = {}
    for _, entry in ipairs(riders()) do
        if entry.np ~= nil then table.insert(order, entry.np.globalIndex) end
    end
    table.sort(order)
    local slot = 1
    for i, g in ipairs(order) do if g == np.globalIndex then slot = i end end
    local p = list[((slot - 1 + rule().turn) % #list) + 1]

    local lap = math.floor((slot - 1) / #list)
    local x, z = p.x + lap * 150, p.z + lap * 150
    local y = floor_at(x, p.y + 300, z) or p.y
    local cx, cz = middle(list)
    opened = true
    m.pos.x, m.pos.y, m.pos.z = x, y + 20, z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.faceAngle.y = face_to(x, z, cx, cz)
    m.intendedYaw = m.faceAngle.y
    if m.marioObj ~= nil then
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ = m.pos.x, m.pos.y, m.pos.z
        m.marioObj.oMoveAngleYaw = m.faceAngle.y
    end
    local r = ride()
    if r.RIDE_GROUND ~= nil then
        mario_set_forward_vel(m, 0)
        set_mario_action(m, r.RIDE_GROUND, 1)
    end
    OF.util.camera_behind_soon()
    return true
end
SB.open_round = open_round

local RIDE_GROUPS = nil
local function may_ride(m)
    if m == nil or m.action == nil then return false end
    if (m.health or 0) < 0x100 then return false end
    if RIDE_GROUPS == nil then
        RIDE_GROUPS = { [ACT_GROUP_STATIONARY] = true, [ACT_GROUP_MOVING] = true,
                        [ACT_GROUP_AIRBORNE] = true }
    end
    return RIDE_GROUPS[m.action & ACT_GROUP_MASK] == true
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local state = OF.gamemodes.state()
    if (state == OF.gamemodes.ACTIVE or state == OF.gamemodes.COUNTDOWN)
        and OF.util.round_screen() and ride().shut_the_ways ~= nil then
        ride().shut_the_ways(true)
    end
    if state ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) == K.ROLE_OUT and me.spent and on_the_ride(m) then

        set_mario_action(m, ACT_FREEFALL, 0)
        return
    end
    if not riding_me() and not ghost_me() then return end
    local r = ride()
    if r.RIDE_GROUND == nil then return end
    if not opened then
        open_round(m)
        return
    end
    if me.carried > 0 then carry(m) return end
    if me.waiting > 0 then

        OF.input.freeze(m)
        m.vel.x, m.vel.z, m.forwardVel = 0, 0, 0
        return
    end
    if on_the_ride(m) then sinceRide = 0 return end
    sinceRide = sinceRide + 1
    if sinceRide < K.REMOUNT_FRAMES or not may_ride(m) then return end
    sinceRide = 0
    if (m.forwardVel or 0) < K.PUSH_OFF then mario_set_forward_vel(m, K.PUSH_OFF) end
    set_mario_action(m, r.RIDE_GROUND, 0)
end

local function tick_me()
    local before = flags()
    if me.carried > 0 then me.carried = me.carried - 1 end
    if me.waiting > 0 then
        me.waiting = me.waiting - 1
        if me.waiting == 0 then
            me.balloons = K.COMEBACK_BALLOONS
            me.stack = 0
            call_lakitu(0)
            me.invUntil = frame + K.LAKITU_FRAMES + K.INVINCIBLE
            local m = gMarioStates[0]
            if m ~= nil then m.invincTimer = K.LAKITU_FRAMES + K.INVINCIBLE end
        end
    end
    if before ~= flags() then write_row() end
end

local function check_falls(m)
    if me.carried > 0 or me.waiting > 0 then return end
    local manual = m.controller ~= nil and ((m.controller.buttonPressed or 0) & D_JPAD) ~= 0
    if manual then

        me.stack = 0
        call_lakitu(K.LAKITU_MANUAL)
        return
    end
    local list = the_points()
    if list == nil then return end
    local low = lowest(list)
    if low ~= nil and m.pos.y < low - K.FALL_BELOW and (m.vel.y or 0) <= 0 then
        SB.fell(m)
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    sinceThrow = sinceThrow + 1
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if ghost_me() then

        tick_me()
        check_falls(m)
        return
    end
    if not riding_me() then return end
    if not me.ready then SB.ready_me() end
    if not opened then return end
    tick_me()
    SB.tick_shine()
    check_falls(m)
    if me.carried == 0 and me.waiting == 0 then
        watch_pickups(m)
        ram(m)
        if last_standing() then ghost_touch(m) end
        SB.touch_shine(m)
        local pressedB = m.controller ~= nil
            and ((m.controller.buttonPressed or 0) & B_BUTTON) ~= 0
        if pressedB then throw(m) end
    end
    lastPos = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    if written == nil then write_row() end
end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    frame = frame + 1
    draw_ground()
    step_flights()
    step_bangs()
    watch_hits()
    if SB.shine_scenery ~= nil then SB.shine_scenery() end

    for index = 0, MAX_PLAYERS - 1 do
        if not riding(index) and not ghost_here(index) then hide_rider(index) end
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if host.laid then settle_grabs() end
    if SB.host_shine ~= nil and SB.host_shine() then return end
    local target = rule().target
    if target > 0 and not game_is("shine") then
        for _, entry in ipairs(riders()) do
            if score_of(entry.localIndex) >= target then
                OF.gamemodes.finish("@ won with @ points.", entry.np.name,
                    entry.np.name, tostring(target))
                return
            end
        end
    end
    if last_standing() and not game_is("shine") then
        local left = riders()
        if #left == 1 then
            OF.gamemodes.finish("@ won as the last rider up.", left[1].np.name,
                left[1].np.name)
        elseif #left == 0 then
            OF.gamemodes.finish("Nobody was left riding.")
        end
    end
end

function mode.still_winnable()
    return #riders() >= (last_standing() and 1 or 2)
end

local function breaker(entry)
    local r = row_of(entry.localIndex)
    return -r.emptied * 1000 + r.landed
end
SB.breaker = breaker

function mode.on_timeout()
    if SB.shine_timeout ~= nil and game_is("shine") then
        SB.shine_timeout()
        return
    end
    local list = riders()
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_OUT)) do table.insert(list, entry) end
    local best, names = OF.gamemodes.best_of(list,
        function(entry) return score_of(entry.localIndex) end, false, breaker)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody popped a balloon.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ points.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won with @ points.", names[1], names[1], tostring(best))
    end
end

local function by_board_value(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.localIndex < b.localIndex
end

function mode.board()
    local rows = {}
    local list = riders()
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_OUT)) do table.insert(list, entry) end
    for _, entry in ipairs(list) do
        local r = row_of(entry.localIndex)
        local right
        if game_is("shine") then
            right = SB.shine_left_text ~= nil and SB.shine_left_text(entry.localIndex) or ""
        else
            right = OF.lang.fill("@ pts", tostring(score_of(entry.localIndex)))
        end
        local value = score_of(entry.localIndex)
        if game_is("shine") then value = -r.shine end
        table.insert(rows, { localIndex = entry.localIndex, name = entry.np.name,
            right = right, value = value, balloons = r.balloons })
    end
    table.sort(rows, by_board_value)
    return rows
end

function SB.legend_lines()
    return {
        OF.lang.t("B - throw the top bomb"),
        OF.lang.t("Select + B - drop a mine"),
        OF.lang.t("D-pad down - call the Lakitu"),
        OF.lang.t("A - jump"),
    }
end

local RING_REACH = 90
SB.RING_REACH = RING_REACH
local ringAt = { x = 0, y = 0, z = 0 }
function SB.spawn_rings()
    local drawn = 0
    for slot, b in ipairs(ground()) do
        if b and not taken[slot .. ":" .. b.serial] then
            local spot = spot_of(b.point, b.serial)
            if spot ~= nil then
                ringAt.x, ringAt.y, ringAt.z = spot.x, spot.y + 4, spot.z
                local lines = OF.util.zone_ring(ringAt, RING_REACH, 24, 3,
                    255, 170, 60, 150)
                if type(lines) == "number" and lines > 0 then drawn = drawn + 1 end
            end
        end
    end
    return drawn
end

function mode.hud()
    SB.spawn_rings()
    local role = OF.gamemodes.role(0)
    if role == K.ROLE_OUT then
        if ghost_seat(0) then

            OF.gamemodes.out_banner()
            if OF.util.asks(OF.hud, "state_line") then
                OF.hud.state_line("ghost", OF.lang.t("Bob-omb ride"), { prio = 50, tone = "warn" })
            end
            return
        end
        OF.gamemodes.out_banner()
        return
    end
    if role ~= K.ROLE_RIDE then return end
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    if SB.frenzy() and not SB.frenzySaid then
        SB.frenzySaid = true
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("roundstate", OF.lang.t("FRENZY"), OF.lang.t("Bombs come back twice as fast"))
        end
    end

    if OF.util.asks(OF.hud, "state_line") then
        if me.carried > 0 or me.waiting > 0 then
            OF.hud.state_line("lakitu", OF.lang.t("Lakitu has you"), { prio = 60, tone = "mute" })
        end
        OF.hud.state_line("kit", nil, { prio = 50, icons = mode.kit_icons() })
    end
    OF.util.legend(SB.legend_lines())

    local rows = mode.board()
    if #rows > 0 then
        if OF.util.asks(OF.gamemodes, "board_cap") then
            rows = OF.gamemodes.board_cap(rows, OF.gamemodes.SIDE_BOARD_ROWS or 4)
        end
        OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
            OF.lang.t("Battle"), rows, { column = 130 })
    end
end

function mode.kit_icons()
    local items = {}
    if game_is("shine") then
        items[#items + 1] = { icon = "star", tone = "target", empty = my_shine() == nil,
            text = tostring(math.ceil(me.shineLeft / 30)) }
    else
        for _ = 1, math.max(0, me.balloons or 0) do
            items[#items + 1] = { icon = "balloon", tone = "bad" }
        end
    end
    items[#items + 1] = { icon = "bomb", count = me.stack, tone = "ink" }
    return items
end

function mode.cleanup()

    if ride().open_the_ways ~= nil then ride().open_the_ways() end
    drop_all_flights()
    drop_bangs()
    for slot in pairs(groundDrawn) do hide("sbGround" .. slot) end
    groundDrawn = {}
    for index = 0, MAX_PLAYERS - 1 do hide_rider(index) end
    if SB.cleanup_shine ~= nil then SB.cleanup_shine() end

    local m = gMarioStates[0]
    if m ~= nil and on_the_ride(m) then
        mario_set_forward_vel(m, 0)
        set_mario_action(m, ACT_IDLE, 0)
    end
    if m ~= nil then m.invincTimer = 0 end

    forget_me()
    opened = false
    taken = {}
    spotCache = {}
    burstIds = {}
    seenHit = {}
    rowsRead = false
    lastPos = nil
    pointsRaw, points = nil, nil
    OF.util.publish_row(0, ROW_KEY, nil)
    OF.util.publish_row(0, GRAB_KEY, nil)
    if OF.util.is_host() then
        OF.util.publish(K.RULE_KEY, nil)
        OF.util.publish(K.PTS_KEY, nil)
        OF.util.publish(K.BOMBS_KEY, nil)
        OF.util.publish(K.SHINE_KEY, nil)
    end
    host = { slots = {}, serial = 0, seenGrab = {}, laid = false }
    return true
end

OF.gamemodes.register(mode)
