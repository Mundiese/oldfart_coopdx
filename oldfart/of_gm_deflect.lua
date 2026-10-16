OF = OF or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local KEY_AT = "ofDfAt"
local KEY_BALL = "ofDfBall"
local ROW_PARRY = "ofDfParry"
local ROW_HIT = "ofDfHit"
local ROW_LIVES = "ofDfLives"
local ROLE_IN = "in"
local ROLE_OUT = "out"
local MAX_BALLS = 4

local GONE, WAITING, FLYING, HOLD = 0, 1, 2, 3

local WHY_SENT, WHY_PARRY, WHY_LOST = 0, 1, 2

local PARRY_REACH = 360

local PARRY_TALL = 360

local HIT_REACH = 90

local CONTACT = 60

local CHEST = 80

local HOLD_LIMIT = 90

local SEND_PAUSE = 45
local FIRST_PAUSE = 90

local SEND_HEIGHT = 400

local FREE_FLIGHT = 6

local TURN_BASE = 0.10
local TURN_GROWTH = 0.004

local LOCK_ON = 250

local TOP_SPEED = 150

local WHIFF_LOCK = 30

local SEND_EVERY = 3

local OUT_DROP = 400

local AIM_CONE = math.pi / 3

local TRAIL = 300

local SPEED_STOPS = { steady = 40, gentle = 34, fierce = 52 }

local GAIN_STOPS = { tenth = 0.10, twentieth = 0.05, fifth = 0.20 }

local WINDOW_STOPS = { half = 15, third = 10, most = 22 }
local BALL_STOPS = { one = 1, two = 2, three = 3, four = 4 }
local LIFE_STOPS = { one = 1, two = 2, three = 3 }

local function stop_of(stops, key, first)
    return stops[OF.gamemodes.option_now(key) or first] or stops[first]
end

local function start_speed() return stop_of(SPEED_STOPS, "speed", "steady") end
local function speed_gain() return stop_of(GAIN_STOPS, "gain", "tenth") end
local function swing_window() return stop_of(WINDOW_STOPS, "window", "half") end
local function lives_dealt() return stop_of(LIFE_STOPS, "lives", "one") end

local tick = 0

local sim = {}
for b = 1, MAX_BALLS do
    sim[b] = { phase = GONE, x = 0, y = 0, z = 0, dx = 0, dy = 0, dz = 1,
               speed = 0, target = -1, serial = 0, why = WHY_SENT,
               wait = 0, chase = 0, free = 0, hold = 0, gap = 0 }
end

local lastChosen = {}

local tieRank = {}

local sinceSend = 0
local mustSend = false

local serialEra = 0

local rowSeen = {}

local heard = {}
for b = 1, MAX_BALLS do
    heard[b] = {
        prev = { x = 0, y = 0, z = 0, gap = 0 },
        cur = { x = 0, y = 0, z = 0, gap = 0 },
        phase = GONE, target = -1, serial = 0, speed = 0, why = WHY_SENT,
        arrived = 0, span = SEND_EVERY,
    }
end
local heardText = nil

local flameObjs = {}

local flameModel = {}
local drawn = {}
for b = 1, MAX_BALLS do drawn[b] = { x = 0, y = 0, z = 0, gap = 0, live = false } end

local swingAt = nil
local swingTargeted = false
local lockedUntil = 0
local lastAction = 0
local judged = {}
local parried = {}
local struck = {}
local lives = 1
local beepAt = 0
local out = false

local lastCause = nil

local seenOutRole = {}
local lastOutLocal, lastOutAt = nil, -9999
local outTick = 0

local function track_last_out()
    outTick = outTick + 1
    for s = 0, (MAX_PLAYERS or 16) - 1 do
        local role = OF.gamemodes.role(s)
        if role == ROLE_OUT and seenOutRole[s] ~= ROLE_OUT then
            lastOutLocal, lastOutAt = s, outTick
        end
        seenOutRole[s] = role
    end
end

local trailX, trailY, trailZ, trailLive, trailRed = {}, {}, {}, {}, {}
for k = 1, TRAIL * MAX_BALLS do
    trailX[k], trailY[k], trailZ[k], trailLive[k], trailRed[k] = 0, 0, 0, 0, 0
end

local function am_in()
    return OF.gamemodes.role(0) == ROLE_IN
end

local function still_in()
    return OF.gamemodes.with_role(ROLE_IN)
end

local atText, atPlace = nil, nil
local function pinned()
    local text = gGlobalSyncTable[KEY_AT]
    if type(text) ~= "string" or text == "" then return nil end
    if text ~= atText then
        local level, area, x, y, z = text:match(
            "^(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)$")
        atText = text
        if level == nil then
            atPlace = nil
        else
            atPlace = { level = tonumber(level), area = tonumber(area),
                        x = tonumber(x), y = tonumber(y), z = tonumber(z) }
        end
    end
    return atPlace
