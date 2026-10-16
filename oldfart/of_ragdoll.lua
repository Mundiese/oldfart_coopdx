OF = OF or {}
OF.ragdoll = OF.ragdoll or {}

local rag = OF.ragdoll

rag.ROW = "ragdoll"
rag.BUTTON = Y_BUTTON or 0x0080
rag.BUTTON_NAME = "Y"
rag.BUTTON_KEY = "M"
rag.PACKET = "rgp"
rag.GRAB_PACKET = "rgg"
rag.ANIM = "of_ragdoll_still"
rag.MARK = 0x52

rag.GRAVITY = 4
rag.TERMINAL = 75
rag.SUBSTEPS = 2
rag.ITERATIONS = 4

rag.FRICTION = 0.12
rag.STICK = 0.8
rag.BOUNCE = 0.2

rag.AIR_DRAG = 0.998
rag.LIMB_DRAG = 0.965

rag.SETTLE_SPEED = 1.5
rag.SETTLE_DAMP = 0.55
rag.SETTLE_CONTACTS = 3
rag.REST_SPEED = 0.2
rag.REST_TICKS = 10

rag.THROW_FORWARD = 18
rag.THROW_UP = 14

rag.HOP_FROM = 6
rag.HOP_BASE = 10
rag.HOP_PER_SPEED = 0.3
rag.HOP_MAX = 24

rag.KNOCK_TUMBLE = 0.3

rag.KNOCK_LIFT = 12

rag.SPIN_BASE = 0.05
rag.SPIN_PER_SPEED = 0.006
rag.SPIN_MAX = 0.3
rag.SPIN_YAW = 0.06

rag.FLAIL = 7

rag.INVULNERABLE = 2

rag.GRAB_REACH = 160
rag.GRAB_SLACK = 1.6
rag.GRAB_LOSE = 4
rag.HOLD_MAX = 300
rag.THROW_SPEED = 30
rag.THROW_LIFT = 20

rag.HAND_FORWARD = 200
rag.HAND_UP = 420

rag.GETUP_AFTER = 15
rag.REST_GETUP = 75
rag.MAX_TICKS = 600
rag.SEND_EVERY = 2

rag.BONE_UNIT = 0.25

rag.POINTS = {
    { name = "pelvis", part = 2,  radius = 45 },
    { name = "waist",  part = 3,  radius = 45 },
    { name = "neck",   part = 4,  radius = 30 },
    { name = "crown",             radius = 70 },
    { name = "lsh",    part = 6,  radius = 25 },
    { name = "lel",    part = 7,  radius = 22 },
    { name = "lwr",    part = 8,  radius = 25 },
    { name = "rsh",    part = 10, radius = 25 },
    { name = "rel",    part = 11, radius = 22 },
    { name = "rwr",    part = 12, radius = 25 },
    { name = "lhip",   part = 14, radius = 30 },
    { name = "lkn",    part = 15, radius = 25 },
    { name = "lan",    part = 16, radius = 25 },
    { name = "ltoe",              radius = 20 },
    { name = "rhip",   part = 18, radius = 30 },
    { name = "rkn",    part = 19, radius = 25 },
    { name = "ran",    part = 20, radius = 25 },
    { name = "rtoe",              radius = 20 },

    { name = "lthumb",            radius = 10 },
    { name = "rthumb",            radius = 10 },
    { name = "lsole",             radius = 10 },
    { name = "rsole",             radius = 10 },
}
rag.P = {}
for i, point in ipairs(rag.POINTS) do rag.P[point.name] = i end
local P = rag.P
local COUNT = #rag.POINTS

rag.STANDING = {
    pelvis = { 0, 190, 0 },   waist = { 0, 258, 0 },   neck = { 0, 345, 0 },
    crown  = { 0, 425, 8 },
    lsh = { 79, 325, -10 },   lel = { 79, 260, -10 },  lwr = { 79, 200, -10 },
    rsh = { -79, 325, -10 },  rel = { -79, 260, -10 }, rwr = { -79, 200, -10 },
    lhip = { 42, 203, -8 },   lkn = { 42, 114, -8 },   lan = { 42, 47, -8 },
    ltoe = { 42, 20, 40 },
    rhip = { -42, 203, -8 },  rkn = { -42, 114, -8 },  ran = { -42, 47, -8 },
    rtoe = { -42, 20, 40 },

    lthumb = { 99, 200, -10 }, rthumb = { -59, 200, -10 },
    lsole = { 62, 47, -8 },    rsole = { -22, 47, -8 },
}

local CROWN_ALONG = 80
local TOE_FORWARD = 48
local TOE_DOWN = 27

rag.LINKS = {
    { "pelvis", "waist" }, { "waist", "neck" }, { "neck", "crown" },
    { "lsh", "lel" }, { "lel", "lwr" }, { "rsh", "rel" }, { "rel", "rwr" },
    { "lhip", "lkn" }, { "lkn", "lan" }, { "lan", "ltoe" },
    { "rhip", "rkn" }, { "rkn", "ran" }, { "ran", "rtoe" },
    { "waist", "lsh" }, { "waist", "rsh" }, { "neck", "lsh" },
    { "neck", "rsh" }, { "lsh", "rsh" },
    { "pelvis", "lhip" }, { "pelvis", "rhip" }, { "lhip", "rhip" },
    { "waist", "lhip" }, { "waist", "rhip" },
}

rag.RANGES = {
    { "pelvis", "neck",  { "pelvis", "waist", "neck" }, 0.72, 1.0 },
    { "waist",  "crown", { "waist", "neck", "crown" },  0.82, 1.0 },
    { "lsh",    "lwr",   { "lsh", "lel", "lwr" },       0.30, 1.0 },
    { "rsh",    "rwr",   { "rsh", "rel", "rwr" },       0.30, 1.0 },
    { "lhip",   "lan",   { "lhip", "lkn", "lan" },      0.45, 1.0 },
    { "rhip",   "ran",   { "rhip", "rkn", "ran" },      0.45, 1.0 },
    { "lkn",    "ltoe",  { "lkn", "lan", "ltoe" },      0.70, 1.12 },
    { "rkn",    "rtoe",  { "rkn", "ran", "rtoe" },      0.70, 1.12 },
}

rag.HINGES = {
    { "lsh", "lel", "lwr", "torso", 1 },
    { "rsh", "rel", "rwr", "torso", 1 },
    { "lhip", "lkn", "lan", "pelvis", -1 },
    { "rhip", "rkn", "ran", "pelvis", -1 },
}

rag.TWISTS = {
    { "lthumb", "lwr", "lel", "lwr",  { "lsh", "lel", "lwr" },  "hinge", 1.4 },
    { "rthumb", "rwr", "rel", "rwr",  { "rsh", "rel", "rwr" },  "hinge", 1.4 },
    { "lsole",  "lan", "lan", "ltoe", { "lhip", "lkn", "lan" }, "leg",   0.6 },
    { "rsole",  "ran", "ran", "rtoe", { "rhip", "rkn", "ran" }, "leg",   0.6 },
}

rag.TWIST_REACH = 20

