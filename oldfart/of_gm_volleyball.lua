OF = OF or {}
OF.volleyball = OF.volleyball or {}

local vb = OF.volleyball

local ROLE_PLAY = "playing"
vb.RADIUS = 75
vb.MATERIAL = "volley"
vb.COURTS = {
    ordinary = { halfX = 2000, halfZ = 1300 },
    big      = { halfX = 2600, halfZ = 1700 },
}

vb.NET_HEIGHT = 300
vb.NET_PAST = 300
vb.SERVE_BACK = 300
vb.SERVE_Y = 420
vb.SERVE_TOSS = 14
vb.NET_GAP = 45

vb.FEEL = {

    ring = { reach = 280, mid = 80, tall = 330, forward = 0 },

    receiveReach = 60,
    receiveNear = 250,

    landRingPerFrame = 6,
    landRingMost = 300,

    yoursRing = 70,

    passLoftDeg = 60,

    bump = { vyMin = 28, vyMax = 30, flatMax = 16 },
    set = { vyMin = 30, vyMax = 33, flatMax = 14 },

    overFacingDeg = 50,
    overClear = 60,
    overLandNear = 900,
    overLandFar = 1300,
    overLandAim = 1100,
    liftVy = 14,
    liftFlat = 10,
    liftClear = 40,

    overHangMost = 2.4,
    shortAims = { 0.6, 0.3, 0.15 },

    solveStep = 0.5,
    solveConfirm = 6,

    spike = { above = 125, near = 700, facingDeg = 60, gain = 1.5, speedMin = 60, speedMax = 70,
              anglesDeg = { 35, 30, 25, 20, 15, 10, 5, 0 }, clear = 20, landNear = 400, landFar = 1400,
              strikeDeg = 30 },

    serve = { landNear = 900, landFar = 1300, hangMost = 2.0, stallSeconds = 6, lobVy = 30, lobPast = 1000 },

    bumpRise = 28,
    bumpAlong = 6,

    aimFacing = 0.75,
    landInside = 80,

    graceLeast = 8,
    graceMost = 15,

    claimCopies = 2,
    earliestWindow = 6,
    easeKeep = 0.8,
    snapPast = 600,
    streamEvery = 2,
    reliableEvery = 15,
}

function vb.bump_lift()
    return math.tan(math.rad(vb.FEEL.passLoftDeg))
end
vb.TOUCHES_A_SIDE = 3
vb.SERVE_SECONDS = 2

vb.TARGET = 11
vb.MAX_REWIND = 45

local PUBLISH_EVERY = 3
local COOLDOWN = 10
local DRIBBLE_GAP = 4

local MAX_REWIND = 45
local CLAIM_SLACK = 250
local ACK_WAIT = 60
local HISTORY = 64
local HOST_LEEWAY = 620

local BALL_KEY = "ofVbBall"
local SCORE_KEY = "ofVbScore"
local AT_KEY = "ofVbAt"
local TARGET_KEY = "ofVbTarget"
local HIT_KEY = "ofVbHit"
local ball = OF.ball.new(0, 0, 0, vb.RADIUS)
ball.serial, ball.toucher, ball.touchN = 0, -1, 0
local seq = 0
local wireSeen = nil
local pending = nil
local frame, hostFrame, cooldown = 0, 0, 0

local press = {}
local hits = 0
local lastHit = {}
local history = {}
local rallyStep = 0
local refusedGI, refusedN = -1, 0
local mustPublish = false
local hostNoCourt = false
local lastResume = nil
local heard = { speed = 0, held = nil }
local drawOff = { x = 0, y = 0, z = 0 }
local seenSeq = -1
local graceAt = nil
local releasedAt = nil
local deuceSaid = false
local lastTake = nil
local copiesLeft = 0
local claimText = nil
local packetClaims = {}

