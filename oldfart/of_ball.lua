OF = OF or {}
OF.ball = OF.ball or {}

local ball = OF.ball

ball.MATERIALS = {
    standard = { gravity = 2.5, bounce = 0.55, roll = 0.98, air = 0.995, wall = 0.7,
                 touch = 1.0, cap = 170, buoyancy = 0 },
    rubber   = { gravity = 2.5, bounce = 0.75, roll = 0.985, air = 0.995, wall = 0.85,
                 touch = 1.0, cap = 170, buoyancy = 0 },
    bowling  = { gravity = 4.0, bounce = 0.15, roll = 0.995, air = 0.998, wall = 0.3,
                 touch = 0.45, cap = 170, buoyancy = 2 },
    beach    = { gravity = 1.2, bounce = 0.7, roll = 0.97, air = 0.98, wall = 0.8,
                 touch = 0.8, cap = 80, buoyancy = -0.5 },
    crystal  = { gravity = 2.5, bounce = 0.55, roll = 0.98, air = 0.995, wall = 0.7,
                 touch = 1.0, cap = 170, buoyancy = 0, breakLand = 30, breakHit = 60 },

    volley   = { gravity = 1.0, bounce = 0.55, roll = 0.95, air = 0.995, wall = 0.6,
                 touch = 0.65, cap = 75, buoyancy = -0.5, fall = 40 },
}

ball.MATERIAL_ORDER = { "standard", "rubber", "bowling", "beach", "crystal" }

function ball.material(name)
    return ball.MATERIALS[name or "standard"] or ball.MATERIALS.standard
end

ball.SURFACES = {
    normal  = { friction = 1.0,  bounce = 1.0,  power = 1.0,  name = "the fairway" },
    ice     = { friction = 0.25, bounce = 0.73, power = 1.0,  name = "ice" },
    mud     = { friction = 3.0,  bounce = 0.55, power = 0.8,  name = "mud" },
    bouncy  = { friction = 1.0,  bounce = 1.45, power = 1.0,  name = "bouncy" },
    slick   = { friction = 0.4,  bounce = 0.8,  power = 1.0,  name = "the green" },
    rough   = { friction = 2.5,  bounce = 0.7,  power = 0.8,  name = "the rough" },
    bunker  = { friction = 8.0,  bounce = 0.1,  power = 0.55, name = "a bunker" },
}

ball.SURFACE_ORDER = { "normal", "ice", "mud", "bouncy" }

local BOUNCE_CEILING = 0.9

function ball.surface(name)
    return ball.SURFACES[name or "normal"] or ball.SURFACES.normal
end

local function type_is(t, name, value)
    local known = _G[name]
    if type(known) ~= "number" then known = value end
    return t == known
end

function ball.lie_of(surfaceType)
    local t = tonumber(surfaceType) or 0
    if type_is(t, "SURFACE_DEATH_PLANE", 0x000A) or type_is(t, "SURFACE_BURNING", 0x0001)
        or type_is(t, "SURFACE_VERTICAL_WIND", 0x0038)
        or type_is(t, "SURFACE_INSTANT_QUICKSAND", 0x0023)
        or type_is(t, "SURFACE_INSTANT_MOVING_QUICKSAND", 0x002D) then
        return "out"
    end
    if type_is(t, "SURFACE_SHALLOW_QUICKSAND", 0x0021) or type_is(t, "SURFACE_DEEP_QUICKSAND", 0x0022)
        or type_is(t, "SURFACE_DEEP_MOVING_QUICKSAND", 0x0024)
        or type_is(t, "SURFACE_SHALLOW_MOVING_QUICKSAND", 0x0025)
        or type_is(t, "SURFACE_QUICKSAND", 0x0026) or type_is(t, "SURFACE_MOVING_QUICKSAND", 0x0027) then
        return "bunker"
    end
    if type_is(t, "SURFACE_ICE", 0x002E) or type_is(t, "SURFACE_VERY_SLIPPERY", 0x0013)
        or type_is(t, "SURFACE_HARD_VERY_SLIPPERY", 0x0036)
        or type_is(t, "SURFACE_NOISE_VERY_SLIPPERY", 0x0075)
        or type_is(t, "SURFACE_NOISE_VERY_SLIPPERY_73", 0x0073)
        or type_is(t, "SURFACE_NOISE_VERY_SLIPPERY_74", 0x0074)
        or type_is(t, "SURFACE_NO_CAM_COL_VERY_SLIPPERY", 0x0078) then
        return "ice"
    end
    if type_is(t, "SURFACE_SLIPPERY", 0x0014) or type_is(t, "SURFACE_HARD_SLIPPERY", 0x0035)
        or type_is(t, "SURFACE_NOISE_SLIPPERY", 0x002A)
        or type_is(t, "SURFACE_NO_CAM_COL_SLIPPERY", 0x0079) then
        return "slick"
    end
    if type_is(t, "SURFACE_NOT_SLIPPERY", 0x0015) or type_is(t, "SURFACE_HARD_NOT_SLIPPERY", 0x0037)
        or type_is(t, "SURFACE_SLOW", 0x0009) then
        return "rough"
    end
    return "normal"
end

local K = {
    SUB_LEN = 50,
    SUB_MAX = 8,
    BOUNCE_MIN = 6,
    STOP = 0.4,
    GRIP = 0.15,
    WALL_GRIP = 0.1,
    FLOOR_NY = 0.5,
    STICK = 20,
    STICK_PER = 0.75,
    CLIMB = 0.6,
    PIT = 3000,
    WATER_DRAG = 0.8,
    SKIP_SPEED = 12.5,
    SKIP_BAND = 30,
    CURL = 0.012,
    SPIN_AIR = 0.99,
    SPIN_LAND = 0.3,
    TOP_LAND = 0.35,
    BACK_BITE = -0.8,
    WALL_RADIUS = 200,
}
ball.K = K

local function len3(x, y, z) return math.sqrt(x * x + y * y + z * z) end

function ball.rebound(b, nx, ny, nz, e, grip, settle)
    local vn = b.vx * nx + b.vy * ny + b.vz * nz
    if vn >= 0 then return 0 end
    if settle and -vn < K.BOUNCE_MIN then e = 0 end
    local tx, ty, tz = b.vx - vn * nx, b.vy - vn * ny, b.vz - vn * nz
    local along = len3(tx, ty, tz)
    local keep = 1
    if along > 0.0001 then
        keep = 1 - math.min(along, grip * (1 + e) * -vn) / along
    end
    b.vx = tx * keep - e * vn * nx
    b.vy = ty * keep - e * vn * ny
    b.vz = tz * keep - e * vn * nz
    return -vn
end

