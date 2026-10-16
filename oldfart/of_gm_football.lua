OF = OF or {}
OF.football = OF.football or {}

local football = OF.football

local ROLE_PLAY = "playing"
local BALL_RADIUS = 100

local GRAVITY = 2.5
local BOUNCE = 0.55
local BOUNCE_MIN = 6
local ROLL = 0.98
local AIR = 0.995
local WALL_BOUNCE = 0.7
local POST_BOUNCE = 0.75
local NET_BOUNCE = 0.1
local NET_HOLD = 0.85
local RING_SPEED = 15

local GROUND_GRIP = 0.15
local WALL_GRIP = 0.1
local NET_GRIP = 0.6

local ROOF_TILT = 0.6
football.MAX_SPEED = 170
football.MARIO_TOP = 48
local MAX_SPEED = football.MAX_SPEED
local STOP_SPEED = 0.4

football.BALL_DEFAULT = "standard"
football.PITCH_DEFAULT = "normal"
local feel = { gravity = GRAVITY, bounce = BOUNCE, roll = ROLL, air = AIR,
               wall = WALL_BOUNCE, touch = 1, cap = MAX_SPEED }
function football.feel()
    local name = OF.gamemodes.option_now("ball") or football.BALL_DEFAULT
    local mat = OF.ball.material(name)
    local surf = OF.ball.surface(OF.gamemodes.option_now("pitch") or football.PITCH_DEFAULT)
    feel.material = OF.ball.MATERIALS[name] ~= nil and name or football.BALL_DEFAULT
    feel.gravity = mat.gravity
    feel.bounce = math.min(0.9, mat.bounce * surf.bounce)
    feel.roll = 1 - (1 - mat.roll) * surf.friction
    feel.air = mat.air
    feel.wall = mat.wall
    feel.touch = mat.touch or 1
    feel.cap = math.min(MAX_SPEED, mat.cap or MAX_SPEED)
    feel.breakLand, feel.breakHit = mat.breakLand, mat.breakHit
    return feel
end

local function knock(b, f, into, landing)
    local line = landing and f.breakLand or f.breakHit
    if line ~= nil and (into or 0) > line then b.broke = true end
end
football.knock = knock
local POST_RADIUS = 25
local SIGNS = { -1, 1 }

football.TOUCHES = {
    shot   = { fwd = 0,  up = 60, reach = 70, swing = 70, loft = 0.14, aim = 0.25, e = 0.6, min = 60 },
    volley = { fwd = 60, up = 70, reach = 45, swing = 45, loft = 0.6,  aim = 0.2,  e = 0.6, min = 45 },
    dive   = { fwd = 80, up = 40, reach = 50, swing = 10, loft = 0.08, aim = 0.1,  e = 0.6, min = 40 },
    slide  = { fwd = 80, up = 15, reach = 45, swing = 25, loft = 0.35, aim = 0.15, e = 0.6, min = 45 },
    kick   = { fwd = 60, up = 45, reach = 45, swing = 40, loft = 0.20, aim = 0.15, e = 0.6, min = 40 },
}

football.FEEL = {
    touches = football.TOUCHES,

    ring = { reach = 230, mid = 80, tall = 220, forward = 40 },

    forgeRing = { reachPast = 130, mid = 80, tallPast = 120, forward = 40 },

    window = { kick = 8, volley = 10, dive = 12, slide = 12, poundLand = 3 },
    buffer = 5,

    bodyIgnore = 8,

    stickMin = 0.5,
    stickTurnDeg = 45,

    kneeAt = 120,
    kneeSpan = 50,

    volleyLoft = { k = 0.6, ref = 80, lo = 0.4, hi = 0.75 },

    spikeDrop = 0.5,

    passConeDeg = 20,
    passShare = 0.5,
    passMaxDeg = 10,
    passNear = 250,
    passFar = 3500,

    shotConeDeg = 25,
    shotMaxDeg = 8,
    shotFadeFrom = 4500,
    shotRange = 7000,
    postInside = 1.3,

    stuckFrames = 15,
    stuckPop = 20,
    stuckPush = 8,

    hitTiers = { 0, 60, 110, 150 },
    hitStop = { 0, 2, 3, 4 },
    soundTiers = { 60, 120 },
    sparkAt = 100,
    trailAt = 110,

    shadowOver = 180,

    claimCopies = 2,
}
football.RING = football.FEEL.ring

local BODY_RADIUS = 40
local BODY_TALL = 160
local BODY_BOUNCE = 0.5

local DRIBBLE_BOUNCE = 0.15
local DRIBBLE_SOFT = 0.04
local DRIBBLE_KNOCK = 0.2
local DRIBBLE_WALK = 12
football.DRIBBLE_RUN = 28

local STILL_SPEED = 2

local STEER = 0.4
local STEER_CLOSE = 0.6
local STEER_SPRINT = 0.3
local STEER_FULL = 8

function football.dribble_steer(run)
    run = tonumber(run) or 0
    if run <= STEER_FULL then return STEER_CLOSE * math.max(0, run) / STEER_FULL end
    if run <= DRIBBLE_WALK then return STEER_CLOSE end
    if run <= football.DRIBBLE_RUN then
        return STEER_CLOSE + (STEER - STEER_CLOSE) * (run - DRIBBLE_WALK)
            / (football.DRIBBLE_RUN - DRIBBLE_WALK)
    end
    return math.max(STEER_SPRINT, STEER + (STEER_SPRINT - STEER)
        * (run - football.DRIBBLE_RUN) / (football.MARIO_TOP - football.DRIBBLE_RUN))
end

function football.dribble_bounce(run)
    run = tonumber(run) or 0
    if run <= DRIBBLE_WALK then return DRIBBLE_SOFT end
    if run <= football.DRIBBLE_RUN then
        return DRIBBLE_SOFT + (DRIBBLE_BOUNCE - DRIBBLE_SOFT)
            * (run - DRIBBLE_WALK) / (football.DRIBBLE_RUN - DRIBBLE_WALK)
    end
    return math.min(DRIBBLE_KNOCK, DRIBBLE_BOUNCE + (DRIBBLE_KNOCK - DRIBBLE_BOUNCE)
        * (run - football.DRIBBLE_RUN) / (football.MARIO_TOP - football.DRIBBLE_RUN))
end

football.SPRINT_FULL = 90
local COOLDOWN = 10
local DRIBBLE_GAP = 4

local HOST_LEEWAY = BALL_RADIUS + 70 + 450
local PUBLISH_EVERY = 3

local MAX_REWIND = 24
local CLAIM_SLACK = 250
local ACK_WAIT = 45
local GOAL_WAIT = 8
football.GOAL_WAIT = GOAL_WAIT
local HISTORY = 64

local KICKOFF_SECONDS = 2

local BALL_KEY = "ofFbBall"
local SCORE_KEY = "ofFbScore"
local AT_KEY = "ofFbAt"
local TARGET_KEY = "ofFbTarget"
local KICK_KEY = "ofFbKick"
local TARGET_GOALS = 5

local PEN_KEY = "ofFbPen"
football.PEN_SPOT = 1100
football.PEN_KICKS = 5
local PEN_SHOOT_SECONDS = 8
local PEN_FLIGHT_FRAMES = 90
local PEN_BREAK_SECONDS = 3

football.PEN_BAND = 700

football.PITCHES = {

    the_stadium = {
        centre = { x = 0, z = 0 },
        floor = 0, ceiling = 4000,
        minX = -10000, maxX = 10000, minZ = -5000, maxZ = 5000,
        goalX = 9700, goalDepth = 300, goalHeight = 500,

        goalHalfWidth = 600,
        spawns = { red = { x = -5000, z = 0 }, blue = { x = 5000, z = 0 } },
        spawnGoals = true, drawLines = true,
        circleRadius = 1500, boxDepth = 2000,
    },
}
football.PITCH_ORDER = { "the_stadium" }

local GOAL_STOPS = { ordinary = 0, wide = 300, narrow = -150 }
local GOAL_DEFAULT = "ordinary"
local GOAL_HALF_FALLBACK = 600
local GOAL_HALF_MIN = 250

local LINE_GEO = "of_pitch_line_geo"
local NET_GEO = { red = "of_turf_red_geo", blue = "of_turf_blue_geo" }

pcall(function() OF.ball.resolve_at_load({ LINE_GEO, NET_GEO.red, NET_GEO.blue }) end)
local MODEL_UNIT = 100
local LINE_WIDTH = 30
local LINE_LIFT = 2
local CIRCLE_RADIUS = 900
local CIRCLE_PIECES = 12
local BOX_DEPTH = 1500
local BOX_WIDER = 900

local ball = { x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, step = 0,
               toucher = -1, touchN = 0, touchStep = -9999, serial = 0 }

local drawOff = { x = 0, y = 0, z = 0 }

local replay = nil
local seq = 0
local wireSeen = nil

local pending = nil
local frame = 0
local hostFrame = 0
local cooldown = 0

local press = {}

local kicks = 0

local faced = false

local heardPitch = { speed = 0, held = nil }

local brokeSeen = false
local mustPublish = false
local lastKick = {}
local lastToucher = -1

local history = {}
local kickoffStep = 0
local touchSerial = 0
local refusedGI, refusedN = -1, 0
local goalSeenAt = nil
local lastResume = nil
local hostNoPitch = false
local modelIds = nil

local penShot, penShotAt, penSaved = false, 0, false
local penSeen = nil
local penMineShot = false