local function numbers(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for word in string.gmatch(text, "%S+") do out[#out + 1] = word end
    return out
end

vb.ROOM = {
    key = "the_stadium2",
    centre = { x = 0, z = 0 },
    floor = 0,
    minX = -10000, maxX = 10000, minZ = -5000, maxZ = 5000,
}

function vb.pitch()
    local parts = numbers(gGlobalSyncTable[AT_KEY])
    local level, area = tonumber(parts[1]), tonumber(parts[2])
    if level == nil then return nil end
    return vb.ROOM, level, area
end

function vb.in_room(localIndex)
    local p, level, area = vb.pitch()
    if p == nil then return false end
    local np = gNetworkPlayers[localIndex or 0]
    return np ~= nil and np.currLevelNum == level
        and (area == nil or np.currAreaIndex == area)
end

vb.COURT_BIG_FROM = 11
function vb.court()
    local pick = OF.gamemodes.option_now("court") or "auto"
    if pick == "auto" then
        pick = #OF.gamemodes.with_role(ROLE_PLAY) >= vb.COURT_BIG_FROM and "big" or "ordinary"
    end
    return vb.COURTS[pick] or vb.COURTS.ordinary
end

function vb.score()
    local parts = numbers(gGlobalSyncTable[SCORE_KEY])
    return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0,
        parts[3] == "blue" and "blue" or "red", (tonumber(parts[4]) or 0) / 10,
        parts[5] == "h", (parts[6] == "red" or parts[6] == "blue") and parts[6] or nil,
        tonumber(parts[7]) or 0
end

function vb.held()
    return numbers(gGlobalSyncTable[SCORE_KEY])[5] == "h"
end

local function target_points()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return vb.TARGET end
    return value
end

function vb.half_of(x, p)
    p = p or vb.pitch()
    if p == nil then return nil end
    return x < p.centre.x and "red" or "blue"
end

local function own_dir(side)
    return side == "blue" and 1 or -1
end

function vb.ball()
    return ball
end

local netPlane = { nx = 1, ny = 0, nz = 0, d = 0, twoSided = true, e = 0.25,
                   grip = 0.5, name = "net" }
local world = { material = vb.MATERIAL, planes = { netPlane } }
function vb.world(p)
    p = p or vb.pitch()
    if p == nil then return world end
    local c = vb.court()
    netPlane.d = -p.centre.x
    netPlane.maxY = p.floor + vb.NET_HEIGHT
    netPlane.minY = p.floor - 50
    netPlane.minZ = p.centre.z - c.halfZ - vb.NET_PAST
    netPlane.maxZ = p.centre.z + c.halfZ + vb.NET_PAST
    return world
end

local function pack_ball()
    return string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f",
        seq, ball.step or 0, ball.x, ball.y, ball.z, ball.vx * 10, ball.vy * 10, ball.vz * 10,
        (ball.spin or 0) * 100, ball.serial or 0, ball.toucher or -1, ball.touchN or 0,
        refusedGI, refusedN)
end

local function adopt(text, into)
    local parts = numbers(text)
    if #parts < 8 then return nil end
    local b = into or ball
    b.step = tonumber(parts[2]) or 0
    b.x, b.y, b.z = tonumber(parts[3]) or 0, tonumber(parts[4]) or 0, tonumber(parts[5]) or 0
    b.vx = (tonumber(parts[6]) or 0) / 10
    b.vy = (tonumber(parts[7]) or 0) / 10
    b.vz = (tonumber(parts[8]) or 0) / 10
    b.spin = (tonumber(parts[9]) or 0) / 100
    b.radius = vb.RADIUS
    b.grounded = false
    local wire = {
        seq = tonumber(parts[1]) or 0, step = b.step,
        serial = tonumber(parts[10]) or 0, toucher = tonumber(parts[11]) or -1,
        touchN = tonumber(parts[12]) or 0, refusedGI = tonumber(parts[13]) or -1,
        refusedN = tonumber(parts[14]) or 0,
    }
    b.serial, b.toucher, b.touchN = wire.serial, wire.toucher, wire.touchN
    if into == nil and vb.predict ~= nil then vb.predict(b) end
    return wire
end
vb.adopt = adopt

vb.net = { refused = {}, accepted = 0, taken = 0, refusedMine = 0, timeouts = 0, sent = 0 }
local function count_refusal(why)
    vb.net.refused[why or "?"] = (vb.net.refused[why or "?"] or 0) + 1
end

local function publish_ball(stream)
    seq = seq + 1
    local text = pack_ball()
    adopt(text)
    if stream and OF.util.asks(OF.gamemodes, "stream_send") then
        OF.gamemodes.stream_send(BALL_KEY, text)
    else
        OF.util.publish(BALL_KEY, text)
    end
end

local function publish_score(red, blue, serve, resume, held, touchSide, touches, decider)
    if decider == nil then decider = tonumber(numbers(gGlobalSyncTable[SCORE_KEY])[8]) or -1 end
    OF.util.publish(SCORE_KEY, string.format("%.0f %.0f %s %.0f %s %s %.0f %.0f", red, blue,
        serve == "blue" and "blue" or "red", resume * 10, held and "h" or "-",
        touchSide or "-", touches or 0, decider))
end

function vb.serve_spot(p, side)
    local c = vb.court()
    return p.centre.x + own_dir(side) * (c.halfX - vb.SERVE_BACK), p.floor + vb.SERVE_Y, p.centre.z
end

local function hold_for_serve(p, side)
    ball.x, ball.y, ball.z = vb.serve_spot(p, side)
    ball.vx, ball.vy, ball.vz, ball.spin, ball.top = 0, 0, 0, 0, 0
    ball.grounded = false
    ball.toucher, ball.touchN = -1, 0
    rallyStep = ball.step or 0
end

local FLY_MOST = 400

local function face_of(m)
    local yaw = (m ~= nil and m.faceAngle ~= nil and m.faceAngle.y or 0) * math.pi / 32768
    return math.sin(yaw), math.cos(yaw)
end

function vb.over_facing(m, b, p)
    p = p or vb.pitch()
    if p == nil or m == nil or b == nil then return nil end
    local fx = face_of(m)
    return b.x < p.centre.x and fx or -fx
end

function vb.fly(b, vx, vy, vz, p)
    local mat = OF.ball.material(vb.MATERIAL)
    local r = b.radius or vb.RADIUS
    local x, y, z = b.x, b.y, b.z
    local from = b.x < p.centre.x and -1 or 1

    local near, far = p.centre.x + from * r, p.centre.x - from * r
    local nearY, crossY = nil, nil
    local frames = 0
    for _ = 1, FLY_MOST do
        frames = frames + 1
        if vy > -mat.fall then vy = math.max(vy - mat.gravity, -mat.fall) end
        local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
        if speed > mat.cap then
            local k = mat.cap / speed
            vx, vy, vz = vx * k, vy * k, vz * k
        end
        local px = x
        x, y, z = x + vx, y + vy, z + vz
        if nearY == nil and (px - near) * from >= 0 and (x - near) * from < 0 then
            nearY = y - (x - near) / vx * vy
        end
        if crossY == nil and (px - far) * from >= 0 and (x - far) * from < 0 then
            crossY = math.min(nearY or math.huge, y - (x - far) / vx * vy)
        end
        vx, vy, vz = vx * mat.air, vy * mat.air, vz * mat.air
        if y - r <= p.floor then break end
    end
    return crossY, x, z, frames
end

local function past_net(b, x, p)
    return b.x < p.centre.x and x - p.centre.x or p.centre.x - x
end

local function lands_over(b, vx, vy, vz, p, clear, near, far)
    local crossY, x, z, frames = vb.fly(b, vx, vy, vz, p)
    if crossY == nil then return false end
    local over = crossY - (b.radius or vb.RADIUS) - (p.floor + vb.NET_HEIGHT)
    local d = past_net(b, x, p)
    local c = vb.court()
    local inside = math.abs(x - p.centre.x) <= c.halfX and math.abs(z - p.centre.z) <= c.halfZ
    return over >= clear and d >= near and d <= far and inside, over, d, frames
end
vb.lands_over = lands_over

function vb.touch_number(m)
    local _, _, _, _, _, touchSide, touches = vb.score()
    local side = OF.teams.of(m ~= nil and m.playerIndex or 0)
    if touchSide ~= nil and touchSide == side then return (touches or 0) + 1 end
    return 1
end

function vb.is_serve(b)
    return b ~= nil and (b.toucher == nil or b.toucher < 0) and not vb.held()
end

function vb.over_line(b, ux, uz, flat0, vy0, p, bounded, near, far, hangMost)
    local F = vb.FEEL
    local mat = OF.ball.material(vb.MATERIAL)
    local g, air, cap = mat.gravity, mat.air, mat.cap
    local r = b.radius or vb.RADIUS
    local ax = math.abs(ux)
    if ax < 0.05 then return nil end
    local L = 1 / (1 - air)
    local logA = math.log(air)
    local wStar = -g * L
    local ground = p.floor + r
    local netTop = p.floor + vb.NET_HEIGHT
    local toNet = math.abs(b.x - p.centre.x)
    local c = vb.court()
    local hang = (hangMost or F.overHangMost) * 30
    local vyHi = bounded and math.min(cap, vy0 + F.liftVy) or cap
    local flatHi = bounded and math.min(cap, flat0 + F.liftFlat) or cap
    local function height(w1, n)
        return b.y + n * wStar + (w1 - wStar) * (1 - air ^ n) * L
    end

    local function landing(vy)
        local w1 = vy - g
        local top = 1
        if w1 > 0 then top = 1 + math.log(-wStar / (w1 - wStar)) / logA end
        if height(w1, hang) > ground then return nil end
        local lo, hi = math.max(top, 0), hang
        for _ = 1, 24 do
            local mid = (lo + hi) / 2
            if height(w1, mid) > ground then lo = mid else hi = mid end
        end
        return hi
    end

    local function frames_to(flat, d)
        local q = 1 - d / (flat * L)
        if q <= 0 then return nil end
        return math.log(q) / logA
    end
    local function candidates(clear, lo, hi, aim)
        local list = {}
        if aim < lo or aim > hi then return list end
        local need = (toNet + aim) / ax
        local landZ = b.z + uz * need
        if math.abs(landZ - p.centre.z) > c.halfZ then return list end
        local vy = 6
        while vy <= vyHi do
            local n = landing(vy)
            if n ~= nil then
                local flat = need / ((1 - air ^ n) * L)
                if flat <= flatHi and flat * flat + vy * vy <= cap * cap then
                    local nNear = frames_to(flat, (toNet - r) / ax)
                    local nFar = frames_to(flat, (toNet + r) / ax)
                    if nNear ~= nil and nFar ~= nil then
                        local w1 = vy - g
                        local low = math.min(height(w1, nNear), height(w1, nFar))
                        if low - r - netTop >= clear then
                            list[#list + 1] = { cost = math.abs(vy - vy0) + math.abs(flat - flat0),
                                                vy = vy, flat = flat }
                        end
                    end
                end
            end
            vy = vy + F.solveStep
        end
        table.sort(list, function(x, y) return x.cost < y.cost end)
        return list
    end
    local function try(clear, lo, hi, aim)
        local list = candidates(clear, lo, hi, aim)
        for i = 1, math.min(#list, F.solveConfirm) do
            local t = list[i]
            local good, _, _, frames = lands_over(b, ux * t.flat, t.vy, uz * t.flat, p, clear, lo, hi)
            if good and frames <= hang + 1 then return ux * t.flat, t.vy, uz * t.flat end
        end
        return nil
    end
    local vx, vy, vz = try(F.overClear, near, far, F.overLandAim)
    if vx == nil then

        for _, share in ipairs(F.shortAims) do
            vx, vy, vz = try(F.liftClear, r, c.halfX - F.landInside, F.overLandAim * share)
            if vx ~= nil then break end
        end
    end
    return vx, vy, vz
end

function vb.spike_wanted(m, b, kind)
    if kind == nil or m == nil or b == nil or m.pos == nil then return false end
    local S = vb.FEEL.spike
    local p = vb.pitch()
    local over = vb.over_facing(m, b, p)
    if over == nil or over < math.cos(math.rad(S.facingDeg)) then return false end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800) then return false end
    if math.abs(m.pos.x - p.centre.x) > S.near then return false end
    return b.y >= p.floor + vb.NET_HEIGHT + (b.radius or vb.RADIUS) + S.above
end

function vb.spike(m, b, speed)
    local p = vb.pitch()
    if p == nil then return nil end
    local S = vb.FEEL.spike
    local fx, fz = face_of(m)
    speed = math.min(S.speedMax, math.max(speed, S.speedMin))
    for _, deg in ipairs(S.anglesDeg) do
        local a = math.rad(deg)
        local vx, vy, vz = fx * speed * math.cos(a), -speed * math.sin(a), fz * speed * math.cos(a)
        if lands_over(b, vx, vy, vz, p, S.clear, S.landNear, S.landFar) then return vx, vy, vz end
    end
    return nil
end

function vb.predict(b, p)
    p = p or vb.pitch()
    if p == nil or b == nil then vb.landing = nil return nil end
    if b.grounded or vb.held() then vb.landing = nil return nil end
    local _, x, z, frames = vb.fly(b, b.vx or 0, b.vy or 0, b.vz or 0, p)
    vb.landing = { x = x, z = z, frames = frames, fromStep = b.step or 0 }
    return vb.landing
end

local function ring_for(m, b)
    local F = vb.FEEL
    local at = vb.landing
    if at ~= nil and b ~= nil and (b.vy or 0) < 0 and m ~= nil and m.pos ~= nil then
        local dx, dz = m.pos.x - at.x, m.pos.z - at.z
        if dx * dx + dz * dz <= F.receiveNear * F.receiveNear then
            return { reach = F.ring.reach + F.receiveReach, mid = F.ring.mid, tall = F.ring.tall,
                     forward = F.ring.forward }
        end
    end
    return F.ring
end

function vb.touch(m, b, spent)
    if not OF.util.asks(OF.football, "touch") then return nil end
    local used = spent
    if type(spent) == "table" then used = spent.spent == true end
    if used and m ~= nil and OF.football.kind_of(m.action) ~= nil then return nil end
    local F = vb.FEEL
    local action = m ~= nil and OF.football.kind_of(m.action) or nil
    local spiking = action ~= nil and vb.spike_wanted(m, b, action)
    local lofts = nil
    if action ~= nil then
        lofts = { [action] = spiking and -math.tan(math.rad(F.spike.strikeDeg))
            or vb.bump_lift() }
    end
    local kind, vx, vy, vz, spin = OF.football.touch(m, b, nil, ring_for(m, b), spent, lofts)
    if kind == nil then return nil end

    local soft = OF.ball.material(vb.MATERIAL).touch or 1
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz) * soft
    if spiking and kind ~= "dribble" then
        local sx, sy, sz = vb.spike(m, b, speed * F.spike.gain)
        if sx ~= nil then return kind, sx, sy, sz, spin or 0, "spike" end
    end
    vx, vy, vz = vx * soft, vy * soft, vz * soft

    vx, vz = vb.aim_along(m, vx, vz)
    local flat = math.sqrt(vx * vx + vz * vz)
    local fx, fz = face_of(m)
    local ux, uz = fx, fz
    if flat > 0.001 then ux, uz = vx / flat, vz / flat end
    local p = vb.pitch()
    local cap = OF.ball.material(vb.MATERIAL).cap
    local serve = vb.is_serve(b)
    if p ~= nil then
        local over = vb.over_facing(m, b, p) or -1
        local facingOver = over >= math.cos(math.rad(F.overFacingDeg))
        local n = vb.touch_number(m)
        local crossing = facingOver and (lands_over(b, vx, vy, vz, p, 0, 0, math.huge))
        if serve or (facingOver and (n >= vb.TOUCHES_A_SIDE or crossing)) then
            if serve and not facingOver then

                ux, uz = (b.x < p.centre.x) and 1 or -1, 0
            end

            local S = F.serve
            local bounded = not serve and n < vb.TOUCHES_A_SIDE
            local near, far = serve and S.landNear or F.overLandNear, serve and S.landFar or F.overLandFar
            local hang = serve and S.hangMost or F.overHangMost
            local hx, hy, hz = vb.over_line(b, ux, uz, flat, vy, p, bounded, near, far, hang)
            if hx == nil and serve then

                hx, hy, hz = vb.over_line(b, (b.x < p.centre.x) and 1 or -1, 0, flat, vy, p, false, near, far, hang)
            end
            if hx ~= nil then return kind, hx, hy, hz, spin or 0, serve and "serve" or "over" end
        end
    end

    local band = (p ~= nil and vb.touch_number(m) == 2) and F.set or F.bump
    local rise = math.max(band.vyMin, math.min(band.vyMax, vy), F.bumpRise)
    local run = math.max(F.bumpAlong, math.min(band.flatMax, flat))
    local out = { vx = ux * run, vy = rise, vz = uz * run }
    OF.ball.clamp(out, cap)
    out.vx, out.vz = vb.keep_in(b, out.vx, out.vy, out.vz)
    return kind, out.vx, out.vy, out.vz, spin or 0, band == F.set and "set" or "bump"