function ball.clamp(b, cap)
    local speed = len3(b.vx, b.vy, b.vz)
    if cap ~= nil and speed > cap then
        local k = cap / speed
        b.vx, b.vy, b.vz = b.vx * k, b.vy * k, b.vz * k
    end
end

function ball.new(x, y, z, radius)
    return { x = x or 0, y = y or 0, z = z or 0, vx = 0, vy = 0, vz = 0,
             radius = radius or 100, spin = 0, top = 0, step = 0,
             grounded = false, lie = "normal", turn = 0 }
end

function ball.kick(b, vx, vy, vz, spin, top, cap)
    b.vx, b.vy, b.vz = vx or 0, vy or 0, vz or 0
    b.spin = math.max(-1, math.min(1, spin or 0))
    b.top = math.max(-1, math.min(1, top or 0))
    b.grounded = false
    ball.clamp(b, cap)
end

function ball.curl(b)
    local spin = b.spin or 0
    if spin == 0 then return 0 end
    local a = spin * K.CURL
    local c, s = math.cos(a), math.sin(a)

    local vx, vz = b.vx, b.vz
    b.vx = vx * c - vz * s
    b.vz = vx * s + vz * c
    b.spin = spin * K.SPIN_AIR
    if math.abs(b.spin) < 0.01 then b.spin = 0 end
    return a
end

local function spend_spin(b, wasVx, wasVz)
    b.spin = (b.spin or 0) * K.SPIN_LAND
    if math.abs(b.spin) < 0.01 then b.spin = 0 end
    local top = b.top or 0
    if top ~= 0 then
        if top < K.BACK_BITE then

            b.vx, b.vz = -wasVx * 0.25, -wasVz * 0.25
        else
            local keep = 1 + top * K.TOP_LAND
            b.vx, b.vz = b.vx * keep, b.vz * keep
        end
        b.top = top * 0.5
        if math.abs(b.top) < 0.05 then b.top = 0 end
    end
end

local function floor_at(x, y, z)
    if find_floor == nil then return -11000, nil end
    local h, surf = find_floor(x, y, z)
    return tonumber(h) or -11000, surf
end

local function water_at(x, z)
    if find_water_level == nil then return -11000 end
    return tonumber(find_water_level(x, z)) or -11000
end

local function ray(sx, sy, sz, dx, dy, dz)
    if collision_find_surface_on_ray == nil then return nil end
    local info = collision_find_surface_on_ray(sx, sy, sz, dx, dy, dz)

    if info == nil or info.surface == nil then return nil end
    local s = info.surface
    if s.type ~= nil and type_is(s.type, "SURFACE_INTANGIBLE", 0x0012) then return nil end
    local n = s.normal
    if n == nil then return nil end
    return info.hitPos.x, info.hitPos.y, info.hitPos.z, n.x, n.y, n.z, s.type
end

local wallProbe = { x = 0, y = 0, z = 0 }
local function push_off_walls(b)
    if resolve_and_return_wall_collisions == nil then return nil end
    wallProbe.x, wallProbe.y, wallProbe.z = b.x, b.y, b.z
    local wall = resolve_and_return_wall_collisions(wallProbe, 0,
        math.min(b.radius or 100, K.WALL_RADIUS))
    if wall == nil or wall.normal == nil then return nil end

    local n = wall.normal
    local before = n.x * b.x + (n.y or 0) * b.y + n.z * b.z + (tonumber(wall.originOffset) or 0)
    if before < 0 then return nil end
    b.x, b.z = wallProbe.x, wallProbe.z
    return wall.normal.x, wall.normal.z
end

local function hard(events, mat, speed, landing)
    local line = landing and mat.breakLand or mat.breakHit
    if line ~= nil and speed > line then events.broke = true end
end

local function contact(b, events, mat, surf, nx, ny, nz, surfaceType)
    if ny >= K.FLOOR_NY then
        local wasVx, wasVz = b.vx, b.vz
        local e = math.min(BOUNCE_CEILING, mat.bounce * surf.bounce)
        local into = ball.rebound(b, nx, ny, nz, e, K.GRIP, true)
        if into > 0 then
            if into >= K.BOUNCE_MIN then
                events.landed = math.max(events.landed or 0, into)
                spend_spin(b, wasVx, wasVz)
            end
            hard(events, mat, into, true)
        end
        if b.vx * nx + b.vy * ny + b.vz * nz < K.BOUNCE_MIN then b.grounded = true end
        b.lie = surfaceType ~= nil and ball.lie_of(surfaceType) or b.lie
        return
    end
    local into = ball.rebound(b, nx, ny, nz, mat.wall, K.WALL_GRIP, false)
    if into > 0 then
        events.wall = math.max(events.wall or 0, into)
        hard(events, mat, into, false)
    end
end

local function planes(b, events, list, fromX, fromY, fromZ)
    if list == nil then return end
    local r = b.radius or 100
    for _, p in ipairs(list) do
        local inside = (p.minY == nil or b.y + r > p.minY) and (p.maxY == nil or b.y - r < p.maxY)
            and (p.minX == nil or b.x > p.minX) and (p.maxX == nil or b.x < p.maxX)
            and (p.minZ == nil or b.z > p.minZ) and (p.maxZ == nil or b.z < p.maxZ)
        if inside then
            local was = p.nx * fromX + p.ny * fromY + p.nz * fromZ + p.d
            local now = p.nx * b.x + p.ny * b.y + p.nz * b.z + p.d
            local nx, ny, nz, gap = p.nx, p.ny, p.nz, now

            if p.twoSided and was < 0 then nx, ny, nz, gap = -nx, -ny, -nz, -now end
            if gap < r then
                local push = r - gap
                b.x, b.y, b.z = b.x + nx * push, b.y + ny * push, b.z + nz * push
                local into = ball.rebound(b, nx, ny, nz, p.e or 0.5, p.grip or K.WALL_GRIP, false)
                if into > 0 then
                    events.plane = p.name or true
                    events.wall = math.max(events.wall or 0, into)
                end
            end
        end
    end
end

