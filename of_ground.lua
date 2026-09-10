OF = OF or {}
OF.ground = OF.ground or {}

local ground = OF.ground

local floors = {}

local painted = nil
local ceiling = nil
local painting = false

local CREEP_KEY = "ofLavaFront"
local creeping = false
local creepSeed = nil
local creepFront = nil
local creepReach = nil
local creepCounted = nil

local FLOOR_NORMAL = 0.5

local BANDS = { 800, 2500, false }

local STAGES = {
    "the low ground",
    "all but the high ground",
    "the whole course",
    "a spreading fire",
}

function ground.stage_name(level)
    if type(level) ~= "number" or level ~= level then return nil end
    return STAGES[math.floor(level)]
end

function ground.stage_count()
    return #STAGES
end

local blowSpared = 0

local blowing = false

local function is_floor(surface)
    if surface == nil then return false end
    local normal = surface.normal
    if normal == nil or type(normal.y) ~= "number" then return false end
    return normal.y > FLOOR_NORMAL
end

local function top_of(surface)
    if surface == nil then return nil end
    if type(surface.upperY) == "number" then return surface.upperY end
    local v1, v2, v3 = surface.vertex1, surface.vertex2, surface.vertex3
    if v1 == nil or v2 == nil or v3 == nil then return nil end
    return math.max(v1.y, v2.y, v3.y)
end