end

local function chaseable(localIndex, at)
    if OF.gamemodes.role(localIndex) ~= ROLE_IN then return false end
    if not OF.gamemodes.in_contention(localIndex) then return false end
    return OF.gamemodes.distance_to_place(at, localIndex) ~= nil
end

local function yaw_dir(yaw)
    local a = (yaw or 0) / 65536 * 2 * math.pi
    return math.sin(a), math.cos(a)
end

local function balls_wanted(left)
    if left < 2 then return 0 end
    local said = OF.gamemodes.option_now("balls") or "one"
    local n = said == "auto" and math.min(4, math.ceil(left / 5))
        or stop_of(BALL_STOPS, "balls", "one")
    return math.max(1, math.min(n, left - 1))
end

local packParts = {}

local function pack_balls()
    local parts = packParts
    for b = 1, MAX_BALLS do
        local s = sim[b]
        parts[b] = string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f",
            s.phase, s.serial, s.target, s.x, s.y, s.z,
            math.floor(s.speed * 10 + 0.5), s.gap, s.why)
    end
    return table.concat(parts, ";")
end

local function send_now()

    OF.gamemodes.stream_send(KEY_BALL, pack_balls())
    sinceSend = 0
    mustSend = false
end

local NUM = "(%-?%d+)"
local ONE = "^" .. NUM .. " " .. NUM .. " " .. NUM .. " " .. NUM .. " " .. NUM
    .. " " .. NUM .. " " .. NUM .. " " .. NUM .. " " .. NUM .. "$"
local function hear(text)
    heardText = text
    local b = 0
    for part in string.gmatch(text or "", "[^;]+") do
        b = b + 1
        if b > MAX_BALLS then break end
        local h = heard[b]
        local phase, serial, target, x, y, z, speed, gap, why = part:match(ONE)
        if phase ~= nil then
            phase, serial = tonumber(phase), tonumber(serial)
            x, y, z, gap = tonumber(x), tonumber(y), tonumber(z), tonumber(gap)
            local snap = h.phase == GONE or phase == WAITING
            local fresh = serial ~= h.serial
            if snap then
                h.prev.x, h.prev.y, h.prev.z, h.prev.gap = x, y, z, gap
            else
                h.prev.x, h.prev.y, h.prev.z = h.cur.x, h.cur.y, h.cur.z

                h.prev.gap = fresh and gap or h.cur.gap
            end
            h.cur.x, h.cur.y, h.cur.z, h.cur.gap = x, y, z, gap
            h.span = OF.util.clamp(tick - h.arrived, 1, 15)
            h.arrived = tick
            h.phase, h.serial, h.target = phase, serial, tonumber(target)
            h.speed = tonumber(speed) / 10
            h.why = tonumber(why)
        end
    end
    for rest = b + 1, MAX_BALLS do heard[rest].phase = GONE end
end

local function interp(b)
    local h = heard[b]
    local u = OF.util.clamp((tick - h.arrived) / h.span, 0, 1)
    local p, c = h.prev, h.cur
    return p.x + (c.x - p.x) * u, p.y + (c.y - p.y) * u,
        p.z + (c.z - p.z) * u, p.gap + (c.gap - p.gap) * u
end

local function my_global()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex or -2
end

local function coming_for_me(b)
    local h = heard[b]
    return (h.phase == FLYING or h.phase == HOLD or h.phase == WAITING)
        and h.target == my_global()
end

local function in_ring(gap, ox, oy, oz)
    if gap == nil then return false end
    if gap <= PARRY_REACH then return true end
    local len = math.sqrt(ox * ox + oy * oy + oz * oz)
    if len < 1 then return false end
    local across = gap * math.sqrt(ox * ox + oz * oz) / len
    local upDown = gap * math.abs(oy) / len
    return across <= PARRY_REACH and upDown <= PARRY_TALL
end

local function ring_reached(b)
    local m = gMarioStates[0]
    local gap = drawn[b].gap
    if m == nil or m.pos == nil then return gap <= PARRY_REACH end
    local x, y, z = interp(b)
    return in_ring(gap, x - m.pos.x, y - (m.pos.y + CHEST), z - m.pos.z)
end

local function frames_left(b)
    local h = heard[b]
    if h.phase ~= FLYING and h.phase ~= HOLD then return math.huge end
    return drawn[b].gap / math.max(h.speed, 1)
end