function ball.step(b, world)
    world = world or {}
    local mat = type(world.material) == "table" and world.material or ball.material(world.material)
    local fixed = world.surface ~= nil and ball.surface(world.surface) or nil
    local events = {}
    local r = b.radius or 100
    b.step = (b.step or 0) + 1

    local waterY = world.noWorld and -11000 or water_at(b.x, b.z)
    local wet = b.y < waterY
    if wet then
        if not b.wet then events.splash = true end
        events.water = true
        b.vy = b.vy + (1 - (mat.buoyancy or 0)) * mat.gravity
        local flat = math.sqrt(b.vx * b.vx + b.vz * b.vz)
        if flat > K.SKIP_SPEED and math.abs(b.y - r - waterY) < K.SKIP_BAND + r and b.vy < 0 then
            b.vy = -b.vy
        end
        b.vx, b.vy, b.vz = b.vx * K.WATER_DRAG, b.vy * K.WATER_DRAG, b.vz * K.WATER_DRAG
        b.grounded = false
    elseif not b.grounded then
        local was = b.vy
        b.vy = b.vy - mat.gravity

        if mat.fall ~= nil and b.vy < -mat.fall then b.vy = math.min(-mat.fall, was) end
        ball.curl(b)
    end
    b.wet = wet
    ball.clamp(b, mat.cap)

    local speed = len3(b.vx, b.vy, b.vz)
    local steps = math.max(1, math.min(K.SUB_MAX, math.ceil(speed / K.SUB_LEN)))
    local wasGrounded = b.grounded
    local lastFloor = nil
    for _ = 1, steps do
        local dx, dy, dz = b.vx / steps, b.vy / steps, b.vz / steps
        local fromX, fromY, fromZ = b.x, b.y, b.z
        local moved = len3(dx, dy, dz)
        local hit = false
        if moved > 0.001 and not world.noWorld then

            local reach = (moved + r) / moved
            local hx, hy, hz, nx, ny, nz, st = ray(b.x, b.y, b.z, dx * reach, dy * reach, dz * reach)
            if hx ~= nil then
                if nx * dx + ny * dy + nz * dz > 0 then nx, ny, nz = -nx, -ny, -nz end

                if not (b.grounded and ny >= K.FLOOR_NY) then
                    b.x, b.y, b.z = hx + nx * r, hy + ny * r, hz + nz * r
                    contact(b, events, mat, fixed or ball.surface(ball.lie_of(st)),
                        nx, ny, nz, st)
                    hit = true
                end
            end
        end
        if not hit then
            b.x, b.y, b.z = b.x + dx, b.y + dy, b.z + dz
        end
        planes(b, events, world.planes, fromX, fromY, fromZ)

        if not world.noWorld then
            local wx, wz = push_off_walls(b)
            if wx ~= nil then
                local into = ball.rebound(b, wx, 0, wz, mat.wall, K.WALL_GRIP, false)
                if into > 0 then
                    events.wall = math.max(events.wall or 0, into)
                    hard(events, mat, into, false)
                end
            end
        end

        local floorY, floor
        if world.noWorld then
            floorY, floor = world.floorY or 0, world.floorSurface
        else
            floorY, floor = floor_at(b.x, b.y, b.z)
        end
        lastFloor = floor
        if floor == nil and not world.noWorld then

            b.grounded = false
            if b.pitFrom == nil then b.pitFrom = b.y end
            if b.y < b.pitFrom - K.PIT or b.y < -10500 then events.out = "pit" end
        else
            b.pitFrom = nil
            local n = floor ~= nil and floor.normal or { x = 0, y = 1, z = 0 }
            local st = floor ~= nil and floor.type or nil
            local lie = fixed ~= nil and world.surface or ball.lie_of(st)
            local bottom = b.y - r
            local gap = bottom - floorY
            if gap < 0 then
                if -gap > r * K.CLIMB + moved and b.grounded and not hit then

                    b.x, b.y, b.z = fromX, fromY, fromZ
                    local hx2, hz2 = dx, dz
                    local flat = math.sqrt(hx2 * hx2 + hz2 * hz2)
                    if flat > 0.001 then
                        local into = ball.rebound(b, -hx2 / flat, 0, -hz2 / flat, mat.wall, K.WALL_GRIP, false)
                        if into > 0 then events.wall = math.max(events.wall or 0, into) end
                    end
                else
                    b.y = floorY + r
                    if not b.grounded then
                        contact(b, events, mat, fixed or ball.surface(lie), n.x, n.y, n.z, st)
                    end
                    b.lie = lie
                end
            elseif b.grounded and gap <= K.STICK + moved * K.STICK_PER and b.vy <= 0.001
                and n.y >= K.FLOOR_NY then

                b.y = floorY + r
                b.lie = lie
            elseif gap > 0.5 then
                b.grounded = false
            end
            if lie == "out" and b.y - r <= floorY + 0.5 then
                events.out = events.out or (st ~= nil and type_is(st, "SURFACE_BURNING", 1) and "lava" or "death")
            end
        end
        if events.out ~= nil or events.broke then break end
    end

    if b.grounded and not b.wet then
        local f = lastFloor
        local surf = fixed or ball.surface(b.lie)
        if f ~= nil and f.normal ~= nil then
            local nx, ny, nz = f.normal.x, f.normal.y, f.normal.z
            local nn = nx * nx + ny * ny + nz * nz
            if nn > 0 then

                local h = (nx * nx + nz * nz) / nn * mat.gravity * 2
                b.vx = b.vx + nx * h
                b.vz = b.vz + nz * h
            end
        end
        b.vy = 0
        local keep = 1 - (1 - mat.roll) * surf.friction
        b.vx, b.vz = b.vx * keep, b.vz * keep
        if math.abs(b.vx) < K.STOP and math.abs(b.vz) < K.STOP then
            b.vx, b.vz = 0, 0
            events.rest = true
        end
    elseif not b.wet then
        b.vx, b.vz = b.vx * mat.air, b.vz * mat.air
        b.vy = b.vy * mat.air
    end
    ball.clamp(b, mat.cap)

    local flat = math.sqrt(b.vx * b.vx + b.vz * b.vz)
    b.turn = ((b.turn or 0) + flat / r) % (2 * math.pi)
    if wasGrounded and not b.grounded then events.left = true end
    return events
end

function ball.pack(b)
    return string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f",
        b.x, b.y, b.z, b.vx * 10, b.vy * 10, b.vz * 10, (b.spin or 0) * 100, (b.top or 0) * 100)
end