end

local FLIGHT_MOST = 400
local DEPTH_TRIES = 14

function vb.aim_along(m, vx, vz)
    local flat = math.sqrt(vx * vx + vz * vz)
    if flat < 0.001 or m == nil or m.faceAngle == nil then return vx, vz end
    local yaw = (m.faceAngle.y or 0) * math.pi / 32768
    local ax = vx / flat * (1 - vb.FEEL.aimFacing) + math.sin(yaw) * vb.FEEL.aimFacing
    local az = vz / flat * (1 - vb.FEEL.aimFacing) + math.cos(yaw) * vb.FEEL.aimFacing
    local len = math.sqrt(ax * ax + az * az)
    if len < 0.001 then return vx, vz end
    return ax / len * flat, az / len * flat
end

function vb.flight_length(b, vx, vy, vz, floorY)
    local f = OF.ball.new(b.x, b.y, b.z, b.radius or vb.RADIUS)
    f.vx, f.vy, f.vz, f.grounded = vx, vy, vz, false
    local r = f.radius
    local world = { material = vb.MATERIAL, noWorld = true, floorY = floorY }
    for _ = 1, FLIGHT_MOST do
        OF.ball.step(f, world)
        if f.grounded or f.y - r <= floorY + 1 then break end
    end
    local dx, dz = f.x - b.x, f.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