local function numbers(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for word in string.gmatch(text, "%S+") do out[#out + 1] = word end
    return out
end

function football.pitch()
    local parts = numbers(gGlobalSyncTable[AT_KEY])
    local key = parts[1]
    local pitch = key ~= nil and football.PITCHES[key] or nil
    if pitch == nil then return nil end
    return pitch, key, tonumber(parts[2]), tonumber(parts[3])
end

function football.in_room(localIndex)
    local pitch, _, level, area = football.pitch()
    if pitch == nil then return false end
    local np = gNetworkPlayers[localIndex or 0]
    return np ~= nil and np.currLevelNum == level
        and (area == nil or np.currAreaIndex == area)
end

function football.score()
    local parts = numbers(gGlobalSyncTable[SCORE_KEY])
    return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0,
        (tonumber(parts[3]) or 0) / 10
end

function football.kickoff_side()
    local parts = numbers(gGlobalSyncTable[SCORE_KEY])
    return parts[4] == "blue" and "blue" or "red"
end

function football.scorer()
    local parts = numbers(gGlobalSyncTable[SCORE_KEY])
    local gi = tonumber(parts[5])
    if gi == nil or gi < 0 then return nil end
    return gi
end

local function target_goals()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_GOALS end
    return value
end

function football.goal_half_width(p)
    p = p or football.pitch()
    local base = p ~= nil and p.goalHalfWidth or GOAL_HALF_FALLBACK
    local step = GOAL_STOPS[OF.gamemodes.option_now("goals") or GOAL_DEFAULT]
        or GOAL_STOPS[GOAL_DEFAULT]
    return math.max(GOAL_HALF_MIN, base + step)
end

function football.paused()
    if football.penalties() and football.pen() == nil then return true end
    return numbers(gGlobalSyncTable[SCORE_KEY])[6] == "h"
end

function football.kickoff_left()
    if not football.paused() then return nil end
    local _, _, resume = football.score()
    return math.max(0, resume - OF.gamemodes.since_start())
end

local function publish_score(red, blue, resume, side, scorer, held)
    OF.util.publish(SCORE_KEY, string.format("%.0f %.0f %.0f %s %.0f %s", red, blue,
        resume * 10, side == "blue" and "blue" or "red", scorer or -1,
        held and "h" or "-"))
end

function football.release()
    if not OF.util.is_host() then return false end
    local parts = numbers(gGlobalSyncTable[SCORE_KEY])
    if parts[6] ~= "h" then return false end
    local resume = (tonumber(parts[3]) or 0) / 10
    if OF.gamemodes.since_start() < resume then return false end
    publish_score(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, resume,
        parts[4], tonumber(parts[5]) or -1, false)
    return true
end

function football.ball()
    return ball
end

function football.penalties()
    return OF.gamemodes.option_is("format", "penalties")
end

function football.pen()
    local parts = numbers(gGlobalSyncTable[PEN_KEY])
    local serial = tonumber(parts[1])
    if serial == nil then return nil end
    return { serial = serial, side = parts[2] == "blue" and "blue" or "red",
             striker = tonumber(parts[3]) or -1, keeper = tonumber(parts[4]) or -1,
             deadline = (tonumber(parts[5]) or 0) / 10,
             redTaken = tonumber(parts[6]) or 0, blueTaken = tonumber(parts[7]) or 0,
             last = parts[8] or "-" }
end

local function attack_dir(side)
    return side == "blue" and -1 or 1
end

function football.pen_spot(p, side)
    local dir = attack_dir(side)
    return p.centre.x + dir * (p.goalX - football.PEN_SPOT), p.centre.z
end

function football.pen_may_touch(gi, shot)
    if not football.penalties() then return true end
    local pen = football.pen()
    if pen == nil or gi == nil then return false end
    if gi == pen.keeper then return true end
    return gi == pen.striker and not shot
end

function football.pen_decided(red, blue, redTaken, blueTaken)
    local k = football.PEN_KICKS
    if redTaken < k or blueTaken < k then
        local redLeft = math.max(k - redTaken, 0)
        local blueLeft = math.max(k - blueTaken, 0)
        return red + redLeft < blue or blue + blueLeft < red
    end
    return redTaken == blueTaken and red ~= blue
end

local KEEPER_AT = 0.93
local LINES_AT = { 0.62, 0.40, 0.22 }
local LINE_SPREAD = 0.75
local KICKER_BEHIND = BALL_RADIUS + 80

function football.formation(p, side, count, kicking)
    local slots = {}
    if p == nil or count == nil or count < 1 then return slots end
    local own = side == "blue" and 1 or -1
    local cx, cz = p.centre.x, p.centre.z
    local half = math.min(p.maxZ - cz, cz - p.minZ)
    local faceX, faceZ = cx - own * p.goalX, cz
    local rest = count
    if kicking then rest = rest - 1 end
    if rest >= 1 then
        slots[#slots + 1] = { x = cx + own * p.goalX * KEEPER_AT, z = cz,
                              faceX = faceX, faceZ = faceZ }
        rest = rest - 1
    end
    local lines = { 0, 0, 0 }
    for i = 1, rest do
        local line = ((i - 1) % 3) + 1
        lines[line] = lines[line] + 1
    end
    for line = 1, 3 do
        local k = lines[line]
        for j = 1, k do
            local z = cz - half * LINE_SPREAD
                + (2 * half * LINE_SPREAD) * (j - 0.5) / k
            slots[#slots + 1] = { x = cx + own * p.goalX * LINES_AT[line], z = z,
                                  faceX = faceX, faceZ = faceZ }
        end
    end
    if kicking then
        slots[#slots + 1] = { x = cx + own * KICKER_BEHIND, z = cz,
                              faceX = faceX, faceZ = faceZ }
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

function football.slot_for(localIndex, kicking)
    local p = football.pitch()
    if p == nil then return nil end
    local side = OF.teams.of(localIndex)
    if side ~= "red" and side ~= "blue" then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    local place, count = OF.gamemodes.muster_slot(np.globalIndex, side_order(side))
    if place == nil then return nil end
    if kicking == nil then
        kicking = football.paused() and football.kickoff_side() == side
    end
    return football.formation(p, side, count, kicking)[place], p
end

local function face_the_play(m, slot)
    if m == nil or slot == nil then return false end
    if m.faceAngle ~= nil and atan2s ~= nil then
        local yaw = atan2s(slot.faceZ - slot.z, slot.faceX - slot.x)
        m.faceAngle.y = yaw
        m.intendedYaw = yaw
    end
    OF.util.camera_behind_soon()
    return true
end

function football.line_up(kicking)
    local slot, p = football.slot_for(0, kicking)
    local m = gMarioStates[0]
    if slot == nil or m == nil then return false end
    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, slot.x, p.floor, slot.z)
    face_the_play(m, slot)
    m.forwardVel = 0
    return true
end

local FACED_NEAR = 60
function football.face_the_opening()
    if faced then return false end
    local m = gMarioStates[0]
    local slot = nil
    if football.penalties() then
        slot = football.pen_slot(0, football.pen(), football.pitch())
    else
        slot = football.slot_for(0)
    end
    if m == nil or m.pos == nil or slot == nil then
        if not OF.gamemodes.in_muster_window() then faced = true end
        return false
    end
    local dx, dz = m.pos.x - slot.x, m.pos.z - slot.z
    if dx * dx + dz * dz > FACED_NEAR * FACED_NEAR then
        if not OF.gamemodes.in_muster_window() then faced = true end
        return false
    end
    faced = true
    return face_the_play(m, slot)
end

function football.pen_slot(localIndex, pen, p)
    if pen == nil or p == nil then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    local gi = np.globalIndex
    local dir = attack_dir(pen.side)
    local spotX, spotZ = football.pen_spot(p, pen.side)
    local goalX = p.centre.x + dir * p.goalX
    if gi == pen.striker then
        return { x = spotX - dir * KICKER_BEHIND, z = spotZ,
                 faceX = goalX, faceZ = spotZ }
    end
    if gi == pen.keeper then
        return { x = goalX - dir * (BODY_RADIUS + 20), z = spotZ,
                 faceX = spotX, faceZ = spotZ }
    end

    local others = {}
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local e = entry.np
        if e ~= nil and e.globalIndex ~= pen.striker and e.globalIndex ~= pen.keeper then
            others[#others + 1] = e.globalIndex
        end
    end
    table.sort(others)
    local place = 1
    for i, other in ipairs(others) do
        if other == gi then place = i end
    end
    local half = math.min(p.maxZ - p.centre.z, p.centre.z - p.minZ) * LINE_SPREAD
    local z = p.centre.z - half + 2 * half * (place - 0.5) / math.max(#others, 1)
    return { x = p.centre.x, z = z, faceX = spotX, faceZ = spotZ }
end

local function pen_line_up(pen)
    local p = football.pitch()
    local slot = football.pen_slot(0, pen, p)
    local m = gMarioStates[0]
    if slot == nil or m == nil then return false end
    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, slot.x, p.floor, slot.z)
    face_the_play(m, slot)
    m.forwardVel = 0
    return true
end

function football.pen_hold_back(m, pen, p)
    if m == nil or m.pos == nil or pen == nil or p == nil then return false end
    local np = gNetworkPlayers[m.playerIndex or 0]
    if np == nil then return false end
    if np.globalIndex == pen.striker or np.globalIndex == pen.keeper then
        return false
    end
    local dx = m.pos.x - p.centre.x
    if math.abs(dx) <= football.PEN_BAND then return false end
    m.pos.x = p.centre.x + (dx > 0 and football.PEN_BAND or -football.PEN_BAND)
    return true
end

local function clamp_speed(b)
    local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
    local cap = math.min(MAX_SPEED, feel.cap or MAX_SPEED)
    if speed > cap then
        local k = cap / speed
        b.vx, b.vy, b.vz = b.vx * k, b.vy * k, b.vz * k
    end
end

local function rebound(b, nx, ny, nz, e, grip)
    local vn = b.vx * nx + b.vy * ny + b.vz * nz
    if vn >= 0 then return false end
    local tx, ty, tz = b.vx - vn * nx, b.vy - vn * ny, b.vz - vn * nz
    local along = math.sqrt(tx * tx + ty * ty + tz * tz)
    local keep = 1
    if along > 0.0001 then
        keep = 1 - math.min(along, grip * (1 + e) * -vn) / along
    end
    b.vx = tx * keep - e * vn * nx
    b.vy = ty * keep - e * vn * ny
    b.vz = tz * keep - e * vn * nz
    return true
end
football.rebound = rebound

local function hit_bar(b, ax, ay, az, cx, cy, cz, radius, e, grip)
    local sx, sy, sz = cx - ax, cy - ay, cz - az
    local len2 = sx * sx + sy * sy + sz * sz
    local t = 0
    if len2 > 0 then
        t = ((b.x - ax) * sx + (b.y - ay) * sy + (b.z - az) * sz) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local px, py, pz = ax + sx * t, ay + sy * t, az + sz * t
    local dx, dy, dz = b.x - px, b.y - py, b.z - pz
    local away = math.sqrt(dx * dx + dy * dy + dz * dz)
    local reach = BALL_RADIUS + radius
    if away >= reach or away < 0.001 then return false end
    local nx, ny, nz = dx / away, dy / away, dz / away
    b.x, b.y, b.z = px + nx * reach, py + ny * reach, pz + nz * reach
    local into = -(b.vx * nx + b.vy * ny + b.vz * nz)
    rebound(b, nx, ny, nz, e, grip)
    return true, into
end

function football.step(b, p, halfWidth)
    local f = football.feel()
    local fromX, fromY, fromZ = b.x, b.y, b.z
    local floorY = p.floor + BALL_RADIUS
    local grounded = b.y <= floorY + 0.5 and b.vy <= 0
    if not grounded then
        b.vy = b.vy - f.gravity

        OF.ball.curl(b)
    end

    b.x, b.y, b.z = b.x + b.vx, b.y + b.vy, b.z + b.vz

    if b.y < floorY then
        b.y = floorY
        if b.vy < -BOUNCE_MIN then
            knock(b, f, -b.vy, true)
            rebound(b, 0, 1, 0, f.bounce, GROUND_GRIP)
            b.spin = (b.spin or 0) * OF.ball.K.SPIN_LAND
            if math.abs(b.spin) < 0.01 then b.spin = 0 end
        else
            b.vy = 0
        end
    end
    local roof = p.ceiling - BALL_RADIUS
    if b.y > roof then
        b.y = roof
        knock(b, f, b.vy, false)
        rebound(b, 0, -1, 0, f.wall, WALL_GRIP)
    end

    if b.y <= floorY + 0.5 then
        b.vx, b.vz = b.vx * f.roll, b.vz * f.roll
    else
        b.vx, b.vz = b.vx * f.air, b.vz * f.air
    end

    local cx, cz = p.centre.x, p.centre.z
    local barY = p.floor + p.goalHeight

    if math.abs(b.z - cz) < halfWidth then
        for _, sx in ipairs(SIGNS) do
            local behind = sx * (b.x - cx)
            if behind > p.goalX then
                local back = p.goalX + p.goalDepth - BALL_RADIUS
                if behind > back and b.y - BALL_RADIUS < barY then
                    b.x = cx + sx * back
                    rebound(b, -sx, 0, 0, NET_BOUNCE, NET_GRIP)
                end

                local top = barY + POST_RADIUS
                if fromY - BALL_RADIUS >= top - 0.5 and b.y - BALL_RADIUS < top then
                    b.y = top + BALL_RADIUS
                    if b.vy < -BOUNCE_MIN then
                        rebound(b, 0, 1, 0, NET_BOUNCE, NET_GRIP)
                    else
                        b.vy = 0
                    end
                end

                if math.abs(b.y - BALL_RADIUS - top) <= 0.5 then
                    b.vx = b.vx - sx * ROOF_TILT
                end

                if fromY + BALL_RADIUS <= barY + 0.5 and b.y + BALL_RADIUS > barY then
                    b.y = barY - BALL_RADIUS
                    rebound(b, 0, -1, 0, NET_BOUNCE, NET_GRIP)
                end

                if behind > p.goalX + BALL_RADIUS and b.y + BALL_RADIUS <= barY + 0.5 then
                    b.vx, b.vz = b.vx * NET_HOLD, b.vz * NET_HOLD
                end
            end
        end
    end

    if b.x < p.minX + BALL_RADIUS then
        b.x = p.minX + BALL_RADIUS
        knock(b, f, -b.vx, false)
        rebound(b, 1, 0, 0, f.wall, WALL_GRIP)
    elseif b.x > p.maxX - BALL_RADIUS then
        b.x = p.maxX - BALL_RADIUS
        knock(b, f, b.vx, false)
        rebound(b, -1, 0, 0, f.wall, WALL_GRIP)
    end
    if b.z < p.minZ + BALL_RADIUS then
        b.z = p.minZ + BALL_RADIUS
        knock(b, f, -b.vz, false)
        rebound(b, 0, 0, 1, f.wall, WALL_GRIP)
    elseif b.z > p.maxZ - BALL_RADIUS then
        b.z = p.maxZ - BALL_RADIUS
        knock(b, f, b.vz, false)
        rebound(b, 0, 0, -1, f.wall, WALL_GRIP)
    end

    local postE = math.min(0.95, POST_BOUNCE * f.wall / WALL_BOUNCE)
    for _, sx in ipairs(SIGNS) do
        local gx = cx + sx * p.goalX
        for _, sz in ipairs(SIGNS) do
            local pz = cz + sz * halfWidth
            local hit, into = hit_bar(b, gx, p.floor, pz, gx, barY, pz,
                POST_RADIUS, postE, WALL_GRIP)
            if hit and into > RING_SPEED then b.rang = math.max(b.rang or 0, into) end
            if hit then knock(b, f, into, false) end
        end
        local hit, into = hit_bar(b, gx, barY, cz - halfWidth, gx, barY, cz + halfWidth,
            POST_RADIUS, postE, WALL_GRIP)
        if hit and into > RING_SPEED then b.rang = math.max(b.rang or 0, into) end
        if hit then knock(b, f, into, false) end
    end

    football.side_nets(b, p, halfWidth, fromZ)
    football.track_mouth(b, p, halfWidth, fromX, fromY, fromZ)

    if math.abs(b.vx) < STOP_SPEED and math.abs(b.vz) < STOP_SPEED
        and b.y <= floorY + 0.5 then
        b.vx, b.vz = 0, 0
    end
    clamp_speed(b)

    if b.goal == nil then
        local side = football.goal_scored(b, p, halfWidth)
        if side ~= nil then b.goal, b.goalStep = side, b.step or 0 end
    end
    return b
end

function football.side_nets(b, p, halfWidth, fromZ)
    local cx, cz = p.centre.x, p.centre.z
    if b.y - BALL_RADIUS >= p.floor + p.goalHeight then return end
    local behind = math.abs(b.x - cx)
    if behind <= p.goalX or behind > p.goalX + p.goalDepth + BALL_RADIUS then return end
    for _, sz in ipairs(SIGNS) do
        local edge = cz + sz * halfWidth
        local wasIn = (fromZ - cz) * sz < halfWidth
        local nowIn = (b.z - cz) * sz < halfWidth
        if wasIn and not nowIn then
            b.z = edge - sz * BALL_RADIUS
            rebound(b, 0, 0, -sz, NET_BOUNCE, NET_GRIP)
        elseif nowIn and not wasIn then
            b.z = edge + sz * BALL_RADIUS
            rebound(b, 0, 0, sz, NET_BOUNCE, NET_GRIP)
        end
    end
end

function football.track_mouth(b, p, halfWidth, fromX, fromY, fromZ)
    local cx, cz = p.centre.x, p.centre.z
    for _, sx in ipairs(SIGNS) do
        local side = sx > 0 and "red" or "blue"
        local before, after = sx * (fromX - cx), sx * (b.x - cx)
        if after <= p.goalX then
            if b.mouth == side then b.mouth = nil end
        elseif before <= p.goalX then
            local t = (p.goalX - before) / (after - before)
            local zAt = fromZ + (b.z - fromZ) * t
            local yAt = fromY + (b.y - fromY) * t
            if math.abs(zAt - cz) < halfWidth
                and yAt - BALL_RADIUS < p.floor + p.goalHeight then
                b.mouth = side
            else
                b.mouth = nil
            end
        end
    end
end

function football.goal_scored(b, p, halfWidth)
    local cx, cz = p.centre.x, p.centre.z
    if math.abs(b.z - cz) >= halfWidth then return nil end
    if b.y - BALL_RADIUS >= p.floor + p.goalHeight then return nil end
    if b.x - cx > p.goalX + BALL_RADIUS and b.mouth == "red" then return "red" end
    if cx - b.x > p.goalX + BALL_RADIUS and b.mouth == "blue" then return "blue" end
    return nil
end

local function centre_ball(p)
    ball.x, ball.y, ball.z = p.centre.x, p.floor + BALL_RADIUS, p.centre.z
    if football.penalties() then
        local pen = football.pen()
        if pen ~= nil then ball.x, ball.z = football.pen_spot(p, pen.side) end
    end
    ball.vx, ball.vy, ball.vz = 0, 0, 0
    ball.spin, ball.broke = 0, nil
    ball.mouth, ball.goal, ball.goalStep = nil, nil, nil
    ball.toucher, ball.touchN, ball.touchStep = -1, 0, -9999
    ball.from, replay = nil, nil
    kickoffStep = ball.step or 0
    goalSeenAt = nil
end

local MOUTH_WORD = { red = "r", blue = "b" }
local WORD_MOUTH = { r = "red", b = "blue" }

local function pack_ball()
    return string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %s %.0f",
        seq, ball.x, ball.y, ball.z, ball.vx * 10, ball.vy * 10, ball.vz * 10,
        ball.step or 0, ball.serial or 0, ball.toucher or -1, ball.touchN or 0,
        ball.touchStep or -9999, refusedGI, refusedN, MOUTH_WORD[ball.mouth] or "-",
        (ball.spin or 0) * 100) .. football.pack_from(ball.from)
end

function football.pack_from(f)
    if f == nil then return "" end
    return string.format(" %.0f %.0f %.0f %.0f %.0f %.0f %.0f", f.x, f.y, f.z,
        f.vx * 10, f.vy * 10, f.vz * 10, (f.spin or 0) * 100)
end

local function adopt(text, into)
    local parts = numbers(text)
    if #parts < 7 then return nil end
    local b = into or ball
    b.x, b.y, b.z = tonumber(parts[2]) or 0, tonumber(parts[3]) or 0,
        tonumber(parts[4]) or 0
    b.vx = (tonumber(parts[5]) or 0) / 10
    b.vy = (tonumber(parts[6]) or 0) / 10
    b.vz = (tonumber(parts[7]) or 0) / 10
    local wire = {
        seq = tonumber(parts[1]) or 0,
        step = tonumber(parts[8]) or (b.step or 0),
        serial = tonumber(parts[9]) or 0,
        toucher = tonumber(parts[10]) or -1,
        touchN = tonumber(parts[11]) or 0,
        touchStep = tonumber(parts[12]) or -9999,
        refusedGI = tonumber(parts[13]) or -1,
        refusedN = tonumber(parts[14]) or 0,
        mouth = WORD_MOUTH[parts[15] or "-"],
    }
    b.step, b.serial = wire.step, wire.serial
    b.toucher, b.touchN, b.touchStep = wire.toucher, wire.touchN, wire.touchStep
    b.mouth = wire.mouth
    b.spin = (tonumber(parts[16]) or 0) / 100
    b.broke = nil
    b.from = nil
    if #parts >= 23 then
        b.from = { x = tonumber(parts[17]) or 0, y = tonumber(parts[18]) or 0,
            z = tonumber(parts[19]) or 0, vx = (tonumber(parts[20]) or 0) / 10,
            vy = (tonumber(parts[21]) or 0) / 10, vz = (tonumber(parts[22]) or 0) / 10,
            spin = (tonumber(parts[23]) or 0) / 100 }
    end
    wire.from = b.from
    return wire
end
football.adopt = adopt

local RELIABLE_EVERY = 15
football.RELIABLE_EVERY = RELIABLE_EVERY
local function publish_ball(stream)
    seq = seq + 1
    local text = pack_ball()
    local goal, goalStep = ball.goal, ball.goalStep
    adopt(text)
    ball.goal, ball.goalStep = goal, goalStep
    if stream == true and OF.util.asks(OF.gamemodes, "stream_send") then
        OF.gamemodes.stream_send(BALL_KEY, text)
    else
        OF.util.publish(BALL_KEY, text)
    end
end

function football.wire_now()
    local wire = gGlobalSyncTable[BALL_KEY]
    local streamed = OF.util.asks(OF.gamemodes, "stream_read") and OF.gamemodes.stream_read(BALL_KEY) or nil
    if streamed ~= nil and (wire == nil
        or (tonumber(numbers(streamed)[1]) or 0) > (tonumber(numbers(wire)[1]) or 0)) then
        return streamed
    end
    return wire
end

local function facing(m)
    local yaw = (m.faceAngle ~= nil and m.faceAngle.y or 0) * math.pi / 32768
    return math.sin(yaw), math.cos(yaw)
end

function football.kind_of(action)
    if action == nil then return nil end
    if action == ACT_GROUND_POUND or action == ACT_GROUND_POUND_LAND then
        return "shot"
    elseif action == ACT_DIVE or action == ACT_DIVE_SLIDE then
        return "dive"
    elseif action == ACT_SLIDE_KICK or action == ACT_SLIDE_KICK_SLIDE
        or (ACT_CROUCH_SLIDE ~= nil and action == ACT_CROUCH_SLIDE) then
        return "slide"
    elseif action == ACT_JUMP_KICK then
        return "volley"
    elseif action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING then
        return "kick"
    end
    return nil
end

function football.press_stage(m)
    if m == nil then return 0 end
    if m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING then
        local arg = tonumber(m.actionArg) or 0
        if arg >= 9 then return 3 end
        return math.min(2, math.floor(arg / 3))
    end
    return 0
end

function football.press_note(memo, m)
    local kind = m ~= nil and football.kind_of(m.action) or nil
    local stage = football.press_stage(m)
    if kind == nil or kind ~= memo.kind or stage ~= memo.stage then
        memo.spent = false
        memo.frames, memo.landAt = 0, nil
    else
        memo.frames = (memo.frames or 0) + 1
    end
    if m ~= nil and m.action == ACT_GROUND_POUND_LAND and memo.landAt == nil then
        memo.landAt = memo.frames
    end

    memo.since = (memo.since or 999) + 1
    memo.kind, memo.stage = kind, stage
    return memo.spent == true
end

function football.live(memo, kind)
    if memo == nil or memo.frames == nil or kind == nil then return true end
    local w = football.FEEL.window
    if kind == "shot" then
        return memo.landAt == nil or memo.frames - memo.landAt <= w.poundLand
    end
    return memo.frames <= math.max(w[kind] or 0, football.FEEL.buffer)
end

function football.prop_press(m, b)
    if m == nil or b == nil then return false end
    b.presses = b.presses or {}
    local index = m.playerIndex or 0
    local memo = b.presses[index]
    if memo == nil then
        memo = {}
        b.presses[index] = memo
    end
    return football.press_note(memo, m), memo
end

function football.in_ring(m, b, ring)
    if m == nil or m.pos == nil or b == nil or ring == nil then return false end

    local fx, fz = facing(m)
    local ahead = ring.forward or 0
    local dx, dz = b.x - (m.pos.x + fx * ahead), b.z - (m.pos.z + fz * ahead)
    local dy = b.y - (m.pos.y + ring.mid)
    return dx * dx + dz * dz <= ring.reach * ring.reach and math.abs(dy) <= ring.tall
end

function football.forge_ring(b)
    local r = (b ~= nil and b.radius) or BALL_RADIUS
    local f = football.FEEL.forgeRing
    return { reach = r + f.reachPast, mid = f.mid, tall = r + f.tallPast, forward = f.forward }
end

local FIXED_LINE = { shot = true, dive = true, volley = true }
function football.strike_dir(m, kind)
    local fx, fz = facing(m)
    if FIXED_LINE[kind] or m == nil or m.controller == nil or m.intendedYaw == nil then return fx, fz end
    local mag = (tonumber(m.controller.stickMag) or 0) / 64
    if mag <= football.FEEL.stickMin then return fx, fz end
    local yaw = (tonumber(m.intendedYaw) or 0) * math.pi / 32768
    local ix, iz = math.sin(yaw), math.cos(yaw)
    if ix * fx + iz * fz < math.cos(math.rad(football.FEEL.stickTurnDeg)) then return fx, fz end
    return ix, iz
end

function football.knee(v)
    local at, span = football.FEEL.kneeAt, football.FEEL.kneeSpan
    if v <= at then return v end
    local x = math.exp(2 * (v - at) / span)
    return at + span * (x - 1) / (x + 1)
end

local function ring_strike(m, b, kind, t, ring, mvx, mvy, mvz, fx, fz, power, lift)
    if not football.in_ring(m, b, ring) then return nil end

    local own = lift == nil
    if lift == nil then
        lift = t.loft
        if kind == "shot" and b.y < m.pos.y then lift = -football.FEEL.spikeDrop end
    end
    local bvx, bvy, bvz = b.vx or 0, b.vy or 0, b.vz or 0
    local function along(l)
        local tilt = math.sqrt(1 + l * l)
        local sdx, sdy, sdz = fx / tilt, l / tilt, fz / tilt

        local run = math.max(0, mvx * sdx + mvy * sdy + mvz * sdz)
        local closing = run - (bvx * sdx + bvy * sdy + bvz * sdz) + t.swing
        if closing <= 0 then return nil end
        return sdx, sdy, sdz, math.max((1 + t.e) * closing, t.min or 0) * (power or 1)
    end
    local sdx, sdy, sdz, push = along(lift)
    if push == nil then return nil end
    if kind == "volley" and own then

        local v = football.FEEL.volleyLoft
        local again = v.k * math.max(v.lo, math.min(v.hi, v.ref / math.max(push, 1)))
        local ax, ay, az, apush = along(again)
        if apush ~= nil then sdx, sdy, sdz, push = ax, ay, az, apush end
    end
    push = football.knee(push)
    local out = { vx = sdx * push, vy = sdy * push, vz = sdz * push }
    clamp_speed(out)
    return out.vx, out.vy, out.vz
end

function football.body_velocity(m)
    local vx, vy, vz = 0, 0, 0
    if m.vel ~= nil then
        vx, vy, vz = tonumber(m.vel.x) or 0, tonumber(m.vel.y) or 0, tonumber(m.vel.z) or 0
    end
    if vx * vx + vz * vz < 0.01 then
        local fx, fz = facing(m)
        local fv = tonumber(m.forwardVel) or 0
        vx, vz = fx * fv, fz * fv
    end
    return vx, vy, vz
end

function football.still(m)
    if m == nil or m.pos == nil then return false end
    if football.kind_of(m.action) ~= nil then return false end
    local vx, vy, vz = football.body_velocity(m)
    return vx * vx + vz * vz < STILL_SPEED * STILL_SPEED and math.abs(vy) < STILL_SPEED
end

local function strike(b, lx, ly, lz, reach, hvx, hvy, hvz, sdx, sdy, sdz, aim, e, least, power)
    local dx, dy, dz = b.x - lx, b.y - ly, b.z - lz
    local away = math.sqrt(dx * dx + dy * dy + dz * dz)
    if away >= BALL_RADIUS + reach or away < 0.001 then return nil end
    local nx, ny, nz = dx / away, dy / away, dz / away
    local bvx, bvy, bvz = b.vx or 0, b.vy or 0, b.vz or 0
    local closing = (hvx - bvx) * nx + (hvy - bvy) * ny + (hvz - bvz) * nz
    if closing <= 0 then return nil end
    local push = math.max((1 + e) * closing, least or 0) * (power or 1)
    local ax, ay, az = nx * (1 - aim) + sdx * aim, ny * (1 - aim) + sdy * aim,
        nz * (1 - aim) + sdz * aim
    local len = math.sqrt(ax * ax + ay * ay + az * az)

    if len < 0.001 or (ax * nx + ay * ny + az * nz) / len < 0.2 then
        ax, ay, az, len = nx, ny, nz, 1
    end
    local out = { vx = bvx + ax / len * push, vy = bvy + ay / len * push,
                  vz = bvz + az / len * push }
    clamp_speed(out)
    return out.vx, out.vy, out.vz, push
end

function football.touch(m, b, charge, ring, spent, lofts)
    if m == nil or m.pos == nil or b == nil then return nil end
    local f = football.feel()
    local fx, fz = facing(m)
    local mvx, mvy, mvz = football.body_velocity(m)
    local kind = football.kind_of(m.action)

    local memo = type(spent) == "table" and spent or nil
    if ring == nil then
        ring = football.forge_ring(b)
        spent, memo = football.prop_press(m, b)
    end
    if memo ~= nil then spent = memo.spent == true end
    if ring == false then ring = nil end
    if kind ~= nil and ring ~= nil then

        if not spent then
            if football.live(memo, kind) then
                local power = f.touch * (1 + football.CHARGE_GAIN * math.max(0, math.min(1, charge or 0)))
                local dx, dz = football.strike_dir(m, kind)
                local vx, vy, vz = ring_strike(m, b, kind, football.TOUCHES[kind], ring,
                    mvx, mvy, mvz, dx, dz, power, lofts ~= nil and lofts[kind] or nil)
                if vx ~= nil then
                    if memo ~= nil then memo.spent, memo.since = true, 0 end
                    return kind, vx, vy, vz, football.curl_of(m, kind)
                end
            end
        else

            return nil
        end
    elseif kind ~= nil then
        local t = football.TOUCHES[kind]
        local tilt = math.sqrt(1 + t.loft * t.loft)
        local sdx, sdy, sdz = fx / tilt, t.loft / tilt, fz / tilt
        local power = f.touch * (1 + football.CHARGE_GAIN * math.max(0, math.min(1, charge or 0)))
        local vx, vy, vz = strike(b, m.pos.x + fx * t.fwd, m.pos.y + t.up,
            m.pos.z + fz * t.fwd, t.reach,
            mvx + sdx * t.swing, mvy + sdy * t.swing, mvz + sdz * t.swing,
            sdx, sdy, sdz, t.aim, t.e, t.min, power)
        if vx ~= nil then return kind, vx, vy, vz, football.curl_of(m, kind) end
    end
    if football.still(m) then return nil end

    if memo ~= nil and (memo.since or 999) < football.FEEL.bodyIgnore then return nil end

    local low, high = m.pos.y + BODY_RADIUS, m.pos.y + BODY_TALL - BODY_RADIUS
    local ay = math.max(low, math.min(high, b.y))
    local run = math.sqrt(mvx * mvx + mvz * mvz)
    local pace = math.sqrt(mvx * mvx + mvy * mvy + mvz * mvz)
    local vx, vy, vz, push = strike(b, m.pos.x, ay, m.pos.z, BODY_RADIUS,
        mvx, mvy, mvz, fx, 0, fz, football.dribble_steer(run),
        football.dribble_bounce(pace), 0, f.touch)

    if vx == nil or push < 1.5 then return nil end
    return "dribble", vx, vy, vz, 0
end

local PASS_KINDS = { kick = true, dive = true, slide = true }
local SHOT_KINDS = { shot = true, volley = true }

local function angle_to(ax, az, bx, bz)
    return math.atan(ax * bz - az * bx, ax * bx + az * bz)
end

local function turn_by(vx, vz, a)
    local c, s = math.cos(a), math.sin(a)
    return vx * c - vz * s, vx * s + vz * c
end
football.turn_by = turn_by

function football.receiver(m, b, side, vx, vz)
    local F = football.FEEL
    local flat = math.sqrt(vx * vx + vz * vz)
    if flat < 0.001 then return nil end
    local best, bestErr, bx, bz = nil, math.rad(F.passConeDeg), nil, nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local li = entry.localIndex
        local r = gMarioStates[li]
        if li ~= m.playerIndex and r ~= nil and r.pos ~= nil and OF.teams.of(li) == side
            and football.in_room(li) then
            local dx, dz = r.pos.x - b.x, r.pos.z - b.z
            local d = math.sqrt(dx * dx + dz * dz)
            if d >= F.passNear and d <= F.passFar then
                local frames = d / math.max(flat, 1)
                local rvx, _, rvz = football.body_velocity(r)
                local tx, tz = r.pos.x + rvx * frames, r.pos.z + rvz * frames
                local err = angle_to(vx, vz, tx - b.x, tz - b.z)
                if math.abs(err) <= bestErr then best, bestErr, bx, bz = li, math.abs(err), tx, tz end
            end
        end
    end
    if best == nil then return nil end
    return best, bx, bz, angle_to(vx, vz, bx - b.x, bz - b.z)
end

function football.on_target(m, b, side, vx, vz, p, halfWidth)
    if p == nil then return nil end
    local F = football.FEEL
    local dir = attack_dir(side)
    local lineX = p.centre.x + dir * p.goalX
    local ahead = (lineX - b.x) * dir
    if ahead <= 0 or ahead > F.shotRange or vx * dir <= 0 then return nil end
    local gx, gz = lineX - b.x, p.centre.z - b.z
    if math.abs(angle_to(vx, vz, gx, gz)) > math.rad(F.shotConeDeg) then return nil end
    local z = b.z + vz / vx * (lineX - b.x)

    if math.abs(z - p.centre.z) <= halfWidth then return nil end
    local inside = math.max(0, halfWidth - BALL_RADIUS * F.postInside)
    local post = z > p.centre.z and p.centre.z + inside or p.centre.z - inside
    local want = angle_to(vx, vz, lineX - b.x, post - b.z)
    local fade = 1
    if ahead > F.shotFadeFrom then
        fade = math.max(0, (F.shotRange - ahead) / (F.shotRange - F.shotFadeFrom))
    end
    local most = math.rad(F.shotMaxDeg) * fade
    return math.max(-most, math.min(most, want))
end

function football.assist(m, b, kind, vx, vy, vz)
    if m == nil or b == nil or kind == nil or football.penalties()
        or OF.gamemodes.option_is("assist", "off") then return vx, vy, vz end
    local side = OF.teams.of(m.playerIndex or 0)
    if side ~= "red" and side ~= "blue" then return vx, vy, vz end
    local F = football.FEEL
    if PASS_KINDS[kind] then
        local li, _, _, err = football.receiver(m, b, side, vx, vz)
        if li ~= nil then
            local most = math.rad(F.passMaxDeg)
            vx, vz = turn_by(vx, vz, math.max(-most, math.min(most, err * F.passShare)))
        end
    elseif SHOT_KINDS[kind] then
        local p = football.pitch()
        local turn = football.on_target(m, b, side, vx, vz, p, football.goal_half_width(p))
        if turn ~= nil then vx, vz = turn_by(vx, vz, turn) end
    end
    return vx, vy, vz
end

football.CURL_DEAD = 16
football.CURL_FULL = 64
function football.curl_of(m, kind)
    if kind ~= "volley" or OF.gamemodes.option_is("curl", "off") then return 0 end
    local pad = m ~= nil and m.controller or nil
    local x = pad ~= nil and tonumber(pad.stickX) or 0
    if math.abs(x) < football.CURL_DEAD then return 0 end
    return math.max(-1, math.min(1, x / football.CURL_FULL))
end

football.CHARGE_GAIN = 0.3
football.CHARGE_FRAMES = 30
football.CHARGE_KEEP = 45
football.CHARGE_WALK = 14
football.CHARGE_BUTTON = Y_BUTTON or 0x0080
local charge, chargeHeld, chargeLeft = 0, false, 0
local function charge_on()
    return not OF.gamemodes.option_is("charge", "off")
end

function football.work_the_charge(m)
    chargeHeld = false
    if m == nil or m.controller == nil or not charge_on() then
        charge, chargeLeft = 0, 0
        return 0
    end
    local held = OF.util.has_flag(m.controller.buttonDown or 0, football.CHARGE_BUTTON)
    local onGround = m.action == ACT_WALKING or m.action == ACT_IDLE
        or m.action == ACT_BRAKING or m.action == ACT_DECELERATING
    if held and onGround then
        chargeHeld = true
        charge = math.min(1, charge + 1 / football.CHARGE_FRAMES)
        chargeLeft = football.CHARGE_KEEP
        if m.action == ACT_WALKING and (tonumber(m.forwardVel) or 0) > football.CHARGE_WALK then
            m.forwardVel = football.CHARGE_WALK
        end
    elseif charge > 0 then
        chargeLeft = chargeLeft - 1
        if chargeLeft <= 0 then charge = 0 end
    end
    return charge
end

function football.charge_now()
    return charge, chargeHeld
end

function football.spend_charge()
    charge, chargeLeft = 0, 0
end

function football.keep_out(m, b)
    if m == nil or m.pos == nil or b == nil then return false end
    if m.pos.y > b.y + BALL_RADIUS * 0.5 then return false end
    if m.pos.y + BODY_TALL < b.y - BALL_RADIUS then return false end
    local dx, dz = m.pos.x - b.x, m.pos.z - b.z
    local flat = math.sqrt(dx * dx + dz * dz)
    local reach = BALL_RADIUS + BODY_RADIUS
    if flat >= reach then return false end
    if flat < 0.001 then dx, dz, flat = 1, 0, 1 end
    m.pos.x = b.x + dx / flat * reach
    m.pos.z = b.z + dz / flat * reach
    return true
end

function football.bounce_off(b, m)
    if m == nil or m.pos == nil or b == nil then return false end
    if m.pos.y > b.y + BALL_RADIUS or m.pos.y + BODY_TALL < b.y - BALL_RADIUS then
        return false
    end
    local low, high = m.pos.y + BODY_RADIUS, m.pos.y + BODY_TALL - BODY_RADIUS
    local ay = math.max(low, math.min(high, b.y))
    local dx, dy, dz = b.x - m.pos.x, b.y - ay, b.z - m.pos.z
    local away = math.sqrt(dx * dx + dy * dy + dz * dz)
    local reach = BALL_RADIUS + BODY_RADIUS
    if away >= reach or away < 0.001 then return false end
    local nx, ny, nz = dx / away, dy / away, dz / away
    local into = -(b.vx * nx + b.vy * ny + b.vz * nz)
    if into <= 0 then return false end
    b.x, b.y, b.z = m.pos.x + nx * reach, ay + ny * reach, m.pos.z + nz * reach
    knock(b, football.feel(), into, false)
    rebound(b, nx, ny, nz, BODY_BOUNCE, WALL_GRIP)
    return true
end

local function may_wall(li, b, pen)
    local np = gNetworkPlayers[li]
    if np == nil or not np.connected then return false end
    if not OF.gamemodes.can_play(li) or not football.in_room(li) then return false end
    local gi = np.globalIndex
    if gi == b.toucher and (b.step or 0) - (b.touchStep or -9999) <= COOLDOWN then
        return false
    end
    if pen ~= nil and gi ~= pen.striker and gi ~= pen.keeper then return false end
    return true
end

function football.bounce_still(b)
    local hit = nil

    local pen = football.penalties() and (football.pen() or { striker = -2, keeper = -2 }) or nil

    local order = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil then order[#order + 1] = { li = entry.localIndex, gi = np.globalIndex } end
    end
    table.sort(order, function(a, c) return a.gi < c.gi end)
    for _, entry in ipairs(order) do
        local li = entry.li
        local m = gMarioStates[li]
        if may_wall(li, b, pen) and football.still(m) and football.bounce_off(b, m) then
            hit = hit or {}
            table.insert(hit, gNetworkPlayers[li].globalIndex)
        end
    end
    return hit
end

function football.unstick(b)
    local F = football.FEEL
    local n, sx, sz = 0, 0, 0
    local reach = BALL_RADIUS + BODY_RADIUS
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil and football.in_room(entry.localIndex)
            and m.pos.y <= b.y + BALL_RADIUS and m.pos.y + BODY_TALL >= b.y - BALL_RADIUS then
            local dx, dz = b.x - m.pos.x, b.z - m.pos.z
            if dx * dx + dz * dz < reach * reach then
                n = n + 1
                sx, sz = sx + m.pos.x, sz + m.pos.z
            end
        end
    end
    if n < 2 then
        b.stuck = 0
        return false
    end
    b.stuck = (b.stuck or 0) + 1
    if b.stuck <= F.stuckFrames then return false end
    b.stuck = 0
    local ax, az = b.x - sx / n, b.z - sz / n
    local len = math.sqrt(ax * ax + az * az)
    if len < 0.001 then ax, az, len = 1, 0, 1 end
    b.vx, b.vz = ax / len * F.stuckPush, az / len * F.stuckPush
    b.vy = F.stuckPop
    b.grounded = false
    return true
end

function football.advance(b, p, halfWidth)
    b.step = (b.step or 0) + 1
    football.step(b, p, halfWidth)
    football.unstick(b)
    local hit = football.bounce_still(b)
    if OF.util.is_host() and b == ball then
        history[b.step % HISTORY] = { step = b.step, x = b.x, y = b.y, z = b.z }
    end
    return hit
end

function football.judge(gi, n, claim, body)
    if football.paused() then return false, "held" end
    if claim == nil or claim.step == nil then return false, "unreadable" end

    for _, v in ipairs({ claim.step, claim.x, claim.y, claim.z, claim.vx, claim.vy, claim.vz }) do
        if not OF.finite(v) then return false, "unreadable" end
    end
    local now = ball.step or 0
    local at = claim.step
    if at > now then at = now end
    if at < kickoffStep then return false, "before the kickoff" end
    if now - at > MAX_REWIND then return false, "too late" end
    if ball.goal ~= nil and at >= (ball.goalStep or now) then return false, "already in" end
    if ball.toucher ~= gi and (at < (ball.touchStep or -9999)
        or (claim.serial or 0) < (ball.serial or 0)) then

        return false, "after another touch"
    end
    local was = football.history_at(at)
    if was ~= nil then
        local dx, dy, dz = claim.x - was.x, claim.y - was.y, claim.z - was.z
        if dx * dx + dy * dy + dz * dz > CLAIM_SLACK * CLAIM_SLACK then
            return false, "not where the ball was"
        end
    end
    if body == nil or body.pos == nil then return false, "no body" end
    local bx, bz = body.pos.x - claim.x, body.pos.z - claim.z
    if bx * bx + bz * bz > HOST_LEEWAY * HOST_LEEWAY then return false, "too far" end
    if not football.pen_may_touch(gi, penShot) then return false, "not their kick" end
    return true
end

function football.take(gi, n, claim)
    local now = ball.step or 0
    local fromX, fromY, fromZ = ball.x, ball.y, ball.z
    local shownAt = football.drawn_peek()
    local at = math.min(claim.step, now)
    ball.x, ball.y, ball.z = claim.x, claim.y, claim.z
    ball.vx, ball.vy, ball.vz = claim.vx, claim.vy, claim.vz
    ball.spin = claim.spin or 0
    ball.broke = nil
    clamp_speed(ball)
    ball.mouth = claim.mouth
    ball.goal, ball.goalStep = nil, nil
    goalSeenAt = nil
    ball.step = at
    ball.toucher, ball.touchN, ball.touchStep = gi, n, at
    ball.serial = (ball.serial or 0) + 1
    ball.from = { x = ball.x, y = ball.y, z = ball.z, vx = ball.vx, vy = ball.vy,
        vz = ball.vz, spin = ball.spin }
    local p = football.pitch()
    if p ~= nil then
        local halfWidth = football.goal_half_width()
        while (ball.step or 0) < now do football.advance(ball, p, halfWidth) end
    end

    if not football.see_touch(shownAt) then football.correct(fromX, fromY, fromZ) end
    lastToucher = gi
    football.pen_touched(gi)
    publish_ball()
end

football.net = { refused = {}, accepted = 0, taken = 0, refusedMine = 0, timeouts = 0, sent = 0 }

football.PACKET_KICK = "fbkick"
local packetKicks = {}
local kickCopies, kickText = 0, nil
function football.receive_kick(data)
    if type(data) ~= "table" or data.ofp ~= football.PACKET_KICK or not OF.util.is_host() then return false end
    if type(data.t) ~= "string" then return false end
    local _, gi = OF.util.asked_by(data)
    if gi == nil then return false end
    local was = packetKicks[gi]
    local n = tonumber(numbers(data.t)[1]) or -1
    if was == nil or n > (tonumber(numbers(was)[1]) or -1) then packetKicks[gi] = data.t end
    return true
end
hook_event(HOOK_ON_PACKET_RECEIVE, function(data) football.receive_kick(data) end)

function football.should_adopt(wire, myGI, nowFrame)
    if pending == nil then return true end
    local taken = wire.toucher == myGI and wire.touchN >= pending.n
    local refused = wire.refusedGI == myGI and wire.refusedN >= pending.n
    local timedOut = nowFrame >= pending.untilFrame
    local answered = taken or (wire.serial > pending.serial and wire.toucher ~= myGI)
        or refused or football.paused() or timedOut
    if answered then
        if taken then
            football.net.taken = football.net.taken + 1
        elseif refused or timedOut then

            if refused then football.net.refusedMine = football.net.refusedMine + 1 end
            if timedOut and not refused then football.net.timeouts = football.net.timeouts + 1 end
            press.spent, press.since, cooldown = false, 999, 0
        end
        pending = nil
    end
    return answered
end

function football.pending()
    return pending
end

function football.history_at(step)
    local was = history[step % HISTORY]
    if was ~= nil and was.step == step then return was end
    return nil
end

local sprinting = false
local function stamina_now()
    if OF.util.asks(OF.moves, "sprint_stamina") then return OF.moves.sprint_stamina() end
    return football.SPRINT_FULL
end

local function sprint_on()
    return not OF.gamemodes.option_is("sprint", "off")
end

function football.work_the_sprint(m)
    sprinting = false
    if m == nil or m.controller == nil or not sprint_on() then return false end
    if not OF.util.asks(OF.moves, "sprint_step") then return false end
    local held = OF.util.has_flag(m.controller.buttonDown or 0, X_BUTTON or 0x0040)
    sprinting = OF.moves.sprint_step(m, held)
    return sprinting
end

local mode = {
    key = "football",
    name = "Football",
    blurb = "two sides, one big ball - put it in their goal",
    blurbTeams = "two sides, one big ball - put it in their goal",
    aims = { [ROLE_PLAY] = "Put the ball in their goal - a ground pound beside it is a shot." },
    how = "Two sides, one big ball, two goals.\n"
        .. "Run into the ball to dribble it; punch or kick to pass.\n"
        .. "Dive to head it, and ground pound beside it to shoot.\n"
        .. "A jump kick volleys it high; the stick curls it.\n"
        .. "Hold X to sprint; hold Y to charge your next strike.\n"
        .. "Bodies are solid - shoulder in, but no punch lands.\n"
        .. "A full lobby only makes it longer: widen the goals below.\n"
        .. "First side to the target wins; then the clock.\n"
        .. "Penalties below: a striker, a keeper, five kicks a side.",

    minPlayers = 2,
    sidesFrom = 2,

    maps = { "the_stadium" },

    room = { rules = { interactions = PLAYER_INTERACTIONS_SOLID or 1 } },
    music = SEQ_LEVEL_GRASS,
    defaultLimit = 300,
    teams = "always",
    symmetric = true,

    target = { auto = function(n, teams, side)
                   if n >= 9 then return 3 end
                   return 4
               end,
               name = "goals to win",
               asks = "How many goals win the round",
               default = TARGET_GOALS,

               shownIf = { format = "match" },
               min = 1, max = 20, step = 1 },

    pointBanner = "GOAL",
    overtimeWord = "GOLDEN GOAL",
    overtimeSub = "Next goal wins",
    boardTitle = "Goals",
    options = {

        { key = "format", name = "What is played",
          help = "a match, or a penalty shoot-out",
          choices = {
              { key = "match", name = "a match",
                help = "two sides, one ball, goals to the target" },
              { key = "penalties", name = "a penalty shoot-out",
                help = "five kicks a side, then kick for kick until decided" },
          } },

        { key = "goals", name = "Goal width",
          help = "how wide the goal mouths are",
          choices = {
              { key = "ordinary", name = "normal",
                help = "as the pitch has them" },
              { key = "wide", name = "wide",
                help = "for a full lobby - more goals" },
              { key = "narrow", name = "narrow",
                help = "for a small lobby - a goal has to be earned" },
          } },

        { key = "ball", name = "What the ball is made of",
          help = "every machine plays the same ball",
          choices = {
              { key = "standard", name = "a football",
                help = "the ball as it always was" },
              { key = "rubber", name = "rubber",
                help = "bounces higher, rolls further" },
              { key = "bowling", name = "a bowling ball",
                help = "heavy to kick, low, and it rolls for ever" },
              { key = "beach", name = "a beach ball",
                help = "light, slow and floaty - time to get under it" },
              { key = "crystal", name = "crystal",
                help = "a hard landing or knock shatters it" },
          } },
        { key = "pitch", name = "What the pitch is",
          help = "how the ground rolls and bounces the ball",
          choices = {
              { key = "normal", name = "grass", help = "as it always was" },
              { key = "ice", name = "ice", help = "the ball runs on and on" },
              { key = "mud", name = "mud", help = "it stops quickly and barely bounces" },
              { key = "bouncy", name = "bouncy", help = "every landing springs back up" },
          } },
        { key = "curl", name = "Curl on volleys",
          help = "a jump kick with the stick to one side bends that way",
          choices = {
              { key = "on", name = "on", help = "bend it round a wall of defenders" },
              { key = "off", name = "off", help = "every volley flies straight" },
          } },
        { key = "charge", name = "Charged strike",
          help = "hold Y to walk and charge the next strike",
          choices = {
              { key = "on", name = "on", help = "up to a third harder, but you walk" },
              { key = "off", name = "off", help = "every strike as it comes" },
          } },
        { key = "assist", name = "Passes and shots",
          help = "a pass finds the team-mate you face, a shot the goal",
          choices = {
              { key = "on", name = "helped", help = "led to the run, pulled inside the posts" },
              { key = "off", name = "as struck", help = "the ball goes where the foot sends it" },
          } },
        { key = "sprint", name = "Sprint",
          help = "hold X on the ground - three seconds, then it refills",
          choices = {
              { key = "on", name = "on",
                help = "a burst for a break or a chase" },
              { key = "off", name = "off",
                help = "everybody runs at the same pace" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the deciding goal, again",
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

local TERMS_WIDTH = { ordinary = "normal goals",
    wide = "wide goals", narrow = "narrow goals" }

mode.presets = {
    { key = "classic", name = "Classic", help = "a match on grass", sets = {} },
    { key = "hockey", name = "Ice Hockey", help = "a rubber ball on ice",
      sets = { pitch = "ice", ball = "rubber" } },
    { key = "beach", name = "Beach", help = "a beach ball on a bouncy pitch",
      sets = { ball = "beach", pitch = "bouncy" } },
    { key = "penalties", name = "Penalties", help = "a penalty shoot-out",
      sets = { format = "penalties" } },
}

function mode.may_attack(attacker, victim)
    return false
end

function mode.terms()
    local key = OF.gamemodes.option_showing(mode.key, "goals") or GOAL_DEFAULT
    if OF.gamemodes.option_showing(mode.key, "format") == "penalties" then
        return OF.lang.fill("@ penalties a side, @",
            tostring(football.PEN_KICKS), TERMS_WIDTH[key] or TERMS_WIDTH[GOAL_DEFAULT])
    end
    return OF.lang.fill("first to @ goals, @",
        tostring(OF.gamemodes.target_for and OF.gamemodes.target_for(mode.key)
            or TARGET_GOALS), TERMS_WIDTH[key] or TERMS_WIDTH[GOAL_DEFAULT])
end

function mode.setup(players, options)

    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAY)
    end
    OF.util.publish(TARGET_KEY, options.target or TARGET_GOALS)
    OF.util.publish(SCORE_KEY, "0 0 0")
end

local function pitch_for_room(level, area)
    for _, pitchKey in ipairs(football.PITCH_ORDER) do
        local place = OF.util.asks(OF.arena, "find") and OF.arena.find(pitchKey) or nil
        if place ~= nil and place.level ~= nil and place.level == level
            and (place.area or 1) == (area or 1) then
            return pitchKey
        end
    end
    return nil
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then hostNoPitch = true return end
    local key = pitch_for_room(here.level, here.area)
    if key == nil then
        hostNoPitch = true
        return
    end
    hostNoPitch = false
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f", key, here.level, here.area))
    centre_ball(football.PITCHES[key])
    publish_ball()
end

function mode.late_join(localIndex)
    return ROLE_PLAY
end

local function seed_kicks()
    lastKick = {}
    if not OF.util.is_host() then return end
    for index = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        local row = gPlayerSyncTable[index]
        if np ~= nil and np.connected and row ~= nil then
            local n = tonumber(numbers(row[KICK_KEY])[1])
            if n ~= nil then lastKick[np.globalIndex] = n end
        end
    end
end

function mode.on_start()

    seq, wireSeen, frame, cooldown = 0, nil, 0, 0
    pending = nil
    press = {}
    sprinting = false
    if OF.util.asks(OF.moves, "sprint_reset") then OF.moves.sprint_reset() end
    football.spend_charge()
    brokeSeen = false
    hostFrame = 0
    history, kickoffStep, refusedGI, refusedN = {}, 0, -1, 0
    goalSeenAt = nil
    ball.step, ball.serial = 0, 0
    drawOff = { x = 0, y = 0, z = 0 }
    replay = nil
    seed_kicks()
    faced = false
    heardPitch = { speed = 0, held = nil }
    lastToucher, lastResume = -1, nil
    penShot, penShotAt, penSaved, penSeen, penMineShot = false, 0, false, nil, false
    local pitch = football.pitch()
    if pitch ~= nil then centre_ball(pitch) end
    football.pen_reset()

end

function mode.cleanup()
    football.hide_all()
    lastKick, wireSeen, pending, history = {}, nil, nil, {}
    drawOff = { x = 0, y = 0, z = 0 }
    replay = nil
    if OF.util.is_host() then
        OF.util.publish(BALL_KEY, nil)
        OF.util.publish(SCORE_KEY, nil)
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(PEN_KEY, nil)
    end
    OF.util.publish_row(0, KICK_KEY, "")
end

function mode.update()
    if football.in_room(0) then football.face_the_opening() end
    local _, _, resume = football.score()
    local pen = football.penalties() and football.pen() or nil
    if pen ~= nil and pen.serial ~= penSeen then
        penSeen = pen.serial
        penMineShot = false
        if football.in_room(0) then pen_line_up(pen) end
        lastResume = resume
    elseif pen ~= nil and football.paused() and football.in_room(0) then

        local m0 = gMarioStates[0]
        local slot = football.pen_slot(0, pen, football.pitch())
        if slot ~= nil and m0 ~= nil and m0.pos ~= nil then
            local dx, dz = m0.pos.x - slot.x, m0.pos.z - slot.z
            if dx * dx + dz * dz > 400 * 400 then pen_line_up(pen) end
        end
    end
    if lastResume == nil then
        lastResume = resume
    elseif resume ~= lastResume then
        lastResume = resume
        if football.in_room(0) and not football.penalties() then football.line_up() end
    end
    local m = gMarioStates[0]
    if football.in_room(0) and OF.gamemodes.can_play(0) then

        football.work_the_charge(m)
        if select(2, football.charge_now()) then

            if OF.util.asks(OF.moves, "sprint_step") then OF.moves.sprint_step(m, false) end
        else
            football.work_the_sprint(m)
        end

        football.hold_hit_stop(m)
        football.my_touch(m)

        if not press.spent and (press.since or 999) >= football.FEEL.bodyIgnore then
            football.keep_out(m, ball)
        end
        if pen ~= nil then football.pen_hold_back(m, pen, football.pitch()) end
    elseif cooldown > 0 then
        cooldown = cooldown - 1
    end
end

local hitStop = { left = 0, frame = nil }

function football.feel_strike(m, speed, charged)
    local F = football.FEEL
    local frames = 0
    for i, from in ipairs(F.hitTiers) do
        if speed >= from then frames = F.hitStop[i] end
    end
    if charged then frames = F.hitStop[#F.hitStop] end
    local anim = m ~= nil and m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx ~= nil and m.marioObj.header.gfx.animInfo or nil
    if frames > 0 and anim ~= nil then
        hitStop.left, hitStop.frame = frames, anim.animFrame
    end
    if m ~= nil and m.particleFlags ~= nil then
        local flag = speed >= F.sparkAt and PARTICLE_HORIZONTAL_STAR or PARTICLE_DUST
        if flag ~= nil then m.particleFlags = OF.util.add_flag(m.particleFlags, flag) end
    end
    return frames
end

function football.hold_hit_stop(m)
    if hitStop.left <= 0 then return false end
    hitStop.left = hitStop.left - 1
    local anim = m ~= nil and m.marioObj ~= nil and m.marioObj.header.gfx.animInfo or nil
    if anim ~= nil and hitStop.frame ~= nil then anim.animFrame = hitStop.frame end
    return true
end

function football.side_rgb(side)
    local c = OF.hud ~= nil and OF.hud.C ~= nil and (side == "red" or side == "blue") and OF.hud.C[side] or nil
    if c ~= nil then return c[1], c[2], c[3] end
    return 255, 255, 255
end

function football.draw_telegraphs()
    local p = football.pitch()
    local m = gMarioStates[0]
    if p == nil or m == nil or m.pos == nil or not football.in_room(0) then return end
    local F = football.FEEL
    local r, g, b = football.side_rgb(OF.teams.of(0))
    local kind = football.kind_of(m.action)
    if kind ~= nil and not press.spent and football.live(press, kind) then
        local fx, fz = facing(m)
        local ring = F.ring
        local inside = football.in_ring(m, ball, ring)
        OF.util.zone_ring({ x = m.pos.x + fx * (ring.forward or 0), y = m.pos.y + 4,
            z = m.pos.z + fz * (ring.forward or 0) }, ring.reach, 24, 2, r, g, b, inside and 200 or 70)
    end
    local c = charge or 0
    if c > 0 then
        local full = c >= 1
        local a = full and ((math.floor((frame or 0) / 4) % 2 == 0) and 255 or 90) or 160
        OF.util.zone_ring({ x = m.pos.x, y = m.pos.y + 4, z = m.pos.z }, 60 + 60 * c, 16, 3,
            full and 120 or r, full and 200 or g, full and 255 or b, a)
    end
    local up = (ball.y or 0) - (p.floor or 0)
    if up > F.shadowOver then
        OF.util.zone_ring({ x = ball.x, y = p.floor + 4, z = ball.z }, BALL_RADIUS + up * 0.12, 24, 2,
            40, 40, 40, 170)
    end
end

function football.trail(b)
    local speed = math.sqrt((b.vx or 0) ^ 2 + (b.vy or 0) ^ 2 + (b.vz or 0) ^ 2)
    if speed <= football.FEEL.trailAt or (frame or 0) % 2 ~= 0 then return false end
    if spawn_non_sync_object == nil or id_bhvSparkleSpawn == nil then return false end
    spawn_non_sync_object(id_bhvSparkleSpawn, E_MODEL_NONE or 0, b.x, b.y, b.z, nil)
    return true
end

function football.my_touch(m)

    if kickCopies > 0 and kickText ~= nil and not OF.util.is_host() then
        kickCopies = kickCopies - 1
        OF.util.send_to_host({ ofp = football.PACKET_KICK, t = kickText }, true)
    end

    football.press_note(press, m)
    if cooldown > 0 then cooldown = cooldown - 1 return nil end
    if not football.in_room(0) or football.paused() then return nil end

    if ball.goal ~= nil then return nil end
    local me = gNetworkPlayers[0]
    local gi = me ~= nil and me.globalIndex or -1
    if football.penalties() and not football.pen_may_touch(gi, penMineShot) then
        return nil
    end
    local kind, vx, vy, vz, spin = football.touch(m, ball, (football.charge_now()),
        football.FEEL.ring, press)
    if kind == nil then return nil end
    if kind ~= "dribble" then press.spent = true end
    vx, vy, vz = football.assist(m, ball, kind, vx, vy, vz)
    if kind ~= "dribble" then
        football.feel_strike(m, math.sqrt(vx * vx + vy * vy + vz * vz), (charge or 0) >= 1)
        football.spend_charge()
    end
    cooldown = kind == "dribble" and DRIBBLE_GAP or COOLDOWN
    local pen = football.penalties() and football.pen() or nil
    if pen ~= nil and gi == pen.striker then penMineShot = true end
    kicks = kicks + 1
    local serialSeen = ball.serial or 0
    ball.vx, ball.vy, ball.vz = vx, vy, vz
    ball.spin = spin or 0
    clamp_speed(ball)
    ball.toucher, ball.touchN, ball.touchStep = gi, kicks, ball.step or 0
    football.end_replay()
    if OF.util.is_host() then
        ball.serial = serialSeen + 1
        ball.from = { x = ball.x, y = ball.y, z = ball.z, vx = ball.vx, vy = ball.vy,
            vz = ball.vz, spin = ball.spin }
        lastToucher = gi
        football.pen_touched(gi)
        publish_ball()
        return kind
    end

    local text = string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %s %.0f",
        kicks, ball.step or 0, serialSeen, ball.x, ball.y, ball.z,
        ball.vx * 10, ball.vy * 10, ball.vz * 10, MOUTH_WORD[ball.mouth] or "-",
        (ball.spin or 0) * 100)
    local claim = football.read_claim(text)
    ball.x, ball.y, ball.z = claim.x, claim.y, claim.z
    ball.vx, ball.vy, ball.vz = claim.vx, claim.vy, claim.vz
    ball.spin = claim.spin
    OF.util.publish_row(0, KICK_KEY, text)
    kickText, kickCopies = text, football.FEEL.claimCopies
    OF.util.send_to_host({ ofp = football.PACKET_KICK, t = text })
    football.net.sent = football.net.sent + 1
    pending = { n = kicks, serial = serialSeen, untilFrame = frame + ACK_WAIT }
    return kind
end

function football.read_claim(text)
    local parts = numbers(text)
    local n = tonumber(parts[1])
    if #parts < 9 then return nil, n end
    local claim = {
        step = tonumber(parts[2]), serial = tonumber(parts[3]) or 0,
        x = tonumber(parts[4]) or 0, y = tonumber(parts[5]) or 0, z = tonumber(parts[6]) or 0,
        vx = (tonumber(parts[7]) or 0) / 10, vy = (tonumber(parts[8]) or 0) / 10,
        vz = (tonumber(parts[9]) or 0) / 10, mouth = WORD_MOUTH[parts[10] or "-"],
        spin = math.max(-1, math.min(1, (tonumber(parts[11]) or 0) / 100)),
    }
    if claim.step == nil then return nil, n end
    return claim, n
end

function football.hear_guests()
    local fresh = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local li = entry.localIndex
        local np = gNetworkPlayers[li]
        if li ~= 0 and np ~= nil and np.connected then
            local row = gPlayerSyncTable[li]
            local gi = np.globalIndex
            local text = row ~= nil and row[KICK_KEY] or nil
            local packed = packetKicks[gi]
            if packed ~= nil and (tonumber(numbers(packed)[1]) or -1) > (tonumber(numbers(text)[1]) or -1) then
                text = packed
            end
            local claim, n = football.read_claim(text)
            local last = lastKick[gi]
            if n ~= nil and (last == nil or n > last or n < last - 1000) then
                lastKick[gi] = n
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
        if OF.gamemodes.can_play(touch.li) and football.in_room(touch.li) then
            ok, why = football.judge(touch.gi, touch.n, touch.claim, gMarioStates[touch.li])
        end
        if ok then
            football.net.accepted = football.net.accepted + 1
            football.take(touch.gi, touch.n, touch.claim)
        else
            football.net.refused[why or "?"] = (football.net.refused[why or "?"] or 0) + 1
            refusedGI, refusedN = touch.gi, touch.n
            mustPublish = true
        end
    end
end

function football.goal_due()
    if not OF.util.is_host() then return nil end
    if ball.goal == nil then
        goalSeenAt = nil
        return nil
    end
    goalSeenAt = goalSeenAt or hostFrame
    if hostFrame - goalSeenAt < GOAL_WAIT then return nil end
    return ball.goal
end

local function goal_for(side, p)
    local red, blue = football.score()
    if side == "red" then red = red + 1 else blue = blue + 1 end
    local resume = OF.gamemodes.since_start() + KICKOFF_SECONDS

    publish_score(red, blue, resume, side == "red" and "blue" or "red", lastToucher, true)
    centre_ball(p)
    publish_ball()

    return red, blue
end

function football.show_break()
    if brokeSeen then return false end
    brokeSeen = true
    OF.ball.puff(ball)
    if SOUND_GENERAL_BREAK_BOX ~= nil then
        OF.gamemodes.round_sound_throttled("fbbreak", 15, SOUND_GENERAL_BREAK_BOX)
    end
    return true
end

function football.shatter(p)
    football.show_break()
    local red, blue = football.score()
    local li = lastToucher >= 0 and network_local_index_from_global ~= nil
        and network_local_index_from_global(lastToucher) or nil
    local breaker = type(li) == "number" and li >= 0 and OF.teams.of(li) or nil
    local side = breaker == "red" and "blue" or "red"
    publish_score(red, blue, OF.gamemodes.since_start() + KICKOFF_SECONDS, side,
        football.scorer() or -1, true)
    centre_ball(p)
    publish_ball()

    return side
end

function football.pen_touched(gi)
    if not OF.util.is_host() then return end
    if not football.penalties() then return end
    local pen = football.pen()
    if pen == nil then return end
    if gi == pen.striker and not penShot then
        penShot, penShotAt = true, hostFrame
    elseif gi == pen.keeper and penShot then
        penSaved = true
    end
end

local function pen_publish(serial, redTaken, blueTaken, last)
    local side = blueTaken < redTaken and "blue" or "red"
    local other = side == "red" and "blue" or "red"
    local taken = side == "red" and redTaken or blueTaken
    local shooters, keepers = side_order(side), side_order(other)
    local striker = #shooters > 0 and shooters[(taken % #shooters) + 1] or -1
    local keeper = #keepers > 0 and keepers[(taken % #keepers) + 1] or -1
    local resume = OF.gamemodes.since_start() + PEN_BREAK_SECONDS
    local red, blue = football.score()
    publish_score(red, blue, resume, side, lastToucher, true)
    OF.util.publish(PEN_KEY, string.format("%.0f %s %.0f %.0f %.0f %.0f %.0f %s",
        serial, side, striker, keeper, (resume + PEN_SHOOT_SECONDS) * 10,
        redTaken, blueTaken, last or "-"))
    penShot, penShotAt, penSaved = false, 0, false
    local p = football.pitch()
    if p ~= nil then centre_ball(p) end
    publish_ball()
end

local function pen_settle(pen, scored)
    local red, blue = football.score()
    if scored then
        if pen.side == "red" then red = red + 1 else blue = blue + 1 end
    end
    local redTaken, blueTaken = pen.redTaken, pen.blueTaken
    if pen.side == "red" then redTaken = redTaken + 1 else blueTaken = blueTaken + 1 end
    publish_score(red, blue, OF.gamemodes.since_start(), pen.side, lastToucher, false)
    local last = scored and "goal" or (penSaved and "save" or "miss")

    if football.pen_decided(red, blue, redTaken, blueTaken) then
        OF.util.publish(PEN_KEY, string.format("%.0f %s %.0f %.0f %.0f %.0f %.0f %s",
            pen.serial, pen.side, -1, -1, 0, redTaken, blueTaken, last))
        OF.gamemodes.finish(OF.teams.result_text(red, blue),
            OF.gamemodes.team_winner(OF.teams.find(red > blue and "red" or "blue")))
        return
    end
    pen_publish(pen.serial + 1, redTaken, blueTaken, last)
end

function football.pen_host(pitch, halfWidth, held)
    if not OF.util.is_host() then return end
    local pen = football.pen()
    if pen == nil then
        pen_publish(1, 0, 0, "-")
        return
    end

    if pen.striker < 0 or pen.keeper < 0 then
        if hostFrame % 15 == 0 then
            pen_publish(pen.serial + 1, pen.redTaken, pen.blueTaken, pen.last)
        end
        return
    end
    if held then
        centre_ball(pitch)
        if hostFrame % 15 == 0 then publish_ball() end
        return
    end

    local walls = football.advance(ball, pitch, halfWidth)
    if walls ~= nil then mustPublish = true end
    for _, gi in ipairs(walls or {}) do
        if gi == pen.keeper and penShot then penSaved = true end
    end

    if ball.broke then
        football.show_break()
        pen_settle(pen, false)
        return
    end
    local side = football.goal_due()
    if side ~= nil then
        pen_settle(pen, side == pen.side)
        return
    end

    if ball.goal ~= nil then return end
    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy + ball.vz * ball.vz)
    if penShot then
        local flown = hostFrame - penShotAt
        if flown > PEN_FLIGHT_FRAMES or (flown > 10 and speed < 1.5) then
            pen_settle(pen, false)
            return
        end
    elseif OF.gamemodes.since_start() > pen.deadline then
        pen_settle(pen, false)
        return
    end
    if mustPublish or hostFrame % PUBLISH_EVERY == 0 then
        mustPublish = false
        publish_ball(hostFrame % RELIABLE_EVERY ~= 0)
    end
end

function mode.host_update()
    if hostNoPitch then
        hostNoPitch = false

        local name, tried = nil, nil
        if OF.util.asks(OF.arena, "missing_level") then
            name, tried = OF.arena.missing_level(football.PITCH_ORDER[1])
        end
        if name ~= nil then
            OF.gamemodes.abandon("Football needs @: no @ here.",
                name, tried)
        else
            OF.gamemodes.abandon("Football needs a pitch, and this map has none.")
        end
        return
    end
    local pitch = football.pitch()
    if pitch == nil then return end
    local halfWidth = football.goal_half_width()
    hostFrame = hostFrame + 1

    football.release()

    local held = football.paused()
    football.hear_guests()

    if football.penalties() then
        football.pen_host(pitch, halfWidth, held)
        return
    end

    if held then
        centre_ball(pitch)
        if hostFrame % 15 == 0 then publish_ball() end
        return
    end

    if football.advance(ball, pitch, halfWidth) ~= nil then mustPublish = true end
    if ball.broke then
        football.shatter(pitch)
        return
    end
    local side = football.goal_due()
    if side ~= nil then
        local red, blue = goal_for(side, pitch)
        local target = target_goals()
        if red >= target or blue >= target then
            OF.gamemodes.finish(OF.teams.result_text(red, blue),
                OF.gamemodes.team_winner(OF.teams.find(red > blue and "red" or "blue")))
        end
        return
    end
    if mustPublish or hostFrame % PUBLISH_EVERY == 0 then
        mustPublish = false
        publish_ball(hostFrame % RELIABLE_EVERY ~= 0)
    end
end

function mode.overtime()
    local red, blue = football.score()

    if football.penalties() then
        local pen = football.pen()
        if pen ~= nil then
            return not football.pen_decided(red, blue, pen.redTaken, pen.blueTaken)
                and not (pen.redTaken == pen.blueTaken and red ~= blue)
        end
    end
    return red == blue
end

function mode.still_winnable()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

function mode.on_timeout()
    local red, blue = football.score()
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
    local red, blue = football.score()
    return string.format("%.0f", side == "red" and red or blue)
end

function mode.side_place(side)
    local pitch, _, level, area = football.pitch()
    if pitch == nil or pitch.spawns[side] == nil then return nil end
    local at = pitch.spawns[side]
    return { x = pitch.centre.x + at.x, y = pitch.floor, z = pitch.centre.z + at.z,
             level = level, area = area }
end

function mode.side_slot(side, place, count)
    local p = football.pitch()
    if p == nil or (side ~= "red" and side ~= "blue") then return nil end
    local slot = football.formation(p, side, count, football.kickoff_side() == side)[place]
    if slot == nil then return nil end
    return { x = slot.x, y = p.floor, z = slot.z, faceX = slot.faceX, faceZ = slot.faceZ }
end

function mode.death_place()
    local slot, p = football.slot_for(0)
    if slot == nil then return nil end
    local _, _, level, area = football.pitch()
    return { x = slot.x, y = p.floor, z = slot.z, level = level, area = area }
end

function mode.replayDecider()
    local gi = football.scorer()
    if gi == nil then return nil end
    local li = network_local_index_from_global(gi)
    if type(li) ~= "number" or li < 0 then return nil end
    return li
end

function football.ball_model()
    OF.ball.forget_model()
    local id, scale, shadow = OF.ball.model(BALL_RADIUS)
    return id, scale, shadow or nil
end

local function model_ids()
    if modelIds ~= nil then return modelIds end
    local ids = {}
    ids.ball, ids.ballScale, ids.ballShadow = football.ball_model()
    local function actor(geo)
        if not OF.util.optional("mod_file_exists", false, "actors/" .. geo .. ".bin") then
            return nil
        end
        local id = OF.util.optional("smlua_model_util_get_id", nil, geo)
        if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
        return id
    end
    ids.line = actor(LINE_GEO)
    ids.red, ids.blue = actor(NET_GEO.red), actor(NET_GEO.blue)
    modelIds = ids
    return ids
end

function football.pieces(p, halfWidth, ids)
    local list = {}
    local cx, cz, y = p.centre.x, p.centre.z, p.floor + LINE_LIFT
    local function line(name, x, z, alongX, alongZ, yaw)
        if ids.line == nil then return end
        list[#list + 1] = { name = name, model = ids.line, x = x, y = y, z = z,
            sx = alongX / MODEL_UNIT, sy = 1, sz = alongZ / MODEL_UNIT,
            pitch = 0, yaw = yaw or 0, roll = 0 }
    end
    local w = LINE_WIDTH
    local depth = p.maxZ - p.minZ
    local radius = p.circleRadius or CIRCLE_RADIUS
    local boxDepth = p.boxDepth or BOX_DEPTH
    if p.drawLines then
        line("fbHalf", cx, cz, w, depth)
        for i = 0, CIRCLE_PIECES - 1 do
            local a = (i + 0.5) * 2 * math.pi / CIRCLE_PIECES
            local piece = 2 * math.pi * radius / CIRCLE_PIECES
            local yaw = math.floor(-(a + math.pi / 2) * 32768 / math.pi) % 65536
            line("fbRing" .. i, cx + radius * math.cos(a),
                cz + radius * math.sin(a), piece, w, yaw)
        end
        for _, s in ipairs(SIGNS) do
            local tag = s < 0 and "W" or "E"
            local gx = cx + s * p.goalX
            local boxZ = halfWidth + BOX_WIDER
            line("fbGoalLine" .. tag, gx, cz, w, depth)
            line("fbBoxFront" .. tag, gx - s * boxDepth, cz, w, boxZ * 2)
            line("fbBoxL" .. tag, gx - s * boxDepth / 2, cz - boxZ, boxDepth, w)
            line("fbBoxR" .. tag, gx - s * boxDepth / 2, cz + boxZ, boxDepth, w)
        end
    end
    if p.spawnGoals then
        for _, s in ipairs(SIGNS) do
            local side = s < 0 and "red" or "blue"
            local tag = s < 0 and "W" or "E"
            local net = ids[side]
            local gx = cx + s * p.goalX
            local h = p.goalHeight
            local back = gx + s * p.goalDepth
            local mid = gx + s * p.goalDepth / 2
            if net ~= nil then

                list[#list + 1] = { name = "fbNetBack" .. tag, model = net,
                    x = back, y = p.floor + h / 2, z = cz,
                    sx = h / MODEL_UNIT, sy = 1, sz = halfWidth * 2 / MODEL_UNIT,
                    pitch = 0, yaw = 0, roll = 0x4000 }
                for _, e in ipairs(SIGNS) do
                    list[#list + 1] = { name = "fbNetSide" .. tag .. e, model = net,
                        x = mid, y = p.floor + h / 2, z = cz + e * halfWidth,
                        sx = p.goalDepth / MODEL_UNIT, sy = 1, sz = h / MODEL_UNIT,
                        pitch = 0x4000, yaw = 0, roll = 0 }
                end
                list[#list + 1] = { name = "fbNetTop" .. tag, model = net,
                    x = mid, y = p.floor + h, z = cz,
                    sx = p.goalDepth / MODEL_UNIT, sy = 1,
                    sz = halfWidth * 2 / MODEL_UNIT, pitch = 0, yaw = 0, roll = 0 }
            end
            if ids.line ~= nil then
                for _, e in ipairs(SIGNS) do
                    list[#list + 1] = { name = "fbPost" .. tag .. e, model = ids.line,
                        x = gx, y = p.floor + h / 2, z = cz + e * halfWidth,
                        sx = w * 2 / MODEL_UNIT, sy = 1, sz = h / MODEL_UNIT,
                        pitch = 0x4000, yaw = 0x4000, roll = 0 }
                end
                list[#list + 1] = { name = "fbBar" .. tag, model = ids.line,
                    x = gx, y = p.floor + h, z = cz,
                    sx = w * 2 / MODEL_UNIT, sy = 1, sz = halfWidth * 2 / MODEL_UNIT,
                    pitch = 0, yaw = 0, roll = 0x4000 }
            end
        end
    end
    return list
end

local drawn = {}

function football.hide_all()
    for name in pairs(drawn) do OF.gamemodes.hide_token(name) end
    drawn = {}
    OF.gamemodes.hide_token("fbBall")
    OF.gamemodes.hide_token("fbBallShadow")
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

local KICK_HEARD = 60
local KICK_JUMP = 20

local function kick_sound(speed)
    local tiers = football.FEEL.soundTiers
    if (speed or 0) >= tiers[2] then return SOUND_ACTION_HIT_3 or SOUND_ACTION_HIT or SOUND_ACTION_BOUNCE_OFF_OBJECT end
    if (speed or 0) >= tiers[1] then return SOUND_ACTION_HIT or SOUND_ACTION_BOUNCE_OFF_OBJECT end
    return SOUND_ACTION_BOUNCE_OFF_OBJECT
end
function football.hear_the_pitch(token)
    local played = nil
    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy + ball.vz * ball.vz)
    if speed >= KICK_HEARD and speed - heardPitch.speed >= KICK_JUMP then
        played = OF.gamemodes.round_sound_throttled("fbkick", 6, kick_sound(speed), token)
    end
    heardPitch.speed = speed

    if (ball.rang or 0) > 0 then
        ball.rang = nil
        if SOUND_ACTION_METAL_BONK ~= nil then
            played = OF.gamemodes.round_sound_throttled("fbpost", 10,
                SOUND_ACTION_METAL_BONK, token) or played
        end
    end
    local held = football.paused() and not football.penalties()
    if held then
        local left = football.kickoff_left()
        if left ~= nil then OF.gamemodes.tick_down(math.ceil(left - 0.1)) end
    elseif heardPitch.held == true then
        played = OF.gamemodes.round_sound(OF.sounds.SHOT) or played
    end
    heardPitch.held = held
    return played
end

function football.correct(fromX, fromY, fromZ)
    drawOff.x = drawOff.x + fromX - ball.x
    drawOff.y = drawOff.y + fromY - ball.y
    drawOff.z = drawOff.z + fromZ - ball.z
end

local DRAW_EASE = 0.6
local DRAW_SNAP = 400
function football.drawn()
    local o = drawOff
    if o.x * o.x + o.y * o.y + o.z * o.z > DRAW_SNAP * DRAW_SNAP then
        o.x, o.y, o.z = 0, 0, 0
    end
    local src = replay or ball
    local at = { x = src.x + o.x, y = src.y + o.y, z = src.z + o.z }
    o.x, o.y, o.z = o.x * DRAW_EASE, o.y * DRAW_EASE, o.z * DRAW_EASE
    if math.abs(o.x) + math.abs(o.y) + math.abs(o.z) < 0.5 then o.x, o.y, o.z = 0, 0, 0 end
    return at
end

function football.follow_the_wire()
    local wire = football.wire_now()
    if wire == nil or wire == wireSeen then return false end
    local read = adopt(wire, {})
    if read == nil then
        wireSeen = wire
        return false
    end
    local me = gNetworkPlayers[0]
    if not football.should_adopt(read, me ~= nil and me.globalIndex or -1, frame) then
        return false
    end
    wireSeen = wire
    local fromX, fromY, fromZ = ball.x, ball.y, ball.z
    local shownAt = football.drawn_peek()
    local serialWas = ball.serial or 0
    adopt(wire)
    ball.goal, ball.goalStep = nil, nil

    local mine = me ~= nil and read.toucher == me.globalIndex
    if read.serial > serialWas and not mine and football.see_touch(shownAt) then
        return true
    end

    football.correct(fromX, fromY, fromZ)
    return true
end

local REPLAY_RATE = 2
local REPLAY_MOST = 2 * MAX_REWIND

function football.drawn_peek()
    local src = replay or ball
    return { x = src.x + drawOff.x, y = src.y + drawOff.y, z = src.z + drawOff.z }
end

function football.see_touch(shownAt)
    local f = ball.from
    local late = (ball.step or 0) - (ball.touchStep or -9999)
    if f == nil or late <= 0 or late > REPLAY_MOST then return false end
    replay = { x = f.x, y = f.y, z = f.z, vx = f.vx, vy = f.vy, vz = f.vz,
        spin = f.spin or 0, step = ball.touchStep, toucher = ball.toucher,
        touchStep = ball.touchStep, mouth = ball.mouth }
    if shownAt ~= nil then
        drawOff.x, drawOff.y, drawOff.z = shownAt.x - f.x, shownAt.y - f.y, shownAt.z - f.z
    end
    return true
end

function football.run_replay(p, halfWidth)
    if replay == nil then return false end
    if p == nil then replay = nil return false end
    for _ = 1, REPLAY_RATE do
        if (replay.step or 0) >= (ball.step or 0) then break end
        football.advance(replay, p, halfWidth)
    end
    if (replay.step or 0) >= (ball.step or 0) then
        football.end_replay()
        return false
    end
    return true
end

function football.end_replay()
    if replay == nil then return end
    drawOff.x = drawOff.x + replay.x - ball.x
    drawOff.y = drawOff.y + replay.y - ball.y
    drawOff.z = drawOff.z + replay.z - ball.z
    replay = nil
end

function football.replaying()
    return replay
end

function mode.scenery()

    OF.gamemodes.hear_sides(football.score())
    local pitch = football.pitch()

    if pitch == nil or not football.in_room(0) or not OF.util.round_screen() then
        football.hide_all()
        return
    end
    local halfWidth = football.goal_half_width()
    local ids = model_ids()

    frame = frame + 1
    if not OF.util.is_host() then
        football.follow_the_wire()
        if football.paused() then
            centre_ball(pitch)
        elseif ball.broke then

            football.show_break()
        elseif OF.gamemodes.state() == OF.gamemodes.ACTIVE then
            football.advance(ball, pitch, halfWidth)
        end
    end
    if not ball.broke then brokeSeen = false end

    for _, piece in ipairs(football.pieces(pitch, halfWidth, ids)) do place(piece) end

    football.run_replay(pitch, halfWidth)
    local shown = football.drawn()
    if ball.broke then
        OF.gamemodes.hide_token("fbBall")
        OF.gamemodes.hide_token("fbBallShadow")
        return
    end
    local token = OF.gamemodes.show_token("fbBall", ids.ball,
        { x = shown.x, y = shown.y, z = shown.z })
    if ids.ballShadow and E_MODEL_WATER_BOMB_SHADOW ~= nil then

        local shade = OF.gamemodes.show_token("fbBallShadow", E_MODEL_WATER_BOMB_SHADOW,
            { x = shown.x, y = shown.y, z = shown.z })
        if shade ~= nil then
            OF.util.optional("obj_scale", nil, shade, BALL_RADIUS * 1.25 / 160)
        end
    end
    football.hear_the_pitch(token)
    football.trail(ball)
    if token ~= nil then
        OF.util.optional("obj_scale", nil, token, ids.ballScale)

        local speed = math.sqrt(ball.vx * ball.vx + ball.vz * ball.vz)
        if speed > 0.5 then
            token.oFaceAngleYaw = math.floor(math.atan(ball.vx, ball.vz)
                * 32768 / math.pi) % 65536
            token.oFaceAnglePitch = math.floor((token.oFaceAnglePitch or 0)
                + speed / BALL_RADIUS * 32768 / math.pi) % 65536
        end
    end
end

function football.controls_lines()
    local lines = {
        OF.lang.t("B - kick it, or a header at a run"),
        OF.lang.t("A, then B - a volley, high over them"),
        OF.lang.t("Z in the air beside it - a shot"),
    }
    if sprint_on() then
        table.insert(lines, OF.lang.t("Hold X - sprint"))
    end
    if charge_on() then
        table.insert(lines, OF.lang.t("Hold Y - charge the next strike"))
    end
    table.insert(lines, OF.lang.t("No button: run into it to dribble"))
    return lines
end

function football.draw_controls()
    local m = gMarioStates[0]
    if m == nil then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_PLAY then return false end
    if not OF.util.can_play(0) or not football.in_room(0) then return false end
    return OF.util.legend(football.controls_lines()) == true
end

local kickoffEntry = { id = "kickoff", prio = 60 }
function football.kickoff_line()
    local left = football.kickoff_left()
    if left == nil or football.penalties() then return nil end
    kickoffEntry.text = OF.lang.t("Kick off")
    kickoffEntry.tone = football.kickoff_side()

    kickoffEntry.figure = math.max(1, math.ceil(left - 0.1))
    return kickoffEntry
end

local penSaid = nil
function football.pen_reset() penSaid = nil end
function football.pen_news(pen)
    if pen == nil or pen.serial == penSaid then return nil end
    local said = penSaid
    penSaid = pen.serial
    if said == nil or not OF.util.asks(OF.hud, "banner") then return nil end

    local shooter = pen.redTaken > pen.blueTaken and "red" or "blue"
    local mine = OF.teams.of(0)
    local keptOut = mine == "red" or mine == "blue"
    if pen.last == "save" then
        return OF.hud.banner("objective", OF.lang.t("SAVED"), nil,
            { side = keptOut and (mine ~= shooter and "us" or "them") or nil })
    elseif pen.last == "miss" then
        return OF.hud.banner("objective", OF.lang.t("MISSED"), nil,
            { side = keptOut and (mine ~= shooter and "us" or "them") or nil })
    end
    return nil
end

function mode.hud()
    football.draw_controls()
    football.draw_telegraphs()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local kickoff = football.kickoff_line()
    if kickoff ~= nil then state(kickoff.id, kickoff.text, kickoff) end
    local pen = football.penalties() and football.pen() or nil
    football.pen_news(pen)
    if pen ~= nil and pen.striker >= 0 then
        local me = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].globalIndex or -1
        if pen.striker == me then
            state("pen", OF.lang.t("Your kick"), { prio = 70, tone = "target" })
        elseif pen.keeper == me then
            state("pen", OF.lang.t("You keep"), { prio = 70, tone = "target" })
        else
            state("pen", OF.lang.t("Penalties"), { prio = 50,
                figure = tostring(pen.redTaken + pen.blueTaken + 1) .. "/"
                    .. tostring(football.PEN_KICKS * 2) })
        end
        return
    end
    local prompt = OF.util.asks(OF.hud, "prompt")

    if charge > 0 then
        if prompt then OF.hud.prompt("grenade", OF.lang.t("Charge"), charge, { tone = "target" }) end
        return
    end

    local stamina = stamina_now()
    if sprint_on() and stamina < football.SPRINT_FULL and prompt then
        OF.hud.prompt("flash", OF.lang.t("Sprint"), stamina / football.SPRINT_FULL, { tone = "target" })
    end
end

function mode.targets(viewer)
    if football.pitch() == nil then return nil end
    return { { id = "ball", pos = { x = ball.x, y = ball.y, z = ball.z }, label = "Ball",
               tone = "target", priority = 80, compass = "offscreen" } }
end

football.mode = mode

function mode.cluster()
    return OF.gamemodes.side_cluster(function(key)
        local red, blue = football.score()
        return key == "red" and red or blue
    end, target_goals())
end

mode.target_now = target_goals

OF.gamemodes.register(mode)