function ball.unpack(text, into)
    if type(text) ~= "string" then return nil end
    local parts = {}
    for word in string.gmatch(text, "%S+") do parts[#parts + 1] = tonumber(word) end
    if #parts < 6 then return nil end
    for i = 1, 6 do if parts[i] == nil then return nil end end
    local b = into or ball.new(0, 0, 0)
    b.x, b.y, b.z = parts[1], parts[2], parts[3]
    b.vx, b.vy, b.vz = parts[4] / 10, parts[5] / 10, parts[6] / 10
    b.spin = (parts[7] or 0) / 100
    b.top = (parts[8] or 0) / 100
    return b
end

ball.MODEL = { geo = "of_ball_geo", radius = 100 }
ball.STAND_IN = { geo = "ccm_geo_0003F0", radius = 180 }

local modelCache = nil

function ball.model(radius)
    radius = radius or 100
    if modelCache == nil then
        modelCache = {}
        if OF.util.optional("mod_file_exists", false, "actors/" .. ball.MODEL.geo .. ".bin") then
            local id = OF.util.optional("smlua_model_util_get_id", nil, ball.MODEL.geo)
            if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
                modelCache.id, modelCache.radius, modelCache.shadow = id, ball.MODEL.radius, true
            end
        end
        if modelCache.id == nil then
            local found = OF.util.optional("smlua_model_util_get_id", nil, ball.STAND_IN.geo)
            if type(found) == "number" and found ~= E_MODEL_ERROR_MODEL then
                modelCache.id, modelCache.radius = found, ball.STAND_IN.radius
            end
        end
        if modelCache.id == nil then
            modelCache.id, modelCache.radius = E_MODEL_BOWLING_BALL, 100
        end
    end
    return modelCache.id, radius / modelCache.radius, modelCache.shadow == true
end

function ball.forget_model()
    modelCache = nil
end

function ball.draw(name, b, at)
    if b == nil or not OF.util.asks(OF.gamemodes, "show_token") then return nil end
    at = at or b
    local r = b.radius or 100
    local id, scale, shadow = ball.model(r)
    local token = OF.gamemodes.show_token(name, id, { x = at.x, y = at.y, z = at.z })
    if token == nil then return nil end
    OF.util.optional("obj_scale", nil, token, scale)
    if shadow and E_MODEL_WATER_BOMB_SHADOW ~= nil then
        local shade = OF.gamemodes.show_token(name .. "Shadow", E_MODEL_WATER_BOMB_SHADOW,
            { x = at.x, y = at.y, z = at.z })
        if shade ~= nil then OF.util.optional("obj_scale", nil, shade, r * 1.25 / 160) end
    end
    local flat = math.sqrt((b.vx or 0) ^ 2 + (b.vz or 0) ^ 2)
    if flat > 0.5 then
        token.oFaceAngleYaw = math.floor(math.atan(b.vx, b.vz) * 32768 / math.pi) % 65536
    end
    token.oFaceAnglePitch = math.floor((b.turn or 0) * 32768 / math.pi) % 65536
    return token
end

function ball.hide(name)
    if not OF.util.asks(OF.gamemodes, "hide_token") then return end
    OF.gamemodes.hide_token(name)
    OF.gamemodes.hide_token(name .. "Shadow")
end

ball.BALLOON = {
    knot = 40,

    radius = 30,
    bands = { { y = -40, r = 8.1 }, { y = -30, r = 16.0 }, { y = -20, r = 25.6 },
              { y = 0, r = 30.0 }, { y = 10, r = 28.0 }, { y = 20, r = 21.1 },
              { y = 30, r = 11.7 } },
    order = { "red", "white", "blue", "green", "yellow",
              "orange", "purple", "pink", "cyan", "brown" },
    rgb = { red = { 255, 7, 4 }, white = { 242, 242, 242 }, blue = { 47, 111, 232 },
            green = { 60, 194, 74 }, yellow = { 245, 199, 38 },
            orange = { 255, 110, 10 }, purple = { 142, 60, 214 },
            pink = { 255, 126, 200 }, cyan = { 46, 224, 230 },
            brown = { 122, 74, 36 } },
    standIn = "E_MODEL_BUBBLE",
}

function ball.balloon_geo(colour)
    if colour == nil or colour == "red" or ball.BALLOON.rgb[colour] == nil then
        return "of_balloon_geo"
    end
    return "of_balloon_" .. colour .. "_geo"
end

ball.LOAD_GEOS = ball.LOAD_GEOS or {}
function ball.resolve_at_load(geos)
    for _, geo in ipairs(geos or {}) do
        local seen = false
        for _, had in ipairs(ball.LOAD_GEOS) do
            if had == geo then seen = true end
        end
        if not seen then ball.LOAD_GEOS[#ball.LOAD_GEOS + 1] = geo end
    end
    local asked = {}
    if type(mod_file_exists) ~= "function" or type(smlua_model_util_get_id) ~= "function" then
        return asked
    end
    for _, geo in ipairs(ball.LOAD_GEOS) do
        local okHave, have = pcall(mod_file_exists, "actors/" .. geo .. ".bin")
        if okHave and have == true and pcall(smlua_model_util_get_id, geo) then
            asked[#asked + 1] = geo
        end
    end
    return asked
end
do
    local geos = { ball.MODEL.geo }
    for _, colour in ipairs(ball.BALLOON.order) do geos[#geos + 1] = ball.balloon_geo(colour) end
    ball.ASKED_AT_LOAD = ball.resolve_at_load(geos)
end

local balloonModels = {}

function ball.balloon_model(colour)
    local geo = ball.balloon_geo(colour)
    local cached = balloonModels[geo]
    if cached == nil then
        cached = { id = _G[ball.BALLOON.standIn], host = false }
        if OF.util.optional("mod_file_exists", false, "actors/" .. geo .. ".bin") then
            local id = OF.util.optional("smlua_model_util_get_id", nil, geo)
            if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
                cached = { id = id, host = true }
            end
        end
        balloonModels[geo] = cached
    end
    return cached.id, cached.host
end

function ball.forget_balloon_models()
    balloonModels = {}
end

function ball.balloon_nearest(r, g, b)
    local best, bestD = "red", nil
    for _, key in ipairs(ball.BALLOON.order) do
        local c = ball.BALLOON.rgb[key]
        local d = (c[1] - (r or 0)) ^ 2 + (c[2] - (g or 0)) ^ 2 + (c[3] - (b or 0)) ^ 2
        if bestD == nil or d < bestD then best, bestD = key, d end
    end
    return best
end

function ball.balloon_seat(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return nil end
    local seat = 1
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.np ~= nil and entry.np.globalIndex < np.globalIndex then seat = seat + 1 end
    end
    return seat
end

function ball.balloon_colour(localIndex)
    local T = OF.teams
    if OF.util.asks(T, "in_play") and T.in_play() and OF.util.asks(T, "of")
        and T.of(localIndex) ~= T.NONE and OF.util.asks(T, "color_of") then
        return ball.balloon_nearest(T.color_of(localIndex))
    end
    local seat = ball.balloon_seat(localIndex)
    if seat == nil then return "red" end
    local order = ball.BALLOON.order
    return order[(seat - 1) % #order + 1]
end

local balloonDrawn = {}

function ball.balloon_draw(name, knot, colour, opts)
    if knot == nil or not OF.util.asks(OF.gamemodes, "show_token") then return nil end
    opts = opts or {}
    if opts.room ~= nil and OF.util.asks(OF.gamemodes, "in_place_room")
        and not OF.gamemodes.in_place_room(opts.room) then
        ball.balloon_hide(name)
        return nil
    end
    local id, host = ball.balloon_model(colour)
    if id == nil then return nil end

    if balloonDrawn[name] ~= nil and balloonDrawn[name] ~= id then
        OF.gamemodes.hide_token(name)
    end
    local scale = host and (opts.scale or 1) or opts.standInScale
    local lift = host and ball.BALLOON.knot * scale or 0
    local token = OF.gamemodes.show_token(name, id,
        { x = knot.x, y = knot.y + lift, z = knot.z }, opts.spin)
    if token == nil then return nil end

    if opts.yaw ~= nil and opts.spin == nil then token.oFaceAngleYaw = opts.yaw end
    balloonDrawn[name] = id
    if scale ~= nil then
        local gfx = token.header ~= nil and token.header.gfx or nil
        if gfx == nil or gfx.scale == nil or gfx.scale.x ~= scale then
            OF.util.optional("obj_scale", nil, token, scale)
        end
    end
    return token
end

function ball.balloon_hide(name)
    balloonDrawn[name] = nil
    if OF.util.asks(OF.gamemodes, "hide_token") then OF.gamemodes.hide_token(name) end
end

function ball.puff(b)
    if b == nil or not OF.util.asks(OF.celebrate, "puff") then return false end
    return OF.celebrate.puff(b.x, b.y, b.z) == true
end

ball.RIDE_KEY = "ofBallRide"
ball.PACKET_STATE = "ballat"
ball.PROP_RADIUS = 100
ball.PROP_MATERIAL = "rubber"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local RIDE_GROUND = at_load("allocate_mario_action",
    (ACT_GROUP_MOVING or 0x040) | (ACT_FLAG_MOVING or 0x400))
local RIDE_AIR = at_load("allocate_mario_action",
    (ACT_GROUP_AIRBORNE or 0x080) | (ACT_FLAG_AIR or 0x800))
ball.RIDE_GROUND, ball.RIDE_AIR = RIDE_GROUND, RIDE_AIR

local balls = {}
local ride = nil

local function in_a_round(index)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    if index == nil or index == 0 then return OF.lockdown.menu_stands_down() == true end
    return OF.lockdown.menu_stands_down(index) == true
end

local function read_ride(index)
    local row = gPlayerSyncTable[index]
    local p = {}
    for word in string.gmatch(tostring(row ~= nil and row[ball.RIDE_KEY] or ""), "%S+") do
        p[#p + 1] = tonumber(word)
    end
    if #p < 1 or p[1] == nil then return nil end
    return { id = p[1], vx = (p[2] or 0) / 10, vz = (p[3] or 0) / 10 }
end
ball.read_ride = read_ride

ball.RIDE_EVERY = 3
local rideSince = 0
local function publish_ride(now)
    rideSince = rideSince + 1
    if now ~= true and rideSince < ball.RIDE_EVERY then return false end
    rideSince = 0
    if ride == nil then
        OF.util.publish_row(0, "ofBallRide", "")
        return true
    end
    OF.util.publish_row(0, "ofBallRide", string.format("%.0f %.0f %.0f",
        ride.id, ride.vx * 10, ride.vz * 10))
    return true
end
ball.publish_ride = publish_ride

local function owns(o)
    local id = o ~= nil and o.oSyncID or nil
    if id == nil or id == 0 or type(sync_object_is_owned_locally) ~= "function" then return false end
    return sync_object_is_owned_locally(id) == true
end
ball.owns = owns

function ball.anchors()
    local out = {}
    local bhv = OF.spawner ~= nil and OF.spawner.BALL or nil
    if bhv == nil or type(obj_get_first_with_behavior_id) ~= "function" then return out end
    local o = obj_get_first_with_behavior_id(bhv)
    local guard = 0
    while o ~= nil and guard < 2048 do
        if o.activeFlags ~= 0 then out[#out + 1] = o end
        o = obj_get_next_with_same_behavior_id(o)
        guard = guard + 1
    end
    return out
end

local function token_name(entry)
    return "bpBall" .. tostring(entry.id)
end

local function entry_for(o)
    local entry = balls[o]
    if entry ~= nil then return entry end
    local b = ball.new(o.oPosX or 0, o.oPosY or 0, o.oPosZ or 0, ball.PROP_RADIUS)
    entry = { o = o, id = o.oSyncID or 0, b = b, frames = 0, kicks = {}, seq = 0, sent = nil }
    balls[o] = entry
    return entry
end

local NO_BALLS = setmetatable({}, { __newindex = function()
    error("ball.list() with no ball is shared and read-only", 2)
end })
local function by_sync_id(a, c) return a.id < c.id end
function ball.list()
    if next(balls) == nil then return NO_BALLS end
    local out = {}
    for _, entry in pairs(balls) do out[#out + 1] = entry end
    if #out > 1 then table.sort(out, by_sync_id) end
    return out
end

local function entry_by_id(id)
    id = tonumber(id)
    if id == nil then return nil end
    for _, entry in pairs(balls) do
        if entry.id == id then return entry end
    end
    return nil
end
ball.entry_by_id = entry_by_id

function ball.sync_anchors()
    local here = {}
    for _, o in ipairs(ball.anchors()) do
        here[o] = true
        entry_for(o)
    end
    for o, entry in pairs(balls) do
        if not here[o] or o.activeFlags == 0 then
            balls[o] = nil
            ball.hide(token_name(entry))
            if ride ~= nil and ride.id == entry.id then ball.get_off(gMarioStates[0], true) end
        end
    end
end

local function send_state(entry)
    entry.seq = entry.seq + 1
    local me = gNetworkPlayers[0]
    OF.util.send_all_unreliable({ ofp = ball.PACKET_STATE, id = entry.id, n = entry.seq,
        o = me ~= nil and me.globalIndex or nil, s = ball.pack(entry.b) })
end
ball.send_state = send_state

function ball.receive_state(data)
    if type(data) ~= "table" or data.ofp ~= ball.PACKET_STATE then return false end
    local o = nil
    for _, a in ipairs(ball.anchors()) do
        if a.oSyncID == tonumber(data.id) then o = a end
    end
    if o == nil or owns(o) then return false end
    local entry = entry_for(o)
    local n = tonumber(data.n) or 0
    local from = tonumber(data.o)
    if from ~= nil and from ~= entry.owner then
        entry.owner, entry.seq = from, n - 1
    end
    if n <= entry.seq then return false end
    local target = ball.unpack(data.s)
    if target == nil then return false end
    entry.seq = n
    entry.target = target
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) == "table" and data.ofp == ball.PACKET_STATE then ball.receive_state(data) end
end)

function ball.ridden_by_other(id)
    for index = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected then
            local r = read_ride(index)
            if r ~= nil and r.id == id then return index end
        end
    end
    return nil
end

function ball.menu_has_pad()
    return OF.util.menu_has_screen() == true
end

ball.RIDE = { accel = 1.4, friction = 0.97, top = 40, airSteer = 0.33, airKeep = 0.995,
              slope = 2.5, wallKeep = 0.85, gravity = 4, terminal = 75, jump = 62,
              bounceFrom = 16, bounceKeep = 0.5, mountReach = 0.85, mountAbove = 90,
              mountBelow = 40, offHop = 30, kickGap = 10,

              offSpeed = 16, offPerRadius = 0.02, offGuard = 45 }

local function has_flag(value, flag)
    if value == nil or flag == nil or flag == 0 then return false end
    return math.floor(value / flag) % 2 == 1
end

function ball.riding(m)
    m = m or gMarioStates[0]
    return m ~= nil and RIDE_GROUND ~= nil and (m.action == RIDE_GROUND or m.action == RIDE_AIR)
end

local function heading(yaw)
    local turn = (tonumber(yaw) or 0) * 2 * math.pi / 0x10000
    return math.sin(turn), math.cos(turn)
end

local offGuard = 0
function ball.off_speed(radius)
    local R = ball.RIDE
    return R.offSpeed + R.offPerRadius * (tonumber(radius) or ball.PROP_RADIUS)
end

function ball.off_carry(radius)
    local R = ball.RIDE
    radius = tonumber(radius) or ball.PROP_RADIUS
    local v, vy, x, y = ball.off_speed(radius), R.offHop, 0, 0
    for _ = 1, 400 do
        x = x + v
        y = y + vy
        vy = math.max(vy - R.gravity, -R.terminal)
        v = math.max(v - 0.35, 0)
        if y <= -2 * radius then break end
    end
    return x
end

function ball.get_off(m, quiet, ax, az)
    m = m or gMarioStates[0]
    if ride == nil and not ball.riding(m) then return false end
    local was = ride
    ride = nil
    publish_ride(true)
    local entry = was ~= nil and entry_by_id(was.id) or nil
    local radius = entry ~= nil and entry.b.radius or ball.PROP_RADIUS
    if m ~= nil and ball.riding(m) and set_mario_action ~= nil then
        if not quiet then
            m.pos.y = m.pos.y + 2 * radius
            local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
            ax, az = tonumber(ax) or 0, tonumber(az) or 0
            if ax * ax + az * az > 0.0025 and atan2s ~= nil then yaw = atan2s(az, ax) end
            set_mario_action(m, ACT_JUMP, 0)
            local speed = ball.off_speed(radius)
            if m.faceAngle ~= nil then m.faceAngle.y = yaw end
            m.forwardVel = speed
            if m.vel ~= nil then
                local fx, fz = heading(yaw)
                m.vel.x, m.vel.z = fx * speed, fz * speed
                m.vel.y = ball.RIDE.offHop
            end

            offGuard = ball.RIDE.offGuard
        else
            set_mario_action(m, ACT_FREEFALL, 0)
        end
    end

    if entry ~= nil and owns(entry.o) and m ~= nil and m.pos ~= nil then
        local b = entry.b
        b.x, b.y, b.z = m.pos.x, m.pos.y - (quiet and 0 or 2 * ball.PROP_RADIUS) + ball.PROP_RADIUS, m.pos.z
        b.vx, b.vy, b.vz, b.grounded = was.vx, 0, was.vz, false
    end
    return true
end

function ball.try_mount(m)
    if m == nil or m.pos == nil or RIDE_GROUND == nil or ball.riding(m) then return nil end

    if offGuard > 0 then
        offGuard = offGuard - 1
        return nil
    end
    if in_a_round(0) then return nil end
    if (m.vel == nil or m.vel.y > 0) then return nil end
    if not has_flag(m.action or 0, ACT_FLAG_AIR or 0x800) then return nil end
    local R = ball.RIDE
    for _, entry in ipairs(ball.list()) do
        local at = entry.b
        if not ball.ridden_by_other(entry.id) then
            local dx, dz = m.pos.x - at.x, m.pos.z - at.z
            local top = at.y + ball.PROP_RADIUS
            if dx * dx + dz * dz < (ball.PROP_RADIUS * R.mountReach) ^ 2
                and m.pos.y <= top + R.mountAbove and m.pos.y >= top - R.mountBelow then
                ride = { id = entry.id, vx = at.vx or 0, vz = at.vz or 0 }
                m.pos.x, m.pos.y, m.pos.z = at.x, at.y - ball.PROP_RADIUS, at.z
                m.vel.x, m.vel.y, m.vel.z = ride.vx, 0, ride.vz
                set_mario_action(m, RIDE_GROUND, 0)
                publish_ride(true)
                return entry.id
            end
        end
    end
    return nil
end

local function take_the_pad(m)
    local c = m.controller
    if c == nil then return 0, 0, false, false end
    local sx, sy = tonumber(c.stickX) or 0, tonumber(c.stickY) or 0
    local mag = math.min(64, math.sqrt(sx * sx + sy * sy)) / 64
    local ax, az = 0, 0
    if mag > 0.05 then
        local cam = m.area ~= nil and m.area.camera ~= nil and m.area.camera.yaw or 0
        local yaw = math.floor(math.atan(sx, -sy) * 0x8000 / math.pi) + cam
        ax, az = heading(yaw)
        ax, az = ax * mag, az * mag
    end
    local pressed = c.buttonPressed or 0
    local jump = has_flag(pressed, A_BUTTON or 0x8000)
    local off = has_flag(pressed, X_BUTTON or 0x0040)
    c.stickX, c.stickY, c.stickMag = 0, 0, 0
    for _, bit in ipairs({ A_BUTTON or 0x8000, B_BUTTON or 0x4000, Z_TRIG or 0x2000, X_BUTTON or 0x0040 }) do
        if has_flag(c.buttonPressed or 0, bit) then c.buttonPressed = c.buttonPressed - bit end
        if has_flag(c.buttonDown or 0, bit) then c.buttonDown = c.buttonDown - bit end
    end
    return ax, az, jump, off
end

function ball.work_the_ride(m)
    if ride == nil or not ball.riding(m) then return false end
    local R = ball.RIDE
    if ball.menu_has_pad() then
        local keep = m.action == RIDE_AIR and R.airKeep or R.friction
        ride.vx, ride.vz = ride.vx * keep, ride.vz * keep
        return true
    end
    local ax, az, jump, off = take_the_pad(m)
    if off then
        ball.get_off(m, false, ax, az)
        return true
    end
    local air = m.action == RIDE_AIR
    local steer = air and R.airSteer or 1
    local keep = air and R.airKeep or R.friction
    ride.vx = (ride.vx + ax * R.accel * steer) * keep
    ride.vz = (ride.vz + az * R.accel * steer) * keep
    local speed = math.sqrt(ride.vx * ride.vx + ride.vz * ride.vz)
    if speed > R.top then
        ride.vx, ride.vz = ride.vx * R.top / speed, ride.vz * R.top / speed
    end
    if jump and not air then
        m.vel.y = R.jump
        set_mario_action(m, RIDE_AIR, 0)
    end
    if speed > 2 and m.faceAngle ~= nil then
        m.faceAngle.y = math.floor(math.atan(ride.vx, ride.vz) * 0x8000 / math.pi)
    end
    return true
end

local function off_the_wall(m)
    local n = m.wallNormal
    if n == nil or ride == nil then return end
    local nx, nz = n.x or 0, n.z or 0
    local len = math.sqrt(nx * nx + nz * nz)
    if len < 0.01 then return end
    nx, nz = nx / len, nz / len
    local into = ride.vx * nx + ride.vz * nz
    if into >= 0 then return end
    ride.vx = (ride.vx - 2 * into * nx) * ball.RIDE.wallKeep
    ride.vz = (ride.vz - 2 * into * nz) * ball.RIDE.wallKeep
end

local function ride_speed(m)
    if m.playerIndex == 0 and ride ~= nil then return ride.vx, ride.vz end
    return m.vel ~= nil and m.vel.x or 0, m.vel ~= nil and m.vel.z or 0
end

local function ride_pose(m, speed)
    if set_character_animation == nil then return end
    if speed < 1 then
        set_character_animation(m, CHAR_ANIM_IDLE_HEAD_CENTER)
    elseif set_character_anim_with_accel ~= nil then
        set_character_anim_with_accel(m, CHAR_ANIM_WALKING,
            math.floor(math.max(speed, 4) / 4 * 0x10000))
    end
end

local function act_ride_ground(m)
    if m == nil then return false end
    local vx, vz = ride_speed(m)
    if m.playerIndex == 0 and ride ~= nil and m.floor ~= nil and m.floor.normal ~= nil then
        ride.vx = ride.vx + (m.floor.normal.x or 0) * ball.RIDE.slope
        ride.vz = ride.vz + (m.floor.normal.z or 0) * ball.RIDE.slope
        vx, vz = ride.vx, ride.vz
    end
    local speed = math.sqrt(vx * vx + vz * vz)
    m.vel.x, m.vel.y, m.vel.z = vx, 0, vz
    m.forwardVel = speed
    m.slideVelX, m.slideVelZ = vx, vz
    ride_pose(m, speed)
    local result = perform_ground_step(m)
    if result == GROUND_STEP_LEFT_GROUND then
        m.vel.y = 0
        set_mario_action(m, RIDE_AIR, 0)
    elseif result == GROUND_STEP_HIT_WALL then
        off_the_wall(m)
    end
    return false
end

local function act_ride_air(m)
    if m == nil then return false end
    local vx, vz = ride_speed(m)
    m.vel.x, m.vel.z = vx, vz
    m.vel.y = math.max((m.vel.y or 0) - ball.RIDE.gravity, -ball.RIDE.terminal)
    m.forwardVel = math.sqrt(vx * vx + vz * vz)
    ride_pose(m, m.forwardVel)
    local falling = m.vel.y
    local result = perform_air_step(m, 0)
    if result == AIR_STEP_LANDED then
        if falling < -ball.RIDE.bounceFrom then
            m.vel.y = -falling * ball.RIDE.bounceKeep
        else
            m.vel.y = 0
            set_mario_action(m, RIDE_GROUND, 0)
        end
    elseif result == AIR_STEP_HIT_WALL then
        off_the_wall(m)
    end
    return false
end

ball.act_ride_ground, ball.act_ride_air = act_ride_ground, act_ride_air

local function rider_of(entry)
    if ride ~= nil and ride.id == entry.id then return gMarioStates[0], ride end
    local index = ball.ridden_by_other(entry.id)
    if index == nil then return nil, nil end
    return gMarioStates[index], read_ride(index)
end

ball.MARIO_RADIUS = 37
ball.MARIO_TALL = 160
ball.BUMP_KEEP = 0.8

function ball.solid_spots()
    local out = {}
    for _, entry in ipairs(ball.list()) do
        local at = entry.b
        local mine = ride ~= nil and ride.id == entry.id
        local spot = { x = at.x, y = at.y, z = at.z, ridden = false, mine = mine }
        local rm = rider_of(entry)
        if rm ~= nil and rm.pos ~= nil then
            spot.x, spot.y, spot.z = rm.pos.x, rm.pos.y + ball.PROP_RADIUS, rm.pos.z
            spot.ridden = true
        end
        out[#out + 1] = spot
    end
    return out
end

function ball.push_players(m)
    m = m or gMarioStates[0]
    if m == nil or m.pos == nil or m.playerIndex ~= 0 then return 0 end
    if in_a_round(0) then return 0 end
    local r = ball.PROP_RADIUS
    local riding = ride ~= nil and ball.riding(m)
    local pushed = 0
    for _, spot in ipairs(ball.solid_spots()) do
        if not spot.mine then
            local dx, dz = m.pos.x - spot.x, m.pos.z - spot.z
            local flat = math.sqrt(dx * dx + dz * dz)
            if riding then

                local cy = m.pos.y + r
                local dy = cy - spot.y
                local reach = 2 * r
                if flat < reach and math.abs(dy) < reach and flat > 0.01 then
                    local nx, nz = dx / flat, dz / flat
                    m.pos.x, m.pos.z = spot.x + nx * reach, spot.z + nz * reach
                    local into = ride.vx * nx + ride.vz * nz
                    if into < 0 then
                        ride.vx = (ride.vx - 2 * into * nx) * ball.BUMP_KEEP
                        ride.vz = (ride.vz - 2 * into * nz) * ball.BUMP_KEEP
                    end
                    pushed = pushed + 1
                end
            elseif spot.ridden then

                local reach = r + ball.MARIO_RADIUS
                local feet, head = m.pos.y, m.pos.y + ball.MARIO_TALL
                if flat < reach and head > spot.y - r and feet < spot.y + r - 10 then
                    local nx, nz = 1, 0
                    if flat > 0.01 then
                        nx, nz = dx / flat, dz / flat
                    elseif m.faceAngle ~= nil then
                        nx, nz = heading(m.faceAngle.y + 0x8000)
                    end
                    m.pos.x, m.pos.z = spot.x + nx * reach, spot.z + nz * reach
                    if m.vel ~= nil then
                        local into = (m.vel.x or 0) * nx + (m.vel.z or 0) * nz
                        if into < 0 then
                            m.vel.x = m.vel.x - into * nx
                            m.vel.z = m.vel.z - into * nz
                        end
                    end
                    pushed = pushed + 1
                end
            end
        end
    end
    return pushed
end

ball.rider_of = rider_of

function ball.forget_ride()
    ride, offGuard = nil, 0
end

ball.RIDE_HINTS = { { "move", "Roll" }, { "jump", "Jump" },
    { { pad = "X", key = "I" }, "Jump off" } }
function ball.ride_hints()
    if not ball.riding(gMarioStates[0]) then return false end
    if OF.util.asks(OF.camera, "controls_shown") and not OF.camera.controls_shown() then return false end
    local H = OF.hud
    if H == nil or type(H.hints) ~= "function" then return false end
    return H.hints(ball.RIDE_HINTS, { y = H.corner_hint_y() }) > 0
end

if RIDE_GROUND ~= nil and RIDE_AIR ~= nil then
    at_load("hook_mario_action", RIDE_GROUND, { every_frame = ball.act_ride_ground })
    at_load("hook_mario_action", RIDE_AIR, { every_frame = ball.act_ride_air })
end

local function one_owned_frame(entry)
    local np0 = gNetworkPlayers[0]
    local b, o = entry.b, entry.o
    entry.frames = entry.frames + 1
    if OF.forge ~= nil and OF.forge.held == o then

        local moved = math.abs(b.x - o.oPosX) + math.abs(b.y - o.oPosY) + math.abs(b.z - o.oPosZ) > 0.5
        b.x, b.y, b.z = o.oPosX, o.oPosY, o.oPosZ
        b.vx, b.vy, b.vz, b.grounded = 0, 0, 0, false
        return {}, (moved and entry.frames % 3 == 0) or entry.frames % 90 == 0
    end
    local rm, r = rider_of(entry)
    if rm ~= nil and rm.pos ~= nil then
        b.x, b.y, b.z = rm.pos.x, rm.pos.y + ball.PROP_RADIUS, rm.pos.z
        b.vx, b.vy, b.vz = r ~= nil and r.vx or 0, 0, r ~= nil and r.vz or 0
        local flat = math.sqrt(b.vx * b.vx + b.vz * b.vz)
        b.turn = ((b.turn or 0) + flat / ball.PROP_RADIUS) % (2 * math.pi)
        return {}, entry.frames % 3 == 0
    end
    local ev = ball.step(b, { material = ball.PROP_MATERIAL })

    if OF.util.asks(OF.football, "touch") then
        for index = 0, MAX_PLAYERS - 1 do
            local np = gNetworkPlayers[index]
            local m = gMarioStates[index]
            if np ~= nil and np.connected and m ~= nil and m.pos ~= nil
                and np.currLevelNum == np0.currLevelNum and np.currAreaIndex == np0.currAreaIndex
                and not in_a_round(index) and not ball.riding(m) then
                local gap = entry.kicks[np.globalIndex] or 0
                if gap > 0 then
                    entry.kicks[np.globalIndex] = gap - 1

                    if OF.util.asks(OF.football, "prop_press") then OF.football.prop_press(m, b) end
                else
                    local kind, vx, vy, vz = OF.football.touch(m, b)
                    if kind ~= nil then
                        b.vx, b.vy, b.vz = vx, vy, vz
                        b.grounded = false
                        entry.kicks[np.globalIndex] = ball.RIDE.kickGap
                        ev.kicked = kind
                    end
                end
            end
        end
    end
    if ev.out ~= nil then

        b.x, b.y, b.z = o.oHomeX or b.x, (o.oHomeY or b.y) + 300, o.oHomeZ or b.z
        b.vx, b.vy, b.vz = 0, 0, 0
    end
    local moving = math.abs(b.vx) + math.abs(b.vy) + math.abs(b.vz) > 0.05
    return ev, ev.kicked ~= nil or ev.out ~= nil or (moving and entry.frames % 3 == 0)
        or entry.frames % 90 == 0
end

function ball.prop_frame()
    local np0 = gNetworkPlayers[0]
    if np0 == nil then return nil end
    local last = nil

    local asleep = in_a_round(0)
    for _, entry in ipairs(ball.list()) do
        local o, b = entry.o, entry.b
        if owns(o) then
            if not asleep then
                local ev, due = one_owned_frame(entry)

                if due or entry.frames == 1 then send_state(entry) end
                last = ev

                o.oPosX, o.oPosY, o.oPosZ = b.x, b.y, b.z
            end
        else
            local rm = rider_of(entry)
            local t = entry.target
            if rm ~= nil and rm.pos ~= nil then
                b.x, b.y, b.z = rm.pos.x, rm.pos.y + ball.PROP_RADIUS, rm.pos.z
            elseif t ~= nil then
                b.x = b.x + (t.x - b.x) * 0.5
                b.y = b.y + (t.y - b.y) * 0.5
                b.z = b.z + (t.z - b.z) * 0.5
                b.vx, b.vy, b.vz = t.vx, t.vy, t.vz
            end
            b.turn = ((b.turn or 0) + math.sqrt((b.vx or 0) ^ 2 + (b.vz or 0) ^ 2) / ball.PROP_RADIUS)
                % (2 * math.pi)
        end
    end
    return last
end

function ball.draw_props()
    local shown = 0
    local live = {}
    if gNetworkPlayers[0] ~= nil and not in_a_round(0) then
        for _, entry in ipairs(ball.list()) do
            local name = token_name(entry)
            ball.draw(name, entry.b, nil)
            live[name] = true
            shown = shown + 1
        end
    end
    for name in pairs(ball.propsShown or {}) do
        if not live[name] then ball.hide(name) end
    end
    ball.propsShown = live
    return shown
end

function ball.prop_update()
    local m = gMarioStates[0]
    ball.sync_anchors()
    if ride ~= nil then
        if entry_by_id(ride.id) == nil or in_a_round(0) or not ball.riding(m) then
            ball.get_off(m, true)
        else
            publish_ride()
        end
    elseif ball.riding(m) then
        ball.get_off(m, true)
    else
        ball.try_mount(m)
    end
    ball.prop_frame()
    ball.draw_props()
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if ride ~= nil then ball.work_the_ride(m) end
    ball.push_players(m)
end, OF.LOCAL_MARIO)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.marioObj == nil or not ball.riding(m) then return end
    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.pos ~= nil and m.pos ~= nil then
        gfx.pos.y = m.pos.y + 2 * ball.PROP_RADIUS
    end
end)

hook_event(HOOK_UPDATE, function()
    ball.prop_update()
end)

function ball.forget_props()
    for _, entry in pairs(balls) do ball.hide(token_name(entry)) end
    balls = {}
    ball.forget_ride()
    ball.propsShown = {}
end
function ball.ride_state()
    return ride
end

function ball.ready()
    return true
end