local function draw_position(b)
    local d = drawn[b]
    local x, y, z, gap = interp(b)
    d.x, d.y, d.z, d.gap = x, y, z, gap
    d.live = heard[b].phase ~= GONE
    if not d.live or heard[b].phase == WAITING or not coming_for_me(b) then
        return d
    end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return d end
    local cx, cy, cz = m.pos.x, m.pos.y + CHEST, m.pos.z
    local ox, oy, oz = x - cx, y - cy, z - cz
    local len = math.sqrt(ox * ox + oy * oy + oz * oz)
    if len < 1 then return d end
    local w = OF.util.clamp((1500 - gap) / 1000, 0, 1)
    local rx, ry, rz = cx + ox / len * gap, cy + oy / len * gap, cz + oz / len * gap
    d.x, d.y, d.z = x + (rx - x) * w, y + (ry - y) * w, z + (rz - z) * w
    return d
end

local function chest_of(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end
    return m.pos.x, m.pos.y + CHEST, m.pos.z
end

local function taken_by_other(b, g)
    for other = 1, MAX_BALLS do
        if other ~= b and sim[other].phase ~= GONE and sim[other].target == g then
            return true
        end
    end
    return false
end

local function next_after_send(b, at)
    local best, bestAt, bestG, spare = nil, nil, nil, nil
    for _, entry in ipairs(still_in()) do
        local li = entry.localIndex
        if chaseable(li, at) then
            local g = network_global_index_from_local(li)
            if taken_by_other(b, g) then
                spare = spare or li
            else
                local when = lastChosen[g] or -1
                local rank = tieRank[g] or g
                if best == nil or when < bestAt
                    or (when == bestAt and rank < bestG) then
                    best, bestAt, bestG = li, when, rank
                end
            end
        end
    end
    return best or spare
end

local function next_after_parry(b, at, parrierLocal, yaw)
    local fx, fz = yaw_dir(yaw)
    local px, _, pz = chest_of(parrierLocal)
    if px == nil then return next_after_send(b, at) end
    local coneBest, coneNear, anyBest, anyAngle = nil, nil, nil, nil
    local spare = nil
    for _, entry in ipairs(still_in()) do
        local li = entry.localIndex
        if li ~= parrierLocal and chaseable(li, at) then
            local g = network_global_index_from_local(li)
            if taken_by_other(b, g) then
                spare = spare or li
            else
                local cx, _, cz = chest_of(li)
                local ox, oz = cx - px, cz - pz
                local dist = math.sqrt(ox * ox + oz * oz)
                local angle = 0
                if dist > 1 then
                    local dot = OF.util.clamp((ox * fx + oz * fz) / dist, -1, 1)
                    angle = math.acos(dot)
                end
                if angle <= AIM_CONE and (coneBest == nil or dist < coneNear) then
                    coneBest, coneNear = li, dist
                end
                if anyBest == nil or angle < anyAngle then
                    anyBest, anyAngle = li, angle
                end
            end
        end
    end
    return coneBest or anyBest or spare
end

local function choose(b, li, why)
    local s = sim[b]
    local g = li ~= nil and network_global_index_from_local(li) or -1
    s.target = g
    s.serial = s.serial + 1
    s.why = why
    s.chase = 0
    s.hold = 0

    local tx, ty, tz = nil, nil, nil
    if li ~= nil then tx, ty, tz = chest_of(li) end
    if tx ~= nil then
        local ox, oy, oz = tx - s.x, ty - s.y, tz - s.z
        s.gap = math.sqrt(ox * ox + oy * oy + oz * oz)
    else
        s.gap = PARRY_REACH * 10
    end
    if g >= 0 then lastChosen[g] = tick end
    mustSend = true
end

local function send_from_middle(b, at, pause)
    local s = sim[b]
    s.phase = WAITING
    s.x, s.y, s.z = at.x, at.y + SEND_HEIGHT, at.z
    local was = s.speed
    if OF.gamemodes.since_start() >= 120 and type(was) == "number" and was > 0 then
        s.speed = math.min(math.max(was, start_speed()) * (1 + speed_gain()), TOP_SPEED)
    else
        s.speed = start_speed()
    end
    s.wait = pause
    s.free = 0
    s.gap = 0
    choose(b, next_after_send(b, at), WHY_SENT)
end

local function turn_allowance(s)
    return TURN_BASE + TURN_GROWTH * s.chase
end

local function steer(s, li)
    local tx, ty, tz = chest_of(li)
    if tx == nil then return end
    local ox, oy, oz = tx - s.x, ty - s.y, tz - s.z
    local dist = math.sqrt(ox * ox + oy * oy + oz * oz)
    s.gap = dist
    if dist <= CONTACT then
        s.phase = HOLD
        s.hold = 0
        s.x, s.y, s.z, s.gap = tx, ty, tz, 0
        mustSend = true
        return
    end
    local wx, wy, wz = ox / dist, oy / dist, oz / dist
    if s.free > 0 then
        s.free = s.free - 1
    elseif dist <= LOCK_ON then
        s.dx, s.dy, s.dz = wx, wy, wz
    else

        local dot = OF.util.clamp(s.dx * wx + s.dy * wy + s.dz * wz, -1, 1)
        local angle = math.acos(dot)
        local allow = turn_allowance(s)
        local k = angle <= allow and 1 or allow / angle
        local nx = s.dx + (wx - s.dx) * k
        local ny = s.dy + (wy - s.dy) * k
        local nz = s.dz + (wz - s.dz) * k
        local n = math.sqrt(nx * nx + ny * ny + nz * nz)
        if n < 0.001 then nx, ny, nz, n = wx, wy, wz, 1 end
        s.dx, s.dy, s.dz = nx / n, ny / n, nz / n
    end
    local step = math.min(s.speed, dist)
    s.x, s.y, s.z = s.x + s.dx * step, s.y + s.dy * step, s.z + s.dz * step
    s.chase = s.chase + 1
end

local function row_says(li, key, b)
    local row = gPlayerSyncTable[li]
    local text = row ~= nil and row[key] or nil
    if type(text) ~= "string" then return nil end
    local seen = rowSeen[li]
    if seen == nil then
        seen = { parry = nil, hit = nil, p = {}, h = {}, pYaw = 0,
                 pCount = 0, hCount = 0 }
        rowSeen[li] = seen
    end
    if key == ROW_PARRY then
        if seen.parry ~= text then

            seen.parry = text
            local n = 0
            for v in string.gmatch(text, "%-?%d+") do
                n = n + 1
                seen.p[n] = tonumber(v) or 0
            end
            seen.pYaw = n > 0 and seen.p[n] or 0
            seen.pCount = n - 1
        end
        if b > (seen.pCount or 0) then return 0, seen.pYaw end
        return seen.p[b], seen.pYaw
    end
    if seen.hit ~= text then
        seen.hit = text
        local n = 0
        for v in string.gmatch(text, "%d+") do
            n = n + 1
            seen.h[n] = tonumber(v) or 0
        end
        seen.hCount = n
    end
    if b > (seen.hCount or 0) then return 0 end
    return seen.h[b]
end

local function verdict(b, li)
    local s = sim[b]
    local p, yaw = row_says(li, ROW_PARRY, b)
    if p == s.serial then return "parry", yaw end
    if row_says(li, ROW_HIT, b) == s.serial then return "hit" end
    return nil
end

local function host_ball(b, at, wanted)
    local s = sim[b]
    if s.phase == GONE then
        if b <= wanted then send_from_middle(b, at, SEND_PAUSE) end
        return
    end

    local li = s.target >= 0 and OF.util.local_from_global(s.target) or nil
    if li == nil or not chaseable(li, at) then

        if b > wanted then
            s.phase, s.target = GONE, -1
            mustSend = true
            return
        end
        choose(b, next_after_send(b, at), WHY_LOST)

        if s.phase == HOLD then s.phase, s.free = FLYING, 0 end
        if s.target < 0 then return end
        li = OF.util.local_from_global(s.target)
        if li == nil then return end
    end

    local said, yaw = verdict(b, li)
    if said == "parry" then
        local px, _, pz = chest_of(li)
        local fx, fz = yaw_dir(yaw)
        s.dx, s.dy, s.dz = fx, 0, fz
        if px ~= nil and s.phase == HOLD then
            s.x, s.z = px + fx * CONTACT, pz + fz * CONTACT
        end
        s.speed = math.min(s.speed * (1 + speed_gain()), TOP_SPEED)
        s.phase = FLYING
        s.free = FREE_FLIGHT
        choose(b, next_after_parry(b, at, li, yaw), WHY_PARRY)
        return
    elseif said == "hit" then
        if b > wanted then
            s.phase, s.target = GONE, -1
            mustSend = true
        else
            send_from_middle(b, at, SEND_PAUSE)
        end
        return
    end

    if s.phase == WAITING then
        s.wait = s.wait - 1
        local tx, ty, tz = chest_of(li)
        if tx ~= nil then
            local ox, oy, oz = tx - s.x, ty - s.y, tz - s.z
            s.gap = math.sqrt(ox * ox + oy * oy + oz * oz)
        end
        if s.wait <= 0 then
            s.phase = FLYING
            if tx ~= nil and s.gap > 0 then
                s.dx, s.dy, s.dz = (tx - s.x) / s.gap, (ty - s.y) / s.gap,
                    (tz - s.z) / s.gap
            end
            mustSend = true
        end
    elseif s.phase == FLYING then
        steer(s, li)
    elseif s.phase == HOLD then
        local tx, ty, tz = chest_of(li)
        if tx ~= nil then s.x, s.y, s.z = tx, ty, tz end
        s.gap = 0
        s.hold = s.hold + 1
        if s.hold > HOLD_LIMIT then send_from_middle(b, at, SEND_PAUSE) end
    end
end

local mode = {
    key = "deflect",
    resultsBy = "survival",
    name = "Deflect",
    blurb = "a flame hunts one player at a time - punch it back",
    how = "A flame hunts one player at a time, faster every time.\n"
        .. "Punch or kick it back and it turns on somebody else.\n"
        .. "It goes to whoever is nearest the way you face.\n"
        .. "Swing early and your next swing waits a second.\n"
        .. "A touch costs a life. Last one standing wins.",
    aims = {
        [ROLE_IN] = "When the flame comes for you, punch it as it arrives.",
    },
    minPlayers = 2,
    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 180,
    teams = false,
    lensRole = ROLE_OUT,
    music = SEQ_LEVEL_BOSS_KOOPA_FINAL,
    options = {
        { key = "speed", name = "Flame speed",
          help = "its speed when it is sent from the middle",
          choices = {
              { key = "steady", name = "normal",
                help = "a little quicker than Mario at a sprint" },
              { key = "gentle", name = "gentle",
                help = "only just faster than a run - for a first meeting" },
              { key = "fierce", name = "fierce",
                help = "much faster than a run - the first swing counts" },
          } },
        { key = "gain", name = "Speed-up per parry",
          help = "how much faster the flame goes after every parry",
          choices = {
              { key = "tenth", name = "normal",
                help = "a tenth faster each hit - long rallies end in a blur" },
              { key = "twentieth", name = "gentle",
                help = "a twentieth faster each hit - long rallies stay readable" },
              { key = "fifth", name = "steep",
                help = "a fifth faster each time - twice as fast in three" },
          } },
        { key = "window", name = "Parry window",
          help = "the time a punch or kick can meet the flame",
          choices = {
              { key = "half", name = "normal",
                help = "half a second, the original's window" },
              { key = "third", name = "tight",
                help = "a third of a second - for a lobby that parries well" },
              { key = "most", name = "wide",
                help = "most of a second - forgiving, for a first evening" },
          } },

        { key = "balls", name = "Flames",

          help = "more flames for a big lobby",
          choices = {
              { key = "one", name = "one",
                help = "a single hunter, whatever the lobby holds" },
              { key = "auto", name = "auto",
                help = "one flame for every five left, up to four" },
              { key = "two", name = "two",
                help = "two at once, one again for the last two" },
              { key = "three", name = "three",
                help = "for a lobby of eight or more" },
              { key = "four", name = "four",
                help = "for a full lobby of twelve to sixteen" },
          } },
        { key = "lives", name = "Lives",
          help = "how many touches of the flame put you out",
          choices = {
              { key = "one", name = "one life",
                help = "one touch and you are out" },
              { key = "two", name = "two lives",
                help = "the first touch is a warning" },
              { key = "three", name = "three lives",
                help = "a longer round for a smaller lobby" },
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
        { key = "classic", name = "Classic", help = "the usual round", sets = {} },
        { key = "beginner", name = "Beginner", help = "a gentle flame, a wide window, two lives",
          sets = { speed = "gentle", gain = "twentieth", window = "most", lives = "two" } },
        { key = "pro", name = "Pro", help = "a fierce flame, a steep climb, a tight window",
          sets = { speed = "fierce", gain = "fifth", window = "third" } },
    },
}

function mode.replayDecider()
    if lastOutLocal == nil or outTick - lastOutAt > 300 then return nil end
    return lastOutLocal
end

local function flame_after(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    for b = 1, MAX_BALLS do
        local h = heard[b]
        if h.phase ~= GONE and h.target == np.globalIndex then
            return true, frames_left(b) < 30
        end
    end
    return nil
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
end

local NO_FLOOR = -10000

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    local y = here.y
    local floor = OF.util.optional("find_floor_height", nil,
        here.x, here.y + 100, here.z)
    if type(floor) == "number" and floor > NO_FLOOR then y = floor end
    OF.util.publish(KEY_AT, string.format("%.0f %.0f %.0f %.0f %.0f",
        here.level, here.area, here.x, y, here.z))
end

mode.leadPin = { keys = { KEY_AT } }

local function reset_rows()
    OF.util.publish_row(0, ROW_PARRY, "0 0 0 0 0")
    OF.util.publish_row(0, ROW_HIT, "0 0 0 0")
end

function mode.on_start()
    tick = 0
    swingAt, swingTargeted, lockedUntil = nil, false, 0
    beepAt = 0
    out = false
    heardText = nil
    for b = 1, MAX_BALLS do
        judged[b], parried[b], struck[b] = 0, 0, 0
        heard[b].phase, heard[b].serial, heard[b].target = GONE, 0, -1
    end
    lives = lives_dealt()
    reset_rows()
    OF.util.publish_row(0, ROW_LIVES, am_in() and lives or 0)
    if OF.util.is_host() then
        serialEra = (serialEra + 1000) % 900000
        for b = 1, MAX_BALLS do
            sim[b].phase, sim[b].target, sim[b].serial = GONE, -1, serialEra
        end
        lastChosen = {}
        tieRank = {}
        for _, entry in ipairs(still_in()) do
            local g = network_global_index_from_local(entry.localIndex)
            if g ~= nil then tieRank[g] = OF.util.random() end
        end
        rowSeen = {}
        sinceSend = 0
        mustSend = true
    end
    lastCause = nil

end

local function go_out(text)
    if out then return end
    out = true
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    lastCause = text

end

local function lose_life(text)
    lives = math.max(lives - 1, 0)
    OF.util.publish_row(0, ROW_LIVES, lives)
    if lives <= 0 then
        go_out(text)
        return
    end

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("out", OF.lang.t("HIT"),
            OF.lang.plural(lives, "1 life left", "@ lives left"), { quiet = true })
    end
    OF.gamemodes.cue("bad")
end

local function publish_parry(yaw)
    OF.util.publish_row(0, ROW_PARRY, string.format("%.0f %.0f %.0f %.0f %.0f",
        parried[1], parried[2], parried[3], parried[4], yaw))
end

local function publish_hit()
    OF.util.publish_row(0, ROW_HIT, string.format("%.0f %.0f %.0f %.0f",
        struck[1], struck[2], struck[3], struck[4]))
end

local SWING_ACTIONS = nil
local PUNCH_ACTIONS = nil
local function swing_sets()
    if SWING_ACTIONS == nil then
        SWING_ACTIONS, PUNCH_ACTIONS = {}, {}
        for _, act in ipairs({ ACT_PUNCHING, ACT_MOVE_PUNCHING, ACT_JUMP_KICK,
                               ACT_SLIDE_KICK, ACT_DIVE }) do
            SWING_ACTIONS[act] = true
        end
        PUNCH_ACTIONS[ACT_PUNCHING] = true
        PUNCH_ACTIONS[ACT_MOVE_PUNCHING] = true
    end
    return SWING_ACTIONS, PUNCH_ACTIONS
end

local function swung(m)
    local swings, punches = swing_sets()
    local act = m.action
    local entered = swings[act] == true and act ~= lastAction
    local again = punches[act] == true and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed or 0, B_BUTTON)
    lastAction = act
    return entered or again
end

local function targeted_now()
    for b = 1, MAX_BALLS do
        if coming_for_me(b) then return true end
    end
    return false
end

function mode.update()
    track_last_out()
    if out or not am_in() then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local at = pinned()

    if (m.health or 0) < 0x880 then m.health = 0x880 end
    m.hurtCounter = 0

    if at ~= nil and m.pos.y < at.y - OUT_DROP then
        lose_life("Off the edge")
        if not out and OF.util.asks(OF.net, "snap_to") then
            OF.net.snap_to(at.x, at.y + 60, at.z, nil)
            OF.util.camera_behind_soon()
        end
        return
    end

    if swung(m) and tick >= lockedUntil then
        swingAt = tick
        swingTargeted = targeted_now()
    end
    local window = swing_window()
    local live = swingAt ~= nil and tick - swingAt <= window

    for b = 1, MAX_BALLS do
        local h = heard[b]
        if coming_for_me(b) and h.phase ~= WAITING and judged[b] ~= h.serial then
            local gap = drawn[b].gap
            if live and ring_reached(b) then
                judged[b] = h.serial
                parried[b] = h.serial
                publish_parry(m.faceAngle.y)
                swingAt = nil
                live = false

                OF.gamemodes.cue("good")
            elseif gap <= HIT_REACH then
                judged[b] = h.serial
                struck[b] = h.serial
                publish_hit()
                lose_life("The flame got you")
                if out then return end
            end
        end
    end

    if swingAt ~= nil and tick - swingAt > window then
        if swingTargeted or targeted_now() then lockedUntil = tick + WHIFF_LOCK end
        swingAt = nil
    end
end

function mode.host_update()
    local at = pinned()
    if at == nil then return end

    local left = still_in()
    if #left <= 1 then
        if #left == 1 then
            local name = left[1].np.name
            OF.gamemodes.finish("@ won.", name, name)
        else
            OF.gamemodes.finish("Everybody went out.")
        end
        return
    end

    local reachable = 0
    for _, entry in ipairs(left) do
        if chaseable(entry.localIndex, at) then reachable = reachable + 1 end
    end
    if reachable == 0 then
        OF.gamemodes.abandon("Nobody left in the arena for the flame to chase.")
        return
    end

    local wanted = balls_wanted(reachable)
    for b = 1, MAX_BALLS do

        if sim[b].phase == GONE and b <= wanted and sim[b].serial == serialEra
            and b == 1 then
            send_from_middle(b, at, FIRST_PAUSE)
        else
            host_ball(b, at, wanted)
        end
    end

    sinceSend = sinceSend + 1
    if mustSend or sinceSend >= SEND_EVERY then send_now() end
end

function mode.on_timeout()
    local left = still_in()
    if #left == 1 then
        OF.gamemodes.finish("@ won.", left[1].np.name,
            left[1].np.name)
        return
    end
    if #left == 0 then
        OF.gamemodes.finish("Everybody went out.")
        return
    end
    local names = {}
    for _, entry in ipairs(left) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish(#left == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names },
        tostring(#left))
end

local function trail_slot(b, index)
    return (b - 1) * TRAIL + (index % TRAIL) + 1
end

local function trail_record()
    if not OF.util.asks(OF.replay, "recording") or not OF.replay.recording() then
        return
    end
    local index = OF.replay.written()
    for b = 1, MAX_BALLS do
        local k = trail_slot(b, index)
        local d = drawn[b]
        trailLive[k] = d.live and 1 or 0
        trailX[k], trailY[k], trailZ[k] = d.x, d.y, d.z
        trailRed[k] = (coming_for_me(b) or frames_left(b) < 30) and 1 or 0
    end
end

local function trail_index()
    if not OF.util.asks(OF.replay, "playing") or OF.replay.playing() ~= "end" then
        return nil
    end

    if OF.util.asks(OF.replay, "shown") then
        local at = OF.replay.shown()
        if at ~= nil then return math.floor(at) end
    end
    local play = OF.replay.play
    if play == nil then return nil end
    return (play.from or 0) + math.max((play.t or 1) - 1, 0)
end

local function flame_obj(b, x, y, z)
    local obj = OF.util.handle_obj(flameObjs[b])
    if obj == nil then
        obj = OF.util.optional("spawn_non_sync_object", nil,
            id_bhvStaticObject, E_MODEL_BLUE_FLAME, x, y, z, nil)
        flameObjs[b] = OF.util.handle(obj, id_bhvStaticObject)
        if obj ~= nil then
            OF.util.optional("obj_set_billboard", nil, obj)
            obj.oAnimState = 0
            flameModel[b] = E_MODEL_BLUE_FLAME
        end
    end
    return obj
end

local function drop_flame(b)
    OF.util.handle_drop(flameObjs[b])
    flameObjs[b] = nil
end

local function show_flame(b, x, y, z, red, speed)
    local obj = flame_obj(b, x, y, z)
    if obj == nil then return end
    obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
    obj.oAnimState = (obj.oAnimState + 1) % 8
    local want = red and E_MODEL_RED_FLAME or E_MODEL_BLUE_FLAME
    if flameModel[b] ~= want then
        OF.util.optional("obj_set_model_extended", nil, obj, want)
        flameModel[b] = want
    end
    OF.util.optional("obj_scale", nil, obj,
        OF.util.clamp(3 + ((speed or 40) - 40) / 50, 3, 5))
end

local function beep_every(framesLeft)
    if framesLeft > 60 then return nil end
    return math.max(2, math.floor(framesLeft / 4))
end

local lastSerial = { 0, 0 }

function mode.scenery()
    tick = tick + 1

    if not OF.util.round_screen() then
        for b = 1, MAX_BALLS do drop_flame(b) end
        return
    end
    local text = OF.gamemodes.stream_read(KEY_BALL)
    if type(text) == "string" and text ~= heardText then hear(text) end

    local replayAt = trail_index()
    for b = 1, MAX_BALLS do
        local d = draw_position(b)
        local h = heard[b]
        if replayAt ~= nil then
            local k = trail_slot(b, replayAt)
            if trailLive[k] == 1 then
                show_flame(b, trailX[k], trailY[k], trailZ[k], trailRed[k] == 1, h.speed)
            else
                drop_flame(b)
            end
        elseif d.live then
            local mine = coming_for_me(b)
            show_flame(b, d.x, d.y, d.z, mine or frames_left(b) < 30, h.speed)

            if h.serial ~= lastSerial[b] then
                if h.why == WHY_PARRY and lastSerial[b] ~= 0 then
                    OF.gamemodes.round_sound_from(OF.util.handle_obj(flameObjs[b]), SOUND_OBJ_FLAME_BLOWN)
                end
                if mine and not out then

                    OF.gamemodes.cue("hazard")
                end
                lastSerial[b] = h.serial
            end
            if mine and not out then
                local every = beep_every(frames_left(b))
                if every ~= nil and tick - beepAt >= every then
                    beepAt = tick

                    OF.gamemodes.round_sound(SOUND_MENU_CHANGE_SELECT)
                end
            end
        else
            drop_flame(b)
        end
    end
    trail_record()
end

function mode.hud()
    local m = gMarioStates[0]
    local mine = nil
    for b = 1, MAX_BALLS do
        if coming_for_me(b) then mine = b end
    end

    if mine ~= nil and not out and m ~= nil and m.pos ~= nil then

        local inside = ring_reached(mine) and heard[mine].phase ~= WAITING
        local spot = { x = m.pos.x, y = m.pos.y + 10, z = m.pos.z }
        if inside then
            OF.util.zone_ring(spot, PARRY_REACH, 32, 3, 255, 70, 50, 230)
        else
            OF.util.zone_ring(spot, PARRY_REACH, 32, 2, 255, 255, 255, 150)
        end

        if OF.util.asks(OF.hud, "state_line") then
            if tick < lockedUntil then
                OF.hud.state_line("early", OF.lang.t("Too early"), { prio = 90, tone = "bad" })
            end
            OF.hud.state_line("mine", OF.lang.t("It's on you"), { prio = 85, tone = "bad", urgent = true })
        end
    end
end

function mode.out_cause() return lastCause end

function mode.cleanup()
    for b = 1, MAX_BALLS do drop_flame(b) end
    if OF.util.is_host() then
        OF.util.publish(KEY_AT, nil)
        OF.gamemodes.stream_send(KEY_BALL, nil)
        for b = 1, MAX_BALLS do sim[b].phase, sim[b].target = GONE, -1 end
    end
    reset_rows()
    OF.util.publish_row(0, ROW_LIVES, 0)
    for b = 1, MAX_BALLS do
        heard[b].phase, heard[b].target = GONE, -1
        lastSerial[b] = 0
    end
    heardText = nil
    atText, atPlace = nil, nil
    out = false
    seenOutRole = {}
    lastOutLocal, lastOutAt = nil, -9999
    outTick = 0
end

function mode.terms()
    local pick = OF.gamemodes.option_showing("deflect", "lives") or "one"
    local n = LIFE_STOPS[pick] or 1
    return OF.lang.fill("last one standing, @ each",
        n == 1 and "one life" or (tostring(n) .. " lives"))
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    local row = gPlayerSyncTable[localIndex]
    local n = row ~= nil and row[ROW_LIVES] or nil
    if type(n) == "number" and lives_dealt() > 1 then return tostring(n) end
    return nil
end

mode.sim = sim
mode.heard = heard
mode.drawn = drawn
mode.pack_balls = pack_balls
mode.next_after_parry = next_after_parry
mode.balls_wanted = balls_wanted
mode.PARRY_REACH = PARRY_REACH
mode.PARRY_TALL = PARRY_TALL
mode.in_ring = in_ring
mode.HIT_REACH = HIT_REACH
mode.WHIFF_LOCK = WHIFF_LOCK
mode.TOP_SPEED = TOP_SPEED
mode.SPEED_STOPS = SPEED_STOPS
mode.phases = { GONE = GONE, WAITING = WAITING, FLYING = FLYING, HOLD = HOLD }
function mode.lives_left() return lives end
function mode.trail_at(b, index)
    local k = trail_slot(b, index)
    return trailLive[k] == 1, trailX[k], trailY[k], trailZ[k]
end

local flameTargets = {}
local flameList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #flameList, 1, -1 do flameList[i] = nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        if index ~= 0 then
            local after, urgent = flame_after(index)
            if after then
                local t = flameTargets[index] or { label = "target", priority = 75,
                    compass = "offscreen" }
                flameTargets[index] = t
                t.id = "flame:" .. tostring(index)
                t.player = index
                t.tone = urgent and { 255, 70, 50 } or { 255, 170, 70 }
                t.urgent = urgent
                flameList[#flameList + 1] = t
            end
        end
    end
    return flameList
end

OF.gamemodes.register(mode)