function ground.remeasure(surface)
    if surface == nil then return false end
    local entry = floors[#floors]
    if entry == nil or entry.surface ~= surface then return false end
    local top = top_of(surface)
    if top == nil then return false end
    local v1, v2, v3 = surface.vertex1, surface.vertex2, surface.vertex3
    entry.top = top
    if v1 ~= nil and v2 ~= nil and v3 ~= nil then
        entry.low = math.min(v1.y, v2.y, v3.y)
        entry.x = (v1.x + v2.x + v3.x) / 3
        entry.z = (v1.z + v2.z + v3.z) / 3
    else
        entry.low = top
    end
    return true
end

function ground.lowest()
    local low = nil
    for _, entry in ipairs(floors) do
        local y = entry.low
        if y ~= nil and (low == nil or y < low) then low = y end
    end
    return low
end

function ground.counted()
    return #floors
end

function ground.painted_level()
    return painted
end

hook_event(HOOK_ON_ADD_SURFACE, function(surface, dynamic)
    if dynamic then return end
    if not is_floor(surface) then return end
    local top = top_of(surface)
    if top == nil then return end
    local v1, v2, v3 = surface.vertex1, surface.vertex2, surface.vertex3
    local low = top
    if v1 ~= nil and v2 ~= nil and v3 ~= nil then
        low = math.min(v1.y, v2.y, v3.y)
    end
    table.insert(floors, {
        surface = surface,
        was = surface.type,
        wasForce = surface.force,
        top = top,
        low = low,

        x = (v1 ~= nil and v2 ~= nil and v3 ~= nil) and (v1.x + v2.x + v3.x) / 3 or 0,
        z = (v1 ~= nil and v2 ~= nil and v3 ~= nil) and (v1.z + v2.z + v3.z) / 3 or 0,
    })

    if painting and not creeping and not blowing
        and (ceiling == nil or top <= ceiling)
        and ground.burnable(surface.type) then
        surface.type = SURFACE_BURNING
    end
end)

hook_event(HOOK_ON_CLEAR_AREAS, function()
    floors = {}

    creepSeed = nil
    creepReach = nil
    creepCounted = nil
    if creeping then
        creepFront = 0
        if OF.util.is_host() then OF.util.publish(CREEP_KEY, 0) end
    end

end)

local function alive(surface)
    return OF.util.asks(OF.util, "alive") and OF.util.alive(surface)
end

function ground.restore()
    painted = nil
    ceiling = nil
    painting = false

    blowSpared = 0
    blowing = false

    creeping = false
    creepSeed = nil
    creepFront = nil
    creepReach = nil
    creepCounted = nil

    if OF.util.is_host() then OF.util.publish(CREEP_KEY, nil) end
    local put = 0
    for _, entry in ipairs(floors) do
        if alive(entry.surface) then
            if entry.surface.type ~= entry.was then
                entry.surface.type = entry.was
                put = put + 1
            end

            if entry.wasForce ~= nil and entry.surface.force ~= entry.wasForce then
                entry.surface.force = entry.wasForce
            end
        end
    end
    return put
end

local NOT_GROUND = {

    [0x000A] = true,

    [0x0038] = true,
}

function ground.burnable(surfaceType)
    return NOT_GROUND[surfaceType] ~= true
end

function ground.paint_to(upTo)
    local put = 0
    local burned = 0
    for _, entry in ipairs(floors) do
        if alive(entry.surface) then
            local wants = (upTo == nil or entry.top <= upTo)
                and ground.burnable(entry.was)
                and SURFACE_BURNING or entry.was
            if entry.surface.type ~= wants then
                entry.surface.type = wants
                put = put + 1
            end
            if wants == SURFACE_BURNING then burned = burned + 1 end
        end
    end
    ceiling = upTo
    painting = true

    blowing = false
    return burned, put
end

function ground.paint(level)
    if type(level) ~= "number" or level < 1 then level = 1 end
    if level > #BANDS then level = #BANDS end
    ground.restore()
    painted = level

    local band = BANDS[level]
    local low = ground.lowest()
    local upTo = nil
    if band and low ~= nil then upTo = low + band end

    local burned = ground.paint_to(upTo)

    if burned > 0 then
        local name = ground.stage_name(level)
        if name ~= nil and OF.util.asks(OF.notify, "show") then
            OF.notify.show("The floor is lava - @", "warn", 5, name)
        end
    end
    return burned
end

local CREEP_SPEED = 4

local function creep_seed()
    local best, bestName = nil, nil
    for _, entry in ipairs(floors) do
        if best == nil or entry.top < best.top then
            best, bestName = entry, nil
        elseif entry.top == best.top and alive(entry.surface) then
            if bestName == nil then bestName = ground.name_of(best.surface) end
            local name = ground.name_of(entry.surface)
            if name ~= nil and (bestName == nil or name < bestName) then
                best, bestName = entry, name
            end
        end
    end
    return best
end

local function measure_from_seed()
    creepSeed = creep_seed()
    creepCounted = #floors
    creepReach = 0
    if creepSeed == nil then return false end
    local sx, sy, sz = creepSeed.x, creepSeed.top, creepSeed.z
    for _, entry in ipairs(floors) do
        local dx, dy, dz = entry.x - sx, entry.top - sy, entry.z - sz
        local away = math.sqrt(dx * dx + dy * dy + dz * dz)
        entry.away = away
        if away > creepReach then creepReach = away end
    end
    return true
end

function ground.creep_to(front)
    if type(front) ~= "number" then return 0 end
    if creepSeed == nil or creepCounted ~= #floors then
        if not measure_from_seed() then return 0 end
    end
    local burned = 0
    for _, entry in ipairs(floors) do
        if alive(entry.surface) and entry.away ~= nil and entry.away <= front
            and ground.burnable(entry.was) then
            if entry.surface.type ~= SURFACE_BURNING then
                entry.surface.type = SURFACE_BURNING
            end
            burned = burned + 1
        end
    end
    creepFront = front
    painting = true
    return burned
end

function ground.creep()
    ground.restore()
    creeping = true
    painted = #BANDS + 1
    creepFront = 0
    measure_from_seed()
    if creepSeed ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show("A fire has started at the bottom of this course", "warn", 6)
    end
    return creepSeed ~= nil
end

function ground.creeping()
    return creeping
end

function ground.creep_at()
    if creepSeed == nil then return nil end
    return ground.name_of(creepSeed.surface)
end

function ground.creep_front()
    if not creeping then return nil end
    return creepFront, creepReach
end

function ground.creep_eta(localIndex)
    if not creeping then return nil end
    if creepSeed == nil or creepFront == nil then return nil end
    local m = gMarioStates[localIndex or 0]
    if m == nil or m.pos == nil then return nil end
    local dx = m.pos.x - creepSeed.x
    local dy = m.pos.y - creepSeed.top
    local dz = m.pos.z - creepSeed.z
    local left = math.sqrt(dx * dx + dy * dy + dz * dz) - creepFront
    if left <= 0 then return 0 end
    return left / (CREEP_SPEED * 30)
end

local function render_fire()
    local eta = ground.creep_eta(0)
    if eta == nil then return end
    if OF.util.menu_has_screen() then return end

    local text
    if eta <= 0 then
        text = OF.lang.t("The fire is here")
    else
        text = OF.lang.fill("Fire in @s", math.floor(eta + 0.5))
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local width = djui_hud_get_screen_width()
    local size = OF.util.text_size(text, 0.7)

    local r, g, b = 255, 140, 60
    if eta <= 5 and math.floor(eta * 2) % 2 == 0 then r, g, b = 255, 255, 255 end
    OF.util.text(text, (width - size) * 0.5, 64, 0.7, r, g, b, 255)
end

hook_event(HOOK_ON_HUD_RENDER, render_fire)

hook_event(HOOK_UPDATE, function()
    if not creeping then return end
    if #floors == 0 then return end
    if OF.util.is_host() then
        if creepReach == nil or creepCounted ~= #floors then measure_from_seed() end
        local front = (creepFront or 0) + CREEP_SPEED

        if creepReach ~= nil and front > creepReach then front = creepReach end
        OF.util.publish(CREEP_KEY, math.floor(front))
    end
    local said = gGlobalSyncTable[CREEP_KEY]
    if type(said) == "number" then ground.creep_to(said) end
end)

local BLOW_OUT, BLOW_IN, BLOW_ROUND = 1, 2, 3

function ground.middle()
    if #floors == 0 then return nil end
    local x, z = 0, 0
    for _, entry in ipairs(floors) do
        x = x + entry.x
        z = z + entry.z
    end
    return x / #floors, z / #floors
end

local function yaw_of(dx, dz)

    return math.floor(math.atan(dx, dz) * 0x8000 / math.pi + 0.5) & 0xFFFF
end

local ON_THE_SPOT = 1.0

function ground.blow(which, upTo)
    if which ~= BLOW_OUT and which ~= BLOW_IN and which ~= BLOW_ROUND then
        return 0
    end
    local cx, cz = ground.middle()
    if cx == nil then return 0 end

    local blown = 0
    blowSpared = 0
    for _, entry in ipairs(floors) do
        if alive(entry.surface) then

            if not ground.leanable(entry.was) then
                blowSpared = blowSpared + 1
            elseif upTo == nil or entry.top <= upTo then
                local dx, dz = entry.x - cx, entry.z - cz
                if which == BLOW_IN then dx, dz = -dx, -dz end
                if which == BLOW_ROUND then dx, dz = -dz, dx end

                if math.abs(dx) > ON_THE_SPOT or math.abs(dz) > ON_THE_SPOT then
                    entry.surface.type = SURFACE_HORIZONTAL_WIND
                    entry.surface.force = (yaw_of(dx, dz) >> 8) & 0xFF
                    blown = blown + 1
                end
            else
                entry.surface.type = entry.was
                if entry.wasForce ~= nil then entry.surface.force = entry.wasForce end
            end
        end
    end
    ceiling = upTo
    painting = true

    blowing = true
    return blown
end

ground.OUT, ground.IN, ground.ROUND = BLOW_OUT, BLOW_IN, BLOW_ROUND

function ground.blow_spared()
    return blowSpared
end

local LEANABLE = {

    [0x0000] = true,

    [0x0004] = true,

    [0x0009] = true,

    [0x0013] = true,

    [0x0014] = true,

    [0x0015] = true,

    [0x0016] = true,

    [0x0029] = true,

    [0x002A] = true,

    [0x002C] = true,

    [0x002E] = true,

    [0x0030] = true,

    [0x0035] = true,

    [0x0036] = true,

    [0x0037] = true,

    [0x0068] = true,

    [0x0073] = true,

    [0x0074] = true,

    [0x0075] = true,

    [0x0076] = true,

    [0x0077] = true,

    [0x0078] = true,

    [0x0079] = true,
}

function ground.leanable(surfaceType)
    return LEANABLE[surfaceType] == true
end

function ground.highest()
    local high = nil
    for _, entry in ipairs(floors) do
        local y = entry.top
        if y ~= nil and (high == nil or y > high) then high = y end
    end
    return high
end

function ground.share(level)
    if #floors == 0 then return nil end
    if type(level) ~= "number" then level = painted end
    if level == nil then return nil end
    local band = BANDS[level]
    if not band then return 1 end
    local low = ground.lowest()
    if low == nil then return nil end
    local under = 0
    for _, entry in ipairs(floors) do
        if entry.top <= low + band then under = under + 1 end
    end
    return under / #floors
end

local NAME_BASIS = 2166136261
local NAME_PRIME = 16777619

local function fold(hash, value)
    if type(value) ~= "number" or value ~= value then return nil end
    if value < -32768 or value > 32767 then return nil end

    hash = (hash ~ (math.floor(value) % 65536)) & 0xFFFFFFFF
    return (hash * NAME_PRIME) & 0xFFFFFFFF
end

function ground.name_of(surface)
    if surface == nil then return nil end
    local a, b, c = surface.vertex1, surface.vertex2, surface.vertex3

    if a == nil or b == nil or c == nil then return nil end
    local hash = NAME_BASIS
    for _, corner in ipairs({ a, b, c }) do
        hash = fold(hash, corner.x)
        if hash == nil then return nil end
        hash = fold(hash, corner.y)
        if hash == nil then return nil end
        hash = fold(hash, corner.z)
        if hash == nil then return nil end
    end
    return hash
end

local function is_mine(m)
    return m ~= nil and m.playerIndex == 0
end

local CONTINUE = -1

local FALL_PER_FRAME = 4.0
local TERMINAL = -75.0

local PULLS = {
    { key = "moon",   name = "the moon", factor = 0.17 },
    { key = "low",    name = "low",      factor = 0.45 },
    { key = "light",  name = "light",    factor = 0.72 },
    { key = "normal", name = "normal",   factor = nil },
    { key = "heavy",  name = "heavy",    factor = 1.60 },
    { key = "lead",   name = "lead",     factor = 2.50 },
}

local pulling = nil
local pullKey = nil

local pullIsRound = false

function ground.pull()
    return pulling
end

function ground.pull_key()
    return pullKey
end

function ground.pull_step(key)
    if key == nil then return nil end
    for _, step in ipairs(PULLS) do
        if step.key == key then return step end
    end
    return nil
end

function ground.pull_name()
    local step = ground.pull_step(pullKey)
    return step ~= nil and step.name or nil
end

local function moon_is_taken()
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("lowgrav") then
        return true
    end
    if OF.util.asks(OF.cheats, "is_on") and OF.cheats.is_on("lowgrav") then
        return true
    end
    return false
end

function ground.pull_is_yielding()
    return pulling ~= nil and moon_is_taken()
end

local FLAG_JUMP_HEIGHT = 0x02000000
local FLAG_INTANGIBLE  = 0x00001000
local FLAG_INVULNERABLE = 0x00020000
local FLAG_JUMPED      = 0x00000100
local A_IS_DOWN        = 0x0080

local function vanilla_owns_this_frame(m)
    local vel = m.vel
    if vel == nil or type(vel.y) ~= "number" then return true end
    if type(m.flags) ~= "number" or type(m.input) ~= "number"
        or type(m.action) ~= "number" then
        return true
    end

    if MARIO_WING_CAP ~= nil and (m.flags & MARIO_WING_CAP) ~= 0
        and vel.y < 0 and (m.input & A_IS_DOWN) ~= 0 then
        return true
    end

    if (m.flags & FLAG_JUMPED) == 0 then return false end
    if (m.action & (FLAG_INTANGIBLE | FLAG_INVULNERABLE)) ~= 0 then return false end
    if (m.input & A_IS_DOWN) == 0 and vel.y > 20.0 then
        return (m.action & FLAG_JUMP_HEIGHT) ~= 0
    end
    return false
end

function ground.gravity_frame(m)
    if not is_mine(m) then return CONTINUE end
    if pulling == nil then return CONTINUE end
    if moon_is_taken() then return CONTINUE end
    if vanilla_owns_this_frame(m) then return CONTINUE end

    local vel = m.vel
    local bottom = TERMINAL * pulling
    vel.y = vel.y - FALL_PER_FRAME * pulling
    if vel.y < bottom then vel.y = bottom end

    return true
end

local PULLED = {}

local function pulled_by(action)
    if type(action) ~= "number" or action == 0 then return end
    for _, already in ipairs(PULLED) do
        if already == action then return end
    end
    table.insert(PULLED, action)
end

pulled_by(ACT_JUMP)
pulled_by(ACT_DOUBLE_JUMP)
pulled_by(ACT_TRIPLE_JUMP)
pulled_by(ACT_BACKFLIP)
pulled_by(ACT_SIDE_FLIP)
pulled_by(ACT_WALL_KICK_AIR)
pulled_by(ACT_FREEFALL)
pulled_by(ACT_DIVE)
pulled_by(ACT_JUMP_KICK)
pulled_by(ACT_AIR_HIT_WALL)
pulled_by(ACT_RIDING_SHELL_FALL)

pulled_by(0x03000885)

pulled_by(0x01000889)

pulled_by(0x0300088E)

pulled_by(0x03000894)

pulled_by(0x030008A0)

pulled_by(0x010008A1)

pulled_by(0x010008A2)

pulled_by(0x010008A3)

pulled_by(0x010008A6)

pulled_by(0x010008AD)

pulled_by(0x000008AE)

pulled_by(0x030008AF)

pulled_by(0x010208B6)

for _, action in ipairs(PULLED) do
    hook_mario_action(action, { gravity = ground.gravity_frame })
end

function ground.pulled_count()
    return #PULLED
end

function ground.is_pulled(action)
    for _, hooked in ipairs(PULLED) do
        if hooked == action then return true end
    end
    return false
end

ground.PACKET = "gpull"
function ground.wear_pull(key)
    local step = ground.pull_step(key)
    if step == nil then
        pulling = nil
        pullKey = nil
        return false
    end
    pulling = step.factor
    pullKey = step.factor ~= nil and step.key or nil
    return true
end

function ground.set_pull(key, askerLocal)
    if type(key) ~= "string" then return false, "Which gravity?" end
    local step = ground.pull_step(key)
    if step == nil then return false, "There is no gravity by that name." end

    if not OF.util.is_host() then
        return OF.net.host_does("gravity", key)
    end

    ground.wear_pull(key)
    pullIsRound = OF.util.asks(OF.gamemodes, "is_running")
        and OF.gamemodes.is_running() or false

    OF.util.tell_all({ ofp = ground.PACKET,
                       p = step.factor ~= nil and key or "normal" })

    if step.factor == nil then
        OF.notify.send_all("Gravity is back to normal", "info", 4)
    else

        OF.notify.send_all("Gravity is now @", "warn", 5, step.name)
    end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal,
            OF.lang.fill("gravity: @", OF.lang.t(step.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("set the lobby's gravity: @", OF.lang.t(step.name)))
    return true
end

local function on_pull_packet(data)
    if type(data) ~= "table" then return end
    if data.ofp ~= ground.PACKET then return end

    if not OF.util.from_host(data) then return end
    ground.wear_pull(tostring(data.p))
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_pull_packet)

local function tell_the_joiner(m)
    if not OF.util.is_host() then return end
    if pullKey == nil then return end
    if m == nil or type(m.playerIndex) ~= "number" then return end
    if m.playerIndex <= 0 then return end

    if not OF.util.send_to_player(m.playerIndex,
        { ofp = ground.PACKET, p = pullKey }) then
        return
    end
end

hook_event(HOOK_ON_PLAYER_CONNECTED, tell_the_joiner)

local roundWas = false

local function watch_the_round()
    local running = OF.util.asks(OF.gamemodes, "is_running")
        and OF.gamemodes.is_running() or false
    if running == roundWas then return end
    roundWas = running
    if running then return end
    if not OF.util.is_host() then return end
    if pullKey == nil or not pullIsRound then return end

    OF.util.report(ground.set_pull("normal"))
end

hook_event(HOOK_UPDATE, watch_the_round)

local function render_pull()
    if pullKey == nil then return end
    if OF.util.menu_has_screen() then return end

    local name = ground.pull_name()
    if name == nil then return end
    local text
    if moon_is_taken() then

        text = OF.lang.fill("Gravity @ - the Low gravity modifier has it", name)
    else
        text = OF.lang.fill("Gravity: @", name)
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local width = djui_hud_get_screen_width()
    local size = OF.util.text_size(text, 0.6)
    OF.util.text(text, (width - size) * 0.5, 84, 0.6, 170, 200, 255, 210)
end

hook_event(HOOK_ON_HUD_RENDER, render_pull)

local pullReady = false

function ground.register()
    if pullReady then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    pullReady = true

    OF.net.register_action("gravity", "speedrun", function(fromLocal, key)
        if not OF.util.is_host() then return false, "Only the host." end
        return ground.set_pull(tostring(key), fromLocal)
    end)
end

hook_event(HOOK_UPDATE, function() ground.register() end)

function ground.pull_names()
    local names = {}
    for _, step in ipairs(PULLS) do table.insert(names, step.key) end
    return names
end

local EDGE_SHOWN = 90

local edgeAgo = nil

function ground.left_the_map(m)
    if not is_mine(m) then return end
    edgeAgo = 0
end

function ground.at_edge()
    return edgeAgo
end

if HOOK_ON_COLLIDE_LEVEL_BOUNDS ~= nil then
    hook_event(HOOK_ON_COLLIDE_LEVEL_BOUNDS, ground.left_the_map)
end

local function age_the_edge()
    if edgeAgo == nil then return end
    edgeAgo = edgeAgo + 1
    if edgeAgo > EDGE_SHOWN then edgeAgo = nil end
end

hook_event(HOOK_UPDATE, age_the_edge)

local function render_edge()
    if edgeAgo == nil then return end
    if not painting then return end
    if OF.util.menu_has_screen() then return end

    local text = OF.lang.t("No ground here - the level ends")
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local width = djui_hud_get_screen_width()
    local size = OF.util.text_size(text, 0.6)
    OF.util.text(text, (width - size) * 0.5, 104, 0.6, 255, 210, 120, 220)
end

hook_event(HOOK_ON_HUD_RENDER, render_edge)

function ground.ready()
    return true
end