local function exit_along(x, z, dx, dz, minX, maxX, minZ, maxZ)
    local near, far = -math.huge, math.huge
    for _, axis in ipairs({ { x, dx, minX, maxX }, { z, dz, minZ, maxZ } }) do
        local o, d, lo, hi = axis[1], axis[2], axis[3], axis[4]
        if math.abs(d) < 1e-6 then
            if o < lo or o > hi then return nil end
        else
            local t1, t2 = (lo - o) / d, (hi - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            near, far = math.max(near, t1), math.min(far, t2)
        end
    end
    if near > far or far <= 0 then return nil end
    return far
end

function vb.keep_in(b, vx, vy, vz)
    local p = vb.pitch()
    local flat = math.sqrt(vx * vx + vz * vz)
    if p == nil or b == nil or flat < 0.5 then return vx, vz end
    local c = vb.court()
    local inset = vb.FEEL.landInside
    local room = exit_along(b.x, b.z, vx / flat, vz / flat,
        p.centre.x - c.halfX + inset, p.centre.x + c.halfX - inset,
        p.centre.z - c.halfZ + inset, p.centre.z + c.halfZ - inset)
    if room == nil then return vx, vz end
    if vb.flight_length(b, vx, vy, vz, p.floor) <= room then return vx, vz end
    local lo, hi = 0, 1
    for _ = 1, DEPTH_TRIES do
        local mid = (lo + hi) / 2
        if vb.flight_length(b, vx * mid, vy, vz * mid, p.floor) <= room then
            lo = mid
        else
            hi = mid
        end
    end
    return vx * lo, vz * lo
end

function vb.advance(b, p)

    local ev = OF.ball.step(b, vb.world(p))
    if OF.util.is_host() and b == ball then
        history[(b.step or 0) % HISTORY] = { step = b.step, x = b.x, y = b.y, z = b.z }
    end
    return ev
end

vb.PACKET_HIT = "vbhit"
function vb.receive_hit(data)
    if type(data) ~= "table" or data.ofp ~= vb.PACKET_HIT or not OF.util.is_host() then return false end
    if type(data.t) ~= "string" then return false end
    local _, gi = OF.util.asked_by(data)
    if gi == nil then return false end
    local was = packetClaims[gi]
    local n = tonumber(numbers(data.t)[1]) or -1
    if was == nil or n > (tonumber(numbers(was)[1]) or -1) then packetClaims[gi] = data.t end
    return true
end
hook_event(HOOK_ON_PACKET_RECEIVE, function(data) vb.receive_hit(data) end)

local function send_copies()
    if copiesLeft > 0 and claimText ~= nil and not OF.util.is_host() then
        copiesLeft = copiesLeft - 1
        OF.util.send_to_host({ ofp = vb.PACKET_HIT, t = claimText }, true)
    end
end

function vb.my_touch(m)
    send_copies()

    if OF.util.asks(OF.football, "press_note") then OF.football.press_note(press, m) end
    if cooldown > 0 then cooldown = cooldown - 1 return nil end
    if not vb.in_room(0) or vb.held() then return nil end
    local me = gNetworkPlayers[0]
    local gi = me ~= nil and me.globalIndex or -1
    local kind, vx, vy, vz, spin = vb.touch(m, ball, press)
    if kind == nil then return nil end
    if kind ~= "dribble" then press.spent = true end
    cooldown = kind == "dribble" and DRIBBLE_GAP or COOLDOWN
    hits = hits + 1
    local serialSeen = ball.serial or 0
    ball.vx, ball.vy, ball.vz, ball.spin = vx, vy, vz, spin
    ball.grounded = false
    ball.toucher, ball.touchN, ball.touchStep = gi, hits, ball.step or 0
    vb.predict(ball)
    if OF.util.is_host() then

        lastTake = { gi = gi, n = hits, step = ball.step or 0, serialBefore = serialSeen,
                     scoreBefore = gGlobalSyncTable[SCORE_KEY] }
        if graceAt ~= nil then graceAt = nil end
        ball.serial = serialSeen + 1
        vb.count_touch(gi)
        publish_ball()
        return kind
    end
    local text = string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f",
        hits, ball.step or 0, serialSeen, ball.x, ball.y, ball.z,
        ball.vx * 10, ball.vy * 10, ball.vz * 10, (ball.spin or 0) * 100)
    local claim = vb.read_claim(text)
    ball.x, ball.y, ball.z = claim.x, claim.y, claim.z
    ball.vx, ball.vy, ball.vz, ball.spin = claim.vx, claim.vy, claim.vz, claim.spin
    OF.util.publish_row(0, HIT_KEY, text)

    claimText, copiesLeft = text, vb.FEEL.claimCopies
    OF.util.send_to_host({ ofp = vb.PACKET_HIT, t = text })
    vb.net.sent = vb.net.sent + 1
    pending = { n = hits, serial = serialSeen, untilFrame = frame + ACK_WAIT }
    return kind
end

function vb.read_claim(text)
    local parts = numbers(text)
    local n = tonumber(parts[1])
    if #parts < 9 then return nil, n end
    local claim = {
        step = tonumber(parts[2]), serial = tonumber(parts[3]) or 0,
        x = tonumber(parts[4]) or 0, y = tonumber(parts[5]) or 0, z = tonumber(parts[6]) or 0,
        vx = (tonumber(parts[7]) or 0) / 10, vy = (tonumber(parts[8]) or 0) / 10,
        vz = (tonumber(parts[9]) or 0) / 10,
        spin = math.max(-1, math.min(1, (tonumber(parts[10]) or 0) / 100)),
    }
    if claim.step == nil then return nil, n end
    return claim, n
end

function vb.judge(gi, claim, body)
    if vb.held() then return false, "held" end
    if claim == nil then return false, "unreadable" end

    for _, v in ipairs({ claim.step, claim.x, claim.y, claim.z, claim.vx, claim.vy, claim.vz }) do
        if not OF.finite(v) then return false, "unreadable" end
    end
    local now = ball.step or 0
    local at = math.min(claim.step, now)
    if at < rallyStep then return false, "before the serve" end
    if now - at > MAX_REWIND then return false, "too late" end
    if ball.toucher ~= gi and (claim.serial or 0) < (ball.serial or 0) then

        local t = lastTake
        if not (t ~= nil and (claim.serial or 0) == t.serialBefore and claim.step < t.step
            and t.step - claim.step <= vb.FEEL.earliestWindow) then
            return false, "after another touch"
        end
    end
    local was = history[at % HISTORY]
    if was ~= nil and was.step == at then
        local dx, dy, dz = claim.x - was.x, claim.y - was.y, claim.z - was.z
        if dx * dx + dy * dy + dz * dz > CLAIM_SLACK * CLAIM_SLACK then
            return false, "not where the ball was"
        end
    end
    if body == nil or body.pos == nil then return false, "no body" end
    local bx, bz = body.pos.x - claim.x, body.pos.z - claim.z
    if bx * bx + bz * bz > HOST_LEEWAY * HOST_LEEWAY then return false, "too far" end
    return true
end

local pendingEvents = nil
function vb.take(gi, n, claim)
    local now = ball.step or 0
    local fromX, fromY, fromZ = ball.x, ball.y, ball.z
    local at = math.min(claim.step, now)
    local t = lastTake
    if t ~= nil and (claim.serial or 0) == t.serialBefore and t.gi ~= gi and claim.step < t.step then

        OF.util.publish(SCORE_KEY, t.scoreBefore)
        ball.serial = t.serialBefore
        refusedGI, refusedN = t.gi, t.n
        count_refusal("displaced by an earlier touch")
    end
    lastTake = { gi = gi, n = n, step = at, serialBefore = ball.serial or 0,
                 scoreBefore = gGlobalSyncTable[SCORE_KEY] }

    if graceAt ~= nil and at < graceAt.step then graceAt = nil end
    vb.net.accepted = vb.net.accepted + 1
    ball.x, ball.y, ball.z = claim.x, claim.y, claim.z
    ball.vx, ball.vy, ball.vz, ball.spin = claim.vx, claim.vy, claim.vz, claim.spin or 0
    ball.grounded = false
    OF.ball.clamp(ball, OF.ball.material(vb.MATERIAL).cap)
    ball.step = at
    ball.toucher, ball.touchN, ball.touchStep = gi, n, at
    ball.serial = (ball.serial or 0) + 1
    vb.count_touch(gi)
    local p = vb.pitch()
    if p ~= nil then
        while (ball.step or 0) < now do
            local ev = vb.advance(ball, p)
            if ev.landed or ev.out or ev.rest then pendingEvents = ev end
        end
    end
    vb.correct(fromX, fromY, fromZ)
    publish_ball()
end

