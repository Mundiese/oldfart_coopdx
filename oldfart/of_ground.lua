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

    "only where nobody is standing",
    "only where somebody has stood",
    "it pulls back while somebody is down",

    "where somebody died",
}

local STAGE = {
    fire   = #BANDS + 1,
    spare  = #BANDS + 2,
    path   = #BANDS + 3,
    relief = #BANDS + 4,
    graves = #BANDS + 5,
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

local lineKind = nil
local lineHeight = nil
local lineHeld = nil
local lineWas = nil
local lineWrote = nil
local lineTook = 0
local lineSpared = 0

local trodden = {}
local troddenCount = 0
local standing = {}
local byName = nil
local claims = { lava = false, trail = false }
local pathStage = nil
local pulledBack = nil
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

local worn = {}
local wornCount = 0

do

    local MATERIALS = {

        { key = "ground", name = "Ordinary ground", type = 0x0000,
          says = "what a block already is - the way out of anything else" },

        { key = "ice", name = "Ice", type = 0x002E,
          says = "you keep going after you stop pressing" },

        { key = "lava", name = "Lava", type = 0x0001,
          says = "the same field The floor is lava writes, on one block" },

        { key = "sand", name = "Sand", type = 0x0029,
          says = "walks and sounds like sand, and harms nobody" },

        { key = "quicksand", name = "Quicksand", type = 0x0021,
          says = "you sink a little way into it, and no further" },

        { key = "slippery", name = "Slippery", type = 0x0014,
          says = "less than ice, and you can still turn on it" },

        { key = "slide", name = "Slide", type = 0x0013,
          says = "what a slide is made of" },

        { key = "grip", name = "Grip", type = 0x0015,
          says = "nothing slides on it, whatever the level is doing" },

        { key = "hard", name = "Hard", type = 0x0030,
          says = "a landing on it always hurts" },
    }

    local byKey = {}
    for _, row in ipairs(MATERIALS) do byKey[row.key] = row end

    ground.MATERIALS = MATERIALS

    function ground.material(key)
        if type(key) ~= "string" then return nil end
        return byKey[key]
    end

    function ground.material_keys()
        local keys = {}
        for _, row in ipairs(MATERIALS) do keys[#keys + 1] = row.key end
        return keys
    end

    local byIndex = {}
    for index, row in ipairs(MATERIALS) do byIndex[row.key] = index end

    function ground.material_index(key)
        if type(key) ~= "string" then return nil end
        return byIndex[key]
    end

    function ground.material_at(index)
        index = tonumber(index)
        if index == nil then return nil end
        local row = MATERIALS[math.floor(index)]
        return row ~= nil and row.key or nil
    end

    local function name_of(object)
        if object == nil then return nil end

        if not (OF.util.asks(OF.util, "alive") and OF.util.alive(object)) then
            return nil
        end
        local id = tonumber(object.oSyncID)
        if id == nil or id ~= id or id <= 0 then return nil end
        return math.floor(id)
    end

    ground.material_name_of = name_of

    function ground.wear(object, key)
        return ground.wear_id(name_of(object), key)
    end

    function ground.wear_id(id, key)
        if type(id) ~= "number" or id ~= id or id <= 0 then return false end
        local row = byKey[key]
        if row == nil then return false end
        id = math.floor(id)
        if worn[id] == nil then wornCount = wornCount + 1 end
        worn[id] = row
        return true
    end

    function ground.bare(object)
        return ground.bare_id(name_of(object))
    end

    function ground.bare_id(id)
        if type(id) ~= "number" then return false end
        id = math.floor(id)
        if worn[id] == nil then return false end
        worn[id] = nil
        wornCount = wornCount - 1
        return true
    end

    function ground.worn(object)
        local id = name_of(object)
        if id == nil then return nil end
        local row = worn[id]
        return row ~= nil and row.key or nil
    end

    function ground.worn_id(id)
        if type(id) ~= "number" then return nil end
        local row = worn[math.floor(id)]
        return row ~= nil and row.key or nil
    end

    function ground.worn_count()
        return wornCount
    end

    function ground.forget_materials()
        worn = {}
        wornCount = 0
    end

    hook_event(HOOK_ON_OBJECT_UNLOAD, function(object)
        if wornCount == 0 then return end
        local id = name_of(object)
        if id == nil or worn[id] == nil then return end
        worn[id] = nil
        wornCount = wornCount - 1
    end)
end

hook_event(HOOK_ON_ADD_SURFACE, function(surface, dynamic)
    if dynamic then

        if wornCount == 0 then return end
        if surface == nil then return end
        local object = surface.object
        if object == nil then return end
        local id = tonumber(object.oSyncID)
        if id == nil then return end
        local row = worn[math.floor(id)]
        if row == nil then return end

        surface.type = row.type
        return
    end

    if surface ~= nil and surface.object ~= nil and SURFACE_BURNING ~= nil
        and OF.util.asks(OF.spawner, "is_lava_block")
        and OF.spawner.is_lava_block(surface.object) then
        surface.type = SURFACE_BURNING
    end
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

    byName = nil

    if painting and not creeping and not blowing
        and (ceiling == nil or top <= ceiling)
        and ground.burnable(surface.type) then
        surface.type = SURFACE_BURNING
    end
end)

hook_event(HOOK_ON_CLEAR_AREAS, function()
    floors = {}

    ground.forget_materials()

    trodden = {}
    troddenCount = 0
    standing = {}
    byName = nil
    pulledBack = nil

    lineHeld = nil
    lineWas = nil
    lineWrote = nil

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

    pathStage = nil
    pulledBack = nil
    claims.lava = false
    if not claims.trail then
        trodden = {}
        troddenCount = 0
        standing = {}
    end

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

ground.TIDE_KEY = "ofGroundTide"
local TIDE_HUNDREDTHS = 10000
local TIDE_HEARTBEAT = 30 * 30

local tideOn = false
local tideSeenText = nil
local tideStamp = 0
local tidePeriod = nil
local tideOrigin = 0
local tideSaid = 0

local tideTickFrame, tideTickAt = nil, nil

local function tide_ticks()
    local util = OF.util
    if util == nil then return 0 end
    local frame = util.optional("get_global_timer", nil)
    if frame ~= nil and frame == tideTickFrame and tideTickAt ~= nil then
        return tideTickAt
    end
    local now
    local secs = util.optional("clock_elapsed_f64", nil)
    if type(secs) == "number" then
        now = secs * 30
    elseif type(frame) == "number" then
        now = frame
    else
        now = 0
    end
    tideTickFrame, tideTickAt = frame, now
    return now
end

local function tide_next_said()
    tideSaid = tideSaid + 1
    if tideSaid > 99999 then tideSaid = 1 end
    return tideSaid
end

local function tide_take(text)
    local bits = {}
    for part in string.gmatch(tostring(text), "[^:]+") do
        table.insert(bits, part)
    end
    if #bits < 3 then return false end
    local stamp = tonumber(bits[2])
    local period = tonumber(bits[3])
    if type(stamp) ~= "number" or stamp ~= stamp then return false end
    if type(period) ~= "number" or period ~= period or period <= 0 then
        return false
    end
    tideStamp = stamp % TIDE_HUNDREDTHS
    tidePeriod = period
    tideOrigin = tide_ticks()
    tideSeenText = text
    return true
end

local function tide_forget()
    tideSeenText, tidePeriod = nil, nil
    tideStamp, tideOrigin = 0, 0
end

local function tide_follow()
    local text = gGlobalSyncTable[ground.TIDE_KEY]
    if type(text) ~= "string" or text == "" then
        if tideSeenText ~= nil then tide_forget() end
        return false
    end
    if text ~= tideSeenText then return tide_take(text) end
    return true
end

local function tide_progress()
    if not tide_follow() then return nil end
    local elapsed = tide_ticks() - tideOrigin
    if elapsed < 0 then elapsed = 0 end
    return (tideStamp + elapsed * TIDE_HUNDREDTHS / (tidePeriod * 30))
        % TIDE_HUNDREDTHS
end

function ground.tide_height(base, amplitude)
    local progress = tide_progress()
    if progress == nil then return nil end
    if type(base) ~= "number" then base = 0 end
    if type(amplitude) ~= "number" then amplitude = 0 end
    return base + amplitude * math.sin(progress / TIDE_HUNDREDTHS * 2 * math.pi)
end

function ground.tide_armed()
    return tide_follow()
end

function ground.tide_progress()
    return tide_progress()
end

function ground.tide_arm(period)
    if not OF.util.is_host() then return false end
    if type(period) ~= "number" or period <= 0 then return false end
    tideOn = true
    local text = tide_next_said() .. ":0:" .. math.floor(period)
    OF.util.publish(ground.TIDE_KEY, text)
    tide_follow()
    return true
end

function ground.tide_disarm()
    if not OF.util.is_host() then return false end
    tideOn = false
    OF.util.publish(ground.TIDE_KEY, "")
    tide_forget()
    return true
end

hook_event(HOOK_UPDATE, function()
    if not tideOn then return end
    if not OF.util.is_host() then return end
    local frame = OF.util.optional("get_global_timer", nil)
    if type(frame) ~= "number" or frame % TIDE_HEARTBEAT ~= 0 then return end
    local progress = tide_progress()
    if progress == nil or tidePeriod == nil then return end

    local text = tide_next_said() .. ":" .. string.format("%.2f", progress)
        .. ":" .. math.floor(tidePeriod)
    OF.util.publish(ground.TIDE_KEY, text)
    tide_follow()
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

    if level == STAGE.path then return troddenCount / #floors end
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

local LINE_LETHAL, LINE_OPEN, LINE_LAVA = 1, 2, 3

ground.LETHAL, ground.OPEN, ground.LAVA = LINE_LETHAL, LINE_OPEN, LINE_LAVA

local LINE_TYPES = {

    [LINE_LETHAL] = 0x000A,

    [LINE_OPEN] = 0x0012,

    [LINE_LAVA] = 0x0001,
}

local LINE_NAMES = {
    "the bottom of the world",
    "nothing to stand on",
    "lava",
}

function ground.line_kind_name(kind)
    if type(kind) ~= "number" or kind ~= kind then return nil end
    return LINE_NAMES[math.floor(kind)]
end

function ground.line_kind_count()
    return #LINE_NAMES
end

local function line_put_back()
    if lineHeld == nil then return false end
    local held, was, wrote = lineHeld, lineWas, lineWrote
    lineHeld, lineWas, lineWrote = nil, nil, nil
    if was == nil then return false end
    if not alive(held) then return false end

    if held.type ~= wrote then return false end
    if held.type ~= was then held.type = was end
    return true
end

function ground.set_line(kind, height)
    if type(kind) ~= "number" or LINE_TYPES[kind] == nil then return false end
    if type(height) ~= "number" or height ~= height then return false end
    line_put_back()
    lineKind = kind
    lineHeight = height
    lineTook = 0
    lineSpared = 0
    return true
end

function ground.clear_line()
    local put = line_put_back()
    lineKind = nil
    lineHeight = nil
    return put
end

function ground.line()
    if lineKind == nil then return nil end
    return lineKind, lineHeight
end

function ground.line_holding()
    if lineHeld == nil then return nil end
    return lineHeld, lineWas
end

function ground.line_took()
    return lineTook
end

function ground.line_spared()
    return lineSpared
end

function ground.line_step()
    line_put_back()
    if lineKind == nil or lineHeight == nil then return false end

    if type(find_floor) ~= "function" then return false end

    local m = gMarioStates[0]
    if not is_mine(m) then return false end
    if m.pos == nil or m.vel == nil then return false end

    local x = m.pos.x + m.vel.x
    local y = m.pos.y + m.vel.y
    local z = m.pos.z + m.vel.z

    local height, surface = find_floor(x, y, z)
    if surface == nil or type(height) ~= "number" then return false end
    if not alive(surface) then return false end

    if height > lineHeight then return false end

    if y > height then return false end

    local was = surface.type
    if not ground.leanable(was) then
        lineSpared = lineSpared + 1
        return false
    end

    local wants = LINE_TYPES[lineKind]
    surface.type = wants
    lineHeld = surface
    lineWas = was
    lineWrote = wants
    lineTook = lineTook + 1
    return true
end

hook_event(HOOK_UPDATE, ground.line_step)

local DOWN_ACTIONS = {}
for _, action in ipairs({ ACT_BUBBLED, ACT_DROWNING, ACT_WATER_DEATH,
    ACT_STANDING_DEATH, ACT_QUICKSAND_DEATH, ACT_ELECTROCUTION,
    ACT_SUFFOCATION, ACT_DEATH_ON_STOMACH, ACT_DEATH_ON_BACK,
    ACT_EATEN_BY_BUBBA }) do
    if type(action) == "number" then DOWN_ACTIONS[action] = true end
end

local TREAD_SLACK = 4

local function index_by_name()
    if byName ~= nil then return byName end
    local index = {}
    for _, entry in ipairs(floors) do

        if entry.stamp == nil then entry.stamp = ground.name_of(entry.surface) end
        if entry.stamp ~= nil then index[entry.stamp] = entry end
    end
    byName = index
    return index
end

local function walk_the_floors()
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil then return nil end
    local seen = nil
    for _, row in ipairs(OF.util.connected_players()) do
        local np = row.np
        if np ~= nil and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex then
            local m = gMarioStates[row.localIndex]
            if m ~= nil and m.pos ~= nil and m.floor ~= nil
                and type(m.floorHeight) == "number"
                and m.pos.y <= m.floorHeight + TREAD_SLACK
                and alive(m.floor) then
                local name = ground.name_of(m.floor)
                if name ~= nil then
                    seen = seen or {}
                    seen[name] = true
                end
            end
        end
    end
    return seen
end

local function anybody_down()
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil then return false end
    for _, row in ipairs(OF.util.connected_players()) do
        local np = row.np
        if np ~= nil and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex then
            local m = gMarioStates[row.localIndex]
            if m ~= nil and DOWN_ACTIONS[m.action] == true then return true end
        end
    end
    return false
end

function ground.is_trodden(surface)
    if surface == nil then return false end
    if not alive(surface) then return false end
    local name = ground.name_of(surface)
    if name == nil then return false end
    return trodden[name] == true
end

function ground.trodden_count()
    return troddenCount
end

function ground.remembering()
    return pathStage
end

function ground.trail(on)
    claims.trail = (on == true)
    if not claims.trail and not claims.lava then
        trodden = {}
        troddenCount = 0
        standing = {}
    end
    return claims.trail
end

function ground.tread_step()
    if not (claims.lava or claims.trail) then return 0 end
    if #floors == 0 then return 0 end

    local now = walk_the_floors()

    local index = (pathStage ~= nil) and index_by_name() or nil
    local touched = 0

    if now ~= nil then
        for name in pairs(now) do
            if trodden[name] == nil then
                trodden[name] = true
                troddenCount = troddenCount + 1
                if pathStage == STAGE.path and index ~= nil then
                    local entry = index[name]
                    if entry ~= nil and alive(entry.surface)
                        and ground.burnable(entry.was)
                        and entry.surface.type ~= SURFACE_BURNING then
                        entry.surface.type = SURFACE_BURNING
                        touched = touched + 1
                    end
                end
            end
        end
    end

    if pathStage == STAGE.spare and index ~= nil then
        for name in pairs(standing) do
            if now == nil or now[name] == nil then
                local entry = index[name]
                if entry ~= nil and alive(entry.surface)
                    and ground.burnable(entry.was)
                    and entry.surface.type ~= SURFACE_BURNING then
                    entry.surface.type = SURFACE_BURNING
                    touched = touched + 1
                end
            end
        end
        if now ~= nil then
            for name in pairs(now) do
                if standing[name] == nil then
                    local entry = index[name]
                    if entry ~= nil and alive(entry.surface)
                        and entry.surface.type ~= entry.was then
                        entry.surface.type = entry.was
                        touched = touched + 1
                    end
                end
            end
        end
    end

    if pathStage == STAGE.relief then
        local down = anybody_down()
        if down ~= pulledBack then
            local low = ground.lowest()
            if down and low ~= nil and BANDS[1] then
                ground.paint_to(low + BANDS[1])
            else
                ground.paint_to(nil)
            end
            pulledBack = down
            touched = touched + 1
        end
    end

    standing = now or {}
    return touched
end

function ground.remember(level)
    if type(level) ~= "number" or level ~= level then return false end
    level = math.floor(level)

    if level ~= STAGE.spare and level ~= STAGE.path and level ~= STAGE.relief then
        return false
    end

    ground.restore()
    claims.lava = true
    pathStage = level
    painted = level
    pulledBack = false
    standing = {}

    if level ~= STAGE.path then ground.paint_to(nil) end

    ground.tread_step()

    local name = ground.stage_name(level)
    if name ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show("The floor is lava - @", "warn", 5, name)
    end
    return true
end

hook_event(HOOK_UPDATE, ground.tread_step)

function ground.ready()
    return true
end