local LINKS, RANGES, HINGES, TWISTS = {}, {}, {}, {}
for _, l in ipairs(rag.LINKS) do LINKS[#LINKS + 1] = { P[l[1]], P[l[2]] } end
for _, r in ipairs(rag.RANGES) do
    local chain = {}
    for _, name in ipairs(r[3]) do chain[#chain + 1] = P[name] end
    RANGES[#RANGES + 1] = { P[r[1]], P[r[2]], chain, r[4], r[5] }
end
for _, h in ipairs(rag.HINGES) do
    HINGES[#HINGES + 1] = { P[h[1]], P[h[2]], P[h[3]], h[4], h[5] }
end
rag.HINGES_AT = HINGES
for _, t in ipairs(rag.TWISTS) do
    TWISTS[#TWISTS + 1] = { P[t[1]], P[t[2]], P[t[3]], P[t[4]],
        { P[t[5][1]], P[t[5][2]], P[t[5][3]] }, t[6], t[7] }
end

local sqrt, abs, max, min = math.sqrt, math.abs, math.max, math.min

local function v(x, y, z) return { x = x, y = y, z = z } end

local function sub(a, b) return a.x - b.x, a.y - b.y, a.z - b.z end

local function len3(x, y, z) return sqrt(x * x + y * y + z * z) end

local function norm3(x, y, z)
    local l = len3(x, y, z)
    if l < 0.000001 then return 0, 0, 0, 0 end
    return x / l, y / l, z / l, l
end

local function cross3(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function dot3(ax, ay, az, bx, by, bz) return ax * bx + ay * by + az * bz end

local function orth(zx, zy, zz, xx, xy, xz, fx, fy, fz)
    local d = dot3(zx, zy, zz, xx, xy, xz)
    local ox, oy, oz, l = norm3(zx - d * xx, zy - d * xy, zz - d * xz)
    if l < 0.0001 and fx ~= nil then
        d = dot3(fx, fy, fz, xx, xy, xz)
        ox, oy, oz, l = norm3(fx - d * xx, fy - d * xy, fz - d * xz)
    end
    if l < 0.0001 then

        if abs(xy) < 0.9 then return norm3(cross3(xx, xy, xz, 0, 1, 0)) end
        return norm3(cross3(xx, xy, xz, 1, 0, 0))
    end
    return ox, oy, oz
end

function rag.new_body(points, vx, vy, vz, unit)
    local body = { p = {}, q = {}, r = {}, rest = {}, range = {},
                   unit = unit or rag.BONE_UNIT, still = 0, ticks = 0,
                   contacts = 0, impact = 0, touch = {} }
    local s = rag.SUBSTEPS
    for i = 1, COUNT do
        local at = points[i]
        body.p[i] = v(at.x, at.y, at.z)
        body.q[i] = v(at.x - (vx or 0) / s, at.y - (vy or 0) / s, at.z - (vz or 0) / s)
        body.r[i] = rag.POINTS[i].radius * body.unit
    end

    for k, l in ipairs(LINKS) do
        body.rest[k] = len3(sub(body.p[l[1]], body.p[l[2]]))
    end
    body.twistLen = {}
    for k, t in ipairs(TWISTS) do
        body.twistLen[k] = max(len3(sub(body.p[t[1]], body.p[t[2]])), 0.5 * body.unit)
    end
    for k, r in ipairs(RANGES) do
        local chain = 0
        for c = 1, #r[3] - 1 do
            chain = chain + len3(sub(body.p[r[3][c]], body.p[r[3][c + 1]]))
        end
        body.range[k] = { chain * r[4], chain * r[5] }
    end
    return body
end

local function hold(pa, pb, lo, hi)
    local dx, dy, dz = pb.x - pa.x, pb.y - pa.y, pb.z - pa.z
    local d = len3(dx, dy, dz)
    if d < 0.0001 then return end
    local want
    if d < lo then want = lo elseif d > hi then want = hi else return end
    local k = (d - want) / d * 0.5
    pa.x, pa.y, pa.z = pa.x + dx * k, pa.y + dy * k, pa.z + dz * k
    pb.x, pb.y, pb.z = pb.x - dx * k, pb.y - dy * k, pb.z - dz * k
end

local function side_of(p, left, right)
    return norm3(sub(p[left], p[right]))
end

local function up_of(p, from, to)
    return norm3(sub(p[to], p[from]))
end

local function keep_hinge(p, h)
    local a, b, c = p[h[1]], p[h[2]], p[h[3]]
    local sx, sy, sz
    if h[4] == "torso" then
        sx, sy, sz = side_of(p, P.lsh, P.rsh)
    else
        sx, sy, sz = side_of(p, P.lhip, P.rhip)
    end
    local ux, uy, uz = sub(b, a)
    local lx, ly, lz = sub(c, b)
    local nx, ny, nz = cross3(lx, ly, lz, ux, uy, uz)
    local n = len3(nx, ny, nz)
    local ul, ll = len3(ux, uy, uz), len3(lx, ly, lz)

    if n < 0.12 * ul * ll then return false end
    if dot3(nx, ny, nz, sx, sy, sz) * h[5] >= 0 then return false end
    local ax, ay, az = norm3(sub(c, a))
    local bx, by, bz = sub(b, a)
    local along = dot3(bx, by, bz, ax, ay, az)
    b.x, b.y, b.z = a.x + ax * along, a.y + ay * along, a.z + az * along
    return true
end
rag.keep_hinge = keep_hinge

local function hinge_axis(p, chain, kind)
    local a, b, c = p[chain[1]], p[chain[2]], p[chain[3]]
    local ux, uy, uz = sub(b, a)
    local lx, ly, lz = sub(c, b)
    local nx, ny, nz
    if kind == "hinge" then
        nx, ny, nz = cross3(lx, ly, lz, ux, uy, uz)
    else
        nx, ny, nz = cross3(ux, uy, uz, lx, ly, lz)
    end
    if len3(nx, ny, nz) > 0.2 * len3(ux, uy, uz) * len3(lx, ly, lz) then
        return nx, ny, nz
    end
    if kind == "hinge" then return side_of(p, P.lsh, P.rsh) end
    return side_of(p, P.lhip, P.rhip)
end

local function keep_twist(body, k)
    local t = TWISTS[k]
    local p = body.p
    local o, side = p[t[2]], p[t[1]]
    local xx, xy, xz, l = norm3(sub(p[t[4]], p[t[3]]))
    if l < 0.0001 then return false end
    local hx, hy, hz = hinge_axis(p, t[5], t[6])
    local rx, ry, rz = orth(hx, hy, hz, xx, xy, xz)
    local dx, dy, dz = sub(side, o)
    local sx, sy, sz = orth(dx, dy, dz, xx, xy, xz, rx, ry, rz)
    local c = dot3(sx, sy, sz, rx, ry, rz)
    local cx, cy, cz = cross3(rx, ry, rz, sx, sy, sz)
    local angle = math.atan(dot3(cx, cy, cz, xx, xy, xz), c)
    local stopped = false
    if abs(angle) > t[7] then
        angle = angle > 0 and t[7] or -t[7]
        local ca, sa = math.cos(angle), math.sin(angle)
        local wx, wy, wz = cross3(xx, xy, xz, rx, ry, rz)
        sx, sy, sz = rx * ca + wx * sa, ry * ca + wy * sa, rz * ca + wz * sa
        stopped = true
    end
    local d = body.twistLen[k]
    side.x, side.y, side.z = o.x + sx * d, o.y + sy * d, o.z + sz * d
    return stopped
end
rag.keep_twist = keep_twist

local function place_twists(out, unit)
    for _, t in ipairs(TWISTS) do
        local o = out[t[2]]
        local xx, xy, xz = norm3(sub(out[t[4]], out[t[3]]))
        local hx, hy, hz = hinge_axis(out, t[5], t[6])
        local sx, sy, sz = orth(hx, hy, hz, xx, xy, xz)
        local d = rag.TWIST_REACH * unit
        out[t[1]] = v(o.x + sx * d, o.y + sy * d, o.z + sz * d)
    end
end

local NO_FLOOR = -10000
local wallProbe = v(0, 0, 0)

local function collide(body, i)
    local p, r = body.p[i], body.r[i]
    wallProbe.x, wallProbe.y, wallProbe.z = p.x, p.y, p.z
    resolve_and_return_wall_collisions(wallProbe, 0, max(r, 5))
    p.x, p.z = wallProbe.x, wallProbe.z

    local onFloor = false
    local floor = find_floor_height(p.x, p.y, p.z)
    if floor > NO_FLOOR and p.y - r < floor then
        local q = body.q[i]
        local fall = q.y - p.y
        p.y = floor + r
        onFloor = true

        body.touch[i] = true
        if fall > 0 then
            q.y = p.y - fall * rag.BOUNCE
            if fall > body.impact then body.impact = fall end
        else
            q.y = p.y
        end
    end
    local ceil = find_ceil_height(p.x, p.y, p.z)
    if ceil ~= nil and p.y + r > ceil and ceil > floor then
        p.y = ceil - r
    end
    return onFloor
end

local function sweep(body)
    local p, q = body.p[P.pelvis], body.q[P.pelvis]
    local dx, dy, dz = p.x - q.x, p.y - q.y, p.z - q.z
    local r = body.r[P.pelvis]
    if dx * dx + dz * dz < r * r then return end
    if collision_find_surface_on_ray == nil then return end
    local hit = collision_find_surface_on_ray(q.x, q.y, q.z, dx, dy, dz, 3)
    if hit == nil or hit.surface == nil or hit.hitPos == nil then return end
    local ux, uy, uz = norm3(dx, dy, dz)
    local tx = hit.hitPos.x - ux * r - p.x
    local ty = hit.hitPos.y - uy * r - p.y
    local tz = hit.hitPos.z - uz * r - p.z
    for i = 1, COUNT do
        local b = body.p[i]
        b.x, b.y, b.z = b.x + tx, b.y + ty, b.z + tz

        local c = body.q[i]
        c.x, c.y, c.z = b.x, b.y, b.z
    end
end

local LIMB_END = {}
for _, name in ipairs({ "crown", "lel", "lwr", "rel", "rwr", "lkn", "lan", "ltoe",
    "rkn", "ran", "rtoe", "lthumb", "rthumb", "lsole", "rsole" }) do
    LIMB_END[P[name]] = true
end
rag.LIMB_END = LIMB_END

function rag.step(body)
    body.ticks = body.ticks + 1
    body.impact = 0
    body.touch = body.touch or {}
    local g = rag.GRAVITY / (rag.SUBSTEPS * rag.SUBSTEPS)
    local cap = rag.TERMINAL / rag.SUBSTEPS
    local contacts = 0
    local mean = 0
    for _ = 1, rag.SUBSTEPS do

        local airborne = (body.contacts or 0) == 0
        local lostX, lostY, lostZ = 0, 0, 0
        local vel = body.vel or {}
        body.vel = vel
        for i = 1, COUNT do
            local p, q = body.p[i], body.q[i]
            local drag = (airborne and LIMB_END[i]) and rag.LIMB_DRAG or rag.AIR_DRAG
            local vx, vy, vz = p.x - q.x, p.y - q.y, p.z - q.z
            if airborne then
                lostX = lostX + vx * (1 - drag)
                lostY = lostY + vy * (1 - drag)
                lostZ = lostZ + vz * (1 - drag)
            end
            local w = vel[i] or {}
            w[1], w[2], w[3] = vx * drag, vy * drag, vz * drag
            vel[i] = w
        end
        lostX, lostY, lostZ = lostX / COUNT, lostY / COUNT, lostZ / COUNT
        for i = 1, COUNT do
            local p, q, w = body.p[i], body.q[i], vel[i]
            local vx, vy, vz = w[1] + lostX, w[2] + lostY - g, w[3] + lostZ
            if vy < -cap then vy = -cap end
            q.x, q.y, q.z = p.x, p.y, p.z
            p.x, p.y, p.z = p.x + vx, p.y + vy, p.z + vz
            body.touch[i] = false
        end
        sweep(body)
        contacts = 0
        for it = 1, rag.ITERATIONS do
            for k, l in ipairs(LINKS) do
                local d = body.rest[k]
                hold(body.p[l[1]], body.p[l[2]], d, d)
            end
            for k, r in ipairs(RANGES) do
                hold(body.p[r[1]], body.p[r[2]], body.range[k][1], body.range[k][2])
            end
            for _, h in ipairs(HINGES) do keep_hinge(body.p, h) end
            for k = 1, #TWISTS do keep_twist(body, k) end

            local pin = body.pin
            if pin ~= nil then
                local pt = body.p[pin.i]
                pt.x, pt.y, pt.z = pin.x, pin.y, pin.z
            end
            if it % 2 == 0 then
                contacts = 0
                for i = 1, COUNT do
                    if collide(body, i) then contacts = contacts + 1 end
                end
            end
        end
        body.contacts = contacts

        local keep = 1 - rag.FRICTION
        mean = 0
        for i = 1, COUNT do
            local p, q = body.p[i], body.q[i]
            if body.touch[i] then
                local sx, sz = p.x - q.x, p.z - q.z
                if sx * sx + sz * sz < rag.STICK * rag.STICK then

                    q.x, q.z = p.x, p.z
                else
                    q.x, q.z = p.x - sx * keep, p.z - sz * keep
                end
            end
            mean = mean + len3(sub(p, q))
        end
        mean = mean / COUNT

        if contacts >= rag.SETTLE_CONTACTS and mean < rag.SETTLE_SPEED
            and body.pin == nil then
            local k = rag.SETTLE_DAMP
            for i = 1, COUNT do
                local p, q = body.p[i], body.q[i]
                q.x = p.x - (p.x - q.x) * k
                q.y = p.y - (p.y - q.y) * k
                q.z = p.z - (p.z - q.z) * k
            end
            mean = mean * k
        end
    end

    local fastest = 0
    for i = 1, COUNT do
        local s = len3(sub(body.p[i], body.q[i]))
        if s > fastest then fastest = s end
    end
    body.fastest = fastest
    body.mean = mean
    if mean < rag.REST_SPEED and contacts > 0 then
        body.still = body.still + 1
    else
        body.still = 0
    end
    return body
end

function rag.velocity_of(body, i)
    local p, q = body.p[i or P.pelvis], body.q[i or P.pelvis]
    local s = rag.SUBSTEPS
    return (p.x - q.x) * s, (p.y - q.y) * s, (p.z - q.z) * s
end

function rag.set_velocity(body, i, vx, vy, vz)
    local p, q = body.p[i], body.q[i]
    local s = rag.SUBSTEPS
    q.x, q.y, q.z = p.x - vx / s, p.y - vy / s, p.z - vz / s
end

function rag.push(body, i, vx, vy, vz)
    local q = body.q[i]
    local s = rag.SUBSTEPS
    q.x, q.y, q.z = q.x - vx / s, q.y - vy / s, q.z - vz / s
end

rag.RIDE_GAP = 40
function rag.carry(body)
    if body == nil or find_floor == nil then return false end
    local pel = body.p[P.pelvis]
    local h, floor = find_floor(pel.x, pel.y + 50, pel.z)
    local obj = nil
    if floor ~= nil and h ~= nil and h > NO_FLOOR
        and pel.y - body.r[P.pelvis] - h < rag.RIDE_GAP then
        obj = floor.object
    end
    if obj == nil then body.ride = nil return false end
    local x, y, z = obj.oPosX or 0, obj.oPosY or 0, obj.oPosZ or 0
    local yaw = obj.oFaceAngleYaw or 0
    local ride = body.ride
    local moved = false
    if ride ~= nil and ride.obj == obj then
        local dx, dy, dz = x - ride.x, y - ride.y, z - ride.z
        local turn = (yaw - ride.yaw) % 0x10000
        if turn >= 0x8000 then turn = turn - 0x10000 end
        if dx ~= 0 or dy ~= 0 or dz ~= 0 or turn ~= 0 then
            local a = turn * math.pi / 0x8000
            local c, sn = math.cos(a), math.sin(a)
            for _, list in ipairs({ body.p, body.q }) do
                for i = 1, COUNT do
                    local pt = list[i]

                    local ox, oz = pt.x + dx - x, pt.z + dz - z
                    pt.x = x + ox * c + oz * sn
                    pt.z = z - ox * sn + oz * c
                    pt.y = pt.y + dy
                end
            end
            moved = true
        end
    end
    body.ride = { obj = obj, x = x, y = y, z = z, yaw = yaw }
    return moved
end

function rag.at_rest(body)
    return body ~= nil and body.still >= rag.REST_TICKS
end

local LIMB = {

    [2]  = { "pelvis", "waist", "pelvis" },
    [3]  = { "waist",  "neck",  "torso" },
    [4]  = { "neck",   "crown", "torso" },
    [6]  = { "lsh",    "lel",   "hinge", { "lsh", "lel", "lwr" } },
    [7]  = { "lel",    "lwr",   "hinge", { "lsh", "lel", "lwr" } },
    [10] = { "rsh",    "rel",   "hinge", { "rsh", "rel", "rwr" } },
    [11] = { "rel",    "rwr",   "hinge", { "rsh", "rel", "rwr" } },
    [14] = { "lhip",   "lkn",   "leg",   { "lhip", "lkn", "lan" } },
    [15] = { "lkn",    "lan",   "leg",   { "lhip", "lkn", "lan" } },
    [16] = { "lan",    "ltoe",  "leg",   { "lhip", "lkn", "lan" } },
    [18] = { "rhip",   "rkn",   "leg",   { "rhip", "rkn", "ran" } },
    [19] = { "rkn",    "ran",   "leg",   { "rhip", "rkn", "ran" } },
    [20] = { "ran",    "rtoe",  "leg",   { "rhip", "rkn", "ran" } },
}

local SAME_AS = { [1] = 2, [5] = 6, [9] = 10, [13] = 14, [17] = 18 }
local HAND = { [8] = { 7, "lwr" }, [12] = { 11, "rwr" } }

local TWIST_OF = { [8] = "lthumb", [12] = "rthumb", [16] = "lsole", [20] = "rsole" }

rag.PARTS = 20

function rag.frames(p, keep)
    keep = keep or {}
    local out = {}
    local tzx, tzy, tzz = side_of(p, P.lsh, P.rsh)
    local pzx, pzy, pzz = side_of(p, P.lhip, P.rhip)
    for part = 1, rag.PARTS do
        local limb = LIMB[part]
        if limb ~= nil then
            local o, to = p[P[limb[1]]], p[P[limb[2]]]
            local xx, xy, xz, l = norm3(sub(to, o))
            if l < 0.0001 then xx, xy, xz = 0, 1, 0 end
            local zx, zy, zz
            if limb[3] == "torso" then
                zx, zy, zz = orth(tzx, tzy, tzz, xx, xy, xz)
            elseif limb[3] == "pelvis" then
                zx, zy, zz = orth(pzx, pzy, pzz, xx, xy, xz)
            else
                local chain = limb[4]
                local a, b, c = p[P[chain[1]]], p[P[chain[2]]], p[P[chain[3]]]
                local ux, uy, uz = sub(b, a)
                local lx, ly, lz = sub(c, b)
                local nx, ny, nz
                if limb[3] == "hinge" then
                    nx, ny, nz = cross3(lx, ly, lz, ux, uy, uz)
                else
                    nx, ny, nz = cross3(ux, uy, uz, lx, ly, lz)
                end
                local n = len3(nx, ny, nz)
                local fallbackX, fallbackY, fallbackZ
                if limb[3] == "hinge" then
                    local kept = keep[chain[1]]
                    if kept ~= nil then
                        fallbackX, fallbackY, fallbackZ = kept[1], kept[2], kept[3]
                    else
                        fallbackX, fallbackY, fallbackZ = tzx, tzy, tzz
                    end
                else
                    fallbackX, fallbackY, fallbackZ = pzx, pzy, pzz
                end
                if n > 0.2 * len3(ux, uy, uz) * len3(lx, ly, lz) then
                    zx, zy, zz = orth(nx, ny, nz, xx, xy, xz,
                        fallbackX, fallbackY, fallbackZ)
                    if limb[3] == "hinge" then keep[chain[1]] = { zx, zy, zz } end
                else
                    zx, zy, zz = orth(fallbackX, fallbackY, fallbackZ, xx, xy, xz)
                end
            end
            local yx, yy, yz = cross3(zx, zy, zz, xx, xy, xz)
            out[part] = { o.x, o.y, o.z, xx, xy, xz, yx, yy, yz, zx, zy, zz }
        end
    end
    for part, from in pairs(SAME_AS) do
        local f = out[from]
        out[part] = { f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9],
                      f[10], f[11], f[12] }
    end
    for part, hand in pairs(HAND) do
        local f, w = out[hand[1]], p[P[hand[2]]]
        out[part] = { w.x, w.y, w.z, f[4], f[5], f[6], f[7], f[8], f[9],
                      f[10], f[11], f[12] }
    end

    for part, side in pairs(TWIST_OF) do
        local f = out[part]
        local s = p[P[side]]
        if f ~= nil and s ~= nil then
            local zx, zy, zz = orth(s.x - f[1], s.y - f[2], s.z - f[3],
                f[4], f[5], f[6], f[10], f[11], f[12])
            local yx, yy, yz = cross3(zx, zy, zz, f[4], f[5], f[6])
            f[7], f[8], f[9], f[10], f[11], f[12] = yx, yy, yz, zx, zy, zz
        end
    end
    return out
end

function rag.compose(f, s, tx, ty, tz, V, dest)
    local x0, x1, x2 = s * f[4], s * f[5], s * f[6]
    local y0, y1, y2 = s * f[7], s * f[8], s * f[9]
    local z0, z1, z2 = s * f[10], s * f[11], s * f[12]
    local o0 = f[1] - (tx * x0 + ty * y0 + tz * z0)
    local o1 = f[2] - (tx * x1 + ty * y1 + tz * z1)
    local o2 = f[3] - (tx * x2 + ty * y2 + tz * z2)
    local a0, a1, a2 = V[1], V[2], V[3]
    local b0, b1, b2 = V[4], V[5], V[6]
    local c0, c1, c2 = V[7], V[8], V[9]
    dest.m00 = x0 * a0 + x1 * b0 + x2 * c0
    dest.m01 = x0 * a1 + x1 * b1 + x2 * c1
    dest.m02 = x0 * a2 + x1 * b2 + x2 * c2
    dest.m10 = y0 * a0 + y1 * b0 + y2 * c0
    dest.m11 = y0 * a1 + y1 * b1 + y2 * c1
    dest.m12 = y0 * a2 + y1 * b2 + y2 * c2
    dest.m20 = z0 * a0 + z1 * b0 + z2 * c0
    dest.m21 = z0 * a1 + z1 * b1 + z2 * c1
    dest.m22 = z0 * a2 + z1 * b2 + z2 * c2
    dest.m30 = o0 * a0 + o1 * b0 + o2 * c0 + V[10]
    dest.m31 = o0 * a1 + o1 * b1 + o2 * c1 + V[11]
    dest.m32 = o0 * a2 + o1 * b2 + o2 * c2 + V[12]
    return dest
end

function rag.compose_local(f, s, Li, V, dest)
    local x0, x1, x2 = s * f[4], s * f[5], s * f[6]
    local y0, y1, y2 = s * f[7], s * f[8], s * f[9]
    local z0, z1, z2 = s * f[10], s * f[11], s * f[12]

    local m00 = Li[1] * x0 + Li[2] * y0 + Li[3] * z0
    local m01 = Li[1] * x1 + Li[2] * y1 + Li[3] * z1
    local m02 = Li[1] * x2 + Li[2] * y2 + Li[3] * z2
    local m10 = Li[4] * x0 + Li[5] * y0 + Li[6] * z0
    local m11 = Li[4] * x1 + Li[5] * y1 + Li[6] * z1
    local m12 = Li[4] * x2 + Li[5] * y2 + Li[6] * z2
    local m20 = Li[7] * x0 + Li[8] * y0 + Li[9] * z0
    local m21 = Li[7] * x1 + Li[8] * y1 + Li[9] * z1
    local m22 = Li[7] * x2 + Li[8] * y2 + Li[9] * z2
    local o0 = Li[10] * x0 + Li[11] * y0 + Li[12] * z0 + f[1]
    local o1 = Li[10] * x1 + Li[11] * y1 + Li[12] * z1 + f[2]
    local o2 = Li[10] * x2 + Li[11] * y2 + Li[12] * z2 + f[3]
    local a0, a1, a2 = V[1], V[2], V[3]
    local b0, b1, b2 = V[4], V[5], V[6]
    local c0, c1, c2 = V[7], V[8], V[9]
    dest.m00 = m00 * a0 + m01 * b0 + m02 * c0
    dest.m01 = m00 * a1 + m01 * b1 + m02 * c1
    dest.m02 = m00 * a2 + m01 * b2 + m02 * c2
    dest.m10 = m10 * a0 + m11 * b0 + m12 * c0
    dest.m11 = m10 * a1 + m11 * b1 + m12 * c1
    dest.m12 = m10 * a2 + m11 * b2 + m12 * c2
    dest.m20 = m20 * a0 + m21 * b0 + m22 * c0
    dest.m21 = m20 * a1 + m21 * b1 + m22 * c1
    dest.m22 = m20 * a2 + m21 * b2 + m22 * c2
    dest.m30 = o0 * a0 + o1 * b0 + o2 * c0 + V[10]
    dest.m31 = o0 * a1 + o1 * b1 + o2 * c1 + V[11]
    dest.m32 = o0 * a2 + o1 * b2 + o2 * c2 + V[12]
    return dest
end

local function inverse12(a)
    local d = a[1] * (a[5] * a[9] - a[6] * a[8]) - a[2] * (a[4] * a[9] - a[6] * a[7])
        + a[3] * (a[4] * a[8] - a[5] * a[7])
    if abs(d) < 1e-9 then return nil end
    local k = 1 / d
    local r = {
        (a[5] * a[9] - a[6] * a[8]) * k, (a[3] * a[8] - a[2] * a[9]) * k, (a[2] * a[6] - a[3] * a[5]) * k,
        (a[6] * a[7] - a[4] * a[9]) * k, (a[1] * a[9] - a[3] * a[7]) * k, (a[3] * a[4] - a[1] * a[6]) * k,
        (a[4] * a[8] - a[5] * a[7]) * k, (a[2] * a[7] - a[1] * a[8]) * k, (a[1] * a[5] - a[2] * a[4]) * k,
    }
    local t0, t1, t2 = a[10], a[11], a[12]
    r[10] = -(t0 * r[1] + t1 * r[4] + t2 * r[7])
    r[11] = -(t0 * r[2] + t1 * r[5] + t2 * r[8])
    r[12] = -(t0 * r[3] + t1 * r[6] + t2 * r[9])
    return r, d
end
rag.inverse12 = inverse12

local function mul12(a, b)
    return {
        a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
        a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
        a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
        a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
        a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
        a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
        a[10] * b[1] + a[11] * b[4] + a[12] * b[7] + b[10],
        a[10] * b[2] + a[11] * b[5] + a[12] * b[8] + b[11],
        a[10] * b[3] + a[11] * b[6] + a[12] * b[9] + b[12],
    }
end

local function yaw_axes(yaw)
    local s, c = math.sin(yaw * math.pi / 0x8000), math.cos(yaw * math.pi / 0x8000)

    return s, c, c, -s
end

function rag.standing_points(m, unit, lying)
    local fx, fz, lx, lz = yaw_axes(m.faceAngle.y or 0)
    local out = {}
    for i, point in ipairs(rag.POINTS) do
        local at = rag.STANDING[point.name]
        local side, up, fwd = at[1] * unit, at[2] * unit, at[3] * unit
        if lying then

            up, fwd = fwd + 45 * unit, -up
        end
        out[i] = v(m.pos.x + lx * side + fx * fwd,
                   m.pos.y + up,
                   m.pos.z + lz * side + fz * fwd)
    end
    return out
end

function rag.unit_of(m)
    local scale = 1
    local gfx = m.marioObj ~= nil and m.marioObj.header.gfx or nil
    if gfx ~= nil and gfx.scale ~= nil then
        scale = (abs(gfx.scale.x or 1) + abs(gfx.scale.y or 1) + abs(gfx.scale.z or 1)) / 3
    end
    if scale < 0.05 then scale = 0.05 end
    return rag.BONE_UNIT * scale
end

function rag.live_points(m, unit)
    local body = m.marioBodyState
    local timer = get_global_timer ~= nil and get_global_timer() or 0
    if body == nil or body.updateTorsoTime == nil
        or timer - body.updateTorsoTime > 2 then
        return nil
    end
    local out = {}
    local probe = v(0, 0, 0)
    for i, point in ipairs(rag.POINTS) do
        if point.part ~= nil then
            if not get_mario_anim_part_pos(m, point.part, probe) then return nil end
            local dx, dy, dz = probe.x - m.pos.x, probe.y - m.pos.y, probe.z - m.pos.z
            if len3(dx, dy, dz) > 600 * unit * 4 then return nil end
            out[i] = v(probe.x, probe.y, probe.z)
        end
    end

    local ux, uy, uz = up_of(out, P.waist, P.neck)
    local n = out[P.neck]
    out[P.crown] = v(n.x + ux * CROWN_ALONG * unit, n.y + uy * CROWN_ALONG * unit,
                     n.z + uz * CROWN_ALONG * unit)
    local sx, sy, sz = side_of(out, P.lhip, P.rhip)
    local px, py, pz = up_of(out, P.pelvis, P.waist)
    local fx, fy, fz = cross3(sx, sy, sz, px, py, pz)
    for _, foot in ipairs({ { P.lan, P.ltoe }, { P.ran, P.rtoe } }) do
        local a = out[foot[1]]
        out[foot[2]] = v(a.x + (fx * TOE_FORWARD - px * TOE_DOWN) * unit,
                         a.y + (fy * TOE_FORWARD - py * TOE_DOWN) * unit,
                         a.z + (fz * TOE_FORWARD - pz * TOE_DOWN) * unit)
    end
    place_twists(out, unit)
    return out
end

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local DIGIT = {}
for i = 1, #ALPHABET do DIGIT[string.sub(ALPHABET, i, i)] = i - 1 end
local HALF = 2048

function rag.encode(points)
    local pelvis = points[P.pelvis]
    local parts = {}
    for i = 1, COUNT do
        if i ~= P.pelvis then
            for _, axis in ipairs({ "x", "y", "z" }) do
                local q = math.floor((points[i][axis] - pelvis[axis]) * 2 + 0.5) + HALF
                if q < 0 then q = 0 elseif q > 4095 then q = 4095 end
                local hi, lo = math.floor(q / 64), q % 64
                parts[#parts + 1] = string.sub(ALPHABET, hi + 1, hi + 1)
                    .. string.sub(ALPHABET, lo + 1, lo + 1)
            end
        end
    end
    return table.concat(parts)
end

function rag.decode(text, px, py, pz)
    if type(text) ~= "string" or #text ~= (COUNT - 1) * 6 then return nil end
    local out = {}
    out[P.pelvis] = v(px, py, pz)
    local at = 1
    for i = 1, COUNT do
        if i ~= P.pelvis then
            local c = {}
            for axis = 1, 3 do
                local hi = DIGIT[string.sub(text, at, at)]
                local lo = DIGIT[string.sub(text, at + 1, at + 1)]
                if hi == nil or lo == nil then return nil end
                c[axis] = ((hi * 64 + lo) - HALF) / 2
                at = at + 2
            end
            out[i] = v(px + c[1], py + c[2], pz + c[3])
        end
    end
    return out
end

rag.body = nil
rag.downAt = 0

rag.drawn = {}

rag.heard = {}

rag.marked = {}
rag.skeletons = {}

rag.sent = 0
rag.posed = 0
rag.seq = 0

rag.carrying = nil
rag.rejected = 0

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local RAGDOLL = at_load("allocate_mario_action", ACT_GROUP_AUTOMATIC)
rag.ACTION = RAGDOLL

do
    local index = {}
    for _ = 1, 3 + rag.PARTS * 3 do
        index[#index + 1] = 1
        index[#index + 1] = 0
    end
    at_load("smlua_anim_util_register_animation", rag.ANIM, 0, 0, 0, 0, 1,
        { 0 }, index)
end

function rag.switched_on()
    if OF.moves == nil or OF.moves.stop == nil then return false end
    local stop = OF.moves.stop(rag.ROW)
    return stop ~= nil and stop.on == true
end

local function has(value, flag)
    return flag ~= nil and flag ~= 0 and ((value or 0) & flag) ~= 0
end

local REFUSE_FLAGS = { "ACT_FLAG_SWIMMING", "ACT_FLAG_ON_POLE", "ACT_FLAG_HANGING",
    "ACT_FLAG_INTANGIBLE", "ACT_FLAG_RIDING_SHELL", "ACT_FLAG_METAL_WATER",
    "ACT_FLAG_WATER_OR_TEXT" }

rag.KNOCK_NAMES = { "ACT_BACKWARD_AIR_KB", "ACT_FORWARD_AIR_KB",
    "ACT_HARD_BACKWARD_AIR_KB", "ACT_HARD_FORWARD_AIR_KB",
    "ACT_HARD_BACKWARD_GROUND_KB", "ACT_HARD_FORWARD_GROUND_KB",
    "ACT_THROWN_BACKWARD", "ACT_THROWN_FORWARD" }
local KNOCK, THROWN = {}, {}
for _, name in ipairs(rag.KNOCK_NAMES) do
    if _G[name] ~= nil then KNOCK[_G[name]] = true end
end
if ACT_THROWN_BACKWARD ~= nil then THROWN[ACT_THROWN_BACKWARD] = true end
if ACT_THROWN_FORWARD ~= nil then THROWN[ACT_THROWN_FORWARD] = true end
rag.KNOCK = KNOCK

function rag.knock_allowed()
    if OF.moves ~= nil and OF.util.asks(OF.moves, "round_holds")
        and OF.moves.round_holds() then
        local mode = OF.util.asks(OF.gamemodes, "current") and OF.gamemodes.current() or nil
        if mode == nil or type(mode.ragdollOnKnock) ~= "function" then return false end
        local ok, yes = pcall(mode.ragdollOnKnock)
        return ok and yes == true
    end
    return rag.switched_on()
end

function rag.still_allowed(body)
    if body ~= nil and body.forced then return rag.knock_allowed() end
    return rag.switched_on()
end

function rag.on_set_action(m)
    if m == nil or m.playerIndex ~= 0 or RAGDOLL == nil then return end
    if not KNOCK[m.action] then return end
    local hurt = tonumber(m.hurtCounter) or 0
    local hit = THROWN[m.action] or hurt > 0 or (tonumber(m.knockbackTimer) or 0) > 0
    if not hit then return end
    if (m.health or 0x880) - 0x40 * hurt < 0x100 then
        rag.pending = nil
        return
    end
    rag.pending = { action = m.action }
end

function rag.may_start(m, forced)
    if RAGDOLL == nil then return false, "this build cannot make the action" end
    if m == nil or m.playerIndex ~= 0 then return false, "not this machine's" end
    if forced then
        if not rag.knock_allowed() then return false, "knockback does not throw you limp here" end
    elseif not rag.switched_on() then
        return false, "the ragdoll is off"
    end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(0) then
        return false, "watching"
    end
    if m.action == RAGDOLL then return false, "already down" end
    if (m.health or 0x880) < 0x100 then return false, "out of health" end
    local group = (m.action or 0) & (ACT_GROUP_MASK or 0x1C0)

    if group == (ACT_GROUP_CUTSCENE or 0x1C0) or group == (ACT_GROUP_SUBMERGED or 0x0C0)
        or group == (ACT_GROUP_AUTOMATIC or 0x140) then
        return false, "the game has him"
    end
    for _, name in ipairs(REFUSE_FLAGS) do
        if has(m.action, _G[name]) then return false, "the game has him" end
    end
    return true
end

local function body_yaw(p)
    local sx, sy, sz = side_of(p, P.lsh, P.rsh)
    local ux, uy, uz = up_of(p, P.waist, P.neck)
    local fx, _, fz = cross3(sx, sy, sz, ux, uy, uz)
    if abs(fx) + abs(fz) < 0.01 then

        fx, fz = ux, uz
    end
    return math.floor(math.atan(fx, fz) * 0x8000 / math.pi + 0.5)
end

local function sound(m, name)
    local id = _G[name]
    if id == nil or play_character_sound == nil then return end
    pcall(play_character_sound, m, id)
end

function rag.launch(body, m, forced)
    local vx, vy, vz = m.vel.x or 0, m.vel.y or 0, m.vel.z or 0
    local fx, fz = yaw_axes(m.faceAngle.y or 0)
    local ground = not has(m.action, ACT_FLAG_AIR or 0x800)
    local speed = sqrt(vx * vx + vz * vz)
    local hop = 0
    if not forced and ground and speed >= rag.HOP_FROM then
        hop = min(rag.HOP_BASE + rag.HOP_PER_SPEED * speed, rag.HOP_MAX)
    end
    for i = 1, COUNT do
        local top = (i == P.waist or i == P.neck or i == P.crown or i == P.lsh
            or i == P.rsh or i == P.lel or i == P.rel or i == P.lwr or i == P.rwr
            or i == P.lthumb or i == P.rthumb)
        if forced then
            local k = top and rag.KNOCK_TUMBLE or 0
            rag.push(body, i, vx * k, abs(vy) * k * 0.5 + max(0, rag.KNOCK_LIFT - vy), vz * k)
        else
            local k = top and 1 or 0.15
            rag.push(body, i, fx * rag.THROW_FORWARD * k,
                rag.THROW_UP * (top and 1 or 0.4) + hop,
                fz * rag.THROW_FORWARD * k)
        end
    end

    local dx, dz = vx, vz
    if speed < 1 then
        dx, dz = fx, fz
        if forced then dx, dz = -fx, -fz end
    end
    rag.spin(body, dx, dz, rag.spin_rate(speed + abs(vy) * 0.5))
    rag.flail(body)
    body.launched = { speed = speed, hop = hop }
    return body
end

function rag.spin_rate(speed)
    return min(rag.SPIN_BASE + rag.SPIN_PER_SPEED * (speed or 0), rag.SPIN_MAX)
end

function rag.spin(body, dx, dz, rate)
    local hx, _, hz, l = norm3(dx, 0, dz)
    if l < 0.0001 then return false end
    local cx, cy, cz = 0, 0, 0
    for i = 1, COUNT do
        local p = body.p[i]
        cx, cy, cz = cx + p.x, cy + p.y, cz + p.z
    end
    cx, cy, cz = cx / COUNT, cy / COUNT, cz / COUNT

    local ax, ay, az = hz * rate, 0, -hx * rate
    ay = (math.random() * 2 - 1) * rag.SPIN_YAW
    for i = 1, COUNT do
        local p = body.p[i]
        local rx, ry, rz = p.x - cx, p.y - cy, p.z - cz
        local wx, wy, wz = cross3(ax, ay, az, rx, ry, rz)
        rag.push(body, i, wx, wy, wz)
    end
    body.spin = rate
    return true
end

function rag.flail(body)
    local f = rag.FLAIL
    for _, name in ipairs({ "lwr", "rwr", "lan", "ran" }) do
        local i = P[name]
        local k = (name == "lwr" or name == "rwr") and 1 or 0.5
        local x = (math.random() * 2 - 1) * f * k
        local y = (math.random() * 0.7 + 0.3) * f * k
        local z = (math.random() * 2 - 1) * f * k
        rag.push(body, i, x, y, z)
    end
end

function rag.start(m, forced)
    local ok, why = rag.may_start(m, forced)
    if not ok then return false, why end
    if m.heldObj ~= nil and mario_drop_held_object ~= nil then
        mario_drop_held_object(m)
    end

    if rag.carrying ~= nil then rag.let_go(m, false) end
    local unit = rag.unit_of(m)
    local points = rag.live_points(m, unit) or rag.standing_points(m, unit, false)
    local body = rag.new_body(points, m.vel.x, m.vel.y, m.vel.z, unit)
    rag.launch(body, m, forced)
    body.forced = forced == true
    rag.body = body
    rag.downAt = 0
    rag.keep = {}
    set_mario_action(m, RAGDOLL, 0)
    if m.action ~= RAGDOLL then
        rag.body = nil
        return false, "the game said no"
    end
    sound(m, "CHAR_SOUND_WAH2")
    return true
end

function rag.finish()
    rag.body = nil
    rag.downAt = 0
    rag.drawn[0] = nil
end

function rag.get_up(m)
    local body = rag.body
    if body == nil or m == nil then rag.finish() return false end
    local p = body.p[P.pelvis]
    local floor = find_floor_height(p.x, p.y + 60, p.z)
    local ground = floor > NO_FLOOR and p.y - floor < 60
    m.pos.x, m.pos.z = p.x, p.z
    m.pos.y = ground and floor or p.y
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.faceAngle.x, m.faceAngle.z = 0, 0
    m.faceAngle.y = body_yaw(body.p)
    m.peakHeight = m.pos.y
    rag.finish()
    if ground then
        set_mario_action(m, ACT_WAKING_UP or ACT_IDLE, 1)
    else
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    return true
end

local function set_pose_look(m)
    local bs = m.marioBodyState
    if bs ~= nil then
        bs.handState = MARIO_HAND_OPEN or 1
        bs.eyeState = MARIO_EYES_HALF_CLOSED or 2
    end
end

local function act_ragdoll(m)
    if m.playerIndex ~= 0 then

        set_pose_look(m)
        m.marioObj.header.gfx.pos.x = m.pos.x
        m.marioObj.header.gfx.pos.y = m.pos.y
        m.marioObj.header.gfx.pos.z = m.pos.z
        return
    end
    local body = rag.body
    if body == nil then

        set_mario_action(m, ACT_FREEFALL, 0)
        return
    end
    rag.downAt = rag.downAt + 1

    if not rag.still_allowed(body)
        or (OF.util.asks(OF.spectate, "is_spectating")
            and OF.spectate.is_spectating(0)) then
        rag.get_up(m)
        return
    end

    if (tonumber(m.invincTimer) or 0) < rag.INVULNERABLE then
        m.invincTimer = rag.INVULNERABLE
    end
    if (m.health or 0x880) < 0x100 then
        rag.finish()
        set_mario_action(m, ACT_DEATH_ON_BACK or ACT_FREEFALL, 0)
        return
    end

    local was = {}
    for i = 1, COUNT do
        local p = body.p[i]
        was[i] = v(p.x, p.y, p.z)
    end
    rag.hold_tick(m, body)
    rag.carry(body)
    if not rag.at_rest(body) then
        rag.step(body)
    else

        body.still = body.still + 1
        body.impact = 0
    end

    local pelvis = body.p[P.pelvis]
    local floor = find_floor_height(pelvis.x, pelvis.y, pelvis.z)
    if floor <= NO_FLOOR and pelvis.y < -9000 then

        rag.finish()
        set_mario_action(m, ACT_FREEFALL, 0)
        return
    end

    m.pos.x, m.pos.z = pelvis.x, pelvis.z
    m.pos.y = max(pelvis.y - body.r[P.pelvis], floor > NO_FLOOR and floor or pelvis.y)
    m.vel.x, m.vel.y, m.vel.z = rag.velocity_of(body, P.pelvis)
    m.forwardVel = 0

    m.peakHeight = m.pos.y
    local gfx = m.marioObj.header.gfx
    gfx.pos.x, gfx.pos.y, gfx.pos.z = m.pos.x, m.pos.y, m.pos.z
    gfx.angle.x, gfx.angle.y, gfx.angle.z = 0, m.faceAngle.y, 0
    set_pose_look(m)

    if body.impact > 12 and play_sound ~= nil and SOUND_ACTION_TERRAIN_BODY_HIT_GROUND ~= nil then
        pcall(play_sound, SOUND_ACTION_TERRAIN_BODY_HIT_GROUND, gfx.cameraToObject)
    end

    local prev = rag.drawn[0]
    rag.keep = rag.keep or {}
    local cur = rag.frames(body.p, rag.keep)
    rag.drawn[0] = { cur = cur, prev = prev ~= nil and prev.cur or rag.frames(was, {}) }

    if rag.downAt % rag.SEND_EVERY == 0 then rag.send(m) end

    if rag.downAt >= rag.MAX_TICKS
        or (rag.at_rest(body) and body.still >= rag.REST_GETUP) then
        rag.get_up(m)
    end
end
rag.act = act_ragdoll

function rag.read_button(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local pad = m.controller
    if pad == nil or not has(pad.buttonPressed, rag.BUTTON) then return false end
    if OF.util.asks(OF.input, "blocked") and OF.input.blocked() then
        return false
    end
    if m.action == RAGDOLL then
        if rag.downAt >= rag.GETUP_AFTER then return rag.get_up(m) end
        return false
    end
    return (rag.start(m))
end

local function global_of(li)
    if network_global_index_from_local == nil then return li end
    return network_global_index_from_local(li)
end

local function connected(li)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[li] or nil
    return np ~= nil and np.connected ~= false
end

local function apart(a, b)
    return len3(a.x - b.x, a.y - b.y, a.z - b.z)
end

function rag.grab_target(m)
    if RAGDOLL == nil or m == nil or m.pos == nil then return nil end
    local best, bestD = nil, rag.GRAB_REACH
    for li = 1, (MAX_PLAYERS or 16) - 1 do
        local other = gMarioStates[li]
        if other ~= nil and other.action == RAGDOLL and connected(li) then
            local d = apart(m.pos, other.pos)
            if d < bestD then best, bestD = li, d end
        end
    end
    return best
end

function rag.grab(m, li)
    if li == nil then return false end
    local ok = OF.util.send_to_player(li, { ofp = rag.GRAB_PACKET, g = global_of(li), grab = 1 })
    if ok == false then return false end
    rag.carrying = li
    return true
end

function rag.let_go(m, throw)
    local li = rag.carrying
    rag.carrying = nil
    if li == nil then return false end
    local vx, vy, vz = m.vel.x or 0, m.vel.y or 0, m.vel.z or 0
    if throw then
        local fx, fz = yaw_axes(m.faceAngle.y or 0)
        vx, vz = vx + fx * rag.THROW_SPEED, vz + fz * rag.THROW_SPEED
        vy = max(vy, 0) + rag.THROW_LIFT
    end
    OF.util.send_to_player(li, { ofp = rag.GRAB_PACKET, g = global_of(li), grab = 0,
        vx = math.floor(vx + 0.5), vy = math.floor(vy + 0.5), vz = math.floor(vz + 0.5) })
    return true
end

local function take_b(pad)
    local b = B_BUTTON or 0x4000
    if has(pad.buttonPressed, b) then pad.buttonPressed = pad.buttonPressed - b end
    if has(pad.buttonDown, b) then pad.buttonDown = pad.buttonDown - b end
end

function rag.before_update(m)
    if m == nil or m.playerIndex ~= 0 or RAGDOLL == nil then return end
    local pad = m.controller
    if pad == nil or not has(pad.buttonPressed, B_BUTTON or 0x4000) then return end
    if m.action == RAGDOLL then return end
    if rag.carrying ~= nil then
        take_b(pad)
        rag.let_go(m, true)
        return
    end
    if not rag.switched_on() then return end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(0) then
        return
    end

    if m.heldObj ~= nil then return end
    local li = rag.grab_target(m)
    if li == nil then return end
    take_b(pad)
    rag.grab(m, li)
end

function rag.carrier_tick(m)
    local li = rag.carrying
    if li == nil then return end
    local other = gMarioStates[li]
    if other == nil or other.action ~= RAGDOLL or not connected(li)
        or apart(m.pos, other.pos) > rag.GRAB_REACH * rag.GRAB_LOSE then
        rag.carrying = nil
    end
end

function rag.hand_of(grabber)
    local bs = grabber.marioBodyState
    local timer = get_global_timer ~= nil and get_global_timer() or 0
    if bs ~= nil and bs.updateTorsoTime ~= nil and timer - bs.updateTorsoTime <= 2 then
        local probe = v(0, 0, 0)
        if get_mario_anim_part_pos(grabber, MARIO_ANIM_PART_RIGHT_HAND or 12, probe) then
            return probe.x, probe.y, probe.z
        end
    end
    local unit = rag.unit_of(grabber)
    local fx, fz = yaw_axes(grabber.faceAngle.y or 0)
    return grabber.pos.x + fx * rag.HAND_FORWARD * unit,
           grabber.pos.y + rag.HAND_UP * unit,
           grabber.pos.z + fz * rag.HAND_FORWARD * unit
end

rag.CARRY_CLEAR = 60
function rag.carry_pin(grabber, bodyUnit)
    local x, y, z = rag.hand_of(grabber)
    local lowest = grabber.pos.y + (rag.STANDING.neck[2] + rag.CARRY_CLEAR) * bodyUnit
    if y < lowest then y = lowest end
    return x, y, z
end

function rag.at_hand(points, grabber, bodyUnit)
    local neck = points[P.neck]
    if neck == nil or grabber == nil or grabber.pos == nil then return points end
    local x, y, z = rag.carry_pin(grabber, bodyUnit)
    local dx, dy, dz = x - neck.x, y - neck.y, z - neck.z
    local out = {}
    for i, q in ipairs(points) do out[i] = v(q.x + dx, q.y + dy, q.z + dz) end
    return out
end

function rag.hold_tick(m, body)
    local li = body.held
    if li == nil then body.pin = nil return end
    local grabber = gMarioStates[li]
    body.heldTicks = (body.heldTicks or 0) + 1
    if grabber == nil or not connected(li) or grabber.action == RAGDOLL
        or body.heldTicks > rag.HOLD_MAX
        or apart(grabber.pos, body.p[P.pelvis]) > rag.GRAB_REACH * rag.GRAB_LOSE then
        body.held, body.pin = nil, nil
        return
    end
    local x, y, z = rag.carry_pin(grabber, rag.unit_of(m))
    body.pin = { i = P.neck, x = x, y = y, z = z }

    body.still = 0
end

function rag.on_grab(data)
    local body = rag.body
    if body == nil then return false end
    if network_global_index_from_local ~= nil
        and data.g ~= network_global_index_from_local(0) then
        return false
    end
    local li = network_local_index_from_global ~= nil
        and network_local_index_from_global(tonumber(data.from) or -1) or nil
    if li == nil or li <= 0 or li >= (MAX_PLAYERS or 16) then return false end
    if tonumber(data.grab) == 1 then
        local grabber = gMarioStates[li]
        if grabber == nil or grabber.action == RAGDOLL or not connected(li)
            or (OF.moves ~= nil and OF.util.asks(OF.moves, "round_holds")
                and OF.moves.round_holds())
            or apart(grabber.pos, body.p[P.pelvis]) > rag.GRAB_REACH * rag.GRAB_SLACK then
            rag.rejected = rag.rejected + 1
            return false
        end
        body.held, body.heldTicks = li, 0
        return true
    end

    if body.held ~= li then return false end
    body.held, body.pin = nil, nil
    local vx, vy, vz = tonumber(data.vx) or 0, tonumber(data.vy) or 0, tonumber(data.vz) or 0
    local cap = rag.TERMINAL
    vx, vy, vz = max(-cap, min(cap, vx)), max(-cap, min(cap, vy)), max(-cap, min(cap, vz))
    for i = 1, COUNT do rag.set_velocity(body, i, vx, vy, vz) end
    body.still = 0
    return true
end

function rag.send(m)
    local body = rag.body
    if body == nil or OF.util == nil then return false end
    local pelvis = body.p[P.pelvis]
    rag.seq = (rag.seq + 1) % 0x10000
    local data = {
        ofp = rag.PACKET,
        n = rag.seq,
        g = network_global_index_from_local ~= nil and network_global_index_from_local(0) or 0,
        x = math.floor(pelvis.x + 0.5), y = math.floor(pelvis.y + 0.5),
        z = math.floor(pelvis.z + 0.5),
        s = rag.encode(body.p),
    }

    OF.util.send_all_unreliable(data)
    rag.sent = rag.sent + 1
    return true
end

function rag.on_packet(data)
    if type(data) ~= "table" then return end
    if data.ofp == rag.GRAB_PACKET then rag.on_grab(data) return end
    if data.ofp ~= rag.PACKET then return end
    if network_local_index_from_global == nil then return end

    local g = tonumber(data.g)
    if g == nil or g ~= g or g < 0 or g >= (MAX_PLAYERS or 16) then return end
    local li = network_local_index_from_global(math.floor(g))
    if li == nil or li <= 0 or li >= (MAX_PLAYERS or 16) then return end
    local points = rag.decode(data.s, tonumber(data.x) or 0, tonumber(data.y) or 0,
        tonumber(data.z) or 0)
    if points == nil then return end
    local heard = rag.heard[li] or {}

    local n = tonumber(data.n)
    if n ~= nil and heard.n ~= nil then
        local behind = (heard.n - n) % 0x10000
        if behind < 0x8000 then return end
    end
    heard.n = n
    heard.older = heard.newer
    heard.newer = { points = points, at = get_global_timer ~= nil and get_global_timer() or 0 }
    heard.fresh = true
    rag.heard[li] = heard
end

rag.AHEAD_MAX = 4
rag.BLEND = 0.5
function rag.heard_points(li, now)
    local heard = rag.heard[li]
    if heard == nil or heard.newer == nil then return nil end
    local b = heard.newer
    local a = heard.older
    local span = a ~= nil and (b.at - a.at) or 0
    local ahead = now - b.at
    if ahead < 0 then ahead = 0 elseif ahead > rag.AHEAD_MAX then ahead = rag.AHEAD_MAX end
    local k = (span > 0) and (ahead / span) or 0
    local target = {}
    for i = 1, COUNT do
        local pb = b.points[i]
        local pa = (span > 0) and a.points[i] or pb
        target[i] = v(pb.x + (pb.x - pa.x) * k, pb.y + (pb.y - pa.y) * k,
                      pb.z + (pb.z - pa.z) * k)
    end
    if heard.fresh then
        heard.fresh = false
        local shown = heard.shown
        heard.offset = {}
        for i = 1, COUNT do
            if shown ~= nil and shown[i] ~= nil then
                heard.offset[i] = { shown[i].x - target[i].x, shown[i].y - target[i].y,
                                    shown[i].z - target[i].z }
            else
                heard.offset[i] = { 0, 0, 0 }
            end
        end
    end
    local out = {}
    local offset = heard.offset
    for i = 1, COUNT do
        local o = offset ~= nil and offset[i] or nil
        if o ~= nil then
            out[i] = v(target[i].x + o[1], target[i].y + o[2], target[i].z + o[3])
            o[1], o[2], o[3] = o[1] * rag.BLEND, o[2] * rag.BLEND, o[3] * rag.BLEND
        else
            out[i] = target[i]
        end
    end
    heard.shown = out
    return out
end

local PART_TYPE = GRAPH_NODE_TYPE_ANIMATED_PART or 0x019
local BONE_TYPE = GRAPH_NODE_TYPE_BONE or 0x030
local SWITCH_TYPE = GRAPH_NODE_TYPE_SWITCH_CASE or 0x10C

local function key_of(x)
    if x == nil then return nil end
    local ok, pointer = pcall(function() return x._pointer end)
    if ok and pointer ~= nil then return pointer end
    return x
end

local BUDGET = 800
local function walk(root, mark)
    local count, seen, bones = 0, 0, 0
    local ring

    local function one(node, counting)
        seen = seen + 1
        if seen > BUDGET then return end
        local t = node.type
        if t == PART_TYPE or t == BONE_TYPE then
            if counting then count = count + 1 end
            if t == BONE_TYPE then bones = bones + 1 end
            if mark ~= nil then mark(node) end
        end
        local child = node.children
        if child ~= nil then ring(child, counting, t == SWITCH_TYPE) end
    end

    ring = function(first, counting, firstOnly)
        local node, n = first, 0
        repeat
            one(node, counting and (not firstOnly or n == 0))
            n = n + 1
            node = node.next
        until node == nil or node == first or seen > BUDGET
    end
    if root ~= nil then one(root, true) end
    return count, seen, bones
end
rag.walk = walk

function rag.skeleton_ok(shared)
    local key = key_of(shared)
    if key == nil then return false end
    local known = rag.skeletons[key]
    if known ~= nil then return known end

    local count, _, bones = walk(shared, nil)
    known = (count == rag.PARTS and bones == 0)
    rag.skeletons[key] = known
    return known
end

rag.markedModels = {}
function rag.mark(shared)
    local key = key_of(shared)
    if key ~= nil and rag.markedModels[key] then return end
    if key ~= nil then rag.markedModels[key] = true end
    walk(shared, function(node)
        if node.hookProcess == 0 then
            node.hookProcess = rag.MARK
            rag.marked[node] = true
        end
    end)
end

function rag.unmark()
    for node in pairs(rag.marked) do
        if node.hookProcess == rag.MARK then node.hookProcess = 0 end
    end
    rag.marked = {}
    rag.markedModels = {}

    rag.localInv = {}
end

local camFrame, camNow, camPrev = -1, {}, {}
local function read12(mat, into)
    into[1], into[2], into[3] = mat.m00, mat.m01, mat.m02
    into[4], into[5], into[6] = mat.m10, mat.m11, mat.m12
    into[7], into[8], into[9] = mat.m20, mat.m21, mat.m22
    into[10], into[11], into[12] = mat.m30, mat.m31, mat.m32
end
local function camera()
    local frame = get_global_timer()
    if camFrame == frame then return camNow, camPrev end
    local cam = geo_get_current_camera ~= nil and geo_get_current_camera() or nil
    if cam == nil or cam.matrixPtr == nil then return nil end
    read12(cam.matrixPtr, camNow)
    read12(cam.matrixPtrPrev or cam.matrixPtr, camPrev)
    camFrame = frame
    return camNow, camPrev
end
rag.forget_camera = function() camFrame = -1 end

function rag.world_scale(mat, V)
    local a0, a1, a2 = mat.m00 or 0, mat.m01 or 0, mat.m02 or 0
    if V == nil then return len3(a0, a1, a2) end
    local Vi = inverse12(V)
    if Vi == nil then return len3(a0, a1, a2) end
    return len3(a0 * Vi[1] + a1 * Vi[4] + a2 * Vi[7],
                a0 * Vi[2] + a1 * Vi[5] + a2 * Vi[8],
                a0 * Vi[3] + a1 * Vi[6] + a2 * Vi[9])
end

function rag.before_geo(node, index)
    if node == nil then return end
    local t = node.type
    if t ~= PART_TYPE and t ~= BONE_TYPE then return end
    local m = geo_get_mario_state()
    if m == nil then return end
    local d = rag.drawn[m.playerIndex]
    if d == nil then return end

    if geo_get_current_object() ~= m.marioObj then return end
    local part = (m.marioBodyState.currAnimPart or 0) + 1
    local f = d.cur[part]
    if f == nil then return end
    local V, Vp = camera()
    if V == nil then return end
    local slot, prevSlot = gMatStack[index], gMatStackPrev[index]
    if slot == nil or prevSlot == nil then return end
    if part == 1 then

        d.s, d.sp = rag.world_scale(slot, V), rag.world_scale(prevSlot, Vp)
    end
    if d.s == nil or d.s <= 0 then return end

    if part == 1 or d.key == nil then d.key = key_of(m.marioObj.header.gfx.sharedChild) end
    local modelKey = d.key
    local known = modelKey ~= nil and rag.localInv[modelKey] or nil
    local Li = known ~= nil and known[part] or nil
    local shaped = cast_graph_node(node)
    local tr = shaped ~= nil and shaped.translation or nil
    local tx, ty, tz = 0, 0, 0
    if tr ~= nil then tx, ty, tz = tr.x or 0, tr.y or 0, tr.z or 0 end
    if Li ~= nil then
        rag.compose_local(f, d.s, Li, V, slot)
        rag.compose_local(d.prev[part] or f, d.sp or d.s, Li, Vp, prevSlot)
    else
        rag.compose(f, d.s, tx, ty, tz, V, slot)
        rag.compose(d.prev[part] or f, d.sp or d.s, tx, ty, tz, Vp, prevSlot)
    end
    rag.measuring[index] = { key = modelKey, part = part, t = { tx, ty, tz } }
    rag.posed = rag.posed + 1
end

rag.localInv = {}
rag.measuring = {}
rag.measured = 0

rag.LOCAL_DRIFT = 400
local function measure(index)
    if index == nil or index < 1 then return end
    local rec = rag.measuring[index - 1]
    if rec == nil then return end
    rag.measuring[index - 1] = nil
    local child, parent = gMatStack[index], gMatStack[index - 1]
    if child == nil or parent == nil or rec.key == nil then return end
    local P12, C12 = {}, {}
    read12(parent, P12)
    read12(child, C12)
    local Pinv = inverse12(P12)
    if Pinv == nil then return end
    local L = mul12(C12, Pinv)
    local Li, det = inverse12(L)
    if Li == nil or abs(det - 1) > 0.05 then return end
    if rec.t ~= nil then
        local dx, dy, dz = L[10] - rec.t[1], L[11] - rec.t[2], L[12] - rec.t[3]
        if len3(dx, dy, dz) > rag.LOCAL_DRIFT then return end
    end
    local byModel = rag.localInv[rec.key]
    if byModel == nil then
        byModel = {}
        rag.localInv[rec.key] = byModel
    end
    byModel[rec.part] = Li
    rag.measured = rag.measured + 1
end

function rag.on_children(node, index) measure(index) end

function rag.on_geo(node, index) measure(index) end

function rag.update(m)
    if m == nil then return end
    local i = m.playerIndex
    if i == 0 then
        if rag.body ~= nil and m.action ~= RAGDOLL then

            rag.finish()
        end

        local pending = rag.pending
        rag.pending = nil
        if pending ~= nil and m.action == pending.action then rag.start(m, true) end
        rag.carrier_tick(m)
        rag.read_button(m)
    elseif RAGDOLL ~= nil and m.action == RAGDOLL then
        local now = get_global_timer()
        local points = rag.heard_points(i, now)
            or rag.standing_points(m, rag.unit_of(m), true)
        if rag.carrying == i then
            points = rag.at_hand(points, gMarioStates[0], rag.unit_of(m))
        end
        local was = rag.drawn[i]
        rag.keepOf = rag.keepOf or {}
        rag.keepOf[i] = rag.keepOf[i] or {}
        local cur = rag.frames(points, rag.keepOf[i])
        rag.drawn[i] = { cur = cur, prev = was ~= nil and was.cur or cur }
    else
        rag.drawn[i] = nil
        rag.heard[i] = nil
        if rag.keepOf ~= nil then rag.keepOf[i] = nil end
    end

    local d = rag.drawn[i]
    local obj = m.marioObj
    if d ~= nil and obj ~= nil then
        local shared = obj.header.gfx.sharedChild
        if shared ~= nil and rag.skeleton_ok(shared) then

            if set_mario_animation ~= nil and MARIO_ANIM_A_POSE ~= nil then
                set_mario_animation(m, MARIO_ANIM_A_POSE)
            end
            smlua_anim_util_set_animation(obj, rag.ANIM)
            rag.mark(shared)
        else

            rag.drawn[i] = nil
        end
    end

    if i == 0 then rag.tidy() end
end

function rag.tidy()
    for j in pairs(rag.drawn) do
        if j ~= 0 then
            local other = gMarioStates[j]
            local np = gNetworkPlayers ~= nil and gNetworkPlayers[j] or nil
            if other == nil or other.action ~= RAGDOLL
                or (np ~= nil and np.connected == false) then
                rag.drawn[j] = nil
                rag.heard[j] = nil
            end
        end
    end
    if next(rag.drawn) == nil and next(rag.marked) ~= nil then rag.unmark() end
end

function rag.on_level()
    rag.heard = {}
    for i in pairs(rag.drawn) do if i ~= 0 then rag.drawn[i] = nil end end
end

if RAGDOLL ~= nil then
    at_load("hook_mario_action", RAGDOLL, { every_frame = act_ragdoll })
end
hook_event(HOOK_MARIO_UPDATE, rag.update)
hook_event(HOOK_BEFORE_GEO_PROCESS, rag.before_geo)
hook_event(HOOK_ON_GEO_PROCESS, rag.on_geo)
hook_event(HOOK_ON_GEO_PROCESS_CHILDREN, rag.on_children)
hook_event(HOOK_ON_PACKET_RECEIVE, rag.on_packet)
hook_event(HOOK_ON_LEVEL_INIT, rag.on_level)
hook_event(HOOK_ON_SET_MARIO_ACTION, rag.on_set_action)
hook_event(HOOK_BEFORE_MARIO_UPDATE, rag.before_update, OF.LOCAL_MARIO)

function rag.ready()
    return RAGDOLL ~= nil
end