function vb.should_adopt(wire, myGI, nowFrame)
    if pending == nil then return true end
    local taken = wire.toucher == myGI and wire.touchN >= pending.n
    local refused = wire.refusedGI == myGI and wire.refusedN >= pending.n
    local timedOut = nowFrame >= pending.untilFrame
    local answered = taken or (wire.serial > pending.serial and wire.toucher ~= myGI)
        or refused or vb.held() or timedOut
    if answered then
        if taken then
            vb.net.taken = vb.net.taken + 1
        elseif refused or timedOut then

            if refused then vb.net.refusedMine = vb.net.refusedMine + 1 end
            if timedOut and not refused then vb.net.timeouts = vb.net.timeouts + 1 end
            press.spent = false
            press.since = 999
            cooldown = 0
        end
        pending = nil
    end
    return answered
end

local touchFault = nil
function vb.count_touch(gi)
    if not OF.util.is_host() then return end
    local li = network_local_index_from_global ~= nil and network_local_index_from_global(gi) or nil
    local side = type(li) == "number" and li >= 0 and OF.teams.of(li) or nil
    if side ~= "red" and side ~= "blue" then return end
    local red, blue, serve, resume, held, touchSide, touches = vb.score()
    if touchSide ~= side then
        touchSide, touches = side, 1
    else
        touches = touches + 1
    end
    if touches > vb.TOUCHES_A_SIDE and not OF.gamemodes.option_is("touches", "any") then
        touchFault = side
    end
    publish_score(red, blue, serve, resume, held, touchSide, touches)
end

function vb.rally_over(ev, p)
    if touchFault ~= nil then
        local side = touchFault
        touchFault = nil
        return side == "red" and "blue" or "red", "four touches"
    end
    local c = vb.court()
    local down = ev.landed or ev.rest or ev.out ~= nil
        or (ball.grounded and ball.y - vb.RADIUS <= p.floor + 1)

    if ev.wall and ev.plane ~= "net" and not ev.bodies then down = true end
    if not down then return nil end
    local inX = math.abs(ball.x - p.centre.x) <= c.halfX + vb.RADIUS * 0.5
    local inZ = math.abs(ball.z - p.centre.z) <= c.halfZ + vb.RADIUS * 0.5
    if inX and inZ and ev.out == nil then
        local half = vb.half_of(ball.x, p)
        return half == "red" and "blue" or "red", "down"
    end
    local _, _, serve, _, _, touchSide = vb.score()
    local last = touchSide or serve
    return last == "red" and "blue" or "red", "out"
end

local function point_for(side, why, p)
    local red, blue = vb.score()
    if side == "red" then red = red + 1 else blue = blue + 1 end
    local resume = OF.gamemodes.since_start() + vb.SERVE_SECONDS
    publish_score(red, blue, side, resume, true, nil, 0, ball.toucher or -1)
    hold_for_serve(p, side)
    publish_ball()

    local _ = why
    return red, blue
end
vb.point_for = point_for

function vb.release()
    if not OF.util.is_host() then return false end
    local red, blue, serve, resume, held = vb.score()
    if not held or OF.gamemodes.since_start() < resume then return false end
    publish_score(red, blue, serve, resume, false, nil, 0)
    ball.vy = vb.SERVE_TOSS
    rallyStep = ball.step or 0
    releasedAt = hostFrame
    publish_ball()
    return true
end

function vb.keep_side(m)
    if m == nil or m.pos == nil then return false end
    local p = vb.pitch()
    if p == nil then return false end
    local side = OF.teams.of(0)
    if side ~= "red" and side ~= "blue" then return false end

    local dir = own_dir(side)
    local edge = p.centre.x + dir * vb.NET_GAP
    if dir < 0 and m.pos.x > edge then
        m.pos.x = edge
        if m.vel ~= nil and m.vel.x > 0 then m.vel.x = 0 end
        return true
    elseif dir > 0 and m.pos.x < edge then
        m.pos.x = edge
        if m.vel ~= nil and m.vel.x < 0 then m.vel.x = 0 end
        return true
    end
    return false
end

function vb.formation(p, side, count)
    local slots = {}
    if p == nil or count == nil or count < 1 then return slots end
    local c = vb.court()
    local dir = own_dir(side)
    local rows = count <= 3 and 1 or (count <= 8 and 2 or 3)
    local perRow = math.ceil(count / rows)
    local placed = 0
    for row = 1, rows do
        local inRow = math.min(perRow, count - placed)
        local x = p.centre.x + dir * c.halfX * (row - 0.5) / rows
        for j = 1, inRow do
            local z = p.centre.z - c.halfZ * 0.8 + (2 * c.halfZ * 0.8) * (j - 0.5) / inRow
            slots[#slots + 1] = { x = x, z = z, faceX = p.centre.x, faceZ = z }
            placed = placed + 1
        end
    end
    return slots
end

local function side_order(side)
    local order = {}
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if entry.np ~= nil and OF.teams.of(entry.localIndex) == side then
            order[#order + 1] = entry.np.globalIndex
        end
    end
    table.sort(order)
    return order
end

function vb.slot_for(localIndex)
    local p = vb.pitch()
    if p == nil then return nil end
    local side = OF.teams.of(localIndex)
    if side ~= "red" and side ~= "blue" then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    local place, count = OF.gamemodes.muster_slot(np.globalIndex, side_order(side))
    if place == nil then return nil end
    return vb.formation(p, side, count)[place], p
end

local mode = {
    key = "volleyball",
    name = "Volleyball",
    blurb = "two sides, a net, and the ball must never land on your side",
    blurbTeams = "two sides, a net, and the ball must never land on your side",
    aims = { [ROLE_PLAY] = "Keep it off your floor - three touches, then over the net." },
    how = "Two sides, a net across The Sand Court, one big ball.\n"
        .. "It must not touch the floor on your side - their point.\n"
        .. "Three touches a side, then it has to go over the net.\n"
        .. "Punch or run into it to bump it; a jump kick volleys it.\n"
        .. "Ground pound over it to spike it down into their half.\n"
        .. "Hit it out and the point is theirs. The winner serves.\n"
        .. "First side to the target wins; then the clock.",
    minPlayers = 2,
    sidesFrom = 2,
    maps = { "the_stadium2" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_SOLID or 1 } },
    music = SEQ_LEVEL_WATER,
    defaultLimit = 300,
    teams = "always",
    symmetric = true,
    target = { name = "points to win",
               asks = "How many points win the round",
               default = vb.TARGET,
               min = 3, max = 30, step = 1 },

    pointBanner = "POINT",
    options = {

        { key = "court", name = "Court size",
          help = "how big the court is",
          choices = {
              { key = "auto", name = "for the lobby",
                help = "normal up to 10 players, big from 11" },
              { key = "ordinary", name = "normal", help = "the usual court" },
              { key = "big", name = "big", help = "a third wider each way" },
          } },

        { key = "bytwo", name = "Win by two",
          help = "whether the winner must also be two points ahead",
          choices = {
              { key = "no", name = "no", help = "first to the target wins" },
              { key = "yes", name = "yes", help = "keep playing until a side is two ahead" },
          } },
        { key = "touches", name = "Touches a side",
          help = "how often a side may touch it before it goes over",
          choices = {
              { key = "three", name = "three", help = "as volleyball is played" },
              { key = "any", name = "as many as you like",
                help = "only the floor counts" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the deciding point, again",
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

function mode.may_attack(attacker, victim)
    return false
end

function mode.terms()
    return OF.lang.fill("first to @ points, @",
        tostring(OF.gamemodes.target_for and OF.gamemodes.target_for(mode.key) or vb.TARGET),
        OF.gamemodes.option_showing(mode.key, "touches") == "any"
            and "any number of touches" or "three touches a side")
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAY)
    end
    OF.util.publish(TARGET_KEY, options.target or vb.TARGET)
    publish_score(0, 0, "red", 0, true, nil, 0, -1)
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    local place = OF.util.asks(OF.arena, "find") and OF.arena.find(vb.ROOM.key) or nil
    if here == nil or place == nil or place.level ~= here.level
        or (place.area or 1) ~= (here.area or 1) then
        hostNoCourt = true
        return
    end
    hostNoCourt = false
    OF.util.publish(AT_KEY, string.format("%.0f %.0f", here.level, here.area or 1))
    local p = vb.pitch()
    if p ~= nil then
        publish_score(0, 0, "red", OF.gamemodes.since_start() + vb.SERVE_SECONDS, true, nil, 0, -1)
        hold_for_serve(p, "red")
        publish_ball()
    end
end

function mode.late_join(localIndex)
    return ROLE_PLAY
end

local function seed_hits()
    lastHit = {}
    if not OF.util.is_host() then return end
    for index = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        local row = gPlayerSyncTable[index]
        if np ~= nil and np.connected and row ~= nil then
            local n = tonumber(numbers(row[HIT_KEY])[1])
            if n ~= nil then lastHit[np.globalIndex] = n end
        end
    end
end

function mode.on_start()
    seq, wireSeen, pending, frame, hostFrame, cooldown = 0, nil, nil, 0, 0, 0
    seenSeq, graceAt, lastTake, copiesLeft, claimText, packetClaims = -1, nil, nil, 0, nil, {}
    press = {}
    history, rallyStep, refusedGI, refusedN = {}, 0, -1, 0
    touchFault, pendingEvents, mustPublish = nil, nil, false
    lastResume = nil
    heard = { speed = 0, held = nil }
    drawOff = { x = 0, y = 0, z = 0 }
    ball = OF.ball.new(0, 0, 0, vb.RADIUS)
    ball.serial, ball.toucher, ball.touchN = 0, -1, 0
    seed_hits()
    local p = vb.pitch()
    if p ~= nil then hold_for_serve(p, "red") end
    deuceSaid = false

end

function mode.cleanup()
    vb.hide_all()
    lastHit, wireSeen, pending, history = {}, nil, nil, {}
    if OF.util.is_host() then
        OF.util.publish(BALL_KEY, nil)
        OF.util.publish(SCORE_KEY, nil)
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(TARGET_KEY, nil)
    end
    OF.util.publish_row(0, HIT_KEY, "")
end

function mode.update()
    local red, blue, _, resume = vb.score()
    if lastResume ~= resume then

        if lastResume ~= nil and ((red or 0) + (blue or 0)) > 0 then vb.line_up() end
        lastResume = resume
        vb.face_the_net()
    end
    local m = gMarioStates[0]
    if vb.in_room(0) and OF.gamemodes.can_play(0) then
        vb.keep_side(m)
        vb.my_touch(m)

        if not press.spent and (press.since or 999) >= OF.football.FEEL.bodyIgnore
            and OF.util.asks(OF.football, "keep_out") then
            OF.football.keep_out(m, ball)
        end
    elseif cooldown > 0 then
        cooldown = cooldown - 1
    end
end

function vb.serve_order(side, red, blue)
    local order = side_order(side)
    local n = #order
    local seed = (OF.gamemodes.round_seed() % 9973) * 31 + (red or 0) * 977 + (blue or 0) * 131
        + (side == "blue" and 7 or 3)
    local state = (seed % 2147483646) + 1
    for i = n, 2, -1 do
        state = (state * 48271) % 2147483647
        local j = 1 + (state % i)
        order[i], order[j] = order[j], order[i]
    end
    return order
end

function vb.serve_slot(localIndex)
    local p = vb.pitch()
    if p == nil then return nil end
    local side = OF.teams.of(localIndex)
    if side ~= "red" and side ~= "blue" then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    local red, blue = vb.score()
    local place, count = OF.gamemodes.muster_slot(np.globalIndex, vb.serve_order(side, red, blue))
    if place == nil then return nil end
    return vb.formation(p, side, count)[place], p
end

function vb.line_up()
    if not vb.in_room(0) or not OF.gamemodes.can_play(0) then return false end
    if OF.gamemodes.role(0) ~= ROLE_PLAY then return false end
    local slot, p = vb.serve_slot(0)
    local m = gMarioStates[0]
    if slot == nil or m == nil or m.pos == nil then return false end
    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, slot.x, p.floor, slot.z)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.y, m.vel.z = 0, 0, 0 end
    OF.util.camera_behind_soon()
    return true
end

function vb.face_the_net()
    local m = gMarioStates[0]
    local p = vb.pitch()
    if m == nil or m.faceAngle == nil or p == nil or not vb.in_room(0) then return false end
    if atan2s ~= nil then
        local yaw = atan2s(0, p.centre.x - m.pos.x)
        m.faceAngle.y = yaw
        m.intendedYaw = yaw
    end
    return true
end

function vb.hear_guests()
    local fresh = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local li = entry.localIndex
        local np = gNetworkPlayers[li]
        if li ~= 0 and np ~= nil and np.connected then
            local row = gPlayerSyncTable[li]
            local gi = np.globalIndex

            local text = row ~= nil and row[HIT_KEY] or nil
            local packed = packetClaims[gi]
            if packed ~= nil then
                local pn = tonumber(numbers(packed)[1]) or -1
                if pn > (tonumber(numbers(text)[1]) or -1) then text = packed end
            end
            local claim, n = vb.read_claim(text)
            local last = lastHit[gi]

            if n ~= nil and (last == nil or n > last or n < last - 1000) then
                lastHit[gi] = n
                fresh[#fresh + 1] = { li = li, gi = gi, n = n, claim = claim,
                    at = claim ~= nil and claim.step or -1 }
            end
        end
    end
    table.sort(fresh, function(a, c)
        if a.at ~= c.at then return a.at < c.at end
        return a.gi < c.gi
    end)
    for _, touch in ipairs(fresh) do
        local ok, why = false, "not playing"
        if OF.gamemodes.can_play(touch.li) and vb.in_room(touch.li) then
            ok, why = vb.judge(touch.gi, touch.claim, gMarioStates[touch.li])
        end
        if ok then
            vb.take(touch.gi, touch.n, touch.claim)
        else
            count_refusal(why)
            refusedGI, refusedN = touch.gi, touch.n
            mustPublish = true
        end
    end
end

function vb.grace_frames()
    local slowest = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local np = gNetworkPlayers[entry.localIndex]
        if entry.localIndex ~= 0 and np ~= nil and np.connected then
            slowest = math.max(slowest, tonumber(np.ping) or 0)
        end
    end
    local frames = math.floor(slowest / 1000 * 30 / 2) + 4
    return math.max(vb.FEEL.graceLeast, math.min(vb.FEEL.graceMost, frames))
end

function mode.host_update()
    if hostNoCourt then
        hostNoCourt = false

        local name, tried = nil, nil
        if OF.util.asks(OF.arena, "missing_level") then
            name, tried = OF.arena.missing_level(vb.ROOM.key)
        end
        if name ~= nil then
            OF.gamemodes.abandon("Volleyball needs @: no @ here.",
                name, tried)
        else
            OF.gamemodes.abandon("Volleyball needs The Sand Court, and this map is not it.")
        end
        return
    end
    local p = vb.pitch()
    if p == nil then return end
    hostFrame = hostFrame + 1
    vb.release()
    vb.hear_guests()
    local red, blue, serve, _, held = vb.score()
    if held then
        hold_for_serve(p, serve)
        if hostFrame % 15 == 0 then publish_ball() end
        return
    end

    local S = vb.FEEL.serve
    if releasedAt ~= nil and (ball.toucher or -1) < 0 and hostFrame - releasedAt > S.stallSeconds * 30 then
        releasedAt = nil
        local dir = serve == "blue" and -1 or 1
        local lx, ly = vb.over_line(ball, dir, 0, 0, S.lobVy, p, false, S.lobPast - 200, S.lobPast + 200, 3)
        if lx ~= nil then
            ball.vx, ball.vy, ball.vz, ball.grounded = lx, ly, 0, false
            mustPublish = true
        end
    end
    local ev = vb.advance(ball, p)
    if pendingEvents ~= nil then
        for k, v in pairs(pendingEvents) do if ev[k] == nil then ev[k] = v end end
        pendingEvents = nil
    end
    if ev.bodies then mustPublish = true end
    local winner, why = vb.rally_over(ev, p)

    if winner ~= nil and why ~= "four touches" and graceAt == nil then
        graceAt = { winner = winner, why = why, step = ball.step or 0, untilFrame = hostFrame + vb.grace_frames() }
        winner = nil
    end
    if graceAt ~= nil then
        if hostFrame < graceAt.untilFrame then

            ball.vx, ball.vy, ball.vz = 0, 0, 0
            return
        end
        winner, why, graceAt = graceAt.winner, graceAt.why, nil
    end
    if winner ~= nil then
        red, blue = point_for(winner, why, p)
        if vb.decided(red, blue) then
            OF.gamemodes.finish(OF.teams.result_text(red, blue),
                OF.gamemodes.team_winner(OF.teams.find(red > blue and "red" or "blue")))
        end
        return
    end
    if mustPublish or hostFrame % vb.FEEL.reliableEvery == 0 then
        mustPublish = false
        publish_ball()
    elseif hostFrame % vb.FEEL.streamEvery == 0 then
        publish_ball(true)
    end
end

function vb.decided(red, blue)
    local target = target_points()
    if red < target and blue < target then return false end
    if OF.gamemodes.option_is("bytwo", "yes") then
        return math.abs(red - blue) >= 2
    end
    return true
end

function mode.overtime()
    local red, blue = vb.score()
    return red == blue
end

function mode.still_winnable()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

function mode.on_timeout()
    local red, blue = vb.score()
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, red)
        return
    end
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(OF.teams.find(red > blue and "red" or "blue")))
end

function mode.standing(localIndex)
    local side = OF.teams.of(localIndex)
    if side ~= "red" and side ~= "blue" then return nil end
    local red, blue = vb.score()
    return string.format("%.0f", side == "red" and red or blue)
end

function mode.replayDecider()
    local gi = tonumber(numbers(gGlobalSyncTable[SCORE_KEY])[8])
    if gi == nil or gi < 0 then return nil end
    local li = network_local_index_from_global(gi)
    if type(li) ~= "number" or li < 0 then return nil end
    return li
end

function mode.side_place(side)
    local p, level, area = vb.pitch()
    if p == nil then return nil end
    local c = vb.court()
    return { x = p.centre.x + own_dir(side) * c.halfX * 0.5, y = p.floor, z = p.centre.z,
             level = level, area = area }
end

function mode.side_slot(side, place, count)
    local p = vb.pitch()
    if p == nil or (side ~= "red" and side ~= "blue") then return nil end
    local slot = vb.formation(p, side, count)[place]
    if slot == nil then return nil end
    return { x = slot.x, y = p.floor, z = slot.z, faceX = slot.faceX, faceZ = slot.faceZ }
end

function mode.death_place()
    local slot, p = vb.slot_for(0)
    if slot == nil then return nil end
    local _, level, area = vb.pitch()
    return { x = slot.x, y = p.floor, z = slot.z, level = level, area = area }
end

local LINE_GEO = "of_pitch_line_geo"
pcall(function() OF.ball.resolve_at_load({ LINE_GEO }) end)
local MODEL_UNIT = 100
local LINE_WIDTH = 30
local NET_STRINGS = 10
local lineId = nil

local function line_model()
    if lineId ~= nil then return lineId end
    if not OF.util.optional("mod_file_exists", false, "actors/" .. LINE_GEO .. ".bin") then
        return nil
    end
    local id = OF.util.optional("smlua_model_util_get_id", nil, LINE_GEO)
    if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
    lineId = id
    return id
end

function vb.pieces(p, id)
    local list = {}
    if p == nil or id == nil then return list end
    local c = vb.court()
    local cx, cz, y = p.centre.x, p.centre.z, p.floor + 2
    local w = LINE_WIDTH
    local function piece(name, x, py, z, sx, sy, sz, pitch, yaw, roll)
        list[#list + 1] = { name = name, model = id, x = x, y = py, z = z,
            sx = sx, sy = sy, sz = sz, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
    end

    piece("vbSideN", cx, y, cz - c.halfZ, c.halfX * 2 / MODEL_UNIT, 1, w / MODEL_UNIT)
    piece("vbSideS", cx, y, cz + c.halfZ, c.halfX * 2 / MODEL_UNIT, 1, w / MODEL_UNIT)
    piece("vbBackW", cx - c.halfX, y, cz, w / MODEL_UNIT, 1, c.halfZ * 2 / MODEL_UNIT)
    piece("vbBackE", cx + c.halfX, y, cz, w / MODEL_UNIT, 1, c.halfZ * 2 / MODEL_UNIT)
    piece("vbMid", cx, y, cz, w / MODEL_UNIT, 1, c.halfZ * 2 / MODEL_UNIT)

    local reach = c.halfZ + vb.NET_PAST
    local h = vb.NET_HEIGHT
    piece("vbTape", cx, p.floor + h - 20, cz, 40 / MODEL_UNIT, 1, reach * 2 / MODEL_UNIT, 0, 0, 0x4000)
    piece("vbCordLow", cx, p.floor + h * 0.35, cz, 12 / MODEL_UNIT, 1, reach * 2 / MODEL_UNIT, 0, 0, 0x4000)
    piece("vbCordMid", cx, p.floor + h * 0.67, cz, 12 / MODEL_UNIT, 1, reach * 2 / MODEL_UNIT, 0, 0, 0x4000)
    for _, e in ipairs({ -1, 1 }) do
        piece("vbPost" .. (e < 0 and "N" or "S"), cx, p.floor + h / 2, cz + e * reach,
            w * 2 / MODEL_UNIT, 1, h / MODEL_UNIT, 0x4000, 0x4000, 0)
    end
    for i = 1, NET_STRINGS do
        local z = cz - reach + 2 * reach * i / (NET_STRINGS + 1)
        piece("vbString" .. i, cx, p.floor + h * 0.35 + h * 0.33, z,
            10 / MODEL_UNIT, 1, h * 0.65 / MODEL_UNIT, 0x4000, 0x4000, 0)
    end
    return list
end

local drawn = {}
function vb.hide_all()
    for name in pairs(drawn) do OF.gamemodes.hide_token(name) end
    drawn = {}
    OF.ball.hide("vbBall")
end

local function place(piece)
    local token = OF.gamemodes.show_token(piece.name, piece.model,
        { x = piece.x, y = piece.y, z = piece.z })
    if token == nil then return nil end
    token.oFaceAnglePitch, token.oFaceAngleYaw, token.oFaceAngleRoll =
        piece.pitch, piece.yaw, piece.roll
    OF.util.optional("obj_scale_xyz", nil, token, piece.sx, piece.sy, piece.sz)
    drawn[piece.name] = true
    return token
end

function vb.correct(fromX, fromY, fromZ)
    drawOff.x = drawOff.x + fromX - ball.x
    drawOff.y = drawOff.y + fromY - ball.y
    drawOff.z = drawOff.z + fromZ - ball.z
end

function vb.drawn()
    local o = drawOff
    local snap, keep = vb.FEEL.snapPast, vb.FEEL.easeKeep
    if o.x * o.x + o.y * o.y + o.z * o.z > snap * snap then o.x, o.y, o.z = 0, 0, 0 end
    local at = { x = ball.x + o.x, y = ball.y + o.y, z = ball.z + o.z }
    o.x, o.y, o.z = o.x * keep, o.y * keep, o.z * keep
    if math.abs(o.x) + math.abs(o.y) + math.abs(o.z) < 0.5 then o.x, o.y, o.z = 0, 0, 0 end
    return at
end

function vb.follow_the_wire()

    local wire = gGlobalSyncTable[BALL_KEY]
    local streamed = OF.util.asks(OF.gamemodes, "stream_read") and OF.gamemodes.stream_read(BALL_KEY) or nil
    if streamed ~= nil and (wire == nil
        or (tonumber(numbers(streamed)[1]) or 0) > (tonumber(numbers(wire)[1]) or 0)) then
        wire = streamed
    end
    if wire == nil or wire == wireSeen then return false end
    local read = adopt(wire, {})
    if read == nil then
        wireSeen = wire
        return false
    end

    if read.seq <= seenSeq then
        wireSeen = wire
        return false
    end
    local me = gNetworkPlayers[0]
    if not vb.should_adopt(read, me ~= nil and me.globalIndex or -1, frame) then return false end
    wireSeen = wire
    seenSeq = read.seq
    local fromX, fromY, fromZ = ball.x, ball.y, ball.z
    adopt(wire)
    vb.correct(fromX, fromY, fromZ)
    return true
end

local function hear_the_court(token)
    local played = nil
    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy + ball.vz * ball.vz)
    if speed >= 30 and speed - heard.speed >= 15 then
        played = OF.gamemodes.round_sound_throttled("vbhit", 6, SOUND_ACTION_BOUNCE_OFF_OBJECT, token)
    end
    heard.speed = speed
    local held = vb.held()
    if held then
        local _, _, _, resume = vb.score()
        local left = math.max(0, resume - OF.gamemodes.since_start())
        OF.gamemodes.tick_down(math.ceil(left - 0.1))
    elseif heard.held == true then
        played = OF.gamemodes.round_sound(OF.sounds.SHOT) or played
    end
    heard.held = held
    return played
end
vb.hear_the_court = hear_the_court

function mode.scenery()
    OF.gamemodes.hear_sides(vb.score())
    local p = vb.pitch()

    if p == nil or not vb.in_room(0) or not OF.util.round_screen() then
        vb.hide_all()
        return
    end
    frame = frame + 1
    if not OF.util.is_host() then
        vb.follow_the_wire()
        local _, _, serve, _, held = vb.score()
        if held then
            hold_for_serve(p, serve)
        elseif OF.gamemodes.state() == OF.gamemodes.ACTIVE then
            vb.advance(ball, p)
        end
    end
    for _, piece in ipairs(vb.pieces(p, line_model())) do place(piece) end
    local token = OF.ball.draw("vbBall", ball, vb.drawn())
    hear_the_court(token)
end

function vb.controls_lines()
    return {
        OF.lang.t("B - bump it up"),
        OF.lang.t("A, then B - a high volley"),
        OF.lang.t("Z in the air over it - spike"),
        OF.lang.t("No button: run into it to set"),
    }
end

function vb.draw_controls()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_PLAY then return false end
    if not OF.util.can_play(0) or not vb.in_room(0) then return false end
    return OF.util.legend(vb.controls_lines()) == true
end

local vbEntry = {}
function vb.under_line()
    local _, _, serve, resume, held, touchSide, touches = vb.score()
    local mine = OF.teams.of(0)
    if held then
        vbEntry.id, vbEntry.prio, vbEntry.tone = "serve", 60, serve
        vbEntry.text = serve == mine and OF.lang.t("Your serve") or OF.lang.t("Serve")
        vbEntry.figure = math.max(1, math.ceil(math.max(0, resume - OF.gamemodes.since_start()) - 0.1))
        return vbEntry
    end
    if touchSide ~= nil and touchSide == mine and not OF.gamemodes.option_is("touches", "any") then
        vbEntry.id, vbEntry.prio, vbEntry.tone = "touches", 50, mine
        vbEntry.text = OF.lang.t("Touches")
        vbEntry.figure = tostring(touches) .. "/" .. tostring(vb.TOUCHES_A_SIDE)
        return vbEntry
    end
    return nil
end

vb.SHADOW_LEAST, vb.SHADOW_MOST = 70, 240
function vb.draw_shadow()
    local p = vb.pitch()
    if p == nil or not vb.in_room(0) or ball == nil or ball.x == nil then return nil end
    local up = (ball.y or p.floor) - p.floor
    if up < 0 then return nil end
    local radius = math.min(vb.SHADOW_MOST, vb.SHADOW_LEAST + up * 0.12)
    local r, g, b = 255, 230, 120
    local li = ball.toucher ~= nil and ball.toucher >= 0
        and network_local_index_from_global ~= nil
        and network_local_index_from_global(ball.toucher) or nil
    if type(li) == "number" and li >= 0 then
        local side = OF.teams.of(li)
        if side == "red" or side == "blue" then r, g, b = OF.football.side_rgb(side) end
    end
    OF.util.zone_ring({ x = ball.x, y = p.floor + 4, z = ball.z }, radius, 24, 3, r, g, b, 210)
    return radius
end

function vb.draw_landing()
    local p = vb.pitch()
    local at = vb.landing
    if p == nil or at == nil or not vb.in_room(0) or vb.held() then return nil end
    if (ball.vy or 0) >= 0 and (ball.y or 0) - p.floor < vb.RADIUS * 2 then return nil end
    local side = vb.half_of(at.x, p)
    local r, g, b = OF.football.side_rgb(side)
    local left = math.max(0, (at.frames or 0) - ((ball.step or 0) - (at.fromStep or ball.step or 0)))
    local radius = vb.RADIUS + math.min(vb.FEEL.landRingMost, left * vb.FEEL.landRingPerFrame)
    OF.util.zone_ring({ x = at.x, y = p.floor + 6, z = at.z }, radius, 24, 3, r, g, b, 230)

    local best, bestD = nil, math.huge
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil and OF.teams.of(entry.localIndex) == side and vb.in_room(entry.localIndex) then
            local d = (m.pos.x - at.x) ^ 2 + (m.pos.z - at.z) ^ 2
            if d < bestD then best, bestD = m, d end
        end
    end

    if best ~= nil then
        OF.util.zone_ring({ x = best.pos.x, y = best.pos.y + 4, z = best.pos.z }, vb.FEEL.yoursRing, 16, 3,
            r, g, b, 255)
    end
    return radius
end

function mode.hud()
    vb.draw_controls()
    vb.draw_shadow()
    vb.draw_landing()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local red, blue = vb.score()
    local line = vb.under_line()
    if line ~= nil then state(line.id, line.text, line) end
    local target = target_points()
    if OF.gamemodes.option_is("bytwo", "yes") and red == blue and red >= target - 1 and red > 0 then
        if not deuceSaid and OF.util.asks(OF.hud, "banner") then
            deuceSaid = true
            OF.hud.banner("overtime", OF.lang.t("DEUCE"), OF.lang.t("Two ahead wins"))
        end
    elseif red ~= blue then
        deuceSaid = false
    end
end

function mode.targets(viewer)
    if vb.pitch() == nil then return nil end
    return { { id = "ball", pos = { x = ball.x, y = ball.y, z = ball.z }, label = "Ball",
               tone = "target", priority = 80, compass = "offscreen" } }
end

function vb.press_memo() return press end
function vb.set_pending_for_suite(p) pending = p end

function vb.forget_for_suite()
    touchFault, pendingEvents = nil, nil
end

vb.mode = mode

function mode.cluster()
    return OF.gamemodes.side_cluster(function(key)
        local red, blue = vb.score()
        return key == "red" and red or blue
    end, target_points())
end

mode.target_now = target_points

OF.gamemodes.register(mode)
